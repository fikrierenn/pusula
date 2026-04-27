-- EncoreMerkez Sorgu 10.3 — Mağaza Bazlı Ciro Karşılaştırması
-- Kaynak: encore-merkez-analiz-raporu.html
-- Veritabanı: EncoreMerkez
-- ============================================

-- Tüm dönem mağaza bazlı ciro, ortalama sepet + 3AL2ÖDE kırılımı
;WITH cte_3al2ode AS (
    SELECT
        spc.SalesId,
        CAST(SUM(sp.TotalPrice + ABS(spc.DistributedAmount)) AS decimal(18,2)) AS BrutCiro,
        CAST(SUM(ABS(spc.DistributedAmount)) AS decimal(18,2)) AS Indirim,
        CAST(SUM(sp.TotalPrice) AS decimal(18,2)) AS NetCiro,
        COUNT(*) AS UrunSayisi
    FROM dbo.SalesProductCampaigns spc
    JOIN dbo.SalesProducts sp ON spc.SalesId = sp.SalesId AND spc.ProductSequence = sp.Sequence
    WHERE spc.CampaignId IN (1, 12) AND sp.IsValid = 1
    GROUP BY spc.SalesId
)
SELECT
    st.Name AS Magaza,
    COUNT(*) AS FisSayisi,
    SUM(CASE WHEN s.DocumentsTypeId = 3 THEN 1 ELSE 0 END) AS IadeFisSayisi,
    CAST(SUM(CASE WHEN s.DocumentsTypeId=3 THEN -s.GrossTotal ELSE s.GrossTotal END) AS decimal(18,2)) AS BrutCiro,
    CAST(SUM(CASE WHEN s.DocumentsTypeId=3 THEN -ABS(s.DiscountTotal) ELSE s.DiscountTotal END) AS decimal(18,2)) AS ToplamIndirim,
    CAST(SUM(CASE WHEN s.DocumentsTypeId=3 THEN -s.TotalAmount ELSE s.TotalAmount END) AS decimal(18,2)) AS NetCiro,
    CASE WHEN SUM(CASE WHEN s.DocumentsTypeId=3 THEN -s.GrossTotal ELSE s.GrossTotal END) > 0
         THEN CAST(SUM(CASE WHEN s.DocumentsTypeId=3 THEN -ABS(s.DiscountTotal) ELSE s.DiscountTotal END) * 100.0
              / SUM(CASE WHEN s.DocumentsTypeId=3 THEN -s.GrossTotal ELSE s.GrossTotal END) AS decimal(5,1))
         ELSE 0 END AS IndirimOrani,
    CAST(AVG(CASE WHEN s.DocumentsTypeId <> 3 THEN s.GrossTotal END) AS decimal(18,2)) AS OrtSepet,
    CAST(AVG(CAST(gc.GecerliUrun AS decimal)) AS decimal(5,1)) AS OrtUrunAdet,
    COUNT(DISTINCT CASE WHEN spc_3al.SalesId IS NOT NULL THEN s.Id END) AS [3Al2Ode_Fis],
    ISNULL(SUM(spc_3al.UrunSayisi), 0) AS [3Al2Ode_Urun],
    CAST(ISNULL(SUM(spc_3al.BrutCiro), 0) AS decimal(18,2)) AS [3Al2Ode_BrutCiro],
    CAST(ISNULL(SUM(spc_3al.Indirim), 0) AS decimal(18,2)) AS [3Al2Ode_Indirim],
    CAST(ISNULL(SUM(spc_3al.NetCiro), 0) AS decimal(18,2)) AS [3Al2Ode_NetCiro]
FROM dbo.Sales s
JOIN dbo.Stores st ON s.StoresId = st.Id
CROSS APPLY (
    SELECT COUNT(*) AS GecerliUrun
    FROM dbo.SalesProducts sp
    WHERE sp.SalesId = s.Id AND sp.IsValid = 1
) gc
LEFT JOIN cte_3al2ode spc_3al ON s.Id = spc_3al.SalesId
-- Belge: 1=Fiş, 2=Fatura, 3=İade(-), 6=Personel Fiş, 7=Personel Fatura, 8=Sınav
WHERE s.DocumentsTypeId IN (1, 2, 3, 6, 7, 8)
GROUP BY st.Name
ORDER BY BrutCiro DESC
