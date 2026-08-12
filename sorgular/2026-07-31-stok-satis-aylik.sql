/*
  Soru:  Stoğu olan ürün — Depo(WMS anlık hücre)/FSM/Özlüce/İst.Yolu stok + 2023'ten beri AY-AY satış (mağaza).
  DB:    DerinSISBkm. Kaynak: depo.stok_adres_palet_vw (DEPO = WMS fiziki hücre) + dbo.irsHrk (mağaza stok + aylık satış) + bkm.UrunBilgi.
  ⚠ DEPO (mekan 12) = WMS HÜCRE stoğu (depo.stok_adres_palet_vw), irsHrk kümülatif DEĞİL (o muhasebe-hareketi, fiziki envanteri vermez — kullanıcı 2026-07-31).
     Mağazalarda WMS yok → FSM/Özlüce/İst irsHrk kümülatif kalır.
  Konvansiyon: mağaza stok = SUM(ehAdetN) ehAltDepo=0; satış = ehTip IN (1,4,100), -SUM(ehAdetN) (çıkış negatif → pozitif); iade (3,5,101) HARİÇ (brüt).
  Tek-script: #stok + #satis doldurur → dinamik PIVOT ile @mekan mağazasının 43-ay-kolonlu wide raporunu üretir. @mekan değiştir, 3 kez çalıştır (FSM/Özlüce/İst).
*/
SET NOCOUNT ON;

-------------------------------------------------------------------------------
-- #stok : ürün × lokasyon anlık stok (DEPO=WMS hücre · mağaza=irsHrk kümülatif)
-------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#stok') IS NOT NULL DROP TABLE #stok;
SELECT stkID,
    CAST(SUM(CASE WHEN loc = 'Depo'   THEN adet ELSE 0 END) AS int) AS Depo,
    CAST(SUM(CASE WHEN loc = 'FSM'    THEN adet ELSE 0 END) AS int) AS FSM,
    CAST(SUM(CASE WHEN loc = 'Ozluce' THEN adet ELSE 0 END) AS int) AS Ozluce,
    CAST(SUM(CASE WHEN loc = 'Ist'    THEN adet ELSE 0 END) AS int) AS Ist
INTO #stok
FROM (
    -- DEPO = WMS anlık hücre stoğu — SADECE RAF(0)+GR(1), CK01 HARİÇ (kullanıcı 2026-07-31)
    SELECT stkID, 'Depo' AS loc, SUM(Stok) AS adet
    FROM depo.stok_adres_palet_vw
    WHERE Stok > 0 AND adrsAlanTipID IN (0, 1) AND adrsAd <> 'CK01'
    GROUP BY stkID
    UNION ALL
    -- MAĞAZA = irsHrk kümülatif kalan
    SELECT ehstkID,
           CASE ehMekan WHEN 1 THEN 'FSM' WHEN 4477 THEN 'Ozluce' WHEN 4478 THEN 'Ist' END,
           SUM(ehAdetN)
    FROM dbo.irsHrk WITH(NOLOCK)
    WHERE ehMekan IN (1, 4477, 4478) AND ehAltDepo = 0
    GROUP BY ehstkID, ehMekan
) u
GROUP BY stkID;

-- stoğu olan = en az bir lokasyonda pozitif
DELETE FROM #stok WHERE Depo <= 0 AND FSM <= 0 AND Ozluce <= 0 AND Ist <= 0;
-- SADECE Kırtasiye + Oyuncak + Hediyelik (Kategori3; Kitap/Akademi/Çocuk Kitabı vb. HARİÇ) — kullanıcı 2026-07-31
DELETE st FROM #stok st
WHERE NOT EXISTS (
    SELECT 1 FROM DerinSISBkm.bkm.UrunBilgi ub
    WHERE ub.stkID = st.stkID AND ub.Kategori3 IN (N'Kırtasiye', N'Oyuncak', N'Hediyelik')
);
CREATE CLUSTERED INDEX ix_stok ON #stok(stkID);

-------------------------------------------------------------------------------
-- #satis : mağaza × ürün × ay (brüt satış adedi)
-------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#satis') IS NOT NULL DROP TABLE #satis;
SELECT ehstkID AS stkID, ehMekan,
       RIGHT('0000' + CAST(YEAR(ehTrhS) AS varchar(4)), 4) + '-' + RIGHT('00' + CAST(MONTH(ehTrhS) AS varchar(2)), 2) AS Ay,
       CAST(-SUM(ehAdetN) AS int) AS Adet
INTO #satis
FROM dbo.irsHrk WITH(NOLOCK)
WHERE ehMekan IN (1, 4477, 4478) AND ehTip IN (1, 4, 100) AND ehTrhS >= '20230101'
GROUP BY ehstkID, ehMekan, YEAR(ehTrhS), MONTH(ehTrhS);
CREATE CLUSTERED INDEX ix_satis ON #satis(ehMekan, stkID);

-------------------------------------------------------------------------------
-- FINAL : @mekan mağazasının wide raporu (stok + 43 ay satış kolonu, dinamik PIVOT)
-------------------------------------------------------------------------------
DECLARE @mekan int = 1;   -- 1=FSM · 4477=Özlüce · 4478=İst.Yolu (yalnız SATIŞ kolonlarını belirler; stok 4 lokasyon zaten ayrı)

DECLARE @cols nvarchar(max) =
    STUFF((SELECT ',' + QUOTENAME(Ay)
           FROM (SELECT DISTINCT Ay FROM #satis) a
           ORDER BY Ay
           FOR XML PATH(''), TYPE).value('.', 'nvarchar(max)'), 1, 1, '');

DECLARE @sql nvarchar(max) = N'
SELECT st.stkID, ub.stkKod AS Kod, ub.stkAd AS Urun, ub.mrkAd AS Marka, ub.Kategori3 AS Kategori,
       st.Depo, st.FSM, st.Ozluce, st.Ist, ' + @cols + N'   -- lokasyon stokları AYRI (toplanmadan)
FROM #stok st
    JOIN DerinSISBkm.bkm.UrunBilgi ub ON ub.stkID = st.stkID
    LEFT JOIN (
        SELECT stkID, ' + @cols + N'
        FROM (SELECT stkID, Ay, Adet FROM #satis WHERE ehMekan = ' + CAST(@mekan AS varchar(10)) + N') src
        PIVOT (SUM(Adet) FOR Ay IN (' + @cols + N')) pv
    ) p ON p.stkID = st.stkID
ORDER BY ub.Kategori3, ub.stkAd;';   -- SABİT satır seti (tüm kategori+stok ürünü); @mekan yalnız satış kolonlarını belirler

EXEC sys.sp_executesql @sql;

/*
  Notlar:
    • PIVOT'ta satışsız ay = NULL (0 istenirse dinamik ISNULL sarımı gerekir).
    • DEPO: yalnız RAF(0)+GR(1) hücreleri, CK01 adresi HARİÇ (kullanıcı direktifi). Tip 2 (~445K adet) ve CK01 dahil DEĞİL.
    • Özet (4 lokasyon tek tablo) istersen: SELECT st.*, ub.stkKod, ub.stkAd, ub.mrkAd, ub.Kategori3 FROM #stok st JOIN bkm.UrunBilgi ub ...
    • Emitter (Excel çok-sheet): scripts/stok_satis_aylik_raporu.py — ⚠ o script DEPO'yu hâlâ irsHrk'tan alıyor, WMS'e çekilmeli (aynı düzeltme).
*/
