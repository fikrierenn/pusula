using System.Diagnostics;
using GmDashboard.Models;

namespace GmDashboard.Data;

/// <param name="Deger">Ekranda gösterilecek tek rakam.</param>
/// <param name="Not">Rakamın altındaki kısa bağlam.</param>
/// <param name="Ms">Ölçülen süre — 2 sn eşiğinin denetimi (plan-37 Faz B).</param>
/// <param name="Hata">Doluysa metrik alınamadı; sessiz boş gösterilmez.</param>
public record MiniMetrik(string Deger, string? Not, long Ms, string? Hata = null);

/// <summary>
/// Patron Soruları panelinin lazy mini-metrikleri (plan-37 Faz B).
///
/// KURAL (emitter-ayrimi §2): burada SQL YOK. Her metrik hedef sayfanın çağırdığı
/// <c>*Queries</c> metodunu ÇAĞIRIR — sorgu kopyalanırsa panel ile sayfa zamanla ayrışır
/// ve panel sessizce yanlış rakam gösterir. Yeni metrik eklerken de kural aynı.
///
/// Yalnız &lt;2 sn ölçülen servisler buraya alınır; yavaş olan Faz A rozetinde kalır.
/// Süre her çağrıda ölçülür, eşik aşılırsa log'a uyarı düşer (sessiz yavaşlama olmasın).
/// </summary>
public sealed class PatronSorulariQueries(
    Queries queries,
    RefQueries refQueries,
    EticQueries etic,
    BulunurlukQueries bulunurluk,
    GorevService gorev,
    ILogger<PatronSorulariQueries> log)
{
    private const long EsikMs = 2000;

    /// <summary>Aynı sayfa açılışında iki soru aynı servisi çağırırsa tek sorgu koşsun.</summary>
    private readonly Dictionary<string, Task<MiniMetrik>> _memo = new();

    private static readonly System.Globalization.CultureInfo Tr =
        System.Globalization.CultureInfo.GetCultureInfo("tr-TR");

    /// <summary>Metriği olan sorular — registry'deki MetrikAnahtar ile eşleşir.</summary>
    public static readonly IReadOnlySet<string> Anahtarlar = new HashSet<string>
    {
        "hedef-gerceklesme", "mtd-ciro", "acik-gorev",
        "hediye-ceki-12ay", "bulunurluk-oos", "bekleyen-kargo",
    };

    public Task<MiniMetrik> GetAsync(string anahtar)
    {
        if (_memo.TryGetValue(anahtar, out var mevcut)) { return mevcut; }
        var t = Olc(anahtar, () => Uret(anahtar));
        _memo[anahtar] = t;
        return t;
    }

    private async Task<MiniMetrik> Olc(string anahtar, Func<Task<MiniMetrik>> is_)
    {
        var sw = Stopwatch.StartNew();
        try
        {
            var m = await is_();
            sw.Stop();
            if (sw.ElapsedMilliseconds > EsikMs)
            {
                log.LogWarning("Patron mini-metrik '{Anahtar}' {Ms} ms — {Esik} ms eşiğini aştı, Faz A'ya geri alınmalı.",
                    anahtar, sw.ElapsedMilliseconds, EsikMs);
            }
            return m with { Ms = sw.ElapsedMilliseconds };
        }
        catch (Exception ex)
        {
            sw.Stop();
            log.LogError(ex, "Patron mini-metrik '{Anahtar}' alınamadı", anahtar);
            return new MiniMetrik("—", null, sw.ElapsedMilliseconds, "alınamadı");
        }
    }

    private Task<MiniMetrik> Uret(string anahtar) => anahtar switch
    {
        "hedef-gerceklesme" => HedefGerceklesme(),
        "mtd-ciro" => MtdCiro(),
        "acik-gorev" => AcikGorev(),
        "hediye-ceki-12ay" => HediyeCeki(),
        "bulunurluk-oos" => BulunurlukOos(),
        "bekleyen-kargo" => BekleyenKargo(),
        _ => Task.FromResult(new MiniMetrik("—", null, 0, $"bilinmeyen metrik '{anahtar}'")),
    };

    // ── MTD penceresi: ayın 1'i → bugün (dahil). /magazalar "Hedef (MTD)" ile aynı taban. ──
    private static (DateOnly Bas, DateOnly BitHaric) Mtd()
    {
        var bugun = DateOnly.FromDateTime(DateTime.Today);
        return (new DateOnly(bugun.Year, bugun.Month, 1), bugun.AddDays(1));
    }

    private async Task<MiniMetrik> HedefGerceklesme()
    {
        var (bas, bit) = Mtd();
        var (magaza, _) = await queries.GetHedefAsync(bas, bit);
        var hedef = magaza.Sum(m => m.Hedef);
        var net = magaza.Sum(m => m.Net);
        if (hedef <= 0) { return new MiniMetrik("—", "hedef girilmemiş", 0); }
        var pct = net / hedef * 100m;
        return new MiniMetrik($"%{pct:N1}", $"MTD {Tl(net)} / hedef {Tl(hedef)} ₺ · {magaza.Count} mağaza", 0);
    }

    private async Task<MiniMetrik> MtdCiro()
    {
        var (bas, bit) = Mtd();
        var (magaza, _) = await queries.GetHedefAsync(bas, bit);
        return new MiniMetrik($"{Tl(magaza.Sum(m => m.Net))} ₺", $"MTD net · {bas:dd.MM} – {bit.AddDays(-1):dd.MM.yyyy}", 0);
    }

    private Task<MiniMetrik> AcikGorev()
    {
        var n = gorev.Listele(acikOnly: true).Count;
        return Task.FromResult(new MiniMetrik(n.ToString("N0", Tr), "açık görev", 0));
    }

    private async Task<MiniMetrik> HediyeCeki()
    {
        var hc = await refQueries.GetHediyeCekiAsync();
        return new MiniMetrik($"{Tl(hc.ToplamKullanilan12Ay)} ₺",
            $"son 12 ay kullanılan · satılan {Tl(hc.ToplamSatilan12Ay)} ₺", 0);
    }

    private async Task<MiniMetrik> BulunurlukOos()
    {
        var satirlar = await bulunurluk.GetSubeOosAsync();
        var tasinan = satirlar.Sum(s => s.TasinanAktif);
        var kuru = satirlar.Sum(s => s.Kuru);
        if (tasinan == 0) { return new MiniMetrik("—", "pre-agg boş", 0); }
        return new MiniMetrik($"%{(decimal)kuru / tasinan * 100:N1}",
            $"{kuru:N0} kuru / {tasinan:N0} taşınan-aktif SKU", 0);
    }

    private async Task<MiniMetrik> BekleyenKargo()
    {
        var b = await etic.GetBekleyenDurumAsync();
        return new MiniMetrik(b.Toplam.ToString("N0", Tr),
            $"toplanma {b.ToplanmaBekleyen:N0} · hazırlanan {b.Hazirlanan:N0} · temin {b.TeminBekleyen:N0}", 0);
    }

    private static string Tl(decimal v) => v.ToString("#,##0", Tr);
}
