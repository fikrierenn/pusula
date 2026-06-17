using Dapper;
using GmDashboard.Models;

namespace GmDashboard.Data;

/// <summary>
/// Referans paneller (envanter + müşteri). Aylık/365g sabit pencere. SQL Python gm_dashboard.py'den port.
/// </summary>
public sealed partial class RefQueries(Db db, ILogger<RefQueries> logger, IcKartService icKart)
{
    /// <summary>RFM müşteri segmenti — yazarkasa (365g) + e-ticaret. dun = referans gün.</summary>
    public async Task<(IReadOnlyList<RfmSegment> Yazarkasa, IReadOnlyList<RfmSegment> Eticaret)> GetRfmAsync(DateOnly dun)
    {
        var dunDt = dun.ToDateTime(TimeOnly.MinValue);
        var g2Dt = dun.AddDays(1).ToDateTime(TimeOnly.MinValue);
        // B-88: yk (EncoreMerkez) + et (JOKER) bağımsız → her biri kendi bağlantısı, paralel (B-74 deseni).
        async Task<List<RfmSegment>> Q(string sql, object prm)
        {
            await using var c = await db.OpenAsync();
            return (await c.QueryAsync<RfmSegment>(sql, prm)).OrderBy(r => r.Segment).ToList();
        }
        // et için DİREKT JOKER (linked değil) — detay net (KDV+kargo-hariç) hızlı çalışır. plan-16.
        async Task<List<RfmSegment>> Qj(string sql, object prm)
        {
            await using var c = await db.OpenJokerAsync();
            return (await c.QueryAsync<RfmSegment>(sql, prm)).OrderBy(r => r.Segment).ToList();
        }

        // Yazarkasa (EncoreMerkez Sales, CustomersId) — iç-kart tek kanonik filtre (plan-18: isim+tel+elle liste)
        var icIds = icKart.Idler();
        var ykSql = $"""
            SELECT seg.S AS Segment, COUNT(*) AS Musteri, SUM(c.Mon) AS Ciro
            FROM (SELECT s.CustomersId, DATEDIFF(DAY,MAX(s.Date),@dun) Rec, COUNT(*) Frq, SUM(s.GrossTotal-s.DiscountTotal-s.VatTotal) Mon
                  FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
                  WHERE s.DocumentsTypeId=1 AND s.CustomersId>0 AND s.Date>=DATEADD(DAY,-365,@dun) AND s.Date<@g2{IcKartFiltre.Sql("s.CustomersId", icIds.Length > 0)}
                  GROUP BY s.CustomersId) c
            CROSS APPLY (SELECT CAST(CASE WHEN Frq>=8 AND Rec<=30 THEN N'1-Şampiyon' WHEN Frq>=4 AND Rec<=90 THEN N'2-Sadık'
                         WHEN Frq<=2 AND Rec<=30 THEN N'3-Yeni' WHEN Rec BETWEEN 91 AND 180 THEN N'4-Risk'
                         WHEN Rec>180 THEN N'5-Kayıp' ELSE N'6-Diğer' END AS nvarchar(20)) S) seg
            GROUP BY seg.S;
            """;
        var tYk = Q(ykSql, new { dun = dunDt, g2 = g2Dt, icIds });

        // E-ticaret (JOKER, CUSTOMERREF) — ISO tarih
        const string etSql = """
            SELECT seg.S AS Segment, COUNT(*) AS Musteri, SUM(c.Mon) AS Ciro
            FROM (SELECT oc.CUSTOMERREF, DATEDIFF(DAY,MAX(o.ORDERDATE),@dun) Rec, COUNT(*) Frq, SUM(ISNULL(det.net,0)) Mon
                  FROM dbo.J_ORDERS o
                  JOIN dbo.J_ORDER_CLIENTS oc ON oc.LOGICALREF=o.CLIENTREF
                  CROSS APPLY (SELECT SUM(d.QUANTITY*d.SELLINGPRICEWITHOUTVAT) AS net FROM dbo.J_ORDER_DETAILS d WHERE d.ORDERREF=o.ORDERID) det
                  WHERE o.ORDERDATE>=@bas AND o.ORDERDATE<@g2 AND oc.CUSTOMERREF>0
                  GROUP BY oc.CUSTOMERREF) c
            CROSS APPLY (SELECT CAST(CASE WHEN Frq>=5 AND Rec<=30 THEN N'1-Şampiyon' WHEN Frq>=3 AND Rec<=90 THEN N'2-Sadık'
                         WHEN Frq<=2 AND Rec<=30 THEN N'3-Yeni' WHEN Rec BETWEEN 91 AND 180 THEN N'4-Risk'
                         WHEN Rec>180 THEN N'5-Kayıp' ELSE N'6-Diğer' END AS nvarchar(20)) S) seg
            GROUP BY seg.S;
            """;
        var tEt = Qj(etSql,
            new { dun = dun.ToString("yyyyMMdd"), bas = dun.AddDays(-365).ToString("yyyyMMdd"), g2 = dun.AddDays(1).ToString("yyyyMMdd") });

        await Task.WhenAll(tYk, tEt);
        return (await tYk, await tEt);
    }

    // Stok/envanter raporlarında dışlanan kategoriler (sema metrics envanter_exclusions)
    const string EXC = "(N'Sınav Okulları',N'Dergi',N'Genel',N'Tanımsız',N'Etkinlik',N'Hediye Çeki',N'Sınav Kayıt')";

    /// <summary>Envanter sayfası: toplam değer + devir + ABC + marka + stockout. Geçen tam ay penceresi.</summary>
    public async Task<InventoryData> GetInventoryAsync(DateOnly dun)
    {
        var ayBas = new DateOnly(dun.Year, dun.Month, 1).AddMonths(-1);  // geçen ay ilk
        var aySon = new DateOnly(dun.Year, dun.Month, 1);               // bu ay ilk (exclusive)
        var aySonGun = aySon.AddDays(-1);                                // geçen ay son gün (snapshot)
        var p = new
        {
            ayBas = ayBas.ToDateTime(TimeOnly.MinValue),
            aySon = aySon.ToDateTime(TimeOnly.MinValue),
            snapBas = ayBas.ToString("yyyyMMdd"),       // ISO yyyyMMdd — yyyy-MM-dd YASAK (sql-server-conventions)
            snapSon = aySonGun.ToString("yyyyMMdd"),
        };

        // B-74: 5 ağır sorgu tek bağlantıda sıralıydı (~13s) → her biri kendi bağlantısı + paralel (B-49 deseni).
        // SQL'ler birebir aynı (rakam değişmez); sadece eşzamanlı çalışır → süre ~en yavaş tek sorguya iner.
        async Task<T> Q<T>(Func<System.Data.IDbConnection, Task<T>> fn) { await using var c = await db.OpenAsync(); return await fn(c); }

        // Toplam envanter değeri (Ort.Maliyet, son snapshot, Dergi/Sınav hariç)
        var tToplam = Q(c => c.ExecuteScalarAsync<decimal?>($"""
            SELECT CAST(SUM([FSM Stok Maliyet]+[Özlüce Stok Maliyet]+[İst.Yolu Stok Maliyet]+[Merkez Depo Stok Maliyet]) AS decimal(18,0))
            FROM DerinSISBkm.bkm.ENVANTER_RAPORU WITH(NOLOCK)
            WHERE Tarih=(SELECT MAX(Tarih) FROM DerinSISBkm.bkm.ENVANTER_RAPORU) AND [Maliyet Tipi]='Ort.Maliyet' AND KTGR3 NOT IN {EXC};
            """));

        // Devir/WoS/sell-through/stok ₺ (irsHrk satış+gelen + ENVANTER snapshot başı/sonu ort. adet)
        var tEv = Q(c => c.QueryAsync<(string K, decimal Sat, decimal Gel, decimal BA, decimal EA, decimal BM, decimal EM)>($"""
            SELECT m.K, m.Sat, m.Gel, ISNULL(b.A,0) BA, ISNULL(e.A,0) EA, ISNULL(b.M,0) BM, ISNULL(e.M,0) EM
            FROM (SELECT CAST(k.ktgrAd AS nvarchar(50)) K, -SUM(CASE WHEN h.ehTip IN (4,100,3,5,101) THEN h.ehAdetN ELSE 0 END) Sat,
                         SUM(CASE WHEN h.ehTip IN (10,13) THEN h.ehAdetN ELSE 0 END) Gel
                  FROM DerinSISBkm.dbo.irsHrk h WITH(NOLOCK)
                  JOIN DerinSISBkm.dbo.urn u ON u.stkID=h.ehstkID JOIN DerinSISBkm.dbo.urnKtgr2 k ON k.ktgrID=u.urnKtgr2ID
                  WHERE h.ehTrhS>=@ayBas AND h.ehTrhS<@aySon AND h.ehMekan IN (1,4477,4478) AND h.ehAltDepo=0 AND h.ehTip IN (4,100,10,13,3,5,101)
                  GROUP BY CAST(k.ktgrAd AS nvarchar(50))) m
            LEFT JOIN (SELECT KTGR3 K, SUM(ISNULL([Fsm Stok Adet],0)+ISNULL([Özlüce Stok Adet],0)+ISNULL([İst.Yolu Stok Adet],0)) A,
                              SUM(ISNULL([FSM Stok Maliyet],0)+ISNULL([Özlüce Stok Maliyet],0)+ISNULL([İst.Yolu Stok Maliyet],0)) M
                       FROM DerinSISBkm.bkm.ENVANTER_RAPORU WITH(NOLOCK) WHERE CAST(Tarih AS date)=@snapBas AND [Maliyet Tipi]='Ort.Maliyet' GROUP BY KTGR3) b
                   ON b.K COLLATE Turkish_CI_AS=m.K COLLATE Turkish_CI_AS
            LEFT JOIN (SELECT KTGR3 K, SUM(ISNULL([Fsm Stok Adet],0)+ISNULL([Özlüce Stok Adet],0)+ISNULL([İst.Yolu Stok Adet],0)) A,
                              SUM(ISNULL([FSM Stok Maliyet],0)+ISNULL([Özlüce Stok Maliyet],0)+ISNULL([İst.Yolu Stok Maliyet],0)) M
                       FROM DerinSISBkm.bkm.ENVANTER_RAPORU WITH(NOLOCK) WHERE CAST(Tarih AS date)=@snapSon AND [Maliyet Tipi]='Ort.Maliyet' GROUP BY KTGR3) e
                   ON e.K COLLATE Turkish_CI_AS=m.K COLLATE Turkish_CI_AS
            WHERE m.K NOT IN {EXC};
            """, p));

        // ABC (Pareto) — geçen ay ürün cirosu kümülatif
        var tAbc = Q(c => c.QueryAsync<AbcClass>($"""
            SELECT Sinif, COUNT(*) AS Adet, CAST(SUM(Ciro) AS decimal(18,0)) AS Ciro FROM (
              SELECT ProductsId, Ciro, 100.0*SUM(Ciro) OVER(ORDER BY Ciro DESC ROWS UNBOUNDED PRECEDING)/SUM(Ciro) OVER() KP FROM (
                SELECT sp.ProductsId, SUM(sp.TotalPrice-sp.VatTotal) Ciro FROM EncoreMerkez.dbo.SalesProducts sp WITH(NOLOCK)
                JOIN EncoreMerkez.dbo.Sales s ON s.Id=sp.SalesId
                WHERE sp.IsValid=1 AND sp.BarcodeNo<>'1001' AND s.Date>=@ayBas AND s.Date<@aySon AND s.DocumentsTypeId IN (1,2,6,7,8)
                GROUP BY sp.ProductsId HAVING SUM(sp.TotalPrice-sp.VatTotal)>0) p) r
            CROSS APPLY (SELECT CASE WHEN KP<=80 THEN 'A' WHEN KP<=95 THEN 'B' ELSE 'C' END Sinif) x GROUP BY Sinif;
            """, p));

        // Marka/yayınevi top 20 (irsHrk stkID, geçen ay)
        var tMarka = Q(c => c.QueryAsync<MarkaRow>("""
            SELECT TOP 20 CAST(mrk.mrkAd AS nvarchar(80)) AS Ad,
                   CAST(SUM(CASE WHEN h.ehTip IN(4,100) THEN h.ehTutarN WHEN h.ehTip IN(3,5,101) THEN -h.ehTutarN ELSE 0 END) AS decimal(18,0)) AS Ciro,
                   CAST(-SUM(CASE WHEN h.ehTip IN(4,100,3,5,101) THEN h.ehAdetN ELSE 0 END) AS int) AS Adet,
                   COUNT(DISTINCT h.ehstkID) AS Cesit
            FROM DerinSISBkm.dbo.irsHrk h WITH(NOLOCK)
            JOIN DerinSISBkm.dbo.urn u ON u.stkID=h.ehstkID JOIN DerinSISBkm.dbo.urnMrk mrk ON mrk.mrkID=u.urnMrkID
            WHERE h.ehTrhS>=@ayBas AND h.ehTrhS<@aySon AND h.ehMekan IN (1,4477,4478) AND h.ehAltDepo=0 AND h.ehTip IN (4,100,3,5,101)
            GROUP BY CAST(mrk.mrkAd AS nvarchar(80)) ORDER BY Ciro DESC;
            """, p));

        // Stockout (E8) — son 30g talepli SKU, bakiye<=0 oranı. (pre-agg denendi 16.06: ~1s, kazanç yok → CROSS APPLY kaldı.)
        var tStockout = Q(c => c.QueryAsync<StockoutRow>("""
            SELECT x.Kategori, COUNT(*) AS Cesit, SUM(CASE WHEN x.Bakiye<=0 THEN 1 ELSE 0 END) AS Yok,
                   CAST(100.0*SUM(CASE WHEN x.Bakiye<=0 THEN 1 ELSE 0 END)/NULLIF(COUNT(*),0) AS decimal(10,1)) AS Pct
            FROM (SELECT k.ktgrAd Kategori, sold.stkID, bal.Bakiye
              FROM (SELECT DISTINCT h.ehstkID stkID FROM DerinSISBkm.dbo.irsHrk h WITH(NOLOCK)
                    WHERE h.ehTip IN (4,100) AND h.ehTrhS>=DATEADD(DAY,-30,GETDATE()) AND h.ehMekan IN (1,4477,4478) AND h.ehAltDepo=0) sold
              JOIN DerinSISBkm.dbo.urn u WITH(NOLOCK) ON u.stkID=sold.stkID
              JOIN DerinSISBkm.dbo.urnKtgr2 k WITH(NOLOCK) ON k.ktgrID=u.urnKtgr2ID
              CROSS APPLY (SELECT SUM(b.ehAdetN) Bakiye FROM DerinSISBkm.dbo.irsHrk b WITH(NOLOCK)
                           WHERE b.ehstkID=sold.stkID AND b.ehMekan IN (1,4477,4478) AND b.ehAltDepo=0) bal
              WHERE k.ktgrAd NOT IN (N'Sınav Okulları',N'Dergi',N'Genel',N'Tanımsız',N'Etkinlik',N'Hediye Çeki')) x
            GROUP BY x.Kategori;
            """));

        await Task.WhenAll(tToplam, tEv, tAbc, tMarka, tStockout);

        var toplam = (await tToplam) ?? 0m;
        var devir = new List<DevirRow>();
        foreach (var r in await tEv)
        {
            var ort = (r.BA + r.EA) / 2;
            if (ort <= 0) continue;
            var stl = (r.BM + r.EM) / 2;
            decimal? wos = r.Sat > 0 ? Math.Round(ort * 52 / 12 / r.Sat, 1) : null;
            decimal? st = (r.BA + r.Gel) > 0 ? Math.Round(100 * r.Sat / (r.BA + r.Gel), 1) : null;
            devir.Add(new DevirRow(r.K, Math.Round(12 * r.Sat / ort, 2), wos, st, Math.Round(stl), (int)Math.Round(r.Sat)));
        }
        var abc = (await tAbc).OrderBy(a => a.Sinif).ToList();
        var marka = (await tMarka).ToList();
        var stockout = (await tStockout).OrderByDescending(s => s.Pct).ToList();

        return new InventoryData(toplam, devir.OrderByDescending(d => d.Devir).ToList(), abc, marka, stockout);
    }

    // Segment whitelist (RFM drill) — yalnız bu değerler SQL HAVING koşuluna map'lenir (injection yok)
    static readonly Dictionary<string, string> YkCond = new()
    {
        ["1-Şampiyon"] = "COUNT(*)>=8 AND DATEDIFF(DAY,MAX(s.Date),@dun)<=30",
        ["2-Sadık"] = "COUNT(*)>=4 AND DATEDIFF(DAY,MAX(s.Date),@dun)<=90",
        ["3-Yeni"] = "COUNT(*)<=2 AND DATEDIFF(DAY,MAX(s.Date),@dun)<=30",
        ["4-Risk"] = "DATEDIFF(DAY,MAX(s.Date),@dun) BETWEEN 91 AND 180",
        ["5-Kayıp"] = "DATEDIFF(DAY,MAX(s.Date),@dun)>180",
    };
    static readonly Dictionary<string, string> EtCond = new()
    {
        ["1-Şampiyon"] = "COUNT(*)>=5 AND DATEDIFF(DAY,MAX(o.ORDERDATE),@dun)<=30",
        ["2-Sadık"] = "COUNT(*)>=3 AND DATEDIFF(DAY,MAX(o.ORDERDATE),@dun)<=90",
        ["3-Yeni"] = "COUNT(*)<=2 AND DATEDIFF(DAY,MAX(o.ORDERDATE),@dun)<=30",
        ["4-Risk"] = "DATEDIFF(DAY,MAX(o.ORDERDATE),@dun) BETWEEN 91 AND 180",
        ["5-Kayıp"] = "DATEDIFF(DAY,MAX(o.ORDERDATE),@dun)>180",
    };

    /// <summary>RFM drill (yazarkasa) — segment → top 100 müşteri. ic=true → iç/mağaza kartları dahil.</summary>
    public async Task<IReadOnlyList<CustomerRow>> GetYkCustomersAsync(string seg, DateOnly dun, bool ic = false)
    {
        if (!YkCond.TryGetValue(seg, out var cond)) return [];
        await using var conn = await db.OpenAsync();
        // ic=false → iç-kart tek kanonik filtre (plan-18); ic=true → dahil (drill "iç kartları göster")
        var icIds = icKart.Idler();
        var filt = ic ? "" : IcKartFiltre.Sql("s.CustomersId", icIds.Length > 0);
        var sql = $"""
            SELECT TOP 100 s.CustomersId AS Id,
                MAX(CAST(ISNULL(c.Name, s.CustomerCardNo) AS nvarchar(60))) AS Ad,
                MAX(CAST(c.PhoneNumber AS nvarchar(15))) AS Tel,
                COUNT(*) AS Frq, CAST(SUM(s.GrossTotal-s.DiscountTotal-s.VatTotal) AS decimal(18,0)) AS Mon,
                DATEDIFF(DAY,MAX(s.Date),@dun) AS Rec
            FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
            LEFT JOIN DerinCrm.dbo.Customer c WITH(NOLOCK) ON c.Id=s.CustomersId
            WHERE s.DocumentsTypeId=1 AND s.CustomersId>0 AND s.Date>=DATEADD(DAY,-365,@dun) AND s.Date<DATEADD(DAY,1,@dun){filt}
            GROUP BY s.CustomersId HAVING {cond} ORDER BY Mon DESC;
            """;
        return (await conn.QueryAsync<CustomerRow>(sql, new { dun = dun.ToDateTime(TimeOnly.MinValue), icIds })).ToList();
    }

    /// <summary>RFM drill (e-ticaret JOKER) — segment → top 100 müşteri. ISO tarih.</summary>
    public async Task<IReadOnlyList<CustomerRow>> GetEtCustomersAsync(string seg, DateOnly dun)
    {
        if (!EtCond.TryGetValue(seg, out var cond)) return [];
        await using var conn = await db.OpenJokerAsync();  // DİREKT JOKER (linked değil) — detay net hızlı. plan-16.
        var sql = $"""
            SELECT TOP 100 oc.CUSTOMERREF AS Id, MAX(CAST(oc.CMAIL AS nvarchar(80))) AS Ad,
                MAX(CAST(oc.CPHONE AS nvarchar(30))) AS Tel,
                COUNT(*) AS Frq,
                CAST(SUM(ISNULL(det.net,0)) AS decimal(18,0)) AS Mon,
                DATEDIFF(DAY,MAX(o.ORDERDATE),@dun) AS Rec
            FROM dbo.J_ORDERS o
            JOIN dbo.J_ORDER_CLIENTS oc ON oc.LOGICALREF=o.CLIENTREF
            CROSS APPLY (SELECT SUM(d.QUANTITY*d.SELLINGPRICEWITHOUTVAT) AS net FROM dbo.J_ORDER_DETAILS d WHERE d.ORDERREF=o.ORDERID) det
            WHERE o.ORDERDATE>=@bas AND o.ORDERDATE<@g2 AND oc.CUSTOMERREF>0
            GROUP BY oc.CUSTOMERREF HAVING {cond} ORDER BY Mon DESC;
            """;
        return (await conn.QueryAsync<CustomerRow>(sql,
            new { dun = dun.ToString("yyyyMMdd"), bas = dun.AddDays(-365).ToString("yyyyMMdd"), g2 = dun.AddDays(1).ToString("yyyyMMdd") })).ToList();
    }

    /// <summary>Müşteri istatistik (plan-17): aylık yeni müşteri kazanımı (13 ay) + mağaza kart-fiş oranı (30g). İç kartlar hariç.</summary>
    public async Task<MusteriStat> GetMusteriStatAsync(DateOnly dun)
    {
        await using var conn = await db.OpenAsync();
        var icIds = icKart.Idler();
        var filt = IcKartFiltre.Sql("s.CustomersId", icIds.Length > 0);   // tek kanonik iç-kart filtresi (plan-18: isim+tel+elle)
        // Yeni müşteri = ilk fiş tarihi o ayda. İç/mağaza kartı hariç (kanonik filtre).
        var kazSql = $"""
            SELECT LEFT(CONVERT(varchar,ilk.IlkTarih,23),7) AS Ay, COUNT(*) AS Yeni
            FROM (SELECT s.CustomersId, MIN(s.Date) AS IlkTarih
                  FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
                  WHERE s.DocumentsTypeId=1 AND s.CustomersId>0{filt}
                  GROUP BY s.CustomersId) ilk
            WHERE ilk.IlkTarih >= DATEADD(MONTH,-12,@aybas)
            GROUP BY LEFT(CONVERT(varchar,ilk.IlkTarih,23),7);
            """;
        var aybas = new DateOnly(dun.Year, dun.Month, 1).ToDateTime(TimeOnly.MinValue);
        var kaz = (await conn.QueryAsync<MusteriKazanim>(kazSql, new { aybas, icIds }))
            .OrderBy(k => k.Ay).ToList();

        // Mağaza kart-fiş oranı (son 30g): kaç fiş, kaçı gerçek müşteri-kartlı (iç kart kanonik filtre ile düşülür).
        // NOT: filtre SUM(CASE) içinde → subquery YASAK (SQL), Customer-join'li kolon-form (SqlCols) kullanılır.
        var kartSql = $"""
            SELECT CAST(st.Name AS nvarchar(30)) AS Magaza, COUNT(*) AS Fis,
                   SUM(CASE WHEN s.CustomersId>0{IcKartFiltre.SqlCols("c", "s", icIds.Length > 0)} THEN 1 ELSE 0 END) AS Kartli
            FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
            JOIN EncoreMerkez.dbo.Stores st ON st.Id=s.StoresId
            LEFT JOIN DerinCrm.dbo.Customer c WITH(NOLOCK) ON c.Id=s.CustomersId
            WHERE s.DocumentsTypeId = 1 AND s.Date>=DATEADD(DAY,-30,@dun) AND s.Date<@dun2
            GROUP BY CAST(st.Name AS nvarchar(30));
            """;
        var dun2 = dun.AddDays(1).ToDateTime(TimeOnly.MinValue);
        var kartRaw = (await conn.QueryAsync<(string Magaza, int Fis, int Kartli)>(kartSql,
            new { dun = dun.ToDateTime(TimeOnly.MinValue), dun2, icIds })).ToList();
        var kart = kartRaw.Select(r => new MagazaKart(r.Magaza, r.Fis, r.Kartli,
            r.Fis > 0 ? Math.Round(100m * r.Kartli / r.Fis, 1) : 0)).OrderByDescending(k => k.Fis).ToList();

        return new MusteriStat(kaz, kart, kart.Sum(k => k.Fis), kart.Sum(k => k.Kartli));
    }

    /// <summary>Kart oranı drill (R-2): farklı pencere (gun=7/30/90) için mağaza bazlı kartlı-fiş oranı. İç kart kanonik filtre.</summary>
    public async Task<IReadOnlyList<MagazaKart>> GetKartOranAsync(DateOnly dun, int gun)
    {
        await using var conn = await db.OpenAsync();
        var icIds = icKart.Idler();
        var kartSql = $"""
            SELECT CAST(st.Name AS nvarchar(30)) AS Magaza, COUNT(*) AS Fis,
                   SUM(CASE WHEN s.CustomersId>0{IcKartFiltre.SqlCols("c", "s", icIds.Length > 0)} THEN 1 ELSE 0 END) AS Kartli
            FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
            JOIN EncoreMerkez.dbo.Stores st ON st.Id=s.StoresId
            LEFT JOIN DerinCrm.dbo.Customer c WITH(NOLOCK) ON c.Id=s.CustomersId
            WHERE s.DocumentsTypeId = 1 AND s.Date>=DATEADD(DAY,-@gun,@dun) AND s.Date<@dun2
            GROUP BY CAST(st.Name AS nvarchar(30));
            """;
        var dun2 = dun.AddDays(1).ToDateTime(TimeOnly.MinValue);
        var raw = (await conn.QueryAsync<(string Magaza, int Fis, int Kartli)>(kartSql,
            new { gun, dun = dun.ToDateTime(TimeOnly.MinValue), dun2, icIds })).ToList();
        return raw.Select(r => new MagazaKart(r.Magaza, r.Fis, r.Kartli,
            r.Fis > 0 ? Math.Round(100m * r.Kartli / r.Fis, 1) : 0)).OrderByDescending(k => k.Fis).ToList();
    }

    /// <summary>Kazanım drill (R-1): ay="2025-06" formatında → o ayda ilk kez alışveriş yapan müşteriler (Top 200, iç kart hariç).</summary>
    public async Task<IReadOnlyList<KazanimDetayRow>> GetKazanimDetayAsync(string ay)
    {
        await using var conn = await db.OpenAsync();
        var icIds = icKart.Idler();
        var filt = IcKartFiltre.Sql("s.CustomersId", icIds.Length > 0);
        var sql = $"""
            SELECT TOP 200
                ISNULL(c.Name, '') AS Ad,
                ISNULL(c.PhoneNumber, '') AS Tel,
                CONVERT(varchar, ilk.IlkTarih, 104) AS IlkTarih,
                CAST((SELECT TOP 1 s2.GrossTotal - s2.DiscountTotal - s2.VatTotal
                      FROM EncoreMerkez.dbo.Sales s2 WITH(NOLOCK)
                      WHERE s2.CustomersId = ilk.CustomersId
                        AND CONVERT(date, s2.Date) = CONVERT(date, ilk.IlkTarih)
                        AND s2.DocumentsTypeId = 1
                      ORDER BY s2.Id) AS decimal(18,0)) AS IlkTutar
            FROM (
                SELECT s.CustomersId, MIN(s.Date) AS IlkTarih
                FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
                WHERE s.DocumentsTypeId = 1 AND s.CustomersId > 0{filt}
                GROUP BY s.CustomersId
                HAVING LEFT(CONVERT(varchar, MIN(s.Date), 23), 7) = @ay
            ) ilk
            LEFT JOIN DerinCrm.dbo.Customer c WITH(NOLOCK) ON c.Id = ilk.CustomersId
            ORDER BY ilk.IlkTarih DESC;
            """;
        return (await conn.QueryAsync<KazanimDetayRow>(sql, new { ay, icIds })).ToList();
    }

    /// <summary>Drill katman 3: müşteri → fiş/sipariş listesi (son 365g, top 100). Tutar KDV-hariç. plan-17 (Python HAR_YK/HAR_ET portu).</summary>
    public async Task<IReadOnlyList<FisRow>> GetFislerAsync(string kanal, long id)
    {
        if (kanal == "et")
        {
            await using var jc = await db.OpenJokerAsync();  // direkt JOKER
            const string et = """
                SELECT TOP 100 CONVERT(varchar,o.ORDERDATE,104) AS Tarih, CAST(o.ORDERID AS varchar) AS [Ref],
                    ISNULL((SELECT COUNT(*) FROM dbo.J_ORDER_DETAILS d WHERE d.ORDERREF=o.ORDERID),0) AS Kalem,
                    CAST(ISNULL((SELECT SUM(d.QUANTITY*d.SELLINGPRICEWITHOUTVAT) FROM dbo.J_ORDER_DETAILS d WHERE d.ORDERREF=o.ORDERID),0) AS decimal(18,0)) AS Tutar
                FROM dbo.J_ORDERS o JOIN dbo.J_ORDER_CLIENTS oc ON oc.LOGICALREF=o.CLIENTREF
                WHERE oc.CUSTOMERREF=@id ORDER BY o.ORDERDATE DESC;
                """;
            return (await jc.QueryAsync<FisRow>(et, new { id })).ToList();
        }
        await using var conn = await db.OpenAsync();
        // Fiş-bazlı (1,3) + iade sign'lı — müşteri raporu evreniyle tutarlı (sql-server-conventions § fiş bazlı).
        const string yk = """
            SELECT TOP 100 CONVERT(varchar,s.Date,104) AS Tarih, CAST(s.Id AS varchar) AS [Ref],
                (SELECT COUNT(*) FROM EncoreMerkez.dbo.SalesProducts sp WITH(NOLOCK) WHERE sp.SalesId=s.Id AND sp.IsValid=1) AS Kalem,
                CAST(CASE WHEN s.DocumentsTypeId=3 THEN -(s.GrossTotal-s.DiscountTotal-s.VatTotal) ELSE s.GrossTotal-s.DiscountTotal-s.VatTotal END AS decimal(18,0)) AS Tutar
            FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
            WHERE s.CustomersId=@id AND s.DocumentsTypeId IN (1,3) AND s.Date>=DATEADD(DAY,-365,GETDATE())
            ORDER BY s.Date DESC;
            """;
        return (await conn.QueryAsync<FisRow>(yk, new { id })).ToList();
    }

    /// <summary>Drill katman 4: fiş/sipariş içeriği (ürün/adet/birim/net, KDV-hariç). plan-17 (Python FIS_YK/FIS_ET portu).</summary>
    public async Task<IReadOnlyList<FisIcerikRow>> GetFisIcerikAsync(string kanal, long fis)
    {
        if (kanal == "et")
        {
            await using var jc = await db.OpenJokerAsync();
            // Net = KDV-hariç (SELLINGPRICEWITHOUTVAT). Brüt = liste KDV-hariç (gross/(1+VAT/100)). İndirim = Brüt−Net.
            const string et = """
                SELECT TOP 200 CAST(it.NAME AS nvarchar(60)) AS Ad, d.QUANTITY AS Adet,
                    CAST(d.QUANTITY*d.SELLINGPRICEWITHOUTDISCOUNT/(1+d.VAT/100.0) AS decimal(18,2)) AS Brut,
                    CAST(d.QUANTITY*(d.SELLINGPRICEWITHOUTDISCOUNT/(1+d.VAT/100.0) - d.SELLINGPRICEWITHOUTVAT) AS decimal(18,2)) AS Indirim,
                    CAST(d.QUANTITY*d.SELLINGPRICEWITHOUTVAT AS decimal(18,2)) AS Net,
                    CAST(NULL AS nvarchar(50)) AS Kampanya
                FROM dbo.J_ORDER_DETAILS d JOIN dbo.J_ITEMS it ON it.LOGICALREF=d.ITEMREF
                WHERE d.ORDERREF=@fis;
                """;
            return (await jc.QueryAsync<FisIcerikRow>(et, new { fis })).ToList();
        }
        await using var conn = await db.OpenAsync();
        // Net = KDV-hariç (TotalPrice−VatTotal). İndirim = DiscountTotalDirect (KDV-dahil baz; kitap %0'da tam, %20'de yaklaşık). Brüt = Net+İndirim.
        const string yk = """
            SELECT TOP 200 CAST(pr.Name AS nvarchar(60)) AS Ad, CAST(sp.Amount AS decimal(18,2)) AS Adet,
                CAST(sp.TotalPrice-sp.VatTotal+sp.DiscountTotalDirect AS decimal(18,2)) AS Brut,
                CAST(sp.DiscountTotalDirect AS decimal(18,2)) AS Indirim,
                CAST(sp.TotalPrice-sp.VatTotal AS decimal(18,2)) AS Net,
                (SELECT TOP 1 CAST(spc.CampaignName AS nvarchar(50)) FROM EncoreMerkez.dbo.SalesProductCampaigns spc WITH(NOLOCK)
                 WHERE spc.SalesId=sp.SalesId AND spc.ProductSequence=sp.Sequence AND LTRIM(RTRIM(spc.CampaignName))<>'') AS Kampanya
            FROM EncoreMerkez.dbo.SalesProducts sp WITH(NOLOCK)
            JOIN EncoreMerkez.dbo.Products pr WITH(NOLOCK) ON pr.Id=sp.ProductsId
            WHERE sp.SalesId=@fis AND sp.IsValid=1 AND sp.BarcodeNo<>'1001';
            """;
        return (await conn.QueryAsync<FisIcerikRow>(yk, new { fis })).ToList();
    }

}
