using Bkm.Shared.Data;
using BkmVardiya.Security;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Solum.Identity.DependencyInjection;

// Vardiya Yönetim Uygulaması — plan 48 Adım 4 (kimlik + yetki).
// Kimlik DEPOSU Solum.Identity'den (DapperUserStore); kimlik doğrulama ŞEMASI burada.
// Solum şema kaydetmez, yalnız depo verir — bu ayrım bilinçli.

// ⚠ Solum.Sql SAĞLAYICIYI KENDİ SEÇMEZ: dialect açıkça kaydedilir. Kaydedilmezse
//   hata AÇILIŞTA değil İLK SORGUDA gelir ("Baglanti dizesini taniyan dialect yok")
//   ve sebebi uzak görünür (ölçüldü 19.09.2026 — seed koşumunda çıktı).
Solum.Sql.SqlServer.SolumSqlServer.Register();

var builder = WebApplication.CreateBuilder(args);

// Geçici şifreyle gelen kullanıcı, şifresini değiştirene kadar başka sayfaya
// gidemez. FİLTRE olarak kuruldu: tek tek sayfalara kontrol koymak, YENİ eklenen
// sayfanın unutulmasını sessiz yapardı.
builder.Services.AddRazorPages()
    .AddMvcOptions(o => o.Filters.Add<BkmVardiya.Pages.ForcePasswordChangeFilter>());

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
// ⚠ .AddRoles<IdentityRole>() ÇAĞRILMAZ — Solum.Identity `IUserStore` ve
//   `IUserRoleStore` verir ama `IRoleStore` VERMEZ. Çağrılırsa uygulama
//   AÇILIŞTA patlar: "Unable to resolve service for type IRoleStore<IdentityRole>"
//   (ölçüldü 19.09.2026). Rol tablosu (bkm.Vrd_Roles) SQL ile doldurulur;
//   kullanıcı-rol ataması UserManager üzerinden çalışır (IUserRoleStore var).
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

// ── Kadro kurulumu:  dotnet run --project vardiya-app -- seed ─────────────────
// Uygulamayı AYAĞA KALDIRMAZ; kurulumu yapar, çıkış kodunu döndürür ve biter.
// Çıkış kodu sözleşmesi sqlcli ile aynı: 0 tamam · 1 KIRIK · 2 KOŞAMADI.
if (args.Contains("seed"))
{
    using var kapsam = app.Services.CreateScope();
    var kayitci = kapsam.ServiceProvider.GetRequiredService<ILoggerFactory>().CreateLogger("seed");
    return await BkmVardiya.Security.Seed.CalistirAsync(kapsam.ServiceProvider, kayitci);
}

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
return 0;


// WebApplicationFactory<Program> icin gorunur olmali — top-level statements'in
// urettigi Program sinifi varsayilan olarak internal'dir (plan 48 V-06 testi).
public partial class Program { }
