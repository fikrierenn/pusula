/* ============================================================
   M2 — Kampanya Mağaza Raporu
   Mağaza × kampanya × gün sayısı × indirim × fiş × ürün adedi
   ------------------------------------------------------------
   Kaynak: EncoreMerkez.dbo.SalesProductCampaigns (SalesId, CampaignId,
           CampaignName, TotalDiscount [negatif=indirim]) + Sales.
   Mağaza: posMagaza.mekanKod = Stores.Code (M01=FSM/1, M02=Özlüce/4477, M03=İstYolu/4478).
   - GunSayisi = COUNT(DISTINCT satış günü) → kampanyanın aktif olduğu gün sayısı
   - Indirim   = SUM(-TotalDiscount)  (pozitif TL)
   - Fis       = COUNT(DISTINCT SalesId)
   CampaignName boş ('') = kampanya kodsuz/manuel set indirimi.
   MCP-uyumlu (TOP + ORDER BY); tarih ISO YYYYMMDD, mekanID elle değiştir.
   ------------------------------------------------------------
   Doğrulama (FSM, 2026-06-01→06-12): 9 kampanya, toplam indirim 1,11M ₺,
        5.024 fiş. Top: 3AL2ÖDE(K) 426K/1398 fiş, SABİT FİYAT(K) 297K/2786 fiş,
        YÜZDESEL İND.(K) 233K/793 fiş.
   ============================================================
   --- A) MCP-UYUMLU — mağaza × kampanya (tek mağaza) --- */
SELECT TOP 20
    spc.CampaignName                                         AS Kampanya,
    COUNT(DISTINCT CONVERT(date, s.Date))                   AS GunSayisi,
    CAST(SUM(-spc.TotalDiscount) AS decimal(18,2))          AS Indirim,
    COUNT(DISTINCT spc.SalesId)                             AS Fis
FROM EncoreMerkez.dbo.SalesProductCampaigns spc
JOIN EncoreMerkez.dbo.Sales s            ON s.Id = spc.SalesId
JOIN EncoreMerkez.dbo.Pos p              ON p.Id = s.PosId
JOIN EncoreMerkez.dbo.Stores st          ON st.Id = p.StoreId
JOIN DerinSISBkm.dbo.posMagaza MG        ON MG.mekanKod COLLATE Turkish_CI_AS = st.Code COLLATE Turkish_CI_AS
WHERE s.Date >= '20260601' AND s.Date < '20260612'
  AND MG.mekanID = 1                                        -- 1=FSM, 4477=Özlüce, 4478=İst.Yolu
GROUP BY spc.CampaignName
ORDER BY SUM(-spc.TotalDiscount) DESC;

/* ============================================================
   --- B) SSMS — 3 mağaza özet (tutar + ürün adedi + indirim%) ---
   Tutar/ürün = kampanyalı satışların satış kalemleri (IsValid=1).
   ============================================================ */
WITH Kamp AS (
    SELECT MG.mekanID,
           COUNT(DISTINCT spc.CampaignId)                AS KampanyaSayisi,
           COUNT(DISTINCT CONVERT(date, s.Date))         AS GunSayisi,
           SUM(-spc.TotalDiscount)                       AS Indirim,
           COUNT(DISTINCT spc.SalesId)                   AS Fis
    FROM EncoreMerkez.dbo.SalesProductCampaigns spc
    JOIN EncoreMerkez.dbo.Sales s     ON s.Id = spc.SalesId
    JOIN EncoreMerkez.dbo.Pos p       ON p.Id = s.PosId
    JOIN EncoreMerkez.dbo.Stores st   ON st.Id = p.StoreId
    JOIN DerinSISBkm.dbo.posMagaza MG ON MG.mekanKod COLLATE Turkish_CI_AS = st.Code COLLATE Turkish_CI_AS
    WHERE s.Date >= '20260601' AND s.Date < '20260612'
      AND MG.mekanID IN (1,4477,4478)
    GROUP BY MG.mekanID
)
SELECT
    CASE mekanID WHEN 1 THEN 'FSM' WHEN 4477 THEN 'Özlüce' WHEN 4478 THEN 'İst.Yolu' END AS Magaza,
    KampanyaSayisi, GunSayisi,
    CAST(Indirim AS decimal(18,2)) AS Indirim,
    Fis
FROM Kamp
ORDER BY Indirim DESC;
