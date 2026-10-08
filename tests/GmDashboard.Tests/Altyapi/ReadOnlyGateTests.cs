using Bkm.TestAltyapi;

namespace GmDashboard.Tests.Altyapi;

// Kapı SÖZDİZİMİ kapısıdır (R1, FR-015): tanınmayan her şey reddedilir; dize/yorum/tanımlayıcı içindeki kelime geçer.
// Ret beklentisi her satırda reddedilen kelimeyi (ya da yapı hatasını) Reason'da arar: Reason doğrulanmadan RET yeşil olmaz (K-r1-9).
[Trait("AC", "FR-015")]
[Trait("AC", "R1")]
public class ReadOnlyGateTests
{
    [Theory]
    [InlineData("WITH x AS (SELECT 1 AS a) UPDATE x SET a = 2", "UPDATE")]
    [InlineData("SELECT a INTO #t FROM dbo.t", "INTO")]
    [InlineData("SELECT 1; EXEC sp_x", "EXEC")]
    [InlineData("/* SELECT */ DELETE FROM t", "DELETE")]
    [InlineData("SELECT 1 -- \nDROP TABLE t", "DROP")]
    [InlineData("MERGE dbo.t AS x USING dbo.s AS y ON x.a = y.a WHEN MATCHED THEN DELETE;", "MERGE")]
    [InlineData("TRUNCATE TABLE t", "TRUNCATE")]
    [InlineData("INSERT INTO dbo.t (a) VALUES (1)", "INSERT")]
    [InlineData("UPDATE dbo.x SET a = 1", "UPDATE")]
    [InlineData("DELETE FROM dbo.t", "DELETE")]
    [InlineData("EXEC sp_who", "EXEC")]
    [InlineData("EXECUTE sp_who", "EXECUTE")]
    [InlineData("DROP TABLE dbo.t", "DROP")]
    [InlineData("ALTER TABLE dbo.t ADD c int", "ALTER")]
    [InlineData("CREATE TABLE dbo.t (a int)", "CREATE")]
    [InlineData("GRANT SELECT ON dbo.t TO public", "GRANT")]
    [InlineData("REVOKE SELECT ON dbo.t FROM public", "REVOKE")]
    [InlineData("DENY SELECT ON dbo.t TO public", "DENY")]
    [InlineData("SET NOCOUNT ON", "SET")]
    [InlineData("USE master", "USE")]
    [InlineData("DBCC CHECKDB", "DBCC")]
    [InlineData("BACKUP DATABASE BKM TO DISK = 'x'", "BACKUP")]
    [InlineData("RESTORE DATABASE BKM FROM DISK = 'x'", "RESTORE")]
    [InlineData("KILL 55", "KILL")]
    [InlineData("SHUTDOWN", "SHUTDOWN")]
    [InlineData("SELECT * FROM OPENROWSET('SQLNCLI','Server=x;','SELECT 1')", "OPENROWSET")]
    [InlineData("SELECT * FROM OPENDATASOURCE('SQLNCLI','Data Source=x').db.dbo.t", "OPENDATASOURCE")]
    [InlineData("SELECT * FROM OPENROWSET(BULK 'c:\\x.txt', SINGLE_CLOB) AS b", "OPENROWSET")]
    [InlineData("BULK INSERT dbo.t FROM 'c:\\x.txt'", "BULK")]
    [InlineData("SELECT * FROM OPENQUERY(ODAKJOKER, 'UPDATE t SET a=1')", "OPENQUERY")]
    public void Check_WriteForms_Rejects(string sql, string expectedWord)
    {
        ReadOnlyGateResult result = ReadOnlyGate.Check(sql);

        Assert.False(result.Passed);
        Assert.NotNull(result.Reason);
        Assert.Contains(expectedWord, result.Reason, StringComparison.OrdinalIgnoreCase);
    }

    // Güvenlik incelemesi r0 atlatma girdileri (T-021-duzeltme-r1.md G1–G10). Hepsi bugünkü kapıdan GEÇİYORDU.
    // Beklenen kelime: girdide sırayla ilk yasak kelime.
    [Theory]
    [InlineData("SELECT 1 DISABLE TRIGGER ALL ON dbo.t COMMIT", "DISABLE")]
    [InlineData("SELECT 1 AS a COMMIT", "COMMIT")]
    [InlineData("SELECT 1 AS a ROLLBACK", "ROLLBACK")]
    [InlineData("SELECT 1 AS a WRITETEXT dbo.t.c @p 'x'", "WRITETEXT")]
    [InlineData("SELECT * FROM OPENQUERY(ODAKJOKER, 'SELECT * FROM OPENQUERY(DERINSIS, ''DELETE FROM t'')')", "OPENQUERY")]
    [InlineData("SELECT * FROM OPENQUERY(ODAKJOKER, 'dbo.usp_Yaz')", "OPENQUERY")]
    [InlineData("SELECT TOP (1) 1 AS a FROM dbo.irsHrk WITH (TABLOCKX, HOLDLOCK) WAITFOR DELAY '00:03:59'", "TABLOCKX")]
    [InlineData("SELECT NEXT VALUE FOR dbo.seq", "NEXT")]
    [InlineData("SELECT 1 AS a --x\rDELETE FROM dbo.t", "DELETE")]
    [InlineData("SELECT 1 AS a DECLARE @x int", "DECLARE")]
    public void Check_SecurityReviewBypassInputs_Rejects(string sql, string expectedWord)
    {
        ReadOnlyGateResult result = ReadOnlyGate.Check(sql);

        Assert.False(result.Passed);
        Assert.NotNull(result.Reason);
        Assert.Contains(expectedWord, result.Reason, StringComparison.OrdinalIgnoreCase);
    }

    // K-r1-1: her yeni yasak kelime için en az bir satır; kelime ';'siz, SELECT'ten sonra her konumda yakalanır.
    [Theory]
    [InlineData("SELECT 1 AS a COMMIT TRANSACTION", "COMMIT")]
    [InlineData("SELECT 1 AS a ROLLBACK TRANSACTION", "ROLLBACK")]
    [InlineData("SELECT 1 AS a SAVE TRANSACTION s1", "SAVE")]
    [InlineData("SELECT 1 AS a BEGIN TRANSACTION", "BEGIN")]
    [InlineData("SELECT 1 AS a DECLARE @p varbinary(16)", "DECLARE")]
    [InlineData("SELECT 1 AS a WRITETEXT dbo.t.c @p 'x'", "WRITETEXT")]
    [InlineData("SELECT 1 AS a UPDATETEXT dbo.t.c @p 0 NULL 'x'", "UPDATETEXT")]
    [InlineData("SELECT 1 AS a READTEXT dbo.t.c @p 0 1", "READTEXT")]
    [InlineData("SELECT 1 AS a DISABLE TRIGGER ALL ON dbo.t", "DISABLE")]
    [InlineData("SELECT 1 AS a ENABLE TRIGGER ALL ON dbo.t", "ENABLE")]
    [InlineData("SELECT 1 AS a SEND ON CONVERSATION @h ('x')", "SEND")]
    [InlineData("SELECT 1 AS a RECEIVE TOP (1) b FROM dbo.q", "RECEIVE")]
    [InlineData("SELECT 1 AS a WAITFOR DELAY '00:00:01'", "WAITFOR")]
    [InlineData("SELECT 1 AS a RECONFIGURE", "RECONFIGURE")]
    [InlineData("SELECT 1 AS a CHECKPOINT", "CHECKPOINT")]
    [InlineData("SELECT * FROM OPENQUERY(ODAKJOKER, 'SELECT ORDERID FROM J_ORDERS WHERE ORDERDATE >= ''20260901''')", "OPENQUERY")]
    [InlineData("SELECT a FROM t WITH (TABLOCKX)", "TABLOCKX")]
    [InlineData("SELECT a FROM t WITH (TABLOCK)", "TABLOCK")]
    [InlineData("SELECT a FROM t WITH (XLOCK)", "XLOCK")]
    [InlineData("SELECT a FROM t WITH (UPDLOCK)", "UPDLOCK")]
    [InlineData("SELECT a FROM t WITH (HOLDLOCK)", "HOLDLOCK")]
    [InlineData("SELECT a FROM t WITH (PAGLOCK)", "PAGLOCK")]
    [InlineData("SELECT a FROM t WITH (NOLOCK, XLOCK, HOLDLOCK)", "XLOCK")]
    [InlineData("SELECT NEXT VALUE FOR dbo.seq AS n", "NEXT")]
    [InlineData("SELECT next value for dbo.seq", "NEXT")]
    [InlineData("SELECT NEXT /* x */ VALUE FOR dbo.seq", "NEXT")]
    [InlineData("SELECT NEXT\nVALUE FOR dbo.seq", "NEXT")]
    [InlineData("select 1 as a commit", "COMMIT")]
    [InlineData("SELECT 1 AS a;COMMIT", "COMMIT")]
    [InlineData("WITH c AS (SELECT 1 AS a) SELECT a FROM c ROLLBACK", "ROLLBACK")]
    // K-r1-1 sınırı: MERGE JOIN / USE HINT içeren meşru SQL güvenli yönde reddedilir.
    [InlineData("SELECT a FROM t OPTION (MERGE JOIN)", "MERGE")]
    [InlineData("SELECT a FROM t OPTION (USE HINT ('DISABLE_OPTIMIZER_ROWGOAL'))", "USE")]
    public void Check_NewForbiddenWordAnyPosition_Rejects(string sql, string expectedWord)
    {
        ReadOnlyGateResult result = ReadOnlyGate.Check(sql);

        Assert.False(result.Passed);
        Assert.NotNull(result.Reason);
        Assert.Contains(expectedWord, result.Reason, StringComparison.OrdinalIgnoreCase);
    }

    // K-r1-2: `--` yorumu \n, \r, U+0085, U+2028, U+2029'dan herhangi biriyle biter; sonrası taranır.
    [Theory]
    [InlineData("SELECT 1 AS a --x\rDELETE FROM dbo.t", "DELETE")]
    [InlineData("SELECT 1 AS a --x\u0085DELETE FROM dbo.t", "DELETE")]
    [InlineData("SELECT 1 AS a --x\u2028DELETE FROM dbo.t", "DELETE")]
    [InlineData("SELECT 1 AS a --x\u2029DELETE FROM dbo.t", "DELETE")]
    [InlineData("SELECT 1 AS a --x\rUPDATE dbo.t SET a = 1", "UPDATE")]
    [InlineData("SELECT 1 AS a --x\u2028; DROP TABLE t", "DROP")]
    [InlineData("SELECT 1 AS a --x\u0085COMMIT", "COMMIT")]
    [InlineData("SELECT 1 AS a --x\nDELETE FROM dbo.t", "DELETE")]
    public void Check_LineCommentEndsAtAnyLineBreak_Rejects(string sql, string expectedWord)
    {
        ReadOnlyGateResult result = ReadOnlyGate.Check(sql);

        Assert.False(result.Passed);
        Assert.NotNull(result.Reason);
        Assert.Contains(expectedWord, result.Reason, StringComparison.OrdinalIgnoreCase);
    }

    [Theory]
    [InlineData("WITH a AS (SELECT 1 x), b AS (SELECT 2 y) DELETE FROM t", "DELETE")]
    [InlineData("WITH c AS (SELECT 1 a) INSERT INTO t SELECT a FROM c", "INSERT")]
    [InlineData("WITH c AS (SELECT 1 a) MERGE t USING c ON 1=1 WHEN MATCHED THEN DELETE;", "MERGE")]
    [InlineData("WITH c AS (SELECT 1 a) EXEC sp_x", "EXEC")]
    [InlineData("WITH c AS (SELECT 1 a)", "WITH sonrası SELECT yok")]
    [InlineData("WITH c AS (SELECT 1 a) SELECT a INTO #t FROM c", "INTO")]
    [InlineData("SELECT 1; DELETE FROM t", "DELETE")]
    [InlineData("SELECT 1;DELETE FROM t", "DELETE")]
    [InlineData("SELECT 1;\tDELETE FROM t", "DELETE")]
    [InlineData("SELECT 1;\u00A0DELETE FROM t", "DELETE")]
    [InlineData("SELECT 1\nDELETE FROM t", "DELETE")]
    [InlineData("SELECT 1 /* x */ ; /* y */ DROP TABLE t", "DROP")]
    [InlineData("SELECT 1/**/;DROP TABLE t", "DROP")]
    [InlineData("SELECT 1 /* ' */ ; DROP TABLE t", "DROP")]
    [InlineData("SELECT 1 -- '\n; DROP TABLE t", "DROP")]
    [InlineData("SELECT '/*' ; DROP TABLE t -- */", "DROP")]
    [InlineData("SELECT '--' AS a; DROP TABLE t", "DROP")]
    [InlineData("SELECT 1 /* -- */ ; DELETE FROM t", "DELETE")]
    [InlineData("SELECT 1 -- /*\n; DELETE FROM t\n-- */", "DELETE")]
    [InlineData("SELECT 1 -- yorum\r\nDROP TABLE t", "DROP")]
    [InlineData("SELECT 1 --a\n--b\n; DROP TABLE t", "DROP")]
    [InlineData("SELECT N'it''s'; DROP TABLE t", "DROP")]
    [InlineData("SELECT 'a'''; UPDATE t SET a = 1", "UPDATE")]
    [InlineData("SELECT N''; UPDATE t SET a = 1", "UPDATE")]
    [InlineData("SELECT 1 /* a /* b */ c */ ; DROP TABLE t", "DROP")]
    [InlineData("select 1; delete from t", "DELETE")]
    [InlineData("SeLeCt 1; DeLeTe FrOm t", "DELETE")]
    [InlineData("delete from t", "DELETE")]
    [InlineData("uPdAtE t SET a=1", "UPDATE")]
    [InlineData("dRoP table t", "DROP")]
    [InlineData("SELECT a INTO dbo.t2 FROM dbo.t", "INTO")]
    [InlineData("SELECT a INTO ##g FROM dbo.t", "INTO")]
    [InlineData("SELECT 1\nGO\nUPDATE t SET a = 1", "UPDATE")]
    [InlineData("DECLARE @x date = CONVERT(date,'01.09.2026',104); SELECT @x", "DECLARE")]
    [InlineData("SELECT 1 WHERE 1=1; ; DROP TABLE t", "DROP")]
    [InlineData(";DROP TABLE t", "DROP")]
    [InlineData("SELECT 1 SELECT 2 UPDATE t SET a=1", "UPDATE")]
    public void Check_HiddenWrite_Rejects(string sql, string expectedWord)
    {
        ReadOnlyGateResult result = ReadOnlyGate.Check(sql);

        Assert.False(result.Passed);
        Assert.NotNull(result.Reason);
        Assert.Contains(expectedWord, result.Reason, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void Check_LowercaseInsertUnderTurkishCulture_Rejects()
    {
        using CultureScope culture = new("tr-TR");

        ReadOnlyGateResult result = ReadOnlyGate.Check("insert into t values (1)");

        Assert.False(result.Passed);
        Assert.Contains("INSERT", result.Reason, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void Check_LowercaseCommitUnderTurkishCulture_Rejects()
    {
        using CultureScope culture = new("tr-TR");

        ReadOnlyGateResult result = ReadOnlyGate.Check("select 1 as a commit");

        Assert.False(result.Passed);
        Assert.Contains("COMMIT", result.Reason, StringComparison.OrdinalIgnoreCase);
    }

    [Theory]
    [InlineData("SELECT 'DELETE' AS a")]
    [InlineData("SELECT 1 /* UPDATE */")]
    [InlineData("WITH c AS (SELECT 1 AS a) SELECT a FROM c")]
    [InlineData("SELECT N'DROP TABLE t' AS a")]
    [InlineData("SELECT 1 -- DROP TABLE t")]
    [InlineData("SELECT 1 -- DELETE\n, 2 AS b")]
    [InlineData("SELECT 1 AS a --x\r, 2 AS b")]
    [InlineData("SELECT 1 AS a --x\u2028, 2 AS b")]
    [InlineData("SELECT N'it''s DELETE' AS a")]
    [InlineData("SELECT '''' AS q")]
    [InlineData("SELECT 'a''; DROP TABLE t; --' AS a")]
    [InlineData("SELECT 'a;b' AS a")]
    [InlineData("SELECT 1 /* a /* UPDATE */ b */")]
    [InlineData("SELECT 1 /* -- */")]
    [InlineData("SELECT '--' AS a")]
    [InlineData("SELECT '/*' AS a")]
    [InlineData("SELECT/**/1")]
    [InlineData("SELECT 1 AS a; -- sonda yorum")]
    [InlineData("SELECT 1;")]
    [InlineData("SELECT 1 ;  \n  ")]
    [InlineData("WITH c(a, b) AS (SELECT 1, 2) SELECT a FROM c")]
    [InlineData("WITH a AS (SELECT 1 x), b AS (SELECT 2 y) SELECT x, y FROM a, b")]
    [InlineData("WITH c AS (SELECT (1+2) a, 'x)' b) SELECT a FROM c")]
    [InlineData("WITH c AS (SELECT 1 a UNION ALL SELECT a+1 FROM c WHERE a<5) SELECT a FROM c")]
    [InlineData("select 1")]
    [InlineData("SeLeCt 1")]
    [InlineData("with c as (select 1 a) select a from c")]
    [InlineData("\r\n\t  SELECT 1")]
    [InlineData("/* başlık */\n-- açıklama\nSELECT 1")]
    [InlineData("SELECT 1 AS İşlem, N'Çok Şeker' AS ğ")]
    [InlineData("SELECT 'COMMIT' AS a, N'ROLLBACK TRANSACTION' AS b")]
    [InlineData("SELECT 1 /* WAITFOR DELAY '00:01:00' */")]
    [InlineData("SELECT 1 AS a -- DECLARE @x int")]
    public void Check_WordInsideStringOrComment_Passes(string sql)
    {
        ReadOnlyGateResult result = ReadOnlyGate.Check(sql);

        Assert.True(result.Passed, result.Reason);
        Assert.Null(result.Reason);
    }

    [Fact]
    public void Check_TurkishCharacterSelectUnderTurkishCulture_Passes()
    {
        using CultureScope culture = new("tr-TR");

        ReadOnlyGateResult result = ReadOnlyGate.Check("SELECT 1 AS İşlem, N'Çok Şeker' AS ğ");

        Assert.True(result.Passed, result.Reason);
    }

    [Theory]
    [InlineData("SELECT a FROM dbo.t x WITH(NOLOCK)")]
    [InlineData("SELECT STUFF((SELECT ',' + n FROM dbo.t FOR XML PATH('')), 1, 1, '') AS l")]
    [InlineData("SELECT a FROM DerinSISBkm.dbo.irsHrk")]
    [InlineData("SELECT a FROM EncoreMerkez.dbo.Sales s CROSS APPLY (SELECT COUNT(*) c FROM EncoreMerkez.dbo.SalesProducts WHERE SalesId = s.Id AND IsValid = 1) sp")]
    [InlineData("SELECT * FROM ODAKJOKER.JOKER.dbo.J_ORDERS")]
    [InlineData("SELECT CONVERT(date, '01.09.2026', 104) AS d, ISNULL(x, 0) FROM t WHERE y > @start AND y < @end")]
    [InlineData("SELECT a AS Updated, b AS Deleted, c AS InsertedBy, d AS Dropdown, e AS Setting, f AS Usepoint FROM t")]
    [InlineData("SELECT UPDATE_DATE, CREATE_TS, DROP_FLAG FROM t")]
    [InlineData("SELECT a FROM t WHERE b IN (SELECT b FROM u) ORDER BY a OPTION (RECOMPILE)")]
    [InlineData("SELECT * FROM t WITH (NOLOCK) WHERE x = 1")]
    [InlineData("SELECT SUM(CASE WHEN DocumentsTypeId = 3 THEN -GrossTotal ELSE GrossTotal END) FROM t")]
    [InlineData("SELECT dbo.fn_x(1)")]
    [InlineData(";WITH c AS (SELECT 1 a) SELECT a FROM c")]
    [InlineData("SELECT [Delete] FROM t")]
    [InlineData("SELECT \"Drop\" FROM t")]
    [InlineData("SELECT a AS [Update] FROM t")]
    [InlineData("SELECT [a]]; DROP TABLE t; --] FROM t")]
    [InlineData("SELECT @Into AS a, #Set FROM t")]
    [InlineData("SELECT CommitDate, RollbackFlag, BeginDate, SaveTime, NextValue, Checkpointed FROM t")]
    [InlineData("SELECT [Commit], [Begin], \"Rollback\", [Next Value] FROM t")]
    [InlineData("SELECT a FROM t ORDER BY a OFFSET 0 ROWS FETCH NEXT 10 ROWS ONLY")]
    [InlineData("SELECT @Declare AS a, @Commit AS b FROM t")]
    public void Check_LegitimatePanelSql_Passes(string sql)
    {
        ReadOnlyGateResult result = ReadOnlyGate.Check(sql);

        Assert.True(result.Passed, result.Reason);
        Assert.Null(result.Reason);
    }

    [Fact]
    public void Check_HundredThousandCharComment_Passes()
    {
        string sql = "SELECT 1 /*" + new string('x', 100_000) + "*/";

        ReadOnlyGateResult result = ReadOnlyGate.Check(sql);

        Assert.True(result.Passed, result.Reason);
    }

    [Theory]
    [InlineData(null, "boş girdi")]
    [InlineData("", "boş girdi")]
    [InlineData("   ", "boş girdi")]
    [InlineData("\r\n\t", "boş girdi")]
    [InlineData("-- sadece yorum", "ilk anlamlı kelime yok")]
    [InlineData("/* sadece yorum */", "ilk anlamlı kelime yok")]
    [InlineData("'SELECT'", "tanınmayan ilk simge")]
    [InlineData("SELECT 'kapanmamış", "kapanmamış dize")]
    [InlineData("SELECT 1 /* kapanmamış", "kapanmamış blok yorum")]
    [InlineData("SELECT 1 /* a /* b */", "kapanmamış blok yorum")]
    [InlineData("SELECT [kapanmamış FROM t", "kapanmamış tanımlayıcı")]
    [InlineData("FOO BAR", "FOO")]
    [InlineData("BEGIN TRAN", "BEGIN")]
    [InlineData("IF 1=1 SELECT 1", "ilk kelime: IF")]
    [InlineData("WAITFOR DELAY '00:00:01'", "WAITFOR")]
    [InlineData("( SELECT 1 )", "tanınmayan ilk simge")]
    public void Check_EmptyOrAmbiguousInput_RejectsWithoutException(string? sql, string expectedWord)
    {
        ReadOnlyGateResult result = ReadOnlyGate.Check(sql!);

        Assert.False(result.Passed);
        Assert.NotNull(result.Reason);
        Assert.Contains(expectedWord, result.Reason, StringComparison.OrdinalIgnoreCase);
    }
}
