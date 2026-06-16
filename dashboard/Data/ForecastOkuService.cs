using System.Text.Json;
using GmDashboard.Models;

namespace GmDashboard.Data;

/// <summary>
/// Tahmin motoru (scripts/forecast/, plan-15) çıktısını okur — SADECE GÖSTERİM.
/// Kaynak: {ContentRoot}/data/forecast/*.json (Python motoru oraya yazar).
/// Motor çalışmadıysa/JSON yoksa null döner → çağıran C# heuristiğe fallback + uyarı (sessiz değil).
/// </summary>
public sealed class ForecastOkuService(IHostEnvironment env, ILogger<ForecastOkuService> log)
{
    private static readonly JsonSerializerOptions _opt = new() { PropertyNameCaseInsensitive = true };
    private string Dir => Path.Combine(env.ContentRootPath, "data", "forecast");

    public ForecastCikti? Aylik() => Oku<ForecastCikti>("tahmin-aylik.json");
    public ForecastAgirlik? Agirlik() => Oku<ForecastAgirlik>("yontem-agirlik.json");

    /// <summary>Seçilen ay için motor tahmini (yoksa null → fallback).</summary>
    public ForecastAy? Ay(int yil, int ay) =>
        Aylik()?.Aylar.FirstOrDefault(a => a.Yil == yil && a.Ay == ay);

    private T? Oku<T>(string ad) where T : class
    {
        var path = Path.Combine(Dir, ad);
        try
        {
            if (!File.Exists(path)) return null;
            return JsonSerializer.Deserialize<T>(File.ReadAllText(path), _opt);
        }
        catch (Exception ex)
        {
            log.LogError(ex, "Tahmin motoru çıktısı okunamadı ({Path}) — fallback", path);
            return null;
        }
    }
}
