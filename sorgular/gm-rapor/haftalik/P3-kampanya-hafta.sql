-- =====================================================================
-- P3 — HAFTALIK KAMPANYA PERFORMANSI (3Al2Öde vs diğer kampanya vs kampanyasız)
-- Veritabanı: EncoreMerkez (compat 110 — IIF/TRIM/STRING_AGG/TRY_CONVERT YOK)
-- 3Al2Öde = CampaignId IN (1 eski, 12 güncel). DiscountTotal fiş toplam indirim.
-- DOĞRULAMA (11.06.2026, hafta 01-07.06):
--   3Al2Ode 3.213 fiş / sepet 1.550 ₺ / net 3,62M · Diğer 7.153 / 720 ₺ / 3,78M ·
--   Kampanyasız 7.106 / 404 ₺ / 2,72M — net toplam 10,13M = brief ✓
--   İçgörü: 3Al2Öde sepeti kampanyasızın 3,8 katı.
-- MCP-safe (CTE'siz). SSMS'te DECLARE ile dinamik hafta kullan:
--   DECLARE @HaftaBas date = DATEADD(WEEK, DATEDIFF(WEEK,0,GETDATE())-1, 0);
--   DECLARE @HaftaBit date = DATEADD(DAY,7,@HaftaBas);
-- =====================================================================
SELECT TOP 20
  CASE WHEN c3.SalesId IS NOT NULL THEN '3Al2Ode'
       WHEN ca.SalesId IS NOT NULL THEN 'DigerKampanya' ELSE 'Kampanyasiz' END AS Grup,
  COUNT(DISTINCT s.Id) AS FisSayisi,
  SUM(CASE WHEN s.DocumentsTypeId = 3 THEN 1 ELSE 0 END) AS IadeFis,
  CAST(AVG(CASE WHEN s.DocumentsTypeId <> 3 THEN s.GrossTotal END) AS decimal(18,2)) AS OrtBrutSepet,
  CAST(SUM(CASE WHEN s.DocumentsTypeId=3 THEN -s.GrossTotal ELSE s.GrossTotal END) AS decimal(18,0)) AS BrutCiro,
  CAST(SUM(CASE WHEN s.DocumentsTypeId=3 THEN -(s.GrossTotal-ABS(s.DiscountTotal)) ELSE s.GrossTotal-s.DiscountTotal END) AS decimal(18,0)) AS NetCiro
FROM dbo.Sales s
LEFT JOIN (SELECT DISTINCT SalesId FROM dbo.SalesProductCampaigns WHERE CampaignId IN (1,12)) c3 ON s.Id = c3.SalesId
LEFT JOIN (SELECT DISTINCT SalesId FROM dbo.SalesProductCampaigns) ca ON s.Id = ca.SalesId
WHERE s.DocumentsTypeId IN (1,2,3,6,7,8)
  AND s.Date >= CONVERT(date,'01.06.2026',104) AND s.Date < CONVERT(date,'08.06.2026',104)
GROUP BY CASE WHEN c3.SalesId IS NOT NULL THEN '3Al2Ode'
       WHEN ca.SalesId IS NOT NULL THEN 'DigerKampanya' ELSE 'Kampanyasiz' END;
