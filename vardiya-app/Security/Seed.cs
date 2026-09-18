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
///   (ProviderName='Role'). Kişi rol değiştirince izinleri kendiliğinden değişir.
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
    public const string RolGmy = "GMY";
    public const string RolIk = "IK";
    public const string RolSubeSorumlusu = "SubeSorumlusu";

    /// <summary>İlk girişte şifre değiştirme zorunluluğu — claim tipi.</summary>
    public const string SifreDegistirClaim = "vardiya.sifreDegistir";

    private static readonly (string Rol, string[] Izinler)[] RolIzinleri =
    [
        // GMY salt-okuma + denetim: onay YAZMAZ (plan 48 yetki matrisi).
        (RolGmy, [Permissions.AllBranches]),
        (RolIk, [Permissions.AllBranches, Permissions.Approve, Permissions.ManageStaff]),
        // Şube sorumlusu "tüm şubeler" ALMAZ — kapsamı ACL satırlarından gelir.
        (RolSubeSorumlusu, [Permissions.Approve]),
    ];

    /// <summary>Ad Soyad · rol · şubeler (şube sorumlusu değilse boş).</summary>
    private static readonly (string AdSoyad, string Rol, string[] Subeler)[] Kadro =
    [
        ("FİKRİ EREN",          RolGmy, []),
        ("FARUK BİNGÖLBALİ",    RolGmy, []),

        ("CEREN BİLMİŞ",        RolIk,  []),
        ("ESRA YENER",          RolIk,  []),
        ("SERPİL YAĞLI",        RolIk,  []),

        ("RESUL ÇİL",           RolSubeSorumlusu, ["FSM"]),
        ("NECMETTİN ÇELİK",     RolSubeSorumlusu, ["FSM"]),
        ("ERKAL GÜDENLİ",       RolSubeSorumlusu, ["İST. YOLU"]),
        ("ÖMER FARUK KIRMACI",  RolSubeSorumlusu, ["İST. YOLU"]),
        ("EREN BORAN",          RolSubeSorumlusu, ["İST. YOLU"]),
        ("ABDURRAHMAN UĞURLU",  RolSubeSorumlusu, ["ÖZLÜCE"]),
        ("AYDIN ÖZCAN",         RolSubeSorumlusu, ["ÖZLÜCE"]),
        ("SIRAÇ YİĞİT",         RolSubeSorumlusu, ["ÖZLÜCE"]),
        ("CİHAT BİNGÖLBALİ",    RolSubeSorumlusu, ["ŞURA"]),
        ("EMRAH ÖZCAN",         RolSubeSorumlusu, ["ŞURA"]),
        ("RECEP ÖZCAN",         RolSubeSorumlusu, ["HEYKEL"]),
        // Kafeler müdürü ÜÇ şubeden sorumlu — ACL'nin çok-a-çok olmasının
        // ilk gerçek kullanımı (Solum'un 18.09'da uyardığı şekil).
        ("MURAT SADIK ERBAŞ",   RolSubeSorumlusu, ["FSM KAFE", "İST. YOLU KAFE", "ÖZLÜCE KAFE"]),
    ];

    public static async Task<int> CalistirAsync(IServiceProvider sp, ILogger logger)
    {
        var userManager = sp.GetRequiredService<UserManager<IdentityUser>>();
        var db = sp.GetRequiredService<Db>();

        using var cn = db.OpenPanel();

        // Şube adları DB'de gerçekten var mı? Yoksa ACL'nin FK'sı patlar — ama
        // hata mesajı "FK ihlali" olur ve sebebi görünmez. Önce açıkça ölç.
        var gecerliSubeler = (await cn.QueryAsync<string>("SELECT Sube FROM bkm.Vrd_Sube")).ToHashSet();
        var eksik = Kadro.SelectMany(k => k.Subeler).Distinct()
                         .Where(s => !gecerliSubeler.Contains(s)).ToList();
        if (eksik.Count > 0)
        {
            logger.LogError("Kadro listesinde bkm.Vrd_Sube'de OLMAYAN şube(ler) var: {Subeler}. "
                          + "Seed durduruldu — yanlış şube adı kapsamı SESSİZCE boşaltırdı.",
                            string.Join(", ", eksik));
            return 2;   // KOŞAMADI
        }

        // ── Roller ────────────────────────────────────────────────────────────
        // ⚠ RoleManager KULLANILMIYOR: Solum.Identity `IRoleStore` vermiyor
        //   (yalnız IUserStore + IUserRoleStore). Rol satırı doğrudan yazılır;
        //   kullanıcı-rol ataması yine UserManager üzerinden gider.
        foreach (var (rol, _) in RolIzinleri)
            await cn.ExecuteAsync("""
                IF NOT EXISTS (SELECT 1 FROM bkm.Vrd_Roles WHERE NormalizedName = @norm)
                INSERT INTO bkm.Vrd_Roles (Id, Name, NormalizedName, ConcurrencyStamp)
                VALUES (@id, @rol, @norm, NEWID());
                """, new { id = Guid.NewGuid().ToString(), rol, norm = rol.ToUpperInvariant() });

        // ── Rol → izin ────────────────────────────────────────────────────────
        foreach (var (rol, izinler) in RolIzinleri)
            foreach (var izin in izinler)
                await cn.ExecuteAsync("""
                    IF NOT EXISTS (SELECT 1 FROM bkm.SolumPermissionGrant
                                   WHERE ProviderName=N'Role' AND ProviderKey=@rol AND PermissionName=@izin)
                    INSERT INTO bkm.SolumPermissionGrant (ProviderName, ProviderKey, PermissionName)
                    VALUES (N'Role', @rol, @izin);
                    """, new { rol, izin });

        // ── Kullanıcılar ──────────────────────────────────────────────────────
        var sifreler = new List<string>();
        int yeni = 0, atlanan = 0;

        foreach (var (adSoyad, rol, subeler) in Kadro)
        {
            var kullaniciAdi = KullaniciAdiUret(adSoyad);
            var mevcut = await userManager.FindByNameAsync(kullaniciAdi);
            if (mevcut is not null)
            {
                atlanan++;
                continue;   // ⚠ DOKUNMA: şifre sıfırlamak sessiz bir kilitleme olurdu.
            }

            var gecici = GeciciSifreUret();
            var kullanici = new IdentityUser { UserName = kullaniciAdi, LockoutEnabled = true };
            var sonuc = await userManager.CreateAsync(kullanici, gecici);
            if (!sonuc.Succeeded)
            {
                logger.LogError("Kullanıcı kurulamadı {Ad}: {Hata}", kullaniciAdi,
                                string.Join("; ", sonuc.Errors.Select(e => e.Description)));
                return 1;
            }

            await userManager.AddToRoleAsync(kullanici, rol);
            await userManager.AddClaimAsync(kullanici,
                new System.Security.Claims.Claim(SifreDegistirClaim, "1"));

            foreach (var sube in subeler)
                await cn.ExecuteAsync("""
                    IF NOT EXISTS (SELECT 1 FROM bkm.Vrd_KullaniciSube
                                   WHERE UserId=@id AND Sube=@sube AND GecerliBit IS NULL)
                    INSERT INTO bkm.Vrd_KullaniciSube (UserId, Sube, VerenId)
                    VALUES (@id, @sube, N'seed');
                    """, new { id = kullanici.Id, sube });

            sifreler.Add($"{kullaniciAdi}\t{gecici}\t{adSoyad}\t{rol}\t{string.Join(" | ", subeler)}");
            yeni++;
        }

        // ── Geçici şifreler: ciktilar/ altına (git yoksayar) ──────────────────
        if (sifreler.Count > 0)
        {
            var klasor = Path.Combine(Directory.GetCurrentDirectory(), "..", "ciktilar");
            Directory.CreateDirectory(klasor);
            var dosya = Path.Combine(klasor, $"vardiya-ilk-sifreler-{DateTime.Now:yyyyMMdd-HHmm}.txt");
            await File.WriteAllTextAsync(dosya,
                "# BKM Vardiya — ilk giriş şifreleri\r\n"
              + "# Bu dosya git'e GİRMEZ (ciktilar/ yoksayılı). Dağıtım sonrası SİLİN.\r\n"
              + "# Kullanıcı ilk girişte şifresini DEĞİŞTİRMEK ZORUNDA.\r\n"
              + "# kullanıcı adı\tgeçici şifre\tad soyad\trol\tşubeler\r\n"
              + string.Join("\r\n", sifreler) + "\r\n", Encoding.UTF8);
            // ⚠ Dosya YOLU loglanır, İÇERİĞİ loglanmaz.
            logger.LogInformation("Geçici şifreler yazıldı: {Dosya}", dosya);
        }

        logger.LogInformation("Seed tamam — {Yeni} yeni kullanıcı, {Atlanan} mevcut (dokunulmadı), "
                            + "{Rol} rol.", yeni, atlanan, RolIzinleri.Length);
        return 0;
    }

    /// <summary>"FİKRİ EREN" → "fikri.eren". Türkçe harfler ASCII'ye çevrilir —
    /// kullanıcı adı teknik bir alandır, UI metni değil.</summary>
    public static string KullaniciAdiUret(string adSoyad)
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
    private static string GeciciSifreUret()
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
