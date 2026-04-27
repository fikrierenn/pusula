-- EncoreMerkez Sorgu 10.13 — Marka (Yayınevi) Bazlı Satış
-- Kaynak: encore-merkez-analiz-raporu.html
-- Veritabanı: EncoreMerkez
-- ============================================

-- En çok satan 30 yayınevi/marka + 3AL2ÖDE kırılımı
;WITH cte_3al2ode AS (
    SELECT
        spc.SalesId, spc.ProductSequence,
        CAST(SUM(sp2.TotalPrice + ABS(spc.DistributedAmount)) AS decimal(18,2)) AS BrutCiro,
        CAST(SUM(ABS(spc.DistributedAmount)) AS decimal(18,2)) AS Indirim,
        CAST(SUM(sp2.TotalPrice) AS decimal(18,2)) AS NetCiro,
        COUNT(*) AS UrunSayisi
    FROM dbo.SalesProductCampaigns spc
    JOIN dbo.SalesProducts sp2 ON spc.SalesId = sp2.SalesId AND spc.ProductSequence = sp2.Sequence
    WHERE spc.CampaignId IN (1, 12) AND sp2.IsValid = 1
    GROUP BY spc.SalesId, spc.ProductSequence
)
SELECT TOP 30
    pb.Name AS Marka,
    COUNT(DISTINCT sp.SalesId) AS FisSayisi,
    CAST(SUM(sp.Amount) AS decimal(18,0)) AS ToplamAdet,
    CAST(SUM(sp.TotalPrice) AS decimal(18,2)) AS ToplamTutar,
    CAST(SUM(sp.DiscountTotalCampaign) AS decimal(18,2)) AS KampanyaIndirim,
    ISNULL(SUM(spc_3al.UrunSayisi), 0) AS [3Al2Ode_Urun],
    CAST(ISNULL(SUM(spc_3al.BrutCiro), 0) AS decimal(18,2)) AS [3Al2Ode_BrutCiro],
    CAST(ISNULL(SUM(spc_3al.Indirim), 0) AS decimal(18,2)) AS [3Al2Ode_Indirim],
    CAST(ISNULL(SUM(spc_3al.NetCiro), 0) AS decimal(18,2)) AS [3Al2Ode_NetCiro]
FROM dbo.SalesProducts sp
JOIN dbo.Products p ON sp.ProductsId = p.Id
LEFT JOIN dbo.ProductBrand pb ON p.BrandId = pb.Id
LEFT JOIN cte_3al2ode spc_3al ON sp.SalesId = spc_3al.SalesId AND sp.Sequence = spc_3al.ProductSequence
WHERE sp.IsValid = 1
GROUP BY pb.Name
ORDER BY ToplamTutar DESC
