-- ork:hedef-db EncoreMerkez
-- ork:compat 110
/* Soru     : Kumbara ve manuel indirim fişleri brüt ve indirimde fiş başına bir kez mi sayılıyor?
   AC       : AC-1.1, AC-1.2, AC-1.3 · Spec 001 · H01
   Dönem    : 01.09.2026 – 30.09.2026 (bitiş hariç 01.10.2026)
   Tolerans : Σ Brut ve Σ Indirim ≤ 1,00 TL; fiş sayısı birebir
   Önce     : RefQueries.GetKumbaraAsync/GetManuelIndirimAsync SQL'i, Eylül 2026, 3 mağaza (sqlcli, 04.10.2026, ayrı 'önce' koşusu):
              Kumbara Brut 6.106.723,80 · Kumbara Indirim 237.219,16 · Kumbara fiş 7 · manuel Indirim (Type=1, tüm sebepler) 519.987.913,87
   Sonra    : yok (düzeltme T-0xx sonrası ölçülür)
   Bağımsız : A: Σ Brut 223.717,80 (İst.Yolu 216.357,00 · Özlüce 7.360,80 · FSM satırı yok) ·
              B: Kumbara Σ Indirim 10.546,86 · manuel sebepler Σ Indirim 20.238.232,67 (34 satır; (sebep, fiş) tekil, sebepler arası toplam
              fiş tekil toplamını aşabilir) · C: 0 satır (04.10.2026, sqlcli encore profili, --read-only)
   Aynı kaynak — neden: Kumbara/manuel bağı (SalesProductCampaigns.CampaignVersion = RefundReasons.Id, CampaignId IS NULL)
              yalnız Encore'da var; ERP'de karşılığı yok, bu yüzden kaynak bağımsız değil, yöntem bağımsız
              (önce fiş kümesi tekilleştirilir, tutar başlıktan bir kez alınır).
   Başka ne olabilir: (1) iki sebepli fiş her sebepte bir kez sayıldığı için sebepler arası toplam fiş tekil toplamını
              aşabilir (beklenen, hata değil); (2) Kumbara (Id 17) aynı zamanda Type=1 olduğundan manuel listede de
              görünür, B'de iki ayrı satır grubu olarak (Sebep = Kumbara ve sebep adı) çıkar, ikisi toplanmaz;
              (3) 1001 geri dönüşüm satırları iade belgelerinde yoğun (T-001) ama bu bağ kampanya kalemine dayandığı
              için fiş kümesinde 1001 dışlaması yapılmadı.
   Kapsam   : DocumentsTypeId IN (1,2,3,6,7,8), iade (3) negatif; mağaza = Pos.StoreId → Stores.Code = posMagaza.mekanKod
              (COLLATE), mekanID IN (1,4477,4478); kalem SalesProducts.IsValid = 1; (SalesId, ProductSequence) =
              (SalesId, [Sequence]); Brut = Sales.GrossTotal, Indirim = Sales.DiscountTotal (başlıktan bir kez).
   Dondurma : e1a0a78
   SSMS     : DECLARE @Bas datetime = CONVERT(datetime, '01.09.2026', 104), @Bit datetime = CONVERT(datetime, '01.10.2026', 104);
   Komut    : sqlcli --param ISO tarih ister; bu yüzden her blok literal tarihle koşuldu (SSMS DECLARE esas).
   Bloklar  : A Kumbara brüt (Magaza, Brut) · B indirim (Sebep, Magaza, Indirim) · C iadeli fiş (Magaza, IadeliFis, IadeBrut, IadeIndirim)
              C: iade belgeleri (DocumentsTypeId = 3) mutlak değer; A/B içinde zaten negatif düşülmüştür.
   AC-1.3   : AC-1.3 nüfus 0 — KOŞAMADI beklenir (Eylül 2026'da iadeli Kumbara/manuel fiş yok; mağaza süzgeci olmadan da 0 ölçüldü)
*/

-- blok: A  (Kumbara brüt, fiş başına bir kez)
DECLARE @Bas datetime = CONVERT(datetime, '01.09.2026', 104);  -- DMY
DECLARE @Bit datetime = CONVERT(datetime, '01.10.2026', 104);  -- DMY

WITH KumbaraFis AS (
    SELECT DISTINCT s.Id AS fis_id
    FROM EncoreMerkez.dbo.Sales AS s
        INNER JOIN EncoreMerkez.dbo.SalesProducts AS sp
            ON
                s.Id = sp.SalesId
                AND sp.IsValid = 1
        INNER JOIN EncoreMerkez.dbo.SalesProductCampaigns AS spc
            ON
                sp.SalesId = spc.SalesId
                AND sp.[Sequence] = spc.ProductSequence
                AND spc.CampaignId IS NULL
        INNER JOIN EncoreMerkez.dbo.RefundReasons AS rr
            ON
                spc.CampaignVersion = rr.Id
                AND rr.Id = 17
    WHERE
        s.[Date] >= @Bas
        AND s.[Date] < @Bit
        AND s.DocumentsTypeId IN (1, 2, 3, 6, 7, 8)
)

SELECT
    st.Name AS Magaza,
    SUM(CASE WHEN s.DocumentsTypeId = 3 THEN -s.GrossTotal ELSE s.GrossTotal END) AS Brut
FROM KumbaraFis AS kf
    INNER JOIN EncoreMerkez.dbo.Sales AS s
        ON kf.fis_id = s.Id
    INNER JOIN EncoreMerkez.dbo.Pos AS ps
        ON s.PosId = ps.Id
    INNER JOIN EncoreMerkez.dbo.Stores AS st
        ON ps.StoreId = st.Id
    INNER JOIN DerinSISBkm.dbo.posMagaza AS mg
        ON
            mg.mekanKod COLLATE Turkish_CI_AS = st.Code COLLATE Turkish_CI_AS
            AND mg.mekanID IN (1, 4477, 4478)
GROUP BY st.Name
ORDER BY st.Name;

-- blok: B  (indirim; Kumbara ve manuel sebepler, her (sebep, fiş) bir kez)
DECLARE @Bas datetime = CONVERT(datetime, '01.09.2026', 104);  -- DMY
DECLARE @Bit datetime = CONVERT(datetime, '01.10.2026', 104);  -- DMY

WITH SebepFis AS (
    SELECT DISTINCT
        CASE WHEN rr.Id = 17 THEN N'Kumbara' ELSE rr.Name END AS sebep_adi,
        s.Id AS fis_id
    FROM EncoreMerkez.dbo.Sales AS s
        INNER JOIN EncoreMerkez.dbo.SalesProducts AS sp
            ON
                s.Id = sp.SalesId
                AND sp.IsValid = 1
        INNER JOIN EncoreMerkez.dbo.SalesProductCampaigns AS spc
            ON
                sp.SalesId = spc.SalesId
                AND sp.[Sequence] = spc.ProductSequence
                AND spc.CampaignId IS NULL
        INNER JOIN EncoreMerkez.dbo.RefundReasons AS rr
            ON
                spc.CampaignVersion = rr.Id
                AND rr.Id = 17
    WHERE
        s.[Date] >= @Bas
        AND s.[Date] < @Bit
        AND s.DocumentsTypeId IN (1, 2, 3, 6, 7, 8)
    UNION
    SELECT DISTINCT
        rr.Name AS sebep_adi,
        s.Id AS fis_id
    FROM EncoreMerkez.dbo.Sales AS s
        INNER JOIN EncoreMerkez.dbo.SalesProducts AS sp
            ON
                s.Id = sp.SalesId
                AND sp.IsValid = 1
        INNER JOIN EncoreMerkez.dbo.SalesProductCampaigns AS spc
            ON
                sp.SalesId = spc.SalesId
                AND sp.[Sequence] = spc.ProductSequence
                AND spc.CampaignId IS NULL
        INNER JOIN EncoreMerkez.dbo.RefundReasons AS rr
            ON
                spc.CampaignVersion = rr.Id
                AND rr.Type = 1
    WHERE
        s.[Date] >= @Bas
        AND s.[Date] < @Bit
        AND s.DocumentsTypeId IN (1, 2, 3, 6, 7, 8)
)

SELECT
    sf.sebep_adi AS Sebep,
    st.Name AS Magaza,
    SUM(CASE WHEN s.DocumentsTypeId = 3 THEN -s.DiscountTotal ELSE s.DiscountTotal END) AS Indirim
FROM SebepFis AS sf
    INNER JOIN EncoreMerkez.dbo.Sales AS s
        ON sf.fis_id = s.Id
    INNER JOIN EncoreMerkez.dbo.Pos AS ps
        ON s.PosId = ps.Id
    INNER JOIN EncoreMerkez.dbo.Stores AS st
        ON ps.StoreId = st.Id
    INNER JOIN DerinSISBkm.dbo.posMagaza AS mg
        ON
            mg.mekanKod COLLATE Turkish_CI_AS = st.Code COLLATE Turkish_CI_AS
            AND mg.mekanID IN (1, 4477, 4478)
GROUP BY sf.sebep_adi, st.Name
ORDER BY sf.sebep_adi, st.Name;

-- blok: C  (iadeli Kumbara/manuel fiş; tutarlar mutlak değer)
DECLARE @Bas datetime = CONVERT(datetime, '01.09.2026', 104);  -- DMY
DECLARE @Bit datetime = CONVERT(datetime, '01.10.2026', 104);  -- DMY

WITH IadeFis AS (
    SELECT DISTINCT s.Id AS fis_id
    FROM EncoreMerkez.dbo.Sales AS s
        INNER JOIN EncoreMerkez.dbo.SalesProducts AS sp
            ON
                s.Id = sp.SalesId
                AND sp.IsValid = 1
        INNER JOIN EncoreMerkez.dbo.SalesProductCampaigns AS spc
            ON
                sp.SalesId = spc.SalesId
                AND sp.[Sequence] = spc.ProductSequence
                AND spc.CampaignId IS NULL
        INNER JOIN EncoreMerkez.dbo.RefundReasons AS rr
            ON
                spc.CampaignVersion = rr.Id
                AND rr.Type = 1
    WHERE
        s.[Date] >= @Bas
        AND s.[Date] < @Bit
        AND s.DocumentsTypeId = 3
)

SELECT
    st.Name AS Magaza,
    COUNT(*) AS IadeliFis,
    SUM(s.GrossTotal) AS IadeBrut,
    SUM(s.DiscountTotal) AS IadeIndirim
FROM IadeFis AS i
    INNER JOIN EncoreMerkez.dbo.Sales AS s
        ON i.fis_id = s.Id
    INNER JOIN EncoreMerkez.dbo.Pos AS ps
        ON s.PosId = ps.Id
    INNER JOIN EncoreMerkez.dbo.Stores AS st
        ON ps.StoreId = st.Id
    INNER JOIN DerinSISBkm.dbo.posMagaza AS mg
        ON
            mg.mekanKod COLLATE Turkish_CI_AS = st.Code COLLATE Turkish_CI_AS
            AND mg.mekanID IN (1, 4477, 4478)
GROUP BY st.Name
ORDER BY st.Name;
