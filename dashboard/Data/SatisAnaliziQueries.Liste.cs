using Dapper;
using GmDashboard.Models;
using Microsoft.Extensions.Caching.Memory;   // TryGetValue<T> / Set genişletmeleri (B-168 akran cache)

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
        ["kat1"] = "t.Kat1",
        ["kat2"] = "t.Kat2",
        ["kat3"] = "t.Kat3",
        ["kat4"] = "t.Kat4",
        // KATEGORİ YOLU — yalnız SIRALAMA ifadesi. SELECT'e kolon EKLENMEZ:
        // yol C# tarafında (SatisAnaliziHucre.KategoriYolu) kurulur, böylece
        // Dapper pozisyonel record sırası değişmez.
        ["katyol"] = "CONCAT(t.Kategori1, N'>', ISNULL(t.Kat1, N''), N'>', ISNULL(t.Kat2, N''), N'>', ISNULL(t.Kat3, N''), N'>', ISNULL(t.Kat4, N''))",
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
        ["sonsatis"] = "t.SonSatis",
        ["satanay"] = "t.SatanAy",
        ["maliyettarih"] = "t.MaliyetTarih",
        ["maliyetyas"] = "t.MaliyetTarih",   // yaş tarihin tersi sırası; aynı kolondan sırala
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
        -- ⚠ HER KOLONA AÇIK ALIAS (10.09.2026, silent-failure-hunter madde 9).
        -- Önce 18 kolon alias'sızdı ve `tools/panel_kolon_denetimi.py` sıra kıyasını
        -- YALNIZ alias'lı kolonlarda yapıyordu → araya ALIAS'SIZ kolon eklenince
        -- alias'ların GÖRELİ sırası değişmiyor, sapma yakalanmıyor ama Dapper'da tüm
        -- alt pozisyonlar KAYIYORDU. Alias adı = record parametre adı; davranış değişmez,
        -- denetim körlüğü kapanır.
        t.stkID AS StkId, t.Kategori3 AS Kategori3, t.BarkodAna AS BarkodAna,
        t.stkAd AS StkAd, t.Kategori1 AS Kategori1,
        -- ÜRÜN AĞACI (14.09.2026) — Kategori1'den HEMEN SONRA; record'da da aynı yerde.
        t.Kat1 AS Kat1, t.Kat2 AS Kat2, t.Kat3 AS Kat3, t.Kat4 AS Kat4,
        t.Yayinevi AS Yayinevi, t.Yazar AS Yazar, t.SatisFiyat AS SatisFiyat,
        t.Tutar AS ToplamStokTutar, t.ToplamStok AS ToplamStok,
        t.OdakStok AS OdakStok, t.IlkGiris AS IlkGirisTarihi, t.SonGiris AS SonGirisTarihi,
        t.AcilisTarihi AS AcilisTarihi,
        t.StokFsm AS StokFsm, t.StokOzl AS StokOzluce, t.StokIst AS StokIstyolu,
        t.MagazaStok AS MagazaStok, t.MerkezStok AS MerkezStok,
        t.SatisFsm AS SatisFsm, t.SatisOzl AS SatisOzluce, t.SatisIst AS SatisIstyolu,
        t.SatisToplam AS SatisToplam,
        t.SonSatis AS SonSatisTarihi,
        -- TALEP DESENİ ham girdileri (sınıf kodda hesaplanır; ADI = 12 / SatanAy)
        t.SatanAy AS SatanAy, t.TalepCV2 AS TalepCV2,
        -- MALİYETİN TARİHİ + YAŞI (B11) — marj bu yaşı taşıyor; süzülebilir olsun diye listede.
        -- ⚠ Yaş KESİM TARİHİNE göre, bugüne göre DEĞİL: geçmiş kesim seçilirse yaş kaymasın.
        t.MaliyetTarih AS MaliyetTarih,
        CONVERT(int, DATEDIFF(DAY, t.MaliyetTarih, t.Kesim)) AS MaliyetYasGun,
        t.Ay1 AS SezonAy1, t.Ay2 AS SezonAy2, t.Ay3 AS SezonAy3,
        t.SezonToplam AS SezonToplam,
        t.LeadTime AS LeadTime, t.OdakDurum AS OdakSatisDurum,
        -- MERKEZ ÇIKIŞI (365g) — toptan/grup, tüketici talebi DEĞİL. Gün-stok kapsam
        -- asimetrisini kapatmak için ayrı ölçülür (bkz. SatisAnaliziSatir.MerkezGunStok).
        ISNULL(t.MerkezCikis, 0) AS MerkezCikis,
        -- Kaç ayrı günde çıktı = SIÇRAMALILIK. Hız değil (ölçüldü: %67 tek günde).
        ISNULL(t.MerkezCikisGun, 0) AS MerkezCikisGun,
        -- ETKİN GÜN = satış hızının paydası. Tanım TEK YERDE: EtkinGunSql (alt sınır 1).
        """
        // ⚠ "\n" ŞART: ham dizge kapanış tırnağından ÖNCEKİ satır sonunu İÇERMEZ. O yüzden
        // birleştirilen ifade, üstteki `--` yorumunun AYNI satırına düşüp yorum içinde
        // kayboluyordu; SQL'de yalnız orphan `WHEN` satırları kalıp "156: 'WHEN' yakınında
        // sözdizimi yanlış" veriyordu (09.09.2026'da bu hataya düşüldü).
        + "\n" + EtkinGunSql + " AS EtkinGun";

    /// <summary>
    /// Liste kolonları + SİPARİŞ kolonları (plan-46). Sipariş kolonları ölçülen yıl oranına
    /// bağlı olduğu için sabit değil, metot.
    /// ⚠ DAPPER POZİSYONEL: üçü de SELECT'in SONUNA eklenir ve SatisAnaliziSatir record'unun
    /// SONUNA aynı sırayla yazılır (sql-server-conventions § Dapper pozisyonel record).
    /// </summary>
    /// <summary>
    /// ÜRÜN GRUBU EVRENİ (Kat1) — filtre kutusunun önerileri.
    ///
    /// GMY 14.09.2026: <i>"defter grubuna nasıl ulaşacağım"</i>. <c>Kategori3</c> 11 değerde
    /// duruyor, <c>Kategori1</c> ise aslında <c>KatAna</c> ve alt kırılım VERMİYOR (Kırtasiye'nin
    /// 52.021 çeşidinin hepsinde yine "Kırtasiye"). Gerçek grup <c>UrunBilgi.Kat1</c>:
    /// "Defterler" · "Kalemler ve Yazı Gereçleri" · "Çanta ve Mataralar"…
    ///
    /// ÖLÇÜLDÜ 14.09.2026 (kesim tabanı, 276.072 çeşit): Kat1 <b>%90,9 dolu</b>, <b>516</b> ayrı
    /// değer; "Defterler" 7.933 çeşit. 516 seçenek <c>select</c> için fazla → datalist (yazarak ara).
    /// ⚠ Boş Kat1 taşıyan %9,1 bu listede görünmez ve gruba göre süzülemez — kapsam kaybı
    /// GİZLENMEZ, ekranda yazılı.
    /// </summary>
    public async Task<IReadOnlyList<KatGrupSatir>> Kat1EvreniAsync(
        SatisAnaliziFiltre f, CancellationToken ct = default)
    {
        await using var conn = await db.OpenAsync();
        var sql = $"""
            SELECT t.Kat1 AS Ad, COUNT(*) AS Cesit
            FROM {Taban} t WITH (NOLOCK)
            WHERE t.Kesim = @kesim AND t.SezonYil = @sezon AND t.Kat1 IS NOT NULL
              AND (@kategori3 IS NULL OR t.Kategori3 = @kategori3)
            GROUP BY t.Kat1
            ORDER BY COUNT(*) DESC
            """;
        var p = new DynamicParameters();
        p.Add("kesim", f.Kesim.ToDateTime(TimeOnly.MinValue));
        p.Add("sezon", f.SezonYil);
        p.Add("kategori3", f.Kategori3);
        var r = await conn.QueryAsync<KatGrupSatir>(
            new CommandDefinition(sql, p, commandTimeout: 60, cancellationToken: ct));
        return r.ToList();
    }

    private const string ListeKolonlarSql =
        ListeKolonlar
        + ",\n" + SiparisOneriSql + " AS SiparisOneri"
        + ",\n" + SiparisKapakSql + " AS SiparisKapak"
        + ",\n" + SiparisTabanEtiketSql + " AS SiparisTaban";

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

        var oran = SiparisOranSql(await SiparisOranAsync(f, ct));
        var (nerede, p) = Filtre(f);
        p.Add("atla", (sayfa - 1) * sayfaBoyu);
        p.Add("al", sayfaBoyu);

        var sql = $"""
            SELECT {ListeKolonlarSql}
            FROM {Taban} t WITH (NOLOCK)
            {SiparisKaynak(oran)}
            WHERE {nerede}
            ORDER BY {sirala} {yon}, t.stkID
            OFFSET @atla ROWS FETCH NEXT @al ROWS ONLY
            """;

        await using var conn = await db.OpenAsync();
        var satirlar = (await conn.QueryAsync<SatisAnaliziSatir>(
            new CommandDefinition(sql, p, commandTimeout: 120, cancellationToken: ct))).ToList();

        var toplam = bilinenToplam
            ?? (toplamGerekli || satirlar.Count == 0 ? await SayAsync(conn, nerede, p, oran, ct) : satirlar.Count);

        return SayfaSonucu<SatisAnaliziSatir>.Olustur(satirlar, toplam, sayfa, sayfaBoyu);
    }

    /// <summary>Filtreye uyan toplam satır — sayfa çevirmede TEKRAR sorulmaz (34 ms ama gereksiz).</summary>
    public async Task<int> SayAsync(SatisAnaliziFiltre f, CancellationToken ct = default)
    {
        var oran = SiparisOranSql(await SiparisOranAsync(f, ct));
        var (nerede, p) = Filtre(f);
        await using var conn = await db.OpenAsync();
        return await SayAsync(conn, nerede, p, oran, ct);
    }

    /// <summary>
    /// Filtreye uyan satır sayısı. ⚠ <c>oran</c> ŞART: sipariş filtresi <c>sp.Oneri</c>'yi
    /// okur, o da yalnız <c>SiparisKaynak</c> APPLY'ı ile var olur. Eksikti → sipariş kartına
    /// tıklayınca "Çok parçacı sp.Oneri tanımlayıcısı bağlanamadı" (SQL 4104) ve liste
    /// "Veri alınamadı" verdi (ölçüldü 11.09.2026 — build yeşildi, hata çalışma anında çıktı).
    /// </summary>
    private static async Task<int> SayAsync(
        System.Data.Common.DbConnection conn, string nerede, DynamicParameters p, string oran,
        CancellationToken ct)
    {
        var sql = $"""
            SELECT COUNT(*) FROM {Taban} t WITH (NOLOCK)
            {SiparisKaynak(oran)}
            WHERE {nerede}
            """;
        return await conn.ExecuteScalarAsync<int>(
            new CommandDefinition(sql, p, commandTimeout: 120, cancellationToken: ct));
    }

    /// <summary>Excel dökümü — TÜM filtreli satırlar (sayfalama yok). Ağır yol, butona basınca.</summary>
    public async Task<IReadOnlyList<SatisAnaliziSatir>> GetTumListeAsync(
        SatisAnaliziFiltre f, int tavan = 300_000, CancellationToken ct = default)
    {
        var sirala = SiralamaHaritasi.TryGetValue(f.Sirala, out var kolon) ? kolon : "t.Tutar";
        var yon = f.Azalan ? "DESC" : "ASC";
        var oran = SiparisOranSql(await SiparisOranAsync(f, ct));
        var (nerede, p) = Filtre(f);
        p.Add("tavan", tavan);

        var sql = $"""
            SELECT TOP (@tavan) {ListeKolonlarSql}
            FROM {Taban} t WITH (NOLOCK)
            {SiparisKaynak(oran)}
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
        var oran = SiparisOranSql(await SiparisOranAsync(
            new SatisAnaliziFiltre(kesim, sezonYil), ct));
        var sql = $"""
            SELECT {ListeKolonlarSql}
            FROM {Taban} t WITH (NOLOCK)
            {SiparisKaynak(oran)}
            WHERE t.Kesim = @kesim AND t.SezonYil = @sezon AND t.stkID = @stkId
            """;
        // ⚠ PARAMETRELER `KesimP`TEN GELMELİ — elle kurulan anonim nesne YETMEZ.
        // Vaka 14.09.2026: burada `new { kesim, sezon, stkId }` yazılıydı ve sayfa
        // "Veri alınamadı" veriyordu. Sebep: `SiparisKaynak` CROSS APPLY zinciri
        // @pbas · @a8 · @a9 · @a10 · @a11 takvim parametrelerini İSTİYOR (8632'den
        // kaçmak için takvim matematiği C#'a taşınmıştı) ama bu çağrı onları
        // VERMİYORDU → SQL 137 "skaler değişken bildirilmelidir" + zincirin her
        // adımında sözdizimi hatası. Liste sorgusu KesimP kullandığı için çalışıyor,
        // yalnız ürün drill'i düşüyordu — yani hata TEK SAYFADA görünüyordu.
        // KURAL: `SiparisKaynak` SQL'e giriyorsa parametre kaynağı da `KesimP` olur.
        var p = new DynamicParameters(KesimP(new SatisAnaliziFiltre(kesim, sezonYil)));
        p.Add("stkId", stkId);
        await using var conn = await db.OpenAsync();
        return await conn.QuerySingleOrDefaultAsync<SatisAnaliziSatir>(new CommandDefinition(sql, p,
            commandTimeout: 60, cancellationToken: ct));
    }

    /// <summary>
    /// Drill kıyas tabanı: ürünün Kategori1 akranlarının **MEDYANI**.
    ///
    /// ⚠ ORTALAMA DEĞİL — ölçüldü 09.09.2026: "Hobi ve Oyuncak" 15.251 çeşidin ORTALAMA stoğu
    /// 22 adet çıkıyor (uzun kuyruk: binlerce çeşit 0-2 adet). Tek bir gerçek ürün 18.910 adetle
    /// "+%87.003" gibi anlamsız bir fark üretiyordu. Medyan uzun kuyruğa dayanıklı.
    /// </summary>
    /// <remarks>
    /// PERF (B-168, ölçüldü 09.09.2026): bu sorgu drill'in TEK ağır kalemiydi —
    /// DMV'de ort. <b>1.096 ms / 462.305 mantıksal okuma</b>. Drill sayfası toplam 1,36 s
    /// sürüyordu; çerçeve tabanı (/login) 0,22 s, diğer 8 drill sorgusu 13-17 ms.
    /// Yani gecikmenin ~%80'i buradaydı.
    ///
    /// MALİYET İZOLE EDİLDİ (taban 1.389 ms sqlcli açılışı düşülmüş):
    /// yalnız COUNT(*) 64 ms · TEK PERCENTILE_CONT 376 ms · COUNT OVER + 4 PERCENTILE 692 ms.
    /// ⇒ Suçlu <c>COUNT(*) OVER ()</c> DEĞİL, <b>PERCENTILE_CONT pencere fonksiyonları</b>
    /// (TOP 1 sonucu atsa bile her satır için hesaplanıyor).
    ///
    /// REDDEDİLEN ÇÖZÜMLER (ikisi de ÖLÇÜLDÜ, ikisi de daha kötü):
    /// (a) <b>9 sorguyu tek QueryMultiple'a toplamak</b> — B-168'in ilk önerisiydi. Gerekçesi
    ///     ("round-trip birikir") YANLIŞ: 9 round-trip LAN'da ~45 ms, kazanç yok. Gecikme
    ///     round-trip'te değil TEK sorgunun ÇALIŞMA süresinde.
    /// (b) <b>ROW_NUMBER tabanlı medyan</b> — 5 metrik için CTE'ye 5 kez başvuruyor; SQL Server
    ///     CTE'yi materialize ETMEDİĞİ için taban 5 kez taranıp sıralanıyor: >40 s (60 s
    ///     timeout'a dayandı, iptal edildi). PERCENTILE_CONT bu alternatiften çok daha iyi.
    ///
    /// UYGULANAN: sorgu AYNEN kaldı, <b>tekrar hesaplanması</b> engellendi. Akran medyanı
    /// (Kesim, SezonYil, Kategori1) üçlüsü için SABİTTİR — aynı kategorideki her ürün aynı
    /// medyanı görür. 42 Kategori1 var, yani kesim başına en fazla 42 kayıt.
    ///
    /// ⚠ BAYATLAMA SINIRI: taban AYNI kesim için yeniden kurulursa (DELETE+INSERT) cache
    /// en fazla <see cref="AkranCacheSuresi"/> kadar eski medyanı gösterir. Bilinçli kabul:
    /// akran medyanı bir BAĞLAM metriğidir (kıyas çubuğu), sipariş kararının girdisi değil.
    /// Ürünün kendi rakamları cache'lenmiyor. Kesim değişince anahtar da değişir.
    /// </remarks>
    private static readonly TimeSpan AkranCacheSuresi = TimeSpan.FromMinutes(30);

    public async Task<AkranOzet?> GetAkranAsync(
        string kategori1, DateOnly kesim, int sezonYil, CancellationToken ct = default)
    {
        var anahtar = $"akran|{kesim:yyyyMMdd}|{sezonYil}|{kategori1}";
        if (cache.TryGetValue(anahtar, out AkranOzet? onbellek)) return onbellek;

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
                                  {EtkinGunSql}) END)
                        OVER (PARTITION BY t.Kategori1))                                   AS OrtGunStok
            FROM {Taban} t WITH (NOLOCK)
            WHERE t.Kesim = @kesim AND t.SezonYil = @sezon AND t.Kategori1 = @kategori1
            """;
        await using var conn = await db.OpenAsync();
        var sonuc = await conn.QuerySingleOrDefaultAsync<AkranOzet>(new CommandDefinition(sql,
            new { kesim = kesim.ToDateTime(TimeOnly.MinValue), sezon = (short)sezonYil, kategori1 },
            commandTimeout: 120, cancellationToken: ct));

        // NULL da cache'lenir: akranı olmayan kategori her drill'de 700 ms'i yeniden ödemesin.
        cache.Set(anahtar, sonuc, AkranCacheSuresi);
        return sonuc;
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
    /// GERÇEKLEŞEN SATIŞ FİYATI — POS'ta fiilen ne kadara satıldı (kullanıcı isteği 09.09:
    /// "detay kartına gerçekleşen ortalama satış fiyatına göre kâr ve kâr marjı da olsa").
    ///
    /// NEDEN ŞART (ölçüldü 09.09.2026, 90 gün, panel evreni): POS brütü kart fiyatına EŞİT
    /// (%95,4–99,5 → <c>urn.fiyatS</c> gerçekten raf fiyatı) ama <b>gerçekleşen NET</b> çok
    /// altında: Kitap %71,1 · Çocuk Kitabı %72,3 · Elektronik %77,3 · Hazırlık %78,9 ·
    /// Akademi %79,5 · Kırtasiye %80,3 · Hediyelik %81,6 · Oyuncak %88,6 · Dergi %98,0.
    /// Panelin stok değeri kart fiyatıyla 1.022,2M ₺; kategori oranlarıyla 807,3M ₺ →
    /// <b>214,9M ₺ / %21,03 şişme</b>. Kart fiyatıyla hesaplanan marj bu yüzden fazla iyimser.
    ///
    /// KAYNAK POS (EncoreMerkez) — <c>irsHrk</c> DEĞİL: indirim kırılımı yalnız POS'ta var.
    /// Köprü <c>Products.Code = stkID</c> (barkod DEĞİL; sql-server-conventions).
    /// <c>IsValid = 1</c> zorunlu.
    ///
    /// ══ İKİ KURAL, İKİ ÖLÇÜ SETİ (düzeltme 10.09.2026, sql-denetci bulgusu) ═══════════
    /// Bu sorgu İKİ farklı soruyu besliyor ve <c>veri-dogrula §2/2</c> ikisine AYRI kural
    /// koyuyor:
    ///   · <b>ORTALAMA FİYAT</b> (birim fiyat, indirim oranı, birim kâr, marj) → AVG sorusu,
    ///     <b>iade HARİÇ</b>: iade satırı fiyatı bozar.
    ///   · <b>TOPLAM TUTAR</b> (365 günlük kâr, satılan adet) → SUM sorusu, <b>iade NEGATİF
    ///     SIGN ile DÜŞÜLÜR</b>: dışlamak tutarı ŞİŞİRİR.
    /// Önce tek set vardı (iade tamamen dışlanmış) ve TOPLAM KÂR şişiyordu — aynı hata
    /// tabanda da vardı, orada ölçüldü: kâr 4.322.551 ₺ / net satış 13.265.831 ₺ şişme
    /// (marj oranı yalnız 0,03 puan, çünkü iade satışı ve maliyeti orantılı düşürüyor).
    /// ⇒ Sorgu artık İKİ SET döndürüyor: <c>Adet/NetKdvDahil/Kdv/...</c> (iade hariç, AVG için)
    /// ve <c>AdetNet/NetNet/KdvNet</c> (iade netli, SUM için). Türev ölçüler doğru setten okur.
    /// KDV: <c>VatTotal</c> POS'un kendi hesabı — ürün kartındaki orandan türetilmez.
    /// </summary>
    public async Task<UrunGerceklesen?> GetGerceklesenAsync(
        int stkId, DateOnly kesim, CancellationToken ct = default)
    {
        const string sql = """
            SELECT -- ① İADE HARİÇ set — ORTALAMA fiyat/marj soruları için (AVG kuralı)
                   CONVERT(decimal(18,3), SUM(CASE WHEN s.DocumentsTypeId <> 3
                        THEN sp.Amount ELSE 0 END))                              AS Adet,
                   CONVERT(decimal(18,2), SUM(CASE WHEN s.DocumentsTypeId <> 3
                        THEN sp.TotalPrice ELSE 0 END))                          AS NetKdvDahil,
                   CONVERT(decimal(18,2), SUM(CASE WHEN s.DocumentsTypeId <> 3
                        THEN sp.TotalPrice + sp.DiscountTotalDirect ELSE 0 END))  AS BrutKdvDahil,
                   CONVERT(decimal(18,2), SUM(CASE WHEN s.DocumentsTypeId <> 3
                        THEN sp.VatTotal ELSE 0 END))                            AS Kdv,
                   CONVERT(decimal(18,2), SUM(CASE WHEN s.DocumentsTypeId <> 3
                        THEN sp.DiscountTotalCampaign ELSE 0 END))               AS IndirimKampanya,
                   SUM(CASE WHEN s.DocumentsTypeId <> 3 THEN 1 ELSE 0 END)       AS Kalem,
                   -- ② İADE NETLİ set — TOPLAM tutar soruları için (SUM kuralı)
                   CONVERT(decimal(18,3), SUM(CASE WHEN s.DocumentsTypeId = 3
                        THEN -sp.Amount ELSE sp.Amount END))                     AS AdetNet,
                   CONVERT(decimal(18,2), SUM(CASE WHEN s.DocumentsTypeId = 3
                        THEN -sp.TotalPrice ELSE sp.TotalPrice END))             AS NetNet,
                   CONVERT(decimal(18,2), SUM(CASE WHEN s.DocumentsTypeId = 3
                        THEN -sp.VatTotal ELSE sp.VatTotal END))                 AS KdvNet
            FROM EncoreMerkez.dbo.SalesProducts sp WITH (NOLOCK)
            JOIN EncoreMerkez.dbo.Sales s WITH (NOLOCK) ON s.Id = sp.SalesId
            JOIN EncoreMerkez.dbo.Products p WITH (NOLOCK) ON p.Id = sp.ProductsId
            WHERE sp.IsValid = 1
              AND s.DocumentsTypeId IN (1, 2, 3, 6, 7, 8)   -- 3 = İADE (set ②'de negatiflenir)
              AND s.[Date] >= @bas AND s.[Date] < DATEADD(DAY, 1, @kesim)
              AND ISNUMERIC(p.Code) = 1 AND p.Code NOT LIKE '%.%' AND p.Code NOT LIKE '%e%'
              AND CONVERT(int, p.Code) = @stkId
            HAVING SUM(CASE WHEN s.DocumentsTypeId <> 3 THEN sp.Amount ELSE 0 END) > 0
            """;
        await using var conn = await db.OpenAsync();
        return await conn.QuerySingleOrDefaultAsync<UrunGerceklesen>(new CommandDefinition(sql,
            new
            {
                stkId,
                kesim = kesim.ToDateTime(TimeOnly.MinValue),
                bas = kesim.AddDays(-364).ToDateTime(TimeOnly.MinValue),
            },
            commandTimeout: 60, cancellationToken: ct));
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
              AND h.ehTrhS >= @bas AND h.ehTrhS < @son
            GROUP BY DATEFROMPARTS(YEAR(h.ehTrhS), MONTH(h.ehTrhS), 1)
            ORDER BY 1
            """;
        await using var conn = await db.OpenAsync();
        var ham = (await conn.QueryAsync<AylikSatis>(new CommandDefinition(sql,
            new
            {
                stkId,
                bas = TamAyPenceresi(kesim).Bas,
                son = TamAyPenceresi(kesim).Son,
            }, commandTimeout: 60, cancellationToken: ct))).ToList();

        // Boş ayları 0 ile doldur — "veri yok" ile "satış yok" karışmasın.
        var (basAy, sonAyHaric) = TamAyPenceresi(kesim);
        var sonAy = sonAyHaric.AddMonths(-1);   // son TAM ay (kesim ayı dışarıda)
        var harita = ham.ToDictionary(x => x.Ay, x => x.Adet);
        var tam = new List<AylikSatis>();
        for (var a = basAy; a <= sonAy; a = a.AddMonths(1))
            tam.Add(new AylikSatis(a, harita.GetValueOrDefault(a)));
        return tam;
    }

    /// <summary>
    /// TAM-AY PENCERESİ — aylık serilerin başlangıcı. Son 12 <b>TAM</b> ay:
    /// kesim ayının 1'inden 12 ay geriye; kesim ayının kendisi DIŞARIDA kalır.
    ///
    /// ⚠ NEDEN (kullanıcı 10.09.2026: "ayın bir kısmı dışarda kalıyor bir kısmı içerde"):
    /// eski pencere <c>kesim−364</c> idi ve aylık gruplama iki YARIM ay üretiyordu.
    /// ÖLÇÜLDÜ (kesim 09.09.2026, 3 mağaza): 13 bar çıkıyordu, ikisi kırpık —
    ///   Eyl 2025 <b>21/30 gün</b> → 512.619 adet (tam ayı <b>910.765</b>, yani %56'sı)
    ///   Eyl 2026 <b>9/30 gün</b>  → 315.093 adet
    /// Eyl 2026'nın günlük hızı 35.010/gün ile <b>yılın en hızlısı</b>ydı ama grafikte
    /// Ağustos'un (446.767) altında "düşük ay" gibi duruyordu.
    /// Grafikten okunan YoY <b>−%38,5</b>; aynı 9 güne göre gerçek <b>−%20,9</b>
    /// (398.146 → 315.093) — sapma iki kat.
    /// Ayrıca sezon/dışı ayrımı (<c>MONTH IN (8,9,10)</c>) İKİ AYRI SEZONUN parçasını
    /// topluyordu: Eyl'25 kırpık + Eki'25 + Ağu'26 + Eyl'26 kırpık = 1.781.788
    /// (tam 2025 sezonu 1.843.439 — sayı yakın, <b>anlamı yanlış</b>).
    ///
    /// ⚠ KAPSAM SINIRI — bu yalnız AYLIK SERİLER için. Tabandaki <c>SatisToplam</c> hâlâ
    /// 365 gün (manşet KPI + Kübra'nın Excel raporunun tanımı; 12 tam ay olsa
    /// 5.655.586 → 5.738.639, <b>+%1,5</b>). İki tanım bilerek ayrı: grafik ölçüm doğruluğu
    /// için hizalı, manşet kaynak raporla süreklilik için 365 gün.
    /// </summary>
    private static (DateTime Bas, DateTime Son) TamAyPenceresi(DateOnly kesim)
    {
        var sonAy = new DateTime(kesim.Year, kesim.Month, 1);   // dışlanan üst sınır
        return (sonAy.AddMonths(-12), sonAy);
    }

    /// <summary>
    /// AÇIK SİPARİŞ (yolda mal) — kurulun "en kritik eksik" dediği madde (satinalma-danisman 08.09).
    ///
    /// KAYNAK sema'dan (metrics.yaml → bulunurluk_osa.mal_yolda_kontrolu): <c>dbo.sip</c> +
    /// <c>dbo.sipAyr</c>, <c>eDurum &lt;&gt; 2</c>.
    /// ⚠ TARİH TUZAĞI: <c>s.eTarih</c> kullanılır — <c>eTarihS</c> DEĞİL (sema'da belgeli).
    ///
    /// ══ DÜZELTME 10.09.2026 — <c>eTip</c> SÜZGECİ YOKTU, SAYI YANLIŞTI ═══════════════
    /// Kullanıcı uyardı ("sipariş kısmını kontrol etmelisin"). <c>dbo.sip</c> SATIN ALMA
    /// siparişi tablosu DEĞİL, tüm sipariş türlerini taşıyor — <c>dbo.sipTip_vw</c> (14 kod,
    /// <c>sqlcli lookup --count-from</c> ile okundu, elle yazılmadı):
    ///   0 Alış <b>41.743</b> · 1 Satış <b>6.997.606</b> · 3 Yerel Alım 3.495 ·
    ///   9 Alış İade Emri 27.614 · 13 Depo Mağaza 22.100 · 2/4/8 iç transfer.
    /// Alış tüm kayıtların yalnız <b>%0,6</b>'sı. Süzgeç olmadığı için kart, satın almayla
    /// ilgisi olmayan belgeleri "yolda mal" sayıyordu — hem de <b>TERS YÖNLÜ</b> olanları:
    /// <b>Alış İade Emri</b> tedarikçiye GERİ GÖNDERME (stok azaltıcı) ve <b>Satış</b> müşteri
    /// siparişi (stok azaltıcı). Kart "üstüne alım yapma" derken mal aslında gidiyordu.
    ///
    /// ÖLÇÜLDÜ 10.09 (kesim 09.09.2026, 120 gün, panel geneli):
    ///   uyarı alan 37.168 ürün · <b>17.139'unda (%46,1) gerçek alış siparişi SIFIR</b> →
    ///   yanlış uyarı. Adet: filtresiz 4.543.969 · <b>gerçek alış 630.682 (%13,9)</b> ·
    ///   alış iade emri 683.186 · müşteri siparişi 1.570.466 · iç transfer 1.659.635.
    ///   Yani gösterilen adedin <b>%86'sı</b> satın alma siparişi değildi.
    ///   Örnek stkID 1672852 (Bricks Lego, aşırı stoğun en büyük kalemi): "33.262 adet açık
    ///   sipariş" → gerçekte <b>0 alış</b>; %68'i alış iade emri, %25'i iç transfer, %7'si
    ///   müşteri siparişi.
    /// ⇒ Süzgeç <c>s.eTip IN (0, 3)</c> (Alış + Yerel Alım).
    ///
    /// ══ İKİNCİ DÜZELTME — pencere <c>GETDATE()</c> değil <c>@kesim</c> ════════════════
    /// Drill seçilen kesime göre ölçüyor; sipariş penceresi ise makinenin BUGÜNÜNÜ
    /// kullanıyordu. Eski bir kesim seçildiğinde pencere onu takip etmiyordu — ölçümün
    /// kapsamı kodun kapsamıyla aynı olmalı (olctum-mu-cikardim-mi § 2).
    ///
    /// ⚠ SINIR — DEĞİŞMEDİ, ÖLÇÜMLE TEYİT EDİLDİ: bu adet SİPARİŞ EDİLEN'dir, "yolda kalan"
    /// DEĞİL. <c>sipAyr.ehSevkAdet</c> alış siparişi satırlarının <b>%100'ünde NULL</b>
    /// (37.537/37.537 satır, ölçüldü 10.09) → karşılanma oranı ölçülemiyor. Ekranda böyle yazılır.
    /// ⚠ SINIR — <c>eDurum = 2</c> (kapalı) 24.02.2025'ten beri HİÇ kullanılmamış (5.334 belgenin
    /// tamamı o tarihten eski). Yani "açık" iddiası eDurum'a güvenemez; 120 günlük pencere
    /// bunu kısmen sınırlıyor, tamamen çözmüyor.
    /// </summary>
    public async Task<AcikSiparis?> GetAcikSiparisAsync(
        int stkId, DateOnly kesim, int gunPenceresi = 120, CancellationToken ct = default)
    {
        const string sql = """
            SELECT COUNT(DISTINCT s.eID)                  AS Belge,
                   CONVERT(decimal(18,2), SUM(sa.ehAdet)) AS SiparisAdet,
                   MAX(s.eTarih)                          AS SonSiparis
            FROM DerinSISBkm.dbo.sip s WITH (NOLOCK)
            JOIN DerinSISBkm.dbo.sipAyr sa WITH (NOLOCK) ON sa.ehID = s.eID
            WHERE sa.ehstkID = @stkId AND s.eDurum <> 2
              -- Yalnız SATIN ALMA: 0 Alış · 3 Yerel Alım. Süzgeç olmadan 9 Alış İade Emri,
              -- 1 Satış ve 13 Depo-Mağaza da "yolda mal" sayılıyordu (adetin %86'sı).
              AND s.eTip IN (0, 3)
              AND s.eTarih >= DATEADD(DAY, -@gun, @kesim)
            """;
        await using var conn = await db.OpenAsync();
        var r = await conn.QuerySingleOrDefaultAsync<AcikSiparis>(new CommandDefinition(sql,
            new { stkId, gun = gunPenceresi, kesim = kesim.ToDateTime(TimeOnly.MinValue) },
            commandTimeout: 60, cancellationToken: ct));
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
              AND h.ehTrhS >= @bas AND h.ehTrhS < @son
            GROUP BY DATEFROMPARTS(YEAR(h.ehTrhS), MONTH(h.ehTrhS), 1)
            ORDER BY 1
            """;
        await using var conn = await db.OpenAsync();
        var ham = (await conn.QueryAsync<AylikSatis>(new CommandDefinition(sql,
            new
            {
                stkId,
                bas = TamAyPenceresi(kesim).Bas,
                son = TamAyPenceresi(kesim).Son,
            }, commandTimeout: 60, cancellationToken: ct))).ToList();

        var (basAy, sonAyHaric) = TamAyPenceresi(kesim);
        var sonAy = sonAyHaric.AddMonths(-1);   // son TAM ay (kesim ayı dışarıda)
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
              AND h.ehTrhS >= @bas AND h.ehTrhS < @son
            GROUP BY DATEFROMPARTS(YEAR(h.ehTrhS), MONTH(h.ehTrhS), 1)
            ORDER BY 1
            """;
        var (bas, son) = TamAyPenceresi(kesim);
        await using var conn = await db.OpenAsync();
        await using var grid = await conn.QueryMultipleAsync(new CommandDefinition(sql,
            new { stkId, bas, son },
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
              AND h.ehTrhS >= @bas AND h.ehTrhS < @son
            """;
        // ⚠ TAM AY (10.09.2026): yarım ay hem sezona hem dışına yazılıyordu. Eski pencerede
        // MONTH IN (8,9,10) İKİ AYRI SEZONUN parçasını topluyordu (Eyl'25 kırpık + Eki'25 +
        // Ağu'26 + Eyl'26 kırpık). Pay ve payda BİRLİKTE hizalanır — oran bozulmaz.
        var (basDt, sonDt) = TamAyPenceresi(kesim);
        var bas = DateOnly.FromDateTime(basDt);
        var sonHaric = DateOnly.FromDateTime(sonDt);
        await using var conn = await db.OpenAsync();
        var ham = await conn.QuerySingleAsync<(int SezonAdet, int DisiAdet)>(
            new CommandDefinition(sql,
                new { stkId, bas = basDt, son = sonDt },
                commandTimeout: 60, cancellationToken: ct));

        // ⚠ PAYDA RAF PENCERESİ (düzeltme 09.09 — kullanıcı uyarısı "stok gireli 365 gün
        // olmadıysa 365'e bölmek mantıksız"). Gün sayımı ürünün mağazada OLDUĞU günlerden
        // başlar; ilk girişten önceki günler ne sezona ne sezon dışına yazılır.
        // İlk giriş bilinmiyorsa pencerenin tamamı sayılır (1.186 ürün — ölçüldü).
        var ilk = ilkGiris is { } ig ? DateOnly.FromDateTime(ig) : bas;
        var sayimBas = ilk > bas ? ilk : bas;

        int sezonGun = 0, disiGun = 0;
        for (var g = sayimBas; g < sonHaric; g = g.AddDays(1))
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
                   -- ⚠ SIFIR SENTINEL: eFirma=0 → frm'deki "GENEL" satırına bağlanır ve
                   -- gerçek tedarikçi gibi görünür (ölçüldü 12.09.2026). Ayrı etiketlenir.
                   (SELECT TOP 1 CASE WHEN f2.eFirma = 0 THEN N'(tedarikçi yok — iç işlem)'
                                      ELSE ISNULL(fr.frmAd, '(firma adı yok)') END
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
                   -- ⚠ SIFIR SENTINEL (ölçüldü 12.09.2026): `irs.eFirma = 0` "karşı taraf YOK" demektir
            -- (Sayım 25.415 · POS Satış 6.895 · POS Satış İade 6.886 · Bozuk Ürün · Dönüşüm —
            -- hepsi iç işlem). `dbo.frm`'de frmID=0 diye BİR SATIR VAR ve adı **GENEL** →
            -- LEFT JOIN NULL DÖNMEZ, ISNULL koruması boşa çıkar ve ekranda "GENEL" adlı bir
            -- ŞİRKET görünür. sql-server-conventions § SIFIR SENTINEL.
            -- Bugün bu yolda 0 satır (ölçüldü: merkez çıkış 1.125 belgenin 0'ı, alış 9.660'ın 0'ı)
            -- ama ehTip 101 süzgeçte ve o tip evrende eFirma=0 taşıyor → kapı şimdi kuruluyor.
            CASE WHEN i.eFirma = 0 THEN N'(karşı taraf yok — iç işlem)'
                        ELSE ISNULL(f.frmAd, '(firma kaydı yok)') END AS FirmaAd,
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
        // ⚠ Bu AYLIK SERİ DEĞİL — 365 günlük tek toplam. Tam-ay hizası yalnız aylık
        // grafiklere uygulanır; buradaki pencere kasten 365 gün (manşetle aynı tanım).
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
        // ÜRÜN GRUBU (Kat1) — "defter grubu" gibi sorular bununla cevaplanır.
        // ⚠ Kategori1 (=KatAna) alt kırılım VERMEZ; Kırtasiye'de 52.021 çeşidin hepsi "Kırtasiye".
        if (!string.IsNullOrWhiteSpace(f.Kat1)) { sartlar.Add("t.Kat1 = @kat1"); p.Add("kat1", f.Kat1); }
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
            SatisDurumFiltre.StoksuzSezon => StoksuzSezonSart,
            SatisDurumFiltre.AsiriStok => AsiriStokSart,
            // ⚠ KPI'daki HareketsizCesit ile AYNI ifade olmalı (ayrışırsa kart ve liste
            // farklı sayı gösterir). Yenilik koruması: yeni açılan ürün haksız damgalanmasın —
            // ölçüldü 09.09, stkID 1739163 vakası (kart 04.09.2026, mağazaya hiç girmemiş).
            // KPI'daki RafsizCesit / RafBosCesit ile AYNI ifadeler (ayrışma yasak).
            SatisDurumFiltre.Rafsiz => RafsizSart,
            // KPI ile AYNI: üç rafın HEPSİ boş. Toplam kullanmak negatif stoğu maskeliyordu
            // (stkID 1697931: FSM 5 · İst.Yolu −13 → toplam −8 "boş" görünüyordu).
            SatisDurumFiltre.RafBos => RafBosSart,
            SatisDurumFiltre.Hareketsiz => OluStokSart,
            // KPI KirliCesit ile AYNI ifade. Mekan bazlı negatif dahil — merkez pozitifken
            // mağaza rafındaki eksi stok gizleniyordu (ölçüldü: 187 çeşit / 4,89M ₺).
            SatisDurumFiltre.VeriKirli => DefterGuvenilmezSart,
            // KPI MaliyetSupheliCesit ile AYNI ifade (ayrışırsa kart ve liste ayrı sayı gösterir).
            SatisDurumFiltre.MaliyetSupheli => MaliyetSupheliSart,
            // Filtrenin TERSİ: yalnız taze stok. TazeGunHaric ile birlikte kullanılmaz (biri diğerini boşaltır).
            SatisDurumFiltre.SadeceTaze =>
                "(COALESCE(t.SonGiris, t.IlkGiris, t.AcilisTarihi) >= DATEADD(DAY, -@tazeGun, @kesim))",
            // ⚠ KPI'daki YeniCesit ile AYNI ifade (ayrışırsa kart ve liste farklı sayı verir).
            SatisDurumFiltre.Yeni =>
                "(COALESCE(t.IlkGiris, t.AcilisTarihi) >= DATEADD(DAY, -@yeniGun, @kesim) " +
                "AND t.ToplamStok > 0)",
            // ⚠ Kohort ölçütleri KPI ile AYNI SABİTTEN gelir (ayrışma imkânsız).
            SatisDurumFiltre.Dengesiz => DengesizSart,
            SatisDurumFiltre.SezonAcik => SezonHazirlikSart,
            SatisDurumFiltre.SezonRafAcigi => SezonRafAcigiSart,
            // Talep deseni — panelin hız metriklerinin geçerli olduğu/olmadığı küme.
            SatisDurumFiltre.DuzgunTalep => GunStokGuvenilirSart,
            SatisDurumFiltre.AraliklıTalep =>
                "(t.SatanAy IS NOT NULL AND t.SatanAy > 0 AND NOT " + GunStokGuvenilirSart + ")",
            // ⚠ KPI'daki SiparisCesit / SiparisAcilCesit ile AYNI sabitten gelir (ayrışma imkânsız).
            // Ölü stoğun iki yarısı — ölçüt KPI ile AYNI sabitten (OluStokSart), ayrım
            // yalnız SonSatis. "Hiç satmamış" = alım hatası · "satmış, durmuş" = talep kaybı.
            SatisDurumFiltre.HicSatilmamis => "(" + OluStokSart + " AND t.SonSatis IS NULL)",
            SatisDurumFiltre.SatmisDurmus => "(" + OluStokSart + " AND t.SonSatis IS NOT NULL)",
            SatisDurumFiltre.SiparisIhtiyaci => SiparisSart,
            SatisDurumFiltre.SiparisAcil => SiparisAcilSart,
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

/// <summary>
/// POS'ta FİİLEN gerçekleşen satış — kart fiyatı değil. 365 gün, iade hariç.
/// Türev ölçüler burada; SQL yalnız ham toplamı verir (emitter-ayrimi).
/// </summary>
public sealed record UrunGerceklesen(
    decimal Adet, decimal NetKdvDahil, decimal BrutKdvDahil, decimal Kdv,
    decimal IndirimKampanya, int Kalem,
    // ⚠ SIRA SQL SELECT SIRASIYLA AYNI — Dapper pozisyonel record'da isim değil SIRA eşler.
    // İade NETLİ set (SUM soruları için); iade HARİÇ set yukarıda (AVG soruları için).
    decimal AdetNet, decimal NetNet, decimal KdvNet)
{
    /// <summary>Gerçekleşen ortalama satış fiyatı, KDV DAHİL (müşterinin ödediği).</summary>
    public decimal BirimKdvDahil => Adet <= 0 ? 0 : NetKdvDahil / Adet;

    /// <summary>KDV HARİÇ birim — maliyetle aynı tabana getirilmiş hâli (marj burada hesaplanır).</summary>
    public decimal BirimKdvHaric => Adet <= 0 ? 0 : (NetKdvDahil - Kdv) / Adet;

    /// <summary>Kart fiyatına göre gerçekleşme oranı. 1'in altı = indirimle satılıyor.</summary>
    public decimal? KartOrani(decimal kartFiyat) =>
        kartFiyat <= 0 || Adet <= 0 ? null : NetKdvDahil / Adet / kartFiyat;

    /// <summary>Ortalama indirim oranı (brüt→net). POS'un kendi indirim kolonundan.</summary>
    public decimal? IndirimOrani =>
        BrutKdvDahil <= 0 ? null : (BrutKdvDahil - NetKdvDahil) / BrutKdvDahil;

    /// <summary>
    /// İndirimin ne kadarı KAMPANYA kaynaklı (geri kalanı elle/kasa indirimi).
    /// ⚠ <c>DiscountTotalCampaign</c>, <c>DiscountTotalDirect</c>'in ALT KÜMESİdir —
    /// toplanmaz (sql-server-conventions § İndirim Kolonları). Payda toplam indirim.
    /// </summary>
    public decimal? KampanyaPayi =>
        BrutKdvDahil - NetKdvDahil is var toplam && toplam <= 0 ? null : IndirimKampanya / toplam;

    /// <summary>BİRİM KÂR (KDV hariç) — gerçekleşen fiyat − alış maliyeti.</summary>
    public decimal? BirimKar(decimal? birimMaliyet) =>
        birimMaliyet is null or <= 0 || Adet <= 0 ? null : BirimKdvHaric - birimMaliyet.Value;

    /// <summary>BRÜT MARJ = kâr ÷ satış (yukarıdan aşağı). Satıştan ne kadarı kâr.</summary>
    public decimal? Marj(decimal? birimMaliyet) =>
        BirimKar(birimMaliyet) is not { } k || BirimKdvHaric <= 0 ? null : k / BirimKdvHaric;

    /// <summary>MARKUP = kâr ÷ maliyet (aşağıdan yukarı). Maliyetin üstüne ne kondu.</summary>
    public decimal? Markup(decimal? birimMaliyet) =>
        BirimKar(birimMaliyet) is not { } k || birimMaliyet is null or <= 0 ? null : k / birimMaliyet.Value;

    /// <summary>Satılan adet üzerinden TOPLAM kâr (365 gün).</summary>
    /// <summary>
    /// 365 günlük kâr — <b>İADE NETLİ adetle</b> (düzeltme 10.09.2026). Birim kâr iade
    /// HARİÇ ortalamadan gelir (AVG kuralı), toplam ise NETLİ adetle çarpılır (SUM kuralı).
    /// Eskiden iade-hariç adet kullanılıyordu ve tutar şişiyordu.
    /// </summary>
    public decimal? ToplamKar(decimal? birimMaliyet) =>
        BirimKar(birimMaliyet) is not { } k ? null : k * AdetNet;

    /// <summary>İade netli net satış, KDV hariç — toplam tutar soruları için.</summary>
    public decimal NetKdvHaricNet => NetNet - KdvNet;

    /// <summary>İade oranı (adet) — netli ÷ hariç. 1'e yakın = iade yok.</summary>
    public decimal? IadeOrani => Adet <= 0 ? null : 1m - AdetNet / Adet;
}

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
