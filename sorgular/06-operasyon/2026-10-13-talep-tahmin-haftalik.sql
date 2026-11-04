-- Talep tahmini — mağaza 1 haftalık net satış (ürün × ISO hafta), [@A, @B) aralığı
-- Hafta 0 = 2021-06-07 (Pazartesi). Net satış = satış (1,4,100; ehAdetN negatif) − iade (3,5,101) → -SUM(ehAdetN).
-- Yalnız sıfır olmayan hücreler döner (seyrek). Stoksuz haftalarda satış = SANSÜRLÜ talep (ayrıca işlenecek).
-- Çalıştır: sqlcli query --profile erp --read-only --format csv --max-rows 100000 --param A=2021-06-07 --param B=2021-07-05 "$(grep -v '^\s*--' <bu dosya>)"
SELECT h.ehstkID stk, DATEDIFF(day, '2021-06-07', CAST(h.ehTrhS AS date)) / 7 w, -SUM(h.ehAdetN) q
FROM dbo.irsHrk h WITH (NOLOCK)
WHERE h.ehMekan = CAST(@MK AS int) AND h.ehTip IN (1,4,100,3,5,101)
  AND h.ehTrhS >= CONVERT(date, @A, 23) AND h.ehTrhS < CONVERT(date, @B, 23)   -- style 23: dil ayarından bağımsız (sunucu DMY; çıplak @A tarih kaydırıyordu, 2026-10-13)
GROUP BY h.ehstkID, DATEDIFF(day, '2021-06-07', CAST(h.ehTrhS AS date)) / 7
HAVING SUM(h.ehAdetN) <> 0
