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
