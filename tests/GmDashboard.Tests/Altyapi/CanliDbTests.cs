using System.Text.RegularExpressions;
using Bkm.TestAltyapi;
using Xunit.Sdk;

namespace GmDashboard.Tests.Altyapi;

// CanliDb: kapı reddi bağlantıdan ÖNCE (K-karar-7b), sıra env -> kapı -> bağlantı (K-karar-6).
// Süreç-geneli BKM_ENV_DOSYA değiştiği için koleksiyon sıralı koşar.
[Collection(CanliDbEnvKoleksiyonu.Adi)]
[Trait("AC", "FR-015")]
[Trait("AC", "R1")]
public class CanliDbTests
{
    private const string EnvAdi = "BKM_ENV_DOSYA";
    private const string KapiOnEki = "SALT-OKUMA KAPISI:";
    private const string EnvMesaji = "KOŞAMADI: BKM_ENV_DOSYA tanımlı — hata testi ortamı sızdı";

    // ---------- Birim: kapıdan geçmeyen SQL bağlantı açılmadan reddedilir ----------

    [Theory]
    [InlineData(Hedef.Erp, "UPDATE dbo.x SET a = 1", "UPDATE")]
    [InlineData(Hedef.Joker, "DELETE FROM dbo.x", "DELETE")]
    [InlineData(Hedef.Erp, "", "")]
    [InlineData(Hedef.Erp, "SET LOCK_TIMEOUT 1; SELECT 1", "SET")]
    [InlineData(Hedef.Erp, "SELECT a INTO #t FROM dbo.t", "INTO")]
    public async Task CanliDb_SorguAsync_KapidanGecmeyenSqlCalistirmaz(Hedef hedef, string sql, string kelime)
    {
        using EnvKapsami env = new(EnvAdi, null);

        FailException ex = await Assert.ThrowsAsync<FailException>(() => CanliDb.SorguAsync<int>(hedef, sql));

        Assert.StartsWith(KapiOnEki, ex.Message, StringComparison.Ordinal);
        Assert.Contains(kelime, ex.Message, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("bağlantı", ex.Message, StringComparison.OrdinalIgnoreCase);
    }

    [Theory]
    [InlineData(Hedef.Erp, "SELECT 1; DROP TABLE t", "DROP")]
    [InlineData(Hedef.Joker, "WITH c AS (SELECT 1 a) UPDATE c SET a=2", "UPDATE")]
    public async Task CanliDb_TekDegerAsync_KapidanGecmeyenSqlCalistirmaz(Hedef hedef, string sql, string kelime)
    {
        using EnvKapsami env = new(EnvAdi, null);

        FailException ex = await Assert.ThrowsAsync<FailException>(() => CanliDb.TekDegerAsync<int>(hedef, sql));

        Assert.StartsWith(KapiOnEki, ex.Message, StringComparison.Ordinal);
        Assert.Contains(kelime, ex.Message, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task CanliDb_SorguAsync_ParametreKapiyiAtlatmaz()
    {
        using EnvKapsami env = new(EnvAdi, null);

        FailException ex = await Assert.ThrowsAsync<FailException>(
            () => CanliDb.SorguAsync<int>(Hedef.Erp, "SELECT a INTO #t FROM dbo.t", new { p = 1 }));

        Assert.StartsWith(KapiOnEki, ex.Message, StringComparison.Ordinal);
    }

    [Fact]
    public async Task CanliDb_SorguAsync_IkinciCagridaDaAyniReddiVerir()
    {
        using EnvKapsami env = new(EnvAdi, null);

        FailException ilk = await Assert.ThrowsAsync<FailException>(() => CanliDb.SorguAsync<int>(Hedef.Erp, "DELETE FROM t"));
        FailException ikinci = await Assert.ThrowsAsync<FailException>(() => CanliDb.SorguAsync<int>(Hedef.Erp, "DELETE FROM t"));

        Assert.Equal(ilk.Message, ikinci.Message);
    }

    [Fact]
    public async Task CanliDb_SorguAsync_TanimsizHedef_ArgumentOutOfRangeFirlatir()
    {
        using EnvKapsami env = new(EnvAdi, null);

        await Assert.ThrowsAsync<ArgumentOutOfRangeException>(() => CanliDb.SorguAsync<int>((Hedef)99, "SELECT 1"));
    }

    // ---------- Birim: BKM_ENV_DOSYA ----------

    [Fact]
    public async Task CanliDb_SorguAsync_BkmEnvDosyaTanimli_KosamadiVerir()
    {
        using EnvKapsami env = new(EnvAdi, @"C:\yok\x.env");

        FailException ex = await Assert.ThrowsAsync<FailException>(() => CanliDb.SorguAsync<int>(Hedef.Erp, "SELECT 1"));

        Assert.Equal(EnvMesaji, ex.Message);
    }

    [Fact]
    public async Task CanliDb_SorguAsync_BkmEnvDosyaTanimliJoker_KosamadiVerir()
    {
        using EnvKapsami env = new(EnvAdi, @"C:\yok\x.env");

        FailException ex = await Assert.ThrowsAsync<FailException>(() => CanliDb.SorguAsync<int>(Hedef.Joker, "SELECT 1"));

        Assert.Equal(EnvMesaji, ex.Message);
    }

    [Fact]
    public async Task CanliDb_TekDegerAsync_BkmEnvDosyaTanimli_KosamadiVerir()
    {
        using EnvKapsami env = new(EnvAdi, @"C:\yok\x.env");

        FailException ex = await Assert.ThrowsAsync<FailException>(() => CanliDb.TekDegerAsync<int>(Hedef.Erp, "SELECT 1"));

        Assert.Equal(EnvMesaji, ex.Message);
    }

    [Fact]
    public async Task CanliDb_SorguAsync_BkmEnvDosyaTanimliVeSqlKapidanGecmez_EnvOnceGelir()
    {
        using EnvKapsami env = new(EnvAdi, @"C:\yok\x.env");

        FailException ex = await Assert.ThrowsAsync<FailException>(() => CanliDb.SorguAsync<int>(Hedef.Erp, "UPDATE dbo.x SET a=1"));

        Assert.Equal(EnvMesaji, ex.Message);
        Assert.DoesNotContain("SALT-OKUMA", ex.Message, StringComparison.Ordinal);
    }

    [Fact]
    public async Task CanliDb_SorguAsync_BkmEnvDosyaTanimliVeTokenIptalEdilmis_EnvMesajiVerir()
    {
        using EnvKapsami env = new(EnvAdi, @"C:\yok\x.env");

        FailException ex = await Assert.ThrowsAsync<FailException>(
            () => CanliDb.SorguAsync<int>(Hedef.Erp, "SELECT 1", null, new CancellationToken(true)));

        Assert.Equal(EnvMesaji, ex.Message);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    public async Task CanliDb_SorguAsync_BkmEnvDosyaTanimsizSayilir_KapiReddiGelir(string? deger)
    {
        using EnvKapsami env = new(EnvAdi, deger);

        FailException ex = await Assert.ThrowsAsync<FailException>(() => CanliDb.SorguAsync<int>(Hedef.Erp, "UPDATE dbo.x SET a=1"));

        Assert.StartsWith(KapiOnEki, ex.Message, StringComparison.Ordinal);
        Assert.DoesNotContain(EnvAdi, ex.Message, StringComparison.Ordinal);
    }

    // ---------- Birim: kaynak metin (K-karar-8) ----------

    [Fact]
    public void CanliDb_Kaynak_ExecuteAsyncCagrisiYok()
    {
        string kaynak = KaynakOku();

        Assert.DoesNotContain("ExecuteAsync", kaynak, StringComparison.Ordinal);
    }

    [Fact]
    public void CanliDb_Kaynak_RollbackFinallyIcinde()
    {
        string kaynak = KaynakOku();

        Assert.Matches(new Regex(@"finally\s*\{[^}]*Rollback\(\)", RegexOptions.Singleline), kaynak);
        Assert.DoesNotContain("Commit(", kaynak, StringComparison.Ordinal);
    }

    [Fact]
    public void CanliDb_Kaynak_SetSabitMetinKapiDisi()
    {
        string kaynak = KaynakOku();

        Assert.Contains("SET LOCK_TIMEOUT 5000; SET DEADLOCK_PRIORITY LOW;", kaynak, StringComparison.Ordinal);
        Assert.DoesNotMatch(new Regex(@"SET DEADLOCK_PRIORITY LOW;""\s*\+|\$""[^""]*SET LOCK_TIMEOUT"), kaynak);
    }

    [Fact]
    public void CanliDb_Kaynak_KomutZamanAsimi240VeIslemGecer()
    {
        string kaynak = KaynakOku();

        Assert.Contains("commandTimeout: 240", kaynak, StringComparison.Ordinal);
        Assert.Contains("transaction: tx", kaynak, StringComparison.Ordinal);
    }

    // ---------- Canlı (ERP/JOKER; mesai dışı koşulur) ----------

    [Fact]
    [Trait("Tur", "Canli")]
    public async Task CanliDb_TekDegerAsync_ErpSelectBir_BirDoner()
    {
        using EnvKapsami env = new(EnvAdi, null);

        int deger = await CanliDb.TekDegerAsync<int>(Hedef.Erp, "SELECT 1");

        Assert.Equal(1, deger);
    }

    [Fact]
    [Trait("Tur", "Canli")]
    public async Task CanliDb_TekDegerAsync_JokerSelectBir_BirDoner()
    {
        using EnvKapsami env = new(EnvAdi, null);

        int deger = await CanliDb.TekDegerAsync<int>(Hedef.Joker, "SELECT 1");

        Assert.Equal(1, deger);
    }

    [Fact]
    [Trait("Tur", "Canli")]
    public async Task CanliDb_SorguAsync_IkiSatir_SiraylaDoner()
    {
        using EnvKapsami env = new(EnvAdi, null);

        IReadOnlyList<int> satirlar = await CanliDb.SorguAsync<int>(Hedef.Erp, "SELECT 1 AS a UNION ALL SELECT 2");

        Assert.Equal(new[] { 1, 2 }, satirlar.Order());
    }

    [Fact]
    [Trait("Tur", "Canli")]
    public async Task CanliDb_SorguAsync_SatirYok_BosListeDoner()
    {
        using EnvKapsami env = new(EnvAdi, null);

        IReadOnlyList<int> satirlar = await CanliDb.SorguAsync<int>(Hedef.Erp, "SELECT 1 AS a WHERE 1 = 0");

        Assert.NotNull(satirlar);
        Assert.Empty(satirlar);
    }

    [Fact]
    [Trait("Tur", "Canli")]
    public async Task CanliDb_TekDegerAsync_Sorgu_IslemIcindeKosar()
    {
        using EnvKapsami env = new(EnvAdi, null);

        int islemSayisi = await CanliDb.TekDegerAsync<int>(Hedef.Erp, "SELECT @@TRANCOUNT");

        Assert.Equal(1, islemSayisi);
    }

    [Fact]
    [Trait("Tur", "Canli")]
    public async Task CanliDb_TekDegerAsync_Sorgu_KilitZamanAsimi5000()
    {
        using EnvKapsami env = new(EnvAdi, null);

        int zamanAsimi = await CanliDb.TekDegerAsync<int>(Hedef.Erp, "SELECT @@LOCK_TIMEOUT");

        Assert.Equal(5000, zamanAsimi);
    }

    [Fact]
    [Trait("Tur", "Canli")]
    public async Task CanliDb_TekDegerAsync_Sorgu_DeadlockOnceligiDusuk()
    {
        using EnvKapsami env = new(EnvAdi, null);

        int oncelik = await CanliDb.TekDegerAsync<int>(
            Hedef.Erp,
            "SELECT deadlock_priority FROM sys.dm_exec_sessions WHERE session_id = @@SPID");

        Assert.Equal(-5, oncelik);
    }

    [Fact]
    [Trait("Tur", "Canli")]
    public async Task CanliDb_TekDegerAsync_ArdArdaCagri_IslemSizdirmaz()
    {
        using EnvKapsami env = new(EnvAdi, null);

        int ilk = await CanliDb.TekDegerAsync<int>(Hedef.Erp, "SELECT @@TRANCOUNT");
        int ikinci = await CanliDb.TekDegerAsync<int>(Hedef.Erp, "SELECT @@TRANCOUNT");

        Assert.Equal(1, ilk);
        Assert.Equal(1, ikinci);
    }

    [Fact]
    [Trait("Tur", "Canli")]
    public async Task CanliDb_SorguAsync_SifiraBolme_SqlIstisnasiYukariCikar()
    {
        using EnvKapsami env = new(EnvAdi, null);

        await Assert.ThrowsAnyAsync<Exception>(() => CanliDb.SorguAsync<int>(Hedef.Erp, "SELECT 1/0"));
        int sonra = await CanliDb.TekDegerAsync<int>(Hedef.Erp, "SELECT 1");

        Assert.Equal(1, sonra);
    }

    [Fact]
    [Trait("Tur", "Canli")]
    public async Task CanliDb_SorguAsync_ParametreDegeriAynenBaglanir()
    {
        using EnvKapsami env = new(EnvAdi, null);
        string enjeksiyonMetni = "'; DROP TABLE x;--";

        IReadOnlyList<string> satirlar = await CanliDb.SorguAsync<string>(Hedef.Erp, "SELECT @p AS a", new { p = enjeksiyonMetni });

        Assert.Equal(new[] { enjeksiyonMetni }, satirlar);
    }

    [Fact]
    [Trait("Tur", "Canli")]
    public async Task CanliDb_SorguAsync_TamsayiParametre_Baglanir()
    {
        using EnvKapsami env = new(EnvAdi, null);

        IReadOnlyList<int> satirlar = await CanliDb.SorguAsync<int>(Hedef.Erp, "SELECT @n AS a", new { n = 5 });

        Assert.Equal(new[] { 5 }, satirlar);
    }

    [Fact]
    [Trait("Tur", "Canli")]
    public async Task CanliDb_SorguAsync_UcParcaliAd_MasterBaglamindaCalisir()
    {
        using EnvKapsami env = new(EnvAdi, null);

        int adet = await CanliDb.TekDegerAsync<int>(Hedef.Erp, "SELECT COUNT(*) FROM DerinSISBkm.dbo.urn");

        Assert.True(adet > 0, "KOŞAMADI: urn nüfusu 0");
    }

    [Fact]
    [Trait("Tur", "Canli")]
    public async Task CanliDb_PanelDb_BaglantilariAcar()
    {
        using EnvKapsami env = new(EnvAdi, null);
        var db = CanliDb.PanelDb();

        using var erp = await db.OpenAsync();
        using var joker = await db.OpenJokerAsync();

        Assert.NotNull(db);
        Assert.Equal(System.Data.ConnectionState.Open, erp.State);
        Assert.Equal(System.Data.ConnectionState.Open, joker.State);
    }

    [Fact]
    [Trait("Tur", "Canli")]
    public async Task CanliDb_TekDegerAsync_SatirYok_KosamadiVerir()
    {
        using EnvKapsami env = new(EnvAdi, null);

        FailException ex = await Assert.ThrowsAsync<FailException>(
            () => CanliDb.TekDegerAsync<int>(Hedef.Erp, "SELECT 1 AS a WHERE 1 = 0"));

        Assert.Contains("KOŞAMADI: sorgu satır döndürmedi", ex.Message, StringComparison.Ordinal);
    }

    [Fact]
    [Trait("Tur", "Canli")]
    public async Task CanliDb_TekDegerAsync_BirdenCokSatir_Fail()
    {
        using EnvKapsami env = new(EnvAdi, null);

        FailException ex = await Assert.ThrowsAsync<FailException>(
            () => CanliDb.TekDegerAsync<int>(Hedef.Erp, "SELECT 1 AS a UNION ALL SELECT 2"));

        Assert.Contains("tek değer bekleniyordu", ex.Message, StringComparison.Ordinal);
    }

    // ---------- Yardımcı ----------

    private static string KaynakOku()
    {
        DirectoryInfo? kok = Enumerable
            .Repeat(0, 12)
            .Aggregate<int, DirectoryInfo?>(new DirectoryInfo(AppContext.BaseDirectory), (klasor, _) =>(klasor is null) || File.Exists(Path.Combine(klasor.FullName, "Pusula.sln")) ? klasor : klasor.Parent);

        Assert.True(kok is not null && File.Exists(Path.Combine(kok.FullName, "Pusula.sln")), "KOŞAMADI: depo kökü bulunamadı");

        return File.ReadAllText(Path.Combine(kok!.FullName, "lib", "Bkm.TestAltyapi", "CanliDb.cs"));
    }
}
