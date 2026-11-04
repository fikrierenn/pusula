-- Talep tahmini — ürün özellikleri (bkm.UrunBilgi), mağaza 1'de 2021-06-07'den beri satışı olanlar, stkID % 4 = @P.
SELECT u.stkID stk, u.Kategori2 kat2, u.KatAna katana, u.Kat2ID kat2id, u.Kat3ID kat3id, u.mrkID yayinevi,
       u.YazarId yazar, CAST(u.SatisFiyat AS decimal(12,2)) fiyat, CAST(u.SonAlis AS decimal(12,2)) sonalis,
       CONVERT(char(10), u.gTarih, 23) giris, u.UrunDurum durum
FROM bkm.UrunBilgi u WITH (NOLOCK)
WHERE u.stkID % 4 = CAST(@P AS int)
  AND EXISTS (SELECT 1 FROM dbo.irsHrk h WITH (NOLOCK)
              WHERE h.ehMekan = CAST(@MK AS int) AND h.ehstkID = u.stkID AND h.ehTip IN (100,4,1)
                AND h.ehTrhS >= CONVERT(date, '2021-06-07', 23))
