/* =====================================================================
   2026-08-19 · Sınav fişlerinin İADE'leri — zincir kurulabiliyor mu?
   DB : master bağlamı (3-parçalı) · Kapsam 29.07.2025 – 19.08.2026

   CEVAP: EVET, %100 kurulabiliyor — AMA doğru köprü FE değil LinkedDocumentId.

   KÖPRÜ: Sales.LinkedDocumentId -> orijinal Sales.Id  (LinkedDocumentNo da dolu)
          İade fişi 171/171'de bağlı; orijinalin tamamı DocumentsTypeId=8 (Sınav)
          ve orijinalin SiparisKod'u iade fişiyle AYNI.
          Index mevcut: IX_Sales_LinkedDocumentId_SalesType.
   ⚠ Sales.RefundReasonId header'da HER ZAMAN 0 — iade sebebi burada YOK.
     Sebep zinciri: SalesProducts.RefundReasonId / SalesProductCampaigns
     (CampaignId IS NULL iken CampaignVersion = RefundReasons.Id) — codes.yaml.

   *** ANA BULGU — FE tablosu iadelerin %43'ünü KAÇIRIYOR ***
   Sınav fişine (tip 8) bağlı toplam iade fişi: 298
     · SinavSiparisFisEncore İÇİNDE  171 fiş · 6.508.993,34 ₺ dahil / 6.449.547,12 hariç
       -> 143/171 TAM İADE (tutar orijinalin tamamı) = sipariş iptali
     · SinavSiparisFisEncore DIŞINDA 127 fiş ·   371.700,51 ₺ dahil /   360.247,61 hariç
       -> yalnız 2/127 tam; gerisi KISMİ İADE (kalem geri verme), ort. 2.926 ₺
   TOPLAM Sınav iadesi: 6.880.693,85 ₺ dahil · 6.809.794,73 ₺ hariç (cironun ~%1,6)

   YORUM: FE tablosu sipariş-seviyesi tam iade/iptali kaydediyor; kalem-bazlı
   kısmi iade FE'ye YAZILMIYOR. Kısmi iadeler perakende iade fişi olarak
   kesiliyor — bir kısmı GTY... e-fatura formatında, bir kısmı BAŞKA MAĞAZADA
   (StoresId 2/3) ve orijinal satıştan AYLAR sonra (ör. 20.08.2025 satış →
   03.11.2025 iade). Bu yüzden "Sınav iadesi" FE üstünden değil
   LinkedDocumentId üstünden sorgulanmalı.

   1:N — aynı orijinal fişe birden çok iade olabilir
   (ör. Sales.Id 85249 → iade 92725 ve 152373).

   SATIR EŞLEŞMESİ: iade satırı ↔ orijinal satır
   anahtar = LinkedDocumentId + ProductsId + TotalPrice (+ Amount).
   Sequence EŞLEŞMEZ (iade fişi kendi sıra numarasını kullanır).
   ⚠ Örnek 92725'te iade edilen 2 kalem (10231, 1662208) orijinal 85249'da
     YOK — veri kalitesi bayrağı (blok 4 bunu listeler).

   GENEL POS BAĞLAM: EncoreMerkez tüm iade fişi 33.295 · bağlı 19.682 (%59) ·
   BAĞSIZ 13.613 (2.726.203,86 ₺) → perakende genelinde iade zincirinin %41'i
   kurulamıyor. Sınav tarafında bu sorun YOK (171/171 bağlı).
   ===================================================================== */

-- ---------------------------------------------------------------------
-- 1) Sınav iadelerinin TAMAMI (doğru köprü) — fiş başlığı
-- ---------------------------------------------------------------------
SELECT I.Id                                        AS IadeFisId,
       I.Date                                      AS IadeTarih,
       I.DocumentNo                                AS IadeBelgeNo,
       I.ReceiptNo                                 AS IadeFisNo,
       I.ClosureNo                                 AS IadeZno,
       PSI.SerialNumber                            AS IadeKasa,
       I.StoresId                                  AS IadeMagaza,
       O.Id                                        AS OrijinalFisId,
       O.Date                                      AS OrijinalTarih,
       O.DocumentNo                                AS OrijinalBelgeNo,
       O.ReceiptNo                                 AS OrijinalFisNo,
       O.StoresId                                  AS OrijinalMagaza,
       FEO.SiparisKod,
       DATEDIFF(day, O.Date, I.Date)               AS GunFarki,
       CASE WHEN FEI.InvoiceNo IS NOT NULL THEN 'FE_ICINDE' ELSE 'FE_DISINDA' END AS FeDurumu,
       CAST(I.GrossTotal - I.DiscountTotal              AS decimal(18,2)) AS IadeKdvDahil,
       CAST(I.VatTotal                                  AS decimal(18,2)) AS IadeKdv,
       CAST(I.GrossTotal - I.DiscountTotal - I.VatTotal  AS decimal(18,2)) AS IadeKdvHaric,
       CAST(O.GrossTotal - O.DiscountTotal              AS decimal(18,2)) AS OrijinalKdvDahil,
       CAST((I.GrossTotal - I.DiscountTotal) * 100.0
            / NULLIF(O.GrossTotal - O.DiscountTotal,0)  AS decimal(9,2))  AS IadeOraniYuzde,
       CASE WHEN ABS((I.GrossTotal-I.DiscountTotal)-(O.GrossTotal-O.DiscountTotal)) < 0.02
            THEN 'TAM' ELSE 'KISMI' END            AS IadeTipi
FROM EncoreMerkez.dbo.Sales I WITH(NOLOCK)                       -- iade fişi
     JOIN EncoreMerkez.dbo.Sales O WITH(NOLOCK) ON O.Id = I.LinkedDocumentId
                                               AND O.DocumentsTypeId = 8   -- orijinal Sınav fişi
     LEFT JOIN EncoreMerkez.dbo.Pos PSI WITH(NOLOCK) ON PSI.Id = I.PosId
     LEFT JOIN BKM.snv.SinavSiparisFisEncore FEI WITH(NOLOCK) ON FEI.InvoiceNo = I.DocumentNo
     LEFT JOIN BKM.snv.SinavSiparisFisEncore FEO WITH(NOLOCK) ON FEO.InvoiceNo = O.DocumentNo
WHERE I.DocumentsTypeId = 3
ORDER BY I.Date DESC;

-- ---------------------------------------------------------------------
-- 2) Özet — FE içinde / dışında kırılımı
-- ---------------------------------------------------------------------
SELECT CASE WHEN FEI.InvoiceNo IS NOT NULL THEN 'FE_ICINDE' ELSE 'FE_DISINDA' END AS FeDurumu,
       COUNT(*)                                                             AS IadeFis,
       SUM(CASE WHEN ABS((I.GrossTotal-I.DiscountTotal)-(O.GrossTotal-O.DiscountTotal)) < 0.02
                THEN 1 ELSE 0 END)                                          AS TamIade,
       CAST(SUM(I.GrossTotal - I.DiscountTotal)             AS decimal(18,2)) AS IadeKdvDahil,
       CAST(SUM(I.VatTotal)                                 AS decimal(18,2)) AS IadeKdv,
       CAST(SUM(I.GrossTotal - I.DiscountTotal - I.VatTotal) AS decimal(18,2)) AS IadeKdvHaric,
       CAST(AVG(I.GrossTotal - I.DiscountTotal)             AS decimal(18,2)) AS OrtIade,
       MIN(CAST(I.Date AS date)) AS Ilk, MAX(CAST(I.Date AS date)) AS Son
FROM EncoreMerkez.dbo.Sales I WITH(NOLOCK)
     JOIN EncoreMerkez.dbo.Sales O WITH(NOLOCK) ON O.Id = I.LinkedDocumentId AND O.DocumentsTypeId = 8
     LEFT JOIN BKM.snv.SinavSiparisFisEncore FEI WITH(NOLOCK) ON FEI.InvoiceNo = I.DocumentNo
WHERE I.DocumentsTypeId = 3
GROUP BY CASE WHEN FEI.InvoiceNo IS NOT NULL THEN 'FE_ICINDE' ELSE 'FE_DISINDA' END;

-- ---------------------------------------------------------------------
-- 3) SATIR DETAYI — iade kalemi ↔ orijinal kalem eşleşmesi
--    (kova etiketi: iade edilen paket mi, yan ürün mü?)
-- ---------------------------------------------------------------------
SELECT I.Id AS IadeFisId, I.Date AS IadeTarih, O.Id AS OrijinalFisId,
       FEO.SiparisKod,
       SPI.Sequence          AS IadeSira,
       eslesme.Sequence      AS OrijinalSira,
       CASE WHEN eslesme.Sequence IS NULL THEN 'ORIJINALDE_YOK' ELSE '' END AS Uyari,
       CASE WHEN sd.StokId IS NOT NULL   THEN 'PAKET'
            WHEN U.urnKtgr2ID IN (13,18) THEN 'KIYAFET'
            ELSE 'YAN' END   AS Kova,
       k2.ktgrAd AS Kategori, PR.Code AS StkID, PR.Name AS Urun,
       SPI.Amount, SPI.VatPercent,
       -SPI.TotalPrice                    AS IadeKdvDahil,   -- iade => negatif
       -SPI.VatTotal                      AS IadeKdv,
      -(SPI.TotalPrice - SPI.VatTotal)    AS IadeKdvHaric
FROM EncoreMerkez.dbo.Sales I WITH(NOLOCK)
     JOIN EncoreMerkez.dbo.Sales O           WITH(NOLOCK) ON O.Id = I.LinkedDocumentId AND O.DocumentsTypeId = 8
     JOIN EncoreMerkez.dbo.SalesProducts SPI WITH(NOLOCK) ON SPI.SalesId = I.Id AND SPI.IsValid = 1
     JOIN EncoreMerkez.dbo.Products PR       WITH(NOLOCK) ON PR.Id = SPI.ProductsId
     LEFT JOIN DerinSISBkm.dbo.urn U         WITH(NOLOCK) ON U.stkID = PR.Code
     LEFT JOIN DerinSISBkm.dbo.urnKtgr2 k2   WITH(NOLOCK) ON k2.ktgrID = U.urnKtgr2ID
     LEFT JOIN BKM.snv.SinavSiparisFisEncore FEO WITH(NOLOCK) ON FEO.InvoiceNo = O.DocumentNo
     LEFT JOIN BKM.snv.Siparis sip           WITH(NOLOCK) ON sip.SiparisKod = FEO.SiparisKod
     OUTER APPLY (SELECT TOP 1 sd2.StokId FROM BKM.snv.SiparisDetay sd2 WITH(NOLOCK)
                  WHERE sd2.SiparisId = sip.SiparisId AND sd2.StokId = U.stkID) sd
     -- iade satırını orijinal satıra bağla: ProductsId + TotalPrice + Amount
     OUTER APPLY (SELECT TOP 1 SPO.Sequence
                  FROM EncoreMerkez.dbo.SalesProducts SPO WITH(NOLOCK)
                  WHERE SPO.SalesId    = O.Id
                    AND SPO.IsValid    = 1
                    AND SPO.ProductsId = SPI.ProductsId
                    AND SPO.TotalPrice = SPI.TotalPrice
                    AND SPO.Amount     = SPI.Amount) eslesme
WHERE I.DocumentsTypeId = 3
ORDER BY I.Date DESC, SPI.Sequence;

-- ---------------------------------------------------------------------
-- 4) VERİ KALİTESİ — iade edilmiş ama orijinal fişte bulunmayan kalemler
-- ---------------------------------------------------------------------
SELECT I.Id AS IadeFisId, I.Date, I.DocumentNo, O.Id AS OrijinalFisId,
       PR.Code AS StkID, PR.Name AS Urun, SPI.Amount, SPI.TotalPrice
FROM EncoreMerkez.dbo.Sales I WITH(NOLOCK)
     JOIN EncoreMerkez.dbo.Sales O           WITH(NOLOCK) ON O.Id = I.LinkedDocumentId AND O.DocumentsTypeId = 8
     JOIN EncoreMerkez.dbo.SalesProducts SPI WITH(NOLOCK) ON SPI.SalesId = I.Id AND SPI.IsValid = 1
     JOIN EncoreMerkez.dbo.Products PR       WITH(NOLOCK) ON PR.Id = SPI.ProductsId
WHERE I.DocumentsTypeId = 3
  AND NOT EXISTS (SELECT 1 FROM EncoreMerkez.dbo.SalesProducts SPO WITH(NOLOCK)
                  WHERE SPO.SalesId = O.Id AND SPO.IsValid = 1
                    AND SPO.ProductsId = SPI.ProductsId)
ORDER BY I.Date DESC;

-- ---------------------------------------------------------------------
-- 5) NET CİRO — satış eksi iade (dönem bazlı, KDV hariç)
--    Satış tarafı FE üstünden, iade tarafı LinkedDocumentId üstünden.
-- ---------------------------------------------------------------------
SELECT YEAR(T.Tarih) AS Yil, MONTH(T.Tarih) AS Ay,
       CAST(SUM(CASE WHEN T.Yon='SATIS' THEN T.KdvHaric ELSE 0 END) AS decimal(18,2)) AS Satis,
       CAST(SUM(CASE WHEN T.Yon='IADE'  THEN T.KdvHaric ELSE 0 END) AS decimal(18,2)) AS Iade,
       CAST(SUM(T.KdvHaric) AS decimal(18,2))                                          AS NetCiro,
       CAST(-SUM(CASE WHEN T.Yon='IADE' THEN T.KdvHaric ELSE 0 END) * 100.0
            / NULLIF(SUM(CASE WHEN T.Yon='SATIS' THEN T.KdvHaric ELSE 0 END),0) AS decimal(9,2)) AS IadeOraniYuzde
FROM (
    SELECT 'SATIS' AS Yon, S.Date AS Tarih,
           (S.GrossTotal - S.DiscountTotal - S.VatTotal) AS KdvHaric
    FROM BKM.snv.SinavSiparisFisEncore FE WITH(NOLOCK)
         JOIN EncoreMerkez.dbo.Sales S WITH(NOLOCK) ON S.DocumentNo = FE.InvoiceNo
    WHERE S.DocumentsTypeId = 8
    UNION ALL
    SELECT 'IADE' AS Yon, I.Date,
           -(I.GrossTotal - I.DiscountTotal - I.VatTotal)
    FROM EncoreMerkez.dbo.Sales I WITH(NOLOCK)
         JOIN EncoreMerkez.dbo.Sales O WITH(NOLOCK) ON O.Id = I.LinkedDocumentId AND O.DocumentsTypeId = 8
    WHERE I.DocumentsTypeId = 3
) T
GROUP BY YEAR(T.Tarih), MONTH(T.Tarih)
ORDER BY Yil, Ay;
