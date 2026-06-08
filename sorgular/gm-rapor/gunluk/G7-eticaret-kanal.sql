-- =====================================================================
-- G7 — GÜNLÜK E-TİCARET (JOKER) KANAL KIRILIMI
-- Amaç: Dün online sipariş + ciro + sepet, kanal bazlı (App/Mobil Site/Web).
-- Kaynak: ODAKJOKER.JOKER linked server (J_ORDERS)
-- ⚠️ TARİH: Linked server'da ISO 'YYYYMMDD' ZORUNLU (DMY sessiz yanlış eşleşir).
-- Kanal: J_ORDERS.APPLICATION ∈ Mobil Uygulama (Android/iOS) · Mobil Site · Web Sitesi
-- DOĞRULAMA (07.06.2026): toplam 2.647 sipariş · 3.022.333 ₺ (= 3 fiziksel mağazadan BÜYÜK!).
--   App (Android 889 + iOS 523) ciro 1.737k = %57,5; sepet App 1.208-1.268 > Mobil Site 963.
-- ⚠️ KAPSAM: TOTALPRICE = brüt (sipariş başlık). Net için iptal/iade J_ORDER_STATUS 1006/1007
--   filtrelenmeli (v2). Brief'e (haftalık) e-ticaret DAHİL DEĞİL → B-21.
-- NOT: MCP-safe (CTE yok). @Gun yerine ISO literal. SSMS'te DECLARE serbest.
-- =====================================================================
DECLARE @Gun varchar(8) = CONVERT(varchar(8), DATEADD(DAY,-1,GETDATE()), 112);  -- dün ISO YYYYMMDD
DECLARE @GunBitis varchar(8) = CONVERT(varchar(8), CAST(GETDATE() AS date), 112);

SELECT
    o.APPLICATION                                              AS Kanal,
    COUNT(*)                                                   AS Sipariş,
    CAST(SUM(o.TOTALPRICE) AS decimal(18,0))                   AS [Ciro ₺],
    CAST(SUM(o.TOTALPRICE)/NULLIF(COUNT(*),0) AS decimal(18,0)) AS [Ort. Sepet ₺]
FROM ODAKJOKER.JOKER.dbo.J_ORDERS o
WHERE o.ORDERDATE >= @Gun AND o.ORDERDATE < @GunBitis
GROUP BY o.APPLICATION
ORDER BY [Ciro ₺] DESC;
