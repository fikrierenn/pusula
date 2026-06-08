-- =====================================================================
-- ABC ANALİZİ (Pareto 80/20) — ürün ciro yoğunlaşması
-- Amaç: Hangi az sayıda ürün cironun çoğunu yapıyor (A), hangi uzun kuyruk
--        ölü-stok/clearance adayı (C). Merchandising + reyon rasyonalizasyonu.
-- Veritabanı: EncoreMerkez (SalesProducts net satış)
-- Sınıf: A = kümülatif ciro ilk %80 · B = %80-95 · C = %95-100 (uzun kuyruk)
-- DOĞRULAMA (Mayıs 2026, 3 mağaza): A 13.141 ürün (SKU %25) → ciro %80 ·
--   B 18.360 → %15 · C 20.712 ürün (SKU %40) → ciro %5 (ölü kuyruk).
-- AKSİYON: C-sınıfı ∩ düşük sell-through (envanter-verim-devir-sellthrough.sql) = clearance listesi.
-- NOT: Window fonksiyon ağır (~7sn, 52K ürün). EncoreMerkez compat 110'da SUM() OVER() çalışır.
--      MCP-safe (CTE'siz derived table) — alttaki özet MCP'de de koşar.
-- =====================================================================
DECLARE @AyBas date = '20260501';
DECLARE @AySon date = '20260601';

-- ÖZET — A/B/C sınıf dağılımı
;WITH UrunCiro AS (
    SELECT sp.ProductsId, SUM(sp.TotalPrice) AS Ciro
    FROM EncoreMerkez.dbo.SalesProducts sp WITH(NOLOCK)
    JOIN EncoreMerkez.dbo.Sales s WITH(NOLOCK) ON s.Id = sp.SalesId
    WHERE sp.IsValid = 1 AND sp.BarcodeNo <> '1001'
      AND s.Date >= @AyBas AND s.Date < @AySon AND s.DocumentsTypeId IN (1,2,6,7,8)
    GROUP BY sp.ProductsId
    HAVING SUM(sp.TotalPrice) > 0
),
Kumulatif AS (
    SELECT ProductsId, Ciro,
        100.0 * SUM(Ciro) OVER (ORDER BY Ciro DESC ROWS UNBOUNDED PRECEDING)
              / SUM(Ciro) OVER () AS KumPay
    FROM UrunCiro
)
SELECT
    CASE WHEN KumPay <= 80 THEN N'A (ilk %80 ciro)'
         WHEN KumPay <= 95 THEN N'B (%80-95)'
         ELSE N'C (%95-100, uzun kuyruk)' END AS Sınıf,
    COUNT(*)                                                        AS [Ürün Sayısı],
    CAST(SUM(Ciro) AS decimal(18,0))                               AS [Ciro ₺],
    CAST(100.0*SUM(Ciro)/SUM(SUM(Ciro)) OVER() AS decimal(5,1))    AS [Ciro Pay %],
    CAST(100.0*COUNT(*)/SUM(COUNT(*)) OVER() AS decimal(5,1))      AS [Ürün Pay %]
FROM Kumulatif
GROUP BY CASE WHEN KumPay <= 80 THEN N'A (ilk %80 ciro)'
              WHEN KumPay <= 95 THEN N'B (%80-95)'
              ELSE N'C (%95-100, uzun kuyruk)' END
ORDER BY [Ciro ₺] DESC;

-- ---------------------------------------------------------------------
-- C-SINIF CLEARANCE ADAYLARI (uzun kuyruk ürün detayı) — açmak için yorumdan çıkar
-- ---------------------------------------------------------------------
-- ;WITH UrunCiro AS ( ... yukarıdaki aynı ... ),
-- Kumulatif AS ( ... yukarıdaki aynı ... )
-- SELECT TOP 200 p.Code, p.Name, CAST(k.Ciro AS decimal(18,0)) AS Ciro, CAST(k.KumPay AS decimal(5,1)) AS KumPay
-- FROM Kumulatif k JOIN EncoreMerkez.dbo.Products p ON p.Id = k.ProductsId
-- WHERE k.KumPay > 95 ORDER BY k.Ciro ASC;  -- en düşük cirolu C ürünler
