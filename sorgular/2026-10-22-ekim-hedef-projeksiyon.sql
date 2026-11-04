-- Ekim 2026 hedef tutar mı? MTD (01-21.10) gerçekleşen vs BKMDATA.dbo.Hedef + geçen yıl 22-31 Ekim payı ile projeksiyon.
-- Taban: SabahService G1 ile aynı (EncoreMerkez KDV-hariç net, tip 1,2,3,6,7,8, iade eksi, 1001 barkodlu fiş hariç).
-- Bulgu 22.10.2026: FSM ~%96 (≈1,1M açık), Özlüce ~%100-101,5 (sınırda), İst.Yolu ~%110, toplam ~%102-103.
WITH S AS (
  SELECT MG2.mekanID, CAST(s.Date AS date) AS g,
    SUM(CASE WHEN s.DocumentsTypeId=3 THEN -1 ELSE 1 END*(s.GrossTotal-s.DiscountTotal-s.VatTotal)) AS Net
  FROM EncoreMerkez.dbo.Sales s
  JOIN EncoreMerkez.dbo.Pos p ON p.Id=s.PosId
  JOIN EncoreMerkez.dbo.Stores st ON st.Id=p.StoreId
  JOIN DerinSISBkm.dbo.posMagaza MG2 ON MG2.mekanKod COLLATE Turkish_CI_AS = st.Code COLLATE Turkish_CI_AS
  LEFT JOIN EncoreMerkez.dbo.SalesProducts spb ON spb.SalesId=s.Id AND spb.BarcodeNo='1001'
  WHERE ((s.Date >= '20261001' AND s.Date < '20261022') OR (s.Date >= '20251001' AND s.Date < '20251101'))
    AND s.DocumentsTypeId IN (1,2,3,6,7,8) AND spb.Id IS NULL
  GROUP BY MG2.mekanID, CAST(s.Date AS date)
), H AS (
  SELECT mekanId AS mekanID,
    SUM(CASE WHEN tarih < '20261022' THEN hedef ELSE 0 END) AS HedefMTD,
    SUM(hedef) AS HedefAy
  FROM BKMDATA.dbo.Hedef WHERE mekanId IN (1,4477,4478) AND yil=2026 AND ay=10
  GROUP BY mekanId
)
SELECT h.mekanID, h.HedefMTD, h.HedefAy,
  (SELECT SUM(Net) FROM S WHERE S.mekanID=h.mekanID AND g>='20261001') AS GercekMTD,
  (SELECT SUM(Net) FROM S WHERE S.mekanID=h.mekanID AND g>='20251001' AND g<'20251022') AS GY_1_21,
  (SELECT SUM(Net) FROM S WHERE S.mekanID=h.mekanID AND g>='20251022' AND g<'20251101') AS GY_22_31
FROM H h ORDER BY h.mekanID
;
