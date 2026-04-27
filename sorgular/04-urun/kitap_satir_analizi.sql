-- EncoreMerkez — Sadece Kitap Satırları Analizi
-- Fişte ne olursa olsun, sadece Kitap/Hazırlık/Çocuk/Akademi kategorisindeki
-- ürün satırlarını alır. Fişin kırtasiye/oyuncak satırları dahil DEĞİL.
-- Mapping: Barcodes.BarcodeNo → DerinSISBkm.dbo.urnBrkd.urnBarkod → stkID → bkm.urunbilgi.Kategori3
-- Veritabanı: EncoreMerkez (cross-db join DerinSISBkm)
-- ============================================

;WITH kitap_satirlar AS (
    SELECT
        CONVERT(varchar(7), s.Date, 126) AS Ay,
        s.Id AS SalesId,
        sp.Id AS SalesProductId,
        sp.ProductsId,
        sp.TotalPrice,
        sp.DiscountTotalDirect,
        sp.Amount,
        s.DocumentsTypeId,
        CASE WHEN s.DocumentsTypeId = 3 THEN -1 ELSE 1 END AS IadeIsareti,
        kat.Kategori3,
        -- Fiş kampanya bilgisi
        CASE
            WHEN s.DocumentsTypeId = 3 THEN 'Iade'
            WHEN fkt.Has3Al2Ode = 1 THEN '3Al2Ode'
            WHEN fkt.SalesId IS NOT NULL THEN 'DigerKampanya'
            ELSE 'Kampanyasiz'
        END AS FisGrup
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
    LEFT JOIN (
        SELECT SalesId,
            MAX(CASE WHEN CampaignId IN (1,12) THEN 1 ELSE 0 END) AS Has3Al2Ode
        FROM dbo.SalesProductCampaigns
        GROUP BY SalesId
    ) fkt ON fkt.SalesId = s.Id
    -- Belge: 1=Fiş, 2=Fatura, 3=İade(-), 6=Personel Fiş, 7=Personel Fatura, 8=Sınav
    WHERE s.DocumentsTypeId IN (1, 2, 3, 6, 7, 8)
      AND s.Date >= DATEADD(MONTH, -3, CAST(GETDATE() AS date))
      AND kat.Kategori3 IN ('Kitap', N'Hazırlık Kitapları', N'Çocuk Kitabı', 'Akademi')
)
-- RESULT SET 1: Ay + Kategori3 kırılımı
SELECT
    Ay,
    Kategori3,
    COUNT(*) AS SatirSayisi,
    CAST(SUM(IadeIsareti * Amount) AS decimal(18,1)) AS ToplamAdet,
    CAST(SUM(IadeIsareti * (TotalPrice + DiscountTotalDirect)) AS decimal(18,2)) AS BrutCiro,
    CAST(SUM(IadeIsareti * DiscountTotalDirect) AS decimal(18,2)) AS Indirim,
    CAST(SUM(IadeIsareti * TotalPrice) AS decimal(18,2)) AS NetCiro,
    CAST(CASE WHEN SUM(IadeIsareti * (TotalPrice + DiscountTotalDirect)) > 0
        THEN SUM(IadeIsareti * DiscountTotalDirect) * 100.0
            / SUM(IadeIsareti * (TotalPrice + DiscountTotalDirect))
        ELSE 0 END AS decimal(5,1)) AS IndirimOrani,
    COUNT(DISTINCT SalesId) AS FisSayisi
FROM kitap_satirlar
GROUP BY Ay, Kategori3
ORDER BY Ay DESC, NetCiro DESC

-- İsteğe bağlı: RESULT SET 2 — Ay + FisGrup (kampanya) kırılımı
-- Yorum kaldırarak çalıştırılabilir:
/*
;WITH kitap_satirlar AS ( ... aynı CTE ... )
SELECT
    Ay,
    FisGrup,
    Kategori3,
    COUNT(*) AS SatirSayisi,
    CAST(SUM(IadeIsareti * Amount) AS decimal(18,1)) AS ToplamAdet,
    CAST(SUM(IadeIsareti * (TotalPrice + DiscountTotalDirect)) AS decimal(18,2)) AS BrutCiro,
    CAST(SUM(IadeIsareti * DiscountTotalDirect) AS decimal(18,2)) AS Indirim,
    CAST(SUM(IadeIsareti * TotalPrice) AS decimal(18,2)) AS NetCiro
FROM kitap_satirlar
GROUP BY Ay, FisGrup, Kategori3
ORDER BY Ay DESC, FisGrup, NetCiro DESC
*/
