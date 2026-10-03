-- Ay sonu stok kaynak mutabakatı (DerinSISBkm) — 03.10.2026
-- Soru: "Ay Sonu Stok ve Satış Raporu" için mağaza stoğu geçmiş bir ayın sonu itibarıyla kurulabilir mi?
-- Bulgu (Kat3 10/12/16): irsHrk defteri (ehAltDepo=0) bugüne kadar ≈ stokSon_vw, mekan başına fark ≤3 adet
--   FSM 654.121,82 / 654.124,82 · Özlüce 796.189,88 / 796.190,88 · İst.Yolu 600.380,2 / 600.381,2
--   ⇒ şube ay-sonu = irsHrk, ehTrhS < ertesi ayın 1'i. Depo (mekan 12): defter 3.146.771 vs WMS 2.790.350 →
--   depo defterden OKUNMAZ, WMS anlık kalır (sql-server-conventions § MERKEZ DEPO STOĞU = HER ZAMAN WMS).
-- Uygulama: scripts/stok_satis_aylik_wide.py --ay=YYYY-MM

-- 1) Defter, bugüne kadar
SELECT 'irsHrk_simdi' AS kaynak, h.ehMekan, SUM(h.ehAdetN) AS adet
FROM dbo.irsHrk h WITH(NOLOCK)
JOIN bkm.UrunBilgi u WITH(NOLOCK) ON u.stkID = h.ehstkID AND u.Kat3ID IN (10,12,16)
WHERE h.ehMekan IN (1,4477,4478,12) AND h.ehAltDepo = 0
GROUP BY h.ehMekan;

-- 2) Defter, 30.09.2026 sonu itibarıyla
SELECT 'irsHrk_30eyl' AS kaynak, h.ehMekan, SUM(h.ehAdetN) AS adet
FROM dbo.irsHrk h WITH(NOLOCK)
JOIN bkm.UrunBilgi u WITH(NOLOCK) ON u.stkID = h.ehstkID AND u.Kat3ID IN (10,12,16)
WHERE h.ehMekan IN (1,4477,4478,12) AND h.ehAltDepo = 0 AND h.ehTrhS < '20261001'
GROUP BY h.ehMekan;

-- 3) Anlık stok view'ı
SELECT 'stokSon_vw' AS kaynak, s.ehMekan, SUM(s.stok) AS adet
FROM dbo.stokSon_vw s WITH(NOLOCK)
JOIN bkm.UrunBilgi u WITH(NOLOCK) ON u.stkID = s.ehstkID AND u.Kat3ID IN (10,12,16)
WHERE s.ehMekan IN (1,4477,4478,12)
GROUP BY s.ehMekan;

-- 4) WMS anlık (RAF + GİRİŞ)
SELECT 'WMS' AS kaynak, 12 AS ehMekan, SUM(w.Stok) AS adet
FROM depo.stok_adres_palet_vw w WITH(NOLOCK)
JOIN bkm.UrunBilgi u WITH(NOLOCK) ON u.stkID = w.stkID AND u.Kat3ID IN (10,12,16)
WHERE w.Stok > 0 AND w.adrsAlanTipID IN (0,1);
