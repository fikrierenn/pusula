-- EncoreMerkez Sorgu 10.9 — Mağaza Bazlı Kampanya Performansı
-- Kaynak: encore-merkez-analiz-raporu.html
-- Veritabanı: EncoreMerkez
-- ============================================

-- Her mağazada kampanyaların ne kadar etki ettiği
SELECT
    st.Name AS Magaza,
    ISNULL(c.Name, '(Kampanya ID yok)') AS KampanyaAd,
    COUNT(DISTINCT spc.SalesId) AS FisSayisi,
    COUNT(*) AS UrunSatiri,
    CAST(SUM(spc.TotalDiscount) AS decimal(18,2)) AS ToplamIndirim,
    CAST(AVG(spc.TotalDiscount) AS decimal(18,2)) AS OrtIndirimPerUrun
FROM dbo.SalesProductCampaigns spc
JOIN dbo.Sales s ON spc.SalesId = s.Id
JOIN dbo.Stores st ON s.StoresId = st.Id
LEFT JOIN dbo.Campaign c ON spc.CampaignId = c.Id
GROUP BY st.Name, ISNULL(c.Name, '(Kampanya ID yok)')
ORDER BY Magaza, ToplamIndirim DESC
