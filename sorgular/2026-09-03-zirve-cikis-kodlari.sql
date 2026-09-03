/* İşten çıkış kodları: sözlük nerede + sezonluk çıkışlar hangi kodla yazılıyor?
   DB: BKM_GENEL (192.168.40.25\ZRVSQL2008, Zirve) + DerinSISBkm (192.168.40.201)
   Araç: sqlcli --profile zirve / --profile erp
   Soru: sema "Zirve'de kod→açıklama LOOKUP TABLOSU YOK" diyordu; kod açıklaması olmadan
         "istifa mı, sözleşme bitimi mi" ayrımı yapılamıyor ve sezonluk devir analizi
         yorumlanamıyor.

   BULGU 1 — SÖZLÜK ZİRVE'DE DEĞİL, ERP'DE:
   · Zirve taraması (tablo adı %cikis%/%ayril%/%neden%/%kod%/%sgk%/%tanim% + kolon adı
     %ayrilma%/%CikisNeden%) açıklama tablosu BULMADI. Zirve yalnız KODU tutuyor
     (`vw_PersonelDepartman.IstenCikisKodu`, sıfır dolgulu: '03').
   · Açıklama sözlüğü `DerinSISBkm.iky.ayrilma_neden` (33 satır, kod+aciklama).
     Eşleşme: Zirve '03' → sözlük '3' (sıfır dolgusu kaldırılır / CAST int).
   · ⚠ `iky` şeması KULLANILMIYOR: personel/bordro/puantaj/personel_ucret vb. hepsi
     0 satır. Yalnız lookup tabloları dolu (ayrilma_neden 33 · ebildirge_belgeturu 34 ·
     ebildirge_eksikgunneden 23). İK'nın TEK kaynağı Zirve (kullanıcı teyidi 03.09).
     Yani iky sözlük olarak kullanılır, veri kaynağı olarak KULLANILMAZ.
   · Zirve'de kullanılan 3 kod sözlükte YOK: 45 (4 kişi) · 46 (1) · 48 (5) — SGK'nın
     sonradan eklediği kodlar; sözlük 36'ya kadar gidiyor. İK teyidi gerekir.

   BULGU 2 — SEZON SONU AYRILMALARI "İSTİFA" OLARAK YAZILIYOR:
   · Sözlükte 18 İşin sona ermesi · 19 Mevsim bitimi · 20 Kampanya bitimi kodları VAR.
   · Zirve'de bu üç kodun kullanımı TÜM ZAMAN İÇİN 0. Buna karşılık 212 sezonluk çıkış var.
   · 2025-2026 mağaza sezonluk çıkışları: 03 istifa 60 · 02 deneme süreli işçi feshi 26 ·
     01 deneme süreli işveren feshi 4 · 05 belirli süreli sözleşme bitimi 1.
   · SONUÇ: "sezonluk personelin çoğu istifa etti" çıkarımı VERİDEN DOĞRULANAMAZ — kod
     seçimi süreç gereği böyle yazılmış olabilir. Devir/istifa oranı yorumlanırken bu not
     olmadan yanlış okunur. İK'ya sorulacak (TODO K-33). */

-- 1) Sözlük: ERP'deki (kullanılmayan) iky modülünün lookup tablosu
SELECT kod, aciklama FROM iky.ayrilma_neden ORDER BY CAST(kod AS int);   -- ERP

-- 2) iky modülü gerçekten boş mu (veri kaynağı olarak kullanılmadığının kanıtı)  -- ERP
SELECT t.name AS tablo, SUM(p.rows) AS satir
FROM sys.tables t
JOIN sys.schemas s ON s.schema_id = t.schema_id
JOIN sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0, 1)
WHERE s.name = 'iky'
GROUP BY t.name
ORDER BY satir DESC;

-- 3) Zirve: çıkış kodu dağılımı (ayrılmış personel)                             -- ZIRVE
SELECT IstenCikisKodu, COUNT(*) AS kisi
FROM dbo.vw_PersonelDepartman
WHERE Ict IS NOT NULL
GROUP BY IstenCikisKodu
ORDER BY kisi DESC;

-- 4) Zirve: segment bazında (2025-2026, mağaza kapsamı)                         -- ZIRVE
SELECT CASE WHEN Kadro = 'SEZONLUK' THEN 'sezonluk' ELSE 'kadrolu' END AS segment,
       IstenCikisKodu, COUNT(*) AS kisi
FROM dbo.vw_PersonelDepartman
WHERE Ict IS NOT NULL AND Lokasyon LIKE 'MA%' AND YEAR(Ict) IN (2025, 2026)
GROUP BY CASE WHEN Kadro = 'SEZONLUK' THEN 'sezonluk' ELSE 'kadrolu' END, IstenCikisKodu
ORDER BY segment, kisi DESC;

-- 5) Mevsim/kampanya/iş bitimi kodları hiç kullanılmış mı (beklenen 0)          -- ZIRVE
SELECT SUM(CASE WHEN IstenCikisKodu IN ('18', '19', '20') THEN 1 ELSE 0 END) AS mevsim_kod_kullanimi,
       SUM(CASE WHEN Kadro = 'SEZONLUK' AND Ict IS NOT NULL THEN 1 ELSE 0 END) AS sezonluk_cikis
FROM dbo.vw_PersonelDepartman;
