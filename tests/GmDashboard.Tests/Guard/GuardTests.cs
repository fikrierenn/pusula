using Bkm.TestAltyapi;
using GmDashboard.Data;
using GmDashboard.Models;

namespace GmDashboard.Tests.Guard;

// SC-006: panel düzeltmeleri mağaza neti ile e-ticaret ana cirosunu (Eylül 2026) DEĞİŞTİRMEMELİ.
// Eski formül T-020'nin dondurulmuş SQL kopyası, yeni formül panelin kendisi (Queries.GetPeriodAsync).
// Canlı ERP + JOKER'e bağlanır: mesai dışında koşar. "Tur=Canli" birim süzgecinden (Tur!=Canli) dışlar.
public class GuardTests
{
    private const int StoreFsm = 1;
    private const int StoreOzluce = 4477;
    private const int StoreIstYolu = 4478;

    private sealed record OldStoreRow(int MekanId, decimal Net, int Fis, decimal Iade);

    private sealed record OldEcommerceRow(int Sip, decimal Ciro);

    [Fact]
    [Trait("Tur", "Canli")]
    [Trait("Tur", "Koruma")]
    [Trait("AC", "001-SC-006")]
    public async Task Guard_September2026_OldAndNewFormulaEqual()
    {
        // Arrange
        DateOnly start = new(2026, 9, 1);
        DateOnly endExcl = new(2026, 10, 1);
        string oldStoreSql = ReadOld("magaza-net-eski.sql");
        string oldEticSql = ReadOld("etic-ana-eski.sql");

        // Act: eski formül (dondurulmuş SQL) ve yeni formül (panel) ardışık okunur.
        IReadOnlyList<OldStoreRow> oldStores = await LiveDb.QueryAsync<OldStoreRow>(
            DbTarget.Erp,
            oldStoreSql,
            new { start = start.ToDateTime(TimeOnly.MinValue), end = endExcl.ToDateTime(TimeOnly.MinValue) });
        IReadOnlyList<OldEcommerceRow> oldEtic = await LiveDb.QueryAsync<OldEcommerceRow>(
            DbTarget.Joker,
            oldEticSql,
            new { giso = start.ToString("yyyyMMdd"), g2iso = endExcl.ToString("yyyyMMdd") });
        PeriodSummary panel = await new Queries(LiveDb.PanelDb()).GetPeriodAsync(start, endExcl);

        // Assert: nüfus önce, "boş = eşit" yanılgısı olmasın.
        Population.AtLeast(oldStores.Count(r => r.MekanId is StoreFsm or StoreOzluce or StoreIstYolu), "eski SQL üç mağaza satırı döndürmeli");
        Assert.Equal(3, oldStores.Count(r => r.MekanId is StoreFsm or StoreOzluce or StoreIstYolu));
        Population.AtLeast(oldEtic.Single().Sip, "e-ticaret sipariş sayısı > 0 olmalı");

        AssertStoreNet(oldStores, panel, StoreFsm, "FSM");
        AssertStoreNet(oldStores, panel, StoreOzluce, "Özlüce");
        AssertStoreNet(oldStores, panel, StoreIstYolu, "İst.Yolu");
        Tolerance.AmountEqual(panel.Eticaret, oldEtic.Single().Ciro, "e-ticaret ana ciro");
        Assert.Equal(oldEtic.Single().Sip, panel.ESip);
    }

    private static void AssertStoreNet(IReadOnlyList<OldStoreRow> oldStores, PeriodSummary panel, int mekanId, string label)
    {
        decimal oldNet = oldStores.Single(r => r.MekanId == mekanId).Net;
        decimal panelNet = panel.Stores.Single(s => s.MekanId == mekanId).Net;
        Tolerance.AmountEqual(panelNet, oldNet, $"mağaza net {label}");
    }

    private static string ReadOld(string fileName)
    {
        return File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "Koruma", "Eski", fileName));
    }
}
