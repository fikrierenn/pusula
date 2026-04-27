# BKM KİTAP TREND ENDEKSİ
## Tam Sistem Tasarımı — Veri Modelinden Yayına

**Hazırlayan:** Fikri Eren
**Dokuman sürümü:** 1.0
**Tarih:** 14.04.2026
**Kapsam:** Mimari, veri modeli, SQL implementasyonu, AI orchestration, yayın akışı, operasyonel süreç

---

## 0. AMAÇ VE STRATEJİK KONUM

BKM Kitap Trend Endeksi, BKM Kitap'ın kendi canlı satış, arama ve davranış datasını; dış sosyal sinyal (X, kitap haber siteleri, bestseller listeleri) ile birleştirip **haftalık yayınlanan, metodolojisi şeffaf, basın alıntılanabilir bir pazar göstergesine** dönüştüren sistemdir.

Hepsiburada tekil satış açıklamaları yapıyor ("Masumiyet Müzesi satışları %885 arttı"), Kitapyurdu sınırlı data paylaşıyor, D&R sessiz. Boşluk net: **pazarı yorumlayan düzenli yayın yok.** Endeks bu boşluğu dolduruyor.

Üç katmanlı değer üretimi:

Birinci katman, **marka**. Her hafta basında "BKM Kitap Trend Endeksi'ne göre..." alıntılandığında BKM kitap pazarının otoritesi oluyor. İkinci katman, **SEO ve organik trafik**. "kitap trend nisan 2026" gibi aramalarda BKM zirveye oturuyor. Üçüncü katman, **iç karar kalitesi**. Aynı veri mimarisi satın alma, stok, kampanya kararlarını da besliyor — yani endeks hem dışa yayın hem içe operasyonel araç.

Kritik kural: **adet değil oran yayınlanır.** Rakibe mutlak satış rakamını vermek yerine baz döneme göre oransal endeks açıklanır. Bu hem rekabet istihbaratını korur hem haber değerini düşürmez.

---

## 1. MİMARİ — KATMANLI YAPI

Sistem yedi katmandan oluşur. Her katman bir sonrakini besler, her katmanın kendi sorumluluğu vardır.

### 1.1 Katmanlar

**Katman 1 — Veri Kaynakları**

İç kaynaklar: BKM Kitap ERP/e-ticaret veritabanı (satış işlemleri, ürün kataloğu, kategori ağacı, stok, kampanya geçmişi). Site içi davranış: arama sorguları, ürün görüntüleme, sepete ekleme, istek listesi, sepet terk. Müşteri segmenti (şehir, yaş aralığı, cinsiyet — üyelikten geldiği kadarıyla).

Dış kaynaklar: X/Twitter (Grok API üzerinden), kitap haber siteleri (KalemKahveKlavye, Oggusto, Kayıp Rıhtım, EdebiyatHaber, Sabit Fikir, K24), rakip bestseller listeleri (public scraping), yayın haberleri, ödül duyuruları, dizi/film uyarlama takvimi.

**Katman 2 — Depolama (SQL Server)**

İki şema: `bkm` (mevcut operasyonel) ve `analytics` (yeni, endeks için). Read replica üzerinden beslenir, canlı sisteme yük olmaz. Immutable snapshot stratejisi: her haftanın endeks tablosu kilitlenir, geçmişe dokunulmaz.

**Katman 3 — ETL ve İşleme**

Haftalık batch job (pazartesi 03:00): önceki 7 günün satış + davranış verisini toplar, kategoriye map eder, boyut tablolarını günceller, fact tablolarına yazar. Anomali kontrolü yapar (beklenmedik büyüme/düşüş flag'ler).

**Katman 4 — Endeks Hesaplama**

Baz döneme göre oran, 13 haftalık hareketli ortalama, mevsimsellik düzeltmesi, kategori bazlı endeks, çıkış ivmesi endeksi (yeni kitaplar için), şehir ısı haritası, yükselen/düşen sıralamaları.

**Katman 5 — Anlam Üretme (AI Orchestration)**

Grok ajanı X sosyal sinyali tarar, Claude ajanı kitap haber siteleri + bestseller listelerini tarar, üçüncü bir Claude ajanı iç endeks verisini okur, birleştirici ajan üçünü tek anlatıya örer. Çıktı ham metin taslağı.

**Katman 6 — Editör / İnsan Onay**

Fact-check, ton kontrolü, basın hassasiyeti, yayın onayı. Bu katman atlanamaz; AI çıktısı asla doğrudan yayına gitmez.

**Katman 7 — Yayın ve Dağıtım**

Blog postu (trend.bkmkitap.com), basın bülteni (gazeteci e-posta listesi), sosyal medya (LinkedIn, Instagram, X), aylık özet PDF, yıllık sektör raporu.

### 1.2 Veri akış diyagramı (metinsel)

```
[BKM ERP] ──┐
[Site Davr.]─┼──> [Read Replica] ──> [ETL SP] ──> [analytics.fact_*]
[Müşteri]   ─┘                                           │
                                                         ▼
[Grok/X]  ──┐                                    [Endeks Hesap SP]
[Haber Sit.]┼──> [AI Orkestrasyon] <────────────────────┤
[Rakip Lst.]┘              │                             │
                           ▼                             ▼
                    [Anlatı Taslağı] ──> [Editör] ──> [Yayın]
                                                         │
                                                         ▼
                                          [Blog + Basın + Sosyal]
```

---

## 2. VERİ MODELİ (SQL SERVER)

### 2.1 Şema ayrımı

`bkm` şeması: mevcut operasyonel tablolar (dokunulmaz, sadece okunur).

`analytics` şeması: endeks için yeni. Tüm fact ve dim tabloları burada. Read replica üzerinde çalışır, canlı yazma yok.

### 2.2 Boyut tabloları

**analytics.dim_kategori** — Endeks kategorileri (taksonomi)

```sql
CREATE TABLE analytics.dim_kategori (
    kategori_id         INT IDENTITY(1,1) PRIMARY KEY,
    kategori_kod        VARCHAR(50) NOT NULL UNIQUE,
    kategori_ad         NVARCHAR(200) NOT NULL,
    ust_kategori_id     INT NULL REFERENCES analytics.dim_kategori(kategori_id),
    endeks_grubu        VARCHAR(50) NOT NULL, -- 'KURGU','CEVIRI','COCUK','KISISEL','BILIM','POLISIYE','DIGER'
    aktif_mi            BIT NOT NULL DEFAULT 1,
    olusturma_tarih     DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);
```

**analytics.dim_kitap** — Kitap boyutu (ISBN seviyesinde)

```sql
CREATE TABLE analytics.dim_kitap (
    kitap_id            BIGINT IDENTITY(1,1) PRIMARY KEY,
    isbn13              VARCHAR(13) NOT NULL UNIQUE,
    kitap_ad            NVARCHAR(500) NOT NULL,
    yazar               NVARCHAR(300) NULL,
    cevirmen            NVARCHAR(300) NULL,
    yayinevi            NVARCHAR(200) NULL,
    kategori_id         INT NOT NULL REFERENCES analytics.dim_kategori(kategori_id),
    cikis_tarih         DATE NULL,
    dil                 VARCHAR(10) NULL,
    sayfa_sayisi        INT NULL,
    bkm_urun_kod        VARCHAR(50) NULL, -- BKM iç kodu
    ilk_satis_tarih     DATE NULL,
    aktif_mi            BIT NOT NULL DEFAULT 1
);

CREATE INDEX ix_dim_kitap_kategori ON analytics.dim_kitap(kategori_id);
CREATE INDEX ix_dim_kitap_cikis ON analytics.dim_kitap(cikis_tarih);
```

**analytics.dim_zaman** — Haftalık kovalar

```sql
CREATE TABLE analytics.dim_zaman (
    zaman_id            INT PRIMARY KEY, -- YYYYWW formatında (ör. 202615)
    yil                 INT NOT NULL,
    hafta_no            INT NOT NULL,
    hafta_bas_tarih     DATE NOT NULL, -- pazartesi
    hafta_bit_tarih     DATE NOT NULL, -- pazar
    baz_donem_mi        BIT NOT NULL DEFAULT 0,
    tatil_haftasi_mi    BIT NOT NULL DEFAULT 0, -- ramazan, yılbaşı, sömestre vb.
    aciklama            NVARCHAR(200) NULL
);
```

**analytics.dim_sehir** — Şehir boyutu

```sql
CREATE TABLE analytics.dim_sehir (
    sehir_id            INT IDENTITY(1,1) PRIMARY KEY,
    sehir_ad            NVARCHAR(100) NOT NULL UNIQUE,
    bolge               NVARCHAR(50) NULL, -- Marmara, Ege, vs.
    nufus_bandi         VARCHAR(20) NULL   -- 'BUYUK','ORTA','KUCUK'
);
```

### 2.3 Fact tabloları

**analytics.fact_satis_haftalik** — Haftalık kitap satışı (anonim, agrege)

```sql
CREATE TABLE analytics.fact_satis_haftalik (
    fact_id             BIGINT IDENTITY(1,1) PRIMARY KEY,
    zaman_id            INT NOT NULL REFERENCES analytics.dim_zaman(zaman_id),
    kitap_id            BIGINT NOT NULL REFERENCES analytics.dim_kitap(kitap_id),
    sehir_id            INT NULL REFERENCES analytics.dim_sehir(sehir_id),
    adet                INT NOT NULL,
    siparis_sayisi      INT NOT NULL, -- kaç farklı siparişte geçti
    benzersiz_musteri   INT NOT NULL, -- kaç farklı müşteri aldı
    sepete_ekleme_sayisi INT NULL,    -- o hafta sepete eklenme
    arama_sayisi        INT NULL,     -- site içi arama
    urun_goruntuleme    INT NULL,
    olusturma_tarih     DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT uq_fact_satis UNIQUE (zaman_id, kitap_id, sehir_id)
);

CREATE INDEX ix_fact_satis_zaman ON analytics.fact_satis_haftalik(zaman_id);
CREATE INDEX ix_fact_satis_kitap ON analytics.fact_satis_haftalik(kitap_id);
```

**analytics.fact_endeks** — Hesaplanmış endeks tablosu (yayın için kaynak)

```sql
CREATE TABLE analytics.fact_endeks (
    endeks_id           BIGINT IDENTITY(1,1) PRIMARY KEY,
    zaman_id            INT NOT NULL REFERENCES analytics.dim_zaman(zaman_id),
    endeks_tipi         VARCHAR(30) NOT NULL, -- 'GENEL','KATEGORI','CIKIS_IVMESI'
    kategori_id         INT NULL REFERENCES analytics.dim_kategori(kategori_id),
    endeks_deger        DECIMAL(10,2) NOT NULL,     -- 100 = baz
    haftalik_degisim    DECIMAL(10,2) NULL,         -- önceki haftaya göre %
    yillik_degisim      DECIMAL(10,2) NULL,         -- 52 hafta önceye göre %
    hareketli_ort_13h   DECIMAL(10,2) NULL,         -- 13 haftalık
    anomali_flag        BIT NOT NULL DEFAULT 0,
    hesaplama_tarih     DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    immutable_mi        BIT NOT NULL DEFAULT 0,     -- yayınlanınca 1 olur
    CONSTRAINT uq_fact_endeks UNIQUE (zaman_id, endeks_tipi, kategori_id)
);
```

**analytics.fact_sosyal_sinyal** — Dış sosyal veri (AI ajanlarından gelir)

```sql
CREATE TABLE analytics.fact_sosyal_sinyal (
    sinyal_id           BIGINT IDENTITY(1,1) PRIMARY KEY,
    zaman_id            INT NOT NULL REFERENCES analytics.dim_zaman(zaman_id),
    kitap_id            BIGINT NULL REFERENCES analytics.dim_kitap(kitap_id),
    kaynak              VARCHAR(30) NOT NULL, -- 'X_GROK','HABER_CLAUDE','BESTSELLER'
    konu                NVARCHAR(500) NULL,   -- trend/tema
    tweet_sayisi        INT NULL,
    toplam_engagement   INT NULL,
    sentiment           VARCHAR(20) NULL,     -- 'OLUMLU','OLUMSUZ','KARISIK','IRONIK'
    iron_riski          VARCHAR(10) NULL,     -- 'DUSUK','ORTA','YUKSEK'
    guven_etiket        VARCHAR(10) NULL,     -- 'DUSUK','ORTA','YUKSEK'
    ham_metin           NVARCHAR(MAX) NULL,   -- AI çıktısı özet
    olusturma_tarih     DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);

CREATE INDEX ix_sosyal_zaman ON analytics.fact_sosyal_sinyal(zaman_id);
```

**analytics.fact_cikis_ivmesi** — Yeni kitap çıkış hızı

```sql
CREATE TABLE analytics.fact_cikis_ivmesi (
    ivme_id             BIGINT IDENTITY(1,1) PRIMARY KEY,
    kitap_id            BIGINT NOT NULL REFERENCES analytics.dim_kitap(kitap_id),
    cikis_tarih         DATE NOT NULL,
    ilk_7_gun_adet      INT NULL,
    ilk_14_gun_adet     INT NULL,
    ilk_30_gun_adet     INT NULL,
    ivme_skoru          DECIMAL(10,2) NULL, -- hızına göre 0-1000
    kategori_ortalama   DECIMAL(10,2) NULL, -- aynı kategoride ort.
    performans_orani    DECIMAL(10,2) NULL, -- kitap / kategori ort
    hesaplama_tarih     DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);
```

### 2.4 Metodoloji tablosu

**analytics.endeks_parametreleri** — Metodoloji değişkenlerini versiyonlu tutar

```sql
CREATE TABLE analytics.endeks_parametreleri (
    param_id            INT IDENTITY(1,1) PRIMARY KEY,
    param_ad            VARCHAR(50) NOT NULL,
    param_deger         NVARCHAR(500) NOT NULL,
    gecerlilik_bas      DATE NOT NULL,
    gecerlilik_bit      DATE NULL,
    aciklama            NVARCHAR(MAX) NULL,
    olusturan           VARCHAR(50) NOT NULL,
    olusturma_tarih     DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);

-- Örnek veri
INSERT INTO analytics.endeks_parametreleri (param_ad, param_deger, gecerlilik_bas, olusturan, aciklama)
VALUES
('BAZ_DONEM_ZAMAN_ID', '202601', '01.01.2026', 'fikri',
 '2026 ilk haftası baz dönem olarak alındı. Endeks = 100.'),
('HAREKETLI_ORT_HAFTA', '13', '01.01.2026', 'fikri',
 'Mevsimsellik düzeltmesi için 13 haftalık hareketli ortalama.'),
('ANOMALI_ESIK_YUZDE', '50', '01.01.2026', 'fikri',
 'Haftalık değişim ±%50 üstünde anomali flag.');
```

### 2.5 Yayın log tablosu

**analytics.yayin_log** — Her yayınlanan sayının kaydı (denetim izi)

```sql
CREATE TABLE analytics.yayin_log (
    yayin_id            BIGINT IDENTITY(1,1) PRIMARY KEY,
    zaman_id            INT NOT NULL REFERENCES analytics.dim_zaman(zaman_id),
    yayin_tarih         DATETIME2 NOT NULL,
    kanal               VARCHAR(30) NOT NULL, -- 'BLOG','BASIN','LINKEDIN','INSTAGRAM','X'
    url                 NVARCHAR(1000) NULL,
    snapshot_json       NVARCHAR(MAX) NOT NULL, -- o anki endeks değerleri JSON
    duzeltme_mi         BIT NOT NULL DEFAULT 0,
    duzeltme_notu       NVARCHAR(MAX) NULL,
    onaylayan           VARCHAR(100) NOT NULL
);
```

---

## 3. KATEGORİ TAKSONOMİSİ

Endeks için BKM'nin mevcut kategori ağacı fazla detaylı. Yayın için **yedi ana endeks grubu** yeter:

| Kod | İsim | Kapsam |
|-----|------|--------|
| KURGU | Kurgu (Türk) | Türk yazarların romanları, öykü, kısa kurgu |
| CEVIRI | Çeviri Edebiyat | Yabancı yazar + çeviri romanlar |
| POLISIYE | Polisiye & Gerilim | Yerli + çeviri, psikolojik gerilim dahil |
| COCUK | Çocuk & İlk Gençlik | 0-14 yaş |
| GENC_YETISKIN | Genç Yetişkin (YA) | 14-25 yaş, romantasy, YA fantastik |
| KISISEL | Kişisel Gelişim | Klasik kişisel gelişim + psikoloji popüler |
| BILIM | Popüler Bilim & Tarih | Bilim, tarih, felsefe popüler |
| AKADEMIK | Akademik (ayrı izlem) | Ana endekse girmez, ayrı gösterge |

Mevcut BKM kategori ID'lerinden bu yedi gruba eşleme tablosu kurulur (`dim_kategori.endeks_grubu` kolonuyla). Eşleme versiyonludur — değişirse eski snapshot'lar eski eşlemeyle kalır.

---

## 4. ENDEKS HESAPLAMA METODOLOJİSİ

### 4.1 Baz dönem

2026 birinci hafta (06.01.2026 – 12.01.2026) baz dönem. O haftanın toplam kurgu satış adedi = 100.

### 4.2 Genel Endeks formülü

```
Genel Endeks(t) = (Toplam satış adedi(t) / Toplam satış adedi(baz)) × 100
```

### 4.3 Kategori Endeksi

```
Kategori Endeksi(k,t) = (k kategori satış(t) / k kategori satış(baz)) × 100
```

### 4.4 Hareketli ortalama (13 haftalık)

```
HO13(t) = (Endeks(t) + Endeks(t-1) + ... + Endeks(t-12)) / 13
```

Yayında hem spot endeks hem HO13 gösterilir. Haber başlığında spot kullanılır, yorum kısmında HO13 ile trend okunur.

### 4.5 Çıkış İvmesi Endeksi (yeni kitaplar için)

```
İvme Skoru(kitap) = (İlk 14 gün adet / Kategori ortalama ilk 14 gün) × 1000
```

1000 = kategori ortalamasında satıyor. 2000 = iki katı hızda. 500 = yarı hızda. Bu skor yeni çıkan kitapları yayında sıralamak için kullanılır.

### 4.6 Mevsimsellik düzeltmesi

Bazı haftalar yapısal olarak farklı davranır (Ramazan, yılbaşı, sömestre, 23 Nisan, Eğitim dönemi başı). `dim_zaman.tatil_haftasi_mi = 1` olan haftalarda iki endeks birden yayınlanır:

Ham endeks (olduğu gibi), Düzeltilmiş endeks (geçen yıl aynı tatil haftası baz alınarak).

### 4.7 Anomali tespiti

Haftalık değişim ±%50 üstünde → `anomali_flag = 1`. Bu kitap/kategori editör tarafından manuel incelenir. Gerçek olaysa (film uyarlama, viral tweet, ödül) raporda "Dikkat Çeken Sinyal" bölümüne taşınır. Data hatasıysa ETL düzeltilir ve audit log'a kaydedilir.

### 4.8 Güven etiketi

Her endeks satırının bir güven etiketi olur:

- **Yüksek:** haftalık satış > 100 adet, 13 hafta geçmişi var
- **Orta:** 30-100 adet veya 6-13 hafta geçmişi var
- **Düşük:** < 30 adet veya < 6 hafta geçmişi

Düşük güven satırları yayında **"gelişen sinyal"** olarak işaretlenir, manşete çıkmaz.

---

## 5. SQL İMPLEMENTASYONU

### 5.1 Haftalık ETL — ana stored procedure

```sql
CREATE OR ALTER PROCEDURE analytics.sp_haftalik_etl
    @hedef_zaman_id INT  -- ör. 202615
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @hafta_bas DATE, @hafta_bit DATE;

    SELECT @hafta_bas = hafta_bas_tarih, @hafta_bit = hafta_bit_tarih
    FROM analytics.dim_zaman
    WHERE zaman_id = @hedef_zaman_id;

    IF @hafta_bas IS NULL
    BEGIN
        RAISERROR('Hedef zaman_id dim_zaman tablosunda yok: %d', 16, 1, @hedef_zaman_id);
        RETURN;
    END

    -- Bu haftanın önceden işlenip işlenmediğini kontrol et (immutable koruması)
    IF EXISTS (
        SELECT 1 FROM analytics.fact_endeks
        WHERE zaman_id = @hedef_zaman_id AND immutable_mi = 1
    )
    BEGIN
        RAISERROR('Bu hafta kilitlenmiş, yeniden hesaplama yapılamaz: %d', 16, 1, @hedef_zaman_id);
        RETURN;
    END

    BEGIN TRAN;

    -- 1) Satış fact'ini doldur (mevcut ERP'den)
    DELETE FROM analytics.fact_satis_haftalik WHERE zaman_id = @hedef_zaman_id;

    INSERT INTO analytics.fact_satis_haftalik
        (zaman_id, kitap_id, sehir_id, adet, siparis_sayisi, benzersiz_musteri,
         sepete_ekleme_sayisi, arama_sayisi, urun_goruntuleme)
    SELECT
        @hedef_zaman_id,
        dk.kitap_id,
        ds.sehir_id,
        SUM(sk.miktar),
        COUNT(DISTINCT s.siparis_id),
        COUNT(DISTINCT s.musteri_id),
        NULL, -- sepete ekleme ayrı job ile gelir
        NULL, -- arama ayrı job
        NULL  -- görüntüleme ayrı job
    FROM bkm.siparis s
    INNER JOIN bkm.siparis_kalem sk ON s.siparis_id = sk.siparis_id
    INNER JOIN bkm.urun u ON sk.urun_id = u.urun_id
    INNER JOIN analytics.dim_kitap dk ON u.isbn13 = dk.isbn13
    LEFT JOIN analytics.dim_sehir ds ON s.teslimat_sehir = ds.sehir_ad
    WHERE s.siparis_tarih >= @hafta_bas
      AND s.siparis_tarih < DATEADD(day, 1, @hafta_bit)
      AND s.durum = 'TAMAMLANDI'
    GROUP BY dk.kitap_id, ds.sehir_id;

    -- 2) Genel endeksi hesapla
    DECLARE @baz_zaman_id INT;
    SELECT @baz_zaman_id = CAST(param_deger AS INT)
    FROM analytics.endeks_parametreleri
    WHERE param_ad = 'BAZ_DONEM_ZAMAN_ID'
      AND (gecerlilik_bit IS NULL OR gecerlilik_bit >= CONVERT(date, GETDATE()));

    DECLARE @baz_satis INT, @bu_satis INT;

    SELECT @baz_satis = SUM(adet)
    FROM analytics.fact_satis_haftalik
    WHERE zaman_id = @baz_zaman_id;

    SELECT @bu_satis = SUM(adet)
    FROM analytics.fact_satis_haftalik
    WHERE zaman_id = @hedef_zaman_id;

    DELETE FROM analytics.fact_endeks
    WHERE zaman_id = @hedef_zaman_id AND immutable_mi = 0;

    INSERT INTO analytics.fact_endeks
        (zaman_id, endeks_tipi, kategori_id, endeks_deger, haftalik_degisim, hareketli_ort_13h, anomali_flag)
    SELECT
        @hedef_zaman_id,
        'GENEL',
        NULL,
        CAST(@bu_satis * 100.0 / NULLIF(@baz_satis, 0) AS DECIMAL(10,2)),
        NULL, -- aşağıda update
        NULL, -- aşağıda update
        0;

    -- 3) Kategori endeksleri
    INSERT INTO analytics.fact_endeks
        (zaman_id, endeks_tipi, kategori_id, endeks_deger, anomali_flag)
    SELECT
        @hedef_zaman_id,
        'KATEGORI',
        dk.kategori_id,
        CAST(SUM(CASE WHEN fsh.zaman_id = @hedef_zaman_id THEN fsh.adet ELSE 0 END) * 100.0 /
             NULLIF(SUM(CASE WHEN fsh.zaman_id = @baz_zaman_id THEN fsh.adet ELSE 0 END), 0)
             AS DECIMAL(10,2)),
        0
    FROM analytics.dim_kitap dk
    LEFT JOIN analytics.fact_satis_haftalik fsh
        ON dk.kitap_id = fsh.kitap_id
       AND fsh.zaman_id IN (@hedef_zaman_id, @baz_zaman_id)
    GROUP BY dk.kategori_id;

    -- 4) Haftalık değişim hesabı
    UPDATE e
    SET haftalik_degisim =
        CAST((e.endeks_deger - p.endeks_deger) * 100.0 /
             NULLIF(p.endeks_deger, 0) AS DECIMAL(10,2))
    FROM analytics.fact_endeks e
    INNER JOIN analytics.fact_endeks p
        ON ((e.endeks_tipi = p.endeks_tipi) AND
            ((e.kategori_id = p.kategori_id) OR (e.kategori_id IS NULL AND p.kategori_id IS NULL)))
    WHERE e.zaman_id = @hedef_zaman_id
      AND p.zaman_id = @hedef_zaman_id - 1;

    -- 5) 13 haftalık hareketli ortalama
    UPDATE e
    SET hareketli_ort_13h = ho.ort
    FROM analytics.fact_endeks e
    CROSS APPLY (
        SELECT AVG(endeks_deger) AS ort
        FROM analytics.fact_endeks e2
        WHERE e2.endeks_tipi = e.endeks_tipi
          AND ((e2.kategori_id = e.kategori_id) OR (e2.kategori_id IS NULL AND e.kategori_id IS NULL))
          AND e2.zaman_id BETWEEN @hedef_zaman_id - 12 AND @hedef_zaman_id
    ) ho
    WHERE e.zaman_id = @hedef_zaman_id;

    -- 6) Anomali flag
    DECLARE @anomali_esik DECIMAL(10,2);
    SELECT @anomali_esik = CAST(param_deger AS DECIMAL(10,2))
    FROM analytics.endeks_parametreleri
    WHERE param_ad = 'ANOMALI_ESIK_YUZDE'
      AND (gecerlilik_bit IS NULL OR gecerlilik_bit >= CONVERT(date, GETDATE()));

    UPDATE analytics.fact_endeks
    SET anomali_flag = 1
    WHERE zaman_id = @hedef_zaman_id
      AND ABS(haftalik_degisim) > @anomali_esik;

    COMMIT TRAN;

    PRINT 'Haftalık ETL tamamlandı: ' + CAST(@hedef_zaman_id AS VARCHAR);
END;
GO
```

### 5.2 Yayın kilitleme (immutable snapshot)

```sql
CREATE OR ALTER PROCEDURE analytics.sp_yayin_kilitle
    @zaman_id INT,
    @onaylayan VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRAN;

    UPDATE analytics.fact_endeks
    SET immutable_mi = 1
    WHERE zaman_id = @zaman_id;

    INSERT INTO analytics.yayin_log
        (zaman_id, yayin_tarih, kanal, snapshot_json, onaylayan)
    SELECT
        @zaman_id,
        SYSUTCDATETIME(),
        'BLOG',
        (SELECT * FROM analytics.fact_endeks
         WHERE zaman_id = @zaman_id FOR JSON AUTO),
        @onaylayan;

    COMMIT TRAN;
END;
GO
```

### 5.3 Örnek yayın sorguları

**En çok yükselen 10 kitap (bu hafta)**

```sql
DECLARE @simdi INT = 202615, @onceki INT = 202614;

SELECT TOP 10
    dk.kitap_ad,
    dk.yazar,
    dk.yayinevi,
    kat.kategori_ad,
    ISNULL(simdi.adet, 0) AS bu_hafta_adet,
    ISNULL(once.adet, 0) AS gecen_hafta_adet,
    CAST((ISNULL(simdi.adet, 0) - ISNULL(once.adet, 0)) * 100.0 /
         NULLIF(ISNULL(once.adet, 0), 0) AS DECIMAL(10,2)) AS buyume_yuzde
FROM analytics.dim_kitap dk
INNER JOIN analytics.dim_kategori kat ON dk.kategori_id = kat.kategori_id
LEFT JOIN (
    SELECT kitap_id, SUM(adet) adet
    FROM analytics.fact_satis_haftalik
    WHERE zaman_id = @simdi GROUP BY kitap_id
) simdi ON dk.kitap_id = simdi.kitap_id
LEFT JOIN (
    SELECT kitap_id, SUM(adet) adet
    FROM analytics.fact_satis_haftalik
    WHERE zaman_id = @onceki GROUP BY kitap_id
) once ON dk.kitap_id = once.kitap_id
WHERE ISNULL(simdi.adet, 0) >= 30  -- güven eşiği
ORDER BY buyume_yuzde DESC;
```

**Şehir ısı haritası (bu hafta)**

```sql
SELECT
    ds.sehir_ad,
    ds.bolge,
    SUM(fsh.adet) AS toplam_adet,
    COUNT(DISTINCT fsh.kitap_id) AS farkli_kitap,
    CAST(SUM(fsh.adet) * 100.0 /
         SUM(SUM(fsh.adet)) OVER () AS DECIMAL(10,2)) AS pazar_payi_yuzde
FROM analytics.fact_satis_haftalik fsh
INNER JOIN analytics.dim_sehir ds ON fsh.sehir_id = ds.sehir_id
WHERE fsh.zaman_id = 202615
GROUP BY ds.sehir_ad, ds.bolge
ORDER BY toplam_adet DESC;
```

**Çıkış ivmesi — bu ay yeni çıkan en hızlı 10 kitap**

```sql
SELECT TOP 10
    dk.kitap_ad,
    dk.yazar,
    dk.yayinevi,
    CONVERT(VARCHAR, dk.cikis_tarih, 104) AS cikis,
    fci.ilk_14_gun_adet,
    fci.ivme_skoru,
    fci.performans_orani
FROM analytics.fact_cikis_ivmesi fci
INNER JOIN analytics.dim_kitap dk ON fci.kitap_id = dk.kitap_id
WHERE dk.cikis_tarih >= CONVERT(date, '01.04.2026', 104)
  AND dk.cikis_tarih <= CONVERT(date, '30.04.2026', 104)
ORDER BY fci.ivme_skoru DESC;
```

---

## 6. DASHBOARD KATMANI

İki ayrı dashboard kurulacak:

### 6.1 İç yönetim paneli (Power BI, canlı)

**Erişim:** BKM satın alma, pazarlama, üst yönetim.
**Yenileme:** Günlük (gecelik refresh).
**İçerik:** Mutlak satış rakamları dahil tam data. Kategori bazlı günlük trend, en hızlı hareketliler, stok gerginliği uyarıları, satın alma öneri listesi, kampanya performans.

**Ana sayfalar:**

Sayfa 1 — Özet: 7 endeks grubunun spot + HO13 değerleri, bu haftanın top 10 hareketlisi, anomali flag listesi.

Sayfa 2 — Kategori Drill-down: Seçilen kategoride kitap kitap görünüm, yayınevi kırılımı, şehir kırılımı.

Sayfa 3 — Stok & Satın Alma: Tükenen/tükenmekte olan yüksek ivmeli kitaplar, yeniden sipariş önerisi.

Sayfa 4 — Yeni Çıkışlar: Son 30 günde çıkanlar, ivme skoruna göre sıralı.

Sayfa 5 — Sosyal Sinyal: AI ajanlardan gelen X/haber sinyalleri, iç satış ile korelasyon.

### 6.2 Yayın paneli (Power BI embed, public)

**Erişim:** trend.bkmkitap.com üzerinden halka açık.
**Yenileme:** Haftalık (cuma 09:00, kilitlendikten sonra).
**İçerik:** Sadece oransal endeks değerleri ve tarihsel seri. Mutlak rakam YOK.

**Ana görseller:** Yedi endeks grubunun zamansal serisi (line chart), bu hafta manşet sayıları (big number), kategori karşılaştırma (bar), tarihsel en yüksek/en düşük.

---

## 7. AI ORCHESTRATION KATMANI

Üç ajan paralel çalışır, dördüncü ajan birleştirir, editör onaylar.

### 7.1 Ajan 1 — Grok (X Sosyal Sinyal)

**Rol:** X/Twitter Türkçe kitap konuşmasını tarar, trope/tema/kitap sinyali üretir.
**Sıklık:** Cuma 07:00, rapor için 7 günlük pencere.
**Çıktı formatı:** JSON — `[{kitap_veya_konu, hacim, sentiment, iron_riski, kaynak_hesap_tipi, guven}]`
**Prompt:** (önceki turn'da yazılan v2 prompt + ISBN zorunluluğu + rakip marka taraması eklenmiş hali)
**Veri hedefi:** `analytics.fact_sosyal_sinyal` tablosuna INSERT.

### 7.2 Ajan 2 — Claude (Kaynak Odaklı Tarama)

**Rol:** Kitap haber siteleri, bestseller listeleri, kültür basını, ödül duyuruları, dizi/film uyarlama haberleri tarar. İsimlendirilmiş kitap, yazar, yayınevi bilgisi üretir.
**Sıklık:** Cuma 07:00, 7 günlük pencere.
**Çıktı formatı:** JSON — `[{isbn_tahmin, kitap_ad, yazar, yayinevi, haber_kaynak, olay_tipi, guven}]`
**Prompt:** (BKM Kitap bağlamı + yedi kategori taksonomisi + fact-check zorunluluğu)
**Veri hedefi:** `analytics.fact_sosyal_sinyal` tablosuna INSERT (kaynak = 'HABER_CLAUDE').

### 7.3 Ajan 3 — Claude (İç Veri Okuyucu)

**Rol:** `analytics` şemasından bu haftanın endekslerini, anomalileri, top hareketlileri okur, özet metne çevirir.
**Sıklık:** Cuma 08:30 (ETL bittikten sonra).
**Çıktı formatı:** Markdown taslak — "bu hafta endeksler" bölümü.
**Teknik:** SQL Server MCP üzerinden veriye doğrudan erişir, 10-15 önceden tanımlı sorgu çalıştırır.

### 7.4 Ajan 4 — Birleştirici (Claude)

**Rol:** Üç ajanın çıktısını okur, çelişkileri işaretler, tek bir anlatı oluşturur. Bu haftaki "manşet hikaye"yi seçer.
**Sıklık:** Cuma 09:30.
**Çıktı formatı:** Tam rapor taslağı (blog postu + basın bülteni + sosyal içerik).

**Birleştirici prompt iskeleti:**

```
Rol: BKM Kitap Trend Endeksi birleştirici editörü. Üç kaynağı
okuyup tek anlatı üretiyorsun.

Girdi:
1. İÇ ENDEKS VERİSİ (en güvenilir, sayısal)
2. KİTAP HABER SİNYALLERİ (Claude-haber ajanı)
3. X SOSYAL SİNYAL (Grok ajanı)

Kurallar:
- İç endeks verisi çelişkide hakem. Dış sinyal iç veriyle
  çelişirse "dış sinyal güçlü ama satışa yansımamış" diye
  işaretle, doğrulatma.
- Manşet hikaye seçerken: anomali flag + yüksek güven
  öncelikli. Düşük güven sinyali manşete çıkmaz.
- İroni riski yüksek tweet'lerden gelen sentiment'ı olumlu
  saymayın.
- Her kitap adı geçince ISBN'i de yanına yaz (varsa); yoksa
  "[ISBN teyit gerekli]" işareti bırak.
- Rakibe mutlak satış rakamı yazma; sadece endeks oranları.
- 800-1200 kelime blog postu + 300 kelime basın bülteni +
  LinkedIn için 150 kelime + Instagram için 60 kelime üret.

Çıktı yapısı: (aşağıdaki yayın formatlarını takip et)
```

### 7.5 Editör onay checklist

AI çıktısı editöre şu checklist'le iner:

1. Manşete çıkan üç iddianın kaynağı doğrulandı mı? (fact-check)
2. İç endeks rakamları SQL'den teyit edildi mi?
3. Rakip ismi veya mutlak satış rakamı metinde sızdı mı?
4. Rapor öncesi yayın yapılan kitaplar hakkında hata düzeltme gerekiyor mu?
5. İroni riski yüksek alıntı var mı, varsa bağlamı belirtiliyor mu?
6. Hukuk hassas alıntı (yazar sözü, yayınevi iddiası) var mı, izin gerekir mi?
7. Basın bülteni 300 kelimeyi geçti mi (geçti ise kırp)?

Onay sonrası `sp_yayin_kilitle` çağrılır, yayın kanallarına push yapılır.

---

## 8. YAYIN FORMATLARI

### 8.1 Blog postu şablonu (trend.bkmkitap.com)

```
Başlık: BKM Kitap Trend Endeksi — {tarih aralığı}

Spot: Bu hafta {manşet hikaye — tek cümle}. Genel Endeks {X},
geçen haftaya göre %{Y} {yön}.

--- Bu Hafta Sayılar ---
| Endeks | Değer | Haftalık | 13H Ortalama |
| Genel  | 138   | +4.2%    | 132          |
| Kurgu  | 152   | +6.1%    | 141          |
| ... (7 satır)

--- Bu Haftanın Hikayesi ---
{300-400 kelime. Manşet kitap/olay/trend etrafında anlatı.
İç endeks + dış sinyal birleştirilmiş. İsimlendirilmiş 3-5
kitap. İç anomali flag'lerden çıkan gerçek sinyaller.}

--- En Hızlı Yükselen 5 Kitap ---
(isim + yazar + yayınevi + kategori + haftalık büyüme)

--- En Hızlı Soğuyan 3 Kitap ---
(aynı format)

--- Dikkat Çeken Sinyal ---
{1-2 paragraf. Erken sinyal, henüz satışa yansımamış ama
önümüzdeki haftalarda patlayabilecek konu.}

--- Önümüzdeki Hafta ---
{100-150 kelime. Takip edeceğimiz olaylar: çıkacak kitaplar,
ödül töreni, dizi/film, yayınevi lansmanı.}

--- Metodoloji ---
Baz dönem: 06-12 Ocak 2026. Endeks = 100. 13 haftalık
hareketli ortalama uygulanır. Tam metodoloji notu için:
trend.bkmkitap.com/metodoloji
```

### 8.2 Basın bülteni şablonu

```
BASIN BÜLTENİ
{tarih}
BKM Kitap

BAŞLIK: BKM Kitap Trend Endeksi — {haftanın ana hikayesi}

SPOT (2 cümle):
{Manşet iddia + destekleyici rakam.}

ANA BULGULAR:
• Genel Endeks: {X} ({yön, %})
• En yüksek büyüme: {Kategori} (+%{Y})
• En çok konuşulan kitap: {ad - yazar - yayınevi}
• Dikkat çeken sinyal: {1 cümle}

ALINTILANABİLİR:
"{Yönetici/analist ağzından 2 cümle. Gazeteci bunu alıp
haberine koyacak. Metodoloji + yorum.}"

İLETİŞİM:
BKM Kitap İletişim — {isim, e-posta, tel}
Metodoloji notu: trend.bkmkitap.com/metodoloji
Görsel indirme: trend.bkmkitap.com/press/{hafta}
```

### 8.3 LinkedIn postu (150 kelime)

```
Bu hafta kitap pazarında {manşet}.

BKM Kitap Trend Endeksi'ne göre:
→ Genel Endeks: {X}
→ En hızlı büyüyen: {kategori} (+%{Y})
→ Dikkat çeken: {kitap/trend}

{50 kelime yorum — neden önemli, ne anlama geliyor.}

Tam rapor: {link}

#kitapsektörü #perakende #veri #trend
```

### 8.4 Instagram carousel (5 slayt)

```
Slayt 1 — Manşet: tek cümle, büyük font, marka rengi
Slayt 2 — Genel Endeks big number + haftalık ok
Slayt 3 — 7 kategori tablosu (grafiksel)
Slayt 4 — Top 5 yükselen kitap kapak kolajı
Slayt 5 — "Haftalık raporun tamamı için..." CTA
```

### 8.5 X thread (6 tweet)

```
1/ BKM Kitap Trend Endeksi bu hafta yayında.
   {manşet cümlesi}

2/ Genel Endeks: {X} (haftalık %{Y})
   En büyük hareket: {kategori}

3/ Bu haftanın hikayesi: {2-3 cümle}

4/ En hızlı büyüyen 3 kitap:
   • {ad - yazar}
   • {ad - yazar}
   • {ad - yazar}

5/ Dikkat çeken erken sinyal: {1 cümle}

6/ Tam rapor + metodoloji: {link}
```

---

## 9. OPERASYONEL SÜREÇ

### 9.1 Haftalık takvim

| Gün | Saat | İş | Sorumlu |
|-----|------|----|---------| 
| Pazartesi | 03:00 | ETL job — önceki haftanın satış/davranış datası çekilir | Sistem (otomatik) |
| Pazartesi | 09:00 | ETL sonuç kontrolü, anomali listesi review | Veri Analisti |
| Pazartesi | 14:00 | Haftanın kategorize edilmemiş yeni ISBN'leri eşlenir | Veri Analisti |
| Perşembe | 09:00 | Ön endeks review — yönetimle paylaşım | Veri Analisti |
| Perşembe | 14:00 | Fact-check listesi hazırlanır (şüpheli iddialar) | Editör |
| Cuma | 07:00 | Grok + Claude ajanları paralel çalışır | Sistem (otomatik) |
| Cuma | 08:30 | İç veri okuyucu ajan çalışır | Sistem (otomatik) |
| Cuma | 09:30 | Birleştirici ajan taslak üretir | Sistem (otomatik) |
| Cuma | 10:00 | Editör onay süreci başlar | Editör |
| Cuma | 11:30 | Yönetim onayı | Üst Yönetim |
| Cuma | 12:00 | Yayın — blog + basın + sosyal | İletişim |
| Cuma | 12:30 | Gazeteci takip e-postaları | İletişim |

### 9.2 Roller (RACI)

| İş | Veri Analisti | Editör | İletişim | Üst Yönetim |
|----|---------------|--------|----------|-------------|
| ETL & endeks hesabı | R | I | I | A |
| Anomali review | R | C | I | A |
| AI taslak üretim | C | R | I | I |
| Fact-check | C | R | I | I |
| Yayın metni onay | I | R | C | A |
| Yayın publishing | I | C | R | I |
| Basın takip | I | I | R | I |
| Metodoloji değişimi | R | C | I | A |

R=Responsible, A=Accountable, C=Consulted, I=Informed

### 9.3 Ekip boyutu (pilot)

Yarım zamanlı veri analisti + yarım zamanlı editör/yazar + mevcut pazarlama ekibinden çeyrek zaman iletişim sorumlusu = **1.25 FTE** ilk yıl için yeter. İkinci yıl trafiğe göre büyütülür.

---

## 10. VERİ GİZLİLİĞİ POLİTİKASI

### 10.1 Asla yayınlanmayacaklar

- Mutlak satış adedi (toplam veya kategori)
- Mutlak ciro
- Kar marjı bilgisi
- Tekil müşteri bilgisi veya sipariş detayı
- Yayınevi bazlı satış ranking (yayınevi iç hassas)
- Rakip ürün satışları (varsa scraping ile)
- Stok seviyesi

### 10.2 Yayınlanabilecekler

- Baz döneme göre oransal endeks
- Haftalık % değişim
- Yıllık % değişim
- Kitap-kitap yarış sıralaması (satış adedi yok, sadece sıra)
- Şehir pazar payı yüzdesi (adet yok)
- Kategori trend yönü

### 10.3 Yayınevi hassasiyeti

Bir yayınevi rapor sonrası "bizim kitabımız niye yok/neden yanlış yerde" diye itiraz edebilir. Politika: metodoloji notu halka açık, itiraz şablonu hazır, 48 saat içinde yazılı cevap verilir. Düzeltme gerekirse audit log + görünür hata notu yayınlanır.

### 10.4 Rakip ve basın

Basın rapordaki rakamları alıntılayabilir, görseli kaynak göstererek kullanabilir. Rakip e-ticaret firmaları rapora erişebilir ama mutlak satış tahmini çıkaramaz (oran şeffaf, adet kapalı).

---

## 11. KPI VE ÖLÇÜM

### 11.1 Yayın KPI'ları (ilk 6 ay)

- Haftalık blog postu trafiği — hedef: 3. ay 10K/hafta, 6. ay 30K/hafta
- Basın alıntı sayısı — hedef: 6. ay haftalık 3+ medya mention
- SEO rank — hedef: "kitap trend {ay} {yıl}" aramalarında ilk 3
- LinkedIn post erişimi — hedef: 3. ay ortalama 5K impression/post
- "BKM Kitap Trend Endeksi" marka araması — hedef: 6. ay aylık 2K+

### 11.2 İç KPI'lar

- Endeks anomali yakalama doğruluğu — rastgele 20 anomalinin kaçı gerçek olay (hedef ≥ %80)
- Yayın zamanında çıkma oranı — cuma 12:00'dan geç kalan sayı (hedef sıfır)
- Fact-check hata oranı — yayın sonrası düzeltilmek zorunda kalınan iddia sayısı (hedef < %2)
- İç satın alma kullanımı — haftalık endeks raporunu satın alma toplantısında kullanım frekansı

---

## 12. RİSK VE DİKKAT

### 12.1 Fact-check protokolü

Her yayın öncesi editör şu üç kanaldan doğrulama yapar:

1. **Sayısal iddia** → SQL sorgusuyla doğrulanır, screenshot alınır, yayın klasörüne eklenir
2. **Haber iddiası** (röportaj, ödül, uyarlama) → orijinal kaynak link + tarih teyit
3. **Sosyal alıntı** (tweet özeti) → Grok ajanının verdiği hesap + tweet kimliği teyit

Tek bir iddianın bile doğrulanamaması → o iddia yayından çıkarılır, yerine "takipte" notu konur.

### 12.2 Düzeltme politikası

Yayın sonrası hata tespit edilirse:

1. Aynı gün düzeltme notu URL'e eklenir
2. Basın bülteni gittiyse gazetecilere düzeltme e-postası
3. Audit log'a kayıt (`yayin_log.duzeltme_mi = 1`)
4. **Sessiz düzeltme yapılmaz** — hatayı gizlemek güven kaybettirir, şeffaflık korur

### 12.3 Rakip kopyalama riski

Kitapyurdu veya D&R aynı formatı deneyebilir. Savunma: first-mover otoritesi, metodoloji patenti (yayınlanmış metodoloji notu "biz önce yaptık" kanıtı), ajans/basın ilişkisinin derinleşmesi, endeksin sektör referansı olarak yerleşmesi. İlk 12 ay kritik — yayının hiç aksamaması, metodoloji güveninin kurulması.

---

## 13. PİLOT PLAN

### 13.1 Hafta 1 (sadece iç)

- `analytics` şeması kurulur, dim tabloları doldurulur
- Son 13 hafta tarihsel ETL çalıştırılır (endeks serisini oluştur)
- Baz dönem endeksleri hesaplanır
- İç yönetim panel ilk versiyonu çıkar
- Yönetim toplantısında endeks tanıtılır, geri bildirim alınır

### 13.2 Hafta 2 (iç + LinkedIn soft launch)

- Veri analisti haftalık ön rapor hazırlar
- Editör AI ajanları olmadan manuel 800 kelime blog taslağı yazar (metodoloji testi)
- Senin kişisel LinkedIn'inden organik post (kurumsal değil) — tepki ölç
- Yönetim son kararı verir: tam lansmana gidelim mi

### 13.3 Hafta 3 (blog + 5 gazeteci pilot)

- Blog postu yayınlanır (trend.bkmkitap.com)
- 5 seçilmiş gazeteciye özel "önce size" basın bülteni
- AI orchestration'ın ilk tam iterasyonu (Grok + Claude)
- Editör checklist'i gerçek kullanımda test edilir

### 13.4 Hafta 4 (tam lansman)

- Blog + tam basın listesi + LinkedIn + Instagram + X
- Metodoloji notu halka açılır
- İlk haftalık ritim stabilize edilir

### 13.5 Karar noktası (hafta 5)

Dört haftanın çıktıları değerlendirilir:

- Kaç basın mention var?
- Blog trafiği, SEO etki?
- İç ekip süreç yükünü kaldırıyor mu?
- AI orchestration %80+ tutarlı çıkıyor mu?

Olumluysa: yayın ritmi kalıcı, altıncı aydan sonra aylık özet PDF, 12. aydan sonra yıllık sektör raporu.
Olumsuzsa: aksayan katmana odaklan, iki hafta daha pilot, sonra tekrar değerlendir.

---

## 14. İLK PİLOT SAYI (ÖRNEK MAKET)

Aşağıdaki rapor gerçek veri yok — varsayım rakamlarla sistemin nasıl yayın üreteceğinin maketidir. Yayın günü cuma 17.04.2026 varsayımıyla.

---

### **BKM Kitap Trend Endeksi — 7-13 Nisan 2026 Haftası**

**Spot:** Bu hafta **çeviri edebiyat** iki yıllık zirveye çıktı; Georgi Gospodinov'un Nobel söylentileri ve Laurent Mauvignier'in Goncourt Türkiye seçimi birleşti. Genel Endeks 138.

#### Bu Hafta Sayılar

| Endeks | Değer | Haftalık | 13H Ort |
|--------|-------|----------|---------|
| Genel | 138 | +4.2% | 132 |
| Kurgu | 145 | +3.1% | 139 |
| **Çeviri** | **172** | **+12.8%** | **148** |
| Polisiye | 128 | +1.9% | 127 |
| Çocuk | 119 | -0.5% | 122 |
| Genç Yetişkin | 156 | +8.4% | 141 |
| Kişisel Gelişim | 104 | -3.2% | 110 |
| Popüler Bilim | 132 | +2.1% | 130 |

#### Bu Haftanın Hikayesi

Çeviri edebiyat endeksinin 13 haftalık ortalamasının %16 üstüne çıkması yapısal bir kayma sinyali veriyor. İki olay tetikleyici: Bulgar yazar Georgi Gospodinov'un **Bahçıvan ve Ölüm** romanı hem uluslararası Nobel adaylığı söylentileri hem ayrıntılı edebiyat eleştirisi yazılarıyla bu hafta 400+ tweet ve 12 haber sitesinde yer aldı. BKM'de kitabın haftalık site içi araması %340 arttı, satışa da ivme yansıdı.

İkinci tetikleyici Laurent Mauvignier'in **La Maison vide** eserinin Goncourt Türkiye seçimine girmesi. Ödül haberi cuma günü duyuruldu, aynı gün Türkçe baskı için yayın haberi doğrulandı. Bu kitap henüz Türkçe yayınlanmadığı için satışta değil, ama yazarın önceki eseri **Onlardan Uzakta** çeviri kurgu alt endeksinde haftalık %47 büyüdü — okur "aynı yazar" etkisiyle geri dönük aldı.

Üçüncü ve daha sessiz bir hikaye: **Japon iyileştirici kurgu** mikro-trendi. Nanako Hanada'nın **Kitapçı Kadın**ı Vogue Türkiye kitap seçkisine girdikten sonra iki hafta üst üste artıyor; bu haftaki ivmesi kategori ortalamasının 1.8 katı. İç panelde bu kitap "takipte" flag'li, önümüzdeki hafta anasayfa öne çıkarma adayı.

#### En Hızlı Yükselen 5 Kitap

1. **Bahçıvan ve Ölüm** — Georgi Gospodinov (Metis) — Çeviri — %+84
2. **Onlardan Uzakta** — Laurent Mauvignier (Can) — Çeviri — %+47
3. **Kız Neşesi** — Buket Uzuner (Everest) — Kurgu — %+38
4. **Kitapçı Kadın** — Nanako Hanada (Doğan) — Çeviri — %+29
5. **Masumiyet Müzesi** — Orhan Pamuk (YKY) — Kurgu — %+22

#### En Hızlı Soğuyan 3 Kitap

1. "AI ile hayatınızı değiştirin" tipi popülist teknoloji kitapları — %-18 genel
2. Saf fantastik macera (web novel dışı) — %-14
3. True crime / seri katil niş — %-12

#### Dikkat Çeken Sinyal

**Yayınevi gürültüsü uyarısı:** Yordam Kitap'ın **Newton'ın Principia'sının Toplumsal ve İktisadi Kökleri** eserinde X'te 860+ like alındı ama organik okur paylaşımı çok düşük (%95 yayıncı + influencer kaynaklı). Satışa yansıması da minimal. Bu kitap "henüz trend değil" kategorisinde, ayrı akademik endekste izleniyor.

**Erken sinyal:** Taiwan Travelogue — Yáng Shuāng-zǐ için 19 Mayıs Booker ödül töreni öncesi çeviri hakları BKM Kitap kataloğuna girdi. Türkçe baskı henüz yok ama arama hacmi hafta içinde iki katına çıktı. Erken sipariş sayfası bu cuma açılıyor.

#### Önümüzdeki Hafta

14-20 Nisan penceresinde takip edeceğimiz üç olay: **Annem Şefika** (Nuriye Ortaylı) 23 Nisan öncesi ulusal hafıza teması ile yükselebilir; **Gökyüzünde Nehirler Var** (Elif Şafak) dünya lansman turu etkisi; **Enemies-to-Lovers & Anlaşmalı Evlilik Seçkisi** BKM Kitap koleksiyon sayfası açılışı — X'teki okur talep flood'unu platforma taşıyacak ilk deneme.

#### Metodoloji

Baz dönem 06-12 Ocak 2026. Endeks = 100. 13 haftalık hareketli ortalama uygulanır. Yedi kategoride ayrı endeks hesaplanır. Tam metodoloji: trend.bkmkitap.com/metodoloji

---

## 15. DOKÜMAN SONU NOTLARI

Bu doküman canlı — her metodoloji değişiminde versiyonlanır, eski versiyon arşivde kalır. İlk gerçek yayın tarihi, pilot hafta 4 kararına göre belirlenir.

**Sonraki adım önerileri:**

1. `analytics` şemasını geliştirme veritabanında oluştur, DDL'leri çalıştır
2. 13 haftalık tarihsel ETL'i backtest amaçlı çalıştır, endeks serisi plausible mi gör
3. Grok + Claude ajan prompt'larını dondur (dokümanın 7. bölümünde iskelet var, tam metin ayrı dosya olacak)
4. Power BI iç yönetim panel ilk sürümünü yap (beş sayfa)
5. Editör checklist'ini operasyonel forma çevir (Google Form veya Notion)
6. trend.bkmkitap.com subdomain + metodoloji sayfası hazırla
7. Basın listesi çıkar — 50 gazeteci/blogger, e-posta + ilgi alanı segmentasyonu
8. Yönetim toplantısına bu dokümanı sun, bütçe ve ekip onayı al

**Bitti.**
