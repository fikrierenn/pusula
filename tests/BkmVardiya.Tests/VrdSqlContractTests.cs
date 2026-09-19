using Bkm.Shared.Data;
using Xunit;

namespace BkmVardiya.Tests;

/// <summary>
/// BOĞAZIN KENDİ SÖZLEŞMESİ — V-09.
///
/// Boğazın verdiği iki garanti burada ÖLÇÜLÜR, iddia edilmez:
///   (1) kapsam süzgeci kaynağın içindedir ve çıkarılamaz,
///   (2) parametre adı SQL ile karşılaştırılır.
///
/// ⚠ İkincisi dört kez sessizce kırıldı (19.09.2026) ve her seferinde belirti
///   ÇALIŞMA ANINDA `Must declare the scalar variable` idi. Bu testler o hatayı
///   veritabanına hiç gitmeden, çağrının kendisinde yakalar.
///
/// DB gerekmez — saf sözleşme testi.
/// </summary>
public class VrdSqlContractTests
{
    /// <summary>
    /// SQL'de olup verilmeyen parametre. Dördünün de belirtisi buydu:
    /// `@sube` ↔ `branch`, `@girisDk` ↔ `inMin`.
    /// </summary>
    [Fact]
    public async Task Missing_parameter_is_caught_at_call_site()
    {
        var hata = await Assert.ThrowsAsync<InvalidOperationException>(() =>
            VrdSql.ExecuteAsync(new FakeConnection(),
                "SELECT 1 WHERE Sube = @sube",
                VrdParams.For("u1").Branch("FSM")));

        Assert.Contains("sube", hata.Message);        // eksik olanı ADIYLA söyler
        Assert.Contains("branch", hata.Message);      // fazladan vereni de
    }

    /// <summary>
    /// Verilmiş ama SQL'de kullanılmayan parametre: süzgeç sessizce düşmüş demektir.
    /// Bu yön olmasaydı "süzgeci sildim ama parametreyi bıraktım" görünmezdi.
    /// </summary>
    [Fact]
    public async Task Unused_parameter_is_caught_too()
    {
        var hata = await Assert.ThrowsAsync<InvalidOperationException>(() =>
            VrdSql.ExecuteAsync(new FakeConnection(),
                "SELECT 1",
                VrdParams.For("u1").Branch("FSM")));

        Assert.Contains("branch", hata.Message);
    }

    /// <summary>
    /// `userId` kapsam çapasıdır ve her çağrıda bulunur; kapsam taşımayan bir
    /// sorguda SQL'de geçmemesi kusur DEĞİLDİR. Bu muafiyet başka hiçbir ada açık
    /// değil — yukarıdaki test onu kanıtlıyor.
    /// </summary>
    [Fact]
    public async Task UserId_scope_anchor_is_exempt()
    {
        var ex = await Record.ExceptionAsync(() =>
            VrdSql.ExecuteAsync(new FakeConnection(),
                "DELETE FROM bkm.Vrd_Onay WHERE SicilNo = @sicilNo AND Tarih = @tarih",
                VrdParams.For("u1").StaffDay("123", new DateOnly(2026, 9, 1))));

        // Doğrulama geçer; sonrasında sahte bağlantı patlar — o bizim işimiz değil.
        Assert.IsNotType<InvalidOperationException>(ex);
    }

    /// <summary>
    /// Kapsam süzgeci kaynağın İÇİNDE. Bu test bir dize karşılaştırması gibi görünür
    /// ama koruduğu şey şu: biri `PersonDays`i "sadeleştirip" süzgeci dışarı alırsa
    /// on sorgu birden sessizce kapsamsız kalır ve HİÇBİRİ hata vermez.
    /// </summary>
    [Fact]
    public void Scoped_sources_carry_filter_inside()
    {
        foreach (var kaynak in new[] { VrdSql.PersonDays, VrdSql.Carryover })
        {
            Assert.Contains("Vrd_SubeKapsami", kaynak);
            Assert.Contains("@userId", kaynak);
        }
    }

    /// <summary>
    /// Kapsam çapası olmadan boğaz kurulamaz: parametresiz bir kapsam sorgusu
    /// yazmanın yolu yok.
    /// </summary>
    [Fact]
    public void UserId_cannot_be_blank()
        => Assert.Throws<ArgumentException>(() => VrdParams.For("  "));

    /// <summary>Doğrulama, bağlantıya hiç gitmeden çalışır — sahte bağlantı yeter.</summary>
    private sealed class FakeConnection : System.Data.IDbConnection
    {
        string System.Data.IDbConnection.ConnectionString { get => ""; set { } }
        public int ConnectionTimeout => 0;
        public string Database => "";
        public System.Data.ConnectionState State => System.Data.ConnectionState.Closed;
        public System.Data.IDbTransaction BeginTransaction() => throw new NotSupportedException();
        public System.Data.IDbTransaction BeginTransaction(System.Data.IsolationLevel il) => throw new NotSupportedException();
        public void ChangeDatabase(string databaseName) { }
        public void Close() { }
        public System.Data.IDbCommand CreateCommand() => throw new NotSupportedException();
        public void Dispose() { }
        public void Open() { }
    }
}
