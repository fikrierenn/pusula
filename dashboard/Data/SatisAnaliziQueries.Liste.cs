using Dapper;
using GmDashboard.Models;

namespace GmDashboard.Data;

// SatisAnaliziQueries partial (dosya-boyutu disiplini) — filtreli/sayfalı ürün listesi.
// Özet/kırılım sorguları SatisAnaliziQueries.cs'te.
public sealed partial class SatisAnaliziQueries
{
    /// <summary>
    /// Sıralama anahtarı → kolon. WHITELIST: kullanıcı girdisi ASLA SQL'e gömülmez
    /// (security-principles §2). Tanınmayan anahtar varsayılana düşer.
    /// Anahtarlar <see cref="SatisAnaliziKolonlar"/> ile aynı isimleri taşır (tek sözleşme).
    /// </summary>
    private static readonly Dictionary<string, string> SiralamaHaritasi = new(StringComparer.OrdinalIgnoreCase)
    {
        ["tutar"] = "t.Tutar",
        ["stok"] = "t.ToplamStok",
        ["satis"] = "t.SatisToplam",
        ["sezon"] = "t.SezonToplam",
        ["odak"] = "t.OdakStok",
        ["leadtime"] = "t.LeadTime",
        ["fiyat"] = "t.SatisFiyat",
        ["stkid"] = "t.stkID",
        ["kategori3"] = "t.Kategori3",
        ["kategori1"] = "t.Kategori1",
        ["yayinevi"] = "t.Yayinevi",
        ["ad"] = "t.stkAd",
        ["stok_fsm"] = "t.StokFsm",
        ["stok_ozl"] = "t.StokOzl",
        ["stok_ist"] = "t.StokIst",
        ["magaza_stok"] = "t.MagazaStok",
        ["merkez_stok"] = "t.MerkezStok",
        ["satis_fsm"] = "t.SatisFsm",
        ["satis_ozl"] = "t.SatisOzl",
        ["satis_ist"] = "t.SatisIst",
        ["sezon_ay1"] = "t.Ay1",
        ["sezon_ay2"] = "t.Ay2",
        ["sezon_ay3"] = "t.Ay3",
        ["ilkgiris"] = "t.IlkGiris",
        ["songiris"] = "t.SonGiris",
        ["acilis"] = "t.AcilisTarihi",
    };

    /// <summary>
    /// ⚠ SIRA SÖZLEŞMESİ: Dapper konumsal record'da SELECT kolon sırası ctor sırasıyla
    /// AYNI olmalı. Ölçüldü 09.09.2026: <c>SonGirisTarihi</c>'ni yanlış yere koyunca
    /// "A parameterless default constructor or one matching signature ... is required"
    /// hatası verdi (sessiz yanlış map DEĞİL — patlıyor, iyi haber).
    /// Kolon eklerken <see cref="SatisAnaliziSatir"/> ctor sırasını takip et.
    /// </summary>
    private const string ListeKolonlar = """
        t.stkID AS StkId, t.Kategori3, t.BarkodAna, t.stkAd AS StkAd, t.Kategori1,
        t.Yayinevi, t.Yazar, t.SatisFiyat, t.Tutar AS ToplamStokTutar, t.ToplamStok,
        t.OdakStok, t.IlkGiris AS IlkGirisTarihi, t.SonGiris AS SonGirisTarihi, t.AcilisTarihi,
        t.StokFsm, t.StokOzl AS StokOzluce, t.StokIst AS StokIstyolu, t.MagazaStok, t.MerkezStok,
        t.SatisFsm, t.SatisOzl AS SatisOzluce, t.SatisIst AS SatisIstyolu, t.SatisToplam,
        t.Ay1 AS SezonAy1, t.Ay2 AS SezonAy2, t.Ay3 AS SezonAy3, t.SezonToplam,
        t.LeadTime, t.OdakDurum AS OdakSatisDurum
        """;

    /// <summary>
    /// Filtreli + sayfalı ürün listesi — ön-agrega tablosundan, index seek.
    /// ÖLÇÜLDÜ: sayfa 1 → 17 ms · derin sayfa (500.) → 534 ms · arama → 346 ms.
    /// ⚠ <c>COUNT(*) OVER ()</c> YOK: sayfa başına 1,2 s ekliyordu. Toplam ayrı ve YALNIZ
    /// gerektiğinde sorulur (34 ms) — <paramref name="toplamGerekli"/>.
    /// </summary>
    public async Task<SayfaSonucu<SatisAnaliziSatir>> GetListeAsync(
        SatisAnaliziFiltre f, bool toplamGerekli = true, int? bilinenToplam = null,
        CancellationToken ct = default)
    {
        var sirala = SiralamaHaritasi.TryGetValue(f.Sirala, out var kolon) ? kolon : "t.Tutar";
        var yon = f.Azalan ? "DESC" : "ASC";
        var sayfaBoyu = Math.Clamp(f.SayfaBoyu, 10, 500);
        var sayfa = Math.Max(1, f.Sayfa);

        var (nerede, p) = Filtre(f);
        p.Add("atla", (sayfa - 1) * sayfaBoyu);
        p.Add("al", sayfaBoyu);

        var sql = $"""
            SELECT {ListeKolonlar}
            FROM {Taban} t WITH (NOLOCK)
            WHERE {nerede}
            ORDER BY {sirala} {yon}, t.stkID
            OFFSET @atla ROWS FETCH NEXT @al ROWS ONLY
            """;

        await using var conn = await db.OpenAsync();
        var satirlar = (await conn.QueryAsync<SatisAnaliziSatir>(
            new CommandDefinition(sql, p, commandTimeout: 120, cancellationToken: ct))).ToList();

        var toplam = bilinenToplam
            ?? (toplamGerekli || satirlar.Count == 0 ? await SayAsync(conn, nerede, p, ct) : satirlar.Count);

        return SayfaSonucu<SatisAnaliziSatir>.Olustur(satirlar, toplam, sayfa, sayfaBoyu);
    }

    /// <summary>Filtreye uyan toplam satır — sayfa çevirmede TEKRAR sorulmaz (34 ms ama gereksiz).</summary>
    public async Task<int> SayAsync(SatisAnaliziFiltre f, CancellationToken ct = default)
    {
        var (nerede, p) = Filtre(f);
        await using var conn = await db.OpenAsync();
        return await SayAsync(conn, nerede, p, ct);
    }

    private static async Task<int> SayAsync(
        System.Data.Common.DbConnection conn, string nerede, DynamicParameters p, CancellationToken ct)
    {
        var sql = $"SELECT COUNT(*) FROM {Taban} t WITH (NOLOCK) WHERE {nerede}";
        return await conn.ExecuteScalarAsync<int>(
            new CommandDefinition(sql, p, commandTimeout: 120, cancellationToken: ct));
    }

    /// <summary>Excel dökümü — TÜM filtreli satırlar (sayfalama yok). Ağır yol, butona basınca.</summary>
    public async Task<IReadOnlyList<SatisAnaliziSatir>> GetTumListeAsync(
        SatisAnaliziFiltre f, int tavan = 300_000, CancellationToken ct = default)
    {
        var sirala = SiralamaHaritasi.TryGetValue(f.Sirala, out var kolon) ? kolon : "t.Tutar";
        var yon = f.Azalan ? "DESC" : "ASC";
        var (nerede, p) = Filtre(f);
        p.Add("tavan", tavan);

        var sql = $"""
            SELECT TOP (@tavan) {ListeKolonlar}
            FROM {Taban} t WITH (NOLOCK)
            WHERE {nerede}
            ORDER BY {sirala} {yon}, t.stkID
            """;
        await using var conn = await db.OpenAsync();
        return (await conn.QueryAsync<SatisAnaliziSatir>(
            new CommandDefinition(sql, p, commandTimeout: 600, cancellationToken: ct))).ToList();
    }

    /// <summary>
    /// TEK ÜRÜN drill verisi. Ayrı sayfa (/satis-analizi/urun/{stkId}) kullanır — modal DEĞİL,
    /// çünkü modal-üstü-modal Blazor'da çalışmıyor (repo dersi) ve drill'den hareket geçmişine
    /// gidilebilmesi gerekiyor.
    /// </summary>
    public async Task<SatisAnaliziSatir?> GetUrunAsync(
        int stkId, DateOnly kesim, int sezonYil, CancellationToken ct = default)
    {
        var sql = $"""
            SELECT {ListeKolonlar}
            FROM {Taban} t WITH (NOLOCK)
            WHERE t.Kesim = @kesim AND t.SezonYil = @sezon AND t.stkID = @stkId
            """;
        await using var conn = await db.OpenAsync();
        return await conn.QuerySingleOrDefaultAsync<SatisAnaliziSatir>(new CommandDefinition(sql,
            new { kesim = kesim.ToDateTime(TimeOnly.MinValue), sezon = (short)sezonYil, stkId },
            commandTimeout: 60, cancellationToken: ct));
    }

    /// <summary>
    /// Drill kıyas tabanı: ürünün Kategori1 akranlarının **MEDYANI**.
    ///
    /// ⚠ ORTALAMA DEĞİL — ölçüldü 09.09.2026: "Hobi ve Oyuncak" 15.251 çeşidin ORTALAMA stoğu
    /// 22 adet çıkıyor (uzun kuyruk: binlerce çeşit 0-2 adet). Tek bir gerçek ürün 18.910 adetle
    /// "+%87.003" gibi anlamsız bir fark üretiyordu. Medyan uzun kuyruğa dayanıklı.
    /// </summary>
    public async Task<AkranOzet?> GetAkranAsync(
        string kategori1, DateOnly kesim, int sezonYil, CancellationToken ct = default)
    {
        var sql = $"""
            SELECT TOP 1
                   COUNT(*) OVER ()                                                        AS Cesit,
                   CONVERT(decimal(18,2), PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY CAST(t.ToplamStok AS float))
                        OVER (PARTITION BY t.Kategori1))                                   AS OrtStok,
                   CONVERT(decimal(18,2), PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY CAST(t.SatisToplam AS float))
                        OVER (PARTITION BY t.Kategori1))                                   AS OrtSatis,
                   CONVERT(decimal(18,2), PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY CAST(t.SezonToplam AS float))
                        OVER (PARTITION BY t.Kategori1))                                   AS OrtSezon,
                   CONVERT(decimal(18,2), PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY CAST(ISNULL(t.LeadTime, 0) AS float))
                        OVER (PARTITION BY t.Kategori1))                                   AS OrtLeadTime,
                   CONVERT(decimal(18,2), PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY
                        CASE WHEN t.SatisToplam > 0
                             THEN CAST(t.ToplamStok AS float) / (CAST(t.SatisToplam AS float) / 365.0) END)
                        OVER (PARTITION BY t.Kategori1))                                   AS OrtGunStok
            FROM {Taban} t WITH (NOLOCK)
            WHERE t.Kesim = @kesim AND t.SezonYil = @sezon AND t.Kategori1 = @kategori1
            """;
        await using var conn = await db.OpenAsync();
        return await conn.QuerySingleOrDefaultAsync<AkranOzet>(new CommandDefinition(sql,
            new { kesim = kesim.ToDateTime(TimeOnly.MinValue), sezon = (short)sezonYil, kategori1 },
            commandTimeout: 120, cancellationToken: ct));
    }

    /// <summary>
    /// GİRİŞ MALİYETİ — tek ürün, drill için (kullanıcı isteği 09.09).
    ///
    /// KANONİK TANIM (sema/metrics.yaml → birim_maliyet, 15.06 "TEK KAYNAK, her yerde bu"):
    /// <c>COALESCE(MLYT, ORT_ALIS, SONRAKI, 0)</c> — MLYT = SON 5 ALIŞ FATURASI'nın
    /// <c>SUM(ehTutarN)/SUM(ehAdetN)</c>'i (fatura-bazında topla-böl, satır-bazında DEĞİL).
    /// Süzgeç: <c>f.eTip = 0</c> (alış) AND <c>f.eDurum &lt;&gt; 2</c> (iptal hariç).
    ///
    /// Burada YALNIZ MLYT hesaplanır; fallback'ler (ORT_ALIS materialize, sonraki-alış) tek ürün
    /// ekranında YOK — bulunamazsa "maliyet kaydı yok" YAZILIR, 0 gösterilmez.
    /// Gerekçe: 0 maliyet marjı %100 gösterir, sessiz yanlış rakam olur (error-handling § sessiz fallback yasak).
    /// ⚠ <c>ehMaliyet</c> KULLANILMAZ: alış faturasında 0 olabiliyor (maliyet ayrı job ile güncellenir).
    /// </summary>
    public async Task<UrunMaliyet?> GetMaliyetAsync(int stkId, CancellationToken ct = default)
    {
        const string sql = """
            SELECT m.Adet, m.Tutar,
                   CONVERT(decimal(18,4), m.Tutar / NULLIF(m.Adet, 0)) AS BirimMaliyet,
                   m.FaturaSayisi, m.SonAlis, m.SonAlisAdet
            FROM (
                SELECT SUM(x.adet) AS Adet, SUM(x.tutar) AS Tutar, COUNT(*) AS FaturaSayisi,
                       MAX(x.eTarih) AS SonAlis,
                       CONVERT(decimal(18,2), MAX(CASE WHEN x.sira = 1 THEN x.adet END)) AS SonAlisAdet
                FROM (
                    SELECT TOP 5 f.eID, f.eTarih,
                           SUM(fa.ehAdetN) AS adet, SUM(fa.ehTutarN) AS tutar,
                           ROW_NUMBER() OVER (ORDER BY f.eTarih DESC, f.eID DESC) AS sira
                    FROM DerinSISBkm.dbo.fatAyr fa WITH (NOLOCK)
                    JOIN DerinSISBkm.dbo.fat f WITH (NOLOCK) ON f.eID = fa.ehID
                    WHERE fa.ehstkID = @stkId AND f.eTip = 0 AND f.eDurum <> 2
                    GROUP BY f.eID, f.eTarih
                    ORDER BY f.eTarih DESC, f.eID DESC
                ) x
            ) m
            WHERE m.Adet IS NOT NULL AND m.Adet <> 0
            """;
        await using var conn = await db.OpenAsync();
        return await conn.QuerySingleOrDefaultAsync<UrunMaliyet>(
            new CommandDefinition(sql, new { stkId }, commandTimeout: 60, cancellationToken: ct));
    }

    /// <summary>
    /// AYLIK SATIŞ SERİSİ — tek ürün, 365 günlük pencere (kullanıcı isteği 09.09).
    ///
    /// Tabanda aylık seri YOK (kesim başına tek satır) → canlı <c>irsHrk</c>'dan çekilir.
    /// Tek stkID + indexli (<c>IX_irsH_ehStkID</c>) olduğu için ucuz. Panelin TAMAMI için
    /// aylık seri üretilmez — 275K ürün × 12 ay taban tasarımını bozar.
    ///
    /// NEDEN DEĞERLİ (ölçüldü 09.09): "Bricks Lego" sezon kapsaması 8,5x görünüyordu ama aylık
    /// seri zirvenin OCAK (5.021) ve MART (4.550) olduğunu gösteriyor — ürün sezonluk DEĞİL,
    /// yani sezon kapsaması o üründe yanıltıcıydı. Grafik bu yanılgıyı doğrudan düzeltiyor.
    ///
    /// Boş aylar 0 ile DOLDURULUR (çağıran tarafta) — eksik ay grafikte boşluk bırakırsa
    /// "veri yok" ile "satış yok" karışır.
    /// </summary>
    public async Task<IReadOnlyList<AylikSatis>> GetAylikSatisAsync(
        int stkId, DateOnly kesim, CancellationToken ct = default)
    {
        const string sql = """
            SELECT DATEFROMPARTS(YEAR(h.ehTrhS), MONTH(h.ehTrhS), 1) AS Ay,
                   CONVERT(int, -SUM(h.ehAdetN)) AS Adet
            FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
            WHERE h.ehstkID = @stkId
              AND h.ehMekan IN (1, 4477, 4478)
              AND h.ehTip IN (1, 3, 4, 5, 100, 101)
              AND h.ehTrhS >= @bas AND h.ehTrhS < DATEADD(DAY, 1, @kesim)
            GROUP BY DATEFROMPARTS(YEAR(h.ehTrhS), MONTH(h.ehTrhS), 1)
            ORDER BY 1
            """;
        await using var conn = await db.OpenAsync();
        var ham = (await conn.QueryAsync<AylikSatis>(new CommandDefinition(sql,
            new
            {
                stkId,
                bas = kesim.AddDays(-364).ToDateTime(TimeOnly.MinValue),
                kesim = kesim.ToDateTime(TimeOnly.MinValue),
            }, commandTimeout: 60, cancellationToken: ct))).ToList();

        // Boş ayları 0 ile doldur — "veri yok" ile "satış yok" karışmasın.
        var basAy = new DateTime(kesim.AddDays(-364).Year, kesim.AddDays(-364).Month, 1);
        var sonAy = new DateTime(kesim.Year, kesim.Month, 1);
        var harita = ham.ToDictionary(x => x.Ay, x => x.Adet);
        var tam = new List<AylikSatis>();
        for (var a = basAy; a <= sonAy; a = a.AddMonths(1))
            tam.Add(new AylikSatis(a, harita.GetValueOrDefault(a)));
        return tam;
    }

    /// <summary>
    /// AÇIK SİPARİŞ (yolda mal) — kurulun "en kritik eksik" dediği madde (satinalma-danisman 08.09).
    ///
    /// KAYNAK sema'dan (metrics.yaml → bulunurluk_osa.mal_yolda_kontrolu): <c>dbo.sip</c> +
    /// <c>dbo.sipAyr</c>, <c>eDurum &lt;&gt; 2</c>.
    /// ⚠ TARİH TUZAĞI: <c>s.eTarih</c> kullanılır — <c>eTarihS</c> DEĞİL (sema'da belgeli).
    /// ⚠ SINIR (sema, birebir): "Yalnız VAR/YOK okunur; karşılanma oranı ölçülemiyor
    ///   (ehSevkAdet NULL)". Bu adet SİPARİŞ EDİLEN'dir, "yolda kalan" DEĞİL — bir kısmı gelmiş
    ///   olabilir. Ekranda böyle yazılır.
    /// Ölçüm 09.09 (stkID 1701128): 8 belge / 10.528 adet, son 04.09.2026 — elde 9.846 stok varken.
    /// </summary>
    public async Task<AcikSiparis?> GetAcikSiparisAsync(
        int stkId, int gunPenceresi = 120, CancellationToken ct = default)
    {
        const string sql = """
            SELECT COUNT(DISTINCT s.eID)                  AS Belge,
                   CONVERT(decimal(18,2), SUM(sa.ehAdet)) AS SiparisAdet,
                   MAX(s.eTarih)                          AS SonSiparis
            FROM DerinSISBkm.dbo.sip s WITH (NOLOCK)
            JOIN DerinSISBkm.dbo.sipAyr sa WITH (NOLOCK) ON sa.ehID = s.eID
            WHERE sa.ehstkID = @stkId AND s.eDurum <> 2
              AND s.eTarih >= DATEADD(DAY, -@gun, GETDATE())
            """;
        await using var conn = await db.OpenAsync();
        var r = await conn.QuerySingleOrDefaultAsync<AcikSiparis>(new CommandDefinition(sql,
            new { stkId, gun = gunPenceresi }, commandTimeout: 60, cancellationToken: ct));
        return r is null || r.Belge == 0 ? null : r;
    }

    /// <summary>
    /// AYLIK ALIŞ SERİSİ — satışın yanına konur ki "alım talebi takip ediyor mu" görünsün.
    /// Alış = <c>ehTip IN (0, 10)</c> (Alış + Yerel Alım), adet POZİTİF (giriş).
    /// Mekan: 3 mağaza + merkez depo (12) — mal merkeze de gelir, dışlanırsa alım görünmez.
    /// </summary>
    public async Task<IReadOnlyList<AylikSatis>> GetAylikAlisAsync(
        int stkId, DateOnly kesim, CancellationToken ct = default)
    {
        const string sql = """
            SELECT DATEFROMPARTS(YEAR(h.ehTrhS), MONTH(h.ehTrhS), 1) AS Ay,
                   CONVERT(int, SUM(h.ehAdetN)) AS Adet
            FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
            WHERE h.ehstkID = @stkId AND h.ehTip IN (0, 10)
              AND h.ehMekan IN (1, 4477, 4478, 12)
              AND h.ehTrhS >= @bas AND h.ehTrhS < DATEADD(DAY, 1, @kesim)
            GROUP BY DATEFROMPARTS(YEAR(h.ehTrhS), MONTH(h.ehTrhS), 1)
            ORDER BY 1
            """;
        await using var conn = await db.OpenAsync();
        var ham = (await conn.QueryAsync<AylikSatis>(new CommandDefinition(sql,
            new
            {
                stkId,
                bas = kesim.AddDays(-364).ToDateTime(TimeOnly.MinValue),
                kesim = kesim.ToDateTime(TimeOnly.MinValue),
            }, commandTimeout: 60, cancellationToken: ct))).ToList();

        var basAy = new DateTime(kesim.AddDays(-364).Year, kesim.AddDays(-364).Month, 1);
        var sonAy = new DateTime(kesim.Year, kesim.Month, 1);
        var harita = ham.ToDictionary(x => x.Ay, x => x.Adet);
        var tam = new List<AylikSatis>();
        for (var a = basAy; a <= sonAy; a = a.AddMonths(1))
            tam.Add(new AylikSatis(a, harita.GetValueOrDefault(a)));
        return tam;
    }

    /// <summary>
    /// ÜRÜN GÖRSELİ — <c>ent.tsoft_urun.stkid = urn.stkID</c>, tam URL
    /// <c>https://cdn.bkmkitap.com/</c> + <c>ImageUrl</c>.
    ///
    /// KAYNAK sema'dan (bridges.yaml → tsoft-urun-resim): "Satınalma ürün-detay görseli bunu
    /// kullanır" — yerleşik desen, yeniden icat edilmedi. Kullanıcı da oraya işaret etti.
    /// ⚠ CDN HOTLINK korumalı → <c>&lt;img referrerpolicy="no-referrer"&gt;</c> ŞART
    ///   (referer'lı istek placeholder döner, sema notu).
    ///
    /// NEDEN BKMDATA binary DEĞİL: <c>odak_urun_tam.urun_gorsel_url</c> sorgu dizesinde
    /// <b>authToken</b> taşıyor — tarayıcıya verilemez (security-principles). Binary'yi servis
    /// etmek ayrı endpoint gerektiriyordu; tsoft yolu hem belgeli hem doğrudan stkID.
    /// Alternatif (kullanılmadı): DerinSISBkmWeb.web.urnWeb.urnWebResim — DB-içi binary, kapsamı ölçülmedi.
    ///
    /// ÖLÇÜM 09.09: 438.360 satır = 438.360 tekil stkID (fan-out YOK) · 438.335'inde görsel var ·
    /// slug ürün adıyla %99,8 uyuşuyor (1.987 örnekte 4 uyumsuz) → nadir vakada yanlış görsel
    /// görünebilir, o yüzden ekranda küçük tutulur ve karara dayanak yapılmaz.
    /// </summary>
    public async Task<string?> GetResimUrlAsync(int stkId, CancellationToken ct = default)
    {
        const string sql = """
            SELECT TOP 1 t.ImageUrl
            FROM DerinSISBkm.ent.tsoft_urun t WITH (NOLOCK)
            WHERE t.stkid = @stkId AND t.ImageUrl IS NOT NULL AND t.ImageUrl <> ''
            """;
        await using var conn = await db.OpenAsync();
        var ad = await conn.ExecuteScalarAsync<string?>(
            new CommandDefinition(sql, new { stkId }, commandTimeout: 30, cancellationToken: ct));
        return string.IsNullOrWhiteSpace(ad) ? null : "https://cdn.bkmkitap.com/" + ad;
    }

    /// <summary>WHERE + parametreler. Tek yerde kurulur → liste/sayım/Excel AYRIŞMAZ.</summary>
    private static (string Nerede, DynamicParameters P) Filtre(SatisAnaliziFiltre f)
    {
        var p = new DynamicParameters(KesimP(f));
        var sartlar = new List<string> { "t.Kesim = @kesim AND t.SezonYil = @sezon" };

        // TAZE STOK: son N günde mal kabulü olanlar değerlendirmeden çıkar (KPI ile AYNI şart).
        if (f.TazeGunHaric > 0)
            sartlar.Add("(t.SonGiris IS NULL OR t.SonGiris < DATEADD(DAY, -@taze, @kesim))");

        if (!string.IsNullOrWhiteSpace(f.Kategori3)) { sartlar.Add("t.Kategori3 = @kategori3"); p.Add("kategori3", f.Kategori3); }
        if (!string.IsNullOrWhiteSpace(f.Kategori1)) { sartlar.Add("t.Kategori1 = @kategori1"); p.Add("kategori1", f.Kategori1); }

        if (f.MinYasYil > 0)
        {
            sartlar.Add("(t.AcilisTarihi IS NOT NULL AND t.AcilisTarihi <= DATEADD(YEAR, -@minYas, @kesim))");
            p.Add("minYas", f.MinYasYil);
        }

        if (f.OdakVar == true) sartlar.Add("t.OdakStok > 0");
        else if (f.OdakVar == false) sartlar.Add("t.OdakStok <= 0");

        if (f.Mekan == 1) sartlar.Add("(t.StokFsm <> 0 OR t.SatisFsm <> 0)");
        else if (f.Mekan == 4477) sartlar.Add("(t.StokOzl <> 0 OR t.SatisOzl <> 0)");
        else if (f.Mekan == 4478) sartlar.Add("(t.StokIst <> 0 OR t.SatisIst <> 0)");

        var durumSart = f.Durum switch
        {
            SatisDurumFiltre.StoksuzSezon => "(t.SezonToplam > 0 AND t.ToplamStok <= 0)",
            SatisDurumFiltre.AsiriStok => "(t.SezonToplam > 0 AND t.ToplamStok > 5 * t.SezonToplam)",
            SatisDurumFiltre.Hareketsiz => "(t.SatisToplam <= 0 AND t.ToplamStok > 0)",
            SatisDurumFiltre.VeriKirli => "(t.ToplamStok < 0 OR t.SatisFiyat <= 0)",
            // Filtrenin TERSİ: yalnız taze stok. TazeGunHaric ile birlikte kullanılmaz (biri diğerini boşaltır).
            SatisDurumFiltre.SadeceTaze => "(t.SonGiris >= DATEADD(DAY, -@tazeGun, @kesim))",
            _ => null,
        };
        if (durumSart is not null) sartlar.Add(durumSart);
        if (f.Durum == SatisDurumFiltre.SadeceTaze)
            p.Add("tazeGun", f.TazeGunHaric > 0 ? f.TazeGunHaric : 90);   // kapalıysa varsayılan 90 gün

        if (!string.IsNullOrWhiteSpace(f.Arama))
        {
            var q = f.Arama.Trim();
            // stkID / barkod tam eşleşme + ad LIKE. Tabanda barkod ve ad zaten duruyor →
            // canlı urn/urnBrkd'a gitmeye gerek yok (CTE sürümünde 5,8 s riski vardı).
            sartlar.Add("(t.stkAd LIKE @aramaLike OR t.BarkodAna = @arama OR CAST(t.stkID AS varchar(20)) = @arama)");
            p.Add("arama", q);
            p.Add("aramaLike", "%" + q + "%");
        }

        return (string.Join(" AND ", sartlar), p);
    }
}

/// <summary>Akran (aynı Kategori1) MEDYANLARI — drill'de kıyas tabanı. Ortalama değil (uzun kuyruk).</summary>
public sealed record AkranOzet(
    int Cesit, decimal? OrtStok, decimal? OrtSatis, decimal? OrtSezon,
    decimal? OrtLeadTime, decimal? OrtGunStok);

/// <summary>
/// Giriş maliyeti — son 5 alış faturasının ağırlıklı birimi (kanonik MLYT).
/// <c>BirimMaliyet</c> null ise maliyet kaydı YOK; 0 gösterilmez.
/// </summary>
public sealed record UrunMaliyet(
    decimal Adet, decimal Tutar, decimal? BirimMaliyet, int FaturaSayisi,
    DateTime? SonAlis, decimal? SonAlisAdet);

/// <summary>Bir ayın net satış adedi (iade netlenmiş, 3 mağaza).</summary>
public sealed record AylikSatis(DateTime Ay, int Adet);

/// <summary>
/// Açık sipariş özeti. ⚠ SiparisAdet = SİPARİŞ EDİLEN adet, "yolda kalan" değil
/// (karşılanma oranı ölçülemiyor — sema: ehSevkAdet NULL).
/// </summary>
public sealed record AcikSiparis(int Belge, decimal? SiparisAdet, DateTime? SonSiparis);

