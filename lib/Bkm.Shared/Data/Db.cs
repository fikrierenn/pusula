using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Microsoft.Data.SqlClient;

namespace Bkm.Shared.Data;

/// <summary>
/// Dapper bağlantı fabrikası. Secret tek kaynaktan: repo kökü .env (Python gm_dashboard.py ile aynı).
/// .env gitignore'lu — connection string asla koda/appsettings'e gömülmez (security-principles.md).
/// </summary>
public sealed class Db
{
    private readonly string _connStr;
    private readonly string? _jokerConnStr;
    private readonly string? _zirveConnStr;
    private readonly string? _panelConnStr;
    private readonly ILogger<Db> _logger;

    public Db(IConfiguration config, ILogger<Db> logger)
    {
        _logger = logger;
        var env = LoadEnv();
        var host = env.GetValueOrDefault("MSSQL_HOST") ?? throw new InvalidOperationException(".env içinde MSSQL_HOST yok");
        var port = env.GetValueOrDefault("MSSQL_PORT");
        var user = env.GetValueOrDefault("MSSQL_USER") ?? "sa";
        var pass = env.GetValueOrDefault("MSSQL_PASSWORD") ?? "";
        var dbName = env.GetValueOrDefault("MSSQL_DATABASE") ?? "master";
        var trusted = env.GetValueOrDefault("MSSQL_TRUSTED");

        var dataSource = string.IsNullOrWhiteSpace(port) ? host : $"{host},{port}";
        var b = new SqlConnectionStringBuilder
        {
            DataSource = dataSource,
            InitialCatalog = dbName,
            TrustServerCertificate = true,
            ConnectTimeout = 20,
            CommandTimeout = 240,
            // DMY garantisi LOGIN'de veriliyor — fazladan round-trip YOK (B-168, 09.09.2026).
            // Eskiden her OpenAsync() ayrı komut olarak "SET DATEFORMAT dmy;" çalıştırıyordu.
            // ÖLÇÜLDÜ: o SET bir NO-OP'tu — login 'sa' varsayılan dili zaten 'Türkçe'
            // (sys.server_principals.default_language_name), @@LANGUAGE='Türkçe' ve
            // sys.syslanguages'a göre Türkçe dateformat = dmy. SET'siz CONVERT(date,'13.06.2026')
            // doğru parse ediyor. Ama sunucu/login varsayılanına SESSİZCE güvenmek kırılgan:
            // Current Language ile aynı garanti açıkça ve BEDELSİZ veriliyor (login sırasında).
            // Maliyet ölçümü: DB'ye RTT ort 30 ms / min 16 ms; drill sayfası 9 bağlantı açıyordu
            // → 9 gereksiz gidiş-dönüş ≈ 225 ms. App'te 135 db.OpenAsync() çağrısı var.
            CurrentLanguage = "Turkish",
        };
        if (string.Equals(trusted, "true", StringComparison.OrdinalIgnoreCase))
        {
            b.IntegratedSecurity = true;
        }
        else
        {
            b.UserID = user;
            b.Password = pass;
        }
        _connStr = b.ConnectionString;

        // ZIRVE bordro/İK DB direkt bağlantı (plan-38 yol B). Linked server [ZIRVE] remote login
        // 'kutlama' İK objelerinde yetkisiz (02.09.2026 test: SELECT denied) → OPENQUERY kullanılamıyor.
        // SALT-OKUMA: bu bağlantıyla yalnız SELECT yapılır (erp-write-policy.md — Zirve yazma YASAK).
        var zHost = env.GetValueOrDefault("ZIRVE_HOST");
        if (!string.IsNullOrWhiteSpace(zHost) && !string.IsNullOrWhiteSpace(env.GetValueOrDefault("ZIRVE_PASSWORD")))
        {
            var zPort = env.GetValueOrDefault("ZIRVE_PORT");
            var zb = new SqlConnectionStringBuilder
            {
                DataSource = string.IsNullOrWhiteSpace(zPort) ? zHost : $"{zHost},{zPort}",
                InitialCatalog = env.GetValueOrDefault("ZIRVE_DATABASE") ?? "BKM_GENEL",
                UserID = env.GetValueOrDefault("ZIRVE_USER") ?? user,
                Password = env.GetValueOrDefault("ZIRVE_PASSWORD") ?? pass,
                TrustServerCertificate = true,
                ConnectTimeout = 20,
                CommandTimeout = 120,
            };
            _zirveConnStr = zb.ConnectionString;
        }

        // JOKER e-ticaret DB direkt bağlantı (linked server ODAKJOKER yerine — B-74 perf).
        // User/pass JOKER_* yoksa MSSQL_* ile aynı (Fikri teyit: aynı sa).
        var jHost = env.GetValueOrDefault("JOKER_HOST");
        if (!string.IsNullOrWhiteSpace(jHost))
        {
            var jPort = env.GetValueOrDefault("JOKER_PORT");
            var jb = new SqlConnectionStringBuilder
            {
                DataSource = string.IsNullOrWhiteSpace(jPort) ? jHost : $"{jHost},{jPort}",
                InitialCatalog = env.GetValueOrDefault("JOKER_DATABASE") ?? "JOKER",
                UserID = env.GetValueOrDefault("JOKER_USER") ?? user,
                Password = env.GetValueOrDefault("JOKER_PASSWORD") ?? pass,
                TrustServerCertificate = true,
                ConnectTimeout = 20,
                CommandTimeout = 240,
            };
            _jokerConnStr = jb.ConnectionString;
        }

        // Panel auth DB (localhost, Windows auth) — B-84. .env'de PANEL_DB_HOST yoksa auth devre dışı.
        var pHost = env.GetValueOrDefault("PANEL_DB_HOST");
        if (!string.IsNullOrWhiteSpace(pHost))
        {
            var pb = new SqlConnectionStringBuilder
            {
                DataSource = pHost,
                InitialCatalog = env.GetValueOrDefault("PANEL_DB_NAME") ?? "BkmPanel",
                TrustServerCertificate = true,
                ConnectTimeout = 10,
                CommandTimeout = 30,
            };
            if (string.Equals(env.GetValueOrDefault("PANEL_DB_TRUSTED"), "true", StringComparison.OrdinalIgnoreCase))
                pb.IntegratedSecurity = true;
            else { pb.UserID = env.GetValueOrDefault("PANEL_DB_USER") ?? "sa"; pb.Password = env.GetValueOrDefault("PANEL_DB_PASSWORD") ?? ""; }
            _panelConnStr = pb.ConnectionString;
        }
    }

    /// <summary>Panel auth DB bağlantısı (localhost BkmPanel). .env'de PANEL_DB_HOST yoksa null → auth kapalı.</summary>
    public Task<SqlConnection>? OpenPanelAsync() =>
        _panelConnStr is null ? null : OpenWithRetryAsync(_panelConnStr);

    /// <summary>Panel DB senkron bağlantı (auth + app-state servisleri — localhost, hızlı, retry'sız).</summary>
    public SqlConnection OpenPanel()
    {
        if (_panelConnStr is null) throw new InvalidOperationException(".env PANEL_DB_HOST yok — panel DB yapılandırılmamış.");
        var conn = new SqlConnection(_panelConnStr);
        conn.Open();
        return conn;
    }

    public bool PanelEnabled => _panelConnStr is not null;

    /// <summary>
    /// Panel DB bağlantı dizesi — Solum.Identity <c>SolumIdentityOptions</c> için.
    /// Solum kendi bağlantısını açar (Dapper), bizim fabrikamızı kullanmaz; o yüzden
    /// dizenin kendisi gerekiyor.
    /// ⚠ Yalnız yapılandırma anında okunur. Loglanmaz, ekrana basılmaz, dışarı verilmez
    /// (<c>security-principles.md</c>: sır tek kaynakta, .env).
    /// </summary>
    public string PanelConnectionString =>
        _panelConnStr ?? throw new InvalidOperationException(
            ".env PANEL_DB_HOST yok — panel DB yapılandırılmamış; kimlik deposu kurulamaz.");

    /// <summary>
    /// Her çağrıda yeni açık bağlantı (Dapper using ile kapatır).
    /// DMY, bağlantı dizesindeki <c>Current Language=Turkish</c> ile LOGIN'de sağlanır —
    /// ayrıca <c>SET DATEFORMAT</c> komutu GÖNDERİLMEZ (B-168: gereksiz round-trip'ti).
    /// </summary>
    public Task<SqlConnection> OpenAsync() => OpenWithRetryAsync(_connStr);

    /// <summary>Zirve bordro/İK yapılandırıldı mı (.env ZIRVE_HOST + ZIRVE_PASSWORD).</summary>
    public bool ZirveEnabled => _zirveConnStr is not null;

    /// <summary>Zirve (BKM_GENEL) İK DB'ye direkt bağlantı — SALT-OKUMA. .env'de ZIRVE_HOST/PASSWORD yoksa hata.</summary>
    public Task<SqlConnection> OpenZirveAsync()
    {
        if (_zirveConnStr is null)
            throw new InvalidOperationException(
                ".env içinde ZIRVE_HOST / ZIRVE_PASSWORD yok — Zirve İK bağlantısı yapılandırılmamış (plan-38).");
        return OpenWithRetryAsync(_zirveConnStr);  // Zirve SQL2008; tarihler ISO literal ile verilir.
    }

    /// <summary>JOKER e-ticaret DB'ye direkt bağlantı (linked server ODAKJOKER yerine). .env'de JOKER_HOST yoksa hata.</summary>
    public Task<SqlConnection> OpenJokerAsync()
    {
        if (_jokerConnStr is null)
            throw new InvalidOperationException(".env içinde JOKER_HOST yok — direkt JOKER bağlantısı yapılandırılmamış.");
        return OpenWithRetryAsync(_jokerConnStr);  // JOKER ISO YYYYMMDD — DATEFORMAT gerekmez.
    }

    // Bağlantı açma + transient hatada retry (plan-12 WS-5). DMY login'de (Current Language).
    // Server restart / ağ blip = baskın transient (SignalR-drop senaryosu). max 2 retry + backoff.
    // Fatal (syntax/izin) veya tükenmiş transient → exception PROPAGATE (çağıranın catch'i banner gösterir; sessiz değil).
    private async Task<SqlConnection> OpenWithRetryAsync(string connStr)
    {
        const int maxRetry = 2;
        for (int attempt = 0; ; attempt++)
        {
            SqlConnection? conn = null;
            try
            {
                conn = new SqlConnection(connStr);
                await conn.OpenAsync();
                // SET DATEFORMAT YOK: DMY artık bağlantı dizesindeki Current Language ile
                // login'de geliyor (B-168). Eski hali her bağlantıda fazladan bir round-trip'ti.
                return conn;
            }
            catch (Exception ex) when (attempt < maxRetry && SqlErrorClassifier.ShouldRetry(ex))
            {
                conn?.Dispose();
                var delayMs = 300 * (attempt + 1);   // 300ms, 600ms backoff
                _logger.LogWarning(ex, "Transient SQL bağlantı hatası (deneme {Attempt}/{Max}) — {Delay}ms sonra retry", attempt + 1, maxRetry + 1, delayMs);
                await Task.Delay(delayMs);
            }
            catch
            {
                conn?.Dispose();
                throw;   // fatal veya tükenmiş transient → yukarı
            }
        }
    }

    /// <summary>Repo kökü .env'i bul + parse (Python cfg() ile birebir kaynak).</summary>
    /// <summary>.env'i dışarıdan okumak için (GeminiProvider GEMINI_API_KEY — plan-20).</summary>
    public static Dictionary<string, string> LoadEnvStatic() => LoadEnv();

    private static Dictionary<string, string> LoadEnv()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null && !File.Exists(Path.Combine(dir.FullName, ".env")))
            dir = dir.Parent;
        var path = dir is null ? null : Path.Combine(dir.FullName, ".env");

        var map = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        if (path is null || !File.Exists(path)) return map;
        foreach (var raw in File.ReadAllLines(path))
        {
            var line = raw.Trim();
            if (line.Length == 0 || line.StartsWith('#') || !line.Contains('=')) continue;
            var i = line.IndexOf('=');
            var key = line[..i].Trim();
            var val = line[(i + 1)..].Trim().Trim('"');
            if (val.Length > 0) map[key] = val;
        }
        return map;
    }
}
