using Dapper;
using GmDashboard.Models;

namespace GmDashboard.Data;

/// <summary>
/// Gider Merkezi Dağılımlı Mizan (B-128). Kaynak: mhs.mhsFis — MizanQueries ile AYNI çekirdek
/// (Bakiye = Borç−Alacak, fisBA=1→-fisTutar / fisBA=0→fisTutar; Kapanış fişi HARİÇ; yıl = sirketID+2020).
/// Gider = 7xx tümü + gider-6xx (62/63/65/66/68); gelir 6xx (600/602/642/679) HARİÇ.
/// DerinSIS resmi "Gider Merkezi Dağılımlı Mizan" ile birebir doğrulandı (2026-08-06, Haziran).
/// Db.OpenAsync → master → 3-parçalı isim ZORUNLU. Salt-okuma (erp-write-policy).
/// Hücre (hesap×merkez) tıkla → arkasındaki yevmiye satırları → fiş/fatura drill.
/// </summary>
public sealed class GiderMizanQueries(Db db, ILogger<GiderMizanQueries> logger)
{
    public const int YilOffset = 2020;   // fisSirketID + 2020 = takvim yılı (MizanQueries ile aynı)

    // Gider hesap filtresi — tek yerde. Çekirdek + drill AYNI filtreyi kullanır (emitter-ayrımı).
    private const string GiderFiltre =
        "(h.hspKod LIKE '7%' OR LEFT(h.hspKod,2) IN ('62','63','65','66','68'))";

    // Gider merkezi adı temizliği ("G - …  Gider Merkezi" → kısa). 0 → GENEL.
    private const string MerkezAdExpr =
        "CASE WHEN ISNULL(ff.fisGdrMerkez,0) > 0 " +
        "THEN LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(gm.frmAd,N'G - ',N''),N'G- ',N''),N' Gider Merkezi',N''))) " +
        "ELSE N'GENEL (dağıtılmamış)' END";

    /// <summary>Seçici için mevcut dönemler (şirket-yıl), en yeni önce.</summary>
    public async Task<IReadOnlyList<(int SirketId, int Yil)>> GetDonemlerAsync()
    {
        await using var conn = await db.OpenAsync();
        var ids = await conn.QueryAsync<int>(
            "SELECT DISTINCT hspSirketID FROM DerinSISBkm.mhs.mhsHsp ORDER BY hspSirketID DESC");
        return ids.Select(s => (s, s + YilOffset)).ToList();
    }

    /// <summary>Matris ham satırları (hesap × merkez). ayBas..ay penceresi (kümüle ayBas=1 · tek ay ayBas=ay).</summary>
    public async Task<IReadOnlyList<GiderMizanSatir>> GetMatrisAsync(int sirketId, int ayBas, int ay)
    {
        await using var conn = await db.OpenAsync();
        var rows = await conn.QueryAsync<GiderMizanSatir>($"""
            SELECT LEFT(h.hspKod,3) AS Grup,
                   CAST(ISNULL(an.aHspAd, N'') AS nvarchar(60)) AS GrupAd,
                   h.hspKod AS HspKod,
                   CAST(h.hspAd AS nvarchar(90)) AS HspAd,
                   CAST(ISNULL(ff.fisGdrMerkez,0) AS int) AS MerkezId,
                   {MerkezAdExpr} AS MerkezAd,
                   CAST(SUM(CASE WHEN ff.fisBA=1 THEN -ff.fisTutar ELSE 0 END)
                      - SUM(CASE WHEN ff.fisBA=0 THEN  ff.fisTutar ELSE 0 END) AS decimal(18,2)) AS Gider
            FROM DerinSISBkm.mhs.mhsFis ff
            JOIN DerinSISBkm.mhs.mhsFisBaslik b ON b.fisbID = ff.fisID AND b.fisbSirketID = ff.fisSirketID
            JOIN DerinSISBkm.mhs.mhsHsp h       ON h.hspID = ff.fisHspID AND h.hspSirketID = ff.fisSirketID
            LEFT JOIN DerinSISBkm.mhs.mhsAnaHsp an ON CAST(an.aHspID AS varchar(20)) = LEFT(h.hspKod,3)
            LEFT JOIN DerinSISBkm.dbo.frm gm       ON gm.frmID = ff.fisGdrMerkez
            WHERE ff.fisSirketID = @sirketId
              AND MONTH(ff.fisTarih) BETWEEN @ayBas AND @ay
              AND ISNULL(b.fisAd, N'') <> N'Kapanış'
              AND {GiderFiltre}
            GROUP BY LEFT(h.hspKod,3), CAST(ISNULL(an.aHspAd, N'') AS nvarchar(60)),
                     h.hspKod, CAST(h.hspAd AS nvarchar(90)),
                     CAST(ISNULL(ff.fisGdrMerkez,0) AS int), {MerkezAdExpr}
            HAVING SUM(CASE WHEN ff.fisBA=1 THEN -ff.fisTutar ELSE 0 END)
                 - SUM(CASE WHEN ff.fisBA=0 THEN  ff.fisTutar ELSE 0 END) <> 0
            """, new { sirketId, ayBas, ay });
        var list = rows.ToList();
        logger.LogInformation("Gider mizan matris: sirket {S} ay {B}-{A} → {N} satır", sirketId, ayBas, ay, list.Count);
        return list;
    }

    /// <summary>Hücre drill: (hesap kodu × merkez × dönem) arkasındaki yevmiye satırları + varsa fatura bağı.</summary>
    public async Task<IReadOnlyList<GiderMizanDetay>> GetHucreDetayAsync(
        int sirketId, int ayBas, int ay, string hspKod, int merkezId)
    {
        await using var conn = await db.OpenAsync();
        var rows = await conn.QueryAsync<GiderMizanDetay>("""
            SELECT CAST(ff.fisID AS int) AS FisId,
                   CAST(ff.fisSirketID AS int) AS Sirket,
                   CAST(b.yevmiyeNo AS int) AS YevmiyeNo,
                   CONVERT(varchar(10), ff.fisTarih, 104) AS Tarih,
                   CAST(ff.fisAciklama AS nvarchar(160)) AS Aciklama,
                   CAST(-ff.fisTutar AS decimal(18,2)) AS Tutar,   -- satır gideri = Borç−Alacak (tek satırda −fisTutar)
                   fa.eID AS FaturaEID, CAST(fa.eNo AS varchar(50)) AS FaturaNo
            FROM DerinSISBkm.mhs.mhsFis ff
            JOIN DerinSISBkm.mhs.mhsFisBaslik b ON b.fisbID = ff.fisID AND b.fisbSirketID = ff.fisSirketID
            JOIN DerinSISBkm.mhs.mhsHsp h       ON h.hspID = ff.fisHspID AND h.hspSirketID = ff.fisSirketID
            OUTER APPLY (SELECT TOP 1 f2.eID, f2.eNo FROM DerinSISBkm.dbo.fat f2 WHERE f2.eMhsFisID = b.fisbID) fa
            WHERE ff.fisSirketID = @sirketId
              AND MONTH(ff.fisTarih) BETWEEN @ayBas AND @ay
              AND ISNULL(b.fisAd, N'') <> N'Kapanış'
              AND h.hspKod = @hspKod
              AND ISNULL(ff.fisGdrMerkez,0) = @merkezId
            ORDER BY ff.fisTarih, ff.fisID
            """, new { sirketId, ayBas, ay, hspKod, merkezId });
        return rows.ToList();
    }
}
