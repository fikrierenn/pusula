-- EncoreMerkez Sorgu 10.10 — Kampanyalı vs Kampanyasız Sepet Karşılaştırması
-- Kaynak: encore-merkez-analiz-raporu.html
-- Veritabanı: EncoreMerkez
-- ============================================

-- Son 30 gün: kampanyasız / herhangi kampanya / 3AL2ÖDE sepet karşılaştırması
;WITH cte_3al2ode AS (
    SELECT DISTINCT SalesId FROM dbo.SalesProductCampaigns WHERE CampaignId IN (1, 12)
)
SELECT
    CASE
        WHEN spc_3al.SalesId IS NOT NULL THEN '3Al2Ode'
        WHEN spc_all.SalesId IS NOT NULL THEN 'DigerKampanya'
        ELSE 'Kampanyasiz'
    END AS Grup,
    COUNT(DISTINCT s.Id) AS FisSayisi,
    SUM(CASE WHEN s.DocumentsTypeId = 3 THEN 1 ELSE 0 END) AS IadeFisSayisi,
    CAST(AVG(CASE WHEN s.DocumentsTypeId <> 3 THEN s.GrossTotal END) AS decimal(18,2)) AS OrtBrutSepet,
    CAST(AVG(CASE WHEN s.DocumentsTypeId <> 3 THEN CAST(gc.GecerliUrun AS decimal) END) AS decimal(18,1)) AS OrtUrunAdet,
    CAST(SUM(CASE WHEN s.DocumentsTypeId=3 THEN -s.GrossTotal ELSE s.GrossTotal END) AS decimal(18,2)) AS ToplamBrutCiro,
    CAST(SUM(CASE WHEN s.DocumentsTypeId=3 THEN -(s.GrossTotal - ABS(s.DiscountTotal)) ELSE s.GrossTotal - s.DiscountTotal END) AS decimal(18,2)) AS ToplamNetCiro
FROM dbo.Sales s
CROSS APPLY (
    SELECT COUNT(*) AS GecerliUrun
    FROM dbo.SalesProducts sp
    WHERE sp.SalesId = s.Id AND sp.IsValid = 1
) gc
LEFT JOIN (SELECT DISTINCT SalesId FROM dbo.SalesProductCampaigns) spc_all ON s.Id = spc_all.SalesId
LEFT JOIN cte_3al2ode spc_3al ON s.Id = spc_3al.SalesId
-- Belge: 1=Fiş, 2=Fatura, 3=İade(-), 6=Personel Fiş, 7=Personel Fatura, 8=Sınav
WHERE s.DocumentsTypeId IN (1, 2, 3, 6, 7, 8)
  AND CAST(s.Date AS date) >= DATEADD(DAY, -30, CAST(GETDATE() AS date))
GROUP BY CASE
    WHEN spc_3al.SalesId IS NOT NULL THEN '3Al2Ode'
    WHEN spc_all.SalesId IS NOT NULL THEN 'DigerKampanya'
    ELSE 'Kampanyasiz' END
