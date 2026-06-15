using System.Diagnostics;

namespace GmDashboard.Data;

/// <summary>
/// Sayfa veri-yükleme süresi paylaşılan durumu (scoped → circuit başına). Her sayfa load'unu
/// Track(...) ile sarar, biten süreyi MainLayout footer'ı okur. Tek global gösterge, sayfa tekrarı yok.
/// </summary>
public sealed class PerfState
{
    public string LastPage { get; private set; } = "";
    public long LastMs { get; private set; }
    public event Action? Changed;

    /// <summary>Yeni süre ölçer başlat (sayfa load başında). Dönen Stopwatch'i finally'de Report'a ver.</summary>
    public static Stopwatch Start() => Stopwatch.StartNew();

    /// <summary>Ölçülen süreyi kaydet + footer'ı tazele (sayfa load finally'sinde).</summary>
    public void Report(string page, Stopwatch sw)
    {
        sw.Stop();
        LastPage = page;
        LastMs = sw.ElapsedMilliseconds;
        Changed?.Invoke();
    }
}
