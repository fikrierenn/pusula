using System.Text.Json;
using GmDashboard.Models;

namespace GmDashboard.Data;

/// <summary>
/// Kaydedilmiş tahmin deposu (plan-14). JSON dosya: data/tahmin-kayitlari.json.
/// Tek kullanıcı (CFO) → DB/migration yerine düz JSON. Upsert anahtarı: Year+Month+MekanId.
/// Hata sessiz yutulmaz (error-handling.md): log + güvenli boş liste fallback.
/// </summary>
public sealed class TahminKayitService(ILogger<TahminKayitService> log)
{
    private static readonly string _path = Path.Combine(AppContext.BaseDirectory, "data", "tahmin-kayitlari.json");
    private static readonly JsonSerializerOptions _opt = new() { WriteIndented = true };
    private readonly object _kilit = new();

    public IReadOnlyList<TahminKayitEntry> Yukle()
    {
        lock (_kilit) return YukleIc();
    }

    private List<TahminKayitEntry> YukleIc()
    {
        try
        {
            if (!File.Exists(_path)) return new();
            var json = File.ReadAllText(_path);
            return JsonSerializer.Deserialize<List<TahminKayitEntry>>(json) ?? new();
        }
        catch (Exception ex)
        {
            log.LogError(ex, "Tahmin kayıtları okunamadı ({Path}) — boş liste ile devam", _path);
            return new();
        }
    }

    /// <summary>Year+Month+MekanId aynı kayıt varsa üzerine yazar, yoksa ekler. Başarı = true.</summary>
    public bool Kaydet(TahminKayitEntry entry)
    {
        lock (_kilit)
        {
            var liste = YukleIc();
            liste.RemoveAll(e => e.Year == entry.Year && e.Month == entry.Month && e.MekanId == entry.MekanId);
            liste.Add(entry);
            return Yaz(liste);
        }
    }

    public bool Sil(string id)
    {
        lock (_kilit)
        {
            var liste = YukleIc();
            if (liste.RemoveAll(e => e.Id == id) == 0) return false;
            return Yaz(liste);
        }
    }

    private bool Yaz(List<TahminKayitEntry> liste)
    {
        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(_path)!);
            File.WriteAllText(_path, JsonSerializer.Serialize(liste, _opt));
            return true;
        }
        catch (Exception ex)
        {
            log.LogError(ex, "Tahmin kayıtları yazılamadı ({Path})", _path);
            return false;
        }
    }
}
