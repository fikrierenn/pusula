-- ============================================================
-- Mayıs 2026 — %50 Tüm Kitaplar İndirim Kampanyası Tahmin Tablosu
-- ============================================================
-- HEDEF: Apr26 satış hızını baz alıp Mayıs %50 indirim adet/ciro tahmini
-- TABLO: DerinSISBkm.bkm.MayKampanyaTahmin_2026
-- BAZ DÖNEM: 01.04.2026 - 26.04.2026 (Nisan ay-içi, ay tamamlanmamış)
-- ÜST FİYAT: bkm.urunbilgi.SatisFiyat (DerinSIS güncel kart fiyatı)
-- ELASTİKİYET SENARYOLARI:
--   Senaryo 1 (Muhafazakar):  adet × 1.5
--   Senaryo 2 (Orta - öneri):  adet × 2.0
--   Senaryo 3 (Agresif):       adet × 2.5
-- BRÜT CİRO  = TahminAdet × UstFiyat   (indirimsiz)
-- NET CİRO   = BrütCiro × 0.50         (Mayıs %50 indirim sonrası kasa)
-- KAPSAM: Tüm kitap satışları (kampanyalı dahil — 3Al2Öde dahil), iade negatif sign
-- KATEGORİ: urunbilgi.Kategori3 IN ('Kitap','Hazırlık Kitapları','Çocuk Kitabı','Akademi')
-- MAĞAZA: 1=İst.Yolu, 2=FSM, 3=Özlüce
-- ============================================================
-- ÇALIŞTIRMA: SSMS'te tüm script'i seçip F5. Tek seferde 4 adım çalışır:
--   1. Tabloyu (varsa) düşür
--   2. Yarat
--   3. Doldur (Apr26 satışlarını + senaryoları hesapla)
--   4. Doğrulama sorguları
-- ============================================================

USE DerinSISBkm;
GO

-- ---------- 1) ESKİ TABLOYU DÜŞÜR ----------
IF OBJECT_ID('bkm.MayKampanyaTahmin_2026', 'U') IS NOT NULL
    DROP TABLE bkm.MayKampanyaTahmin_2026;
GO

-- ---------- 2) TABLO YAPISI ----------
CREATE TABLE bkm.MayKampanyaTahmin_2026 (
    ProductsId          int             NOT NULL,
    stkID               int             NOT NULL,
    UrunKod             nvarchar(100)   NULL,
    UrunAd              nvarchar(200)   NULL,
    Yayinevi            nvarchar(200)   NULL,
    Yazar               nvarchar(200)   NULL,
    Kategori3           nvarchar(200)   NULL,
    KatAna              nvarchar(200)   NULL,
    Kat1                nvarchar(200)   NULL,

    -- Apr26 satış adetleri (mağaza bazında)
    IstYolu_Adet        decimal(18, 0)  NOT NULL DEFAULT 0,
    FSM_Adet            decimal(18, 0)  NOT NULL DEFAULT 0,
    Ozluce_Adet         decimal(18, 0)  NOT NULL DEFAULT 0,
    Toplam_Adet         decimal(18, 0)  NOT NULL DEFAULT 0,

    -- Fiyat & baz ciro
    UstFiyat            decimal(18, 2)  NOT NULL DEFAULT 0,
    Apr26_BrutCiroBaz   decimal(18, 2)  NOT NULL DEFAULT 0,    -- Toplam_Adet × UstFiyat (Apr26 baz hizı, indirimsiz)

    -- Senaryo 1: Muhafazakar (1.5x adet)
    Sen1_Adet           decimal(18, 0)  NOT NULL DEFAULT 0,
    Sen1_BrutCiro       decimal(18, 2)  NOT NULL DEFAULT 0,
    Sen1_NetCiro        decimal(18, 2)  NOT NULL DEFAULT 0,

    -- Senaryo 2: Orta - önerilen (2.0x adet)
    Sen2_Adet           decimal(18, 0)  NOT NULL DEFAULT 0,
    Sen2_BrutCiro       decimal(18, 2)  NOT NULL DEFAULT 0,
    Sen2_NetCiro        decimal(18, 2)  NOT NULL DEFAULT 0,

    -- Senaryo 3: Agresif (2.5x adet)
    Sen3_Adet           decimal(18, 0)  NOT NULL DEFAULT 0,
    Sen3_BrutCiro       decimal(18, 2)  NOT NULL DEFAULT 0,
    Sen3_NetCiro        decimal(18, 2)  NOT NULL DEFAULT 0,

    -- Bayraklar
    LongTail            bit             NOT NULL DEFAULT 0,    -- Toplam_Adet 1-2 (uzun kuyruk, tahmin güvensiz)
    UstFiyatYok         bit             NOT NULL DEFAULT 0,    -- urunbilgi.SatisFiyat 0/NULL

    IslenmeTarihi       datetime        NOT NULL DEFAULT GETDATE(),

    CONSTRAINT PK_MayKampanyaTahmin_2026 PRIMARY KEY (ProductsId)
);
GO

CREATE INDEX IX_MayKampanyaTahmin_ToplamAdet ON bkm.MayKampanyaTahmin_2026 (Toplam_Adet DESC) INCLUDE (UstFiyat, Sen2_NetCiro);
CREATE INDEX IX_MayKampanyaTahmin_Kategori   ON bkm.MayKampanyaTahmin_2026 (Kategori3, KatAna);
CREATE INDEX IX_MayKampanyaTahmin_Yayinevi   ON bkm.MayKampanyaTahmin_2026 (Yayinevi);
GO

-- ---------- 3) DOLDUR ----------
;WITH kitap AS (
    -- Apr26 dönemindeki tüm kitap kategorisindeki ürünler
    SELECT b.ProductsId, MIN(br.urnBrkdStkID) AS stkID
    FROM EncoreMerkez.dbo.Barcodes b
    INNER JOIN DerinSISBkm.dbo.urnBrkd br
        ON b.BarcodeNo COLLATE Turkish_CI_AS = br.urnBarkod COLLATE Turkish_CI_AS
    INNER JOIN DerinSISBkm.bkm.urunbilgi u ON br.urnBrkdStkID = u.stkID
    WHERE u.Kategori3 IN ('Kitap', N'Hazırlık Kitapları', N'Çocuk Kitabı', 'Akademi')
    GROUP BY b.ProductsId
),
satis AS (
    SELECT
        sp.ProductsId,
        SUM(CASE WHEN s.StoresId=1 THEN (CASE WHEN s.DocumentsTypeId=3 THEN -sp.Amount ELSE sp.Amount END) ELSE 0 END) AS IstYolu_Adet,
        SUM(CASE WHEN s.StoresId=2 THEN (CASE WHEN s.DocumentsTypeId=3 THEN -sp.Amount ELSE sp.Amount END) ELSE 0 END) AS FSM_Adet,
        SUM(CASE WHEN s.StoresId=3 THEN (CASE WHEN s.DocumentsTypeId=3 THEN -sp.Amount ELSE sp.Amount END) ELSE 0 END) AS Ozluce_Adet,
        SUM(CASE WHEN s.DocumentsTypeId=3 THEN -sp.Amount ELSE sp.Amount END) AS Toplam_Adet
    FROM EncoreMerkez.dbo.Sales s
    INNER JOIN EncoreMerkez.dbo.SalesProducts sp ON sp.SalesId = s.Id AND sp.IsValid = 1
    INNER JOIN kitap k ON k.ProductsId = sp.ProductsId
    WHERE s.DocumentsTypeId IN (1, 2, 3, 6, 7, 8)
      AND s.Date >= CONVERT(date, '01.04.2026', 104)
      AND s.Date <  CONVERT(date, '27.04.2026', 104)
    GROUP BY sp.ProductsId
)
INSERT INTO bkm.MayKampanyaTahmin_2026 (
    ProductsId, stkID,
    UrunKod, UrunAd, Yayinevi, Yazar, Kategori3, KatAna, Kat1,
    IstYolu_Adet, FSM_Adet, Ozluce_Adet, Toplam_Adet,
    UstFiyat, Apr26_BrutCiroBaz,
    Sen1_Adet, Sen1_BrutCiro, Sen1_NetCiro,
    Sen2_Adet, Sen2_BrutCiro, Sen2_NetCiro,
    Sen3_Adet, Sen3_BrutCiro, Sen3_NetCiro,
    LongTail, UstFiyatYok
)
SELECT
    sat.ProductsId,
    k.stkID,
    p.Code,
    p.Name,
    ISNULL(ub.mrkAd, '')        AS Yayinevi,
    ISNULL(ub.Yazar, '')        AS Yazar,
    ub.Kategori3,
    ISNULL(ub.KatAna, '')       AS KatAna,
    ISNULL(ub.Kat1, '')         AS Kat1,

    CAST(sat.IstYolu_Adet AS decimal(18,0)),
    CAST(sat.FSM_Adet AS decimal(18,0)),
    CAST(sat.Ozluce_Adet AS decimal(18,0)),
    CAST(sat.Toplam_Adet AS decimal(18,0)),

    CAST(ISNULL(ub.SatisFiyat, 0) AS decimal(18,2)) AS UstFiyat,
    CAST(sat.Toplam_Adet * ISNULL(ub.SatisFiyat, 0) AS decimal(18,2)) AS Apr26_BrutCiroBaz,

    -- Senaryo 1: Muhafazakar (1.5x adet)
    CAST(sat.Toplam_Adet * 1.5 AS decimal(18,0))                                            AS Sen1_Adet,
    CAST(sat.Toplam_Adet * 1.5 * ISNULL(ub.SatisFiyat, 0) AS decimal(18,2))                 AS Sen1_BrutCiro,
    CAST(sat.Toplam_Adet * 1.5 * ISNULL(ub.SatisFiyat, 0) * 0.5 AS decimal(18,2))           AS Sen1_NetCiro,

    -- Senaryo 2: Orta (2.0x adet) — ÖNERİLEN
    CAST(sat.Toplam_Adet * 2.0 AS decimal(18,0))                                            AS Sen2_Adet,
    CAST(sat.Toplam_Adet * 2.0 * ISNULL(ub.SatisFiyat, 0) AS decimal(18,2))                 AS Sen2_BrutCiro,
    CAST(sat.Toplam_Adet * 2.0 * ISNULL(ub.SatisFiyat, 0) * 0.5 AS decimal(18,2))           AS Sen2_NetCiro,

    -- Senaryo 3: Agresif (2.5x adet)
    CAST(sat.Toplam_Adet * 2.5 AS decimal(18,0))                                            AS Sen3_Adet,
    CAST(sat.Toplam_Adet * 2.5 * ISNULL(ub.SatisFiyat, 0) AS decimal(18,2))                 AS Sen3_BrutCiro,
    CAST(sat.Toplam_Adet * 2.5 * ISNULL(ub.SatisFiyat, 0) * 0.5 AS decimal(18,2))           AS Sen3_NetCiro,

    -- Bayraklar
    CASE WHEN sat.Toplam_Adet BETWEEN 1 AND 2 THEN 1 ELSE 0 END AS LongTail,
    CASE WHEN ISNULL(ub.SatisFiyat, 0) <= 0 THEN 1 ELSE 0 END   AS UstFiyatYok
FROM satis sat
INNER JOIN kitap k ON k.ProductsId = sat.ProductsId
INNER JOIN EncoreMerkez.dbo.Products p ON p.Id = sat.ProductsId
LEFT JOIN DerinSISBkm.bkm.urunbilgi ub ON ub.stkID = k.stkID
WHERE sat.Toplam_Adet > 0;
GO

-- ---------- 4) DOĞRULAMA SORGULARI ----------

-- 4a. Genel özet
SELECT
    'Toplam ürün satırı'                AS Metrik, COUNT(*)                                     AS Deger FROM bkm.MayKampanyaTahmin_2026
UNION ALL SELECT 'Toplam Apr26 adet',         CAST(SUM(Toplam_Adet) AS bigint)         FROM bkm.MayKampanyaTahmin_2026
UNION ALL SELECT 'Toplam Apr26 brüt ciro',    CAST(SUM(Apr26_BrutCiroBaz) AS bigint)   FROM bkm.MayKampanyaTahmin_2026
UNION ALL SELECT 'Sen2 (Orta) toplam adet',   CAST(SUM(Sen2_Adet) AS bigint)           FROM bkm.MayKampanyaTahmin_2026
UNION ALL SELECT 'Sen2 (Orta) brüt ciro',     CAST(SUM(Sen2_BrutCiro) AS bigint)       FROM bkm.MayKampanyaTahmin_2026
UNION ALL SELECT 'Sen2 (Orta) NET ciro %50',  CAST(SUM(Sen2_NetCiro) AS bigint)        FROM bkm.MayKampanyaTahmin_2026
UNION ALL SELECT 'Long tail (1-2 adet) ürün', COUNT(*)                                 FROM bkm.MayKampanyaTahmin_2026 WHERE LongTail = 1
UNION ALL SELECT 'Üst fiyatı 0/yok',          COUNT(*)                                 FROM bkm.MayKampanyaTahmin_2026 WHERE UstFiyatYok = 1;

-- 4b. Senaryo karşılaştırması (3 mağaza ayrı + toplam)
SELECT
    'IST YOLU' AS Magaza,
    CAST(SUM(IstYolu_Adet) AS bigint)               AS Apr26_Adet,
    CAST(SUM(IstYolu_Adet * UstFiyat) AS bigint)    AS Apr26_BrutCiro,
    CAST(SUM(IstYolu_Adet * 1.5) AS bigint)         AS Sen1_Adet,
    CAST(SUM(IstYolu_Adet * 1.5 * UstFiyat * 0.5) AS bigint) AS Sen1_NetCiro,
    CAST(SUM(IstYolu_Adet * 2.0) AS bigint)         AS Sen2_Adet,
    CAST(SUM(IstYolu_Adet * 2.0 * UstFiyat * 0.5) AS bigint) AS Sen2_NetCiro,
    CAST(SUM(IstYolu_Adet * 2.5) AS bigint)         AS Sen3_Adet,
    CAST(SUM(IstYolu_Adet * 2.5 * UstFiyat * 0.5) AS bigint) AS Sen3_NetCiro
FROM bkm.MayKampanyaTahmin_2026
UNION ALL
SELECT
    'FSM',
    CAST(SUM(FSM_Adet) AS bigint),
    CAST(SUM(FSM_Adet * UstFiyat) AS bigint),
    CAST(SUM(FSM_Adet * 1.5) AS bigint),
    CAST(SUM(FSM_Adet * 1.5 * UstFiyat * 0.5) AS bigint),
    CAST(SUM(FSM_Adet * 2.0) AS bigint),
    CAST(SUM(FSM_Adet * 2.0 * UstFiyat * 0.5) AS bigint),
    CAST(SUM(FSM_Adet * 2.5) AS bigint),
    CAST(SUM(FSM_Adet * 2.5 * UstFiyat * 0.5) AS bigint)
FROM bkm.MayKampanyaTahmin_2026
UNION ALL
SELECT
    'OZLUCE',
    CAST(SUM(Ozluce_Adet) AS bigint),
    CAST(SUM(Ozluce_Adet * UstFiyat) AS bigint),
    CAST(SUM(Ozluce_Adet * 1.5) AS bigint),
    CAST(SUM(Ozluce_Adet * 1.5 * UstFiyat * 0.5) AS bigint),
    CAST(SUM(Ozluce_Adet * 2.0) AS bigint),
    CAST(SUM(Ozluce_Adet * 2.0 * UstFiyat * 0.5) AS bigint),
    CAST(SUM(Ozluce_Adet * 2.5) AS bigint),
    CAST(SUM(Ozluce_Adet * 2.5 * UstFiyat * 0.5) AS bigint)
FROM bkm.MayKampanyaTahmin_2026
UNION ALL
SELECT
    'TOPLAM (3 mağaza)',
    CAST(SUM(Toplam_Adet) AS bigint),
    CAST(SUM(Apr26_BrutCiroBaz) AS bigint),
    CAST(SUM(Sen1_Adet) AS bigint),
    CAST(SUM(Sen1_NetCiro) AS bigint),
    CAST(SUM(Sen2_Adet) AS bigint),
    CAST(SUM(Sen2_NetCiro) AS bigint),
    CAST(SUM(Sen3_Adet) AS bigint),
    CAST(SUM(Sen3_NetCiro) AS bigint)
FROM bkm.MayKampanyaTahmin_2026;

-- 4c. Top 20 ciroya en çok katkı (Sen2 Orta senaryo bazında)
SELECT TOP 20
    UrunKod, UrunAd, Yayinevi, Kat1,
    Toplam_Adet AS Apr26_Adet,
    UstFiyat,
    Sen2_Adet,
    Sen2_NetCiro
FROM bkm.MayKampanyaTahmin_2026
ORDER BY Sen2_NetCiro DESC;

-- 4d. Kategori bazlı (KatAna) özet
SELECT
    KatAna,
    COUNT(*) AS UrunSayisi,
    CAST(SUM(Toplam_Adet) AS bigint)        AS Apr26_Adet,
    CAST(SUM(Apr26_BrutCiroBaz) AS bigint)  AS Apr26_BrutCiro,
    CAST(SUM(Sen2_NetCiro) AS bigint)       AS Sen2_NetCiro_May
FROM bkm.MayKampanyaTahmin_2026
GROUP BY KatAna
ORDER BY Apr26_BrutCiro DESC;
GO

-- ============================================================
-- BAŞARILIYSA: bana "tablo hazır" de, tablodan SELECT'lerle Excel + brifing üreteyim.
-- Ya bu satırı kullan: 'mayis kampanyasi tablosu hazir' demem yeterli.
-- ============================================================
