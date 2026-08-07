using Dapper;
using GmDashboard.Models;

namespace GmDashboard.Data;

/// <summary>
/// Ayrıntılı Gelir Tablosu (B-129) — Net Satış → Faaliyet Gideri (7xx) → Faaliyet Kârı → Finansman/KKEG → Net Kâr.
/// BKM'nin resmi mhsGelirTabloGiderMerkeziDetayli SP'si 6xx-only (7xx opex'i göstermez); bu rapor TAM P&L.
/// İşaret: signed fisTutar (gelir BA=0 →+, gider BA=1 →−). Kapanış fişi HARİÇ. Yıl=sirketID+2020.
/// Merkez filtresi: fisGdrMerkez (null=tüm merkez toplam). Db.OpenAsync → master → 3-parçalı isim.
/// </summary>
public sealed class GelirTabloQueries(Db db, ILogger<GelirTabloQueries> logger)
{
    public const int YilOffset = 2020;

    // .YY (7/A alt-hesap) → kategori adı (TDHP sabit — TekDuzenHesap deseni, hardcode meşru).
    public static readonly IReadOnlyDictionary<string, string> KategoriAd = new Dictionary<string, string>
    {
        ["00"] = "İlk Madde ve Malzeme Giderleri",
        ["10"] = "İşçi Ücret ve Giderleri",
        ["20"] = "Yönetim Ücret ve Giderleri",
        ["30"] = "Dışarıdan Sağlanan Fayda ve Hizmetler",
        ["40"] = "Çeşitli Giderler",
        ["50"] = "Vergi, Resim ve Harçlar",
        ["60"] = "Amortismanlar ve Tükenme Payları",
    };
    // Kategori gösterim sırası.
    public static readonly string[] KategoriSira = ["10", "20", "30", "40", "50", "60", "00"];

    public async Task<IReadOnlyList<(int SirketId, int Yil)>> GetDonemlerAsync()
    {
        await using var conn = await db.OpenAsync();
        var ids = await conn.QueryAsync<int>("SELECT DISTINCT hspSirketID FROM DerinSISBkm.mhs.mhsHsp ORDER BY hspSirketID DESC");
        return ids.Select(s => (s, s + YilOffset)).ToList();
    }

    /// <summary>Merkez seçici — dönemde gider/gelir hareketi olan merkezler (0=GENEL dahil), tutar DESC.</summary>
    public async Task<IReadOnlyList<(int Id, string Ad)>> GetMerkezlerAsync(int sirketId)
    {
        await using var conn = await db.OpenAsync();
        var rows = await conn.QueryAsync<(int Id, string Ad)>("""
            SELECT CAST(ISNULL(ff.fisGdrMerkez,0) AS int) AS Id,
                   MAX(CASE WHEN ISNULL(ff.fisGdrMerkez,0)>0
                       THEN LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(gm.frmAd,N'G - ',N''),N'G- ',N''),N' Gider Merkezi',N'')))
                       ELSE N'GENEL (dağıtılmamış)' END) AS Ad
            FROM DerinSISBkm.mhs.mhsFis ff
            JOIN DerinSISBkm.mhs.mhsHsp h ON h.hspID=ff.fisHspID AND h.hspSirketID=ff.fisSirketID
            LEFT JOIN DerinSISBkm.dbo.frm gm ON gm.frmID=ff.fisGdrMerkez
            WHERE ff.fisSirketID=@sirketId AND LEFT(h.hspKod,1) IN ('6','7')
            GROUP BY CAST(ISNULL(ff.fisGdrMerkez,0) AS int)
            HAVING SUM(ABS(ff.fisTutar))<>0
            """, new { sirketId });
        return rows.ToList();
    }

    /// <summary>P&L ham detay (hesap bazlı, signed). merkezId null → tüm merkez toplam. ayBas..ay penceresi.</summary>
    public async Task<IReadOnlyList<GelirDetay>> GetGelirTabloAsync(int sirketId, int ayBas, int ay, int? merkezId)
    {
        await using var conn = await db.OpenAsync();
        var rows = await conn.QueryAsync<GelirDetay>("""
            SELECT
              CASE
                WHEN LEFT(h.hspKod,2) IN ('60','61') THEN 'NETSATIS'
                WHEN LEFT(h.hspKod,3) IN ('740','760','770','750') THEN 'GIDER'
                WHEN LEFT(h.hspKod,3)='780' OR LEFT(h.hspKod,2)='66' OR LEFT(h.hspKod,3)='653' THEN 'FINANSMAN'
                WHEN LEFT(h.hspKod,3) IN ('689','680','681') THEN 'KKEG'
                WHEN LEFT(h.hspKod,2) IN ('64','67') THEN 'DIGERGELIR'
                ELSE 'DIGERGIDER'
              END AS Bolum,
              CASE WHEN LEFT(h.hspKod,3) IN ('740','760','770','750')
                   THEN SUBSTRING(h.hspKod,5,2) ELSE '' END AS Kategori,
              h.hspKod AS HspKod,
              CAST(h.hspAd AS nvarchar(90)) AS HspAd,
              CAST(SUM(ff.fisTutar) AS decimal(18,2)) AS Tutar
            FROM DerinSISBkm.mhs.mhsFis ff
            JOIN DerinSISBkm.mhs.mhsFisBaslik b ON b.fisbID=ff.fisID AND b.fisbSirketID=ff.fisSirketID
            JOIN DerinSISBkm.mhs.mhsHsp h ON h.hspID=ff.fisHspID AND h.hspSirketID=ff.fisSirketID
            WHERE ff.fisSirketID=@sirketId
              AND MONTH(ff.fisTarih) BETWEEN @ayBas AND @ay
              AND ISNULL(b.fisAd,N'')<>N'Kapanış'
              AND LEFT(h.hspKod,1) IN ('6','7')
              AND (@merkezId IS NULL OR ISNULL(ff.fisGdrMerkez,0)=@merkezId)
            GROUP BY
              CASE
                WHEN LEFT(h.hspKod,2) IN ('60','61') THEN 'NETSATIS'
                WHEN LEFT(h.hspKod,3) IN ('740','760','770','750') THEN 'GIDER'
                WHEN LEFT(h.hspKod,3)='780' OR LEFT(h.hspKod,2)='66' OR LEFT(h.hspKod,3)='653' THEN 'FINANSMAN'
                WHEN LEFT(h.hspKod,3) IN ('689','680','681') THEN 'KKEG'
                WHEN LEFT(h.hspKod,2) IN ('64','67') THEN 'DIGERGELIR'
                ELSE 'DIGERGIDER'
              END,
              CASE WHEN LEFT(h.hspKod,3) IN ('740','760','770','750')
                   THEN SUBSTRING(h.hspKod,5,2) ELSE '' END,
              h.hspKod, CAST(h.hspAd AS nvarchar(90))
            HAVING SUM(ff.fisTutar)<>0
            """, new { sirketId, ayBas, ay, merkezId });
        var list = rows.ToList();
        logger.LogInformation("Gelir tablosu: sirket {S} ay {B}-{A} merkez {M} → {N} satır", sirketId, ayBas, ay, merkezId, list.Count);
        return list;
    }
}
