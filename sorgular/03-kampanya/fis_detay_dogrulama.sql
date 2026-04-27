-- EncoreMerkez — Fiş Başlık + Ürün Detay Sorgusu (Doğrulama Amaçlı)
-- SSMS'te çalıştır → 2 result set döner: 1) Fiş Başlık  2) Ürün Detay
-- FisId ile eşleştirerek doğrulama yap
-- ============================================
-- ALAN AÇIKLAMALARI:
--   Sales.GrossTotal       = Brüt toplam (liste fiyat × adet)
--   Sales.DiscountTotal    = Başlık seviyesi toplam indirim
--   GrossTotal - DiscountTotal = Net satış tutarı (KDV hariç)
--   SalesProducts.TotalPrice       = Satır net tutarı (indirim düşülmüş, KDV hariç)
--   SalesProducts.DiscountTotalDirect = Satırdaki TOPLAM indirim (manuel + kampanya dahil)
--   SalesProducts.DiscountTotalCampaign = Sadece kampanya indirim kısmı (Direct'in alt kümesi)
--   SalesProducts.IsValid  = false → iptal/düzeltme satırı (Sales toplamlarına dahil DEĞİL)
--   !! RS2'de sadece IsValid=1 satırlar gösterilir — SUM(TotalPrice) = Sales Net !!
-- ============================================

-- *** PARAMETRELERİ DEĞİŞTİR ***
DECLARE @Tarih1 varchar(10) = '01.04.2026'   -- başlangıç (dahil)
DECLARE @Tarih2 varchar(10) = '02.04.2026'   -- bitiş (hariç)
DECLARE @MagazaKod varchar(10) = 'M01'       -- M01=FSM, M02=ÖZLÜCE, M03=İST.YOLU (NULL=hepsi)
-- *******************************

-- =============================================
-- RESULT SET 1: FİŞ BAŞLIK
-- KampanyaTipi: 3Al2Öde varsa → '3Al2Ode', yoksa başka kampanya varsa → 'DigerKampanya', hiç yoksa → 'Kampanyasiz'
-- =============================================
SELECT TOP 10000
    s.Id              AS FisId,
    s.DocumentNo      AS FisNo,
    CONVERT(varchar, s.Date, 104)  AS Tarih,
    st.Code           AS MagazaKod,
    st.Name           AS Magaza,
    s.DocumentsTypeId AS BelgeTipi,
    gc.GecerliUrun    AS FisUrunSayisi,
    CAST(s.GrossTotal AS decimal(18,2))                    AS FisBrut,
    CAST(s.DiscountTotal AS decimal(18,2))                 AS FisIndirim,
    CAST(s.GrossTotal - s.DiscountTotal AS decimal(18,2))  AS FisNet,
    CASE
        WHEN EXISTS (SELECT 1 FROM dbo.SalesProductCampaigns spc
                     WHERE spc.SalesId = s.Id AND spc.CampaignId IN (1, 12))
            THEN '3Al2Ode'
        WHEN EXISTS (SELECT 1 FROM dbo.SalesProductCampaigns spc
                     WHERE spc.SalesId = s.Id)
            THEN 'DigerKampanya'
        ELSE 'Kampanyasiz'
    END AS KampanyaTipi
FROM dbo.Sales s
INNER JOIN dbo.Stores st ON s.StoresId = st.Id
CROSS APPLY (
    SELECT COUNT(*) AS GecerliUrun
    FROM dbo.SalesProducts sp
    WHERE sp.SalesId = s.Id AND sp.IsValid = 1
) gc
-- Belge: 1=Fiş, 2=Fatura, 3=İade(-), 6=Personel Fiş, 7=Personel Fatura, 8=Sınav
WHERE s.DocumentsTypeId IN (1, 2, 3, 6, 7, 8)
  AND CAST(s.Date AS date) >= CONVERT(date, @Tarih1, 104)
  AND CAST(s.Date AS date) <  CONVERT(date, @Tarih2, 104)
  AND (st.Code = @MagazaKod OR @MagazaKod IS NULL)
ORDER BY s.Id

-- =============================================
-- RESULT SET 2: ÜRÜN DETAY (sadece IsValid=1, her satır = 1 geçerli ürün)
-- SatirTutar = indirim düşülmüş net (KDV hariç)
-- Indirim   = DiscountTotalDirect = toplam indirim (manuel + kampanya)
-- KampanyaIndirimi = sadece kampanya kısmı (Indirim'in alt kümesi, çift sayma!)
-- =============================================
SELECT TOP 10000
    sp.SalesId        AS FisId,
    CASE
        WHEN EXISTS (SELECT 1 FROM dbo.SalesProductCampaigns spc
                     WHERE spc.SalesId = s.Id AND spc.CampaignId IN (1, 12))
            THEN '3Al2Ode'
        WHEN EXISTS (SELECT 1 FROM dbo.SalesProductCampaigns spc
                     WHERE spc.SalesId = s.Id)
            THEN 'DigerKampanya'
        ELSE 'Kampanyasiz'
    END AS KampanyaTipi,
    sp.Sequence       AS Sira,
    p.Code            AS UrunKod,
    p.Name            AS UrunAd,
    sp.BarcodeNo      AS Barkod,
    CAST(sp.Amount AS decimal(18,4))                       AS Adet,
    CAST(sp.TotalPrice + sp.DiscountTotalDirect AS decimal(18,2))  AS ListeFiyat,
    CAST(sp.DiscountTotalDirect AS decimal(18,2))          AS Indirim,
    CAST(sp.TotalPrice AS decimal(18,2))                   AS SatirTutar,
    CAST(sp.VatTotal AS decimal(18,2))                     AS KDV,
    CAST(sp.DiscountTotalCampaign AS decimal(18,2))        AS KampanyaIndirimi,
    kmp.IndirimTipi,
    CAST(kmp.KampanyaDagitilanTutar AS decimal(18,2))      AS KampanyaDagitilanTutar
FROM dbo.Sales s
INNER JOIN dbo.Stores st ON s.StoresId = st.Id
INNER JOIN dbo.SalesProducts sp ON sp.SalesId = s.Id
INNER JOIN dbo.Products p ON sp.ProductsId = p.Id
OUTER APPLY (
    SELECT TOP 1
        c.Name AS IndirimTipi,
        (SELECT CAST(ABS(SUM(x.DistributedAmount)) AS decimal(18,2))
         FROM dbo.SalesProductCampaigns x
         WHERE x.SalesId = sp.SalesId AND x.ProductSequence = sp.Sequence
        ) AS KampanyaDagitilanTutar
    FROM dbo.SalesProductCampaigns spc
    LEFT JOIN dbo.Campaign c ON c.Id = spc.CampaignId
    WHERE spc.SalesId = sp.SalesId AND spc.ProductSequence = sp.Sequence
) kmp
-- Belge: 1=Fiş, 2=Fatura, 3=İade(-), 6=Personel Fiş, 7=Personel Fatura, 8=Sınav
WHERE s.DocumentsTypeId IN (1, 2, 3, 6, 7, 8)
  AND CAST(s.Date AS date) >= CONVERT(date, @Tarih1, 104)
  AND CAST(s.Date AS date) <  CONVERT(date, @Tarih2, 104)
  AND (st.Code = @MagazaKod OR @MagazaKod IS NULL)
  AND sp.IsValid = 1
ORDER BY sp.SalesId, sp.Sequence
