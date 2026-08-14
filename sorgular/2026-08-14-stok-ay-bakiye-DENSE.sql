/*
  bkm.StokAyBakiyeMekanBazli — ŞUBE bölümü YOĞUNLAŞTIRMA (plan-33 B-133b, kullanıcı önerisi 2026-08-14).
  DEĞİŞİKLİK: eski script sadece HAREKETLİ aylara satır yazıyordu (sparse) → tüketiciler carry-forward yapmak
  zorunda. Yeni: SON @DENSE_AY ay YOĞUN — her ay satır (0 DAHİL = explicit kuru); öncesi sparse (boyut için).
  ETKİ: availability = direkt 'o ay satır Stok≥eşik', carry-forward GEREKSİZ, OOS = direkt COUNT.
  Schema DEĞİŞMEZ (Stok=0 geçerli, PK dense taşır) → DROP/CREATE yok, sadece re-populate (idempotent).
  BOYUT: ölçüldü ~2,56M(son24)→~13,3M üst-sınır + eski sparse ≈ 12-15M toplam (~2×). Yönetilebilir.
  GERİYE UYUMLU: 'Donem<=@ay ORDER BY Donem DESC' deseni yine çalışır (artık tam ayı bulur).
  ⚠ Bu SADECE Kaynak='irsHrk' (şube) bölümünü değiştirir. Depo (WMS) bölümü orijinal scriptten aynen kalır.
  ÇALIŞTIRMADAN ÖNCE: 591060 doğrulama (aşağıda) — dense satırlar bilinen bakiyeyle (157/131/118/72/59) tutmalı
  + kuru aylar explicit 0 olmalı. Satınalma stoklu_ay RE-VALIDATE (birebir).
*/
SET NOCOUNT ON;

DECLARE @denseCut date = EOMONTH(DATEADD(month, -36, GETDATE()));   -- yoğun pencere başı (son 36 ay)
DECLARE @sonAyG  date = EOMONTH(GETDATE());

-- ŞUBE (mekan 1,4477,4478) — irsHrk ehAltDepo=0. İDEMPOTENT (irsHrk bölümünü tam yeniden kurar).
DELETE FROM bkm.StokAyBakiyeMekanBazli WHERE Kaynak = 'irsHrk';

;WITH aylik_delta AS (                         -- ürün×mekan×ay net hareket (ehAltDepo=0)
    SELECT h.ehstkID, h.ehMekan, EOMONTH(h.ehTrhS) AS Donem, SUM(h.ehAdetN) AS delta
    FROM dbo.irsHrk h WITH(NOLOCK)
    WHERE h.ehAltDepo = 0 AND h.ehMekan IN (1, 4477, 4478)
    GROUP BY h.ehstkID, h.ehMekan, EOMONTH(h.ehTrhS)
),
sparse_bakiye AS (                             -- ESKİ (< @denseCut): running-total sadece hareketli ay (mevcut davranış)
    SELECT ehstkID, ehMekan, Donem,
           SUM(delta) OVER (PARTITION BY ehstkID, ehMekan ORDER BY Donem ROWS UNBOUNDED PRECEDING) AS Stok
    FROM aylik_delta
),
pairs AS (                                     -- carried çiftler + ilk hareket ayı
    SELECT ehstkID, ehMekan, MIN(Donem) AS ilk_ay FROM aylik_delta GROUP BY ehstkID, ehMekan
),
spine AS (                                     -- son 36 ay EOMONTH omurgası
    SELECT EOMONTH(DATEADD(month, n, @denseCut)) AS Donem
    FROM (SELECT TOP 60 ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS n FROM sys.all_objects) x
    WHERE EOMONTH(DATEADD(month, n, @denseCut)) <= @sonAyG
),
opening AS (                                   -- pencereye GİRİŞ bakiyesi (< @denseCut kümülatif)
    SELECT ehstkID, ehMekan, SUM(delta) AS acilis
    FROM aylik_delta WHERE Donem < @denseCut GROUP BY ehstkID, ehMekan
),
dense_bakiye AS (                              -- YOĞUN: carried-pair × spine-ay (pair var olduğundan beri), balance = açılış + pencere-içi kümülatif
    SELECT p.ehstkID, p.ehMekan, s.Donem,
       ISNULL(o.acilis,0)
       + ISNULL(SUM(ad.delta) OVER (PARTITION BY p.ehstkID, p.ehMekan ORDER BY s.Donem ROWS UNBOUNDED PRECEDING),0) AS Stok
    FROM pairs p
    JOIN spine s ON s.Donem >= CASE WHEN p.ilk_ay > @denseCut THEN p.ilk_ay ELSE @denseCut END
    LEFT JOIN opening o ON o.ehstkID = p.ehstkID AND o.ehMekan = p.ehMekan
    LEFT JOIN aylik_delta ad ON ad.ehstkID = p.ehstkID AND ad.ehMekan = p.ehMekan AND ad.Donem = s.Donem
)
INSERT INTO bkm.StokAyBakiyeMekanBazli (Donem, stkID, ehMekan, Stok, Kaynak)
SELECT Donem, ehstkID, ehMekan, CASE WHEN Stok < 0 THEN 0 ELSE CONVERT(int, Stok) END, 'irsHrk'
FROM sparse_bakiye WHERE Donem < @denseCut                    -- eski: sparse
UNION ALL
SELECT Donem, ehstkID, ehMekan, CASE WHEN Stok < 0 THEN 0 ELSE CONVERT(int, Stok) END, 'irsHrk'
FROM dense_bakiye;                                            -- son 36 ay: dense (0 dahil)

-- ÖZET
SELECT Kaynak, COUNT(*) satir, COUNT(DISTINCT stkID) urun, MIN(Donem) ilk, MAX(Donem) son,
       SUM(CASE WHEN Stok=0 THEN 1 ELSE 0 END) sifir_satir
FROM bkm.StokAyBakiyeMekanBazli WHERE Kaynak='irsHrk' GROUP BY Kaynak;

-- DOĞRULAMA (591060 mekan 1 — dense aylar bilinen bakiyeyle tutmalı + kuru aylar explicit 0):
-- SELECT Donem, Stok FROM bkm.StokAyBakiyeMekanBazli WHERE stkID=591060 AND ehMekan=1 AND Kaynak='irsHrk' AND Donem>='20250101' ORDER BY Donem;
--   beklenen: 2025-05..12 dolu (193..59), 2026-01..06 = 59 (taşındı, hareketsiz), sonra düşer.
