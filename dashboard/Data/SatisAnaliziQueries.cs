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
    /// <summary>
    /// YENİ ÜRÜN SQL SÜZGECİ — "değerlendirilecek kadar zamanı oldu mu".
    ///
    /// ⚠ Bu tek yerde tanımlıdır ve KPI ile liste süzgeci AYNI ifadeyi kullanır; ayrışırsa
    /// kart bir sayı, liste başka sayı gösterir (SayfaSonucu'nun yasakladığı çelişki).
    ///
    /// NEDEN <c>COALESCE(IlkGiris, AcilisTarihi)</c>: yenilik önce MAĞAZAYA ilk girişten
    /// ölçülür; ürün mağazaya hiç girmediyse <c>IlkGiris</c> NULL olur ve eski sürüm onu
    /// sessizce "eski" sayıyordu. Ölçüldü 09.09.2026 (kullanıcı bildirimi, stkID 1739163
    /// "Penna Kar Küresi Peluş" — kartı 04.09.2026'da açılmış, mağazaya hiç girmemiş,
    /// merkezde 1.344 adet, yine de HAREKETSİZ listesinde): 119.434 hareketsiz çeşidin
    /// 4.374'ü son 90 günde yeni (31,34M ₺), 371'i mağazaya hiç girmemiş + yeni açılmış.
    /// İkisi de NULL olan kayıt YOK (ölçüldü: 0) → COALESCE her zaman bir tarih bulur.
    /// </summary>
    private const string YeniDegilSart =
        "COALESCE(t.IlkGiris, t.AcilisTarihi) < DATEADD(DAY, -@yeniGun, @kesim)";

    private static string TazeSart(SatisAnaliziFiltre f) => f.TazeGunHaric > 0
        // ⚠ Eski hâli "SonGiris IS NULL OR ..." idi: tarihi bilinmeyeni sessizce ESKİ sayıyordu.
        // Mağazaya hiç girmemiş ürünün SonGiris'i NULL olur (mağaza defterinde kayıt yok) →
        // 4 gün önce açılmış ürün "eski" muamelesi görüyordu (stkID 1739163 vakası, 09.09).
        // Doğrusu: bilinen en yeni tarihe düş — son mal kabulü → mağazaya ilk giriş → kart açılışı.
        ? " AND " + "(COALESCE(t.SonGiris, t.IlkGiris, t.AcilisTarihi) < DATEADD(DAY, -@taze, @kesim))"
        : "";

    /// <summary>Kesim+sezon süzgeci — her sorgunun ilk şartı (index'lerin ön eki).</summary>
    private static object KesimP(SatisAnaliziFiltre f) => new
    {
        kesim = f.Kesim.ToDateTime(TimeOnly.MinValue),
        sezon = (short)f.SezonYil,
        taze = f.TazeGunHaric,
        // YENİLİK EŞİĞİ — ekrandaki "taze gün" kutusuna bağlı; kutu kapalıysa varsayılan.
        // Kullanıcı kararı 09.09: 90 çok uzun, 30-45 aralığı → 45 seçildi (ortası).
        // Ölçüldü: 30g 2.040 çeşit/22,0M ₺ · 45g 2.658/24,6M ₺ · 90g 4.374/31,3M ₺ korur.
        yeniGun = f.TazeGunHaric > 0 ? f.TazeGunHaric : SatisAnaliziFiltre.YeniUrunGunVarsayilan,
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
                   -- Gün-stok payı MAĞAZA stoğudur (kapsam asimetrisi düzeltmesi 09.09):
                   -- payda mağaza satışı olduğu için pay da mağaza olmalı. Merkez AYRI.
                   CONVERT(bigint, SUM(CONVERT(bigint, t.MagazaStok)))  AS MagazaStok,
                   CONVERT(bigint, SUM(CONVERT(bigint, t.MerkezStok)))  AS MerkezStok,
                   CONVERT(decimal(18,2), SUM(t.Tutar))           AS Tutar,
                   CONVERT(bigint, SUM(CONVERT(bigint, t.SatisToplam))) AS Satis365,
                   CONVERT(float, SUM(CONVERT(float, t.SatisToplam) / CASE
                       WHEN t.IlkGiris IS NULL THEN 365.0
                       WHEN DATEDIFF(DAY, t.IlkGiris, t.Kesim) + 1 < 365 THEN DATEDIFF(DAY, t.IlkGiris, t.Kesim) + 1
                       ELSE 365.0 END)) AS GunlukHiz,
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
                   -- Hareketsiz: satış yok + stok var + DEĞERLENDİRİLECEK kadar zamanı olmuş.
                   -- Yenilik koruması olmadan yeni açılan ürün haksız damgalanıyordu (ölçüldü).
                   SUM(CASE WHEN t.SatisToplam <= 0 AND t.ToplamStok > 0
                                 AND COALESCE(t.IlkGiris, t.AcilisTarihi) < DATEADD(DAY, -@yeniGun, @kesim)
                            THEN 1 ELSE 0 END) AS HareketsizCesit,
                   CONVERT(decimal(18,2), SUM(CASE WHEN t.SatisToplam <= 0 AND t.ToplamStok > 0
                        AND COALESCE(t.IlkGiris, t.AcilisTarihi) < DATEADD(DAY, -@yeniGun, @kesim)
                        THEN t.Tutar ELSE 0 END))                                          AS HareketsizTutar,
                   -- RAFA HİÇ ÇIKMAMIŞ (kullanıcı isteği 09.09: "gelmiş ama mağazaya gitmemiş
                   -- te bir kpi olmalı"). Merkeze girmiş, mağazaya HİÇ girmemiş → satması
                   -- imkânsız. IlkGiris NULL = mağaza defterinde tek giriş kaydı yok.
                   -- ÖLÇÜLDÜ 09.09: 1.182 çeşit / 142.714 adet / 24,17M ₺; 802'si 90 günden eski.
                   SUM(CASE WHEN t.IlkGiris IS NULL AND t.MerkezStok > 0 THEN 1 ELSE 0 END) AS RafsizCesit,
                   CONVERT(decimal(18,2), SUM(CASE WHEN t.IlkGiris IS NULL AND t.MerkezStok > 0
                        THEN t.Tutar ELSE 0 END))                                          AS RafsizTutar,
                   -- RAFTA YOK ama MERKEZDE VAR — daha önce rafa çıkmış, şimdi rafı boş.
                   -- Satışı olanlar KANITLI TALEP + boş raf = kayıp satış (ölçüldü: 3.539
                   -- çeşit / 10,46M ₺, 1.218'inin satışı var). Transferle çözülür, alımla değil.
                   -- ⚠ DÜZELTME 09.09 (kullanıcı bildirimi, stkID 1697931): ölçüt MagazaStok
                   -- TOPLAMI <= 0 idi ve NEGATİF stoğu maskeliyordu — o üründe FSM 5 adet VARDI
                   -- ama İst.Yolu −13 (veri kiri) toplamı −8 yapıyor, ürün "rafı boş" görünüyordu.
                   -- Doğrusu: ÜÇ RAFIN HEPSİ boş. Ölçüldü: 3.539 → 3.533 çeşit (6'sı aslında
                   -- rafta vardı), tutar 10,46M → 10,27M ₺.
                   SUM(CASE WHEN t.IlkGiris IS NOT NULL AND t.MerkezStok > 0
                                 AND t.StokFsm <= 0 AND t.StokOzl <= 0 AND t.StokIst <= 0
                            THEN 1 ELSE 0 END)                                             AS RafBosCesit,
                   CONVERT(decimal(18,2), SUM(CASE WHEN t.IlkGiris IS NOT NULL AND t.MerkezStok > 0
                        AND t.StokFsm <= 0 AND t.StokOzl <= 0 AND t.StokIst <= 0 THEN t.Tutar ELSE 0 END))                      AS RafBosTutar,
                   SUM(CASE WHEN t.IlkGiris IS NOT NULL AND t.MerkezStok > 0
                            AND t.StokFsm <= 0 AND t.StokOzl <= 0 AND t.StokIst <= 0
                            AND t.SatisToplam > 0 THEN 1 ELSE 0 END)                       AS RafBosSatisliCesit,
                   -- ⚠ GENİŞLETİLDİ 09.09: eski ölçüt yalnız TOPLAM negatifi görüyordu; merkez
                   -- pozitifse mağaza rafındaki eksi stok gizleniyordu (ölçüldü: 187 çeşit /
                   -- 4,89M ₺ hiçbir ölçütte görünmüyordu; mağaza raflarında −8.160 adet negatif).
                   -- Vaka: stkID 1697931 FSM 5 · İst.Yolu −13 · merkez 600 → toplam 592 "temiz".
                   SUM(CASE WHEN t.StokFsm < 0 OR t.StokOzl < 0 OR t.StokIst < 0 OR t.MerkezStok < 0 OR t.ToplamStok < 0 OR t.SatisFiyat <= 0 THEN 1 ELSE 0 END)  AS KirliCesit,
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
            MagazaStok: satirlar.Sum(x => x.MagazaStok),
            MerkezStok: satirlar.Sum(x => x.MerkezStok),
            PerakendeSatis365: satirlar.Sum(x => x.Satis365),
            MerkezCikis365: merkezCikis.Evrende,
            MerkezCikisEvrenDisi: merkezCikis.EvrenDisi,
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
            RafsizCesit: satirlar.Sum(x => x.RafsizCesit),
            RafsizTutar: satirlar.Sum(x => x.RafsizTutar),
            RafBosCesit: satirlar.Sum(x => x.RafBosCesit),
            RafBosTutar: satirlar.Sum(x => x.RafBosTutar),
            RafBosSatisliCesit: satirlar.Sum(x => x.RafBosSatisliCesit),
            VeriKirliCesit: satirlar.Sum(x => x.KirliCesit),
            VeriKirliTutar: satirlar.Sum(x => x.KirliTutar),
            // Hızlar ürün bazında kendi raf süresine bölünüp SQL'de toplandı → burada topla, BÖLME.
            PerakendeGunlukHiz: satirlar.Sum(x => x.GunlukHiz));

        var kirilim = satirlar.Select(x => new SatisAnaliziKirilim(
            x.Ad, x.Cesit, x.Stok, x.Tutar, x.Satis365, x.Sezon, x.StoksuzCesit, x.AsiriTutar,
            GunlukHiz: x.GunlukHiz)).ToList();

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
                   CONVERT(float, SUM(CONVERT(float, t.SatisToplam) / CASE
                       WHEN t.IlkGiris IS NULL THEN 365.0
                       WHEN DATEDIFF(DAY, t.IlkGiris, t.Kesim) + 1 < 365 THEN DATEDIFF(DAY, t.IlkGiris, t.Kesim) + 1
                       ELSE 365.0 END)) AS GunlukHiz,
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
                   CONVERT(float, SUM(CONVERT(float, t.SatisToplam) / CASE
                       WHEN t.IlkGiris IS NULL THEN 365.0
                       WHEN DATEDIFF(DAY, t.IlkGiris, t.Kesim) + 1 < 365 THEN DATEDIFF(DAY, t.IlkGiris, t.Kesim) + 1
                       ELSE 365.0 END)) AS GunlukHiz,
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
    /// Raf gün-stoğuna GİRMEZ; ayrı gösterilir. Çıkış ayrıca SIÇRAMALI (%67 tek günde) →
    /// merkez için gün-stok hesaplanmaz.
    ///
    /// ⚠ İKİ SAYI DÖNER — ÇELİŞKİYİ ÖNLEMEK İÇİN (09.09.2026):
    /// İlk sürüm TÜM evreni sayıyordu (1.895.799) ama ürün-bazlı <c>MerkezCikis</c> kolonunun
    /// toplamı 1.215.293'tü; ekranda aynı şey için iki rakam görünüyordu. Sebep ÖLÇÜLDÜ:
    /// merkez çıkışının 1.139 çeşidi / 670.659 adedi panel evreninin (Kategori3'ün 12 değeri)
    /// DIŞINDA. Artık <c>Evrende</c> = panelin kendi evreni (kolon toplamıyla tutar),
    /// <c>EvrenDisi</c> = kategori filtresi yüzünden görünmeyen kısım — ekranda AYRI yazılır,
    /// sessizce yutulmaz (kapsam hatası #2, Excel denetimi 08.09).
    /// </summary>
    private static async Task<(long Evrende, long EvrenDisi)> MerkezCikisAsync(
        System.Data.Common.DbConnection conn, SatisAnaliziFiltre f, CancellationToken ct)
    {
        const string sql = """
            SELECT CONVERT(bigint, ISNULL(SUM(CASE WHEN t.stkID IS NOT NULL THEN x.Cikis END), 0)) AS Evrende,
                   CONVERT(bigint, ISNULL(SUM(CASE WHEN t.stkID IS NULL     THEN x.Cikis END), 0)) AS EvrenDisi
            FROM (
                SELECT h.ehstkID AS stkID, -SUM(h.ehAdetN) AS Cikis
                FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
                WHERE h.ehMekan = 12 AND h.ehTip IN (1, 3, 5, 101)
                  AND h.ehTrhS >= @bas AND h.ehTrhS < DATEADD(DAY, 1, @kesim)
                GROUP BY h.ehstkID
                HAVING -SUM(h.ehAdetN) > 0
            ) x
            LEFT JOIN DerinSISBkm.bkm.SatisAnaliziTaban t WITH (NOLOCK)
                   ON t.stkID = x.stkID AND t.Kesim = @kesim AND t.SezonYil = @sezon
            """;
        var cmd = new CommandDefinition(sql,
            new
            {
                bas = f.Baslangic.ToDateTime(TimeOnly.MinValue),
                kesim = f.Kesim.ToDateTime(TimeOnly.MinValue),
                sezon = (short)f.SezonYil,
            },
            commandTimeout: 180, cancellationToken: ct);
        var r = await conn.QuerySingleAsync<(long Evrende, long EvrenDisi)>(cmd);
        return r;
    }

    private sealed record OzetSatirRow(
        string Ad, int Cesit, long Stok, long MagazaStok, long MerkezStok, decimal Tutar, long Satis365, double GunlukHiz, long Sezon,
        int StoksuzCesit, decimal StoksuzKayip, int StoksuzOdakCesit, decimal StoksuzOdakKayip,
        int AsiriCesit, decimal AsiriTutar, int AsiriOdakCesit, decimal AsiriOdakTutar,
        int HareketsizCesit, decimal HareketsizTutar,
        int RafsizCesit, decimal RafsizTutar,
        int RafBosCesit, decimal RafBosTutar, int RafBosSatisliCesit,
        int KirliCesit, decimal KirliTutar);
}

/// <summary>Sayfa açılışında tek geçişte gelen özet: KPI + Kategori3 kırılımı.</summary>
public sealed record SatisAnaliziOzet(SatisAnaliziKpi Kpi, IReadOnlyList<SatisAnaliziKirilim> Kategori3);

/// <summary>ODAK temin süresi bandı kırılımı.</summary>
public sealed record TeminKirilim(string Ad, int Sira, int Cesit, decimal Tutar, long OdakStok);
