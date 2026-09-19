using Bkm.Shared.Data;
using BkmVardiya.Security;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace BkmVardiya.Tests;

/// <summary>
/// ŞUBE YETKİSİ YAZMA YOLU — V-13.
///
/// NEDEN VAR: bu SQL 19.09.2026'da SESSİZCE kırıktı (SQL <c>@sube</c>, C# <c>branch</c>)
/// ve kırıklığı GÖRÜNMEZDİ, çünkü:
///   • seed mevcut kullanıcıyı atlıyor → yeniden koşturmak bu satırı ÇALIŞTIRMIYOR,
///   • ACL satırları zaten yazılmıştı (kusur, koşumdan SONRA yapılan yeniden
///     adlandırmayla girdi),
///   • ve derleme temizdi.
/// Yani "seed'i tekrar çalıştır, bak bakalım" bir DOĞRULAMA DEĞİLDİ. Doğrulama,
/// yazma yolunu doğrudan koşturmaktır — bu test onu yapar.
///
/// ⚠ GERÇEK VERİTABANI: yetki yazması bir güvenlik yoludur; sahte bağlantıyla
///   ölçülürse kolon adı/FK/koşullu UNIQUE hiç sınanmamış olur.
/// ⚠ Kullanıcı <c>zz_test_</c> önekli; fikstür başta ve sonda temizler.
/// </summary>
[Collection(VardiyaDbCollection.Name)]
public class SeedAclWriteTests(VardiyaAppFactory factory)
{
    [Fact]
    public async Task Branch_grant_writes_and_is_idempotent()
    {
        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<Db>();
        using var cn = db.OpenPanel();

        // Fikstürün müdürüne İKİNCİ bir şube verilir. Gerçek bir şube adı seçilir:
        // uydurulmuş ad FK'ya takılır ve test "yazma çalışmıyor" gibi okunurdu.
        var otherBranch = (await AuthSql.QueryAsync<string>(cn, """
            SELECT TOP 1 Sube FROM bkm.Vrd_Sube
            WHERE  Sube <> @mevcut
            ORDER BY Sube
            """, new SqlParams().Add("mevcut", factory.ManagerBranch))).SingleOrDefault();

        Assert.False(string.IsNullOrEmpty(otherBranch),
            "bkm.Vrd_Sube'de ikinci bir şube YOK — bu test hiçbir şey ölçemez (KOŞAMADI).");

        var before = await CountAsync(cn, factory.ManagerId);

        await Seed.GrantBranchAsync(cn, factory.ManagerId, otherBranch!, "zz_test");
        var after = await CountAsync(cn, factory.ManagerId);
        Assert.Equal(before + 1, after);

        // İdempotenlik: aynı şube ikinci kez → yeni satır AÇILMAZ. Mükerrer satır
        // zamansal ACL'i (GecerliBit IS NULL = yürürlükte) bozardı.
        await Seed.GrantBranchAsync(cn, factory.ManagerId, otherBranch!, "zz_test");
        Assert.Equal(after, await CountAsync(cn, factory.ManagerId));

        // Yazılan satır GERÇEKTEN o şube mi? Sayı doğru ama şube yanlış olabilirdi.
        var branches = await AuthSql.QueryAsync<string>(cn, """
            SELECT Sube FROM bkm.Vrd_KullaniciSube
            WHERE  UserId = @id AND GecerliBit IS NULL
            """, new SqlParams().Add("id", factory.ManagerId));
        Assert.Contains(otherBranch, branches);

        // DENETİM İZİ (V-12): yetki verme bir OLAYDIR ve izi olmadan
        // "kime hangi şube verildi, kim verdi" sorusunun cevabı yoktur.
        // ⚠ İZ TAM BİR KEZ: idempotent ikinci çağrı olay değildir. İki satır
        //   çıkarsa iz gürültüye boğulur ve gerçek yetki verme kaybolur.
        var trail = await AuthSql.QueryAsync<int>(cn, """
            SELECT COUNT(*) FROM bkm.SolumAuditTrail
            WHERE  EntityName = N'Vrd_KullaniciSube' AND RecordId = @kayit
            """, new SqlParams().Add("kayit", $"{factory.ManagerId}|{otherBranch}"));
        Assert.Equal(1, trail.Single());
    }

    private static async Task<int> CountAsync(System.Data.IDbConnection cn, string userId)
        => (await AuthSql.QueryAsync<int>(cn, """
            SELECT COUNT(*) FROM bkm.Vrd_KullaniciSube
            WHERE  UserId = @id AND GecerliBit IS NULL
            """, new SqlParams().Add("id", userId))).Single();
}
