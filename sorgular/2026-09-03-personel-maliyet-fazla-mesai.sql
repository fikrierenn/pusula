/* ============================================================================
   PERSONEL MALİYETİ (brüt işveren) + FAZLA MESAİ / YASAL SINIR
   ----------------------------------------------------------------------------
   Soru   : (K-21) "Neden fazla eleman aldınız?" sorusunun MALİYET tarafı —
            personel maliyetinin ciroya oranı iki yılda ne oldu?
            (K-22) Kadro alınmasaydı aynı iş fazla mesaiyle çıkar mıydı,
            yasal sınır (4857 s.K. m.41, yıllık 270 saat) aşılır mıydı?
   Sunucu : zirve (192.168.40.66 · BKM_GENEL) + sqlserver (DerinSISBkm)
   Tarih  : 03.09.2026 · Kaynak formül: kullanıcının kendi bordro kontrol
            raporu (D:\Belgelerim\sql\PERSONEL BORDRO KONTROL v2+.sql)

   BULGU (Oca–Tem, üç POS mağazası):
     personel maliyeti 31,2M → 47,2M ₺ (+%51,5) · kişi-ay 781 → 856 (+%9,6)
     kişi-ay başı maliyet 39.893 → 55.160 ₺ (+%38,3 — ücret artışı)
     ciro (KDV hariç) 242,5M → 388,7M ₺ (+%60,3)
     MALİYET / CİRO: %12,85 → %12,15  (−0,70 puan — cironun personel yükü DÜŞTÜ)
     fazla mesai 6.328,5 → 7.628,5 saat · kişi başı yıllık 97 → 107 saat
     kadro 2025 seviyesinde kalsaydı: +14.625 saat FM gerekir → kişi başı
     yıllık 342 saat → 270 saatlik YASAL SINIR AŞILIR.

   ⚠ TUZAKLAR
   1) `Ucret` (vw_PersonelDepartman) NET ve CARİ orandır — geçmiş ay maliyeti
      için KULLANILMAZ. Tarihsel maliyet `vw_PuanBil` (bordro) içindedir.
   2) `vw_PuanBil.Personelno` FİRMA SONEKLİ ('1108-BKM') → üç tüzel kişiliği
      (BKM_GENEL · BURSA_KÜLTÜR_MERKEZİ · ASİYE_BİNGÖLBALI) birden kapsar.
      Ham `dbo.puanbil` int Personelno tutar ve yalnız BKM_GENEL'dir.
   3) PENCERE: bordro ayı KOŞMADAN alınırsa maliyet %80+ eksik görünür
      (03.09.2026'da Ağustos 2026 = 31 kişi, Temmuz = 256 kişi). Son TAM
      bordro ayı dinamik bulunmalı (aşağıdaki blok 1).
   4) Şube kırılımı personelin BUGÜNKÜ şubesine göredir (bordro ayındaki
      şubesi değil) — toplamlar doğru, şube dağılımı yer değiştirenlerde kayar.
   5) Ciro KDV HARİÇ alınır (maliyet de KDV'siz) ve Sınav DAHİL edilir —
      o satışı da aynı mağaza personeli yapar.
============================================================================ */

-- ---------------------------------------------------------------------------
-- BLOK 1 — SON TAM BORDRO AYI (pencere kararı). Kişi sayısı o yılın en yüksek
--          ayının %60'ının altına düşen ilk ay = bordro henüz koşmamış.
-- ---------------------------------------------------------------------------
USE BKM_GENEL;
SELECT b.Yil, b.Ayindex, COUNT(*) AS kisi
FROM dbo.vw_PuanBil b
INNER JOIN dbo.vw_PersonelDepartman p ON p.Personelno = b.Personelno
WHERE b.Yil IN (2025, 2026)
  AND p.Lokasyon LIKE 'MA%'          -- mağaza kapsamı (GM/merkez hariç)
GROUP BY b.Yil, b.Ayindex
ORDER BY b.Yil, b.Ayindex;

-- ---------------------------------------------------------------------------
-- BLOK 2 — ŞUBE × YIL: personel maliyeti (brüt işveren) + fazla mesai
--          maliyet = Bt (brüt toplam) + Isskk (işveren SGK) + Iisk (işveren işsizlik)
--          FM      = fm1+fm2+fm3 (saat) · fmtutar1..3 (tutar)
--          @SonAy  = blok 1'den gelen son tam bordro ayı (2026-09-03: 7)
-- ---------------------------------------------------------------------------
DECLARE @SonAy tinyint = 7;
DECLARE @FmAylikSinir float = 270.0 / 12.0;   -- yıllık 270 saatin aylık hızı

SELECT b.Yil, p.AltLokasyon AS Sube,
       COUNT(*)                                                            AS KisiAy,
       SUM(b.Bt)                                                           AS Brut,
       SUM(b.Isskk)                                                        AS IsverenSgk,
       SUM(b.Iisk)                                                         AS IsverenIssizlik,
       SUM(b.Bt + b.Isskk + b.Iisk)                                        AS PersonelMaliyet,
       SUM(b.Netu)                                                         AS NetOdenen,
       SUM(b.fm1 + b.fm2 + b.fm3)                                          AS FmSaat,
       SUM(b.fmtutar1 + b.fmtutar2 + b.fmtutar3)                           AS FmTutar,
       SUM(CASE WHEN (b.fm1 + b.fm2 + b.fm3) > 0 THEN 1 ELSE 0 END)        AS FmYapanKisiAy,
       SUM(CASE WHEN (b.fm1 + b.fm2 + b.fm3) > @FmAylikSinir THEN 1 ELSE 0 END)
                                                                           AS SinirHizindaKisiAy,
       MAX(b.fm1 + b.fm2 + b.fm3)                                          AS FmEnYuksekKisiAy
FROM dbo.vw_PuanBil b
INNER JOIN dbo.vw_PersonelDepartman p ON p.Personelno = b.Personelno
WHERE b.Yil IN (2025, 2026)
  AND b.Ayindex BETWEEN 1 AND @SonAy
  AND p.Lokasyon LIKE 'MA%'
GROUP BY b.Yil, p.AltLokasyon
ORDER BY p.AltLokasyon, b.Yil;

-- ---------------------------------------------------------------------------
-- BLOK 3 — CİRO (KDV HARİÇ) aylık, üç POS mağazası. Maliyet oranının paydası.
--          Sınav DAHİL (aynı personel yapıyor). DerinSISBkm'de çalıştırılır.
-- ---------------------------------------------------------------------------
/*
USE DerinSISBkm;
SELECT YEAR(bs.eTarihS) AS Yil, MONTH(bs.eTarihS) AS Ay,
       SUM(CAST(dt.ehTutar - dt.ehIndirim AS float)) AS NetKdvHaric,
       SUM(ABS(CAST(dt.ehAdet AS float)))            AS Adet
FROM dbo.irs bs WITH(NOLOCK)
INNER JOIN dbo.irsAyr dt WITH(NOLOCK) ON dt.ehID = bs.eID
WHERE bs.eTip = 100                       -- POS günlük özet belgesi
  AND bs.eMekan IN (1, 4477, 4478)        -- FSM · Özlüce · İst. Yolu
  AND YEAR(bs.eTarihS) IN (2025, 2026)
GROUP BY YEAR(bs.eTarihS), MONTH(bs.eTarihS)
ORDER BY Yil, Ay;
*/

-- ---------------------------------------------------------------------------
-- BLOK 4 — K-22 MODELİ (Python tarafında hesaplanır, burada belgelenir)
--   eksik_kisi_ay   = kisi_ay(2026) − kisi_ay(2025)                        = 75
--   ek_fm_saat      = eksik_kisi_ay × 195   (45 sa/hafta × 52 / 12)        = 14.625
--   varsayim_fm     = fiili_fm(2026) + ek_fm_saat                          = 22.253,5
--   kisi_basi_yil   = varsayim_fm / kisi_ay(2025) × 12                     = 341,9 saat
--   yasal_sinir     = 270 saat/yıl/kişi  (4857 s.K. m.41)                  → AŞILIR
--
--   VARSAYIM: işgücü ihtiyacı kişi sayısıyla doğru orantılıdır ve eksik kapasite
--   ancak fazla mesaiyle kapanır. Kısmi süreli/hafta sonu düzenlemeleri, verim
--   artışı ve mağaza içi kaydırmalar modelde YOKTUR — bu yüzden üst sınır
--   tahmini olarak okunmalıdır. Karşı-metrik: fiili FM 107 sa/yıl (sınırın
--   içinde) ama sınır hızında çalışan kişi-ay 32 → 95'e çıkmıştır.
-- ---------------------------------------------------------------------------

-- Emitter: scripts/verimlilik_excel.py (cek() 3g + 12 blokları) → JSON
--          → Excel «Maliyet» sayfası + sunum «Personel Maliyeti ve Ciro Oranı»
--          + «Kadro Alınmasaydı: Fazla Mesai Sınırı» slaytları.
-- Denetim: scripts/tutarlilik_kontrol.py (maliyet/FM aritmetiği + çıktı katmanı).
