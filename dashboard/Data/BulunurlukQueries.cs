using Dapper;
using GmDashboard.Models;

namespace GmDashboard.Data;

/// <summary>
/// Şube bazlı raf bulunurluğu (On-Shelf Availability) — plan-33. Kaynak: bkm.StokAyBakiyeMekanBazli
/// (ay-sonu bakiye) × irsHrk satış. Availability = pencerede raf ≥ min-stok VEYA pencereye giriş bakiyesi ≥ min-stok
/// (carry-in — sparse tabloda hareketsiz-stok kaçmasın; dense regen sonrası da doğru kalır).
/// Salt-okuma (erp-write-policy); 3-parçalı DerinSISBkm isim (master katalog). Kat3ID 10/12/16.
/// </summary>
public sealed class BulunurlukQueries(Db db, ILogger<BulunurlukQueries> logger)
{
    static readonly string[] Stores = ["1", "4477", "4478"];
    static string MekanAd(int m) => m switch { 1 => "FSM", 4477 => "Özlüce", 4478 => "İst.Yolu", 12 => "Depo(online)", _ => m.ToString() };
    static string KatAd(int k) => k switch { 10 => "Hediyelik", 12 => "Kırtasiye", 16 => "Oyuncak", _ => k.ToString() };

    const int MinStok = 3;                              // raf ≥3 = "bulunur" (satınalma SatinMinStok ile aynı mantık)
    static readonly System.Collections.Concurrent.ConcurrentDictionary<string, (System.DateTime Ts, object Data)> _cache = new();
    static readonly System.TimeSpan _ttl = System.TimeSpan.FromMinutes(20);

    // Son 12 tam ay penceresi (bugünün ay-başı −12 .. ay-başı).
    static (string Bas, string Son) Pencere()
    {
        var son = new System.DateTime(System.DateTime.Today.Year, System.DateTime.Today.Month, 1);
        return (son.AddMonths(-12).ToString("yyyyMMdd"), son.ToString("yyyyMMdd"));
    }

    // Ortak availability CTE gövdesi (carried-active pair + window-max + carry-in avail flag). @bas/@son param.
    const string AvailCte = """
        WITH aktif AS (   -- son12 satan Kat3 SKU
            SELECT h.ehstkID AS stkID
            FROM DerinSISBkm.dbo.irsHrk h WITH(NOLOCK)
            WHERE h.ehTip IN (1,4,100) AND h.ehTrhS>=@bas AND h.ehTrhS<@son
              AND h.ehstkID IN (SELECT StkID FROM DerinSISBkm.bkm.UrunBilgi WHERE Kat3ID IN (10,12,16))
            GROUP BY h.ehstkID HAVING SUM(-h.ehAdetN)>0
        ),
        carried AS (   -- (sku,mekan) o şubenin TAŞIDIĞI + aktif
            SELECT DISTINCT b.stkID, b.ehMekan
            FROM DerinSISBkm.bkm.StokAyBakiyeMekanBazli b WITH(NOLOCK)
            WHERE b.Kaynak='irsHrk' AND b.ehMekan IN (1,4477,4478) AND b.stkID IN (SELECT stkID FROM aktif)
        ),
        wmax AS (   -- pencere içi max raf
            SELECT stkID, ehMekan, MAX(Stok) mx
            FROM DerinSISBkm.bkm.StokAyBakiyeMekanBazli WITH(NOLOCK)
            WHERE Kaynak='irsHrk' AND ehMekan IN (1,4477,4478) AND Donem>=@bas AND Donem<@son
            GROUP BY stkID, ehMekan
        ),
        carryin AS (   -- pencereye giriş bakiyesi (önceki son satır)
            SELECT stkID, ehMekan, stok FROM (
                SELECT stkID, ehMekan, Stok stok,
                       ROW_NUMBER() OVER (PARTITION BY stkID,ehMekan ORDER BY Donem DESC) rn
                FROM DerinSISBkm.bkm.StokAyBakiyeMekanBazli WITH(NOLOCK)
                WHERE Kaynak='irsHrk' AND ehMekan IN (1,4477,4478) AND Donem<@bas
            ) z WHERE rn=1
        ),
        av AS (   -- her carried çift için bulunur mu?
            SELECT c.stkID, c.ehMekan,
                CASE WHEN ISNULL(w.mx,0)>=@min OR ISNULL(ci.stok,0)>=@min THEN 1 ELSE 0 END AS bulunur
            FROM carried c
            LEFT JOIN wmax w ON w.stkID=c.stkID AND w.ehMekan=c.ehMekan
            LEFT JOIN carryin ci ON ci.stkID=c.stkID AND ci.ehMekan=c.ehMekan
        )
        """;

    /// <summary>Şube × kategori OOS oranı (taşınan-aktif SKU'ların % kaçı kuru). 20dk cache.</summary>
    public async Task<IReadOnlyList<SubeOos>> GetSubeOosAsync()
    {
        if (_cache.TryGetValue("oos", out var hit) && System.DateTime.UtcNow - hit.Ts < _ttl)
            return (IReadOnlyList<SubeOos>)hit.Data;

        var (bas, son) = Pencere();
        var sql = AvailCte + """

            SELECT av.ehMekan AS Mekan, u.Kat3ID,
                   COUNT(*) AS TasinanAktif,
                   SUM(av.bulunur) AS Bulunur,
                   SUM(1-av.bulunur) AS Kuru,
                   CONVERT(decimal(5,1), 100.0*SUM(1-av.bulunur)/COUNT(*)) AS OosYuzde
            FROM av
            JOIN DerinSISBkm.bkm.UrunBilgi u WITH(NOLOCK) ON u.StkID=av.stkID
            GROUP BY av.ehMekan, u.Kat3ID;
            """;
        await using var c = await db.OpenAsync();
        var rows = (await c.QueryAsync<SubeOos>(new CommandDefinition(sql, new { bas, son, min = MinStok }, commandTimeout: 120))).AsList();
        foreach (var r in rows) { r.MekanAd = MekanAd(r.Mekan); r.Kategori = KatAd(r.Kat3ID); }
        _cache["oos"] = (System.DateTime.UtcNow, rows);
        logger.LogInformation("Bulunurluk OOS: {N} şube×kategori satırı", rows.Count);
        return rows;
    }

    /// <summary>Kayıp-satış öncelik listesi — kısmi-dağıtım (1-2 şube stoklu) + kuru-şube olan SKU'lar,
    /// tahmini kaçan ₺'ye göre. Kaba üst-sınır: görünür satış × (eksik/stoklu) × son alış birim maliyeti.</summary>
    public async Task<IReadOnlyList<BulunurlukKayip>> GetKayipOncelikAsync(int top = 200)
    {
        if (_cache.TryGetValue($"kayip{top}", out var hit) && System.DateTime.UtcNow - hit.Ts < _ttl)
            return (IReadOnlyList<BulunurlukKayip>)hit.Data;

        var (bas, son) = Pencere();
        var sql = AvailCte + """
            ,
            satis AS (   -- son12 görünür satış (adet)
                SELECT h.ehstkID stkID, CONVERT(int,SUM(-h.ehAdetN)) satis
                FROM DerinSISBkm.dbo.irsHrk h WITH(NOLOCK)
                WHERE h.ehTip IN (1,4,100) AND h.ehTrhS>=@bas AND h.ehTrhS<@son AND h.ehstkID IN (SELECT stkID FROM aktif)
                GROUP BY h.ehstkID
            ),
            sku_av AS (   -- SKU başına stoklu/kuru şube + hangi şube kuru
                SELECT stkID,
                    SUM(bulunur) stoklu, SUM(1-bulunur) kuru,
                    MAX(CASE WHEN ehMekan=1    AND bulunur=0 THEN 1 ELSE 0 END) d1,
                    MAX(CASE WHEN ehMekan=4477 AND bulunur=0 THEN 1 ELSE 0 END) d4477,
                    MAX(CASE WHEN ehMekan=4478 AND bulunur=0 THEN 1 ELSE 0 END) d4478
                FROM av GROUP BY stkID
            ),
            aday AS (   -- kısmi-dağıtım (1-2 stoklu) + ≥1 kuru; kaba kayıp adet
                SELECT a.stkID, s.satis, a.stoklu, a.kuru, a.d1, a.d4477, a.d4478,
                       CONVERT(int, 1.0*s.satis*(3-a.stoklu)/a.stoklu) AS kayip_adet
                FROM sku_av a JOIN satis s ON s.stkID=a.stkID
                WHERE a.stoklu IN (1,2) AND a.kuru>=1
            )
            SELECT TOP (@top)
                t.stkID AS StkID, u.stkAd AS StkAd, ISNULL(ub.Kategori3,'') AS Kategori, ISNULL(ub.mrkAd,'') AS Marka,
                t.stoklu AS StokluSube, t.kuru AS KuruSube,
                LTRIM(
                    CASE WHEN t.d1=1    THEN ' FSM'      ELSE '' END +
                    CASE WHEN t.d4477=1 THEN ' Özlüce'   ELSE '' END +
                    CASE WHEN t.d4478=1 THEN ' İst.Yolu' ELSE '' END) AS KuruSubeAd,
                t.satis AS GorunurSatis, t.kayip_adet AS TahminiKayipAdet,
                CONVERT(decimal(18,2), ISNULL(mal.birim,0)) AS BirimMaliyet
            FROM (SELECT TOP 800 * FROM aday ORDER BY kayip_adet DESC) t
            JOIN DerinSISBkm.dbo.urn u WITH(NOLOCK) ON u.stkID=t.stkID
            LEFT JOIN DerinSISBkm.bkm.UrunBilgi ub WITH(NOLOCK) ON ub.StkID=t.stkID
            OUTER APPLY (
                SELECT TOP 1 SUM(fa.ehTutarN)/NULLIF(SUM(fa.ehAdetN),0) AS birim
                FROM DerinSISBkm.dbo.fatAyr fa WITH(NOLOCK)
                JOIN DerinSISBkm.dbo.fat f WITH(NOLOCK) ON fa.ehID=f.eID
                WHERE fa.ehstkID=t.stkID AND f.eTip=0 AND f.eDurum<>2 AND fa.ehAdetN>0
                GROUP BY f.eID ORDER BY MAX(f.eTarih) DESC
            ) mal
            ORDER BY (t.kayip_adet * ISNULL(mal.birim,0)) DESC;
            """;
        await using var c = await db.OpenAsync();
        var rows = (await c.QueryAsync<BulunurlukKayip>(new CommandDefinition(sql, new { bas, son, min = MinStok, top }, commandTimeout: 120))).AsList();
        _cache[$"kayip{top}"] = (System.DateTime.UtcNow, rows);
        logger.LogInformation("Bulunurluk kayıp-öncelik: {N} SKU", rows.Count);
        return rows;
    }
}
