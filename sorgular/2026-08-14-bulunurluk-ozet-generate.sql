/*
  bkm.BulunurlukOzet + bkm.BulunurlukKayip — PRE-AGGREGATED bulunurluk (OSA) özeti. plan-33.
  NEDEN: dashboard 29M dense tabloyu canlı tarayınca ~10s (window-MAX 844K çift + join). Aylık-grain veri →
         özeti AYDA BİR hesapla + sakla → dashboard 9-satır/top-N okur = sub-second.
  ÇALIŞTIRMA: SSMS, DerinSISBkm. Dense (2026-08-14-stok-ay-bakiye-DENSE.sql) çalıştıktan SONRA, AYLIK.
              @Donem snapshot = ay-sonu → geçmiş birikir (OOS trendi). İdempotent (o Donem'i yeniler).
  KAYNAK: bkm.StokAyBakiyeMekanBazli (dense ay-sonu bakiye) × irsHrk satış × fatAyr maliyet. Kat3 10/12/16.
  Availability = son12 pencerede MAX(Stok)>=@min (dense → carry-forward gereksiz).
*/
SET NOCOUNT ON;

DECLARE @min int = 3;
DECLARE @Donem date = EOMONTH(GETDATE());                       -- snapshot damgası
DECLARE @son char(8) = CONVERT(char(8), DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1), 112);
DECLARE @bas char(8) = CONVERT(char(8), DATEADD(month, -12, DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1)), 112);

-- 1) TABLOLAR (yoksa)
IF OBJECT_ID('bkm.BulunurlukOzet') IS NULL
CREATE TABLE bkm.BulunurlukOzet (
    Donem date NOT NULL, Mekan int NOT NULL, Kat3ID int NOT NULL,
    TasinanAktif int NOT NULL, Bulunur int NOT NULL, Kuru int NOT NULL,
    KayitTarihi datetime NOT NULL CONSTRAINT DF_BulOzet_dt DEFAULT (GETDATE()),
    CONSTRAINT PK_BulOzet PRIMARY KEY (Donem, Mekan, Kat3ID)
);
IF OBJECT_ID('bkm.BulunurlukKayip') IS NULL
CREATE TABLE bkm.BulunurlukKayip (
    Donem date NOT NULL, StkID int NOT NULL, StkAd nvarchar(200) NULL, Kategori nvarchar(100) NULL, Marka nvarchar(100) NULL,
    StokluSube int NOT NULL, KuruSube int NOT NULL, KuruSubeAd nvarchar(60) NULL,
    GorunurSatis int NOT NULL, TahminiKayipAdet int NOT NULL, BirimMaliyet decimal(18,2) NULL,
    KayitTarihi datetime NOT NULL CONSTRAINT DF_BulKayip_dt DEFAULT (GETDATE()),
    CONSTRAINT PK_BulKayip PRIMARY KEY (Donem, StkID)
);

-- ortak: aktif Kat3 SKU (son12 satan) + pencere window-MAX (availability)
IF OBJECT_ID('tempdb..#aktif') IS NOT NULL DROP TABLE #aktif;
SELECT ehstkID AS stkID INTO #aktif
FROM dbo.irsHrk WITH(NOLOCK)
WHERE ehTip IN (1,4,100) AND ehTrhS>=@bas AND ehTrhS<@son
  AND ehstkID IN (SELECT StkID FROM bkm.UrunBilgi WHERE Kat3ID IN (10,12,16))
GROUP BY ehstkID HAVING SUM(-ehAdetN)>0;
CREATE CLUSTERED INDEX ix ON #aktif(stkID);

IF OBJECT_ID('tempdb..#av') IS NOT NULL DROP TABLE #av;
SELECT b.stkID, b.ehMekan, MAX(b.Stok) AS mx
INTO #av
FROM bkm.StokAyBakiyeMekanBazli b WITH(NOLOCK)
JOIN #aktif a ON a.stkID=b.stkID
WHERE b.Kaynak='irsHrk' AND b.ehMekan IN (1,4477,4478) AND b.Donem>=@bas AND b.Donem<@son
GROUP BY b.stkID, b.ehMekan;
CREATE CLUSTERED INDEX ix ON #av(stkID, ehMekan);

-- 2) OZET (şube × kategori OOS)
DELETE FROM bkm.BulunurlukOzet WHERE Donem=@Donem;
INSERT INTO bkm.BulunurlukOzet (Donem, Mekan, Kat3ID, TasinanAktif, Bulunur, Kuru)
SELECT @Donem, v.ehMekan, u.Kat3ID,
    COUNT(*), SUM(CASE WHEN v.mx>=@min THEN 1 ELSE 0 END), SUM(CASE WHEN v.mx<@min THEN 1 ELSE 0 END)
FROM #av v JOIN bkm.UrunBilgi u WITH(NOLOCK) ON u.StkID=v.stkID
GROUP BY v.ehMekan, u.Kat3ID;

-- 3) KAYIP (kısmi-dağıtım + kuru şube, top 500 by kayıp₺)
IF OBJECT_ID('tempdb..#sku') IS NOT NULL DROP TABLE #sku;
SELECT v.stkID,
    SUM(CASE WHEN v.mx>=@min THEN 1 ELSE 0 END) AS stoklu,
    SUM(CASE WHEN v.mx<@min THEN 1 ELSE 0 END) AS kuru,
    MAX(CASE WHEN v.ehMekan=1    AND v.mx<@min THEN 1 ELSE 0 END) AS d1,
    MAX(CASE WHEN v.ehMekan=4477 AND v.mx<@min THEN 1 ELSE 0 END) AS d4477,
    MAX(CASE WHEN v.ehMekan=4478 AND v.mx<@min THEN 1 ELSE 0 END) AS d4478
INTO #sku FROM #av v GROUP BY v.stkID;

IF OBJECT_ID('tempdb..#satis') IS NOT NULL DROP TABLE #satis;
SELECT ehstkID AS stkID, CONVERT(int,SUM(-ehAdetN)) AS satis INTO #satis
FROM dbo.irsHrk WITH(NOLOCK)
WHERE ehTip IN (1,4,100) AND ehTrhS>=@bas AND ehTrhS<@son AND ehstkID IN (SELECT stkID FROM #aktif)
GROUP BY ehstkID;
CREATE CLUSTERED INDEX ix ON #satis(stkID);

DELETE FROM bkm.BulunurlukKayip WHERE Donem=@Donem;
;WITH aday AS (
    SELECT k.stkID, s.satis, k.stoklu, k.kuru, k.d1, k.d4477, k.d4478,
           CONVERT(int, 1.0*s.satis*(3-k.stoklu)/k.stoklu) AS kayip_adet
    FROM #sku k JOIN #satis s ON s.stkID=k.stkID
    WHERE k.stoklu IN (1,2) AND k.kuru>=1
)
INSERT INTO bkm.BulunurlukKayip (Donem, StkID, StkAd, Kategori, Marka, StokluSube, KuruSube, KuruSubeAd, GorunurSatis, TahminiKayipAdet, BirimMaliyet)
SELECT TOP 500 @Donem, t.stkID, u.stkAd, ISNULL(ub.Kategori3,''), ISNULL(ub.mrkAd,''),
    t.stoklu, t.kuru,
    LTRIM(CASE WHEN t.d1=1 THEN ' FSM' ELSE '' END + CASE WHEN t.d4477=1 THEN ' Özlüce' ELSE '' END + CASE WHEN t.d4478=1 THEN ' İst.Yolu' ELSE '' END),
    t.satis, t.kayip_adet, CONVERT(decimal(18,2), ISNULL(mal.birim,0))
FROM (SELECT TOP 1500 * FROM aday ORDER BY kayip_adet DESC) t
JOIN dbo.urn u WITH(NOLOCK) ON u.stkID=t.stkID
LEFT JOIN bkm.UrunBilgi ub WITH(NOLOCK) ON ub.StkID=t.stkID
OUTER APPLY (
    SELECT TOP 1 SUM(fa.ehTutarN)/NULLIF(SUM(fa.ehAdetN),0) AS birim
    FROM dbo.fatAyr fa WITH(NOLOCK) JOIN dbo.fat f WITH(NOLOCK) ON fa.ehID=f.eID
    WHERE fa.ehstkID=t.stkID AND f.eTip=0 AND f.eDurum<>2 AND fa.ehAdetN>0
    GROUP BY f.eID ORDER BY MAX(f.eTarih) DESC
) mal
ORDER BY (t.kayip_adet * ISNULL(mal.birim,0)) DESC;

DROP TABLE #aktif, #av, #sku, #satis;

-- ÖZET
SELECT 'Ozet' tip, COUNT(*) satir FROM bkm.BulunurlukOzet WHERE Donem=@Donem
UNION ALL SELECT 'Kayip', COUNT(*) FROM bkm.BulunurlukKayip WHERE Donem=@Donem;
