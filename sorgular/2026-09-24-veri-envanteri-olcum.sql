-- Veri envanteri ölçümü — Gemini Enterprise / BigQuery ön bilgi paketi için (24.09.2026)
-- Soru: sistem başına boyut, satır, yıllık büyüme. DB: 192.168.40.201 (erp/encore profilleri), zirve.
-- Bulgu: ERP 784 GB ama 177 GB api_log + ~230 GB e-fatura blob; analitik çekirdek ~50 GB.
--        irsHrk 59,4M · POS fiş 1,38M / satır 6,5M · e-tic ~1,3M sipariş/yıl · eski kasa 6,4M belge (2014–2025).

-- 1) Sunucudaki DB boyutları (master)
SELECT d.name, CAST(SUM(mf.size)*8/1024.0/1024 AS decimal(10,1)) AS GB, d.compatibility_level, d.collation_name
FROM sys.databases d JOIN sys.master_files mf ON mf.database_id=d.database_id
WHERE d.database_id>4 GROUP BY d.name,d.compatibility_level,d.collation_name ORDER BY GB DESC;

-- 2) DerinSISBkm en büyük 25 tablo
SELECT TOP 25 s.name+'.'+t.name AS tablo, SUM(p.rows) AS satir,
       CAST(SUM(a.total_pages)*8/1024.0/1024 AS decimal(10,1)) AS GB
FROM sys.tables t JOIN sys.schemas s ON s.schema_id=t.schema_id
JOIN sys.partitions p ON p.object_id=t.object_id AND p.index_id IN (0,1)
JOIN sys.allocation_units a ON a.container_id=p.partition_id
GROUP BY s.name,t.name ORDER BY GB DESC;

-- 3) irsHrk yıllık büyüme
SELECT YEAR(ehTrhS) yil, COUNT(*) satir, COUNT(DISTINCT ehstkID) urun
FROM dbo.irsHrk WHERE ehTrhS>=CONVERT(date,'01.01.2022',104) GROUP BY YEAR(ehTrhS) ORDER BY yil;

-- 4) Master sayıları
SELECT (SELECT COUNT(*) FROM dbo.urn) urun, (SELECT COUNT(*) FROM dbo.urn WHERE urnTip=0) urun_normal,
       (SELECT COUNT(*) FROM dbo.frm) taraf, (SELECT COUNT(*) FROM dbo.urnBrkd) barkod,
       (SELECT MIN(ehTrhS) FROM dbo.irsHrk) ilk_hrk;

-- 5) EncoreMerkez POS yıllık (encore profili)
SELECT YEAR(Date) yil, COUNT(*) fis, SUM(CASE WHEN DocumentsTypeId=8 THEN 1 ELSE 0 END) sinav_belge,
       COUNT(DISTINCT CASE WHEN CustomersId>0 THEN CustomersId END) kartli_musteri
FROM dbo.Sales WHERE DocumentsTypeId IN (1,2,3,6,7,8) GROUP BY YEAR(Date) ORDER BY yil;

SELECT (SELECT COUNT(*) FROM dbo.Sales) sales, (SELECT COUNT(*) FROM dbo.SalesProducts WHERE IsValid=1) satir,
       (SELECT COUNT(*) FROM dbo.Products) products, (SELECT MIN(Date) FROM dbo.Sales) ilk, (SELECT MAX(Date) FROM dbo.Sales) son;

-- 6) Eski kasa INTER_BOS
SELECT (SELECT COUNT(*) FROM INTER_BOS.dbo.BELGE) belge, (SELECT COUNT(*) FROM INTER_BOS.dbo.HAREKET) satir,
       (SELECT MIN(Tarih) FROM INTER_BOS.dbo.BELGE) ilk;

-- 7) E-ticaret (linked server, ISO tarih zorunlu)
SELECT YEAR(ORDERDATE) yil, COUNT(*) siparis
FROM ODAKJOKER.JOKER.dbo.J_ORDERS WHERE ORDERDATE>='20230101' GROUP BY YEAR(ORDERDATE) ORDER BY yil;

-- 8) Zirve BKM_GENEL boyut (zirve profili)
SELECT DB_NAME() db, CAST(SUM(size)*8/1024.0 AS decimal(10,1)) MB FROM sys.database_files;
