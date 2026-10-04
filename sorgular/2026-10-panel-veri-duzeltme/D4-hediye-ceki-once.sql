-- ork:hedef-db EncoreMerkez
-- ork:compat 110
/* Soru     : Panelin mevcut (ÖNCE) hediye çeki barem kalem sorgusu Eylül 2026'da ne değer veriyor?
   AC       : D-4 · Spec 001 · D4-hediye-ceki.sql'in ÖNCE bölümü (sqlfluff 20.000 bayt sınırı için ayrıldı)
   Dönem    : @Bas = 01.09.2026, @Bit = 01.10.2026 (bitiş hariç)
   Tolerans : ≤ 1,00 TL (kanonik D4-hediye-ceki.sql ile kıyas)
   Önce     : ONCE (Brut · Indirim · Net KDV HARİÇ · Brut − Indirim − Net), dilim 2..6:
                4.096,40 · 839,80 · 2.991,56 · 265,04 / 81.601,84 · 15.858,59 · 61.293,15 · 4.450,10
                / 237.404,58 · 51.169,48 · 170.723,30 · 15.511,80 / 410.245,74 · 69.907,01 · 302.988,35 · 37.350,38
                / 928.662,36 · 184.975,10 · 666.507,84 · 77.179,42
   Sonra    : yok
   Bağımsız : D4-hediye-ceki.sql blok A (aynı dönem)
   Aynı kaynak — neden: panel gövdesi aynen; kanonik karşılığı D4-hediye-ceki.sql'dedir.
   Başka ne olabilir: bkz. D4-hediye-ceki.sql başlığı.
   Dondurma : 01b8381
   SSMS     : DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104);
   Komut    : sqlcli --read-only DECLARE kabul etmez; DECLARE'siz, literalle, --profile encore.
   Bloklar  : ONCE (HediyeCekiQueries.cs :128 gövdesi, biçim kurallarından muaf).
*/
-- noqa: disable=all
-- blok: ONCE  (panel GetBaremKalemAsync gövdesi HediyeCekiQueries.cs :128 aynen; sabit parçalar genişletilmiş; dilim bazlı dış toplam)
/* tsqllint-disable */
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104);  -- DMY

SELECT x.Dilim,
       SUM(x.Adet) AS Adet,
       SUM(x.Brut) AS Brut,
       SUM(x.Indirim) AS Indirim,
       SUM(x.Net) AS Net,
       SUM(x.Brut) - SUM(x.Indirim) - SUM(x.Net) AS BrutEksiIndirimEksiNet
FROM (
    SELECT CASE WHEN hc.HcTutar <=  100 THEN 1
             WHEN hc.HcTutar <=  250 THEN 2
             WHEN hc.HcTutar <=  500 THEN 3
             WHEN hc.HcTutar <= 1000 THEN 4
             WHEN hc.HcTutar <= 2500 THEN 5
             ELSE 6 END AS Dilim,
           CONVERT(int, p.Code) AS StkID,
           ISNULL(ub.KatAna, N'Tanımsız') AS KatAna,
           SUM(CASE WHEN s.DocumentsTypeId = 3 THEN -sp.Amount ELSE sp.Amount END) AS Adet,
           SUM(CASE WHEN s.DocumentsTypeId = 3 THEN -(sp.TotalPrice + sp.DiscountTotalDirect)
                    ELSE (sp.TotalPrice + sp.DiscountTotalDirect) END) AS Brut,
           SUM(CASE WHEN s.DocumentsTypeId = 3 THEN -sp.DiscountTotalDirect
                    ELSE sp.DiscountTotalDirect END) AS Indirim,
           SUM(CASE WHEN s.DocumentsTypeId = 3 THEN -(sp.TotalPrice - sp.VatTotal)
                    ELSE (sp.TotalPrice - sp.VatTotal) END) AS Net
    FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
    JOIN EncoreMerkez.dbo.SalesProducts sp WITH(NOLOCK) ON sp.SalesId = s.Id AND sp.IsValid = 1
    JOIN EncoreMerkez.dbo.Products p WITH(NOLOCK) ON p.Id = sp.ProductsId
    JOIN DerinSISBkm.bkm.UrunBilgi ub WITH(NOLOCK) ON ub.stkID = CONVERT(int, p.Code)
    JOIN (SELECT SalesId, SUM(Amount) AS HcTutar
        FROM EncoreMerkez.dbo.SalesPayments WITH(NOLOCK)
        WHERE PaymentTypesId = 11 AND IsChangeAmount = 0
        GROUP BY SalesId) hc ON hc.SalesId = s.Id
    WHERE s.DocumentsTypeId IN (1, 3) AND s.Date >= @Bas AND s.Date < @Bit
      AND ISNUMERIC(p.Code) = 1
      AND ub.KatAna <> N'Hediye Çeki'
      AND sp.RefundReasonId <> 12
      AND p.Code <> '583160'
    GROUP BY CASE WHEN hc.HcTutar <=  100 THEN 1
             WHEN hc.HcTutar <=  250 THEN 2
             WHEN hc.HcTutar <=  500 THEN 3
             WHEN hc.HcTutar <= 1000 THEN 4
             WHEN hc.HcTutar <= 2500 THEN 5
             ELSE 6 END, CONVERT(int, p.Code), ub.KatAna
) x
GROUP BY x.Dilim
ORDER BY x.Dilim;
/* tsqllint-enable */
GO
-- noqa: enable=all
