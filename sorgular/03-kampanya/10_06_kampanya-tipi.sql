-- EncoreMerkez Sorgu 10.6 — Kampanya Tipi Bazlı Dağılım
-- Kaynak: encore-merkez-analiz-raporu.html
-- Veritabanı: EncoreMerkez
-- ============================================

-- Kampanya tiplerinin toplam performansı
SELECT
    CASE c.CampaignTypeId
        WHEN 1 THEN 'BuyN PayN (3al2ode vb.)'
        WHEN 2 THEN 'Yuzdesel / Sabit Fiyat'
        WHEN 5 THEN 'Tutar Indirimi'
        ELSE 'Diger (Hediye vb.)'
    END AS KampanyaTipi,
    COUNT(DISTINCT spc.CampaignId) AS KampanyaSayisi,
    COUNT(DISTINCT spc.SalesId) AS FisSayisi,
    COUNT(*) AS UrunSatiri,
    CAST(SUM(spc.TotalDiscount) AS decimal(18,2)) AS ToplamIndirim
FROM dbo.SalesProductCampaigns spc
JOIN dbo.Campaign c ON spc.CampaignId = c.Id
WHERE spc.CampaignId IS NOT NULL
GROUP BY c.CampaignTypeId
ORDER BY ToplamIndirim DESC
