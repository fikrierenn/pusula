using System.Security.Claims;
using BkmVardiya.Security;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace BkmVardiya.Pages;

/// <summary>
/// Şifre değiştirme. Geçici şifreyle giren kullanıcı için ZORUNLU:
/// <see cref="Seed.SifreDegistirClaim"/> claim'i varsa
/// <see cref="ForcePasswordChangeFilter"/> her isteği buraya yönlendirir.
///
/// ⚠ Değiştirme başarılı olunca claim SİLİNİR ve oturum YENİLENİR. Yenilenmezse
///   çerezdeki eski claim yerinde kalır ve kullanıcı kendi şifresini değiştirmiş
///   olmasına rağmen sonsuz yönlendirmede sıkışır.
/// </summary>
public sealed class ChangePasswordModel(
    UserManager<IdentityUser> userManager,
    SignInManager<IdentityUser> signInManager,
    PermissionLoader permissionLoader,
    ILogger<ChangePasswordModel> logger) : PageModel
{
    [BindProperty] public string CurrentPassword { get; set; } = "";
    [BindProperty] public string NewPassword { get; set; } = "";
    [BindProperty] public string NewPasswordAgain { get; set; } = "";
    public string? Error { get; private set; }
    public bool Forced { get; private set; }

    public void OnGet() =>
        Forced = User.HasClaim(c => c.Type == Seed.MustChangePasswordClaim);

    public async Task<IActionResult> OnPostAsync()
    {
        Forced = User.HasClaim(c => c.Type == Seed.MustChangePasswordClaim);

        if (NewPassword != NewPasswordAgain)
        {
            Error = "Yeni şifre iki alanda aynı değil.";
            return Page();
        }

        var user = await userManager.GetUserAsync(User);
        if (user is null)
        {
            // Oturum var ama kullanıcı yok — çerez bayat. Sessizce devam etmek
            // "değiştirdim" yanılsaması üretirdi.
            logger.LogWarning("Şifre değiştirme: oturumdaki kullanıcı bulunamadı.");
            return RedirectToPage("/Logout");
        }

        var result = await userManager.ChangePasswordAsync(user, CurrentPassword, NewPassword);
        if (!result.Succeeded)
        {
            Error = string.Join(" ", result.Errors.Select(e => e.Description));
            return Page();
        }

        // Zorunluluk claim'i düşer — hem DB'den hem oturumdan.
        foreach (var c in await userManager.GetClaimsAsync(user))
            if (c.Type == Seed.MustChangePasswordClaim)
                await userManager.RemoveClaimAsync(user, c);

        var claims = await permissionLoader.LoadAsync(user.Id);
        await signInManager.SignOutAsync();
        await signInManager.SignInWithClaimsAsync(user, isPersistent: false, claims);

        logger.LogInformation("Şifre değiştirildi: {Ad}", user.UserName);
        return RedirectToPage("/Index");
    }
}

/// <summary>
/// Geçici şifreyle gelen kullanıcıyı şifre değiştirmeye ZORLAR.
///
/// ⚠ Kapı neden filtre: tek tek sayfalara kontrol koymak, YENİ eklenen sayfanın
///   unutulmasını sessiz yapardı. Filtre varsayılan olarak her sayfayı kapsar;
///   muafiyet listesi AÇIKÇA yazılır ve kısadır.
/// </summary>
public sealed class ForcePasswordChangeFilter : Microsoft.AspNetCore.Mvc.Filters.IAsyncPageFilter
{
    private static readonly string[] Exempt =
        ["/ChangePassword", "/Logout", "/Login", "/AccessDenied", "/Error"];

    public Task OnPageHandlerSelectionAsync(Microsoft.AspNetCore.Mvc.Filters.PageHandlerSelectedContext c)
        => Task.CompletedTask;

    public async Task OnPageHandlerExecutionAsync(
        Microsoft.AspNetCore.Mvc.Filters.PageHandlerExecutingContext context,
        Microsoft.AspNetCore.Mvc.Filters.PageHandlerExecutionDelegate next)
    {
        var user = context.HttpContext.User;
        var page = (context.ActionDescriptor.ViewEnginePath ?? "").TrimEnd('/');

        if (user.Identity?.IsAuthenticated == true
            && user.HasClaim(c => c.Type == Seed.MustChangePasswordClaim)
            && !Exempt.Contains(page, StringComparer.OrdinalIgnoreCase))
        {
            context.Result = new RedirectToPageResult("/ChangePassword");
            return;
        }

        await next();
    }
}
