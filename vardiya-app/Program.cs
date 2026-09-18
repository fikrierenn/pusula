using Bkm.Shared.Data;

// Vardiya Yönetim Uygulaması — plan 48 Adım 3 (iskelet).
// Razor Pages: arayüz omurgası Solum (D:\Dev\Solum), tasarım sistemi solum.css.
// Auth + rol + şube sınırı Adım 4'te gelir; şu an anonim ve SALT-OKUMA.

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddRazorPages();

// Ortak veri katmanı (lib/Bkm.Shared). Db singleton — dashboard'daki kayıt deseniyle aynı.
builder.Services.AddSingleton<Db>();
builder.Services.AddScoped<VardiyaQueries>();

var app = builder.Build();

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Hata");
    app.UseHsts();
}

app.UseStaticFiles();
app.UseRouting();

app.MapGet("/healthz", () => Results.Ok("ok"));
app.MapRazorPages();

app.Run();
