using System.Globalization;
using System.Text.Json;
using System.Text.Json.Serialization;
using GmDashboard.Models;

namespace GmDashboard.Data;

/// <summary>
/// Takvim etmen servisi (plan-14). İki kaynak:
///  1. Ulusal+dini+arife tatil → Apps Script API, data/takvim-cache.json'a önbellek (yılda 1 Yenile).
///  2. Okul dönem + sınav → data/okul-takvimi.json (elle, MEB takvimi).
/// Tahmin daima cache/dosyadan okur — canlı API bağımlılığı YOK (kişisel script, kaybolabilir).
/// Etmen çarpanları deterministik; sessiz hata yutulmaz (error-handling.md).
/// </summary>
public sealed class TakvimService(IHttpClientFactory httpFactory, ILogger<TakvimService> log)
{
    // Apps Script — DMY localeDateString + epoch date. Dini bayram + arife dahil (Nager.Date'te yok).
    private const string ApiUrl = "https://script.google.com/macros/s/AKfycbzVHms-rNzPCAXTWQkqJncuHBhcaW9Yhx4vY_njRhkmQY3fdgmrcIyjCqyttkkcjEvo/exec";
    private static readonly string _cachePath = Path.Combine(AppContext.BaseDirectory, "data", "takvim-cache.json");
    private static readonly string _okulPath = Path.Combine(AppContext.BaseDirectory, "data", "okul-takvimi.json");
    private static readonly JsonSerializerOptions _opt = new() { WriteIndented = true, Converters = { new JsonStringEnumConverter() } };

    // ---- Tatil (cache) ----

    /// <summary>Önbellekteki tatil günleri (ulusal+dini+arife). Yoksa boş — etmen nötr (çarpan 1.0).</summary>
    public IReadOnlyList<TakvimGun> TatilGunleri()
    {
        try
        {
            if (!File.Exists(_cachePath)) return [];
            return JsonSerializer.Deserialize<List<TakvimGun>>(File.ReadAllText(_cachePath), _opt) ?? [];
        }
        catch (Exception ex)
        {
            log.LogError(ex, "Takvim cache okunamadı ({Path}) — boş ile devam", _cachePath);
            return [];
        }
    }

    public bool CacheVar => File.Exists(_cachePath);

    /// <summary>API'den çek, gürültü temizle, cache'e yaz. Başarısızsa eski cache korunur (false döner).</summary>
    public async Task<bool> ApidenYenileAsync()
    {
        try
        {
            var http = httpFactory.CreateClient();
            http.Timeout = TimeSpan.FromSeconds(15);
            var json = await http.GetStringAsync(ApiUrl);
            var ham = JsonSerializer.Deserialize<List<ApiKayit>>(json) ?? throw new InvalidDataException("API boş/çözümlenemez yanıt");

            var temiz = new List<TakvimGun>();
            var gorulen = new HashSet<DateOnly>();   // tarih bazlı dedup
            foreach (var k in ham)
            {
                // Gürültü filtresi: İngilizce artık kayıtlar ("Sacrifice Feast Holiday") — gerçek başlıklar "Bayramı" içerir.
                if (k.title.Contains("Feast", StringComparison.OrdinalIgnoreCase) ||
                    k.title.Contains("Holiday", StringComparison.OrdinalIgnoreCase)) continue;
                if (!DateOnly.TryParseExact(k.localeDateString, "dd.MM.yyyy", CultureInfo.InvariantCulture, DateTimeStyles.None, out var tarih)) continue;
                if (!gorulen.Add(tarih)) continue;

                bool dini = k.title.Contains("Ramazan", StringComparison.OrdinalIgnoreCase) ||
                            k.title.Contains("Kurban", StringComparison.OrdinalIgnoreCase);
                bool yarim = k.title.Contains("Arife", StringComparison.OrdinalIgnoreCase) ||
                             k.title.Contains("yarım", StringComparison.OrdinalIgnoreCase);
                temiz.Add(new TakvimGun(tarih, k.title, dini ? TakvimTip.DiniBayram : TakvimTip.Ulusal, yarim));
            }
            if (temiz.Count == 0) throw new InvalidDataException("Temizleme sonrası 0 kayıt — yazma iptal");

            Directory.CreateDirectory(Path.GetDirectoryName(_cachePath)!);
            File.WriteAllText(_cachePath, JsonSerializer.Serialize(temiz, _opt));
            log.LogInformation("Takvim cache güncellendi: {N} gün", temiz.Count);
            return true;
        }
        catch (Exception ex)
        {
            log.LogError(ex, "Takvim API yenileme başarısız — eski cache korunuyor");
            return false;
        }
    }

    // ---- Okul (elle JSON) ----

    private OkulTakvim Okul()
    {
        try
        {
            if (!File.Exists(_okulPath)) return new();
            return JsonSerializer.Deserialize<OkulTakvim>(File.ReadAllText(_okulPath), _opt) ?? new();
        }
        catch (Exception ex)
        {
            log.LogError(ex, "Okul takvimi okunamadı ({Path})", _okulPath);
            return new();
        }
    }

    // ---- Etmen hesabı ----

    /// <summary>Bir ay için takvim etmen özeti. Çarpanlar deterministik; veri yoksa 1.0 (nötr, güvenli).</summary>
    public AyEtmen GetAyEtmen(int yil, int ay)
    {
        int ayGun = DateTime.DaysInMonth(yil, ay);
        int htBu = HaftaSonuSay(yil, ay);
        int htGY = HaftaSonuSay(yil - 1, ay);
        decimal htCarpan = htGY > 0 ? Math.Round((decimal)htBu / htGY, 4) : 1m;

        var tatiller = TatilGunleri();
        int diniBu = DiniKapaliGun(tatiller, yil, ay);
        int diniGY = DiniKapaliGun(tatiller, yil - 1, ay);
        // YoY kayan bayram düzeltmesi: hedef ayda taban yıla göre fazla kapalı gün → tahmin düşür.
        decimal bayramCarpan = Math.Round(1m - (decimal)(diniBu - diniGY) / ayGun, 4);

        var okul = Okul();
        bool okulAcik = okul.Donemler.Any(d => d.Bas <= new DateOnly(yil, ay, ayGun) && d.Son >= new DateOnly(yil, ay, 1));
        bool sinavAyi = okul.Sinavlar.Any(s => s.Tarih.Year == yil && s.Tarih.Month == ay);

        return new AyEtmen(htBu, diniBu, okulAcik, sinavAyi, htCarpan, 1m, bayramCarpan);
    }

    private static int HaftaSonuSay(int yil, int ay)
    {
        int n = DateTime.DaysInMonth(yil, ay), say = 0;
        for (int g = 1; g <= n; g++)
        {
            var d = new DateTime(yil, ay, g).DayOfWeek;
            if (d is DayOfWeek.Saturday or DayOfWeek.Sunday) say++;
        }
        return say;
    }

    // Dini bayramın TAM günleri (arife yarım gün hariç) — gerçek mağaza kapanışı. Ulusal hariç (mağaza açık varsayımı).
    private static int DiniKapaliGun(IReadOnlyList<TakvimGun> tatiller, int yil, int ay) =>
        tatiller.Count(t => t.Tip == TakvimTip.DiniBayram && !t.YarimGun && t.Tarih.Year == yil && t.Tarih.Month == ay);

    // ---- JSON DTO'ları ----
    private sealed record ApiKayit(string title, long date, string localeDateString);

    private sealed class OkulTakvim
    {
        public List<OkulDonemDto> Donemler { get; set; } = [];
        public List<OkulSinavDto> Sinavlar { get; set; } = [];
    }
    private sealed class OkulDonemDto
    {
        [JsonConverter(typeof(DmyDateConverter))] public DateOnly Bas { get; set; }
        [JsonConverter(typeof(DmyDateConverter))] public DateOnly Son { get; set; }
    }
    private sealed class OkulSinavDto
    {
        public string Ad { get; set; } = "";
        [JsonConverter(typeof(DmyDateConverter))] public DateOnly Tarih { get; set; }
    }

    /// <summary>okul-takvimi.json "dd.MM.yyyy" (DMY — proje standardı) ↔ DateOnly.</summary>
    private sealed class DmyDateConverter : JsonConverter<DateOnly>
    {
        public override DateOnly Read(ref Utf8JsonReader r, Type t, JsonSerializerOptions o) =>
            DateOnly.ParseExact(r.GetString()!, "dd.MM.yyyy", CultureInfo.InvariantCulture);
        public override void Write(Utf8JsonWriter w, DateOnly v, JsonSerializerOptions o) =>
            w.WriteStringValue(v.ToString("dd.MM.yyyy", CultureInfo.InvariantCulture));
    }
}
