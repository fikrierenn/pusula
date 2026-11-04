using Bkm.TestAltyapi;

namespace GmDashboard.Tests.Altyapi;

// Kanonik arşiv + koruma girdileri + kırmızı-kip sahte klasörü kapıdan geçmeli (R1, FR-015).
// Birim testidir (DB yok): `Tur` Trait'i bilerek yok (K-karar-5), mesai içi komutta görünür.
[Trait("AC", "FR-015")]
[Trait("AC", "R1")]
[Collection(GmDashboard.Tests.Infrastructure.CanonicalFolderCollection.Name)]
public class CanonicalFileGateTests
{
    public static IEnumerable<object[]> AllBlocks()
    {
        return CanonicalBlockReader.Rows("Kanonik", Path.Combine("Koruma", "Eski"), Path.Combine("Altyapi", "Sahte"));
    }

    [Theory]
    [MemberData(nameof(AllBlocks))]
    public void CanonicalFiles_EveryBlock_PassesReadOnlyGate(string fileName, string block, string text)
    {
        ReadOnlyGateResult result = ReadOnlyGate.Check(text);

        Assert.True(result.Passed, $"{fileName} blok {block}: {result.Reason}");
    }

    [Fact]
    public void CanonicalFiles_Population_IsNotEmpty()
    {
        var canonical = CanonicalBlockReader.Files("Kanonik").ToList();
        var blocks = canonical.SelectMany(d => CanonicalBlockReader.Split(d.FileName, d.Text)).ToList();

        Assert.True(canonical.Count > 0, "KOŞAMADI: kanonik dosya bulunamadı");
        Assert.True(blocks.Count >= canonical.Count, "KOŞAMADI: blok bulunamadı");
    }

    [Fact]
    public void Split_MarkerMidLine_DoesNotSplit()
    {
        var blocks = CanonicalBlockReader.Split("bellek.sql", "SELECT 1 AS a -- blok: x");

        Assert.Single(blocks);
        Assert.True(ReadOnlyGate.Check(blocks[0].Text).Passed);
    }

    [Fact]
    public void Split_HeaderComment_IsNotGateStatement()
    {
        string text = "-- ork:hedef-db EncoreMerkez\n/* Soru: x */\n-- blok: A\nSELECT 1 AS a\nGO\n";

        var blocks = CanonicalBlockReader.Split("bellek.sql", text);

        Assert.Single(blocks);
        Assert.True(ReadOnlyGate.Check(blocks[0].Text).Passed);
    }

    [Fact]
    public void Split_GoLine_IsRemoved()
    {
        var blocks = CanonicalBlockReader.Split("bellek.sql", "-- blok: A\nSELECT 1\nGO\n-- blok: B\nSELECT 2");

        Assert.Equal(2, blocks.Count);
        Assert.All(blocks, b => Assert.True(ReadOnlyGate.Check(b.Text).Passed));
    }

    [Fact]
    public void Split_LeadingDeclareWithSemicolon_IsRemoved()
    {
        string text = "-- blok: A\nDECLARE @Bas date = CONVERT(date, '01.09.2026', 104), @Bit date = CONVERT(date, '01.10.2026', 104);\nSELECT @Bas AS b";

        var blocks = CanonicalBlockReader.Split("bellek.sql", text);

        Assert.DoesNotContain("DECLARE", blocks[0].Text, StringComparison.OrdinalIgnoreCase);
        Assert.True(ReadOnlyGate.Check(blocks[0].Text).Passed);
    }

    [Fact]
    public void Split_MultiLineDeclareWithSubquery_IsRemoved()
    {
        string text = "-- blok: J\nDECLARE\n    @Alt DATE\n    = (\n        SELECT MAX(x.Donem)\n        FROM dbo.t AS x\n    );\nSELECT TOP (1) b.a FROM dbo.t AS b WHERE b.Donem >= @Alt;";

        var blocks = CanonicalBlockReader.Split("bellek.sql", text);

        Assert.DoesNotContain("DECLARE", blocks[0].Text, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("SELECT TOP (1)", blocks[0].Text, StringComparison.Ordinal);
        Assert.True(ReadOnlyGate.Check(blocks[0].Text).Passed);
    }

    // K-r1-5: ';'siz baştaki DECLARE ayıklanmaz; gövde kapıya DECLARE ile girer ve reddedilir.
    [Fact]
    public void Split_LeadingDeclareWithoutSemicolon_IsKeptAndGateRejects()
    {
        var blocks = CanonicalBlockReader.Split("bellek.sql", "-- blok: A\nDECLARE @x int = 1\nSELECT @x AS a;");

        ReadOnlyGateResult result = ReadOnlyGate.Check(blocks[0].Text);

        Assert.Contains("DECLARE", blocks[0].Text, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("SELECT @x AS a", blocks[0].Text, StringComparison.Ordinal);
        Assert.False(result.Passed);
        Assert.Contains("DECLARE", result.Reason, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void Split_LeadingDeclareWithoutSemicolonFollowedByWith_IsKeptAndGateRejects()
    {
        var blocks = CanonicalBlockReader.Split("bellek.sql", "-- blok: A\nDECLARE @x int = 1\nWITH c AS (SELECT @x AS a) SELECT a FROM c;");

        ReadOnlyGateResult result = ReadOnlyGate.Check(blocks[0].Text);

        Assert.Contains("DECLARE", blocks[0].Text, StringComparison.OrdinalIgnoreCase);
        Assert.False(result.Passed);
        Assert.Contains("DECLARE", result.Reason, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void Split_DeclareInMiddle_GateRejects()
    {
        var blocks = CanonicalBlockReader.Split("bellek.sql", "-- blok: A\nSELECT 1;\nDECLARE @x int = 1;\nSELECT @x");

        ReadOnlyGateResult result = ReadOnlyGate.Check(blocks[0].Text);

        Assert.False(result.Passed);
        Assert.Contains("DECLARE", result.Reason, StringComparison.OrdinalIgnoreCase);
    }

    // K-r1-2: başlık yorumu yalnız CR ile bitse de sonrası blok gövdesi olarak kalır ve taranır.
    [Fact]
    public void Split_HeaderCommentEndingWithCarriageReturn_WriteIsNotHidden()
    {
        var blocks = CanonicalBlockReader.Split("bellek.sql", "-- blok: A\n-- x\rDECLARE @x int = 1\rDELETE FROM dbo.t;");

        ReadOnlyGateResult result = ReadOnlyGate.Check(blocks[0].Text);

        Assert.Contains("DELETE", blocks[0].Text, StringComparison.Ordinal);
        Assert.False(result.Passed);
    }

    [Fact]
    public void Split_BlockWithUpdate_GateRejects()
    {
        var blocks = CanonicalBlockReader.Split("sahte.sql", "-- blok: A\nSELECT 1 AS a\nUPDATE dbo.x SET a=1");

        ReadOnlyGateResult result = ReadOnlyGate.Check(blocks[0].Text);

        Assert.False(result.Passed);
        Assert.Contains("UPDATE", result.Reason, StringComparison.OrdinalIgnoreCase);
    }
}
