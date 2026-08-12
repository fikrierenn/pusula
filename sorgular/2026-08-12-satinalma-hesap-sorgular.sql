/*
  SATINALMA HESAP-SORMA raporunun (scripts/satinalma_hesap_sorma.py) kullandığı TÜM SQL sorguları.
  SSMS'te DerinSISBkm üzerinde çalışır. Örnek ay = Temmuz 2026 (tarihleri değiştirerek başka ay).
  Sıra: alınan ürün seti (#a) → ledger stok → aylık satış (şube+e-tic) → bu-ay satış → depo → stok-tablo
        → master → maliyet (fatura>devir) → ilk satış → kategori sezon büyümesi.

  TARİH PARAMETRELERİ (py'de dinamik; burada Temmuz-2026 örneği):
    @T_AY0 = hedef ay başı (dahil)      = 20260701
    @T_AY1 = sonraki ay başı (hariç)    = 20260801
    @T_GEC = 24 ay öncesi (şekil başı)  = 20240701
    SON12  = son 12 ay  = 2025-07 .. 2026-06   ONC12 = önceki 12 ay = 2024-07 .. 2025-06
    Sezon penceresi (önümüz Ağu-Eki geçen yıl) = SON12[1..3] = 2025-08, 2025-09, 2025-10
  Kategori: bkm.UrunBilgi.Kat3ID IN (10=Hediyelik, 12=Kırtasiye, 16=Oyuncak).
*/
SET NOCOUNT ON;
DECLARE @T_AY0 char(8)='20260701', @T_AY1 char(8)='20260801', @T_GEC char(8)='20240701';

/* ============================================================
   0) ALINAN ÜRÜN SETİ (#a) — raporun satır kümesi
   Bu ay satın alınmış ürünler (irsHrk fiziki stok girişi: ehTip 0 Alış + 10 Yerel Alım).
   ============================================================ */
IF OBJECT_ID('tempdb..#a') IS NOT NULL DROP TABLE #a;
SELECT h.ehstkID AS stkID,
       CONVERT(int,   SUM(h.ehAdetN))  AS alis_adet,
       CONVERT(money, SUM(h.ehTutarN)) AS alis_tutar         -- KDV-hariç net
INTO #a
FROM dbo.irsHrk h WITH(NOLOCK)
JOIN bkm.UrunBilgi u WITH(NOLOCK) ON u.stkID=h.ehstkID AND u.Kat3ID IN (10,12,16)
WHERE h.ehTip IN (0,10) AND h.ehTrhS>=@T_AY0 AND h.ehTrhS<@T_AY1 AND h.ehAdetN>0
GROUP BY h.ehstkID;
CREATE UNIQUE CLUSTERED INDEX ix_a ON #a(stkID);

/* ============================================================
   1) LEDGER STOK — ay başı / ay sonu / (24 ay öncesi) ham bakiye
   NOT: irsHrk mutlak bazı bazı üründe bozuk (depo mekan 12 negatife gider).
   Rapor bunu SADECE 'ay-net delta' için kullanır; mutlak stok fiziki-ankrajdan gelir (bkz. 6+7).
   ============================================================ */
SELECT h.ehstkID,
   SUM(CASE WHEN h.ehTrhS<@T_AY0 THEN h.ehAdetN ELSE 0 END) AS ledger_acilis,   -- ay başı öncesi
   SUM(CASE WHEN h.ehTrhS<@T_AY1 THEN h.ehAdetN ELSE 0 END) AS ledger_kapanis   -- ay sonu öncesi
FROM dbo.irsHrk h WITH(NOLOCK) JOIN #a ON #a.stkID=h.ehstkID
WHERE h.ehTrhS<@T_AY1
GROUP BY h.ehstkID;
-- Rapor: ay_net = ledger_kapanis - ledger_acilis (delta güvenilir). Ay Sonu = fiziki (6+7). Ay Başı = Ay Sonu - ay_net.

/* ============================================================
   2) AYLIK ŞUBE SATIŞ (24 ay) — talep şekli (SON12/ONC12 + sezon)
   Şube = mağaza; satış = ehTip 1/4/100 (çıkış), -SUM ile pozitif adet.
   ============================================================ */
SELECT h.ehstkID, CONVERT(varchar(7),h.ehTrhS,126) AS ay, CONVERT(int,-SUM(h.ehAdetN)) AS satis
FROM dbo.irsHrk h WITH(NOLOCK) JOIN #a ON #a.stkID=h.ehstkID
WHERE h.ehTip IN (1,4,100) AND h.ehTrhS>=@T_GEC AND h.ehTrhS<@T_AY0
GROUP BY h.ehstkID, CONVERT(varchar(7),h.ehTrhS,126);

/* ============================================================
   3) AYLIK E-TİCARET SATIŞ (24 ay) — JOKER (uzak), kategori-set Python'da süzülür
   ============================================================ */
SELECT x.stkID, x.ay, CONVERT(int,x.qty) AS satis
FROM OPENQUERY(ODAKJOKER, '
    SELECT i.DERINSIS_ID stkID,
           CONVERT(varchar(4),YEAR(o.ORDERDATE))+''-''+RIGHT(''0''+CONVERT(varchar(2),MONTH(o.ORDERDATE)),2) ay,
           SUM(d.QUANTITY) qty
    FROM JOKER.dbo.J_ORDER_DETAILS d
        JOIN JOKER.dbo.J_ORDERS o ON o.ORDERID=d.ORDERREF
        JOIN JOKER.dbo.J_ITEMS  i ON i.LOGICALREF=d.ITEMREF
    WHERE o.ORDERDATE>=''20240701'' AND o.ORDERDATE<''20260701'' AND i.DERINSIS_ID>0 AND d.STATUS NOT IN (2004,2005,2010)
    GROUP BY i.DERINSIS_ID, CONVERT(varchar(4),YEAR(o.ORDERDATE))+''-''+RIGHT(''0''+CONVERT(varchar(2),MONTH(o.ORDERDATE)),2)') x
JOIN #a ON #a.stkID=x.stkID;

/* ============================================================
   4) BU AY SATILAN (roll-forward'ı kapatır) — şube + e-tic, hedef ay
   ============================================================ */
SELECT h.ehstkID, CONVERT(int,-SUM(h.ehAdetN)) AS bu_ay_satis   -- şube
FROM dbo.irsHrk h WITH(NOLOCK) JOIN #a ON #a.stkID=h.ehstkID
WHERE h.ehTip IN (1,4,100) AND h.ehTrhS>=@T_AY0 AND h.ehTrhS<@T_AY1
GROUP BY h.ehstkID;
-- + e-tic (aynı OPENQUERY deseni, ORDERDATE >= @T_AY0 AND < @T_AY1) → Python'da toplanır.

/* ============================================================
   5) DEPO FİZİKİ STOK (WMS anlık) — RAF+GR, CK/CK01 hariç
   ============================================================ */
SELECT d.stkID, CONVERT(int,SUM(d.Stok)) AS depo_stok
FROM depo.stok_adres_palet_vw d WITH(NOLOCK)
WHERE d.adrsAlanTipID IN (0,1) AND d.stkID IN (SELECT stkID FROM #a)
GROUP BY d.stkID;

/* ============================================================
   6) ŞUBE AYLIK STOK BAKİYE — persistent tablodan (güvenilir, floored)
   (tablo: sorgular/2026-08-12-stok-ay-bakiye-mekan-tablo.sql ile doldurulur)
   Rapor bir aya kadarki SON bakiyeyi taşır: Donem <= @ay ORDER BY Donem DESC.
   ============================================================ */
SELECT b.stkID, b.ehMekan, CONVERT(varchar(7),b.Donem,126) AS ay, b.Stok
FROM bkm.StokAyBakiyeMekanBazli b WITH(NOLOCK)
WHERE b.Kaynak='irsHrk' AND b.stkID IN (SELECT stkID FROM #a) AND b.Donem>='20240101'
ORDER BY b.stkID, b.ehMekan, b.Donem;

/* ============================================================
   7) ÜRÜN MASTER — atıf + ad + kategori + marka
   ============================================================ */
SELECT u.stkID, u.SatinAlma, u.stkAd, u.Kategori3, u.mrkAd
FROM bkm.UrunBilgi u WITH(NOLOCK) JOIN #a ON #a.stkID=u.stkID;

/* ============================================================
   8) BİRİM MALİYET — (a) son alış faturası > (b) 31.05.2021 devir. (yoksa Python: bu-ay alış birimi)
   ============================================================ */
-- (a) son alış faturası birim (KDV-hariç net)
SELECT stkID, birim AS maliyet_fatura, tarih AS son_alis FROM (
    SELECT fa.ehstkID AS stkID,
           CONVERT(decimal(18,4), fa.ehTutarN/NULLIF(fa.ehAdetN,0)) AS birim,
           f.eTarih AS tarih,
           ROW_NUMBER() OVER (PARTITION BY fa.ehstkID ORDER BY f.eTarih DESC, f.eID DESC) rn
    FROM dbo.fatAyr fa WITH(NOLOCK) JOIN dbo.fat f WITH(NOLOCK) ON fa.ehID=f.eID
    JOIN #a ON #a.stkID=fa.ehstkID
    WHERE f.eTip=0 AND f.eDurum<>2 AND fa.ehAdetN>0
) t WHERE rn=1;
-- (b) 31.05.2021 devir (fatura yok ise) — irsHrk ehTip=99 'Sayım' açılış
SELECT h.ehstkID AS stkID, CONVERT(decimal(18,4), SUM(h.ehTutarN)/NULLIF(SUM(h.ehAdetN),0)) AS maliyet_devir
FROM dbo.irsHrk h WITH(NOLOCK) JOIN #a ON #a.stkID=h.ehstkID
WHERE h.ehTip=99 AND h.ehTrhS>='20210531' AND h.ehTrhS<'20210601'
GROUP BY h.ehstkID HAVING SUM(h.ehAdetN)<>0;

/* ============================================================
   9) İLK GERÇEK SATIŞ — yaş / genç-ürün kapısı (ilk satış <12 ay → değerlendirme dışı)
   ============================================================ */
SELECT h.ehstkID, MIN(h.ehTrhS) AS ilk_satis
FROM dbo.irsHrk h WITH(NOLOCK) JOIN #a ON #a.stkID=h.ehstkID
WHERE h.ehTip IN (1,4,100) AND h.ehTrhS<@T_AY1
GROUP BY h.ehstkID;

/* ============================================================
   10) KATEGORİ SEZON BÜYÜMESİ — ürün-g tabanı ince (<100) olunca fallback
   Önümüz sezon (Ağu-Eki 2026) için geçen yıl (2025) / önceki yıl (2024) oranı.
   ============================================================ */
SELECT u.Kategori3,
    -SUM(CASE WHEN i.ehTrhS>='20250801' AND i.ehTrhS<'20251101' THEN i.ehAdetN ELSE 0 END) AS sezon_gecen_yil,
    -SUM(CASE WHEN i.ehTrhS>='20240801' AND i.ehTrhS<'20241101' THEN i.ehAdetN ELSE 0 END) AS sezon_onceki_yil
FROM dbo.irsHrk i WITH(NOLOCK)
JOIN bkm.UrunBilgi u WITH(NOLOCK) ON u.stkID=i.ehstkID AND u.Kat3ID IN (10,12,16)
WHERE i.ehTip IN (1,4,100) AND i.ehTrhS>='20240801' AND i.ehTrhS<'20251101'
GROUP BY u.Kategori3;
-- büyüme_katsayısı = sezon_gecen_yil / sezon_onceki_yil (floor 0.5, tavan 4).

-- Temizlik
IF OBJECT_ID('tempdb..#a') IS NOT NULL DROP TABLE #a;
