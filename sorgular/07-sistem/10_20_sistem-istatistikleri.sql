-- EncoreMerkez Sorgu 10.20 — Sistem İstatistikleri (Tablo Boyutları)
-- Kaynak: encore-merkez-analiz-raporu.html
-- Veritabanı: EncoreMerkez
-- ============================================

-- Veritabanındaki tüm tabloların satır sayısı ve boyutu
SELECT
    s.name AS Sema,
    t.name AS Tablo,
    p.rows AS SatirSayisi,
    CAST(SUM(a.total_pages) * 8.0 / 1024 AS decimal(10,1)) AS BoyutMB,
    CAST(SUM(a.used_pages) * 8.0 / 1024 AS decimal(10,1)) AS KullanilanMB
FROM sys.tables t
JOIN sys.schemas s ON t.schema_id = s.schema_id
JOIN sys.indexes i ON t.object_id = i.object_id AND i.index_id IN (0,1)
JOIN sys.partitions p ON i.object_id = p.object_id AND i.index_id = p.index_id
JOIN sys.allocation_units a ON p.partition_id = a.container_id
GROUP BY s.name, t.name, p.rows
ORDER BY p.rows DESC
