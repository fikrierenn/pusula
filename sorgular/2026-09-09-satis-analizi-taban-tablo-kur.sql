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

        -- ÜRÜN AĞACI — iki seviye daha (14.09.2026, GMY: "defter grubuna nasıl ulaşacağım").
        -- ⚠ `Kategori1` ADI YANILTICI: o aslında `UrunBilgi.KatAna`dır ve Kırtasiye'nin
        -- 52.021 çeşidinin HEPSİNDE yine "Kırtasiye" yazar — alt kırılım vermez.
        -- Gerçek ağaç `KatAna → Kat1 → Kat2`; defter burada: Kat1='Defterler' ·
        -- Kat2='Çizgili Defter'. ÖLÇÜLDÜ 14.09.2026 (837.990 ürün master):
        --   Kat1 dolu %88,2 (tabanda %90,9) · 553 ayrı değer   → FİLTRE OLUR
        --   Kat2 dolu %21,9 (tabanda %29,3) · 568 ayrı değer   → kolon olur, filtre zayıf
        --   Kat3 dolu  %8,7 · 324 ayrı değer                    → alındı (GMY: "kaç kat varsa")
        --   Kat4 dolu  %5,7 · 597 ayrı değer                    → alındı
        --   Kat5 dolu  %0,0 · TEK değer                         → ALINMADI (pratikte boş)
        -- Derin yol gerçek: "Eğitim - Sınavlara Hazırlık → Ortaokul Yardımcı → 8.Sınıf →
        -- Soru → Matematik" (392 çeşit). Seyreklik ürünün eksikliği değil, ağacın dengesizliği:
        -- kırtasiye 2 basamakta biter, sınav hazırlık 5 basamağa iner.
        -- Defterler: 7.933 çeşit, 3.296'sı ölü stok adayı.
        -- ⚠ `ReyonAd` REYON DEĞİL: "Kampanya Dışı / %50 İNDİRİM…" taşıyor (kod4=KAMPANYA).
        Kat1         nvarchar(60)  NULL,
        Kat2         nvarchar(60)  NULL,
        Kat3         nvarchar(60)  NULL,
        Kat4         nvarchar(60)  NULL,
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

/* ────────────────────────────────────────────────────────────────────────────
   09.09.2026 — MERKEZ DEPO ÇIKIŞI (ürün bazında, 365 gün)

   NEDEN: gün-stok KAPSAM ASİMETRİSİ taşıyordu (kurul bulgusu 09.09) — payda
   `ToplamStok` = mağaza + merkez, paydada satış = YALNIZ 3 mağaza. Merkezden
   yılda 1.895.799 adet çıkıyor (17.713 çeşit, ölçüldü) ve paydada yoktu →
   gün-stok sistematik olarak "stok yeter" yönünde sapıyordu.

   NEDEN E-TİCARET PAYDAYA EKLENMEDİ (kullanıcı, 09.09): "e-ticaret stoğu bizde
   değil ODAK tarafında". E-tic talebi ODAK'ın kendi stoğunu tüketir; bizim
   payımız ODAK'a yaptığımız SATIŞ olarak zaten merkez çıkışının içinde
   (frm 9525 ODAK Kitap-Point: 302.908 adet/yıl, ölçüldü).

   Merkez çıkışının karşı tarafı (ölçüldü, 365 gün):
     frm 56   Bursa Kültür Merkezi (GRUP ŞİRKETİ)  1.375.700  %72
     frm 9525 ODAK Kitap-Point (e-tic fulfillment)   302.908  %16
     frm 120  Sınav Basın Yayın                      110.100   %6
   → Merkez depo bir TOPTAN/GRUP DAĞITIM deposu. Çıkışı gerçek stok erimesidir
     ama TÜKETİCİ TALEBİ DEĞİLDİR → mağaza hızıyla KARIŞTIRILMAZ, ayrı ölçülür.

   ⚠ Kaynak ERP defteri (mekan 12). Merkez STOĞU için defter YASAK (negatifli,
   sql-server-conventions § MERKEZ DEPO STOĞU) ama ÇIKIŞ HAREKETİ için defter
   tek kaynak — WMS hareket geçmişi tutmuyor. Stok=WMS, hareket=defter.
   ──────────────────────────────────────────────────────────────────────────── */
IF COL_LENGTH('bkm.SatisAnaliziTaban', 'MerkezCikis') IS NULL
    ALTER TABLE bkm.SatisAnaliziTaban ADD MerkezCikis int NULL;
GO

/* ────────────────────────────────────────────────────────────────────────────
   09.09.2026 — MERKEZ ÇIKIŞI KAÇ AYRI GÜNDE OLDU

   NEDEN: kullanıcı uyarısı "merkez çıkış spontane". ÖLÇÜLDÜ ve doğrulandı —
   merkez çıkışı bir HIZ DEĞİL, SIÇRAMA:
     17.713 çeşidin 11.855'i (%67) TEK GÜNDE çıkmış · 5.335'i 2-5 günde ·
     522'si 6-30 günde · yalnız 1 ürün 30 günden fazla.
     Çıkışın ortalama %82,7'si tek güne yığılmış; 15.569 çeşitte (%88)
     yarısından fazlası tek gün. Uç örnek: Sınav Basın Yayın 110.100 adet,
     TEK BELGE (04.06.2026).
   → "merkez gün-stoğu = stok / ortalama çıkış hızı" ANLAMSIZ, kaldırıldı.
     Onun yerine hacim + kaç günde olduğu + parti büyüklüğü gösterilir.
   ──────────────────────────────────────────────────────────────────────────── */
IF COL_LENGTH('bkm.SatisAnaliziTaban', 'MerkezCikisGun') IS NULL
    ALTER TABLE bkm.SatisAnaliziTaban ADD MerkezCikisGun int NULL;
GO

/* ────────────────────────────────────────────────────────────────────────────
   10.09.2026 — GERÇEKLEŞEN MARJ İÇİN BEŞ KOLON (satinalma-danisman kurulu #2)

   NEDEN: panelin en büyük sayısı (stok değeri) ETİKET fiyatıyla hesaplanıyordu
   ve marj yalnız DRILL'de vardı. ÖLÇÜLDÜ 09.09 (90 gün, POS, panel evreni):
   POS brütü kart fiyatına eşit (%95,4-99,5 → urn.fiyatS gerçekten raf fiyatı)
   ama gerçekleşen NET çok altında — Kitap %71,1 · Çocuk Kitabı %72,3 ·
   Elektronik %77,3 · Kırtasiye %80,3 · Oyuncak %88,6 · Dergi %98,0.
   Etiketle 1.022,2M ₺ · kategori oranlarıyla 807,3M ₺ → 214,9M ₺ (%21,03) şişme.
   Kurul kararı: "gerçekleşen marj panelin eksik olan ASIL ekseni" (madde #2).

   MALİYET NEDEN TABANDA: drill tek ürün için bkm.UrunMaliyet çağırıyor; 275K
   ürün için satır-başı UDF timeout demek (sql-server-conventions § TVF'i
   korelasyonlu alt-sorguda çağırma). Set-bazlı ön-hesap ölçüldü: 9,1 s /
   433.682 çeşit. POS agregası 3,0 s / 154.225 çeşit. Kurulum 31-45 s → ~55 s.

   TANIM (drill ile AYNI olmalı — emitter-ayrimi):
     BirimMaliyet = son 5 ALIŞ faturasının ağırlıklı birimi, KDV HARİÇ
                    (fat.eTip=0, eDurum<>2; fatura bazında topla-böl)
     PosAdet/PosNet/PosKdv/PosBrut = 365 gün POS, iade (DocumentsTypeId=3)
                    HARİÇ — ortalama fiyat sorusunda iade satırı fiyatı bozar.
                    Köprü Products.Code = stkID (barkod DEĞİL).
   ⚠ PosNet KDV DAHİL (TotalPrice), PosKdv ayrı → KDV-hariç birim =
     (PosNet − PosKdv) / PosAdet. Maliyetle aynı tabana ancak böyle gelir.
   ──────────────────────────────────────────────────────────────────────────── */
IF COL_LENGTH('bkm.SatisAnaliziTaban', 'BirimMaliyet') IS NULL
    ALTER TABLE bkm.SatisAnaliziTaban ADD BirimMaliyet decimal(18,4) NULL;
GO
IF COL_LENGTH('bkm.SatisAnaliziTaban', 'PosAdet') IS NULL
    ALTER TABLE bkm.SatisAnaliziTaban ADD PosAdet int NULL;
GO
IF COL_LENGTH('bkm.SatisAnaliziTaban', 'PosNet') IS NULL
    ALTER TABLE bkm.SatisAnaliziTaban ADD PosNet decimal(18,2) NULL;
GO
IF COL_LENGTH('bkm.SatisAnaliziTaban', 'PosKdv') IS NULL
    ALTER TABLE bkm.SatisAnaliziTaban ADD PosKdv decimal(18,2) NULL;
GO
IF COL_LENGTH('bkm.SatisAnaliziTaban', 'PosBrut') IS NULL
    ALTER TABLE bkm.SatisAnaliziTaban ADD PosBrut decimal(18,2) NULL;
GO

/* ────────────────────────────────────────────────────────────────────────────
   10.09.2026 — SON SATIŞ TARİHİ (kullanıcı isteği)

   Kullanıcı: "hareketsiz stokta sanki son satış tarihi gibi bir bilgi de lazım".

   NEDEN TABANDA VE NEDEN PENCERESİZ: "hareketsiz" tanımı 365 günde satış YOK
   demek — yani son satış, tanımı gereği pencerenin DIŞINDA. `SatisToplam` bu
   soruyu cevaplayamaz (o hep 0). Ve iki durum AYRI problemdir:
     · hiç satılmamış      → alım hatası (yanlış ürün alındı)
     · satıyordu, durdu    → talep kaybı (ne zaman durdu, neden)
   NULL = hiç satılmamış. 0 ya da bir tarih UYDURULMAZ.

   Kapsam `SatisToplam` ile AYNI: ehTip IN (1,4,100), mekan 1/4477/4478, çıkış.
   Merkez çıkışı DAHİL DEĞİL — tüketici talebi değil (%72'si grup şirketine).
   ÖLÇÜLDÜ: 3,1 s / 315.607 çeşit · en eski 01.06.2021 · en yeni 09.09.2026.
   ──────────────────────────────────────────────────────────────────────────── */
IF COL_LENGTH('bkm.SatisAnaliziTaban', 'SonSatis') IS NULL
    ALTER TABLE bkm.SatisAnaliziTaban ADD SonSatis datetime NULL;
GO

/* ── 10.09.2026 — MAĞAZA BAZLI SEZON SATIŞI ─────────────────────────────────────
   "Sezonluk Raf Açığı" kartı için: geçen sezon BU mağazada sattı mı? Ay1/Ay2/Ay3 üç
   mağazanın TOPLAMI olduğu için bu soruyu cevaplayamıyordu — kohortun 337/389'unda
   başka mağazada stok var, toplamla bakınca raf boşluğu kayboluyordu.
   İlgili: sorgular/2026-09-10-acik-siparis-etip-ve-sezon-raf-acigi.sql blok 2 */
IF COL_LENGTH('bkm.SatisAnaliziTaban', 'SezonFsm') IS NULL
    ALTER TABLE bkm.SatisAnaliziTaban ADD SezonFsm int NULL;
IF COL_LENGTH('bkm.SatisAnaliziTaban', 'SezonOzl') IS NULL
    ALTER TABLE bkm.SatisAnaliziTaban ADD SezonOzl int NULL;
IF COL_LENGTH('bkm.SatisAnaliziTaban', 'SezonIst') IS NULL
    ALTER TABLE bkm.SatisAnaliziTaban ADD SezonIst int NULL;
GO

/* ── 10.09.2026 — MALİYETİN TARİHİ (denetim bulgusu B11) ────────────────────────
   Birim maliyet tarih penceresi olmadan "son 5 alış faturası"ndan gelir = BUGÜNKÜ
   maliyet; payı olan POS satışı ise 365 GÜNLÜK. Enflasyonda marj olduğundan düşük
   görünür. Tarih tabanda olmadığı için sapma ÖLÇÜLEMİYORDU. */
IF COL_LENGTH('bkm.SatisAnaliziTaban', 'MaliyetTarih') IS NULL
    ALTER TABLE bkm.SatisAnaliziTaban ADD MaliyetTarih datetime NULL;
GO

/* ── 10.09.2026 — TALEP DESENİ (Syntetos-Boylan-Croston) ────────────────────────
   Ölçüldü: çeşitlerin %91,9'unda talep ARALIKLI → "gün-stok" orada yanıltıcı.
   Ham iki girdi saklanır; SINIF kodda hesaplanır (eşikler ADI 1,32 · CV² 0,49
   YAYINLANMIŞ, veriden türetilmedi). SatanAy = son 12 tam ayda satış olan ay sayısı;
   ADI = 12 / SatanAy. TalepCV2 = sıfır-olmayan aylık talep büyüklüklerinin kareli
   değişim katsayısı. */
IF COL_LENGTH('bkm.SatisAnaliziTaban', 'SatanAy') IS NULL
    ALTER TABLE bkm.SatisAnaliziTaban ADD SatanAy int NULL;
IF COL_LENGTH('bkm.SatisAnaliziTaban', 'TalepCV2') IS NULL
    ALTER TABLE bkm.SatisAnaliziTaban ADD TalepCV2 decimal(10,3) NULL;
GO
