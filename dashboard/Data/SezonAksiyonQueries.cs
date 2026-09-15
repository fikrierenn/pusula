using Dapper;
using GmDashboard.Models;

namespace GmDashboard.Data;

/// <summary>
/// SEZON AKSİYON LİSTESİ sorguları — SALT-SELECT (erp-write-policy).
/// Kaynak: <c>bkm.SatisAnaliziTaban</c> ön-agregası (Satış Analizi paneliyle AYNI taban).
///
/// HESAP (tek yerde — <see cref="TabanSql"/>):
///   Satılacak = CEILING(sezonda satılan × (1 + büyüme))
///   Elde      = mağaza stok + merkez(depo) stok
///   AÇIK      = Satılacak − Elde   (pozitifse)   → sipariş / transfer
///   FAZLA     = Elde − Satılacak   (pozitifse)   → indirim / iade / transfer
///
/// ⚠ 3-PARÇALI İSİM ZORUNLU: <c>Db.OpenAsync</c> varsayılan katalog = master (Err 208).
/// ⚠ Kardeş emitter <c>scripts/sezon_aksiyon_listesi_excel.py</c> ile iş mantığı AYNI —
///   biri değişirse öteki de değişir (emitter-ayrimi.md).
///
/// SINIRLAR (ekranda da yazılı — beyan edilmeyen sınır yanıltır):
///  · Açık sipariş DÜŞÜLMEZ. ERP'de "kapalı" durumu (<c>sip.eDurum=2</c>) 24.02.2025'ten
///    beri hiç yazılmıyor; kapatılmamış alış siparişi adedinin %86,4'ü bir yıldan eski
///    (ölçüldü 14.09.2026, sorgular/2026-09-14-sezon-stok-yaniltici-alti-madde.sql blok 2-3).
///  · FAZLA ₺ ALT SINIR: maliyeti yok/şüpheli (TMS 2: 0 &lt; maliyet ≤ satış fiyatı) olan
///    satır adet olarak sayılır, paraya girmez.
///  · Depo stoğu WMS kaynaklıdır; ERP defteriyle çelişebilir (hayalet stok).
///  · Tek gün fotoğrafı — stok gün içinde değişir.
/// </summary>
public sealed class SezonAksiyonQueries(Db db, ILogger<SezonAksiyonQueries> logger)
{
    private const string Taban = "DerinSISBkm.bkm.SatisAnaliziTaban";

    private const string MaliyetGecerli = "(t.BirimMaliyet > 0 AND t.BirimMaliyet <= t.SatisFiyat)";

    /// <summary>
    /// FROM + APPLY + WHERE — üç sorgunun (KPI · kategori · liste) ORTAK gövdesi.
    /// ⚠ Kohort tanımı TEK yerde: KPI ile listenin ayrışması "kart 100 diyor, listede 80 var"
    /// sınıfı sessiz hatadır.
    /// </summary>
    /// <summary>
    /// AYNI PENCERE — iki yılın satışı BİREBİR aynı uzunlukta ölçülür (GMY 15.09.2026:
    /// "aynı pencereye getirelim"). Pencere okul açılışına HİZALIDIR; takvim günüyle
    /// hizalamak yanıltır (açılış 08.09.2025 → 14.09.2026, altı gün kaydı).
    /// ⚠ Tabanda hazır değil — <c>SatisToplam</c> [kesim−364, kesim] penceresindedir ve
    /// geçen sezonun başını KAÇIRIR. Bu yüzden iki dar CTE (44'er gün) ile canlı ölçülür.
    /// </summary>
    private const string PencereSql = $"""
        WITH gh AS (
            SELECT h.ehstkID AS stkID, -SUM(h.ehAdetN) AS Adet
            FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
            WHERE h.ehMekan IN (1, 4477, 4478) AND h.ehTip IN (1, 3, 4, 5, 100, 101)
              AND h.ehTrhS >= @gBas AND h.ehTrhS < @gSonEx
            GROUP BY h.ehstkID
        ),
        bh AS (
            SELECT h.ehstkID AS stkID, -SUM(h.ehAdetN) AS Adet
            FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
            WHERE h.ehMekan IN (1, 4477, 4478) AND h.ehTip IN (1, 3, 4, 5, 100, 101)
              AND h.ehTrhS >= @bBas AND h.ehTrhS < @bSonEx
            GROUP BY h.ehstkID
        ),
        gk AS (   -- GEÇEN yılın KALAN sezon dilimi — AÇIK/FAZLA'nın TABANI
            SELECT h.ehstkID AS stkID, -SUM(h.ehAdetN) AS Adet
            FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
            WHERE h.ehMekan IN (1, 4477, 4478) AND h.ehTip IN (1, 3, 4, 5, 100, 101)
              AND h.ehTrhS >= @gkBas AND h.ehTrhS < @gkSonEx
            GROUP BY h.ehstkID
        ),
        yl AS (   -- YILLIK 365 gün: 01.08.<sezon> – 31.07.<sezon+1>, HER ŞEY dahil
            SELECT h.ehstkID AS stkID, -SUM(h.ehAdetN) AS Adet
            FROM DerinSISBkm.dbo.irsHrk h WITH (NOLOCK)
            WHERE h.ehMekan IN (1, 4477, 4478) AND h.ehTip IN (1, 3, 4, 5, 100, 101)
              AND h.ehTrhS >= @yBas AND h.ehTrhS < @ySonEx
            GROUP BY h.ehstkID
        )
        """;

    private const string TabanSql = $"""
        FROM {Taban} t WITH (NOLOCK)
        -- stkKod tabanda YOK (yalnız BarkodAna var) — ürün master'ından okunur.
        -- ⚠ stkKod BARKOD DEĞİLDİR; eşleşme her zaman stkID üstünden.
        LEFT JOIN DerinSISBkm.dbo.urn u WITH (NOLOCK) ON u.stkID = t.stkID
        LEFT JOIN gh ON gh.stkID = t.stkID
        LEFT JOIN bh ON bh.stkID = t.stkID
        LEFT JOIN gk ON gk.stkID = t.stkID
        LEFT JOIN yl ON yl.stkID = t.stkID
        -- ⚠ TABAN: TÜM SEZON DEĞİL, KALAN SEZON (GMY 15.09.2026). Ölçüldü: tüm sezonla
        --   AÇIK 254,7M ₺, kalan sezonla 106,9M ₺ — 2,4 kat fark.
        -- ⚠ NEGATİF TALEP OLMAZ: gk negatifse (iade > satış) sıfıra kırpılır.
        CROSS APPLY (SELECT Satilacak = CASE WHEN ISNULL(gk.Adet, 0) > 0
                         THEN CONVERT(int, CEILING(gk.Adet * (1.0 + @buyume))) ELSE 0 END,
                            Elde      = t.MagazaStok + t.MerkezStok) s
        CROSS APPLY (SELECT Sinif = CASE
                WHEN ISNULL(gk.Adet, 0) <= 0 THEN CASE WHEN t.MagazaStok + t.MerkezStok > 0
                                                       THEN 3 ELSE 0 END   -- 3 SEZONU BİTTİ
                WHEN s.Satilacak > s.Elde THEN 1                           -- 1 AÇIK
                WHEN s.Elde > s.Satilacak THEN 2                           -- 2 FAZLA
                ELSE 0 END) g
        WHERE t.Kesim = @kesim AND t.SezonYil = @sezon
          AND t.SezonToplam > 0
          AND t.StokFsm >= 0 AND t.StokOzl >= 0 AND t.StokIst >= 0 AND t.MerkezStok >= 0
          AND t.SatisFiyat > 0
          -- ⚠ DÖRT SINIF (GMY 15.09.2026: "kalan sezonda satış olmayanları da ayrı göster").
          --   "SEZONU BİTTİ" = geçen yıl KALAN dilimde hiç satmamış + stoğu var. AÇIK'a
          --   giremez (talebi 0) ve FAZLA'dan AYRI tutulur: eylemi farklı.
          AND (@yalnizAcik  = 0 OR (s.Satilacak > s.Elde AND ISNULL(gk.Adet, 0) > 0))
          AND (@yalnizFazla = 0 OR (s.Elde > s.Satilacak AND ISNULL(gk.Adet, 0) > 0))
          AND (@yalnizBitti = 0 OR (ISNULL(gk.Adet, 0) <= 0 AND s.Elde > 0))
          AND (@kategori IS NULL OR t.Kategori3 = @kategori)
          AND (@ara IS NULL OR t.stkAd LIKE @araLike OR t.BarkodAna = @ara OR u.stkKod = @ara)
        """;

    /// <summary>Kategori yolu — panelin C# karşılığıyla (SatisAnaliziHucre.KategoriYolu) AYNI kural.</summary>
    private const string YolSql = """
        STUFF(ISNULL(N' > ' + NULLIF(t.Kategori1, N''), N'')
            + ISNULL(N' > ' + NULLIF(t.Kat1, N''), N'')
            + ISNULL(N' > ' + NULLIF(t.Kat2, N''), N'')
            + ISNULL(N' > ' + NULLIF(t.Kat3, N''), N'')
            + ISNULL(N' > ' + NULLIF(t.Kat4, N''), N''), 1, 3, N'')
        """;

    private static DynamicParameters P(SezonAksiyonFiltre f)
    {
        var p = new DynamicParameters();
        p.Add("kesim", f.Kesim.ToDateTime(TimeOnly.MinValue));
        p.Add("sezon", f.SezonYil);
        p.Add("buyume", f.Buyume);
        var (gb, gsn) = f.GecenPencere;
        var (bb, bsn) = f.BuPencere;
        // ⚠⚠ ÜST SINIR DIŞLAYICI (< açılış günü), "<= son gün 23:59:59.9999999" DEĞİL.
        //   ÖLÇÜLDÜ 15.09.2026: TimeOnly.MaxValue SQL `datetime` kolonuna yazılırken
        //   BİR SONRAKİ GÜNE YUVARLANIYOR (23:59:59.9999999 → 08.09.2025 00:00:00.000,
        //   datetime 3,33 ms çözünürlüklü). Sonuç: pencere 44 değil 45 gün oluyordu ve
        //   okul AÇILIŞ GÜNÜNÜN satışı içeri giriyordu. stkID 486093'te tam 20 adet fark
        //   (panel 606 / script 586). Ekran "44 gün" yazıp 45 gün ölçüyordu — sessiz sapma.
        //   Kanıt: sorgular/2026-09-15-ayni-pencere-ve-yanlis-alarm.sql blok 5.
        p.Add("gBas", gb.ToDateTime(TimeOnly.MinValue));
        p.Add("gSonEx", gsn.AddDays(1).ToDateTime(TimeOnly.MinValue));
        p.Add("bBas", bb.ToDateTime(TimeOnly.MinValue));
        p.Add("bSonEx", bsn.AddDays(1).ToDateTime(TimeOnly.MinValue));
        var (yb, ysn) = f.YilPencere;
        var (gkb, gks) = f.GecenKalanPencere;
        p.Add("gkBas", gkb.ToDateTime(TimeOnly.MinValue));
        p.Add("gkSonEx", gks.AddDays(1).ToDateTime(TimeOnly.MinValue));
        p.Add("yBas", yb.ToDateTime(TimeOnly.MinValue));
        p.Add("ySonEx", ysn.AddDays(1).ToDateTime(TimeOnly.MinValue));
        p.Add("yalnizAcik", f.Durum == "acik" ? 1 : 0);
        p.Add("yalnizFazla", f.Durum == "fazla" ? 1 : 0);
        p.Add("yalnizBitti", f.Durum == "bitti" ? 1 : 0);
        p.Add("kategori", string.IsNullOrWhiteSpace(f.Kategori3) ? null : f.Kategori3);
        var ara = string.IsNullOrWhiteSpace(f.Arama) ? null : f.Arama.Trim();
        p.Add("ara", ara);
        p.Add("araLike", ara is null ? null : "%" + ara + "%");
        return p;
    }

    /// <summary>
    /// Tabanda hazır kesimler + o kesimin sezon yılı (en yeni önce).
    /// ⚠ Sezon yılı EKRANDAN SORULMAZ: ölçüldü (15.09.2026) — her kesimde TEK sezon yılı var
    /// (13.09/11.09/10.09 → hepsi 2025). Kullanıcıya soru sormak, cevabı tek olan bir soruyu
    /// ekrana koymaktı. Birden çok çıkarsa en yenisi alınır ve kesim listesi bunu gösterir.
    /// </summary>
    public async Task<IReadOnlyList<(DateOnly Kesim, int SezonYil)>> GetKesimlerAsync(
        CancellationToken ct = default)
    {
        const string sql = $"""
            SELECT Kesim, MAX(SezonYil) AS SezonYil
            FROM {Taban} WITH (NOLOCK)
            GROUP BY Kesim
            ORDER BY Kesim DESC
            """;
        await using var conn = await db.OpenAsync();
        var d = await conn.QueryAsync<(DateTime Kesim, int SezonYil)>(
            new CommandDefinition(sql, commandTimeout: 60, cancellationToken: ct));
        return d.Select(x => (DateOnly.FromDateTime(x.Kesim), x.SezonYil)).ToList();
    }

    /// <summary>KPI + kategori kırılımı — tek gidiş dönüş (iki sonuç kümesi).</summary>
    public async Task<SezonAksiyonOzet> GetOzetAsync(SezonAksiyonFiltre f, CancellationToken ct = default)
    {
        var sql = $"""
            {PencereSql}
            SELECT CONVERT(int, COUNT(*))                                                  AS Cesit,
                   CONVERT(int,  SUM(CASE WHEN g.Sinif = 1 THEN 1 ELSE 0 END))            AS AcikUrun,
                   CONVERT(bigint, SUM(CASE WHEN g.Sinif = 1
                                            THEN s.Satilacak - s.Elde ELSE 0 END))         AS AcikAdet,
                   CONVERT(decimal(18,2), SUM(CASE WHEN g.Sinif = 1
                        THEN (s.Satilacak - s.Elde) * t.SatisFiyat ELSE 0 END))            AS AcikTutar,
                   CONVERT(int,  SUM(CASE WHEN g.Sinif = 2 THEN 1 ELSE 0 END))            AS FazlaUrun,
                   CONVERT(bigint, SUM(CASE WHEN g.Sinif = 2
                                            THEN s.Elde - s.Satilacak ELSE 0 END))         AS FazlaAdet,
                   CONVERT(decimal(18,2), SUM(CASE WHEN g.Sinif = 2 AND {MaliyetGecerli}
                        THEN (s.Elde - s.Satilacak) * t.BirimMaliyet ELSE 0 END))          AS FazlaTutar,
                   CONVERT(int,  SUM(CASE WHEN g.Sinif = 3 THEN 1 ELSE 0 END))            AS BittiUrun,
                   CONVERT(bigint, SUM(CASE WHEN g.Sinif = 3
                                            THEN s.Elde - s.Satilacak ELSE 0 END))         AS BittiAdet,
                   CONVERT(decimal(18,2), SUM(CASE WHEN g.Sinif = 3 AND {MaliyetGecerli}
                        THEN (s.Elde - s.Satilacak) * t.BirimMaliyet ELSE 0 END))          AS BittiTutar,
                   CONVERT(int,  SUM(CASE WHEN g.Sinif IN (2,3) AND NOT {MaliyetGecerli}
                                          THEN 1 ELSE 0 END))                              AS MaliyetiYok
            {TabanSql};

            {PencereSql}
            SELECT ISNULL(t.Kategori3, N'(boş)')                                           AS Kategori,
                   CONVERT(int, COUNT(*))                                                  AS Cesit,
                   CONVERT(int,  SUM(CASE WHEN g.Sinif = 1 THEN 1 ELSE 0 END))            AS AcikUrun,
                   CONVERT(bigint, SUM(CASE WHEN g.Sinif = 1
                                            THEN s.Satilacak - s.Elde ELSE 0 END))         AS AcikAdet,
                   CONVERT(decimal(18,2), SUM(CASE WHEN g.Sinif = 1
                        THEN (s.Satilacak - s.Elde) * t.SatisFiyat ELSE 0 END))            AS AcikTutar,
                   CONVERT(int,  SUM(CASE WHEN g.Sinif = 2 THEN 1 ELSE 0 END))            AS FazlaUrun,
                   CONVERT(bigint, SUM(CASE WHEN g.Sinif = 2
                                            THEN s.Elde - s.Satilacak ELSE 0 END))         AS FazlaAdet,
                   CONVERT(decimal(18,2), SUM(CASE WHEN g.Sinif = 2 AND {MaliyetGecerli}
                        THEN (s.Elde - s.Satilacak) * t.BirimMaliyet ELSE 0 END))          AS FazlaTutar
            {TabanSql}
            GROUP BY t.Kategori3
            ORDER BY 5 DESC;
            """;

        await using var conn = await db.OpenAsync();
        await using var g = await conn.QueryMultipleAsync(
            new CommandDefinition(sql, P(f), commandTimeout: 180, cancellationToken: ct));
        var kpi = await g.ReadFirstOrDefaultAsync<SezonAksiyonKpi>()
                  ?? new SezonAksiyonKpi(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
        var kat = (await g.ReadAsync<SezonAksiyonKategori>()).ToList();
        return new SezonAksiyonOzet(kpi, kat);
    }

    /// <summary>
    /// Kategori3 seçenekleri — süzgeç açılırı. Kohort filtresinden BAĞIMSIZ (aksi hâlde
    /// bir kategoriyi seçince öteki seçenekler kaybolurdu).
    /// </summary>
    public async Task<IReadOnlyList<string>> GetKategorilerAsync(
        SezonAksiyonFiltre f, CancellationToken ct = default)
    {
        const string sql = $"""
            SELECT DISTINCT t.Kategori3
            FROM {Taban} t WITH (NOLOCK)
            WHERE t.Kesim = @kesim AND t.SezonYil = @sezon AND t.SezonToplam > 0
              AND t.Kategori3 IS NOT NULL AND t.Kategori3 <> N''
            ORDER BY t.Kategori3
            """;
        await using var conn = await db.OpenAsync();
        var p = new DynamicParameters();
        p.Add("kesim", f.Kesim.ToDateTime(TimeOnly.MinValue));
        p.Add("sezon", f.SezonYil);
        return (await conn.QueryAsync<string>(
            new CommandDefinition(sql, p, commandTimeout: 60, cancellationToken: ct))).ToList();
    }

    /// <summary>
    /// SELECT kolonları — ekran, sayfalama ve Excel AYNI listeyi kullanır.
    /// ⚠ SIRA = <see cref="SezonAksiyonSatir"/> parametre sırası (Dapper pozisyonel record).
    /// </summary>
    private static string KolonlarSql => $"""
            t.stkID                                   AS StkId,
            u.stkKod                                  AS StkKod,
            t.BarkodAna                               AS Barkod,
            t.stkAd                                   AS StkAd,
            t.Kategori3                               AS Kategori3,
            {YolSql}                                  AS KategoriYolu,
            t.Yayinevi                                AS Yayinevi,
            CONVERT(decimal(18,2), t.SatisFiyat)      AS SatisFiyat,
            CONVERT(int, ISNULL(gh.Adet, 0))          AS GecenAyni,
            CONVERT(int, ISNULL(bh.Adet, 0))          AS BuAyni,
            t.SezonToplam                             AS SezonToplam,
            CONVERT(int, ISNULL(yl.Adet, 0))          AS Yillik,
            CONVERT(int, ISNULL(gk.Adet, 0))          AS GecenKalan,
            s.Satilacak                               AS Satilacak,
            t.StokFsm                                 AS StokFsm,
            t.StokOzl                                 AS StokOzl,
            t.StokIst                                 AS StokIst,
            t.MagazaStok                              AS MagazaStok,
            t.MerkezStok                              AS MerkezStok,
            s.Elde                                    AS ToplamStok,
            CONVERT(int, CASE WHEN s.Satilacak > s.Elde THEN s.Satilacak - s.Elde ELSE 0 END) AS Acik,
            CONVERT(int, CASE WHEN s.Elde > s.Satilacak THEN s.Elde - s.Satilacak ELSE 0 END) AS Fazla,
            CONVERT(decimal(18,2), CASE WHEN s.Satilacak > s.Elde
                 THEN (s.Satilacak - s.Elde) * t.SatisFiyat END)                              AS AcikTutar,
            CONVERT(decimal(18,2), CASE WHEN s.Elde > s.Satilacak AND {MaliyetGecerli}
                 THEN (s.Elde - s.Satilacak) * t.BirimMaliyet END)                            AS FazlaTutar,
            CONVERT(decimal(18,2), CASE WHEN {MaliyetGecerli} THEN t.BirimMaliyet END)        AS BirimMaliyet
        """;

    public async Task<SayfaSonucu<SezonAksiyonSatir>> GetListeAsync(
        SezonAksiyonFiltre f, CancellationToken ct = default)
    {
        var yon = f.Azalan ? "DESC" : "ASC";
        // ⚠ COUNT(*) OVER () KULLANILMIYOR: Satış Analizi'nde sayfa başına 1,2 s ekliyordu.
        var sql = $"""
            {PencereSql}
            SELECT CONVERT(int, COUNT(*)) {TabanSql};

            {PencereSql}
            SELECT {KolonlarSql}
            {TabanSql}
            ORDER BY {SezonAksiyonSiralama.Sql(f.Sirala)} {yon}, t.stkID
            OFFSET @atla ROWS FETCH NEXT @al ROWS ONLY;
            """;

        var sayfa = Math.Max(1, f.Sayfa);
        var boyu = Math.Clamp(f.SayfaBoyu, 10, 500);
        var p = P(f);
        p.Add("atla", (sayfa - 1) * boyu);
        p.Add("al", boyu);

        await using var conn = await db.OpenAsync();
        await using var g = await conn.QueryMultipleAsync(
            new CommandDefinition(sql, p, commandTimeout: 180, cancellationToken: ct));
        var toplam = await g.ReadFirstAsync<int>();
        var satirlar = (await g.ReadAsync<SezonAksiyonSatir>()).ToList();
        return SayfaSonucu<SezonAksiyonSatir>.Olustur(satirlar, toplam, sayfa, boyu);
    }

    /// <summary>Excel için TÜM satırlar — sayfalama yok. Endpoint akışta yazar.</summary>
    public async Task<IReadOnlyList<SezonAksiyonSatir>> GetTumListeAsync(
        SezonAksiyonFiltre f, CancellationToken ct = default)
    {
        var yon = f.Azalan ? "DESC" : "ASC";
        var sql = $"""
            {PencereSql}
            SELECT {KolonlarSql}
            {TabanSql}
            ORDER BY {SezonAksiyonSiralama.Sql(f.Sirala)} {yon}, t.stkID
            """;
        await using var conn = await db.OpenAsync();
        var r = (await conn.QueryAsync<SezonAksiyonSatir>(
            new CommandDefinition(sql, P(f), commandTimeout: 600, cancellationToken: ct))).ToList();
        logger.LogInformation("Sezon aksiyon Excel: {Satir} satır (kesim {Kesim}, büyüme {B})",
            r.Count, f.Kesim, f.Buyume);
        return r;
    }
}
