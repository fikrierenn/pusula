-- =====================================================================
-- 08.02 — ENVANTER VERİM: Devir (E4) + Weeks-of-Supply (E7) + Sell-Through (E6) — kategori
-- Amaç: Stok ne hızla nakde dönüyor (devir) + kaç haftalık stok var (WoS) + gelen mal
--        ne hızla eriyor (sell-through). WoS yüksek (Kitap ~36 hafta) = ölü sermaye sinyali.
-- Kaynak: irsHrk (satış/gelen hareket) + bkm.ENVANTER_RAPORU (açılış/kapanış stok adet)
-- KPI (deep-research 08.06.2026, sorgular/gm-rapor/KATALOG.md § E):
--   Devir (adet bazlı) = Satılan adet / Ort. stok adet   [birim maliyet sadeleşir → COGS motoru gerekmez]
--      Yıllık devir = Aylık devir × 12
--   Sell-through = Satılan adet / (Açılış stok + Gelen adet) × 100
-- Hareket tipleri (irsHrk.ehTip — 08.06 keşif):
--   Satış: 4 (mağaza) + 100 (POS)   ·   İade: 5 + 101 (hariç)
--   Gelen: 10 (alış mal kabulü, dış tedarikçi) + 13 (Ana Depo firma=12 şube transfer-in)
--   Transfer-out: 9, 12 (hariç)
-- ANOMALİ: Sınav Okulları (paket koduyla giriş, parça koduyla çıkış) → hariç tutuldu.
-- Mağaza eşleşme: ENVANTER_RAPORU.KTGR3 = urnKtgr2.ktgrAd (doğrulandı).
-- ENVANTER.Tarih DATETIME (00:05) → CAST(... AS date) ile eşle.
-- DOĞRULAMA (MCP, Mayıs 2026, 3 mağaza):
--   Devir yıllık: Dergi 8,53x · Gıda 5,63x · Oyuncak 3,49x · Kitap 1,46x · Kırtasiye 1,32x · Akademi 1,17x
--   Sell-through: Gıda %32,5 · Dergi %37,4 · Kitap %10,7 · Kırtasiye %10,0 · Sınav Kıyafet %2,8
-- CAVEAT: Yüksek enflasyon ort. envanteri (TL) şişirir; adet-bazlı devir bundan ETKİLENMEZ (avantaj).
--         Benchmark hedef sayısı YOK — kendi tarihsel baseline'ınla kıyasla.
-- NOT: SSMS/pymssql. MCP CTE wrap eder; bu sorgu CTE'siz (derived table) — MCP'de de çalışır.
-- =====================================================================

DECLARE @AyBas date = '20260501';   -- dönem başı (ENVANTER açılış snapshot bu tarihte olmalı)
DECLARE @AySon date = '20260531';   -- dönem sonu (ENVANTER kapanış snapshot bu tarihte olmalı)
DECLARE @AyUst date = DATEADD(DAY, 1, @AySon);  -- hareket üst sınır (exclusive)
DECLARE @AySayisi decimal(6,2) = 1.0;  -- dönem kaç ay (yıllıklaştırma için)

SELECT
    m.Kategori,
    m.SatilanAdet,
    m.GelenAdet,
    b.AcilisStok,
    e.KapanisStok,
    CAST((b.AcilisStok + e.KapanisStok) / 2.0 AS decimal(18,0))                             AS OrtStok,
    -- E4 Devir
    CAST(1.0 * m.SatilanAdet / NULLIF((b.AcilisStok + e.KapanisStok) / 2.0, 0) AS decimal(10,3)) AS DonemDevir,
    CAST((12.0 / @AySayisi) * m.SatilanAdet / NULLIF((b.AcilisStok + e.KapanisStok) / 2.0, 0) AS decimal(10,2)) AS YillikDevir,
    -- E7 Weeks of Supply (kaç haftalık stok var = devir'in tersi). Yüksek = fazla stok/ölü sermaye.
    CAST(((b.AcilisStok + e.KapanisStok) / 2.0) * (@AySayisi * 52.0 / 12.0)
       / NULLIF(m.SatilanAdet, 0) AS decimal(10,1))                                        AS HaftalikStok_WoS,
    -- E6 Sell-through
    CAST(100.0 * m.SatilanAdet / NULLIF(b.AcilisStok + m.GelenAdet, 0) AS decimal(10,1))    AS SellThroughYuzde
FROM (
    SELECT k.ktgrAd AS Kategori,
        -SUM(CASE WHEN h.ehTip IN (4,100) THEN h.ehAdetN ELSE 0 END) AS SatilanAdet,
         SUM(CASE WHEN h.ehTip IN (10,13) THEN h.ehAdetN ELSE 0 END) AS GelenAdet
    FROM DerinSISBkm.dbo.irsHrk h WITH(NOLOCK)
    JOIN DerinSISBkm.dbo.urn u WITH(NOLOCK) ON u.stkID = h.ehstkID
    JOIN DerinSISBkm.dbo.urnKtgr2 k WITH(NOLOCK) ON k.ktgrID = u.urnKtgr2ID
    WHERE h.ehTrhS >= @AyBas AND h.ehTrhS < @AyUst
      AND h.ehMekan IN (1, 4477, 4478) AND h.ehAltDepo = 0
      AND h.ehTip IN (4, 100, 10, 13)
    GROUP BY k.ktgrAd
) m
LEFT JOIN (
    SELECT KTGR3 AS Kategori,
      SUM(ISNULL([Fsm Stok Adet],0) + ISNULL([Özlüce Stok Adet],0) + ISNULL([İst.Yolu Stok Adet],0)) AS AcilisStok
    FROM DerinSISBkm.bkm.ENVANTER_RAPORU WITH(NOLOCK)
    WHERE CAST(Tarih AS date) = @AyBas AND [Maliyet Tipi] = 'Ort.Maliyet'
    GROUP BY KTGR3
) b ON b.Kategori COLLATE Turkish_CI_AS = m.Kategori COLLATE Turkish_CI_AS
LEFT JOIN (
    SELECT KTGR3 AS Kategori,
      SUM(ISNULL([Fsm Stok Adet],0) + ISNULL([Özlüce Stok Adet],0) + ISNULL([İst.Yolu Stok Adet],0)) AS KapanisStok
    FROM DerinSISBkm.bkm.ENVANTER_RAPORU WITH(NOLOCK)
    WHERE CAST(Tarih AS date) = @AySon AND [Maliyet Tipi] = 'Ort.Maliyet'
    GROUP BY KTGR3
) e ON e.Kategori COLLATE Turkish_CI_AS = m.Kategori COLLATE Turkish_CI_AS
WHERE m.Kategori NOT IN ('Sınav Okulları','Sınav Kayıt','Genel','Tanımsız','Etkinlik','Hediye Çeki')
ORDER BY YillikDevir DESC;

-- =====================================================================
-- E5 — GMROI (Gross Margin Return on Investment) — TODO (karzarar bağımlı)
-- GMROI = Brüt marj (TL) / Ort. envanter maliyeti (TL)
--   Brüt marj: 04-karzarar/2026-05-07-karzarar-v7-prodparity.sql (mağaza×kategori Marj_TL)
--   Ort. envanter: ENVANTER_RAPORU (açılış+kapanış)/2, [.. Stok Maliyet] Ort.Maliyet bazı
-- Devir'in aksine GMROI birim maliyeti SADELEŞTİREMEZ (marj ≠ adet) → gerçek COGS/marj gerekir.
-- karzarar motoru SSMS-only (temp table). Aylık çalıştır → Marj_TL'yi kategori bazında
-- ENVANTER ort. maliyetine böl. Plan: plans/05-envanter-verim-kpi.md adım E5.
-- =====================================================================
