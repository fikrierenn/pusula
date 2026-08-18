/*
  Soru: Satınalma "Alım Analizi" Temmuz 2026'da FAZLA listesini dolduran Serve Deep kalem
        kümesi TEK sipariş mi, yoksa tekrarlayan alım mı?
  DB: DerinSISBkm. Kaynak: dbo.irsHrk (alım ehTip 0/10, ehAdetN>0) × dbo.irs (evrak başlık) × dbo.frm (tedarikçi).
  Köprüler: irshrk-irs (ehID=eID) · irs-firma (irs.eFirma=frm.frmID) — sema/bridges.yaml.

  BULGU:
   1) Temmuz 2026 Serve Deep alımı = TEK evrak: eNo 007287 · 10.07.2026 · Merkez Depo (mekan 12)
      · tedarikçi PROMARKA KIRTASİYE (frmID 188) · 50 SKU · 5.040 adet · 985.089,60 ₺ net (KDV hariç)
      · giren kişi SAMET TILCI (insID 697) · onay=1.
      → Temmuz'un 31,4M ₺ toplam alımının %3,1'i; "materyal fazla" 3,4M ₺ bağlı paranın ~%29'u.
   2) Küme TEK SEFERLİK DEĞİL — 2026'da 5 ayda tekrar alındı:
      Şub 324 ad / 58K ₺ · Mar 12.660 / 1,41M · Nis 3.305 / 666K · Haz 8.952 / 1,74M · Tem 5.040 / 985K
      = 30.281 adet ≈ 4,86M ₺ (6 ay). 2025'te de 12 ayın 10'unda alım var.
   3) EN SERT KANIT — Harry Potter 8 varyantı (stkID 1701937-1701944):
      ilk alım 13.03.2026, o günden beri 6-8 ayrı evrak, varyant başına 510-732 adet toplam alım;
      son 12 ay satış yalnız 46-89 adet → ay-kapsam 80-152 ay. Tekrarlayan alım, satış yok.
   4) Mevcut renk varyantları (metalik/doğa/fosforlu): ay-kapsam 13-59 ay.

  METODOLOJİ NOTU (overclaim guard):
   - son12 satış = ehTip IN (1,4,100) ham toplam; retail-cap UYGULANMADI, iade (3,5,101) netlenMEDİ
     → dashboard'ın "Son12" kolonundan küçük sapma olabilir.
   - stok_31tem = irsHrk kümülatif (ehTrhS<'20260801', ehAltDepo=0, mekan 1/4477/4478/12) → Temmuz alımı DAHİL.
   - MIN(CONVERT(varchar,...,104)) STRING min verir (yanıltıcı '01.06.2026') → tarih MIN'i daima
     MIN(ehTrhS) üzerinden alınmalı. Gerçek ilk alım 13.03.2026.
*/

-- 1) Temmuz 2026 Serve Deep alımı — evrak kırılımı (tek satır çıkarsa tek sipariş)
SELECT i.eNo,
       CONVERT(varchar, i.eTarihS, 104) AS evrak_tarih,
       h.ehTip, h.ehMekan,
       i.eFirma, fr.frmAd AS tedarikci,
       k.insAd  AS giren_kisi, i.onay,
       COUNT(DISTINCT h.ehstkID) AS urun_cesit,
       SUM(h.ehAdetN)            AS adet,
       SUM(h.ehTutarN)           AS tutar_net
FROM dbo.irsHrk h WITH(NOLOCK)
JOIN dbo.irs   i  WITH(NOLOCK) ON i.eID = h.ehID
JOIN dbo.urn   u  WITH(NOLOCK) ON u.stkID = h.ehstkID
LEFT JOIN dbo.frm  fr WITH(NOLOCK) ON fr.frmID = i.eFirma
LEFT JOIN dbo.drn1 k  WITH(NOLOCK) ON k.insID  = i.gKisi
WHERE h.ehTip IN (0,10)                    -- alış + yerel alım (giriş → ehAdetN POZİTİF)
  AND h.ehTrhS >= '20260701' AND h.ehTrhS < '20260801'
  AND h.ehAdetN > 0
  AND u.stkAd LIKE '%Serve Deep%'
GROUP BY i.eNo, i.eTarihS, h.ehTip, h.ehMekan, i.eFirma, fr.frmAd, k.insAd, i.onay
ORDER BY SUM(h.ehTutarN) DESC;

-- 2) Küme tekrar ediyor mu — ay bazlı alım (evrak sayısı + tedarikçi sayısı)
SELECT YEAR(h.ehTrhS)*100 + MONTH(h.ehTrhS) AS yilay,
       COUNT(DISTINCT i.eNo)    AS evrak_sayi,
       COUNT(DISTINCT i.eFirma) AS tedarikci_sayi,
       COUNT(DISTINCT h.ehstkID) AS sku,
       SUM(h.ehAdetN)  AS adet,
       SUM(h.ehTutarN) AS tutar_net
FROM dbo.irsHrk h WITH(NOLOCK)
JOIN dbo.irs i WITH(NOLOCK) ON i.eID = h.ehID
JOIN dbo.urn u WITH(NOLOCK) ON u.stkID = h.ehstkID
WHERE h.ehTip IN (0,10) AND h.ehAdetN > 0
  AND h.ehTrhS >= '20250101' AND h.ehTrhS < '20260801'
  AND u.stkAd LIKE '%Serve Deep%'
GROUP BY YEAR(h.ehTrhS)*100 + MONTH(h.ehTrhS)
ORDER BY 1 DESC;

-- 3) Evrak 007287'nin 50 kaleminin hesap-sorma tablosu: alınan / son12 satış / ay sonu stok / ay-kapsam
WITH alim AS (
    SELECT h.ehstkID AS stkID, SUM(h.ehAdetN) AS alinan, SUM(h.ehTutarN) AS tutar
    FROM dbo.irsHrk h WITH(NOLOCK)
    JOIN dbo.irs i WITH(NOLOCK) ON i.eID = h.ehID
    WHERE i.eNo = '007287'
      AND h.ehTip IN (0,10)
      AND h.ehTrhS >= '20260701' AND h.ehTrhS < '20260801'
      AND h.ehAdetN > 0
    GROUP BY h.ehstkID
),
satis12 AS (   -- ham son12 (retail-cap YOK, iade netlenmedi — bkz. metodoloji notu)
    SELECT s.ehstkID, SUM(-s.ehAdetN) AS son12
    FROM dbo.irsHrk s WITH(NOLOCK)
    WHERE s.ehTip IN (1,4,100)
      AND s.ehTrhS >= '20250801' AND s.ehTrhS < '20260801'
      AND s.ehstkID IN (SELECT stkID FROM alim)
    GROUP BY s.ehstkID
),
stok AS (      -- ay sonu stok = kümülatif (Temmuz alımı dahil), şube + merkez depo
    SELECT t.ehstkID, SUM(t.ehAdetN) AS stok
    FROM dbo.irsHrk t WITH(NOLOCK)
    WHERE t.ehTrhS < '20260801'
      AND t.ehAltDepo = 0
      AND t.ehMekan IN (1, 4477, 4478, 12)
      AND t.ehstkID IN (SELECT stkID FROM alim)
    GROUP BY t.ehstkID
),
ilk AS (       -- ürünün İLK alım tarihi (tekrar-alım tespiti; string MIN kullanma!)
    SELECT f.ehstkID, MIN(f.ehTrhS) AS ilk_alim, COUNT(DISTINCT i2.eNo) AS toplam_evrak,
           SUM(f.ehAdetN) AS tum_zaman_alinan
    FROM dbo.irsHrk f WITH(NOLOCK)
    JOIN dbo.irs i2 WITH(NOLOCK) ON i2.eID = f.ehID
    WHERE f.ehTip IN (0,10) AND f.ehAdetN > 0
      AND f.ehstkID IN (SELECT stkID FROM alim)
    GROUP BY f.ehstkID
)
SELECT a.stkID, u.stkAd,
       a.alinan, a.tutar,
       ISNULL(s.son12, 0)  AS son12_satis,
       ISNULL(st.stok, 0)  AS stok_31tem,
       CASE WHEN ISNULL(s.son12,0) = 0 THEN 999
            ELSE ROUND(ISNULL(st.stok,0) * 12.0 / s.son12, 1) END AS ay_kapsam,
       CONVERT(varchar, il.ilk_alim, 104) AS ilk_alim,
       il.toplam_evrak, il.tum_zaman_alinan
FROM alim a
JOIN dbo.urn u WITH(NOLOCK) ON u.stkID = a.stkID
LEFT JOIN satis12 s  ON s.ehstkID  = a.stkID
LEFT JOIN stok    st ON st.ehstkID = a.stkID
LEFT JOIN ilk     il ON il.ehstkID = a.stkID
ORDER BY a.tutar DESC;

/* ---------------------------------------------------------------------------
   4) HARRY POTTER KÜMESİ (stkID 1701937-1701944) — EVRAK DÖKÜMÜ
   Bulgu: 13.03.2026 → 03.08.2026 arası 8 evrak, 3 farklı tedarikçi
          (BETA KİTAP · PROMARKA · BUDAK KAĞIT), hepsi Merkez Depo (12),
          hepsini giren SAMET TILCI, hepsi onay=1, birim 226,11-233,10 ₺.
          Toplam 5.064 adet / 1.177.397 ₺ net.
   Sipariş adedi ARTARAK gitti (192 → 240 → 744 → 936 → 720 → 432 → 1.440 → 360)
   ama satış Mayıs zirvesinden (203) sonra ÇÖKTÜ (Haz 58 · Tem 23 · Ağu 35).
   → Talep sinyali düşerken sipariş büyütülmüş = klasik ratchet.
--------------------------------------------------------------------------- */
SELECT i.eNo,
       CONVERT(varchar, i.eTarihS, 104) AS evrak_tarih,
       fr.frmAd AS tedarikci,
       k.insAd  AS giren,
       i.eMekan, i.onay,
       COUNT(DISTINCT h.ehstkID) AS varyant,
       SUM(h.ehAdetN)  AS adet,
       SUM(h.ehTutarN) AS tutar_net,
       ROUND(SUM(h.ehTutarN) / NULLIF(SUM(h.ehAdetN),0), 2) AS birim_net
FROM dbo.irsHrk h WITH(NOLOCK)
JOIN dbo.irs i WITH(NOLOCK) ON i.eID = h.ehID
LEFT JOIN dbo.frm  fr WITH(NOLOCK) ON fr.frmID = i.eFirma
LEFT JOIN dbo.drn1 k  WITH(NOLOCK) ON k.insID  = i.gKisi
WHERE h.ehTip IN (0,10) AND h.ehAdetN > 0
  AND h.ehstkID BETWEEN 1701937 AND 1701944
GROUP BY i.eNo, i.eTarihS, fr.frmAd, k.insAd, i.eMekan, i.onay
ORDER BY i.eTarihS;

-- 5) HP kümesi ay bazlı alım vs satış (ratchet kanıtı — sipariş büyürken satış düşüyor)
SELECT YEAR(h.ehTrhS)*100 + MONTH(h.ehTrhS) AS yilay,
       SUM(CASE WHEN h.ehTip IN (0,10) AND h.ehAdetN > 0 THEN h.ehAdetN ELSE 0 END) AS alim_adet,
       SUM(CASE WHEN h.ehTip IN (1,4,100) THEN -h.ehAdetN ELSE 0 END)               AS satis_adet,
       SUM(CASE WHEN h.ehTip IN (3,5,101) THEN -h.ehAdetN ELSE 0 END)               AS iade_adet
FROM dbo.irsHrk h WITH(NOLOCK)
WHERE h.ehstkID BETWEEN 1701937 AND 1701944
  AND h.ehTrhS >= '20260301'
GROUP BY YEAR(h.ehTrhS)*100 + MONTH(h.ehTrhS)
ORDER BY 1;
