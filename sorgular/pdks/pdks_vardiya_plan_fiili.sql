/* =======================================================================
   PDKS + Vardiya Plan-Fiili Karşılaştırma — Günlük
   -----------------------------------------------------------------------
   Kaynaklar:
     - BKM.vrd.Vardiya          → haftalık vardiya başlığı
     - BKM.vrd.VardiyaDetay     → kişi × haftanın günü (Pazartesi..Pazar)
     - BKM.vrd.VardiyaZaman     → vardiya kodu → saat aralığı + mola
     - BKM.vrd.SubeListe        → şube adı
     - GecoTime.TPerInd         → TC Kimlik ↔ Per_PersNr (BRIDGE)
     - GecoTime.TTagLes         → günlük özet (ilk giriş, son çıkış, brüt)

   Köprü:
     vrd.VardiyaDetay.SicilNo (TC, 11 hane) COLLATE Turkish_CI_AS
       = GecoTime.TPerInd.PIn_SteuerNr COLLATE Turkish_CI_AS
     → GecoTime.TPerInd.PIn_PersNr = TTagLes.TLe_PersNr

   Özel kodlar (vrd.VardiyaDetay.Carsamba gibi):
     51=HFT.İZİN, 52=ÜCRETSİZ, 53=ÜCRTLİ, 55=RESMİ TATİL,
     58=YILLIK, 62=GÜVENLİK, 63=RAPOR, 73=MESAİ İZNİ

   KRİTİK: vrd.Vardiya.Tarih = haftanın Pazartesi'si.
           15.04.2026 Çarşamba için Tarih = 13.04.2026.
   ======================================================================= */

DECLARE @Tarih date = '15.04.2026';            -- hedef gün (rapor tarihi)
DECLARE @HaftaBas date = DATEADD(DAY, 1 - DATEPART(WEEKDAY, @Tarih), @Tarih);
-- DİKKAT: DATEFIRST=7 ise Pazar=1, Pazartesi=2 olur. Aşağıdaki basit fallback:
DECLARE @Pazartesi date = DATEADD(DAY, -((DATEPART(WEEKDAY, @Tarih) + @@DATEFIRST + 5) % 7), @Tarih);

-- Hangi gün kolonunu kullanacağız?
DECLARE @GunKol varchar(20) =
  CASE DATENAME(WEEKDAY, @Tarih)
    WHEN 'Monday'    THEN 'Pazartesi'
    WHEN 'Tuesday'   THEN 'Sali'
    WHEN 'Wednesday' THEN 'Carsamba'
    WHEN 'Thursday'  THEN 'Persembe'
    WHEN 'Friday'    THEN 'Cuma'
    WHEN 'Saturday'  THEN 'Cumartesi'
    WHEN 'Sunday'    THEN 'Pazar'
  END;

-- Dinamik kolon kullanımı gerektiğinde dynamic SQL. Burada örnek: Çarşamba (15.04.2026)
SELECT TOP 500
  s.SubeAd                                         AS Sube,
  vd.Bolum                                         AS Bolum,
  vd.Personel                                      AS Personel,
  vd.SicilNo                                       AS TC,
  vz.Aciklama                                      AS PlanVardiya,
  CONVERT(varchar(5), vz.Baslama, 108)             AS PlanBas,
  CONVERT(varchar(5), vz.Bitis, 108)               AS PlanBit,
  vz.ToplamCalismaDk                               AS PlanDk,
  l.FiiliGiris                                     AS FiiliGiris,
  l.FiiliCikis                                     AS FiiliCikis,
  l.BrutSure                                       AS BrutSure,
  l.MazeretKod                                     AS MazeretKod
FROM vrd.Vardiya v
INNER JOIN vrd.VardiyaDetay vd ON vd.VardiyaNo = v.VardiyaNo
INNER JOIN vrd.VardiyaZaman  vz ON vz.VardiyaId = vd.Carsamba    -- ← gün kolonu
INNER JOIN vrd.SubeListe     s  ON s.SubeNo   = v.SubeNo
LEFT JOIN OPENQUERY([PDKS], '
  SELECT i.PIn_SteuerNr                            AS TC,
         CONVERT(varchar(5), l.TLe_VonZeit, 108)   AS FiiliGiris,
         CONVERT(varchar(5), l.TLe_BisZeit, 108)   AS FiiliCikis,
         l.TLe_IstZeit                             AS BrutSure,
         l.TLe_AbwArt                              AS MazeretKod
  FROM TPerInd i
  INNER JOIN TTagLes l ON l.TLe_PersNr = i.PIn_PersNr
  WHERE l.TLe_Datum = ''20260415''                 -- ← hedef gün (ISO)
    AND l.TLe_BeginnKz = 0
') l
  ON l.TC COLLATE Turkish_CI_AS = vd.SicilNo COLLATE Turkish_CI_AS
WHERE v.Tarih = CONVERT(datetime, '13.04.2026', 104)  -- ← haftanın Pazartesi'si
  AND vd.Carsamba NOT IN (51,52,53,55,58,62,63,73)     -- planlı çalışma günleri
ORDER BY s.SubeAd, vd.Bolum, vd.Personel;
