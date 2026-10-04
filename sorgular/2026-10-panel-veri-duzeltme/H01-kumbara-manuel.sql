-- ork:hedef-db EncoreMerkez
-- ork:compat 110
/* Soru     : Kumbara ve manuel indirim fişleri brüt ve indirimde fiş başına bir kez mi sayılıyor?
   AC       : AC-1.1, AC-1.2, AC-1.3 · Spec 001 · H01
   Dönem    : 01.09.2026 – 30.09.2026 (bitiş hariç 01.10.2026)
   Tolerans : Σ Brut ve Σ Indirim ≤ 1,00 TL; fiş sayısı birebir
   Önce     : RefQueries.GetKumbaraAsync/GetManuelIndirimAsync SQL'i, Eylül 2026, 3 mağaza (sqlcli, 04.10.2026, ayrı 'önce' koşusu).
              Dosya dışı: T-005 ölçümü (defter, 04.10.2026); panel SQL'i bu dosyada yok, blok olarak yeniden koşulamaz:
              Kumbara Brut 6.106.723,80 · Kumbara Indirim 237.219,16 · Kumbara fiş 7 · manuel Indirim (Type=1, tüm sebepler) 519.987.913,87
   Sonra    : yok (düzeltme T-0xx sonrası ölçülür)
   Bağımsız : (04.10.2026, sqlcli encore profili, --read-only; A–C bu dosyadaki bloklardır, yöntem bağımsız, kaynak aynı)
              A  : Σ Brut 223.717,80 (İst.Yolu 216.357,00 · Özlüce 7.360,80 · FSM satırı yok)
              B  : Kumbara Σ Indirim 10.546,86 · manuel sebepler (Sebep <> Kumbara) Σ Indirim 19.891.253,40 (34 satır, (sebep, fiş) tekil)
              B2 : manuel fiş tekil Σ Indirim 18.256.609,93 (3 satır; Kumbara dahil; iade negatif)
              C  : 496 iade belgesi · IadeBrut 4.520.582,40 · IadeIndirim 323.221,53 (FSM 139 · İst.Yolu 189 · Özlüce 168);
                   Kumbara kaynaklı iade 0
   Aynı kaynak — neden: Kumbara/manuel bağı (SalesProductCampaigns.CampaignVersion = RefundReasons.Id, CampaignId IS NULL)
              yalnız Encore'da var; ERP'de karşılığı yok, bu yüzden kaynak bağımsız değil, yöntem bağımsız
              (önce fiş kümesi tekilleştirilir, tutar başlıktan bir kez alınır).
   Başka ne olabilir: (1) iki sebepli fiş her sebepte bir kez sayıldığı için sebepler arası toplam fiş tekil toplamını
              aşabilir (beklenen); fiş tekil toplam B2'dedir. (2) Kumbara (Id 17) Type=1 olduğundan manuel listede kendi adıyla da
              görünür; manuel karşılaştırması B'de Sebep <> N'Kumbara satırlarıyla yapılır, Kumbara ayrı satırdır, ikisi toplanmaz.
              (3) 1001 geri dönüşüm satırları iade belgelerinde yoğun (T-001); bu bağ kampanya kalemine dayandığı için 1001 dışlaması yok.
              (4) AC-1.2 tanımı: fiş başına başlık DiscountTotal = manuel sebepli fişlerin TOPLAM indirimi; kalem bazlı manuel
              indirim DEĞİL. Kalem indirimi = DiscountTotalDirect + DiscountTotalIndirect (T-017); Eylül, 3 mağaza, iade negatif
              (blok K, 04.10.2026, 134.314 fiş): Direct 40.779.006,66 + Indirect 10.853.128,37 = 51.632.135,03 = başlık DiscountTotal
              toplamı 51.632.135,03 (K'da ayrıca hesaplanır; kaynak içi kimlik, bağımsız kanıt değil).
              Eski '~5,14M Direct' atfı geçersiz (kaynağı yoktu) ve kaldırıldı.
   İade     : iade belgesi kendi manuel bağını taşımaz (2026'da DocumentsTypeId=3 belgelerinde CampaignId IS NULL satır 0). İade kümesi
              kaynak fişten kurulur: r.DocumentsTypeId = 3 AND r.LinkedDocumentId > 0 ve kaynak fişte (sp.SalesId = r.LinkedDocumentId,
              IsValid = 1) CampaignId IS NULL satırı + RefundReasons.Type = 1 (Kumbara için Id = 17). İade KENDİ tarihine (r.[Date])
              negatif yazılır; kaynağı önceki ayda olan iade de dahildir (karar). Sınırlar: (a) kısmi iade, kaynak fişin manuel olmayan
              kalemini de iade etmiş olabilir; (b) perakende iadelerin yaklaşık %41'inde LinkedDocumentId = 0, zincirlenemez, dışarıda;
              (c) iade tarihine yazılır, kaynak fişin tarihine değil.
   Kapsam   : DocumentsTypeId IN (1,2,3,6,7,8), iade (3) negatif; mağaza = Pos.StoreId → Stores.Code = posMagaza.mekanKod
              (COLLATE), mekanID IN (1,4477,4478); posMagaza'da bu üç mekân için mekanKod tekil (3 satır, 3 tekil kod, Stores'ta
              3 eşleşme; fan-out yok); kalem SalesProducts.IsValid = 1;
              Brut = Sales.GrossTotal, Indirim = Sales.DiscountTotal (başlıktan bir kez).
   Dondurma : e1a0a78
   SSMS     : DECLARE @Bas datetime = CONVERT(datetime, '01.09.2026', 104), @Bit datetime = CONVERT(datetime, '01.10.2026', 104);
   Komut    : sqlcli --param ISO tarih ister; bloklar GO'suz ve DECLARE'siz, literal tarihle koşuldu (SSMS DECLARE + GO esas).
   Bloklar  : A Kumbara brüt (Magaza, Brut) · B sebep indirimi (Sebep, Magaza, Indirim) · B2 manuel fiş tekil (Magaza, Indirim)
              · C manuel kaynaklı iade (Magaza, IadeliFis, IadeBrut, IadeIndirim; mutlak değer). A/B/B2 içinde iade zaten negatif.
              · K kalem indirimi Direct + Indirect ve başlık toplamı (KalemDirect, KalemIndirect, BaslikIndirim, Fis; tek satır)
   AC-1.3   : nüfus 496 (manuel), 0 (Kumbara)
*/

-- blok: A  (Kumbara brüt, fiş başına bir kez; iade kaynak fişten, iade tarihine negatif)
DECLARE @Bas datetime = CONVERT(datetime, '01.09.2026', 104);  -- DMY
DECLARE @Bit datetime = CONVERT(datetime, '01.10.2026', 104);  -- DMY

WITH KumbaraFis AS (
    SELECT DISTINCT s.Id AS fis_id
    FROM EncoreMerkez.dbo.Sales AS s
        INNER JOIN EncoreMerkez.dbo.SalesProducts AS sp
            ON s.Id = sp.SalesId AND sp.IsValid = 1
        INNER JOIN EncoreMerkez.dbo.SalesProductCampaigns AS spc
            ON sp.SalesId = spc.SalesId AND sp.[Sequence] = spc.ProductSequence AND spc.CampaignId IS NULL
        INNER JOIN EncoreMerkez.dbo.RefundReasons AS rr
            ON spc.CampaignVersion = rr.Id AND rr.Id = 17
    WHERE
        s.[Date] >= @Bas AND s.[Date] < @Bit
        AND s.DocumentsTypeId IN (1, 2, 3, 6, 7, 8)
    UNION
    SELECT DISTINCT r.Id AS fis_id
    FROM EncoreMerkez.dbo.Sales AS r
        INNER JOIN EncoreMerkez.dbo.SalesProducts AS sp
            ON r.LinkedDocumentId = sp.SalesId AND sp.IsValid = 1
        INNER JOIN EncoreMerkez.dbo.SalesProductCampaigns AS spc
            ON sp.SalesId = spc.SalesId AND sp.[Sequence] = spc.ProductSequence AND spc.CampaignId IS NULL
        INNER JOIN EncoreMerkez.dbo.RefundReasons AS rr
            ON spc.CampaignVersion = rr.Id AND rr.Id = 17
    WHERE
        r.[Date] >= @Bas AND r.[Date] < @Bit
        AND r.DocumentsTypeId = 3
        AND r.LinkedDocumentId > 0
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
        ON mg.mekanKod COLLATE Turkish_CI_AS = st.Code COLLATE Turkish_CI_AS AND mg.mekanID IN (1, 4477, 4478)
GROUP BY st.Name
ORDER BY st.Name;
GO

-- blok: B  (kalem bazlı sebep değil: sebepli fişin TOPLAM başlık indirimi; her (sebep, fiş) bir kez; iade kaynak fişten)
DECLARE @Bas datetime = CONVERT(datetime, '01.09.2026', 104);  -- DMY
DECLARE @Bit datetime = CONVERT(datetime, '01.10.2026', 104);  -- DMY

WITH SebepFis AS (
    SELECT DISTINCT
        CASE WHEN rr.Id = 17 THEN N'Kumbara' ELSE rr.Name END AS sebep_adi,
        s.Id AS fis_id
    FROM EncoreMerkez.dbo.Sales AS s
        INNER JOIN EncoreMerkez.dbo.SalesProducts AS sp
            ON s.Id = sp.SalesId AND sp.IsValid = 1
        INNER JOIN EncoreMerkez.dbo.SalesProductCampaigns AS spc
            ON sp.SalesId = spc.SalesId AND sp.[Sequence] = spc.ProductSequence AND spc.CampaignId IS NULL
        INNER JOIN EncoreMerkez.dbo.RefundReasons AS rr
            ON spc.CampaignVersion = rr.Id AND rr.Id = 17
    WHERE
        s.[Date] >= @Bas AND s.[Date] < @Bit
        AND s.DocumentsTypeId IN (1, 2, 3, 6, 7, 8)
    UNION
    SELECT DISTINCT
        rr.Name AS sebep_adi,
        s.Id AS fis_id
    FROM EncoreMerkez.dbo.Sales AS s
        INNER JOIN EncoreMerkez.dbo.SalesProducts AS sp
            ON s.Id = sp.SalesId AND sp.IsValid = 1
        INNER JOIN EncoreMerkez.dbo.SalesProductCampaigns AS spc
            ON sp.SalesId = spc.SalesId AND sp.[Sequence] = spc.ProductSequence AND spc.CampaignId IS NULL
        INNER JOIN EncoreMerkez.dbo.RefundReasons AS rr
            ON spc.CampaignVersion = rr.Id AND rr.Type = 1
    WHERE
        s.[Date] >= @Bas AND s.[Date] < @Bit
        AND s.DocumentsTypeId IN (1, 2, 3, 6, 7, 8)
    UNION
    SELECT DISTINCT
        CASE WHEN rr.Id = 17 THEN N'Kumbara' ELSE rr.Name END AS sebep_adi,
        r.Id AS fis_id
    FROM EncoreMerkez.dbo.Sales AS r
        INNER JOIN EncoreMerkez.dbo.SalesProducts AS sp
            ON r.LinkedDocumentId = sp.SalesId AND sp.IsValid = 1
        INNER JOIN EncoreMerkez.dbo.SalesProductCampaigns AS spc
            ON sp.SalesId = spc.SalesId AND sp.[Sequence] = spc.ProductSequence AND spc.CampaignId IS NULL
        INNER JOIN EncoreMerkez.dbo.RefundReasons AS rr
            ON spc.CampaignVersion = rr.Id AND rr.Id = 17
    WHERE
        r.[Date] >= @Bas AND r.[Date] < @Bit
        AND r.DocumentsTypeId = 3
        AND r.LinkedDocumentId > 0
    UNION
    SELECT DISTINCT
        rr.Name AS sebep_adi,
        r.Id AS fis_id
    FROM EncoreMerkez.dbo.Sales AS r
        INNER JOIN EncoreMerkez.dbo.SalesProducts AS sp
            ON r.LinkedDocumentId = sp.SalesId AND sp.IsValid = 1
        INNER JOIN EncoreMerkez.dbo.SalesProductCampaigns AS spc
            ON sp.SalesId = spc.SalesId AND sp.[Sequence] = spc.ProductSequence AND spc.CampaignId IS NULL
        INNER JOIN EncoreMerkez.dbo.RefundReasons AS rr
            ON spc.CampaignVersion = rr.Id AND rr.Type = 1
    WHERE
        r.[Date] >= @Bas AND r.[Date] < @Bit
        AND r.DocumentsTypeId = 3
        AND r.LinkedDocumentId > 0
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
        ON mg.mekanKod COLLATE Turkish_CI_AS = st.Code COLLATE Turkish_CI_AS AND mg.mekanID IN (1, 4477, 4478)
GROUP BY sf.sebep_adi, st.Name
ORDER BY sf.sebep_adi, st.Name;
GO

-- blok: B2  (manuel indirim, fiş tekil: Type=1 sebeplerden herhangi biri olan fiş bir kez; Kumbara dahil)
DECLARE @Bas datetime = CONVERT(datetime, '01.09.2026', 104);  -- DMY
DECLARE @Bit datetime = CONVERT(datetime, '01.10.2026', 104);  -- DMY

WITH ManuelFis AS (
    SELECT DISTINCT s.Id AS fis_id
    FROM EncoreMerkez.dbo.Sales AS s
        INNER JOIN EncoreMerkez.dbo.SalesProducts AS sp
            ON s.Id = sp.SalesId AND sp.IsValid = 1
        INNER JOIN EncoreMerkez.dbo.SalesProductCampaigns AS spc
            ON sp.SalesId = spc.SalesId AND sp.[Sequence] = spc.ProductSequence AND spc.CampaignId IS NULL
        INNER JOIN EncoreMerkez.dbo.RefundReasons AS rr
            ON spc.CampaignVersion = rr.Id AND rr.Type = 1
    WHERE
        s.[Date] >= @Bas AND s.[Date] < @Bit
        AND s.DocumentsTypeId IN (1, 2, 3, 6, 7, 8)
    UNION
    SELECT DISTINCT r.Id AS fis_id
    FROM EncoreMerkez.dbo.Sales AS r
        INNER JOIN EncoreMerkez.dbo.SalesProducts AS sp
            ON r.LinkedDocumentId = sp.SalesId AND sp.IsValid = 1
        INNER JOIN EncoreMerkez.dbo.SalesProductCampaigns AS spc
            ON sp.SalesId = spc.SalesId AND sp.[Sequence] = spc.ProductSequence AND spc.CampaignId IS NULL
        INNER JOIN EncoreMerkez.dbo.RefundReasons AS rr
            ON spc.CampaignVersion = rr.Id AND rr.Type = 1
    WHERE
        r.[Date] >= @Bas AND r.[Date] < @Bit
        AND r.DocumentsTypeId = 3
        AND r.LinkedDocumentId > 0
)

SELECT
    st.Name AS Magaza,
    SUM(CASE WHEN s.DocumentsTypeId = 3 THEN -s.DiscountTotal ELSE s.DiscountTotal END) AS Indirim
FROM ManuelFis AS mf
    INNER JOIN EncoreMerkez.dbo.Sales AS s
        ON mf.fis_id = s.Id
    INNER JOIN EncoreMerkez.dbo.Pos AS ps
        ON s.PosId = ps.Id
    INNER JOIN EncoreMerkez.dbo.Stores AS st
        ON ps.StoreId = st.Id
    INNER JOIN DerinSISBkm.dbo.posMagaza AS mg
        ON mg.mekanKod COLLATE Turkish_CI_AS = st.Code COLLATE Turkish_CI_AS AND mg.mekanID IN (1, 4477, 4478)
GROUP BY st.Name
ORDER BY st.Name;
GO

-- blok: C  (iade belgeleri: kaynak fişi manuel sebepli; tutarlar mutlak değer)
DECLARE @Bas datetime = CONVERT(datetime, '01.09.2026', 104);  -- DMY
DECLARE @Bit datetime = CONVERT(datetime, '01.10.2026', 104);  -- DMY

WITH IadeFis AS (
    SELECT DISTINCT r.Id AS fis_id
    FROM EncoreMerkez.dbo.Sales AS r
        INNER JOIN EncoreMerkez.dbo.SalesProducts AS sp
            ON r.LinkedDocumentId = sp.SalesId AND sp.IsValid = 1
        INNER JOIN EncoreMerkez.dbo.SalesProductCampaigns AS spc
            ON sp.SalesId = spc.SalesId AND sp.[Sequence] = spc.ProductSequence AND spc.CampaignId IS NULL
        INNER JOIN EncoreMerkez.dbo.RefundReasons AS rr
            ON spc.CampaignVersion = rr.Id AND rr.Type = 1
    WHERE
        r.[Date] >= @Bas AND r.[Date] < @Bit
        AND r.DocumentsTypeId = 3
        AND r.LinkedDocumentId > 0
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
        ON mg.mekanKod COLLATE Turkish_CI_AS = st.Code COLLATE Turkish_CI_AS AND mg.mekanID IN (1, 4477, 4478)
GROUP BY st.Name
ORDER BY st.Name;
GO

-- blok: K  (kalem indirimi Direct + Indirect = başlık DiscountTotal mı? iade negatif; 3 mağaza, bütün belge tipleri 1,2,3,6,7,8)
DECLARE @Bas datetime = CONVERT(datetime, '01.09.2026', 104);  -- DMY
DECLARE @Bit datetime = CONVERT(datetime, '01.10.2026', 104);  -- DMY

WITH Fis AS (
    SELECT
        s.Id AS fis_id,
        s.DocumentsTypeId,
        s.DiscountTotal
    FROM EncoreMerkez.dbo.Sales AS s
        INNER JOIN EncoreMerkez.dbo.Pos AS ps
            ON s.PosId = ps.Id
        INNER JOIN EncoreMerkez.dbo.Stores AS st
            ON ps.StoreId = st.Id
        INNER JOIN DerinSISBkm.dbo.posMagaza AS mg
            ON mg.mekanKod COLLATE Turkish_CI_AS = st.Code COLLATE Turkish_CI_AS AND mg.mekanID IN (1, 4477, 4478)
    WHERE
        s.[Date] >= @Bas AND s.[Date] < @Bit
        AND s.DocumentsTypeId IN (1, 2, 3, 6, 7, 8)
),

Kalem AS (
    SELECT
        sp.SalesId AS fis_id,
        SUM(sp.DiscountTotalDirect) AS direct_toplam,
        SUM(sp.DiscountTotalIndirect) AS indirect_toplam
    FROM EncoreMerkez.dbo.SalesProducts AS sp
    WHERE sp.IsValid = 1
    GROUP BY sp.SalesId
)

SELECT
    COUNT(*) AS Fis,
    SUM(CASE WHEN f.DocumentsTypeId = 3 THEN -ISNULL(k.direct_toplam, 0) ELSE ISNULL(k.direct_toplam, 0) END) AS KalemDirect,
    SUM(CASE WHEN f.DocumentsTypeId = 3 THEN -ISNULL(k.indirect_toplam, 0) ELSE ISNULL(k.indirect_toplam, 0) END) AS KalemIndirect,
    SUM(CASE WHEN f.DocumentsTypeId = 3 THEN -f.DiscountTotal ELSE f.DiscountTotal END) AS BaslikIndirim
FROM Fis AS f
    LEFT JOIN Kalem AS k
        ON f.fis_id = k.fis_id;
