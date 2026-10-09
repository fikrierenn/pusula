using GmDashboard;
using Microsoft.Extensions.DependencyInjection;

namespace GmDashboard.Tests.Unit;

// T-029 (AC-0.1): AddBkmVeri TimeProvider.System'i tek, singleton kayıt olarak ekler (K5: sahte zaman AddBkmVeri SONRASI kaydedilir).
public class TimeProviderRegistrationTests
{
    private sealed class FixedTimeProvider(DateTimeOffset now) : TimeProvider
    {
        public override DateTimeOffset GetUtcNow() => now;
    }

    private static ServiceCollection BuildServices()
    {
        ServiceCollection services = new();
        services.AddBkmVeri();
        return services;
    }

    [Fact]
    public void AddBkmVeri_Registers_ExactlyOneTimeProvider()
    {
        // Arrange
        ServiceCollection services = BuildServices();

        // Act
        int count = services.Count(d => d.ServiceType == typeof(TimeProvider));

        // Assert
        Assert.Equal(1, count);
    }

    [Fact]
    public void AddBkmVeri_TimeProvider_IsSingletonInstanceOfSystem()
    {
        // Arrange
        ServiceDescriptor descriptor = BuildServices().Single(d => d.ServiceType == typeof(TimeProvider));

        // Assert
        Assert.Equal(ServiceLifetime.Singleton, descriptor.Lifetime);
        Assert.Same(TimeProvider.System, descriptor.ImplementationInstance);
    }

    [Fact]
    public void AddBkmVeri_GetRequiredTimeProvider_ReturnsSystem()
    {
        // Arrange
        using ServiceProvider provider = BuildServices().BuildServiceProvider();

        // Act
        TimeProvider resolved = provider.GetRequiredService<TimeProvider>();

        // Assert
        Assert.Same(TimeProvider.System, resolved);
    }

    [Fact]
    public void AddBkmVeri_TwoScopes_ShareSameTimeProvider()
    {
        // Arrange
        using ServiceProvider provider = BuildServices().BuildServiceProvider();
        using IServiceScope first = provider.CreateScope();
        using IServiceScope second = provider.CreateScope();

        // Act
        TimeProvider a = first.ServiceProvider.GetRequiredService<TimeProvider>();
        TimeProvider b = second.ServiceProvider.GetRequiredService<TimeProvider>();

        // Assert
        Assert.Same(a, b);
    }

    [Fact]
    public void AddBkmVeri_FakeRegisteredAfter_WinsAndSystemRegistrationRemains()
    {
        // Arrange
        ServiceCollection services = BuildServices();
        FixedTimeProvider fake = new(new DateTimeOffset(2026, 10, 5, 12, 0, 0, TimeSpan.Zero));
        services.AddSingleton<TimeProvider>(fake);
        using ServiceProvider provider = services.BuildServiceProvider();

        // Act
        TimeProvider resolved = provider.GetRequiredService<TimeProvider>();

        // Assert
        Assert.Same(fake, resolved);
        Assert.Equal(2, services.Count(d => d.ServiceType == typeof(TimeProvider)));
    }

    // Karakterizasyon (K5): AddSingleton kullanıldığı için AddBkmVeri ÖNCEDEN kayıtlı sahteyi ezer.
    [Fact]
    public void AddBkmVeri_FakeRegisteredBefore_IsOverriddenBySystem()
    {
        // Arrange
        ServiceCollection services = new();
        FixedTimeProvider fake = new(new DateTimeOffset(2026, 10, 5, 12, 0, 0, TimeSpan.Zero));
        services.AddSingleton<TimeProvider>(fake);
        services.AddBkmVeri();
        using ServiceProvider provider = services.BuildServiceProvider();

        // Act
        TimeProvider resolved = provider.GetRequiredService<TimeProvider>();

        // Assert
        Assert.Same(TimeProvider.System, resolved);
    }

    [Fact]
    public void AddBkmVeri_ResolvedTimeProvider_ReportsRealClock()
    {
        // Arrange
        using ServiceProvider provider = BuildServices().BuildServiceProvider();
        TimeProvider resolved = provider.GetRequiredService<TimeProvider>();

        // Act
        TimeSpan drift = (resolved.GetUtcNow() - TimeProvider.System.GetUtcNow()).Duration();

        // Assert
        Assert.True(drift < TimeSpan.FromSeconds(5), $"Sapma {drift}");
    }
}
