-- Kumbara indirim raporu: Mağaza × Gün (17.06.2026 — kullanıcı SQL)
-- DB: EncoreMerkez (ana) + DerinSISBkm (magaza filtresi) + DerinCrm (opsiyonel)
-- Köprü: Sales → SalesProducts (IsValid=1) → SalesProductCampaigns (CampaignId IS NULL, CampaignVersion=rr.Id)
--         → RefundReasons rr (Id=17 = 'Okul Kumbara Projesi İndirimi', Type=1)
-- Bulgu: SPC.CampaignVersion = RefundReasons.Id (manuel indirim tipi bağı) — önceden bilinmiyordu
-- TotalAmount bu sorguda SatirSayisi (ürün adet) olarak kullanılıyor (ciro değil — sql-server-conventions.md §TotalAmount)

WITH aaa AS (
    SELECT DISTINCT
           U.Name + ' ' + U.SurName AS Kasiyer,
           st.Name                  AS Magaza,
           st.Code,
           S.DocumentNo             AS Belge_ID,
           PS.Code                  AS Kasa_No,
           S.Id                     AS Belge_No,
           CONVERT(date, s.[Date])  AS Tarih,
           s.GrossTotal,
           s.DiscountTotal,
           s.TotalAmount
    FROM EncoreMerkez.dbo.Sales             S   WITH(NOLOCK)
    JOIN EncoreMerkez.dbo.Users             U   WITH(NOLOCK) ON U.Id = S.UsersId
    JOIN EncoreMerkez.dbo.Documents         dt  WITH(NOLOCK) ON dt.Id = s.DocumentsTypeId
    JOIN EncoreMerkez.dbo.SalesProducts     P   WITH(NOLOCK) ON p.SalesId = S.Id AND p.IsValid = 1
    JOIN EncoreMerkez.dbo.SalesProductCampaigns SPC WITH(NOLOCK)
         ON spc.SalesId = s.Id AND spc.ProductSequence = p.[Sequence] AND CampaignId IS NULL
    JOIN EncoreMerkez.dbo.RefundReasons     rr  WITH(NOLOCK) ON rr.Id = spc.CampaignVersion
    JOIN EncoreMerkez.dbo.Pos               ps  WITH(NOLOCK) ON ps.Id = s.PosId
    JOIN EncoreMerkez.dbo.Stores            st  WITH(NOLOCK) ON st.Id = ps.StoreId
    JOIN DerinSISBkm.dbo.posMagaza          MG  WITH(NOLOCK)
         ON mg.mekanKod = st.Code AND mg.mekanID IN (1, 4477, 4478)
    LEFT JOIN DerinCrm.dbo.Customer         dc  WITH(NOLOCK) ON dc.CardNumber = s.CustomerCardNo
    WHERE CONVERT(DATE, s.[Date]) > '2026-01-01'
      AND rr.Id = 17   -- Okul Kumbara Projesi İndirimi
)
SELECT
    a.Magaza,
    a.Code,
    a.Tarih,
    SUM(a.GrossTotal)                              AS Tutar,
    SUM(a.DiscountTotal)                           AS Indirim,
    ROUND(SUM(a.DiscountTotal) / SUM(a.GrossTotal), 2) AS IndirimYuzde,
    COUNT(1)                                       AS FisSayisi,
    CONVERT(int, SUM(a.TotalAmount))               AS SatirSayisi
FROM aaa a
GROUP BY a.Magaza, a.Tarih, a.Code
ORDER BY a.Tarih DESC, a.Magaza;
