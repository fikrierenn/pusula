/* ============================================================================
   DEFTER GRUBU STOK YETERLİLİĞİ — OKUL-HİZALI YoY KONTROL (14.09.2026)

   Soru (GMY): "defter grubunda stok seviyesi yeterli midir, geçen yıl-bu yıl
   bir kontrol raporu"

   EVREN   : bkm.UrunBilgi.Kat1 = 'Defterler' (11.554 çeşit, hepsi urnTip=0 mal)
   MEKAN   : şube 1 FSM · 4477 Özlüce · 4478 İst.Yolu  (+ merkez depo 12 = WMS)
             ⚠ Bu bir KAPSAM SEÇİMİ; defterde 9 mekan var (sql-server-conventions
             § MEKAN = frm içindeki bir taraf). İade Deposu (4480) vb. hariç.
   SATIŞ   : irsHrk ehTip 100 − 101 + 4 − 5  (kanonik şube cirosu formülü)
             Adet işareti: satış NEGATİF, iade POZİTİF → net adet = -SUM(ehAdetN)
             ölçüldü 14.09.2026: ehTip 100 −72.224 / 101 +707 / 4 −2.740 / 5 +1
   ehAltDepo: Defterler'de TÜMÜ 0 (ölçüldü) → süzgece gerek yok, etkisi sıfır
   STOK    : şube anlık   = dbo.stokSonAltDepo_vw (şube için DOĞRU)
             şube tarihsel = bkm.StokAyBakiyeMekanBazli (Kaynak='irsHrk')
             merkez depo   = depo.stok_adres_palet_vw, adrsAlanTipID IN (0 RAF,1 GİRİŞ)
             ⚠ merkez depo ERP defterinden OKUNMAZ (kullanıcı direktifi 03.09.2026)
             ⚠ WMS snapshot YALNIZ 2026-08-31 var → DEPO YoY ÖLÇÜLEMEZ

   OKUL HİZALAMA (kritik): okul açılışı 2025 → 08.09.2025 · 2026 → 14.09.2026
   6 gün kayma. Takvim ayı kıyası YÖNÜ TERS gösteriyor:
     Ağu-2026 23.943 ad vs Ağu-2025 30.018 ad → −%20,2  (SAHTE düşüş)
     hizalı T−45..T−1                         → +%11,0  (GERÇEK)
============================================================================ */

/* ---------------------------------------------------------------- BLOK 1
   Kapsam: 'Defterler' grubu var mı, kaç çeşit, hepsi mal mı? */
SELECT COUNT(*) cesit, SUM(CASE WHEN urnTip=0 THEN 1 ELSE 0 END) mal
FROM bkm.UrunBilgi WHERE Kat1='Defterler';
-- ÖLÇÜLDÜ 14.09.2026: 11.554 / 11.554 (tamamı stok ürünü)

/* ---------------------------------------------------------------- BLOK 2
   Aylık satış (mevsimsellik + takvim tuzağının kanıtı) */
SELECT YEAR(h.ehTrhS) yil, MONTH(h.ehTrhS) ay,
       -SUM(h.ehAdetN) net_adet, SUM(h.ehTutarN) net_tutar,
       COUNT(DISTINCT h.ehstkID) cesit
FROM dbo.irsHrk h
JOIN bkm.UrunBilgi u ON u.stkID = h.ehstkID
WHERE u.Kat1='Defterler' AND h.ehMekan IN (1,4477,4478)
  AND h.ehTip IN (4,5,100,101)
  AND h.ehTrhS >= '20240101' AND h.ehTrhS < '20260915'
GROUP BY YEAR(h.ehTrhS), MONTH(h.ehTrhS)
ORDER BY 1,2;
-- Sezon zirvesi Eylül: 2024 70.111 · 2025 90.156 · 2026 (14 güne kadar) 52.098

/* ---------------------------------------------------------------- BLOK 3
   Okul-hizalı günlük seri (Python'da T-index'e çevrilir)
   2025 çıpa 08.09.2025 · 2026 çıpa 14.09.2026 */
SELECT CONVERT(varchar(8), h.ehTrhS, 112) gun, h.ehMekan,
       -SUM(h.ehAdetN) adet, SUM(h.ehTutarN) tutar
FROM dbo.irsHrk h
JOIN bkm.UrunBilgi u ON u.stkID = h.ehstkID
WHERE u.Kat1='Defterler' AND h.ehMekan IN (1,4477,4478)
  AND h.ehTip IN (4,5,100,101)
  AND ( (h.ehTrhS >= '20250715' AND h.ehTrhS < '20251115')
     OR (h.ehTrhS >= '20260715' AND h.ehTrhS < '20261115') )
GROUP BY CONVERT(varchar(8), h.ehTrhS, 112), h.ehMekan
ORDER BY 1,2;
-- ÖLÇÜLDÜ: T−45..T−1 adet 67.294 → 74.684 (+%11,0) · tutar 5,69M → 7,87M (+%38,3)
--          2025 T+0..T+30 (sezonun geri kalanı) = 61.842 adet

/* ---------------------------------------------------------------- BLOK 4
   Sezon girişi stoğu: 31.08.2025 vs 31.08.2026 (şube snapshot)
   ⚠ maliyet SABİT FİYATLA (bugünün SonAlis'i her iki yıla) → mix ölçer, ₺ değil */
SELECT s.Donem, s.ehMekan,
       SUM(CASE WHEN s.Stok>0 THEN s.Stok ELSE 0 END) poz_adet,
       COUNT(CASE WHEN s.Stok>0 THEN 1 END)          poz_cesit,
       SUM(CASE WHEN s.Stok>0 THEN s.Stok*u.SonAlis ELSE 0 END) sabit_fiyat_maliyet
FROM bkm.StokAyBakiyeMekanBazli s
JOIN bkm.UrunBilgi u ON u.stkID = s.stkID
WHERE u.Kat1='Defterler' AND s.Kaynak='irsHrk'
  AND s.Donem IN ('20250831','20260831')
GROUP BY s.Donem, s.ehMekan ORDER BY s.Donem, s.ehMekan;
-- ÖLÇÜLDÜ: 192.507 → 174.164 adet (−%9,5) · çeşit 12.484 → 13.351 (+%6,9)
--          ⇒ çeşit başı derinlik 15,4 → 13,0 adet (−%15,6)

/* ---------------------------------------------------------------- BLOK 5
   Bugünkü şube stoğu + merkez depo (WMS) */
SELECT t.ehMekan, SUM(CASE WHEN t.st>0 THEN t.st ELSE 0 END) poz,
       SUM(CASE WHEN t.st<0 THEN t.st ELSE 0 END) neg,
       COUNT(CASE WHEN t.st>0 THEN 1 END) poz_cesit
FROM (SELECT v.ehMekan, v.ehstkID, SUM(v.stok) st
      FROM dbo.stokSonAltDepo_vw v
      JOIN bkm.UrunBilgi u ON u.stkID = v.ehstkID
      WHERE u.Kat1='Defterler' AND v.ehMekan IN (1,4477,4478)
      GROUP BY v.ehMekan, v.ehstkID) t
GROUP BY t.ehMekan ORDER BY t.ehMekan;
-- ÖLÇÜLDÜ 14.09.2026: FSM 54.622 · Özlüce 69.605 · İst.Yolu 52.004 = 176.231

SELECT p.adrsAlanTipID, SUM(p.Stok) adet, COUNT(DISTINCT p.stkID) cesit
FROM depo.stok_adres_palet_vw p
JOIN bkm.UrunBilgi u ON u.stkID = p.stkID
WHERE u.Kat1='Defterler'
GROUP BY p.adrsAlanTipID ORDER BY p.adrsAlanTipID;
-- ÖLÇÜLDÜ: RAF 456.337 (2.512 çeşit) · GİRİŞ 26.763 · ÇIKIŞ 41.835
--          RAF+GİRİŞ = 483.100 adet arkada duruyor

/* ---------------------------------------------------------------- BLOK 6
   SİMETRİK kuru-girdi oranı: 31.08 stoğu <= 0 iken ÖNCEKİ yıl sezon talebi > 0
   ⚠ Bu blok bir SAHTE BULGUYU ÖLDÜRDÜ. İlk kurguda 2025 için AYNI-yıl, 2026
   için ÖNCEKİ-yıl talebi kullanılmıştı → "kuru çeşit 336 → 1.239, 3,7 kat"
   diye alarm çıkıyordu. Metrik simetrik hale getirilince oran SABİT çıktı.
   2025 için: Donem='20250831', talep penceresi 20240725..20241009 */
SELECT SUM(CASE WHEN m.Stok<=0 THEN 1 ELSE 0 END) kuru_hucre,
       COUNT(*) talepli_hucre,
       SUM(CASE WHEN m.Stok<=0 THEN d.adet ELSE 0 END) kuru_onceki_talep,
       SUM(d.adet) onceki_talep_tum
FROM (SELECT ehMekan, stkID, Stok FROM bkm.StokAyBakiyeMekanBazli
      WHERE Donem='20260831' AND Kaynak='irsHrk' AND ehMekan IN (1,4477,4478)) m
JOIN bkm.UrunBilgi u ON u.stkID = m.stkID AND u.Kat1='Defterler'
JOIN (SELECT h.ehMekan, h.ehstkID, -SUM(h.ehAdetN) adet
      FROM dbo.irsHrk h
      WHERE h.ehTip IN (4,5,100,101) AND h.ehMekan IN (1,4477,4478)
        AND h.ehTrhS >= '20250725' AND h.ehTrhS < '20251009'
      GROUP BY h.ehMekan, h.ehstkID) d
  ON d.ehMekan = m.ehMekan AND d.ehstkID = m.stkID AND d.adet > 0;
-- ÖLÇÜLDÜ: 2025 973/5.190 = %18,7 · 2026 1.239/6.343 = %19,5 → DEĞİŞMEDİ

/* ---------------------------------------------------------------- BLOK 7
   SKU-MAĞAZA AÇIĞI (aksiyon listesi) — bugünkü stok vs beklenen kalan sezon
   beklenen = geçen yıl AYNI SKU-mağaza T+0..T+30 adedi × 1,11 (hizalı büyüme)
   CANLI süzgeci: depoda stok VAR ya da 2026 ön-sezonda SATMIŞ
     (yoksa 2025 tasarımı bırakılmış olabilir — "başka ne olabilir?" kapısı) */
SELECT t.ehMekan, t.stkID, u.stkAd, u.Kat2, u.mrkAd,
       CAST(t.beklenen AS int) beklenen, CAST(t.stok AS int) stok,
       CAST(t.acik AS int) acik, CAST(t.depo AS int) depo,
       CAST(t.gs26 AS int) onsezon26,
       CAST(t.acik*u.SonAlis AS decimal(18,2)) acik_maliyet
FROM (
  SELECT d.ehMekan, d.ehstkID stkID, d.adet*1.11 beklenen,
         ISNULL(s.st,0) stok, d.adet*1.11 - ISNULL(s.st,0) acik,
         ISNULL(w.st,0) depo, ISNULL(g.adet,0) gs26
  FROM (SELECT h.ehMekan, h.ehstkID, -SUM(h.ehAdetN) adet FROM dbo.irsHrk h
        WHERE h.ehTip IN (4,5,100,101) AND h.ehMekan IN (1,4477,4478)
          AND h.ehTrhS >= '20250908' AND h.ehTrhS < '20251009'
        GROUP BY h.ehMekan, h.ehstkID) d
  LEFT JOIN (SELECT v.ehMekan, v.ehstkID, SUM(v.stok) st FROM dbo.stokSonAltDepo_vw v
             WHERE v.ehMekan IN (1,4477,4478) GROUP BY v.ehMekan, v.ehstkID) s
    ON s.ehMekan = d.ehMekan AND s.ehstkID = d.ehstkID
  LEFT JOIN (SELECT p.stkID, SUM(p.Stok) st FROM depo.stok_adres_palet_vw p
             WHERE p.adrsAlanTipID IN (0,1) GROUP BY p.stkID) w ON w.stkID = d.ehstkID
  LEFT JOIN (SELECT h.ehstkID, -SUM(h.ehAdetN) adet FROM dbo.irsHrk h
             WHERE h.ehTip IN (4,5,100,101) AND h.ehMekan IN (1,4477,4478)
               AND h.ehTrhS >= '20260731' AND h.ehTrhS < '20260915'
             GROUP BY h.ehstkID) g ON g.ehstkID = d.ehstkID
  WHERE d.adet > 0
) t
JOIN bkm.UrunBilgi u ON u.stkID = t.stkID AND u.Kat1='Defterler'
WHERE t.acik > 0 AND (t.depo > 0 OR t.gs26 > 0)
ORDER BY t.acik*u.SonAlis DESC;
-- ÖLÇÜLDÜ: canlı açık 1.584 hücre / 25.332 adet / 1,44M ₺ (sabit fiyat)
--          858 hücrede depoda stok var → 12.180 adet TRANSFERLE kapanabilir
--          ölü/bırakılmış 626 hücre / 3.377 adet (aksiyon gerektirmez)

/* ---------------------------------------------------------------- BLOK 8
   AÇIĞIN TERSİ: bugünkü şube stoğunun ne kadarı zirve 45 günde HİÇ satmayan
   SKU'da duruyor (fazla/atıl taraf — açıkla birlikte okunur) */
SELECT s.ehMekan, SUM(s.st) toplam_stok,
       SUM(CASE WHEN ISNULL(g.adet,0)<=0 THEN s.st ELSE 0 END) satmayan_stok,
       SUM(CASE WHEN ISNULL(g.adet,0)<=0 THEN 1 ELSE 0 END)    satmayan_cesit,
       SUM(CASE WHEN ISNULL(g.adet,0)<=0 THEN s.st*u.SonAlis ELSE 0 END) satmayan_maliyet,
       COUNT(*) cesit
FROM (SELECT v.ehMekan, v.ehstkID, SUM(v.stok) st FROM dbo.stokSonAltDepo_vw v
      WHERE v.ehMekan IN (1,4477,4478) GROUP BY v.ehMekan, v.ehstkID
      HAVING SUM(v.stok) > 0) s
JOIN bkm.UrunBilgi u ON u.stkID = s.ehstkID AND u.Kat1='Defterler'
LEFT JOIN (SELECT h.ehMekan, h.ehstkID, -SUM(h.ehAdetN) adet FROM dbo.irsHrk h
           WHERE h.ehTip IN (4,5,100,101) AND h.ehMekan IN (1,4477,4478)
             AND h.ehTrhS >= '20260731' AND h.ehTrhS < '20260915'
           GROUP BY h.ehMekan, h.ehstkID) g
  ON g.ehMekan = s.ehMekan AND g.ehstkID = s.ehstkID
GROUP BY s.ehMekan ORDER BY s.ehMekan;
-- ÖLÇÜLDÜ: 66.487 adet / 3,13M ₺ (şube stoğunun %37,9) zirve 45 günde hiç satmadı
--          FSM %48,8 · Özlüce %37,3 · İst.Yolu %26,8

/* ============================================================================
   SONUÇ (14.09.2026)
   · Grup toplamında stok YETERLİ: 176.231 şube + 483.100 depo vs beklenen
     kalan sezon 68.645 adet → kapak 2,57x (g=1,00'da 2,85 · g=1,50'de 1,90)
   · Ama SEZONA %9,5 DAHA AZ STOKLA girildi, talep +%11 → giriş kapağı
     1,56 → 1,22 (−%22). Derinlik düştü, çeşit arttı.
   · Sorun HACİM değil DAĞITIM: 25.332 adet canlı açık ile 66.487 adet
     satmayan stok AYNI ANDA duruyor.
   ⚠ SINIR: kayıp satış SAĞDAN SANSÜRLÜ (stok bitince satış kesilir) → geçen
     yılın talebi ALT SINIRDIR. SKU düzeyinde tek yıldan tahmin gürültülüdür
     (defter tasarımı yıllık döner) — liste ÖNCELİK sırası, sipariş emri değil.
============================================================================ */
