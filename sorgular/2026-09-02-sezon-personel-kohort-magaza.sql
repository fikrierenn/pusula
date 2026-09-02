/*
  Soru: Gecen yil sezon icin alinan personelin seyri ile bu yil alinanin seyri -- MAGAZA BAZLI.
  DB: Zirve BKM_GENEL (MCP: zirve) -- kanonik IK kaynagi dbo.vw_PersonelDepartman.

  *** SEZON PERSONELI AYRACI = Kadro = 'SEZONLUK' (Zirve'nin kendi bayragi) ***
  TUZAK (bu oturumda yasandi): sezon kohortunu YALNIZ giris tarihi penceresiyle
  (Igt 1 Tem - 2 Eyl) tanimlamak YANLIS. O pencere ayni donemde alinan KADROLU
  personeli de kapsar (2026'da 61 kisi) ve olcumu bozar:
      karisik pencere  -> 14g tutunma %83,2 ("sezon kadrosu eriyor" yanlis sonucu)
      Kadro=SEZONLUK   -> 14g tutunma %91,8 (gecen yil %93,3 -- normal)
      Kadro<>SEZONLUK  -> 14g tutunma %75,5 (gecen yil %92,1 -- BOZULMA BURADA)
  Bayrak 01.08.2023'ten beri kullaniliyor (288 kayit, 77 aktif). Sezonluk alimin
  tamami Tem-Agu-Eyl'e dusuyor; pencere yine gerekli ama TEK BASINA yeterli degil.

  Kohort: Kadro='SEZONLUK' AND Igt 1 Tem - 2 Eyl. Anchor 2 Eylul = analiz gunu;
  uc yil ayni takvim gununde kesilir (adil kiyas).
  Censoring KRITIK: "bugun aktif" yillar arasi KIYASLANAMAZ (2026 kohortu henuz
  Eylul tahliye dalgasini gormedi). Dogru olcut = esit-kidem survival (risk14/kalan14,
  risk30/kalan30) + Eylul-oncesi kayip (Tem-Agu penceresi her yil tam kapanmis).

  Bulgu (2026-09-02, SEZONLUK): alim 73(2024)/83(2025)/86(2026) · 14g tutunma
  %92,7/%93,3/%91,8 · Eylul oncesi kayip 7/9/10 kisi. Magaza: Ist.Yolu iki yil
  ust uste 0 erken kayip (26 kisi) · Heykel %100 -> %71,4 (tek gercek bozulma)
  · Ozluce + Merkez Depo iki yildir kaybediyor (kronik).
  NOT: Ict IS NULL = aktif (Personeldurumu DEGIL). Personelno alfanumerik. View 3 firmayi birlestirir.
  NOT: Sezonluktan kadroya gecis Kadro alaninda IZ BIRAKMAZ (tarihce yok) -> donusum olculemez.
*/

-- 0) AYRAC KESFI: Kadro alani dagilimi (bu sorgu atlanmaz -- bayragin varligini teyit eder)
SELECT ISNULL(Kadro,'(NULL)') AS kadro, COUNT(*) AS toplam,
       SUM(CASE WHEN Ict IS NULL THEN 1 ELSE 0 END) AS aktif,
       MIN(Igt) AS ilk_giris, MAX(Igt) AS son_giris
FROM dbo.vw_PersonelDepartman
GROUP BY Kadro
ORDER BY 2 DESC;
-- KADRO 968/268 · SEZONLUK 288/77 · (NULL) 9 · bos 3 · STAJYER 2 · PART-TIME 1 · PART TIME 1 · KISMI 1
-- Veri kalitesi borcu: 'PART-TIME' ve 'PART TIME' ayri yazilmis + 12 bos/NULL kayit

-- 1) Sezon penceresi teyidi: SEZONLUK alim ay bazli (Tem-Agu-Eyl yogunlugu)
SELECT YEAR(Igt) AS yil, MONTH(Igt) AS ay, COUNT(*) AS sezonluk_alim,
       SUM(CASE WHEN Ict IS NULL THEN 1 ELSE 0 END) AS halen_aktif
FROM dbo.vw_PersonelDepartman
WHERE Kadro = 'SEZONLUK'
GROUP BY YEAR(Igt), MONTH(Igt)
ORDER BY 1, 2;

-- 2) SEGMENT KIYASI (tuzagin kaniti): ayni pencere, Kadro tipine gore ayrilmis
WITH k AS (
    SELECT Igt, Ict, ISNULL(Kadro,'(NULL)') AS kadro, YEAR(Igt) AS kohort,
           CONVERT(datetime, CAST(YEAR(Igt) AS varchar(4)) + '0902', 112) AS anchor
    FROM dbo.vw_PersonelDepartman
    WHERE (Igt >= '20240701' AND Igt < '20240903')
       OR (Igt >= '20250701' AND Igt < '20250903')
       OR (Igt >= '20260701' AND Igt < '20260903')
)
SELECT kadro, kohort,
       COUNT(*) AS alinan,
       SUM(CASE WHEN Ict IS NULL THEN 1 ELSE 0 END) AS bugun_aktif,
       SUM(CASE WHEN Ict IS NOT NULL AND Ict < DATEADD(DAY,-1,anchor) THEN 1 ELSE 0 END) AS eylul_oncesi_ayrilan,
       SUM(CASE WHEN Igt <= DATEADD(DAY,-14,anchor) THEN 1 ELSE 0 END) AS risk14,
       SUM(CASE WHEN Igt <= DATEADD(DAY,-14,anchor) AND (Ict IS NULL OR DATEDIFF(DAY,Igt,Ict) >= 14) THEN 1 ELSE 0 END) AS kalan14,
       SUM(CASE WHEN Igt <= DATEADD(DAY,-30,anchor) THEN 1 ELSE 0 END) AS risk30,
       SUM(CASE WHEN Igt <= DATEADD(DAY,-30,anchor) AND (Ict IS NULL OR DATEDIFF(DAY,Igt,Ict) >= 30) THEN 1 ELSE 0 END) AS kalan30
FROM k
GROUP BY kadro, kohort
ORDER BY kadro, kohort;

-- 3) SEZONLUK kohort ozeti + esit-kidem survival
WITH k AS (
    SELECT Igt, Ict, YEAR(Igt) AS kohort,
           CONVERT(datetime, CAST(YEAR(Igt) AS varchar(4)) + '0902', 112) AS anchor
    FROM dbo.vw_PersonelDepartman
    WHERE Kadro = 'SEZONLUK'
      AND ((Igt >= '20240701' AND Igt < '20240903')
        OR (Igt >= '20250701' AND Igt < '20250903')
        OR (Igt >= '20260701' AND Igt < '20260903'))
)
SELECT kohort,
       COUNT(*) AS alinan,
       SUM(CASE WHEN Ict IS NULL THEN 1 ELSE 0 END) AS bugun_aktif,          -- yillar arasi kiyaslamaz
       SUM(CASE WHEN Ict IS NOT NULL AND Ict < DATEADD(DAY,-1,anchor) THEN 1 ELSE 0 END) AS eylul_oncesi_ayrilan,
       SUM(CASE WHEN Igt <= DATEADD(DAY,-14,anchor) THEN 1 ELSE 0 END) AS risk14,
       SUM(CASE WHEN Igt <= DATEADD(DAY,-14,anchor) AND (Ict IS NULL OR DATEDIFF(DAY,Igt,Ict) >= 14) THEN 1 ELSE 0 END) AS kalan14,
       SUM(CASE WHEN Igt <= DATEADD(DAY,-30,anchor) THEN 1 ELSE 0 END) AS risk30,
       SUM(CASE WHEN Igt <= DATEADD(DAY,-30,anchor) AND (Ict IS NULL OR DATEDIFF(DAY,Igt,Ict) >= 30) THEN 1 ELSE 0 END) AS kalan30,
       AVG(CASE WHEN Ict IS NOT NULL THEN DATEDIFF(DAY,Igt,Ict) END) AS ort_kalis_gun
FROM k
GROUP BY kohort
ORDER BY kohort;

-- 4) MAGAZA BAZLI (ana tablo) -- SEZONLUK, sube x kohort
WITH k AS (
    SELECT Igt, Ict, ISNULL(Lokasyon,'(bos)') AS grup, ISNULL(AltLokasyon,'(bos)') AS sube,
           YEAR(Igt) AS kohort,
           CONVERT(datetime, CAST(YEAR(Igt) AS varchar(4)) + '0902', 112) AS anchor
    FROM dbo.vw_PersonelDepartman
    WHERE Kadro = 'SEZONLUK'
      AND ((Igt >= '20240701' AND Igt < '20240903')
        OR (Igt >= '20250701' AND Igt < '20250903')
        OR (Igt >= '20260701' AND Igt < '20260903'))
)
SELECT grup, sube, kohort,
       COUNT(*) AS alinan,
       SUM(CASE WHEN Ict IS NULL THEN 1 ELSE 0 END) AS bugun_aktif,
       SUM(CASE WHEN Ict IS NOT NULL AND Ict < DATEADD(DAY,-1,anchor) THEN 1 ELSE 0 END) AS eylul_oncesi_ayrilan,
       SUM(CASE WHEN Igt <= DATEADD(DAY,-14,anchor) THEN 1 ELSE 0 END) AS risk14,
       SUM(CASE WHEN Igt <= DATEADD(DAY,-14,anchor) AND (Ict IS NULL OR DATEDIFF(DAY,Igt,Ict) >= 14) THEN 1 ELSE 0 END) AS kalan14,
       SUM(CASE WHEN Igt <= DATEADD(DAY,-30,anchor) THEN 1 ELSE 0 END) AS risk30,
       SUM(CASE WHEN Igt <= DATEADD(DAY,-30,anchor) AND (Ict IS NULL OR DATEDIFF(DAY,Igt,Ict) >= 30) THEN 1 ELSE 0 END) AS kalan30
FROM k
GROUP BY grup, sube, kohort
ORDER BY sube, kohort;

-- 4b) Ayni tablo KADROLU (Kadro <> 'SEZONLUK') -- bozulmanin nerede oldugunu gosterir
WITH k AS (
    SELECT Igt, Ict, ISNULL(AltLokasyon,'(bos)') AS sube, YEAR(Igt) AS kohort,
           CONVERT(datetime, CAST(YEAR(Igt) AS varchar(4)) + '0902', 112) AS anchor
    FROM dbo.vw_PersonelDepartman
    WHERE ISNULL(Kadro,'X') <> 'SEZONLUK'
      AND ((Igt >= '20250701' AND Igt < '20250903')
        OR (Igt >= '20260701' AND Igt < '20260903'))
)
SELECT sube, kohort,
       COUNT(*) AS alinan,
       SUM(CASE WHEN Ict IS NULL THEN 1 ELSE 0 END) AS bugun_aktif,
       SUM(CASE WHEN Ict IS NOT NULL AND Ict < DATEADD(DAY,-1,anchor) THEN 1 ELSE 0 END) AS eylul_oncesi_ayrilan,
       SUM(CASE WHEN Igt <= DATEADD(DAY,-14,anchor) THEN 1 ELSE 0 END) AS risk14,
       SUM(CASE WHEN Igt <= DATEADD(DAY,-14,anchor) AND (Ict IS NULL OR DATEDIFF(DAY,Igt,Ict) >= 14) THEN 1 ELSE 0 END) AS kalan14
FROM k
GROUP BY sube, kohort
ORDER BY sube, kohort;

-- 5) Sube x reyon kirilimi (SEZONLUK, 2025 vs 2026) -- hangi reyon eriyor
SELECT ISNULL(AltLokasyon,'(bos)') AS sube, ISNULL(Departman,'(bos)') AS departman,
       SUM(CASE WHEN YEAR(Igt)=2025 THEN 1 ELSE 0 END) AS a25,
       SUM(CASE WHEN YEAR(Igt)=2025 AND Ict IS NOT NULL AND Ict < '20250901' THEN 1 ELSE 0 END) AS eylul_oncesi25,
       SUM(CASE WHEN YEAR(Igt)=2026 THEN 1 ELSE 0 END) AS a26,
       SUM(CASE WHEN YEAR(Igt)=2026 AND Ict IS NOT NULL THEN 1 ELSE 0 END) AS ayril26
FROM dbo.vw_PersonelDepartman
WHERE Kadro = 'SEZONLUK'
  AND ((Igt >= '20250701' AND Igt < '20250903') OR (Igt >= '20260701' AND Igt < '20260903'))
GROUP BY AltLokasyon, Departman
ORDER BY 1, 5 DESC;

-- 6) Sezon cozulme deseni: ayrilisin Agustos'a gore ay ofseti (0=Agu, 1=Eyl)
--    SEZONLUK: 2024'te 73 ayrilisin 59'u Eylul (%80,8) · 2025'te 82 ayrilisin 56'si (%68,3) = planli tahliye
SELECT YEAR(Igt) AS kohort,
       DATEDIFF(MONTH, CONVERT(datetime, CAST(YEAR(Igt) AS varchar(4)) + '0801', 112), Ict) AS ay_ofset,
       COUNT(*) AS ayrilan
FROM dbo.vw_PersonelDepartman
WHERE Kadro = 'SEZONLUK' AND Ict IS NOT NULL
  AND ((Igt >= '20240701' AND Igt < '20240903')
    OR (Igt >= '20250701' AND Igt < '20250903')
    OR (Igt >= '20260701' AND Igt < '20260903'))
GROUP BY YEAR(Igt), DATEDIFF(MONTH, CONVERT(datetime, CAST(YEAR(Igt) AS varchar(4)) + '0801', 112), Ict)
ORDER BY 1, 2;

-- 7) SGK cikis kodu dagilimi (kod sozlugu Zirve'de YOK -- IK teyidi gerekir, yorumlanmadi)
SELECT ISNULL(IstenCikisKodu,'(bos)') AS cikis_kodu, ISNULL(Kadro,'(NULL)') AS kadro,
       SUM(CASE WHEN YEAR(Igt)=2024 THEN 1 ELSE 0 END) AS k2024,
       SUM(CASE WHEN YEAR(Igt)=2025 THEN 1 ELSE 0 END) AS k2025,
       SUM(CASE WHEN YEAR(Igt)=2026 THEN 1 ELSE 0 END) AS k2026
FROM dbo.vw_PersonelDepartman
WHERE Ict IS NOT NULL
  AND ((Igt >= '20240701' AND Igt < '20240903')
    OR (Igt >= '20250701' AND Igt < '20250903')
    OR (Igt >= '20260701' AND Igt < '20260903'))
GROUP BY IstenCikisKodu, Kadro
ORDER BY 1, 2;

-- 8) Bugunku kadronun bilesimi
SELECT COUNT(*) AS aktif_toplam,
       SUM(CASE WHEN Kadro = 'SEZONLUK' AND Igt >= '20260701' THEN 1 ELSE 0 END) AS sezonluk26,
       SUM(CASE WHEN Kadro = 'SEZONLUK' AND Igt < '20260701' THEN 1 ELSE 0 END) AS sezonluk_eski,
       SUM(CASE WHEN ISNULL(Kadro,'X') <> 'SEZONLUK' THEN 1 ELSE 0 END) AS kadrolu_ve_diger
FROM dbo.vw_PersonelDepartman
WHERE Ict IS NULL;
