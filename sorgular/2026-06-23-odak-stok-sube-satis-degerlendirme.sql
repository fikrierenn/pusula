/* ODAK stok × son-1-yıl şube satışı değerlendirme raporu (kategori bazlı)
   DB: DerinSISBkm (201) · Soru: ODAK depo stoğu yıllık şube satışına göre fazla/yetersiz mi (devir)?
   ⚠ Stok = KANONİK `ent.odak_depo_Stok` (ODAK e-tic fulfillment depo, stkID→StokMiktar) — kullanıcı 23.06: "odak stok = bu tablo".
     (Mağaza rafı/Merkez Depo değil; stokSonAltDepo_vw mekan 26142 İPTAL-Transfer transit, HARİÇ.)
   Satış = sadece 3 şube (1,4477,4478) · Devir = yıllık satış adet / ODAK stok adet  → <1 fazla stok, >3 hızlı dönen. */

WITH stk AS (   -- ODAK depo stoğu (kanonik tablo, kategori bazında)
  SELECT u.urnKtgr2ID, SUM(o.StokMiktar) AS StokAdet
  FROM ent.odak_depo_Stok o
  JOIN dbo.urn u ON u.stkID = o.stkID
  WHERE o.StokMiktar > 0
  GROUP BY u.urnKtgr2ID
),
sat AS (        -- son 12 ay şube satışı (ehTip 4=mağaza/100=POS satış; 3/5/101 iade negatif)
  SELECT u.urnKtgr2ID,
    -SUM(CASE WHEN h.ehTip IN (4,100) THEN h.ehAdetN ELSE 0 END) AS SatisAdet,   -- satış adet çıkış(-) → işaret çevir
    SUM(CASE WHEN h.ehTip IN (4,100) THEN h.ehTutarN
             WHEN h.ehTip IN (3,5,101) THEN -h.ehTutarN ELSE 0 END) AS NetCiro
  FROM dbo.irsHrk h
  JOIN dbo.urn u ON u.stkID = h.ehstkID
  WHERE h.ehTrhS >= DATEADD(YEAR, -1, GETDATE())
    AND h.ehMekan IN (1, 4477, 4478)        -- sadece şubeler
    AND h.ehAltDepo = 0
    AND h.ehTip IN (4, 100, 3, 5, 101)
  GROUP BY u.urnKtgr2ID
)
SELECT
  k.ktgrAd                                              AS Kategori,
  ISNULL(stk.StokAdet, 0)                               AS StokAdet,
  ISNULL(sat.SatisAdet, 0)                              AS YilSatisAdet,
  CAST(ISNULL(sat.NetCiro, 0) AS decimal(18,0))         AS YilNetCiro,
  CASE WHEN ISNULL(stk.StokAdet,0) > 0
       THEN CAST(1.0 * ISNULL(sat.SatisAdet,0) / stk.StokAdet AS decimal(10,2)) END AS Devir,
  CASE WHEN ISNULL(sat.SatisAdet,0) > 0
       THEN CAST(stk.StokAdet / (sat.SatisAdet / 12.0) AS decimal(10,1)) END         AS AyKapsam   -- stok kaç aylık satışa yeter
FROM dbo.urnKtgr2 k
LEFT JOIN stk ON stk.urnKtgr2ID = k.ktgrID
LEFT JOIN sat ON sat.urnKtgr2ID = k.ktgrID
WHERE (ISNULL(stk.StokAdet,0) > 0 OR ISNULL(sat.SatisAdet,0) > 0)
  AND k.ktgrAd NOT IN (N'Sınav Okulları', N'Hediye Çeki', N'Etkinlik', N'Zkargo', N'KARGO')
ORDER BY YilNetCiro DESC;


/* ── DRILL: Hazırlık Kitapları → YAYINEVİ (urnMrk) bazlı ODAK ölü-stok dökümü ──
   Stok = KANONİK `ent.odak_depo_Stok` (ODAK e-tic fulfillment depo) · Stok ₺ = ODAK adet × maliyet şelalesi (son-5 alış faturası fat5 → Aktarim ORT_ALIS → kategori fiyat-oran fallback).
   Satış = son 12 ay, 3 şube · Devir = yıl şube satış adet / ODAK stok adet. Risk = yüksek StokTl + düşük Devir. */
WITH urunler AS (
  SELECT u.stkID, u.urnMrkID,
    CAST(o.StokMiktar AS int) AS Stok,
    COALESCE(fat5.Maliyet, ml.ORT_ALIS, CASE WHEN u.fiyatS>0 THEN u.fiyatS*avgml.AvgCostOran END) AS Maliyet
  FROM ent.odak_depo_Stok o
  JOIN dbo.urn u ON u.stkID=o.stkID
  JOIN dbo.urnKtgr2 k ON k.ktgrID=u.urnKtgr2ID AND k.ktgrAd=N'Hazırlık Kitapları'
  LEFT JOIN Aktarim.dbo.BKM_STOKLAR_MALIYETLI ml ON ml.STKID=u.stkID
  LEFT JOIN (SELECT u2.urnKtgr2ID ktgrID, AVG(CASE WHEN u2.fiyatS>0 THEN ml2.ORT_ALIS/u2.fiyatS END) AvgCostOran
             FROM Aktarim.dbo.BKM_STOKLAR_MALIYETLI ml2 JOIN dbo.urn u2 ON u2.stkID=ml2.STKID
             WHERE ml2.ORT_ALIS>0 AND u2.fiyatS>0 AND ml2.ORT_ALIS<u2.fiyatS GROUP BY u2.urnKtgr2ID) avgml ON avgml.ktgrID=u.urnKtgr2ID
  OUTER APPLY (SELECT CONVERT(money, SUM(b.ehTutarN)/SUM(b.ehAdetN)) Maliyet
               FROM (SELECT TOP 5 fa.ehAdetN, fa.ehTutarN FROM dbo.fatAyr fa
                     JOIN dbo.fat f ON fa.ehID=f.eID AND f.eTip=0 AND f.eDurum<>2
                     WHERE fa.ehstkID=u.stkID AND fa.ehAdetN<>0 ORDER BY f.eTarih DESC) b
               HAVING SUM(b.ehAdetN)<>0) fat5
  WHERE u.urnTip=0 AND o.StokMiktar>0
),
sat AS (
  SELECT u.urnMrkID,
    -SUM(CASE WHEN h.ehTip IN (4,100) THEN h.ehAdetN ELSE 0 END) AS SatisAdet,
    SUM(CASE WHEN h.ehTip IN (4,100) THEN h.ehTutarN WHEN h.ehTip IN (3,5,101) THEN -h.ehTutarN ELSE 0 END) AS NetCiro
  FROM dbo.irsHrk h JOIN dbo.urn u ON u.stkID=h.ehstkID
  JOIN dbo.urnKtgr2 k ON k.ktgrID=u.urnKtgr2ID AND k.ktgrAd=N'Hazırlık Kitapları'
  WHERE h.ehTrhS>=DATEADD(YEAR,-1,GETDATE()) AND h.ehMekan IN (1,4477,4478) AND h.ehAltDepo=0 AND h.ehTip IN (4,100,3,5,101)
  GROUP BY u.urnMrkID
)
SELECT m.mrkAd AS Yayinevi,
  COUNT(DISTINCT CASE WHEN p.Stok>0 THEN p.stkID END) AS Cesit,
  SUM(p.Stok) AS StokAdet,
  CAST(SUM(p.Stok*p.Maliyet) AS decimal(18,0)) AS StokTl,
  ISNULL(s.SatisAdet,0) AS YilSatis,
  CAST(ISNULL(s.NetCiro,0) AS decimal(18,0)) AS YilCiro,
  CASE WHEN SUM(p.Stok)>0 THEN CAST(1.0*ISNULL(s.SatisAdet,0)/SUM(p.Stok) AS decimal(10,2)) END AS Devir
FROM urunler p
JOIN dbo.urnMrk m ON m.mrkID=p.urnMrkID
LEFT JOIN sat s ON s.urnMrkID=p.urnMrkID
GROUP BY m.mrkAd, s.SatisAdet, s.NetCiro
HAVING SUM(p.Stok)>0
ORDER BY StokTl DESC;
-- Ürün bazlı için: GROUP BY kaldır, SELECT'e u.stkAd ekle, mrkAd filtreye al (WHERE m.mrkAd=N'Karekök Yayıncılık').


/* ── DRILL 2: ÜRÜN bazlı + ODAK depo stok + ŞUBE satış + E-TİCARET sipariş (Hazırlık Kitapları) ──
   ⚠ "ODAK STOK" = KANONİK TABLO `ent.odak_depo_Stok` (stkID→StokMiktar, 1:1 ~7,16M adet) — e-tic fulfillment depo stoğu.
     NOT (kullanıcı 23.06): odak stoğu = bu tablo. stokSonAltDepo_vw'daki mekan 26142 (İPTAL-Transfer Deposu, 129K) TRANSİT → HARİÇ (journal 14.06: "transit 4480/26142/4835 hariç"). Mağaza rafı = stokSonAltDepo_vw mekan 1/4477/4478, Merkez Depo=12 (ayrı; bu rapor ODAK fulfillment'a bakar).
   Şube satış = irsHrk 12ay (ehTip 4/100, iade 3/5/101 -) · E-ticaret = OPENQUERY ODAKJOKER (DERINSIS_ID=stkID, ORDERDATE ISO 12ay).
   AyKapsam = ODAK stok / aylık ort satış (kaç aylık). Bulgu (23.06): Murat 11.Sınıf SB 569-695 ay, Limit/Okyanus/Karekök matematik-geometri-fizik SB 350-400 ay (ODAK aşırı alım); Üç-Dört-Beş TYT Mat 10lu 4,8 ay (sağlıklı). */
WITH ecom AS (
  SELECT DERINSIS_ID AS stkID, Qty FROM OPENQUERY(ODAKJOKER, '
    SELECT i.DERINSIS_ID, SUM(d.QUANTITY) AS Qty
    FROM JOKER.dbo.J_ORDER_DETAILS d
    JOIN JOKER.dbo.J_ORDERS o ON o.ORDERID = d.ORDERREF
    JOIN JOKER.dbo.J_ITEMS i ON i.LOGICALREF = d.ITEMREF
    WHERE o.ORDERDATE >= ''20250623'' AND i.DERINSIS_ID > 0
    GROUP BY i.DERINSIS_ID')
),
sube AS (SELECT h.ehstkID sID, -SUM(CASE WHEN h.ehTip IN (4,100) THEN h.ehAdetN ELSE 0 END) Adet
         FROM dbo.irsHrk h WHERE h.ehTrhS>=DATEADD(YEAR,-1,GETDATE()) AND h.ehMekan IN (1,4477,4478)
           AND h.ehAltDepo=0 AND h.ehTip IN (4,100,3,5,101) GROUP BY h.ehstkID)
SELECT ISNULL(m.mrkAd,N'-') AS Marka, u.stkKod AS Kod, u.stkAd AS Urun,
  o.StokMiktar         AS OdakStok,
  ISNULL(sube.Adet,0)  AS SubeSatis,
  ISNULL(ecom.Qty,0)   AS EcomSiparis,
  CAST((ISNULL(sube.Adet,0)+ISNULL(ecom.Qty,0))/12.0 AS decimal(10,1)) AS AylikOrtSatis,
  CASE WHEN (ISNULL(sube.Adet,0)+ISNULL(ecom.Qty,0))>0
       THEN CAST(o.StokMiktar/((ISNULL(sube.Adet,0)+ISNULL(ecom.Qty,0))/12.0) AS decimal(10,1)) END AS AyKapsam
FROM ent.odak_depo_Stok o
JOIN dbo.urn u ON u.stkID=o.stkID
JOIN dbo.urnKtgr2 k ON k.ktgrID=u.urnKtgr2ID AND k.ktgrAd=N'Hazırlık Kitapları'
LEFT JOIN dbo.urnMrk m ON m.mrkID=u.urnMrkID
LEFT JOIN sube ON sube.sID=u.stkID
LEFT JOIN ecom ON ecom.stkID=u.stkID
WHERE o.StokMiktar>0
ORDER BY OdakStok DESC;
-- Kategori değiştir: k.ktgrAd=N'...' · Tüm kategoriler: k filtresini kaldır · Mağaza rafı stoğu da istenirse: + LEFT JOIN stokSonAltDepo_vw (mekan 1/4477/4478).


/* ── DRILL 3: TAM ÜRÜN DÖKÜMÜ — şube/depo/ODAK stok ayrı + şube satış ayrı + maliyet/fiyat + marka/yazar (Hazırlık) ──
   Kaynak ürün bilgisi = bkm.UrunBilgi (stkID, mrkAd=yayınevi, Yazar, SonAlis=maliyet birim, SatisFiyat=üst fiyat birim, Kategori3=kategori).
   Stok kolonları: FSM(1)/Özlüce(4477)/İst.Yolu(4478)/Merkez Depo(12) = stokSonAltDepo_vw · ODAK = ent.odak_depo_Stok (e-tic fulfillment).
     NOT: Hazırlık'ta Merkez Depo(12) ~0 — stok ODAK + mağaza rafında. Transit 26142/4480/4835 dahil DEĞİL.
   Satış: şube bazlı son-12ay adet (irsHrk ehMekan 1/4477/4478, ehTip 4/100) + E-TİCARET (OPENQUERY ODAKJOKER, J_ORDER_DETAILS×J_ORDERS×J_ITEMS, DERINSIS_ID=stkID, son 12ay). */
WITH ecom AS (
  SELECT DERINSIS_ID AS stkID, Qty FROM OPENQUERY(ODAKJOKER, '
    SELECT i.DERINSIS_ID, SUM(d.QUANTITY) AS Qty FROM JOKER.dbo.J_ORDER_DETAILS d
    JOIN JOKER.dbo.J_ORDERS o ON o.ORDERID=d.ORDERREF JOIN JOKER.dbo.J_ITEMS i ON i.LOGICALREF=d.ITEMREF
    WHERE o.ORDERDATE >= ''20250623'' AND i.DERINSIS_ID > 0 GROUP BY i.DERINSIS_ID')
),
mgz AS (
  SELECT v.ehstkID sID,
    SUM(CASE WHEN v.ehMekan=1    THEN v.stok ELSE 0 END) Fsm,
    SUM(CASE WHEN v.ehMekan=4477 THEN v.stok ELSE 0 END) Ozl,
    SUM(CASE WHEN v.ehMekan=4478 THEN v.stok ELSE 0 END) Ist,
    SUM(CASE WHEN v.ehMekan=12   THEN v.stok ELSE 0 END) Mrkz
  FROM dbo.stokSonAltDepo_vw v WHERE v.ehAltDepo=0 AND v.ehMekan IN (1,4477,4478,12) GROUP BY v.ehstkID),
sat AS (
  SELECT h.ehstkID sID,
    -SUM(CASE WHEN h.ehMekan=1    AND h.ehTip IN (4,100) THEN h.ehAdetN ELSE 0 END) sFsm,
    -SUM(CASE WHEN h.ehMekan=4477 AND h.ehTip IN (4,100) THEN h.ehAdetN ELSE 0 END) sOzl,
    -SUM(CASE WHEN h.ehMekan=4478 AND h.ehTip IN (4,100) THEN h.ehAdetN ELSE 0 END) sIst
  FROM dbo.irsHrk h WHERE h.ehTrhS>=DATEADD(YEAR,-1,GETDATE()) AND h.ehMekan IN (1,4477,4478) AND h.ehAltDepo=0 AND h.ehTip IN (4,100) GROUP BY h.ehstkID)
SELECT
  ub.mrkAd AS Yayinevi, LTRIM(RTRIM(ub.Yazar)) AS Yazar, ub.stkKod AS Kod, ub.stkAd AS Urun,
  ISNULL(mgz.Fsm,0) AS StokFSM, ISNULL(mgz.Ozl,0) AS StokOzluce, ISNULL(mgz.Ist,0) AS StokIstYolu,
  ISNULL(mgz.Mrkz,0) AS StokMerkezDepo, ISNULL(o.StokMiktar,0) AS StokODAK,
  ISNULL(mgz.Fsm,0)+ISNULL(mgz.Ozl,0)+ISNULL(mgz.Ist,0)+ISNULL(mgz.Mrkz,0)+ISNULL(o.StokMiktar,0) AS StokToplam,
  ISNULL(sat.sFsm,0) AS SatisFSM, ISNULL(sat.sOzl,0) AS SatisOzluce, ISNULL(sat.sIst,0) AS SatisIstYolu,
  ISNULL(sat.sFsm,0)+ISNULL(sat.sOzl,0)+ISNULL(sat.sIst,0) AS SatisSubeToplam,
  ISNULL(ecom.Qty,0) AS SatisEticaret,
  ISNULL(sat.sFsm,0)+ISNULL(sat.sOzl,0)+ISNULL(sat.sIst,0)+ISNULL(ecom.Qty,0) AS SatisGenelToplam,
  ub.SonAlis AS MaliyetBirim, ub.SatisFiyat AS UstFiyatBirim
FROM bkm.UrunBilgi ub
LEFT JOIN ent.odak_depo_Stok o ON o.stkID=ub.stkID
LEFT JOIN mgz ON mgz.sID=ub.stkID
LEFT JOIN sat ON sat.sID=ub.stkID
LEFT JOIN ecom ON ecom.stkID=ub.stkID
WHERE ub.Kategori3=N'Hazırlık Kitapları' AND ub.urnTip=0
  AND (ISNULL(o.StokMiktar,0)>0 OR ISNULL(mgz.Fsm,0)+ISNULL(mgz.Ozl,0)+ISNULL(mgz.Ist,0)+ISNULL(mgz.Mrkz,0)>0)
ORDER BY StokODAK DESC;
-- Kategori değiştir: ub.Kategori3=N'...' (UrunBilgi kategori) · Marka/yayınevi filtre: AND ub.mrkAd=N'Murat Yayınları' · Tek yazar: AND ub.Yazar LIKE N'%...%'.
