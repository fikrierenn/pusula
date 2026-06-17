namespace GmDashboard.Data;

/// <summary>Login/Setup HTML (B-84) — Blazor-dışı düz sayfa (interactive circuit'te SignIn olmaz).
/// İzole inline stil (app.css'e bağımlı değil; login öncesi garanti render).</summary>
internal static class AuthHtml
{
    private const string Stil = """
        <style>
          *{box-sizing:border-box}
          body{margin:0;font-family:system-ui,-apple-system,Segoe UI,Roboto,sans-serif;background:#0f172a;
               display:flex;min-height:100vh;align-items:center;justify-content:center;color:#e2e8f0}
          .card{background:#1e293b;padding:32px;border-radius:16px;width:100%;max-width:360px;box-shadow:0 10px 40px rgba(0,0,0,.4)}
          h1{font-size:20px;margin:0 0 4px;color:#fff}
          .sub{font-size:13px;color:#94a3b8;margin:0 0 24px}
          label{display:block;font-size:13px;margin:14px 0 6px;color:#cbd5e1}
          input{width:100%;padding:11px 12px;border:1px solid #334155;border-radius:8px;background:#0f172a;color:#fff;font-size:15px}
          input:focus{outline:none;border-color:#4063e6}
          button{width:100%;margin-top:22px;padding:12px;border:0;border-radius:8px;background:#4063e6;color:#fff;
                 font-size:15px;font-weight:600;cursor:pointer}
          button:hover{background:#3050cc}
          .err{background:#7f1d1d;color:#fecaca;padding:10px 12px;border-radius:8px;font-size:13px;margin-bottom:16px}
        </style>
        """;

    public static string Login(string? hata)
    {
        var err = hata switch
        {
            "yanlis" => "<div class='err'>Kullanıcı adı veya şifre hatalı.</div>",
            "kilit"  => "<div class='err'>Çok fazla hatalı deneme — 5 dakika kilitli.</div>",
            _ => "",
        };
        return $$"""
            <!DOCTYPE html><html lang="tr"><head><meta charset="utf-8">
            <meta name="viewport" content="width=device-width,initial-scale=1"><title>BKM Panel — Giriş</title>{{Stil}}</head>
            <body><form class="card" method="post" action="/auth/login">
              <h1>BKM Yönetim Paneli</h1><p class="sub">Devam etmek için giriş yapın</p>
              {{err}}
              <label>Kullanıcı Adı</label><input name="kullanici" autofocus autocomplete="username" required>
              <label>Şifre</label><input name="sifre" type="password" autocomplete="current-password" required>
              <button type="submit">Giriş Yap</button>
            </form></body></html>
            """;
    }

    public static string Setup(string? hata)
    {
        var err = hata is null ? "" : $"<div class='err'>{System.Net.WebUtility.HtmlEncode(hata)}</div>";
        return $$"""
            <!DOCTYPE html><html lang="tr"><head><meta charset="utf-8">
            <meta name="viewport" content="width=device-width,initial-scale=1"><title>BKM Panel — İlk Kurulum</title>{{Stil}}</head>
            <body><form class="card" method="post" action="/auth/setup">
              <h1>İlk Kurulum</h1><p class="sub">Panel yöneticisi hesabını oluşturun</p>
              {{err}}
              <label>Kullanıcı Adı</label><input name="kullanici" autofocus required>
              <label>Şifre (min 6)</label><input name="sifre" type="password" minlength="6" required>
              <label>Şifre (tekrar)</label><input name="sifre2" type="password" minlength="6" required>
              <button type="submit">Hesabı Oluştur</button>
            </form></body></html>
            """;
    }
}
