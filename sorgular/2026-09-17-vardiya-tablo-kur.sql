/* ============================================================================
   VARDİYA EKSİK/FAZLA TAKİP — TABLO KURULUMU (plan 47)
   Hedef : DEV → BkmPanel @ BT-FIKRI\SQLEXPRESS, şema `bkm`
           PROD'a (DerinSISBkm) HİÇBİR ŞEY YAZILMAZ — terfi ayrı onay ister.
   Not   : Şema ve nesne adları dev/prod'da BİREBİR AYNI; terfi bağlantı dizesi
           değişikliğidir, yeniden yazım değil.
   İdempotent: tekrar koşturulabilir, veri KAYBETMEZ (yalnız eksik nesneyi yaratır).

   ⚠ SÜRELER DAKİKA (int) TUTULUR, `time` DEĞİL.
     Gerekçe ölçüldü: gece mesaisinde çıkış ertesi güne sarkıyor (24:30 gibi) ve
     `time` tipi 24 saati aşamaz; Excel tarafında bu yüzden negatif süreler ve
     #DEĞER! doğmuştu. Dakika olarak tutulunca gün dönümü doğal şekilde ifade
     edilir, biçimlendirme okuyan tarafın işidir.
   ============================================================================ */

IF SCHEMA_ID('bkm') IS NULL EXEC('CREATE SCHEMA bkm');
GO

/* ---------------------------------------------------------------- HESAP ----
   Yalnız `bkm.sp_Vrd_KisiGunDoldur` yazar. Elle INSERT/UPDATE yapılmaz.
   Kesim = hangi koşumun ürünü olduğu; aynı kesim yeniden koşarsa silinip yazılır. */
IF OBJECT_ID('bkm.Vrd_KisiGun') IS NULL
CREATE TABLE bkm.Vrd_KisiGun (
    Id              bigint IDENTITY(1,1) NOT NULL,
    KesimBas        date          NOT NULL,
    KesimBit        date          NOT NULL,
    SayimBas        date          NOT NULL,   -- bundan önceki gün toplama katılmaz
    Sube            nvarchar(50)  NOT NULL,
    SicilNo         varchar(11)   NOT NULL,   -- TC; PDKS'te TC'si olmayanda ''
    PdksNo          int           NULL,
    Personel        nvarchar(120) NULL,
    Bolum           nvarchar(80)  NULL,
    Gorev           nvarchar(120) NULL,
    Tarih           date          NOT NULL,
    VardiyaTanim    nvarchar(60)  NULL,
    PlanBaslamaDk   int           NULL,
    PlanBitisDk     int           NULL,
    PlanCalismaDk   int           NULL,
    KartGirisDk     int           NULL,       -- ham PDKS
    KartCikisDk     int           NULL,
    GirisDk         int           NULL,       -- toleranslı
    CikisDk         int           NULL,       -- gün dönümünde > 1440 olabilir
    BrutDk          int           NULL,
    MolaDk          int           NULL,
    CalismaDk       int           NULL,
    Durum           nvarchar(60)  NOT NULL,
    Izin            bit           NOT NULL CONSTRAINT DF_VrdKisiGun_Izin DEFAULT (0),
    GunDonumu       bit           NOT NULL CONSTRAINT DF_VrdKisiGun_GunDon DEFAULT (0),
    SayimDisi       bit           NOT NULL CONSTRAINT DF_VrdKisiGun_SayimDisi DEFAULT (0),
    KayitSayisi     int           NULL,
    MazeretTipi     nvarchar(40)  NULL,
    OlcumNotu       nvarchar(400) NULL,
    -- Dev/prod karışmasın diye: satırı hangi sunucu yazdı.
    Kaynak          nvarchar(80)  NOT NULL CONSTRAINT DF_VrdKisiGun_Kaynak
                                  DEFAULT (CAST(SERVERPROPERTY('ServerName') AS nvarchar(80))),
    YazilmaUtc      datetime2(0)  NOT NULL CONSTRAINT DF_VrdKisiGun_Utc DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT PK_Vrd_KisiGun PRIMARY KEY CLUSTERED (Id)
);
GO
/* Kesim + kişi-gün erişimi. SicilNo boş olabildiği için UNIQUE DEĞİL:
   PDKS'te TC'si olmayan kişi var (ölçüldü, 1 kişi) ve tekillik garanti edilemez. */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Vrd_KisiGun_Kesim')
CREATE INDEX IX_Vrd_KisiGun_Kesim
    ON bkm.Vrd_KisiGun (KesimBas, KesimBit, Sube, Tarih)
    INCLUDE (SicilNo, Personel, Durum, CalismaDk, PlanCalismaDk);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Vrd_KisiGun_Kisi')
CREATE INDEX IX_Vrd_KisiGun_Kisi
    ON bkm.Vrd_KisiGun (SicilNo, Tarih) INCLUDE (KesimBas, KesimBit);
GO

/* MEVZUAT KAPISI (UyumAsync) KAPSAYAN İNDEKSİ.
   Kapı bir kesimin TAMAMINI tarar ve GirisDk/CikisDk/Izin/OlcumNotu ister —
   bunlar _Kesim indeksinde YOK, yani her satır için anahtar arama (key lookup)
   doğuyordu. Dar bir (KesimBas,KesimBit) indeksi bunu ÇÖZMEZ, KÖTÜLEŞTİRİR.

   ÖLÇÜLDÜ (18.09.2026) — 24 kesimlik ölçek taklidi, 146.712 satır, medyan 8 koşum:
     indekssiz (yığın tarama) ....  89,6 ms
     dar (KesimBas,KesimBit) ..... 111,9 ms   ← anahtar arama yüzünden DAHA YAVAŞ
     kapsayan (bu indeks) ........  22,9 ms   ← 3,9 kat
   Bugünkü tek kesimde (6.113 satır) fark ölçüm gürültüsü içinde (46,3 → 44,0 ms);
   indeks kesim sayısı arttıkça kazandırır, bugün zarar vermiyor. Boyut 376 KB. */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='IX_Vrd_KisiGun_KesimUyum')
CREATE INDEX IX_Vrd_KisiGun_KesimUyum
    ON bkm.Vrd_KisiGun (KesimBas, KesimBit)
    INCLUDE (SicilNo, Tarih, CalismaDk, GirisDk, CikisDk, Izin, OlcumNotu);
GO

/* --------------------------------------------------------- ELLE GİRİLEN ----
   Hiçbir sorgudan çıkmaz. Bugün Excel hücresinde yaşıyor ve dosya yenilenince
   kayboluyor — tablonun gerçek gerekçesi budur.
   Kesime BAĞLI DEĞİL: kişi-gün kimliğiyle tutulur, her koşumda yeniden bindirilir. */
IF OBJECT_ID('bkm.Vrd_Onay') IS NULL
CREATE TABLE bkm.Vrd_Onay (
    SicilNo         varchar(11)   NOT NULL,
    Tarih           date          NOT NULL,
    OnayliGirisDk   int           NULL,
    OnayliCikisDk   int           NULL,
    EkMesaiDk       int           NULL,   -- evden çalışma / ayrıca onaylanmış ek mesai
    Aciklama        nvarchar(300) NULL,
    Kaydeden        nvarchar(80)  NULL,
    KayitUtc        datetime2(0)  NOT NULL CONSTRAINT DF_VrdOnay_Utc DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT PK_Vrd_Onay PRIMARY KEY CLUSTERED (SicilNo, Tarih),
    /* ⚠ GÜN DÖNÜMÜ ARTIK OTOMATİK — `EkMesaiDk`'ya gece mesaisi telafisi YAZILMAZ,
       yoksa mesai İKİ KEZ sayılır. ÖLÇÜLDÜ (17.09.2026): eski Excel'de elle
       doldurulan 11 satırın 9'u tam olarak bu telafiydi. */
    CONSTRAINT CK_Vrd_Onay_EkMesai CHECK (EkMesaiDk IS NULL OR EkMesaiDk BETWEEN 0 AND 1440)
);
GO

IF OBJECT_ID('bkm.Vrd_MagazaGeriDonus') IS NULL
CREATE TABLE bkm.Vrd_MagazaGeriDonus (
    Id              int IDENTITY(1,1) NOT NULL,
    Sube            nvarchar(50)  NOT NULL,
    Personel        nvarchar(120) NOT NULL,
    Grup            nvarchar(80)  NULL,
    Tarih           date          NOT NULL,
    YoneticiGirisDk int           NULL,
    YoneticiCikisDk int           NULL,
    Aciklama        nvarchar(300) NULL,
    Kaydeden        nvarchar(80)  NULL,
    KayitUtc        datetime2(0)  NOT NULL CONSTRAINT DF_VrdGeri_Utc DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT PK_Vrd_MagazaGeriDonus PRIMARY KEY CLUSTERED (Id)
);
GO

/* ------------------------------------------------------------ DONDURULAN ---
   GEREKÇE ÖLÇÜLDÜ (17.09.2026): PDKS geçmişe dönük düzeltiliyor. 15.09'da çekilmiş
   dosyayla canlı PDKS arasında 5 kişi-gün farklı çıktı (SERHAT KELEŞ 02.09 →
   dosyada 19:24, canlıda 17:30). Yani ay kapanışında ödenen rakam sonradan yeniden
   SORGULANARAK BULUNAMAZ. Bu tablo bir kez yazılır, sonra dokunulmaz. */
IF OBJECT_ID('bkm.Vrd_Devir') IS NULL
CREATE TABLE bkm.Vrd_Devir (
    Donem           char(7)       NOT NULL,   -- 'YYYY-MM'
    SicilNo         varchar(11)   NOT NULL,
    Sube            nvarchar(50)  NULL,
    Personel        nvarchar(120) NULL,
    Bolum           nvarchar(80)  NULL,
    Gorev           nvarchar(120) NULL,
    EksikDk         int           NOT NULL CONSTRAINT DF_VrdDevir_Eksik DEFAULT (0),
    FazlaDk         int           NOT NULL CONSTRAINT DF_VrdDevir_Fazla DEFAULT (0),
    DondurmaUtc     datetime2(0)  NOT NULL CONSTRAINT DF_VrdDevir_Utc DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT PK_Vrd_Devir PRIMARY KEY CLUSTERED (Donem, SicilNo),
    CONSTRAINT CK_Vrd_Devir_Donem CHECK (Donem LIKE '[12][0-9][0-9][0-9]-[01][0-9]')
);
GO

/* ------------------------------------------------------------ PARAMETRE ----
   TEK YÖN: `vardiya/vardiya_parametreleri.json` → tablo (`--parametre-yukle`).
   Tabloya ELLE yazılmaz; yükleyici truncate+reload yapar. JSON düzenleme yüzeyi
   olarak kalır çünkü politika değişikliği git diff'inde görünmelidir. */
IF OBJECT_ID('bkm.Vrd_Sube') IS NULL
CREATE TABLE bkm.Vrd_Sube (
    Sube            nvarchar(50)  NOT NULL,
    Grup            nvarchar(80)  NOT NULL,
    CalismaDk       int           NULL,   -- NULL ise vardiya planından ÖLÇÜLÜR (mod)
    YuklemeUtc      datetime2(0)  NOT NULL CONSTRAINT DF_VrdSube_Utc DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT PK_Vrd_Sube PRIMARY KEY CLUSTERED (Sube)
);
GO

IF OBJECT_ID('bkm.Vrd_CalismaSaati') IS NULL
CREATE TABLE bkm.Vrd_CalismaSaati (
    Grup            nvarchar(80)  NOT NULL,
    Sube            nvarchar(50)  NOT NULL,
    Bolum           nvarchar(80)  NULL,
    -- Bölüm NULL olabiliyor (plansız kart basan kişide bölüm bilinmiyor); NULL bir
    -- anahtarın parçası olamaz, bu yüzden hesaplanmış ve kalıcı bir kova kolonu.
    BolumAnahtar AS ISNULL(Bolum, N'') PERSISTED,
    CalismaDk       int           NOT NULL,
    Not_            nvarchar(200) NULL,   -- "OTOMATİK EKLENDİ — İK onaylamalı"
    YuklemeUtc      datetime2(0)  NOT NULL CONSTRAINT DF_VrdCalSaat_Utc DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT PK_Vrd_CalismaSaati PRIMARY KEY CLUSTERED (Grup, Sube, BolumAnahtar)
);
GO

IF OBJECT_ID('bkm.Vrd_Mola') IS NULL
CREATE TABLE bkm.Vrd_Mola (
    Tip             varchar(10)   NOT NULL,   -- 'net' | 'brut' | 'arac' | 'excel'
    AltSinirDk      int           NOT NULL,
    MolaDk          int           NOT NULL,
    Ustu            bit           NOT NULL CONSTRAINT DF_VrdMola_Ustu DEFAULT (0),
    YuklemeUtc      datetime2(0)  NOT NULL CONSTRAINT DF_VrdMola_Utc DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT PK_Vrd_Mola PRIMARY KEY CLUSTERED (Tip, AltSinirDk, MolaDk),
    CONSTRAINT CK_Vrd_Mola_Tip CHECK (Tip IN ('net','brut','arac','excel'))
);
GO

/* ⚠ `bkm.Vrd_KartBasmayan` KURULMADI (GMY itirazı 17.09.2026: "gereksiz gibi geldi").
   Haklı: "Kart Basmayan Gruplar" hiçbir HESAPTA kullanılmıyor — Excel'de yalnız
   `AL` kolonundaki "Dahil/Hariç" etiketi ve pivot süzgeci. SP'nin ona ihtiyacı yok,
   JSON'da kalması yeter. Parametre tablosu ancak SP onu OKUYORSA gerekçelidir.
   Kalan üçü gerekçeli: Vrd_CalismaSaati (olması gereken saat) · Vrd_Mola (mola
   eşiği) · Vrd_Sube (grup → Çalışma Saatleri anahtarı). */

/* ---------------------------------------------------------------- KONTROL -- */
SELECT s.name AS Sema, t.name AS Tablo,
       (SELECT COUNT(*) FROM sys.columns c WHERE c.object_id = t.object_id) AS Kolon
FROM   sys.tables t
JOIN   sys.schemas s ON s.schema_id = t.schema_id
WHERE  s.name = 'bkm' AND t.name LIKE 'Vrd[_]%'
ORDER BY t.name;
