/* ═══════════════════════════════════════════════════════════════════════════════
   SEZON STOK RAPORLARINDAKİ YANILTICI ALTI MADDE — ÖLÇÜM
   GMY direktifi 14.09.2026: "yanıltıcı bir şey istemiyorum"

   DB: DerinSISBkm · kesim 13.09.2026 · sezon 2025 · okul açılışı 14.09.2026 (geçen 08.09.2025)
   Emitter: scripts/sezon_magaza_stok_excel.py (iki mod: varsayılan (A) fazla · --yetmeyen (B) açık)

   BULGU ÖZETİ
   1) Ürün bazlı büyüme yalnız %7,2'de güvenilir → kaynak kolonu ZORUNLU  (blok 1)
   2) Merkez WMS hayalet şüphesi küçük ama sıfır değil: 84 çeşit / 2.369 adet (blok 1)
   3) "Açık sipariş" ölçülemez — kapatma alanı 24.02.2025'te ölmüş, adetin %86,4'ü
      bir yıldan eski → NETLENMEZ, dar pencereli BAYRAK olur           (blok 2, 3)
   4) (B) rafı boşalmış ürünü DIŞLIYORDU: 5.672 çeşit / 16,0M ₺ eksik   (blok 4)
   5) (A) sezon dışı ürünü "sezon fazlası" sayıyordu → sezon katı kapısı eklendi
   6) Kampanya/fiyat taşınmazlığı + sağdan sansür: düzeltilemez, BEYAN edildi
   ═══════════════════════════════════════════════════════════════════════════════ */

-- ── BLOK 1: ürün bazlı büyüme ne kadar güvenilir + merkez hayalet şüphesi ─────
-- Evren: (B)'nin evreni — sezon sonuna kalan talebi olan çeşitler.
DECLARE @k date = '2026-09-13', @ab date = '2026-09-14', @ag date = '2025-09-08';

WITH ub AS (   -- ürün bazlı hizalı sezon büyümesi (her iki yıl T−44..T−1)
  SELECT h.ehstkID AS stkID,
    SUM(CASE WHEN h.ehTrhS >= DATEADD(DAY,-44,@ab) AND h.ehTrhS < @ab THEN -h.ehAdetN ELSE 0 END) AS Y2,
    SUM(CASE WHEN h.ehTrhS >= DATEADD(DAY,-44,@ag) AND h.ehTrhS < @ag THEN -h.ehAdetN ELSE 0 END) AS Y1
  FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
  WHERE h.ehMekan IN (1,4477,4478) AND h.ehTip IN (1,3,4,5,100,101)
    AND h.ehTrhS >= DATEADD(DAY,-44,@ag) AND h.ehTrhS < @ab
  GROUP BY h.ehstkID),
kl AS (        -- geçen yılın aynı uzunluktaki kalan-sezon penceresi
  SELECT h.ehstkID AS stkID, SUM(-h.ehAdetN) AS KalanGY
  FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
  WHERE h.ehMekan IN (1,4477,4478) AND h.ehTip IN (1,3,4,5,100,101)
    AND h.ehTrhS >= @ag AND h.ehTrhS <= '20251025'
  GROUP BY h.ehstkID),
dft AS (       -- ERP merkez defteri — WMS'i ÇAPRAZ DENETLEMEK için (stok kaynağı DEĞİL)
  SELECT d.ehstkID AS stkID, SUM(d.stok) AS DefterMerkez
  FROM DerinSISBkm.dbo.stokSonAltDepo_vw d WITH (NOLOCK)
  WHERE d.ehMekan = 12
  GROUP BY d.ehstkID)
SELECT
  COUNT(*)                                                               AS ToplamCesit,
  SUM(CASE WHEN ISNULL(ub.Y1,0) >= 20 THEN 1 ELSE 0 END)                 AS UrunBuyume_n20,
  SUM(CASE WHEN ISNULL(ub.Y1,0) >= 5  THEN 1 ELSE 0 END)                 AS UrunBuyume_n5,
  SUM(CASE WHEN t.MerkezStok > 0 THEN 1 ELSE 0 END)                      AS MerkezStoguVar,
  SUM(CASE WHEN t.MerkezStok > 0 AND ISNULL(dft.DefterMerkez,0) <= 0 THEN 1 ELSE 0 END)
                                                                          AS HayaletSupheli,
  CONVERT(bigint, SUM(CASE WHEN t.MerkezStok > 0 AND ISNULL(dft.DefterMerkez,0) <= 0
                           THEN t.MerkezStok ELSE 0 END))                AS HayaletAdet
FROM DerinSISBkm.bkm.SatisAnaliziTaban t WITH (NOLOCK)
LEFT JOIN ub ON ub.stkID = t.stkID
LEFT JOIN kl ON kl.stkID = t.stkID
LEFT JOIN dft ON dft.stkID = t.stkID
WHERE t.Kesim = @k AND t.SezonYil = 2025 AND t.SezonToplam > 0
  AND t.StokFsm >= 0 AND t.StokOzl >= 0 AND t.StokIst >= 0 AND t.MerkezStok >= 0
  AND t.SatisFiyat > 0 AND ISNULL(kl.KalanGY,0) > 0;
/* SONUÇ 2026-09-14:
   ToplamCesit 65.898 · UrunBuyume_n20 4.740 (%7,2) · n5 15.214 (%23,1)
   MerkezStoguVar 8.810 · HayaletSupheli 84 · HayaletAdet 2.369
   ⇒ Ürün bazlı büyüme kategoriyi TAMAMEN YERİNE KOYAMAZ. %92,8 kategoriye düşüyor →
     her satırda "Büyüme kaynağı" yazılmak ZORUNDA. Kaynağı yazmayan rapor, ürün bazlı
     ölçtüğünü ima eder ve YANILTIR. */


-- ── BLOK 2: "açık sipariş" kapatma alanı ölü mü? ──────────────────────────────
SELECT s.eDurum,
       COUNT(DISTINCT s.eID)            AS Belge,
       MIN(s.eTarih)                    AS EnEski,
       MAX(s.eTarih)                    AS EnYeni,
       CONVERT(bigint, SUM(sa.ehAdet))  AS Adet
FROM DerinSISBkm.dbo.sip s WITH (NOLOCK)
JOIN DerinSISBkm.dbo.sipAyr sa WITH (NOLOCK) ON sa.ehID = s.eID
WHERE s.eTip IN (0,3)                  -- yalnız SATIN ALMA: 0 Alış · 3 Yerel Alım
GROUP BY s.eDurum ORDER BY s.eDurum;
/* SONUÇ: 0 → 1.634 belge / 6.264.737 adet (21.02.2023–14.09.2026)
          1 → 38.290 / 16.942.872 (31.05.2021–14.09.2026)
          2 → 5.334 / 663.778 (03.06.2021–**24.02.2025**)   ← kapatma o tarihte DURMUŞ
   ⇒ `eDurum <> 2` süzgeci "açık" DEMEK DEĞİL, "kapatılmamış" demek. */


-- ── BLOK 3: kapatılmamış siparişlerin YAŞI ────────────────────────────────────
SELECT Yas = CASE WHEN s.eTarih >= DATEADD(DAY,-15,@k)  THEN '0-15 gun'
                  WHEN s.eTarih >= DATEADD(DAY,-30,@k)  THEN '16-30 gun'
                  WHEN s.eTarih >= DATEADD(DAY,-60,@k)  THEN '31-60 gun'
                  WHEN s.eTarih >= DATEADD(DAY,-120,@k) THEN '61-120 gun'
                  WHEN s.eTarih >= DATEADD(DAY,-365,@k) THEN '121-365 gun'
                  ELSE '1 yildan eski' END,
       COUNT(DISTINCT s.eID) AS Belge, CONVERT(bigint, SUM(sa.ehAdet)) AS Adet
FROM DerinSISBkm.dbo.sip s WITH (NOLOCK)
JOIN DerinSISBkm.dbo.sipAyr sa WITH (NOLOCK) ON sa.ehID = s.eID
WHERE s.eTip IN (0,3) AND s.eDurum <> 2 AND s.eTarih <= @k
GROUP BY CASE WHEN s.eTarih >= DATEADD(DAY,-15,@k)  THEN '0-15 gun'
              WHEN s.eTarih >= DATEADD(DAY,-30,@k)  THEN '16-30 gun'
              WHEN s.eTarih >= DATEADD(DAY,-60,@k)  THEN '31-60 gun'
              WHEN s.eTarih >= DATEADD(DAY,-120,@k) THEN '61-120 gun'
              WHEN s.eTarih >= DATEADD(DAY,-365,@k) THEN '121-365 gun'
              ELSE '1 yildan eski' END;
/* SONUÇ: 0-15g 115/131.951 · 16-30g 111/39.063 · 31-60g 240/100.877 ·
          61-120g 469/335.199 · 121-365g 1.921/2.525.817 · 1 yıldan eski 37.065/19.920.271
   Toplam 23.053.178 adet → 1 yıldan eskisi %86,4 · son 30 gün %0,74.
   ⇒ KARAR: açık sipariş RAPORDAN DÜŞÜLMEZ. 30 günlük BAYRAK kolonu olur.
     (30 gün = ODAK temin ort. 5,03 gün + pay.) Netleme yapan rapor 20 milyon
     hayalet adetle yanıltırdı. Koruma: degismezler → sip-edurum-kapatma-olu. */


-- ── BLOK 4: (B) rafı boşalmış ürünü dışlıyordu — ne kadar eksik saydı? ────────
DECLARE @kg int = DATEDIFF(DAY, @ab, '20261031');   -- sezon sonuna kalan gün

WITH kl2 AS (
  SELECT h.ehstkID AS stkID, SUM(-h.ehAdetN) AS KalanGY
  FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
  WHERE h.ehMekan IN (1,4477,4478) AND h.ehTip IN (1,3,4,5,100,101)
    AND h.ehTrhS >= @ag AND h.ehTrhS <= DATEADD(DAY,@kg,@ag)
  GROUP BY h.ehstkID),
b AS (SELECT u.Kategori3,
    SUM(CASE WHEN h.ehTrhS >= DATEADD(DAY,-44,@ab) AND h.ehTrhS < @ab THEN -h.ehAdetN ELSE 0 END) AS S2,
    SUM(CASE WHEN h.ehTrhS >= DATEADD(DAY,-44,@ag) AND h.ehTrhS < @ag THEN -h.ehAdetN ELSE 0 END) AS S1
  FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
  JOIN DerinSISBkm.bkm.UrunBilgi u WITH (NOLOCK) ON u.stkID = h.ehstkID
  WHERE h.ehMekan IN (1,4477,4478) AND h.ehTip IN (1,3,4,5,100,101)
    AND h.ehTrhS >= DATEADD(DAY,-44,@ag) AND h.ehTrhS < @ab
  GROUP BY u.Kategori3),
k AS (SELECT Kategori3, CONVERT(float,S2)/NULLIF(S1,0) AS SB FROM b)
SELECT RafDurum = CASE WHEN t.MagazaStok > 0 THEN 'raf dolu (eski surumde vardi)'
                       ELSE 'RAF BOS (eski surumde YOKTU)' END,
  COUNT(*) AS Cesit,
  CONVERT(bigint, SUM(CEILING(kl2.KalanGY * ISNULL(k.SB,1.0)) - (t.MagazaStok + t.MerkezStok))) AS AcikAdet,
  CONVERT(decimal(18,0), SUM((CEILING(kl2.KalanGY * ISNULL(k.SB,1.0))
                              - (t.MagazaStok + t.MerkezStok)) * t.SatisFiyat)) AS AcikTL
FROM DerinSISBkm.bkm.SatisAnaliziTaban t WITH (NOLOCK)
JOIN kl2 ON kl2.stkID = t.stkID
LEFT JOIN k ON k.Kategori3 = t.Kategori3
WHERE t.Kesim = @k AND t.SezonYil = 2025 AND t.SezonToplam > 0
  AND t.StokFsm >= 0 AND t.StokOzl >= 0 AND t.StokIst >= 0 AND t.MerkezStok >= 0
  AND t.SatisFiyat > 0 AND kl2.KalanGY > 0
  AND t.MagazaStok + t.MerkezStok < CEILING(kl2.KalanGY * ISNULL(k.SB,1.0))
GROUP BY CASE WHEN t.MagazaStok > 0 THEN 'raf dolu (eski surumde vardi)'
              ELSE 'RAF BOS (eski surumde YOKTU)' END;
/* SONUÇ (kategori büyümesiyle, ürün bazlı KAPALI — eski sürümle kıyas için):
     raf dolu  14.188 çeşit ·  345.626 adet · 116.078.070 ₺
     RAF BOŞ    5.672 çeşit ·   40.927 adet ·  15.995.092 ₺   ← sessizce düşüyordu
   ⇒ Açığın EN KÖTÜ hâli (raf tamamen boş) listede YOKTU. %12 eksik sayım.
     `MagazaStok > 0` şartı artık YALNIZ (A) modunda uygulanıyor. */


-- ── BLOK 5: emitter çıktısının bağımsız doğrulaması (ürün bazlı büyüme AÇIK) ──
-- Python'un pozisyonel parametre bağlaması kayarsa SESSİZ yanlış rakam olur.
-- Bu blok aynı formülü BAĞIMSIZ kurar; emitter çıktısıyla birebir tutmalı.
WITH kl3 AS (
  SELECT h.ehstkID AS stkID, SUM(-h.ehAdetN) AS KalanGY
  FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
  WHERE h.ehMekan IN (1,4477,4478) AND h.ehTip IN (1,3,4,5,100,101)
    AND h.ehTrhS >= @ag AND h.ehTrhS <= DATEADD(DAY,@kg,@ag)
  GROUP BY h.ehstkID),
ub3 AS (SELECT h.ehstkID AS stkID,
    SUM(CASE WHEN h.ehTrhS >= DATEADD(DAY,-44,@ab) AND h.ehTrhS < @ab THEN -h.ehAdetN ELSE 0 END) AS Y2,
    SUM(CASE WHEN h.ehTrhS >= DATEADD(DAY,-44,@ag) AND h.ehTrhS < @ag THEN -h.ehAdetN ELSE 0 END) AS Y1
  FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
  WHERE h.ehMekan IN (1,4477,4478) AND h.ehTip IN (1,3,4,5,100,101)
    AND h.ehTrhS >= DATEADD(DAY,-44,@ag) AND h.ehTrhS < @ab
  GROUP BY h.ehstkID),
b3 AS (SELECT u.Kategori3,
    SUM(CASE WHEN h.ehTrhS >= DATEADD(DAY,-44,@ab) AND h.ehTrhS < @ab THEN -h.ehAdetN ELSE 0 END) AS S2,
    SUM(CASE WHEN h.ehTrhS >= DATEADD(DAY,-44,@ag) AND h.ehTrhS < @ag THEN -h.ehAdetN ELSE 0 END) AS S1
  FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
  JOIN DerinSISBkm.bkm.UrunBilgi u WITH (NOLOCK) ON u.stkID = h.ehstkID
  WHERE h.ehMekan IN (1,4477,4478) AND h.ehTip IN (1,3,4,5,100,101)
    AND h.ehTrhS >= DATEADD(DAY,-728,@k) AND h.ehTrhS <= @k
  GROUP BY u.Kategori3),
k3 AS (SELECT Kategori3, CONVERT(float,S2)/NULLIF(S1,0) AS SB FROM b3)
SELECT COUNT(*) AS Cesit,
  CONVERT(bigint, SUM(x.KalanTalep - (t.MagazaStok + t.MerkezStok))) AS AcikAdet,
  CONVERT(decimal(18,0), SUM((x.KalanTalep - (t.MagazaStok + t.MerkezStok)) * t.SatisFiyat)) AS AcikTL,
  CONVERT(bigint, SUM(x.KalanTalep)) AS KalanTalep
FROM DerinSISBkm.bkm.SatisAnaliziTaban t WITH (NOLOCK)
JOIN kl3 ON kl3.stkID = t.stkID
LEFT JOIN k3 ON k3.Kategori3 = t.Kategori3
LEFT JOIN ub3 ON ub3.stkID = t.stkID
CROSS APPLY (SELECT UO = CASE WHEN ISNULL(ub3.Y1,0) >= 20
                              THEN CONVERT(float, ub3.Y2) / ub3.Y1 END) bo
CROSS APPLY (SELECT Bu = CASE WHEN bo.UO BETWEEN 0.2 AND 5.0 THEN bo.UO
                              ELSE ISNULL(k3.SB, 1.0) END) bx
CROSS APPLY (SELECT KalanTalep = CONVERT(int, CEILING(kl3.KalanGY * bx.Bu))) x
WHERE t.Kesim = @k AND t.SezonYil = 2025 AND t.SezonToplam > 0
  AND t.StokFsm >= 0 AND t.StokOzl >= 0 AND t.StokIst >= 0 AND t.MerkezStok >= 0
  AND t.SatisFiyat > 0 AND kl3.KalanGY > 0
  AND t.MagazaStok + t.MerkezStok < x.KalanTalep;
/* SONUÇ: 19.610 çeşit · 405.213 adet · 129.484.766 ₺ · kalan talep 630.716
   Emitter (--yetmeyen) çıktısı: 19.610 / 405.213 / 129.484.766 → BİREBİR TUTTU.
   ⇒ pyodbc pozisyonel bağlaması doğru. Bu blok, parametre sırası değişirse
     yeniden koşulmalıdır (sessiz kayma tek yakalanma yolu budur). */
