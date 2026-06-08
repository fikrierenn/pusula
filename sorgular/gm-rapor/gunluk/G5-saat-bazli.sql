-- =====================================================================
-- G5 — GÜNLÜK SAAT BAZLI YOĞUNLUK
-- Amaç: Dün saatlik fiş + net ciro. Vardiya/kasiyer planı + pik saat tespiti.
-- Veritabanı: EncoreMerkez (Sales.Date datetime → DATEPART HOUR)
-- DOĞRULAMA (07.06.2026): pik 16:00 (347 fiş, 257k ₺); yoğun bant 13-20;
--   sabah 10-11 zayıf; kapanış 22:00.
-- NOT: MCP-safe (CTE yok). @Gun yerine ISO literal.
-- =====================================================================
DECLARE @Gun date = CAST(DATEADD(DAY,-1,GETDATE()) AS date);
DECLARE @GunBitis date = DATEADD(DAY,1,@Gun);

SELECT
    DATEPART(HOUR, s.Date)                                                          AS Saat,
    SUM(IIF(s.DocumentsTypeId=3,-1,1))                                              AS Fiş,
    CAST(SUM(IIF(s.DocumentsTypeId=3,-1,1)*(s.GrossTotal-s.DiscountTotal)) AS decimal(18,0)) AS [Net Ciro ₺],
    CAST(SUM(IIF(s.DocumentsTypeId=3,-1,1)*(s.GrossTotal-s.DiscountTotal))
       / NULLIF(SUM(IIF(s.DocumentsTypeId=3,-1,1)),0) AS decimal(18,0))             AS [Sepet Ort ₺]
FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
WHERE s.DocumentsTypeId IN (1,2,3,6,7,8) AND s.Date>=@Gun AND s.Date<@GunBitis
GROUP BY DATEPART(HOUR, s.Date)
ORDER BY Saat;
