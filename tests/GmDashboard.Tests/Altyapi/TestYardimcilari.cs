using System.Globalization;
using System.Text.RegularExpressions;

namespace GmDashboard.Tests.Altyapi;

/// <summary>Süreç-geneli ortam değişkenini değiştirir, Dispose'ta eski değeri geri yazar.</summary>
internal sealed class EnvKapsami : IDisposable
{
    private readonly string _ad;
    private readonly string? _eski;

    public EnvKapsami(string ad, string? yeni)
    {
        _ad = ad;
        _eski = Environment.GetEnvironmentVariable(ad);
        Environment.SetEnvironmentVariable(ad, yeni);
    }

    public void Dispose()
    {
        Environment.SetEnvironmentVariable(_ad, _eski);
    }
}

/// <summary>Geçerli kültürü değiştirir, Dispose'ta geri yazar.</summary>
internal sealed class KulturKapsami : IDisposable
{
    private readonly CultureInfo _eski = CultureInfo.CurrentCulture;

    public KulturKapsami(string kultur)
    {
        CultureInfo.CurrentCulture = new CultureInfo(kultur);
    }

    public void Dispose()
    {
        CultureInfo.CurrentCulture = _eski;
    }
}

[CollectionDefinition(Adi, DisableParallelization = true)]
public sealed class CanliDbEnvKoleksiyonu
{
    public const string Adi = "CanliDbEnv";
}

internal sealed record KanonikBlok(string Dosya, string Ad, string Govde);

/// <summary>
/// Kanonik .sql dosyasını `-- blok: ad` (yalnız satır başı) işaretiyle bloklara böler;
/// blok metninden GO satırlarını ve baştaki DECLARE ön ekini ayıklar (K-karar-15: işaret yoksa bütün dosya tek blok).
/// </summary>
internal static class KanonikBlokOkuyucu
{
    private static readonly Regex s_isaret = new(@"^-- blok:[ \t]*(?<ad>\S*)[^\r\n]*", RegexOptions.Multiline);
    private static readonly Regex s_goSatiri = new(@"^[ \t]*GO[ \t]*\r?$", RegexOptions.Multiline | RegexOptions.IgnoreCase);
    private static readonly Regex s_onEk = new(@"\A(?:\s|--[^\r\n]*|/\*.*?\*/|DECLARE\b[^;]*;)*", RegexOptions.Singleline | RegexOptions.IgnoreCase);
    private static readonly Regex s_declare = new(@"DECLARE\b[^;]*;", RegexOptions.Singleline | RegexOptions.IgnoreCase);

    public static IReadOnlyList<KanonikBlok> Bol(string dosya, string metin)
    {
        MatchCollection isaretler = s_isaret.Matches(metin);
        if (isaretler.Count == 0)
        {
            return [new KanonikBlok(dosya, "(tum)", Temizle(metin))];
        }

        string[] parcalar = s_isaret.Split(metin);

        // Split yakalama grubu olduğu için ad parçaları araya girer: [baslik, ad1, govde1, ad2, govde2, ...].
        return isaretler
            .Select((m, i) => new KanonikBlok(dosya, m.Groups["ad"].Value, Temizle(parcalar[(2 * i) + 2])))
            .ToList();
    }

    public static string Temizle(string blok)
    {
        string goYok = s_goSatiri.Replace(blok, string.Empty);
        Match onEk = s_onEk.Match(goYok);
        string temizOnEk = s_declare.Replace(onEk.Value, string.Empty);
        return temizOnEk + goYok[onEk.Length..];
    }

    /// <summary>Çıktı klasöründeki (bin) göreli klasörlerdeki .sql dosyalarını okur; (dosya, metin).</summary>
    public static IEnumerable<(string Dosya, string Metin)> Dosyalar(params string[] gorelKlasorler)
    {
        return gorelKlasorler
            .Select(k => Path.Combine(AppContext.BaseDirectory, k))
            .Where(Directory.Exists)
            .SelectMany(k => Directory.GetFiles(k, "*.sql"))
            .OrderBy(f => f, StringComparer.Ordinal)
            .Select(f => (Path.GetRelativePath(AppContext.BaseDirectory, f), File.ReadAllText(f)));
    }

    public static IEnumerable<object[]> Satirlar(params string[] gorelKlasorler)
    {
        return Dosyalar(gorelKlasorler)
            .SelectMany(d => Bol(d.Dosya, d.Metin))
            .Select(b => new object[] { b.Dosya, b.Ad, b.Govde });
    }
}
