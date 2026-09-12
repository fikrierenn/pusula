/* ============================================================================
   POS ÖZET ↔ STOK DEFTERİ — KURUŞU KURUŞUNA KİMLİK  (2026-09-12)
   DB: DerinSISBkm (profil: erp)

   SORU: `posOzetUrun` ile `irsHrk` (ehTip 100/101) aynı ürün-gün satırında ADET
   olarak birebir tutuyor ama TUTAR ~1,97 kat farklı görünüyordu. Fiyat tabanı mı
   farklı?

   CEVAP: HAYIR. Fark tamamen ÖLÇENİN HATASIYDI — iki ayrı yanlış aynı anda:
     (1) `satTutar` KDV DAHİL sanılmadı, KDV hariç sanıldı,
     (2) `satIndirim` AYRICA DÜŞÜLDÜ (oysa indirim `satTutar` içinde zaten uygulanmış).
   İkisi düzeltilince kimlik KURUŞUNA oturuyor.

   ⚠ DERS: "iki taraf tutmuyor" demeden önce HER İKİ TARAFIN KOLON SÖZLEŞMESİ
     okunur. Burada "açık soru / fiyat tabanı farklı" diye bir bulgu yazılmıştı;
     bulgu DEĞİL, ölçüm hatasıydı. Kayıt sema'da tutuluyor ki tekrarlanmasın.
   ============================================================================ */

/* 1) ÜRÜN BAZINDA ORAN — hipotezi tek bakışta gösterir.
      Oran tam olarak KDV koduna oturuyorsa, satTutar KDV DAHİLDİR. */
WITH p AS (
    SELECT posStkID,
           SUM(satAdet)    AS pAdet,
           SUM(satTutar)   AS pTutar,
           SUM(satIndirim) AS pInd,
           MAX(CONVERT(int, posKDV)) AS kdvKod
    FROM   DerinSISBkm.dbo.posOzetUrun WITH(NOLOCK)
    WHERE  posMekan = 4478 AND posTarih = '20260805'
    GROUP BY posStkID
), i AS (
    SELECT ehstkID, SUM(ABS(ehAdetN)) AS iAdet, SUM(ehTutarN) AS iTutar
    FROM   DerinSISBkm.dbo.irsHrk WITH(NOLOCK)
    WHERE  ehMekan = 4478 AND ehTip = 100 AND ehAltDepo = 0 AND ehTrhS = '20260805'
    GROUP BY ehstkID
)
SELECT TOP 12 p.posStkID, u.stkAd, p.kdvKod, p.pAdet,
       CONVERT(decimal(18,2), p.pTutar) AS pos_tutar,
       CONVERT(decimal(18,2), p.pInd)   AS pos_indirim,
       i.iAdet, CONVERT(decimal(18,2), i.iTutar) AS irs_tutar,
       CONVERT(decimal(18,4), i.iTutar / NULLIF(p.pTutar,0)) AS oran
FROM   p JOIN i ON i.ehstkID = p.posStkID
JOIN   DerinSISBkm.dbo.urn u WITH(NOLOCK) ON u.stkID = p.posStkID
WHERE  p.pTutar > 500
ORDER BY i.iTutar DESC;
/* Ölçüm — oran KDV KODUNA BİREBİR oturuyor:
     kod 1 (%0)   23.275,50 -> 23.275,50   oran 1,000
     kod 2 (%1)    2.475,00 ->  2.450,29   oran 0,990  = 1/1,01
     kod 6 (%10)   5.000,00 ->  4.545,47   oran 0,909  = 1/1,10
     kod 7 (%20)   3.990,00 ->  3.325,01   oran 0,833  = 1/1,20
   ⇒ `satTutar` KDV DAHİL · `ehTutarN` KDV HARİÇ.
   ⇒ Ayrıca stkID 1732640: satTutar 23.275,50 · satIndirim 23.275,50 ·
     ehTutarN 23.275,50 → `satIndirim` AYRICA DÜŞÜLMEZ; indirim zaten uygulanmış,
     bu kolon yalnız indirimin TUTARINI bildirir. */

/* 2) ★ KİMLİK — tam ay, tek sorgu. `posKDV` = `urnKDV.kdvID` ile yüzdeye çevrilir. */
WITH pos AS (
    SELECT CONVERT(decimal(18,2), SUM(p.satTutar  / (1.0 + k.kdvYuzde/100.0))) AS pos_net,
           CONVERT(decimal(18,2), SUM(p.iadeTutar / (1.0 + k.kdvYuzde/100.0))) AS pos_iade,
           CONVERT(decimal(18,2), SUM(p.satTutar))                             AS pos_kdvdahil
    FROM   DerinSISBkm.dbo.posOzetUrun p WITH(NOLOCK)
    JOIN   DerinSISBkm.dbo.urnKDV      k ON k.kdvID = p.posKDV
    WHERE  p.posMekan = 4478
      AND  p.posTarih >= '20260801' AND p.posTarih < '20260901'
), irs AS (
    SELECT CONVERT(decimal(18,2), SUM(CASE WHEN ehTip=100 THEN ehTutarN ELSE 0 END)) AS t100,
           CONVERT(decimal(18,2), SUM(CASE WHEN ehTip=101 THEN ehTutarN ELSE 0 END)) AS t101
    FROM   DerinSISBkm.dbo.irsHrk WITH(NOLOCK)
    WHERE  ehMekan = 4478 AND ehAltDepo = 0 AND ehTip IN (100,101)
      AND  ehTrhS >= '20260801' AND ehTrhS < '20260901'
)
SELECT * FROM pos CROSS JOIN irs;
/* Ölçüm — İst.Yolu, Ağustos 2026, TAM AY:
     POS satTutar  KDV DAHİL   130.912.940,80
     POS satTutar  KDV HARİÇ   128.097.715,43   ↔  irsHrk ehTip=100  128.097.709,99
                                                     FARK  +5,44 ₺   (%0,0000)
     POS iadeTutar KDV HARİÇ     1.677.233,89   ↔  irsHrk ehTip=101    1.677.233,65
                                                     FARK  +0,24 ₺   (%0,0000)
   128 MİLYON üzerinde 5 lira = satır-başı bölme yuvarlaması. KİMLİK KURULDU. */

/* 3) KANONİK FORMÜL (sema: entities:dbo.posOzetUrun)
      irsHrk.ehTutarN (ehTip=100) = SUM( posOzetUrun.satTutar  / (1 + urnKDV.kdvYuzde/100) )
      irsHrk.ehTutarN (ehTip=101) = SUM( posOzetUrun.iadeTutar / (1 + urnKDV.kdvYuzde/100) )
      Join: posOzetUrun.posKDV = urnKDV.kdvID
            posMekan=ehMekan · posTarih=ehTrhS · posStkID=ehstkID

   ⚠ ÜÇ TUZAK BİR ARADA — üçü de bu oturumda yaşandı:
     · `posKDV` ORAN DEĞİL KOD (tinyint; 1=%0 · 2=%1 · 6=%10 · 7=%20).
       `/(1+posKDV/100)` yazmak sessiz yanlış rakam üretir.
     · `satTutar` KDV DAHİL — `ehTutarN` ile doğrudan karşılaştırılamaz.
     · `satIndirim` ÇIKARILMAZ — çıkarınca tutar yarıya iner ve "fiyat tabanı
       farklı" gibi SAHTE bir bulgu doğar. */
