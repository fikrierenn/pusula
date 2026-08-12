/*
  Stoğu/satışı olan Kırtasiye+Oyuncak+Hediyelik ürün — TEK SATIR/ÜRÜN, tam-geniş (TEMP tablo).
  Kolonlar: BarkodAna + depo_stok(WMS RAF+GR) + FSM/OZL/IST anlık stok
            + 129 şube satış (FSM_/OZL_/IST_) + 43 e-tic satış (ETIC_) 2023-01…2026-07.
  Şube: DerinSIS irs_vw NET (eTip 1,4,3,5,100,101, -1*SUM iade düşülü), eDurum=1, urnKtgr2ID IN (10,12,16).
  E-tic: OPENQUERY(ODAKJOKER) uzakta AGGREGATE (ham detay çekmez=HIZLI), J_ITEMS.DERINSIS_ID=stkID, NET (STATUS NOT IN 2004,2005,2010);
         sonra lokal urn join ile kategori (10,12,16) süzülür (küçük agregat üstünde ucuz).
  DEPO = depo.stok_adres_palet_vw RAF(0)+GR(1), CK/CK01(tip2) HARİÇ. Mağaza stok = stokSon_vw. Tüm rakam int, NULL=0.
*/
SET NOCOUNT ON;
DECLARE @T1 date='20230101', @T2 date='20260801';   -- @T2 üst sınır HARİÇ

-- #sat : birleşik satış (şube + e-tic), stkID × kol × adet
IF OBJECT_ID('tempdb..#sat') IS NOT NULL DROP TABLE #sat;
CREATE TABLE #sat (stkID int, kol varchar(20), Adet int);

INSERT #sat (stkID, kol, Adet)          -- ŞUBE (irs_vw, net)
SELECT u.stkID,
    CASE i.eMekan WHEN 1 THEN 'FSM' WHEN 4477 THEN 'OZL' WHEN 4478 THEN 'IST' END + '_' + format(i.eTarih,'yyyy-MM'),
    convert(int,-1*SUM(i.ehAdet))
FROM irs_vw i WITH(NOLOCK) JOIN urn u WITH(NOLOCK) ON u.stkID=i.ehStkID
WHERE i.eTip IN (1,4,3,5,100,101) AND i.eTarih>=@T1 AND i.eTarih<@T2 AND (i.eDurum=1 OR i.eTip IN (100,101))
    AND i.eMekan IN (1,4477,4478) AND u.urnKtgr2ID IN (10,12,16)
GROUP BY u.stkID, CASE i.eMekan WHEN 1 THEN 'FSM' WHEN 4477 THEN 'OZL' WHEN 4478 THEN 'IST' END + '_' + format(i.eTarih,'yyyy-MM');

INSERT #sat (stkID, kol, Adet)          -- E-TİCARET (OPENQUERY uzak-aggregate + lokal kategori süz)
SELECT x.stkID, 'ETIC_'+x.ay, convert(int,x.qty)
FROM OPENQUERY(ODAKJOKER, '
    SELECT i.DERINSIS_ID AS stkID,
           CONVERT(varchar(4),YEAR(o.ORDERDATE))+''-''+RIGHT(''0''+CONVERT(varchar(2),MONTH(o.ORDERDATE)),2) AS ay,
           SUM(d.QUANTITY) AS qty
    FROM JOKER.dbo.J_ORDER_DETAILS d
        JOIN JOKER.dbo.J_ORDERS o ON o.ORDERID=d.ORDERREF
        JOIN JOKER.dbo.J_ITEMS  i ON i.LOGICALREF=d.ITEMREF
    WHERE o.ORDERDATE>=''20230101'' AND o.ORDERDATE<''20260801'' AND i.DERINSIS_ID>0 AND d.STATUS NOT IN (2004,2005,2010)
    GROUP BY i.DERINSIS_ID, CONVERT(varchar(4),YEAR(o.ORDERDATE))+''-''+RIGHT(''0''+CONVERT(varchar(2),MONTH(o.ORDERDATE)),2)') x
    JOIN urn u WITH(NOLOCK) ON u.stkID=x.stkID AND u.urnKtgr2ID IN (10,12,16);
CREATE CLUSTERED INDEX ix_sat ON #sat(stkID);

-- #depo : WMS hücre RAF(0)+GR(1), CK/CK01 hariç
IF OBJECT_ID('tempdb..#depo') IS NOT NULL DROP TABLE #depo;
SELECT stkID, convert(int,SUM(Stok)) AS DepoStok
INTO #depo FROM depo.stok_adres_palet_vw WHERE Stok>0 AND adrsAlanTipID IN (0,1) GROUP BY stkID;
CREATE CLUSTERED INDEX ix_depo ON #depo(stkID);

-- #mstok : mağaza anlık stok
IF OBJECT_ID('tempdb..#mstok') IS NOT NULL DROP TABLE #mstok;
SELECT ehstkID AS stkID,
    convert(int,SUM(case when ehMekan=1    then stok end)) FSM_stok,
    convert(int,SUM(case when ehMekan=4477 then stok end)) OZL_stok,
    convert(int,SUM(case when ehMekan=4478 then stok end)) IST_stok
INTO #mstok FROM stokSon_vw WHERE ehMekan IN (1,4477,4478) GROUP BY ehstkID;
CREATE CLUSTERED INDEX ix_mstok ON #mstok(stkID);

-- FINAL : tek satır/ürün
SELECT b.stkID,b.BarkodAna,b.stkAd,b.mrkAd,b.Kategori3
    ,isnull(d.DepoStok,0)   depo_stok
    ,isnull(ms.FSM_stok,0)  FSM_stok
    ,isnull(ms.OZL_stok,0)  OZL_stok
    ,isnull(ms.IST_stok,0)  IST_stok
    ,isnull(p.[FSM_2023-01],0) [FSM_2023-01],isnull(p.[FSM_2023-02],0) [FSM_2023-02],isnull(p.[FSM_2023-03],0) [FSM_2023-03],isnull(p.[FSM_2023-04],0) [FSM_2023-04],
    isnull(p.[FSM_2023-05],0) [FSM_2023-05],isnull(p.[FSM_2023-06],0) [FSM_2023-06],isnull(p.[FSM_2023-07],0) [FSM_2023-07],isnull(p.[FSM_2023-08],0) [FSM_2023-08],
    isnull(p.[FSM_2023-09],0) [FSM_2023-09],isnull(p.[FSM_2023-10],0) [FSM_2023-10],isnull(p.[FSM_2023-11],0) [FSM_2023-11],isnull(p.[FSM_2023-12],0) [FSM_2023-12],
    isnull(p.[FSM_2024-01],0) [FSM_2024-01],isnull(p.[FSM_2024-02],0) [FSM_2024-02],isnull(p.[FSM_2024-03],0) [FSM_2024-03],isnull(p.[FSM_2024-04],0) [FSM_2024-04],
    isnull(p.[FSM_2024-05],0) [FSM_2024-05],isnull(p.[FSM_2024-06],0) [FSM_2024-06],isnull(p.[FSM_2024-07],0) [FSM_2024-07],isnull(p.[FSM_2024-08],0) [FSM_2024-08],
    isnull(p.[FSM_2024-09],0) [FSM_2024-09],isnull(p.[FSM_2024-10],0) [FSM_2024-10],isnull(p.[FSM_2024-11],0) [FSM_2024-11],isnull(p.[FSM_2024-12],0) [FSM_2024-12],
    isnull(p.[FSM_2025-01],0) [FSM_2025-01],isnull(p.[FSM_2025-02],0) [FSM_2025-02],isnull(p.[FSM_2025-03],0) [FSM_2025-03],isnull(p.[FSM_2025-04],0) [FSM_2025-04],
    isnull(p.[FSM_2025-05],0) [FSM_2025-05],isnull(p.[FSM_2025-06],0) [FSM_2025-06],isnull(p.[FSM_2025-07],0) [FSM_2025-07],isnull(p.[FSM_2025-08],0) [FSM_2025-08],
    isnull(p.[FSM_2025-09],0) [FSM_2025-09],isnull(p.[FSM_2025-10],0) [FSM_2025-10],isnull(p.[FSM_2025-11],0) [FSM_2025-11],isnull(p.[FSM_2025-12],0) [FSM_2025-12],
    isnull(p.[FSM_2026-01],0) [FSM_2026-01],isnull(p.[FSM_2026-02],0) [FSM_2026-02],isnull(p.[FSM_2026-03],0) [FSM_2026-03],isnull(p.[FSM_2026-04],0) [FSM_2026-04],
    isnull(p.[FSM_2026-05],0) [FSM_2026-05],isnull(p.[FSM_2026-06],0) [FSM_2026-06],isnull(p.[FSM_2026-07],0) [FSM_2026-07],isnull(p.[OZL_2023-01],0) [OZL_2023-01],
    isnull(p.[OZL_2023-02],0) [OZL_2023-02],isnull(p.[OZL_2023-03],0) [OZL_2023-03],isnull(p.[OZL_2023-04],0) [OZL_2023-04],isnull(p.[OZL_2023-05],0) [OZL_2023-05],
    isnull(p.[OZL_2023-06],0) [OZL_2023-06],isnull(p.[OZL_2023-07],0) [OZL_2023-07],isnull(p.[OZL_2023-08],0) [OZL_2023-08],isnull(p.[OZL_2023-09],0) [OZL_2023-09],
    isnull(p.[OZL_2023-10],0) [OZL_2023-10],isnull(p.[OZL_2023-11],0) [OZL_2023-11],isnull(p.[OZL_2023-12],0) [OZL_2023-12],isnull(p.[OZL_2024-01],0) [OZL_2024-01],
    isnull(p.[OZL_2024-02],0) [OZL_2024-02],isnull(p.[OZL_2024-03],0) [OZL_2024-03],isnull(p.[OZL_2024-04],0) [OZL_2024-04],isnull(p.[OZL_2024-05],0) [OZL_2024-05],
    isnull(p.[OZL_2024-06],0) [OZL_2024-06],isnull(p.[OZL_2024-07],0) [OZL_2024-07],isnull(p.[OZL_2024-08],0) [OZL_2024-08],isnull(p.[OZL_2024-09],0) [OZL_2024-09],
    isnull(p.[OZL_2024-10],0) [OZL_2024-10],isnull(p.[OZL_2024-11],0) [OZL_2024-11],isnull(p.[OZL_2024-12],0) [OZL_2024-12],isnull(p.[OZL_2025-01],0) [OZL_2025-01],
    isnull(p.[OZL_2025-02],0) [OZL_2025-02],isnull(p.[OZL_2025-03],0) [OZL_2025-03],isnull(p.[OZL_2025-04],0) [OZL_2025-04],isnull(p.[OZL_2025-05],0) [OZL_2025-05],
    isnull(p.[OZL_2025-06],0) [OZL_2025-06],isnull(p.[OZL_2025-07],0) [OZL_2025-07],isnull(p.[OZL_2025-08],0) [OZL_2025-08],isnull(p.[OZL_2025-09],0) [OZL_2025-09],
    isnull(p.[OZL_2025-10],0) [OZL_2025-10],isnull(p.[OZL_2025-11],0) [OZL_2025-11],isnull(p.[OZL_2025-12],0) [OZL_2025-12],isnull(p.[OZL_2026-01],0) [OZL_2026-01],
    isnull(p.[OZL_2026-02],0) [OZL_2026-02],isnull(p.[OZL_2026-03],0) [OZL_2026-03],isnull(p.[OZL_2026-04],0) [OZL_2026-04],isnull(p.[OZL_2026-05],0) [OZL_2026-05],
    isnull(p.[OZL_2026-06],0) [OZL_2026-06],isnull(p.[OZL_2026-07],0) [OZL_2026-07],isnull(p.[IST_2023-01],0) [IST_2023-01],isnull(p.[IST_2023-02],0) [IST_2023-02],
    isnull(p.[IST_2023-03],0) [IST_2023-03],isnull(p.[IST_2023-04],0) [IST_2023-04],isnull(p.[IST_2023-05],0) [IST_2023-05],isnull(p.[IST_2023-06],0) [IST_2023-06],
    isnull(p.[IST_2023-07],0) [IST_2023-07],isnull(p.[IST_2023-08],0) [IST_2023-08],isnull(p.[IST_2023-09],0) [IST_2023-09],isnull(p.[IST_2023-10],0) [IST_2023-10],
    isnull(p.[IST_2023-11],0) [IST_2023-11],isnull(p.[IST_2023-12],0) [IST_2023-12],isnull(p.[IST_2024-01],0) [IST_2024-01],isnull(p.[IST_2024-02],0) [IST_2024-02],
    isnull(p.[IST_2024-03],0) [IST_2024-03],isnull(p.[IST_2024-04],0) [IST_2024-04],isnull(p.[IST_2024-05],0) [IST_2024-05],isnull(p.[IST_2024-06],0) [IST_2024-06],
    isnull(p.[IST_2024-07],0) [IST_2024-07],isnull(p.[IST_2024-08],0) [IST_2024-08],isnull(p.[IST_2024-09],0) [IST_2024-09],isnull(p.[IST_2024-10],0) [IST_2024-10],
    isnull(p.[IST_2024-11],0) [IST_2024-11],isnull(p.[IST_2024-12],0) [IST_2024-12],isnull(p.[IST_2025-01],0) [IST_2025-01],isnull(p.[IST_2025-02],0) [IST_2025-02],
    isnull(p.[IST_2025-03],0) [IST_2025-03],isnull(p.[IST_2025-04],0) [IST_2025-04],isnull(p.[IST_2025-05],0) [IST_2025-05],isnull(p.[IST_2025-06],0) [IST_2025-06],
    isnull(p.[IST_2025-07],0) [IST_2025-07],isnull(p.[IST_2025-08],0) [IST_2025-08],isnull(p.[IST_2025-09],0) [IST_2025-09],isnull(p.[IST_2025-10],0) [IST_2025-10],
    isnull(p.[IST_2025-11],0) [IST_2025-11],isnull(p.[IST_2025-12],0) [IST_2025-12],isnull(p.[IST_2026-01],0) [IST_2026-01],isnull(p.[IST_2026-02],0) [IST_2026-02],
    isnull(p.[IST_2026-03],0) [IST_2026-03],isnull(p.[IST_2026-04],0) [IST_2026-04],isnull(p.[IST_2026-05],0) [IST_2026-05],isnull(p.[IST_2026-06],0) [IST_2026-06],
    isnull(p.[IST_2026-07],0) [IST_2026-07],isnull(p.[ETIC_2023-01],0) [ETIC_2023-01],isnull(p.[ETIC_2023-02],0) [ETIC_2023-02],isnull(p.[ETIC_2023-03],0) [ETIC_2023-03],
    isnull(p.[ETIC_2023-04],0) [ETIC_2023-04],isnull(p.[ETIC_2023-05],0) [ETIC_2023-05],isnull(p.[ETIC_2023-06],0) [ETIC_2023-06],isnull(p.[ETIC_2023-07],0) [ETIC_2023-07],
    isnull(p.[ETIC_2023-08],0) [ETIC_2023-08],isnull(p.[ETIC_2023-09],0) [ETIC_2023-09],isnull(p.[ETIC_2023-10],0) [ETIC_2023-10],isnull(p.[ETIC_2023-11],0) [ETIC_2023-11],
    isnull(p.[ETIC_2023-12],0) [ETIC_2023-12],isnull(p.[ETIC_2024-01],0) [ETIC_2024-01],isnull(p.[ETIC_2024-02],0) [ETIC_2024-02],isnull(p.[ETIC_2024-03],0) [ETIC_2024-03],
    isnull(p.[ETIC_2024-04],0) [ETIC_2024-04],isnull(p.[ETIC_2024-05],0) [ETIC_2024-05],isnull(p.[ETIC_2024-06],0) [ETIC_2024-06],isnull(p.[ETIC_2024-07],0) [ETIC_2024-07],
    isnull(p.[ETIC_2024-08],0) [ETIC_2024-08],isnull(p.[ETIC_2024-09],0) [ETIC_2024-09],isnull(p.[ETIC_2024-10],0) [ETIC_2024-10],isnull(p.[ETIC_2024-11],0) [ETIC_2024-11],
    isnull(p.[ETIC_2024-12],0) [ETIC_2024-12],isnull(p.[ETIC_2025-01],0) [ETIC_2025-01],isnull(p.[ETIC_2025-02],0) [ETIC_2025-02],isnull(p.[ETIC_2025-03],0) [ETIC_2025-03],
    isnull(p.[ETIC_2025-04],0) [ETIC_2025-04],isnull(p.[ETIC_2025-05],0) [ETIC_2025-05],isnull(p.[ETIC_2025-06],0) [ETIC_2025-06],isnull(p.[ETIC_2025-07],0) [ETIC_2025-07],
    isnull(p.[ETIC_2025-08],0) [ETIC_2025-08],isnull(p.[ETIC_2025-09],0) [ETIC_2025-09],isnull(p.[ETIC_2025-10],0) [ETIC_2025-10],isnull(p.[ETIC_2025-11],0) [ETIC_2025-11],
    isnull(p.[ETIC_2025-12],0) [ETIC_2025-12],isnull(p.[ETIC_2026-01],0) [ETIC_2026-01],isnull(p.[ETIC_2026-02],0) [ETIC_2026-02],isnull(p.[ETIC_2026-03],0) [ETIC_2026-03],
    isnull(p.[ETIC_2026-04],0) [ETIC_2026-04],isnull(p.[ETIC_2026-05],0) [ETIC_2026-05],isnull(p.[ETIC_2026-06],0) [ETIC_2026-06],isnull(p.[ETIC_2026-07],0) [ETIC_2026-07]
FROM bkm.UrunBilgi b
    LEFT JOIN #depo  d  ON d.stkID = b.stkID
    LEFT JOIN #mstok ms ON ms.stkID = b.stkID
    LEFT JOIN (
        SELECT stkID,
        [FSM_2023-01],[FSM_2023-02],[FSM_2023-03],[FSM_2023-04],[FSM_2023-05],[FSM_2023-06],
        [FSM_2023-07],[FSM_2023-08],[FSM_2023-09],[FSM_2023-10],[FSM_2023-11],[FSM_2023-12],
        [FSM_2024-01],[FSM_2024-02],[FSM_2024-03],[FSM_2024-04],[FSM_2024-05],[FSM_2024-06],
        [FSM_2024-07],[FSM_2024-08],[FSM_2024-09],[FSM_2024-10],[FSM_2024-11],[FSM_2024-12],
        [FSM_2025-01],[FSM_2025-02],[FSM_2025-03],[FSM_2025-04],[FSM_2025-05],[FSM_2025-06],
        [FSM_2025-07],[FSM_2025-08],[FSM_2025-09],[FSM_2025-10],[FSM_2025-11],[FSM_2025-12],
        [FSM_2026-01],[FSM_2026-02],[FSM_2026-03],[FSM_2026-04],[FSM_2026-05],[FSM_2026-06],
        [FSM_2026-07],[OZL_2023-01],[OZL_2023-02],[OZL_2023-03],[OZL_2023-04],[OZL_2023-05],
        [OZL_2023-06],[OZL_2023-07],[OZL_2023-08],[OZL_2023-09],[OZL_2023-10],[OZL_2023-11],
        [OZL_2023-12],[OZL_2024-01],[OZL_2024-02],[OZL_2024-03],[OZL_2024-04],[OZL_2024-05],
        [OZL_2024-06],[OZL_2024-07],[OZL_2024-08],[OZL_2024-09],[OZL_2024-10],[OZL_2024-11],
        [OZL_2024-12],[OZL_2025-01],[OZL_2025-02],[OZL_2025-03],[OZL_2025-04],[OZL_2025-05],
        [OZL_2025-06],[OZL_2025-07],[OZL_2025-08],[OZL_2025-09],[OZL_2025-10],[OZL_2025-11],
        [OZL_2025-12],[OZL_2026-01],[OZL_2026-02],[OZL_2026-03],[OZL_2026-04],[OZL_2026-05],
        [OZL_2026-06],[OZL_2026-07],[IST_2023-01],[IST_2023-02],[IST_2023-03],[IST_2023-04],
        [IST_2023-05],[IST_2023-06],[IST_2023-07],[IST_2023-08],[IST_2023-09],[IST_2023-10],
        [IST_2023-11],[IST_2023-12],[IST_2024-01],[IST_2024-02],[IST_2024-03],[IST_2024-04],
        [IST_2024-05],[IST_2024-06],[IST_2024-07],[IST_2024-08],[IST_2024-09],[IST_2024-10],
        [IST_2024-11],[IST_2024-12],[IST_2025-01],[IST_2025-02],[IST_2025-03],[IST_2025-04],
        [IST_2025-05],[IST_2025-06],[IST_2025-07],[IST_2025-08],[IST_2025-09],[IST_2025-10],
        [IST_2025-11],[IST_2025-12],[IST_2026-01],[IST_2026-02],[IST_2026-03],[IST_2026-04],
        [IST_2026-05],[IST_2026-06],[IST_2026-07],[ETIC_2023-01],[ETIC_2023-02],[ETIC_2023-03],
        [ETIC_2023-04],[ETIC_2023-05],[ETIC_2023-06],[ETIC_2023-07],[ETIC_2023-08],[ETIC_2023-09],
        [ETIC_2023-10],[ETIC_2023-11],[ETIC_2023-12],[ETIC_2024-01],[ETIC_2024-02],[ETIC_2024-03],
        [ETIC_2024-04],[ETIC_2024-05],[ETIC_2024-06],[ETIC_2024-07],[ETIC_2024-08],[ETIC_2024-09],
        [ETIC_2024-10],[ETIC_2024-11],[ETIC_2024-12],[ETIC_2025-01],[ETIC_2025-02],[ETIC_2025-03],
        [ETIC_2025-04],[ETIC_2025-05],[ETIC_2025-06],[ETIC_2025-07],[ETIC_2025-08],[ETIC_2025-09],
        [ETIC_2025-10],[ETIC_2025-11],[ETIC_2025-12],[ETIC_2026-01],[ETIC_2026-02],[ETIC_2026-03],
        [ETIC_2026-04],[ETIC_2026-05],[ETIC_2026-06],[ETIC_2026-07]
        FROM #sat
        PIVOT ( SUM(Adet) FOR kol IN (
        [FSM_2023-01],[FSM_2023-02],[FSM_2023-03],[FSM_2023-04],[FSM_2023-05],[FSM_2023-06],
        [FSM_2023-07],[FSM_2023-08],[FSM_2023-09],[FSM_2023-10],[FSM_2023-11],[FSM_2023-12],
        [FSM_2024-01],[FSM_2024-02],[FSM_2024-03],[FSM_2024-04],[FSM_2024-05],[FSM_2024-06],
        [FSM_2024-07],[FSM_2024-08],[FSM_2024-09],[FSM_2024-10],[FSM_2024-11],[FSM_2024-12],
        [FSM_2025-01],[FSM_2025-02],[FSM_2025-03],[FSM_2025-04],[FSM_2025-05],[FSM_2025-06],
        [FSM_2025-07],[FSM_2025-08],[FSM_2025-09],[FSM_2025-10],[FSM_2025-11],[FSM_2025-12],
        [FSM_2026-01],[FSM_2026-02],[FSM_2026-03],[FSM_2026-04],[FSM_2026-05],[FSM_2026-06],
        [FSM_2026-07],[OZL_2023-01],[OZL_2023-02],[OZL_2023-03],[OZL_2023-04],[OZL_2023-05],
        [OZL_2023-06],[OZL_2023-07],[OZL_2023-08],[OZL_2023-09],[OZL_2023-10],[OZL_2023-11],
        [OZL_2023-12],[OZL_2024-01],[OZL_2024-02],[OZL_2024-03],[OZL_2024-04],[OZL_2024-05],
        [OZL_2024-06],[OZL_2024-07],[OZL_2024-08],[OZL_2024-09],[OZL_2024-10],[OZL_2024-11],
        [OZL_2024-12],[OZL_2025-01],[OZL_2025-02],[OZL_2025-03],[OZL_2025-04],[OZL_2025-05],
        [OZL_2025-06],[OZL_2025-07],[OZL_2025-08],[OZL_2025-09],[OZL_2025-10],[OZL_2025-11],
        [OZL_2025-12],[OZL_2026-01],[OZL_2026-02],[OZL_2026-03],[OZL_2026-04],[OZL_2026-05],
        [OZL_2026-06],[OZL_2026-07],[IST_2023-01],[IST_2023-02],[IST_2023-03],[IST_2023-04],
        [IST_2023-05],[IST_2023-06],[IST_2023-07],[IST_2023-08],[IST_2023-09],[IST_2023-10],
        [IST_2023-11],[IST_2023-12],[IST_2024-01],[IST_2024-02],[IST_2024-03],[IST_2024-04],
        [IST_2024-05],[IST_2024-06],[IST_2024-07],[IST_2024-08],[IST_2024-09],[IST_2024-10],
        [IST_2024-11],[IST_2024-12],[IST_2025-01],[IST_2025-02],[IST_2025-03],[IST_2025-04],
        [IST_2025-05],[IST_2025-06],[IST_2025-07],[IST_2025-08],[IST_2025-09],[IST_2025-10],
        [IST_2025-11],[IST_2025-12],[IST_2026-01],[IST_2026-02],[IST_2026-03],[IST_2026-04],
        [IST_2026-05],[IST_2026-06],[IST_2026-07],[ETIC_2023-01],[ETIC_2023-02],[ETIC_2023-03],
        [ETIC_2023-04],[ETIC_2023-05],[ETIC_2023-06],[ETIC_2023-07],[ETIC_2023-08],[ETIC_2023-09],
        [ETIC_2023-10],[ETIC_2023-11],[ETIC_2023-12],[ETIC_2024-01],[ETIC_2024-02],[ETIC_2024-03],
        [ETIC_2024-04],[ETIC_2024-05],[ETIC_2024-06],[ETIC_2024-07],[ETIC_2024-08],[ETIC_2024-09],
        [ETIC_2024-10],[ETIC_2024-11],[ETIC_2024-12],[ETIC_2025-01],[ETIC_2025-02],[ETIC_2025-03],
        [ETIC_2025-04],[ETIC_2025-05],[ETIC_2025-06],[ETIC_2025-07],[ETIC_2025-08],[ETIC_2025-09],
        [ETIC_2025-10],[ETIC_2025-11],[ETIC_2025-12],[ETIC_2026-01],[ETIC_2026-02],[ETIC_2026-03],
        [ETIC_2026-04],[ETIC_2026-05],[ETIC_2026-06],[ETIC_2026-07]
        ) ) pv
    ) p ON p.stkID = b.stkID
WHERE b.Kat3ID IN (10,12,16);
