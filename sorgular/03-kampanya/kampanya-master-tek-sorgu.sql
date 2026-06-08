USE DerinSISBkm;
SET NOCOUNT ON;
-- 1. Filtreli ürün master
IF OBJECT_ID('tempdb..#UrunMaster') IS NOT NULL DROP TABLE #UrunMaster;
SELECT
    u.stkID,
    LEFT(u.stkAd, 80)                   AS stkAd,
    ISNULL(LEFT(u.mrkAd, 30), '(Yok)')  AS Yayinevi,
    ISNULL(LEFT(u.Yazar, 40), '(Yok)')  AS Yazar,
    u.Kategori3                         AS Kategori,
    ISNULL(LEFT(u.ReyonAd, 30), '')     AS Reyon,
    CAST(ISNULL(u.SatisFiyat, 0) AS DECIMAL(18,2)) AS ListeFiyat   -- v7: indirimsiz etiket fiyatı
INTO #UrunMaster
FROM bkm.urunbilgi u
WHERE u.Kategori3 IN (N'Kitap', N'Çocuk Kitabı', N'Akademi', N'Hazırlık Kitapları')
  AND u.stkID <> 583160;
CREATE CLUSTERED INDEX IX_UrunMaster_stkID ON #UrunMaster(stkID);
-- 2. Kampanya satışı
IF OBJECT_ID('tempdb..#KampSatis') IS NOT NULL DROP TABLE #KampSatis;
SELECT
    h.ehstkID AS stkID,
    -SUM(CASE WHEN h.ehTip IN (4,100) THEN h.ehAdetN ELSE 0 END)
    -SUM(CASE WHEN h.ehTip IN (5,101) THEN h.ehAdetN ELSE 0 END) AS NetAdet,
    SUM(CASE WHEN h.ehTip IN (4,100) THEN h.ehTutarN ELSE 0 END)
   -SUM(CASE WHEN h.ehTip IN (5,101) THEN h.ehTutarN ELSE 0 END) AS NetTutar,
    -SUM(CASE WHEN CAST(h.ehTrhS AS DATE)=CONVERT(date,'07.05.2026',104) AND h.ehTip IN (4,100) THEN h.ehAdetN
              WHEN CAST(h.ehTrhS AS DATE)=CONVERT(date,'07.05.2026',104) AND h.ehTip IN (5,101) THEN h.ehAdetN END) AS Ad_07,
    -SUM(CASE WHEN CAST(h.ehTrhS AS DATE)=CONVERT(date,'08.05.2026',104) AND h.ehTip IN (4,100) THEN h.ehAdetN
              WHEN CAST(h.ehTrhS AS DATE)=CONVERT(date,'08.05.2026',104) AND h.ehTip IN (5,101) THEN h.ehAdetN END) AS Ad_08,
    -SUM(CASE WHEN CAST(h.ehTrhS AS DATE)=CONVERT(date,'09.05.2026',104) AND h.ehTip IN (4,100) THEN h.ehAdetN
              WHEN CAST(h.ehTrhS AS DATE)=CONVERT(date,'09.05.2026',104) AND h.ehTip IN (5,101) THEN h.ehAdetN END) AS Ad_09,
    -SUM(CASE WHEN CAST(h.ehTrhS AS DATE)=CONVERT(date,'10.05.2026',104) AND h.ehTip IN (4,100) THEN h.ehAdetN
              WHEN CAST(h.ehTrhS AS DATE)=CONVERT(date,'10.05.2026',104) AND h.ehTip IN (5,101) THEN h.ehAdetN END) AS Ad_10,
    -SUM(CASE WHEN h.ehMekan=1    AND h.ehTip IN (4,100) THEN h.ehAdetN
              WHEN h.ehMekan=1    AND h.ehTip IN (5,101) THEN h.ehAdetN END) AS Ad_FSM,
    -SUM(CASE WHEN h.ehMekan=4477 AND h.ehTip IN (4,100) THEN h.ehAdetN
              WHEN h.ehMekan=4477 AND h.ehTip IN (5,101) THEN h.ehAdetN END) AS Ad_Ozluce,
    -SUM(CASE WHEN h.ehMekan=4478 AND h.ehTip IN (4,100) THEN h.ehAdetN
              WHEN h.ehMekan=4478 AND h.ehTip IN (5,101) THEN h.ehAdetN END) AS Ad_IstYolu
INTO #KampSatis
FROM dbo.irsHrk h WITH (NOLOCK)
INNER JOIN #UrunMaster u ON u.stkID = h.ehstkID
WHERE h.ehTrhS >= CONVERT(date,'07.05.2026',104)
  AND h.ehTrhS <  CONVERT(date,'11.05.2026',104)
  AND h.ehMekan IN (1,4477,4478) AND h.ehTip IN (4,5,100,101) AND h.ehAltDepo = 0
GROUP BY h.ehstkID
HAVING -SUM(CASE WHEN h.ehTip IN (4,100) THEN h.ehAdetN ELSE 0 END)
       -SUM(CASE WHEN h.ehTip IN (5,101) THEN h.ehAdetN ELSE 0 END) > 0;
CREATE CLUSTERED INDEX IX_KampSatis_stkID ON #KampSatis(stkID);
-- 3. Yıllık baseline
IF OBJECT_ID('tempdb..#YilSatis') IS NOT NULL DROP TABLE #YilSatis;
SELECT
    h.ehstkID AS stkID,
    -SUM(CASE WHEN h.ehTip IN (4,100) THEN h.ehAdetN ELSE 0 END)
    -SUM(CASE WHEN h.ehTip IN (5,101) THEN h.ehAdetN ELSE 0 END) AS YilAdet,
    SUM(CASE WHEN h.ehTip IN (4,100) THEN h.ehTutarN ELSE 0 END)
   -SUM(CASE WHEN h.ehTip IN (5,101) THEN h.ehTutarN ELSE 0 END) AS YilTutar
INTO #YilSatis
FROM dbo.irsHrk h WITH (NOLOCK)
INNER JOIN #KampSatis k ON k.stkID = h.ehstkID
WHERE h.ehTrhS >= CONVERT(date,'07.05.2025',104)
  AND h.ehTrhS <  CONVERT(date,'07.05.2026',104)
  AND h.ehMekan IN (1,4477,4478) AND h.ehTip IN (4,5,100,101) AND h.ehAltDepo = 0
GROUP BY h.ehstkID;
CREATE CLUSTERED INDEX IX_YilSatis_stkID ON #YilSatis(stkID);
-- 4. İlk satış tarihi
IF OBJECT_ID('tempdb..#IlkSatis') IS NOT NULL DROP TABLE #IlkSatis;
SELECT
    h.ehstkID AS stkID,
    MIN(CAST(h.ehTrhS AS DATE)) AS IlkSatisTarih
INTO #IlkSatis
FROM dbo.irsHrk h WITH (NOLOCK)
INNER JOIN #KampSatis k ON k.stkID = h.ehstkID
WHERE h.ehTip IN (4,100)
  AND h.ehMekan IN (1,4477,4478)
  AND h.ehAltDepo = 0
GROUP BY h.ehstkID;
CREATE CLUSTERED INDEX IX_IlkSatis_stkID ON #IlkSatis(stkID);
-- 5. Güncel stok
IF OBJECT_ID('tempdb..#Stok') IS NOT NULL DROP TABLE #Stok;
SELECT
    s.ehstkID AS stkID,
    SUM(CASE WHEN s.ehMekan=1    THEN s.stok ELSE 0 END) AS Stok_FSM,
    SUM(CASE WHEN s.ehMekan=4477 THEN s.stok ELSE 0 END) AS Stok_Ozluce,
    SUM(CASE WHEN s.ehMekan=4478 THEN s.stok ELSE 0 END) AS Stok_IstYolu,
    SUM(CASE WHEN s.ehMekan=12   THEN s.stok ELSE 0 END) AS Stok_MerkezDepo,
    SUM(s.stok) AS Stok_Toplam
INTO #Stok
FROM dbo.stokSon_vw s WITH (NOLOCK)
INNER JOIN #KampSatis k ON k.stkID = s.ehstkID
WHERE s.ehMekan IN (1,4477,4478,12)
GROUP BY s.ehstkID;
CREATE CLUSTERED INDEX IX_Stok_stkID ON #Stok(stkID);
-- 6. Son alış
IF OBJECT_ID('tempdb..#SonAlis') IS NOT NULL DROP TABLE #SonAlis;
;WITH AlisHrk AS (
    SELECT fa.ehStkID, f.eTarih, fa.ehAdetN
    FROM dbo.fatAyr fa WITH (NOLOCK)
    INNER JOIN dbo.fat f WITH (NOLOCK) ON f.eID = fa.ehID
    INNER JOIN #KampSatis k ON k.stkID = fa.ehStkID
    WHERE f.eGC=1 AND f.onay=1 AND f.eDurum=0
      AND f.eTarih >= CONVERT(date,'01.01.2022',104)
      AND fa.ehAdetN < 0
),
SonTarih AS (
    SELECT ehStkID, MAX(eTarih) AS SonAlisTarih FROM AlisHrk GROUP BY ehStkID
)
SELECT
    sa.ehStkID AS stkID,
    sa.SonAlisTarih,
    CAST(-SUM(a.ehAdetN) AS INT) AS SonAlisAdet,
    DATEDIFF(DAY, sa.SonAlisTarih, GETDATE()) AS GunSayisiAlisBeri
INTO #SonAlis
FROM SonTarih sa
INNER JOIN AlisHrk a ON a.ehStkID=sa.ehStkID AND a.eTarih=sa.SonAlisTarih
GROUP BY sa.ehStkID, sa.SonAlisTarih;
CREATE CLUSTERED INDEX IX_SonAlis_stkID ON #SonAlis(stkID);
-- =============================================================
-- ANA SORGU — v5 (CEILING tutarlılığı düzeltildi)
-- BeklenenAdet bir kere CROSS APPLY ile hesaplanır + yuvarlanır,
-- FazlaAdet o yuvarlanmış değerden çıkartılır.
-- =============================================================
DECLARE @KampBaslangic DATE = CONVERT(date,'07.05.2026',104);

SELECT
    -- Ürün master (7) + liste fiyatı
    k.stkID,
    u.stkAd,
    u.Yayinevi,
    u.Yazar,
    u.Kategori,
    u.Reyon,
    u.ListeFiyat,                                                   -- indirimsiz etiket fiyatı
    -- Kampanya satışı (10) — para sadece referans
    CAST(k.NetAdet AS INT)              AS KampAdet,
    CAST(k.NetTutar AS DECIMAL(18,2))   AS KampTutar,
    CAST(ISNULL(k.Ad_07,0) AS INT)      AS Ad_07,
    CAST(ISNULL(k.Ad_08,0) AS INT)      AS Ad_08,
    CAST(ISNULL(k.Ad_09,0) AS INT)      AS Ad_09,
    CAST(ISNULL(k.Ad_10,0) AS INT)      AS Ad_10,
    CAST(ISNULL(k.Ad_FSM,0) AS INT)     AS Ad_FSM,
    CAST(ISNULL(k.Ad_Ozluce,0) AS INT)  AS Ad_Ozluce,
    CAST(ISNULL(k.Ad_IstYolu,0) AS INT) AS Ad_IstYolu,
    CAST(k.NetTutar / NULLIF(k.NetAdet,0) AS DECIMAL(18,2)) AS BirimSatisFiyat,
    -- Yıllık baseline (2) — para sadece referans
    CAST(ISNULL(y.YilAdet,0)  AS INT)            AS YilAdet,
    CAST(ISNULL(y.YilTutar,0) AS DECIMAL(18,2))  AS YilTutar,
    -- İlk satış (2)
    isn.IlkSatisTarih,
    ag.AktifGun,
    -- ADET bazlı karşılaştırma — yuvarlanmış BeklenenAdet, FazlaAdet ondan türetilir
    bd.BeklenenAdet,
    CASE
        WHEN bd.BeklenenAdet IS NULL THEN CAST(k.NetAdet AS INT)        -- yeni urun / yillik 0 → tumu fazla
        ELSE CAST(k.NetAdet AS INT) - bd.BeklenenAdet                   -- net çıkarma, tutarlı
    END AS FazlaAdet,
    -- v8: Geri dönüşte kesilecek tutar — yayınevi ile ANLAŞILAN oran üzerinden
    -- Formül: ListeFiyat × (GeriDonusOran/100) × KampAdet
    -- Kaynak: bkm.UrunIskontoYuzdeElliKampanya_vw (öncelik: Verilmeyen > Barkod > Marka)
    -- ListeKarsiligi referans (iskontosuz toplam), MaksKesinti karşılaştırma için.
    iv.IskontoKaynak,
    iv.GeriDonusOran                                                AS IskontoOran,
    CAST(u.ListeFiyat * k.NetAdet                  AS DECIMAL(18,2)) AS ListeKarsiligi,
    CAST(u.ListeFiyat * k.NetAdet - k.NetTutar     AS DECIMAL(18,2)) AS MaksKesinti,        -- üst limit
    CAST(u.ListeFiyat * iv.GeriDonusOran / 100.0
         * k.NetAdet                              AS DECIMAL(18,2)) AS KesilecekTutar,     -- gerçek anlaşma
    -- Segment (yuvarlanmış BeklenenAdet ile karşılaştırılır → tutarlı)
    -- v7: Eşik kaldırıldı — AktifGun kaç günse o kabul. Sadece 0 (ilk satış kampanyada) Yeni Kitap kalır.
    CASE
        WHEN ag.AktifGun < 1                            THEN N'Yeni Kitap'
        WHEN ISNULL(y.YilAdet,0) = 0                     THEN N'YillikSatissiz'
        WHEN k.NetAdet > bd.BeklenenAdet                 THEN N'OrtalamadanFazla'
        ELSE                                                   N'OrtalamadanAz'
    END AS Segment,
    -- Stok (5)
    CAST(ISNULL(s.Stok_FSM,0)         AS INT) AS Stok_FSM,
    CAST(ISNULL(s.Stok_Ozluce,0)      AS INT) AS Stok_Ozluce,
    CAST(ISNULL(s.Stok_IstYolu,0)     AS INT) AS Stok_IstYolu,
    CAST(ISNULL(s.Stok_MerkezDepo,0)  AS INT) AS Stok_MerkezDepo,
    CAST(ISNULL(s.Stok_Toplam,0)      AS INT) AS Stok_Toplam,
    -- Kampanya öncesi stok (4)
    CAST(ISNULL(s.Stok_FSM,0)     + ISNULL(k.Ad_FSM,0)     AS INT) AS StokOnceKamp_FSM,
    CAST(ISNULL(s.Stok_Ozluce,0)  + ISNULL(k.Ad_Ozluce,0)  AS INT) AS StokOnceKamp_Ozluce,
    CAST(ISNULL(s.Stok_IstYolu,0) + ISNULL(k.Ad_IstYolu,0) AS INT) AS StokOnceKamp_IstYolu,
    CAST(ISNULL(s.Stok_Toplam,0)  + k.NetAdet              AS INT) AS StokOnceKamp_Toplam,
    -- Son alış (3)
    sa.SonAlisTarih,
    ISNULL(sa.SonAlisAdet, 0)        AS SonAlisAdet,
    ISNULL(sa.GunSayisiAlisBeri, 9999) AS GunSayisiAlisBeri
FROM #KampSatis k
INNER JOIN #UrunMaster u ON u.stkID = k.stkID
INNER JOIN #IlkSatis isn ON isn.stkID = k.stkID
LEFT JOIN #YilSatis y    ON y.stkID = k.stkID
LEFT JOIN #Stok s        ON s.stkID = k.stkID
LEFT JOIN #SonAlis sa    ON sa.stkID = k.stkID
LEFT JOIN bkm.UrunIskontoYuzdeElliKampanya_vw iv ON iv.stkID = k.stkID
-- v5: BeklenenAdet bir kere hesaplanır, herkes onu kullanır → tutarlılık
CROSS APPLY (VALUES (DATEDIFF(DAY, isn.IlkSatisTarih, @KampBaslangic))) ag(AktifGun)
CROSS APPLY (VALUES (
    -- v7: Eşik tamamen kaldırıldı. AktifGun kaç günse o kabul.
    -- Sadece AktifGun = 0 (ilk satış kampanyada başladı) için NULL → divide-by-zero koruma.
    -- AktifGun > 365 → 365 ile sınırla (yıllık baseline 365 günü kapsar).
    CASE WHEN ag.AktifGun < 1 OR ISNULL(y.YilAdet,0) = 0 THEN NULL
         ELSE CAST(CEILING(ISNULL(y.YilAdet,0) * 4.0 /
              CASE WHEN ag.AktifGun > 365 THEN 365 ELSE ag.AktifGun END) AS INT)
    END
)) bd(BeklenenAdet)
ORDER BY k.NetAdet DESC;

DROP TABLE #UrunMaster, #KampSatis, #YilSatis, #IlkSatis, #Stok, #SonAlis;
