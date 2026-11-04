-- Ürün başına SON 5 alış satırının birim fiyatı (salt-okuma) — sağlam birim maliyet (medyan) için.
-- ehTip 0 Alış, 10 Yerel Alım; tüm mekanlar. Birim = ehTutarN / ehAdetN (adet > 0). @M/@R: stkID'ye göre bölme.
-- Neden: bkm.UrunBilgi.SonAlis tek bir hatalı (koli fiyatlı) satırdan bozuluyor (37040: 9,20 → 920 TL) — 2026-10-15 danışman bulgusu, doğrulandı.
SELECT x.stk, x.sira, CONVERT(char(10), x.tarih, 23) tarih, CAST(x.birim AS decimal(14,4)) birim, CAST(x.adet AS decimal(14,3)) adet
FROM (
  SELECT h.ehstkID stk, h.ehTrhS tarih, h.ehTutarN / h.ehAdetN birim, h.ehAdetN adet,
         ROW_NUMBER() OVER (PARTITION BY h.ehstkID ORDER BY h.ehTrhS DESC, h.ehAdetN DESC) sira
  FROM dbo.irsHrk h WITH (NOLOCK)
  WHERE h.ehTip IN (0, 10) AND h.ehAdetN > 0 AND h.ehTutarN > 0 AND h.ehstkID % CAST(@M AS int) = CAST(@R AS int)
) x
WHERE x.sira <= 5
