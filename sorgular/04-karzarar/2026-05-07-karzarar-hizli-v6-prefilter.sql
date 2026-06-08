/*================================================================
  Kâr/Zarar v6 — Pre-Filter Strategy
  ----------------------------------------------------------------
  Yazan         : Claude (v5 + v3 statistics analizi)
  Tarih         : 07.05.2026

  v5 STATISTICS analizi:
    fytOzl: 38 sn (588K logical read) — ALISSART darboğaz
    fat:    36 sn (200M logical read) — 5-fat avg darboğaz
    Toplam: ~75 sn

  v6 ÇÖZÜM:
    fat ve fytOzl tablolarını ANA döngüden ÖNCE bir kez tarayıp
    temp+index'li ön-tablolara çekiyoruz. CROSS APPLY artık
    devasa tablolar yerine küçük temp'lere bakıyor.

    Beklenen: 5-15 saniye (5x hızlanma).

  ÖN-TEMP TABLOLAR (ek):
    #FAT_HEADER (PK eID, NCI eTarih)
        — Lookback aralığında alış faturası başlık (eTip=0, eDurum<>2)
    #FYTOZL_AKT (NCI fStkID, fTarihSon DESC)
        — Alış şart fiyatları (fTur=1, fTip=1) sadece satılan ürünler için

  KAPSAM:
    - TÜM ürünler (kategori filtresi yok)
    - Mağaza: 12 (Ana Depo) + 1 (FSM) + 4477 (Özlüce) + 4478 (İst.Yolu)
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
DECLARE @ALISSART_DAHIL BIT = 0;  -- 0: ALISSART hesaplama (fytOzl ağır, ~21sn). 1: hesapla
DECLARE @MALIYET_LOOKBACK_AY TINYINT = 12;
DECLARE @LOOKBACK_DATE DATE = DATEADD(MONTH, -@MALIYET_LOOKBACK_AY, @TARIH_ILK);


-- ================================================================
-- ADIM 1: Satılan ürünler
-- ================================================================
IF OBJECT_ID('tempdb..#SATILAN_URUN') IS NOT NULL DROP TABLE #SATILAN_URUN;
CREATE TABLE #SATILAN_URUN (stkId INT NOT NULL PRIMARY KEY);

INSERT INTO #SATILAN_URUN(stkId)
SELECT DISTINCT ia.ehStkID
FROM dbo.irs   irs WITH (NOLOCK)
INNER JOIN dbo.irsAyr ia WITH (NOLOCK) ON ia.ehID = irs.eID
WHERE irs.eTip IN (1, 4, 3, 5, 100, 101)
  AND irs.eTarih BETWEEN @TARIH_ILK AND @TARIH_SON
  AND irs.Neden    <> 243
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
-- ADIM 1B: ÖN-TEMP — fat lookback aralığında alış başlık (BU KRİTİK!)
-- Tek scan ile fat tablosundaki ilgili kayıtları çıkarıyoruz.
-- Sonraki adımlarda fat'a artık bakılmaz, sadece bu temp'e.
-- ================================================================
IF OBJECT_ID('tempdb..#FAT_HEADER') IS NOT NULL DROP TABLE #FAT_HEADER;
CREATE TABLE #FAT_HEADER (
    eID    INT          NOT NULL PRIMARY KEY,
    eTarih DATE         NOT NULL,
    eFirma INT          NOT NULL
);

INSERT INTO #FAT_HEADER(eID, eTarih, eFirma)
SELECT f.eID, f.eTarih, f.eFirma
FROM dbo.fat f WITH (NOLOCK)
WHERE f.eTip   = 0
  AND f.eDurum <> 2
  AND f.eTarih >= @LOOKBACK_DATE
  AND f.eTarih <= @TARIH_SON
  AND (f.eFirma <> 9525 OR (f.eFirma = 9525 AND f.eTarih >= '01/09/2022'));

CREATE NONCLUSTERED INDEX IX_FAT_HEADER_eTarih ON #FAT_HEADER (eTarih DESC) INCLUDE (eFirma);


-- ================================================================
-- ADIM 1C: ÖN-TEMP — fytOzl alış şart (sadece @ALISSART_DAHIL=1 ise)
-- DİKKAT: fytOzl 135M satır + filtered covering index yok →
-- INNER JOIN bile tam scan yapıyor (~21 sn, 588K logical read).
-- DBA önerisi:
--   CREATE NONCLUSTERED INDEX IX_fytOzl_AlisSart
--   ON dbo.fytOzl (fStkID, fFrmID, fTarihSon DESC)
--   INCLUDE (sonrakiFiyat, fInd1, fInd2, fInd3, fInd4, fInd5)
--   WHERE fTur = 1 AND fTip = 1;
-- ================================================================
IF OBJECT_ID('tempdb..#FYTOZL_AKT') IS NOT NULL DROP TABLE #FYTOZL_AKT;
CREATE TABLE #FYTOZL_AKT (
    fStkID       INT           NOT NULL,
    fFrmID       INT           NOT NULL,
    fTarihSon    DATE          NOT NULL,
    sonrakiFiyat DECIMAL(18,4) NOT NULL,
    fInd1        DECIMAL(5,2)  NOT NULL,
    fInd2        DECIMAL(5,2)  NOT NULL,
    fInd3        DECIMAL(5,2)  NOT NULL,
    fInd4        DECIMAL(5,2)  NOT NULL,
    fInd5        DECIMAL(5,2)  NOT NULL
);

IF @ALISSART_DAHIL = 1
BEGIN
    INSERT INTO #FYTOZL_AKT(fStkID, fFrmID, fTarihSon, sonrakiFiyat, fInd1, fInd2, fInd3, fInd4, fInd5)
    SELECT fy.fStkID, fy.fFrmID, fy.fTarihSon, fy.sonrakiFiyat,
           fy.fInd1, fy.fInd2, fy.fInd3, fy.fInd4, fy.fInd5
    FROM dbo.fytOzl fy WITH (NOLOCK)
    INNER JOIN #SATILAN_URUN s ON s.stkId = fy.fStkID
    WHERE fy.fTur = 1
      AND fy.fTip = 1;

    CREATE CLUSTERED INDEX CIX_FYTOZL_AKT ON #FYTOZL_AKT (fStkID, fTarihSon DESC);
END


-- ================================================================
-- ADIM 2: 5-fat avg (DerinSIS) — artık #FAT_HEADER'a bakar, fat'a değil!
-- ================================================================
IF OBJECT_ID('tempdb..#FAT_RAW') IS NOT NULL DROP TABLE #FAT_RAW;
CREATE TABLE #FAT_RAW (
    stkId    INT           NOT NULL,
    eTarih   DATE          NOT NULL,
    ehAdetN  DECIMAL(18,3) NOT NULL,
    ehTutarN DECIMAL(18,4) NOT NULL
);

INSERT INTO #FAT_RAW(stkId, eTarih, ehAdetN, ehTutarN)
SELECT s.stkId, b.eTarih, b.ehAdetN, b.ehTutarN
FROM #SATILAN_URUN s
CROSS APPLY (
    SELECT TOP 5 fa.ehAdetN, fa.ehTutarN, fh.eTarih
    FROM dbo.fatAyr fa WITH (NOLOCK)
    INNER JOIN #FAT_HEADER fh ON fh.eID = fa.ehID
    WHERE fa.ehStkID = s.stkId
      AND fa.ehAdetN <> 0
    ORDER BY fh.eTarih DESC
) b;

CREATE NONCLUSTERED INDEX IX_FAT_RAW_stk ON #FAT_RAW (stkId);


-- ================================================================
-- ADIM 3: ODAK_FATURA fallback (sadece DerinSIS'te yoksa)
-- ================================================================
IF OBJECT_ID('tempdb..#ODAK_RAW') IS NOT NULL DROP TABLE #ODAK_RAW;
CREATE TABLE #ODAK_RAW (
    stkId INT          NOT NULL,
    Tarih DATE         NOT NULL,
    ADET  DECIMAL(18,3) NOT NULL,
    TUTAR DECIMAL(18,4) NOT NULL
);

INSERT INTO #ODAK_RAW(stkId, Tarih, ADET, TUTAR)
SELECT s.stkId, b.TARIH, b.ADET, b.NET * b.ADET
FROM #SATILAN_URUN s
CROSS APPLY (
    SELECT TOP 5 f.TARIH, f.ADET, f.NET
    FROM BKMDATA..ODAK_FATURA f WITH (NOLOCK)
    WHERE f.STKID = s.stkId
      AND f.TARIH <= @TARIH_SON
      AND f.TARIH >= @LOOKBACK_DATE
    ORDER BY f.TARIH DESC
) b
WHERE NOT EXISTS (SELECT 1 FROM #FAT_RAW fr WHERE fr.stkId = s.stkId);

CREATE NONCLUSTERED INDEX IX_ODAK_RAW_stk ON #ODAK_RAW (stkId);


-- ================================================================
-- ADIM 4: 5-fat avg ortalama
-- ================================================================
IF OBJECT_ID('tempdb..#MALIYET_AVG') IS NOT NULL DROP TABLE #MALIYET_AVG;
CREATE TABLE #MALIYET_AVG (
    stkID   INT           NOT NULL PRIMARY KEY,
    MALIYET DECIMAL(18,4)
);

;WITH BIRLESIK AS (
    SELECT stkId, ehAdetN AS adet, ehTutarN AS tutar FROM #FAT_RAW
    UNION ALL
    SELECT stkId, ADET, TUTAR FROM #ODAK_RAW
)
INSERT INTO #MALIYET_AVG(stkID, MALIYET)
SELECT stkId,
       CONVERT(MONEY, SUM(tutar) / NULLIF(SUM(adet), 0))
FROM BIRLESIK
GROUP BY stkId
HAVING SUM(adet) <> 0;


-- ================================================================
-- ADIM 5: ALISSART — artık #FYTOZL_AKT'a bakar (CIX seek!)
-- ================================================================
IF OBJECT_ID('tempdb..#ALISSART') IS NOT NULL DROP TABLE #ALISSART;
CREATE TABLE #ALISSART (
    stkId           INT           NOT NULL PRIMARY KEY,
    BrutAlisFiyat   DECIMAL(18,4),
    NetAlisFiyat    DECIMAL(18,4)
);

IF @ALISSART_DAHIL = 1
BEGIN
    INSERT INTO #ALISSART(stkId, BrutAlisFiyat, NetAlisFiyat)
    SELECT s.stkId, a.sonrakiFiyat,
           a.sonrakiFiyat
           * (1 - a.fInd1/100.0) * (1 - a.fInd2/100.0) * (1 - a.fInd3/100.0)
           * (1 - a.fInd4/100.0) * (1 - a.fInd5/100.0)
    FROM #SATILAN_URUN s
    INNER JOIN dbo.urn u WITH (NOLOCK) ON u.stkID = s.stkId
    CROSS APPLY (
        SELECT TOP 1 sonrakiFiyat, fInd1, fInd2, fInd3, fInd4, fInd5
        FROM #FYTOZL_AKT fy
        WHERE fy.fStkID = s.stkId
          AND fy.fFrmID IN (0, u.stkFirma)
        ORDER BY fy.fTarihSon DESC
    ) a;
END


-- ================================================================
-- ADIM 6: SATIS ham
-- ================================================================
IF OBJECT_ID('tempdb..#SATIS_RAW') IS NOT NULL DROP TABLE #SATIS_RAW;
CREATE TABLE #SATIS_RAW (
    tarih    DATE          NOT NULL,
    mekanId  INT           NOT NULL,
    stkId    INT           NOT NULL,
    satisTip VARCHAR(20)   NOT NULL,
    adet     DECIMAL(18,3) NOT NULL,
    tutar    DECIMAL(18,4) NOT NULL
);

INSERT INTO #SATIS_RAW(tarih, mekanId, stkId, satisTip, adet, tutar)
SELECT
    irs.eTarih, irs.eMekan, ia.ehStkID,
    CASE
        WHEN irs.eID IS NULL                                    THEN 'BELİRSİZ'
        WHEN irs.eTip IN (100, 101)                             THEN 'PERAKENDE'
        WHEN ff.eTip = 4 AND ff.eFatPos = 1                     THEN 'PERAKENDE'
        WHEN ff.eTip = 1 AND ff.eMekan = 12 AND ff.Neden = 239  THEN 'WEB'
        WHEN ff.eFirma = 56                                     THEN 'HEYKEL'
        WHEN ff.eFirma = 9525                                   THEN 'ODAK'
        ELSE                                                         'KURUMSAL'
    END,
    -1.00 * SUM(ISNULL(fa.ehAdet, ia.ehAdet)),
    SUM(CASE WHEN irs.eTip IN (3,5,101)
             THEN -1 * ISNULL(fa.ehTutar - fa.ehIndirim, ia.ehTutar - ia.ehIndirim)
             ELSE      ISNULL(fa.ehTutar - fa.ehIndirim, ia.ehTutar - ia.ehIndirim)
        END)
FROM dbo.irs irs WITH (NOLOCK)
INNER JOIN dbo.irsAyr ia WITH (NOLOCK)
    ON ia.ehID = irs.eID
   AND ia.ehStkID IN (SELECT stkId FROM #SATILAN_URUN)
LEFT  JOIN dbo.fatAyr fa WITH (NOLOCK)
    ON fa.ehIrsID = ia.ehID AND fa.ehIrsSira = ia.ehSira
LEFT  JOIN dbo.fat    ff WITH (NOLOCK)
    ON ff.eID = fa.ehID AND ff.Neden <> 243
WHERE irs.eTip IN (1, 4, 3, 5, 100, 101)
  AND irs.eTarih BETWEEN @TARIH_ILK AND @TARIH_SON
  AND irs.Neden    <> 243
  AND irs.NedenAlt <> 1
  AND irs.eMekan IN (12, 1, 4477, 4478)
  AND (irs.eDurum = 1 OR irs.eTip IN (100, 101))
GROUP BY irs.eTarih, irs.eMekan, ia.ehStkID,
    CASE
        WHEN irs.eID IS NULL                                    THEN 'BELİRSİZ'
        WHEN irs.eTip IN (100, 101)                             THEN 'PERAKENDE'
        WHEN ff.eTip = 4 AND ff.eFatPos = 1                     THEN 'PERAKENDE'
        WHEN ff.eTip = 1 AND ff.eMekan = 12 AND ff.Neden = 239  THEN 'WEB'
        WHEN ff.eFirma = 56                                     THEN 'HEYKEL'
        WHEN ff.eFirma = 9525                                   THEN 'ODAK'
        ELSE                                                         'KURUMSAL'
    END;

CREATE CLUSTERED INDEX CIX_SATIS_RAW ON #SATIS_RAW (tarih, mekanId, stkId);


-- ================================================================
-- ADIM 7: #MALIYET final
-- ================================================================
IF OBJECT_ID('tempdb..#MALIYET') IS NOT NULL DROP TABLE #MALIYET;
CREATE TABLE #MALIYET (
    tarih    DATE          NOT NULL,
    satisTip VARCHAR(20)   NOT NULL,
    mekanId  INT           NOT NULL,
    stkId    INT           NOT NULL,
    adet     DECIMAL(18,3) NOT NULL,
    tutar    DECIMAL(18,4) NOT NULL,
    maliyet  DECIMAL(18,4)
);

INSERT INTO #MALIYET(tarih, satisTip, mekanId, stkId, adet, tutar, maliyet)
SELECT s.tarih, s.satisTip, s.mekanId, s.stkId, s.adet, s.tutar,
       COALESCE(MA.MALIYET, AKM.ORT_ALIS, AS_.NetAlisFiyat) * s.adet
FROM #SATIS_RAW s
LEFT JOIN #MALIYET_AVG MA ON MA.stkID  = s.stkId
LEFT JOIN Aktarim.dbo.BKM_STOKLAR_MALIYETLI AKM
        WITH (NOLOCK)     ON AKM.STKID = s.stkId
LEFT JOIN #ALISSART AS_   ON AS_.stkId = s.stkId;

CREATE CLUSTERED INDEX CIX_MALIYET ON #MALIYET (tarih, mekanId, stkId);


-- ================================================================
-- ÇIKTI 3: MAĞAZA × KATEGORİ × KANAL + ROLLUP (mağaza+grand toplam)
-- ================================================================
IF @MAGAZAOZETGOSTER = 1
BEGIN
    ;WITH AGG AS (
        SELECT
            f.frmAd                                       AS frmAd,
            kt.ktgrAd                                     AS ktgrAd,
            M.satisTip                                    AS Kanal,
            COUNT(DISTINCT M.stkId)                       AS UrunCesidi,
            SUM(M.adet)                                   AS Adet,
            SUM(M.tutar)                                  AS Tutar,
            SUM(IIF(@MALIYETTIP = 0, M.maliyet, M.adet * AS_.NetAlisFiyat)) AS Maliyet,
            GROUPING(f.frmAd)                             AS gMagaza,
            GROUPING(kt.ktgrAd)                           AS gKategori
        FROM #MALIYET M
        INNER JOIN dbo.urn       u  WITH (NOLOCK) ON u.stkID   = M.stkId
        INNER JOIN dbo.urnKtgr2  kt WITH (NOLOCK) ON kt.ktgrID = u.urnKtgr2ID
        INNER JOIN dbo.frm       f  WITH (NOLOCK) ON f.frmID   = M.mekanId
        LEFT  JOIN #ALISSART AS_   ON AS_.stkId = M.stkId
        GROUP BY ROLLUP((f.frmAd), (kt.ktgrAd, M.satisTip))
    )
    SELECT
        ISNULL(frmAd, 'GENEL TOPLAM')           AS Mağaza,
        ISNULL(ktgrAd, '* Mağaza Toplam')       AS Kategori,
        ISNULL(Kanal, '')                       AS Kanal,
        UrunCesidi,
        CAST(Adet    AS DECIMAL(18,2))          AS Adet,
        CAST(Tutar   AS DECIMAL(18,2))          AS Tutar,
        CAST(Maliyet AS DECIMAL(18,2))          AS Maliyet,
        CAST(Tutar - Maliyet AS DECIMAL(18,2))  AS Marj_TL,
        CAST((Tutar - Maliyet) * 100.0 / NULLIF(Tutar, 0) AS DECIMAL(8,2)) AS Marj_Yuzde
    FROM AGG
    ORDER BY gMagaza, frmAd, gKategori, Tutar DESC;
END

-- ================================================================
-- ÇIKTI 4: DOĞRULAMA
-- ================================================================
IF @DOGRULAMAGOSTER = 1
BEGIN
    SELECT 'Satılan Ürün'                       AS Metrik, COUNT(*)   AS Sayi FROM #SATILAN_URUN
    UNION ALL SELECT 'Fat header (lookback)',             COUNT(*) FROM #FAT_HEADER
    UNION ALL SELECT 'fytOzl aktif (satılan ürün)',       COUNT(*) FROM #FYTOZL_AKT
    UNION ALL SELECT 'Fat ham (5x stkID)',                COUNT(*) FROM #FAT_RAW
    UNION ALL SELECT 'Odak ham (fallback)',               COUNT(*) FROM #ODAK_RAW
    UNION ALL SELECT 'Maliyet AVG (ürün)',                COUNT(*) FROM #MALIYET_AVG
    UNION ALL SELECT 'ALISSART (ürün)',                   COUNT(*) FROM #ALISSART
    UNION ALL SELECT 'SATIS ham (satır)',                 COUNT(*) FROM #SATIS_RAW
    UNION ALL SELECT 'MALIYET final (satır)',             COUNT(*) FROM #MALIYET
    UNION ALL SELECT 'Toplam Tutar (TL)',                 CAST(SUM(tutar) AS BIGINT)  FROM #MALIYET
    UNION ALL SELECT 'Toplam Maliyet (TL)',               CAST(SUM(maliyet) AS BIGINT) FROM #MALIYET
    UNION ALL SELECT 'Maliyetsiz Satır',
                     SUM(CASE WHEN maliyet IS NULL OR maliyet = 0 THEN 1 ELSE 0 END) FROM #MALIYET;
END


-- =============== TEMİZLİK ===============
DROP TABLE #SATILAN_URUN;
DROP TABLE #FAT_HEADER;
DROP TABLE #FYTOZL_AKT;
DROP TABLE #FAT_RAW;
DROP TABLE #ODAK_RAW;
DROP TABLE #MALIYET_AVG;
DROP TABLE #ALISSART;
DROP TABLE #SATIS_RAW;
DROP TABLE #MALIYET;
