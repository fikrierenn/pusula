using GmDashboard.Components;
using GmDashboard.Data;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddRazorComponents()
    .AddInteractiveServerComponents();

builder.Services.AddSingleton<Db>();
builder.Services.AddScoped<Queries>();
builder.Services.AddScoped<MagazaQueries>();
builder.Services.AddScoped<RefQueries>();
builder.Services.AddScoped<EticQueries>();
builder.Services.AddSingleton<LlmService>();      // yerel LLM — model lazy yüklenir (ilk istekte)
builder.Services.AddSingleton<GorevService>();    // SQLite görev deposu (asistan.db)

var app = builder.Build();

// Configure the HTTP request pipeline.
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error", createScopeForErrors: true);
    // The default HSTS value is 30 days. You may want to change this for production scenarios, see https://aka.ms/aspnetcore-hsts.
    app.UseHsts();
}
app.UseStatusCodePagesWithReExecute("/not-found", createScopeForStatusCodePages: true);
app.UseHttpsRedirection();

app.UseAntiforgery();

app.MapStaticAssets();
app.MapRazorComponents<App>()
    .AddInteractiveServerRenderMode();

app.Run();
