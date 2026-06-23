using Dapper;
using GmDashboard.Models;

namespace GmDashboard.Data;

/// <summary>
/// Mağaza detay sayfası (/magaza/{id}) sorguları — B-40.
/// Kaynak: gm-rapor katalog G2 (ödeme) · G3 (iade) · M2 (kampanya) · UPT (SalesProducts.Amount).
/// Mağaza köprü: posMagaza.mekanKod = Stores.Code (COLLATE Turkish_CI_AS). Tarih DMY param.
/// </summary>
public sealed class MagazaQueries(Db db)
{
    // Mağaza adı LokasyonConfig.Mekan'dan (posMagaza dinamik — hardcode değil).

    // Ödeme tipi → üst-grup. TÜRK LİRASI=Nakit, çekler ayrı, geri kalan banka adları=Kredi/Banka Kartı.
    static string OdemeGrubu(string tip) => tip?.ToUpperInvariant() switch
    {
        "TÜRK LİRASI" => "Nakit",
        "İADE ÇEKİ" => "İade Çeki",
        "HEDİYE ÇEKİ" => "Hediye Çeki",
        _ => "Kredi/Banka Kartı",
    };

    public async Task<MagazaDetay?> GetDetayAsync(int mid, DateOnly start, DateOnly endExcl)
    {
        if (!LokasyonConfig.Mekan.ContainsKey(mid)) return null;
        var par = new { mid, start = start.ToDateTime(TimeOnly.MinValue), end = endExcl.ToDateTime(TimeOnly.MinValue) };
        // B-49 perf: 7 bağımsız sorgu paralel (her biri kendi bağlantısı) → sıralı ~3,4s yerine ~1,2s (max tek sorgu).
        async Task<T> Q<T>(Func<System.Data.IDbConnection, Task<T>> fn) { await using var c = await db.OpenAsync(); return await fn(c); }
        var ayBas = new DateOnly(start.Year, start.Month, 1);   // hedef: ay başı–bugün
        var hedefPar = new { mid, a = ayBas.ToDateTime(TimeOnly.MinValue), b = endExcl.ToDateTime(TimeOnly.MinValue) };

        // Net / Fiş / İade / İade oranı (G3 pattern, tek mağaza; geri dönüşüm fişi 1001 hariç net'te)
        const string kpiSql = """
            SELECT
                SUM(CASE WHEN s.DocumentsTypeId=3 THEN -1 ELSE 1 END*(s.GrossTotal-s.DiscountTotal-s.VatTotal)) AS Net,
                SUM(CASE WHEN s.DocumentsTypeId=3 THEN -1 ELSE 1 END)                                AS Fis,
                SUM(CASE WHEN s.DocumentsTypeId=3 THEN s.GrossTotal ELSE 0 END)                      AS Iade,
                CAST(100.0*SUM(CASE WHEN s.DocumentsTypeId=3 THEN s.GrossTotal ELSE 0 END)
                   / NULLIF(SUM(CASE WHEN s.DocumentsTypeId IN(1,2,6,7,8) THEN s.GrossTotal ELSE 0 END),0) AS decimal(10,1)) AS IadeOran
            FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
            JOIN EncoreMerkez.dbo.Pos p ON p.Id=s.PosId
            JOIN EncoreMerkez.dbo.Stores st ON st.Id=p.StoreId
            JOIN DerinSISBkm.dbo.posMagaza MG ON MG.mekanKod COLLATE Turkish_CI_AS=st.Code COLLATE Turkish_CI_AS
            LEFT JOIN EncoreMerkez.dbo.SalesProducts spb ON spb.SalesId=s.Id AND spb.BarcodeNo='1001'
            WHERE MG.mekanID=@mid AND s.DocumentsTypeId IN (1,2,3,6,7,8) AND spb.Id IS NULL
              AND s.Date>=@start AND s.Date<@end;
            """;
        var tKpi = Q(c => c.QuerySingleOrDefaultAsync<(decimal? Net, int? Fis, decimal? Iade, decimal? IadeOran)>(kpiSql, par));

        // UPT = satılan adet (SalesProducts.Amount) / fiş; iade hariç (satış belgeleri)
        const string uptSql = """
            SELECT CAST(SUM(sp.Amount)/NULLIF(COUNT(DISTINCT s.Id),0) AS decimal(10,2))
            FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
            JOIN EncoreMerkez.dbo.Pos p ON p.Id=s.PosId
            JOIN EncoreMerkez.dbo.Stores st ON st.Id=p.StoreId
            JOIN DerinSISBkm.dbo.posMagaza MG ON MG.mekanKod COLLATE Turkish_CI_AS=st.Code COLLATE Turkish_CI_AS
            JOIN EncoreMerkez.dbo.SalesProducts sp WITH(NOLOCK) ON sp.SalesId=s.Id AND sp.IsValid=1 AND sp.BarcodeNo<>'1001'
            WHERE MG.mekanID=@mid AND s.DocumentsTypeId IN (1,2,6,7,8) AND s.Date>=@start AND s.Date<@end;
            """;
        var tUpt = Q(c => c.QuerySingleOrDefaultAsync<decimal?>(uptSql, par));

        // Ödeme tipi mix (G2, tek mağaza; para üstü hariç)
        const string odemeSql = """
            SELECT pt.Name AS Tip, COUNT(*) AS Islem, CAST(SUM(sp.Amount) AS decimal(18,2)) AS Tutar,
                   CAST(100.0*SUM(sp.Amount)/NULLIF(SUM(SUM(sp.Amount)) OVER(),0) AS decimal(5,1)) AS Pay
            FROM EncoreMerkez.dbo.SalesPayments sp WITH(NOLOCK)
            JOIN EncoreMerkez.dbo.PaymentTypes pt WITH(NOLOCK) ON pt.Id=sp.PaymentTypesId
            JOIN EncoreMerkez.dbo.Sales s WITH(NOLOCK) ON s.Id=sp.SalesId
            JOIN EncoreMerkez.dbo.Pos p ON p.Id=s.PosId
            JOIN EncoreMerkez.dbo.Stores st ON st.Id=p.StoreId
            JOIN DerinSISBkm.dbo.posMagaza MG ON MG.mekanKod COLLATE Turkish_CI_AS=st.Code COLLATE Turkish_CI_AS
            WHERE MG.mekanID=@mid AND s.DocumentsTypeId IN (1,2,3,6,7,8) AND sp.IsChangeAmount=0
              AND s.Date>=@start AND s.Date<@end
            GROUP BY pt.Name
            ORDER BY Tutar DESC;
            """;
        var tOdeme = Q(c => c.QueryAsync<OdemeRow>(odemeSql, par));

        // Kampanya yükü (M2, tek mağaza; CampaignName boş = manuel set indirimi)
        // Brüt = kampanyalı kalemlerin net satışı (SalesProducts.TotalPrice) + indirim.
        // KRİTİK: spc bir ürün satırına N indirim satırı üretir (3al2öde 52 adet → 26 çift = 52 spc).
        //   İndirim spc-başı doğru (SUM), AMA sp.TotalPrice spc fan-out'unda N× sayılır → brüt şişer.
        //   Bu yüzden: indirim spc'den (ind CTE), net satır-başı 1× DISTINCT'ten (net CTE). (FIX 15.06)
        const string kampSql = """
            WITH ind AS (
                SELECT CASE WHEN LTRIM(RTRIM(spc.CampaignName))='' THEN N'(manuel/kodsuz)' ELSE spc.CampaignName END AS Ad,
                       COUNT(DISTINCT CONVERT(date,s.Date)) AS Gun,
                       CAST(SUM(-spc.TotalDiscount) AS decimal(18,2)) AS Indirim,
                       COUNT(DISTINCT spc.SalesId) AS Fis
                FROM EncoreMerkez.dbo.SalesProductCampaigns spc
                JOIN EncoreMerkez.dbo.Sales s ON s.Id=spc.SalesId
                JOIN EncoreMerkez.dbo.Pos p ON p.Id=s.PosId
                JOIN EncoreMerkez.dbo.Stores st ON st.Id=p.StoreId
                JOIN DerinSISBkm.dbo.posMagaza MG ON MG.mekanKod COLLATE Turkish_CI_AS=st.Code COLLATE Turkish_CI_AS
                WHERE MG.mekanID=@mid AND s.DocumentsTypeId IN (1,2,6,7,8) AND s.Date>=@start AND s.Date<@end
                GROUP BY CASE WHEN LTRIM(RTRIM(spc.CampaignName))='' THEN N'(manuel/kodsuz)' ELSE spc.CampaignName END
            ),
            net AS (
                SELECT Ad, CAST(SUM(TotalPrice) AS decimal(18,2)) AS Net
                FROM (
                    SELECT DISTINCT
                           CASE WHEN LTRIM(RTRIM(spc.CampaignName))='' THEN N'(manuel/kodsuz)' ELSE spc.CampaignName END AS Ad,
                           sp.SalesId, sp.Sequence, sp.TotalPrice
                    FROM EncoreMerkez.dbo.SalesProductCampaigns spc
                    JOIN EncoreMerkez.dbo.SalesProducts sp ON sp.SalesId=spc.SalesId AND sp.Sequence=spc.ProductSequence AND sp.IsValid=1
                    JOIN EncoreMerkez.dbo.Sales s ON s.Id=spc.SalesId
                    JOIN EncoreMerkez.dbo.Pos p ON p.Id=s.PosId
                    JOIN EncoreMerkez.dbo.Stores st ON st.Id=p.StoreId
                    JOIN DerinSISBkm.dbo.posMagaza MG ON MG.mekanKod COLLATE Turkish_CI_AS=st.Code COLLATE Turkish_CI_AS
                    WHERE MG.mekanID=@mid AND s.DocumentsTypeId IN (1,2,6,7,8) AND s.Date>=@start AND s.Date<@end
                ) d
                GROUP BY Ad
            )
            SELECT ind.Ad, ind.Gun,
                   CAST(ISNULL(net.Net,0)+ind.Indirim AS decimal(18,2)) AS Brut,
                   ind.Indirim,
                   CAST(100.0*ind.Indirim/NULLIF(ISNULL(net.Net,0)+ind.Indirim,0) AS decimal(5,1)) AS Oran,
                   ind.Fis
            FROM ind
            LEFT JOIN net ON net.Ad=ind.Ad
            ORDER BY ind.Indirim DESC;
            """;
        var tKamp = Q(c => c.QueryAsync<KampanyaRow>(kampSql, par));

        // TOPLAM fiş: DISTINCT kampanyalı fiş (kampanyalar arası çift sayımı önler — geçerli kalemli)
        const string kampFisSql = """
            SELECT COUNT(DISTINCT spc.SalesId)
            FROM EncoreMerkez.dbo.SalesProductCampaigns spc
            JOIN EncoreMerkez.dbo.SalesProducts sp ON sp.SalesId=spc.SalesId AND sp.Sequence=spc.ProductSequence AND sp.IsValid=1
            JOIN EncoreMerkez.dbo.Sales s ON s.Id=spc.SalesId
            JOIN EncoreMerkez.dbo.Pos p ON p.Id=s.PosId
            JOIN EncoreMerkez.dbo.Stores st ON st.Id=p.StoreId
            JOIN DerinSISBkm.dbo.posMagaza MG ON MG.mekanKod COLLATE Turkish_CI_AS=st.Code COLLATE Turkish_CI_AS
            WHERE MG.mekanID=@mid AND s.DocumentsTypeId IN (1,2,6,7,8) AND s.Date>=@start AND s.Date<@end;
            """;
        var tKampFis = Q(c => c.QuerySingleOrDefaultAsync<int>(kampFisSql, par));

        // Kategori (skat, tek mağaza — ürün drill için)
        const string katSql = """
            SELECT CAST(ktg.ktgrAd AS nvarchar(50)) AS Ad,
                   CAST(SUM(CASE WHEN s.DocumentsTypeId=3 THEN -1 ELSE 1 END*(sp.TotalPrice-sp.VatTotal)) AS decimal(18,0)) AS Ciro
            FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
            JOIN EncoreMerkez.dbo.Pos p ON p.Id=s.PosId
            JOIN EncoreMerkez.dbo.Stores st ON st.Id=p.StoreId
            JOIN DerinSISBkm.dbo.posMagaza MG ON MG.mekanKod COLLATE Turkish_CI_AS=st.Code COLLATE Turkish_CI_AS
            JOIN EncoreMerkez.dbo.SalesProducts sp WITH(NOLOCK) ON sp.SalesId=s.Id AND sp.IsValid=1 AND sp.BarcodeNo<>'1001'
            JOIN EncoreMerkez.dbo.Products pr WITH(NOLOCK) ON pr.Id=sp.ProductsId
            JOIN DerinSISBkm.dbo.urn u WITH(NOLOCK) ON u.stkID=CONVERT(int,pr.Code)
            JOIN DerinSISBkm.dbo.urnKtgr2 ktg WITH(NOLOCK) ON ktg.ktgrID=u.urnKtgr2ID
            WHERE MG.mekanID=@mid AND s.DocumentsTypeId IN (1,2,3,6,7,8) AND ISNUMERIC(pr.Code)=1
              AND s.Date>=@start AND s.Date<@end
            GROUP BY CAST(ktg.ktgrAd AS nvarchar(50))
            ORDER BY Ciro DESC;
            """;
        var tKat = Q(c => c.QueryAsync<CategorySlice>(katSql, par));

        // Hedef gerçekleşme (aylık) — ay başı–bugün
        const string hedefSql = "SELECT SUM(hedef) FROM BKMDATA.dbo.Hedef WITH(NOLOCK) WHERE mekanId=@mid AND tarih>=@a AND tarih<@b;";
        var tHedef = Q(c => c.QuerySingleOrDefaultAsync<decimal?>(hedefSql, hedefPar));

        await Task.WhenAll(tKpi, tUpt, tOdeme, tKamp, tKampFis, tKat, tHedef);

        // --- Sonuçları işle (tümü paralel tamamlandı) ---
        var kpi = tKpi.Result;
        var net = kpi.Net ?? 0m;
        var fis = kpi.Fis ?? 0;
        var upt = tUpt.Result ?? 0m;

        // Ödeme üst-grupla: TÜRK LİRASI=Nakit · İADE ÇEKİ · HEDİYE ÇEKİ · geri kalan (banka)=Kredi/Banka Kartı
        var odemeHam = tOdeme.Result.ToList();
        var toplamOdeme = odemeHam.Sum(o => o.Tutar);
        var siraDuzen = new Dictionary<string, int> { ["Kredi/Banka Kartı"] = 0, ["Nakit"] = 1, ["İade Çeki"] = 2, ["Hediye Çeki"] = 3 };
        var odeme = odemeHam
            .GroupBy(o => OdemeGrubu(o.Tip))
            .Select(g => new OdemeGrup(g.Key, g.Sum(x => x.Islem), g.Sum(x => x.Tutar),
                toplamOdeme > 0 ? Math.Round(100 * g.Sum(x => x.Tutar) / toplamOdeme, 1) : 0,
                g.OrderByDescending(x => x.Tutar).ToList()))
            .OrderBy(g => siraDuzen.GetValueOrDefault(g.Grup, 9))
            .ToList();

        var kampDetay = tKamp.Result.ToList();
        var kampToplamFis = tKampFis.Result;
        var kampToplamBrut = kampDetay.Sum(k => k.Brut);
        var kampToplamInd = kampDetay.Sum(k => k.Indirim);

        // Grupla: 3AL2ÖDE(K) ayrı (ana kampanya) · geri kalan hepsi "Diğer İndirimler" toplu (drill detayında).
        var kampanya = new List<KampanyaGrup>();
        var anaKamp = kampDetay.FirstOrDefault(k => k.Ad == "3AL2ÖDE(K)");
        if (anaKamp is not null)
            kampanya.Add(new KampanyaGrup("3AL2ÖDE(K)", anaKamp.Brut, anaKamp.Indirim, anaKamp.Oran, anaKamp.Fis, [anaKamp]));
        var diger = kampDetay.Where(k => k.Ad != "3AL2ÖDE(K)").ToList();
        if (diger.Count > 0)
        {
            var dBrut = diger.Sum(x => x.Brut);
            var dInd = diger.Sum(x => x.Indirim);
            kampanya.Add(new KampanyaGrup("Diğer İndirimler", dBrut, dInd,
                dBrut > 0 ? Math.Round(100 * dInd / dBrut, 1) : 0,
                diger.Sum(x => x.Fis), diger));
        }

        var kategori = tKat.Result.ToList();
        var hedef = tHedef.Result;
        decimal? ger = hedef is > 0 ? Math.Round(100 * net / hedef.Value, 1) : null;

        return new MagazaDetay(mid, LokasyonConfig.Mekan[mid], net, fis, fis > 0 ? (int)Math.Round(net / fis) : 0,
            upt, kpi.Iade ?? 0m, kpi.IadeOran ?? 0m, ger, odeme, kampanya,
            kampToplamBrut, kampToplamInd, kampToplamFis, kategori);
    }

    /// <summary>Mağaza son N gün günlük net ciro (trend area). dun = referans (dahil). B-53.</summary>
    public async Task<IReadOnlyList<TrendPoint>> GetTrendAsync(int mid, DateOnly dun, int gun = 30)
    {
        await using var conn = await db.OpenAsync();
        const string sql = """
            SELECT CONVERT(varchar,s.Date,23) AS Tarih,
                   CAST(SUM(CASE WHEN s.DocumentsTypeId=3 THEN -1 ELSE 1 END*(s.GrossTotal-s.DiscountTotal-s.VatTotal)) AS decimal(18,0)) AS Net
            FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
            JOIN EncoreMerkez.dbo.Pos p ON p.Id=s.PosId
            JOIN EncoreMerkez.dbo.Stores st ON st.Id=p.StoreId
            JOIN DerinSISBkm.dbo.posMagaza MG ON MG.mekanKod COLLATE Turkish_CI_AS=st.Code COLLATE Turkish_CI_AS
            LEFT JOIN EncoreMerkez.dbo.SalesProducts spb ON spb.SalesId=s.Id AND spb.BarcodeNo='1001'
            WHERE MG.mekanID=@mid AND s.DocumentsTypeId IN (1,2,3,6,7,8) AND spb.Id IS NULL
              AND s.Date>=@bas AND s.Date<@son
            GROUP BY CONVERT(varchar,s.Date,23);
            """;
        var bas = dun.AddDays(-(gun - 1)).ToDateTime(TimeOnly.MinValue);
        var son = dun.AddDays(1).ToDateTime(TimeOnly.MinValue);
        return (await conn.QueryAsync<TrendPoint>(sql, new { mid, bas, son })).OrderBy(t => t.Tarih).ToList();
    }

    /// <summary>B-55 saat×gün yoğunluk (heatmap): son N gün fiş adedi. Gun=DATEDIFF%7 (0=Pzt..6=Paz, deterministik).</summary>
    public async Task<IReadOnlyList<HeatCell>> GetHeatmapAsync(int mid, DateOnly dun, int gun = 60)
    {
        await using var conn = await db.OpenAsync();
        const string sql = """
            SELECT DATEDIFF(DAY,0,s.Date)%7 AS Gun, DATEPART(HOUR,s.Date) AS Saat, COUNT(*) AS Fis
            FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
            JOIN EncoreMerkez.dbo.Pos p ON p.Id=s.PosId
            JOIN EncoreMerkez.dbo.Stores st ON st.Id=p.StoreId
            JOIN DerinSISBkm.dbo.posMagaza MG ON MG.mekanKod COLLATE Turkish_CI_AS=st.Code COLLATE Turkish_CI_AS
            WHERE MG.mekanID=@mid AND s.DocumentsTypeId IN (1,2,6,7,8) AND s.Date>=@bas AND s.Date<@son
            GROUP BY DATEDIFF(DAY,0,s.Date)%7, DATEPART(HOUR,s.Date);
            """;
        var bas = dun.AddDays(-(gun - 1)).ToDateTime(TimeOnly.MinValue);
        var son = dun.AddDays(1).ToDateTime(TimeOnly.MinValue);
        return (await conn.QueryAsync<HeatCell>(sql, new { mid, bas, son })).ToList();
    }
}
