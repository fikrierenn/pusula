-- ork:hedef-db DerinSISBkm
-- ork:compat 150
/* Soru     : Tedarikçi karnesinde merkez depo stoğu canlı WMS'ten (raf + giriş alanı) mı geliyor?
   AC       : AC-3.1, AC-3.2, AC-3.3, AC-3.4 · Spec 001 · H03
   Dönem    : yok (canlı anlık stok; ölçüm saati başlıkta, WMS günlük değişir)
   Tolerans : stok adedi birebir
   Önce     : RefQueries.Envanter.cs GetTedarikciPerformansAsync stok alt-sorgusunun merkez depo bileşeni
              (stokSonAltDepo_vw, ehAltDepo = 0, stok > 0, ehMekan = 12 = ERP defteri), 04.10.2026 01:03.
              Panel SQL'i bu dosyada yok (dosya dışı: T-007 ölçümü, defter); aynı bileşen blok ONCE (marka başına, int kesmeli)
              ve blok ONCE_TOPLAM (kesmesiz toplam) olarak yeniden koşulur:
              Σ depo 5.878.678,18 adet (32.631 ürün; hepsi urn'de eşleşir; 1.022 marka) — 02.10.2026 referansı 5.884.929.
              Marka başı int kesmesi nedeniyle ONCE satırlarının toplamı 5.878.678,18'den ±1 marka başına sapar (blok ONCE_TOPLAM
              kesmesiz değeri verir; D ile aynı kesme farkı geçerli).
   Sonra    : yok (düzeltme T-0xx sonrası ölçülür)
   Bağımsız : (04.10.2026 01:03, sqlcli erp profili, --read-only; B ve D bu dosyadaki bloklardır)
              B  : WMS alan 0+1 toplamı 3.621.587 adet (25.496 satır, 21.400 ürün, negatif satır 0)
                   — 02.10.2026 referansı 3.628.661; WMS günlük değişir, fark beklenen
              B2 : urn ile eşleşen toplam 3.621.587 (740 marka) = B, öksüz ürün yok
              D  : mağaza stoğu (1,4477,4478; stok > 0) Σ 3.690.345,86 adet (4.495 marka; marka başı int kesmesi toplamı 3.690.341)
              E  : hayalet = WMS pozitif, ERP defteri merkez depo ≤ 0: 142 ürün, 3.026 adet
   Kapsam   : (T-001 G ile fark) 00-taban-olcumu.sql blok G canlı WMS'i yalnız SatisAnaliziTaban son kesimindeki aynı stkID
              kümesinde okur (2.830.868 adet); B bütün WMS'tir (3.621.587). İki sayı çelişmez, kapsamları farklıdır.
              SatisAnaliziTaban.MerkezStok üretim anındaki WMS'tir, canlı WMS'ten sapması zaman kaymasıdır (G'de).
   Yeniden ölçüm: 04.10.2026 22:02 (aynı bloklar, canlı veri gün içinde değişir; fark beklenen):
              B 3.613.000 (01:03'te 3.621.587) · E 142 ürün / 2.954 adet (3.026) · ONCE_TOPLAM 5.870.157,18 adet / 32.595 ürün /
              1.022 marka (01:03 değerleri 5.878.678,18 / 32.631 yukarıdaki 'Önce'de, dosya dışı T-007 ölçümü olarak kalır).
   Aynı kaynak — neden: değil. Panel ERP defterinden, kanonik sorgu WMS hücresel stoğundan okur
              (depo.stok_adres_palet_vw); mağaza bileşeni (blok D) ERP defterinde kalır, çünkü
              mağaza için defter doğrudur (sql-server-conventions § MERKEZ DEPO) ve AC-3.4 değişmesini yasaklar.
   Başka ne olabilir: (1) ERP defteri ile WMS farkı (~2,26M adet) ambalaj/sarf ve kitap kalıntısı kapsamından
              gelebilir; çift yönlü: ERP'de olup WMS'te olmayan çok, WMS'te olup ERP'de olmayan 'hayalet' az (blok E).
              (2) WMS gün içinde değişir; test ile arşiv ölçümü arasındaki saat farkı küçük sapma üretebilir.
              (3) Karne yalnız satış ≥ 50 adet markalarını gösterir; A bütün markaları verir, test kümeyi A'dan seçer.
              (4) Çıkış alanı (2) bilerek dışarıda: sevke hazırlanmış mal.
              (5) Marka başına CAST(... AS int) toplamı kesirli ürün stoğunu keser; D ve ONCE satır toplamları kesmesiz
              toplamdan marka başına ±1 farklı olabilir (D: 3.690.345,86 kesmesiz, 3.690.341 kesmeli).
   Kapsam   : depo = stok_adres_palet_vw, adrsAlanTipID IN (0,1); marka = urn.urnMrkID (ürün stkID üstünden,
              stkKod değil); urn'de soft-delete kolonu yok (IsValid/urnSil yok, ölçüldü); mağaza = ehMekan IN (1,4477,4478).
   Dondurma : 18c2ce0
   SSMS     : tarih parametresi yok; bloklar canlı ve DECLARE'siz, GO ile ayrılır.
   Komut    : sqlcli query --profile erp --read-only --max-rows 100000 "<tek blok>" (depo kökünden).
   Bloklar  : A (MrkId, DepoStok) · B (DepoToplam) · C (StkId, DepoStok) ilk 20 ürün · D (MrkId, MagazaStok)
              · ONCE (MrkId, DepoStok) ERP defteri, yalnız 'önce' ölçümü · ONCE_TOPLAM (DepoToplam, Urun, Marka) kesmesiz
              · E (HayaletUrun, HayaletAdet) çift yön
   AC-3.x   : nüfus A 740 marka, C 20 ürün, D 4.495 marka (> 0 olmalı; 0 ise KOŞAMADI)
*/

-- blok: A  (marka başına merkez depo, canlı WMS alan 0+1)
SELECT
    u.urnMrkID AS MrkId,
    CAST(SUM(w.Stok) AS int) AS DepoStok
FROM DerinSISBkm.depo.stok_adres_palet_vw AS w
    INNER JOIN DerinSISBkm.dbo.urn AS u
        ON w.stkID = u.stkID
WHERE w.adrsAlanTipID IN (0, 1)
GROUP BY u.urnMrkID
ORDER BY u.urnMrkID;
GO

-- blok: B  (tüm WMS alan 0+1 toplamı, urn'e bağlanmadan)
SELECT CAST(SUM(w.Stok) AS int) AS DepoToplam
FROM DerinSISBkm.depo.stok_adres_palet_vw AS w
WHERE w.adrsAlanTipID IN (0, 1);
GO

-- blok: C  (depo > 0 olan ilk 20 ürün; karne ürün örneklemi.
--           Kategori çeşit ekranı (RefQueries.Envanter GetKategoriCesitAsync)
--           bu bloğa dayanmaz: o ekran StokAyBakiyeMekanBazli'de MAX(Donem) ay sonu görüntüsünden çeşit sayısı okur,
--           canlı WMS değil; Y-DEPO düzeltmesi sonrası geçerli)
SELECT TOP 20
    w.stkID AS [StkId],
    CAST(SUM(w.Stok) AS int) AS DepoStok
FROM DerinSISBkm.depo.stok_adres_palet_vw AS w
WHERE w.adrsAlanTipID IN (0, 1)
GROUP BY w.stkID
HAVING SUM(w.Stok) > 0
ORDER BY w.stkID;
GO

-- blok: D  (marka başına mağaza stoğu, ERP defteri; AC-3.4 değişmez bileşen)
SELECT
    u.urnMrkID AS MrkId,
    CAST(SUM(v.stok) AS int) AS MagazaStok
FROM DerinSISBkm.dbo.stokSonAltDepo_vw AS v
    INNER JOIN DerinSISBkm.dbo.urn AS u
        ON v.ehstkID = u.stkID
WHERE
    v.ehAltDepo = 0
    AND v.stok > 0
    AND v.ehMekan IN (1, 4477, 4478)
GROUP BY u.urnMrkID
ORDER BY u.urnMrkID;
GO

-- blok: ONCE  (düzeltme ÖNCESİ panel merkez depo bileşeni: ERP defteri, marka başına)
SELECT
    u.urnMrkID AS MrkId,
    CAST(SUM(v.stok) AS int) AS DepoStok
FROM DerinSISBkm.dbo.stokSonAltDepo_vw AS v
    INNER JOIN DerinSISBkm.dbo.urn AS u
        ON v.ehstkID = u.stkID
WHERE
    v.ehAltDepo = 0
    AND v.stok > 0
    AND v.ehMekan = 12
GROUP BY u.urnMrkID
ORDER BY u.urnMrkID;
GO

-- blok: ONCE_TOPLAM  (düzeltme ÖNCESİ merkez depo bileşeni, int kesmesi YOK; başlıktaki 5.878.678,18 / 32.631 ürün kaynağı)
SELECT
    SUM(v.stok) AS DepoToplam,
    COUNT(DISTINCT v.ehstkID) AS Urun,
    COUNT(DISTINCT u.urnMrkID) AS Marka
FROM DerinSISBkm.dbo.stokSonAltDepo_vw AS v
    INNER JOIN DerinSISBkm.dbo.urn AS u
        ON v.ehstkID = u.stkID
WHERE
    v.ehAltDepo = 0
    AND v.stok > 0
    AND v.ehMekan = 12;
GO

-- blok: E  (çift yön: WMS pozitif, ERP defteri merkez depo ≤ 0 = hayalet)
WITH WmsUrun AS (
    SELECT
        w.stkID,
        SUM(w.Stok) AS wms_stok
    FROM DerinSISBkm.depo.stok_adres_palet_vw AS w
    WHERE w.adrsAlanTipID IN (0, 1)
    GROUP BY w.stkID
),

DefterUrun AS (
    SELECT
        v.ehstkID,
        SUM(v.stok) AS defter_stok
    FROM DerinSISBkm.dbo.stokSonAltDepo_vw AS v
    WHERE
        v.ehAltDepo = 0
        AND v.ehMekan = 12
    GROUP BY v.ehstkID
)

SELECT
    COUNT(*) AS HayaletUrun,
    CAST(SUM(wm.wms_stok) AS int) AS HayaletAdet
FROM WmsUrun AS wm
    LEFT JOIN DefterUrun AS df
        ON wm.stkID = df.ehstkID
WHERE
    wm.wms_stok > 0
    AND (df.ehstkID IS NULL OR df.defter_stok <= 0);
