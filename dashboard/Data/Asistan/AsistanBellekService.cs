using System.Text;
using System.Text.RegularExpressions;
using Dapper;

namespace GmDashboard.Data.Asistan;

/// <summary>Bir bellek girdisi. Tip: 'tercih' (USER) | 'gercek' (MEMORY). Durum: 'aktif' | 'arsiv' (ASLA DELETE).</summary>
public sealed record Bellek(long Id, string Tip, string Icerik, string Kaynak, string Durum, string? Olusturma, string? SonDogrulama, int TtlGun);
/// <summary>Prompt'a enjekte edilen donmuş snapshot + doluluk.</summary>
public sealed record BellekSnapshot(string Metin, int KullanilanChar, int ToplamChar, int YuzdeDolu);
public enum BellekSonucDurum { Eklendi, Guncellendi, Silindi, LimitAsildi, GuvenlikReddi, Bulunamadi, Kapali }
public sealed record BellekYazSonuc(BellekSonucDurum Durum, string Mesaj);

/// <summary>
/// BKM-Asistan "Genius" öğrenen katmanı (plan-22, Hermes-uyarlı). BkmPanel.PanelAsistanBellek satır-tablo.
/// Hot bellek (tercih+gerçek) oturum başı FROZEN snapshot olarak system-prompt'a girer. self-edit: bellek_yaz (ekle/degistir/sil).
/// NO AUTO-COMPACT: limit aşılırsa LimitAsildi döner — LLM aynı turda yer açar. Yazımda injection/credential/unicode taranır. ASLA DELETE → 'arsiv'.
/// </summary>
public sealed class AsistanBellekService
{
    private const int TercihLimit = 1400;   // USER.md eşleniği (Hermes ~1375)
    private const int GercekLimit = 2200;   // MEMORY.md eşleniği (Hermes ~2200)

    private readonly Db _db;
    private readonly ILogger<AsistanBellekService> _log;

    public AsistanBellekService(Db db, ILogger<AsistanBellekService> log)
    {
        _db = db; _log = log;
        if (!db.PanelEnabled) { log.LogWarning("Panel DB kapalı — asistan belleği devre dışı"); return; }
        try
        {
            using var c = db.OpenPanel();
            c.Execute("""
                IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name='PanelAsistanBellek')
                CREATE TABLE dbo.PanelAsistanBellek (
                    Id bigint IDENTITY(1,1) PRIMARY KEY,
                    Tip nvarchar(10) NOT NULL DEFAULT N'tercih',
                    Icerik nvarchar(400) NOT NULL,
                    Kaynak nvarchar(20) NOT NULL DEFAULT N'llm',
                    Durum nvarchar(12) NOT NULL DEFAULT N'aktif',
                    Olusturma nvarchar(20), SonDogrulama nvarchar(20),
                    TtlGun int NOT NULL DEFAULT 120);
                """);
        }
        catch (Exception ex) { log.LogError(ex, "PanelAsistanBellek tablo oluşturma hatası"); }
    }

    public bool Aktif => _db.PanelEnabled;

    private static int Limit(string tip) => tip == "gercek" ? GercekLimit : TercihLimit;
    private static string TipNorm(string? tip) => string.Equals(tip, "gercek", StringComparison.OrdinalIgnoreCase) ? "gercek" : "tercih";

    // ── HOT: oturum başı prompt'a giren donmuş snapshot ──
    public BellekSnapshot Snapshot()
    {
        if (!_db.PanelEnabled) return new("", 0, TercihLimit + GercekLimit, 0);
        var hepsi = Listele();
        var tercih = hepsi.Where(b => b.Tip == "tercih").ToList();
        var gercek = hepsi.Where(b => b.Tip == "gercek").ToList();
        int kullanilan = hepsi.Sum(b => b.Icerik.Length);
        int toplam = TercihLimit + GercekLimit;
        int yuzde = toplam > 0 ? kullanilan * 100 / toplam : 0;
        if (hepsi.Count == 0) return new("", 0, toplam, 0);
        var sb = new StringBuilder();
        sb.Append("[GENIUS BELLEK %").Append(yuzde).Append(" — ").Append(kullanilan).Append('/').Append(toplam).Append(" char] (senin kalıcı belleğin)\n");
        if (tercih.Count > 0) { sb.Append("## Tercihler (kullanıcı davranış/kural)\n"); foreach (var b in tercih) sb.Append("- ").Append(b.Icerik).Append('\n'); }
        if (gercek.Count > 0) { sb.Append("## Bilinen Gerçekler\n"); foreach (var b in gercek) sb.Append("- ").Append(b.Icerik).Append('\n'); }
        return new(sb.ToString(), kullanilan, toplam, yuzde);
    }

    // ── self-edit: ekle | degistir | sil ──
    public BellekYazSonuc Yaz(string action, string? icerik, string? tip = "tercih", string? eslesme = null)
    {
        if (!_db.PanelEnabled) return new(BellekSonucDurum.Kapali, "Bellek devre dışı (panel DB yok).");
        var act = (action ?? "").Trim().ToLowerInvariant();
        try
        {
            using var c = _db.OpenPanel();
            var t = DateTime.Now.ToString("dd.MM.yyyy HH:mm");
            if (act is "ekle" or "add")
            {
                if (string.IsNullOrWhiteSpace(icerik)) return new(BellekSonucDurum.Bulunamadi, "İçerik boş.");
                var (ok, sebep) = GuvenlikTara(icerik);
                if (!ok) { _log.LogWarning("Bellek yazımı reddedildi: {Sebep}", sebep); return new(BellekSonucDurum.GuvenlikReddi, $"Reddedildi: {sebep}"); }
                var tn = TipNorm(tip);
                var icr = icerik.Trim();
                if (icr.Length > 400) icr = icr[..400];
                int mevcutChar = c.ExecuteScalar<int>("SELECT ISNULL(SUM(LEN(Icerik)),0) FROM dbo.PanelAsistanBellek WHERE Tip=@tn AND Durum=N'aktif'", new { tn });
                if (mevcutChar + icr.Length > Limit(tn))
                    return new(BellekSonucDurum.LimitAsildi, $"'{tn}' bloğu dolu ({mevcutChar}/{Limit(tn)}). Önce sil/değiştir ile yer aç, sonra tekrar ekle.");
                c.Execute("INSERT INTO dbo.PanelAsistanBellek (Tip, Icerik, Kaynak, Durum, Olusturma, SonDogrulama, TtlGun) VALUES (@tn,@i,N'llm',N'aktif',@t,@t,120)",
                    new { tn, i = icr, t });
                return new(BellekSonucDurum.Eklendi, "Belleğe eklendi.");
            }
            if (act is "degistir" or "replace")
            {
                if (string.IsNullOrWhiteSpace(eslesme) || string.IsNullOrWhiteSpace(icerik)) return new(BellekSonucDurum.Bulunamadi, "eslesme + icerik gerekli.");
                var (ok, sebep) = GuvenlikTara(icerik);
                if (!ok) return new(BellekSonucDurum.GuvenlikReddi, $"Reddedildi: {sebep}");
                var id = c.ExecuteScalar<long?>("SELECT TOP 1 Id FROM dbo.PanelAsistanBellek WHERE Durum=N'aktif' AND Icerik LIKE N'%'+@e+N'%' ORDER BY Id", new { e = eslesme.Trim() });
                if (id is null) return new(BellekSonucDurum.Bulunamadi, "Eşleşen bellek girdisi yok.");
                var icr = icerik.Trim(); if (icr.Length > 400) icr = icr[..400];
                c.Execute("UPDATE dbo.PanelAsistanBellek SET Icerik=@i, SonDogrulama=@t WHERE Id=@id", new { id, i = icr, t });
                return new(BellekSonucDurum.Guncellendi, "Bellek güncellendi.");
            }
            if (act is "sil" or "remove")
            {
                if (string.IsNullOrWhiteSpace(eslesme)) return new(BellekSonucDurum.Bulunamadi, "eslesme gerekli.");
                var n = c.Execute("UPDATE dbo.PanelAsistanBellek SET Durum=N'arsiv' WHERE Durum=N'aktif' AND Icerik LIKE N'%'+@e+N'%'", new { e = eslesme.Trim() });
                return n > 0 ? new(BellekSonucDurum.Silindi, "Bellekten kaldırıldı (arşiv).") : new(BellekSonucDurum.Bulunamadi, "Eşleşen girdi yok.");
            }
            return new(BellekSonucDurum.Bulunamadi, "Geçersiz action (ekle|degistir|sil).");
        }
        catch (Exception ex) { _log.LogError(ex, "Bellek yazımı hatası"); return new(BellekSonucDurum.Kapali, "Bellek yazılamadı."); }
    }

    public IReadOnlyList<Bellek> Listele(bool aktifOnly = true)
    {
        if (!_db.PanelEnabled) return [];
        try
        {
            using var c = _db.OpenPanel();
            var sql = "SELECT Id, Tip, Icerik, Kaynak, Durum, Olusturma, SonDogrulama, TtlGun FROM dbo.PanelAsistanBellek"
                      + (aktifOnly ? " WHERE Durum=N'aktif'" : "") + " ORDER BY Tip, Id";
            return c.Query<Bellek>(sql).ToList();
        }
        catch (Exception ex) { _log.LogError(ex, "Bellek listesi okunamadı"); return []; }
    }

    /// <summary>Yaşı dolmuş (stale) kayıtlar — TtlGun>0 ve SonDogrulama+TtlGun &lt; bugün. TtlGun=0 pinned, muaf.</summary>
    public IReadOnlyList<Bellek> StaleListele() =>
        Listele().Where(b => b.TtlGun > 0 && DateTime.TryParseExact(b.SonDogrulama, "dd.MM.yyyy HH:mm", null, System.Globalization.DateTimeStyles.None, out var d)
                             && d.AddDays(b.TtlGun) < DateTime.Now).ToList();

    public bool Dogrula(long id) => Exec("UPDATE dbo.PanelAsistanBellek SET SonDogrulama=@t WHERE Id=@id", new { id, t = DateTime.Now.ToString("dd.MM.yyyy HH:mm") });
    public bool Arsivle(long id) => Exec("UPDATE dbo.PanelAsistanBellek SET Durum=N'arsiv' WHERE Id=@id", new { id });

    private bool Exec(string sql, object p)
    {
        if (!_db.PanelEnabled) return false;
        try { using var c = _db.OpenPanel(); return c.Execute(sql, p) > 0; }
        catch (Exception ex) { _log.LogError(ex, "Bellek işlemi başarısız"); return false; }
    }

    // ── Güvenlik: kabul öncesi blokla (prompt-zehirlenmesi / sır sızıntısı / görünmez-unicode) ──
    private static readonly Regex Injection = new(@"ignore\s+(all\s+)?previous|disregard\s+(all\s+)?(previous|above)|you\s+are\s+now|new\s+instructions|system\s*:|</?(tool|system|instructions)|<\|",
        RegexOptions.IgnoreCase | RegexOptions.Compiled);
    private static readonly Regex Credential = new(@"\bapi[_-]?key\b|\bpassword\b|\bpasswd\b|\bsecret\b|\bbearer\s|\bsk-[A-Za-z0-9]|\bgsk_[A-Za-z0-9]|\bAKIA[0-9A-Z]|BEGIN\s+(RSA\s+)?PRIVATE\s+KEY|Server=.*Password=",
        RegexOptions.IgnoreCase | RegexOptions.Compiled);

    public static (bool Ok, string Sebep) GuvenlikTara(string icerik)
    {
        if (GorunmezVar(icerik)) return (false, "görünmez/yön-değiştiren unicode");
        if (Injection.IsMatch(icerik)) return (false, "talimat-enjeksiyon kalıbı");
        if (Credential.IsMatch(icerik)) return (false, "sır/kimlik bilgisi (belleğe yazılmaz)");
        return (true, "");
    }

    // Görünmez/yön-değiştiren unicode tara (kod-tabanlı, 0x kod-noktası): ZWSP-RLM, bidi embed/override, isolate, BOM.
    private static bool GorunmezVar(string s)
    {
        foreach (var ch in s)
        {
            int c = ch;
            if ((c >= 0x200B && c <= 0x200F) || (c >= 0x202A && c <= 0x202E) || (c >= 0x2066 && c <= 0x2069) || c == 0xFEFF)
                return true;
        }
        return false;
    }
}
