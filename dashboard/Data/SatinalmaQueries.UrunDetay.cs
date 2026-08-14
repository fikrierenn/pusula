using Dapper;
using GmDashboard.Models;

namespace GmDashboard.Data;

/// <summary>
/// Satınalma ürün-detay drill (/satinalma/urun/{stkID}) — Alım Analizi satırından tıklanır.
/// Ürün özet + alış faturaları (fatAyr+fat+frm) + aylık satış (şube irsHrk + e-tic JOKER direkt).
/// Salt-okuma (erp-write-policy); 3-parçalı DerinSISBkm isim (master katalog).
/// </summary>
public sealed partial class SatinalmaQueries
{
    /// <summary>
    /// Tek ürün için KANONİK sezonlu analiz (Alım Analizi ile aynı çekirdek/SQL — gy_sezon, büyüme,
    /// beklenen sezon, sezon-sonrası kalan, sezonlu tükenme, değerlendirme). Detay teşhisi bunu kullanır;
    /// naif aylık-ortalama DEĞİL. #a tek ürüne daraltılır (alım-ayı filtresi kaldırılır). Son biten ay bağlamı.
    /// </summary>
    public async Task<SatinalmaAnalizSatir?> GetUrunAnalizAsync(int stkID)
    {
        var ay0 = new System.DateTime(System.DateTime.Today.Year, System.DateTime.Today.Month, 1)
                        .AddMonths(-1).ToString("yyyyMMdd");
        // AnalizSql'in #a tanımını tek-ürüne daralt (aylık alım filtresi yerine ürün-id). Model gerisi aynı → kanonik.
        var sql = AnalizSql.Replace(
            "WHERE h.ehTip IN (0,10) AND h.ehTrhS>=@AY0 AND h.ehTrhS<@AY1 AND h.ehAdetN>0",
            "WHERE h.ehstkID=@STK AND h.ehTip IN (0,10)");
        var p = BaseParams(ay0); p.Add("STK", stkID);
        await using var c = await db.OpenAsync();
        return await c.QueryFirstOrDefaultAsync<SatinalmaAnalizSatir>(
            new CommandDefinition(sql, p, commandTimeout: 60));
    }

    /// <summary>Ürün başlığı + anlık şube/depo stok. Yoksa null (geçersiz stkID).</summary>
    public async Task<SatinalmaUrunOzet?> GetUrunOzetAsync(int stkID)
    {
        const string sql = """
            SELECT u.stkID AS UrunKodu, u.stkAd AS UrunAd, u.Kategori3 AS Kategori, u.mrkAd AS Marka,
              ISNULL((SELECT SUM(stok) FROM DerinSISBkm.dbo.stokSon_vw WHERE ehstkID=@id AND ehMekan IN (1,4477,4478)),0) AS SubeStok,
              ISNULL((SELECT SUM(Stok) FROM DerinSISBkm.depo.stok_adres_palet_vw WHERE stkID=@id AND adrsAlanTipID IN (0,1)),0) AS DepoStok,
              (SELECT TOP 1 'https://cdn.bkmkitap.com/'+ts.ImageUrl FROM DerinSISBkm.ent.tsoft_urun ts
                 WHERE ts.stkid=@id AND ts.ImageUrl IS NOT NULL AND ts.ImageUrl<>'') AS ResimUrl
            FROM DerinSISBkm.bkm.UrunBilgi u WHERE u.stkID=@id;
            """;
        await using var c = await db.OpenAsync();
        return await c.QueryFirstOrDefaultAsync<SatinalmaUrunOzet>(sql, new { id = stkID });
    }

    /// <summary>Son alış faturaları (eTip=0), fatura-bazında toplanmış (0-birim promo satırlar dahil). Tedarikçi frm.frmAd.</summary>
    public async Task<IReadOnlyList<SatinalmaFaturaSatir>> GetFaturaDetayAsync(int stkID, int top = 40)
    {
        var sql = $"""
            SELECT TOP {top}
               MAX(f.eTarih) AS Tarih, f.eNo AS BelgeNo, MAX(LTRIM(RTRIM(ISNULL(frm.frmAd,'')))) AS Tedarikci,
               CONVERT(int,SUM(fa.ehAdetN)) AS Adet, CONVERT(decimal(18,2),SUM(fa.ehTutarN)) AS Tutar,
               CONVERT(decimal(18,2), SUM(fa.ehTutarN)/NULLIF(SUM(fa.ehAdetN),0)) AS Birim
            FROM DerinSISBkm.dbo.fatAyr fa WITH(NOLOCK)
            JOIN DerinSISBkm.dbo.fat f WITH(NOLOCK) ON fa.ehID=f.eID
            LEFT JOIN DerinSISBkm.dbo.frm frm WITH(NOLOCK) ON frm.frmID=f.eFirma
            WHERE fa.ehstkID=@id AND f.eTip=0 AND f.eDurum<>2 AND fa.ehAdetN>0
            GROUP BY f.eNo, f.eID
            ORDER BY MAX(f.eTarih) DESC, f.eID DESC;
            """;
        await using var c = await db.OpenAsync();
        return (await c.QueryAsync<SatinalmaFaturaSatir>(sql, new { id = stkID })).AsList();
    }

    /// <summary>Geçen-yıl SABİT sezon penceresinde ŞUBE-bazlı satış + o sezondaki MAX raf stoğu.
    /// Amaç: forecast tabanı (gy_sezon) bazı şubeler KURUyken bastırıldı mı? Kuru şube = "talep yok" değil "stok yok"
    /// → toplam sezon-satışı eksik-sayım. Detay teşhisi bu şeffaflığı gösterir (591060 Faber-Castell vakası).</summary>
    public async Task<IReadOnlyList<SatinalmaSubeSezon>> GetSubeSezonAsync(int stkID)
    {
        var ay0 = new DateTime(DateTime.Today.Year, DateTime.Today.Month, 1).AddMonths(-1).ToString("yyyyMMdd");
        var sz = SatinalmaSezon.Hesapla(ay0);   // geçen-yıl sezon [SEZb,SEZe) — Alım Analizi ile aynı pencere
        const string sql = """
            SELECT m.Mekan, m.Ad,
              ISNULL(s.satis,0) AS Satis,
              ISNULL(b.max_stok,0) AS MaxStok
            FROM (VALUES (1,N'FSM'),(4477,N'Özlüce'),(4478,N'İst.Yolu')) m(Mekan,Ad)
            LEFT JOIN (SELECT ehMekan, CONVERT(int,SUM(-ehAdetN)) satis
                       FROM DerinSISBkm.dbo.irsHrk WITH(NOLOCK)
                       WHERE ehstkID=@id AND ehTip IN (1,4,100) AND ehTrhS>=@sezb AND ehTrhS<@seze
                       GROUP BY ehMekan) s ON s.ehMekan=m.Mekan
            LEFT JOIN (SELECT ehMekan, CONVERT(int,MAX(Stok)) max_stok
                       FROM DerinSISBkm.bkm.StokAyBakiyeMekanBazli WITH(NOLOCK)
                       WHERE stkID=@id AND Kaynak='irsHrk' AND Donem>=@sezb AND Donem<@seze
                       GROUP BY ehMekan) b ON b.ehMekan=m.Mekan;
            """;
        await using var c = await db.OpenAsync();
        return (await c.QueryAsync<SatinalmaSubeSezon>(sql, new { id = stkID, sezb = sz.SEZb, seze = sz.SEZe })).AsList();
    }

    /// <summary>TOPTAN/bulk satış hareketleri (son 12 ay, tek-hareket > cap) — TOPTAN KANAL rozeti drill.
    /// Analist "bu %X toptan nereden" görsün (ör. Sınav Okulları İst.Yolu bulk kalem alımı).</summary>
    public async Task<IReadOnlyList<SatinalmaBulkHareket>> GetBulkHareketAsync(int stkID, int cap, int top = 20)
    {
        var bas = new DateTime(DateTime.Today.Year, DateTime.Today.Month, 1).AddMonths(-12).ToString("yyyyMMdd");
        var sql = $"""
            SELECT TOP (@top) h.ehTrhS AS Tarih, h.ehMekan AS Mekan, CONVERT(int,-h.ehAdetN) AS Adet,
                   ISNULL(ev.eNo,'—') AS EvrakNo
            FROM DerinSISBkm.dbo.irsHrk h WITH(NOLOCK)
            OUTER APPLY (SELECT TOP 1 i.eNo FROM DerinSISBkm.dbo.irs i WITH(NOLOCK) WHERE i.eID=h.ehID) ev
            WHERE h.ehstkID=@id AND h.ehTip IN (1,4) AND h.ehAdetN<0 AND -h.ehAdetN > @cap AND h.ehTrhS>=@bas
            ORDER BY -h.ehAdetN DESC;
            -- ehTip 100 (POS) HARİÇ: POS satırı günlük-aggregate (gerçek bulk değil); bulk = sevk/fatura belge (ehTip 1/4).
            """;
        await using var c = await db.OpenAsync();
        var rows = (await c.QueryAsync<SatinalmaBulkHareket>(sql, new { id = stkID, cap, bas, top })).AsList();
        foreach (var r in rows) r.MekanAd = r.Mekan switch { 1 => "FSM", 4477 => "Özlüce", 4478 => "İst.Yolu", 12 => "Depo/online", _ => r.Mekan.ToString() };
        return rows;
    }

    /// <summary>Son 24 ay satış — şube (irsHrk) DerinSIS + e-ticaret (JOKER direkt), ay-bazında birleşik.</summary>
    public async Task<IReadOnlyList<SatinalmaAySatis>> GetAySatisAsync(int stkID)
    {
        // Son 24 ayın başı (bu ayın başından −23 ay) — hem DerinSIS hem JOKER penceresi.
        var basDt = new DateTime(DateTime.Today.Year, DateTime.Today.Month, 1).AddMonths(-23);
        var basIso = basDt.ToString("yyyyMMdd");

        const string subeSql = """
            SELECT CONVERT(char(7),ehTrhS,126) AS Ay, CONVERT(int,-SUM(ehAdetN)) AS Adet
            FROM DerinSISBkm.dbo.irsHrk WITH(NOLOCK)
            WHERE ehstkID=@id AND ehTip IN (1,4,100) AND ehTrhS>=@bas
            GROUP BY CONVERT(char(7),ehTrhS,126);
            """;
        const string eticSql = """
            SELECT CONVERT(varchar(4),YEAR(o.ORDERDATE))+'-'+RIGHT('0'+CONVERT(varchar(2),MONTH(o.ORDERDATE)),2) AS Ay, SUM(d.QUANTITY) AS Adet
            FROM JOKER.dbo.J_ORDER_DETAILS d JOIN JOKER.dbo.J_ORDERS o ON o.ORDERID=d.ORDERREF JOIN JOKER.dbo.J_ITEMS i ON i.LOGICALREF=d.ITEMREF
            WHERE i.DERINSIS_ID=@id AND d.STATUS NOT IN (2004,2005,2010) AND o.ORDERDATE>=@bas
            GROUP BY CONVERT(varchar(4),YEAR(o.ORDERDATE))+'-'+RIGHT('0'+CONVERT(varchar(2),MONTH(o.ORDERDATE)),2);
            """;

        async Task<List<(string Ay, int Adet)>> Sube()
        {
            await using var c = await db.OpenAsync();
            return (await c.QueryAsync<(string, int)>(subeSql, new { id = stkID, bas = basIso })).AsList();
        }
        async Task<List<(string Ay, int Adet)>> Etic()
        {
            await using var c = await db.OpenJokerAsync();   // direkt JOKER (ISO) — linked/OPENQUERY yerine (B-74)
            return (await c.QueryAsync<(string, int)>(eticSql, new { id = stkID, bas = basIso })).AsList();
        }

        var sube = await Sube();
        var etic = await Etic();

        // Ay-bazında birleştir + son 24 ay iskeleti (boş aylar 0).
        var map = new Dictionary<string, SatinalmaAySatis>();
        for (int i = 0; i < 24; i++)
        {
            var ay = basDt.AddMonths(i).ToString("yyyy-MM");
            map[ay] = new SatinalmaAySatis { Ay = ay };
        }
        foreach (var (ay, adet) in sube) if (map.TryGetValue(ay, out var r)) r.Sube = adet;
        foreach (var (ay, adet) in etic) if (map.TryGetValue(ay, out var r)) r.Etic = adet;
        return map.Values.OrderBy(r => r.Ay).ToList();
    }
}
