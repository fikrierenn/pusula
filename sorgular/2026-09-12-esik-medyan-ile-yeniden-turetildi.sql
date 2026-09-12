/* ═══════════════════════════════════════════════════════════════════════════════
   AŞIRI STOK EŞİĞİ MEDYAN İLE YENİDEN TÜRETİLDİ — B-172(d)          12.09.2026

   Danışman itirazı (satinalma-danisman 10.09): "panel geneli 3× artık DESTEKLENMİYOR;
   karma örneklemden türetilmişti ve onu Kırtasiye domine ediyordu (bantlarında 7.480 çeşit).
   Kırtasiye ayrıldı → kalan sekiz kategori BAŞKA BİR KATEGORİNİN eşiğiyle yargılanıyor.
   3× Kırtasiye HARİÇ yeniden ölçülmeli."

   Ölçüldü — ve itirazdan DAHA BÜYÜK bir hata çıktı.

   ═══ ASIL BULGU: ORTALAMA YANILTMIŞ ═══════════════════════════════════════════
   10.09'daki türetme bant başına ORTALAMA yıllık devir kullanıyordu. Devir dağılımı SAĞA
   ÇARPIK: hızlı dönen azınlık ortalamayı yukarı çeker ve eşik olduğundan YÜKSEK çıkar.

   Panel geneli (Kırtasiye + Hazırlık HARİÇ, n = 2.114 çeşit):
     bant       <2×    2-3×   3-4×   4-5×   5-8×   8×+
     ORTALAMA   5,82   1,11   1,06   0,74   0,47   0,32    → "eşik 4×" derdi
     MEDYAN     1,00   0,65   0,48   0,50   0,29   0,16    → eşik 2×

   Hazırlık Kitapları (bugünkü eşiği 8×):
     ORTALAMA  11,68   2,14   1,93   1,20   0,28           → 8×
     MEDYAN     3,67   0,86   0,83   0,35   0,38   0,07    → 2×
   ⇒ ortalama bu kategoride eşiği DÖRT KAT şişirmişti.

   Kırtasiye — ince bant (n = 7.480):
     bant     <0,5×  0,5-1×  1-1,5×  1,5-2×  2-3×   3×+
     MEDYAN    0,67   0,75    0,78    0,75   0,62   0,30
   MONOTON DEĞİL ve ilk banttan itibaren HEPSİ 1'in ALTINDA ⇒ bu eksende eşik TÜRETİLEMEZ.
   Kategori, kat'tan bağımsız olarak yavaş (ölçülen kategori devri 1,25).
   ⚠ Bu, danışmanın (c) itirazının doğrudan kanıtı: eşiği kategorinin KENDİ geçmişinden
     türetmek başarısızlığı normalleştiriyor. Kırtasiye panel geneliyle aynı eşiğe bırakıldı.

   ═══ İSTATİSTİKSEL SINAMA (olctum-mu-cikardim-mi § EŞİK TÜRETME) ══════════════
   Cochran-Armitage trend (devir<1 oranı, 6 sıralı bant): χ²(1) = 213,86 · p = 2,0e-48.
   Monotonluk: devir azalan ✓ · oran artan ✓ (%45,2 · %64,8 · %74,5 · %83,3 · %83,5 · %93,0).
   Wilson %95 GA:
     <2×   0,428-0,478   ┐ AYRIK → 2× kesimi DESTEKLİ
     2-3×  0,576-0,714   ┘
     3-4×  0,655-0,819   ┐
     4-5×  0,731-0,902   ├ ÇAKIŞIK → 3× ile 4× arasında ayrım DESTEKLENMİYOR
     5-8×  0,742-0,899   │
     8×+   0,880-0,961   ┘
   ⇒ İstatistiğin desteklediği TEK kesim 2×; medyan ölçütü de onu veriyor. İki bağımsız
     ölçüt aynı yeri gösteriyor.

   ⚠ KESİMİN BEDELİ (Altman & Royston 2006 · Royston/Altman/Sauerbrei 2006): veriden seçilen
     kesim gruplar arası farkı ABARTIR, tekrarlanabilirliği düşürür. Kesimdeki oran farkı bir
     ETKİ ÖLÇÜSÜ olarak sunulmaz; yalnız kohort seçiminde kullanılır.
   ⚠ TERS NEDENSELLİK duruyor: alıcı çok satmasını beklediğine çok stok koyar.
   ⚠ "Yıllık devir" hem stok düzeyini hem talep değişimini taşır.

   ═══ KARAR ════════════════════════════════════════════════════════════════════
   Kategori bazlı eşik KALDIRILDI. Tek eşik: 2× sezon satışı.
     panel geneli       3× → 2×
     Hazırlık Kitapları 8× → 2×   (ortalama hatası, 4 kat)
     Kırtasiye          2× → 2×   (türetilemedi; ayrıcalıklı eşik gerekçesi kalmadı)

   ETKİ (kesim 11.09.2026, defter güvenilir, sezon > 0):
     30.361 → 40.017 çeşit · eşik üstü fazla maliyet 72,5M → 83,3M ₺ (ceza +%15).
   ⚠ Karşı-metrik dengesi (B-172a) bu sıkılaştırmadan ÖNCE kuruldu — hafifletici olmadan
     bu değişiklik alıcıyı "az al" yönüne iterdi (danışmanın en ciddi itirazı).

   Kod: dashboard/Data/SatisAnaliziQueries.cs → AsiriStokKat / AsiriStokKatSql
   Süperseder: sorgular/2026-09-10-kategori-bazli-asiri-stok-esigi.sql (ortalama tabanlı)
   ═══════════════════════════════════════════════════════════════════════════════ */

SET NOCOUNT ON;

/* ── 1) MEDYAN vs ORTALAMA — grup × bant ────────────────────────────────────────
   Aynı veriden iki ölçüt; farkı görmek için yan yana. */
WITH bas AS (      -- 01.08.2025 itibarıyla toplam stok (mağaza + merkez)
    SELECT ehstkID AS sid, SUM(ehAdetN) AS Stok
    FROM DerinSISBkm.dbo.irsHrk WITH (NOLOCK)
    WHERE ehMekan IN (1, 4477, 4478, 12) AND ehTrhS < CONVERT(date, '20250801')
    GROUP BY ehstkID
),
s24 AS (           -- 2024 sezonu (Ağu-Eki) = TALEP VEKİLİ
    SELECT ehstkID AS sid, CONVERT(int, -SUM(ehAdetN)) AS Satis
    FROM DerinSISBkm.dbo.irsHrk WITH (NOLOCK)
    WHERE ehMekan IN (1, 4477, 4478) AND ehTip IN (1, 3, 4, 5, 100, 101)
      AND ehTrhS >= CONVERT(date, '20240801') AND ehTrhS < CONVERT(date, '20241101')
    GROUP BY ehstkID
),
son12 AS (         -- SONRAKİ 12 AY = SONUÇ
    SELECT ehstkID AS sid, CONVERT(int, -SUM(ehAdetN)) AS Satis
    FROM DerinSISBkm.dbo.irsHrk WITH (NOLOCK)
    WHERE ehMekan IN (1, 4477, 4478) AND ehTip IN (1, 3, 4, 5, 100, 101)
      AND ehTrhS >= CONVERT(date, '20250801') AND ehTrhS < CONVERT(date, '20260801')
    GROUP BY ehstkID
),
kat AS (
    SELECT DISTINCT stkID, Kategori3 FROM DerinSISBkm.bkm.SatisAnaliziTaban WITH (NOLOCK)
    WHERE Kesim = (SELECT MAX(Kesim) FROM DerinSISBkm.bkm.SatisAnaliziTaban) AND SezonYil = 2025
),
d AS (
    SELECT CASE WHEN k.Kategori3 IN (N'Kırtasiye', N'Hazırlık Kitapları') THEN k.Kategori3
                ELSE N'(panel geneli — 8 kategori)' END AS Grup,
           CONVERT(decimal(12,3), ISNULL(s.Satis, 0)) / b.Stok AS Devir,
           CASE WHEN b.Stok * 1.0 / s24.Satis < 2 THEN '1) <2x'
                WHEN b.Stok * 1.0 / s24.Satis < 3 THEN '2) 2-3x'
                WHEN b.Stok * 1.0 / s24.Satis < 4 THEN '3) 3-4x'
                WHEN b.Stok * 1.0 / s24.Satis < 5 THEN '4) 4-5x'
                WHEN b.Stok * 1.0 / s24.Satis < 8 THEN '5) 5-8x' ELSE '6) 8x+' END AS Bant
    FROM bas b
    JOIN s24 ON s24.sid = b.sid
    JOIN kat k ON k.stkID = b.sid
    LEFT JOIN son12 s ON s.sid = b.sid
    WHERE s24.Satis >= 5 AND b.Stok > 0
)
SELECT DISTINCT Grup, Bant,
       COUNT(*) OVER (PARTITION BY Grup, Bant) AS Cesit,
       CONVERT(decimal(6,2), PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY Devir)
               OVER (PARTITION BY Grup, Bant))                  AS MedyanDevir,
       CONVERT(decimal(6,2), AVG(Devir) OVER (PARTITION BY Grup, Bant)) AS OrtalamaDevir
FROM d
ORDER BY Grup, Bant;

/* ── 2) KIRTASİYE İNCE BANT — eşik neden TÜRETİLEMİYOR ──────────────────────────
   Medyan 0,67 · 0,75 · 0,78 · 0,75 · 0,62 · 0,30 → monoton DEĞİL, hepsi <1. */
WITH bas AS (
    SELECT ehstkID AS sid, SUM(ehAdetN) AS Stok FROM DerinSISBkm.dbo.irsHrk WITH (NOLOCK)
    WHERE ehMekan IN (1, 4477, 4478, 12) AND ehTrhS < CONVERT(date, '20250801') GROUP BY ehstkID
),
s24 AS (
    SELECT ehstkID AS sid, CONVERT(int, -SUM(ehAdetN)) AS Satis FROM DerinSISBkm.dbo.irsHrk WITH (NOLOCK)
    WHERE ehMekan IN (1, 4477, 4478) AND ehTip IN (1, 3, 4, 5, 100, 101)
      AND ehTrhS >= CONVERT(date, '20240801') AND ehTrhS < CONVERT(date, '20241101') GROUP BY ehstkID
),
son12 AS (
    SELECT ehstkID AS sid, CONVERT(int, -SUM(ehAdetN)) AS Satis FROM DerinSISBkm.dbo.irsHrk WITH (NOLOCK)
    WHERE ehMekan IN (1, 4477, 4478) AND ehTip IN (1, 3, 4, 5, 100, 101)
      AND ehTrhS >= CONVERT(date, '20250801') AND ehTrhS < CONVERT(date, '20260801') GROUP BY ehstkID
),
kat AS (
    SELECT DISTINCT stkID, Kategori3 FROM DerinSISBkm.bkm.SatisAnaliziTaban WITH (NOLOCK)
    WHERE Kesim = (SELECT MAX(Kesim) FROM DerinSISBkm.bkm.SatisAnaliziTaban) AND SezonYil = 2025
),
d AS (
    SELECT CONVERT(decimal(12,3), ISNULL(s.Satis, 0)) / b.Stok AS Devir,
           b.Stok * 1.0 / s24.Satis AS Kat
    FROM bas b JOIN s24 ON s24.sid = b.sid JOIN kat k ON k.stkID = b.sid
    LEFT JOIN son12 s ON s.sid = b.sid
    WHERE s24.Satis >= 5 AND b.Stok > 0 AND k.Kategori3 = N'Kırtasiye'
),
e AS (
    SELECT Devir, CASE WHEN Kat < 0.5 THEN '1) <0,5x' WHEN Kat < 1 THEN '2) 0,5-1x'
                       WHEN Kat < 1.5 THEN '3) 1-1,5x' WHEN Kat < 2 THEN '4) 1,5-2x'
                       WHEN Kat < 3 THEN '5) 2-3x' ELSE '6) 3x+' END AS Bant
    FROM d
)
SELECT DISTINCT Bant, COUNT(*) OVER (PARTITION BY Bant) AS Cesit,
       CONVERT(decimal(6,2), PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY Devir)
               OVER (PARTITION BY Bant)) AS MedyanDevir
FROM e ORDER BY Bant;

/* ── 3) ETKİ — bugünkü kategori bazlı eşik ↔ tek eşik 2× ────────────────────────
   Ölçüldü (kesim 11.09.2026): 30.361 → 40.017 çeşit · 72,5M → 83,3M ₺. */
DECLARE @k date = (SELECT MAX(Kesim) FROM DerinSISBkm.bkm.SatisAnaliziTaban);
WITH t AS (
    SELECT * FROM DerinSISBkm.bkm.SatisAnaliziTaban WITH (NOLOCK)
    WHERE Kesim = @k AND SezonYil = 2025
      AND StokFsm >= 0 AND StokOzl >= 0 AND StokIst >= 0 AND MerkezStok >= 0
      AND SatisFiyat > 0 AND SezonToplam > 0
),
e AS (
    SELECT *, (CASE Kategori3 WHEN N'Kırtasiye' THEN 2
                              WHEN N'Hazırlık Kitapları' THEN 8 ELSE 3 END) AS Bugun
    FROM t
)
SELECT 'ESKI (2/3/8 kategori bazli)' AS Senaryo,
       SUM(CASE WHEN ToplamStok > Bugun * SezonToplam THEN 1 ELSE 0 END) AS Cesit,
       CONVERT(decimal(18,0), SUM(CASE WHEN ToplamStok > Bugun * SezonToplam AND BirimMaliyet > 0
            THEN CONVERT(decimal(18,4), ToplamStok - Bugun * SezonToplam) * BirimMaliyet
            ELSE 0 END)) AS FazlaMaliyet
FROM e
UNION ALL
SELECT 'YENI (tek esik 2x, medyanla)',
       SUM(CASE WHEN ToplamStok > 2 * SezonToplam THEN 1 ELSE 0 END),
       CONVERT(decimal(18,0), SUM(CASE WHEN ToplamStok > 2 * SezonToplam AND BirimMaliyet > 0
            THEN CONVERT(decimal(18,4), ToplamStok - 2 * SezonToplam) * BirimMaliyet ELSE 0 END))
FROM e;
