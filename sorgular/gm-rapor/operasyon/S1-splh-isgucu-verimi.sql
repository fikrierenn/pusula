-- =====================================================================
-- S1 — SPLH (Sales Per Labor Hour) — işgücü verimi, mağaza bazlı
-- Amaç: Çalışılan saat başına net ciro + fiş. Mağaza işgücü verimliliği kıyası.
-- Kaynaklar:
--   Çalışılan saat: PDKS OPENQUERY([PDKS]) → TTagZei (segment) + TPerTab.
--     Mağaza eşleşme: Per_Grp1='MAĞAZALAR' AND Per_Grp2 ∈ FSM/ÖZLÜCE/İST.YOLU.
--     (KAFELER/E-TİCARET/MERKEZ DEPO hariç — sadece mağaza satış personeli.)
--   Ciro/Fiş: EncoreMerkez.Sales (net, geri dönüşüm hariç) → posMagaza mekanID.
-- ⚠️ TARİH: OPENQUERY içinde ISO 'YYYYMMDD'; dış sorguda da ISO. İKİSİNİ birlikte güncelle.
-- ⚠️ Çalışılan saat = tüm segment (VonZeit→BisZeit) toplamı; mola ZeitArt'a göre kırılır.
-- DOĞRULAMA (Mayıs 2026): Özlüce 3.786 ₺/saat (en verimli) · FSM 2.822 · İst.Yolu 2.794.
--   Fiş/saat: Özlüce 5,27 · FSM 5,14 · İst.Yolu 4,37 (en düşük throughput).
-- NOT: MCP-safe (CTE'siz). Cross linked-server (PDKS) + EncoreMerkez join (mağaza adı).
-- =====================================================================

SELECT
    lab.Magaza,
    cir.NetCiro                                                       AS [Net Ciro ₺],
    cir.Fis                                                           AS [Fiş],
    lab.CalisilanSaat                                                 AS [Çalışılan Saat],
    lab.Personel,
    CAST(cir.NetCiro / NULLIF(lab.CalisilanSaat,0) AS decimal(18,0))  AS [SPLH ₺/saat],
    CAST(cir.Fis / NULLIF(lab.CalisilanSaat,0) AS decimal(10,2))      AS [Fiş/saat]
FROM (
    -- PDKS çalışılan saat (mağaza bazlı)
    SELECT Magaza, CalisilanSaat, Personel
    FROM OPENQUERY([PDKS], '
      SELECT LTRIM(RTRIM(p.Per_Grp2)) AS Magaza,
         CAST(SUM(DATEDIFF(MINUTE, z.TZe_VonZeit, z.TZe_BisZeit))/60.0 AS decimal(18,1)) AS CalisilanSaat,
         COUNT(DISTINCT z.TZe_PersNr) AS Personel
      FROM TTagZei z INNER JOIN TPerTab p ON p.Per_PersNr = z.TZe_PersNr
      WHERE z.TZe_Datum >= ''20260501'' AND z.TZe_Datum <= ''20260531''
        AND p.Per_Grp1 = ''MAĞAZALAR''
        AND LTRIM(RTRIM(p.Per_Grp2)) IN (''FSM'',''ÖZLÜCE'',''İST.YOLU'')
        AND z.TZe_VonZeit IS NOT NULL AND z.TZe_BisZeit IS NOT NULL
      GROUP BY LTRIM(RTRIM(p.Per_Grp2))
    ')
) lab
JOIN (
    -- EncoreMerkez net ciro (mağaza bazlı) — aynı dönem
    SELECT CASE MG.mekanID WHEN 1 THEN N'FSM' WHEN 4477 THEN N'ÖZLÜCE' WHEN 4478 THEN N'İST.YOLU' END AS Magaza,
        SUM(IIF(s.DocumentsTypeId=3,-1,1)*(s.GrossTotal-s.DiscountTotal)) AS NetCiro,
        SUM(IIF(s.DocumentsTypeId=3,-1,1)) AS Fis
    FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
    JOIN EncoreMerkez.dbo.Pos p WITH(NOLOCK) ON p.Id=s.PosId
    JOIN EncoreMerkez.dbo.Stores st WITH(NOLOCK) ON st.Id=p.StoreId
    JOIN DerinSISBkm.dbo.posMagaza MG WITH(NOLOCK) ON MG.mekanKod COLLATE Turkish_CI_AS=st.Code COLLATE Turkish_CI_AS
    LEFT JOIN EncoreMerkez.dbo.SalesProducts spb WITH(NOLOCK) ON spb.SalesId=s.Id AND spb.BarcodeNo='1001'
    WHERE s.DocumentsTypeId IN (1,2,3,6,7,8) AND s.Date>='20260501' AND s.Date<'20260601' AND spb.Id IS NULL
    GROUP BY MG.mekanID
) cir ON cir.Magaza COLLATE Turkish_CI_AS = lab.Magaza COLLATE Turkish_CI_AS;
