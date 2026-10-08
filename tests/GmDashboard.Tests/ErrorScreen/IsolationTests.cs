using Bkm.TestAltyapi;
using GmDashboard.Tests.Altyapi;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Xunit.Sdk;

namespace GmDashboard.Tests.ErrorScreen;

// Hata ekranı yalıtımı: bellekte host + sahte veritabanı ortamı (senaryo S29-S35, S48-S49; K3).
// Ortam paylaşılan koleksiyon fikstürüdür; fabrika onu Dispose etmez. İlk assert her testte AssertIsolated.
[Collection(ErrorScreenCollection.Name)]
[Trait("Tur", "ErrorScreen")]
public class IsolationTests
{
    private readonly ErrorScreenEnvironment _env;

    public IsolationTests(ErrorScreenEnvironment env)
    {
        _env = env;
    }

    [Fact]
    [Trait("AC", "001-AC-10.1")]
    public void Factory_CreateClient_RunsInDevelopmentEnvironment()
    {
        _env.AssertIsolated();
        using ErrorScreenFactory factory = new(_env);

        using HttpClient client = factory.CreateClient();

        Assert.Equal(Environments.Development, factory.Services.GetRequiredService<IWebHostEnvironment>().EnvironmentName);
    }

    [Fact]
    public void Factory_VariableUnset_FailsBeforeHostIsBuilt()
    {
        _env.AssertIsolated();
        using EnvScope scope = new(EnvironmentNames.EnvVariable, null);

        Assert.ThrowsAny<XunitException>(() => new ErrorScreenFactory(_env));
    }

    [Fact]
    [Trait("AC", "001-AC-10.1")]
    public async Task Request_AnyScreenWithFakeDatabase_LeaksNoRealServerOrCredential()
    {
        _env.AssertIsolated();
        using ErrorScreenFactory factory = new(_env);
        using HttpClient client = factory.CreateClient(new Microsoft.AspNetCore.Mvc.Testing.WebApplicationFactoryClientOptions
        {
            AllowAutoRedirect = false,
        });

        using HttpResponseMessage root = await client.GetAsync("/");
        using HttpResponseMessage login = await client.GetAsync("/login");
        string bodies = await root.Content.ReadAsStringAsync() + await login.Content.ReadAsStringAsync();
        string logs = string.Join("\n", factory.Logs.Entries.Select(e => e.Message + " " + e.Exception));

        Assert.DoesNotContain("192.168.40.", bodies, StringComparison.Ordinal);
        Assert.DoesNotContain("192.168.40.", logs, StringComparison.Ordinal);
        Assert.DoesNotContain("Password=", logs, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("Pwd=", logs, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    [Trait("AC", "001-AC-10.1")]
    public void Factory_UnreachableDatabase_StartsWithoutCriticalLogs()
    {
        _env.AssertIsolated();
        using ErrorScreenFactory factory = new(_env);

        using HttpClient client = factory.CreateClient();

        Assert.DoesNotContain(factory.Logs.Entries, e => e.Level == LogLevel.Critical);
    }

    [Fact]
    [Trait("AC", "001-AC-10.2")]
    public void Logs_ErrorWrittenThroughHostLogger_IsCapturedWithExceptionAndCategory()
    {
        _env.AssertIsolated();
        using ErrorScreenFactory factory = new(_env);
        using HttpClient client = factory.CreateClient();
        ILogger logger = factory.Services.GetRequiredService<ILoggerFactory>().CreateLogger("Test");
        InvalidOperationException error = new("sahte");

        logger.LogError(error, "{Ekran} hata", "Sabah");

        LogEntry entry = Assert.Single(factory.Logs.Entries, e => e.Category == "Test");
        Assert.Equal(LogLevel.Error, entry.Level);
        Assert.Equal("Sabah hata", entry.Message);
        Assert.Same(error, entry.Exception);
    }

    [Fact]
    [Trait("AC", "001-AC-10.2")]
    public void Logs_SecondFactoryAfterFirstDisposed_DoesNotSeeFirstEntries()
    {
        _env.AssertIsolated();
        using (ErrorScreenFactory first = new(_env))
        {
            using HttpClient firstClient = first.CreateClient();
            first.Services.GetRequiredService<ILoggerFactory>().CreateLogger("Test").LogError("yalnız birinci");
        }

        using ErrorScreenFactory second = new(_env);
        using HttpClient secondClient = second.CreateClient();

        Assert.DoesNotContain(second.Logs.Entries, e => e.Message == "yalnız birinci");
    }

    [Fact]
    public void Dispose_FactoryUsedAndDisposed_LeavesEnvironmentIntactAndLogsReadable()
    {
        _env.AssertIsolated();
        ErrorScreenFactory factory = new(_env);
        using HttpClient client = factory.CreateClient();
        factory.Services.GetRequiredService<ILoggerFactory>().CreateLogger("Test").LogError("kalıcı kayıt");

        factory.Dispose();

        Assert.True(File.Exists(_env.EnvFilePath));
        Assert.Equal(_env.EnvFilePath, Environment.GetEnvironmentVariable(EnvironmentNames.EnvVariable));
        Assert.Contains(factory.Logs.Entries, e => e.Message == "kalıcı kayıt");
    }

    [Fact]
    public async Task LiveDb_EnvironmentActive_FailsWithCouldNotRunMessage()
    {
        _env.AssertIsolated();

        FailException ex = await Assert.ThrowsAsync<FailException>(() => LiveDb.QueryAsync<int>(DbTarget.Erp, "SELECT 1"));

        Assert.StartsWith("KOŞAMADI: BKM_ENV_DOSYA tanımlı", ex.Message, StringComparison.Ordinal);
    }

    [Fact]
    public async Task LiveDb_EnvironmentActive_NeverReachesAnyServer()
    {
        _env.AssertIsolated();

        // Bağlantı denenseydi SqlException/KOŞAMADI(bağlanamadı) gelirdi; tam tür FailException + env mesajı beklenir.
        FailException scalar = await Assert.ThrowsAsync<FailException>(() => LiveDb.ScalarAsync<int>(DbTarget.Joker, "SELECT 1"));

        Assert.StartsWith("KOŞAMADI: BKM_ENV_DOSYA tanımlı", scalar.Message, StringComparison.Ordinal);
        Assert.DoesNotContain("bağlan", scalar.Message, StringComparison.OrdinalIgnoreCase);
    }
}

/// <summary>
/// ErrorScreen koleksiyonu dışında kalan bir test, başka testin geçici ortamını görmemeli (S27).
/// Paralel faz bitmeden kendi koleksiyonları koşmaz; bu sınıf bilerek koleksiyonsuz (kanarya).
/// </summary>
public class ParallelLeakCanaryTests
{
    [Fact]
    public void EnvVariable_TestOutsideErrorScreenCollection_NeverSeesTemporaryEnvironment()
    {
        string value = Environment.GetEnvironmentVariable(EnvironmentNames.EnvVariable) ?? string.Empty;

        Assert.DoesNotContain("gmd-hata-", value, StringComparison.Ordinal);
    }
}
