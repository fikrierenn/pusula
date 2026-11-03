/*
  DÖNEM BAŞI STOK — anlık stoktan GERİ GİDEREK (DerinSISBkm)
  Soru: ODAK hesap-sorma için "alış öncesi zaten şişik stok var mıydı?" — 01.08.2026 itibarıyla stok.
  Dönem başı snapshot (bkm.StokAyBakiyeMekanBazli 2026-07-31) MERKEZ DEPO (12) içermiyor (WMS job koşmamış),
  o yüzden anlık stoktan net hareketi düşerek geri gidilir.

  BULGU (canlı doğrulandı 2026-11-03):
    MAĞAZA (1/4477/4478): stok_T1 = stokSon_vw anlık − SUM(irsHrk.ehAdetN WHERE ehTrhS>=T1)
      Doğrulama vs 2026-07-31 snapshot: FSM 947.206 vs 965.196 (−%1,9) · Özlüce 1.411.831 vs 1.425.761 (−%1,0) ·
      İst.Yolu 1.698.093 vs 1.710.372 (−%0,7). İkisi de irsHrk-türevi → ~%1 ikiz, kabul.
    MERKEZ DEPO (12): stok_T1 = WMS anlık (depo.stok_adres_palet_vw) − SUM(paletIcHrk.piAdet WHERE pikTarih>=T1)
      ⭐ paletIcHrk.piAdet ZATEN İŞARETLİ: giriş pGC=0 → +, çıkış pGC=1 → −. SUM(piAdet) = NET.
      ⭐ İç palet transferleri (palet→palet) net'te BİRBİRİNİ GÖTÜRÜR: tüm-zaman gross giriş 55,1M / çıkış 53,8M
        iken net yalnız 1,34M. Yani SUM(piAdet) = sınır-geçen (mal kabul − sevk) net hareket.
      ⚠ paletIcHrk SIFIRDAN BAŞLAMIYOR: tüm-zaman net 1,34M ≠ WMS anlık 4,07M (loglama öncesi açılış ~2,7M).
        Bu yüzden sıfırdan toplanmaz; yalnız KISA PENCERE geri-gitmede geçerli (pencere hareketleri tam loglanır).
      Sanity (01.08→03.11): WMS anlık 4.067.522 − net(−1.060.897) = WMS_T1 5.128.419 (depo Ağustos'ta daha büyüktü,
        net 1,06M sevk çıktı → şimdi 4,07M). Pozitif, mantıklı.
    Dönem başı negatif çıkarsa (ürün T1'de yoktu / defter gürültüsü) → 0'a sabitlenir.
  Üretim: scripts/odak_hesapsorma_analiz.py → raporlar/odak-hesapsorma-*.xlsx (Dönem Başı Stok + Kalan Stok + Sell-through)
*/

-- 1) MAĞAZA dönem başı doğrulama: rekonstrüksiyon vs 2026-07-31 snapshot
SELECT n.ehMekan, n.stok_now, ISNULL(h.net_hrk,0) net_since_t1,
       n.stok_now - ISNULL(h.net_hrk,0) AS rekon_T1, s.snapshot_T1
FROM (SELECT ehMekan, SUM(stok) stok_now FROM dbo.stokSon_vw WITH(NOLOCK)
      WHERE ehMekan IN (1,4477,4478) GROUP BY ehMekan) n
LEFT JOIN (SELECT ehMekan, SUM(ehAdetN) net_hrk FROM dbo.irsHrk WITH(NOLOCK)
           WHERE ehMekan IN (1,4477,4478) AND ehTrhS>='20260801' GROUP BY ehMekan) h ON h.ehMekan=n.ehMekan
LEFT JOIN (SELECT ehMekan, SUM(Stok) snapshot_T1 FROM bkm.StokAyBakiyeMekanBazli WITH(NOLOCK)
           WHERE Donem='2026-07-31' GROUP BY ehMekan) s ON s.ehMekan=n.ehMekan;

-- 2) MERKEZ DEPO (12) WMS geri-gitme: piAdet işaret + iç transfer net kanıtı
SELECT w.wms_now,
       SUM(CASE WHEN p.pGC=0 THEN p.piAdet ELSE 0 END) gross_giris,
       SUM(CASE WHEN p.pGC=1 THEN p.piAdet ELSE 0 END) gross_cikis,  -- piAdet zaten negatif
       SUM(p.piAdet) net_all_time                                    -- ≠ wms_now (sıfırdan başlamıyor)
FROM (SELECT SUM(Stok) wms_now FROM depo.stok_adres_palet_vw WITH(NOLOCK)) w
CROSS JOIN depo.paletIcHrk p WITH(NOLOCK)
GROUP BY w.wms_now;

-- 3) MERKEZ DEPO dönem başı sanity (kısa pencere geri-gitme)
SELECT w.wms_now, ISNULL(p.net_t1,0) net_since_t1, w.wms_now - ISNULL(p.net_t1,0) AS wms_rekon_T1
FROM (SELECT SUM(Stok) wms_now FROM depo.stok_adres_palet_vw WITH(NOLOCK)) w
CROSS JOIN (SELECT SUM(piAdet) net_t1 FROM depo.paletIcHrk WITH(NOLOCK) WHERE pikTarih>='20260801') p;
