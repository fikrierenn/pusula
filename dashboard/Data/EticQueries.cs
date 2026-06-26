using Dapper;
using GmDashboard.Models;

namespace GmDashboard.Data;

/// <summary>
/// E-ticaret (JOKER) lojistik performans sorguları — E-ticaret sayfası için.
/// Bağlantı: db.OpenJokerAsync() = 192.168.40.70 DIREKT (linked server ODAKJOKER yerine — B-74 perf).
/// Tablolar dbo.J_* (4-part ODAKJOKER prefix YOK). Tarih param = ISO YYYYMMDD. NET filtre: STATUS NOT IN (1001,1006,1007,3000,4000).
/// Kategori: J_ITEMS.DERINSIS_LOGOGRUP (= DerinSIS Kategori3 grain, linked join gerekmez).
/// </summary>
public sealed class EticQueries(Db db)
{
    // Tatil günleri VERİDEN otomatik: depo'nun çalışmadığı hafta-içi günler (resmi + dini bayram + idari/grev).
    // Çalışılan gün = kargo çıkışı (SENDDATE) ≥ eşik. Hafta-içi olup çalışılmayan = tatil (0-kargo dini bayram dahil).
    // Statik cache (tatil global, request-bağımsız). 6 saatte bir yenilenir.
    const int CalismaEsigi = 100;                 // günde <100 kargo = depo kapalı (normal 3000+, Cmt/tatil <10)
    static string? _tatilCache;
    static DateTime _tatilCacheZaman = DateTime.MinValue;
    static readonly SemaphoreSlim _tatilLock = new(1, 1);

    // Takvim çıkış (müşteri algısı): ham gün farkı, saat hassasiyetli.
    const string CikisTakvim = "CAST(DATEDIFF(HOUR,o.ORDERDATE,o.SENDDATE) AS float)/24";

    // İş günü çıkış (depo gerçek performansı): takvim − hafta sonu − araya giren hafta-içi tatil.
    // ta.T = CROSS APPLY ile gelen tatil sayısı. o.ORDERDATE/o.SENDDATE alias sabit.
    const string CikisIsGunu =
        "DATEDIFF(DAY,o.ORDERDATE,o.SENDDATE) - DATEDIFF(WEEK,o.ORDERDATE,o.SENDDATE)*2 " +
        "- CASE WHEN DATEPART(WEEKDAY,o.ORDERDATE)=1 THEN 1 ELSE 0 END " +
        "- CASE WHEN DATEPART(WEEKDAY,o.SENDDATE)=7 THEN 1 ELSE 0 END - ta.T";

    /// <summary>Tatil VALUES string'i (cache). Çalışılan günleri çeker, C#'ta son 18 ay hafta-içi fark = tatil.</summary>
    async Task<string> TatilValuesAsync(System.Data.Common.DbConnection conn)
    {
        if (_tatilCache is not null && (DateTime.UtcNow - _tatilCacheZaman).TotalHours < 6) return _tatilCache;
        await _tatilLock.WaitAsync();
        try
        {
            if (_tatilCache is not null && (DateTime.UtcNow - _tatilCacheZaman).TotalHours < 6) return _tatilCache;
            var bas = DateOnly.FromDateTime(DateTime.Today).AddMonths(-18);
            var son = DateOnly.FromDateTime(DateTime.Today);
            // Çalışılan günler: kargo çıkışı ≥ eşik
            var calisilan = (await conn.QueryAsync<DateTime>(
                "SELECT CONVERT(date,o.SENDDATE) d FROM dbo.J_ORDERS o " +
                "WHERE o.SENDDATE>=@bas AND o.SENDDATE<@son GROUP BY CONVERT(date,o.SENDDATE) HAVING COUNT(*)>=@esik",
                new { bas = bas.ToString("yyyyMMdd"), son = son.ToString("yyyyMMdd"), esik = CalismaEsigi }))
                .Select(DateOnly.FromDateTime).ToHashSet();
            // Hafta-içi olup çalışılmayan = tatil (0-kargo dini bayram dahil)
            var tatiller = new List<DateOnly>();
            for (var d = bas; d < son; d = d.AddDays(1))
                if (d.DayOfWeek is not DayOfWeek.Saturday and not DayOfWeek.Sunday && !calisilan.Contains(d))
                    tatiller.Add(d);
            _tatilCache = tatiller.Count > 0
                ? string.Join(",", tatiller.Select(d => $"(CONVERT(date,'{d:yyyyMMdd}'))"))
                : "(CONVERT(date,'19000101'))";   // boş liste guard (VALUES boş olamaz)
            _tatilCacheZaman = DateTime.UtcNow;
            return _tatilCache;
        }
        finally { _tatilLock.Release(); }
    }

    static string TatilApply(string tatilValues) =>
        $"CROSS APPLY (SELECT COUNT(*) T FROM (VALUES {tatilValues}) H(d) " +
        "WHERE H.d>o.ORDERDATE AND H.d<=o.SENDDATE AND DATEPART(WEEKDAY,H.d) NOT IN (1,7)) ta";

    /// <summary>Kargo performansı: firma × adet × ort. çıkış günü × ort. teslim günü (dönem-duyarlı, sadece teslim olmuş).</summary>
    public async Task<IReadOnlyList<KargoPerf>> GetKargoPerfAsync(DateOnly start, DateOnly endExcl)
    {
        await using var conn = await db.OpenJokerAsync();
        var tatil = await TatilValuesAsync(conn);
        var sql = $"""
            SELECT TOP 10 ISNULL(c.CNAME,'(bilinmiyor)') AS Kargo, COUNT(*) AS Adet,
                   CAST(AVG({CikisTakvim}) AS decimal(10,1)) AS CikisTakvim,
                   CAST(AVG(CAST({CikisIsGunu} AS float)) AS decimal(10,1)) AS CikisIsGunu,
                   CAST(AVG(CAST(DATEDIFF(HOUR,o.SENDDATE,o.CARGODELIVERYDATE) AS float)/24) AS decimal(10,1)) AS TeslimGun
            FROM dbo.J_ORDERS o
            LEFT JOIN dbo.J_CARGO c ON c.ID=o.CARGOREF
            {TatilApply(tatil)}
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
        await using var conn = await db.OpenJokerAsync();
        const string sql = """
            SELECT DATEDIFF(DAY,o.ORDERDATE,o.SENDDATE) AS Gun, COUNT(*) AS Adet
            FROM dbo.J_ORDERS o
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
        await using var conn = await db.OpenJokerAsync();
        var tatil = await TatilValuesAsync(conn);
        var sql = $"""
            SELECT TOP 15 mus.DCITY AS Sehir, COUNT(*) AS Adet,
                   CAST(AVG({CikisTakvim}) AS decimal(10,1)) AS CikisTakvim,
                   CAST(AVG(CAST({CikisIsGunu} AS float)) AS decimal(10,1)) AS CikisIsGunu,
                   CAST(AVG(CAST(DATEDIFF(HOUR,o.SENDDATE,o.CARGODELIVERYDATE) AS float)/24) AS decimal(10,1)) AS TeslimGun
            FROM dbo.J_ORDERS o
            JOIN dbo.J_ORDER_DELIVERY_ADDRESS mus ON mus.LOGICALREF=o.DELIVERYREF
            {TatilApply(tatil)}
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
        await using var conn = await db.OpenJokerAsync();
        // Son 13 tam ay: bu ayın başından 12 ay geri (kısmi son ay dahil edilmez)
        var ayBas = new DateOnly(DateTime.Today.Year, DateTime.Today.Month, 1).AddMonths(-12);
        var ayBitis = new DateOnly(DateTime.Today.Year, DateTime.Today.Month, 1);
        var tatil = await TatilValuesAsync(conn);
        var sql = $"""
            SELECT YEAR(o.SENDDATE)*100+MONTH(o.SENDDATE) AS AyKod,
                   COUNT(DISTINCT o.ORDERID) AS Siparis,
                   CAST(AVG({CikisTakvim}) AS decimal(10,1)) AS CikisTakvim,
                   CAST(AVG(CAST({CikisIsGunu} AS float)) AS decimal(10,1)) AS CikisIsGunu
            FROM dbo.J_ORDERS o
            {TatilApply(tatil)}
            WHERE o.SENDDATE>=@giso AND o.SENDDATE<@g2iso AND o.SENDDATE IS NOT NULL
              AND o.STATUS NOT IN (1001,1006,1007,3000,4000) AND DATEDIFF(DAY,o.ORDERDATE,o.SENDDATE)>=0
            GROUP BY YEAR(o.SENDDATE)*100+MONTH(o.SENDDATE);
            """;
        var raw = await conn.QueryAsync<(int AyKod, int Siparis, decimal CikisTakvim, decimal CikisIsGunu)>(sql,
            new { giso = ayBas.ToString("yyyyMMdd"), g2iso = ayBitis.ToString("yyyyMMdd") });
        return raw.OrderBy(r => r.AyKod)
            .Select(r => new AyKargo(r.AyKod, $"{r.AyKod % 100:00}.{r.AyKod / 100}", r.Siparis, r.CikisTakvim, r.CikisIsGunu))
            .ToList();
    }

    /// <summary>Gün çıkış detayı (B-41 drill): bir ayın (YYYYMM) günleri × sipariş × çıkış takvim+iş günü.</summary>
    public async Task<IReadOnlyList<GunKargo>> GetGunKargoAsync(int ayKod)
    {
        await using var conn = await db.OpenJokerAsync();
        var ayBas = new DateOnly(ayKod / 100, ayKod % 100, 1);
        var ayBitis = ayBas.AddMonths(1);
        var tatil = await TatilValuesAsync(conn);
        var sql = $"""
            SELECT CONVERT(varchar,o.SENDDATE,104) AS Gun,
                   COUNT(DISTINCT o.ORDERID) AS Siparis,
                   CAST(AVG({CikisTakvim}) AS decimal(10,1)) AS CikisTakvim,
                   CAST(AVG(CAST({CikisIsGunu} AS float)) AS decimal(10,1)) AS CikisIsGunu
            FROM dbo.J_ORDERS o
            {TatilApply(tatil)}
            WHERE o.SENDDATE>=@giso AND o.SENDDATE<@g2iso AND o.SENDDATE IS NOT NULL
              AND o.STATUS NOT IN (1001,1006,1007,3000,4000) AND DATEDIFF(DAY,o.ORDERDATE,o.SENDDATE)>=0
            GROUP BY CONVERT(varchar,o.SENDDATE,104), CONVERT(date,o.SENDDATE);
            """;
        return (await conn.QueryAsync<(string Gun, int Siparis, decimal CikisTakvim, decimal CikisIsGunu)>(sql,
                new { giso = ayBas.ToString("yyyyMMdd"), g2iso = ayBitis.ToString("yyyyMMdd") }))
            .OrderBy(r => r.Gun).Select(r => new GunKargo(r.Gun, r.Siparis, r.CikisTakvim, r.CikisIsGunu)).ToList();
    }

    /// <summary>Kapıda ödeme (COD) özeti (B-41): PAYDEFREF=-3. İade=CARGODELIVERYSTATUS=2, iade maliyeti=2×CARGOPRICE (gidiş+geri, BKM yutar). SENDDATE dönemi.</summary>
    public async Task<CodOzet> GetCodOzetAsync(DateOnly start, DateOnly endExcl)
    {
        await using var conn = await db.OpenJokerAsync();
        const string sql = """
            SELECT COUNT(*) AS Siparis,
                   SUM(CASE WHEN o.STATUS=1005 THEN 1 ELSE 0 END) AS Teslim,
                   SUM(CASE WHEN o.CARGODELIVERYSTATUS=2 THEN 1 ELSE 0 END) AS Iade,
                   CAST(SUM(o.SERVICEPRICE) AS decimal(18,0)) AS KapidaBedel,
                   CAST(SUM(CASE WHEN o.CARGODELIVERYSTATUS=2 THEN 2*o.CARGOPRICE ELSE 0 END) AS decimal(18,0)) AS IadeMaliyet
            FROM dbo.J_ORDERS o
            WHERE o.PAYDEFREF=-3 AND o.SENDDATE>=@giso AND o.SENDDATE<@g2iso AND o.SENDDATE IS NOT NULL;
            """;
        var r = await conn.QuerySingleOrDefaultAsync<(int Siparis, int Teslim, int Iade, decimal KapidaBedel, decimal IadeMaliyet)>(sql,
            new { giso = start.ToString("yyyyMMdd"), g2iso = endExcl.ToString("yyyyMMdd") });
        var oran = r.Siparis > 0 ? Math.Round(100m * r.Iade / r.Siparis, 1) : 0;
        return new CodOzet(r.Siparis, r.Teslim, r.Iade, oran, r.KapidaBedel, r.IadeMaliyet);
    }

    /// <summary>COD il bazlı iade oranı (B-56): coğrafi risk. En yüksek oran üstte (HAVING ≥20 sipariş — gürültü filtresi).</summary>
    public async Task<IReadOnlyList<CodIl>> GetCodIlAsync(DateOnly start, DateOnly endExcl)
    {
        await using var conn = await db.OpenJokerAsync();
        const string sql = """
            SELECT TOP 12 mus.DCITY AS Sehir, COUNT(*) AS Siparis,
                   SUM(CASE WHEN o.CARGODELIVERYSTATUS=2 THEN 1 ELSE 0 END) AS Iade,
                   CAST(100.0*SUM(CASE WHEN o.CARGODELIVERYSTATUS=2 THEN 1 ELSE 0 END)/COUNT(*) AS decimal(10,1)) AS Oran
            FROM dbo.J_ORDERS o
            JOIN dbo.J_ORDER_DELIVERY_ADDRESS mus ON mus.LOGICALREF=o.DELIVERYREF
            WHERE o.PAYDEFREF=-3 AND o.SENDDATE>=@giso AND o.SENDDATE<@g2iso AND o.SENDDATE IS NOT NULL AND mus.DCITY IS NOT NULL
            GROUP BY mus.DCITY HAVING COUNT(*)>=20 ORDER BY Oran DESC;
            """;
        return (await conn.QueryAsync<CodIl>(sql,
            new { giso = start.ToString("yyyyMMdd"), g2iso = endExcl.ToString("yyyyMMdd") })).ToList();
    }

    /// <summary>Bekleyen gün raporu: kargoya çıkmamış (SENDDATE NULL) + normal STATUS siparişlerin yaş dağılımı (anlık, dönemsiz).</summary>
    public async Task<IReadOnlyList<BekleyenBucket>> GetBekleyenAsync()
    {
        await using var conn = await db.OpenJokerAsync();
        const string sql = """
            SELECT CASE WHEN DATEDIFF(DAY,o.ORDERDATE,GETDATE())<=1 THEN '0-1g'
                        WHEN DATEDIFF(DAY,o.ORDERDATE,GETDATE())<=3 THEN '2-3g'
                        WHEN DATEDIFF(DAY,o.ORDERDATE,GETDATE())<=7 THEN '4-7g' ELSE '8+g' END AS Bucket,
                   COUNT(*) AS Adet
            FROM dbo.J_ORDERS o
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

    /// <summary>B-111 WMS bekleyen doluluk — aşama split (anlık, kargoya çıkmamış). L3 raporu mantığı, zincir toplam.
    /// 1000=toplanma bekleyen (raflanmayı bekleyen, en kritik) · 3001/3003/3004=hazırlanan · 3006=temin bekleyen.</summary>
    public async Task<BekleyenDurum> GetBekleyenDurumAsync()
    {
        await using var conn = await db.OpenJokerAsync();
        const string sql = """
            SELECT SUM(CASE WHEN o.STATUS=1000 THEN 1 ELSE 0 END)                AS ToplanmaBekleyen,
                   SUM(CASE WHEN o.STATUS IN (3001,3003,3004) THEN 1 ELSE 0 END) AS Hazirlanan,
                   SUM(CASE WHEN o.STATUS=3006 THEN 1 ELSE 0 END)                AS TeminBekleyen
            FROM dbo.J_ORDERS o
            WHERE o.SENDDATE IS NULL AND o.STATUS IN (1000,3001,3003,3004,3006);
            """;
        return await conn.QueryFirstOrDefaultAsync<BekleyenDurum>(sql) ?? new BekleyenDurum(0, 0, 0);
    }

    /// <summary>E-ticaret (JOKER) kategori mix — verilen dönem. Kategori = J_ITEMS.DERINSIS_LOGOGRUP (DerinSIS Kategori3 grain, linked gerekmez).</summary>
    public async Task<IReadOnlyList<EticKategoriRow>> GetEticKategoriAsync(DateOnly start, DateOnly endExcl)
    {
        await using var conn = await db.OpenJokerAsync();
        var rows = await conn.QueryAsync<EticKategoriRow>("""
            SELECT ji.DERINSIS_LOGOGRUP                AS Kategori,
                COUNT(DISTINCT o.ORDERID)             AS Siparis,
                SUM(d.QUANTITY * d.SELLINGPRICEWITHOUTVAT)      AS NetCiro,
                CAST(SUM(d.QUANTITY) AS int)          AS Adet
            FROM dbo.J_ORDER_DETAILS d WITH(NOLOCK)
            JOIN dbo.J_ORDERS      o  WITH(NOLOCK) ON o.ORDERID    = d.ORDERREF
            JOIN dbo.J_ITEMS       ji WITH(NOLOCK) ON ji.LOGICALREF = d.ITEMREF
            WHERE o.ORDERDATE >= @Bas AND o.ORDERDATE < @Bit AND ji.DERINSIS_LOGOGRUP IS NOT NULL
            GROUP BY ji.DERINSIS_LOGOGRUP
            """, new { Bas = start.ToString("yyyyMMdd"), Bit = endExcl.ToString("yyyyMMdd") });
        return rows.OrderByDescending(r => r.NetCiro).ToList();
    }

    /// <summary>Kategori drill: bir LOGOGRUP kategorisi altındaki ürünler — TOP 30 net ciroya göre (sipariş/adet/ciro).</summary>
    public async Task<IReadOnlyList<EticKategoriUrunRow>> GetEticKategoriUrunAsync(string kategori, DateOnly start, DateOnly endExcl)
    {
        await using var conn = await db.OpenJokerAsync();
        var rows = await conn.QueryAsync<EticKategoriUrunRow>("""
            SELECT TOP 30 ji.NAME              AS Urun,
                COUNT(DISTINCT o.ORDERID)      AS Siparis,
                CAST(SUM(d.QUANTITY) AS int)   AS Adet,
                SUM(d.QUANTITY * d.SELLINGPRICEWITHOUTVAT) AS NetCiro
            FROM dbo.J_ORDER_DETAILS d WITH(NOLOCK)
            JOIN dbo.J_ORDERS      o  WITH(NOLOCK) ON o.ORDERID    = d.ORDERREF
            JOIN dbo.J_ITEMS       ji WITH(NOLOCK) ON ji.LOGICALREF = d.ITEMREF
            WHERE o.ORDERDATE >= @Bas AND o.ORDERDATE < @Bit AND ji.DERINSIS_LOGOGRUP = @Kat
            GROUP BY ji.NAME
            ORDER BY SUM(d.QUANTITY * d.SELLINGPRICEWITHOUTVAT) DESC
            """, new { Bas = start.ToString("yyyyMMdd"), Bit = endExcl.ToString("yyyyMMdd"), Kat = kategori });
        return rows.ToList();
    }

    /// <summary>Kategori × ay (mevcut yıl, Oca→bugün) — yığılmış grafik için. ORDERDATE bazlı net ciro.</summary>
    public async Task<IReadOnlyList<EticKategoriAyRow>> GetEticKategoriYilAsync()
    {
        await using var conn = await db.OpenJokerAsync();
        var yilBas = new DateOnly(DateTime.Today.Year, 1, 1);
        var yarin = DateOnly.FromDateTime(DateTime.Today).AddDays(1);
        var rows = await conn.QueryAsync<EticKategoriAyRow>("""
            SELECT MONTH(o.ORDERDATE)               AS Ay,
                ji.DERINSIS_LOGOGRUP                AS Kategori,
                SUM(d.QUANTITY * d.SELLINGPRICEWITHOUTVAT)    AS NetCiro
            FROM dbo.J_ORDER_DETAILS d WITH(NOLOCK)
            JOIN dbo.J_ORDERS      o  WITH(NOLOCK) ON o.ORDERID    = d.ORDERREF
            JOIN dbo.J_ITEMS       ji WITH(NOLOCK) ON ji.LOGICALREF = d.ITEMREF
            WHERE o.ORDERDATE >= @Bas AND o.ORDERDATE < @Bit AND ji.DERINSIS_LOGOGRUP IS NOT NULL
            GROUP BY MONTH(o.ORDERDATE), ji.DERINSIS_LOGOGRUP
            """, new { Bas = yilBas.ToString("yyyyMMdd"), Bit = yarin.ToString("yyyyMMdd") });
        return rows.ToList();
    }

    /// <summary>Sipariş durum huni — verilen dönem, 6 aşamaya gruplandırılmış.</summary>
    public async Task<IReadOnlyList<EticFunnelRow>> GetFunnelAsync(DateOnly start, DateOnly endExcl)
    {
        await using var conn = await db.OpenJokerAsync();
        var rows = await conn.QueryAsync<EticFunnelRow>("""
            SELECT TOP 10
                CASE
                    WHEN o.STATUS IN (1001,3000,4000) THEN '5-İptal'
                    WHEN o.STATUS IN (1006)           THEN '4-İade'
                    WHEN o.STATUS IN (1005,3009,4009) THEN '3-Kargoya Verildi'
                    WHEN o.STATUS IN (3006,4006,2000,2002,2007) THEN '2-Tedarik Bekliyor'
                    WHEN o.STATUS IN (1007,1009)      THEN '6-Kayıp/Sorunlu'
                    ELSE '1-İşleniyor'
                END AS Asama,
                COUNT(*) AS Siparis,
                SUM(ISNULL(det.net,0)) AS ToplamCiro
            FROM dbo.J_ORDERS o WITH(NOLOCK)
            CROSS APPLY (SELECT SUM(d.QUANTITY*d.SELLINGPRICEWITHOUTVAT) AS net FROM dbo.J_ORDER_DETAILS d WHERE d.ORDERREF=o.ORDERID) det
            WHERE o.ORDERDATE >= @Bas AND o.ORDERDATE < @Bit
            GROUP BY CASE
                    WHEN o.STATUS IN (1001,3000,4000) THEN '5-İptal'
                    WHEN o.STATUS IN (1006)           THEN '4-İade'
                    WHEN o.STATUS IN (1005,3009,4009) THEN '3-Kargoya Verildi'
                    WHEN o.STATUS IN (3006,4006,2000,2002,2007) THEN '2-Tedarik Bekliyor'
                    WHEN o.STATUS IN (1007,1009)      THEN '6-Kayıp/Sorunlu'
                    ELSE '1-İşleniyor'
                END
            """, new { Bas = start.ToString("yyyyMMdd"), Bit = endExcl.ToString("yyyyMMdd") });
        return rows.OrderBy(r => r.Asama).ToList();
    }

    /// <summary>Baskısı yok yapılan siparişler — kullanıcı bazlı özet (tarih aralığı [start, endExcl)). Kaynak JOKER.BASKISIYOK.</summary>
    public async Task<IReadOnlyList<BaskisiYokOzet>> GetBaskisiYokOzetAsync(DateOnly start, DateOnly endExcl)
    {
        await using var conn = await db.OpenJokerAsync();
        var rows = await conn.QueryAsync<BaskisiYokOzet>("""
            SELECT CONVERT(varchar(10), CONVERT(DATE, B.TARIH), 104) AS Gun,
                   COUNT(DISTINCT B.BARCODE)           AS BarkodSayi,
                   COUNT(DISTINCT D.ORDERREF)          AS SipSayi,
                   CAST(SUM(B.QUANTITY) AS int)        AS Miktar,
                   SUM(B.QUANTITY * D.SELLINGPRICE)    AS Tutar
            FROM   dbo.BASKISIYOK B WITH(NOLOCK)
            JOIN   dbo.J_ORDER_DETAILS D WITH(NOLOCK) ON D.LOGICALREF = B.DETAILREF
            WHERE  CONVERT(DATE, B.TARIH) >= @Bas AND CONVERT(DATE, B.TARIH) < @Bit AND B.QUANTITY > 0
            GROUP BY CONVERT(DATE, B.TARIH)
            ORDER BY CONVERT(DATE, B.TARIH) DESC
            """, new { Bas = start.ToString("yyyyMMdd"), Bit = endExcl.ToString("yyyyMMdd") });
        return rows.ToList();
    }

    /// <summary>Baskısı yok — günlük trend (çeşit + adet) tarih aralığı. Sadece BASKISIYOK (barkod + miktar).</summary>
    public async Task<IReadOnlyList<BaskisiYokGun>> GetBaskisiYokTrendAsync(DateOnly start, DateOnly endExcl)
    {
        await using var conn = await db.OpenJokerAsync();
        var rows = await conn.QueryAsync<BaskisiYokGun>("""
            SELECT CONVERT(varchar(10), CONVERT(DATE, B.TARIH), 104) AS Gun,
                   COUNT(DISTINCT B.BARCODE)                         AS Cesit,
                   CAST(SUM(B.QUANTITY) AS int)                      AS Adet
            FROM   dbo.BASKISIYOK B WITH(NOLOCK)
            WHERE  CONVERT(DATE, B.TARIH) >= @Bas AND CONVERT(DATE, B.TARIH) < @Bit AND B.QUANTITY > 0
            GROUP BY CONVERT(DATE, B.TARIH)
            ORDER BY CONVERT(DATE, B.TARIH)
            """, new { Bas = start.ToString("yyyyMMdd"), Bit = endExcl.ToString("yyyyMMdd") });
        return rows.ToList();
    }

    /// <summary>Baskısı yok — ürün bazlı detay (tarih aralığı). BASKISIYOK × J_ORDER_DETAILS × J_ITEMS × EM_USERS.</summary>
    public async Task<IReadOnlyList<BaskisiYokDetay>> GetBaskisiYokDetayAsync(DateOnly start, DateOnly endExcl)
    {
        await using var conn = await db.OpenJokerAsync();
        var rows = await conn.QueryAsync<BaskisiYokDetay>("""
            SELECT CONVERT(varchar(10), B.TARIH, 104)  AS Tarih,
                   U.FULLNAME                          AS Kullanici,
                   D.BARCODE                           AS Barkod,
                   A.CODE                              AS Kod,
                   A.NAME                              AS Ad,
                   A.BRAND                             AS Marka,
                   A.GROUPCODE                         AS Grup,
                   CAST(SUM(B.QUANTITY) AS int)        AS Miktar,
                   SUM(B.QUANTITY * D.SELLINGPRICE)    AS Tutar
            FROM   dbo.BASKISIYOK B WITH(NOLOCK)
            JOIN   dbo.J_ORDER_DETAILS D WITH(NOLOCK) ON D.LOGICALREF = B.DETAILREF
            JOIN   dbo.J_ITEMS A WITH(NOLOCK)         ON A.LOGICALREF = D.ITEMREF
            JOIN   dbo.EM_USERS U WITH(NOLOCK)        ON U.LOGICALREF = B.USERREF
            WHERE  CONVERT(DATE, B.TARIH) >= @Bas AND CONVERT(DATE, B.TARIH) < @Bit AND B.QUANTITY > 0
            GROUP BY B.TARIH, U.FULLNAME, D.BARCODE, A.CODE, A.NAME, A.BRAND, A.GROUPCODE
            ORDER BY SUM(B.QUANTITY * D.SELLINGPRICE) DESC
            """, new { Bas = start.ToString("yyyyMMdd"), Bit = endExcl.ToString("yyyyMMdd") });
        return rows.ToList();
    }

    /// <summary>Baskısı yok — seçili aralık KPI özeti (iptal=B.QUANTITY=0 ayrı sayılır, hariç tutulur).</summary>
    public async Task<BaskisiYokKpi> GetBaskisiYokKpiAsync(DateOnly start, DateOnly endExcl)
    {
        await using var conn = await db.OpenJokerAsync();
        return await conn.QuerySingleAsync<BaskisiYokKpi>("""
            SELECT CAST(COUNT(DISTINCT CASE WHEN B.QUANTITY > 0 THEN B.BARCODE END) AS int)        AS Cesit,
                   CAST(SUM(CASE WHEN B.QUANTITY > 0 THEN B.QUANTITY ELSE 0 END) AS int)            AS Adet,
                   ISNULL(SUM(CASE WHEN B.QUANTITY > 0 THEN B.QUANTITY * D.SELLINGPRICE ELSE 0 END), 0) AS Tutar,
                   CAST(COUNT(DISTINCT CASE WHEN B.QUANTITY > 0 THEN D.ORDERREF END) AS int)        AS Siparis,
                   CAST(SUM(CASE WHEN B.QUANTITY = 0 THEN 1 ELSE 0 END) AS int)                     AS IptalSatir
            FROM   dbo.BASKISIYOK B WITH(NOLOCK)
            JOIN   dbo.J_ORDER_DETAILS D WITH(NOLOCK) ON D.LOGICALREF = B.DETAILREF
            WHERE  CONVERT(DATE, B.TARIH) >= @Bas AND CONVERT(DATE, B.TARIH) < @Bit
            """, new { Bas = start.ToString("yyyyMMdd"), Bit = endExcl.ToString("yyyyMMdd") });
    }

    /// <summary>Baskısı yok — ürün grubu (J_ITEMS.GROUPCODE) bazlı dağılım (iptal hariç). Tutara göre.</summary>
    public async Task<IReadOnlyList<BaskisiYokGrup>> GetBaskisiYokGrupAsync(DateOnly start, DateOnly endExcl)
    {
        await using var conn = await db.OpenJokerAsync();
        var rows = await conn.QueryAsync<BaskisiYokGrup>("""
            SELECT TOP 20 ISNULL(A.GROUPCODE, N'-')         AS Grup,
                   COUNT(DISTINCT B.BARCODE)                AS Cesit,
                   CAST(SUM(B.QUANTITY) AS int)             AS Adet,
                   SUM(B.QUANTITY * D.SELLINGPRICE)         AS Tutar
            FROM   dbo.BASKISIYOK B WITH(NOLOCK)
            JOIN   dbo.J_ORDER_DETAILS D WITH(NOLOCK) ON D.LOGICALREF = B.DETAILREF
            JOIN   dbo.J_ITEMS A WITH(NOLOCK)         ON A.LOGICALREF = D.ITEMREF
            WHERE  CONVERT(DATE, B.TARIH) >= @Bas AND CONVERT(DATE, B.TARIH) < @Bit AND B.QUANTITY > 0
            GROUP BY A.GROUPCODE
            ORDER BY SUM(B.QUANTITY * D.SELLINGPRICE) DESC
            """, new { Bas = start.ToString("yyyyMMdd"), Bit = endExcl.ToString("yyyyMMdd") });
        return rows.ToList();
    }

    /// <summary>Baskısı yok — saat-bazlı yoğunluk (gün içi 0-23, iptal hariç). Hangi saatlerde yoğun.</summary>
    public async Task<IReadOnlyList<BaskisiYokSaat>> GetBaskisiYokSaatAsync(DateOnly start, DateOnly endExcl)
    {
        await using var conn = await db.OpenJokerAsync();
        var rows = await conn.QueryAsync<BaskisiYokSaat>("""
            SELECT RIGHT('0' + CAST(DATEPART(HOUR, B.TARIH) AS varchar(2)), 2) + ':00' AS Saat,
                   CAST(SUM(B.QUANTITY) AS int)        AS Adet,
                   COUNT(DISTINCT B.BARCODE)           AS Cesit
            FROM   dbo.BASKISIYOK B WITH(NOLOCK)
            WHERE  CONVERT(DATE, B.TARIH) >= @Bas AND CONVERT(DATE, B.TARIH) < @Bit AND B.QUANTITY > 0
            GROUP BY DATEPART(HOUR, B.TARIH)
            ORDER BY DATEPART(HOUR, B.TARIH)
            """, new { Bas = start.ToString("yyyyMMdd"), Bit = endExcl.ToString("yyyyMMdd") });
        return rows.ToList();
    }
}
