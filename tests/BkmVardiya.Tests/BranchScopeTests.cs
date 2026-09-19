using Xunit;
using System.Net;
using System.Text.RegularExpressions;
using Bkm.Shared.Data;
using Dapper;
using Microsoft.Extensions.DependencyInjection;

namespace BkmVardiya.Tests;

/// <summary>
/// ŞUBE KAPSAMI — UÇTAN UCA (plan 48 V-06).
///
/// ══ YAKALAMA SÖZLEŞMESİ ══════════════════════════════════════════════════════
/// YAKALAR:
///   • Bir okuma sorgusunda scope süzgecinin ATLANMASI (müdür fazla satır görür).
///   • Süzgecin YANLIŞ KOLONA bağlanması — metin kapısının göremediği sınıf:
///     `Bolum IN (...)` yazılsa metin kapısı geçer, bu test KIRMIZI döner.
///   • Kimlik/talep zincirinin kopması (kullanıcı kimliği TVF'e ulaşmıyorsa
///     scope boşalır ve müdür HİÇBİR ŞEY görmez).
///
/// YAKALAMAZ:
///   • Dağıtım sınıfı: çerez politikası (`SecurePolicy.Always` + http taban adresi),
///     HTTPS yönlendirme, iletilmiş başlıklar, Kestrel sınırları. Bunlar AYRI ve
///     küçük bir duman testini hak eder — buraya karıştırılırsa bu test başka bir
///     sebeple kırmızı döner ve insan "yine o çerez işi" deyip BAKMAMAYA başlar.
///   • YAZMA tarafını (onay kaydı). Onun kapısı ayrı: `SaveApprovalAsync` içindeki
///     scope kontrolü + `Permissions.Approve`.
///   • Kapsamın DOĞRU olduğunu — yalnız SIZMADIĞINI. Müdürün şubesi ACL'de yanlış
///     yazılmışsa test yine yeşil döner.
///
/// BİLİNEN ATLATMA:
///   • Test yalnız `GetSummaryAsync` yüzeyini (kişi-gün KPI'ı) okur. Başka bir
///     sorguda süzgeç atlanırsa BU TEST GÖRMEZ — metin kapısı
///     (`tools/vardiya_kapsam_denetimi.py`) o yüzden emekliye AYRILMAZ; ikisi
///     farklı şeyi ölçer.
///
/// YÜKSELTME YOLU:
///   • Her okuma yüzeyi için ayrı iddia eklenirse (durum/şube/bant/satır), metin
///     kapısının "atlanmış süzgeç" maddesi gereksizleşir ve silinebilir. Bugün
///     ikisi birlikte gerekiyor.
/// ═════════════════════════════════════════════════════════════════════════════
/// </summary>
public sealed class BranchScopeTests(VardiyaAppFactory factory) : IClassFixture<VardiyaAppFactory>
{
    /// <summary>
    /// ÖN KOŞULLAR — yorum değil, <c>Assert</c>. Nüfus yetersizse bu test
    /// "geçti" değil "BAKAMADIM" demelidir (`olctum-mu-cikardim-mi.md`).
    /// Ayrıca (2) asıl iddianın KIRILMA PAYIDIR: scope dışı toplam sıfırdan
    /// büyükse, süzgeç kalktığında müdür = İK olmak ZORUNDA.
    /// </summary>
    [Fact]
    public async Task Preconditions_population_is_sufficient()
    {
        var (branchCount, inScope, outOfScope) = await MeasurePopulationAsync();

        Assert.True(branchCount >= 2,
            $"Kapsam testi en az 2 şube ister, {branchCount} var. Tek şubede 'müdür = İK' " +
            "ZATEN doğrudur ve test hiçbir şey ölçmez.");

        Assert.True(inScope > 0,
            "Müdürün şubesinde hiç kişi-gün yok — 'scope çalışıyor' iddiası boş kümede " +
            "sessizce doğru çıkar.");

        Assert.True(outOfScope > 0,
            "Kapsam DIŞINDA hiç kişi-gün yok — süzgeç kalksa bile fark görünmezdi, " +
            "yani bu test sızıntıyı ölçemez.");
    }

    /// <summary>
    /// ASIL İDDİA — üç parça birlikte.
    /// KATI EŞİTSİZLİK sızıntıyı ölçer: süzgeç sızarsa müdür = İK olur.
    /// Eşitlikler doğruluğu ölçer. (Solum, 19.09: eşitlik tek başına boş kümede
    /// ve tek-şube dünyasında da doğru çıkar — ayırt edici olan eşitsizliktir.)
    /// </summary>
    [Fact]
    public async Task Manager_sees_only_own_branch()
    {
        var managerPersonDays = await ReadPersonDaysAsync(factory.ManagerName);
        var hrPersonDays = await ReadPersonDaysAsync(factory.HrName);
        var (_, ownBranch, outOfScope) = await MeasurePopulationAsync();

        // 1) SIZINTI ÖLÇÜTÜ — süzgeç sızarsa bu EŞİT olur.
        Assert.True(managerPersonDays < hrPersonDays,
            $"SIZINTI: müdür {managerPersonDays} kişi-gün görüyor, İK {hrPersonDays}. " +
            "Kapsam süzgeci atlanmış ya da yanlış kolona bağlanmış olabilir.");

        // 2) DOĞRULUK — gördüğü şey tam olarak kendi şubesi.
        Assert.Equal(ownBranch, managerPersonDays);

        // 3) TOPLAMA İLİŞKİSİ — scope bir bölme, parçalar bütünü verir.
        Assert.Equal(hrPersonDays, managerPersonDays + outOfScope);
    }

    /// <summary>
    /// Kimliksiz istek hiçbir şey görmemeli — fail-closed. Giriş yapmadan ana
    /// sayfaya gidilirse uygulama /Login'e yönlendirir; "yetkisiz kullanıcı her
    /// şeyi görür" durumu OLUŞAMAZ.
    /// </summary>
    [Fact]
    public async Task Anonymous_request_cannot_reach_report()
    {
        var client = factory.CreateClient(new() { AllowAutoRedirect = false });
        var response = await client.GetAsync("/");

        Assert.Equal(HttpStatusCode.Redirect, response.StatusCode);
        Assert.Contains("/Login", response.Headers.Location?.OriginalString ?? "",
            StringComparison.OrdinalIgnoreCase);
    }

    // ── yardımcılar ──────────────────────────────────────────────────────────

    /// <summary>(şube sayısı, müdürün şubesindeki kişi-gün, scope dışı kişi-gün)</summary>
    private async Task<(int, int, int)> MeasurePopulationAsync()
    {
        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<Db>();
        using var cn = db.OpenPanel();
        return await cn.QuerySingleAsync<(int, int, int)>("""
            SELECT BranchCount  = (SELECT COUNT(DISTINCT Sube) FROM bkm.Vrd_KisiGun),
                   InScope   = (SELECT COUNT(*) FROM bkm.Vrd_KisiGun WHERE Sube = @sube),
                   OutOfScope  = (SELECT COUNT(*) FROM bkm.Vrd_KisiGun WHERE Sube <> @sube)
            """, new { sube = factory.ManagerBranch });
    }

    /// <summary>
    /// Gerçek tur: giriş formu → antiforgery token → POST → oturum çerezi → report.
    /// Token kazımak zahmetli ama bu bir kusur değil — o zahmet, GERÇEK bir tur
    /// attığımızın kanıtı. Kısayol (IAntiforgery ezmek) gerçek POST yolunu
    /// ölçmez hâle getirirdi.
    /// </summary>
    private async Task<int> ReadPersonDaysAsync(string userName)
    {
        var client = factory.CreateClient(new() { AllowAutoRedirect = true });

        var loginPage = await (await client.GetAsync("/Login")).Content.ReadAsStringAsync();
        var token = Regex.Match(loginPage,
            "name=\"__RequestVerificationToken\"[^>]*value=\"([^\"]+)").Groups[1].Value;
        Assert.False(string.IsNullOrEmpty(token),
            "Antiforgery token bulunamadı — giriş formu değişmiş olabilir; test gerçek POST yapamaz.");

        var loginResponse = await client.PostAsync("/Login", new FormUrlEncodedContent(new Dictionary<string, string>
        {
            ["UserName"] = userName,
            ["Password"] = VardiyaAppFactory.Password,
            // ⚠ Token KAZINMAKLA bitmiyor — gövdeye de konur. Konmayınca ASP.NET
            //   400 döner ve hata "giriş başarısız" gibi okunur: kapsam testi
            //   kapsamı hiç ölçmeden kırmızı verir (yanlış teşhis).
            ["__RequestVerificationToken"] = token,
        }));
        Assert.True(loginResponse.IsSuccessStatusCode, $"Giriş başarısız: {userName}");

        var report = await (await client.GetAsync("/")).Content.ReadAsStringAsync();

        Assert.DoesNotContain("Rapor okunamadı", report);

        // Tutamak `data-test` — HTML biçimi değişse de öznitelik kalır.
        var m = Regex.Match(report, "data-test=\"kisi-gun\"[^>]*>([^<]+)<");
        Assert.True(m.Success,
            $"Kişi-gün KPI'ı bulunamadı ({userName}). Sayfa hata vermiş ya da " +
            "data-test tutamağı kaldırılmış olabilir — test SESSİZCE geçmemeli.");

        return int.Parse(m.Groups[1].Value.Replace(".", "").Replace(",", "").Trim());
    }
}
