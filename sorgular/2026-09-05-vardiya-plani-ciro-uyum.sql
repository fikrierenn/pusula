/* ============================================================================
   VARDİYA PLANI ↔ SAATLİK CİRO UYUMU (3 POS mağazası)
   DB      : DerinSISBkm (EncoreMerkez 3-parçalı + OPENQUERY([PDKS]) GecoTime)
   Pencere : 29.08–04.09.2026 (7 gün, 183 tekil personel, 942 kişi-gün)
   Soru    : "Saatlik ciroya göre vardiya planında hatalı yapılan bir şey var mı?"
   Bulgu   : (1) G3 vardiyasının molası 17:00 — haftanın EN YOĞUN saati (fişlerin
             %11,6'sı). 942 kişi-günün 501'i (%53) o saatte molada → planlı kapsama
             818→361 kişi-saat düşüyor. (2) 10:00-11:00 aşırı kadro (kişi-saatin
             %9,7'si, fişin %5,4'ü). (3) 19-21 dar (kadro %22, fiş %27) → hafta
             içinde 1.423 kişi-saat fazla mesai ile kapatılıyor.
   NOT     : sqlcli varsayılan --max-rows 1000 SESSİZ keser → bu sorgularda 5000 ver.
============================================================================ */

-- [1] VARDİYA KATALOĞU (plan modelleri). TZe_TagMod = o kişi-güne atanan PLAN.
--     Kern* = planlı vardiya penceresi, Pau1* = planlı mola.
SELECT * FROM OPENQUERY([PDKS], '
  SELECT t.Tag_TagMod, t.Tag_TagModBez, t.Tag_TagSollzeit,
    CONVERT(varchar(5),t.Tag_KernVonZeit,108) kern_v, CONVERT(varchar(5),t.Tag_KernBisZeit,108) kern_b,
    CONVERT(varchar(5),t.Tag_Pau1VonZeit,108) mola_v, CONVERT(varchar(5),t.Tag_Pau1BisZeit,108) mola_b
  FROM TTagMod t
  WHERE t.Tag_TagMod IN (''G1'',''G2'',''G3'',''G4'',''818'',''830-1'',''919'',''2408'')');
/* Ölçülen katalog (04.09.2026):
   G1 09:00-17:30 mola 12-13 | G2 10:00-18:30 mola 13-14 | G3 13:30-22:00 mola 17-18
   G4 14:30-23:00 mola 18-19 | 818 08:00-18:00 | 830-1 08:30-18:30 | 919 09:00-19:00 (mola 12-13)
   2408 00:00-08:00 (gece) | SABIT/SBT9 = 03:00-03:01 kukla pencere (saat takibi YOK) */

-- [2] KİŞİ-GÜN PLAN + FİİLİ (mağaza × gün × personel)
SELECT * FROM OPENQUERY([PDKS], '
  SELECT CONVERT(varchar(8),z.TZe_Datum,112) gun, LTRIM(RTRIM(p.Per_Grp2)) magaza,
         z.TZe_PersNr pers, MAX(z.TZe_TagMod) tagmod,
         MAX(CASE WHEN z.TZe_AbwArt=''DESIZ'' THEN 1 ELSE 0 END) devamsiz,
         MAX(CASE WHEN z.TZe_AbwArt=''RESTA'' THEN 1 ELSE 0 END) resmitatil,
         MIN(CASE WHEN z.TZe_VonZeit IS NOT NULL THEN CONVERT(varchar(5),z.TZe_VonZeit,108) END) giris,
         MAX(CASE WHEN z.TZe_BisZeit IS NOT NULL THEN CONVERT(varchar(5),z.TZe_BisZeit,108) END) cikis,
         SUM(CASE WHEN z.TZe_ZeitArt LIKE ''FM%'' THEN z.TZe_IstZeit ELSE 0 END) fm_saat,
         MAX(z.TZe_TagSollzeit) soll
  FROM TTagZei z JOIN TPerTab p ON p.Per_PersNr=z.TZe_PersNr
  WHERE z.TZe_Datum>=''20260829'' AND z.TZe_Datum<=''20260904''
    AND p.Per_Grp1 LIKE ''MA%LAR''
    AND LTRIM(RTRIM(p.Per_Grp2)) IN (''FSM'',''ÖZLÜCE'',''İST.YOLU'')
  GROUP BY CONVERT(varchar(8),z.TZe_Datum,112), LTRIM(RTRIM(p.Per_Grp2)), z.TZe_PersNr');

-- [3] FİİLİ SEGMENTLER (kişi-saat eğrisi + mola boşluğu tespiti)
--     ZeitArt: NCAL = normal çalışma · FM1/FM3 = fazla mesai dilimleri.
SELECT * FROM OPENQUERY([PDKS], '
  SELECT CONVERT(varchar(8),z.TZe_Datum,112) gun, LTRIM(RTRIM(p.Per_Grp2)) magaza, z.TZe_PersNr pers,
         CONVERT(varchar(5),z.TZe_VonZeit,108) v, CONVERT(varchar(5),z.TZe_BisZeit,108) b, z.TZe_ZeitArt zart
  FROM TTagZei z JOIN TPerTab p ON p.Per_PersNr=z.TZe_PersNr
  WHERE z.TZe_Datum>=''20260829'' AND z.TZe_Datum<=''20260904''
    AND p.Per_Grp1 LIKE ''MA%LAR''
    AND LTRIM(RTRIM(p.Per_Grp2)) IN (''FSM'',''ÖZLÜCE'',''İST.YOLU'')
    AND z.TZe_VonZeit IS NOT NULL AND z.TZe_BisZeit IS NOT NULL');

-- [4] TALEP TARAFI: mağaza × gün × saat fiş/ciro (Sınav ayrıştırılmış)
SELECT CONVERT(varchar(8),s.Date,112) gun,
  CASE s.StoresId WHEN 1 THEN 'IST.YOLU' WHEN 2 THEN 'FSM' WHEN 3 THEN 'OZLUCE' END magaza,
  DATEPART(hour,s.Date) saat, COUNT(*) fis,
  SUM(CASE WHEN s.DocumentsTypeId=3 THEN -(s.GrossTotal-s.DiscountTotal-s.VatTotal)
           ELSE (s.GrossTotal-s.DiscountTotal-s.VatTotal) END) net,
  SUM(CASE WHEN s.DocumentsTypeId=8 THEN (s.GrossTotal-s.DiscountTotal-s.VatTotal) ELSE 0 END) sinav,
  SUM(CASE WHEN s.DocumentsTypeId=8 THEN 0 ELSE 1 END) fis_perakende
FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
WHERE s.DocumentsTypeId IN (1,2,3,6,7,8)
  AND s.Date >= CONVERT(date,'29.08.2026',104) AND s.Date < CONVERT(date,'05.09.2026',104)
GROUP BY CONVERT(varchar(8),s.Date,112), s.StoresId, DATEPART(hour,s.Date);

/* [5] EŞLEŞTİRME/SENARYO Python'da yapıldı (saat-dilimi örtüşme aritmetiği):
   planlı kişi-saat[h] = Σ örtüşme(Kern penceresi − mola, [h,h+1))
   fiili kişi-saat[h]  = Σ örtüşme(segment, [h,h+1))
   Ölçülen hafta eğrisi (3 mağaza): fiş/kişi-saat 10:00=1,45 · 14:00=2,41 · 16:00=2,82
   · 17:00=6,72 · 20:00=4,22. Senaryo B (G3 molası 15:30-16:30 + G2 11:00-19:30):
   fiş/kişi-saat std 1,89→1,21, 17:00 7,56→3,46 — ek kadro/saat GEREKMEDEN.

   ⚠ TUZAK: DESIZ ('DEVAMSIZ') = devamsızlık DEĞİL. 217 kişi-günün 178'i SABIT
   (saat takibi olmayan) modelde; G1-G4 vardiyalı personelde SIFIR DESIZ.
   Devamsızlık oranı diye raporlanırsa (Özlüce %25,7) YANLIŞ olur. */

/* ============================================================================
   EK — HAM KART OKUTMALARI (TZeiBuf). 2026-09-05, ikinci tur.
   Neden: [3]'teki TTagZei segmentleri TÜRETİLMİŞ; mola boşluğu oradan "ölçüldü"
   sanıldı. Ham okutma bunu ÇÜRÜTTÜ — mola HİÇ kart okutulmuyor.
============================================================================ */

-- [6] Okuyucular (LesNr → mağaza)
SELECT * FROM OPENQUERY([PDKS], '
  SELECT l.Les_LesNr, l.Les_LesOrt, COUNT(b.IdNr) okutma
  FROM TLesTab l LEFT JOIN TZeiBuf b ON b.ZBu_LesNr=l.Les_LesNr
    AND b.ZBu_ErfDatum>=''20260829'' AND b.ZBu_ErfDatum<=''20260904''
  GROUP BY l.Les_LesNr, l.Les_LesOrt');
-- Ölçülen: 1=FSM · 2=OZLUCE · 4,5=Y.YOLU (İst.Yolu) · 3=HEYKEL · 10=ŞURA Heykel

-- [7] HAM OKUTMA (kişi × gün × saat). ZBu_ErfFunk TEK DEĞER (20) → giriş/çıkış
--     ayrımı YOK, sıraya göre ilk=giriş son=çıkış. ZBu_Storniert=1 iptal.
SELECT * FROM OPENQUERY([PDKS], '
  SELECT CONVERT(varchar(8),b.ZBu_ErfDatum,112) gun, LTRIM(RTRIM(p.Per_Grp2)) magaza,
         b.ZBu_PersNr pers, CONVERT(varchar(5),b.ZBu_ErfZeit,108) saat,
         b.ZBu_LesNr lesnr, b.ZBu_ErfFunk fonk, ISNULL(b.ZBu_Storniert,0) iptal,
         ISNULL(b.ZBu_Benutzer,''(okuyucu)'') kullanici
  FROM TZeiBuf b JOIN TPerTab p ON p.Per_PersNr=b.ZBu_PersNr
  WHERE b.ZBu_ErfDatum>=''20260829'' AND b.ZBu_ErfDatum<=''20260904''
    AND p.Per_Grp1 LIKE ''MA%LAR''
    AND LTRIM(RTRIM(p.Per_Grp2)) IN (''FSM'',''ÖZLÜCE'',''İST.YOLU'')');
/* Ölçüm: 1.876 okutma / 940 kişi-gün. 915 kişi-günde TAM 2 okutma, 25'inde 1,
   4 okutmalı gün SIFIR → MOLA HİÇ OKUTULMUYOR. Tüm okutmalar okuyucudan
   (ZBu_Benutzer hep NULL — elle girilmiş sahte okutma YOK). */

-- [8] EKSİK OKUTMA BAYRAĞI: TTagZei.TZe_InfKz='m' (InfKzKo='m' giriş eksik,
--     InfKzGe='m' çıkış eksik) → sistem günü TagMod planından TAMAMLIYOR.
SELECT * FROM OPENQUERY([PDKS], '
  SELECT CONVERT(varchar(8),z.TZe_Datum,112) gun, LTRIM(RTRIM(p.Per_Grp2)) magaza, z.TZe_PersNr pers,
         CONVERT(varchar(5),z.TZe_VonZeit,108) v, CONVERT(varchar(5),z.TZe_BisZeit,108) b,
         z.TZe_IstZeit ist, ISNULL(z.TZe_InfKzKo,''-'') ko, ISNULL(z.TZe_InfKzGe,''-'') ge, z.TZe_TagMod tm
  FROM TTagZei z JOIN TPerTab p ON p.Per_PersNr=z.TZe_PersNr
  WHERE z.TZe_Datum>=''20260829'' AND z.TZe_Datum<=''20260904''
    AND p.Per_Grp1 LIKE ''MA%LAR''
    AND LTRIM(RTRIM(p.Per_Grp2)) IN (''FSM'',''ÖZLÜCE'',''İST.YOLU'')
    AND z.TZe_InfKz=''m''');
/* Ölçüm: 42 kişi-gün / 92 segment. Kart okutması: 22'sinde SIFIR · 18'inde 1 · 2'sinde 2.
   Bu günlerde çalışma olarak yazılan 322 kişi-saat (haftalık 6.798'in %4,7'si);
   hiç okutma olmayanlar 177 kişi-saat. Örnek: Özlüce 31.08 pers 2483 — tek okutma
   13:30, kayıt 13:30-17:00 + 18:00-22:00 (tam G3). Çıkış plandan yazılmış. */

/* [9] KART-TABANLI KAPSAMA EĞRİSİ (mola düşülmemiş) — hafta, 3 mağaza:
   10:00 303 ks / fiş %1,9 · 14:00 911 / %9,5 · 17:00 883 / %11,6 · 20:00 519 / %9,3
   fiş/kişi-saat: 10:00=1,51 · 14:00=2,46 · 17:00=3,09 · 20:00=4,23 (akşama doğru artıyor).
   TTagZei kayıtlı çalışma 6.798 ks vs kart-içi süre 7.905 ks → fark 1.108 ks (%14)
   = model molası + yuvarlama. Yuvarlama asimetrik: giriş okutması kayıtlı başlangıçtan
   medyan 4 dk ÖNCE, çıkış okutması kayıtlı bitişten medyan 2 dk SONRA.
   Plana uyum (kart saatiyle, 896 kişi-gün): erken giriş %46,9 · geç giriş %20,2 ·
   erken çıkış %21,1 · 15 dk+ geç çıkış %29,2. */
