using Bkm.Shared.Data;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace BkmVardiya.Tests;

/// <summary>
/// PLAN DÜZELTME — plan 49 / V-05.
///
/// Ölçülen şey: düzeltme YAZILIYOR mu · kapsam DIŞINA yazılamıyor mu · hesabı
/// GERÇEKTEN değiştiriyor mu (GMY kararı S1) · izi tam bir kez düşüyor mu.
///
/// ⚠ GERÇEK KİŞİ-GÜN ÜZERİNDE ÇALIŞIR — düzeltme tablosu gerçek sicillere bağlıdır
///   ve uydurma bir sicil kapsam kapısına takılır (yani test hiçbir şey ölçemez).
///   Bu yüzden test kendi yazdığı düzeltmeyi SONUNDA SİLER ve fikstür de
///   `Kaydeden LIKE 'zz_test%'` satırlarını temizler: iki katman, çünkü test
///   ortada çökerse `finally` koşar ama süreç çökerse koşmaz.
/// </summary>
[Collection(VardiyaDbCollection.Name)]
public sealed class PlanCorrectionTests(VardiyaAppFactory factory)
{
    private const string SavedBy = "zz_test_duzeltme";

    [Fact]
    public async Task Correction_changes_effective_totals_and_writes_trail_once()
    {
        using var scope = factory.Services.CreateScope();
        var queries = scope.ServiceProvider.GetRequiredService<VardiyaQueries>();
        var db = scope.ServiceProvider.GetRequiredService<Db>();
        using var cn = db.OpenPanel();

        var (cutoffFrom, cutoffTo, staffNo, date, requiredMin) = await PickPersonDayAsync(cn);

        var before = await queries.GetSummaryAsync(factory.ManagerId, cutoffFrom, cutoffTo);
        Assert.NotNull(before);

        // Tabanı 60 dk AZALT: fazla mesai 60 dk ARTMALI (ya da eksik 60 dk azalmalı).
        // Yönü test etmek için mevcut tabandan türetiyoruz — sabit bir sayı seçmek
        // veriye bağımlı olurdu ve başka bir kesimde sessizce anlamsızlaşırdı.
        var newBase = Math.Max(requiredMin - 60, 0);

        try
        {
            await queries.SavePlanCorrectionAsync(factory.ManagerId, staffNo, date,
                shiftPlan: "zz_test tanım", planStartMin: null, planEndMin: null,
                planWorkMin: newBase, onLeave: null, aciklama: "test", savedBy: SavedBy);

            var after = await queries.GetSummaryAsync(factory.ManagerId, cutoffFrom, cutoffTo);
            Assert.NotNull(after);

            // 1) DÜZELTME SAYILIYOR — ekranda "kaç gün düzeltildi" görünmek zorunda.
            Assert.Equal(before!.CorrectedDays + 1, after!.CorrectedDays);

            // 2) HESAP GERÇEKTEN DEĞİŞTİ (karar S1). Taban düştüğü için toplam
            //    eksik AZALIR ya da toplam fazla ARTAR — hangisi olduğu satırın
            //    gerçekleşmesine bağlı, ama İKİSİ BİRDEN aynı kalamaz.
            var degisti = after.ShortMin != before.ShortMin || after.OvertimeMin != before.OvertimeMin;
            Assert.True(degisti,
                $"Düzeltme hesabı DEĞİŞTİRMEDİ (eksik {before.ShortMin}→{after.ShortMin}, " +
                $"fazla {before.OvertimeMin}→{after.OvertimeMin}). Karar S1'e göre düzeltilmiş " +
                "taban eksik/fazlanın tabanıdır; değişmiyorsa view etkin değerleri okumuyordur.");

            // 3) İZ TAM BİR KEZ — yetki/veri değişikliği izsiz olamaz.
            var iz = await SayAsync(cn, $"{staffNo}|{date:yyyy-MM-dd}");
            Assert.Equal(1, iz);

            // 4) OKUMA GERİ DÖNÜYOR — yazdığımız düzeltme aynı kimlikle okunabiliyor.
            var okunan = await queries.GetPlanCorrectionAsync(factory.ManagerId, staffNo, date);
            Assert.NotNull(okunan);
            Assert.Equal(newBase, okunan!.PlanWorkMin);
        }
        finally
        {
            // Hepsi boş → kayıt silinir; hesap kaynağın değerine döner.
            await queries.SavePlanCorrectionAsync(factory.ManagerId, staffNo, date,
                null, null, null, null, null, null, SavedBy);
        }

        // 5) GERİ ALINDI MI — silme sonrası özet başlangıçtakiyle AYNI olmalı.
        var final = await queries.GetSummaryAsync(factory.ManagerId, cutoffFrom, cutoffTo);
        Assert.Equal(before!.ShortMin, final!.ShortMin);
        Assert.Equal(before.OvertimeMin, final.OvertimeMin);
        Assert.Equal(before.CorrectedDays, final.CorrectedDays);
    }

    /// <summary>
    /// İZİN GÜNÜ — düzeltme süresi tabanı DEĞİŞTİRMEZ; ancak "aslında izinli değildi"
    /// denirse değiştirir.
    ///
    /// ⚠ BU TESTİN SEBEBİ BİR ÖLÇÜM: ilk hâlde view izinli güne yazılan süreyi tabana
    ///   alıyordu ve kişi İZİNDEYKEN 8 saat EKSİK görünüyordu. Delta aritmetiği
    ///   doğruydu, ANLAMI yanlıştı. Tek NORMAL gün üzerinde test edildiği için
    ///   görünmemişti — Solum'un "çok adımlı mantığı tek şekilli fikstürle ölçemezsin"
    ///   uyarısının bizdeki karşılığı.
    /// </summary>
    [Fact]
    public async Task Leave_day_base_is_untouched_unless_explicitly_disputed()
    {
        using var scope = factory.Services.CreateScope();
        var queries = scope.ServiceProvider.GetRequiredService<VardiyaQueries>();
        var db = scope.ServiceProvider.GetRequiredService<Db>();
        using var cn = db.OpenPanel();

        var gun = await PickLeaveDayAsync(cn, factory.ManagerBranch);
        Assert.True(gun is not null,
            "Müdürün kapsamında tabanı 0 olan izinli gün YOK — bu test ölçemez (KOŞAMADI).");
        var (staffNo, date) = gun!.Value;

        try
        {
            // 1) İzinli güne süre yazılır — taban DEĞİŞMEMELİ.
            await queries.SavePlanCorrectionAsync(factory.ManagerId, staffNo, date,
                null, null, null, planWorkMin: 480, onLeave: null, aciklama: "test", savedBy: SavedBy);

            Assert.Equal(0, await EffectiveBaseAsync(cn, staffNo, date));
            Assert.Equal(0, await EffectiveShortAsync(cn, staffNo, date));

            // 2) "Aslında izinli değildi" itirazı — ŞİMDİ taban uygulanır.
            // ⚠ ARTIK SQL ARKA KAPISI DEĞİL (V-18): itiraz uygulamanın kendi
            //   yolundan yazılıyor. Önce SQL ile yazılıyordu ve o hâliyle test,
            //   ÜRÜNÜN YAPAMADIĞI bir şeyi ölçüyordu.
            await queries.SavePlanCorrectionAsync(factory.ManagerId, staffNo, date,
                null, null, null, planWorkMin: 480, onLeave: false, aciklama: "itiraz",
                savedBy: SavedBy);

            Assert.Equal(480, await EffectiveBaseAsync(cn, staffNo, date));
        }
        finally
        {
            await queries.SavePlanCorrectionAsync(factory.ManagerId, staffNo, date,
                null, null, null, null, null, null, SavedBy);
        }
    }

    /// <summary>
    /// Kapsam dışı bir kişi-güne düzeltme YAZILAMAZ. Okuma süzgeci bunu korumaz:
    /// sicil ve tarih elle de gönderilebilir.
    /// </summary>
    [Fact]
    public async Task Correction_outside_scope_is_rejected()
    {
        using var scope = factory.Services.CreateScope();
        var queries = scope.ServiceProvider.GetRequiredService<VardiyaQueries>();

        await Assert.ThrowsAsync<UnauthorizedAccessException>(() =>
            queries.SavePlanCorrectionAsync(factory.ManagerId, "zz_yok_boyle_sicil",
                new DateOnly(2026, 9, 1), "x", null, null, 480, null, null, SavedBy));
    }

    /// <summary>Yarım aralık reddedilir — tek başına bir başlama saati vardiya tanımlamaz.</summary>
    [Fact]
    public async Task Half_interval_is_rejected_with_reason()
    {
        using var scope = factory.Services.CreateScope();
        var queries = scope.ServiceProvider.GetRequiredService<VardiyaQueries>();

        var hata = await Assert.ThrowsAsync<ArgumentException>(() =>
            queries.SavePlanCorrectionAsync(factory.ManagerId, "zz_yok_boyle_sicil",
                new DateOnly(2026, 9, 1), null, planStartMin: 540, planEndMin: null,
                planWorkMin: null, onLeave: null, aciklama: null, savedBy: SavedBy));

        Assert.Contains("İKİSİ BİRDEN", hata.Message);
    }

    // ── yardımcılar ──────────────────────────────────────────────────────────

    /// <summary>
    /// Müdürün kapsamındaki, tabanı SIFIRDAN BÜYÜK bir kişi-gün seçer.
    /// Tabanı 0 olan gün (izin) seçilirse düzeltme hesabı değiştirmez ve test
    /// "geçti" değil "ölçemedim" durumuna düşerdi.
    /// </summary>
    private async Task<(DateOnly, DateOnly, string, DateOnly, int)> PickPersonDayAsync(
        System.Data.IDbConnection cn)
    {
        var row = await AuthSqlLikeQueryAsync(cn, factory.ManagerBranch);
        Assert.True(row is not null,
            "Müdürün kapsamında tabanı > 0 olan kişi-gün YOK — bu test hiçbir şey ölçemez (KOŞAMADI).");
        return row!.Value;
    }

    private static async Task<(DateOnly, DateOnly, string, DateOnly, int)?> AuthSqlLikeQueryAsync(
        System.Data.IDbConnection cn, string branch)
    {
        // ⚠ ŞUBE SÜZGECİ ZORUNLU: ilk yazımda kapsamsız seçiliyordu ve test kendi
        //   kapsam kapısına takıldı ("şube kapsamınızda değil"). Yani hata testin
        //   ölçtüğü şeyde değil, ÖRNEK SEÇİMİNDEYDİ — ve kapı doğru davrandı.
        var r = await Dapper.SqlMapper.QuerySingleOrDefaultAsync<(DateTime, DateTime, string, DateTime, int)?>(cn,
            """
            SELECT TOP 1 KesimBas, KesimBit, SicilNo, Tarih, GerekenDk
            FROM   bkm.Vrd_KisiGun
            WHERE  Sube = @branch AND ISNULL(GerekenDk, 0) > 0 AND SayimDisi = 0
              AND  NOT EXISTS (SELECT 1 FROM bkm.Vrd_PlanDuzeltme d
                               WHERE d.SicilNo = bkm.Vrd_KisiGun.SicilNo
                                 AND d.Tarih   = bkm.Vrd_KisiGun.Tarih)
            ORDER BY Tarih DESC
            """, new { branch });
        if (r is null) return null;
        var (bas, bit, sicil, tarih, gereken) = r.Value;
        return (DateOnly.FromDateTime(bas), DateOnly.FromDateTime(bit), sicil,
                DateOnly.FromDateTime(tarih), gereken);
    }

    private static Task<int> SayAsync(System.Data.IDbConnection cn, string kayitId) =>
        Dapper.SqlMapper.ExecuteScalarAsync<int>(cn, """
            SELECT COUNT(*) FROM bkm.SolumAuditTrail
            WHERE  EntityName = N'Vrd_PlanDuzeltme' AND RecordId = @kayitId
            """, new { kayitId });

    private static async Task<(string, DateOnly)?> PickLeaveDayAsync(
        System.Data.IDbConnection cn, string branch)
    {
        var r = await Dapper.SqlMapper.QuerySingleOrDefaultAsync<(string, DateTime)?>(cn, """
            SELECT TOP 1 SicilNo, Tarih
            FROM   bkm.Vrd_KisiGun
            WHERE  Sube = @branch AND Izin = 1 AND ISNULL(GerekenDk, 0) = 0 AND SayimDisi = 0
              AND  NOT EXISTS (SELECT 1 FROM bkm.Vrd_PlanDuzeltme d
                               WHERE d.SicilNo = bkm.Vrd_KisiGun.SicilNo
                                 AND d.Tarih   = bkm.Vrd_KisiGun.Tarih)
            ORDER BY Tarih DESC
            """, new { branch });
        return r is null ? null : (r.Value.Item1, DateOnly.FromDateTime(r.Value.Item2));
    }

    private static Task<int> EffectiveBaseAsync(System.Data.IDbConnection cn, string sicilNo, DateOnly tarih) =>
        Dapper.SqlMapper.ExecuteScalarAsync<int>(cn, """
            SELECT ISNULL(EtkinGerekenDk, 0) FROM bkm.Vrd_KisiGunDuzeltilmis_vw
            WHERE  SicilNo = @sicilNo AND Tarih = @tarih
            """, new { sicilNo, tarih = tarih.ToDateTime(TimeOnly.MinValue) });

    private static Task<int> EffectiveShortAsync(System.Data.IDbConnection cn, string sicilNo, DateOnly tarih) =>
        Dapper.SqlMapper.ExecuteScalarAsync<int>(cn, """
            SELECT ISNULL(EtkinEksikDk, 0) FROM bkm.Vrd_KisiGunDuzeltilmis_vw
            WHERE  SicilNo = @sicilNo AND Tarih = @tarih
            """, new { sicilNo, tarih = tarih.ToDateTime(TimeOnly.MinValue) });

    /// <summary>
    /// EKRAN YOLU (V-18) — "izinli DEĞİLDİ" itirazı formdan yazılabiliyor mu?
    ///
    /// ⚠ NEDEN AYRI TEST: servis metodu `bool?` alıyordu ve itirazı ZATEN
    ///   destekliyordu; eksik olan EKRANDI (onay kutusu iki durum taşıyor, üçüncüsü
    ///   yok). Yani servis testi yeşilken kullanıcı o işi YAPAMIYORDU — "ürün
    ///   çalışıyor" ile "kullanıcı yapabiliyor" aynı şey değil.
    /// </summary>
    [Fact]
    public async Task Dispute_can_be_written_from_the_screen()
    {
        using var scope = factory.Services.CreateScope();
        var queries = scope.ServiceProvider.GetRequiredService<VardiyaQueries>();
        var db = scope.ServiceProvider.GetRequiredService<Db>();
        using var cn = db.OpenPanel();

        var gun = await PickLeaveDayAsync(cn, factory.ManagerBranch);
        Assert.True(gun is not null, "İzinli gün YOK — ekran testi ölçemez (KOŞAMADI).");
        var (staffNo, date) = gun!.Value;

        var client = factory.CreateClient(new() { AllowAutoRedirect = true });
        var loginPage = await (await client.GetAsync("/Login")).Content.ReadAsStringAsync();
        var loginToken = System.Text.RegularExpressions.Regex.Match(loginPage,
            "name=\"__RequestVerificationToken\"[^>]*value=\"([^\"]+)").Groups[1].Value;
        await client.PostAsync("/Login", new FormUrlEncodedContent(new Dictionary<string, string>
        {
            ["UserName"] = factory.ManagerName,
            ["Password"] = VardiyaAppFactory.Password,
            ["__RequestVerificationToken"] = loginToken,
        }));

        var url = $"/Approval?StaffNo={Uri.EscapeDataString(staffNo)}&Date={date:yyyy-MM-dd}";
        var form = await (await client.GetAsync(url)).Content.ReadAsStringAsync();
        Assert.Contains("OnLeaveChoice", form);   // üç durumlu seçim EKRANDA mı

        var token = System.Text.RegularExpressions.Regex.Match(form,
            "name=\"__RequestVerificationToken\"[^>]*value=\"([^\"]+)").Groups[1].Value;

        try
        {
            await client.PostAsync(url + "&handler=Plan", new FormUrlEncodedContent(
                new Dictionary<string, string>
                {
                    ["StaffNo"] = staffNo,
                    ["Date"] = date.ToString("yyyy-MM-dd"),
                    ["PlanWork"] = "08:00",
                    ["OnLeaveChoice"] = "0",          // itiraz
                    ["PlanNote"] = "ekran testi",
                    ["__RequestVerificationToken"] = token,
                }));

            var kayit = await queries.GetPlanCorrectionAsync(factory.ManagerId, staffNo, date);
            Assert.NotNull(kayit);
            Assert.False(kayit!.OnLeave);            // null DEĞİL, false — itiraz yazıldı
            Assert.Equal(480, await EffectiveBaseAsync(cn, staffNo, date));
        }
        finally
        {
            await queries.SavePlanCorrectionAsync(factory.ManagerId, staffNo, date,
                null, null, null, null, null, null, SavedBy);
        }
    }
}
