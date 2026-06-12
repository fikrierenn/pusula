using System.Text;
using Dapper;
using Microsoft.Data.Sqlite;

namespace GmDashboard.Data;

/// <summary>Görev kaydı (asistan/Program.cs SaveTask + /gorevler mantığı).</summary>
public sealed record Gorev(long Id, string Baslik, string Aciklama, string Oncelik, string? Atanan, string Durum, string Olusturma);

/// <summary>
/// SQLite görev deposu (asistan.db, dashboard kökü). Dapper.
/// Şema asistan POC ile birebir: gorevler + kisiler.
/// </summary>
public sealed class GorevService
{
    private readonly string _connStr;

    public GorevService()
    {
        var dbPath = Path.Combine(AppContext.BaseDirectory, "asistan.db");
        _connStr = $"Data Source={dbPath}";
        using var c = new SqliteConnection(_connStr);
        c.Open();
        c.Execute("""
            CREATE TABLE IF NOT EXISTS gorevler(
              id INTEGER PRIMARY KEY AUTOINCREMENT, baslik TEXT, aciklama TEXT,
              oncelik TEXT, atanan TEXT, durum TEXT DEFAULT 'Açık', olusturma TEXT);
            CREATE TABLE IF NOT EXISTS kisiler(ad TEXT PRIMARY KEY, iletisim TEXT);
            """);
    }

    /// <summary>Taslak metninden başlık/açıklama/öncelik ayıkla + kaydet. Yeni id döner.</summary>
    public long Kaydet(string taslak, string? atanan = null)
    {
        var lines = taslak.Split('\n', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        string baslik = "", oncelik = "Orta";
        var aciklama = new StringBuilder();
        foreach (var l in lines)
        {
            if (l.StartsWith("📋")) baslik = l[2..].Trim();
            else if (l.StartsWith("📝")) aciklama.Append(l[2..].Trim());
            else if (l.StartsWith("⚡")) oncelik = l.Contains("Yüksek") ? "Yüksek" : l.Contains("Düşük") ? "Düşük" : "Orta";
        }
        if (baslik.Length == 0) baslik = lines.FirstOrDefault() ?? "Görev";

        using var db = new SqliteConnection(_connStr);
        db.Open();
        db.Execute(
            "INSERT INTO gorevler(baslik,aciklama,oncelik,atanan,durum,olusturma) VALUES(@baslik,@aciklama,@oncelik,@atanan,'Açık',@t)",
            new { baslik, aciklama = aciklama.ToString(), oncelik, atanan, t = DateTime.Now.ToString("dd.MM.yyyy HH:mm") });
        return db.ExecuteScalar<long>("SELECT last_insert_rowid()");
    }

    public IReadOnlyList<Gorev> Listele(bool acikOnly = true)
    {
        using var db = new SqliteConnection(_connStr);
        var sql = "SELECT id,baslik,aciklama,oncelik,atanan,durum,olusturma FROM gorevler"
                  + (acikOnly ? " WHERE durum<>'Kapalı'" : "") + " ORDER BY id DESC LIMIT 100";
        return db.Query<Gorev>(sql).ToList();
    }

    public Gorev? Get(long id)
    {
        using var db = new SqliteConnection(_connStr);
        return db.QueryFirstOrDefault<Gorev>(
            "SELECT id,baslik,aciklama,oncelik,atanan,durum,olusturma FROM gorevler WHERE id=@id", new { id });
    }

    public bool Kapat(long id)
    {
        using var db = new SqliteConnection(_connStr);
        return db.Execute("UPDATE gorevler SET durum='Kapalı' WHERE id=@id", new { id }) > 0;
    }

    /// <summary>Görev alanlarını güncelle (düzenle modalı).</summary>
    public bool Guncelle(long id, string baslik, string aciklama, string oncelik, string? atanan, string durum)
    {
        using var db = new SqliteConnection(_connStr);
        return db.Execute(
            "UPDATE gorevler SET baslik=@baslik, aciklama=@aciklama, oncelik=@oncelik, atanan=@atanan, durum=@durum WHERE id=@id",
            new { id, baslik, aciklama, oncelik, atanan, durum }) > 0;
    }

    public bool Sil(long id)
    {
        using var db = new SqliteConnection(_connStr);
        return db.Execute("DELETE FROM gorevler WHERE id=@id", new { id }) > 0;
    }
}
