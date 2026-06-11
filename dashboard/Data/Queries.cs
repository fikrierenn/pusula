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

        // E-ticaret NET (iptal 1001/3000/4000 + iade 1006 + kayıp 1007 HARİÇ; 3004/3006 NORMAL aşama) — JOKER, ISO tarih
        const string eticSql = """
            SELECT SUM(CASE WHEN o.STATUS NOT IN (1001,1006,1007,3000,4000) THEN 1 ELSE 0 END) AS Sip,
                   SUM(CASE WHEN o.STATUS NOT IN (1001,1006,1007,3000,4000) THEN o.TOTALPRICE ELSE 0 END) AS Ciro
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

        // Mağaza × kategori (drill — mağaza kartı tıkla → kategori dağılımı)
        var katPar = new { start = start.ToDateTime(TimeOnly.MinValue), end = endExcl.ToDateTime(TimeOnly.MinValue) };
        const string skatSql = """
            SELECT MG.mekanID AS MekanId, CAST(ktg.ktgrAd AS nvarchar(50)) AS Ad,
                   CAST(SUM(IIF(s.DocumentsTypeId=3,-1,1)*sp.TotalPrice) AS decimal(18,0)) AS Ciro
            FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
            JOIN EncoreMerkez.dbo.Pos p ON p.Id=s.PosId JOIN EncoreMerkez.dbo.Stores st ON st.Id=p.StoreId
            JOIN DerinSISBkm.dbo.posMagaza MG ON MG.mekanKod COLLATE Turkish_CI_AS=st.Code COLLATE Turkish_CI_AS
            JOIN EncoreMerkez.dbo.SalesProducts sp WITH(NOLOCK) ON sp.SalesId=s.Id AND sp.IsValid=1 AND sp.BarcodeNo<>'1001'
            JOIN EncoreMerkez.dbo.Products pr WITH(NOLOCK) ON pr.Id=sp.ProductsId
            JOIN DerinSISBkm.dbo.urn u WITH(NOLOCK) ON u.stkID=CONVERT(int,pr.Code)
            JOIN DerinSISBkm.dbo.urnKtgr2 ktg WITH(NOLOCK) ON ktg.ktgrID=u.urnKtgr2ID
            WHERE s.DocumentsTypeId IN (1,2,3,6,7,8) AND ISNUMERIC(pr.Code)=1 AND s.Date>=@start AND s.Date<@end
            GROUP BY MG.mekanID, CAST(ktg.ktgrAd AS nvarchar(50));
            """;
        var skat = (await conn.QueryAsync<(int MekanId, string Ad, decimal Ciro)>(skatSql, katPar)).ToList();
        var skatMap = skat.GroupBy(r => r.MekanId)
            .ToDictionary(g => g.Key, g => (IReadOnlyList<CategorySlice>)g.OrderByDescending(x => x.Ciro)
                .Select(x => new CategorySlice(x.Ad, x.Ciro)).ToList());

        var cards = new List<StoreCard>();
        foreach (var mid in new[] { 4477, 1, 4478 })
        {
            var r = stores.FirstOrDefault(s => s.MekanId == mid);
            var net = r?.Net ?? 0;
            var fis = r?.Fis ?? 0;
            decimal? ger = hedef.TryGetValue(mid, out var h) && h > 0 ? Math.Round(100 * net / h, 1) : null;
            cards.Add(new StoreCard(mid, Mekan[mid], net, fis, fis > 0 ? (int)Math.Round(net / fis) : 0, ger, r?.Iade ?? 0,
                skatMap.GetValueOrDefault(mid, [])));
        }

        // E-ticaret kanal kırılımı (donut)
        const string eticKanalSql = """
            SELECT CASE WHEN o.APPLICATION IN ('Mobil Uygulama (Android)','Mobil Uygulama (iOS)','Mobil Site','Web Sitesi')
                        THEN o.APPLICATION ELSE 'Diğer' END AS Ad,
                   SUM(CASE WHEN o.STATUS NOT IN (1001,1006,1007,3000,4000) THEN 1 ELSE 0 END) AS Sip,
                   SUM(CASE WHEN o.STATUS IN (1001,1006,1007,3000,4000) THEN 1 ELSE 0 END) AS Ipt,
                   SUM(CASE WHEN o.STATUS NOT IN (1001,1006,1007,3000,4000) THEN o.TOTALPRICE ELSE 0 END) AS Ciro
            FROM ODAKJOKER.JOKER.dbo.J_ORDERS o
            WHERE o.ORDERDATE>=@giso AND o.ORDERDATE<@g2iso
            GROUP BY CASE WHEN o.APPLICATION IN ('Mobil Uygulama (Android)','Mobil Uygulama (iOS)','Mobil Site','Web Sitesi')
                          THEN o.APPLICATION ELSE 'Diğer' END;
            """;
        var eticKanal = (await conn.QueryAsync<EticChannel>(eticKanalSql, new { giso, g2iso }))
            .Select(e => e with { Ad = e.Ad.Replace("Mobil Uygulama ", "").Replace("(", "").Replace(")", "") })
            .OrderByDescending(e => e.Ciro).ToList();

        // Kategori mix (mağaza×kategori → toplam; Products.Code=stkID köprüsü, geri dönüşüm hariç)
        const string katSql = """
            SELECT CAST(ktg.ktgrAd AS nvarchar(50)) AS Ad,
                   CAST(SUM(IIF(s.DocumentsTypeId=3,-1,1)*sp.TotalPrice) AS decimal(18,0)) AS Ciro
            FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
            JOIN EncoreMerkez.dbo.SalesProducts sp WITH(NOLOCK) ON sp.SalesId=s.Id AND sp.IsValid=1 AND sp.BarcodeNo<>'1001'
            JOIN EncoreMerkez.dbo.Products pr WITH(NOLOCK) ON pr.Id=sp.ProductsId
            JOIN DerinSISBkm.dbo.urn u WITH(NOLOCK) ON u.stkID=CONVERT(int,pr.Code)
            JOIN DerinSISBkm.dbo.urnKtgr2 ktg WITH(NOLOCK) ON ktg.ktgrID=u.urnKtgr2ID
            WHERE s.DocumentsTypeId IN (1,2,3,6,7,8) AND ISNUMERIC(pr.Code)=1 AND s.Date>=@start AND s.Date<@end
            GROUP BY CAST(ktg.ktgrAd AS nvarchar(50));
            """;
        var kategori = (await conn.QueryAsync<CategorySlice>(katSql, katPar))
            .OrderByDescending(k => k.Ciro).Take(8).ToList();

        // Saat bazlı yoğunluk
        const string saatSql = """
            SELECT DATEPART(HOUR,s.Date) AS Saat, SUM(IIF(s.DocumentsTypeId=3,-1,1)) AS Fis,
                   CAST(SUM(IIF(s.DocumentsTypeId=3,-1,1)*(s.GrossTotal-s.DiscountTotal)) AS decimal(18,0)) AS Net
            FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
            WHERE s.DocumentsTypeId IN (1,2,3,6,7,8) AND s.Date>=@start AND s.Date<@end
            GROUP BY DATEPART(HOUR,s.Date);
            """;
        var saat = (await conn.QueryAsync<HourBar>(saatSql, katPar)).OrderBy(h => h.Saat).ToList();

        // Kasiyer performansı (mağaza gruplu, grup içi net azalan)
        const string kasSql = """
            SELECT CAST(st.Name AS nvarchar(30)) AS Magaza, CAST(ISNULL(u.Name,'?') AS nvarchar(30)) AS Ad, COUNT(*) AS Fis,
                   CAST(SUM(CASE WHEN s.DocumentsTypeId=3 THEN -(s.GrossTotal-ABS(s.DiscountTotal)) ELSE s.GrossTotal-s.DiscountTotal END) AS decimal(18,0)) AS Net,
                   SUM(CASE WHEN s.DocumentsTypeId=3 THEN 1 ELSE 0 END) AS Iade
            FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
            JOIN EncoreMerkez.dbo.Stores st ON st.Id=s.StoresId
            LEFT JOIN EncoreMerkez.dbo.Users u ON u.Id=s.UsersId
            WHERE s.DocumentsTypeId IN (1,2,3,6,7,8) AND s.Date>=@start AND s.Date<@end
            GROUP BY CAST(st.Name AS nvarchar(30)), CAST(ISNULL(u.Name,'?') AS nvarchar(30));
            """;
        var kasiyer = (await conn.QueryAsync<(string Magaza, string Ad, int Fis, decimal Net, int Iade)>(kasSql, katPar))
            .Select(k => new KasiyerRow(k.Magaza, k.Ad, k.Fis, k.Net, k.Fis > 0 ? (int)Math.Round(k.Net / k.Fis) : 0, k.Iade))
            .OrderBy(k => k.Magaza).ThenByDescending(k => k.Net).ToList();

        var fiz = stores.Sum(s => s.Net);
        var fisTop = stores.Sum(s => s.Fis);
        var iadeTop = stores.Sum(s => s.Iade);
        return new PeriodSummary(fiz, fisTop, iadeTop, eCiro, eSip, fiz + eCiro, cards, kategori, eticKanal, saat, kasiyer);
    }

    /// <summary>Son 14 gün fiziksel net ciro (trend area). dun = referans (dahil).</summary>
    public async Task<IReadOnlyList<TrendPoint>> GetTrendAsync(DateOnly dun)
    {
        await using var conn = await db.OpenAsync();
        const string sql = """
            SELECT CONVERT(varchar,s.Date,23) AS Tarih,
                   CAST(SUM(IIF(s.DocumentsTypeId=3,-1,1)*(s.GrossTotal-s.DiscountTotal)) AS decimal(18,0)) AS Net
            FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
            LEFT JOIN EncoreMerkez.dbo.SalesProducts spb ON spb.SalesId=s.Id AND spb.BarcodeNo='1001'
            WHERE s.DocumentsTypeId IN (1,2,3,6,7,8) AND spb.Id IS NULL AND s.Date>=@bas AND s.Date<@son
            GROUP BY CONVERT(varchar,s.Date,23);
            """;
        var bas = dun.AddDays(-13).ToDateTime(TimeOnly.MinValue);
        var son = dun.AddDays(1).ToDateTime(TimeOnly.MinValue);
        return (await conn.QueryAsync<TrendPoint>(sql, new { bas, son })).OrderBy(t => t.Tarih).ToList();
    }

    /// <summary>Son 14 gün net alış (mal kabul) trend. ehTip 0=Alış + 10=Yerel Alım − 2=Alış İade (irsHrk).</summary>
    public async Task<IReadOnlyList<TrendPoint>> GetAlisTrendAsync(DateOnly dun)
    {
        await using var conn = await db.OpenAsync();
        const string sql = """
            SELECT CONVERT(varchar,h.ehTrhS,23) AS Tarih,
                   CAST(SUM(CASE WHEN h.ehTip IN (0,10) THEN h.ehTutarN WHEN h.ehTip=2 THEN -h.ehTutarN ELSE 0 END) AS decimal(18,0)) AS Net
            FROM DerinSISBkm.dbo.irsHrk h WITH(NOLOCK)
            WHERE h.ehTrhS>=@bas AND h.ehTrhS<@son AND h.ehAltDepo=0 AND h.ehTip IN (0,2,10)
            GROUP BY CONVERT(varchar,h.ehTrhS,23);
            """;
        var bas = dun.AddDays(-13).ToDateTime(TimeOnly.MinValue);
        var son = dun.AddDays(1).ToDateTime(TimeOnly.MinValue);
        return (await conn.QueryAsync<TrendPoint>(sql, new { bas, son })).OrderBy(t => t.Tarih).ToList();
    }
}
