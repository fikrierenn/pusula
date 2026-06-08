-- =====================================================================
-- G0 — BİRLEŞİK GÜNLÜK TOPLAM (Fiziksel + E-ticaret)
-- Amaç: GERÇEK günlük ciro — 3 fiziksel mağaza (EncoreMerkez) + online (JOKER).
--        Mevcut Pazartesi brief'i sadece fizikseli gösteriyor = resmin ~%39'u.
-- Kaynaklar: EncoreMerkez.Sales (POS) + ODAKJOKER.JOKER.J_ORDERS (online, ISO tarih!)
-- DOĞRULAMA (07.06.2026): Fiziksel 1.933.437 ₺ (3.060 fiş) · E-ticaret 3.022.333 ₺ (2.647 sip.)
--   → TOPLAM 4.955.770 ₺. E-ticaret payı %61 (cironun çoğunluğu online).
-- ⚠️ E-ticaret brüt (TOTALPRICE); net için iptal/iade J_ORDER_STATUS 1006/1007 (v2).
-- ⚠️ Fiziksel net (Gross-Disc, iade sign'lı, geri dönüşüm 1001 hariç).
--    İki kanal farklı net tanımı — kabaca karşılaştırma; kesin için normalize gerek.
-- NOT: SSMS (#temp). MCP'de iki kaynak ayrı çalıştırılıp birleştirilir.
-- =====================================================================
DECLARE @Gun     varchar(8) = CONVERT(varchar(8), DATEADD(DAY,-1,GETDATE()), 112);  -- dün ISO
DECLARE @GunBitis varchar(8) = CONVERT(varchar(8), CAST(GETDATE() AS date), 112);

IF OBJECT_ID('tempdb..#G0') IS NOT NULL DROP TABLE #G0;
CREATE TABLE #G0 (Sira int, Kanal nvarchar(30), Ciro decimal(18,0), Adet int);

-- Fiziksel (EncoreMerkez, 3 mağaza, net, geri dönüşüm hariç)
INSERT INTO #G0
SELECT 1, N'Fiziksel (3 mağaza)',
    SUM(IIF(s.DocumentsTypeId=3,-1,1)*(s.GrossTotal-s.DiscountTotal)),
    SUM(IIF(s.DocumentsTypeId=3,-1,1))
FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
LEFT JOIN EncoreMerkez.dbo.SalesProducts spb WITH(NOLOCK) ON spb.SalesId=s.Id AND spb.BarcodeNo='1001'
WHERE s.DocumentsTypeId IN (1,2,3,6,7,8) AND s.Date>=@Gun AND s.Date<@GunBitis AND spb.Id IS NULL;

-- E-ticaret (JOKER, brüt sipariş)
INSERT INTO #G0
SELECT 2, N'E-ticaret (JOKER)', SUM(o.TOTALPRICE), COUNT(*)
FROM ODAKJOKER.JOKER.dbo.J_ORDERS o
WHERE o.ORDERDATE>=@Gun AND o.ORDERDATE<@GunBitis;

-- Çıktı: detay + TOPLAM + pay %
SELECT
    ISNULL(Kanal, N'★ TOPLAM')                                          AS Kanal,
    SUM(Ciro)                                                           AS [Ciro ₺],
    SUM(Adet)                                                           AS [Sipariş/Fiş],
    CAST(100.0*SUM(Ciro)/NULLIF((SELECT SUM(Ciro) FROM #G0),0) AS decimal(5,1)) AS [Pay %]
FROM #G0
GROUP BY ROLLUP(Sira, Kanal)
HAVING GROUPING(Sira)=1 OR GROUPING(Kanal)=0
ORDER BY GROUPING(Kanal), MIN(Sira);

DROP TABLE #G0;
