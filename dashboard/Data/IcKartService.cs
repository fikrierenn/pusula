using System.Text.Json;
using GmDashboard.Models;

namespace GmDashboard.Data;

/// <summary>
/// Elle işaretlenmiş iç/mağaza kartları (plan-16 ek). data/ic-kartlar.json.
/// CustomersId (EncoreMerkez/DerinCrm) listesi → RFM + sadakat + müşteri cirosundan hariç.
/// Otomatik desen filtresi (isim %Mağaza%/%Kumbara%, tel 599/699) YETMEZ → kullanıcı tıkla-işaretle.
/// Geri alınabilir (Sil). Hata sessiz yutulmaz (error-handling.md).
/// </summary>
public sealed class IcKartService(ILogger<IcKartService> log)
{
    private static readonly string _path = Path.Combine(AppContext.BaseDirectory, "data", "ic-kartlar.json");
    private static readonly JsonSerializerOptions _opt = new() { WriteIndented = true };
    private readonly object _kilit = new();

    public IReadOnlyList<IcKart> Yukle() { lock (_kilit) return YukleIc(); }

    /// <summary>SQL filtresi için işaretli CustomersId dizisi (boşsa boş dizi → çağıran NOT IN eklemez).</summary>
    public long[] Idler() { lock (_kilit) return YukleIc().Select(k => k.Id).ToArray(); }

    private List<IcKart> YukleIc()
    {
        try
        {
            if (!File.Exists(_path)) return new();
            return JsonSerializer.Deserialize<List<IcKart>>(File.ReadAllText(_path)) ?? new();
        }
        catch (Exception ex)
        {
            log.LogError(ex, "İç kart listesi okunamadı ({Path}) — boş ile devam", _path);
            return new();
        }
    }

    public bool Ekle(long id, string ad)
    {
        lock (_kilit)
        {
            var liste = YukleIc();
            if (liste.Any(k => k.Id == id)) return true;  // zaten var
            liste.Add(new IcKart(id, ad, DateTime.Now.ToString("dd.MM.yyyy HH:mm")));
            return Yaz(liste);
        }
    }

    public bool Sil(long id)
    {
        lock (_kilit)
        {
            var liste = YukleIc();
            if (liste.RemoveAll(k => k.Id == id) == 0) return false;
            return Yaz(liste);
        }
    }

    private bool Yaz(List<IcKart> liste)
    {
        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(_path)!);
            File.WriteAllText(_path, JsonSerializer.Serialize(liste, _opt));
            return true;
        }
        catch (Exception ex)
        {
            log.LogError(ex, "İç kart listesi yazılamadı ({Path})", _path);
            return false;
        }
    }
}
