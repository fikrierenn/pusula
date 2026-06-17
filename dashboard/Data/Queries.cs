using Dapper;
using GmDashboard.Models;

namespace GmDashboard.Data;

/// <summary>
/// Tüm dashboard sorguları. SQL Python gm_dashboard.py'den birebir port (sema/sql-server-conventions).
/// Tarih param = DMY (SET DATEFORMAT dmy bağlantıda). E-ticaret ISO YYYYMMDD (linked server).
/// </summary>
public sealed class Queries(Db db)
{
    static readonly Dictionary<int, string> Mekan = new() { [1] = "FSM", [4477] = "Özlüce", [4478] = "İst.Yolu" };

    /// <summary>Dönem özeti: mağaza net/fiş/iade + e-ticaret net + hedef gerçekleşme.</summary>
    /// <param name="prevStart">Geçen-dönem (WoW) penceresi başı. null → hemen önceki eş-uzunluk.</param>
    /// <param name="prevEnd">Geçen-dönem penceresi sonu (exclusive). null → start.</param>
    public async Task<PeriodSummary> GetPeriodAsync(DateOnly start, DateOnly endExcl, DateOnly? prevStart = null, DateOnly? prevEnd = null)
    {
        await using var conn = await db.OpenAsync();
        var giso = start.ToString("yyyyMMdd");
        var g2iso = endExcl.ToString("yyyyMMdd");

        // Mağaza (EncoreMerkez Sales → posMagaza; geri dönüşüm fişi BarcodeNo='1001' hariç)
        // Net = KDV-HARİÇ (plan-16): Sales.GrossTotal−DiscountTotal−VatTotal (header VAT = satır TP−VatTotal toplamı, kuruşu kuruşuna doğrulandı 16.06).
        const string storeSql = """
            SELECT MG.mekanID AS MekanId,
                   SUM(CASE WHEN s.DocumentsTypeId=3 THEN -1 ELSE 1 END*(s.GrossTotal-s.DiscountTotal-s.VatTotal)) AS Net,
                   SUM(CASE WHEN s.DocumentsTypeId=3 THEN -1 ELSE 1 END) AS Fis,
                   SUM(CASE WHEN s.DocumentsTypeId=3 THEN (s.GrossTotal-s.DiscountTotal-s.VatTotal) ELSE 0 END) AS Iade
            FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
            JOIN EncoreMerkez.dbo.Pos p ON p.Id=s.PosId
            JOIN EncoreMerkez.dbo.Stores st ON st.Id=p.StoreId
            JOIN DerinSISBkm.dbo.posMagaza MG ON MG.mekanKod COLLATE Turkish_CI_AS = st.Code COLLATE Turkish_CI_AS
            LEFT JOIN EncoreMerkez.dbo.SalesProducts spb ON spb.SalesId=s.Id AND spb.BarcodeNo='1001'
            WHERE s.DocumentsTypeId IN (1,2,3,6,7,8) AND spb.Id IS NULL AND s.Date>=@start AND s.Date<@end
            GROUP BY MG.mekanID;
            """;
        var stores = (await conn.QueryAsync<StoreRow>(storeSql,
            new { start = start.ToDateTime(TimeOnly.MinValue), end = endExcl.ToDateTime(TimeOnly.MinValue) })).ToList();

        // Geçen dönem penceresi — hero + mağaza WoW trendi. Aylık → geçen ayın aynı günleri (Home verir);
        // null → hemen önceki eş-uzunluk. Aynı storeSql, kaydırılmış tarih.
        int len = endExcl.DayNumber - start.DayNumber;
        var pStart = prevStart ?? start.AddDays(-len);
        var pEnd = prevEnd ?? start;
        var prevStores = (await conn.QueryAsync<StoreRow>(storeSql,
            new { start = pStart.ToDateTime(TimeOnly.MinValue), end = pEnd.ToDateTime(TimeOnly.MinValue) })).ToList();
        var prevNetMap = prevStores.ToDictionary(s => s.MekanId, s => s.Net);

        // E-ticaret NET (iptal 1001/3000/4000 + iade 1006 + kayıp 1007 HARİÇ; 3004/3006 NORMAL aşama) — DİREKT JOKER (B-74).
        // Ciro = KDV+KARGO-HARİÇ (plan-16): satır SELLINGPRICEWITHOUTVAT (kargo order-başlığı CARGOPRICE'ta, satırda yok).
        // Eski TOTALPRICE (KDV+kargo dahil) KULLANILMIYOR. Direkt bağlantıda detay CROSS APPLY hızlı (linked değil).
        const string eticSql = """
            SELECT SUM(CASE WHEN o.STATUS NOT IN (1001,1006,1007,3000,4000) THEN 1 ELSE 0 END) AS Sip,
                   SUM(CASE WHEN o.STATUS NOT IN (1001,1006,1007,3000,4000) THEN ISNULL(det.net,0) ELSE 0 END) AS Ciro
            FROM dbo.J_ORDERS o
            CROSS APPLY (SELECT SUM(d.QUANTITY*d.SELLINGPRICEWITHOUTVAT) AS net
                         FROM dbo.J_ORDER_DETAILS d WHERE d.ORDERREF=o.ORDERID) det
            WHERE o.ORDERDATE>=@giso AND o.ORDERDATE<@g2iso;
            """;
        await using var jconn = await db.OpenJokerAsync();
        var etic = await jconn.QuerySingleOrDefaultAsync<(int? Sip, decimal? Ciro)>(eticSql, new { giso, g2iso });
        var eSip = etic.Sip ?? 0;
        var eCiro = etic.Ciro ?? 0m;

        // Geçen dönem e-ticaret net (hero online WoW)
        var prevEtic = await jconn.QuerySingleOrDefaultAsync<(int? Sip, decimal? Ciro)>(eticSql,
            new { giso = pStart.ToString("yyyyMMdd"), g2iso = pEnd.ToString("yyyyMMdd") });
        var prevECiro = prevEtic.Ciro ?? 0m;
        var prevESip = prevEtic.Sip ?? 0;

        // Hedef (MTD) — sadece aylık dönemde dolu; ay başı–bugün
        var ayBas = new DateOnly(start.Year, start.Month, 1);
        const string hedefSql = "SELECT mekanId, SUM(hedef) H FROM BKMDATA.dbo.Hedef WITH(NOLOCK) WHERE mekanId IN (1,4477,4478) AND tarih>=@a AND tarih<@b GROUP BY mekanId;";
        var hedef = (await conn.QueryAsync<(int mekanId, decimal H)>(hedefSql,
            new { a = ayBas.ToDateTime(TimeOnly.MinValue), b = endExcl.ToDateTime(TimeOnly.MinValue) }))
            .ToDictionary(x => x.mekanId, x => x.H);

        // Mağaza × kategori (drill — mağaza kartı tıkla → kategori dağılımı)
        var katPar = new { start = start.ToDateTime(TimeOnly.MinValue), end = endExcl.ToDateTime(TimeOnly.MinValue) };
        const string skatSql = """
            SELECT MG.mekanID AS MekanId, CAST(ktg.ktgrAd AS nvarchar(50)) AS Ad,
                   CAST(SUM(CASE WHEN s.DocumentsTypeId=3 THEN -1 ELSE 1 END*(sp.TotalPrice-sp.VatTotal)) AS decimal(18,0)) AS Ciro
            FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
            JOIN EncoreMerkez.dbo.Pos p ON p.Id=s.PosId JOIN EncoreMerkez.dbo.Stores st ON st.Id=p.StoreId
            JOIN DerinSISBkm.dbo.posMagaza MG ON MG.mekanKod COLLATE Turkish_CI_AS=st.Code COLLATE Turkish_CI_AS
            JOIN EncoreMerkez.dbo.SalesProducts sp WITH(NOLOCK) ON sp.SalesId=s.Id AND sp.IsValid=1 AND sp.BarcodeNo<>'1001'
            JOIN EncoreMerkez.dbo.Products pr WITH(NOLOCK) ON pr.Id=sp.ProductsId
            JOIN DerinSISBkm.dbo.urn u WITH(NOLOCK) ON u.stkID=CONVERT(int,pr.Code)
            JOIN DerinSISBkm.dbo.urnKtgr2 ktg WITH(NOLOCK) ON ktg.ktgrID=u.urnKtgr2ID
            WHERE s.DocumentsTypeId IN (1,2,3,6,7,8) AND ISNUMERIC(pr.Code)=1 AND s.Date>=@start AND s.Date<@end
            GROUP BY MG.mekanID, CAST(ktg.ktgrAd AS nvarchar(50));
            """;
        var skat = (await conn.QueryAsync<(int MekanId, string Ad, decimal Ciro)>(skatSql, katPar)).ToList();
        var skatMap = skat.GroupBy(r => r.MekanId)
            .ToDictionary(g => g.Key, g => (IReadOnlyList<CategorySlice>)g.OrderByDescending(x => x.Ciro)
                .Select(x => new CategorySlice(x.Ad, x.Ciro)).ToList());

        var cards = new List<StoreCard>();
        foreach (var mid in new[] { 4477, 1, 4478 })
        {
            var r = stores.FirstOrDefault(s => s.MekanId == mid);
            var net = r?.Net ?? 0;
            var fis = r?.Fis ?? 0;
            decimal? ger = hedef.TryGetValue(mid, out var h) && h > 0 ? Math.Round(100 * net / h, 1) : null;
            var pn = prevNetMap.GetValueOrDefault(mid, 0);
            decimal? wow = pn > 0 ? Math.Round(100 * (net - pn) / pn, 1) : null;
            cards.Add(new StoreCard(mid, Mekan[mid], net, fis, fis > 0 ? (int)Math.Round(net / fis) : 0, ger, r?.Iade ?? 0,
                skatMap.GetValueOrDefault(mid, []), wow));
        }

        // E-ticaret kanal kırılımı (donut) — DİREKT JOKER, Ciro KDV+kargo-hariç (SELLINGPRICEWITHOUTVAT). plan-16.
        const string eticKanalSql = """
            SELECT CASE WHEN o.APPLICATION IN ('Mobil Uygulama (Android)','Mobil Uygulama (iOS)','Mobil Site','Web Sitesi')
                        THEN o.APPLICATION ELSE 'Diğer' END AS Ad,
                   SUM(CASE WHEN o.STATUS NOT IN (1001,1006,1007,3000,4000) THEN 1 ELSE 0 END) AS Sip,
                   SUM(CASE WHEN o.STATUS IN (1001,1006,1007,3000,4000) THEN 1 ELSE 0 END) AS Ipt,
                   SUM(CASE WHEN o.STATUS NOT IN (1001,1006,1007,3000,4000) THEN ISNULL(det.net,0) ELSE 0 END) AS Ciro
            FROM dbo.J_ORDERS o
            CROSS APPLY (SELECT SUM(d.QUANTITY*d.SELLINGPRICEWITHOUTVAT) AS net FROM dbo.J_ORDER_DETAILS d WHERE d.ORDERREF=o.ORDERID) det
            WHERE o.ORDERDATE>=@giso AND o.ORDERDATE<@g2iso
            GROUP BY CASE WHEN o.APPLICATION IN ('Mobil Uygulama (Android)','Mobil Uygulama (iOS)','Mobil Site','Web Sitesi')
                          THEN o.APPLICATION ELSE 'Diğer' END;
            """;
        var eticKanal = (await jconn.QueryAsync<EticChannel>(eticKanalSql, new { giso, g2iso }))
            .Select(e => e with { Ad = e.Ad.Replace("Mobil Uygulama ", "").Replace("(", "").Replace(")", "") })
            .OrderByDescending(e => e.Ciro).ToList();

        // Kategori mix (mağaza×kategori → toplam; Products.Code=stkID köprüsü, geri dönüşüm hariç)
        const string katSql = """
            SELECT CAST(ktg.ktgrAd AS nvarchar(50)) AS Ad,
                   CAST(SUM(CASE WHEN s.DocumentsTypeId=3 THEN -1 ELSE 1 END*(sp.TotalPrice-sp.VatTotal)) AS decimal(18,0)) AS Ciro
            FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
            JOIN EncoreMerkez.dbo.SalesProducts sp WITH(NOLOCK) ON sp.SalesId=s.Id AND sp.IsValid=1 AND sp.BarcodeNo<>'1001'
            JOIN EncoreMerkez.dbo.Products pr WITH(NOLOCK) ON pr.Id=sp.ProductsId
            JOIN DerinSISBkm.dbo.urn u WITH(NOLOCK) ON u.stkID=CONVERT(int,pr.Code)
            JOIN DerinSISBkm.dbo.urnKtgr2 ktg WITH(NOLOCK) ON ktg.ktgrID=u.urnKtgr2ID
            WHERE s.DocumentsTypeId IN (1,2,3,6,7,8) AND ISNUMERIC(pr.Code)=1 AND s.Date>=@start AND s.Date<@end
            GROUP BY CAST(ktg.ktgrAd AS nvarchar(50));
            """;
        var kategori = (await conn.QueryAsync<CategorySlice>(katSql, katPar))
            .OrderByDescending(k => k.Ciro).Take(8).ToList();

        // Saat bazlı yoğunluk
        const string saatSql = """
            SELECT DATEPART(HOUR,s.Date) AS Saat, SUM(CASE WHEN s.DocumentsTypeId=3 THEN -1 ELSE 1 END) AS Fis,
                   CAST(SUM(CASE WHEN s.DocumentsTypeId=3 THEN -1 ELSE 1 END*(s.GrossTotal-s.DiscountTotal-s.VatTotal)) AS decimal(18,0)) AS Net
            FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
            WHERE s.DocumentsTypeId IN (1,2,3,6,7,8) AND s.Date>=@start AND s.Date<@end
            GROUP BY DATEPART(HOUR,s.Date);
            """;
        var saat = (await conn.QueryAsync<HourBar>(saatSql, katPar)).OrderBy(h => h.Saat).ToList();

        // Kasiyer performansı (mağaza gruplu, grup içi net azalan)
        const string kasSql = """
            SELECT CAST(st.Name AS nvarchar(30)) AS Magaza, CAST(ISNULL(u.Name,'?') AS nvarchar(30)) AS Ad, COUNT(*) AS Fis,
                   CAST(SUM(CASE WHEN s.DocumentsTypeId=3 THEN -(s.GrossTotal-ABS(s.DiscountTotal)-s.VatTotal) ELSE s.GrossTotal-s.DiscountTotal-s.VatTotal END) AS decimal(18,0)) AS Net,
                   SUM(CASE WHEN s.DocumentsTypeId=3 THEN 1 ELSE 0 END) AS Iade
            FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
            JOIN EncoreMerkez.dbo.Stores st ON st.Id=s.StoresId
            LEFT JOIN EncoreMerkez.dbo.Users u ON u.Id=s.UsersId
            WHERE s.DocumentsTypeId IN (1,2,3,6,7,8) AND s.Date>=@start AND s.Date<@end
            GROUP BY CAST(st.Name AS nvarchar(30)), CAST(ISNULL(u.Name,'?') AS nvarchar(30));
            """;
        var kasiyer = (await conn.QueryAsync<(string Magaza, string Ad, int Fis, decimal Net, int Iade)>(kasSql, katPar))
            .Select(k => new KasiyerRow(k.Magaza, k.Ad, k.Fis, k.Net, k.Fis > 0 ? (int)Math.Round(k.Net / k.Fis) : 0, k.Iade))
            .OrderBy(k => k.Magaza).ThenByDescending(k => k.Net).ToList();

        // E-ticaret kargo firma dağılımı (net sipariş, JOKER J_CARGO) — DİREKT JOKER (linked server kaldırıldı, M-12)
        const string kargoSql = """
            SELECT ISNULL(c.CNAME,'(bilinmiyor)') AS Ad, COUNT(*) AS Adet
            FROM dbo.J_ORDERS o
            LEFT JOIN dbo.J_CARGO c ON c.ID=o.CARGOREF
            WHERE o.ORDERDATE>=@giso AND o.ORDERDATE<@g2iso AND o.STATUS NOT IN (1001,1006,1007,3000,4000)
            GROUP BY ISNULL(c.CNAME,'(bilinmiyor)');
            """;
        var kargo = (await jconn.QueryAsync<NameCount>(kargoSql, new { giso, g2iso }))
            .OrderByDescending(k => k.Adet).ToList();

        // E-ticaret il dağılımı (teslimat DCITY, top 12) — DİREKT JOKER (M-12)
        const string ilSql = """
            SELECT ISNULL(d.DCITY,'(bilinmiyor)') AS Ad, COUNT(*) AS Adet
            FROM dbo.J_ORDERS o
            LEFT JOIN dbo.J_ORDER_DELIVERY_ADDRESS d ON d.LOGICALREF=o.DELIVERYREF
            WHERE o.ORDERDATE>=@giso AND o.ORDERDATE<@g2iso AND o.STATUS NOT IN (1001,1006,1007,3000,4000)
            GROUP BY ISNULL(d.DCITY,'(bilinmiyor)');
            """;
        var il = (await jconn.QueryAsync<NameCount>(ilSql, new { giso, g2iso }))
            .OrderByDescending(x => x.Adet).Take(12).ToList();

        var fiz = stores.Sum(s => s.Net);
        var fisTop = stores.Sum(s => s.Fis);
        var iadeTop = stores.Sum(s => s.Iade);
        var prevFiz = prevStores.Sum(s => s.Net);
        var prevFis = prevStores.Sum(s => s.Fis);
        var prevIade = prevStores.Sum(s => s.Iade);
        return new PeriodSummary(fiz, fisTop, iadeTop, eCiro, eSip, fiz + eCiro, cards, kategori, eticKanal, saat, kasiyer, kargo, il,
            prevFiz, prevFis, prevIade, prevECiro, prevESip);
    }

    /// <summary>
    /// Hedef-gerçekleşen (sadece aylık MTD): mağaza × MTD net × aylık hedef × gerçekleşme %,
    /// ve kategori × hedef × gerçekleşme % (en sapan ilk N). Köprü: Hedef.ktgId=urnKtgr2.ktgrID.
    /// </summary>
    public async Task<(IReadOnlyList<HedefMagaza> Magaza, IReadOnlyList<HedefKategori> Kategori)> GetHedefAsync(DateOnly start, DateOnly endExcl)
    {
        await using var conn = await db.OpenAsync();
        var ayBas = new DateOnly(start.Year, start.Month, 1);
        var par = new
        {
            start = start.ToDateTime(TimeOnly.MinValue),
            end = endExcl.ToDateTime(TimeOnly.MinValue),
            a = ayBas.ToDateTime(TimeOnly.MinValue),
            b = endExcl.ToDateTime(TimeOnly.MinValue),
        };

        // Mağaza MTD net (geri dönüşüm fişi hariç)
        const string netSql = """
            SELECT MG.mekanID AS MekanId,
                   SUM(CASE WHEN s.DocumentsTypeId=3 THEN -1 ELSE 1 END*(s.GrossTotal-s.DiscountTotal-s.VatTotal)) AS Net
            FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
            JOIN EncoreMerkez.dbo.Pos p ON p.Id=s.PosId
            JOIN EncoreMerkez.dbo.Stores st ON st.Id=p.StoreId
            JOIN DerinSISBkm.dbo.posMagaza MG ON MG.mekanKod COLLATE Turkish_CI_AS=st.Code COLLATE Turkish_CI_AS
            LEFT JOIN EncoreMerkez.dbo.SalesProducts spb ON spb.SalesId=s.Id AND spb.BarcodeNo='1001'
            WHERE s.DocumentsTypeId IN (1,2,3,6,7,8) AND spb.Id IS NULL AND s.Date>=@start AND s.Date<@end
            GROUP BY MG.mekanID;
            """;
        var net = (await conn.QueryAsync<(int MekanId, decimal Net)>(netSql, par))
            .ToDictionary(x => x.MekanId, x => x.Net);

        const string hMagSql = "SELECT mekanId, SUM(hedef) H FROM BKMDATA.dbo.Hedef WITH(NOLOCK) WHERE mekanId IN (1,4477,4478) AND tarih>=@a AND tarih<@b GROUP BY mekanId;";
        var hMag = (await conn.QueryAsync<(int mekanId, decimal H)>(hMagSql, par)).ToDictionary(x => x.mekanId, x => x.H);

        var magaza = new List<HedefMagaza>();
        foreach (var mid in new[] { 4477, 1, 4478 })
        {
            var n = net.GetValueOrDefault(mid, 0);
            var h = hMag.GetValueOrDefault(mid, 0);
            magaza.Add(new HedefMagaza(mid, Mekan[mid], n, h, h > 0 ? Math.Round(100 * n / h, 1) : null));
        }

        // Kategori MTD net (Products.Code=stkID köprüsü; tüm mağazalar toplam)
        const string katNetSql = """
            SELECT u.urnKtgr2ID AS KtgId, CAST(ktg.ktgrAd AS nvarchar(50)) AS Ad,
                   CAST(SUM(CASE WHEN s.DocumentsTypeId=3 THEN -1 ELSE 1 END*(sp.TotalPrice-sp.VatTotal)) AS decimal(18,0)) AS Net
            FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
            JOIN EncoreMerkez.dbo.SalesProducts sp WITH(NOLOCK) ON sp.SalesId=s.Id AND sp.IsValid=1 AND sp.BarcodeNo<>'1001'
            JOIN EncoreMerkez.dbo.Products pr WITH(NOLOCK) ON pr.Id=sp.ProductsId
            JOIN DerinSISBkm.dbo.urn u WITH(NOLOCK) ON u.stkID=CONVERT(int,pr.Code)
            JOIN DerinSISBkm.dbo.urnKtgr2 ktg WITH(NOLOCK) ON ktg.ktgrID=u.urnKtgr2ID
            WHERE s.DocumentsTypeId IN (1,2,3,6,7,8) AND ISNUMERIC(pr.Code)=1 AND s.Date>=@start AND s.Date<@end
            GROUP BY u.urnKtgr2ID, CAST(ktg.ktgrAd AS nvarchar(50));
            """;
        var katNet = (await conn.QueryAsync<(int KtgId, string Ad, decimal Net)>(katNetSql, par))
            .ToDictionary(x => x.KtgId, x => (x.Ad, x.Net));

        const string katHedSql = """
            SELECT h.ktgId AS KtgId, CAST(MAX(k.ktgrAd) AS nvarchar(50)) AS Ad, SUM(h.hedef) AS H
            FROM BKMDATA.dbo.Hedef h WITH(NOLOCK)
            LEFT JOIN DerinSISBkm.dbo.urnKtgr2 k ON k.ktgrID=h.ktgId
            WHERE h.mekanId IN (1,4477,4478) AND h.tarih>=@a AND h.tarih<@b
            GROUP BY h.ktgId;
            """;
        var katHed = (await conn.QueryAsync<(int KtgId, string Ad, decimal H)>(katHedSql, par)).ToList();

        var kategori = katHed
            .Where(x => x.H > 0)
            .Select(x =>
            {
                var nv = katNet.TryGetValue(x.KtgId, out var v) ? v : (Ad: x.Ad, Net: 0m);
                return new HedefKategori(nv.Ad ?? x.Ad, nv.Net, x.H, x.H > 0 ? Math.Round(100 * nv.Net / x.H, 1) : null);
            })
            .OrderBy(x => x.GerPct ?? 0)   // en sapan (en düşük gerçekleşme) önce
            .ToList();

        return (magaza, kategori);
    }

    /// <summary>Son 14 gün fiziksel net ciro (trend area). dun = referans (dahil).</summary>
    public async Task<IReadOnlyList<TrendPoint>> GetTrendAsync(DateOnly dun)
    {
        await using var conn = await db.OpenAsync();
        const string sql = """
            SELECT CONVERT(varchar,s.Date,23) AS Tarih,
                   CAST(SUM(CASE WHEN s.DocumentsTypeId=3 THEN -1 ELSE 1 END*(s.GrossTotal-s.DiscountTotal-s.VatTotal)) AS decimal(18,0)) AS Net
            FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
            LEFT JOIN EncoreMerkez.dbo.SalesProducts spb ON spb.SalesId=s.Id AND spb.BarcodeNo='1001'
            WHERE s.DocumentsTypeId IN (1,2,3,6,7,8) AND spb.Id IS NULL AND s.Date>=@bas AND s.Date<@son
            GROUP BY CONVERT(varchar,s.Date,23);
            """;
        var bas = dun.AddDays(-13).ToDateTime(TimeOnly.MinValue);
        var son = dun.AddDays(1).ToDateTime(TimeOnly.MinValue);
        return (await conn.QueryAsync<TrendPoint>(sql, new { bas, son })).OrderBy(t => t.Tarih).ToList();
    }

    /// <summary>Son 14 gün net alış (mal kabul) trend. ehTip 0=Alış + 10=Yerel Alım − 2=Alış İade (irsHrk).</summary>
    public async Task<IReadOnlyList<TrendPoint>> GetAlisTrendAsync(DateOnly dun)
    {
        await using var conn = await db.OpenAsync();
        const string sql = """
            SELECT CONVERT(varchar,h.ehTrhS,23) AS Tarih,
                   CAST(SUM(CASE WHEN h.ehTip IN (0,10) THEN h.ehTutarN WHEN h.ehTip=2 THEN -h.ehTutarN ELSE 0 END) AS decimal(18,0)) AS Net
            FROM DerinSISBkm.dbo.irsHrk h WITH(NOLOCK)
            WHERE h.ehTrhS>=@bas AND h.ehTrhS<@son AND h.ehAltDepo=0 AND h.ehTip IN (0,2,10)
            GROUP BY CONVERT(varchar,h.ehTrhS,23);
            """;
        var bas = dun.AddDays(-13).ToDateTime(TimeOnly.MinValue);
        var son = dun.AddDays(1).ToDateTime(TimeOnly.MinValue);
        return (await conn.QueryAsync<TrendPoint>(sql, new { bas, son })).OrderBy(t => t.Tarih).ToList();
    }

    /// <summary>
    /// B-73 Hedef tahmin: aylık net seri (irsHrk, 3 mağaza, KDV-hariç) + tahmin ayı için
    /// YoY taban × son-3-ay YoY ivmesi + senaryo bandı (±σ). MTD gerçekleşme dahil.
    /// Tahmin ayı = bugünün ayı (kısmi). irsHrk: ehTip 4/100 satış − 101 iade.
    /// </summary>
    /// <summary>Hedef ay tahmini (plan-14). hedefYil/hedefAy seçilen ay; carpan = takvim etmen çarpanı (1.0=etmensiz).
    /// Pencere hem hedefi (taban için -15 ay) hem bugünü (ivme için -15 ay) kapsar.</summary>
    public async Task<TahminSonuc> GetTahminAsync(DateOnly bugun, int hedefYil, int hedefAy, int mekanId = 0, decimal carpan = 1m)
    {
        await using var conn = await db.OpenAsync();
        // Net = satış (ehTip 1,4,100) − iade (3,5,101). ehTutarN daima pozitif (sema codes.yaml).
        const string sql = """
            SELECT CONVERT(char(7),h.ehTrhS,23) AS Ay,
                   CAST(SUM(CASE WHEN h.ehTip IN (1,4,100) THEN h.ehTutarN WHEN h.ehTip IN (3,5,101) THEN -h.ehTutarN ELSE 0 END) AS decimal(18,0)) AS Net
            FROM DerinSISBkm.dbo.irsHrk h WITH(NOLOCK)
            WHERE h.ehMekan IN (1,4477,4478) AND (@mekan=0 OR h.ehMekan=@mekan)
              AND h.ehTip IN (1,3,4,5,100,101) AND h.ehTrhS>=@bas AND h.ehTrhS<@son
            GROUP BY CONVERT(char(7),h.ehTrhS,23);
            """;
        var hedef = new DateOnly(hedefYil, hedefAy, 1);
        var cur = new DateOnly(bugun.Year, bugun.Month, 1);
        // Erken sınır: hedef-15 (taban) ile bugün-15 (ivme) min'i. Geç sınır: ikisinin max'ı +1.
        var basDate = (hedef < cur ? hedef : cur).AddMonths(-15);
        var sonDate = (hedef > cur ? hedef : cur).AddMonths(1);
        var seri = (await conn.QueryAsync<AylikNokta>(sql,
            new { mekan = mekanId, bas = basDate.ToDateTime(TimeOnly.MinValue), son = sonDate.ToDateTime(TimeOnly.MinValue) }))
            .OrderBy(x => x.Ay).ToList();
        return Forecast.Hesapla(seri, $"{hedef:yyyy-MM}", $"{cur:yyyy-MM}", bugun.Day, DateTime.DaysInMonth(hedefYil, hedefAy), carpan);
    }

    /// <summary>B-57 Kasiyer net performansı + önceki eş-uzunluk döneme göre değişim %. Mağaza gruplu, net azalan.</summary>
    public async Task<IReadOnlyList<KasiyerDelta>> GetKasiyerDeltaAsync(DateOnly start, DateOnly endExcl, DateOnly prevStart, DateOnly prevEnd)
    {
        await using var conn = await db.OpenAsync();
        const string sql = """
            SELECT CAST(st.Name AS nvarchar(30)) AS Magaza, CAST(ISNULL(u.Name,'?') AS nvarchar(30)) AS Ad, COUNT(*) AS Fis,
                   CAST(SUM(CASE WHEN s.DocumentsTypeId=3 THEN -(s.GrossTotal-ABS(s.DiscountTotal)-s.VatTotal) ELSE s.GrossTotal-s.DiscountTotal-s.VatTotal END) AS decimal(18,0)) AS Net
            FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
            JOIN EncoreMerkez.dbo.Stores st ON st.Id=s.StoresId
            LEFT JOIN EncoreMerkez.dbo.Users u ON u.Id=s.UsersId
            WHERE s.DocumentsTypeId IN (1,2,3,6,7,8) AND s.Date>=@start AND s.Date<@end
            GROUP BY CAST(st.Name AS nvarchar(30)), CAST(ISNULL(u.Name,'?') AS nvarchar(30));
            """;
        var cur = (await conn.QueryAsync<(string Magaza, string Ad, int Fis, decimal Net)>(sql,
            new { start = start.ToDateTime(TimeOnly.MinValue), end = endExcl.ToDateTime(TimeOnly.MinValue) })).ToList();
        var prev = (await conn.QueryAsync<(string Magaza, string Ad, int Fis, decimal Net)>(sql,
            new { start = prevStart.ToDateTime(TimeOnly.MinValue), end = prevEnd.ToDateTime(TimeOnly.MinValue) }))
            .ToDictionary(k => k.Magaza + "|" + k.Ad, k => k.Net);
        return cur.Select(k =>
        {
            decimal? d = prev.TryGetValue(k.Magaza + "|" + k.Ad, out var pn) && pn > 0
                ? Math.Round(100 * (k.Net - pn) / pn, 1) : null;
            return new KasiyerDelta(k.Magaza, k.Ad, k.Fis, k.Net, k.Fis > 0 ? (int)Math.Round(k.Net / k.Fis) : 0, d);
        }).OrderBy(k => k.Magaza).ThenByDescending(k => k.Net).ToList();
    }

    /// <summary>Kategori bazlı YoY karşılaştırma (seçilen ay vs geçen yıl aynı dönem, irsHrk+urn+urnKtgr2). plan-13/14.
    /// Bu ay → MTD (bugüne dek); geçmiş ay → tam ay; gelecek ay → boş (bu-yıl tarafı veri yok).</summary>
    public async Task<IReadOnlyList<TahminKategori>> GetTahminKategoriAsync(DateOnly bugun, int hedefYil, int hedefAy)
    {
        await using var conn = await db.OpenAsync();
        var hedef = new DateOnly(hedefYil, hedefAy, 1);
        bool buAy = hedefYil == bugun.Year && hedefAy == bugun.Month;
        int gun = buAy ? bugun.Day : DateTime.DaysInMonth(hedefYil, hedefAy);
        var basBy = hedef.ToDateTime(TimeOnly.MinValue);
        var sonBy = hedef.AddDays(gun).ToDateTime(TimeOnly.MinValue);
        var basGY = hedef.AddYears(-1).ToDateTime(TimeOnly.MinValue);
        var sonGY = hedef.AddYears(-1).AddDays(gun).ToDateTime(TimeOnly.MinValue);
        const string sql = """
            SELECT k.ktgrAd AS Ad,
                   CAST(SUM(CASE WHEN h.ehTrhS>=@basBy AND h.ehTrhS<@sonBy AND h.ehTip IN (1,4,100) THEN h.ehTutarN
                                 WHEN h.ehTrhS>=@basBy AND h.ehTrhS<@sonBy AND h.ehTip IN (3,5,101) THEN -h.ehTutarN ELSE 0 END) AS decimal(18,0)) AS MtdBuYil,
                   CAST(SUM(CASE WHEN h.ehTrhS>=@basGY AND h.ehTrhS<@sonGY AND h.ehTip IN (1,4,100) THEN h.ehTutarN
                                 WHEN h.ehTrhS>=@basGY AND h.ehTrhS<@sonGY AND h.ehTip IN (3,5,101) THEN -h.ehTutarN ELSE 0 END) AS decimal(18,0)) AS MtdGecenYil
            FROM DerinSISBkm.dbo.irsHrk h WITH(NOLOCK)
            JOIN DerinSISBkm.dbo.urn u ON u.stkID = h.ehstkID
            JOIN DerinSISBkm.dbo.urnKtgr2 k ON k.ktgrID = u.urnKtgr2ID
            WHERE h.ehMekan IN (1,4477,4478)
              AND h.ehTip IN (1,3,4,5,100,101)
              AND h.ehTrhS >= @basGY AND h.ehTrhS < @sonBy
            GROUP BY k.ktgrAd
            HAVING SUM(CASE WHEN h.ehTrhS>=@basBy AND h.ehTrhS<@sonBy AND h.ehTip IN (1,4,100) THEN h.ehTutarN
                            WHEN h.ehTrhS>=@basBy AND h.ehTrhS<@sonBy AND h.ehTip IN (3,5,101) THEN -h.ehTutarN ELSE 0 END) > 0
            ORDER BY MtdBuYil DESC;
            """;
        var rows = await conn.QueryAsync<(string Ad, decimal MtdBuYil, decimal MtdGecenYil)>(
            sql, new { basBy, sonBy, basGY, sonGY });
        return rows.Select(r =>
        {
            decimal? yoy = r.MtdGecenYil > 0 ? Math.Round(100 * (r.MtdBuYil - r.MtdGecenYil) / r.MtdGecenYil, 1) : null;
            return new TahminKategori(r.Ad, r.MtdBuYil, r.MtdGecenYil, yoy);
        }).ToList();
    }

    /// <summary>Bir ayın gerçek net cirosu (plan-14 kayıt karşılaştırma). MekanId 0=toplam. Veri yoksa null.</summary>
    public async Task<decimal?> GetGercekCiroAsync(int yil, int ay, int mekanId = 0)
    {
        await using var conn = await db.OpenAsync();
        const string sql = """
            SELECT CAST(SUM(CASE WHEN h.ehTip IN (1,4,100) THEN h.ehTutarN WHEN h.ehTip IN (3,5,101) THEN -h.ehTutarN ELSE 0 END) AS decimal(18,0))
            FROM DerinSISBkm.dbo.irsHrk h WITH(NOLOCK)
            WHERE h.ehMekan IN (1,4477,4478) AND (@mekan=0 OR h.ehMekan=@mekan)
              AND h.ehTip IN (1,3,4,5,100,101) AND h.ehTrhS>=@bas AND h.ehTrhS<@son;
            """;
        var bas = new DateOnly(yil, ay, 1).ToDateTime(TimeOnly.MinValue);
        var son = new DateOnly(yil, ay, 1).AddMonths(1).ToDateTime(TimeOnly.MinValue);
        return await conn.ExecuteScalarAsync<decimal?>(sql, new { mekan = mekanId, bas, son });
    }
}

/// <summary>Hedef tahmin matematiği (saf C# — SQL'den ayrı, test edilebilir). B-73.</summary>
public static class Forecast
{
    /// <param name="bugunAy">İçinde bulunulan ay ("yyyy-MM"). İvme daima buna göre son-3-tamamlanmış-ay.</param>
    /// <param name="gunGecti">Hedef==bugün ay ise geçen gün; aksi halde anlamsız.</param>
    /// <param name="carpan">Takvim etmen çarpanı (plan-14). 1.0 = etmensiz. Tahmin/alt/üst bununla ölçeklenir.</param>
    public static TahminSonuc Hesapla(IReadOnlyList<AylikNokta> seri, string tahminAy, string bugunAy,
        int gunGecti, int ayGun, decimal carpan = 1m)
    {
        var m = seri.ToDictionary(x => x.Ay, x => x.Net);
        static string Kaydir(string ay, int n) =>
            DateTime.ParseExact(ay + "-01", "yyyy-MM-dd", System.Globalization.CultureInfo.InvariantCulture)
                .AddMonths(n).ToString("yyyy-MM");
        decimal? Get(string a) => m.TryGetValue(a, out var v) ? v : null;

        bool gelecek = string.CompareOrdinal(tahminAy, bugunAy) > 0;
        bool gecmis = string.CompareOrdinal(tahminAy, bugunAy) < 0;

        var seriDeger = Get(tahminAy);
        var mtd = gelecek ? 0m : (seriDeger ?? 0m);    // gelecek=yok; bu ay=kısmi; geçmiş=tam gerçek
        decimal? gercek = gecmis ? seriDeger : null;   // geçmiş ay tam gerçekleşme (backtest)
        var yoyBase = Get(Kaydir(tahminAy, -12));      // geçen yıl aynı ay (mevsimsel taban)

        // İvme: BUGÜNE göre son 3 TAMAMLANMIŞ ay (hedef ay değil — gelecek ay tahmininde de geçerli).
        var rates = new List<decimal>();
        for (int i = 1; i <= 3; i++)
        {
            var k = Get(Kaydir(bugunAy, -i));
            var kp = Get(Kaydir(bugunAy, -i - 12));
            if (k is not null && kp is > 0) rates.Add(k.Value / kp.Value - 1);
        }
        var yeterli = yoyBase is > 0 && rates.Count >= 2;
        if (!yeterli)
            return new TahminSonuc(tahminAy, yoyBase ?? 0, 0, 0, 0, 0, mtd, null, false, seri, gelecek, gecmis, gercek, carpan);

        var ivme = rates.Average();
        var ort = (double)ivme;
        var sigma = rates.Count > 1
            ? (decimal)Math.Sqrt(rates.Sum(r => Math.Pow((double)r - ort, 2)) / rates.Count)
            : 0m;
        var tahmin = Math.Round(yoyBase!.Value * (1 + ivme) * carpan, 0);
        var alt = Math.Round(yoyBase.Value * (1 + ivme - sigma) * carpan, 0);
        var ust = Math.Round(yoyBase.Value * (1 + ivme + sigma) * carpan, 0);
        // MTD pace = kısmi ay → tüm aya doğrusal projeksiyon (sadece bu ay anlamlı; mevsimsel değil).
        decimal? pace = (!gelecek && !gecmis && gunGecti > 0) ? Math.Round(mtd * ayGun / gunGecti, 0) : null;

        return new TahminSonuc(tahminAy, yoyBase.Value, Math.Round(100 * ivme, 1), tahmin, alt, ust,
            mtd, pace, true, seri, gelecek, gecmis, gercek, carpan);
    }
}
