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
{
    // Prod: her şey auth (allow-list hariç). Development: local preview için anonim (muhasebe app ile aynı desen).
    if (!builder.Environment.IsDevelopment())
        o.FallbackPolicy = new AuthorizationPolicyBuilder().RequireAuthenticatedUser().Build();
});
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
    app.Services.GetRequiredService<Bkm.Shared.Data.Db>(),
    app.Services.GetRequiredService<ILogger<Bkm.Shared.Data.Db>>());

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

// Development'ta FallbackPolicy YOK (yukarıdaki bilinçli karar: "local preview için anonim").
// Endpoint'lerde AÇIK RequireAuthorization o kararla ÇELİŞİYORDU: sayfa anonim açılırken
// /api/* login'e atıyordu (ölçüldü 09.09 — Excel bağlantısı /login?ReturnUrl=... döndü).
// Prod'da koruma AYNEN duruyor; yalnız dev'de sayfalarla aynı davranış.
var korumaGerekli = !app.Environment.IsDevelopment();

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
// SATIŞ ANALİZİ EXCEL — circuit üstünden DEĞİL, doğrudan indirme.
//
// ⚠ NEDEN ENDPOINT: ExcelButton dosyayı base64'e çevirip JS'e gönderiyordu; 275.059 satırlık
// çıktıda circuit ÇÖKÜYORDU (log: JSDisconnectedException "circuit has disconnected").
// Circuit ölünce sayfa tümden ölü kalıyor — satır tıklama bile çalışmıyor (kullanıcı 09.09).
// Endpoint akışta yazdığı için satır sayısı SignalR mesaj boyutuna bağlı değil.
//
// Filtre URL'den okunur (SatisAnaliziFiltre.Coz) → ekranda ne görünüyorsa o iner.
// Kolonlar `kolon=a,b,c` ile gelir; gelmezse varsayılan kolon seti.
var satisAnaliziExcel = app.MapGet("/api/satis-analizi-excel", async (
    GmDashboard.Data.SatisAnaliziQueries q, HttpContext ctx) =>
{
    var sozluk = ctx.Request.Query.ToDictionary(x => x.Key, x => x.Value.ToString());
    var filtre = GmDashboard.Models.SatisAnaliziFiltre.Coz(
        sozluk,
        DateOnly.FromDateTime(DateTime.Today.AddDays(-1)),
        DateTime.Today.Year - 1,
        out var atlanan);

    var anahtarlar = (sozluk.GetValueOrDefault("kolon") ?? "")
        .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
        .ToHashSet(StringComparer.OrdinalIgnoreCase);
    var kolonlar = GmDashboard.Models.SatisAnaliziKolonlar.Hepsi
        .Where(k => anahtarlar.Count == 0 ? k.Varsayilan : anahtarlar.Contains(k.Anahtar))
        .ToList();
    if (kolonlar.Count == 0)
        kolonlar = GmDashboard.Models.SatisAnaliziKolonlar.Hepsi.Where(k => k.Varsayilan).ToList();

    var satirlar = await q.GetTumListeAsync(filtre, ct: ctx.RequestAborted);
    var data = satirlar.Select(s =>
    {
        IDictionary<string, object?> d = new Dictionary<string, object?>();
        foreach (var k in kolonlar) d[k.Baslik] = GmDashboard.Data.SatisAnaliziHucre.Deger(s, k.Anahtar);
        // Detay BAĞLANTISI kaldırıldı 09.09 (kullanıcı: "detay linkinide kaldır").
        // Gerekçe: detay artık Excel'in İÇİNDE — Detay/Mağaza/Depo Adres sayfaları.
        // Tarayıcıya götüren köprü o sayfalar varken gereksiz kolon.
        return d;
    }).ToList();

    // ── ÇOK SAYFALI ÇIKTI (kullanıcı 09.09: "ben excel içinde istiyorum" — drill'e bağlantı
    //    değil, detayın kendisi). Sayfa sayısı SABİT 4; ürün başına sayfa YOK.
    //    Detay sayfaları FİLTREYE BAĞLI: eşiği geçerse yazılmaz ve nedeni "Bilgi" sayfasına
    //    yazılır — sessiz atlama yasak (error-handling § sessiz fallback).
    var sayfalar = new Dictionary<string, object> { ["Liste"] = data };
    var bilgi = new List<IDictionary<string, object?>>();
    const int DetayTavani = 20_000;

    if (data.Count == 0)
    {
        bilgi.Add(new Dictionary<string, object?>
        {
            ["Konu"] = "Boş sonuç",
            ["Açıklama"] = "Bu filtrede satır yok — detay sayfaları da boş.",
        });
    }
    else if (data.Count > DetayTavani)
    {
        bilgi.Add(new Dictionary<string, object?>
        {
            ["Konu"] = "Detay sayfaları YAZILMADI",
            ["Açıklama"] = $"Filtrede {data.Count:N0} ürün var, sınır {DetayTavani:N0}. " +
                "Detay sayfaları (Detay · Mağaza · Depo Adres) ürün başına 1 + 3 + ~2 satır " +
                "üretir; bu boyutta dosya kullanılamaz hale gelir. Panelde kategori/durum " +
                "filtresi uygulayıp tekrar indirin.",
        });
    }
    else
    {
        var detay = await q.GetExcelDetayAsync(filtre, ctx.RequestAborted);
        var magaza = await q.GetExcelMagazaAsync(filtre, ctx.RequestAborted);
        var adres = await q.GetExcelAdresAsync(filtre, ctx.RequestAborted);

        sayfalar["Detay"] = detay.Select(x => GmDashboard.Data.ExcelDetayCevir.Satir(x, filtre)).ToList();
        sayfalar["Mağaza"] = magaza.Select(x => (IDictionary<string, object?>)new Dictionary<string, object?>
        {
            ["stkID"] = x.StkId,
            ["Ürün"] = x.StkAd,
            ["Mağaza"] = x.MekanAd,
            ["Stok"] = x.Stok,
            ["Satış 365g"] = x.Satis,
            ["Son satış"] = x.SonSatis,
            ["Kaç gündür satmıyor"] = x.GunOnce,
            ["Not"] = x.SonSatis is null ? "bu mağazada hiç satılmamış"
                     : x.Stok < 0 ? "EKSİ STOK — sayım hatası"
                     : x.Stok > 0 && x.GunOnce >= 90 ? "stok var, 90+ gündür satmıyor"
                     : "",
        }).ToList();
        sayfalar["Depo Adres"] = adres.Select(x => (IDictionary<string, object?>)new Dictionary<string, object?>
        {
            ["stkID"] = x.StkId,
            ["Ürün"] = x.StkAd,
            ["Alan tipi"] = x.AlanTip,
            ["Adres"] = x.Adres,
            ["Palet"] = x.PaletID,
            ["Adet"] = x.Adet,
            ["Palete giriş"] = x.PaleteGiris,
            ["Merkez stoğuna dahil"] = x.MerkezStokaGiriyor == 1 ? "evet" : "HAYIR (çıkış alanı)",
        }).ToList();

        bilgi.Add(new Dictionary<string, object?>
        {
            ["Konu"] = "Kapsam",
            ["Açıklama"] = $"Kesim {filtre.Kesim:dd.MM.yyyy} · sezon {filtre.SezonYil} · " +
                $"{data.Count:N0} ürün. Satış penceresi son 365 gün. Merkez stoğu WMS hücresel " +
                "stoktan (ERP defteri negatif taşıdığı için kullanılmaz); ÇIKIŞ ALANI merkez " +
                "stoğuna dahil DEĞİL, Depo Adres sayfasında işaretli.",
        });
        bilgi.Add(new Dictionary<string, object?>
        {
            ["Konu"] = "Marj",
            ["Açıklama"] = "Maliyet son 5 alış faturasının ağırlıklı birimi, KDV HARİÇ. Satış " +
                "fiyatı KDV DAHİL olduğu için KDV'den arındırıldı (oran ürün bazında). Bu LİSTE " +
                "marjıdır — kampanya, iade ve sezon-sonu indirimi içinde yok.",
        });
        bilgi.Add(new Dictionary<string, object?>
        {
            ["Konu"] = "Tükenme",
            ["Açıklama"] = "Hızlar ölçüldü; tükenme tarihi ÇIKARIM (geçmiş hızın tekrarı " +
                "varsayılır). Merkez çıkışı sıçramalı olduğu için (çeşitlerin %67'si tek günde) " +
                "merkez için gün-stok hesaplanmaz.",
        });
        bilgi.Add(new Dictionary<string, object?>
        {
            ["Konu"] = "ODAK temin süresi",
            ["Açıklama"] = "leadTime ODAK'ın KATALOG süresidir. Ürünü ODAK'tan almıyorsak bizim " +
                "tedarik süremiz DEĞİL — Detay sayfasında 'Tedarik kaynağı' sütununa bakın.",
        });
    }
    sayfalar["Bilgi"] = bilgi;

    ctx.Response.ContentType = GmDashboard.Data.ExcelExport.ContentType;
    ctx.Response.Headers.ContentDisposition =
        $"attachment; filename=\"satis-analizi-{filtre.Kesim:yyyy-MM-dd}.xlsx\"";
    using var ms = new MemoryStream();
    await MiniExcel.SaveAsAsync(ms, sayfalar, printHeader: true);
    ms.Position = 0;
    await ms.CopyToAsync(ctx.Response.Body);
});
if (korumaGerekli) satisAnaliziExcel.RequireAuthorization();

// ── SEZON AKSİYON LİSTESİ Excel ───────────────────────────────────────────────
// Ekrandaki süzgecin AYNISI iner: filtre URL'den çözülür (SezonAksiyonFiltre.Coz),
// sayfa bileşeni de Excel bağlantısını aynı SorguDizesi()'nden kurar → ekran ile
// dosya AYRIŞAMAZ (emitter-ayrimi.md).
// ⚠ ExcelButton/base64 DEĞİL: büyük listede circuit çöküyor (ölçüldü 09.09).
// Kardeş emitter: scripts/sezon_aksiyon_listesi_excel.py — iş mantığı AYNI.
var sezonAksiyonExcel = app.MapGet("/api/sezon-aksiyon-excel", async (
    GmDashboard.Data.SezonAksiyonQueries q, HttpContext ctx) =>
{
    var sozluk = ctx.Request.Query.ToDictionary(x => x.Key, x => x.Value.ToString());
    var filtre = GmDashboard.Models.SezonAksiyonFiltre.Coz(
        sozluk,
        DateOnly.FromDateTime(DateTime.Today.AddDays(-1)),
        DateTime.Today.Year - 1,
        out var atlanan);

    var satirlar = await q.GetTumListeAsync(filtre, ct: ctx.RequestAborted);

    // ══ TEK SAYFA — SEZON PAYI modelinin tam zinciri ═══════════════════════════
    // GMY 16.09.2026: "alanları gizleme, hücre başlıklarını daha uzun ve anlaşılır yaz".
    // Ara adımlar SAKLANMAZ: oran → tahmin → kalan → eksik → sipariş zinciri şube şube
    // görünür, çünkü alıcı sayıya değil ADIMA itiraz eder.
    // Sınırlar SİLİNMEDİ: ilk satırda tek cümle olarak gidiyor (dosya elden ele dolaşıyor).
    // Kardeş emitter scripts/sezon_aksiyon_listesi_excel.py ile AYNI kolon seti.
    var ustSatir =
        $"Kesim {filtre.Kesim:dd.MM.yyyy} · sezon {filtre.SezonYil} (Ağu–Eki) · " +
        "YÖNTEM: geçen sezonun yüzde kaçı okul açılmadan ÖNCE satılmışsa, bu sezonun okul " +
        "öncesi satışı o orana bölünür → TOPLAM SEZON tahmini; ondan bu sezon bugüne kadar " +
        "satılan düşülür → sezonun kalanında satılacak. · " +
        $"OKUL ÖNCESİ PENCERE: geçen sezon {filtre.GecenPencere.Bas:dd.MM.yyyy}–{filtre.GecenPencere.Son:dd.MM.yyyy}, " +
        $"bu sezon {filtre.BuPencere.Bas:dd.MM.yyyy}–{filtre.BuPencere.Son:dd.MM.yyyy} — {filtre.PencereGun} gün, EŞİT. " +
        "Pencere OKUL AÇILIŞINA hizalı, takvime DEĞİL (takvim hizasıyla tahmin %23,5 düşük " +
        "çıkıyordu). · BÜYÜME PARAMETRESİ YOK — hacmi ürünün bu sezonki kendi satışı taşır. · " +
        "HESAP ŞUBE DÜZEYİNDE kurulur, ürün satırı üç şubenin TOPLAMIDIR. · " +
        "SİPARİŞ = şubelerin toplam eksiği − merkez depo stoğu; mağazalar arası aktarma " +
        "varsayılmaz. · Tutar: siparişte satış fiyatı, fazla/ölüde maliyet — İKİSİ TOPLANMAZ; " +
        "siparişteki tutar kaybedilen CİRODUR, kâr DEĞİL (marj ölçülmedi). · " +
        "Birim maliyeti olmayan üründe Tutar boş kalır → fazla/ölü tutarı ALT SINIR. · " +
        "⚠ Geçen sezon stoğu bitmiş üründe gözlenen satış gerçek talebin ALTINDADIR " +
        "(sağdan sansür) — ayrı kolonda işaretli, düzeltilmedi. · " +
        "Açık sipariş DÜŞÜLMEDİ (ERP'de kapatma alanı 24.02.2025'ten beri yazılmıyor) · " +
        "depo stoğu WMS'ten · tek gün fotoğrafı · " +
        "Alıcı boyutu veride YOK — bu bir GÖREV listesidir, kişiye atıf değildir" +
        (atlanan.Count > 0 ? " · ATLANAN SÜZGEÇ: " + string.Join(" | ", atlanan) : "");

    // MiniExcel başlığı kendi yazar; not satırını ÜSTE koyabilmek için printHeader
    // KAPATILIR ve satırlar elle kurulur: 1. satır not, 2. satır başlık, 3.+ veri.
    // Anahtarlar (k00..) yalnız hücre KONUMUDUR — görünen ad 2. satırdadır.
    // ⚠ MiniExcel kolon kümesini İLK satırın anahtarlarından alır. Not satırı tek anahtar
    //   taşıyınca dosya TEK KOLON çıkıyordu (tablo sessizce kayboldu, hata YOK — ölçüldü
    //   15.09.2026). Bu yüzden HER satır anahtarların hepsini taşır, boşlar null.
    const int SezonAksiyonKolonSayisi = 46;
    static Dictionary<string, object?> Satir(params object?[] h)
    {
        var d = new Dictionary<string, object?>(SezonAksiyonKolonSayisi);
        for (var i = 0; i < SezonAksiyonKolonSayisi; i++)
            d[$"k{i:00}"] = i < h.Length ? h[i] : null;
        return d;
    }

    var pen = $"{filtre.PencereGun} gün";
    var liste = new List<Dictionary<string, object?>>(satirlar.Count + 2)
    {
        Satir(ustSatir),
        Satir("Ürün", "Kategori", "Ürün grubu", "Alt kategori", "Marka / Yayınevi",
              "Stok kodu", "Barkod",
              $"Geçen sezon toplam satılan ({filtre.GecenSezon.Bas:dd.MM.yy}–{filtre.GecenSezon.Son:dd.MM.yy})",
              $"Geçen sezon okul açılmadan önce satılan ({filtre.GecenPencere.Bas:dd.MM.yy}–{filtre.GecenPencere.Son:dd.MM.yy}, {pen})",
              "Geçen sezon stoğu bitti mi (bittiyse satış gerçek talebin altında)",
              "Alt kategori ortalama oranı (şubenin kendi ölçümü zayıfsa bu kullanılır)",
              "Oranın alındığı kırılım",
              "Ürünün sezon payı (sezon ÷ yıllık; düşükse ürün sezonluk değil)",
              $"Bu sezon okul açılmadan önce satılan ({filtre.BuPencere.Bas:dd.MM.yy}–{filtre.BuPencere.Son:dd.MM.yy}, {pen})",
              $"Bu sezon bugüne kadar satılan ({filtre.BuSezon.Bas:dd.MM.yy}–{filtre.BuSezon.Son:dd.MM.yy})",
              "FSM: kullanılan oran", "FSM: bu sezon toplam satacak",
              "FSM: sezonun kalanında satacak", "FSM: stok", "FSM: eksik adet",
              "Özlüce: kullanılan oran", "Özlüce: bu sezon toplam satacak",
              "Özlüce: sezonun kalanında satacak", "Özlüce: stok", "Özlüce: eksik adet",
              "İstanbul Yolu: kullanılan oran", "İstanbul Yolu: bu sezon toplam satacak",
              "İstanbul Yolu: sezonun kalanında satacak", "İstanbul Yolu: stok",
              "İstanbul Yolu: eksik adet",
              "Bu sezon toplam satılacak (üç şubenin toplamı)",
              "Sezonun kalanında satılacak (üç şubenin toplamı)",
              "Şubelerde toplam eksik adet",
              "Mağazalarda toplam stok", $"Merkez depoda stok ({filtre.Kesim:dd.MM.yyyy})",
              "Mağaza ve depo toplam stok",
              "Durum (şube eksikleri merkez depodan karşılanamıyorsa sipariş gerekir)",
              "Sipariş verilecek adet (şubelerde toplam eksik eksi merkez depo stoğu)",
              "Sipariş nereden karşılanır", "Tedarikçide bulunan adet (bizim stoğumuz değil)",
              "Geçen yıl sezon dışında satılan (Kas–Tem)", "Geçen yıl toplam satılan (365 gün)",
              "Gelecek sezona kalacak adet",
              "Satış fiyatı", "Birim maliyet",
              "Tutar (siparişte satış fiyatıyla, fazla/ölüde maliyetle)"),
    };
    foreach (var r in satirlar)
        liste.Add(Satir(
            r.StkAd, r.Kategori3, r.Kat1, r.Kat2, r.Yayinevi, r.StkKod, r.Barkod,
            r.SezonToplam, r.GecenOkulOncesi, r.StoksuzKaldi ? "EVET" : "HAYIR",
            r.KatOran, r.OranKirilim, r.SezonPayi,
            r.BuOkulOncesi, r.BuBugune,
            r.OranFsm, r.TahminFsm, r.KalanFsm, r.StokFsm, r.EksikFsm,
            r.OranOzl, r.TahminOzl, r.KalanOzl, r.StokOzl, r.EksikOzl,
            r.OranIst, r.TahminIst, r.KalanIst, r.StokIst, r.EksikIst,
            r.TahminToplam, r.KalanToplam, r.EksikToplam,
            r.MagazaStok, r.MerkezStok, r.ToplamStok,
            r.DurumAd, r.Siparis, r.Nereden, r.OdakStok,
            r.SezonDisi, r.Yillik, r.Fazla,
            r.SatisFiyat, r.BirimMaliyet, r.Tutar));

    ctx.Response.ContentType = GmDashboard.Data.ExcelExport.ContentType;
    ctx.Response.Headers.ContentDisposition =
        $"attachment; filename=\"sezon-siparis-{filtre.Kesim:yyyy-MM-dd}.xlsx\"";
    using var ms = new MemoryStream();
    await MiniExcel.SaveAsAsync(ms, liste, printHeader: false, sheetName: "LİSTE");
    ms.Position = 0;
    await ms.CopyToAsync(ctx.Response.Body);
});
if (korumaGerekli) sezonAksiyonExcel.RequireAuthorization();

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
