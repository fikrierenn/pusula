using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using Bkm.Shared.Data;
using Dapper;
using Microsoft.AspNetCore.Identity;

namespace BkmVardiya.Security;

/// <summary>
/// İlk kadro kurulumu — roller, izinler, kullanıcılar, şube ACL'i.
///
/// Çalıştırma:  dotnet run --project vardiya-app -- seed
///
/// TASARIM KARARLARI (plan 48 Adım 4):
/// • ŞİFRE KODA GİRMEZ. Her kullanıcıya kriptografik rastgele geçici şifre üretilir,
///   hash'i DB'ye yazılır, DÜZ METNİ yalnız <c>ciktilar/</c> altındaki dosyaya (git
///   yoksayar) — İK oradan dağıtır. Konsola basılmaz, loglanmaz.
/// • İLK GİRİŞTE DEĞİŞTİRME ZORUNLU: kullanıcıya <c>vardiya.sifreDegistir</c> claim'i
///   yazılır. Claim standart <c>Vrd_UserClaims</c> tablosunda durur — IdentityUser'ı
///   genişletmeye gerek yok (Solum'un DapperUserStore'u standart kolonları yazar).
/// • İZİN ROLE BAĞLANIR, kullanıcıya değil: <c>SolumPermissionGrant</c>
///   (ProviderName='Role'). Kişi role değiştirince izinleri kendiliğinden değişir.
/// • İDEMPOTENT: var olan kullanıcıya DOKUNMAZ — şifresini sıfırlamaz, rolünü
///   bozmaz. Yeniden koşmak güvenli.
///
/// ⚠ KADRO LİSTESİ ÖLÇÜLDÜ (19.09.2026, Zirve <c>vw_PersonelDepartman</c>, işten
///   çıkışı olmayanlar): mağaza müdürü + müdür yardımcısı + kafeler müdürü +
///   İK + GMY. Reyon/kasa şefleri BİLEREK DIŞARIDA — onay yetkisi istenmedi.
/// ⚠ Liste KODA GÖMÜLÜ ve bu bir borçtur: kadro değişince burası bayatlar. Doğrusu
///   Zirve'den canlı okumak; ilk kurulum için sabit liste tercih edildi çünkü
///   Zirve↔vardiya şube adları BİREBİR EŞLEŞMİYOR (GENEL YÖNETİM ↔ GENEL MÜDÜRLÜK)
///   ve eşleme tablosu henüz yok (Solum plan-21 bekliyor).
/// </summary>
public static class Seed
{
    public const string RoleGmy = "GMY";
    public const string RoleHr = "IK";
    public const string RoleBranchManager = "SubeSorumlusu";

    /// <summary>İlk girişte şifre değiştirme zorunluluğu — claim tipi.</summary>
    public const string MustChangePasswordClaim = "vardiya.sifreDegistir";

    private static readonly (string Role, string[] PermissionNames)[] RolePermissions =
    [
        // GMY salt-okuma + denetim: onay YAZMAZ (plan 48 yetki matrisi).
        (RoleGmy, [Permissions.AllBranches]),
        (RoleHr, [Permissions.AllBranches, Permissions.Approve, Permissions.ManageStaff]),
        // Şube sorumlusu "tüm şubeler" ALMAZ — kapsamı ACL satırlarından gelir.
        (RoleBranchManager, [Permissions.Approve]),
    ];

    /// <summary>Ad Soyad · role · şubeler (şube sorumlusu değilse boş).</summary>
    private static readonly (string FullName, string Role, string[] Branches)[] Staff =
    [
        ("FİKRİ EREN",          RoleGmy, []),
        ("FARUK BİNGÖLBALİ",    RoleGmy, []),

        ("CEREN BİLMİŞ",        RoleHr,  []),
        ("ESRA YENER",          RoleHr,  []),
        ("SERPİL YAĞLI",        RoleHr,  []),

        ("RESUL ÇİL",           RoleBranchManager, ["FSM"]),
        ("NECMETTİN ÇELİK",     RoleBranchManager, ["FSM"]),
        ("ERKAL GÜDENLİ",       RoleBranchManager, ["İST. YOLU"]),
        ("ÖMER FARUK KIRMACI",  RoleBranchManager, ["İST. YOLU"]),
        ("EREN BORAN",          RoleBranchManager, ["İST. YOLU"]),
        ("ABDURRAHMAN UĞURLU",  RoleBranchManager, ["ÖZLÜCE"]),
        ("AYDIN ÖZCAN",         RoleBranchManager, ["ÖZLÜCE"]),
        ("SIRAÇ YİĞİT",         RoleBranchManager, ["ÖZLÜCE"]),
        ("CİHAT BİNGÖLBALİ",    RoleBranchManager, ["ŞURA"]),
        ("EMRAH ÖZCAN",         RoleBranchManager, ["ŞURA"]),
        ("RECEP ÖZCAN",         RoleBranchManager, ["HEYKEL"]),
        // Kafeler müdürü ÜÇ şubeden sorumlu — ACL'nin çok-a-çok olmasının
        // ilk gerçek kullanımı (Solum'un 18.09'da uyardığı şekil).
        ("MURAT SADIK ERBAŞ",   RoleBranchManager, ["FSM KAFE", "İST. YOLU KAFE", "ÖZLÜCE KAFE"]),
    ];

    public static async Task<int> CalistirAsync(IServiceProvider sp, ILogger logger)
    {
        var userManager = sp.GetRequiredService<UserManager<IdentityUser>>();
        var db = sp.GetRequiredService<Db>();

        using var cn = db.OpenPanel();

        // Şube adları DB'de gerçekten var mı? Yoksa ACL'nin FK'sı patlar — ama
        // hata mesajı "FK ihlali" olur ve sebebi görünmez. Önce açıkça ölç.
        var validBranches = (await cn.QueryAsync<string>("SELECT Sube FROM bkm.Vrd_Sube")).ToHashSet();
        var missing = Staff.SelectMany(k => k.Branches).Distinct()
                         .Where(s => !validBranches.Contains(s)).ToList();
        if (missing.Count > 0)
        {
            logger.LogError("Kadro listesinde bkm.Vrd_Sube'de OLMAYAN şube(ler) var: {Subeler}. "
                          + "Seed durduruldu — yanlış şube adı kapsamı SESSİZCE boşaltırdı.",
                            string.Join(", ", missing));
            return 2;   // KOŞAMADI
        }

        // ── Roller ────────────────────────────────────────────────────────────
        // ⚠ RoleManager KULLANILMIYOR: Solum.Identity `IRoleStore` vermiyor
        //   (yalnız IUserStore + IUserRoleStore). Role satırı doğrudan yazılır;
        //   kullanıcı-role ataması yine UserManager üzerinden gider.
        foreach (var (role, _) in RolePermissions)
            await cn.ExecuteAsync("""
                IF NOT EXISTS (SELECT 1 FROM bkm.Vrd_Roles WHERE NormalizedName = @norm)
                INSERT INTO bkm.Vrd_Roles (Id, Name, NormalizedName, ConcurrencyStamp)
                VALUES (@id, @rol, @norm, NEWID());
                """, new { id = Guid.NewGuid().ToString(), role, norm = role.ToUpperInvariant() });

        // ── Role → permission ────────────────────────────────────────────────────────
        foreach (var (role, permissionNames) in RolePermissions)
            foreach (var permission in permissionNames)
                await cn.ExecuteAsync("""
                    IF NOT EXISTS (SELECT 1 FROM bkm.SolumPermissionGrant
                                   WHERE ProviderName=N'Role' AND ProviderKey=@rol AND PermissionName=@izin)
                    INSERT INTO bkm.SolumPermissionGrant (ProviderName, ProviderKey, PermissionName)
                    VALUES (N'Role', @rol, @izin);
                    """, new { role, permission });

        // ── Kullanıcılar ──────────────────────────────────────────────────────
        var passwords = new List<string>();
        int created = 0, skipped = 0;

        foreach (var (fullName, role, branches) in Staff)
        {
            var userName = BuildUserName(fullName);
            var existing = await userManager.FindByNameAsync(userName);
            if (existing is not null)
            {
                skipped++;
                continue;   // ⚠ DOKUNMA: şifre sıfırlamak sessiz bir kilitleme olurdu.
            }

            var tempPassword = GenerateTempPassword();
            var user = new IdentityUser { UserName = userName, LockoutEnabled = true };
            var result = await userManager.CreateAsync(user, tempPassword);
            if (!result.Succeeded)
            {
                logger.LogError("Kullanıcı kurulamadı {Ad}: {Hata}", userName,
                                string.Join("; ", result.Errors.Select(e => e.Description)));
                return 1;
            }

            await userManager.AddToRoleAsync(user, role);
            await userManager.AddClaimAsync(user,
                new System.Security.Claims.Claim(MustChangePasswordClaim, "1"));

            foreach (var branch in branches)
                await cn.ExecuteAsync("""
                    IF NOT EXISTS (SELECT 1 FROM bkm.Vrd_KullaniciSube
                                   WHERE UserId=@id AND Sube=@sube AND GecerliBit IS NULL)
                    INSERT INTO bkm.Vrd_KullaniciSube (UserId, Sube, VerenId)
                    VALUES (@id, @sube, N'seed');
                    """, new { id = user.Id, branch });

            passwords.Add($"{userName}\t{tempPassword}\t{fullName}\t{role}\t{string.Join(" | ", branches)}");
            created++;
        }

        // ── Geçici şifreler: ciktilar/ altına (git yoksayar) ──────────────────
        if (passwords.Count > 0)
        {
            var folder = Path.Combine(Directory.GetCurrentDirectory(), "..", "ciktilar");
            Directory.CreateDirectory(folder);
            var file = Path.Combine(folder, $"vardiya-ilk-sifreler-{DateTime.Now:yyyyMMdd-HHmm}.txt");
            await File.WriteAllTextAsync(file,
                "# BKM Vardiya — ilk giriş şifreleri\r\n"
              + "# Bu dosya git'e GİRMEZ (ciktilar/ yoksayılı). Dağıtım sonrası SİLİN.\r\n"
              + "# Kullanıcı ilk girişte şifresini DEĞİŞTİRMEK ZORUNDA.\r\n"
              + "# kullanıcı adı\tgeçici şifre\tad soyad\trol\tşubeler\r\n"
              + string.Join("\r\n", passwords) + "\r\n", Encoding.UTF8);
            // ⚠ Dosya YOLU loglanır, İÇERİĞİ loglanmaz.
            logger.LogInformation("Geçici şifreler yazıldı: {Dosya}", file);
        }

        logger.LogInformation("Seed tamam — {Yeni} yeni kullanıcı, {Atlanan} mevcut (dokunulmadı), "
                            + "{Rol} rol.", created, skipped, RolePermissions.Length);
        return 0;
    }

    /// <summary>"FİKRİ EREN" → "fikri.eren". Türkçe harfler ASCII'ye çevrilir —
    /// kullanıcı adı teknik bir alandır, UI metni değil.</summary>
    public static string BuildUserName(string adSoyad)
    {
        var s = adSoyad.Trim().ToLower(new CultureInfo("tr-TR"));
        var sb = new StringBuilder();
        foreach (var ch in s)
            sb.Append(ch switch
            {
                'ı' => 'i', 'ş' => 's', 'ğ' => 'g', 'ü' => 'u', 'ö' => 'o', 'ç' => 'c',
                ' ' => '.',
                _ => ch,
            });
        return sb.ToString();
    }

    /// <summary>Kriptografik rastgele geçici şifre (Identity kuralı: en az 10 karakter).</summary>
    private static string GenerateTempPassword()
    {
        // Karışması kolay karakterler (0/O, 1/l/I) BİLEREK yok — şifre elle yazılacak.
        const string harf = "abcdefghjkmnpqrstuvwxyz";
        const string buyuk = "ABCDEFGHJKMNPQRSTUVWXYZ";
        const string rakam = "23456789";
        const string ozel = "!*-+?";
        var havuz = harf + buyuk + rakam + ozel;

        var sb = new StringBuilder();
        sb.Append(buyuk[RandomNumberGenerator.GetInt32(buyuk.Length)]);
        sb.Append(harf[RandomNumberGenerator.GetInt32(harf.Length)]);
        sb.Append(rakam[RandomNumberGenerator.GetInt32(rakam.Length)]);
        sb.Append(ozel[RandomNumberGenerator.GetInt32(ozel.Length)]);
        for (int i = 0; i < 8; i++)
            sb.Append(havuz[RandomNumberGenerator.GetInt32(havuz.Length)]);
        return sb.ToString();
    }
}
