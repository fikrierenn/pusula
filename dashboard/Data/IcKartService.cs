using Dapper;
using GmDashboard.Models;

namespace GmDashboard.Data;

/// <summary>
/// İç-kart hariç tutma — TEK kanonik SQL predicate (plan-18). Tüm müşteri sorguları bunu kullanır.
/// İsim (Mağaza/Kumbara) + telefon (599/699 = geçersiz mobil prefix, iç/dummy kart) + elle işaretli liste (@icIds).
/// Customer JOIN GEREKTİRMEZ: NOT IN alt-sorgu → her alias'ta çalışır. Çağıran @icIds param geçer (hasIcIds=true ise).
/// </summary>
public static class IcKartFiltre
{
    /// <param name="custCol">CustomersId kolon ifadesi — alias'lı ("s.CustomersId") veya çıplak ("CustomersId").</param>
    /// <param name="hasIcIds">Elle işaretli liste varsa @icIds NOT IN ekle (çağıran @icIds param geçer).</param>
    public static string Sql(string custCol, bool hasIcIds) =>
        $" AND {custCol} NOT IN (SELECT Id FROM DerinCrm.dbo.Customer WITH(NOLOCK)"
        + " WHERE Name LIKE N'%Mağaza%' COLLATE Turkish_CI_AS OR Name LIKE N'%Kumbara%' COLLATE Turkish_CI_AS"
        + " OR ISNULL(PhoneNumber,'') LIKE '599%' OR ISNULL(PhoneNumber,'') LIKE '699%')"
        + (hasIcIds ? $" AND {custCol} NOT IN @icIds" : "");

    /// <summary>
    /// Aggregate CASE içi varyant (SUM(CASE WHEN...)) — SQL aggregate içinde subquery YASAKLAR.
    /// Customer JOIN gerektirir (c alias). Aynı tanım: isim (Mağaza/Kumbara) + tel (599/699) + elle liste.
    /// </summary>
    /// <param name="c">DerinCrm.Customer alias.</param><param name="s">Sales alias.</param>
    public static string SqlCols(string c, string s, bool hasIcIds) =>
        $" AND ({c}.Id IS NULL OR ({c}.Name NOT LIKE N'%Mağaza%' COLLATE Turkish_CI_AS AND {c}.Name NOT LIKE N'%Kumbara%' COLLATE Turkish_CI_AS"
        + $" AND ISNULL({c}.PhoneNumber,'') NOT LIKE '599%' AND ISNULL({c}.PhoneNumber,'') NOT LIKE '699%'))"
        + (hasIcIds ? $" AND {s}.CustomersId NOT IN @icIds" : "");
}

/// <summary>
/// Elle işaretlenmiş iç/mağaza kartları (plan-16 ek). data/ic-kartlar.json.
/// CustomersId (EncoreMerkez/DerinCrm) listesi → RFM + sadakat + müşteri cirosundan hariç.
/// Otomatik desen filtresi (isim %Mağaza%/%Kumbara%, tel 599/699) YETMEZ → kullanıcı tıkla-işaretle.
/// Geri alınabilir (Sil). Hata sessiz yutulmaz (error-handling.md).
/// </summary>
public sealed class IcKartService
{
    private readonly Db _db;
    private readonly ILogger<IcKartService> _log;

    public IcKartService(Db db, ILogger<IcKartService> log)
    {
        _db = db; _log = log;
        if (!db.PanelEnabled) { log.LogWarning("Panel DB kapalı — iç-kart listesi boş çalışır"); return; }
        try
        {
            using var c = db.OpenPanel();
            c.Execute("""
                IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name='PanelIcKart')
                CREATE TABLE dbo.PanelIcKart (Id bigint PRIMARY KEY, Ad nvarchar(200) NOT NULL, KayitTarih nvarchar(20) NOT NULL);
                """);
        }
        catch (Exception ex) { log.LogError(ex, "PanelIcKart tablo oluşturma hatası"); }
    }

    public IReadOnlyList<IcKart> Yukle()
    {
        if (!_db.PanelEnabled) return [];
        try
        {
            using var c = _db.OpenPanel();
            return c.Query<IcKart>("SELECT Id, Ad, KayitTarih FROM dbo.PanelIcKart ORDER BY Ad").ToList();
        }
        catch (Exception ex) { _log.LogError(ex, "İç kart listesi okunamadı — boş ile devam"); return []; }
    }

    /// <summary>SQL filtresi için işaretli CustomersId dizisi (boşsa boş dizi → çağıran NOT IN eklemez).</summary>
    public long[] Idler()
    {
        if (!_db.PanelEnabled) return [];
        try
        {
            using var c = _db.OpenPanel();
            return c.Query<long>("SELECT Id FROM dbo.PanelIcKart").ToArray();
        }
        catch (Exception ex) { _log.LogError(ex, "İç kart Id listesi okunamadı — boş ile devam"); return []; }
    }

    public bool Ekle(long id, string ad)
    {
        if (!_db.PanelEnabled) return false;
        try
        {
            using var c = _db.OpenPanel();
            c.Execute("""
                IF NOT EXISTS (SELECT 1 FROM dbo.PanelIcKart WHERE Id=@id)
                INSERT INTO dbo.PanelIcKart (Id, Ad, KayitTarih) VALUES (@id, @ad, @t);
                """, new { id, ad, t = DateTime.Now.ToString("dd.MM.yyyy HH:mm") });
            return true;
        }
        catch (Exception ex) { _log.LogError(ex, "İç kart eklenemedi (Id {Id})", id); return false; }
    }

    public bool Sil(long id)
    {
        if (!_db.PanelEnabled) return false;
        try
        {
            using var c = _db.OpenPanel();
            return c.Execute("DELETE FROM dbo.PanelIcKart WHERE Id=@id", new { id }) > 0;
        }
        catch (Exception ex) { _log.LogError(ex, "İç kart silinemedi (Id {Id})", id); return false; }
    }
}
