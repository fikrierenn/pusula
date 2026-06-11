/* ============================================================
   L1 — Kargo Firma Performansı (JOKER e-ticaret)
   Firma × adet × ort. çıkış günü (ORDERDATE→SENDDATE)
            × ort. teslim günü (SENDDATE→CARGODELIVERYDATE)
   ------------------------------------------------------------
   Kaynak: ODAKJOKER.JOKER.dbo.J_ORDERS + J_CARGO (CARGOREF=ID)
   Tarih: ISO YYYYMMDD (linked server). NET filtre = STATUS
          NOT IN (1001,1006,1007,3000,4000) — 3004/3006 normal aşama.
   MCP-uyumlu (tek SELECT, TOP ile ORDER BY). Tarihleri elle değiştir.
   Doğrulama (2026-06-01→06-12): HEPSIJET 10.286 (çıkış 2g/teslim 1g),
          PTT 6.863 (2/2), MNG 3.206 (2/1), Bir Günde 2.102 (2/1).
   ============================================================ */
SELECT TOP 10
    c.CNAME                                                   AS KargoFirma,
    COUNT(*)                                                  AS PaketAdedi,
    AVG(DATEDIFF(DAY, o.ORDERDATE, o.SENDDATE))              AS OrtCikisGun,
    AVG(DATEDIFF(DAY, o.SENDDATE, o.CARGODELIVERYDATE))      AS OrtTeslimGun
FROM ODAKJOKER.JOKER.dbo.J_ORDERS o
LEFT JOIN ODAKJOKER.JOKER.dbo.J_CARGO c ON c.ID = o.CARGOREF
WHERE o.ORDERDATE >= '20260601' AND o.ORDERDATE < '20260612'
  AND o.SENDDATE IS NOT NULL
  AND o.CARGODELIVERYDATE IS NOT NULL
  AND o.STATUS NOT IN (1001, 1006, 1007, 3000, 4000)
GROUP BY c.CNAME
ORDER BY COUNT(*) DESC;
