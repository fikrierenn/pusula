/* ═══════════════════════════════════════════════════════════════════════════════
   SEZON AKSİYON LİSTESİ — "365 günde satılan" KOLONU NEDEN KALDIRILDI
   + AÇIK listesindeki YANLIŞ ALARMIN büyüklüğü

   GMY 15.09.2026: "365 günde satılan sezon dışı olanlar mı" → "aynı pencereye getirelim"
   DB: DerinSISBkm · kesim 13.09.2026 · sezon 2025
   Emitter: scripts/sezon_aksiyon_listesi_excel.py

   BULGU 1 — İKİ KOLONUN PENCERESİ İÇ İÇE GEÇMİYOR (blok 1)
     SatisToplam = [kesim−364, kesim] = 14.09.2025–13.09.2026
     SezonToplam = 01.08.2025–31.10.2025
     Örtüşme yalnız ~48 gün. Geçen sezonun 1 Ağu–13 Eyl kısmı 365 günden ESKİ olduğu için
     SatisToplam'ın DIŞINDA. Bu yüzden bir üründe 365g=33 iken sezon=652 olabiliyor ve
     bu bir HATA DEĞİL. Yan yana konunca okuyanı yanıltıyordu → kolon KALDIRILDI,
     yerine iki yıl için de AYNI uzunlukta, okula HİZALI pencere kondu.

   BULGU 2 — AÇIK'IN %34,8'İ YANLIŞ ALARM (blok 2)
     Rafta mal DURUYOR ve sezonun 44 gününde SIFIR satmış: 10.865 ürün / 40,4M ₺.
     Bunlara "sipariş et" demek yanlış — talep yok, stok yokluğu değil (mal ORADA).
   ═══════════════════════════════════════════════════════════════════════════════ */

-- ── BLOK 1: tek ürün üzerinde pencere farkı (Bic Yazı Tahtalı Set, stkID 486093) ──
SELECT Ay = CONVERT(char(7), h.ehTrhS, 126), Adet = CONVERT(int, -SUM(h.ehAdetN))
FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
WHERE h.ehstkID = 486093 AND h.ehMekan IN (1,4477,4478) AND h.ehTip IN (1,3,4,5,100,101)
  AND h.ehTrhS >= '20250801' AND h.ehTrhS < '20260914'
GROUP BY CONVERT(char(7), h.ehTrhS, 126) ORDER BY 1;
/* SONUÇ: 2025-08 → 321 · 2025-09 → 323 · 2025-10 → 8 · 2025-11 → 3 · 2025-12 → 1 · 2026 → YOK
   Tabandaki değerler: SatisToplam 33 · SezonToplam 652 (Ay1 321 / Ay2 323 / Ay3 8).
   33 = 365 günlük pencereye düşen kuyruk (14-30 Eyl 2025 + Eki + Kas + Ara).
   ⇒ Ürün Aralık 2025'ten beri HİÇ satmamış; bu sezon (Ağu-Eyl 2026) SIFIR.
     Buna rağmen rapor "782 adet AÇIK / 1,3M ₺" diyordu. */


-- ── BLOK 2: AÇIK listesi — bu sezon fiilen satan / satmayan ayrımı ───────────────
DECLARE @k date = '2026-09-13';

WITH bu AS (   -- BU sezonun fiili satışı (01.08.2026 .. kesim)
    SELECT h.ehstkID AS stkID, -SUM(h.ehAdetN) AS BuSezon
    FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
    WHERE h.ehMekan IN (1,4477,4478) AND h.ehTip IN (1,3,4,5,100,101)
      AND h.ehTrhS >= '20260801' AND h.ehTrhS < DATEADD(DAY,1,@k)
    GROUP BY h.ehstkID)
SELECT Sinif = CASE
         WHEN ISNULL(bu.BuSezon,0) > 0 THEN 'A- bu sezon SATTI'
         WHEN t.MagazaStok > 0 THEN 'B- rafta MAL VAR ama SIFIR satti (talep yok)'
         WHEN t.MerkezStok > 0 THEN 'C- raf bos, DEPODA var, sifir satti'
         ELSE 'D- hic stok yok, sifir satti (sansurlu OLABILIR)' END,
       COUNT(*)                                                    AS Urun,
       CONVERT(bigint, SUM(s.Sat - s.Elde))                        AS AcikAdet,
       CONVERT(decimal(18,0), SUM((s.Sat - s.Elde) * t.SatisFiyat)) AS AcikTL
FROM DerinSISBkm.bkm.SatisAnaliziTaban t WITH (NOLOCK)
LEFT JOIN bu ON bu.stkID = t.stkID
CROSS APPLY (SELECT Sat = CONVERT(int, CEILING(t.SezonToplam * 1.20)),
                    Elde = t.MagazaStok + t.MerkezStok) s
WHERE t.Kesim = @k AND t.SezonYil = 2025 AND t.SezonToplam > 0
  AND t.StokFsm >= 0 AND t.StokOzl >= 0 AND t.StokIst >= 0 AND t.MerkezStok >= 0
  AND t.SatisFiyat > 0
  AND s.Sat > s.Elde                       -- yalnız AÇIK kohortu
GROUP BY CASE
         WHEN ISNULL(bu.BuSezon,0) > 0 THEN 'A- bu sezon SATTI'
         WHEN t.MagazaStok > 0 THEN 'B- rafta MAL VAR ama SIFIR satti (talep yok)'
         WHEN t.MerkezStok > 0 THEN 'C- raf bos, DEPODA var, sifir satti'
         ELSE 'D- hic stok yok, sifir satti (sansurlu OLABILIR)' END
ORDER BY 1;
/* SONUÇ (31.187 AÇIK ürün / 254.733.925 ₺):
     A  bu sezon sattı                12.679 ·  615.232 adet · 189.814.236 ₺
     B  rafta mal VAR, sıfır sattı    10.865 ·  138.599 adet ·  40.432.087 ₺  ← YANLIŞ ALARM
     C  raf boş, depoda var, sıfır       259 ·    2.589 adet ·   2.067.066 ₺
     D  hiç stok yok, sıfır            7.384 ·   54.218 adet ·  22.420.535 ₺  ← belirsiz
   B SANSÜRLÜ DEĞİLDİR: mal raftaydı ve satmadı → talep kaybı, stok yokluğu değil.
   D sansürlü OLABİLİR (satamadı çünkü yoktu) — ayırt edilemez, öyle etiketlendi. */


-- ── BLOK 3: SonSatis vekili yeterli mi? (kolon eklemeden bayrak kurulabilir mi) ──
WITH bu AS (
    SELECT h.ehstkID AS stkID, -SUM(h.ehAdetN) AS BuSezon
    FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
    WHERE h.ehMekan IN (1,4477,4478) AND h.ehTip IN (1,3,4,5,100,101)
      AND h.ehTrhS >= '20260801' AND h.ehTrhS < DATEADD(DAY,1,@k)
    GROUP BY h.ehstkID)
SELECT COUNT(*) AS Cesit,
       SUM(CASE WHEN ISNULL(bu.BuSezon,0) > 0 THEN 1 ELSE 0 END)  AS OlculenSatti,
       SUM(CASE WHEN t.SonSatis >= '20260801' THEN 1 ELSE 0 END)  AS SonSatisVekili,
       SUM(CASE WHEN ISNULL(bu.BuSezon,0) > 0
                 AND (t.SonSatis IS NULL OR t.SonSatis < '20260801') THEN 1 ELSE 0 END) AS VekilKACIRDI,
       SUM(CASE WHEN ISNULL(bu.BuSezon,0) <= 0
                 AND t.SonSatis >= '20260801' THEN 1 ELSE 0 END)   AS VekilYanlisPozitif
FROM DerinSISBkm.bkm.SatisAnaliziTaban t WITH (NOLOCK)
LEFT JOIN bu ON bu.stkID = t.stkID
WHERE t.Kesim = @k AND t.SezonYil = 2025 AND t.SezonToplam > 0
  AND t.StokFsm >= 0 AND t.StokOzl >= 0 AND t.StokIst >= 0 AND t.MerkezStok >= 0
  AND t.SatisFiyat > 0;
/* SONUÇ: 85.274 çeşit · ölçülen 37.075 · vekil 37.534 · KAÇIRDI 0 · yanlış pozitif 459
   Vekil bayrak olarak neredeyse kusursuz ama ADEDİ vermiyor; 459 yanlış pozitif
   iadesi satışını götüren ürünler (SonSatis satış OLAYINI sayar, net adedi değil).
   ⇒ Rapora gerçek ADET kondu (gh/bh CTE'leri), vekil KULLANILMADI. */


-- ── BLOK 4: hizalama — takvim mi okul mu? (kolonun tanımını belirleyen ölçüm) ────
-- Emitter iki yıl için de AÇILIŞTAN GERİYE 44 gün alır:
--   geçen yıl 26.07.2025–07.09.2025 · bu yıl 01.08.2026–13.09.2026
-- Takvim günüyle (01.08–13.09 her iki yıl) hizalamak YANLIŞ olurdu: okul açılışı
-- 08.09.2025 → 14.09.2026, altı gün kaydı. Ölçülmüş bedeli (14.09.2026, arşiv
-- 2026-09-14-sezon-stok-yaniltici-alti-madde.sql): Hazırlık Kitapları sezon büyümesi
-- takvimle 0,727 ("%27 küçüldü"), okula hizalı 1,104 ("%10 büyüdü") — ZIT sonuç.
