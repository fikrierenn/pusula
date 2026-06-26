/* Baskısı Yok yapılan e-ticaret siparişleri (B-126)
   DB: JOKER (192.168.40.70 direkt) — SSMS'te JOKER'e bağlan; 201'den ODAKJOKER linked ile OPENQUERY sar.
   Kaynak: dbo.BASKISIYOK × J_ORDER_DETAILS × J_ITEMS × EM_USERS.
   Köprü: BASKISIYOK.DETAILREF=J_ORDER_DETAILS.LOGICALREF · ITEMREF=J_ITEMS.LOGICALREF · USERREF=EM_USERS.LOGICALREF · ORDERREF=J_ORDERS.ORDERID.
   Adet = BASKISIYOK.QUANTITY (B) · Tutar = B.QUANTITY × D.SELLINGPRICE · Çeşit = distinct B.BARCODE.
   ⚠ B.QUANTITY = 0 satırları İPTAL kaynaklı (bug) → DEVRE DIŞI: WHERE B.QUANTITY > 0. (2026-06-26 kullanıcı: iptal bug'ı.)
     (SELLINGPRICE=0 = hediye çeki, ayrı/normal — Tutar 0 ama Adet dolu.)
   Dashboard: /baskisi-yok (gün özeti + ürün detay) + E-ticaret 30g trend. EticQueries.GetBaskisiYok*Async.
   Parametre: @Bas/@Bit ISO yyyymmdd (bitiş HARİÇ; tek gün = bugün..ertesi). */

DECLARE @Bas date = CONVERT(date, GETDATE());                   -- başlangıç (dahil)
DECLARE @Bit date = DATEADD(DAY, 1, CONVERT(date, GETDATE()));  -- bitiş (HARİÇ)

/* ── 1) GÜN BAZLI ÖZET (dashboard /baskisi-yok üst tablo) ── */
SELECT CONVERT(varchar(10), CONVERT(DATE, B.TARIH), 104) AS Gun,
       COUNT(DISTINCT B.BARCODE)                         AS Barkod,
       COUNT(DISTINCT D.ORDERREF)                        AS Siparis,
       SUM(B.QUANTITY)                                   AS Miktar,
       SUM(B.QUANTITY * D.SELLINGPRICE)                  AS Tutar
FROM   dbo.BASKISIYOK B WITH(NOLOCK)
JOIN   dbo.J_ORDER_DETAILS D WITH(NOLOCK) ON D.LOGICALREF = B.DETAILREF
WHERE  CONVERT(DATE, B.TARIH) >= @Bas AND CONVERT(DATE, B.TARIH) < @Bit AND B.QUANTITY > 0
GROUP BY CONVERT(DATE, B.TARIH)
ORDER BY CONVERT(DATE, B.TARIH) DESC;

/* ── 2) ÜRÜN BAZLI DETAY (dashboard /baskisi-yok alt tablo) ── */
SELECT CONVERT(varchar(10), B.TARIH, 104) AS Tarih,
       U.FULLNAME                          AS Kullanici,
       D.BARCODE                           AS Barkod,
       A.CODE, A.NAME, A.BRAND, A.GROUPCODE,
       SUM(B.QUANTITY)                     AS Miktar,
       SUM(B.QUANTITY * D.SELLINGPRICE)    AS Tutar
FROM   dbo.BASKISIYOK B WITH(NOLOCK)
JOIN   dbo.J_ORDER_DETAILS D WITH(NOLOCK) ON D.LOGICALREF = B.DETAILREF
JOIN   dbo.J_ITEMS A WITH(NOLOCK)         ON A.LOGICALREF = D.ITEMREF
JOIN   dbo.EM_USERS U WITH(NOLOCK)        ON U.LOGICALREF = B.USERREF
WHERE  CONVERT(DATE, B.TARIH) >= @Bas AND CONVERT(DATE, B.TARIH) < @Bit AND B.QUANTITY > 0
GROUP BY B.TARIH, U.FULLNAME, D.BARCODE, A.CODE, A.NAME, A.BRAND, A.GROUPCODE
ORDER BY SUM(B.QUANTITY * D.SELLINGPRICE) DESC;

/* ── 3) GÜNLÜK TREND — çeşit + adet (dashboard E-ticaret 30g grafiği) ── */
SELECT CONVERT(varchar(10), CONVERT(DATE, B.TARIH), 104) AS Gun,
       COUNT(DISTINCT B.BARCODE)                         AS Cesit,
       SUM(B.QUANTITY)                                   AS Adet
FROM   dbo.BASKISIYOK B WITH(NOLOCK)
WHERE  CONVERT(DATE, B.TARIH) >= DATEADD(DAY, -29, CONVERT(date, GETDATE())) AND B.QUANTITY > 0
GROUP BY CONVERT(DATE, B.TARIH)
ORDER BY CONVERT(DATE, B.TARIH);
