using System.Net;
using System.Text.RegularExpressions;
using Xunit;

namespace BkmVardiya.Tests;

/// <summary>
/// SOLUM KABUĞU AYAKTA MI — V-03.
///
/// NEDEN VAR: kabuk bir <c>_ViewStart</c> satırıyla devrede. O satır geri alınırsa
/// uygulama ÇALIŞMAYA DEVAM EDER, testler yeşil kalır ve fark yalnız EKRANDA görünür —
/// yani kimse bakmadığı sürece görünmez. Bu test kabuğun kurulduğunu iddia değil
/// ÖLÇÜ hâline getirir.
///
/// ⚠ İkinci ölçüm CSS: kabuk RCL'den gelen <c>solum.css</c>'e bağlı. Dosya
///   sunulmazsa sayfa ÇİZİLİR ama biçimsiz kalır — HTML testleri bunu GÖRMEZ.
///   O yüzden adres ayrıca isteniyor.
/// </summary>
[Collection(VardiyaDbCollection.Name)]
public sealed class SolumShellTests(VardiyaAppFactory factory)
{
    [Fact]
    public async Task Report_page_renders_inside_solum_shell()
    {
        var client = factory.CreateClient(new() { AllowAutoRedirect = true });

        var loginPage = await (await client.GetAsync("/Login")).Content.ReadAsStringAsync();
        var token = Regex.Match(loginPage,
            "name=\"__RequestVerificationToken\"[^>]*value=\"([^\"]+)").Groups[1].Value;

        var login = await client.PostAsync("/Login", new FormUrlEncodedContent(new Dictionary<string, string>
        {
            ["UserName"] = factory.ManagerName,
            ["Password"] = VardiyaAppFactory.Password,
            ["__RequestVerificationToken"] = token,
        }));
        Assert.True(login.IsSuccessStatusCode, "Giriş başarısız — kabuk ölçülemez.");

        var page = await (await client.GetAsync("/")).Content.ReadAsStringAsync();

        Assert.Contains("solum-shell", page);
        Assert.Contains("BKM Vardiya", page);           // marka tüketiciden geliyor
        Assert.Contains("Mesai Raporu", page);          // menü katkısı kuruldu
        Assert.Contains("/Logout", page);               // çıkış adresi verilmiş
    }

    /// <summary>
    /// Kabuk CSS'i RCL'den sunuluyor mu? Sunulmazsa sayfa biçimsiz kalır ve
    /// HTML iddiaları bunu göremez.
    /// </summary>
    [Fact]
    public async Task Shell_stylesheet_is_served()
    {
        var response = await factory.CreateClient().GetAsync("/_content/Solum.Web/solum.css");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.NotEqual(0, response.Content.Headers.ContentLength ?? 0);
    }
}
