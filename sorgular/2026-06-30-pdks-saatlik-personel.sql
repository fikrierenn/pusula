/* ============================================================================
   PDKS SAATLİK ÇALIŞAN PERSONEL — FSM (haftagünü × saat ort.)
   DB        : DerinSISBkm (OPENQUERY([PDKS]) → 192.168.40.66\SQLEXPRESS wtimserv GecoTime)
   Soru      : "O saatte FSM'de kaç personel vardiyada?" — Trafik sayfası uyum haritası kaynağı.
   Bulgu     : Haziran 4 Salı: 16=24·17=23·18=21·19=16·20=13 (yumuşak iniş).
   Tarih     : 2026-06-30 (B-127 PDKS entegrasyonu, TrafikQueries.GetPdksPersonelAsync)

   KABUL EDİLEN MANTIK (3 kural — sema/entities.yaml pdks_saatlik_personel):
   1) VARDİYA ARALIĞI = kişi başı gün içi MIN(giriş) → MAX(son dolu saat).
      Öğle molası segmenti satır kırar (10-13 + 14-18) → segment-bazlı saymak mola
      saatinde SAHTE DÜŞÜŞ üretir. MIN-MAX span mola saatini de "vardiyada" sayar.
   2) ÇIKIŞ SAATİ = dakika>0 ise o saat dahil (18:30→18), tam saatte çıktıysa hariç
      (18:00→17). Giriş floor (10:30→10). Yoksa 18:30 çalışan saat 18'de hiç sayılmaz.
   3) ORTALAMA = SUM(saatteki kişi) / o haftagününün ÇALIŞILAN TOPLAM gün sayısı.
      Boş saat 0 paya girer; sadece-dolu-güne bölmek uç saatleri şişirir.

   NOT: MCP sql_query CTE'yi auto-TOP wrap ile bozar → bu dosya SSMS içindir.
        OPENQUERY tarih literali ISO 'YYYYMMDD' (linked server kuralı).
============================================================================ */

DECLARE @bas char(8) = '20260601';   -- dönem başı (dahil)
DECLARE @bit char(8) = '20260629';   -- dönem sonu (dahil)

WITH nums AS (
    SELECT 0 AS h UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3
    UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7
    UNION ALL SELECT 8 UNION ALL SELECT 9 UNION ALL SELECT 10 UNION ALL SELECT 11
    UNION ALL SELECT 12 UNION ALL SELECT 13 UNION ALL SELECT 14 UNION ALL SELECT 15
    UNION ALL SELECT 16 UNION ALL SELECT 17 UNION ALL SELECT 18 UNION ALL SELECT 19
    UNION ALL SELECT 20 UNION ALL SELECT 21 UNION ALL SELECT 22 UNION ALL SELECT 23
),
seg AS (
    -- GirisH = giriş saati (floor). SonH = son DOLU saat (çıkış dakikası>0 → o saat dahil).
    SELECT TZe_PersNr, TZe_Datum,
           DATEPART(hour, TZe_VonZeit) AS GirisH,
           CASE WHEN DATEPART(minute, TZe_BisZeit) > 0
                THEN DATEPART(hour, TZe_BisZeit)
                ELSE DATEPART(hour, TZe_BisZeit) - 1 END AS SonH
    FROM OPENQUERY([PDKS], '
        SELECT TZe_PersNr, TZe_Datum, TZe_VonZeit, TZe_BisZeit
        FROM TTagZei z
        INNER JOIN TPerTab p ON p.Per_PersNr = z.TZe_PersNr
        WHERE z.TZe_Datum >= ''20260601'' AND z.TZe_Datum <= ''20260629''
          AND p.Per_Grp1 = ''MAĞAZALAR''
          AND LTRIM(RTRIM(p.Per_Grp2)) = ''FSM''
          AND z.TZe_VonZeit IS NOT NULL AND z.TZe_BisZeit IS NOT NULL
    ')
),
span AS (   -- kişi başı gün vardiya aralığı (mola dahil)
    SELECT TZe_PersNr, TZe_Datum,
           MIN(GirisH) AS g, MAX(SonH) AS lastH,
           (DATEPART(weekday, TZe_Datum) + @@DATEFIRST - 2) % 7 AS Gun
    FROM seg
    GROUP BY TZe_PersNr, TZe_Datum, (DATEPART(weekday, TZe_Datum) + @@DATEFIRST - 2) % 7
),
opdays AS (   -- o haftagününün çalışılan toplam gün sayısı (ortalama paydası)
    SELECT Gun, COUNT(DISTINCT TZe_Datum) AS Gunler
    FROM span GROUP BY Gun
),
perDate AS (  -- gün × saat eş-zamanlı kişi
    SELECT s.TZe_Datum, s.Gun, n.h AS Saat,
           COUNT(DISTINCT s.TZe_PersNr) AS Cnt
    FROM span s
    JOIN nums n ON n.h >= s.g AND n.h <= s.lastH
    GROUP BY s.TZe_Datum, s.Gun, n.h
)
SELECT pd.Gun, pd.Saat,
       CAST(ROUND(SUM(CAST(pd.Cnt AS float)) / NULLIF(o.Gunler, 0), 0) AS int) AS Personel
FROM perDate pd
JOIN opdays o ON o.Gun = pd.Gun
GROUP BY pd.Gun, pd.Saat, o.Gunler
ORDER BY pd.Gun, pd.Saat;


/* ############################################################################
   ANALİZ İZİ — Bu mantığa ulaşırken çalıştırılan KEŞİF + TEŞHİS sorguları
   (kronolojik; MCP mcp__sqlserver__sql_query, database=DerinSISBkm).
   Amaç: "nasıl bulduk" tekrar-üretilebilir kalsın (semantic-layer ikiz yükümlülük).
   NOT: MCP wrapper gotcha'ları — ORDER BY top-level YASAK, çok-kolon GROUP BY
        wrap'te patlar, alias'lı literal ('SELECT 9 h') bazen kırılır. Aşağıdaki
        sorgular MCP'de çalışan (CTE'siz, tek-kolon GROUP BY) hallerdir.
############################################################################ */

-- [1] PDKS tabloları DerinSIS'te DEĞİL — iky şeması sadece bordro/puantaj (aylık).
--     Gerçek giriş/çıkış GecoTime'da (linked server [PDKS] → 192.168.40.66\SQLEXPRESS).
SELECT TOP 50 TABLE_SCHEMA, TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_NAME LIKE '%pdks%' OR TABLE_NAME LIKE '%devam%' OR TABLE_NAME LIKE '%mesai%'
   OR TABLE_NAME LIKE '%vardiya%' OR TABLE_NAME LIKE '%persone%';

-- [2] TTagZei yapısı — TZe_VonZeit/BisZeit segment giriş-çıkış (1899-12-30 tarih tabanı, saat anlamlı).
SELECT TOP 3 * FROM OPENQUERY([PDKS], 'SELECT TOP 3 * FROM TTagZei');

-- [3] İLK ÇÖZÜM (gün ort. distinct kişi) — jitter'ı görmeden önceki naif sürüm.
--     Kişi bazında saat detayı YOK → sonra saatlik istendi.
SELECT (DATEPART(weekday, TZe_Datum) + @@DATEFIRST - 2) % 7 AS Gun,
       CAST(AVG(CAST(DailyCount AS float)) AS int) AS AvgPersonel
FROM (
    SELECT TZe_Datum, COUNT(DISTINCT TZe_PersNr) AS DailyCount
    FROM OPENQUERY([PDKS], '
        SELECT TZe_PersNr, TZe_Datum
        FROM TTagZei z INNER JOIN TPerTab p ON p.Per_PersNr = z.TZe_PersNr
        WHERE z.TZe_Datum >= ''20260601'' AND z.TZe_Datum <= ''20260629''
          AND p.Per_Grp1 = ''MAĞAZALAR'' AND LTRIM(RTRIM(p.Per_Grp2)) = ''FSM''
          AND z.TZe_VonZeit IS NOT NULL AND z.TZe_BisZeit IS NOT NULL')
    GROUP BY TZe_Datum
) daily
GROUP BY (DATEPART(weekday, TZe_Datum) + @@DATEFIRST - 2) % 7;

-- [4] TEŞHİS: kişi başı gün içi ÇOK segment var mı? (27.06, FSM)
--     Bulgu: EVET — öğle molası satır kırıyor (10:00-13:00 + 14:00-18:30) →
--     segment-bazlı saat saymak mola saatinde SAHTE DÜŞÜŞ üretir.
SELECT TOP 30 TZe_PersNr, CONVERT(varchar,TZe_Datum,104) AS Tarih,
       CONVERT(varchar(5),TZe_VonZeit,108) AS Giris,
       CONVERT(varchar(5),TZe_BisZeit,108) AS Cikis, TZe_ZeitArt
FROM OPENQUERY([PDKS], '
    SELECT z.TZe_PersNr, z.TZe_Datum, z.TZe_VonZeit, z.TZe_BisZeit, z.TZe_ZeitArt
    FROM TTagZei z INNER JOIN TPerTab p ON p.Per_PersNr = z.TZe_PersNr
    WHERE z.TZe_Datum = ''20260627'' AND p.Per_Grp1 = ''MAĞAZALAR''
      AND LTRIM(RTRIM(p.Per_Grp2)) = ''FSM''
      AND z.TZe_VonZeit IS NOT NULL AND z.TZe_BisZeit IS NOT NULL
    ORDER BY z.TZe_PersNr, z.TZe_VonZeit');

-- [5] ÇÖZÜM DOĞRULAMA: span (MIN giriş–MAX çıkış) tek gün saat eğrisi (27.06 Cmt).
--     Bulgu: 9→27 plato →12 PÜRÜZSÜZ (mola çukuru kayboldu). floor çıkış (h < c).
SELECT TOP 50 n.h AS Saat, COUNT(DISTINCT sp.PersNr) AS SpanIle
FROM (
    SELECT PersNr, MIN(GirisH) AS g, MAX(CikisH) AS c
    FROM (
        SELECT TZe_PersNr AS PersNr,
               DATEPART(hour,TZe_VonZeit) AS GirisH,
               DATEPART(hour,TZe_BisZeit) AS CikisH
        FROM OPENQUERY([PDKS], '
            SELECT z.TZe_PersNr, z.TZe_VonZeit, z.TZe_BisZeit
            FROM TTagZei z INNER JOIN TPerTab p ON p.Per_PersNr = z.TZe_PersNr
            WHERE z.TZe_Datum = ''20260627'' AND p.Per_Grp1 = ''MAĞAZALAR''
              AND LTRIM(RTRIM(p.Per_Grp2)) = ''FSM''
              AND z.TZe_VonZeit IS NOT NULL AND z.TZe_BisZeit IS NOT NULL') s
    ) seg GROUP BY PersNr
) sp
INNER JOIN (SELECT 9 h UNION ALL SELECT 10 UNION ALL SELECT 11 UNION ALL SELECT 12
            UNION ALL SELECT 13 UNION ALL SELECT 14 UNION ALL SELECT 15 UNION ALL SELECT 16
            UNION ALL SELECT 17 UNION ALL SELECT 18 UNION ALL SELECT 19 UNION ALL SELECT 20
            UNION ALL SELECT 21) n ON n.h >= sp.g AND n.h < sp.c
GROUP BY n.h;

-- [6] KULLANICI TEŞHİSİ: "Salı 18'de 21→14 düşüyor doğru mu?" → floor-çıkış BUG'ı.
--     23.06 Salı floor sürüm: 17=21, 18=15 (keskin uçurum — 18:30 çalışan saat 18'de HİÇ sayılmıyor).
SELECT TOP 50 n.h AS Saat, COUNT(DISTINCT sp.PersNr) AS Kisi
FROM (
    SELECT PersNr, MIN(GirisH) AS g, MAX(CikisH) AS c
    FROM (
        SELECT TZe_PersNr AS PersNr,
               DATEPART(hour,TZe_VonZeit) AS GirisH,
               DATEPART(hour,TZe_BisZeit) AS CikisH
        FROM OPENQUERY([PDKS], '
            SELECT z.TZe_PersNr, z.TZe_VonZeit, z.TZe_BisZeit
            FROM TTagZei z INNER JOIN TPerTab p ON p.Per_PersNr = z.TZe_PersNr
            WHERE z.TZe_Datum = ''20260623'' AND p.Per_Grp1 = ''MAĞAZALAR''
              AND LTRIM(RTRIM(p.Per_Grp2)) = ''FSM''
              AND z.TZe_VonZeit IS NOT NULL AND z.TZe_BisZeit IS NOT NULL') s
    ) seg GROUP BY PersNr
) sp
INNER JOIN (SELECT 9 h UNION ALL SELECT 10 UNION ALL SELECT 11 UNION ALL SELECT 12
            UNION ALL SELECT 13 UNION ALL SELECT 14 UNION ALL SELECT 15 UNION ALL SELECT 16
            UNION ALL SELECT 17 UNION ALL SELECT 18 UNION ALL SELECT 19 UNION ALL SELECT 20
            UNION ALL SELECT 21) n ON n.h >= sp.g AND n.h < sp.c
GROUP BY n.h;

-- [7] DÜZELTME DOĞRULAMA: çıkış dakikası>0 → o saat dahil (SonH). 23.06 Salı.
--     Bulgu: 17=23, 18=20, 19=15 — keskin uçurum gitti, gerçekçi iniş. (n.h <= lastH)
SELECT TOP 50 n.h AS Saat, COUNT(DISTINCT sp.PersNr) AS Kisi
FROM (
    SELECT PersNr, MIN(GirisH) AS g, MAX(SonH) AS lastH
    FROM (
        SELECT TZe_PersNr AS PersNr,
               DATEPART(hour,TZe_VonZeit) AS GirisH,
               CASE WHEN DATEPART(minute,TZe_BisZeit) > 0
                    THEN DATEPART(hour,TZe_BisZeit)
                    ELSE DATEPART(hour,TZe_BisZeit) - 1 END AS SonH
        FROM OPENQUERY([PDKS], '
            SELECT z.TZe_PersNr, z.TZe_VonZeit, z.TZe_BisZeit
            FROM TTagZei z INNER JOIN TPerTab p ON p.Per_PersNr = z.TZe_PersNr
            WHERE z.TZe_Datum = ''20260623'' AND p.Per_Grp1 = ''MAĞAZALAR''
              AND LTRIM(RTRIM(p.Per_Grp2)) = ''FSM''
              AND z.TZe_VonZeit IS NOT NULL AND z.TZe_BisZeit IS NOT NULL') s
    ) seg GROUP BY PersNr
) sp
INNER JOIN (SELECT 9 h UNION ALL SELECT 10 UNION ALL SELECT 11 UNION ALL SELECT 12
            UNION ALL SELECT 13 UNION ALL SELECT 14 UNION ALL SELECT 15 UNION ALL SELECT 16
            UNION ALL SELECT 17 UNION ALL SELECT 18 UNION ALL SELECT 19 UNION ALL SELECT 20
            UNION ALL SELECT 21) n ON n.h >= sp.g AND n.h <= sp.lastH
GROUP BY n.h;

-- [8] ORTALAMA DOĞRULAMA: 4 Salı toplam/gün (payda = çalışılan gün = 4).
--     16=95/4=24 · 17=93/4=23 · 18=85/4=21 · 19=62/4=16 · 20=50/4=13. Yumuşak.
SELECT TOP 50 n.h AS Saat,
       COUNT(DISTINCT CAST(sp.Tarih AS varchar)+'_'+CAST(sp.PersNr AS varchar)) AS ToplamKisiGun,
       COUNT(DISTINCT sp.Tarih) AS GunSayisi
FROM (
    SELECT PersNr, Tarih, MIN(GirisH) AS g, MAX(SonH) AS lastH
    FROM (
        SELECT TZe_PersNr AS PersNr, TZe_Datum AS Tarih,
               DATEPART(hour,TZe_VonZeit) AS GirisH,
               CASE WHEN DATEPART(minute,TZe_BisZeit) > 0
                    THEN DATEPART(hour,TZe_BisZeit)
                    ELSE DATEPART(hour,TZe_BisZeit) - 1 END AS SonH
        FROM OPENQUERY([PDKS], '
            SELECT z.TZe_PersNr, z.TZe_Datum, z.TZe_VonZeit, z.TZe_BisZeit
            FROM TTagZei z INNER JOIN TPerTab p ON p.Per_PersNr = z.TZe_PersNr
            WHERE z.TZe_Datum >= ''20260601'' AND z.TZe_Datum <= ''20260629''
              AND p.Per_Grp1 = ''MAĞAZALAR'' AND LTRIM(RTRIM(p.Per_Grp2)) = ''FSM''
              AND z.TZe_VonZeit IS NOT NULL AND z.TZe_BisZeit IS NOT NULL') s
        WHERE (DATEPART(weekday,TZe_Datum) + @@DATEFIRST - 2) % 7 = 1   -- Salı
    ) seg GROUP BY PersNr, Tarih
) sp
INNER JOIN (SELECT 16 h UNION ALL SELECT 17 UNION ALL SELECT 18 UNION ALL SELECT 19
            UNION ALL SELECT 20) n ON n.h >= sp.g AND n.h <= sp.lastH
GROUP BY n.h;
