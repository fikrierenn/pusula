using Dapper;
using System.Text;

namespace GmDashboard.Data;

public sealed record MagazaGunSatir(string Ad, decimal Net, int Fis, decimal Wow, decimal Mtd, decimal Hedef);
public sealed record StockoutSatir(string Kategori, int SatilanCesit, int StoksuzCesit, decimal OranYuzde);
public sealed record HaftaSatir(string Ad, decimal HaftaNet, decimal OncekiHaftaNet);

public sealed class SabahVeri
{
    public DateOnly Tarih      { get; init; }
    public bool     IsPazartesi { get; init; }

    public IReadOnlyList<MagazaGunSatir> Magazalar { get; init; } = [];
    public decimal ToplamNet   => Magazalar.Sum(m => m.Net);
    public decimal ToplamWow   => Magazalar.Sum(m => m.Wow);
    public decimal ToplamMtd   => Magazalar.Sum(m => m.Mtd);
    public decimal ToplamHedef => Magazalar.Sum(m => m.Hedef);

    // MTD projeksiyon (ay sonu tahmini)
    public decimal MtdProjeksiyon { get; init; }
    public decimal MtdHedefFarki  => MtdProjeksiyon - ToplamHedef;

    // Stockout
    public IReadOnlyList<StockoutSatir> Stockout { get; init; } = [];

    // Pazartesi: geçen hafta vs önceki hafta (mağaza bazlı)
    public IReadOnlyList<HaftaSatir> HaftaOzet          { get; init; } = [];
    public decimal HaftaToplamNet       => HaftaOzet.Sum(h => h.HaftaNet);
    public decimal OncekiHaftaToplamNet => HaftaOzet.Sum(h => h.OncekiHaftaNet);

    public string? Hata { get; init; }
}

/// <summary>
/// Sabah Dikkat Listesi veri servisi (MIMBAL entegrasyonu).
/// G1 = dünkü ciro + WoW + MTD + MTD projeksiyon.
/// E8 = stockout kategori özeti (sahaf+sezon dışı).
/// Pazartesi: ek haftalık mağaza karşılaştırması (geçen hafta vs önceki hafta).
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

    // Pazartesi: geçen hafta (Pzt-Paz) vs önceki hafta, mağaza bazlı tek sorguda
    private const string HaftaSql = """
        SELECT
            CASE MG2.mekanID WHEN 1 THEN N'FSM' WHEN 4477 THEN N'Özlüce' WHEN 4478 THEN N'İst.Yolu' END AS Ad,
            SUM(CASE WHEN s.Date >= @haftaBas AND s.Date < @haftaBitis
                THEN CASE WHEN s.DocumentsTypeId=3 THEN -1 ELSE 1 END*(s.GrossTotal-s.DiscountTotal-s.VatTotal)
                ELSE 0 END) AS HaftaNet,
            SUM(CASE WHEN s.Date >= @oncekiHaftaBas AND s.Date < @haftaBas
                THEN CASE WHEN s.DocumentsTypeId=3 THEN -1 ELSE 1 END*(s.GrossTotal-s.DiscountTotal-s.VatTotal)
                ELSE 0 END) AS OncekiHaftaNet
        FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
        JOIN EncoreMerkez.dbo.Pos p ON p.Id=s.PosId
        JOIN EncoreMerkez.dbo.Stores st ON st.Id=p.StoreId
        JOIN DerinSISBkm.dbo.posMagaza MG2 ON MG2.mekanKod COLLATE Turkish_CI_AS = st.Code COLLATE Turkish_CI_AS
        LEFT JOIN EncoreMerkez.dbo.SalesProducts spb ON spb.SalesId=s.Id AND spb.BarcodeNo='1001'
        WHERE s.Date >= @oncekiHaftaBas AND s.Date < @haftaBitis
          AND MG2.mekanID IN (1,4477,4478)
          AND s.DocumentsTypeId IN (1,2,3,6,7,8) AND spb.Id IS NULL
        GROUP BY MG2.mekanID
        ORDER BY MG2.mekanID
        """;

    public async Task<SabahVeri> GetAsync()
    {
        var bugun     = DateOnly.FromDateTime(DateTime.Today);
        var dun       = bugun.AddDays(-1);
        var wow       = dun.AddDays(-7);
        var ayBas     = new DateOnly(dun.Year, dun.Month, 1);
        var isPzt     = bugun.DayOfWeek == DayOfWeek.Monday;

        // Pazartesi: geçen hafta = önceki Pazartesi → önceki Pazar (= dün)
        // bugun = Pazartesi → haftaBas = 7 gün önce Pazartesi, haftaBitis = bugun (dün dahil)
        var haftaBas       = bugun.AddDays(-7);  // geçen Pazartesi
        var oncekiHaftaBas = bugun.AddDays(-14); // önceki Pazartesi

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

            // MTD projeksiyon: günlük ortalama × ay gün sayısı
            var toplamMtd    = magazalar.Sum(m => m.Mtd);
            var toplamHedef  = magazalar.Sum(m => m.Hedef);
            var ayGunSayisi  = DateTime.DaysInMonth(dun.Year, dun.Month);
            var gecenGun     = dun.Day;
            var projeksiyon  = gecenGun > 0 ? toplamMtd / gecenGun * ayGunSayisi : 0m;

            // Pazartesi haftalık karşılaştırma
            List<HaftaSatir> haftaOzet = [];
            if (isPzt)
            {
                haftaOzet = (await conn.QueryAsync<HaftaSatir>(HaftaSql, new {
                    haftaBas       = haftaBas.ToDateTime(TimeOnly.MinValue),
                    haftaBitis     = bugun.ToDateTime(TimeOnly.MinValue),
                    oncekiHaftaBas = oncekiHaftaBas.ToDateTime(TimeOnly.MinValue),
                })).ToList();
            }

            return new SabahVeri
            {
                Tarih            = dun,
                IsPazartesi      = isPzt,
                Magazalar        = magazalar,
                Stockout         = stockout,
                MtdProjeksiyon   = projeksiyon,
                HaftaOzet        = haftaOzet,
            };
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

    /// <summary>Veriyi LLM için zengin metin bloğuna çevirir. Pazartesi'de haftalık blok eklenir.</summary>
    public static string VeriMetni(SabahVeri v)
    {
        var sb = new StringBuilder();

        // ── GÜNLÜK CİRO ──────────────────────────────────────────────────
        sb.AppendLine($"=== GÜNLÜK CİRO ({v.Tarih:dd.MM.yyyy ddd}) ===");
        foreach (var m in v.Magazalar)
        {
            var wowPct = m.Wow > 0 ? (m.Net - m.Wow) / m.Wow * 100 : 0m;
            var mtdPct = m.Hedef > 0 ? m.Mtd / m.Hedef * 100 : 0m;
            sb.AppendLine($"{m.Ad}: {m.Net:N0} ₺ | {m.Fis} fiş | WoW {wowPct:+0.0;-0.0}% | MTD {mtdPct:0.0}% ({m.Mtd:N0} / {m.Hedef:N0} ₺)");
        }

        var topWow = v.ToplamWow > 0 ? (v.ToplamNet - v.ToplamWow) / v.ToplamWow * 100 : 0m;
        var topMtd = v.ToplamHedef > 0 ? v.ToplamMtd / v.ToplamHedef * 100 : 0m;
        sb.AppendLine($"TOPLAM: {v.ToplamNet:N0} ₺ | WoW {topWow:+0.0;-0.0}% | MTD {topMtd:0.0}% ({v.ToplamMtd:N0} / {v.ToplamHedef:N0} ₺)");

        // ── MTD PROJEKSİYON ───────────────────────────────────────────────
        sb.AppendLine();
        var ayGun    = DateTime.DaysInMonth(v.Tarih.Year, v.Tarih.Month);
        var kalanGun = ayGun - v.Tarih.Day;
        var farkTl   = v.MtdHedefFarki;
        var farkSign = farkTl >= 0 ? "+" : "";
        sb.AppendLine($"=== MTD PROJEKSİYON ===");
        sb.AppendLine($"Günde ortalama: {(v.Tarih.Day > 0 ? v.ToplamMtd / v.Tarih.Day : 0):N0} ₺");
        sb.AppendLine($"Ay sonu tahmini: {v.MtdProjeksiyon:N0} ₺ (hedef {v.ToplamHedef:N0} ₺, fark {farkSign}{farkTl:N0} ₺)");
        sb.AppendLine($"Kalan gün: {kalanGun} (ay {ayGun} gün)");
        if (v.ToplamHedef > 0)
        {
            var kalanHedef   = v.ToplamHedef - v.ToplamMtd;
            var gunlukGerekenPace = kalanGun > 0 ? kalanHedef / kalanGun : 0m;
            var mevcutPace   = v.Tarih.Day > 0 ? v.ToplamMtd / v.Tarih.Day : 0m;
            sb.AppendLine($"Hedefe ulaşmak için kalan {kalanGun} günde gereken günlük: {gunlukGerekenPace:N0} ₺ (mevcut pace: {mevcutPace:N0} ₺/gün)");
        }

        // ── HAFTALIK ÖZET (sadece Pazartesi) ─────────────────────────────
        if (v.IsPazartesi && v.HaftaOzet.Count > 0)
        {
            sb.AppendLine();
            sb.AppendLine("=== HAFTALIK ÖZET (geçen Pazartesi–Pazar) ===");
            foreach (var h in v.HaftaOzet)
            {
                var hafWow = h.OncekiHaftaNet > 0 ? (h.HaftaNet - h.OncekiHaftaNet) / h.OncekiHaftaNet * 100 : 0m;
                sb.AppendLine($"{h.Ad}: {h.HaftaNet:N0} ₺ (önceki hafta {h.OncekiHaftaNet:N0} ₺, HoH {hafWow:+0.0;-0.0}%)");
            }
            var topHoH = v.OncekiHaftaToplamNet > 0
                ? (v.HaftaToplamNet - v.OncekiHaftaToplamNet) / v.OncekiHaftaToplamNet * 100
                : 0m;
            sb.AppendLine($"TOPLAM: {v.HaftaToplamNet:N0} ₺ (önceki hafta {v.OncekiHaftaToplamNet:N0} ₺, HoH {topHoH:+0.0;-0.0}%)");
        }

        // ── STOCKOUT ─────────────────────────────────────────────────────
        sb.AppendLine();
        sb.AppendLine("=== STOCKOUT (son 30 gün, sahaf+sezon dışı) ===");
        sb.AppendLine("Eşik referansı: <%5 sağlıklı · %5-10 dikkat · >%10 kritik");
        sb.AppendLine("Not: Elektronik=spot-mal dönen-barkod riski (artefakt olabilir). Akademi/Hazırlık/SınavKıyafet=sezon-bağlı (hariç).");
        foreach (var s in v.Stockout)
        {
            var seviye = s.OranYuzde > 10 ? "KRİTİK" : s.OranYuzde > 5 ? "DİKKAT" : "OK";
            sb.AppendLine($"[{seviye}] {s.Kategori}: %{s.OranYuzde} ({s.StoksuzCesit}/{s.SatilanCesit} çeşit stoksuz)");
        }

        return sb.ToString();
    }
}
