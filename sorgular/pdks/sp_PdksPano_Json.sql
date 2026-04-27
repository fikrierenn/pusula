/* =======================================================================
   sp_PdksPano_Json — PDKS Yönetim Panosu Tek SP (JSON çıktı)
   -----------------------------------------------------------------------
   sp_PdksPano ile aynı mantık, tek farkla: 7 ayrı result set yerine
   tüm veriyi JSON olarak tek bir sütunda döndürür.

   Sunucu  : 192.168.40.201 (BKM veritabanı, compat 150)
   Bağımlı : Linked Server [PDKS] → 192.168.40.66\SQLEXPRESS (wtimserv)
             vrd şeması (Vardiya, VardiyaDetay, VardiyaZaman, SubeListe)

   Kullanım:
     EXEC bkm.sp_PdksPano_Json;                      -- bugün
     EXEC bkm.sp_PdksPano_Json '15.04.2026';         -- belirli gün
     EXEC bkm.sp_PdksPano_Json '15.04.2026', 20, 15; -- FM TOP 20, Geç TOP 15

   Çıktı Yapısı (tek sütun: PanoJson):
     {
       "tarih": "16.04.2026",
       "gunAdi": "Perşembe",
       "haftaBas": "13.04.2026",
       "kpi": { kadroToplam, kadroGelen, ... planKatilimYuzde },
       "detay": [ { sube, bolum, personel, ... durum, girisSapmaDk } ],
       "subeOzet": [ { sube, planSayisi, ... suAnIceride } ],
       "mesai": [ { sicil, adSoyad, bolum, gun, fmSaat, fmDk } ],
       "gecKalma": [ { tc, personel, sube, gun, toplamGecikmeDk } ],
       "bolumDoluluk": <doğrudan OPENQUERY — JSON'a çevrilir>,
       "eksikOkutma": <doğrudan OPENQUERY — JSON'a çevrilir>
     }
   ======================================================================= */

CREATE OR ALTER PROCEDURE sp_PdksPano_Json
  @Tarih      varchar(10) = NULL,     -- dd.MM.yyyy (DMY) veya NULL=bugün
  @FmTop      int = 10,               -- fazla mesai TOP N
  @GecTop     int = 10                -- geç kalma TOP N
AS
BEGIN
  SET NOCOUNT ON;

  -- ===================================================================
  -- 0. TARİH HESAPLAMALARI
  -- ===================================================================
  DECLARE @Gun       date;
  DECLARE @HaftaBas  date;
  DECLARE @AyBas     date;
  DECLARE @Dun       date;
  DECLARE @GunISO    char(8);
  DECLARE @AyBasISO  char(8);
  DECLARE @DunISO    char(8);

  IF @Tarih IS NULL
    SET @Gun = CAST(GETDATE() AS date)
  ELSE
    SET @Gun = CONVERT(date, @Tarih, 104);

  SET @HaftaBas = DATEADD(DAY, -((DATEPART(WEEKDAY, @Gun) + @@DATEFIRST + 5) % 7), @Gun);
  SET @AyBas    = DATEADD(DAY, 1 - DAY(@Gun), @Gun);
  SET @Dun      = DATEADD(DAY, -1, @Gun);

  SET @GunISO   = CONVERT(char(8), @Gun,    112);
  SET @AyBasISO = CONVERT(char(8), @AyBas,  112);
  SET @DunISO   = CONVERT(char(8), @Dun,    112);

  -- ===================================================================
  -- 1. PLAN VERİSİ (vrd → CROSS APPLY UNPIVOT ile dinamik gün)
  -- ===================================================================
  SELECT
    s.SubeAd                                         AS Sube,
    vd.Bolum,
    vd.Personel,
    vd.SicilNo                                       AS TC,
    gun.VardiyaId,
    vz.Aciklama                                      AS PlanVardiya,
    CONVERT(varchar(5), vz.Baslama, 108)             AS PlanBas,
    CONVERT(varchar(5), vz.Bitis,   108)             AS PlanBit,
    vz.ToplamCalismaDk                               AS PlanDk,
    vz.MolaSureDk                                    AS PlanMolaDk,
    vz.ToplamCalismaDk - ISNULL(vz.MolaSureDk, 0)   AS PlanNetDk,
    CAST(ISNULL(vz.Izin, 0) AS int)                  AS IzinMi,
    CASE WHEN gun.VardiyaId = 100 THEN 1 ELSE 0 END  AS OzelDurumMu
  INTO #plan
  FROM vrd.Vardiya v
  INNER JOIN vrd.VardiyaDetay vd ON vd.VardiyaNo = v.VardiyaNo
  CROSS APPLY (VALUES
    (DATEADD(DAY, 0, v.Tarih), vd.Pazartesi),
    (DATEADD(DAY, 1, v.Tarih), vd.Sali),
    (DATEADD(DAY, 2, v.Tarih), vd.Carsamba),
    (DATEADD(DAY, 3, v.Tarih), vd.Persembe),
    (DATEADD(DAY, 4, v.Tarih), vd.Cuma),
    (DATEADD(DAY, 5, v.Tarih), vd.Cumartesi),
    (DATEADD(DAY, 6, v.Tarih), vd.Pazar)
  ) gun(GunTarih, VardiyaId)
  INNER JOIN vrd.SubeListe     s  ON s.SubeNo    = v.SubeNo
  LEFT  JOIN vrd.VardiyaZaman  vz ON vz.VardiyaId = gun.VardiyaId
  WHERE gun.GunTarih = @Gun;

  -- ===================================================================
  -- 2. FİİLİ VERİ (PDKS → OPENQUERY, dinamik tarih)
  -- ===================================================================
  CREATE TABLE #fiili (
    TC          nvarchar(20),
    FiiliGiris  varchar(5),
    FiiliCikis  varchar(5),
    BrutSure    decimal(18,2),
    MazeretKod  nvarchar(10)
  );

  DECLARE @oqFiili nvarchar(max) = N'
    SELECT * FROM OPENQUERY([PDKS], ''
      SELECT i.PIn_SteuerNr                            AS TC,
             CONVERT(varchar(5), l.TLe_VonZeit, 108)   AS FiiliGiris,
             CONVERT(varchar(5), l.TLe_BisZeit, 108)   AS FiiliCikis,
             l.TLe_IstZeit                             AS BrutSure,
             l.TLe_AbwArt                              AS MazeretKod
      FROM TPerInd i
      INNER JOIN TTagLes l ON l.TLe_PersNr = i.PIn_PersNr
      WHERE l.TLe_Datum = ''''' + @GunISO + '''''
        AND l.TLe_BeginnKz = 0
    '')';

  INSERT INTO #fiili EXEC sp_executesql @oqFiili;

  -- ===================================================================
  -- 3. FM1 FAZLA MESAİ TOP N (ay başı → bugün)
  -- ===================================================================
  CREATE TABLE #mesai (
    Sicil    int,
    AdSoyad  nvarchar(100),
    Bolum    nvarchar(80),
    Gun      int,
    FmSaat   decimal(10,2),
    FmDk     int
  );

  DECLARE @oqMesai nvarchar(max) = N'
    SELECT * FROM OPENQUERY([PDKS], ''
      SELECT TOP ' + CAST(@FmTop AS varchar(5)) + '
        z.TZe_PersNr                                 AS Sicil,
        p.Per_Vorname + '''' '''' + p.Per_Name       AS AdSoyad,
        p.Per_Grp2                                   AS Bolum,
        COUNT(DISTINCT z.TZe_Datum)                  AS Gun,
        CAST(SUM(DATEDIFF(MINUTE, z.TZe_VonZeit, z.TZe_BisZeit)) / 60.0 AS decimal(10,2)) AS FmSaat,
        SUM(DATEDIFF(MINUTE, z.TZe_VonZeit, z.TZe_BisZeit)) AS FmDk
      FROM TTagZei z
      INNER JOIN TPerTab p ON p.Per_PersNr = z.TZe_PersNr
      WHERE z.TZe_Datum >= ''''' + @AyBasISO + '''''
        AND z.TZe_Datum <= ''''' + @GunISO + '''''
        AND z.TZe_ZeitArt = ''''FM1''''
        AND z.TZe_VonZeit IS NOT NULL
        AND z.TZe_BisZeit IS NOT NULL
      GROUP BY z.TZe_PersNr, p.Per_Vorname, p.Per_Name, p.Per_Grp2
      ORDER BY FmDk DESC
    '')';

  INSERT INTO #mesai EXEC sp_executesql @oqMesai;

  -- ===================================================================
  -- 4. GEÇ KALMA TOP N (ay başı → bugün, plan-fiili karşılaştırma)
  -- ===================================================================
  CREATE TABLE #ayPlan (
    TC       nvarchar(20),
    Personel nvarchar(100),
    Sube     nvarchar(50),
    Gun      date,
    PlanBas  time
  );

  INSERT INTO #ayPlan
  SELECT vd.SicilNo, vd.Personel, s.SubeAd, gun.GunTarih, CONVERT(time, vz.Baslama)
  FROM vrd.Vardiya v
  INNER JOIN vrd.VardiyaDetay vd ON vd.VardiyaNo = v.VardiyaNo
  CROSS APPLY (VALUES
    (DATEADD(DAY, 0, v.Tarih), vd.Pazartesi),
    (DATEADD(DAY, 1, v.Tarih), vd.Sali),
    (DATEADD(DAY, 2, v.Tarih), vd.Carsamba),
    (DATEADD(DAY, 3, v.Tarih), vd.Persembe),
    (DATEADD(DAY, 4, v.Tarih), vd.Cuma),
    (DATEADD(DAY, 5, v.Tarih), vd.Cumartesi),
    (DATEADD(DAY, 6, v.Tarih), vd.Pazar)
  ) gun(GunTarih, VardiyaId)
  INNER JOIN vrd.VardiyaZaman vz ON vz.VardiyaId = gun.VardiyaId
  INNER JOIN vrd.SubeListe    s  ON s.SubeNo    = v.SubeNo
  WHERE gun.GunTarih >= @AyBas AND gun.GunTarih <= @Gun
    AND vz.Izin = 0 AND gun.VardiyaId <> 100
    AND vz.Baslama IS NOT NULL
    AND CONVERT(varchar(5), vz.Baslama, 108) <> '00:00';

  CREATE TABLE #ayFiili (
    TC    nvarchar(20),
    Gun   date,
    Giris time
  );

  DECLARE @oqAyFiili nvarchar(max) = N'
    SELECT * FROM OPENQUERY([PDKS], ''
      SELECT i.PIn_SteuerNr                        AS TC,
             CONVERT(date, l.TLe_Datum, 112)       AS Gun,
             CONVERT(time, l.TLe_VonZeit)          AS Giris
      FROM TPerInd i
      INNER JOIN TTagLes l ON l.TLe_PersNr = i.PIn_PersNr
      WHERE l.TLe_Datum >= ''''' + @AyBasISO + '''''
        AND l.TLe_Datum <= ''''' + @GunISO + '''''
        AND l.TLe_BeginnKz = 0
        AND l.TLe_VonZeit IS NOT NULL
    '')';

  INSERT INTO #ayFiili EXEC sp_executesql @oqAyFiili;

  -- Geç kalma hesapla → #gecKalma
  SELECT
    ap.TC,
    ap.Personel,
    ap.Sube,
    COUNT(*)                                         AS Gun,
    SUM(DATEDIFF(MINUTE, ap.PlanBas, af.Giris))      AS ToplamGecikmeDk
  INTO #gecKalma
  FROM #ayPlan ap
  INNER JOIN #ayFiili af
    ON af.TC COLLATE Turkish_CI_AS = ap.TC COLLATE Turkish_CI_AS
   AND af.Gun = ap.Gun
  WHERE DATEDIFF(MINUTE, ap.PlanBas, af.Giris) > 5
  GROUP BY ap.TC, ap.Personel, ap.Sube;

  -- ===================================================================
  -- 5. BÖLÜM DOLULUK → #bolum
  -- ===================================================================
  CREATE TABLE #bolum (
    Bolum   nvarchar(80),
    Kadro   int,
    Gelen   int,
    Izinli  int
  );

  DECLARE @oqBolum nvarchar(max) = N'
    SELECT * FROM OPENQUERY([PDKS], ''
      SELECT
        p.Per_Grp2                               AS Bolum,
        COUNT(*)                                 AS Kadro,
        SUM(CASE WHEN l.TLe_PersNr IS NOT NULL THEN 1 ELSE 0 END) AS Gelen,
        SUM(CASE WHEN a.Abw_AbwArt IS NOT NULL THEN 1 ELSE 0 END) AS Izinli
      FROM TPerTab p
      LEFT JOIN TTagLes l ON l.TLe_PersNr = p.Per_PersNr
                          AND l.TLe_Datum = ''''' + @GunISO + '''''
                          AND l.TLe_BeginnKz = 0
      LEFT JOIN TAbwArt a ON a.Abw_AbwArt = l.TLe_AbwArt
      WHERE p.Per_ZeitAktiv = 1
        AND p.Per_Grp2 IS NOT NULL
        AND p.Per_Grp2 <> ''''''''
      GROUP BY p.Per_Grp2
      ORDER BY Kadro DESC
    '')';

  INSERT INTO #bolum EXEC sp_executesql @oqBolum;

  -- ===================================================================
  -- 6. EKSİK OKUTMA → #eksik
  -- ===================================================================
  CREATE TABLE #eksik (
    Sicil    int,
    AdSoyad  nvarchar(100),
    Bolum    nvarchar(80),
    Giris    varchar(5),
    Cikis    varchar(5)
  );

  DECLARE @oqEksik nvarchar(max) = N'
    SELECT * FROM OPENQUERY([PDKS], ''
      SELECT TOP 20
        l.TLe_PersNr                             AS Sicil,
        p.Per_Vorname + '''' '''' + p.Per_Name   AS AdSoyad,
        p.Per_Grp2                               AS Bolum,
        CONVERT(varchar(5), l.TLe_VonZeit, 108)  AS Giris,
        CONVERT(varchar(5), l.TLe_BisZeit, 108)  AS Cikis
      FROM TTagLes l
      INNER JOIN TPerTab p ON p.Per_PersNr = l.TLe_PersNr
      WHERE l.TLe_Datum = ''''' + @DunISO + '''''
        AND l.TLe_BeginnKz = 0
        AND l.TLe_VonZeit IS NOT NULL
        AND l.TLe_BisZeit IS NULL
      ORDER BY p.Per_Grp2, p.Per_Name
    '')';

  INSERT INTO #eksik EXEC sp_executesql @oqEksik;

  -- ===================================================================
  -- 7. KPI HESAPLAMALARI
  -- ===================================================================
  DECLARE @TotalKadro int, @TotalGelen int, @TotalIzinli int, @TotalGelmedi int;

  SELECT @TotalKadro = COUNT(*) FROM OPENQUERY([PDKS],
    'SELECT Per_PersNr FROM TPerTab WHERE Per_ZeitAktiv = 1');

  SELECT
    @TotalGelen  = SUM(CASE WHEN FiiliGiris IS NOT NULL THEN 1 ELSE 0 END),
    @TotalIzinli = SUM(CASE WHEN MazeretKod IS NOT NULL AND MazeretKod <> '' THEN 1 ELSE 0 END)
  FROM #fiili;

  SET @TotalGelmedi = @TotalKadro - ISNULL(@TotalGelen, 0) - ISNULL(@TotalIzinli, 0);

  DECLARE @PlanToplam int, @PlanGeldi int, @PlanGelmedi int, @PlanIzinli int;
  SELECT
    @PlanToplam = SUM(CASE WHEN IzinMi = 0 AND OzelDurumMu = 0 THEN 1 ELSE 0 END),
    @PlanIzinli = SUM(CASE WHEN IzinMi = 1 THEN 1 ELSE 0 END)
  FROM #plan;

  SELECT @PlanGeldi = COUNT(DISTINCT f.TC)
  FROM #plan p
  INNER JOIN #fiili f ON f.TC COLLATE Turkish_CI_AS = p.TC COLLATE Turkish_CI_AS
  WHERE p.IzinMi = 0 AND p.OzelDurumMu = 0 AND f.FiiliGiris IS NOT NULL;

  SET @PlanGelmedi = @PlanToplam - @PlanGeldi;

  -- ===================================================================
  -- TEK JSON ÇIKTI
  -- ===================================================================
  SELECT (
    SELECT
      -- Meta
      CONVERT(varchar(10), @Gun, 104)                  AS tarih,
      DATENAME(WEEKDAY, @Gun)                          AS gunAdi,
      CONVERT(varchar(10), @HaftaBas, 104)             AS haftaBas,

      -- KPI
      (SELECT
        @TotalKadro                                    AS kadroToplam,
        @TotalGelen                                    AS kadroGelen,
        @TotalIzinli                                   AS kadroIzinli,
        @TotalGelmedi                                  AS kadroGelmedi,
        CAST(ROUND(100.0 * @TotalGelen / NULLIF(@TotalKadro, 0), 1) AS decimal(5,1))
                                                       AS kadroKatilimYuzde,
        @PlanToplam                                    AS planToplam,
        @PlanGeldi                                     AS planGeldi,
        @PlanGelmedi                                   AS planGelmedi,
        @PlanIzinli                                    AS planIzinli,
        CAST(ROUND(100.0 * @PlanGeldi / NULLIF(@PlanToplam, 0), 1) AS decimal(5,1))
                                                       AS planKatilimYuzde
      FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)            AS kpi,

      -- Detay (RS1)
      (SELECT
        p.Sube                AS sube,
        p.Bolum               AS bolum,
        p.Personel            AS personel,
        p.TC                  AS tc,
        p.PlanVardiya         AS planVardiya,
        p.PlanBas             AS planBas,
        p.PlanBit             AS planBit,
        p.PlanDk              AS planDk,
        p.PlanNetDk           AS planNetDk,
        f.FiiliGiris          AS fiiliGiris,
        f.FiiliCikis          AS fiiliCikis,
        f.BrutSure            AS brutSure,
        f.MazeretKod          AS mazeretKod,
        p.IzinMi              AS izinMi,
        p.OzelDurumMu         AS ozelDurumMu,
        CASE
          WHEN p.IzinMi = 1                                    THEN 'IZINLI'
          WHEN p.OzelDurumMu = 1 AND f.FiiliGiris IS NULL      THEN 'OZEL'
          WHEN f.MazeretKod IS NOT NULL AND f.MazeretKod <> ''  THEN 'MAZERETLI'
          WHEN f.FiiliGiris IS NULL AND f.TC IS NULL            THEN 'YOK'
          WHEN f.FiiliGiris IS NULL                             THEN 'GELMEDI'
          WHEN f.FiiliCikis IS NULL                             THEN 'ICERIDE'
          ELSE 'TAMAM'
        END                   AS durum,
        CASE
          WHEN f.FiiliGiris IS NOT NULL AND p.PlanBas IS NOT NULL
            THEN DATEDIFF(MINUTE, CONVERT(time, p.PlanBas), CONVERT(time, f.FiiliGiris))
          ELSE NULL
        END                   AS girisSapmaDk,
        CASE
          WHEN f.FiiliCikis IS NOT NULL AND p.PlanBit IS NOT NULL
            THEN DATEDIFF(MINUTE, CONVERT(time, p.PlanBit), CONVERT(time, f.FiiliCikis))
          ELSE NULL
        END                   AS cikisSapmaDk
      FROM #plan p
      LEFT JOIN #fiili f ON f.TC COLLATE Turkish_CI_AS = p.TC COLLATE Turkish_CI_AS
      ORDER BY p.Sube, p.Bolum, p.Personel
      FOR JSON PATH)          AS detay,

      -- Şube Özet (RS2)
      (SELECT
        p.Sube                AS sube,
        COUNT(*)              AS planSayisi,
        SUM(CASE WHEN p.IzinMi = 0 AND p.OzelDurumMu = 0 THEN 1 ELSE 0 END) AS calismaPlan,
        SUM(CASE WHEN p.IzinMi = 0 AND p.OzelDurumMu = 0
                  AND f.FiiliGiris IS NOT NULL THEN 1 ELSE 0 END)             AS geldi,
        SUM(CASE WHEN p.IzinMi = 0 AND p.OzelDurumMu = 0
                  AND f.FiiliGiris IS NULL AND f.TC IS NOT NULL THEN 1 ELSE 0 END) AS gelmedi,
        SUM(CASE WHEN p.IzinMi = 0 AND p.OzelDurumMu = 0
                  AND f.TC IS NULL THEN 1 ELSE 0 END)                         AS pdksYok,
        SUM(CASE WHEN p.IzinMi = 1 THEN 1 ELSE 0 END)                        AS izinli,
        SUM(CASE WHEN p.OzelDurumMu = 1 THEN 1 ELSE 0 END)                   AS ozelDurum,
        SUM(CASE WHEN p.IzinMi = 0 AND p.OzelDurumMu = 0
                  AND f.FiiliGiris IS NOT NULL AND f.FiiliCikis IS NULL
                  THEN 1 ELSE 0 END)                                           AS suAnIceride
      FROM #plan p
      LEFT JOIN #fiili f ON f.TC COLLATE Turkish_CI_AS = p.TC COLLATE Turkish_CI_AS
      GROUP BY p.Sube
      FOR JSON PATH)          AS subeOzet,

      -- Mesai TOP N (RS4)
      (SELECT
        Sicil                 AS sicil,
        AdSoyad               AS adSoyad,
        Bolum                 AS bolum,
        Gun                   AS gun,
        FmSaat                AS fmSaat,
        FmDk                  AS fmDk
      FROM #mesai
      ORDER BY FmDk DESC
      FOR JSON PATH)          AS mesai,

      -- Geç Kalma TOP N (RS5)
      (SELECT TOP (@GecTop)
        TC                    AS tc,
        Personel              AS personel,
        Sube                  AS sube,
        Gun                   AS gun,
        ToplamGecikmeDk       AS toplamGecikmeDk
      FROM #gecKalma
      ORDER BY ToplamGecikmeDk DESC
      FOR JSON PATH)          AS gecKalma,

      -- Bölüm Doluluk (RS6)
      (SELECT
        Bolum                 AS bolum,
        Kadro                 AS kadro,
        Gelen                 AS gelen,
        Izinli                AS izinli
      FROM #bolum
      ORDER BY Kadro DESC
      FOR JSON PATH)          AS bolumDoluluk,

      -- Eksik Okutma (RS7)
      (SELECT
        Sicil                 AS sicil,
        AdSoyad               AS adSoyad,
        Bolum                 AS bolum,
        Giris                 AS giris,
        Cikis                 AS cikis
      FROM #eksik
      FOR JSON PATH)          AS eksikOkutma

    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
  ) AS PanoJson;

  -- ===================================================================
  -- TEMİZLİK
  -- ===================================================================
  DROP TABLE IF EXISTS #plan;
  DROP TABLE IF EXISTS #fiili;
  DROP TABLE IF EXISTS #mesai;
  DROP TABLE IF EXISTS #ayPlan;
  DROP TABLE IF EXISTS #ayFiili;
  DROP TABLE IF EXISTS #gecKalma;
  DROP TABLE IF EXISTS #bolum;
  DROP TABLE IF EXISTS #eksik;

END;
GO

/* =======================================================================
   KULLANIM ÖRNEKLERİ
   -----------------------------------------------------------------------
   EXEC bkm.sp_PdksPano_Json;                            -- bugün
   EXEC bkm.sp_PdksPano_Json '15.04.2026';               -- belirli gün
   EXEC bkm.sp_PdksPano_Json '15.04.2026', 20, 15;       -- FM TOP 20, Geç TOP 15

   Tek sütun (PanoJson) döner. JavaScript tarafında:
     const pano = JSON.parse(rs.rows[0].PanoJson);
     pano.kpi.kadroToplam       → 148
     pano.detay[0].durum        → "TAMAM"
     pano.subeOzet[0].geldi     → 32
     pano.mesai[0].fmSaat       → 12.5
     pano.gecKalma[0].personel  → "ALİ YILMAZ"
     pano.bolumDoluluk          → [...]
     pano.eksikOkutma           → [...]

   NOTLAR:
   - sp_PdksPano ile aynı veri, aynı mantık — sadece çıktı formatı JSON.
   - FOR JSON PATH ile iç içe (nested) yapı.
   - kpi nesnesi WITHOUT_ARRAY_WRAPPER (tekil obje).
   - Boş diziler NULL döner (JSON spec), JS tarafında || [] ile handle edilmeli.
   - datetime ↔ time uyumsuzluğu CONVERT(varchar(5), ..., 108) ile çözüldü.
   ======================================================================= */
