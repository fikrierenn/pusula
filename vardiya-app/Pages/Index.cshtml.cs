using System.Security.Claims;
using Bkm.Shared.Data;
using Bkm.Shared.Models;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace BkmVardiya.Pages;

public sealed class IndexModel(VardiyaQueries queries, ILogger<IndexModel> logger) : PageModel
{
    public IReadOnlyList<VrdKesim> Cutoffs { get; private set; } = [];
    public string? Error { get; private set; }

    public async Task OnGetAsync()
    {
        try
        {
            Cutoffs = await queries.GetCutoffsAsync(User.FindFirstValue(ClaimTypes.NameIdentifier) ?? "");
        }
        catch (Exception ex)
        {
            // Hata yutulmuyor: loglanır VE ekranda görünür (error-handling.md).
            logger.LogError(ex, "Vardiya kesimleri okunamadı");
            Error = ex.Message;
        }
    }
}
