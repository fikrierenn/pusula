-- ork:hedef-db EncoreMerkez
-- ork:compat 110
/* Soru     : Fiş sayısı her ekranda aynı mı? Fiş yalnız satış fişi mi (iade, fatura, personel, Sınav ve geri dönüşüm hariç)?
   AC       : AC-5.1, AC-5.3, AC-5.4 · Spec 001 · H05 · KR-1 (kanonik tanım 1001 barkodu)
   Dönem    : A ve C: @Bas = 01.09.2026, @Bit = 01.10.2026 (bitiş hariç), FSM (mekanID 1); D: aynı dönem, 3 mağaza
              B: son 12 ay, @Bugun = 04.10.2026 (gün başı; bugün dahil değil)
   Tolerans : sayı birebir; B'de NetCiro (belge tipi 1 ve 3) panelle ≤ 1 TL
   Önce     : (04.10.2026, sqlcli encore profili, --read-only; dönem Eylül 2026, FSM)
              Home (Queries.cs GetPeriodAsync storeSql) Fis = SUM(iade ? -1 : 1), tipler 1,2,3,6,7,8, 1001 hariç: 42.311
                -> 42.774 (satış) + 244 (fatura) + 232 (personel fiş) + 8 (personel fatura) - 947 (iade) = 42.311; iade eksi sayılıyor
              Trafik (TrafikQueries.cs satır 32, 71, 168) Fis = COUNT(*), aynı tipler: 44.205
                -> 42.774 + 244 + 947 + 232 + 8 = 44.205; iade artı sayılıyor
              Home ile Trafik farkı 1.894 = 2 x 947 (iade işareti). 02.10 referansı Trafik 44.776 bu koşuda yeniden üretilemedi
              (571 fazla; sebep bu dosyada ölçülmedi, Eylül verisi sonradan değişmiş olabilir)
              GetKartliAsync (SadakatQueries.cs): yalnız tip 1 ve 3 sayıyor, 1001 dışlaması yok; COUNT(*) iadeyi de fiş sayıyor
              (tip 1 ve 3 belge sayısı 639.664 + 472.023 = 1.111.687; kanonik fiş toplamı aşağıda)
              İade (AC-5.4): Home Iade kolonu tutardır (sayı değil); 1001 hariç iade belgesi sayısı Home sorgusundan 947
   Sonra    : yok (düzeltme T-041..T-047 sonrası ölçülür)
   Bağımsız : (04.10.2026) A: FSM 42.774 · Özlüce 47.782 · İst.Yolu 31.488
              C: FSM 947 · Özlüce 1.167 · İst.Yolu 990 (1001 dahil iade 1.518 · 1.926 · 1.512)
              B: kartlı 629.063 fiş, 457.409.931,69 TL · kartsız 453.132 fiş, 265.904.702,52 TL (NetCiro tip 1 ve 3, 1001 dahil)
              D: Eylül iade belgesi (kollar sebep12/kod583160/barkod1001, 1 = var): FSM 941 yok · 4 (0,1,1) · 6 (1,0,0) · 567 (1,1,1);
                 Özlüce 1.157 · 6 · 10 · 753; İst.Yolu 970 · 40 · 20 · 482. Yalnız 583160 ve yalnız 1001 kolu 0;
                 583160 olan her belgede 1001 var.
                 Panel tanımı (sebep 12 veya 583160) 1001'den 3 mağazada 36 belge fazla dışlıyor (6 + 10 + 20: yalnız sebep 12 olanlar)
   Nüfus    : (blok N, 04.10.2026) Eylül 3 mağaza belge (tip 1 ve 3) 127.001 · 1001 taşıyan Eylül belgesi (tüm mağaza) 1.853
              · son 12 ay belge (tip 1 ve 3) 1.163.756 · iç kart kuralıyla dışlanan 52.069
   Aynı kaynak — neden: Fiş belge düzeyinde yalnız Encore'da var. ERP'de (DerinSISBkm.dbo.irsHrk, ehTip 100) POS satışı günlük
              özet belgedir (ayda 32 satır); belge sayısı üretilemez, bağımsız kaynak yok. Yöntem bağımsız: sayım
              Sales başlığından, 1001 dışlaması SalesProducts üzerinden (panel LEFT JOIN spb IS NULL, burada DISTINCT SalesId
              anti-join); panelin işaretli toplamı (SUM +1/-1) yerine tipe göre ayrı sayım.
   Başka ne olabilir: (1) 1001 tespiti kalemin IsValid değerine bakmaz (plan K-B); geçersiz 1001 satırlı bir fiş de dışlanır.
              (2) Iade belgesinin tamamı 1001 ise iade sayısına girmez (947 = 1.518 - 571). (3) Bir fişte hem 1001 hem başka
              ürün varsa belge bütünüyle dışlanır (kalem düzeyi değil). (4) Mağaza bağı Pos -> Stores -> posMagaza; pozu
              olmayan belge hiçbir mağazaya girmez. (5) Blok B'de iç kart kuralı yalnız isim (Mağaza/Kumbara) ve telefon (599/699);
              elle işaretli liste (PanelIcKart) okunamadı, aşağıya bak. (6) Blok B kartsız anonim (CustomersId = 0) dahildir.
   İç kart  : isim + telefon kuralı (IcKartFiltre). Elle liste bu makinede okunamadı (BkmPanel dbo.PanelIcKart);
              etkisi blok N'de ayrı sütunda sayılır.
   Kapsam   : Fiş = Sales.DocumentsTypeId = 1 ve belgede BarcodeNo = '1001' satırı yok. İade = DocumentsTypeId = 3 ve 1001 satırı yok.
              Kartlı = CustomersId > 0 ve CardNumber <> ''. Fatura (2), personel (6, 7), Sınav (8) fiş sayılmaz.
   Dondurma : 47e7030
   SSMS     : DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104), @MekanId INT = 1;
              DECLARE @Bugun DATE = CONVERT(DATE, '04.10.2026', 104);
   Komut    : sqlcli --read-only DECLARE kabul etmez; bloklar GO'suz ve DECLARE'siz, literal tarihle koşuldu (SSMS DECLARE + GO esas).
   Bloklar  : A fiş sayısı (Fis) · B kartlı/kartsız (Tip, FisSayisi, NetCiro) · C iade sayısı (IadeSayisi)
              · D iade tanım kolları (kanıt) · N nüfus (tek satır)
              Boş nüfus 'bakamadım'dır, 'temiz' değil; blok N her koşuda beklenen büyüklükte dönmelidir.
*/

-- blok: A  (kanonik fiş sayısı; @MekanId = 1 FSM)
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104), @MekanId INT = 1;  -- DMY

WITH Gd AS (
    SELECT DISTINCT sp.SalesId
    FROM EncoreMerkez.dbo.SalesProducts AS sp   -- 1001 tespiti IsValid'e bakmaz (plan K-B)
    WHERE sp.BarcodeNo = '1001'
)

SELECT COUNT(*) AS Fis
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
    mg.mekanID = @MekanId
    AND s.DocumentsTypeId = 1
    AND gd.SalesId IS NULL
    AND s.[Date] >= @Bas
    AND s.[Date] < @Bit;
GO

-- blok: B  (kartlı/kartsız fiş ve ciro; son 12 ay, tüm mağazalar)
DECLARE @Bugun DATE = CONVERT(DATE, '04.10.2026', 104);  -- DMY

WITH Gd AS (
    SELECT DISTINCT sp.SalesId
    FROM EncoreMerkez.dbo.SalesProducts AS sp   -- 1001 tespiti IsValid'e bakmaz (plan K-B)
    WHERE sp.BarcodeNo = '1001'
)

SELECT
    CASE
        WHEN s.CustomersId > 0 AND ISNULL(c.CardNumber, '') <> '' THEN N'Kartlı'
        ELSE N'Kartsız'
    END AS Tip,
    SUM(CASE WHEN s.DocumentsTypeId = 1 AND gd.SalesId IS NULL THEN 1 ELSE 0 END) AS FisSayisi,
    SUM(CASE
        WHEN s.DocumentsTypeId = 3 THEN -(s.GrossTotal - s.DiscountTotal - s.VatTotal)
        ELSE (s.GrossTotal - s.DiscountTotal - s.VatTotal)
    END) AS NetCiro
FROM EncoreMerkez.dbo.Sales AS s
    LEFT JOIN Gd AS gd
        ON s.Id = gd.SalesId
    LEFT JOIN DerinCrm.dbo.Customer AS c
        ON s.CustomersId = c.Id
WHERE
    s.DocumentsTypeId IN (1, 3)
    AND s.[Date] >= DATEADD(MONTH, -12, @Bugun)
    AND s.[Date] < @Bugun
    AND (
        c.Id IS NULL
        OR (
            c.Name NOT LIKE N'%Mağaza%' COLLATE Turkish_CI_AS
            AND c.Name NOT LIKE N'%Kumbara%' COLLATE Turkish_CI_AS
            AND ISNULL(c.PhoneNumber, '') NOT LIKE '599%'
            AND ISNULL(c.PhoneNumber, '') NOT LIKE '699%'
        )
    )
GROUP BY
    CASE
        WHEN s.CustomersId > 0 AND ISNULL(c.CardNumber, '') <> '' THEN N'Kartlı'
        ELSE N'Kartsız'
    END
ORDER BY Tip;
GO

-- blok: C  (kanonik iade sayısı; @MekanId = 1 FSM)
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104), @MekanId INT = 1;  -- DMY

WITH Gd AS (
    SELECT DISTINCT sp.SalesId
    FROM EncoreMerkez.dbo.SalesProducts AS sp   -- 1001 tespiti IsValid'e bakmaz (plan K-B)
    WHERE sp.BarcodeNo = '1001'
)

SELECT COUNT(*) AS IadeSayisi
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
    mg.mekanID = @MekanId
    AND s.DocumentsTypeId = 3
    AND gd.SalesId IS NULL
    AND s.[Date] >= @Bas
    AND s.[Date] < @Bit;
GO

-- blok: D  (kanıt: iade belgelerinde geri dönüşüm tanımları; kanonik tanım 1001'dir, KR-1)
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104);  -- DMY

WITH Kume AS (
    SELECT
        s.Id AS satis_id,
        mg.mekanID AS mekan_id
    FROM EncoreMerkez.dbo.Sales AS s
        INNER JOIN EncoreMerkez.dbo.Pos AS p
            ON s.PosId = p.Id
        INNER JOIN EncoreMerkez.dbo.Stores AS st
            ON p.StoreId = st.Id
        INNER JOIN DerinSISBkm.dbo.posMagaza AS mg
            ON st.Code COLLATE Turkish_CI_AS = mg.mekanKod COLLATE Turkish_CI_AS
    WHERE
        mg.mekanID IN (1, 4477, 4478)
        AND s.DocumentsTypeId = 3
        AND s.[Date] >= @Bas
        AND s.[Date] < @Bit
),

SebepKodu AS (   -- panel tanımı: geçerli kalemde RefundReasonId = 12
    SELECT DISTINCT sp.SalesId
    FROM EncoreMerkez.dbo.SalesProducts AS sp
        INNER JOIN Kume AS k
            ON sp.SalesId = k.satis_id
    WHERE
        sp.IsValid = 1
        AND sp.RefundReasonId = 12
),

UrunKodu AS (   -- panel tanımı: geçerli kalemde Products.Code = '583160'
    SELECT DISTINCT sp.SalesId
    FROM EncoreMerkez.dbo.SalesProducts AS sp
        INNER JOIN Kume AS k
            ON sp.SalesId = k.satis_id
        INNER JOIN EncoreMerkez.dbo.Products AS pr
            ON sp.ProductsId = pr.Id
    WHERE
        sp.IsValid = 1
        AND pr.Code = '583160'
),

Barkod AS (   -- kanonik tanım: 1001 barkodu (IsValid'e bakmaz)
    SELECT DISTINCT sp.SalesId
    FROM EncoreMerkez.dbo.SalesProducts AS sp
        INNER JOIN Kume AS k
            ON sp.SalesId = k.satis_id
    WHERE sp.BarcodeNo = '1001'
),

Bayrak AS (
    SELECT
        k.mekan_id,
        CASE WHEN sk.SalesId IS NULL THEN 0 ELSE 1 END AS sebep12,
        CASE WHEN uk.SalesId IS NULL THEN 0 ELSE 1 END AS kod583160,
        CASE WHEN bk.SalesId IS NULL THEN 0 ELSE 1 END AS barkod1001
    FROM Kume AS k
        LEFT JOIN SebepKodu AS sk
            ON k.satis_id = sk.SalesId
        LEFT JOIN UrunKodu AS uk
            ON k.satis_id = uk.SalesId
        LEFT JOIN Barkod AS bk
            ON k.satis_id = bk.SalesId
)

SELECT
    b.mekan_id AS mekan_kodu,
    b.sebep12 AS sebep_kodu_12,
    b.kod583160 AS urun_kodu_583160,
    b.barkod1001 AS barkod_1001,
    COUNT(*) AS iade_belgesi
FROM Bayrak AS b
GROUP BY b.mekan_id, b.sebep12, b.kod583160, b.barkod1001
ORDER BY b.mekan_id, b.sebep12, b.kod583160, b.barkod1001;
GO

-- blok: N  (nüfus: tek satır)
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104);  -- DMY
DECLARE @Bugun DATE = CONVERT(DATE, '04.10.2026', 104);  -- DMY

WITH Gd AS (
    SELECT DISTINCT sp.SalesId
    FROM EncoreMerkez.dbo.SalesProducts AS sp   -- 1001 tespiti IsValid'e bakmaz (plan K-B)
    WHERE sp.BarcodeNo = '1001'
)

SELECT
    (
        SELECT COUNT(*)
        FROM EncoreMerkez.dbo.Sales AS s
            INNER JOIN EncoreMerkez.dbo.Pos AS p ON s.PosId = p.Id
            INNER JOIN EncoreMerkez.dbo.Stores AS st ON p.StoreId = st.Id
            INNER JOIN DerinSISBkm.dbo.posMagaza AS mg
                ON st.Code COLLATE Turkish_CI_AS = mg.mekanKod COLLATE Turkish_CI_AS
        WHERE
            mg.mekanID IN (1, 4477, 4478)
            AND s.DocumentsTypeId IN (1, 3)
            AND s.[Date] >= @Bas
            AND s.[Date] < @Bit
    ) AS belge_1_3_eylul_uc_magaza,
    (
        SELECT COUNT(*)
        FROM EncoreMerkez.dbo.Sales AS s
            INNER JOIN Gd AS gd ON s.Id = gd.SalesId
        WHERE
            s.DocumentsTypeId IN (1, 3)
            AND s.[Date] >= @Bas
            AND s.[Date] < @Bit
    ) AS belge_1001_eylul_tum_magaza,
    (
        SELECT COUNT(*)
        FROM EncoreMerkez.dbo.Sales AS s
        WHERE
            s.DocumentsTypeId IN (1, 3)
            AND s.[Date] >= DATEADD(MONTH, -12, @Bugun)
            AND s.[Date] < @Bugun
    ) AS belge_1_3_son12ay,
    (
        SELECT COUNT(*)
        FROM EncoreMerkez.dbo.Sales AS s
            INNER JOIN DerinCrm.dbo.Customer AS c ON s.CustomersId = c.Id
        WHERE
            s.DocumentsTypeId IN (1, 3)
            AND s.[Date] >= DATEADD(MONTH, -12, @Bugun)
            AND s.[Date] < @Bugun
            AND (
                c.Name LIKE N'%Mağaza%' COLLATE Turkish_CI_AS
                OR c.Name LIKE N'%Kumbara%' COLLATE Turkish_CI_AS
                OR ISNULL(c.PhoneNumber, '') LIKE '599%'
                OR ISNULL(c.PhoneNumber, '') LIKE '699%'
            )
    ) AS ic_kart_kurali_ile_dislanan_belge;
