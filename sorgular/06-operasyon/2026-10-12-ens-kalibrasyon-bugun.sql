-- ENS kalibrasyon — bugünün canlı öneri listesi (@D), mağaza 1, satışı olan tüm ürünler + ad
-- Çıktı ENS karar kapısına girer (Ens.Bkm.Backtest). Kişi verisi yok; ürün adı ve fiyat.
SELECT o.StkId, REPLACE(REPLACE(u.stkAd, ',', ' '), '"', '') Ad, o.KategoriId Kat,
       o.Miktar30 M30, o.Miktar90 M90, o.Miktar360 M360,
       CAST(o.SatisFiyat AS decimal(12,2)) Fiyat, o.Stok, o.OneriSiparisAdet Oneri
FROM bkm.OneriSiparis o WITH (NOLOCK)
JOIN dbo.urn u WITH (NOLOCK) ON u.stkID = o.StkId
WHERE o.MekanId = 1 AND o.Tarih = @D AND o.Miktar90 > 0
