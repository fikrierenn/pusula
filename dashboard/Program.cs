using System.Security.Claims;
using ApexCharts;
using Microsoft.AspNetCore.Authentication;
using GmDashboard;
using GmDashboard.Components;
using GmDashboard.Data;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authorization;
using MiniExcelLibs;

// Dapper: SQL date ↔ DateOnly (SqlClient date'i DateTime döndürür; record DateOnly ctor eşleşmez) — B-108.
Dapper.SqlMapper.AddTypeHandler(new DateOnlyTypeHandler());

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddRazorComponents()
    .AddInteractiveServerComponents();

// ── Auth (B-84) — cookie + global authorize. Şifre localhost BkmPanel'de (AuthService). ──
builder.Services.AddAuthentication(CookieAuthenticationDefaults.AuthenticationScheme)
    .AddCookie(o =>
    {
        o.LoginPath = "/login";
        o.ExpireTimeSpan = TimeSpan.FromHours(12);
        o.SlidingExpiration = true;
        o.Cookie.Name = "bkm_panel";
        o.Cookie.HttpOnly = true;
        o.Cookie.SameSite = SameSiteMode.Lax;
        o.Cookie.SecurePolicy = CookieSecurePolicy.SameAsRequest;  // HTTP(5112)+HTTPS(5443) paralel mimari
    });
builder.Services.AddAuthorization(o =>
    o.FallbackPolicy = new AuthorizationPolicyBuilder().RequireAuthenticatedUser().Build());  // her şey auth, allow-list hariç
builder.Services.AddCascadingAuthenticationState();
builder.Services.AddScoped<AuthService>();

builder.Services.AddApexCharts();   // mobil-native grafik motoru (plan-08)
builder.Services.AddHttpClient();   // takvim API (Apps Script) — IHttpClientFactory plan-14

// ── DI: özellik-bazlı kayıt (B-121, ServiceRegistration.cs). Yeni servis → kendi grubuna, Program.cs değişmez. ──
// NOT: LlmService (yerel qwen) DI'dan KALDIRILDI (18.06) — asistan cloud'a geçti. Kod korunuyor, yüklenmiyor (boot hızlı).
builder.Services.AddBkmVeri();      // Db + ERP/mizan sorgu servisleri
builder.Services.AddBkmDurum();     // app-local durum (görev/tahmin/takvim/ayar) + forecast + UI state
builder.Services.AddBkmAsistan();   // LLM zinciri + asistan araçları (plan-21/26)

var app = builder.Build();

// Lokasyon (şube/depo mekanID) posMagaza'dan dinamik yükle — hardcode yerine (startup, bir kez). Hata → fallback.
await GmDashboard.Data.LokasyonConfig.InitAsync(
    app.Services.GetRequiredService<GmDashboard.Data.Db>(),
    app.Services.GetRequiredService<ILogger<GmDashboard.Data.Db>>());

// Configure the HTTP request pipeline.
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error", createScopeForErrors: true);
    // The default HSTS value is 30 days. You may want to change this for production scenarios, see https://aka.ms/aspnetcore-hsts.
    app.UseHsts();
}
app.UseStatusCodePagesWithReExecute("/not-found", createScopeForStatusCodePages: true);
// HTTPS redirect KAPALI (dev/mobil): http (5112) + https (5443) paralel.
// Telefon CA'yı HTTP'den indirir, güvenir, sonra HTTPS'ten standalone açar.

app.UseAuthentication();
app.UseAuthorization();
app.UseAntiforgery();

// PWA için CA sertifikası indirme — doğru MIME ile Android "CA yükle" ekranını açar.
app.MapGet("/ca.crt", (IWebHostEnvironment env) =>
    Results.File(Path.Combine(env.ContentRootPath, "cert", "bkm-ca.crt"), "application/x-x509-ca-cert", "BKM-Panel-CA.crt"))
    .AllowAnonymous();

// Hafif sağlık ucu — istemci circuit kopunca poll eder, sunucu dönünce telefon otomatik reload.
app.MapGet("/healthz", () => Results.Text("ok")).AllowAnonymous();

// ── Auth endpoint'leri (B-84) — login/setup düz HTML (Blazor circuit'te SignIn olmaz). ──
app.MapGet("/login", async (AuthService auth, string? hata) =>
{
    if (!auth.Enabled) return Results.Text("Auth yapılandırılmamış (.env PANEL_DB_HOST yok).");
    if (!await auth.KullaniciVarMiAsync()) return Results.Redirect("/setup");
    return Results.Content(AuthHtml.Login(hata), "text/html");
}).AllowAnonymous();

app.MapPost("/auth/login", async (HttpContext ctx, AuthService auth, [Microsoft.AspNetCore.Mvc.FromForm] string kullanici, [Microsoft.AspNetCore.Mvc.FromForm] string sifre) =>
{
    var sonuc = await auth.DogrulaAsync(kullanici ?? "", sifre ?? "");
    if (sonuc == AuthSonuc.Basarili)
    {
        var principal = new ClaimsPrincipal(new ClaimsIdentity(
            [new Claim(ClaimTypes.Name, kullanici!.Trim())], CookieAuthenticationDefaults.AuthenticationScheme));
        await ctx.SignInAsync(CookieAuthenticationDefaults.AuthenticationScheme, principal);
        return Results.Redirect("/");
    }
    var msg = sonuc == AuthSonuc.Kilitli ? "kilit" : "yanlis";
    return Results.Redirect($"/login?hata={msg}");
}).AllowAnonymous().DisableAntiforgery();

app.MapGet("/setup", async (AuthService auth) =>
{
    if (!auth.Enabled) return Results.Text("Auth yapılandırılmamış.");
    if (await auth.KullaniciVarMiAsync()) return Results.Redirect("/login");
    return Results.Content(AuthHtml.Setup(null), "text/html");
}).AllowAnonymous();

app.MapPost("/auth/setup", async (HttpContext ctx, AuthService auth, [Microsoft.AspNetCore.Mvc.FromForm] string kullanici, [Microsoft.AspNetCore.Mvc.FromForm] string sifre, [Microsoft.AspNetCore.Mvc.FromForm] string sifre2) =>
{
    if (await auth.KullaniciVarMiAsync()) return Results.Redirect("/login");
    if (sifre != sifre2 || (sifre?.Length ?? 0) < 6)
        return Results.Content(AuthHtml.Setup("Şifreler eşleşmeli ve en az 6 karakter olmalı."), "text/html");
    if (!await auth.SetupAsync(kullanici ?? "", sifre!))
        return Results.Content(AuthHtml.Setup("Kullanıcı oluşturulamadı."), "text/html");
    var principal = new ClaimsPrincipal(new ClaimsIdentity(
        [new Claim(ClaimTypes.Name, kullanici!.Trim())], CookieAuthenticationDefaults.AuthenticationScheme));
    await ctx.SignInAsync(CookieAuthenticationDefaults.AuthenticationScheme, principal);
    return Results.Redirect("/");
}).AllowAnonymous().DisableAntiforgery();

app.MapPost("/auth/logout", async (HttpContext ctx) =>
{
    await ctx.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
    return Results.Redirect("/login");
}).DisableAntiforgery();

// ── Google OAuth (Faz-2: Gmail+Takvim) — yalnız giriş yapmış CFO bağlanabilir (AllowAnonymous YOK). ──
app.MapGet("/auth/google", (GmDashboard.Data.Asistan.GoogleAuthService g) =>
    g.Yapilandirilmis ? Results.Redirect(g.AuthUrl())
                      : Results.Text("Google OAuth yapılandırılmamış (.env GOOGLE_CLIENT_ID/SECRET)."));

app.MapGet("/auth/google/callback", async (GmDashboard.Data.Asistan.GoogleAuthService g, string? code, string? error) =>
{
    if (!string.IsNullOrEmpty(error) || string.IsNullOrEmpty(code)) return Results.Redirect("/asistan?google=hata");
    try { await g.BaglantiBitirAsync(code); return Results.Redirect("/asistan?google=ok"); }
    catch { return Results.Redirect("/asistan?google=hata"); }
});

// Ölü stok Excel indirme — MiniExcel streaming, büyük liste için uygun.
app.MapGet("/api/olustok-excel", async (RefQueries ref_, HttpContext ctx) =>
{
    var rows = await ref_.GetOluStokTumAsync();
    var data = rows.Select(r => new
    {
        Stok_Kodu   = r.Kod,
        Ürün_Adı    = r.Ad,
        Kategori    = r.Kategori,
        Toplam      = r.Bakiye,
        FSM         = r.StokFsm,
        Özlüce      = r.StokOzl,
        İst_Yolu    = r.StokIst,
        Depo        = r.StokDepo,
        Ort_Maliyet = r.OrtMaliyet,
        Stok_TL     = r.StokTl,
        Yaş_Gün     = r.YasGun,
    });
    ctx.Response.ContentType = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";
    ctx.Response.Headers.ContentDisposition = "attachment; filename=\"olustok.xlsx\"";
    using var ms = new MemoryStream();
    await MiniExcel.SaveAsAsync(ms, data);
    ms.Position = 0;
    await ms.CopyToAsync(ctx.Response.Body);
}).RequireAuthorization();

app.MapStaticAssets().AllowAnonymous();   // css/js/framework login öncesi yüklenir
app.MapRazorComponents<App>()
    .AddInteractiveServerRenderMode();

app.Run();

// ── Dapper DateOnly ↔ SQL date handler (B-108) ──
internal sealed class DateOnlyTypeHandler : Dapper.SqlMapper.TypeHandler<DateOnly>
{
    public override DateOnly Parse(object value) => DateOnly.FromDateTime((DateTime)value);
    public override void SetValue(System.Data.IDbDataParameter p, DateOnly value)
    {
        p.DbType = System.Data.DbType.Date;
        p.Value = value.ToDateTime(TimeOnly.MinValue);
    }
}
