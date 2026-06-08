/*================================================================
  Kâr/Zarar v4 (Hızlandırılmış) — Tüm Ürün, 4 Mağaza
  ----------------------------------------------------------------
  Yazan         : Claude (Fikri'nin prod sorgusu temel + perf refactor)
  Tarih         : 07.05.2026

  HEDEF: birkaç saniyede sonuç (orijinal dakikalar sürüyordu)

  PERFORMANS STRATEJİSİ:
    Eski: OUTER APPLY her satış satırı için 5-fat avg lookup
          → N satış × 5 fat × cross-DB UNION = ağır
    Yeni: 1) Satış aralığında SATILAN ürünleri DISTINCT al (~5-10K ürün)
          2) BU ürünler için tek seferde 5-fat avg → #MALIYET_AVG
          3) BU ürünler için ALISSART → #ALISSART
          4) SATIS detay: LEFT JOIN materyalize edilmiş tablolardan
    Hız:  N×M (her satış için subquery) → O(N+M) (ürün başına 1 kez)

  KAPSAM:
    - TÜM ürünler (kategori filtresi YOK)
    - Mağazalar: 12 (Ana Depo) + 1 (FSM) + 4477 (Özlüce) + 4478 (İst.Yolu)
    - SatisTip kanal kırılımı: PERAKENDE/WEB/HEYKEL/ODAK/KURUMSAL
    - Maliyet: 5-fat avg → Aktarim ortalama → ALISSART (öncelik)
    - 4 maliyet grubu: MALİYETLİ × ŞARTLI/ŞARTSIZ × MALİYETSİZ + TANIMSIZ + MUHTELİF

  KULLANIM:
    @TARIH_ILK / @TARIH_SON: aralık DAHİL
    @MALIYETTIP: 0 = 5-fat avg, >0 = ALISSART (NetAlisFiyat)
    @DETAYGOSTER / @OZETGOSTER / @MAGAZAOZETGOSTER / @DOGRULAMAGOSTER
================================================================*/

USE DerinSISBkm;
SET NOCOUNT ON;

DECLARE @TARIH_ILK DATE = '27/04/2026';
DECLARE @TARIH_SON DATE = '03/05/2026';

DECLARE @DETAYGOSTER         BIT = 0;
DECLARE @OZETGOSTER          BIT = 0;
DECLARE @MAGAZAOZETGOSTER    BIT = 1;
DECLARE @DOGRULAMAGOSTER     BIT = 1;

DECLARE @MALIYETTIP TINYINT = 0;

-- Maliyet için lookback aralığı (satış aralığından geriye)
DECLARE @MALIYET_LOOKBACK_AY TINYINT = 12;

-- ================================================================
-- ADIM 1: Satış aralığında SATILAN ürünleri çıkar
-- ================================================================
CREATE TABLE #SATILAN_URUN (stkId INT PRIMARY KEY);

INSERT INTO #SATILAN_URUN(stkId)
SELECT DISTINCT ia.ehStkID
FROM dbo.irs   irs WITH (NOLOCK)
INNER JOIN dbo.irsAyr ia WITH (NOLOCK) ON ia.ehID = irs.eID
WHERE irs.eTip IN (1, 4, 3, 5, 100, 101)
  AND irs.eTarih BETWEEN @TARIH_ILK AND @TARIH_SON
  AND irs.Neden <> 243
  AND irs.NedenAlt <> 1
  AND irs.eMekan IN (12, 1, 4477, 4478)
  AND (irs.eDurum = 1 OR irs.eTip IN (100, 101))
  AND irs.eID NOT IN (
      1409000,1409109,1409209,1409319,1409373,1409446,1409556,
      4253372,4253665,4253850,4253873,4253874,4253876,4253946,4254021,
      4254214,4254850,4255154,4255255,4255310,4255411,4255459,4255476,4255507,4255537,
      4272130,4272149,4272157,4272158,4272160,4272162,4272183,4272347,
      4281796,4281832,4281860,4281898,4281939,4281962,4281963,4281964,
      4287136,4287137,4287138,4287140,4287141,4287149,4287150,4287151,
      4291824,4291825,4291832,4291833,4291836,4291838,4291839,4291840,4291842,
      4300012,4300035,4300036,4300038,4300040,4300041,4300044,
      4303143,4303223,4303307,4303416,4303766,4303769,4303827,4303981,4304043,
      7061919,7108754,7115012
  );

-- ================================================================
-- ADIM 2: Bu ürünler için 5-fat avg maliyet (tek seferde)
-- ================================================================
CREATE TABLE #MALIYET_AVG (
    stkID   INT          PRIMARY KEY,
    MALIYET DECIMAL(18,4)
);

DECLARE @LOOKBACK_DATE DATE = DATEADD(MONTH, -@MALIYET_LOOKBACK_AY, @TARIH_ILK);

;WITH SonFat AS (
    -- Her satılan ürün için son 5 alış faturası satırı
    SELECT s.stkId, b.ehAdetN, b.ehTutarN
    FROM #SATILAN_URUN s
    CROSS APPLY (
        SELECT TOP 5 fa.ehAdetN, fa.ehTutarN
        FROM dbo.fatAyr fa WITH (NOLOCK)
        INNER JOIN dbo.fat f WITH (NOLOCK) ON fa.ehID = f.eID
        WHERE fa.ehStkID = s.stkId
          AND fa.ehAdetN <> 0
          AND f.eTip = 0
          AND f.eDurum <> 2
          AND f.eTarih <= @TARIH_SON
          AND f.eTarih >= @LOOKBACK_DATE
          AND (f.eFirma <> 9525 OR (f.eFirma = 9525 AND f.eTarih >= '01/09/2022'))
        ORDER BY f.eTarih DESC
    ) b
)
INSERT INTO #MALIYET_AVG(stkID, MALIYET)
SELECT stkId,
       CONVERT(MONEY, SUM(ehTutarN) / NULLIF(SUM(ehAdetN), 0))
FROM SonFat
GROUP BY stkId
HAVING SUM(ehAdetN) <> 0;

-- ================================================================
-- ADIM 2b: ODAK_FATURA cross-DB ekle (yoksa atla)
--   ODAK ürünleri için BKMDATA..ODAK_FATURA'dan TOP 5 daha
--   Sadece DerinSIS fat'ta hiç ortalama olmayan ürünler için
-- ================================================================
;WITH SonOdak AS (
    SELECT s.stkId, b.ADET, b.TUTAR
    FROM #SATILAN_URUN s
    CROSS APPLY (
        SELECT TOP 5 f.ADET, f.NET * f.ADET AS TUTAR
        FROM BKMDATA..ODAK_FATURA f WITH (NOLOCK)
        WHERE f.STKID = s.stkId
          AND f.TARIH <= @TARIH_SON
          AND f.TARIH >= @LOOKBACK_DATE
        ORDER BY f.TARIH DESC
    ) b
    WHERE NOT EXISTS (SELECT 1 FROM #MALIYET_AVG m WHERE m.stkID = s.stkId)
)
INSERT INTO #MALIYET_AVG(stkID, MALIYET)
SELECT stkId,
       CONVERT(MONEY, SUM(TUTAR) / NULLIF(SUM(ADET), 0))
FROM SonOdak
GROUP BY stkId
HAVING SUM(ADET) <> 0;

-- ================================================================
-- ADIM 3: ALISSART (fytOzl, 5 kademeli iskonto)
-- ================================================================
CREATE TABLE #ALISSART (
    stkId           INT          PRIMARY KEY,
    BrutAlisFiyat   DECIMAL(18,4),
    NetAlisFiyat    DECIMAL(18,4)
);

INSERT INTO #ALISSART(stkId, BrutAlisFiyat, NetAlisFiyat)
SELECT s.stkId, a.sonrakiFiyat,
       a.sonrakiFiyat
       * (1 - a.fInd1/100.0) * (1 - a.fInd2/100.0) * (1 - a.fInd3/100.0)
       * (1 - a.fInd4/100.0) * (1 - a.fInd5/100.0) AS NetAlisFiyat
FROM #SATILAN_URUN s
INNER JOIN dbo.urn u WITH (NOLOCK) ON u.stkID = s.stkId
CROSS APPLY (
    SELECT TOP 1 sonrakiFiyat, fInd1, fInd2, fInd3, fInd4, fInd5
    FROM dbo.fytOzl fy WITH (NOLOCK)
    WHERE fy.fStkID = s.stkId
      AND fy.fFrmID IN (0, u.stkFirma)
      AND fy.fTur = 1
      AND fy.fTip = 1
    ORDER BY fy.fTarihSon DESC
) a;

-- ================================================================
-- ADIM 4: SATIS detay #MALIYET'e yaz
-- ================================================================
CREATE TABLE #MALIYET (
    tarih       DATE          INDEX IX_M2,
    satisTip    VARCHAR(20),
    mekanId     INT,
    stkId       INT           INDEX IX_M2a,
    adet        DECIMAL(18,3),
    tutar       DECIMAL(18,4),
    maliyet     DECIMAL(18,4)
);

;WITH SATIS AS (
    SELECT
        irs.eTarih AS tarih,
        irs.eMekan AS mekanID,
        ia.ehStkID AS stkId,
        CASE
            WHEN irs.eID IS NULL                                     THEN 'BELİRSİZ'
            WHEN irs.eTip IN (100, 101)                              THEN 'PERAKENDE'
            WHEN ff.eTip = 4 AND ff.eFatPos = 1                      THEN 'PERAKENDE'
            WHEN ff.eTip = 1 AND ff.eMekan = 12 AND ff.Neden = 239   THEN 'WEB'
            WHEN ff.eFirma = 56                                      THEN 'HEYKEL'
            WHEN ff.eFirma = 9525                                    THEN 'ODAK'
            ELSE                                                          'KURUMSAL'
        END AS SatisTip,
        -1.00 * SUM(ISNULL(fa.ehAdet, ia.ehAdet)) AS adet,
        SUM(
            CASE
                WHEN irs.eTip IN (3, 5, 101)
                    THEN -1 * ISNULL(fa.ehTutar - fa.ehIndirim, ia.ehTutar - ia.ehIndirim)
                ELSE         ISNULL(fa.ehTutar - fa.ehIndirim, ia.ehTutar - ia.ehIndirim)
            END
        ) AS tutar
    FROM dbo.irs irs WITH (NOLOCK)
    INNER JOIN dbo.irsAyr ia WITH (NOLOCK) ON ia.ehID = irs.eID
    LEFT  JOIN dbo.fatAyr fa WITH (NOLOCK) ON fa.ehIrsID = ia.ehID AND fa.ehIrsSira = ia.ehSira
    LEFT  JOIN dbo.fat    ff WITH (NOLOCK) ON ff.eID = fa.ehID AND ff.Neden <> 243
    WHERE irs.eTip IN (1, 4, 3, 5, 100, 101)
      AND irs.eTarih BETWEEN @TARIH_ILK AND @TARIH_SON
      AND irs.Neden <> 243
      AND irs.NedenAlt <> 1
      AND irs.eMekan IN (12, 1, 4477, 4478)
      AND (irs.eDurum = 1 OR irs.eTip IN (100, 101))
      AND ia.ehStkID IN (SELECT stkId FROM #SATILAN_URUN)
    GROUP BY irs.eTarih, irs.eMekan, ia.ehStkID,
        CASE
            WHEN irs.eID IS NULL                                     THEN 'BELİRSİZ'
            WHEN irs.eTip IN (100, 101)                              THEN 'PERAKENDE'
            WHEN ff.eTip = 4 AND ff.eFatPos = 1                      THEN 'PERAKENDE'
            WHEN ff.eTip = 1 AND ff.eMekan = 12 AND ff.Neden = 239   THEN 'WEB'
            WHEN ff.eFirma = 56                                      THEN 'HEYKEL'
            WHEN ff.eFirma = 9525                                    THEN 'ODAK'
            ELSE                                                          'KURUMSAL'
        END
)
INSERT INTO #MALIYET(tarih, mekanId, stkId, satisTip, adet, tutar, maliyet)
SELECT
    s.tarih, s.mekanID, s.stkId, s.satisTip, s.adet, s.tutar,
    -- 3 katmanlı: 5-fat avg → Aktarim ortalama → NetAlisFiyat (ALISSART proxy)
    COALESCE(MA.MALIYET, AKM.ORT_ALIS, AS_.NetAlisFiyat) * s.adet AS Maliyet
FROM SATIS s
LEFT JOIN #MALIYET_AVG MA                          ON MA.stkID = s.stkId
LEFT JOIN Aktarim.dbo.BKM_STOKLAR_MALIYETLI AKM
        WITH (NOLOCK)                              ON AKM.STKID = s.stkId
LEFT JOIN #ALISSART AS_                            ON AS_.stkId = s.stkId;


-- ================================================================
-- ÇIKTI 1: ÜRÜN BAZLI DETAY
-- ================================================================
IF @DETAYGOSTER = 1
BEGIN
    SELECT
        f.frmAd                                       AS lokasyonAd,
        kt.ktgrAd                                     AS Kategori,
        u.stkID, u.stkAd,
        mk.mrkAd                                      AS Marka,
        M.satisTip,
        SUM(M.adet)                                   AS Adet,
        SUM(M.tutar)                                  AS TUTAR,
        SUM(M.maliyet)                                AS MALIYET,
        SUM(M.adet * AS_.NetAlisFiyat)                AS ALISSART_MALIYET,
        CASE
            WHEN kt.ktgrAd = 'Tanımsız'                                                 THEN 'TANIMSIZ'
            WHEN u.stkID IN (101296,84642,59337,104965,65462,56761,64515,22390,60318,65940) THEN 'MUHTELİF'
            WHEN ISNULL(SUM(M.maliyet),0) <> 0 AND ISNULL(SUM(M.adet*AS_.NetAlisFiyat),0) <> 0 THEN 'MALİYETLİ SATINALMA ŞARTLI'
            WHEN ISNULL(SUM(M.maliyet),0) <> 0                                          THEN 'MALİYETLİ SATINALMA ŞARTSIZ'
            WHEN ISNULL(SUM(M.adet*AS_.NetAlisFiyat),0) <> 0                            THEN 'MALİYETSİZ SATINALMA ŞARTLI'
            ELSE                                                                            'MALİYETSİZ SATINALMA ŞARTSIZ'
        END AS GRUP,
        SUM(M.tutar) - SUM(M.maliyet)                 AS Marj_TL
    FROM #MALIYET M
    INNER JOIN dbo.urn       u  WITH (NOLOCK) ON u.stkID   = M.stkId
    INNER JOIN dbo.urnKtgr2  kt WITH (NOLOCK) ON kt.ktgrID = u.urnKtgr2ID
    INNER JOIN dbo.urnMrk    mk WITH (NOLOCK) ON mk.mrkID  = u.urnMrkID
    INNER JOIN dbo.frm       f  WITH (NOLOCK) ON f.frmID   = M.mekanId
    LEFT  JOIN #ALISSART     AS_ WITH (NOLOCK) ON AS_.stkId = M.stkId
    GROUP BY f.frmAd, kt.ktgrAd, u.stkID, u.stkAd, mk.mrkAd, M.satisTip
    ORDER BY SUM(M.tutar) DESC;
END

-- ================================================================
-- ÇIKTI 2: MALİYETLİ/MALİYETSİZ ÖZET
-- ================================================================
IF @OZETGOSTER = 1
BEGIN
    ;WITH OZET AS (
        SELECT
            f.frmAd lokasyonAd, kt.ktgrAd Kategori, mk.mrkAd Marka, M.satisTip,
            CASE
                WHEN kt.ktgrAd = 'Tanımsız'                                                 THEN 'TANIMSIZ'
                WHEN u.stkID IN (101296,84642,59337,104965,65462,56761,64515,22390,60318,65940) THEN 'MUHTELİF'
                WHEN ISNULL(SUM(IIF(@MALIYETTIP = 0, M.maliyet, M.adet * AS_.NetAlisFiyat)), 0) <> 0 THEN 'MALİYETLİ'
                ELSE                                                                            'MALİYETSİZ'
            END AS GRUP,
            SUM(M.adet)                                                AS SATIS_ADET,
            SUM(M.tutar)                                               AS SATIS_TUTAR,
            SUM(IIF(@MALIYETTIP = 0, M.maliyet, M.adet * AS_.NetAlisFiyat)) AS MALIYET
        FROM #MALIYET M
        INNER JOIN dbo.urn       u  WITH (NOLOCK) ON u.stkID   = M.stkId
        INNER JOIN dbo.urnKtgr2  kt WITH (NOLOCK) ON kt.ktgrID = u.urnKtgr2ID
        INNER JOIN dbo.urnMrk    mk WITH (NOLOCK) ON mk.mrkID  = u.urnMrkID
        INNER JOIN dbo.frm       f  WITH (NOLOCK) ON f.frmID   = M.mekanId
        LEFT  JOIN #ALISSART     AS_ WITH (NOLOCK) ON AS_.stkId = M.stkId
        GROUP BY f.frmAd, kt.ktgrAd, u.stkID, mk.mrkAd, M.satisTip
    )
    SELECT
        O.lokasyonAd, O.Kategori, O.Marka, O.satisTip,
        SUM(IIF(O.GRUP = 'MALİYETLİ',  O.SATIS_TUTAR, 0)) AS MALIYETLI_SATIS,
        SUM(IIF(O.GRUP = 'MALİYETLİ',  O.MALIYET,     0)) AS MALIYETLI_SATIS_SMM,
        SUM(IIF(O.GRUP = 'MALİYETSİZ', O.SATIS_TUTAR, 0)) AS MALIYETSIZ_SATIS,
        SUM(IIF(O.GRUP = 'TANIMSIZ',   O.SATIS_TUTAR, 0)) AS TANIMSIZ_SATIS,
        SUM(IIF(O.GRUP = 'MUHTELİF',   O.SATIS_TUTAR, 0)) AS MUHTELIF_SATIS
    FROM OZET O
    GROUP BY O.lokasyonAd, O.Kategori, O.Marka, O.satisTip;
END

-- ================================================================
-- ÇIKTI 3: MAĞAZA × KATEGORİ × KANAL KÂR/ZARAR
-- ================================================================
IF @MAGAZAOZETGOSTER = 1
BEGIN
    SELECT
        f.frmAd                                       AS Mağaza,
        kt.ktgrAd                                     AS Kategori,
        M.satisTip                                    AS Kanal,
        COUNT(DISTINCT M.stkId)                       AS UrunCesidi,
        CAST(SUM(M.adet)   AS DECIMAL(18,2))          AS NetAdet,
        CAST(SUM(M.tutar)  AS DECIMAL(18,2))          AS NetSatis,
        CAST(SUM(IIF(@MALIYETTIP = 0, M.maliyet, M.adet * AS_.NetAlisFiyat)) AS DECIMAL(18,2)) AS Maliyet,
        CAST(SUM(M.tutar) - SUM(IIF(@MALIYETTIP = 0, M.maliyet, M.adet * AS_.NetAlisFiyat)) AS DECIMAL(18,2)) AS Marj_TL,
        CAST(
            (SUM(M.tutar) - SUM(IIF(@MALIYETTIP = 0, M.maliyet, M.adet * AS_.NetAlisFiyat)))
            * 100.0 / NULLIF(SUM(M.tutar), 0)
        AS DECIMAL(8,2))                              AS Marj_Yuzde
    FROM #MALIYET M
        INNER JOIN dbo.urn       u  WITH (NOLOCK) ON u.stkID   = M.stkId
        INNER JOIN dbo.urnKtgr2  kt WITH (NOLOCK) ON kt.ktgrID = u.urnKtgr2ID
        INNER JOIN dbo.frm       f  WITH (NOLOCK) ON f.frmID   = M.mekanId
        LEFT  JOIN #ALISSART     AS_ WITH (NOLOCK) ON AS_.stkId = M.stkId
    GROUP BY f.frmAd, kt.ktgrAd, M.satisTip
    ORDER BY f.frmAd, SUM(M.tutar) DESC;
END

-- ================================================================
-- ÇIKTI 4: DOĞRULAMA — Kapsam metrikleri + temp tablo durumu
-- ================================================================
IF @DOGRULAMAGOSTER = 1
BEGIN
    SELECT 'Satılan Ürün'        AS Metrik, COUNT(*) AS Sayi FROM #SATILAN_URUN
    UNION ALL
    SELECT 'Maliyet (5fat avg)',           COUNT(*) FROM #MALIYET_AVG
    UNION ALL
    SELECT 'ALISSART (fytOzl)',            COUNT(*) FROM #ALISSART
    UNION ALL
    SELECT 'Satış satırı (#MALIYET)',      COUNT(*) FROM #MALIYET
    UNION ALL
    SELECT 'Toplam Tutar (TL)',
           CAST(SUM(tutar) AS BIGINT) FROM #MALIYET
    UNION ALL
    SELECT 'Toplam Maliyet (TL)',
           CAST(SUM(maliyet) AS BIGINT) FROM #MALIYET
    UNION ALL
    SELECT 'Maliyetsiz Satır',
           SUM(CASE WHEN maliyet IS NULL OR maliyet = 0 THEN 1 ELSE 0 END) FROM #MALIYET;
END

-- =============== TEMİZLİK ===============
DROP TABLE #SATILAN_URUN;
DROP TABLE #MALIYET_AVG;
DROP TABLE #ALISSART;
DROP TABLE #MALIYET;
