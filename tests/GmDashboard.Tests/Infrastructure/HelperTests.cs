using Bkm.TestAltyapi;
using Xunit.Sdk;

namespace GmDashboard.Tests.Infrastructure;

// Nüfus kapısı ve sahte saat (T-023). Birim testidir; Trait'siz.
public class HelperTests
{
    private static readonly DateTimeOffset s_noon = new(2026, 10, 8, 10, 0, 0, TimeSpan.Zero);

    [Theory]
    [InlineData(1)]
    [InlineData(5401)]
    [InlineData(int.MaxValue)]
    public void Population_AtLeast_PositiveCountPasses(int n)
    {
        Population.AtLeast(n, "r");
    }

    [Fact]
    public void Population_AtLeast_ZeroGivesCouldNotRunMessage()
    {
        XunitException ex = Assert.ThrowsAny<XunitException>(() => Population.AtLeast(0, "son 90 gün satış"));

        Assert.Equal("KOŞAMADI: nüfus 0 — son 90 gün satış", ex.Message);
    }

    [Fact]
    public void Population_AtLeast_NegativeGivesCouldNotRunMessage()
    {
        XunitException ex = Assert.ThrowsAny<XunitException>(() => Population.AtLeast(-1, "r"));

        Assert.StartsWith("KOŞAMADI", ex.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void Population_AtLeast_ZeroIsNotAPassOrArgumentError()
    {
        Exception? ex = Record.Exception(() => Population.AtLeast(0, "r"));

        Assert.IsAssignableFrom<XunitException>(ex);
        Assert.IsNotAssignableFrom<ArgumentException>(ex);
        Assert.DoesNotContain("geçti", ex!.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void Population_AtLeast_EmptyReasonStillFailsWithPrefix()
    {
        XunitException ex = Assert.ThrowsAny<XunitException>(() => Population.AtLeast(0, string.Empty));

        Assert.StartsWith("KOŞAMADI: nüfus 0 — ", ex.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void FakeClock_GetUtcNow_ReturnsGivenInstant()
    {
        FakeClock clock = new(s_noon);

        Assert.Equal(s_noon, clock.GetUtcNow());
    }

    [Fact]
    public void FakeClock_GetLocalNow_ReturnsGivenInstant()
    {
        FakeClock clock = new(s_noon);

        DateTimeOffset local = clock.GetLocalNow();

        Assert.Equal(s_noon, local);
        Assert.Equal(TimeSpan.Zero, local.Offset);
    }

    [Fact]
    public void FakeClock_LocalTimeZone_IsUtc()
    {
        FakeClock clock = new(s_noon);

        Assert.Equal(TimeZoneInfo.Utc, clock.LocalTimeZone);
    }

    [Fact]
    public void FakeClock_OffsetInstant_NormalizesToUtc()
    {
        FakeClock clock = new(new DateTimeOffset(2026, 10, 8, 13, 0, 0, TimeSpan.FromHours(3)));

        DateTimeOffset utc = clock.GetUtcNow();

        Assert.Equal(s_noon, utc);
        Assert.Equal(TimeSpan.Zero, utc.Offset);
    }

    [Fact]
    public void FakeClock_OffsetInstant_LocalOffsetIsNotKept()
    {
        FakeClock clock = new(new DateTimeOffset(2026, 10, 8, 13, 0, 0, TimeSpan.FromHours(3)));

        DateTimeOffset local = clock.GetLocalNow();

        Assert.Equal(s_noon, local);
        Assert.Equal(TimeSpan.Zero, local.Offset);
    }

    [Fact]
    public void FakeClock_RepeatedCalls_NeverAdvance()
    {
        FakeClock clock = new(s_noon);

        DateTimeOffset first = clock.GetUtcNow();
        DateTimeOffset second = clock.GetUtcNow();

        Assert.Equal(first, second);
        Assert.Equal(s_noon, second);
    }

    [Fact]
    public void FakeClock_EndOfYearInstant_DoesNotRollDay()
    {
        FakeClock clock = new(new DateTimeOffset(2026, 12, 31, 23, 59, 59, TimeSpan.Zero).AddTicks(9999999));

        DateTimeOffset local = clock.GetLocalNow();

        Assert.Equal(new DateOnly(2026, 12, 31), DateOnly.FromDateTime(local.DateTime));
        Assert.Equal(TimeSpan.Zero, local.Offset);
    }

    [Fact]
    public void FakeClock_AsTimeProvider_ReturnsSameInstant()
    {
        TimeProvider provider = new FakeClock(s_noon);

        Assert.Equal(s_noon, provider.GetUtcNow());
    }
}
