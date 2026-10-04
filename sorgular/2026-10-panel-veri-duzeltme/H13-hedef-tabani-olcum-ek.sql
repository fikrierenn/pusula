-- ork:hedef-db EncoreMerkez
-- ork:compat 110
/* Soru     : Hedef KDV dahil mi hariç mi kurulmuş: Kitap (KDV %0) ile Kırtasiye (%20) çifti hangi tabanda aynı oranı veriyor?
   AC       : AC-13.4, AC-13.5 (girdi) · plan K-C (KDV ayırıcısı) · Spec 001 · H13 · H13-hedef-tabani-olcum.sql'in D ve E blokları
   Dönem    : D, E: Temmuz 2025 – Eylül 2026, 01.07.2025 – 01.10.2026 (bitiş hariç)
              Encore'da veri olan aylar; Temmuz 2025 kısmi ay (POS geçişi)
   Tolerans : ölçüm; kesim seçilmez, iki taban kıyaslanır
   Önce     : H13-hedef-tabani-olcum.sql başlığı (plan K-C tek ay Eylül; dosya dışı: plan.md)
   Sonra    : yok (öneri belgesi GMY teyidini bekler)
   Bağımsız : YOK. D ve E aynı Encore kaleminden ve aynı hedef tablosundan kurulur; kaynak içi ölçümdür.
   Aynı kaynak — neden: hedefin tek kaynağı BKMDATA.dbo.Hedef; gerçekleşen yalnız Encore kaleminde ürün kırılımlı.
   Başka ne olabilir: (1) Kategori hedefi geçen yıl cirosundan türetilmişse oran KDV'den bağımsız sapar (E bunu sınar);
              (2) Kitap/Kırtasiye ürün karması oranı 1,20'den uzaklaştırır (beklenen_dahil_hedef çiftin kendi gerçekleşenlerinden
              ölçülür); (3) Tem-2025 kısmi ay (kismi / kismi_taban ayrı gruptur).
   Dondurma : (denetleyici yazar; H13-hedef-tabani-olcum.sql'den bölündü)
   SSMS     : DECLARE @DBas date = CONVERT(date, '01.07.2025', 104), @DBit date = CONVERT(date, '01.10.2026', 104);
   Komut    : her blok ayrı koşulur (D/E 120 sn üstü sürer: --timeout 600); sqlcli DMY reddeder, bu yüzden SSMS DECLARE esas;
              04.10.2026 koşusunda literal, --profile encore, --max-rows 1000.
   Özet     : medyan ve aralık PERCENTILE_CONT ile; bootstrap yoktur.
   Kapsam   : Encore kalem, ürün bazlı (Products.Code = urn.stkID), belge 1,2,3,6,7,8 (iade negatif), mağaza 1/4477/4478,
              BarcodeNo 1001 hariç, yalnız Kitap (15) ve Kırtasiye (12). Hariç = TotalPrice − VatTotal; Dahil = TotalPrice.
              Ürün kodu (T-014 kuralı): Code COLLATE Latin1_General_BIN2 NOT LIKE '%[^0-9]%' AND LEN(Code) BETWEEN 1 AND 9;
              CONVERT yalnız CASE THEN dalında (D ve E Kalem CTE, iki yer). Kalem gövdesi ana dosyadaki A/B/C ile aynıdır.
   Koşu     : 04.10.2026 (sqlcli, encore profili, --read-only; ürün kodu kuralı SONRASI yeniden koşuldu).
              Satır sayıları: D 45 çift · E 9 çift.
              D (Tem-2025..Eyl-2026): çift oranı KDV hariç medyan 0,977 [Q1 0,914 · Q3 1,032 · en küçük 0,747 · en büyük 1,657];
              beklenen (hedef KDV dahil olsaydı) çift medyanı 1,17; 45 çiftin 37'si 1,00 tarafında (tam 42 çift medyan 0,975 ·
              kısmi ay 3 çift medyan 1,027). Mağaza medyanları (15'er çift): FSM 0,955 · Özlüce 0,994 · İst.Yolu 0,893.
              Binom p (tek yönlü, 37/45): 0,000007687; çiftler tam bağımsız değil (aynı mağazanın ardışık ayları).
              E (9 çift): medyan 1,085, 4/9 hariç tarafında; kısmi taban (Tem-2025) 3 çift medyan 1,008, tam taban 6 çift medyan 1,123.
   Not      : Kalem CTE'de urn INNER JOIN'dir (A/B/C'deki LEFT JOIN'den farklı): urn'de karşılığı olmayan kalem D/E'de düşer;
              zaten yalnız Kitap (15) ve Kırtasiye (12) kategorisi aranır. D'deki Terim özyinelemesi n + 1 adımdır (n = çift sayısı,
              en çok 3 mağaza × 15 ay = 45); varsayılan sınır 100'ü aşan bir n blok hatası verir, sessiz kesme olmaz.
              Çıktıda mekan_ad (posMagaza.mekanAd) mekan_id ile birlikte verilir.
   Bloklar  : D Kitap/Kırtasiye mağaza×ay eşli · E hedef 2026 / gerçek 2025
*/

-- blok: D  (Kitap 15 ↔ Kırtasiye 12, mağaza × ay eşli; her satır bir çift)
-- beklenen_dahil_hedef = (Kırtasiye dahil/hariç) / (Kitap dahil/hariç), o çiftin kendi gerçekleşenlerinden ölçülür
--   (ürün karması yüzünden tam 1,20 değil).
-- haric_tarafinda = oran, 1,00 ile beklenen_dahil_hedef arasındaki geometrik orta noktanın (karekök) altında ise 1.
-- Mantık: aynı mağaza ve ayda iki kategorinin hedef/gerçek oranı aynı tabanla kurulmuşsa oran_kirtasiye / oran_kitap, KDV hariç tabanda
--   hedef KDV DAHİL ise ≈ 1,20 (Kırtasiye %20, Kitap %0), hedef KDV HARİÇ ise ≈ 1,00. Çift = hedefi ve gerçekleşeni > 0 olan iki kategori.
-- kismi_ay: Temmuz 2025'te Encore'da 23.990 satış belgesi var (Ağustos 75.545; POS geçişi; dosya dışı ölçüm 04.10.2026,
--   tip 1,2,3,6,7,8, tüm mağaza Sales sayımı) → ayrı grup. Özet sütunları: tum / kismi_ay gruplarına göre.
/* tsqllint-disable non-sargable */
WITH Kalem AS (
    SELECT
        DATEFROMPARTS(YEAR(s.[Date]), MONTH(s.[Date]), 1) AS ay_bas,
        pm.mekanID AS mekan_id,
        ISNULL(CONVERT(INT, u.urnKtgr2ID), -1) AS ktg_id,
        CASE WHEN s.DocumentsTypeId = 3 THEN -1 ELSE 1 END * (sp.TotalPrice - sp.VatTotal) AS tutar_haric,
        CASE WHEN s.DocumentsTypeId = 3 THEN -1 ELSE 1 END * sp.TotalPrice AS tutar_dahil,
        CASE WHEN s.DocumentsTypeId = 3 THEN -1 ELSE 1 END * (sp.TotalPrice - sp.VatTotal) * ISNULL(kd.kdvYuzde, 0) AS kdv_agirlik
    FROM EncoreMerkez.dbo.Sales AS s
        INNER JOIN EncoreMerkez.dbo.Pos AS ps
            ON s.PosId = ps.Id
        INNER JOIN EncoreMerkez.dbo.Stores AS st
            ON ps.StoreId = st.Id
        INNER JOIN DerinSISBkm.dbo.posMagaza AS pm
            ON pm.mekanKod COLLATE Turkish_CI_AS = st.Code COLLATE Turkish_CI_AS
        INNER JOIN EncoreMerkez.dbo.SalesProducts AS sp
            ON
                s.Id = sp.SalesId
                AND sp.IsValid = 1
                AND sp.BarcodeNo <> '1001'
        INNER JOIN EncoreMerkez.dbo.Products AS p
            ON sp.ProductsId = p.Id
        INNER JOIN DerinSISBkm.dbo.urn AS u
            ON u.stkID = CASE
                WHEN p.Code COLLATE Latin1_General_BIN2 NOT LIKE '%[^0-9]%' AND LEN(p.Code) BETWEEN 1 AND 9
                    THEN CONVERT(INT, p.Code)
            END
        LEFT JOIN DerinSISBkm.dbo.urnKDV AS kd
            ON u.KDVs = kd.kdvID
    WHERE
        s.[Date] >= @DBas
        AND s.[Date] < @DBit
        AND s.DocumentsTypeId IN (1, 2, 3, 6, 7, 8)
        AND pm.mekanID IN (1, 4477, 4478)
        AND u.urnKtgr2ID IN (12, 15)
),

Gercek AS (
    SELECT
        k.ay_bas,
        k.mekan_id,
        k.ktg_id,
        SUM(k.tutar_haric) AS gercek_haric,
        SUM(k.tutar_dahil) AS gercek_dahil
    FROM Kalem AS k
    GROUP BY k.ay_bas, k.mekan_id, k.ktg_id
),

Hedef AS (
    SELECT
        DATEFROMPARTS(h.yil, h.ay, 1) AS ay_bas,
        h.mekanId AS mekan_id,
        h.ktgId AS ktg_id,
        SUM(h.hedef) AS hedef
    FROM BKMDATA.dbo.Hedef AS h
    WHERE
        h.tarih >= @DBas
        AND h.tarih < @DBit
        AND h.mekanId IN (1, 4477, 4478)
        AND h.ktgId IN (12, 15)
    GROUP BY DATEFROMPARTS(h.yil, h.ay, 1), h.mekanId, h.ktgId
),

Aylik AS (
    SELECT
        g.ay_bas,
        g.mekan_id,
        g.ktg_id,
        hd.hedef,
        g.gercek_haric,
        g.gercek_dahil
    FROM Gercek AS g
        INNER JOIN Hedef AS hd
            ON
                g.ay_bas = hd.ay_bas
                AND g.mekan_id = hd.mekan_id
                AND g.ktg_id = hd.ktg_id
    WHERE
        hd.hedef > 0
        AND g.gercek_haric > 0
        AND g.gercek_dahil > 0
),

Cift AS (
    SELECT
        kr.ay_bas,
        kr.mekan_id,
        CASE WHEN kr.ay_bas = @DBas THEN 'kismi' ELSE 'tam' END AS ay_durumu,
        kr.hedef AS hedef_kirtasiye,
        kr.gercek_haric AS gercek_haric_kirtasiye,
        kr.gercek_dahil AS gercek_dahil_kirtasiye,
        kt.hedef AS hedef_kitap,
        kt.gercek_haric AS gercek_haric_kitap,
        kt.gercek_dahil AS gercek_dahil_kitap,
        (kr.hedef / kr.gercek_haric) / (kt.hedef / kt.gercek_haric) AS cift_orani_haric,
        (kr.hedef / kr.gercek_dahil) / (kt.hedef / kt.gercek_dahil) AS cift_orani_dahil,
        (kr.gercek_dahil / kr.gercek_haric) / (kt.gercek_dahil / kt.gercek_haric) AS beklenen_dahil_hedef
    FROM Aylik AS kr
        INNER JOIN Aylik AS kt
            ON
                kr.ay_bas = kt.ay_bas
                AND kr.mekan_id = kt.mekan_id
                AND kt.ktg_id = 15
    WHERE kr.ktg_id = 12
),

Sayim AS (
    SELECT
        COUNT(*) AS n,
        SUM(CASE WHEN c.cift_orani_haric < SQRT(c.beklenen_dahil_hedef) THEN 1 ELSE 0 END) AS k
    FROM Cift AS c
),

Terim AS (
    SELECT
        0 AS i,
        CONVERT(DECIMAL(38, 0), 1) AS binom_kat,
        sy.n,
        sy.k
    FROM Sayim AS sy
    UNION ALL
    SELECT
        te.i + 1 AS i,
        CONVERT(DECIMAL(38, 0), te.binom_kat * (te.n - te.i) / (te.i + 1)) AS binom_kat,
        te.n,
        te.k
    FROM Terim AS te
    WHERE te.i < te.n
),

BinomP AS (
    -- Tek yönlü binom kuyruğu: P(X >= k), X ~ Binom(n, 0,5).
    -- Çiftler tam bağımsız değil (aynı mağazanın ardışık ayları), p yalnız yaklaşık güçtür.
    SELECT
        CONVERT(FLOAT(53), SUM(CASE WHEN te.i >= te.k THEN te.binom_kat ELSE 0 END))   -- ork:izin RUN-005 olasılık, para değil
        / POWER(CONVERT(FLOAT(53), 2), MAX(te.n)) AS kuyruk_p   -- ork:izin RUN-005 olasılık, para değil
    FROM Terim AS te
)

SELECT
    c.ay_bas,
    c.mekan_id,
    CONVERT(NVARCHAR(40), pm3.mekanAd) AS mekan_ad,
    c.ay_durumu,
    CONVERT(DECIMAL(18, 0), c.hedef_kirtasiye) AS hedef_kirtasiye,
    CONVERT(DECIMAL(18, 0), c.gercek_haric_kirtasiye) AS gercek_haric_kirtasiye,
    CONVERT(DECIMAL(18, 0), c.gercek_dahil_kirtasiye) AS gercek_dahil_kirtasiye,
    CONVERT(DECIMAL(18, 0), c.hedef_kitap) AS hedef_kitap,
    CONVERT(DECIMAL(18, 0), c.gercek_haric_kitap) AS gercek_haric_kitap,
    CONVERT(DECIMAL(18, 0), c.gercek_dahil_kitap) AS gercek_dahil_kitap,
    CONVERT(DECIMAL(9, 4), c.cift_orani_haric) AS cift_orani_haric,
    CONVERT(DECIMAL(9, 4), c.cift_orani_dahil) AS cift_orani_dahil,
    CONVERT(DECIMAL(9, 4), c.beklenen_dahil_hedef) AS beklenen_dahil_hedef,
    CASE WHEN c.cift_orani_haric < SQRT(c.beklenen_dahil_hedef) THEN 1 ELSE 0 END AS haric_tarafinda,
    SUM(CASE WHEN c.cift_orani_haric < SQRT(c.beklenen_dahil_hedef) THEN 1 ELSE 0 END) OVER () AS haric_tarafinda_toplam,
    CONVERT(DECIMAL(9, 4), PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY c.beklenen_dahil_hedef) OVER ()) AS medyan_beklenen_dahil_hedef,
    CONVERT(INT, COUNT(*) OVER ()) AS cift_sayisi,
    CONVERT(DECIMAL(9, 4), PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY c.cift_orani_haric) OVER ()) AS medyan_haric,
    CONVERT(DECIMAL(9, 4), PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY c.cift_orani_haric) OVER ()) AS ceyrek1_haric,
    CONVERT(DECIMAL(9, 4), PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY c.cift_orani_haric) OVER ()) AS ceyrek3_haric,
    CONVERT(DECIMAL(9, 4), MIN(c.cift_orani_haric) OVER ()) AS en_kucuk_haric,
    CONVERT(DECIMAL(9, 4), MAX(c.cift_orani_haric) OVER ()) AS en_buyuk_haric,
    CONVERT(DECIMAL(9, 4), PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY c.cift_orani_dahil) OVER ()) AS medyan_dahil,
    CONVERT(DECIMAL(9, 4), MIN(c.cift_orani_dahil) OVER ()) AS en_kucuk_dahil,
    CONVERT(DECIMAL(9, 4), MAX(c.cift_orani_dahil) OVER ()) AS en_buyuk_dahil,
    CONVERT(INT, COUNT(*) OVER (PARTITION BY c.ay_durumu)) AS durum_cift_sayisi,
    CONVERT(DECIMAL(9, 4), PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY c.cift_orani_haric) OVER (PARTITION BY c.ay_durumu))
        AS durum_medyan_haric,
    CONVERT(INT, COUNT(*) OVER (PARTITION BY c.mekan_id)) AS magaza_cift_sayisi,
    CONVERT(DECIMAL(9, 4), PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY c.cift_orani_haric) OVER (PARTITION BY c.mekan_id))
        AS magaza_medyan_haric,
    CONVERT(DECIMAL(18, 9), bp.kuyruk_p) AS binom_p_tek_yonlu
FROM Cift AS c
    CROSS JOIN BinomP AS bp
    LEFT JOIN DerinSISBkm.dbo.posMagaza AS pm3
        ON c.mekan_id = pm3.mekanID
ORDER BY c.ay_bas, c.mekan_id;
/* tsqllint-enable non-sargable */

-- blok: E  (hedef 2026 / gerçek 2025, aynı ay ve kategori; hangi tabanda düzleşiyor)
-- Mantık: 2026 hedefi geçen yılın aynı ay satışından türetilmişse hedef / gerçek(2025) oranı hangi tabanda
--   Kitap ile Kırtasiye arasında eşitlenir?
-- Encore verisi olan 2025 ayları (Tem-2025 kısmi) ↔ aynı ayların 2026 hedefi (Tem-Eyl 2026).
/* tsqllint-disable non-sargable */
WITH Kalem AS (
    SELECT
        DATEFROMPARTS(YEAR(s.[Date]), MONTH(s.[Date]), 1) AS ay_bas,
        pm.mekanID AS mekan_id,
        ISNULL(CONVERT(INT, u.urnKtgr2ID), -1) AS ktg_id,
        CASE WHEN s.DocumentsTypeId = 3 THEN -1 ELSE 1 END * (sp.TotalPrice - sp.VatTotal) AS tutar_haric,
        CASE WHEN s.DocumentsTypeId = 3 THEN -1 ELSE 1 END * sp.TotalPrice AS tutar_dahil,
        CASE WHEN s.DocumentsTypeId = 3 THEN -1 ELSE 1 END * (sp.TotalPrice - sp.VatTotal) * ISNULL(kd.kdvYuzde, 0) AS kdv_agirlik
    FROM EncoreMerkez.dbo.Sales AS s
        INNER JOIN EncoreMerkez.dbo.Pos AS ps
            ON s.PosId = ps.Id
        INNER JOIN EncoreMerkez.dbo.Stores AS st
            ON ps.StoreId = st.Id
        INNER JOIN DerinSISBkm.dbo.posMagaza AS pm
            ON pm.mekanKod COLLATE Turkish_CI_AS = st.Code COLLATE Turkish_CI_AS
        INNER JOIN EncoreMerkez.dbo.SalesProducts AS sp
            ON
                s.Id = sp.SalesId
                AND sp.IsValid = 1
                AND sp.BarcodeNo <> '1001'
        INNER JOIN EncoreMerkez.dbo.Products AS p
            ON sp.ProductsId = p.Id
        INNER JOIN DerinSISBkm.dbo.urn AS u
            ON u.stkID = CASE
                WHEN p.Code COLLATE Latin1_General_BIN2 NOT LIKE '%[^0-9]%' AND LEN(p.Code) BETWEEN 1 AND 9
                    THEN CONVERT(INT, p.Code)
            END
        LEFT JOIN DerinSISBkm.dbo.urnKDV AS kd
            ON u.KDVs = kd.kdvID
    WHERE
        s.[Date] >= @DBas
        AND s.[Date] < @DBit
        AND s.DocumentsTypeId IN (1, 2, 3, 6, 7, 8)
        AND pm.mekanID IN (1, 4477, 4478)
        AND u.urnKtgr2ID IN (12, 15)
),

Gercek AS (
    SELECT
        k.ay_bas,
        k.mekan_id,
        k.ktg_id,
        SUM(k.tutar_haric) AS gercek_haric,
        SUM(k.tutar_dahil) AS gercek_dahil
    FROM Kalem AS k
    GROUP BY k.ay_bas, k.mekan_id, k.ktg_id
),

Hedef AS (
    SELECT
        DATEFROMPARTS(h.yil, h.ay, 1) AS ay_bas,
        h.mekanId AS mekan_id,
        h.ktgId AS ktg_id,
        SUM(h.hedef) AS hedef
    FROM BKMDATA.dbo.Hedef AS h
    WHERE
        h.tarih >= @DBas
        AND h.tarih < @DBit
        AND h.mekanId IN (1, 4477, 4478)
        AND h.ktgId IN (12, 15)
    GROUP BY DATEFROMPARTS(h.yil, h.ay, 1), h.mekanId, h.ktgId
),

Eslesen AS (
    SELECT
        hd.ay_bas,
        hd.mekan_id,
        hd.ktg_id,
        hd.hedef AS hedef_2026,
        g.gercek_haric AS gercek_haric_2025,
        g.gercek_dahil AS gercek_dahil_2025
    FROM Hedef AS hd
        INNER JOIN Gercek AS g
            ON
                g.ay_bas = DATEADD(YEAR, -1, hd.ay_bas)
                AND hd.mekan_id = g.mekan_id
                AND hd.ktg_id = g.ktg_id
    WHERE
        hd.hedef > 0
        AND g.gercek_haric > 0
        AND g.gercek_dahil > 0
        AND hd.ay_bas >= DATEADD(YEAR, 1, @DBas)
),

Cift AS (
    SELECT
        kr.ay_bas,
        kr.mekan_id,
        CASE WHEN kr.ay_bas = DATEADD(YEAR, 1, @DBas) THEN 'kismi_taban' ELSE 'tam' END AS taban_durumu,
        kr.hedef_2026 AS hedef_kirtasiye,
        kt.hedef_2026 AS hedef_kitap,
        kr.gercek_haric_2025 AS gercek25_haric_kirtasiye,
        kt.gercek_haric_2025 AS gercek25_haric_kitap,
        (kr.hedef_2026 / kr.gercek_haric_2025) / (kt.hedef_2026 / kt.gercek_haric_2025) AS cift_orani_haric,
        (kr.hedef_2026 / kr.gercek_dahil_2025) / (kt.hedef_2026 / kt.gercek_dahil_2025) AS cift_orani_dahil,
        (kr.gercek_dahil_2025 / kr.gercek_haric_2025) / (kt.gercek_dahil_2025 / kt.gercek_haric_2025) AS beklenen_dahil_hedef
    FROM Eslesen AS kr
        INNER JOIN Eslesen AS kt
            ON
                kr.ay_bas = kt.ay_bas
                AND kr.mekan_id = kt.mekan_id
                AND kt.ktg_id = 15
    WHERE kr.ktg_id = 12
)

SELECT
    c.ay_bas,
    c.mekan_id,
    CONVERT(NVARCHAR(40), pm3.mekanAd) AS mekan_ad,
    c.taban_durumu,
    CONVERT(DECIMAL(18, 0), c.hedef_kirtasiye) AS hedef_kirtasiye,
    CONVERT(DECIMAL(18, 0), c.gercek25_haric_kirtasiye) AS gercek25_haric_kirtasiye,
    CONVERT(DECIMAL(18, 0), c.hedef_kitap) AS hedef_kitap,
    CONVERT(DECIMAL(18, 0), c.gercek25_haric_kitap) AS gercek25_haric_kitap,
    CONVERT(DECIMAL(9, 4), c.cift_orani_haric) AS cift_orani_haric,
    CONVERT(DECIMAL(9, 4), c.cift_orani_dahil) AS cift_orani_dahil,
    CONVERT(DECIMAL(9, 4), c.beklenen_dahil_hedef) AS beklenen_dahil_hedef,
    CASE WHEN c.cift_orani_haric < SQRT(c.beklenen_dahil_hedef) THEN 1 ELSE 0 END AS haric_tarafinda,
    SUM(CASE WHEN c.cift_orani_haric < SQRT(c.beklenen_dahil_hedef) THEN 1 ELSE 0 END) OVER () AS haric_tarafinda_toplam,
    CONVERT(DECIMAL(9, 4), PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY c.beklenen_dahil_hedef) OVER ()) AS medyan_beklenen_dahil_hedef,
    CONVERT(INT, COUNT(*) OVER (PARTITION BY c.taban_durumu)) AS taban_cift_sayisi,
    CONVERT(DECIMAL(9, 4), PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY c.cift_orani_haric) OVER (PARTITION BY c.taban_durumu))
        AS taban_medyan_haric,
    CONVERT(INT, COUNT(*) OVER ()) AS cift_sayisi,
    CONVERT(DECIMAL(9, 4), PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY c.cift_orani_haric) OVER ()) AS medyan_haric,
    CONVERT(DECIMAL(9, 4), PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY c.cift_orani_haric) OVER ()) AS ceyrek1_haric,
    CONVERT(DECIMAL(9, 4), PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY c.cift_orani_haric) OVER ()) AS ceyrek3_haric,
    CONVERT(DECIMAL(9, 4), MIN(c.cift_orani_haric) OVER ()) AS en_kucuk_haric,
    CONVERT(DECIMAL(9, 4), MAX(c.cift_orani_haric) OVER ()) AS en_buyuk_haric,
    CONVERT(DECIMAL(9, 4), PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY c.cift_orani_dahil) OVER ()) AS medyan_dahil,
    CONVERT(DECIMAL(9, 4), MIN(c.cift_orani_dahil) OVER ()) AS en_kucuk_dahil,
    CONVERT(DECIMAL(9, 4), MAX(c.cift_orani_dahil) OVER ()) AS en_buyuk_dahil
FROM Cift AS c
    LEFT JOIN DerinSISBkm.dbo.posMagaza AS pm3
        ON c.mekan_id = pm3.mekanID
ORDER BY c.ay_bas, c.mekan_id;
/* tsqllint-enable non-sargable */
