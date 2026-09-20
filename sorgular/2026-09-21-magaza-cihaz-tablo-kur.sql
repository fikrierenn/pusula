/* ============================================================================
   2026-09-21 — BKM Mağaza: CİHAZ KAYIT tablosu            (DB: BkmPanel, APP-LOCAL)
   Plan: plans/50-magaza-urun-bulma-uygulamasi.md

   ⚠ ERP'DE DEĞİL. Hedef panelin kendi yerel veritabanı (BkmPanel).
   erp-write-policy.md: panel DB'de yazma serbest; DerinSISBkm/EncoreMerkez/JOKER
   tarafına bu uygulama TEK SATIR yazmaz.

   NEDEN cihaz kaydı: BYOD telefonda her açılışta kullanıcı adı/şifre yazdırmak
   personeli uygulamadan soğutur. Cihaz bir kez kaydolur, jeton cihazda kalır.

   ⚠ BUNUN BEDELİ AÇIKÇA: jeton, şifreden ZAYIF bir kimliktir — telefonu açık ele
   geçiren kişi uygulamaya erişir. Kabul edilebilir olmasının tek sebebi uygulamanın
   SALT-OKUMA olması (stok/fiyat/raf görür, hiçbir şey değiştiremez). Karşılığında:
     · her cihazın ADI vardır (kim kullanıyor bellidir),
     · kayıt KURULUM KODU ister (ağa giren herkes kendini kaydedemez),
     · Aktif = 0 ile cihaz anında iptal edilir (kayıp/çalıntı/işten ayrılma).

   Jetonun KENDİSİ saklanmaz, SHA-256 özeti saklanır — tablo sızarsa jetonlar
   kullanılamaz (parola saklama ilkesiyle aynı gerekçe).

   Idempotent: tablo varsa dokunmaz.
   ============================================================================ */

IF OBJECT_ID('dbo.PanelMagazaCihaz', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.PanelMagazaCihaz
    (
        Id           int IDENTITY(1,1) NOT NULL CONSTRAINT PK_PanelMagazaCihaz PRIMARY KEY,
        CihazId      nvarchar(64)      NOT NULL,   -- cihazda üretilen UUID
        AdSoyad      nvarchar(128)     NOT NULL,
        MekanId      int               NOT NULL,
        MekanAd      nvarchar(64)      NULL,
        JetonOzet    varbinary(32)     NOT NULL,   -- SHA-256(jeton); jetonun kendisi YOK
        Aktif        bit               NOT NULL CONSTRAINT DF_PMC_Aktif  DEFAULT (1),
        Model        nvarchar(128)     NULL,       -- telefon modeli (kim hangi cihaz)
        KayitTarih   datetime2(0)      NOT NULL CONSTRAINT DF_PMC_Kayit  DEFAULT (SYSUTCDATETIME()),
        SonGoruldu   datetime2(0)      NULL,
        SonIp        nvarchar(45)      NULL
    );

    CREATE UNIQUE INDEX UX_PanelMagazaCihaz_CihazId ON dbo.PanelMagazaCihaz (CihazId);
    CREATE INDEX IX_PanelMagazaCihaz_Jeton ON dbo.PanelMagazaCihaz (JetonOzet) WHERE Aktif = 1;
END
GO

/* Kurulum kodu KOD İÇİNDE DEĞİL, .env'de: MAGAZA_KURULUM_KODU=<kod>
   (security-principles.md — sır env'de, kaynakta değil.)

   Cihaz iptali (kayıp telefon / işten ayrılma):
       UPDATE dbo.PanelMagazaCihaz SET Aktif = 0 WHERE CihazId = N'<uuid>';

   Kim, hangi cihazdan, ne zaman:
       SELECT AdSoyad, MekanAd, Model, KayitTarih, SonGoruldu, Aktif
       FROM dbo.PanelMagazaCihaz ORDER BY SonGoruldu DESC;
*/
