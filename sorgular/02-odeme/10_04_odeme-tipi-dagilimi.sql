-- EncoreMerkez Sorgu 10.4 — Ödeme Tipi Dağılımı
-- Kaynak: encore-merkez-analiz-raporu.html
-- Veritabanı: EncoreMerkez
-- ============================================

-- Tüm dönem veya tarih aralığı ile ödeme tipi dağılımı
SELECT
    pt.Name AS OdemeTipi,
    COUNT(*) AS IslemSayisi,
    CAST(SUM(sp.Amount) AS decimal(18,2)) AS Tutar,
    CASE WHEN (SELECT SUM(sp2.Amount) FROM dbo.SalesPayments sp2
          JOIN dbo.Sales s2 ON sp2.SalesId = s2.Id
          WHERE s2.DocumentsTypeId IN (1, 2, 3, 6, 7, 8) AND sp2.IsChangeAmount = 0) > 0
         THEN CAST(SUM(sp.Amount) * 100.0 /
              (SELECT SUM(sp2.Amount) FROM dbo.SalesPayments sp2
               JOIN dbo.Sales s2 ON sp2.SalesId = s2.Id
               WHERE s2.DocumentsTypeId IN (1, 2, 3, 6, 7, 8) AND sp2.IsChangeAmount = 0) AS decimal(5,1))
         ELSE 0 END AS YuzdePay
FROM dbo.SalesPayments sp
JOIN dbo.PaymentTypes pt ON sp.PaymentTypesId = pt.Id
JOIN dbo.Sales s ON sp.SalesId = s.Id
-- Belge: 1=Fiş, 2=Fatura, 3=İade(-), 6=Personel Fiş, 7=Personel Fatura, 8=Sınav
WHERE s.DocumentsTypeId IN (1, 2, 3, 6, 7, 8) AND sp.IsChangeAmount = 0
GROUP BY pt.Name
ORDER BY Tutar DESC
