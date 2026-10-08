using Microsoft.Extensions.Logging;

namespace Bkm.TestAltyapi;

/// <summary>Günlük kayıtlarını bellekte toplar; testler bunları okur.</summary>
public sealed class MemoryLoggerProvider : ILoggerProvider
{
    public IReadOnlyList<LogEntry> Entries => throw new NotImplementedException();

    public ILogger CreateLogger(string categoryName)
    {
        throw new NotImplementedException();
    }

    public void Dispose()
    {
        throw new NotImplementedException();
    }
}
