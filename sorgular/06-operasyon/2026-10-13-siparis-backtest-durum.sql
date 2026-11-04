-- Sipariş backtest'i — karar günü (@D, Pazartesi = talep panelinin hafta başı) mağaza 1 durum: stok + proc önerisi.
-- Miktar90 > 0 (proc popülasyonu). Stok = o tarihteki şube stoğu; OneriSiparisAdet = proc'un o günkü önerisi.
SELECT o.StkId stk, o.Stok stok, o.Bakiye bakiye, o.Minimum mn, o.Maximum mx,
       o.OneriSiparisAdet oneri, CAST(o.SatisFiyat AS decimal(12,2)) fiyat
FROM bkm.OneriSiparis o WITH (NOLOCK)
WHERE o.MekanId = 1 AND o.Tarih = CONVERT(date, @D, 23) AND o.Miktar90 > 0
