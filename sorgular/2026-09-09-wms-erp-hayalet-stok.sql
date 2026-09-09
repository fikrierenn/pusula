/* ═══════════════════════════════════════════════════════════════════════════════
   WMS ↔ ERP DEFTERİ ÇELİŞKİSİ — merkez depoda hayalet stok             09.09.2026
   DB: DerinSISBkm

   SORU (kullanıcı): "stok hareketlerine bakınca aslında gr paletteki ürün satış
   faturası düzenlenerek çıkmış" + "akademik tarafta bir sürü ürün 1 adet depoda
   gözüküyor, depoda kitap yok normalde".

   BULGU: Duran kural "merkez stoğu her zaman WMS" (defter negatif taşıdığı için)
   TEK YÖNLÜ okunuyordu. Ters yön de var: satış ERP'de kesilip WMS'ten düşülmediğinde
   WMS şişik kalıyor → ekranda/raporda HAYALET stok.

   Sema: entities.yaml MERKEZ_STOK_WMS_ERP_CELISKISI + depo.paletIcHrk
   Kural: .claude/rules/sql-server-conventions.md § WMS DE MUTLAK DOĞRU DEĞİL
   Rapor: scripts/gr_palet_supheli_excel.py
   ═══════════════════════════════════════════════════════════════════════════════ */

-- ── 1) VAKA: stkID 248104 — ERP defteri ne diyor? ─────────────────────────────
SELECT CONVERT(char(10), h.ehTrhS, 104) AS Tarih, CONVERT(int, h.ehMekan) AS Mekan,
       CONVERT(int, h.ehTip) AS ehTip, ISNULL(v.tipAd, '?') AS TipAd,
       CONVERT(int, h.ehAdetN) AS Adet, h.ehID, i.eNo, i.eFirma
FROM dbo.irsHrk h WITH (NOLOCK)
LEFT JOIN dbo.irsTip_vw v ON v.tipID = h.ehTip
LEFT JOIN dbo.irs i WITH (NOLOCK) ON i.eID = h.ehID
WHERE h.ehstkID = 248104 AND h.ehMekan = 12
ORDER BY h.ehTrhS DESC;
-- SONUÇ: 23.02.2026 Mağaza→Depo +1 (D012026000001079, İst.Yolu'ndan dönüş)
--         22.05.2026 SATIŞ −1 (belge 7135278, firma 375)
--         → merkez defter bakiyesi 0

-- ── 2) Aynı ürün WMS'te ne gösteriyor? ────────────────────────────────────────
SELECT ISNULL(a.alanTipAd, '?') AS AlanTip, d.adrsAd AS Adres, d.PaletID,
       CONVERT(int, d.Stok) AS Adet,
       CASE WHEN d.adrsAlanTipID IN (0, 1) THEN 'MerkezStok''a dahil' ELSE 'HARİÇ' END AS Kapsam
FROM depo.stok_adres_palet_vw d WITH (NOLOCK)
LEFT JOIN depo.adresAlanTip a ON a.alanTipID = d.adrsAlanTipID
WHERE d.stkID = 248104;
-- SONUÇ: GİRİŞ ALANI / GR01 / palet 37250 / 1 adet
--         → ERP 0, WMS 1. ÇELİŞKİ.

-- ── 3) 10.07 hareketi MAL KABUL mü? (hayır — belgesiz iç taşıma) ──────────────
SELECT CONVERT(char(10), h.pikTarih, 104) + ' ' + CONVERT(char(5), h.pikTarih, 108) AS Zaman,
       h.piİlkID AS Palet, h.piSonID AS KarsiPalet, CONVERT(int, h.piAdet) AS Adet,
       CASE h.pGC WHEN 0 THEN 'GİRİŞ' ELSE 'ÇIKIŞ' END AS Yon,
       ISNULL(tp.pHrkTipAd, '?') AS HrkTip,
       h.piIlkAdrsID AS AdrsID, h.piIrsID AS IrsaliyeID, h.pikKisi
FROM depo.paletIcHrk h WITH (NOLOCK)
LEFT JOIN depo.paletIcHrkTip tp ON tp.pHrkTipID = h.pHrkTip
WHERE h.piStkID = 248104
ORDER BY h.pikTarih DESC;
-- SONUÇ: 23.02.2026 15:18 palet 37060'a giriş, piIrsID=7121400 (transfer irsaliyesi) ✓
--         23.02.2026 15:21 → 44711 (raf, adres 89762), belgesiz
--         13.04.2026 09:58 44711 ↔ 37077 (iki kez, aynı dakika — geri alınmış)
--         10.07.2026 09:55 44711 → 37250 (GR01, adres 16338), piIrsID=0 → BELGESİZ
--   ⚠ Hepsi pHrkTip=0 KULLANICI (elle). 22.05'teki SATIŞA KARŞILIK GELEN KAYIT YOK
--     → satış ERP'de kesildi, WMS'ten düşülmedi; mal rafta kaldı, sonra elle GR'ye taşındı.
--   ⚠ Yani "palete giriş 10.07" MAL KABUL DEĞİL. Ekranda "palete konuldu" diye yazılır.

-- ── 4) piİlkID / piSonID hangisi hedef? — İKİ HİPOTEZ, view ile sına ──────────
-- Kayıt YÖNÜ belgelenmemişti; ölçmeden kullanmak "makul ama yanlış" üretir.
SELECT 'A: Son = hedef' AS Hipotez,
  CONVERT(int, (SELECT ISNULL(SUM(piAdet), 0) FROM depo.paletIcHrk WITH (NOLOCK)
                WHERE piStkID = 235636 AND piSonID = 37250))  AS Palet37250,
  CONVERT(int, (SELECT ISNULL(SUM(piAdet), 0) FROM depo.paletIcHrk WITH (NOLOCK)
                WHERE piStkID = 235636 AND piSonID = 230598)) AS Palet230598
UNION ALL
SELECT 'B: İlk = hedef',
  CONVERT(int, (SELECT ISNULL(SUM(piAdet), 0) FROM depo.paletIcHrk WITH (NOLOCK)
                WHERE piStkID = 235636 AND piİlkID = 37250)),
  CONVERT(int, (SELECT ISNULL(SUM(piAdet), 0) FROM depo.paletIcHrk WITH (NOLOCK)
                WHERE piStkID = 235636 AND piİlkID = 230598))
UNION ALL
SELECT 'GERÇEK (view)',
  CONVERT(int, (SELECT ISNULL(SUM(Stok), 0) FROM depo.stok_adres_palet_vw WITH (NOLOCK)
                WHERE stkID = 235636 AND PaletID = 37250)),
  CONVERT(int, (SELECT ISNULL(SUM(Stok), 0) FROM depo.stok_adres_palet_vw WITH (NOLOCK)
                WHERE stkID = 235636 AND PaletID = 230598));
-- SONUÇ: A → −2 / −3 · B → 2 / 3 · GERÇEK → 2 / 3
--   → piİlkID hareketin SAHİBİ palet, piSonID KARŞI palet. KANITLANDI.
-- ⚠ Kolon adı TÜRKÇE İ ile: piİlkID. ASCII piIlkID yazımı Err 207 verir.

-- ── 5) pGC ve pHrkTip kod kümeleri (liste elle yazılmaz) ──────────────────────
SELECT CONVERT(int, pGC) AS pGC, COUNT(*) AS Satir,
       CONVERT(bigint, SUM(piAdet)) AS AdetToplam,
       SUM(CASE WHEN piAdet < 0 THEN 1 ELSE 0 END) AS NegatifSatir
FROM depo.paletIcHrk WITH (NOLOCK)
GROUP BY pGC;
-- SONUÇ: 0 → 780.009 satır, hepsi pozitif (GİRİŞ) · 1 → 981.769 satır, 979.868'i negatif (ÇIKIŞ)

SELECT * FROM depo.paletIcHrkTip;
-- SONUÇ: 0 KULLANICI · 1 EMİR · 2 SAYIM · 3 GERİ AL

-- ── 6) ÖLÇEK: çelişki iki yönde de kaç ürün? ──────────────────────────────────
-- Yön A — WMS pozitif ama defter ≤ 0 (HAYALET)
SELECT COUNT(*) AS Cesit, CONVERT(bigint, SUM(w.WmsStok)) AS WmsAdet,
       CONVERT(bigint, SUM(ISNULL(e.DefterNet, 0))) AS DefterAdet
FROM (SELECT stkID, SUM(Stok) AS WmsStok FROM depo.stok_adres_palet_vw WITH (NOLOCK)
      WHERE adrsAlanTipID IN (0, 1) GROUP BY stkID HAVING SUM(Stok) > 0) w
LEFT JOIN (SELECT ehstkID, SUM(ehAdetN) AS DefterNet FROM dbo.irsHrk WITH (NOLOCK)
           WHERE ehMekan = 12 GROUP BY ehstkID) e ON e.ehstkID = w.stkID
WHERE ISNULL(e.DefterNet, 0) <= 0;
-- SONUÇ: 349 çeşit / WMS 3.757 adet (defter toplamı −4.364)

-- Yön B — defter pozitif ama WMS'te yok (WMS'in tercih sebebi)
SELECT COUNT(*) AS Cesit, CONVERT(bigint, SUM(e.DefterNet)) AS DefterAdet
FROM (SELECT ehstkID, SUM(ehAdetN) AS DefterNet FROM dbo.irsHrk WITH (NOLOCK)
      WHERE ehMekan = 12 GROUP BY ehstkID HAVING SUM(ehAdetN) > 0) e
LEFT JOIN (SELECT stkID, SUM(Stok) AS WmsStok FROM depo.stok_adres_palet_vw WITH (NOLOCK)
           WHERE adrsAlanTipID IN (0, 1) GROUP BY stkID) w ON w.stkID = e.ehstkID
WHERE ISNULL(w.WmsStok, 0) <= 0;
-- SONUÇ: 9.146 çeşit / 1.996.995 adet
--   → İKİSİ DE TEK BAŞINA DOĞRU DEĞİL. Kural çift yönlü okunmalı.

-- ── 7) MEKANİZMA doğrulaması: hayaletlerin kaçında satış + belgesiz hareket var?
SELECT COUNT(*) AS Cesit, CONVERT(bigint, SUM(x.WmsStok)) AS WmsHayaletAdet,
       SUM(CASE WHEN x.SatisVar = 1 THEN 1 ELSE 0 END)   AS MerkezSatisiOlan,
       SUM(CASE WHEN x.Belgesiz = 1 THEN 1 ELSE 0 END)   AS BelgesizHareketiOlan
FROM (
    SELECT w.stkID, w.WmsStok,
      CASE WHEN EXISTS (SELECT 1 FROM dbo.irsHrk s WITH (NOLOCK)
                        WHERE s.ehstkID = w.stkID AND s.ehMekan = 12 AND s.ehTip = 1)
           THEN 1 ELSE 0 END AS SatisVar,
      CASE WHEN EXISTS (SELECT 1 FROM depo.paletIcHrk pi WITH (NOLOCK)
                        WHERE pi.piStkID = w.stkID AND pi.piIrsID = 0)
           THEN 1 ELSE 0 END AS Belgesiz
    FROM (SELECT stkID, SUM(Stok) AS WmsStok FROM depo.stok_adres_palet_vw WITH (NOLOCK)
          WHERE adrsAlanTipID IN (0, 1) GROUP BY stkID HAVING SUM(Stok) > 0) w
    LEFT JOIN (SELECT ehstkID, SUM(ehAdetN) AS Net FROM dbo.irsHrk WITH (NOLOCK)
               WHERE ehMekan = 12 GROUP BY ehstkID) e ON e.ehstkID = w.stkID
    WHERE ISNULL(e.Net, 0) <= 0
) x;
-- SONUÇ: 349 çeşit / 3.757 adet · 261'inde merkez satışı · 342'sinde belgesiz palet hareketi
--   → mekanizma tek vaka değil, DESEN.

-- ── 8) KATEGORİ YIĞILMASI — kullanıcı gözlemi ("depoda kitap yok normalde") ───
SELECT ISNULL(t.Kategori3, '(evren dışı)') AS Kategori3,
       COUNT(*) AS Cesit,
       SUM(CASE WHEN w.WmsStok = 1 THEN 1 ELSE 0 END) AS TekAdet,
       CONVERT(bigint, SUM(w.WmsStok)) AS WmsAdet,
       SUM(CASE WHEN ISNULL(e.Net, 0) <= 0 THEN 1 ELSE 0 END) AS Hayalet
FROM (SELECT stkID, SUM(Stok) AS WmsStok FROM depo.stok_adres_palet_vw WITH (NOLOCK)
      WHERE adrsAlanTipID IN (0, 1) GROUP BY stkID HAVING SUM(Stok) > 0) w
LEFT JOIN bkm.SatisAnaliziTaban t ON t.stkID = w.stkID AND t.Kesim = '20260908'
LEFT JOIN (SELECT ehstkID, SUM(ehAdetN) AS Net FROM dbo.irsHrk WITH (NOLOCK)
           WHERE ehMekan = 12 GROUP BY ehstkID) e ON e.ehstkID = w.stkID
GROUP BY t.Kategori3
ORDER BY 3 DESC;
-- SONUÇ (Cesit / Hayalet → oran):
--   Akademi    84 / 76 → %90   ← kullanıcı gözlemi DOĞRU
--   Kitap     127 / 77 → %61
--   Kırtasiye 15.803 / 142 → %0,9
--   Oyuncak    5.299 /  41 → %0,8
--   → Hayalet KİTAP tarafında yığılı. Merkez depo kitap tutmuyor; oradaki tek-adetler
--     mağazadan dönüp satılan ama WMS'ten düşülmemiş kalıntılar.

-- ── 9) GİRİŞ ALANI (GR) paletlerinde bekleyen şüpheli mal ─────────────────────
SELECT COUNT(*) AS Satir, COUNT(DISTINCT d.stkID) AS Cesit,
       CONVERT(int, SUM(d.Stok)) AS Adet,
       SUM(CASE WHEN ISNULL(e.Net, 0) <= 0 THEN 1 ELSE 0 END) AS SupheliSatir
FROM depo.stok_adres_palet_vw d WITH (NOLOCK)
LEFT JOIN (SELECT ehstkID, SUM(ehAdetN) AS Net FROM dbo.irsHrk WITH (NOLOCK)
           WHERE ehMekan = 12 GROUP BY ehstkID) e ON e.ehstkID = d.stkID
WHERE d.adrsAlanTipID = 1 AND d.Stok <> 0;
-- SONUÇ: 4.753 satır / 4.352 çeşit / 182.313 adet; bunlardan 234 satır ŞÜPHELİ.
--   Excel çıktısı: scripts/gr_palet_supheli_excel.py
--     GR       → 234 satır /  1.434 adet /   456.525 ₺ (etiket)
--     tüm alan → 998 satır / 13.038 adet / 3.479.742 ₺
--
-- ⚠ SINIR: bu bir SAYIM EMRİDİR, muhasebe kaydı değil. "ERP'ye göre yok" ≠ "fiilen yok";
--   ters yön (blok 6-B) 9.146 çeşitte tam tersini gösteriyor. Karar fiziksel sayımla verilir.
