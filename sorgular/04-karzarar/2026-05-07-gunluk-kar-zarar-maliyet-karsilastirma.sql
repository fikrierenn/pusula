/*================================================================
  Günlük Kâr/Zarar — Kitap Kategorisi
  Maliyet Kaynağı: Son Alış Faturası (fatAyr.ehMaliyet)
  ----------------------------------------------------------------
  Yazan         : Claude (Fikri için)
  Tarih         : 07.05.2026
  Plan          : plans/04-gunluk-kar-zarar-maliyet-karsilastirma.md
  Bağlantı      : EncoreMerkez (POS satış) + DerinSISBkm cross-db
  Run           : SSMS, sorguyu olduğu gibi çalıştır.

  TASARIM NOTU (07.05.2026 revize):
    İlk versiyonda iki ayrı maliyet kaynağı (fat+fatAyr ile irsHrk)
    karşılaştırması planlanmıştı. Test sonucu:
      1. irsHrk.ehMlyt: BKM'de %99+ BOŞ (FIFO/ortalama aktif değil)
      2. fatAyr.ehMaliyet: KOLON HEP 0 — kullanılmıyor
      3. ASIL FORMÜL: ehTutarN / ABS(ehAdetN) = birim alış (KDV hariç)
    DerinSIS alış faturası convention'ı:
      - eGC=1 (giriş) satırlarda ehAdet/ehAdetN NEGATİF
      - ehTutarN pozitif (KDV hariç net)
      - Birim maliyet = ehTutarN / ABS(ehAdetN)

  KULLANIM:
    @BasTarih, @BitTarih: Aralık DAHİL/HARİÇ — BitTarih DAHİL DEĞİL
                          (gün sonunu kapsamak için ertesi gün ver)
    Örnek: 06-07 Mayıs 2026 = '06.05.2026' .. '08.05.2026'
    @KategoriIDList: kitap kategorileri (default 2,8,15,24)
    @YalnizTL: 1 (default) → sadece TL alış faturaları
    @TopN: detay result-set en çok kaç ürün (default 200)

  KAPSAM:
    - Sadece POS satışları (Sales/SalesProducts), JOKER hariç
    - Kitap kategorileri: Çocuk Kitabı (2) + Hazırlık (8)
                       + Kitap (15) + Akademi (24)
    - Mağaza ayrımı YAPILMAMIŞ — global birim maliyet
    - Maliyet = fatAyr.ehTutarN / ABS(fatAyr.ehAdetN) (son alış, KDV hariç)
      (ehMaliyet kolonu BKM'de kullanılmıyor — hep 0)

  ÇIKTI:
    Result-set 1: Ürün-bazlı detay (top N, NetSatis DESC)
    Result-set 2: Kategori özet
    Result-set 3: Doğrulama metrikleri (köprü eşleşme + maliyet
                  bulunma oranı)

  BİLİNEN SINIRLAMALAR:
    - Yabancı para alışları kapsam dışı (eDvzID=1 filtresi)
    - JOKER e-ticaret kanalı kapsam dışı
    - Yeni ürünlerde son fatura yoksa Maliyet=NULL (MaliyetiYok flag'i)
    - Köprü eşleşmesi ~%99.4 (kalan ~%0.6 unmapped)
================================================================*/

USE EncoreMerkez;
SET NOCOUNT ON;

-- =============== PARAMETRELER ===============
DECLARE @BasTarih  DATE = CONVERT(DATE, '06.05.2026', 104);
DECLARE @BitTarih  DATE = CONVERT(DATE, '08.05.2026', 104);  -- DAHİL DEĞİL
DECLARE @YalnizTL  BIT  = 1;
DECLARE @TopN      INT  = 200;

DECLARE @KategoriID TABLE (id TINYINT PRIMARY KEY);
INSERT INTO @KategoriID(id) VALUES (2),(8),(15),(24);

-- Maliyet için lookback: son 24 ay (büyük tabloyu daraltır, kapsamı tutar)
DECLARE @MaliyetBaslangic DATE = DATEADD(MONTH, -24, @BasTarih);

-- ================================================================
-- ÇIKTI 1: ÜRÜN-BAZLI DETAY
-- ================================================================
;WITH
KitapUrun AS (
    SELECT u.stkID, u.stkKod, u.stkAd, u.urnKtgr2ID,
           CAST(k.ktgrAd AS NVARCHAR(50)) AS ktgrAd
    FROM DerinSISBkm.dbo.urn u WITH (NOLOCK)
    INNER JOIN DerinSISBkm.dbo.urnKtgr2 k WITH (NOLOCK) ON k.ktgrID = u.urnKtgr2ID
    WHERE u.urnKtgr2ID IN (SELECT id FROM @KategoriID)
),
SatisHam AS (
    SELECT
        sp.Id                                AS SatirId,
        s.Id                                 AS SalesId,
        s.[Date]                             AS SatisTarih,
        s.DocumentsTypeId,
        sp.ProductsId,
        sp.BarcodeNo,
        p.Code                               AS ProductsCode,
        sp.Amount,
        sp.TotalPrice,
        sp.DiscountTotalDirect,
        sp.VatPercent,
        sp.VatTotal,
        u_b.stkID                            AS stkID,
        u_b.stkKod                           AS stkKod,
        u_b.stkAd                            AS stkAd,
        u_b.urnKtgr2ID                       AS urnKtgr2ID
    FROM dbo.SalesProducts sp WITH (NOLOCK)
    INNER JOIN dbo.Sales s WITH (NOLOCK)
        ON s.Id = sp.SalesId
    INNER JOIN dbo.Products p WITH (NOLOCK)
        ON p.Id = sp.ProductsId
    LEFT JOIN DerinSISBkm.dbo.urn u_b WITH (NOLOCK)
        ON u_b.stkID = CONVERT(int, p.Code) AND ISNUMERIC(p.Code) = 1   -- 09.06: Products.Code=stkID köprüsü (stkKod≠barkod)
       AND u_b.urnKtgr2ID IN (SELECT id FROM @KategoriID)
    WHERE sp.IsValid = 1
      AND s.[Date] >= @BasTarih
      AND s.[Date] <  @BitTarih
      AND s.DocumentsTypeId IN (1,2,3,6,7,8)
),
SatisFiltreli AS (
    SELECT *,
        CASE WHEN DocumentsTypeId = 3 THEN -1 ELSE 1 END AS IadeSign
    FROM SatisHam
    WHERE stkID IS NOT NULL
),
MaliyetA_Aday AS (
    -- DerinSIS convention: alış faturasında ehAdet/ehAdetN NEGATİF,
    -- ehTutarN pozitif (KDV hariç net). Birim = ehTutarN / ABS(ehAdetN)
    SELECT
        fa.ehStkID                                  AS stkID,
        f.eTarih                                    AS faturaTarih,
        f.eID                                       AS faturaID,
        f.eFirma                                    AS tedarikciID,
        ABS(fa.ehAdetN)                             AS faturaAdet,
        fa.ehTutarN                                 AS faturaTutarN,
        CAST(fa.ehTutarN / NULLIF(ABS(fa.ehAdetN), 0) AS DECIMAL(18,4)) AS faturaBirimMaliyet,
        ROW_NUMBER() OVER (
            PARTITION BY fa.ehStkID
            ORDER BY f.eTarih DESC, f.eID DESC, fa.ehSira DESC
        ) AS rn
    FROM DerinSISBkm.dbo.fat f WITH (NOLOCK)
    INNER JOIN DerinSISBkm.dbo.fatAyr fa WITH (NOLOCK)
        ON fa.ehID = f.eID
    WHERE f.eGC    = 1                  -- Giriş (alış)
      AND f.onay   = 1
      AND f.eDurum = 0
      AND f.eTarih >= @MaliyetBaslangic
      AND fa.ehAdetN < 0                -- DerinSIS convention: alış girişinde negatif
      AND fa.ehTutarN > 0
      AND (@YalnizTL = 0 OR f.eDvzID = 1)
      AND fa.ehStkID IN (SELECT stkID FROM KitapUrun)
),
MaliyetA AS (
    SELECT stkID, faturaTarih, faturaID, tedarikciID,
           faturaAdet, faturaTutarN, faturaBirimMaliyet
    FROM MaliyetA_Aday
    WHERE rn = 1
),
UrunOzet AS (
    SELECT
        sf.stkID,
        sf.stkKod,
        sf.stkAd,
        sf.urnKtgr2ID,
        SUM(sf.IadeSign * sf.Amount)                                AS NetAdet,
        SUM(sf.IadeSign * sf.TotalPrice)                            AS BrutSatis,
        SUM(sf.IadeSign * sf.DiscountTotalDirect)                   AS Indirim,
        SUM(sf.IadeSign * (sf.TotalPrice - sf.DiscountTotalDirect)) AS NetSatis,
        SUM(CASE WHEN sf.DocumentsTypeId = 3 THEN sf.Amount ELSE 0 END) AS IadeAdet,
        COUNT(DISTINCT sf.SalesId)                                  AS FisSayi
    FROM SatisFiltreli sf
    GROUP BY sf.stkID, sf.stkKod, sf.stkAd, sf.urnKtgr2ID
),
UrunFinal AS (
    SELECT
        u.stkID,
        u.stkKod,
        u.stkAd,
        ku.ktgrAd,
        u.NetAdet,
        u.IadeAdet,
        u.FisSayi,
        u.BrutSatis,
        u.Indirim,
        u.NetSatis,
        ma.faturaBirimMaliyet                                       AS MaliyetBirim,
        ma.faturaTarih                                              AS MaliyetTarih,
        ma.tedarikciID                                              AS SonTedarikciID,
        CAST(ma.faturaBirimMaliyet * u.NetAdet AS DECIMAL(18,2))    AS MaliyetToplam,
        CAST(u.NetSatis - (ma.faturaBirimMaliyet * u.NetAdet) AS DECIMAL(18,2)) AS Marj_TL,
        CAST(CASE WHEN u.NetSatis > 0
                  THEN (u.NetSatis - ma.faturaBirimMaliyet * u.NetAdet) * 100.0 / u.NetSatis
                  ELSE NULL END AS DECIMAL(8,2))                    AS Marj_Yuzde,
        CASE WHEN ma.stkID IS NOT NULL THEN 'Var' ELSE 'Yok' END    AS MaliyetDurum
    FROM UrunOzet u
    INNER JOIN KitapUrun ku ON ku.stkID = u.stkID
    LEFT JOIN MaliyetA ma ON ma.stkID = u.stkID
)
SELECT TOP (@TopN)
    stkID, stkKod, stkAd, ktgrAd,
    NetAdet, IadeAdet, FisSayi,
    BrutSatis, Indirim, NetSatis,
    MaliyetBirim, MaliyetTarih, SonTedarikciID, MaliyetToplam,
    Marj_TL, Marj_Yuzde,
    MaliyetDurum
FROM UrunFinal
ORDER BY NetSatis DESC;


-- ================================================================
-- ÇIKTI 2: KATEGORİ ÖZET
-- ================================================================
;WITH
KitapUrun AS (
    SELECT u.stkID, u.stkKod, u.urnKtgr2ID,
           CAST(k.ktgrAd AS NVARCHAR(50)) AS ktgrAd
    FROM DerinSISBkm.dbo.urn u WITH (NOLOCK)
    INNER JOIN DerinSISBkm.dbo.urnKtgr2 k WITH (NOLOCK) ON k.ktgrID = u.urnKtgr2ID
    WHERE u.urnKtgr2ID IN (2, 8, 15, 24)
),
SatisHam AS (
    SELECT s.DocumentsTypeId, sp.Amount, sp.TotalPrice, sp.DiscountTotalDirect,
           u_b.stkID AS stkID,
           CASE WHEN s.DocumentsTypeId = 3 THEN -1 ELSE 1 END AS IadeSign
    FROM dbo.SalesProducts sp WITH (NOLOCK)
    INNER JOIN dbo.Sales s WITH (NOLOCK) ON s.Id = sp.SalesId
    INNER JOIN dbo.Products p WITH (NOLOCK) ON p.Id = sp.ProductsId
    LEFT JOIN DerinSISBkm.dbo.urn u_b WITH (NOLOCK)
        ON u_b.stkID = CONVERT(int, p.Code) AND ISNUMERIC(p.Code) = 1   -- 09.06: Products.Code=stkID köprüsü (stkKod≠barkod)
       AND u_b.urnKtgr2ID IN (2,8,15,24)
    WHERE sp.IsValid = 1
      AND s.[Date] >= CONVERT(DATE,'06.05.2026',104)
      AND s.[Date] <  CONVERT(DATE,'08.05.2026',104)
      AND s.DocumentsTypeId IN (1,2,3,6,7,8)
),
SatisFiltreli AS (SELECT * FROM SatisHam WHERE stkID IS NOT NULL),
MaliyetA_Aday AS (
    SELECT fa.ehStkID AS stkID,
           CAST(fa.ehTutarN / NULLIF(ABS(fa.ehAdetN), 0) AS DECIMAL(18,4)) AS faturaBirimMaliyet,
           ROW_NUMBER() OVER (PARTITION BY fa.ehStkID ORDER BY f.eTarih DESC, f.eID DESC, fa.ehSira DESC) AS rn
    FROM DerinSISBkm.dbo.fat f WITH (NOLOCK)
    INNER JOIN DerinSISBkm.dbo.fatAyr fa WITH (NOLOCK) ON fa.ehID = f.eID
    WHERE f.eGC=1 AND f.onay=1 AND f.eDurum=0 AND f.eDvzID=1
      AND f.eTarih >= CONVERT(DATE,'06.05.2024',104)
      AND fa.ehAdetN < 0          -- DerinSIS: alış girişinde negatif
      AND fa.ehTutarN > 0
      AND fa.ehStkID IN (SELECT stkID FROM KitapUrun)
),
MaliyetA AS (SELECT stkID, faturaBirimMaliyet FROM MaliyetA_Aday WHERE rn=1),
UrunOzet AS (
    SELECT sf.stkID,
           SUM(sf.IadeSign * sf.Amount) AS NetAdet,
           SUM(sf.IadeSign * sf.TotalPrice) AS BrutSatis,
           SUM(sf.IadeSign * (sf.TotalPrice - sf.DiscountTotalDirect)) AS NetSatis
    FROM SatisFiltreli sf
    GROUP BY sf.stkID
)
SELECT
    ku.urnKtgr2ID,
    ku.ktgrAd                                                          AS Kategori,
    COUNT(DISTINCT u.stkID)                                            AS UrunCesidi,
    SUM(u.NetAdet)                                                     AS ToplamNetAdet,
    SUM(u.BrutSatis)                                                   AS ToplamBrutSatis,
    SUM(u.BrutSatis - u.NetSatis)                                      AS ToplamIndirim,
    SUM(u.NetSatis)                                                    AS ToplamNetSatis,
    SUM(CAST(ma.faturaBirimMaliyet * u.NetAdet AS DECIMAL(18,2)))      AS ToplamMaliyet,
    SUM(u.NetSatis) - SUM(CAST(ma.faturaBirimMaliyet * u.NetAdet AS DECIMAL(18,2))) AS ToplamMarj_TL,
    CAST((SUM(u.NetSatis) - SUM(CAST(ma.faturaBirimMaliyet * u.NetAdet AS DECIMAL(18,2)))) * 100.0
         / NULLIF(SUM(u.NetSatis),0) AS DECIMAL(8,2))                  AS Marj_Yuzde,
    SUM(CASE WHEN ma.stkID IS NOT NULL THEN 1 ELSE 0 END)              AS Urun_MaliyetVar,
    SUM(CASE WHEN ma.stkID IS NULL     THEN 1 ELSE 0 END)              AS Urun_MaliyetiYok,
    -- Maliyetli ürünlerin satış payı
    CAST(SUM(CASE WHEN ma.stkID IS NOT NULL THEN u.NetSatis ELSE 0 END) * 100.0
         / NULLIF(SUM(u.NetSatis),0) AS DECIMAL(8,2))                  AS MaliyetliSatis_Yuzde
FROM UrunOzet u
INNER JOIN KitapUrun ku ON ku.stkID = u.stkID
LEFT JOIN MaliyetA ma ON ma.stkID = u.stkID
GROUP BY ku.urnKtgr2ID, ku.ktgrAd
ORDER BY SUM(u.NetSatis) DESC;


-- ================================================================
-- ÇIKTI 3: DOĞRULAMA METRİKLERİ
-- ================================================================
;WITH BridgeStats AS (
    SELECT
        COUNT(*) AS toplam_satir,
        COUNT(CASE WHEN u_b.stkID IS NOT NULL THEN 1 END) AS eslesen,
        COUNT(CASE WHEN u_b.stkID IS NULL THEN 1 END) AS eslesmeyen,
        COUNT(CASE WHEN u_b.urnKtgr2ID IN (2,8,15,24) THEN 1 END) AS kitap_eslesen
    FROM dbo.SalesProducts sp WITH (NOLOCK)
    INNER JOIN dbo.Sales s WITH (NOLOCK) ON s.Id = sp.SalesId
    INNER JOIN dbo.Products p WITH (NOLOCK) ON p.Id = sp.ProductsId
    LEFT JOIN DerinSISBkm.dbo.urn u_b WITH (NOLOCK)
        ON u_b.stkID = CONVERT(int, p.Code) AND ISNUMERIC(p.Code) = 1   -- 09.06: Products.Code=stkID köprüsü (stkKod≠barkod)
    WHERE sp.IsValid = 1
      AND s.[Date] >= CONVERT(DATE,'06.05.2026',104)
      AND s.[Date] <  CONVERT(DATE,'08.05.2026',104)
      AND s.DocumentsTypeId IN (1,2,3,6,7,8)
)
SELECT
    'Köprü Eşleşme' AS Metrik,
    toplam_satir,
    eslesen,
    eslesmeyen,
    CAST(eslesen * 100.0 / NULLIF(toplam_satir,0) AS DECIMAL(5,2)) AS Yuzde,
    kitap_eslesen
FROM BridgeStats;

-- ================================================================
-- NOT 1: İlk çalıştırmada @BasTarih..@BitTarih dar bir aralıkta
--        (örn. 1-2 gün) deneyin. Geniş aralıkta (>30 gün) Maliyet
--        CTE'si fatAyr indeksini ağır tarayabilir.
--
-- NOT 2: MaliyetDurum='Yok' olan ürünler:
--        - Yeni ürün, henüz alış faturası kesilmemiş
--        - Konsinye/sınav okulları kitabı (yayınevi direkt)
--        - 24 aydan eski son alış (lookback dışı)
--        Bu ürünler için maliyet=0 değil NULL → Marj hesaplanmaz.
--
-- NOT 3: İade satırı (DocumentsTypeId=3) için sign çevriliyor:
--        Brüt, indirim, net ve maliyet TÜMÜ negatife dönüyor.
--        Tek günde iade > satış olursa kategori toplamı NEGATİF olabilir.
--
-- NOT 4: Yabancı para alışları (eDvzID<>1) HARİÇ TUTULDU.
--        İthal ürün varsa MaliyetDurum='Yok' görüntülenir.
-- ================================================================
