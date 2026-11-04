using Bkm.TestAltyapi;
using GmDashboard.Data;
using Microsoft.Extensions.Logging.Abstractions;

namespace GmDashboard.Tests.Canonical;

// Merkez depo stoğu (T-027, R6): panel ürün özeti, kanonik canlı WMS (alan tipi 0 ve 1) ile birebir eşit olmalı.
// Karakterizasyon testi: değişiklikten önce de sonra da yeşil. Canlı ERP, mesai dışında koşulur.
[Trait("AC", "001-AC-8.1")]
[Trait("Tur", "Canli")]
public class H08PurchasingTests
{
    private const string CanonicalFile = "H08-merkez-depo.sql";
    private const int SampleSize = 20;

    private sealed record WarehouseRow(int StkId, int Merkez);

    [Fact]
    public async Task ProductSummary_Today_CentralStockEqualsLiveWms()
    {
        // Arrange
        string sql = CanonicalQuery.Read(CanonicalFile, "A");
        IReadOnlyList<WarehouseRow> live = await LiveDb.QueryAsync<WarehouseRow>(DbTarget.Erp, sql);
        WarehouseRow[] sample = live.Where(row => row.Merkez > 0).Take(SampleSize).ToArray();
        Population.AtLeast(sample.Length, "canlı WMS alan 0+1'de stoğu olan ürün yok");

        // GetUrunOzetAsync ayar servisini kullanmaz; null verilerek panel veritabanına dokunulmaz.
        SatinalmaQueries queries = new(LiveDb.PanelDb(), NullLogger<SatinalmaQueries>.Instance, null!);

        // Act
        var summaries = await Task.WhenAll(sample.Select(row => queries.GetUrunOzetAsync(row.StkId)));

        // Assert
        Assert.All(summaries, summary => Assert.NotNull(summary));
        Assert.Equal(
            sample.Select(row => row.Merkez).ToArray(),
            summaries.Select(summary => summary!.DepoStok).ToArray());
    }
}
