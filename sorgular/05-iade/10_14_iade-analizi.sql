-- EncoreMerkez Sorgu 10.14 — İade Analizi (Mağaza + Belge Tipi)
-- Kaynak: encore-merkez-analiz-raporu.html
-- Veritabanı: EncoreMerkez
-- ============================================

-- Son 30 gün mağaza ve belge tipi bazlı iade analizi
SELECT
    st.Name AS Magaza,
    d.Name AS BelgeTipi,
    COUNT(*) AS IadeSayisi,
    CAST(SUM(s.GrossTotal) AS decimal(18,2)) AS IadeTutari,
    CAST(AVG(s.GrossTotal) AS decimal(18,2)) AS OrtIadeTutar
FROM dbo.Sales s
JOIN dbo.Stores st ON s.StoresId = st.Id
JOIN dbo.Documents d ON s.DocumentsTypeId = d.Id
WHERE s.DocumentsTypeId IN (3,4)  -- 3=İade, 4=İade-Değişim
  AND CAST(s.Date AS date) >= DATEADD(DAY, -30, CAST(GETDATE() AS date))
GROUP BY st.Name, d.Name
ORDER BY Magaza, BelgeTipi
