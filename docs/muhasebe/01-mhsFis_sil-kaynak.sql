-- =============================================================================
-- mhs.mhsFis_sil  —  Muhasebe fişi silme prosedürü
-- DerinSISBkm
-- =============================================================================
-- WITH ENCRYPTION ile derlenmiş. Kaynak burada arşivleniyor (kaybolmasın).
-- Açık adı: muhasebe fişini (master + detay) güvenli şekilde sil; bağlı
-- entegrasyon kayıtlarını (fat/car/ith/pos) referansını boşa çek; arşive yaz;
-- denetim izine düş.
-- =============================================================================

USE DerinSISBkm
GO

SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [mhs].[mhsFis_sil]
    @fisID    int,
    @belgeyi  tinyint     = 0,        -- 1 ise master (mhsFisBaslik) da silinir
    @kisi     int         = 0,        -- audit için kullanıcı ID
    @progAd   varchar(10) = 'Mhs'     -- audit için çağıran program kodu
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON

    DECLARE @sirket          tinyint
    DECLARE @entTip          tinyint
    DECLARE @fisTarih        smalldatetime
    DECLARE @siralamaTarihi  smalldatetime
    DECLARE @fiscID          int
    DECLARE @aciklama        varchar(50)

    -- ---------------------------------------------------------------------
    -- 1) Fişi yükle (master + şirket sıralama tarihi)
    -- ---------------------------------------------------------------------
    SELECT  @entTip          = fisEntTipID,
            @sirket          = fisbSirketID,
            @fisTarih        = fisTarih,
            @siralamaTarihi  = sirketSiraliTarih,
            @fiscID          = fiscID
    FROM    mhs.mhsFisBaslik
            INNER JOIN mhs.mhsSirket ON sirketID = fisbSirketID
    WHERE   fisbID = @fisID

    -- ---------------------------------------------------------------------
    -- 2) Mali sıralama tarihi koruması (kapanmış dönem fişi silinemez)
    -- ---------------------------------------------------------------------
    IF @fisTarih <= @siralamaTarihi
    BEGIN
        SET @aciklama = 'Sıralama tarihinden önce, FişID=' + CAST(@fisID AS varchar(10))
        RAISERROR (@aciklama, 11, 1)
        RETURN
    END

    -- ---------------------------------------------------------------------
    -- 3) İthalat/İhracat KAPANIŞ fişi kontrolü
    --    (Bu fiş bir ith dosyasının kapanış mhs fişi ise, sadece IthKpn
    --    programı silebilir.)
    -- ---------------------------------------------------------------------
    DECLARE @ithID int

    SELECT  @ithID     = ithID,
            @aciklama  = (CASE WHEN ithTip = 0 THEN 'ithalat' ELSE 'ihracat' END)
    FROM    ith
    WHERE   ithKapanisMhsFis = @fisID

    IF @ithID > 0 AND @progAd <> 'IthKpn'
    BEGIN
        SET @aciklama = CAST(@fisID AS varchar(10))
                        + ' numaralı fiş, '
                        + CAST(@ithID AS varchar(10)) + '. '
                        + @aciklama + ' kapanış fişidir.'
        RAISERROR (@aciklama, 11, 1)
        RETURN
    END

    -- ---------------------------------------------------------------------
    -- 4) İthalat/İhracat AÇIK DOSYA kontrolü (entTip 1,2,5)
    --    Cari hareket üzerinden bu fişe bağlı ithalat dosyası varsa ve
    --    durumu "açık" (=1) ise silinemez.
    -- ---------------------------------------------------------------------
    DECLARE @ithDurum tinyint

    IF @entTip IN (1, 2, 5)
    BEGIN
        SELECT  @ithDurum  = ithDurum,
                @ithID     = ithID,
                @aciklama  = (CASE WHEN ithTip = 0 THEN 'ithalat' ELSE 'ihracat' END)
        FROM    car
                INNER JOIN ith ON cIthID = ithID
        WHERE   cMhsfisID = @fisID

        IF @ithDurum = 1
        BEGIN
            SET @aciklama = CAST(@fisID AS varchar(10))
                            + ' numaralı fiş, '
                            + CAST(@ithID AS varchar(10)) + '. '
                            + @aciklama + ' dosyasına bağlı'
            RAISERROR (@aciklama, 11, 1)
            RETURN
        END
    END

    -- ---------------------------------------------------------------------
    -- 5) POS entegrasyon ANA fişi kontrolü (entTip=3, e-Defter güvencesi)
    --    Bir mekan-gün için sadece "ana" pos entegrasyon fişi silinebilir;
    --    ona bağlı diğer fişler bu SP üzerinden tek tek silinmez.
    -- ---------------------------------------------------------------------
    IF @entTip = 3
    BEGIN
        IF (SELECT COUNT(*) FROM posOzetMagazaGun WHERE pMhsfisID = @fisID) = 0
        BEGIN
            SET @aciklama = CAST(@fisID AS varchar(10)) + ' fiş, ana pos entegrasyon fişi değil.'
            RAISERROR (@aciklama, 11, 1)
            RETURN
        END
    END

    -- =====================================================================
    -- ASIL SİLME — TRANSACTION içinde
    -- =====================================================================
    DECLARE @ErrorMessage  NVARCHAR(4000)
    DECLARE @ErrorSeverity INT
    DECLARE @ErrorState    INT

    BEGIN TRANSACTION
    BEGIN TRY

        IF @belgeyi > 0
        BEGIN
            DECLARE @fisEntID int
            SELECT TOP 1 @fisEntID = fisEntID
            FROM   mhs.mhsFis
            WHERE  fisID = @fisID

            -- 5.1 Şirketin AÇILIŞ / KAPANIŞ fiş referanslarını boşa çek
            DECLARE @ilkFis int
            DECLARE @sonFis int
            SELECT  @ilkFis = sirketIlkFisID,
                    @sonFis = sirketSonFisID
            FROM    mhs.mhsSirket
            WHERE   sirketID = @sirket

            IF @ilkFis = @fisID
            BEGIN
                UPDATE mhs.mhsSirket SET sirketIlkFisID = 0 WHERE sirketID = @sirket
                INSERT INTO drn2 (izProgID, izTip, izBlg, izKisi, islem, islemNot, izBlgID)
                SELECT 55, 0, host_name(), @kisi, 4,
                       'Açılış fişi silindi. Şirket no:' + CAST(@sirket AS varchar(10)),
                       @fisID
                FROM   mhs.mhsFisBaslik WHERE fisbID = @fisID
            END

            IF @sonFis = @fisID
            BEGIN
                UPDATE mhs.mhsSirket SET sirketSonFisID = 0 WHERE sirketID = @sirket
                INSERT INTO drn2 (izProgID, izTip, izBlg, izKisi, islem, islemNot, izBlgID)
                SELECT 55, 0, host_name(), @kisi, 4,
                       'Kapanış fişi silindi. Şirket no:' + CAST(@sirket AS varchar(10)),
                       @fisID
                FROM   mhs.mhsFisBaslik WHERE fisbID = @fisID
            END

            -- 5.2 entTip = 1 (FATURA entegrasyonu)
            IF @entTip = 1
            BEGIN
                UPDATE fat
                SET    eMhsFisID = 0
                WHERE  eID IN (SELECT DISTINCT mhs.mhsFis.fisEntID FROM mhs.mhsFis WHERE fisID = @fisID)

                UPDATE car
                SET    cMhsFisID = 0
                WHERE  cFatTip < 13
                  AND  cFatID <> 0
                  AND  cFatID IN (SELECT DISTINCT mhs.mhsFis.fisEntID FROM mhs.mhsFis WHERE fisID = @fisID)
            END

            -- 5.3 entTip IN (2, 4)  (CARİ entegrasyonu)
            IF @entTip IN (2, 4)
                UPDATE car
                SET    cMhsFisID = 0
                WHERE  cID IN (SELECT DISTINCT mhs.mhsFis.fisEntID FROM mhs.mhsFis WHERE fisID = @fisID)
                   OR  (cKodKarsi <> 0 AND cBag <> 0
                        AND cBag IN (SELECT DISTINCT mhs.mhsFis.fisEntID FROM mhs.mhsFis WHERE fisID = @fisID))

            -- 5.4 entTip = 5  (İTHALAT/İHRACAT)
            IF @entTip = 5
            BEGIN
                IF @fiscID > 0
                BEGIN
                    DECLARE @fisCari int
                    SELECT TOP 1 @fisCari = fisCari
                    FROM   mhs.mhsFis
                    WHERE  fisID = @fisID AND fisCari > 0

                    IF @fisCari > 0
                    BEGIN
                        DELETE FROM carNot
                        WHERE  cnID IN (SELECT cID FROM car WHERE (cFatTip BETWEEN 20 AND 199) AND cFatID = @fiscID)

                        DELETE FROM car
                        WHERE  (cFatTip BETWEEN 20 AND 199) AND cFatID = @fiscID

                        INSERT INTO drn2 (izProgID, izTip, izBlg, izKisi, islem, islemNot, izBlgID)
                        SELECT 11, 0, host_name(), @kisi, 4,
                               'Cari fiş mhs fişle silindi-' + @progAd,
                               @fiscID
                    END
                END

                UPDATE car
                SET    cMhsFisID = 0
                WHERE  cID IN (SELECT DISTINCT mhs.mhsFis.fisEntID FROM mhs.mhsFis WHERE fisID = @fisID)
                   OR  (cKodKarsi <> 0 AND cBag <> 0
                        AND cBag IN (SELECT DISTINCT mhs.mhsFis.fisEntID FROM mhs.mhsFis WHERE fisID = @fisID))
            END

            -- 5.5 entTip = 3  (POS entegrasyonu — e-Defter mekan-gün ana fişi)
            IF @entTip = 3
            BEGIN
                DECLARE @mkn int
                SELECT @mkn = magazaID FROM posOzetMagazaGun WHERE pMhsFisID = @fisID

                UPDATE posOzetMagazaGun SET pMhsFisID = 0 WHERE pMhsFisID = @fisID
                UPDATE dbo.car          SET cMhsFisID = 0 WHERE cMhsFisID = @fisID

                -- Aynı tarih + mağaza için diğer mağaza-kasa fişlerini topla
                DECLARE @digerMagazaKasa table (fID int)
                INSERT INTO @digerMagazaKasa
                SELECT DISTINCT cMhsFisID
                FROM   car
                WHERE  car.cTarih = @fisTarih
                  AND  (car.cKod = @mkn OR car.cKodKarsi = @mkn)
                  AND  ((cFatTip BETWEEN 20 AND 199) OR cFatTip = 13)
                  AND  cMhsFisID != 0

                IF (SELECT COUNT(*) FROM @digerMagazaKasa) > 0
                BEGIN
                    UPDATE dbo.car
                    SET    cMhsFisID = 0
                    WHERE  cMhsFisID IN (SELECT fID FROM @digerMagazaKasa)

                    DELETE FROM mhs.mhsFis        WHERE fisID  IN (SELECT fID FROM @digerMagazaKasa)
                    DELETE FROM mhs.mhsFisBaslik  WHERE fisbID IN (SELECT fID FROM @digerMagazaKasa)
                END

                -- Aynı tarih + mağaza için Z bazlı kasa fişlerini topla
                DECLARE @digerZBazliKasa table (fID int)
                INSERT INTO @digerZBazliKasa
                SELECT DISTINCT fisID
                FROM   mhs.mhsFis
                       INNER JOIN mhs.mhsFisBaslik ON fisBID = fisID
                WHERE  mhsFisBaslik.fisTarih = @fisTarih
                  AND  fisEntID    = @mkn
                  AND  fisEntTipID = 3

                IF (SELECT COUNT(*) FROM @digerZBazliKasa) > 0
                BEGIN
                    DELETE FROM mhs.mhsFis        WHERE fisID  IN (SELECT fID FROM @digerZBazliKasa)
                    DELETE FROM mhs.mhsFisBaslik  WHERE fisbID IN (SELECT fID FROM @digerZBazliKasa)
                    UPDATE      posOzetOdemeZ SET zMhsFisID = 0
                    WHERE       zMhsFisID IN (SELECT fID FROM @digerZBazliKasa)
                END
            END
        END

        -- ---------------------------------------------------------------------
        -- 6) ARŞİV — silinen fiş satırlarını sil.mhsFis'e snapshot olarak yaz
        -- ---------------------------------------------------------------------
        INSERT INTO sil.mhsFis
            (fsID, fisID, fisSirketID, yevmiyeNo, fisTarih, fisTip, fisHspID,
             fisAciklama, fisBA, fisTutar, fisEntID, fisGdrMerkez, fisCari,
             fisAd, fisGrp, fisEntTipID, fiscID, fisOnay,
             gKisi, kKisi, oKisi, gTarih, kTarih, oTarih)
        SELECT  fsID, fisID, fisSirketID, b.yevmiyeNo, b.fisTarih, b.fisTip, fisHspID,
                fisAciklama, fisBA, fisTutar, fisEntID, fisGdrMerkez, fisCari,
                fisAd, fisGrp, fisEntTipID, fiscID, fisOnay,
                gKisi, kKisi, oKisi, gTarih, kTarih, oTarih
        FROM    mhs.mhsFisBaslik b
                INNER JOIN mhs.mhsFis f ON b.fisbID = f.fisID
        WHERE   f.fisID = @fisID

        -- ---------------------------------------------------------------------
        -- 7) Detay satırlarını (mahsup) sil
        -- ---------------------------------------------------------------------
        DELETE FROM mhs.mhsFis WHERE fisID = @fisID

        -- ---------------------------------------------------------------------
        -- 8) İstendiyse master satırını da sil + audit
        -- ---------------------------------------------------------------------
        IF @belgeyi > 0
        BEGIN
            INSERT INTO drn2 (izProgID, izTip, izBlg, izKisi, islem, islemNot, izBlgID)
            SELECT 55, 0, host_name(), @kisi, 4,
                   CAST(yevmiyeNo AS varchar(10)) + ' '
                   + CAST(fisTarih AS varchar(10)) + ' ['
                   + CAST(@entTip AS varchar) + '] ['
                   + CAST(isNull(@fisEntID, '') AS varchar) + '] silindi,Prg=' + @progAd,
                   @fisID
            FROM   mhs.mhsFisBaslik WHERE fisbID = @fisID

            DELETE FROM mhs.mhsFisBaslik WHERE fisbID = @fisID
        END

        COMMIT TRANSACTION
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION
        SELECT  @ErrorMessage  = ERROR_MESSAGE(),
                @ErrorSeverity = ERROR_SEVERITY(),
                @ErrorState    = ERROR_STATE();
        RAISERROR (@ErrorMessage, @ErrorSeverity, @ErrorState)
    END CATCH

END
GO
