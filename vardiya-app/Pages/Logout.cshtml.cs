using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace BkmVardiya.Pages;

/// <summary>Çıkış — çerez düşer, izinler de onunla gider.</summary>
public sealed class LogoutModel(SignInManager<IdentityUser> signInManager) : PageModel
{
    public async Task OnGetAsync() => await signInManager.SignOutAsync();
}
