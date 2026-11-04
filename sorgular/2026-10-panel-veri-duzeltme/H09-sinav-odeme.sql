-- ork:hedef-db EncoreMerkez
-- ork:compat 110
/* Soru     : Sınav ödeme sağlık kartı ve KPI, kanal kuralını uygulayan kanonik net toplamla (fatura başına bir kez; iade LinkedDocumentId
              bağından, yalnız aynı mağazada) aynı mı?
   AC       : AC-9.1, AC-9.2 · Spec 001 · H09
   Dönem    : @Bas = 01.09.2026; @DonemId = snv.Donem'de IslemBaslamaTarih <= @Bas olan en yeni dönem (canlı türetilir; 04.10.2026 → 8)
   Tolerans : sayı birebir; tutar ≤ 1 TL
   Pencere  : dönem 8'in TAMAMI, Eylül değil: dönem başı 16.07.2026, siparişler 22.07.2026 → koşu günü (04.10.2026).
              Dönem açık; her gün değişir, aşağıdaki sayılar 04.10.2026 koşusuna aittir.
   Dönem türetme: @DonemId A, B, C, D, ONCE-KPI, ONCE-KART, N, IADE-KAYNAK bloklarında (sekiz yerde) ve ek dosya IADE-AY'de AYNI metinle
              türetilir.
              Türetme bitiş koşulsuzdur (snv.Donem'de bitiş kolonu yok): ek dosya DONEM_ARALIK.
   Kolonlar : A beş kolon döndürür, sıra sözleşmedir (T-055): DonemId, FaturaSayisi, SatisFaturaSayisi, IadeFaturaSayisi, NetKdvHaric.
   Ek dosya : H09-sinav-odeme-ek.sql (BT, IADE-AY, DONEM, DONEM_ARALIK; 20 KB sınırı).
   Kanal kuralı : sema metrics:iade_kanal_atamasi (GMY 12.09.2026): Sınav iadesi yalnız orijinal fatura aynı mağazadaysa
              Sınav'dan düşer → A ve C'de IadeFatura'da i.StoresId = o.StoresId. Panel KPI bu kuralı uygulamaz.
   Önce     : (04.10.2026, erp profili, --read-only; panel SinavQueries.cs :174 kart ve :132 KPI gövdeleri aynen, @donemId = 8)
              ONCE-KPI (GetSezonKpiAsync): satış fişi 7.566 · iade fişi 234 · NetKdvHaric 448.273.958,37
              ONCE-KART (GetOdemeDurumAsync) NetKdvHaric: TAM_ODENDI 380.985.798,12 · KISMI_ODENDI 67.195.560,93 · HIC_ODENMEDI 247.718,37
                Σ kart = 448.429.077,42 (6.385 + 1.063 + 36 = 7.484 sipariş)
              Kart − KPI = +155.119,05 (tolerans 1 TL aşıldı). Dönem açık: 04.10.2026 ilk koşusundan sonra sayılar arttı (satış fişi
              7.564 → 7.566), farklar aynı kaldı.
   Sonra    : yok (düzeltme T-055 sonrası ölçülür)
   Bağımsız : (04.10.2026) A kanonik net 448.276.992,84 (7.566 satış + 227 iade faturası = 7.793), kanal kuralı uygulanmış.
              A − ONCE-KPI = +3.034,47 = kanal kuralının dışarıda bıraktığı 7 iade (IADE-KAYNAK: 2 + 5 farklı mağaza,
              1.037,28 + 1.997,19). C kalem düzeyi (SalesProducts IsValid = 1, TotalPrice − VatTotal) 448.276.992,84 = A.
              Kart − A = 152.084,58; toplam kart − KPI = 155.119,05 = 152.084,58 + 3.034,47.
              IADE-KAYNAK (LinkedDocumentId bağlı 234 iade; FE'de kayıtlı × aynı mağaza):
                FE var · aynı mağaza 143 / 6.398.341,12 · FE var · farklı mağaza 2 / 1.037,28
                FE yok · aynı mağaza 84 / 153.121,86 · FE yok · farklı mağaza 5 / 1.997,19
              Kart iadeyi FE kaydından aldığı için FE'de olmayan 89 iadeyi düşmez. FE'de kayıtlı 145 iade 6.399.378,40
              (= 6.398.341,12 + 1.037,28); KPI'ın 234 iadesi 6.554.497,45; fark 155.119,05 = FE'de olmayan 89 iade
              (153.121,86 + 1.997,19).
              IADE-AY (ek dosya): Temmuz 1 · Ağustos 42 · Eylül 186 · Ekim 5; toplam 234; Eylül M03 182 iade / 5.290.096,33 = T-001 F.
   Nüfus    : (blok N, 04.10.2026) dönem 8: 7.484 sipariş · 7.711 FE satırı · 7.711 tekil fatura ·
              FE ⋈ Sales 7.711 satır / 7.711 tekil fatura (çoğalma yok); kalemsiz fişli sipariş 0.
              B CokSiparisliFatura = 0; BT dönemsiz (tüm dönemler) = 0 (ek dosya); D FazlaSayilanNet 0,00: fan-out yok.
              DONEM bloğu ve negatif DonemId (−8: 39 sipariş, 17.07–13.09.2026, hiçbiri fişli; −7: 36 sipariş, 2'si fişli; snv.Donem'de
              karşılığı yok, anlamı veriden çıkarılamadı, açık soru): ek dosya DONEM. Kart ve KPI @DonemId = 8 ile bunları dışlar.
   Aynı kaynak — neden: A, ONCE-KPI ile AYNI kaynaktan (FE + Sales + LinkedDocumentId) kurulur;
              kaynak içi kimliktir, bağımsız kanıt DEĞİLDİR.
              Bağımsız yan: C kalem düzeyi (SalesProducts) başlıktan ayrı tablo;
              iade tarafında FE ↔ LinkedDocumentId karşılaştırması.
              Encore dışı bağımsız kaynak yok (ERP'de Sınav faturası günlük özet belgedir).
   Başka ne olabilir: (1) Fan-out: ölçüldü, 0. (2) Kalemsiz sipariş: ölçüldü, 0.
              (3) FE'de çift fatura satırı: 7.709 satır = 7.709 tekil fatura.
              (4) FE iade kaydı eksik (sema: FE kısmi iadeleri kaydetmiyor): ölçüldü, farkın tamamı bu.
              (5) Dönem süzgeci: kart ve KPI aynı.
   Kapsam   : Satış faturası = FE'ye bağlı Sales, DocumentsTypeId <> 3;
              iade = LinkedDocumentId > 0 ile Sınav faturasına (tip 8) bağlı tip 3.
              Net = GrossTotal − DiscountTotal − VatTotal (KDV hariç); iade negatif.
   Dondurma : 18c2ce0
   SSMS     : DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104);  (@DonemId blok içinde türetilir)
   Komut    : sqlcli DECLARE kabul etmez; bloklar DECLARE'siz, literalle koşuldu (--profile erp, --read-only).
   Bloklar  : A kanonik net · B çok siparişli fatura · C kalem kontrolü · D fan-out tutarı · IADE-KAYNAK
              · ONCE-KPI · ONCE-KART (panel gövdeleri) · N nüfus. Ek dosyada: BT · IADE-AY · DONEM · DONEM_ARALIK.
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
        AND i.StoresId = o.StoresId   -- kanal kuralı: iade yalnız orijinal fatura aynı mağazadaysa Sınav'dan düşer
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
        AND i.StoresId = o.StoresId   -- kanal kuralı (A ile aynı)
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
DECLARE @DonemId INT = (
    SELECT TOP (1) d.DonemId
    FROM BKM.snv.Donem AS d
    WHERE d.IslemBaslamaTarih <= @Bas
    ORDER BY d.IslemBaslamaTarih DESC
);

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
DECLARE @DonemId INT = (
    SELECT TOP (1) d.DonemId
    FROM BKM.snv.Donem AS d
    WHERE d.IslemBaslamaTarih <= @Bas
    ORDER BY d.IslemBaslamaTarih DESC
);

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
    MIN(sip.Tarih) AS ilk_siparis_tarihi,
    MAX(sip.Tarih) AS son_siparis_tarihi,
    COUNT(fe.SiparisKod) AS fe_satiri,
    COUNT(DISTINCT fe.InvoiceNo) AS tekil_fatura,
    COUNT(s.Id) AS fe_sales_satiri,
    COUNT(DISTINCT s.Id) AS fe_sales_tekil_fatura,
    COUNT(DISTINCT CASE WHEN sd.SiparisId IS NULL THEN fe.SiparisKod END) AS kalemsiz_fisli_siparis
FROM BKM.snv.Siparis AS sip
    LEFT JOIN BKM.snv.SinavSiparisFisEncore AS fe
        ON sip.SiparisKod = fe.SiparisKod
    LEFT JOIN EncoreMerkez.dbo.Sales AS s
        ON fe.InvoiceNo COLLATE Turkish_CI_AS = s.DocumentNo COLLATE Turkish_CI_AS
    LEFT JOIN Detayli AS sd
        ON sip.SiparisId = sd.SiparisId
WHERE sip.DonemId = @DonemId;
GO

-- blok: IADE-KAYNAK  (dönem iadeleri: LinkedDocumentId bağlı × FE'de kayıtlı mı × aynı mağaza mı; adet ve net KDV hariç, pozitif)
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

Bagli AS (
    SELECT DISTINCT
        i.Id,
        i.DocumentNo,
        CASE WHEN i.StoresId = o.StoresId THEN 1 ELSE 0 END AS ayni_magaza,
        i.GrossTotal - i.DiscountTotal - i.VatTotal AS net_kdv_haric
    FROM EncoreMerkez.dbo.Sales AS i
        INNER JOIN EncoreMerkez.dbo.Sales AS o
            ON
                i.LinkedDocumentId = o.Id
                AND o.DocumentsTypeId = 8
        INNER JOIN BKM.snv.SinavSiparisFisEncore AS feo
            ON feo.InvoiceNo COLLATE Turkish_CI_AS = o.DocumentNo COLLATE Turkish_CI_AS
        INNER JOIN Siparis AS si
            ON feo.SiparisKod = si.SiparisKod
    WHERE
        i.DocumentsTypeId = 3
        AND i.LinkedDocumentId > 0
),

FeIade AS (
    SELECT DISTINCT fe.InvoiceNo
    FROM BKM.snv.SinavSiparisFisEncore AS fe
        INNER JOIN Siparis AS si
            ON fe.SiparisKod = si.SiparisKod
)

SELECT
    CASE WHEN fi.InvoiceNo IS NULL THEN 0 ELSE 1 END AS fe_de_kayitli,
    b.ayni_magaza,
    COUNT(*) AS iade_adet,
    CONVERT(DECIMAL(18, 2), SUM(b.net_kdv_haric)) AS net_kdv_haric
FROM Bagli AS b
    LEFT JOIN FeIade AS fi
        ON b.DocumentNo COLLATE Turkish_CI_AS = fi.InvoiceNo COLLATE Turkish_CI_AS
GROUP BY
    CASE WHEN fi.InvoiceNo IS NULL THEN 0 ELSE 1 END,
    b.ayni_magaza
ORDER BY fe_de_kayitli DESC, b.ayni_magaza DESC;
GO
