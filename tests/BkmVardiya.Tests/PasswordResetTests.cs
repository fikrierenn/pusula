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

        // ⚠ TUTAMAK `data-test` — ilk yazımda "sayfadaki İLK <code>" alınıyordu ve
        //   test ARA SIRA kırmızı dönüyordu (V-15'te "üretilemeyen kırmızı" diye
        //   kaydedilen flake BUYDU). Kabuk/uyarı metni bir <code> içerirse yanlış
        //   dizge şifre sanılıyor, giriş başarısız oluyor ve hata "şifre çalışmadı"
        //   gibi okunuyordu — yani testin ölçtüğü şey değil, ÖLÇÜM ARACI bozuktu.
        // ⚠ HTML ÇÖZÜMÜ ZORUNLU — ve bunu ÖLÇEREK öğrendik (V-15 flake'inin gerçek
        //   sebebi buydu): şifre havuzunda `+` var ve Razor onu `&#x2B;` diye
        //   kodluyor. Çözülmeden denenince giriş başarısız oluyor, hata "şifre
        //   çalışmadı" gibi okunuyordu — oysa ÜRÜN doğru, ÖLÇÜM ARACI yanlıştı.
        //   Kırmızı ARA SIRA çıkıyordu çünkü her şifrede `+` olmuyor.
        var newPassword = System.Net.WebUtility.HtmlDecode(
            Regex.Match(page, "data-test=\"temp-password\"[^>]*>([^<]+)<").Groups[1].Value).Trim();
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
        // ⚠ KANIT TOPLA: bu iddia ARA SIRA kırmızı dönüyordu ve sebebi tahminle
        //   bulunamadı. Hata mesajı artık ÜRETİLEN ŞİFREYİ ve sayfanın hata metnini
        //   taşıyor — "flaky" demek yerine ölçebilmek için.
        if (login.StatusCode != HttpStatusCode.Redirect)
        {
            var govde = await login.Content.ReadAsStringAsync();
            var hataMetni = Regex.Match(govde, "role=\"alert\"[^>]*>(.*?)<", RegexOptions.Singleline)
                                 .Groups[1].Value.Trim();
            Assert.Fail($"Giriş yönlendirme vermedi ({login.StatusCode}). " +
                        $"Şifre uzunluğu {newPassword.Length}, şifre: <{newPassword}>. " +
                        $"Sayfa uyarısı: <{hataMetni}>");
        }

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
