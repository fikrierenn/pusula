/* ============================================================================
   2026-09-20 — MAĞAZA APP: KATEGORİ KURALI + ARAMA VERİ KALİTESİ  (DerinSISBkm)
   Kardeş dosya: sorgular/2026-09-20-ryn-raf-haritasi-kesif.sql
   Tetik: GMY iki düzeltme yaptı —
     (1) "sadece kitap raflanıyor, kırtasiye/oyuncak/hediyelik rafsız"
     (2) "yazar isimleri çok sıkıntılı, aynı yazar 3-5 farklı yazımda olabilir"
   Bulgu özeti:
     · Raf kuralı KİTABA özgü: kitapta kapsama %99,0-99,4, kırtasiyede %0,6
       ⇒ ilk ölçümdeki "%74-81 kapsama" YANLIŞ PAYDAYDI (kitap+kırtasiye aynı kefede)
     · Yazar: 173.055 yazım, soyadla 59.201 kümeye iner; Dostoyevski 4 ayrı YazarId
     · ryn.reyon koordinatları (reyonX/reyonY) 576/576 BOŞ → mağaza krokisi çizilemez
   Plan: plans/50-magaza-urun-bulma-uygulamasi.md
   ============================================================================ */

-- ---------------------------------------------------------------------------
-- 1) BUGÜN HANGİ İSTEMCİLER BAĞLI — "sayım/raflama programı hangisi"
-- Bulgu: DerinBilgi thick-client takımı, çoğu SRVTERM terminal sunucusundan:
--   DerinSis 56+46 · UrunAnaliz 34 · Irsaliye 20 · DepoPaletTanim 19 ·
--   UrunSorgulama 8 (+4 IST-KIRTASIYE) · Siparis 9 · DerinUs 9+1 · DepoEmir ·
--   MagazaKasa · CiroAnaliz · DerinHQ.Hub.Client (NCRSERVER)
-- ⚠ SayimLog'a hangisinin yazdığı BU SORGUYLA ÖLÇÜLMEZ — oturum listesi yalnız
--   "kim bağlı" der. İstemci teyidi Faz 0 işi.
-- ---------------------------------------------------------------------------
SELECT program_name, host_name, login_name, COUNT(*) AS oturum,
       MAX(last_request_end_time) AS son
FROM sys.dm_exec_sessions
WHERE is_user_process = 1
GROUP BY program_name, host_name, login_name
ORDER BY oturum DESC;

-- DerinUS el terminali tabloları: derinus2 5.989.880 (barkod/rafNo/palet okuma satırı) ·
-- derinus2_palet 1.594.791 · derinus3 730.509 · derinus1 175.852 (başlık: tMekan/tReyon/tTip/tTarih)
SELECT s.name AS sch, t.name AS tbl,
       SUM(CASE WHEN p.index_id IN (0,1) THEN p.row_count ELSE 0 END) AS satir
FROM sys.tables t
JOIN sys.schemas s ON s.schema_id = t.schema_id
LEFT JOIN sys.dm_db_partition_stats p ON p.object_id = t.object_id
WHERE s.name = 'drs'
GROUP BY s.name, t.name ORDER BY satir DESC;

-- ---------------------------------------------------------------------------
-- 2) ⭐ RAF KURALI KATEGORİYE BAĞLI — kapsama kategori kırılımında (FSM)
-- Bulgu: Edebiyat %100,0 · Çocuk %97,8 · diğer kitap %99-100
--        Kırtasiye %0,6 (32.368 çeşitte 205) · Hobi-Oyuncak %11,8 · Hediyelik %0,2
--        Elektronik %0,0 · Süpermarket %0,0
-- ---------------------------------------------------------------------------
WITH s AS (SELECT ehstkID AS stkID FROM dbo.stokSonAltDepo_vw
           WHERE ehMekan = 1 GROUP BY ehstkID HAVING SUM(stok) > 0),
     h AS (SELECT DISTINCT StokId FROM bkm.SayimRaflari WHERE MekanId = 1)
SELECT ISNULL(u.KatAna, '(kategorisiz)') AS kategori,
       COUNT(*) AS stokta,
       SUM(CASE WHEN h.StokId IS NOT NULL THEN 1 ELSE 0 END) AS rafi_var,
       CAST(100.0 * SUM(CASE WHEN h.StokId IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*) AS decimal(5,1)) AS yuzde
FROM s
LEFT JOIN bkm.UrunBilgi u ON u.StkID = s.stkID
LEFT JOIN h ON h.StokId = s.stkID
GROUP BY ISNULL(u.KatAna, '(kategorisiz)')
HAVING COUNT(*) > 200
ORDER BY stokta DESC;

-- ---------------------------------------------------------------------------
-- 3) DOĞRU PAYDA — kitap vs kitap dışı (üç mağaza)
-- Bulgu: KİTAP  FSM %99,2 · Özlüce %99,0 · İst.Yolu %99,4
--        KİTAP DIŞI  %21,6 / %20,3 / %35,6  (raflanması BEKLENMİYOR)
-- ⚠ "Kitap" ayracı KatAna metnine dayanıyor (LIKE '%Kitap%' + 3 istisna) — kaba bir
--   sınıflandırma; kalıcı kullanılacaksa kategori id tabanlı bir ayraç tanımlanmalı.
-- ---------------------------------------------------------------------------
WITH s AS (SELECT ehMekan AS mekan, ehstkID AS stkID FROM dbo.stokSonAltDepo_vw
           WHERE ehMekan IN (1,4477,4478) GROUP BY ehMekan, ehstkID HAVING SUM(stok) > 0),
     h AS (SELECT DISTINCT MekanId, StokId FROM bkm.SayimRaflari),
     t AS (SELECT s.mekan, s.stkID,
                  CASE WHEN u.KatAna LIKE '%Kitap%'
                         OR u.KatAna IN ('Edebiyat Kitapları','Akademik Kitaplar','Genel Konular')
                       THEN 'KITAP' ELSE 'KITAP DISI' END AS tur,
                  CASE WHEN h.StokId IS NOT NULL THEN 1 ELSE 0 END AS rafli
           FROM s
           LEFT JOIN bkm.UrunBilgi u ON u.StkID = s.stkID
           LEFT JOIN h ON h.MekanId = s.mekan AND h.StokId = s.stkID)
SELECT mekan, tur, COUNT(*) AS cesit, SUM(rafli) AS rafli,
       CAST(100.0 * SUM(rafli) / COUNT(*) AS decimal(5,1)) AS yuzde
FROM t GROUP BY mekan, tur ORDER BY mekan, tur;

-- 3b) Kitapta yeni ürün korkusu ÇÜRÜTÜLDÜ (FSM, yalnız kitap)
-- Bulgu: son 90 gün %96,7 · 90g-1yıl %99,3 · eski %99,2  (önceki "%65,4" kategori karmasıydı)
WITH ilk AS (SELECT ehstkID, MIN(ehTrhS) AS ilk_hrk FROM dbo.irsHrk WHERE ehMekan = 1 GROUP BY ehstkID),
     s   AS (SELECT ehstkID AS stkID FROM dbo.stokSonAltDepo_vw WHERE ehMekan = 1 GROUP BY ehstkID HAVING SUM(stok) > 0),
     h   AS (SELECT DISTINCT StokId FROM bkm.SayimRaflari WHERE MekanId = 1)
SELECT CASE WHEN i.ilk_hrk >= DATEADD(day,-90,GETDATE())  THEN '1) son 90 gun'
            WHEN i.ilk_hrk >= DATEADD(day,-365,GETDATE()) THEN '2) 90g-1yil'
            ELSE '3) eski' END AS yas,
       COUNT(*) AS kitap_cesit,
       SUM(CASE WHEN h.StokId IS NOT NULL THEN 1 ELSE 0 END) AS rafli
FROM s
JOIN ilk i ON i.ehstkID = s.stkID
JOIN bkm.UrunBilgi u ON u.StkID = s.stkID
LEFT JOIN h ON h.StokId = s.stkID
WHERE u.KatAna LIKE '%Kitap%' OR u.KatAna IN ('Edebiyat Kitapları','Akademik Kitaplar','Genel Konular')
GROUP BY CASE WHEN i.ilk_hrk >= DATEADD(day,-90,GETDATE())  THEN '1) son 90 gun'
              WHEN i.ilk_hrk >= DATEADD(day,-365,GETDATE()) THEN '2) 90g-1yil'
              ELSE '3) eski' END
ORDER BY 1;

-- ---------------------------------------------------------------------------
-- 4) SON RAFLAMA YAŞI — güven rozetinin kaynağı (FSM, stoktaki tüm çeşit)
-- Bulgu: 0-30 gün 14.446 · 31-90 18.698 · 91-365 99.830 · 1 yıl+ 900 ·
--        HİÇ RAFLANMAMIŞ 41.921  → kapsama açığıyla birebir tutuyor (çapraz doğrulama)
-- ---------------------------------------------------------------------------
WITH s AS (SELECT ehstkID AS stkID FROM dbo.stokSonAltDepo_vw WHERE ehMekan = 1 GROUP BY ehstkID HAVING SUM(stok) > 0),
     son AS (SELECT StokId, MAX(LogDate) AS son_raflama FROM bkm.SayimLog WHERE Tip = 6 AND MekanId = 1 GROUP BY StokId)
SELECT CASE WHEN son.son_raflama IS NULL THEN '9) hic raflanmamis'
            WHEN son.son_raflama >= DATEADD(day,-30,GETDATE())  THEN '1) 0-30 gun'
            WHEN son.son_raflama >= DATEADD(day,-90,GETDATE())  THEN '2) 31-90 gun'
            WHEN son.son_raflama >= DATEADD(day,-365,GETDATE()) THEN '3) 91-365 gun'
            ELSE '4) 1 yildan eski' END AS yas,
       COUNT(*) AS urun
FROM s LEFT JOIN son ON son.StokId = s.stkID
GROUP BY CASE WHEN son.son_raflama IS NULL THEN '9) hic raflanmamis'
              WHEN son.son_raflama >= DATEADD(day,-30,GETDATE())  THEN '1) 0-30 gun'
              WHEN son.son_raflama >= DATEADD(day,-90,GETDATE())  THEN '2) 31-90 gun'
              WHEN son.son_raflama >= DATEADD(day,-365,GETDATE()) THEN '3) 91-365 gun'
              ELSE '4) 1 yildan eski' END
ORDER BY 1;

-- ---------------------------------------------------------------------------
-- 5) ⚠ MAĞAZA KROKİSİ ÇİZİLEMEZ — koordinat kolonları var ama BOŞ
-- Bulgu: 576 reyonun 576'sında reyonX=reyonY=0, reyonEbat=0. "Kolon var" ≠ "veri var".
-- ---------------------------------------------------------------------------
SELECT k.katMekan, COUNT(*) AS reyon,
       SUM(CASE WHEN r.reyonX <> 0 OR r.reyonY <> 0 THEN 1 ELSE 0 END) AS koordinatli,
       SUM(CASE WHEN r.reyonEbat IS NOT NULL AND r.reyonEbat <> 0 THEN 1 ELSE 0 END) AS ebatli
FROM ryn.reyon r
JOIN ryn.alan a ON a.alanID = r.reyonAlanID
JOIN ryn.kat  k ON k.katID  = a.alanKatID
GROUP BY k.katMekan ORDER BY reyon DESC;

-- 5b) RafSira fiziksel sıra DEĞİL, ekleme sayacı (çöp rafta 3.976'ya çıkıyor) → arayüzde kullanılmaz
SELECT TOP 12 mekan, reyonAD, rafgrpAD, rafAD, RafSira, CokluRaf
FROM bkm.SUBE_RAF_LISTE WHERE mekan = 1 AND RafSira > 1 ORDER BY RafSira DESC;

-- ---------------------------------------------------------------------------
-- 6) ARAMA VERİ KALİTESİ — yazar adı varyantları
-- Bulgu: 173.055 farklı yazım. Basit normalizasyon (boşluk/nokta/virgül + Turkish_CI_AI)
--        yalnız 586'sını birleştiriyor → sorun büyük/küçük harf DEĞİL.
-- ---------------------------------------------------------------------------
WITH y AS (SELECT Yazar, COUNT(*) AS urun FROM bkm.UrunBilgi
           WHERE Yazar IS NOT NULL AND LTRIM(RTRIM(Yazar)) <> '' GROUP BY Yazar),
     n AS (SELECT Yazar, urun,
                  UPPER(REPLACE(REPLACE(REPLACE(REPLACE(Yazar,' ',''),'.',''),',',''),'-','')) COLLATE Turkish_CI_AI AS norm
           FROM y)
SELECT COUNT(DISTINCT Yazar) AS ham_yazar, COUNT(DISTINCT norm) AS normalize_yazar,
       COUNT(DISTINCT Yazar) - COUNT(DISTINCT norm) AS fazla_varyant
FROM n;

-- 6b) Somut vaka: aynı kişi 4 ayrı YazarId'de
-- Fyodor Mihayloviç Dostoyevski 900 · Fyodor Mihailoviç Dostoyevski 3 ·
-- Fyodor Dostoyevski 2 · Fyodor Dostoyevsky 2
-- ⚠ Aynı soyadda BAŞKA kişiler de var: Anna Grigoriyevna Dostoyevski 4 · Aimee Dostoyevski 1
--   ⇒ soyad ADAY üretir, KİMLİK değildir; otomatik birleştirme yanlış sonuç verir.
SELECT Yazar, COUNT(*) AS urun, COUNT(DISTINCT YazarId) AS yazarid
FROM bkm.UrunBilgi
WHERE Yazar LIKE '%osto%vsk%' OR Yazar LIKE '%osto%evski%'
GROUP BY Yazar ORDER BY urun DESC;

-- 6c) Soyad tokenıyla kümeleme ne kadar topluyor
-- Bulgu: 173.055 yazım → 59.201 soyad kümesi (%66 birleşme); 1.381 kümenin soyadı <3 harf (riskli)
WITH y AS (SELECT DISTINCT LTRIM(RTRIM(Yazar)) AS Yazar FROM bkm.UrunBilgi
           WHERE Yazar IS NOT NULL AND LTRIM(RTRIM(Yazar)) <> ''),
     s AS (SELECT Yazar,
                  UPPER(REVERSE(LEFT(REVERSE(Yazar), CHARINDEX(' ', REVERSE(Yazar) + ' ') - 1))) COLLATE Turkish_CI_AI AS soyad
           FROM y)
SELECT COUNT(*) AS ham_yazim, COUNT(DISTINCT soyad) AS soyad_kumesi,
       SUM(CASE WHEN LEN(soyad) < 3 THEN 1 ELSE 0 END) AS kisa_soyad_riskli
FROM s;
