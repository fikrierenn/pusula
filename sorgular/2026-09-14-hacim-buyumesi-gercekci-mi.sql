/* ============================================================================
   HACİM BÜYÜMESİ GERÇEKÇİ Mİ — TAHMİNİN EN BÜYÜK VARSAYIMI SINANDI  2026-09-14
   DB: DerinSISBkm + EncoreMerkez (profil: erp)

   GMY: "hacim büyümesi gerçekçi mi, onu da ölç".
   Bağlam: 2027 tahmini adedin +%26 büyüyeceğini varsayıyor ve ÜÇ FİYAT SENARYOSU
   bu riski KAPSAMIYOR (raporun kendi uyarısı). Bu dosya o varsayımı sınar.

   ⚠ İLK ŞÜPHE — KAYIT ARTEFAKTI: sema'da `pos_sistem_gecisi_2025` yapısal kırılma
   olarak kayıtlı ve aynı sınıf bir SAHTE BÜYÜME daha önce yakalanmıştı (kartlı
   müşteri payı Ağu-2025 %0,3-1,4 → Ağu-2026 %77,4-81,9; bu müşteri artışı DEĞİL,
   kart yakalamanın devreye girmesiydi — B-163). Adet artışı da öyle olabilir mi?
   ============================================================================ */

/* ── 1) ★ BÜYÜME NEREDEN GELİYOR — KATEGORİ AYRIŞTIRMASI (Oca-Ağu, perakende) ── */
SELECT b.Kategori3 AS kategori,
       SUM(CASE WHEN YEAR(h.ehTrhS)=2025 THEN (CASE WHEN h.ehTip IN (100,4) THEN ABS(h.ehAdetN) ELSE -ABS(h.ehAdetN) END) ELSE 0 END) AS adet25,
       SUM(CASE WHEN YEAR(h.ehTrhS)=2026 THEN (CASE WHEN h.ehTip IN (100,4) THEN ABS(h.ehAdetN) ELSE -ABS(h.ehAdetN) END) ELSE 0 END) AS adet26
FROM   DerinSISBkm.dbo.irsHrk h WITH(NOLOCK)
JOIN   DerinSISBkm.bkm.UrunBilgi b WITH(NOLOCK) ON b.stkID = h.ehstkID
WHERE  h.ehTip IN (100,101,4,5) AND h.ehMekan IN (1,4477,4478)
       AND b.KatAna NOT LIKE 'Sınav Okul%'
       AND MONTH(h.ehTrhS) <= 8 AND YEAR(h.ehTrhS) IN (2025,2026)
GROUP BY b.Kategori3 ORDER BY adet26 DESC;
/* kategori            adet25      adet26   adet%   brm25  brm26  fiyat%
   Kırtasiye        1.082.490   1.321.634   +22%     62     69    +12%
   Çocuk Kitabı       360.769     446.247   +24%    127    162    +28%
   Kitap              305.726     353.603   **+16%** 205   263    +28%
   Oyuncak            207.613     300.488   +45%    205    235    +15%
   **Hediyelik**      147.359     296.985  **+102%**  40     46    +16%
   Hazırlık Kit.      221.031     267.924   +21%    253    303    +20%
   Gıda               117.816     140.027   +19%     33     40    +23%
   **Akademi**         30.908      78.346  **+153%** 259   281     +9%
   **Kişisel Bakım**   19.737      46.032  **+133%**  53     35   **−33%**
   Elektronik          21.774      24.075   +11%    129    161    +25%
   Dergi               12.776      13.578    +6%     89    127    +43%
   TOPLAM           2.535.614   3.372.583  **+33%**  121    139    +15%

   ⚠ BÜYÜME HOMOJEN DEĞİL: üç haneli artışlar KÜÇÜK TABANLI kategorilerde
     (Akademi 31K, Kişisel Bakım 20K, Hediyelik 147K). Çekirdek kategoriler çok
     daha ölçülü: Kitap +%16, Hazırlık +%21, Kırtasiye +%22.
   ⇒ Manşet +%33, küçük tabanların patlamasıyla ŞİŞİYOR. Küçük taban üç haneli
     büyümeyi sürdüremez; model bunu 1,60 kırpmasıyla zaten sınırlıyor. */

/* ── 2) ★ ŞUBE VE ÇEŞİT — tek bir yerin işi mi, çeşit genişlemesi mi ────────── */
SELECT h.ehMekan AS mekan, YEAR(h.ehTrhS) AS yil,
       SUM(CASE WHEN h.ehTip IN (100,4) THEN ABS(h.ehAdetN) ELSE -ABS(h.ehAdetN) END) AS adet,
       COUNT(DISTINCT h.ehstkID) AS cesit
FROM   DerinSISBkm.dbo.irsHrk h WITH(NOLOCK)
JOIN   DerinSISBkm.bkm.UrunBilgi b WITH(NOLOCK) ON b.stkID = h.ehstkID
WHERE  h.ehTip IN (100,101,4,5) AND h.ehMekan IN (1,4477,4478)
       AND b.KatAna NOT LIKE 'Sınav Okul%'
       AND MONTH(h.ehTrhS) <= 8 AND YEAR(h.ehTrhS) BETWEEN 2023 AND 2026
GROUP BY h.ehMekan, YEAR(h.ehTrhS) ORDER BY mekan, yil;
/* şube      2023      2024      2025      2026    24/23 25/24 26/25  çeşit25 çeşit26
   FSM      673.032   649.901   750.702   983.414   −3%  +16%  +31%   68.319  74.260
   Özlüce   788.558   907.432 1.087.071 1.380.178  +15%  +20%  +27%   82.931  87.904
   İst.Yolu 383.027   532.480   697.841 1.008.991  +39%  +31%  +45%   64.895  73.281
   ⇒ ÜÇ ŞUBEDE DE VAR — tek mağazanın işi DEĞİL, yani kayıt/yerel bir olay değil.
   ⇒ ÇEŞİT yalnız +%6-13 arttı ⇒ büyüme ÜRÜN BAŞINA SATIŞ artışından geliyor,
     ürün yelpazesi genişlemesinden DEĞİL. Bu gerçek talep lehine bir işarettir. */

/* ── 3) ⚠ FİŞ SAYISI İLE DOĞRULANAMIYOR — POS GEÇİŞİ BOŞLUĞU ──────────────── */
SELECT YEAR(s.Date) AS yil, MONTH(s.Date) AS ay, COUNT(DISTINCT s.Id) AS fis,
       CONVERT(decimal(10,2), SUM(sp.Amount)*1.0/COUNT(DISTINCT s.Id)) AS sepet_adedi
FROM   EncoreMerkez.dbo.Sales s WITH(NOLOCK)
JOIN   EncoreMerkez.dbo.SalesProducts sp WITH(NOLOCK) ON sp.SalesId = s.Id
WHERE  s.DocumentsTypeId = 1 AND sp.IsValid = 1
       AND s.Date >= '20250101' AND s.Date < '20260901'
GROUP BY YEAR(s.Date), MONTH(s.Date) ORDER BY yil, ay;
/* ⚠⚠ EncoreMerkez'de **Oca-Haz 2025 HİÇ YOK**, Tem-2025 EKSİK (22.602 fiş vs
     2026'nın 75.447'si). POS geçişi yılın ortasında ⇒ 2026'nın ilk yarısı fiş
     sayısıyla DOĞRULANAMIYOR. Bu bir VERİ SINIRI, "büyüme yok" demek DEĞİL.
   ⭐ TEK TEMİZ KIYAS AĞUSTOS (iki yıl da tam): **fiş +%17 · sepet adedi −%1**
     ⇒ artış SEPETTEN değil MÜŞTERİ SAYISINDAN geliyor. Sepet sabit kalmış. */

/* ── 4) ★★★ HACİM MARJLA MI SATIN ALINDI — KESİN TEST ─────────────────────── */
-- Şüphe: fiyatı kırıp hacim almış olabiliriz. O zaman marj ERİMELİ.
-- Her yıl için, o yılın satış adedi × O YILIN alış birim fiyatı (aynı-yıl eşleme).
WITH sat AS (
  SELECT YEAR(h.ehTrhS) AS yil, h.ehstkID AS stkID,
         SUM(CASE WHEN h.ehTip IN (100,4) THEN ABS(h.ehAdetN) ELSE -ABS(h.ehAdetN) END) AS adet,
         SUM(CASE WHEN h.ehTip IN (100,4) THEN h.ehTutarN ELSE -h.ehTutarN END) AS ciro
  FROM   DerinSISBkm.dbo.irsHrk h WITH(NOLOCK)
  JOIN   DerinSISBkm.bkm.UrunBilgi b WITH(NOLOCK) ON b.stkID = h.ehstkID
  WHERE  h.ehTip IN (100,101,4,5) AND h.ehMekan IN (1,4477,4478)
         AND b.KatAna NOT LIKE 'Sınav Okul%' AND MONTH(h.ehTrhS) <= 8
         AND YEAR(h.ehTrhS) BETWEEN 2024 AND 2026
  GROUP BY YEAR(h.ehTrhS), h.ehstkID
), al AS (
  SELECT YEAR(f.eTarih) AS yil, a.ehStkID AS stkID,
         SUM(a.ehTutarN)/NULLIF(SUM(a.ehAdetN),0) AS birim
  FROM   DerinSISBkm.dbo.fat f WITH(NOLOCK)
  JOIN   DerinSISBkm.dbo.fatAyr a WITH(NOLOCK) ON a.ehID = f.eID
  WHERE  f.eTip = 0 AND f.eTarih >= '20240101' AND f.eTarih < '20260901'
         AND a.ehTutar > 0 AND a.ehAdetN > 0
  GROUP BY YEAR(f.eTarih), a.ehStkID
)
SELECT sat.yil, COUNT(*) AS urun,
       CONVERT(decimal(18,0), SUM(sat.ciro)) AS CIRO,
       CONVERT(decimal(18,0), SUM(sat.adet*al.birim)) AS SMM,
       CONVERT(decimal(10,1), 100.0*(SUM(sat.ciro)-SUM(sat.adet*al.birim))
                              / NULLIF(SUM(sat.ciro),0)) AS MARJ
FROM   sat JOIN al ON al.stkID = sat.stkID AND al.yil = sat.yil
WHERE  sat.adet > 0 AND sat.ciro > 0
GROUP BY sat.yil ORDER BY sat.yil;
/* yıl    ürün      CİRO ₺        SMM ₺       MARJ
   2024  89.702  169.456.123  119.770.328   %29,3
   2025  84.710  272.732.438  189.338.057   %30,6
   2026  81.128  398.590.624  277.139.016   **%30,5**
   ⭐ MARJ SABİT ⇒ **HACİM MARJLA SATIN ALINMADI.** Bu, büyümenin gerçekliği
     lehine en güçlü iç kanıttır.
   ⚠⚠ YAN BULGU — ÖNCEKİ ÖLÇÜMÜN İYİMSERLİĞİ ARTIK SAYISAL: 2026-09-13'te
     24 AYLIK alış penceresiyle perakende marjı **%37,3** ölçülmüş ve "pencere
     uyuşmazlığı SMM'yi düşük gösterir, marj İYİMSERDİR" diye BEYAN EDİLMİŞTİ.
     Aynı-yıl eşlemeyle **%30,5** çıkıyor ⇒ beyan edilen iyimserlik **6,8 PUAN**.
     (Kapsam farkı da var: orada 12 ay/24 ay, burada Oca-Ağu/aynı yıl.) */

/* ── 5) ALIŞ FİYATI vs SATIŞ FİYATI vs ENFLASYON ──────────────────────────── */
SELECT YEAR(f.eTarih) AS yil,
       CONVERT(decimal(18,2), SUM(a.ehTutarN)/NULLIF(SUM(a.ehAdetN),0)) AS birim_alis
FROM   DerinSISBkm.dbo.fat f WITH(NOLOCK)
JOIN   DerinSISBkm.dbo.fatAyr a WITH(NOLOCK) ON a.ehID = f.eID
WHERE  f.eTip = 0 AND f.eTarih >= '20230101' AND f.eTarih < '20260901'
       AND MONTH(f.eTarih) <= 8 AND a.ehTutar > 0 AND a.ehAdetN > 0
GROUP BY YEAR(f.eTarih) ORDER BY yil;
/* yıl   birim alış   artış    birim satış (perakende)   artış
   2023     54,86       —              —                   —
   2024     70,64    +%28,8            —                   —
   2025     76,09     +%7,7           121 ₺                —
   2026     99,99   **+%31,4**        139 ₺            **+%15,0**
   ⚠ Alış +%31,4, satış +%15,0 — 16 puan fark. AMA blok 4 marjın SABİT olduğunu
     gösteriyor ⇒ fark KARMA etkisidir (aldığımız sepet ile sattığımız sepet aynı
     değil), marj erimesi DEĞİL.
   ⭐ DIŞ ÇIPA (TÜİK, Ağu-2026 yıllık): TÜFE **%31,51** · **Temel Mallar %15,89** ·
     Hizmetler %40,28. Kitap/kırtasiye TEMEL MALDIR ⇒ bizim **+%15,0**'imiz mal
     enflasyonuyla neredeyse BİREBİR. ⇒ **Gerçek (reel) fiyatımız DÜŞMEDİ**;
     yani hacim, fiyat kırarak satın alınmış DEĞİL. Blok 4'ü bağımsız destekler.
   ⚠ Manşet TÜFE ile kıyas YANILTIR (%31,5): hizmet enflasyonu bizim sepetimizde yok. */

/* ── 6) KAPASİTE — fiziksel sınır var mı ──────────────────────────────────── */
WITH g AS (
  SELECT st.Name AS magaza, CAST(s.Date AS date) AS gun, COUNT(DISTINCT s.Id) AS fis
  FROM   EncoreMerkez.dbo.Sales s WITH(NOLOCK)
  JOIN   EncoreMerkez.dbo.Stores st WITH(NOLOCK) ON st.Id = s.StoresId
  WHERE  s.DocumentsTypeId = 1 AND s.Date >= '20250901' AND s.Date < '20260913'
  GROUP BY st.Name, CAST(s.Date AS date)
)
SELECT magaza, COUNT(*) AS gun_sayisi,
       CONVERT(decimal(10,0), AVG(fis*1.0)) AS ort_gunluk_fis,
       MAX(fis) AS zirve_gun_fis,
       CONVERT(decimal(10,2), MAX(fis)*1.0/AVG(fis*1.0)) AS zirve_ort_kat
FROM   g GROUP BY magaza ORDER BY magaza;
/* mağaza      gün   ort günlük fiş   zirve gün   zirve/ort
   FSM         375       1.068          2.206       2,07
   İst.Yolu    375         797          1.933       2,42
   Özlüce      375       1.241          2.389       1,92
   ⇒ 2027 tahmini adet +%26,2 ⇒ ortalama gün FSM ~1.346 · Özlüce ~1.564 ·
     İst.Yolu ~1.004 fişe çıkar; ZİRVE GÜN Özlüce'de ~3.000 fişe.
   ⚠ Bu, BUGÜNE DEK GÖRÜLEN EN YOĞUN GÜNÜN (2.389) **%26 ÜSTÜ**. ~13 saatlik
     günde 231 fiş/saat ≈ dakikada 4 fiş — mümkün ama SIKIŞIK. Kasa/personel
     planlaması yapılmazsa bu zirve FİZİKSEL OLARAK karşılanamayabilir.
   ⚠ Bu bir kapasite MODELİ değil, bir BÜYÜKLÜK KONTROLÜDÜR. */

/* ============================================================================
   HÜKÜM
   LEHTE (büyüme gerçek): üç şubede de var (+%31/+%27/+%45) · çeşit yalnız +%6-13
     ⇒ ürün başına satış artıyor · MARJ SABİT (%29,3→%30,6→%30,5) ⇒ indirimle
     alınmamış · fiyatımız temel mal enflasyonuyla aynı (+%15,0 vs %15,89) ⇒ reel
     fiyat kırılmamış · Ağustos'ta fiş +%17, sepet sabit ⇒ MÜŞTERİ artıyor.
   ALEYHTE (+%26 fazla iyimser olabilir): büyüme HIZLANIYOR (+%13,3 → +%21,3 →
     +%33,0) ve hızlanma ekstrapole etmek klasik tahmin hatasıdır · 3 YILLIK CAGR
     **+%22,3**, model +%26,2 kullanıyor ⇒ uzun trendin ÜSTÜNDE · üç haneli
     büyüyenler küçük tabanlı · zirve gün bugüne dek görülenin %26 üstüne çıkıyor ·
     2026 tabanının **%41'i zaten TAHMİN**.
   ⇒ **+%26,2 SAVUNULABİLİR AMA İYİMSER UÇTA.** 3 yıllık CAGR'a (+%22,3) çekilirse
     2027 orta ciro 1.434,1M → **~1.389,8M ₺** (−%3,1).
   ⚠ ÖLÇÜLEMEYEN: 2026'nın ilk yarısı fiş sayısıyla doğrulanamadı (POS boşluğu).
     "Müşteri mi sepet mi" sorusunun tam yıl cevabı YOK — yalnız Ağustos var.
   ============================================================================ */
