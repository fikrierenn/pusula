/*  VARDİYA PLAN DÜZELTME — plan 49 / V-05 · 19.09.2026
    Hedef: BkmPanel (DEV). Prod'a HİÇBİR ŞEY yazılmaz (erp-write-policy.md).

    NE İÇİN: kişi-gün hesabı `bkm.sp_Vrd_KisiGunDoldur` tarafından yazılıyor ve
    vardiya planı PDKS'den geliyor. Plan eksikse SP şube varsayılanına düşüyor
    (ölçüldü 19.09: 172 gün `Vardiya Tanımsız Çalışma`). Bu tablo o eksiği
    İNSAN KARARIYLA düzeltmenin yeri.

    ⚠ NEDEN AYRI TABLO (plan 49 §3): `Vrd_KisiGun` yalnız SP tarafından yazılır.
      Uygulama oraya yazsaydı SP'nin bir sonraki koşumu düzeltmeyi SESSİZCE ezerdi
      ve "ölçülen" ile "düzeltilen" ayrımı kaybolurdu. Burada ikisi ayrı durur,
      okuma anında birleşir (`Vrd_Onay` deseninin ikizi).

    ⚠ İZİN İŞARETİ PDKS'Yİ EZMEZ (GMY kararı S3): `Izin` kolonu kaynakta DURUR,
      buradaki `IzinliMi` onun YANINA yazılır. Çeliştiklerinde ikisi de okunabilir —
      "kaynak ne diyordu" sorusu denetimde cevaplanabilir kalmalı.

    Kim yazar: yalnız vardiya uygulaması (`vardiya.onayla` yetkisi + şube kapsamı).
*/

IF SCHEMA_ID('bkm') IS NULL EXEC('CREATE SCHEMA bkm');
GO

IF OBJECT_ID('bkm.Vrd_PlanDuzeltme') IS NULL
BEGIN
    CREATE TABLE bkm.Vrd_PlanDuzeltme
    (
        SicilNo         nvarchar(20)   NOT NULL,
        Tarih           date           NOT NULL,

        -- Düzeltilmiş plan. Hepsi NULL olabilir: kullanıcı yalnız izin işareti
        -- koyuyor olabilir. "Hiçbiri dolu değil ve izin de yok" hâli anlamsızdır
        -- ve uygulama o kaydı SİLER (onay yolundaki desenin aynısı).
        VardiyaTanim    nvarchar(60)   NULL,
        PlanBaslamaDk   int            NULL,
        PlanBitisDk     int            NULL,
        PlanCalismaDk   int            NULL,

        -- İzin günü işareti — PDKS'nin `Izin` alanını EZMEZ, yanında durur.
        IzinliMi        bit            NULL,

        Aciklama        nvarchar(400)  NULL,
        Kaydeden        nvarchar(128)  NOT NULL,
        KayitUtc        datetime2(0)   NOT NULL CONSTRAINT DF_Vrd_PlanDuzeltme_KayitUtc DEFAULT SYSUTCDATETIME(),

        CONSTRAINT PK_Vrd_PlanDuzeltme PRIMARY KEY CLUSTERED (SicilNo, Tarih),

        -- Gece vardiyasında çıkış ertesi güne sarkar (>1440) — 2880 dk (48 saat)
        -- üst sınır bilinçli: 26:00 meşru, 50:00 değil.
        CONSTRAINT CK_Vrd_PlanDuzeltme_Baslama CHECK (PlanBaslamaDk  IS NULL OR PlanBaslamaDk  BETWEEN 0 AND 2880),
        CONSTRAINT CK_Vrd_PlanDuzeltme_Bitis   CHECK (PlanBitisDk    IS NULL OR PlanBitisDk    BETWEEN 0 AND 2880),
        CONSTRAINT CK_Vrd_PlanDuzeltme_Sure    CHECK (PlanCalismaDk  IS NULL OR PlanCalismaDk  BETWEEN 0 AND 1440),

        -- Başlama/bitiş İKİSİ BİRDEN ya doludur ya boştur: tek başına bir başlama
        -- saati bir vardiya tanımlamaz ve okuma tarafında sessizce yarım plan üretirdi.
        CONSTRAINT CK_Vrd_PlanDuzeltme_AralikButun
            CHECK ((PlanBaslamaDk IS NULL AND PlanBitisDk IS NULL)
                OR (PlanBaslamaDk IS NOT NULL AND PlanBitisDk IS NOT NULL)),

        -- Bitiş başlamadan sonra olmalı. Eşit olması da yasak: sıfır süreli vardiya
        -- bir tanım değil, bir hatadır.
        CONSTRAINT CK_Vrd_PlanDuzeltme_AralikYon
            CHECK (PlanBaslamaDk IS NULL OR PlanBitisDk > PlanBaslamaDk)
    );

    PRINT 'bkm.Vrd_PlanDuzeltme kuruldu.';
END
ELSE
    PRINT 'bkm.Vrd_PlanDuzeltme zaten var — dokunulmadı.';
GO

/*  Kişi-gün listesi kesim bazında okunuyor ve düzeltmeler LEFT JOIN ile
    birleşiyor. Tarih öncelikli indeks, kesim penceresi taramasını ucuzlatır.
    ⚠ ÖLÇÜLMEDİ: tablo bugün BOŞ, yani bu indeks bir TAHMİNDİR. Satır sayısı
      anlamlı olunca plan yeniden ölçülmeli (bugün 0 satırda ölçüm yapılamaz —
      "hızlı" demek anlamsız olurdu).  */
IF NOT EXISTS (SELECT 1 FROM sys.indexes
               WHERE object_id = OBJECT_ID('bkm.Vrd_PlanDuzeltme')
                 AND name = 'IX_Vrd_PlanDuzeltme_Tarih')
BEGIN
    CREATE INDEX IX_Vrd_PlanDuzeltme_Tarih
        ON bkm.Vrd_PlanDuzeltme (Tarih) INCLUDE (SicilNo, PlanCalismaDk, IzinliMi);
    PRINT 'IX_Vrd_PlanDuzeltme_Tarih kuruldu.';
END
GO

-- Kurulum doğrulaması: tablo + kısıt sayısı. Sessiz kurulum kabul edilmez.
SELECT Tablo      = 'bkm.Vrd_PlanDuzeltme',
       Var        = CASE WHEN OBJECT_ID('bkm.Vrd_PlanDuzeltme') IS NULL THEN 0 ELSE 1 END,
       CheckSayisi= (SELECT COUNT(*) FROM sys.check_constraints
                     WHERE parent_object_id = OBJECT_ID('bkm.Vrd_PlanDuzeltme')),
       Satir      = (SELECT COUNT(*) FROM bkm.Vrd_PlanDuzeltme);
GO
