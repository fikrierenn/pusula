-- İST. YOLU hafta tatili çalışması neden diğerlerinin 2,5 katı? (GMY 21.09.2026)
-- DB: BkmPanel (DEV) + DerinSISBkm/EncoreMerkez (salt-okuma). Pencere 01-16 Eylül 2026.
--
-- ⚠⚠ ÖNCE BİR DÜZELTME — `HaftalikPrimDk` ÖLÇÜLEN ÇALIŞMA DEĞİL, SABİT KREDİ.
--    Ölçüldü: mağazalarda HER satırda tam 450 dk, GENEL MÜDÜRLÜK'te tam 540 dk
--    (min=max=ort). Yani "525 saat" = 70 kişi-gün × 7,5 sa. O günlerde FİİLEN
--    çalışılan süre `CalismaDk`'dadır ve 643 saattir (3 günü şüpheli okutma).
--    Kaleme "saat" demek ile "prim" demek aynı şey değil; toplamı ciro gibi okuma.

DECLARE @b date='2026-09-01', @s date='2026-09-16';

-- 1) Prim SABİT Mİ? (min=max ise ölçüm değil kredidir)
SELECT Sube, COUNT(*) gun, COUNT(DISTINCT SicilNo) kisi,
       MIN(HaftalikPrimDk) mn, MAX(HaftalikPrimDk) mx,
       SUM(HaftalikPrimDk)/60.0 prim_saat, SUM(CalismaDk)/60.0 fiili_saat
FROM bkm.Vrd_KisiGun WHERE Tarih BETWEEN @b AND @s AND HaftalikPrimDk>0
GROUP BY Sube ORDER BY SUM(HaftalikPrimDk) DESC;
-- Bulgu: mn=mx=450 (GM 540). İST.YOLU 70 gün/41 kişi, fiili 643 sa.

-- 2) Hangi günler? (yığılma var mı)
SELECT Tarih, DATENAME(weekday,Tarih) gun_adi, COUNT(*) kisi, SUM(CalismaDk)/60.0 fiili
FROM bkm.Vrd_KisiGun WHERE Tarih BETWEEN @b AND @s AND Sube='İST. YOLU' AND HaftalikPrimDk>0
GROUP BY Tarih, DATENAME(weekday,Tarih) ORDER BY Tarih;
-- Bulgu: YALNIZ iki Pazar — 06.09 (32 kişi) ve 13.09 (38 kişi).

-- 3) ASIL SORU: Pazar açık olmak fark mı? (prim ancak 7/7 çalışılınca doğar)
SELECT Sube, COUNT(DISTINCT SicilNo) kadro,
       SUM(CASE WHEN Tarih IN ('20260906','20260913') AND CalismaDk>0 THEN 1 ELSE 0 END) pazar_calisan,
       SUM(CASE WHEN Tarih IN ('20260906','20260913') AND HaftalikPrimDk>0 THEN 1 ELSE 0 END) primli
FROM bkm.Vrd_KisiGun WHERE Tarih BETWEEN @b AND @s GROUP BY Sube ORDER BY 3 DESC;
-- Bulgu: Pazar çalışması HER mağazada var (İY 113 · ÖZ 106 · FSM 80 · HEY 78).
--        Primli oranı: İY %62 · ÖZ %26 · FSM %25 · HEY %28. Fark PAZAR DEĞİL,
--        Pazar çalışanına hafta içi TELAFİ İZNİ verilip verilmemesi.

-- 4) Telafi izni ölçümü — kişi başına çalışılmayan gün
SELECT Sube, COUNT(DISTINCT SicilNo) kisi,
       SUM(CASE WHEN CalismaDk>0 THEN 1.0 ELSE 0 END)/COUNT(DISTINCT SicilNo) gun_basi_calisilan,
       SUM(CASE WHEN ISNULL(CalismaDk,0)=0 THEN 1.0 ELSE 0 END)/COUNT(DISTINCT SicilNo) gun_basi_bos
FROM bkm.Vrd_KisiGun WHERE Tarih BETWEEN @b AND @s GROUP BY Sube ORDER BY 4;
-- Bulgu: İY kişi başı boş gün 1,9 — DOKUZ ŞUBENİN EN DÜŞÜĞÜ. ÖZ 2,7 · FSM 2,2.
--        Aynı kadro (62) ile İY 858, ÖZ 797 kişi-gün çalışmış.

-- 5) Bölüm karması açıklıyor mu? (HAYIR — fark yaygın)
SELECT Bolum,
       SUM(CASE WHEN Sube='İST. YOLU' THEN 1 ELSE 0 END)
         /NULLIF(COUNT(DISTINCT CASE WHEN Sube='İST. YOLU' THEN SicilNo END),0) iy_gun,
       SUM(CASE WHEN Sube='ÖZLÜCE' THEN 1 ELSE 0 END)
         /NULLIF(COUNT(DISTINCT CASE WHEN Sube='ÖZLÜCE' THEN SicilNo END),0) oz_gun
FROM bkm.Vrd_KisiGun WHERE Tarih BETWEEN @b AND @s AND CalismaDk>0
  AND Sube IN ('İST. YOLU','ÖZLÜCE') GROUP BY Bolum ORDER BY 2 DESC;
-- Bulgu: her bölümde 13-15 gün; tek bir bölümün yükü değil.

-- ══ YAPISAL AÇIKLAMA — SINAV OKULLARI (EncoreMerkez, belge bazlı) ══
-- Kanal ayracı BELGE bazlıdır: DocumentsTypeId=8 (sql-server-conventions).
-- StoresId 1=İst.Yolu(M03) · 2=FSM(M01) · 3=Özlüce(M02).
SELECT s.StoresId,
       CASE WHEN s.DocumentsTypeId=8 THEN 'SINAV' ELSE 'PERAKENDE' END kanal,
       COUNT(DISTINCT s.Id) belge,
       SUM(CASE WHEN s.DocumentsTypeId=3 THEN -sp.Amount ELSE sp.Amount END) adet,
       SUM(CASE WHEN s.DocumentsTypeId=3
                THEN -(s.GrossTotal-s.DiscountTotal-s.VatTotal)
                ELSE  (s.GrossTotal-s.DiscountTotal-s.VatTotal) END) net_ciro
FROM dbo.Sales s
JOIN dbo.SalesProducts sp ON sp.SalesId=s.Id AND sp.IsValid=1
WHERE s.Date >= '20260901' AND s.Date < '20260917'
  AND s.DocumentsTypeId IN (1,2,3,6,7,8)
GROUP BY s.StoresId, CASE WHEN s.DocumentsTypeId=8 THEN 'SINAV' ELSE 'PERAKENDE' END;
-- Bulgu: Sınav YALNIZ İst.Yolu'nda — 4.794 belge · 148.387 adet · 289,6M ₺.
--        İst.Yolu PERAKENDE cirosu ise EN DÜŞÜK (18,8M; ÖZ 29,8M · FSM 19,1M).
--        Kişi-gün başına kalem: İY 309 · ÖZ 244 · FSM 192.
--        ⇒ Dinlenme günü verilememesinin ölçülebilir bir yük karşılığı VAR.
