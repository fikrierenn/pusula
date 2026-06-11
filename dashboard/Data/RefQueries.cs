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
}
