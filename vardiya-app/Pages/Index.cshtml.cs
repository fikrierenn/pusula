using System.Security.Claims;
using Bkm.Shared.Data;
using Bkm.Shared.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace BkmVardiya.Pages;

/// <summary>
/// Eksik/fazla + mesai raporu — plan 48 Adım 5.
/// Dashboard'daki Blazor sayfasından taşındı; HESAP DEĞİŞMEDİ (SP'de kalıyor).
///
/// ⚠ Filtreler QUERY STRING'te (Blazor'daki alan bağlamanın yerine): Razor Pages'in
///   doğal yolu ve yan faydası var — filtreli görünüm PAYLAŞILABİLİR bir adres olur.
/// ⚠ ŞUBE FİLTRESİ BİR YETKİ DEĞİL: kapsam SQL'de çözülüyor
///   (<c>bkm.Vrd_SubeKapsami</c>); buradaki değer yalnız kapsam İÇİNDE daraltır.
///   Adres çubuğuna başka şube yazmak kapsamı genişletmez, kesişimde düşer.
/// </summary>
public sealed class IndexModel(VardiyaQueries queries, ILogger<IndexModel> logger) : PageModel
{
    [BindProperty(SupportsGet = true)] public string? Cutoff { get; set; }
    [BindProperty(SupportsGet = true)] public string? Branch { get; set; }
    [BindProperty(SupportsGet = true)] public string? Search { get; set; }
    [BindProperty(SupportsGet = true)] public bool OnlyDeviations { get; set; }

    public IReadOnlyList<VrdCutoff> Cutoffs { get; private set; } = [];
    public VrdCutoff? SelectedCutoff { get; private set; }
    public VrdSummary? Summary { get; private set; }
    public VrdCompliance? Compliance { get; private set; }
    public VrdOvertimeSource? OvertimeSource { get; private set; }
    public IReadOnlyList<VrdStayBand> StayBands { get; private set; } = [];
    public IReadOnlyList<VrdBranch> Branches { get; private set; } = [];
    public IReadOnlyList<VrdRow> Rows { get; private set; } = [];
    public string? Error { get; private set; }

    public int StayBandTotal => StayBands.Sum(b => b.Minutes);

    public static string CutoffKey(VrdCutoff c) =>
        $"{c.CutoffFrom:yyyy-MM-dd}|{c.CutoffTo:yyyy-MM-dd}";

    public async Task OnGetAsync()
    {
        // Kimlik oturumdan; kapsamı SQL bundan çözer. Boşsa hiçbir şey görünmez
        // (fail-closed) — "yetkisiz kullanıcı her şeyi görür" durumu OLUŞAMAZ.
        var userId = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? "";

        try
        {
            Cutoffs = await queries.GetCutoffsAsync(userId);
            if (Cutoffs.Count == 0) return;

            SelectedCutoff = Cutoffs.FirstOrDefault(c => CutoffKey(c) == Cutoff) ?? Cutoffs[0];
            Cutoff = CutoffKey(SelectedCutoff);

            var from = DateOnly.FromDateTime(SelectedCutoff.CutoffFrom);
            var to = DateOnly.FromDateTime(SelectedCutoff.CutoffTo);
            var branch = string.IsNullOrWhiteSpace(Branch) ? null : Branch;

            Summary = await queries.GetSummaryAsync(userId, from, to);
            Compliance = await queries.GetComplianceAsync(userId, from, to);
            Branches = await queries.GetBranchBreakdownAsync(userId, from, to);
            OvertimeSource = await queries.GetOvertimeSourceAsync(userId, from, to, branch);
            StayBands = await queries.GetStayBandsAsync(userId, from, to, branch);
            Rows = await queries.GetRowsAsync(userId, from, to, branch, Search, OnlyDeviations);
        }
        catch (Exception ex)
        {
            // Yutulmaz: loglanır VE ekranda görünür (error-handling.md).
            logger.LogError(ex, "Vardiya raporu okunamadı");
            Error = ex.Message;
        }
    }
}
