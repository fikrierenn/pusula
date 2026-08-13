/*
  SATINALMA HESAP-SORMA — TAM DİNAMİK SQL (Excel raporunun birebir SQL karşılığı).
  scripts/satinalma_hesap_sorma.py mantığını temp tablo + numbers-table ile SSMS'te üretir.
  ÇALIŞTIRMA: DerinSISBkm üzerinde tek seferde (F5). Örnek ay = Temmuz 2026.
  BAĞIMLILIK: bkm.StokAyBakiyeMekanBazli (şube aylık bakiye — stok-tablo scriptiyle doldurulmuş olmalı).
  NOT: MCP çok-statement temp tabloyu çalıştıramaz → SSMS'te koş, Excel ile kıyasla.

  Aşamalar: #a alış → #ilk stok-giriş → #ay aylık satış(şube+etic) → #shape 12-ay şekil
            → #agg büyüme/sezon → #stok fiziki(ay başı/sonu) → #stoklu şube stoklu-ay
            → #tuk sezonlu tükenme → maliyet → FINAL (karakter+değerlendirme+açıklama).
*/
SET NOCOUNT ON;
DECLARE @AY0 char(8)='20260701', @AY1 char(8)='20260801';         -- hedef ay [başı, sonu)
DECLARE @S12b char(8)='20250701', @S24b char(8)='20240701';       -- son12 başı, 24-ay başı
DECLARE @O12b char(8)='20240701', @O12e char(8)='20250701';       -- önceki12 [başı,bitiş)
DECLARE @SEZb char(8)='20250801', @SEZe char(8)='20251101';       -- geçen yıl sezon (Ağu-Eki)
DECLARE @ESIK int=12, @MAT int=5000, @MINKOLI int=24;             -- fazla eşiği, materiality, min-koli

/* 1) #a — bu ay alınan ürünler + alış adet/tutar */
IF OBJECT_ID('tempdb..#a') IS NOT NULL DROP TABLE #a;
SELECT h.ehstkID AS stkID, CONVERT(int,SUM(h.ehAdetN)) AS alis_adet, CONVERT(money,SUM(h.ehTutarN)) AS alis_tutar
INTO #a
FROM dbo.irsHrk h WITH(NOLOCK)
JOIN bkm.UrunBilgi u WITH(NOLOCK) ON u.stkID=h.ehstkID AND u.Kat3ID IN (10,12,16)
WHERE h.ehTip IN (0,10) AND h.ehTrhS>=@AY0 AND h.ehTrhS<@AY1 AND h.ehAdetN>0
GROUP BY h.ehstkID;
CREATE UNIQUE CLUSTERED INDEX ix ON #a(stkID);

/* 2) #ilk — stoğa ilk giriş (alış/sevk/stok-ekle/devir), yaş kapısı */
IF OBJECT_ID('tempdb..#ilk') IS NOT NULL DROP TABLE #ilk;
SELECT h.ehstkID AS stkID, MIN(h.ehTrhS) AS ilk_giris
INTO #ilk FROM dbo.irsHrk h WITH(NOLOCK) JOIN #a ON #a.stkID=h.ehstkID
WHERE h.ehTip IN (0,10,13,16,99) AND h.ehTrhS<@AY1 GROUP BY h.ehstkID;

/* 3) #ay — aylık satış (şube irsHrk 1/4/100 + e-tic JOKER), 24 ay */
IF OBJECT_ID('tempdb..#ay') IS NOT NULL DROP TABLE #ay;
CREATE TABLE #ay (stkID int, ay char(7), satis int);
INSERT #ay SELECT h.ehstkID, CONVERT(char(7),h.ehTrhS,126), CONVERT(int,-SUM(h.ehAdetN))
FROM dbo.irsHrk h WITH(NOLOCK) JOIN #a ON #a.stkID=h.ehstkID
WHERE h.ehTip IN (1,4,100) AND h.ehTrhS>=@S24b AND h.ehTrhS<@AY0
GROUP BY h.ehstkID, CONVERT(char(7),h.ehTrhS,126);
INSERT #ay SELECT x.stkID, x.ay, CONVERT(int,x.qty)
FROM OPENQUERY(ODAKJOKER,'
    SELECT i.DERINSIS_ID stkID, CONVERT(varchar(4),YEAR(o.ORDERDATE))+''-''+RIGHT(''0''+CONVERT(varchar(2),MONTH(o.ORDERDATE)),2) ay, SUM(d.QUANTITY) qty
    FROM JOKER.dbo.J_ORDER_DETAILS d JOIN JOKER.dbo.J_ORDERS o ON o.ORDERID=d.ORDERREF JOIN JOKER.dbo.J_ITEMS i ON i.LOGICALREF=d.ITEMREF
    WHERE o.ORDERDATE>=''20240701'' AND o.ORDERDATE<''20260701'' AND i.DERINSIS_ID>0 AND d.STATUS NOT IN (2004,2005,2010)
    GROUP BY i.DERINSIS_ID, CONVERT(varchar(4),YEAR(o.ORDERDATE))+''-''+RIGHT(''0''+CONVERT(varchar(2),MONTH(o.ORDERDATE)),2)') x
JOIN #a ON #a.stkID=x.stkID;
-- ürün×ay birleşik (şube+etic)
IF OBJECT_ID('tempdb..#aylik') IS NOT NULL DROP TABLE #aylik;
SELECT stkID, ay, SUM(satis) AS satis INTO #aylik FROM #ay GROUP BY stkID, ay;
CREATE CLUSTERED INDEX ix ON #aylik(stkID, ay);

/* 4) #shape — 12-ay şekil (SON12: 2025-07=idx0 .. 2026-06=idx11) */
IF OBJECT_ID('tempdb..#shape') IS NOT NULL DROP TABLE #shape;
SELECT s.stkID, m.idx, ISNULL(a.satis,0) AS val
INTO #shape
FROM (SELECT stkID FROM #a) s
CROSS JOIN (VALUES (0,'2025-07'),(1,'2025-08'),(2,'2025-09'),(3,'2025-10'),(4,'2025-11'),(5,'2025-12'),
                   (6,'2026-01'),(7,'2026-02'),(8,'2026-03'),(9,'2026-04'),(10,'2026-05'),(11,'2026-06')) m(idx,ay)
LEFT JOIN #aylik a ON a.stkID=s.stkID AND a.ay=m.ay;
CREATE CLUSTERED INDEX ix ON #shape(stkID, idx);

/* 5) #agg — son12/onc12/son24/gy_sezon(shape idx1..3)/satis_ay + büyüme g */
IF OBJECT_ID('tempdb..#agg') IS NOT NULL DROP TABLE #agg;
SELECT a.stkID,
   ISNULL(SUM(CASE WHEN ay>='2025-07' AND ay<='2026-06' THEN al.satis END),0) AS son12,
   ISNULL(SUM(CASE WHEN ay>='2024-07' AND ay<='2025-06' THEN al.satis END),0) AS onc12,
   ISNULL(SUM(al.satis),0) AS son24,
   ISNULL(SUM(CASE WHEN ay IN ('2025-08','2025-09','2025-10') THEN al.satis END),0) AS gy_sezon,
   ISNULL(SUM(CASE WHEN ay>='2025-07' AND ay<='2026-06' AND al.satis>0 THEN 1 END),0) AS satis_ay
INTO #agg
FROM #a a LEFT JOIN #aylik al ON al.stkID=a.stkID
GROUP BY a.stkID;
ALTER TABLE #agg ADD g float, g_kaynak varchar(10);
-- kategori sezon büyümesi (fallback)
DECLARE @gK float, @gO float, @gH float;
SELECT @gK = CASE WHEN o>0 THEN 1.0*y/o ELSE 1 END FROM (SELECT
   -SUM(CASE WHEN i.ehTrhS>=@SEZb AND i.ehTrhS<@SEZe THEN i.ehAdetN ELSE 0 END) y,
   -SUM(CASE WHEN i.ehTrhS>='20240801' AND i.ehTrhS<'20241101' THEN i.ehAdetN ELSE 0 END) o
   FROM dbo.irsHrk i WITH(NOLOCK) JOIN bkm.UrunBilgi u WITH(NOLOCK) ON u.stkID=i.ehstkID AND u.Kat3ID=12
   WHERE i.ehTip IN (1,4,100) AND i.ehTrhS>='20240801' AND i.ehTrhS<@SEZe) t;   -- Kırtasiye
-- (Oyuncak/Hediyelik için ayrı; kısalık için kategori-g'yi ürün-bazlı fallback'te ürün Kat3ID'sine göre çöz)
UPDATE g SET g.g = CASE WHEN g.onc12>=100 THEN CASE WHEN 1.0*g.son12/g.onc12<0.3 THEN 0.3 WHEN 1.0*g.son12/g.onc12>6 THEN 6 ELSE 1.0*g.son12/g.onc12 END
                        ELSE ISNULL(kg.gval,1.37) END,
       g.g_kaynak = CASE WHEN g.onc12>=100 THEN 'ürün' ELSE 'kategori' END
FROM #agg g
OUTER APPLY (SELECT CASE u.Kat3ID WHEN 12 THEN 1.37 WHEN 16 THEN 1.61 WHEN 10 THEN 2.54 END gval
             FROM bkm.UrunBilgi u WHERE u.stkID=g.stkID) kg;

/* 6) #stok — ay sonu = fiziki(şube stokSon + depo WMS); ay başı = ay sonu − ledger ay-net */
IF OBJECT_ID('tempdb..#stok') IS NOT NULL DROP TABLE #stok;
SELECT a.stkID,
   ISNULL(sube.s,0)+ISNULL(depo.d,0) AS kap,
   ISNULL(led.kapanis,0)-ISNULL(led.acilis,0) AS ay_net
INTO #stok
FROM #a a
OUTER APPLY (SELECT SUM(stok) s FROM stokSon_vw WHERE ehstkID=a.stkID AND ehMekan IN (1,4477,4478)) sube
OUTER APPLY (SELECT SUM(Stok) d FROM depo.stok_adres_palet_vw WHERE stkID=a.stkID AND adrsAlanTipID IN (0,1)) depo
OUTER APPLY (SELECT SUM(CASE WHEN ehTrhS<@AY0 THEN ehAdetN ELSE 0 END) acilis,
                    SUM(CASE WHEN ehTrhS<@AY1 THEN ehAdetN ELSE 0 END) kapanis
             FROM dbo.irsHrk WITH(NOLOCK) WHERE ehstkID=a.stkID AND ehTrhS<@AY1) led;
ALTER TABLE #stok ADD ac int;
UPDATE #stok SET ac = kap - ay_net;

/* 7) #stoklu — şube stoklu-ay (SON12'de bakiye>0 VEYA o ay satış>0), bkm.StokAyBakiyeMekanBazli'den */
IF OBJECT_ID('tempdb..#stoklu') IS NOT NULL DROP TABLE #stoklu;
SELECT a.stkID,
  SUM(CASE WHEN (bal.bakiye>0 OR ISNULL(sa.satis,0)>0) THEN 1 ELSE 0 END) AS stoklu_ay
INTO #stoklu
FROM #a a
CROSS JOIN (VALUES ('2025-07'),('2025-08'),('2025-09'),('2025-10'),('2025-11'),('2025-12'),
                   ('2026-01'),('2026-02'),('2026-03'),('2026-04'),('2026-05'),('2026-06')) m(ay)
OUTER APPLY (SELECT SUM(x.Stok) bakiye FROM (
     SELECT b.ehMekan, (SELECT TOP 1 b2.Stok FROM bkm.StokAyBakiyeMekanBazli b2 WITH(NOLOCK)
        WHERE b2.stkID=a.stkID AND b2.ehMekan=b.ehMekan AND b2.Kaynak='irsHrk' AND CONVERT(char(7),b2.Donem,126)<=m.ay
        ORDER BY b2.Donem DESC) Stok
     FROM (SELECT DISTINCT ehMekan FROM bkm.StokAyBakiyeMekanBazli WITH(NOLOCK) WHERE stkID=a.stkID AND Kaynak='irsHrk') b) x) bal
OUTER APPLY (SELECT satis FROM #aylik WHERE stkID=a.stkID AND ay=m.ay) sa
GROUP BY a.stkID;

/* 8) #tuk — sezonlu ileri tükenme (numbers-table, decay + g<1 floor + sezon offset +1) */
IF OBJECT_ID('tempdb..#f') IS NOT NULL DROP TABLE #f;
SELECT TOP 1000 CONVERT(int,ROW_NUMBER() OVER (ORDER BY (SELECT NULL))-1) AS f INTO #f FROM sys.all_columns;   -- 0..999: Python while f<999 ile hizalı (400-cap 999'a takılıp erken 'tükenmez' veriyordu)
IF OBJECT_ID('tempdb..#tuk') IS NOT NULL DROP TABLE #tuk;
;WITH exp AS (
    SELECT sh.stkID, f.f,
       sh.val * (CASE WHEN g.g>=1 THEN 1+(g.g-1)*(CASE WHEN f.f<12 THEN 1-f.f/12.0 ELSE 0 END) ELSE 1 END) AS e
    FROM #f f JOIN #shape sh ON sh.idx=(f.f+1)%12 JOIN #agg g ON g.stkID=sh.stkID
), cum AS (
    SELECT stkID, f, e, SUM(e) OVER (PARTITION BY stkID ORDER BY f) AS c,
           SUM(e) OVER (PARTITION BY stkID ORDER BY f) - e AS cb
    FROM exp
), gecis AS (   -- İLK f: kümülatif stoğu aşan ay (crossing). Sonraki f'lerde cb>kap → interpolasyon NEGATİF olur, o yüzden sadece ilk geçiş.
    SELECT c.stkID, MIN(c.f) AS f0
    FROM cum c JOIN #stok st ON st.stkID=c.stkID
    WHERE st.kap>0 AND c.c>=st.kap AND c.e>0
    GROUP BY c.stkID
)
SELECT g.stkID,
   CONVERT(decimal(10,1), cm.f + (st.kap - cm.cb)/cm.e) AS tuk_ay   -- ilk geçiş ayında interpolasyon
INTO #tuk
FROM gecis g
JOIN cum cm ON cm.stkID=g.stkID AND cm.f=g.f0
JOIN #stok st ON st.stkID=g.stkID;

/* 9) #maliyet — son fatura > 2021 devir (Python: yoksa bu-ay alış birimi = FINAL'de) */
IF OBJECT_ID('tempdb..#mal') IS NOT NULL DROP TABLE #mal;
SELECT stkID, birim INTO #mal FROM (
   SELECT fa.ehstkID stkID, CONVERT(decimal(18,4),SUM(fa.ehTutarN)/NULLIF(SUM(fa.ehAdetN),0)) birim,
          ROW_NUMBER() OVER (PARTITION BY fa.ehstkID ORDER BY MAX(f.eTarih) DESC, f.eID DESC) rn
   FROM dbo.fatAyr fa WITH(NOLOCK) JOIN dbo.fat f WITH(NOLOCK) ON fa.ehID=f.eID
   JOIN #a ON #a.stkID=fa.ehstkID WHERE f.eTip=0 AND f.eDurum<>2 AND fa.ehAdetN>0
   GROUP BY fa.ehstkID, f.eID) t WHERE rn=1;   -- fatura-bazında SUM(tutar)/SUM(adet) (bedava/0-birim satırlar ortalamaya dahil), sonra en son fatura (deterministik, satır-tie yok)
INSERT #mal SELECT h.ehstkID, CONVERT(decimal(18,4),SUM(h.ehTutarN)/NULLIF(SUM(h.ehAdetN),0))
FROM dbo.irsHrk h WITH(NOLOCK) JOIN #a ON #a.stkID=h.ehstkID
WHERE h.ehTip=99 AND h.ehTrhS>='20210531' AND h.ehTrhS<'20210601' AND h.ehstkID NOT IN (SELECT stkID FROM #mal)
GROUP BY h.ehstkID HAVING SUM(h.ehAdetN)<>0;

/* ============================================================
   FINAL — Excel ile aynı kolonlar + karakter + değerlendirme + açıklama
   ============================================================ */
SELECT
   a.stkID                                                   AS [Ürün Kodu],
   u.stkAd                                                   AS [Ürün Adı],
   u.Kategori3                                               AS [Kategori],
   u.mrkAd                                                   AS [Marka],
   a.alis_adet                                               AS [Bu Ay Alınan (adet)],
   CONVERT(int,a.alis_tutar)                                 AS [Bu Ay Alış Tutarı],
   CONVERT(decimal(18,2), ISNULL(NULLIF(m.birim,0), CASE WHEN a.alis_adet>0 THEN a.alis_tutar/a.alis_adet END)) AS [Birim Maliyet],
   st.ac                                                     AS [Ay Başındaki Stok],
   st.kap                                                    AS [Ay Sonundaki Stok],
   ag.son12                                                  AS [Son 12 Ay Satış],
   CONVERT(decimal(6,2),ag.g)                                AS [Yıllık Büyüme],
   CONVERT(decimal(10,1), CASE WHEN ag.son12=0 OR st.kap<=0 THEN NULL ELSE ISNULL(tk.tuk_ay,999) END) AS [Kaç Ayda Tükenir],
   CONVERT(decimal(10,1), CASE WHEN ag.son12>0 THEN st.kap/(ag.son12/12.0) END) AS [Kaç Ayda Tükenir (basit)],
   ag.gy_sezon                                               AS [Geçen Yıl Sezon Satışı],
   CONVERT(int, ag.gy_sezon*ag.g)                            AS [Bu Sezon Beklenen],
   st.kap - CONVERT(int, ag.gy_sezon*ag.g)                   AS [Sezon Sonrası Kalan],
   sl.stoklu_ay                                              AS [Yılda Kaç Ay Stoklu],
   CONVERT(decimal(10,1), CASE WHEN sl.stoklu_ay>0 THEN 1.0*ag.son12/sl.stoklu_ay END) AS [Aylık Satış Hızı],
   CONVERT(int, CASE WHEN ag.son12>0 THEN 100.0*ag.gy_sezon/ag.son12 ELSE 0 END) AS [Satışın Sezon Payı %],
   ag.g_kaynak                                               AS [Büyüme Kaynağı],
   (DATEDIFF(month, ik.ilk_giris, @AY0))                     AS [Stoğa İlk Girişten Beri (ay)],
   ag.satis_ay                                               AS [Yılda Kaç Ay Satmış],
   -- KARAKTER (Python sırası: genç → durgun → sezonsal → normal → trend → düşüş → düzensiz)
   CASE
     WHEN DATEDIFF(month,ik.ilk_giris,@AY0) BETWEEN 0 AND 11 THEN 'GENÇ'
     WHEN ag.son24=0 THEN 'DURGUN'
     WHEN ag.son12>0 AND 1.0*ag.gy_sezon/ag.son12>=0.5 THEN 'SEZONSAL'
     WHEN ag.satis_ay>=9 THEN 'NORMAL'
     WHEN ag.g>=2 THEN 'TREND'
     WHEN ag.g<0.7 THEN 'DÜŞÜŞ'
     ELSE 'DÜZENSİZ' END                                     AS [Ürün Karakteri],
   -- DEĞERLENDİRME (Python bayrak sırası)
   CASE
     WHEN DATEDIFF(month,ik.ilk_giris,@AY0) BETWEEN 0 AND 11 THEN N'GENÇ ÜRÜN'
     WHEN ag.son12=0 AND sl.stoklu_ay>=6 THEN N'🔴 ÖLÜ-ALIM'
     WHEN ag.son12=0 THEN N'🟠 YENİDEN-STOK'
     WHEN st.kap - ag.gy_sezon*ag.g < 0 THEN (CASE WHEN NOT(ag.son12>0 AND ag.gy_sezon>=0.5*ag.son12) AND ag.satis_ay<9 AND ag.g>=2 THEN N'🟠 TREND-HIZLI' ELSE N'🟢 AZ ALMIŞ' END)   -- Python: karakter='TREND' (g>=2 AMA sezonsal/normal DEĞİL), sadece g>=2 değil
     WHEN st.kap>0 AND ISNULL(tk.tuk_ay,999) > @ESIK THEN
        (CASE WHEN ag.g_kaynak='kategori' THEN N'🟠 İZLE (veri yok)'   -- Python: kategori-veri-yok, min-koli/materiality'den ÖNCE (kategori ürün FAZLA olmaz → KÜÇÜK/UZUN'a düşmez)
              WHEN a.alis_adet<=@MINKOLI THEN N'🟡 KÜÇÜK-ALIM'
              WHEN CONVERT(money,CASE WHEN ag.son12>0 THEN (st.kap-1.0*ag.son12/NULLIF(sl.stoklu_ay,0)*@ESIK) ELSE 0 END)
                   * ISNULL(NULLIF(m.birim,0),CASE WHEN a.alis_adet>0 THEN a.alis_tutar/a.alis_adet END) < @MAT THEN N'🟡 UZUN-KUYRUK'
              ELSE N'🔴 FAZLA' END)
     WHEN st.kap>0 AND ISNULL(tk.tuk_ay,999) > 6 THEN N'🟠 İZLE'
     ELSE N'🟢 NORMAL' END                                    AS [Değerlendirme]
FROM #a a
JOIN bkm.UrunBilgi u WITH(NOLOCK) ON u.stkID=a.stkID
JOIN #agg ag ON ag.stkID=a.stkID
JOIN #stok st ON st.stkID=a.stkID
LEFT JOIN #stoklu sl ON sl.stkID=a.stkID
LEFT JOIN #tuk tk ON tk.stkID=a.stkID
LEFT JOIN #ilk ik ON ik.stkID=a.stkID
LEFT JOIN #mal m ON m.stkID=a.stkID
ORDER BY u.Kategori3, u.stkAd;

-- Temizlik
-- DROP TABLE #a,#ilk,#ay,#aylik,#shape,#agg,#stok,#stoklu,#f,#tuk,#mal;
