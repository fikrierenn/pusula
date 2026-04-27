-- EncoreMerkez Sorgu 10.1 — Günlük Ciro + Kampanya Kırılımı
-- Kaynak: encore-merkez-analiz-raporu.html
-- Veritabanı: EncoreMerkez
-- ============================================

-- Son 7 gün, mağaza bazlı günlük ciro + kampanya kırılımı (3AL2ÖDE dahil)
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
    CONVERT(varchar, s.Date, 104) AS Tarih,
    st.Name AS Magaza,
    COUNT(DISTINCT s.Id) AS FisSayisi,
    SUM(CASE WHEN s.DocumentsTypeId = 3 THEN 1 ELSE 0 END) AS IadeFisSayisi,
    CAST(SUM(CASE WHEN s.DocumentsTypeId=3 THEN -s.GrossTotal ELSE s.GrossTotal END) AS decimal(18,2)) AS BrutCiro,
    CAST(SUM(CASE WHEN s.DocumentsTypeId=3 THEN -ABS(s.DiscountTotal) ELSE s.DiscountTotal END) AS decimal(18,2)) AS Indirim,
    CAST(SUM(CASE WHEN s.DocumentsTypeId=3 THEN -s.TotalAmount ELSE s.TotalAmount END) AS decimal(18,2)) AS NetCiro,
    COUNT(DISTINCT CASE WHEN spc_all.SalesId IS NOT NULL THEN s.Id END) AS KampanyaliFis,
    COUNT(DISTINCT CASE WHEN spc_3al.SalesId IS NOT NULL THEN s.Id END) AS [3Al2Ode_Fis],
    ISNULL(SUM(spc_3al.UrunSayisi), 0) AS [3Al2Ode_Urun],
    CAST(ISNULL(SUM(spc_3al.BrutCiro), 0) AS decimal(18,2)) AS [3Al2Ode_BrutCiro],
    CAST(ISNULL(SUM(spc_3al.Indirim), 0) AS decimal(18,2)) AS [3Al2Ode_Indirim],
    CAST(ISNULL(SUM(spc_3al.NetCiro), 0) AS decimal(18,2)) AS [3Al2Ode_NetCiro]
FROM dbo.Sales s
JOIN dbo.Stores st ON s.StoresId = st.Id
LEFT JOIN (SELECT DISTINCT SalesId FROM dbo.SalesProductCampaigns) spc_all ON s.Id = spc_all.SalesId
LEFT JOIN cte_3al2ode spc_3al ON s.Id = spc_3al.SalesId
-- Belge: 1=Fiş, 2=Fatura, 3=İade(-), 6=Personel Fiş, 7=Personel Fatura, 8=Sınav
WHERE s.DocumentsTypeId IN (1, 2, 3, 6, 7, 8)
  AND CAST(s.Date AS date) >= DATEADD(DAY, -7, CAST(GETDATE() AS date))
GROUP BY CONVERT(varchar, s.Date, 104), st.Name
ORDER BY Tarih DESC, Magaza
