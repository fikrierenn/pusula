-- 2026-06-18 — B-111 WMS bekleyen toplama keşfi (DerinSISBkm)
-- Soru: "kaç sipariş raflanmayı/toplanmayı bekliyor" kartı için temiz bekleyen-backlog var mı?
-- BULGU: depo.emirAyr.emTamam=0 KİRLİ — 2.422 emir / ~2M satır / 4,3M kalan adet,
--        header kTarih 2021'e kadar gidiyor. depo.emir.emDurum=1 hem 2021 zombi hem
--        taze emir kapsıyor → temiz açık/kapalı bayrağı YOK. WMS açık emirleri temizlemiyor.
--        Gerçek aktif backlog son günlerde minik (1-3g: 5 emir/877 adet). Ham sayım = çöp.
--        metrics.yaml wms_bekleyen_toplama aslında J_ORDERS/J_ORDER_DETAILS (e-tic) tarafı.
-- KARAR: B-111 parked — A) emirAyr recency-filtreli + zombi-uyarısı, VEYA B) J_ORDERS e-tic. (sonraki tur)

-- 1) emTamam 0/1 dağılımı (son 30g) — bekleyen emAdetTop=0 (tamamlanınca dolar)
SELECT emTamam, COUNT(*) AS Emir, CAST(ISNULL(SUM(emAdetTop),0) AS int) AS Adet,
       MIN(emTarih) AS EnEski, MAX(emTarih) AS EnYeni
FROM DerinSISBkm.depo.emirAyr WITH(NOLOCK)
WHERE emTarih >= DATEADD(DAY,-30,GETDATE())
GROUP BY emTamam;

-- 2) Bekleyen (emTamam=0) yaş kovaları — kalan adet = emAdet - emAdetTop
SELECT CASE WHEN emTarih>=CAST(GETDATE() AS date) THEN '0-bugun'
            WHEN emTarih>=DATEADD(DAY,-3,CAST(GETDATE() AS date)) THEN '1-3gun'
            WHEN emTarih>=DATEADD(DAY,-7,CAST(GETDATE() AS date)) THEN '4-7gun'
            ELSE '7gun+' END AS Kova,
       COUNT(*) AS Satir, COUNT(DISTINCT emAyrID) AS Emir,
       CAST(SUM(emAdet-emAdetTop) AS int) AS KalanAdet,
       SUM(CASE WHEN emIsleniyor<>0 THEN 1 ELSE 0 END) AS Isleniyor
FROM DerinSISBkm.depo.emirAyr WITH(NOLOCK)
WHERE emTamam=0
GROUP BY CASE WHEN emTarih>=CAST(GETDATE() AS date) THEN '0-bugun'
              WHEN emTarih>=DATEADD(DAY,-3,CAST(GETDATE() AS date)) THEN '1-3gun'
              WHEN emTarih>=DATEADD(DAY,-7,CAST(GETDATE() AS date)) THEN '4-7gun'
              ELSE '7gun+' END;

-- 3) Bekleyen satırı olan emirlerin header durumu (emDurum/emTip) — zombi pile kapalı mı?
--    FK: depo.emirAyr.emAyrID = depo.emir.emID. emDurum=1 açık (2021→2026 karışık), 2=kapalı(eski/az).
SELECT e.emDurum, e.emTip, COUNT(*) AS Emir, MIN(e.kTarih) AS EnEski, MAX(e.kTarih) AS EnYeni
FROM DerinSISBkm.depo.emir e WITH(NOLOCK)
WHERE EXISTS (SELECT 1 FROM DerinSISBkm.depo.emirAyr a WITH(NOLOCK)
             WHERE a.emAyrID=e.emID AND a.emTamam=0)
GROUP BY e.emDurum, e.emTip;
