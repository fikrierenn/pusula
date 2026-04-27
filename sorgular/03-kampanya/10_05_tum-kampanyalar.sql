-- EncoreMerkez Sorgu 10.5 — Tüm Kampanyalar — Performans Özeti
-- Kaynak: encore-merkez-analiz-raporu.html
-- Veritabanı: EncoreMerkez
-- ============================================

-- Tüm kampanyaların toplam performansı (aktif/pasif bilgisiyle)
SELECT
    spc.CampaignId,
    ISNULL(spc.CampaignName, c.Name) AS KampanyaAd,
    c.CampaignTypeId AS TipId,
    CASE c.CampaignTypeId
        WHEN 1 THEN 'BuyN PayN'
        WHEN 2 THEN 'Yuzdesel/SabitFiyat'
        WHEN 5 THEN 'Tutar'
        ELSE 'Diger'
    END AS KampanyaTipi,
    CASE WHEN c.IsActive = 1 THEN 'Aktif' ELSE 'Pasif' END AS Durum,
    COUNT(DISTINCT spc.SalesId) AS FisSayisi,
    COUNT(*) AS UrunSatiri,
    CAST(SUM(spc.TotalDiscount) AS decimal(18,2)) AS ToplamIndirim,
    CAST(AVG(spc.TotalDiscount) AS decimal(18,2)) AS OrtIndirimPerUrun
FROM dbo.SalesProductCampaigns spc
LEFT JOIN dbo.Campaign c ON spc.CampaignId = c.Id
GROUP BY spc.CampaignId, ISNULL(spc.CampaignName, c.Name), c.CampaignTypeId, c.IsActive
ORDER BY ToplamIndirim DESC
