/* ============================================================================
   2026-09-21 — BKM Mağaza: TEK KULLANIMLIK KOD + yönetici bayrağı
                                                          (DB: BkmPanel, APP-LOCAL)
   Plan: plans/50-magaza-urun-bulma-uygulamasi.md

   ⚠ ERP'DE DEĞİL — panel veritabanı (erp-write-policy.md).

   NEDEN: tek ve kalıcı kurulum kodu paylaşıldığı anda kalıcı bir anahtara dönüşür;
   sızarsa süresiz geçerlidir ve iptali herkesi etkiler. Tek kullanımlık kod
   sızsa bile işe yaramaz (kullanılmış ya da süresi dolmuş olur) ve
   "bu kodu kime verdim" kaydı kalır → kayıt kişiyle eşleşir.

   Kod ÖZETİ saklanır, kodun kendisi DEĞİL — tablo sızarsa kodlar kullanılamaz.
   ============================================================================ */

IF OBJECT_ID('dbo.PanelMagazaKod', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.PanelMagazaKod
    (
        Id              int IDENTITY(1,1) NOT NULL CONSTRAINT PK_PanelMagazaKod PRIMARY KEY,
        KodOzet         varbinary(32)     NOT NULL,   -- SHA-256(kod)
        AdSoyad         nvarchar(128)     NOT NULL,   -- kodu kimin için ürettik
        Eposta          nvarchar(160)     NULL,
        MekanId         int               NOT NULL,
        MekanAd         nvarchar(64)      NULL,
        Olusturan       nvarchar(64)      NULL,       -- kodu üreten yönetici
        OlusturmaTrh    datetime2(0)      NOT NULL CONSTRAINT DF_PMK2_Olustur DEFAULT (SYSUTCDATETIME()),
        GecerlilikBitis datetime2(0)      NOT NULL,
        KullanildiTrh   datetime2(0)      NULL,       -- NULL = henüz kullanılmadı
        KullananCihazId nvarchar(64)      NULL,
        Iptal           bit               NOT NULL CONSTRAINT DF_PMK2_Iptal   DEFAULT (0),
        MailDurum       nvarchar(200)     NULL        -- gönderildi / hata metni
    );

    CREATE UNIQUE INDEX UX_PanelMagazaKod_Ozet ON dbo.PanelMagazaKod (KodOzet);
END
GO

-- Yönetici bayrağı: kod üretme ve cihaz iptali yalnız bu kullanıcılarda.
IF COL_LENGTH('dbo.PanelMagazaKullanici', 'Yonetici') IS NULL
    ALTER TABLE dbo.PanelMagazaKullanici
        ADD Yonetici bit NOT NULL CONSTRAINT DF_PMK_Yonetici DEFAULT (0);
GO

/* Yönetici yetkisi verme (elle, bilinçli):
       UPDATE dbo.PanelMagazaKullanici SET Yonetici = 1 WHERE KullaniciAdi = N'<ad>';

   Kod üretimi panelden yapılır (/yonetim.html) ya da komut satırından:
       dotnet run -- kod-uret "Ahmet Yılmaz" ahmet@bkmkitap.com 1 "FSM Mğz"

   Denetim — kim kime kod üretti, kullanıldı mı:
       SELECT AdSoyad, Eposta, MekanAd, Olusturan, OlusturmaTrh, GecerlilikBitis,
              KullanildiTrh, Iptal, MailDurum
       FROM dbo.PanelMagazaKod ORDER BY OlusturmaTrh DESC;
*/
