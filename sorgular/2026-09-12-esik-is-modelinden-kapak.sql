/* ============================================================================
   B-172(c) — AŞIRI STOK EŞİĞİ İŞ MODELİNDEN: İKMAL KAPAĞI
   Tarih: 12.09.2026 · DB: DerinSISBkm (bkm.SatisAnaliziTaban, kesim 11.09.2026)

   SORU: danışman itirazı — "eşik iş modelinden gelmeli; LeadTime, sezon ağırlığı
   ve iade hakkı veride VAR ve kullanılmıyor". Bugüne kadar eşik ürünün KENDİ
   geçmişinden (sezon satışının katı) türetiliyordu.

   ═══ BULGU 1 — sezon ekseni YANLIŞ POZİTİF üretiyor (blok 3) ═══════════════
   Dört grup, medyan yıllık devir (satış365 / stok):
     A) sezon-DIŞI satan (kart KÖR)   63.565 çeşit · 132,2M ₺ · medyan 0,50
     B) sezon işaretli, kapak TEMİZ    4.904 çeşit ·  13,4M ₺ · medyan 2,25
     C) ikisi de işaretli             32.556 çeşit · 109,9M ₺ · medyan 0,48
     D) ikisi de temiz                35.273 çeşit ·  71,6M ₺ · medyan 2,40
   B grubunun devri D'den AYIRT EDİLEMİYOR (2,25 ↔ 2,40) → sağlıklı dönen mal
   "aşırı stok" damgası yiyordu. UYGULANDI: kapak ayağı eklendi, B kohorttan çıktı.
   Panelde doğrulandı: 40.017 → 37.103 çeşit · fazla maliyet 83,3M → 74,7M ₺.
   (Bağımsız ölçüm 32.556 diyor; fark, satış365 = 0 ama sezonda satmış ~4.500
   çeşit — onlarda düz hız 0 olduğu için kapak ayağı bağlamıyor. Doğru davranış:
   bir yılda hiç satmayan mal zaten aşırıdır.)

   ═══ BULGU 2 — kartın KÖR NOKTASI (A grubu), AÇIK BIRAKILDI ════════════════
   Ölçüt `SezonToplam > 0` kapısı taşıyor → sezon DIŞINDA satan 63.565 çeşit /
   132,2M ₺ (medyan devir 0,50) aşırı stok kartında HİÇ görünmüyor. Sezon kapısını
   kaldırıp tümüyle kapağa geçmek ÖLÇÜLDÜ (blok 4):
     bugünkü 2× sezon      37.460 çeşit ·  81,6M ₺ fazla
     kapak 5× (iş modeli)  94.021 çeşit · 170,2M ₺ fazla   ← ceza 2,1 KAT
     kapak 8×              76.091 çeşit · 137,1M ₺
     kapak 12×             55.570 çeşit · 110,1M ₺
   Alıcıya bakan sayıyı ikiye katlayan adım TEK TARAFLI UYGULANMADI — kullanıcı
   kararı bekliyor (TODO B-172c2).

   ═══ KAT SAYISI NEREDEN (veriden DEĞİL) ════════════════════════════════════
   Devir hedefi 2,0 ⇒ üst sınır gün-stok 365/2,0 = 182,5 gün.
   Ortalama döngü = ODAK temin 5,03 + 30 gün gözden geçirme = 35,03 gün.
   182,5 / 35,03 = 5,21 ⇒ kat 5. Ortalama temin süresinde eşik tam devir hedefine
   denk düşer; hızlı temin edilen üründe SIKILAŞIR, yavaşta GEVŞER.
   ⇒ Altman & Royston (2006) "veriden seçilen kesimin bedeli" uyarısı bu ayağa
   İŞLEMEZ: kesim veriden değil hedeften geliyor.

   ⚠ KISMİ TOTOLOJİ (beyan): kapak da devir de SatisToplam'ı kullanıyor. Blok 2'nin
   "kapak katı arttıkça devir düşüyor" deseni kısmen mekaniktir ve eşik seçiminde
   DELİL SAYILMADI; yalnız eksenin monotonluğunu göstermek için duruyor — sezon
   ekseninin Kırtasiye'de yapamadığı şey (bkz. 2026-09-12-esik-medyan...sql).
   ============================================================================ */

DECLARE @k date = (SELECT MAX(Kesim) FROM DerinSISBkm.bkm.SatisAnaliziTaban);

/* Ortak taban: defter güvenilir + stok var. Kapak = max(düz hız, sezon hızı) ×
   (temin + 30). Ay1+Ay2+Ay3 = sezon penceresi (92 gün) — SezonToplam ile aynı küme. */
WITH t AS (
    SELECT stkID, ToplamStok, SatisToplam, SezonToplam, Ay1, Ay2, Ay3,
           LeadTime, BirimMaliyet, Kategori3
    FROM DerinSISBkm.bkm.SatisAnaliziTaban WITH (NOLOCK)
    WHERE Kesim = @k AND SezonYil = 2025
      AND StokFsm >= 0 AND StokOzl >= 0 AND StokIst >= 0 AND MerkezStok >= 0
      AND SatisFiyat > 0 AND ToplamStok > 0
),
k2 AS (
    SELECT *,
           CASE WHEN (CONVERT(float, ISNULL(Ay1,0)) + ISNULL(Ay2,0) + ISNULL(Ay3,0)) / 92.0
                     > CONVERT(float, SatisToplam) / 365.0
                THEN (CONVERT(float, ISNULL(Ay1,0)) + ISNULL(Ay2,0) + ISNULL(Ay3,0)) / 92.0
                ELSE CONVERT(float, SatisToplam) / 365.0 END
           * (CONVERT(int, ISNULL(LeadTime, 7)) + 30) AS Kapak
    FROM t
)

/* ── BLOK 1 — kapak ekseninde dağılım (bugün "aşırı" sayılanla birlikte) ──── */
SELECT CASE WHEN ToplamStok <= Kapak THEN '0) kapak ALTI'
            WHEN ToplamStok <= 2*Kapak THEN '1) 1-2 kapak'
            WHEN ToplamStok <= 3*Kapak THEN '2) 2-3'
            WHEN ToplamStok <= 6*Kapak THEN '3) 3-6'
            WHEN ToplamStok <= 12*Kapak THEN '4) 6-12'
            ELSE '5) 12+' END AS Kova,
       COUNT(*) AS Cesit,
       SUM(CASE WHEN SezonToplam > 0 AND ToplamStok > 2*SezonToplam THEN 1 ELSE 0 END) AS BugunAsiriSayilan
FROM k2
GROUP BY CASE WHEN ToplamStok <= Kapak THEN '0) kapak ALTI'
              WHEN ToplamStok <= 2*Kapak THEN '1) 1-2 kapak'
              WHEN ToplamStok <= 3*Kapak THEN '2) 2-3'
              WHEN ToplamStok <= 6*Kapak THEN '3) 3-6'
              WHEN ToplamStok <= 12*Kapak THEN '4) 6-12'
              ELSE '5) 12+' END
ORDER BY 1;
/* ÖLÇÜLDÜ: kapak altı 25.109 · 1-2 9.685 · 2-3 10.944 · 3-6 22.051 ·
   6-12 30.661 · 12+ 55.570. Medyan devir bantlar boyunca MONOTON azalıyor
   (10,50 · 5,00 · 2,89 · 2,58 · 1,78 · 1,00 · 0,33) ve devir<1 oranı monoton
   artıyor (%1,1 → %100). Sezon ekseni Kırtasiye'de monoton DEĞİLDİ. */

/* ── BLOK 3 — DÖRT GRUP: eşiklerin nerede ayrıştığı (ASIL BULGU) ─────────── */
-- WITH ... (yukarıdaki t/k2 aynen), sonra:
--   Grup A: SezonToplam <= 0                        → kart kör
--   Grup B: sezon işaretli, kapak temiz (<= 6×)     → YANLIŞ POZİTİF
--   Grup C: ikisi de işaretli                       → gerçek sorun
--   Grup D: ikisi de temiz
-- Medyan: ROW_NUMBER() OVER (PARTITION BY Grup ORDER BY Devir) - (COUNT(*)+1)/2 = 1
-- ÖLÇÜLDÜ: A 63.565/132,2M/0,50 · B 4.904/13,4M/2,25 · C 32.556/109,9M/0,48 ·
--          D 35.273/71,6M/2,40

/* ── BLOK 4 — eşik seçeneklerinin ALICIYA BAKAN maliyeti ────────────────── */
-- 'bugun 2x sezon'        → çeşit 37.460 · fazla maliyet  81,6M ₺
-- 'kapak 5x (is modeli)'  → çeşit 94.021 · fazla maliyet 170,2M ₺
-- 'kapak 8x'              → çeşit 76.091 · fazla maliyet 137,1M ₺
-- 'kapak 12x'             → çeşit 55.570 · fazla maliyet 110,1M ₺
-- Fazla maliyet = (ToplamStok - eşik) × BirimMaliyet, yalnız eşiği aşanlarda.
