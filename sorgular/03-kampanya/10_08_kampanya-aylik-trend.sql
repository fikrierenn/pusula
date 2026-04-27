-- EncoreMerkez Sorgu 10.8 — Belirli Kampanya — Aylık Trend
-- Kaynak: encore-merkez-analiz-raporu.html
-- Veritabanı: EncoreMerkez
-- ============================================

-- @kampanyaId değiştir: 1=3AL2ÖDE(eski), 12=3AL2ÖDE(K), 17=SABİT FİYAT(K), 16=YÜZDESEL(K)
DECLARE @kampanyaId bigint = 12

SELECT
    CONVERT(varchar(7), s.Date, 126) AS Ay,
    COUNT(DISTINCT spc.SalesId) AS FisSayisi,
    COUNT(*) AS UrunSatiri,
    CAST(SUM(spc.TotalDiscount) AS decimal(18,2)) AS ToplamIndirim,
    CAST(AVG(spc.TotalDiscount) AS decimal(18,2)) AS OrtIndirim
FROM dbo.SalesProductCampaigns spc
JOIN dbo.Sales s ON spc.SalesId = s.Id
WHERE spc.CampaignId = @kampanyaId
GROUP BY CONVERT(varchar(7), s.Date, 126)
ORDER BY Ay
