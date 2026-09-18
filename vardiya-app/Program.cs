using Bkm.Shared.Data;
using BkmVardiya.Components;

// Vardiya Yönetim Uygulaması — plan 48 Adım 3 (iskelet).
// Auth + rol + şube sınırı Adım 4'te gelir; şu an anonim ve SALT-OKUMA.

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddRazorComponents()
    .AddInteractiveServerComponents();

// Ortak veri katmanı (lib/Bkm.Shared). Db singleton — dashboard'daki kayıt deseniyle aynı.
builder.Services.AddSingleton<Db>();
builder.Services.AddScoped<VardiyaQueries>();

var app = builder.Build();

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error", createScopeForErrors: true);
    app.UseHsts();
}

app.UseStaticFiles();
app.UseAntiforgery();

// Circuit koptuğunda istemcinin sunucunun döndüğünü anlaması için (dashboard deseni).
app.MapGet("/healthz", () => Results.Ok("ok"));

app.MapRazorComponents<App>()
    .AddInteractiveServerRenderMode();

app.Run();
