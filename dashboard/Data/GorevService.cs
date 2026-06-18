using System.Text;
using Dapper;

namespace GmDashboard.Data;

/// <summary>Görev kaydı (asistan/Program.cs SaveTask + /gorevler mantığı). SonTarih = due date (dd.MM.yyyy, opsiyonel).</summary>
public sealed record Gorev(long Id, string Baslik, string Aciklama, string Oncelik, string? Atanan, string Durum, string Olusturma, string? SonTarih = null);

/// <summary>
/// Görev deposu — localhost Express BkmPanel.dbo.PanelGorev (eski SQLite asistan.db'den taşındı).
/// </summary>
public sealed class GorevService
{
    private readonly Db _db;
    private readonly ILogger<GorevService> _log;

    public GorevService(Db db, ILogger<GorevService> log)
    {
        _db = db; _log = log;
        if (!db.PanelEnabled) { log.LogWarning("Panel DB kapalı — görev deposu devre dışı"); return; }
        try
        {
            using var c = db.OpenPanel();
            c.Execute("""
                IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name='PanelGorev')
                CREATE TABLE dbo.PanelGorev (
                    Id bigint IDENTITY(1,1) PRIMARY KEY, Baslik nvarchar(300), Aciklama nvarchar(max),
                    Oncelik nvarchar(20), Atanan nvarchar(100) NULL, Durum nvarchar(20) NOT NULL DEFAULT N'Açık',
                    Olusturma nvarchar(20));
                IF COL_LENGTH('dbo.PanelGorev','SonTarih') IS NULL ALTER TABLE dbo.PanelGorev ADD SonTarih nvarchar(20) NULL;
                """);
        }
        catch (Exception ex) { log.LogError(ex, "PanelGorev tablo oluşturma hatası"); }
    }

    /// <summary>Taslak metninden başlık/açıklama/öncelik ayıkla + kaydet. Yeni id döner (0 = hata).</summary>
    public long Kaydet(string taslak, string? atanan = null)
    {
        if (!_db.PanelEnabled) return 0;
        var lines = taslak.Split('\n', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        string baslik = "", oncelik = "Orta"; string? sonTarih = null;
        var aciklama = new StringBuilder();
        foreach (var l in lines)
        {
            if (l.StartsWith("📋")) baslik = l[2..].Trim();
            else if (l.StartsWith("📝")) aciklama.Append(l[2..].Trim());
            else if (l.StartsWith("⚡")) oncelik = l.Contains("Yüksek") ? "Yüksek" : l.Contains("Düşük") ? "Düşük" : "Orta";
            else if (l.StartsWith("📅")) { var v = l[2..].Replace("Son tarih:", "").Trim(); if (v.Length > 0) sonTarih = v; }
        }
        if (baslik.Length == 0) baslik = lines.FirstOrDefault() ?? "Görev";
        try
        {
            using var c = _db.OpenPanel();
            return c.ExecuteScalar<long>("""
                INSERT INTO dbo.PanelGorev (Baslik, Aciklama, Oncelik, Atanan, Durum, Olusturma, SonTarih)
                VALUES (@baslik, @aciklama, @oncelik, @atanan, N'Açık', @t, @sonTarih);
                SELECT CAST(SCOPE_IDENTITY() AS bigint);
                """, new { baslik, aciklama = aciklama.ToString(), oncelik, atanan, t = DateTime.Now.ToString("dd.MM.yyyy HH:mm"), sonTarih });
        }
        catch (Exception ex) { _log.LogError(ex, "Görev kaydedilemedi"); return 0; }
    }

    public IReadOnlyList<Gorev> Listele(bool acikOnly = true)
    {
        if (!_db.PanelEnabled) return [];
        try
        {
            using var c = _db.OpenPanel();
            var sql = "SELECT TOP 100 Id, Baslik, Aciklama, Oncelik, Atanan, Durum, Olusturma, SonTarih FROM dbo.PanelGorev"
                      + (acikOnly ? " WHERE Durum<>N'Kapalı'" : "") + " ORDER BY Id DESC";
            return c.Query<Gorev>(sql).ToList();
        }
        catch (Exception ex) { _log.LogError(ex, "Görev listesi okunamadı"); return []; }
    }

    public Gorev? Get(long id)
    {
        if (!_db.PanelEnabled) return null;
        try
        {
            using var c = _db.OpenPanel();
            return c.QueryFirstOrDefault<Gorev>(
                "SELECT Id, Baslik, Aciklama, Oncelik, Atanan, Durum, Olusturma, SonTarih FROM dbo.PanelGorev WHERE Id=@id", new { id });
        }
        catch (Exception ex) { _log.LogError(ex, "Görev okunamadı (Id {Id})", id); return null; }
    }

    public bool Kapat(long id) => Exec("UPDATE dbo.PanelGorev SET Durum=N'Kapalı' WHERE Id=@id", new { id });

    /// <summary>Görev alanlarını güncelle (düzenle modalı).</summary>
    public bool Guncelle(long id, string baslik, string aciklama, string oncelik, string? atanan, string durum, string? sonTarih = null) =>
        Exec("UPDATE dbo.PanelGorev SET Baslik=@baslik, Aciklama=@aciklama, Oncelik=@oncelik, Atanan=@atanan, Durum=@durum, SonTarih=@sonTarih WHERE Id=@id",
            new { id, baslik, aciklama, oncelik, atanan, durum, sonTarih });

    public bool Sil(long id) => Exec("DELETE FROM dbo.PanelGorev WHERE Id=@id", new { id });

    private bool Exec(string sql, object p)
    {
        if (!_db.PanelEnabled) return false;
        try { using var c = _db.OpenPanel(); return c.Execute(sql, p) > 0; }
        catch (Exception ex) { _log.LogError(ex, "Görev işlemi başarısız"); return false; }
    }
}
