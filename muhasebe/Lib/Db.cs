using System.Data;
using System.Text.RegularExpressions;
using Microsoft.Data.SqlClient;

namespace Muhasebe.Lib;

/// <summary>
/// Dapper bağlantı fabrikası — SALT-OKUMA ERP (DerinSISBkm). Secret tek kaynaktan: repo kökü .env
/// (dashboard/gm_dashboard.py ile aynı MSSQL_* anahtarları). Connection string koda/appsettings'e gömülmez.
/// Bu app ERP'ye YAZMAZ (erp-write-policy) — yalnız okur + öneri üretir.
/// </summary>
public sealed class Db
{
    private readonly string _connStr;

    public Db()
    {
        var env = LoadEnv();
        var host = env.GetValueOrDefault("MSSQL_HOST") ?? throw new InvalidOperationException(".env içinde MSSQL_HOST yok");
        var port = env.GetValueOrDefault("MSSQL_PORT");
        // Host/port whitelist (injection — coding-discipline)
        if (!Regex.IsMatch(host, @"^[A-Za-z0-9._\-\\]+$"))
            throw new InvalidOperationException("Geçersiz MSSQL_HOST");
        var b = new SqlConnectionStringBuilder
        {
            DataSource = string.IsNullOrWhiteSpace(port) ? host : $"{host},{port}",
            InitialCatalog = "DerinSISBkm",   // doğrudan ERP DB — 2-parçalı isim yeter
            TrustServerCertificate = true,
            ConnectTimeout = 20,
            CommandTimeout = 300,
        };
        if (string.Equals(env.GetValueOrDefault("MSSQL_TRUSTED"), "true", StringComparison.OrdinalIgnoreCase))
            b.IntegratedSecurity = true;
        else { b.UserID = env.GetValueOrDefault("MSSQL_USER") ?? "sa"; b.Password = env.GetValueOrDefault("MSSQL_PASSWORD") ?? ""; }
        _connStr = b.ConnectionString;
    }

    /// <summary>Senkron açık bağlantı (Dapper).</summary>
    public IDbConnection Open()
    {
        var cn = new SqlConnection(_connStr);
        cn.Open();
        return cn;
    }

    /// <summary>Async açık bağlantı (ham reader — büyük tarama).</summary>
    public async Task<SqlConnection> OpenAsync()
    {
        var cn = new SqlConnection(_connStr);
        await cn.OpenAsync();
        return cn;
    }

    /// <summary>Repo kökü .env'i bul (content root'tan yukarı) + parse.</summary>
    private static Dictionary<string, string> LoadEnv()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null && !File.Exists(Path.Combine(dir.FullName, ".env")))
            dir = dir.Parent;
        var map = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        if (dir is null) return map;
        foreach (var raw in File.ReadAllLines(Path.Combine(dir.FullName, ".env")))
        {
            var line = raw.Trim();
            if (line.Length == 0 || line.StartsWith('#') || !line.Contains('=')) continue;
            var i = line.IndexOf('=');
            var val = line[(i + 1)..].Trim().Trim('"');
            if (val.Length > 0) map[line[..i].Trim()] = val;
        }
        return map;
    }
}
