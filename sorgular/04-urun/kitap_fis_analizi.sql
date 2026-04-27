-- EncoreMerkez — Kitap Fiş Analizi
-- Kitap fişi = fişte en az 1 adet Kitap/Hazırlık/Çocuk/Akademi kategorisinde ürün olan fiş
-- Mapping: Barcodes.BarcodeNo → DerinSISBkm.dbo.urnBrkd.urnBarkod → stkID → bkm.urunbilgi.Kategori3
-- Veritabanı: EncoreMerkez (cross-db join DerinSISBkm)
-- ============================================

-- 1) Kitap fişlerini bul
IF OBJECT_ID('tempdb..#kitap_fis') IS NOT NULL DROP TABLE #kitap_fis

SELECT DISTINCT sp.SalesId
INTO #kitap_fis
FROM dbo.Sales s
INNER JOIN dbo.SalesProducts sp ON sp.SalesId = s.Id AND sp.IsValid = 1
CROSS APPLY (
    SELECT TOP 1 u.Kategori3
    FROM dbo.Barcodes b
    INNER JOIN DerinSISBkm.dbo.urnBrkd br
        ON b.BarcodeNo COLLATE Turkish_CI_AS = br.urnBarkod COLLATE Turkish_CI_AS
    INNER JOIN DerinSISBkm.bkm.urunbilgi u ON br.urnBrkdStkID = u.stkID
    WHERE b.ProductsId = sp.ProductsId
) kat
-- Belge: 1=Fiş, 2=Fatura, 3=İade(-), 6=Personel Fiş, 7=Personel Fatura, 8=Sınav
WHERE s.DocumentsTypeId IN (1, 2, 3, 6, 7, 8)
  AND s.Date >= DATEADD(MONTH, -3, CAST(GETDATE() AS date))
  AND kat.Kategori3 IN ('Kitap', N'Hazırlık Kitapları', N'Çocuk Kitabı', 'Akademi')

-- 2) Kitap fişleri üzerinde kampanya kırılımlı analiz (fiş bazlı)
;WITH fis_detay AS (
    SELECT
        CONVERT(varchar(7), s.Date, 126) AS Ay,
        CASE
            WHEN s.DocumentsTypeId = 3 THEN 'Iade'
            WHEN fkt.Has3Al2Ode = 1 THEN '3Al2Ode'
            WHEN fkt.SalesId IS NOT NULL THEN 'DigerKampanya'
            ELSE 'Kampanyasiz'
        END AS Grup,
        gc.GecerliUrun,
        s.GrossTotal,
        s.DiscountTotal,
        CASE WHEN s.DocumentsTypeId = 3 THEN -1 ELSE 1 END AS IadeIsareti,
        s.DocumentsTypeId
    FROM dbo.Sales s
    INNER JOIN #kitap_fis kf ON s.Id = kf.SalesId
    CROSS APPLY (
        SELECT COUNT(*) AS GecerliUrun
        FROM dbo.SalesProducts sp
        WHERE sp.SalesId = s.Id AND sp.IsValid = 1
    ) gc
    LEFT JOIN (
        SELECT SalesId,
            MAX(CASE WHEN CampaignId IN (1,12) THEN 1 ELSE 0 END) AS Has3Al2Ode
        FROM dbo.SalesProductCampaigns
        GROUP BY SalesId
    ) fkt ON fkt.SalesId = s.Id
)
SELECT
    Ay,
    Grup,
    COUNT(*) AS FisSayisi,
    SUM(IadeIsareti * GecerliUrun) AS ToplamUrun,
    CAST(SUM(IadeIsareti * GrossTotal) AS decimal(18,2)) AS BrutCiro,
    CAST(SUM(IadeIsareti * DiscountTotal) AS decimal(18,2)) AS Indirim,
    CAST(SUM(IadeIsareti * (GrossTotal - DiscountTotal)) AS decimal(18,2)) AS NetCiro,
    CAST(AVG(CASE WHEN DocumentsTypeId <> 3 THEN GrossTotal END) AS decimal(18,2)) AS OrtBrutSepet,
    CAST(AVG(CASE WHEN DocumentsTypeId <> 3 THEN CAST(GecerliUrun AS decimal) END) AS decimal(5,1)) AS OrtUrunAdet,
    CAST(CASE WHEN SUM(IadeIsareti * GrossTotal) > 0
        THEN SUM(IadeIsareti * DiscountTotal) * 100.0 / SUM(IadeIsareti * GrossTotal)
        ELSE 0 END AS decimal(5,1)) AS IndirimOrani
FROM fis_detay
GROUP BY Ay, Grup
ORDER BY Ay DESC, Grup

DROP TABLE #kitap_fis
