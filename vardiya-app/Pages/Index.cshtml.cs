using Bkm.Shared.Data;
using Bkm.Shared.Models;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace BkmVardiya.Pages;

public sealed class IndexModel(VardiyaQueries sorgu, ILogger<IndexModel> logger) : PageModel
{
    public IReadOnlyList<VrdKesim> Kesimler { get; private set; } = [];
    public string? Hata { get; private set; }

    public async Task OnGetAsync()
    {
        try
        {
            Kesimler = await sorgu.KesimlerAsync();
        }
        catch (Exception ex)
        {
            // Hata yutulmuyor: loglanır VE ekranda görünür (error-handling.md).
            logger.LogError(ex, "Vardiya kesimleri okunamadı");
            Hata = ex.Message;
        }
    }
}
