using Microsoft.AspNetCore.Components.Routing;

namespace GmDashboard.Models;

/// <summary>
/// Dashboard navigasyon kaydı — TEK kaynak (plan-12 WS-3, Hermes registry single-source-of-truth).
/// Sidebar (masaüstü) + mobil btm-nav bu listeden türer. Yeni sayfa = tek satır → tüm nav otomatik
/// güncellenir; elle iki yeri senkronlama YOK → orphan link riski yok (B-75 kökü).
/// </summary>
public record NavItem(
    string Href,
    string Label,
    string Icon,
    bool InBottomNav = false,
    string? BottomLabel = null,   // btm-nav kısa etiket (null → Label)
    bool MatchAll = false,        // "/" Genel Bakış için NavLinkMatch.All
    string Section = "ANALİTİK",  // sidebar grup başlığı
    bool GorevBadge = false)      // açık görev rozeti (özel-case, MainLayout besler)
{
    public NavLinkMatch Match => MatchAll ? NavLinkMatch.All : NavLinkMatch.Prefix;
    public string BtmLabel => BottomLabel ?? Label;
}

public static class NavRegistry
{
    public static readonly IReadOnlyList<NavItem> Items = new[]
    {
        new NavItem("", "Genel Bakış", "layout-dashboard", InBottomNav: true, BottomLabel: "Genel", MatchAll: true),
        new NavItem("magazalar", "Mağazalar", "store"),
        new NavItem("toplam", "TOPLAM Kategori", "chart-pie"),
        new NavItem("eticaret", "E-ticaret", "shopping-cart", InBottomNav: true),
        new NavItem("operasyon", "Operasyon", "store", InBottomNav: true),
        new NavItem("envanter", "Envanter", "package", InBottomNav: true),
        new NavItem("musteri", "Müşteri", "users", InBottomNav: true),
        new NavItem("sadakat", "Sadakat", "heart"),
        new NavItem("tahmin", "Hedef Tahmin", "sparkles"),
        new NavItem("asistan", "Asistan", "message-square", Section: "ASİSTAN"),
        new NavItem("gorevler", "Görevler", "check-square", Section: "ASİSTAN", GorevBadge: true),
    };

    /// <summary>btm-nav (mobil) öğeleri — sıra korunur.</summary>
    public static IEnumerable<NavItem> BottomNav => Items.Where(i => i.InBottomNav);

    /// <summary>Sidebar grup başlıkları — ilk-görünüm sırasında.</summary>
    public static IEnumerable<string> Sections => Items.Select(i => i.Section).Distinct();
}
