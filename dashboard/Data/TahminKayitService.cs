using Dapper;
using GmDashboard.Models;

namespace GmDashboard.Data;

/// <summary>
/// Kaydedilmiş tahmin deposu (plan-14). localhost Express BkmPanel.dbo.PanelTahminKayit.
/// Upsert anahtarı: Year+Month+MekanId. Hata sessiz yutulmaz (error-handling.md): log + güvenli boş/false.
/// </summary>
public sealed class TahminKayitService
{
    private readonly Db _db;
    private readonly ILogger<TahminKayitService> _log;

    public TahminKayitService(Db db, ILogger<TahminKayitService> log)
    {
        _db = db; _log = log;
        if (!db.PanelEnabled) { log.LogWarning("Panel DB kapalı — tahmin kayıtları boş çalışır"); return; }
        try
        {
            using var c = db.OpenPanel();
            c.Execute("""
                IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name='PanelTahminKayit')
                CREATE TABLE dbo.PanelTahminKayit (
                    Id nvarchar(50) PRIMARY KEY, Year int NOT NULL, Month int NOT NULL, MekanId int NOT NULL,
                    Tahmin decimal(18,4), Alt decimal(18,4), Ust decimal(18,4), IvmePct decimal(18,4),
                    YoYTaban decimal(18,4), Carpan decimal(18,4), KayitTarih nvarchar(20) NOT NULL,
                    CONSTRAINT UQ_PanelTahmin UNIQUE (Year, Month, MekanId));
                """);
        }
        catch (Exception ex) { log.LogError(ex, "PanelTahminKayit tablo oluşturma hatası"); }
    }

    public IReadOnlyList<TahminKayitEntry> Yukle()
    {
        if (!_db.PanelEnabled) return [];
        try
        {
            using var c = _db.OpenPanel();
            return c.Query<TahminKayitEntry>("""
                SELECT Id, Year, Month, MekanId, Tahmin, Alt, Ust, IvmePct, YoYTaban, Carpan, KayitTarih
                FROM dbo.PanelTahminKayit ORDER BY Year DESC, Month DESC
                """).ToList();
        }
        catch (Exception ex) { _log.LogError(ex, "Tahmin kayıtları okunamadı — boş liste ile devam"); return []; }
    }

    /// <summary>Year+Month+MekanId aynı kayıt varsa üzerine yazar, yoksa ekler. Başarı = true.</summary>
    public bool Kaydet(TahminKayitEntry e)
    {
        if (!_db.PanelEnabled) return false;
        try
        {
            using var c = _db.OpenPanel();
            c.Execute("DELETE FROM dbo.PanelTahminKayit WHERE Year=@Year AND Month=@Month AND MekanId=@MekanId", e);
            c.Execute("""
                INSERT INTO dbo.PanelTahminKayit (Id, Year, Month, MekanId, Tahmin, Alt, Ust, IvmePct, YoYTaban, Carpan, KayitTarih)
                VALUES (@Id, @Year, @Month, @MekanId, @Tahmin, @Alt, @Ust, @IvmePct, @YoYTaban, @Carpan, @KayitTarih)
                """, e);
            return true;
        }
        catch (Exception ex) { _log.LogError(ex, "Tahmin kaydı yazılamadı"); return false; }
    }

    public bool Sil(string id)
    {
        if (!_db.PanelEnabled) return false;
        try
        {
            using var c = _db.OpenPanel();
            return c.Execute("DELETE FROM dbo.PanelTahminKayit WHERE Id=@id", new { id }) > 0;
        }
        catch (Exception ex) { _log.LogError(ex, "Tahmin kaydı silinemedi (Id {Id})", id); return false; }
    }
}
