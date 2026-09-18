using System.Security.Claims;
using Bkm.Shared.Data;
using BkmVardiya.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace BkmVardiya.Pages;

/// <summary>
/// Yönetici onayı — plan 48 Adım 6.
///
/// ⚠ İKİ AYRI KAPI, ikisi de gerekli:
///   1. <see cref="Permissions.Approve"/> — bu kişi onay YAZABİLİR mi? (role işi)
///   2. Şube kapsamı — bu SATIRA yazabilir mi? (SQL'de, VardiyaQueries içinde)
///   Birincisi olmadan GMY de yazabilirdi (salt-okuma olması gereken role);
///   ikincisi olmadan bir müdür başka şubeye yazabilirdi. Biri ötekinin yerini
///   TUTMAZ.
///
/// ⚠ Süreler DAKİKA girilir değil, SAAT:DAKİKA girilir — kullanıcı "13:30" yazar,
///   dakikaya burada çevrilir. Gece vardiyasında çıkış ertesi güne sarkar ve
///   1440'ı aşar; "26:00" meşru bir değerdir ve kabul edilir.
/// </summary>
[Authorize(Policy = Permissions.Approve)]
public sealed class ApprovalModel(VardiyaQueries queries, ILogger<ApprovalModel> logger) : PageModel
{
    [BindProperty(SupportsGet = true)] public string StaffNo { get; set; } = "";
    [BindProperty(SupportsGet = true)] public DateOnly Date { get; set; }

    [BindProperty] public string? ApprovedIn { get; set; }
    [BindProperty] public string? ApprovedOut { get; set; }
    [BindProperty] public string? ExtraShift { get; set; }
    [BindProperty] public string? Note { get; set; }

    public string? Error { get; private set; }
    public string? Saved { get; private set; }

    public async Task<IActionResult> OnGetAsync()
    {
        if (string.IsNullOrWhiteSpace(StaffNo) || Date == default)
            return RedirectToPage("/Index");

        var userId = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? "";
        var existing = await queries.GetApprovalAsync(userId, StaffNo, Date);
        if (existing is not null)
        {
            ApprovedIn = MinutesToText(existing.ApprovedInMin);
            ApprovedOut = MinutesToText(existing.ApprovedOutMin);
            ExtraShift = MinutesToText(existing.ExtraShiftMin);
            Note = existing.Note;
        }
        return Page();
    }

    public async Task<IActionResult> OnPostAsync()
    {
        var userId = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? "";
        var savedBy = User.Identity?.Name ?? userId;

        if (!TextToMinutes(ApprovedIn, out var inMin) ||
            !TextToMinutes(ApprovedOut, out var outMin) ||
            !TextToMinutes(ExtraShift, out var extraMin))
        {
            Error = "Saat biçimi geçersiz. SS:DD yazın (örnek 13:30). Gece vardiyasında 26:00 gibi değerler geçerlidir.";
            return Page();
        }

        try
        {
            await queries.SaveApprovalAsync(userId, StaffNo, Date, inMin, outMin, extraMin, Note, savedBy);
            logger.LogInformation("Onay kaydedildi: {Sicil} {Tarih} — {Kim}", StaffNo, Date, savedBy);
            Saved = "Onay kaydedildi.";
        }
        catch (UnauthorizedAccessException ex)
        {
            // Kapsam dışı satır — SQL kapısı reddetti. Kullanıcıya sebebi söylenir
            // ama hangi şube olduğu SÖYLENMEZ (kapsam dışı bilgi sızdırmaz).
            logger.LogWarning(ex, "Kapsam dışı onay denemesi: {Kim} → {Sicil} {Tarih}", savedBy, StaffNo, Date);
            Error = "Bu kayıt şube kapsamınızda değil.";
        }
        catch (ArgumentException ex)
        {
            Error = ex.Message;
        }
        catch (Exception ex)
        {
            // Teknik ayrıntı ekrana BASILMAZ, log'a yazılır (security-principles).
            logger.LogError(ex, "Onay kaydedilemedi: {Sicil} {Tarih}", StaffNo, Date);
            Error = "Kayıt sırasında beklenmedik bir hata oluştu.";
        }
        return Page();
    }

    /// <summary>"13:30" → 810. Boş → null. Gece sarkması için 1440 üstü SERBEST.</summary>
    internal static bool TextToMinutes(string? text, out int? minutes)
    {
        minutes = null;
        if (string.IsNullOrWhiteSpace(text)) return true;
        var p = text.Trim().Split(':');
        if (p.Length != 2 || !int.TryParse(p[0], out var ss) || !int.TryParse(p[1], out var dd))
            return false;
        if (ss < 0 || dd < 0 || dd > 59) return false;
        minutes = ss * 60 + dd;
        return true;
    }

    /// <summary>810 → "13:30". 1590 → "26:30" (gün dönümü GİZLENMEZ).</summary>
    internal static string? MinutesToText(int? dk) =>
        dk is null ? null : $"{dk.Value / 60:00}:{dk.Value % 60:00}";
}
