/* =====================================================================================
   B-118 Mizan — KESİN MİZAN (kapanış fişi hariç) + Excel doğrulama + 590 fark izi
   DB: DerinSISBkm.mhs · sirketID = yıl − 2020 (5=2025, 6=2026) · salt-okuma
   Soru: kapanmış yıl mizanı neden hepsi 0? Gerçek mizan nasıl üretilir? 590 farkı nedir?
   Bulgu:
     - mhsMizan_vw yıl-sonu KAPANIŞ fişlerini içerir → kapanmış yıl her hesap Borç=Alacak → Bakiye 0.
     - Gerçek/kesin mizan = "Kapanış" bilanço fişi HARİÇ (VİRMAN'lar DAHİL: 6xx→690→692→590 kapanır,
       bilanço hesapları bakiyeli, 590 dönem kârı görünür).
     - "Kapanış" fişi: her kapanmış yılda TEK, HER ZAMAN max yevmiyeNo (sistem-üretimi ad, fisTip ayırmıyor=2).
       Açılış = yevmiyeNo 1. fisTip yalnız 0/2 → açılış/kapanış'ı AYIRMAZ → ad+pozisyon ile yakalanır.
     - Excel (28.04.2026 snapshot) ile karşılaştırma: 100/102/120/320/600 KURUŞU KURUŞUNA tutar.
       590 Dönem Kârı 5.870.000 fark = 692/590 VİRMAN fişi 30.04.2026'da revize (Excel'den sonra) → veri, formül değil.
   ===================================================================================== */

-- 1) Kesin mizan (ana hesap, Kapanış fişi hariç) — gerçek bakiye
SELECT LEFT(h.hspKod,3) AS Hesap,
       CAST(SUM(CASE WHEN ff.fisBA=1 THEN -ff.fisTutar ELSE 0 END) AS decimal(18,2)) AS Borc,
       CAST(SUM(CASE WHEN ff.fisBA=0 THEN  ff.fisTutar ELSE 0 END) AS decimal(18,2)) AS Alacak,
       CAST(SUM(CASE WHEN ff.fisBA=1 THEN -ff.fisTutar ELSE 0 END)
          - SUM(CASE WHEN ff.fisBA=0 THEN  ff.fisTutar ELSE 0 END) AS decimal(18,2)) AS Bakiye
FROM mhs.mhsFis ff
JOIN mhs.mhsHsp h ON h.hspID = ff.fisHspID AND h.hspSirketID = ff.fisSirketID
WHERE ff.fisSirketID = 5
  AND NOT EXISTS (SELECT 1 FROM mhs.mhsFisBaslik k
                  WHERE k.fisbID = ff.fisID AND k.fisbSirketID = ff.fisSirketID AND k.fisAd = N'Kapanış')
GROUP BY LEFT(h.hspKod,3)
ORDER BY LEFT(h.hspKod,3);

-- 2) Kapanış fişi = max yevmiye, her kapanmış yılda tek (fisTip ayırt etmiyor)
SELECT b.fisbSirketID AS Sirket,
       SUM(CASE WHEN b.fisAd=N'Kapanış' THEN 1 ELSE 0 END) AS KapanisAdet,
       MAX(b.yevmiyeNo) AS MaxYevmiye,
       MAX(CASE WHEN b.fisAd=N'Kapanış' THEN b.yevmiyeNo END) AS KapanisYevmiye
FROM mhs.mhsFisBaslik b GROUP BY b.fisbSirketID ORDER BY b.fisbSirketID;

-- 3) 590 dönem kârı fark izi — tüm 590 fişleri + revizyon tarihi (Excel 28.04 snapshot vs DB)
SELECT ff.fisID, b.fisAd, b.yevmiyeNo, CONVERT(varchar(10),b.fisTarih,104) AS Tarih,
       CONVERT(varchar(16),b.kTarih,120) AS SonGuncelleme, ff.fisBA, CAST(ff.fisTutar AS decimal(18,2)) AS Tutar
FROM mhs.mhsFis ff
JOIN mhs.mhsHsp h ON h.hspID=ff.fisHspID AND h.hspSirketID=ff.fisSirketID
JOIN mhs.mhsFisBaslik b ON b.fisbID=ff.fisID AND b.fisbSirketID=ff.fisSirketID
WHERE ff.fisSirketID=5 AND LEFT(h.hspKod,3)='590';
