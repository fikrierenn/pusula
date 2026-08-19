/* =====================================================================
   2026-08-19 · Sınav siparişi ödeme durumu — KISMİ ÖDEME DAHİL DOĞRU MODEL
   DB : master bağlamı (3-parçalı) · Kapsam DonemId 7-8 (Encore dönemi)

   ⚠ BU DOSYA, 2026-08-19-sinav-odeme-durumu-pingpong.sql'deki
     "Net > 0 -> ÖDENDİ" kuralını GEÇERSİZ KILAR. O kural kısmi ödemeyi
     tam sanıyordu. Ping-pong/olay defteri blokları hâlâ geçerli.

   *** ÖDEME İKİ EKSENLİ — TEK BOYUTA İNDİRİLEMEZ ***

   EKSEN 1 · KALEM KAPSAMI  (kaynak: snv.SiparisDetay.OdemesiYapildi)
     Sipariş kalem kalem ödeniyor. Veli 28 kalemin 26'sını alıp 2'sini
     almazsa sipariş KISMİ kalır.
       OdenmisKalem = 0                       -> HIC_ODENMEDI
       OdenmemisKalem = 0                     -> TAM_ODENDI
       ikisi de > 0                           -> KISMI_ODENDI
     (Iptal=1 kalemler paydadan düşer.)

   EKSEN 2 · TUTAR/HAREKET  (kaynak: Sales satış-iade net)
     Net = Σ satış − Σ iade (KDV hariç, iade sign'lı).
     Ping-pong burada görünür; kalem kapsamını ETKİLEMEZ.

   *** CANLI ÖLÇÜM (DonemId 7-8, 9.080 sipariş) ***
   | Kalem durumu   | İade | Sipariş | Ödenmemiş kalem | Flag=1 (yanlış) |
   |----------------|------|---------|-----------------|-----------------|
   | TAM_ODENDI     | yok  |  7.110  |        0        |   7.110  DOĞRU  |
   | TAM_ODENDI     | var  |    114  |        0        |     114  DOĞRU  |
   | KISMI_ODENDI   | yok  |  1.745  |    6.233        |   1.742  YANLIŞ |
   | KISMI_ODENDI   | var  |     46  |      242        |      44  YANLIŞ |
   | HIC_ODENMEDI   | yok  |     57  |      700        |       1  YANLIŞ |
   | HIC_ODENMEDI   | var  |      8  |       74        |       0  DOĞRU  |

   -> snv.Siparis.Odendi bit'i KISMİYİ TAM SANIYOR:
      **1.787 sipariş (6.475 kalem) hatalı "ödendi"** görünüyor (%20 sipariş).
   -> Kısmilik İADEDEN GELMİYOR: 1.745/1.791 kısmi siparişte hiç iade yok.
      Sebep kalemin hiç kasadan geçmemesi (KasaAdet=0, FisId NULL).

   *** TUTAR KISITI (ÖNEMLİ) ***
   snv.SiparisDetay.BirimFiyat PRATİKTE NULL — dönem 7-8'de 112.499 ödenmiş
   kalemin toplam "beklenen tutarı" yalnız 599 ₺ çıkıyor. Yani ÖDENMEMİŞ
   KALEMİN TL KARŞILIĞI BU TABLODAN HESAPLANAMAZ; yalnız KALEM SAYISI verilir.
   Ödenen tutar ise kalem-fiş köprüsünden gelir:
     SiparisDetay.FisId       = EncoreMerkez.Sales.DocumentNo
     SiparisDetay.FisIdSiraNo = EncoreMerkez.SalesProducts.Sequence
   Eksik tutar isteniyorsa güncel fiyat listesinden TAHMİN edilir (ayrı iş).

   *** SENKRON KOPUKLUĞU (veri kalitesi) ***
   Örn. 3812025233328: fişte 40.828,10 ₺ net geçmiş ama SiparisDetay'da
   yalnız 1 kalem OdemesiYapildi=1 ve HİÇBİR kalemde FisId yok (TekilFis=0).
   Ping-pong sonrası SiparisDetay çoğunlukla SON geçerli fişe repoint ediliyor
   (3812025195916 -> 17561337840006) ama her vakada olmuyor. Blok 4 bunu listeler.
   ===================================================================== */

DECLARE @Donem1 int = 7, @Donem2 int = 8;

-- ---------------------------------------------------------------------
-- 1) SİPARİŞ DURUM ÖZETİ — iki eksen birlikte (KANONİK)
-- ---------------------------------------------------------------------
SELECT sip.SiparisKod, sip.SiparisId, sip.DonemId, sip.Tarih AS SiparisTarih,
       CONVERT(int, ISNULL(sip.Odendi,0))                       AS OdendiFlag,
       -- EKSEN 1: kalem kapsamı
       K.Kalem, K.IptalKalem, K.OdenmisKalem, K.OdenmemisKalem,
       CAST(K.OdenmisKalem * 100.0 / NULLIF(K.Kalem - K.IptalKalem,0) AS decimal(9,2)) AS OdemeYuzde,
       CASE WHEN K.OdenmisKalem = 0                THEN 'HIC_ODENMEDI'
            WHEN K.OdenmemisKalem = 0              THEN 'TAM_ODENDI'
            ELSE                                        'KISMI_ODENDI' END AS KalemDurum,
       -- EKSEN 2: tutar / hareket
       ISNULL(X.SatisFis,0) AS SatisFis, ISNULL(X.IadeFis,0) AS IadeFis,
       X.IlkHareket, X.SonHareket,
       CAST(ISNULL(X.NetKdvHaric,0) AS decimal(18,2)) AS NetKdvHaric,
       CAST(ISNULL(X.BrutSatis,0)   AS decimal(18,2)) AS BrutSatis,
       CASE WHEN X.IadeFis >= 2 THEN 'PING_PONG'
            WHEN X.IadeFis  = 1 THEN 'TEK_IADE' ELSE '' END AS IadeDeseni,
       -- FLAG DENETİMİ
       CASE WHEN CONVERT(int,ISNULL(sip.Odendi,0)) = 1 AND K.OdenmemisKalem > 0
                 THEN 'FLAG_YANLIS_ODENDI'
            WHEN CONVERT(int,ISNULL(sip.Odendi,0)) = 0 AND K.OdenmemisKalem = 0 AND K.OdenmisKalem > 0
                 THEN 'FLAG_YANLIS_ODENMEDI'
            ELSE 'FLAG_TUTARLI' END AS FlagDenetim
FROM BKM.snv.Siparis sip WITH(NOLOCK)
     CROSS APPLY (
        SELECT COUNT(*)                                                                AS Kalem,
               SUM(CASE WHEN ISNULL(sd.Iptal,0) = 1 THEN 1 ELSE 0 END)                 AS IptalKalem,
               SUM(CASE WHEN ISNULL(sd.OdemesiYapildi,0) = 1 THEN 1 ELSE 0 END)        AS OdenmisKalem,
               SUM(CASE WHEN ISNULL(sd.OdemesiYapildi,0) = 0
                         AND ISNULL(sd.Iptal,0) = 0 THEN 1 ELSE 0 END)                 AS OdenmemisKalem
        FROM BKM.snv.SiparisDetay sd WITH(NOLOCK)
        WHERE sd.SiparisId = sip.SiparisId) K
     OUTER APPLY (
        SELECT SUM(CASE WHEN S.DocumentsTypeId = 3 THEN 1 ELSE 0 END)  AS IadeFis,
               SUM(CASE WHEN S.DocumentsTypeId <> 3 THEN 1 ELSE 0 END) AS SatisFis,
               SUM(CASE WHEN S.DocumentsTypeId <> 3
                        THEN S.GrossTotal-S.DiscountTotal-S.VatTotal ELSE 0 END)       AS BrutSatis,
               SUM(CASE WHEN S.DocumentsTypeId = 3
                        THEN -(S.GrossTotal-S.DiscountTotal-S.VatTotal)
                        ELSE  (S.GrossTotal-S.DiscountTotal-S.VatTotal) END)           AS NetKdvHaric,
               MIN(S.Date) AS IlkHareket, MAX(S.Date) AS SonHareket
        FROM BKM.snv.SinavSiparisFisEncore FE WITH(NOLOCK)
             JOIN EncoreMerkez.dbo.Sales S WITH(NOLOCK) ON S.DocumentNo = FE.InvoiceNo
        WHERE FE.SiparisKod = sip.SiparisKod) X
WHERE sip.DonemId IN (@Donem1, @Donem2) AND K.Kalem > 0
ORDER BY sip.SiparisKod;

-- ---------------------------------------------------------------------
-- 2) 3x2 MATRİS — kalem durumu × iade durumu (yukarıdaki tabloyu üretir)
-- ---------------------------------------------------------------------
SELECT T.KalemDurum,
       CASE WHEN T.IadeFis > 0 THEN 'IADE_VAR' ELSE 'IADE_YOK' END AS IadeDurum,
       COUNT(*)                                       AS Siparis,
       SUM(T.Kalem)                                   AS Kalem,
       SUM(T.OdenmemisKalem)                          AS OdenmemisKalem,
       SUM(CASE WHEN T.OdendiFlag = 1 THEN 1 ELSE 0 END) AS FlagOdendi,
       CAST(SUM(ISNULL(T.NetKdvHaric,0)) AS decimal(18,2)) AS NetKdvHaric
FROM (
    SELECT sip.SiparisId, CONVERT(int,ISNULL(sip.Odendi,0)) AS OdendiFlag,
           K.Kalem, K.OdenmisKalem, K.OdenmemisKalem,
           CASE WHEN K.OdenmisKalem = 0   THEN 'HIC_ODENMEDI'
                WHEN K.OdenmemisKalem = 0 THEN 'TAM_ODENDI'
                ELSE                           'KISMI_ODENDI' END AS KalemDurum,
           ISNULL(X.IadeFis,0) AS IadeFis, X.NetKdvHaric
    FROM BKM.snv.Siparis sip WITH(NOLOCK)
         CROSS APPLY (SELECT COUNT(*) AS Kalem,
                             SUM(CASE WHEN ISNULL(sd.OdemesiYapildi,0)=1 THEN 1 ELSE 0 END) AS OdenmisKalem,
                             SUM(CASE WHEN ISNULL(sd.OdemesiYapildi,0)=0
                                       AND ISNULL(sd.Iptal,0)=0 THEN 1 ELSE 0 END)          AS OdenmemisKalem
                      FROM BKM.snv.SiparisDetay sd WITH(NOLOCK)
                      WHERE sd.SiparisId = sip.SiparisId) K
         OUTER APPLY (SELECT SUM(CASE WHEN S.DocumentsTypeId=3 THEN 1 ELSE 0 END) AS IadeFis,
                             SUM(CASE WHEN S.DocumentsTypeId=3
                                      THEN -(S.GrossTotal-S.DiscountTotal-S.VatTotal)
                                      ELSE  (S.GrossTotal-S.DiscountTotal-S.VatTotal) END) AS NetKdvHaric
                      FROM BKM.snv.SinavSiparisFisEncore FE WITH(NOLOCK)
                           JOIN EncoreMerkez.dbo.Sales S WITH(NOLOCK) ON S.DocumentNo = FE.InvoiceNo
                      WHERE FE.SiparisKod = sip.SiparisKod) X
    WHERE sip.DonemId IN (@Donem1, @Donem2) AND K.Kalem > 0
) T
GROUP BY T.KalemDurum, CASE WHEN T.IadeFis > 0 THEN 'IADE_VAR' ELSE 'IADE_YOK' END
ORDER BY T.KalemDurum, IadeDurum;

-- ---------------------------------------------------------------------
-- 3) EKSİK KALEM LİSTESİ — hangi siparişin hangi ürünü ödenmedi
--    (operasyona "tahsil edilecek" listesi)
-- ---------------------------------------------------------------------
SELECT sip.SiparisKod, sip.SiparisId, sip.DonemId,
       CONVERT(int, ISNULL(sip.Odendi,0)) AS OdendiFlag,
       sd.SiparisDetayId, sd.StokId, U.stkAd AS Urun, k2.ktgrAd AS Kategori,
       sd.Adet, sd.KasaAdet,
       CONVERT(int, ISNULL(sd.Alindi,0))       AS Alindi,
       CONVERT(int, ISNULL(sd.Hazirlandi,0))   AS Hazirlandi,
       CONVERT(int, ISNULL(sd.OkulTeslimat,0)) AS OkulTeslimat,
       sd.FisId, sd.FisIdSiraNo
FROM BKM.snv.Siparis sip WITH(NOLOCK)
     JOIN BKM.snv.SiparisDetay sd WITH(NOLOCK) ON sd.SiparisId = sip.SiparisId
     LEFT JOIN DerinSISBkm.dbo.urn U        WITH(NOLOCK) ON U.stkID = sd.StokId
     LEFT JOIN DerinSISBkm.dbo.urnKtgr2 k2  WITH(NOLOCK) ON k2.ktgrID = U.urnKtgr2ID
WHERE sip.DonemId IN (@Donem1, @Donem2)
  AND ISNULL(sd.OdemesiYapildi,0) = 0
  AND ISNULL(sd.Iptal,0) = 0
ORDER BY sip.SiparisKod, sd.StokId;

-- ---------------------------------------------------------------------
-- 4) SENKRON KOPUKLUĞU — fişte para geçmiş ama kalem eşleşmesi yok
--    (ödenmiş kalem var ama FisId yazılmamış, ya da net > 0 iken kalem 0)
-- ---------------------------------------------------------------------
SELECT sip.SiparisKod, sip.SiparisId, CONVERT(int,ISNULL(sip.Odendi,0)) AS OdendiFlag,
       K.OdenmisKalem, K.OdenmemisKalem, K.FisIdYazili, K.TekilFis,
       ISNULL(X.SatisFis,0) AS SatisFis, ISNULL(X.IadeFis,0) AS IadeFis,
       CAST(ISNULL(X.NetKdvHaric,0) AS decimal(18,2)) AS NetKdvHaric,
       CASE WHEN K.OdenmisKalem > 0 AND K.FisIdYazili = 0 THEN 'ODENMIS_AMA_FISID_YOK'
            WHEN X.NetKdvHaric > 0.02 AND K.OdenmisKalem = 0 THEN 'PARA_VAR_KALEM_ODENMEMIS'
            WHEN X.NetKdvHaric <= 0.02 AND K.OdenmisKalem > 0 THEN 'KALEM_ODENMIS_PARA_YOK'
            ELSE '' END AS Bulgu
FROM BKM.snv.Siparis sip WITH(NOLOCK)
     CROSS APPLY (SELECT SUM(CASE WHEN ISNULL(sd.OdemesiYapildi,0)=1 THEN 1 ELSE 0 END) AS OdenmisKalem,
                         SUM(CASE WHEN ISNULL(sd.OdemesiYapildi,0)=0
                                   AND ISNULL(sd.Iptal,0)=0 THEN 1 ELSE 0 END)          AS OdenmemisKalem,
                         SUM(CASE WHEN sd.FisId IS NOT NULL AND sd.FisId <> '' THEN 1 ELSE 0 END) AS FisIdYazili,
                         COUNT(DISTINCT sd.FisId) AS TekilFis
                  FROM BKM.snv.SiparisDetay sd WITH(NOLOCK)
                  WHERE sd.SiparisId = sip.SiparisId) K
     OUTER APPLY (SELECT SUM(CASE WHEN S.DocumentsTypeId<>3 THEN 1 ELSE 0 END) AS SatisFis,
                         SUM(CASE WHEN S.DocumentsTypeId=3 THEN 1 ELSE 0 END)  AS IadeFis,
                         SUM(CASE WHEN S.DocumentsTypeId=3
                                  THEN -(S.GrossTotal-S.DiscountTotal-S.VatTotal)
                                  ELSE  (S.GrossTotal-S.DiscountTotal-S.VatTotal) END) AS NetKdvHaric
                  FROM BKM.snv.SinavSiparisFisEncore FE WITH(NOLOCK)
                       JOIN EncoreMerkez.dbo.Sales S WITH(NOLOCK) ON S.DocumentNo = FE.InvoiceNo
                  WHERE FE.SiparisKod = sip.SiparisKod) X
WHERE sip.DonemId IN (@Donem1, @Donem2)
  AND ( (K.OdenmisKalem > 0 AND K.FisIdYazili = 0)
     OR (X.NetKdvHaric > 0.02 AND K.OdenmisKalem = 0)
     OR (ISNULL(X.NetKdvHaric,0) <= 0.02 AND K.OdenmisKalem > 0) )
ORDER BY ABS(ISNULL(X.NetKdvHaric,0)) DESC;

-- ---------------------------------------------------------------------
-- 5) ÖDENEN KALEMİN TUTARI — kalem-fiş köprüsü
--    SiparisDetay.FisId = Sales.DocumentNo · FisIdSiraNo = SalesProducts.Sequence
--    Ödenmemiş kalemde FisId NULL olduğu için tutar YOK (BirimFiyat da NULL).
-- ---------------------------------------------------------------------
SELECT sip.SiparisKod, sd.SiparisDetayId, sd.StokId, U.stkAd AS Urun,
       sd.Adet, sd.KasaAdet, sd.FisId, sd.FisIdSiraNo,
       S.Id AS FisId_Sales, S.Date AS FisTarih, DT.Name AS BelgeTip,
       SP.VatPercent,
       CAST(SP.TotalPrice                 AS decimal(18,2)) AS OdenenKdvDahil,
       CAST(SP.TotalPrice - SP.VatTotal    AS decimal(18,2)) AS OdenenKdvHaric
FROM BKM.snv.Siparis sip WITH(NOLOCK)
     JOIN BKM.snv.SiparisDetay sd WITH(NOLOCK) ON sd.SiparisId = sip.SiparisId
     LEFT JOIN DerinSISBkm.dbo.urn U WITH(NOLOCK) ON U.stkID = sd.StokId
     LEFT JOIN EncoreMerkez.dbo.Sales S WITH(NOLOCK)
            ON S.DocumentNo = sd.FisId COLLATE Turkish_CI_AS
     LEFT JOIN EncoreMerkez.dbo.Documents DT WITH(NOLOCK) ON DT.Id = S.DocumentsTypeId
     LEFT JOIN EncoreMerkez.dbo.SalesProducts SP WITH(NOLOCK)
            ON SP.SalesId = S.Id AND SP.Sequence = sd.FisIdSiraNo AND SP.IsValid = 1
WHERE sip.DonemId IN (@Donem1, @Donem2)
  AND ISNULL(sd.OdemesiYapildi,0) = 1
  AND sd.FisId IS NOT NULL AND sd.FisId <> ''
ORDER BY sip.SiparisKod, sd.FisIdSiraNo;
