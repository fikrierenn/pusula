/* =====================================================================
   VARDİYA UYGULAMASI — KİMLİK + ŞUBE KAPSAMI (plan 48 Adım 4)
   Hedef: DEV — BT-FIKRI\SQLEXPRESS · BkmPanel · şema bkm
   Tarih: 18.09.2026

   NE KURAR
     1. Solum.Identity'nin beklediği ASP.NET Identity tabloları (önek Vrd_)
     2. bkm.Vrd_KullaniciSube — kullanıcı ↔ şube ACL'i (ÇOK-A-ÇOK)
     3. bkm.Vrd_SubeKapsami — kapsam çözücü TVF (şube boğazı, "(b)-tam")

   ÖN KOŞUL
     Solum şema betikleri 0005 (izinler) ve 0025 (denetim izi) ÖNCE koşmuş
     olmalı — TVF bkm.SolumPermissionGrant'ı okur. 0015 ALINMIYOR (ölçüldü:
     yalnız 0010'un tablolarına dokunuyor). Aşağıda sessizce geçilmez, kontrol
     edilir ve yoksa PATLAR.

   İdempotent: her nesne IF OBJECT_ID ile korunuyor, tekrar koşulabilir.
   ===================================================================== */

SET NOCOUNT ON;
GO

/* ── ÖN KOŞUL KAPISI ───────────────────────────────────────────────────
   Eksik tabloyla devam etmek TVF'i "izin yok" tarafına düşürürdü: kapsam
   sessizce yalnız ACL satırlarına inerdi ve "tüm şubeler" yetkisi HİÇ
   çalışmazdı. Bu sessiz bir yetki kaybıdır — gürültülü hata tercih edilir. */
IF OBJECT_ID('bkm.SolumPermissionGrant') IS NULL
BEGIN
    RAISERROR(N'bkm.SolumPermissionGrant YOK. Once Solum 0005_SolumPermissions betigini kosun (MigrationRunner, schema=bkm).', 16, 1);
    SET NOEXEC ON;
END;
GO

/* =====================================================================
   1. KİMLİK TABLOLARI — Solum.Identity sözleşmesi

   Kolon adları Solum.Identity/Sql/SqlServerIdentitySql.cs'ten BİREBİR
   alındı (uydurulmadı): UserColumns dizisi + rol/claim sorguları.
   Tablo adları SolumIdentityOptions ile eşleşmeli:
       Schema = "bkm", TablePrefix = "Vrd_"
   → bkm.Vrd_Users · bkm.Vrd_Roles · bkm.Vrd_UserRoles · bkm.Vrd_UserClaims

   Panelin dbo.PanelKullanici'sına DOKUNULMAZ — ayrı kadro, ayrı tablo
   (plan 48: "panelin tek-kullanıcı hesabı ile vardiya kadrosu karışmaz").
   ===================================================================== */

IF OBJECT_ID('bkm.Vrd_Users') IS NULL
CREATE TABLE bkm.Vrd_Users (
    Id                    nvarchar(450)  NOT NULL,
    UserName              nvarchar(256)  NULL,
    NormalizedUserName    nvarchar(256)  NULL,
    Email                 nvarchar(256)  NULL,
    NormalizedEmail       nvarchar(256)  NULL,
    EmailConfirmed        bit            NOT NULL CONSTRAINT DF_VrdUsers_EmailOnay DEFAULT (0),
    PasswordHash          nvarchar(max)  NULL,
    SecurityStamp         nvarchar(max)  NULL,
    ConcurrencyStamp      nvarchar(max)  NULL,
    PhoneNumber           nvarchar(50)   NULL,
    PhoneNumberConfirmed  bit            NOT NULL CONSTRAINT DF_VrdUsers_TelOnay DEFAULT (0),
    TwoFactorEnabled      bit            NOT NULL CONSTRAINT DF_VrdUsers_2FA DEFAULT (0),
    -- datetimeoffset: kilit bitişi bir AN'dır ve geri kazanılabilir olmalı
    -- (Solum'un 0015 dersi — offset'siz değer UTC mi yerel mi belli değil).
    LockoutEnd            datetimeoffset(7) NULL,
    LockoutEnabled        bit            NOT NULL CONSTRAINT DF_VrdUsers_KilitAcik DEFAULT (1),
    AccessFailedCount     int            NOT NULL CONSTRAINT DF_VrdUsers_HataSayac DEFAULT (0),
    CONSTRAINT PK_Vrd_Users PRIMARY KEY CLUSTERED (Id)
);
GO

/* Giriş yolu NormalizedUserName üzerinden (FindUserByNormalizedName).
   Benzersiz: iki kullanıcı aynı adı alırsa giriş hangisini seçeceğini
   bilemez — ve seçim sessizce yapılır. */
IF INDEXPROPERTY(OBJECT_ID('bkm.Vrd_Users'), 'UX_Vrd_Users_Ad', 'IndexID') IS NULL
CREATE UNIQUE NONCLUSTERED INDEX UX_Vrd_Users_Ad
    ON bkm.Vrd_Users (NormalizedUserName) WHERE NormalizedUserName IS NOT NULL;
GO

IF OBJECT_ID('bkm.Vrd_Roles') IS NULL
CREATE TABLE bkm.Vrd_Roles (
    Id                nvarchar(450) NOT NULL,
    Name              nvarchar(256) NULL,
    NormalizedName    nvarchar(256) NULL,
    ConcurrencyStamp  nvarchar(max) NULL,
    CONSTRAINT PK_Vrd_Roles PRIMARY KEY CLUSTERED (Id)
);
GO

IF INDEXPROPERTY(OBJECT_ID('bkm.Vrd_Roles'), 'UX_Vrd_Roles_Ad', 'IndexID') IS NULL
CREATE UNIQUE NONCLUSTERED INDEX UX_Vrd_Roles_Ad
    ON bkm.Vrd_Roles (NormalizedName) WHERE NormalizedName IS NOT NULL;
GO

IF OBJECT_ID('bkm.Vrd_UserRoles') IS NULL
CREATE TABLE bkm.Vrd_UserRoles (
    UserId  nvarchar(450) NOT NULL,
    RoleId  nvarchar(450) NOT NULL,
    CONSTRAINT PK_Vrd_UserRoles PRIMARY KEY CLUSTERED (UserId, RoleId),
    CONSTRAINT FK_Vrd_UserRoles_User FOREIGN KEY (UserId) REFERENCES bkm.Vrd_Users (Id) ON DELETE CASCADE,
    CONSTRAINT FK_Vrd_UserRoles_Role FOREIGN KEY (RoleId) REFERENCES bkm.Vrd_Roles (Id) ON DELETE CASCADE
);
GO

IF OBJECT_ID('bkm.Vrd_UserClaims') IS NULL
CREATE TABLE bkm.Vrd_UserClaims (
    Id          int IDENTITY(1,1) NOT NULL,
    UserId      nvarchar(450) NOT NULL,
    ClaimType   nvarchar(max) NULL,
    ClaimValue  nvarchar(max) NULL,
    CONSTRAINT PK_Vrd_UserClaims PRIMARY KEY CLUSTERED (Id),
    CONSTRAINT FK_Vrd_UserClaims_User FOREIGN KEY (UserId) REFERENCES bkm.Vrd_Users (Id) ON DELETE CASCADE
);
GO

IF INDEXPROPERTY(OBJECT_ID('bkm.Vrd_UserClaims'), 'IX_Vrd_UserClaims_Kisi', 'IndexID') IS NULL
CREATE NONCLUSTERED INDEX IX_Vrd_UserClaims_Kisi ON bkm.Vrd_UserClaims (UserId);
GO

/* =====================================================================
   2. ŞUBE ACL — kullanıcı ↔ şube, ÇOK-A-ÇOK

   ŞEKİL BİLİNÇLİ (Solum ekibi, 18.09): tek şube kolonu DEĞİL, çok-a-çok bir
   tablo. Sebep ileriye dönük: Solum bir gün "birim kapsamı" katmanı yazarsa
   (bugün 1/3 eşikte, yazılmıyor) taşıma bir kolon + bir süzgeç olur. Tek
   şubelik bir kolon seçilseydi taşıma pahalı olurdu — pahalı olan kısım
   kolon adı değil, ACL'nin ANLAMI.

   ⚠ "TÜM ŞUBELERİ GÖR" BU TABLOYA SATIR OLARAK YAZILMAZ. Ayrı bir YETKİDİR
   (bkm.SolumPermissionGrant → 'vardiya.tumSubeler'). Gerekçe ölçülebilir:
   GMY'yi dokuz şubeye tek tek eklersen, ONUNCU şube açıldığı gün GMY onu
   GÖRMEZ ve kimse fark etmez.

   ⚠ BENZERSİZ KISIT BİR GÜVENLİK KAPISI (Solum 0005'in dersi, aynen geçerli):
   aynı kullanıcıya aynı şube iki kez verilseydi erişim kontrolü yine doğru
   çalışırdı — ama erişimi KALDIRMA yarım kalırdı: bir satır silinir, öteki
   erişimi açık tutar.
   ===================================================================== */

IF OBJECT_ID('bkm.Vrd_KullaniciSube') IS NULL
CREATE TABLE bkm.Vrd_KullaniciSube (
    Id          bigint IDENTITY(1,1) NOT NULL,
    UserId      nvarchar(450) NOT NULL,
    Sube        nvarchar(50)  NOT NULL,
    VerenId     nvarchar(450) NULL,          -- kim verdi (denetim izi)
    VerilmeUtc  datetime2(0)  NOT NULL CONSTRAINT DF_VrdKullSube_Utc DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT PK_Vrd_KullaniciSube PRIMARY KEY CLUSTERED (Id),
    CONSTRAINT FK_Vrd_KullaniciSube_User FOREIGN KEY (UserId) REFERENCES bkm.Vrd_Users (Id) ON DELETE CASCADE,
    -- Şube geçerliliği FK ile zorlanır: elle girilen bir şube adı yazım
    -- hatasıyla kapsamı SESSİZCE boşaltırdı (kimse yetkisiz olmaz, ama
    -- kullanıcı hiçbir şey göremez ve sebebi görünmez).
    CONSTRAINT FK_Vrd_KullaniciSube_Sube FOREIGN KEY (Sube) REFERENCES bkm.Vrd_Sube (Sube)
);
GO

IF INDEXPROPERTY(OBJECT_ID('bkm.Vrd_KullaniciSube'), 'UX_Vrd_KullaniciSube', 'IndexID') IS NULL
CREATE UNIQUE NONCLUSTERED INDEX UX_Vrd_KullaniciSube
    ON bkm.Vrd_KullaniciSube (UserId, Sube);
GO

/* =====================================================================
   3. KAPSAM ÇÖZÜCÜ — şube boğazı, "(b)-tam"

   GMY kararı 18.09: *"b-tam yap"*.

   SÖZLEŞME: çağıran YALNIZ @KullaniciId verir. Şube kimliği ve "hepsini gör"
   bayrağı uygulamadan GEÇMEZ — ikisi de burada, veritabanında çözülür.
   Ölçüt (Solum): *"bu yoldan geçen değerlerden hangisi bir YETKİ KARARIDIR?"*
   Cevap: SIFIR.

   Bu yüzden yanlış bir şube id'si "geçemez" değil, GEÇİRİLECEK YER YOKTUR.

   ⚠ Görüntü filtresi bundan AYRI bir şeydir. Sorgular kapsamla KESİŞİR:
       WHERE Sube IN (SELECT Sube FROM bkm.Vrd_SubeKapsami(@KullaniciId))
         AND (@SubeFiltre IS NULL OR Sube = @SubeFiltre)
   @SubeFiltre bir yetki kararı değil, kapsam İÇİNDE daraltmadır; uydurulmuş
   bir değer kesişimde düşer.

   BEDELİ (bilerek kabul edildi): yetki kuralı SQL'de yaşar. Karşılığı yetki
   atlatmasının yapısal olarak imkânsız olması. Bizde SQL tarafı denetlenebilir
   (sqlcli assert + sema/degismezler.json), yani Solum'un saydığı "SQL'de test
   zor" bedeli burada daha ucuz.
   ===================================================================== */

IF OBJECT_ID('bkm.Vrd_SubeKapsami') IS NOT NULL DROP FUNCTION bkm.Vrd_SubeKapsami;
GO

CREATE FUNCTION bkm.Vrd_SubeKapsami (@KullaniciId nvarchar(450))
RETURNS TABLE
AS
RETURN
(
    -- (1) "Tüm şubeler" yetkisi olan kullanıcı: şube kümesinin TAMAMI.
    --     Küme Vrd_Sube'den CANLI okunur — yeni açılan şube kendiliğinden
    --     kapsama girer (ACL'ye satır yazılmadığı için unutulamaz).
    SELECT s.Sube
    FROM   bkm.Vrd_Sube AS s
    WHERE  EXISTS (
        SELECT 1
        FROM   bkm.SolumPermissionGrant AS g
        WHERE  g.PermissionName = N'vardiya.tumSubeler'
          AND  (
                 (g.ProviderName = N'User' AND g.ProviderKey = @KullaniciId)
              OR (g.ProviderName = N'Role' AND EXISTS (
                     SELECT 1
                     FROM   bkm.Vrd_UserRoles AS ur
                     JOIN   bkm.Vrd_Roles     AS r ON r.Id = ur.RoleId
                     WHERE  ur.UserId = @KullaniciId
                       AND  r.Name    = g.ProviderKey))
               )
    )

    UNION   -- UNION (ALL değil): iki yoldan gelen aynı şube tekilleşir.

    -- (2) Yetkisi olmayan kullanıcı: yalnız ACL'de yazılı şubeleri.
    SELECT ks.Sube
    FROM   bkm.Vrd_KullaniciSube AS ks
    WHERE  ks.UserId = @KullaniciId
);
GO

/* ── KURULUM SONRASI DOĞRULAMA (elle koşulur, sonuç okunur) ─────────────

SELECT 'tablolar' = COUNT(*)
FROM sys.tables t JOIN sys.schemas s ON s.schema_id = t.schema_id
WHERE s.name = 'bkm' AND t.name IN
      ('Vrd_Users','Vrd_Roles','Vrd_UserRoles','Vrd_UserClaims','Vrd_KullaniciSube');
-- beklenen: 5

SELECT * FROM bkm.Vrd_SubeKapsami(N'yok-boyle-kullanici');
-- beklenen: 0 satır (kimliksiz istek hiçbir şube görmez)

*/
