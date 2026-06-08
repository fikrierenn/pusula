-- ============================================================
-- FSM Trafik & Dönüşüm Analiz Sorguları — 28 Nis 2026
-- ============================================================
-- Kapı sayıcı verisi MANUEL (henüz tabloda değil).
-- Bu sorgular EncoreMerkez Sales tarafını çeker; sayıcı sayıları
-- (Giriş) Excel/manuel ile eşleştirilir.
--
-- Kurallar:
-- - Tarih DMY: dd.MM.yyyy / CONVERT(..., 104)
-- - DocumentsTypeId IN (1,2,6,7,8) = pozitif satış, 3 = İade (sign'lı)
-- - Net = (GrossTotal - DiscountTotal) [normal] - (GrossTotal - DiscountTotal) [iade]
-- - Sales.LineCount kullanıyoruz (CROSS APPLY pattern istenmedi — bu seviye yeterli)
-- - Stores: 1 = İST YOLU, 2 = FSM, 3 = ÖZLÜCE
-- ============================================================


-- ----------------------------------------------------------------
-- 1) FSM GÜNLÜK DETAY — sayıcı eşleştirme için
-- Brief'te kullanılan ana sorgu. Tek mağaza, tarih aralığı parametrik.
-- ----------------------------------------------------------------
SELECT
    CONVERT(varchar, Date, 104) AS Tarih,
    DATENAME(WEEKDAY, Date) AS Gun,
    SUM(CASE WHEN DocumentsTypeId IN (1,2,6,7,8) THEN GrossTotal - DiscountTotal ELSE 0 END)
        - SUM(CASE WHEN DocumentsTypeId = 3 THEN GrossTotal - DiscountTotal ELSE 0 END) AS NetCiro,
    SUM(CASE WHEN DocumentsTypeId IN (1,2,6,7,8) THEN 1 ELSE 0 END) AS Fis,
    SUM(CASE WHEN DocumentsTypeId IN (1,2,6,7,8) THEN LineCount ELSE 0 END) AS Urun
FROM EncoreMerkez.dbo.Sales
WHERE Date >= CONVERT(datetime, '08.04.2026', 104)
  AND Date <  CONVERT(datetime, '29.04.2026', 104)
  AND DocumentsTypeId IN (1, 2, 3, 6, 7, 8)
  AND StoresId = 2  -- FSM
GROUP BY CONVERT(varchar, Date, 104), DATENAME(WEEKDAY, Date);


-- ----------------------------------------------------------------
-- 2) 3 MAĞAZA HAFTALIK ÖZET — H17 (20-26 Nis) örneği
-- Brief'in "Fiziksel Mağaza" tablosu için.
-- ----------------------------------------------------------------
SELECT
    StoresId,
    CASE StoresId WHEN 1 THEN 'IST YOLU' WHEN 2 THEN 'FSM' WHEN 3 THEN 'OZLUCE' END AS Magaza,
    SUM(CASE WHEN DocumentsTypeId IN (1,2,6,7,8) THEN GrossTotal - DiscountTotal ELSE 0 END) AS Brut,
    SUM(CASE WHEN DocumentsTypeId = 3 THEN GrossTotal - DiscountTotal ELSE 0 END) AS Iade,
    SUM(CASE WHEN DocumentsTypeId IN (1,2,6,7,8) THEN GrossTotal - DiscountTotal ELSE 0 END)
        - SUM(CASE WHEN DocumentsTypeId = 3 THEN GrossTotal - DiscountTotal ELSE 0 END) AS Net,
    SUM(CASE WHEN DocumentsTypeId IN (1,2,6,7,8) THEN DiscountTotal ELSE 0 END) AS Indirim,
    SUM(CASE WHEN DocumentsTypeId IN (1,2,6,7,8) THEN 1 ELSE 0 END) AS Fis,
    SUM(CASE WHEN DocumentsTypeId IN (1,2,6,7,8) THEN LineCount ELSE 0 END) AS Urun
FROM EncoreMerkez.dbo.Sales
WHERE Date >= CONVERT(datetime, '20.04.2026', 104)
  AND Date <  CONVERT(datetime, '27.04.2026', 104)
  AND DocumentsTypeId IN (1, 2, 3, 6, 7, 8)
GROUP BY StoresId;


-- ----------------------------------------------------------------
-- 3) ÇOKLU DÖNEM (H17 + H16 + MTD) tek sorguda
-- Brief'in WoW + MTD karşılaştırma için. UNION ALL yapısı.
-- ----------------------------------------------------------------
SELECT 'H17' AS Donem, StoresId,
    SUM(CASE WHEN DocumentsTypeId IN (1,2,6,7,8) THEN GrossTotal - DiscountTotal ELSE 0 END)
        - SUM(CASE WHEN DocumentsTypeId = 3 THEN GrossTotal - DiscountTotal ELSE 0 END) AS Net,
    SUM(CASE WHEN DocumentsTypeId IN (1,2,6,7,8) THEN 1 ELSE 0 END) AS Fis,
    SUM(CASE WHEN DocumentsTypeId IN (1,2,6,7,8) THEN LineCount ELSE 0 END) AS Urun
FROM EncoreMerkez.dbo.Sales
WHERE Date >= CONVERT(datetime, '20.04.2026', 104) AND Date < CONVERT(datetime, '27.04.2026', 104)
  AND DocumentsTypeId IN (1, 2, 3, 6, 7, 8)
GROUP BY StoresId

UNION ALL
SELECT 'H16', StoresId,
    SUM(CASE WHEN DocumentsTypeId IN (1,2,6,7,8) THEN GrossTotal - DiscountTotal ELSE 0 END)
        - SUM(CASE WHEN DocumentsTypeId = 3 THEN GrossTotal - DiscountTotal ELSE 0 END),
    SUM(CASE WHEN DocumentsTypeId IN (1,2,6,7,8) THEN 1 ELSE 0 END),
    SUM(CASE WHEN DocumentsTypeId IN (1,2,6,7,8) THEN LineCount ELSE 0 END)
FROM EncoreMerkez.dbo.Sales
WHERE Date >= CONVERT(datetime, '13.04.2026', 104) AND Date < CONVERT(datetime, '20.04.2026', 104)
  AND DocumentsTypeId IN (1, 2, 3, 6, 7, 8)
GROUP BY StoresId

UNION ALL
SELECT 'MTD', StoresId,
    SUM(CASE WHEN DocumentsTypeId IN (1,2,6,7,8) THEN GrossTotal - DiscountTotal ELSE 0 END)
        - SUM(CASE WHEN DocumentsTypeId = 3 THEN GrossTotal - DiscountTotal ELSE 0 END),
    SUM(CASE WHEN DocumentsTypeId IN (1,2,6,7,8) THEN 1 ELSE 0 END),
    SUM(CASE WHEN DocumentsTypeId IN (1,2,6,7,8) THEN LineCount ELSE 0 END)
FROM EncoreMerkez.dbo.Sales
WHERE Date >= CONVERT(datetime, '01.04.2026', 104) AND Date < CONVERT(datetime, '27.04.2026', 104)
  AND DocumentsTypeId IN (1, 2, 3, 6, 7, 8)
GROUP BY StoresId;


-- ----------------------------------------------------------------
-- 4) DÖNÜŞÜM HESABI — sayıcı verisi geldiğinde kullanılır
-- Excel'de manuel: NetCiro / Giriş = Kişi başı, Fiş / Giriş = Dönüşüm %
-- Sayıcı tabloya akarsa bu sorgu tablo ile JOIN'lanır.
--
-- Örnek (sayıcı sonradan tabloya akarsa):
-- SELECT
--     s.Tarih, s.NetCiro, s.Fis, t.GirisAdet,
--     CAST(s.Fis * 100.0 / NULLIF(t.GirisAdet, 0) AS decimal(5,2)) AS DonusumPct,
--     CAST(s.NetCiro / NULLIF(t.GirisAdet, 0) AS decimal(18,2)) AS KisiBasiCiro,
--     CAST(s.NetCiro / NULLIF(s.Fis, 0) AS decimal(18,2)) AS Sepet
-- FROM <yukarıdaki sorgu> s
-- LEFT JOIN bkm.MagazaTrafik t ON t.Tarih = s.Tarih AND t.StoresId = 2
-- ORDER BY s.Tarih;
--
-- Şimdilik manuel hesap (Excel sütun formülü):
--   Donusum %    = Fis / Giris
--   Kisi basi TL = NetCiro / Giris
--   Sepet TL     = NetCiro / Fis
--   Urun/giren   = Urun / Giris


-- ----------------------------------------------------------------
-- 5) GÜN-TİPİ KIRILIMI — hafta içi / Cuma / Cmt / Pzr
-- Sayıcı dahil edildiğinde dönüşüm pattern karşılaştırma.
-- ----------------------------------------------------------------
SELECT
    CASE
        WHEN DATENAME(WEEKDAY, Date) IN ('Saturday','Sunday') THEN 'HaftaSonu'
        WHEN DATENAME(WEEKDAY, Date) = 'Friday' THEN 'Cuma'
        ELSE 'HaftaIci'
    END AS GunTipi,
    StoresId,
    COUNT(DISTINCT CAST(Date AS date)) AS GunSayisi,
    SUM(CASE WHEN DocumentsTypeId IN (1,2,6,7,8) THEN GrossTotal - DiscountTotal ELSE 0 END)
        - SUM(CASE WHEN DocumentsTypeId = 3 THEN GrossTotal - DiscountTotal ELSE 0 END) AS NetCiro,
    SUM(CASE WHEN DocumentsTypeId IN (1,2,6,7,8) THEN 1 ELSE 0 END) AS Fis
FROM EncoreMerkez.dbo.Sales
WHERE Date >= CONVERT(datetime, '08.04.2026', 104)
  AND Date <  CONVERT(datetime, '29.04.2026', 104)
  AND DocumentsTypeId IN (1, 2, 3, 6, 7, 8)
GROUP BY
    CASE
        WHEN DATENAME(WEEKDAY, Date) IN ('Saturday','Sunday') THEN 'HaftaSonu'
        WHEN DATENAME(WEEKDAY, Date) = 'Friday' THEN 'Cuma'
        ELSE 'HaftaIci'
    END,
    StoresId;


-- ----------------------------------------------------------------
-- 6) SAYICI VERİSİ TABLO ŞEMASI (ileride lazım olduğunda)
-- Şu an manuel veri var, sistematize olmadı. İhtiyaç olunca uygula:
-- ----------------------------------------------------------------
/*
CREATE TABLE bkm.MagazaTrafik (
    Id          int IDENTITY PRIMARY KEY,
    Tarih       date NOT NULL,
    StoresId    int NOT NULL,         -- EncoreMerkez.Stores.Id ile eşleşir
    Saat        tinyint NULL,         -- 0-23 (saat bazlı veri varsa)
    GirisAdet   int NOT NULL,
    Kaynak      nvarchar(50) NOT NULL DEFAULT 'manuel',  -- 'csv-import' | 'api' | 'manuel'
    ImportAt    datetime NOT NULL DEFAULT GETDATE(),
    Notlar      nvarchar(500) NULL,
    CONSTRAINT UQ_MagazaTrafik UNIQUE (Tarih, StoresId, Saat)
);

CREATE INDEX IX_MagazaTrafik_StoresDate ON bkm.MagazaTrafik (StoresId, Tarih);

-- 8-28 Nis FSM verisi yükleme örneği:
-- INSERT INTO bkm.MagazaTrafik (Tarih, StoresId, GirisAdet, Kaynak)
-- VALUES
--   (CONVERT(date, '08.04.2026', 104), 2, 1598, 'manuel'),
--   (CONVERT(date, '09.04.2026', 104), 2, 1669, 'manuel'),
--   ...
*/


-- ----------------------------------------------------------------
-- 7) NOTLAR
-- ----------------------------------------------------------------
-- Veri kalitesi check'leri (manuel için):
--   - Future timestamp: Tarih > GETDATE() satırlar atla
--   - Anomali: GirisAdet < 50 olan günler flag (cihaz arızası şüphesi)
--   - Personel/iç giriş: cihaz açılış-kapanış saatleri dışı kayıtları ayrı not et
--
-- Stores mapping (EncoreMerkez.dbo.Stores):
--   1 = IST YOLU MGZ
--   2 = FSM Mağaza
--   3 = ÖZLÜCE
--
-- Brief.txt için kullanılan dönem etiketleri:
--   H17 = 20-26 Nis 2026 (Pazartesi başlangıçlı)
--   H16 = 13-19 Nis 2026
--   MTD = 01-26 Nis 2026 (ay başından bugüne)
