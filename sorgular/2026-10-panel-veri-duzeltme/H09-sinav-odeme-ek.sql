-- ork:hedef-db EncoreMerkez
-- ork:compat 110
/* Soru     : H09-sinav-odeme.sql'in dönem ve iade ara ölçümleri: dönem türetmesi bitiş koşulsuz mu, iadeler ay × mağaza nasıl dağılıyor?
              Ana dosya: H09-sinav-odeme.sql (20 KB sınırı nedeniyle BT, IADE-AY, DONEM burada).
   AC       : AC-9.1, AC-9.2 · Spec 001 · H09 · T-019 düzeltme geçişi
   Dönem    : @Bas = 01.09.2026; @DonemId ana dosyayla AYNI metinle türetilir (IADE-AY bloğunda). Dönem 8 açık: sayılar 04.10.2026
              koşusuna aittir.
   Tolerans : sayı birebir; tutar ≤ 1 TL
   Önce     : yok (ara ölçüm dosyası)
   Sonra    : yok
   Bağımsız : (04.10.2026)
              BT B'nin dönemsiz karşılığı: tüm dönemlerde birden çok siparişe bağlı satış faturası 0.
              IADE-AY (ay × mağaza, kanal kuralı öncesi 234 iade): Temmuz 1 · Ağustos 42 (M01 1 · M02 2 · M03 39) · Eylül 186
                (M01 1 · M02 3 · M03 182; M03 5.290.096,33, T-001 F ile aynı) · Ekim 5; toplam 234 (ana dosya IADE-KAYNAK 143 + 2 + 84 +
              5).
              DONEM Eylül tarihli siparişler: DonemId 8 → 5.395 (01.09–30.09) · 7 → 1 (08.09) · −8 → 5 (02.09–13.09); snv.Donem'de 1, 4,
              5, 6, 7, 8
                tanımlı; −8 tanımsız (anlamı veriden çıkarılamadı, açık soru; kart ve KPI @DonemId = 8 ile dışlar).
              DONEM_ARALIK: snv.Donem'de bitiş kolonu YOK (IslemBaslamaTarih ve YariYil); dönem türetmesi
                IslemBaslamaTarih <= @Bas ORDER BY DESC bitiş koşulsuzdur: sonraki dönem başlayana kadar son başlamış dönem geçerli
              sayılır.
                Dönem 7 (01.06.2025) ile 8 (16.07.2026) arasında @Bas hangi tarihte olursa olsun 7 gelir; blok her dönemin sonraki
              başlangıcını
                ve aralık dışı sipariş sayısını verir.
                Ölçüm: dönem 8 → 7.484 sipariş, aralık dışı 0 · 7 → 8.724 / 1 · 6 → 8.928 / 1 · 5 → 9.794 / 1.190 · 1 → 13 / 13 · 4 → 0 /
              0.
   Nüfus    : yok (ana dosya blok N geçerli).
   Aynı kaynak — neden: kaynak içi: hepsi BKM.snv ve Encore Sales; bağımsız kaynak yok (ERP'de Sınav faturası günlük özet belgedir).
   Başka ne olabilir: (1) Aralık dışı sipariş, dönem sınırının sipariş tarihinden farklı tanımlandığını gösterir. (2) Negatif DonemId
              testten kalma olabilir.
   Kapsam   : iade = LinkedDocumentId > 0 ile Sınav faturasına (tip 8) bağlı tip 3; net KDV hariç, pozitif.
   Dondurma : 18c2ce0
   SSMS     : DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104);  (@DonemId blok içinde türetilir)
   Komut    : sqlcli DECLARE kabul etmez; bloklar DECLARE'siz, literalle koşuldu (--profile erp, --read-only).
   Bloklar  : BT · IADE-AY · DONEM · DONEM_ARALIK
*/

-- blok: BT  (B'nin dönemsiz karşılığı: tüm dönemlerde birden çok siparişe bağlı satış faturası)
SELECT COUNT(*) AS CokSiparisliFaturaTumDonem
FROM (
    SELECT s.Id
    FROM BKM.snv.SinavSiparisFisEncore AS fe
        INNER JOIN EncoreMerkez.dbo.Sales AS s
            ON fe.InvoiceNo COLLATE Turkish_CI_AS = s.DocumentNo COLLATE Turkish_CI_AS
    WHERE s.DocumentsTypeId <> 3
    GROUP BY s.Id
    HAVING COUNT(DISTINCT fe.SiparisKod) > 1
) AS x;
GO

-- blok: IADE-AY  (dönem iadeleri ay × mağaza; LinkedDocumentId bağlı, kanal kuralı öncesi tümü; pozitif net KDV hariç)
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
        i.StoresId,
        YEAR(i.[Date]) AS yil,
        MONTH(i.[Date]) AS ay,
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
)

SELECT
    b.yil,
    b.ay,
    st.Code AS magaza_kodu,
    COUNT(*) AS iade_adet,
    CONVERT(DECIMAL(18, 2), SUM(b.net_kdv_haric)) AS net_kdv_haric
FROM Bagli AS b
    INNER JOIN EncoreMerkez.dbo.Stores AS st
        ON b.StoresId = st.Id
GROUP BY b.yil, b.ay, st.Code
ORDER BY b.yil, b.ay, st.Code;
GO

-- blok: DONEM  (Eylül tarihli siparişlerin DonemId dağılımı; snv.Donem'de karşılığı olmayan = negatif dönemler)
DECLARE @Bas DATE = CONVERT(DATE, '01.09.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104);  -- DMY

SELECT
    sip.DonemId,
    CASE WHEN d.DonemId IS NULL THEN 0 ELSE 1 END AS snv_donem_var,
    COUNT(*) AS siparis_sayisi,
    MIN(sip.Tarih) AS ilk_tarih,
    MAX(sip.Tarih) AS son_tarih
FROM BKM.snv.Siparis AS sip
    LEFT JOIN BKM.snv.Donem AS d
        ON sip.DonemId = d.DonemId
WHERE
    sip.Tarih >= @Bas
    AND sip.Tarih < @Bit
GROUP BY
    sip.DonemId,
    CASE WHEN d.DonemId IS NULL THEN 0 ELSE 1 END
ORDER BY sip.DonemId DESC;
GO

-- blok: DONEM_ARALIK  (her dönemin başlangıcı, sonraki başlangıcı ve kendi aralığı dışında kalan sipariş sayısı)
SELECT
    d.DonemId,
    d.IslemBaslamaTarih AS Baslangic,
    nx.sonraki AS SonrakiBaslangic,
    COUNT(sip.SiparisId) AS Siparis,
    SUM(CASE
        WHEN sip.Tarih < d.IslemBaslamaTarih THEN 1
        WHEN nx.sonraki IS NOT NULL AND sip.Tarih >= nx.sonraki THEN 1
        ELSE 0
    END) AS AralikDisi
FROM BKM.snv.Donem AS d
    OUTER APPLY (
        SELECT MIN(x.IslemBaslamaTarih) AS sonraki
        FROM BKM.snv.Donem AS x
        WHERE x.IslemBaslamaTarih > d.IslemBaslamaTarih
    ) AS nx
    LEFT JOIN BKM.snv.Siparis AS sip
        ON d.DonemId = sip.DonemId
GROUP BY d.DonemId, d.IslemBaslamaTarih, nx.sonraki
ORDER BY d.DonemId;
GO
