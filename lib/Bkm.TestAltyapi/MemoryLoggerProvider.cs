using Microsoft.Extensions.Logging;

namespace Bkm.TestAltyapi;

/// <summary>Günlük kayıtlarını bellekte toplar; testler bunları okur.</summary>
public sealed class MemoryLoggerProvider : ILoggerProvider
{
    private readonly Lock _lock = new();
    private readonly List<LogEntry> _entries = [];
    private readonly TimeProvider _time;

    public MemoryLoggerProvider(TimeProvider? time = null)
    {
        _time = time ?? TimeProvider.System;
    }

    /// <summary>Anlık kopya döner; sonraki yazmalar ve dışarıdan değişiklik onu etkilemez.</summary>
    public IReadOnlyList<LogEntry> Entries
    {
        get
        {
            lock (_lock)
            {
                return _entries.ToArray().AsReadOnly();
            }
        }
    }

    public ILogger CreateLogger(string categoryName)
    {
        return new MemoryLogger(this, categoryName);
    }

    public void Dispose()
    {
        // Kayıtlar Dispose sonrası da okunabilir kalır; serbest bırakılacak kaynak yok.
    }

    private void Add(LogEntry entry)
    {
        lock (_lock)
        {
            _entries.Add(entry);
        }
    }

    private sealed class MemoryLogger : ILogger
    {
        private readonly MemoryLoggerProvider _owner;
        private readonly string _category;

        public MemoryLogger(MemoryLoggerProvider owner, string category)
        {
            _owner = owner;
            _category = category;
        }

        public IDisposable? BeginScope<TState>(TState state)
            where TState : notnull
        {
            return null;
        }

        public bool IsEnabled(LogLevel logLevel)
        {
            return logLevel != LogLevel.None;
        }

        public void Log<TState>(
            LogLevel logLevel,
            EventId eventId,
            TState state,
            Exception? exception,
            Func<TState, Exception?, string> formatter)
        {
            if (!IsEnabled(logLevel))
            {
                return;
            }

            ArgumentNullException.ThrowIfNull(formatter);
            _owner.Add(new LogEntry(logLevel, _category, formatter(state, exception), exception, _owner._time.GetUtcNow()));
        }
    }
}
