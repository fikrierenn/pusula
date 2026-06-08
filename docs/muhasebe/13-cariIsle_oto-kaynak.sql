-- =============================================================================
-- mhs.cariIsle_oto — E-fatura/CRM kaynaklı günlük cari → muhasebe robot SP'si
-- =============================================================================
-- Encryption YOK. Kaynak DerinSISBkm.sys.sql_modules.definition'dan çekildi.
-- Dosya: docs/muhasebe/13-cariIsle_oto-kaynak.sql
--
-- AMAÇ: BUGÜN CRM tarafından üretilmiş cari hareketleri otomatik olarak
--       muhasebe defterine entegre eder. Sahte "robot" kullanıcı adına çalışır.
--       Yıl-sonu kapanışla ilgisi yok — gecelik akış otomasyonu.
-- =============================================================================
USE DerinSISBkm
GO

CREATE PROC [mhs].[cariIsle_oto]
AS

/*
    Buradaki prosedür yalnızca çalıştığı günün evrakları kontrol ediyor.
    Ayrıca bu evrakların cari işlem aralığında olması da kontrol ediliyor.
*/

DECLARE @tablo TABLE (
    id      int,
    no      varchar(max),
    tarih   smalldatetime,
    tip     varchar(30),
    frmad1  varchar(max),
    frmad2  varchar(max),
    tutar   decimal(25,2),
    ins     int,
    kull    varchar(max)
)

DECLARE @tarih1        smalldatetime = CAST(GETDATE() - 3 AS DATE)   -- 3 gün öncesi
DECLARE @tarih2        smalldatetime = CAST(GETDATE() AS DATE)        -- bugün
DECLARE @cariIlkTarih  smalldatetime
DECLARE @sirket        int
DECLARE @kisi          int

-- Aktif yıl (varsayılan) şirketi al
SELECT @sirket = sirketID
FROM   mhs.mhsSirket
WHERE  sirketOnce = 1
   AND YEAR(GETDATE()) = sirketDonem

-- Robot kullanıcı + cari işlemler başlangıç tarihi (system ayarları)
SELECT @kisi          = ayarDeger FROM drn2ayar WHERE ayarID = 920   -- e-fatura robot kullanıcısı
SELECT @cariIlkTarih  = ayarDeger FROM drn2ayar WHERE ayarID = 154   -- cari işlemler başlangıç tarihi

-- 3 günlük pencerede entegre edilmemiş cari adaylarını topla
INSERT INTO @tablo
EXEC mhs.mhsEntKontrolCar @tarih1, @tarih2, @sirket, 0, 0

-- Cursor ile bugün girilmiş + CRM kaynaklı + mali başlangıçtan sonra kayıtlar
DECLARE @cariID int
DECLARE db_cursor CURSOR FOR
    SELECT id
    FROM   @tablo
    INNER JOIN car ON cID = id
    WHERE  CAST(cgTarih AS DATE) >= @cariIlkTarih              -- cari işlemler başlangıcından sonra
      AND  CAST(cgTarih AS DATE) =  CAST(GETDATE() AS DATE)    -- BUGÜN girilmiş
      AND  cCrmID > 0                                          -- CRM kaynaklı (manuel hariç)

OPEN db_cursor
FETCH NEXT FROM db_cursor INTO @cariID

WHILE @@FETCH_STATUS = 0
BEGIN
    -- Her cari hareketi tek tek mhs.mhsFis'e entegre et
    EXEC mhs.mhsEnt_car @cariID, @sirket, 0, @kisi
    FETCH NEXT FROM db_cursor INTO @cariID
END

CLOSE db_cursor
DEALLOCATE db_cursor
GO
