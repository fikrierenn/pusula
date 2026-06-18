using Google.Apis.Auth.OAuth2;
using Google.Apis.Auth.OAuth2.Flows;
using Google.Apis.Auth.OAuth2.Requests;
using Google.Apis.Calendar.v3;
using Google.Apis.Gmail.v1;
using Google.Apis.Json;
using Google.Apis.Util.Store;
using Dapper;

namespace GmDashboard.Data.Asistan;

/// <summary>
/// BKM-Asistan Faz-2 (plan-21) Google OAuth — tek kullanıcı (CFO). Refresh-token BkmPanel.PanelGoogleToken'da kalıcı.
/// Akış: /auth/google → consent → /auth/google/callback → token DB'ye. Sonra KimlikAsync() ile Calendar/Gmail çağrısı.
/// Secret .env (GOOGLE_CLIENT_ID/SECRET) — koda gömülmez.
/// </summary>
public sealed class GoogleAuthService
{
    public const string KullaniciId = "cfo";   // tek kullanıcı
    private static readonly string[] Scopes =
    [
        CalendarService.Scope.CalendarEvents,   // etkinlik oku/oluştur
        GmailService.Scope.GmailReadonly,        // gelen kutusu oku/özet
        GmailService.Scope.GmailSend,            // yanıt gönder (yalnız CFO onayıyla)
    ];

    private readonly string _redirect;
    private readonly GoogleAuthorizationCodeFlow? _flow;
    private readonly ILogger<GoogleAuthService> _log;

    public GoogleAuthService(Db db, ILogger<GoogleAuthService> log)
    {
        _log = log;
        var env = Db.LoadEnvStatic();
        var id = env.GetValueOrDefault("GOOGLE_CLIENT_ID");
        var secret = env.GetValueOrDefault("GOOGLE_CLIENT_SECRET");
        _redirect = env.GetValueOrDefault("GOOGLE_REDIRECT_URI") ?? "http://localhost:5112/auth/google/callback";
        if (string.IsNullOrWhiteSpace(id) || string.IsNullOrWhiteSpace(secret) || !db.PanelEnabled)
        {
            log.LogWarning("Google OAuth yapılandırılmamış (GOOGLE_CLIENT_ID/SECRET veya panel DB yok) — mail/takvim devre dışı");
            return;
        }
        _flow = new GoogleAuthorizationCodeFlow(new GoogleAuthorizationCodeFlow.Initializer
        {
            ClientSecrets = new ClientSecrets { ClientId = id, ClientSecret = secret },
            Scopes = Scopes,
            DataStore = new PanelTokenStore(db, log),
        });
    }

    /// <summary>OAuth yapılandırıldı mı (client id/secret + panel DB var).</summary>
    public bool Yapilandirilmis => _flow is not null;

    /// <summary>Token kayıtlı mı (CFO bir kez bağlandı mı).</summary>
    public async Task<bool> BagliMiAsync(CancellationToken ct = default)
    {
        if (_flow is null) return false;
        var t = await _flow.LoadTokenAsync(KullaniciId, ct);
        return t is not null && (t.RefreshToken is not null || t.AccessToken is not null);
    }

    /// <summary>Consent URL — kullanıcı "Bağlan" deyince buraya yönlendirilir (offline + consent → refresh-token garanti).</summary>
    public string AuthUrl()
    {
        if (_flow is null) throw new InvalidOperationException("Google OAuth yapılandırılmamış.");
        var req = (GoogleAuthorizationCodeRequestUrl)_flow.CreateAuthorizationCodeRequest(_redirect);
        req.AccessType = "offline";   // refresh-token al
        req.Prompt = "consent";        // her bağlanışta refresh-token yenile
        return req.Build().ToString();
    }

    /// <summary>Callback'teki code'u token'a çevirip DB'ye yazar.</summary>
    public async Task BaglantiBitirAsync(string code, CancellationToken ct = default)
    {
        if (_flow is null) throw new InvalidOperationException("Google OAuth yapılandırılmamış.");
        await _flow.ExchangeCodeForTokenAsync(KullaniciId, code, _redirect, ct);
        _log.LogInformation("Google OAuth token alındı (CFO bağlandı)");
    }

    /// <summary>Kayıtlı token'dan UserCredential üretir (access-token süresi dolmuşsa otomatik refresh). Yoksa null.</summary>
    public async Task<UserCredential?> KimlikAsync(CancellationToken ct = default)
    {
        if (_flow is null) return null;
        var token = await _flow.LoadTokenAsync(KullaniciId, ct);
        if (token is null) return null;
        return new UserCredential(_flow, KullaniciId, token);
    }

    /// <summary>Bağlantıyı kes (token sil).</summary>
    public async Task BaglantiKesAsync(CancellationToken ct = default)
    {
        if (_flow is null) return;
        await _flow.DeleteTokenAsync(KullaniciId, ct);
    }

    // ── DB-backed IDataStore: token JSON'unu BkmPanel.PanelGoogleToken'da tutar (tek satır/anahtar) ──
    private sealed class PanelTokenStore : IDataStore
    {
        private readonly Db _db;
        public PanelTokenStore(Db db, ILogger log)
        {
            _db = db;
            try
            {
                using var c = db.OpenPanel();
                c.Execute("""
                    IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name='PanelGoogleToken')
                    CREATE TABLE dbo.PanelGoogleToken (K nvarchar(255) PRIMARY KEY, V nvarchar(max) NOT NULL);
                    """);
            }
            catch (Exception ex) { log.LogError(ex, "PanelGoogleToken tablo oluşturma hatası"); }
        }

        private static string Key<T>(string key) => $"{Uri.EscapeDataString(key)}-{typeof(T).FullName}";

        public Task StoreAsync<T>(string key, T value)
        {
            var json = NewtonsoftJsonSerializer.Instance.Serialize(value);
            using var c = _db.OpenPanel();
            c.Execute("""
                MERGE dbo.PanelGoogleToken AS t USING (SELECT @k AS K, @v AS V) AS s ON t.K=s.K
                WHEN MATCHED THEN UPDATE SET V=s.V
                WHEN NOT MATCHED THEN INSERT (K,V) VALUES (s.K,s.V);
                """, new { k = Key<T>(key), v = json });
            return Task.CompletedTask;
        }

        public Task<T> GetAsync<T>(string key)
        {
            using var c = _db.OpenPanel();
            var json = c.QueryFirstOrDefault<string>("SELECT V FROM dbo.PanelGoogleToken WHERE K=@k", new { k = Key<T>(key) });
            return Task.FromResult(json is null ? default! : NewtonsoftJsonSerializer.Instance.Deserialize<T>(json));
        }

        public Task DeleteAsync<T>(string key)
        {
            using var c = _db.OpenPanel();
            c.Execute("DELETE FROM dbo.PanelGoogleToken WHERE K=@k", new { k = Key<T>(key) });
            return Task.CompletedTask;
        }

        public Task ClearAsync()
        {
            using var c = _db.OpenPanel();
            c.Execute("DELETE FROM dbo.PanelGoogleToken");
            return Task.CompletedTask;
        }
    }
}
