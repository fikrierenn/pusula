/* ═══════════════════════════════════════════════════════════════════════════════
   İKİ BULGU — Satış Analizi drill'i                                   10.09.2026

   (1) "Açık sipariş" kartı YANLIŞ sayı gösteriyordu — eTip süzgeci yoktu.
   (2) "Geçen sezon iyi sattı · bugün rafta yok · merkezde mal var" kohortu panelin
       hiçbir kartına tam girmiyordu.

   Kullanıcı uyardı: "sipariş kısmını kontrol etmelisin bence orada sıkıntı olabilir" ·
   "şubelerde geçen sezon çok iyi satmış ama bu sezon rafında olmayan ama depoda olanlar
   ile ilgili bir bakar mısın" · "satış kaybı olanlar bu tanıma mı giriyor".

   ═══ BULGU 1 — dbo.sip SATIN ALMA TABLOSU DEĞİL ══════════════════════════════
   `dbo.sipTip_vw` 14 kod taşıyor (sqlcli lookup --count-from ile okundu, elle yazılmadı):
     0 Alış 41.743 · 1 Satış 6.997.606 · 2 Mağaza Depo 950 · 3 Yerel Alım 3.495 ·
     4 Depo Depo 931 · 8 Mağaza Mağaza 64 · 9 Alış İade Emri 27.614 ·
     10 Satış İade Emri 1 · 13 Depo Mağaza 22.100 · (5,6,7,11,12 canlıda yok)
   ⇒ Alış tüm kayıtların yalnız %0,6'sı. Drill sorgusu eTip'i HİÇ süzmüyordu.

   Ters yönlü olanları da "yolda mal" sayıyordu:
     · eTip 9 Alış İade Emri = tedarikçiye GERİ GÖNDERME (stok AZALTICI)
     · eTip 1 Satış          = müşteri siparişi        (stok AZALTICI)
     · eTip 2/4/8/13         = iç transfer             (şirket stoğunu DEĞİŞTİRMEZ)
   Kart "üstüne alım yapma" derken mal aslında gidiyordu.

   ÖLÇÜLDÜ (kesim 09.09.2026, 120 gün, panel geneli):
     uyarı alan 37.168 ürün · 17.139'unda (%46,1) gerçek alış siparişi SIFIR → yanlış uyarı
     adet: filtresiz 4.543.969 · GERÇEK ALIŞ 630.682 (%13,9) · alış iade emri 683.186 ·
           müşteri siparişi 1.570.466 · iç transfer 1.659.635
     ⇒ gösterilen adedin %86'sı satın alma siparişi DEĞİLDİ.
   Örnek stkID 1672852 (Bricks Lego — aşırı stoğun en büyük kalemi, 3.741.001 ₺):
     "33.262 adet açık sipariş" → gerçekte 0 alış.
     22.733 (%68) alış iade emri · 8.198 (%25) iç transfer · 2.331 (%7) müşteri siparişi.

   İKİ SINIR (değişmedi, ölçümle teyit edildi):
     · `sipAyr.ehSevkAdet` alış satırlarının %100'ünde NULL (37.537/37.537) → karşılanma
       oranı ölçülemiyor. Adet SİPARİŞ EDİLEN'dir, "yolda kalan" DEĞİL.
     · `eDurum = 2` (kapalı) 24.02.2025'ten beri HİÇ kullanılmamış (5.334 belgenin tamamı
       o tarihten eski) → "açık" iddiası eDurum'a güvenemez; 120 günlük pencere kısmi çözüm.
   Düzeltme: `dashboard/Data/SatisAnaliziQueries.Liste.cs` → `s.eTip IN (0,3)` +
   pencere `GETDATE()` yerine `@kesim` (ölçüm kapsamı = kod kapsamı).

   ═══ BULGU 2 — SEZONLUK RAF AÇIĞI: mal merkezde, raf boş ════════════════════
   Kohort: geçen sezon (Ağu-Eki 2025) O MAĞAZADA ≥10 adet sattı · bugün O MAĞAZANIN
   rafında stok yok · merkez depoda mal var.
     389 çeşit / 459 mağaza-ürün satırı · geçen sezon 35.291 adet = 5.616.497 ₺ ·
     merkezde bekleyen 74.830 adet (talebin ~2 katı → TRANSFERLE çözülür, sipariş gerekmez)

   Mevcut kartların kapsaması (aynı 389 çeşit üzerinde):
     Sezon Stok Açığı        186 (%48) — yakalıyor ama eylemi yanlış ima ediyor (sipariş)
     Raf Bulunurluk Kaybı     52 (%13) — ÜÇ rafın da boş olmasını şart koşuyor; 337'sinde
                                          başka mağazada stok var
     Stokta Yokluk · sezon     4 (%1)  — tanım `ToplamStok<=0`, depoda mal olduğu için dışlıyor
     Aşırı Stok               61 (%16) — ÇELİŞKİ DEĞİL, TEŞHİS: merkez şişik, raf boş
     HİÇBİRİ                 179 (%46) — 15.507 adet / 1.135.340 ₺ panelde hiç görünmüyor
   Sebep: kartlar TOPLAM stoğa bakıyor, merkez stoğunu "var" sayıyor → raf boş olsa da
   "stok yeterli" görünüyor. Mağaza bazlı sezon satışı tabanda YOKTU (Ay1/Ay2/Ay3 üç
   mağazanın TOPLAMI) → taban `SezonFsm/SezonOzl/SezonIst` ile genişletildi.

   İlgili: sema/metrics.yaml → acik_siparis_etip_suzgeci · sezonluk_raf_acigi_merkezde
   ═══════════════════════════════════════════════════════════════════════════════ */

SET NOCOUNT ON;

/* ── 1a) sip belge tipi kümesi — LİSTE ELLE YAZILMAZ ────────────────────────── */
SELECT t.tipID, t.tipAd, COUNT(s.eID) AS Belge
FROM DerinSISBkm.dbo.sipTip_vw t
LEFT JOIN DerinSISBkm.dbo.sip s WITH (NOLOCK) ON s.eTip = t.tipID
GROUP BY t.tipID, t.tipAd
ORDER BY t.tipID;

/* ── 1b) Tek ürünün "açık siparişi" neyden oluşuyor (stkID 1672852) ─────────── */
SELECT s.eTip, t.tipAd, s.eDurum,
       COUNT(DISTINCT s.eID) AS Belge,
       CONVERT(int, SUM(sa.ehAdet)) AS Adet,
       MAX(s.eTarih) AS SonSiparis
FROM DerinSISBkm.dbo.sip s WITH (NOLOCK)
JOIN DerinSISBkm.dbo.sipAyr sa WITH (NOLOCK) ON sa.ehID = s.eID
LEFT JOIN DerinSISBkm.dbo.sipTip_vw t ON t.tipID = s.eTip
WHERE sa.ehstkID = 1672852 AND s.eDurum <> 2
  AND s.eTarih >= DATEADD(DAY, -120, CONVERT(date, '20260909'))
GROUP BY s.eTip, t.tipAd, s.eDurum
ORDER BY 5 DESC;

/* ── 1c) Panel geneli etki: kaç üründe yanlış uyarı, adet nasıl dağılıyor ───── */
WITH s120 AS (
    SELECT sa.ehstkID AS sid, s.eTip, sa.ehAdet
    FROM DerinSISBkm.dbo.sip s WITH (NOLOCK)
    JOIN DerinSISBkm.dbo.sipAyr sa WITH (NOLOCK) ON sa.ehID = s.eID
    WHERE s.eDurum <> 2 AND s.eTarih >= DATEADD(DAY, -120, CONVERT(date, '20260909'))
),
u AS (
    SELECT sid,
           SUM(ehAdet)                                          AS Filtresiz,
           SUM(CASE WHEN eTip IN (0, 3)      THEN ehAdet ELSE 0 END) AS GercekAlis,
           SUM(CASE WHEN eTip = 9            THEN ehAdet ELSE 0 END) AS AlisIadeEmri,
           SUM(CASE WHEN eTip = 1            THEN ehAdet ELSE 0 END) AS MusteriSip,
           SUM(CASE WHEN eTip IN (2,4,8,13)  THEN ehAdet ELSE 0 END) AS IcTransfer
    FROM s120 GROUP BY sid
)
SELECT COUNT(*) AS UrunSayisi,
       SUM(CASE WHEN GercekAlis = 0 THEN 1 ELSE 0 END) AS AlisSiparisiOlmayan,
       CONVERT(decimal(5,1), 100.0 * SUM(CASE WHEN GercekAlis = 0 THEN 1 ELSE 0 END) / COUNT(*))
                                                       AS YanlisUyariYuzde,
       CONVERT(bigint, SUM(Filtresiz))    AS Adet_Filtresiz,
       CONVERT(bigint, SUM(GercekAlis))   AS Adet_GercekAlis,
       CONVERT(bigint, SUM(AlisIadeEmri)) AS Adet_AlisIadeEmri,
       CONVERT(bigint, SUM(MusteriSip))   AS Adet_MusteriSip,
       CONVERT(bigint, SUM(IcTransfer))   AS Adet_IcTransfer
FROM u;

/* ── 1d) ehSevkAdet doluluk — "yolda kalan" ölçülebilir mi? (hayır) ─────────── */
SELECT COUNT(*) AS Satir,
       SUM(CASE WHEN sa.ehSevkAdet IS NULL THEN 1 ELSE 0 END) AS SevkNull,
       SUM(CASE WHEN sa.ehSevkAdet > 0     THEN 1 ELSE 0 END) AS SevkVar,
       CONVERT(int, SUM(sa.ehAdet)) AS SipAdet
FROM DerinSISBkm.dbo.sip s WITH (NOLOCK)
JOIN DerinSISBkm.dbo.sipAyr sa WITH (NOLOCK) ON sa.ehID = s.eID
WHERE s.eTip IN (0, 3) AND s.eDurum <> 2
  AND s.eTarih >= DATEADD(DAY, -120, CONVERT(date, '20260909'));

/* ── 1e) eDurum=2 ne zamandan beri kullanılmıyor ────────────────────────────── */
SELECT s.eDurum, COUNT(*) AS Belge, MIN(s.eTarih) AS Ilk, MAX(s.eTarih) AS Son
FROM DerinSISBkm.dbo.sip s WITH (NOLOCK)
WHERE s.eTip IN (0, 3)
GROUP BY s.eDurum ORDER BY 1;

/* ── 2a) SEZONLUK RAF AÇIĞI kohortu — büyüklük ──────────────────────────────── */
WITH sez AS (   -- geçen sezon, MAĞAZA BAZINDA (taban Ay1/2/3 toplamı bunu vermiyor)
    SELECT h.ehstkID AS sid, h.ehMekan AS mekan, CONVERT(int, -SUM(h.ehAdetN)) AS Adet
    FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
    WHERE h.ehMekan IN (1, 4477, 4478) AND h.ehTip IN (1, 3, 4, 5, 100, 101)
      AND h.ehTrhS >= CONVERT(date, '20250801') AND h.ehTrhS < CONVERT(date, '20251101')
    GROUP BY h.ehstkID, h.ehMekan
    HAVING CONVERT(int, -SUM(h.ehAdetN)) >= 10
),
t AS (
    SELECT * FROM DerinSISBkm.bkm.SatisAnaliziTaban WITH (NOLOCK)
    WHERE Kesim = '2026-09-09' AND SezonYil = 2025
),
j AS (
    SELECT s.sid, s.mekan, s.Adet, t.SatisFiyat, t.MerkezStok,
           CASE s.mekan WHEN 1 THEN t.StokFsm WHEN 4477 THEN t.StokOzl ELSE t.StokIst END AS RafStok
    FROM sez s JOIN t ON t.stkID = s.sid
)
SELECT COUNT(*) AS MagazaUrunSatiri, COUNT(DISTINCT sid) AS Cesit,
       CONVERT(decimal(18,2), SUM(Adet * SatisFiyat)) AS GecenSezonKayipTL,
       CONVERT(bigint, SUM(Adet))        AS GecenSezonAdet,
       CONVERT(bigint, SUM(MerkezStok))  AS MerkezAdet
FROM j
WHERE RafStok <= 0 AND MerkezStok > 0;

/* ── 2b) Mevcut kartlar bu kohortu ne kadar kapsıyor ────────────────────────── */
WITH sez AS (
    SELECT h.ehstkID AS sid, h.ehMekan AS mekan, CONVERT(int, -SUM(h.ehAdetN)) AS Adet
    FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
    WHERE h.ehMekan IN (1, 4477, 4478) AND h.ehTip IN (1, 3, 4, 5, 100, 101)
      AND h.ehTrhS >= CONVERT(date, '20250801') AND h.ehTrhS < CONVERT(date, '20251101')
    GROUP BY h.ehstkID, h.ehMekan
    HAVING CONVERT(int, -SUM(h.ehAdetN)) >= 10
),
t AS (
    SELECT * FROM DerinSISBkm.bkm.SatisAnaliziTaban WITH (NOLOCK)
    WHERE Kesim = '2026-09-09' AND SezonYil = 2025
),
j AS (
    SELECT DISTINCT t.stkID, t.StokFsm, t.StokOzl, t.StokIst, t.MerkezStok,
           t.ToplamStok, t.SezonToplam, t.IlkGiris
    FROM sez s JOIN t ON t.stkID = s.sid
    WHERE (CASE s.mekan WHEN 1 THEN t.StokFsm WHEN 4477 THEN t.StokOzl ELSE t.StokIst END) <= 0
      AND t.MerkezStok > 0
)
SELECT COUNT(*) AS Cesit,
       SUM(CASE WHEN StokFsm <= 0 AND StokOzl <= 0 AND StokIst <= 0 THEN 1 ELSE 0 END) AS RafBos_karti,
       SUM(CASE WHEN ToplamStok <= 0 THEN 1 ELSE 0 END)                                AS StoksuzSezon_karti,
       SUM(CASE WHEN ToplamStok > 0 AND ToplamStok < 0.5 * SezonToplam THEN 1 ELSE 0 END) AS SezonAcik_karti,
       SUM(CASE WHEN ToplamStok > 3 * SezonToplam THEN 1 ELSE 0 END)                    AS AsiriStok_karti,
       SUM(CASE WHEN StokFsm > 0 OR StokOzl > 0 OR StokIst > 0 THEN 1 ELSE 0 END)       AS BaskaRaftaVar
FROM j;
