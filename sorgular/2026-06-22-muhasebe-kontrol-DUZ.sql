/* =====================================================================================
   Kapanış/Geçmiş-Dönem Müdahale Kontrolü — DÜZ KOD (SP'den ÖNCE kontrol için)
   -------------------------------------------------------------------------------------
   Aşağıdaki @parametreleri değiştir, F5. Sonuç doğruysa SP'ye sararız.
   Kaynaklar doğrulandı (2025-05 kapanmış ay): CAR=4, FAT=8, MHS=129 değişen/109 giren.
   Join doğrulandı: mhsFis.fisID = mhsFisBaslik.fisbID (+fisSirketID) → fiş başına 2 satır (B/A).
   ===================================================================================== */

DECLARE @Yil          int          = 2025;     -- NULL + @Ay NULL = TÜM kapanmış dönemler
DECLARE @Ay           tinyint      = 5;        -- kapanmış ay (Fin_AyKapanis'te olmalı)
DECLARE @Kaynak       varchar(10)  = 'HEPSI';  -- CAR | FAT | MHS | HEPSI
DECLARE @SadeceGider  bit          = 1;        -- 1: CAR/FAT G-% ; MHS 6xx/7xx
DECLARE @Mod          varchar(6)   = 'OZET';   -- OZET | DETAY
DECLARE @Top          int          = 5000;

/* Hedef kapanmış dönem(ler) */
DECLARE @Donemler TABLE (DonemYil int, DonemAy tinyint, KapanisDT datetime2(0));
INSERT INTO @Donemler
SELECT DonemYil, DonemAy, KapanisDT FROM bkm.Fin_AyKapanis
WHERE (@Yil IS NULL OR DonemYil=@Yil) AND (@Ay IS NULL OR DonemAy=@Ay);

IF NOT EXISTS (SELECT 1 FROM @Donemler)
BEGIN RAISERROR(N'Kapanış dönemi yok (bkm.Fin_AyKapanis). 2026 ayları eksik olabilir.',16,1); RETURN; END;

/* Ortak ham hareket havuzu */
IF OBJECT_ID('tempdb..#H') IS NOT NULL DROP TABLE #H;
CREATE TABLE #H (
    Kaynak varchar(6), EvrakID bigint, EvrakNo varchar(50), Donem char(7),
    BelgeDT datetime2(0), KapanisDT datetime2(0), GirisDT datetime2(0), DegisimDT datetime2(0),
    GecGiris bit, SonradanDeg bit, GunSonra int,
    GiderKod varchar(50), GiderAd nvarchar(200), KarsiKod varchar(50),
    KisiGiren int, KisiOnay int, Tutar decimal(18,2), Notu nvarchar(400)
);

/* ---- CAR ---- */
IF @Kaynak IN ('CAR','HEPSI')
INSERT INTO #H
SELECT 'CAR', CAST(c.cID AS bigint), CAST(c.cEvrakNo AS varchar(50)),
    RIGHT('0'+CAST(d.DonemAy AS varchar(2)),2)+'.'+CAST(d.DonemYil AS varchar(4)),
    CAST(c.cTarih AS datetime2(0)), d.KapanisDT,
    CAST(ISNULL(c.cgTarih,c.cTarih) AS datetime2(0)),
    CAST(ISNULL(c.ckTarih,ISNULL(c.cgTarih,c.cTarih)) AS datetime2(0)),
    CASE WHEN ISNULL(c.cgTarih,c.cTarih)>d.KapanisDT THEN 1 ELSE 0 END,
    CASE WHEN ISNULL(c.ckTarih,ISNULL(c.cgTarih,c.cTarih))>d.KapanisDT THEN 1 ELSE 0 END,
    DATEDIFF(DAY,d.KapanisDT,ISNULL(c.ckTarih,ISNULL(c.cgTarih,c.cTarih))),
    CASE WHEN f1.frmKod LIKE 'G-%' THEN f1.frmKod WHEN f2.frmKod LIKE 'G-%' THEN f2.frmKod ELSE f1.frmKod END,
    CASE WHEN f1.frmKod LIKE 'G-%' THEN f1.frmAd  WHEN f2.frmKod LIKE 'G-%' THEN f2.frmAd  ELSE f1.frmAd  END,
    f2.frmKod, c.cgKisi, c.coKisi, CAST(c.cTutar AS decimal(18,2)), c.cNot
FROM dbo.car c
JOIN @Donemler d ON d.DonemYil=YEAR(c.cTarih) AND d.DonemAy=MONTH(c.cTarih)
LEFT JOIN dbo.frm f1 ON f1.frmID=c.cKod
LEFT JOIN dbo.frm f2 ON f2.frmID=c.cKodKarsi
WHERE c.cOnay=1
  AND (ISNULL(c.cgTarih,c.cTarih)>d.KapanisDT OR ISNULL(c.ckTarih,ISNULL(c.cgTarih,c.cTarih))>d.KapanisDT)
  AND (@SadeceGider=0 OR (f1.frmKod LIKE 'G-%' OR f2.frmKod LIKE 'G-%'));

/* ---- FAT (eTip 6,7,8) ---- */
IF @Kaynak IN ('FAT','HEPSI')
INSERT INTO #H
SELECT 'FAT', CAST(f.eID AS bigint), CAST(f.eNo AS varchar(50)),
    RIGHT('0'+CAST(d.DonemAy AS varchar(2)),2)+'.'+CAST(d.DonemYil AS varchar(4)),
    CAST(f.eTarihS AS datetime2(0)), d.KapanisDT,
    CAST(ISNULL(f.gTarih,ISNULL(f.oTarih,f.eTarihS)) AS datetime2(0)),
    CAST(f.kTarih AS datetime2(0)),
    CASE WHEN ISNULL(f.gTarih,ISNULL(f.oTarih,f.eTarihS))>d.KapanisDT THEN 1 ELSE 0 END,
    CASE WHEN f.kTarih>d.KapanisDT THEN 1 ELSE 0 END,
    DATEDIFF(DAY,d.KapanisDT,f.kTarih),
    MAX(CASE WHEN u.stkKod LIKE 'G-%' THEN u.stkKod END),
    MAX(CASE WHEN u.stkKod LIKE 'G-%' THEN u.stkAd  END),
    NULL, f.gKisi, f.oKisi,
    CAST(SUM(ISNULL(a.ehTutar,0))+SUM(ISNULL(a.ehTutarKDV,0))
       - SUM(ISNULL(a.ehTutarKDVtvkft,0))-SUM(ISNULL(a.ehTutarStopaj,0)) AS decimal(18,2)),
    f.eNot
FROM dbo.fat f
JOIN @Donemler d ON d.DonemYil=YEAR(f.eTarihS) AND d.DonemAy=MONTH(f.eTarihS)
JOIN dbo.fatAyr a ON a.ehID=f.eID
LEFT JOIN dbo.urn u ON u.stkID=a.ehStkID AND u.urnTip IN (1,2)
WHERE f.eTip IN (6,7,8)
  AND (ISNULL(f.gTarih,ISNULL(f.oTarih,f.eTarihS))>d.KapanisDT OR f.kTarih>d.KapanisDT)
  AND (@SadeceGider=0 OR EXISTS (SELECT 1 FROM dbo.fatAyr a2 JOIN dbo.urn u2 ON u2.stkID=a2.ehStkID
                                 WHERE a2.ehID=f.eID AND u2.stkKod LIKE 'G-%'))
GROUP BY f.eID,f.eNo,f.eTarihS,f.gTarih,f.oTarih,f.kTarih,f.gKisi,f.oKisi,f.eNot,d.DonemYil,d.DonemAy,d.KapanisDT;

/* ---- MHS (yevmiye fişi) ---- */
IF @Kaynak IN ('MHS','HEPSI')
INSERT INTO #H
SELECT 'MHS', CAST(b.fisbID AS bigint), CAST(b.yevmiyeNo AS varchar(50)),
    RIGHT('0'+CAST(d.DonemAy AS varchar(2)),2)+'.'+CAST(d.DonemYil AS varchar(4)),
    CAST(b.fisTarih AS datetime2(0)), d.KapanisDT,
    CAST(ISNULL(b.gTarih,b.fisTarih) AS datetime2(0)),
    CAST(ISNULL(b.kTarih,ISNULL(b.gTarih,b.fisTarih)) AS datetime2(0)),
    CASE WHEN ISNULL(b.gTarih,b.fisTarih)>d.KapanisDT THEN 1 ELSE 0 END,
    CASE WHEN ISNULL(b.kTarih,ISNULL(b.gTarih,b.fisTarih))>d.KapanisDT THEN 1 ELSE 0 END,
    DATEDIFF(DAY,d.KapanisDT,ISNULL(b.kTarih,ISNULL(b.gTarih,b.fisTarih))),
    NULL, N'(yevmiye fişi)', NULL, b.gKisi, b.oKisi,
    CAST((SELECT SUM(CASE WHEN ff.fisBA=0 THEN ff.fisTutar ELSE 0 END)
          FROM mhs.mhsFis ff WHERE ff.fisID=b.fisbID AND ff.fisSirketID=b.fisbSirketID) AS decimal(18,2)),
    CAST(b.fisAd AS nvarchar(400))
FROM mhs.mhsFisBaslik b
JOIN @Donemler d ON d.DonemYil=YEAR(b.fisTarih) AND d.DonemAy=MONTH(b.fisTarih)
WHERE (ISNULL(b.gTarih,b.fisTarih)>d.KapanisDT OR ISNULL(b.kTarih,ISNULL(b.gTarih,b.fisTarih))>d.KapanisDT)
  AND (@SadeceGider=0 OR EXISTS (SELECT 1 FROM mhs.mhsFis ff JOIN mhs.mhsHsp h ON h.hspID=ff.fisHspID AND h.hspSirketID=ff.fisSirketID
                                 WHERE ff.fisID=b.fisbID AND ff.fisSirketID=b.fisbSirketID
                                   AND (h.hspKod LIKE '6%' OR h.hspKod LIKE '7%')));

/* ---- Severity + forensic + çıktı ---- */
IF OBJECT_ID('tempdb..#B') IS NOT NULL DROP TABLE #B;
SELECT *,
    Severity = CASE WHEN GecGiris=1 AND SonradanDeg=1 THEN 3 WHEN SonradanDeg=1 THEN 2 WHEN GecGiris=1 THEN 1 ELSE 0 END,
    YuvarlakTutar = CASE WHEN ABS(Tutar)>=1000 AND ABS(Tutar)%1000=0 THEN 1 ELSE 0 END,
    GirenOnaylayanAyni = CASE WHEN KisiGiren IS NOT NULL AND KisiGiren=KisiOnay THEN 1 ELSE 0 END,
    MukerrerAdet = COUNT(*) OVER (PARTITION BY Kaynak, GiderKod, ABS(Tutar), CONVERT(date,BelgeDT))
INTO #B
FROM #H;

ALTER TABLE #B ADD Mukerrer AS (CASE WHEN MukerrerAdet>1 THEN 1 ELSE 0 END);
ALTER TABLE #B ADD RiskSkor AS (
      Severity*100
    + CASE WHEN GunSonra>90 THEN 90 WHEN GunSonra<0 THEN 0 ELSE GunSonra END
    + CASE WHEN ABS(Tutar)>=1000 AND ABS(Tutar)%1000=0 THEN 25 ELSE 0 END
    + CASE WHEN KisiGiren IS NOT NULL AND KisiGiren=KisiOnay THEN 20 ELSE 0 END
    + CASE WHEN MukerrerAdet>1 THEN 15 ELSE 0 END);

IF @Mod='DETAY'
    SELECT TOP (@Top) b.Donem, b.Kaynak, b.EvrakID, b.EvrakNo,
        BelgeTarihi=CONVERT(varchar(10),b.BelgeDT,104),
        KapanisTarihi=CONVERT(varchar(10),b.KapanisDT,104),
        DegisimTarihi=CONVERT(varchar(10),b.DegisimDT,104),
        b.GecGiris, b.SonradanDeg, b.GunSonra, b.Severity,
        b.YuvarlakTutar, b.GirenOnaylayanAyni, b.Mukerrer, b.RiskSkor,
        b.GiderKod, b.GiderAd, b.KarsiKod,
        Giren = ISNULL(dg.insAd, CAST(b.KisiGiren AS varchar(20))),
        Onaylayan = ISNULL(do.insAd, CAST(b.KisiOnay AS varchar(20))),
        b.Tutar, b.Notu
    FROM #B b
    LEFT JOIN dbo.drn1 dg ON dg.insID=b.KisiGiren   -- kişi ID → isim (drn1.insID/insAd)
    LEFT JOIN dbo.drn1 do ON do.insID=b.KisiOnay
    ORDER BY b.RiskSkor DESC, b.DegisimDT DESC, b.EvrakID DESC;
ELSE
    SELECT TOP (@Top) Donem, Kaynak, GiderKod, GiderAd,
        EvrakAdet=COUNT(*), ToplamTutar=CAST(SUM(Tutar) AS decimal(18,2)), MaxGunSonra=MAX(GunSonra),
        SonradanDegAdet=SUM(CAST(SonradanDeg AS int)), GecGirisAdet=SUM(CAST(GecGiris AS int)),
        YuvarlakAdet=SUM(YuvarlakTutar), MukerrerAdet=SUM(Mukerrer), GirenOnayAyniAdet=SUM(GirenOnaylayanAyni),
        MaxRiskSkor=MAX(RiskSkor), ToplamRiskSkor=SUM(RiskSkor)
    FROM #B GROUP BY Donem, Kaynak, GiderKod, GiderAd
    ORDER BY MAX(RiskSkor) DESC, COUNT(*) DESC;

DROP TABLE #H; DROP TABLE #B;
