using Dapper;
using GmDashboard.Models;

namespace GmDashboard.Data;

/// <summary>
/// Referans paneller (envanter + müşteri). Aylık/365g sabit pencere. SQL Python gm_dashboard.py'den port.
/// </summary>
public sealed class RefQueries(Db db)
{
    /// <summary>RFM müşteri segmenti — yazarkasa (365g) + e-ticaret. dun = referans gün.</summary>
    public async Task<(IReadOnlyList<RfmSegment> Yazarkasa, IReadOnlyList<RfmSegment> Eticaret)> GetRfmAsync(DateOnly dun)
    {
        await using var conn = await db.OpenAsync();
        var dunDt = dun.ToDateTime(TimeOnly.MinValue);
        var g2Dt = dun.AddDays(1).ToDateTime(TimeOnly.MinValue);

        // Yazarkasa (EncoreMerkez Sales, CustomersId)
        const string ykSql = """
            SELECT seg.S AS Segment, COUNT(*) AS Musteri, SUM(c.Mon) AS Ciro
            FROM (SELECT s.CustomersId, DATEDIFF(DAY,MAX(s.Date),@dun) Rec, COUNT(*) Frq, SUM(s.GrossTotal-s.DiscountTotal) Mon
                  FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
                  WHERE s.DocumentsTypeId=1 AND s.CustomersId>0 AND s.Date>=DATEADD(DAY,-365,@dun) AND s.Date<@g2
                  GROUP BY s.CustomersId) c
            CROSS APPLY (SELECT CAST(CASE WHEN Frq>=8 AND Rec<=30 THEN N'1-Şampiyon' WHEN Frq>=4 AND Rec<=90 THEN N'2-Sadık'
                         WHEN Frq<=2 AND Rec<=30 THEN N'3-Yeni' WHEN Rec BETWEEN 91 AND 180 THEN N'4-Risk'
                         WHEN Rec>180 THEN N'5-Kayıp' ELSE N'6-Diğer' END AS nvarchar(20)) S) seg
            GROUP BY seg.S;
            """;
        var yk = (await conn.QueryAsync<RfmSegment>(ykSql, new { dun = dunDt, g2 = g2Dt }))
            .OrderBy(r => r.Segment).ToList();

        // E-ticaret (JOKER, CUSTOMERREF) — ISO tarih
        const string etSql = """
            SELECT seg.S AS Segment, COUNT(*) AS Musteri, SUM(c.Mon) AS Ciro
            FROM (SELECT oc.CUSTOMERREF, DATEDIFF(DAY,MAX(o.ORDERDATE),@dun) Rec, COUNT(*) Frq, SUM(o.TOTALPRICE) Mon
                  FROM ODAKJOKER.JOKER.dbo.J_ORDERS o
                  JOIN ODAKJOKER.JOKER.dbo.J_ORDER_CLIENTS oc ON oc.LOGICALREF=o.CLIENTREF
                  WHERE o.ORDERDATE>=@bas AND o.ORDERDATE<@g2 AND oc.CUSTOMERREF>0
                  GROUP BY oc.CUSTOMERREF) c
            CROSS APPLY (SELECT CAST(CASE WHEN Frq>=5 AND Rec<=30 THEN N'1-Şampiyon' WHEN Frq>=3 AND Rec<=90 THEN N'2-Sadık'
                         WHEN Frq<=2 AND Rec<=30 THEN N'3-Yeni' WHEN Rec BETWEEN 91 AND 180 THEN N'4-Risk'
                         WHEN Rec>180 THEN N'5-Kayıp' ELSE N'6-Diğer' END AS nvarchar(20)) S) seg
            GROUP BY seg.S;
            """;
        var et = (await conn.QueryAsync<RfmSegment>(etSql,
            new { dun = dun.ToString("yyyyMMdd"), bas = dun.AddDays(-365).ToString("yyyyMMdd"), g2 = dun.AddDays(1).ToString("yyyyMMdd") }))
            .OrderBy(r => r.Segment).ToList();

        return (yk, et);
    }

    // Stok/envanter raporlarında dışlanan kategoriler (sema metrics envanter_exclusions)
    const string EXC = "(N'Sınav Okulları',N'Dergi',N'Genel',N'Tanımsız',N'Etkinlik',N'Hediye Çeki',N'Sınav Kayıt')";

    /// <summary>Envanter sayfası: toplam değer + devir + ABC + marka + stockout. Geçen tam ay penceresi.</summary>
    public async Task<InventoryData> GetInventoryAsync(DateOnly dun)
    {
        await using var conn = await db.OpenAsync();
        var ayBas = new DateOnly(dun.Year, dun.Month, 1).AddMonths(-1);  // geçen ay ilk
        var aySon = new DateOnly(dun.Year, dun.Month, 1);               // bu ay ilk (exclusive)
        var aySonGun = aySon.AddDays(-1);                                // geçen ay son gün (snapshot)
        var p = new
        {
            ayBas = ayBas.ToDateTime(TimeOnly.MinValue),
            aySon = aySon.ToDateTime(TimeOnly.MinValue),
            snapBas = ayBas.ToString("yyyy-MM-dd"),
            snapSon = aySonGun.ToString("yyyy-MM-dd"),
        };

        // Toplam envanter değeri (Ort.Maliyet, son snapshot, Dergi/Sınav hariç)
        var toplam = await conn.ExecuteScalarAsync<decimal?>($"""
            SELECT CAST(SUM([FSM Stok Maliyet]+[Özlüce Stok Maliyet]+[İst.Yolu Stok Maliyet]+[Merkez Depo Stok Maliyet]+[Odak Depo Stok Maliyet]) AS decimal(18,0))
            FROM DerinSISBkm.bkm.ENVANTER_RAPORU WITH(NOLOCK)
            WHERE Tarih=(SELECT MAX(Tarih) FROM DerinSISBkm.bkm.ENVANTER_RAPORU) AND [Maliyet Tipi]='Ort.Maliyet' AND KTGR3 NOT IN {EXC};
            """) ?? 0m;

        // Devir/WoS/sell-through/stok ₺ (irsHrk satış+gelen + ENVANTER snapshot başı/sonu ort. adet)
        var ev = await conn.QueryAsync<(string K, decimal Sat, decimal Gel, decimal BA, decimal EA, decimal BM, decimal EM)>($"""
            SELECT m.K, m.Sat, m.Gel, ISNULL(b.A,0) BA, ISNULL(e.A,0) EA, ISNULL(b.M,0) BM, ISNULL(e.M,0) EM
            FROM (SELECT CAST(k.ktgrAd AS nvarchar(50)) K, -SUM(CASE WHEN h.ehTip IN (4,100) THEN h.ehAdetN ELSE 0 END) Sat,
                         SUM(CASE WHEN h.ehTip IN (10,13) THEN h.ehAdetN ELSE 0 END) Gel
                  FROM DerinSISBkm.dbo.irsHrk h WITH(NOLOCK)
                  JOIN DerinSISBkm.dbo.urn u ON u.stkID=h.ehstkID JOIN DerinSISBkm.dbo.urnKtgr2 k ON k.ktgrID=u.urnKtgr2ID
                  WHERE h.ehTrhS>=@ayBas AND h.ehTrhS<@aySon AND h.ehMekan IN (1,4477,4478) AND h.ehAltDepo=0 AND h.ehTip IN (4,100,10,13)
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
            """, p);
        var devir = new List<DevirRow>();
        foreach (var r in ev)
        {
            var ort = (r.BA + r.EA) / 2;
            if (ort <= 0) continue;
            var stl = (r.BM + r.EM) / 2;
            decimal? wos = r.Sat > 0 ? Math.Round(ort * 52 / 12 / r.Sat, 1) : null;
            decimal? st = (r.BA + r.Gel) > 0 ? Math.Round(100 * r.Sat / (r.BA + r.Gel), 1) : null;
            devir.Add(new DevirRow(r.K, Math.Round(12 * r.Sat / ort, 2), wos, st, Math.Round(stl), (int)Math.Round(r.Sat)));
        }

        // ABC (Pareto) — geçen ay ürün cirosu kümülatif
        var abc = (await conn.QueryAsync<AbcClass>($"""
            SELECT Sinif, COUNT(*) AS Adet, CAST(SUM(Ciro) AS decimal(18,0)) AS Ciro FROM (
              SELECT ProductsId, Ciro, 100.0*SUM(Ciro) OVER(ORDER BY Ciro DESC ROWS UNBOUNDED PRECEDING)/SUM(Ciro) OVER() KP FROM (
                SELECT sp.ProductsId, SUM(sp.TotalPrice) Ciro FROM EncoreMerkez.dbo.SalesProducts sp WITH(NOLOCK)
                JOIN EncoreMerkez.dbo.Sales s ON s.Id=sp.SalesId
                WHERE sp.IsValid=1 AND sp.BarcodeNo<>'1001' AND s.Date>=@ayBas AND s.Date<@aySon AND s.DocumentsTypeId IN (1,2,6,7,8)
                GROUP BY sp.ProductsId HAVING SUM(sp.TotalPrice)>0) p) r
            CROSS APPLY (SELECT CASE WHEN KP<=80 THEN 'A' WHEN KP<=95 THEN 'B' ELSE 'C' END Sinif) x GROUP BY Sinif;
            """, p)).OrderBy(a => a.Sinif).ToList();

        // Marka/yayınevi top 20 (irsHrk stkID, geçen ay)
        var marka = (await conn.QueryAsync<MarkaRow>("""
            SELECT TOP 20 CAST(mrk.mrkAd AS nvarchar(80)) AS Ad,
                   CAST(ABS(SUM(CASE WHEN h.ehTip IN(4,100) THEN h.ehTutarN ELSE 0 END)) AS decimal(18,0)) AS Ciro,
                   CAST(-SUM(CASE WHEN h.ehTip IN(4,100) THEN h.ehAdetN ELSE 0 END) AS int) AS Adet,
                   COUNT(DISTINCT h.ehstkID) AS Cesit
            FROM DerinSISBkm.dbo.irsHrk h WITH(NOLOCK)
            JOIN DerinSISBkm.dbo.urn u ON u.stkID=h.ehstkID JOIN DerinSISBkm.dbo.urnMrk mrk ON mrk.mrkID=u.urnMrkID
            WHERE h.ehTrhS>=@ayBas AND h.ehTrhS<@aySon AND h.ehMekan IN (1,4477,4478) AND h.ehAltDepo=0 AND h.ehTip IN (4,100)
            GROUP BY CAST(mrk.mrkAd AS nvarchar(80)) ORDER BY Ciro DESC;
            """, p)).ToList();

        // Stockout (E8) — son 30g talepli SKU, bakiye<=0 oranı
        var stockout = (await conn.QueryAsync<StockoutRow>("""
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
            """)).OrderByDescending(s => s.Pct).ToList();

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
        // ic=false → 599/699 telefonlu + Mağaza/Kumbara iç kartlarını ayıkla (MUS_YK port)
        var ickart = ic ? "" : """
             AND (c.Id IS NULL OR (c.Name NOT LIKE '%Mağaza%' AND c.Name NOT LIKE '%Kumbara%'
                  AND ISNULL(c.PhoneNumber,'') NOT LIKE '599%' AND ISNULL(c.PhoneNumber,'') NOT LIKE '699%'))
            """;
        var sql = $"""
            SELECT TOP 100 s.CustomersId AS Id,
                MAX(CAST(ISNULL(c.Name, s.CustomerCardNo) AS nvarchar(60))) AS Ad,
                MAX(CAST(c.PhoneNumber AS nvarchar(15))) AS Tel,
                COUNT(*) AS Frq, CAST(SUM(s.GrossTotal-s.DiscountTotal) AS decimal(18,0)) AS Mon,
                DATEDIFF(DAY,MAX(s.Date),@dun) AS Rec
            FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
            LEFT JOIN DerinCrm.dbo.Customer c WITH(NOLOCK) ON c.Id=s.CustomersId
            WHERE s.DocumentsTypeId=1 AND s.CustomersId>0 AND s.Date>=DATEADD(DAY,-365,@dun) AND s.Date<DATEADD(DAY,1,@dun){ickart}
            GROUP BY s.CustomersId HAVING {cond} ORDER BY Mon DESC;
            """;
        return (await conn.QueryAsync<CustomerRow>(sql, new { dun = dun.ToDateTime(TimeOnly.MinValue) })).ToList();
    }

    /// <summary>RFM drill (e-ticaret JOKER) — segment → top 100 müşteri. ISO tarih.</summary>
    public async Task<IReadOnlyList<CustomerRow>> GetEtCustomersAsync(string seg, DateOnly dun)
    {
        if (!EtCond.TryGetValue(seg, out var cond)) return [];
        await using var conn = await db.OpenAsync();
        var sql = $"""
            SELECT TOP 100 oc.CUSTOMERREF AS Id, MAX(CAST(oc.CMAIL AS nvarchar(80))) AS Ad,
                MAX(CAST(oc.CPHONE AS nvarchar(30))) AS Tel,
                COUNT(*) AS Frq, CAST(SUM(o.TOTALPRICE) AS decimal(18,0)) AS Mon,
                DATEDIFF(DAY,MAX(o.ORDERDATE),@dun) AS Rec
            FROM ODAKJOKER.JOKER.dbo.J_ORDERS o
            JOIN ODAKJOKER.JOKER.dbo.J_ORDER_CLIENTS oc ON oc.LOGICALREF=o.CLIENTREF
            WHERE o.ORDERDATE>=@bas AND o.ORDERDATE<@g2 AND oc.CUSTOMERREF>0
            GROUP BY oc.CUSTOMERREF HAVING {cond} ORDER BY Mon DESC;
            """;
        return (await conn.QueryAsync<CustomerRow>(sql,
            new { dun = dun.ToString("yyyyMMdd"), bas = dun.AddDays(-365).ToString("yyyyMMdd"), g2 = dun.AddDays(1).ToString("yyyyMMdd") })).ToList();
    }

    /// <summary>Kategori → ürün drill. Satış/Ciro = SEÇİLİ DÖNEM + mağaza (mekanId=0 → 3 mağaza toplam).
    /// Bakiye = güncel stok (tüm geçmiş hareket toplamı, mağaza bazlı). irsHrk stkID, satış ehTip 4/100.</summary>
    public async Task<IReadOnlyList<UrunRow>> GetUrunlerAsync(string kategori, int mekanId, DateOnly start, DateOnly endExcl)
    {
        await using var conn = await db.OpenAsync();
        // Satış/Ciro CASE'i döneme bağlı; Bakiye WHERE'de tarih yok → tüm geçmiş = güncel stok.
        const string sql = """
            SELECT TOP 100 u.stkKod AS Kod, CAST(u.stkAd AS nvarchar(80)) AS Ad,
                CAST(-SUM(CASE WHEN h.ehTip IN (4,100) AND h.ehTrhS>=@start AND h.ehTrhS<@end THEN h.ehAdetN ELSE 0 END) AS int) AS Satis,
                CAST(ABS(SUM(CASE WHEN h.ehTip IN (4,100) AND h.ehTrhS>=@start AND h.ehTrhS<@end THEN h.ehTutarN ELSE 0 END)) AS decimal(18,0)) AS Ciro,
                CAST(SUM(h.ehAdetN) AS int) AS Bakiye
            FROM DerinSISBkm.dbo.irsHrk h WITH(NOLOCK)
            JOIN DerinSISBkm.dbo.urn u ON u.stkID=h.ehstkID
            JOIN DerinSISBkm.dbo.urnKtgr2 k ON k.ktgrID=u.urnKtgr2ID
            WHERE k.ktgrAd=@kat AND h.ehMekan IN (1,4477,4478) AND (@mekan=0 OR h.ehMekan=@mekan)
                AND h.ehAltDepo=0 AND h.ehstkID IS NOT NULL
            GROUP BY u.stkKod, CAST(u.stkAd AS nvarchar(80))
            HAVING -SUM(CASE WHEN h.ehTip IN (4,100) AND h.ehTrhS>=@start AND h.ehTrhS<@end THEN h.ehAdetN ELSE 0 END)>0
            ORDER BY Satis DESC;
            """;
        return (await conn.QueryAsync<UrunRow>(sql, new
        {
            kat = kategori,
            mekan = mekanId,
            start = start.ToDateTime(TimeOnly.MinValue),
            end = endExcl.ToDateTime(TimeOnly.MinValue),
        })).ToList();
    }

    /// <summary>Ciro-vs-envanter scatter (cve port). Kategori: Mayıs irsHrk ciro vs ENVANTER_RAPORU 3 mağaza değer.</summary>
    public async Task<IReadOnlyList<CveRow>> GetCveAsync(DateOnly dun)
    {
        await using var conn = await db.OpenAsync();
        var ayBas = new DateOnly(dun.Year, dun.Month, 1).AddMonths(-1);
        var aySon = new DateOnly(dun.Year, dun.Month, 1);
        var p = new { ayBas = ayBas.ToDateTime(TimeOnly.MinValue), aySon = aySon.ToDateTime(TimeOnly.MinValue) };

        // Ciro (irsHrk, geçen ay, 3 mağaza) — envanterle aynı stkID kaynağı
        var ciro = (await conn.QueryAsync<(string K, decimal Ciro)>($"""
            SELECT CAST(k.ktgrAd AS nvarchar(50)) K,
                   CAST(ABS(SUM(CASE WHEN h.ehTip IN (4,100) THEN h.ehTutarN ELSE 0 END)) AS decimal(18,0)) Ciro
            FROM DerinSISBkm.dbo.irsHrk h WITH(NOLOCK)
            JOIN DerinSISBkm.dbo.urn u ON u.stkID=h.ehstkID JOIN DerinSISBkm.dbo.urnKtgr2 k ON k.ktgrID=u.urnKtgr2ID
            WHERE h.ehTrhS>=@ayBas AND h.ehTrhS<@aySon AND h.ehMekan IN (1,4477,4478) AND h.ehAltDepo=0 AND h.ehTip IN (4,100)
                  AND k.ktgrAd NOT IN {EXC}
            GROUP BY CAST(k.ktgrAd AS nvarchar(50));
            """, p)).ToDictionary(x => x.K, x => x.Ciro, StringComparer.OrdinalIgnoreCase);

        // Envanter değeri (son snapshot, 3 mağaza)
        var env = (await conn.QueryAsync<(string K, decimal V)>($"""
            SELECT CAST(KTGR3 AS nvarchar(50)) K,
                   CAST(SUM([FSM Stok Maliyet]+[Özlüce Stok Maliyet]+[İst.Yolu Stok Maliyet]) AS decimal(18,0)) V
            FROM DerinSISBkm.bkm.ENVANTER_RAPORU WITH(NOLOCK)
            WHERE Tarih=(SELECT MAX(Tarih) FROM DerinSISBkm.bkm.ENVANTER_RAPORU) AND [Maliyet Tipi]='Ort.Maliyet' AND KTGR3 NOT IN {EXC}
            GROUP BY CAST(KTGR3 AS nvarchar(50));
            """)).ToList();

        var rows = new List<CveRow>();
        foreach (var e in env)
        {
            var c = ciro.GetValueOrDefault(e.K, 0m);
            if (e.V > 0 || c > 0) rows.Add(new CveRow(e.K, c, e.V));
        }
        return rows.OrderByDescending(r => r.Ciro).ToList();
    }

    /// <summary>Operasyon ek: SPLH (PDKS OPENQUERY, son 30g) + COD (olgun 60g pencere).</summary>
    public async Task<OpsData> GetOpsAsync(DateOnly dun)
    {
        await using var conn = await db.OpenAsync();
        var d30 = dun.AddDays(-29).ToString("yyyyMMdd");
        var g2iso = dun.AddDays(1).ToString("yyyyMMdd");

        // SPLH — PDKS linked server düşerse boş liste (panel "veri yok" gösterir)
        var splh = new List<SplhRow>();
        try
        {
            var sql = $$"""
                SELECT lab.Magaza, cir.NetCiro, cir.Fis, lab.CalisilanSaat AS Saat, lab.Personel
                FROM (SELECT Magaza, CalisilanSaat, Personel FROM OPENQUERY([PDKS], '
                    SELECT LTRIM(RTRIM(p.Per_Grp2)) AS Magaza,
                      CAST(SUM(DATEDIFF(MINUTE, z.TZe_VonZeit, z.TZe_BisZeit))/60.0 AS decimal(18,1)) AS CalisilanSaat,
                      COUNT(DISTINCT z.TZe_PersNr) AS Personel
                    FROM TTagZei z INNER JOIN TPerTab p ON p.Per_PersNr = z.TZe_PersNr
                    WHERE z.TZe_Datum >= ''{{d30}}'' AND z.TZe_Datum <= ''{{g2iso}}''
                      AND p.Per_Grp1 = ''MAĞAZALAR'' AND LTRIM(RTRIM(p.Per_Grp2)) IN (''FSM'',''ÖZLÜCE'',''İST.YOLU'')
                      AND z.TZe_VonZeit IS NOT NULL AND z.TZe_BisZeit IS NOT NULL
                    GROUP BY LTRIM(RTRIM(p.Per_Grp2))')) lab
                JOIN (SELECT CASE MG.mekanID WHEN 1 THEN N'FSM' WHEN 4477 THEN N'ÖZLÜCE' WHEN 4478 THEN N'İST.YOLU' END Magaza,
                    SUM(IIF(s.DocumentsTypeId=3,-1,1)*(s.GrossTotal-s.DiscountTotal)) NetCiro, SUM(IIF(s.DocumentsTypeId=3,-1,1)) Fis
                  FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
                  JOIN EncoreMerkez.dbo.Pos p WITH(NOLOCK) ON p.Id=s.PosId
                  JOIN EncoreMerkez.dbo.Stores st WITH(NOLOCK) ON st.Id=p.StoreId
                  JOIN DerinSISBkm.dbo.posMagaza MG WITH(NOLOCK) ON MG.mekanKod COLLATE Turkish_CI_AS=st.Code COLLATE Turkish_CI_AS
                  LEFT JOIN EncoreMerkez.dbo.SalesProducts spb WITH(NOLOCK) ON spb.SalesId=s.Id AND spb.BarcodeNo='1001'
                  WHERE s.DocumentsTypeId IN (1,2,3,6,7,8) AND s.Date>='{{d30}}' AND s.Date<'{{g2iso}}' AND spb.Id IS NULL
                  GROUP BY MG.mekanID) cir ON cir.Magaza COLLATE Turkish_CI_AS=lab.Magaza COLLATE Turkish_CI_AS;
                """;
            splh = (await conn.QueryAsync<SplhRow>(sql)).OrderByDescending(s => s.Saat > 0 ? s.NetCiro / s.Saat : 0).ToList();
        }
        catch { /* PDKS linked server yoksa panel boş */ }

        // COD — olgun pencere (75→15 gün önce; son 15 gün kargo süreci bitmemiş hariç)
        var codB = dun.AddDays(-75).ToString("yyyyMMdd");
        var codE = dun.AddDays(-15).ToString("yyyyMMdd");
        var cod = (await conn.QueryAsync<CodRow>("""
            SELECT CASE WHEN o.PAYDEFREF=-3 THEN 'COD' ELSE 'Online' END AS Tip, COUNT(*) AS Siparis,
                   SUM(CASE WHEN o.CARGODELIVERYSTATUS=1 THEN 1 ELSE 0 END) AS Teslim,
                   SUM(CASE WHEN o.CARGODELIVERYSTATUS=2 THEN 1 ELSE 0 END) AS Iade
            FROM ODAKJOKER.JOKER.dbo.J_ORDERS o
            WHERE o.PAYDEFREF IN (-3,-13) AND o.ORDERDATE>=@b AND o.ORDERDATE<@e
            GROUP BY CASE WHEN o.PAYDEFREF=-3 THEN 'COD' ELSE 'Online' END;
            """, new { b = codB, e = codE })).ToList();
        var zarar = await conn.ExecuteScalarAsync<decimal?>("""
            SELECT CAST(SUM(o.CARGOPRICE)*2 AS decimal(18,0)) FROM ODAKJOKER.JOKER.dbo.J_ORDERS o
            WHERE o.PAYDEFREF=-3 AND o.CARGODELIVERYSTATUS=2 AND o.ORDERDATE>=@b AND o.ORDERDATE<@e;
            """, new { b = codB, e = codE }) ?? 0m;

        return new OpsData(splh, cod, zarar);
    }
}
