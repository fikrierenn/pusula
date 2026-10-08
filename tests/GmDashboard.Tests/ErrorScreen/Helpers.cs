using Bkm.TestAltyapi;
using Microsoft.Extensions.Logging;

namespace GmDashboard.Tests.ErrorScreen;

internal static class EnvironmentNames
{
    public const string EnvVariable = "BKM_ENV_DOSYA";
}

/// <summary>Geçici bir dosya; Dispose'ta silinir.</summary>
internal sealed class TempFile : IDisposable
{
    public TempFile(string content)
    {
        Path = System.IO.Path.Combine(System.IO.Path.GetTempPath(), "gmd-test-" + Guid.NewGuid().ToString("N") + ".env");
        File.WriteAllText(Path, content);
    }

    public string Path { get; }

    public void Dispose()
    {
        File.Delete(Path);
    }
}

internal static class RepoLocator
{
    public static string RepoRoot()
    {
        DirectoryInfo? dir = new(AppContext.BaseDirectory);
        while (dir is not null && !File.Exists(System.IO.Path.Combine(dir.FullName, "CLAUDE.md")))
        {
            dir = dir.Parent;
        }

        return dir?.FullName ?? throw new InvalidOperationException("KOŞAMADI: repo kökü (CLAUDE.md) bulunamadı");
    }
}

/// <summary>Zamanı elle ilerletilen TimeProvider (yeni paket gerektirmez).</summary>
internal sealed class ManualTimeProvider : TimeProvider
{
    private DateTimeOffset _now;

    public ManualTimeProvider(DateTimeOffset start)
    {
        _now = start;
    }

    public void Advance(TimeSpan by)
    {
        _now += by;
    }

    public override DateTimeOffset GetUtcNow()
    {
        return _now;
    }
}

/// <summary>Eşzamanlılık testlerinin döngüleri burada (testlerde döngü yok).</summary>
internal static class LoggerLoad
{
    public static void WriteMany(ILogger logger, int count)
    {
        for (int i = 0; i < count; i++)
        {
            logger.LogInformation("kayit {Index}", i);
        }
    }

    /// <summary>İptal edilene dek Entries'i numaralandırır; her anlık görüntü öncekinden küçük olmamalı.</summary>
    public static (int Reads, bool Monotonic) ReadUntilCancelled(MemoryLoggerProvider provider, CancellationToken stop)
    {
        int reads = 0;
        int previous = 0;
        bool monotonic = true;
        do
        {
            int count = provider.Entries.Count(e => e.Level == LogLevel.Information);
            monotonic &= count >= previous;
            previous = count;
            reads++;
        }
        while (!stop.IsCancellationRequested);

        return (reads, monotonic);
    }

    /// <summary>Dışarıdan değiştirme denemesi; değiştirilebildiyse true.</summary>
    public static bool TryMutate(IReadOnlyList<LogEntry> entries)
    {
        if (entries is not IList<LogEntry> list || list.IsReadOnly)
        {
            return false;
        }

        try
        {
            list.Clear();
            return true;
        }
        catch (NotSupportedException)
        {
            return false;
        }
    }
}
