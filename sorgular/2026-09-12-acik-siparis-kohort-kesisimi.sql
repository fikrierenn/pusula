/* ============================================================================
   AÇIK SİPARİŞ × HESAP-SORMA KOHORTLARI — "yolda mal var" itirazı ölçüldü
   Tarih: 12.09.2026 · DB: DerinSISBkm (bkm.SatisAnaliziTaban kesim 11.09.2026 + dbo.sip/sipAyr)

   NEDEN: `satinalma-danisman` kurulu toplantının EN BÜYÜK RİSKİ olarak şunu işaretledi —
   "alıcı ilk on dakikada 'yolda mal var' diyecek, elinde netleyecek sayı olmadığı için
   kabul edeceksin; sonra 2. ve 3. kartta da aynı şey olacak. Üst üste üç kez 'haklısın'
   demek kalan kartların hepsini geçersiz kılar."
   Panel açık siparişi BİLEREK düşmüyor (kullanıcı direktifi 10.09.2026: "yeni gelen sezon
   siparişlerini var olarak görme"). Bu ölçüm o direktifi DEĞİŞTİRMEZ — netleme yapmaz,
   yalnız itirazın BÜYÜKLÜĞÜNÜ bilmeyi sağlar.

   ═══ SEMA'DAN ALINAN ÜÇ TUZAK (canlı keşif YAPILMADI) ══════════════════════
   1. TARİH: sipariş tarihi = `sip.eTarih` (giriş). `eTarihS` SEVK PLANI ve GEÇMİŞTE
      KALABİLİR — onunla bakınca "Ağustos'ta hiç sipariş girilmemiş" gibi YANLIŞ sonuç çıkar.
   2. ADET: `sipAyr.ehAdet`. **`ehAdetN` DEĞİL** — açık/bekleyen satırlarda 0 olabilir
      (eTip 0 → ehAdet 568.302 vs ehAdetN 105.998). ehAdetN ile ölçersen açık siparişleri
      SIFIR sayarsın.
   3. TİP: dış alım kararı = **eTip 0 (Alış) + 3 (Yerel Alım)**. eTip 9 (Alış İade Emri)
      MAL KABUL işlemidir, alım DEĞİL — 19.08.2026'da bu hataya düşülüp mal kabulcü en büyük
      satınalmacı gösterilmişti. eTip 13 = depo→mağaza sevki, satınalma değil.
   `eDurum <> 2` (iptal şüphesi) süzüldü; 0/1 ayrımının anlamı sema'da TEYİT BEKLİYOR.

   ⚠ SINIR — KARŞILANMA ÖLÇÜLEMİYOR: `sipAyr.ehSevkAdet` tamamen NULL, `irsAyr.ehSipID`
   bağı doğrulanamadı (sema `karsilanma_uyarisi`). Yani "sipariş girilmiş" ≠ "mal hâlâ yolda".
   Bu yüzden pencere DARALTILARAK okunmalı (aşağıya bak).

   ═══ BULGU 1 — "yolda mal var" itirazı, kohort kohort ═════════════════════
   Son 180 günde eTip 0/3 siparişi olan çeşit oranı:
     TALEBİ KANITLI STOKSUZ (356 çeşit)  →   52 çeşit (%14,6) · 1.285 adet
     SEZON STOK AÇIĞI     (7.368 çeşit)  → 2.002 çeşit (%27,2) · 35.247 adet
   ⇒ Talebi kanıtlı kohortta itiraz **%85 geçersiz** — 304 üründe sipariş bile YOK.
   ⇒ Sezon açığı kohortunda itiraz **kısmen HAKLI** (dörtte bir) — kabul edilmeli.

   ═══ BULGU 2 — fazla stoklu ürüne HÂLÂ sipariş giriliyor mu ═══════════════
   Aşırı stok kohortu (maliyet-güvenilir dilim, 35.642 çeşit / 73,71M ₺ fazla):
     pencere      çeşit    sipariş adedi   o çeşitlerin fazla maliyeti
     son  30 gün    674            9.702    0,65M ₺
     son  60 gün  1.507           15.394    1,36M ₺
     son 180 gün  4.097          176.736   10,71M ₺
     sipariş YOK 31.545                0   62,99M ₺

   ⚠⚠ **180 GÜNLÜK SAYIYI "HÂLÂ SİPARİŞ VERİYOR" DİYE OKUMAK YANLIŞTIR** — bu oturumda
   tam bu hataya düşülüp ölçüm daraltılarak düzeltildi. ODAK ortalama temin süresi 5,03 gün;
   180 gün önce girilen siparişin malı ÇOKTAN GELMİŞ ve BUGÜNKÜ STOĞUN İÇİNDE olma
   ihtimali yüksek. Yani o 176.736 adet büyük ölçüde "fazlayı YARATAN" sipariştir,
   "fazlaya EKLENECEK" sipariş değil. İki iddia farklıdır:
     · "fazla stoğa rağmen sipariş GİRİLMİŞ" (geçmiş karar)   → 180 gün penceresi
     · "fazla stoğa rağmen HÂLÂ sipariş giriliyor" (süren davranış) → 30 gün penceresi
   Toplantıda ikincisi kullanılır: **674 çeşit / 9.702 adet / 0,65M ₺**.

   ⇒ ALICININ LEHİNE BULGU (söylenmeli): fazla maliyetin **%85'inde (63,0M ₺) sipariş
     DURMUŞ**. Alıcı büyük ölçüde frenlemiş; besleme yalnız küçük bir dilimde sürüyor.
   ============================================================================ */

DECLARE @k date = (SELECT MAX(Kesim) FROM DerinSISBkm.bkm.SatisAnaliziTaban);

/* ── Açık sipariş özeti: ürün başına adet (SEMA TUZAKLARI UYGULANMIŞ) ─────── */
WITH acik AS (
    SELECT a.ehstkID AS stkID,
           SUM(CONVERT(float, a.ehAdet))  AS SipAdet,      -- ehAdetN DEĞİL
           COUNT(DISTINCT s.eID)          AS SipSayi
    FROM DerinSISBkm.dbo.sipAyr a WITH (NOLOCK)
    JOIN DerinSISBkm.dbo.sip    s WITH (NOLOCK) ON s.eID = a.ehID
    WHERE s.eTip IN (0, 3)                                  -- Alış + Yerel Alım (9/13 HARİÇ)
      AND s.eDurum <> 2                                     -- iptal şüphesi
      AND s.eTarih >= DATEADD(DAY, -180, @k)                -- eTarihS DEĞİL
      AND s.eTarih <  DATEADD(DAY, 1, @k)
    GROUP BY a.ehstkID
),
t AS (
    SELECT * FROM DerinSISBkm.bkm.SatisAnaliziTaban WITH (NOLOCK)
    WHERE Kesim = @k AND SezonYil = 2025
      AND StokFsm >= 0 AND StokOzl >= 0 AND StokIst >= 0 AND MerkezStok >= 0 AND SatisFiyat > 0
)
SELECT 'A) TALEBI KANITLI STOKSUZ' AS kohort, COUNT(*) AS cesit,
       SUM(CASE WHEN c.stkID IS NOT NULL THEN 1 ELSE 0 END) AS siparisiVar,
       CONVERT(decimal(14,0), SUM(ISNULL(c.SipAdet, 0)))    AS sipAdet
FROM t LEFT JOIN acik c ON c.stkID = t.stkID
WHERE t.SezonToplam >= 20 AND t.ToplamStok = 0
UNION ALL
SELECT 'B) SEZON STOK ACIGI', COUNT(*),
       SUM(CASE WHEN c.stkID IS NOT NULL THEN 1 ELSE 0 END),
       CONVERT(decimal(14,0), SUM(ISNULL(c.SipAdet, 0)))
FROM t LEFT JOIN acik c ON c.stkID = t.stkID
WHERE t.SezonToplam > 0 AND t.ToplamStok > 0
  AND CONVERT(float, t.ToplamStok) < 0.5 * t.SezonToplam;
-- ÖLÇÜLDÜ: A) 356 / 52 / 1.285   ·   B) 7.368 / 2.002 / 35.247

/* ── Aşırı stok × sipariş penceresi (30 / 60 / 180 gün) ───────────────────── */
-- Aşırı stok kohortu tanımı için bkz. sorgular/2026-09-12-esik-is-modelinden-kapak.sql
-- (iki ayaklı eşik) + 2026-09-12-maliyet-kaydi-supheli.sql (maliyet güvenilir şartı).
-- Aynı `acik` CTE'si 30/60 günlük SUM'larla kurulur ve LEFT JOIN edilir.
-- ÖLÇÜLDÜ: 30g 674 / 9.702 / 0,65M · 60g 1.507 / 15.394 / 1,36M ·
--          180g 4.097 / 176.736 / 10,71M · siparişsiz 31.545 / 62,99M
