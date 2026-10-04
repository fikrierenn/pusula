-- ork:hedef-db DerinSISBkm
-- ork:compat 150
/* Soru     : Merkez depo stoğu bugün canlı WMS'ten, geçmiş ay ay sonu görüntüsünden mi geliyor?
              Görüntü yoksa başka ayın değeri gösteriliyor mu?
   AC       : AC-8.1, AC-8.2, AC-8.3, AC-8.4 · Spec 001 · H08
   Dönem    : A canlı anlık (parametre yok); B ve C @Donem (ay sonu görüntü tarihi).
              Doğrulama: son dolu dönem 31.08.2026 ve dolu olmayan 01.10.2026.
   Tolerans : stok adedi birebir
   Önce     : OdakQueries.GetUrunlerAsync 'depo' CTE ve RefQueries.Envanter GetKategoriCesitAsync UNION ALL kolu
              Donem = MAX(Donem) (Kaynak='WMS') okur: en son dolu görüntüyü (31.08.2026) bugünkü stok gibi
              gösterir; bkz. ONCE_ODAK, ONCE_CESIT. Referans 02.10.2026: canlı WMS 3.628.661 adet,
              ODAK ay sonu 4.249.866.
   Sonra    : yok (düzeltme T-0xx sonrası ölçülür)
   Bağımsız : T-001 blok J (StokAyBakiyeMekanBazli mekan 12): yalnız Kaynak='WMS', tek Donem 31.08.2026,
              25.190 satır, 4.249.866 adet; irsHrk kaynağında mekan 12 yok.
              T-007 (04.10.2026 01:03): canlı WMS alan 0+1 = 3.621.587 adet / 25.496 satır;
              T-001 G'nin 2.830.868'i SatisAnaliziTaban stkID kümesiyle sınırlıydı.
   Aynı kaynak — neden: değil. Bugün: depo.stok_adres_palet_vw (A); geçmiş ay: bkm.StokAyBakiyeMekanBazli (B, C).
              İki ayrı kaynak bilerek ayrı bloklarda.
   Başka ne olabilir: (1) Görüntü tablosu yalnız WMS kaynaklı ve tek dönemli; geçmiş ay istenince çoğu zaman
              boş dönmesi doğru davranıştır. (2) WMS gün içinde değişir; ölçüm saati başlıkta. (3) Ay sonu
              görüntüsünde alan 2 (çıkış) yok, canlı tarafta da alan 0+1; tanımlar aynı. (4) Taban farkı
              (blok K) yalnız zaman kaymasından değil, taban kümesi dışı ürünlerden de gelebilir; K ürün ürün ayrıştırır.
   Kapsam   : A = adrsAlanTipID IN (0,1); B/C = Kaynak='WMS' AND ehMekan=12 AND Donem=@Donem, MAX(Donem) yedeği yok.
   Dondurma : bd02553
   SSMS     : her blok kendi DECLARE'ini taşır, GO ile ayrılır.
   Komut    : sqlcli query --profile erp --read-only --max-rows 100000 "<tek blok>" (depo kökünden).
   Bloklar  : A (StkId, Merkez) · B (StkId, Merkez) @Donem · C (GoruntuVar) @Donem
              · ONCE_ODAK / ONCE_CESIT (düzeltme öncesi) · K (taban kayması)
   AC-8.x   : nüfus A > 0 satır; B son dolu dönemde > 0, olmayan dönemde 0 satır; C 1 / 0 (0 ise "görüntü yok").
*/

-- blok: A  (canlı WMS alan 0+1, ürün başına)
SELECT
    w.stkID AS [StkId],
    CAST(SUM(w.Stok) AS int) AS Merkez
FROM DerinSISBkm.depo.stok_adres_palet_vw AS w
WHERE w.adrsAlanTipID IN (0, 1)
GROUP BY w.stkID
ORDER BY w.stkID;
GO

-- blok: B  (ay sonu görüntüsü, ürün başına; olmayan dönemde boş)
DECLARE @Donem datetime = CONVERT(datetime, '31.08.2026', 104);   -- DMY; olmayan dönem denemesi: 01.10.2026
SELECT
    b.stkID AS [StkId],
    CAST(SUM(b.Stok) AS int) AS Merkez
FROM DerinSISBkm.bkm.StokAyBakiyeMekanBazli AS b
WHERE
    b.Kaynak = 'WMS'
    AND b.ehMekan = 12
    AND b.Donem = @Donem
GROUP BY b.stkID
ORDER BY b.stkID;
GO

-- blok: C  (görüntü var mı)
DECLARE @Donem datetime = CONVERT(datetime, '31.08.2026', 104);   -- DMY; olmayan dönem denemesi: 01.10.2026
SELECT
    CASE
        WHEN EXISTS (
            SELECT 1
            FROM DerinSISBkm.bkm.StokAyBakiyeMekanBazli AS b
            WHERE
                b.Kaynak = 'WMS'
                AND b.ehMekan = 12
                AND b.Donem = @Donem
        ) THEN 1
        ELSE 0
    END AS GoruntuVar;
GO

-- blok: ONCE_ODAK  (düzeltme öncesi OdakQueries 'depo' CTE: MAX(Donem) görüntüsü, ürün başına)
SELECT
    b.stkID AS [StkId],
    SUM(CAST(b.Stok AS int)) AS Merkez
FROM DerinSISBkm.bkm.StokAyBakiyeMekanBazli AS b
WHERE
    b.Kaynak = 'WMS'
    AND b.ehMekan = 12
    AND b.Donem = (
        SELECT TOP (1) x.Donem
        FROM DerinSISBkm.bkm.StokAyBakiyeMekanBazli AS x
        WHERE x.Kaynak = 'WMS'
        ORDER BY x.Donem DESC
    )
GROUP BY b.stkID;
GO

-- blok: ONCE_CESIT  (düzeltme öncesi GetKategoriCesitAsync merkez kolu: MAX(Donem), stok > 0 çeşit ve adet)
SELECT
    (
        SELECT TOP (1) x.Donem
        FROM DerinSISBkm.bkm.StokAyBakiyeMekanBazli AS x
        WHERE x.Kaynak = 'WMS'
        ORDER BY x.Donem DESC
    ) AS KullanilanDonem,
    COUNT(DISTINCT CASE WHEN b.Stok > 0 THEN b.stkID END) AS Cesit,
    SUM(CAST(b.Stok AS int)) AS Adet
FROM DerinSISBkm.bkm.StokAyBakiyeMekanBazli AS b
WHERE
    b.Kaynak = 'WMS'
    AND b.ehMekan = 12
    AND b.Donem = (
        SELECT TOP (1) x.Donem
        FROM DerinSISBkm.bkm.StokAyBakiyeMekanBazli AS x
        WHERE x.Kaynak = 'WMS'
        ORDER BY x.Donem DESC
    );
GO

-- blok: K  (taban kayması: SatisAnaliziTaban son Kesim stkID kümesinde canlı WMS ile MerkezStok farkı, ürün bazında)
WITH Son AS (
    SELECT MAX(t.Kesim) AS kesim
    FROM DerinSISBkm.bkm.SatisAnaliziTaban AS t
),

Taban AS (
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
),

Fark AS (
    SELECT
        tbn.stkID,
        ISNULL(c.stok, 0) - tbn.merkez_stok AS fark
    FROM Taban AS tbn
        LEFT JOIN Canli AS c
            ON tbn.stkID = c.stkID
)

SELECT
    (SELECT sn.kesim FROM Son AS sn) AS kesim_tarihi,
    COUNT(*) AS taban_urun_sayisi,
    SUM(CASE WHEN f.fark <> 0 THEN 1 ELSE 0 END) AS degisen_urun_sayisi,
    SUM(CASE WHEN f.fark > 0 THEN 1 ELSE 0 END) AS artan_urun_sayisi,
    SUM(CASE WHEN f.fark < 0 THEN 1 ELSE 0 END) AS azalan_urun_sayisi,
    SUM(f.fark) AS net_fark_adet,
    SUM(CASE WHEN f.fark > 0 THEN f.fark ELSE 0 END) AS artis_adet,
    SUM(CASE WHEN f.fark < 0 THEN f.fark ELSE 0 END) AS azalis_adet,
    SUM(ABS(f.fark)) AS mutlak_fark_adet
FROM Fark AS f;
GO
