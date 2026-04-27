-- EncoreMerkez Sorgu 10.12 — Kategori Bazlı Satış Analizi
-- Kaynak: encore-merkez-analiz-raporu.html
-- Veritabanı: EncoreMerkez
-- ============================================

-- Kategorilere göre satış hacmi, ciro, kampanya + 3AL2ÖDE indirim kırılımı
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
SELECT
    pc.Name AS Kategori,
    COUNT(DISTINCT sp.SalesId) AS FisSayisi,
    CAST(SUM(sp.Amount) AS decimal(18,0)) AS ToplamAdet,
    CAST(SUM(sp.TotalPrice) AS decimal(18,2)) AS ToplamTutar,
    CAST(SUM(sp.DiscountTotalCampaign) AS decimal(18,2)) AS KampanyaIndirim,
    CAST(SUM(sp.DiscountTotalDirect) AS decimal(18,2)) AS DogruIndirim,
    COUNT(DISTINCT CASE WHEN spc_3al.SalesId IS NOT NULL THEN sp.SalesId END) AS [3Al2Ode_Fis],
    ISNULL(SUM(spc_3al.UrunSayisi), 0) AS [3Al2Ode_Urun],
    CAST(ISNULL(SUM(spc_3al.BrutCiro), 0) AS decimal(18,2)) AS [3Al2Ode_BrutCiro],
    CAST(ISNULL(SUM(spc_3al.Indirim), 0) AS decimal(18,2)) AS [3Al2Ode_Indirim],
    CAST(ISNULL(SUM(spc_3al.NetCiro), 0) AS decimal(18,2)) AS [3Al2Ode_NetCiro]
FROM dbo.SalesProducts sp
JOIN dbo.Products p ON sp.ProductsId = p.Id
LEFT JOIN dbo.ProductCategory pc ON p.CategoryId = pc.Id
LEFT JOIN cte_3al2ode spc_3al ON sp.SalesId = spc_3al.SalesId AND sp.Sequence = spc_3al.ProductSequence
WHERE sp.IsValid = 1
GROUP BY pc.Name
ORDER BY ToplamTutar DESC
