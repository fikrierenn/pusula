using Bkm.TestAltyapi;
using Xunit.Sdk;

namespace GmDashboard.Tests.Infrastructure;

// SourceFile.Read (T-023): depo kökü bulma, depo dışına çıkış reddi. Yalıtılmış sahte depo geçici dizinde kurulur;
// gizli dosya depo DIŞINDA durur, böylece "içerik dönmedi" iddiası gerçekten sınanır. Birim testidir; Trait'siz.
public class SourceFileTests : IDisposable
{
    private const string OutsideText = "GIZLI-DEPO-DISI";

    private readonly string _outer;
    private readonly string _repo;
    private readonly string _sub;

    public SourceFileTests()
    {
        _outer = Directory.CreateTempSubdirectory("pusula-srcfile-").FullName;
        _repo = Path.Combine(_outer, "repo");
        _sub = Path.Combine(_repo, "sub");
        Directory.CreateDirectory(_sub);
        File.WriteAllText(Path.Combine(_repo, "Pusula.sln"), "fake");
        File.WriteAllText(Path.Combine(_repo, "ok.txt"), "ICERIK-OK");
        File.WriteAllText(Path.Combine(_sub, "inner.txt"), "ICERIK-INNER");
        File.WriteAllText(Path.Combine(_outer, "outside.txt"), OutsideText);
    }

    public void Dispose()
    {
        Directory.Delete(_outer, recursive: true);
    }

    [Fact]
    public void SourceFile_Read_RealRepoFileReturnsContent()
    {
        string text = SourceFile.Read("CLAUDE.md");

        Assert.Contains("Pusula", text, StringComparison.Ordinal);
    }

    [Fact]
    public void SourceFile_Read_SubfolderPathWithSlashesWorks()
    {
        string text = SourceFile.Read("sorgular/2026-10-panel-veri-duzeltme/H06-magaza.sql");

        Assert.Contains("SELECT", text, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void SourceFile_Read_BackslashSeparatorWorks()
    {
        string text = SourceFile.Read(@"sorgular\2026-10-panel-veri-duzeltme\H06-magaza.sql");

        Assert.Contains("SELECT", text, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void SourceFile_Read_StartDirectoryInsideRepoFindsRoot()
    {
        string text = SourceFile.Read("ok.txt", _sub);

        Assert.Equal("ICERIK-OK", text);
    }

    [Fact]
    public void SourceFile_Read_ParentTraversalIsRejectedAndOutsideTextNotReturned()
    {
        ArgumentException ex = Assert.ThrowsAny<ArgumentException>(() => SourceFile.Read("../outside.txt", _repo));

        Assert.DoesNotContain(OutsideText, ex.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void SourceFile_Read_NestedTraversalOutOfRepoIsRejected()
    {
        Assert.ThrowsAny<ArgumentException>(() => SourceFile.Read("sub/../../outside.txt", _repo));
    }

    [Fact]
    public void SourceFile_Read_TraversalThatStaysInsideRepoIsAllowed()
    {
        string text = SourceFile.Read("sub/../ok.txt", _repo);

        Assert.Equal("ICERIK-OK", text);
    }

    [Fact]
    public void SourceFile_Read_AbsolutePathOutsideRepoIsRejected()
    {
        string absolute = Path.Combine(_outer, "outside.txt");

        Assert.ThrowsAny<ArgumentException>(() => SourceFile.Read(absolute, _repo));
    }

    [Fact]
    public void SourceFile_Read_MissingFileThrowsFileNotFound()
    {
        Assert.Throws<FileNotFoundException>(() => SourceFile.Read("yok.txt", _repo));
    }

    [Fact]
    public void SourceFile_Read_NoSolutionFileUpwardsGivesCouldNotRun()
    {
        string isolated = Directory.CreateTempSubdirectory("pusula-yalitik-").FullName;
        try
        {
            XunitException ex = Assert.ThrowsAny<XunitException>(() => SourceFile.Read("ok.txt", isolated));

            Assert.Equal("KOŞAMADI: depo kökü bulunamadı", ex.Message);
        }
        finally
        {
            Directory.Delete(isolated, recursive: true);
        }
    }

    [Fact]
    public void SourceFile_Read_EmptyPathIsRejected()
    {
        Assert.ThrowsAny<ArgumentException>(() => SourceFile.Read(string.Empty, _repo));
    }

    [Fact]
    public void SourceFile_Read_DoubleDotInsideFileNameIsNotTraversal()
    {
        Assert.Throws<FileNotFoundException>(() => SourceFile.Read("a..b.sql", _repo));
    }

    [Fact]
    public void SourceFile_Read_DirectoryPathIsNotAFile()
    {
        Assert.Throws<FileNotFoundException>(() => SourceFile.Read("sub", _repo));
    }
}
