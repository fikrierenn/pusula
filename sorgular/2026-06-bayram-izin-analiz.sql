/* ============================================================
   BKM — Mağaza ciro + Bayram/İzin + Kategori3 satış analizi
   Oturum: 2026-06 | DB: DerinSISBkm (192.168.40.201)
   Runtime notları:
   - Tarih: 'YYYYMMDD' compact ISO (locale-safe). 'yyyy-MM-dd' tireli KULLANMA.
   - sql_query auto-wrap TOP N ile sarıyor -> sorgu içinde ORDER BY ve WITH(CTE) HATA verir.
     Çözüm: ORDER BY koyma (client'ta sırala); CTE yerine derived table kullan.
   - Mağazalar: FSM=1, ÖZLÜCE=4477, İST.YOLU=4478 (mekan_vw, mekanTip=2 = satış).
   - Net ciro (özet): posOzetMagazaGun.satis - iade.
   - Kategori satış (line): irsHrk.ehTip=100 = perakende satış (ehAdetN negatif=stok çıkışı).
   ============================================================ */


/* ------------------------------------------------------------
   1) MAĞAZA BAZLI AYLIK CİRO (yaz / herhangi dönem)
   Kaynak: posOzetMagazaGun (günlük mağaza özeti) + posMagaza
   Net = satis - iade (KDV dahil kasa cirosu)
   ------------------------------------------------------------ */
SELECT m.mekanAd,
 SUM(CASE WHEN g.satisTarih>='20250601' AND g.satisTarih<'20250701' THEN g.satis-g.iade ELSE 0 END) AS Haziran,
 SUM(CASE WHEN g.satisTarih>='20250701' AND g.satisTarih<'20250801' THEN g.satis-g.iade ELSE 0 END) AS Temmuz,
 SUM(CASE WHEN g.satisTarih>='20250801' AND g.satisTarih<'20250901' THEN g.satis-g.iade ELSE 0 END) AS Agustos,
 SUM(g.satis-g.iade) AS ToplamYaz
FROM dbo.posOzetMagazaGun g
JOIN dbo.posMagaza m ON m.mekanID = g.magazaID
WHERE g.satisTarih>='20250601' AND g.satisTarih<'20250901'
GROUP BY m.mekanAd;   -- ORDER BY YOK (auto-wrap)


/* ------------------------------------------------------------
   2) TÜM YIL AYLIK CİRO (mağaza bazlı) — mevsimsellik
   ------------------------------------------------------------ */
SELECT YEAR(g.satisTarih) AS Yil, MONTH(g.satisTarih) AS Ay,
 SUM(CASE WHEN m.mekanAd LIKE 'ÖZLÜCE%'   THEN g.satis-g.iade ELSE 0 END) AS OZLUCE,
 SUM(CASE WHEN m.mekanAd LIKE 'FSM%'      THEN g.satis-g.iade ELSE 0 END) AS FSM,
 SUM(CASE WHEN m.mekanAd LIKE 'İST YOLU%' THEN g.satis-g.iade ELSE 0 END) AS IST_YOLU,
 SUM(g.satis-g.iade) AS Toplam
FROM dbo.posOzetMagazaGun g
JOIN dbo.posMagaza m ON m.mekanID=g.magazaID
WHERE g.satisTarih>='20240101' AND g.satisTarih<'20260101'
GROUP BY YEAR(g.satisTarih), MONTH(g.satisTarih);


/* ------------------------------------------------------------
   3) GÜNLÜK CİRO (mağaza sütun) — bir ay, ör. Mayıs 2025
   Bayram günlerini (1 ve 19 Mayıs) normal günle kıyaslamak için
   ------------------------------------------------------------ */
SELECT g.satisTarih, DATENAME(weekday, g.satisTarih) AS Gun,
 SUM(CASE WHEN m.mekanAd LIKE 'ÖZLÜCE%'   THEN g.satis-g.iade ELSE 0 END) AS OZLUCE,
 SUM(CASE WHEN m.mekanAd LIKE 'FSM%'      THEN g.satis-g.iade ELSE 0 END) AS FSM,
 SUM(CASE WHEN m.mekanAd LIKE 'İST YOLU%' THEN g.satis-g.iade ELSE 0 END) AS IST_YOLU,
 SUM(g.satis-g.iade) AS Toplam, SUM(g.satisAdet) AS AdetToplam
FROM dbo.posOzetMagazaGun g
JOIN dbo.posMagaza m ON m.mekanID=g.magazaID
WHERE g.satisTarih>='20250501' AND g.satisTarih<'20250601'
GROUP BY g.satisTarih, DATENAME(weekday, g.satisTarih);


/* ------------------------------------------------------------
   4) ehTip RECONCILE (hangi hareket tipi perakende satış?)
   ehTip=100 -> perakende satış (tutar +, adet -). ~mağaza özetinin %95'i
   ------------------------------------------------------------ */
SELECT ehMekan, ehTip, COUNT(*) AS satir, SUM(ehAdetN) AS adet, SUM(ehTutarN) AS tutar
FROM dbo.irsHrk
WHERE ehTrhS>='20250501' AND ehTrhS<'20250502'
GROUP BY ehMekan, ehTip;


/* ------------------------------------------------------------
   5) KATEGORİ3 BAZLI SATIŞ (adet + ciro) — bayram vs normal
   irsHrk (ehTip=100) -> ehstkID -> bkm.UrunBilgi.Kategori3
   Sütunlar: 1 May | 19 May | Kurban/gün ort | Normal/gün ort (komple)
   Pencere: Mayıs+Haziran 2025 (her ikisi de dip ay).
   Bayram günleri: 1 May, 19 May (laik) + Kurban 6-9 Haz 2025
     (6 Haz 1. gün mağaza KAPALI -> satır yok -> COUNT DISTINCT otomatik dışlar).
   Normal ort = pencere içindeki DİĞER tüm günler (hafta sonu DAHİL, komple).
   Ortalamalar COUNT(DISTINCT tarih) ile bölünür -> kapalı/eksik gün bozmaz.
   NOT: CTE yerine derived table (auto-wrap CTE'yi sarmalayamıyor); ORDER BY yok.
   ------------------------------------------------------------ */
SELECT ISNULL(ub.k3,'(eşleşmeyen)') AS Kategori3,
 SUM(CASE WHEN CAST(h.ehTrhS AS date)='20250501' THEN h.ehTutarN ELSE 0 END)  AS Ciro_1May,
 SUM(CASE WHEN CAST(h.ehTrhS AS date)='20250501' THEN -h.ehAdetN ELSE 0 END)  AS Adet_1May,
 SUM(CASE WHEN CAST(h.ehTrhS AS date)='20250519' THEN h.ehTutarN ELSE 0 END)  AS Ciro_19May,
 SUM(CASE WHEN CAST(h.ehTrhS AS date)='20250519' THEN -h.ehAdetN ELSE 0 END)  AS Adet_19May,
 SUM(CASE WHEN CAST(h.ehTrhS AS date) IN ('20250606','20250607','20250608','20250609') THEN h.ehTutarN ELSE 0 END)
   / NULLIF(COUNT(DISTINCT CASE WHEN CAST(h.ehTrhS AS date) IN ('20250606','20250607','20250608','20250609') THEN CAST(h.ehTrhS AS date) END),0) AS Ciro_KurbanOrt,
 SUM(CASE WHEN CAST(h.ehTrhS AS date) IN ('20250606','20250607','20250608','20250609') THEN -h.ehAdetN ELSE 0 END)
   / NULLIF(COUNT(DISTINCT CASE WHEN CAST(h.ehTrhS AS date) IN ('20250606','20250607','20250608','20250609') THEN CAST(h.ehTrhS AS date) END),0) AS Adet_KurbanOrt,
 SUM(CASE WHEN CAST(h.ehTrhS AS date) NOT IN ('20250501','20250519','20250606','20250607','20250608','20250609') THEN h.ehTutarN ELSE 0 END)
   / NULLIF(COUNT(DISTINCT CASE WHEN CAST(h.ehTrhS AS date) NOT IN ('20250501','20250519','20250606','20250607','20250608','20250609') THEN CAST(h.ehTrhS AS date) END),0) AS Ciro_NormalOrt,
 SUM(CASE WHEN CAST(h.ehTrhS AS date) NOT IN ('20250501','20250519','20250606','20250607','20250608','20250609') THEN -h.ehAdetN ELSE 0 END)
   / NULLIF(COUNT(DISTINCT CASE WHEN CAST(h.ehTrhS AS date) NOT IN ('20250501','20250519','20250606','20250607','20250608','20250609') THEN CAST(h.ehTrhS AS date) END),0) AS Adet_NormalOrt
FROM dbo.irsHrk h
JOIN (SELECT stkID, MIN(Kategori3) AS k3 FROM bkm.UrunBilgi GROUP BY stkID) ub
     ON ub.stkID = h.ehstkID
WHERE h.ehMekan IN (1,4477,4478) AND h.ehTip=100
  AND h.ehTrhS>='20250501' AND h.ehTrhS<'20250701'
GROUP BY ub.k3;


/* ------------------------------------------------------------
   Yardımcı: kategori listesi ve mekanlar
   ------------------------------------------------------------ */
-- Kategori3 listesi + ürün sayısı
SELECT Kategori3, COUNT(*) AS UrunSayisi FROM bkm.UrunBilgi GROUP BY Kategori3;

-- Satış mağazaları (mekanTip=2)
SELECT mekanID, mekanAd, mekanTip FROM dbo.mekan_vw;   -- veya dbo.posMagaza
