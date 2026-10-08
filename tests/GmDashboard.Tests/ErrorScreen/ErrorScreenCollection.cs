using Bkm.TestAltyapi;

namespace GmDashboard.Tests.ErrorScreen;

/// <summary>Hata ekranı testleri: tek paylaşılan yalıtılmış ortam, paralel koşu kapalı (K2, K3).</summary>
[CollectionDefinition(Name, DisableParallelization = true)]
public sealed class ErrorScreenCollection : ICollectionFixture<ErrorScreenEnvironment>
{
    public const string Name = "ErrorScreen";
}

/// <summary>
/// Kendi ErrorScreenEnvironment örneğini kuran birim testleri için ayrı koleksiyon: paylaşılan ortam
/// (K2: aynı süreçte iki eşzamanlı ortam yok) ile çakışmaz, paralel de koşmaz.
/// </summary>
[CollectionDefinition(Name, DisableParallelization = true)]
public sealed class ErrorScreenOwnEnvironmentCollection
{
    public const string Name = "ErrorScreenOwnEnvironment";
}
