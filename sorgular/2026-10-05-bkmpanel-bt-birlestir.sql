/* ork:hedef-db BkmPanel
   Amaç  : BT-FIKRI BkmPanel (yedek 05.10.2026, BkmPanel_BT olarak açıldı) nesnelerini
           SANAL-FIKRI BkmPanel'e EKLER. Mevcut tablolara dokunmaz. Tek transaction.
   Hariç : bkm.Vrd_ParitePython, dbo.PanelMagazaCihaz, dbo.PanelMagazaIslemLog, dbo.PanelMagazaKod, dbo.PanelMagazaKullanici
   Üretim: kataloğdan (sys.*) otomatik — elle düzenlenmedi. */
SET XACT_ABORT ON;
SET NOCOUNT ON;
BEGIN TRAN;
IF SCHEMA_ID(N'bkm') IS NULL EXEC(N'CREATE SCHEMA [bkm] AUTHORIZATION dbo');

IF OBJECT_ID(N'bkm.SolumAuditTrail', N'U') IS NOT NULL THROW 51000, N'bkm.SolumAuditTrail hedefte zaten var', 1;
CREATE TABLE [bkm].[SolumAuditTrail] (
    [Id] bigint IDENTITY(1,1) NOT NULL,
    [EntityName] nvarchar(256) COLLATE Turkish_CI_AS NOT NULL,
    [RecordId] nvarchar(256) COLLATE Turkish_CI_AS NOT NULL,
    [Action] int NOT NULL,
    [UserId] nvarchar(256) COLLATE Turkish_CI_AS NULL,
    [UserName] nvarchar(256) COLLATE Turkish_CI_AS NULL,
    [At] datetimeoffset(7) NOT NULL,
    [CompanyId] int NULL,
    [Changes] nvarchar(max) COLLATE Turkish_CI_AS NOT NULL,
    CONSTRAINT [PK_SolumAuditTrail] PRIMARY KEY CLUSTERED ([Id])
);
SET IDENTITY_INSERT [bkm].[SolumAuditTrail] ON;
INSERT INTO [bkm].[SolumAuditTrail] ([Id], [EntityName], [RecordId], [Action], [UserId], [UserName], [At], [CompanyId], [Changes]) SELECT [Id], [EntityName], [RecordId], [Action], [UserId], [UserName], [At], [CompanyId], [Changes] FROM [BkmPanel_BT].[bkm].[SolumAuditTrail];
SET IDENTITY_INSERT [bkm].[SolumAuditTrail] OFF;

IF OBJECT_ID(N'bkm.SolumPermissionGrant', N'U') IS NOT NULL THROW 51000, N'bkm.SolumPermissionGrant hedefte zaten var', 1;
CREATE TABLE [bkm].[SolumPermissionGrant] (
    [Id] bigint IDENTITY(1,1) NOT NULL,
    [ProviderName] nvarchar(64) COLLATE Turkish_CI_AS NOT NULL,
    [ProviderKey] nvarchar(256) COLLATE Turkish_CI_AS NOT NULL,
    [PermissionName] nvarchar(256) COLLATE Turkish_CI_AS NOT NULL,
    CONSTRAINT [PK_SolumPermissionGrant] PRIMARY KEY CLUSTERED ([Id])
);
SET IDENTITY_INSERT [bkm].[SolumPermissionGrant] ON;
INSERT INTO [bkm].[SolumPermissionGrant] ([Id], [ProviderName], [ProviderKey], [PermissionName]) SELECT [Id], [ProviderName], [ProviderKey], [PermissionName] FROM [BkmPanel_BT].[bkm].[SolumPermissionGrant];
SET IDENTITY_INSERT [bkm].[SolumPermissionGrant] OFF;

IF OBJECT_ID(N'bkm.SolumUserCompanyAccess', N'U') IS NOT NULL THROW 51000, N'bkm.SolumUserCompanyAccess hedefte zaten var', 1;
CREATE TABLE [bkm].[SolumUserCompanyAccess] (
    [Id] bigint IDENTITY(1,1) NOT NULL,
    [UserId] nvarchar(256) COLLATE Turkish_CI_AS NOT NULL,
    [CompanyId] int NOT NULL,
    CONSTRAINT [PK_SolumUserCompanyAccess] PRIMARY KEY CLUSTERED ([Id])
);
SET IDENTITY_INSERT [bkm].[SolumUserCompanyAccess] ON;
INSERT INTO [bkm].[SolumUserCompanyAccess] ([Id], [UserId], [CompanyId]) SELECT [Id], [UserId], [CompanyId] FROM [BkmPanel_BT].[bkm].[SolumUserCompanyAccess];
SET IDENTITY_INSERT [bkm].[SolumUserCompanyAccess] OFF;

IF OBJECT_ID(N'bkm.Vrd_CalismaSaati', N'U') IS NOT NULL THROW 51000, N'bkm.Vrd_CalismaSaati hedefte zaten var', 1;
CREATE TABLE [bkm].[Vrd_CalismaSaati] (
    [Grup] nvarchar(80) COLLATE Turkish_CI_AS NOT NULL,
    [Sube] nvarchar(50) COLLATE Turkish_CI_AS NOT NULL,
    [Bolum] nvarchar(80) COLLATE Turkish_CI_AS NULL,
    [BolumAnahtar] AS (isnull([Bolum],N'')) PERSISTED,
    [CalismaDk] int NOT NULL,
    [Not_] nvarchar(200) COLLATE Turkish_CI_AS NULL,
    [YuklemeUtc] datetime2(0) NOT NULL CONSTRAINT [DF_VrdCalSaat_Utc] DEFAULT (sysutcdatetime()),
    CONSTRAINT [PK_Vrd_CalismaSaati] PRIMARY KEY CLUSTERED ([Grup], [Sube], [BolumAnahtar])
);
INSERT INTO [bkm].[Vrd_CalismaSaati] ([Grup], [Sube], [Bolum], [CalismaDk], [Not_], [YuklemeUtc]) SELECT [Grup], [Sube], [Bolum], [CalismaDk], [Not_], [YuklemeUtc] FROM [BkmPanel_BT].[bkm].[Vrd_CalismaSaati];

IF OBJECT_ID(N'bkm.Vrd_Devir', N'U') IS NOT NULL THROW 51000, N'bkm.Vrd_Devir hedefte zaten var', 1;
CREATE TABLE [bkm].[Vrd_Devir] (
    [Donem] char(7) COLLATE Turkish_CI_AS NOT NULL,
    [SicilNo] varchar(11) COLLATE Turkish_CI_AS NOT NULL,
    [Sube] nvarchar(50) COLLATE Turkish_CI_AS NULL,
    [Personel] nvarchar(120) COLLATE Turkish_CI_AS NULL,
    [Bolum] nvarchar(80) COLLATE Turkish_CI_AS NULL,
    [Gorev] nvarchar(120) COLLATE Turkish_CI_AS NULL,
    [EksikDk] int NOT NULL CONSTRAINT [DF_VrdDevir_Eksik] DEFAULT ((0)),
    [FazlaDk] int NOT NULL CONSTRAINT [DF_VrdDevir_Fazla] DEFAULT ((0)),
    [DondurmaUtc] datetime2(0) NOT NULL CONSTRAINT [DF_VrdDevir_Utc] DEFAULT (sysutcdatetime()),
    CONSTRAINT [PK_Vrd_Devir] PRIMARY KEY CLUSTERED ([Donem], [SicilNo]),
    CONSTRAINT [CK_Vrd_Devir_Donem] CHECK ([Donem] like '[12][0-9][0-9][0-9]-[01][0-9]')
);
INSERT INTO [bkm].[Vrd_Devir] ([Donem], [SicilNo], [Sube], [Personel], [Bolum], [Gorev], [EksikDk], [FazlaDk], [DondurmaUtc]) SELECT [Donem], [SicilNo], [Sube], [Personel], [Bolum], [Gorev], [EksikDk], [FazlaDk], [DondurmaUtc] FROM [BkmPanel_BT].[bkm].[Vrd_Devir];

IF OBJECT_ID(N'bkm.Vrd_KisiGun', N'U') IS NOT NULL THROW 51000, N'bkm.Vrd_KisiGun hedefte zaten var', 1;
CREATE TABLE [bkm].[Vrd_KisiGun] (
    [Id] bigint IDENTITY(1,1) NOT NULL,
    [KesimBas] date NOT NULL,
    [KesimBit] date NOT NULL,
    [SayimBas] date NOT NULL,
    [Sube] nvarchar(50) COLLATE Turkish_CI_AS NOT NULL,
    [SicilNo] varchar(11) COLLATE Turkish_CI_AS NOT NULL,
    [PdksNo] int NULL,
    [Personel] nvarchar(120) COLLATE Turkish_CI_AS NULL,
    [Bolum] nvarchar(80) COLLATE Turkish_CI_AS NULL,
    [Gorev] nvarchar(120) COLLATE Turkish_CI_AS NULL,
    [Tarih] date NOT NULL,
    [VardiyaTanim] nvarchar(60) COLLATE Turkish_CI_AS NULL,
    [PlanBaslamaDk] int NULL,
    [PlanBitisDk] int NULL,
    [PlanCalismaDk] int NULL,
    [KartGirisDk] int NULL,
    [KartCikisDk] int NULL,
    [GirisDk] int NULL,
    [CikisDk] int NULL,
    [BrutDk] int NULL,
    [MolaDk] int NULL,
    [CalismaDk] int NULL,
    [Durum] nvarchar(60) COLLATE Turkish_CI_AS NOT NULL,
    [Izin] bit NOT NULL CONSTRAINT [DF_VrdKisiGun_Izin] DEFAULT ((0)),
    [GunDonumu] bit NOT NULL CONSTRAINT [DF_VrdKisiGun_GunDon] DEFAULT ((0)),
    [SayimDisi] bit NOT NULL CONSTRAINT [DF_VrdKisiGun_SayimDisi] DEFAULT ((0)),
    [KayitSayisi] int NULL,
    [MazeretTipi] nvarchar(40) COLLATE Turkish_CI_AS NULL,
    [OlcumNotu] nvarchar(400) COLLATE Turkish_CI_AS NULL,
    [Kaynak] nvarchar(80) COLLATE Turkish_CI_AS NOT NULL CONSTRAINT [DF_VrdKisiGun_Kaynak] DEFAULT (CONVERT([nvarchar](80),serverproperty('ServerName'))),
    [YazilmaUtc] datetime2(0) NOT NULL CONSTRAINT [DF_VrdKisiGun_Utc] DEFAULT (sysutcdatetime()),
    [GerekenDk] int NULL,
    [Net2Dk] int NULL,
    [HaftalikPrimDk] int NULL,
    [EksikDk] int NULL,
    [FazlaDk] int NULL,
    [FazlaCalismaDk] int NULL,
    [FazlaIzinIptalDk] int NULL,
    [FazlaPlansizDk] int NULL,
    [CikisSonrasiDk] int NULL,
    [GirisOncesiDk] int NULL,
    CONSTRAINT [PK_Vrd_KisiGun] PRIMARY KEY CLUSTERED ([Id])
);
SET IDENTITY_INSERT [bkm].[Vrd_KisiGun] ON;
INSERT INTO [bkm].[Vrd_KisiGun] ([Id], [KesimBas], [KesimBit], [SayimBas], [Sube], [SicilNo], [PdksNo], [Personel], [Bolum], [Gorev], [Tarih], [VardiyaTanim], [PlanBaslamaDk], [PlanBitisDk], [PlanCalismaDk], [KartGirisDk], [KartCikisDk], [GirisDk], [CikisDk], [BrutDk], [MolaDk], [CalismaDk], [Durum], [Izin], [GunDonumu], [SayimDisi], [KayitSayisi], [MazeretTipi], [OlcumNotu], [Kaynak], [YazilmaUtc], [GerekenDk], [Net2Dk], [HaftalikPrimDk], [EksikDk], [FazlaDk], [FazlaCalismaDk], [FazlaIzinIptalDk], [FazlaPlansizDk], [CikisSonrasiDk], [GirisOncesiDk]) SELECT [Id], [KesimBas], [KesimBit], [SayimBas], [Sube], [SicilNo], [PdksNo], [Personel], [Bolum], [Gorev], [Tarih], [VardiyaTanim], [PlanBaslamaDk], [PlanBitisDk], [PlanCalismaDk], [KartGirisDk], [KartCikisDk], [GirisDk], [CikisDk], [BrutDk], [MolaDk], [CalismaDk], [Durum], [Izin], [GunDonumu], [SayimDisi], [KayitSayisi], [MazeretTipi], [OlcumNotu], [Kaynak], [YazilmaUtc], [GerekenDk], [Net2Dk], [HaftalikPrimDk], [EksikDk], [FazlaDk], [FazlaCalismaDk], [FazlaIzinIptalDk], [FazlaPlansizDk], [CikisSonrasiDk], [GirisOncesiDk] FROM [BkmPanel_BT].[bkm].[Vrd_KisiGun];
SET IDENTITY_INSERT [bkm].[Vrd_KisiGun] OFF;

IF OBJECT_ID(N'bkm.Vrd_KullaniciSube', N'U') IS NOT NULL THROW 51000, N'bkm.Vrd_KullaniciSube hedefte zaten var', 1;
CREATE TABLE [bkm].[Vrd_KullaniciSube] (
    [Id] bigint IDENTITY(1,1) NOT NULL,
    [UserId] nvarchar(450) COLLATE Turkish_CI_AS NOT NULL,
    [Sube] nvarchar(50) COLLATE Turkish_CI_AS NOT NULL,
    [VerenId] nvarchar(450) COLLATE Turkish_CI_AS NULL,
    [VerilmeUtc] datetime2(0) NOT NULL CONSTRAINT [DF_VrdKullSube_Utc] DEFAULT (sysutcdatetime()),
    [GecerliBas] date NOT NULL CONSTRAINT [DF_VrdKullSube_Bas] DEFAULT ('19000101'),
    [GecerliBit] date NULL,
    CONSTRAINT [PK_Vrd_KullaniciSube] PRIMARY KEY CLUSTERED ([Id]),
    CONSTRAINT [CK_VrdKullSube_Aralik] CHECK ([GecerliBit] IS NULL OR [GecerliBit]>=[GecerliBas])
);
SET IDENTITY_INSERT [bkm].[Vrd_KullaniciSube] ON;
INSERT INTO [bkm].[Vrd_KullaniciSube] ([Id], [UserId], [Sube], [VerenId], [VerilmeUtc], [GecerliBas], [GecerliBit]) SELECT [Id], [UserId], [Sube], [VerenId], [VerilmeUtc], [GecerliBas], [GecerliBit] FROM [BkmPanel_BT].[bkm].[Vrd_KullaniciSube];
SET IDENTITY_INSERT [bkm].[Vrd_KullaniciSube] OFF;

IF OBJECT_ID(N'bkm.Vrd_MagazaGeriDonus', N'U') IS NOT NULL THROW 51000, N'bkm.Vrd_MagazaGeriDonus hedefte zaten var', 1;
CREATE TABLE [bkm].[Vrd_MagazaGeriDonus] (
    [Id] int IDENTITY(1,1) NOT NULL,
    [Sube] nvarchar(50) COLLATE Turkish_CI_AS NOT NULL,
    [Personel] nvarchar(120) COLLATE Turkish_CI_AS NOT NULL,
    [Grup] nvarchar(80) COLLATE Turkish_CI_AS NULL,
    [Tarih] date NOT NULL,
    [YoneticiGirisDk] int NULL,
    [YoneticiCikisDk] int NULL,
    [Aciklama] nvarchar(300) COLLATE Turkish_CI_AS NULL,
    [Kaydeden] nvarchar(80) COLLATE Turkish_CI_AS NULL,
    [KayitUtc] datetime2(0) NOT NULL CONSTRAINT [DF_VrdGeri_Utc] DEFAULT (sysutcdatetime()),
    CONSTRAINT [PK_Vrd_MagazaGeriDonus] PRIMARY KEY CLUSTERED ([Id])
);
SET IDENTITY_INSERT [bkm].[Vrd_MagazaGeriDonus] ON;
INSERT INTO [bkm].[Vrd_MagazaGeriDonus] ([Id], [Sube], [Personel], [Grup], [Tarih], [YoneticiGirisDk], [YoneticiCikisDk], [Aciklama], [Kaydeden], [KayitUtc]) SELECT [Id], [Sube], [Personel], [Grup], [Tarih], [YoneticiGirisDk], [YoneticiCikisDk], [Aciklama], [Kaydeden], [KayitUtc] FROM [BkmPanel_BT].[bkm].[Vrd_MagazaGeriDonus];
SET IDENTITY_INSERT [bkm].[Vrd_MagazaGeriDonus] OFF;

IF OBJECT_ID(N'bkm.Vrd_Mola', N'U') IS NOT NULL THROW 51000, N'bkm.Vrd_Mola hedefte zaten var', 1;
CREATE TABLE [bkm].[Vrd_Mola] (
    [Tip] varchar(10) COLLATE Turkish_CI_AS NOT NULL,
    [AltSinirDk] int NOT NULL,
    [MolaDk] int NOT NULL,
    [Ustu] bit NOT NULL CONSTRAINT [DF_VrdMola_Ustu] DEFAULT ((0)),
    [YuklemeUtc] datetime2(0) NOT NULL CONSTRAINT [DF_VrdMola_Utc] DEFAULT (sysutcdatetime()),
    CONSTRAINT [PK_Vrd_Mola] PRIMARY KEY CLUSTERED ([Tip], [AltSinirDk], [MolaDk]),
    CONSTRAINT [CK_Vrd_Mola_Tip] CHECK ([Tip]='excel' OR [Tip]='arac' OR [Tip]='brut' OR [Tip]='net')
);
INSERT INTO [bkm].[Vrd_Mola] ([Tip], [AltSinirDk], [MolaDk], [Ustu], [YuklemeUtc]) SELECT [Tip], [AltSinirDk], [MolaDk], [Ustu], [YuklemeUtc] FROM [BkmPanel_BT].[bkm].[Vrd_Mola];

IF OBJECT_ID(N'bkm.Vrd_Onay', N'U') IS NOT NULL THROW 51000, N'bkm.Vrd_Onay hedefte zaten var', 1;
CREATE TABLE [bkm].[Vrd_Onay] (
    [SicilNo] varchar(11) COLLATE Turkish_CI_AS NOT NULL,
    [Tarih] date NOT NULL,
    [OnayliGirisDk] int NULL,
    [OnayliCikisDk] int NULL,
    [EkMesaiDk] int NULL,
    [Aciklama] nvarchar(300) COLLATE Turkish_CI_AS NULL,
    [Kaydeden] nvarchar(80) COLLATE Turkish_CI_AS NULL,
    [KayitUtc] datetime2(0) NOT NULL CONSTRAINT [DF_VrdOnay_Utc] DEFAULT (sysutcdatetime()),
    CONSTRAINT [PK_Vrd_Onay] PRIMARY KEY CLUSTERED ([SicilNo], [Tarih]),
    CONSTRAINT [CK_Vrd_Onay_EkMesai] CHECK ([EkMesaiDk] IS NULL OR [EkMesaiDk]>=(0) AND [EkMesaiDk]<=(1440))
);
INSERT INTO [bkm].[Vrd_Onay] ([SicilNo], [Tarih], [OnayliGirisDk], [OnayliCikisDk], [EkMesaiDk], [Aciklama], [Kaydeden], [KayitUtc]) SELECT [SicilNo], [Tarih], [OnayliGirisDk], [OnayliCikisDk], [EkMesaiDk], [Aciklama], [Kaydeden], [KayitUtc] FROM [BkmPanel_BT].[bkm].[Vrd_Onay];

IF OBJECT_ID(N'bkm.Vrd_PlanDuzeltme', N'U') IS NOT NULL THROW 51000, N'bkm.Vrd_PlanDuzeltme hedefte zaten var', 1;
CREATE TABLE [bkm].[Vrd_PlanDuzeltme] (
    [SicilNo] nvarchar(20) COLLATE Turkish_CI_AS NOT NULL,
    [Tarih] date NOT NULL,
    [VardiyaTanim] nvarchar(60) COLLATE Turkish_CI_AS NULL,
    [PlanBaslamaDk] int NULL,
    [PlanBitisDk] int NULL,
    [PlanCalismaDk] int NULL,
    [IzinliMi] bit NULL,
    [Aciklama] nvarchar(400) COLLATE Turkish_CI_AS NULL,
    [Kaydeden] nvarchar(128) COLLATE Turkish_CI_AS NOT NULL,
    [KayitUtc] datetime2(0) NOT NULL CONSTRAINT [DF_Vrd_PlanDuzeltme_KayitUtc] DEFAULT (sysutcdatetime()),
    CONSTRAINT [PK_Vrd_PlanDuzeltme] PRIMARY KEY CLUSTERED ([SicilNo], [Tarih]),
    CONSTRAINT [CK_Vrd_PlanDuzeltme_Baslama] CHECK ([PlanBaslamaDk] IS NULL OR [PlanBaslamaDk]>=(0) AND [PlanBaslamaDk]<=(2880)),
    CONSTRAINT [CK_Vrd_PlanDuzeltme_Bitis] CHECK ([PlanBitisDk] IS NULL OR [PlanBitisDk]>=(0) AND [PlanBitisDk]<=(2880)),
    CONSTRAINT [CK_Vrd_PlanDuzeltme_Sure] CHECK ([PlanCalismaDk] IS NULL OR [PlanCalismaDk]>=(0) AND [PlanCalismaDk]<=(1440)),
    CONSTRAINT [CK_Vrd_PlanDuzeltme_AralikButun] CHECK ([PlanBaslamaDk] IS NULL AND [PlanBitisDk] IS NULL OR [PlanBaslamaDk] IS NOT NULL AND [PlanBitisDk] IS NOT NULL),
    CONSTRAINT [CK_Vrd_PlanDuzeltme_AralikYon] CHECK ([PlanBaslamaDk] IS NULL OR [PlanBitisDk]>[PlanBaslamaDk])
);
INSERT INTO [bkm].[Vrd_PlanDuzeltme] ([SicilNo], [Tarih], [VardiyaTanim], [PlanBaslamaDk], [PlanBitisDk], [PlanCalismaDk], [IzinliMi], [Aciklama], [Kaydeden], [KayitUtc]) SELECT [SicilNo], [Tarih], [VardiyaTanim], [PlanBaslamaDk], [PlanBitisDk], [PlanCalismaDk], [IzinliMi], [Aciklama], [Kaydeden], [KayitUtc] FROM [BkmPanel_BT].[bkm].[Vrd_PlanDuzeltme];

IF OBJECT_ID(N'bkm.Vrd_Roles', N'U') IS NOT NULL THROW 51000, N'bkm.Vrd_Roles hedefte zaten var', 1;
CREATE TABLE [bkm].[Vrd_Roles] (
    [Id] nvarchar(450) COLLATE Turkish_CI_AS NOT NULL,
    [Name] nvarchar(256) COLLATE Turkish_CI_AS NULL,
    [NormalizedName] nvarchar(256) COLLATE Turkish_CI_AS NULL,
    [ConcurrencyStamp] nvarchar(max) COLLATE Turkish_CI_AS NULL,
    CONSTRAINT [PK_Vrd_Roles] PRIMARY KEY CLUSTERED ([Id])
);
INSERT INTO [bkm].[Vrd_Roles] ([Id], [Name], [NormalizedName], [ConcurrencyStamp]) SELECT [Id], [Name], [NormalizedName], [ConcurrencyStamp] FROM [BkmPanel_BT].[bkm].[Vrd_Roles];

IF OBJECT_ID(N'bkm.Vrd_Sube', N'U') IS NOT NULL THROW 51000, N'bkm.Vrd_Sube hedefte zaten var', 1;
CREATE TABLE [bkm].[Vrd_Sube] (
    [Sube] nvarchar(50) COLLATE Turkish_CI_AS NOT NULL,
    [Grup] nvarchar(80) COLLATE Turkish_CI_AS NOT NULL,
    [CalismaDk] int NULL,
    [YuklemeUtc] datetime2(0) NOT NULL CONSTRAINT [DF_VrdSube_Utc] DEFAULT (sysutcdatetime()),
    CONSTRAINT [PK_Vrd_Sube] PRIMARY KEY CLUSTERED ([Sube])
);
INSERT INTO [bkm].[Vrd_Sube] ([Sube], [Grup], [CalismaDk], [YuklemeUtc]) SELECT [Sube], [Grup], [CalismaDk], [YuklemeUtc] FROM [BkmPanel_BT].[bkm].[Vrd_Sube];

IF OBJECT_ID(N'bkm.Vrd_UserClaims', N'U') IS NOT NULL THROW 51000, N'bkm.Vrd_UserClaims hedefte zaten var', 1;
CREATE TABLE [bkm].[Vrd_UserClaims] (
    [Id] int IDENTITY(1,1) NOT NULL,
    [UserId] nvarchar(450) COLLATE Turkish_CI_AS NOT NULL,
    [ClaimType] nvarchar(max) COLLATE Turkish_CI_AS NULL,
    [ClaimValue] nvarchar(max) COLLATE Turkish_CI_AS NULL,
    CONSTRAINT [PK_Vrd_UserClaims] PRIMARY KEY CLUSTERED ([Id])
);
SET IDENTITY_INSERT [bkm].[Vrd_UserClaims] ON;
INSERT INTO [bkm].[Vrd_UserClaims] ([Id], [UserId], [ClaimType], [ClaimValue]) SELECT [Id], [UserId], [ClaimType], [ClaimValue] FROM [BkmPanel_BT].[bkm].[Vrd_UserClaims];
SET IDENTITY_INSERT [bkm].[Vrd_UserClaims] OFF;

IF OBJECT_ID(N'bkm.Vrd_UserRoles', N'U') IS NOT NULL THROW 51000, N'bkm.Vrd_UserRoles hedefte zaten var', 1;
CREATE TABLE [bkm].[Vrd_UserRoles] (
    [UserId] nvarchar(450) COLLATE Turkish_CI_AS NOT NULL,
    [RoleId] nvarchar(450) COLLATE Turkish_CI_AS NOT NULL,
    CONSTRAINT [PK_Vrd_UserRoles] PRIMARY KEY CLUSTERED ([UserId], [RoleId])
);
INSERT INTO [bkm].[Vrd_UserRoles] ([UserId], [RoleId]) SELECT [UserId], [RoleId] FROM [BkmPanel_BT].[bkm].[Vrd_UserRoles];

IF OBJECT_ID(N'bkm.Vrd_Users', N'U') IS NOT NULL THROW 51000, N'bkm.Vrd_Users hedefte zaten var', 1;
CREATE TABLE [bkm].[Vrd_Users] (
    [Id] nvarchar(450) COLLATE Turkish_CI_AS NOT NULL,
    [UserName] nvarchar(256) COLLATE Turkish_CI_AS NULL,
    [NormalizedUserName] nvarchar(256) COLLATE Turkish_CI_AS NULL,
    [Email] nvarchar(256) COLLATE Turkish_CI_AS NULL,
    [NormalizedEmail] nvarchar(256) COLLATE Turkish_CI_AS NULL,
    [EmailConfirmed] bit NOT NULL CONSTRAINT [DF_VrdUsers_EmailOnay] DEFAULT ((0)),
    [PasswordHash] nvarchar(max) COLLATE Turkish_CI_AS NULL,
    [SecurityStamp] nvarchar(max) COLLATE Turkish_CI_AS NULL,
    [ConcurrencyStamp] nvarchar(max) COLLATE Turkish_CI_AS NULL,
    [PhoneNumber] nvarchar(50) COLLATE Turkish_CI_AS NULL,
    [PhoneNumberConfirmed] bit NOT NULL CONSTRAINT [DF_VrdUsers_TelOnay] DEFAULT ((0)),
    [TwoFactorEnabled] bit NOT NULL CONSTRAINT [DF_VrdUsers_2FA] DEFAULT ((0)),
    [LockoutEnd] datetimeoffset(7) NULL,
    [LockoutEnabled] bit NOT NULL CONSTRAINT [DF_VrdUsers_KilitAcik] DEFAULT ((1)),
    [AccessFailedCount] int NOT NULL CONSTRAINT [DF_VrdUsers_HataSayac] DEFAULT ((0)),
    CONSTRAINT [PK_Vrd_Users] PRIMARY KEY CLUSTERED ([Id])
);
INSERT INTO [bkm].[Vrd_Users] ([Id], [UserName], [NormalizedUserName], [Email], [NormalizedEmail], [EmailConfirmed], [PasswordHash], [SecurityStamp], [ConcurrencyStamp], [PhoneNumber], [PhoneNumberConfirmed], [TwoFactorEnabled], [LockoutEnd], [LockoutEnabled], [AccessFailedCount]) SELECT [Id], [UserName], [NormalizedUserName], [Email], [NormalizedEmail], [EmailConfirmed], [PasswordHash], [SecurityStamp], [ConcurrencyStamp], [PhoneNumber], [PhoneNumberConfirmed], [TwoFactorEnabled], [LockoutEnd], [LockoutEnabled], [AccessFailedCount] FROM [BkmPanel_BT].[bkm].[Vrd_Users];

IF OBJECT_ID(N'dbo.PanelAsistanBellek', N'U') IS NOT NULL THROW 51000, N'dbo.PanelAsistanBellek hedefte zaten var', 1;
CREATE TABLE [dbo].[PanelAsistanBellek] (
    [Id] bigint IDENTITY(1,1) NOT NULL,
    [Tip] nvarchar(10) COLLATE Turkish_CI_AS NOT NULL CONSTRAINT [DF__PanelAsista__Tip__02FC7413] DEFAULT (N'tercih'),
    [Icerik] nvarchar(400) COLLATE Turkish_CI_AS NOT NULL,
    [Kaynak] nvarchar(20) COLLATE Turkish_CI_AS NOT NULL CONSTRAINT [DF__PanelAsis__Kayna__03F0984C] DEFAULT (N'llm'),
    [Durum] nvarchar(12) COLLATE Turkish_CI_AS NOT NULL CONSTRAINT [DF__PanelAsis__Durum__04E4BC85] DEFAULT (N'aktif'),
    [Olusturma] nvarchar(20) COLLATE Turkish_CI_AS NULL,
    [SonDogrulama] nvarchar(20) COLLATE Turkish_CI_AS NULL,
    [TtlGun] int NOT NULL CONSTRAINT [DF__PanelAsis__TtlGu__05D8E0BE] DEFAULT ((120)),
    CONSTRAINT [PK__PanelAsi__3214EC079B95EC48] PRIMARY KEY CLUSTERED ([Id])
);
SET IDENTITY_INSERT [dbo].[PanelAsistanBellek] ON;
INSERT INTO [dbo].[PanelAsistanBellek] ([Id], [Tip], [Icerik], [Kaynak], [Durum], [Olusturma], [SonDogrulama], [TtlGun]) SELECT [Id], [Tip], [Icerik], [Kaynak], [Durum], [Olusturma], [SonDogrulama], [TtlGun] FROM [BkmPanel_BT].[dbo].[PanelAsistanBellek];
SET IDENTITY_INSERT [dbo].[PanelAsistanBellek] OFF;

IF OBJECT_ID(N'dbo.PanelAsistanGorusme', N'U') IS NOT NULL THROW 51000, N'dbo.PanelAsistanGorusme hedefte zaten var', 1;
CREATE TABLE [dbo].[PanelAsistanGorusme] (
    [Id] bigint IDENTITY(1,1) NOT NULL,
    [Baslik] nvarchar(200) COLLATE Turkish_CI_AS NOT NULL CONSTRAINT [DF__PanelAsis__Basli__08B54D69] DEFAULT (N'Yeni konuşma'),
    [Baslangic] nvarchar(20) COLLATE Turkish_CI_AS NULL,
    [Guncelleme] nvarchar(20) COLLATE Turkish_CI_AS NULL,
    [MesajlarJson] nvarchar(max) COLLATE Turkish_CI_AS NULL,
    [GecmisJson] nvarchar(max) COLLATE Turkish_CI_AS NULL,
    CONSTRAINT [PK__PanelAsi__3214EC07862D318D] PRIMARY KEY CLUSTERED ([Id])
);
SET IDENTITY_INSERT [dbo].[PanelAsistanGorusme] ON;
INSERT INTO [dbo].[PanelAsistanGorusme] ([Id], [Baslik], [Baslangic], [Guncelleme], [MesajlarJson], [GecmisJson]) SELECT [Id], [Baslik], [Baslangic], [Guncelleme], [MesajlarJson], [GecmisJson] FROM [BkmPanel_BT].[dbo].[PanelAsistanGorusme];
SET IDENTITY_INSERT [dbo].[PanelAsistanGorusme] OFF;

IF OBJECT_ID(N'dbo.PanelAyar', N'U') IS NOT NULL THROW 51000, N'dbo.PanelAyar hedefte zaten var', 1;
CREATE TABLE [dbo].[PanelAyar] (
    [Anahtar] nvarchar(60) COLLATE Turkish_CI_AS NOT NULL,
    [Deger] nvarchar(400) COLLATE Turkish_CI_AS NOT NULL,
    [Guncelleme] datetime NOT NULL,
    CONSTRAINT [PK__PanelAya__D1426FEA2C9DCF3A] PRIMARY KEY CLUSTERED ([Anahtar])
);
INSERT INTO [dbo].[PanelAyar] ([Anahtar], [Deger], [Guncelleme]) SELECT [Anahtar], [Deger], [Guncelleme] FROM [BkmPanel_BT].[dbo].[PanelAyar];

IF OBJECT_ID(N'dbo.PanelForecast', N'U') IS NOT NULL THROW 51000, N'dbo.PanelForecast hedefte zaten var', 1;
CREATE TABLE [dbo].[PanelForecast] (
    [Ad] nvarchar(40) COLLATE Turkish_CI_AS NOT NULL,
    [Json] nvarchar(max) COLLATE Turkish_CI_AS NOT NULL,
    [Uretim] datetime2(7) NOT NULL CONSTRAINT [DF__PanelFore__Ureti__693CA210] DEFAULT (sysutcdatetime()),
    CONSTRAINT [PK__PanelFor__3214AD01596113E6] PRIMARY KEY CLUSTERED ([Ad])
);
INSERT INTO [dbo].[PanelForecast] ([Ad], [Json], [Uretim]) SELECT [Ad], [Json], [Uretim] FROM [BkmPanel_BT].[dbo].[PanelForecast];

IF OBJECT_ID(N'dbo.PanelGoogleToken', N'U') IS NOT NULL THROW 51000, N'dbo.PanelGoogleToken hedefte zaten var', 1;
CREATE TABLE [dbo].[PanelGoogleToken] (
    [K] nvarchar(255) COLLATE Turkish_CI_AS NOT NULL,
    [V] nvarchar(max) COLLATE Turkish_CI_AS NOT NULL,
    CONSTRAINT [PK__PanelGoo__3BD019B0BA7435D3] PRIMARY KEY CLUSTERED ([K])
);
INSERT INTO [dbo].[PanelGoogleToken] ([K], [V]) SELECT [K], [V] FROM [BkmPanel_BT].[dbo].[PanelGoogleToken];

IF OBJECT_ID(N'dbo.PanelGorev', N'U') IS NOT NULL THROW 51000, N'dbo.PanelGorev hedefte zaten var', 1;
CREATE TABLE [dbo].[PanelGorev] (
    [Id] bigint IDENTITY(1,1) NOT NULL,
    [Baslik] nvarchar(300) COLLATE Turkish_CI_AS NULL,
    [Aciklama] nvarchar(max) COLLATE Turkish_CI_AS NULL,
    [Oncelik] nvarchar(20) COLLATE Turkish_CI_AS NULL,
    [Atanan] nvarchar(100) COLLATE Turkish_CI_AS NULL,
    [Durum] nvarchar(20) COLLATE Turkish_CI_AS NOT NULL CONSTRAINT [DF__PanelGore__Durum__5CD6CB2B] DEFAULT (N'Açık'),
    [Olusturma] nvarchar(20) COLLATE Turkish_CI_AS NULL,
    [SonTarih] nvarchar(20) COLLATE Turkish_CI_AS NULL,
    CONSTRAINT [PK__PanelGor__3214EC078C0EF45E] PRIMARY KEY CLUSTERED ([Id])
);
SET IDENTITY_INSERT [dbo].[PanelGorev] ON;
INSERT INTO [dbo].[PanelGorev] ([Id], [Baslik], [Aciklama], [Oncelik], [Atanan], [Durum], [Olusturma], [SonTarih]) SELECT [Id], [Baslik], [Aciklama], [Oncelik], [Atanan], [Durum], [Olusturma], [SonTarih] FROM [BkmPanel_BT].[dbo].[PanelGorev];
SET IDENTITY_INSERT [dbo].[PanelGorev] OFF;

IF OBJECT_ID(N'dbo.PanelIcKart', N'U') IS NOT NULL THROW 51000, N'dbo.PanelIcKart hedefte zaten var', 1;
CREATE TABLE [dbo].[PanelIcKart] (
    [Id] bigint NOT NULL,
    [Ad] nvarchar(200) COLLATE Turkish_CI_AS NOT NULL,
    [KayitTarih] nvarchar(20) COLLATE Turkish_CI_AS NOT NULL,
    CONSTRAINT [PK__PanelIcK__3214EC074848B283] PRIMARY KEY CLUSTERED ([Id])
);
INSERT INTO [dbo].[PanelIcKart] ([Id], [Ad], [KayitTarih]) SELECT [Id], [Ad], [KayitTarih] FROM [BkmPanel_BT].[dbo].[PanelIcKart];

IF OBJECT_ID(N'dbo.PanelKolonTercih', N'U') IS NOT NULL THROW 51000, N'dbo.PanelKolonTercih hedefte zaten var', 1;
CREATE TABLE [dbo].[PanelKolonTercih] (
    [Kullanici] nvarchar(80) COLLATE Turkish_CI_AS NOT NULL,
    [Ekran] nvarchar(40) COLLATE Turkish_CI_AS NOT NULL,
    [Kolonlar] nvarchar(2000) COLLATE Turkish_CI_AS NOT NULL,
    [Guncelleme] datetime NOT NULL,
    CONSTRAINT [PK_PanelKolonTercih] PRIMARY KEY CLUSTERED ([Kullanici], [Ekran])
);
INSERT INTO [dbo].[PanelKolonTercih] ([Kullanici], [Ekran], [Kolonlar], [Guncelleme]) SELECT [Kullanici], [Ekran], [Kolonlar], [Guncelleme] FROM [BkmPanel_BT].[dbo].[PanelKolonTercih];

IF OBJECT_ID(N'dbo.PanelKullanici', N'U') IS NOT NULL THROW 51000, N'dbo.PanelKullanici hedefte zaten var', 1;
CREATE TABLE [dbo].[PanelKullanici] (
    [Id] int IDENTITY(1,1) NOT NULL,
    [KullaniciAdi] nvarchar(50) COLLATE Turkish_CI_AS NOT NULL,
    [SifreHash] varbinary(32) NULL,
    [Salt] varbinary(16) NULL,
    [Iterasyon] int NOT NULL CONSTRAINT [DF__PanelKull__Itera__4AB81AF0] DEFAULT ((100000)),
    [Aktif] bit NOT NULL CONSTRAINT [DF__PanelKull__Aktif__4BAC3F29] DEFAULT ((1)),
    [SonGiris] datetime2(7) NULL,
    [BasarisizSayac] int NOT NULL CONSTRAINT [DF__PanelKull__Basar__4CA06362] DEFAULT ((0)),
    [KilitBitis] datetime2(7) NULL,
    [OlusturmaTrh] datetime2(7) NOT NULL CONSTRAINT [DF__PanelKull__Olust__4D94879B] DEFAULT (sysutcdatetime()),
    CONSTRAINT [PK__PanelKul__3214EC072903DC9E] PRIMARY KEY CLUSTERED ([Id]),
    CONSTRAINT [UQ__PanelKul__5BAE6A75193977CA] UNIQUE NONCLUSTERED ([KullaniciAdi])
);
SET IDENTITY_INSERT [dbo].[PanelKullanici] ON;
INSERT INTO [dbo].[PanelKullanici] ([Id], [KullaniciAdi], [SifreHash], [Salt], [Iterasyon], [Aktif], [SonGiris], [BasarisizSayac], [KilitBitis], [OlusturmaTrh]) SELECT [Id], [KullaniciAdi], [SifreHash], [Salt], [Iterasyon], [Aktif], [SonGiris], [BasarisizSayac], [KilitBitis], [OlusturmaTrh] FROM [BkmPanel_BT].[dbo].[PanelKullanici];
SET IDENTITY_INSERT [dbo].[PanelKullanici] OFF;

IF OBJECT_ID(N'dbo.PanelTahminKayit', N'U') IS NOT NULL THROW 51000, N'dbo.PanelTahminKayit hedefte zaten var', 1;
CREATE TABLE [dbo].[PanelTahminKayit] (
    [Id] nvarchar(50) COLLATE Turkish_CI_AS NOT NULL,
    [Year] int NOT NULL,
    [Month] int NOT NULL,
    [MekanId] int NOT NULL,
    [Tahmin] decimal(18,4) NULL,
    [Alt] decimal(18,4) NULL,
    [Ust] decimal(18,4) NULL,
    [IvmePct] decimal(18,4) NULL,
    [YoYTaban] decimal(18,4) NULL,
    [Carpan] decimal(18,4) NULL,
    [KayitTarih] nvarchar(20) COLLATE Turkish_CI_AS NOT NULL,
    CONSTRAINT [PK__PanelTah__3214EC07312B2D41] PRIMARY KEY CLUSTERED ([Id]),
    CONSTRAINT [UQ_PanelTahmin] UNIQUE NONCLUSTERED ([Year], [Month], [MekanId])
);
INSERT INTO [dbo].[PanelTahminKayit] ([Id], [Year], [Month], [MekanId], [Tahmin], [Alt], [Ust], [IvmePct], [YoYTaban], [Carpan], [KayitTarih]) SELECT [Id], [Year], [Month], [MekanId], [Tahmin], [Alt], [Ust], [IvmePct], [YoYTaban], [Carpan], [KayitTarih] FROM [BkmPanel_BT].[dbo].[PanelTahminKayit];

IF OBJECT_ID(N'dbo.PanelTakvim', N'U') IS NOT NULL THROW 51000, N'dbo.PanelTakvim hedefte zaten var', 1;
CREATE TABLE [dbo].[PanelTakvim] (
    [Id] int IDENTITY(1,1) NOT NULL,
    [Bas] date NOT NULL,
    [Son] date NOT NULL,
    [Ad] nvarchar(120) COLLATE Turkish_CI_AS NOT NULL,
    [Tip] nvarchar(20) COLLATE Turkish_CI_AS NOT NULL,
    [YarimGun] bit NOT NULL CONSTRAINT [DF__PanelTakv__Yarim__66603565] DEFAULT ((0)),
    CONSTRAINT [PK__PanelTak__3214EC07E3D118A2] PRIMARY KEY CLUSTERED ([Id])
);
SET IDENTITY_INSERT [dbo].[PanelTakvim] ON;
INSERT INTO [dbo].[PanelTakvim] ([Id], [Bas], [Son], [Ad], [Tip], [YarimGun]) SELECT [Id], [Bas], [Son], [Ad], [Tip], [YarimGun] FROM [BkmPanel_BT].[dbo].[PanelTakvim];
SET IDENTITY_INSERT [dbo].[PanelTakvim] OFF;

-- indeksler + yabancı anahtarlar (veri yüklendikten sonra)
CREATE NONCLUSTERED INDEX [IX_SolumAuditTrail_Kayit] ON [bkm].[SolumAuditTrail] ([EntityName], [RecordId]);
CREATE NONCLUSTERED INDEX [IX_SolumPermissionGrant_Saglayici] ON [bkm].[SolumPermissionGrant] ([ProviderName], [ProviderKey]) INCLUDE ([PermissionName]);
CREATE UNIQUE NONCLUSTERED INDEX [UX_SolumUserCompanyAccess] ON [bkm].[SolumUserCompanyAccess] ([UserId], [CompanyId]);
CREATE NONCLUSTERED INDEX [IX_Vrd_KisiGun_Kesim] ON [bkm].[Vrd_KisiGun] ([KesimBas], [KesimBit], [Sube], [Tarih]) INCLUDE ([SicilNo], [Personel], [Durum], [CalismaDk], [PlanCalismaDk]);
CREATE NONCLUSTERED INDEX [IX_Vrd_KisiGun_Kisi] ON [bkm].[Vrd_KisiGun] ([SicilNo], [Tarih]) INCLUDE ([KesimBas], [KesimBit]);
CREATE NONCLUSTERED INDEX [IX_Vrd_KisiGun_KesimUyum] ON [bkm].[Vrd_KisiGun] ([KesimBas], [KesimBit]) INCLUDE ([SicilNo], [Tarih], [CalismaDk], [GirisDk], [CikisDk], [Izin], [OlcumNotu]);
CREATE UNIQUE NONCLUSTERED INDEX [UX_Vrd_KullaniciSube_Acik] ON [bkm].[Vrd_KullaniciSube] ([UserId], [Sube]) WHERE ([GecerliBit] IS NULL);
CREATE NONCLUSTERED INDEX [IX_Vrd_PlanDuzeltme_Tarih] ON [bkm].[Vrd_PlanDuzeltme] ([Tarih]) INCLUDE ([SicilNo], [PlanCalismaDk], [IzinliMi]);
CREATE UNIQUE NONCLUSTERED INDEX [UX_Vrd_Roles_Ad] ON [bkm].[Vrd_Roles] ([NormalizedName]) WHERE ([NormalizedName] IS NOT NULL);
CREATE NONCLUSTERED INDEX [IX_Vrd_UserClaims_Kisi] ON [bkm].[Vrd_UserClaims] ([UserId]);
CREATE UNIQUE NONCLUSTERED INDEX [UX_Vrd_Users_Ad] ON [bkm].[Vrd_Users] ([NormalizedUserName]) WHERE ([NormalizedUserName] IS NOT NULL);
ALTER TABLE [bkm].[Vrd_UserRoles] WITH CHECK ADD CONSTRAINT [FK_Vrd_UserRoles_User] FOREIGN KEY ([UserId]) REFERENCES [bkm].[Vrd_Users] ([Id]) ON DELETE CASCADE;
ALTER TABLE [bkm].[Vrd_UserRoles] WITH CHECK ADD CONSTRAINT [FK_Vrd_UserRoles_Role] FOREIGN KEY ([RoleId]) REFERENCES [bkm].[Vrd_Roles] ([Id]) ON DELETE CASCADE;
ALTER TABLE [bkm].[Vrd_UserClaims] WITH CHECK ADD CONSTRAINT [FK_Vrd_UserClaims_User] FOREIGN KEY ([UserId]) REFERENCES [bkm].[Vrd_Users] ([Id]) ON DELETE CASCADE;
ALTER TABLE [bkm].[Vrd_KullaniciSube] WITH CHECK ADD CONSTRAINT [FK_Vrd_KullaniciSube_User] FOREIGN KEY ([UserId]) REFERENCES [bkm].[Vrd_Users] ([Id]) ON DELETE CASCADE;
ALTER TABLE [bkm].[Vrd_KullaniciSube] WITH CHECK ADD CONSTRAINT [FK_Vrd_KullaniciSube_Sube] FOREIGN KEY ([Sube]) REFERENCES [bkm].[Vrd_Sube] ([Sube]);

EXEC(N'
CREATE FUNCTION bkm.Vrd_SubeKapsami (@KullaniciId nvarchar(450))
RETURNS TABLE
AS
RETURN
(
    -- (1) "Tüm şubeler" yetkisi → şube kümesinin TAMAMI (canlı okunur;
    --     yeni açılan şube kendiliğinden kapsama girer).
    SELECT s.Sube
    FROM   bkm.Vrd_Sube AS s
    WHERE  EXISTS (
        SELECT 1
        FROM   bkm.SolumPermissionGrant AS g
        WHERE  g.PermissionName = N''vardiya.tumSubeler''
          AND  (
                 (g.ProviderName = N''User'' AND g.ProviderKey = @KullaniciId)
              OR (g.ProviderName = N''Role'' AND EXISTS (
                     SELECT 1
                     FROM   bkm.Vrd_UserRoles AS ur
                     JOIN   bkm.Vrd_Roles     AS r ON r.Id = ur.RoleId
                     WHERE  ur.UserId = @KullaniciId
                       AND  r.Name    = g.ProviderKey))
               )
    )

    UNION

    -- (2) ACL: BUGÜN geçerli olan satırlar.
    --     "Bugün sorumluysan geçmişi de görürsün" — tarih süzgeci YOK.
    SELECT ks.Sube
    FROM   bkm.Vrd_KullaniciSube AS ks
    WHERE  ks.UserId = @KullaniciId
      AND  ks.GecerliBas <= CAST(SYSDATETIME() AS date)
      AND  (ks.GecerliBit IS NULL OR ks.GecerliBit >= CAST(SYSDATETIME() AS date))
);
');

EXEC(N'
CREATE VIEW bkm.Vrd_KisiGunDuzeltilmis_vw
AS
SELECT
    k.*,

    -- ── DÜZELTME ALANLARI (ham hâlleriyle — ekran ikisini de gösterebilsin) ──
    DuzeltmeVardiyaTanim  = d.VardiyaTanim,
    DuzeltmePlanBaslamaDk = d.PlanBaslamaDk,
    DuzeltmePlanBitisDk   = d.PlanBitisDk,
    DuzeltmePlanCalismaDk = d.PlanCalismaDk,
    DuzeltmeIzinliMi      = d.IzinliMi,
    DuzeltmeAciklama      = d.Aciklama,
    DuzeltmeKaydeden      = d.Kaydeden,
    DuzeltmeKayitUtc      = d.KayitUtc,
    DuzeltildiMi          = CASE WHEN d.SicilNo IS NULL THEN CONVERT(bit, 0) ELSE CONVERT(bit, 1) END,

    -- ── ETKİN DEĞERLER — düzeltme varsa o, yoksa kaynağın değeri ─────────────
    EtkinVardiyaTanim = ISNULL(d.VardiyaTanim, k.VardiyaTanim),

    -- Etkin taban, ÜÇ dallı — ikinci dal bir ÖLÇÜMDEN doğdu (19.09):
    --   1) düzeltme "izinli" diyorsa taban 0 (izinli günün tabanı yoktur),
    --   2) KAYNAK izinli ve düzeltme bu konuda SUSUYORSA taban DEĞİŞMEZ,
    --   3) aksi hâlde düzeltilmiş süre, o da yoksa SP''nin yazdığı `GerekenDk`.
    --
    -- ⚠ İKİNCİ DAL OLMADAN NE OLUYORDU (ölçüldü, geri alınabilir işlemde):
    --   izinli bir güne süre yazılınca `EtkinEksikDk` 0 → 480 oluyordu; yani
    --   kişi İZİNDEYKEN 8 saat EKSİK görünüyordu. Delta aritmetiği doğruydu,
    --   ANLAMI yanlıştı — Solum''un "çok adımlı mantığı tek satırlık fikstürle
    --   ölçemezsin" uyarısının bizdeki karşılığı: tek NORMAL gün üzerinde
    --   test edildiği için görünmüyordu.
    --
    -- ⚠ "Aslında izinli DEĞİLDİ" demek hâlâ mümkün: `IzinliMi = 0` yazılırsa
    --   üçüncü dala düşer ve süre uygulanır. Yani kaynak EZİLMİYOR, ama
    --   bilinçli bir itiraz yazılabiliyor (karar S3).
    EtkinGerekenDk = CASE
        WHEN d.IzinliMi = 1 THEN 0
        WHEN k.Izin = 1 AND d.IzinliMi IS NULL THEN ISNULL(k.GerekenDk, 0)
        ELSE ISNULL(d.PlanCalismaDk, k.GerekenDk) END,

    -- ── ETKİN EKSİK/FAZLA — SP''NİN DEĞERİNE TABAN FARKI UYGULANIR ──────────
    --
    -- ⚠ İLK YAZIMDA FORMÜL SIFIRDAN YENİDEN YAZILMIŞTI ve SP''den AYRIŞTI:
    --   mutabakat 82.800 dk fark verdi. Sebep: SP''nin `FazlaDk`ı yalnız
    --   `Net2 - Gereken` değil — izin gününde hafta tatili primi (`HaftalikPrimDk`,
    --   540 dk) de içinde. Yani "aynı formülü yazdım" sanmak YETMEDİ; formülün
    --   TAMAMI SP''nin dört ayrı UPDATE bloğuna yayılmış.
    --
    -- DOĞRU MEKANİZMA: formülü kopyalamak değil, TABAN FARKINI uygulamak.
    --   Δ = EtkinGereken - Gereken   (düzeltme yoksa Δ = 0)
    --   Eksik'' = max(Eksik + Δ, 0)   ·   Fazla'' = max(Fazla - Δ, 0)
    -- Düzeltme YOKKEN sonuç SP''nin değerinin AYNISI olur — mutabakat aritmetik
    -- olarak garanti, iddia değil. Prim gibi taban-dışı kalemler olduğu gibi taşınır
    -- (vardiya tanımı hafta tatili primini değiştirmez).
    EtkinEksikDk = CASE WHEN k.SayimDisi = 1 THEN 0 ELSE
        CASE WHEN ISNULL(k.EksikDk, 0)
                + (CASE WHEN d.IzinliMi = 1 THEN 0
                            WHEN k.Izin = 1 AND d.IzinliMi IS NULL THEN ISNULL(k.GerekenDk, 0)
                            ELSE ISNULL(d.PlanCalismaDk, k.GerekenDk) END
                   - ISNULL(k.GerekenDk, 0)) > 0
             THEN ISNULL(k.EksikDk, 0)
                + (CASE WHEN d.IzinliMi = 1 THEN 0
                            WHEN k.Izin = 1 AND d.IzinliMi IS NULL THEN ISNULL(k.GerekenDk, 0)
                            ELSE ISNULL(d.PlanCalismaDk, k.GerekenDk) END
                   - ISNULL(k.GerekenDk, 0))
             ELSE 0 END END,

    EtkinFazlaDk = CASE WHEN k.SayimDisi = 1 THEN 0 ELSE
        CASE WHEN ISNULL(k.FazlaDk, 0)
                - (CASE WHEN d.IzinliMi = 1 THEN 0
                            WHEN k.Izin = 1 AND d.IzinliMi IS NULL THEN ISNULL(k.GerekenDk, 0)
                            ELSE ISNULL(d.PlanCalismaDk, k.GerekenDk) END
                   - ISNULL(k.GerekenDk, 0)) > 0
             THEN ISNULL(k.FazlaDk, 0)
                - (CASE WHEN d.IzinliMi = 1 THEN 0
                            WHEN k.Izin = 1 AND d.IzinliMi IS NULL THEN ISNULL(k.GerekenDk, 0)
                            ELSE ISNULL(d.PlanCalismaDk, k.GerekenDk) END
                   - ISNULL(k.GerekenDk, 0))
             ELSE 0 END END

FROM       bkm.Vrd_KisiGun       k
LEFT JOIN  bkm.Vrd_PlanDuzeltme  d
       ON  d.SicilNo = k.SicilNo AND d.Tarih = k.Tarih;
');

EXEC(N'
CREATE VIEW bkm.Vrd_KullaniciSubeGecmis_vw
AS
SELECT  ks.UserId,
        u.UserName,
        ks.Sube,
        ks.GecerliBas,
        ks.GecerliBit,
        Durum = CASE WHEN ks.GecerliBit IS NULL THEN N''açık'' ELSE N''kapalı'' END,
        ks.VerenId,
        ks.VerilmeUtc
FROM    bkm.Vrd_KullaniciSube AS ks
LEFT JOIN bkm.Vrd_Users       AS u ON u.Id = ks.UserId;
');

EXEC(N'/* ============================================================================
   bkm.sp_Vrd_KisiGunDoldur — kişi-gün tabanının T-SQL karşılığı (plan 47, Faz 1)
   Hedef : DEV → BkmPanel @ BT-FIKRI\SQLEXPRESS. PROD''a yazma YOK.

   Kurallar `scripts/vardiya_pdks_program_raporu.py` çekirdeğinden BİREBİR
   taşındı; hiçbiri burada YENİDEN İCAT EDİLMEDİ. Kapı: SP çıktısı ile Python
   çıktısı kişi-gün bazında karşılaştırılır, **fark 0 çıkmadan Python emekli
   edilmez** (iki uygulama sessizce ayrışmasın diye).

   ERİŞİM (ölçüldü 17.09.2026): yerelde `LIVE201 → 192.168.40.201` linked server
   var ve ÇİFT ATLAMA çalışıyor —
       OPENQUERY(LIVE201, ''… OPENQUERY([PDKS], ''''…'''') …'')
   Tırnak katmanı üç seviye olduğu için sorgular DEĞİŞKENDE kurulur ve her
   katmanda `REPLACE(x, '''''''', '''''''''''')` ile kaçırılır; elle tırnak sayma YAPILMAZ.

   ⚠ SÜRELER DAKİKA. Gece mesaisinde çıkış ertesi güne sarkar (>1440) ve `time`
     tipi bunu tutamaz.
   ============================================================================ */

CREATE   PROCEDURE bkm.sp_Vrd_KisiGunDoldur
    @Bas      date,
    @Bit      date,
    @SayimBas date = NULL,        -- NULL → @Bas
    @Konus    bit  = 1            -- 1 → ekrana özet yaz
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @SayimBas IS NULL SET @SayimBas = @Bas;
    IF @SayimBas < @Bas
        THROW 50001, ''KOSAMADI: @SayimBas, @Bas''''tan once olamaz.'', 1;

    DECLARE @bas8 char(8) = CONVERT(char(8), @Bas, 112),
            @bit8 char(8) = CONVERT(char(8), @Bit, 112);
    DECLARE @l2 nvarchar(max), @l1 nvarchar(max), @sql nvarchar(max);
    DECLARE @TOLERANS int = 10;   -- dk, ÇİFT YÖNLÜ (ölçüldü 521/521)

    -- =====================================================================
    -- 1) VARDİYA PLANI — 201 üstünde, PDKS''e inmeden
    --    `Tarih` haftanın PAZARTESİ''sidir; gün ofseti CROSS APPLY ile açılır.
    --    VardiyaId = 0 → o gün vardiya atanmamış (SIFIR SENTİNEL, NULL değil).
    -- =====================================================================
    CREATE TABLE #plan (
        SubeAd nvarchar(50), SicilNo varchar(11), Personel nvarchar(120),
        Bolum nvarchar(80), Gorev nvarchar(120), Tarih date,
        VardiyaTanim nvarchar(60), Baslama time(0), Bitis time(0),
        ToplamCalismaDk int, Izin bit);

    SET @l1 = N''
        SELECT  s.SubeAd,
                LTRIM(RTRIM(vd.SicilNo)) AS SicilNo,
                vd.Personel, vd.Bolum, vd.Gorev,
                CONVERT(date, DATEADD(day, g.ofs, v.Tarih)) AS Tarih,
                vz.Aciklama AS VardiyaTanim, vz.Baslama, vz.Bitis,
                vz.ToplamCalismaDk, vz.Izin
        FROM        BKM.vrd.Vardiya       v
        INNER JOIN  BKM.vrd.SubeListe     s  ON s.SubeNo    = v.SubeNo
        INNER JOIN  BKM.vrd.VardiyaDetay  vd ON vd.VardiyaNo = v.VardiyaNo
        CROSS APPLY (VALUES (0, vd.Pazartesi), (1, vd.Sali), (2, vd.Carsamba),
                            (3, vd.Persembe), (4, vd.Cuma), (5, vd.Cumartesi),
                            (6, vd.Pazar)) AS g(ofs, VardiyaId)
        LEFT  JOIN  BKM.vrd.VardiyaZaman  vz ON vz.VardiyaId = g.VardiyaId
        WHERE   g.VardiyaId <> 0
            AND DATEADD(day, g.ofs, v.Tarih) >= '''''' + @bas8 + ''''''
            AND DATEADD(day, g.ofs, v.Tarih) <= '''''' + @bit8 + '''''''';

    SET @sql = N''INSERT INTO #plan SELECT * FROM OPENQUERY(LIVE201, ''''''
             + REPLACE(@l1, '''''''', '''''''''''') + '''''') p'';
    EXEC sp_executesql @sql;

    IF NOT EXISTS (SELECT 1 FROM #plan)
        THROW 50002, ''KOSAMADI: plan satiri YOK. Bos nufus "ihlal yok" demek degildir.'', 1;

    -- =====================================================================
    -- 2) TC → PersNr  (PDKS, çift atlama)
    --    ⚠ MÜKERRER TC: 11 TC iki PersNr taşıyor (yeniden işe giriş). Doğru
    --      kayıt ÖLÇÜLDÜ: 11''inin 11''inde tam biri `Per_ZeitAktiv = 1` ve kart
    --      okumaları onda. MIN/MAX tahmini DEĞİL, bu süzgeç kullanılır.
    --    ⚠ `Per_ZeitAktiv` "personel aktif mi" DEĞİL, "PDKS zaman takibi açık
    --      mı" demektir — müdürlerde 0''dır ve onlar çalışmaktadır.
    -- =====================================================================
    CREATE TABLE #tc (TC varchar(11) COLLATE Turkish_CI_AS, PersNr int, Aktif int);

    SET @l2 = N''
        SELECT i.PIn_SteuerNr AS TC, i.PIn_PersNr AS PersNr,
               ISNULL(p.Per_ZeitAktiv, 0) AS Aktif
        FROM TPerInd i LEFT JOIN TPerTab p ON p.Per_PersNr = i.PIn_PersNr
        WHERE i.PIn_SteuerNr <> '''''''''';
    SET @l1 = N''SELECT x.TC COLLATE Turkish_CI_AS AS TC, x.PersNr, x.Aktif
                FROM OPENQUERY([PDKS], '''''' + REPLACE(@l2, '''''''', '''''''''''') + '''''') x'';
    SET @sql = N''INSERT INTO #tc SELECT * FROM OPENQUERY(LIVE201, ''''''
             + REPLACE(@l1, '''''''', '''''''''''') + '''''') y'';
    EXEC sp_executesql @sql;

    CREATE TABLE #tcTek (TC varchar(11) COLLATE Turkish_CI_AS PRIMARY KEY, PersNr int);
    INSERT INTO #tcTek (TC, PersNr)
    SELECT TC, PersNr FROM (
        SELECT TC, PersNr,
               ROW_NUMBER() OVER (PARTITION BY TC ORDER BY Aktif DESC, PersNr DESC) rn
        FROM #tc) t WHERE rn = 1;

    -- =====================================================================
    -- 3) PDKS GÜNLÜK ÖZET — TLe_BeginnKz = 0 (günün ilk satırı / gün özeti)
    -- =====================================================================
    CREATE TABLE #pdks (
        TC varchar(11) COLLATE Turkish_CI_AS, Gun char(8),
        Giris datetime NULL, Cikis datetime NULL,
        KayitSayisi int, Mazeret nvarchar(40) NULL);

    SET @l2 = N''
        SELECT  i.PIn_SteuerNr AS TC, CONVERT(char(8), l.TLe_Datum, 112) AS Gun,
                MIN(l.TLe_VonZeit) AS Giris, MAX(l.TLe_BisZeit) AS Cikis,
                COUNT(*) AS KayitSayisi, MIN(l.TLe_AbwArt) AS Mazeret
        FROM        TPerInd i
        INNER JOIN  TTagLes l ON l.TLe_PersNr = i.PIn_PersNr
        WHERE   l.TLe_Datum >= '''''' + @bas8 + '''''' AND l.TLe_Datum <= '''''' + @bit8 + ''''''
            AND l.TLe_BeginnKz = 0 AND i.PIn_SteuerNr <> ''''''''
        GROUP BY i.PIn_SteuerNr, CONVERT(char(8), l.TLe_Datum, 112)'';
    SET @l1 = N''SELECT x.TC COLLATE Turkish_CI_AS AS TC, x.Gun, x.Giris, x.Cikis,
                       x.KayitSayisi, x.Mazeret
                FROM OPENQUERY([PDKS], '''''' + REPLACE(@l2, '''''''', '''''''''''') + '''''') x'';
    SET @sql = N''INSERT INTO #pdks SELECT * FROM OPENQUERY(LIVE201, ''''''
             + REPLACE(@l1, '''''''', '''''''''''') + '''''') y'';
    EXEC sp_executesql @sql;

    IF NOT EXISTS (SELECT 1 FROM #pdks)
        THROW 50003, ''KOSAMADI: PDKS tarafi BOS dondu -- okuma gercekten yok mu, yoksa linked server mi dustu?'', 1;

    -- =====================================================================
    -- 4) HAM OKUTMA (TZeiBuf) — "Devamsız" etiketini DENETLEMEK için.
    --    `TTagLes` giriş+çıkış ÇİFTİ ister; tek okutma yapan kişide satır
    --    OLUŞMAZ ve rapor "Devamsız" der. Ham okutmada görünür.
    -- =====================================================================
    CREATE TABLE #ham (TC varchar(11) COLLATE Turkish_CI_AS, Gun char(8), Okutma int);

    SET @l2 = N''
        SELECT  i.PIn_SteuerNr AS TC, CONVERT(char(8), b.ZBu_ErfDatum, 112) AS Gun,
                COUNT(*) AS Okutma
        FROM        TZeiBuf b
        INNER JOIN  TPerInd i ON i.PIn_PersNr = b.ZBu_PersNr
        WHERE   b.ZBu_ErfDatum >= '''''' + @bas8 + '''''' AND b.ZBu_ErfDatum <= '''''' + @bit8 + ''''''
            AND ISNULL(b.ZBu_Storniert, 0) = 0 AND i.PIn_SteuerNr <> ''''''''
        GROUP BY i.PIn_SteuerNr, CONVERT(char(8), b.ZBu_ErfDatum, 112)'';
    SET @l1 = N''SELECT x.TC COLLATE Turkish_CI_AS AS TC, x.Gun, x.Okutma
                FROM OPENQUERY([PDKS], '''''' + REPLACE(@l2, '''''''', '''''''''''') + '''''') x'';
    SET @sql = N''INSERT INTO #ham SELECT * FROM OPENQUERY(LIVE201, ''''''
             + REPLACE(@l1, '''''''', '''''''''''') + '''''') y'';
    EXEC sp_executesql @sql;

    -- =====================================================================
    -- 5) PLANSIZ AMA KART BASAN — kapsam PDKS tarafından çizilir (Per_Grp1 +
    --    Per_Grp2), plandan DEĞİL. Hafta içinde işe giren plana işlenmemiş
    --    olabilir; kart bastıysa raporda GÖRÜNMELİ (kullanıcı isteği 15.09).
    --    ⚠ Per_Grp2 TEK BAŞINA YETMEZ: "FSM" hem mağazanın hem FSM KAFE''nin
    --      Per_Grp2''si; ayıran Per_Grp1 (MAĞAZALAR / KAFELER).
    --    Python şube şube döngüyle çekiyor; burada TEK GEÇİŞTE çekilip yerelde
    --    eşleniyor — sonuç aynı, tur sayısı 9 yerine 2.
    -- =====================================================================
    CREATE TABLE #subeGrp (SubeAd nvarchar(50) COLLATE Turkish_CI_AS,
                           G1 nvarchar(60) COLLATE Turkish_CI_AS,
                           G2 nvarchar(60) COLLATE Turkish_CI_AS);
    SET @l2 = N''SELECT SubeAd, Per_Grp1, Per_Grp2 FROM bkm.SubeListe WHERE Per_Grp2 IS NOT NULL'';
    -- ⚠ COLLATE uygulanan her ifadeye TAKMA AD şart; adsız kolon `INSERT … SELECT`
    --   içinde "An object or column name is missing or empty" ile patlar (ölçüldü).
    SET @l1 = N''SELECT SubeAd = x.SubeAd COLLATE Turkish_CI_AS,
                       G1 = LTRIM(RTRIM(x.Per_Grp1)) COLLATE Turkish_CI_AS,
                       G2 = LTRIM(RTRIM(x.Per_Grp2)) COLLATE Turkish_CI_AS
                FROM OPENQUERY([PDKS], '''''' + REPLACE(@l2, '''''''', '''''''''''') + '''''') x'';
    SET @sql = N''INSERT INTO #subeGrp SELECT * FROM OPENQUERY(LIVE201, ''''''
             + REPLACE(@l1, '''''''', '''''''''''') + '''''') y'';
    EXEC sp_executesql @sql;

    CREATE TABLE #pdksGrp (
        TC varchar(11) COLLATE Turkish_CI_AS, PersNr int, Ad nvarchar(120),
        G1 nvarchar(60) COLLATE Turkish_CI_AS, G2 nvarchar(60) COLLATE Turkish_CI_AS,
        Gun char(8), Giris datetime NULL, Cikis datetime NULL,
        KayitSayisi int, Mazeret nvarchar(40) NULL);

    SET @l2 = N''
        SELECT  ISNULL(i.PIn_SteuerNr, '''''''') AS TC, p.Per_PersNr AS PersNr,
                LTRIM(RTRIM(p.Per_Vorname)) + '''' '''' + LTRIM(RTRIM(p.Per_Name)) AS Ad,
                LTRIM(RTRIM(p.Per_Grp1)) AS G1, LTRIM(RTRIM(p.Per_Grp2)) AS G2,
                CONVERT(char(8), l.TLe_Datum, 112) AS Gun,
                MIN(l.TLe_VonZeit) AS Giris, MAX(l.TLe_BisZeit) AS Cikis,
                COUNT(*) AS KayitSayisi, MIN(l.TLe_AbwArt) AS Mazeret
        FROM        TPerTab p
        INNER JOIN  TTagLes l ON l.TLe_PersNr = p.Per_PersNr
        LEFT  JOIN  TPerInd i ON i.PIn_PersNr = p.Per_PersNr
        WHERE   l.TLe_Datum >= '''''' + @bas8 + '''''' AND l.TLe_Datum <= '''''' + @bit8 + ''''''
            AND l.TLe_BeginnKz = 0
        GROUP BY i.PIn_SteuerNr, p.Per_PersNr, p.Per_Vorname, p.Per_Name,
                 p.Per_Grp1, p.Per_Grp2, CONVERT(char(8), l.TLe_Datum, 112)'';
    SET @l1 = N''SELECT TC = x.TC COLLATE Turkish_CI_AS, x.PersNr, x.Ad,
                       G1 = x.G1 COLLATE Turkish_CI_AS, G2 = x.G2 COLLATE Turkish_CI_AS,
                       x.Gun, x.Giris, x.Cikis, x.KayitSayisi, x.Mazeret
                FROM OPENQUERY([PDKS], '''''' + REPLACE(@l2, '''''''', '''''''''''') + '''''') x'';
    SET @sql = N''INSERT INTO #pdksGrp SELECT * FROM OPENQUERY(LIVE201, ''''''
             + REPLACE(@l1, '''''''', '''''''''''') + '''''') y'';
    EXEC sp_executesql @sql;

    -- =====================================================================
    -- 6) BİRLEŞİK KİŞİ-GÜN — planlı + plansız
    -- =====================================================================
    CREATE TABLE #sat (
        SubeAd nvarchar(50), SicilNo varchar(11), Personel nvarchar(120),
        Bolum nvarchar(80), Gorev nvarchar(120), Tarih date,
        VardiyaTanim nvarchar(60), PlanBasDk int NULL, PlanBitDk int NULL,
        PlanCalismaDk int, Izin bit, Plansiz bit,
        KartGirisDk int NULL, KartCikisDk int NULL,
        KayitSayisi int NULL, Mazeret nvarchar(40) NULL, PersNr int NULL,
        HamOkutma int NULL);

    INSERT INTO #sat
    SELECT  p.SubeAd, p.SicilNo, p.Personel, p.Bolum, p.Gorev, p.Tarih,
            p.VardiyaTanim,
            DATEDIFF(minute, 0, p.Baslama), DATEDIFF(minute, 0, p.Bitis),
            ISNULL(p.ToplamCalismaDk, 0), ISNULL(p.Izin, 0), 0,
            DATEPART(hour, d.Giris) * 60 + DATEPART(minute, d.Giris),
            DATEPART(hour, d.Cikis) * 60 + DATEPART(minute, d.Cikis),
            d.KayitSayisi, d.Mazeret, t.PersNr, h.Okutma
    FROM        #plan p
    LEFT  JOIN  #pdks  d ON d.TC = p.SicilNo AND d.Gun = CONVERT(char(8), p.Tarih, 112)
    LEFT  JOIN  #tcTek t ON t.TC = p.SicilNo
    LEFT  JOIN  #ham   h ON h.TC = p.SicilNo AND h.Gun = CONVERT(char(8), p.Tarih, 112);

    -- Plansız: bu şubenin PDKS grubunda kart basmış ama plan anahtarı olmayan.
    -- Kişi bilgisi (Bölüm/Görev) plandan gelir; yoksa NULL bırakılır — UYDURULMAZ.
    INSERT INTO #sat
    SELECT  sg.SubeAd, g.TC, ISNULL(k.Personel, g.Ad), k.Bolum, k.Gorev,
            CONVERT(date, g.Gun), NULL, NULL, NULL, 0, 0, 1,
            DATEPART(hour, g.Giris) * 60 + DATEPART(minute, g.Giris),
            DATEPART(hour, g.Cikis) * 60 + DATEPART(minute, g.Cikis),
            g.KayitSayisi, g.Mazeret, g.PersNr, NULL
    FROM        #pdksGrp g
    INNER JOIN  #subeGrp sg ON sg.G1 = g.G1 AND sg.G2 = g.G2
    OUTER APPLY (SELECT TOP 1 x.Personel, x.Bolum, x.Gorev
                 FROM #plan x WHERE x.SicilNo = g.TC
                 ORDER BY x.Tarih) k
    WHERE NOT EXISTS (SELECT 1 FROM #plan x
                      WHERE x.SicilNo = g.TC
                        AND CONVERT(char(8), x.Tarih, 112) = g.Gun);

    -- =====================================================================
    -- 7) HESAP — tolerans · gün dönümü · mola · durum
    -- =====================================================================
    DELETE FROM bkm.Vrd_KisiGun WHERE KesimBas = @Bas AND KesimBit = @Bit;

    ;WITH h AS (
        SELECT s.*,
               -- İzin gününde plan başlaması 0 sayılır (ölçüldü: araç böyle yapıyor)
               planBas0 = CASE WHEN s.Izin = 1 THEN 0 ELSE ISNULL(s.PlanBasDk, 0) END,
               varsa    = CASE WHEN s.KartGirisDk IS NOT NULL
                                AND s.KartCikisDk IS NOT NULL THEN 1 ELSE 0 END
        FROM #sat s
    ), t AS (
        SELECT h.*,
               -- ÇİFT YÖNLÜ tolerans: erken gelen plandan önce sayılmaz,
               -- geç gelenin ilk 10 dk''sı affedilir.
               girisDk = CASE WHEN h.varsa = 0 THEN NULL ELSE
                    h.planBas0 + CASE
                        WHEN ABS(h.KartGirisDk - h.planBas0) <= @TOLERANS THEN 0
                        WHEN h.KartGirisDk - h.planBas0 > 0
                             THEN h.KartGirisDk - h.planBas0 - @TOLERANS
                        ELSE h.KartGirisDk - h.planBas0 + @TOLERANS END END
        FROM h
    ), c AS (
        SELECT t.*,
               -- GÜN DÖNÜMÜ: çıkış girişten küçükse ertesi güne aittir (+24 saat).
               -- Çıkışta tolerans YOK (ölçüldü 521/521).
               cikisDk = CASE WHEN t.varsa = 0 THEN NULL
                              WHEN t.KartCikisDk < t.girisDk THEN t.KartCikisDk + 1440
                              ELSE t.KartCikisDk END
        FROM t
    ), b AS (
        SELECT c.*, brutDk = CASE WHEN c.varsa = 0 THEN NULL
                                  ELSE c.cikisDk - c.girisDk END
        FROM c
    ), m AS (
        SELECT b.*,
               -- Mola tablosu PARAMETREDEN okunur (tip ''arac''). Hardcode edilirse
               -- Python ile SP sessizce ayrışır.
               molaDk = ISNULL((SELECT TOP 1 v.MolaDk FROM bkm.Vrd_Mola v
                                WHERE v.Tip = ''arac'' AND v.AltSinirDk <= b.brutDk
                                ORDER BY v.AltSinirDk DESC), 0)
        FROM b
    )
    INSERT INTO bkm.Vrd_KisiGun
        (KesimBas, KesimBit, SayimBas, Sube, SicilNo, PdksNo, Personel, Bolum,
         Gorev, Tarih, VardiyaTanim, PlanBaslamaDk, PlanBitisDk, PlanCalismaDk,
         KartGirisDk, KartCikisDk, GirisDk, CikisDk, BrutDk, MolaDk, CalismaDk,
         Durum, Izin, GunDonumu, SayimDisi, KayitSayisi, MazeretTipi, OlcumNotu)
    SELECT
        @Bas, @Bit, @SayimBas, m.SubeAd, ISNULL(m.SicilNo, ''''), m.PersNr,
        m.Personel, m.Bolum, m.Gorev, m.Tarih, m.VardiyaTanim,
        -- ⚠ İZİN GÜNÜNDE PLAN SAATİ RAPORLANMAZ. `VardiyaZaman` izin satırında
        --   Baslama/Bitis''i 00:00 tutuyor; ham yazılırsa "izinli ama 00:00-00:00
        --   vardiyası var" gibi okunur. Araç bu kolonları BOŞ bırakır, Python da
        --   öyle yapıyor — parite ölçümünde 781 satırda ayrıştı, SP''ye taşındı.
        CASE WHEN m.Izin = 1 THEN NULL ELSE m.PlanBasDk END,
        CASE WHEN m.Izin = 1 THEN NULL ELSE m.PlanBitDk END,
        CASE WHEN m.Izin = 1 THEN 0 ELSE ISNULL(m.PlanCalismaDk, 0) END,
        m.KartGirisDk, m.KartCikisDk, m.girisDk, m.cikisDk, m.brutDk,
        CASE WHEN m.varsa = 1 THEN m.molaDk END,
        CASE WHEN m.varsa = 1 THEN m.brutDk - m.molaDk ELSE 0 END,
        -- DURUM — HAM PDKS saatiyle karar verilir, toleranslıyla DEĞİL (595/595).
        durum = CASE
            WHEN m.Plansiz = 1                       THEN N''Vardiya Tanımsız Çalışma''
            WHEN m.Izin = 1 AND m.varsa = 1          THEN N''İzin Günü Çalışılmış''
            WHEN m.Izin = 1                          THEN N''İzinli''
            WHEN m.varsa = 0                         THEN N''Devamsız''
            WHEN (m.PlanBasDk IS NOT NULL AND m.KartGirisDk > m.PlanBasDk)
              OR (m.PlanBitDk IS NOT NULL AND m.KartCikisDk < m.PlanBitDk)
                                                     THEN N''Geç girilmiş ve/veya erken çıkılmış''
            ELSE N''Normal Çalışma'' END,
        m.Izin,
        CASE WHEN m.varsa = 1 AND m.KartCikisDk < m.girisDk THEN 1 ELSE 0 END,
        CASE WHEN m.Tarih < @SayimBas THEN 1 ELSE 0 END,
        m.KayitSayisi, m.Mazeret,
        -- ÖLÇÜM NOTU — düzeltme ve şüphe SESSİZ KALMAZ.
        NULLIF(CASE
            WHEN m.varsa = 1 AND m.KartCikisDk < m.girisDk AND m.brutDk > 16 * 60
                THEN N''GÜN DÖNÜMÜ — çıkış ertesi gün sayıldı, brüt ''
                     + CONVERT(nvarchar(4), m.brutDk / 60) + N'':''
                     + RIGHT(''0'' + CONVERT(nvarchar(4), m.brutDk % 60), 2)
                     + N'' ŞÜPHELİ (çıkış okutması unutulmuş olabilir)''
            WHEN m.varsa = 1 AND m.KartCikisDk < m.girisDk
                THEN N''GÜN DÖNÜMÜ — çıkış ertesi gün sayıldı''
            WHEN m.Plansiz = 0 AND m.Izin = 0 AND m.varsa = 0 AND m.PersNr IS NULL
                THEN N''PDKS kaydı yok — ölçülemiyor (devamsız DEĞİL)''
            WHEN m.Plansiz = 0 AND m.Izin = 0 AND m.varsa = 0 AND m.HamOkutma > 0
                THEN N''HAM OKUTMA VAR ('' + CONVERT(nvarchar(10), m.HamOkutma)
                     + N'' kez) — giriş/çıkış çifti oluşmamış''
            WHEN m.Plansiz = 0 AND m.Izin = 0 AND m.varsa = 0
                THEN N''Ham okutma da yok''
            ELSE N'''' END, N'''')
    FROM m;

    -- =====================================================================
    -- 8) YAYINLANAN RAPORUN ÖLÇÜSÜ — Eksik/Fazla Saat
    --
    -- ⚠ TABAN `Vrd_CalismaSaati` POLİTİKA TABLOSUDUR, vardiya planının SÜRESİ
    --   DEĞİL. İki taban farklı sonuç verir; ÖLÇÜLDÜ (17.09.2026, 6.113 kişi-gün):
    --   plan tabanı 4.313/4.596 saat · politika tabanı 6.118/5.024 saat.
    --   Yayınlanan Excel raporu politika tabanını kullanıyor; panel de onu
    --   kullanmak ZORUNDA, yoksa iki doğruluk kaynağı olur (emitter-ayrimi).
    --
    -- ⚠ ÇALIŞMA ÖLÇÜSÜ DE AYRI: Excel kendi mola tablosunu (tip ''excel'') kullanır
    --   ve net 11 saati aşınca 30 dk daha düşer. Aracın ölçüsü (`CalismaDk`)
    --   DEĞİŞMEDEN durur — ikisi kasıtlı iki ayrı ölçü.
    -- =====================================================================
    UPDATE k SET
        k.GerekenDk = CASE
            WHEN k.SayimDisi = 1 THEN 0
            WHEN k.VardiyaTanim IN (N''HFT.İZİN'', N''RAPOR'', N''YILLIK İZİN'',
                                    N''ÜCRETSİZ İZİN'', N''ÖZEL DURUM'') THEN 0
            -- ⚠ POLİTİKADA KARŞILIĞI YOKSA ŞUBE VARSAYILANINA DÜŞ — ama SESSİZCE
            --   DEĞİL: aşağıda Ölçüm Notu''na damga düşülür. NULL bırakılsaydı o
            --   satır Eksik/Fazla''ya hiç girmezdi ve rapor sessizce eksik olurdu.
            --   ÖLÇÜLDÜ (17.09.2026): tek satır (plansız kart basan, bölümsüz)
            --   18,8 dk fazla mesaiyi düşürüyordu.
            ELSE ISNULL(cs.CalismaDk, s.CalismaDk) END,
        k.Net2Dk = CASE WHEN k.BrutDk IS NULL THEN NULL ELSE
            k.BrutDk - x.molaExcel
            - CASE WHEN k.BrutDk - x.molaExcel > 11 * 60 THEN 30 ELSE 0 END END
    FROM        bkm.Vrd_KisiGun k
    INNER JOIN  bkm.Vrd_Sube s ON s.Sube = k.Sube
    LEFT  JOIN  bkm.Vrd_CalismaSaati cs
             ON cs.Grup = s.Grup AND cs.Sube = k.Sube
            AND cs.BolumAnahtar = ISNULL(k.Bolum, N'''')
    CROSS APPLY (SELECT molaExcel = ISNULL((SELECT TOP 1 v.MolaDk FROM bkm.Vrd_Mola v
                                            WHERE v.Tip = ''excel'' AND v.AltSinirDk < k.BrutDk
                                            ORDER BY v.AltSinirDk DESC), 0)) x
    WHERE k.KesimBas = @Bas AND k.KesimBit = @Bit;

    -- HAFTALIK İZİN PRİMİ — haftada 7 gün çalışıp hafta tatili kullanmayana,
    -- haftanın SON GÜNÜNE (Pazar) yazılır. Sayfadaki ilk satıra yazılırsa ay
    -- dönümünde primi önceki aya kaçırır (ÖLÇÜLDÜ: 331 kişi-hafta).
    ;WITH g AS (
        SELECT SicilNo, hafta = DATEPART(iso_week, Tarih),
               calisilan = SUM(CASE WHEN Durum IN (N''İzinli'', N''Devamsız'') THEN 0 ELSE 1 END)
        FROM bkm.Vrd_KisiGun
        WHERE KesimBas = @Bas AND KesimBit = @Bit
        GROUP BY SicilNo, DATEPART(iso_week, Tarih)
    )
    -- ⚠ PRİM TUTARI POLİTİKA SAATİDİR, `GerekenDk` DEĞİL. `GerekenDk` izin
    --   etiketli günde 0''a çekilir; haftanın 7 günü çalışan kişinin Pazar''ı
    --   çoğu zaman "İzin Günü Çalışılmış"tır (vardiya tanımı HFT.İZİN) ve prim
    --   sessizce SIFIRLANIR. ÖLÇÜLDÜ: 972 saat çıktı, doğrusu 1.380 saat.
    UPDATE k SET k.HaftalikPrimDk = cs.CalismaDk
    FROM bkm.Vrd_KisiGun k
    INNER JOIN g ON g.SicilNo = k.SicilNo AND g.hafta = DATEPART(iso_week, k.Tarih)
    INNER JOIN bkm.Vrd_Sube s ON s.Sube = k.Sube
    LEFT  JOIN bkm.Vrd_CalismaSaati cs
            ON cs.Grup = s.Grup AND cs.Sube = k.Sube
           AND cs.BolumAnahtar = ISNULL(k.Bolum, N'''')
    WHERE k.KesimBas = @Bas AND k.KesimBit = @Bit
      AND k.SayimDisi = 0
      -- ⚠ PAZAR TESPİTİ `DATEPART(weekday)` İLE YAPILMAZ: sonucu `@@DATEFIRST`''e
      --   bağlıdır ve oturum diline göre değişir. ÖLÇÜLDÜ: 36. haftanın primi
      --   (378 saat) sessizce düştü, 37. haftanınki geldi — hata vermeden.
      --   1900-01-01 Pazartesi''dir; gün farkının 7''ye kalanı 6 ise Pazar.
      AND DATEDIFF(day, ''19000101'', k.Tarih) % 7 = 6
      AND g.calisilan >= 7;

    UPDATE bkm.Vrd_KisiGun SET
        HaftalikPrimDk = ISNULL(HaftalikPrimDk, 0),
        EksikDk = CASE WHEN SayimDisi = 1 OR Net2Dk IS NULL OR GerekenDk IS NULL THEN 0
                       WHEN Net2Dk < GerekenDk THEN GerekenDk - Net2Dk ELSE 0 END,
        FazlaDk = CASE WHEN SayimDisi = 1 THEN 0 ELSE
                       CASE WHEN Net2Dk IS NOT NULL AND GerekenDk IS NOT NULL
                                 AND Net2Dk > GerekenDk THEN Net2Dk - GerekenDk ELSE 0 END
                       + ISNULL(HaftalikPrimDk, 0) END
    WHERE KesimBas = @Bas AND KesimBit = @Bit;

    -- =====================================================================
    -- 9) FAZLA MESAİNİN KAYNAĞI — "ne kadarı fazla çalışma, ne kadarı izin
    --    iptali" (GMY isteği 17.09.2026). Tek rakam yönetilemez: üç kalem
    --    HUKUKEN DE AYRIDIR (m.41 fazla çalışma · m.46 hafta tatili çalışması
    --    1 yevmiye + %50 · izin gününde çalıştırma), ödeme biçimleri farklı.
    --
    -- ⚠ İZİN GÜNÜNDE `GerekenDk` 0''dır (izin etiketi) → o satırda fazlanın
    --   TAMAMI izin iptalidir. Kalem sırası bu yüzden önemli: önce izin iptali
    --   ve plansız ayrılır, "fazla çalışma" ARTAKALANDIR — toplam hep tutar.
    -- =====================================================================
    UPDATE bkm.Vrd_KisiGun SET
        FazlaIzinIptalDk = CASE WHEN SayimDisi = 1 THEN 0
                                WHEN Izin = 1 AND Net2Dk > 0 THEN Net2Dk ELSE 0 END,
        FazlaPlansizDk   = CASE WHEN SayimDisi = 1 THEN 0
                                WHEN Durum = N''Vardiya Tanımsız Çalışma''
                                     AND Net2Dk > ISNULL(GerekenDk, 0)
                                THEN Net2Dk - ISNULL(GerekenDk, 0) ELSE 0 END
    WHERE KesimBas = @Bas AND KesimBit = @Bit;

    UPDATE bkm.Vrd_KisiGun SET
        FazlaCalismaDk = ISNULL(FazlaDk, 0) - ISNULL(HaftalikPrimDk, 0)
                       - ISNULL(FazlaIzinIptalDk, 0) - ISNULL(FazlaPlansizDk, 0)
    WHERE KesimBas = @Bas AND KesimBit = @Bit;

    -- KONTROL EDİLEBİLİRLİK — GMY sorusu 17.09.2026: *"patron sezonda izinleri
    -- iptal ediyor mecburen, dağılan mağaza gün bitiminde toplanmak için
    -- çalışmak gerekiyor — ne kadarı mağazanın elinde yapılmış mesai?"*
    --
    -- Plan üstü çalışma İKİ UÇTAN doğar ve ikisi AYRI yönetim sorusudur:
    --   · çıkış plan bitişinden SONRA  → kapanış/toplanma, mağaza operasyonu
    --   · giriş plan başlangıcından ÖNCE → erken açılış/hazırlık
    -- Ölçülüp yazılır; yorum panelde değil `ik-danisman`''da.
    UPDATE bkm.Vrd_KisiGun SET
        CikisSonrasiDk = CASE WHEN SayimDisi = 0 AND CikisDk > PlanBitisDk
                              THEN CikisDk - PlanBitisDk ELSE 0 END,
        GirisOncesiDk  = CASE WHEN SayimDisi = 0 AND GirisDk < PlanBaslamaDk
                              THEN PlanBaslamaDk - GirisDk ELSE 0 END
    WHERE KesimBas = @Bas AND KesimBit = @Bit;

    -- İzin satırında Net2Dk yok ama GerekenDk 0 → eksik 0. Çalışmayan (Devamsız)
    -- satırda Net2Dk NULL ve GerekenDk dolu → EKSİK SAYILMALI (plan vardı, gelmedi).
    UPDATE bkm.Vrd_KisiGun SET EksikDk = GerekenDk
    WHERE KesimBas = @Bas AND KesimBit = @Bit
      AND SayimDisi = 0 AND Net2Dk IS NULL AND ISNULL(GerekenDk, 0) > 0;

    -- Politika boşluğu BEYAN EDİLİR (fallback sessiz kalmaz — error-handling.md).
    UPDATE k SET k.OlcumNotu =
        CASE WHEN k.OlcumNotu IS NULL THEN N'''' ELSE k.OlcumNotu + N'' · '' END
        + N''ÇALIŞMA SAATİ POLİTİKASINDA KARŞILIĞI YOK — şube varsayılanı kullanıldı''
    FROM        bkm.Vrd_KisiGun k
    INNER JOIN  bkm.Vrd_Sube s ON s.Sube = k.Sube
    LEFT  JOIN  bkm.Vrd_CalismaSaati cs
             ON cs.Grup = s.Grup AND cs.Sube = k.Sube
            AND cs.BolumAnahtar = ISNULL(k.Bolum, N'''')
    WHERE k.KesimBas = @Bas AND k.KesimBit = @Bit
      AND cs.CalismaDk IS NULL AND k.SayimDisi = 0;

    IF @Konus = 1
    BEGIN
        SELECT Kesim = CONVERT(char(10), @Bas, 104) + N'' – '' + CONVERT(char(10), @Bit, 104),
               SayimBas = CONVERT(char(10), @SayimBas, 104),
               KisiGun = COUNT(*), Sube = COUNT(DISTINCT Sube),
               Plansiz = SUM(CASE WHEN Durum = N''Vardiya Tanımsız Çalışma'' THEN 1 ELSE 0 END),
               GunDonumu = SUM(CONVERT(int, GunDonumu)),
               SayimDisi = SUM(CONVERT(int, SayimDisi))
        FROM bkm.Vrd_KisiGun WHERE KesimBas = @Bas AND KesimBit = @Bit;
    END
END');

COMMIT;
