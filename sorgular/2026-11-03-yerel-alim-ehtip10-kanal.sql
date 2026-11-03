/*
  ALIŞ KANALI = ehTip 0 (Alış, çoğu depo-12) + 10 (Yerel Alım, çoğu mağazaya DİREKT) — DerinSISBkm
  Soru: satınalma raporu FIFO "son parti / en eski kalan" neden bazı ürünlerde boş? → yerel alım atlanıyordu.

  BULGU (canlı doğrulandı 2026-11-03):
    Alış iki ehTip taşır: 0 ve 10. Dağılım (2026, ehTrhS>=2026-01-01):
      ehTip=0  mekan 12 = 4.520.336 adet (merkez depo alımı)  · mekan 1/4478 küçük (1.319 / 13.984)
      ehTip=10 mekan 4478=1.461.544 · 4477=1.139.904 · 1=794.537 → TOPLAM ~3,4M adet MAĞAZAYA DİREKT
    ⚠ FIFO parti havuzu yalnız `ehTip=0 AND ehMekan=12` alırsa, yalnız YEREL alınan ürünlerin
      (depoya hiç uğramayan) partisi HİÇ görünmez → "Son Parti / En Eski Kalan / Taze parti" boş/yanlış.
    Örnek (eski_depo_alis=0 ama yerel>500): 1667706 Key Chain 39.986 ad/13 gün · 1695745 Mini Sticker
      20.000/2 gün · 37040 Laminasyon 11.602/5 gün. Eski FIFO bunları partisiz bırakıyordu.
    DÜZELTME: parti havuzu = `ehTip IN (0,10)` + TÜM mekan, `GROUP BY ehstkID, CONVERT(date,ehTrhS)`
      (aynı gün tüm kanallar tek partide). Uygulandı: scripts/satinalma_toplanti_analiz.py.
    ⚠ Tek-parti/yalnız-depo ürünü (ör. 1697900 Mas Sunum Dosyası, tek alış 21.10 depo 1224) ETKİLENMEZ.
  Not: ehTip=10 = 'Yerel Alım' (irsTip_vw); ehAdetN POZİTİF (giriş). Satış/alış yön kuralı sql-server-conventions.md.
*/

-- Alış kanalı dağılımı: ehTip × mekan (2026)
SELECT h.ehTip, h.ehMekan, COUNT(*) satir, SUM(h.ehAdetN) adet
FROM dbo.irsHrk h WITH(NOLOCK)
WHERE h.ehTip IN (0,10) AND h.ehTrhS >= '20260101'
GROUP BY h.ehTip, h.ehMekan
ORDER BY adet DESC;

-- Eski FIFO'nun kaçırdığı ürünler: depo-alışı YOK ama yerel alımı büyük (Kat3ID 10/12/16 = rapor kapsamı)
SELECT TOP 20 h.ehstkID, u.stkAd,
  SUM(CASE WHEN h.ehTip=0 AND h.ehMekan=12 THEN h.ehAdetN ELSE 0 END) eski_depo_alis,
  SUM(CASE WHEN h.ehTip=10 THEN h.ehAdetN ELSE 0 END) yerel_alis,
  COUNT(DISTINCT CONVERT(date,h.ehTrhS)) parti_gun
FROM dbo.irsHrk h WITH(NOLOCK)
JOIN bkm.UrunBilgi u WITH(NOLOCK) ON u.stkID=h.ehstkID AND u.Kat3ID IN (10,12,16)
WHERE h.ehTip IN (0,10) AND h.ehTrhS>='20260101' AND h.ehTrhS<'20261101'
GROUP BY h.ehstkID, u.stkAd
HAVING SUM(CASE WHEN h.ehTip=0 AND h.ehMekan=12 THEN h.ehAdetN ELSE 0 END)=0
   AND SUM(CASE WHEN h.ehTip=10 THEN h.ehAdetN ELSE 0 END)>500
ORDER BY yerel_alis DESC;
