using Dapper;
using GmDashboard.Models;

namespace GmDashboard.Data;

/// <summary>Sadakat / müşteri tutma sorguları — /sadakat sayfası (Faz 3).</summary>
public sealed class SadakatQueries(Db db)
{
    /// <summary>Win-back listesi — son 365g aktif ama son 90g yok, frekans≥3, ciro≥500. Aksiyon listesi.</summary>
    public async Task<IReadOnlyList<WinBackRow>> GetWinBackAsync()
    {
        await using var conn = await db.OpenAsync();
        var rows = await conn.QueryAsync<WinBackRow>("""
            SELECT TOP 200
                LTRIM(c.Name)        AS Ad,
                c.PhoneNumber        AS Tel,
                c.CardNumber         AS Kart,
                COUNT(s.Id)          AS Frq,
                SUM(CASE WHEN s.DocumentsTypeId=3
                    THEN -(s.GrossTotal-s.DiscountTotal)
                    ELSE   s.GrossTotal-s.DiscountTotal END) AS ToplCiro,
                DATEDIFF(DAY, MAX(s.Date), GETDATE()) AS GunIdle
            FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
            JOIN DerinCrm.dbo.Customer c WITH(NOLOCK) ON c.Id = s.CustomersId
            WHERE s.DocumentsTypeId IN (1,2,3,6,7,8)
              AND s.CustomersId > 0
              AND s.Date >= DATEADD(DAY,-365,CAST(GETDATE() AS date))
              AND s.Date < DATEADD(DAY,-90,CAST(GETDATE() AS date))
            GROUP BY c.Name, c.PhoneNumber, c.CardNumber
            HAVING COUNT(s.Id) >= 3
               AND SUM(CASE WHEN s.DocumentsTypeId=3
                   THEN -(s.GrossTotal-s.DiscountTotal)
                   ELSE   s.GrossTotal-s.DiscountTotal END) >= 500
            ORDER BY ToplCiro DESC
            """, commandTimeout: 30);
        return rows.ToList();
    }

    /// <summary>Pareto dilim tablosu — son 12 ay, 10 dilim (%10'ar), hangisi ne kadar ciro tutuyor.</summary>
    public async Task<IReadOnlyList<ParetoRow>> GetParetoAsync()
    {
        await using var conn = await db.OpenAsync();
        var rows = await conn.QueryAsync<ParetoRow>("""
            SELECT TOP 10
                dilim.dilim   AS Dilim,
                COUNT(*)      AS MusteriSayisi,
                SUM(dilim.Mon) AS ToplamCiro
            FROM (
                SELECT s.CustomersId,
                    SUM(CASE WHEN s.DocumentsTypeId=3
                        THEN -(s.GrossTotal-s.DiscountTotal)
                        ELSE   s.GrossTotal-s.DiscountTotal END) AS Mon,
                    NTILE(10) OVER (ORDER BY
                        SUM(CASE WHEN s.DocumentsTypeId=3
                            THEN -(s.GrossTotal-s.DiscountTotal)
                            ELSE   s.GrossTotal-s.DiscountTotal END) DESC) AS dilim
                FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
                WHERE s.DocumentsTypeId IN (1,2,3,6,7,8) AND s.CustomersId > 0
                  AND s.Date >= DATEADD(MONTH,-12,CAST(GETDATE() AS date))
                GROUP BY s.CustomersId
            ) dilim
            GROUP BY dilim.dilim
            ORDER BY dilim.dilim
            """, commandTimeout: 30);
        return rows.ToList();
    }
}
