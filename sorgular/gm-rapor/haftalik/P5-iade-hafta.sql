-- =====================================================================
-- P5 — HAFTALIK İADE ANALİZİ (mağaza + belge tipi)
-- Veritabanı: EncoreMerkez. DocumentsTypeId 3=İade, 4=İade-Değişim.
-- DOĞRULAMA (11.06.2026, hafta 01-07.06): FSM 76 / İst.Yolu 70 / Özlüce 134 = 280 iade
--   (P3 IadeFis toplamıyla birebir ✓). Ort iade İst.Yolu 1.007 ₺ en yüksek.
-- MCP-safe. SSMS dinamik hafta: DATEADD(WEEK, DATEDIFF(WEEK,0,GETDATE())-1, 0).
-- =====================================================================
SELECT TOP 20 st.Name AS Magaza, d.Name AS BelgeTipi,
  COUNT(*) AS IadeSayisi,
  CAST(SUM(s.GrossTotal) AS decimal(18,2)) AS IadeTutari,
  CAST(AVG(s.GrossTotal) AS decimal(18,2)) AS OrtIade
FROM dbo.Sales s
JOIN dbo.Stores st ON s.StoresId = st.Id
JOIN dbo.Documents d ON s.DocumentsTypeId = d.Id
WHERE s.DocumentsTypeId IN (3,4)
  AND s.Date >= CONVERT(date,'01.06.2026',104) AND s.Date < CONVERT(date,'08.06.2026',104)
GROUP BY st.Name, d.Name;
