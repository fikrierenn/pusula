-- ork:hedef-db EncoreMerkez
-- ork:compat 110
/* Soru     : Mağaza sayfasında indirim, iade ve UPT tek tabanda mı (iptal kalem indirimi dışarıda, iade KDV hariç, UPT yalnız
              kanonik fişte)?
   AC       : AC-6.1, AC-6.2, AC-6.3, AC-6.4 · Spec 001 · H06 · KR-1 (1001 iade ve fiş dışlaması)
   Dönem    : @Bas = 01.09.2026, @Bit = 01.10.2026 (bitiş hariç); @MekanId 1 FSM · 4477 Özlüce · 4478 İst.Yolu
   Tolerans : sayı birebir; tutar ≤ 1 TL
   Önce     : (04.10.2026, sqlcli encore profili, --read-only; panel SQL'i MagazaQueries.cs GetDetayAsync, aynı dönem, koşulmuş)
              Iade (kpiSql :41, GrossTotal, KDV dahil, indirim düşülmemiş; 1001 hariç): FSM 1.330.198,93 · Özlüce 1.536.627,53 ·
              İst.Yolu 6.841.660,75
              UPT (uptSql :58, tipler 1,2,6,7,8; kalem sp.Amount, fiş DISTINCT, 1001 yalnız kalem düzeyinde): FSM 6,70 (289.716 / 43.258)
                · Özlüce 8,17 (398.009 / 48.690) · İst.Yolu 12,03 (449.856 / 37.407)
              Kampanya (ind CTE :96, IsValid süzgeci YOK; net CTE IsValid=1; Brüt = net + indirim; tipler 1,2,6,7,8):
                İndirim FSM 12.605.327,63 · Özlüce 16.302.187,31 · İst.Yolu 328.136.559,76
                Brüt 35.871.177,32 · 47.920.498,87 · 609.633.923,26 ; net (Ad bazlı toplam) 23.265.849,69 · 31.618.311,56 · 281.497.363,50
   Sonra    : yok (düzeltme T-041..T-047 sonrası ölçülür)
   Bağımsız : (04.10.2026) A IptalKalemKampanyaIndirim: FSM 175.375,56 · Özlüce 275.638,94 · İst.Yolu 313.059,34
              B KampanyaliKalemNetKdvDahil: FSM 23.259.498,10 · Özlüce 31.613.583,78 · İst.Yolu 277.588.171,79
              C IadeKdvHaric (1001 hariç, indirim düşülmüş): FSM 995.170,57 · Özlüce 1.173.183,70 · İst.Yolu 6.234.866,80
              D (Kalem, Fis; tip 1, 1001 hariç): FSM 283.227 · 42.774 (UPT 6,62) · Özlüce 382.775 · 47.782 (UPT 8,01) · İst.Yolu
              274.007 · 31.488 (UPT 8,70)
              Fark (Önce − Bağımsız): iade FSM +335.028,36 (GrossTotal tabanı); panel B tabanı (net Ad bazlı) − blok B: FSM
              +6.351,59 · Özlüce +4.727,78 · İst.Yolu +3.909.191,71
                (kalem birden fazla kampanyada ise Ad bazlı net onu her kampanyada bir kez sayıyor; blok B kalemi bir kez sayar)
              İade kimliği (KR-1 dışı, 1001 DAHİL): C1 Encore iade KDV hariç 1.097.636,30 · 1.287.609,19 · 6.325.338,18
                = C2 ERP irsHrk ehTip 101 (ehAltDepo 0) 1.097.636,30 · 1.287.609,19 · 6.325.338,18 → fark 0,00 üç mağazada
              (kuruşu kuruşuna)
              D Fis, H05 blok A ile aynı (42.774 · 47.782 · 31.488).
   Nüfus    : (blok N, 04.10.2026) Eylül tüm mağaza: iptal kalem (tip 1,2,6,7,8) 16.692 · SPC satırı 542.136 · iade belgesi 4.956
              · satış fişi (tip 1) 122.045 · irsHrk 101 satırı (3 mağaza) 11.586. T-001 E (03.10): son 90 günde (SalesId,
              Sequence) tekrarlı kalem çifti 0.
   Aynı kaynak — neden: Kampanya ve kalem düzeyi yalnız Encore'da var; ERP'de POS özet belgedir (kalem/kampanya üretilemez). İade
              için ERP bağımsız kaynaktır: C1 ↔ C2 kimliği 1001 DAHİL toplamla kurulur, C (1001 hariç) bu kimliğin alt kümesidir.
              Yöntem bağımsız: panelin LEFT JOIN spb yerine DISTINCT SalesId anti-join; UPT'de panelin kalem JOIN'i yerine fiş
              kümesi önce kurulur.
   Başka ne olabilir: (1) SPC tarafında aynı (SalesId, ProductSequence) için çok satır (T-005: 5'e kadar) meşru çoklu kampanyadır; blok A
              her SPC satırını toplar (indirim satır başına doğru), blok B kalemi EXISTS ile bir kez toplar. (2) Blok A/B belge
              kapsamı panelle aynı
              (1,2,6,7,8; iade hariç) ve 1001 dışlamaz; 1001 yalnız iade ve UPT'de dışlanır. (3) Blok D Fis tüm kanonik fişi sayar (kalemi
              olmayan fiş dahil), H05 ile aynı; ayrı ölçülmedi. (4) Önce UPT'deki fark tek sebepten değil: tipler (1,2,6,7,8 ↔ 1)
              ve 1001 dışlamasının
              kalem/fiş düzeyi birlikte etkiler; ayrıştırılmadı. (5) İade farkı 1001 hariç/dahil ve GrossTotal/net tabanından;
              ikisi ayrı ölçülmedi.
   Kapsam   : Mağaza = Pos -> Stores -> posMagaza. İade = DocumentsTypeId 3, 1001 barkodlu belge hariç (KR-1); tutar GrossTotal −
              DiscountTotal − VatTotal.
              Fiş (UPT) = DocumentsTypeId 1, 1001 hariç. Kampanya kalemi = (SalesId, ProductSequence = Sequence).
   Dondurma : 47e7030
   SSMS     : DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104), @MekanId INT = 1;
   Komut    : sqlcli --read-only DECLARE kabul etmez; bloklar GO'suz ve DECLARE'siz, @Bas/@Bit/@MekanId literalle değiştirilerek koşuldu
              (SSMS DECLARE + GO esas); C2 --profile erp, diğerleri --profile encore, --max-rows 1000.
   Bloklar  : A iptal kalem kampanya indirimi · B kampanyalı kalem net (KDV dahil) · C iade KDV hariç · C1 kontrol Encore 1001 dahil
              · C2 kontrol ERP irsHrk 101 · D UPT (Kalem, Fis) · N nüfus. Boş nüfus 'bakamadım'dır, 'temiz' değil.
*/

-- blok: A  (iptal kaleme bağlı kampanya indirimi; @MekanId = 1 FSM)
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104), @MekanId INT = 1;  -- DMY

SELECT CONVERT(DECIMAL(18, 2), ISNULL(SUM(-spc.TotalDiscount), 0)) AS IptalKalemKampanyaIndirim
FROM EncoreMerkez.dbo.SalesProductCampaigns AS spc
    INNER JOIN EncoreMerkez.dbo.SalesProducts AS sp
        ON
            spc.SalesId = sp.SalesId
            AND spc.ProductSequence = sp.[Sequence]
    INNER JOIN EncoreMerkez.dbo.Sales AS s
        ON spc.SalesId = s.Id
    INNER JOIN EncoreMerkez.dbo.Pos AS p
        ON s.PosId = p.Id
    INNER JOIN EncoreMerkez.dbo.Stores AS st
        ON p.StoreId = st.Id
    INNER JOIN DerinSISBkm.dbo.posMagaza AS mg
        ON st.Code COLLATE Turkish_CI_AS = mg.mekanKod COLLATE Turkish_CI_AS
WHERE
    sp.IsValid = 0
    AND mg.mekanID = @MekanId
    AND s.DocumentsTypeId IN (1, 2, 6, 7, 8)
    AND s.[Date] >= @Bas
    AND s.[Date] < @Bit;
GO

-- blok: B  (geçerli kampanyalı kalemlerin net satışı, KDV dahil; kalem bir kez; @MekanId = 1 FSM)
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104), @MekanId INT = 1;  -- DMY

SELECT CONVERT(DECIMAL(18, 2), ISNULL(SUM(sp.TotalPrice), 0)) AS KampanyaliKalemNetKdvDahil
FROM EncoreMerkez.dbo.SalesProducts AS sp
    INNER JOIN EncoreMerkez.dbo.Sales AS s
        ON sp.SalesId = s.Id
    INNER JOIN EncoreMerkez.dbo.Pos AS p
        ON s.PosId = p.Id
    INNER JOIN EncoreMerkez.dbo.Stores AS st
        ON p.StoreId = st.Id
    INNER JOIN DerinSISBkm.dbo.posMagaza AS mg
        ON st.Code COLLATE Turkish_CI_AS = mg.mekanKod COLLATE Turkish_CI_AS
WHERE
    sp.IsValid = 1
    AND mg.mekanID = @MekanId
    AND s.DocumentsTypeId IN (1, 2, 6, 7, 8)
    AND s.[Date] >= @Bas
    AND s.[Date] < @Bit
    AND EXISTS (   -- SPC tarafı tekilleştirilir: kalem en fazla bir kez toplanır
        SELECT 1
        FROM EncoreMerkez.dbo.SalesProductCampaigns AS spc
        WHERE
            spc.SalesId = sp.SalesId
            AND spc.ProductSequence = sp.[Sequence]
    );
GO

-- blok: C  (iade, KDV hariç, indirim düşülmüş, 1001 hariç; @MekanId = 1 FSM)
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104), @MekanId INT = 1;  -- DMY

WITH Gd AS (
    SELECT DISTINCT sp.SalesId
    FROM EncoreMerkez.dbo.SalesProducts AS sp   -- 1001 tespiti IsValid'e bakmaz (plan K-B)
    WHERE sp.BarcodeNo = '1001'
)

SELECT CONVERT(DECIMAL(18, 2), ISNULL(SUM(s.GrossTotal - s.DiscountTotal - s.VatTotal), 0)) AS IadeKdvHaric
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

-- blok: C1  (kontrol: iade, 1001 DAHİL, aynı taban; ehTip 101 kimliği için; @MekanId = 1 FSM)
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104), @MekanId INT = 1;  -- DMY

SELECT CONVERT(DECIMAL(18, 2), ISNULL(SUM(s.GrossTotal - s.DiscountTotal - s.VatTotal), 0)) AS IadeKdvHaricBinBirDahil
FROM EncoreMerkez.dbo.Sales AS s
    INNER JOIN EncoreMerkez.dbo.Pos AS p
        ON s.PosId = p.Id
    INNER JOIN EncoreMerkez.dbo.Stores AS st
        ON p.StoreId = st.Id
    INNER JOIN DerinSISBkm.dbo.posMagaza AS mg
        ON st.Code COLLATE Turkish_CI_AS = mg.mekanKod COLLATE Turkish_CI_AS
WHERE
    mg.mekanID = @MekanId
    AND s.DocumentsTypeId = 3
    AND s.[Date] >= @Bas
    AND s.[Date] < @Bit;
GO

-- blok: C2  (kontrol: ERP defteri iade, irsHrk ehTip = 101; @MekanId = 1 FSM)
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104), @MekanId INT = 1;  -- DMY

SELECT CONVERT(DECIMAL(18, 2), ISNULL(SUM(h.ehTutarN), 0)) AS Irs101
FROM DerinSISBkm.dbo.irsHrk AS h
WHERE
    h.ehTip = 101
    AND h.ehMekan = @MekanId
    AND h.ehAltDepo = 0
    AND h.ehTrhS >= @Bas
    AND h.ehTrhS < @Bit;
GO

-- blok: D  (UPT payı ve paydası; yalnız kanonik fiş: tip 1, 1001 hariç; @MekanId = 1 FSM)
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104), @MekanId INT = 1;  -- DMY

WITH Gd AS (
    SELECT DISTINCT sp.SalesId
    FROM EncoreMerkez.dbo.SalesProducts AS sp   -- 1001 tespiti IsValid'e bakmaz (plan K-B)
    WHERE sp.BarcodeNo = '1001'
),

Fisler AS (
    SELECT s.Id
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
        AND s.[Date] < @Bit
)

SELECT
    CONVERT(DECIMAL(18, 2), ISNULL((
        SELECT SUM(sp.Amount)
        FROM EncoreMerkez.dbo.SalesProducts AS sp
            INNER JOIN Fisler AS f
                ON sp.SalesId = f.Id
        WHERE sp.IsValid = 1
    ), 0)) AS Kalem,
    (SELECT COUNT(*) FROM Fisler) AS Fis;
GO

-- blok: N  (nüfus: tek satır; Eylül 2026)
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104);  -- DMY

SELECT
    (
        SELECT COUNT(*)
        FROM EncoreMerkez.dbo.SalesProducts AS sp
            INNER JOIN EncoreMerkez.dbo.Sales AS s ON sp.SalesId = s.Id
        WHERE sp.IsValid = 0 AND s.DocumentsTypeId IN (1, 2, 6, 7, 8) AND s.[Date] >= @Bas AND s.[Date] < @Bit
    ) AS iptal_kalem_eylul_tum_magaza,
    (
        SELECT COUNT(*)
        FROM EncoreMerkez.dbo.SalesProductCampaigns AS spc
            INNER JOIN EncoreMerkez.dbo.Sales AS s ON spc.SalesId = s.Id
        WHERE s.DocumentsTypeId IN (1, 2, 6, 7, 8) AND s.[Date] >= @Bas AND s.[Date] < @Bit
    ) AS spc_satir_eylul_tum_magaza,
    (
        SELECT COUNT(*)
        FROM EncoreMerkez.dbo.Sales AS s
        WHERE s.DocumentsTypeId = 3 AND s.[Date] >= @Bas AND s.[Date] < @Bit
    ) AS iade_belge_eylul_tum_magaza,
    (
        SELECT COUNT(*)
        FROM DerinSISBkm.dbo.irsHrk AS h
        WHERE h.ehTip = 101 AND h.ehMekan IN (1, 4477, 4478) AND h.ehAltDepo = 0 AND h.ehTrhS >= @Bas AND h.ehTrhS < @Bit
    ) AS irs101_satir_eylul_uc_magaza,
    (
        SELECT COUNT(*)
        FROM EncoreMerkez.dbo.Sales AS s
        WHERE s.DocumentsTypeId = 1 AND s.[Date] >= @Bas AND s.[Date] < @Bit
    ) AS satis_fisi_eylul_tum_magaza;
