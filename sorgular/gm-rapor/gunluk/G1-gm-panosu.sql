-- =====================================================================
-- 10.00 — GÜNLÜK GM PANOSU (mağaza kırılımı)
-- Amaç: Dün kapanışı tek bakış — Net ciro · Fiş · Sepet ort (ATV) · UPT
--        + WoW (geçen hafta aynı gün) + YoY (geçen yıl aynı gün)
--        + MTD hedef gerçekleşme
-- Veritabanı: EncoreMerkez (+ DerinSISBkm.posMagaza, BKMDATA.Hedef)
-- Kanonik pattern: scripts/generate_brief.py (SQL_PERIOD / SQL_DAILY / SQL_HEDEF)
--   Net ciro = SUM(IIF(DocumentsTypeId=3,-1,1)*(GrossTotal-DiscountTotal-VatTotal))  -- KDV-hariç (plan-16)
--   Mağaza   = Pos -> Stores -> posMagaza.mekanID (1=FSM, 4477=Özlüce, 4478=İst.Yolu)
--   Geri dönüşüm fişi (SalesProducts.BarcodeNo='1001') anti-join ile hariç
-- KPI sözlük (deep-research 2026-06-08, sorgular/gm-rapor/KATALOG.md § Genişletme):
--   ATV (sepet ort) = Net ciro / Fiş   ·   UPT = Net adet / Fiş   ·   WoW/YoY erken uyarı
-- DOĞRULAMA: @Gun=07.06.2026 → TOPLAM 1.933.437 TL / 3060 fiş (⚠️ KDV-DAHİL dönem; plan-16 sonrası KDV-hariç ~1,79M — yeniden doğrula).
--            UPT: FSM 3,38 · Özlüce 4,05 · İst.Yolu 4,33 (FSM düşük sepet = adet sorunu).
-- YoY KISIT: EncoreMerkez POS verisi 11.07.2025'te başlıyor → YoY kolonu ~11.07.2026'ya
--            kadar boş (—) gösterir. Tarihsel YoY için DerinSIS irsHrk kaynağı gerekir (ayrı sorgu).
-- NOT: SSMS veya pymssql ile çalıştır. MCP sql_query CTE'leri auto-TOP wrap edip kırıyor.
-- =====================================================================

DECLARE @Gun date = CAST(DATEADD(DAY, -1, GETDATE()) AS date);  -- varsayılan: dün
-- Manuel gün için:  SET @Gun = CONVERT(date, '07.06.2026', 104);

DECLARE @GunBitis date = DATEADD(DAY, 1, @Gun);          -- gün üst sınır (exclusive)
DECLARE @Wow      date = DATEADD(DAY, -7, @Gun);         -- geçen hafta aynı gün
DECLARE @WowBitis date = DATEADD(DAY, 1, @Wow);
DECLARE @Yoy      date = DATEADD(YEAR, -1, @Gun);        -- geçen yıl aynı gün
DECLARE @YoyBitis date = DATEADD(DAY, 1, @Yoy);
DECLARE @AyBas    date = DATEFROMPARTS(YEAR(@Gun), MONTH(@Gun), 1);  -- MTD başlangıç

;WITH Gun AS (   -- dün, mağaza bazlı (Net ciro + Fiş + İade + Net adet→UPT)
    SELECT MG.mekanID,
        SUM(IIF(s.DocumentsTypeId = 3, -1, 1) * (s.GrossTotal - s.DiscountTotal - s.VatTotal)) AS NetCiro,
        SUM(IIF(s.DocumentsTypeId = 3, -1, 1)) AS Fis,
        SUM(IIF(s.DocumentsTypeId = 3, 1, 0)) AS IadeFis,
        SUM(IIF(s.DocumentsTypeId = 3, -1, 1) * adet.Cnt) AS NetAdet
    FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
    JOIN EncoreMerkez.dbo.Pos p WITH(NOLOCK) ON p.Id = s.PosId
    JOIN EncoreMerkez.dbo.Stores st WITH(NOLOCK) ON st.Id = p.StoreId
    JOIN DerinSISBkm.dbo.posMagaza MG WITH(NOLOCK)
        ON MG.mekanKod COLLATE Turkish_CI_AS = st.Code COLLATE Turkish_CI_AS
    LEFT JOIN EncoreMerkez.dbo.SalesProducts spb WITH(NOLOCK)
        ON spb.SalesId = s.Id AND spb.BarcodeNo = '1001'
    CROSS APPLY (   -- fiş başına geçerli satır sayısı (geri dönüşüm hariç)
        SELECT COUNT(*) AS Cnt FROM EncoreMerkez.dbo.SalesProducts spx WITH(NOLOCK)
        WHERE spx.SalesId = s.Id AND spx.IsValid = 1 AND spx.BarcodeNo <> '1001'
    ) adet
    WHERE s.Date >= @Gun AND s.Date < @GunBitis
      AND spb.Id IS NULL
    GROUP BY MG.mekanID
),
Wow AS (   -- geçen hafta aynı gün
    SELECT MG.mekanID,
        SUM(IIF(s.DocumentsTypeId = 3, -1, 1) * (s.GrossTotal - s.DiscountTotal)) AS NetCiro
    FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
    JOIN EncoreMerkez.dbo.Pos p WITH(NOLOCK) ON p.Id = s.PosId
    JOIN EncoreMerkez.dbo.Stores st WITH(NOLOCK) ON st.Id = p.StoreId
    JOIN DerinSISBkm.dbo.posMagaza MG WITH(NOLOCK)
        ON MG.mekanKod COLLATE Turkish_CI_AS = st.Code COLLATE Turkish_CI_AS
    LEFT JOIN EncoreMerkez.dbo.SalesProducts spb WITH(NOLOCK)
        ON spb.SalesId = s.Id AND spb.BarcodeNo = '1001'
    WHERE s.Date >= @Wow AND s.Date < @WowBitis
      AND spb.Id IS NULL
    GROUP BY MG.mekanID
),
Yoy AS (   -- geçen yıl aynı gün (mevsimsellik — sınav/okula dönüş için kritik)
    SELECT MG.mekanID,
        SUM(IIF(s.DocumentsTypeId = 3, -1, 1) * (s.GrossTotal - s.DiscountTotal)) AS NetCiro
    FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
    JOIN EncoreMerkez.dbo.Pos p WITH(NOLOCK) ON p.Id = s.PosId
    JOIN EncoreMerkez.dbo.Stores st WITH(NOLOCK) ON st.Id = p.StoreId
    JOIN DerinSISBkm.dbo.posMagaza MG WITH(NOLOCK)
        ON MG.mekanKod COLLATE Turkish_CI_AS = st.Code COLLATE Turkish_CI_AS
    LEFT JOIN EncoreMerkez.dbo.SalesProducts spb WITH(NOLOCK)
        ON spb.SalesId = s.Id AND spb.BarcodeNo = '1001'
    WHERE s.Date >= @Yoy AND s.Date < @YoyBitis
      AND spb.Id IS NULL
    GROUP BY MG.mekanID
),
Mtd AS (   -- ay başından @Gun dahil
    SELECT MG.mekanID,
        SUM(IIF(s.DocumentsTypeId = 3, -1, 1) * (s.GrossTotal - s.DiscountTotal)) AS NetCiro
    FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
    JOIN EncoreMerkez.dbo.Pos p WITH(NOLOCK) ON p.Id = s.PosId
    JOIN EncoreMerkez.dbo.Stores st WITH(NOLOCK) ON st.Id = p.StoreId
    JOIN DerinSISBkm.dbo.posMagaza MG WITH(NOLOCK)
        ON MG.mekanKod COLLATE Turkish_CI_AS = st.Code COLLATE Turkish_CI_AS
    LEFT JOIN EncoreMerkez.dbo.SalesProducts spb WITH(NOLOCK)
        ON spb.SalesId = s.Id AND spb.BarcodeNo = '1001'
    WHERE s.Date >= @AyBas AND s.Date < @GunBitis
      AND spb.Id IS NULL
    GROUP BY MG.mekanID
),
Hedef AS (   -- MTD hedef (ay başından @Gun dahil)
    SELECT mekanId, SUM(hedef) AS HedefMtd
    FROM BKMDATA.dbo.Hedef WITH(NOLOCK)
    WHERE mekanId IN (1, 4477, 4478)
      AND tarih >= @AyBas AND tarih < @GunBitis
    GROUP BY mekanId
),
Birlesik AS (
    SELECT
        m.mekanID,
        CASE m.mekanID WHEN 1 THEN N'FSM' WHEN 4477 THEN N'Özlüce' WHEN 4478 THEN N'İst.Yolu' ELSE N'?' END AS Magaza,
        ISNULL(g.NetCiro, 0)  AS NetCiro,
        ISNULL(g.Fis, 0)      AS Fis,
        ISNULL(g.IadeFis, 0)  AS IadeFis,
        ISNULL(g.NetAdet, 0)  AS NetAdet,
        ISNULL(w.NetCiro, 0)  AS WowNet,
        ISNULL(y.NetCiro, 0)  AS YoyNet,
        ISNULL(t.NetCiro, 0)  AS MtdNet,
        ISNULL(h.HedefMtd, 0) AS HedefMtd
    FROM (SELECT 1 AS mekanID UNION ALL SELECT 4477 UNION ALL SELECT 4478) m
    LEFT JOIN Gun   g ON g.mekanID = m.mekanID
    LEFT JOIN Wow   w ON w.mekanID = m.mekanID
    LEFT JOIN Yoy   y ON y.mekanID = m.mekanID
    LEFT JOIN Mtd   t ON t.mekanID = m.mekanID
    LEFT JOIN Hedef h ON h.mekanId = m.mekanID
)
SELECT
    CONVERT(varchar, @Gun, 104) AS [Tarih],
    Magaza,
    CAST(NetCiro AS decimal(18,2))                                   AS [Net Ciro],
    Fis                                                              AS [Fiş],
    IadeFis                                                          AS [İade Fiş],
    CAST(NetCiro / NULLIF(Fis, 0) AS decimal(18,2))                  AS [Sepet Ort (ATV)],
    CAST(1.0 * NetAdet / NULLIF(Fis, 0) AS decimal(10,2))            AS [UPT],
    CAST(100.0 * (NetCiro - WowNet) / NULLIF(WowNet, 0) AS decimal(10,1)) AS [WoW %],
    CAST(100.0 * (NetCiro - YoyNet) / NULLIF(YoyNet, 0) AS decimal(10,1)) AS [YoY %],
    CAST(MtdNet AS decimal(18,2))                                    AS [MTD Net],
    CAST(HedefMtd AS decimal(18,2))                                  AS [MTD Hedef],
    CAST(100.0 * MtdNet / NULLIF(HedefMtd, 0) AS decimal(10,1))      AS [Gerçekleşme %]
FROM Birlesik

UNION ALL

SELECT
    CONVERT(varchar, @Gun, 104),
    N'★ TOPLAM',
    CAST(SUM(NetCiro) AS decimal(18,2)),
    SUM(Fis),
    SUM(IadeFis),
    CAST(SUM(NetCiro) / NULLIF(SUM(Fis), 0) AS decimal(18,2)),
    CAST(1.0 * SUM(NetAdet) / NULLIF(SUM(Fis), 0) AS decimal(10,2)),
    CAST(100.0 * (SUM(NetCiro) - SUM(WowNet)) / NULLIF(SUM(WowNet), 0) AS decimal(10,1)),
    CAST(100.0 * (SUM(NetCiro) - SUM(YoyNet)) / NULLIF(SUM(YoyNet), 0) AS decimal(10,1)),
    CAST(SUM(MtdNet) AS decimal(18,2)),
    CAST(SUM(HedefMtd) AS decimal(18,2)),
    CAST(100.0 * SUM(MtdNet) / NULLIF(SUM(HedefMtd), 0) AS decimal(10,1))
FROM Birlesik
ORDER BY CASE WHEN Magaza = N'★ TOPLAM' THEN 1 ELSE 0 END, Magaza COLLATE Turkish_CI_AS;
