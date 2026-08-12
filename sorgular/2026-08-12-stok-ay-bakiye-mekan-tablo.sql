/*
  bkm.StokAyBakiyeMekanBazli — mekan-bazlı AYLIK ay-sonu stok bakiyesi (kalıcı geçmiş).
  Amaç: irsHrk ledger'ın mutlak bazı bozuk (depo mekan 12 geçmişte negatife gider) → raporlarda
        geçmiş stok reconstruct edilemiyordu. Bu tablo güvenilir aylık stoğu SAKLAR.

  RELIABILITY (KRİTİK):
   • ŞUBE (mekan 1=FSM, 4477=Özlüce, 4478=İst.Yolu): irsHrk ehAltDepo=0 kümülatif = stokSon ile BİREBİR
     → GÜVENİLİR, tüm geçmiş backfill edilebilir. (Transit mekan 26142/4480/4835 HARİÇ.)
   • DEPO (mekan 12): irsHrk ledger geçmişte BOZUK (591060: 2025-08'de −1264, WMS=2208 ile tutmaz).
     → Geçmiş backfill YOK. Sadece WMS ANLIK snapshot (bu ay). Aylık tekrar çalıştır → depo geçmişi ileriye birikir.

  ÇALIŞTIRMA: SSMS'te DerinSISBkm üzerinde. Şube kısmı idempotent (tam yeniden-kurar).
              Depo kısmı bu-ayı yeniler, geçmiş WMS snapshot'ları korur. AYLIK çalıştır (ay sonu).
  KULLANIM (rapor): belirli aydaki şube stoğu =
     SELECT TOP 1 Stok FROM bkm.StokAyBakiyeMekanBazli
     WHERE stkID=@x AND ehMekan=@m AND Donem<=@ayMonu ORDER BY Donem DESC;  -- son bakiye taşınır
*/
SET NOCOUNT ON;

-- 1) TABLO (yoksa oluştur)
IF OBJECT_ID('bkm.StokAyBakiyeMekanBazli') IS NULL
BEGIN
    CREATE TABLE bkm.StokAyBakiyeMekanBazli (
        Donem       date        NOT NULL,   -- ay-sonu tarihi (EOMONTH)
        stkID       int         NOT NULL,
        ehMekan     int         NOT NULL,   -- 1/4477/4478 şube · 12 depo
        Stok        int         NOT NULL,   -- o ay sonundaki bakiye
        Kaynak      varchar(10) NOT NULL,   -- 'irsHrk' (şube, güvenilir) · 'WMS' (depo, anlık)
        KayitTarihi datetime    NOT NULL CONSTRAINT DF_StokAyBakiyeMekan_dt DEFAULT (GETDATE()),
        CONSTRAINT PK_StokAyBakiyeMekan PRIMARY KEY (Donem, stkID, ehMekan)
    );
    -- lookup: belirli ürün+mekan'ın bir aya kadarki son bakiyesi (rapor 'Donem<=@ay' deseni)
    CREATE INDEX IX_StokAyBakiyeMekan_stk ON bkm.StokAyBakiyeMekanBazli (stkID, ehMekan, Donem) INCLUDE (Stok);
END;

-- 2) ŞUBE BACKFILL (mekan 1,4477,4478) — irsHrk ehAltDepo=0 kümülatif ay-sonu bakiye. İdempotent.
DELETE FROM bkm.StokAyBakiyeMekanBazli WHERE Kaynak = 'irsHrk';

;WITH aylik_delta AS (   -- ürün×mekan×ay net hareket
    SELECT h.ehstkID, h.ehMekan, EOMONTH(h.ehTrhS) AS Donem, SUM(h.ehAdetN) AS delta
    FROM dbo.irsHrk h WITH(NOLOCK)
    WHERE h.ehAltDepo = 0 AND h.ehMekan IN (1, 4477, 4478)
    GROUP BY h.ehstkID, h.ehMekan, EOMONTH(h.ehTrhS)
),
bakiye AS (              -- kümülatif = ay-sonu bakiye (running total)
    SELECT ehstkID, ehMekan, Donem,
           SUM(delta) OVER (PARTITION BY ehstkID, ehMekan ORDER BY Donem
                            ROWS UNBOUNDED PRECEDING) AS Stok
    FROM aylik_delta
)
INSERT INTO bkm.StokAyBakiyeMekanBazli (Donem, stkID, ehMekan, Stok, Kaynak)
SELECT Donem, ehstkID, ehMekan,
       CASE WHEN Stok < 0 THEN 0 ELSE CONVERT(int, Stok) END,   -- floor: fiziki stok negatif olamaz
       'irsHrk'                                                  -- (~%15 eski ürün açılış-öncesi irsHrk'de yok → derin geçmiş negatif → 0)
FROM bakiye;   -- Not: sadece hareket olan aylar (bakiye aradaki aylarda taşınır → lookup 'Donem<=@ay' ile)
-- running-sum (bakiye CTE) FLOOR'suz kalır → sonraki ay doğru kümülatif; sadece SAKLANAN değer floor'lanır.

-- 3) DEPO ANLIK snapshot (mekan 12, WMS = tek doğru kaynak) — bu ay. İleriye biriktir.
DECLARE @sonAy date = EOMONTH(GETDATE());
DELETE FROM bkm.StokAyBakiyeMekanBazli WHERE Kaynak = 'WMS' AND Donem = @sonAy;

INSERT INTO bkm.StokAyBakiyeMekanBazli (Donem, stkID, ehMekan, Stok, Kaynak)
SELECT @sonAy, stkID, 12, CONVERT(int, SUM(Stok)), 'WMS'
FROM depo.stok_adres_palet_vw WITH(NOLOCK)
WHERE Stok <> 0 AND adrsAlanTipID IN (0, 1)   -- RAF+GR, CK/CK01 hariç
GROUP BY stkID;

-- 4) ÖZET (çalıştıktan sonra kontrol)
SELECT Kaynak, COUNT(*) satir, COUNT(DISTINCT stkID) urun,
       MIN(Donem) ilk_ay, MAX(Donem) son_ay
FROM bkm.StokAyBakiyeMekanBazli GROUP BY Kaynak;

-- Doğrulama (591060 — şube geçmişi negatif OLMAMALI):
-- SELECT Donem, ehMekan, Stok, Kaynak FROM bkm.StokAyBakiyeMekanBazli
-- WHERE stkID = 591060 ORDER BY Donem, ehMekan;
