using Dapper;
using GmDashboard.Models;

namespace GmDashboard.Data;

/// <summary>
/// Tüm dashboard sorguları. SQL Python gm_dashboard.py'den birebir port (sema/sql-server-conventions).
/// Tarih param = DMY (SET DATEFORMAT dmy bağlantıda). E-ticaret ISO YYYYMMDD (linked server).
/// </summary>
public sealed class Queries(Db db)
{
    static readonly Dictionary<int, string> Mekan = new() { [1] = "FSM", [4477] = "Özlüce", [4478] = "İst.Yolu" };

    /// <summary>Dönem özeti: mağaza net/fiş/iade + e-ticaret net + hedef gerçekleşme.</summary>
    public async Task<PeriodSummary> GetPeriodAsync(DateOnly start, DateOnly endExcl)
    {
        await using var conn = await db.OpenAsync();
        var giso = start.ToString("yyyyMMdd");
        var g2iso = endExcl.ToString("yyyyMMdd");

        // Mağaza (EncoreMerkez Sales → posMagaza; geri dönüşüm fişi BarcodeNo='1001' hariç)
        const string storeSql = """
            SELECT MG.mekanID AS MekanId,
                   SUM(IIF(s.DocumentsTypeId=3,-1,1)*(s.GrossTotal-s.DiscountTotal)) AS Net,
                   SUM(IIF(s.DocumentsTypeId=3,-1,1)) AS Fis,
                   SUM(IIF(s.DocumentsTypeId=3,s.GrossTotal,0)) AS Iade
            FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
            JOIN EncoreMerkez.dbo.Pos p ON p.Id=s.PosId
            JOIN EncoreMerkez.dbo.Stores st ON st.Id=p.StoreId
            JOIN DerinSISBkm.dbo.posMagaza MG ON MG.mekanKod COLLATE Turkish_CI_AS = st.Code COLLATE Turkish_CI_AS
            LEFT JOIN EncoreMerkez.dbo.SalesProducts spb ON spb.SalesId=s.Id AND spb.BarcodeNo='1001'
            WHERE s.DocumentsTypeId IN (1,2,3,6,7,8) AND spb.Id IS NULL AND s.Date>=@start AND s.Date<@end
            GROUP BY MG.mekanID;
            """;
        var stores = (await conn.QueryAsync<StoreRow>(storeSql,
            new { start = start.ToDateTime(TimeOnly.MinValue), end = endExcl.ToDateTime(TimeOnly.MinValue) })).ToList();

        // E-ticaret NET (iptal 1006 + iade 3004/3006 hariç) — JOKER linked server, ISO tarih
        const string eticSql = """
            SELECT SUM(CASE WHEN o.STATUS NOT IN (1006,3004,3006) THEN 1 ELSE 0 END) AS Sip,
                   SUM(CASE WHEN o.STATUS NOT IN (1006,3004,3006) THEN o.TOTALPRICE ELSE 0 END) AS Ciro
            FROM ODAKJOKER.JOKER.dbo.J_ORDERS o
            WHERE o.ORDERDATE>=@giso AND o.ORDERDATE<@g2iso;
            """;
        var etic = await conn.QuerySingleOrDefaultAsync<(int? Sip, decimal? Ciro)>(eticSql, new { giso, g2iso });
        var eSip = etic.Sip ?? 0;
        var eCiro = etic.Ciro ?? 0m;

        // Hedef (MTD) — sadece aylık dönemde dolu; ay başı–bugün
        var ayBas = new DateOnly(start.Year, start.Month, 1);
        const string hedefSql = "SELECT mekanId, SUM(hedef) H FROM BKMDATA.dbo.Hedef WITH(NOLOCK) WHERE mekanId IN (1,4477,4478) AND tarih>=@a AND tarih<@b GROUP BY mekanId;";
        var hedef = (await conn.QueryAsync<(int mekanId, decimal H)>(hedefSql,
            new { a = ayBas.ToDateTime(TimeOnly.MinValue), b = endExcl.ToDateTime(TimeOnly.MinValue) }))
            .ToDictionary(x => x.mekanId, x => x.H);

        var cards = new List<StoreCard>();
        foreach (var mid in new[] { 4477, 1, 4478 })
        {
            var r = stores.FirstOrDefault(s => s.MekanId == mid);
            var net = r?.Net ?? 0;
            var fis = r?.Fis ?? 0;
            decimal? ger = hedef.TryGetValue(mid, out var h) && h > 0 ? Math.Round(100 * net / h, 1) : null;
            cards.Add(new StoreCard(mid, Mekan[mid], net, fis, fis > 0 ? (int)Math.Round(net / fis) : 0, ger, r?.Iade ?? 0));
        }

        var fiz = stores.Sum(s => s.Net);
        var fisTop = stores.Sum(s => s.Fis);
        var iadeTop = stores.Sum(s => s.Iade);
        return new PeriodSummary(fiz, fisTop, iadeTop, eCiro, eSip, fiz + eCiro, cards);
    }
}
