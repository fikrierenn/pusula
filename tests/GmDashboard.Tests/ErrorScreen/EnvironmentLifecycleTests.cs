using System.Reflection;
using Bkm.Shared.Data;
using Bkm.TestAltyapi;
using GmDashboard.Tests.Altyapi;
using Xunit.Sdk;

namespace GmDashboard.Tests.ErrorScreen;

// ErrorScreenEnvironment kurulum, AssertIsolated ve Dispose sözleşmesi (senaryo S1-S28; kararlar K1, K2, K6-K8).
// Her test KENDİ ortamını kurar; bu yüzden paylaşılan ortamlı "ErrorScreen" koleksiyonunda değil, ayrı koleksiyonda.
[Collection(ErrorScreenOwnEnvironmentCollection.Name)]
public class EnvironmentLifecycleTests
{
    private const string EnvName = EnvironmentNames.EnvVariable;

    // ---------- A. Kurulum ----------

    [Fact]
    public void Constructor_NewEnvironment_CreatesFileAndPointsVariableToIt()
    {
        using ErrorScreenEnvironment env = new();

        Assert.True(File.Exists(env.EnvFilePath));
        Assert.Equal(env.EnvFilePath, Environment.GetEnvironmentVariable(EnvName));
    }

    [Fact]
    public void Constructor_NewEnvironment_WritesOnlyFakeHostAndPort()
    {
        using ErrorScreenEnvironment env = new();

        string[] lines = File.ReadAllLines(env.EnvFilePath)
            .Where(l => l.Trim().Length > 0)
            .OrderBy(l => l, StringComparer.Ordinal)
            .ToArray();

        Assert.Equal("127.0.0.1", ErrorScreenEnvironment.FakeHost);
        Assert.Equal("1", ErrorScreenEnvironment.FakePort);
        Assert.Equal(["MSSQL_HOST=127.0.0.1", "MSSQL_PORT=1"], lines);
    }

    [Theory]
    [InlineData("PASSWORD")]
    [InlineData("MSSQL_USER")]
    [InlineData("JOKER")]
    [InlineData("ZIRVE")]
    [InlineData("PANEL")]
    public void Constructor_NewEnvironment_FileHasNoCredentialOrOtherServerKeys(string forbidden)
    {
        using ErrorScreenEnvironment env = new();

        string text = File.ReadAllText(env.EnvFilePath);

        Assert.DoesNotContain(forbidden, text, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void EnvFilePath_NewEnvironment_IsTempFileOutsideRepo()
    {
        using ErrorScreenEnvironment env = new();
        string tempRoot = Path.GetFullPath(Path.GetTempPath());
        string repoRoot = RepoLocator.RepoRoot();

        Assert.StartsWith(tempRoot, Path.GetFullPath(env.EnvFilePath), StringComparison.OrdinalIgnoreCase);
        Assert.StartsWith("gmd-hata-", Path.GetFileName(env.EnvFilePath), StringComparison.Ordinal);
        Assert.EndsWith(".env", env.EnvFilePath, StringComparison.Ordinal);
        Assert.NotEqual(Path.Combine(repoRoot, ".env"), env.EnvFilePath);
    }

    [Fact]
    public void Constructor_SecondEnvironmentAfterDispose_UsesDifferentPath()
    {
        string firstPath;
        using (ErrorScreenEnvironment first = new())
        {
            firstPath = first.EnvFilePath;
        }

        using ErrorScreenEnvironment second = new();

        Assert.NotEqual(firstPath, second.EnvFilePath);
        Assert.False(File.Exists(firstPath));
        Assert.True(File.Exists(second.EnvFilePath));
    }

    [Fact]
    public void LoadEnvStatic_NewEnvironment_ReturnsFakeHostAndPort()
    {
        using ErrorScreenEnvironment env = new();

        Dictionary<string, string> map = Db.LoadEnvStatic();

        Assert.Equal("127.0.0.1", map["MSSQL_HOST"]);
        Assert.Equal("1", map["MSSQL_PORT"]);
    }

    [Fact]
    public void LoadEnvStatic_NewEnvironment_HasNoKeysBeyondHostAndPort()
    {
        using ErrorScreenEnvironment env = new();

        Dictionary<string, string> map = Db.LoadEnvStatic();

        Assert.Empty(map.Keys.Except(["MSSQL_HOST", "MSSQL_PORT"], StringComparer.OrdinalIgnoreCase));
        Assert.False(map.ContainsKey("MSSQL_PASSWORD"));
    }

    // ---------- B. AssertIsolated ----------

    [Fact]
    public void AssertIsolated_HealthyEnvironmentWithoutFactory_DoesNotThrow()
    {
        using ErrorScreenEnvironment env = new();

        Exception? ex = Record.Exception(() => env.AssertIsolated());

        Assert.Null(ex);
    }

    [Fact]
    public void AssertIsolated_FileDeleted_FailsAndMessageNamesTheFile()
    {
        using ErrorScreenEnvironment env = new();
        string path = env.EnvFilePath;
        File.Delete(path);

        XunitException ex = Assert.ThrowsAny<XunitException>(() => env.AssertIsolated());

        Assert.Contains(path, ex.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void AssertIsolated_FileDeleted_NeverReadsFallbackHost()
    {
        using ErrorScreenEnvironment env = new();
        File.Delete(env.EnvFilePath);

        XunitException ex = Assert.ThrowsAny<XunitException>(() => env.AssertIsolated());

        // Dosya yokken Db gerçek .env'e düşer; mesaj gerçek sunucu adresini taşımamalı.
        Assert.DoesNotContain("192.168.", ex.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void AssertIsolated_VariableUnset_Fails()
    {
        using ErrorScreenEnvironment env = new();
        using EnvScope scope = new(EnvName, null);

        Assert.ThrowsAny<XunitException>(() => env.AssertIsolated());
    }

    [Fact]
    public void AssertIsolated_VariableEmpty_Fails()
    {
        using ErrorScreenEnvironment env = new();
        using EnvScope scope = new(EnvName, string.Empty);

        Assert.ThrowsAny<XunitException>(() => env.AssertIsolated());
    }

    [Fact]
    public void AssertIsolated_VariableWhitespace_Fails()
    {
        using ErrorScreenEnvironment env = new();
        using EnvScope scope = new(EnvName, "   ");

        Assert.ThrowsAny<XunitException>(() => env.AssertIsolated());
    }

    [Fact]
    public void AssertIsolated_VariablePointsToOtherExistingFile_Fails()
    {
        using ErrorScreenEnvironment env = new();
        using TempFile other = new("MSSQL_HOST=10.9.9.9");
        using EnvScope scope = new(EnvName, other.Path);

        Assert.ThrowsAny<XunitException>(() => env.AssertIsolated());
    }

    [Fact]
    public void AssertIsolated_FileHostChanged_FailsAndMessageNamesTheFile()
    {
        using ErrorScreenEnvironment env = new();
        File.WriteAllText(env.EnvFilePath, "MSSQL_HOST=10.20.30.40\nMSSQL_PORT=1\n");

        XunitException ex = Assert.ThrowsAny<XunitException>(() => env.AssertIsolated());

        Assert.Contains(env.EnvFilePath, ex.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void AssertIsolated_FileTruncatedToEmpty_Fails()
    {
        using ErrorScreenEnvironment env = new();
        File.WriteAllText(env.EnvFilePath, string.Empty);

        Assert.ThrowsAny<XunitException>(() => env.AssertIsolated());
    }

    [Fact]
    public void AssertIsolated_AfterDispose_Fails()
    {
        ErrorScreenEnvironment env = new();
        env.Dispose();

        Assert.ThrowsAny<XunitException>(() => env.AssertIsolated());
    }

    [Fact]
    public void AssertIsolated_CalledTwice_PassesAndChangesNothing()
    {
        using ErrorScreenEnvironment env = new();
        string before = File.ReadAllText(env.EnvFilePath);

        env.AssertIsolated();
        env.AssertIsolated();

        Assert.Equal(before, File.ReadAllText(env.EnvFilePath));
        Assert.Equal(env.EnvFilePath, Environment.GetEnvironmentVariable(EnvName));
    }

    // ---------- C. Dispose ----------

    [Fact]
    public void Dispose_Environment_ResetsVariableToNull()
    {
        ErrorScreenEnvironment env = new();

        env.Dispose();

        Assert.Null(Environment.GetEnvironmentVariable(EnvName));
    }

    [Fact]
    public void Dispose_Environment_DeletesFile()
    {
        ErrorScreenEnvironment env = new();
        string path = env.EnvFilePath;

        env.Dispose();

        Assert.False(File.Exists(path));
    }

    [Fact]
    public void Dispose_CalledTwice_DoesNotThrow()
    {
        ErrorScreenEnvironment env = new();
        env.Dispose();

        Exception? ex = Record.Exception(() => env.Dispose());

        Assert.Null(ex);
        Assert.Null(Environment.GetEnvironmentVariable(EnvName));
    }

    [Fact]
    public void Dispose_FileAlreadyDeleted_DoesNotThrowAndResetsVariable()
    {
        ErrorScreenEnvironment env = new();
        File.Delete(env.EnvFilePath);

        Exception? ex = Record.Exception(() => env.Dispose());

        Assert.Null(ex);
        Assert.Null(Environment.GetEnvironmentVariable(EnvName));
    }

    [Fact]
    public void Dispose_ScopeLeftByException_StillCleansUp()
    {
        string path = string.Empty;

        Action scopeThatFails = () =>
        {
            using ErrorScreenEnvironment env = new();
            path = env.EnvFilePath;
            throw new InvalidOperationException("sahte test hatası");
        };

        Assert.Throws<InvalidOperationException>(scopeThatFails);

        Assert.Null(Environment.GetEnvironmentVariable(EnvName));
        Assert.False(File.Exists(path));
    }

    [Fact]
    public void Constructor_VariableAlreadySetToForeignValue_ThrowsAndLeavesVariableUntouched()
    {
        using EnvScope outside = new(EnvName, @"C:\baska\x.env");

        Assert.Throws<InvalidOperationException>(() =>
        {
            _ = new ErrorScreenEnvironment();
        });

        Assert.Equal(@"C:\baska\x.env", Environment.GetEnvironmentVariable(EnvName));
    }

    // ---------- D. Koleksiyon / eşzamanlılık ----------

    [Fact]
    public void Constructor_SecondActiveEnvironment_ThrowsAndFirstStaysIntact()
    {
        using ErrorScreenEnvironment first = new();

        Assert.Throws<InvalidOperationException>(() =>
        {
            _ = new ErrorScreenEnvironment();
        });

        Assert.True(File.Exists(first.EnvFilePath));
        Assert.Equal(first.EnvFilePath, Environment.GetEnvironmentVariable(EnvName));
    }

    [Fact]
    public void ErrorScreenCollection_Definition_NamesErrorScreenAndDisablesParallelization()
    {
        CustomAttributeData definition = typeof(ErrorScreenCollection)
            .GetCustomAttributesData()
            .Single(d => d.AttributeType == typeof(CollectionDefinitionAttribute));

        CustomAttributeNamedArgument disable = definition.NamedArguments
            .Single(a => a.MemberName == nameof(CollectionDefinitionAttribute.DisableParallelization));

        Assert.Equal("ErrorScreen", ErrorScreenCollection.Name);
        Assert.Equal(true, disable.TypedValue.Value);
        Assert.Contains(
            typeof(ICollectionFixture<ErrorScreenEnvironment>),
            typeof(ErrorScreenCollection).GetInterfaces());
    }

    [Fact]
    public void ErrorScreenTraitClasses_AllBelongToErrorScreenCollection()
    {
        // Liste elle yazılmaz: test derlemesindeki Tur=ErrorScreen taşıyan her sınıf taranır.
        Type[] traitClasses = typeof(EnvironmentLifecycleTests).Assembly.GetTypes()
            .Where(t => CarriesErrorScreenTrait(t) || t.GetMethods().Any(CarriesErrorScreenTrait))
            .ToArray();

        Type[] outside = traitClasses
            .Where(t => !t.GetCustomAttributesData().Any(d =>
                d.AttributeType == typeof(CollectionAttribute)
                && (string?)d.ConstructorArguments[0].Value == ErrorScreenCollection.Name))
            .ToArray();

        Assert.NotEmpty(traitClasses);
        Assert.Empty(outside);
    }

    private static bool CarriesErrorScreenTrait(MemberInfo member)
    {
        return member.GetCustomAttributesData().Any(d =>
            d.AttributeType == typeof(TraitAttribute)
            && (string?)d.ConstructorArguments[0].Value == "Tur"
            && (string?)d.ConstructorArguments[1].Value == "ErrorScreen");
    }
}
