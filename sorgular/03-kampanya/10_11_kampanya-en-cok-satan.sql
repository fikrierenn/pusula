-- EncoreMerkez Sorgu 10.11 — Kampanya Bazlı En Çok Satan Ürünler
-- Kaynak: encore-merkez-analiz-raporu.html
-- Veritabanı: EncoreMerkez
-- ============================================

-- @kampanyaId değiştir: 1=3AL2ÖDE(eski), 12=3AL2ÖDE(K), 17=SABİT FİYAT(K), 16=YÜZDESEL(K)
DECLARE @kampanyaId bigint = 12

SELECT TOP 20
    p.Code, p.Name,
    pc.Name AS Kategori,
    pb.Name AS Marka,
    COUNT(*) AS Adet,
    CAST(SUM(spc.TotalDiscount) AS decimal(18,2)) AS ToplamIndirim,
    CAST(AVG(spc.TotalDiscount) AS decimal(18,2)) AS OrtIndirim
FROM dbo.SalesProductCampaigns spc
JOIN dbo.Sales s ON spc.SalesId = s.Id
JOIN dbo.SalesProducts sp ON spc.SalesId = sp.SalesId AND spc.ProductSequence = sp.Sequence
JOIN dbo.Products p ON sp.ProductsId = p.Id
LEFT JOIN dbo.ProductCategory pc ON p.CategoryId = pc.Id
LEFT JOIN dbo.ProductBrand pb ON p.BrandId = pb.Id
WHERE spc.CampaignId = @kampanyaId
GROUP BY p.Code, p.Name, pc.Name, pb.Name
ORDER BY Adet DESC
