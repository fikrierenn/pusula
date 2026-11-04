-- ork:hedef-db DerinSISBkm
-- 2026-11-03 — dbo.fatSatirKDVBelgeSonu_guncelle incelemesi (DerinSISBkm, 192.168.40.201)
-- Soru (GMY): bu prosedür ne yapıyor, riski var mı?
-- Prosedür WITH ENCRYPTION; GMY onayıyla `sqlcli ddl --profile erp` ile DAC üstünden çözüldü
-- (geçici ALTER + ROLLBACK; sonrasında modify_date 19.03.2024 aynı, DAC 0'a döndü).
-- Gövde (özet, satıcı kodu buraya kopyalanmadı):
--   @eID faturası için KDV oranı (ehKDV) başına
--   fark = CAST(SUM(ehTutarKDV) AS decimal(9,2))
--        - CAST(SUM((ehTutar-ehIndirim)*kdvYuzde/100.0) AS decimal(9,2))
--   o oranın MAX(ehSira) satırında ehTutarKDV -= fark. Taban ehTutarN DEĞİL, ehTutar-ehIndirim.
-- Bulgular:
--   * Kuruş farkı son satıra yazılıyor (eTip 0: 95 farklı satırın 81'i son sırada; max 0,11 ₺).
--   * Tevkifatı (ehTutarKDVtvkft) hesaba katmaz: tevkifat ayrıldıktan sonra çağrılırsa
--     tevkifat tutarını son satırın KDV'sine ekler. eTip 7 verisinde bu OLMAMIŞ (blok 3).
--   * decimal(9,2) tavanı 9.999.999,99: tek oranlı KDV toplamı bunu aşan fatura defterde var
--     (ANZ2026000000062 12,09M · ANZ2026000000064 15,21M, eTip 7, 08.05.2026) → prosedür
--     böyle bir faturada aritmetik taşma (8115) verir ve çağıran faturalama işlemi düşer.
--   * urnKDV'de karşılığı olmayan ehKDV: 0 satır.

-- Blok 1 — yapı: parametre, bağımlılık, çağıranlar
SELECT p.parameter_id, p.name, TYPE_NAME(p.user_type_id) AS tip
FROM sys.parameters p
WHERE p.object_id = OBJECT_ID('dbo.fatSatirKDVBelgeSonu_guncelle');

SELECT d.referenced_entity_name
FROM sys.sql_expression_dependencies d
WHERE d.referencing_id = OBJECT_ID('dbo.fatSatirKDVBelgeSonu_guncelle');

SELECT OBJECT_SCHEMA_NAME(d.referencing_id) AS sema, OBJECT_NAME(d.referencing_id) AS nesne,
       OBJECTPROPERTY(d.referencing_id, 'IsEncrypted') AS sifreli
FROM sys.sql_expression_dependencies d
WHERE d.referenced_entity_name = 'fatSatirKDVBelgeSonu_guncelle';

-- Blok 2 — davranış: prosedürün kendi tabanıyla (ehTutar-ehIndirim) son 30 gün, fatura tipi kırılımı
SELECT f.eTip, COUNT(*) AS satir,
       SUM(CASE WHEN a.ehTutarN <> a.ehTutar - a.ehIndirim THEN 1 ELSE 0 END) AS tabanFarkli,
       SUM(CASE WHEN a.ehTutarKDV <> ROUND((a.ehTutar - a.ehIndirim) * k.kdvYuzde / 100.0, 2)
                THEN 1 ELSE 0 END) AS kdvFarkliSatir,
       MAX(ABS(a.ehTutarKDV - ROUND((a.ehTutar - a.ehIndirim) * k.kdvYuzde / 100.0, 2))) AS maxFark
FROM dbo.fatAyr a
JOIN dbo.fat f ON f.eID = a.ehID
JOIN dbo.urnKDV k ON k.kdvID = a.ehKDV
WHERE f.eTarih >= DATEADD(DAY, -30, GETDATE())
GROUP BY f.eTip
ORDER BY f.eTip;

-- Blok 3 — tevkifatlı satırlar: büyük fark = ehTutarKDVtvkft (tam KDV = ehTutarKDV + tvkft)
SELECT TOP 20 a.ehID, a.ehSira, a.ehTutar, a.ehIndirim, k.kdvYuzde, a.ehTutarKDV, a.ehTutarKDVtvkft
FROM dbo.fatAyr a
JOIN dbo.fat f ON f.eID = a.ehID
JOIN dbo.urnKDV k ON k.kdvID = a.ehKDV
WHERE f.eTip = 7
  AND f.eTarih >= DATEADD(DAY, -30, GETDATE())
  AND ABS(a.ehTutarKDV - ROUND((a.ehTutar - a.ehIndirim) * k.kdvYuzde / 100.0, 2)) > 1
ORDER BY ABS(a.ehTutarKDV - ROUND((a.ehTutar - a.ehIndirim) * k.kdvYuzde / 100.0, 2)) DESC;

-- Blok 4 — taşma payı: decimal(9,2) tavanını aşan (fatura, KDV oranı) grupları
SELECT a.ehID, a.ehKDV, SUM((a.ehTutar - a.ehIndirim) * k.kdvYuzde / 100.0) AS kdvToplam
FROM dbo.fatAyr a
JOIN dbo.urnKDV k ON k.kdvID = a.ehKDV
GROUP BY a.ehID, a.ehKDV
HAVING ABS(SUM((a.ehTutar - a.ehIndirim) * k.kdvYuzde / 100.0)) > 9999999.99
    OR ABS(SUM(a.ehTutarKDV)) > 9999999.99;

-- Blok 5 — urnKDV karşılığı olmayan KDV kodu (düzeltmenin dışında kalır)
SELECT COUNT(*) AS eslesmeyen
FROM dbo.fatAyr a
WHERE NOT EXISTS (SELECT 1 FROM dbo.urnKDV k WHERE k.kdvID = a.ehKDV);
