/* Günlük ciro detay paketi — "dün ciro neydi" sorusunun kanonik cevabı.
   DB: DerinSISBkm (3-parçalı isimlerle EncoreMerkez + ODAKJOKER linked).
   Ölçüm penceresi: 04.09.2026 (parametre @g / @g1 ile değiştir).
   Bulgu (04.09.2026): POS net KDV-hariç 14.687.992 TL (Sınav 11.674.645 + perakende 3.013.347),
   3.226 fiş; e-ticaret 2.947 sipariş / 3.472.258 TL (KDV dahil, sipariş anı). */

DECLARE @g date = CONVERT(date,'04.09.2026',104);
DECLARE @g1 date = DATEADD(day,1,@g);

-- 1) Mağaza × belge tipi (net = GrossTotal - DiscountTotal - VatTotal, iade sign'lı)
SELECT CASE s.StoresId WHEN 1 THEN 'İst.Yolu' WHEN 2 THEN 'FSM' WHEN 3 THEN 'Özlüce'
       ELSE CONVERT(varchar,s.StoresId) END AS magaza,
       s.DocumentsTypeId AS belge, COUNT(*) AS fis,
       SUM(CASE WHEN s.DocumentsTypeId=3 THEN -s.GrossTotal ELSE s.GrossTotal END) AS brut,
       SUM(CASE WHEN s.DocumentsTypeId=3 THEN -s.DiscountTotal ELSE s.DiscountTotal END) AS indirim,
       SUM(CASE WHEN s.DocumentsTypeId=3 THEN -(s.GrossTotal-s.DiscountTotal-s.VatTotal)
                ELSE (s.GrossTotal-s.DiscountTotal-s.VatTotal) END) AS net_kdvharic
FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
WHERE s.DocumentsTypeId IN (1,2,3,6,7,8) AND s.Date >= @g AND s.Date < @g1
GROUP BY s.StoresId, s.DocumentsTypeId
ORDER BY magaza, belge;

-- 2) Kategori kırılımı (POS → DerinSIS köprüsü Products.Code = urn.stkID; stkKod/barkod DEĞİL)
SELECT ub.KatAna AS kategori,
 SUM(CASE WHEN s.DocumentsTypeId=3 THEN -sp.Amount ELSE sp.Amount END) AS adet,
 SUM(CASE WHEN s.DocumentsTypeId=3 THEN -(sp.TotalPrice - sp.VatTotal)
          ELSE (sp.TotalPrice - sp.VatTotal) END) AS net_kdvharic
FROM EncoreMerkez.dbo.SalesProducts sp WITH(NOLOCK)
JOIN EncoreMerkez.dbo.Sales s WITH(NOLOCK) ON s.Id=sp.SalesId
JOIN EncoreMerkez.dbo.Products p WITH(NOLOCK) ON p.Id=sp.ProductsId
JOIN DerinSISBkm.bkm.Urunbilgi ub ON ub.stkID = CONVERT(int, p.Code)
WHERE sp.IsValid=1 AND s.DocumentsTypeId IN (1,2,3,6,7,8) AND ISNUMERIC(p.Code)=1
  AND s.Date >= @g AND s.Date < @g1
GROUP BY ub.KatAna ORDER BY net_kdvharic DESC;
-- Mutabakat: bu bloğun toplamı (1)'in net toplamına EŞİT olmalı (kalem↔header, 04.09'da birebir tuttu).

-- 3) Ödeme tipi (KDV DAHİL tahsilat — ciro değil; IsChangeAmount=0 zorunlu)
SELECT pt.Name AS odeme, COUNT(*) AS adet, SUM(sp.Amount) AS tutar_kdvdahil
FROM EncoreMerkez.dbo.SalesPayments sp WITH(NOLOCK)
JOIN EncoreMerkez.dbo.Sales s WITH(NOLOCK) ON s.Id=sp.SalesId
LEFT JOIN EncoreMerkez.dbo.PaymentTypes pt ON pt.Id=sp.PaymentTypesId
WHERE sp.IsChangeAmount=0 AND s.DocumentsTypeId IN (1,2,3,6,7,8)
  AND s.Date >= @g AND s.Date < @g1
GROUP BY pt.Name ORDER BY tutar_kdvdahil DESC;

-- 4) Saatlik dağılım
SELECT DATEPART(hour,s.Date) AS saat, COUNT(*) AS fis,
  SUM(CASE WHEN s.DocumentsTypeId=3 THEN -(s.GrossTotal-s.DiscountTotal-s.VatTotal)
           ELSE (s.GrossTotal-s.DiscountTotal-s.VatTotal) END) AS net
FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
WHERE s.DocumentsTypeId IN (1,2,3,6,7,8) AND s.Date >= @g AND s.Date < @g1
GROUP BY DATEPART(hour,s.Date) ORDER BY saat;

-- 5) Trend: son 8 gün + geçen yıl aynı tarih (Sınav ayrıştırılmış)
SELECT CONVERT(date,s.Date) AS gun, DATENAME(weekday,s.Date) AS gun_adi, COUNT(*) AS fis,
  SUM(CASE WHEN s.DocumentsTypeId=8 THEN 0 WHEN s.DocumentsTypeId=3
           THEN -(s.GrossTotal-s.DiscountTotal-s.VatTotal)
           ELSE (s.GrossTotal-s.DiscountTotal-s.VatTotal) END) AS perakende,
  SUM(CASE WHEN s.DocumentsTypeId=8 THEN (s.GrossTotal-s.DiscountTotal-s.VatTotal) ELSE 0 END) AS sinav
FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
WHERE s.DocumentsTypeId IN (1,2,3,6,7,8)
  AND ((s.Date >= DATEADD(day,-7,@g) AND s.Date < @g1)
    OR (s.Date >= DATEADD(year,-1,@g) AND s.Date < DATEADD(year,-1,@g1)))
GROUP BY CONVERT(date,s.Date), DATENAME(weekday,s.Date) ORDER BY gun;

-- 6) E-ticaret (JOKER linked server — tarih ISO YYYYMMDD, DMY sessiz hata verir)
SELECT o.APPLICATION AS kanal, COUNT(*) AS siparis,
       CAST(SUM(o.TOTALPRICE) AS decimal(18,2)) AS tutar_kdvdahil,
       CAST(SUM(o.CARGOPRICE) AS decimal(18,2)) AS kargo
FROM ODAKJOKER.JOKER.dbo.J_ORDERS o
WHERE o.ORDERDATE >= '20260904' AND o.ORDERDATE < '20260905'
GROUP BY o.APPLICATION ORDER BY tutar_kdvdahil DESC;
