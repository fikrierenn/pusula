/*================================================================
  Kitap Kâr/Zarar v3 (Prod-Grade Temelli)
  ----------------------------------------------------------------
  Yazan         : Claude (Fikri'nin paylaştığı prod sorgu temel alındı)
  Tarih         : 07.05.2026
  Plan          : plans/04-gunluk-kar-zarar-maliyet-karsilastirma.md
  Kaynak        : Fikri'nin prod kâr/zarar sorgusu + kitap+mağaza filtresi

  ÖNEMLİ DEĞİŞİKLİKLER (orijinale göre):
    - urnKtgr2 IN (2,8,15,24) kitap filtresi eklendi (KitapUrun CTE)
    - Mağaza listesi: 12,1,4477,4478 (12 = ana depo, WEB için zorunlu)
    - 4 result-set: detay + özet + mağaza×kategori + doğrulama
    - SatisTip kanal kırılımı CTE içinde (PERAKENDE/WEB/HEYKEL/ODAK/KURUMSAL)
    - 4 maliyet grubu: MALİYETLİ/MALİYETSİZ × ŞARTLI/ŞARTSIZ + TANIMSIZ + MUHTELİF

  KORUNDU (orijinalden):
    - Satış: irs+irsAyr LEFT JOIN fat+fatAyr (fatura kesildiyse fa, yoksa ia)
    - Maliyet 3 katmanlı fallback: 5-fat avg → Aktarim ortalama → gelecek proxy
    - Maliyet kaynak UNION: DerinSIS fat (eTip=0) + BKMDATA..ODAK_FATURA
    - ALISSART: fytOzl (fTur=1, fTip=1) + 5 kademeli iskonto fInd1..fInd5
    - Filtreler: irs.Neden<>243, irs.NedenAlt<>1, manuel ID exclude
    - POS özel durum: irs.eDurum=1 OR irs.eTip IN (100,101)
    - 4 maliyet grubu CASE: MALİYETLİ × ALISSART, MUHTELİF, TANIMSIZ

  KULLANIM:
    @TARIH_ILK / @TARIH_SON: aralık DAHİL
    @MALIYETTIP: 0 = son 5 fat avg, >0 = satınalma şartı (ALISSART)
    @DETAYGOSTER / @OZETGOSTER: hangi result-set görünür
    @MAGAZAOZETGOSTER: 3. result-set (mağaza × kategori × kanal özet)
    @DOGRULAMAGOSTER: 4. result-set (kapsam metrikleri)
================================================================*/

USE DerinSISBkm;
SET NOCOUNT ON;

DECLARE @TARIH_ILK DATE = '27/04/2026';
DECLARE @TARIH_SON DATE = '03/05/2026';

DECLARE @DETAYGOSTER         BIT = 0;  -- 1: ürün-bazlı detay
DECLARE @OZETGOSTER          BIT = 0;  -- 1: maliyetli/maliyetsiz dağılım
DECLARE @MAGAZAOZETGOSTER    BIT = 1;  -- 1: mağaza × kategori × kanal kâr/zarar (YENİ)
DECLARE @DOGRULAMAGOSTER     BIT = 1;  -- 1: kapsam metrikleri (YENİ)

DECLARE @MALIYETTIP TINYINT = 0;  -- 0: son 5 fatura avg, >0: satınalma şartı (ALISSART)

-- =============== KİTAP KATEGORİLERİ ===============
DECLARE @KategoriID TABLE (id TINYINT PRIMARY KEY);
INSERT INTO @KategoriID(id) VALUES (2),(8),(15),(24);
-- 2=Çocuk Kitabı, 8=Hazırlık Kitapları, 15=Kitap, 24=Akademi

-- =============== MAĞAZA ===============
DECLARE @Mekan TABLE (mekanID INT PRIMARY KEY, mekanAd VARCHAR(20));
INSERT INTO @Mekan(mekanID, mekanAd) VALUES
    (12,   'Ana Depo'),
    (1,    'FSM'),
    (4477, 'Özlüce'),
    (4478, 'İst.Yolu');

-- =============== TEMP TABLOLAR ===============
CREATE TABLE #KITAPSTK (stkID INT PRIMARY KEY);
INSERT INTO #KITAPSTK(stkID)
SELECT u.stkID FROM dbo.urn u WITH (NOLOCK)
WHERE u.urnKtgr2ID IN (SELECT id FROM @KategoriID);

CREATE TABLE #MALIYET (
    tarih       DATE          INDEX IX_M2,
    satisTip    VARCHAR(20),
    mekanId     INT,
    stkId       INT           INDEX IX_M2a,
    adet        DECIMAL(18,3),
    tutar       DECIMAL(18,4),
    maliyet     DECIMAL(18,4)
);

CREATE TABLE #ALISSART (
    stkId           INT INDEX IX_A3,
    BrutAlisFiyat   DECIMAL(18,4),
    NetAlisFiyat    DECIMAL(18,4)
);

-- =============== ALISSART (satınalma şartı, 5 kademeli iskonto) ===============
INSERT INTO #ALISSART(stkId, BrutAlisFiyat, NetAlisFiyat)
SELECT
    fStkID,
    sonrakiFiyat AS BrutAlisFiyat,
    sonrakiFiyat
        * (1 - fInd1/100.0) * (1 - fInd2/100.0) * (1 - fInd3/100.0)
        * (1 - fInd4/100.0) * (1 - fInd5/100.0)                 AS NetAlisFiyat
FROM (
    SELECT a.fStkID, sonrakiFiyat, fInd1, fInd2, fInd3, fInd4, fInd5,
           ROW_NUMBER() OVER (PARTITION BY a.fStkID ORDER BY fTarihSon DESC) AS sno
    FROM dbo.urn u WITH (NOLOCK)
    JOIN dbo.fytOzl a WITH (NOLOCK)
        ON a.fStkID = u.stkID
       AND a.fFrmID IN (0, u.stkFirma)
       AND a.fTur = 1   -- Satış Fiyatı türü (?  fTip=1 alış olabilir, kontrol edilmeli)
       AND a.fTip = 1
    WHERE u.stkID IN (SELECT stkID FROM #KITAPSTK)
) A
WHERE A.sno = 1;

-- =============== SATIS + MALİYET ===============
;WITH SATIS AS (
    SELECT
        irs.eTarih                                AS tarih,
        irs.eMekan                                AS mekanID,
        ia.ehStkID                                AS stkId,
        CASE
            WHEN irs.eID IS NULL                                    THEN 'BELİRSİZ'
            WHEN irs.eTip IN (100, 101)                             THEN 'PERAKENDE'
            WHEN ff.eTip = 4 AND ff.eFatPos = 1                     THEN 'PERAKENDE'
            WHEN ff.eTip = 1 AND ff.eMekan = 12 AND ff.Neden = 239  THEN 'WEB'
            WHEN ff.eFirma = 56                                     THEN 'HEYKEL'
            WHEN ff.eFirma = 9525                                   THEN 'ODAK'
            ELSE                                                         'KURUMSAL'
        END                                       AS SatisTip,
        -1.00 * SUM(ISNULL(fa.ehAdet, ia.ehAdet)) AS adet,
        SUM(
            CASE
                WHEN irs.eTip IN (3, 5, 101)
                    THEN -1 * ISNULL(fa.ehTutar - fa.ehIndirim, ia.ehTutar - ia.ehIndirim)
                ELSE         ISNULL(fa.ehTutar - fa.ehIndirim, ia.ehTutar - ia.ehIndirim)
            END
        )                                         AS tutar
    FROM dbo.irs irs WITH (NOLOCK)
        INNER JOIN dbo.irsAyr ia WITH (NOLOCK)
            ON ia.ehID = irs.eID
        LEFT JOIN dbo.fatAyr fa WITH (NOLOCK)
            ON fa.ehIrsID = ia.ehID AND fa.ehIrsSira = ia.ehSira
        LEFT JOIN dbo.fat ff WITH (NOLOCK)
            ON ff.eID = fa.ehID AND ff.Neden <> 243
    WHERE irs.eTip IN (1, 4, 3, 5, 100, 101)
      AND irs.eTarih BETWEEN @TARIH_ILK AND @TARIH_SON
      AND irs.Neden <> 243
      AND irs.NedenAlt <> 1
      AND irs.eMekan IN (SELECT mekanID FROM @Mekan)
      AND (irs.eDurum = 1 OR irs.eTip IN (100, 101))
      AND ia.ehStkID IN (SELECT stkID FROM #KITAPSTK)
      -- Bilinen anormal kayıt exclude (Fikri'nin sorgusundan alındı)
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
    GROUP BY
        irs.eTarih, irs.eMekan, ia.ehStkID,
        CASE
            WHEN irs.eID IS NULL                                    THEN 'BELİRSİZ'
            WHEN irs.eTip IN (100, 101)                             THEN 'PERAKENDE'
            WHEN ff.eTip = 4 AND ff.eFatPos = 1                     THEN 'PERAKENDE'
            WHEN ff.eTip = 1 AND ff.eMekan = 12 AND ff.Neden = 239  THEN 'WEB'
            WHEN ff.eFirma = 56                                     THEN 'HEYKEL'
            WHEN ff.eFirma = 9525                                   THEN 'ODAK'
            ELSE                                                         'KURUMSAL'
        END
)
INSERT INTO #MALIYET(tarih, mekanId, stkId, satisTip, adet, tutar, maliyet)
SELECT
    s.tarih, s.mekanID, s.stkId, s.satisTip, s.adet, s.tutar,
    COALESCE(MLYT.MALIYET, M.ORT_ALIS, SONRAKI.MALIYET) * s.adet AS ehMlyt
FROM SATIS s
    -- Maliyet katman 1: son 5 fatura ortalaması (DerinSIS + ODAK_FATURA UNION)
    OUTER APPLY (
        SELECT CONVERT(MONEY, SUM(b.ehTutarN) / NULLIF(SUM(b.ehAdetN), 0)) AS MALIYET
        FROM (
            SELECT TOP 5 ehAdetN, ehTutarN
            FROM (
                -- DerinSIS alış faturaları (eTip=0 cari alış)
                SELECT TOP 5 f.eTarih, fa.ehAdetN, fa.ehTutarN
                FROM dbo.fatAyr fa WITH (NOLOCK)
                INNER JOIN dbo.fat f WITH (NOLOCK)
                    ON fa.ehID = f.eID
                   AND f.eTarih <= s.tarih
                   AND f.eTip = 0
                   AND f.eDurum <> 2
                   AND (f.eFirma <> 9525 OR (f.eFirma = 9525 AND f.eTarih >= '01/09/2022'))
                WHERE fa.ehStkID = s.stkId
                  AND fa.ehAdetN <> 0
                ORDER BY f.eTarih DESC

                UNION ALL

                -- ODAK tedarikçisi (cross-DB)
                SELECT TOP 5 f.TARIH, f.ADET, f.NET * f.ADET
                FROM BKMDATA..ODAK_FATURA f WITH (NOLOCK)
                WHERE f.STKID = s.stkId
                  AND f.TARIH <= s.tarih
                ORDER BY f.TARIH DESC
            ) ML
            ORDER BY ML.eTarih DESC
        ) b
        HAVING SUM(b.ehAdetN) <> 0
    ) MLYT
    -- Maliyet katman 2: Aktarim ortalama maliyet
    LEFT JOIN Aktarim.dbo.BKM_STOKLAR_MALIYETLI M WITH (NOLOCK)
        ON M.STKID = s.stkId
    -- Maliyet katman 3: gelecek ilk fatura proxy (yeni ürünler için)
    OUTER APPLY (
        SELECT TOP 1 MALIYET
        FROM (
            SELECT TOP 1 f.eTarih, fa.ehTutarN / NULLIF(fa.ehAdetN, 0) AS MALIYET
            FROM dbo.fatAyr fa WITH (NOLOCK)
            INNER JOIN dbo.fat f WITH (NOLOCK)
                ON fa.ehID = f.eID
               AND f.eTarih > s.tarih
               AND f.eTip = 0
               AND f.eDurum <> 2
            WHERE fa.ehStkID = s.stkId AND fa.ehAdetN <> 0
            ORDER BY f.eTarih

            UNION ALL

            SELECT TOP 1 f.TARIH, f.NET
            FROM BKMDATA..ODAK_FATURA f WITH (NOLOCK)
            WHERE f.STKID = s.stkId AND f.TARIH > s.tarih
            ORDER BY f.TARIH
        ) SON_ILK
        ORDER BY eTarih
    ) SONRAKI;


-- ================================================================
-- ÇIKTI 1: ÜRÜN BAZLI DETAY (DETAYGOSTER)
-- ================================================================
IF @DETAYGOSTER = 1
BEGIN
    ;WITH VERI AS (
        SELECT
            f.frmAd                                          AS lokasyonAd,
            kt.ktgrAd                                        AS Kategori,
            mk.mrkAd                                         AS Marka,
            u.stkID, u.stkAd,
            M.satisTip,
            SUM(M.adet)                                      AS Adet,
            SUM(M.tutar)                                     AS TUTAR,
            SUM(M.maliyet)                                   AS MALIYET,
            SUM(M.adet * S.NetAlisFiyat)                     AS ALISSART_MALIYET
        FROM #MALIYET M
            JOIN dbo.urn       u  WITH (NOLOCK) ON u.stkID  = M.stkId
            JOIN dbo.urnKtgr2  kt WITH (NOLOCK) ON kt.ktgrID = u.urnKtgr2ID
            JOIN dbo.urnMrk    mk WITH (NOLOCK) ON mk.mrkID  = u.urnMrkID
            JOIN dbo.frm       f  WITH (NOLOCK) ON f.frmID   = M.mekanId
            LEFT JOIN #ALISSART S WITH (NOLOCK) ON S.stkId   = M.stkId
        GROUP BY f.frmAd, kt.ktgrAd, u.stkID, u.stkAd, mk.mrkAd, M.satisTip
    )
    SELECT
        V.*,
        CASE
            WHEN Kategori = 'Tanımsız'                                                THEN 'TANIMSIZ'
            WHEN stkID IN (101296,84642,59337,104965,65462,56761,64515,22390,60318,65940) THEN 'MUHTELİF'
            WHEN ISNULL(MALIYET,0) <> 0 AND ISNULL(ALISSART_MALIYET,0) <> 0           THEN 'MALİYETLİ SATINALMA ŞARTLI'
            WHEN ISNULL(MALIYET,0) <> 0 AND ISNULL(ALISSART_MALIYET,0) =  0           THEN 'MALİYETLİ SATINALMA ŞARTSIZ'
            WHEN ISNULL(MALIYET,0) =  0 AND ISNULL(ALISSART_MALIYET,0) <> 0           THEN 'MALİYETSİZ SATINALMA ŞARTLI'
            ELSE                                                                          'MALİYETSİZ SATINALMA ŞARTSIZ'
        END AS GRUP,
        TUTAR - MALIYET AS Marj_TL
    FROM VERI V
    ORDER BY V.TUTAR DESC;
END

-- ================================================================
-- ÇIKTI 2: ÖZET — Lokasyon × Kategori × Marka × Kanal MALİYETLİ/SİZ
-- ================================================================
IF @OZETGOSTER = 1
BEGIN
    ;WITH VERI AS (
        SELECT
            f.frmAd                                                          AS lokasyonAd,
            kt.ktgrAd                                                        AS Kategori,
            u.stkID, u.stkAd, mk.mrkAd                                       AS Marka,
            M.satisTip,
            SUM(M.adet)                                                      AS Adet,
            SUM(M.tutar)                                                     AS TUTAR,
            SUM(IIF(@MALIYETTIP = 0, M.maliyet, M.adet * S.NetAlisFiyat))    AS MALIYET
        FROM #MALIYET M
            JOIN dbo.urn       u  WITH (NOLOCK) ON u.stkID   = M.stkId
            JOIN dbo.urnKtgr2  kt WITH (NOLOCK) ON kt.ktgrID = u.urnKtgr2ID
            JOIN dbo.urnMrk    mk WITH (NOLOCK) ON mk.mrkID  = u.urnMrkID
            JOIN dbo.frm       f  WITH (NOLOCK) ON f.frmID   = M.mekanId
            LEFT JOIN #ALISSART S WITH (NOLOCK) ON S.stkId   = M.stkId
        GROUP BY f.frmAd, kt.ktgrAd, u.stkID, u.stkAd, mk.mrkAd, M.satisTip
    ),
    OZET AS (
        SELECT V.lokasyonAd, V.Kategori, V.Marka, V.satisTip,
            CASE
                WHEN Kategori = 'Tanımsız'                                                  THEN 'TANIMSIZ'
                WHEN stkID IN (101296,84642,59337,104965,65462,56761,64515,22390,60318,65940) THEN 'MUHTELİF'
                WHEN ISNULL(MALIYET,0) <> 0                                                 THEN 'MALİYETLİ'
                ELSE                                                                            'MALİYETSİZ'
            END AS GRUP,
            V.Adet AS SATIS_ADET, V.TUTAR AS SATIS_TUTAR, V.MALIYET AS MALIYET
        FROM VERI V
    )
    SELECT
        O.lokasyonAd, O.Kategori, O.Marka, O.satisTip,
        SUM(IIF(O.GRUP = 'MALİYETLİ',  O.SATIS_TUTAR, 0)) AS [MALİYETLİ_SATIS],
        SUM(IIF(O.GRUP = 'MALİYETLİ',  O.MALIYET,     0)) AS [MALİYETLİ_SATIS_SMM],
        SUM(IIF(O.GRUP = 'MALİYETSİZ', O.SATIS_TUTAR, 0)) AS [MALİYETSİZ_SATIS],
        SUM(IIF(O.GRUP = 'TANIMSIZ',   O.SATIS_TUTAR, 0)) AS [TANIMSIZ_SATIS],
        SUM(IIF(O.GRUP = 'MUHTELİF',   O.SATIS_TUTAR, 0)) AS [MUHTELIF_SATIS]
    FROM OZET O
    GROUP BY O.lokasyonAd, O.Kategori, O.Marka, O.satisTip;
END

-- ================================================================
-- ÇIKTI 3: MAĞAZA × KATEGORİ × KANAL KÂR/ZARAR (YENİ)
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
        CAST(SUM(IIF(@MALIYETTIP = 0, M.maliyet, M.adet * S.NetAlisFiyat)) AS DECIMAL(18,2)) AS Maliyet,
        CAST(SUM(M.tutar) - SUM(IIF(@MALIYETTIP = 0, M.maliyet, M.adet * S.NetAlisFiyat)) AS DECIMAL(18,2)) AS Marj_TL,
        CAST(
            (SUM(M.tutar) - SUM(IIF(@MALIYETTIP = 0, M.maliyet, M.adet * S.NetAlisFiyat)))
            * 100.0 / NULLIF(SUM(M.tutar), 0)
        AS DECIMAL(8,2))                              AS Marj_Yuzde
    FROM #MALIYET M
        JOIN dbo.urn       u  WITH (NOLOCK) ON u.stkID   = M.stkId
        JOIN dbo.urnKtgr2  kt WITH (NOLOCK) ON kt.ktgrID = u.urnKtgr2ID
        JOIN dbo.frm       f  WITH (NOLOCK) ON f.frmID   = M.mekanId
        LEFT JOIN #ALISSART S WITH (NOLOCK) ON S.stkId   = M.stkId
    GROUP BY f.frmAd, kt.ktgrAd, M.satisTip
    ORDER BY f.frmAd, SUM(M.tutar) DESC;
END

-- ================================================================
-- ÇIKTI 4: DOĞRULAMA — Kapsam metrikleri (YENİ)
-- ================================================================
IF @DOGRULAMAGOSTER = 1
BEGIN
    SELECT
        'Toplam'                                     AS Metrik,
        COUNT(*)                                     AS Satir,
        COUNT(DISTINCT stkId)                        AS UrunCesidi,
        CAST(SUM(adet)   AS DECIMAL(18,2))           AS Adet,
        CAST(SUM(tutar)  AS DECIMAL(18,2))           AS Tutar,
        CAST(SUM(maliyet) AS DECIMAL(18,2))          AS Maliyet5Fat,
        SUM(IIF(maliyet IS NULL OR maliyet = 0, 1, 0)) AS Maliyetsiz_Satir
    FROM #MALIYET

    UNION ALL

    SELECT
        'Kanal: ' + satisTip,
        COUNT(*),
        COUNT(DISTINCT stkId),
        CAST(SUM(adet)   AS DECIMAL(18,2)),
        CAST(SUM(tutar)  AS DECIMAL(18,2)),
        CAST(SUM(maliyet) AS DECIMAL(18,2)),
        SUM(IIF(maliyet IS NULL OR maliyet = 0, 1, 0))
    FROM #MALIYET
    GROUP BY satisTip

    UNION ALL

    SELECT
        'ALISSART: ' + CASE WHEN S.stkId IS NOT NULL THEN 'Şartlı' ELSE 'Şartsız' END,
        COUNT(*),
        COUNT(DISTINCT M.stkId),
        CAST(SUM(M.adet)    AS DECIMAL(18,2)),
        CAST(SUM(M.tutar)   AS DECIMAL(18,2)),
        CAST(SUM(M.maliyet) AS DECIMAL(18,2)),
        SUM(IIF(M.maliyet IS NULL OR M.maliyet = 0, 1, 0))
    FROM #MALIYET M
        LEFT JOIN #ALISSART S WITH (NOLOCK) ON S.stkId = M.stkId
    GROUP BY CASE WHEN S.stkId IS NOT NULL THEN 'Şartlı' ELSE 'Şartsız' END;
END

-- =============== TEMİZLİK ===============
DROP TABLE #MALIYET;
DROP TABLE #ALISSART;
DROP TABLE #KITAPSTK;
