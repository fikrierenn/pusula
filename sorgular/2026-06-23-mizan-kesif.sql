/* =====================================================================================
   B-118 Mizan / likidite dashboard — keşif (DerinSISBkm.mhs)
   Soru: mizan bakiyesi nasıl doğru hesaplanır? fisBA işaret yönü? açılış dahil mi?
   Bulgu özeti:
     - fisBA=0 = ALACAK (gelir 600 sadece fisBA=0, pozitif), fisBA=1 = BORÇ. fisTutar İŞARETLİ (alacak+/borç−).
       → Bakiye = −SUM(fisTutar) = Borç − Alacak.  (plan-25 risk-tablosu TERSTİ; B-117 notu doğru.)
     - mhs.mhsMizan_vw HAZIR Borc/Alacak kolonu verir (fisBA'yı çözmeye gerek yok). Kolonlar:
       fisSirketID(tinyint) · fisTarih(smalldatetime) · hspKod(varchar) · fisHspID(int) · Alacak(decimal) · Borc(decimal)
     - fisSirketID = yıl − 2020 (1=2021 … 6=2026). Her şirket-yıl AYRI dönem.
     - 01.01.2026'da ~1,1 milyarlık AÇILIŞ/DEVİR fişi (26 satır, hsp 120) → sirket=6 açılışı İÇERİR
       → SUM(sirket=6) = gerçek mizan (açılış + yıl-içi), sadece akış değil. Bilanço hesabı doğru.
   Doğrulama (sirket=6, 2026):
     100 Kasa  : Borç 70.984.153,51 · Alacak 64.897.382,76 · Bakiye +6.086.770,75 (borç=varlık, doğru)
     120 Alıcı : Bakiye −148.050.743,96   320 Satıcı: −43.244.915,89   600 Satış: −370.585.958,53 (alacak/gelir)
   Tarih: 2026-06-23 · DMY · salt-okuma.
   ===================================================================================== */

-- 1) fisBA işaret yönü (gelir 600 = alacak kanıtı)
SELECT LEFT(h.hspKod,3) AS AnaHesap, ff.fisBA, COUNT(*) AS Adet, CAST(SUM(ff.fisTutar) AS decimal(18,2)) AS ToplamTutar
FROM mhs.mhsFis ff
JOIN mhs.mhsHsp h ON h.hspID = ff.fisHspID AND h.hspSirketID = ff.fisSirketID
WHERE ff.fisSirketID = 6 AND (h.hspKod LIKE '100%' OR h.hspKod LIKE '320%' OR h.hspKod LIKE '600%')
GROUP BY LEFT(h.hspKod,3), ff.fisBA
ORDER BY AnaHesap, ff.fisBA;

-- 2) mhsMizan_vw ile ana-hesap mizanı (Borc/Alacak hazır kolon)
SELECT LEFT(hspKod,3) AS AnaHesap,
       CAST(SUM(Borc) AS decimal(18,2)) AS Borc,
       CAST(SUM(Alacak) AS decimal(18,2)) AS Alacak,
       CAST(SUM(Borc) - SUM(Alacak) AS decimal(18,2)) AS Bakiye,
       COUNT(*) AS Satir
FROM mhs.mhsMizan_vw
WHERE fisSirketID = 6
GROUP BY LEFT(hspKod,3)
ORDER BY AnaHesap;

-- 3) açılış fişi kanıtı (01.01 büyük çift-taraflı devir)
SELECT TOP 10 CONVERT(varchar(10), fisTarih, 104) AS Tarih, COUNT(*) AS Satir,
       CAST(SUM(Borc) AS decimal(18,2)) AS Borc, CAST(SUM(Alacak) AS decimal(18,2)) AS Alacak
FROM mhs.mhsMizan_vw
WHERE fisSirketID = 6 AND hspKod LIKE '120%'
GROUP BY CONVERT(varchar(10), fisTarih, 104), fisTarih
ORDER BY fisTarih;

-- 4) dönem (şirket-yıl) eşlemesi
SELECT fisSirketID, MIN(YEAR(fisTarih)) AS MinYil, MAX(YEAR(fisTarih)) AS MaxYil, COUNT(*) AS Satir
FROM mhs.mhsMizan_vw GROUP BY fisSirketID ORDER BY fisSirketID;
