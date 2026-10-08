using Microsoft.Extensions.Logging;

namespace Bkm.TestAltyapi;

/// <summary>Bellek günlüğüne düşen tek kayıt.</summary>
public sealed record LogEntry(LogLevel Level, string Category, string Message, Exception? Exception, DateTimeOffset Timestamp);
