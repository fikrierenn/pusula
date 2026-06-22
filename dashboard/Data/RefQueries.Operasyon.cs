using Dapper;
using GmDashboard.Models;

namespace GmDashboard.Data;

/// <summary>
/// Operasyon sayfası hızlı-kazanım kartları (B-112) — zincir geneli, dönem-duyarlı.
/// (a) Ödeme üst-grubu cirosu + önceki eş-dönem (nakit payı↑ = stres) ·
/// (b) İade sebebi (RefundReasons.Type=0, DocType=3) ·
/// (c) İndirim kaynağı (SalesProductCampaigns.Source 0/1/2).
/// Köprü: posMagaza.mekanKod = Stores.Code (COLLATE Turkish_CI_AS), şubeler IN (Subeler). Tarih DMY param.
/// </summary>
public sealed partial class RefQueries
{
    // Ödeme tipi adı → üst-grup (sema codes.yaml encore_odeme_grup). MagazaQueries ile aynı eşleme.
    static string OdemeGrubu(string? tip) => tip?.ToUpperInvariant() switch
    {
        "TÜRK LİRASI" => "Nakit",
        "İADE ÇEKİ" => "İade Çeki",
        "HEDİYE ÇEKİ" => "Hediye Çeki",
        _ => "Kredi/Banka Kartı",
    };

    /// <summary>(a) Ödeme üst-grubu cirosu (zincir, dönem) + önceki eş-uzunluk dönem.
    /// Para üstü hariç (IsChangeAmount=0 ZORUNLU). prevStart = start − dönem uzunluğu.</summary>
    public async Task<IReadOnlyList<OdemeGrupRow>> GetOdemeGrupAsync(DateOnly start, DateOnly endExcl, DateOnly prevStart)
    {
        await using var conn = await db.OpenAsync();
        var sql = $"""
            SELECT pt.Name AS Tip,
                   CAST(SUM(CASE WHEN s.[Date]>=@start THEN sp.Amount ELSE 0 END) AS decimal(18,2)) AS Tutar,
                   CAST(SUM(CASE WHEN s.[Date]<@start  THEN sp.Amount ELSE 0 END) AS decimal(18,2)) AS Onceki
            FROM EncoreMerkez.dbo.SalesPayments sp WITH(NOLOCK)
            JOIN EncoreMerkez.dbo.PaymentTypes  pt WITH(NOLOCK) ON pt.Id = sp.PaymentTypesId
            JOIN EncoreMerkez.dbo.Sales         s  WITH(NOLOCK) ON s.Id = sp.SalesId
            JOIN EncoreMerkez.dbo.Pos           ps WITH(NOLOCK) ON ps.Id = s.PosId
            JOIN EncoreMerkez.dbo.Stores        st WITH(NOLOCK) ON st.Id = ps.StoreId
            JOIN DerinSISBkm.dbo.posMagaza      mg WITH(NOLOCK)
                 ON mg.mekanKod COLLATE Turkish_CI_AS = st.Code COLLATE Turkish_CI_AS
                AND mg.mekanID IN ({LokasyonConfig.Subeler})
            WHERE sp.IsChangeAmount = 0 AND s.DocumentsTypeId IN (1,2,3,6,7,8)
              AND s.[Date] >= @prev AND s.[Date] < @end
            GROUP BY pt.Name;
            """;
        var par = new
        {
            start = start.ToDateTime(TimeOnly.MinValue),
            end = endExcl.ToDateTime(TimeOnly.MinValue),
            prev = prevStart.ToDateTime(TimeOnly.MinValue),
        };
        var ham = (await conn.QueryAsync<(string Tip, decimal Tutar, decimal Onceki)>(sql, par)).ToList();
        var sira = new Dictionary<string, int> { ["Kredi/Banka Kartı"] = 0, ["Nakit"] = 1, ["İade Çeki"] = 2, ["Hediye Çeki"] = 3 };
        return ham
            .GroupBy(o => OdemeGrubu(o.Tip))
            .Select(g => new OdemeGrupRow(g.Key, g.Sum(x => x.Tutar), g.Sum(x => x.Onceki)))
            .OrderBy(g => sira.GetValueOrDefault(g.Grup, 9))
            .ToList();
    }

    /// <summary>(b) İade sebebi (RefundReasons.Type=0) — DocType=3 iade kalemleri, dönem.
    /// Tutar = KDV-hariç iade satır tutarı (TotalPrice − VatTotal). Geri dönüşüm 1001 dahil (gerçek iade sebebi).</summary>
    public async Task<IReadOnlyList<IadeSebepRow>> GetIadeSebepAsync(DateOnly start, DateOnly endExcl)
    {
        await using var conn = await db.OpenAsync();
        var sql = $"""
            SELECT rr.Name AS Sebep,
                   COUNT(*) AS Kalem,
                   CAST(SUM(sp.TotalPrice - sp.VatTotal) AS decimal(18,2)) AS Tutar
            FROM EncoreMerkez.dbo.SalesProducts sp WITH(NOLOCK)
            JOIN EncoreMerkez.dbo.Sales         s  WITH(NOLOCK) ON s.Id = sp.SalesId
            JOIN EncoreMerkez.dbo.RefundReasons rr WITH(NOLOCK) ON rr.Id = sp.RefundReasonId AND rr.Type = 0
            JOIN EncoreMerkez.dbo.Pos           ps WITH(NOLOCK) ON ps.Id = s.PosId
            JOIN EncoreMerkez.dbo.Stores        st WITH(NOLOCK) ON st.Id = ps.StoreId
            JOIN DerinSISBkm.dbo.posMagaza      mg WITH(NOLOCK)
                 ON mg.mekanKod COLLATE Turkish_CI_AS = st.Code COLLATE Turkish_CI_AS
                AND mg.mekanID IN ({LokasyonConfig.Subeler})
            WHERE sp.IsValid = 1 AND s.DocumentsTypeId = 3
              AND s.[Date] >= @start AND s.[Date] < @end
            GROUP BY rr.Name;
            """;
        var par = new { start = start.ToDateTime(TimeOnly.MinValue), end = endExcl.ToDateTime(TimeOnly.MinValue) };
        return (await conn.QueryAsync<IadeSebepRow>(sql, par)).OrderByDescending(r => r.Kalem).ToList();
    }

    /// <summary>(c) İndirim kaynağı (SalesProductCampaigns.Source) — dönem indirim hacmi.
    /// 0=Kampanya (adlı) · 1=Manuel (kodsuz) · 2=Legacy/otomatik · 3=Kupon. İndirim = SUM(−TotalDiscount).</summary>
    public async Task<IReadOnlyList<IndirimKaynakRow>> GetIndirimKaynakAsync(DateOnly start, DateOnly endExcl)
    {
        await using var conn = await db.OpenAsync();
        var sql = $"""
            SELECT spc.Source AS Source,
                   CAST(SUM(-spc.TotalDiscount) AS decimal(18,2)) AS Indirim,
                   COUNT(DISTINCT spc.SalesId) AS Fis
            FROM EncoreMerkez.dbo.SalesProductCampaigns spc WITH(NOLOCK)
            JOIN EncoreMerkez.dbo.Sales    s  WITH(NOLOCK) ON s.Id = spc.SalesId
            JOIN EncoreMerkez.dbo.Pos      ps WITH(NOLOCK) ON ps.Id = s.PosId
            JOIN EncoreMerkez.dbo.Stores   st WITH(NOLOCK) ON st.Id = ps.StoreId
            JOIN DerinSISBkm.dbo.posMagaza mg WITH(NOLOCK)
                 ON mg.mekanKod COLLATE Turkish_CI_AS = st.Code COLLATE Turkish_CI_AS
                AND mg.mekanID IN ({LokasyonConfig.Subeler})
            WHERE s.DocumentsTypeId IN (1,2,6,7,8)
              AND s.[Date] >= @start AND s.[Date] < @end
            GROUP BY spc.Source;
            """;
        var par = new { start = start.ToDateTime(TimeOnly.MinValue), end = endExcl.ToDateTime(TimeOnly.MinValue) };
        var ad = new Dictionary<int, string> { [0] = "Kampanya (adlı)", [1] = "Manuel (kodsuz)", [2] = "Legacy/otomatik", [3] = "Kupon" };
        return (await conn.QueryAsync<(int Source, decimal Indirim, int Fis)>(sql, par))
            .Select(r => new IndirimKaynakRow(r.Source, ad.GetValueOrDefault(r.Source, $"Source {r.Source}"), r.Indirim, r.Fis))
            .OrderByDescending(r => r.Indirim).ToList();
    }
}
