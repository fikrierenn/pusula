using Dapper;
using GmDashboard.Models;

namespace GmDashboard.Data;

/// <summary>
/// Referans paneller (envanter + müşteri). Aylık/365g sabit pencere. SQL Python gm_dashboard.py'den port.
/// </summary>
public sealed class RefQueries(Db db)
{
    /// <summary>RFM müşteri segmenti — yazarkasa (365g) + e-ticaret. dun = referans gün.</summary>
    public async Task<(IReadOnlyList<RfmSegment> Yazarkasa, IReadOnlyList<RfmSegment> Eticaret)> GetRfmAsync(DateOnly dun)
    {
        await using var conn = await db.OpenAsync();
        var dunDt = dun.ToDateTime(TimeOnly.MinValue);
        var g2Dt = dun.AddDays(1).ToDateTime(TimeOnly.MinValue);

        // Yazarkasa (EncoreMerkez Sales, CustomersId)
        const string ykSql = """
            SELECT seg.S AS Segment, COUNT(*) AS Musteri, SUM(c.Mon) AS Ciro
            FROM (SELECT s.CustomersId, DATEDIFF(DAY,MAX(s.Date),@dun) Rec, COUNT(*) Frq, SUM(s.GrossTotal-s.DiscountTotal) Mon
                  FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
                  WHERE s.DocumentsTypeId=1 AND s.CustomersId>0 AND s.Date>=DATEADD(DAY,-365,@dun) AND s.Date<@g2
                  GROUP BY s.CustomersId) c
            CROSS APPLY (SELECT CAST(CASE WHEN Frq>=8 AND Rec<=30 THEN N'1-Şampiyon' WHEN Frq>=4 AND Rec<=90 THEN N'2-Sadık'
                         WHEN Frq<=2 AND Rec<=30 THEN N'3-Yeni' WHEN Rec BETWEEN 91 AND 180 THEN N'4-Risk'
                         WHEN Rec>180 THEN N'5-Kayıp' ELSE N'6-Diğer' END AS nvarchar(20)) S) seg
            GROUP BY seg.S;
            """;
        var yk = (await conn.QueryAsync<RfmSegment>(ykSql, new { dun = dunDt, g2 = g2Dt }))
            .OrderBy(r => r.Segment).ToList();

        // E-ticaret (JOKER, CUSTOMERREF) — ISO tarih
        const string etSql = """
            SELECT seg.S AS Segment, COUNT(*) AS Musteri, SUM(c.Mon) AS Ciro
            FROM (SELECT oc.CUSTOMERREF, DATEDIFF(DAY,MAX(o.ORDERDATE),@dun) Rec, COUNT(*) Frq, SUM(o.TOTALPRICE) Mon
                  FROM ODAKJOKER.JOKER.dbo.J_ORDERS o
                  JOIN ODAKJOKER.JOKER.dbo.J_ORDER_CLIENTS oc ON oc.LOGICALREF=o.CLIENTREF
                  WHERE o.ORDERDATE>=@bas AND o.ORDERDATE<@g2 AND oc.CUSTOMERREF>0
                  GROUP BY oc.CUSTOMERREF) c
            CROSS APPLY (SELECT CAST(CASE WHEN Frq>=5 AND Rec<=30 THEN N'1-Şampiyon' WHEN Frq>=3 AND Rec<=90 THEN N'2-Sadık'
                         WHEN Frq<=2 AND Rec<=30 THEN N'3-Yeni' WHEN Rec BETWEEN 91 AND 180 THEN N'4-Risk'
                         WHEN Rec>180 THEN N'5-Kayıp' ELSE N'6-Diğer' END AS nvarchar(20)) S) seg
            GROUP BY seg.S;
            """;
        var et = (await conn.QueryAsync<RfmSegment>(etSql,
            new { dun = dun.ToString("yyyyMMdd"), bas = dun.AddDays(-365).ToString("yyyyMMdd"), g2 = dun.AddDays(1).ToString("yyyyMMdd") }))
            .OrderBy(r => r.Segment).ToList();

        return (yk, et);
    }
}
