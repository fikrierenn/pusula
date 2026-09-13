/* ============================================================================
   2026 KAPANIŞ + 2027 TAHMİN — TABAN ÖLÇÜMLERİ                    2026-09-13
   DB: DerinSISBkm (profil: erp)

   GMY istekleri, sırayla:
     1) "2027 şube ciro satış tahmini... ay şube hatta kategori adet birim fiyat
         ciro kırılımlı" → "ay şube kategori çalışman lazım"
     2) "ilk önce bu yıl kalan ayların kapanışlarını tahmin etmen lazım sanırım"
     3) "seneye de bayram resmi tatil dini bayram okul sezonu vs dikkate almalısın"

   Modeli koşan script: `scripts/tahmin_2027_sube_kategori.py`
   Çıktı: `raporlar/2027-tahmin-ay-sube-kategori.xlsx`
   Bu dosya = modelin DAYANDIĞI ölçümler (tekrar üretilebilir olsun diye).
   ============================================================================ */

/* ── 1) ★ GEÇMİŞİN DERİNLİĞİ — 5 yıl, üç şube, ADET + CİRO ─────────────────── */
SELECT YEAR(h.ehTrhS) AS yil, COUNT(DISTINCT MONTH(h.ehTrhS)) AS ay_sayisi,
       CONVERT(decimal(18,0), SUM(CASE WHEN h.ehTip IN (100,4) THEN h.ehTutarN
              ELSE -h.ehTutarN END)) AS net_ciro,
       CONVERT(decimal(18,0), SUM(CASE WHEN h.ehTip IN (100,4) THEN ABS(h.ehAdetN)
              ELSE -ABS(h.ehAdetN) END)) AS net_adet
FROM   DerinSISBkm.dbo.irsHrk h WITH(NOLOCK)
WHERE  h.ehTip IN (100,101,4,5) AND h.ehMekan IN (1,4477,4478)
       AND h.ehTrhS >= '20220101'
GROUP BY YEAR(h.ehTrhS) ORDER BY yil;
/* yıl    net ciro ₺      net adet    birim ₺
   2022   187.997.698    3.056.960      61,5
   2023   332.809.941    3.484.997      95,5
   2024   633.389.311    3.967.214     159,7
   2025   974.355.464    4.912.349     198,4
   2026*  873.102.177    3.918.027     222,8   (*9 ay, Eylül KISMİ)
   ⇒ Tahmin için yeterli derinlik var. ⚠ Bu tablo SINAV DAHİLdir. */

/* ── 2) ★★ SEGMENT AYRIMI — Sınav ayrı tutulmalı (GMY kararı) ─────────────── */
SELECT YEAR(h.ehTrhS) AS yil,
       CASE WHEN b.KatAna LIKE 'Sınav Okul%' THEN 'SINAV' ELSE 'PERAKENDE' END AS segment,
       CONVERT(decimal(18,0), SUM(CASE WHEN h.ehTip IN (100,4) THEN h.ehTutarN
              ELSE -h.ehTutarN END)) AS ciro,
       CONVERT(decimal(18,0), SUM(CASE WHEN h.ehTip IN (100,4) THEN ABS(h.ehAdetN)
              ELSE -ABS(h.ehAdetN) END)) AS adet
FROM   DerinSISBkm.dbo.irsHrk h WITH(NOLOCK)
JOIN   DerinSISBkm.bkm.UrunBilgi b WITH(NOLOCK) ON b.stkID = h.ehstkID
WHERE  h.ehTip IN (100,101,4,5) AND h.ehMekan IN (1,4477,4478)
       AND h.ehTrhS >= '20240101'
GROUP BY YEAR(h.ehTrhS),
         CASE WHEN b.KatAna LIKE 'Sınav Okul%' THEN 'SINAV' ELSE 'PERAKENDE' END
ORDER BY yil, segment;
/* segment    yıl     ciro ₺        adet      birim ₺
   PERAKENDE 2024   399.318.185   3.904.775    102
             2025   630.967.949   4.862.626    130
             2026*  565.424.737   3.886.258    146
   SINAV     2024   234.071.127      62.439  3.749
             2025   343.384.909      49.700  6.909
             2026*  307.677.209      31.767  9.686
   ⚠⚠ SINAV'IN ADEDİ İKİ YILDA YARIYA İNDİ (62.439 → 31.767) ve ciroyu FİYAT
     taşıyor. Perakendeyle aynı model geçerli DEĞİL ⇒ GMY kararı: "Sınav'ı ayrı
     tut, karıştırma". Excel'de ayrı sayfa, TAHMİN YOK, yalnız gerçekleşen. */

/* ── 3) ★★ İKİ KUVVET TERS YÖNDE — adet hızlanıyor, fiyat yavaşlıyor ──────── */
-- (aylık seri; Oca-Ağu kıyaslanabilir pencerede hesaplandı)
/* dönem      adet büyümesi   birim fiyat artışı
   2024/2023      +%13,3            —
   2025/2024      +%21,3          ~+%30
   2026/2025      +%33,0          ~+%17,9
   ⇒ Ciro TEK PARÇA tahmin edilemez: hacim hızlanırken fiyat yavaşlıyor.
     Model ikisini AYRI taşır; üç senaryo yalnız FİYATI değiştirir. */

/* ── 4) ★★★ OKUL-HİZALI k — Eylül TAKVİMLE kapatılamaz ────────────────────── */
-- Sema `sezon_ciro_tahmini_okul_hizali`: okul açılışı kayan yılda tahmin takvim
-- ayı üzerinden YAPILMAZ. ÖLÇÜLEN açılışlar: 2024→09.09 · 2025→08.09 · 2026→14.09.
-- 2026'da açılış 6 GÜN GEÇ. Ofset = gün − o yılın açılışı.
WITH g AS (
  SELECT CAST(h.ehTrhS AS date) AS gun,
         CASE WHEN YEAR(h.ehTrhS)=2026 THEN DATEDIFF(DAY,'20260914',h.ehTrhS)
              WHEN YEAR(h.ehTrhS)=2025 THEN DATEDIFF(DAY,'20250908',h.ehTrhS)
              ELSE DATEDIFF(DAY,'20240909',h.ehTrhS) END AS ofset,
         YEAR(h.ehTrhS) AS yil,
         CASE WHEN h.ehTip IN (100,4) THEN h.ehTutarN ELSE -h.ehTutarN END AS ciro,
         CASE WHEN h.ehTip IN (100,4) THEN ABS(h.ehAdetN) ELSE -ABS(h.ehAdetN) END AS adet
  FROM   DerinSISBkm.dbo.irsHrk h WITH(NOLOCK)
  JOIN   DerinSISBkm.bkm.UrunBilgi b WITH(NOLOCK) ON b.stkID = h.ehstkID
  WHERE  h.ehTip IN (100,101,4,5) AND h.ehMekan IN (1,4477,4478)
         AND b.KatAna NOT LIKE 'Sınav Okul%' AND h.ehTrhS >= '20240601'
)
SELECT yil,
       CONVERT(decimal(18,0), SUM(CASE WHEN ofset BETWEEN -29 AND -2 THEN ciro ELSE 0 END)) AS ciro_T29_T2,
       CONVERT(decimal(18,0), SUM(CASE WHEN ofset BETWEEN -29 AND -2 THEN adet ELSE 0 END)) AS adet_T29_T2,
       CONVERT(decimal(18,0), SUM(CASE WHEN ofset BETWEEN -1 AND 16 THEN ciro ELSE 0 END)) AS ciro_T1_T16,
       CONVERT(decimal(18,0), SUM(CASE WHEN ofset BETWEEN -1 AND 16 THEN adet ELSE 0 END)) AS adet_T1_T16
FROM   g WHERE yil IN (2025,2026) GROUP BY yil ORDER BY yil;
/* yıl   ciro T−29..T−2   adet T−29..T−2   ciro T−1..T+16   adet T−1..T+16
   2025    97.881.883        592.186        87.823.408        532.679
   2026   143.718.191        738.202         9.076.072         48.105
   ⇒ **k = ciro ×1,468 · adet ×1,247** (hizalı, T−29..T−2)
   ⇒ AÇILIŞ DALGASI 2026'DA HENÜZ GELMEMİŞ: T−1..T+16 penceresinde 2025'te
     87,8M ₺ varken 2026'da yalnız 9,1M (o pencerenin tek günü T−1 = 13.09.2026).
     Takvim kıyası bunu "talep kaybı" sanar — YANLIŞ. Eylül kalanı bu yüzden
     2025'in AYNI OFSETLERİ × k ile kapatıldı. */

/* ── 5) ★★★ BAYRAM ETKİSİ — HAM ORTALAMA YANILTIYOR ───────────────────────── */
-- Amaç: "bayram satışı artırır mı" sorusunu ÖLÇMEK (GMY isteği), varsaymamak.
WITH g AS (
  SELECT CAST(h.ehTrhS AS date) AS gun,
         SUM(CASE WHEN h.ehTip IN (100,4) THEN h.ehTutarN ELSE -h.ehTutarN END) AS ciro
  FROM   DerinSISBkm.dbo.irsHrk h WITH(NOLOCK)
  JOIN   DerinSISBkm.bkm.UrunBilgi b WITH(NOLOCK) ON b.stkID = h.ehstkID
  WHERE  h.ehTip IN (100,101,4,5) AND h.ehMekan IN (1,4477,4478)
         AND b.KatAna NOT LIKE 'Sınav Okul%' AND h.ehTrhS >= '20250101'
  GROUP BY CAST(h.ehTrhS AS date)
), e AS (
  SELECT gun, ciro,
    CASE WHEN gun BETWEEN '20250330' AND '20250401' THEN 'Ramazan25'
         WHEN gun BETWEEN '20250316' AND '20250329' THEN 'oncesi-Ramazan25'
         WHEN gun BETWEEN '20250606' AND '20250609' THEN 'Kurban25'
         WHEN gun BETWEEN '20250523' AND '20250605' THEN 'oncesi-Kurban25'
         WHEN gun BETWEEN '20260319' AND '20260322' THEN 'Ramazan26'
         WHEN gun BETWEEN '20260305' AND '20260318' THEN 'oncesi-Ramazan26'
         WHEN gun BETWEEN '20260526' AND '20260530' THEN 'Kurban26'
         WHEN gun BETWEEN '20260512' AND '20260525' THEN 'oncesi-Kurban26'
         ELSE NULL END AS pencere
  FROM g
)
SELECT pencere, COUNT(*) AS satirli_gun,
       CONVERT(decimal(18,0), AVG(ciro)) AS ham_gunluk_ort
FROM   e WHERE pencere IS NOT NULL GROUP BY pencere ORDER BY pencere;
/* ⚠⚠ HAM ÇIKTI YANILTICIDIR — `satirli_gun` sütunu neden olduğunu söylüyor:
     Ramazan25 penceresi 3 TAKVİM GÜNÜ ama yalnız 2 gün SATIR taşıyor;
     Kurban25 4 gün ama 3 satır; Kurban26 5 gün ama 4 satır.
     **Mağaza kapalı olduğu gün `irsHrk`'de SATIR YOKTUR ve AVG onu SAYMAZ.**
     ⇒ Doğru ölçü: pencere TOPLAMI ÷ TAKVİM GÜN SAYISI.

   bayram        ham AVG   TAKVİM GÜNÜ DÜZELTİLMİŞ
   Ramazan 2025   ×1,95          **×1,30**
   Ramazan 2026   ×1,54          **×1,15**
   Kurban  2025   ×1,18          **×0,89**
   Kurban  2026   ×1,06          **×0,85**

   ⇒ **RAMAZAN BAYRAMI SATIŞI ARTIRIYOR (+%15-30), KURBAN BAYRAMI DÜŞÜRÜYOR
     (−%11-15).** Ham ortalamaya bakılsaydı Kurban da "artırıcı" yazılacaktı —
     yön TERS çıkardı. ("Nüfus sıfırsa geçti değil bakamadım" sınıfı hata;
     `.claude/rules/olctum-mu-cikardim-mi.md`.)
   ⇒ Modelde kullanılan gün ağırlıkları: ramazan 1,22 · kurban 0,87 (iki yıl ort). */

/* ── 6) 2027 TAKVİMİ — web'den doğrulandı, hafızadan yazılmadı ─────────────── */
/* Ramazan Bayramı : 2026 → 19-22 Mart      · 2027 → 8-11 Mart   (AYNI AY)
   Kurban Bayramı  : 2026 → 26-30 Mayıs     · 2027 → 15-19 Mayıs (AYNI AY)
   ⇒ ⭐ 2027'DE AY SEVİYESİNDE BAYRAM KAYMASI YOK; gün sayıları da aynı ⇒ ay
     takvim çarpanı ≈ 1. Bu bir SONUÇTUR, ihmal değil — ölçülüp öyle bulundu.
   ⚠ 19 MAYIS 2027: Kurban'ın 4. günü ile Atatürk'ü Anma ÇAKIŞIYOR. 2026'da ayrı
     düşen iki tatil 2027'de üst üste biniyor ⇒ Mayıs'ta bir çalışma günü kazanılıyor.
   ⚠⚠ 2027-2028 OKUL AÇILIŞI MEB'CE HENÜZ AÇIKLANMADI → 13.09.2027 (pazartesi)
     VARSAYILDI. Bu **ÇIKARIMDIR, ÖLÇÜM DEĞİL**; takvim açıklanınca yeniden koşulmalı.
   Kaynak: cnnturk.com (2027 resmi tatiller) · isbank.com.tr (2026 resmi tatiller). */

/* ============================================================================
   MODELİN SONUCU (script çıktısı, 2026-09-13 koşumu — perakende, KDV hariç)
     2025 GERÇEK   :   630.967.949 ₺ / 4.862.626 adet
     2026 KAPANIŞ  :   950.067.814 ₺ / 6.296.194 adet  (×1,506)
       ⚠ bunun %59'u GERÇEKLEŞEN (556,3M ₺), **%41'i TAHMİN**
     2027 DÜŞÜK    : 1.306.374.322 ₺  (×1,375)
     2027 ORTA     : 1.414.240.092 ₺  (×1,489)
     2027 YÜKSEK   : 1.534.090.947 ₺  (×1,615)
   Şube (2027 orta): Özlüce 550,4M · İst.Yolu 484,9M · FSM 379,0M

   ⚠⚠ HACİM DUYARLILIĞI — ÜÇ SENARYONUN DIŞINDA, ASIL BELİRSİZLİK BURADA:
     hacim büyümesi yarıya inerse 1.253,2M · 2026'da SABİT kalırsa 1.092,2M
     ⇒ hacim durursa ciro, üç fiyat senaryosunun EN DÜŞÜĞÜNÜN de ALTINA iner.
   ============================================================================ */
