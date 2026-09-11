using System.Globalization;
using Microsoft.Extensions.Caching.Memory;
using Dapper;
using GmDashboard.Models;

namespace GmDashboard.Data;

/// <summary>
/// SİPARİŞ ÖNERİSİ ÇEKİRDEĞİ (plan-46) — "kaç tane alırım" hesabının TEK yeri.
///
/// Kardeş emitter: <c>scripts/siparis_onerisi_excel.py</c> (Excel + tedarikçi kırılımı).
/// İkisi AYRIŞMAMALI; formül burada ve orada BİREBİR aynıdır (emitter-ayrimi).
/// Skill: <c>.claude/skills/siparis-karari/SKILL.md</c> — miktar + taahhüt + çıkış planı.
///
/// ═══ HESAP ═══════════════════════════════════════════════════════════════════
///   win          = LeadTime + 30                 (30 gün = aylık sipariş turu)
///   düz kapak    = (Satis365 / 365) × win
///   sezon talebi = (Ay1×fAğu + Ay2×fEyl + Ay3×fEki) × kategoriOranı
///                  f = pencerenin o aya düşen gün payı, pencere [kesim, kesim+win)
///   kapak        = max(düz kapak, sezon talebi)
///   emniyet      = z × √(CV² / SatanAy) × kapak ; tavan kapak (düz) · 0,25×kapak (sezon)
///   öneri        = ceil(kapak + emniyet − ToplamStok) ≥ 0, kategori tavanıyla kırpılır
///   z            = 1,65 Kırtasiye/Elektronik · 1,04 diğer
///   KOHORT       = öneri &gt; 0
///
/// ═══ NEDEN BÖYLE — üçü de ölçüldü (11.09.2026) ═══════════════════════════════
/// 1) Kohort "stok = 0" iken gerçek ihtiyacın ~1/13'ünü görüyordu: Kırtasiye'de 796 çeşit
///    gösterirken kapağın altına düşmüş 1.687 çeşit / 14.528 adet vardı. Perakende
///    siparişinin GÖVDESİ "stoğu var ama yetersiz"tir; stok=0 onun yalnız uç hâli.
/// 2) Düz 365g hızı SEZON ürününde talebi 4 KAT az sayıyor. Kırtasiye sezon-yoğun 285 çeşit,
///    50 günlük pencere: düz 7.257 adet · geçen yılın aynı penceresi 29.057. Aylık dağılım
///    Ağu 10.510 · <b>Eyl 29.193</b> · Eki 10.437 — zirve EYLÜL ve <c>Satis365</c> penceresi
///    (09.09.2025→09.09.2026) onu dışarıda bırakıyor. Bağımsız doğrulama (irsHrk):
///    Maxx Mx-616 → Eyl-2025 1.617 · Eki-2025 20 · son 365 gün 484.
/// 3) "Geçen yıl kadar al" bir VARSAYIM. Bu yıl/geçen yıl aynı takvim penceresi ölçüldü:
///    Kırtasiye <b>0,82</b> · Oyuncak 1,50 · Hediyelik 1,25 · Elektronik 0,88 →
///    Kırtasiye'de geçen yılı birebir sipariş etmek %18 fazla almaktır.
/// 4) Sezon sonunda emniyet stoğu TERS çalışır: eksik almanın bedeli kaçan satış, fazlanın
///    bedeli ÖLÜ STOK (mal gelecek sezona kalır, kırtasiyede model/desen değişir) → %25 tavan.
///
/// ⚠ ÖNERİ, SİPARİŞ DEĞİLDİR: MOQ/koli katı veride yok · tedarikçi iade hakkı izli değil
///   (kesin alım varsayıldı) · talep tahmini sağdan sansürlü, yani ALT SINIR.
/// ⚠ Açık sipariş (yolda mal) DÜŞÜLMEZ — kullanıcı direktifi 10.09.2026:
///   <i>"yeni gelen sezon siparişlerini var olarak görme"</i>.
/// </summary>
public sealed partial class SatisAnaliziQueries
{
    /// <summary>Gözden geçirme aralığı (gün) — aylık sipariş turu varsayımı.</summary>
    private const string SiparisGozdenGecirme = "30";

    /// <summary>Kapak penceresi (gün) = temin süresi + gözden geçirme. LeadTime NULL → 7.</summary>
    private const string SiparisPencereGun =
        "(CONVERT(int, ISNULL(t.LeadTime, 7)) + " + SiparisGozdenGecirme + ")";

    /// <summary>Günlük düz hız (365 günlük satış). Sezon ürününde YETERSİZ — sınıf özeti §2.</summary>
    private const string SiparisDuzHiz = "(CONVERT(float, t.SatisToplam) / 365.0)";

    private const string SiparisDuzKapak = "(" + SiparisDuzHiz + " * " + SiparisPencereGun + ")";

    /// <summary>Hizmet düzeyi z. Tek global değer YOK: ölçülen kategori devri 1,25–5,95 arası.</summary>
    private const string SiparisZ =
        "(CASE WHEN t.Kategori3 IN (N'Kırtasiye', N'Elektronik') THEN 1.65 ELSE 1.04 END)";

    /// <summary>Oranın güvenilir sayılması için bu yıl gereken en az adet.</summary>
    private const int SiparisOranTaban = 200;

    /// <summary>
    /// SİPARİŞ KAYNAĞI — taban + adım adım hesap (CROSS APPLY zinciri).
    ///
    /// ⚠ NEDEN ADIM ADIM (ölçüldü 11.09.2026, İKİ KEZ): ifadeleri iç içe yazınca
    /// (a) KPI sorgusunda <c>kapak</c> 40+ kez tekrarlanıyordu, (b) ayrı sorguya alınca bile
    /// ay-örtüşmesi zinciri SQL Server'ın <b>8632 "deyim hizmetleri sınırına ulaşıldı"</b>
    /// sınırını aşıyordu ve panel HİÇ açılmadı. Build ikisini de yakalamadı — "derlendi"
    /// çalıştığı anlamına gelmiyor. Her adım satır başına BİR kez hesaplanır ve bir sonraki
    /// adım önceki takma adı OKUR, ifadeyi yeniden yazmaz.
    ///
    /// Takvim matematiği C#'ta (<c>KesimP</c>: @pbas · @a8 · @a9 · @a10 · @a11).
    /// Kullanımı: <c>FROM {Taban} t WITH (NOLOCK) {SiparisKaynak(oran)}</c> → <c>sp.Oneri</c>.
    /// </summary>
    public static string SiparisKaynak(string oran) => $"""
        CROSS APPLY (SELECT Win = CONVERT(int, ISNULL(t.LeadTime, 7)) + {SiparisGozdenGecirme}) w
        CROSS APPLY (SELECT PSon = DATEADD(DAY, w.Win, @pbas)) w2
        CROSS APPLY (SELECT
                AguGun = DATEDIFF(DAY, CASE WHEN @a8  > @pbas THEN @a8  ELSE @pbas END,
                                       CASE WHEN @a9  < w2.PSon THEN @a9  ELSE w2.PSon END),
                EylGun = DATEDIFF(DAY, CASE WHEN @a9  > @pbas THEN @a9  ELSE @pbas END,
                                       CASE WHEN @a10 < w2.PSon THEN @a10 ELSE w2.PSon END),
                EkiGun = DATEDIFF(DAY, CASE WHEN @a10 > @pbas THEN @a10 ELSE @pbas END,
                                       CASE WHEN @a11 < w2.PSon THEN @a11 ELSE w2.PSon END)) g
        CROSS APPLY (SELECT SezonTalep =
                (CONVERT(float, ISNULL(t.Ay1, 0)) * CASE WHEN g.AguGun > 0 THEN g.AguGun / 31.0 ELSE 0 END
               + CONVERT(float, ISNULL(t.Ay2, 0)) * CASE WHEN g.EylGun > 0 THEN g.EylGun / 30.0 ELSE 0 END
               + CONVERT(float, ISNULL(t.Ay3, 0)) * CASE WHEN g.EkiGun > 0 THEN g.EkiGun / 31.0 ELSE 0 END)
                * {oran},
                DuzKapak = (CONVERT(float, t.SatisToplam) / 365.0) * w.Win) a1
        CROSS APPLY (SELECT Kapak = CASE WHEN a1.SezonTalep > a1.DuzKapak
                                        THEN a1.SezonTalep ELSE a1.DuzKapak END,
                            Sezonlu = CASE WHEN a1.SezonTalep > a1.DuzKapak THEN 1 ELSE 0 END) a2
        CROSS APPLY (SELECT EmnHam = {SiparisZ} * SQRT(CONVERT(float, ISNULL(t.TalepCV2, 1.0))
                                 / CONVERT(float, CASE WHEN ISNULL(t.SatanAy, 0) < 1 THEN 1
                                                       ELSE t.SatanAy END)) * a2.Kapak,
                            EmnTavan = a2.Kapak * CASE WHEN a2.Sezonlu = 1 THEN 0.25 ELSE 1.0 END) a3
        CROSS APPLY (SELECT Emniyet = CASE WHEN a3.EmnHam > a3.EmnTavan
                                          THEN a3.EmnTavan ELSE a3.EmnHam END) a4
        CROSS APPLY (SELECT Ham = CEILING(a2.Kapak + a4.Emniyet - CONVERT(float, t.ToplamStok)),
                            Tavan = {SiparisTavan}) a5
        CROSS APPLY (SELECT Kapak = CONVERT(int, CEILING(a2.Kapak + a4.Emniyet)),
                            Sezonlu = a2.Sezonlu,
                            Oneri = CONVERT(int, CASE WHEN a5.Ham <= 0 THEN 0
                                WHEN a5.Tavan IS NOT NULL AND a5.Ham > a5.Tavan THEN a5.Tavan
                                ELSE a5.Ham END)) sp
        """;

    /// <summary>Kategori tavanı: aşırı stok eşiği × sezon satışı − eldeki stok. Aşılamaz.</summary>
    private static string SiparisTavan =>
        "(CASE WHEN t.SezonToplam > 0 THEN " +
        "(CASE WHEN " + AsiriStokKatSql + " * t.SezonToplam - t.ToplamStok > 0 " +
        "THEN " + AsiriStokKatSql + " * t.SezonToplam - t.ToplamStok ELSE 0 END) END)";

    /// <summary>ÖNERİ ADEDİ — kohort tanımı da budur (&gt; 0). APPLY'dan okunur.</summary>
    public const string SiparisOneriSql = "sp.Oneri";

    /// <summary>Kohort şartı — kart, filtre ve liste AYNI ifadeyi kullanır.</summary>
    public const string SiparisSart =
        "(t.SatisToplam >= 5 AND " + DefterGuvenilirSart + " AND sp.Oneri > 0)";

    /// <summary>ACİL: sipariş gerekiyor VE hiç stok yok — kayıp ZATEN yaşanıyor.</summary>
    public const string SiparisAcilSart = "(" + SiparisSart + " AND t.ToplamStok <= 0)";

    /// <summary>Önerinin maliyeti — bağlanacak para. Birim maliyeti olmayan çeşitte 0 (eksik).</summary>
    public const string SiparisMaliyetSql = "(sp.Oneri * ISNULL(t.BirimMaliyet, 0))";

    /// <summary>Ekran etiketi: rakam düz hızdan mı sezon penceresinden mi geldi.</summary>
    public const string SiparisTabanEtiketSql =
        "(CASE WHEN sp.Sezonlu = 1 THEN N'sezon penceresi' ELSE N'365g düz' END)";

    /// <summary>Kapak (emniyet dahil) — eldeki stok bunun altındaysa ürün kohorta girer.</summary>
    public const string SiparisKapakSql = "sp.Kapak";

    /// <summary>
    /// SİPARİŞ ÖZETİ — KPI kartının beş sayısı (çeşit · adet · maliyet · ACİL çeşit/adet).
    ///
    /// ⚠ NEDEN AYRI SORGU: KPI sorgusu 56 agregayla zaten sınırdaydı; sipariş ifadeleri
    /// eklenince SQL Server <b>8632 "deyim hizmetleri sınırına ulaşıldı"</b> hatası verdi ve
    /// panel HİÇ açılmadı (ölçüldü 11.09.2026 — build yeşildi, hata yalnız çalışma anında
    /// çıktı; "derlendi = çalışıyor" değil).
    /// </summary>
    public async Task<SiparisOzet> SiparisOzetAsync(
        System.Data.Common.DbConnection conn, SatisAnaliziFiltre f, CancellationToken ct = default)
    {
        var oran = SiparisOranSql(await SiparisOranAsync(f, ct));
        var sql = $"""
            SELECT COUNT(*)                                            AS Cesit,
                   CONVERT(bigint, ISNULL(SUM(sp.Oneri), 0))           AS Adet,
                   CONVERT(decimal(18,2), ISNULL(SUM({SiparisMaliyetSql}), 0)) AS Maliyet,
                   SUM(CASE WHEN t.ToplamStok <= 0 THEN 1 ELSE 0 END)  AS AcilCesit,
                   CONVERT(bigint, ISNULL(SUM(CASE WHEN t.ToplamStok <= 0
                        THEN sp.Oneri ELSE 0 END), 0))                 AS AcilAdet
            FROM {Taban} t WITH (NOLOCK)
            {SiparisKaynak(oran)}
            WHERE t.Kesim = @kesim AND t.SezonYil = @sezon{TazeSart(f)}
              AND {SiparisSart}
            """;
        return await conn.QuerySingleAsync<SiparisOzet>(new CommandDefinition(sql, KesimP(f),
            commandTimeout: 120, cancellationToken: ct));
    }

    /// <summary>KPI kartının beş sayısı — sıfır satır dönerse hepsi 0 (COUNT/SUM garantisi).</summary>
    public sealed record SiparisOzet(int Cesit, long Adet, decimal Maliyet, int AcilCesit, long AcilAdet);

    /// <summary>
    /// KATEGORİ YIL ORANI — bu yıl / geçen yıl AYNI takvim penceresi (1 Ağu → kesim).
    ///
    /// ⚠ "Geçen yıl kadar al" bir VARSAYIMDIR; bu ölçüm onu sayıya çevirir. Ölçüldü
    /// 11.09.2026: Kırtasiye <b>0,82</b> · Oyuncak 1,50 · Hediyelik 1,25 · Elektronik 0,88.
    /// Bu yıl <see cref="SiparisOranTaban"/> adedin altında satmış kategoride oran
    /// GÜVENİLMEZ sayılır ve 1,0 alınır (uydurma yok). Kapsam taban <c>SatisToplam</c> ile
    /// AYNI: mağaza satışı, ehTip 1/3/4/5/100/101, mekan 1/4477/4478.
    ///
    /// ⚠ NEDEN CTE DEĞİL: liste sorgusu sayfa başına koşar; oranı her sayfada yeniden ölçmek
    /// <c>irsHrk</c>'yı 13 aylık pencereyle taratır. Kesim başına BİR kez ölçülür, cache'lenir
    /// ve SQL'e literal CASE olarak gömülür. Değerler ÖLÇÜMDEN gelir (kullanıcı girdisi değil);
    /// kategori adı <see cref="Kategori3Evreni"/> ile sınırlanır, sayı invariant biçimle yazılır.
    /// </summary>
    public async Task<IReadOnlyDictionary<string, double>> SiparisOranAsync(
        SatisAnaliziFiltre f, CancellationToken ct = default)
    {
        var anahtar = $"siparis-oran-{f.Kesim:yyyyMMdd}";
        if (cache.TryGetValue(anahtar, out object? onbellek)
            && onbellek is IReadOnlyDictionary<string, double> hazir)
            return hazir;

        const string sql = """
            SELECT ub.Kategori3 AS Kategori,
                   CONVERT(bigint, SUM(CASE WHEN h.ehTrhS >= DATEFROMPARTS(YEAR(@kesim), 8, 1)
                        AND h.ehTrhS <= @kesim THEN -h.ehAdetN ELSE 0 END)) AS BuYil,
                   CONVERT(bigint, SUM(CASE WHEN h.ehTrhS >= DATEFROMPARTS(YEAR(@kesim) - 1, 8, 1)
                        AND h.ehTrhS <= DATEADD(YEAR, -1, @kesim) THEN -h.ehAdetN ELSE 0 END)) AS GecenYil
            FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
            JOIN DerinSISBkm.bkm.UrunBilgi ub WITH (NOLOCK) ON ub.stkID = h.ehstkID
            WHERE h.ehMekan IN (1, 4477, 4478) AND h.ehTip IN (1, 3, 4, 5, 100, 101)
              AND h.ehTrhS >= DATEFROMPARTS(YEAR(@kesim) - 1, 8, 1)
            GROUP BY ub.Kategori3
            """;

        await using var conn = await db.OpenAsync();
        var satirlar = (await conn.QueryAsync<OranSatir>(new CommandDefinition(sql,
            new { kesim = f.Kesim.ToDateTime(TimeOnly.MinValue) },
            commandTimeout: 120, cancellationToken: ct))).ToList();

        var sonuc = new Dictionary<string, double>(StringComparer.Ordinal);
        foreach (var r in satirlar)
        {
            if (string.IsNullOrEmpty(r.Kategori) || r.BuYil < SiparisOranTaban || r.GecenYil <= 0)
                continue;
            sonuc[r.Kategori] = (double)r.BuYil / r.GecenYil;
        }

        logger.LogInformation("Sipariş yıl oranı ölçüldü ({N} kategori): {Oran}", sonuc.Count,
            string.Join(" · ", sonuc.Select(x => $"{x.Key} {x.Value:0.00}")));
        cache.Set(anahtar, (IReadOnlyDictionary<string, double>)sonuc, TimeSpan.FromMinutes(30));
        return sonuc;
    }

    private sealed record OranSatir(string Kategori, long BuYil, long GecenYil);

    /// <summary>Ölçülen oranın SQL karşılığı. Ölçülmemiş kategori 1,0 (nötr).</summary>
    public static string SiparisOranSql(IReadOnlyDictionary<string, double> oranlar)
    {
        var parcalar = oranlar
            .Where(x => Kategori3Evreni.Contains(x.Key))
            .Select(x => $"WHEN N'{x.Key.Replace("'", "''")}' THEN " +
                         x.Value.ToString("0.0000", CultureInfo.InvariantCulture))
            .ToList();
        return parcalar.Count == 0 ? "1.0" : $"(CASE t.Kategori3 {string.Join(" ", parcalar)} ELSE 1.0 END)";
    }
}
