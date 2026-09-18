using Bkm.Shared.Data;
using BkmVardiya.Security;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Solum.Identity.DependencyInjection;

// Vardiya Yönetim Uygulaması — plan 48 Adım 4 (kimlik + yetki).
// Kimlik DEPOSU Solum.Identity'den (DapperUserStore); kimlik doğrulama ŞEMASI burada.
// Solum şema kaydetmez, yalnız depo verir — bu ayrım bilinçli.

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddRazorPages();

// Ortak veri katmanı (lib/Bkm.Shared).
builder.Services.AddSingleton<Db>();
builder.Services.AddScoped<VardiyaQueries>();

// ── Kimlik deposu — Solum.Identity ────────────────────────────────────────────
// Tablolar: bkm.Vrd_Users / Vrd_Roles / Vrd_UserRoles / Vrd_UserClaims
// (DDL: sorgular/2026-09-18-vardiya-auth-tablo-kur.sql — kolon adları Solum'un
//  SqlServerIdentitySql.UserColumns listesinden BİREBİR alındı, uydurulmadı.)
// Panelin dbo.PanelKullanici'sına DOKUNULMAZ: ayrı kadro, ayrı tablo.
var db = new Db(builder.Configuration,
    LoggerFactory.Create(b => b.AddConsole()).CreateLogger<Db>());
builder.Services.AddSolumIdentityStores<IdentityUser>(o =>
{
    o.Schema = "bkm";
    o.TablePrefix = "Vrd_";
    o.ConnectionString = db.PanelConnectionString;
});

builder.Services.AddIdentityCore<IdentityUser>(o =>
{
    // Kilit AÇIK: domain hesabı yok, şifre tek savunma hattı (plan 48).
    o.Lockout.AllowedForNewUsers = true;
    o.Lockout.MaxFailedAccessAttempts = 5;
    o.Lockout.DefaultLockoutTimeSpan = TimeSpan.FromMinutes(5);
    o.Password.RequiredLength = 10;
    o.User.RequireUniqueEmail = false;   // e-posta zorunlu değil; giriş kullanıcı adıyla
})
.AddRoles<IdentityRole>()
.AddSignInManager();

// ── Kimlik doğrulama şeması — çerez ───────────────────────────────────────────
builder.Services.AddAuthentication(IdentityConstants.ApplicationScheme)
    .AddCookie(IdentityConstants.ApplicationScheme, o =>
    {
        o.LoginPath = "/Login";
        o.AccessDeniedPath = "/AccessDenied";
        o.ExpireTimeSpan = TimeSpan.FromHours(10);
        o.SlidingExpiration = true;
        o.Cookie.Name = "bkm_vardiya";       // panelin "bkm_panel" çerezinden AYRI
        o.Cookie.HttpOnly = true;
        o.Cookie.SameSite = SameSiteMode.Lax;
        o.Cookie.SecurePolicy = CookieSecurePolicy.SameAsRequest;
    });

builder.Services.AddAuthorization(o =>
{
    // Varsayılan KAPALI: her sayfa kimlik ister, açılacak olan açıkça [AllowAnonymous].
    // Tersi (varsayılan açık) bir sayfanın korumasız unutulmasını SESSİZ yapar.
    o.FallbackPolicy = new AuthorizationPolicyBuilder().RequireAuthenticatedUser().Build();

    // ⚠ Politika adı bir İZİNDİR, bir ROL DEĞİL (Solum ekibi, 18.09): kod rol adı
    //   görmez. Dördüncü rol geldiğinde `if (rol == "IK")` avına çıkılmaz.
    o.AddPolicy(Permissions.AllBranches, p => p.RequireClaim(Permissions.ClaimType, Permissions.AllBranches));
    o.AddPolicy(Permissions.Approve, p => p.RequireClaim(Permissions.ClaimType, Permissions.Approve));
});

builder.Services.AddScoped<PermissionLoader>();

var app = builder.Build();

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error");
    app.UseHsts();
}

app.UseStaticFiles();
app.UseRouting();
app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/healthz", () => Results.Ok("ok")).AllowAnonymous();
app.MapRazorPages();

app.Run();
