/* ═══════════════════════════════════════════════════════════════════════════════
   AŞIRI STOK EŞİĞİ KATEGORİ BAZINDA TÜRETİLDİ                        10.09.2026

   Panel geneli 3× eşiği bir sorun taşıyordu: ölçülen yıllık devir Kırtasiye 1,25 ile
   Dergi 5,95 arasında değişirken ikisi AYNI eşiği paylaşıyordu.

   ⚠ `bkm.OneriSiparisKtg3Ondeger` (hedef gün-stok politika tablosu) kullanıcı kararıyla
   İPTAL EDİLDİ (10.09.2026: "bu iptal buna takılma"). Eşik artık ÖLÇÜMDEN gelir,
   politika tablosundan değil. Kod: `SatisAnaliziQueries.AsiriStokKatSql`.

   ═══ YÖNTEM (panel geneli 3× ile AYNI) ══════════════════════════════════════
   01.08.2025 kapsama katı (toplam stok ÷ 2024 Ağu-Eki satışı) bantlarına göre SONRAKİ
   12 AYIN yıllık devri (satılan ÷ başlangıç stoğu). Devrin 1,0 ALTINA düştüğü kat =
   o kategorinin eşiği ("bir yıldan fazla stok" çizgisi).
   Bant başına en az 30 çeşit şartı (altındakiler raporlanmaz).

   ═══ ÖLÇÜM — yıllık devir, bant sırası <2× · 2-3× · 3-5× · 5-8× · 8×+ ══════
     Kırtasiye           4,78 · [0,93] · 0,64 · 0,49 · 0,31    MONOTON  ⇒ eşik 2×
     Hazırlık Kitapları 11,68 ·  2,14  · 1,93 · [1,20] · 0,28  MONOTON  ⇒ eşik 8×
     Çocuk Kitabı        5,57 ·  1,36  · 1,06 · (n<30) · 0,30  BANT EKSİK   ⇒ 3× kaldı
     Oyuncak             3,21 ·  0,94  · [1,13] · 0,61 · 0,42  MONOTON DEĞİL ⇒ 3× kaldı
     Hediyelik           4,81 · (n<30) · 0,42 · (n<30) · 0,38  BANT EKSİK   ⇒ 3× kaldı
     Akademi 2,82 · Dergi 48,95 · Elektronik 2,45 · Kitap 3,66 — yalnız <2× bandı n≥30
       ⇒ TÜRETİLEMEDİ, 3× kaldı
   ⇒ Yalnız İKİ kategori değişti: kanıtı monoton ve bantları dolu olanlar.
     Kalan sekizde panel geneli duruyor — "ölçemediğimi değiştirmem".

   ═══ ETKİ (kesim 09.09.2026, güvenilir defter) ══════════════════════════════
     Kırtasiye           9.897 → 11.679 çeşit · 219.793.233 → 247.578.941 ₺  (+27,8M)
       eşik SIKILAŞTI (2×) çünkü devri yavaş: 1,25
     Hazırlık Kitapları  1.427 →    460 çeşit ·  11.899.218 →   4.930.648 ₺  (−7,0M)
       eşik GEVŞEDİ (8×) çünkü devri hızlı: 3,16 → haksız "aşırı" damgası kalktı
     Diğer sekiz kategori DEĞİŞMEDİ.
     Panel toplamı: 308,3M ₺ / 29.628 çeşit → 329,0M ₺ / 30.439 çeşit (panelde doğrulandı;
     kart → filtre → liste 30.439 birebir).

   ⚠ CONFOUND'LAR DEĞİŞMEDİ, aynen geçerli:
     · TERS NEDENSELLİK — alıcı çok satmasını beklediğine çok stok koyar
     · Veriden seçilen kesimin bedeli (Altman & Royston 2006) — kesimdeki fark bir ETKİ
       ÖLÇÜSÜ olarak sunulmaz, yalnız kohort seçiminde kullanılır
     · "Yıllık devir" hem stok düzeyini hem talep değişimini taşır
   ⚠ Kategori kırılımı örneklemi böler: 10 kategori × 5 bant = 50 hücre, çoğu n<30.
     Bu yüzden 8 kategoride eşik türetilemedi — küçültme daha fazla kırılım kaldırmaz.

   Kural: .claude/rules/olctum-mu-cikardim-mi.md § EŞİK TÜRETME
   Sema: sema/metrics.yaml → asiri_stok_esigi_kategori_bazli
   ═══════════════════════════════════════════════════════════════════════════════ */

SET NOCOUNT ON;

/* ── 1) Kategori × kapsama katı → sonraki 12 ayın yıllık devri ──────────────── */
WITH bas AS (   -- 01.08.2025 itibarıyla toplam stok (mağaza + merkez)
    SELECT ehstkID AS sid, SUM(ehAdetN) AS Stok
    FROM DerinSISBkm.dbo.irsHrk WITH (NOLOCK)
    WHERE ehMekan IN (1, 4477, 4478, 12) AND ehTrhS < CONVERT(date, '20250801')
    GROUP BY ehstkID
),
s24 AS (        -- 2024 sezonu (Ağu-Eki) = TALEP VEKİLİ
    SELECT ehstkID AS sid, CONVERT(int, -SUM(ehAdetN)) AS Satis
    FROM DerinSISBkm.dbo.irsHrk WITH (NOLOCK)
    WHERE ehMekan IN (1, 4477, 4478) AND ehTip IN (1, 3, 4, 5, 100, 101)
      AND ehTrhS >= CONVERT(date, '20240801') AND ehTrhS < CONVERT(date, '20241101')
    GROUP BY ehstkID
),
son12 AS (      -- SONRAKİ 12 AY = SONUÇ
    SELECT ehstkID AS sid, CONVERT(int, -SUM(ehAdetN)) AS Satis
    FROM DerinSISBkm.dbo.irsHrk WITH (NOLOCK)
    WHERE ehMekan IN (1, 4477, 4478) AND ehTip IN (1, 3, 4, 5, 100, 101)
      AND ehTrhS >= CONVERT(date, '20250801') AND ehTrhS < CONVERT(date, '20260801')
    GROUP BY ehstkID
),
kat AS (        -- kategori panel evreninden (Kategori3Evreni ile aynı 10 değer)
    SELECT DISTINCT stkID, Kategori3
    FROM DerinSISBkm.bkm.SatisAnaliziTaban WITH (NOLOCK)
    WHERE Kesim = '2026-09-09' AND SezonYil = 2025
),
d AS (
    SELECT k.Kategori3, b.Stok, ISNULL(s.Satis, 0) AS S12,
           CONVERT(decimal(12,2), b.Stok * 1.0 / s24.Satis) AS Kat
    FROM bas b
    JOIN s24 ON s24.sid = b.sid
    JOIN kat k ON k.stkID = b.sid
    LEFT JOIN son12 s ON s.sid = b.sid
    WHERE s24.Satis >= 5 AND b.Stok > 0
)
SELECT Kategori3,
       CASE WHEN Kat < 2 THEN '1) <2x' WHEN Kat < 3 THEN '2) 2-3x' WHEN Kat < 5 THEN '3) 3-5x'
            WHEN Kat < 8 THEN '4) 5-8x' ELSE '5) 8x+' END AS Bant,
       COUNT(*) AS Cesit,
       CONVERT(decimal(5,2), AVG(CONVERT(decimal(12,3), S12) / Stok)) AS YillikDevir
FROM d
GROUP BY Kategori3,
         CASE WHEN Kat < 2 THEN '1) <2x' WHEN Kat < 3 THEN '2) 2-3x' WHEN Kat < 5 THEN '3) 3-5x'
              WHEN Kat < 8 THEN '4) 5-8x' ELSE '5) 8x+' END
HAVING COUNT(*) >= 30          -- ⚠ altındaki hücreler GÜVENİLMEZ, raporlanmaz
ORDER BY Kategori3, Bant;

/* ── 2) Eşik değişiminin etkisi — panel ölçütüyle AYNI kohort ───────────────── */
WITH t AS (
    SELECT * FROM DerinSISBkm.bkm.SatisAnaliziTaban WITH (NOLOCK)
    WHERE Kesim = '2026-09-09' AND SezonYil = 2025
      AND StokFsm >= 0 AND StokOzl >= 0 AND StokIst >= 0 AND MerkezStok >= 0 AND SatisFiyat > 0
      AND SezonToplam > 0
)
SELECT Kategori3,
       SUM(CASE WHEN ToplamStok > 3 * SezonToplam THEN 1 ELSE 0 END) AS Esik3_Cesit,
       CONVERT(decimal(18,2), SUM(CASE WHEN ToplamStok > 3 * SezonToplam
             THEN Tutar ELSE 0 END))                                AS Esik3_TL,
       SUM(CASE WHEN ToplamStok > (CASE Kategori3
                                        WHEN N'Kırtasiye' THEN 2
                                        WHEN N'Hazırlık Kitapları' THEN 8
                                        ELSE 3 END) * SezonToplam
                THEN 1 ELSE 0 END)                                  AS Yeni_Cesit,
       CONVERT(decimal(18,2), SUM(CASE WHEN ToplamStok > (CASE Kategori3
                                        WHEN N'Kırtasiye' THEN 2
                                        WHEN N'Hazırlık Kitapları' THEN 8
                                        ELSE 3 END) * SezonToplam
             THEN Tutar ELSE 0 END))                                AS Yeni_TL
FROM t
GROUP BY Kategori3
HAVING SUM(CASE WHEN ToplamStok > 3 * SezonToplam THEN 1 ELSE 0 END) > 0
ORDER BY Esik3_TL DESC;
