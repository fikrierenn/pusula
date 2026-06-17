-- 2026-06-17 — irsHrk/fatAyr ehTip adet işareti keşfi (ADR-004 düzeltme kanıtı)
-- Soru: alış mı satış mı hangi ehTip, ehAdetN işareti ne? Eski ADR-004 "ehTip=1 alış, negatif" doğru mu?
-- Bulgu: Alış=ehTip 0 (+Yerel Alım 10) POZİTİF (giriş); Satış=1,4,100 NEGATİF (çıkış). ADR-004 TERSTİ → düzeltildi.
-- DB: DerinSISBkm

-- irsHrk (stok hareket) ehTip × adet işareti
SELECT h.ehTip, t.tipAD, COUNT(*) Adet, SUM(h.ehAdetN) ToplamAdetN, AVG(h.ehAdetN) OrtAdetN, SUM(h.ehTutarN) ToplamTutarN
FROM DerinSISBkm.dbo.irsHrk h WITH(NOLOCK)
LEFT JOIN DerinSISBkm.dbo.irsTip_vw t ON t.tipID = h.ehTip
WHERE h.ehTrhS >= DATEADD(DAY,-30,GETDATE()) AND h.ehMekan IN (12,1,4478,4477) AND h.ehAltDepo=0
GROUP BY h.ehTip, t.tipAD
ORDER BY COUNT(*) DESC;

-- fatAyr (fatura satırı) eTip × adet işareti — alış faturası (eTip=0) da POZİTİF
SELECT f.eTip, COUNT(*) Satir, SUM(fa.ehAdetN) ToplamAdetN, AVG(fa.ehAdetN) OrtAdetN
FROM DerinSISBkm.dbo.fat f WITH(NOLOCK)
JOIN DerinSISBkm.dbo.fatAyr fa WITH(NOLOCK) ON fa.ehID=f.eID
WHERE f.eTarih >= DATEADD(DAY,-30,GETDATE())
GROUP BY f.eTip ORDER BY COUNT(*) DESC;
