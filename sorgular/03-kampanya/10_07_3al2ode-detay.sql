-- EncoreMerkez Sorgu 10.7 — 3 Al 2 Öde Birleşik Detay (Eski + Güncel)
-- Kaynak: encore-merkez-analiz-raporu.html
-- Veritabanı: EncoreMerkez
-- ============================================

-- 3AL2ÖDE eski (Id=1) + güncel (Id=12) birleşik performans
SELECT
    CASE WHEN spc.CampaignId = 1 THEN '3AL2ODE (eski)'
         WHEN spc.CampaignId = 12 THEN '3AL2ODE(K) (guncel)'
    END AS Versiyon,
    COUNT(DISTINCT spc.SalesId) AS FisSayisi,
    COUNT(*) AS UrunSatiri,
    CAST(SUM(spc.TotalDiscount) AS decimal(18,2)) AS ToplamIndirim,
    CAST(AVG(spc.TotalDiscount) AS decimal(18,2)) AS OrtIndirimPerUrun,
    MIN(CONVERT(varchar, s.Date, 104)) AS IlkSatis,
    MAX(CONVERT(varchar, s.Date, 104)) AS SonSatis
FROM dbo.SalesProductCampaigns spc
JOIN dbo.Sales s ON spc.SalesId = s.Id
WHERE spc.CampaignId IN (1, 12)
GROUP BY spc.CampaignId

UNION ALL

SELECT
    '3AL2ODE TOPLAM' AS Versiyon,
    COUNT(DISTINCT spc.SalesId),
    COUNT(*),
    CAST(SUM(spc.TotalDiscount) AS decimal(18,2)),
    CAST(AVG(spc.TotalDiscount) AS decimal(18,2)),
    MIN(CONVERT(varchar, s.Date, 104)),
    MAX(CONVERT(varchar, s.Date, 104))
FROM dbo.SalesProductCampaigns spc
JOIN dbo.Sales s ON spc.SalesId = s.Id
WHERE spc.CampaignId IN (1, 12)
