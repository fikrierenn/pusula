/* =======================================================================
   PDKS · Fazla Mesai TOP N — FM1 segmentleri (DOĞRU yöntem)
   -----------------------------------------------------------------------
   Kaynak : dbo.TTagZei (detay segment tablosu)
   Filtre : TZe_ZeitArt = 'FM1' → sistem tarafından fazla mesai olarak
            etiketlenmiş segmentler.

   NEDEN brüt − plan DEĞİL:
     - Brüt (TLe_IstZeit) ilk giriş ↔ son çıkış arasıdır.
     - GecoTime yemek molasını (kart okutulduğunda) otomatik kırar ama
       2×15 dk çay molası brüt içinde kalır → yanlış pozitif üretir.
     - FM1 ise sistemin etiketlediği gerçek fazla mesai dilimidir.

   Sunucu : 192.168.40.201 (BKM DB) → OPENQUERY([PDKS], ...)
   Tarih  : OPENQUERY içinde YYYYMMDD (ISO), dış sorguda DMY 104.
   ======================================================================= */

SELECT TOP 10 * FROM OPENQUERY([PDKS], '
SELECT
  z.TZe_PersNr                              AS Sicil,
  p.Per_Vorname + '' '' + p.Per_Name        AS AdSoyad,
  p.Per_Grp2                                AS Bolum,
  COUNT(DISTINCT z.TZe_Datum)               AS Gun,
  CAST(SUM(DATEDIFF(MINUTE, z.TZe_VonZeit, z.TZe_BisZeit)) / 60.0
       AS decimal(10,2))                    AS FmSaat,
  SUM(DATEDIFF(MINUTE, z.TZe_VonZeit, z.TZe_BisZeit)) AS FmDk
FROM TTagZei z
INNER JOIN TPerTab p ON p.Per_PersNr = z.TZe_PersNr
WHERE z.TZe_Datum >= ''20260401'' AND z.TZe_Datum <= ''20260415''
  AND z.TZe_ZeitArt = ''FM1''
  AND z.TZe_VonZeit IS NOT NULL
  AND z.TZe_BisZeit IS NOT NULL
GROUP BY z.TZe_PersNr, p.Per_Vorname, p.Per_Name, p.Per_Grp2
ORDER BY FmDk DESC
') ORDER BY FmDk DESC;
