/* ═══════════════════════════════════════════════════════════════════════════════
   EŞİK TÜRETMENİN İSTATİSTİĞİ + TALEP DESENİ + SEKTÖR KIYASI          10.09.2026

   Kullanıcı direktifleri:
     "bence bunlar için kabul görmüş istatistik yöntemleri varsa onları da kullanarak
      değerlendirme yapmak gerekiyor sanki litaratür araştırmalısın"
     "daha iyisi yok mu derin araştır belki de direkt kitap perakende kırtasiye
      özelinde çalışmalar bile vardır"

   ═══ 1) ÖLÇÜT SINAMASI — Cochran-Armitage + Wilson ══════════════════════════
   "Rafı boş, merkezde mal var" kartının yeterlilik ölçütü aranırken iki aday eksen
   geriye dönük ölçüldü: as-of 01.08.2025 rafı boş + merkezinde mal olan ürünler,
   sonuç değişkeni SONRAKİ 12 AYDA satıldı mı (evet/hayır).

   MERKEZ STOĞU ekseni (bant · n · x · oran · %95 Wilson):
     1 adet  3644  117   3,2%  [2,7 - 3,8]
     2       1758   86   4,9%  [4,0 - 6,0]
     3-4     1643  134   8,2%  [6,9 - 9,6]
     5-9     1409  104   7,4%  [6,1 - 8,9]
     10-24   1119   72   6,4%  [5,1 - 8,0]
     25+      779   93  11,9%  [9,8 - 14,4]
     Cochran-Armitage: chi2(1) = 95,57 · p = 1,43e-22
     MONOTON DEĞİL (8,2 → 7,4 → 6,4) · iki komşu bant GA'sı ÇAKIŞIK  ⇒ ÖLÇÜT REDDEDİLDİ

   ÖNCEKİ YIL TALEBİ ekseni (aynı kohort, aynı sonuç değişkeni):
     talep yok 8736  306   3,5%  [3,1 - 3,9]
     1-4 adet  1330  177  13,3%  [11,6 - 15,2]
     5-19       229   88  38,4%  [32,4 - 44,9]
     20-49       47   27  57,4%  [43,3 - 70,5]
     50+         10    6  60,0%  [31,3 - 83,2]
     Cochran-Armitage: chi2(1) = 873,01 · p = 7,24e-192
     MONOTON · 1-4 ile 5-19 GA'ları ÇAKIŞMIYOR  ⇒ "yılda 5+ satış" ölçütü SEÇİLDİ
     ⚠ Üst iki bant tek başına güvenilmez (n=47 ve n=10, GA'ları çakışık) → 20-49 ile
       50+ arasında ayrım YAPILMADI.

   ⚠ EN ÖNEMLİ DERS: merkez ekseninde p = 1,4e-22 (son derece küçük) olmasına RAĞMEN
   ölçüt geçersiz. Cochran-Armitage yalnız DOĞRUSAL trende karşı güçlüdür; U-şeklini ve
   monoton olmayanı kaçırır. Küçük p bir ölçütü doğrulamaz.

   ⚠⚠ VERİDEN SEÇİLEN KESİMİN BEDELİ: Altman & Royston 2006 (BMJ, "The cost of
   dichotomising continuous variables") ve Royston/Altman/Sauerbrei 2006 (Stat Med,
   "Dichotomizing continuous predictors in multiple regression: a bad idea") —
   veriden türetilen "optimal kesim" gruplar arası farkı ABARTIR, spuriously
   significant sonuç riski taşır, tekrarlanabilirliği düşüktür; medyandan bölmek
   verinin üçte birini atmakla aynı güç kaybını verir.
   ⇒ Kesimdeki oran farkı (%13,3 → %38,4) bir ETKİ ÖLÇÜSÜ olarak SUNULMAZ.
   Panelin üç eşiği de (aşırı stok 3× · sezon 0,50 · raf kaybı 5 satış) bu uyarıya tabi.

   ═══ 2) TALEP DESENİ — panelin en büyük yapısal sınırı ══════════════════════
   Aralıklı talep (intermittent demand) çerçevesi: Croston 1972 · Syntetos-Boylan 2005
   (SBA, Croston'ın yanlılığını düzeltir) · Syntetos/Boylan/Croston 2005 sınıflandırma
   (talep-arası aralık ADI + talep büyüklüğü CV²; ADI eşiği ~1,32) · Teunter/Syntetos/
   Babai 2011 (TSB — eskime/obsolescence için sıfır-talep olasılığını ayrı izler).

   ÖLÇÜLDÜ (Eyl 2025 – Ağu 2026, 12 TAM ay, satış olan ay sayısına göre):
     hiç satmadı           121.411  %44,1
     1-2 ay  (ADI >= 6)     76.912  %27,9
     3-4 ay  (ADI 3-4)      27.587  %10,0
     5-8 ay  (ADI 1,5-2,4)  27.045   %9,8
     9-12 ay (ADI <= 1,33)  22.430   %8,1   ← DÜZGÜN talep, yalnız bu
   ⇒ Çeşitlerin %91,9'unda "günlük ortalama satış" ve "gün-stok" YANILTICI: ortalama,
     çoğu SIFIR olan aylara yayılıyor. Panelde Croston/SBA ayrıştırması YAPILMADI;
     ürün bazlı gün-stok yalnız %8,1'de güvenilir, kategori agregasında savunulabilir.

   ═══ 3) SEKTÖR KIYASI — devir hızı ═════════════════════════════════════════
   ÖLÇÜLDÜ (mağaza stoğu ÷ 365 günlük mağaza satışı, adet · güvenilir defter):
     Dergi 5,95 · Oyuncak 3,29 · Hazırlık Kitapları 3,16 · Hediyelik 2,11 ·
     Çocuk Kitabı 2,09 · Elektronik 1,91 · Akademi 1,35 · Kitap 1,28 · Kırtasiye 1,25
     Gün-stok: Kitap 285 · Kırtasiye 291 · Akademi 270 · Dergi 61
   Yayınlanmış kitapçı hedefi 3,0-4,0 devir/yıl (yüksek performanslı 4-6); GMROI hedefi
   çoğu perakende kategorisinde 3,0+. Ölçülen yaklaşık GMROI: 0,32-1,38.
   ⚠ Kıyas kaynağı TİCARİ/SEKTÖR YAYINI, akademik ölçüm DEĞİL. BKM saf kitapçı değil
     (kırtasiye + sınav okulları + grup şirketi mal akışı, merkez çıkışının %72'si frmID 56).
   ⚠ GMROI hesabım standart DEĞİL: payda ANLIK stok maliyeti (ortalama stok değil),
     pay 365 günlük POS kârı, maliyet kapsamı etiket bazında %94,7 → "yaklaşık".
   ⇒ Aşırı stok eşiği sektör hedefine ÇEKİLMEDİ: 3× eşiği yıllık devir 1,0'a denk;
     sektör hedefi ~0,25-0,33× kapsamaya karşılık gelir ve kohorta 200 binden fazla
     çeşit sokup listeyi işe yaramaz hâle getirir. Fark bilinçli, panelde beyan edildi.

   ═══ 4) KAYIT DOĞRULUĞU ve SANSÜRLÜ TALEP — beyan edilen sınırlar ═══════════
   · Kayıt-fiziksel uyuşmazlığı (inventory record inaccuracy) literatürde SKU'ların
     %50-70'inde; DeHoratius & Raman 369.567 kaydın %65'i hatalı, hataların %41'i
     "fiziksel > kayıt" yönünde; hayalet stok kaynaklı kayıp ~yıllık cironun %4'ü.
     BKM panelinin "doğrulanamıyor" oranı %0,12 (327/275.385) — bu DOĞRULUK ORANI DEĞİL,
     yalnız aritmetik olarak imkânsız (negatif stok / fiyat 0) kayıtların oranı.
     Gerçek sapma yalnız FİZİKSEL SAYIMLA bilinir.
   · Kayıp satış tahminleri ALT SINIRDIR: talep vekili olarak geçen yılın GERÇEKLEŞEN
     satışı kullanılıyor, o satış da stok tükenen günlerde kesilmiş (sağdan sansürlü).
     Kabul görmüş düzeltme EM tabanlı sansürlü-talep tahmini + ikame modellemesi
     (Anupindi/Dada/Gupta 1998 · Conlon & Mortimer). Panelde uygulanmadı.

   Kural: .claude/rules/olctum-mu-cikardim-mi.md § EŞİK TÜRETME
   Sema: sema/metrics.yaml → esik_turetme_istatistigi · talep_deseni_aralikli ·
         devir_hizi_sektor_kiyasi
   ═══════════════════════════════════════════════════════════════════════════════ */

SET NOCOUNT ON;

/* ── 1) Ölçüt sınaması için sayaçlar (CA testi + Wilson Python'da hesaplanır) ── */
WITH raf AS (   -- as-of 01.08.2025 mağaza rafı, mekan bazında
    SELECT ehstkID AS sid,
           SUM(CASE WHEN ehMekan = 1    THEN ehAdetN ELSE 0 END) AS Fsm,
           SUM(CASE WHEN ehMekan = 4477 THEN ehAdetN ELSE 0 END) AS Ozl,
           SUM(CASE WHEN ehMekan = 4478 THEN ehAdetN ELSE 0 END) AS Ist
    FROM DerinSISBkm.dbo.irsHrk WITH (NOLOCK)
    WHERE ehMekan IN (1, 4477, 4478) AND ehTrhS < CONVERT(date, '20250801')
    GROUP BY ehstkID
),
mrk AS (        -- ⚠ merkez as-of DEFTERDEN (WMS geçmişi yok) — beyan edilen sınır
    SELECT ehstkID AS sid, SUM(ehAdetN) AS Merkez
    FROM DerinSISBkm.dbo.irsHrk WITH (NOLOCK)
    WHERE ehMekan = 12 AND ehTrhS < CONVERT(date, '20250801')
    GROUP BY ehstkID
),
onc AS (        -- ÖNCEKİ 12 ay mağaza satışı = TALEP KANITI
    SELECT ehstkID AS sid, CONVERT(int, -SUM(ehAdetN)) AS Satis
    FROM DerinSISBkm.dbo.irsHrk WITH (NOLOCK)
    WHERE ehMekan IN (1, 4477, 4478) AND ehTip IN (1, 3, 4, 5, 100, 101)
      AND ehTrhS >= CONVERT(date, '20240801') AND ehTrhS < CONVERT(date, '20250801')
    GROUP BY ehstkID
),
son AS (        -- SONRAKİ 12 ay = SONUÇ
    SELECT ehstkID AS sid, CONVERT(int, -SUM(ehAdetN)) AS Satis
    FROM DerinSISBkm.dbo.irsHrk WITH (NOLOCK)
    WHERE ehMekan IN (1, 4477, 4478) AND ehTip IN (1, 3, 4, 5, 100, 101)
      AND ehTrhS >= CONVERT(date, '20250801') AND ehTrhS < CONVERT(date, '20260801')
    GROUP BY ehstkID
),
k AS (
    SELECT r.sid, m.Merkez, ISNULL(o.Satis, 0) AS Onc,
           CASE WHEN ISNULL(s.Satis, 0) > 0 THEN 1 ELSE 0 END AS Satti
    FROM raf r
    JOIN mrk m ON m.sid = r.sid
    LEFT JOIN onc o ON o.sid = r.sid
    LEFT JOIN son s ON s.sid = r.sid
    WHERE r.Fsm = 0 AND r.Ozl = 0 AND r.Ist = 0 AND m.Merkez > 0
)
SELECT 'TALEP' AS Eksen,
       CASE WHEN Onc <= 0 THEN 0 WHEN Onc < 5 THEN 1 WHEN Onc < 20 THEN 2
            WHEN Onc < 50 THEN 3 ELSE 4 END AS Skor,
       COUNT(*) AS n, SUM(Satti) AS x
FROM k
GROUP BY CASE WHEN Onc <= 0 THEN 0 WHEN Onc < 5 THEN 1 WHEN Onc < 20 THEN 2
              WHEN Onc < 50 THEN 3 ELSE 4 END
UNION ALL
SELECT 'MERKEZ',
       CASE WHEN Merkez = 1 THEN 0 WHEN Merkez = 2 THEN 1 WHEN Merkez < 5 THEN 2
            WHEN Merkez < 10 THEN 3 WHEN Merkez < 25 THEN 4 ELSE 5 END,
       COUNT(*), SUM(Satti)
FROM k
GROUP BY CASE WHEN Merkez = 1 THEN 0 WHEN Merkez = 2 THEN 1 WHEN Merkez < 5 THEN 2
              WHEN Merkez < 10 THEN 3 WHEN Merkez < 25 THEN 4 ELSE 5 END
ORDER BY 1, 2;

/* ── 2) TALEP DESENİ — satış olan ay sayısı (ADI vekili) ────────────────────── */
WITH ay AS (
    SELECT h.ehstkID AS sid, DATEFROMPARTS(YEAR(h.ehTrhS), MONTH(h.ehTrhS), 1) AS Ay,
           CONVERT(int, -SUM(h.ehAdetN)) AS Adet
    FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
    WHERE h.ehMekan IN (1, 4477, 4478) AND h.ehTip IN (1, 3, 4, 5, 100, 101)
      AND h.ehTrhS >= CONVERT(date, '20250901') AND h.ehTrhS < CONVERT(date, '20260901')
    GROUP BY h.ehstkID, DATEFROMPARTS(YEAR(h.ehTrhS), MONTH(h.ehTrhS), 1)
    HAVING CONVERT(int, -SUM(h.ehAdetN)) > 0
),
u AS (SELECT sid, COUNT(*) AS SatanAy FROM ay GROUP BY sid),
j AS (
    SELECT t.stkID, ISNULL(u.SatanAy, 0) AS SatanAy
    FROM DerinSISBkm.bkm.SatisAnaliziTaban t WITH (NOLOCK)
    LEFT JOIN u ON u.sid = t.stkID
    WHERE t.Kesim = '2026-09-09' AND t.SezonYil = 2025
)
SELECT CASE WHEN SatanAy = 0 THEN '0) hic satmadi'
            WHEN SatanAy <= 2 THEN '1) 1-2 ay (ADI>=6)'
            WHEN SatanAy <= 4 THEN '2) 3-4 ay (ADI 3-4)'
            WHEN SatanAy <= 8 THEN '3) 5-8 ay (ADI 1,5-2,4)'
            ELSE '4) 9-12 ay (ADI<=1,33 duzgun)' END AS TalepDeseni,
       COUNT(*) AS Cesit,
       CONVERT(decimal(5,1), 100.0 * COUNT(*) / SUM(COUNT(*)) OVER ()) AS Pay
FROM j
GROUP BY CASE WHEN SatanAy = 0 THEN '0) hic satmadi'
              WHEN SatanAy <= 2 THEN '1) 1-2 ay (ADI>=6)'
              WHEN SatanAy <= 4 THEN '2) 3-4 ay (ADI 3-4)'
              WHEN SatanAy <= 8 THEN '3) 5-8 ay (ADI 1,5-2,4)'
              ELSE '4) 9-12 ay (ADI<=1,33 duzgun)' END
ORDER BY 1;

/* ── 3) SEKTÖR KIYASI — kategori devir hızı + yaklaşık GMROI ────────────────── */
WITH t AS (
    SELECT * FROM DerinSISBkm.bkm.SatisAnaliziTaban WITH (NOLOCK)
    WHERE Kesim = '2026-09-09' AND SezonYil = 2025
      AND StokFsm >= 0 AND StokOzl >= 0 AND StokIst >= 0 AND MerkezStok >= 0 AND SatisFiyat > 0
)
SELECT Kategori3,
       COUNT(*) AS Cesit,
       CONVERT(bigint, SUM(MagazaStok))  AS MagazaStok,
       CONVERT(bigint, SUM(SatisToplam)) AS Satis365,
       CONVERT(decimal(5,2), SUM(CONVERT(decimal(18,2), SatisToplam))
             / NULLIF(SUM(MagazaStok), 0))                        AS YillikDevir_adet,
       CONVERT(int, 365.0 * SUM(MagazaStok) / NULLIF(SUM(SatisToplam), 0)) AS GunStok,
       -- ⚠ STANDART GMROI DEĞİL: payda ANLIK stok maliyeti (ortalama stok değil)
       CONVERT(decimal(5,2),
           SUM(CASE WHEN BirimMaliyet > 0 AND PosAdet > 0
                    THEN (PosNet - PosKdv) - CONVERT(decimal(18,4), PosAdet) * BirimMaliyet
                    ELSE 0 END)
         / NULLIF(SUM(CASE WHEN BirimMaliyet > 0
                           THEN CONVERT(decimal(18,4), ToplamStok) * BirimMaliyet
                           ELSE 0 END), 0))                       AS GMROI_yaklasik
FROM t
GROUP BY Kategori3
ORDER BY YillikDevir_adet DESC;
