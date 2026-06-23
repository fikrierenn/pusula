/* =====================================================================================
   bkm.sp_KapanisMudahaleKontrol_v2  —  Kapanış/Geçmiş-Dönem Müdahale Kontrolü (GELİŞTİRİLMİŞ)
   -------------------------------------------------------------------------------------
   Fikri'nin 3 SP'sini TEK parametrik motora konsolide eder + 4 geliştirme:
     (eski) sp_AyKapanisSonrasiEvrakKontrol / sp_AylikKapanisSonrasiMudahaleKontrol
            / sp_AylikGecmisDonemDegisimKontrol
     1) ÖZET + SKOR  : @Mod='OZET' → dönem×kaynak×gider×kişi (adet/tutar/maxgün/severity)
     2) TÜM-DÖNEM    : @Yil=NULL, @Ay=NULL → Fin_AyKapanis'teki TÜM kapanmış aylar
     3) FORENSIC     : round-number, mükerrer, giren=onaylayan (ISA 240 A43 esinli)
     4) MHS KAPSAMI  : car/fat'a ek yevmiye fişi (mhs.mhsFisBaslik) kapanış-sonrası

   KAYNAKLAR (@Kaynak): 'CAR' | 'FAT' | 'MHS' | 'HEPSI'
     CAR : dbo.car         (cTarih belge / cgTarih giriş / ckTarih değişim, cOnay=1)
     FAT : dbo.fat eTip IN (6,7,8) gider/masraf faturası (+ fatAyr tutar)
     MHS : mhs.mhsFisBaslik yevmiye (fisTarih belge / gTarih giriş / kTarih değişim)

   GİDER FİLTRESİ (@SadeceGider=1):
     CAR/FAT → frmKod / urn.stkKod LIKE 'G-%'  (Fikri konvansiyonu)
     MHS     → fiş satırında 6xx/7xx (gelir tablosu / maliyet) hesabı var
   MÜDAHALE TANIMI: giriş VEYA değişim tarihi, ait olduğu ayın KapanisDT'sinden SONRA.

   NOT: salt-okuma rapor SP'si. Mevcut 3 SP'ye DOKUNULMAZ (v2 ayrı isim).
        Kapanış tarihleri bkm.Fin_AyKapanis'ten okunur — 2026 ayları GİRİLMEDEN 2026 boş döner.
   Tarih: 2026-06-22 · DMY (CONVERT 104). Doğrulama: May'25 kapanış-sonrası mhsFis 129 (canlı).
   ===================================================================================== */
CREATE OR ALTER PROCEDURE bkm.sp_KapanisMudahaleKontrol_v2
(
    @Yil          int          = NULL,      -- NULL + @Ay NULL = tüm kapanmış dönemler
    @Ay           tinyint      = NULL,
    @Kaynak       varchar(10)  = 'HEPSI',   -- CAR | FAT | MHS | HEPSI
    @SadeceGider  bit          = 1,
    @Mod          varchar(6)   = 'OZET',    -- OZET | DETAY
    @GiderKod     varchar(50)  = NULL,      -- DRILL: özet satırına tıklayınca o gider koduyla DETAY çağrılır
    @Top          int          = 5000
)
AS
BEGIN
    SET NOCOUNT ON;

    /* Hedef dönem(ler): tek ay verildiyse onu, yoksa Fin_AyKapanis'teki tüm kapanmış ayları al. */
    -- AyBas/AySon: SARGABLE tarih-aralığı (YEAR/MONTH join non-sargable → index boşa, full scan). Range → index seek.
    DECLARE @Donemler TABLE (DonemYil int, DonemAy tinyint, KapanisDT datetime2(0), AyBas date, AySon date);
    INSERT INTO @Donemler (DonemYil, DonemAy, KapanisDT, AyBas, AySon)
    SELECT k.DonemYil, k.DonemAy, k.KapanisDT,
           DATEFROMPARTS(k.DonemYil, k.DonemAy, 1),
           DATEADD(MONTH, 1, DATEFROMPARTS(k.DonemYil, k.DonemAy, 1))
    FROM bkm.Fin_AyKapanis k
    WHERE (@Yil IS NULL OR k.DonemYil = @Yil)
      AND (@Ay  IS NULL OR k.DonemAy  = @Ay);

    IF NOT EXISTS (SELECT 1 FROM @Donemler)
    BEGIN
        RAISERROR(N'Kapanış dönemi bulunamadı. bkm.Fin_AyKapanis''e ilgili ay(lar)ı girin (örn. 2026 ayları eksik).',16,1);
        RETURN;
    END;

    /* ---- Ortak ham hareket havuzu (kaynak-bağımsız kolon şeması) ---- */
    CREATE TABLE #H (
        Kaynak       varchar(6),
        EvrakID      bigint,
        EvrakNo      varchar(50),
        Donem        char(7),              -- AA.YYYY
        BelgeDT      datetime2(0),
        KapanisDT    datetime2(0),
        GirisDT      datetime2(0),
        DegisimDT    datetime2(0),
        GecGiris     bit,
        SonradanDeg  bit,
        GunSonra     int,                  -- DegisimDT - KapanisDT (gün)
        GiderKod     varchar(50),
        GiderAd      nvarchar(200),
        KarsiKod     varchar(50),
        KisiGiren    int,
        KisiOnay     int,
        Tutar        decimal(18,2),
        Notu         nvarchar(400)
    );

    /* ===================== CAR ===================== */
    IF @Kaynak IN ('CAR','HEPSI')
    INSERT INTO #H
    SELECT
        'CAR', CAST(c.cID AS bigint), CAST(c.cEvrakNo AS varchar(50)),
        RIGHT('0'+CAST(d.DonemAy AS varchar(2)),2)+'.'+CAST(d.DonemYil AS varchar(4)),
        CAST(c.cTarih AS datetime2(0)),
        d.KapanisDT,
        CAST(ISNULL(c.cgTarih, c.cTarih) AS datetime2(0)),
        CAST(ISNULL(c.ckTarih, ISNULL(c.cgTarih, c.cTarih)) AS datetime2(0)),
        CASE WHEN ISNULL(c.cgTarih,c.cTarih) > d.KapanisDT THEN 1 ELSE 0 END,
        CASE WHEN ISNULL(c.ckTarih,ISNULL(c.cgTarih,c.cTarih)) > d.KapanisDT THEN 1 ELSE 0 END,
        DATEDIFF(DAY, d.KapanisDT, ISNULL(c.ckTarih,ISNULL(c.cgTarih,c.cTarih))),
        CASE WHEN f1.frmKod LIKE 'G-%' THEN f1.frmKod WHEN f2.frmKod LIKE 'G-%' THEN f2.frmKod ELSE f1.frmKod END,
        CASE WHEN f1.frmKod LIKE 'G-%' THEN f1.frmAd  WHEN f2.frmKod LIKE 'G-%' THEN f2.frmAd  ELSE f1.frmAd  END,
        f2.frmKod, c.cgKisi, c.coKisi,
        CAST(c.cTutar AS decimal(18,2)), c.cNot
    FROM dbo.car c
    JOIN @Donemler d ON c.cTarih >= d.AyBas AND c.cTarih < d.AySon   -- sargable (IX_car_cTarih seek)
    LEFT JOIN dbo.frm f1 ON f1.frmID = c.cKod
    LEFT JOIN dbo.frm f2 ON f2.frmID = c.cKodKarsi
    WHERE c.cOnay = 1
      AND (ISNULL(c.cgTarih,c.cTarih) > d.KapanisDT
        OR ISNULL(c.ckTarih,ISNULL(c.cgTarih,c.cTarih)) > d.KapanisDT)     -- kapanış sonrası dokunma
      AND (@SadeceGider = 0 OR (f1.frmKod LIKE 'G-%' OR f2.frmKod LIKE 'G-%'));

    /* ===================== FAT (gider/masraf faturası eTip 6,7,8) ===================== */
    IF @Kaynak IN ('FAT','HEPSI')
    INSERT INTO #H
    SELECT
        'FAT', CAST(f.eID AS bigint), CAST(f.eNo AS varchar(50)),
        RIGHT('0'+CAST(d.DonemAy AS varchar(2)),2)+'.'+CAST(d.DonemYil AS varchar(4)),
        CAST(f.eTarihS AS datetime2(0)),
        d.KapanisDT,
        CAST(ISNULL(f.gTarih, ISNULL(f.oTarih, f.eTarihS)) AS datetime2(0)),
        CAST(f.kTarih AS datetime2(0)),
        CASE WHEN ISNULL(f.gTarih,ISNULL(f.oTarih,f.eTarihS)) > d.KapanisDT THEN 1 ELSE 0 END,
        CASE WHEN f.kTarih > d.KapanisDT THEN 1 ELSE 0 END,
        DATEDIFF(DAY, d.KapanisDT, f.kTarih),
        MAX(CASE WHEN u.stkKod LIKE 'G-%' THEN u.stkKod END),
        MAX(CASE WHEN u.stkKod LIKE 'G-%' THEN u.stkAd  END),
        NULL, f.gKisi, f.oKisi,
        CAST(SUM(ISNULL(a.ehTutar,0)) + SUM(ISNULL(a.ehTutarKDV,0))
           - SUM(ISNULL(a.ehTutarKDVtvkft,0)) - SUM(ISNULL(a.ehTutarStopaj,0)) AS decimal(18,2)),
        f.eNot
    FROM dbo.fat f
    JOIN @Donemler d ON f.eTarihS >= d.AyBas AND f.eTarihS < d.AySon   -- sargable (IX_fat_7 seek)
    JOIN dbo.fatAyr a ON a.ehID = f.eID
    LEFT JOIN dbo.urn u ON u.stkID = a.ehStkID AND u.urnTip IN (1,2)
    WHERE f.eTip IN (6,7,8)
      AND (ISNULL(f.gTarih,ISNULL(f.oTarih,f.eTarihS)) > d.KapanisDT OR f.kTarih > d.KapanisDT)
      AND (@SadeceGider = 0 OR EXISTS (
            SELECT 1 FROM dbo.fatAyr a2 JOIN dbo.urn u2 ON u2.stkID=a2.ehStkID
            WHERE a2.ehID=f.eID AND u2.stkKod LIKE 'G-%'))
    GROUP BY f.eID, f.eNo, f.eTarihS, f.gTarih, f.oTarih, f.kTarih, f.gKisi, f.oKisi, f.eNot, d.DonemYil, d.DonemAy, d.KapanisDT;

    /* ===================== MHS (yevmiye fişi) ===================== */
    IF @Kaynak IN ('MHS','HEPSI')
    INSERT INTO #H
    SELECT
        'MHS', CAST(b.fisbID AS bigint), CAST(b.yevmiyeNo AS varchar(50)),
        RIGHT('0'+CAST(d.DonemAy AS varchar(2)),2)+'.'+CAST(d.DonemYil AS varchar(4)),
        CAST(b.fisTarih AS datetime2(0)),
        d.KapanisDT,
        CAST(ISNULL(b.gTarih, b.fisTarih) AS datetime2(0)),
        CAST(ISNULL(b.kTarih, ISNULL(b.gTarih, b.fisTarih)) AS datetime2(0)),
        CASE WHEN ISNULL(b.gTarih,b.fisTarih) > d.KapanisDT THEN 1 ELSE 0 END,
        CASE WHEN ISNULL(b.kTarih,ISNULL(b.gTarih,b.fisTarih)) > d.KapanisDT THEN 1 ELSE 0 END,
        DATEDIFF(DAY, d.KapanisDT, ISNULL(b.kTarih,ISNULL(b.gTarih,b.fisTarih))),
        NULL, N'(yevmiye fişi)', NULL, b.gKisi, b.oKisi,
        CAST((SELECT SUM(CASE WHEN ff.fisBA=0 THEN ff.fisTutar ELSE 0 END)
              FROM mhs.mhsFis ff WHERE ff.fisID=b.fisbID AND ff.fisSirketID=b.fisbSirketID) AS decimal(18,2)),
        CAST(b.fisAd AS nvarchar(400))
    FROM mhs.mhsFisBaslik b
    JOIN @Donemler d ON b.fisTarih >= d.AyBas AND b.fisTarih < d.AySon   -- sargable (fisTarih indexsiz → yine de range filtre erken daraltır)
    WHERE (ISNULL(b.gTarih,b.fisTarih) > d.KapanisDT OR ISNULL(b.kTarih,ISNULL(b.gTarih,b.fisTarih)) > d.KapanisDT)
      AND (@SadeceGider = 0 OR EXISTS (
            SELECT 1 FROM mhs.mhsFis ff JOIN mhs.mhsHsp h ON h.hspID=ff.fisHspID AND h.hspSirketID=ff.fisSirketID
            WHERE ff.fisID=b.fisbID AND ff.fisSirketID=b.fisbSirketID
              AND (h.hspKod LIKE '6%' OR h.hspKod LIKE '7%')));   -- gelir tablosu / maliyet hesabı

    /* ---- Severity + forensic bayraklar ---- */
    ;WITH Skor AS (
        SELECT *,
            Severity = CASE WHEN GecGiris=1 AND SonradanDeg=1 THEN 3
                            WHEN SonradanDeg=1 THEN 2
                            WHEN GecGiris=1 THEN 1 ELSE 0 END,
            YuvarlakTutar = CASE WHEN ABS(Tutar) >= 1000 AND ABS(Tutar) % 1000 = 0 THEN 1 ELSE 0 END,
            GirenOnaylayanAyni = CASE WHEN KisiGiren IS NOT NULL AND KisiGiren = KisiOnay THEN 1 ELSE 0 END,
            MukerrerAdet = COUNT(*) OVER (PARTITION BY Kaynak, GiderKod, ABS(Tutar), CONVERT(date, BelgeDT))
        FROM #H
    ),
    Bayrakli AS (
        SELECT *,
            Mukerrer = CASE WHEN MukerrerAdet > 1 THEN 1 ELSE 0 END,
            RiskSkor = Severity*100
                     + CASE WHEN GunSonra > 90 THEN 90 ELSE (CASE WHEN GunSonra<0 THEN 0 ELSE GunSonra END) END
                     + CASE WHEN ABS(Tutar) >= 1000 AND ABS(Tutar) % 1000 = 0 THEN 25 ELSE 0 END
                     + CASE WHEN KisiGiren IS NOT NULL AND KisiGiren = KisiOnay THEN 20 ELSE 0 END
                     + CASE WHEN MukerrerAdet > 1 THEN 15 ELSE 0 END
        FROM Skor
    )

    /* ===================== ÇIKTI ===================== */
    SELECT * INTO #B FROM Bayrakli;

    IF @Mod = 'DETAY'
    BEGIN
        SELECT TOP (@Top)
            b.Donem, b.Kaynak, b.EvrakID, b.EvrakNo,
            BelgeTarihi   = CONVERT(varchar(10), b.BelgeDT, 104),
            KapanisTarihi = CONVERT(varchar(10), b.KapanisDT, 104),
            DegisimTarihi = CONVERT(varchar(10), b.DegisimDT, 104),
            b.GecGiris, b.SonradanDeg, b.GunSonra, b.Severity,
            b.YuvarlakTutar, b.GirenOnaylayanAyni, b.Mukerrer, b.RiskSkor,
            b.GiderKod, b.GiderAd, b.KarsiKod,
            Giren = ISNULL(dg.insAd, CAST(b.KisiGiren AS varchar(20))),
            Onaylayan = ISNULL(do.insAd, CAST(b.KisiOnay AS varchar(20))),
            b.Tutar, b.Notu
        FROM #B b
        LEFT JOIN dbo.drn1 dg ON dg.insID = b.KisiGiren   -- kişi ID → isim (gKisi/cgKisi → drn1.insID)
        LEFT JOIN dbo.drn1 do ON do.insID = b.KisiOnay
        WHERE (@GiderKod IS NULL OR b.GiderKod = @GiderKod)   -- drill: özet → bu gider kodu
        ORDER BY b.RiskSkor DESC, b.DegisimDT DESC, b.EvrakID DESC;
    END
    ELSE   /* OZET */
    BEGIN
        SELECT TOP (@Top)
            Donem, Kaynak,
            GiderKod, GiderAd,
            EvrakAdet     = COUNT(*),
            ToplamTutar   = CAST(SUM(Tutar) AS decimal(18,2)),
            MaxGunSonra   = MAX(GunSonra),
            SonradanDegAdet = SUM(CAST(SonradanDeg AS int)),       -- SUM(bit) geçersiz → CAST int
            GecGirisAdet    = SUM(CAST(GecGiris AS int)),
            YuvarlakAdet    = SUM(CAST(YuvarlakTutar AS int)),
            MukerrerAdet    = SUM(CAST(Mukerrer AS int)),
            GirenOnayAyniAdet = SUM(CAST(GirenOnaylayanAyni AS int)),
            MaxRiskSkor   = MAX(RiskSkor),
            ToplamRiskSkor= SUM(RiskSkor)
        FROM #B
        GROUP BY Donem, Kaynak, GiderKod, GiderAd
        ORDER BY MAX(RiskSkor) DESC, COUNT(*) DESC;
    END

    DROP TABLE #H; DROP TABLE #B;
END
GO

/* ---- KULLANIM ----
   -- Tek dönem özet (kapanmış ay):           EXEC bkm.sp_KapanisMudahaleKontrol_v2 @Yil=2025, @Ay=5;
   -- Tek dönem detay, tüm kaynak:             EXEC bkm.sp_KapanisMudahaleKontrol_v2 @Yil=2025, @Ay=5, @Mod='DETAY';
   -- TÜM kapanmış dönemler özet:              EXEC bkm.sp_KapanisMudahaleKontrol_v2;
   -- Sadece yevmiye (mhs) tüm dönem detay:    EXEC bkm.sp_KapanisMudahaleKontrol_v2 @Kaynak='MHS', @Mod='DETAY';
   -- Gider filtresiz (tüm evrak):             EXEC bkm.sp_KapanisMudahaleKontrol_v2 @Yil=2025, @Ay=5, @SadeceGider=0;
   -- DRILL (özet satırına tıklama):           EXEC bkm.sp_KapanisMudahaleKontrol_v2 @Yil=2025, @Ay=5, @Kaynak='CAR', @Mod='DETAY', @GiderKod='G-001';
*/
