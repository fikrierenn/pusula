-- EncoreMerkez Sorgu 10.15 — CampaignId NULL İndirim Analizi
-- Kaynak: encore-merkez-analiz-raporu.html
-- Veritabanı: EncoreMerkez
-- ============================================

-- Kampanya ID'si olmadan kaydedilen indirimlerin analizi
SELECT
    CONVERT(varchar(7), s.Date, 126) AS Ay,
    COUNT(DISTINCT spc.SalesId) AS FisSayisi,
    COUNT(*) AS UrunSatiri,
    CAST(SUM(spc.TotalDiscount) AS decimal(18,2)) AS ToplamIndirim,
    CAST(AVG(spc.TotalDiscount) AS decimal(18,2)) AS OrtIndirim,
    spc.CampaignName AS KampanyaAd
FROM dbo.SalesProductCampaigns spc
JOIN dbo.Sales s ON spc.SalesId = s.Id
WHERE spc.CampaignId IS NULL
GROUP BY CONVERT(varchar(7), s.Date, 126), spc.CampaignName
ORDER BY Ay, ToplamIndirim DESC
