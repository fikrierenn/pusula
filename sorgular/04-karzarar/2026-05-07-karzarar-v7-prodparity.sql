/*================================================================
  Kâr/Zarar v7 — PROD PARITY + Hızlandırılmış
  ----------------------------------------------------------------
  Yazan         : Claude
  Tarih         : 07.05.2026
  Kaynak        : 1.D Satılan Malın Maliyeti Güncel Sorgu (Fikri prod)

  v6 → v7 KRİTİK DEĞİŞİM:
    v6: Fallback 3 = ALISSART (fytOzl)  ← prod ile farklı sonuç!
    v7: Fallback 3 = SONRAKI (gelecek fatura proxy)  ← prod parity
    ALISSART artık final hesaba GİRMEZ, sadece detay raporda
    ayrı kolon olarak görünür (prod sorgudaki gibi).

  MALİYET FALLBACK ZİNCİRİ (PROD PARİTE):
    1. #MALIYET_AVG  = son 5 alış faturası ortalama (DerinSIS fat eTip=0 + BKMDATA..ODAK_FATURA UNION)
    2. Aktarim.dbo.BKM_STOKLAR_MALIYETLI.ORT_ALIS
    3. #FAT_FUTURE   = satıştan SONRAKİ ilk alış faturası birim (yeni ürünler için proxy)

  HIZLANDIRMA (v6'dan korunan):
    #FAT_HEADER ön-temp → fat tablosunu tek scan'de küçültür
    #SATILAN_URUN PK + index'li join'ler

  EKLEMELER:
    Mağaza × Kategori × Kanal ROLLUP (mağaza altı + grand total)
    @ALISSART_DAHIL parametresi (rapor için ayrı kolon, isteğe bağlı)
    Doğrulama metrikleri (kapsam sayıları)

  KAPSAM:
    - TÜM ürünler (kategori filtresi yok)
    - Mağaza: 12 (Ana Depo) + 1 (FSM) + 4477 (Özlüce) + 4478 (İst.Yolu)
    - Manuel exclude: ~100 anormal irs.eID

  KULLANIM:
    @TARIH_ILK / @TARIH_SON: aralık DAHİL
    @ALISSART_DAHIL: 1 = ALISSART_MALIYET kolonu da hesapla (fytOzl ~21sn)
================================================================*/

USE DerinSISBkm;
SET NOCOUNT ON;

DECLARE @TARIH_ILK DATE = '27/04/2026';
DECLARE @TARIH_SON DATE = '03/05/2026';

DECLARE @DETAYGOSTER       BIT = 0;
DECLARE @OZETGOSTER        BIT = 0;
DECLARE @MAGAZAOZETGOSTER  BIT = 1;
DECLARE @DOGRULAMAGOSTER   BIT = 1;

DECLARE @MALIYETTIP        TINYINT = 0;     -- 0: 5-fat avg (final), 1: ALISSART (özet için)
DECLARE @ALISSART_DAHIL    BIT = 0;          -- 0: fytOzl atla, 1: hesapla
DECLARE @MALIYET_LOOKBACK_AY TINYINT = 12;
DECLARE @LOOKBACK_DATE     DATE = DATEADD(MONTH, -@MALIYET_LOOKBACK_AY, @TARIH_ILK);
DECLARE @FUTURE_LOOKAHEAD_AY TINYINT = 6;    -- gelecek fatura proxy için ileri bak
DECLARE @FUTURE_DATE       DATE = DATEADD(MONTH, @FUTURE_LOOKAHEAD_AY, @TARIH_SON);


-- ================================================================
-- ADIM 1: Satılan ürünler (PK)
-- ================================================================
IF OBJECT_ID('tempdb..#SATILAN_URUN') IS NOT NULL DROP TABLE #SATILAN_URUN;
CREATE TABLE #SATILAN_URUN (stkId INT NOT NULL PRIMARY KEY);

INSERT INTO #SATILAN_URUN(stkId)
SELECT DISTINCT ia.ehStkID
FROM dbo.irs irs WITH (NOLOCK)
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
-- ADIM 1B: ÖN-TEMP — fat alış başlık (geçmiş + gelecek aralığı dahil)
--   Geçmişte: 5-fat avg için (lookback)
--   Gelecekte: SONRAKI proxy için (lookahead)
--   Tek scan ile fat tablosunu küçültürüyoruz.
-- ================================================================
IF OBJECT_ID('tempdb..#FAT_HEADER') IS NOT NULL DROP TABLE #FAT_HEADER;
CREATE TABLE #FAT_HEADER (
    eID    INT  NOT NULL PRIMARY KEY,
    eTarih DATE NOT NULL,
    eFirma INT  NOT NULL
);

INSERT INTO #FAT_HEADER(eID, eTarih, eFirma)
SELECT f.eID, f.eTarih, f.eFirma
FROM dbo.fat f WITH (NOLOCK)
WHERE f.eTip   = 0
  AND f.eDurum <> 2
  AND f.eTarih >= @LOOKBACK_DATE
  AND f.eTarih <= @FUTURE_DATE
  AND (f.eFirma <> 9525 OR (f.eFirma = 9525 AND f.eTarih >= '01/09/2022'));

CREATE NONCLUSTERED INDEX IX_FAT_HEADER_eTarih ON #FAT_HEADER (eTarih) INCLUDE (eFirma);


-- ================================================================
-- ADIM 2: 5-FAT AVG (geçmiş) — DerinSIS fat
-- ================================================================
IF OBJECT_ID('tempdb..#FAT_PAST') IS NOT NULL DROP TABLE #FAT_PAST;
CREATE TABLE #FAT_PAST (
    stkId    INT           NOT NULL,
    eTarih   DATE          NOT NULL,
    ehAdetN  DECIMAL(18,3) NOT NULL,
    ehTutarN DECIMAL(18,4) NOT NULL
);

INSERT INTO #FAT_PAST(stkId, eTarih, ehAdetN, ehTutarN)
SELECT s.stkId, b.eTarih, b.ehAdetN, b.ehTutarN
FROM #SATILAN_URUN s
CROSS APPLY (
    SELECT TOP 5 fa.ehAdetN, fa.ehTutarN, fh.eTarih
    FROM dbo.fatAyr fa WITH (NOLOCK)
    INNER JOIN #FAT_HEADER fh ON fh.eID = fa.ehID
    WHERE fa.ehStkID = s.stkId
      AND fa.ehAdetN <> 0
      AND fh.eTarih <= @TARIH_SON
      AND fh.eTarih >= @LOOKBACK_DATE
    ORDER BY fh.eTarih DESC
) b;

CREATE NONCLUSTERED INDEX IX_FAT_PAST_stk ON #FAT_PAST (stkId);


-- ================================================================
-- ADIM 3: ODAK_FATURA fallback (DerinSIS'te yoksa)
-- ================================================================
IF OBJECT_ID('tempdb..#ODAK_PAST') IS NOT NULL DROP TABLE #ODAK_PAST;
CREATE TABLE #ODAK_PAST (
    stkId INT           NOT NULL,
    Tarih DATE          NOT NULL,
    ADET  DECIMAL(18,3) NOT NULL,
    TUTAR DECIMAL(18,4) NOT NULL
);

INSERT INTO #ODAK_PAST(stkId, Tarih, ADET, TUTAR)
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
WHERE NOT EXISTS (SELECT 1 FROM #FAT_PAST fr WHERE fr.stkId = s.stkId);

CREATE NONCLUSTERED INDEX IX_ODAK_PAST_stk ON #ODAK_PAST (stkId);


-- ================================================================
-- ADIM 4: 5-FAT AVG ORTALAMA (Fallback 1)
-- ================================================================
IF OBJECT_ID('tempdb..#MALIYET_AVG') IS NOT NULL DROP TABLE #MALIYET_AVG;
CREATE TABLE #MALIYET_AVG (
    stkID   INT           NOT NULL PRIMARY KEY,
    MALIYET DECIMAL(18,4)
);

;WITH BIRLESIK AS (
    SELECT stkId, ehAdetN AS adet, ehTutarN AS tutar FROM #FAT_PAST
    UNION ALL
    SELECT stkId, ADET, TUTAR FROM #ODAK_PAST
)
INSERT INTO #MALIYET_AVG(stkID, MALIYET)
SELECT stkId,
       CONVERT(MONEY, SUM(tutar) / NULLIF(SUM(adet), 0))
FROM BIRLESIK
GROUP BY stkId
HAVING SUM(adet) <> 0;


-- ================================================================
-- ADIM 5: GELECEK İLK FATURA (Fallback 3 — SONRAKI)
--   Yeni ürünler için: alış henüz olmadıysa, ileride gelen ilk
--   fatura birim fiyatı proxy olarak kullanılır.
-- ================================================================
IF OBJECT_ID('tempdb..#FAT_FUTURE') IS NOT NULL DROP TABLE #FAT_FUTURE;
CREATE TABLE #FAT_FUTURE (
    stkId   INT           NOT NULL PRIMARY KEY,
    MALIYET DECIMAL(18,4)
);

INSERT INTO #FAT_FUTURE(stkId, MALIYET)
SELECT s.stkId, b.MALIYET
FROM #SATILAN_URUN s
CROSS APPLY (
    SELECT TOP 1 MALIYET
    FROM (
        SELECT TOP 1 fh.eTarih AS Tarih, fa.ehTutarN / NULLIF(fa.ehAdetN, 0) AS MALIYET
        FROM dbo.fatAyr fa WITH (NOLOCK)
        INNER JOIN #FAT_HEADER fh ON fh.eID = fa.ehID
        WHERE fa.ehStkID = s.stkId
          AND fa.ehAdetN <> 0
          AND fh.eTarih > @TARIH_SON
          AND fh.eTarih <= @FUTURE_DATE
        ORDER BY fh.eTarih

        UNION ALL

        SELECT TOP 1 f.TARIH, f.NET
        FROM BKMDATA..ODAK_FATURA f WITH (NOLOCK)
        WHERE f.STKID = s.stkId AND f.TARIH > @TARIH_SON
        ORDER BY f.TARIH
    ) X
    ORDER BY Tarih
) b
WHERE NOT EXISTS (SELECT 1 FROM #MALIYET_AVG ma WHERE ma.stkID = s.stkId)
  AND NOT EXISTS (
      SELECT 1 FROM Aktarim.dbo.BKM_STOKLAR_MALIYETLI akm WITH (NOLOCK)
      WHERE akm.STKID = s.stkId AND akm.ORT_ALIS IS NOT NULL
  );


-- ================================================================
-- ADIM 6: ALISSART (opsiyonel, AYRI KOLON — final hesaba girmez)
-- ================================================================
IF OBJECT_ID('tempdb..#ALISSART') IS NOT NULL DROP TABLE #ALISSART;
CREATE TABLE #ALISSART (
    stkId         INT           NOT NULL PRIMARY KEY,
    BrutAlisFiyat DECIMAL(18,4),
    NetAlisFiyat  DECIMAL(18,4)
);

IF @ALISSART_DAHIL = 1
BEGIN
    INSERT INTO #ALISSART(stkId, BrutAlisFiyat, NetAlisFiyat)
    SELECT a.fStkID,
           a.sonrakiFiyat,
           a.sonrakiFiyat
           * (1 - a.fInd1/100.0) * (1 - a.fInd2/100.0) * (1 - a.fInd3/100.0)
           * (1 - a.fInd4/100.0) * (1 - a.fInd5/100.0)
    FROM (
        SELECT u.stkID AS fStkID, fy.sonrakiFiyat,
               fy.fInd1, fy.fInd2, fy.fInd3, fy.fInd4, fy.fInd5,
               ROW_NUMBER() OVER (PARTITION BY fy.fStkID ORDER BY fy.fTarihSon DESC) AS sno
        FROM dbo.urn u WITH (NOLOCK)
        INNER JOIN dbo.fytOzl fy WITH (NOLOCK)
            ON fy.fStkID = u.stkID
           AND fy.fFrmID IN (0, u.stkFirma)
           AND fy.fTur = 1 AND fy.fTip = 1
        WHERE u.stkID IN (SELECT stkId FROM #SATILAN_URUN)
    ) a
    WHERE a.sno = 1;
END


-- ================================================================
-- ADIM 7: SATIS ham (irs+irsAyr+fat+fatAyr birleşim, SatisTip kanal)
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
  )
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
-- ADIM 8: #MALIYET final — PROD PARITE FALLBACK ZİNCİRİ
--   1) MA   = #MALIYET_AVG (5-fat avg)
--   2) AKM  = Aktarim.ORT_ALIS
--   3) FUT  = #FAT_FUTURE (gelecek ilk fatura)
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
       COALESCE(MA.MALIYET, AKM.ORT_ALIS, FUT.MALIYET) * s.adet
FROM #SATIS_RAW s
LEFT JOIN #MALIYET_AVG MA  ON MA.stkID  = s.stkId
LEFT JOIN Aktarim.dbo.BKM_STOKLAR_MALIYETLI AKM
        WITH (NOLOCK)      ON AKM.STKID = s.stkId
LEFT JOIN #FAT_FUTURE FUT  ON FUT.stkId = s.stkId;

CREATE CLUSTERED INDEX CIX_MALIYET ON #MALIYET (tarih, mekanId, stkId);


-- ================================================================
-- ÇIKTI 1: ÜRÜN BAZLI DETAY (prod sorgudaki gibi)
-- ================================================================
IF @DETAYGOSTER = 1
BEGIN
    SELECT
        f.frmAd                                            AS lokasyonAd,
        kt.ktgrAd                                          AS Kategori,
        u.stkID, u.stkAd,
        mk.mrkAd                                           AS Marka,
        M.satisTip,
        SUM(M.adet)                                        AS Adet,
        SUM(M.tutar)                                       AS TUTAR,
        SUM(M.maliyet)                                     AS MALIYET,
        SUM(M.adet * AS_.NetAlisFiyat)                     AS ALISSART_MALIYET,
        CASE
            WHEN kt.ktgrAd = 'Tanımsız'                                                           THEN 'TANIMSIZ'
            WHEN u.stkID IN (101296,84642,59337,104965,65462,56761,64515,22390,60318,65940)         THEN 'MUHTELİF'
            WHEN ISNULL(SUM(M.maliyet),0)<>0 AND ISNULL(SUM(M.adet*AS_.NetAlisFiyat),0)<>0          THEN 'MALİYETLİ SATINALMA ŞARTLI'
            WHEN ISNULL(SUM(M.maliyet),0)<>0                                                       THEN 'MALİYETLİ SATINALMA ŞARTSIZ'
            WHEN ISNULL(SUM(M.adet*AS_.NetAlisFiyat),0)<>0                                         THEN 'MALİYETSİZ SATINALMA ŞARTLI'
            ELSE                                                                                       'MALİYETSİZ SATINALMA ŞARTSIZ'
        END                                                AS GRUP,
        SUM(M.tutar) - SUM(M.maliyet)                      AS Marj_TL
    FROM #MALIYET M
    INNER JOIN dbo.urn       u  WITH (NOLOCK) ON u.stkID   = M.stkId
    INNER JOIN dbo.urnKtgr2  kt WITH (NOLOCK) ON kt.ktgrID = u.urnKtgr2ID
    INNER JOIN dbo.urnMrk    mk WITH (NOLOCK) ON mk.mrkID  = u.urnMrkID
    INNER JOIN dbo.frm       f  WITH (NOLOCK) ON f.frmID   = M.mekanId
    LEFT  JOIN #ALISSART     AS_                          ON AS_.stkId = M.stkId
    GROUP BY f.frmAd, kt.ktgrAd, u.stkID, u.stkAd, mk.mrkAd, M.satisTip
    ORDER BY SUM(M.tutar) DESC;
END


-- ================================================================
-- ÇIKTI 2: MALİYETLİ/SİZ ÖZET
-- ================================================================
IF @OZETGOSTER = 1
BEGIN
    ;WITH OZET AS (
        SELECT
            f.frmAd lokasyonAd, kt.ktgrAd Kategori, mk.mrkAd Marka, M.satisTip,
            CASE
                WHEN kt.ktgrAd = 'Tanımsız'                                                       THEN 'TANIMSIZ'
                WHEN u.stkID IN (101296,84642,59337,104965,65462,56761,64515,22390,60318,65940)     THEN 'MUHTELİF'
                WHEN ISNULL(SUM(IIF(@MALIYETTIP=0, M.maliyet, M.adet*AS_.NetAlisFiyat)),0)<>0       THEN 'MALİYETLİ'
                ELSE                                                                                   'MALİYETSİZ'
            END                                                              AS GRUP,
            SUM(M.adet)                                                      AS SATIS_ADET,
            SUM(M.tutar)                                                     AS SATIS_TUTAR,
            SUM(IIF(@MALIYETTIP=0, M.maliyet, M.adet*AS_.NetAlisFiyat))      AS MALIYET
        FROM #MALIYET M
        INNER JOIN dbo.urn       u  WITH (NOLOCK) ON u.stkID   = M.stkId
        INNER JOIN dbo.urnKtgr2  kt WITH (NOLOCK) ON kt.ktgrID = u.urnKtgr2ID
        INNER JOIN dbo.urnMrk    mk WITH (NOLOCK) ON mk.mrkID  = u.urnMrkID
        INNER JOIN dbo.frm       f  WITH (NOLOCK) ON f.frmID   = M.mekanId
        LEFT  JOIN #ALISSART     AS_                          ON AS_.stkId = M.stkId
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
-- ÇIKTI 3: MAĞAZA × KATEGORİ × KANAL + ROLLUP
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
            SUM(M.maliyet)                                AS Maliyet,
            GROUPING(f.frmAd)                             AS gMagaza,
            GROUPING(kt.ktgrAd)                           AS gKategori
        FROM #MALIYET M
        INNER JOIN dbo.urn       u  WITH (NOLOCK) ON u.stkID   = M.stkId
        INNER JOIN dbo.urnKtgr2  kt WITH (NOLOCK) ON kt.ktgrID = u.urnKtgr2ID
        INNER JOIN dbo.frm       f  WITH (NOLOCK) ON f.frmID   = M.mekanId
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
-- ÇIKTI 4: DOĞRULAMA — Kapsam metrikleri
-- ================================================================
IF @DOGRULAMAGOSTER = 1
BEGIN
    SELECT 'Satılan Ürün'                       AS Metrik, COUNT(*)   AS Sayi FROM #SATILAN_URUN
    UNION ALL SELECT 'Fat header (lookback+ahead)',         COUNT(*) FROM #FAT_HEADER
    UNION ALL SELECT 'Fat past (5x stkID)',                 COUNT(*) FROM #FAT_PAST
    UNION ALL SELECT 'Odak past (fallback)',                COUNT(*) FROM #ODAK_PAST
    UNION ALL SELECT 'Maliyet AVG (Fallback 1)',            COUNT(*) FROM #MALIYET_AVG
    UNION ALL SELECT 'Fat future (Fallback 3)',             COUNT(*) FROM #FAT_FUTURE
    UNION ALL SELECT 'ALISSART (rapor için)',               COUNT(*) FROM #ALISSART
    UNION ALL SELECT 'SATIS ham',                           COUNT(*) FROM #SATIS_RAW
    UNION ALL SELECT 'MALIYET final',                       COUNT(*) FROM #MALIYET
    UNION ALL SELECT 'Toplam Tutar (TL)',                   CAST(SUM(tutar) AS BIGINT)  FROM #MALIYET
    UNION ALL SELECT 'Toplam Maliyet (TL)',                 CAST(SUM(maliyet) AS BIGINT) FROM #MALIYET
    UNION ALL SELECT 'Maliyetsiz Satır',
                     SUM(CASE WHEN maliyet IS NULL OR maliyet = 0 THEN 1 ELSE 0 END) FROM #MALIYET;
END


-- =============== TEMİZLİK ===============
DROP TABLE #SATILAN_URUN;
DROP TABLE #FAT_HEADER;
DROP TABLE #FAT_PAST;
DROP TABLE #ODAK_PAST;
DROP TABLE #MALIYET_AVG;
DROP TABLE #FAT_FUTURE;
DROP TABLE #ALISSART;
DROP TABLE #SATIS_RAW;
DROP TABLE #MALIYET;
