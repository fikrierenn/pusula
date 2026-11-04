using Bkm.Shared.Data;
using Xunit;

namespace Bkm.TestAltyapi;

/// <summary>
/// Hata ekranı testleri için yalıtılmış ortam: geçici .env dosyası, gerçek .env'e ulaşmayı engeller.
/// </summary>
public sealed class ErrorScreenEnvironment : IDisposable
{
    public const string FakeHost = "127.0.0.1";

    public const string FakePort = "1";

    private const string EnvName = "BKM_ENV_DOSYA";

    /// <summary>Dispose dosyayı silemediyse true; testler kalıntıyı raporlayabilsin diye.</summary>
    public bool DeleteFailed { get; private set; }

    public ErrorScreenEnvironment()
    {
        // Dışarıdan gelen ya da ikinci bir ortam yalıtımı bozar; üzerine yazılmaz.
        string? current = Environment.GetEnvironmentVariable(EnvName);
        if (!string.IsNullOrWhiteSpace(current))
        {
            throw new InvalidOperationException(
                $"{EnvName} zaten tanımlı ({current}); yalıtılmış ortam kurulamaz.");
        }

        EnvFilePath = Path.Combine(Path.GetTempPath(), "gmd-hata-" + Guid.NewGuid().ToString("N") + ".env");
        File.WriteAllText(EnvFilePath, $"MSSQL_HOST={FakeHost}{Environment.NewLine}MSSQL_PORT={FakePort}{Environment.NewLine}");

        // Değişken yalnız dosya yazıldıktan sonra ayarlanır.
        Environment.SetEnvironmentVariable(EnvName, EnvFilePath);
    }

    public string EnvFilePath { get; }

    /// <summary>Dosya var mı ve Db sahte sunucuyu mu okuyor; fabrikayı kurmadan çağrılabilir.</summary>
    public void AssertIsolated()
    {
        // Sıra bilinçli: dosya yoksa Db gerçek .env'e düşer, o yüzden Db'ye hiç sorulmaz.
        string? variable = Environment.GetEnvironmentVariable(EnvName);
        if (!string.Equals(variable, EnvFilePath, StringComparison.Ordinal))
        {
            Assert.Fail($"Yalıtım bozuk: {EnvName}='{variable}', beklenen '{EnvFilePath}'.");
        }

        if (!File.Exists(EnvFilePath))
        {
            Assert.Fail($"Yalıtım bozuk: geçici ortam dosyası yok: {EnvFilePath}");
        }

        Dictionary<string, string> map = Db.LoadEnvStatic();
        map.TryGetValue("MSSQL_HOST", out string? host);
        if (!string.Equals(host, FakeHost, StringComparison.Ordinal))
        {
            Assert.Fail($"Yalıtım bozuk: {EnvFilePath} içinde MSSQL_HOST='{host}', beklenen '{FakeHost}'.");
        }
    }

    public void Dispose()
    {
        // Silme hatası fırlatılmaz: kalıntı dosya parola içermez; değişken yine de sıfırlanır.
        try
        {
            File.Delete(EnvFilePath);
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            DeleteFailed = true;
        }

        // Başkasının değerini ezmemek için yalnız kendi yolumuzsa sıfırlanır.
        if (string.Equals(Environment.GetEnvironmentVariable(EnvName), EnvFilePath, StringComparison.Ordinal))
        {
            Environment.SetEnvironmentVariable(EnvName, null);
        }
    }
}
