;WITH cte_3al2ode AS (
    SELECT DISTINCT SalesId FROM dbo.SalesProductCampaigns WHERE CampaignId IN (1, 12)
),
cte_any_campaign AS (
    SELECT DISTINCT SalesId FROM dbo.SalesProductCampaigns
)
SELECT
    CONVERT(varchar(7), s.Date, 126) AS Ay,
    CASE
        WHEN s.DocumentsTypeId = 3 THEN 'Iade'
        WHEN c3.SalesId IS NOT NULL THEN '3Al2Ode'
        WHEN ca.SalesId IS NOT NULL THEN 'DigerKampanya'
        ELSE 'Kampanyasiz'
    END AS Grup,
    COUNT(*) AS FisSayisi,
    CAST(AVG(CASE WHEN s.DocumentsTypeId <> 3 THEN s.GrossTotal END) AS decimal(18,2)) AS OrtBrutSepet,
    CAST(AVG(CASE WHEN s.DocumentsTypeId <> 3 THEN ABS(s.DiscountTotal) END) AS decimal(18,2)) AS OrtIndirimTutar,
    CAST(AVG(CASE WHEN s.DocumentsTypeId <> 3 THEN s.GrossTotal - ABS(s.DiscountTotal) END) AS decimal(18,2)) AS OrtNetSepet,
    CAST(AVG(CASE WHEN s.DocumentsTypeId <> 3 THEN CAST(gc.GecerliUrun AS decimal) END) AS decimal(18,1)) AS OrtUrunAdet,
    CASE WHEN SUM(CASE WHEN s.DocumentsTypeId=3 THEN -s.GrossTotal ELSE s.GrossTotal END) > 0
         THEN CAST(SUM(CASE WHEN s.DocumentsTypeId=3 THEN -ABS(s.DiscountTotal) ELSE ABS(s.DiscountTotal) END) * 100.0
              / SUM(CASE WHEN s.DocumentsTypeId=3 THEN -s.GrossTotal ELSE s.GrossTotal END) AS decimal(5,1))
         ELSE 0 END AS IndirimOrani,
    CAST(SUM(CASE WHEN s.DocumentsTypeId=3 THEN -s.GrossTotal ELSE s.GrossTotal END) AS decimal(18,2)) AS ToplamBrutCiro,
    CAST(SUM(CASE WHEN s.DocumentsTypeId=3 THEN -ABS(s.DiscountTotal) ELSE ABS(s.DiscountTotal) END) AS decimal(18,2)) AS ToplamIndirim,
    CAST(SUM(CASE WHEN s.DocumentsTypeId=3 THEN -(s.GrossTotal-ABS(s.DiscountTotal)) ELSE s.GrossTotal-ABS(s.DiscountTotal) END) AS decimal(18,2)) AS ToplamNetCiro
FROM dbo.Sales s
CROSS APPLY (
    SELECT COUNT(*) AS GecerliUrun
    FROM dbo.SalesProducts sp
    WHERE sp.SalesId = s.Id AND sp.IsValid = 1
) gc
LEFT JOIN cte_3al2ode c3 ON s.Id = c3.SalesId
LEFT JOIN cte_any_campaign ca ON s.Id = ca.SalesId
-- Belge: 1=Fiş, 2=Fatura, 3=İade(-), 6=Personel Fiş, 7=Personel Fatura, 8=Sınav
WHERE s.DocumentsTypeId IN (1, 2, 3, 6, 7, 8)
GROUP BY CONVERT(varchar(7), s.Date, 126),
    CASE WHEN s.DocumentsTypeId = 3 THEN 'Iade'
         WHEN c3.SalesId IS NOT NULL THEN '3Al2Ode'
         WHEN ca.SalesId IS NOT NULL THEN 'DigerKampanya'
         ELSE 'Kampanyasiz' END
ORDER BY Ay, Grup