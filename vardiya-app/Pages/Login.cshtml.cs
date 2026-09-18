using System.Security.Claims;
using BkmVardiya.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace BkmVardiya.Pages;

/// <summary>
/// Giriş — kullanıcı adı + şifre (domain hesabı YOK, GMY kararı 18.09).
/// Şifre doğrulama Solum.Identity <c>DapperUserStore</c> + ASP.NET Identity
/// hash'leme; kendi PBKDF2'mizi YAZMIYORUZ.
/// </summary>
[AllowAnonymous]
public sealed class LoginModel(
    SignInManager<IdentityUser> signInManager,
    UserManager<IdentityUser> userManager,
    PermissionLoader permissionLoader,
    ILogger<LoginModel> logger) : PageModel
{
    [BindProperty] public string UserName { get; set; } = "";
    [BindProperty] public string Password { get; set; } = "";
    public string? Error { get; private set; }

    public void OnGet() { }

    public async Task<IActionResult> OnPostAsync(string? returnUrl)
    {
        if (string.IsNullOrWhiteSpace(UserName) || string.IsNullOrEmpty(Password))
        {
            Error = "Kullanıcı adı ve şifre gerekli.";
            return Page();
        }

        var user = await userManager.FindByNameAsync(UserName.Trim());
        // ⚠ Kullanıcı yoksa da şifre doğrulaması YAPILIR gibi davranılmaz ama mesaj
        //   AYNI kalır: "yok" ile "yanlış" ayrımı geçerli kullanıcı adlarını sayar.
        if (user is null)
        {
            logger.LogWarning("Başarısız giriş — kullanıcı yok: {Ad}", UserName.Trim());
            Error = "Kullanıcı adı veya şifre hatalı.";
            return Page();
        }

        var result = await signInManager.CheckPasswordSignInAsync(user, Password, lockoutOnFailure: true);
        if (result.IsLockedOut)
        {
            logger.LogWarning("Hesap kilitli: {Ad}", user.UserName);
            Error = "Hesap geçici olarak kilitlendi. 5 dakika sonra tekrar deneyin.";
            return Page();
        }
        if (!result.Succeeded)
        {
            logger.LogWarning("Başarısız giriş — şifre: {Ad}", user.UserName);
            Error = "Kullanıcı adı veya şifre hatalı.";
            return Page();
        }

        // İzinler girişte çereze yazılır — bedeli IzinYukleyici'de yazılı
        // (kaldırılan yetki, çıkışa kadar taşınır).
        var extraClaims = await permissionLoader.LoadAsync(user.Id);
        await signInManager.SignInWithClaimsAsync(user, isPersistent: false, extraClaims);

        logger.LogInformation("Giriş başarılı: {Ad} · {Sayi} izin", user.UserName, extraClaims.Count);

        // ⚠ AÇIK YÖNLENDİRME KAPISI: yalnız yerel yol kabul edilir.
        //   "//baska.site" da yerel görünür — IsLocalUrl bunu da eler.
        if (!string.IsNullOrEmpty(returnUrl) && Url.IsLocalUrl(returnUrl))
            return LocalRedirect(returnUrl);
        return RedirectToPage("/Index");
    }
}
