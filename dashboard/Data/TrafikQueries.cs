using Dapper;
using GmDashboard.Models;

namespace GmDashboard.Data;

/// <summary>
/// FSM trafik + kasiyer analizi (B-127). Kapı sayacı (bkm.MusteriSayi) × POS fiş (EncoreMerkez.Sales).
/// FSM: MusteriSayi.MekanId=1, Sales → posMagaza.mekanID=1. SALT-OKUMA. 3-parçalı isim ZORUNLU (app master katalog).
/// Geri dönüşüm fişi (BarcodeNo='1001') hariç — Queries.cs storeSql deseni.
/// </summary>
public sealed class TrafikQueries(Db db)
{
    // FSM = posMagaza.mekanID=1. StoresId doğrudan filtrelemek yerine canonical join kullanılır (Queries.cs deseni).
    const string FsmJoin = """
        JOIN EncoreMerkez.dbo.Pos p ON p.Id=s.PosId
        JOIN EncoreMerkez.dbo.Stores st ON st.Id=p.StoreId
        JOIN DerinSISBkm.dbo.posMagaza MG ON MG.mekanKod COLLATE Turkish_CI_AS = st.Code COLLATE Turkish_CI_AS
        LEFT JOIN EncoreMerkez.dbo.SalesProducts spb ON spb.SalesId=s.Id AND spb.BarcodeNo='1001'
        """;

    const string FsmWhere = "MG.mekanID = 1 AND spb.Id IS NULL AND s.DocumentsTypeId IN (1,2,3,6,7,8)";

    /// <summary>Dönem KPI: toplam ziyaretçi (kapı) + fiş + KDV-hariç net + aktif personel sayısı.</summary>
    public async Task<TrafikKpi> GetKpiAsync(DateOnly bas, DateOnly bit)
    {
        await using var conn = await db.OpenAsync();
        return await conn.QuerySingleAsync<TrafikKpi>($"""
            SELECT
                (SELECT ISNULL(SUM(MusteriSayi), 0)
                 FROM DerinSISBkm.bkm.MusteriSayi
                 WHERE MekanId = 1 AND Tarih >= @bas AND Tarih < @bit) AS Ziyaretci,
                COUNT(*) AS Fis,
                CAST(SUM(CASE WHEN s.DocumentsTypeId=3 THEN -1 ELSE 1 END
                         * (s.GrossTotal-s.DiscountTotal-s.VatTotal)) AS decimal(18,0)) AS Net,
                COUNT(DISTINCT s.UsersId) AS Kasiyer
            FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
            {FsmJoin}
            WHERE {FsmWhere} AND s.Date >= @bas AND s.Date < @bit
            """, new { bas, bit });
    }

    /// <summary>Heatmap: gün×saat ortalama (Ziyaretci / Fis / Kasiyer). İki ayrı connection — MARS yok (paralel sorgu aynı conn = hata).</summary>
    public async Task<IReadOnlyList<TrafikHeat>> GetHeatAsync(DateOnly bas, DateOnly bit)
    {
        await using var connZ = await db.OpenAsync();
        await using var connF = await db.OpenAsync();

        var zTask = connZ.QueryAsync<(int Gun, int Saat, int Val)>("""
            SELECT
                (DATEPART(weekday, CONVERT(date, Tarih)) + @@DATEFIRST - 2) % 7 AS Gun,
                DATEPART(hour, Tarih) AS Saat,
                CAST(AVG(CAST(MusteriSayi AS float)) AS int) AS Val
            FROM DerinSISBkm.bkm.MusteriSayi
            WHERE MekanId = 1 AND Tarih >= @bas AND Tarih < @bit
            GROUP BY
                (DATEPART(weekday, CONVERT(date, Tarih)) + @@DATEFIRST - 2) % 7,
                DATEPART(hour, Tarih)
            """, new { bas, bit });

        var fTask = connF.QueryAsync<(int Gun, int Saat, int Fis, int Kasiyer)>($"""
            SELECT
                Gun,
                Saat,
                CAST(AVG(CAST(DailyFis AS float)) AS int) AS Fis,
                CAST(AVG(CAST(DailyK   AS float)) AS int) AS Kasiyer
            FROM (
                SELECT
                    CONVERT(date, s.Date) AS Tarih,
                    (DATEPART(weekday, CONVERT(date, s.Date)) + @@DATEFIRST - 2) % 7 AS Gun,
                    DATEPART(hour, s.Date) AS Saat,
                    COUNT(*) AS DailyFis,
                    COUNT(DISTINCT s.UsersId) AS DailyK
                FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
                {FsmJoin}
                WHERE {FsmWhere} AND s.Date >= @bas AND s.Date < @bit
                GROUP BY
                    CONVERT(date, s.Date),
                    (DATEPART(weekday, CONVERT(date, s.Date)) + @@DATEFIRST - 2) % 7,
                    DATEPART(hour, s.Date)
            ) daily
            GROUP BY Gun, Saat
            """, new { bas, bit });

        await Task.WhenAll(zTask, fTask);

        var zMap = (await zTask).ToDictionary(r => (r.Gun, r.Saat), r => r.Val);
        var fMap = (await fTask).ToDictionary(r => (r.Gun, r.Saat), r => (r.Fis, r.Kasiyer));

        var keys = zMap.Keys.Union(fMap.Keys).OrderBy(k => k.Gun).ThenBy(k => k.Saat);
        return keys.Select(k =>
        {
            var fk = fMap.GetValueOrDefault(k);
            return new TrafikHeat(k.Gun, k.Saat, zMap.GetValueOrDefault(k), fk.Fis, fk.Kasiyer);
        }).ToList();
    }

    /// <summary>PDKS saatlik ort. çalışan (FSM). Her (Gun,Saat) için o saatte vardiyada olan personel, gün ortalaması.
    /// VARDİYA ARALIĞI = kişi başı gün içi MIN giriş–MAX çıkış (öğle molası satır kırmasını yutar — yoksa mola saatinde
    /// sahte düşüş olur). ORTALAMA paydası = o haftagününün çalışılan TOPLAM gün sayısı (boş saat 0 sayılır, uç saat şişmez).
    /// OPENQUERY([PDKS]) TTagZei×TPerTab. Tarihler OPENQUERY içine gömülür — DateOnly kaynağı, injection riski yok.</summary>
    public async Task<IReadOnlyList<TrafikPdksHeat>> GetPdksPersonelAsync(DateOnly bas, DateOnly bit)
    {
        var bas8 = bas.ToString("yyyyMMdd");
        var bit8 = bit.AddDays(-1).ToString("yyyyMMdd"); // bit exclusive
        var sql = $"""
            WITH nums AS (
                SELECT 0 AS h UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3
                UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7
                UNION ALL SELECT 8 UNION ALL SELECT 9 UNION ALL SELECT 10 UNION ALL SELECT 11
                UNION ALL SELECT 12 UNION ALL SELECT 13 UNION ALL SELECT 14 UNION ALL SELECT 15
                UNION ALL SELECT 16 UNION ALL SELECT 17 UNION ALL SELECT 18 UNION ALL SELECT 19
                UNION ALL SELECT 20 UNION ALL SELECT 21 UNION ALL SELECT 22 UNION ALL SELECT 23
            ),
            seg AS (
                -- GirisH = giriş saati (floor). SonH = son DOLU saat: çıkış dakikası>0 ise o saat dahil,
                -- tam saatte çıktıysa (18:00) o saat hariç. Yoksa 18:30 çalışanı saat 18'de hiç saymazdık (sahte uçurum).
                SELECT TZe_PersNr, TZe_Datum,
                       DATEPART(hour, TZe_VonZeit) AS GirisH,
                       CASE WHEN DATEPART(minute, TZe_BisZeit) > 0
                            THEN DATEPART(hour, TZe_BisZeit)
                            ELSE DATEPART(hour, TZe_BisZeit) - 1 END AS SonH
                FROM OPENQUERY([PDKS], '
                    SELECT TZe_PersNr, TZe_Datum, TZe_VonZeit, TZe_BisZeit
                    FROM TTagZei z
                    INNER JOIN TPerTab p ON p.Per_PersNr = z.TZe_PersNr
                    WHERE z.TZe_Datum >= ''{bas8}'' AND z.TZe_Datum <= ''{bit8}''
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
                SELECT Gun, COUNT(DISTINCT TZe_Datum) AS Gunler
                FROM span
                GROUP BY Gun
            ),
            perDate AS (
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
            """;
        await using var conn = await db.OpenAsync();
        return (await conn.QueryAsync<TrafikPdksHeat>(sql)).ToList();
    }

    /// <summary>Satış personeli dönem performansı (fiş bazlı, FSM, isim: EncoreMerkez.dbo.Users.Name).</summary>
    public async Task<IReadOnlyList<TrafikPersonel>> GetPersonelAsync(DateOnly bas, DateOnly bit)
    {
        await using var conn = await db.OpenAsync();
        return (await conn.QueryAsync<(string Ad, int Fis, decimal Net, int CalistigiGun, int IlkSaat, int SonSaat)>($"""
            SELECT
                CAST(ISNULL(u.Name, '?') AS nvarchar(40)) AS Ad,
                COUNT(*) AS Fis,
                CAST(SUM(CASE WHEN s.DocumentsTypeId=3 THEN -1 ELSE 1 END
                         * (s.GrossTotal-s.DiscountTotal-s.VatTotal)) AS decimal(18,0)) AS Net,
                COUNT(DISTINCT CONVERT(date, s.Date)) AS CalistigiGun,
                MIN(DATEPART(hour, s.Date)) AS IlkSaat,
                MAX(DATEPART(hour, s.Date)) AS SonSaat
            FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
            {FsmJoin}
            LEFT JOIN EncoreMerkez.dbo.Users u ON u.Id = s.UsersId
            WHERE {FsmWhere} AND s.Date >= @bas AND s.Date < @bit
            GROUP BY s.UsersId, CAST(ISNULL(u.Name, '?') AS nvarchar(40))
            ORDER BY COUNT(*) DESC
            """, new { bas, bit }))
            .Select(r => new TrafikPersonel(r.Ad, r.Fis, r.Net,
                r.Fis > 0 ? (int)(r.Net / r.Fis) : 0, r.CalistigiGun, r.IlkSaat, r.SonSaat))
            .ToList();
    }

    /// <summary>Gün-gün detay (eski sayiyo-rapor.xlsx karşılığı) — kapı sayacı × POS fiş/ciro, günlük. Dönüşüm/Sepet UI'da hesaplanır.</summary>
    public async Task<IReadOnlyList<TrafikGunluk>> GetGunlukAsync(DateOnly bas, DateOnly bit)
    {
        await using var conn = await db.OpenAsync();
        return (await conn.QueryAsync<TrafikGunluk>($"""
            ;WITH G AS (
                SELECT CAST(Tarih AS date) AS T, SUM(MusteriSayi) AS Giris
                FROM DerinSISBkm.bkm.MusteriSayi
                WHERE MekanId = 1 AND Tarih >= @bas AND Tarih < @bit
                GROUP BY CAST(Tarih AS date)
            ), F AS (
                SELECT CAST(s.Date AS date) AS T,
                    SUM(CASE WHEN s.DocumentsTypeId=3 THEN -1 ELSE 1 END) AS Fis,
                    CAST(SUM(CASE WHEN s.DocumentsTypeId=3 THEN -1 ELSE 1 END
                             * (s.GrossTotal-s.DiscountTotal-s.VatTotal)) AS decimal(18,0)) AS Ciro
                FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
                {FsmJoin}
                WHERE {FsmWhere} AND s.Date >= @bas AND s.Date < @bit
                GROUP BY CAST(s.Date AS date)
            )
            SELECT G.T AS Tarih, G.Giris, ISNULL(F.Fis, 0) AS Fis, ISNULL(F.Ciro, 0) AS Ciro
            FROM G LEFT JOIN F ON F.T = G.T
            ORDER BY G.T
            """, new { bas, bit })).ToList();
    }
}
