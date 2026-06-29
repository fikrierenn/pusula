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

    /// <summary>Heatmap: gün×saat ortalama (Ziyaretci / Fis / Kasiyer). Ziyaretçi + fiş ayrı sorgu, C#'da (gun,saat) birleştir.</summary>
    public async Task<IReadOnlyList<TrafikHeat>> GetHeatAsync(DateOnly bas, DateOnly bit)
    {
        await using var conn = await db.OpenAsync();

        var zTask = conn.QueryAsync<(int Gun, int Saat, int Val)>("""
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

        var fTask = conn.QueryAsync<(int Gun, int Saat, int Fis, int Kasiyer)>($"""
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
}
