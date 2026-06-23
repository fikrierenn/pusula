/* =====================================================================================
   Kontrol paneli SP perf TEST — SSMS'te çalıştır, "Messages" sekmesindeki ms değerlerini bana ver.
   Hangi kaynağın (CAR/FAT/MHS) yavaş olduğunu izole eder. DerinSISBkm. Salt-okuma SP (veri yazmaz).
   ÖNCE bir kez "warm-up" çalıştır (cache ısınsın), İKİNCİ koşunun ms'lerini al.
   ===================================================================================== */
USE DerinSISBkm;
SET NOCOUNT ON;
DECLARE @t datetime2(3);

-- En yeni kapanmış dönemi otomatik al (panel ilk-açılış bu dönemi yükler)
DECLARE @Yil int, @Ay int;
SELECT TOP 1 @Yil = DonemYil, @Ay = DonemAy
FROM bkm.Fin_AyKapanis ORDER BY DonemYil DESC, DonemAy DESC;
PRINT 'Test dönemi: ' + CAST(@Ay AS varchar) + '.' + CAST(@Yil AS varchar);
PRINT '----------------------------------------';

-- 1) CAR
SET @t = SYSDATETIME();
EXEC bkm.sp_KapanisMudahaleKontrol_v2 @Yil=@Yil, @Ay=@Ay, @Kaynak='CAR', @SadeceGider=1, @Mod='OZET';
PRINT 'CAR : ' + CAST(DATEDIFF(MILLISECOND, @t, SYSDATETIME()) AS varchar) + ' ms';

-- 2) FAT
SET @t = SYSDATETIME();
EXEC bkm.sp_KapanisMudahaleKontrol_v2 @Yil=@Yil, @Ay=@Ay, @Kaynak='FAT', @SadeceGider=1, @Mod='OZET';
PRINT 'FAT : ' + CAST(DATEDIFF(MILLISECOND, @t, SYSDATETIME()) AS varchar) + ' ms';

-- 3) MHS
SET @t = SYSDATETIME();
EXEC bkm.sp_KapanisMudahaleKontrol_v2 @Yil=@Yil, @Ay=@Ay, @Kaynak='MHS', @SadeceGider=1, @Mod='OZET';
PRINT 'MHS : ' + CAST(DATEDIFF(MILLISECOND, @t, SYSDATETIME()) AS varchar) + ' ms';

-- 4) HEPSI (panelin gerçek çağrısı)
SET @t = SYSDATETIME();
EXEC bkm.sp_KapanisMudahaleKontrol_v2 @Yil=@Yil, @Ay=@Ay, @Kaynak='HEPSI', @SadeceGider=1, @Mod='OZET';
PRINT 'HEPSI: ' + CAST(DATEDIFF(MILLISECOND, @t, SYSDATETIME()) AS varchar) + ' ms  <-- panel bunu çağırır';
PRINT '----------------------------------------';
PRINT 'Bu 4 ms değerini bana gönder. Yavaş olan kaynağı (CAR/FAT/MHS) hedefleriz.';
