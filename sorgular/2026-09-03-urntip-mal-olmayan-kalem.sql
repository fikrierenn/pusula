/* K-25 — urnTip=2 nedir, `WHERE urnTip=0` dışlaması kasıtlı mı?
   DB: DerinSISBkm (192.168.40.201)
   Soru: başka bir oturum `dbo.urn.urnTip`'in üçüncü değer aldığını buldu (2, 52 kayıt) ve
         "demirbaş/araç satışı" diye etiketledi. Ölü stok/kategori raporları `urnTip=0`
         filtresi kullanıyor → bu 52 kayıt sessizce dışarıda kalıyor. Kasıtlı mı, kaza mı?
   BULGU: dışlama KASITLI ve DOĞRU. urnTip 1 ve 2 aynı sınıf — ikisi de MAL DEĞİL:
          irsHrk stok hareketi 0, bkm.UrunBilgi master'ında 0 kayıt, yalnız fatAyr fatura
          kaleminde var (1 → 97.165 · 2 → 5.888 kalem). Sessiz veri kaybı yok.
   DÜZELTME: etiket yanlıştı. 52 kaydın 38'i `H-0xx` fatura hizmet/gelir kalemi (KDV oranına
          göre varyantlı), 14'ü `252.10.xxx` gayrimenkul/arsa kartı (252=Binalar hesabı).
          Araç satışı yalnız 2 kayıt (H-031 Araç Satışı %18, H-040 BMW). Tek örnekten
          türetilen etiket sınıfı yanlış tanımlıyordu.
   Koruma: sema/degismezler.json → mal-olmayan-kalem-stok-hareketsiz (bu SQL'in 4. bloğu). */

-- 1) urnTip dağılımı (üç değer)
SELECT u.urnTip, COUNT(*) AS kayit
FROM dbo.urn u
GROUP BY u.urnTip
ORDER BY u.urnTip;

-- 2) urnTip=2'nin TAM listesi — sınıfı ad/kod deseninden okunur
--    (H-0xx = fatura hizmet/gelir kalemi · 252.10.xxx = gayrimenkul)
SELECT u.stkKod, u.stkAd, u.fiyatS, u.urnKtgr2ID
FROM dbo.urn u
WHERE u.urnTip = 2
ORDER BY u.stkKod;

-- 3) Rapor master'ında var mı (bkm.UrunBilgi = kategori/bulunurluk/ölü stok evreni)
SELECT u.urnTip,
       COUNT(*)                                             AS urun,
       SUM(CASE WHEN ub.StkID IS NULL THEN 1 ELSE 0 END)     AS masterda_yok
FROM dbo.urn u
LEFT JOIN bkm.UrunBilgi ub ON ub.StkID = u.stkID
WHERE u.urnTip IN (1, 2)
GROUP BY u.urnTip;

-- 4) STOK HAREKETİ var mı — dışlamanın doğruluğunun tek şartı (DEĞİŞMEZ)
--    Sıfırdan farklı çıkarsa: gerçek mal `urnTip=0` filtresiyle sessizce düşüyor demektir.
SELECT COUNT(*) AS irsHrk_hareket
FROM dbo.irsHrk h
WHERE h.ehstkID IN (SELECT stkID FROM dbo.urn WHERE urnTip IN (1, 2));

-- 5) FATURA kaleminde var mı — bu kalemlerin gerçek yaşadığı yer
--    (fatAyr'de tip kolonu yok; kalem sayısı yeter. GL/mizan analizinde MEŞRU gelir/gider.)
SELECT u.urnTip, COUNT(*) AS fatura_kalemi
FROM dbo.fatAyr f
JOIN dbo.urn u ON u.stkID = f.ehStkID
WHERE u.urnTip IN (1, 2)
GROUP BY u.urnTip;

-- 6) Stok bakiyesi (net adet) taşıyan urnTip=2 ürünü — beklenen 0
SELECT COUNT(*) AS bakiyeli_urun
FROM (
    SELECT h.ehstkID, SUM(h.ehAdetN) AS bakiye
    FROM dbo.irsHrk h
    JOIN dbo.urn u ON u.stkID = h.ehstkID
    WHERE u.urnTip = 2
    GROUP BY h.ehstkID
    HAVING SUM(h.ehAdetN) <> 0
) t;
