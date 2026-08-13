using Dapper;
using GmDashboard.Models;

namespace GmDashboard.Data;

/// <summary>
/// Satınalma ürün-detay drill (/satinalma/urun/{stkID}) — Alım Analizi satırından tıklanır.
/// Ürün özet + alış faturaları (fatAyr+fat+frm) + aylık satış (şube irsHrk + e-tic JOKER direkt).
/// Salt-okuma (erp-write-policy); 3-parçalı DerinSISBkm isim (master katalog).
/// </summary>
public sealed partial class SatinalmaQueries
{
    /// <summary>Ürün başlığı + anlık şube/depo stok. Yoksa null (geçersiz stkID).</summary>
    public async Task<SatinalmaUrunOzet?> GetUrunOzetAsync(int stkID)
    {
        const string sql = """
            SELECT u.stkID AS UrunKodu, u.stkAd AS UrunAd, u.Kategori3 AS Kategori, u.mrkAd AS Marka,
              ISNULL((SELECT SUM(stok) FROM DerinSISBkm.dbo.stokSon_vw WHERE ehstkID=@id AND ehMekan IN (1,4477,4478)),0) AS SubeStok,
              ISNULL((SELECT SUM(Stok) FROM DerinSISBkm.depo.stok_adres_palet_vw WHERE stkID=@id AND adrsAlanTipID IN (0,1)),0) AS DepoStok,
              (SELECT TOP 1 'https://cdn.bkmkitap.com/'+ts.ImageUrl FROM DerinSISBkm.ent.tsoft_urun ts
                 WHERE ts.stkid=@id AND ts.ImageUrl IS NOT NULL AND ts.ImageUrl<>'') AS ResimUrl
            FROM DerinSISBkm.bkm.UrunBilgi u WHERE u.stkID=@id;
            """;
        await using var c = await db.OpenAsync();
        return await c.QueryFirstOrDefaultAsync<SatinalmaUrunOzet>(sql, new { id = stkID });
    }

    /// <summary>Son alış faturaları (eTip=0), fatura-bazında toplanmış (0-birim promo satırlar dahil). Tedarikçi frm.frmAd.</summary>
    public async Task<IReadOnlyList<SatinalmaFaturaSatir>> GetFaturaDetayAsync(int stkID, int top = 40)
    {
        var sql = $"""
            SELECT TOP {top}
               MAX(f.eTarih) AS Tarih, f.eNo AS BelgeNo, MAX(LTRIM(RTRIM(ISNULL(frm.frmAd,'')))) AS Tedarikci,
               CONVERT(int,SUM(fa.ehAdetN)) AS Adet, CONVERT(decimal(18,2),SUM(fa.ehTutarN)) AS Tutar,
               CONVERT(decimal(18,2), SUM(fa.ehTutarN)/NULLIF(SUM(fa.ehAdetN),0)) AS Birim
            FROM DerinSISBkm.dbo.fatAyr fa WITH(NOLOCK)
            JOIN DerinSISBkm.dbo.fat f WITH(NOLOCK) ON fa.ehID=f.eID
            LEFT JOIN DerinSISBkm.dbo.frm frm WITH(NOLOCK) ON frm.frmID=f.eFirma
            WHERE fa.ehstkID=@id AND f.eTip=0 AND f.eDurum<>2 AND fa.ehAdetN>0
            GROUP BY f.eNo, f.eID
            ORDER BY MAX(f.eTarih) DESC, f.eID DESC;
            """;
        await using var c = await db.OpenAsync();
        return (await c.QueryAsync<SatinalmaFaturaSatir>(sql, new { id = stkID })).AsList();
    }

    /// <summary>Son 24 ay satış — şube (irsHrk) DerinSIS + e-ticaret (JOKER direkt), ay-bazında birleşik.</summary>
    public async Task<IReadOnlyList<SatinalmaAySatis>> GetAySatisAsync(int stkID)
    {
        // Son 24 ayın başı (bu ayın başından −23 ay) — hem DerinSIS hem JOKER penceresi.
        var basDt = new DateTime(DateTime.Today.Year, DateTime.Today.Month, 1).AddMonths(-23);
        var basIso = basDt.ToString("yyyyMMdd");

        const string subeSql = """
            SELECT CONVERT(char(7),ehTrhS,126) AS Ay, CONVERT(int,-SUM(ehAdetN)) AS Adet
            FROM DerinSISBkm.dbo.irsHrk WITH(NOLOCK)
            WHERE ehstkID=@id AND ehTip IN (1,4,100) AND ehTrhS>=@bas
            GROUP BY CONVERT(char(7),ehTrhS,126);
            """;
        const string eticSql = """
            SELECT CONVERT(varchar(4),YEAR(o.ORDERDATE))+'-'+RIGHT('0'+CONVERT(varchar(2),MONTH(o.ORDERDATE)),2) AS Ay, SUM(d.QUANTITY) AS Adet
            FROM JOKER.dbo.J_ORDER_DETAILS d JOIN JOKER.dbo.J_ORDERS o ON o.ORDERID=d.ORDERREF JOIN JOKER.dbo.J_ITEMS i ON i.LOGICALREF=d.ITEMREF
            WHERE i.DERINSIS_ID=@id AND d.STATUS NOT IN (2004,2005,2010) AND o.ORDERDATE>=@bas
            GROUP BY CONVERT(varchar(4),YEAR(o.ORDERDATE))+'-'+RIGHT('0'+CONVERT(varchar(2),MONTH(o.ORDERDATE)),2);
            """;

        async Task<List<(string Ay, int Adet)>> Sube()
        {
            await using var c = await db.OpenAsync();
            return (await c.QueryAsync<(string, int)>(subeSql, new { id = stkID, bas = basIso })).AsList();
        }
        async Task<List<(string Ay, int Adet)>> Etic()
        {
            await using var c = await db.OpenJokerAsync();   // direkt JOKER (ISO) — linked/OPENQUERY yerine (B-74)
            return (await c.QueryAsync<(string, int)>(eticSql, new { id = stkID, bas = basIso })).AsList();
        }

        var sube = await Sube();
        var etic = await Etic();

        // Ay-bazında birleştir + son 24 ay iskeleti (boş aylar 0).
        var map = new Dictionary<string, SatinalmaAySatis>();
        for (int i = 0; i < 24; i++)
        {
            var ay = basDt.AddMonths(i).ToString("yyyy-MM");
            map[ay] = new SatinalmaAySatis { Ay = ay };
        }
        foreach (var (ay, adet) in sube) if (map.TryGetValue(ay, out var r)) r.Sube = adet;
        foreach (var (ay, adet) in etic) if (map.TryGetValue(ay, out var r)) r.Etic = adet;
        return map.Values.OrderBy(r => r.Ay).ToList();
    }
}
