-- =============================================================================
-- mhs.mhsFis_cikar — Bir mhs fişinden bir entegrasyon belgesini ÇIKAR
-- =============================================================================
-- WITH ENCRYPTION ile derlenmiş. Kaynak burada arşivleniyor.
--
-- AMAÇ: mhsFis_sil tüm fişi siler. Bu SP ise — fiş içinden
--       SADECE belirli bir entegrasyon belgesinin (fat/cari) satırlarını
--       çıkarır. Master fiş, tüm detayı silinmediği sürece DURUR.
--
-- ÇALIŞTIĞI ENTTIP'LER:
--   1 = Fatura  → fat.eMhsFisID=0, ilgili car.cMhsFisID=0
--   2 = Cari    → car.cMhsFisID=0 (hem ana cID hem karşı taraf cBag)
--
-- DİĞER ENTTIP'LER (0,3,4,5) için ÇIKAR YOK — RAISERROR ile reddedilir.
-- =============================================================================
USE DerinSISBkm
GO

SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [mhs].[mhsFis_cikar]
    @fisEntID  int,
    @fisID     int,
    @kisi      int          = 0,
    @progAd    varchar(10)  = 'Mhs'
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON

    DECLARE @aciklama varchar(50)

    ---------------------------------------------------------------------------
    -- 1) Belge ID 0 reddedilir (defansif)
    ---------------------------------------------------------------------------
    IF @fisEntID = 0
    BEGIN
        SET @aciklama = 'Belge ID 0 gönderilemez, FişID='
                        + CAST(@fisID AS varchar(10))
                        + ',BelgeID=' + CAST(@fisEntID AS varchar(10))
        RAISERROR (@aciklama, 11, 1)
        RETURN
    END

    ---------------------------------------------------------------------------
    -- 2) Fişin temel bilgilerini çek (entTip, sirket, tarih, sıralama tarihi)
    ---------------------------------------------------------------------------
    DECLARE @sirket          tinyint
    DECLARE @entTip          tinyint
    DECLARE @fisTarih        smalldatetime
    DECLARE @siralamaTarihi  smalldatetime

    SELECT  @entTip          = fisEntTipID,
            @sirket          = fisbSirketID,
            @fisTarih        = fisTarih,
            @siralamaTarihi  = sirketSiraliTarih
    FROM    mhs.mhsFisBaslik
            INNER JOIN mhs.mhsSirket ON sirketID = fisbSirketID
    WHERE   fisbID = @fisID

    ---------------------------------------------------------------------------
    -- 3) Sıralama tarihi koruması (kapanmış dönem)
    ---------------------------------------------------------------------------
    IF @fisTarih <= @siralamaTarihi
    BEGIN
        SET @aciklama = 'Sıralama tarihinden önce, FişID='
                        + CAST(@fisID AS varchar(10))
                        + ',BelgeID=' + CAST(@fisEntID AS varchar(10))
        RAISERROR (@aciklama, 11, 1)
        RETURN
    END

    ---------------------------------------------------------------------------
    -- 4) entTip kontrolü — sadece 1 (Fatura) ve 2 (Cari) için çıkarma var
    ---------------------------------------------------------------------------
    IF @entTip NOT IN (1, 2)
    BEGIN
        SET @aciklama = 'Enteg. çıkarılamaz, FişID='
                        + CAST(@fisID AS varchar(10))
                        + ',BelgeID=' + CAST(@fisEntID AS varchar(10))
        RAISERROR (@aciklama, 11, 1)
        RETURN
    END

    ---------------------------------------------------------------------------
    -- 5) Bağlantı doğrulama — bu fisEntID gerçekten bu fişin satırlarında var mı?
    ---------------------------------------------------------------------------
    DECLARE @sorunVar tinyint
    SET @sorunVar = 0

    IF NOT EXISTS (
        SELECT TOP 1 *
        FROM   mhs.mhsFis
        WHERE  fisID = @fisID AND fisEntID = @fisEntID
    )
    BEGIN
        IF @entTip = 2  -- cariden borç olan entegre edilmişse
        BEGIN
            -- car.cBag (alt cari) üzerinden de eşleşme arıyoruz
            IF EXISTS (
                SELECT TOP 1 *
                FROM   mhs.mhsFis, car
                WHERE  fisID = @fisID
                  AND  fisEntID = cBag
                  AND  cID = @fisEntID
            )
                SELECT @fisEntID = cBag FROM car WHERE cID = @fisEntID
            ELSE
                SET @sorunVar = 1
        END
        ELSE
            SET @sorunVar = 1
    END

    IF @sorunVar > 0
    BEGIN
        SET @aciklama = 'Enteg. bağlantısı yok, FişID='
                        + CAST(@fisID AS varchar(10))
                        + ',BelgeID=' + CAST(@fisEntID AS varchar(10))
        RAISERROR (@aciklama, 11, 1)
        RETURN
    END

    ---------------------------------------------------------------------------
    -- (KAPALI BLOK) entTip=5 (Cari Fiş) için çıkarma yasaklı — yorum satırı
    -- IF @entTip = 5
    -- BEGIN
    --     IF EXISTS(SELECT TOP 1 * FROM mhs.mhsFis WHERE fisID=@fisID AND fisCari=1)
    --     BEGIN
    --         SET @aciklama = 'Enteg. çıkarılamaz, FişID=...'
    --         RAISERROR (@aciklama, 11, 1)
    --         RETURN
    --     END
    -- END
    ---------------------------------------------------------------------------

    DECLARE @ErrorMessage NVARCHAR(4000)
    DECLARE @ErrorSeverity INT
    DECLARE @ErrorState INT

    BEGIN TRANSACTION
    BEGIN TRY

        -- 6) Kaynak modüldeki entegrasyon flag'lerini sıfırla
        IF @entTip = 1  -- FATURA
        BEGIN
            UPDATE fat
               SET eMhsFisID = 0
             WHERE eID = @fisEntID

            UPDATE car
               SET cMhsFisID = 0
             WHERE cFatTip < 13
               AND cFatID  <> 0
               AND cFatID   = @fisEntID
        END

        IF @entTip = 2  -- CARİ
            UPDATE car
               SET cMhsFisID = 0
             WHERE cID = @fisEntID
                OR (cKodKarsi <> 0 AND cBag = @fisEntID)

        -- (Yorum satırı kapalı: entTip=5 için iş yok — cari fişler tek başına entegre)
        --     UPDATE car SET cMhsFisID=0 WHERE cFatID=@fisEntID

        -- 7) Bu belgenin mhs detay satırlarını sil
        DELETE FROM mhs.mhsFis
         WHERE fisID    = @fisID
           AND fisEntID = @fisEntID

        -- 8) Audit
        INSERT INTO drn2 (izProgID, izTip, izBlg, izKisi, islem, islemNot, izBlgID)
        SELECT 55, 0, host_name(), @kisi, 4,
               CAST(yevmiyeNo AS varchar(10)) + '-'
                + CAST(fisTarih  AS varchar(11)) + ' ['
                + CAST(@entTip   AS varchar)     + '] ['
                + CAST(isNull(@fisEntID, '') AS varchar) + '] çıkarıldı,Prg=' + @progAd,
               @fisID
        FROM   mhs.mhsFisBaslik
        WHERE  fisbID = @fisID

        -- 9) Eğer bu fişin BAŞKA detayı kalmadıysa master'ı da sil
        IF NOT EXISTS (SELECT TOP 1 * FROM mhs.mhsFis WHERE fisID = @fisID)
            DELETE FROM mhs.mhsFisBaslik WHERE fisbID = @fisID

        COMMIT TRANSACTION
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION
        SELECT @ErrorMessage  = ERROR_MESSAGE(),
               @ErrorSeverity = ERROR_SEVERITY(),
               @ErrorState    = ERROR_STATE()
        RAISERROR (@ErrorMessage, @ErrorSeverity, @ErrorState)
    END CATCH
END
GO
