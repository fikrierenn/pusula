using System.Security.Cryptography;
using Dapper;

namespace GmDashboard.Data;

/// <summary>Panel auth (B-84) — tek-kullanıcı, localhost BkmPanel.dbo.PanelKullanici.
/// PBKDF2-SHA256 100k. Başarısız sayaç + kilit SQL'de. Şifre koda/env-plain GİRMEZ — ilk açılış /setup ile belirlenir.</summary>
public sealed class AuthService(Db db, ILogger<AuthService> logger)
{
    private const int Iter = 100_000, SaltLen = 16, HashLen = 32, MaxHata = 5, KilitDk = 5;

    public bool Enabled => db.PanelEnabled;

    /// <summary>Hiç kullanıcı var mı (yoksa ilk-kurulum /setup gerekir).</summary>
    public async Task<bool> KullaniciVarMiAsync()
    {
        var open = db.OpenPanelAsync();
        if (open is null) return false;
        await using var conn = await open;
        return await conn.ExecuteScalarAsync<int>("SELECT COUNT(*) FROM dbo.PanelKullanici WHERE Aktif=1") > 0;
    }

    /// <summary>İlk kurulum — yalnızca tablo BOŞken kullanıcı oluşturur (yarış: WHERE NOT EXISTS).</summary>
    public async Task<bool> SetupAsync(string kullaniciAdi, string sifre)
    {
        if (string.IsNullOrWhiteSpace(kullaniciAdi) || sifre.Length < 6) return false;
        var open = db.OpenPanelAsync();
        if (open is null) return false;
        var salt = RandomNumberGenerator.GetBytes(SaltLen);
        var hash = Hashle(sifre, salt);
        await using var conn = await open;
        var n = await conn.ExecuteAsync("""
            INSERT INTO dbo.PanelKullanici (KullaniciAdi, SifreHash, Salt, Iterasyon, Aktif)
            SELECT @ad, @hash, @salt, @iter, 1
            WHERE NOT EXISTS (SELECT 1 FROM dbo.PanelKullanici)
            """, new { ad = kullaniciAdi.Trim(), hash, salt, iter = Iter });
        return n == 1;
    }

    /// <summary>Şifre doğrula — kilit kontrol → PBKDF2 verify → sayaç/SonGiris güncelle.</summary>
    public async Task<AuthSonuc> DogrulaAsync(string kullaniciAdi, string sifre)
    {
        var open = db.OpenPanelAsync();
        if (open is null) return AuthSonuc.Kapali;
        await using var conn = await open;
        var k = await conn.QueryFirstOrDefaultAsync<KullaniciRow>("""
            SELECT Id, SifreHash, Salt, Iterasyon, BasarisizSayac, KilitBitis
            FROM dbo.PanelKullanici WHERE KullaniciAdi=@ad AND Aktif=1
            """, new { ad = kullaniciAdi.Trim() });

        if (k is null || k.SifreHash is null || k.Salt is null) return AuthSonuc.Yanlis;
        if (k.KilitBitis is { } kb && kb > DateTime.UtcNow) return AuthSonuc.Kilitli;

        var beklenen = Hashle(sifre, k.Salt, k.Iterasyon);
        if (CryptographicOperations.FixedTimeEquals(beklenen, k.SifreHash))
        {
            await conn.ExecuteAsync("UPDATE dbo.PanelKullanici SET BasarisizSayac=0, KilitBitis=NULL, SonGiris=SYSUTCDATETIME() WHERE Id=@id", new { id = k.Id });
            return AuthSonuc.Basarili;
        }

        // Yanlış → sayaç artır, eşik aşılırsa kilitle.
        var yeniSayac = k.BasarisizSayac + 1;
        DateTime? kilit = yeniSayac >= MaxHata ? DateTime.UtcNow.AddMinutes(KilitDk) : null;
        await conn.ExecuteAsync("UPDATE dbo.PanelKullanici SET BasarisizSayac=@s, KilitBitis=@kb WHERE Id=@id",
            new { s = yeniSayac, kb = kilit, id = k.Id });
        logger.LogWarning("Panel login başarısız — kullanıcı {Ad}, sayaç {Sayac}", kullaniciAdi, yeniSayac);
        return kilit is null ? AuthSonuc.Yanlis : AuthSonuc.Kilitli;
    }

    private static byte[] Hashle(string sifre, byte[] salt, int iter = Iter) =>
        Rfc2898DeriveBytes.Pbkdf2(sifre, salt, iter, HashAlgorithmName.SHA256, HashLen);

    private sealed class KullaniciRow
    {
        public int Id { get; set; }
        public byte[]? SifreHash { get; set; }
        public byte[]? Salt { get; set; }
        public int Iterasyon { get; set; }
        public int BasarisizSayac { get; set; }
        public DateTime? KilitBitis { get; set; }
    }
}

public enum AuthSonuc { Basarili, Yanlis, Kilitli, Kapali }
