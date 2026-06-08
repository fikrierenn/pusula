/*================================================================
  KAMPANYA EXCEL VERİ KAYNAKLARI — 4 sorgu, 4 ayrı sheet için
  ----------------------------------------------------------------
  Kullanım:
    1. Her sorguyu sırayla SSMS'te çalıştır (F5)
    2. Sonucu seç (Ctrl+A grid'de)
    3. Excel dosyasının ilgili sheet'ine yapıştır (A1 hücresinden başla)
    4. Header'lar dahil yapıştır

  Sheet eşleme:
    Q1 → "Urun_Master" sheet  (10K satır)
    Q2 → "Yillik" sheet        (10K satır)
    Q3 → "Stok" sheet          (10K satır)
    Q4 → "SonAlis" sheet       (10K satır — 4 kolon)

  Tarih parametreleri sorgularda sabit yazılı:
    Kampanya: 07-10 Mayıs 2026
    Yıllık baseline: 07.05.2025 - 07.05.2026

  Filtreler:
    Mağaza: FSM (1) + Özlüce (4477) + İst.Yolu (4478)
    Kategori3: Kitap, Çocuk Kitabı, Akademi, Hazırlık Kitapları
    Hareket: ehTip 4/100 satış, 5/101 iade, ehAltDepo=0
    stkID 583160 (Geri Dönüşüm) hariç
================================================================*/

USE DerinSISBkm;
SET NOCOUNT ON;

-- ================================================================
-- Q1 — Urun_Master sheet (TOP 10K ürün, kampanya tutarına göre sıralı)
-- Kolonlar: stkID, stkAd, Yayinevi, Yazar, Kategori, Reyon, KampNetAdet,
--           KampNetTutar, Ad_07, Ad_08, Ad_09, Ad_10, Ad_FSM, Ad_Ozluce, Ad_IstYolu
-- ================================================================
SELECT TOP 10000
    h.ehstkID                                  AS stkID,
    LEFT(u.stkAd, 80)                          AS stkAd,
    ISNULL(u.mrkAd, '(Yok)')                   AS Yayinevi,
    ISNULL(LEFT(u.Yazar, 40), '(Yok)')         AS Yazar,
    u.Kategori3                                AS Kategori,
    ISNULL(u.ReyonAd, '')                      AS Reyon,
    CAST(-SUM(CASE WHEN h.ehTip IN (4,100) THEN h.ehAdetN ELSE 0 END)
         -SUM(CASE WHEN h.ehTip IN (5,101) THEN h.ehAdetN ELSE 0 END) AS DECIMAL(18,0)) AS KampNetAdet,
    CAST(SUM(CASE WHEN h.ehTip IN (4,100) THEN h.ehTutarN ELSE 0 END)
         -SUM(CASE WHEN h.ehTip IN (5,101) THEN h.ehTutarN ELSE 0 END) AS DECIMAL(18,2)) AS KampNetTutar,
    CAST(-SUM(CASE WHEN CAST(h.ehTrhS AS DATE)=CONVERT(date,'07.05.2026',104) AND h.ehTip IN (4,100) THEN h.ehAdetN
                   WHEN CAST(h.ehTrhS AS DATE)=CONVERT(date,'07.05.2026',104) AND h.ehTip IN (5,101) THEN h.ehAdetN END) AS DECIMAL(18,0)) AS Ad_07,
    CAST(-SUM(CASE WHEN CAST(h.ehTrhS AS DATE)=CONVERT(date,'08.05.2026',104) AND h.ehTip IN (4,100) THEN h.ehAdetN
                   WHEN CAST(h.ehTrhS AS DATE)=CONVERT(date,'08.05.2026',104) AND h.ehTip IN (5,101) THEN h.ehAdetN END) AS DECIMAL(18,0)) AS Ad_08,
    CAST(-SUM(CASE WHEN CAST(h.ehTrhS AS DATE)=CONVERT(date,'09.05.2026',104) AND h.ehTip IN (4,100) THEN h.ehAdetN
                   WHEN CAST(h.ehTrhS AS DATE)=CONVERT(date,'09.05.2026',104) AND h.ehTip IN (5,101) THEN h.ehAdetN END) AS DECIMAL(18,0)) AS Ad_09,
    CAST(-SUM(CASE WHEN CAST(h.ehTrhS AS DATE)=CONVERT(date,'10.05.2026',104) AND h.ehTip IN (4,100) THEN h.ehAdetN
                   WHEN CAST(h.ehTrhS AS DATE)=CONVERT(date,'10.05.2026',104) AND h.ehTip IN (5,101) THEN h.ehAdetN END) AS DECIMAL(18,0)) AS Ad_10,
    CAST(-SUM(CASE WHEN h.ehMekan=1    AND h.ehTip IN (4,100) THEN h.ehAdetN
                   WHEN h.ehMekan=1    AND h.ehTip IN (5,101) THEN h.ehAdetN END) AS DECIMAL(18,0)) AS Ad_FSM,
    CAST(-SUM(CASE WHEN h.ehMekan=4477 AND h.ehTip IN (4,100) THEN h.ehAdetN
                   WHEN h.ehMekan=4477 AND h.ehTip IN (5,101) THEN h.ehAdetN END) AS DECIMAL(18,0)) AS Ad_Ozluce,
    CAST(-SUM(CASE WHEN h.ehMekan=4478 AND h.ehTip IN (4,100) THEN h.ehAdetN
                   WHEN h.ehMekan=4478 AND h.ehTip IN (5,101) THEN h.ehAdetN END) AS DECIMAL(18,0)) AS Ad_IstYolu
FROM dbo.irsHrk h WITH (NOLOCK)
JOIN bkm.urunbilgi u ON u.stkID = h.ehstkID
WHERE h.ehTrhS >= CONVERT(date,'07.05.2026',104) AND h.ehTrhS < CONVERT(date,'11.05.2026',104)
  AND h.ehMekan IN (1,4477,4478) AND h.ehTip IN (4,5,100,101) AND h.ehAltDepo=0
  AND u.Kategori3 IN (N'Kitap',N'Çocuk Kitabı',N'Akademi',N'Hazırlık Kitapları')
  AND h.ehstkID <> 583160
GROUP BY h.ehstkID, u.stkAd, u.mrkAd, u.Yazar, u.Kategori3, u.ReyonAd
ORDER BY SUM(CASE WHEN h.ehTip IN (4,100) THEN h.ehTutarN ELSE 0 END)
       - SUM(CASE WHEN h.ehTip IN (5,101) THEN h.ehTutarN ELSE 0 END) DESC;


-- ================================================================
-- Q2 — Yillik sheet (1 yıl baseline 07.05.2025 - 07.05.2026)
-- Kolonlar: stkID, YilNetAdet, YilNetTutar
-- ================================================================
SELECT TOP 10000
    h.ehstkID                                  AS stkID,
    CAST(-SUM(CASE WHEN h.ehTip IN (4,100) THEN h.ehAdetN ELSE 0 END)
         -SUM(CASE WHEN h.ehTip IN (5,101) THEN h.ehAdetN ELSE 0 END) AS DECIMAL(18,0)) AS YilNetAdet,
    CAST(SUM(CASE WHEN h.ehTip IN (4,100) THEN h.ehTutarN ELSE 0 END)
         -SUM(CASE WHEN h.ehTip IN (5,101) THEN h.ehTutarN ELSE 0 END) AS DECIMAL(18,2)) AS YilNetTutar
FROM dbo.irsHrk h WITH (NOLOCK)
JOIN bkm.urunbilgi u ON u.stkID = h.ehstkID
WHERE h.ehTrhS >= CONVERT(date,'07.05.2025',104) AND h.ehTrhS < CONVERT(date,'07.05.2026',104)
  AND h.ehMekan IN (1,4477,4478) AND h.ehTip IN (4,5,100,101) AND h.ehAltDepo=0
  AND u.Kategori3 IN (N'Kitap',N'Çocuk Kitabı',N'Akademi',N'Hazırlık Kitapları')
GROUP BY h.ehstkID
ORDER BY SUM(CASE WHEN h.ehTip IN (4,100) THEN h.ehTutarN ELSE 0 END)
       - SUM(CASE WHEN h.ehTip IN (5,101) THEN h.ehTutarN ELSE 0 END) DESC;


-- ================================================================
-- Q3 — Stok sheet (güncel stok, mağaza pivot)
-- Kolonlar: stkID, Stok_FSM, Stok_Ozluce, Stok_IstYolu, Stok_MerkezDepo, Stok_Toplam
-- ================================================================
SELECT TOP 10000
    s.ehstkID                                  AS stkID,
    CAST(SUM(CASE WHEN s.ehMekan = 1    THEN s.stok ELSE 0 END) AS INT) AS Stok_FSM,
    CAST(SUM(CASE WHEN s.ehMekan = 4477 THEN s.stok ELSE 0 END) AS INT) AS Stok_Ozluce,
    CAST(SUM(CASE WHEN s.ehMekan = 4478 THEN s.stok ELSE 0 END) AS INT) AS Stok_IstYolu,
    CAST(SUM(CASE WHEN s.ehMekan = 12   THEN s.stok ELSE 0 END) AS INT) AS Stok_MerkezDepo,
    CAST(SUM(s.stok) AS INT)                                            AS Stok_Toplam
FROM dbo.stokSon_vw s WITH (NOLOCK)
JOIN bkm.urunbilgi u ON u.stkID = s.ehstkID
WHERE s.ehMekan IN (1, 4477, 4478, 12)
  AND u.Kategori3 IN (N'Kitap',N'Çocuk Kitabı',N'Akademi',N'Hazırlık Kitapları')
GROUP BY s.ehstkID
HAVING SUM(s.stok) > 0
ORDER BY SUM(s.stok) DESC;


-- ================================================================
-- Q4 — SonAlis sheet (en son alış faturası — tarih + adet)
-- Kolonlar: stkID, SonAlisTarih, SonAlisAdet, GunSayisiAlisBeri
-- SonAlisAdet = son alış tarihindeki TOPLAM giriş adedi (aynı gün
--   birden fazla satır varsa toplanır)
-- GunSayisiAlisBeri = bugünden son alışa kadar geçen gün
-- ================================================================
;WITH AlisHrk AS (
    SELECT fa.ehStkID, f.eTarih, fa.ehAdetN
    FROM dbo.fatAyr fa WITH (NOLOCK)
    INNER JOIN dbo.fat f WITH (NOLOCK) ON f.eID = fa.ehID
    INNER JOIN bkm.urunbilgi u ON u.stkID = fa.ehStkID
    WHERE f.eGC = 1 AND f.onay = 1 AND f.eDurum = 0
      AND f.eTarih >= CONVERT(date,'01.01.2022',104)
      AND fa.ehAdetN < 0
      AND u.Kategori3 IN (N'Kitap',N'Çocuk Kitabı',N'Akademi',N'Hazırlık Kitapları')
),
SonTarih AS (
    SELECT ehStkID, MAX(eTarih) AS SonAlisTarih
    FROM AlisHrk
    GROUP BY ehStkID
)
SELECT TOP 10000
    sa.ehStkID                                AS stkID,
    sa.SonAlisTarih,
    CAST(-SUM(a.ehAdetN) AS DECIMAL(18,0))    AS SonAlisAdet,
    DATEDIFF(DAY, sa.SonAlisTarih, GETDATE()) AS GunSayisiAlisBeri
FROM SonTarih sa
INNER JOIN AlisHrk a ON a.ehStkID = sa.ehStkID AND a.eTarih = sa.SonAlisTarih
GROUP BY sa.ehStkID, sa.SonAlisTarih
ORDER BY sa.SonAlisTarih DESC, SonAlisAdet DESC;
