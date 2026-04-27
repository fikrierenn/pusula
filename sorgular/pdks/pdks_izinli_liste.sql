/* =======================================================================
   PDKS + Vardiya · Bugün Normalde İzinli Olanlar
   -----------------------------------------------------------------------
   vrd.VardiyaZaman.Izin = 1 olan kodlara atanmış kişiler.
   İzin türleri: 51=HFT.İZİN, 52=ÜCRETSİZ, 53=ÜCRETLİ, 55=RESMİ TATİL,
                 58=YILLIK, 63=RAPOR, 73=MESAİ İZNİ
   NOT: 62 GÜVENLİK → Izin=0 (gece vardiyası, izin değil!)
        100 ÖZEL DURUM → Izin=0, saat 00:00-00:00 (belirsiz slot)
   ======================================================================= */

SELECT TOP 200
  s.SubeAd AS Sube,
  vd.Bolum,
  vd.Personel,
  vd.SicilNo AS TC,
  vd.Carsamba AS Kod,           -- ← gün kolonu (Pazartesi..Pazar)
  vz.Aciklama AS IzinTuru
FROM vrd.Vardiya v
INNER JOIN vrd.VardiyaDetay vd ON vd.VardiyaNo = v.VardiyaNo
INNER JOIN vrd.VardiyaZaman  vz ON vz.VardiyaId = vd.Carsamba
INNER JOIN vrd.SubeListe     s  ON s.SubeNo   = v.SubeNo
WHERE v.Tarih = CONVERT(datetime, '13.04.2026', 104)   -- ← haftanın Pazartesi'si
  AND vz.Izin = 1
ORDER BY vz.Aciklama, s.SubeAd, vd.Personel;

/* 15.04.2026 Çarşamba sonucu: 38 kişi
   - HFT.İZİN (51): 35
   - ÜCRETSİZ İZİN (52): 3
   - Diğer (53, 55, 58, 63, 73): 0
*/
