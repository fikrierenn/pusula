using System.Diagnostics;

namespace GmDashboard.Data;

/// <summary>Forecast motorunu (scripts/forecast/run.py) portaldan tetikler (B-109).
/// Python kalır (statsforecast AutoARIMA/ETS C#'ta yok); dashboard sadece çalıştırır.
/// Çıktı dashboard/data/forecast/*.json → ForecastOkuService okur. Sabit komut (injection yok), auth'lu sayfa.</summary>
public sealed class ForecastService(ILogger<ForecastService> log)
{
    private static readonly string? _dir = BulForecastDir();

    public bool Available => _dir is not null;

    /// <summary>python run.py çalıştır (cwd=scripts/forecast). Bitince çıktı JSON güncel. Max 10 dk.</summary>
    public async Task<(bool Ok, string Mesaj, int Saniye)> RunAsync()
    {
        if (_dir is null) return (false, "scripts/forecast bulunamadı", 0);
        var sw = Stopwatch.StartNew();
        try
        {
            var psi = new ProcessStartInfo
            {
                FileName = "python",
                Arguments = "run.py",
                WorkingDirectory = _dir,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                CreateNoWindow = true,
            };
            using var p = Process.Start(psi) ?? throw new InvalidOperationException("python süreci başlatılamadı");
            using var cts = new CancellationTokenSource(TimeSpan.FromMinutes(10));
            var stdout = p.StandardOutput.ReadToEndAsync(cts.Token);
            var stderr = p.StandardError.ReadToEndAsync(cts.Token);
            await p.WaitForExitAsync(cts.Token);
            sw.Stop();
            var sn = (int)sw.Elapsed.TotalSeconds;
            if (p.ExitCode == 0)
            {
                log.LogInformation("Forecast çalıştı: {Sn}s", sn);
                return (true, $"Tahmin güncellendi ({sn} sn)", sn);
            }
            var err = (await stderr).Trim();
            log.LogError("Forecast hata (exit {Code}): {Err}", p.ExitCode, err.Length > 500 ? err[^500..] : err);
            return (false, $"Hata (kod {p.ExitCode}) — {(err.Length > 0 ? err[^Math.Min(160, err.Length)..] : "çıktı yok")}", sn);
        }
        catch (OperationCanceledException)
        {
            log.LogError("Forecast 10 dk zaman aşımı");
            return (false, "Zaman aşımı (10 dk)", (int)sw.Elapsed.TotalSeconds);
        }
        catch (Exception ex)
        {
            log.LogError(ex, "Forecast tetikleme hatası");
            return (false, $"Tetiklenemedi: {ex.Message}", (int)sw.Elapsed.TotalSeconds);
        }
    }

    // Repo kökü scripts/forecast/run.py'ı bul (AppContext.BaseDirectory'den yukarı).
    private static string? BulForecastDir()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null)
        {
            var cand = Path.Combine(dir.FullName, "scripts", "forecast", "run.py");
            if (File.Exists(cand)) return Path.GetDirectoryName(cand);
            dir = dir.Parent;
        }
        return null;
    }
}
