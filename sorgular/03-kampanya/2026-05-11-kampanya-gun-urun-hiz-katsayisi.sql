-- =====================================================================
-- KAMPANYA HIZ KATSAYI: Gün × Segment + Top Vurucu Ürünler
-- ----------------------------------------------------------------
-- Amaç: %50 kitap kampanyası (07-10 Mayıs 2026) etkisinin
--       gün ve ürün bazında detaylı analizi.
--
-- Metrik: Katsayı = (KampanyaGünlükAdet) / (YıllıkGünlükAdet)
--         Yıllık baseline: 07.05.2025 - 07.05.2026 (1 yıl)
--
-- Mağazalar: FSM (1), Özlüce (4477), İst.Yolu (4478)
-- Kategori: Kitap, Çocuk Kitabı, Akademi, Hazırlık Kitapları
-- ehTip: 4/100 satış, 5/101 iade, ehAltDepo=0
-- =====================================================================

DECLARE @KampBas DATE = CONVERT(date,'07.05.2026',104);
DECLARE @KampBit DATE = CONVERT(date,'11.05.2026',104);  -- DAHİL DEĞİL
DECLARE @YilBas  DATE = CONVERT(date,'07.05.2025',104);
DECLARE @YilBit  DATE = CONVERT(date,'07.05.2026',104);

-- =====================================================================
-- ÇIKTI 1: GÜN × SEGMENT MATRİSİ
-- =====================================================================
;WITH KampGunluk AS (
    SELECT
        CAST(h.ehTrhS AS DATE) AS Gun,
        h.ehstkID,
        -SUM(CASE WHEN h.ehTip IN (4,100) THEN h.ehAdetN ELSE 0 END)
        -SUM(CASE WHEN h.ehTip IN (5,101) THEN h.ehAdetN ELSE 0 END) AS GunAdet,
         SUM(CASE WHEN h.ehTip IN (4,100) THEN h.ehTutarN ELSE 0 END)
        -SUM(CASE WHEN h.ehTip IN (5,101) THEN h.ehTutarN ELSE 0 END) AS GunTutar
    FROM dbo.irsHrk h WITH (NOLOCK)
    JOIN bkm.urunbilgi u ON u.stkID = h.ehstkID
    WHERE h.ehTrhS >= @KampBas AND h.ehTrhS < @KampBit
      AND h.ehMekan IN (1,4477,4478) AND h.ehTip IN (4,5,100,101) AND h.ehAltDepo=0
      AND u.Kategori3 IN (N'Kitap',N'Çocuk Kitabı',N'Akademi',N'Hazırlık Kitapları')
      AND h.ehstkID <> 583160
    GROUP BY CAST(h.ehTrhS AS DATE), h.ehstkID
),
YilSatis AS (
    SELECT h.ehstkID,
        -SUM(CASE WHEN h.ehTip IN (4,100) THEN h.ehAdetN ELSE 0 END)
        -SUM(CASE WHEN h.ehTip IN (5,101) THEN h.ehAdetN ELSE 0 END) AS YilAdet
    FROM dbo.irsHrk h WITH (NOLOCK)
    WHERE h.ehTrhS >= @YilBas AND h.ehTrhS < @YilBit
      AND h.ehMekan IN (1,4477,4478) AND h.ehTip IN (4,5,100,101) AND h.ehAltDepo=0
    GROUP BY h.ehstkID
),
KampSegmentli AS (
    SELECT
        k.Gun, k.ehstkID, k.GunAdet, k.GunTutar,
        ISNULL(y.YilAdet, 0) AS YilAdet,
        CASE WHEN ISNULL(y.YilAdet,0) = 0 THEN NULL
             ELSE k.GunAdet / (y.YilAdet / 365.0) END AS Katsayi,
        CASE
            WHEN ISNULL(y.YilAdet,0) = 0                                 THEN '1_Ölü stok dirildi'
            WHEN k.GunAdet / (y.YilAdet / 365.0) > 30                    THEN '2_PATLAMA (30x+)'
            WHEN k.GunAdet / (y.YilAdet / 365.0) BETWEEN 10 AND 30       THEN '3_Çok güçlü (10-30x)'
            WHEN k.GunAdet / (y.YilAdet / 365.0) BETWEEN 3  AND 10       THEN '4_Güçlü (3-10x)'
            WHEN k.GunAdet / (y.YilAdet / 365.0) BETWEEN 1  AND 3        THEN '5_Normal (1-3x)'
            ELSE                                                              '6_Etkisiz (<1x)'
        END AS Segment
    FROM KampGunluk k
    LEFT JOIN YilSatis y ON y.ehstkID = k.ehstkID
    WHERE k.GunAdet > 0
)
SELECT
    Gun AS [Gün],
    Segment,
    COUNT(DISTINCT ehstkID) AS [Ürün Çeşidi],
    CAST(SUM(GunAdet)  AS INT)            AS [Adet],
    CAST(SUM(GunTutar) AS DECIMAL(18,2))  AS [Tutar],
    CAST(AVG(Katsayi)  AS DECIMAL(10,1))  AS [Ort. Katsayı],
    CAST(MAX(Katsayi)  AS DECIMAL(10,1))  AS [Max Katsayı]
FROM KampSegmentli
GROUP BY Gun, Segment
ORDER BY Gun, Segment;


-- =====================================================================
-- ÇIKTI 2: TOP 50 VURUCU ÜRÜN — En yüksek katsayı
-- (1 yıl boyunca az satan, kampanyada patlayanlar)
-- =====================================================================
;WITH KampToplam AS (
    SELECT h.ehstkID,
        -SUM(CASE WHEN h.ehTip IN (4,100) THEN h.ehAdetN ELSE 0 END)
        -SUM(CASE WHEN h.ehTip IN (5,101) THEN h.ehAdetN ELSE 0 END) AS KampAdet,
         SUM(CASE WHEN h.ehTip IN (4,100) THEN h.ehTutarN ELSE 0 END)
        -SUM(CASE WHEN h.ehTip IN (5,101) THEN h.ehTutarN ELSE 0 END) AS KampTutar
    FROM dbo.irsHrk h WITH (NOLOCK)
    JOIN bkm.urunbilgi u ON u.stkID = h.ehstkID
    WHERE h.ehTrhS >= @KampBas AND h.ehTrhS < @KampBit
      AND h.ehMekan IN (1,4477,4478) AND h.ehTip IN (4,5,100,101) AND h.ehAltDepo=0
      AND u.Kategori3 IN (N'Kitap',N'Çocuk Kitabı',N'Akademi',N'Hazırlık Kitapları')
      AND h.ehstkID <> 583160
    GROUP BY h.ehstkID
),
YilTop AS (
    SELECT h.ehstkID,
        -SUM(CASE WHEN h.ehTip IN (4,100) THEN h.ehAdetN ELSE 0 END)
        -SUM(CASE WHEN h.ehTip IN (5,101) THEN h.ehAdetN ELSE 0 END) AS YilAdet
    FROM dbo.irsHrk h WITH (NOLOCK)
    WHERE h.ehTrhS >= @YilBas AND h.ehTrhS < @YilBit
      AND h.ehMekan IN (1,4477,4478) AND h.ehTip IN (4,5,100,101) AND h.ehAltDepo=0
    GROUP BY h.ehstkID
)
SELECT TOP 50
    k.ehstkID AS [stkID],
    u.stkAd AS [Ürün Adı],
    ub.Kategori3 AS [Kategori],
    CAST(ISNULL(y.YilAdet, 0) AS INT)               AS [Yıllık Adet],
    CAST(ISNULL(y.YilAdet, 0)/365.0 AS DECIMAL(10,3)) AS [Yıllık Günlük Ort],
    CAST(k.KampAdet AS INT)                          AS [4 Gün Kamp Adet],
    CAST(k.KampAdet/4.0 AS DECIMAL(10,2))            AS [Kamp Günlük Ort],
    CAST(k.KampTutar AS DECIMAL(18,2))               AS [Kamp Tutar],
    CASE WHEN ISNULL(y.YilAdet,0) = 0 THEN 99999
         ELSE CAST((k.KampAdet/4.0) / (y.YilAdet/365.0) AS DECIMAL(10,1)) END AS [Katsayı],
    -- "Kaç günlük normal satışa eşit"
    CASE WHEN ISNULL(y.YilAdet,0) = 0 THEN NULL
         ELSE CAST(k.KampAdet * 365.0 / y.YilAdet AS DECIMAL(10,1)) END AS [Kaç Günlük Satışa Eşit]
FROM KampToplam k
LEFT JOIN YilTop y ON y.ehstkID = k.ehstkID
INNER JOIN dbo.urn u WITH (NOLOCK) ON u.stkID = k.ehstkID
INNER JOIN bkm.urunbilgi ub ON ub.stkID = k.ehstkID
WHERE k.KampAdet >= 10  -- en az 10 adet sat
ORDER BY
    CASE WHEN ISNULL(y.YilAdet,0) = 0 THEN 99999
         ELSE (k.KampAdet/4.0) / (y.YilAdet/365.0) END DESC;


-- =====================================================================
-- ÇIKTI 3: TOP 30 ÖLÜ STOK KURTARMASI — yılda 0 satış, kampanyada en çok
-- (Stok tahliyesinin somut listesi)
-- =====================================================================
;WITH KampToplam AS (
    SELECT h.ehstkID,
        -SUM(CASE WHEN h.ehTip IN (4,100) THEN h.ehAdetN ELSE 0 END)
        -SUM(CASE WHEN h.ehTip IN (5,101) THEN h.ehAdetN ELSE 0 END) AS KampAdet,
         SUM(CASE WHEN h.ehTip IN (4,100) THEN h.ehTutarN ELSE 0 END)
        -SUM(CASE WHEN h.ehTip IN (5,101) THEN h.ehTutarN ELSE 0 END) AS KampTutar
    FROM dbo.irsHrk h WITH (NOLOCK)
    JOIN bkm.urunbilgi u ON u.stkID = h.ehstkID
    WHERE h.ehTrhS >= @KampBas AND h.ehTrhS < @KampBit
      AND h.ehMekan IN (1,4477,4478) AND h.ehTip IN (4,5,100,101) AND h.ehAltDepo=0
      AND u.Kategori3 IN (N'Kitap',N'Çocuk Kitabı',N'Akademi',N'Hazırlık Kitapları')
      AND h.ehstkID <> 583160
    GROUP BY h.ehstkID
),
YilTop AS (
    SELECT h.ehstkID FROM dbo.irsHrk h WITH (NOLOCK)
    WHERE h.ehTrhS >= @YilBas AND h.ehTrhS < @YilBit
      AND h.ehMekan IN (1,4477,4478) AND h.ehTip IN (4,100) AND h.ehAltDepo=0
    GROUP BY h.ehstkID HAVING SUM(h.ehAdetN) < 0  -- en az 1 satış
)
SELECT TOP 30
    k.ehstkID AS [stkID],
    u.stkAd AS [Ürün Adı],
    ub.Kategori3 AS [Kategori],
    CAST(k.KampAdet AS INT) AS [Kamp Adet],
    CAST(k.KampTutar AS DECIMAL(18,2)) AS [Kamp Tutar]
FROM KampToplam k
INNER JOIN dbo.urn u WITH (NOLOCK) ON u.stkID = k.ehstkID
INNER JOIN bkm.urunbilgi ub ON ub.stkID = k.ehstkID
WHERE k.ehstkID NOT IN (SELECT ehstkID FROM YilTop)  -- 1 yılda 0 satış
  AND k.KampAdet > 0
ORDER BY k.KampTutar DESC;
