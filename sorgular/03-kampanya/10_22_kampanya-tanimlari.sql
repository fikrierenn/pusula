-- EncoreMerkez Sorgu 10.22 — Kampanya Tanımları (Aktif Liste)
-- Kaynak: encore-merkez-analiz-raporu.html
-- Veritabanı: EncoreMerkez
-- ============================================

-- Aktif kampanya tanımları ve kuralları
SELECT
    c.Id,
    c.Name AS KampanyaAd,
    c.CampaignTypeId AS TipId,
    CASE c.CampaignTypeId
        WHEN 1 THEN 'BuyN PayN'
        WHEN 2 THEN 'Yuzdesel/SabitFiyat'
        WHEN 5 THEN 'Tutar'
        ELSE 'Diger'
    END AS KampanyaTipi,
    CONVERT(varchar, c.BeginDate, 104) AS Baslangic,
    CONVERT(varchar, c.EndDate, 104) AS Bitis,
    c.BuyNPayN_1ConditionNum AS AlimKosul,
    c.BuyNPayN_1PayNum AS OdemeKosul,
    c.ConditionAmount AS KosulTutar,
    c.ConditionQuantity AS KosulAdet,
    c.Sequence AS Oncelik,
    c.ValidForAllStores AS TumMagazalar,
    c.IsActive
FROM dbo.Campaign c
WHERE c.IsActive = 1
ORDER BY c.Sequence, c.Name
