using Dapper;
using GmDashboard.Models;

namespace GmDashboard.Data;

/// <summary>
/// E-ticaret (JOKER) lojistik performans sorguları — E-ticaret sayfası için.
/// Tarih param = ISO YYYYMMDD (linked server ODAKJOKER). NET filtre: STATUS NOT IN (1001,1006,1007,3000,4000).
/// </summary>
public sealed class EticQueries(Db db)
{
    // Türkiye resmi tatilleri 2025-2026 (depo kapalı). Dini bayram tarihleri YAKLAŞIK — yıllık güncellenmeli.
    // Kullanım: çıkış süresi (sipariş→kargoya veriliş) iş günü hesabında. Depo Pzt-Cuma çalışıyor (Cmt 5/Paz 0 doğrulandı 13.06).
    const string Holidays =
        "(CONVERT(date,'20250101')),(CONVERT(date,'20250330')),(CONVERT(date,'20250331')),(CONVERT(date,'20250401'))," +
        "(CONVERT(date,'20250423')),(CONVERT(date,'20250501')),(CONVERT(date,'20250519'))," +
        "(CONVERT(date,'20250606')),(CONVERT(date,'20250607')),(CONVERT(date,'20250608')),(CONVERT(date,'20250609'))," +
        "(CONVERT(date,'20250715')),(CONVERT(date,'20250830')),(CONVERT(date,'20251029'))," +
        "(CONVERT(date,'20260101')),(CONVERT(date,'20260320')),(CONVERT(date,'20260321')),(CONVERT(date,'20260322'))," +
        "(CONVERT(date,'20260423')),(CONVERT(date,'20260501')),(CONVERT(date,'20260519'))," +
        "(CONVERT(date,'20260527')),(CONVERT(date,'20260528')),(CONVERT(date,'20260529')),(CONVERT(date,'20260530'))," +
        "(CONVERT(date,'20260715')),(CONVERT(date,'20260830')),(CONVERT(date,'20261029'))";

    // Takvim çıkış (müşteri algısı): ham gün farkı, saat hassasiyetli.
    const string CikisTakvim = "CAST(DATEDIFF(HOUR,o.ORDERDATE,o.SENDDATE) AS float)/24";

    // İş günü çıkış (depo gerçek performansı): takvim − hafta sonu − araya giren hafta-içi resmi tatil.
    // ta.T = CROSS APPLY ile gelen tatil sayısı. o.ORDERDATE/o.SENDDATE alias sabit.
    const string CikisIsGunu =
        "DATEDIFF(DAY,o.ORDERDATE,o.SENDDATE) - DATEDIFF(WEEK,o.ORDERDATE,o.SENDDATE)*2 " +
        "- CASE WHEN DATEPART(WEEKDAY,o.ORDERDATE)=1 THEN 1 ELSE 0 END " +
        "- CASE WHEN DATEPART(WEEKDAY,o.SENDDATE)=7 THEN 1 ELSE 0 END - ta.T";

    static string TatilApply() =>
        $"CROSS APPLY (SELECT COUNT(*) T FROM (VALUES {Holidays}) H(d) " +
        "WHERE H.d>o.ORDERDATE AND H.d<=o.SENDDATE AND DATEPART(WEEKDAY,H.d) NOT IN (1,7)) ta";

    /// <summary>Kargo performansı: firma × adet × ort. çıkış günü × ort. teslim günü (dönem-duyarlı, sadece teslim olmuş).</summary>
    public async Task<IReadOnlyList<KargoPerf>> GetKargoPerfAsync(DateOnly start, DateOnly endExcl)
    {
        await using var conn = await db.OpenAsync();
        var sql = $"""
            SELECT TOP 10 ISNULL(c.CNAME,'(bilinmiyor)') AS Kargo, COUNT(*) AS Adet,
                   CAST(AVG({CikisTakvim}) AS decimal(10,1)) AS CikisTakvim,
                   CAST(AVG(CAST({CikisIsGunu} AS float)) AS decimal(10,1)) AS CikisIsGunu,
                   CAST(AVG(CAST(DATEDIFF(HOUR,o.SENDDATE,o.CARGODELIVERYDATE) AS float)/24) AS decimal(10,1)) AS TeslimGun
            FROM ODAKJOKER.JOKER.dbo.J_ORDERS o
            LEFT JOIN ODAKJOKER.JOKER.dbo.J_CARGO c ON c.ID=o.CARGOREF
            {TatilApply()}
            WHERE o.ORDERDATE>=@giso AND o.ORDERDATE<@g2iso
              AND o.SENDDATE IS NOT NULL AND o.CARGODELIVERYDATE IS NOT NULL
              AND o.STATUS NOT IN (1001,1006,1007,3000,4000)
            GROUP BY ISNULL(c.CNAME,'(bilinmiyor)') ORDER BY Adet DESC;
            """;
        return (await conn.QueryAsync<KargoPerf>(sql,
            new { giso = start.ToString("yyyyMMdd"), g2iso = endExcl.ToString("yyyyMMdd") })).ToList();
    }

    /// <summary>Günlük kargo çıkış dağılımı: sipariş→kargoya teslim gün farkı (0,1,2…) × paket adedi (dönem, çıkmış siparişler).</summary>
    public async Task<IReadOnlyList<KargoGun>> GetKargoGunAsync(DateOnly start, DateOnly endExcl)
    {
        await using var conn = await db.OpenAsync();
        const string sql = """
            SELECT DATEDIFF(DAY,o.ORDERDATE,o.SENDDATE) AS Gun, COUNT(*) AS Adet
            FROM ODAKJOKER.JOKER.dbo.J_ORDERS o
            WHERE o.ORDERDATE>=@giso AND o.ORDERDATE<@g2iso
              AND o.SENDDATE IS NOT NULL AND o.STATUS NOT IN (1001,1006,1007,3000,4000)
              AND DATEDIFF(DAY,o.ORDERDATE,o.SENDDATE)>=0
            GROUP BY DATEDIFF(DAY,o.ORDERDATE,o.SENDDATE);
            """;
        return (await conn.QueryAsync<KargoGun>(sql,
                new { giso = start.ToString("yyyyMMdd"), g2iso = endExcl.ToString("yyyyMMdd") }))
            .OrderBy(x => x.Gun).ToList();
    }

    /// <summary>İl teslimat performansı (B-41): şehir × adet × ort çıkış/teslim gün. Kargoya çıkış (SENDDATE) dönemi, teslim olmuş (STATUS=1005).</summary>
    public async Task<IReadOnlyList<IlTeslimat>> GetIlTeslimatAsync(DateOnly start, DateOnly endExcl)
    {
        await using var conn = await db.OpenAsync();
        var sql = $"""
            SELECT TOP 15 mus.DCITY AS Sehir, COUNT(*) AS Adet,
                   CAST(AVG({CikisTakvim}) AS decimal(10,1)) AS CikisTakvim,
                   CAST(AVG(CAST({CikisIsGunu} AS float)) AS decimal(10,1)) AS CikisIsGunu,
                   CAST(AVG(CAST(DATEDIFF(HOUR,o.SENDDATE,o.CARGODELIVERYDATE) AS float)/24) AS decimal(10,1)) AS TeslimGun
            FROM ODAKJOKER.JOKER.dbo.J_ORDERS o
            JOIN ODAKJOKER.JOKER.dbo.J_ORDER_DELIVERY_ADDRESS mus ON mus.LOGICALREF=o.DELIVERYREF
            {TatilApply()}
            WHERE o.SENDDATE>=@giso AND o.SENDDATE<@g2iso
              AND o.CARGODELIVERYDATE IS NOT NULL AND o.STATUS=1005 AND mus.DCITY IS NOT NULL
            GROUP BY mus.DCITY ORDER BY Adet DESC;
            """;
        return (await conn.QueryAsync<IlTeslimat>(sql,
            new { giso = start.ToString("yyyyMMdd"), g2iso = endExcl.ToString("yyyyMMdd") })).ToList();
    }

    /// <summary>Aylık çıkış trendi (B-41): son 13 ay × sipariş × ort çıkış gün (sipariş→kargoya veriliş). Dönem-bağımsız (kapasite/yoğunluk trendi).</summary>
    public async Task<IReadOnlyList<AyKargo>> GetAyKargoAsync()
    {
        await using var conn = await db.OpenAsync();
        // Son 13 tam ay: bu ayın başından 12 ay geri (kısmi son ay dahil edilmez)
        var ayBas = new DateOnly(DateTime.Today.Year, DateTime.Today.Month, 1).AddMonths(-12);
        var ayBitis = new DateOnly(DateTime.Today.Year, DateTime.Today.Month, 1);
        var sql = $"""
            SELECT YEAR(o.SENDDATE)*100+MONTH(o.SENDDATE) AS AyKod,
                   COUNT(DISTINCT o.ORDERID) AS Siparis,
                   CAST(AVG({CikisTakvim}) AS decimal(10,1)) AS CikisTakvim,
                   CAST(AVG(CAST({CikisIsGunu} AS float)) AS decimal(10,1)) AS CikisIsGunu
            FROM ODAKJOKER.JOKER.dbo.J_ORDERS o
            {TatilApply()}
            WHERE o.SENDDATE>=@giso AND o.SENDDATE<@g2iso AND o.SENDDATE IS NOT NULL
              AND o.STATUS NOT IN (1001,1006,1007,3000,4000) AND DATEDIFF(DAY,o.ORDERDATE,o.SENDDATE)>=0
            GROUP BY YEAR(o.SENDDATE)*100+MONTH(o.SENDDATE);
            """;
        var raw = await conn.QueryAsync<(int AyKod, int Siparis, decimal CikisTakvim, decimal CikisIsGunu)>(sql,
            new { giso = ayBas.ToString("yyyyMMdd"), g2iso = ayBitis.ToString("yyyyMMdd") });
        return raw.OrderBy(r => r.AyKod)
            .Select(r => new AyKargo($"{r.AyKod % 100:00}.{r.AyKod / 100}", r.Siparis, r.CikisTakvim, r.CikisIsGunu))
            .ToList();
    }

    /// <summary>Kapıda ödeme (COD) özeti (B-41): PAYDEFREF=-3. İade=CARGODELIVERYSTATUS=2, iade maliyeti=2×CARGOPRICE (gidiş+geri, BKM yutar). SENDDATE dönemi.</summary>
    public async Task<CodOzet> GetCodOzetAsync(DateOnly start, DateOnly endExcl)
    {
        await using var conn = await db.OpenAsync();
        const string sql = """
            SELECT COUNT(*) AS Siparis,
                   SUM(CASE WHEN o.STATUS=1005 THEN 1 ELSE 0 END) AS Teslim,
                   SUM(CASE WHEN o.CARGODELIVERYSTATUS=2 THEN 1 ELSE 0 END) AS Iade,
                   CAST(SUM(o.SERVICEPRICE) AS decimal(18,0)) AS KapidaBedel,
                   CAST(SUM(CASE WHEN o.CARGODELIVERYSTATUS=2 THEN 2*o.CARGOPRICE ELSE 0 END) AS decimal(18,0)) AS IadeMaliyet
            FROM ODAKJOKER.JOKER.dbo.J_ORDERS o
            WHERE o.PAYDEFREF=-3 AND o.SENDDATE>=@giso AND o.SENDDATE<@g2iso AND o.SENDDATE IS NOT NULL;
            """;
        var r = await conn.QuerySingleOrDefaultAsync<(int Siparis, int Teslim, int Iade, decimal KapidaBedel, decimal IadeMaliyet)>(sql,
            new { giso = start.ToString("yyyyMMdd"), g2iso = endExcl.ToString("yyyyMMdd") });
        var oran = r.Siparis > 0 ? Math.Round(100m * r.Iade / r.Siparis, 1) : 0;
        return new CodOzet(r.Siparis, r.Teslim, r.Iade, oran, r.KapidaBedel, r.IadeMaliyet);
    }

    /// <summary>Bekleyen gün raporu: kargoya çıkmamış (SENDDATE NULL) + normal STATUS siparişlerin yaş dağılımı (anlık, dönemsiz).</summary>
    public async Task<IReadOnlyList<BekleyenBucket>> GetBekleyenAsync()
    {
        await using var conn = await db.OpenAsync();
        const string sql = """
            SELECT CASE WHEN DATEDIFF(DAY,o.ORDERDATE,GETDATE())<=1 THEN '0-1g'
                        WHEN DATEDIFF(DAY,o.ORDERDATE,GETDATE())<=3 THEN '2-3g'
                        WHEN DATEDIFF(DAY,o.ORDERDATE,GETDATE())<=7 THEN '4-7g' ELSE '8+g' END AS Bucket,
                   COUNT(*) AS Adet
            FROM ODAKJOKER.JOKER.dbo.J_ORDERS o
            WHERE o.SENDDATE IS NULL AND o.STATUS NOT IN (1001,1006,1007,3000,4000)
            GROUP BY CASE WHEN DATEDIFF(DAY,o.ORDERDATE,GETDATE())<=1 THEN '0-1g'
                          WHEN DATEDIFF(DAY,o.ORDERDATE,GETDATE())<=3 THEN '2-3g'
                          WHEN DATEDIFF(DAY,o.ORDERDATE,GETDATE())<=7 THEN '4-7g' ELSE '8+g' END;
            """;
        // Sabit sıra (0-1g → 8+g); eksik bucket 0 ile doldurulur
        var raw = (await conn.QueryAsync<BekleyenBucket>(sql)).ToDictionary(b => b.Bucket, b => b.Adet);
        return new[] { "0-1g", "2-3g", "4-7g", "8+g" }
            .Select(k => new BekleyenBucket(k, raw.GetValueOrDefault(k, 0))).ToList();
    }
}
