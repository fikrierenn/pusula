using System.Net;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Identity;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace BkmVardiya.Tests;

/// <summary>
/// ŞİFRE SIFIRLAMA (İK) — V-01'in kilidini açan yolun ölçümü.
///
/// ⚠ SIFIRLAMA HEDEFİ AYRI BİR TEST KULLANICISI: fikstürün müdürünü sıfırlamak
///   AYNI koleksiyondaki öteki testleri kırardı (onlar sabit şifreyle giriyor).
///   Yani bu testin izolasyonu bir konfor değil, ÖN KOŞUL.
///
/// YAKALAMAZ: şifrenin ekranda gösterildikten sonra bir yerde saklanmadığını —
/// onu yalnız kod okuması gösterir (dosyaya yazılmıyor, loglanmıyor).
/// </summary>
[Collection(VardiyaDbCollection.Name)]
public sealed class PasswordResetTests(VardiyaAppFactory factory)
{
    [Fact]
    public async Task Hr_resets_password_and_target_must_change_it()
    {
        // ── hedef kullanıcı (atılır) ─────────────────────────────────────────
        using var scope = factory.Services.CreateScope();
        var userManager = scope.ServiceProvider.GetRequiredService<UserManager<IdentityUser>>();

        var targetName = factory.Stamp + "_sifirla";
        var target = new IdentityUser { UserName = targetName, LockoutEnabled = false };
        var created = await userManager.CreateAsync(target, VardiyaAppFactory.Password);
        Assert.True(created.Succeeded, "Hedef test kullanıcısı kurulamadı.");

        // ── İK giriş yapar ve sıfırlar ───────────────────────────────────────
        var hr = await LoginAsync(factory.HrName);

        var form = await (await hr.GetAsync("/ResetPassword")).Content.ReadAsStringAsync();
        var token = Regex.Match(form,
            "name=\"__RequestVerificationToken\"[^>]*value=\"([^\"]+)").Groups[1].Value;
        Assert.False(string.IsNullOrEmpty(token), "İK sıfırlama formunu göremedi.");

        var page = await (await hr.PostAsync("/ResetPassword", new FormUrlEncodedContent(
            new Dictionary<string, string>
            {
                ["UserName"] = targetName,
                ["__RequestVerificationToken"] = token,
            }))).Content.ReadAsStringAsync();

        var newPassword = Regex.Match(page, "<code[^>]*>([^<]+)</code>").Groups[1].Value.Trim();
        Assert.False(string.IsNullOrWhiteSpace(newPassword),
            "Geçici şifre ekranda GÖSTERİLMEDİ — İK sıfırlamayı iletemez, yol işe yaramaz.");

        // ── yeni şifre GERÇEKTEN çalışıyor mu ────────────────────────────────
        var targetClient = factory.CreateClient(new() { AllowAutoRedirect = false });
        var loginPage = await (await targetClient.GetAsync("/Login")).Content.ReadAsStringAsync();
        var loginToken = Regex.Match(loginPage,
            "name=\"__RequestVerificationToken\"[^>]*value=\"([^\"]+)").Groups[1].Value;

        var login = await targetClient.PostAsync("/Login", new FormUrlEncodedContent(
            new Dictionary<string, string>
            {
                ["UserName"] = targetName,
                ["Password"] = newPassword,
                ["__RequestVerificationToken"] = loginToken,
            }));
        Assert.Equal(HttpStatusCode.Redirect, login.StatusCode);   // giriş başarılı → yönlendirme

        // ── ve ilk girişte DEĞİŞTİRMEYE zorlanıyor mu ────────────────────────
        var afterLogin = await targetClient.GetAsync("/");
        Assert.Equal(HttpStatusCode.Redirect, afterLogin.StatusCode);
        Assert.Contains("/ChangePassword", afterLogin.Headers.Location?.OriginalString ?? "",
            StringComparison.OrdinalIgnoreCase);
    }

    /// <summary>
    /// Yetkisi olmayan rol sıfırlayamaz. Bu iddia olmadan sayfa "çalışıyor" görünür
    /// ama HERKESE açık olabilirdi — ve fark ancak biri denediğinde anlaşılırdı.
    /// </summary>
    [Fact]
    public async Task Manager_cannot_reach_reset_page()
    {
        var manager = await LoginAsync(factory.ManagerName, follow: false);
        var response = await manager.GetAsync("/ResetPassword");

        Assert.NotEqual(HttpStatusCode.OK, response.StatusCode);
    }

    private async Task<HttpClient> LoginAsync(string userName, bool follow = true)
    {
        var client = factory.CreateClient(new() { AllowAutoRedirect = follow });
        var loginPage = await (await client.GetAsync("/Login")).Content.ReadAsStringAsync();
        var token = Regex.Match(loginPage,
            "name=\"__RequestVerificationToken\"[^>]*value=\"([^\"]+)").Groups[1].Value;

        await client.PostAsync("/Login", new FormUrlEncodedContent(new Dictionary<string, string>
        {
            ["UserName"] = userName,
            ["Password"] = VardiyaAppFactory.Password,
            ["__RequestVerificationToken"] = token,
        }));
        return client;
    }
}
