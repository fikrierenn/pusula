using Dapper;
using GmDashboard.Models;

namespace GmDashboard.Data;

/// <summary>
/// E-ticaret (JOKER) lojistik performans sorguları — E-ticaret sayfası için.
/// Tarih param = ISO YYYYMMDD (linked server ODAKJOKER). NET filtre: STATUS NOT IN (1001,1006,1007,3000,4000).
/// </summary>
public sealed class EticQueries(Db db)
{
    /// <summary>Kargo performansı: firma × adet × ort. çıkış günü × ort. teslim günü (dönem-duyarlı, sadece teslim olmuş).</summary>
    public async Task<IReadOnlyList<KargoPerf>> GetKargoPerfAsync(DateOnly start, DateOnly endExcl)
    {
        await using var conn = await db.OpenAsync();
        const string sql = """
            SELECT TOP 10 ISNULL(c.CNAME,'(bilinmiyor)') AS Kargo, COUNT(*) AS Adet,
                   CAST(AVG(CAST(DATEDIFF(HOUR,o.ORDERDATE,o.SENDDATE) AS float)/24) AS decimal(10,1)) AS CikisGun,
                   CAST(AVG(CAST(DATEDIFF(HOUR,o.SENDDATE,o.CARGODELIVERYDATE) AS float)/24) AS decimal(10,1)) AS TeslimGun
            FROM ODAKJOKER.JOKER.dbo.J_ORDERS o
            LEFT JOIN ODAKJOKER.JOKER.dbo.J_CARGO c ON c.ID=o.CARGOREF
            WHERE o.ORDERDATE>=@giso AND o.ORDERDATE<@g2iso
              AND o.SENDDATE IS NOT NULL AND o.CARGODELIVERYDATE IS NOT NULL
              AND o.STATUS NOT IN (1001,1006,1007,3000,4000)
            GROUP BY ISNULL(c.CNAME,'(bilinmiyor)') ORDER BY Adet DESC;
            """;
        return (await conn.QueryAsync<KargoPerf>(sql,
            new { giso = start.ToString("yyyyMMdd"), g2iso = endExcl.ToString("yyyyMMdd") })).ToList();
    }

    /// <summary>Günlük kargo çıkış dağılımı: sipariş→kargoya teslim gün farkı (0,1,2…) × paket adedi (dönem, çıkmış siparişler).</summary>
    public async Task<IReadOnlyList<KargoGun>> GetKargoGunAsync(DateOnly start, DateOnly endExcl)
    {
        await using var conn = await db.OpenAsync();
        const string sql = """
            SELECT DATEDIFF(DAY,o.ORDERDATE,o.SENDDATE) AS Gun, COUNT(*) AS Adet
            FROM ODAKJOKER.JOKER.dbo.J_ORDERS o
            WHERE o.ORDERDATE>=@giso AND o.ORDERDATE<@g2iso
              AND o.SENDDATE IS NOT NULL AND o.STATUS NOT IN (1001,1006,1007,3000,4000)
              AND DATEDIFF(DAY,o.ORDERDATE,o.SENDDATE)>=0
            GROUP BY DATEDIFF(DAY,o.ORDERDATE,o.SENDDATE);
            """;
        return (await conn.QueryAsync<KargoGun>(sql,
                new { giso = start.ToString("yyyyMMdd"), g2iso = endExcl.ToString("yyyyMMdd") }))
            .OrderBy(x => x.Gun).ToList();
    }

    /// <summary>İl teslimat performansı (B-41): şehir × adet × ort çıkış/teslim gün. Kargoya çıkış (SENDDATE) dönemi, teslim olmuş (STATUS=1005).</summary>
    public async Task<IReadOnlyList<IlTeslimat>> GetIlTeslimatAsync(DateOnly start, DateOnly endExcl)
    {
        await using var conn = await db.OpenAsync();
        const string sql = """
            SELECT TOP 15 mus.DCITY AS Sehir, COUNT(*) AS Adet,
                   CAST(AVG(CAST(DATEDIFF(HOUR,o.ORDERDATE,o.SENDDATE) AS float)/24) AS decimal(10,1)) AS CikisGun,
                   CAST(AVG(CAST(DATEDIFF(HOUR,o.SENDDATE,o.CARGODELIVERYDATE) AS float)/24) AS decimal(10,1)) AS TeslimGun
            FROM ODAKJOKER.JOKER.dbo.J_ORDERS o
            JOIN ODAKJOKER.JOKER.dbo.J_ORDER_DELIVERY_ADDRESS mus ON mus.LOGICALREF=o.DELIVERYREF
            WHERE o.SENDDATE>=@giso AND o.SENDDATE<@g2iso
              AND o.CARGODELIVERYDATE IS NOT NULL AND o.STATUS=1005 AND mus.DCITY IS NOT NULL
            GROUP BY mus.DCITY ORDER BY Adet DESC;
            """;
        return (await conn.QueryAsync<IlTeslimat>(sql,
            new { giso = start.ToString("yyyyMMdd"), g2iso = endExcl.ToString("yyyyMMdd") })).ToList();
    }

    /// <summary>Bekleyen gün raporu: kargoya çıkmamış (SENDDATE NULL) + normal STATUS siparişlerin yaş dağılımı (anlık, dönemsiz).</summary>
    public async Task<IReadOnlyList<BekleyenBucket>> GetBekleyenAsync()
    {
        await using var conn = await db.OpenAsync();
        const string sql = """
            SELECT CASE WHEN DATEDIFF(DAY,o.ORDERDATE,GETDATE())<=1 THEN '0-1g'
                        WHEN DATEDIFF(DAY,o.ORDERDATE,GETDATE())<=3 THEN '2-3g'
                        WHEN DATEDIFF(DAY,o.ORDERDATE,GETDATE())<=7 THEN '4-7g' ELSE '8+g' END AS Bucket,
                   COUNT(*) AS Adet
            FROM ODAKJOKER.JOKER.dbo.J_ORDERS o
            WHERE o.SENDDATE IS NULL AND o.STATUS NOT IN (1001,1006,1007,3000,4000)
            GROUP BY CASE WHEN DATEDIFF(DAY,o.ORDERDATE,GETDATE())<=1 THEN '0-1g'
                          WHEN DATEDIFF(DAY,o.ORDERDATE,GETDATE())<=3 THEN '2-3g'
                          WHEN DATEDIFF(DAY,o.ORDERDATE,GETDATE())<=7 THEN '4-7g' ELSE '8+g' END;
            """;
        // Sabit sıra (0-1g → 8+g); eksik bucket 0 ile doldurulur
        var raw = (await conn.QueryAsync<BekleyenBucket>(sql)).ToDictionary(b => b.Bucket, b => b.Adet);
        return new[] { "0-1g", "2-3g", "4-7g", "8+g" }
            .Select(k => new BekleyenBucket(k, raw.GetValueOrDefault(k, 0))).ToList();
    }
}
