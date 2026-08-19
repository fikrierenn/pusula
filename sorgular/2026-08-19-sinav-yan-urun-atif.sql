/* =====================================================================
   2026-08-19 · Sınav cirosu vs YAN ÜRÜN (sepet büyütme) ayrımı
   Soru : Sınav sipariş paketi cirosu ne, aynı fişte sipariş DIŞI satılan
          ürünler ne kadar ek ciro yarattı?
   DB   : master bağlamı (3-parçalı) — BKM + EncoreMerkez + DerinSISBkm
   Grain: fiş satırı · Tutar: KDV HARİÇ (= TotalPrice - VatTotal), iade sign'lı

   AYRAÇ (kategori DEĞİL — sipariş kapsamı):
     SINAV PAKETİ = satırın ürünü o siparişin BKM.snv.SiparisDetay'ında VAR
     YAN ÜRÜN     = fişte var ama siparişte YOK (kasada eklenmiş)
   Gerekçe: kategori ayracı çalışmaz — 'Çocuk Kitabı' / 'Hazırlık Kitapları'
   hem siparişte hem sipariş-dışı görünüyor. SiparisDetay (DonemId=8) yalnız
   Sınav Okulları(88 ürün) + Hazırlık(66) + Çocuk Kitabı(13) + Kitap(9) içerir;
   KIYAFET ve KIRTASİYE sipariş kapsamında HİÇ YOK -> tanımı gereği yan ürün.

   ! Kıyafet ayrı kova: sipariş dışı ama zorunlu üniforma -> "isteğe bağlı
   sepet büyütme" sayılmamalı. 3 kova raporla: Paket / Kıyafet / Yan ürün.

   ! FAN-OUT: SiparisDetay LEFT JOIN yerine OUTER APPLY TOP 1 — (SiparisId,
   StokId) birden çok satır dönerse ciro N katı şişer. 18.08.2026'da fan-out
   yoktu (721 = 721 tekil) ama geniş pencerede garanti değil.

   18.08.2026 SONUÇ (KDV hariç): Paket 1.098.902,37 (%90,7) ·
   Kıyafet 35.408,92 (%2,9) · Yan ürün 77.179,28 (%6,4) · TOPLAM 1.211.490,57
   Yan ürünlü fiş 19/24 (%79) · kıyafetli 8/24 (%33) · yan ürünlü fiş başı 4.062,07
   ===================================================================== */

DECLARE @Bas datetime = CONVERT(datetime,'18.08.2026',104),
        @Bit datetime = CONVERT(datetime,'19.08.2026',104);   -- bitiş HARİÇ ( < )

-- ---------------------------------------------------------------------
-- 1) GÜN ÖZETİ — 3 kova
-- ---------------------------------------------------------------------
WITH Satir AS (
    SELECT S.Id AS FisId,
           CASE WHEN sd.StokId IS NOT NULL   THEN 'PAKET'
                WHEN U.urnKtgr2ID IN (13,18) THEN 'KIYAFET'
                ELSE 'YAN' END AS Kova,
           (SP.TotalPrice - SP.VatTotal) * IIF(S.DocumentsTypeId=3,-1,1) AS NetKdvHaric,
            SP.TotalPrice                * IIF(S.DocumentsTypeId=3,-1,1) AS NetKdvDahil,
            SP.Amount, k2.ktgrAd
    FROM BKM.snv.SinavSiparisFisEncore FE WITH(NOLOCK)
         JOIN EncoreMerkez.dbo.Sales S          WITH(NOLOCK) ON S.DocumentNo = FE.InvoiceNo
         JOIN EncoreMerkez.dbo.SalesProducts SP WITH(NOLOCK) ON SP.SalesId = S.Id AND SP.IsValid = 1
         JOIN EncoreMerkez.dbo.Products PR      WITH(NOLOCK) ON PR.Id = SP.ProductsId
         JOIN DerinSISBkm.dbo.urn U             WITH(NOLOCK) ON U.stkID = PR.Code
         LEFT JOIN DerinSISBkm.dbo.urnKtgr2 k2  WITH(NOLOCK) ON k2.ktgrID = U.urnKtgr2ID
         JOIN BKM.snv.Siparis sip               WITH(NOLOCK) ON sip.SiparisKod = FE.SiparisKod AND sip.DonemId = 8
         OUTER APPLY (SELECT TOP 1 sd2.StokId
                      FROM BKM.snv.SiparisDetay sd2 WITH(NOLOCK)
                      WHERE sd2.SiparisId = sip.SiparisId AND sd2.StokId = U.stkID) sd
    WHERE S.Date >= @Bas AND S.Date < @Bit
)
SELECT Kova, COUNT(*) AS Satir, SUM(Amount) AS Adet,
       CAST(SUM(NetKdvDahil) AS decimal(18,2)) AS NetKdvDahil,
       CAST(SUM(NetKdvHaric) AS decimal(18,2)) AS NetKdvHaric,
       CAST(SUM(NetKdvHaric) * 100.0 / SUM(SUM(NetKdvHaric)) OVER () AS decimal(9,2)) AS PayYuzde
FROM Satir
GROUP BY Kova
ORDER BY 5 DESC;

-- ---------------------------------------------------------------------
-- 2) KATEGORİ x KOVA — yan ürünün neyden geldiği
-- ---------------------------------------------------------------------
SELECT k2.ktgrAd,
       CASE WHEN sd.StokId IS NOT NULL THEN 'PAKET'
            WHEN U.urnKtgr2ID IN (13,18) THEN 'KIYAFET' ELSE 'YAN' END AS Kova,
       COUNT(*) AS Satir, SUM(SP.Amount) AS Adet,
       CAST(SUM((SP.TotalPrice - SP.VatTotal) * IIF(S.DocumentsTypeId=3,-1,1)) AS decimal(18,2)) AS NetKdvHaric
FROM BKM.snv.SinavSiparisFisEncore FE WITH(NOLOCK)
     JOIN EncoreMerkez.dbo.Sales S          WITH(NOLOCK) ON S.DocumentNo = FE.InvoiceNo
     JOIN EncoreMerkez.dbo.SalesProducts SP WITH(NOLOCK) ON SP.SalesId = S.Id AND SP.IsValid = 1
     JOIN EncoreMerkez.dbo.Products PR      WITH(NOLOCK) ON PR.Id = SP.ProductsId
     JOIN DerinSISBkm.dbo.urn U             WITH(NOLOCK) ON U.stkID = PR.Code
     LEFT JOIN DerinSISBkm.dbo.urnKtgr2 k2  WITH(NOLOCK) ON k2.ktgrID = U.urnKtgr2ID
     JOIN BKM.snv.Siparis sip               WITH(NOLOCK) ON sip.SiparisKod = FE.SiparisKod AND sip.DonemId = 8
     OUTER APPLY (SELECT TOP 1 sd2.StokId FROM BKM.snv.SiparisDetay sd2 WITH(NOLOCK)
                  WHERE sd2.SiparisId = sip.SiparisId AND sd2.StokId = U.stkID) sd
WHERE S.Date >= @Bas AND S.Date < @Bit
GROUP BY k2.ktgrAd,
         CASE WHEN sd.StokId IS NOT NULL THEN 'PAKET'
              WHEN U.urnKtgr2ID IN (13,18) THEN 'KIYAFET' ELSE 'YAN' END
ORDER BY NetKdvHaric DESC;

-- ---------------------------------------------------------------------
-- 3) FİŞ BAZLI — 3 kova + attach göstergeleri
-- ---------------------------------------------------------------------
SELECT S.Id AS FisId, S.ReceiptNo AS BelgeNo, S.ClosureNo AS Zno,
       PS.SerialNumber AS Kasa, FE.SiparisKod, sip.SiparisId, S.Date,
       CAST(SUM(CASE WHEN sd.StokId IS NOT NULL
                     THEN (SP.TotalPrice-SP.VatTotal)*IIF(S.DocumentsTypeId=3,-1,1) ELSE 0 END) AS decimal(18,2)) AS SinavPaket,
       CAST(SUM(CASE WHEN sd.StokId IS NULL AND U.urnKtgr2ID IN (13,18)
                     THEN (SP.TotalPrice-SP.VatTotal)*IIF(S.DocumentsTypeId=3,-1,1) ELSE 0 END) AS decimal(18,2)) AS Kiyafet,
       CAST(SUM(CASE WHEN sd.StokId IS NULL AND U.urnKtgr2ID NOT IN (13,18)
                     THEN (SP.TotalPrice-SP.VatTotal)*IIF(S.DocumentsTypeId=3,-1,1) ELSE 0 END) AS decimal(18,2)) AS YanUrun,
       SUM(CASE WHEN sd.StokId IS NULL AND U.urnKtgr2ID NOT IN (13,18) THEN 1 ELSE 0 END) AS YanSatir,
       CAST(SUM((SP.TotalPrice-SP.VatTotal)*IIF(S.DocumentsTypeId=3,-1,1)) AS decimal(18,2)) AS ToplamKdvHaric,
       CAST(SUM(CASE WHEN sd.StokId IS NULL
                     THEN (SP.TotalPrice-SP.VatTotal)*IIF(S.DocumentsTypeId=3,-1,1) ELSE 0 END) * 100.0
            / NULLIF(SUM((SP.TotalPrice-SP.VatTotal)*IIF(S.DocumentsTypeId=3,-1,1)),0) AS decimal(9,2)) AS SiparisDisiPayYuzde
FROM BKM.snv.SinavSiparisFisEncore FE WITH(NOLOCK)
     JOIN EncoreMerkez.dbo.Sales S          WITH(NOLOCK) ON S.DocumentNo = FE.InvoiceNo
     JOIN EncoreMerkez.dbo.Pos PS           WITH(NOLOCK) ON PS.Id = S.PosId
     JOIN EncoreMerkez.dbo.SalesProducts SP WITH(NOLOCK) ON SP.SalesId = S.Id AND SP.IsValid = 1
     JOIN EncoreMerkez.dbo.Products PR      WITH(NOLOCK) ON PR.Id = SP.ProductsId
     JOIN DerinSISBkm.dbo.urn U             WITH(NOLOCK) ON U.stkID = PR.Code
     JOIN BKM.snv.Siparis sip               WITH(NOLOCK) ON sip.SiparisKod = FE.SiparisKod AND sip.DonemId = 8
     OUTER APPLY (SELECT TOP 1 sd2.StokId FROM BKM.snv.SiparisDetay sd2 WITH(NOLOCK)
                  WHERE sd2.SiparisId = sip.SiparisId AND sd2.StokId = U.stkID) sd
WHERE S.Date >= @Bas AND S.Date < @Bit
GROUP BY S.Id, S.ReceiptNo, S.ClosureNo, PS.SerialNumber, FE.SiparisKod, sip.SiparisId, S.Date
ORDER BY YanUrun DESC;

-- ---------------------------------------------------------------------
-- 4) TEK FİŞ SATIR DETAYI — kova etiketli (kontrol için)
-- ---------------------------------------------------------------------
DECLARE @FisId bigint = 1253461;

SELECT SP.Sequence,
       CASE WHEN sd.StokId IS NOT NULL THEN 'PAKET'
            WHEN U.urnKtgr2ID IN (13,18) THEN 'KIYAFET' ELSE 'YAN' END AS Kova,
       k2.ktgrAd, SP.BarcodeNo, PR.Name AS Urun, sd.OkulTeslimat, SP.Amount, SP.VatPercent,
       SP.TotalPrice              * IIF(S.DocumentsTypeId=3,-1,1) AS NetKdvDahil,
       SP.VatTotal                * IIF(S.DocumentsTypeId=3,-1,1) AS Kdv,
      (SP.TotalPrice-SP.VatTotal) * IIF(S.DocumentsTypeId=3,-1,1) AS NetKdvHaric,
       SP.DiscountTotalDirect, SP.DiscountTotalIndirect,
       S.ReceiptNo AS BelgeNo, S.ClosureNo AS Zno, PS.SerialNumber AS Kasa, FE.SiparisKod
FROM BKM.snv.SinavSiparisFisEncore FE WITH(NOLOCK)
     JOIN EncoreMerkez.dbo.Sales S          WITH(NOLOCK) ON S.DocumentNo = FE.InvoiceNo
     JOIN EncoreMerkez.dbo.Pos PS           WITH(NOLOCK) ON PS.Id = S.PosId
     JOIN EncoreMerkez.dbo.SalesProducts SP WITH(NOLOCK) ON SP.SalesId = S.Id AND SP.IsValid = 1
     JOIN EncoreMerkez.dbo.Products PR      WITH(NOLOCK) ON PR.Id = SP.ProductsId
     JOIN DerinSISBkm.dbo.urn U             WITH(NOLOCK) ON U.stkID = PR.Code
     LEFT JOIN DerinSISBkm.dbo.urnKtgr2 k2  WITH(NOLOCK) ON k2.ktgrID = U.urnKtgr2ID
     JOIN BKM.snv.Siparis sip               WITH(NOLOCK) ON sip.SiparisKod = FE.SiparisKod AND sip.DonemId = 8
     OUTER APPLY (SELECT TOP 1 sd2.StokId, sd2.OkulTeslimat FROM BKM.snv.SiparisDetay sd2 WITH(NOLOCK)
                  WHERE sd2.SiparisId = sip.SiparisId AND sd2.StokId = U.stkID) sd
WHERE S.Id = @FisId
ORDER BY SP.Sequence;
