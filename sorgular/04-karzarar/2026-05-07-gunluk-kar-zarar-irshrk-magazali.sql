/*================================================================
  Günlük Kâr/Zarar v2 — irsHrk Tabanlı, Mağaza Kırılımlı
  Satış: irsHrk.ehTutarN  |  Maliyet: fat+fatAyr son alış
  ----------------------------------------------------------------
  Yazan         : Claude (Fikri için)
  Tarih         : 07.05.2026
  Plan          : plans/04-gunluk-kar-zarar-maliyet-karsilastirma.md
                  + 04-v2 mağaza kırılımı (TODO B-23)
  Kaynak        : DerinSISBkm — TEK DB (cross-db köprü gerekmez)
  Referans dok  : sorgular/SEMANTIK_KATMAN.md (ehTip kod sözlüğü)

  v1 → v2 değişimi:
    v1: EncoreMerkez Sales+SalesProducts (POS terminal verisi)
    v2: DerinSIS irsHrk (tüm satış+irsaliye, daha kapsamlı)
        - Cross-db köprü problemi yok (%100 stkID eşleşme)
        - Mağaza filtresi doğal: ehMekan IN (1, 4477, 4478)
        - İndirim zaten ehTutarN'de düşülmüş (= ehTutar - ehIndirim)
        - Sınav Okulları DAHIL (4478 İst.Yolu altında)

  ehTip Kod Sözlüğü (SEMANTIK_KATMAN.md):
    POS Satış brüt:  ehTip IN (1, 4, 100)
    POS İade:        ehTip IN (3, 5, 101)
    Net ciro = brüt − iade
    (Diğerleri: 9/10/11/13=transfer, 99=sayım — HARİÇ)

  Mekan ID:
    1    = FSM
    4477 = Özlüce
    4478 = İst.Yolu

  KULLANIM:
    @BasTarih, @BitTarih: Aralık [BasTarih, BitTarih) — BitTarih DAHİL DEĞİL
    @KategoriIDList: kitap kategorileri (default 2,8,15,24)
    @TopN: detay result-set en çok kaç ürün

  ÇIKTI:
    Result-set 1: Mağaza × Kategori özet (kâr/zarar)
    Result-set 2: Genel kategori özet (3 mağaza toplam)
    Result-set 3: Top N ürün detay (mağaza ayrımsız global)
    Result-set 4: Doğrulama (maliyet bulunma oranı)

  KRİTİK:
    DerinSIS alış faturasında ehAdet/ehAdetN NEGATİF, ehTutarN
    pozitif. Birim alış maliyet = ehTutarN / ABS(ehAdetN).
    irsHrk satışta ise ehAdetN NEGATİF (çıkış), ehTutarN pozitif.
    Toplam: SUM(ehTutarN) doğru, NetAdet = ABS(ehAdetN) toplamı.
================================================================*/

USE DerinSISBkm;
SET NOCOUNT ON;

-- =============== PARAMETRELER ===============
DECLARE @BasTarih  DATE = CONVERT(DATE, '06.05.2026', 104);
DECLARE @BitTarih  DATE = CONVERT(DATE, '08.05.2026', 104);  -- DAHİL DEĞİL
DECLARE @YalnizTL  BIT  = 1;
DECLARE @TopN      INT  = 200;

DECLARE @KategoriID TABLE (id TINYINT PRIMARY KEY);
INSERT INTO @KategoriID(id) VALUES (2),(8),(15),(24);

DECLARE @Mekan TABLE (mekanID INT PRIMARY KEY, mekanAd VARCHAR(20));
INSERT INTO @Mekan(mekanID, mekanAd) VALUES (1, 'FSM'), (4477, 'Özlüce'), (4478, 'İst.Yolu');

-- Maliyet için lookback: son 24 ay
DECLARE @MaliyetBaslangic DATE = DATEADD(MONTH, -24, @BasTarih);


-- ================================================================
-- ÇIKTI 1: MAĞAZA × KATEGORİ ÖZET
-- ================================================================
;WITH
KitapUrun AS (
    SELECT u.stkID, u.stkKod, u.stkAd, u.urnKtgr2ID,
           CAST(k.ktgrAd AS NVARCHAR(50)) AS ktgrAd
    FROM dbo.urn u WITH (NOLOCK)
    INNER JOIN dbo.urnKtgr2 k WITH (NOLOCK) ON k.ktgrID = u.urnKtgr2ID
    WHERE u.urnKtgr2ID IN (SELECT id FROM @KategoriID)
),
SatisHam AS (
    -- POS satış (brüt) + iade — net ciro = brüt − iade
    SELECT
        ih.ehMekan,
        ih.ehstkID,
        CASE WHEN ih.ehTip IN (1, 4, 100) THEN  1   -- Satış: tutar pozitif
             WHEN ih.ehTip IN (3, 5, 101) THEN -1   -- İade: net'ten düş
        END AS Sign,
        ABS(ih.ehAdetN)    AS BirimAdet,
        ih.ehTutarN        AS BirimTutar  -- KDV hariç net (indirim sonrası)
    FROM dbo.irsHrk ih WITH (NOLOCK)
    WHERE ih.ehMekan IN (SELECT mekanID FROM @Mekan)
      AND ih.hrkTarih >= @BasTarih
      AND ih.hrkTarih <  @BitTarih
      AND ih.ehTip IN (1, 4, 100, 3, 5, 101)
      AND ih.ehAltDepo = 0
      AND ih.ehstkID IN (SELECT stkID FROM KitapUrun)
),
MaliyetA_Aday AS (
    SELECT fa.ehStkID AS stkID,
           CAST(fa.ehTutarN / NULLIF(ABS(fa.ehAdetN), 0) AS DECIMAL(18,4)) AS faturaBirimMaliyet,
           f.eTarih AS faturaTarih,
           ROW_NUMBER() OVER (PARTITION BY fa.ehStkID ORDER BY f.eTarih DESC, f.eID DESC, fa.ehSira DESC) AS rn
    FROM dbo.fat f WITH (NOLOCK)
    INNER JOIN dbo.fatAyr fa WITH (NOLOCK) ON fa.ehID = f.eID
    WHERE f.eGC=1 AND f.onay=1 AND f.eDurum=0
      AND (@YalnizTL = 0 OR f.eDvzID = 1)
      AND f.eTarih >= @MaliyetBaslangic
      AND fa.ehAdetN < 0
      AND fa.ehTutarN > 0
      AND fa.ehStkID IN (SELECT stkID FROM KitapUrun)
),
MaliyetA AS (
    SELECT stkID, faturaBirimMaliyet, faturaTarih
    FROM MaliyetA_Aday WHERE rn = 1
),
SatisOzet AS (
    SELECT
        s.ehMekan,
        s.ehstkID,
        SUM(s.Sign * s.BirimAdet)  AS NetAdet,
        SUM(s.Sign * s.BirimTutar) AS NetSatis,
        SUM(CASE WHEN s.Sign =  1 THEN s.BirimTutar ELSE 0 END) AS BrutSatis,
        SUM(CASE WHEN s.Sign = -1 THEN s.BirimTutar ELSE 0 END) AS Iade,
        SUM(CASE WHEN s.Sign = -1 THEN s.BirimAdet  ELSE 0 END) AS IadeAdet
    FROM SatisHam s
    GROUP BY s.ehMekan, s.ehstkID
)
SELECT
    m.mekanID,
    m.mekanAd,
    ku.urnKtgr2ID,
    ku.ktgrAd                                                     AS Kategori,
    COUNT(DISTINCT s.ehstkID)                                     AS UrunCesidi,
    SUM(s.NetAdet)                                                AS NetAdet,
    SUM(s.BrutSatis)                                              AS BrutSatis,
    SUM(s.Iade)                                                   AS Iade,
    SUM(s.NetSatis)                                               AS NetSatis,
    SUM(CAST(ma.faturaBirimMaliyet * s.NetAdet AS DECIMAL(18,2))) AS Maliyet,
    SUM(s.NetSatis) - SUM(CAST(ma.faturaBirimMaliyet * s.NetAdet AS DECIMAL(18,2))) AS Marj_TL,
    CAST((SUM(s.NetSatis) - SUM(CAST(ma.faturaBirimMaliyet * s.NetAdet AS DECIMAL(18,2)))) * 100.0
         / NULLIF(SUM(s.NetSatis),0) AS DECIMAL(8,2))             AS Marj_Yuzde,
    SUM(CASE WHEN ma.stkID IS NOT NULL THEN 1 ELSE 0 END)         AS Urun_MaliyetVar,
    SUM(CASE WHEN ma.stkID IS NULL     THEN 1 ELSE 0 END)         AS Urun_MaliyetiYok
FROM SatisOzet s
INNER JOIN @Mekan m       ON m.mekanID = s.ehMekan
INNER JOIN KitapUrun ku   ON ku.stkID  = s.ehstkID
LEFT  JOIN MaliyetA  ma   ON ma.stkID  = s.ehstkID
GROUP BY m.mekanID, m.mekanAd, ku.urnKtgr2ID, ku.ktgrAd
ORDER BY m.mekanID, SUM(s.NetSatis) DESC;


-- ================================================================
-- ÇIKTI 2: GENEL KATEGORİ ÖZET (3 MAĞAZA TOPLAM)
-- ================================================================
;WITH
KitapUrun AS (
    SELECT u.stkID, u.urnKtgr2ID, CAST(k.ktgrAd AS NVARCHAR(50)) AS ktgrAd
    FROM dbo.urn u WITH (NOLOCK)
    INNER JOIN dbo.urnKtgr2 k WITH (NOLOCK) ON k.ktgrID = u.urnKtgr2ID
    WHERE u.urnKtgr2ID IN (2,8,15,24)
),
SatisHam AS (
    SELECT ih.ehstkID,
        CASE WHEN ih.ehTip IN (1,4,100) THEN  1
             WHEN ih.ehTip IN (3,5,101) THEN -1 END AS Sign,
        ABS(ih.ehAdetN) AS BirimAdet,
        ih.ehTutarN     AS BirimTutar
    FROM dbo.irsHrk ih WITH (NOLOCK)
    WHERE ih.ehMekan IN (1,4477,4478)
      AND ih.hrkTarih >= CONVERT(DATE,'06.05.2026',104)
      AND ih.hrkTarih <  CONVERT(DATE,'08.05.2026',104)
      AND ih.ehTip IN (1,4,100,3,5,101)
      AND ih.ehAltDepo = 0
      AND ih.ehstkID IN (SELECT stkID FROM KitapUrun)
),
MaliyetA_Aday AS (
    SELECT fa.ehStkID AS stkID,
           CAST(fa.ehTutarN / NULLIF(ABS(fa.ehAdetN),0) AS DECIMAL(18,4)) AS faturaBirimMaliyet,
           ROW_NUMBER() OVER (PARTITION BY fa.ehStkID ORDER BY f.eTarih DESC, f.eID DESC, fa.ehSira DESC) AS rn
    FROM dbo.fat f WITH (NOLOCK)
    INNER JOIN dbo.fatAyr fa WITH (NOLOCK) ON fa.ehID = f.eID
    WHERE f.eGC=1 AND f.onay=1 AND f.eDurum=0 AND f.eDvzID=1
      AND f.eTarih >= CONVERT(DATE,'06.05.2024',104)
      AND fa.ehAdetN < 0 AND fa.ehTutarN > 0
      AND fa.ehStkID IN (SELECT stkID FROM KitapUrun)
),
MaliyetA AS (SELECT stkID, faturaBirimMaliyet FROM MaliyetA_Aday WHERE rn=1),
SatisOzet AS (
    SELECT s.ehstkID,
           SUM(s.Sign * s.BirimAdet)  AS NetAdet,
           SUM(s.Sign * s.BirimTutar) AS NetSatis,
           SUM(CASE WHEN s.Sign= 1 THEN s.BirimTutar ELSE 0 END) AS BrutSatis,
           SUM(CASE WHEN s.Sign=-1 THEN s.BirimTutar ELSE 0 END) AS Iade
    FROM SatisHam s
    GROUP BY s.ehstkID
)
SELECT
    ku.urnKtgr2ID,
    ku.ktgrAd                                                     AS Kategori,
    COUNT(DISTINCT s.ehstkID)                                     AS UrunCesidi,
    SUM(s.NetAdet)                                                AS NetAdet,
    SUM(s.BrutSatis)                                              AS BrutSatis,
    SUM(s.Iade)                                                   AS Iade,
    SUM(s.NetSatis)                                               AS NetSatis,
    SUM(CAST(ma.faturaBirimMaliyet * s.NetAdet AS DECIMAL(18,2))) AS Maliyet,
    SUM(s.NetSatis) - SUM(CAST(ma.faturaBirimMaliyet * s.NetAdet AS DECIMAL(18,2))) AS Marj_TL,
    CAST((SUM(s.NetSatis) - SUM(CAST(ma.faturaBirimMaliyet * s.NetAdet AS DECIMAL(18,2)))) * 100.0
         / NULLIF(SUM(s.NetSatis),0) AS DECIMAL(8,2))             AS Marj_Yuzde,
    CAST(SUM(CASE WHEN ma.stkID IS NOT NULL THEN s.NetSatis ELSE 0 END) * 100.0
         / NULLIF(SUM(s.NetSatis),0) AS DECIMAL(8,2))             AS MaliyetliSatis_Yuzde,
    SUM(CASE WHEN ma.stkID IS NOT NULL THEN 1 ELSE 0 END)         AS Urun_MaliyetVar,
    SUM(CASE WHEN ma.stkID IS NULL     THEN 1 ELSE 0 END)         AS Urun_MaliyetiYok
FROM SatisOzet s
INNER JOIN KitapUrun ku ON ku.stkID = s.ehstkID
LEFT  JOIN MaliyetA  ma ON ma.stkID = s.ehstkID
GROUP BY ku.urnKtgr2ID, ku.ktgrAd
ORDER BY SUM(s.NetSatis) DESC;


-- ================================================================
-- ÇIKTI 3: TOP N ÜRÜN DETAY (Global, 3 mağaza toplam)
-- ================================================================
;WITH
KitapUrun AS (
    SELECT u.stkID, u.stkKod, u.stkAd, u.urnKtgr2ID,
           CAST(k.ktgrAd AS NVARCHAR(50)) AS ktgrAd
    FROM dbo.urn u WITH (NOLOCK)
    INNER JOIN dbo.urnKtgr2 k WITH (NOLOCK) ON k.ktgrID = u.urnKtgr2ID
    WHERE u.urnKtgr2ID IN (2,8,15,24)
),
SatisHam AS (
    SELECT ih.ehstkID,
        CASE WHEN ih.ehTip IN (1,4,100) THEN  1
             WHEN ih.ehTip IN (3,5,101) THEN -1 END AS Sign,
        ABS(ih.ehAdetN) AS BirimAdet,
        ih.ehTutarN     AS BirimTutar
    FROM dbo.irsHrk ih WITH (NOLOCK)
    WHERE ih.ehMekan IN (1,4477,4478)
      AND ih.hrkTarih >= CONVERT(DATE,'06.05.2026',104)
      AND ih.hrkTarih <  CONVERT(DATE,'08.05.2026',104)
      AND ih.ehTip IN (1,4,100,3,5,101)
      AND ih.ehAltDepo = 0
      AND ih.ehstkID IN (SELECT stkID FROM KitapUrun)
),
MaliyetA_Aday AS (
    SELECT fa.ehStkID AS stkID, f.eTarih AS faturaTarih, f.eFirma AS tedarikciID,
           CAST(fa.ehTutarN / NULLIF(ABS(fa.ehAdetN),0) AS DECIMAL(18,4)) AS faturaBirimMaliyet,
           ROW_NUMBER() OVER (PARTITION BY fa.ehStkID ORDER BY f.eTarih DESC, f.eID DESC, fa.ehSira DESC) AS rn
    FROM dbo.fat f WITH (NOLOCK)
    INNER JOIN dbo.fatAyr fa WITH (NOLOCK) ON fa.ehID = f.eID
    WHERE f.eGC=1 AND f.onay=1 AND f.eDurum=0 AND f.eDvzID=1
      AND f.eTarih >= CONVERT(DATE,'06.05.2024',104)
      AND fa.ehAdetN < 0 AND fa.ehTutarN > 0
      AND fa.ehStkID IN (SELECT stkID FROM KitapUrun)
),
MaliyetA AS (SELECT stkID, faturaBirimMaliyet, faturaTarih, tedarikciID FROM MaliyetA_Aday WHERE rn=1),
SatisOzet AS (
    SELECT s.ehstkID,
           SUM(s.Sign * s.BirimAdet)  AS NetAdet,
           SUM(s.Sign * s.BirimTutar) AS NetSatis,
           SUM(CASE WHEN s.Sign= 1 THEN s.BirimTutar ELSE 0 END) AS BrutSatis,
           SUM(CASE WHEN s.Sign=-1 THEN s.BirimTutar ELSE 0 END) AS Iade,
           SUM(CASE WHEN s.Sign=-1 THEN s.BirimAdet  ELSE 0 END) AS IadeAdet
    FROM SatisHam s
    GROUP BY s.ehstkID
)
SELECT TOP (200)
    ku.stkID,
    ku.stkKod,
    ku.stkAd,
    ku.ktgrAd,
    s.NetAdet,
    s.IadeAdet,
    s.BrutSatis,
    s.Iade,
    s.NetSatis,
    ma.faturaBirimMaliyet                                       AS MaliyetBirim,
    ma.faturaTarih                                              AS MaliyetTarih,
    ma.tedarikciID                                              AS SonTedarikciID,
    CAST(ma.faturaBirimMaliyet * s.NetAdet AS DECIMAL(18,2))    AS MaliyetToplam,
    CAST(s.NetSatis - (ma.faturaBirimMaliyet * s.NetAdet) AS DECIMAL(18,2)) AS Marj_TL,
    CAST(CASE WHEN s.NetSatis > 0
              THEN (s.NetSatis - ma.faturaBirimMaliyet * s.NetAdet) * 100.0 / s.NetSatis
              ELSE NULL END AS DECIMAL(8,2))                    AS Marj_Yuzde,
    CASE WHEN ma.stkID IS NOT NULL THEN 'Var' ELSE 'Yok' END    AS MaliyetDurum
FROM SatisOzet s
INNER JOIN KitapUrun ku ON ku.stkID = s.ehstkID
LEFT  JOIN MaliyetA  ma ON ma.stkID = s.ehstkID
ORDER BY s.NetSatis DESC;


-- ================================================================
-- ÇIKTI 4: DOĞRULAMA (Mağaza × Maliyet bulunma oranı)
-- ================================================================
;WITH
KitapUrun AS (
    SELECT u.stkID FROM dbo.urn u WITH (NOLOCK)
    WHERE u.urnKtgr2ID IN (2,8,15,24)
),
SatisOzet AS (
    SELECT ih.ehMekan AS mekanID, ih.ehstkID,
           SUM(CASE WHEN ih.ehTip IN (1,4,100) THEN ih.ehTutarN ELSE 0 END) -
           SUM(CASE WHEN ih.ehTip IN (3,5,101) THEN ih.ehTutarN ELSE 0 END) AS NetSatis
    FROM dbo.irsHrk ih WITH (NOLOCK)
    WHERE ih.ehMekan IN (1,4477,4478)
      AND ih.hrkTarih >= CONVERT(DATE,'06.05.2026',104)
      AND ih.hrkTarih <  CONVERT(DATE,'08.05.2026',104)
      AND ih.ehTip IN (1,4,100,3,5,101)
      AND ih.ehAltDepo = 0
      AND ih.ehstkID IN (SELECT stkID FROM KitapUrun)
    GROUP BY ih.ehMekan, ih.ehstkID
),
MaliyetA_Aday AS (
    SELECT fa.ehStkID AS stkID,
           ROW_NUMBER() OVER (PARTITION BY fa.ehStkID ORDER BY f.eTarih DESC) AS rn
    FROM dbo.fat f WITH (NOLOCK)
    INNER JOIN dbo.fatAyr fa WITH (NOLOCK) ON fa.ehID = f.eID
    WHERE f.eGC=1 AND f.onay=1 AND f.eDurum=0 AND f.eDvzID=1
      AND f.eTarih >= CONVERT(DATE,'06.05.2024',104)
      AND fa.ehAdetN < 0 AND fa.ehTutarN > 0
      AND fa.ehStkID IN (SELECT stkID FROM KitapUrun)
),
MaliyetA AS (SELECT stkID FROM MaliyetA_Aday WHERE rn=1)
SELECT
    s.mekanID,
    CASE s.mekanID WHEN 1 THEN 'FSM' WHEN 4477 THEN 'Özlüce' WHEN 4478 THEN 'İst.Yolu' END AS mekanAd,
    COUNT(*) AS toplam_urun,
    SUM(CASE WHEN ma.stkID IS NOT NULL THEN 1 ELSE 0 END) AS maliyetli_urun,
    CAST(SUM(CASE WHEN ma.stkID IS NOT NULL THEN 1 ELSE 0 END) * 100.0
         / NULLIF(COUNT(*),0) AS DECIMAL(5,2)) AS maliyetli_urun_yuzde,
    SUM(s.NetSatis) AS toplam_satis,
    SUM(CASE WHEN ma.stkID IS NOT NULL THEN s.NetSatis ELSE 0 END) AS maliyetli_satis,
    CAST(SUM(CASE WHEN ma.stkID IS NOT NULL THEN s.NetSatis ELSE 0 END) * 100.0
         / NULLIF(SUM(s.NetSatis),0) AS DECIMAL(5,2)) AS maliyetli_satis_yuzde
FROM SatisOzet s
LEFT JOIN MaliyetA ma ON ma.stkID = s.ehstkID
GROUP BY s.mekanID
ORDER BY s.mekanID;

-- ================================================================
-- NOT 1: Satış kaynağı = irsHrk (TÜM irsaliye/satış hareketleri).
--        Sales+SalesProducts'tan farklı: Sınav Okulları DAHIL,
--        irsaliye-bazlı (POS terminal değil).
--
-- NOT 2: ehAltDepo = 0 → ana depo hariç (mağaza içi alt depo
--        hareketleri ÇIKARILDI). Eğer alt depolar dahil edilmek
--        istenirse bu filtreyi kaldır.
--
-- NOT 3: Maliyet yine fatAyr (DerinSIS son alış faturası birim).
--        Formül: ehTutarN / ABS(ehAdetN), eGC=1, onay=1, eDurum=0.
--
-- NOT 4: Mağaza × kategori marjı %22-25 civarı bekleniyor. Eğer
--        bir mağaza %5 altı veya %50 üstü çıkarsa kontrol et:
--        - Sınav Okulları paket yansıması (4478'de bilinen sorun)
--        - 3al2öde indirim
--        - Yeni LGS kitapları (fatura yok → maliyet NULL)
-- ================================================================
