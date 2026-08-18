/*
  Soru: BKM'de birden fazla TÜZEL KİŞİ var mı (web'de "BKM KİTAP Point İnternet Tek. ve Lojistik A.Ş."
        ayrı şirket olarak görünüyor) — analizlerde şirket sınırı sessizce karışıyor olabilir mi?
  DB: DerinSISBkm (192.168.40.201). Tetik: 2026-08-17 kamuya-açık kayıt taraması.

  BULGU (3 parça):
   1) mhs.mhsSirket = 6 satır ama HEPSİ aynı tüzel kişi ("BKM Kitap Kırtasiye");
      ayrım sirketDonem = 2021..2026 → **sirketID = MALİ DÖNEM, ŞİRKET DEĞİL**.
      fisSirketID/fisbSirketID/hspSirketID kolonları da dönem taşır. TEK ŞİRKET → konsolidasyon riski YOK.
   2) "Point" ayrı tüzel kişi olarak DEĞİL, **TEDARİKÇİ/CARİ olarak** kayıtlı:
      frmID 9525 "ODAK KİTAP-POİNT İNTERNET TEKNOLOJİLERİ" (frmKod 320.10.P060, frmTip=0)
      + frmID 22100 "POİNT KİTAP DAĞITIM TİC. A.Ş." (320.10.P006).
      320.10 = satıcılar hesabı → ilişkili-taraf ise transfer-fiyatlama/mutabakat konusu (denetim sorusu).
   3) mekan_vw = 11 mekan; Heykel yalnız "HEYKEL TRANSFER DEPOSU" (mekanTip=3 DEPO, satış mekanı DEĞİL),
      Esenyurt HİÇ YOK. Yani bu DerinSIS örneği Bursa 3 mağaza + depolar + Eticaret(4479) kapsıyor.

  YAN BULGU (GL forensic için kritik): 2025'te yevmiye granülaritesi kırıldı — fiş 2,69M→123K
  (−%95) ama TL hacmi arttı → detay yerine TOPLU posting. Yıl-kırılımı olmadan Benford/anomali kıyası geçersiz.
*/

-- 1) Şirket mi dönem mi? (sirketAd tekrar ediyorsa = dönem)
SELECT sirketID, sirketAd, sirketDonem, sirketOnce, sirketIlkFisID, sirketSonFisID
FROM mhs.mhsSirket WITH(NOLOCK)
ORDER BY sirketID;

-- 2) fisSirketID gerçekten yıl mı? (tarih aralıkları örtüşmüyorsa dönemdir)
SELECT f.fisSirketID,
       COUNT(DISTINCT f.fisID) AS fis_sayi,
       COUNT(*)                AS satir,
       CONVERT(varchar, MIN(f.fisTarih), 104) AS ilk,
       CONVERT(varchar, MAX(f.fisTarih), 104) AS son,
       SUM(CASE WHEN f.fisBA = 1 THEN f.fisTutar ELSE 0 END) AS ba1_tarafi
FROM mhs.mhsFis f WITH(NOLOCK)
GROUP BY f.fisSirketID
ORDER BY f.fisSirketID;

-- 3) "Point / İnternet Teknolojileri" cari araması (ayrı tüzel kişi mi, tedarikçi mi?)
SELECT frmID, frmKod, frmAd, frmTip, frmSirketTip
FROM dbo.frm WITH(NOLOCK)
WHERE frmAd LIKE '%POINT%' OR frmAd LIKE '%POİNT%'
   OR frmAd LIKE '%İNTERNET TEK%' OR frmAd LIKE '%INTERNET TEK%'
ORDER BY frmAd;

-- 4) Mekan envanteri (Heykel satış mekanı mı, depo mu? Esenyurt var mı?)
SELECT mekanID, mekanAd, mekanTip
FROM dbo.mekan_vw WITH(NOLOCK)
ORDER BY mekanID;

-- 5) ODAK-POINT ilişkili-taraf hacmi — alış tarafında ne kadar dönüyor?
--    (irs.eFirma = frm.frmID köprüsü; ehTip 0/10 = alış girişi)
SELECT YEAR(h.ehTrhS) AS yil,
       COUNT(DISTINCT i.eNo) AS evrak,
       SUM(h.ehAdetN)  AS adet,
       SUM(h.ehTutarN) AS tutar_net
FROM dbo.irsHrk h WITH(NOLOCK)
JOIN dbo.irs i WITH(NOLOCK) ON i.eID = h.ehID
WHERE i.eFirma IN (9525, 22100)          -- ODAK KİTAP-POİNT · POİNT KİTAP DAĞITIM
  AND h.ehTip IN (0, 10) AND h.ehAdetN > 0
GROUP BY YEAR(h.ehTrhS)
ORDER BY 1;

/* ---------------------------------------------------------------------------
   6) TEDARİKÇİ KONSANTRASYONU — ODAK-POINT tek başına alımın ~%40'ı
   2025: ODAK-POINT 307.703.436 ₺ vs diğer 176 firma 468.127.295 ₺ → %39,7
   2026 (17.08): ODAK-POINT 224.694.084 ₺ vs diğer 151 firma 339.619.274 ₺ → %39,8
   → Tek cari, girişin ~%40'ı. İlişkili taraf ise: transfer-fiyatlama + mutabakat +
     bağımlılık riski (denetim sorusu). Değilse: tedarikçi konsantrasyon riski.
--------------------------------------------------------------------------- */
SELECT YEAR(h.ehTrhS) AS yil,
       CASE WHEN i.eFirma = 9525 THEN 'ODAK-POINT' ELSE 'DIGER' END AS kaynak,
       COUNT(DISTINCT i.eFirma) AS firma_sayi,
       SUM(h.ehTutarN)          AS tutar_net
FROM dbo.irsHrk h WITH(NOLOCK)
JOIN dbo.irs i WITH(NOLOCK) ON i.eID = h.ehID
WHERE h.ehTip IN (0,10) AND h.ehAdetN > 0
  AND h.ehTrhS >= '20250101'
GROUP BY YEAR(h.ehTrhS), CASE WHEN i.eFirma = 9525 THEN 'ODAK-POINT' ELSE 'DIGER' END
ORDER BY 1 DESC, 2;
