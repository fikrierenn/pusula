-- Talep tahmini — mağaza 1 ürün özellikleri + bugünkü öneri durumu (@D), StkId % 2 = @P parçası (100K satır sınırı)
-- Kategori/fiyat: bkm.OneriSiparis (o günün satırı). Stok/Min/Max/öneri: proc çıktısı (karşılaştırma tabanı).
SELECT o.StkId stk, o.KategoriId kat, CAST(o.SatisFiyat AS decimal(12,2)) fiyat, o.Stok stok,
       o.Minimum mn, o.Maximum mx, o.OneriSiparisAdet oneri, o.Miktar90 m90, o.Miktar360 m360
FROM bkm.OneriSiparis o WITH (NOLOCK)
WHERE o.MekanId = 1 AND o.Tarih = CONVERT(date, @D, 23) AND o.StkId % 2 = CAST(@P AS int)
