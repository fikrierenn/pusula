-- EncoreMerkez — Kitap Fiş Performans Raporu
-- Sadece en az 1 adet Kitap/Hazırlık/Çocuk/Akademi ürünü içeren fişler.
-- Fiş bazlı: fişin TÜMMM satırları (kırtasiye dahil) dahildir.
-- Pivot format: 3al2ode_performans_raporu.sql ile aynı yapı.
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

-- 1) Kitap içeren fişleri bul
IF OBJECT_ID('tempdb..#kitap_fisid') IS NOT NULL DROP TABLE #kitap_fisid

SELECT DISTINCT sp.SalesId
INTO #kitap_fisid
FROM dbo.Sales s
INNER JOIN dbo.SalesProducts sp ON sp.SalesId = s.Id AND sp.IsValid = 1
CROSS APPLY (
    SELECT TOP 1 u.Kategori3
    FROM dbo.Barcodes b
    INNER JOIN DerinSISBkm.dbo.urnBrkd br
        ON b.BarcodeNo COLLATE Turkish_CI_AS = br.urnBarkod COLLATE Turkish_CI_AS
    INNER JOIN DerinSISBkm.bkm.urunbilgi u ON br.urnBrkdStkID = u.stkID
    WHERE b.ProductsId = sp.ProductsId
      AND u.Kategori3 IN ('Kitap', N'Hazırlık Kitapları', N'Çocuk Kitabı', 'Akademi')
) kat
WHERE s.DocumentsTypeId IN (1, 2, 3, 6, 7, 8)
  AND s.Date >= @baslangic AND s.Date <= @bitis

-- 2) Kitap fişlerini #fis'e al (fiş bazlı metrikler)
IF OBJECT_ID('tempdb..#fis') IS NOT NULL DROP TABLE #fis

SELECT
    CAST(s.Date AS date) AS Gun,
    st.Name AS Magaza,
    gc.GecerliUrun AS LineCount,
    s.GrossTotal,
    s.DiscountTotal,
    CASE
        WHEN s.DocumentsTypeId = 3 THEN 'Iade'
        WHEN fkt.Has3Al2Ode = 1 THEN '3Al2Ode'
        WHEN fkt.SalesId IS NOT NULL THEN 'Diger'
        ELSE 'Kampanyasiz'
    END AS KTip,
    CASE WHEN s.DocumentsTypeId = 3 THEN -1 ELSE 1 END AS IadeIsareti
INTO #fis
FROM dbo.Sales s
INNER JOIN #kitap_fisid kf ON s.Id = kf.SalesId
INNER JOIN dbo.Stores st ON s.StoresId = st.Id
CROSS APPLY (
    SELECT COUNT(*) AS GecerliUrun
    FROM dbo.SalesProducts sp
    WHERE sp.SalesId = s.Id AND sp.IsValid = 1
) gc
LEFT JOIN (
    SELECT SalesId,
        MAX(CASE WHEN CampaignId IN (1,12) THEN 1 ELSE 0 END) AS Has3Al2Ode
    FROM dbo.SalesProductCampaigns
    GROUP BY SalesId
) fkt ON fkt.SalesId = s.Id

DROP TABLE #kitap_fisid

-- =============================================
-- RESULT SET 1: MEVCUT AY
-- gün+mağaza detay → gün toplam → ay toplam
-- =============================================
;WITH gun_detay AS (
    SELECT CONVERT(varchar, Gun, 104) AS Tarih, Magaza,
        Gun AS SortKey, 0 AS IsTotal,
        KTip, LineCount, GrossTotal, DiscountTotal, IadeIsareti
    FROM #fis WHERE YEAR(Gun)=YEAR(GETDATE()) AND MONTH(Gun)=MONTH(GETDATE())
    UNION ALL
    SELECT CONVERT(varchar, Gun, 104) AS Tarih, 'TOPLAM' AS Magaza,
        Gun AS SortKey, 1 AS IsTotal,
        KTip, LineCount, GrossTotal, DiscountTotal, IadeIsareti
    FROM #fis WHERE YEAR(Gun)=YEAR(GETDATE()) AND MONTH(Gun)=MONTH(GETDATE())
    UNION ALL
    SELECT 'AY TOPLAM' AS Tarih, '' AS Magaza,
        CAST('2099-12-31' AS date) AS SortKey, 1 AS IsTotal,
        KTip, LineCount, GrossTotal, DiscountTotal, IadeIsareti
    FROM #fis WHERE YEAR(Gun)=YEAR(GETDATE()) AND MONTH(Gun)=MONTH(GETDATE())
),
ham AS (
SELECT
    Tarih, Magaza,
    ----- 3 AL 2 ÖDE -----
    SUM(CASE WHEN KTip='3Al2Ode' THEN 1 ELSE 0 END) AS [3Al2Ode Fis],
    SUM(CASE WHEN KTip='3Al2Ode' THEN IadeIsareti*LineCount ELSE 0 END) AS [3Al2Ode Urun],
    CAST(SUM(CASE WHEN KTip='3Al2Ode' THEN IadeIsareti*GrossTotal ELSE 0 END) AS decimal(18,2)) AS [3Al2Ode Brut],
    CAST(SUM(CASE WHEN KTip='3Al2Ode' THEN IadeIsareti*DiscountTotal ELSE 0 END) AS decimal(18,2)) AS [3Al2Ode Indirim],
    CAST(SUM(CASE WHEN KTip='3Al2Ode' THEN IadeIsareti*(GrossTotal-DiscountTotal) ELSE 0 END) AS decimal(18,2)) AS [3Al2Ode Net],
    CAST(CASE WHEN SUM(CASE WHEN KTip='3Al2Ode' THEN 1 ELSE 0 END)>0
        THEN SUM(CASE WHEN KTip='3Al2Ode' THEN IadeIsareti*LineCount ELSE 0 END)*1.0/SUM(CASE WHEN KTip='3Al2Ode' THEN 1 ELSE 0 END)
        ELSE 0 END AS decimal(5,2)) AS [3Al2Ode Ort Sepet Adet],
    CAST(CASE WHEN SUM(CASE WHEN KTip='3Al2Ode' THEN 1 ELSE 0 END)>0
        THEN SUM(CASE WHEN KTip='3Al2Ode' THEN IadeIsareti*(GrossTotal-DiscountTotal) ELSE 0 END)*1.0/SUM(CASE WHEN KTip='3Al2Ode' THEN 1 ELSE 0 END)
        ELSE 0 END AS decimal(10,2)) AS [3Al2Ode Ort Sepet Tutar],
    CAST(CASE WHEN SUM(CASE WHEN KTip='3Al2Ode' THEN IadeIsareti*GrossTotal ELSE 0 END)>0
        THEN SUM(CASE WHEN KTip='3Al2Ode' THEN IadeIsareti*DiscountTotal ELSE 0 END)*100.0/SUM(CASE WHEN KTip='3Al2Ode' THEN IadeIsareti*GrossTotal ELSE 0 END)
        ELSE 0 END AS decimal(5,1)) AS [3Al2Ode Indirim Orani],
    ----- DİĞER KAMPANYA -----
    SUM(CASE WHEN KTip='Diger' THEN 1 ELSE 0 END) AS [DigerKmp Fis],
    SUM(CASE WHEN KTip='Diger' THEN IadeIsareti*LineCount ELSE 0 END) AS [DigerKmp Urun],
    CAST(SUM(CASE WHEN KTip='Diger' THEN IadeIsareti*GrossTotal ELSE 0 END) AS decimal(18,2)) AS [DigerKmp Brut],
    CAST(SUM(CASE WHEN KTip='Diger' THEN IadeIsareti*DiscountTotal ELSE 0 END) AS decimal(18,2)) AS [DigerKmp Indirim],
    CAST(SUM(CASE WHEN KTip='Diger' THEN IadeIsareti*(GrossTotal-DiscountTotal) ELSE 0 END) AS decimal(18,2)) AS [DigerKmp Net],
    CAST(CASE WHEN SUM(CASE WHEN KTip='Diger' THEN 1 ELSE 0 END)>0
        THEN SUM(CASE WHEN KTip='Diger' THEN IadeIsareti*LineCount ELSE 0 END)*1.0/SUM(CASE WHEN KTip='Diger' THEN 1 ELSE 0 END)
        ELSE 0 END AS decimal(5,2)) AS [DigerKmp Ort Sepet Adet],
    CAST(CASE WHEN SUM(CASE WHEN KTip='Diger' THEN 1 ELSE 0 END)>0
        THEN SUM(CASE WHEN KTip='Diger' THEN IadeIsareti*(GrossTotal-DiscountTotal) ELSE 0 END)*1.0/SUM(CASE WHEN KTip='Diger' THEN 1 ELSE 0 END)
        ELSE 0 END AS decimal(10,2)) AS [DigerKmp Ort Sepet Tutar],
    CAST(CASE WHEN SUM(CASE WHEN KTip='Diger' THEN IadeIsareti*GrossTotal ELSE 0 END)>0
        THEN SUM(CASE WHEN KTip='Diger' THEN IadeIsareti*DiscountTotal ELSE 0 END)*100.0/SUM(CASE WHEN KTip='Diger' THEN IadeIsareti*GrossTotal ELSE 0 END)
        ELSE 0 END AS decimal(5,1)) AS [DigerKmp Indirim Orani],
    ----- KAMPANYASIZ -----
    SUM(CASE WHEN KTip='Kampanyasiz' THEN 1 ELSE 0 END) AS [Kampanyasiz Fis],
    SUM(CASE WHEN KTip='Kampanyasiz' THEN IadeIsareti*LineCount ELSE 0 END) AS [Kampanyasiz Urun],
    CAST(SUM(CASE WHEN KTip='Kampanyasiz' THEN IadeIsareti*(GrossTotal-DiscountTotal) ELSE 0 END) AS decimal(18,2)) AS [Kampanyasiz Net],
    CAST(CASE WHEN SUM(CASE WHEN KTip='Kampanyasiz' THEN 1 ELSE 0 END)>0
        THEN SUM(CASE WHEN KTip='Kampanyasiz' THEN IadeIsareti*LineCount ELSE 0 END)*1.0/SUM(CASE WHEN KTip='Kampanyasiz' THEN 1 ELSE 0 END)
        ELSE 0 END AS decimal(5,2)) AS [Kampanyasiz Ort Sepet Adet],
    CAST(CASE WHEN SUM(CASE WHEN KTip='Kampanyasiz' THEN 1 ELSE 0 END)>0
        THEN SUM(CASE WHEN KTip='Kampanyasiz' THEN IadeIsareti*(GrossTotal-DiscountTotal) ELSE 0 END)*1.0/SUM(CASE WHEN KTip='Kampanyasiz' THEN 1 ELSE 0 END)
        ELSE 0 END AS decimal(10,2)) AS [Kampanyasiz Ort Sepet Tutar],
    ----- GENEL TOPLAM -----
    COUNT(*) AS [Toplam Fis],
    SUM(IadeIsareti*LineCount) AS [Toplam Urun],
    CAST(SUM(IadeIsareti*GrossTotal) AS decimal(18,2)) AS [Toplam Brut],
    CAST(SUM(IadeIsareti*DiscountTotal) AS decimal(18,2)) AS [Toplam Indirim],
    CAST(SUM(IadeIsareti*(GrossTotal-DiscountTotal)) AS decimal(18,2)) AS [Toplam Net],
    CAST(SUM(IadeIsareti*LineCount)*1.0/COUNT(*) AS decimal(5,2)) AS [Toplam Ort Sepet Adet],
    CAST(SUM(IadeIsareti*(GrossTotal-DiscountTotal))*1.0/COUNT(*) AS decimal(10,2)) AS [Toplam Ort Sepet Tutar],
    CAST(CASE WHEN SUM(IadeIsareti*GrossTotal)>0
        THEN SUM(IadeIsareti*DiscountTotal)*100.0/SUM(IadeIsareti*GrossTotal) ELSE 0 END AS decimal(5,1)) AS [Toplam Indirim Orani],
    ----- 3AL2ÖDE PAYLARI -----
    CAST(SUM(CASE WHEN KTip='3Al2Ode' THEN 1 ELSE 0 END)*100.0/COUNT(*) AS decimal(5,1)) AS [3Al2Ode Fis Payi %],
    CAST(SUM(CASE WHEN KTip='3Al2Ode' THEN IadeIsareti*LineCount ELSE 0 END)*100.0/SUM(IadeIsareti*LineCount) AS decimal(5,1)) AS [3Al2Ode Urun Payi %],
    CAST(SUM(CASE WHEN KTip='3Al2Ode' THEN IadeIsareti*(GrossTotal-DiscountTotal) ELSE 0 END)*100.0/SUM(IadeIsareti*(GrossTotal-DiscountTotal)) AS decimal(5,1)) AS [3Al2Ode Ciro Payi %],
    SortKey, IsTotal
FROM gun_detay
GROUP BY Tarih, Magaza, SortKey, IsTotal
)
SELECT TOP 200
    Tarih, Magaza,
    [3Al2Ode Fis], [3Al2Ode Urun], [3Al2Ode Brut], [3Al2Ode Indirim], [3Al2Ode Net],
    [3Al2Ode Ort Sepet Adet], [3Al2Ode Ort Sepet Tutar],
    [3Al2Ode Indirim Orani] AS [3Al2Ode Indirim Orani %],
    [DigerKmp Fis], [DigerKmp Urun], [DigerKmp Brut], [DigerKmp Indirim], [DigerKmp Net],
    [DigerKmp Ort Sepet Adet], [DigerKmp Ort Sepet Tutar],
    [DigerKmp Indirim Orani] AS [DigerKmp Indirim Orani %],
    [Kampanyasiz Fis], [Kampanyasiz Urun], [Kampanyasiz Net],
    [Kampanyasiz Ort Sepet Adet], [Kampanyasiz Ort Sepet Tutar],
    [Toplam Fis], [Toplam Urun], [Toplam Brut], [Toplam Indirim], [Toplam Net],
    [Toplam Ort Sepet Adet], [Toplam Ort Sepet Tutar],
    [Toplam Indirim Orani] AS [Toplam Indirim Orani %],
    [3Al2Ode Fis Payi %], [3Al2Ode Urun Payi %], [3Al2Ode Ciro Payi %]
FROM ham
ORDER BY SortKey DESC, IsTotal DESC, Magaza

-- =============================================
-- RESULT SET 2: ÖNCEKİ AYLAR
-- ay+mağaza detay → ay toplam
-- =============================================
;WITH ay_detay AS (
    SELECT RIGHT('0'+CAST(MONTH(Gun) AS varchar),2)+'.'+CAST(YEAR(Gun) AS varchar) AS Tarih, Magaza,
        CAST(CAST(YEAR(Gun) AS varchar)+'-'+RIGHT('0'+CAST(MONTH(Gun) AS varchar),2)+'-01' AS date) AS SortKey, 0 AS IsTotal,
        KTip, LineCount, GrossTotal, DiscountTotal, IadeIsareti
    FROM #fis WHERE NOT(YEAR(Gun)=YEAR(GETDATE()) AND MONTH(Gun)=MONTH(GETDATE()))
    UNION ALL
    SELECT RIGHT('0'+CAST(MONTH(Gun) AS varchar),2)+'.'+CAST(YEAR(Gun) AS varchar) AS Tarih, 'TOPLAM' AS Magaza,
        CAST(CAST(YEAR(Gun) AS varchar)+'-'+RIGHT('0'+CAST(MONTH(Gun) AS varchar),2)+'-01' AS date) AS SortKey, 1 AS IsTotal,
        KTip, LineCount, GrossTotal, DiscountTotal, IadeIsareti
    FROM #fis WHERE NOT(YEAR(Gun)=YEAR(GETDATE()) AND MONTH(Gun)=MONTH(GETDATE()))
),
ham2 AS (
SELECT
    Tarih, Magaza,
    ----- 3 AL 2 ÖDE -----
    SUM(CASE WHEN KTip='3Al2Ode' THEN 1 ELSE 0 END) AS [3Al2Ode Fis],
    SUM(CASE WHEN KTip='3Al2Ode' THEN IadeIsareti*LineCount ELSE 0 END) AS [3Al2Ode Urun],
    CAST(SUM(CASE WHEN KTip='3Al2Ode' THEN IadeIsareti*GrossTotal ELSE 0 END) AS decimal(18,2)) AS [3Al2Ode Brut],
    CAST(SUM(CASE WHEN KTip='3Al2Ode' THEN IadeIsareti*DiscountTotal ELSE 0 END) AS decimal(18,2)) AS [3Al2Ode Indirim],
    CAST(SUM(CASE WHEN KTip='3Al2Ode' THEN IadeIsareti*(GrossTotal-DiscountTotal) ELSE 0 END) AS decimal(18,2)) AS [3Al2Ode Net],
    CAST(CASE WHEN SUM(CASE WHEN KTip='3Al2Ode' THEN 1 ELSE 0 END)>0
        THEN SUM(CASE WHEN KTip='3Al2Ode' THEN IadeIsareti*LineCount ELSE 0 END)*1.0/SUM(CASE WHEN KTip='3Al2Ode' THEN 1 ELSE 0 END)
        ELSE 0 END AS decimal(5,2)) AS [3Al2Ode Ort Sepet Adet],
    CAST(CASE WHEN SUM(CASE WHEN KTip='3Al2Ode' THEN 1 ELSE 0 END)>0
        THEN SUM(CASE WHEN KTip='3Al2Ode' THEN IadeIsareti*(GrossTotal-DiscountTotal) ELSE 0 END)*1.0/SUM(CASE WHEN KTip='3Al2Ode' THEN 1 ELSE 0 END)
        ELSE 0 END AS decimal(10,2)) AS [3Al2Ode Ort Sepet Tutar],
    CAST(CASE WHEN SUM(CASE WHEN KTip='3Al2Ode' THEN IadeIsareti*GrossTotal ELSE 0 END)>0
        THEN SUM(CASE WHEN KTip='3Al2Ode' THEN IadeIsareti*DiscountTotal ELSE 0 END)*100.0/SUM(CASE WHEN KTip='3Al2Ode' THEN IadeIsareti*GrossTotal ELSE 0 END)
        ELSE 0 END AS decimal(5,1)) AS [3Al2Ode Indirim Orani],
    ----- DİĞER KAMPANYA -----
    SUM(CASE WHEN KTip='Diger' THEN 1 ELSE 0 END) AS [DigerKmp Fis],
    SUM(CASE WHEN KTip='Diger' THEN IadeIsareti*LineCount ELSE 0 END) AS [DigerKmp Urun],
    CAST(SUM(CASE WHEN KTip='Diger' THEN IadeIsareti*GrossTotal ELSE 0 END) AS decimal(18,2)) AS [DigerKmp Brut],
    CAST(SUM(CASE WHEN KTip='Diger' THEN IadeIsareti*DiscountTotal ELSE 0 END) AS decimal(18,2)) AS [DigerKmp Indirim],
    CAST(SUM(CASE WHEN KTip='Diger' THEN IadeIsareti*(GrossTotal-DiscountTotal) ELSE 0 END) AS decimal(18,2)) AS [DigerKmp Net],
    CAST(CASE WHEN SUM(CASE WHEN KTip='Diger' THEN 1 ELSE 0 END)>0
        THEN SUM(CASE WHEN KTip='Diger' THEN IadeIsareti*LineCount ELSE 0 END)*1.0/SUM(CASE WHEN KTip='Diger' THEN 1 ELSE 0 END)
        ELSE 0 END AS decimal(5,2)) AS [DigerKmp Ort Sepet Adet],
    CAST(CASE WHEN SUM(CASE WHEN KTip='Diger' THEN 1 ELSE 0 END)>0
        THEN SUM(CASE WHEN KTip='Diger' THEN IadeIsareti*(GrossTotal-DiscountTotal) ELSE 0 END)*1.0/SUM(CASE WHEN KTip='Diger' THEN 1 ELSE 0 END)
        ELSE 0 END AS decimal(10,2)) AS [DigerKmp Ort Sepet Tutar],
    CAST(CASE WHEN SUM(CASE WHEN KTip='Diger' THEN IadeIsareti*GrossTotal ELSE 0 END)>0
        THEN SUM(CASE WHEN KTip='Diger' THEN IadeIsareti*DiscountTotal ELSE 0 END)*100.0/SUM(CASE WHEN KTip='Diger' THEN IadeIsareti*GrossTotal ELSE 0 END)
        ELSE 0 END AS decimal(5,1)) AS [DigerKmp Indirim Orani],
    ----- KAMPANYASIZ -----
    SUM(CASE WHEN KTip='Kampanyasiz' THEN 1 ELSE 0 END) AS [Kampanyasiz Fis],
    SUM(CASE WHEN KTip='Kampanyasiz' THEN IadeIsareti*LineCount ELSE 0 END) AS [Kampanyasiz Urun],
    CAST(SUM(CASE WHEN KTip='Kampanyasiz' THEN IadeIsareti*(GrossTotal-DiscountTotal) ELSE 0 END) AS decimal(18,2)) AS [Kampanyasiz Net],
    CAST(CASE WHEN SUM(CASE WHEN KTip='Kampanyasiz' THEN 1 ELSE 0 END)>0
        THEN SUM(CASE WHEN KTip='Kampanyasiz' THEN IadeIsareti*LineCount ELSE 0 END)*1.0/SUM(CASE WHEN KTip='Kampanyasiz' THEN 1 ELSE 0 END)
        ELSE 0 END AS decimal(5,2)) AS [Kampanyasiz Ort Sepet Adet],
    CAST(CASE WHEN SUM(CASE WHEN KTip='Kampanyasiz' THEN 1 ELSE 0 END)>0
        THEN SUM(CASE WHEN KTip='Kampanyasiz' THEN IadeIsareti*(GrossTotal-DiscountTotal) ELSE 0 END)*1.0/SUM(CASE WHEN KTip='Kampanyasiz' THEN 1 ELSE 0 END)
        ELSE 0 END AS decimal(10,2)) AS [Kampanyasiz Ort Sepet Tutar],
    ----- GENEL TOPLAM -----
    COUNT(*) AS [Toplam Fis],
    SUM(IadeIsareti*LineCount) AS [Toplam Urun],
    CAST(SUM(IadeIsareti*GrossTotal) AS decimal(18,2)) AS [Toplam Brut],
    CAST(SUM(IadeIsareti*DiscountTotal) AS decimal(18,2)) AS [Toplam Indirim],
    CAST(SUM(IadeIsareti*(GrossTotal-DiscountTotal)) AS decimal(18,2)) AS [Toplam Net],
    CAST(SUM(IadeIsareti*LineCount)*1.0/COUNT(*) AS decimal(5,2)) AS [Toplam Ort Sepet Adet],
    CAST(SUM(IadeIsareti*(GrossTotal-DiscountTotal))*1.0/COUNT(*) AS decimal(10,2)) AS [Toplam Ort Sepet Tutar],
    CAST(CASE WHEN SUM(IadeIsareti*GrossTotal)>0
        THEN SUM(IadeIsareti*DiscountTotal)*100.0/SUM(IadeIsareti*GrossTotal) ELSE 0 END AS decimal(5,1)) AS [Toplam Indirim Orani],
    ----- 3AL2ÖDE PAYLARI -----
    CAST(SUM(CASE WHEN KTip='3Al2Ode' THEN 1 ELSE 0 END)*100.0/COUNT(*) AS decimal(5,1)) AS [3Al2Ode Fis Payi %],
    CAST(SUM(CASE WHEN KTip='3Al2Ode' THEN IadeIsareti*LineCount ELSE 0 END)*100.0/SUM(IadeIsareti*LineCount) AS decimal(5,1)) AS [3Al2Ode Urun Payi %],
    CAST(SUM(CASE WHEN KTip='3Al2Ode' THEN IadeIsareti*(GrossTotal-DiscountTotal) ELSE 0 END)*100.0/SUM(IadeIsareti*(GrossTotal-DiscountTotal)) AS decimal(5,1)) AS [3Al2Ode Ciro Payi %],
    SortKey, IsTotal
FROM ay_detay
GROUP BY Tarih, Magaza, SortKey, IsTotal
)
SELECT TOP 100
    Tarih, Magaza,
    [3Al2Ode Fis], [3Al2Ode Urun], [3Al2Ode Brut], [3Al2Ode Indirim], [3Al2Ode Net],
    [3Al2Ode Ort Sepet Adet], [3Al2Ode Ort Sepet Tutar],
    [3Al2Ode Indirim Orani] AS [3Al2Ode Indirim Orani %],
    [DigerKmp Fis], [DigerKmp Urun], [DigerKmp Brut], [DigerKmp Indirim], [DigerKmp Net],
    [DigerKmp Ort Sepet Adet], [DigerKmp Ort Sepet Tutar],
    [DigerKmp Indirim Orani] AS [DigerKmp Indirim Orani %],
    [Kampanyasiz Fis], [Kampanyasiz Urun], [Kampanyasiz Net],
    [Kampanyasiz Ort Sepet Adet], [Kampanyasiz Ort Sepet Tutar],
    [Toplam Fis], [Toplam Urun], [Toplam Brut], [Toplam Indirim], [Toplam Net],
    [Toplam Ort Sepet Adet], [Toplam Ort Sepet Tutar],
    [Toplam Indirim Orani] AS [Toplam Indirim Orani %],
    [3Al2Ode Fis Payi %], [3Al2Ode Urun Payi %], [3Al2Ode Ciro Payi %]
FROM ham2
ORDER BY SortKey DESC, IsTotal DESC, Magaza

DROP TABLE #fis
