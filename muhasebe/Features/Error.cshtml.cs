using System.Diagnostics;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace Muhasebe.Pages;

// Genel hata sayfası (stack trace kullanıcıya sızmaz — security-principles).
public sealed class ErrorModel : PageModel
{
    public string? RequestId { get; set; }

    public void OnGet() => RequestId = Activity.Current?.Id ?? HttpContext.TraceIdentifier;
}
