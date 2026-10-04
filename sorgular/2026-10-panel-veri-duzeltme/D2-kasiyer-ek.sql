-- ork:hedef-db EncoreMerkez
-- ork:compat 110
/* Soru     : D-2: kasiyer satır sayısı farkı (ad çakışması) ve kategori karması eksiği hangi kayıttan geliyor?
   AC       : D-2 · Spec 001 · D2-kasiyer.sql'in ek blokları (sqlfluff 20.000 bayt sınırı için ayrıldı)
   Dönem    : @Bas = 01.09.2026, @Bit = 01.10.2026 (bitiş hariç)
   Tolerans : birebir (sayım) · ≤ 1,00 TL (tutar)
   Önce     : panel kasSql İst.Yolu 13 satır; panel katSql mağaza netinden 13.755,81 TL eksik (D2-kasiyer-once.sql, D2-kasiyer.sql B)
   Sonra    : yok
   Ölçüm    : (kaynak içi, bağımsız DEĞİL)
              U: İst.Yolu'nda UsersId 68 (29 belge) + 70 (4.870) ve 9 (108) + 10 (35) aynı adı taşır (1001 hariç belge sayısı).
              Y: kategoriye bağlanmayan tek ürün Products.Id 800625 / Code 1670694, 81 kalem, 13.755,81 TL (= B Σ).
   Aynı kaynak — neden: kasiyer ve kalem düzeyi yalnız Encore'da var; ERP'de karşılığı yok.
   Başka ne olabilir: Y'de ürün urn'de var ama urnKtgr2'siz olabilirdi; blok urn+urnKtgr2 birlikte aradığı için ikisini ayırmaz.
   Dondurma : 01b8381
   SSMS     : DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104);
   Komut    : sqlcli --read-only DECLARE kabul etmez; DECLARE'siz, literalle, --profile encore.
   Bloklar  : U ad çakışması · Y kategoriye bağlanmayan ürün.
*/
-- blok: U  (aynı adı taşıyan farklı UsersId: panel ad bazlı birleştirir, kanonik kimlik bazlı; kasiyer satır sayısı farkının kaynağı)
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104);  -- DMY

WITH Gd AS (
    SELECT DISTINCT sp.SalesId
    FROM EncoreMerkez.dbo.SalesProducts AS sp   -- 1001 tespiti IsValid'e bakmaz (plan K-B)
        INNER JOIN EncoreMerkez.dbo.Sales AS sg
            ON sp.SalesId = sg.Id
    WHERE
        sp.BarcodeNo = '1001'
        AND sg.[Date] >= @Bas
        AND sg.[Date] < @Bit
),

Kas AS (
    SELECT
        mg.mekanID,
        s.UsersId,
        COUNT(*) AS belge
    FROM EncoreMerkez.dbo.Sales AS s
        INNER JOIN EncoreMerkez.dbo.Pos AS p
            ON s.PosId = p.Id
        INNER JOIN EncoreMerkez.dbo.Stores AS st
            ON p.StoreId = st.Id
        INNER JOIN DerinSISBkm.dbo.posMagaza AS mg
            ON st.Code COLLATE Turkish_CI_AS = mg.mekanKod COLLATE Turkish_CI_AS
        LEFT JOIN Gd AS gd
            ON s.Id = gd.SalesId
    WHERE
        mg.mekanID IN (1, 4477, 4478)
        AND s.DocumentsTypeId IN (1, 2, 3, 6, 7, 8)
        AND gd.SalesId IS NULL
        AND s.[Date] >= @Bas
        AND s.[Date] < @Bit
    GROUP BY mg.mekanID, s.UsersId
)

SELECT
    k.mekanID AS [MekanId],
    k.UsersId AS KasiyerId,
    k.belge AS [Belge],
    DENSE_RANK() OVER (ORDER BY u.Name) AS AdGrubu
FROM Kas AS k
    INNER JOIN EncoreMerkez.dbo.Users AS u
        ON k.UsersId = u.Id
WHERE
    EXISTS (
        SELECT 1
        FROM Kas AS k2
            INNER JOIN EncoreMerkez.dbo.Users AS u2
                ON k2.UsersId = u2.Id
        WHERE k2.mekanID = k.mekanID AND k2.UsersId <> k.UsersId AND u2.Name = u.Name
    )
ORDER BY k.mekanID, AdGrubu, k.UsersId;
GO

-- blok: Y  (kategoriye bağlanmayan kalem: ürün, kalem, net; B'deki KategoriyeGirmeyenKalem Σ ile eşleşir)
/* tsqllint-disable non-sargable */
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104);  -- DMY

WITH Gd AS (
    SELECT DISTINCT sp.SalesId
    FROM EncoreMerkez.dbo.SalesProducts AS sp   -- 1001 tespiti IsValid'e bakmaz (plan K-B)
        INNER JOIN EncoreMerkez.dbo.Sales AS sg
            ON sp.SalesId = sg.Id
    WHERE
        sp.BarcodeNo = '1001'
        AND sg.[Date] >= @Bas
        AND sg.[Date] < @Bit
)

SELECT
    pr.Id AS ProductsId,
    pr.Code AS UrunKodu,
    COUNT(*) AS Kalem,
    CONVERT(DECIMAL(18, 2), SUM(
        CASE WHEN s.DocumentsTypeId = 3 THEN -1 ELSE 1 END * (sp.TotalPrice - sp.VatTotal)
    )) AS Net
FROM EncoreMerkez.dbo.Sales AS s
    INNER JOIN EncoreMerkez.dbo.Pos AS p
        ON s.PosId = p.Id
    INNER JOIN EncoreMerkez.dbo.Stores AS st
        ON p.StoreId = st.Id
    INNER JOIN DerinSISBkm.dbo.posMagaza AS mg
        ON st.Code COLLATE Turkish_CI_AS = mg.mekanKod COLLATE Turkish_CI_AS
    LEFT JOIN Gd AS gd
        ON s.Id = gd.SalesId
    INNER JOIN EncoreMerkez.dbo.SalesProducts AS sp
        ON s.Id = sp.SalesId
    INNER JOIN EncoreMerkez.dbo.Products AS pr
        ON sp.ProductsId = pr.Id
WHERE
    sp.IsValid = 1
    AND mg.mekanID IN (1, 4477, 4478)
    AND s.DocumentsTypeId IN (1, 2, 3, 6, 7, 8)
    AND gd.SalesId IS NULL
    AND s.[Date] >= @Bas
    AND s.[Date] < @Bit
    AND NOT EXISTS (
        SELECT 1
        FROM DerinSISBkm.dbo.urn AS u
            INNER JOIN DerinSISBkm.dbo.urnKtgr2 AS kt
                ON u.urnKtgr2ID = kt.ktgrID
        WHERE u.stkID = CASE
            WHEN pr.Code COLLATE Latin1_General_BIN2 NOT LIKE '%[^0-9]%' AND LEN(pr.Code) BETWEEN 1 AND 9
                THEN CONVERT(INT, pr.Code)
        END
    )
GROUP BY pr.Id, pr.Code
ORDER BY pr.Id;
/* tsqllint-enable non-sargable */
GO
