-- Talep tahmini — mağaza 1 TOPLU/fatura satışları (ehTip 1,4 satış; 3,5 iade) haftalık, [@A, @B).
-- Amaç: perakende talebi = haftalik.sql (1,4,100−3,5,101) − bu sorgu → POS(100) − POS iade(101).
-- 2021-08-16 haftası: ehTip 4'te 479 satırda 203.023 adet (satır başı ~424) — kurumsal/toplu, raf talebi değil.
SELECT h.ehstkID stk, DATEDIFF(day, '2021-06-07', CAST(h.ehTrhS AS date)) / 7 w, -SUM(h.ehAdetN) q
FROM dbo.irsHrk h WITH (NOLOCK)
WHERE h.ehMekan = CAST(@MK AS int) AND h.ehTip IN (1,4,3,5)
  AND h.ehTrhS >= CONVERT(date, @A, 23) AND h.ehTrhS < CONVERT(date, @B, 23)
GROUP BY h.ehstkID, DATEDIFF(day, '2021-06-07', CAST(h.ehTrhS AS date)) / 7
HAVING SUM(h.ehAdetN) <> 0
