/* ============================================================
   L3 — Bekleyen Sipariş Raporu (JOKER e-ticaret) — anlık
   İl × bekleyen toplam × toplanma bekleyen × önsipariş/hazırlanan
        × temin bekleyen
   ------------------------------------------------------------
   Kaynak: J_ORDERS (SENDDATE NULL = henüz kargoya verilmemiş)
   İl: J_ORDER_CLIENTS.CCITY (müşteri/fatura ili) — CLIENTREF=LOGICALREF.
       ⚠ J_ORDER_DELIVERY_ADDRESS (teslimat ili / DCITY) Odak-bekleyen
       siparişlerde DOLU DEĞİL → CCITY proxy kullanılır.
   Aşama kodları (sema codes.yaml joker.J_ORDERS.STATUS):
     1000               = Sipariş Alındı            → TOPLANMA BEKLEYEN
     3001 / 3003 / 3004 = Yeni / Onay / Hazırlanıyor → ÖNSİPARİŞ-HAZIRLANAN
     3006               = Tedarik Edilecek          → TEMİN BEKLEYEN
   ANLIK rapor (tarih filtresi YOK — o an açık olan tüm bekleyenler).
   MCP-uyumlu (TOP + ORDER BY).
   Doğrulama (12.06.2026 anlık): İstanbul 1.492 (334 hazırlanan + 1.157 temin),
            Ankara 630, İzmir 343, Bursa 238. Toplam bekleyen ~5.874.
   ============================================================ */
SELECT TOP 20
    cl.CCITY                                                              AS Il,
    COUNT(*)                                                             AS BekleyenToplam,
    SUM(CASE WHEN o.STATUS = 1000 THEN 1 ELSE 0 END)                    AS ToplanmaBekleyen,
    SUM(CASE WHEN o.STATUS IN (3001, 3003, 3004) THEN 1 ELSE 0 END)     AS OnSiparisHazirlanan,
    SUM(CASE WHEN o.STATUS = 3006 THEN 1 ELSE 0 END)                    AS TeminBekleyen
FROM ODAKJOKER.JOKER.dbo.J_ORDERS o
JOIN ODAKJOKER.JOKER.dbo.J_ORDER_CLIENTS cl ON cl.LOGICALREF = o.CLIENTREF
WHERE o.SENDDATE IS NULL
  AND o.STATUS IN (1000, 3001, 3003, 3004, 3006)
GROUP BY cl.CCITY
ORDER BY COUNT(*) DESC;
