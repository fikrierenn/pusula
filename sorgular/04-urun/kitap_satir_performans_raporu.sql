-- EncoreMerkez — Kitap Satır Performans Raporu (Kampanya Kırılımlı)
-- Sadece Kitap/Hazırlık/Çocuk/Akademi kategorisindeki ürün SATIRLARI.
-- Fişteki kırtasiye/oyuncak satırları DAHİL DEĞİL.
-- SalesProducts seviyesinde: TotalPrice, DiscountTotalDirect, Amount
-- Pivot: Kampanya grupları (3Al2Ode, DigerKmp, Kampanyasiz) kolonlarda
-- Mapping: Barcodes.BarcodeNo → DerinSISBkm.dbo.urnBrkd.urnBarkod → stkID → bkm.urunbilgi.Kategori3
-- Veritabanı: EncoreMerkez (cross-db join DerinSISBkm)
-- 2 Result Set:
--   1) Mevcut ay: gün+mağaza detay → gün toplam → ay toplam
--   2) Önceki aylar: ay+mağaza detay → ay toplam
-- ============================================
SET NOCOUNT ON

-- Tarih aralığı: mevcut yıl başı → bugün
DECLARE @baslangic date = DATEADD(DAY, 1-DATEPART(DAYOFYEAR, GETDATE()), CAST(GETDATE() AS date))
DECLARE @bitis date = CAST(GETDATE() AS date)

-- 1) Kitap satırlarını topla
IF OBJECT_ID('tempdb..#kitap_satir') IS NOT NULL DROP TABLE #kitap_satir

SELECT
    CAST(s.Date AS date) AS Gun,
    st.Name AS Magaza,
    sp.Amount,
    sp.TotalPrice,
    sp.DiscountTotalDirect,
    CASE
        WHEN s.DocumentsTypeId = 3 THEN 'Iade'
        WHEN fkt.Has3Al2Ode = 1 THEN '3Al2Ode'
        WHEN fkt.SalesId IS NOT NULL THEN 'Diger'
        ELSE 'Kampanyasiz'
    END AS KTip,
    CASE WHEN s.DocumentsTypeId = 3 THEN -1 ELSE 1 END AS IadeIsareti
INTO #kitap_satir
FROM dbo.Sales s
INNER JOIN dbo.SalesProducts sp ON sp.SalesId = s.Id AND sp.IsValid = 1
INNER JOIN dbo.Stores st ON s.StoresId = st.Id
CROSS APPLY (
    SELECT TOP 1 u.Kategori3
    FROM dbo.Barcodes b
    INNER JOIN DerinSISBkm.dbo.urnBrkd br
        ON b.BarcodeNo COLLATE Turkish_CI_AS = br.urnBarkod COLLATE Turkish_CI_AS
    INNER JOIN DerinSISBkm.bkm.urunbilgi u ON br.urnBrkdStkID = u.stkID
    WHERE b.ProductsId = sp.ProductsId
      AND u.Kategori3 IN ('Kitap', N'Hazırlık Kitapları', N'Çocuk Kitabı', 'Akademi')
) kat
LEFT JOIN (
    SELECT SalesId,
        MAX(CASE WHEN CampaignId IN (1,12) THEN 1 ELSE 0 END) AS Has3Al2Ode
    FROM dbo.SalesProductCampaigns
    GROUP BY SalesId
) fkt ON fkt.SalesId = s.Id
WHERE s.DocumentsTypeId IN (1, 2, 3, 6, 7, 8)
  AND s.Date >= @baslangic AND s.Date <= @bitis

-- =============================================
-- RESULT SET 1: MEVCUT AY
-- gün+mağaza detay → gün toplam → ay toplam
-- =============================================
;WITH gun_detay AS (
    SELECT CONVERT(varchar, Gun, 104) AS Tarih, Magaza,
        Gun AS SortKey, 0 AS IsTotal,
        KTip, Amount, TotalPrice, DiscountTotalDirect, IadeIsareti
    FROM #kitap_satir WHERE YEAR(Gun)=YEAR(GETDATE()) AND MONTH(Gun)=MONTH(GETDATE())
    UNION ALL
    SELECT CONVERT(varchar, Gun, 104) AS Tarih, 'TOPLAM' AS Magaza,
        Gun AS SortKey, 1 AS IsTotal,
        KTip, Amount, TotalPrice, DiscountTotalDirect, IadeIsareti
    FROM #kitap_satir WHERE YEAR(Gun)=YEAR(GETDATE()) AND MONTH(Gun)=MONTH(GETDATE())
    UNION ALL
    SELECT 'AY TOPLAM' AS Tarih, '' AS Magaza,
        CAST('2099-12-31' AS date) AS SortKey, 1 AS IsTotal,
        KTip, Amount, TotalPrice, DiscountTotalDirect, IadeIsareti
    FROM #kitap_satir WHERE YEAR(Gun)=YEAR(GETDATE()) AND MONTH(Gun)=MONTH(GETDATE())
),
ham AS (
SELECT
    Tarih, Magaza,
    ----- 3 AL 2 ÖDE -----
    SUM(CASE WHEN KTip='3Al2Ode' THEN 1 ELSE 0 END) AS [3Al2Ode Satir],
    CAST(SUM(CASE WHEN KTip='3Al2Ode' THEN IadeIsareti*Amount ELSE 0 END) AS decimal(18,1)) AS [3Al2Ode Adet],
    CAST(SUM(CASE WHEN KTip='3Al2Ode' THEN IadeIsareti*(TotalPrice+DiscountTotalDirect) ELSE 0 END) AS decimal(18,2)) AS [3Al2Ode Brut],
    CAST(SUM(CASE WHEN KTip='3Al2Ode' THEN IadeIsareti*DiscountTotalDirect ELSE 0 END) AS decimal(18,2)) AS [3Al2Ode Indirim],
    CAST(SUM(CASE WHEN KTip='3Al2Ode' THEN IadeIsareti*TotalPrice ELSE 0 END) AS decimal(18,2)) AS [3Al2Ode Net],
    CAST(CASE WHEN SUM(CASE WHEN KTip='3Al2Ode' THEN IadeIsareti*Amount ELSE 0 END)>0
        THEN SUM(CASE WHEN KTip='3Al2Ode' THEN IadeIsareti*(TotalPrice+DiscountTotalDirect) ELSE 0 END)*1.0
            /SUM(CASE WHEN KTip='3Al2Ode' THEN IadeIsareti*Amount ELSE 0 END)
        ELSE 0 END AS decimal(10,2)) AS [3Al2Ode Ort Birim Fiyat],
    CAST(CASE WHEN SUM(CASE WHEN KTip='3Al2Ode' THEN IadeIsareti*(TotalPrice+DiscountTotalDirect) ELSE 0 END)>0
        THEN SUM(CASE WHEN KTip='3Al2Ode' THEN IadeIsareti*DiscountTotalDirect ELSE 0 END)*100.0
            /SUM(CASE WHEN KTip='3Al2Ode' THEN IadeIsareti*(TotalPrice+DiscountTotalDirect) ELSE 0 END)
        ELSE 0 END AS decimal(5,1)) AS [3Al2Ode Indirim Orani],
    ----- DİĞER KAMPANYA -----
    SUM(CASE WHEN KTip='Diger' THEN 1 ELSE 0 END) AS [DigerKmp Satir],
    CAST(SUM(CASE WHEN KTip='Diger' THEN IadeIsareti*Amount ELSE 0 END) AS decimal(18,1)) AS [DigerKmp Adet],
    CAST(SUM(CASE WHEN KTip='Diger' THEN IadeIsareti*(TotalPrice+DiscountTotalDirect) ELSE 0 END) AS decimal(18,2)) AS [DigerKmp Brut],
    CAST(SUM(CASE WHEN KTip='Diger' THEN IadeIsareti*DiscountTotalDirect ELSE 0 END) AS decimal(18,2)) AS [DigerKmp Indirim],
    CAST(SUM(CASE WHEN KTip='Diger' THEN IadeIsareti*TotalPrice ELSE 0 END) AS decimal(18,2)) AS [DigerKmp Net],
    CAST(CASE WHEN SUM(CASE WHEN KTip='Diger' THEN IadeIsareti*Amount ELSE 0 END)>0
        THEN SUM(CASE WHEN KTip='Diger' THEN IadeIsareti*(TotalPrice+DiscountTotalDirect) ELSE 0 END)*1.0
            /SUM(CASE WHEN KTip='Diger' THEN IadeIsareti*Amount ELSE 0 END)
        ELSE 0 END AS decimal(10,2)) AS [DigerKmp Ort Birim Fiyat],
    CAST(CASE WHEN SUM(CASE WHEN KTip='Diger' THEN IadeIsareti*(TotalPrice+DiscountTotalDirect) ELSE 0 END)>0
        THEN SUM(CASE WHEN KTip='Diger' THEN IadeIsareti*DiscountTotalDirect ELSE 0 END)*100.0
            /SUM(CASE WHEN KTip='Diger' THEN IadeIsareti*(TotalPrice+DiscountTotalDirect) ELSE 0 END)
        ELSE 0 END AS decimal(5,1)) AS [DigerKmp Indirim Orani],
    ----- KAMPANYASIZ -----
    SUM(CASE WHEN KTip='Kampanyasiz' THEN 1 ELSE 0 END) AS [Kampanyasiz Satir],
    CAST(SUM(CASE WHEN KTip='Kampanyasiz' THEN IadeIsareti*Amount ELSE 0 END) AS decimal(18,1)) AS [Kampanyasiz Adet],
    CAST(SUM(CASE WHEN KTip='Kampanyasiz' THEN IadeIsareti*TotalPrice ELSE 0 END) AS decimal(18,2)) AS [Kampanyasiz Net],
    CAST(CASE WHEN SUM(CASE WHEN KTip='Kampanyasiz' THEN IadeIsareti*Amount ELSE 0 END)>0
        THEN SUM(CASE WHEN KTip='Kampanyasiz' THEN IadeIsareti*(TotalPrice+DiscountTotalDirect) ELSE 0 END)*1.0
            /SUM(CASE WHEN KTip='Kampanyasiz' THEN IadeIsareti*Amount ELSE 0 END)
        ELSE 0 END AS decimal(10,2)) AS [Kampanyasiz Ort Birim Fiyat],
    ----- GENEL TOPLAM -----
    COUNT(*) AS [Toplam Satir],
    CAST(SUM(IadeIsareti*Amount) AS decimal(18,1)) AS [Toplam Adet],
    CAST(SUM(IadeIsareti*(TotalPrice+DiscountTotalDirect)) AS decimal(18,2)) AS [Toplam Brut],
    CAST(SUM(IadeIsareti*DiscountTotalDirect) AS decimal(18,2)) AS [Toplam Indirim],
    CAST(SUM(IadeIsareti*TotalPrice) AS decimal(18,2)) AS [Toplam Net],
    CAST(CASE WHEN SUM(IadeIsareti*Amount)>0
        THEN SUM(IadeIsareti*(TotalPrice+DiscountTotalDirect))*1.0/SUM(IadeIsareti*Amount)
        ELSE 0 END AS decimal(10,2)) AS [Toplam Ort Birim Fiyat],
    CAST(CASE WHEN SUM(IadeIsareti*(TotalPrice+DiscountTotalDirect))>0
        THEN SUM(IadeIsareti*DiscountTotalDirect)*100.0/SUM(IadeIsareti*(TotalPrice+DiscountTotalDirect))
        ELSE 0 END AS decimal(5,1)) AS [Toplam Indirim Orani],
    ----- 3AL2ÖDE PAYLARI -----
    CAST(SUM(CASE WHEN KTip='3Al2Ode' THEN 1 ELSE 0 END)*100.0/COUNT(*) AS decimal(5,1)) AS [3Al2Ode Satir Payi %],
    CAST(CASE WHEN SUM(IadeIsareti*Amount)>0
        THEN SUM(CASE WHEN KTip='3Al2Ode' THEN IadeIsareti*Amount ELSE 0 END)*100.0/SUM(IadeIsareti*Amount)
        ELSE 0 END AS decimal(5,1)) AS [3Al2Ode Adet Payi %],
    CAST(CASE WHEN SUM(IadeIsareti*TotalPrice)>0
        THEN SUM(CASE WHEN KTip='3Al2Ode' THEN IadeIsareti*TotalPrice ELSE 0 END)*100.0/SUM(IadeIsareti*TotalPrice)
        ELSE 0 END AS decimal(5,1)) AS [3Al2Ode Ciro Payi %],
    SortKey, IsTotal
FROM gun_detay
GROUP BY Tarih, Magaza, SortKey, IsTotal
)
SELECT TOP 200
    Tarih, Magaza,
    [3Al2Ode Satir], [3Al2Ode Adet], [3Al2Ode Brut], [3Al2Ode Indirim], [3Al2Ode Net],
    [3Al2Ode Ort Birim Fiyat], [3Al2Ode Indirim Orani] AS [3Al2Ode Indirim Orani %],
    [DigerKmp Satir], [DigerKmp Adet], [DigerKmp Brut], [DigerKmp Indirim], [DigerKmp Net],
    [DigerKmp Ort Birim Fiyat], [DigerKmp Indirim Orani] AS [DigerKmp Indirim Orani %],
    [Kampanyasiz Satir], [Kampanyasiz Adet], [Kampanyasiz Net], [Kampanyasiz Ort Birim Fiyat],
    [Toplam Satir], [Toplam Adet], [Toplam Brut], [Toplam Indirim], [Toplam Net],
    [Toplam Ort Birim Fiyat], [Toplam Indirim Orani] AS [Toplam Indirim Orani %],
    [3Al2Ode Satir Payi %], [3Al2Ode Adet Payi %], [3Al2Ode Ciro Payi %]
FROM ham
ORDER BY SortKey DESC, IsTotal DESC, Magaza

-- =============================================
-- RESULT SET 2: ÖNCEKİ AYLAR
-- ay+mağaza detay → ay toplam
-- =============================================
;WITH ay_detay AS (
    SELECT RIGHT('0'+CAST(MONTH(Gun) AS varchar),2)+'.'+CAST(YEAR(Gun) AS varchar) AS Tarih, Magaza,
        CAST(CAST(YEAR(Gun) AS varchar)+'-'+RIGHT('0'+CAST(MONTH(Gun) AS varchar),2)+'-01' AS date) AS SortKey, 0 AS IsTotal,
        KTip, Amount, TotalPrice, DiscountTotalDirect, IadeIsareti
    FROM #kitap_satir WHERE NOT(YEAR(Gun)=YEAR(GETDATE()) AND MONTH(Gun)=MONTH(GETDATE()))
    UNION ALL
    SELECT RIGHT('0'+CAST(MONTH(Gun) AS varchar),2)+'.'+CAST(YEAR(Gun) AS varchar) AS Tarih, 'TOPLAM' AS Magaza,
        CAST(CAST(YEAR(Gun) AS varchar)+'-'+RIGHT('0'+CAST(MONTH(Gun) AS varchar),2)+'-01' AS date) AS SortKey, 1 AS IsTotal,
        KTip, Amount, TotalPrice, DiscountTotalDirect, IadeIsareti
    FROM #kitap_satir WHERE NOT(YEAR(Gun)=YEAR(GETDATE()) AND MONTH(Gun)=MONTH(GETDATE()))
),
ham2 AS (
SELECT
    Tarih, Magaza,
    ----- 3 AL 2 ÖDE -----
    SUM(CASE WHEN KTip='3Al2Ode' THEN 1 ELSE 0 END) AS [3Al2Ode Satir],
    CAST(SUM(CASE WHEN KTip='3Al2Ode' THEN IadeIsareti*Amount ELSE 0 END) AS decimal(18,1)) AS [3Al2Ode Adet],
    CAST(SUM(CASE WHEN KTip='3Al2Ode' THEN IadeIsareti*(TotalPrice+DiscountTotalDirect) ELSE 0 END) AS decimal(18,2)) AS [3Al2Ode Brut],
    CAST(SUM(CASE WHEN KTip='3Al2Ode' THEN IadeIsareti*DiscountTotalDirect ELSE 0 END) AS decimal(18,2)) AS [3Al2Ode Indirim],
    CAST(SUM(CASE WHEN KTip='3Al2Ode' THEN IadeIsareti*TotalPrice ELSE 0 END) AS decimal(18,2)) AS [3Al2Ode Net],
    CAST(CASE WHEN SUM(CASE WHEN KTip='3Al2Ode' THEN IadeIsareti*Amount ELSE 0 END)>0
        THEN SUM(CASE WHEN KTip='3Al2Ode' THEN IadeIsareti*(TotalPrice+DiscountTotalDirect) ELSE 0 END)*1.0
            /SUM(CASE WHEN KTip='3Al2Ode' THEN IadeIsareti*Amount ELSE 0 END)
        ELSE 0 END AS decimal(10,2)) AS [3Al2Ode Ort Birim Fiyat],
    CAST(CASE WHEN SUM(CASE WHEN KTip='3Al2Ode' THEN IadeIsareti*(TotalPrice+DiscountTotalDirect) ELSE 0 END)>0
        THEN SUM(CASE WHEN KTip='3Al2Ode' THEN IadeIsareti*DiscountTotalDirect ELSE 0 END)*100.0
            /SUM(CASE WHEN KTip='3Al2Ode' THEN IadeIsareti*(TotalPrice+DiscountTotalDirect) ELSE 0 END)
        ELSE 0 END AS decimal(5,1)) AS [3Al2Ode Indirim Orani],
    ----- DİĞER KAMPANYA -----
    SUM(CASE WHEN KTip='Diger' THEN 1 ELSE 0 END) AS [DigerKmp Satir],
    CAST(SUM(CASE WHEN KTip='Diger' THEN IadeIsareti*Amount ELSE 0 END) AS decimal(18,1)) AS [DigerKmp Adet],
    CAST(SUM(CASE WHEN KTip='Diger' THEN IadeIsareti*(TotalPrice+DiscountTotalDirect) ELSE 0 END) AS decimal(18,2)) AS [DigerKmp Brut],
    CAST(SUM(CASE WHEN KTip='Diger' THEN IadeIsareti*DiscountTotalDirect ELSE 0 END) AS decimal(18,2)) AS [DigerKmp Indirim],
    CAST(SUM(CASE WHEN KTip='Diger' THEN IadeIsareti*TotalPrice ELSE 0 END) AS decimal(18,2)) AS [DigerKmp Net],
    CAST(CASE WHEN SUM(CASE WHEN KTip='Diger' THEN IadeIsareti*Amount ELSE 0 END)>0
        THEN SUM(CASE WHEN KTip='Diger' THEN IadeIsareti*(TotalPrice+DiscountTotalDirect) ELSE 0 END)*1.0
            /SUM(CASE WHEN KTip='Diger' THEN IadeIsareti*Amount ELSE 0 END)
        ELSE 0 END AS decimal(10,2)) AS [DigerKmp Ort Birim Fiyat],
    CAST(CASE WHEN SUM(CASE WHEN KTip='Diger' THEN IadeIsareti*(TotalPrice+DiscountTotalDirect) ELSE 0 END)>0
        THEN SUM(CASE WHEN KTip='Diger' THEN IadeIsareti*DiscountTotalDirect ELSE 0 END)*100.0
            /SUM(CASE WHEN KTip='Diger' THEN IadeIsareti*(TotalPrice+DiscountTotalDirect) ELSE 0 END)
        ELSE 0 END AS decimal(5,1)) AS [DigerKmp Indirim Orani],
    ----- KAMPANYASIZ -----
    SUM(CASE WHEN KTip='Kampanyasiz' THEN 1 ELSE 0 END) AS [Kampanyasiz Satir],
    CAST(SUM(CASE WHEN KTip='Kampanyasiz' THEN IadeIsareti*Amount ELSE 0 END) AS decimal(18,1)) AS [Kampanyasiz Adet],
    CAST(SUM(CASE WHEN KTip='Kampanyasiz' THEN IadeIsareti*TotalPrice ELSE 0 END) AS decimal(18,2)) AS [Kampanyasiz Net],
    CAST(CASE WHEN SUM(CASE WHEN KTip='Kampanyasiz' THEN IadeIsareti*Amount ELSE 0 END)>0
        THEN SUM(CASE WHEN KTip='Kampanyasiz' THEN IadeIsareti*(TotalPrice+DiscountTotalDirect) ELSE 0 END)*1.0
            /SUM(CASE WHEN KTip='Kampanyasiz' THEN IadeIsareti*Amount ELSE 0 END)
        ELSE 0 END AS decimal(10,2)) AS [Kampanyasiz Ort Birim Fiyat],
    ----- GENEL TOPLAM -----
    COUNT(*) AS [Toplam Satir],
    CAST(SUM(IadeIsareti*Amount) AS decimal(18,1)) AS [Toplam Adet],
    CAST(SUM(IadeIsareti*(TotalPrice+DiscountTotalDirect)) AS decimal(18,2)) AS [Toplam Brut],
    CAST(SUM(IadeIsareti*DiscountTotalDirect) AS decimal(18,2)) AS [Toplam Indirim],
    CAST(SUM(IadeIsareti*TotalPrice) AS decimal(18,2)) AS [Toplam Net],
    CAST(CASE WHEN SUM(IadeIsareti*Amount)>0
        THEN SUM(IadeIsareti*(TotalPrice+DiscountTotalDirect))*1.0/SUM(IadeIsareti*Amount)
        ELSE 0 END AS decimal(10,2)) AS [Toplam Ort Birim Fiyat],
    CAST(CASE WHEN SUM(IadeIsareti*(TotalPrice+DiscountTotalDirect))>0
        THEN SUM(IadeIsareti*DiscountTotalDirect)*100.0/SUM(IadeIsareti*(TotalPrice+DiscountTotalDirect))
        ELSE 0 END AS decimal(5,1)) AS [Toplam Indirim Orani],
    ----- 3AL2ÖDE PAYLARI -----
    CAST(SUM(CASE WHEN KTip='3Al2Ode' THEN 1 ELSE 0 END)*100.0/COUNT(*) AS decimal(5,1)) AS [3Al2Ode Satir Payi %],
    CAST(CASE WHEN SUM(IadeIsareti*Amount)>0
        THEN SUM(CASE WHEN KTip='3Al2Ode' THEN IadeIsareti*Amount ELSE 0 END)*100.0/SUM(IadeIsareti*Amount)
        ELSE 0 END AS decimal(5,1)) AS [3Al2Ode Adet Payi %],
    CAST(CASE WHEN SUM(IadeIsareti*TotalPrice)>0
        THEN SUM(CASE WHEN KTip='3Al2Ode' THEN IadeIsareti*TotalPrice ELSE 0 END)*100.0/SUM(IadeIsareti*TotalPrice)
        ELSE 0 END AS decimal(5,1)) AS [3Al2Ode Ciro Payi %],
    SortKey, IsTotal
FROM ay_detay
GROUP BY Tarih, Magaza, SortKey, IsTotal
)
SELECT TOP 100
    Tarih, Magaza,
    [3Al2Ode Satir], [3Al2Ode Adet], [3Al2Ode Brut], [3Al2Ode Indirim], [3Al2Ode Net],
    [3Al2Ode Ort Birim Fiyat], [3Al2Ode Indirim Orani] AS [3Al2Ode Indirim Orani %],
    [DigerKmp Satir], [DigerKmp Adet], [DigerKmp Brut], [DigerKmp Indirim], [DigerKmp Net],
    [DigerKmp Ort Birim Fiyat], [DigerKmp Indirim Orani] AS [DigerKmp Indirim Orani %],
    [Kampanyasiz Satir], [Kampanyasiz Adet], [Kampanyasiz Net], [Kampanyasiz Ort Birim Fiyat],
    [Toplam Satir], [Toplam Adet], [Toplam Brut], [Toplam Indirim], [Toplam Net],
    [Toplam Ort Birim Fiyat], [Toplam Indirim Orani] AS [Toplam Indirim Orani %],
    [3Al2Ode Satir Payi %], [3Al2Ode Adet Payi %], [3Al2Ode Ciro Payi %]
FROM ham2
ORDER BY SortKey DESC, IsTotal DESC, Magaza

DROP TABLE #kitap_satir
