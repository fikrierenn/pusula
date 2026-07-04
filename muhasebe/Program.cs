using Microsoft.AspNetCore.Authentication.Negotiate;
using Muhasebe.Lib;

var builder = WebApplication.CreateBuilder(args);

// Razor Pages — feature-based klasör (Operax kalıbı). API YOK (OnGet/OnPost).
builder.Services.AddRazorPages()
    .AddRazorPagesOptions(o => o.RootDirectory = "/Features");

// Windows auth (DerinSIS'le aynı — domain kimliği, şifre yok). Kim = User.Identity.Name.
// Dev/preview: zorlanmaz (anonim çalışır). Prod: tüm sayfa Windows-auth ister.
builder.Services.AddAuthentication(NegotiateDefaults.AuthenticationScheme).AddNegotiate();
builder.Services.AddAuthorization(o =>
{
    if (!builder.Environment.IsDevelopment())
        o.FallbackPolicy = o.DefaultPolicy;
});

// Salt-okuma ERP bağlantısı (DerinSISBkm) — secret repo kökü .env'den (koda gömülmez).
builder.Services.AddSingleton<Db>();
// Banka ekstresi satır→cari sınıflandırıcı (in-memory index, salt-okuma, öneri-only).
builder.Services.AddSingleton<BankaSiniflandirmaService>();

var app = builder.Build();

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error");
    app.UseHsts();
    app.UseHttpsRedirection();
}
app.UseStaticFiles();
app.UseRouting();
app.UseAuthentication();
app.UseAuthorization();
app.MapRazorPages();

app.Run();
