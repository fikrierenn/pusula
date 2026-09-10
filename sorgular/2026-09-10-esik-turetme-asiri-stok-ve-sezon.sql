/* ═══════════════════════════════════════════════════════════════════════════════
   EŞİK TÜRETME — "aşırı stok" ve "sezon hazırlığı" katsayıları        10.09.2026

   Kullanıcı: "aşırı-stok 5× ve sezon 0,5 katsayıları hâlâ geçici, verilerden sen çıkar".

   Bu iki eşik panelde SEÇİLMİŞ (ölçülmemiş) olarak duruyordu; hedef gün-stok
   politikası `bkm.OneriSiparisKtg3Ondeger` tanımlı ama BOŞ olduğu için geçiciydi.
   Aşağıdaki iki analiz eşikleri GEÇMİŞİN SONUCUNDAN türetiyor.

   ── ÖLÇÜT SEÇİMİ: iki kötü aday elendi ────────────────────────────────────────
   (a) "Sezon sonunda stok ≤ 0" → tükenme vekili olarak DENENDİ, ELENDİ.
       Bantlara göre %0,4-6,6 arası ve TEK YÖNLÜ DEĞİL. Sebep: sezon içinde depodan
       takviye yapılıyor, sezon-sonu stoğu tükenmeyi göstermiyor.
   (b) Karşılanmamış talep → GÖZLENEMEZ. Satmadığın şeyin kaydı yok.
   ⇒ Kullanılan ölçüt: AYNI TALEP BANDI içinde gerçekleşen satış. Talep vekili
     önceki yılın aynı sezonu; böylece "az stokladı çünkü az satacaktı" kısmen sabitlenir.

   ═══ 1) SEZON HAZIRLIĞI — mevcut 0,5 katsayısı DOĞRULANDI ═══════════════════
   Talep bandı: 2024 sezonu (Ağu-Eki) satışı 10-200 adet. Kapsama = 01.08.2025
   itibarıyla mağaza rafı ÷ 2024 sezon satışı. Sonuç = 2025 sezon satışı ÷ 2024.

     kapsama      çeşit  talep24  satış25  GERÇEKLEŞME
     <0,25        2.092     54       23       0,34
     0,25-0,50    2.454     45       33       0,61
     0,50-0,75    2.274     38       30       0,75
     0,75-1,00    1.503     37       33       0,84
     1,00-1,50    2.039     33       32       0,93
     1,50-3,00    2.387     29       38       1,24
     3,00+        1.862     27       62       2,22

   Tek yönlü ve alt uçta dik. Gerçekleşme 1,00 kapsamada doyuyor (0,93).
   ⇒ KARAR: 0,50 eşiği KALIYOR — altında gerçekleşme ≤0,61, yani önceki yıl
     talebinin en az %39'u kaybediliyor. "Yeterli" çizgisi ise 1,00 (0,93).
     Eşik seçilmiş değil artık: 0,50 gerçekleşmenin çöktüğü yer.

   ⚠ CONFOUND (giderilmedi, açıkça yazılıyor): TERS NEDENSELLİK. Alıcı çok satmasını
     beklediği ürüne çok stok koyar → yüksek kapsama zaten yüksek beklentiyi taşıyor
     (3,00+ bandında gerçekleşme 2,22 = o ürünler büyüdü). Ayrıca ORTALAMAYA DÖNÜŞ:
     <0,25 bandı en yüksek 2024 talebine sahip (54) — o ürünler zaten aşağı çekilecekti.
     Yani tablo saf "bulunurluk etkisi" DEĞİL. Ama alt uçtaki düşüş (0,34) yalnız
     ortalamaya dönüşle açıklanamayacak kadar büyük.

   ═══ 2) AŞIRI STOK — mevcut 5× GEVŞEK çıktı, 3× türetildi ═══════════════════
   Kat = 01.08.2025 itibarıyla toplam stok (mağaza+merkez) ÷ 2024 sezon satışı.
   Sonuç = SONRAKİ 12 AYDA satılan ÷ başlangıç stoğu (yıllık devir).

     kat        çeşit  yıllık devir  karşılığı        hiç satmayan %
     <2×        5.762     6,36        ~2 ay stok          16,2
     2-3×       1.088     1,04        ~12 ay              8,4
     3-5×       1.350     0,71        ~17 ay              6,9
     5-8×         980     0,51        ~24 ay              3,8
     8-15×      1.000     0,40        ~30 ay              3,3
     15×+         997     0,23        ~52 ay (4,3 yıl)    2,7

   ⇒ KARAR: eşik 5× → **3×**. Gerekçe: yıllık devrin 1,0'ın ALTINA düştüğü yer 3×
     (2-3× bandı 1,04 ile tam bir yıllık stok). 5× zaten ~24 aylık stok demek —
     o eşik "aşırı"yı ancak iki yılı geçince yakalıyordu.
   Etki (kesim 09.09.2026): 16.697 çeşit / 238,0M ₺ → **29.647 çeşit / 309,9M ₺**
   etiket; maliyetle **107,3M ₺** (asıl bağlı sermaye).

   ⚠ CONFOUND: "yıllık devir" hem stok düzeyini hem talep değişimini taşır; <2×
     bandının 6,36'sı o ürünlerin sürekli takviye edildiğini gösteriyor (az stoklu,
     hızlı dönen). Ölçüt "aşırılık" değil DEVİR ölçüyor — ama karar değişkeni de
     zaten devir: 1,0 altı = bir yıldan fazla stok.

   ⚠ 15×+ bandı 35,5M adet taşıyor (diğer bantların ~100 katı) — kütle uçta ve onu
     5× de yakalıyordu. 5×→3× değişimi 12.950 çeşit / ~72M ₺ etiket ekliyor.

   İlgili: sema/metrics.yaml → asiri_stok_esigi_turetildi · sezon_hazirlik_esigi_turetildi
   Kod: dashboard/Data/SatisAnaliziQueries.cs (AsiriKat / SezonHazirlikSart)
   ═══════════════════════════════════════════════════════════════════════════════ */

SET NOCOUNT ON;

/* ── 1) SEZON: kapsama → gerçekleşme (aynı talep bandı) ─────────────────────── */
WITH bas AS (   -- 31.07.2025 itibarıyla mağaza rafı (as-of, defterden)
    SELECT ehstkID AS sid, SUM(ehAdetN) AS Stok
    FROM DerinSISBkm.dbo.irsHrk WITH (NOLOCK)
    WHERE ehMekan IN (1, 4477, 4478) AND ehTrhS < CONVERT(date, '20250801')
    GROUP BY ehstkID
),
s24 AS (        -- 2024 sezonu (Ağu-Eki) mağaza satışı = TALEP VEKİLİ
    SELECT ehstkID AS sid, CONVERT(int, -SUM(ehAdetN)) AS Satis
    FROM DerinSISBkm.dbo.irsHrk WITH (NOLOCK)
    WHERE ehMekan IN (1, 4477, 4478) AND ehTip IN (1, 3, 4, 5, 100, 101)
      AND ehTrhS >= CONVERT(date, '20240801') AND ehTrhS < CONVERT(date, '20241101')
    GROUP BY ehstkID
),
s25 AS (        -- 2025 sezonu = SONUÇ
    SELECT ehstkID AS sid, CONVERT(int, -SUM(ehAdetN)) AS Satis
    FROM DerinSISBkm.dbo.irsHrk WITH (NOLOCK)
    WHERE ehMekan IN (1, 4477, 4478) AND ehTip IN (1, 3, 4, 5, 100, 101)
      AND ehTrhS >= CONVERT(date, '20250801') AND ehTrhS < CONVERT(date, '20251101')
    GROUP BY ehstkID
),
d AS (
    SELECT s24.sid, s24.Satis AS T24, ISNULL(s25.Satis, 0) AS T25,
           CONVERT(decimal(10,3), ISNULL(bas.Stok, 0) * 1.0 / s24.Satis) AS Kapsama
    FROM s24
    LEFT JOIN s25 ON s25.sid = s24.sid
    LEFT JOIN bas ON bas.sid = s24.sid
    WHERE s24.Satis BETWEEN 10 AND 200 AND ISNULL(bas.Stok, 0) > 0
)
SELECT CASE WHEN Kapsama < 0.25 THEN '1) <0,25' WHEN Kapsama < 0.50 THEN '2) 0,25-0,50'
            WHEN Kapsama < 0.75 THEN '3) 0,50-0,75' WHEN Kapsama < 1.00 THEN '4) 0,75-1,00'
            WHEN Kapsama < 1.50 THEN '5) 1,00-1,50' WHEN Kapsama < 3.00 THEN '6) 1,50-3,00'
            ELSE '7) 3,00+' END AS Bant,
       COUNT(*) AS Cesit, CONVERT(int, AVG(T24)) AS Talep2024,
       CONVERT(int, AVG(T25)) AS Satis2025,
       CONVERT(decimal(5,2), AVG(CONVERT(decimal(10,3), T25) / T24)) AS GerceklesmeOrani
FROM d
GROUP BY CASE WHEN Kapsama < 0.25 THEN '1) <0,25' WHEN Kapsama < 0.50 THEN '2) 0,25-0,50'
              WHEN Kapsama < 0.75 THEN '3) 0,50-0,75' WHEN Kapsama < 1.00 THEN '4) 0,75-1,00'
              WHEN Kapsama < 1.50 THEN '5) 1,00-1,50' WHEN Kapsama < 3.00 THEN '6) 1,50-3,00'
              ELSE '7) 3,00+' END
ORDER BY 1;

/* ── 2) AŞIRI STOK: kat → sonraki 12 ayın devri ─────────────────────────────── */
WITH bas AS (   -- toplam stok (mağaza + MERKEZ), 01.08.2025 itibarıyla
    SELECT ehstkID AS sid, SUM(ehAdetN) AS Stok
    FROM DerinSISBkm.dbo.irsHrk WITH (NOLOCK)
    WHERE ehMekan IN (1, 4477, 4478, 12) AND ehTrhS < CONVERT(date, '20250801')
    GROUP BY ehstkID
),
s24 AS (
    SELECT ehstkID AS sid, CONVERT(int, -SUM(ehAdetN)) AS Satis
    FROM DerinSISBkm.dbo.irsHrk WITH (NOLOCK)
    WHERE ehMekan IN (1, 4477, 4478) AND ehTip IN (1, 3, 4, 5, 100, 101)
      AND ehTrhS >= CONVERT(date, '20240801') AND ehTrhS < CONVERT(date, '20241101')
    GROUP BY ehstkID
),
son12 AS (      -- SONRAKİ 12 AY
    SELECT ehstkID AS sid, CONVERT(int, -SUM(ehAdetN)) AS Satis
    FROM DerinSISBkm.dbo.irsHrk WITH (NOLOCK)
    WHERE ehMekan IN (1, 4477, 4478) AND ehTip IN (1, 3, 4, 5, 100, 101)
      AND ehTrhS >= CONVERT(date, '20250801') AND ehTrhS < CONVERT(date, '20260801')
    GROUP BY ehstkID
),
d AS (
    SELECT bas.sid, bas.Stok, ISNULL(son12.Satis, 0) AS S12,
           CONVERT(decimal(12,2), bas.Stok * 1.0 / s24.Satis) AS Kat
    FROM bas
    JOIN s24 ON s24.sid = bas.sid
    LEFT JOIN son12 ON son12.sid = bas.sid
    WHERE s24.Satis >= 5 AND bas.Stok > 0
)
SELECT CASE WHEN Kat < 2 THEN '1) <2x' WHEN Kat < 3 THEN '2) 2-3x' WHEN Kat < 5 THEN '3) 3-5x'
            WHEN Kat < 8 THEN '4) 5-8x' WHEN Kat < 15 THEN '5) 8-15x' ELSE '6) 15x+' END AS Bant,
       COUNT(*) AS Cesit,
       CONVERT(decimal(5,2), AVG(CONVERT(decimal(12,3), S12) / Stok)) AS YillikDevir,
       CONVERT(decimal(5,1), 100.0 * SUM(CASE WHEN S12 = 0 THEN 1 ELSE 0 END) / COUNT(*)) AS HicSatmayanYuzde,
       CONVERT(bigint, SUM(Stok)) AS StokAdet
FROM d
GROUP BY CASE WHEN Kat < 2 THEN '1) <2x' WHEN Kat < 3 THEN '2) 2-3x' WHEN Kat < 5 THEN '3) 3-5x'
              WHEN Kat < 8 THEN '4) 5-8x' WHEN Kat < 15 THEN '5) 8-15x' ELSE '6) 15x+' END
ORDER BY 1;

/* ── 3) EŞİK DEĞİŞİMİNİN ETKİSİ (kesim 09.09.2026) ─────────────────────────── */
SELECT
    SUM(CASE WHEN SezonToplam > 0 AND ToplamStok > 5 * SezonToplam THEN 1 ELSE 0 END) AS Esik5_Cesit,
    CONVERT(decimal(18,2), SUM(CASE WHEN SezonToplam > 0 AND ToplamStok > 5 * SezonToplam
         THEN Tutar ELSE 0 END))                                                      AS Esik5_Tutar,
    SUM(CASE WHEN SezonToplam > 0 AND ToplamStok > 3 * SezonToplam THEN 1 ELSE 0 END) AS Esik3_Cesit,
    CONVERT(decimal(18,2), SUM(CASE WHEN SezonToplam > 0 AND ToplamStok > 3 * SezonToplam
         THEN Tutar ELSE 0 END))                                                      AS Esik3_Tutar,
    CONVERT(decimal(18,2), SUM(CASE WHEN SezonToplam > 0 AND ToplamStok > 3 * SezonToplam
         AND BirimMaliyet > 0 THEN CONVERT(decimal(18,4), ToplamStok) * BirimMaliyet ELSE 0 END))
                                                                                      AS Esik3_Maliyetli
FROM DerinSISBkm.bkm.SatisAnaliziTaban WITH (NOLOCK)
WHERE Kesim = '2026-09-09' AND SezonYil = 2025;
