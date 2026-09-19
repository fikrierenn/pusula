using System.Security.Claims;
using Bkm.Shared.Data;
using BkmVardiya.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace BkmVardiya.Pages;

/// <summary>
/// ŞİFRE SIFIRLAMA (İK) — V-01'in kilidini açan yol.
///
/// NEDEN VAR: ilk kurulumda geçici şifreler <c>ciktilar/</c> altındaki bir dosyaya
/// yazıldı ve o dosya silinemiyordu — çünkü silinirse şifresini henüz değiştirmemiş
/// kişiler (ölçüm 19.09: 17'nin 13'ü) için KURTARMA YOLU YOKTU. Seed mevcut kullanıcıya
/// bilerek dokunmuyor (idempotent), yani yeniden koşmak da çözüm değildi.
/// Bu sayfa o boşluğu kapatır: dosya artık kurtarma aracı olmaktan çıkar.
///
/// ⚠ ŞİFRE EKRANDA BİR KEZ GÖSTERİLİR. Dosyaya YAZILMAZ, loglanmaz. Gerekçe: dosya
///   tam da kurtulmaya çalıştığımız şey; log ise şifreyi kalıcı ve aranabilir yapar.
/// ⚠ SIFIRLAMA "ŞİFREYİ ÖĞREN" DEĞİLDİR: eski şifre okunamaz (hash), yenisi üretilir.
/// ⚠ SIFIRLANAN HESAP İLK GİRİŞTE DEĞİŞTİRMEYE ZORLANIR — claim geri konur. Yoksa
///   İK'nın bildiği bir şifreyle çalışan bir hesap kalırdı.
/// ⚠ İZ ZORUNLU: şifre sıfırlama bir yetki olayıdır. Kim, kimin şifresini, ne zaman
///   sıfırladı — denetim izine yazılır (<see cref="AuditTrail"/>).
/// </summary>
[Authorize(Policy = Permissions.ManageStaff)]
public sealed class ResetPasswordModel(
    Db db,
    UserManager<IdentityUser> userManager,
    ILogger<ResetPasswordModel> logger) : PageModel
{
    [BindProperty] public string UserName { get; set; } = "";

    public IReadOnlyList<string> Users { get; private set; } = [];
    public string? Error { get; private set; }

    /// <summary>Üretilen geçici şifre — YALNIZ bu istekte, YALNIZ ekranda.</summary>
    public string? TempPassword { get; private set; }

    public async Task OnGetAsync() => Users = await LoadUsersAsync();

    public async Task<IActionResult> OnPostAsync()
    {
        Users = await LoadUsersAsync();

        var user = await userManager.FindByNameAsync(UserName.Trim());
        if (user is null)
        {
            Error = "Kullanıcı bulunamadı.";
            return Page();
        }

        var newPassword = Seed.GenerateTempPassword();

        // Belirteç sağlayıcısı KURULU DEĞİL (AddIdentityCore sade kuruldu), bu yüzden
        // GeneratePasswordResetToken yolu kullanılmıyor: kaldır + ekle.
        var remove = await userManager.RemovePasswordAsync(user);
        if (!remove.Succeeded)
        {
            Error = string.Join(" ", remove.Errors.Select(e => e.Description));
            return Page();
        }

        var add = await userManager.AddPasswordAsync(user, newPassword);
        if (!add.Succeeded)
        {
            // ⚠ BURASI TEHLİKELİ ARALIK: şifre KALDIRILDI ama yenisi konamadı.
            //   Sessizce geçilirse hesap şifresiz kalır. Açıkça bildiriliyor.
            logger.LogError("Şifre sıfırlama YARIM KALDI — {Ad} şifresiz: {Hata}",
                            user.UserName, string.Join("; ", add.Errors.Select(e => e.Description)));
            Error = "Şifre sıfırlanamadı ve hesap şifresiz kaldı. Sistem yöneticisine bildirin.";
            return Page();
        }

        // İlk girişte değiştirme zorunluluğu geri konur (zaten varsa ikinci kez eklenmez).
        if (!(await userManager.GetClaimsAsync(user)).Any(c => c.Type == Seed.MustChangePasswordClaim))
            await userManager.AddClaimAsync(user, new Claim(Seed.MustChangePasswordClaim, "1"));

        var actorId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? "";
        using var cn = db.OpenPanel();
        await AuditTrail.WriteAsync(cn, "Vrd_Users", user.Id, AuditTrail.Action.Updated,
            actorId, User.Identity?.Name,
            // ⚠ ŞİFRE İZE YAZILMAZ — iz OLAYI kaydeder, sırrı değil.
            new { PasswordReset = true, MustChangeOnNextLogin = true });

        logger.LogInformation("Şifre sıfırlandı: {Hedef} (sıfırlayan {Aktor})",
                              user.UserName, User.Identity?.Name);

        TempPassword = newPassword;
        return Page();
    }

    private async Task<IReadOnlyList<string>> LoadUsersAsync()
    {
        using var cn = db.OpenPanel();
        return await AuthSql.QueryAsync<string>(cn,
            "SELECT UserName FROM bkm.Vrd_Users ORDER BY UserName");
    }
}
