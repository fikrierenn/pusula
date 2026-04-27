-- EncoreMerkez Sorgu 10.19 — Mağaza Fiyat Kontrolü (Barkod / Ürün Kodu)
-- Kaynak: encore-merkez-analiz-raporu.html
-- Veritabanı: EncoreMerkez
-- ============================================

-- Barkod veya ürün koduyla tüm mağazalardaki fiyatı sorgulama
DECLARE @ara nvarchar(50) = 'URUN_KODU_VEYA_BARKOD'

SELECT
    st.Name AS Magaza,
    p.Code, p.Name,
    b.BarcodeNo,
    sp.Price1, sp.Price2, sp.Price3,
    sp.IsOnSale, sp.IsChanged,
    pc.Name AS Kategori,
    pb.Name AS Marka
FROM dbo.StorePrice sp
JOIN dbo.Products p ON sp.ProductsId = p.Id
JOIN dbo.Stores st ON sp.StoresId = st.Id
LEFT JOIN dbo.Barcodes b ON p.Id = b.ProductsId
LEFT JOIN dbo.ProductCategory pc ON p.CategoryId = pc.Id
LEFT JOIN dbo.ProductBrand pb ON p.BrandId = pb.Id
WHERE (p.Code = @ara OR b.BarcodeNo = @ara OR p.Name LIKE '%' + @ara + '%')
  AND sp.IsActive = 1 AND p.IsDeleted = 0
