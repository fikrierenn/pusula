using Bkm.TestAltyapi;
using GmDashboard.Tests.Altyapi;
using Xunit.Sdk;

namespace GmDashboard.Tests.Infrastructure;

// Tutar ve oran toleransı (T-023): tam sınır geçer, sınırın bir adım ötesi KALIR. Birim testidir; Trait'siz.
public class ToleranceTests
{
    public static TheoryData<decimal, decimal> AmountWithin => new()
    {
        { 100.00m, 100.00m },
        { 101.00m, 100.00m },
        { 99.00m, 100.00m },
        { 100.004m, 100.00m },
        { 1.00m, 0m },
        { -500.00m, -500.50m },
    };

    public static TheoryData<decimal, decimal> AmountOutside => new()
    {
        { 101.01m, 100.00m },
        { 98.99m, 100.00m },
        { 1.01m, 0m },
        { 128097715.43m, 128097709.99m },
        { -500.00m, 500.00m },
    };

    public static TheoryData<decimal, decimal> RatioWithinLimit => new()
    {
        { 1000m, 1000m },
        { 1003m, 1000m },
        { 997m, 1000m },
        { 0m, 0m },
        { -1003m, -1000m },
    };

    public static TheoryData<decimal, decimal> RatioOutsideLimit => new()
    {
        { 1003.01m, 1000m },
        { 996.99m, 1000m },
        { 0.01m, 0m },
        { -5m, 0m },
        { -1003.01m, -1000m },
        { 1000m, -1000m },
        { 1.50m, 1.00m },
    };

    [Fact]
    public void Tolerance_Constants_MatchContract()
    {
        Assert.Equal(1.00m, Tolerance.Amount);
        Assert.Equal(0.003m, Tolerance.Ratio);
    }

    [Theory]
    [MemberData(nameof(AmountWithin))]
    public void Tolerance_AmountEqual_WithinBoundaryPasses(decimal panel, decimal canonical)
    {
        Tolerance.AmountEqual(panel, canonical, "sinir");
    }

    [Theory]
    [MemberData(nameof(AmountOutside))]
    public void Tolerance_AmountEqual_OutsideBoundaryFails(decimal panel, decimal canonical)
    {
        Assert.ThrowsAny<XunitException>(() => Tolerance.AmountEqual(panel, canonical, "sinir"));
    }

    [Fact]
    public void Tolerance_AmountEqual_ByOneHundredthOverFails()
    {
        Assert.ThrowsAny<XunitException>(() => Tolerance.AmountEqual(101.01m, 100.00m, "ciro"));
    }

    [Fact]
    public void Tolerance_AmountEqual_MessageHasLabelValuesAndDifferenceInTurkishFormat()
    {
        using CultureScope scope = new("en-US");

        XunitException ex = Assert.ThrowsAny<XunitException>(() => Tolerance.AmountEqual(2234.56m, 1000.00m, "H06 ciro"));

        Assert.Contains("H06 ciro", ex.Message, StringComparison.Ordinal);
        Assert.Contains("2.234,56", ex.Message, StringComparison.Ordinal);
        Assert.Contains("1.000,00", ex.Message, StringComparison.Ordinal);
        Assert.Contains("1.234,56", ex.Message, StringComparison.Ordinal);
    }

    [Theory]
    [MemberData(nameof(RatioWithinLimit))]
    public void Tolerance_RatioWithin_WithinLimitPasses(decimal panel, decimal canonical)
    {
        Tolerance.RatioWithin(panel, canonical, "oran");
    }

    [Theory]
    [MemberData(nameof(RatioOutsideLimit))]
    public void Tolerance_RatioWithin_OutsideLimitFails(decimal panel, decimal canonical)
    {
        Assert.ThrowsAny<XunitException>(() => Tolerance.RatioWithin(panel, canonical, "oran"));
    }

    [Fact]
    public void Tolerance_RatioWithin_ZeroCanonicalDoesNotDivide()
    {
        Exception? ex = Record.Exception(() => Tolerance.RatioWithin(0.01m, 0m, "sifir"));

        Assert.IsNotType<DivideByZeroException>(ex);
        Assert.IsAssignableFrom<XunitException>(ex);
    }

    [Fact]
    public void Tolerance_RatioWithin_MessageHasLabelAndBothValues()
    {
        using CultureScope scope = new("en-US");

        XunitException ex = Assert.ThrowsAny<XunitException>(() => Tolerance.RatioWithin(1500.00m, 1000.00m, "kalem oranı"));

        Assert.Contains("kalem oranı", ex.Message, StringComparison.Ordinal);
        Assert.Contains("1.500,00", ex.Message, StringComparison.Ordinal);
        Assert.Contains("1.000,00", ex.Message, StringComparison.Ordinal);
    }
}
