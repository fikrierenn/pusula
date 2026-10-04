-- ork:hedef-db EncoreMerkez
-- ork:compat 110
/* Soru     : 00-taban-olcumu.sql'in devamı: G (satış analizi kesim farkı), H/H2 (Sınav kalemsiz sipariş), I (JOKER erişimi),
              J/J2 (merkez depo geçmiş ay okuma envanteri). Sonuç özetleri ve başlık ana dosyadadır.
   AC       : SC-002 (kanıt) · girdi: H6, H8, H9, H13
   Dönem    : 01.09.2026 – 30.09.2026 (bitiş hariç 01.10.2026); G, J, J2 dönemsiz
   Tolerans : birebir (sayım) · ≤ 1,00 TL (tutar)
   Atıf     : 00-taban-olcumu.sql (blok A–F2 ve tüm sonuç satırları; G, H, H2, I, J, J2 sonuçları orada, bu bloklardan üretildi)
   Hedef-db (blok bazlı): G, J, J2 DerinSISBkm · H, H2 BKM + EncoreMerkez (3 parçalı adlar) · I JOKER (bash tools/sq.sh --joker)
   Dondurma : 18c2ce0
*/

-- blok: G
WITH Son AS (
    SELECT MAX(t.Kesim) AS kesim
    FROM DerinSISBkm.bkm.SatisAnaliziTaban AS t
),

Taban AS   -- anahtar (Kesim, SezonYil, stkID): ürün başına tek değer için MAX
(
    SELECT
        t.stkID,
        MAX(t.MerkezStok) AS merkez_stok
    FROM DerinSISBkm.bkm.SatisAnaliziTaban AS t
        INNER JOIN Son AS sn
            ON t.Kesim = sn.kesim
    GROUP BY t.stkID
),

Canli AS (
    SELECT
        w.stkID,
        SUM(w.Stok) AS stok
    FROM DerinSISBkm.depo.stok_adres_palet_vw AS w
    WHERE w.adrsAlanTipID IN (0, 1)
    GROUP BY w.stkID
)

SELECT
    (SELECT sn.kesim FROM Son AS sn) AS kesim_tarihi,
    (
        SELECT MAX(t2.Uretim)
        FROM DerinSISBkm.bkm.SatisAnaliziTaban AS t2
            INNER JOIN Son AS sn2
                ON t2.Kesim = sn2.kesim
    ) AS taban_uretim_zamani,   -- tablodaki tek zaman damgası (Uretim); MerkezStok üretim anında canlı WMS'ten dolar
    GETDATE() AS sorgu_zamani,
    (SELECT COUNT(*) FROM Taban) AS urun_sayisi,
    SUM(tbn.merkez_stok) AS taban_merkez_adet,
    SUM(ISNULL(c.stok, 0)) AS canli_wms_adet,
    SUM(ISNULL(c.stok, 0)) - SUM(tbn.merkez_stok) AS fark_adet,
    100.0 * (SUM(ISNULL(c.stok, 0)) - SUM(tbn.merkez_stok)) / NULLIF(SUM(tbn.merkez_stok), 0) AS fark_yuzde
FROM Taban AS tbn
    LEFT JOIN Canli AS c
        ON tbn.stkID = c.stkID;

-- blok: H
DECLARE @BasTarih DATE = CONVERT(DATE, '01.09.2026', 104), @BitTarih DATE = CONVERT(DATE, '01.10.2026', 104);   -- dönem sipariş tarihinden
WITH Siparis AS (
    SELECT
        sip.SiparisId,
        sip.SiparisKod
    FROM BKM.snv.Siparis AS sip
    WHERE
        sip.Tarih >= @BasTarih
        AND sip.Tarih < @BitTarih
        AND NOT EXISTS (
            SELECT 1 FROM BKM.snv.SiparisDetay AS sd
            WHERE sd.SiparisId = sip.SiparisId
        )
),

Fis AS (
    SELECT DISTINCT
        si.SiparisKod,
        s.Id AS satis_id,
        s.DocumentsTypeId,
        s.GrossTotal,
        s.DiscountTotal,
        s.VatTotal
    FROM Siparis AS si
        INNER JOIN BKM.snv.SinavSiparisFisEncore AS fe
            ON si.SiparisKod = fe.SiparisKod
        INNER JOIN EncoreMerkez.dbo.Sales AS s
            ON fe.InvoiceNo COLLATE Turkish_CI_AS = s.DocumentNo COLLATE Turkish_CI_AS   -- DocumentNo tekil değil: blok H2
)

SELECT
    (
        SELECT COUNT(*) FROM BKM.snv.Siparis AS x
        WHERE x.Tarih >= @BasTarih AND x.Tarih < @BitTarih
    ) AS eylul_siparis,
    (
        SELECT COUNT(DISTINCT x.DonemId) FROM BKM.snv.Siparis AS x
        WHERE x.Tarih >= @BasTarih AND x.Tarih < @BitTarih
    ) AS donem_sayisi,
    (
        SELECT MIN(x.DonemId) FROM BKM.snv.Siparis AS x
        WHERE x.Tarih >= @BasTarih AND x.Tarih < @BitTarih
    ) AS min_donem_id,
    (
        SELECT MAX(x.DonemId) FROM BKM.snv.Siparis AS x
        WHERE x.Tarih >= @BasTarih AND x.Tarih < @BitTarih
    ) AS maks_donem_id,
    (SELECT COUNT(*) FROM Siparis) AS kalemsiz_siparis,
    (SELECT COUNT(DISTINCT f2.SiparisKod) FROM Fis AS f2) AS fisli_kalemsiz_siparis,
    ISNULL(SUM(CASE
        WHEN f.DocumentsTypeId = 3
            THEN -(f.GrossTotal - f.DiscountTotal - f.VatTotal)
        ELSE (f.GrossTotal - f.DiscountTotal - f.VatTotal)
    END), 0) AS kalemsiz_net_kdv_haric
FROM Fis AS f;

-- blok: H2
DECLARE @BasTarih DATE = CONVERT(DATE, '01.09.2026', 104), @BitTarih DATE = CONVERT(DATE, '01.10.2026', 104);
-- H'nin DocumentNo birleşmesi fan-out yapıyor mu: Eylül Sınav siparişlerinin fatura numarası kaç Encore belgesine eşleşiyor
WITH Fe AS (
    SELECT DISTINCT fe.InvoiceNo
    FROM BKM.snv.Siparis AS sip
        INNER JOIN BKM.snv.SinavSiparisFisEncore AS fe
            ON sip.SiparisKod = fe.SiparisKod
    WHERE
        sip.Tarih >= @BasTarih
        AND sip.Tarih < @BitTarih
),

Es AS (
    SELECT
        f.InvoiceNo,
        COUNT(DISTINCT s.Id) AS belge
    FROM Fe AS f
        INNER JOIN EncoreMerkez.dbo.Sales AS s
            ON f.InvoiceNo COLLATE Turkish_CI_AS = s.DocumentNo COLLATE Turkish_CI_AS
    GROUP BY f.InvoiceNo
)

SELECT
    (SELECT COUNT(*) FROM Fe) AS fatura_no_sayisi,
    COUNT(*) AS eslesen_fatura_no,
    SUM(CASE WHEN es.belge > 1 THEN 1 ELSE 0 END) AS cok_belgeli_fatura_no,
    MAX(es.belge) AS en_cok_belge
FROM Es AS es;

-- blok: I
-- JOKER doğrudan bağlantı testi: bash tools/sq.sh --joker "SELECT 1 AS Bagli"
SELECT 1 AS Bagli;

-- blok: J
DECLARE
    @SonDonemAltSinir DATE
    = (
        SELECT DATEADD(MONTH, -6, MAX(x.Donem))
        FROM DerinSISBkm.bkm.StokAyBakiyeMekanBazli AS x
        WHERE x.ehMekan = 12
    );
SELECT TOP (12)
    b.Donem AS donem_tarihi,
    b.Kaynak AS kaynak_adi,
    COUNT(*) AS satir,
    SUM(CONVERT(BIGINT, b.Stok)) AS stok_toplam
FROM DerinSISBkm.bkm.StokAyBakiyeMekanBazli AS b
WHERE
    b.ehMekan = 12
    AND b.Donem >= @SonDonemAltSinir
GROUP BY b.Donem, b.Kaynak
ORDER BY b.Donem DESC, b.Kaynak ASC;

-- blok: J2
SELECT
    b.Kaynak AS kaynak_adi,
    b.ehMekan AS mekan_id,
    COUNT(DISTINCT b.Donem) AS donem_sayisi,
    MIN(b.Donem) AS ilk_donem,
    MAX(b.Donem) AS son_donem
FROM DerinSISBkm.bkm.StokAyBakiyeMekanBazli AS b
GROUP BY b.Kaynak, b.ehMekan
ORDER BY b.Kaynak, b.ehMekan;
