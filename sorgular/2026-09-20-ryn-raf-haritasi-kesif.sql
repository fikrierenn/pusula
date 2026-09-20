/* ============================================================================
   2026-09-20 — MAĞAZA RAF HARİTASI KEŞFİ  (DB: DerinSISBkm)
   Soru: mağaza personeli için "ürün nerede" uygulaması yazılabilir mi — raf
         adresi verisi var mı, kapsaması ne, tazeliği ne, kim sürdürüyor?
   Bulgu özeti:
     · ryn.* şeması tam mağaza yerleşim hiyerarşisi taşıyor (kat→alan→reyon→rafGrp→raf→rafUrun)
     · bkm.SUBE_RAFLARI (raf master) + bkm.SUBE_RAF_LISTE (raf+ürün) hazır view'lar
     · ⚠ SUBE_RAF_LISTE ürün başına TEK satır verir — bkm.UrunRafla SP'si her raflamada
       ryn.rafUrun'daki önceki satırı SİLİYOR. Çoklu konum (ada/depo) yalnız bkm.SayimRaflari'nda.
     · bkm.SayimLog 13,5M satır, bugün de işlem var → bakım CANLI
   Plan: plans/50-magaza-urun-bulma-uygulamasi.md
   ============================================================================ */

-- ---------------------------------------------------------------------------
-- 1) ryn şeması — tablo ve satır sayıları
-- Bulgu: rafUrun 478.209 · raf 23.327 · rafGrp 1.385 · reyon 576 · alan 40 · kat 16
--        reyonTnm / reyonKtgr / urunPlan BOŞ (0 satır)
-- ---------------------------------------------------------------------------
SELECT s.name AS sch, t.name AS tbl,
       SUM(CASE WHEN p.index_id IN (0,1) THEN p.row_count ELSE 0 END) AS satir
FROM sys.tables t
JOIN sys.schemas s ON s.schema_id = t.schema_id
LEFT JOIN sys.dm_db_partition_stats p ON p.object_id = t.object_id
WHERE s.name = 'ryn'
GROUP BY s.name, t.name
ORDER BY satir DESC;

-- ---------------------------------------------------------------------------
-- 2) rafUrun bağı ÇİFT kolonlu — hipotez testi
-- Bulgu: rafUrnID = raf.rafID VE rafUrnGrpID = rafGrp.rafgrpID → 475.871 (view ile birebir)
--        Yalnız rafUrnGrpID ile bağlamak 478.209 verir = 2.338 satır FAZLA (öksüz raf ref.)
--        rafUrnID tekil değer sayısı yalnız 18.855 → identity PK DEĞİL, raf referansı
-- ---------------------------------------------------------------------------
SELECT 'composite raf+grp' AS hipotez, COUNT(*) AS n
FROM ryn.rafUrun ru
JOIN ryn.raf f ON f.rafID = ru.rafUrnID AND f.rafRafGrpID = ru.rafUrnGrpID
UNION ALL SELECT 'yalniz grp (YANLIS)', COUNT(*)
FROM ryn.rafUrun ru JOIN ryn.rafGrp g ON g.rafgrpID = ru.rafUrnGrpID
UNION ALL SELECT 'view SUBE_RAF_LISTE', COUNT(*) FROM bkm.SUBE_RAF_LISTE
UNION ALL SELECT 'rafUrnID tekil', COUNT(DISTINCT ru.rafUrnID) FROM ryn.rafUrun ru;

-- ---------------------------------------------------------------------------
-- 3) Mağaza bazında harita büyüklüğü
-- Bulgu: FSM 241 reyon/585 rafgrp/170.062 ürün · Özlüce 202/442/163.811
--        İst.Yolu 129/356/141.996 · HEYKEL ve merkez depo YOK
-- ---------------------------------------------------------------------------
SELECT k.katMekan, m.mekanAd,
       COUNT(DISTINCT r.reyonID) AS reyon, COUNT(DISTINCT g.rafgrpID) AS rafgrp,
       COUNT(DISTINCT ru.rafUrnStkID) AS urun_cesit, COUNT(ru.rafUrnID) AS satir
FROM ryn.kat k
LEFT JOIN dbo.posMagaza m ON m.mekanID = k.katMekan
LEFT JOIN ryn.alan a  ON a.alanKatID   = k.katID
LEFT JOIN ryn.reyon r ON r.reyonAlanID = a.alanID
LEFT JOIN ryn.rafGrp g ON g.rafgrpReyonID = r.reyonID
LEFT JOIN ryn.rafUrun ru ON ru.rafUrnGrpID = g.rafgrpID
GROUP BY k.katMekan, m.mekanAd
ORDER BY satir DESC;

-- ---------------------------------------------------------------------------
-- 4) KAPSAMA — stokta olan çeşidin kaçının raf adresi var
-- Bulgu: FSM 133.811/175.825 = %76,1 · İst.Yolu %81,5 · Özlüce %74,2
-- ---------------------------------------------------------------------------
WITH h AS (SELECT DISTINCT mekan, stkId FROM bkm.SUBE_RAF_LISTE),
     s AS (SELECT ehMekan AS mekan, ehstkID AS stkID
           FROM dbo.stokSonAltDepo_vw
           WHERE ehMekan IN (1, 4477, 4478)
           GROUP BY ehMekan, ehstkID
           HAVING SUM(stok) > 0)
SELECT s.mekan, COUNT(*) AS stokta,
       SUM(CASE WHEN h.stkId IS NOT NULL THEN 1 ELSE 0 END) AS rafi_var,
       CAST(100.0 * SUM(CASE WHEN h.stkId IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*) AS decimal(5,1)) AS yuzde
FROM s LEFT JOIN h ON h.mekan = s.mekan AND h.stkId = s.stkID
GROUP BY s.mekan;

-- ---------------------------------------------------------------------------
-- 5) TAZELİK VEKİLİ — ürünün mağazaya ilk gelişine göre kapsama (FSM)
-- Bulgu: son 90 gün %65,4 · 90g-1yıl %74,5 · 1 yıldan eski %76,8
--        ⇒ harita YENİ üründe zayıf (personelin en çok aradığı yer)
-- ⚠ Sınır: "ilk hareket" = mağazaya ilk giriş, "raflanmalıydı" değil.
-- ---------------------------------------------------------------------------
WITH ilk AS (SELECT ehstkID, MIN(ehTrhS) AS ilk_hrk FROM dbo.irsHrk WHERE ehMekan = 1 GROUP BY ehstkID),
     s   AS (SELECT ehstkID AS stkID FROM dbo.stokSonAltDepo_vw WHERE ehMekan = 1 GROUP BY ehstkID HAVING SUM(stok) > 0),
     h   AS (SELECT DISTINCT stkId FROM bkm.SUBE_RAF_LISTE WHERE mekan = 1)
SELECT CASE WHEN i.ilk_hrk >= DATEADD(day,-90,GETDATE())  THEN '1) son 90 gun'
            WHEN i.ilk_hrk >= DATEADD(day,-365,GETDATE()) THEN '2) 90g-1yil'
            ELSE '3) 1 yildan eski' END AS grup,
       COUNT(*) AS stokta,
       SUM(CASE WHEN h.stkId IS NOT NULL THEN 1 ELSE 0 END) AS rafi_var
FROM s
JOIN ilk i ON i.ehstkID = s.stkID
LEFT JOIN h ON h.stkId = s.stkID
GROUP BY CASE WHEN i.ilk_hrk >= DATEADD(day,-90,GETDATE())  THEN '1) son 90 gun'
              WHEN i.ilk_hrk >= DATEADD(day,-365,GETDATE()) THEN '2) 90g-1yil'
              ELSE '3) 1 yildan eski' END
ORDER BY 1;

-- ---------------------------------------------------------------------------
-- 6) "ÇÖP KOVA" TESTİ — raf başına ürün dağılımı
-- Bulgu: ort. 22,7-29,9 ürün/raf → GERÇEK fiziksel granülarite (toplu atama değil)
--        Dev kovalar küçük: FSM SHF-0001 3.693 ürün (%2,2) · İst.Yolu %3,2 · Özlüce %1,3
-- ---------------------------------------------------------------------------
WITH r AS (SELECT mekan, rafAD, COUNT(DISTINCT stkId) AS urun FROM bkm.SUBE_RAF_LISTE GROUP BY mekan, rafAD)
SELECT mekan, COUNT(*) AS raf_sayisi, SUM(urun) AS toplam_atama,
       SUM(CASE WHEN urun > 500 THEN urun ELSE 0 END) AS dev_raflardaki,
       SUM(CASE WHEN urun > 500 THEN 1 ELSE 0 END)    AS dev_raf_adedi,
       MAX(urun) AS en_kalabalik,
       CAST(AVG(CAST(urun AS float)) AS decimal(6,1)) AS ort_urun
FROM r GROUP BY mekan;

-- ---------------------------------------------------------------------------
-- 7) ⚠ ÇOKLU KONUM — SUBE_RAF_LISTE'de YOK, bkm.SayimRaflari'nda VAR
-- GMY düzeltmesi: "bir ürün birden fazla reyona girebilir — çok satanlar adaları,
-- mağaza deposu gibi". Ölçüm bunu doğruladı:
--   Özlüce 5.725 ürün çok konumlu (en fazla 20) · İst.Yolu 2.777 · FSM 1.226
-- ---------------------------------------------------------------------------
WITH k AS (SELECT MekanId, StokId, COUNT(DISTINCT RafAd) AS konum
           FROM bkm.SayimRaflari GROUP BY MekanId, StokId)
SELECT MekanId, COUNT(*) AS urun,
       SUM(CASE WHEN konum = 1 THEN 1 ELSE 0 END)  AS tek,
       SUM(CASE WHEN konum = 2 THEN 1 ELSE 0 END)  AS iki,
       SUM(CASE WHEN konum >= 3 THEN 1 ELSE 0 END) AS uc_arti,
       MAX(konum) AS en_fazla
FROM k GROUP BY MekanId;

-- 7b) İkinci konumlar hangi raflar? → ADA / KLADA / CO-ADA (adalar),
--     HZDP* / HZM* / HZA* (hazırlık-mağaza deposu), VIP / STA (stant)
WITH cok AS (SELECT MekanId, StokId FROM bkm.SayimRaflari
             GROUP BY MekanId, StokId HAVING COUNT(DISTINCT RafAd) > 1)
SELECT TOP 30 s.MekanId, s.RafAd, COUNT(*) AS urun,
       CASE WHEN EXISTS (SELECT 1 FROM bkm.SUBE_RAF_LISTE v
                         WHERE v.mekan = s.MekanId AND v.rafAD = s.RafAd)
            THEN 'ryn de VAR' ELSE 'ryn de YOK' END AS rynde
FROM bkm.SayimRaflari s
JOIN cok c ON c.MekanId = s.MekanId AND c.StokId = s.StokId
GROUP BY s.MekanId, s.RafAd
ORDER BY urun DESC;

-- ---------------------------------------------------------------------------
-- 8) MEKANİZMA — raflama alt sistemini kim yazıyor
-- Bulgu: bkm.UrunRafla / UrunRafCikar / UrunRafBosalt / UrunTasi / SayimRafAktar /
--        SayimRafGuncelle / RaflanmamisDuzenle (+ view SayimRafBirlestirme)
-- UrunRafla gövdesi: ryn.rafUrun'da mekan içindeki TÜM satırları siler, tek satır ekler;
--   SayimRaflari'na CokluRaf=0 ise sil-yaz, CokluRaf<>0 ise EKLE (çoklu konum buradan doğuyor)
-- ---------------------------------------------------------------------------
SELECT s.name AS sch, o.name AS obje, o.type_desc,
       CASE WHEN m.definition LIKE '%INSERT%SayimRaflari%' OR m.definition LIKE '%INTO%SayimRaflari%'
            THEN 'YAZIYOR' ELSE 'okuyor/geciyor' END AS rol
FROM sys.sql_modules m
JOIN sys.objects o ON o.object_id = m.object_id
JOIN sys.schemas s ON s.schema_id = o.schema_id
WHERE m.definition LIKE '%SayimRaflari%'
ORDER BY rol, s.name, o.name;

-- ---------------------------------------------------------------------------
-- 9) BAKIM CANLI MI — bkm.SayimLog
-- Bulgu: 13,5M+ satır; Tip 5 (5,39M) · 2 (4,88M) · 6 raflama (2,67M) · 1/3/4/7..10
--        İlk kayıt 30.10.2023, son kayıt ölçüm anında (20.09.2026 15:10) = CANLI
--        Son 30 gün raflama: FSM 19.190 · İst.Yolu 16.876 · Özlüce 13.435 — 31/31 gün
-- ⚠ SayimLog'da KULLANICI kolonu YOK (SayimLogId, LogDate, MekanId, RafNo, Tip, StokId)
-- ---------------------------------------------------------------------------
SELECT Tip, COUNT(*) AS satir, MIN(LogDate) AS ilk, MAX(LogDate) AS son,
       COUNT(DISTINCT MekanId) AS mekan
FROM bkm.SayimLog GROUP BY Tip ORDER BY satir DESC;

SELECT MekanId, COUNT(*) AS raflama_30g, COUNT(DISTINCT StokId) AS urun,
       COUNT(DISTINCT CAST(LogDate AS date)) AS gun
FROM bkm.SayimLog
WHERE Tip = 6 AND LogDate >= DATEADD(day,-30,GETDATE())
GROUP BY MekanId ORDER BY raflama_30g DESC;

-- ---------------------------------------------------------------------------
-- 10) ÜRÜN GÖRSELİ — kaynak arayışı
-- Bulgu: web.urnWeb BOŞ (0 satır, kullanılmaz).
--        ent.tsoft_urun.ImageUrl 441.097/441.163 dolu (%99,98), değer DOSYA ADI → CDN tabanı gerek
-- ⚠ Kapsam e-ticarete açılmış ürün (441K); mağaza master'ına (~850K) göre kapsama ÖLÇÜLMEDİ
-- ---------------------------------------------------------------------------
SELECT COUNT(*) AS satir,
       SUM(CASE WHEN ImageUrl IS NOT NULL AND ImageUrl <> '' THEN 1 ELSE 0 END) AS resimli,
       MAX(ImageUrl) AS ornek
FROM ent.tsoft_urun;
