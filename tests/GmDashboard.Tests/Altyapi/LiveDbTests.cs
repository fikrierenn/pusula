using System.Text.RegularExpressions;
using Bkm.TestAltyapi;
using Xunit.Sdk;

namespace GmDashboard.Tests.Altyapi;

// LiveDb: kapı reddi bağlantıdan ÖNCE (K-karar-7b), sıra env -> kapı -> bağlantı (K-karar-6).
// Süreç-geneli BKM_ENV_DOSYA değiştiği için koleksiyon sıralı koşar.
[Collection(LiveDbEnvCollection.Name)]
[Trait("AC", "FR-015")]
[Trait("AC", "R1")]
public class LiveDbTests
{
    private const string EnvName = "BKM_ENV_DOSYA";
    private const string GatePrefix = "SALT-OKUMA KAPISI:";
    private const string EnvMessage = "KOŞAMADI: BKM_ENV_DOSYA tanımlı — hata testi ortamı sızdı";
    private const string TransactionClosedMessage = "SALT-OKUMA KAPISI: işlem sorgu içinde kapandı";
    private const string NullMessage = "KOŞAMADI: sorgu NULL döndürdü";

    // ---------- Birim: kapıdan geçmeyen SQL bağlantı açılmadan reddedilir ----------

    [Theory]
    [InlineData(DbTarget.Erp, "UPDATE dbo.x SET a = 1", "UPDATE")]
    [InlineData(DbTarget.Joker, "DELETE FROM dbo.x", "DELETE")]
    [InlineData(DbTarget.Erp, "", "boş girdi")]
    [InlineData(DbTarget.Erp, "SET LOCK_TIMEOUT 1; SELECT 1", "SET")]
    [InlineData(DbTarget.Erp, "SELECT a INTO #t FROM dbo.t", "INTO")]
    [InlineData(DbTarget.Erp, "SELECT 1 AS a COMMIT", "COMMIT")]
    [InlineData(DbTarget.Joker, "SELECT * FROM OPENQUERY(ODAKJOKER, 'dbo.usp_Yaz')", "OPENQUERY")]
    public async Task QueryAsync_SqlFailsGate_DoesNotRun(DbTarget target, string sql, string word)
    {
        using EnvScope env = new(EnvName, null);

        FailException ex = await Assert.ThrowsAsync<FailException>(() => LiveDb.QueryAsync<int>(target, sql));

        Assert.StartsWith(GatePrefix, ex.Message, StringComparison.Ordinal);
        Assert.Contains(word, ex.Message, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("bağlantı", ex.Message, StringComparison.OrdinalIgnoreCase);
    }

    [Theory]
    [InlineData(DbTarget.Erp, "SELECT 1; DROP TABLE t", "DROP")]
    [InlineData(DbTarget.Joker, "WITH c AS (SELECT 1 a) UPDATE c SET a=2", "UPDATE")]
    [InlineData(DbTarget.Erp, "SELECT 1 AS a ROLLBACK", "ROLLBACK")]
    public async Task ScalarAsync_SqlFailsGate_DoesNotRun(DbTarget target, string sql, string word)
    {
        using EnvScope env = new(EnvName, null);

        FailException ex = await Assert.ThrowsAsync<FailException>(() => LiveDb.ScalarAsync<int>(target, sql));

        Assert.StartsWith(GatePrefix, ex.Message, StringComparison.Ordinal);
        Assert.Contains(word, ex.Message, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task QueryAsync_Parameter_DoesNotBypassGate()
    {
        using EnvScope env = new(EnvName, null);

        FailException ex = await Assert.ThrowsAsync<FailException>(
            () => LiveDb.QueryAsync<int>(DbTarget.Erp, "SELECT a INTO #t FROM dbo.t", new { p = 1 }));

        Assert.StartsWith(GatePrefix, ex.Message, StringComparison.Ordinal);
    }

    [Fact]
    public async Task QueryAsync_SecondCall_GivesSameRejection()
    {
        using EnvScope env = new(EnvName, null);

        FailException first = await Assert.ThrowsAsync<FailException>(() => LiveDb.QueryAsync<int>(DbTarget.Erp, "DELETE FROM t"));
        FailException second = await Assert.ThrowsAsync<FailException>(() => LiveDb.QueryAsync<int>(DbTarget.Erp, "DELETE FROM t"));

        Assert.Equal(first.Message, second.Message);
    }

    [Fact]
    public async Task QueryAsync_UndefinedTarget_ThrowsArgumentOutOfRange()
    {
        using EnvScope env = new(EnvName, null);

        await Assert.ThrowsAsync<ArgumentOutOfRangeException>(() => LiveDb.QueryAsync<int>((DbTarget)99, "SELECT 1"));
    }

    // ---------- Birim: BKM_ENV_DOSYA ----------

    [Fact]
    public async Task QueryAsync_EnvFileSet_FailsWithCouldNotRun()
    {
        using EnvScope env = new(EnvName, @"C:\yok\x.env");

        FailException ex = await Assert.ThrowsAsync<FailException>(() => LiveDb.QueryAsync<int>(DbTarget.Erp, "SELECT 1"));

        Assert.Equal(EnvMessage, ex.Message);
    }

    [Fact]
    public async Task QueryAsync_EnvFileSetJoker_FailsWithCouldNotRun()
    {
        using EnvScope env = new(EnvName, @"C:\yok\x.env");

        FailException ex = await Assert.ThrowsAsync<FailException>(() => LiveDb.QueryAsync<int>(DbTarget.Joker, "SELECT 1"));

        Assert.Equal(EnvMessage, ex.Message);
    }

    [Fact]
    public async Task ScalarAsync_EnvFileSet_FailsWithCouldNotRun()
    {
        using EnvScope env = new(EnvName, @"C:\yok\x.env");

        FailException ex = await Assert.ThrowsAsync<FailException>(() => LiveDb.ScalarAsync<int>(DbTarget.Erp, "SELECT 1"));

        Assert.Equal(EnvMessage, ex.Message);
    }

    [Fact]
    public async Task QueryAsync_EnvFileSetAndSqlFailsGate_EnvCheckFirst()
    {
        using EnvScope env = new(EnvName, @"C:\yok\x.env");

        FailException ex = await Assert.ThrowsAsync<FailException>(() => LiveDb.QueryAsync<int>(DbTarget.Erp, "UPDATE dbo.x SET a=1"));

        Assert.Equal(EnvMessage, ex.Message);
        Assert.DoesNotContain("SALT-OKUMA", ex.Message, StringComparison.Ordinal);
    }

    [Fact]
    public async Task QueryAsync_EnvFileSetAndTokenCanceled_GivesEnvMessage()
    {
        using EnvScope env = new(EnvName, @"C:\yok\x.env");

        FailException ex = await Assert.ThrowsAsync<FailException>(
            () => LiveDb.QueryAsync<int>(DbTarget.Erp, "SELECT 1", null, new CancellationToken(true)));

        Assert.Equal(EnvMessage, ex.Message);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    public async Task QueryAsync_EnvFileBlank_GateRejectionComes(string? value)
    {
        using EnvScope env = new(EnvName, value);

        FailException ex = await Assert.ThrowsAsync<FailException>(() => LiveDb.QueryAsync<int>(DbTarget.Erp, "UPDATE dbo.x SET a=1"));

        Assert.StartsWith(GatePrefix, ex.Message, StringComparison.Ordinal);
        Assert.DoesNotContain(EnvName, ex.Message, StringComparison.Ordinal);
    }

    // ---------- Birim: kaynak metin (K-karar-8, K-r1-3) ----------

    [Fact]
    public void Source_HasNoExecuteAsyncCall()
    {
        string source = ReadSource();

        Assert.DoesNotContain("ExecuteAsync", source, StringComparison.Ordinal);
    }

    [Fact]
    public void Source_RollbackInFinallyAndNoCommit()
    {
        string source = ReadSource();

        Assert.Matches(new Regex(@"finally\s*\{[^}]*Rollback\(\)", RegexOptions.Singleline), source);
        Assert.DoesNotContain("Commit(", source, StringComparison.Ordinal);
    }

    [Fact]
    public void Source_SessionSetIsFixedTextOutsideGate()
    {
        string source = ReadSource();

        Assert.Contains("SET LOCK_TIMEOUT 5000; SET DEADLOCK_PRIORITY LOW;", source, StringComparison.Ordinal);
        Assert.DoesNotMatch(new Regex(@"SET DEADLOCK_PRIORITY LOW;""\s*\+|\$""[^""]*SET LOCK_TIMEOUT"), source);
    }

    [Fact]
    public void Source_CommandTimeoutAndTransactionPassed()
    {
        string source = ReadSource();

        Assert.Contains("commandTimeout: 240", source, StringComparison.Ordinal);
        Assert.Contains("transaction: tx", source, StringComparison.Ordinal);
    }

    // K-r1-3: sorgudan sonra aynı bağlantı ve işlemde @@TRANCOUNT okunur; 1 değilse Fail.
    // İhlal girdisi (COMMIT/ROLLBACK) bugünkü kapıda reddedildiği için canlıda sınanamaz; denetimin varlığı kaynakta sınanır.
    [Fact]
    public void Source_ChecksTranCountAfterQuery()
    {
        string source = ReadSource();

        Assert.Contains("SELECT @@TRANCOUNT", source, StringComparison.Ordinal);
        Assert.Contains(TransactionClosedMessage, source, StringComparison.Ordinal);
    }

    // K-r1-3: geri alma yalnız işlem bağlantısı hâlâ geçerliyse yapılır.
    // Sunucunun işlemi kendisi bitirmesi (1205 kurbanı, bağlantı kopması) canlıda belirlenimli üretilemiyor; kaynakta sınanır.
    [Fact]
    public void Source_RollbackGuardedByLiveConnection()
    {
        string source = ReadSource();

        Assert.Matches(
            new Regex(@"\.Connection\s*(?:is\s+not\s+null|!=\s*null)[^;]*?\w+\.Rollback\(\)", RegexOptions.Singleline),
            source);
    }

    // K-r1-3: geri alma kendisi patlarsa asıl istisna korunur: Rollback kendi try/catch'i içinde.
    [Fact]
    public void Source_RollbackFailureDoesNotHideOriginalException()
    {
        string source = ReadSource();

        Assert.Matches(
            new Regex(@"try\s*\{[^}]*\w+\.Rollback\(\);(?:\s*\})+\s*catch", RegexOptions.Singleline),
            source);
    }

    // ---------- Canlı (ERP/JOKER; mesai dışı koşulur) ----------

    [Fact]
    [Trait("Tur", "Canli")]
    public async Task ScalarAsync_ErpSelectOne_ReturnsOne()
    {
        using EnvScope env = new(EnvName, null);

        int value = await LiveDb.ScalarAsync<int>(DbTarget.Erp, "SELECT 1");

        Assert.Equal(1, value);
    }

    [Fact]
    [Trait("Tur", "Canli")]
    public async Task ScalarAsync_JokerSelectOne_ReturnsOne()
    {
        using EnvScope env = new(EnvName, null);

        int value = await LiveDb.ScalarAsync<int>(DbTarget.Joker, "SELECT 1");

        Assert.Equal(1, value);
    }

    [Fact]
    [Trait("Tur", "Canli")]
    public async Task QueryAsync_TwoRows_ReturnsBoth()
    {
        using EnvScope env = new(EnvName, null);

        IReadOnlyList<int> rows = await LiveDb.QueryAsync<int>(DbTarget.Erp, "SELECT 1 AS a UNION ALL SELECT 2");

        Assert.Equal(new[] { 1, 2 }, rows.Order());
    }

    [Fact]
    [Trait("Tur", "Canli")]
    public async Task QueryAsync_NoRows_ReturnsEmptyList()
    {
        using EnvScope env = new(EnvName, null);

        IReadOnlyList<int> rows = await LiveDb.QueryAsync<int>(DbTarget.Erp, "SELECT 1 AS a WHERE 1 = 0");

        Assert.NotNull(rows);
        Assert.Empty(rows);
    }

    [Fact]
    [Trait("Tur", "Canli")]
    public async Task ScalarAsync_Query_RunsInsideTransaction()
    {
        using EnvScope env = new(EnvName, null);

        int tranCount = await LiveDb.ScalarAsync<int>(DbTarget.Erp, "SELECT @@TRANCOUNT");

        Assert.Equal(1, tranCount);
    }

    // K-r1-3 (b): kapıdan geçen meşru SELECT işlemi açık bırakır; sonradan @@TRANCOUNT denetimi Fail VERMEZ.
    // Kapıdan geçip işlemi kapatan bir girdi bugün yok (COMMIT/ROLLBACK reddedilir); ihlal yolu canlıda sınanamaz.
    [Fact]
    [Trait("Tur", "Canli")]
    public async Task QueryAsync_LegitimateCteSelect_TransactionStaysOpenAndRowsReturn()
    {
        using EnvScope env = new(EnvName, null);

        IReadOnlyList<int> rows = await LiveDb.QueryAsync<int>(
            DbTarget.Erp,
            "WITH c AS (SELECT 1 AS a UNION ALL SELECT 2) SELECT a + @@TRANCOUNT - 1 AS a FROM c");

        Assert.Equal(new[] { 1, 2 }, rows.Order());
    }

    [Fact]
    [Trait("Tur", "Canli")]
    public async Task ScalarAsync_Query_LockTimeoutApplied()
    {
        using EnvScope env = new(EnvName, null);

        int lockTimeout = await LiveDb.ScalarAsync<int>(DbTarget.Erp, "SELECT @@LOCK_TIMEOUT");

        Assert.Equal(5000, lockTimeout);
    }

    [Fact]
    [Trait("Tur", "Canli")]
    public async Task ScalarAsync_Query_DeadlockPriorityIsLow()
    {
        using EnvScope env = new(EnvName, null);

        int priority = await LiveDb.ScalarAsync<int>(
            DbTarget.Erp,
            "SELECT deadlock_priority FROM sys.dm_exec_sessions WHERE session_id = @@SPID");

        Assert.Equal(-5, priority);
    }

    [Fact]
    [Trait("Tur", "Canli")]
    public async Task ScalarAsync_ConsecutiveCalls_DoNotLeakTransaction()
    {
        using EnvScope env = new(EnvName, null);

        int first = await LiveDb.ScalarAsync<int>(DbTarget.Erp, "SELECT @@TRANCOUNT");
        int second = await LiveDb.ScalarAsync<int>(DbTarget.Erp, "SELECT @@TRANCOUNT");

        Assert.Equal(1, first);
        Assert.Equal(1, second);
    }

    [Fact]
    [Trait("Tur", "Canli")]
    public async Task QueryAsync_DivideByZero_SqlExceptionSurfaces()
    {
        using EnvScope env = new(EnvName, null);

        await Assert.ThrowsAsync<Microsoft.Data.SqlClient.SqlException>(() => LiveDb.QueryAsync<int>(DbTarget.Erp, "SELECT 1/0"));
        int after = await LiveDb.ScalarAsync<int>(DbTarget.Erp, "SELECT 1");

        Assert.Equal(1, after);
    }

    [Fact]
    [Trait("Tur", "Canli")]
    public async Task QueryAsync_ParameterValue_BoundVerbatim()
    {
        using EnvScope env = new(EnvName, null);
        string injectionText = "'; DROP TABLE x;--";

        IReadOnlyList<string> rows = await LiveDb.QueryAsync<string>(DbTarget.Erp, "SELECT @p AS a", new { p = injectionText });

        Assert.Equal(new[] { injectionText }, rows);
    }

    [Fact]
    [Trait("Tur", "Canli")]
    public async Task QueryAsync_IntegerParameter_IsBound()
    {
        using EnvScope env = new(EnvName, null);

        IReadOnlyList<int> rows = await LiveDb.QueryAsync<int>(DbTarget.Erp, "SELECT @n AS a", new { n = 5 });

        Assert.Equal(new[] { 5 }, rows);
    }

    [Fact]
    [Trait("Tur", "Canli")]
    public async Task QueryAsync_ThreePartName_WorksInMasterContext()
    {
        using EnvScope env = new(EnvName, null);

        int count = await LiveDb.ScalarAsync<int>(DbTarget.Erp, "SELECT COUNT(*) FROM DerinSISBkm.dbo.urn");

        Assert.True(count > 0, "KOŞAMADI: urn nüfusu 0");
    }

    [Fact]
    [Trait("Tur", "Canli")]
    public async Task PanelDb_OpensConnections()
    {
        using EnvScope env = new(EnvName, null);
        var db = LiveDb.PanelDb();

        using var erp = await db.OpenAsync();
        using var joker = await db.OpenJokerAsync();

        Assert.Equal(System.Data.ConnectionState.Open, erp.State);
        Assert.Equal(System.Data.ConnectionState.Open, joker.State);
    }

    [Fact]
    [Trait("Tur", "Canli")]
    public async Task ScalarAsync_NoRows_FailsWithCouldNotRun()
    {
        using EnvScope env = new(EnvName, null);

        FailException ex = await Assert.ThrowsAsync<FailException>(
            () => LiveDb.ScalarAsync<int>(DbTarget.Erp, "SELECT 1 AS a WHERE 1 = 0"));

        Assert.Contains("KOŞAMADI: sorgu satır döndürmedi", ex.Message, StringComparison.Ordinal);
    }

    [Fact]
    [Trait("Tur", "Canli")]
    public async Task ScalarAsync_MultipleRows_Fails()
    {
        using EnvScope env = new(EnvName, null);

        FailException ex = await Assert.ThrowsAsync<FailException>(
            () => LiveDb.ScalarAsync<int>(DbTarget.Erp, "SELECT 1 AS a UNION ALL SELECT 2"));

        Assert.Contains("tek değer bekleniyordu", ex.Message, StringComparison.Ordinal);
    }

    // K-r1-4: nullable olmayan T için NULL tek değer "0" olarak yutulmaz, KOŞAMADI ile kırılır.
    [Fact]
    [Trait("Tur", "Canli")]
    public async Task ScalarAsync_NullIntoNonNullable_FailsWithCouldNotRun()
    {
        using EnvScope env = new(EnvName, null);

        FailException ex = await Assert.ThrowsAsync<FailException>(
            () => LiveDb.ScalarAsync<int>(DbTarget.Erp, "SELECT CAST(NULL AS int) AS v"));

        Assert.Equal(NullMessage, ex.Message);
    }

    // K-r1-4: nullable T için NULL meşru sonuçtur.
    [Fact]
    [Trait("Tur", "Canli")]
    public async Task ScalarAsync_NullIntoNullable_ReturnsNull()
    {
        using EnvScope env = new(EnvName, null);

        int? value = await LiveDb.ScalarAsync<int?>(DbTarget.Erp, "SELECT CAST(NULL AS int) AS v");

        Assert.Null(value);
    }

    // ---------- Yardımcı ----------

    private static string ReadSource()
    {
        DirectoryInfo? root = Enumerable
            .Repeat(0, 12)
            .Aggregate<int, DirectoryInfo?>(
                new DirectoryInfo(AppContext.BaseDirectory),
                (folder, _) => ((folder is null) || File.Exists(Path.Combine(folder.FullName, "Pusula.sln"))) ? folder : folder.Parent);

        Assert.True(root is not null && File.Exists(Path.Combine(root.FullName, "Pusula.sln")), "KOŞAMADI: depo kökü bulunamadı");

        return File.ReadAllText(Path.Combine(root!.FullName, "lib", "Bkm.TestAltyapi", "LiveDb.cs"));
    }
}
