/* =======================================================================
   sp_PdksPano — PDKS Yönetim Panosu Tek SP (7 Result Set)
   -----------------------------------------------------------------------
   Dashboard'ın ihtiyacı olan TÜM verileri 7 ayrı result set olarak döndürür.

   Sunucu  : 192.168.40.201 (BKM veritabanı, compat 150)
   Bağımlı : Linked Server [PDKS] → 192.168.40.66\SQLEXPRESS (wtimserv)
             vrd şeması (Vardiya, VardiyaDetay, VardiyaZaman, SubeListe)

   Kullanım:
     EXEC bkm.sp_PdksPano;                      -- bugün
     EXEC bkm.sp_PdksPano '15.04.2026';         -- belirli gün
     EXEC bkm.sp_PdksPano '15.04.2026', 20, 15; -- FM TOP 20, Geç TOP 15

   Result Set Sırası:
     RS1. Plan-Fiili kişi detay   (D dizisi — Sube,Bolum,Personel,Plan*,Fiili*,Durum,Sapma)
     RS2. Şube özet               (Plan/Geldi/Gelmedi/PdksYok/İzinli/OzelDurum/İçeride)
     RS3. KPI tek satır            (kadro + plan toplamları + katılım yüzdeleri)
     RS4. FM1 fazla mesai TOP N   (ay başından bugüne, segment bazlı)
     RS5. Geç kalma TOP N         (ay başından bugüne, plan-fiili karşılaştırma, 5dk tolerans)
     RS6. Bölüm doluluk           (tüm kadro — GecoTime Per_Grp2 bazlı)
     RS7. Eksik okutma            (dün — giriş var çıkış yok)

   Durum Kodları (RS1):
     TAMAM     = plan var, fiili giriş+çıkış var
     GELMEDI   = plan var, PDKS'te kayıtlı ama giriş yok
     ICERIDE   = giriş var, çıkış henüz yok
     IZINLI    = vrd'de izin kodu (51,52,53,55,58,63,73)
     OZEL      = kod 100 (özel durum, plan belirsiz)
     MAZERETLI = GecoTime'da mazeret kodu var (HASTA vb.)
     YOK       = TPerInd'de TC eşleşmesi yok (yönetici kadro)
   ======================================================================= */

CREATE OR ALTER PROCEDURE sp_PdksPano
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

  -- Haftanın Pazartesi'si (vrd.Vardiya.Tarih = Pazartesi)
  SET @HaftaBas = DATEADD(DAY, -((DATEPART(WEEKDAY, @Gun) + @@DATEFIRST + 5) % 7), @Gun);
  SET @AyBas    = DATEADD(DAY, 1 - DAY(@Gun), @Gun);
  SET @Dun      = DATEADD(DAY, -1, @Gun);

  -- ISO formatlar (OPENQUERY içi — wtimserv compat 110)
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
  -- RS1: PLAN-FİİLİ KİŞİ DETAY
  -- ===================================================================
  SELECT
    p.Sube,
    p.Bolum,
    p.Personel,
    p.TC,
    p.PlanVardiya,
    p.PlanBas,
    p.PlanBit,
    p.PlanDk,
    p.PlanNetDk,
    f.FiiliGiris,
    f.FiiliCikis,
    f.BrutSure,
    f.MazeretKod,
    p.IzinMi,
    p.OzelDurumMu,
    CASE
      WHEN p.IzinMi = 1                                    THEN 'IZINLI'
      WHEN p.OzelDurumMu = 1 AND f.FiiliGiris IS NULL      THEN 'OZEL'
      WHEN f.MazeretKod IS NOT NULL AND f.MazeretKod <> ''  THEN 'MAZERETLI'
      WHEN f.FiiliGiris IS NULL AND f.TC IS NULL            THEN 'YOK'
      WHEN f.FiiliGiris IS NULL                             THEN 'GELMEDI'
      WHEN f.FiiliCikis IS NULL                             THEN 'ICERIDE'
      ELSE 'TAMAM'
    END AS Durum,
    CASE
      WHEN f.FiiliGiris IS NOT NULL AND p.PlanBas IS NOT NULL
        THEN DATEDIFF(MINUTE, CONVERT(time, p.PlanBas), CONVERT(time, f.FiiliGiris))
      ELSE NULL
    END AS GirisSapmaDk,
    CASE
      WHEN f.FiiliCikis IS NOT NULL AND p.PlanBit IS NOT NULL
        THEN DATEDIFF(MINUTE, CONVERT(time, p.PlanBit), CONVERT(time, f.FiiliCikis))
      ELSE NULL
    END AS CikisSapmaDk
  FROM #plan p
  LEFT JOIN #fiili f ON f.TC COLLATE Turkish_CI_AS = p.TC COLLATE Turkish_CI_AS
  ORDER BY p.Sube, p.Bolum, p.Personel;

  -- ===================================================================
  -- RS2: ŞUBE ÖZET
  -- ===================================================================
  SELECT
    p.Sube,
    COUNT(*)                                                                       AS PlanSayisi,
    SUM(CASE WHEN p.IzinMi = 0 AND p.OzelDurumMu = 0 THEN 1 ELSE 0 END)         AS CalismaPlan,
    SUM(CASE WHEN p.IzinMi = 0 AND p.OzelDurumMu = 0
              AND f.FiiliGiris IS NOT NULL THEN 1 ELSE 0 END)                     AS Geldi,
    SUM(CASE WHEN p.IzinMi = 0 AND p.OzelDurumMu = 0
              AND f.FiiliGiris IS NULL AND f.TC IS NOT NULL THEN 1 ELSE 0 END)    AS Gelmedi,
    SUM(CASE WHEN p.IzinMi = 0 AND p.OzelDurumMu = 0
              AND f.TC IS NULL THEN 1 ELSE 0 END)                                 AS PdksYok,
    SUM(CASE WHEN p.IzinMi = 1 THEN 1 ELSE 0 END)                                AS Izinli,
    SUM(CASE WHEN p.OzelDurumMu = 1 THEN 1 ELSE 0 END)                           AS OzelDurum,
    SUM(CASE WHEN p.IzinMi = 0 AND p.OzelDurumMu = 0
              AND f.FiiliGiris IS NOT NULL AND f.FiiliCikis IS NULL
              THEN 1 ELSE 0 END)                                                   AS SuAnIceride
  FROM #plan p
  LEFT JOIN #fiili f ON f.TC COLLATE Turkish_CI_AS = p.TC COLLATE Turkish_CI_AS
  GROUP BY p.Sube
  ORDER BY p.Sube;

  -- ===================================================================
  -- RS3: KPI TEK SATIR
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

  SELECT
    CONVERT(varchar(10), @Gun, 104)                  AS Tarih,
    DATENAME(WEEKDAY, @Gun)                          AS GunAdi,
    CONVERT(varchar(10), @HaftaBas, 104)             AS HaftaBas,
    @TotalKadro                                      AS KadroToplam,
    @TotalGelen                                      AS KadroGelen,
    @TotalIzinli                                     AS KadroIzinli,
    @TotalGelmedi                                    AS KadroGelmedi,
    CAST(ROUND(100.0 * @TotalGelen / NULLIF(@TotalKadro, 0), 1) AS decimal(5,1))
                                                     AS KadroKatilimYuzde,
    @PlanToplam                                      AS PlanToplam,
    @PlanGeldi                                       AS PlanGeldi,
    @PlanGelmedi                                     AS PlanGelmedi,
    @PlanIzinli                                      AS PlanIzinli,
    CAST(ROUND(100.0 * @PlanGeldi / NULLIF(@PlanToplam, 0), 1) AS decimal(5,1))
                                                     AS PlanKatilimYuzde;

  -- ===================================================================
  -- RS4: FM1 FAZLA MESAİ TOP N (ay başı → bugün)
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

  SELECT Sicil, AdSoyad, Bolum, Gun, FmSaat, FmDk
  FROM #mesai
  ORDER BY FmDk DESC;

  -- ===================================================================
  -- RS5: GEÇ KALMA TOP N (ay başı → bugün, plan-fiili karşılaştırma)
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

  SELECT TOP (@GecTop)
    ap.TC,
    ap.Personel,
    ap.Sube,
    COUNT(*)                                         AS Gun,
    SUM(DATEDIFF(MINUTE, ap.PlanBas, af.Giris))      AS ToplamGecikmeDk
  FROM #ayPlan ap
  INNER JOIN #ayFiili af
    ON af.TC COLLATE Turkish_CI_AS = ap.TC COLLATE Turkish_CI_AS
   AND af.Gun = ap.Gun
  WHERE DATEDIFF(MINUTE, ap.PlanBas, af.Giris) > 5     -- 5 dk tolerans
  GROUP BY ap.TC, ap.Personel, ap.Sube
  ORDER BY ToplamGecikmeDk DESC;

  -- ===================================================================
  -- RS6: BÖLÜM DOLULUK (tüm kadro — GecoTime Per_Grp2 bazlı)
  -- ===================================================================
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

  EXEC sp_executesql @oqBolum;

  -- ===================================================================
  -- RS7: EKSİK OKUTMA (dün — giriş var, çıkış yok)
  -- ===================================================================
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

  EXEC sp_executesql @oqEksik;

  -- ===================================================================
  -- TEMİZLİK
  -- ===================================================================
  DROP TABLE IF EXISTS #plan;
  DROP TABLE IF EXISTS #fiili;
  DROP TABLE IF EXISTS #mesai;
  DROP TABLE IF EXISTS #ayPlan;
  DROP TABLE IF EXISTS #ayFiili;

END;
GO

/* =======================================================================
   KULLANIM ÖRNEKLERİ
   -----------------------------------------------------------------------
   EXEC bkm.sp_PdksPano;                            -- bugün
   EXEC bkm.sp_PdksPano '15.04.2026';               -- belirli gün
   EXEC bkm.sp_PdksPano '15.04.2026', 20, 15;       -- FM TOP 20, Geç TOP 15

   RESULT SET SIRASI:
   RS1  Plan-Fiili kişi detay   → Sube, Bolum, Personel, Plan*, Fiili*, Durum, Sapma
   RS2  Şube özet               → Sube, PlanSayisi, CalismaPlan, Geldi, Gelmedi, PdksYok, Izinli, OzelDurum, SuAnIceride
   RS3  KPI tek satır            → Tarih, GunAdi, KadroToplam, ..., PlanToplam, ...
   RS4  FM1 fazla mesai TOP N   → Sicil, AdSoyad, Bolum, Gun, FmSaat, FmDk
   RS5  Geç kalma TOP N         → TC, Personel, Sube, Gun, ToplamGecikmeDk
   RS6  Bölüm doluluk           → Bolum, Kadro, Gelen, Izinli
   RS7  Eksik okutma             → Sicil, AdSoyad, Bolum, Giris, Cikis

   NOTLAR:
   - Tarih parametresi DMY (dd.MM.yyyy). OPENQUERY içi YYYYMMDD ISO.
   - TC kimlik eşleşmesi COLLATE Turkish_CI_AS.
   - CROSS APPLY VALUES UNPIVOT → gün kolonu hard-coded değil.
   - Durum: TAMAM / GELMEDI / ICERIDE / IZINLI / OZEL / YOK / MAZERETLI.
   - GirisSapmaDk: pozitif = geç, negatif = erken.
   - Geç kalma 5dk toleranslı.
   - datetime ↔ time uyumsuzluğu CONVERT(varchar(5), ..., 108) ile çözüldü.
   ======================================================================= */
