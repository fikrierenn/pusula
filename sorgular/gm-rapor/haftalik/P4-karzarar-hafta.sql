-- =====================================================================
-- P4 — HAFTALIK KÂR/ZARAR (brüt marj, mağaza × kategori)
-- ⚠️ SSMS-ONLY (502 satır, temp table + multi-statement + ROLLUP — MCP çalıştıramaz).
-- TAM SORGU: sorgular/04-karzarar/2026-05-07-karzarar-v7-prodparity.sql
--   (prod-parity maliyet fallback: 5-fat avg → ORT_ALIS → SONRAKI fatura)
-- pymssql ile de çalışır (E5 GMROI kanıtı: SET DATEFORMAT dmy + charset UTF-8).
--
-- KULLANIM: v7 dosyasını aç, üstteki DECLARE bloğunu şu dinamik haliyle değiştir:
-- =====================================================================
DECLARE @TARIH_ILK DATE = DATEADD(WEEK, DATEDIFF(WEEK,0,GETDATE())-1, 0);  -- geçen Pzt
DECLARE @TARIH_SON DATE = DATEADD(DAY, 6, @TARIH_ILK);                     -- geçen Paz (DAHİL)

DECLARE @DETAYGOSTER       BIT = 0;
DECLARE @OZETGOSTER        BIT = 0;
DECLARE @MAGAZAOZETGOSTER  BIT = 1;   -- haftalık rutinde mağaza × kategori özeti yeter
DECLARE @DOGRULAMAGOSTER   BIT = 1;

DECLARE @MALIYETTIP        TINYINT = 0;
DECLARE @ALISSART_DAHIL    BIT = 0;
-- (v7'de @TARIH aralığı DAHİL-DAHİL — diğer haftalık sorguların exclusive bitişinden farklı!)
