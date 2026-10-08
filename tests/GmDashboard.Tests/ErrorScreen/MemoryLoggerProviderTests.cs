using Bkm.TestAltyapi;
using Microsoft.Extensions.Logging;

namespace GmDashboard.Tests.ErrorScreen;

// MemoryLoggerProvider / LogEntry sözleşmesi (senaryo S36-S47; kararlar K4, K5). Fabrika gerektirmez.
public class MemoryLoggerProviderTests
{
    private static readonly DateTimeOffset s_start = new(2026, 10, 8, 9, 30, 0, TimeSpan.Zero);

    [Fact]
    [Trait("AC", "001-AC-10.2")]
    public void Log_ErrorWithException_RecordsLevelCategoryMessageAndSameException()
    {
        using MemoryLoggerProvider provider = new();
        ILogger logger = provider.CreateLogger("A");
        InvalidOperationException error = new("boom");

        logger.LogError(error, "x");

        LogEntry entry = Assert.Single(provider.Entries);
        Assert.Equal(LogLevel.Error, entry.Level);
        Assert.Equal("A", entry.Category);
        Assert.Equal("x", entry.Message);
        Assert.Same(error, entry.Exception);
    }

    [Fact]
    [Trait("AC", "001-AC-10.2")]
    public void Log_InformationWithoutException_RecordsNullException()
    {
        using MemoryLoggerProvider provider = new();
        ILogger logger = provider.CreateLogger("A");

        logger.LogInformation("y");

        LogEntry entry = Assert.Single(provider.Entries);
        Assert.Null(entry.Exception);
        Assert.Equal(LogLevel.Information, entry.Level);
    }

    [Fact]
    [Trait("AC", "001-AC-10.2")]
    public void Log_TemplateWithArgument_RecordsFormattedMessage()
    {
        using MemoryLoggerProvider provider = new();
        ILogger logger = provider.CreateLogger("A");

        logger.LogError("{Ekran} veri yükleme hatası", "Sabah");

        Assert.Equal("Sabah veri yükleme hatası", Assert.Single(provider.Entries).Message);
    }

    [Fact]
    [Trait("AC", "001-AC-10.2")]
    public void Log_WithInjectedClock_RecordsTimestampFromTimeProvider()
    {
        ManualTimeProvider clock = new(s_start);
        using MemoryLoggerProvider provider = new(clock);
        ILogger logger = provider.CreateLogger("A");

        logger.LogInformation("birinci");
        clock.Advance(TimeSpan.FromMinutes(5));
        logger.LogInformation("ikinci");

        Assert.Equal(s_start, provider.Entries[0].Timestamp);
        Assert.Equal(s_start.AddMinutes(5), provider.Entries[1].Timestamp);
    }

    [Fact]
    [Trait("AC", "001-AC-10.2")]
    public void Log_WithoutInjectedClock_RecordsRealTimestamp()
    {
        DateTimeOffset before = TimeProvider.System.GetUtcNow();
        using MemoryLoggerProvider provider = new();

        provider.CreateLogger("A").LogInformation("z");

        DateTimeOffset stamp = Assert.Single(provider.Entries).Timestamp;
        Assert.InRange(stamp, before, TimeProvider.System.GetUtcNow());
    }

    [Fact]
    [Trait("AC", "001-AC-10.2")]
    public void Entries_HundredSequentialLogs_KeepWriteOrder()
    {
        using MemoryLoggerProvider provider = new();
        ILogger logger = provider.CreateLogger("A");
        int[] expected = Enumerable.Range(1, 100).ToArray();

        foreach (int i in expected)
        {
            logger.LogInformation("{N}", i);
        }

        Assert.Equal(expected.Select(i => i.ToString(System.Globalization.CultureInfo.InvariantCulture)), provider.Entries.Select(e => e.Message));
    }

    [Fact]
    [Trait("AC", "001-AC-10.2")]
    public async Task Log_ConcurrentWriters_LoseAndDuplicateNothing()
    {
        using MemoryLoggerProvider provider = new();
        ILogger logger = provider.CreateLogger("A");

        Task[] writers = Enumerable.Range(0, 8)
            .Select(_ => Task.Run(() => LoggerLoad.WriteMany(logger, 1000)))
            .ToArray();
        await Task.WhenAll(writers);

        Assert.Equal(8000, provider.Entries.Count);
        Assert.All(writers, w => Assert.True(w.IsCompletedSuccessfully));
    }

    [Fact]
    [Trait("AC", "001-AC-10.2")]
    public async Task Entries_ReadWhileWriting_NeverThrowsAndNeverShrinks()
    {
        using MemoryLoggerProvider provider = new();
        ILogger logger = provider.CreateLogger("A");
        using CancellationTokenSource stop = new();

        Task<(int Reads, bool Monotonic)> reader = Task.Run(() => LoggerLoad.ReadUntilCancelled(provider, stop.Token));
        Task[] writers = Enumerable.Range(0, 4)
            .Select(_ => Task.Run(() => LoggerLoad.WriteMany(logger, 2000)))
            .ToArray();
        await Task.WhenAll(writers);
        await stop.CancelAsync();
        (int reads, bool monotonic) = await reader;

        Assert.True(reads >= 1);
        Assert.True(monotonic);
        Assert.Equal(8000, provider.Entries.Count);
    }

    [Fact]
    [Trait("AC", "001-AC-10.2")]
    public void Entries_ReturnedSnapshot_IsNotAffectedByLaterWritesOrMutation()
    {
        using MemoryLoggerProvider provider = new();
        ILogger logger = provider.CreateLogger("A");
        logger.LogInformation("1");
        logger.LogInformation("2");
        logger.LogInformation("3");
        IReadOnlyList<LogEntry> snapshot = provider.Entries;

        bool mutated = LoggerLoad.TryMutate(snapshot);
        logger.LogInformation("4");

        Assert.False(mutated);
        Assert.Equal(3, snapshot.Count);
        Assert.Equal(4, provider.Entries.Count);
    }

    [Fact]
    [Trait("AC", "001-AC-10.2")]
    public void Log_TwoLoggersFromOneProvider_KeepOwnCategories()
    {
        using MemoryLoggerProvider provider = new();

        provider.CreateLogger("A").LogInformation("a");
        provider.CreateLogger("B").LogInformation("b");

        Assert.Equal(["A", "B"], provider.Entries.Select(e => e.Category));
        Assert.Equal(["a", "b"], provider.Entries.Select(e => e.Message));
    }

    [Fact]
    [Trait("AC", "001-AC-10.2")]
    public void Log_AfterProviderDisposed_DoesNotThrowAndKeepsEarlierEntries()
    {
        MemoryLoggerProvider provider = new();
        ILogger logger = provider.CreateLogger("A");
        logger.LogInformation("once");
        provider.Dispose();

        Exception? ex = Record.Exception(() => logger.LogError("sonra"));

        Assert.Null(ex);
        Assert.Contains(provider.Entries, e => e.Message == "once");
    }

    [Fact]
    [Trait("AC", "001-AC-10.2")]
    public void BeginScope_Anywhere_DoesNotThrowAndAddsNoEntry()
    {
        using MemoryLoggerProvider provider = new();
        ILogger logger = provider.CreateLogger("A");

        Exception? ex = Record.Exception(() =>
        {
            using IDisposable? scope = logger.BeginScope("s");
        });

        Assert.Null(ex);
        Assert.Empty(provider.Entries);
    }

    [Theory]
    [InlineData(LogLevel.Trace)]
    [InlineData(LogLevel.Debug)]
    [InlineData(LogLevel.Information)]
    [InlineData(LogLevel.Warning)]
    [InlineData(LogLevel.Error)]
    [InlineData(LogLevel.Critical)]
    [Trait("AC", "001-AC-10.2")]
    public void Log_EveryLevelExceptNone_IsEnabledAndRecorded(LogLevel level)
    {
        using MemoryLoggerProvider provider = new();
        ILogger logger = provider.CreateLogger("A");

        logger.Log(level, "m");

        Assert.True(logger.IsEnabled(level));
        Assert.Equal(level, Assert.Single(provider.Entries).Level);
    }

    [Fact]
    [Trait("AC", "001-AC-10.2")]
    public void Log_LevelNone_IsDisabledAndNotRecorded()
    {
        using MemoryLoggerProvider provider = new();
        ILogger logger = provider.CreateLogger("A");

        logger.Log(LogLevel.None, "m");

        Assert.False(logger.IsEnabled(LogLevel.None));
        Assert.Empty(provider.Entries);
    }

    [Fact]
    [Trait("AC", "001-AC-10.2")]
    public void Entries_TwoProviderInstances_ShareNothing()
    {
        using MemoryLoggerProvider first = new();
        using MemoryLoggerProvider second = new();

        first.CreateLogger("A").LogInformation("yalnız birinci");

        Assert.Single(first.Entries);
        Assert.Empty(second.Entries);
    }
}
