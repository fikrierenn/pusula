-- Talep tahmini v5 — mağaza 1 TÜM stok hareketleri haftalık net (ürün × hafta), [@A, @B). Hafta 0 = 2021-06-07.
-- Kümülatif toplam = hafta sonu stok (PLAN-04 Faz 0: Bakiye = SUM(ehAdetN), 7/8 doğrulandı). Açılış devri ehTip 99
-- (2021-05-31) hafta −1'e düşer → @A = 2021-05-31 ile başlatılmalı (w = −1 satırları açılış bakiyesidir).
SELECT h.ehstkID stk, (DATEDIFF(day, '2021-06-07', CAST(h.ehTrhS AS date)) + 7) / 7 - 1 w, SUM(h.ehAdetN) q
FROM dbo.irsHrk h WITH (NOLOCK)
WHERE h.ehMekan = CAST(@MK AS int) AND h.ehstkID % CAST(@M AS int) = CAST(@R AS int)   -- @M/@R: satır sınırı aşılırsa ürün koduna göre bölme
  AND h.ehTrhS >= CONVERT(date, @A, 23) AND h.ehTrhS < CONVERT(date, @B, 23)
GROUP BY h.ehstkID, (DATEDIFF(day, '2021-06-07', CAST(h.ehTrhS AS date)) + 7) / 7 - 1
HAVING SUM(h.ehAdetN) <> 0
