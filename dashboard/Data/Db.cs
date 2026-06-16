using Microsoft.Data.SqlClient;

namespace GmDashboard.Data;

/// <summary>
/// Dapper bağlantı fabrikası. Secret tek kaynaktan: repo kökü .env (Python gm_dashboard.py ile aynı).
/// .env gitignore'lu — connection string asla koda/appsettings'e gömülmez (security-principles.md).
/// </summary>
public sealed class Db
{
    private readonly string _connStr;
    private readonly string? _jokerConnStr;

    public Db(IConfiguration config)
    {
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
    }

    /// <summary>Her çağrıda yeni açık bağlantı (Dapper using ile kapatır). DMY zorunlu sorgular için SET DATEFORMAT dmy.</summary>
    public async Task<SqlConnection> OpenAsync()
    {
        var conn = new SqlConnection(_connStr);
        await conn.OpenAsync();
        using (var cmd = conn.CreateCommand())
        {
            cmd.CommandText = "SET DATEFORMAT dmy;";  // yerel DMY (sql-server-conventions.md)
            await cmd.ExecuteNonQueryAsync();
        }
        return conn;
    }

    /// <summary>JOKER e-ticaret DB'ye direkt bağlantı (linked server ODAKJOKER yerine). .env'de JOKER_HOST yoksa hata.</summary>
    public async Task<SqlConnection> OpenJokerAsync()
    {
        if (_jokerConnStr is null)
            throw new InvalidOperationException(".env içinde JOKER_HOST yok — direkt JOKER bağlantısı yapılandırılmamış.");
        var conn = new SqlConnection(_jokerConnStr);
        await conn.OpenAsync();
        return conn;   // JOKER tarih literalleri ISO YYYYMMDD — DATEFORMAT gerekmez.
    }

    /// <summary>Repo kökü .env'i bul + parse (Python cfg() ile birebir kaynak).</summary>
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
