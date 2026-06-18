using Dapper;

namespace GmDashboard.Data.Asistan;

/// <summary>Kayıtlı görüşme — display mesajları + LLM bağlamı (JSON). Razor serialize/deserialize eder.</summary>
public sealed record Gorusme(long Id, string Baslik, string? MesajlarJson, string? GecmisJson);
/// <summary>Görüşme listesi satırı (geçmiş seçici).</summary>
public sealed record GorusmeBilgi(long Id, string Baslik, string Guncelleme);

/// <summary>
/// BKM-Asistan görüşme kalıcılığı (plan-21 #2b) — BkmPanel.PanelAsistanGorusme. Tek CFO; konuşma+bağlam restart'ta kalır.
/// Razor: yeni mesajda Guncelle (debounced değil — her tur), açılışta Son() ile geri yükle. Öğrenen-katmanın temeli.
/// </summary>
public sealed class GorusmeService
{
    private readonly Db _db;
    private readonly ILogger<GorusmeService> _log;

    public GorusmeService(Db db, ILogger<GorusmeService> log)
    {
        _db = db; _log = log;
        if (!db.PanelEnabled) { log.LogWarning("Panel DB kapalı — görüşme kalıcılığı devre dışı"); return; }
        try
        {
            using var c = db.OpenPanel();
            c.Execute("""
                IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name='PanelAsistanGorusme')
                CREATE TABLE dbo.PanelAsistanGorusme (
                    Id bigint IDENTITY(1,1) PRIMARY KEY,
                    Baslik nvarchar(200) NOT NULL DEFAULT N'Yeni konuşma',
                    Baslangic nvarchar(20), Guncelleme nvarchar(20),
                    MesajlarJson nvarchar(max) NULL, GecmisJson nvarchar(max) NULL);
                """);
        }
        catch (Exception ex) { log.LogError(ex, "PanelAsistanGorusme tablo oluşturma hatası"); }
    }

    public bool Aktif => _db.PanelEnabled;

    /// <summary>Yeni görüşme oluştur → Id.</summary>
    public long Olustur(string baslik = "Yeni konuşma")
    {
        if (!_db.PanelEnabled) return 0;
        try
        {
            using var c = _db.OpenPanel();
            var t = DateTime.Now.ToString("dd.MM.yyyy HH:mm");
            return c.ExecuteScalar<long>("""
                INSERT INTO dbo.PanelAsistanGorusme (Baslik, Baslangic, Guncelleme) VALUES (@b, @t, @t);
                SELECT CAST(SCOPE_IDENTITY() AS bigint);
                """, new { b = baslik, t });
        }
        catch (Exception ex) { _log.LogError(ex, "Görüşme oluşturulamadı"); return 0; }
    }

    /// <summary>Görüşmeyi kaydet (display + bağlam JSON). Başlık ilk kullanıcı mesajından türetilebilir.</summary>
    public void Guncelle(long id, string baslik, string mesajlarJson, string gecmisJson)
    {
        if (!_db.PanelEnabled || id <= 0) return;
        try
        {
            using var c = _db.OpenPanel();
            c.Execute("""
                UPDATE dbo.PanelAsistanGorusme
                SET Baslik=@b, MesajlarJson=@m, GecmisJson=@g, Guncelleme=@t WHERE Id=@id
                """, new { id, b = baslik, m = mesajlarJson, g = gecmisJson, t = DateTime.Now.ToString("dd.MM.yyyy HH:mm") });
        }
        catch (Exception ex) { _log.LogError(ex, "Görüşme kaydedilemedi (Id {Id})", id); }
    }

    /// <summary>En son güncellenen görüşme (açılışta geri yükleme). Yoksa null.</summary>
    public Gorusme? Son()
    {
        if (!_db.PanelEnabled) return null;
        try
        {
            using var c = _db.OpenPanel();
            return c.QueryFirstOrDefault<Gorusme>(
                "SELECT TOP 1 Id, Baslik, MesajlarJson, GecmisJson FROM dbo.PanelAsistanGorusme ORDER BY Id DESC");
        }
        catch (Exception ex) { _log.LogError(ex, "Son görüşme okunamadı"); return null; }
    }

    public Gorusme? Getir(long id)
    {
        if (!_db.PanelEnabled) return null;
        try
        {
            using var c = _db.OpenPanel();
            return c.QueryFirstOrDefault<Gorusme>(
                "SELECT Id, Baslik, MesajlarJson, GecmisJson FROM dbo.PanelAsistanGorusme WHERE Id=@id", new { id });
        }
        catch (Exception ex) { _log.LogError(ex, "Görüşme okunamadı (Id {Id})", id); return null; }
    }

    /// <summary>Son N görüşme (geçmiş seçici).</summary>
    public IReadOnlyList<GorusmeBilgi> Listele(int n = 15)
    {
        if (!_db.PanelEnabled) return [];
        try
        {
            using var c = _db.OpenPanel();
            return c.Query<GorusmeBilgi>(
                "SELECT TOP (@n) Id, Baslik, Guncelleme FROM dbo.PanelAsistanGorusme ORDER BY Id DESC", new { n }).ToList();
        }
        catch (Exception ex) { _log.LogError(ex, "Görüşme listesi okunamadı"); return []; }
    }
}
