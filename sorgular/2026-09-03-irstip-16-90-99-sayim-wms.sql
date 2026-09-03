/* ehTip 16 "Stok EKLE" / 90 "Ürün SAY" / 99 "Sayım" nedir? (plan 41 açık soru 2)
   DB: DerinSISBkm · Araç: sqlcli --profile erp
   Soru: 16 (+460,3M adet) ve 90 (−455,7M) tüm hareket toplamını domine ediyor — satış
         hacminin (−44M) on katı. Tip filtresiz her "toplam hareket" bunlara boğulur;
         `OzetHesabaDahilMi` bayrağı buna karar verecek.

   BULGU 1 — HACMİN TAMAMI 2021'DE, AYNA ÇİFT HALİNDE:
   · 16 → 2021 +455,0M (toplamın %98,9) · 90 → 2021 −453,3M (%99,5). Tek mekan: 12 Merkez Depo.
   · 2021 aylık ayna: Eylül 16 +329.003.062 ↔ 90 −328.838.496 (net +164.566);
     Ağustos +100.006.031 ↔ −99.574.160; Ekim +24.597.665 ↔ −24.431.974.
     Yani mekanizma: defter miktarı ÇIKAR (90), sayılan miktar GİR (16) → net = gerçek düzeltme.
     2021'deki dev rakamlar ilk WMS yüklemesi/sayımı; işletme gerçeği net kalıntıdır.

   BULGU 2 — BUGÜN (2026) MEKANİZMA FARKLI: WMS SENKRONU, ÇİFT DEĞİL.
   · İkisinin de belge notu `irs.eNot = 'WMS'` (16 → 184 belge/5.108 satır/+1.052.596 adet;
     90 → 227 belge/1.340 satır/−576.637), 05.01–03.09.2026 arası GÜNLÜK akıyor.
   · Aynı ürün/mekan/gün için ikisi birlikte yalnız 192 grupta geçiyor → 2021'deki ayna
     çifti YOK; WMS bugün stoğu tek yönlü düzeltiyor.
   · Ölçek kıyası 2026: alış (0) +3.775.253 · yerel alım (10) +2.595.439 · **16 WMS +1.052.596**.
     Yani girişi yalnız `ehTip IN (0,10)` diye tanımlayan analiz yıllık ~1M adet girişi kaçırır.
   · 99 Sayım ayrı mekanizma: 2026'da 74.700 satır / 4 mekan / 52.866 ürün / −810.613 adet
     (mağaza+depo sayım düzeltmesi).

   BULGU 3 (EN ÖNEMLİ) — MERKEZ DEPO STOĞU irsHrk'DEN OKUNMAZ:
   · Resmî stok tablosu `bkm.StokAyBakiyeMekanBazli` İKİ KAYNAK kullanıyor (kolon `Kaynak`):
     mağazalar `irsHrk` (1 → 1.012.071 · 4477 → 1.444.442 · 4478 → 1.207.213),
     **merkez depo (12) `WMS` → 4.249.866**.
   · irsHrk kümülatifi (tüm ehTip, ehAltDepo farkı yok) 31.08 dönemine karşı:
     mağazalar TUTUYOR (FSM %0,8 · İst.Yolu %0,3 · Özlüce %4,8 — üç günlük hareket farkı),
     ama merkez depo 1.987.630 → resmî 4.249.866 arasında **2,26M adet fark (2 kat)**.
   · SONUÇ: merkez depo stoğunu irsHrk hareketlerinden toplamak YANLIŞ; WMS kaynağı esastır.
     Ürün sayısı da ayrışıyor: WMS 25.190 ürün, mağaza tarafı 250-320K ürün satırı.

   PLAN 41 DÜZELTMESİ: SAYIM grubu (16, 90, 99) için taslakta `OzetHesabaDahilMi=0` yazılmıştı;
   ölçüm bunu ÇÜRÜTÜYOR — bu hareketler gerçek stok etkisi taşır, dışlamak bakiyeyi bozar.
   Doğrusu: `OzetHesabaDahilMi=1` + `SayimMi=1`; operasyonel/verimlilik analizi çifti
   BİRLİKTE dışlar (birini dışlayıp ötekini bırakmak bakiyeyi bozar). */

-- 1) Yıl bazında hacim: 2021 dominasyonu
SELECT h.ehTip, YEAR(h.ehTrhS) AS yil, COUNT(*) AS satir,
       CAST(SUM(CAST(h.ehAdetN AS float)) AS decimal(18, 0)) AS net_adet,
       COUNT(DISTINCT h.ehMekan) AS mekan, COUNT(DISTINCT h.ehstkID) AS urun
FROM dbo.irsHrk h WITH(NOLOCK)
WHERE h.ehTip IN (16, 90)
GROUP BY h.ehTip, YEAR(h.ehTrhS)
ORDER BY h.ehTip, yil;

-- 2) 2021 ayna çifti (aynı ay, ters işaret, net = gerçek düzeltme)
SELECT h.ehTip, h.ehMekan, MONTH(h.ehTrhS) AS ay, COUNT(*) AS satir,
       CAST(SUM(CAST(h.ehAdetN AS float)) AS decimal(18, 0)) AS net_adet
FROM dbo.irsHrk h WITH(NOLOCK)
WHERE h.ehTip IN (16, 90) AND YEAR(h.ehTrhS) = 2021
GROUP BY h.ehTip, h.ehMekan, MONTH(h.ehTrhS)
ORDER BY h.ehTip, net_adet;

-- 3) Bugünkü iş anlamı: belge notu (eNot) — 2026
SELECT i.eTip, LEFT(ISNULL(NULLIF(LTRIM(RTRIM(i.eNot)), ''), '(not yok)'), 40) AS notu,
       COUNT(DISTINCT i.eID) AS belge, SUM(h.satir) AS satir,
       CAST(SUM(h.adet) AS decimal(18, 0)) AS net_adet,
       CONVERT(varchar, MIN(i.eTarihS), 104) AS ilk, CONVERT(varchar, MAX(i.eTarihS), 104) AS son
FROM dbo.irs i WITH(NOLOCK)
CROSS APPLY (
    SELECT COUNT(*) AS satir, SUM(CAST(x.ehAdetN AS float)) AS adet
    FROM dbo.irsHrk x WITH(NOLOCK)
    WHERE x.ehID = i.eID AND x.ehTip = i.eTip
) h
WHERE i.eTip IN (16, 90) AND i.eTarihS >= '20260101'
GROUP BY i.eTip, LEFT(ISNULL(NULLIF(LTRIM(RTRIM(i.eNot)), ''), '(not yok)'), 40)
ORDER BY SUM(h.satir) DESC;

-- 4) Çift mi? Aynı ürün/mekan/gün için ikisi birlikte kaç grupta geçiyor (2026 → 192, yani hayır)
SELECT COUNT(*) AS eslesen_grup, CAST(SUM(net) AS decimal(18, 0)) AS cift_net
FROM (
    SELECT h.ehstkID, h.ehMekan, h.ehTrhS, SUM(CAST(h.ehAdetN AS float)) AS net
    FROM dbo.irsHrk h WITH(NOLOCK)
    WHERE h.ehTip IN (16, 90) AND h.ehTrhS >= '20260101'
    GROUP BY h.ehstkID, h.ehMekan, h.ehTrhS
    HAVING COUNT(DISTINCT h.ehTip) = 2
) t;

-- 5) Ölçek: WMS eklemesi alış girişinin yanında ne kadar (2026)
SELECT h.ehTip, COUNT(*) AS satir, CAST(SUM(CAST(h.ehAdetN AS float)) AS decimal(18, 0)) AS net_adet
FROM dbo.irsHrk h WITH(NOLOCK)
WHERE h.ehTip IN (0, 10, 16) AND h.ehTrhS >= '20260101'
GROUP BY h.ehTip
ORDER BY net_adet DESC;

-- 6) KRİTİK: resmî stok tablosunun kaynak ayrımı (merkez depo = WMS, mağaza = irsHrk)
SELECT Kaynak, ehMekan, COUNT(*) AS urun, CAST(SUM(CAST(Stok AS float)) AS decimal(18, 0)) AS stok
FROM bkm.StokAyBakiyeMekanBazli WITH(NOLOCK)
WHERE Donem = (SELECT MAX(Donem) FROM bkm.StokAyBakiyeMekanBazli)
GROUP BY Kaynak, ehMekan
ORDER BY Kaynak, stok DESC;

-- 7) Karşılaştırma: irsHrk kümülatifi (mağazalar tutar, merkez depo TUTMAZ)
SELECT ehMekan, CAST(SUM(CAST(ehAdetN AS float)) AS decimal(18, 0)) AS kumulatif_adet
FROM dbo.irsHrk WITH(NOLOCK)
WHERE ehMekan IN (1, 4477, 4478, 12)
GROUP BY ehMekan
ORDER BY kumulatif_adet DESC;


/* ===== K-36 EKİ (aynı gün, 03.09.2026): ehTip 16 alış mı, düzeltme mi? =====
   BULGU A — 16 ALIŞ DEĞİL, alışla ÇAKIŞMIYOR: 2026'da 5.108 satır / 1.052.596 adet 16
   hareketinin yalnız **33 satır / 525 adet**'i (%0,05) aynı ürün+mekan+GÜN'de bir alış
   (ehTip 0/10) satırıyla birlikte geçiyor. Yani WMS eklemesi alış girişinin kopyası
   DEĞİL → girişe eklemek çift sayım olmazdı, ama "alış" saymak da yanlış olurdu.
   Ürün düzeyinde gevşek kıyas: 16'nın 4.225 ürününden 1.361'i (%32) 2026'da alış da
   görmüş — aktif ürün olmanın doğal sonucu, kanıt değil.

   BULGU B — KOD ZATEN AMAÇ BAZLI AYIRIYOR (düzeltme gerekmiyor):
   · `SatinalmaQueries.cs` #a (alış adedi/tutarı) → `ehTip IN (0,10)` = gerçek alış. DOĞRU.
   · `SatinalmaQueries.cs` #ilk (ürünün ilk stok girişi) → `IN (0,10,13,16,99)`. DOĞRU
     (ilk giriş için depo-mağaza/WMS/sayım da meşru giriştir).
   · `RefQueries.Envanter.cs` AlisAdet → `IN (0,10)`. DOĞRU.
   → K-36'nın ilk çerçevesi ("analizler 1M adet girişi kaçırıyor") YANLIŞ çerçeveydi.

   BULGU C (ASIL SORUN) — PANEL MERKEZ DEPO STOĞUNU YANLIŞ KAYNAKTAN OKUYOR:
   · `dbo.stokSonAltDepo_vw` (panelin kullandığı ERP stok view'ı) mekan 12 için
     **1.987.630** adet diyor (426.033 satır, tamamı ehAltDepo=0 — alt depo kırılımı YOK).
   · Resmî `bkm.StokAyBakiyeMekanBazli` (Kaynak='WMS', 31.08.2026) **4.249.866** diyor
     (25.190 ürün) → **2,26M adet / 2,1 kat sapma**. Mağazalarda iki kaynak tutuyor.
   · Sebep zaten Ağustos'ta yazılmıştı: `sorgular/2026-08-12-stok-ay-bakiye-mekan-tablo.sql`
     başlığı "DEPO (mekan 12): irsHrk ledger geçmişte BOZUK … WMS = tek doğru kaynak" diyor.
     O zaman tek ürün örneğiyle (591060) biliniyordu; şimdi TOPLAMDA ölçüldü.
   · Ama panel/scriptlerin bir kısmı hâlâ view'ı depo stoğu olarak gösteriyor:
     `OdakQueries.cs:176` (Mrkz kolonu) · `RefQueries.Envanter.cs:554` (Depo kolonu) ·
     `scripts/export_odak_stok.py:46`. → merkez depo stoğu panelde YARIYA YAKIN gösteriliyor.
     Düzeltme kararı ve kapsamı TODO K-37'de. */

-- K-36/1) 16 ile alışın aynı gün örtüşmesi (2026) — beklenen: çok küçük
SELECT COUNT(*) AS satir, CAST(SUM(CAST(h.ehAdetN AS float)) AS decimal(18, 0)) AS adet
FROM dbo.irsHrk h WITH(NOLOCK)
WHERE h.ehTip = 16 AND h.ehTrhS >= '20260101'
  AND EXISTS (SELECT 1 FROM dbo.irsHrk p WITH(NOLOCK)
              WHERE p.ehstkID = h.ehstkID AND p.ehMekan = h.ehMekan
                AND p.ehTrhS = h.ehTrhS AND p.ehTip IN (0, 10));

-- K-36/2) Panelin stok view'ı vs resmî WMS bakiyesi (mekan bazında)
SELECT v.ehMekan, CAST(SUM(CAST(v.stok AS float)) AS decimal(18, 0)) AS view_stok
FROM dbo.stokSonAltDepo_vw v WITH(NOLOCK)
WHERE v.ehMekan IN (1, 4477, 4478, 12) AND v.ehAltDepo = 0
GROUP BY v.ehMekan
ORDER BY view_stok DESC;
