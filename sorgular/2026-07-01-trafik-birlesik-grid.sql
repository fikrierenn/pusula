/* ============================================================================
   TRAFİK BİRLEŞİK GRID — Gün × Saat: Ziyaretçi / Fiş / Kasiyer / Personel / Ziy/Personel
   (Dashboard /trafik "Veri tablosu" modalının TEK-SORGU hali — SSMS)
   DB     : master bağlamı (3-parçalı isim). 3 kaynak:
            • Ziyaretçi = DerinSISBkm.bkm.MusteriSayi (kapı sayacı, MekanId=1 FSM)
            • Fiş/Kasiyer = EncoreMerkez.dbo.Sales (POS, FSM canonical join, geri dönüşüm hariç)
            • Personel = OPENQUERY([PDKS]) TTagZei×TPerTab (fiili kart giriş-çıkış, span mantığı)
   Grain  : haftagünü (0=Pzt..6=Paz) × saat(0-23). Değerler DÖNEM ORTALAMASI.
   Tarih  : 2026-07-01. Dönem Haziran 2026 (değiştir: @bas/@bit + OPENQUERY iç ISO literal İKİSİ birden).
   NOT    : CTE'li → SSMS. MCP sql_query CTE'yi auto-TOP wrap ile bozar.
            OPENQUERY tarih literali ISO 'YYYYMMDD'; dış sorgu date (yerel).
   PDKS mantığı (sema pdks_saatlik_personel): span=MIN(giriş)–MAX(son dolu saat);
            çıkış dakika>0 → o saat dahil; ortalama paydası = haftagünü çalışılan gün sayısı.
============================================================================ */

DECLARE @bas date = '2026-06-01';   -- dönem başı (dahil)
DECLARE @bit date = '2026-06-29';   -- dönem sonu (HARİÇ — < @bit)

WITH
-- ---- 1) ZİYARETÇİ (kapı sayacı) ----
zi AS (
    SELECT (DATEPART(weekday, Tarih) + @@DATEFIRST - 2) % 7 AS Gun,
           DATEPART(hour, Tarih) AS Saat,
           CAST(AVG(CAST(MusteriSayi AS float)) AS int) AS Ziyaretci
    FROM DerinSISBkm.bkm.MusteriSayi
    WHERE MekanId = 1 AND Tarih >= @bas AND Tarih < @bit
    GROUP BY (DATEPART(weekday, Tarih) + @@DATEFIRST - 2) % 7, DATEPART(hour, Tarih)
),
-- ---- 2) FİŞ + KASİYER (POS, FSM) ---- gün bazında say → gün ortalaması
fk_daily AS (
    SELECT CONVERT(date, s.Date) AS Tarih,
           (DATEPART(weekday, CONVERT(date, s.Date)) + @@DATEFIRST - 2) % 7 AS Gun,
           DATEPART(hour, s.Date) AS Saat,
           COUNT(*) AS DailyFis,
           COUNT(DISTINCT s.UsersId) AS DailyK
    FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
    JOIN EncoreMerkez.dbo.Pos p WITH(NOLOCK) ON p.Id = s.PosId
    JOIN EncoreMerkez.dbo.Stores st WITH(NOLOCK) ON st.Id = p.StoreId
    JOIN DerinSISBkm.dbo.posMagaza MG WITH(NOLOCK)
         ON MG.mekanKod COLLATE Turkish_CI_AS = st.Code COLLATE Turkish_CI_AS
    LEFT JOIN EncoreMerkez.dbo.SalesProducts spb WITH(NOLOCK)
         ON spb.SalesId = s.Id AND spb.BarcodeNo = '1001'   -- geri dönüşüm fişi hariç
    WHERE MG.mekanID = 1 AND spb.Id IS NULL
      AND s.DocumentsTypeId IN (1,2,3,6,7,8)
      AND s.Date >= @bas AND s.Date < @bit
    GROUP BY CONVERT(date, s.Date),
             (DATEPART(weekday, CONVERT(date, s.Date)) + @@DATEFIRST - 2) % 7,
             DATEPART(hour, s.Date)
),
fk AS (
    SELECT Gun, Saat,
           CAST(AVG(CAST(DailyFis AS float)) AS int) AS Fis,
           CAST(AVG(CAST(DailyK   AS float)) AS int) AS Kasiyer
    FROM fk_daily
    GROUP BY Gun, Saat
),
-- ---- 3) PERSONEL (PDKS fiili kart, span mantığı) ----
nums AS (
    SELECT 0 AS h UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3
    UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7
    UNION ALL SELECT 8 UNION ALL SELECT 9 UNION ALL SELECT 10 UNION ALL SELECT 11
    UNION ALL SELECT 12 UNION ALL SELECT 13 UNION ALL SELECT 14 UNION ALL SELECT 15
    UNION ALL SELECT 16 UNION ALL SELECT 17 UNION ALL SELECT 18 UNION ALL SELECT 19
    UNION ALL SELECT 20 UNION ALL SELECT 21 UNION ALL SELECT 22 UNION ALL SELECT 23
),
seg AS (
    SELECT TZe_PersNr, TZe_Datum,
           DATEPART(hour, TZe_VonZeit) AS GirisH,
           CASE WHEN DATEPART(minute, TZe_BisZeit) > 0
                THEN DATEPART(hour, TZe_BisZeit)
                ELSE DATEPART(hour, TZe_BisZeit) - 1 END AS SonH
    FROM OPENQUERY([PDKS], '
        SELECT TZe_PersNr, TZe_Datum, TZe_VonZeit, TZe_BisZeit
        FROM TTagZei z
        INNER JOIN TPerTab p ON p.Per_PersNr = z.TZe_PersNr
        WHERE z.TZe_Datum >= ''20260601'' AND z.TZe_Datum <= ''20260628''
          AND p.Per_Grp1 = ''MAĞAZALAR''
          AND LTRIM(RTRIM(p.Per_Grp2)) = ''FSM''
          AND z.TZe_VonZeit IS NOT NULL AND z.TZe_BisZeit IS NOT NULL
    ')
),
span AS (
    SELECT TZe_PersNr, TZe_Datum,
           MIN(GirisH) AS g, MAX(SonH) AS lastH,
           (DATEPART(weekday, TZe_Datum) + @@DATEFIRST - 2) % 7 AS Gun
    FROM seg
    GROUP BY TZe_PersNr, TZe_Datum, (DATEPART(weekday, TZe_Datum) + @@DATEFIRST - 2) % 7
),
opdays AS (
    SELECT Gun, COUNT(DISTINCT TZe_Datum) AS Gunler FROM span GROUP BY Gun
),
perDate AS (
    SELECT s.TZe_Datum, s.Gun, n.h AS Saat, COUNT(DISTINCT s.TZe_PersNr) AS Cnt
    FROM span s
    JOIN nums n ON n.h >= s.g AND n.h <= s.lastH
    GROUP BY s.TZe_Datum, s.Gun, n.h
),
pe AS (
    SELECT pd.Gun, pd.Saat,
           CAST(ROUND(SUM(CAST(pd.Cnt AS float)) / NULLIF(o.Gunler, 0), 0) AS int) AS Personel
    FROM perDate pd
    JOIN opdays o ON o.Gun = pd.Gun
    GROUP BY pd.Gun, pd.Saat, o.Gunler
),
-- ---- Grid anahtarları (üç kaynağın tüm gün×saat birleşimi) ----
anahtar AS (
    SELECT Gun, Saat FROM zi
    UNION SELECT Gun, Saat FROM fk
    UNION SELECT Gun, Saat FROM pe
)
SELECT
    k.Gun,
    RIGHT('0' + CAST(k.Saat AS varchar(2)), 2) + ':00' AS Saat,
    ISNULL(zi.Ziyaretci, 0) AS Ziyaretci,
    ISNULL(fk.Fis, 0)       AS Fis,
    ISNULL(fk.Kasiyer, 0)   AS Kasiyer,
    ISNULL(pe.Personel, 0)  AS Personel,
    CASE WHEN ISNULL(pe.Personel, 0) > 0
         THEN ISNULL(zi.Ziyaretci, 0) / pe.Personel END AS [Ziy/Personel]
FROM anahtar k
LEFT JOIN zi ON zi.Gun = k.Gun AND zi.Saat = k.Saat
LEFT JOIN fk ON fk.Gun = k.Gun AND fk.Saat = k.Saat
LEFT JOIN pe ON pe.Gun = k.Gun AND pe.Saat = k.Saat
ORDER BY k.Gun, k.Saat;
