using Dapper;
using GmDashboard.Models;

namespace GmDashboard.Data;

/// <summary>
/// Satış Analizi paneli sorguları (plan-42). SALT-SELECT — yazma yalnız
/// <see cref="SatisAnaliziTabanService"/>'te (erp-write-policy).
///
/// Ön-agrega <c>bkm.SatisAnaliziTaban</c>'dan okur. NEDEN (ölçüldü, 274.933 ürün):
///   CTE ile her istekte yeniden hesap → sayfa 5,31-5,44 s · KPI 3,15-3,76 s · arama 5,8 s riski
///   tablodan                          → sayfa 17 ms · KPI 196 ms · arama 346 ms · kohort 73 ms
/// ⚠ <c>COUNT(*) OVER ()</c> KULLANILMAZ: sayfa başına 1,2 s ekliyordu (ölçüldü). Toplam bir kez
///   sayılır (34 ms) ve sayfa çevirmede tekrar sorulmaz.
///
/// ⚠ 3-PARÇALI İSİM ZORUNLU: Db.OpenAsync varsayılan katalog = master → 2-parçalı isim Err 208.
///
/// TANIM KANITI: sorgular/2026-09-08-satis-analizi-excel-denetim.sql §10-12.
/// Kardeş emitter: scripts/satis_analizi_excel.py — ikisi AYRIŞMAMALI.
/// </summary>
public sealed partial class SatisAnaliziQueries(Db db, ILogger<SatisAnaliziQueries> logger)
{
    /// <summary>
    /// Rapor evreni — ÖLÇÜLDÜ: liste dışı 59.826 çeşidin HİÇBİRİ orijinal raporda yok.
    /// ⚠ Satılabilir ürün kaçırıyor (ıslak mendil 'Kişisel Bakım', WMS'te ~366K adet). Panel
    /// orijinali birebir yansıtsın diye AYNEN korunuyor; düzeltme ayrı iş (plan-42 §8).
    /// </summary>
    public static readonly string[] Kategori3Evreni =
    [
        "Kitap", "Kırtasiye", "Oyuncak", "Çocuk Kitabı", "Hazırlık Kitapları",
        "Akademi", "Hediyelik", "Elektronik", "Dergi", "Spor & Outdoor",
        "Kafe Hammede", "Zkargo",
    ];

    private const string Taban = "DerinSISBkm.bkm.SatisAnaliziTaban";

    /// <summary>
    /// TAZE STOK süzgeci. <c>TazeGunHaric &gt; 0</c> ise son N günde mal kabulü olan ürünler
    /// DEĞERLENDİRMEDEN çıkarılır (adil-atıf: yeni gelen mal aşırı/hareketsiz sayılmaz).
    /// KPI, kırılım ve listede AYNI şart uygulanır — yoksa KPI ile tablo ayrışır.
    /// </summary>
    private static string TazeSart(SatisAnaliziFiltre f) => f.TazeGunHaric > 0
        ? " AND (t.SonGiris IS NULL OR t.SonGiris < DATEADD(DAY, -@taze, @kesim))"
        : "";

    /// <summary>Kesim+sezon süzgeci — her sorgunun ilk şartı (index'lerin ön eki).</summary>
    private static object KesimP(SatisAnaliziFiltre f) => new
    {
        kesim = f.Kesim.ToDateTime(TimeOnly.MinValue),
        sezon = (short)f.SezonYil,
        taze = f.TazeGunHaric,
    };

    /// <summary>
    /// KPI + Kategori3 kırılımı — tek geçiş, 196 ms.
    /// Aşırı stok eşiği: stok &gt; 5 × sezon satışı. ⚠ GEÇİCİ: hedef gün-stok politikası
    /// <c>bkm.OneriSiparisKtg3Ondeger</c>'de tanımlı ama BOŞ (ölçüldü 08.09) → eşik girilene
    /// kadar 5× kullanılıyor ve ekranda "eşik tanımlı değil" etiketi çıkar.
    /// </summary>
    public async Task<SatisAnaliziOzet> GetOzetAsync(SatisAnaliziFiltre f, CancellationToken ct = default)
    {
        var sql = $"""
            SELECT t.Kategori3 AS Ad,
                   COUNT(*)                                       AS Cesit,
                   CONVERT(bigint, SUM(CONVERT(bigint, t.ToplamStok)))  AS Stok,
                   CONVERT(decimal(18,2), SUM(t.Tutar))           AS Tutar,
                   CONVERT(bigint, SUM(CONVERT(bigint, t.SatisToplam))) AS Satis365,
                   CONVERT(bigint, SUM(CONVERT(bigint, t.SezonToplam))) AS Sezon,
                   SUM(CASE WHEN t.SezonToplam > 0 AND t.ToplamStok <= 0 THEN 1 ELSE 0 END) AS StoksuzCesit,
                   CONVERT(decimal(18,2), SUM(CASE WHEN t.SezonToplam > 0 AND t.ToplamStok <= 0
                        THEN t.SezonToplam * t.SatisFiyat ELSE 0 END))                     AS StoksuzKayip,
                   SUM(CASE WHEN t.SezonToplam > 0 AND t.ToplamStok <= 0 AND t.OdakStok > 0 THEN 1 ELSE 0 END) AS StoksuzOdakCesit,
                   CONVERT(decimal(18,2), SUM(CASE WHEN t.SezonToplam > 0 AND t.ToplamStok <= 0 AND t.OdakStok > 0
                        THEN t.SezonToplam * t.SatisFiyat ELSE 0 END))                     AS StoksuzOdakKayip,
                   SUM(CASE WHEN t.SezonToplam > 0 AND t.ToplamStok > 5 * t.SezonToplam THEN 1 ELSE 0 END) AS AsiriCesit,
                   CONVERT(decimal(18,2), SUM(CASE WHEN t.SezonToplam > 0 AND t.ToplamStok > 5 * t.SezonToplam
                        THEN t.Tutar ELSE 0 END))                                          AS AsiriTutar,
                   SUM(CASE WHEN t.SezonToplam > 0 AND t.ToplamStok > 5 * t.SezonToplam AND t.OdakStok > 0 THEN 1 ELSE 0 END) AS AsiriOdakCesit,
                   CONVERT(decimal(18,2), SUM(CASE WHEN t.SezonToplam > 0 AND t.ToplamStok > 5 * t.SezonToplam AND t.OdakStok > 0
                        THEN t.Tutar ELSE 0 END))                                          AS AsiriOdakTutar,
                   SUM(CASE WHEN t.SatisToplam <= 0 AND t.ToplamStok > 0 THEN 1 ELSE 0 END) AS HareketsizCesit,
                   CONVERT(decimal(18,2), SUM(CASE WHEN t.SatisToplam <= 0 AND t.ToplamStok > 0
                        THEN t.Tutar ELSE 0 END))                                          AS HareketsizTutar,
                   SUM(CASE WHEN t.ToplamStok < 0 OR t.SatisFiyat <= 0 THEN 1 ELSE 0 END)  AS KirliCesit,
                   CONVERT(decimal(18,2), SUM(CASE WHEN t.ToplamStok < 0 OR t.SatisFiyat <= 0
                        THEN t.Tutar ELSE 0 END))                                          AS KirliTutar
            FROM {Taban} t WITH (NOLOCK)
            WHERE t.Kesim = @kesim AND t.SezonYil = @sezon{TazeSart(f)}
            GROUP BY t.Kategori3
            ORDER BY SUM(t.Tutar) DESC
            """;

        await using var conn = await db.OpenAsync();
        var satirlar = (await conn.QueryAsync<OzetSatirRow>(
            new CommandDefinition(sql, KesimP(f), commandTimeout: 120, cancellationToken: ct))).ToList();

        // Merkez depo çıkışı — TALEP DEĞİL, ayrı kutu (danışma kararı 08.09: %72'si grup şirketine).
        var merkezCikis = await MerkezCikisAsync(conn, f, ct);

        var kpi = new SatisAnaliziKpi(
            ToplamStok: satirlar.Sum(x => x.Stok),
            ToplamStokTutar: satirlar.Sum(x => x.Tutar),
            Cesit: satirlar.Sum(x => x.Cesit),
            PerakendeSatis365: satirlar.Sum(x => x.Satis365),
            MerkezCikis365: merkezCikis,
            StoksuzSezonCesit: satirlar.Sum(x => x.StoksuzCesit),
            StoksuzSezonKayip: satirlar.Sum(x => x.StoksuzKayip),
            StoksuzSezonOdakVarCesit: satirlar.Sum(x => x.StoksuzOdakCesit),
            StoksuzSezonOdakVarKayip: satirlar.Sum(x => x.StoksuzOdakKayip),
            AsiriStokCesit: satirlar.Sum(x => x.AsiriCesit),
            AsiriStokTutar: satirlar.Sum(x => x.AsiriTutar),
            AsiriStokOdakVarCesit: satirlar.Sum(x => x.AsiriOdakCesit),
            AsiriStokOdakVarTutar: satirlar.Sum(x => x.AsiriOdakTutar),
            HareketsizCesit: satirlar.Sum(x => x.HareketsizCesit),
            HareketsizTutar: satirlar.Sum(x => x.HareketsizTutar),
            VeriKirliCesit: satirlar.Sum(x => x.KirliCesit),
            VeriKirliTutar: satirlar.Sum(x => x.KirliTutar));

        var kirilim = satirlar.Select(x => new SatisAnaliziKirilim(
            x.Ad, x.Cesit, x.Stok, x.Tutar, x.Satis365, x.Sezon, x.StoksuzCesit, x.AsiriTutar)).ToList();

        logger.LogInformation("Satış Analizi özet: {Cesit} çeşit / {Kat} kategori, kesim {Kesim}",
            kpi.Cesit, kirilim.Count, f.Kesim);
        return new SatisAnaliziOzet(kpi, kirilim);
    }

    /// <summary>Kategori1 (KatAna) kırılımı — seçili Kategori3 içinde drill.</summary>
    public async Task<IReadOnlyList<SatisAnaliziKirilim>> GetKategori1Async(
        SatisAnaliziFiltre f, CancellationToken ct = default)
    {
        var sql = $"""
            SELECT TOP 30 t.Kategori1 AS Ad, COUNT(*) AS Cesit,
                   CONVERT(bigint, SUM(CONVERT(bigint, t.ToplamStok)))  AS Stok,
                   CONVERT(decimal(18,2), SUM(t.Tutar))           AS Tutar,
                   CONVERT(bigint, SUM(CONVERT(bigint, t.SatisToplam))) AS Satis365,
                   CONVERT(bigint, SUM(CONVERT(bigint, t.SezonToplam))) AS Sezon,
                   SUM(CASE WHEN t.SezonToplam > 0 AND t.ToplamStok <= 0 THEN 1 ELSE 0 END) AS StoksuzCesit,
                   CONVERT(decimal(18,2), SUM(CASE WHEN t.SezonToplam > 0 AND t.ToplamStok > 5 * t.SezonToplam
                        THEN t.Tutar ELSE 0 END)) AS AsiriTutar
            FROM {Taban} t WITH (NOLOCK)
            WHERE t.Kesim = @kesim AND t.SezonYil = @sezon
              AND (@kategori3 IS NULL OR t.Kategori3 = @kategori3){TazeSart(f)}
            GROUP BY t.Kategori1
            ORDER BY SUM(t.Tutar) DESC
            """;
        await using var conn = await db.OpenAsync();
        var p = new DynamicParameters(KesimP(f));
        p.Add("kategori3", f.Kategori3);
        return (await conn.QueryAsync<SatisAnaliziKirilim>(
            new CommandDefinition(sql, p, commandTimeout: 120, cancellationToken: ct))).ToList();
    }

    /// <summary>
    /// Yayınevi kırılımı — iade/konsinye koşulu yayınevi bazlı olduğu için karar tarafında şart
    /// (satinalma-danisman 08.09). ⚠ İade hakkı VERİDE İZLİ DEĞİL (ölçüldü: urn.alimIadeYok sabit 2,
    /// frm.frmIadeKural lookup'sız) → ekranda bu sınır yazılır.
    /// </summary>
    public async Task<IReadOnlyList<SatisAnaliziKirilim>> GetYayineviAsync(
        SatisAnaliziFiltre f, CancellationToken ct = default)
    {
        var sql = $"""
            SELECT TOP 30 ISNULL(t.Yayinevi, N'(tanımsız)') AS Ad, COUNT(*) AS Cesit,
                   CONVERT(bigint, SUM(CONVERT(bigint, t.ToplamStok)))  AS Stok,
                   CONVERT(decimal(18,2), SUM(t.Tutar))           AS Tutar,
                   CONVERT(bigint, SUM(CONVERT(bigint, t.SatisToplam))) AS Satis365,
                   CONVERT(bigint, SUM(CONVERT(bigint, t.SezonToplam))) AS Sezon,
                   SUM(CASE WHEN t.SezonToplam > 0 AND t.ToplamStok <= 0 THEN 1 ELSE 0 END) AS StoksuzCesit,
                   CONVERT(decimal(18,2), SUM(CASE WHEN t.SezonToplam > 0 AND t.ToplamStok > 5 * t.SezonToplam
                        THEN t.Tutar ELSE 0 END)) AS AsiriTutar
            FROM {Taban} t WITH (NOLOCK)
            WHERE t.Kesim = @kesim AND t.SezonYil = @sezon
              AND (@kategori3 IS NULL OR t.Kategori3 = @kategori3){TazeSart(f)}
            GROUP BY t.Yayinevi
            ORDER BY SUM(t.Tutar) DESC
            """;
        await using var conn = await db.OpenAsync();
        var p = new DynamicParameters(KesimP(f));
        p.Add("kategori3", f.Kategori3);
        return (await conn.QueryAsync<SatisAnaliziKirilim>(
            new CommandDefinition(sql, p, commandTimeout: 120, cancellationToken: ct))).ToList();
    }

    /// <summary>
    /// ODAK temin süresi kırılımı — "5 günde gelen mal için ne kadar stok tutuyoruz" sorusu.
    /// ÖLÇÜLDÜ 08.09: aşırı stok + ODAK'ta var kohortunun %97'si (131,4M ₺) ≤5 gün temin süreli.
    /// </summary>
    public async Task<IReadOnlyList<TeminKirilim>> GetTeminKirilimAsync(
        SatisAnaliziFiltre f, CancellationToken ct = default)
    {
        var sql = $"""
            SELECT CASE WHEN t.LeadTime IS NULL THEN N'bilinmiyor'
                        WHEN t.LeadTime <= 3  THEN N'≤3 gün'
                        WHEN t.LeadTime <= 5  THEN N'4-5 gün'
                        WHEN t.LeadTime <= 7  THEN N'6-7 gün'
                        WHEN t.LeadTime <= 10 THEN N'8-10 gün'
                        WHEN t.LeadTime <= 15 THEN N'11-15 gün'
                        ELSE N'16+ gün' END AS Ad,
                   MIN(ISNULL(t.LeadTime, 999)) AS Sira,
                   COUNT(*) AS Cesit,
                   CONVERT(decimal(18,2), SUM(t.Tutar)) AS Tutar,
                   CONVERT(bigint, SUM(CONVERT(bigint, t.OdakStok))) AS OdakStok
            FROM {Taban} t WITH (NOLOCK)
            WHERE t.Kesim = @kesim AND t.SezonYil = @sezon
              AND t.SezonToplam > 0 AND t.ToplamStok > 5 * t.SezonToplam AND t.OdakStok > 0{TazeSart(f)}
            GROUP BY CASE WHEN t.LeadTime IS NULL THEN N'bilinmiyor'
                          WHEN t.LeadTime <= 3  THEN N'≤3 gün'
                          WHEN t.LeadTime <= 5  THEN N'4-5 gün'
                          WHEN t.LeadTime <= 7  THEN N'6-7 gün'
                          WHEN t.LeadTime <= 10 THEN N'8-10 gün'
                          WHEN t.LeadTime <= 15 THEN N'11-15 gün'
                          ELSE N'16+ gün' END
            ORDER BY MIN(ISNULL(t.LeadTime, 999))
            """;
        await using var conn = await db.OpenAsync();
        return (await conn.QueryAsync<TeminKirilim>(
            new CommandDefinition(sql, KesimP(f), commandTimeout: 120, cancellationToken: ct))).ToList();
    }

    /// <summary>
    /// Merkez depo çıkışı (ehMekan=12, ehTip 1/3/5/101) — 365 gün, iade netlenmiş.
    /// ⚠ TÜKETİCİ TALEBİ DEĞİL: %72'si grup şirketine (frmID 56), %16'sı ODAK'a (ölçüm 08.09).
    /// Gün-stok hesabına GİRMEZ; KPI'da ayrı kutuda gösterilir.
    /// Tabanda yok (ürün bazlı değil) → canlı sorulur, ~1 s.
    /// </summary>
    private static async Task<long> MerkezCikisAsync(
        System.Data.Common.DbConnection conn, SatisAnaliziFiltre f, CancellationToken ct)
    {
        const string sql = """
            SELECT CONVERT(bigint, -SUM(h.ehAdetN))
            FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
            WHERE h.ehMekan = 12 AND h.ehTip IN (1, 3, 5, 101)
              AND h.ehTrhS >= @bas AND h.ehTrhS < DATEADD(DAY, 1, @kesim)
            """;
        var cmd = new CommandDefinition(sql,
            new { bas = f.Baslangic.ToDateTime(TimeOnly.MinValue), kesim = f.Kesim.ToDateTime(TimeOnly.MinValue) },
            commandTimeout: 180, cancellationToken: ct);
        return await conn.ExecuteScalarAsync<long?>(cmd) ?? 0L;
    }

    private sealed record OzetSatirRow(
        string Ad, int Cesit, long Stok, decimal Tutar, long Satis365, long Sezon,
        int StoksuzCesit, decimal StoksuzKayip, int StoksuzOdakCesit, decimal StoksuzOdakKayip,
        int AsiriCesit, decimal AsiriTutar, int AsiriOdakCesit, decimal AsiriOdakTutar,
        int HareketsizCesit, decimal HareketsizTutar, int KirliCesit, decimal KirliTutar);
}

/// <summary>Sayfa açılışında tek geçişte gelen özet: KPI + Kategori3 kırılımı.</summary>
public sealed record SatisAnaliziOzet(SatisAnaliziKpi Kpi, IReadOnlyList<SatisAnaliziKirilim> Kategori3);

/// <summary>ODAK temin süresi bandı kırılımı.</summary>
public sealed record TeminKirilim(string Ad, int Sira, int Cesit, decimal Tutar, long OdakStok);
