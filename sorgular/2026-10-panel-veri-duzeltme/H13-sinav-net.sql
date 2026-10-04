-- ork:hedef-db EncoreMerkez
-- ork:compat 110
/* Soru     : Ana sayfa mağaza netinde Sınav Okulları, perakendeden ayrı bir tutar olarak (iade kanalına göre) ne kadar?
   AC       : AC-13.1, AC-13.2 · Spec 001 · H13 · KR-1 (1001 dışlaması) · İnsan onayı 4 (Sınav'a bağlı iade Sınav satırından düşer)
   Dönem    : @Bas = 01.09.2026, @Bit = 01.10.2026 (bitiş hariç); mekanID 1 FSM · 4477 Özlüce · 4478 İst.Yolu
   Çıktı    : (MekanId int, NetSinav decimal) — blok A; parametre @Bas, @Bit
   Tolerans : tutar ≤ 1 TL
   Önce     : (04.10.2026, sqlcli encore profili, --read-only; panel storeSql Queries.cs :25-36 aynen, blok ONCE)
              Panel Sınav'ı ayırmıyor; Net tek satır: FSM 44.666.847,33 · Özlüce 57.819.343,91 · İst.Yolu 367.452.392,84
              (toplam 469.938.584,08; 02.10 referansı 469.938.584 ile tutar).
   Sonra    : yok (düzeltme T-040, T-045 sonrası ölçülür)
   Bağımsız : (04.10.2026) B = başlık yerine KALEM toplamı (TotalPrice − VatTotal, IsValid = 1), aynı belge kümesi:
              FSM −190,83 · Özlüce −1.630,27 · İst.Yolu 325.059.112,77; A ile üç mağazada birebir (fark 0,00).
              A1 bileşenler: İst.Yolu Sınav satışı 5.466 belge / 330.349.209,10 − Sınav'a bağlı iade 182 belge / 5.290.096,33
              (T-001 F ile aynı); FSM 1 iade / 190,83 · Özlüce 3 iade / 1.630,27 (T-001 F2 ile aynı, toplam 4 / 1.821,10).
              Sınav neti toplamı (3 mağaza) 325.057.291,67.
              K bölüntü: Perakende 44.667.038,16 · 57.820.974,18 · 42.393.280,07 (toplam 144.881.292,41) + Sınav = NetToplam
              44.666.847,33 · 57.819.343,91 · 367.452.392,84; panel ONCE Net ile üç mağazada birebir (fark 0,00).
              Perakende + Sınav = 469.938.584,08 = ONCE toplamı.
   Fark     : (Önce − Bağımsız) Panelde Sınav satırı yok; ONCE Net = K NetToplam üç mağazada 0,00. Yani değişen toplam değil,
              yalnız bölüntü: İst.Yolu netinin 325.059.112,77'si Sınav, 42.393.280,07'si perakende.
   Nüfus    : (blok N, 04.10.2026) Eylül tüm mağaza: Sınav belgesi (tip 8) 5.466 · Sınav'a bağlı iade 186 (3 mağazada 186 = 182 + 4)
              · 1001 taşıyan tip 3 veya tip 8 belge 1.852 · mağaza neti belgesi (tip 1,2,3,6,7,8) 134.314.
              Nüfus > 0; 0 olsaydı sonuç 'bakamadım' okunurdu.
   Aynı kaynak — neden: A (başlık) ile B (kalem) aynı EncoreMerkez.Sales/SalesProducts'tan kurulur; B ↔ A kaynak içi tutarlılıktır,
              bağımsız DEĞİL. Sınav ERP'de belge bazlı ayrılamaz (eTip 100 günlük özet; sql-server-conventions § KANAL AYRACI),
              bu yüzden ERP'den bağımsız kıyas yok; ERP ile mutabakat toplam düzeyinde H13-sube-cirosu.sql'dedir.
   Başka ne olabilir: (1) Sınav iadesi Sınav'a değil perakendeye düşmeliydi: İnsan onayı 4 tersini söylüyor; iade yönü iki yorumdan
              biri değil, karar. (2) LinkedDocumentId = 0 (563 belge / 165.801,79) ve bağlı diğer (767 / 869.440,06) iadeler
              perakendede kalır; Sınav'dan gelmiş olabilirler, kanıtlanmadı. (3) Bağlı satış Eylül dışı olabilir; iade KENDİ tarihine
              yazılır (KR). (4) FSM ve Özlüce'de Sınav satışı 0, yalnız bağlı iade var: ihmal (1.821,10).
   Kapsam   : Mağaza = Pos → Stores → posMagaza. Sınav = DocumentsTypeId 8, artı DocumentsTypeId 3 ve LinkedDocumentId > 0
              ve bağlı belge tipi 8 (iade negatif). Net = GrossTotal − DiscountTotal − VatTotal (KDV hariç). 1001 barkodlu
              belge (kalem IsValid'e bakmaz) hariç. Mekan = iadenin kendi mekânı.
   Dondurma : 01b8381
   SSMS     : DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104);
   Komut    : sqlcli --read-only DECLARE kabul etmez; bloklar GO'suz ve DECLARE'siz, @Bas/@Bit literalle değiştirilerek
              koşuldu (SSMS DECLARE + GO esas); hepsi --profile encore, --max-rows 1000.
   Bloklar  : A kanonik Sınav neti · A1 satış ve iade bileşenleri · B kalem bazlı bağımsız yöntem · K Perakende + Sınav bölüntüsü
              · ONCE panel gövdesi · N nüfus. Boş nüfus 'bakamadım'dır, 'temiz' değil.
*/

-- blok: A  (kanonik Sınav neti: tip 8 + bağlı belgesi tip 8 olan iade (negatif); KDV hariç; 1001 hariç; üç mağaza)
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

Kume AS (
    SELECT
        mg.mekanID AS mekan_id,
        s.DocumentsTypeId AS belge_tipi,
        s.GrossTotal - s.DiscountTotal - s.VatTotal AS net
    FROM EncoreMerkez.dbo.Sales AS s
        INNER JOIN EncoreMerkez.dbo.Pos AS p
            ON s.PosId = p.Id
        INNER JOIN EncoreMerkez.dbo.Stores AS st
            ON p.StoreId = st.Id
        INNER JOIN DerinSISBkm.dbo.posMagaza AS mg
            ON st.Code COLLATE Turkish_CI_AS = mg.mekanKod COLLATE Turkish_CI_AS
        LEFT JOIN Gd AS gd
            ON s.Id = gd.SalesId
        LEFT JOIN EncoreMerkez.dbo.Sales AS o
            ON
                s.LinkedDocumentId = o.Id
                AND s.LinkedDocumentId > 0
    WHERE
        mg.mekanID IN (1, 4477, 4478)
        AND gd.SalesId IS NULL
        AND s.[Date] >= @Bas
        AND s.[Date] < @Bit
        AND (
            s.DocumentsTypeId = 8
            OR (s.DocumentsTypeId = 3 AND o.DocumentsTypeId = 8)
        )
)

SELECT
    k.mekan_id AS MekanId,
    CONVERT(DECIMAL(18, 2), SUM(CASE WHEN k.belge_tipi = 3 THEN -k.net ELSE k.net END)) AS NetSinav
FROM Kume AS k
GROUP BY k.mekan_id
ORDER BY k.mekan_id;
GO

-- blok: A1  (A'nın bileşenleri: Sınav satışı ve Sınav'a bağlı iade; mağaza başına)
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
    mg.mekanID AS [MekanId],
    SUM(CASE WHEN s.DocumentsTypeId = 8 THEN 1 ELSE 0 END) AS SinavSatisBelge,
    CONVERT(DECIMAL(18, 2), SUM(
        CASE WHEN s.DocumentsTypeId = 8 THEN s.GrossTotal - s.DiscountTotal - s.VatTotal ELSE 0 END
    )) AS SinavSatisNet,
    SUM(CASE WHEN s.DocumentsTypeId = 3 THEN 1 ELSE 0 END) AS SinavIadeBelge,
    CONVERT(DECIMAL(18, 2), SUM(
        CASE WHEN s.DocumentsTypeId = 3 THEN s.GrossTotal - s.DiscountTotal - s.VatTotal ELSE 0 END
    )) AS SinavIadeNet
FROM EncoreMerkez.dbo.Sales AS s
    INNER JOIN EncoreMerkez.dbo.Pos AS p
        ON s.PosId = p.Id
    INNER JOIN EncoreMerkez.dbo.Stores AS st
        ON p.StoreId = st.Id
    INNER JOIN DerinSISBkm.dbo.posMagaza AS mg
        ON st.Code COLLATE Turkish_CI_AS = mg.mekanKod COLLATE Turkish_CI_AS
    LEFT JOIN Gd AS gd
        ON s.Id = gd.SalesId
    LEFT JOIN EncoreMerkez.dbo.Sales AS o
        ON
            s.LinkedDocumentId = o.Id
            AND s.LinkedDocumentId > 0
WHERE
    mg.mekanID IN (1, 4477, 4478)
    AND gd.SalesId IS NULL
    AND s.[Date] >= @Bas
    AND s.[Date] < @Bit
    AND (
        s.DocumentsTypeId = 8
        OR (s.DocumentsTypeId = 3 AND o.DocumentsTypeId = 8)
    )
GROUP BY mg.mekanID
ORDER BY mg.mekanID;
GO

-- blok: B  (bağımsız yöntem: başlık yerine KALEM toplamı, TotalPrice − VatTotal, yalnız IsValid = 1 kalem)
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
    mg.mekanID AS [MekanId],
    CONVERT(DECIMAL(18, 2), SUM(
        CASE WHEN s.DocumentsTypeId = 3 THEN -(sp.TotalPrice - sp.VatTotal) ELSE sp.TotalPrice - sp.VatTotal END
    )) AS NetSinavKalem
FROM EncoreMerkez.dbo.SalesProducts AS sp
    INNER JOIN EncoreMerkez.dbo.Sales AS s
        ON sp.SalesId = s.Id
    INNER JOIN EncoreMerkez.dbo.Pos AS p
        ON s.PosId = p.Id
    INNER JOIN EncoreMerkez.dbo.Stores AS st
        ON p.StoreId = st.Id
    INNER JOIN DerinSISBkm.dbo.posMagaza AS mg
        ON st.Code COLLATE Turkish_CI_AS = mg.mekanKod COLLATE Turkish_CI_AS
    LEFT JOIN Gd AS gd
        ON s.Id = gd.SalesId
    LEFT JOIN EncoreMerkez.dbo.Sales AS o
        ON
            s.LinkedDocumentId = o.Id
            AND s.LinkedDocumentId > 0
WHERE
    sp.IsValid = 1
    AND mg.mekanID IN (1, 4477, 4478)
    AND gd.SalesId IS NULL
    AND s.[Date] >= @Bas
    AND s.[Date] < @Bit
    AND (
        s.DocumentsTypeId = 8
        OR (s.DocumentsTypeId = 3 AND o.DocumentsTypeId = 8)
    )
GROUP BY mg.mekanID
ORDER BY mg.mekanID;
GO

-- blok: K  (bölüntü kimliği AC-13.1: Perakende + Sınav = panel tanımlı Net; 1001 hariç; mağaza başına)
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

Kume AS (
    SELECT
        mg.mekanID AS mekan_id,
        CASE WHEN s.DocumentsTypeId = 3 THEN -1 ELSE 1 END * (s.GrossTotal - s.DiscountTotal - s.VatTotal) AS net_isaretli,
        CASE
            WHEN s.DocumentsTypeId = 8 THEN 1
            WHEN s.DocumentsTypeId = 3 AND o.DocumentsTypeId = 8 THEN 1
            ELSE 0
        END AS sinav_mi
    FROM EncoreMerkez.dbo.Sales AS s
        INNER JOIN EncoreMerkez.dbo.Pos AS p
            ON s.PosId = p.Id
        INNER JOIN EncoreMerkez.dbo.Stores AS st
            ON p.StoreId = st.Id
        INNER JOIN DerinSISBkm.dbo.posMagaza AS mg
            ON st.Code COLLATE Turkish_CI_AS = mg.mekanKod COLLATE Turkish_CI_AS
        LEFT JOIN Gd AS gd
            ON s.Id = gd.SalesId
        LEFT JOIN EncoreMerkez.dbo.Sales AS o
            ON
                s.LinkedDocumentId = o.Id
                AND s.LinkedDocumentId > 0
    WHERE
        mg.mekanID IN (1, 4477, 4478)
        AND s.DocumentsTypeId IN (1, 2, 3, 6, 7, 8)
        AND gd.SalesId IS NULL
        AND s.[Date] >= @Bas
        AND s.[Date] < @Bit
)

SELECT
    k.mekan_id AS MekanId,
    CONVERT(DECIMAL(18, 2), SUM(CASE WHEN k.sinav_mi = 0 THEN k.net_isaretli ELSE 0 END)) AS NetPerakende,
    CONVERT(DECIMAL(18, 2), SUM(CASE WHEN k.sinav_mi = 1 THEN k.net_isaretli ELSE 0 END)) AS NetSinav,
    CONVERT(DECIMAL(18, 2), SUM(k.net_isaretli)) AS NetToplam
FROM Kume AS k
GROUP BY k.mekan_id
ORDER BY k.mekan_id;
GO

-- noqa: disable=all
/* tsqllint-disable */
-- blok: ONCE  (panel storeSql :25-36 aynen; @start → @Bas, @end → @Bit; panel gövdesi, biçim kurallarından muaf)
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
/* tsqllint-enable */
-- noqa: enable=all

-- blok: N  (nüfus: tek satır; Eylül 2026, üç mağaza)
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104);  -- DMY

SELECT
    (
        SELECT COUNT(*)
        FROM EncoreMerkez.dbo.Sales AS s
        WHERE s.DocumentsTypeId = 8 AND s.[Date] >= @Bas AND s.[Date] < @Bit
    ) AS sinav_belge_eylul_tum_magaza,
    (
        SELECT COUNT(*)
        FROM EncoreMerkez.dbo.Sales AS i
            INNER JOIN EncoreMerkez.dbo.Sales AS o
                ON i.LinkedDocumentId = o.Id
        WHERE
            i.DocumentsTypeId = 3
            AND i.LinkedDocumentId > 0
            AND o.DocumentsTypeId = 8
            AND i.[Date] >= @Bas
            AND i.[Date] < @Bit
    ) AS sinava_bagli_iade_eylul_tum_magaza,
    (
        SELECT COUNT(DISTINCT sp.SalesId)
        FROM EncoreMerkez.dbo.SalesProducts AS sp
            INNER JOIN EncoreMerkez.dbo.Sales AS s
                ON sp.SalesId = s.Id
        WHERE
            sp.BarcodeNo = '1001'
            AND s.DocumentsTypeId IN (3, 8)
            AND s.[Date] >= @Bas
            AND s.[Date] < @Bit
    ) AS bin_bir_tip3_tip8_belge,
    (
        SELECT COUNT(*)
        FROM EncoreMerkez.dbo.Sales AS s
        WHERE s.DocumentsTypeId IN (1, 2, 3, 6, 7, 8) AND s.[Date] >= @Bas AND s.[Date] < @Bit
    ) AS magaza_neti_belge_eylul_tum_magaza;
