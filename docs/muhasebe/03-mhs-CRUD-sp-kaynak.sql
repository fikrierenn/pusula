-- =============================================================================
-- DerinSISBkm — mhs schema CRUD + okuma + onay + yardımcı nesneleri
-- =============================================================================
-- Hepsi WITH ENCRYPTION ile derlenmiş. Kaynaklar burada arşivleniyor.
-- Komple modül haritası:
--   READ      : mhs.mhsFis_vw         (signed → Borç/Alacak ayrımı)
--   WRITE M   : mhs.mhsFisB_ekle      (master upsert: @ID=0→insert, !=0→update)
--   WRITE D   : mhs.mhsFis_ekle       (detay insert)
--   WORKFLOW  : mhs.mhsFis_onay       (onay/onay-kaldır + audit)
--   HELPER    : mhs.mhsSonYevmiyeNo   (yeni yevmiye no üretici)
--   DELETE    : mhs.mhsFis_sil        → ayrı dosya: 01-mhsFis_sil-kaynak.sql
-- =============================================================================
USE DerinSISBkm
GO


-- =============================================================================
-- VIEW: mhs.mhsFis_vw
-- Detay fişi hesap planıyla join'leyip Borç/Alacak ayrımı veren rapor view'ı.
-- KRİTİK: mhsFis.fisTutar SIGNED — negatif = Borç, pozitif = Alacak.
-- Aynı kural fisTutarDvz için de geçerli (sadece fisDvzID<>1 ise dökülür).
-- =============================================================================
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO

CREATE VIEW [mhs].[mhsFis_vw]
WITH ENCRYPTION
AS
SELECT  fsID,
        fisID,
        fisSirketID,
        yevmiyeNo,
        fisTarih,
        fisTip,
        fisBA,
        (CASE WHEN fisTutar < 0 THEN fisTutar ELSE 0 END) AS Borc,
        (CASE WHEN fisTutar > 0 THEN fisTutar ELSE 0 END) AS Alacak,
        fisEntID,
        fisHspID,
        fisAciklama,
        hspKod,
        hspAd,
        fisGdrMerkez,
        fisDvzID,
        (CASE WHEN fisDvzID = 1 THEN 0
              ELSE (CASE WHEN fisTutarDvz < 0 THEN fisTutarDvz ELSE 0 END) END) AS DovizBorc,
        (CASE WHEN fisDvzID = 1 THEN 0
              ELSE (CASE WHEN fisTutarDvz > 0 THEN fisTutarDvz ELSE 0 END) END) AS DovizAlacak
FROM    mhs.mhsFis
        INNER JOIN mhs.mhsHsp ON fisHspID = hspID
GO


-- =============================================================================
-- SP: mhs.mhsSonYevmiyeNo
-- Bir şirket için bir sonraki yevmiye no'yu döner. Hiç fiş yoksa 1.
-- Concurrency notu: serial olmayan, sadece SELECT. Aynı anda iki kullanıcı
-- aynı no'yu kapabilir → ekleme noktasında race riski. (Bilgi.)
-- =============================================================================
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [mhs].[mhsSonYevmiyeNo]
    @SirketID tinyint
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
    SELECT isnull(max(yevmiyeno + 1), 1) AS son
    FROM   mhs.mhsFisBaslik
    WHERE  fisbSirketID = @SirketID
END
GO


-- =============================================================================
-- SP: mhs.mhsFisB_ekle  —  Master fiş başlığı UPSERT
-- @ID = 0 → INSERT (yeni fiş; SCOPE_IDENTITY ile ID üretilir, döner)
-- @ID > 0 → UPDATE (mevcut fişin başlık alanları güncellenir)
-- Audit: drn2.islem  → 2=Kaydet, 3=Değiştir
-- =============================================================================
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [mhs].[mhsFisB_ekle]
        @ID         int,
        @SirketID   tinyint,
        @Ad         varchar(50),
        @YevmiyeNo  int,
        @Tarih      smalldatetime,
        @Tip        tinyint,
        @Grp        tinyint,
        @EntTip     tinyint,
        @kKisi      int,
        @fiscID     int           = 0,
        @kTarih     smalldatetime,
        @progAd     varchar(10)   = 'Mhs'
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

    IF @ID = 0
    BEGIN
        INSERT INTO mhs.mhsFisBaslik
            (fisbSirketID, fisAd, yevmiyeno, fisTarih, fisTip, fisGrp,
             fisEntTipID, fiscID, gKisi, kKisi, oKisi)
        VALUES
            (@SirketID, @Ad, @YevmiyeNo, @Tarih, @Tip, @Grp,
             @EntTip, @fiscID, @kKisi, @kKisi, @kKisi)

        SET @ID = SCOPE_IDENTITY()

        INSERT INTO drn2 (izProgID, izTip, izBlg, izKisi, islem, islemNot, izBlgID)
        SELECT 55, 0, host_name(), @kKisi, 2,
               CAST(@YevmiyeNo AS varchar) + ' '
               + CAST(@Tarih AS varchar(11)) + ' ['
               + CAST(@entTip AS varchar) + '] kaydedildi,Prg=' + @progAd,
               @ID
    END
    ELSE
    BEGIN
        INSERT INTO drn2 (izProgID, izTip, izBlg, izKisi, islem, islemNot, izBlgID)
        SELECT 55, 0, host_name(), @kKisi, 3,
               CAST(@YevmiyeNo AS varchar) + ' '
               + CAST(@Tarih AS varchar(11)) + ' ['
               + CAST(@entTip AS varchar) + '] değiştirildi,Prg=' + @progAd,
               @ID

        UPDATE mhs.mhsFisBaslik
        SET    fisbSirketID = @SirketID,
               fisAd        = @Ad,
               yevmiyeno    = @YevmiyeNo,
               fisTarih     = @Tarih,
               fisTip       = @Tip,
               fisGrp       = @Grp,
               fisEntTipID  = @EntTip,
               fiscID       = @fiscID,
               kKisi        = @kKisi,
               kTarih       = @kTarih
        WHERE  fisbID = @ID
    END

    SELECT @ID
END
GO


-- =============================================================================
-- SP: mhs.mhsFis_ekle  —  Detay (mahsup) satırı INSERT
-- Sadece insert (update yok). SCOPE_IDENTITY ile yeni satırın ID'si döner.
-- Master ile aynı yevmiyeNo / fisTarih / fisTip taşır (denormalize).
-- =============================================================================
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [mhs].[mhsFis_ekle]
        @FisBID     int,
        @SirketID   tinyint,
        @YevmiyeNo  int,
        @Tarih      smalldatetime,
        @Tip        tinyint,
        @BA         tinyint,
        @Tutar      decimal(15,2),
        @EntID      int,
        @HspID      int,
        @Aciklama   varchar(50),
        @gdrMerkez  int          = 0,
        @fisCari    tinyint      = 0
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ID int

    INSERT INTO mhs.mhsFis
        (fisID, fisSirketID, yevmiyeno, fisTarih, fisTip, fisBA, fisTutar,
         fisEntID, fisHspID, fisAciklama, fisGdrMerkez, fisCari)
    VALUES
        (@FisBID, @SirketID, @YevmiyeNo, @Tarih, @Tip, @BA, @Tutar,
         @EntID, @HspID, @Aciklama, @gdrMerkez, @fisCari)

    SET @ID = SCOPE_IDENTITY()
    SELECT @ID
END
GO


-- =============================================================================
-- SP: mhs.mhsFis_onay  —  Onay / onay-kaldır + audit
-- @onay = 1 → onay; @onay = 0 → onay kaldır
-- Audit: drn2.islem = 5 + (1 - @onay)
--        @onay=1 → islem=5  (onay)
--        @onay=0 → islem=6  (onay kaldır)
-- =============================================================================
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [mhs].[mhsFis_onay]
    (@fisID int, @onay tinyint, @oKisi int)
WITH ENCRYPTION
AS
    SET NOCOUNT ON

    DECLARE @yevmiyeNo varchar(10)
    SELECT @yevmiyeNo = yevmiyeNo
    FROM   mhs.mhsFisBaslik
    WHERE  fisbID = @fisID

    UPDATE mhs.mhsFisBaslik
    SET    fisOnay = @onay,
           oKisi   = @oKisi,
           oTarih  = getdate()
    WHERE  fisbID = @fisID

    INSERT INTO drn2 (izProgID, izTip, izBlg, izKisi, islem, islemNot, izBlgID)
    SELECT 55, 0, host_name(), @oKisi, 5 + (1 - @onay),
           @yevmiyeNo + ' onay durum=' + CAST(@onay AS varchar(1)),
           @fisID

    RETURN @onay
GO
