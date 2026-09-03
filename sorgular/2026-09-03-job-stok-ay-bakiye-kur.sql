/* SQL Agent job kurulumu — bkm.StokAyBakiyeMekanBazli aylik ay-sonu snapshot
   Kullanici onayi: 03.09.2026 ("sql agent job kur"). Sunucu: 192.168.40.201
   NEDEN: script 12.08'de yazildi, 14.08'de ELLE bir kez kosuldu, otomasyon HIC kurulmadi
          (msdb.sysjobsteps taramasi: bizim tabloyu yazan 0 adim). Sonuc: depo gecmisi
          birikmedi (WMS tek donem) + damga yanlis (14.08 verisi 31.08 damgali).
   Bu script idempotent: job varsa siler, yeniden kurar. */
SET NOCOUNT ON;
USE msdb;

IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = N'BKM-Stok-AyBakiye-AySonu')
    EXEC msdb.dbo.sp_delete_job @job_name = N'BKM-Stok-AyBakiye-AySonu', @delete_unused_schedule = 1;

DECLARE @jobId binary(16);

EXEC msdb.dbo.sp_add_job
     @job_name = N'BKM-Stok-AyBakiye-AySonu',
     @enabled = 1,
     @description = N'bkm.StokAyBakiyeMekanBazli aylik ay-sonu stok bakiyesi: DEPO (mekan 12) WMS hucresel snapshot (RAF+GIRIS) + SUBE (1/4477/4478) irsHrk kumulatif yeniden-kurulum. Ay-sonu guard var: ayin son gunu disinda ATLAR (damga hatasi onlemi). Kaynak script: D:/Dev/pusula/sorgular/2026-08-12-stok-ay-bakiye-mekan-tablo.sql · kurulum 03.09.2026',
     @start_step_id = 1,
     @owner_login_name = N'sa',
     @job_id = @jobId OUTPUT;

EXEC msdb.dbo.sp_add_jobstep
     @job_id = @jobId,
     @step_id = 1,
     @step_name = N'Ay-sonu stok bakiyesi (depo WMS + sube irsHrk)',
     @subsystem = N'TSQL',
     @database_name = N'DerinSISBkm',
     @command = N'SET NOCOUNT ON;
SET XACT_ABORT ON;

/* AY-SONU GUARD (K-38 damga hatasinin kalici cozumu)
   WMS degeri KOSTUGU ANIN fotografidir; Donem=EOMONTH damgasi ancak ayin SON gunu
   kosulursa dogru olur. 14.08.2026''da elle kosuldu ve satir 31.08 damgalandi ->
   ''Agustos sonu'' sanilan deger aslinda 14 Agustos''tu. Bu guard onu tekrarlatmaz. */
DECLARE @bugun date = CONVERT(date, GETDATE());

IF @bugun <> EOMONTH(@bugun)
BEGIN
    PRINT ''Ay sonu degil ('' + CONVERT(varchar(10), @bugun, 104) + '') - ATLANDI. Job ayin son gunu 23:30 kosar.'';
END
ELSE
BEGIN
    DECLARE @sonAy date = EOMONTH(@bugun);
    PRINT ''Donem: '' + CONVERT(varchar(10), @sonAy, 104);

    /* 1) DEPO (mekan 12) - WMS hucresel stok anlik snapshot.
          Kaynak: depo.stok_adres_palet_vw, adrsAlanTipID IN (0,1) = RAF + GIRIS
          (2=CIKIS ALANI haric: sevke hazirlanmis mal). Kullanici direktifi 03.09.2026:
          "ERP merkez depo defteri senkron sorunu var, her zaman WMS stoklarina bakmalisin." */
    DELETE FROM bkm.StokAyBakiyeMekanBazli WHERE Kaynak = ''WMS'' AND Donem = @sonAy;

    INSERT INTO bkm.StokAyBakiyeMekanBazli (Donem, stkID, ehMekan, Stok, Kaynak)
    SELECT @sonAy, stkID, 12, CONVERT(int, SUM(Stok)), ''WMS''
    FROM depo.stok_adres_palet_vw WITH(NOLOCK)
    WHERE Stok <> 0 AND adrsAlanTipID IN (0, 1)
    GROUP BY stkID;

    PRINT ''WMS depo satiri: '' + CONVERT(varchar(20), @@ROWCOUNT);

    /* 2) SUBE (mekan 1/4477/4478) - irsHrk kumulatif ay-sonu bakiye. IDEMPOTENT tam kurulum.
          Running-sum tum gecmisi gerektirdigi icin artimli yazilmiyor; ay sonu 23:30''da kosar. */
    DELETE FROM bkm.StokAyBakiyeMekanBazli WHERE Kaynak = ''irsHrk'';

    ;WITH aylik_delta AS (
        SELECT h.ehstkID, h.ehMekan, EOMONTH(h.ehTrhS) AS Donem, SUM(h.ehAdetN) AS delta
        FROM dbo.irsHrk h WITH(NOLOCK)
        WHERE h.ehAltDepo = 0 AND h.ehMekan IN (1, 4477, 4478)
        GROUP BY h.ehstkID, h.ehMekan, EOMONTH(h.ehTrhS)
    ),
    bakiye AS (
        SELECT ehstkID, ehMekan, Donem,
               SUM(delta) OVER (PARTITION BY ehstkID, ehMekan ORDER BY Donem
                                ROWS UNBOUNDED PRECEDING) AS Stok
        FROM aylik_delta
    )
    INSERT INTO bkm.StokAyBakiyeMekanBazli (Donem, stkID, ehMekan, Stok, Kaynak)
    SELECT Donem, ehstkID, ehMekan,
           CASE WHEN Stok < 0 THEN 0 ELSE CONVERT(int, Stok) END,
           ''irsHrk''
    FROM bakiye;

    PRINT ''Sube satiri: '' + CONVERT(varchar(20), @@ROWCOUNT);
END;
',
     @retry_attempts = 1,
     @retry_interval = 5,
     @on_success_action = 1,
     @on_fail_action = 2;

/* Zamanlama: HER AYIN SON GUNU 23:30
   freq_type=32 (monthly relative) · freq_interval=9 (Day) · freq_relative_interval=16 (Last) */
EXEC msdb.dbo.sp_add_jobschedule
     @job_id = @jobId,
     @name = N'Ayin son gunu 23:30',
     @enabled = 1,
     @freq_type = 32,
     @freq_interval = 9,
     @freq_relative_interval = 16,
     @freq_recurrence_factor = 1,
     @active_start_time = 233000;

EXEC msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)';

PRINT 'Job kuruldu: BKM-Stok-AyBakiye-AySonu';
