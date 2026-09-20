/* ============================================================================
   2026-09-20 — BKM Mağaza uygulaması kullanıcı tablosu   (DB: BkmPanel, APP-LOCAL)
   Plan: plans/50-magaza-urun-bulma-uygulamasi.md

   ⚠ BU TABLO ERP'DE DEĞİL. Hedef, panelin kendi yerel veritabanı (BkmPanel).
   erp-write-policy.md: panel DB'de yazma serbest (dbo.Panel* kendi tabloları);
   DerinSISBkm / EncoreMerkez / JOKER tarafına bu uygulama TEK SATIR yazmaz.

   Şema ve parola düzeni dashboard'un dbo.PanelKullanici tablosuyla aynı
   (PBKDF2-SHA256, salt + iterasyon kolonda) — aynı kurumda iki parola şeması tutulmaz.
   Fark: mağaza personeli MekanId taşır; oturumun mekanı buradan gelir, istemciden değil.

   Idempotent: tablo varsa dokunmaz.
   ============================================================================ */

IF OBJECT_ID('dbo.PanelMagazaKullanici', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.PanelMagazaKullanici
    (
        Id             int IDENTITY(1,1)  NOT NULL CONSTRAINT PK_PanelMagazaKullanici PRIMARY KEY,
        KullaniciAdi   nvarchar(64)       NOT NULL,
        AdSoyad        nvarchar(128)      NULL,
        MekanId        int                NOT NULL,
        MekanAd        nvarchar(64)       NULL,
        SifreHash      varbinary(64)      NOT NULL,
        Salt           varbinary(32)      NOT NULL,
        Iterasyon      int                NOT NULL CONSTRAINT DF_PMK_Iter    DEFAULT (100000),
        Aktif          bit                NOT NULL CONSTRAINT DF_PMK_Aktif   DEFAULT (1),
        SonGiris       datetime2(0)       NULL,
        BasarisizSayac int                NOT NULL CONSTRAINT DF_PMK_Sayac   DEFAULT (0),
        KilitBitis     datetime2(0)       NULL,
        OlusturmaTrh   datetime2(0)       NOT NULL CONSTRAINT DF_PMK_Olustur DEFAULT (SYSUTCDATETIME())
    );

    CREATE UNIQUE INDEX UX_PanelMagazaKullanici_Ad ON dbo.PanelMagazaKullanici (KullaniciAdi);
END
GO

/* Kullanıcı EKLEME buradan yapılmaz — şifre SQL'e düz yazılmasın diye uygulamadan:
       cd magaza/BkmMagaza
       dotnet run -- kullanici-ekle <kullaniciAdi> "<Ad Soyad>" <mekanId> "<Mekan Ad>" <sifre>
   Mekan kimlikleri: 1 FSM · 4477 Özlüce · 4478 İst. Yolu (dbo.posMagaza, mekanTip = 0).

   Cihaz kaybında oturumu sonlandırma:
       UPDATE dbo.PanelMagazaKullanici SET Aktif = 0 WHERE KullaniciAdi = N'<ad>';
*/
