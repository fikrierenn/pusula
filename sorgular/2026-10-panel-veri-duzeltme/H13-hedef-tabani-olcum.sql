-- ork:hedef-db EncoreMerkez
-- ork:compat 110
/* Soru     : Ana sayfadaki hedef hangi tabanla girilmis: KDV dahil mi, KDV hariç mi? Sınav ve merkez depo hedefte var mı?
   AC       : AC-13.4, AC-13.5 (girdi) · plan K-C üç adım · Spec 001 · H13
   Dönem    : Nisan–Eylül 2026 (6 kapalı ay), 01.04.2026 – 01.10.2026 (bitiş hariç)
   Tolerans : ölçüm; kesim seçilmez, iki taban kıyaslanır
   Önce     : plan K-C tek ay (Eylül): FSM 1,40 → 1,32 · Özlüce 1,25 → 1,17 · İst.Yolu 1,08 → 1,06 (hariç → dahil)
   Sonra    : yok (öneri belgesi GMY teyidini bekler)
   Bağımsız : blok A ay×kategori hedef toplamı = blok C hedef toplamı (üç mağaza); blok B toplamı = blok A toplamı
   Aynı kaynak — neden: gerçekleşen yalnız Encore kalemindedir; hedefin tek kaynağı BKMDATA.dbo.Hedef. Kalem tutarı
              ERP defteriyle (posOzetUrun) ayrıca kuruşu kuruşuna doğrulanmıştır (sql-server-conventions § POS özet).
   Başka ne olabilir: (1) Hedef KDV'siz kurulmuş ama gerçekleşen tarafında iade/indirim farkı oranı oynatıyor olabilir;
              (2) kategori hedefi geçen yıl cirosundan türetilmişse oran KDV'den bağımsız sapar; (3) Sınav hedefi
              belge bazlı değil ürün bazlı olduğundan mağaza kapsamı farkı oranı bozabilir. Ölçüm bunları ayırmaz, yalnız gösterir.
   Dondurma : d83f324
   SSMS     : DECLARE @Bas date = CONVERT(date, '01.04.2026', 104), @Bit date = CONVERT(date, '01.10.2026', 104);
   Koşu 1   : 03.10.2026 · blok A 126 satır · blok C 9+ mekân
              3 mağaza hedef toplamı (A) 833,9M = C (145,4+198,6+489,9) · gerçekleşen KDV hariç 859,2M = C (120,7+175,4+563,2)
              Mekân 12 hedefi 604,9M, kartta değil (panel mekanId IN (1,4477,4478) okur), Encore'da gerçekleşeni yok
              Kategori ort. oran (6 ay): KDV>=%10 grubu hariç 1,17 / dahil 0,99 · KDV<%3 grubu 1,10 (her iki tabanda)
              Medyan farkı (KDV'li - KDV'siz, 12 kategori, kategori bootstrap): hariç +0,07 [-0,34; +0,53] · dahil -0,10 [-0,44; +0,31]
              Sınav Okulları (19): hedef yalnız Eylül'de (295,3M; gerçek 288,0M, oran 1,026); Ağustos gerçek 103,6M, hedef 0
   Komut    : sqlcli query --profile erp --read-only --max-rows 100000 --param bas:date=2026-04-01 --param bit:date=2026-10-01 "<blok>"
   Kapsam   : Gerçekleşen = Encore kalem, ürün bazlı (Products.Code = urn.stkID), belge 1,2,3,6,7,8 (iade negatif),
              mağaza 1/4477/4478, BarcodeNo 1001 (geri dönüşüm) hariç — panelin bugünkü kategori netiyle aynı süzgeç.
              Hariç = TotalPrice − VatTotal ; Dahil = TotalPrice (indirim düşülmüş, KDV dahil).
              Hedef kategorisi = urn.urnKtgr2ID (urnKtgrID2 DEĞİL — o kolon ürünlerin %78'inde 0). Hedef ktgId 0/255 ayrı satır.
*/

-- blok: A  (ay × kategori)
/* tsqllint-disable non-sargable */
WITH Kalem AS (
    SELECT
        DATEFROMPARTS(YEAR(s.[Date]), MONTH(s.[Date]), 1) AS ay_bas,
        ISNULL(u.urnKtgr2ID, 0) AS ktg_id,
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
                WHEN ISNUMERIC(p.Code) = 1 AND p.Code NOT LIKE '%[^0-9]%' AND LEN(p.Code) <= 9
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

-- blok: C  (mekân düzeyi: hedef, 3 mağaza gerçekleşen, mekân 12 ve diğerleri)
-- Soru: mekân 12 hedefi var mı, kart kapsamına (1/4477/4478) giriyor mu? Gerçekleşen yalnız Encore mağazalarında vardır.
WITH Hedef AS (
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
        pm.mekanID AS mekan_id,
        SUM(CASE WHEN s.DocumentsTypeId = 3 THEN -1 ELSE 1 END * (sp.TotalPrice - sp.VatTotal)) AS gercek_haric,
        SUM(CASE WHEN s.DocumentsTypeId = 3 THEN -1 ELSE 1 END * sp.TotalPrice) AS gercek_dahil
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
    WHERE
        s.[Date] >= @Bas
        AND s.[Date] < @Bit
        AND s.DocumentsTypeId IN (1, 2, 3, 6, 7, 8)
    GROUP BY pm.mekanID
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
