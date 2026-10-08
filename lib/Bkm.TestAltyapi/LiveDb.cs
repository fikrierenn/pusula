using System.Data.Common;
using System.Globalization;
using Bkm.Shared.Data;
using Dapper;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Primitives;
using Xunit;

namespace Bkm.TestAltyapi;

public enum DbTarget
{
    Erp,
    Joker,
}

/// <summary>
/// Canlı ERP/JOKER'e salt-okuma sorgusu: kapı → bağlantı → oturum ayarı → işlem içinde sorgu → her zaman geri alma.
/// Bağlantı yoksa ya da ortam sızdıysa "boş sonuç" dönmez, KOŞAMADI ile kırılır.
/// </summary>
public static class LiveDb
{
    private const string EnvName = "BKM_ENV_DOSYA";

    public static Db PanelDb()
    {
        return new Db(new EmptyConfiguration(), NullLogger<Db>.Instance);
    }

    public static Task<IReadOnlyList<T>> QueryAsync<T>(
        DbTarget target,
        string sql,
        object? param = null,
        CancellationToken ct = default)
    {
        return RunAsync<T>(
            target,
            sql,
            param,
            async (connection, command) => (await connection.QueryAsync<T>(command)).AsList(),
            ct);
    }

    public static async Task<T> ScalarAsync<T>(
        DbTarget target,
        string sql,
        object? param = null,
        CancellationToken ct = default)
    {
        IReadOnlyList<object?> values = await RunAsync<object?>(target, sql, param, ReadFirstColumnAsync, ct);

        if (values.Count == 0)
        {
            Assert.Fail("KOŞAMADI: sorgu satır döndürmedi");
        }

        if (values.Count > 1)
        {
            Assert.Fail($"tek değer bekleniyordu, {values.Count} satır geldi");
        }

        object? value = values[0];
        if (value is null)
        {
            // default(T) null olan T (nullable değer tipi, referans tipi) NULL'ı kabul eder.
            if (default(T) is not null)
            {
                Assert.Fail("KOŞAMADI: sorgu NULL döndürdü");
            }

            return default!;
        }

        Type targetType = Nullable.GetUnderlyingType(typeof(T)) ?? typeof(T);
        return (value is T typed) ? typed : (T)Convert.ChangeType(value, targetType, CultureInfo.InvariantCulture);
    }

    private static async Task<IReadOnlyList<object?>> ReadFirstColumnAsync(SqlConnection connection, CommandDefinition command)
    {
        await using DbDataReader reader = await connection.ExecuteReaderAsync(command);
        List<object?> values = [];
        while (await reader.ReadAsync(command.CancellationToken))
        {
            values.Add(reader.IsDBNull(0) ? null : reader.GetValue(0));
        }

        return values;
    }

    private static async Task<IReadOnlyList<TRow>> RunAsync<TRow>(
        DbTarget target,
        string sql,
        object? param,
        Func<SqlConnection, CommandDefinition, Task<IReadOnlyList<TRow>>> read,
        CancellationToken ct)
    {
        if (!string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable(EnvName)))
        {
            Assert.Fail("KOŞAMADI: BKM_ENV_DOSYA tanımlı — hata testi ortamı sızdı");
        }

        ReadOnlyGateResult gate = ReadOnlyGate.Check(sql);
        if (!gate.Passed)
        {
            Assert.Fail($"SALT-OKUMA KAPISI: {gate.Reason}");
        }

        ArgumentOutOfRangeException.ThrowIfGreaterThan((int)target, (int)DbTarget.Joker, nameof(target));
        ArgumentOutOfRangeException.ThrowIfLessThan((int)target, (int)DbTarget.Erp, nameof(target));

        string? openError = null;
        SqlConnection? connection = null;
        try
        {
            Db db = PanelDb();
            connection = (target == DbTarget.Erp) ? await db.OpenAsync() : await db.OpenJokerAsync();
        }
        catch (Exception ex) when (ex is not OperationCanceledException)
        {
            // Sunucu adı ve ex.Message sızmasın diye yalnız istisna türü yazılır.
            openError = ex.GetType().Name;
        }

        if (connection is null)
        {
            Assert.Fail($"KOŞAMADI: bağlantı açılamadı — {openError}");
        }

        await using (connection)
        {
            return await InTransactionAsync(connection, sql, param, read, ct);
        }
    }

    private static async Task<IReadOnlyList<TRow>> InTransactionAsync<TRow>(
        SqlConnection connection,
        string sql,
        object? param,
        Func<SqlConnection, CommandDefinition, Task<IReadOnlyList<TRow>>> read,
        CancellationToken ct)
    {
        await using (DbCommand setup = connection.CreateCommand())
        {
            setup.CommandText = "SET LOCK_TIMEOUT 5000; SET DEADLOCK_PRIORITY LOW;";
            await setup.ExecuteNonQueryAsync(ct);
        }

        using SqlTransaction tx = connection.BeginTransaction();
        bool completed = false;
        try
        {
            CommandDefinition query = new(sql, param, transaction: tx, commandTimeout: 240, cancellationToken: ct);
            IReadOnlyList<TRow> rows = await read(connection, query);

            // K-r1-3: işlem sorgu içinde kapandıysa (COMMIT/ROLLBACK) geri alma güvencesi yoktur.
            if (tx.Connection is null)
            {
                Assert.Fail("SALT-OKUMA KAPISI: işlem sorgu içinde kapandı");
            }

            CommandDefinition count = new("SELECT @@TRANCOUNT", transaction: tx, commandTimeout: 240, cancellationToken: ct);
            if (await connection.ExecuteScalarAsync<int>(count) != 1)
            {
                Assert.Fail("SALT-OKUMA KAPISI: işlem sorgu içinde kapandı");
            }

            completed = true;
            return rows;
        }
        finally
        {
            if (tx.Connection is not null)
            {
                try
                {
                    tx.Rollback();
                }
                catch (Exception ex) when (!completed)
                {
                    // Asıl istisna korunur; geri alma hatası yalnız sorgu başarılıysa yüzeye çıkar.
                    System.Diagnostics.Trace.WriteLine($"geri alma başarısız: {ex.GetType().Name}");
                }
            }
        }
    }

    // Db kurucusu yapılandırmayı kullanmaz (kimlik .env'den okunur); boş bir uygulama yeter.
    private sealed class EmptyConfiguration : IConfiguration
    {
        public string? this[string key]
        {
            get => null;
            set => throw new NotSupportedException();
        }

        public IEnumerable<IConfigurationSection> GetChildren()
        {
            return [];
        }

        public IChangeToken GetReloadToken()
        {
            return new CancellationChangeToken(CancellationToken.None);
        }

        public IConfigurationSection GetSection(string key)
        {
            throw new NotSupportedException();
        }
    }
}
