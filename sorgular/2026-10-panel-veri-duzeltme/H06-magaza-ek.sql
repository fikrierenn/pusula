-- ork:hedef-db EncoreMerkez
-- ork:compat 110
/* Soru     : H06-magaza.sql'in ara ölçümleri: iptal kalem indirimi Direct+Indirect, iade ara kalemleri, ERP indirim büyüklüğü,
              UPT'nin tip 1'e daraltılmış panel biçimi. Ana dosya: H06-magaza.sql (başlıktaki sayılar buraya ve oraya atıf yapar).
   AC       : AC-6.1, AC-6.2, AC-6.3 · Spec 001 · H06 · T-019 düzeltme geçişi
   Dönem    : @Bas = 01.09.2026, @Bit = 01.10.2026 (bitiş hariç); üç mağaza birden (mekanID 1, 4477, 4478)
   Tolerans : A1: Direct + Indirect = H06 blok A (≤ 1 TL) · IADE_ARA: Brüt − İndirim − KDV = H06 blok C (≤ 1 TL)
   Önce     : yok (ara ölçüm dosyası; panel gövdeleri H06-magaza.sql ONCE-* bloklarında)
   Sonra    : yok
   Bağımsız : (04.10.2026, ölçüldü)
              A1 iptal kalem (IsValid = 0, tip 1,2,6,7,8): Direct 207.266,13 · 299.018,54 · 318.323,12; Indirect 0,00 · 0,00 · 0,00;
                Toplam (Direct + Indirect, T-017 kuralı) aynı; H06 blok A DistributedAmount toplamıyla birebir.
              A3 ERP posOzetUrun.satIndirim Σ: 11.403.710,95 · 15.591.396,63 · 22.736.718,31; H06 blok A2 geçerli kalem kampanya
                indirimine göre −%1,4 · −%1,8 · −%9,9. Büyüklük sınırıdır, kuruş kimliği değil: ERP satış özeti ile Encore belge
                tipleri (1,2,6,7,8) aynı kapsam değildir; farkın sebebi ölçülmedi. A3 iadeIndirim: 286.552,88 · 295.745,46 · 471.681,44;
                IADE_ARA İndirim (286.552,88 · 295.745,46 · 471.681,44) ile üç mağazada birebir.
              IADE_ARA iade (tip 3, 1001 hariç): Brüt 1.330.198,93 · 1.536.627,53 · 6.841.660,75; İndirim 286.552,88 · 295.745,46 ·
              471.681,44;
                KDV 48.475,48 · 67.698,37 · 135.112,51; Net 995.170,57 · 1.173.183,70 · 6.234.866,80 (= H06 blok C).
              UPT_T1 panel biçimi (kalem düzeyi 1001, yalnız tip 1): 6,62 · 8,01 · 8,70 (H06 blok D ile aynı). Payda FSM 42.774 ·
                Özlüce 47.780 · İst.Yolu 31.488; Özlüce H05 Fis 47.782'den 2 eksik (kalemi olmayan veya yalnız iptal kalemli 2 fiş).
   Nüfus    : yok (H06-magaza.sql blok N geçerli).
   Aynı kaynak — neden: A1, IADE_ARA ve UPT_T1 Encore içinde kendi ana dosyasındaki bloğun kırılımıdır (kaynak içi kimlik,
              bağımsız kanıt değil). Bağımsız kaynak yalnız A3'tür (ERP posOzetUrun) ve büyüklük sınırı verir.
   Başka ne olabilir: (1) A1 Indirect 0 ise Direct + Indirect ayrımı bu dönemde sonucu değiştirmez; başka dönemde Indirect
              dolu olabilir, kapı o yüzden iki kolonu birlikte toplar. (2) A3 farkı kapsamdan (Sınav, fatura, personel) gelebilir.
   Kapsam   : Mağaza = Pos -> Stores -> posMagaza. İade 1001 hariç (KR-1).
   Dondurma : 18c2ce0
   SSMS     : DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104);
   Komut    : sqlcli --read-only DECLARE kabul etmez; literal tarihle koşuldu. A3 --profile erp, diğerleri --profile encore.
   Bloklar  : A1 iptal kalem Direct/Indirect · A3 ERP indirim büyüklüğü · IADE_ARA iade brüt/indirim/KDV · UPT_T1 (panel gövdesi, tip 1)
*/

-- blok: A1  (iptal kalem indirimi: Direct, Indirect, toplam; üç mağaza)
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104);  -- DMY

SELECT
    mg.mekanID AS Mekan,
    CONVERT(DECIMAL(18, 2), SUM(sp.DiscountTotalDirect)) AS Direct,
    CONVERT(DECIMAL(18, 2), SUM(sp.DiscountTotalIndirect)) AS Indirect,
    CONVERT(DECIMAL(18, 2), SUM(sp.DiscountTotalDirect + sp.DiscountTotalIndirect)) AS Toplam
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
    sp.IsValid = 0
    AND mg.mekanID IN (1, 4477, 4478)
    AND s.DocumentsTypeId IN (1, 2, 6, 7, 8)
    AND s.[Date] >= @Bas
    AND s.[Date] < @Bit
GROUP BY mg.mekanID
ORDER BY mg.mekanID;
GO

-- blok: A3  (ERP büyüklük sınırı: posOzetUrun satış ve iade indirimi; --profile erp)
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104);  -- DMY

SELECT
    o.posMekan AS Mekan,
    CONVERT(DECIMAL(18, 2), SUM(o.satIndirim)) AS ErpSatIndirim,
    CONVERT(DECIMAL(18, 2), SUM(o.iadeIndirim)) AS ErpIadeIndirim
FROM DerinSISBkm.dbo.posOzetUrun AS o
WHERE
    o.posMekan IN (1, 4477, 4478)
    AND o.posTarih >= @Bas
    AND o.posTarih < @Bit
GROUP BY o.posMekan
ORDER BY o.posMekan;
GO

-- blok: IADE_ARA  (iade brüt, indirim, KDV; tip 3, 1001 hariç; üç mağaza)
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
    mg.mekanID AS Mekan,
    CONVERT(DECIMAL(18, 2), SUM(s.GrossTotal)) AS Brut,
    CONVERT(DECIMAL(18, 2), SUM(s.DiscountTotal)) AS Indirim,
    CONVERT(DECIMAL(18, 2), SUM(s.VatTotal)) AS Kdv,
    CONVERT(DECIMAL(18, 2), SUM(s.GrossTotal - s.DiscountTotal - s.VatTotal)) AS Net
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
    AND s.DocumentsTypeId = 3
    AND gd.SalesId IS NULL
    AND s.[Date] >= @Bas
    AND s.[Date] < @Bit
GROUP BY mg.mekanID
ORDER BY mg.mekanID;
GO

-- noqa: disable=all
-- blok: UPT_T1  (panel uptSql gövdesi, belge tipi yalnız 1; kalem düzeyi 1001 dışlaması; üç mağaza)
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104);  -- DMY

SELECT
    MG.mekanID AS Mekan,
    SUM(sp.Amount) AS Pay,
    COUNT(DISTINCT s.Id) AS Payda,
    CAST(SUM(sp.Amount)/NULLIF(COUNT(DISTINCT s.Id),0) AS DECIMAL(10,2)) AS Upt
FROM EncoreMerkez.dbo.Sales s
JOIN EncoreMerkez.dbo.Pos p ON p.Id=s.PosId
JOIN EncoreMerkez.dbo.Stores st ON st.Id=p.StoreId
JOIN DerinSISBkm.dbo.posMagaza MG ON MG.mekanKod COLLATE Turkish_CI_AS=st.Code COLLATE Turkish_CI_AS
JOIN EncoreMerkez.dbo.SalesProducts sp ON sp.SalesId=s.Id AND sp.IsValid=1 AND sp.BarcodeNo<>'1001'
WHERE MG.mekanID IN (1,4477,4478) AND s.DocumentsTypeId=1 AND s.[Date]>=@Bas AND s.[Date]<@Bit
GROUP BY MG.mekanID
ORDER BY MG.mekanID;
GO
-- noqa: enable=all
