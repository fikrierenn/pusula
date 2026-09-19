using Xunit;
using Bkm.Shared.Data;
using Dapper;
using Microsoft.Extensions.DependencyInjection;

namespace BkmVardiya.Tests;

/// <summary>
/// KESİM ↔ DEVİR EKSENİ (V-20). Diğer testlerin hepsi TEK kesim ve TEK dönem
/// üzerinde koşuyordu; bu eksende yanlış kod da doğru sayıyı verir.
///
/// ÖLÇÜLEN KUSUR (19.09.2026, simülasyonla — sıfır yazma): <c>GetSummaryAsync</c>'in
/// devir alt-sorgusunda <b>dönem süzgeci yoktu</b>. Kapsam süzgeci vardı (o kusur
/// aynı gün kapatılmıştı) ama <c>Vrd_Devir</c> dönem bazlıdır. GENEL MÜDÜRLÜK'e
/// ikinci bir dönem eklenince devir eksiği <b>69.563 → 119.563 dk</b> çıkıyordu;
/// yani panelde HER dönemin devri toplanıp tek kesime yazılıyordu.
///
/// Dev veride bir kesim ve bir dönem olduğu için hiçbir test bunu göremezdi. Bu
/// testin yaptığı: <b>ikinci dönemi kendisi üretmek</b>. Gerçek kapanışı beklemek
/// "ölçemediğimiz için ölçmedik"tir ve `olctum-mu-cikardim-mi.md`ye göre bu bir
/// ölçüm değil bir ertelemedir.
///
/// ⚠ YAZMA — bu test <c>bkm.Vrd_Devir</c>'e YAZAR (yalnız DEV <c>BkmPanel</c>):
///   · dönem <c>1900-01</c> — gerçek hiçbir kapanış dönemine denk gelmez,
///   · sicil <c>zz_test_</c> önekli — PK (Donem,SicilNo) çakışmaz,
///   · dondurulmuş gerçek dönem SİLİNMEZ, DEĞİŞTİRİLMEZ.
///   Temizlik İKİ katmanlı: testin kendi <c>finally</c>si ve fikstürün baştan/sondan
///   süpürmesi — süreç çökerse <c>finally</c> koşmaz.
/// </summary>
[Collection(VardiyaDbCollection.Name)]
public sealed class CutoffCarryoverTests(VardiyaAppFactory factory)
{
    private const string FakePeriod = "1900-01";

    [Fact]
    public async Task Another_periods_carryover_does_not_leak_into_the_cutoff()
    {
        using var scope = factory.Services.CreateScope();
        var queries = scope.ServiceProvider.GetRequiredService<VardiyaQueries>();
        var db = scope.ServiceProvider.GetRequiredService<Db>();

        var cutoffs = await queries.GetCutoffsAsync(factory.ManagerId);
        Assert.NotEmpty(cutoffs);
        var c = cutoffs[0];
        var from = DateOnly.FromDateTime(c.CutoffFrom);
        var to = DateOnly.FromDateTime(c.CutoffTo);

        var before = await queries.GetSummaryAsync(factory.ManagerId, from, to);
        Assert.NotNull(before);

        // Devir dönemi kesimden TÜRETİLİYOR ve ekranda yazılıyor — sayının yanında
        // kaynağı olmazsa yanlış dönem gösterildiğinde kimse fark etmez.
        Assert.Equal(VrdPeriod.CarryFor(DateOnly.FromDateTime(c.CountFrom)), before!.CarryPeriod);
        Assert.NotEqual(FakePeriod, before.CarryPeriod);

        using var cn = db.OpenPanel();
        try
        {
            // İkinci dönem — müdürün KENDİ şubesine, yani kapsam onu ELEMEZ.
            // Kapsam süzgeci bu sızıntıyı durduramaz; durduracak olan dönem süzgecidir.
            await cn.ExecuteAsync("""
                INSERT INTO bkm.Vrd_Devir (Donem, SicilNo, Sube, Personel, EksikDk, FazlaDk)
                VALUES (@donem, @sicil, @sube, @ad, 50000, 3000)
                """,
                new
                {
                    donem = FakePeriod,
                    sicil = VardiyaAppFactory.Prefix + "v20",
                    sube = factory.ManagerBranch,
                    ad = factory.Stamp + " devir sondası"
                });

            var after = await queries.GetSummaryAsync(factory.ManagerId, from, to);
            Assert.NotNull(after);

            Assert.Equal(before.CarryShortMin, after!.CarryShortMin);
            Assert.Equal(before.CarryOvertimeMin, after.CarryOvertimeMin);
            Assert.Equal(before.TotalShortMin, after.TotalShortMin);
        }
        finally
        {
            await cn.ExecuteAsync("DELETE FROM bkm.Vrd_Devir WHERE Donem = @donem",
                                  new { donem = FakePeriod });
        }
    }

    /// <summary>
    /// Kesim ↔ dönem eşlemesi SAF bir fonksiyondur; veritabanı olmadan da koşar.
    /// Burada korunan şey sayı değil KURAL: devir, sayılan ayın öncesinde KAPANAN
    /// ayın bakiyesidir. Yıl sınırı ayrıca sınanır — "bir önceki ay" aralık/ocak
    /// geçişinde elle yazılırsa orada kırılır.
    /// </summary>
    [Theory]
    [InlineData(2026, 9, 1, "2026-08")]   // dev veride ölçülen tek gerçek nokta
    [InlineData(2026, 1, 1, "2025-12")]   // yıl sınırı
    [InlineData(2026, 3, 31, "2026-02")]  // kısa ay
    public void Carry_period_is_the_month_before_the_count_month(int y, int m, int d, string expected)
        => Assert.Equal(expected, VrdPeriod.CarryFor(new DateOnly(y, m, d)));
}
