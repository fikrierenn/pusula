-- =====================================================================
-- P6 — HAFTALIK KASİYER PERFORMANSI + GÜN SONU KAPANIŞ
-- Veritabanı: EncoreMerkez. Kasiyer köprüsü: Sales.UsersId = Users.Id (Users.Name).
-- DOĞRULAMA (11.06.2026, hafta 01-07.06): 16 kasiyer; FİDAN (Özlüce) 1.928 fiş/1,23M lider;
--   MURAT (Özlüce, 38 fiş) + EREN (İst.Yolu, 42 fiş) yönetici/destek profili.
-- NOT: Eski 10_16_kasiyer.sql dosyasının İÇERİĞİ kasiyer değil kampanya-aylık-trend idi
--   (dosya adı/içerik uyumsuz) — bu sorgu sıfırdan yazıldı, canlı doğrulandı.
-- MCP-safe. SSMS dinamik hafta: DATEADD(WEEK, DATEDIFF(WEEK,0,GETDATE())-1, 0).
-- =====================================================================

-- §A — Kasiyer performansı (hafta)
SELECT TOP 30 st.Name AS Magaza, u.Name AS Kasiyer,
  COUNT(*) AS Fis,
  CAST(SUM(CASE WHEN s.DocumentsTypeId=3 THEN -(s.GrossTotal-ABS(s.DiscountTotal)) ELSE s.GrossTotal-s.DiscountTotal END) AS decimal(18,0)) AS NetCiro,
  CAST(AVG(CASE WHEN s.DocumentsTypeId <> 3 THEN s.GrossTotal-s.DiscountTotal END) AS decimal(18,0)) AS OrtSepet,
  SUM(CASE WHEN s.DocumentsTypeId=3 THEN 1 ELSE 0 END) AS IadeFis
FROM dbo.Sales s
JOIN dbo.Stores st ON s.StoresId = st.Id
LEFT JOIN dbo.Users u ON u.Id = s.UsersId
WHERE s.DocumentsTypeId IN (1,2,3,6,7,8)
  AND s.Date >= CONVERT(date,'01.06.2026',104) AND s.Date < CONVERT(date,'08.06.2026',104)
GROUP BY st.Name, u.Name;

-- §B — Gün sonu kapanış kontrolü (hafta; kasa × kapanış no)
SELECT TOP 100 CONVERT(varchar, s.Date, 104) AS Tarih, st.Name AS Magaza, pos.Name AS Kasa,
  s.ClosureNo AS KapanisNo, COUNT(*) AS FisSayisi,
  CAST(SUM(s.TotalAmount) AS decimal(18,2)) AS NetCiro
FROM dbo.Sales s
JOIN dbo.Stores st ON s.StoresId = st.Id
JOIN dbo.Pos pos ON s.PosId = pos.Id
WHERE s.DocumentsTypeId IN (1,2,3,6,7,8)
  AND s.Date >= CONVERT(date,'01.06.2026',104) AND s.Date < CONVERT(date,'08.06.2026',104)
GROUP BY CONVERT(varchar, s.Date, 104), st.Name, pos.Name, s.ClosureNo;
