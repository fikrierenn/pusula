using Dapper;
using GmDashboard.Models;

namespace GmDashboard.Data;

/// <summary>
/// Finans raporları (B-124) — cari bakiye / risk özeti. SALT-OKUMA (Db.OpenAsync, DerinSISBkm/201).
/// Kaynak: dbo.bakiyeVDGG_vw (cari bazlı borç/alacak/bakiye + vadesi geçmiş GecenB + yaklaşan GelecekB) + dbo.frm (isim/tip/limit).
/// 3-parçalı isim ZORUNLU (app master katalog). View ağır (~8s, tüm car agg) → çağıran spinner gösterir.
/// </summary>
public sealed class FinansQueries(Db db)
{
    /// <summary>Cari bakiye/risk özeti. kapsam: 'satici'(320) | 'alici'(120) | 'hepsi'. ara: kod/ad LIKE. Mutlak bakiyeye göre sıralı.</summary>
    public async Task<IReadOnlyList<CariRiskRow>> GetCariRiskAsync(string kapsam, string? ara, int top)
    {
        await using var conn = await db.OpenAsync();
        var araLike = string.IsNullOrWhiteSpace(ara) ? null : "%" + ara.Trim() + "%";
        var rows = await conn.QueryAsync<CariRiskRow>("""
            SELECT TOP (@top)
                CAST(b.cKod AS int) AS CariId,
                fr.frmKod AS Kod,
                CAST(fr.frmAd AS nvarchar(120)) AS Ad,
                CAST(ISNULL(tp.frmTipAd, CAST(fr.frmTip AS varchar(10))) AS nvarchar(30)) AS TipAd,
                CAST(ABS(b.borc) AS decimal(18,2)) AS Borc,
                CAST(b.alacak AS decimal(18,2)) AS Alacak,
                CAST(b.bakiye AS decimal(18,2)) AS Bakiye,
                CAST(b.GecenB AS decimal(18,2)) AS VadesiGecen,
                CAST(b.GelecekB AS decimal(18,2)) AS Yaklasan,
                CAST(ISNULL(fr.frmBakiyeLimit,0) AS decimal(18,2)) AS Limit
            FROM DerinSISBkm.dbo.bakiyeVDGG_vw b
            JOIN DerinSISBkm.dbo.frm fr ON fr.frmID = b.cKod
            LEFT JOIN DerinSISBkm.dbo.frmTipTnm tp ON tp.frmTipID = fr.frmTip
            WHERE ABS(b.bakiye) > 0
              AND (@kapsam = 'hepsi'
                   OR (@kapsam = 'satici' AND fr.frmKod LIKE '320%')
                   OR (@kapsam = 'alici'  AND fr.frmKod LIKE '120%'))
              AND (@araLike IS NULL OR fr.frmAd LIKE @araLike OR fr.frmKod LIKE @araLike)
            ORDER BY ABS(b.bakiye) DESC
            """, new { kapsam, araLike, top });
        return rows.ToList();
    }
}
