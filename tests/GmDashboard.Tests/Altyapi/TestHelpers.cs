using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;
using Bkm.TestAltyapi;

namespace GmDashboard.Tests.Altyapi;

/// <summary>Süreç-geneli ortam değişkenini değiştirir, Dispose'ta eski değeri geri yazar.</summary>
internal sealed class EnvScope : IDisposable
{
    private readonly string _name;
    private readonly string? _previous;

    public EnvScope(string name, string? value)
    {
        _name = name;
        _previous = Environment.GetEnvironmentVariable(name);
        Environment.SetEnvironmentVariable(name, value);
    }

    public void Dispose()
    {
        Environment.SetEnvironmentVariable(_name, _previous);
    }
}

/// <summary>Geçerli kültürü değiştirir, Dispose'ta geri yazar.</summary>
internal sealed class CultureScope : IDisposable
{
    private readonly CultureInfo _previous = CultureInfo.CurrentCulture;

    public CultureScope(string culture)
    {
        CultureInfo.CurrentCulture = new CultureInfo(culture);
    }

    public void Dispose()
    {
        CultureInfo.CurrentCulture = _previous;
    }
}

[CollectionDefinition(Name, DisableParallelization = true)]
public sealed class LiveDbEnvCollection
{
    public const string Name = "LiveDbEnv";
}

internal sealed record CanonicalBlock(string FileName, string Name, string Text);

/// <summary>
/// Kanonik .sql dosyasını `-- blok: ad` (yalnız satır başı) işaretiyle bloklara böler;
/// blok metninden GO satırlarını ve baştaki `;` ile biten DECLARE ifadelerini ayıklar
/// (K-karar-15: işaret yoksa bütün dosya tek blok; K-r1-5: `;`'siz DECLARE ayıklanmaz, kapıya girer).
/// </summary>
internal static class CanonicalBlockReader
{
    private const string DeclareWord = "DECLARE";

    private static readonly Regex s_marker = new(@"^-- blok:[ \t]*(?<ad>\S*)[^\r\n]*", RegexOptions.Multiline);
    private static readonly Regex s_goLine = new(@"^[ \t]*GO[ \t]*\r?$", RegexOptions.Multiline | RegexOptions.IgnoreCase);

    // Satır yorumu K-r1-2'deki beş satır sonundan herhangi birinde biter.
    private static readonly Regex s_leadingTrivia = new(
        @"\G(?:\s|--[^\n\r\u0085  ]*|/\*.*?\*/)*",
        RegexOptions.Singleline);

    public static IReadOnlyList<CanonicalBlock> Split(string fileName, string text)
    {
        MatchCollection markers = s_marker.Matches(text);
        if (markers.Count == 0)
        {
            return [new CanonicalBlock(fileName, "(tum)", Clean(text))];
        }

        string[] parts = s_marker.Split(text);

        // Split yakalama grubu olduğu için ad parçaları araya girer: [baslik, ad1, govde1, ad2, govde2, ...].
        return markers
            .Select((m, i) => new CanonicalBlock(fileName, m.Groups["ad"].Value, Clean(parts[(2 * i) + 2])))
            .ToList();
    }

    public static string Clean(string block)
    {
        string text = s_goLine.Replace(block, string.Empty);
        StringBuilder kept = new();
        int position = 0;
        while (true)
        {
            Match trivia = s_leadingTrivia.Match(text, position);
            kept.Append(trivia.Value);
            position += trivia.Length;

            int end = DeclarePrefixEnd(text, position);
            if (end < 0)
            {
                return kept.Append(text, position, text.Length - position).ToString();
            }

            position = end;
        }
    }

    /// <summary>Çıktı klasöründeki (bin) göreli klasörlerdeki .sql dosyalarını okur; (dosya, metin).</summary>
    public static IEnumerable<(string FileName, string Text)> Files(params string[] folders)
    {
        return folders
            .Select(k => Path.Combine(AppContext.BaseDirectory, k))
            .Where(Directory.Exists)
            .SelectMany(k => Directory.GetFiles(k, "*.sql"))
            .OrderBy(f => f, StringComparer.Ordinal)
            .Select(f => (Path.GetRelativePath(AppContext.BaseDirectory, f), File.ReadAllText(f)));
    }

    public static IEnumerable<object[]> Rows(params string[] folders)
    {
        return Files(folders)
            .SelectMany(d => Split(d.FileName, d.Text))
            .Select(b => new object[] { b.FileName, b.Name, b.Text });
    }

    // Ayıklanacak DECLARE ifadesinin bitişi; ayıklanamazsa -1. Ayıklanan metin kapıdan kaçmasın diye
    // DECLARE yerine SELECT konarak kapıdan geçirilir: gövdesinde yazma ya da işlem kelimesi taşıyan ifade ayıklanmaz.
    private static int DeclarePrefixEnd(string text, int position)
    {
        if (!WordAt(text, position, DeclareWord))
        {
            return -1;
        }

        int start = position + DeclareWord.Length;
        int end = DeclareEnd(text, start);
        bool clean = (end >= 0) && ReadOnlyGate.Check("SELECT" + text[start..end]).Passed;
        return clean ? end : -1;
    }

    // DECLARE gövdesini parantez derinliği 0'daki ilk ';'ye kadar izler. Derinlik 0'da SELECT/WITH
    // görülürse ya da metin biterse ifade ';'siz demektir: -1 (ayıklanmaz).
    private static int DeclareEnd(string text, int start)
    {
        int depth = 0;
        int i = start;
        while (i < text.Length)
        {
            char c = text[i];
            if (c == '\'')
            {
                int close = text.IndexOf('\'', i + 1);
                if (close < 0)
                {
                    return -1;
                }

                i = close + 1;
                continue;
            }

            if (c == '(')
            {
                depth++;
            }
            else if (c == ')')
            {
                depth--;
            }
            else if ((c == ';') && (depth == 0))
            {
                return i + 1;
            }
            else if ((depth == 0) && (WordAt(text, i, "SELECT") || WordAt(text, i, "WITH")))
            {
                return -1;
            }

            i++;
        }

        return -1;
    }

    private static bool WordAt(string text, int i, string word)
    {
        bool startsHere = (i == 0) || !IsWordChar(text[i - 1]);
        bool fits = (i + word.Length) <= text.Length;
        bool endsHere = (i + word.Length == text.Length) || (fits && !IsWordChar(text[i + word.Length]));
        return startsHere
            && fits
            && endsHere
            && string.Compare(text, i, word, 0, word.Length, StringComparison.OrdinalIgnoreCase) == 0;
    }

    private static bool IsWordChar(char c)
    {
        return char.IsLetterOrDigit(c) || (c == '_') || (c == '@') || (c == '#') || (c == '$');
    }
}
