using GmDashboard.Models;

namespace GmDashboard.Data;

/// <summary>
/// Bildirim merkezi paylaşılan durumu (scoped → circuit başına). Home dönem verisinden uyarıları üretir,
/// MainLayout'taki global zil bunları okur/açar. Böylece zil + CFO tek global header'da, sayfa tekrarı yok.
/// </summary>
public sealed class NotifState
{
    public IReadOnlyList<AlertItem> Alerts { get; private set; } = Array.Empty<AlertItem>();
    public string Context { get; private set; } = "";   // ör. dönem aralığı ("13.06.2026")

    public event Action? Changed;

    public void Set(IReadOnlyList<AlertItem> alerts, string context)
    {
        Alerts = alerts;
        Context = context;
        Changed?.Invoke();
    }
}
