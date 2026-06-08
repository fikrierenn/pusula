-- =====================================================================
-- E8 — STOKTA YOKLUK (STOCKOUT) — SKU-level, kategori özet
-- Amaç: Son 30 günde satışı olan (talep var) ama mağaza bakiyesi ≤0 olan ürün
--        oranı. Kayıp satış sinyali. Hedef: fiziksel mağaza <%5.
-- Kaynak: DerinSISBkm.irsHrk (per-SKU bakiye = SUM(ehAdetN), mağaza stokları).
--   Talep = son 30 gün satış (ehTip 4,100). Bakiye ≤0 = stoksuz (negatif=hayalet/oversold dahil).
-- DOĞRULAMA (08.06.2026): Akademi %8,7 · Elektronik %6,5 · Oyuncak %5,7 ·
--   Kitap %5,2 · Hediyelik %5,2 · Çocuk/Kırtasiye %3 (sağlıklı).
-- YORUM: <%5 hedef. Üstündekiler (Akademi/Elektronik/Oyuncak/Kitap) reorder açığı = kayıp satış.
-- ⚠️ DERGİ HARİÇ: süreli yayın, stok takibi anlamsız (sürekli tükenir/yenilenir) — devre dışı.
-- ⚠️ Bakiye tüm-zaman SUM (snapshot değil, anlık hesap) — ~1,7sn. CROSS APPLY per-SKU.
-- NOT: MCP-safe (CTE'siz). @GunSayisi talep penceresi.
-- =====================================================================
DECLARE @GunSayisi int = 30;

SELECT x.Kategori,
    COUNT(*)                                                          AS [Satılan Çeşit],
    SUM(CASE WHEN x.Bakiye <= 0 THEN 1 ELSE 0 END)                    AS [Stokta Yok Çeşit],
    CAST(100.0*SUM(CASE WHEN x.Bakiye <= 0 THEN 1 ELSE 0 END)/NULLIF(COUNT(*),0) AS decimal(10,1)) AS [Stockout %]
FROM (
    SELECT k.ktgrAd AS Kategori, sold.stkID, bal.Bakiye
    FROM (
        SELECT DISTINCT h.ehstkID AS stkID
        FROM DerinSISBkm.dbo.irsHrk h WITH(NOLOCK)
        WHERE h.ehTip IN (4,100) AND h.ehTrhS >= DATEADD(DAY,-@GunSayisi,GETDATE())
          AND h.ehMekan IN (1,4477,4478) AND h.ehAltDepo=0
    ) sold
    JOIN DerinSISBkm.dbo.urn u WITH(NOLOCK) ON u.stkID = sold.stkID
    JOIN DerinSISBkm.dbo.urnKtgr2 k WITH(NOLOCK) ON k.ktgrID = u.urnKtgr2ID
    CROSS APPLY (
        SELECT SUM(b.ehAdetN) AS Bakiye
        FROM DerinSISBkm.dbo.irsHrk b WITH(NOLOCK)
        WHERE b.ehstkID = sold.stkID AND b.ehMekan IN (1,4477,4478) AND b.ehAltDepo=0
    ) bal
    WHERE k.ktgrAd NOT IN (N'Sınav Okulları',N'Dergi',N'Genel',N'Tanımsız',N'Etkinlik',N'Hediye Çeki')
) x
GROUP BY x.Kategori
ORDER BY [Stockout %] DESC;
