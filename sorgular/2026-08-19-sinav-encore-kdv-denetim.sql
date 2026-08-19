/* =====================================================================
   2026-08-19 · Sınav Okulları POS fişi KDV / ciro denetimi
   Soru : SinavSiparisFisEncore → Sales/SalesProducts sorgusunda
          "NetTutar = SP.TotalPrice" KDV'li mi KDV'siz mi? Mantıksızlık nerede?
   DB   : master bağlamı (3-parçalı isim) — BKM + EncoreMerkez + DerinSISBkm
   Gün  : 18.08.2026 (24 fiş / 721 geçerli satır)

   BULGULAR
   1) SalesProducts.TotalPrice = KDV DAHİL ve İNDİRİM SONRASI (net tahsil).
      VatTotal, TotalPrice'ın İÇİNDEDİR:  2500 @ %20 → VatTotal 416,66 (= 2500-2500/1,2)
      KDV-hariç satır tutarı = TotalPrice - VatTotal
   2) Fiş mutabakatı BİREBİR tuttu (24/24):
      GrossTotal - SUM(TotalPrice) = DiscountTotal   ve   Sales.VatTotal = SUM(SP.VatTotal)
      Brüt 1.273.063,30 · İnd 39.212,79 · Net(KDV dahil) 1.233.850,51
      KDV 22.359,94 · Net(KDV hariç) 1.211.490,57
   3) İNDİRİM: header DiscountTotal = Direct(5.981,79) + Indirect(33.231,00).
      Yalnız DiscountTotalDirect kullanılırsa indirim %85 eksik ölçülür.
      Campaign(5.981,79) = Direct'in tamamı (bu günde).
   4) KDV oranı POS↔ERP UYUMLU. urn.KDVs bir KOD'dur, yüzde değildir:
      1→%0 · 2→%1 · 6→%10 · 7→%20 (721/721 satır tutarlı, sapma YOK).
      Blended KDV %1,81 görünmesi hata değil: cironun %87'si %0 KDV'li
      süreli yayın/kitap (Sınav Okulları 1.021.517 + Hazırlık 37.081 + Çocuk 13.752).
   5) urnKtgr2ID NOT IN (13,18) = Kıyafet + Sınav Kıyafet → 32 satır /
      38.949,83 ₺ (günün %3,2'si, %10 KDV'li blok) rapordan SESSİZCE düşüyor.
   ===================================================================== */

-- 1) Satır seviyesi KDV yapısı (TotalPrice KDV dahil mi?)
SELECT TOP 40 S.Id, S.DocumentsTypeId, SP.Sequence, SP.VatPercent, SP.Amount,
       SP.TotalPrice, SP.VatTotal,
       ROUND(SP.TotalPrice - SP.VatTotal, 2)                                AS KdvHaric,
       ROUND(SP.VatTotal * 100.0 / NULLIF(SP.TotalPrice - SP.VatTotal,0),2) AS ImaEdilenOran
FROM BKM.snv.SinavSiparisFisEncore FE
     JOIN EncoreMerkez.dbo.Sales S          ON S.DocumentNo = FE.InvoiceNo
     JOIN EncoreMerkez.dbo.SalesProducts SP ON SP.SalesId = S.Id AND SP.IsValid = 1
WHERE S.Date >= CONVERT(datetime,'18.08.2026',104)
  AND S.Date <  CONVERT(datetime,'19.08.2026',104)
ORDER BY S.Id, SP.Sequence;

-- 2) Fiş bazlı header ↔ satır mutabakatı (fark 0 beklenir)
SELECT S.Id, S.GrossTotal, S.DiscountTotal, S.VatTotal, X.SatirTP, X.SatirKdv,
       ROUND(S.GrossTotal - S.DiscountTotal - X.SatirTP, 2) AS Fark_Net,
       ROUND(S.VatTotal - X.SatirKdv, 2)                    AS Fark_Kdv
FROM BKM.snv.SinavSiparisFisEncore FE
     JOIN EncoreMerkez.dbo.Sales S ON S.DocumentNo = FE.InvoiceNo
     CROSS APPLY (SELECT SUM(SP.TotalPrice) AS SatirTP, SUM(SP.VatTotal) AS SatirKdv
                  FROM EncoreMerkez.dbo.SalesProducts SP
                  WHERE SP.SalesId = S.Id AND SP.IsValid = 1) X
WHERE S.Date >= CONVERT(datetime,'18.08.2026',104)
  AND S.Date <  CONVERT(datetime,'19.08.2026',104)
ORDER BY S.Id;

-- 3) İndirim ayrışması: Direct + Indirect = header DiscountTotal
SELECT SUM(SP.DiscountTotalDirect)   AS SatirDirect,
       SUM(SP.DiscountTotalIndirect) AS SatirIndirect,
       SUM(SP.DiscountTotalCampaign) AS SatirCampaign,
       SUM(SP.TotalPrice)            AS NetKdvDahil,
       SUM(SP.VatTotal)              AS Kdv,
       SUM(SP.TotalPrice - SP.VatTotal) AS NetKdvHaric
FROM BKM.snv.SinavSiparisFisEncore FE
     JOIN EncoreMerkez.dbo.Sales S          ON S.DocumentNo = FE.InvoiceNo
     JOIN EncoreMerkez.dbo.SalesProducts SP ON SP.SalesId = S.Id AND SP.IsValid = 1
WHERE S.Date >= CONVERT(datetime,'18.08.2026',104)
  AND S.Date <  CONVERT(datetime,'19.08.2026',104);

-- 4) POS VatPercent ↔ ERP urn.KDVs KOD eşlemesi (1/2/6/7 → 0/1/10/20)
SELECT U.KDVs AS ErpKdvKod, SP.VatPercent AS PosKdvYuzde,
       COUNT(*) AS Satir, SUM(SP.TotalPrice) AS TutarKdvDahil, SUM(SP.VatTotal) AS Kdv
FROM BKM.snv.SinavSiparisFisEncore FE
     JOIN EncoreMerkez.dbo.Sales S          ON S.DocumentNo = FE.InvoiceNo
     JOIN EncoreMerkez.dbo.SalesProducts SP ON SP.SalesId = S.Id AND SP.IsValid = 1
     JOIN EncoreMerkez.dbo.Products PR      ON PR.Id = SP.ProductsId
     JOIN DerinSISBkm.dbo.urn U             ON U.stkID = PR.Code
WHERE S.Date >= CONVERT(datetime,'18.08.2026',104)
  AND S.Date <  CONVERT(datetime,'19.08.2026',104)
GROUP BY U.KDVs, SP.VatPercent
ORDER BY U.KDVs;

-- 5) Kategori × KDV oranı dağılımı (blended %1,81'in kaynağı)
SELECT k2.ktgrAd, SP.VatPercent, COUNT(*) AS Satir,
       SUM(SP.TotalPrice) AS TutarKdvDahil, SUM(SP.VatTotal) AS Kdv,
       SUM(SP.TotalPrice - SP.VatTotal) AS KdvHaric
FROM BKM.snv.SinavSiparisFisEncore FE
     JOIN EncoreMerkez.dbo.Sales S          ON S.DocumentNo = FE.InvoiceNo
     JOIN EncoreMerkez.dbo.SalesProducts SP ON SP.SalesId = S.Id AND SP.IsValid = 1
     JOIN EncoreMerkez.dbo.Products PR      ON PR.Id = SP.ProductsId
     LEFT JOIN DerinSISBkm.dbo.urn U        ON U.stkID = PR.Code
     LEFT JOIN DerinSISBkm.dbo.urnKtgr2 k2  ON k2.ktgrID = U.urnKtgr2ID
WHERE S.Date >= CONVERT(datetime,'18.08.2026',104)
  AND S.Date <  CONVERT(datetime,'19.08.2026',104)
GROUP BY k2.ktgrAd, SP.VatPercent
ORDER BY SUM(SP.TotalPrice) DESC;

-- 6) NOT IN (13,18) kaybı + join fan-out kontrolü (satır = tekil SP.Id olmalı)
SELECT COUNT(*) AS SatirFullJoin, COUNT(DISTINCT SP.Id) AS TekilSatir,
       SUM(SP.TotalPrice) AS TutarKdvDahil
FROM BKM.snv.SinavSiparisFisEncore FE
     JOIN EncoreMerkez.dbo.Sales S          ON S.DocumentNo = FE.InvoiceNo
     JOIN EncoreMerkez.dbo.SalesProducts SP ON SP.SalesId = S.Id AND SP.IsValid = 1
     JOIN EncoreMerkez.dbo.Products PR      ON PR.Id = SP.ProductsId
     JOIN DerinSISBkm.dbo.urn U             ON U.stkID = PR.Code
     JOIN DerinSISBkm.dbo.urnKtgr2 k2       ON k2.ktgrID = U.urnKtgr2ID AND U.urnKtgr2ID NOT IN (13,18)
     JOIN BKM.snv.Siparis sip               ON sip.SiparisKod = FE.SiparisKod AND sip.DonemId = 8
     LEFT JOIN BKM.snv.SiparisDetay sipdet  ON sipdet.SiparisId = sip.SiparisId AND sipdet.StokId = U.stkID
WHERE S.Date >= CONVERT(datetime,'18.08.2026',104)
  AND S.Date <  CONVERT(datetime,'19.08.2026',104);
-- 18.08.2026: 689 satır / 689 tekil (fan-out YOK) · 721-689=32 satır 38.949,83 ₺ Sınav Kıyafet kaybı
