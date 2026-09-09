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
        t.LeadTime, t.OdakDurum AS OdakSatisDurum,
        -- MERKEZ ÇIKIŞI (365g) — toptan/grup, tüketici talebi DEĞİL. Gün-stok kapsam
        -- asimetrisini kapatmak için ayrı ölçülür (bkz. SatisAnaliziSatir.MerkezGunStok).
        ISNULL(t.MerkezCikis, 0) AS MerkezCikis,
        -- Kaç ayrı günde çıktı = SIÇRAMALILIK. Hız değil (ölçüldü: %67 tek günde).
        ISNULL(t.MerkezCikisGun, 0) AS MerkezCikisGun,
        -- ETKİN GÜN = satış hızının paydası. min(365, ilk girişten kesime kadar).
        -- ⚠ 365'e SABİT bölmek YANLIŞ (kullanıcı uyarısı 09.09): rafa yeni giren ürünün hızı
        -- düşük çıkıyor, gün-stok şişiyor. ÖLÇÜLDÜ: 22.385 üründe ort. gün-stok 1.644 → 524,
        -- 4.468 ürün haksız yere ">400 gün" kırmızısında.
        -- İlk giriş NULL ise 365 (1.186 ürün) — bilinmeyen için pencerenin tamamı varsayılır.
        CASE WHEN t.IlkGiris IS NULL THEN 365
             WHEN DATEDIFF(DAY, t.IlkGiris, t.Kesim) + 1 < 365 THEN DATEDIFF(DAY, t.IlkGiris, t.Kesim) + 1
             ELSE 365 END AS EtkinGun
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
                             -- Etkin güne göre (365 sabit DEĞİL — 09.09 düzeltmesi).
                             THEN CAST(t.ToplamStok AS float) / (CAST(t.SatisToplam AS float) /
                                  CASE WHEN t.IlkGiris IS NULL THEN 365.0
                                       WHEN DATEDIFF(DAY, t.IlkGiris, t.Kesim) + 1 < 365 THEN DATEDIFF(DAY, t.IlkGiris, t.Kesim) + 1
                                       ELSE 365.0 END) END)
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
                   m.FaturaSayisi, m.SonAlis, m.SonAlisAdet,
                   -- CAST AS int ZORUNLU: kdvYuzde tinyint → record int? ile eşleşmez
                   -- (sql-server-conventions § Dapper Record smallint/tinyint). Ölçüldü: patladı.
                   -- ⚠ LOOKUP dbo.urnKDV — kdvYuzde_vw DEĞİL: o view her orana ait yalnız İLK
                   -- kodu verip Hizmet/Hammadde varyantlarını (5,8,9,10) atıyordu → 41 üründe
                   -- oran çözülemiyordu (26'sının satışı var, 376.028 ₺ stok). urnKDV'de öksüz 0.
                   (SELECT CONVERT(int, MAX(k.kdvYuzde)) FROM DerinSISBkm.dbo.urn u WITH (NOLOCK)
                    JOIN DerinSISBkm.dbo.urnKDV k ON k.kdvID = u.KDVs
                    WHERE u.stkID = @stkId) AS KdvOran
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

    /// <summary>
    /// AYLIK KAPANIŞ STOĞU — satış grafiğinin üstüne çizgi olarak konur (kullanıcı isteği 09.09).
    ///
    /// ⚠ YALNIZ MAĞAZA STOĞU (mekan 1/4477/4478). Merkez depo DIŞARIDA, iki sebeple:
    ///   · WMS geçmiş snapshot tutmuyor → merkez geçmişi zaten üretilemiyor.
    ///   · Merkez defteri (mekan 12) bozuk: negatif bakiye taşıyor (sql-server-conventions
    ///     § MERKEZ DEPO STOĞU). Kümülatife katılırsa çizgi yanlış olur.
    /// Ekran etiketinde bu sınır YAZILIR.
    ///
    /// Yöntem: pencere başından ÖNCEKİ kümülatif bakiye (taban) + aylık net delta (TÜM ehTip —
    /// satış/alış/transfer/sayım hepsi, çünkü stok bakiyesi hepsinden etkilenir), C# tarafında
    /// kümülatif toplanır.
    /// </summary>
    public async Task<IReadOnlyList<AylikSatis>> GetAylikStokAsync(
        int stkId, DateOnly kesim, CancellationToken ct = default)
    {
        const string sql = """
            SELECT CONVERT(int, ISNULL((
                       SELECT SUM(g.ehAdetN) FROM DerinSISBkm.dbo.irsHrk g WITH (NOLOCK)
                       WHERE g.ehstkID = @stkId AND g.ehMekan IN (1, 4477, 4478)
                         AND g.ehTrhS < @bas), 0)) AS Taban;

            SELECT DATEFROMPARTS(YEAR(h.ehTrhS), MONTH(h.ehTrhS), 1) AS Ay,
                   CONVERT(int, SUM(h.ehAdetN)) AS Adet
            FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
            WHERE h.ehstkID = @stkId AND h.ehMekan IN (1, 4477, 4478)
              AND h.ehTrhS >= @bas AND h.ehTrhS < DATEADD(DAY, 1, @kesim)
            GROUP BY DATEFROMPARTS(YEAR(h.ehTrhS), MONTH(h.ehTrhS), 1)
            ORDER BY 1
            """;
        var bas = kesim.AddDays(-364).ToDateTime(TimeOnly.MinValue);
        await using var conn = await db.OpenAsync();
        await using var grid = await conn.QueryMultipleAsync(new CommandDefinition(sql,
            new { stkId, bas, kesim = kesim.ToDateTime(TimeOnly.MinValue) },
            commandTimeout: 60, cancellationToken: ct));
        var taban = await grid.ReadSingleAsync<int>();
        var delta = (await grid.ReadAsync<AylikSatis>()).ToDictionary(x => x.Ay, x => x.Adet);

        var basAy = new DateTime(bas.Year, bas.Month, 1);
        var sonAy = new DateTime(kesim.Year, kesim.Month, 1);
        var kumulatif = taban;
        var seri = new List<AylikSatis>();
        for (var a = basAy; a <= sonAy; a = a.AddMonths(1))
        {
            kumulatif += delta.GetValueOrDefault(a);
            seri.Add(new AylikSatis(a, kumulatif));
        }
        return seri;
    }

    /// <summary>
    /// SEZON / SEZON-DIŞI GÜNLÜK SATIŞ HIZI — tükenme hesabı için (kullanıcı isteği 09.09:
    /// "sezon ve sezon dışı satış ortalamaları ile tükenme ağırlığı hesaplanmalı").
    ///
    /// NEDEN düz 365 günlük ortalama yetmiyor: aynı ürün sezonda ve sezon dışında farklı hızda
    /// erir; tek ortalama ikisini de yanlış gösterir. Ölçülen iki uç (09.09.2026, kesim 08.09):
    ///   · stkID 1701128 (Penna kırtasiye): sezon 0,196 ad/gün · dışı 0,015 → sezon 13 KAT hızlı.
    ///   · stkID 1672852 (Bricks Lego):     sezon 63,6 ad/gün · dışı 93,6 → sezon DIŞI daha hızlı,
    ///     yani ürün sezonluk DEĞİL. "Sezon = hızlı" varsayımı ürün bazında yanlış olabiliyor.
    /// Bu yüzden hız ürün bazında ÖLÇÜLÜR, varsayılmaz.
    ///
    /// Sezon ayları = <b>Ağustos–Ekim</b> — raporun (ve <c>SezonToplam</c> kolonunun) tanımı.
    /// ⚠ Şirket geneli adet dağılımı bununla tam örtüşmüyor (ölçüm: Eyl 819K zirve ama Oca 534K
    /// ≈ Eki 507K, Tem 277K en düşük) → "sezon" ürüne göre değişir; ekranda kat farkı gösterilir.
    ///
    /// Satış süzgeci <see cref="GetAylikSatisAsync"/> ile AYNI (<c>ehTip IN (1,3,4,5,100,101)</c>,
    /// iade işaretle netlenir) — ayrışmasın diye tek desen.
    /// Gün sayıları SQL'de sayılmaz, takvimden C# tarafında türetilir (deterministik).
    /// </summary>
    public async Task<UrunHiz> GetHizAsync(
        int stkId, DateOnly kesim, DateTime? ilkGiris, CancellationToken ct = default)
    {
        const string sql = """
            SELECT CONVERT(int, -SUM(CASE WHEN MONTH(h.ehTrhS) IN (8,9,10) THEN h.ehAdetN ELSE 0 END)) AS SezonAdet,
                   CONVERT(int, -SUM(CASE WHEN MONTH(h.ehTrhS) IN (8,9,10) THEN 0 ELSE h.ehAdetN END)) AS DisiAdet
            FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
            WHERE h.ehstkID = @stkId
              AND h.ehMekan IN (1, 4477, 4478)
              AND h.ehTip IN (1, 3, 4, 5, 100, 101)
              AND h.ehTrhS >= @bas AND h.ehTrhS < DATEADD(DAY, 1, @kesim)
            """;
        var bas = kesim.AddDays(-364);
        await using var conn = await db.OpenAsync();
        var ham = await conn.QuerySingleAsync<(int SezonAdet, int DisiAdet)>(
            new CommandDefinition(sql,
                new { stkId, bas = bas.ToDateTime(TimeOnly.MinValue), kesim = kesim.ToDateTime(TimeOnly.MinValue) },
                commandTimeout: 60, cancellationToken: ct));

        // ⚠ PAYDA RAF PENCERESİ (düzeltme 09.09 — kullanıcı uyarısı "stok gireli 365 gün
        // olmadıysa 365'e bölmek mantıksız"). Gün sayımı ürünün mağazada OLDUĞU günlerden
        // başlar; ilk girişten önceki günler ne sezona ne sezon dışına yazılır.
        // İlk giriş bilinmiyorsa pencerenin tamamı sayılır (1.186 ürün — ölçüldü).
        var ilk = ilkGiris is { } ig ? DateOnly.FromDateTime(ig) : bas;
        var sayimBas = ilk > bas ? ilk : bas;

        int sezonGun = 0, disiGun = 0;
        for (var g = sayimBas; g <= kesim; g = g.AddDays(1))
        {
            if (g.Month is 8 or 9 or 10) sezonGun++; else disiGun++;
        }
        return new UrunHiz(ham.SezonAdet, sezonGun, ham.DisiAdet, disiGun,
            RafGun: sezonGun + disiGun);
    }

    /// <summary>
    /// MAĞAZA BAZLI SON SATIŞ — "stok var ama kaç gündür satmıyor" (kullanıcı isteği 09.09).
    ///
    /// NEDEN ÖNEMLİ: toplam 365g satış bir mağazanın ölü rafını gizler. Ölçülen örnek
    /// (stkID 1723863, kesim 08.09.2026): FSM 14 gün, Özlüce ve İst.Yolu 19 gündür satmıyor.
    /// Stoğu olup uzun süre satmayan mağaza = transfer veya fiyat/teşhir sorusu.
    ///
    /// Süzgeç: <c>ehTip IN (1,4,100)</c> — SATIŞ hareketleri (iade 3/5/101 DIŞARIDA; iade bir
    /// satış değil, son satış tarihini ileri taşımamalı). Pencere YOK: son satış 365 günden
    /// eski olabilir ve asıl bilgi tam odur.
    /// </summary>
    public async Task<IReadOnlyList<MagazaSonSatis>> GetMagazaSonSatisAsync(
        int stkId, DateOnly kesim, CancellationToken ct = default)
    {
        const string sql = """
            SELECT CONVERT(int, h.ehMekan) AS Mekan,
                   MAX(h.ehTrhS)           AS SonSatis,
                   CONVERT(int, DATEDIFF(DAY, MAX(h.ehTrhS), @kesim)) AS GunOnce
            FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
            WHERE h.ehstkID = @stkId
              AND h.ehMekan IN (1, 4477, 4478)
              AND h.ehTip IN (1, 4, 100)
              AND h.ehTrhS <= DATEADD(DAY, 1, @kesim)
            GROUP BY h.ehMekan
            """;
        await using var conn = await db.OpenAsync();
        return (await conn.QueryAsync<MagazaSonSatis>(new CommandDefinition(sql,
            new { stkId, kesim = kesim.ToDateTime(TimeOnly.MinValue) },
            commandTimeout: 60, cancellationToken: ct))).ToList();
    }

    /// <summary>
    /// ÜRÜNÜ NEREDEN ALIYORUZ — ODAK temin süresinin geçerli olup olmadığını söyler.
    ///
    /// NEDEN: <c>LeadTime</c> ODAK'ın kendi katalog süresidir (BKMDATA.dbo.OdakUrunDurum).
    /// Ürünü ODAK'tan almıyorsak o süre BİZİM tedarik süremiz değildir — kullanıcı uyarısı
    /// 09.09: "ürünler odaktan gelmiyorsa temin süresi bilgisi anlamsız oluyor".
    /// ÖLÇÜLDÜ (leadTime'ı olan 210.631 çeşit, son 365 gün alış faturaları):
    ///   yalnız ODAK 96.208 · ODAK+başka 3.536 · ODAK DIŞI 7.906 · hiç alış yok 102.981.
    /// Yani %4'ünde süre YANILTICI, %49'unda DOĞRULANAMAZ.
    ///
    /// ODAK tedarikçi kimliği <c>frm 9525 = ODAK KİTAP-POİNT</c> (sema: alımın ~%40'ı).
    /// Süzgeç <c>eTip=0</c> (alış) + <c>eDurum&lt;&gt;2</c> (iptal hariç) — maliyet sorgusuyla aynı.
    /// </summary>
    public async Task<UrunTedarik?> GetTedarikAsync(
        int stkId, DateOnly kesim, CancellationToken ct = default)
    {
        const string sql = """
            SELECT CONVERT(int, ISNULL(SUM(CASE WHEN f.eFirma = 9525 THEN fa.ehAdetN END), 0)) AS OdakAdet,
                   CONVERT(int, ISNULL(SUM(CASE WHEN f.eFirma <> 9525 THEN fa.ehAdetN END), 0)) AS DigerAdet,
                   MAX(f.eTarih) AS SonAlis,
                   (SELECT TOP 1 ISNULL(fr.frmAd, '(firma adı yok)')
                    FROM DerinSISBkm.dbo.fatAyr fa2 WITH (NOLOCK)
                    JOIN DerinSISBkm.dbo.fat f2 WITH (NOLOCK) ON f2.eID = fa2.ehID
                    LEFT JOIN DerinSISBkm.dbo.frm fr WITH (NOLOCK) ON fr.frmID = f2.eFirma
                    WHERE fa2.ehStkID = @stkId AND f2.eTip = 0 AND f2.eDurum <> 2
                      AND f2.eTarih >= @bas AND f2.eTarih <= DATEADD(DAY, 1, @kesim)
                    ORDER BY f2.eTarih DESC, f2.eID DESC) AS SonTedarikci
            FROM DerinSISBkm.dbo.fatAyr fa WITH (NOLOCK)
            JOIN DerinSISBkm.dbo.fat f WITH (NOLOCK) ON f.eID = fa.ehID
            WHERE fa.ehStkID = @stkId AND f.eTip = 0 AND f.eDurum <> 2
              AND f.eTarih >= @bas AND f.eTarih <= DATEADD(DAY, 1, @kesim)
            """;
        await using var conn = await db.OpenAsync();
        return await conn.QuerySingleOrDefaultAsync<UrunTedarik>(new CommandDefinition(sql,
            new
            {
                stkId,
                bas = kesim.AddDays(-364).ToDateTime(TimeOnly.MinValue),
                kesim = kesim.ToDateTime(TimeOnly.MinValue),
            }, commandTimeout: 60, cancellationToken: ct));
    }

    /// <summary>
    /// MERKEZ ÇIKIŞININ KARŞI TARAFI — bu ürünün merkez çıkışı KİME gitmiş.
    ///
    /// ⚠ NEDEN ÜRÜN BAZINDA: ekranda sabit "%72 grup şirketi · %16 ODAK · %6 Sınav" yazıyordu.
    /// O oran TÜM EVRENİN dağılımıdır, ürünün değil — kullanıcı sordu (09.09: "bu herkese
    /// standart mı ürüne duruma göre değişiyor mu") ve haklı çıktı: ÖLÇÜLDÜ, stkID 1666147'nin
    /// çıkışının TAMAMI (48 adet / 1 belge) ODAK'a gitmiş, grup şirketi payı %0. Evren ortalaması
    /// ürün kartında yanıltıyordu. Artık gerçek karşı taraf okunur.
    ///
    /// Karşı taraf <c>irs.eFirma</c>'dan gelir (irsHrk'da firma kolonu YOK — başlığa join şart).
    /// Süzgeç <c>ehMekan=12</c> + <c>ehTip IN (1,3,5,101)</c>: taban <c>MerkezCikis</c> ile AYNI.
    /// </summary>
    public async Task<IReadOnlyList<MerkezKarsiTaraf>> GetMerkezKarsiTarafAsync(
        int stkId, DateOnly kesim, CancellationToken ct = default)
    {
        const string sql = """
            SELECT TOP 5 CONVERT(int, i.eFirma) AS FrmId,
                   ISNULL(f.frmAd, '(firma kaydı yok)') AS FirmaAd,
                   CONVERT(int, -SUM(h.ehAdetN)) AS Adet,
                   COUNT(DISTINCT i.eID) AS Belge
            FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
            JOIN DerinSISBkm.dbo.irs i WITH (NOLOCK) ON i.eID = h.ehID
            LEFT JOIN DerinSISBkm.dbo.frm f WITH (NOLOCK) ON f.frmID = i.eFirma
            WHERE h.ehstkID = @stkId AND h.ehMekan = 12 AND h.ehTip IN (1, 3, 5, 101)
              AND h.ehTrhS >= @bas AND h.ehTrhS < DATEADD(DAY, 1, @kesim)
            GROUP BY i.eFirma, f.frmAd
            HAVING -SUM(h.ehAdetN) <> 0
            ORDER BY 3 DESC
            """;
        await using var conn = await db.OpenAsync();
        return (await conn.QueryAsync<MerkezKarsiTaraf>(new CommandDefinition(sql,
            new
            {
                stkId,
                bas = kesim.AddDays(-364).ToDateTime(TimeOnly.MinValue),
                kesim = kesim.ToDateTime(TimeOnly.MinValue),
            }, commandTimeout: 60, cancellationToken: ct))).ToList();
    }

    /// <summary>
    /// ÜRÜNÜN MERKEZ DEPODAKİ ADRESLERİ — hangi hücrede/palette (kullanıcı isteği 09.09).
    ///
    /// Kaynak WMS hücresel stok; merkez stoğunun kanonik kaynağı (ERP defteri mekan 12
    /// negatif taşıdığı için kullanılmaz — sql-server-conventions § MERKEZ DEPO STOĞU).
    /// Doğrulandı: stkID 248104 → GİRİŞ ALANI/GR01/palet 37250/1 adet = taban MerkezStok 1.
    ///
    /// ⚠ ÇIKIŞ ALANI merkez stoğuna GİRMEZ (sevke hazırlanmış mal) — satırda işaretlenir,
    /// yoksa "adresler toplamı merkez stoğunu tutmuyor" gibi görünür.
    /// <c>PaleteGiris</c> = o paletin bu ürün için son giriş hareketi. Yön KANITLANDI 09.09:
    /// <c>piİlkID</c> hareketin sahibi palet (iki hipotez view ile kıyaslandı, yalnız bu tuttu).
    /// </summary>
    public async Task<DepoAdresSonuc> GetDepoAdresAsync(
        int stkId, CancellationToken ct = default)
    {
        const string sql = """
            -- ERP DEFTER BAKİYESİ (mekan 12) — WMS ile ÇELİŞKİ denetimi için.
            -- Satış ERP'de kesilip WMS'ten düşülmediğinde WMS pozitif kalıyor (hayalet).
            SELECT CONVERT(int, ISNULL((SELECT SUM(e.ehAdetN) FROM DerinSISBkm.dbo.irsHrk e WITH (NOLOCK)
                                        WHERE e.ehstkID = @stkId AND e.ehMekan = 12), 0)) AS DefterNet;

            SELECT ISNULL(a.alanTipAd, CONVERT(varchar(20), d.adrsAlanTipID)) AS AlanTip,
                   CASE WHEN d.adrsAlanTipID IN (0, 1) THEN 1 ELSE 0 END AS MerkezStoka,
                   d.adrsAd AS Adres, d.PaletID, CONVERT(int, d.Stok) AS Adet,
                   (SELECT MAX(pi.pikTarih) FROM DerinSISBkm.depo.paletIcHrk pi WITH (NOLOCK)
                    WHERE pi.piStkID = d.stkID AND pi.piİlkID = d.PaletID AND pi.pGC = 0) AS PaleteGiris
            FROM DerinSISBkm.depo.stok_adres_palet_vw d WITH (NOLOCK)
            LEFT JOIN DerinSISBkm.depo.adresAlanTip a ON a.alanTipID = d.adrsAlanTipID
            WHERE d.stkID = @stkId AND d.Stok <> 0
            ORDER BY d.adrsAlanTipID, d.Stok DESC
            """;
        await using var conn = await db.OpenAsync();
        await using var grid = await conn.QueryMultipleAsync(new CommandDefinition(sql,
            new { stkId }, commandTimeout: 60, cancellationToken: ct));
        var defter = await grid.ReadSingleAsync<int>();
        var adresler = (await grid.ReadAsync<DepoAdres>()).ToList();
        return new DepoAdresSonuc(adresler, defter);
    }

    /// <summary>WHERE + parametreler. Tek yerde kurulur → liste/sayım/Excel AYRIŞMAZ.</summary>
    private static (string Nerede, DynamicParameters P) Filtre(SatisAnaliziFiltre f)
    {
        var p = new DynamicParameters(KesimP(f));
        var sartlar = new List<string> { "t.Kesim = @kesim AND t.SezonYil = @sezon" };

        // TAZE STOK: son N günde mal kabulü olanlar değerlendirmeden çıkar (KPI ile AYNI şart).
        if (f.TazeGunHaric > 0)
            // KPI TazeSart ile AYNI ifade. NULL artık "eski" değil: bilinen en yeni tarihe düşer
            // (son mal kabulü → mağazaya ilk giriş → kart açılışı). Bkz. TazeSart yorumu.
            sartlar.Add("(COALESCE(t.SonGiris, t.IlkGiris, t.AcilisTarihi) < DATEADD(DAY, -@taze, @kesim))");

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
            // ⚠ KPI'daki HareketsizCesit ile AYNI ifade olmalı (ayrışırsa kart ve liste
            // farklı sayı gösterir). Yenilik koruması: yeni açılan ürün haksız damgalanmasın —
            // ölçüldü 09.09, stkID 1739163 vakası (kart 04.09.2026, mağazaya hiç girmemiş).
            // KPI'daki RafsizCesit / RafBosCesit ile AYNI ifadeler (ayrışma yasak).
            SatisDurumFiltre.Rafsiz => "(t.IlkGiris IS NULL AND t.MerkezStok > 0)",
            // KPI ile AYNI: üç rafın HEPSİ boş. Toplam kullanmak negatif stoğu maskeliyordu
            // (stkID 1697931: FSM 5 · İst.Yolu −13 → toplam −8 "boş" görünüyordu).
            SatisDurumFiltre.RafBos =>
                "(t.IlkGiris IS NOT NULL AND t.MerkezStok > 0 " +
                "AND t.StokFsm <= 0 AND t.StokOzl <= 0 AND t.StokIst <= 0)",
            SatisDurumFiltre.Hareketsiz =>
                "(t.SatisToplam <= 0 AND t.ToplamStok > 0 " +
                "AND COALESCE(t.IlkGiris, t.AcilisTarihi) < DATEADD(DAY, -@yeniGun, @kesim))",
            // KPI KirliCesit ile AYNI ifade. Mekan bazlı negatif dahil — merkez pozitifken
            // mağaza rafındaki eksi stok gizleniyordu (ölçüldü: 187 çeşit / 4,89M ₺).
            SatisDurumFiltre.VeriKirli =>
                "(t.StokFsm < 0 OR t.StokOzl < 0 OR t.StokIst < 0 OR t.MerkezStok < 0 " +
                "OR t.ToplamStok < 0 OR t.SatisFiyat <= 0)",
            // Filtrenin TERSİ: yalnız taze stok. TazeGunHaric ile birlikte kullanılmaz (biri diğerini boşaltır).
            SatisDurumFiltre.SadeceTaze =>
                "(COALESCE(t.SonGiris, t.IlkGiris, t.AcilisTarihi) >= DATEADD(DAY, -@tazeGun, @kesim))",
            _ => null,
        };
        if (durumSart is not null) sartlar.Add(durumSart);
        if (f.Durum == SatisDurumFiltre.SadeceTaze)
            p.Add("tazeGun", f.TazeGunHaric > 0 ? f.TazeGunHaric : SatisAnaliziFiltre.YeniUrunGunVarsayilan);

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
///
/// <c>KdvOran</c> = <c>urn.KDVs</c> → <c>dbo.urnKDV.kdvYuzde</c> (ürün bazında; sabit oran
/// YASAK — kitap %0, kırtasiye/oyuncak %20, bir kısmı %10).
///
/// ⚠ İLK SÜRÜM <c>kdvYuzde_vw</c> KULLANIYORDU ve YANLIŞTI: o view her orana ait yalnız İLK
/// kdvID'yi veriyor (1,2,3,4,6,7) ve Hizmet/Hammadde varyantlarını (5=Hizmet %18, 8=Hizmet %20,
/// 9=Hammadde %1, 10=Hammadde %10) DIŞARIDA bırakıyor → 41 üründe oran çözülemiyordu; 26'sının
/// satışı var, 376.028 ₺ stok. Değişmez <c>kdv-kod-kumesi-lookupta</c> bunu yazıldığı anda
/// yakaladı. <c>dbo.urnKDV</c> öksüz kod bırakmıyor (ölçüldü: 0).
/// ⚠ DERS: "29.912/29.912 POS eşleşmesi" YANILTICIYDI — o kesişimde öksüz kod yoktu.
/// %100 eşleşme KAPSAMI kanıtlamaz.
/// Oran çözülemezse (null) marj HESAPLANMAZ — "KDV oranı yok" yazılır.
/// </summary>
public sealed record UrunMaliyet(
    decimal Adet, decimal Tutar, decimal? BirimMaliyet, int FaturaSayisi,
    DateTime? SonAlis, decimal? SonAlisAdet, int? KdvOran);

/// <summary>Bir ayın net satış adedi (iade netlenmiş, 3 mağaza).</summary>
public sealed record AylikSatis(DateTime Ay, int Adet);

/// <summary>
/// Açık sipariş özeti. ⚠ SiparisAdet = SİPARİŞ EDİLEN adet, "yolda kalan" değil
/// (karşılanma oranı ölçülemiyor — sema: ehSevkAdet NULL).
/// </summary>
public sealed record AcikSiparis(int Belge, decimal? SiparisAdet, DateTime? SonSiparis);

/// <summary>
/// Sezon / sezon-dışı satış hızı. Adetler ÖLÇÜLDÜ (365 günlük pencere, iade netlenmiş);
/// gün sayıları takvimden. Hız = adet ÷ gün.
/// </summary>
public sealed record UrunHiz(int SezonAdet, int SezonGun, int DisiAdet, int DisiGun, int RafGun = 365)
{
    /// <summary>
    /// Raf süresi pencerenin tamamından kısa mı (ürün 365 günden yeni). Ekranda YAZILIR —
    /// hızın paydası daralmıştır, sezon/sezon-dışı kıyası eksik dönem üzerinden yapılmıştır.
    /// </summary>
    public bool RafKisa => RafGun < 365;

    /// <summary>
    /// Sezon penceresinin tamamını gördü mü (92 gün). Görmediyse sezon hızı EKSİK dönemden
    /// türetilmiştir → sezon ağırlığı (Kat) yanıltır, ekranda uyarı çıkar.
    /// </summary>
    public bool SezonuTamGormedi => SezonGun < 92;

    public decimal SezonHiz => SezonGun > 0 ? (decimal)SezonAdet / SezonGun : 0m;
    public decimal DisiHiz => DisiGun > 0 ? (decimal)DisiAdet / DisiGun : 0m;
    public decimal Toplam => SezonAdet + DisiAdet;

    /// <summary>Sezon hızı sezon-dışının kaç katı. Dışı 0 ise null (bölme yok).</summary>
    public decimal? Kat => DisiHiz > 0 ? SezonHiz / DisiHiz : null;

    /// <summary>
    /// ORAN GÜVENİLİR Mİ — sinyal/gürültü ayrımı. Ölçülen vaka (stkID 1701128): sezon 18 adet,
    /// dışı 4 adet → oran 13,4× çıkıyor ve "sezonluk ürün" diyor, ama toplam 22 adetlik satıştan
    /// mevsimsellik çıkarılamaz; tek bir kutu satış oranı ikiye katlıyor.
    /// Eşik 30 adet: altında oran GÖSTERİLMEZ, "veri az" yazılır.
    /// </summary>
    public bool OranGuvenilir => Toplam >= 30m;

    /// <summary>
    /// TÜKENME TARİHİ — kesimden ileri gün gün simülasyon: her günün kendi dönemine ait hız
    /// düşülür. Geçmiş desenin tekrarı VARSAYIMIDIR (ÇIKARIM), ölçüm değil — ekranda yazılır.
    /// 730 günde tükenmezse null döner ("2 yılda tükenmiyor").
    /// </summary>
    public (DateOnly Tarih, int Gun)? Tukenme(int stok, DateOnly kesim)
    {
        if (stok <= 0 || (SezonHiz <= 0 && DisiHiz <= 0)) return null;
        decimal kalan = stok;
        for (var i = 1; i <= 730; i++)
        {
            var g = kesim.AddDays(i);
            kalan -= g.Month is 8 or 9 or 10 ? SezonHiz : DisiHiz;
            if (kalan <= 0) return (g, i);
        }
        return null;
    }

    /// <summary>Gelecek sezonun (92 gün) sezon hızıyla gerektirdiği adet.</summary>
    public decimal SezonIhtiyaci => SezonHiz * 92m;
}

/// <summary>
/// Bir mağazadaki son satış. <c>GunOnce</c> = kesimden kaç gün önce.
/// Kayıt YOKSA o mağazada HİÇ satılmamış demektir (liste o mekanı içermez) — "0 gün önce"
/// ile karıştırılmasın diye ekranda ayrı yazılır.
/// </summary>
public sealed record MagazaSonSatis(int Mekan, DateTime SonSatis, int GunOnce);

/// <summary>
/// Son 365 günde ürünün alış kaynağı. <c>SonAlis</c> null ise o pencerede hiç alış YOK →
/// ODAK temin süresi doğrulanamaz (ölçüldü: çeşitlerin yarısı bu durumda).
/// </summary>
public sealed record UrunTedarik(int OdakAdet, int DigerAdet, DateTime? SonAlis, string? SonTedarikci)
{
    /// <summary>Son 365 günde hiç alış var mı.</summary>
    public bool AlisVar => SonAlis is not null;

    /// <summary>ODAK temin süresi bu ürün için geçerli mi — yalnız ODAK'tan alınıyorsa.</summary>
    public bool OdakGecerli => OdakAdet > 0 && DigerAdet <= 0;

    /// <summary>ODAK'tan da başka tedarikçiden de alınıyor — süre kısmen geçerli.</summary>
    public bool Karisik => OdakAdet > 0 && DigerAdet > 0;

    /// <summary>Yalnız ODAK DIŞI tedarikçiden alınıyor — ODAK süresi YANILTICI.</summary>
    public bool OdakDisi => AlisVar && OdakAdet <= 0;
}

/// <summary>
/// Merkez çıkışının bir karşı tarafı. <c>FrmId</c> 56 = Bursa Kültür Merkezi (GRUP ŞİRKETİ),
/// 9525 = ODAK Kitap-Point (e-ticaret fulfillment), 120 = Sınav Basın Yayın.
/// </summary>
public sealed record MerkezKarsiTaraf(int FrmId, string FirmaAd, int Adet, int Belge);

/// <summary>
/// Bir WMS hücresi/paleti. <c>MerkezStoka</c> 0 = ÇIKIŞ ALANI (merkez stoğuna dahil değil).
/// </summary>
public sealed record DepoAdres(
    string AlanTip, int MerkezStoka, string? Adres, int? PaletID, int Adet, DateTime? PaleteGiris);

/// <summary>
/// WMS adresleri + ERP defter bakiyesi (mekan 12). İkisi ÇELİŞEBİLİR ve ikisi de tek başına
/// doğru değildir — bu yüzden ikisi birlikte döner.
///
/// ÖLÇÜLDÜ 09.09.2026:
///  · WMS pozitif ama defter ≤ 0 → <b>349 çeşit / 3.757 adet</b> (hayalet). 261'inde merkez
///    satışı var, 342'sinin belgesiz palet hareketi var. Mekanizma: satış ERP'de kesilir,
///    WMS'ten düşülmez; mal rafta kalır, sonra elle giriş alanına taşınır (piIrsID=0).
///  · Defter pozitif ama WMS'te yok → 9.146 çeşit / 1.996.995 adet (merkez stoğunun WMS'ten
///    okunma sebebi; ERP defteri negatif/kalıntı taşıyor).
///  · Hayalet KİTAP tarafında yığılı: Akademi 84 çeşidin 76'sı (%90), Kitap 127'nin 77'si
///    (%61); Kırtasiye %0,9, Oyuncak %0,8. Merkez depo kitap tutmuyor.
/// </summary>
public sealed record DepoAdresSonuc(IReadOnlyList<DepoAdres> Adresler, int DefterNet)
{
    public int WmsToplam => Adresler.Where(a => a.MerkezStoka == 1).Sum(a => a.Adet);

    /// <summary>WMS pozitif ama ERP defteri ≤ 0 → sayı şüpheli (hayalet stok deseni).</summary>
    public bool Hayalet => WmsToplam > 0 && DefterNet <= 0;
}
