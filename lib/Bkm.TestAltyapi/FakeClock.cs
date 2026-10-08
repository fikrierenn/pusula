namespace Bkm.TestAltyapi;

/// <summary>Sabit anı döndüren sahte saat.</summary>
public sealed class FakeClock(DateTimeOffset now) : TimeProvider
{
    private readonly DateTimeOffset _now = now;

    /// <inheritdoc />
    public override TimeZoneInfo LocalTimeZone => TimeZoneInfo.Utc;

    /// <inheritdoc />
    public override DateTimeOffset GetUtcNow()
    {
        throw new NotImplementedException();
    }
}
