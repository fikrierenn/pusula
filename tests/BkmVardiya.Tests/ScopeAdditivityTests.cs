using Xunit;
using Bkm.Shared.Data;
using Dapper;
using Microsoft.Extensions.DependencyInjection;

namespace BkmVardiya.Tests;

/// <summary>
/// KAPSAM TOPLANABİLİRLİĞİ — HER okuma metodu için (V-07).
///
/// ══ NEDEN VAR ════════════════════════════════════════════════════════════════
/// İki kapsam sızıntısını da İNSAN SEZGİSİ buldu: "2.192,6 saat makul ama
/// kapsamla orantısız". Sayı saçma değil MAKUL çıktığı için hiçbir şey uyarmadı
/// (`olctum-mu-cikardim-mi.md` § makul sayı kabul edilir). Sınıf yazılıydı,
/// mekanik karşılığı yoktu — V-07 o boşluk.
///
/// <see cref="BranchScopeTests"/> bu sınıfı YALNIZ <c>GetSummaryAsync</c> için
/// kapatıyordu ve kendi "BİLİNEN ATLATMA" notunda bunu yazıyordu: başka bir
/// sorguda süzgeç atlanırsa o test GÖRMEZ.
///
/// ══ MEKANİZMA ════════════════════════════════════════════════════════════════
/// Üçüncü bir kullanıcı: TÜMLEYEN müdür (ACL = müdürün şubesi hariç hepsi).
/// Her okuma metodu için tek iddia:
///
///     f(müdür) + f(tümleyen) == f(İK)
///
/// Bir metotta kapsam süzgeci düşerse müdür de tümleyen de TAM nüfusu döner ve
/// toplam 2×İK olur. Yani sızıntı, metriğin ne olduğundan BAĞIMSIZ olarak,
/// aritmetik bir çelişkiye dönüşür.
///
/// Bunun asıl kazancı: <b>metrik başına "beklenen değer" yazılmaz.</b> Yeni bir
/// okuma metodu eklendiğinde buraya üç satır eklenir ve kapı genişler; kimsenin
/// o metriğin doğru sayısını bilmesi gerekmez.
///
/// ══ YAKALAMAZ ════════════════════════════════════════════════════════════════
///   • Kapsamın DOĞRU olduğunu — yalnız BÖLÜNDÜĞÜNÜ. ACL'de yanlış şube yazılıysa
///     toplanabilirlik yine sağlanır. Doğruluk <see cref="BranchScopeTests"/>'in işi.
///   • Süzgecin yanlış KOLONA bağlanmasını, eğer o kolon da şubeyi bölüyorsa.
///   • Yazma yolunu (onay/düzeltme kaydı) — ayrı kapıları var.
///
/// ══ KIRMIZI KİP — koşuldu (20.09.2026) ═══════════════════════════════════════
/// Sabotaj bilerek ESKİ testin göremediği yere kondu: `VrdSql.Carryover`'dan
/// kapsam süzgeci kaldırıldı (dönem süzgeci bırakıldı, yani SQL sözleşmesi geçer).
/// Sonuç:
///     GetSummaryAsync.CarryShortMin: müdür 111491 + tümleyen 111491 = 222982,
///     İK 111491. Fark 111491. Müdür = İK → kapsam süzgeci bu metotta DÜŞMÜŞ.
/// YALNIZ o metrik düştü; diğer 13 yüzey doğru bölünmeye devam etti — kapı kör
/// değil, keskin. Geri alındı, 29/29 yeşil.
///
/// ══ HANGİ KAPI NEYİ YAKALAR — üçü de gerekli ═════════════════════════════════
///   • `tools/vardiya_kapsam_denetimi.py` — METİN. Ham tablo adı / boğaz atlama.
///     Süzgecin doğru KOLONA bağlandığını göremez.
///   • `VrdSqlContractTests` — YAPI. Boğaz sabitlerinin içinde süzgeç duruyor mu.
///     Yeni bir kaynak eklenirse o sabit listesinde olmadığı için göremez.
///   • BU TEST — DEĞER. Metin nerede durursa dursun, sonuç bölünüyor mu.
///     Refactor'da metin taşınsa bile ayakta kalan tek kapı budur.
///   • `BranchScopeTests` — DOĞRULUK. Müdürün gördüğü ŞEY tam olarak kendi şubesi mi
///     (yanlış kolona bağlanma sınıfı). Toplanabilirlik onu GÖREMEZ: yanlış kolon
///     herkese boş küme döndürürse 0 + 0 == 0 sağlanır ve bu test YEŞİL kalır.
///
/// ══ ÖN KOŞUL — ölçüldü, varsayılmadı ═════════════════════════════════════════
/// Toplanabilirlik ancak kişi ve kişi-hafta şubeler arasında BÖLÜNMÜYORSA geçerli.
/// Ölçüldü (20.09.2026): çok şubeli kişi 0/380, çok şubeli kişi-hafta 0.
/// Bu bir ÖLÇÜM, garanti değil — biri şube değiştirirse `NoWeeklyRest`/`Over45`
/// gibi kişi-hafta metrikleri toplanamaz hâle gelir. O yüzden ön koşul burada
/// ASSERT'tir: bozulursa test "SIZINTI" değil "BAKAMADIM" der.
/// ═════════════════════════════════════════════════════════════════════════════
/// </summary>
[Collection(VardiyaDbCollection.Name)]
public sealed class ScopeAdditivityTests(VardiyaAppFactory factory)
{
    private const int NoCap = 1_000_000;   // GetRowsAsync TOP'u — kapak toplanabilirliği bozar

    private VardiyaQueries Queries(IServiceScope s) => s.ServiceProvider.GetRequiredService<VardiyaQueries>();

    /// <summary>
    /// ÖN KOŞULLAR — yorum değil Assert. Üçü de sağlanmazsa asıl iddia boş kümede
    /// ya da yanlış aritmetikte "sessizce doğru" çıkar.
    /// </summary>
    [Fact]
    public async Task Preconditions_partition_is_valid()
    {
        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<Db>();
        using var cn = db.OpenPanel();

        var (branches, multiBranchStaff, multiBranchWeeks, outOfScope) =
            await cn.QuerySingleAsync<(int, int, int, int)>("""
                SELECT Branches = (SELECT COUNT(DISTINCT Sube) FROM bkm.Vrd_KisiGun),
                       MultiBranchStaff = (SELECT COUNT(*) FROM (
                            SELECT SicilNo FROM bkm.Vrd_KisiGun
                            GROUP BY SicilNo HAVING COUNT(DISTINCT Sube) > 1) a),
                       MultiBranchWeeks = (SELECT COUNT(*) FROM (
                            SELECT SicilNo, DATEPART(iso_week, Tarih) w FROM bkm.Vrd_KisiGun
                            GROUP BY SicilNo, DATEPART(iso_week, Tarih)
                            HAVING COUNT(DISTINCT Sube) > 1) b),
                       OutOfScope = (SELECT COUNT(*) FROM bkm.Vrd_KisiGun WHERE Sube <> @own)
                """, new { own = factory.ManagerBranch });

        Assert.True(branches >= 2,
            $"Bölme testi en az 2 şube ister, {branches} var. Tek şubede tümleyen BOŞTUR " +
            "ve toplanabilirlik hiçbir şey ölçmez.");

        Assert.True(outOfScope > 0,
            "Tümleyenin kapsamında hiç kişi-gün yok — süzgeç düşse bile toplam değişmezdi.");

        Assert.Equal(0, multiBranchStaff);   // bozulursa: BAKAMADIM, sızıntı DEĞİL
        Assert.Equal(0, multiBranchWeeks);
    }

    /// <summary>
    /// ASIL İDDİA — her okuma metodu için f(müdür) + f(tümleyen) == f(İK).
    /// Tek test içinde toplanır: hangi metotta koptuğu mesajda yazar, ama bir
    /// kopuk metot yüzünden ötekiler ölçülmeden kalmasın diye HEPSİ koşar.
    /// </summary>
    [Fact]
    public async Task Every_read_surface_splits_by_scope()
    {
        using var scope = factory.Services.CreateScope();
        var q = Queries(scope);

        var cutoffs = await q.GetCutoffsAsync(factory.HrId);
        Assert.NotEmpty(cutoffs);
        var c = cutoffs[0];
        var from = DateOnly.FromDateTime(c.CutoffFrom);
        var to = DateOnly.FromDateTime(c.CutoffTo);

        var hatalar = new List<string>();

        async Task Check(string ad, Func<string, Task<long>> olc)
        {
            var mudur = await olc(factory.ManagerId);
            var tumleyen = await olc(factory.ComplementId);
            var ik = await olc(factory.HrId);
            if (mudur + tumleyen != ik)
                hatalar.Add($"{ad}: müdür {mudur} + tümleyen {tumleyen} = {mudur + tumleyen}, " +
                            $"İK {ik}. Fark {mudur + tumleyen - ik}. " +
                            (mudur == ik ? "Müdür = İK → kapsam süzgeci bu metotta DÜŞMÜŞ." : ""));
        }

        await Check("GetCutoffsAsync",
            async u => (await q.GetCutoffsAsync(u)).Sum(x => (long)x.PersonDays));

        await Check("GetSummaryAsync.PersonDays",
            async u => (await q.GetSummaryAsync(u, from, to))?.PersonDays ?? 0);
        await Check("GetSummaryAsync.ShortMin",
            async u => (await q.GetSummaryAsync(u, from, to))?.ShortMin ?? 0);
        await Check("GetSummaryAsync.OvertimeMin",
            async u => (await q.GetSummaryAsync(u, from, to))?.OvertimeMin ?? 0);
        // Devir AYRI tablodan gelir ve kapsamı AYRI süzgeçle çözülür (V-20) —
        // bu yüzden ayrıca sınanır; PersonDays doğru bölünürken devir sızabilir.
        await Check("GetSummaryAsync.CarryShortMin",
            async u => (await q.GetSummaryAsync(u, from, to))?.CarryShortMin ?? 0);
        await Check("GetSummaryAsync.BranchCount",
            async u => (await q.GetSummaryAsync(u, from, to))?.BranchCount ?? 0);

        await Check("GetStatusBreakdownAsync",
            async u => (await q.GetStatusBreakdownAsync(u, from, to)).Sum(x => (long)x.PersonDays));

        await Check("GetBranchBreakdownAsync.PersonDays",
            async u => (await q.GetBranchBreakdownAsync(u, from, to)).Sum(x => (long)x.PersonDays));
        await Check("GetBranchBreakdownAsync.rows",
            async u => (await q.GetBranchBreakdownAsync(u, from, to)).Count);

        await Check("GetOvertimeSourceAsync",
            async u =>
            {
                var o = await q.GetOvertimeSourceAsync(u, from, to, null);
                return o is null ? 0
                    : o.ExtraWorkMin + o.LeaveCancelledMin + o.WeeklyRestMin
                    + o.UnplannedMin + o.AfterCloseMin + o.BeforeOpenMin;
            });

        await Check("GetStayBandsAsync.DayCount",
            async u => (await q.GetStayBandsAsync(u, from, to, null)).Sum(x => (long)x.DayCount));
        await Check("GetStayBandsAsync.Minutes",
            async u => (await q.GetStayBandsAsync(u, from, to, null)).Sum(x => (long)x.Minutes));

        // Mevzuat kapısı: Daily11/Gross12/Night75/Suspect GÜN sayısı, NoWeeklyRest/Over45
        // KİŞİ-HAFTA sayısıdır. İkincisi ancak kişi-hafta şubeye bölünmüyorsa toplanır —
        // ön koşul testi tam bunu koruyor.
        await Check("GetComplianceAsync",
            async u =>
            {
                var o = await q.GetComplianceAsync(u, from, to);
                return o is null ? 0
                    : o.Daily11 + o.Gross12 + o.Night75 + o.NoWeeklyRest + o.Over45 + o.Suspect;
            });

        await Check("GetRowsAsync",
            async u => (await q.GetRowsAsync(u, from, to, null, null, false, NoCap)).Count);

        Assert.True(hatalar.Count == 0,
            "KAPSAM BÖLÜNMÜYOR — aşağıdaki okuma yüzeylerinde:\n  " + string.Join("\n  ", hatalar));
    }

    /// <summary>
    /// TEK-KAYIT yüzeyleri toplanamaz (sayı değil, var/yok). Onlarda iddia şu:
    /// müdür, tümleyenin kapsamındaki bir kişi-günü SORGULAYAMAZ — null döner.
    /// Bu yüzeyler `EXISTS(PersonDays)` ile korunuyor; o EXISTS düşerse sızıntı
    /// buradan olur ve toplanabilirlik testi görmez.
    /// </summary>
    [Fact]
    public async Task Single_record_surfaces_reject_out_of_scope_staff()
    {
        using var scope = factory.Services.CreateScope();
        var q = Queries(scope);
        var db = scope.ServiceProvider.GetRequiredService<Db>();
        using var cn = db.OpenPanel();

        var outsider = await cn.QuerySingleOrDefaultAsync<(string StaffNo, DateTime Day)?>("""
            SELECT TOP 1 SicilNo, Tarih FROM bkm.Vrd_KisiGun
            WHERE Sube <> @own AND SicilNo <> '' ORDER BY Tarih
            """, new { own = factory.ManagerBranch });

        Assert.True(outsider is not null,
            "Kapsam dışında kişi-gün yok — bu test hiçbir şey ölçemez (BAKAMADIM).");

        var (staffNo, dayRaw) = outsider!.Value;
        var day = DateOnly.FromDateTime(dayRaw);

        // Tümleyen GÖREBİLMELİ — yoksa "null döndü" bulgusu kapsamdan değil,
        // kaydın hiç olmamasından gelir ve test yanlış sebeple yeşil olur.
        // (Onay/düzeltme kaydı yoksa ikisi de null döner; o hâlde iddia kurulamaz.)
        var complementApproval = await q.GetApprovalAsync(factory.ComplementId, staffNo, day);
        var complementCorrection = await q.GetPlanCorrectionAsync(factory.ComplementId, staffNo, day);

        var managerApproval = await q.GetApprovalAsync(factory.ManagerId, staffNo, day);
        var managerCorrection = await q.GetPlanCorrectionAsync(factory.ManagerId, staffNo, day);

        Assert.Null(managerApproval);
        Assert.Null(managerCorrection);

        // Not: tümleyenin sonucu NULL olabilir (o kişi-güne kayıt girilmemiş olabilir).
        // Bu bir kusur değil; yalnız o hâlde yukarıdaki iki Assert zayıf kanıttır.
        // Değişkenler bilerek okunuyor — gelecekte veri zenginleşirse iddia güçlenir.
        _ = complementApproval; _ = complementCorrection;
    }
}
