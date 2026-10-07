using Bkm.TestAltyapi;

namespace GmDashboard.Tests.Altyapi;

// Kapı SÖZDİZİMİ kapısıdır (R1, FR-015): tanınmayan her şey reddedilir; dize/yorum/tanımlayıcı içindeki kelime geçer.
[Trait("AC", "FR-015")]
[Trait("AC", "R1")]
public class SaltOkumaKapisiTests
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
    public void SaltOkumaKapisi_Denetle_YazmaBicimleriniReddeder(string sql, string beklenenKelime)
    {
        SaltOkumaSonucu sonuc = SaltOkumaKapisi.Denetle(sql);

        Assert.False(sonuc.Gecti);
        Assert.NotNull(sonuc.Neden);
        Assert.Contains(beklenenKelime, sonuc.Neden, StringComparison.OrdinalIgnoreCase);
    }

    [Theory]
    [InlineData("WITH a AS (SELECT 1 x), b AS (SELECT 2 y) DELETE FROM t", "DELETE")]
    [InlineData("WITH c AS (SELECT 1 a) INSERT INTO t SELECT a FROM c", "INSERT")]
    [InlineData("WITH c AS (SELECT 1 a) MERGE t USING c ON 1=1 WHEN MATCHED THEN DELETE;", "")]
    [InlineData("WITH c AS (SELECT 1 a) EXEC sp_x", "")]
    [InlineData("WITH c AS (SELECT 1 a)", "")]
    [InlineData("WITH c AS (SELECT 1 a) SELECT a INTO #t FROM c", "INTO")]
    [InlineData("SELECT 1; DELETE FROM t", "DELETE")]
    [InlineData("SELECT 1;DELETE FROM t", "")]
    [InlineData("SELECT 1;\tDELETE FROM t", "")]
    [InlineData("SELECT 1;\u00A0DELETE FROM t", "")]
    [InlineData("SELECT 1\nDELETE FROM t", "DELETE")]
    [InlineData("SELECT 1 /* x */ ; /* y */ DROP TABLE t", "DROP")]
    [InlineData("SELECT 1/**/;DROP TABLE t", "")]
    [InlineData("SELECT 1 /* ' */ ; DROP TABLE t", "DROP")]
    [InlineData("SELECT 1 -- '\n; DROP TABLE t", "")]
    [InlineData("SELECT '/*' ; DROP TABLE t -- */", "DROP")]
    [InlineData("SELECT '--' AS a; DROP TABLE t", "")]
    [InlineData("SELECT 1 /* -- */ ; DELETE FROM t", "DELETE")]
    [InlineData("SELECT 1 -- /*\n; DELETE FROM t\n-- */", "DELETE")]
    [InlineData("SELECT 1 -- yorum\r\nDROP TABLE t", "")]
    [InlineData("SELECT 1 --a\n--b\n; DROP TABLE t", "")]
    [InlineData("SELECT N'it''s'; DROP TABLE t", "DROP")]
    [InlineData("SELECT 'a'''; UPDATE t SET a = 1", "UPDATE")]
    [InlineData("SELECT N''; UPDATE t SET a = 1", "")]
    [InlineData("SELECT 1 /* a /* b */ c */ ; DROP TABLE t", "DROP")]
    [InlineData("select 1; delete from t", "")]
    [InlineData("SeLeCt 1; DeLeTe FrOm t", "")]
    [InlineData("delete from t", "")]
    [InlineData("uPdAtE t SET a=1", "")]
    [InlineData("dRoP table t", "")]
    [InlineData("SELECT a INTO dbo.t2 FROM dbo.t", "INTO")]
    [InlineData("SELECT a INTO ##g FROM dbo.t", "INTO")]
    [InlineData("SELECT 1\nGO\nUPDATE t SET a = 1", "UPDATE")]
    [InlineData("DECLARE @x date = CONVERT(date,'01.09.2026',104); SELECT @x", "DECLARE")]
    [InlineData("SELECT 1 WHERE 1=1; ; DROP TABLE t", "")]
    [InlineData(";DROP TABLE t", "")]
    [InlineData("SELECT 1 SELECT 2 UPDATE t SET a=1", "UPDATE")]
    public void SaltOkumaKapisi_Denetle_GizlenmisYazmayiReddeder(string sql, string beklenenKelime)
    {
        SaltOkumaSonucu sonuc = SaltOkumaKapisi.Denetle(sql);

        Assert.False(sonuc.Gecti);
        Assert.NotNull(sonuc.Neden);
        Assert.Contains(beklenenKelime, sonuc.Neden, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void SaltOkumaKapisi_Denetle_TrKulturundeKucukHarfInsert_Reddeder()
    {
        using KulturKapsami kultur = new("tr-TR");

        SaltOkumaSonucu sonuc = SaltOkumaKapisi.Denetle("insert into t values (1)");

        Assert.False(sonuc.Gecti);
        Assert.Contains("INSERT", sonuc.Neden, StringComparison.OrdinalIgnoreCase);
    }

    [Theory]
    [InlineData("SELECT 'DELETE' AS a")]
    [InlineData("SELECT 1 /* UPDATE */")]
    [InlineData("WITH c AS (SELECT 1 AS a) SELECT a FROM c")]
    [InlineData("SELECT N'DROP TABLE t' AS a")]
    [InlineData("SELECT 1 -- DROP TABLE t")]
    [InlineData("SELECT 1 -- DELETE\n, 2 AS b")]
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
    public void SaltOkumaKapisi_Denetle_DizeVeYorumdakiKelimeyiGecirir(string sql)
    {
        SaltOkumaSonucu sonuc = SaltOkumaKapisi.Denetle(sql);

        Assert.True(sonuc.Gecti, sonuc.Neden);
        Assert.Null(sonuc.Neden);
    }

    [Fact]
    public void SaltOkumaKapisi_Denetle_TrKulturundeTurkceKarakterliSelect_Gecirir()
    {
        using KulturKapsami kultur = new("tr-TR");

        SaltOkumaSonucu sonuc = SaltOkumaKapisi.Denetle("SELECT 1 AS İşlem, N'Çok Şeker' AS ğ");

        Assert.True(sonuc.Gecti, sonuc.Neden);
    }

    [Theory]
    [InlineData("SELECT a FROM dbo.t x WITH(NOLOCK)")]
    [InlineData("SELECT STUFF((SELECT ',' + n FROM dbo.t FOR XML PATH('')), 1, 1, '') AS l")]
    [InlineData("SELECT a FROM DerinSISBkm.dbo.irsHrk")]
    [InlineData("SELECT a FROM EncoreMerkez.dbo.Sales s CROSS APPLY (SELECT COUNT(*) c FROM EncoreMerkez.dbo.SalesProducts WHERE SalesId = s.Id AND IsValid = 1) sp")]
    [InlineData("SELECT * FROM OPENQUERY(ODAKJOKER, 'SELECT ORDERID FROM J_ORDERS WHERE ORDERDATE >= ''20260901''')")]
    [InlineData("SELECT * FROM ODAKJOKER.JOKER.dbo.J_ORDERS")]
    [InlineData("SELECT CONVERT(date, '01.09.2026', 104) AS d, ISNULL(x, 0) FROM t WHERE y > @start AND y < @end")]
    [InlineData("SELECT a AS Updated, b AS Deleted, c AS InsertedBy, d AS Dropdown, e AS Setting, f AS Usepoint FROM t")]
    [InlineData("SELECT UPDATE_DATE, CREATE_TS, DROP_FLAG FROM t")]
    [InlineData("SELECT a FROM t WHERE b IN (SELECT b FROM u) ORDER BY a OPTION (RECOMPILE)")]
    [InlineData("SELECT * FROM t WITH (NOLOCK) WHERE x = 1")]
    [InlineData("SELECT SUM(CASE WHEN DocumentsTypeId = 3 THEN -GrossTotal ELSE GrossTotal END) FROM t")]
    [InlineData("SELECT dbo.fn_x(1)")]
    [InlineData(";WITH c AS (SELECT 1 a) SELECT a FROM c")]
    [InlineData("SELECT a FROM t WITH (UPDLOCK)")]
    [InlineData("SELECT a FROM t WITH (XLOCK, HOLDLOCK)")]
    [InlineData("SELECT [Delete] FROM t")]
    [InlineData("SELECT \"Drop\" FROM t")]
    [InlineData("SELECT a AS [Update] FROM t")]
    [InlineData("SELECT [a]]; DROP TABLE t; --] FROM t")]
    [InlineData("SELECT @Into AS a, #Set FROM t")]
    public void SaltOkumaKapisi_Denetle_MesruPanelSqlini_Gecirir(string sql)
    {
        SaltOkumaSonucu sonuc = SaltOkumaKapisi.Denetle(sql);

        Assert.True(sonuc.Gecti, sonuc.Neden);
        Assert.Null(sonuc.Neden);
    }

    [Fact]
    public void SaltOkumaKapisi_Denetle_YuzBinKarakterliYorum_Gecirir()
    {
        string sql = "SELECT 1 /*" + new string('x', 100_000) + "*/";

        SaltOkumaSonucu sonuc = SaltOkumaKapisi.Denetle(sql);

        Assert.True(sonuc.Gecti, sonuc.Neden);
    }

    [Theory]
    [InlineData(null, "")]
    [InlineData("", "")]
    [InlineData("   ", "")]
    [InlineData("\r\n\t", "")]
    [InlineData("-- sadece yorum", "")]
    [InlineData("/* sadece yorum */", "")]
    [InlineData("'SELECT'", "")]
    [InlineData("SELECT 'kapanmamış", "")]
    [InlineData("SELECT 1 /* kapanmamış", "")]
    [InlineData("SELECT 1 /* a /* b */", "")]
    [InlineData("SELECT [kapanmamış FROM t", "")]
    [InlineData("FOO BAR", "FOO")]
    [InlineData("BEGIN TRAN", "")]
    [InlineData("IF 1=1 SELECT 1", "")]
    [InlineData("WAITFOR DELAY '00:00:01'", "")]
    [InlineData("( SELECT 1 )", "")]
    public void SaltOkumaKapisi_Denetle_BosVeBelirsizGirdiyi_ExceptionFirlatmadanReddeder(string? sql, string beklenenKelime)
    {
        SaltOkumaSonucu sonuc = SaltOkumaKapisi.Denetle(sql!);

        Assert.False(sonuc.Gecti);
        Assert.NotNull(sonuc.Neden);
        Assert.Contains(beklenenKelime, sonuc.Neden, StringComparison.OrdinalIgnoreCase);
    }
}
