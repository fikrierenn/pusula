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
    // ══ MENÜ DÜZENİ (GMY 15.09.2026: "çok uzun bir menü oldu, ilgili olanları alt menü yapalım")
    //
    // ÖNCE: 32 satırın 24'ü tek "ANALİTİK" başlığı altındaydı → kaydırmadan sonu görünmüyordu.
    // ŞİMDİ: 7 konu grubu, sidebar'da KATLANIR. Açık olan grup, bulunduğun sayfanın grubudur.
    //
    // Section = "" → grupsuz, en üstte sabit (Genel Bakış). Yeni sayfa eklerken grubunu YAZ;
    // yazılmazsa varsayılan "ANALİTİK" grubuna düşer ve orada kaybolur.
    // Grup SIRASI bu listedeki ilk görünme sırasıdır (Sections → Distinct).
    public static readonly IReadOnlyList<NavItem> Items = new[]
    {
        new NavItem("", "Genel Bakış", "layout-dashboard", InBottomNav: true, BottomLabel: "Genel",
                    MatchAll: true, Section: ""),

        // ── Günlük yönetim soruları ────────────────────────────────────────────────
        new NavItem("patron-sorulari", "Patron Soruları", "clipboard-list", Section: "YÖNETİM"),
        new NavItem("tahmin", "Hedef Tahmin", "sparkles", Section: "YÖNETİM"),
        new NavItem("operasyon", "Operasyon", "activity", InBottomNav: true, Section: "YÖNETİM"),
        new NavItem("kadro", "Kadro / Sezon Personeli", "users-round", Section: "YÖNETİM"),
        new NavItem("vardiya", "Vardiya / Mesai", "clock", Section: "YÖNETİM"),

        // ── Satış tarafı ───────────────────────────────────────────────────────────
        new NavItem("magazalar", "Mağazalar", "store", Section: "SATIŞ"),
        new NavItem("toplam", "TOPLAM Kategori", "chart-pie", Section: "SATIŞ"),
        new NavItem("eticaret", "E-ticaret", "shopping-cart", InBottomNav: true, Section: "SATIŞ"),
        new NavItem("sinav", "Sınav Okulları", "graduation-cap", Section: "SATIŞ"),
        new NavItem("trafik", "Trafik & Kasiyer", "footprints", Section: "SATIŞ"),

        // ── Müşteri tarafı ─────────────────────────────────────────────────────────
        new NavItem("musteri", "Müşteri", "users", InBottomNav: true, Section: "MÜŞTERİ"),
        new NavItem("sadakat", "Sadakat", "heart", Section: "MÜŞTERİ"),
        new NavItem("hediye-ceki", "Hediye Çeki", "ticket", Section: "MÜŞTERİ"),

        // ── Stok & satınalma (eski SATINALMA grubu buraya katıldı) ─────────────────
        new NavItem("satis-analizi", "Satış Analizi", "table-2", Section: "STOK & SATINALMA"),
        new NavItem("sezon-aksiyon", "Sezon Aksiyon", "list-checks", Section: "STOK & SATINALMA"),
        new NavItem("envanter", "Envanter", "package", InBottomNav: true, Section: "STOK & SATINALMA"),
        new NavItem("stok-hareket", "Stok Hareket", "history", Section: "STOK & SATINALMA"),
        new NavItem("odak-stok", "ODAK Stok", "warehouse", Section: "STOK & SATINALMA"),
        new NavItem("bulunurluk", "Bulunurluk", "scan-barcode", Section: "STOK & SATINALMA"),
        new NavItem("baskisi-yok", "Baskısı Yok", "printer", Section: "STOK & SATINALMA"),
        new NavItem("satinalma/analiz", "Alım Analizi", "shopping-bag", Section: "STOK & SATINALMA"),

        // ── Finans / muhasebe ──────────────────────────────────────────────────────
        new NavItem("muhasebe", "Muhasebe / Kontrol", "landmark", Section: "FİNANS"),
        new NavItem("mizan", "Mizan / Finans", "scale", Section: "FİNANS"),
        new NavItem("gider-mizan", "Gider Merkezi Mizanı", "grid-3x3", Section: "FİNANS"),
        new NavItem("gelir-tablosu", "Gelir Tablosu", "receipt-text", Section: "FİNANS"),
        new NavItem("cari-risk", "Cari / Risk", "wallet", Section: "FİNANS"),

        new NavItem("asistan", "Genius", "message-square", Section: "ASİSTAN"),
        new NavItem("gorevler", "Görevler", "check-square", Section: "ASİSTAN", GorevBadge: true),
        new NavItem("bellek", "Bellek", "database", Section: "ASİSTAN"),

        new NavItem("parametreler", "Rapor Parametreleri", "sliders-horizontal", Section: "SİSTEM"),
        new NavItem("ayarlar", "Ayarlar", "settings", Section: "SİSTEM"),
    };

    /// <summary>Grup başlığının ikonu. Tanımsız grup nötr ikon alır — sessizce kaybolmaz.</summary>
    public static string SectionIcon(string section) => section switch
    {
        "YÖNETİM" => "gauge",
        "SATIŞ" => "trending-up",
        "MÜŞTERİ" => "users",
        "STOK & SATINALMA" => "boxes",
        "FİNANS" => "banknote",
        "ASİSTAN" => "bot",
        "SİSTEM" => "settings",
        _ => "folder",
    };

    /// <summary>Grupsuz (en üstte sabit duran) öğeler.</summary>
    public static IEnumerable<NavItem> Kokte => Items.Where(i => i.Section.Length == 0);

    /// <summary>btm-nav (mobil) öğeleri — sıra korunur.</summary>
    public static IEnumerable<NavItem> BottomNav => Items.Where(i => i.InBottomNav);

    /// <summary>Sidebar grup başlıkları — ilk-görünüm sırasında.</summary>
    public static IEnumerable<string> Sections =>
        Items.Where(i => i.Section.Length > 0).Select(i => i.Section).Distinct();
}
