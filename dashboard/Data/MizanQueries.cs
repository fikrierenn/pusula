using Dapper;
using GmDashboard.Models;

namespace GmDashboard.Data;

/// <summary>
/// Mizan / likidite dashboard (B-118, plan-25) — DerinSISBkm.mhs trial balance.
/// Kaynak: `DerinSISBkm.mhs.mhsMizan_vw` (Borc/Alacak hazır kolon), `DerinSISBkm.mhs.mhsHsp` (hesap adı). Mevcut Db.OpenAsync (201), yeni bağlantı yok.
/// Dönem = fisSirketID (yıl−2020; 6=2026). Açılış/devir fişi (01.01) dahil → bakiye gerçek (sadece akış değil).
/// B-117 (forensic Kontrol) AYRI track; bu = mali-tablo. İşaret: Bakiye = Borç − Alacak (keşif 2026-06-23 doğrulandı).
/// </summary>
public sealed class MizanQueries(Db db, ILogger<MizanQueries> logger)
{
    public const int YilOffset = 2020;   // fisSirketID + 2020 = takvim yılı

    /// <summary>Seçici için mevcut dönemler (şirket-yıl), en yeni önce. mhsHsp küçük tablo → hızlı.</summary>
    public async Task<IReadOnlyList<(int SirketId, int Yil)>> GetDonemlerAsync()
    {
        await using var conn = await db.OpenAsync();
        var ids = await conn.QueryAsync<int>(
            "SELECT DISTINCT hspSirketID FROM DerinSISBkm.mhs.mhsHsp ORDER BY hspSirketID DESC");
        return ids.Select(s => (s, s + YilOffset)).ToList();
    }

    /// <summary>Üst özet: nakit / alıcı / satıcı / KDV / denge. Tek tarama, koşullu SUM.</summary>
    public async Task<MizanOzet> GetOzetAsync(int sirketId)
    {
        await using var conn = await db.OpenAsync();
        // Bakiye = Borc − Alacak. Varlık (nakit/alıcı) borç-pozitif; satıcı yükümlülük alacak-pozitif gösterilir.
        // Nakit = 100+101+102+108 (103 Verilen Çekler KONTRA hesap → hariç, ayrı gösterilir).
        const string sql = """
            SELECT
                Nakit = SUM(CASE WHEN LEFT(hspKod,3) IN ('100','101','102','108') THEN Borc-Alacak ELSE 0 END),
                VerilenCek = SUM(CASE WHEN LEFT(hspKod,3)='103' THEN Alacak-Borc ELSE 0 END),
                Alicilar = SUM(CASE WHEN LEFT(hspKod,3)='120' THEN Borc-Alacak ELSE 0 END),
                Saticilar = SUM(CASE WHEN LEFT(hspKod,3)='320' THEN Alacak-Borc ELSE 0 END),
                KdvIndirilecek = SUM(CASE WHEN LEFT(hspKod,3)='191' THEN Borc-Alacak ELSE 0 END),
                KdvHesaplanan  = SUM(CASE WHEN LEFT(hspKod,3)='391' THEN Alacak-Borc ELSE 0 END),
                ToplamBorc = SUM(Borc),
                ToplamAlacak = SUM(Alacak)
            FROM DerinSISBkm.mhs.mhsMizan_vw WHERE fisSirketID = @sirketId
            """;
        var r = await conn.QuerySingleAsync(sql, new { sirketId });
        decimal kdvInd = r.KdvIndirilecek ?? 0m, kdvHes = r.KdvHesaplanan ?? 0m;
        return new MizanOzet(
            r.Nakit ?? 0m, r.VerilenCek ?? 0m, r.Alicilar ?? 0m, r.Saticilar ?? 0m,
            kdvInd, kdvHes, kdvHes - kdvInd,
            r.ToplamBorc ?? 0m, r.ToplamAlacak ?? 0m);
    }

    /// <summary>Mizan: ana hesap (3-hane) Borç/Alacak/Bakiye + alt-hesap adedi. Bakiye≠0 olanlar, mutlak büyüklük sıralı.</summary>
    public async Task<IReadOnlyList<MizanRow>> GetMizanAsync(int sirketId)
    {
        await using var conn = await db.OpenAsync();
        const string sql = """
            WITH g AS (
                SELECT LEFT(hspKod,3) AS AnaKod,
                       SUM(Borc) AS Borc, SUM(Alacak) AS Alacak,
                       COUNT(DISTINCT hspKod) AS AltAdet
                FROM DerinSISBkm.mhs.mhsMizan_vw
                WHERE fisSirketID = @sirketId
                GROUP BY LEFT(hspKod,3)
            )
            SELECT g.AnaKod, n.hspAd AS AnaAd,
                   CAST(g.Borc AS decimal(18,2)) AS Borc,
                   CAST(g.Alacak AS decimal(18,2)) AS Alacak,
                   CAST(g.Borc - g.Alacak AS decimal(18,2)) AS Bakiye,
                   g.AltAdet
            FROM g
            OUTER APPLY (
                SELECT TOP 1 h.hspAd FROM DerinSISBkm.mhs.mhsHsp h
                WHERE h.hspSirketID = @sirketId AND h.hspKod LIKE g.AnaKod + '%'
                ORDER BY LEN(h.hspKod), h.hspKod
            ) n
            WHERE g.Borc <> 0 OR g.Alacak <> 0
            ORDER BY ABS(g.Borc - g.Alacak) DESC, g.AnaKod
            """;
        var rows = await conn.QueryAsync<MizanRow>(sql, new { sirketId });
        return rows.ToList();
    }

    /// <summary>Drill: bir ana hesabın (3-hane prefix) alt hesapları. AnaKod whitelist (3 rakam) — injection guard.</summary>
    public async Task<IReadOnlyList<MizanDetayRow>> GetMizanDetayAsync(int sirketId, string anaKod)
    {
        if (anaKod is not { Length: 3 } || !anaKod.All(char.IsDigit))
            throw new ArgumentException("AnaKod 3 haneli olmalı", nameof(anaKod));
        await using var conn = await db.OpenAsync();
        const string sql = """
            WITH g AS (
                SELECT hspKod, SUM(Borc) AS Borc, SUM(Alacak) AS Alacak
                FROM DerinSISBkm.mhs.mhsMizan_vw
                WHERE fisSirketID = @sirketId AND hspKod LIKE @prefix
                GROUP BY hspKod
            )
            SELECT g.hspKod AS HspKod, h.hspAd AS HspAd,
                   CAST(g.Borc AS decimal(18,2)) AS Borc,
                   CAST(g.Alacak AS decimal(18,2)) AS Alacak,
                   CAST(g.Borc - g.Alacak AS decimal(18,2)) AS Bakiye
            FROM g
            LEFT JOIN DerinSISBkm.mhs.mhsHsp h ON h.hspKod = g.hspKod AND h.hspSirketID = @sirketId
            ORDER BY ABS(g.Borc - g.Alacak) DESC, g.hspKod
            """;
        var rows = await conn.QueryAsync<MizanDetayRow>(sql, new { sirketId, prefix = anaKod + "%" });
        return rows.ToList();
    }
}
