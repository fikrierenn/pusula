namespace BkmVardiya.Security;

/// <summary>
/// İzin adları — kodun gördüğü TEK yetki kavramı.
///
/// ⚠ KOD ROL ADI GÖRMEZ (Solum ekibi, 18.09.2026). Gerekçesi ölçülebilir: bir gün
/// dördüncü rol eklendiğinde `if (rol == "IK")` biçimindeki karşılaştırmaların
/// hepsini bulmak gerekir ve biri kaçar. İzin→rol eşlemesi veritabanında
/// (<c>bkm.SolumPermissionGrant</c>); çağrı yerleri hiç değişmez.
///
/// Aynı adlar SQL tarafında da geçer — <c>bkm.Vrd_SubeKapsami</c> TVF'i
/// <c>vardiya.tumSubeler</c> iznini kendisi çözer. İki tarafta aynı dize olmak
/// zorunda; değişirse kapsam sessizce daralır.
/// ⚠ Bunu bugün hiçbir denetim yakalamıyor — SQL metnindeki izin adı ile buradaki
///   sabit karşılaştırılmıyor. Yazılı kural, koşan kural değil.
/// </summary>
public static class Permissions
{
    /// <summary>Claim tipi — izinler bu tiple taşınır.</summary>
    public const string ClaimType = "vardiya.izin";

    /// <summary>Tüm şubeleri görme. ⚠ ACL'ye satır yazarak DEĞİL, bu izinle verilir.</summary>
    public const string AllBranches = "vardiya.tumSubeler";

    /// <summary>Eksik/fazla satırına yönetici onayı yazma.</summary>
    public const string Approve = "vardiya.onayla";

    /// <summary>Kullanıcı/şube ataması yönetme (İK).</summary>
    public const string ManageStaff = "vardiya.kadroYonet";
}
