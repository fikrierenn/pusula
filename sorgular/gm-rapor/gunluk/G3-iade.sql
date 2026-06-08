-- =====================================================================
-- G3 — GÜNLÜK İADE KONTROLÜ (mağaza bazlı)
-- Amaç: Dün iade fiş + tutar + iade oranı (iade / satış brüt). Yüksek oran = kalite/operasyon sinyali.
-- Veritabanı: EncoreMerkez (Sales) + posMagaza
-- İade = DocumentsTypeId=3 · Satış brüt = DocumentsTypeId IN (1,2,6,7,8)
-- DOĞRULAMA (07.06.2026): İst.Yolu %3,5 (25.403 ₺, en yüksek) · FSM %2,0 · Özlüce %1,4.
-- NOT: MCP-safe (CTE yok). @Gun yerine ISO literal.
-- =====================================================================
DECLARE @Gun date = CAST(DATEADD(DAY,-1,GETDATE()) AS date);
DECLARE @GunBitis date = DATEADD(DAY,1,@Gun);

SELECT
    CASE MG.mekanID WHEN 1 THEN N'FSM' WHEN 4477 THEN N'Özlüce' WHEN 4478 THEN N'İst.Yolu' END AS Magaza,
    SUM(IIF(s.DocumentsTypeId=3,1,0))                                                  AS [İade Fiş],
    CAST(SUM(IIF(s.DocumentsTypeId=3,s.GrossTotal,0)) AS decimal(18,0))                AS [İade ₺],
    CAST(SUM(IIF(s.DocumentsTypeId IN(1,2,6,7,8),s.GrossTotal,0)) AS decimal(18,0))    AS [Satış Brüt ₺],
    CAST(100.0*SUM(IIF(s.DocumentsTypeId=3,s.GrossTotal,0))
       / NULLIF(SUM(IIF(s.DocumentsTypeId IN(1,2,6,7,8),s.GrossTotal,0)),0) AS decimal(10,1)) AS [İade Oranı %]
FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
JOIN EncoreMerkez.dbo.Pos p WITH(NOLOCK) ON p.Id=s.PosId
JOIN EncoreMerkez.dbo.Stores st WITH(NOLOCK) ON st.Id=p.StoreId
JOIN DerinSISBkm.dbo.posMagaza MG WITH(NOLOCK) ON MG.mekanKod COLLATE Turkish_CI_AS=st.Code COLLATE Turkish_CI_AS
WHERE s.DocumentsTypeId IN (1,2,3,6,7,8) AND s.Date>=@Gun AND s.Date<@GunBitis
GROUP BY MG.mekanID
ORDER BY [İade Oranı %] DESC;
