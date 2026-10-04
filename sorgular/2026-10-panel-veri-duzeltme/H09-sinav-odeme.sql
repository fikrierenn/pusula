-- ork:hedef-db EncoreMerkez
-- ork:compat 110
/* Soru     : Sınav ödeme sağlık kartının net toplamı KPI net tutarına eşit mi (fatura başına bir kez, iade LinkedDocumentId bağından)?
   AC       : AC-9.1, AC-9.2 · Spec 001 · H09
   Dönem    : @Bas = 01.09.2026; @DonemId = snv.Donem'de IslemBaslamaTarih <= @Bas olan en yeni dönem (canlı türetilir; 04.10.2026 → 8)
   Tolerans : sayı birebir; tutar ≤ 1 TL
   Önce     : (04.10.2026, sqlcli erp profili, --read-only; panel SinavQueries.cs :174 kart ve :132 KPI gövdeleri aynen, @donemId = 8)
              ONCE-KPI (GetSezonKpiAsync): satış fişi 7.564 · iade fişi 234 · NetKdvHaric 448.183.744,55
              ONCE-KART (GetOdemeDurumAsync) NetKdvHaric: TAM_ODENDI 380.958.595,30 · KISMI_ODENDI 67.132.549,93 · HIC_ODENMEDI 247.718,37
                Σ kart = 448.338.863,60 (6.384 + 1.062 + 36 = 7.482 sipariş)
              Kart − KPI = +155.119,05 (tolerans 1 TL aşıldı)
   Sonra    : yok (düzeltme T-055 sonrası ölçülür)
   Bağımsız : (04.10.2026) A kanonik net 448.183.744,55 (7.564 satış + 234 iade faturası = 7.798) = ONCE-KPI birebir.
              C kalem düzeyi (SalesProducts IsValid = 1, TotalPrice − VatTotal) 448.183.744,55 = A.
              Fark kaynağı: kart iadeyi FE kaydından alıyor (145 iade satırı, 6.399.378,40);
              KPI iadeyi LinkedDocumentId bağından alıyor (234 iade, 6.554.497,45); fark 155.119,05 = kart − KPI.
   Nüfus    : (blok N, 04.10.2026) dönem 8: 7.482 sipariş · 7.709 FE satırı · 7.709 tekil fatura; kalemsiz fişli sipariş 0.
              B CokSiparisliFatura = 0 (dönem 8 ve tüm dönemler): fan-out yok, D FazlaSayilanNet 0,00.
              Eylül tarihli siparişler 3 DonemId'de: 8 → 5.395 · 7 → 1 · −8 → 5; snv.Donem'de yalnız 8 tanımlı.
              Negatif DonemId (−8: 39 sipariş, 17.07–13.09.2026, hiçbiri fişli; −7: 36 sipariş, 2'si fişli) snv.Donem'de karşılığı yok;
              anlamı veriden çıkarılamadı, açık soru. Kart ve KPI @DonemId = 8 ile bunları zaten dışlar.
   Aynı kaynak — neden: A, ONCE-KPI ile AYNI kaynaktan (FE + Sales + LinkedDocumentId) kurulur;
              kaynak içi kimliktir, bağımsız kanıt DEĞİLDİR.
              Bağımsız yan: C kalem düzeyi (SalesProducts) başlıktan ayrı tablo;
              iade tarafında FE ↔ LinkedDocumentId karşılaştırması.
              Encore dışı bağımsız kaynak yok (ERP'de Sınav faturası günlük özet belgedir).
   Başka ne olabilir: (1) Fan-out (fatura birden çok siparişe bağlı): ölçüldü, 0; fark bundan değil.
              (2) Kalemsiz sipariş (K.Kalem > 0 dışlaması): ölçüldü, 0.
              (3) FE'de aynı fatura çift satır: 7.709 satır = 7.709 tekil fatura.
              (4) FE iade kaydı eksik (sema: FE kısmi iadeleri kaydetmiyor): ölçüldü,
              145 FE iade satırı ↔ 234 bağlı iade; tutar farkı = farkın tamamı.
              (5) Dönem süzgeci: kart ve KPI aynı.
   Kapsam   : Satış faturası = FE'ye bağlı Sales, DocumentsTypeId <> 3;
              iade = LinkedDocumentId > 0 ile Sınav faturasına (tip 8) bağlı tip 3.
              Net = GrossTotal − DiscountTotal − VatTotal (KDV hariç); iade negatif.
   Dondurma : bc98d56
   SSMS     : DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104);  (@DonemId blok içinde türetilir)
   Komut    : sqlcli --read-only DECLARE kabul etmez; bloklar GO'suz ve DECLARE'siz, @Bas/@DonemId
              literalle değiştirilerek koşuldu (--profile erp, --max-rows 100000).
   Bloklar  : A kanonik net · B çok siparişli fatura · C kalem kontrolü · D fan-out tutarı
              · ONCE-KPI · ONCE-KART (panel gövdeleri) · N nüfus.
              Boş nüfus 'bakamadım'dır, 'temiz' değil.
*/

-- blok: A  (kanonik net: fatura başına BİR kez; satış FE'den, iade LinkedDocumentId > 0 bağından, işaretli; KDV hariç)
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104);  -- DMY
DECLARE @DonemId INT = (
    SELECT TOP (1) d.DonemId
    FROM BKM.snv.Donem AS d
    WHERE d.IslemBaslamaTarih <= @Bas
    ORDER BY d.IslemBaslamaTarih DESC
);

WITH Siparis AS (
    SELECT sip.SiparisKod
    FROM BKM.snv.Siparis AS sip
    WHERE sip.DonemId = @DonemId
),

SatisFatura AS (
    SELECT DISTINCT s.Id
    FROM BKM.snv.SinavSiparisFisEncore AS fe
        INNER JOIN Siparis AS si
            ON fe.SiparisKod = si.SiparisKod
        INNER JOIN EncoreMerkez.dbo.Sales AS s
            ON fe.InvoiceNo COLLATE Turkish_CI_AS = s.DocumentNo COLLATE Turkish_CI_AS
    WHERE s.DocumentsTypeId <> 3
),

IadeFatura AS (
    SELECT DISTINCT i.Id
    FROM EncoreMerkez.dbo.Sales AS i
        INNER JOIN EncoreMerkez.dbo.Sales AS o
            ON
                i.LinkedDocumentId = o.Id
                AND o.DocumentsTypeId = 8
        INNER JOIN BKM.snv.SinavSiparisFisEncore AS fe
            ON fe.InvoiceNo COLLATE Turkish_CI_AS = o.DocumentNo COLLATE Turkish_CI_AS
        INNER JOIN Siparis AS si
            ON fe.SiparisKod = si.SiparisKod
    WHERE
        i.DocumentsTypeId = 3
        AND i.LinkedDocumentId > 0
),

Fatura AS (
    SELECT
        sf.Id,
        1 AS isaret
    FROM SatisFatura AS sf
    UNION ALL
    SELECT
        ifa.Id,
        -1 AS isaret
    FROM IadeFatura AS ifa
)

SELECT
    @DonemId AS DonemId,
    COUNT(*) AS FaturaSayisi,
    SUM(CASE WHEN f.isaret = 1 THEN 1 ELSE 0 END) AS SatisFaturaSayisi,
    SUM(CASE WHEN f.isaret = -1 THEN 1 ELSE 0 END) AS IadeFaturaSayisi,
    CONVERT(DECIMAL(18, 2), ISNULL(SUM(f.isaret * (s.GrossTotal - s.DiscountTotal - s.VatTotal)), 0)) AS NetKdvHaric
FROM Fatura AS f
    INNER JOIN EncoreMerkez.dbo.Sales AS s
        ON f.Id = s.Id;
GO

-- blok: B  (nüfus: birden çok siparişe bağlı SATIŞ faturası sayısı; dönem siparişleri içinde)
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104);  -- DMY
DECLARE @DonemId INT = (
    SELECT TOP (1) d.DonemId
    FROM BKM.snv.Donem AS d
    WHERE d.IslemBaslamaTarih <= @Bas
    ORDER BY d.IslemBaslamaTarih DESC
);

SELECT COUNT(*) AS CokSiparisliFatura
FROM (
    SELECT s.Id
    FROM BKM.snv.SinavSiparisFisEncore AS fe
        INNER JOIN BKM.snv.Siparis AS sip
            ON fe.SiparisKod = sip.SiparisKod
        INNER JOIN EncoreMerkez.dbo.Sales AS s
            ON fe.InvoiceNo COLLATE Turkish_CI_AS = s.DocumentNo COLLATE Turkish_CI_AS
    WHERE
        sip.DonemId = @DonemId
        AND s.DocumentsTypeId <> 3
    GROUP BY s.Id
    HAVING COUNT(DISTINCT fe.SiparisKod) > 1
) AS x;
GO

-- blok: C  (kontrol: A'nın kalem düzeyi karşılığı; SalesProducts IsValid = 1, KDV hariç = TotalPrice − VatTotal; fatura bir kez)
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104);  -- DMY
DECLARE @DonemId INT = (
    SELECT TOP (1) d.DonemId
    FROM BKM.snv.Donem AS d
    WHERE d.IslemBaslamaTarih <= @Bas
    ORDER BY d.IslemBaslamaTarih DESC
);

WITH Siparis AS (
    SELECT sip.SiparisKod
    FROM BKM.snv.Siparis AS sip
    WHERE sip.DonemId = @DonemId
),

SatisFatura AS (
    SELECT DISTINCT s.Id
    FROM BKM.snv.SinavSiparisFisEncore AS fe
        INNER JOIN Siparis AS si
            ON fe.SiparisKod = si.SiparisKod
        INNER JOIN EncoreMerkez.dbo.Sales AS s
            ON fe.InvoiceNo COLLATE Turkish_CI_AS = s.DocumentNo COLLATE Turkish_CI_AS
    WHERE s.DocumentsTypeId <> 3
),

IadeFatura AS (
    SELECT DISTINCT i.Id
    FROM EncoreMerkez.dbo.Sales AS i
        INNER JOIN EncoreMerkez.dbo.Sales AS o
            ON
                i.LinkedDocumentId = o.Id
                AND o.DocumentsTypeId = 8
        INNER JOIN BKM.snv.SinavSiparisFisEncore AS fe
            ON fe.InvoiceNo COLLATE Turkish_CI_AS = o.DocumentNo COLLATE Turkish_CI_AS
        INNER JOIN Siparis AS si
            ON fe.SiparisKod = si.SiparisKod
    WHERE
        i.DocumentsTypeId = 3
        AND i.LinkedDocumentId > 0
),

Fatura AS (
    SELECT
        sf.Id,
        1 AS isaret
    FROM SatisFatura AS sf
    UNION ALL
    SELECT
        ifa.Id,
        -1 AS isaret
    FROM IadeFatura AS ifa
)

SELECT CONVERT(DECIMAL(18, 2), ISNULL(SUM(f.isaret * (sp.TotalPrice - sp.VatTotal)), 0)) AS KalemNetKdvHaric
FROM Fatura AS f
    INNER JOIN EncoreMerkez.dbo.SalesProducts AS sp
        ON
            f.Id = sp.SalesId
            AND sp.IsValid = 1;
GO

-- blok: D  (fan-out tutarı: bir fatura n siparişe bağlıysa kartın fazla saydığı net = net × (n − 1); yalnız satış faturaları)
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104);  -- DMY
DECLARE @DonemId INT = (
    SELECT TOP (1) d.DonemId
    FROM BKM.snv.Donem AS d
    WHERE d.IslemBaslamaTarih <= @Bas
    ORDER BY d.IslemBaslamaTarih DESC
);

WITH Bag AS (
    SELECT
        s.Id,
        COUNT(DISTINCT fe.SiparisKod) AS siparis_sayisi
    FROM BKM.snv.SinavSiparisFisEncore AS fe
        INNER JOIN BKM.snv.Siparis AS sip
            ON fe.SiparisKod = sip.SiparisKod
        INNER JOIN EncoreMerkez.dbo.Sales AS s
            ON fe.InvoiceNo COLLATE Turkish_CI_AS = s.DocumentNo COLLATE Turkish_CI_AS
    WHERE
        sip.DonemId = @DonemId
        AND s.DocumentsTypeId <> 3
    GROUP BY s.Id
)

SELECT
    COUNT(*) AS CokSiparisliFatura,
    CONVERT(DECIMAL(18, 2), ISNULL(SUM((b.siparis_sayisi - 1) * (s.GrossTotal - s.DiscountTotal - s.VatTotal)), 0)) AS FazlaSayilanNet
FROM Bag AS b
    INNER JOIN EncoreMerkez.dbo.Sales AS s
        ON b.Id = s.Id
WHERE b.siparis_sayisi > 1;
GO

-- noqa: disable=all
-- blok: ONCE-KPI  (panel GetSezonKpiAsync gövdesi aynen; @donemId → @DonemId; yalnız Fis, Iade ve NetKdvHaric)
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104);  -- DMY
DECLARE @DonemId INT = (SELECT TOP (1) d.DonemId FROM BKM.snv.Donem AS d WHERE d.IslemBaslamaTarih <= @Bas ORDER BY d.IslemBaslamaTarih DESC);

WITH Fis AS (
    SELECT DISTINCT S.Id, S.GrossTotal, S.DiscountTotal, S.VatTotal
    FROM BKM.snv.SinavSiparisFisEncore FE WITH(NOLOCK)
         JOIN EncoreMerkez.dbo.Sales S WITH(NOLOCK) ON S.DocumentNo = FE.InvoiceNo
    WHERE S.DocumentsTypeId <> 3
      AND EXISTS (SELECT 1 FROM BKM.snv.Siparis sip WITH(NOLOCK)
                  WHERE sip.SiparisKod = FE.SiparisKod AND (@DonemId IS NULL OR sip.DonemId = @DonemId))
),
Iade AS (
    SELECT DISTINCT I.Id, I.GrossTotal, I.DiscountTotal, I.VatTotal
    FROM EncoreMerkez.dbo.Sales I WITH(NOLOCK)
         JOIN EncoreMerkez.dbo.Sales O WITH(NOLOCK) ON O.Id = I.LinkedDocumentId AND O.DocumentsTypeId = 8
         JOIN BKM.snv.SinavSiparisFisEncore FEO WITH(NOLOCK) ON FEO.InvoiceNo = O.DocumentNo
    WHERE I.DocumentsTypeId = 3
      AND EXISTS (SELECT 1 FROM BKM.snv.Siparis sip WITH(NOLOCK)
                  WHERE sip.SiparisKod = FEO.SiparisKod AND (@DonemId IS NULL OR sip.DonemId = @DonemId))
)
SELECT
  (SELECT COUNT(*) FROM Fis) AS SatisFis,
  (SELECT COUNT(*) FROM Iade) AS IadeFis,
  (SELECT ISNULL(SUM(GrossTotal - DiscountTotal - VatTotal),0) FROM Fis)
- (SELECT ISNULL(SUM(GrossTotal - DiscountTotal - VatTotal),0) FROM Iade) AS NetKdvHaric;
GO

-- blok: ONCE-KART  (panel GetOdemeDurumAsync iç sorgusu aynen; yalnız Durum, Siparis, NetKdvHaric)
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104);  -- DMY
DECLARE @DonemId INT = (SELECT TOP (1) d.DonemId FROM BKM.snv.Donem AS d WHERE d.IslemBaslamaTarih <= @Bas ORDER BY d.IslemBaslamaTarih DESC);

SELECT T.Durum, COUNT(*) AS Siparis, SUM(T.Kalem) AS Kalem, CONVERT(decimal(18,2), ISNULL(SUM(T.NetKdvHaric),0)) AS NetKdvHaric
FROM (
    SELECT sip.SiparisId,
           CASE WHEN K.Odenmis = 0 THEN 'HIC_ODENMEDI' WHEN K.Odenmemis = 0 THEN 'TAM_ODENDI' ELSE 'KISMI_ODENDI' END AS Durum,
           K.Kalem, X.NetKdvHaric
    FROM BKM.snv.Siparis sip WITH(NOLOCK)
         CROSS APPLY (
            SELECT COUNT(*) AS Kalem,
                   SUM(CASE WHEN ISNULL(sd.OdemesiYapildi,0) = 1 THEN 1 ELSE 0 END) AS Odenmis,
                   SUM(CASE WHEN ISNULL(sd.OdemesiYapildi,0) = 0 AND ISNULL(sd.Iptal,0) = 0 THEN 1 ELSE 0 END) AS Odenmemis
            FROM BKM.snv.SiparisDetay sd WITH(NOLOCK)
            WHERE sd.SiparisId = sip.SiparisId) K
         OUTER APPLY (
            SELECT SUM(CASE WHEN S.DocumentsTypeId = 3 THEN -(S.GrossTotal - S.DiscountTotal - S.VatTotal)
                            ELSE (S.GrossTotal - S.DiscountTotal - S.VatTotal) END) AS NetKdvHaric
            FROM BKM.snv.SinavSiparisFisEncore FE WITH(NOLOCK)
                 JOIN EncoreMerkez.dbo.Sales S WITH(NOLOCK) ON S.DocumentNo = FE.InvoiceNo
            WHERE FE.SiparisKod = sip.SiparisKod) X
    WHERE (@DonemId IS NULL OR sip.DonemId = @DonemId) AND K.Kalem > 0
) T
GROUP BY T.Durum;
GO
-- noqa: enable=all

-- blok: N  (nüfus: dönem siparişi, FE satırı, tekil fatura, kalemsiz fişli sipariş)
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104);  -- DMY
DECLARE @DonemId INT = (
    SELECT TOP (1) d.DonemId
    FROM BKM.snv.Donem AS d
    WHERE d.IslemBaslamaTarih <= @Bas
    ORDER BY d.IslemBaslamaTarih DESC
);

WITH Detayli AS (
    SELECT DISTINCT x.SiparisId
    FROM BKM.snv.SiparisDetay AS x
)

SELECT
    COUNT(DISTINCT sip.SiparisKod) AS siparis_sayisi,
    COUNT(fe.SiparisKod) AS fe_satiri,
    COUNT(DISTINCT fe.InvoiceNo) AS tekil_fatura,
    COUNT(DISTINCT CASE WHEN sd.SiparisId IS NULL THEN fe.SiparisKod END) AS kalemsiz_fisli_siparis
FROM BKM.snv.Siparis AS sip
    LEFT JOIN BKM.snv.SinavSiparisFisEncore AS fe
        ON sip.SiparisKod = fe.SiparisKod
    LEFT JOIN Detayli AS sd
        ON sip.SiparisId = sd.SiparisId
WHERE sip.DonemId = @DonemId;
GO
