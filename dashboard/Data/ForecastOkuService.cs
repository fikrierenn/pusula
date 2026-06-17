using System.Text.Json;
using Dapper;
using GmDashboard.Models;

namespace GmDashboard.Data;

/// <summary>
/// Tahmin motoru (scripts/forecast/, plan-15) çıktısını okur — SADECE GÖSTERİM.
/// Kaynak: localhost Express BkmPanel.dbo.PanelForecast (Python run.py pyodbc ile yazar; JSON string, B-109).
/// Motor çalışmadıysa/kayıt yoksa null → çağıran C# heuristiğe fallback + uyarı (sessiz değil).
/// </summary>
public sealed class ForecastOkuService
{
    private static readonly JsonSerializerOptions _opt = new() { PropertyNameCaseInsensitive = true };
    private readonly Db _db;
    private readonly ILogger<ForecastOkuService> _log;

    public ForecastOkuService(Db db, ILogger<ForecastOkuService> log)
    {
        _db = db; _log = log;
        if (!db.PanelEnabled) { log.LogWarning("Panel DB kapalı — forecast çıktısı okunamaz"); return; }
        try
        {
            using var c = db.OpenPanel();
            c.Execute("""
                IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name='PanelForecast')
                CREATE TABLE dbo.PanelForecast (Ad nvarchar(40) PRIMARY KEY, Json nvarchar(max) NOT NULL, Uretim datetime2 NOT NULL DEFAULT SYSUTCDATETIME());
                """);
        }
        catch (Exception ex) { log.LogError(ex, "PanelForecast tablo oluşturma hatası"); }
    }

    public ForecastCikti? Aylik() => Oku<ForecastCikti>("tahmin-aylik");
    public ForecastAgirlik? Agirlik() => Oku<ForecastAgirlik>("yontem-agirlik");

    /// <summary>Seçilen ay için motor tahmini (yoksa null → fallback).</summary>
    public ForecastAy? Ay(int yil, int ay) =>
        Aylik()?.Aylar.FirstOrDefault(a => a.Yil == yil && a.Ay == ay);

    private T? Oku<T>(string ad) where T : class
    {
        if (!_db.PanelEnabled) return null;
        try
        {
            using var c = _db.OpenPanel();
            var json = c.ExecuteScalar<string?>("SELECT Json FROM dbo.PanelForecast WHERE Ad=@ad", new { ad });
            return json is null ? null : JsonSerializer.Deserialize<T>(json, _opt);
        }
        catch (Exception ex)
        {
            _log.LogError(ex, "Tahmin motoru çıktısı okunamadı (Ad {Ad}) — fallback", ad);
            return null;
        }
    }
}
