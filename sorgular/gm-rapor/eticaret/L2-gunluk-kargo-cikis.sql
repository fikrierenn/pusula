/* ============================================================
   L2 — Günlük Kargo (çıkış / SENDDATE bazlı)
   Çıkış günü × paket adedi × kitap sayısı × toplam tutar
   ------------------------------------------------------------
   Kaynak: J_ORDERS (SENDDATE) + J_ORDER_DETAILS (ORDERREF=ORDERID)
   - Paket   = COUNT(DISTINCT o.LOGICALREF)
   - Kitap   = SUM(d.QUANTITY)
   - Tutar   = SUM(d.QUANTITY * d.SELLINGPRICE)  [SELLINGPRICE = birim net]
   NET filtre = STATUS NOT IN (1001,1006,1007,3000,4000).
   Tarih ISO YYYYMMDD. MCP-uyumlu (TOP + ORDER BY).
   Doğrulama (çıkış 11.06.2026): Paket 3.373 · Kitap 19.539 · Tutar 4,51M ₺.
            (08/04.06 ~6.500-7.000 paket, 5,8-6,9M ₺ — hafta içi pik.)
   Not: J_ORDER_DETAILS.ORDERREF = J_ORDERS.ORDERID (LOGICALREF DEĞİL).
   ============================================================ */
SELECT TOP 14
    CONVERT(varchar, o.SENDDATE, 104)                        AS CikisGunu,
    COUNT(DISTINCT o.LOGICALREF)                             AS PaketAdedi,
    SUM(d.QUANTITY)                                          AS KitapSayisi,
    CAST(SUM(d.QUANTITY) * 1.0 / NULLIF(COUNT(DISTINCT o.LOGICALREF),0)
         AS decimal(10,2))                                   AS PaketBasiKitap,
    CAST(SUM(d.QUANTITY * d.SELLINGPRICE) AS decimal(18,2))  AS ToplamTutar
FROM ODAKJOKER.JOKER.dbo.J_ORDERS o
JOIN ODAKJOKER.JOKER.dbo.J_ORDER_DETAILS d ON d.ORDERREF = o.ORDERID
WHERE o.SENDDATE >= '20260601' AND o.SENDDATE < '20260612'
  AND o.STATUS NOT IN (1001, 1006, 1007, 3000, 4000)
GROUP BY CONVERT(varchar, o.SENDDATE, 104)
ORDER BY CONVERT(varchar, o.SENDDATE, 104) DESC;
