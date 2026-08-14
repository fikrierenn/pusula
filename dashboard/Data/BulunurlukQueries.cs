using Dapper;
using GmDashboard.Models;

namespace GmDashboard.Data;

/// <summary>
/// Şube bazlı raf bulunurluğu (On-Shelf Availability) — plan-33. PRE-AGGREGATED okur:
/// bkm.BulunurlukOzet + bkm.BulunurlukKayip (aylık dense job üretir — 2026-08-14-bulunurluk-ozet-generate.sql).
/// Dashboard 29M dense tabloyu CANLI taramaz → 9-satır/top-N okur = sub-second. Salt-okuma; 3-parçalı isim.
/// Boş tablo (özet henüz üretilmemiş) → boş liste (sayfa "veri yok" gösterir).
/// </summary>
public sealed class BulunurlukQueries(Db db, ILogger<BulunurlukQueries> logger)
{
    static string MekanAd(int m) => m switch { 1 => "FSM", 4477 => "Özlüce", 4478 => "İst.Yolu", 12 => "Depo(online)", _ => m.ToString() };
    static string KatAd(int k) => k switch { 10 => "Hediyelik", 12 => "Kırtasiye", 16 => "Oyuncak", _ => k.ToString() };

    /// <summary>Şube × kategori OOS — en güncel snapshot (bkm.BulunurlukOzet). Anlık okuma.</summary>
    public async Task<IReadOnlyList<SubeOos>> GetSubeOosAsync()
    {
        const string sql = """
            SELECT o.Mekan, o.Kat3ID, o.TasinanAktif, o.Bulunur, o.Kuru,
                   CONVERT(decimal(5,1), CASE WHEN o.TasinanAktif>0 THEN 100.0*o.Kuru/o.TasinanAktif ELSE 0 END) AS OosYuzde
            FROM DerinSISBkm.bkm.BulunurlukOzet o WITH(NOLOCK)
            WHERE o.Donem = (SELECT MAX(Donem) FROM DerinSISBkm.bkm.BulunurlukOzet);
            """;
        await using var c = await db.OpenAsync();
        var rows = (await c.QueryAsync<SubeOos>(sql)).AsList();
        foreach (var r in rows) { r.MekanAd = MekanAd(r.Mekan); r.Kategori = KatAd(r.Kat3ID); }
        return rows;
    }

    /// <summary>Kayıp-satış öncelik listesi — en güncel snapshot (bkm.BulunurlukKayip), kayıp ₺ azalan. Anlık.</summary>
    public async Task<IReadOnlyList<BulunurlukKayip>> GetKayipOncelikAsync(int top = 200)
    {
        var sql = $"""
            SELECT TOP (@top)
                k.StkID, k.StkAd, ISNULL(k.Kategori,'') AS Kategori, ISNULL(k.Marka,'') AS Marka,
                k.StokluSube, k.KuruSube, ISNULL(k.KuruSubeAd,'') AS KuruSubeAd,
                k.GorunurSatis, k.TahminiKayipAdet, ISNULL(k.BirimMaliyet,0) AS BirimMaliyet
            FROM DerinSISBkm.bkm.BulunurlukKayip k WITH(NOLOCK)
            WHERE k.Donem = (SELECT MAX(Donem) FROM DerinSISBkm.bkm.BulunurlukKayip)
            ORDER BY (k.TahminiKayipAdet * ISNULL(k.BirimMaliyet,0)) DESC;
            """;
        await using var c = await db.OpenAsync();
        var rows = (await c.QueryAsync<BulunurlukKayip>(new CommandDefinition(sql, new { top }))).AsList();
        logger.LogInformation("Bulunurluk: {O} özet + {K} kayıp (pre-agg okundu)", "?", rows.Count);
        return rows;
    }

    /// <summary>Özetin üretildiği son snapshot ayı (UI'da "veri tarihi" göstermek için). Yoksa null.</summary>
    public async Task<DateTime?> GetSnapshotAsync()
    {
        await using var c = await db.OpenAsync();
        return await c.ExecuteScalarAsync<DateTime?>(
            "SELECT MAX(Donem) FROM DerinSISBkm.bkm.BulunurlukOzet");
    }
}
