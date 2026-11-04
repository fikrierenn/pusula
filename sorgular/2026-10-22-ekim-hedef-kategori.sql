-- Ekim 2026 hedef/gerçekleşen KATEGORİ bazında (mağaza × urnKtgr2), MTD 01-21.10 + geçen yıl 22-31 Ekim payı.
-- Kalem neti = TotalPrice - VatTotal (IsValid=1); toplamı başlık KDV-hariç net ile birebir tuttu (FSM 23.221.070).
-- Bulgu 22.10.2026: FSM açığı Kitap (-1,0M) + Akademi (-0,8M); Akademi üç mağazada da hedefin ~%55-63'ünde.
WITH S AS (
  SELECT MG2.mekanID, ISNULL(CAST(u.urnKtgr2ID AS int),-1) AS ktgId,
    SUM(CASE WHEN s.Date >= '20261001' THEN (CASE WHEN s.DocumentsTypeId=3 THEN -1 ELSE 1 END)*(sp.TotalPrice-sp.VatTotal) ELSE 0 END) AS GercekMTD,
    SUM(CASE WHEN s.Date >= '20251001' AND s.Date < '20251022' THEN (CASE WHEN s.DocumentsTypeId=3 THEN -1 ELSE 1 END)*(sp.TotalPrice-sp.VatTotal) ELSE 0 END) AS GY_1_21,
    SUM(CASE WHEN s.Date >= '20251022' AND s.Date < '20251101' THEN (CASE WHEN s.DocumentsTypeId=3 THEN -1 ELSE 1 END)*(sp.TotalPrice-sp.VatTotal) ELSE 0 END) AS GY_22_31
  FROM EncoreMerkez.dbo.Sales s
  JOIN EncoreMerkez.dbo.Pos p ON p.Id=s.PosId
  JOIN EncoreMerkez.dbo.Stores st ON st.Id=p.StoreId
  JOIN DerinSISBkm.dbo.posMagaza MG2 ON MG2.mekanKod COLLATE Turkish_CI_AS = st.Code COLLATE Turkish_CI_AS
  JOIN EncoreMerkez.dbo.SalesProducts sp ON sp.SalesId=s.Id AND sp.IsValid=1
  LEFT JOIN EncoreMerkez.dbo.Products pr ON pr.Id=sp.ProductsId
  LEFT JOIN DerinSISBkm.dbo.urn u ON u.stkID = CASE WHEN pr.Code COLLATE Latin1_General_BIN2 NOT LIKE '%[^0-9]%' AND LEN(pr.Code) BETWEEN 1 AND 9 THEN CONVERT(int, pr.Code) END
  WHERE ((s.Date >= '20261001' AND s.Date < '20261022') OR (s.Date >= '20251001' AND s.Date < '20251101'))
    AND s.DocumentsTypeId IN (1,2,3,6,7,8)
    AND NOT EXISTS (SELECT 1 FROM EncoreMerkez.dbo.SalesProducts b WHERE b.SalesId=s.Id AND b.BarcodeNo='1001')
  GROUP BY MG2.mekanID, ISNULL(CAST(u.urnKtgr2ID AS int),-1)
), H AS (
  SELECT mekanId AS mekanID, ktgId,
    SUM(CASE WHEN tarih < '20261022' THEN hedef ELSE 0 END) AS HedefMTD, SUM(hedef) AS HedefAy
  FROM BKMDATA.dbo.Hedef WHERE mekanId IN (1,4477,4478) AND yil=2026 AND ay=10
  GROUP BY mekanId, ktgId
)
SELECT COALESCE(S.mekanID,H.mekanID) AS mekanID, COALESCE(S.ktgId,H.ktgId) AS ktgId,
  ISNULL(k.ktgrAd, CASE COALESCE(S.ktgId,H.ktgId) WHEN 0 THEN N'(kırılımsız 0)' WHEN 255 THEN N'(255)' ELSE N'(eşleşmeyen)' END) AS Kategori,
  CAST(ISNULL(H.HedefMTD,0) AS decimal(18,0)) AS HedefMTD, CAST(ISNULL(H.HedefAy,0) AS decimal(18,0)) AS HedefAy,
  CAST(ISNULL(S.GercekMTD,0) AS decimal(18,0)) AS GercekMTD,
  CAST(ISNULL(S.GY_1_21,0) AS decimal(18,0)) AS GY_1_21, CAST(ISNULL(S.GY_22_31,0) AS decimal(18,0)) AS GY_22_31
FROM S FULL OUTER JOIN H ON H.mekanID=S.mekanID AND H.ktgId=S.ktgId
LEFT JOIN DerinSISBkm.dbo.urnKtgr2 k ON k.ktgrID = COALESCE(S.ktgId,H.ktgId)
;
