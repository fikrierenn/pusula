/* ============================================================================
   ALIŞ İSKONTOSU SIFIR OLAN ÜRÜNLER — ALIŞ FATURALARIYLA KONTROL   2026-09-12
   DB: DerinSISBkm + BKMDATA (profil: erp)

   Kullanıcı direktifi: "alış iskontosu sıfır olan ürünleri incele, bunları
   ayrıca alış faturalarından da kontrol et."

   ⚠⚠ SONUÇ ÖNCE: BU KONTROL, AYNI GÜN ATILAN İKİ COMMIT'İN (1b2580a, e22ef46)
   MARJ TABANINI ÇÜRÜTTÜ. `AlisIskonto` (marka vekili) VE faturadaki iskonto
   ORANI, ikisi de marj girdisi olarak GÜVENİLMEZ. Güvenilir olan tek şey
   FATURA BİRİM NET FİYATININ LİSTEYE ORANI — ve o ölçüldüğünde "sıfır iskonto"
   ürünleri listenin %55 altından alınıyor.
   ============================================================================ */

/* ── 0) VIEW'IN İÇİNDE İKİ KUSUR (tanım okundu) ─────────────────────────────── */
-- (a) `JOIN urnBrkd AS bar ON bar.urnBrkdStkID = u.stkID` — **`urnBrkdOnce=0` YOK**
--     ⇒ çok barkodlu üründe FAN-OUT. Ölçüldü: 323.367 satır / 323.223 tekil stkID
--     = 144 fazla satır. Küçük ama gerçek; `COUNT(*)` ürün sayısı DEĞİLDİR.
-- (b) `JOIN BKMDATA.ent.odak_marka` INNER'dır ⇒ `AlisIskonto = 0` "marka kaydı yok"
--     demek DEĞİL, "marka kaydı VAR ve discount alanı 0" demektir. Sıfır GERÇEK
--     bir sıfırdır — ama aşağıda görüleceği gibi EKONOMİK bir sıfır değildir.

/* ── 1) ★ VEKİL vs GERÇEK FATURA — vekilin nerede yalan söylediği ──────────── */
WITH fa AS (
  SELECT a.ehStkID AS stkID, SUM(a.ehTutar) AS brut, SUM(a.ehTutarN) AS net,
         SUM(a.ehAdetN) AS adet
  FROM   DerinSISBkm.dbo.fat f WITH(NOLOCK)
  JOIN   DerinSISBkm.dbo.fatAyr a WITH(NOLOCK) ON a.ehID = f.eID
  WHERE  f.eTip = 0 AND f.eTarih >= DATEADD(MONTH,-24,GETDATE()) AND a.ehTutar > 0
  GROUP BY a.ehStkID
)
SELECT CASE WHEN v.AlisIskonto = 0 THEN 'a) vekil = 0' WHEN v.AlisIskonto < 10 THEN 'b) 0-10'
            WHEN v.AlisIskonto < 30 THEN 'c) 10-30' WHEN v.AlisIskonto < 45 THEN 'd) 30-45'
            ELSE 'e) 45+' END AS vekil_bandi,
       COUNT(DISTINCT v.stkID) AS urun,
       COUNT(DISTINCT CASE WHEN fa.stkID IS NOT NULL THEN v.stkID END) AS faturasi_var,
       CONVERT(decimal(18,0), SUM(fa.brut)) AS alis_brut,
       CONVERT(decimal(10,1), 100.0*(1 - SUM(fa.net)/NULLIF(SUM(fa.brut),0))) AS FATURA_ISK,
       CONVERT(decimal(10,1), AVG(v.AlisIskonto)) AS vekil_isk
FROM   DerinSISBkm.bkm.OdaktaDatasiOlupMarjiSorunluUrunler v
LEFT JOIN fa ON fa.stkID = v.stkID
GROUP BY CASE WHEN v.AlisIskonto = 0 THEN 'a) vekil = 0' WHEN v.AlisIskonto < 10 THEN 'b) 0-10'
            WHEN v.AlisIskonto < 30 THEN 'c) 10-30' WHEN v.AlisIskonto < 45 THEN 'd) 30-45'
            ELSE 'e) 45+' END
ORDER BY vekil_bandi;
/* vekil bandı   ürün   faturası var   alış brüt      FATURA ISK   vekil
   a) = 0       2.355        1.766    37.757.126 ₺     %12,2       %0,0
   b) 0-10      8.397        5.281   140.474.269       %18,7       %1,1
   c) 10-30    29.599        8.858    46.924.145       %27,9      %25,9
   d) 30-45   170.470       92.805   874.451.281       %40,7      %39,5
   e) 45+     112.413       43.471   549.258.305       %50,5      %49,8

   ⭐ VEKİL %30 ÜSTÜNDE NEREDEYSE BİREBİR (39,5↔40,7 · 49,8↔50,5) — marka bazlı
     olmasına rağmen fatura gerçeğini iyi temsil ediyor.
   ⚠⚠ AMA TAM DA NEGATİF BANDI ÜRETEN YERDE YALAN SÖYLÜYOR: vekil 0 derken fatura
     %12,2 · vekil %1,1 derken fatura **%18,7** (17,6 puan sapma).
   ⇒ "Marj sorunlu" listesinin alt ucu, bir ÖLÇÜM KUSURU tarafından şişiriliyor. */

/* ── 2) ★★ SIFIR BANDININ AYRIŞTIRILMASI (2.355 ürün) ──────────────────────── */
-- (aynı `fa` CTE'si + irsHrk giriş (ehTip 0,10) + web cirosu ile)
/* durum                                         ürün   alış brüt     fatura isk  web ind.  web ciro
   a) fatura iskontosu <%5 (GERÇEKTEN SIFIRA YAKIN)  557  14.581.694 ₺    %0,6     %26,9    972.888 ₺
   b) fatura iskontosu >=%5 (VEKİL YANILIYOR)      1.209  23.175.433     %19,5     %23,1    826.211
   c) fatura YOK ama irsaliye girişi VAR               9         —          —       %5,6     29.671
   d) 24 ayda HİÇ GİRİŞ YOK (sitede hâlâ aktif)      580         —          —      %25,3    788.655
   ⇒ Sıfır bandının **yarısında vekil zaten yanlış**; dörtte biri 24 aydır hiç
     alınmamış (ölü ama satışa açık); yalnız 557'sinde faturada da iskonto yok.
   ⇒ WEB CİROSU HER DİLİMDE KÜÇÜK (<1M ₺) — sıfır bandı bir MATERYALİTE DEĞİL.
     Bir önceki commit'in 62,2M ₺'lik NEGATİF web cirosu buradan GELMİYOR. */

/* ── 3) MAĞAZA CİROSU — vekil × fatura çapraz tablosu ──────────────────────── */
/* vekil        fatura           ürün    mağaza cirosu   kasa ind.  fatura isk.
   = 0          <%5               557      7.676.221 ₺     %21,1      %0,6
   = 0          >=%5            1.209     11.583.409       %10,4     %19,5
   = 0          faturasız         589        935.873       %30,0        —
   0-10         <%5               973     10.517.218       %19,3      %1,1
   0-10         >=%5            4.308     54.175.522       %14,4     %21,1
   0-10         faturasız       3.116      6.376.662       %23,0        —
   10-30        >=%5            8.804     12.444.535        %3,8     %28,9
   30+          >=%5          135.655    367.387.801       %24,6     %44,5   ← ana kütle, SAĞLIKLI
   30+          faturasız     146.607        804.435       %20,7        —
   ⇒ **146.607 ürün 24 ayda hiç alış faturası görmemiş ama katalogda** — mağaza
     cirosu yalnız 0,8M ₺. Bunlar büyük olasılıkla ODAK sevkiyatlı/konsinye
     (`urnBilgi` 168 "Odak Stoğunu Sat" 93.180 · 224 "Odak Sevkiyat Ürün" 26.993).
     Bu ürünlerde ALIŞ FATURASI ÜZERİNDEN MARJ ÖLÇÜLEMEZ — ayrı bir yol gerekir. */

/* ── 4) SIFIR BANDININ MARKALARI ───────────────────────────────────────────── */
/* marka (≥20 ürün)      ürün  faturası var  alış brüt    fatura isk.  web ind.
   Scrikss                445      381       4.305.129 ₺    %8,7       %25,5
   Başka Defter           307      183       2.321.659      %8,4       %29,2
   Stabilo                148      121       3.236.823     %12,4       %17,3
   Staedtler               89        1             299      %1,0       %41,4  ← ölçülemez
   **Yıldız Defter**       88       78       1.515.310      %0,0       %37,3
   OMT                     71       68       4.156.910      %5,1       %20,8
   Dong-A                  70       63         572.603     %24,1       %43,3
   **The Edd**             53       23         809.755      %0,0       %25,2
   **Penna**               50       42       2.167.139      %0,3       %18,2
   Stanley                 42       42         928.067     %40,0       %10,0  ← vekil TAMAMEN yanlış
   **Penmark**             25       16       1.260.575      %0,3       %40,9
   **Eastpak**             38       19         262.290      %1,4       %39,9
   ⇒ Kalın olanlar ilk bakışta "sıfır iskontoyla alıp yüksek indirimle satıyoruz"
     görünüyor. Blok 6 bunun DOĞRU OLMADIĞINI gösteriyor. */

/* ── 5) ★★★ KESİN TEST — "iskonto faturada gösterilmiyor" HİPOTEZİ ─────────── */
-- "Başka ne olabilir?" kapısı: faturada iskonto satırı olmaması, malın PAHALI
-- alındığı anlamına gelmez; tedarikçi NET fiyat kesiyor olabilir. Ayırt etmek
-- için fatura BİRİM NET FİYATI, LİSTE fiyatıyla karşılaştırılır (KDV eşitlenerek).
-- ⚠ `urn.fiyatS` KDV DAHİL, `fatAyr.ehTutarN` KDV HARİÇ ⇒ liste KDV'den arındırılır.
-- ⚠ Oran `urnKDV` JOIN'iyle alınır, ELLE YAZILMAZ (sql-server-conventions § KDV).
WITH fa AS (
  SELECT a.ehStkID AS stkID, SUM(a.ehTutar) AS brut, SUM(a.ehTutarN) AS net,
         SUM(a.ehAdetN) AS adet
  FROM   DerinSISBkm.dbo.fat f WITH(NOLOCK)
  JOIN   DerinSISBkm.dbo.fatAyr a WITH(NOLOCK) ON a.ehID = f.eID
  WHERE  f.eTip = 0 AND f.eTarih >= DATEADD(MONTH,-24,GETDATE())
         AND a.ehTutar > 0 AND a.ehAdetN > 0
  GROUP BY a.ehStkID
)
SELECT CASE WHEN 100.0*(1-fa.net/fa.brut) < 5  THEN 'a) faturada iskonto YOK (<%5)'
            WHEN 100.0*(1-fa.net/fa.brut) < 30 THEN 'b) faturada %5-30'
            ELSE 'c) faturada %30+' END AS fatura_bandi,
       COUNT(DISTINCT v.stkID) AS urun,
       CONVERT(decimal(18,0), SUM(fa.net)) AS alis_net,
       CONVERT(decimal(10,1),
         100.0*(1 - SUM(fa.net)/SUM(fa.adet*u.fiyatS/(1+k.kdvYuzde/100.0)))) AS ALIS_LISTEDEN_SAPMA,
       CONVERT(decimal(10,1), AVG(v.SatisMarji))  AS web_ind,
       CONVERT(decimal(10,1), AVG(v.AlisIskonto)) AS vekil_isk
FROM   DerinSISBkm.bkm.OdaktaDatasiOlupMarjiSorunluUrunler v
JOIN   fa ON fa.stkID = v.stkID
JOIN   DerinSISBkm.dbo.urn u WITH(NOLOCK) ON u.stkID = v.stkID
JOIN   DerinSISBkm.dbo.urnKDV k ON k.kdvID = u.KDVs
WHERE  u.fiyatS > 0 AND v.Marka NOT LIKE 'BKM%'
GROUP BY CASE WHEN 100.0*(1-fa.net/fa.brut) < 5  THEN 'a) faturada iskonto YOK (<%5)'
            WHEN 100.0*(1-fa.net/fa.brut) < 30 THEN 'b) faturada %5-30'
            ELSE 'c) faturada %30+' END
ORDER BY fatura_bandi;
/* fatura bandı                 ürün    alış net       **ALIŞ LİSTEDEN SAPMA**  web ind.  vekil
   a) faturada iskonto YOK    2.117   32.223.188 ₺          **%55,0**           %21,8    %14,1
   b) faturada %5-30         13.710  132.123.731            **%53,9**           %17,5    %17,9
   c) faturada %30+         136.229  802.344.280            **%59,5**           %31,0    %43,1

   ★★★ **HİPOTEZ DOĞRULANDI — İSKONTO FATURADA GÖSTERİLMİYOR, FİYAT NET GELİYOR.**
     Faturasında hiç iskonto satırı olmayan ürünler yine de listenin **%55,0**
     altından alınıyor; "sağlıklı" sayılan %30+ bandı %59,5. Fark yalnız 4,5 puan.
   ⇒ `AlisIskonto` (marka vekili) VE faturadaki iskonto ORANI — İKİSİ DE marj
     girdisi olarak GÜVENİLMEZ. İkisi de bir SUNUM tercihini ölçüyor, ekonomiyi değil.
   ⇒ Güvenilir taban: **fatura birim net fiyatı ÷ (liste ÷ (1+KDV))**.
   ⭐ Özel marka elendi (alternatif açıklama): `Marka LIKE 'BKM%'` yalnız 84 ürün /
     4,2M ₺ alış — kütleyi açıklamıyor, bu yüzden dışarıda bırakıldı. */

/* ── 6) ★★★ MARJIN DOĞRU TABANLA YENİDEN ÖLÇÜMÜ — GERİ ALMA ────────────────── */
-- GERCEK_MARJ = ALIS_LISTEDEN_SAPMA − SatisMarji  (iki taraf da "listeden sapma",
-- aynı taban ⇒ kapsam eşleşmesi sağlandı)
WITH fa AS (
  SELECT a.ehStkID AS stkID, SUM(a.ehTutarN) AS net, SUM(a.ehAdetN) AS adet
  FROM   DerinSISBkm.dbo.fat f WITH(NOLOCK)
  JOIN   DerinSISBkm.dbo.fatAyr a WITH(NOLOCK) ON a.ehID = f.eID
  WHERE  f.eTip = 0 AND f.eTarih >= DATEADD(MONTH,-24,GETDATE())
         AND a.ehTutar > 0 AND a.ehAdetN > 0
  GROUP BY a.ehStkID
)
SELECT CASE WHEN v.MarjFarki < 0 THEN 'a) VEKILE gore NEGATIF'
            WHEN v.MarjFarki < 11 THEN 'b) esik alti' ELSE 'c) esik ustu' END AS vekil_bandi,
       COUNT(*) AS urun,
       CONVERT(decimal(10,1), AVG(100.0*(1 - fa.net/(fa.adet*u.fiyatS/(1+k.kdvYuzde/100.0))))) AS ALIS_SAPMA,
       CONVERT(decimal(10,1), AVG(v.SatisMarji)) AS web_ind,
       CONVERT(decimal(10,1), AVG(100.0*(1 - fa.net/(fa.adet*u.fiyatS/(1+k.kdvYuzde/100.0))) - v.SatisMarji)) AS GERCEK_MARJ,
       SUM(CASE WHEN 100.0*(1 - fa.net/(fa.adet*u.fiyatS/(1+k.kdvYuzde/100.0))) - v.SatisMarji < 0
                THEN 1 ELSE 0 END) AS gercekten_negatif
FROM   DerinSISBkm.bkm.OdaktaDatasiOlupMarjiSorunluUrunler v
JOIN   fa ON fa.stkID = v.stkID
JOIN   DerinSISBkm.dbo.urn u WITH(NOLOCK) ON u.stkID = v.stkID
JOIN   DerinSISBkm.dbo.urnKDV k ON k.kdvID = u.KDVs
WHERE  u.fiyatS > 0
GROUP BY CASE WHEN v.MarjFarki < 0 THEN 'a) VEKILE gore NEGATIF'
            WHEN v.MarjFarki < 11 THEN 'b) esik alti' ELSE 'c) esik ustu' END
ORDER BY vekil_bandi;
/* vekil bandı        ürün   ALIŞ SAPMA  web ind.  **GERÇEK MARJ**  gerçekten negatif
   a) vekile NEGATİF 10.556    %53,0      %35,5      **+17,5**       2.016 (%19)
   b) eşik altı      33.303    %56,3      %36,7      **+19,5**          59
   c) eşik üstü     108.420    %57,9      %26,9      **+31,0**         123

   ★★★ **GERİ ALMA:** "NEGATİF" bandın gerçek marjı −19,7 DEĞİL **+17,5 puan**.
     O bandın %81'i (8.540 ürün) doğru tabanla PARA KAZANDIRIYOR. */

/* ── 7) GERÇEK BANTLARIN BÜYÜKLÜĞÜ (web cirosu) ────────────────────────────── */
/* gerçek bant           ürün    ort gerçek marj   web'de satan   WEB CİROSU
   a) GERÇEKTEN NEGATİF  2.190       −12,2            1.606        31.044.772 ₺
   b) gerçek eşik altı  10.030        +6,1            8.297       160.790.325
   c) gerçek eşik üstü 139.951       +29,7           97.962       508.626.076

   ★ ÖNCE / SONRA — bu dosyanın çürüttüğü rakamlar:
     "eşiğin altındaki ürün"      57.083  →  **12.220**
     "gerçekten negatif ürün"     15.457  →   **2.190**
     "negatifin web cirosu"     62,2M ₺  →  **31,0M ₺**
     "web cirosunun eşik altı payı" %51  →   **%27,4** (191,8M / 700,5M ₺)
   ⚠ Kapsam farkı bilinçli: bu tablo YALNIZ son 24 ayda alış faturası GÖRMÜŞ
     152.171 ürünü içerir. Faturasız 146.607 ürün için marj ÖLÇÜLEMEDİ —
     "sıfır" değil, "bakamadım". */

/* ── 8) DEĞİŞMEZ — fatura net kimliği ──────────────────────────────────────── */
-- `alis-fatura-net-kimligi`: eTip=0'da ehTutarN = ehTutar − ehIndirim (son 12 ay).
-- Ölçüldü: 641.905 satırın 641.904'ü tutuyor; tek istisna ehID 7029330 satır 1
-- (4.500 → net 2.700, ehIndirim 0 — elle girilmiş, indirim kolonuna yazılmamış).
-- Kademe kimliği de tutuyor: ehTutarN = ehTutar × Π(1−ehi_i/100), 186 istisna.
-- KIRILABİLİRLİK: doğru formül 1 (le 5) · yalnız `ehi1` kademesi sanılırsa 6.799 ·
--   eTip=4'te 55.879 (sema'nın zaten bildiği bozuk taraf — kapı onu da görüyor).

/* ============================================================================
   SINIRLAR (beyan)
   · Alış penceresi 24 ay, satış penceresi 12 ay — TABANLAR FARKLI. Fiyat artışı
     olan üründe alış listeden sapması OLDUĞUNDAN BÜYÜK görünür (`fiyatS` anlık).
   · `fat.eTip=0` yalnız ALIŞ FATURASIDIR. `irsHrk.ehTip=10` (Yerel Alım) faturaya
     dönmemiş girişleri içerir; `fat.eTip=10` ise İADE FARK FATURASIDIR, alış DEĞİL
     (iki sözlük ayrıdır — sql-server-conventions § DerinSIS Adet İşareti).
   · 146.607 ürünün 24 ayda alış faturası YOK (ODAK sevkiyat/konsinye şüphesi) —
     bu ürünlerde fatura tabanlı marj ÖLÇÜLEMEZ, "ölçemedim" demektir, "sıfır" değil.
   · Kargo · kampanya · ödeme komisyonu · iade hâlâ hesap dışı ⇒ tablo İYİMSER.
   · stkID 1623731 "Sevimli Hayvanlar Kum Boyama"da `SatisMarji = −900` — site
     fiyatı listenin 10 katı. View'da aykırı değer süzgeci YOK; ortalamalara girer.
   ============================================================================ */
