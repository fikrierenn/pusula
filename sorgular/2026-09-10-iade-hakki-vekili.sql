/* ═══════════════════════════════════════════════════════════════════════════════
   İADE HAKKI — kod anlamı çıkmadı, DAVRANIŞ vekili çıktı              10.09.2026

   Panel "iade hakkı veride izli değil → aşırı stok kırılamıyor" diyordu.
   B-150 / B-167(c): `dbo.frm.frmIadeKural` 0/1/2 anlamı belgesiz, lookup view YOK.

   ═══ 1) KOD ANLAMI VERİDEN ÇIKMADI ══════════════════════════════════════════
   Hipotez: iade hakkı olmayan kodda fiilî iade de olmaz → koddan anlam çıkar.
   ÖLÇÜLDÜ (frmTip=0 tedarikçiler, son 365 gün, alış ehTip 0+10 / iade ehTip 2):

     Kod  tedarikçi  alış yapılan  iade yapılan  oran    %95 Wilson GA
      0      1.284         87          16       18,4%   [11,6 - 27,8]
      1         99         11           4       36,4%   [15,2 - 64,6]
      2      1.273         90          36       40,0%   [30,5 - 50,3]
     Adet bazında iade/alış: kod 0 → %19,26 · kod 1 → %1,40 · kod 2 → %5,42

     Cochran-Armitage trend: chi2(1) = 9,86 · p = 0,00169
     ⚠ AMA komşu Wilson aralıklarının HEPSİ ÇAKIŞIK (0-1 çakışık, 1-2 çakışık) ve
       kod 1'de n = 11 → tek başına hiçbir şey söylemiyor.
   ⇒ Kendi kuralımıza göre (olctum-mu-cikardim-mi.md § EŞİK TÜRETME: küçük p yetmez,
     komşu GA'lar ayrışmalı) AYRIM DESTEKLENMEDİ. Üç kodun HEPSİNDE fiilî iade var;
     hiçbiri "iade yok" demiyor. Kod fiilî davranışı ÖNGÖRMÜYOR.
   ⇒ B-150 veriden KAPATILAMAZ. Ama soru keskinleşti: "hangi kod iade hakkı var?"
     yerine "bu alan bugün bir kural mı taşıyor, yoksa terk edilmiş varsayılan mı?"

   ═══ 2) İŞE YARAYAN VEKİL: tedarikçinin GÖZLENEN iade oranı ══════════════════
   Koda hiç ihtiyaç duymadan: tedarikçinin son 2 yıldaki iade/alış oranı. Ürünün
   tedarikçisi = son alış faturasının firması (730 gün içinde).
   Aşırı stok (3× eşiği, güvenilir defter, 308,3M ₺) bu orana göre:

     tedarikçi iade oranı   çeşit    tutar ₺        pay
     hiç iade YOK             905    20.708.983    %6,7
     %0-2                   2.379    56.883.847   %18,5
     %2-10                 20.171   137.884.733   %44,7
     %10-25                 1.124    45.054.376   %14,6
     %25+                      26     2.061.531    %0,7
     tedarikçi bilinmiyor   5.019    45.597.521   %14,8   (730 günde alış faturası yok)

   ⇒ Aşırı stoğun %25,2'si (77,6M ₺) iadesi %2'nin ALTINDAKİ tedarikçilerden:
     orada "iade ile çözülür" savunması ZAYIF. %15,3'ünde (47,1M ₺) tedarikçi fiilen
     iade kabul ediyor (>%10) → o kısımda aşırı stok riski gerçekten daha küçük.

   ⚠ VEKİL, HAK DEĞİL — dört sınır:
     (a) hakkı olup kullanmayan tedarikçi "hiç iade yok" görünür (yanlış negatif),
     (b) oran ÜRÜN değil TEDARİKÇİ düzeyinde; kullanıcı "her kitapta yok iade" demişti,
     (c) TERS NEDENSELLİK: aşırı stok biriken üründe iade YAPILMIŞ olabilir → oran
         kısmen sonucun kendisi,
     (d) "tedarikçi bilinmiyor" %14,8 — eski stok, son 2 yılda alış faturası yok.
   ⇒ Panelde KIRILIM YAPILMADI, kapsam bandında beyan edildi.

   Sema: sema/entities.yaml → frm_iade_vade_kosullari (kod anlamı hâlâ teyit bekliyor)
         sema/metrics.yaml → iade_davranisi_vekili
   ═══════════════════════════════════════════════════════════════════════════════ */

SET NOCOUNT ON;

/* ── 1) Kod ↔ fiilî iade davranışı (anlam çıkmadı) ──────────────────────────── */
WITH alis AS (
    SELECT i.eFirma AS frm, CONVERT(bigint, SUM(h.ehAdetN)) AS Adet,
           COUNT(DISTINCT i.eID) AS Belge
    FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
    JOIN DerinSISBkm.dbo.irs i WITH (NOLOCK) ON i.eID = h.ehID
    WHERE h.ehTip IN (0, 10)
      AND h.ehTrhS >= DATEADD(DAY, -365, CONVERT(date, '20260909'))
    GROUP BY i.eFirma
),
iade AS (
    SELECT i.eFirma AS frm, CONVERT(bigint, -SUM(h.ehAdetN)) AS Adet,
           COUNT(DISTINCT i.eID) AS Belge
    FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
    JOIN DerinSISBkm.dbo.irs i WITH (NOLOCK) ON i.eID = h.ehID
    WHERE h.ehTip = 2
      AND h.ehTrhS >= DATEADD(DAY, -365, CONVERT(date, '20260909'))
    GROUP BY i.eFirma
)
SELECT f.frmIadeKural AS Kod,
       COUNT(*) AS Tedarikci,
       SUM(CASE WHEN a.frm IS NOT NULL THEN 1 ELSE 0 END) AS AlisYapilan,
       SUM(CASE WHEN d.frm IS NOT NULL THEN 1 ELSE 0 END) AS IadeYapilan,
       CONVERT(decimal(5,1), 100.0 * SUM(CASE WHEN d.frm IS NOT NULL THEN 1 ELSE 0 END)
             / NULLIF(SUM(CASE WHEN a.frm IS NOT NULL THEN 1 ELSE 0 END), 0)) AS IadeYapilanYuzde,
       CONVERT(bigint, SUM(ISNULL(a.Adet, 0))) AS AlisAdet,
       CONVERT(bigint, SUM(ISNULL(d.Adet, 0))) AS IadeAdet,
       CONVERT(decimal(6,2), 100.0 * SUM(ISNULL(d.Adet, 0))
             / NULLIF(SUM(ISNULL(a.Adet, 0)), 0)) AS IadeOraniYuzde
FROM DerinSISBkm.dbo.frm f WITH (NOLOCK)
LEFT JOIN alis a ON a.frm = f.frmID
LEFT JOIN iade d ON d.frm = f.frmID
WHERE f.frmTip = 0
GROUP BY f.frmIadeKural
ORDER BY 1;

/* ── 2) Aşırı stok × tedarikçinin gözlenen iade oranı (işe yarayan vekil) ───── */
WITH alis AS (
    SELECT i.eFirma AS frm, SUM(h.ehAdetN) AS Adet
    FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
    JOIN DerinSISBkm.dbo.irs i WITH (NOLOCK) ON i.eID = h.ehID
    WHERE h.ehTip IN (0, 10)
      AND h.ehTrhS >= DATEADD(DAY, -730, CONVERT(date, '20260909'))
    GROUP BY i.eFirma
    HAVING SUM(h.ehAdetN) > 0
),
iade AS (
    SELECT i.eFirma AS frm, -SUM(h.ehAdetN) AS Adet
    FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
    JOIN DerinSISBkm.dbo.irs i WITH (NOLOCK) ON i.eID = h.ehID
    WHERE h.ehTip = 2
      AND h.ehTrhS >= DATEADD(DAY, -730, CONVERT(date, '20260909'))
    GROUP BY i.eFirma
),
tf AS (
    SELECT a.frm, CONVERT(decimal(6,4), ISNULL(d.Adet, 0) / a.Adet) AS Oran
    FROM alis a LEFT JOIN iade d ON d.frm = a.frm
),
son AS (   -- ürünün tedarikçisi = SON alış faturasının firması (730 gün içinde)
    SELECT x.stkID, x.eFirma FROM (
        SELECT fa.ehStkID AS stkID, f.eFirma,
               ROW_NUMBER() OVER (PARTITION BY fa.ehStkID
                                  ORDER BY f.eTarih DESC, f.eID DESC) AS sira
        FROM DerinSISBkm.dbo.fatAyr fa WITH (NOLOCK)
        JOIN DerinSISBkm.dbo.fat f WITH (NOLOCK) ON f.eID = fa.ehID
        WHERE f.eTip = 0 AND f.eDurum <> 2
          AND f.eTarih >= DATEADD(DAY, -730, CONVERT(date, '20260909'))
    ) x WHERE x.sira = 1
),
t AS (     -- AŞIRI STOK kohortu: panelin ölçütüyle AYNI (3× + güvenilir defter)
    SELECT * FROM DerinSISBkm.bkm.SatisAnaliziTaban WITH (NOLOCK)
    WHERE Kesim = '2026-09-09' AND SezonYil = 2025
      AND StokFsm >= 0 AND StokOzl >= 0 AND StokIst >= 0 AND MerkezStok >= 0 AND SatisFiyat > 0
      AND SezonToplam > 0 AND ToplamStok > 3 * SezonToplam
)
SELECT CASE WHEN tf.Oran IS NULL THEN '9) tedarikci bilinmiyor'
            WHEN tf.Oran = 0     THEN '0) hic iade YOK'
            WHEN tf.Oran < 0.02  THEN '1) %0-2'
            WHEN tf.Oran < 0.10  THEN '2) %2-10'
            WHEN tf.Oran < 0.25  THEN '3) %10-25'
            ELSE '4) %25+' END AS TedarikciIadeOrani,
       COUNT(*) AS AsiriStokCesit,
       CONVERT(decimal(18,2), SUM(t.Tutar)) AS AsiriStokTL,
       CONVERT(decimal(5,1), 100.0 * SUM(t.Tutar) / SUM(SUM(t.Tutar)) OVER ()) AS TutarPay
FROM t
LEFT JOIN son ON son.stkID = t.stkID
LEFT JOIN tf  ON tf.frm = son.eFirma
GROUP BY CASE WHEN tf.Oran IS NULL THEN '9) tedarikci bilinmiyor'
              WHEN tf.Oran = 0     THEN '0) hic iade YOK'
              WHEN tf.Oran < 0.02  THEN '1) %0-2'
              WHEN tf.Oran < 0.10  THEN '2) %2-10'
              WHEN tf.Oran < 0.25  THEN '3) %10-25'
              ELSE '4) %25+' END
ORDER BY 1;
