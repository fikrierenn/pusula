using Dapper;
using GmDashboard.Models;

namespace GmDashboard.Data;

/// <summary>
/// EXCEL DETAY SAYFALARI — drill ekranının verdiği bilgiyi Excel'e taşır.
///
/// NEDEN (kullanıcı isteği 09.09.2026): "bu ekranın aynısını detay sayfası da dahil excelde
/// yapmak mümkün mü" + "excel i makrolar vs ile bu detaya ulaşır hale getirebilirz belki
/// satınalma ile paylaşmak için". İlk sürümde satır başına drill BAĞLANTISI konmuştu; kullanıcı
/// "ben excel içinde istiyorum" dedi — haklı: satınalma paneli açmadan çalışmak istiyor.
///
/// ⚠ MAKRO KULLANILMADI, bilinçli: (a) .xlsm çoğu kurulumda varsayılan bloklu ve e-posta/ağ
/// üzerinden gelince Mark-of-the-Web ile açılmıyor, (b) makronun veriye ulaşması için her
/// makinede DB kimlik bilgisi gerekir — panelin tek kontrollü bağlantısına göre güvenlik
/// geriye gider. Detay doğrudan SAYFALARA yazılır; satınalma makrosuz filtreler/pivotlar.
///
/// ⚠ HESAP ÇEKİRDEĞİ TEK YERDE (emitter-ayrimi kuralı): buradaki sorgular drill'in TEK-ÜRÜN
/// sorgularının küme bazlı ikizidir — aynı süzgeç, aynı kod kümeleri, aynı pencere. Tükenme
/// simülasyonu <see cref="UrunHiz.Tukenme"/> ile AYNI metottan geçer, kopyalanmaz.
///
/// Maliyet ölçüldü 09.09: küme bazlı son-5-fatura ağırlıklı birim 433.414 çeşit / 10,4 s.
/// Mağaza son satış 645.786 satır / 3,8 s · sezon hız 156.325 çeşit / 1,5 s.
/// </summary>
public sealed partial class SatisAnaliziQueries
{
    /// <summary>Drill'in türetilmiş ölçüleri — ürün başına tek satır.</summary>
    public async Task<IReadOnlyList<ExcelDetaySatir>> GetExcelDetayAsync(
        SatisAnaliziFiltre f, CancellationToken ct = default)
    {
        var (nerede, p) = Filtre(f);
        // ⚠ KesimP `bas`i TASIMAZ (yalniz kesim/sezon/taze/yeniGun) — 365 gunluk pencere
        // kullanan sorgular ONU AYRICA eklemek zorunda. Atlanınca "@bas bildirilmelidir" (137).
        p.Add("bas", f.Kesim.AddDays(-364).ToDateTime(TimeOnly.MinValue));
        p.Add("odakFrm", OdakTedarikciFrmId);

        // Sezon/sezon-dışı hız, merkez çıkışı, tedarik kaynağı, açık sipariş ve maliyet
        // ürün başına TEK satıra indirilir; taban satırıyla LEFT JOIN edilir.
        var sql = $"""
            WITH hedef AS (
                SELECT t.stkID, t.stkAd, t.Kategori3, t.SatisFiyat, t.MagazaStok, t.MerkezStok,
                       t.ToplamStok, t.SatisToplam, t.MerkezCikis, t.MerkezCikisGun,
                       t.IlkGiris, t.LeadTime
                FROM {Taban} t WITH (NOLOCK)
                WHERE {nerede}
            ),
            hiz AS (   -- sezon (Ağu-Eki) / sezon dışı adet; gün sayıları C# tarafında takvimden
                SELECT h.ehstkID AS stkID,
                       CONVERT(int, -SUM(CASE WHEN MONTH(h.ehTrhS) IN (8,9,10) THEN h.ehAdetN ELSE 0 END)) AS SezonAdet,
                       CONVERT(int, -SUM(CASE WHEN MONTH(h.ehTrhS) IN (8,9,10) THEN 0 ELSE h.ehAdetN END)) AS DisiAdet
                FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
                WHERE h.ehMekan IN (1, 4477, 4478)
                  AND h.ehTip IN (1, 3, 4, 5, 100, 101)
                  AND h.ehTrhS >= @bas AND h.ehTrhS < DATEADD(DAY, 1, @kesim)
                  AND h.ehstkID IN (SELECT stkID FROM hedef)
                GROUP BY h.ehstkID
            ),
            mlyt AS (  -- son 5 alış faturasının ağırlıklı birimi (drill ile AYNI tanım)
                SELECT x.stkID,
                       CONVERT(decimal(18,4), SUM(x.tutar) / NULLIF(SUM(x.adet), 0)) AS BirimMaliyet,
                       COUNT(*) AS FaturaSayisi, MAX(x.eTarih) AS SonAlis
                FROM (
                    SELECT fa.ehStkID AS stkID, f2.eID, f2.eTarih,
                           SUM(fa.ehAdetN) AS adet, SUM(fa.ehTutarN) AS tutar,
                           ROW_NUMBER() OVER (PARTITION BY fa.ehStkID
                                              ORDER BY f2.eTarih DESC, f2.eID DESC) AS sira
                    FROM DerinSISBkm.dbo.fatAyr fa WITH (NOLOCK)
                    JOIN DerinSISBkm.dbo.fat f2 WITH (NOLOCK) ON f2.eID = fa.ehID
                    WHERE f2.eTip = 0 AND f2.eDurum <> 2
                      AND fa.ehStkID IN (SELECT stkID FROM hedef)
                    GROUP BY fa.ehStkID, f2.eID, f2.eTarih
                ) x
                WHERE x.sira <= 5
                GROUP BY x.stkID
            ),
            tdrk AS (  -- ürünü ODAK'tan mı alıyoruz (leadTime'ın geçerliliği buna bağlı)
                SELECT fa.ehStkID AS stkID,
                       CONVERT(int, SUM(CASE WHEN f3.eFirma = @odakFrm THEN fa.ehAdetN ELSE 0 END)) AS OdakAdet,
                       CONVERT(int, SUM(CASE WHEN f3.eFirma <> @odakFrm THEN fa.ehAdetN ELSE 0 END)) AS DigerAdet
                FROM DerinSISBkm.dbo.fatAyr fa WITH (NOLOCK)
                JOIN DerinSISBkm.dbo.fat f3 WITH (NOLOCK) ON f3.eID = fa.ehID
                WHERE f3.eTip = 0 AND f3.eDurum <> 2
                  AND f3.eTarih >= @bas AND f3.eTarih <= DATEADD(DAY, 1, @kesim)
                  AND fa.ehStkID IN (SELECT stkID FROM hedef)
                GROUP BY fa.ehStkID
            ),
            kdv AS (
                SELECT u.stkID, CONVERT(int, k.kdvYuzdesi) AS Oran
                FROM DerinSISBkm.dbo.urn u WITH (NOLOCK)
                JOIN DerinSISBkm.dbo.kdvYuzde_vw k ON k.ilkKDVID = u.KDVs
                WHERE u.stkID IN (SELECT stkID FROM hedef)
            )
            SELECT h.stkID, h.stkAd, h.Kategori3, h.SatisFiyat,
                   h.MagazaStok, h.MerkezStok, h.ToplamStok, h.SatisToplam,
                   h.MerkezCikis, h.MerkezCikisGun, h.IlkGiris, h.LeadTime,
                   ISNULL(z.SezonAdet, 0) AS SezonAdet, ISNULL(z.DisiAdet, 0) AS DisiAdet,
                   m.BirimMaliyet, ISNULL(m.FaturaSayisi, 0) AS FaturaSayisi, m.SonAlis,
                   ISNULL(d.OdakAdet, 0) AS TedarikOdakAdet, ISNULL(d.DigerAdet, 0) AS TedarikDigerAdet,
                   v.Oran AS KdvOran
            FROM hedef h
            LEFT JOIN hiz  z ON z.stkID = h.stkID
            LEFT JOIN mlyt m ON m.stkID = h.stkID
            LEFT JOIN tdrk d ON d.stkID = h.stkID
            LEFT JOIN kdv  v ON v.stkID = h.stkID
            ORDER BY h.stkID
            """;
        await using var conn = await db.OpenAsync();
        return (await conn.QueryAsync<ExcelDetaySatir>(
            new CommandDefinition(sql, p, commandTimeout: 900, cancellationToken: ct))).ToList();
    }

    /// <summary>Mağaza × ürün: stok, satış, son satış tarihi, kaç gündür satmıyor.</summary>
    public async Task<IReadOnlyList<ExcelMagazaSatir>> GetExcelMagazaAsync(
        SatisAnaliziFiltre f, CancellationToken ct = default)
    {
        var (nerede, p) = Filtre(f);
        var sql = $"""
            WITH hedef AS (
                SELECT t.stkID, t.stkAd, t.StokFsm, t.StokOzl, t.StokIst,
                       t.SatisFsm, t.SatisOzl, t.SatisIst
                FROM {Taban} t WITH (NOLOCK)
                WHERE {nerede}
            ),
            son AS (   -- SON SATIŞ: iade (3/5/101) HARİÇ — iade satış değildir, tarihi ileri taşımaz
                SELECT h.ehstkID AS stkID, h.ehMekan AS Mekan, MAX(h.ehTrhS) AS SonSatis
                FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
                WHERE h.ehMekan IN (1, 4477, 4478) AND h.ehTip IN (1, 4, 100)
                  AND h.ehTrhS <= DATEADD(DAY, 1, @kesim)
                  AND h.ehstkID IN (SELECT stkID FROM hedef)
                GROUP BY h.ehstkID, h.ehMekan
            ),
            duz AS (
                SELECT stkID, stkAd, 1    AS Mekan, 'FSM'      AS MekanAd, StokFsm AS Stok, SatisFsm AS Satis FROM hedef
                UNION ALL
                SELECT stkID, stkAd, 4477 AS Mekan, 'Özlüce'   AS MekanAd, StokOzl AS Stok, SatisOzl AS Satis FROM hedef
                UNION ALL
                SELECT stkID, stkAd, 4478 AS Mekan, 'İst.Yolu' AS MekanAd, StokIst AS Stok, SatisIst AS Satis FROM hedef
            )
            SELECT d.stkID, d.stkAd, d.MekanAd, d.Stok, d.Satis,
                   s.SonSatis,
                   CASE WHEN s.SonSatis IS NULL THEN NULL
                        ELSE CONVERT(int, DATEDIFF(DAY, s.SonSatis, @kesim)) END AS GunOnce
            FROM duz d
            LEFT JOIN son s ON s.stkID = d.stkID AND s.Mekan = d.Mekan
            ORDER BY d.stkID, d.Mekan
            """;
        await using var conn = await db.OpenAsync();
        return (await conn.QueryAsync<ExcelMagazaSatir>(
            new CommandDefinition(sql, p, commandTimeout: 900, cancellationToken: ct))).ToList();
    }

    /// <summary>
    /// MERKEZ DEPO ADRESLERİ — ürün hangi hücrede/palette (kullanıcı isteği 09.09:
    /// "merkez depo stoğunda ürünler hangi adreslerde görebilir miyiz").
    ///
    /// Kaynak WMS hücresel stok (<c>depo.stok_adres_palet_vw</c>) — merkez stoğunun KANONİK
    /// kaynağı; ERP defteri (mekan 12) negatif taşıdığı için kullanılmaz.
    /// Alan tipleri ölçüldü 09.09: RAF 3.811.300 adet / 21.850 çeşit · ÇIKIŞ 538.614 / 12.071 ·
    /// GİRİŞ 180.916 / 4.414. ⚠ <b>ÇIKIŞ ALANI MerkezStok'a GİRMEZ</b> (sevke hazırlanmış mal)
    /// → tabloda görünür ama toplamla farkı bu; sütunda işaretlenir.
    /// Yayılım: ürün ortalama 1,8 adreste, en çok 27; 1.217 çeşit 5'ten fazla adreste.
    ///
    /// Palet giriş tarihi <c>depo.paletIcHrk</c>'dan. ⚠ YÖN KANITLANDI 09.09: <c>piİlkID</c>
    /// hareketin SAHİBİ palet, <c>piSonID</c> karşı palet — iki hipotez view ile karşılaştırıldı,
    /// yalnız bu tuttu (stkID 235636: palet 37250 → 2, palet 230598 → 3, view ile birebir).
    /// <c>pGC</c> 0=giriş (780.009 satır, hepsi pozitif) · 1=çıkış (979.868'i negatif).
    /// </summary>
    public async Task<IReadOnlyList<ExcelAdresSatir>> GetExcelAdresAsync(
        SatisAnaliziFiltre f, CancellationToken ct = default)
    {
        var (nerede, p) = Filtre(f);
        var sql = $"""
            WITH hedef AS (
                SELECT t.stkID, t.stkAd FROM {Taban} t WITH (NOLOCK) WHERE {nerede}
            )
            SELECT h.stkID, h.stkAd,
                   ISNULL(a.alanTipAd, CONVERT(varchar(20), d.adrsAlanTipID)) AS AlanTip,
                   CASE WHEN d.adrsAlanTipID IN (0, 1) THEN 1 ELSE 0 END AS MerkezStokaGiriyor,
                   d.adrsAd AS Adres, d.PaletID, CONVERT(int, d.Stok) AS Adet,
                   (SELECT MAX(pi.pikTarih) FROM DerinSISBkm.depo.paletIcHrk pi WITH (NOLOCK)
                    WHERE pi.piStkID = d.stkID AND pi.piİlkID = d.PaletID AND pi.pGC = 0) AS PaleteGiris
            FROM DerinSISBkm.depo.stok_adres_palet_vw d WITH (NOLOCK)
            JOIN hedef h ON h.stkID = d.stkID
            LEFT JOIN DerinSISBkm.depo.adresAlanTip a ON a.alanTipID = d.adrsAlanTipID
            WHERE d.Stok <> 0
            ORDER BY h.stkID, d.adrsAlanTipID, d.adrsAd
            """;
        await using var conn = await db.OpenAsync();
        return (await conn.QueryAsync<ExcelAdresSatir>(
            new CommandDefinition(sql, p, commandTimeout: 900, cancellationToken: ct))).ToList();
    }

    /// <summary>ODAK tedarikçi cari kimliği (frm 9525 = ODAK KİTAP-POİNT). Sema: alımın ~%40'ı.</summary>
    private const int OdakTedarikciFrmId = 9525;
}

/// <summary>Excel "Detay" sayfası — ham sütunlar; türetilmiş ölçüler C# tarafında hesaplanır.</summary>
public sealed record ExcelDetaySatir(
    int StkId, string StkAd, string? Kategori3, decimal SatisFiyat,
    int MagazaStok, int MerkezStok, int ToplamStok, int SatisToplam,
    int MerkezCikis, int MerkezCikisGun, DateTime? IlkGiris, int? LeadTime,
    int SezonAdet, int DisiAdet,
    decimal? BirimMaliyet, int FaturaSayisi, DateTime? SonAlis,
    int TedarikOdakAdet, int TedarikDigerAdet, int? KdvOran);

/// <summary>Excel "Mağaza" sayfası — ürün × mağaza.</summary>
public sealed record ExcelMagazaSatir(
    int StkId, string StkAd, string MekanAd, int Stok, int Satis,
    DateTime? SonSatis, int? GunOnce);

/// <summary>Excel "Depo Adres" sayfası — ürün × WMS hücresi/paleti.</summary>
public sealed record ExcelAdresSatir(
    int StkId, string StkAd, string AlanTip, int MerkezStokaGiriyor,
    string? Adres, int? PaletID, int Adet, DateTime? PaleteGiris);
