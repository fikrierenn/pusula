using System.Globalization;
using System.Text.Json;
using System.Text.Json.Serialization;
using Dapper;
using GmDashboard.Models;
using Microsoft.Data.SqlClient;

namespace GmDashboard.Data;

/// <summary>
/// Takvim etmen servisi (plan-14, B-108). İki kaynak:
///  1. Ulusal+dini+arife tatil → Apps Script API, localhost Express BkmPanel.dbo.PanelTakvim (yılda 1 Yenile).
///     DB'de tutulur → görev/brief/tahmin sorgulayabilir (örn. görev son tarihi tatile denk mi).
///  2. Okul dönem + sınav → data/okul-takvimi.json (elle, MEB takvimi — dönem aralığı, ayrı yapı).
/// Tahmin daima DB'den okur — canlı API bağımlılığı YOK (kişisel script, kaybolabilir).
/// </summary>
public sealed class TakvimService
{
    private const string ApiUrl = "https://script.google.com/macros/s/AKfycbzVHms-rNzPCAXTWQkqJncuHBhcaW9Yhx4vY_njRhkmQY3fdgmrcIyjCqyttkkcjEvo/exec";
    private static readonly string _okulPath = Path.Combine(AppContext.BaseDirectory, "data", "okul-takvimi.json");
    private static readonly JsonSerializerOptions _opt = new() { Converters = { new JsonStringEnumConverter() } };

    private readonly IHttpClientFactory _http;
    private readonly Db _db;
    private readonly ILogger<TakvimService> _log;

    public TakvimService(IHttpClientFactory http, Db db, ILogger<TakvimService> log)
    {
        _http = http; _db = db; _log = log;
        if (!db.PanelEnabled) { log.LogWarning("Panel DB kapalı — takvim devre dışı"); return; }
        try
        {
            using var c = db.OpenPanel();
            c.Execute("""
                IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name='PanelTakvim')
                CREATE TABLE dbo.PanelTakvim (
                    Tarih date PRIMARY KEY, Ad nvarchar(120) NOT NULL, Tip nvarchar(20) NOT NULL, YarimGun bit NOT NULL);
                IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name='PanelOkulDonem')
                CREATE TABLE dbo.PanelOkulDonem (Id int IDENTITY(1,1) PRIMARY KEY, Bas date NOT NULL, Son date NOT NULL);
                """);
            SeedOkulIfEmpty(c);  // ilk açılış: okul-takvimi.json → DB (boşsa)
        }
        catch (Exception ex) { log.LogError(ex, "Panel takvim tablo oluşturma/seed hatası"); }
    }

    /// <summary>İlk açılış migration — okul-takvimi.json içeriğini DB'ye yükle (tablo boşsa). JSON seed kaynağı olarak kalır.</summary>
    private void SeedOkulIfEmpty(SqlConnection c)
    {
        if (!File.Exists(_okulPath)) return;
        var donemBos = c.ExecuteScalar<int>("SELECT COUNT(*) FROM dbo.PanelOkulDonem") == 0;
        var sinavBos = c.ExecuteScalar<int>("SELECT COUNT(*) FROM dbo.PanelTakvim WHERE Tip=N'Sinav'") == 0;
        if (!donemBos && !sinavBos) return;
        OkulTakvim j;
        try { j = JsonSerializer.Deserialize<OkulTakvim>(File.ReadAllText(_okulPath), _opt) ?? new(); }
        catch (Exception ex) { _log.LogError(ex, "okul-takvimi.json seed parse hatası"); return; }
        if (donemBos && j.Donemler.Count > 0)
            c.Execute("INSERT INTO dbo.PanelOkulDonem (Bas, Son) VALUES (@Bas, @Son)", j.Donemler);
        if (sinavBos && j.Sinavlar.Count > 0)
            c.Execute("INSERT INTO dbo.PanelTakvim (Tarih, Ad, Tip, YarimGun) VALUES (@Tarih, @Ad, N'Sinav', 0)",
                j.Sinavlar.Select(s => new { s.Tarih, s.Ad }));
        _log.LogInformation("Okul takvimi seed edildi: {D} dönem, {S} sınav", j.Donemler.Count, j.Sinavlar.Count);
    }

    // ---- Tatil (DB) ----

    /// <summary>PanelTakvim tatil günleri (ulusal+dini+arife). Yoksa boş — etmen nötr (çarpan 1.0).</summary>
    public IReadOnlyList<TakvimGun> TatilGunleri()
    {
        if (!_db.PanelEnabled) return [];
        try
        {
            using var c = _db.OpenPanel();
            return c.Query<TakvimGun>("SELECT Tarih, Ad, Tip, YarimGun FROM dbo.PanelTakvim ORDER BY Tarih").ToList();
        }
        catch (Exception ex) { _log.LogError(ex, "Takvim DB okunamadı — boş ile devam"); return []; }
    }

    public bool CacheVar
    {
        get
        {
            if (!_db.PanelEnabled) return false;
            try { using var c = _db.OpenPanel(); return c.ExecuteScalar<int>("SELECT COUNT(*) FROM dbo.PanelTakvim") > 0; }
            catch { return false; }
        }
    }

    /// <summary>API'den çek, gürültü temizle, PanelTakvim'e yaz (DELETE+INSERT). Başarısızsa eski veri korunur (false).</summary>
    public async Task<bool> ApidenYenileAsync()
    {
        if (!_db.PanelEnabled) return false;
        try
        {
            var http = _http.CreateClient();
            http.Timeout = TimeSpan.FromSeconds(15);
            var json = await http.GetStringAsync(ApiUrl);
            var ham = JsonSerializer.Deserialize<List<ApiKayit>>(json) ?? throw new InvalidDataException("API boş/çözümlenemez yanıt");

            var temiz = new List<TakvimGun>();
            var gorulen = new HashSet<DateOnly>();
            int elenenGurultu = 0, elenenParse = 0;
            foreach (var k in ham)
            {
                if (k.title.Contains("Feast", StringComparison.OrdinalIgnoreCase)) { elenenGurultu++; continue; }
                if (!DateOnly.TryParseExact(k.localeDateString, "dd.MM.yyyy", CultureInfo.InvariantCulture, DateTimeStyles.None, out var tarih)) { elenenParse++; continue; }
                if (!gorulen.Add(tarih)) continue;

                bool dini = k.title.Contains("Ramazan", StringComparison.OrdinalIgnoreCase) ||
                            k.title.Contains("Kurban", StringComparison.OrdinalIgnoreCase);
                bool yarim = k.title.Contains("Arife", StringComparison.OrdinalIgnoreCase) ||
                             k.title.Contains("yarım", StringComparison.OrdinalIgnoreCase);
                temiz.Add(new TakvimGun(tarih, k.title, dini ? TakvimTip.DiniBayram : TakvimTip.Ulusal, yarim));
            }
            if (temiz.Count == 0) throw new InvalidDataException("Temizleme sonrası 0 kayıt — yazma iptal");
            if (elenenGurultu > 0 || elenenParse > 0)
                _log.LogWarning("Takvim API temizleme: {Gurultu} gürültü, {Parse} parse-hatası elendi ({Kalan} tutuldu)", elenenGurultu, elenenParse, temiz.Count);

            using var c = _db.OpenPanel();
            c.Execute("DELETE FROM dbo.PanelTakvim WHERE Tip IN (N'Ulusal', N'DiniBayram')");  // okul tipleri korunur
            c.Execute("INSERT INTO dbo.PanelTakvim (Tarih, Ad, Tip, YarimGun) VALUES (@Tarih, @Ad, @Tip, @YarimGun)",
                temiz.Select(t => new { t.Tarih, t.Ad, Tip = t.Tip.ToString(), t.YarimGun }));
            _log.LogInformation("PanelTakvim güncellendi: {N} gün", temiz.Count);
            return true;
        }
        catch (Exception ex)
        {
            _log.LogError(ex, "Takvim API yenileme başarısız — eski veri korunuyor");
            return false;
        }
    }

    // ---- Okul (DB: PanelOkulDonem + PanelTakvim Tip=Sinav) ----

    private OkulTakvim Okul()
    {
        if (!_db.PanelEnabled) return new();
        try
        {
            using var c = _db.OpenPanel();
            var t = new OkulTakvim
            {
                Donemler = c.Query<OkulDonemDto>("SELECT Bas, Son FROM dbo.PanelOkulDonem").ToList(),
                Sinavlar = c.Query<TakvimGun>("SELECT Tarih, Ad, Tip, YarimGun FROM dbo.PanelTakvim WHERE Tip=N'Sinav'")
                    .Select(s => new OkulSinavDto { Ad = s.Ad, Tarih = s.Tarih }).ToList(),
            };
            return t;
        }
        catch (Exception ex)
        {
            _log.LogError(ex, "Okul takvimi DB okunamadı — boş ile devam");
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
        // Clamp [0.7,1.3]: yanlış sınıflandırma/gürültü absürt çarpan üretirse tahmini patlatmasın (loglu).
        decimal bayramHam = Math.Round(1m - (decimal)(diniBu - diniGY) / ayGun, 4);
        decimal bayramCarpan = Math.Clamp(bayramHam, 0.7m, 1.3m);
        if (bayramCarpan != bayramHam)
            _log.LogWarning("Bayram çarpanı clamp edildi {Yil}-{Ay}: {Ham} → {Son} (diniBu={B}, diniGY={G})", yil, ay, bayramHam, bayramCarpan, diniBu, diniGY);

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
