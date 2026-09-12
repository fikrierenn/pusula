/* ============================================================================
   MARJI SORUNLU ÜRÜNLER — İŞLETMENİN KENDİ TANIMI, İLK KEZ ÖLÇÜLDÜ   2026-09-12
   DB: DerinSISBkm + BKMDATA (profil: erp)

   `bkm.OdaktaDatasiOlupMarjiSorunluUrunler` (VIEW, 2025-09-02, ŞİFRESİZ) okundu.
   ⭐ Bulgu YENİ DEĞİL — birileri 2025'te bu view'ı yazmış ve adını koymuş.
     YENİ OLAN: kaç ürün ve kaç lira olduğunun ÖLÇÜLMESİ.
   ============================================================================ */

/* ── 1) ★ İŞLETMENİN MARJ TANIMI (view tanımından, tahmin değil) ────────────── */
SELECT m.definition FROM DerinSISBkm.sys.sql_modules m
JOIN   DerinSISBkm.sys.objects o ON o.object_id = m.object_id
JOIN   DerinSISBkm.sys.schemas s ON s.schema_id = o.schema_id
WHERE  s.name='bkm' AND o.name='OdaktaDatasiOlupMarjiSorunluUrunler';
/*   ustFiyat    = urn.fiyatS                          (liste, KDV dahil)
     SiteFiyati  = ent.tsoft_urun.fiyat_net_kdvdahil   (web satış, KDV dahil)
     SatisMarji  = (1 − SiteFiyati / ustFiyat) × 100   → SATIŞTA verilen indirim
     AlisIskonto = BKMDATA.ent.odak_marka.discount     → ALIŞTA alınan iskonto (MARKA bazlı)
     **MarjFarki = AlisIskonto − SatisMarji**
   View'de yoruma alınmış iş eşiği:  WHERE ISKONTO - SatisMarji < 11
   Kapsam: tsoft_urun.satis_durum=1 (sitede aktif) + ODAK'ta datası olan ürün.

   ⭐⭐ BU TANIM MALİYET ŞELALESİNE HİÇ İHTİYAÇ DUYMUYOR — `BirimMaliyet` ve onun
     bilinen çürümesi (metrics:birim_maliyet § ORT_ALIS_CURUDU) devreye girmiyor.
     Üç girdi de görece sağlam: liste · web fiyatı · marka iskontosu.
     "Hedef marj vs fiili marj" yolu maliyet yüzünden çıkmaza girmişti; ÖLÇÜLEBİLİR
     hâli budur. */

/* ── 2) ★★ BANT DAĞILIMI ────────────────────────────────────────────────────── */
SELECT CASE WHEN MarjFarki < 0  THEN 'a) NEGATIF (zararina)'
            WHEN MarjFarki < 5  THEN 'b) 0-5 puan'
            WHEN MarjFarki < 11 THEN 'c) 5-11 puan (SORUNLU esigi)'
            WHEN MarjFarki < 20 THEN 'd) 11-20 puan'
            ELSE 'e) 20+ puan' END AS bant,
       COUNT_BIG(*) AS urun,
       CONVERT(decimal(10,1), AVG(MarjFarki))   AS ort_marj_farki,
       CONVERT(decimal(10,1), AVG(SatisMarji))  AS ort_satis_indirimi,
       CONVERT(decimal(10,1), AVG(AlisIskonto)) AS ort_alis_iskonto,
       SUM(CASE WHEN Rakip='RakipTakip' THEN 1 ELSE 0 END) AS rakip_takipli
FROM   DerinSISBkm.bkm.OdaktaDatasiOlupMarjiSorunluUrunler
GROUP BY CASE WHEN MarjFarki < 0  THEN 'a) NEGATIF (zararina)'
            WHEN MarjFarki < 5  THEN 'b) 0-5 puan'
            WHEN MarjFarki < 11 THEN 'c) 5-11 puan (SORUNLU esigi)'
            WHEN MarjFarki < 20 THEN 'd) 11-20 puan'
            ELSE 'e) 20+ puan' END
ORDER BY bant;
/* bant                       ürün    MarjFarki  satış ind.  alış isk.  rakip takipli
   a) NEGATİF (zararına)    15.457      −20,7      %35,5      %14,8          81
   b) 0-5 puan              20.569        2,6      %36,7      %39,4         394
   c) 5-11 (SORUNLU eşiği)  21.057        8,1      %35,1      %43,1         936
   d) 11-20 puan           248.157       14,0      %27,6      %41,7       2.172
   e) 20+ puan              18.127       29,2      %16,8      %46,0         127
   TOPLAM 323.367
   ⇒ **57.083 ürün (%17,7) işletmenin KENDİ eşiğinin altında; 15.457'si NEGATİF.**
   ⇒ NEGATİF bantta alış iskontosu çarpıcı biçimde DÜŞÜK (%14,8) ama satış indirimi
     bandın en yükseklerinden (%35,5) — yani "ucuza alamadığımız malı ucuza satıyoruz". */

/* ── 3) ★★★ WEB CİROSU — asıl materyalite ──────────────────────────────────── */
SELECT CASE WHEN v.MarjFarki < 0 THEN 'a) NEGATIF'
            WHEN v.MarjFarki < 11 THEN 'b) esik alti (0-11)'
            ELSE 'c) esik ustu (11+)' END AS bant,
       COUNT(DISTINCT v.stkID) AS urun,
       COUNT(DISTINCT CASE WHEN e.stkID IS NOT NULL THEN v.stkID END) AS web_satan,
       CONVERT(decimal(18,0), SUM(ISNULL(e.ToplamAdet,0)))          AS web_adet,
       CONVERT(decimal(18,0), SUM(ISNULL(e.NetFiyatToplamCiro,0)))  AS WEB_CIRO
FROM   DerinSISBkm.bkm.OdaktaDatasiOlupMarjiSorunluUrunler v
LEFT JOIN DerinSISBkm.bkm.Enf_AylikUrunSatislari e WITH(NOLOCK)
       ON e.stkID = v.stkID AND e.Kaynak = 'bkmkitapcom'
      AND e.Ay >= DATEADD(MONTH,-12,GETDATE())
GROUP BY CASE WHEN v.MarjFarki < 0 THEN 'a) NEGATIF'
            WHEN v.MarjFarki < 11 THEN 'b) esik alti (0-11)'
            ELSE 'c) esik ustu (11+)' END
ORDER BY bant;
/* NEGATİF           15.425 ürün ·  8.357 web'de satmış ·   344.033 adet ·  62.182.583 ₺
   eşik altı (0-11)  41.612      · 30.541                · 1.481.210      · 308.387.242 ₺
   eşik üstü (11+)  266.195      · 108.102               · 1.760.618      · 356.263.821 ₺

   ⇒ **TOPLAM WEB CİROSUNUN %51'İ (370.569.825 / 726.833.646 ₺) EŞİĞİN ALTINDAKİ
     ÜRÜNDEN GELİYOR.** */

/* ── 4) NEGATİF BANDIN KATEGORİ KIRILIMI ───────────────────────────────────── */
SELECT v.Kategori, COUNT_BIG(*) AS urun,
       CONVERT(decimal(10,1), AVG(v.MarjFarki)) AS ort_marj_farki,
       SUM(CASE WHEN b.SatisToplam > 0 THEN 1 ELSE 0 END) AS magaza_satan,
       SUM(ISNULL(b.SatisToplam,0)) AS magaza_adet,
       CONVERT(decimal(18,0), SUM(ISNULL(b.PosNet,0))) AS kasa_cirosu
FROM   DerinSISBkm.bkm.OdaktaDatasiOlupMarjiSorunluUrunler v
LEFT JOIN DerinSISBkm.bkm.SatisAnaliziTaban b WITH(NOLOCK)
       ON b.stkID = v.stkID AND b.Kesim = '20260911'
WHERE  v.MarjFarki < 0
GROUP BY v.Kategori HAVING COUNT_BIG(*) >= 100 ORDER BY urun DESC;
/* **Kırtasiye 9.113 ürün · −28,2 puan · 7.683 satan · 569.825 adet · 68,3M ₺ (kasa)**
   Kitap 3.198 · −10,6 · 1.200 · 18.922 · 4,8M    Çocuk Kitabı 1.245 · −6,7 · 824 · 2,7M
   Oyuncak 826 · −14,7 · 738 · 59.380 · 16,5M     Akademi 435 · −6,2 · 45 · 0,2M
   Hazırlık 410 · −8,5 · 189 · 5.317 · 1,6M       Tanımsız 129 · −3,8 · 0 satan
   ⇒ Sorun ezici çoğunlukla **KIRTASİYE**: listeden ~%35+ indirim veriliyor ama
     tedarikçiden yalnız ~%15 iskonto alınıyor.

   ⚠⚠ KANAL UYARISI (kullanıcı düzeltmesi): "tanımlanan alış şartları MAĞAZA İÇİNDE
     DE GEÇERLİ" — `AlisIskonto` kanaldan BAĞIMSIZ. Fark SATIŞ tarafında: web
     indirimli satıyor, mağaza satmıyor.
     ⇒ Bulgu **WEB'E ÖZGÜDÜR**; aynı ürünün MAĞAZA marjı daha iyidir.
     ⇒ Bu tablodaki "kasa cirosu" sütunu ürünlerin CANLI olduğunu gösterir,
       zararına satıldıklarını GÖSTERMEZ. Zarar iddiası yalnız WEB cirosu için kurulur. */

/* ============================================================================
   SINIRLAR (beyan)
   · `AlisIskonto` MARKA bazlı (odak_marka.discount), ürün bazlı gerçek fatura
     iskontosu DEĞİL. İşletmenin kendi vekili; alış faturasıyla doğrulanmadı.
   · Kargo · kampanya · ödeme komisyonu · iade HESABA GİRMİYOR ⇒ gerçek net marj
     bu sayıdan DAHA DÜŞÜK; tablo İYİMSER.
   · `MarjFarki` bir PUAN FARKIDIR, yüzde marj değil.
   · 11 puanlık eşik İŞLETMENİN seçimi (view'de yoruma alınmış); nasıl türetildiği
     ÖLÇÜLMEDİ.
   ============================================================================ */
