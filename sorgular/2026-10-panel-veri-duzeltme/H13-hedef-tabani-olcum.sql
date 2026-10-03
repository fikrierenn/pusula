-- ork:hedef-db EncoreMerkez
-- ork:compat 110
/* Soru     : Ana sayfadaki hedef hangi tabanla girilmis: KDV dahil mi, KDV hariç mi? Sınav ve merkez depo hedefte var mı?
   AC       : AC-13.4, AC-13.5 (girdi) · plan K-C üç adım · Spec 001 · H13
   Dönem    : A, B, C: Nisan–Eylül 2026, 01.04.2026 – 01.10.2026 (bitiş hariç)
              D, E   : Temmuz 2025 – Eylül 2026, 01.07.2025 – 01.10.2026 (Encore'da veri olan aylar; Tem-2025 kısmi ay, POS geçişi)
   Tolerans : ölçüm; kesim seçilmez, iki taban kıyaslanır
   Önce     : plan K-C tek ay (Eylül): FSM 1,40 → 1,32 · Özlüce 1,25 → 1,17 · İst.Yolu 1,08 → 1,06 (hariç → dahil)
   Sonra    : yok (öneri belgesi GMY teyidini bekler)
   Bağımsız : YOK. Blok A toplamı = blok C toplamı yalnız iç tutarlılık kontrolüdür (ikisi de aynı Encore kaleminden,
              aynı süzgeçle kurulu); bağımsız kaynakla (posOzetUrun / irsHrk) mutabakat bu görevde yapılmadı.
   Aynı kaynak — neden: hedefin tek kaynağı BKMDATA.dbo.Hedef; gerçekleşen yalnız Encore kaleminde ürün (kategori) kırılımlı;
              panelin okuduğu taban Encore kalemidir, panelle aynı tabanı ölçmek amaç.
   Başka ne olabilir: (1) Hedef KDV'siz kurulmuş ama iade/indirim farkı oranı oynatıyor olabilir; (2) kategori hedefi geçen yıl
              cirosundan türetilmişse oran KDV'den bağımsız sapar (blok E bunu sınar); (3) Sınav hedefi ürün bazlı olduğundan
              mağaza kapsamı farkı oranı bozabilir. Ölçüm bunları ayırmaz, yalnız gösterir.
   Dondurma : d83f324
   SSMS     : DECLARE @Bas date = CONVERT(date, '01.04.2026', 104), @Bit date = CONVERT(date, '01.10.2026', 104),
                      @DBas date = CONVERT(date, '01.07.2025', 104), @DBit date = CONVERT(date, '01.10.2026', 104);
   Komut    : her blok ayrı koşulur; sqlcli --param ISO tarih ister (DMY reddeder), bu yüzden SSMS DECLARE'i esas alınır.
              sqlcli query --profile erp --read-only --max-rows 100000 --param bas:date=<ISO> --param bit:date=<ISO> "<blok>"
   Özet     : medyan ve aralık (en küçük, çeyrekler, en büyük) bloklarda PERCENTILE_CONT ile hesaplanır; bootstrap yoktur.
   Kapsam   : Gerçekleşen = Encore kalem, ürün bazlı (Products.Code = urn.stkID), belge 1,2,3,6,7,8 (iade negatif),
              mağaza 1/4477/4478. Hariç = TotalPrice − VatTotal ; Dahil = TotalPrice (indirim düşülmüş, KDV dahil).
              BarcodeNo 1001 hariç: panelin bugünkü kategori neti (dashboard/Data/Queries.cs katNetSql) bu kalemi dışlıyor ve
              plan K-B 1001'i geri dönüşüm kalemi sayıyor; satış cirosu değil, panelle aynı tabanı ölçmek için dışlandı.
              Hedef kategorisi = urn.urnKtgr2ID (urnKtgrID2 DEĞİL — o kolon ürünlerin %78'inde 0). Hedef ktgId 0/255 ayrı satır.
   Koşu 1   : 03.10.2026 (sqlcli, erp profili, --read-only). Satır sayıları: A 125 · B 12 · C 9 · D 45 çift · E 9 çift.
              A↔C iç tutarlılık: 3 mağaza hedef 833.862.171 ve gerçekleşen KDV hariç 859.242.353 iki blokta aynı.
              D (Tem-2025..Eyl-2026): çift oranı KDV hariç medyan 0,977 [Q1 0,914 · Q3 1,032 · en küçük 0,747 · en büyük 1,657];
              beklenen (hedef KDV dahil olsaydı) çift medyanı 1,17; 45 çiftin 37'si 1,00 tarafında. E (9 çift): medyan 1,085, 4/9 hariç tarafında.
   Bloklar  : A ay×kategori · B kategori×6 ay (KDV grubu, eşik, grup medyanı) · C mekân · D Kitap/Kırtasiye mağaza×ay eşli · E hedef 2026 / gerçek 2025
*/

-- blok: A  (ay × kategori)
/* tsqllint-disable non-sargable */
WITH Kalem AS (
    SELECT
        DATEFROMPARTS(YEAR(s.[Date]), MONTH(s.[Date]), 1) AS ay_bas,
        pm.mekanID AS mekan_id,
        ISNULL(u.urnKtgr2ID, 0) AS ktg_id,
        CASE WHEN s.DocumentsTypeId = 3 THEN -1 ELSE 1 END * (sp.TotalPrice - sp.VatTotal) AS tutar_haric,
        CASE WHEN s.DocumentsTypeId = 3 THEN -1 ELSE 1 END * sp.TotalPrice AS tutar_dahil,
        CASE WHEN s.DocumentsTypeId = 3 THEN -1 ELSE 1 END * (sp.TotalPrice - sp.VatTotal) * ISNULL(kd.kdvYuzde, 0) AS kdv_agirlik
    FROM EncoreMerkez.dbo.Sales AS s
        INNER JOIN EncoreMerkez.dbo.Pos AS ps
            ON ps.Id = s.PosId
        INNER JOIN EncoreMerkez.dbo.Stores AS st
            ON st.Id = ps.StoreId
        INNER JOIN DerinSISBkm.dbo.posMagaza AS pm
            ON pm.mekanKod COLLATE Turkish_CI_AS = st.Code COLLATE Turkish_CI_AS
        INNER JOIN EncoreMerkez.dbo.SalesProducts AS sp
            ON sp.SalesId = s.Id
            AND sp.IsValid = 1
            AND sp.BarcodeNo <> '1001'
        INNER JOIN EncoreMerkez.dbo.Products AS p
            ON p.Id = sp.ProductsId
        LEFT JOIN DerinSISBkm.dbo.urn AS u
            ON u.stkID = CASE
                WHEN ISNUMERIC(p.Code) = 1 AND p.Code NOT LIKE '%[^0-9]%' AND LEN(p.Code) <= 9
                    THEN CONVERT(INT, p.Code)
            END
        LEFT JOIN DerinSISBkm.dbo.urnKDV AS kd
            ON kd.kdvID = u.KDVs
    WHERE s.[Date] >= @Bas
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
    WHERE h.tarih >= @Bas
        AND h.tarih < @Bit
        AND h.mekanId IN (1, 4477, 4478)
    GROUP BY DATEFROMPARTS(h.yil, h.ay, 1), h.ktgId
)

SELECT
    COALESCE(g.ay_bas, hd.ay_bas) AS ay_bas,
    COALESCE(g.ktg_id, hd.ktg_id) AS ktg_id,
    CAST(kt.ktgrAd AS NVARCHAR(40)) AS kategori,
    CAST(g.kdv_orani_urun AS DECIMAL(9, 2)) AS kdv_orani_urun,
    CAST(hd.hedef AS DECIMAL(18, 0)) AS hedef,
    CAST(g.gercek_haric AS DECIMAL(18, 0)) AS gercek_haric,
    CAST(g.gercek_dahil AS DECIMAL(18, 0)) AS gercek_dahil,
    CAST(CASE WHEN g.gercek_haric > 0 THEN hd.hedef / g.gercek_haric END AS DECIMAL(9, 3)) AS oran_haric,
    CAST(CASE WHEN g.gercek_dahil > 0 THEN hd.hedef / g.gercek_dahil END AS DECIMAL(9, 3)) AS oran_dahil
FROM Gercek AS g
    FULL OUTER JOIN Hedef AS hd
        ON hd.ay_bas = g.ay_bas
        AND hd.ktg_id = g.ktg_id
    LEFT JOIN DerinSISBkm.dbo.urnKtgr2 AS kt
        ON kt.ktgrID = COALESCE(g.ktg_id, hd.ktg_id)
ORDER BY COALESCE(g.ay_bas, hd.ay_bas), COALESCE(hd.hedef, 0) DESC;
/* tsqllint-enable non-sargable */

-- blok: B  (kategori × 6 ay toplam; KDV grubu, eşik ve grup medyanı burada)
-- Eşik: 6 ay hedef toplamı >= 1.000.000 TL ve gerçekleşen > 0 (küçük paydalı oran gürültü; ölçülmüş değil, seçilmiş bir eşik).
-- Sınav Okulları (19) dışlanır: hedefi yalnız Eylül'de dolu, Ağustos'ta gerçek 100M+ iken hedef 0 (blok A); altı aylık oran anlamsız.
-- KDV grubu (ağırlıklı ürün KDV oranı): 'KDV>=10' / 'KDV<3' / 'ara'. Gerekçe: Kitap %0 ↔ Kırtasiye %20 ayrımı. Grup medyanı grup içi kategori oranlarından.
/* tsqllint-disable non-sargable */
WITH Kalem AS (
    SELECT
        DATEFROMPARTS(YEAR(s.[Date]), MONTH(s.[Date]), 1) AS ay_bas,
        pm.mekanID AS mekan_id,
        ISNULL(u.urnKtgr2ID, 0) AS ktg_id,
        CASE WHEN s.DocumentsTypeId = 3 THEN -1 ELSE 1 END * (sp.TotalPrice - sp.VatTotal) AS tutar_haric,
        CASE WHEN s.DocumentsTypeId = 3 THEN -1 ELSE 1 END * sp.TotalPrice AS tutar_dahil,
        CASE WHEN s.DocumentsTypeId = 3 THEN -1 ELSE 1 END * (sp.TotalPrice - sp.VatTotal) * ISNULL(kd.kdvYuzde, 0) AS kdv_agirlik
    FROM EncoreMerkez.dbo.Sales AS s
        INNER JOIN EncoreMerkez.dbo.Pos AS ps
            ON ps.Id = s.PosId
        INNER JOIN EncoreMerkez.dbo.Stores AS st
            ON st.Id = ps.StoreId
        INNER JOIN DerinSISBkm.dbo.posMagaza AS pm
            ON pm.mekanKod COLLATE Turkish_CI_AS = st.Code COLLATE Turkish_CI_AS
        INNER JOIN EncoreMerkez.dbo.SalesProducts AS sp
            ON sp.SalesId = s.Id
            AND sp.IsValid = 1
            AND sp.BarcodeNo <> '1001'
        INNER JOIN EncoreMerkez.dbo.Products AS p
            ON p.Id = sp.ProductsId
        LEFT JOIN DerinSISBkm.dbo.urn AS u
            ON u.stkID = CASE
                WHEN ISNUMERIC(p.Code) = 1 AND p.Code NOT LIKE '%[^0-9]%' AND LEN(p.Code) <= 9
                    THEN CONVERT(INT, p.Code)
            END
        LEFT JOIN DerinSISBkm.dbo.urnKDV AS kd
            ON kd.kdvID = u.KDVs
    WHERE s.[Date] >= @Bas
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
    WHERE h.tarih >= @Bas
        AND h.tarih < @Bit
        AND h.mekanId IN (1, 4477, 4478)
    GROUP BY h.ktgId
),

Kat AS (
    SELECT
        g.ktg_id,
        CAST(kt.ktgrAd AS NVARCHAR(40)) AS kategori,
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
            ON hd.ktg_id = g.ktg_id
        LEFT JOIN DerinSISBkm.dbo.urnKtgr2 AS kt
            ON kt.ktgrID = g.ktg_id
    WHERE hd.hedef >= 1000000
        AND g.gercek_haric > 0
        AND g.ktg_id <> 19
)

SELECT
    ka.ktg_id,
    ka.kategori,
    CAST(ka.kdv_orani_urun AS DECIMAL(9, 2)) AS kdv_orani_urun,
    ka.kdv_grubu,
    CAST(ka.hedef AS DECIMAL(18, 0)) AS hedef,
    CAST(ka.gercek_haric AS DECIMAL(18, 0)) AS gercek_haric,
    CAST(ka.gercek_dahil AS DECIMAL(18, 0)) AS gercek_dahil,
    CAST(ka.oran_haric AS DECIMAL(9, 3)) AS oran_haric,
    CAST(ka.oran_dahil AS DECIMAL(9, 3)) AS oran_dahil,
    COUNT(*) OVER (PARTITION BY ka.kdv_grubu) AS grup_kategori_sayisi,
    CAST(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ka.oran_haric) OVER (PARTITION BY ka.kdv_grubu) AS DECIMAL(9, 3)) AS grup_medyan_haric,
    CAST(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY ka.oran_dahil) OVER (PARTITION BY ka.kdv_grubu) AS DECIMAL(9, 3)) AS grup_medyan_dahil,
    CAST(MIN(ka.oran_haric) OVER (PARTITION BY ka.kdv_grubu) AS DECIMAL(9, 3)) AS grup_en_kucuk_haric,
    CAST(MAX(ka.oran_haric) OVER (PARTITION BY ka.kdv_grubu) AS DECIMAL(9, 3)) AS grup_en_buyuk_haric,
    CAST(MIN(ka.oran_dahil) OVER (PARTITION BY ka.kdv_grubu) AS DECIMAL(9, 3)) AS grup_en_kucuk_dahil,
    CAST(MAX(ka.oran_dahil) OVER (PARTITION BY ka.kdv_grubu) AS DECIMAL(9, 3)) AS grup_en_buyuk_dahil
FROM Kat AS ka
ORDER BY ka.hedef DESC;
/* tsqllint-enable non-sargable */

-- blok: C  (mekân düzeyi: hedef, 3 mağaza gerçekleşen, mekân 12 ve diğerleri)
-- Soru: mekân 12 hedefi var mı, kart kapsamına giriyor mu? Gerçekleşen yalnız Encore mağazalarında vardır.
-- magaza_kartinda = ETİKET, kanıt değil: panel kapsamı kodda sabit (dashboard/Data/Queries.cs:74,232 mekanId IN (1,4477,4478)); sütun o listeyi tekrarlar.
/* tsqllint-disable non-sargable */
WITH Kalem AS (
    SELECT
        DATEFROMPARTS(YEAR(s.[Date]), MONTH(s.[Date]), 1) AS ay_bas,
        pm.mekanID AS mekan_id,
        ISNULL(u.urnKtgr2ID, 0) AS ktg_id,
        CASE WHEN s.DocumentsTypeId = 3 THEN -1 ELSE 1 END * (sp.TotalPrice - sp.VatTotal) AS tutar_haric,
        CASE WHEN s.DocumentsTypeId = 3 THEN -1 ELSE 1 END * sp.TotalPrice AS tutar_dahil,
        CASE WHEN s.DocumentsTypeId = 3 THEN -1 ELSE 1 END * (sp.TotalPrice - sp.VatTotal) * ISNULL(kd.kdvYuzde, 0) AS kdv_agirlik
    FROM EncoreMerkez.dbo.Sales AS s
        INNER JOIN EncoreMerkez.dbo.Pos AS ps
            ON ps.Id = s.PosId
        INNER JOIN EncoreMerkez.dbo.Stores AS st
            ON st.Id = ps.StoreId
        INNER JOIN DerinSISBkm.dbo.posMagaza AS pm
            ON pm.mekanKod COLLATE Turkish_CI_AS = st.Code COLLATE Turkish_CI_AS
        INNER JOIN EncoreMerkez.dbo.SalesProducts AS sp
            ON sp.SalesId = s.Id
            AND sp.IsValid = 1
            AND sp.BarcodeNo <> '1001'
        INNER JOIN EncoreMerkez.dbo.Products AS p
            ON p.Id = sp.ProductsId
        LEFT JOIN DerinSISBkm.dbo.urn AS u
            ON u.stkID = CASE
                WHEN ISNUMERIC(p.Code) = 1 AND p.Code NOT LIKE '%[^0-9]%' AND LEN(p.Code) <= 9
                    THEN CONVERT(INT, p.Code)
            END
        LEFT JOIN DerinSISBkm.dbo.urnKDV AS kd
            ON kd.kdvID = u.KDVs
    WHERE s.[Date] >= @Bas
        AND s.[Date] < @Bit
        AND s.DocumentsTypeId IN (1, 2, 3, 6, 7, 8)
        AND pm.mekanID IN (1, 4477, 4478)
),

Hedef AS (
    SELECT
        h.mekanId AS mekan_id,
        SUM(h.hedef) AS hedef
    FROM BKMDATA.dbo.Hedef AS h
    WHERE h.tarih >= @Bas
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
    CAST(pm2.mekanAd AS NVARCHAR(40)) AS mekan_ad,
    CASE WHEN COALESCE(hd.mekan_id, g.mekan_id) IN (1, 4477, 4478) THEN 'evet' ELSE 'hayir' END AS magaza_kartinda,
    CAST(hd.hedef AS DECIMAL(18, 0)) AS hedef,
    CAST(g.gercek_haric AS DECIMAL(18, 0)) AS gercek_haric,
    CAST(g.gercek_dahil AS DECIMAL(18, 0)) AS gercek_dahil
FROM Hedef AS hd
    FULL OUTER JOIN Gercek AS g
        ON g.mekan_id = hd.mekan_id
    LEFT JOIN DerinSISBkm.dbo.posMagaza AS pm2
        ON pm2.mekanID = COALESCE(hd.mekan_id, g.mekan_id)
ORDER BY COALESCE(hd.hedef, 0) DESC;
/* tsqllint-enable non-sargable */

-- blok: D  (Kitap 15 ↔ Kırtasiye 12, mağaza × ay eşli; her satır bir çift)
-- beklenen_dahil_hedef = (Kırtasiye dahil/hariç) / (Kitap dahil/hariç), o çiftin kendi gerçekleşenlerinden ölçülür (ürün karması yüzünden tam 1,20 değil).
-- haric_tarafinda = oran, 1,00 ile beklenen_dahil_hedef arasındaki geometrik orta noktanın (karekök) altında ise 1.
-- Mantık: aynı mağaza ve ayda iki kategorinin hedef/gerçek oranı aynı tabanla kurulmuşsa oran_kirtasiye / oran_kitap, KDV hariç tabanda
--   hedef KDV DAHİL ise ≈ 1,20 (Kırtasiye %20, Kitap %0), hedef KDV HARİÇ ise ≈ 1,00. Çift = hedefi ve gerçekleşeni > 0 olan iki kategori.
-- kismi_ay: Temmuz 2025'te Encore'da 23.990 satış var (Ağustos 75.545; POS geçişi) → ayrı grup. Özet sütunları: tum / kismi_ay gruplarına göre.
/* tsqllint-disable non-sargable */
WITH Kalem AS (
    SELECT
        DATEFROMPARTS(YEAR(s.[Date]), MONTH(s.[Date]), 1) AS ay_bas,
        pm.mekanID AS mekan_id,
        ISNULL(u.urnKtgr2ID, 0) AS ktg_id,
        CASE WHEN s.DocumentsTypeId = 3 THEN -1 ELSE 1 END * (sp.TotalPrice - sp.VatTotal) AS tutar_haric,
        CASE WHEN s.DocumentsTypeId = 3 THEN -1 ELSE 1 END * sp.TotalPrice AS tutar_dahil,
        CASE WHEN s.DocumentsTypeId = 3 THEN -1 ELSE 1 END * (sp.TotalPrice - sp.VatTotal) * ISNULL(kd.kdvYuzde, 0) AS kdv_agirlik
    FROM EncoreMerkez.dbo.Sales AS s
        INNER JOIN EncoreMerkez.dbo.Pos AS ps
            ON ps.Id = s.PosId
        INNER JOIN EncoreMerkez.dbo.Stores AS st
            ON st.Id = ps.StoreId
        INNER JOIN DerinSISBkm.dbo.posMagaza AS pm
            ON pm.mekanKod COLLATE Turkish_CI_AS = st.Code COLLATE Turkish_CI_AS
        INNER JOIN EncoreMerkez.dbo.SalesProducts AS sp
            ON sp.SalesId = s.Id
            AND sp.IsValid = 1
            AND sp.BarcodeNo <> '1001'
        INNER JOIN EncoreMerkez.dbo.Products AS p
            ON p.Id = sp.ProductsId
        INNER JOIN DerinSISBkm.dbo.urn AS u
            ON u.stkID = CASE
                WHEN ISNUMERIC(p.Code) = 1 AND p.Code NOT LIKE '%[^0-9]%' AND LEN(p.Code) <= 9
                    THEN CONVERT(INT, p.Code)
            END
        LEFT JOIN DerinSISBkm.dbo.urnKDV AS kd
            ON kd.kdvID = u.KDVs
    WHERE s.[Date] >= @DBas
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
    WHERE h.tarih >= @DBas
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
            ON hd.ay_bas = g.ay_bas
            AND hd.mekan_id = g.mekan_id
            AND hd.ktg_id = g.ktg_id
    WHERE hd.hedef > 0
        AND g.gercek_haric > 0
        AND g.gercek_dahil > 0
),

Cift AS (
    SELECT
        kr.ay_bas,
        kr.mekan_id,
        CASE WHEN kr.ay_bas = CONVERT(DATE, '01.07.2025', 104) THEN 'kismi' ELSE 'tam' END AS ay_durumu,   -- DMY
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
            ON kt.ay_bas = kr.ay_bas
            AND kt.mekan_id = kr.mekan_id
            AND kt.ktg_id = 15
    WHERE kr.ktg_id = 12
)

SELECT
    c.ay_bas,
    c.mekan_id,
    c.ay_durumu,
    CAST(c.hedef_kirtasiye AS DECIMAL(18, 0)) AS hedef_kirtasiye,
    CAST(c.gercek_haric_kirtasiye AS DECIMAL(18, 0)) AS gercek_haric_kirtasiye,
    CAST(c.gercek_dahil_kirtasiye AS DECIMAL(18, 0)) AS gercek_dahil_kirtasiye,
    CAST(c.hedef_kitap AS DECIMAL(18, 0)) AS hedef_kitap,
    CAST(c.gercek_haric_kitap AS DECIMAL(18, 0)) AS gercek_haric_kitap,
    CAST(c.gercek_dahil_kitap AS DECIMAL(18, 0)) AS gercek_dahil_kitap,
    CAST(c.cift_orani_haric AS DECIMAL(9, 4)) AS cift_orani_haric,
    CAST(c.cift_orani_dahil AS DECIMAL(9, 4)) AS cift_orani_dahil,
    CAST(c.beklenen_dahil_hedef AS DECIMAL(9, 4)) AS beklenen_dahil_hedef,
    CASE WHEN c.cift_orani_haric < SQRT(c.beklenen_dahil_hedef) THEN 1 ELSE 0 END AS haric_tarafinda,
    SUM(CASE WHEN c.cift_orani_haric < SQRT(c.beklenen_dahil_hedef) THEN 1 ELSE 0 END) OVER () AS haric_tarafinda_toplam,
    CAST(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY c.beklenen_dahil_hedef) OVER () AS DECIMAL(9, 4)) AS medyan_beklenen_dahil_hedef,
    CAST(COUNT(*) OVER () AS INT) AS cift_sayisi,
    CAST(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY c.cift_orani_haric) OVER () AS DECIMAL(9, 4)) AS medyan_haric,
    CAST(PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY c.cift_orani_haric) OVER () AS DECIMAL(9, 4)) AS ceyrek1_haric,
    CAST(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY c.cift_orani_haric) OVER () AS DECIMAL(9, 4)) AS ceyrek3_haric,
    CAST(MIN(c.cift_orani_haric) OVER () AS DECIMAL(9, 4)) AS en_kucuk_haric,
    CAST(MAX(c.cift_orani_haric) OVER () AS DECIMAL(9, 4)) AS en_buyuk_haric,
    CAST(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY c.cift_orani_dahil) OVER () AS DECIMAL(9, 4)) AS medyan_dahil,
    CAST(MIN(c.cift_orani_dahil) OVER () AS DECIMAL(9, 4)) AS en_kucuk_dahil,
    CAST(MAX(c.cift_orani_dahil) OVER () AS DECIMAL(9, 4)) AS en_buyuk_dahil,
    CAST(COUNT(*) OVER (PARTITION BY c.ay_durumu) AS INT) AS durum_cift_sayisi,
    CAST(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY c.cift_orani_haric) OVER (PARTITION BY c.ay_durumu) AS DECIMAL(9, 4)) AS durum_medyan_haric
FROM Cift AS c
ORDER BY c.ay_bas, c.mekan_id;
/* tsqllint-enable non-sargable */

-- blok: E  (hedef 2026 / gerçek 2025, aynı ay ve kategori; hangi tabanda düzleşiyor)
-- Mantık: 2026 hedefi geçen yılın aynı ay satışından türetilmişse hedef / gerçek(2025) oranı hangi tabanda Kitap ile Kırtasiye arasında eşitlenir?
-- Encore verisi olan 2025 ayları (Tem-2025 kısmi) ↔ aynı ayların 2026 hedefi (Tem-Eyl 2026).
/* tsqllint-disable non-sargable */
WITH Kalem AS (
    SELECT
        DATEFROMPARTS(YEAR(s.[Date]), MONTH(s.[Date]), 1) AS ay_bas,
        pm.mekanID AS mekan_id,
        ISNULL(u.urnKtgr2ID, 0) AS ktg_id,
        CASE WHEN s.DocumentsTypeId = 3 THEN -1 ELSE 1 END * (sp.TotalPrice - sp.VatTotal) AS tutar_haric,
        CASE WHEN s.DocumentsTypeId = 3 THEN -1 ELSE 1 END * sp.TotalPrice AS tutar_dahil,
        CASE WHEN s.DocumentsTypeId = 3 THEN -1 ELSE 1 END * (sp.TotalPrice - sp.VatTotal) * ISNULL(kd.kdvYuzde, 0) AS kdv_agirlik
    FROM EncoreMerkez.dbo.Sales AS s
        INNER JOIN EncoreMerkez.dbo.Pos AS ps
            ON ps.Id = s.PosId
        INNER JOIN EncoreMerkez.dbo.Stores AS st
            ON st.Id = ps.StoreId
        INNER JOIN DerinSISBkm.dbo.posMagaza AS pm
            ON pm.mekanKod COLLATE Turkish_CI_AS = st.Code COLLATE Turkish_CI_AS
        INNER JOIN EncoreMerkez.dbo.SalesProducts AS sp
            ON sp.SalesId = s.Id
            AND sp.IsValid = 1
            AND sp.BarcodeNo <> '1001'
        INNER JOIN EncoreMerkez.dbo.Products AS p
            ON p.Id = sp.ProductsId
        INNER JOIN DerinSISBkm.dbo.urn AS u
            ON u.stkID = CASE
                WHEN ISNUMERIC(p.Code) = 1 AND p.Code NOT LIKE '%[^0-9]%' AND LEN(p.Code) <= 9
                    THEN CONVERT(INT, p.Code)
            END
        LEFT JOIN DerinSISBkm.dbo.urnKDV AS kd
            ON kd.kdvID = u.KDVs
    WHERE s.[Date] >= @DBas
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
    WHERE h.tarih >= @DBas
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
            ON g.ay_bas = DATEADD(YEAR, -1, hd.ay_bas)
            AND g.mekan_id = hd.mekan_id
            AND g.ktg_id = hd.ktg_id
    WHERE hd.hedef > 0
        AND g.gercek_haric > 0
        AND g.gercek_dahil > 0
        AND hd.ay_bas >= CONVERT(DATE, '01.07.2026', 104)   -- DMY
),

Cift AS (
    SELECT
        kr.ay_bas,
        kr.mekan_id,
        kr.hedef_2026 AS hedef_kirtasiye,
        kt.hedef_2026 AS hedef_kitap,
        kr.gercek_haric_2025 AS gercek25_haric_kirtasiye,
        kt.gercek_haric_2025 AS gercek25_haric_kitap,
        (kr.hedef_2026 / kr.gercek_haric_2025) / (kt.hedef_2026 / kt.gercek_haric_2025) AS cift_orani_haric,
        (kr.hedef_2026 / kr.gercek_dahil_2025) / (kt.hedef_2026 / kt.gercek_dahil_2025) AS cift_orani_dahil,
        (kr.gercek_dahil_2025 / kr.gercek_haric_2025) / (kt.gercek_dahil_2025 / kt.gercek_haric_2025) AS beklenen_dahil_hedef
    FROM Eslesen AS kr
        INNER JOIN Eslesen AS kt
            ON kt.ay_bas = kr.ay_bas
            AND kt.mekan_id = kr.mekan_id
            AND kt.ktg_id = 15
    WHERE kr.ktg_id = 12
)

SELECT
    c.ay_bas,
    c.mekan_id,
    CAST(c.hedef_kirtasiye AS DECIMAL(18, 0)) AS hedef_kirtasiye,
    CAST(c.gercek25_haric_kirtasiye AS DECIMAL(18, 0)) AS gercek25_haric_kirtasiye,
    CAST(c.hedef_kitap AS DECIMAL(18, 0)) AS hedef_kitap,
    CAST(c.gercek25_haric_kitap AS DECIMAL(18, 0)) AS gercek25_haric_kitap,
    CAST(c.cift_orani_haric AS DECIMAL(9, 4)) AS cift_orani_haric,
    CAST(c.cift_orani_dahil AS DECIMAL(9, 4)) AS cift_orani_dahil,
    CAST(c.beklenen_dahil_hedef AS DECIMAL(9, 4)) AS beklenen_dahil_hedef,
    CASE WHEN c.cift_orani_haric < SQRT(c.beklenen_dahil_hedef) THEN 1 ELSE 0 END AS haric_tarafinda,
    SUM(CASE WHEN c.cift_orani_haric < SQRT(c.beklenen_dahil_hedef) THEN 1 ELSE 0 END) OVER () AS haric_tarafinda_toplam,
    CAST(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY c.beklenen_dahil_hedef) OVER () AS DECIMAL(9, 4)) AS medyan_beklenen_dahil_hedef,
    CAST(COUNT(*) OVER () AS INT) AS cift_sayisi,
    CAST(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY c.cift_orani_haric) OVER () AS DECIMAL(9, 4)) AS medyan_haric,
    CAST(PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY c.cift_orani_haric) OVER () AS DECIMAL(9, 4)) AS ceyrek1_haric,
    CAST(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY c.cift_orani_haric) OVER () AS DECIMAL(9, 4)) AS ceyrek3_haric,
    CAST(MIN(c.cift_orani_haric) OVER () AS DECIMAL(9, 4)) AS en_kucuk_haric,
    CAST(MAX(c.cift_orani_haric) OVER () AS DECIMAL(9, 4)) AS en_buyuk_haric,
    CAST(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY c.cift_orani_dahil) OVER () AS DECIMAL(9, 4)) AS medyan_dahil,
    CAST(MIN(c.cift_orani_dahil) OVER () AS DECIMAL(9, 4)) AS en_kucuk_dahil,
    CAST(MAX(c.cift_orani_dahil) OVER () AS DECIMAL(9, 4)) AS en_buyuk_dahil
FROM Cift AS c
ORDER BY c.ay_bas, c.mekan_id;
/* tsqllint-enable non-sargable */
