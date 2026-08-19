using System.Text;
using Dapper;
using GmDashboard.Models;

namespace GmDashboard.Data;

/// <summary>
/// plan-34 B-146 — ATIF (talep sapması). Accountability'nin ADİL metriği:
/// ÖNERİ-SAPMASI = OneriSiparisTalep.SiparisMiktar − OneriSiparis.OneriSiparisAdet (aynı Tarih/MekanId/StkId).
/// Öneri motoru bir adet önerir, insan onu değiştirir → sapma = KONTROL EDİLEBİLİR karar.
/// Ham talep hacminden çok daha adil: hacim benimseme asimetriğinden (İst.Yolu %70) etkilenir, ORAN etkilenmez.
///
/// ADALET KISITLARI (sema: bkm.OneriSiparisTalep · kod düzeyinde zorlanır):
///  - Pencere ≥ Ayarlar.AtifBaslangicEtkin (varsayılan 01.02.2025): kanal devri + talep sistemi ısınma + 2024-08/09/10 boşluğu.
///  - Atıf-dışı hesaplar (yazılımcı/iç denetim) whitelist ile ELENİR.
///  - Aynı kişinin çok hesabı BİRLEŞTİRİLİR (yoksa aynı kişi iki alıcı sayılır).
///  - UNVAN etiketi YOK (roller zaman içinde değişti) → kişi + şube + kategori.
///  - MUTLAK talep/adet ile kişi kıyası YASAK → UI oran gösterir; talep sayısı yalnız paydayı görmek için.
///  - Metrikler AKTİF GÜNE normalize (358 talep/1 gün ≠ 29.253 talep/131 gün).
/// Salt-okuma (erp-write-policy) · 3-parçalı DerinSISBkm isim.
/// </summary>
public sealed partial class SatinalmaQueries
{
    /// <summary>Hesap adı güvenlik süzgeci — Ayarlar'dan gelen isimler SQL'e literal gömülür (CASE/IN).</summary>
    private static bool GuvenliHesap(string s) =>
        s.Length is > 0 and <= 60 && s.All(ch => char.IsAsciiLetterOrDigit(ch) || ch is '.' or '_' or '-');

    /// <summary>
    /// Kullanıcı (birleştirilmiş) × şube bazında öneri-sapması oranları. Sekme tıklanınca çağrılır.
    /// PERF: talep tablosu küçük (111K), OneriSiparis PK(Tarih,MekanId,StkId) üzerinden SEEK — CAST talep tarafında.
    /// </summary>
    public async Task<IReadOnlyList<AtifRow>> GetAtifAsync()
    {
        var a = ayar.Deger;
        var haric = a.AliciHaricEtkin.Where(GuvenliHesap).ToArray();
        var birlestir = a.AliciBirlestirMap.Where(kv => GuvenliHesap(kv.Key) && GuvenliHesap(kv.Value)).ToArray();

        // Hesap birleştirme SQL'de yapılır (aktif-gün COUNT(DISTINCT) birleşme SONRASI doğru olsun).
        var kullaniciIfade = new StringBuilder("t.EkleyenKullanici");
        if (birlestir.Length > 0)
        {
            kullaniciIfade.Clear().Append("CASE ");
            foreach (var (ikincil, ana) in birlestir)
                kullaniciIfade.Append($"WHEN t.EkleyenKullanici='{ikincil}' THEN '{ana}' ");
            kullaniciIfade.Append("ELSE t.EkleyenKullanici END");
        }
        var haricFiltre = haric.Length > 0
            ? "AND t.EkleyenKullanici NOT IN (" + string.Join(",", haric.Select(h => $"'{h}'")) + ")"
            : "";

        var sql = $"""
            SELECT {kullaniciIfade} AS Kullanici,
                   t.MekanId,
                   COUNT(*)                                                        AS Talep,
                   COUNT(DISTINCT CONVERT(varchar(10), t.Tarih, 112))              AS AktifGun,
                   COUNT(DISTINCT t.StkId)                                         AS Urun,
                   SUM(CASE WHEN o.StkId IS NOT NULL THEN 1 ELSE 0 END)            AS OneriEslesen,
                   SUM(CASE WHEN o.StkId IS NOT NULL AND t.SiparisMiktar = o.OneriSiparisAdet THEN 1 ELSE 0 END) AS Aynen,
                   SUM(CASE WHEN o.StkId IS NOT NULL AND t.SiparisMiktar > o.OneriSiparisAdet THEN 1 ELSE 0 END) AS Fazla,
                   SUM(CASE WHEN o.StkId IS NOT NULL AND t.SiparisMiktar < o.OneriSiparisAdet THEN 1 ELSE 0 END) AS Az,
                   SUM(CASE WHEN t.Onay = 1 THEN 1 ELSE 0 END)                     AS Onayli,
                   -- Sapma ORANI (adet değil): her satırda (talep−öneri)/öneri, öneri>0 olanlarda.
                   -- ⚠ KIRPMA ZORUNLU: düz ortalama uç satıra teslim (öneri=1, talep=50 → +4900% tek başına sütunu
                   -- sürükler; canlıda ist.kirtasiye %262 böyle çıkmıştı). Satır oranı [-100%, +200%] aralığına
                   -- kırpılır → ortalama davranışı temsil eder, tek anomali değil. Alt sınır -100 doğal (talep=0).
                   CONVERT(decimal(10,1), 100.0 * AVG(CASE WHEN o.StkId IS NOT NULL AND o.OneriSiparisAdet > 0
                        THEN CASE
                               WHEN (t.SiparisMiktar - o.OneriSiparisAdet) / o.OneriSiparisAdet >  2.0 THEN  2.0
                               WHEN (t.SiparisMiktar - o.OneriSiparisAdet) / o.OneriSiparisAdet < -1.0 THEN -1.0
                               ELSE (t.SiparisMiktar - o.OneriSiparisAdet) / o.OneriSiparisAdet END
                        END)) AS OrtSapmaYuzde,
                   -- Kırpılan satır sayısı ŞEFFAF (sessiz kırpma yasak): kaç talepte sapma +200%'ü aştı?
                   SUM(CASE WHEN o.StkId IS NOT NULL AND o.OneriSiparisAdet > 0
                             AND (t.SiparisMiktar - o.OneriSiparisAdet) / o.OneriSiparisAdet > 2.0
                        THEN 1 ELSE 0 END) AS UcSapma
            FROM DerinSISBkm.bkm.OneriSiparisTalep t WITH(NOLOCK)
            LEFT JOIN DerinSISBkm.bkm.OneriSiparis o WITH(NOLOCK)
                   ON o.Tarih = CAST(t.Tarih AS date) AND o.MekanId = t.MekanId AND o.StkId = t.StkId
            WHERE t.Tarih >= @BAS {haricFiltre}
            GROUP BY {kullaniciIfade}, t.MekanId
            HAVING COUNT(*) >= @MINTALEP
            ORDER BY COUNT(*) DESC;
            """;
        var p = new DynamicParameters();
        p.Add("BAS", a.AtifBaslangicEtkin);
        p.Add("MINTALEP", 10);   // <10 talep = tek-seferlik/gürültü, oran anlamsız
        await using var c = await db.OpenAsync();
        var rows = (await c.QueryAsync<AtifRow>(new CommandDefinition(sql, p, commandTimeout: 90))).ToList();
        foreach (var r in rows) r.SubeAd = r.MekanId switch { 1 => "FSM", 4477 => "Özlüce", 4478 => "İst.Yolu", 12 => "Depo", _ => r.MekanId.ToString() };
        logger.LogInformation("Atıf: {N} kullanıcı×şube (pencere {Bas}, {H} hesap hariç, {B} birleştirme)",
            rows.Count, a.AtifBaslangicEtkin, haric.Length, birlestir.Length);
        return rows;
    }
}
