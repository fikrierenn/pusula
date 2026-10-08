using Bkm.TestAltyapi;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Logging;

namespace GmDashboard.Tests.ErrorScreen;

/// <summary>
/// Dashboard'u bellekte, sahte veritabanı ortamıyla ayağa kaldırır. Ortamın sahibi çağıran test/fikstürdür;
/// fabrika onu Dispose ETMEZ (K3). Ortam yalıtılmamışsa host hiç kalkmaz.
/// </summary>
public sealed class ErrorScreenFactory : WebApplicationFactory<Program>
{
    public ErrorScreenFactory(ErrorScreenEnvironment environment)
    {
        ArgumentNullException.ThrowIfNull(environment);
        environment.AssertIsolated();
        Logs = new MemoryLoggerProvider();
    }

    public MemoryLoggerProvider Logs { get; }

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Development");
        builder.ConfigureLogging(logging => logging.AddProvider(Logs));
    }
}
