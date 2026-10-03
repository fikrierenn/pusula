using System.Diagnostics;
using System.Text;

namespace GmDashboard.Data;

/// <summary>
/// Ay sonu Stok-Satış raporunu panelden SIFIRDAN üretir: scripts/stok_satis_aylik_wide.py --ay=YYYY-MM.
/// Mantık tek yerde (python script) kalsın diye C#'a port edilmedi — panel yalnız tetikler ve izler.
/// Singleton: sayfadan çıkınca üretim sürer; aynı anda tek üretim (rapor ~10 dk, DB'ye ağır).
/// Çıktı script tarafından raporlar/ay-sonu-stok-satis/ arşivine kopyalanır → AySonuStokArsiv listeler.
/// </summary>
public sealed class AySonuStokUretici(IWebHostEnvironment env, ILogger<AySonuStokUretici> logger)
{
    private readonly object _kilit = new();
    private readonly List<string> _log = [];

    public bool Calisiyor { get; private set; }
    public string? Ay { get; private set; }
    public DateTime? Baslangic { get; private set; }
    public bool? Basarili { get; private set; }

    /// <summary>Durum değişince (log satırı, bitiş) tetiklenir — sayfa StateHasChanged için dinler.</summary>
    public event Action? Degisti;

    public IReadOnlyList<string> Log { get { lock (_kilit) return _log.ToList(); } }

    /// <summary>Üretimi başlatır. Başka üretim sürüyorsa ya da ay geçersizse hata metni döner.</summary>
    public string? Baslat(string ay)
    {
        if (!AySonuStokArsiv.GecerliAy(ay)) return "Geçersiz ay.";
        lock (_kilit)
        {
            if (Calisiyor) return $"{AySonuStokArsiv.AyAdi(Ay!)} üretimi sürüyor; bitmesini bekleyin.";
            Calisiyor = true; Ay = ay; Baslangic = DateTime.Now; Basarili = null;
            _log.Clear();
        }
        Degisti?.Invoke();
        _ = Task.Run(() => CalistirAsync(ay));
        return null;
    }

    private async Task CalistirAsync(string ay)
    {
        var kok = Path.GetFullPath(Path.Combine(env.ContentRootPath, ".."));
        var psi = new ProcessStartInfo("python")
        {
            WorkingDirectory = kok,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true,
            StandardOutputEncoding = Encoding.UTF8,
            StandardErrorEncoding = Encoding.UTF8,
        };
        psi.ArgumentList.Add(Path.Combine("scripts", "stok_satis_aylik_wide.py"));
        psi.ArgumentList.Add($"--ay={ay}");
        psi.Environment["PYTHONUTF8"] = "1";
        psi.Environment["PYTHONIOENCODING"] = "utf-8";

        var ok = false;
        try
        {
            using var p = new Process { StartInfo = psi };
            p.OutputDataReceived += (_, e) => { if (e.Data is not null) Ekle(e.Data); };
            p.ErrorDataReceived += (_, e) => { if (e.Data is not null) Ekle(e.Data); };
            p.Start();
            p.BeginOutputReadLine();
            p.BeginErrorReadLine();
            await p.WaitForExitAsync();
            ok = p.ExitCode == 0 && AySonuStokArsiv.Bul(env.ContentRootPath, ay) is not null;
            if (!ok) Ekle($"Script çıkış kodu {p.ExitCode}.");
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Ay sonu stok raporu üretilemedi ({Ay})", ay);
            Ekle("Hata: " + ex.Message);
        }
        finally
        {
            lock (_kilit) { Calisiyor = false; Basarili = ok; }
            Degisti?.Invoke();
        }
    }

    private void Ekle(string satir)
    {
        lock (_kilit) _log.Add(satir);
        Degisti?.Invoke();
    }
}
