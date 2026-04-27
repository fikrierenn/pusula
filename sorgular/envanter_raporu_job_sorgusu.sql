/*
=====================================================
MaliyetRaporu-Ceren SQL Agent Job — Maliyet_Rapor Step
=====================================================
Bu sorgu her gece 00:05 civarında çalışır ve bkm.ENVANTER_RAPORU tablosunu doldurur.
Kaynak: msdb.dbo.sysjobsteps → JobAdi='MaliyetRaporu-Ceren', StepAdi='Maliyet_Rapor'

⚠️ BİLİNEN SORUN: Sınav süreli yayın paketleri (urnKtgrID=78, urnKtgr1ID=5, urnKtgr2ID=19)
   İst.Yolu'nda -236M TL hayalet negatif oluşturuyor. Bkz: envanter_raporu_analiz.md
=====================================================
*/

declare @tarih DATETIME = GETDATE()

CREATE TABLE #ORTMALIYET (stkID INT,brmMaliyet DECIMAL(18,4))
CREATE TABLE #WMSSTOK (stkID INT, stok DECIMAL(18,4))

INSERT INTO #WMSSTOK(stkID,stok)
SELECT pUStkID stkID, SUM(pUAdetN) Stok
FROM depo.paletUrnTnm  WITH(NOLOCK)
    INNER JOIN depo.paletTnm WITH(NOLOCK)  ON paletTnm.pID=paletUrnTnm.pUID
    INNER JOIN depo.adres WITH(NOLOCK)  ON pSonPozID=adrsID
WHERE pUAdetN>0 AND adrsAd NOT IN ('CK01')  AND pUID NOT IN ('42560','20353')
group by pUStkID


;WITH URUNLER  AS (
    SELECT u.stkID,u.stkKod,u.stkAd,u.k0Ad,u.k1Ad,u.urnMrkID,M.mrkAd,GRP.ktgrAd KTGR3,BRK.urnBarkod,urnKtgr2ID
    FROM urnKategori_vw U
        JOIN urnMrk M WITH(NOLOCK) ON M.mrkID = u.urnMrkID
        JOIN urnKtgr2 GRP WITH(NOLOCK) ON GRP.ktgrID = u.urnKtgr2ID
        LEFT JOIN urnBrkd BRK  WITH(NOLOCK) on BRK.urnBrkdStkID = u.stkID AND BRK.urnBrkdOnce = 0
    WHERE U.urnKtgr2ID not in (11,25,23,9,5,6)
        and urnTip = 0
        and U.stkKod not like '%.%'
        and U.stkID not in (81809,77328,200772,84642,59337,65462,64515,56761,22390,60318,128118,1644512)

),VERI AS (
SELECT [ehstkID] AS stkID
        ,u.urnBarkod AS [VarsayılanBarkod]
        ,mgz.mekanAd
        ,u.stkKod
        ,u.stkAd
        ,u.k0Ad
        ,u.k1Ad
        ,u.KTGR3
        ,u.mrkAd
        ,sum(CONVERT(FLOAT, stk.ehAdetN)) stok
    FROM DerinSISBkm.dbo.irsHrk stk WITH(NOLOCK)
        JOIN [DerinSISBkm].[dbo].[mekan_vw] mgz WITH(NOLOCK) ON mgz.mekanID = stk.ehMekan
        JOIN URUNLER u WITH(NOLOCK) ON u.stkID = stk.ehstkID
    where stk.ehTrhS <= @tarih and stk.ehAltDepo = 0  and mgz.mekanID in(1,4477,4478)
    GROUP BY [ehstkID]
        ,u.urnBarkod
        ,mgz.mekanAd
        ,u.stkKod
        ,u.stkAd
        ,u.k0Ad
        ,u.k1Ad
        ,u.KTGR3
        ,u.mrkAd
  UNION ALL
  SELECT S.stkID
        ,BRK.urnBarkod AS [VarsayılanBarkod]
        ,'WMS Depo' mekanAd
        ,u.stkKod
        ,u.stkAd
        ,u.k0Ad
        ,u.k1Ad
        ,u.KTGR3
        ,u.mrkAd
    ,CONVERT(INT,SUM(S.stok)) STOK
  FROM #WMSSTOK S WITH(NOLOCK)
    JOIN URUNLER u WITH(NOLOCK) ON u.stkID = s.stkID
    LEFT JOIN urnBrkd BRK  WITH(NOLOCK) on BRK.urnBrkdStkID = s.stkID AND BRK.urnBrkdOnce = 0
  GROUP BY  S.stkID
        ,BRK.urnBarkod
        ,u.stkKod
        ,u.stkAd
        ,u.k0Ad
        ,u.k1Ad
        ,u.KTGR3
        ,u.mrkAd
    union all
    select u.stkID
    ,u.urnBarkod barkod
    ,'Odak Depo' mekanAd
    ,u.stkKod
        ,u.stkAd
        ,u.k0Ad
        ,u.k1Ad
        ,u.KTGR3
        ,u.mrkAd
        ,convert(int,isnull(odak.StokMiktar,0))
        from URUNLER u  WITH(NOLOCK)
    join ent.odak_depo_Stok odak  WITH(NOLOCK) on odak.stkID=u.stkID
    where odak.StokMiktar>0

), OZET AS (
    SELECT * FROM VERI
    PIVOT(
        SUM(stok) FOR mekanAd IN( [FSM Mğz], [ÖZLÜCE Mğz], [İST YOLU Mğz], [WMS Depo],[Odak Depo])
    ) a
)
SELECT O.*
INTO #STOKENVANTER
FROM OZET O

SELECT s.stkID, CONVERT(FLOAT, bkm.TarihtekiUstFiyat(s.stkID, @tarih)) AS ustFiyat
INTO #FIYATLAR
FROM #STOKENVANTER s

INSERT INTO #ORTMALIYET(stkID,brmMaliyet)
SELECT s.stkID,COALESCE(MLYT.MALIYET,m.ORT_ALIS,SONRAKI.MALIYET,0) brmMaliyet
from #STOKENVANTER s
        OUTER APPLY (
            SELECT CONVERT(money,SUM(b.ehTutarN)/SUM(b.ehAdetN)) MALIYET
            FROM (
                SELECT top 5 ehAdetN, ehTutarN
                FROM fatAyr fa  WITH(NOLOCK)  JOIN fat f  WITH(NOLOCK)  on fa.ehID = f.eID and f.eTarih <= @tarih  and f.eTip =0 and f.eDurum <> 2
                where fa.ehstkID = s.stkID
                ORDER BY f.eTarih desc
            ) b
            HAVING SUM(b.ehAdetN) <>0
        ) MLYT
        OUTER APPLY (
                SELECT top 1 ehTutarN/ehAdetN MALIYET
                FROM fatAyr fa  WITH(NOLOCK)  JOIN fat f  WITH(NOLOCK)  on fa.ehID = f.eID and f.eTarih > @tarih and f.eTip =0 and f.eDurum <> 2
                where fa.ehstkID = s.stkID
                ORDER BY f.eTarih
        ) SONRAKI
        LEFT JOIN Aktarim.dbo.BKM_STOKLAR_MALIYETLI M on M.STKID = s.stkID

SELECT S.*
,isnull(s.[Odak Depo],0) ODAKSTOK
        ,ustFiyat
        ,k.kdvYuzdesi
        ,s.[FSM Mğz]*ustFiyat AS FSMStokTutar
        ,s.[ÖZLÜCE Mğz]*ustFiyat AS OzluceStokTutar
        ,s.[İST YOLU Mğz]*ustFiyat AS IstYoluStokTutar
        ,s.[WMS Depo]*ustFiyat AS WMSDepoStokTutar
        ,isnull(s.[Odak Depo],0) *ustFiyat as OdakDepoStokTutar

        ,s.[FSM Mğz]*O.brmMaliyet AS FSMStokTutarOrtMaliyet
        ,s.[Özlüce Mğz]*O.brmMaliyet AS OzluceStokTutarOrtMaliyet
        ,s.[İST YOLU Mğz]*O.brmMaliyet AS IstYoluStokTutarOrtMaliyet
        ,s.[WMS Depo]*O.brmMaliyet AS WMSDepoStokTutarOrtMaliyet
        ,isnull(s.[Odak Depo],0) *O.brmMaliyet AS OdakDepoStokTutarOrtMaliyet
INTO #SONDURUM
FROM  #STOKENVANTER S
    JOIN urn u on u.stkID=s.stkID
    JOIN kdvYuzde_vw k on k.ilkKDVID = u.KDVs
    LEFT JOIN #FIYATLAR f ON f.stkID = s.stkID
    LEFT JOIN #ORTMALIYET O ON O.stkID = S.stkID


INSERT INTO bkm.ENVANTER_RAPORU(
    Tarih,
    [Maliyet Tipi],
    KTGR3,kdvYuzde,
    [Fsm Stok Adet] ,[FSM Ürün Çeşit Sayı] ,[FSM Stok Maliyet] ,
    [Özlüce Stok Adet] ,[Özlüce Ürün Çeşit Sayı] ,[Özlüce Stok Maliyet] ,
    [İst.Yolu Stok Adet] ,[İs.Yolu Ürün Çeşit Sayı] ,[İst.Yolu Stok Maliyet] ,
    [Merkez Depo Stok Adet] ,[Merkez Depo Ürün Çeşit Sayı]  , [Merkez Depo Stok Maliyet] ,
    [Odak Depo Stok Adet] ,[Odak Depo Ürün Çeşit Sayı] , [Odak Depo Stok Maliyet]
)
    -- ÜstFiyat satırları
    SELECT @tarih Tarih,'ÜstFiyat' [Maliyet Tipi] ,S.KTGR3,s.kdvYuzdesi
        ,SUM(S.[FSM Mğz]) [Fsm Stok Adet],COUNT(DISTINCT IIF(isnull(S.[FSM Mğz],0)<>0,S.STKID,NULL)) [FSM Ürün Çeşit Sayı] ,SUM(S.FSMStokTutar) [FSM Stok Maliyet]
        ,SUM(s.[ÖZLÜCE Mğz])[Özlüce Stok Adet],COUNT(DISTINCT IIF(isnull(S.[ÖZLÜCE Mğz],0)<>0,S.STKID,NULL)) [Özlüce Ürün Çeşit Sayı] ,sum(s.OzluceStokTutar) [Özlüce Stok Maliyet]
        ,SUM(s.[İST YOLU Mğz])[İst.Yolu Stok Adet],COUNT(DISTINCT IIF(isnull(S.[İST YOLU Mğz],0)<>0,S.STKID,NULL)) [İs.Yolu Ürün Çeşit Sayı] ,sum(s.IstYoluStokTutar) [İst.Yolu Stok Maliyet]
        ,SUM(s.[WMS Depo])[Merkez Depo Stok Adet],COUNT(DISTINCT IIF(isnull(S.[WMS Depo],0)<>0,S.STKID,NULL)) [Merkez Depo Ürün Çeşit Sayı] ,sum(s.WMSDepoStokTutar) [Merkez Depo Stok Maliyet]
        ,SUM(s.[Odak Depo])[Odak Depo Stok Adet],COUNT(DISTINCT IIF(isnull(S.[Odak Depo],0)<>0,S.STKID,NULL)) [Odak Depo Ürün Çeşit Sayı] ,sum(s.OdakDepoStokTutar) [Odak Depo Stok Maliyet]
    FROM #SONDURUM S
    GROUP BY  S.KTGR3,s.kdvYuzdesi

    UNION ALL

    -- Ort.Maliyet satırları
    SELECT @tarih Tarih,'Ort.Maliyet' [Maliyet Tipi] ,S.KTGR3,s.kdvYuzdesi
        ,SUM(S.[FSM Mğz]) [Fsm Stok Adet],COUNT(DISTINCT IIF(isnull(S.[FSM Mğz],0)<>0,S.STKID,NULL)) [FSM Ürün Çeşit Sayı] ,SUM(S.FSMStokTutarOrtMaliyet) [FSM Stok Maliyet]
        ,SUM(s.[ÖZLÜCE Mğz])[Özlüce Stok Adet],COUNT(DISTINCT IIF(isnull(S.[ÖZLÜCE Mğz],0)<>0,S.STKID,NULL)) [Özlüce Ürün Çeşit Sayı] ,sum(s.OzluceStokTutarOrtMaliyet) [Özlüce Stok Maliyet]
        ,SUM(s.[İST YOLU Mğz])[İst.Yolu Stok Adet],COUNT(DISTINCT IIF(isnull(S.[İST YOLU Mğz],0)<>0,S.STKID,NULL)) [İs.Yolu Ürün Çeşit Sayı] ,sum(s.IstYoluStokTutarOrtMaliyet) [İst.Yolu Stok Maliyet]
        ,SUM(s.[WMS Depo])[Merkez Depo Stok Adet],COUNT(DISTINCT IIF(isnull(S.[WMS Depo],0)<>0,S.STKID,NULL)) [Merkez Depo Ürün Çeşit Sayı] ,sum(s.WMSDepoStokTutarOrtMaliyet) [Merkez Depo Stok Maliyet]
        ,SUM(s.[Odak Depo])[Merkez Depo Stok Adet],COUNT(DISTINCT IIF(isnull(S.[Odak Depo],0)<>0,S.STKID,NULL)) [Merkez Depo Ürün Çeşit Sayı] ,sum(s.OdakDepoStokTutarOrtMaliyet) [Merkez Depo Stok Maliyet]
    FROM #SONDURUM S
    GROUP BY  S.KTGR3,s.kdvYuzdesi


DROP TABLE #STOKENVANTER
GO
DROP TABLE #ORTMALIYET
GO
DROP TABLE #FIYATLAR
GO
DROP TABLE #SONDURUM
GO
DROP TABLE #WMSSTOK
