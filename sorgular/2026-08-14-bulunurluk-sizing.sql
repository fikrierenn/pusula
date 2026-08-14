/*
  BULUNURLUK (On-Shelf Availability) SIZING PROBE — plan-33 Faz 0
  Soru: Kat3 (10=Hediyelik/12=Kırtasiye/16=Oyuncak) son 12 ay (2025-08..2026-07) SATAN SKU'ların
        kaç şubede (FSM=1/Özlüce=4477/İst.Yolu=4478) raf stoğu (≥3) vardı? Kısmi-dağıtım = kayıp-satış riski.
  DB: DerinSISBkm. Kaynak: bkm.StokAyBakiyeMekanBazli (şube×ay stok) × dbo.irsHrk (satış ehTip 1/4/100).
  BULGU (2026-08-14):
    - HAM (Q1/Q2, sadece pencere satırı MAX): aktif 42.744 · tam 15.486 · kısmi 16.238 · kaba kayıp ~377K.
    - CARRY-IN DÜZELTİLMİŞ (Q3, DOĞRU): tam 18.783 · KISMİ 15.802 (%37) · kaba kayıp ~263.336 adet.
    - Sorun SİSTEMİK → plan-33 haklı; carry-in ile ~%30 küçüldü ama hâlâ yüz binlerce adet.

  TABLO SEMANTİĞİ (KOD-DOĞRULANDI — 2026-08-12-stok-ay-bakiye-mekan-tablo.sql):
   Stok kolonu = ay-SONU BAKİYESİ (kümülatif running-total, ehAltDepo=0 filtreli, negatif→0 floor).
   HAREKET TOPLAMI DEĞİL. 591060 mekan-1 tabloyla ehAltDepo=0 kümülatif BİREBİR (193/189/157/131/118/72/59).
   (İlk uyuşmazlık benim check'imin ehAltDepo=0 filtresini atlamasındandı — tablo doğru.)

  İKİ TUZAK (ikisi de doğrulandı, motor bunları çözecek):
   (A) SATIRLAR SADECE HAREKETLİ AYLARA yazılır (snapshot değil) → hareketsiz ay satır yok (591060 FSM
       2026-H1'de 59 tuttu, 0 satır; 2025'te 12 değil 7 ay). Q1/Q2 "pencere MAX satırı" bunu KURU sanıp ŞİŞİRİR.
       → Q3 CARRY-IN: giriş bakiyesi (önceki son satır ≥3) de "stoklu" sayılır (tablo lookup deseni: Donem<=@ay DESC).
   (B) AY-SONU bakiyesi: stok ayın son günü girdiyse ay-sonu "stoklu" der ama o ay satış imkânı ~0 → ŞİŞİRİR
       (A'nın tersi). Doğru tanım: şube M'de "bulunur" = M-1 AY-SONU bakiyesi ≥ min-stok (aya stokla girdi).
       Motor same-month-end DEĞİL GİRİŞ-bakiyesi kullanır. (Sizing Q3 carry-in bunu yaklaşık verir.)
  NOT: kayıp üst-sınır — eksik-şube aynı hızda satar varsayımı (kasıtlı-assortment / mağaza-boyut / kanibalizasyon hariç).
       Gerçek motor 3 filtre daraltır: "geçmişte-taşımış" + mağaza-boyut normalizasyon + online-kanal (mekan 12) ayrımı.
*/

-- 1) Dağılım: satan SKU kaç şubede stoklu (≥3 raf)?
SELECT
  COUNT(*) AS aktif_sku,
  SUM(CASE WHEN stoklu_sube=0 THEN 1 ELSE 0 END) AS sfr_sube_stoklu,   -- satan ama hiç raf yok (online/churn)
  SUM(CASE WHEN stoklu_sube=1 THEN 1 ELSE 0 END) AS tek_sube,
  SUM(CASE WHEN stoklu_sube=2 THEN 1 ELSE 0 END) AS iki_sube,
  SUM(CASE WHEN stoklu_sube=3 THEN 1 ELSE 0 END) AS uc_sube,
  SUM(CASE WHEN stoklu_sube IN (1,2) THEN satis ELSE 0 END) AS kismi_dagitim_satis,
  SUM(satis) AS toplam_satis
FROM (
  SELECT s.stkID, s.satis, ISNULL(g.stoklu_sube,0) AS stoklu_sube
  FROM (
    SELECT ehstkID AS stkID, CONVERT(int,SUM(-ehAdetN)) AS satis
    FROM dbo.irsHrk WITH(NOLOCK)
    WHERE ehTip IN (1,4,100) AND ehTrhS>='20250801' AND ehTrhS<'20260801'
      AND ehstkID IN (SELECT StkID FROM bkm.UrunBilgi WHERE Kat3ID IN (10,12,16))
    GROUP BY ehstkID HAVING SUM(-ehAdetN)>0
  ) s
  LEFT JOIN (
    SELECT stkID, SUM(CASE WHEN mx>=3 THEN 1 ELSE 0 END) AS stoklu_sube
    FROM (
      SELECT stkID, ehMekan, MAX(Stok) AS mx
      FROM bkm.StokAyBakiyeMekanBazli WITH(NOLOCK)
      WHERE Kaynak='irsHrk' AND ehMekan IN (1,4477,4478) AND Donem>='20250801' AND Donem<'20260801'
      GROUP BY stkID, ehMekan
    ) t GROUP BY stkID
  ) g ON g.stkID=s.stkID
) q;

-- 2) Kaba kayıp-satış (kısmi-dağıtım SKU'lar tam dağıtılsa — eksik-şube × şube-başı hız). ÜST-SINIR.
SELECT
  COUNT(*) AS kismi_sku,
  SUM(satis) AS gorunur_satis,
  CONVERT(bigint, SUM(1.0*satis*(3-stoklu_sube)/stoklu_sube)) AS tahmini_kayip_adet
FROM (
  SELECT s.stkID, s.satis, g.stoklu_sube
  FROM (
    SELECT ehstkID AS stkID, CONVERT(int,SUM(-ehAdetN)) AS satis
    FROM dbo.irsHrk WITH(NOLOCK)
    WHERE ehTip IN (1,4,100) AND ehTrhS>='20250801' AND ehTrhS<'20260801'
      AND ehstkID IN (SELECT StkID FROM bkm.UrunBilgi WHERE Kat3ID IN (10,12,16))
    GROUP BY ehstkID HAVING SUM(-ehAdetN)>0
  ) s
  JOIN (
    SELECT stkID, SUM(CASE WHEN mx>=3 THEN 1 ELSE 0 END) AS stoklu_sube
    FROM (SELECT stkID, ehMekan, MAX(Stok) AS mx FROM bkm.StokAyBakiyeMekanBazli WITH(NOLOCK)
          WHERE Kaynak='irsHrk' AND ehMekan IN (1,4477,4478) AND Donem>='20250801' AND Donem<'20260801'
          GROUP BY stkID, ehMekan) t GROUP BY stkID
  ) g ON g.stkID=s.stkID
  WHERE g.stoklu_sube IN (1,2)
) q;

-- 3) CARRY-IN DÜZELTİLMİŞ (DOĞRU — Q1/Q2 hareketsiz-stok şubeleri kuru sanıyordu). Bir şube "stoklu" =
--    pencerede satır MAX≥3 VEYA pencereye giriş bakiyesi (önceki son satır) ≥3. Sonuç: kısmi 15.802, kayıp ~263K.
SELECT
  COUNT(*) aktif_sku,
  SUM(CASE WHEN stoklu=0 THEN 1 ELSE 0 END) s0, SUM(CASE WHEN stoklu=1 THEN 1 ELSE 0 END) s1,
  SUM(CASE WHEN stoklu=2 THEN 1 ELSE 0 END) s2, SUM(CASE WHEN stoklu=3 THEN 1 ELSE 0 END) s3,
  SUM(CASE WHEN stoklu IN (1,2) THEN satis ELSE 0 END) kismi_satis,
  CONVERT(bigint, SUM(CASE WHEN stoklu IN (1,2) THEN 1.0*satis*(3-stoklu)/stoklu ELSE 0 END)) kayip_adet
FROM (
  SELECT s.stkID, s.satis, ISNULL(av.stoklu,0) stoklu
  FROM (
    SELECT ehstkID stkID, CONVERT(int,SUM(-ehAdetN)) satis
    FROM dbo.irsHrk WITH(NOLOCK)
    WHERE ehTip IN (1,4,100) AND ehTrhS>='20250801' AND ehTrhS<'20260801'
      AND ehstkID IN (SELECT StkID FROM bkm.UrunBilgi WHERE Kat3ID IN (10,12,16))
    GROUP BY ehstkID HAVING SUM(-ehAdetN)>0
  ) s
  LEFT JOIN (
    SELECT stkID, COUNT(DISTINCT mekan) stoklu
    FROM (
      SELECT stkID, ehMekan mekan FROM bkm.StokAyBakiyeMekanBazli WITH(NOLOCK)
      WHERE Kaynak='irsHrk' AND ehMekan IN (1,4477,4478) AND Donem>='20250801' AND Donem<'20260801'
        AND stkID IN (SELECT StkID FROM bkm.UrunBilgi WHERE Kat3ID IN (10,12,16))
      GROUP BY stkID, ehMekan HAVING MAX(Stok)>=3
      UNION
      SELECT stkID, ehMekan FROM (
        SELECT stkID, ehMekan, Stok, ROW_NUMBER() OVER (PARTITION BY stkID,ehMekan ORDER BY Donem DESC) rn
        FROM bkm.StokAyBakiyeMekanBazli WITH(NOLOCK)
        WHERE Kaynak='irsHrk' AND ehMekan IN (1,4477,4478) AND Donem<'20250801'
          AND stkID IN (SELECT StkID FROM bkm.UrunBilgi WHERE Kat3ID IN (10,12,16))
      ) z WHERE rn=1 AND Stok>=3
    ) u GROUP BY stkID
  ) av ON av.stkID=s.stkID
) q;
