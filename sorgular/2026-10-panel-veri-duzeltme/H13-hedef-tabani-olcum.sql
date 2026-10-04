-- ork:hedef-db EncoreMerkez
-- ork:compat 110
/* Soru     : Ana sayfadaki hedef hangi tabanla girilmis: KDV dahil mi, KDV hariç mi? Sınav ve merkez depo hedefte var mı?
   AC       : AC-13.4, AC-13.5 (girdi) · plan K-C üç adım · Spec 001 · H13
   Dönem    : A, B, C, F: Nisan–Eylül 2026, 01.04.2026 – 01.10.2026 (bitiş hariç)
              D, E (kardeş dosya H13-hedef-tabani-olcum-ek.sql): Temmuz 2025 – Eylül 2026, 01.07.2025 – 01.10.2026
   Tolerans : ölçüm; kesim seçilmez, iki taban kıyaslanır
   Önce     : dosya dışı: plan.md K-C tek ay (Eylül): FSM 1,40 → 1,32 · Özlüce 1,25 → 1,17 · İst.Yolu 1,08 → 1,06 (hariç → dahil)
   Sonra    : yok (öneri belgesi GMY teyidini bekler)
   Bağımsız : YOK. Blok A toplamı = blok C toplamı yalnız kaynak içi kimliktir (ikisi de aynı Encore kaleminden, aynı süzgeçle
              kurulu); bağımsız kaynakla (posOzetUrun / irsHrk) mutabakat bu görevde yapılmadı.
   Aynı kaynak — neden: hedefin tek kaynağı BKMDATA.dbo.Hedef; gerçekleşen yalnız Encore kaleminde ürün (kategori) kırılımlı;
              panelin okuduğu taban Encore kalemidir, panelle aynı tabanı ölçmek amaç.
   Başka ne olabilir: (1) Hedef KDV'siz kurulmuş ama iade/indirim farkı oranı oynatıyor olabilir; (2) kategori hedefi geçen yıl
              cirosundan türetilmişse oran KDV'den bağımsız sapar (kardeş dosyada blok E bunu sınar); (3) Sınav hedefi ürün bazlı
              olduğundan mağaza kapsamı farkı oranı bozabilir. Ölçüm bunları ayırmaz, yalnız gösterir.
   Dondurma : 18c2ce0
   SSMS     : DECLARE @Bas date = CONVERT(date, '01.04.2026', 104), @Bit date = CONVERT(date, '01.10.2026', 104);
   Komut    : her blok ayrı koşulur; sqlcli --param ISO tarih ister (DMY reddeder), bu yüzden SSMS DECLARE'i esas alınır;
              04.10.2026 koşusunda @Bas/@Bit literalle değiştirildi, --profile encore, --timeout 600, --max-rows 1000.
              sqlcli query --profile encore --read-only --max-rows 1000 "<blok>"
   Özet     : medyan ve aralık (en küçük, çeyrekler, en büyük) bloklarda PERCENTILE_CONT ile hesaplanır; bootstrap yoktur.
   Kapsam   : Gerçekleşen = Encore kalem, ürün bazlı (Products.Code = urn.stkID), belge 1,2,3,6,7,8 (iade negatif),
              mağaza 1/4477/4478. Hariç = TotalPrice − VatTotal ; Dahil = TotalPrice (indirim düşülmüş, KDV dahil).
              BarcodeNo 1001 hariç: panelin bugünkü kategori neti (dashboard/Data/Queries.cs katNetSql) bu kalemi dışlıyor ve
              plan K-B 1001'i geri dönüşüm kalemi sayıyor; satış cirosu değil, panelle aynı tabanı ölçmek için dışlandı.
              Hedef kategorisi = urn.urnKtgr2ID (urnKtgrID2 DEĞİL — o kolon 842.652 üründe 657.949'unda, %78,1, 0; urnKtgr2ID'de 0 yalnız
              131 ürün; dosya dışı ölçüm 04.10.2026, urn sayımı).
              Ürün kodu (T-014 kuralı): Code COLLATE Latin1_General_BIN2 NOT LIKE '%[^0-9]%' AND LEN(Code) BETWEEN 1 AND 9;
              CONVERT yalnız CASE THEN dalında. Bu dosyada üç yerde (A, B, C Kalem CTE), kardeş dosyada iki yerde (D, E).
   Sentinel : Gerçek tarafta urn'de karşılığı olmayan ürün ktg_id = −1 (urnKtgr2ID = 0 olan 131 ürün 0 kalır;
              A'da ktg_id 0 satırı yok, yani satışları bu dönemde yok); hedefteki ktgId 0/255 ile
              birleşmez (eski ISNULL 0 birleşirdi). Ölçüldü 04.10.2026: blok F hedef 8.601 satır, urnKtgr2'de karşılığı olmayan 0;
              yani bu dönemde hedefte sentinel yok, −1 savunmadır. A'nın ktg_id = −1 satırları: Nisan 27.308 · Mayıs 46.427 ·
              Haziran 15.210 · Temmuz 10.298 · Ağustos 9.149 · Eylül 13.756 = 122.148 TL (hariç); Eylül payı D2-kasiyer-ek.sql
              blok Y'deki tek ürünle (13.755,81) uyumlu.
   Koşu     : 04.10.2026 (sqlcli, encore profili, --read-only; ürün kodu kuralı ve −1 sentinel SONRASI yeniden koşuldu).
              Satır sayıları: A 125 · B 12 · C 9 · F 1.
              A↔C kaynak içi kimlik: 3 mağaza hedef 833.862.171 ve gerçekleşen KDV hariç 859.242.353 (C); A satırlarının
              yuvarlanmış toplamı 833.862.170 / 859.242.354 (satır başı yuvarlama, ±1 TL).
   Kalem CTE: A, B, C bloklarında aynıdır (kardeş dosyada D/E aynı gövdeye Kitap-Kırtasiye süzgeci ekler); değişirse dört blok
              birlikte değişir.
   Bloklar  : A ay×kategori · B kategori×6 ay (KDV grubu, eşik, grup medyanı) · C mekân · F hedefte kategorisiz satır (sentinel).
              D ve E: H13-hedef-tabani-olcum-ek.sql (28.494 B tek dosya sqlfluff sınırını aşıyordu; bölündü).
*/

-- blok: A  (ay × kategori)
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
        LEFT JOIN DerinSISBkm.dbo.urn AS u
            ON u.stkID = CASE
                WHEN p.Code COLLATE Latin1_General_BIN2 NOT LIKE '%[^0-9]%' AND LEN(p.Code) BETWEEN 1 AND 9
                    THEN CONVERT(INT, p.Code)
            END
        LEFT JOIN DerinSISBkm.dbo.urnKDV AS kd
            ON u.KDVs = kd.kdvID
    WHERE
        s.[Date] >= @Bas
        AND s.[Date] < @Bit
        AND s.DocumentsTypeId IN (1, 2, 3, 6, 7, 8)
        AND pm.mekanID IN (1, 4477, 4478)
),

Gercek AS (
    SELECT
        k.ay_bas,
        k.ktg_id,
        SUM(k.tutar_haric) AS gercek_haric,
        SUM(k.tutar_dahil) AS gercek_dahil,
        CASE WHEN SUM(k.tutar_haric) <> 0 THEN SUM(k.kdv_agirlik) / SUM(k.tutar_haric) END AS kdv_orani_urun
    FROM Kalem AS k
    GROUP BY k.ay_bas, k.ktg_id
),

Hedef AS (
    SELECT
        DATEFROMPARTS(h.yil, h.ay, 1) AS ay_bas,
        h.ktgId AS ktg_id,
        SUM(h.hedef) AS hedef
    FROM BKMDATA.dbo.Hedef AS h
    WHERE
        h.tarih >= @Bas
        AND h.tarih < @Bit
        AND h.mekanId IN (1, 4477, 4478)
    GROUP BY DATEFROMPARTS(h.yil, h.ay, 1), h.ktgId
)

SELECT
    COALESCE(g.ay_bas, hd.ay_bas) AS ay_bas,
    COALESCE(g.ktg_id, hd.ktg_id) AS ktg_id,
    CONVERT(NVARCHAR(40), kt.ktgrAd) AS kategori,
    CONVERT(DECIMAL(9, 2), g.kdv_orani_urun) AS kdv_orani_urun,
    CONVERT(DECIMAL(18, 0), hd.hedef) AS hedef,
    CONVERT(DECIMAL(18, 0), g.gercek_haric) AS gercek_haric,
    CONVERT(DECIMAL(18, 0), g.gercek_dahil) AS gercek_dahil,
    CONVERT(DECIMAL(9, 3), CASE WHEN g.gercek_haric > 0 THEN hd.hedef / g.gercek_haric END) AS oran_haric,
    CONVERT(DECIMAL(9, 3), CASE WHEN g.gercek_dahil > 0 THEN hd.hedef / g.gercek_dahil END) AS oran_dahil
FROM Gercek AS g
    FULL OUTER JOIN Hedef AS hd
        ON
            g.ay_bas = hd.ay_bas
            AND g.ktg_id = hd.ktg_id
    LEFT JOIN DerinSISBkm.dbo.urnKtgr2 AS kt
        ON kt.ktgrID = COALESCE(g.ktg_id, hd.ktg_id)
ORDER BY COALESCE(g.ay_bas, hd.ay_bas), COALESCE(hd.hedef, 0) DESC;
/* tsqllint-enable non-sargable */

-- blok: B  (kategori × 6 ay toplam; KDV grubu, eşik ve grup medyanı burada)
-- Eşik: 6 ay hedef toplamı >= 1.000.000 TL ve gerçekleşen > 0 (küçük paydalı oran gürültü; ölçülmüş değil, seçilmiş bir eşik).
-- Sınav Okulları (19) dışlanır: hedefi yalnız Eylül'de dolu, Ağustos'ta gerçek 100M+ iken hedef 0 (blok A);
--   altı aylık oran anlamsız.
-- KDV grubu (ağırlıklı ürün KDV oranı): 'KDV>=10' / 'KDV<3' / 'ara'. Gerekçe: Kitap %0 ↔ Kırtasiye %20 ayrımı.
--   Grup medyanı grup içi kategori oranlarından.
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
        LEFT JOIN DerinSISBkm.dbo.urn AS u
            ON u.stkID = CASE
                WHEN p.Code COLLATE Latin1_General_BIN2 NOT LIKE '%[^0-9]%' AND LEN(p.Code) BETWEEN 1 AND 9
                    THEN CONVERT(INT, p.Code)
            END
        LEFT JOIN DerinSISBkm.dbo.urnKDV AS kd
            ON u.KDVs = kd.kdvID
    WHERE
        s.[Date] >= @Bas
        AND s.[Date] < @Bit
        AND s.DocumentsTypeId IN (1, 2, 3, 6, 7, 8)
        AND pm.mekanID IN (1, 4477, 4478)
),

Gercek AS (
    SELECT
        k.ktg_id,
        SUM(k.tutar_haric) AS gercek_haric,
        SUM(k.tutar_dahil) AS gercek_dahil,
        CASE WHEN SUM(k.tutar_haric) <> 0 THEN SUM(k.kdv_agirlik) / SUM(k.tutar_haric) END AS kdv_orani_urun
    FROM Kalem AS k
    GROUP BY k.ktg_id
),

Hedef AS (
    SELECT
        h.ktgId AS ktg_id,
        SUM(h.hedef) AS hedef
    FROM BKMDATA.dbo.Hedef AS h
    WHERE
        h.tarih >= @Bas
        AND h.tarih < @Bit
        AND h.mekanId IN (1, 4477, 4478)
    GROUP BY h.ktgId
),

Kat AS (
    SELECT
        g.ktg_id,
        CONVERT(NVARCHAR(40), kt.ktgrAd) AS kategori,
        g.kdv_orani_urun,
        CASE
            WHEN g.kdv_orani_urun >= 10 THEN 'KDV>=10'
            WHEN g.kdv_orani_urun < 3 THEN 'KDV<3'
            ELSE 'ara'
        END AS kdv_grubu,
        hd.hedef,
        g.gercek_haric,
        g.gercek_dahil,
        hd.hedef / g.gercek_haric AS oran_haric,
        hd.hedef / g.gercek_dahil AS oran_dahil
    FROM Gercek AS g
        INNER JOIN Hedef AS hd
            ON g.ktg_id = hd.ktg_id
        LEFT JOIN DerinSISBkm.dbo.urnKtgr2 AS kt
            ON g.ktg_id = kt.ktgrID
    WHERE
        hd.hedef >= 1000000
        AND g.gercek_haric > 0
        AND g.ktg_id <> 19
)

SELECT
    ka.ktg_id,
    ka.kategori,
    CONVERT(DECIMAL(9, 2), ka.kdv_orani_urun) AS kdv_orani_urun,
    ka.kdv_grubu,
    CONVERT(DECIMAL(18, 0), ka.hedef) AS hedef,
    CONVERT(DECIMAL(18, 0), ka.gercek_haric) AS gercek_haric,
    CONVERT(DECIMAL(18, 0), ka.gercek_dahil) AS gercek_dahil,
    CONVERT(DECIMAL(9, 3), ka.oran_haric) AS oran_haric,
    CONVERT(DECIMAL(9, 3), ka.oran_dahil) AS oran_dahil,
    COUNT(*) OVER (PARTITION BY ka.kdv_grubu) AS grup_kategori_sayisi,
    CONVERT(DECIMAL(9, 3), PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ka.oran_haric) OVER (PARTITION BY ka.kdv_grubu))
        AS grup_medyan_haric,
    CONVERT(DECIMAL(9, 3), PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ka.oran_dahil) OVER (PARTITION BY ka.kdv_grubu))
        AS grup_medyan_dahil,
    CONVERT(DECIMAL(9, 3), MIN(ka.oran_haric) OVER (PARTITION BY ka.kdv_grubu)) AS grup_en_kucuk_haric,
    CONVERT(DECIMAL(9, 3), MAX(ka.oran_haric) OVER (PARTITION BY ka.kdv_grubu)) AS grup_en_buyuk_haric,
    CONVERT(DECIMAL(9, 3), MIN(ka.oran_dahil) OVER (PARTITION BY ka.kdv_grubu)) AS grup_en_kucuk_dahil,
    CONVERT(DECIMAL(9, 3), MAX(ka.oran_dahil) OVER (PARTITION BY ka.kdv_grubu)) AS grup_en_buyuk_dahil
FROM Kat AS ka
ORDER BY ka.hedef DESC;
/* tsqllint-enable non-sargable */

-- blok: C  (mekân düzeyi: hedef, 3 mağaza gerçekleşen, mekân 12 ve diğerleri)
-- Soru: mekân 12 hedefi var mı, kart kapsamına giriyor mu? Gerçekleşen yalnız Encore mağazalarında vardır.
-- magaza_kartinda = ETİKET, kanıt değil: panel kapsamı kodda sabit
--   (dashboard/Data/Queries.cs:74,232 mekanId IN (1,4477,4478)); sütun o listeyi tekrarlar.
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
        LEFT JOIN DerinSISBkm.dbo.urn AS u
            ON u.stkID = CASE
                WHEN p.Code COLLATE Latin1_General_BIN2 NOT LIKE '%[^0-9]%' AND LEN(p.Code) BETWEEN 1 AND 9
                    THEN CONVERT(INT, p.Code)
            END
        LEFT JOIN DerinSISBkm.dbo.urnKDV AS kd
            ON u.KDVs = kd.kdvID
    WHERE
        s.[Date] >= @Bas
        AND s.[Date] < @Bit
        AND s.DocumentsTypeId IN (1, 2, 3, 6, 7, 8)
        AND pm.mekanID IN (1, 4477, 4478)
),

Hedef AS (
    SELECT
        h.mekanId AS mekan_id,
        SUM(h.hedef) AS hedef
    FROM BKMDATA.dbo.Hedef AS h
    WHERE
        h.tarih >= @Bas
        AND h.tarih < @Bit
    GROUP BY h.mekanId
),

Gercek AS (
    SELECT
        k.mekan_id,
        SUM(k.tutar_haric) AS gercek_haric,
        SUM(k.tutar_dahil) AS gercek_dahil
    FROM Kalem AS k
    GROUP BY k.mekan_id
)

SELECT
    COALESCE(hd.mekan_id, g.mekan_id) AS mekan_id,
    CONVERT(NVARCHAR(40), pm2.mekanAd) AS mekan_ad,
    CASE WHEN COALESCE(hd.mekan_id, g.mekan_id) IN (1, 4477, 4478) THEN 'evet' ELSE 'hayir' END AS magaza_kartinda,
    CONVERT(DECIMAL(18, 0), hd.hedef) AS hedef,
    CONVERT(DECIMAL(18, 0), g.gercek_haric) AS gercek_haric,
    CONVERT(DECIMAL(18, 0), g.gercek_dahil) AS gercek_dahil
FROM Hedef AS hd
    FULL OUTER JOIN Gercek AS g
        ON hd.mekan_id = g.mekan_id
    LEFT JOIN DerinSISBkm.dbo.posMagaza AS pm2
        ON pm2.mekanID = COALESCE(hd.mekan_id, g.mekan_id)
ORDER BY COALESCE(hd.hedef, 0) DESC;
/* tsqllint-enable non-sargable */

-- blok: F  (sıfır sentinel kontrolü: hedefte urnKtgr2'de karşılığı olmayan ktgId; gerçek tarafta kategorisiz ürün A ve C'de ktg_id = -1)
-- Hedefte 0 / 255 gibi bir sentinel olsaydı, gerçek tarafın kategorisiz ürünü (eski ISNULL 0) onunla sessizce birleşirdi.
DECLARE @Bas DATE = CONVERT(DATE, '01.04.2026', 104), @Bit DATE = CONVERT(DATE, '01.10.2026', 104);  -- DMY

SELECT
    COUNT(*) AS hedef_satir,
    SUM(CASE WHEN kt.ktgrID IS NULL THEN 1 ELSE 0 END) AS kategorisiz_hedef_satir
FROM BKMDATA.dbo.Hedef AS h
    LEFT JOIN DerinSISBkm.dbo.urnKtgr2 AS kt
        ON h.ktgId = kt.ktgrID
WHERE
    h.tarih >= @Bas
    AND h.tarih < @Bit
    AND h.mekanId IN (1, 4477, 4478);
