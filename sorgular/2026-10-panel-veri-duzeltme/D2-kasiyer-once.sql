-- ork:hedef-db EncoreMerkez
-- ork:compat 110
/* Soru     : Panelin mevcut (ÖNCE) kasiyer, saat, kategori ve mağaza net sorguları Eylül 2026'da ne değer veriyor?
   AC       : D-2 · Spec 001 · D2-kasiyer.sql'in ÖNCE bölümü (dosya sqlfluff 20.000 bayt sınırı için ayrıldı)
   Dönem    : @Bas = 01.09.2026, @Bit = 01.10.2026 (bitiş hariç)
   Tolerans : ≤ 1,00 TL (kanonik D2-kasiyer.sql ile kıyas)
   Önce     : ONCE-MAG Net: FSM 44.666.847,33 · Özlüce 57.819.343,91 · İst.Yolu 367.452.392,84
              ONCE-KAS (kasSql, 1001 DAHİL, ad bazlı) Σ Net: 44.564.381 (8 satır) · 57.704.918 (14) · 367.362.101 (13)
              ONCE-SAAT (saatSql, 1001 DAHİL) 14 saat · Fiş 124.402 · Net 469.631.399
              ONCE-KAT (katSql, 1001 kalem düzeyi) 18 kategori · Σ Ciro 469.924.828
   Sonra    : yok
   Bağımsız : D2-kasiyer.sql blokları A, M, S, B (aynı dönem)
   Aynı kaynak — neden: panel gövdeleri aynen; kanonik karşılığı D2-kasiyer.sql'dedir.
   Başka ne olabilir: bkz. D2-kasiyer.sql başlığı.
   Dondurma : 01b8381
   SSMS     : DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104);
   Komut    : sqlcli --read-only DECLARE kabul etmez; DECLARE'siz, literalle, --profile encore.
   Bloklar  : ONCE-MAG (Queries.cs :25) · ONCE-KAS (:155) · ONCE-SAAT (:145) · ONCE-KAT (:130); panel gövdeleri, biçim kurallarından muaf.
*/
-- noqa: disable=all
/* tsqllint-disable */
-- blok: ONCE-MAG  (panel storeSql Queries.cs :25 aynen; @start → @Bas, @end → @Bit; panel gövdesi, biçim kurallarından muaf)
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104);  -- DMY

SELECT MG.mekanID AS MekanId,
       SUM(CASE WHEN s.DocumentsTypeId=3 THEN -1 ELSE 1 END*(s.GrossTotal-s.DiscountTotal-s.VatTotal)) AS Net,
       SUM(CASE WHEN s.DocumentsTypeId=3 THEN -1 ELSE 1 END) AS Fis,
       SUM(CASE WHEN s.DocumentsTypeId=3 THEN (s.GrossTotal-s.DiscountTotal-s.VatTotal) ELSE 0 END) AS Iade
FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
JOIN EncoreMerkez.dbo.Pos p ON p.Id=s.PosId
JOIN EncoreMerkez.dbo.Stores st ON st.Id=p.StoreId
JOIN DerinSISBkm.dbo.posMagaza MG ON MG.mekanKod COLLATE Turkish_CI_AS = st.Code COLLATE Turkish_CI_AS
LEFT JOIN EncoreMerkez.dbo.SalesProducts spb ON spb.SalesId=s.Id AND spb.BarcodeNo='1001'
WHERE s.DocumentsTypeId IN (1,2,3,6,7,8) AND spb.Id IS NULL AND s.Date>=@Bas AND s.Date<@Bit
GROUP BY MG.mekanID;
GO

-- blok: ONCE-KAS  (panel kasSql Queries.cs :155 aynen, Magaza bazında dış toplam; kasiyer × mağaza gövde aynen)
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104);  -- DMY

SELECT x.Magaza, COUNT(*) AS KasiyerSatiri, SUM(x.Net) AS Net
FROM (
    SELECT CAST(st.Name AS nvarchar(30)) AS Magaza, CAST(ISNULL(u.Name,'?') AS nvarchar(30)) AS Ad, COUNT(*) AS Fis,
           CAST(SUM(CASE WHEN s.DocumentsTypeId=3 THEN -(s.GrossTotal-ABS(s.DiscountTotal)-s.VatTotal) ELSE s.GrossTotal-s.DiscountTotal-s.VatTotal END) AS decimal(18,0)) AS Net,
           SUM(CASE WHEN s.DocumentsTypeId=3 THEN 1 ELSE 0 END) AS Iade
    FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
    JOIN EncoreMerkez.dbo.Stores st ON st.Id=s.StoresId
    LEFT JOIN EncoreMerkez.dbo.Users u ON u.Id=s.UsersId
    WHERE s.DocumentsTypeId IN (1,2,3,6,7,8) AND s.Date>=@Bas AND s.Date<@Bit
    GROUP BY CAST(st.Name AS nvarchar(30)), CAST(ISNULL(u.Name,'?') AS nvarchar(30))
) x
GROUP BY x.Magaza
ORDER BY x.Magaza;
GO

-- blok: ONCE-SAAT  (panel saatSql Queries.cs :145 aynen, dış toplam; mağaza boyutu yok)
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104);  -- DMY

SELECT COUNT(*) AS SaatSayisi, SUM(x.Fis) AS Fis, SUM(x.Net) AS Net
FROM (
    SELECT DATEPART(HOUR,s.Date) AS Saat, SUM(CASE WHEN s.DocumentsTypeId=3 THEN -1 ELSE 1 END) AS Fis,
           CAST(SUM(CASE WHEN s.DocumentsTypeId=3 THEN -1 ELSE 1 END*(s.GrossTotal-s.DiscountTotal-s.VatTotal)) AS decimal(18,0)) AS Net
    FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
    WHERE s.DocumentsTypeId IN (1,2,3,6,7,8) AND s.Date>=@Bas AND s.Date<@Bit
    GROUP BY DATEPART(HOUR,s.Date)
) x;
GO

-- blok: ONCE-KAT  (panel katSql Queries.cs :130 aynen, dış toplam; mağaza boyutu yok)
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104);  -- DMY

SELECT COUNT(*) AS KategoriSayisi, SUM(x.Ciro) AS Ciro
FROM (
    SELECT CAST(ktg.ktgrAd AS nvarchar(50)) AS Ad,
           CAST(SUM(CASE WHEN s.DocumentsTypeId=3 THEN -1 ELSE 1 END*(sp.TotalPrice-sp.VatTotal)) AS decimal(18,0)) AS Ciro
    FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
    JOIN EncoreMerkez.dbo.SalesProducts sp WITH(NOLOCK) ON sp.SalesId=s.Id AND sp.IsValid=1 AND sp.BarcodeNo<>'1001'
    JOIN EncoreMerkez.dbo.Products pr WITH(NOLOCK) ON pr.Id=sp.ProductsId
    JOIN DerinSISBkm.dbo.urn u WITH(NOLOCK) ON u.stkID=CONVERT(int,pr.Code)
    JOIN DerinSISBkm.dbo.urnKtgr2 ktg WITH(NOLOCK) ON ktg.ktgrID=u.urnKtgr2ID
    WHERE s.DocumentsTypeId IN (1,2,3,6,7,8) AND ISNUMERIC(pr.Code)=1 AND s.Date>=@Bas AND s.Date<@Bit
    GROUP BY CAST(ktg.ktgrAd AS nvarchar(50))
) x;
GO
/* tsqllint-enable */
-- noqa: enable=all
