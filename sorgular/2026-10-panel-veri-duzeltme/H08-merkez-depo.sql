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
              ODAK ay sonu 4.249.866 (ONCE_CESIT Adet 4.249.866, 04.10.2026). ONCE_CESIT panel çıktısı DEĞİL, girdi kümesidir:
              Cesit 25.190 süzgeçsiz; panel kategori süzgeciyle 25.084 (dosya dışı: T-012 ölçümü, fark 106 çeşit).
   Sonra    : yok (düzeltme T-0xx sonrası ölçülür)
   Bağımsız : (kaynak içi kimlik, bağımsız kanıt değil: ONCE_ODAK, ONCE_CESIT, B ve T-001 J aynı StokAyBakiyeMekanBazli tablosunu okur)
              T-001 blok J: yalnız Kaynak='WMS', tek Donem 31.08.2026, 25.190 satır, 4.249.866 adet; irsHrk kaynağında mekan 12 yok.
              Canlı WMS alan 0+1 (A, 04.10.2026): 25.447 satır, 3.613.000 adet (T-007 01:03 ölçümü 3.621.587 / 25.496; WMS gün
              içinde değişir). Alan 0+1'de kesirli satır 0: A'daki CAST int kesmesi bugün adedi değiştirmiyor (blok A_KESIR).
              K: taban Kesim 15.09.2026 (kurulma anı kaydı yok, referans an değil); 276.378 ürün, 8.282'si değişmiş (2.177 artan +51.474,
              6.105 azalan −327.608; net −276.134 adet). K_DISI: canlı WMS'te olup taban stkID kümesinde olmayan 380 ürün /
              790.689 adet (canlı 3.613.000'in ~%22'si); K bunları raporlamaz.
              K'daki farkın 'zaman kayması' olduğu ÇIKARIM (mekanizma ve zaman damgası var, büyüklükçe ayrıştırılmadı).
   Aynı kaynak — neden: değil. Bugün: depo.stok_adres_palet_vw (A); geçmiş ay: bkm.StokAyBakiyeMekanBazli (B, C).
              İki ayrı kaynak bilerek ayrı bloklarda.
   Başka ne olabilir: (1) Görüntü tablosu yalnız WMS kaynaklı ve tek dönemli; geçmiş ay istenince çoğu zaman
              boş dönmesi doğru davranıştır. (2) WMS gün içinde değişir; ölçüm saati başlıkta. (3) Ay sonu
              görüntüsünde alan 2 (çıkış) yok, canlı tarafta da alan 0+1; tanımlar aynı. (4) Taban farkı
              (blok K) yalnız zaman kaymasından değil, taban kümesi dışı ürünlerden de gelebilir (K_DISI: 380 ürün, K'ya girmez).
   Kapsam   : A = adrsAlanTipID IN (0,1); B/C = Kaynak='WMS' AND ehMekan=12 AND Donem=@Donem, MAX(Donem) yedeği yok.
   Dondurma : 18c2ce0
   SSMS     : her blok kendi DECLARE'ini taşır, GO ile ayrılır.
   Komut    : sqlcli query --profile erp --read-only --max-rows 100000 "<tek blok>" (depo kökünden).
   Bloklar  : A (StkId, Merkez) · B (StkId, Merkez) @Donem · C (GoruntuVar) @Donem
              · ONCE_ODAK / ONCE_CESIT (düzeltme öncesi) · K (taban kayması) · K_DISI (taban dışı canlı ürün) · A_KESIR (kesirli stok)
   AC-8.x   : nüfus A > 0 satır; B son dolu dönemde > 0, olmayan dönemde 0 satır; C 1 / 0 (0 ise "görüntü yok").
*/

-- blok: A  (canlı WMS alan 0+1, ürün başına)
SELECT
    w.stkID AS [StkId],
    CAST(SUM(w.Stok) AS INT) AS Merkez
FROM DerinSISBkm.depo.stok_adres_palet_vw AS w
WHERE w.adrsAlanTipID IN (0, 1)
GROUP BY w.stkID
ORDER BY w.stkID;
GO

-- blok: B  (ay sonu görüntüsü, ürün başına; olmayan dönemde boş)
DECLARE @Donem DATE = CONVERT(DATE, '31.08.2026', 104);   -- DMY; olmayan dönem denemesi: 30.09.2026 (ay sonu)
SELECT
    b.stkID AS [StkId],
    CAST(SUM(b.Stok) AS INT) AS Merkez
FROM DerinSISBkm.bkm.StokAyBakiyeMekanBazli AS b
WHERE
    b.Kaynak = 'WMS'
    AND b.ehMekan = 12
    AND b.Donem = @Donem
GROUP BY b.stkID
ORDER BY b.stkID;
GO

-- blok: C  (görüntü var mı)
DECLARE @Donem DATE = CONVERT(DATE, '31.08.2026', 104);   -- DMY; olmayan dönem denemesi: 30.09.2026 (ay sonu)
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
    SUM(CAST(b.Stok AS INT)) AS Merkez
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
    SUM(CAST(b.Stok AS INT)) AS Adet
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

-- blok: K_DISI  (canlı WMS alan 0+1'de olup SatisAnaliziTaban son Kesim stkID kümesinde olmayan ürünler; K bunları raporlamaz)
WITH Son AS (
    SELECT MAX(t.Kesim) AS kesim
    FROM DerinSISBkm.bkm.SatisAnaliziTaban AS t
),

Taban AS (
    SELECT DISTINCT t.stkID
    FROM DerinSISBkm.bkm.SatisAnaliziTaban AS t
        INNER JOIN Son AS sn
            ON t.Kesim = sn.kesim
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
    COUNT(*) AS canli_urun,
    SUM(CASE WHEN tbn.stkID IS NULL THEN 1 ELSE 0 END) AS taban_disi_urun,
    SUM(CASE WHEN tbn.stkID IS NULL THEN c.stok ELSE 0 END) AS taban_disi_adet,
    SUM(c.stok) AS canli_adet
FROM Canli AS c
    LEFT JOIN Taban AS tbn
        ON c.stkID = tbn.stkID;
GO

-- blok: A_KESIR  (alan 0+1'de kesirli stok var mı: A bloğundaki CAST AS int kesmesi adedi değiştirir mi)
SELECT
    COUNT(*) AS satir,
    SUM(CASE WHEN w.Stok <> FLOOR(w.Stok) THEN 1 ELSE 0 END) AS kesirli_satir,
    CAST(SUM(w.Stok) AS DECIMAL(18, 2)) AS adet
FROM DerinSISBkm.depo.stok_adres_palet_vw AS w
WHERE w.adrsAlanTipID IN (0, 1);
GO
