/* =====================================================================
   SINAV FİŞ DETAY — DÜZELTİLMİŞ SÜRÜM              (2026-08-19)
   Kaynak sorgu: kullanıcının SinavSiparisFisEncore detay sorgusu
   DB bağlamı  : master (3-parçalı isim zorunlu) · SSMS

   YAPILAN 9 DÜZELTME (gerekçe + ölçülen etki)
   1. TotalPrice KDV DAHİL -> ayrı KDV-hariç kolonu (NetKdvHaric).
      18.08.2026: 1.233.850,51 dahil / 1.211.490,57 hariç (fark 22.359,94).
   2. Tarih penceresi: between '...23:59' 59 saniye kaybediyor + literal
      session DATEFORMAT'a bağlı -> >= CONVERT(...,104) AND < ertesi gün.
   3. DonemId=8 INNER JOIN GEÇMİŞİ SİLİYOR: canlı dağılım DonemId 8 -> 321 fiş
      (22.07.2026+), 7 -> 8.994 fiş (06.08.2025-19.04.2026), -7 -> 4 fiş.
      -> @DonemId parametresi (NULL = tüm dönemler) + LEFT JOIN + eşleşme bayrağı.
   4. urn INNER JOIN 3.463 satır / 1.307.121,75 ₺ düşürüyordu (Products.Code
      karşılığı urn'de yok) -> LEFT JOIN + ErpUrunYok bayrağı.
   5. urnKtgr2 INNER JOIN + kategori filtresi -> LEFT JOIN (kategorisiz satır düşmesin).
   6. urnKtgr2ID NOT IN (13,18) kıyafeti SESSİZCE düşürüyordu (18.08: 32 satır /
      38.949,83 ₺) -> filtre KALDIRILDI, Kova kolonu ile ayrıştırılıyor.
   7. SiparisDetay LEFT JOIN fan-out riski (SiparisId+StokId birden çok satır)
      -> OUTER APPLY TOP 1.
   8. İndirim: DiscountTotalDirect tek başına eksik (18.08: 5.981,79 / gerçek
      39.212,79) -> Direct + Indirect birlikte + ListeTutar kolonu.
   9. İade sign'ı TÜM tutar kolonlarına uygulandı (yalnız NetTutar'a değil).

   KOVA TANIMI (kategori DEĞİL, sipariş kapsamı):
     PAKET   = ürün o siparişin SiparisDetay'ında VAR (okulun ısmarladığı set)
     KIYAFET = siparişte yok + urnKtgr2ID IN (13,18) (zorunlu üniforma)
     YAN     = siparişte yok + kıyafet değil (kasada eklenen ek satış)
   Gerekçe: SiparisDetay yalnız Sınav Okulları/Hazırlık/Çocuk Kitabı/Kitap
   içerir; kıyafet ve kırtasiye sipariş kapsamında hiç yok.

   18.08.2026 DOĞRULAMA (bu sorgu):
     721 satır · KDV dahil 1.233.850,51 · KDV 22.359,94 · KDV hariç 1.211.490,57
     = Sales header (GrossTotal - DiscountTotal) ile BİREBİR.
   ===================================================================== */

DECLARE @Bas      datetime = CONVERT(datetime,'18.08.2026',104),
        @Bit      datetime = CONVERT(datetime,'19.08.2026',104),  -- bitiş HARİÇ ( < )
        @DonemId  int      = NULL;   -- NULL = tüm dönemler · 8 / 7 / -7 ile daralt

SELECT S.Id,
       SP.SalesId,
       sip.SiparisId,
       CASE WHEN sip.SiparisId IS NULL THEN 'SIPARIS_ESLESMEDI' ELSE '' END AS SiparisUyari,
       sip.DonemId,
       S.PosDocumentId,
       S.Date,
       S.DocumentsTypeId,
       DT.Name                                            AS BelgeTip,
       PS.SerialNumber                                    AS Kasa,
       S.ClosureNo                                        AS Zno,
       S.ReceiptNo                                        AS BelgeNo,
       FE.SiparisKod,
       SP.Sequence,

       -- kova (sipariş kapsamı bazlı)
       CASE WHEN sd.StokId IS NOT NULL              THEN 'PAKET'
            WHEN U.urnKtgr2ID IN (13,18)            THEN 'KIYAFET'
            ELSE 'YAN' END                                AS Kova,

       k2.ktgrAd                                          AS Kategori,
       CASE WHEN U.stkID IS NULL THEN 'ERP_URUN_YOK' ELSE '' END AS UrunUyari,
       PR.Code                                            AS StkID,
       SP.BarcodeNo,
       PR.Name                                            AS Urun,
       sd.OkulTeslimat,
       SP.Amount,
       SP.VatPercent,

       -- TUTARLAR (iade sign'lı)
       (SP.TotalPrice + SP.DiscountTotalDirect + SP.DiscountTotalIndirect)
                                    * IIF(S.DocumentsTypeId = 3, -1, 1) AS ListeTutar,
       (SP.DiscountTotalDirect + SP.DiscountTotalIndirect)
                                    * IIF(S.DocumentsTypeId = 3, -1, 1) AS IndirimToplam,
        SP.TotalPrice               * IIF(S.DocumentsTypeId = 3, -1, 1) AS NetKdvDahil,
        SP.VatTotal                 * IIF(S.DocumentsTypeId = 3, -1, 1) AS Kdv,
       (SP.TotalPrice - SP.VatTotal)* IIF(S.DocumentsTypeId = 3, -1, 1) AS NetKdvHaric,

       -- indirim ayrıntısı (denetim için)
       SP.DiscountTotalDirect,
       SP.DiscountTotalIndirect

FROM BKM.snv.SinavSiparisFisEncore FE WITH(NOLOCK)
     JOIN EncoreMerkez.dbo.Sales S          WITH(NOLOCK) ON S.DocumentNo = FE.InvoiceNo
     JOIN EncoreMerkez.dbo.Pos PS           WITH(NOLOCK) ON PS.Id = S.PosId
     JOIN EncoreMerkez.dbo.Documents DT     WITH(NOLOCK) ON DT.Id = S.DocumentsTypeId
     JOIN EncoreMerkez.dbo.SalesProducts SP WITH(NOLOCK) ON SP.SalesId = S.Id AND SP.IsValid = 1
     JOIN EncoreMerkez.dbo.Products PR      WITH(NOLOCK) ON PR.Id = SP.ProductsId
     -- LEFT: urn'de karşılığı olmayan ürün satırı ciroyu düşürmesin (3.463 satır / 1,3M ₺)
     LEFT JOIN DerinSISBkm.dbo.urn U        WITH(NOLOCK) ON U.stkID = PR.Code
     LEFT JOIN DerinSISBkm.dbo.urnKtgr2 k2  WITH(NOLOCK) ON k2.ktgrID = U.urnKtgr2ID
     -- LEFT + parametre: DonemId hardcode'u geçmişi siliyordu
     LEFT JOIN BKM.snv.Siparis sip          WITH(NOLOCK) ON sip.SiparisKod = FE.SiparisKod
                                            AND (@DonemId IS NULL OR sip.DonemId = @DonemId)
     -- OUTER APPLY TOP 1: (SiparisId, StokId) çoklu satır dönerse ciro N katı şişmesin
     OUTER APPLY (SELECT TOP 1 sd2.StokId, sd2.OkulTeslimat
                  FROM BKM.snv.SiparisDetay sd2 WITH(NOLOCK)
                  WHERE sd2.SiparisId = sip.SiparisId AND sd2.StokId = U.stkID) sd

WHERE S.Date >= @Bas AND S.Date < @Bit
ORDER BY S.Id, SP.Sequence;


/* ---------------------------------------------------------------------
   KONTROL 1 — kova özeti (fiş header ile mutabakat)
   --------------------------------------------------------------------- */
SELECT CASE WHEN sd.StokId IS NOT NULL THEN 'PAKET'
            WHEN U.urnKtgr2ID IN (13,18) THEN 'KIYAFET' ELSE 'YAN' END AS Kova,
       COUNT(*) AS Satir,
       CAST(SUM(SP.TotalPrice                * IIF(S.DocumentsTypeId=3,-1,1)) AS decimal(18,2)) AS NetKdvDahil,
       CAST(SUM(SP.VatTotal                  * IIF(S.DocumentsTypeId=3,-1,1)) AS decimal(18,2)) AS Kdv,
       CAST(SUM((SP.TotalPrice-SP.VatTotal)  * IIF(S.DocumentsTypeId=3,-1,1)) AS decimal(18,2)) AS NetKdvHaric
FROM BKM.snv.SinavSiparisFisEncore FE WITH(NOLOCK)
     JOIN EncoreMerkez.dbo.Sales S          WITH(NOLOCK) ON S.DocumentNo = FE.InvoiceNo
     JOIN EncoreMerkez.dbo.SalesProducts SP WITH(NOLOCK) ON SP.SalesId = S.Id AND SP.IsValid = 1
     JOIN EncoreMerkez.dbo.Products PR      WITH(NOLOCK) ON PR.Id = SP.ProductsId
     LEFT JOIN DerinSISBkm.dbo.urn U        WITH(NOLOCK) ON U.stkID = PR.Code
     LEFT JOIN BKM.snv.Siparis sip          WITH(NOLOCK) ON sip.SiparisKod = FE.SiparisKod
                                            AND (@DonemId IS NULL OR sip.DonemId = @DonemId)
     OUTER APPLY (SELECT TOP 1 sd2.StokId FROM BKM.snv.SiparisDetay sd2 WITH(NOLOCK)
                  WHERE sd2.SiparisId = sip.SiparisId AND sd2.StokId = U.stkID) sd
WHERE S.Date >= @Bas AND S.Date < @Bit
GROUP BY CASE WHEN sd.StokId IS NOT NULL THEN 'PAKET'
              WHEN U.urnKtgr2ID IN (13,18) THEN 'KIYAFET' ELSE 'YAN' END;

/* ---------------------------------------------------------------------
   KONTROL 2 — header referansı (yukarıdaki toplamla eşleşmeli)
   --------------------------------------------------------------------- */
SELECT COUNT(*) AS Fis,
       CAST(SUM(S.GrossTotal)                                AS decimal(18,2)) AS Brut,
       CAST(SUM(S.DiscountTotal)                             AS decimal(18,2)) AS Indirim,
       CAST(SUM(S.GrossTotal - S.DiscountTotal)              AS decimal(18,2)) AS NetKdvDahil,
       CAST(SUM(S.VatTotal)                                  AS decimal(18,2)) AS Kdv,
       CAST(SUM(S.GrossTotal - S.DiscountTotal - S.VatTotal) AS decimal(18,2)) AS NetKdvHaric
FROM BKM.snv.SinavSiparisFisEncore FE WITH(NOLOCK)
     JOIN EncoreMerkez.dbo.Sales S WITH(NOLOCK) ON S.DocumentNo = FE.InvoiceNo
WHERE S.Date >= @Bas AND S.Date < @Bit;
