using System.Text.Json;
using GmDashboard.Models;

namespace GmDashboard.Data;

/// <summary>
/// İç-kart hariç tutma — TEK kanonik SQL predicate (plan-18). Tüm müşteri sorguları bunu kullanır.
/// İsim (Mağaza/Kumbara) + telefon (599/699 = geçersiz mobil prefix, iç/dummy kart) + elle işaretli liste (@icIds).
/// Customer JOIN GEREKTİRMEZ: NOT IN alt-sorgu → her alias'ta çalışır. Çağıran @icIds param geçer (hasIcIds=true ise).
/// </summary>
public static class IcKartFiltre
{
    /// <param name="custCol">CustomersId kolon ifadesi — alias'lı ("s.CustomersId") veya çıplak ("CustomersId").</param>
    /// <param name="hasIcIds">Elle işaretli liste varsa @icIds NOT IN ekle (çağıran @icIds param geçer).</param>
    public static string Sql(string custCol, bool hasIcIds) =>
        $" AND {custCol} NOT IN (SELECT Id FROM DerinCrm.dbo.Customer WITH(NOLOCK)"
        + " WHERE Name LIKE N'%Mağaza%' COLLATE Turkish_CI_AS OR Name LIKE N'%Kumbara%' COLLATE Turkish_CI_AS"
        + " OR ISNULL(PhoneNumber,'') LIKE '599%' OR ISNULL(PhoneNumber,'') LIKE '699%')"
        + (hasIcIds ? $" AND {custCol} NOT IN @icIds" : "");

    /// <summary>
    /// Aggregate CASE içi varyant (SUM(CASE WHEN...)) — SQL aggregate içinde subquery YASAKLAR.
    /// Customer JOIN gerektirir (c alias). Aynı tanım: isim (Mağaza/Kumbara) + tel (599/699) + elle liste.
    /// </summary>
    /// <param name="c">DerinCrm.Customer alias.</param><param name="s">Sales alias.</param>
    public static string SqlCols(string c, string s, bool hasIcIds) =>
        $" AND ({c}.Id IS NULL OR ({c}.Name NOT LIKE N'%Mağaza%' COLLATE Turkish_CI_AS AND {c}.Name NOT LIKE N'%Kumbara%' COLLATE Turkish_CI_AS"
        + $" AND ISNULL({c}.PhoneNumber,'') NOT LIKE '599%' AND ISNULL({c}.PhoneNumber,'') NOT LIKE '699%'))"
        + (hasIcIds ? $" AND {s}.CustomersId NOT IN @icIds" : "");
}

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
