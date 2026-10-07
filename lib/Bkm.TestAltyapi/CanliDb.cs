using Bkm.Shared.Data;
using Dapper;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Primitives;
using Xunit;

namespace Bkm.TestAltyapi;

public enum Hedef
{
    Erp,
    Joker,
}

/// <summary>
/// Canlı ERP/JOKER'e salt-okuma sorgusu: kapı → bağlantı → oturum ayarı → işlem içinde sorgu → her zaman geri alma.
/// Bağlantı yoksa ya da ortam sızdıysa "boş sonuç" dönmez, KOŞAMADI ile kırılır.
/// </summary>
public static class CanliDb
{
    private const string EnvAdi = "BKM_ENV_DOSYA";

    public static Db PanelDb()
    {
        return new Db(new BosYapilandirma(), NullLogger<Db>.Instance);
    }

    public static async Task<IReadOnlyList<T>> SorguAsync<T>(
        Hedef hedef,
        string sql,
        object? param = null,
        CancellationToken ct = default)
    {
        if (!string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable(EnvAdi)))
        {
            Assert.Fail("KOŞAMADI: BKM_ENV_DOSYA tanımlı — hata testi ortamı sızdı");
        }

        SaltOkumaSonucu kapi = SaltOkumaKapisi.Denetle(sql);
        if (!kapi.Gecti)
        {
            Assert.Fail($"SALT-OKUMA KAPISI: {kapi.Neden}");
        }

        ArgumentOutOfRangeException.ThrowIfGreaterThan((int)hedef, (int)Hedef.Joker, nameof(hedef));
        ArgumentOutOfRangeException.ThrowIfLessThan((int)hedef, (int)Hedef.Erp, nameof(hedef));

        string? acmaHatasi = null;
        Microsoft.Data.SqlClient.SqlConnection? baglanti = null;
        try
        {
            Db db = PanelDb();
            baglanti = (hedef == Hedef.Erp) ? await db.OpenAsync() : await db.OpenJokerAsync();
        }
        catch (Exception ex) when (ex is not OperationCanceledException)
        {
            // Sunucu adı ve ex.Message sızmasın diye yalnız istisna türü yazılır.
            acmaHatasi = ex.GetType().Name;
        }

        if (baglanti is null)
        {
            Assert.Fail($"KOŞAMADI: bağlantı açılamadı — {acmaHatasi}");
        }

        await using (baglanti)
        {
            return await IslemIcindeSorgulaAsync<T>(baglanti, sql, param, ct);
        }
    }

    public static async Task<T> TekDegerAsync<T>(
        Hedef hedef,
        string sql,
        object? param = null,
        CancellationToken ct = default)
    {
        IReadOnlyList<T> satirlar = await SorguAsync<T>(hedef, sql, param, ct);

        if (satirlar.Count == 0)
        {
            Assert.Fail("KOŞAMADI: sorgu satır döndürmedi");
        }

        if (satirlar.Count > 1)
        {
            Assert.Fail($"tek değer bekleniyordu, {satirlar.Count} satır geldi");
        }

        return satirlar[0];
    }

    private static async Task<IReadOnlyList<T>> IslemIcindeSorgulaAsync<T>(
        Microsoft.Data.SqlClient.SqlConnection baglanti,
        string sql,
        object? param,
        CancellationToken ct)
    {
        await using (System.Data.Common.DbCommand ayar = baglanti.CreateCommand())
        {
            ayar.CommandText = "SET LOCK_TIMEOUT 5000; SET DEADLOCK_PRIORITY LOW;";
            await ayar.ExecuteNonQueryAsync(ct);
        }

        using Microsoft.Data.SqlClient.SqlTransaction tx = baglanti.BeginTransaction();
        try
        {
            CommandDefinition komut = new(sql, param, transaction: tx, commandTimeout: 240, cancellationToken: ct);
            IEnumerable<T> satirlar = await baglanti.QueryAsync<T>(komut);
            return satirlar.AsList();
        }
        finally
        {
            tx.Rollback();
        }
    }

    // Db kurucusu yapılandırmayı kullanmaz (kimlik .env'den okunur); boş bir uygulama yeter.
    private sealed class BosYapilandirma : IConfiguration
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
