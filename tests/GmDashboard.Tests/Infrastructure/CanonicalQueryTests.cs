using System.Text;
using Bkm.TestAltyapi;

namespace GmDashboard.Tests.Infrastructure;

/// <summary>Çalışma anında Kanonik/ altına yazılan geçici fikstür; Dispose siler (artıkları kurucu da süpürür).</summary>
internal sealed class TempCanonicalFile : IDisposable
{
    private const string Prefix = "_gecici-";

    private readonly string _path;

    public TempCanonicalFile(string content)
    {
        Name = Prefix + Guid.NewGuid().ToString("N") + ".sql";
        _path = Path.Combine(Folder(), Name);
        File.WriteAllText(_path, content, new UTF8Encoding(false));
    }

    public string Name { get; }

    public static void SweepLeftovers()
    {
        Directory.GetFiles(Folder(), Prefix + "*.sql").ToList().ForEach(File.Delete);
    }

    public void Dispose()
    {
        File.Delete(_path);
    }

    private static string Folder()
    {
        return Path.Combine(AppContext.BaseDirectory, "Kanonik");
    }
}

// Kanonik blok okuyucu (T-023): blok sınırı, başlık, hata yolları. Birim testidir (DB yok); Trait'siz.
// R1 kapısından geçemeyecek fikstürler (boş/yinelenen blok) dosyada değil, geçici dosya olarak yazılır.
public class CanonicalQueryTests : IDisposable
{
    private const string Fixture = "_test-fikstur.sql";

    public CanonicalQueryTests()
    {
        TempCanonicalFile.SweepLeftovers();
    }

    public void Dispose()
    {
        TempCanonicalFile.SweepLeftovers();
    }

    [Fact]
    public void CanonicalQuery_Read_StopsAtBlockBoundary()
    {
        string text = CanonicalQuery.Read(Fixture, "A");

        Assert.Contains("govde-A", text);
        Assert.DoesNotContain("govde-B", text);
        Assert.DoesNotContain("govde-C", text);
    }

    [Fact]
    public void CanonicalQuery_Read_ExcludesMarkerLinesAndStartsAfterLabel()
    {
        string text = CanonicalQuery.Read(Fixture, "A");

        Assert.DoesNotContain("-- blok:", text);
        Assert.StartsWith("SELECT 'govde-A'", text.TrimStart(), StringComparison.Ordinal);
    }

    [Fact]
    public void CanonicalQuery_Read_LastBlockRunsToEndOfFile()
    {
        string text = CanonicalQuery.Read(Fixture, "Z");

        Assert.EndsWith("'govde-Z' AS son_satir;", text.TrimEnd(), StringComparison.Ordinal);
        Assert.DoesNotContain("govde_d", text);
        Assert.DoesNotContain("govde-A", text);
    }

    [Fact]
    public void CanonicalQuery_Read_MiddleBlockHasNoNeighbours()
    {
        string text = CanonicalQuery.Read(Fixture, "B");

        Assert.Contains("govde-B", text);
        Assert.DoesNotContain("govde-A", text);
        Assert.DoesNotContain("govde-C", text);
    }

    [Fact]
    public void CanonicalQuery_Read_MissingBlockThrows()
    {
        InvalidOperationException ex = Assert.Throws<InvalidOperationException>(() => CanonicalQuery.Read(Fixture, "X"));

        Assert.Contains(Fixture, ex.Message, StringComparison.Ordinal);
        Assert.Contains("X", ex.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void CanonicalQuery_Read_BlockNameIsCaseSensitive()
    {
        Assert.Throws<InvalidOperationException>(() => CanonicalQuery.Read(Fixture, "a"));
    }

    [Fact]
    public void CanonicalQuery_Read_LabelWithExtraSpacesStillMatches()
    {
        using TempCanonicalFile file = new("-- blok:   A   \nSELECT 'bosluklu';\n");

        string text = CanonicalQuery.Read(file.Name, "A");

        Assert.Contains("'bosluklu'", text, StringComparison.Ordinal);
    }

    [Fact]
    public void CanonicalQuery_Read_LabelWithoutSpaceIsABlock()
    {
        using TempCanonicalFile file = new("-- blok:A\nSELECT 'bitisik';\n");

        string text = CanonicalQuery.Read(file.Name, "A");

        Assert.Contains("'bitisik'", text, StringComparison.Ordinal);
    }

    [Fact]
    public void CanonicalQuery_Read_LabelWithDescriptionMatchesFirstToken()
    {
        using TempCanonicalFile file = new("-- blok: A  (iptal kalem; @MekanId = 1)\nSELECT 'aciklamali';\n-- blok: B\nSELECT 'diger';\n");

        string text = CanonicalQuery.Read(file.Name, "A");

        Assert.Contains("'aciklamali'", text, StringComparison.Ordinal);
        Assert.DoesNotContain("iptal kalem", text, StringComparison.Ordinal);
        Assert.DoesNotContain("'diger'", text, StringComparison.Ordinal);
    }

    [Fact]
    public void CanonicalQuery_Read_NamePrefixDoesNotMatchLongerName()
    {
        using TempCanonicalFile file = new("-- blok: A2\nSELECT 'uzun';\n-- blok: A\nSELECT 'kisa';\n");

        string text = CanonicalQuery.Read(file.Name, "A");

        Assert.Contains("'kisa'", text, StringComparison.Ordinal);
        Assert.DoesNotContain("'uzun'", text, StringComparison.Ordinal);
    }

    [Fact]
    public void CanonicalQuery_Read_HeaderCommentIsExcluded()
    {
        string text = CanonicalQuery.Read(Fixture, "A");

        Assert.DoesNotContain("SORU-METNI-BASLIK", text);
        Assert.DoesNotContain("basliktaki ornek", text);
    }

    [Fact]
    public void CanonicalQuery_Read_MarkerInsideHeaderIsNotABlock()
    {
        // Başlıkta "-- blok: A" örneği var; gerçek A bloğu sonra gelir. Başlık sayılsaydı A yinelenir ya da gövde kaybolurdu.
        string text = CanonicalQuery.Read(Fixture, "A");

        Assert.Contains("govde-A", text);
    }

    [Fact]
    public void CanonicalQuery_Read_KeepsGoAndDeclareRaw()
    {
        string text = CanonicalQuery.Read(Fixture, "D");

        Assert.Contains("DECLARE @n int = 1;", text, StringComparison.Ordinal);
        Assert.Matches(@"(?m)^GO\s*$", text);
    }

    [Fact]
    public void CanonicalQuery_Read_RealFileBlockHasBodyWithoutHeader()
    {
        string text = CanonicalQuery.Read("H06-magaza.sql", "A");

        Assert.Contains("SELECT", text, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("Mağaza sayfasında indirim", text, StringComparison.Ordinal);
        Assert.DoesNotContain("-- blok:", text, StringComparison.Ordinal);
    }

    [Fact]
    public void CanonicalQuery_Read_MissingFileThrowsFileNotFound()
    {
        Assert.Throws<FileNotFoundException>(() => CanonicalQuery.Read("yok-boyle-dosya.sql", "A"));
    }

    [Fact]
    public void CanonicalQuery_Read_MissingFileWithoutBlockThrowsFileNotFound()
    {
        Assert.Throws<FileNotFoundException>(() => CanonicalQuery.Read("yok-boyle-dosya.sql"));
    }

    [Fact]
    public void CanonicalQuery_Read_DuplicateBlockNameThrows()
    {
        using TempCanonicalFile file = new("-- blok: A\nSELECT 'birinci';\n-- blok: A\nSELECT 'ikinci';\n");

        InvalidOperationException ex = Assert.Throws<InvalidOperationException>(() => CanonicalQuery.Read(file.Name, "A"));

        Assert.Contains(file.Name, ex.Message, StringComparison.Ordinal);
        Assert.Contains("birden çok", ex.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void CanonicalQuery_Read_NullBlockReturnsBodyWithoutHeader()
    {
        string text = CanonicalQuery.Read(Fixture);

        Assert.Contains("govde-A", text);
        Assert.Contains("govde-Z", text);
        Assert.DoesNotContain("SORU-METNI-BASLIK", text);
    }

    [Fact]
    public void CanonicalQuery_Read_EmptyBodyBeforeNextMarkerThrows()
    {
        using TempCanonicalFile file = new("-- blok: A\n-- blok: B\nSELECT 'dolu';\n");

        InvalidOperationException ex = Assert.Throws<InvalidOperationException>(() => CanonicalQuery.Read(file.Name, "A"));

        Assert.Contains("boş", ex.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void CanonicalQuery_Read_EmptyBodyAtEndOfFileThrows()
    {
        using TempCanonicalFile file = new("-- blok: A\nSELECT 'dolu';\n-- blok: B\n");

        Assert.Throws<InvalidOperationException>(() => CanonicalQuery.Read(file.Name, "B"));
    }

    [Fact]
    public void CanonicalQuery_Read_WhitespaceOnlyBodyThrows()
    {
        using TempCanonicalFile file = new("-- blok: A\n   \n\t\n-- blok: B\nSELECT 'dolu';\n");

        Assert.Throws<InvalidOperationException>(() => CanonicalQuery.Read(file.Name, "A"));
    }

    [Fact]
    public void CanonicalQuery_Read_RepeatedCallsAreIdenticalAndLeaveFileUntouched()
    {
        string path = Path.Combine(AppContext.BaseDirectory, "Kanonik", Fixture);
        byte[] before = File.ReadAllBytes(path);

        string first = CanonicalQuery.Read(Fixture, "A");
        string second = CanonicalQuery.Read(Fixture, "A");

        Assert.Equal(first, second);
        Assert.Equal(before, File.ReadAllBytes(path));
    }

    [Fact]
    public void CanonicalQuery_Read_MixedLineEndingsKeepBlocksApart()
    {
        using TempCanonicalFile file = new("-- blok: A\r\nSELECT 'a1';\n-- blok: B\r\nSELECT 'b1';\r\n");

        string text = CanonicalQuery.Read(file.Name, "A");

        Assert.Contains("'a1'", text, StringComparison.Ordinal);
        Assert.DoesNotContain("'b1'", text, StringComparison.Ordinal);
    }
}
