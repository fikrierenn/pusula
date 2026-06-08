-- =====================================================================
-- G2 — GÜNLÜK ÖDEME TİPİ MİX (kasa mutabakat)
-- Amaç: Dün ödeme dağılımı — nakit / kart / çek. Nakit oranı kasa kontrolü.
-- Veritabanı: EncoreMerkez (SalesPayments + PaymentTypes)
-- Filtre: IsChangeAmount=0 (para üstü hariç), DocumentsTypeId IN (1,2,3,6,7,8)
-- TÜRK LİRASI = nakit · banka adları = kredi/banka kartı · İADE ÇEKİ = iade kuponu
-- DOĞRULAMA (07.06.2026): HALK 1.094.280 · TL(nakit) 342.092 · ANADOLU 229.915 ·
--   İŞ 226.195 · AKBANK 96.368 · İADE ÇEKİ 23.797 · nakit oranı ~%17.
-- NOT: MCP-safe (CTE yok). @Gun yerine ISO literal ver. SSMS'te DECLARE serbest.
-- =====================================================================
DECLARE @Gun date = CAST(DATEADD(DAY,-1,GETDATE()) AS date);
DECLARE @GunBitis date = DATEADD(DAY,1,@Gun);

SELECT
    pt.Name                                       AS [Ödeme Tipi],
    COUNT(*)                                       AS [İşlem],
    CAST(SUM(sp.Amount) AS decimal(18,2))          AS [Tutar ₺],
    CAST(100.0 * SUM(sp.Amount) / NULLIF(SUM(SUM(sp.Amount)) OVER (), 0) AS decimal(5,1)) AS [Pay %]
FROM EncoreMerkez.dbo.SalesPayments sp WITH(NOLOCK)
JOIN EncoreMerkez.dbo.PaymentTypes pt WITH(NOLOCK) ON pt.Id = sp.PaymentTypesId
JOIN EncoreMerkez.dbo.Sales s WITH(NOLOCK) ON s.Id = sp.SalesId
WHERE s.DocumentsTypeId IN (1,2,3,6,7,8) AND sp.IsChangeAmount = 0
  AND s.Date >= @Gun AND s.Date < @GunBitis
GROUP BY pt.Name
ORDER BY [Tutar ₺] DESC;
