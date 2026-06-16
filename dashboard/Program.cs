using ApexCharts;
using GmDashboard.Components;
using GmDashboard.Data;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddRazorComponents()
    .AddInteractiveServerComponents();

builder.Services.AddApexCharts();   // mobil-native grafik motoru (plan-08)
builder.Services.AddHttpClient();   // takvim API (Apps Script) — IHttpClientFactory plan-14

builder.Services.AddSingleton<Db>();
builder.Services.AddScoped<Queries>();
builder.Services.AddScoped<MagazaQueries>();
builder.Services.AddScoped<RefQueries>();
builder.Services.AddScoped<EticQueries>();
builder.Services.AddScoped<SadakatQueries>();
builder.Services.AddSingleton<LlmService>();      // yerel LLM — model lazy yüklenir (ilk istekte)
builder.Services.AddSingleton<GorevService>();    // SQLite görev deposu (asistan.db)
builder.Services.AddSingleton<TahminKayitService>(); // JSON tahmin kaydı (data/tahmin-kayitlari.json) plan-14
builder.Services.AddSingleton<TakvimService>();      // takvim etmen (tatil API cache + okul JSON) plan-14
builder.Services.AddScoped<ForecastOkuService>();    // tahmin motoru çıktısı okur (data/forecast/*.json) plan-15
builder.Services.AddScoped<NotifState>();         // bildirim merkezi (Home üretir, MainLayout zili okur)
builder.Services.AddScoped<PerfState>();          // sayfa yükleme süresi (sayfalar Track, footer okur)

var app = builder.Build();

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

app.UseAntiforgery();

// PWA için CA sertifikası indirme — doğru MIME ile Android "CA yükle" ekranını açar.
app.MapGet("/ca.crt", (IWebHostEnvironment env) =>
    Results.File(Path.Combine(env.ContentRootPath, "cert", "bkm-ca.crt"), "application/x-x509-ca-cert", "BKM-Panel-CA.crt"));

// Hafif sağlık ucu — istemci circuit kopunca poll eder, sunucu dönünce telefon otomatik reload.
app.MapGet("/healthz", () => Results.Text("ok"));

app.MapStaticAssets();
app.MapRazorComponents<App>()
    .AddInteractiveServerRenderMode();

app.Run();
