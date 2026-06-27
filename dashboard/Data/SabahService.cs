using Dapper;

namespace GmDashboard.Data;

public sealed record MagazaGunSatir(string Ad, decimal Net, int Fis, decimal Wow, decimal Mtd, decimal Hedef);
public sealed record StockoutSatir(string Kategori, int SatilanCesit, int StoksuzCesit, decimal OranYuzde);

public sealed class SabahVeri
{
    public DateOnly Tarih { get; init; }
    public IReadOnlyList<MagazaGunSatir> Magazalar { get; init; } = [];
    public decimal ToplamNet   => Magazalar.Sum(m => m.Net);
    public decimal ToplamWow   => Magazalar.Sum(m => m.Wow);
    public decimal ToplamMtd   => Magazalar.Sum(m => m.Mtd);
    public decimal ToplamHedef => Magazalar.Sum(m => m.Hedef);
    public IReadOnlyList<StockoutSatir> Stockout { get; init; } = [];
    public string? Hata { get; init; }
}

/// <summary>
/// Sabah Dikkat Listesi veri servisi (MIMBAL entegrasyonu).
/// G1 = dünkü ciro + WoW + MTD hedef. E8 = stockout kategori özeti (sahaf+sezon dışı).
/// </summary>
public sealed class SabahService(Db db)
{
    private const string G1Sql = """
        SELECT
            CASE MG.mekanID WHEN 1 THEN N'FSM' WHEN 4477 THEN N'Özlüce' WHEN 4478 THEN N'İst.Yolu' END AS Ad,
            ISNULL(g.Net,  0) AS Net,
            ISNULL(g.Fis,  0) AS Fis,
            ISNULL(w.Net,  0) AS Wow,
            ISNULL(t.Net,  0) AS Mtd,
            ISNULL(h.Hdf,  0) AS Hedef
        FROM (SELECT 1 AS mekanID UNION ALL SELECT 4477 UNION ALL SELECT 4478) MG
        LEFT JOIN (
            SELECT MG2.mekanID,
                SUM(CASE WHEN s.DocumentsTypeId=3 THEN -1 ELSE 1 END*(s.GrossTotal-s.DiscountTotal-s.VatTotal)) AS Net,
                SUM(CASE WHEN s.DocumentsTypeId=3 THEN -1 ELSE 1 END) AS Fis
            FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
            JOIN EncoreMerkez.dbo.Pos p ON p.Id=s.PosId
            JOIN EncoreMerkez.dbo.Stores st ON st.Id=p.StoreId
            JOIN DerinSISBkm.dbo.posMagaza MG2 ON MG2.mekanKod COLLATE Turkish_CI_AS = st.Code COLLATE Turkish_CI_AS
            LEFT JOIN EncoreMerkez.dbo.SalesProducts spb ON spb.SalesId=s.Id AND spb.BarcodeNo='1001'
            WHERE s.Date >= @dun AND s.Date < @bugun
              AND s.DocumentsTypeId IN (1,2,3,6,7,8) AND spb.Id IS NULL
            GROUP BY MG2.mekanID
        ) g ON g.mekanID = MG.mekanID
        LEFT JOIN (
            SELECT MG2.mekanID,
                SUM(CASE WHEN s.DocumentsTypeId=3 THEN -1 ELSE 1 END*(s.GrossTotal-s.DiscountTotal-s.VatTotal)) AS Net
            FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
            JOIN EncoreMerkez.dbo.Pos p ON p.Id=s.PosId
            JOIN EncoreMerkez.dbo.Stores st ON st.Id=p.StoreId
            JOIN DerinSISBkm.dbo.posMagaza MG2 ON MG2.mekanKod COLLATE Turkish_CI_AS = st.Code COLLATE Turkish_CI_AS
            LEFT JOIN EncoreMerkez.dbo.SalesProducts spb ON spb.SalesId=s.Id AND spb.BarcodeNo='1001'
            WHERE s.Date >= @wow AND s.Date < @wowBitis
              AND s.DocumentsTypeId IN (1,2,3,6,7,8) AND spb.Id IS NULL
            GROUP BY MG2.mekanID
        ) w ON w.mekanID = MG.mekanID
        LEFT JOIN (
            SELECT MG2.mekanID,
                SUM(CASE WHEN s.DocumentsTypeId=3 THEN -1 ELSE 1 END*(s.GrossTotal-s.DiscountTotal-s.VatTotal)) AS Net
            FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
            JOIN EncoreMerkez.dbo.Pos p ON p.Id=s.PosId
            JOIN EncoreMerkez.dbo.Stores st ON st.Id=p.StoreId
            JOIN DerinSISBkm.dbo.posMagaza MG2 ON MG2.mekanKod COLLATE Turkish_CI_AS = st.Code COLLATE Turkish_CI_AS
            LEFT JOIN EncoreMerkez.dbo.SalesProducts spb ON spb.SalesId=s.Id AND spb.BarcodeNo='1001'
            WHERE s.Date >= @ayBas AND s.Date < @bugun
              AND s.DocumentsTypeId IN (1,2,3,6,7,8) AND spb.Id IS NULL
            GROUP BY MG2.mekanID
        ) t ON t.mekanID = MG.mekanID
        LEFT JOIN (
            SELECT mekanId, SUM(hedef) AS Hdf
            FROM BKMDATA.dbo.Hedef WITH(NOLOCK)
            WHERE mekanId IN (1,4477,4478) AND tarih >= @ayBas AND tarih < @bugun
            GROUP BY mekanId
        ) h ON h.mekanId = MG.mekanID
        """;

    // Sahaf (SHF-%) + sezon-bağlı (Akademi/Hazırlık/Sınav Kıyafet) dışı — MIMBAL sinyal kuralları (13.06 sema)
    private const string E8Sql = """
        SELECT x.Kategori,
            COUNT(*)                                                              AS SatilanCesit,
            SUM(CASE WHEN x.Bakiye <= 0 THEN 1 ELSE 0 END)                       AS StoksuzCesit,
            CAST(100.0*SUM(CASE WHEN x.Bakiye<=0 THEN 1 ELSE 0 END)/NULLIF(COUNT(*),0) AS decimal(10,1)) AS OranYuzde
        FROM (
            SELECT k.ktgrAd AS Kategori, sold.stkID, bal.Bakiye
            FROM (
                SELECT DISTINCT h.ehstkID AS stkID
                FROM DerinSISBkm.dbo.irsHrk h WITH(NOLOCK)
                WHERE h.ehTip IN (4,100)
                  AND h.ehTrhS >= DATEADD(DAY,-30,GETDATE())
                  AND h.ehMekan IN (1,4477,4478) AND h.ehAltDepo=0
            ) sold
            JOIN DerinSISBkm.dbo.urn u WITH(NOLOCK) ON u.stkID = sold.stkID
            JOIN DerinSISBkm.dbo.urnKtgr2 k WITH(NOLOCK) ON k.ktgrID = u.urnKtgr2ID
            CROSS APPLY (
                SELECT SUM(b.ehAdetN) AS Bakiye
                FROM DerinSISBkm.dbo.irsHrk b WITH(NOLOCK)
                WHERE b.ehstkID = sold.stkID
                  AND b.ehMekan IN (1,4477,4478) AND b.ehAltDepo=0
            ) bal
            WHERE k.ktgrAd NOT IN (N'Sınav Okulları',N'Dergi',N'Genel',N'Tanımsız',N'Etkinlik',N'Hediye Çeki',
                                    N'Akademi',N'Hazırlık',N'Sınav Kıyafet')
              AND u.stkAd NOT LIKE N'SHF-%'
        ) x
        GROUP BY x.Kategori
        HAVING COUNT(*) >= 20
        ORDER BY OranYuzde DESC;
        """;

    public async Task<SabahVeri> GetAsync()
    {
        var bugun  = DateOnly.FromDateTime(DateTime.Today);
        var dun    = bugun.AddDays(-1);
        var wow    = dun.AddDays(-7);
        var ayBas  = new DateOnly(dun.Year, dun.Month, 1);

        try
        {
            await using var conn = await db.OpenAsync();
            var magazalar = (await conn.QueryAsync<MagazaGunSatir>(G1Sql, new {
                dun      = dun.ToDateTime(TimeOnly.MinValue),
                bugun    = bugun.ToDateTime(TimeOnly.MinValue),
                wow      = wow.ToDateTime(TimeOnly.MinValue),
                wowBitis = wow.AddDays(1).ToDateTime(TimeOnly.MinValue),
                ayBas    = ayBas.ToDateTime(TimeOnly.MinValue),
            })).ToList();

            var stockout = (await conn.QueryAsync<StockoutSatir>(E8Sql)).ToList();

            return new SabahVeri { Tarih = dun, Magazalar = magazalar, Stockout = stockout };
        }
        catch (Exception ex)
        {
            return new SabahVeri
            {
                Tarih = DateOnly.FromDateTime(DateTime.Today).AddDays(-1),
                Hata  = ex.Message
            };
        }
    }

    /// <summary>Veriyi LLM için okunabilir metin bloğuna çevirir (MetinUretAsync'e gider).</summary>
    public static string VeriMetni(SabahVeri v)
    {
        var sb = new System.Text.StringBuilder();
        sb.AppendLine($"=== CIRO ({v.Tarih:dd.MM.yyyy}) ===");
        foreach (var m in v.Magazalar)
        {
            var wow = v.ToplamWow > 0 ? (m.Net - m.Wow) / m.Wow * 100 : 0;
            var mtdGer = m.Hedef > 0 ? m.Mtd / m.Hedef * 100 : 0;
            sb.AppendLine($"{m.Ad}: {m.Net:N0} ₺ | {m.Fis} fiş | WoW {wow:+0.0;-0.0}% | MTD {mtdGer:0.0}% ({m.Mtd:N0}/{m.Hedef:N0})");
        }
        var topWow = v.ToplamWow > 0 ? (v.ToplamNet - v.ToplamWow) / v.ToplamWow * 100 : 0;
        var topMtd = v.ToplamHedef > 0 ? v.ToplamMtd / v.ToplamHedef * 100 : 0;
        sb.AppendLine($"TOPLAM: {v.ToplamNet:N0} ₺ | WoW {topWow:+0.0;-0.0}% | MTD {topMtd:0.0}% ({v.ToplamMtd:N0}/{v.ToplamHedef:N0})");

        sb.AppendLine();
        sb.AppendLine("=== STOCKOUT (son 30 gün, sahaf+sezon dışı) ===");
        sb.AppendLine("Hedef: <%5. Elektronik=spot-mal riski (artefakt olabilir).");
        foreach (var s in v.Stockout)
            sb.AppendLine($"{s.Kategori}: %{s.OranYuzde} ({s.StoksuzCesit}/{s.SatilanCesit} çeşit stoksuz)");

        return sb.ToString();
    }
}
