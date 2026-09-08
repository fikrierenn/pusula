/*
  bkm.SatisAnaliziTaban — Satış Analizi paneli ÖN-AGREGA tablosu (plan-42)
  Kurulum: 09.09.2026 · Kullanıcı onayı: 08/09.09.2026 ("ERP'de app-owned tablo" + "temp tablo değil")

  NEDEN VAR — ÖLÇÜLDÜ (08.09.2026, sorgular/2026-09-08-satis-analizi-excel-denetim.sql §13):
  Panel tabanı CTE ile her istekte yeniden hesaplanıyordu. 274.933 ürün için:
    · sayfa çevirme      5,31-5,44 s   → materyalize+index ile    15-27 ms   (~200×)
    · KPI + kırılım      3,15-3,76 s   →                          54 ms      (~60×)
    · filtreli sayfa     ~5 s          →                          84 ms
    · arama (LIKE)       5,8 s riski   →                          16 ms
    · aşırı stok kohortu ~5 s          →                          89 ms
  Taban kurulumu 6,86 s + index 2,85 s (TEK SEFER, kesim başına).
  ⚠ `COUNT(*) OVER ()` sayfa başına 1,2 s ekliyordu → KULLANILMAZ, toplam bir kez sayılır (34 ms).

  NEDEN #temp DEĞİL: temp tablo bağlantı kapsamlıdır; Dapper her çağrıda yeni bağlantı açar →
  sayfa çevirmede kaybolur. (Ayrıca ölçüldü: parametreli batch ODBC'de sp_executesql ile koşuyor,
  #temp o kapsamda da kalmıyor.)

  ERP-WRITE-POLICY: bu tablo app-owned `bkm.*` namespace'inde ve izin listesine EKLENDİ
  (.claude/rules/erp-write-policy.md). DerinSIS native tablolarına yazma MUTLAK YASAK olarak durur.

  KESİM POLİTİKASI: (Kesim, SezonYil) anahtarlı — son 3 kesim saklanır, eskisi silinir
  (kullanıcı kararı). Böylece tarih değiştirince bekleme olmaz.

  İdempotent: tablo/index varsa dokunmaz.
*/

USE DerinSISBkm;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'bkm')
    EXEC('CREATE SCHEMA bkm');
GO

IF OBJECT_ID('bkm.SatisAnaliziTaban', 'U') IS NULL
BEGIN
    CREATE TABLE bkm.SatisAnaliziTaban
    (
        Kesim        date          NOT NULL,   -- son KAPALI gün (satış penceresi = Kesim-364 .. Kesim)
        SezonYil     smallint      NOT NULL,   -- karşılaştırılan sezon (Ağu-Eki)
        stkID        int           NOT NULL,

        -- Ürün master (bkm.UrunBilgi): Kategori1 = KatAna · Yayinevi = mrkAd (FirmaAd DEĞİL)
        Kategori3    nvarchar(50)  NOT NULL,
        Kategori1    nvarchar(50)  NOT NULL,
        BarkodAna    varchar(15)   NULL,
        stkAd        nvarchar(120) NOT NULL,
        Yayinevi     nvarchar(300) NULL,
        Yazar        nvarchar(50)  NULL,
        SatisFiyat   decimal(15,4) NOT NULL,

        -- Stok: mağaza rafı irsHrk kümülatif as-of · Merkez = WMS raf+giriş · ODAK = TEDARİKÇİ stoğu
        StokFsm      int NOT NULL,
        StokOzl      int NOT NULL,
        StokIst      int NOT NULL,
        MerkezStok   int NOT NULL,
        OdakStok     int NOT NULL,             -- ToplamStok'a DAHİL DEĞİL (grup şirketi tedarikçi)

        -- Satış: 365 gün, ehTip IN (1,3,4,5,100,101), iade netlenmiş, 3 mağaza
        SatisFsm     int NOT NULL,
        SatisOzl     int NOT NULL,
        SatisIst     int NOT NULL,

        -- Sezon ayları (geçmiş-sabit)
        Ay1          int NOT NULL,
        Ay2          int NOT NULL,
        Ay3          int NOT NULL,

        -- Türetilmiş (sorguda tekrar hesaplanmasın diye SAKLANIR)
        MagazaStok   int NOT NULL,
        ToplamStok   int NOT NULL,
        SatisToplam  int NOT NULL,
        SezonToplam  int NOT NULL,
        Tutar        decimal(18,2) NOT NULL,   -- ToplamStok × SatisFiyat (SATIŞ fiyatı, maliyet DEĞİL)

        -- Karar kolonları
        IlkGiris     datetime NULL,            -- ürünün MAĞAZAYA ilk girişi
        LeadTime     int NULL,                 -- BKMDATA.OdakUrunDurum.leadTime (ODAK temin, gün)
        OdakDurum    int NULL,                 -- OdakUrunDurum.saleStatus

        Uretim       datetime NOT NULL CONSTRAINT DF_SatisAnaliziTaban_Uretim DEFAULT (GETDATE()),

        CONSTRAINT PK_SatisAnaliziTaban PRIMARY KEY CLUSTERED (Kesim, SezonYil, stkID)
    );
END
GO

-- Sıralama/kırılım/filtre index'leri. Kesim+SezonYil her sorgunun ilk süzgeci → hepsinde önde.
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_SatisAnaliziTaban_Tutar'
               AND object_id = OBJECT_ID('bkm.SatisAnaliziTaban'))
    CREATE INDEX IX_SatisAnaliziTaban_Tutar
        ON bkm.SatisAnaliziTaban (Kesim, SezonYil, Tutar DESC, stkID);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_SatisAnaliziTaban_Kategori'
               AND object_id = OBJECT_ID('bkm.SatisAnaliziTaban'))
    CREATE INDEX IX_SatisAnaliziTaban_Kategori
        ON bkm.SatisAnaliziTaban (Kesim, SezonYil, Kategori3, Tutar DESC);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_SatisAnaliziTaban_Kohort'
               AND object_id = OBJECT_ID('bkm.SatisAnaliziTaban'))
    CREATE INDEX IX_SatisAnaliziTaban_Kohort
        ON bkm.SatisAnaliziTaban (Kesim, SezonYil, SezonToplam, ToplamStok)
        INCLUDE (OdakStok, Tutar);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_SatisAnaliziTaban_Satis'
               AND object_id = OBJECT_ID('bkm.SatisAnaliziTaban'))
    CREATE INDEX IX_SatisAnaliziTaban_Satis
        ON bkm.SatisAnaliziTaban (Kesim, SezonYil, SatisToplam, ToplamStok)
        INCLUDE (Tutar);
GO

-- Kurulum teyidi
SELECT t.name AS tablo,
       (SELECT COUNT(*) FROM sys.columns WHERE object_id = t.object_id) AS kolon,
       (SELECT COUNT(*) FROM sys.indexes WHERE object_id = t.object_id AND type > 0) AS indeks
FROM sys.tables t
JOIN sys.schemas s ON s.schema_id = t.schema_id
WHERE s.name = 'bkm' AND t.name = 'SatisAnaliziTaban';
GO

/* ────────────────────────────────────────────────────────────────────────────
   09.09.2026 — TAZE STOK kolonu (kullanıcı isteği: "taze stokları burada devre
   dışı bırakabilmek lazım")

   NEDEN: yeni gelen mal "aşırı stok" ya da "hareketsiz" sayılmamalı — satacak
   zamanı olmamıştır. Bu, satinalma-danisman'ın adil-atıf şartı: kontrol
   edilebilir karar ile henüz sonuç doğurmamış karar ayrılır.

   NEDEN IlkGiris DEĞİL: `IlkGiris` ürünün MAĞAZAYA İLK girişi (2021'e kadar
   gidebilir). Tazelik SON mal kabulüyle ölçülür → ayrı kolon.
   ──────────────────────────────────────────────────────────────────────────── */
IF COL_LENGTH('bkm.SatisAnaliziTaban', 'SonGiris') IS NULL
    ALTER TABLE bkm.SatisAnaliziTaban ADD SonGiris datetime NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_SatisAnaliziTaban_Taze'
               AND object_id = OBJECT_ID('bkm.SatisAnaliziTaban'))
    CREATE INDEX IX_SatisAnaliziTaban_Taze
        ON bkm.SatisAnaliziTaban (Kesim, SezonYil, SonGiris)
        INCLUDE (ToplamStok, SezonToplam, SatisToplam, Tutar, OdakStok);
GO
