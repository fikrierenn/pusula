-- =============================================================================
-- mhs.mhsKapanis — Mali yıl kapanış fişi üretici
-- =============================================================================
-- WITH ENCRYPTION ile derlenmiş. Kaynak burada arşivleniyor.
--
-- AMAÇ: Bir mali şirketin (yılın) tüm hesap bakiyelerini SIFIRLAYACAK
--       şekilde tek bir "Kapanış" mahsup fişi oluşturur. Her hesap için
--       toplam fisTutar'ın TERSİNİ yazarak hesap bakiyesini 0'a indirir.
--
-- ÖNEMLİ: Bu SP klasik TDHP yıl-sonu kapanışı (6xx → 690 → 691 → 692 → 590)
-- YAPMIYOR. Sadece "teknik bakiye sıfırlama" — kar/zarar yansıtması ve dönem
-- net karı taşıma operasyonları AYRICA manuel mahsupla yapılmalı.
-- =============================================================================
USE DerinSISBkm
GO

SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [mhs].[mhsKapanis]
    (@sirketID       tinyint,
     @giderMerkezli  tinyint,    -- 0 = GM'siz toplama; 1 = GM bazında ayrı satır
     @kKisi          int)
WITH ENCRYPTION
AS
BEGIN
    DECLARE @tarih       smalldatetime
    DECLARE @fisID       int
    DECLARE @yevmiyeNo   int

    ---------------------------------------------------------------------------
    -- 1) Yevmiye no ve tarih hesapla
    ---------------------------------------------------------------------------
    SELECT @yevmiyeNo = isnull(max(yevmiyeno + 1), 1),
           @tarih     = MAX(fisTarih)
    FROM   mhs.mhsFisBaslik
    WHERE  fisbSirketID = @SirketID

    -- Tarihi 31 Aralık aynı yıl olarak ayarla (string concatenation — DMY format!)
    SET @tarih = '31/12/' + CAST(YEAR(@tarih) AS varchar(4))

    ---------------------------------------------------------------------------
    -- 2) TL hijyen — fisDvzID=1 (TL) için fisTutarDvz'i sıfırla
    ---------------------------------------------------------------------------
    UPDATE mhs.mhsFis
       SET fisTutarDvz = 0
     WHERE fisDvzID    = 1
       AND fisSirketID = @sirketID

    ---------------------------------------------------------------------------
    -- 3) Kapanış MASTER fişi oluştur
    ---------------------------------------------------------------------------
    INSERT INTO mhs.mhsFisBaslik
        (fisbSirketID, fisAd, yevmiyeno, fisTarih, fisTip, fisGrp,
         fisEntTipID, gKisi, kKisi, oKisi)
    SELECT @sirketID, 'Kapanış', @yevmiyeNo, @tarih,
           2,                    -- fisTip = 2 (Mahsup)
           0,                    -- fisGrp = 0 (Genel)
           0,                    -- fisEntTipID = 0 (Kullanıcı)
           @kKisi, @kKisi, @kKisi

    SET @fisID = SCOPE_IDENTITY()

    ---------------------------------------------------------------------------
    -- 4) Audit — drn2.islem = 14 (KAPANIŞ — yeni audit kodu)
    ---------------------------------------------------------------------------
    INSERT INTO drn2 (izProgID, izTip, izBlg, izKisi, islem, islemNot, izBlgID)
    SELECT 55, 0, host_name(), @kKisi, 14,
           'Kapanış fişi oluşturuldu. Şirket no:' + CAST(@sirketID AS varchar),
           @fisID

    ---------------------------------------------------------------------------
    -- 5) Kapanış DETAY satırları — her hesap için TERS bakiye yazımı
    --     Sadece bakiyesi 0 olmayan hesaplar için
    ---------------------------------------------------------------------------
    INSERT INTO mhs.mhsFis
        (fisID, fisSirketID, yevmiyeNo, fisTarih, fisTip, fisBA, fisTutar,
         fisEntID, fisHspID, fisAciklama, fisGdrMerkez, fisDvzID, fisTutarDvz)
    SELECT @fisID, @sirketID, @yevmiyeNo, @tarih, 2,

           -- Ters BA (sadece UI için bilgi)
           (CASE WHEN SUM(fisTutar) > 0 THEN 1 ELSE 0 END) AS TersBA,

           -- Ters tutar (asıl signed kapanış değeri)
           -1 * SUM(fisTutar) AS TersTutar,

           0,                                  -- fisEntID = 0 (manuel mahsup)
           fisHspID,                           -- aynı hesap kodu
           'Kapanış',                          -- sabit açıklama
           @giderMerkezli * fisGdrMerkez,      -- 0 ise GM yok; 1 ise GM koru
           fisDvzID,
           -1 * SUM(fisTutarDvz) AS TersTutarDvz

    FROM   mhs.mhsFis
    WHERE  fisSirketID = @sirketID
       AND fisHspID IN (
                SELECT fisHspID
                FROM   mhs.mhsFis
                WHERE  fisSirketID = @sirketID
                GROUP BY fisHspID
                HAVING SUM(fisTutar) <> 0      -- bakiyesi sıfır olmayan hesaplar
            )
    GROUP BY fisHspID, @giderMerkezli * fisGdrMerkez, fisDvzID
    HAVING   SUM(fisTutar) <> 0

    ---------------------------------------------------------------------------
    -- 6) Şirket'in "son kapanış fişi" referansını güncelle
    ---------------------------------------------------------------------------
    UPDATE mhs.mhsSirket
       SET sirketSonFisID = @fisID
     WHERE sirketID       = @sirketID

    -- 7) Yeni kapanış fişinin ID'sini döndür
    SELECT @fisID
END
GO
