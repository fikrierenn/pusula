-- EncoreMerkez Sorgu 10.18 — Gün Sonu Kapanış Kontrolü
-- Kaynak: encore-merkez-analiz-raporu.html
-- Veritabanı: EncoreMerkez
-- ============================================

-- Son 7 gün gün sonu kapanış takibi (kasa + mağaza bazlı)
SELECT
    CONVERT(varchar, s.Date, 104) AS Tarih,
    st.Name AS Magaza,
    pos.Name AS Kasa,
    s.ClosureNo AS KapanisNo,
    COUNT(*) AS FisSayisi,
    CAST(SUM(s.TotalAmount) AS decimal(18,2)) AS NetCiro
FROM dbo.Sales s
JOIN dbo.Stores st ON s.StoresId = st.Id
JOIN dbo.Pos pos ON s.PosId = pos.Id
-- Belge: 1=Fiş, 2=Fatura, 3=İade(-), 6=Personel Fiş, 7=Personel Fatura, 8=Sınav
WHERE s.DocumentsTypeId IN (1, 2, 3, 6, 7, 8)
  AND CAST(s.Date AS date) >= DATEADD(DAY, -7, CAST(GETDATE() AS date))
GROUP BY CONVERT(varchar, s.Date, 104), st.Name, pos.Name, s.ClosureNo
ORDER BY Tarih DESC, Magaza, Kasa
