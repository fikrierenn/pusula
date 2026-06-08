-- =====================================================================
-- 08.03 — E5 GMROI (Gross Margin Return on Investment) — kategori bazlı
-- GMROI = Brüt marj (TL) / Ort. envanter maliyeti (TL)
--   > 1.0 = envantere yatan her 1 TL'den fazla marj kazanıldı (sağlıklı)
-- =====================================================================
-- İKİ GİRDİ:
--   PAY   (Marj_TL)  → karzarar v7 motoru (SSMS-only, prod-parity COGS)
--                      04-karzarar/2026-05-07-karzarar-v7-prodparity.sql
--                      ÇIKTI 3 (Mağaza×Kategori×Kanal) → Marj_TL'yi KTGR3'e topla.
--   PAYDA (Ort.Env.) → bkm.ENVANTER_RAPORU (açılış+kapanış)/2, Ort.Maliyet bazı.
--                      MCP'de DOĞRULANDI (08.06.2026, May): Kitap 64M · Kırtasiye 40M ·
--                      Çocuk 32M · Oyuncak 28M · Hazırlık 21M · Akademi 16M.
--
-- ⚠️ NEDEN KISAYOL YOK (08.06 denendi, reddedildi):
--   COGS'u tek tablodan (Aktarim.BKM_STOKLAR_MALIYETLI.ORT_ALIS) almak YETMEZ —
--   kapsam zayıf: May'da Kitap'ın 52.536 satılan adedinin 27.832'sinde ORT_ALIS NULL
--   → COGS eksik → marj %100+ (saçma). Gerçek COGS = karzarar 3-fallback zinciri
--   (5-fat avg → ORT_ALIS → sonraki fatura). Bu yüzden PAY karzarar'dan gelir.
--
-- ⚠️ CAVEAT: Yüksek enflasyon hem marj (TL) hem ort. envanter (TL) değerini şişirir;
--   GMROI oran olduğu için kısmen sönümlenir ama dönemsel kıyasta dikkat. Benchmark YOK.
--   Birim-bağımsız alternatif: E4 adet-bazlı devir (envanter-verim-devir-sellthrough.sql).
-- NOT: SSMS. karzarar temp table'lı, MCP'de çalışmaz.
-- =====================================================================

DECLARE @AyBas date = '20260501';
DECLARE @AySon date = '20260531';

-- ADIM 1 — karzarar v7'yi @TARIH_ILK=@AyBas, @TARIH_SON=@AySon ile çalıştır.
--          ÇIKTI 3'teki (Mağaza × Kategori) Marj_TL'yi kategoriye toplayıp #MARJ'a yaz.
--          (Aşağıdaki INSERT örnek; karzarar çıktısını buraya bağla veya elle doldur.)
IF OBJECT_ID('tempdb..#MARJ') IS NOT NULL DROP TABLE #MARJ;
CREATE TABLE #MARJ (KTGR3 nvarchar(50) PRIMARY KEY, Marj_TL decimal(18,2));

-- ÖRNEK doldurma (karzarar v7 #MALIYET'ten doğrudan — aynı oturumda çalıştırılırsa):
-- INSERT INTO #MARJ(KTGR3, Marj_TL)
-- SELECT kt.ktgrAd, SUM(M.tutar - M.maliyet)
-- FROM #MALIYET M
-- JOIN dbo.urn u ON u.stkID = M.stkId
-- JOIN dbo.urnKtgr2 kt ON kt.ktgrID = u.urnKtgr2ID
-- GROUP BY kt.ktgrAd;

-- ADIM 2 — Ort. envanter maliyeti (kategori) + GMROI
;WITH OrtEnv AS (
    SELECT b.KTGR3,
        (b.Maliyet + e.Maliyet) / 2.0 AS OrtEnvanterMaliyet
    FROM (SELECT KTGR3,
            SUM(ISNULL([FSM Stok Maliyet],0)+ISNULL([Özlüce Stok Maliyet],0)+ISNULL([İst.Yolu Stok Maliyet],0)) AS Maliyet
          FROM DerinSISBkm.bkm.ENVANTER_RAPORU WITH(NOLOCK)
          WHERE CAST(Tarih AS date)=@AyBas AND [Maliyet Tipi]='Ort.Maliyet' AND KTGR3 NOT IN (N'Sınav Okulları',N'Dergi') GROUP BY KTGR3) b
    JOIN (SELECT KTGR3,
            SUM(ISNULL([FSM Stok Maliyet],0)+ISNULL([Özlüce Stok Maliyet],0)+ISNULL([İst.Yolu Stok Maliyet],0)) AS Maliyet
          FROM DerinSISBkm.bkm.ENVANTER_RAPORU WITH(NOLOCK)
          WHERE CAST(Tarih AS date)=@AySon AND [Maliyet Tipi]='Ort.Maliyet' AND KTGR3 NOT IN (N'Sınav Okulları',N'Dergi') GROUP BY KTGR3) e
      ON e.KTGR3 = b.KTGR3
)
SELECT
    m.KTGR3                                                              AS Kategori,
    CAST(m.Marj_TL AS decimal(18,0))                                    AS [Brüt Marj ₺],
    CAST(o.OrtEnvanterMaliyet AS decimal(18,0))                         AS [Ort. Envanter ₺],
    CAST(m.Marj_TL / NULLIF(o.OrtEnvanterMaliyet, 0) AS decimal(10,2))  AS GMROI
FROM #MARJ m
JOIN OrtEnv o ON o.KTGR3 COLLATE Turkish_CI_AS = m.KTGR3 COLLATE Turkish_CI_AS
ORDER BY GMROI DESC;

DROP TABLE #MARJ;
