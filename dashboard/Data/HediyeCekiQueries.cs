using Dapper;
using GmDashboard.Models;

namespace GmDashboard.Data;

/// <summary>
/// Hediye Çeki paneli — plan-36. SALT-OKUMA (erp-write-policy.md).
/// Çekirdek sorgular <c>sorgular/2026-08-25-hediye-ceki-karlilik-indirim.sql</c> (18 blok, canlı
/// doğrulanmış); bu sınıf dashboard EMITTER'ıdır — iş mantığı burada ÇOĞALTILMAZ (emitter-ayrimi.md).
///
/// ZORUNLU KURALLAR (2026-08-25 keşif dersleri — hepsi canlı doğrulandı):
/// • <b>3-parçalı isim</b> — <c>Db.OpenAsync()</c> varsayılan katalog <c>master</c>; 2-parçalı isim Err 208.
/// • <b>Kanal toplamı irsHrk'den</b> — POS-only ölçüm hacmi ~3 kat eksik gösterir (satış faturası %55).
/// • <b>fatAyr.ehTutarN eTip=4'te KULLANILMAZ</b> — beslenmiyor (net=0 oranı %65→%77, 4 yıllık).
///   Fatura kanalı indiriminde <c>ehTutar</c>/<c>ehIndirim</c> kullanılır, <c>eTip=1</c> ile sınırlı.
/// • <b>Geri dönüşüm ayıklaması İKİ KOŞULLU</b> — <c>RefundReasonId &lt;&gt; 12</c> VE
///   <c>Products.Code &lt;&gt; '583160'</c>. Tek koşul yetmez: SKU 416 satırda yanlış sebep koduyla,
///   12 satırda DocType=1 (satış!) ile geçmiş.
/// • <b>Çek SKU'ları marj hesabından hariç</b> — <c>KatAna &lt;&gt; N'Hediye Çeki'</c> (avans, stok değil).
/// • <b>İADE ÇEKİ (PaymentTypesId=10) DEĞİL</b> — hediye çeki tip 11. Tip 10 geri dönüşüm/iade çeki
///   (15,1 M₺); toplanırsa analiz ~6 kat şişer.
/// • <b>İade sign'ı</b> — <c>DocumentsTypeId=3</c> negatif; indirim yalnız <c>DiscountTotalDirect</c>.
///
/// PERF KARARI (plan-36 §4): dilim × stkID üzerinde fat5 OUTER APPLY ~54K çağrı → zaman aşımı.
/// Bu yüzden <see cref="GetBaremKalemAsync"/> (fat5 YOK, hızlı) ve <see cref="GetMaliyetAsync"/>
/// (distinct stkID × fat5, ~15 s) AYRI çalışır; <c>adet × birim maliyet</c> çarpımı panelde yapılır.
/// Emitter'da kalan yalnız ARİTMETİK — grain, filtre ve maliyet şelalesi SQL'de.
/// </summary>
public sealed class HediyeCekiQueries(Db db, ILogger<HediyeCekiQueries> logger)
{
    /// <summary>Hediye çeki ürünlerinin stkID kümesi. Kategori üstünden — kupür SKU'ları
    /// (50/100/200/500/750/1.000 ₺ + açık tutarlı) zamanla değişir, hardcode liste bayatlar.</summary>
    private const string CekStkFiltre = """
        SELECT u.stkID FROM DerinSISBkm.dbo.urn u WITH(NOLOCK)
        JOIN DerinSISBkm.dbo.urnKtgr2 k WITH(NOLOCK) ON k.ktgrID = u.urnKtgr2ID
        WHERE k.ktgrAd = N'Hediye Çeki'
        """;

    /// <summary>Çek dilimi (barem) CASE — payda ve kalem sorgularında AYNI olmak zorunda.</summary>
    private const string DilimCase = """
        CASE WHEN hc.HcTutar <=  100 THEN 1
             WHEN hc.HcTutar <=  250 THEN 2
             WHEN hc.HcTutar <=  500 THEN 3
             WHEN hc.HcTutar <= 1000 THEN 4
             WHEN hc.HcTutar <= 2500 THEN 5
             ELSE 6 END
        """;

    /// <summary>Fiş başına toplam çek tahsilatı. IsChangeAmount=0 ZORUNLU (=1 para üstü).</summary>
    private const string HcFisToplam = """
        SELECT SalesId, SUM(Amount) AS HcTutar
        FROM EncoreMerkez.dbo.SalesPayments WITH(NOLOCK)
        WHERE PaymentTypesId = 11 AND IsChangeAmount = 0
        GROUP BY SalesId
        """;

    /// <summary>Geri dönüşüm ayıklaması — İKİ koşul birden (bkz. sınıf yorumu).</summary>
    private const string GeriDonusumHaric = """
        AND sp.RefundReasonId <> 12
        AND p.Code <> '583160'
        """;

    // ── 1) Kanal kırılımı (arşiv blok 9) ────────────────────────────────────────

    /// <summary>Çek satış/çıkış kanalı. Tek doğru kaynak irsHrk — POS azınlık kanal.</summary>
    public async Task<List<HcKanal>> GetKanalAsync(DateOnly bas, DateOnly bit)
    {
        await using var conn = await db.OpenAsync();
        var rows = await conn.QueryAsync<HcKanal>($"""
            SELECT CAST(h.ehTip AS int) AS Tip, t.tipAD AS TipAd, COUNT(*) AS Satir,
                   SUM(h.ehAdetN) AS Adet, SUM(h.ehTutarN) AS TutarNet
            FROM DerinSISBkm.dbo.irsHrk h WITH(NOLOCK)
            JOIN DerinSISBkm.dbo.irsTip_vw t WITH(NOLOCK) ON t.tipID = h.ehTip
            WHERE h.ehTrhS >= @bas AND h.ehTrhS < @bit
              AND h.ehstkID IN ({CekStkFiltre})
            GROUP BY h.ehTip, t.tipAD
            """, new { bas, bit }, commandTimeout: 60);
        return rows.OrderByDescending(r => r.TutarNet).ToList();
    }

    // ── 2) Kullanım (arşiv blok 3) ──────────────────────────────────────────────

    /// <summary>POS çek tahsilatı + yuvarlak/kusurlu ayrımı. Yuvarlak = basılı kupür,
    /// kusurlu = kısmi harcama artığı (bonus tasarımında bu davranış kullanılamaz).</summary>
    public async Task<HcKullanim> GetKullanimAsync(DateOnly bas, DateOnly bit)
    {
        await using var conn = await db.OpenAsync();
        return await conn.QuerySingleAsync<HcKullanim>("""
            SELECT COUNT(*) AS Hareket,
                   ISNULL(SUM(pt.Amount), 0) AS Tutar,
                   ISNULL(SUM(CASE WHEN pt.Amount % 50 = 0 THEN pt.Amount ELSE 0 END), 0) AS YuvarlakTutar,
                   ISNULL(SUM(CASE WHEN pt.Amount % 50 <> 0 THEN pt.Amount ELSE 0 END), 0) AS KusurluTutar
            FROM EncoreMerkez.dbo.SalesPayments pt WITH(NOLOCK)
            JOIN EncoreMerkez.dbo.Sales s WITH(NOLOCK) ON s.Id = pt.SalesId
            WHERE pt.PaymentTypesId = 11 AND pt.IsChangeAmount = 0
              AND s.DocumentsTypeId IN (1, 2, 6, 7, 8)
              AND s.Date >= @bas AND s.Date < @bit
            """, new { bas, bit }, commandTimeout: 60);
    }

    // ── 3) Barem (arşiv blok 16 / 16b) ──────────────────────────────────────────

    /// <summary>Barem paydası — dilim bazlı fiş/çek/sepet. SepetOdenen KDV-DAHİL gerçek tahsilat
    /// (kaldıraç oranı için doğru taban); net'e çevirmek oranı bozar.</summary>
    public async Task<List<HcBaremPayda>> GetBaremPaydaAsync(DateOnly bas, DateOnly bit)
    {
        await using var conn = await db.OpenAsync();
        var rows = await conn.QueryAsync<HcBaremPayda>($"""
            SELECT {DilimCase} AS Dilim,
                   COUNT(*) AS Fis,
                   SUM(hc.HcTutar) AS HcOdenen,
                   AVG(hc.HcTutar) AS OrtCek,
                   SUM(CASE WHEN s.DocumentsTypeId = 3 THEN -(s.GrossTotal - s.DiscountTotal)
                            ELSE (s.GrossTotal - s.DiscountTotal) END) AS SepetOdenen
            FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
            JOIN ({HcFisToplam}) hc ON hc.SalesId = s.Id
            WHERE s.DocumentsTypeId IN (1, 3) AND s.Date >= @bas AND s.Date < @bit
            GROUP BY {DilimCase}
            """, new { bas, bit }, commandTimeout: 60);
        return rows.OrderBy(r => r.Dilim).ToList();
    }

    /// <summary>Barem kalemleri — dilim × ürün × kategori. Maliyet YOK (perf: sınıf yorumu).
    /// Kategori marj tablosu da bu veriden türer (tek çekim, iki bölüm).</summary>
    public async Task<List<HcBaremKalem>> GetBaremKalemAsync(DateOnly bas, DateOnly bit)
    {
        await using var conn = await db.OpenAsync();
        var rows = await conn.QueryAsync<HcBaremKalem>($"""
            SELECT {DilimCase} AS Dilim,
                   CONVERT(int, p.Code) AS StkID,
                   ISNULL(ub.KatAna, N'Tanımsız') AS KatAna,
                   SUM(CASE WHEN s.DocumentsTypeId = 3 THEN -sp.Amount ELSE sp.Amount END) AS Adet,
                   SUM(CASE WHEN s.DocumentsTypeId = 3 THEN -(sp.TotalPrice + sp.DiscountTotalDirect)
                            ELSE (sp.TotalPrice + sp.DiscountTotalDirect) END) AS Brut,
                   SUM(CASE WHEN s.DocumentsTypeId = 3 THEN -sp.DiscountTotalDirect
                            ELSE sp.DiscountTotalDirect END) AS Indirim,
                   SUM(CASE WHEN s.DocumentsTypeId = 3 THEN -(sp.TotalPrice - sp.VatTotal)
                            ELSE (sp.TotalPrice - sp.VatTotal) END) AS Net
            FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
            JOIN EncoreMerkez.dbo.SalesProducts sp WITH(NOLOCK) ON sp.SalesId = s.Id AND sp.IsValid = 1
            JOIN EncoreMerkez.dbo.Products p WITH(NOLOCK) ON p.Id = sp.ProductsId
            JOIN DerinSISBkm.bkm.UrunBilgi ub WITH(NOLOCK) ON ub.stkID = CONVERT(int, p.Code)
            JOIN ({HcFisToplam}) hc ON hc.SalesId = s.Id
            WHERE s.DocumentsTypeId IN (1, 3) AND s.Date >= @bas AND s.Date < @bit
              AND ISNUMERIC(p.Code) = 1
              AND ub.KatAna <> N'Hediye Çeki'
              {GeriDonusumHaric}
            GROUP BY {DilimCase}, CONVERT(int, p.Code), ub.KatAna
            """, new { bas, bit }, commandTimeout: 120);
        return rows.ToList();
    }

    /// <summary>fat5 birim maliyet — KANONİK (sema birim_maliyet.MLYT): son 5 alış faturası
    /// SUM(ehTutarN)/SUM(ehAdetN), DerinSIS + ODAK_FATURA birleşik. Tarih çıpası pencere sonu.
    /// ⚠ En pahalı sorgu (~9K stkID × OUTER APPLY ≈ 15 s) — panelde cache'lenir.
    /// ODAK istisnası: eFirma 9525 için 01.09.2022 öncesi hariç (grup-içi devir kirliliği).</summary>
    public async Task<List<HcMaliyet>> GetMaliyetAsync(DateOnly bas, DateOnly bit)
    {
        await using var conn = await db.OpenAsync();
        var rows = await conn.QueryAsync<HcMaliyet>("""
            SELECT d.StkID, MLYT.Birim
            FROM (
                SELECT DISTINCT CONVERT(int, p.Code) AS StkID
                FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
                JOIN EncoreMerkez.dbo.SalesProducts sp WITH(NOLOCK) ON sp.SalesId = s.Id AND sp.IsValid = 1
                JOIN EncoreMerkez.dbo.Products p WITH(NOLOCK) ON p.Id = sp.ProductsId
                WHERE s.DocumentsTypeId IN (1, 3) AND s.Date >= @bas AND s.Date < @bit
                  AND ISNUMERIC(p.Code) = 1
                  AND s.Id IN (SELECT SalesId FROM EncoreMerkez.dbo.SalesPayments WITH(NOLOCK)
                               WHERE PaymentTypesId = 11 AND IsChangeAmount = 0)
            ) d
            OUTER APPLY (
                SELECT CONVERT(money, SUM(b.tut) / NULLIF(SUM(b.adt), 0)) AS Birim
                FROM (
                    SELECT TOP 5 ML.tut, ML.adt
                    FROM (
                        SELECT TOP 5 f.eTarih AS trh, fa.ehTutarN AS tut, fa.ehAdetN AS adt
                        FROM DerinSISBkm.dbo.fatAyr fa WITH(NOLOCK)
                        JOIN DerinSISBkm.dbo.fat f WITH(NOLOCK)
                             ON fa.ehID = f.eID AND f.eTip = 0 AND f.eDurum <> 2
                            AND f.eTarih < @bit
                            AND (f.eFirma <> 9525 OR f.eTarih >= '20220901')
                        WHERE fa.ehStkID = d.StkID AND fa.ehAdetN <> 0
                        ORDER BY f.eTarih DESC
                        UNION ALL
                        SELECT TOP 5 o.TARIH, o.NET * o.ADET, o.ADET
                        FROM BKMDATA..ODAK_FATURA o WITH(NOLOCK)
                        WHERE o.STKID = d.StkID AND o.TARIH < @bit AND o.ADET <> 0
                        ORDER BY o.TARIH DESC
                    ) ML
                    ORDER BY ML.trh DESC
                ) b
                HAVING SUM(b.adt) <> 0
            ) MLYT
            WHERE MLYT.Birim > 0
            """, new { bas, bit }, commandTimeout: 180);
        var list = rows.ToList();
        // Maliyeti bilinmeyen ürün, marj hesabında net'ten DÜŞÜLMEZ (kapsama panelde gösterilir).
        // Kapsama beklenmedik biçimde düşerse (alış faturası akmıyorsa) sessiz kalmasın.
        logger.LogInformation("Hediye çeki fat5 maliyet: {Adet} ürün için birim maliyet bulundu ({Bas}–{Bit})",
            list.Count, bas, bit);
        return list;
    }

    // ── 4) Fatura kanalı indirimleri (arşiv blok 10) ────────────────────────────

    /// <summary>Fatura kanalında müşteri bazlı mevcut indirim (eTip=1 Satış).
    /// ⚠ eTip=4 (Mağaza Satış) DAHİL EDİLMEZ: o satırlarda ehTutarN beslenmiyor (bkz. sınıf yorumu).
    /// ⚠ Liste HAM — grup konsolidasyonu ERP'de tanımlı değil (frmBagID + frmGrup1..5 hepsi 0).</summary>
    public async Task<List<HcFaturaIndirim>> GetFaturaIndirimAsync(DateOnly bas, DateOnly bit)
    {
        await using var conn = await db.OpenAsync();
        var rows = await conn.QueryAsync<HcFaturaIndirim>($"""
            SELECT f.eFirma AS FrmID,
                   ISNULL(c.frmAd, '(tanımsız)') AS FirmaAd,
                   COUNT(DISTINCT f.eID) AS Fatura,
                   SUM(ABS(fa.ehAdetN)) AS Adet,
                   SUM(fa.ehTutar) AS Brut,
                   SUM(fa.ehIndirim) AS Indirim,
                   SUM(fa.ehTutarN) AS Net
            FROM DerinSISBkm.dbo.fatAyr fa WITH(NOLOCK)
            JOIN DerinSISBkm.dbo.fat f WITH(NOLOCK) ON f.eID = fa.ehID
            LEFT JOIN DerinSISBkm.dbo.frm c WITH(NOLOCK) ON c.frmID = f.eFirma
            WHERE f.eDurum <> 2 AND f.eTip = 1
              AND f.eTarih >= @bas AND f.eTarih < @bit
              AND fa.ehStkID IN ({CekStkFiltre})
            GROUP BY f.eFirma, c.frmAd
            """, new { bas, bit }, commandTimeout: 60);
        return rows.OrderByDescending(r => r.Brut).ToList();
    }

    // ── 5) Bonus dayanağı: basılı kupür kaldıracı (arşiv blok 18) ───────────────

    /// <summary>Basılı kupür (yuvarlak tutarlı) dilim davranışı — bonus simülatörünün dayanağı.
    /// Kısmi bakiye artıkları AYIKLANIR: bonus programı basılı kupür ihraç eder, artık-davranışı
    /// (barem-1'in 10,66× kaldıracı) tasarımla üretilemez. Marj panelde barem'den eşleştirilir.</summary>
    public async Task<List<HcBaremPayda>> GetBasiliKupurAsync(DateOnly bas, DateOnly bit)
    {
        await using var conn = await db.OpenAsync();
        var rows = await conn.QueryAsync<HcBaremPayda>($"""
            SELECT {DilimCase} AS Dilim,
                   COUNT(*) AS Fis,
                   SUM(hc.HcTutar) AS HcOdenen,
                   AVG(hc.HcTutar) AS OrtCek,
                   SUM(CASE WHEN s.DocumentsTypeId = 3 THEN -(s.GrossTotal - s.DiscountTotal)
                            ELSE (s.GrossTotal - s.DiscountTotal) END) AS SepetOdenen
            FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
            JOIN ({HcFisToplam}) hc ON hc.SalesId = s.Id
            WHERE s.DocumentsTypeId IN (1, 3) AND s.Date >= @bas AND s.Date < @bit
              AND hc.HcTutar % 50 = 0
            GROUP BY {DilimCase}
            """, new { bas, bit }, commandTimeout: 60);
        return rows.OrderBy(r => r.Dilim).ToList();
    }
}
