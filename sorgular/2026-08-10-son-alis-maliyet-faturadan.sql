/*
  Son Alış Maliyeti (birim, KDV-hariç net) — en son ALIŞ faturasından, ürün bazlı.
  DB: DerinSISBkm · Kaynak: dbo.fatAyr + dbo.fat (eTip=0 = alış; 17.06 kuralı).
  Birim = fatAyr.ehTutarN / ehAdetN (net, KDV-hariç). Son fatura = ROW_NUMBER eTarih DESC.
  Kapsam: Kırtasiye+Oyuncak+Hediyelik (bkm.UrunBilgi.Kat3ID IN 10,12,16).
  Bulgu: faturalı ~%48 (66.783 ürün). Faturasızlarda FALLBACK = 31.05.2021 açılış DEVİR
         (irsHrk ehTip=99 'Sayım', go-live sayımı) birim = SUM(ehTutarN)/SUM(ehAdetN) → +52.218 ürün.
  Kaynak sırası: Fatura (son alış, herhangi bir tarih) > Devir (31.05.2021) > Yok(0).
  Kullanım: stok-satis-aylik-wide.py — "Son Alış Maliyeti"+"Maliyet Kaynak"+"Toplam Maliyet Değeri".
  Not: bkm.UrunBilgi.SonAlis kolonu var ama pasif üründe 0 (güvenilmez) → fatura/devir türetmesi tercih.
*/
-- 1) FATURA (öncelik): en son alış faturası birim net
WITH la AS (
    SELECT fa.ehstkID AS stkID,
           CONVERT(decimal(18,4), fa.ehTutarN / NULLIF(fa.ehAdetN, 0)) AS son_alis_maliyet,
           f.eTarih AS son_alis_tarih,
           ROW_NUMBER() OVER (PARTITION BY fa.ehstkID ORDER BY f.eTarih DESC, f.eID DESC) AS rn
    FROM dbo.fatAyr fa WITH(NOLOCK)
    JOIN dbo.fat f WITH(NOLOCK) ON fa.ehID = f.eID
    JOIN bkm.UrunBilgi u WITH(NOLOCK) ON u.stkID = fa.ehstkID AND u.Kat3ID IN (10, 12, 16)
    WHERE f.eTip = 0 AND f.eDurum <> 2 AND fa.ehAdetN > 0
)
SELECT stkID, son_alis_maliyet, son_alis_tarih, 'Fatura' AS kaynak
FROM la WHERE rn = 1;

-- 2) DEVİR (fallback): 31.05.2021 açılış sayımı — yalnız faturasız ürünlerde kullanılır (Python merge)
SELECT h.ehstkID AS stkID,
       CONVERT(decimal(18,4), SUM(h.ehTutarN) / NULLIF(SUM(h.ehAdetN), 0)) AS devir_maliyet,
       CONVERT(date, '20210531') AS devir_tarih, 'Devir' AS kaynak
FROM dbo.irsHrk h WITH(NOLOCK)
JOIN bkm.UrunBilgi u WITH(NOLOCK) ON u.stkID = h.ehstkID AND u.Kat3ID IN (10, 12, 16)
WHERE h.ehTip = 99 AND h.ehTrhS >= '20210531' AND h.ehTrhS < '20210601'
GROUP BY h.ehstkID
HAVING SUM(h.ehAdetN) <> 0;
