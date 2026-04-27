/* =======================================================================
   PDKS + Vardiya · Şube Bazlı Günlük Özet
   -----------------------------------------------------------------------
   Mağaza başına: Plan / Geldi / Gelmedi / İzinli
   Panoda "Mağaza Plan-Fiili Eşleşmesi" kartının kaynağı.
   ======================================================================= */

SELECT TOP 20
  s.SubeAd AS Sube,
  COUNT(*) AS PlanSayisi,
  SUM(CASE WHEN l.FiiliGiris IS NOT NULL                         THEN 1 ELSE 0 END) AS Geldi,
  SUM(CASE WHEN l.FiiliGiris IS NULL
            AND (l.MazeretKod IS NULL OR l.MazeretKod = '')      THEN 1 ELSE 0 END) AS Gelmedi,
  SUM(CASE WHEN l.MazeretKod IS NOT NULL AND l.MazeretKod <> ''  THEN 1 ELSE 0 END) AS Izinli
FROM vrd.Vardiya v
INNER JOIN vrd.VardiyaDetay vd ON vd.VardiyaNo = v.VardiyaNo
INNER JOIN vrd.SubeListe     s  ON s.SubeNo   = v.SubeNo
LEFT JOIN OPENQUERY([PDKS], '
  SELECT i.PIn_SteuerNr                            AS TC,
         CONVERT(varchar(5), l.TLe_VonZeit, 108)   AS FiiliGiris,
         l.TLe_AbwArt                              AS MazeretKod
  FROM TPerInd i
  INNER JOIN TTagLes l ON l.TLe_PersNr = i.PIn_PersNr
  WHERE l.TLe_Datum = ''20260415''
    AND l.TLe_BeginnKz = 0
') l
  ON l.TC COLLATE Turkish_CI_AS = vd.SicilNo COLLATE Turkish_CI_AS
WHERE v.Tarih = CONVERT(datetime, '13.04.2026', 104)
  AND vd.Carsamba NOT IN (51,52,53,55,58,62,63,73)
GROUP BY s.SubeAd
ORDER BY s.SubeAd;
