-- Ekim 2026 hedefi geçen yıla göre makul mu? Kategori bazında: hedefin istediği büyüme (H Eki26 / G Eki25) vs gerçek büyüme (1-21 Eki ve Eylül YoY) + 2025 Ekim hedef tutma oranı.
-- Taban: kalem net TotalPrice-VatTotal, IsValid=1, tip 1,2,3,6,7,8, 1001 barkodlu fiş hariç.
-- Bulgu 22.10.2026: hedefler kategoriden bağımsız ~+50-60% düz artış; FSM Kitap trendi +20-24%; Akademi Eylül+Ekim toplamında da düşük.
WITH S AS (
  SELECT MG2.mekanID, ISNULL(CAST(u.urnKtgr2ID AS int),-1) AS ktgId,
    SUM(CASE WHEN s.Date >= '20251001' AND s.Date < '20251101' THEN x.n ELSE 0 END) AS G_Eki25,
    SUM(CASE WHEN s.Date >= '20251001' AND s.Date < '20251022' THEN x.n ELSE 0 END) AS G_Eki25_121,
    SUM(CASE WHEN s.Date >= '20261001' AND s.Date < '20261022' THEN x.n ELSE 0 END) AS G_Eki26_121,
    SUM(CASE WHEN s.Date >= '20250901' AND s.Date < '20251001' THEN x.n ELSE 0 END) AS G_Eyl25,
    SUM(CASE WHEN s.Date >= '20260901' AND s.Date < '20261001' THEN x.n ELSE 0 END) AS G_Eyl26
  FROM EncoreMerkez.dbo.Sales s
  JOIN EncoreMerkez.dbo.Pos p ON p.Id=s.PosId
  JOIN EncoreMerkez.dbo.Stores st ON st.Id=p.StoreId
  JOIN DerinSISBkm.dbo.posMagaza MG2 ON MG2.mekanKod COLLATE Turkish_CI_AS = st.Code COLLATE Turkish_CI_AS
  JOIN EncoreMerkez.dbo.SalesProducts sp ON sp.SalesId=s.Id AND sp.IsValid=1
  CROSS APPLY (SELECT (CASE WHEN s.DocumentsTypeId=3 THEN -1 ELSE 1 END)*(sp.TotalPrice-sp.VatTotal) AS n) x
  LEFT JOIN EncoreMerkez.dbo.Products pr ON pr.Id=sp.ProductsId
  LEFT JOIN DerinSISBkm.dbo.urn u ON u.stkID = CASE WHEN pr.Code COLLATE Latin1_General_BIN2 NOT LIKE '%[^0-9]%' AND LEN(pr.Code) BETWEEN 1 AND 9 THEN CONVERT(int, pr.Code) END
  WHERE ((s.Date >= '20250901' AND s.Date < '20251101') OR (s.Date >= '20260901' AND s.Date < '20261022'))
    AND s.DocumentsTypeId IN (1,2,3,6,7,8)
    AND NOT EXISTS (SELECT 1 FROM EncoreMerkez.dbo.SalesProducts b WHERE b.SalesId=s.Id AND b.BarcodeNo='1001')
  GROUP BY MG2.mekanID, ISNULL(CAST(u.urnKtgr2ID AS int),-1)
), H AS (
  SELECT mekanId AS mekanID, CAST(ktgId AS int) AS ktgId,
    SUM(CASE WHEN yil=2026 AND ay=10 THEN hedef ELSE 0 END) AS H_Eki26,
    SUM(CASE WHEN yil=2025 AND ay=10 THEN hedef ELSE 0 END) AS H_Eki25,
    SUM(CASE WHEN yil=2026 AND ay=9  THEN hedef ELSE 0 END) AS H_Eyl26
  FROM BKMDATA.dbo.Hedef WHERE mekanId IN (1,4477,4478) AND ((yil=2026 AND ay IN (9,10)) OR (yil=2025 AND ay=10))
  GROUP BY mekanId, ktgId
)
SELECT COALESCE(S.mekanID,H.mekanID) AS mekanID, COALESCE(S.ktgId,H.ktgId) AS ktgId,
  ISNULL(k.ktgrAd, N'(diğer/eşleşmeyen)') AS Kategori,
  CAST(ISNULL(H.H_Eki26,0) AS decimal(18,0)) H_Eki26, CAST(ISNULL(H.H_Eki25,0) AS decimal(18,0)) H_Eki25, CAST(ISNULL(H.H_Eyl26,0) AS decimal(18,0)) H_Eyl26,
  CAST(ISNULL(S.G_Eki25,0) AS decimal(18,0)) G_Eki25, CAST(ISNULL(S.G_Eki25_121,0) AS decimal(18,0)) G_Eki25_121,
  CAST(ISNULL(S.G_Eki26_121,0) AS decimal(18,0)) G_Eki26_121,
  CAST(ISNULL(S.G_Eyl25,0) AS decimal(18,0)) G_Eyl25, CAST(ISNULL(S.G_Eyl26,0) AS decimal(18,0)) G_Eyl26
FROM S FULL OUTER JOIN H ON H.mekanID=S.mekanID AND H.ktgId=S.ktgId
LEFT JOIN DerinSISBkm.dbo.urnKtgr2 k ON k.ktgrID = COALESCE(S.ktgId,H.ktgId)
;
