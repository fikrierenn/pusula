/* =======================================================================
   PDKS · TTagZei Segment İncelemesi — mola kırma kontrolü
   -----------------------------------------------------------------------
   GecoTime'ın günü nasıl segmentlere böldüğünü görmek için örnek sorgu.

   BULGU (14.04.2026 örnekleri):
     - Yemek molasını (60 dk) OTOMATİK kırıyor → iki NCAL segmenti
       arasında boşluk (örn. 12:00-13:00).
     - 2×15 dk çay molasını KIRMIYOR (kart okutulmuyor) → brüt içinde kalır.
     - Fazla mesai ayrı etiket: TZe_ZeitArt = 'FM1'.

   Segment tipleri:
     NCAL = normal çalışma
     FM1  = fazla mesai tipi 1 (hafta içi)
     (ZeitArt NULL) = günün toplam özet satırı
   ======================================================================= */

SELECT * FROM OPENQUERY([PDKS], '
SELECT TOP 30
  z.TZe_PersNr,
  CONVERT(varchar(10), z.TZe_Datum, 104)    AS Tarih,
  CONVERT(varchar(5),  z.TZe_VonZeit, 108)  AS VonZ,
  CONVERT(varchar(5),  z.TZe_BisZeit, 108)  AS BisZ,
  z.TZe_IstZeit                             AS SegSure,       -- saat.dk (10.05 = 10sa 05dk)
  z.TZe_ZeitArt                             AS ZeitArt,
  z.TZe_TagSollzeit                         AS TagSollzeit,   -- hedef net süre
  z.TZe_TagMod                              AS TagMod,
  l.TLe_IstZeit                             AS BrutSure
FROM TTagZei z
LEFT JOIN TTagLes l
  ON l.TLe_PersNr   = z.TZe_PersNr
 AND l.TLe_Datum    = z.TZe_Datum
 AND l.TLe_BeginnKz = 0
WHERE z.TZe_PersNr IN (20, 60, 184, 3128)   -- örnek personel
  AND z.TZe_Datum = ''20260414''
ORDER BY z.TZe_PersNr, z.TZe_VonZeit
');

/* Örnek çıktı yorumu:
   Sicil 20 (TagMod 830-1, hedef 9 sa net):
     - Segment 1: 08:30-12:00 NCAL = 3.30 (3sa 30dk)
     - Segment 2: 13:00-18:30 NCAL = 5.30 (5sa 30dk)
     - Toplam net = 9.00 sa, brüt = 10.07 (10sa 07dk)
     - Yemek molası (12-13) sistem tarafından düşülmüş.
*/
