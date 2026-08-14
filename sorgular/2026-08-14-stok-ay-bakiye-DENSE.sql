/*
  bkm.StokAyBakiyeMekanBazli — ŞUBE bölümü YOĞUNLAŞTIRMA v2 (TEMP-TABLE, plan-33 B-133b).
  v1 (CTE) YAVAŞTI: CTE materialize edilmez → aylik_delta 4× tekrar hesaplandı + cross-join sort → 3dk+ takıldı.
  v2: #delta bir kez + CLUSTERED INDEX → seek; dense = #pairs×#spine indexli, window STREAMING (sort yok).

  ⚠ ÖNCE PRODUCTION RESTORE: v1 takıldıysa KILL <spid> + orijinal sparse script çalıştır (tablo boş kalmasın).
  Sonra bu v2'yi çalıştır. İdempotent (irsHrk bölümünü tam yeniden kurar). Depo (WMS) bölümü orijinal scriptte.

  DEĞİŞİKLİK: SON 36 ay YOĞUN (her ay satır, 0 dahil = explicit kuru), öncesi sparse. Availability = direkt
  'o ay satır Stok≥eşik' (carry-forward gereksiz). Schema DEĞİŞMEZ. ~2× boyut. GERİYE UYUMLU.
*/
SET NOCOUNT ON;

DECLARE @denseCut date = EOMONTH(DATEADD(month, -36, GETDATE()));
DECLARE @sonAyG  date = EOMONTH(GETDATE());

-- 1) #delta — ürün×mekan×ay net hareket (ehAltDepo=0). BİR KEZ + index.
IF OBJECT_ID('tempdb..#delta') IS NOT NULL DROP TABLE #delta;
SELECT h.ehstkID, h.ehMekan, EOMONTH(h.ehTrhS) AS Donem, SUM(h.ehAdetN) AS delta
INTO #delta
FROM dbo.irsHrk h WITH(NOLOCK)
WHERE h.ehAltDepo = 0 AND h.ehMekan IN (1, 4477, 4478)
GROUP BY h.ehstkID, h.ehMekan, EOMONTH(h.ehTrhS);
CREATE CLUSTERED INDEX ix_delta ON #delta (ehstkID, ehMekan, Donem);

-- 2) #sparse — running-total ay-sonu bakiye (hareketli aylarda). Eski (<cut) bölüm buradan gider.
IF OBJECT_ID('tempdb..#sparse') IS NOT NULL DROP TABLE #sparse;
SELECT ehstkID, ehMekan, Donem,
       SUM(delta) OVER (PARTITION BY ehstkID, ehMekan ORDER BY Donem ROWS UNBOUNDED PRECEDING) AS Stok
INTO #sparse
FROM #delta;
CREATE CLUSTERED INDEX ix_sparse ON #sparse (ehstkID, ehMekan, Donem);

-- 3) #pairs (ilk ay) + #opening (pencereye giriş = <cut kümülatif)
IF OBJECT_ID('tempdb..#pairs') IS NOT NULL DROP TABLE #pairs;
SELECT ehstkID, ehMekan, MIN(Donem) AS ilk_ay INTO #pairs FROM #delta GROUP BY ehstkID, ehMekan;

IF OBJECT_ID('tempdb..#opening') IS NOT NULL DROP TABLE #opening;
SELECT ehstkID, ehMekan, SUM(delta) AS acilis INTO #opening FROM #delta WHERE Donem < @denseCut GROUP BY ehstkID, ehMekan;
CREATE CLUSTERED INDEX ix_open ON #opening (ehstkID, ehMekan);

-- 4) #spine — son 36 ay EOMONTH
IF OBJECT_ID('tempdb..#spine') IS NOT NULL DROP TABLE #spine;
SELECT Donem INTO #spine FROM (
    SELECT EOMONTH(DATEADD(month, n, @denseCut)) AS Donem
    FROM (SELECT TOP 60 ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS n FROM sys.all_objects) x
) s WHERE Donem <= @sonAyG;

-- 5) #db — dense taban: pair × spine (pair var olduğundan beri) + o ayın delta'sı + açılış. Indexli → window streaming.
IF OBJECT_ID('tempdb..#db') IS NOT NULL DROP TABLE #db;
SELECT p.ehstkID, p.ehMekan, s.Donem, ISNULL(d.delta, 0) AS delta, ISNULL(o.acilis, 0) AS acilis
INTO #db
FROM #pairs p
JOIN #spine s ON s.Donem >= CASE WHEN p.ilk_ay > @denseCut THEN p.ilk_ay ELSE @denseCut END
LEFT JOIN #delta d ON d.ehstkID = p.ehstkID AND d.ehMekan = p.ehMekan AND d.Donem = s.Donem
LEFT JOIN #opening o ON o.ehstkID = p.ehstkID AND o.ehMekan = p.ehMekan;
CREATE CLUSTERED INDEX ix_db ON #db (ehstkID, ehMekan, Donem);

-- 6) YAZ — ATOMİK (failure-safe nightly: hata → rollback, eski veri korunur). Temp'ler yukarıda hazır → tran kısa.
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;
    DELETE FROM bkm.StokAyBakiyeMekanBazli WHERE Kaynak = 'irsHrk';

    INSERT INTO bkm.StokAyBakiyeMekanBazli (Donem, stkID, ehMekan, Stok, Kaynak)
    SELECT Donem, ehstkID, ehMekan, CASE WHEN Stok < 0 THEN 0 ELSE CONVERT(int, Stok) END, 'irsHrk'
    FROM #sparse WHERE Donem < @denseCut                          -- eski: sparse
    UNION ALL
    SELECT Donem, ehstkID, ehMekan,
           CASE WHEN acilis + SUM(delta) OVER (PARTITION BY ehstkID, ehMekan ORDER BY Donem ROWS UNBOUNDED PRECEDING) < 0
                THEN 0
                ELSE CONVERT(int, acilis + SUM(delta) OVER (PARTITION BY ehstkID, ehMekan ORDER BY Donem ROWS UNBOUNDED PRECEDING)) END,
           'irsHrk'
    FROM #db;                                                     -- son 36 ay: dense (0 dahil)
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;   -- hata → eski irsHrk verisi geri gelir (boş kalmaz)
    THROW;
END CATCH

DROP TABLE #delta, #sparse, #pairs, #opening, #spine, #db;

-- ÖZET + doğrulama
SELECT Kaynak, COUNT(*) satir, COUNT(DISTINCT stkID) urun, MIN(Donem) ilk, MAX(Donem) son,
       SUM(CASE WHEN Stok=0 THEN 1 ELSE 0 END) sifir_satir
FROM bkm.StokAyBakiyeMekanBazli WHERE Kaynak='irsHrk' GROUP BY Kaynak;
-- 591060 mekan 1: 2025-05..12 dolu (193..59), 2026-01..06 = 59 taşındı, kuru aylar explicit 0.
-- SELECT Donem, Stok FROM bkm.StokAyBakiyeMekanBazli WHERE stkID=591060 AND ehMekan=1 AND Kaynak='irsHrk' AND Donem>='20250101' ORDER BY Donem;
