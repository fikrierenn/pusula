/*
  Konu : bkm.OneriSiparis reorder öneri motoru — geçmiş backtest (güven-bandı × tahmin güvenilirliği)
  DB   : DerinSISBkm (192.168.40.201)
  Kaynak: ENS karar-motoru keşfi 2026-07-30. Sema: entities.bkm.OneriSiparis, metrics.reorder_oneri_motoru.
  Bulgu: satış yoğunluğu (Miktar90) güven-proxy'si tahmin güvenilirliğini ayırıyor (SMAPE 2.0→0.66,
         6 tarih replike, sezon-bağımsız). %74.7 ölü stok. Sapma sezonluk. Bakiye = SUM(irsHrk.ehAdetN).
  NOT  : bkm.OneriSiparis günlük snapshot (proc yalnız bugünü siler → ~19 ay birikmiş, 208M satır).
         Miktar30 = trailing 30-gün satış → self-join ile D'deki tahmin vs D+30'daki gerçekleşme.
*/

-- 1) Geçmiş derinliği + hacim
SELECT COUNT(*) satir, MIN(Tarih) ilk, MAX(Tarih) son FROM bkm.OneriSiparis WITH(NOLOCK);  -- COUNT ağır; alternatif sys.partitions
-- SELECT SUM(p.rows) FROM sys.partitions p JOIN sys.objects o ON o.object_id=p.object_id WHERE o.name='OneriSiparis' AND p.index_id IN(0,1);

-- 2) Tahmin güvenilirliği backtest — güven-bandına (Miktar90 yoğunluğu) göre SMAPE
--    Naive tahmin: Miktar30(D) → gerçek Miktar30(D+30). 6 tarih, mağaza 1.
WITH dts AS (
  SELECT D FROM (VALUES
    (CONVERT(date,'2025-02-01')),(CONVERT(date,'2025-05-01')),(CONVERT(date,'2025-08-01')),
    (CONVERT(date,'2025-11-01')),(CONVERT(date,'2026-02-01')),(CONVERT(date,'2026-05-01'))
  ) v(D)
)
SELECT
  CASE WHEN a.Miktar90=0 THEN '0_olu' WHEN a.Miktar90<=3 THEN '1_seyrek'
       WHEN a.Miktar90<=10 THEN '2_orta' WHEN a.Miktar90<=30 THEN '3_yogun' ELSE '4_cokYogun' END guvenBucket,
  COUNT(*) n,
  AVG(a.Miktar30) tahmin_ort, AVG(b.Miktar30) fiili_ort,
  AVG(CASE WHEN (a.Miktar30+b.Miktar30)>0 THEN ABS(b.Miktar30-a.Miktar30)/((a.Miktar30+b.Miktar30)/2.0) END) smape
FROM dts
JOIN bkm.OneriSiparis a WITH(NOLOCK) ON a.Tarih=dts.D AND a.MekanId=1
JOIN bkm.OneriSiparis b WITH(NOLOCK) ON b.Tarih=DATEADD(day,30,dts.D) AND b.MekanId=1 AND b.StkId=a.StkId
GROUP BY CASE WHEN a.Miktar90=0 THEN '0_olu' WHEN a.Miktar90<=3 THEN '1_seyrek'
       WHEN a.Miktar90<=10 THEN '2_orta' WHEN a.Miktar90<=30 THEN '3_yogun' ELSE '4_cokYogun' END;

-- 3) Bakiye doğrulama: irsHrk kümülatif = OneriSiparis.Stok (mağaza 1, 8 ürün → 7/8 tam)
SELECT TOP 8 a.StkId, CONVERT(int,a.Stok) oneriStok,
  (SELECT SUM(h.ehAdetN) FROM dbo.irsHrk h WITH(NOLOCK)
    WHERE h.ehMekan=1 AND h.ehstkID=a.StkId AND h.ehTrhS<'2025-10-01') irsBakiye
FROM bkm.OneriSiparis a WITH(NOLOCK)
WHERE a.Tarih='2025-10-01' AND a.MekanId=1 AND a.Miktar90 BETWEEN 5 AND 50
ORDER BY a.StkId;

-- 4) Stoksuzluk / POS talep backtest (arındırma GEREKLİ: Stok<=0 dışla — yapay artefakt)
--    Talep = POS satış (ehTip 1,4,100; ehAdetN negatif → -SUM). ⚠️ iade (101) düşülmedi (küçük şişirme).
--    Bakiye kaynağı: irsHrk (StokBakiyeGunluk yalnız 2025-08..12, yetersiz). Mekan 12=depo hariç.
SELECT
  CASE WHEN a.Miktar90=0 THEN '0_olu' WHEN a.Miktar90<=3 THEN '1_seyrek'
       WHEN a.Miktar90<=10 THEN '2_orta' WHEN a.Miktar90<=30 THEN '3_yogun' ELSE '4_cokYogun' END guven,
  COUNT(*) n,
  AVG(CASE WHEN a.OneriSiparisAdet>0 THEN 1.0 ELSE 0 END) procFlagOran,
  AVG(ISNULL(s.demand,0)) ortTalep30,
  AVG(CASE WHEN ISNULL(s.demand,0) >= a.Stok AND a.Stok>0 THEN 1.0 ELSE 0 END) stoksuzOran  -- Stok>0 arındırma
FROM (SELECT StkId, Miktar90, Stok, OneriSiparisAdet FROM bkm.OneriSiparis WITH(NOLOCK)
      WHERE Tarih='2025-10-01' AND MekanId=1) a
LEFT JOIN (
  SELECT ehstkID, -SUM(ehAdetN) demand FROM dbo.irsHrk WITH(NOLOCK)
  WHERE ehMekan=1 AND ehTip IN (1,4,100) AND ehTrhS>'2025-10-01' AND ehTrhS<='2025-10-31'
  GROUP BY ehstkID
) s ON s.ehstkID=a.StkId
GROUP BY CASE WHEN a.Miktar90=0 THEN '0_olu' WHEN a.Miktar90<=3 THEN '1_seyrek'
       WHEN a.Miktar90<=10 THEN '2_orta' WHEN a.Miktar90<=30 THEN '3_yogun' ELSE '4_cokYogun' END;
