-- ENS kalibrasyon backtest — tek karar tarihi (@D), mağaza 1, %20 ürün örneklemi
-- Amaç: bkm.OneriSiparis'in her önerisi için beklenen 30 günlük satış (Miktar90/3) ↔ gerçekleşen
--       net satış (sonraki 30 gün). ENS PLAN-04 Faz 0.5 / PLAN-13 Faz 5 kanıtı.
-- Satış tanımı (sema/codes.yaml irsHrk.ehTip): satış 1,4,100 (ehAdetN negatif) − iade 3,5,101 (pozitif)
--   → net = -SUM(ehAdetN).
-- Ölü stok (Miktar90 = 0) dışarıda (PLAN-04 band hükmü). Bayat ön-agregalar (Rapor_IrsHrk_GunlukOzet,
-- StokBakiyeGunluk — 2025-12 sonrası yok) BİLEREK kullanılmadı.
-- Çalıştır: sqlcli query --profile erp --read-only --format csv --max-rows 100000 --timeout 300 --param D=2026-06-01 "$(cat <bu dosya>)"
-- Koşturucu: tools/ens-kalibrasyon/extract.sh
SELECT CONVERT(char(10), o.Tarih, 23) D, o.StkId, o.KategoriId Kat,
       o.Miktar30 M30, o.Miktar90 M90, o.Miktar360 M360,
       CAST(o.SatisFiyat AS decimal(12,2)) Fiyat,
       ISNULL((SELECT -SUM(h.ehAdetN)
               FROM dbo.irsHrk h WITH (NOLOCK)
               WHERE h.ehMekan = 1 AND h.ehstkID = o.StkId
                 AND h.ehTip IN (1,4,100,3,5,101)
                 AND h.ehTrhS > o.Tarih AND h.ehTrhS < DATEADD(day, 31, o.Tarih)), 0) A30
FROM bkm.OneriSiparis o WITH (NOLOCK)
WHERE o.MekanId = 1 AND o.Tarih = @D AND o.Miktar90 > 0
  AND ABS(CHECKSUM(o.StkId)) % 5 = 0
