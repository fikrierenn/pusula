-- =====================================================================
-- G6 — GÜNLÜK ANOMALİ BAYRAĞI
-- Amaç: Dün veri/fiyat anomalisi taraması — sıfır/negatif fiyat satırı,
--        kampanyasız (manuel) indirim. GM erken uyarı.
-- Veritabanı: EncoreMerkez (SalesProducts + SalesProductCampaigns anti-join)
-- NOTLAR:
--   - Sales tablosunda CampaignId YOK → kampanya linki SalesProductCampaigns (SalesId+ProductSequence).
--   - Kampanyasız indirim = DiscountTotalDirect>0 AMA hiç kampanya satırı yok = MANUEL indirim
--     (geçmiş "CampaignId NULL 389M" araştırması — günlük takip).
-- DOĞRULAMA (07.06.2026): 30 sıfır/neg satır (12.346'da, %0,24 — düşük, promo/paket);
--   kampanyasız indirim 7 satır / 432 ₺ (ihmal edilebilir); toplam indirim 487.209 ₺.
-- BAYRAK EŞİĞİ (öneri): sıfır/neg oranı >%1 VEYA kampanyasız indirim >50.000 ₺ → incele.
-- NOT: MCP-safe (CTE yok). @Gun yerine ISO literal.
-- =====================================================================
DECLARE @Gun date = CAST(DATEADD(DAY,-1,GETDATE()) AS date);
DECLARE @GunBitis date = DATEADD(DAY,1,@Gun);

SELECT
    SUM(CASE WHEN sp.TotalPrice<=0 THEN 1 ELSE 0 END)                                  AS [Sıfır/Neg Fiyat Satır],
    SUM(CASE WHEN sp.DiscountTotalDirect>0 AND spc.SalesId IS NULL THEN 1 ELSE 0 END)  AS [Kampanyasız İndirimli Satır],
    CAST(SUM(CASE WHEN spc.SalesId IS NULL THEN sp.DiscountTotalDirect ELSE 0 END) AS decimal(18,0)) AS [Kampanyasız İndirim ₺],
    CAST(SUM(sp.DiscountTotalDirect) AS decimal(18,0))                                 AS [Toplam İndirim ₺],
    COUNT(*)                                                                           AS [Toplam Geçerli Satır],
    CAST(100.0*SUM(CASE WHEN sp.TotalPrice<=0 THEN 1 ELSE 0 END)/NULLIF(COUNT(*),0) AS decimal(10,2)) AS [Sıfır/Neg %]
FROM EncoreMerkez.dbo.SalesProducts sp WITH(NOLOCK)
JOIN EncoreMerkez.dbo.Sales s WITH(NOLOCK) ON s.Id=sp.SalesId
LEFT JOIN EncoreMerkez.dbo.SalesProductCampaigns spc WITH(NOLOCK)
    ON spc.SalesId=sp.SalesId AND spc.ProductSequence=sp.Sequence
WHERE sp.IsValid=1 AND sp.BarcodeNo<>'1001'
  AND s.Date>=@Gun AND s.Date<@GunBitis AND s.DocumentsTypeId IN (1,2,3,6,7,8);
