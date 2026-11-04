/* DONDURULMUS KOPYA (karakterizasyon girdisi) - DEGISTIRME.
   Kaynak: dashboard/Data/Queries.cs:26-36 (storeSql), commit d5cf345; HEAD'deki metinle ayni.
   Spec 001 SC-006 (koruma testleri). Parametre: @start, @end (date, bitis haric).
   Uretir: (MekanId int, Net decimal, Fis int, Iade decimal)
   Eylul 2026 (@start=01.09.2026, @end=01.10.2026), olculdu 04.10.2026:
     1    Net 44.666.847,33   Fis 42.311  Iade   995.170,57
     4477 Net 57.819.343,91   Fis 47.525  Iade 1.173.183,70
     4478 Net 367.452.392,84  Fis 36.417  Iade 6.234.866,80
     Toplam Net 469.938.584,08 (T-016 ile ayni, kayma yok)
   Salt-okuma. Paneldeki metin birebir; bicim kapilari bilincli kapali. */
-- ork:hedef-db EncoreMerkez
-- ork:compat 110
-- noqa: disable=all
/* tsqllint-disable */
-- SSMS: DECLARE @start date = CONVERT(date, '01.09.2026', 104), @end date = CONVERT(date, '01.10.2026', 104);
SELECT MG.mekanID AS MekanId,
       SUM(CASE WHEN s.DocumentsTypeId=3 THEN -1 ELSE 1 END*(s.GrossTotal-s.DiscountTotal-s.VatTotal)) AS Net,
       SUM(CASE WHEN s.DocumentsTypeId=3 THEN -1 ELSE 1 END) AS Fis,
       SUM(CASE WHEN s.DocumentsTypeId=3 THEN (s.GrossTotal-s.DiscountTotal-s.VatTotal) ELSE 0 END) AS Iade
FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
JOIN EncoreMerkez.dbo.Pos p ON p.Id=s.PosId
JOIN EncoreMerkez.dbo.Stores st ON st.Id=p.StoreId
JOIN DerinSISBkm.dbo.posMagaza MG ON MG.mekanKod COLLATE Turkish_CI_AS = st.Code COLLATE Turkish_CI_AS
LEFT JOIN EncoreMerkez.dbo.SalesProducts spb ON spb.SalesId=s.Id AND spb.BarcodeNo='1001'
WHERE s.DocumentsTypeId IN (1,2,3,6,7,8) AND spb.Id IS NULL AND s.Date>=@start AND s.Date<@end
GROUP BY MG.mekanID;
