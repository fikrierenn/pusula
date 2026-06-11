/* ============================================================
   M1 — Hedef / Gerçekleşen (mağaza × kategori, MTD)
   Mağaza × kategori × MTD net × aylık hedef × gerçekleşme %
   ------------------------------------------------------------
   HEDEF: BKMDATA.dbo.Hedef (mekanId, yil, ay, gun, ktgId, hedef)
          — günlük satırlar; ay için SUM(hedef).
   KÖPRÜ: Hedef.ktgId = DerinSISBkm.dbo.urnKtgr2.ktgrID = urn.urnKtgrID2 (KTGR2 seviyesi)
          (15=Kitap, 8=Hazırlık Kitapları, 12=Kırtasiye, 2=Çocuk Kitabı ...)
   NET (gerçekleşen): EncoreMerkez Sales → Products.Code=urn.stkID köprüsü
          → urn.urnKtgrID2 → kategori.  (SalesProducts net = TotalPrice - DiscountTotalDirect)
   Mağaza: posMagaza.mekanKod = Stores.Code (M01=FSM/1, M02=Özlüce/4477, M03=İstYolu/4478).
   Belge: DocumentsTypeId IN (1,2,3,6,7,8), İade(3) negatif.
   ------------------------------------------------------------
   Haziran 2026 ay hedefleri (doğrulandı): FSM 14,25M · Özlüce 23,5M ·
          İst.Yolu 13M · (Depo mekanId=12 → 77M, retail dışı).
   ============================================================
   --- A) MCP-UYUMLU (tek mağaza, tek SELECT; mekanID + tarihleri elle değiştir) --- */
SELECT
    k.ktgrAd                                                                AS Kategori,
    CAST(SUM((CASE WHEN s.DocumentsTypeId=3 THEN -1 ELSE 1 END)
             * (sp.TotalPrice - sp.DiscountTotalDirect)) AS decimal(18,2))  AS NetMTD
FROM EncoreMerkez.dbo.Sales s
JOIN EncoreMerkez.dbo.Pos p              ON p.Id = s.PosId
JOIN EncoreMerkez.dbo.Stores st          ON st.Id = p.StoreId
JOIN DerinSISBkm.dbo.posMagaza MG        ON MG.mekanKod COLLATE Turkish_CI_AS = st.Code COLLATE Turkish_CI_AS
JOIN EncoreMerkez.dbo.SalesProducts sp   ON sp.SalesId = s.Id AND sp.IsValid = 1
JOIN EncoreMerkez.dbo.Products pr        ON pr.Id = sp.ProductsId AND ISNUMERIC(pr.Code) = 1
JOIN DerinSISBkm.dbo.urn u               ON u.stkID = CONVERT(int, pr.Code)
JOIN DerinSISBkm.dbo.urnKtgr2 k          ON k.ktgrID = u.urnKtgrID2
WHERE s.Date >= '20260601' AND s.Date < '20260612'      -- MTD aralığı
  AND s.DocumentsTypeId IN (1,2,3,6,7,8)
  AND MG.mekanID = 1                                     -- 1=FSM, 4477=Özlüce, 4478=İst.Yolu
GROUP BY k.ktgrAd;

/* --- B) Hedef tarafı (MCP-uyumlu) — yukarıdaki net'le kategori bazında eşleştir --- */
-- SELECT k.ktgrAd, CAST(SUM(h.hedef) AS decimal(18,2)) AS AyHedef
-- FROM BKMDATA.dbo.Hedef h
-- JOIN DerinSISBkm.dbo.urnKtgr2 k ON k.ktgrID = h.ktgId
-- WHERE h.yil=2026 AND h.ay=6 AND h.mekanId=1
-- GROUP BY k.ktgrAd;

/* ============================================================
   --- C) BİRLEŞİK (SSMS — CTE; gerçekleşme % dahil 3 mağaza) ---
   ============================================================ */
WITH Net AS (
    SELECT MG.mekanID, u.urnKtgrID2 AS ktgId,
           SUM((CASE WHEN s.DocumentsTypeId=3 THEN -1 ELSE 1 END)
               * (sp.TotalPrice - sp.DiscountTotalDirect)) AS NetMTD
    FROM EncoreMerkez.dbo.Sales s
    JOIN EncoreMerkez.dbo.Pos p              ON p.Id = s.PosId
    JOIN EncoreMerkez.dbo.Stores st          ON st.Id = p.StoreId
    JOIN DerinSISBkm.dbo.posMagaza MG        ON MG.mekanKod COLLATE Turkish_CI_AS = st.Code COLLATE Turkish_CI_AS
    JOIN EncoreMerkez.dbo.SalesProducts sp   ON sp.SalesId = s.Id AND sp.IsValid = 1
    JOIN EncoreMerkez.dbo.Products pr        ON pr.Id = sp.ProductsId AND ISNUMERIC(pr.Code) = 1
    JOIN DerinSISBkm.dbo.urn u               ON u.stkID = CONVERT(int, pr.Code)
    WHERE s.Date >= '20260601' AND s.Date < '20260612'
      AND s.DocumentsTypeId IN (1,2,3,6,7,8)
      AND MG.mekanID IN (1,4477,4478)
    GROUP BY MG.mekanID, u.urnKtgrID2
),
Hed AS (
    SELECT mekanId AS mekanID, ktgId, SUM(hedef) AS AyHedef
    FROM BKMDATA.dbo.Hedef
    WHERE yil=2026 AND ay=6 AND mekanId IN (1,4477,4478)
    GROUP BY mekanId, ktgId
)
SELECT
    CASE h.mekanID WHEN 1 THEN 'FSM' WHEN 4477 THEN 'Özlüce' WHEN 4478 THEN 'İst.Yolu' END AS Magaza,
    k.ktgrAd                                          AS Kategori,
    CAST(ISNULL(n.NetMTD,0)  AS decimal(18,2))        AS NetMTD,
    CAST(h.AyHedef           AS decimal(18,2))        AS AyHedef,
    CAST(100.0 * ISNULL(n.NetMTD,0) / NULLIF(h.AyHedef,0) AS decimal(9,2)) AS GerceklesmePct
FROM Hed h
JOIN DerinSISBkm.dbo.urnKtgr2 k ON k.ktgrID = h.ktgId
LEFT JOIN Net n ON n.mekanID = h.mekanID AND n.ktgId = h.ktgId
ORDER BY h.mekanID, h.AyHedef DESC;
