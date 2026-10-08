namespace Bkm.TestAltyapi;

/// <summary>
/// Hata ekranı testleri için yalıtılmış ortam: geçici .env dosyası, gerçek .env'e ulaşmayı engeller.
/// </summary>
public sealed class ErrorScreenEnvironment : IDisposable
{
    public const string FakeHost = "127.0.0.1";

    public const string FakePort = "1";

    public ErrorScreenEnvironment()
    {
        throw new NotImplementedException();
    }

    public string EnvFilePath => throw new NotImplementedException();

    /// <summary>Dosya var mı ve Db sahte sunucuyu mu okuyor; fabrikayı kurmadan çağrılabilir.</summary>
    public void AssertIsolated()
    {
        throw new NotImplementedException();
    }

    public void Dispose()
    {
        throw new NotImplementedException();
    }
}
