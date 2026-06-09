-- =====================================================================
-- A6 — MARKA / YAYINEVİ PERFORMANSI (tedarikçi karnesi)
-- Amaç: En çok ciro yapan markalar/yayınevleri. Tedarikçi pazarlığı +
--        ürün çeşidi başına verim (dar+yoğun vs geniş+uzun kuyruk).
-- Kaynak: EncoreMerkez satış + DerinSIS urnMrk (marka=yayınevi).
--   Marka (09.06 düzeltildi): Products.Code=urn.stkID köprüsü → urn.urnMrkID → urnMrk.mrkAd.
--   (Eski stkKod=BarcodeNo join YANLIŞTI; stkKod≠barkod — bazı markaları kaçırıyordu.)
-- NOT: Mağaza filtresi yok (tüm EncoreMerkez) — gerekirse Pos→Stores→posMagaza ekle.
-- YORUM: Ciro/çeşit yüksek = dar+güçlü (Sinan Kuzucu); düşük = geniş+uzun kuyruk (İş Bankası).
-- ⚠️ Marj kolonu yok (karzarar COGS gerekir) — sadece ciro/adet. Marjlı versiyon: E5/karzarar ile.
-- NOT: MCP-safe (CTE'siz). @AyBas/@AySon ISO literal.
-- =====================================================================
DECLARE @AyBas date = '20260501';
DECLARE @AySon date = '20260601';

SELECT TOP 30
    mrk.mrkAd                                          AS [Marka/Yayınevi],
    CAST(SUM(sp.TotalPrice) AS decimal(18,0))          AS [Ciro ₺],
    CAST(SUM(sp.Amount) AS decimal(18,0))              AS [Adet],
    COUNT(DISTINCT sp.ProductsId)                      AS [Ürün Çeşidi],
    CAST(SUM(sp.TotalPrice)/NULLIF(COUNT(DISTINCT sp.ProductsId),0) AS decimal(18,0)) AS [Ciro/Çeşit ₺]
FROM EncoreMerkez.dbo.SalesProducts sp WITH(NOLOCK)
JOIN EncoreMerkez.dbo.Sales s WITH(NOLOCK) ON s.Id = sp.SalesId
JOIN EncoreMerkez.dbo.Products pr WITH(NOLOCK) ON pr.Id = sp.ProductsId
JOIN DerinSISBkm.dbo.urn u WITH(NOLOCK) ON u.stkID = CONVERT(int, pr.Code)
JOIN DerinSISBkm.dbo.urnMrk mrk WITH(NOLOCK) ON mrk.mrkID = u.urnMrkID
WHERE sp.IsValid = 1 AND sp.BarcodeNo <> '1001' AND ISNUMERIC(pr.Code) = 1
  AND s.Date >= @AyBas AND s.Date < @AySon AND s.DocumentsTypeId IN (1,2,6,7,8)
GROUP BY mrk.mrkAd
ORDER BY [Ciro ₺] DESC;
