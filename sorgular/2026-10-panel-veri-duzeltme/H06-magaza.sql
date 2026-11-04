-- ork:hedef-db EncoreMerkez
-- ork:compat 110
/* Soru     : Mağaza sayfasında indirim, iade ve UPT tek tabanda mı (iptal kalem indirimi dışarıda, iade KDV hariç, UPT kanonik fişte)?
   AC       : AC-6.1, AC-6.2, AC-6.3, AC-6.4 · Spec 001 · H06 · KR-1 (1001 iade ve fiş dışlaması)
   Dönem    : @Bas = 01.09.2026, @Bit = 01.10.2026 (bitiş hariç); @MekanId 1 FSM · 4477 Özlüce · 4478 İst.Yolu
   Tolerans : sayı birebir; tutar ≤ 1 TL
   Önce     : (04.10.2026, encore profili, --read-only; panel gövdeleri dosya dışı: T-010 ölçümü, MagazaQueries.cs :41 :58 :96;
              bloklar ONCE-IADE, ONCE-UPT, ONCE-KAMP, FSM; diğer mağazalar @MekanId değiştirilerek)
              ONCE-IADE (kpiSql :41, GrossTotal, KDV dahil, indirim düşülmemiş; 1001 hariç):
                FSM 1.330.198,93 · Özlüce 1.536.627,53 · İst.Yolu 6.841.660,75
              ONCE-UPT (uptSql :58, tipler 1,2,6,7,8; pay SUM(Amount), payda DISTINCT fiş):
                FSM 6,70 (289.716 / 43.258) · Özlüce 8,17 (398.009 / 48.690) · İst.Yolu 12,03 (449.856 / 37.407)
              ONCE-KAMP (ind CTE :96, IsValid süzgeci YOK, indirim = −TotalDiscount, Brüt = net + indirim, Ad'sız toplam):
                İndirim 12.605.327,63 · 16.302.187,31 · 328.136.559,76
                Brüt 35.871.177,32 · 47.920.498,87 · 609.633.923,26
                net (Ad bazlı toplam) 23.265.849,69 · 31.618.311,56 · 281.497.363,50
   Sonra    : yok (T-041..T-047 sonrası)
   Bağımsız : (04.10.2026) kampanya indirimi = −SalesProductCampaigns.DistributedAmount (satıra dağıtılmış, negatif işaretli);
              TotalDiscount (SalesId, CampaignId) grubuna çoğaltılmış toplamdır, KULLANILMAZ.
              A IptalKalemKampanyaIndirim: FSM 207.266,13 · Özlüce 299.018,54 · İst.Yolu 318.323,12
                (= Σ (DiscountTotalDirect + DiscountTotalIndirect) iptal kalemde, üç mağazada birebir; Indirect bu dönemde 0: ek dosya A1)
              A2 geçerli kalem kampanya indirimi (mağaza × tip) Σ: FSM 11.565.743,16 · Özlüce 15.881.640,16 · İst.Yolu 25.238.731,49
              A2 KAYNAK İÇİ KİMLİK (bağımsız kanıt değil): KampanyaIndirim = BaslikIndirim (Σ Sales.DiscountTotal), her mağaza × tip
                satırında fark 0,00 (13/13); ikisi de aynı Encore satışından gelir. Fark ≠ 0 ise A2 kırıktır.
              A3 (ek dosya, ERP posOzetUrun.satIndirim, bağımsız kaynak, yalnız büyüklük sınırı): A2'ye göre −%1,4 · −%1,8 · −%9,9;
                kuruş kimliği değil, kapsam farkı.
              B KampanyaliKalemNetKdvDahil: FSM 23.259.498,10 · Özlüce 31.613.583,78 · İst.Yolu 277.588.171,79
              C IadeKdvHaric (1001 hariç, indirim düşülmüş): FSM 995.170,57 · Özlüce 1.173.183,70 · İst.Yolu 6.234.866,80
              D (Kalem / Fis; tip 1, 1001 hariç): FSM 283.227 / 42.774 (UPT 6,62) · Özlüce 382.775 / 47.782 (UPT 8,01)
                · İst.Yolu 274.007 / 31.488 (UPT 8,70). Fis H05 blok A ile aynı.
              İade kimliği (1001 DAHİL): C1 Encore iade KDV hariç = C2 irsHrk ehTip 101:
                1.097.636,30 · 1.287.609,19 · 6.325.338,18; fark 0,00 üç mağazada.
   Fark     : (Önce − Bağımsız, ölçüldü 04.10.2026)
              İndirim: panel 12,6M / 16,3M / 328,1M ↔ A2 11,57M / 15,88M / 25,24M. Panel TotalDiscount toplar (çoğaltılmış),
                IsValid süzgeci yok.
              Net: panel Ad bazlı net − blok B = +6.351,59 · +4.727,78 · +3.909.191,71 = Σ TotalPrice × (kampanya adı sayısı − 1);
                aynı kalem her kampanyada bir kez sayılıyor.
              UPT: tip 1'e daraltılmış panel UPT'si (kalem düzeyi 1001) 6,62 · 8,01 · 8,70 = D; panel tipleriyle fiş düzeyi
                1001 dışlaması 6,70 · 8,17 · 12,03 = panel. Fark tamamen tip kümesinden (fatura, personel, Sınav); 1001 etkisi 0.
              İade: panel GrossTotal 1.330.198,93 − İndirim 286.552,88 − KDV 48.475,48 = C 995.170,57 (FSM; ek dosya IADE_ARA).
                Fark tamamen tabandan; 1001 ve tip etkisi 0.
   Nüfus    : (blok N, 04.10.2026) Eylül tüm mağaza: iptal kalem (tip 1,2,6,7,8) 16.692 · SPC satırı 542.136 · iade belgesi 4.956
              · satış fişi (tip 1) 122.045 · irsHrk 101 satırı (3 mağaza) 11.586.
              T-001 E (03.10): son 90 günde tekrarlı (SalesId, Sequence) kalem çifti 0.
   Aynı kaynak — neden: Kampanya ve kalem düzeyi yalnız Encore'da var; ERP'de POS özet belgedir. İade için ERP bağımsız kaynak (C1 ↔ C2).
              İndirim için bağımsız kanıt yalnız A3 (ERP, büyüklük sınırı); A2'de kalem
              (DistributedAmount) ↔ başlık (Sales.DiscountTotal) aynı Encore satışıdır, kaynak içi kimliktir.
              Yöntem: panelin LEFT JOIN spb yerine DISTINCT SalesId anti-join; UPT'de fiş kümesi önce.
   Başka ne olabilir: (1) TotalDiscount yerine DistributedAmount: ölçüldü, iptal kalemde Σ DistributedAmount = Σ (Direct + Indirect);
              TotalDiscount aynı kalemi kampanya sayısı kadar çoğaltıyor. (2) A ve B belge kapsamı
              panelle aynı (1,2,6,7,8), 1001 dışlamaz; 1001 yalnız iade ve UPT'de dışlanır. (3) D Fis kalemsiz fişi de sayar (H05 gibi).
              (4) DistributedAmount işareti negatif (A2 kimliğiyle doğrulandı).
   Kapsam   : Mağaza = Pos -> Stores -> posMagaza. İade = tip 3, 1001 hariç (KR-1); tutar Gross − Discount − Vat.
              Fiş (UPT) = tip 1, 1001 hariç. Kampanya kalemi = (SalesId, ProductSequence = Sequence).
   Dondurma : 18c2ce0
   SSMS     : DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104), @MekanId INT = 1;
   Komut    : sqlcli --read-only DECLARE kabul etmez; bloklar GO'suz, @Bas/@Bit/@MekanId literal; C2 --profile erp, diğerleri encore.
   Bloklar  : A iptal kalem kampanya indirimi · A2 mağaza × tip kampanya ↔ başlık indirimi · B kampanyalı kalem net (KDV dahil)
              · C iade KDV hariç · C1 kontrol Encore 1001 dahil · C2 kontrol ERP irsHrk 101 · D UPT (Kalem, Fis)
              · ONCE-IADE · ONCE-UPT · ONCE-KAMP (panel gövdeleri) · N nüfus.
              Ara ölçümler (A1 iptal kalem Direct/Indirect · A3 ERP indirim · IADE_ARA Brüt/İndirim/KDV · UPT_T1) ayrı dosyada:
              H06-magaza-ek.sql (20 KB sınırı).
              Boş nüfus 'bakamadım'dır, 'temiz' değil.
*/

-- blok: A  (iptal kaleme bağlı kampanya indirimi, DistributedAmount; @MekanId = 1 FSM)
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104), @MekanId INT = 1;  -- DMY

SELECT CONVERT(DECIMAL(18, 2), ISNULL(SUM(-spc.DistributedAmount), 0)) AS IptalKalemKampanyaIndirim
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

-- blok: A2  (geçerli kalem kampanya indirimi, mağaza × belge tipi; kimlik: Σ Sales.DiscountTotal; üç mağaza birden)
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104);  -- DMY

WITH Kume AS (
    SELECT
        s.Id,
        mg.mekanAd,
        s.DocumentsTypeId AS belge_tipi,
        s.DiscountTotal
    FROM EncoreMerkez.dbo.Sales AS s
        INNER JOIN EncoreMerkez.dbo.Pos AS p
            ON s.PosId = p.Id
        INNER JOIN EncoreMerkez.dbo.Stores AS st
            ON p.StoreId = st.Id
        INNER JOIN DerinSISBkm.dbo.posMagaza AS mg
            ON st.Code COLLATE Turkish_CI_AS = mg.mekanKod COLLATE Turkish_CI_AS
    WHERE
        mg.mekanID IN (1, 4477, 4478)
        AND s.DocumentsTypeId IN (1, 2, 6, 7, 8)
        AND s.[Date] >= @Bas
        AND s.[Date] < @Bit
),

Kamp AS (
    SELECT
        spc.SalesId,
        SUM(-spc.DistributedAmount) AS kampanya_indirim
    FROM EncoreMerkez.dbo.SalesProductCampaigns AS spc
        INNER JOIN EncoreMerkez.dbo.SalesProducts AS sp
            ON
                spc.SalesId = sp.SalesId
                AND spc.ProductSequence = sp.[Sequence]
        INNER JOIN Kume AS k
            ON spc.SalesId = k.Id
    WHERE sp.IsValid = 1
    GROUP BY spc.SalesId
)

SELECT
    k.mekanAd AS Magaza,
    k.belge_tipi AS Tip,
    CONVERT(DECIMAL(18, 2), SUM(ISNULL(ka.kampanya_indirim, 0))) AS KampanyaIndirim,
    CONVERT(DECIMAL(18, 2), SUM(k.DiscountTotal)) AS BaslikIndirim
FROM Kume AS k
    LEFT JOIN Kamp AS ka
        ON k.Id = ka.SalesId
GROUP BY k.mekanAd, k.belge_tipi
ORDER BY k.mekanAd, k.belge_tipi;
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
        INNER JOIN EncoreMerkez.dbo.Sales AS sg
            ON sp.SalesId = sg.Id
    WHERE
        sp.BarcodeNo = '1001'
        AND sg.[Date] >= @Bas
        AND sg.[Date] < @Bit
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
        INNER JOIN EncoreMerkez.dbo.Sales AS sg
            ON sp.SalesId = sg.Id
    WHERE
        sp.BarcodeNo = '1001'
        AND sg.[Date] >= @Bas
        AND sg.[Date] < @Bit
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

-- noqa: disable=all
-- blok: ONCE-IADE  (panel kpiSql :41 aynen; @mid → @MekanId, @start → @Bas, @end → @Bit; FSM; panel gövdesi, biçim kurallarından muaf)
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104), @MekanId INT = 1;  -- DMY

SELECT
    SUM(CASE WHEN s.DocumentsTypeId=3 THEN -1 ELSE 1 END*(s.GrossTotal-s.DiscountTotal-s.VatTotal)) AS Net,
    SUM(CASE WHEN s.DocumentsTypeId=3 THEN -1 ELSE 1 END)                                AS Fis,
    SUM(CASE WHEN s.DocumentsTypeId=3 THEN s.GrossTotal ELSE 0 END)                      AS Iade,
    CAST(100.0*SUM(CASE WHEN s.DocumentsTypeId=3 THEN s.GrossTotal ELSE 0 END)
       / NULLIF(SUM(CASE WHEN s.DocumentsTypeId IN(1,2,6,7,8) THEN s.GrossTotal ELSE 0 END),0) AS DECIMAL(10,1)) AS IadeOran
FROM EncoreMerkez.dbo.Sales s
JOIN EncoreMerkez.dbo.Pos p ON p.Id=s.PosId
JOIN EncoreMerkez.dbo.Stores st ON st.Id=p.StoreId
JOIN DerinSISBkm.dbo.posMagaza MG ON MG.mekanKod COLLATE Turkish_CI_AS=st.Code COLLATE Turkish_CI_AS
LEFT JOIN EncoreMerkez.dbo.SalesProducts spb ON spb.SalesId=s.Id AND spb.BarcodeNo='1001'
WHERE MG.mekanID=@MekanId AND s.DocumentsTypeId IN (1,2,3,6,7,8) AND spb.Id IS NULL
  AND s.[Date]>=@Bas AND s.[Date]<@Bit;
GO

-- blok: ONCE-UPT  (panel uptSql :58 aynen; pay ve payda ayrı kolon; FSM)
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104), @MekanId INT = 1;  -- DMY

SELECT
    SUM(sp.Amount) AS Pay,
    COUNT(DISTINCT s.Id) AS Payda,
    CAST(SUM(sp.Amount)/NULLIF(COUNT(DISTINCT s.Id),0) AS DECIMAL(10,2)) AS Upt
FROM EncoreMerkez.dbo.Sales s
JOIN EncoreMerkez.dbo.Pos p ON p.Id=s.PosId
JOIN EncoreMerkez.dbo.Stores st ON st.Id=p.StoreId
JOIN DerinSISBkm.dbo.posMagaza MG ON MG.mekanKod COLLATE Turkish_CI_AS=st.Code COLLATE Turkish_CI_AS
JOIN EncoreMerkez.dbo.SalesProducts sp ON sp.SalesId=s.Id AND sp.IsValid=1 AND sp.BarcodeNo<>'1001'
WHERE MG.mekanID=@MekanId AND s.DocumentsTypeId IN (1,2,6,7,8) AND s.[Date]>=@Bas AND s.[Date]<@Bit;
GO

-- blok: ONCE-KAMP  (panel kampSql :96 ind + net CTE'leri aynen; son SELECT Ad'sız toplam; FSM)
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104), @MekanId INT = 1;  -- DMY

WITH ind AS (
    SELECT CASE WHEN LTRIM(RTRIM(spc.CampaignName))='' THEN N'(manuel/kodsuz)' ELSE spc.CampaignName END AS Ad,
           CAST(SUM(-spc.TotalDiscount) AS DECIMAL(18,2)) AS Indirim
    FROM EncoreMerkez.dbo.SalesProductCampaigns spc
    JOIN EncoreMerkez.dbo.Sales s ON s.Id=spc.SalesId
    JOIN EncoreMerkez.dbo.Pos p ON p.Id=s.PosId
    JOIN EncoreMerkez.dbo.Stores st ON st.Id=p.StoreId
    JOIN DerinSISBkm.dbo.posMagaza MG ON MG.mekanKod COLLATE Turkish_CI_AS=st.Code COLLATE Turkish_CI_AS
    WHERE MG.mekanID=@MekanId AND s.DocumentsTypeId IN (1,2,6,7,8) AND s.[Date]>=@Bas AND s.[Date]<@Bit
    GROUP BY CASE WHEN LTRIM(RTRIM(spc.CampaignName))='' THEN N'(manuel/kodsuz)' ELSE spc.CampaignName END
),
net AS (
    SELECT Ad, CAST(SUM(TotalPrice) AS DECIMAL(18,2)) AS Net
    FROM (
        SELECT DISTINCT
               CASE WHEN LTRIM(RTRIM(spc.CampaignName))='' THEN N'(manuel/kodsuz)' ELSE spc.CampaignName END AS Ad,
               sp.SalesId, sp.[Sequence], sp.TotalPrice
        FROM EncoreMerkez.dbo.SalesProductCampaigns spc
        JOIN EncoreMerkez.dbo.SalesProducts sp ON sp.SalesId=spc.SalesId AND sp.[Sequence]=spc.ProductSequence AND sp.IsValid=1
        JOIN EncoreMerkez.dbo.Sales s ON s.Id=spc.SalesId
        JOIN EncoreMerkez.dbo.Pos p ON p.Id=s.PosId
        JOIN EncoreMerkez.dbo.Stores st ON st.Id=p.StoreId
        JOIN DerinSISBkm.dbo.posMagaza MG ON MG.mekanKod COLLATE Turkish_CI_AS=st.Code COLLATE Turkish_CI_AS
        WHERE MG.mekanID=@MekanId AND s.DocumentsTypeId IN (1,2,6,7,8) AND s.[Date]>=@Bas AND s.[Date]<@Bit
    ) d
    GROUP BY Ad
)
SELECT
    CAST(SUM(ind.Indirim) AS DECIMAL(18,2)) AS PanelIndirim,
    CAST(SUM(ISNULL(net.Net,0)+ind.Indirim) AS DECIMAL(18,2)) AS PanelBrut,
    CAST(SUM(ISNULL(net.Net,0)) AS DECIMAL(18,2)) AS PanelNetAdBazli
FROM ind
LEFT JOIN net ON net.Ad=ind.Ad;
GO
-- noqa: enable=all

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
