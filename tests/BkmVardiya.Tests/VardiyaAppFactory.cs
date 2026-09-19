using Xunit;
using Microsoft.AspNetCore.Hosting;
using System.Data;
using Bkm.Shared.Data;
using Dapper;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;

namespace BkmVardiya.Tests;

/// <summary>
/// Test fikstürü — uygulamayı bellek içinde ayağa kaldırır ve kendi test
/// kullanıcılarını kurar.
///
/// BARINDIRMA KARARI — <see cref="WebApplicationFactory{T}"/>, gerçek Kestrel DEĞİL.
/// Gerekçe (Solum, 19.09.2026): ölçüt "ne kadar gerçek" değil, <b>yalan nerede
/// doğdu</b>. Bizim iki sızıntımız SQL kapsamında doğdu; taşıma katmanı iddianın
/// değişkeni değil. Süzgeç eksikse müdürün gördüğü satır sayısı Kestrel'de de
/// TestServer'da da AYNI şekilde şişer — yani Kestrel ölçümü değiştirmez, yalnız
/// kırılganlık ekler. Factory yine de gerçek ara katman zincirini, gerçek kimlik
/// doğrulamayı, gerçek model bağlamayı, gerçek Razor'u ve gerçek Dapper çağrısını
/// koşturur: rol → talep → TVF → satır zinciri baştan sona gerçektir.
///
/// TEST KULLANICILARI — gerçek kadro KULLANILMAZ:
///   • bayatlar (şifreler değişir),
///   • ve bir testin gerçek bir insanın hesabıyla giriş yapması o kişinin
///     denetim izini KİRLETİR.
/// Ad uzayı <c>zz_test_</c> önekiyle ayrılır — artık kalırsa greplenebilir olsun.
///
/// TEMİZLİK BAŞTA DA SONDA DA: süreç çökerse <c>Dispose</c> KOŞMAZ ve artıklar
/// birikir — insanların giriş yaptığı bir veritabanında bilinmeyen test
/// kullanıcıları. Giriş koşulu yalnız başta ya da yalnız sonda sağlanırsa KISMÎDİR.
/// </summary>
public sealed class VardiyaAppFactory : WebApplicationFactory<Program>, IAsyncLifetime
{
    public const string Prefix = "zz_test_";
    public string Stamp { get; } = Prefix + Guid.NewGuid().ToString("N")[..8];

    public string ManagerName => Stamp + "_mudur";
    public string HrName => Stamp + "_ik";
    public const string Password = "ZzTest!2026#scope";

    public string ManagerId { get; private set; } = "";
    public string HrId { get; private set; } = "";
    public string ManagerBranch { get; private set; } = "";

    protected override void ConfigureWebHost(IWebHostBuilder builder) =>
        builder.UseEnvironment("Development");

    public async Task InitializeAsync()
    {
        using var scope = Services.CreateScope();
        var sp = scope.ServiceProvider;
        var db = sp.GetRequiredService<Db>();
        var userManager = sp.GetRequiredService<UserManager<IdentityUser>>();

        using var cn = db.OpenPanel();

        await CleanupResidueAsync(cn);   // ← BAŞTA temizlik (önceki çökmüş koşum)

        ManagerBranch = await cn.ExecuteScalarAsync<string>(
            "SELECT TOP 1 Sube FROM bkm.Vrd_KisiGun GROUP BY Sube ORDER BY COUNT(*) DESC")
            ?? throw new InvalidOperationException(
                "bkm.Vrd_KisiGun BOŞ — scope testi hiçbir şey ölçemez. "
              + "Önce bkm.sp_Vrd_KisiGunDoldur koşturun.");

        ManagerId = await CreateUserAsync(userManager, ManagerName);
        HrId = await CreateUserAsync(userManager, HrName);

        // Müdür: TEK şube, ACL'den. İK: "tüm şubeler" YETKİSİ, ACL satırı YOK.
        await cn.ExecuteAsync(
            "INSERT INTO bkm.Vrd_KullaniciSube (UserId, Sube, VerenId) VALUES (@id, @sube, @veren)",
            new { id = ManagerId, sube = ManagerBranch, veren = Stamp });

        // Müdür ONAY yetkisi taşır — gerçek şube sorumlusu rolünün karşılığı.
        // Olmadan plan düzeltme EKRANI (V-18) test edilemezdi: sayfa
        // [Authorize(Policy = Approve)] taşıyor ve müdür 403 alırdı.
        await cn.ExecuteAsync("""
            INSERT INTO bkm.SolumPermissionGrant (ProviderName, ProviderKey, PermissionName)
            VALUES (N'User', @id, N'vardiya.onayla')
            """, new { id = ManagerId });

        // İK iki yetki taşır: tüm şubeleri GÖRME ve kadro yönetimi (şifre sıfırlama).
        // İkincisi olmadan V-01'in kilidini açan yol test edilemezdi.
        await cn.ExecuteAsync("""
            INSERT INTO bkm.SolumPermissionGrant (ProviderName, ProviderKey, PermissionName)
            VALUES (N'User', @id, N'vardiya.tumSubeler'), (N'User', @id, N'vardiya.kadroYonet')
            """, new { id = HrId });
    }

    private static async Task<string> CreateUserAsync(UserManager<IdentityUser> um, string ad)
    {
        var k = new IdentityUser { UserName = ad, LockoutEnabled = false };
        var s = await um.CreateAsync(k, Password);
        if (!s.Succeeded)
            throw new InvalidOperationException(
                $"Test kullanıcısı kurulamadı ({ad}): " +
                string.Join("; ", s.Errors.Select(e => e.Description)));
        return k.Id;
    }

    /// <summary>
    /// <c>zz_test_</c> önekli HER ŞEYİ siler — bu koşumunkini de, önceki çökmüş
    /// koşumlardan kalanları da. Sıra FK'ya göre: ACL → izin → claim → rol → kullanıcı.
    /// </summary>
    private static Task CleanupResidueAsync(IDbConnection cn) => cn.ExecuteAsync($"""
        DELETE FROM bkm.Vrd_KullaniciSube
        WHERE  UserId IN (SELECT Id FROM bkm.Vrd_Users WHERE UserName LIKE '{Prefix}%');

        DELETE FROM bkm.SolumPermissionGrant
        WHERE  ProviderName = N'User'
          AND  ProviderKey IN (SELECT Id FROM bkm.Vrd_Users WHERE UserName LIKE '{Prefix}%');

        DELETE FROM bkm.Vrd_UserClaims
        WHERE  UserId IN (SELECT Id FROM bkm.Vrd_Users WHERE UserName LIKE '{Prefix}%');

        DELETE FROM bkm.Vrd_UserRoles
        WHERE  UserId IN (SELECT Id FROM bkm.Vrd_Users WHERE UserName LIKE '{Prefix}%');

        DELETE FROM bkm.Vrd_Users WHERE UserName LIKE '{Prefix}%';

        -- Denetim izi de temizlenir: yetki verme artik iz yaziyor (V-12) ve
        -- test artiklari gercek izin arasinda birikirse denetim okunmaz olur.
        DELETE FROM bkm.SolumAuditTrail
        WHERE  EntityName = N'Vrd_KullaniciSube' AND UserName LIKE '{Prefix}%';

        -- PLAN DUZELTME ARTIGI (V-05): duzeltme GERCEK kisi-gune yazilir, yani
        -- artik kalirsa gercek raporu degistirir -- en tehlikeli test artigi budur.
        -- Testin kendi `finally`si de siliyor; bu IKINCI katman, cunku surec cokerse
        -- `finally` kosmaz.
        DELETE FROM bkm.Vrd_PlanDuzeltme WHERE Kaydeden LIKE '{Prefix}%';
        DELETE FROM bkm.SolumAuditTrail
        WHERE  EntityName = N'Vrd_PlanDuzeltme' AND UserName LIKE '{Prefix}%';
        """);

    public new async Task DisposeAsync()
    {
        using var scope = Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<Db>();
        using var cn = db.OpenPanel();
        await CleanupResidueAsync(cn);   // ← SONDA temizlik
        await base.DisposeAsync();
    }
}
