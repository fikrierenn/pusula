/* ============================================================================
   "REYON" = KAMPANYA ETİKETİ · MAĞAZA DA İNDİRİMLİ SATIYOR        2026-09-12
   DB: DerinSISBkm (profil: erp)

   Çıkış noktası — KULLANICI DÜZELTMESİ (ekran görüntüsüyle birlikte):
     "mağazada kampanyalı satıyor 3 al 2 öde veya kampanyalı fiyatlar var,
      ürün kartında reyon tanımından oluyor sanırım"

   ⚠ Bu, bir önceki commit'teki (1b2580a) şu cümleyi ÇÜRÜTÜR:
     "Bulgu WEB'E ÖZGÜDÜR; aynı ürünün MAĞAZA marjı daha iyidir."
   Mağaza marjı GENELDE daha iyi ama NEGATİF bantta MAĞAZA DA ZARARDA.
   ============================================================================ */

/* ── 1) ★ "REYON" ALANI NEREDE — form sırası ile kanıt ──────────────────────── */
-- DerinSIS "Ürün Düzenleme > Ürün Özellikleri" sağ sütunu, yukarıdan aşağı:
--   Web → urn.kod1ID (dbo.urnKod1: Aktif/Pasif/Tükendi)
--   Satınalma → urn.kod2ID (dbo.urnkod2: alıcı adları — "Aydın KULAKSIZOĞLU")
--   Öneri Olanlar → urn.kod3ID (dbo.urnkod3: Öneri Var / Öneri Yok / Ön Sipariş)
--   **Reyon → urn.kod4ID (dbo.urnkod4)**   ← BU
-- Sıra birebir tuttuğu için eşleme ÖLÇÜLDÜ sayılır, tahmin değil.
SELECT k.kod4ID, k.kod4Ad, COUNT(u.stkID) AS urun
FROM   DerinSISBkm.dbo.urnkod4 k
LEFT JOIN DerinSISBkm.dbo.urn u WITH(NOLOCK) ON u.kod4ID = k.kod4ID
GROUP BY k.kod4ID, k.kod4Ad ORDER BY urun DESC;
/* 46 tanım · 838.301 ürün · **öksüz kod4ID = 0**
   3 AL 2 ÖDE 427.291 · Kampanya Dışı 286.098 · Tanımsız 81.921 ·
   %50 INDIRIM 16.687 · %30 16.873? (6.873) · %25 4.598 · Sahaf A Kalite 4.174 ·
   %20 3.181 · İNDİRİMSİZ 2.047 · "99.00 TL ÖZEL FİYAT" 1.056 · …

   ⚠⚠ **AD TUZAĞI:** kartta "Reyon" yazıyor ama içerik REYON DEĞİL, KAMPANYA.
     Gerçek reyon/planogram AYRI bir şemadadır: `ryn.reyon` (576) · `ryn.raf`
     (23.327) · `ryn.rafUrun` (476.923) · `ryn.alan` (40) · `ryn.kat` (16).
     İkisi birbirine KARIŞTIRILMAMALI — "reyon bazlı ciro" isteyen biri
     `urn.kod4ID`'yi kullanırsa kampanya kırılımı alır, raf kırılımı DEĞİL. */

/* ── 2) ★★ ETİKET KASADA GERÇEKLEŞİYOR MU (kendi kendini doğrulama) ────────── */
SELECT k.kod4Ad, COUNT(DISTINCT u.stkID) AS urun,
       CONVERT(decimal(18,0), SUM(p.satTutar)) AS magaza_ciro_kdvli,
       CONVERT(decimal(10,1), 100.0*SUM(p.satIndirim)/NULLIF(SUM(p.satTutar+p.satIndirim),0)) AS KASA_IND
FROM   DerinSISBkm.dbo.urn u WITH(NOLOCK)
JOIN   DerinSISBkm.dbo.urnkod4 k ON k.kod4ID = u.kod4ID
JOIN   DerinSISBkm.dbo.posOzetUrun p WITH(NOLOCK) ON p.posStkID = u.stkID
WHERE  p.posTarih >= DATEADD(MONTH,-12,GETDATE()) AND p.posMekan IN (1,4477,4478)
       AND p.satAdet > 0
GROUP BY k.kod4Ad ORDER BY KASA_IND;
/* ⭐ ETİKET FİİLİ İNDİRİMİ ÖNGÖRÜYOR — alan ölü bir sınıflandırma değil, ÇALIŞIYOR:
     İNDİRİMSİZ      284 ürün ·  17,1M ₺ · kasa indirimi  %1,1
     Kampanya Dışı 45.392     · 627,7M ₺ ·                %3,4
     %20 INDIRIM    1.569     ·  11,9M ₺ ·                %7,2   ← etiketin ALTINDA
     %25 INDIRIM    1.442     ·   8,7M ₺ ·               %13,8   ← etiketin ALTINDA
     3 AL 2 ÖDE    88.264     · 340,6M ₺ ·               %23,9   (teorik tavan %33,3)
     %30 INDIRIM    2.390     ·  12,0M ₺ ·               %25,8
     %50 INDIRIM    6.801     ·  31,6M ₺ ·               %48,1   ← neredeyse tam
   ⇒ Sıralama MONOTON. %20/%25 etiketlerinin altında kalması beklenir: etiket
     kampanya ÜYELİĞİDİR, her satışta tetiklendiği anlamına gelmez (3 AL 2 ÖDE
     yalnız 3 adet alındığında; yüzde indirimler dönemsel).
   ⇒ `satIndirim` KASA indirimi; `satTutar` indirim UYGULANMIŞ tutardır (KDV dahil).
     `satTutar`dan `satIndirim` ÇIKARILMAZ — bkz. sql-server-conventions § POS ÖZET. */

/* ── 3) ★★★ MAĞAZA DA İNDİRİMLİ SATIYOR — bir önceki commit'in DÜZELTMESİ ──── */
WITH mg AS (
  SELECT p.posStkID AS stkID, SUM(p.satTutar) AS ciro, SUM(p.satAdet) AS adet,
         SUM(p.satIndirim) AS ind
  FROM   DerinSISBkm.dbo.posOzetUrun p WITH(NOLOCK)
  WHERE  p.posTarih >= DATEADD(MONTH,-12,GETDATE()) AND p.posMekan IN (1,4477,4478)
         AND p.satAdet > 0
  GROUP BY p.posStkID
), x AS (
  SELECT v.stkID, v.MarjFarki, v.SatisMarji AS web_ind, v.AlisIskonto,
         mg.ciro, 100.0*(1 - mg.ciro/NULLIF(mg.adet*u.fiyatS,0)) AS magaza_ind
  FROM   DerinSISBkm.bkm.OdaktaDatasiOlupMarjiSorunluUrunler v
  JOIN   mg ON mg.stkID = v.stkID
  JOIN   DerinSISBkm.dbo.urn u WITH(NOLOCK) ON u.stkID = v.stkID
  WHERE  u.fiyatS > 0
)
SELECT CASE WHEN MarjFarki < 0 THEN 'a) NEGATIF' WHEN MarjFarki < 11 THEN 'b) esik alti'
            ELSE 'c) esik ustu' END AS bant,
       COUNT(*) AS urun, CONVERT(decimal(18,0), SUM(ciro)) AS magaza_ciro,
       CONVERT(decimal(10,1), SUM(magaza_ind*ciro)/SUM(ciro))  AS magaza_ind,
       CONVERT(decimal(10,1), SUM(web_ind*ciro)/SUM(ciro))     AS web_ind,
       CONVERT(decimal(10,1), SUM(AlisIskonto*ciro)/SUM(ciro)) AS alis_isk,
       CONVERT(decimal(10,1), SUM((AlisIskonto-magaza_ind)*ciro)/SUM(ciro)) AS MAGAZA_MARJ_FARKI,
       SUM(CASE WHEN AlisIskonto-magaza_ind < 0 THEN 1 ELSE 0 END) AS magazada_negatif_urun,
       CONVERT(decimal(18,0), SUM(CASE WHEN AlisIskonto-magaza_ind < 0 THEN ciro ELSE 0 END)) AS magazada_negatif_ciro
FROM x
GROUP BY CASE WHEN MarjFarki < 0 THEN 'a) NEGATIF' WHEN MarjFarki < 11 THEN 'b) esik alti'
            ELSE 'c) esik ustu' END
ORDER BY bant;
/* (ciro ağırlıklı, listeden sapma olarak — view'ın SatisMarji tanımıyla AYNI taban)
   bant          ürün   mağaza cirosu   mağaza ind.  web ind.  alış isk.  MAĞAZA MarjFarkı
   a) NEGATİF  10.713    97.351.818 ₺      %19,6      %28,1      %5,3        **−14,3**
   b) eşik altı 23.324   100.710.365        %31,2      %36,3     %42,0         +10,8
   c) eşik üstü 50.176   276.260.583        %30,6      %23,3     %44,9         +14,3

   ⇒ ✅ Mağaza web'den DAHA AZ indirim veriyor (her üç bantta da) — o kadarı doğruydu.
   ⇒ ❌ Ama **NEGATİF bantta mağaza da EKSİDE (−14,3 puan)**: 7.712 ürün ·
     85.573.406 ₺ mağaza cirosu. Yani zarar WEB'E ÖZGÜ DEĞİL.
   ⇒ Alt bantlarda da mağazada negatif olan var: eşik altı 3.032 ürün / 10,0M ₺ ·
     eşik üstü 7.561 ürün / 29,3M ₺ (o bantlarda ORTALAMA pozitif ama kuyruk eksi). */

/* ── 4) NEGATİF BANT × REYON — mekanizma AYRIŞIYOR ─────────────────────────── */
-- (blok 3'teki mg CTE'si ile; HAVING SUM(ciro) > 2.000.000)
/* bant        reyon                  ürün   mağaza cirosu   kasa ind.  alış isk.
   NEGATİF     **Kampanya Dışı**     5.997    60.334.838 ₺     %2,6       **%1,3**
   NEGATİF     %50 INDIRIM             765     6.179.335       %47,8       %17,0
   NEGATİF     3 AL 2 ÖDE            1.851     5.644.035       %23,1       %40,3
   NEGATİF     %20 INDIRIM             364     2.779.574        %8,8        %0,7
   NEGATİF     99.00 TL ÖZEL FİYAT     140     2.675.732       %41,5       %21,3
   NEGATİF     %25 INDIRIM             358     2.654.104       %10,7        %0,8
   NEGATİF     299.00 TL ÖZEL FİYAT     68     2.244.311       %35,1        %0,5
   eşik altı   3 AL 2 ÖDE           19.805    78.705.693       %24,0       %42,5
   eşik üstü   3 AL 2 ÖDE           41.734   205.155.103       %24,0       %44,7
   eşik üstü   Kampanya Dışı         5.317    56.798.117        %7,5       %42,8

   ★★★ NEGATİF BANDIN EN BÜYÜK PARÇASI **"Kampanya Dışı"** (60,3M ₺ · 5.997 ürün)
     ve orada **kasa indirimi %2,6 ama ALIŞ İSKONTOSU %1,3**.
     ⇒ Bu ürünlerde sorun KAMPANYADA DEĞİL, **ALIŞ TARAFINDA**: neredeyse sıfır
       iskontoyla alınıyorlar. Mağaza listeden satıyor, web indirimli satıyor;
       web'in kaybı alış iskontosunun yokluğundan doğuyor.
   ★★ **3 AL 2 ÖDE KALİBRE:** üç bantta da kasa indirimi %23-24 iken alış iskontosu
     %40-45. Katalogun yarısını kapsayan baskın kampanya SAĞLIKLI ÇALIŞIYOR —
     CLAUDE.md'nin "3Al2Öde gerçek kârlılık etkisi" açık maddesine ilk ölçülmüş yanıt.
   ⚠ Küçük ama keskin kuyruk: `%50 INDIRIM` + `ÖZEL FİYAT` etiketli NEGATİF ürünler
     (≈973 ürün / 11,1M ₺) %35-48 indirimle satılırken %0,5-21 iskontoyla alınmış.
     Kampanyanın gerçekten zarar ürettiği yer BURASI, 3 AL 2 ÖDE değil. */

/* ============================================================================
   SINIRLAR (beyan)
   · `magaza_ind` = listeden sapma (1 − gerçekleşen/fiyatS). İçinde kampanya
     indirimi VE fiyat listesi kayması BİRLİKTE var; ikisi ayrıştırılmadı.
     `kasa_ind` (satIndirim/brüt) yalnız kasada uygulanan indirimi verir — iki
     ölçü farklı şeylerdir, aynı sütunda karşılaştırılmaz.
   · `fiyatS` ANLIK liste fiyatıdır; 12 aylık cironun tamamı bugünün listesiyle
     kıyaslandı ⇒ fiyat artışı olan üründe indirim OLDUĞUNDAN BÜYÜK görünür.
     (Aynı kusur TODO B-177'de kayıtlı.)
   · `kod4ID` ANLIK etikettir; satışın yapıldığı gün başka etikette olabilirdi.
     Geçmiş `bkm.urnkod4log`dadır ve 2026-05-06/12'de toplu yeniden etiketleme var.
   · `AlisIskonto` MARKA bazlı vekildir (odak_marka.discount), ürün bazlı fatura
     iskontosu değil. Kargo/komisyon/iade yine hesap dışı ⇒ tablo İYİMSER.
   ============================================================================ */
