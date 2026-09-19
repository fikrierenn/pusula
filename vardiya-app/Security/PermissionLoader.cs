using System.Security.Claims;
using Bkm.Shared.Data;

namespace BkmVardiya.Security;

/// <summary>
/// Kullanıcının izinlerini <c>bkm.SolumPermissionGrant</c>'tan okur.
///
/// İzin iki yoldan gelebilir (Solum'un sağlayıcı modeli):
///   ProviderName='User' + ProviderKey=&lt;kullanıcı id&gt;
///   ProviderName='Role' + ProviderKey=&lt;rol adı&gt;   → kullanıcının rolleri üzerinden
///
/// ⚠ İZİNLER GİRİŞTE ÇEREZE YAZILIR ve oturum boyunca taşınır. Bu bilinçli bir
///   takas: her istekte DB'ye sormamak. BEDELİ — bir yetki KALDIRILDIĞINDA kullanıcı
///   çıkış yapana kadar onu taşımaya devam eder (en fazla 10 saat, çerez ömrü).
///   Yetki EKLEME anında etkili olmaz; kullanıcı yeniden girmelidir.
///
/// ⚠ Solum'un <c>IsCrossCompany</c> emsali BURAYA UYGULANMADI ve sebebi ayrı:
///   orada konsolide hak "her seferinde yeniden" isteniyor çünkü tüzel kişilik
///   sınırını açıyor. Burada "tüm şubeler" bir görüntüleme kapsamı; şube sınırı
///   YAZMA tarafında ayrıca SQL'de (Vrd_SubeKapsami) zorlanıyor, yani çerezdeki
///   bayat bir izin tek başına yanlış şubeye yazdıramaz.
/// </summary>
public sealed class PermissionLoader(Db db)
{
    public async Task<IReadOnlyList<Claim>> LoadAsync(string userId)
    {
        using var cn = db.OpenPanel();
        var permissions = await AuthSql.QueryAsync<string>(cn, """
            SELECT DISTINCT g.PermissionName
            FROM   bkm.SolumPermissionGrant g
            WHERE (g.ProviderName = N'User' AND g.ProviderKey = @userId)
               OR (g.ProviderName = N'Role' AND EXISTS (
                     SELECT 1
                     FROM   bkm.Vrd_UserRoles ur
                     JOIN   bkm.Vrd_Roles     r ON r.Id = ur.RoleId
                     WHERE  ur.UserId = @userId AND r.Name = g.ProviderKey))
            """, new SqlParams().Add("userId", userId));

        return permissions.Select(p => new Claim(Permissions.ClaimType, p)).ToList();
    }
}
