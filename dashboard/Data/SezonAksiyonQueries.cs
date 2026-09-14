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
    private const string TabanSql = $"""
        FROM {Taban} t WITH (NOLOCK)
        CROSS APPLY (SELECT Satilacak = CONVERT(int, CEILING(t.SezonToplam * (1.0 + @buyume))),
                            Elde      = t.MagazaStok + t.MerkezStok) s
        WHERE t.Kesim = @kesim AND t.SezonYil = @sezon
          AND t.SezonToplam > 0
          AND t.StokFsm >= 0 AND t.StokOzl >= 0 AND t.StokIst >= 0 AND t.MerkezStok >= 0
          AND t.SatisFiyat > 0
          AND (@yalnizAcik  = 0 OR s.Satilacak > s.Elde)
          AND (@yalnizFazla = 0 OR s.Elde > s.Satilacak)
          AND (@kategori IS NULL OR t.Kategori3 = @kategori)
          AND (@ara IS NULL OR t.stkAd LIKE @araLike OR t.BarkodAna = @ara)
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
        p.Add("yalnizAcik", f.Durum == "acik" ? 1 : 0);
        p.Add("yalnizFazla", f.Durum == "fazla" ? 1 : 0);
        p.Add("kategori", string.IsNullOrWhiteSpace(f.Kategori3) ? null : f.Kategori3);
        var ara = string.IsNullOrWhiteSpace(f.Arama) ? null : f.Arama.Trim();
        p.Add("ara", ara);
        p.Add("araLike", ara is null ? null : "%" + ara + "%");
        return p;
    }

    /// <summary>Tabanda hazır kesimler (en yeni önce). Boş dönerse taban doldurulmamıştır.</summary>
    public async Task<IReadOnlyList<DateOnly>> GetKesimlerAsync(CancellationToken ct = default)
    {
        const string sql = $"SELECT DISTINCT Kesim FROM {Taban} WITH (NOLOCK) ORDER BY Kesim DESC";
        await using var conn = await db.OpenAsync();
        var d = await conn.QueryAsync<DateTime>(
            new CommandDefinition(sql, commandTimeout: 60, cancellationToken: ct));
        return d.Select(DateOnly.FromDateTime).ToList();
    }

    /// <summary>KPI + kategori kırılımı — tek gidiş dönüş (iki sonuç kümesi).</summary>
    public async Task<SezonAksiyonOzet> GetOzetAsync(SezonAksiyonFiltre f, CancellationToken ct = default)
    {
        var sql = $"""
            SELECT CONVERT(int, COUNT(*))                                                  AS Cesit,
                   CONVERT(int,  SUM(CASE WHEN s.Satilacak > s.Elde THEN 1 ELSE 0 END))    AS AcikUrun,
                   CONVERT(bigint, SUM(CASE WHEN s.Satilacak > s.Elde
                                            THEN s.Satilacak - s.Elde ELSE 0 END))         AS AcikAdet,
                   CONVERT(decimal(18,2), SUM(CASE WHEN s.Satilacak > s.Elde
                        THEN (s.Satilacak - s.Elde) * t.SatisFiyat ELSE 0 END))            AS AcikTutar,
                   CONVERT(int,  SUM(CASE WHEN s.Elde > s.Satilacak THEN 1 ELSE 0 END))    AS FazlaUrun,
                   CONVERT(bigint, SUM(CASE WHEN s.Elde > s.Satilacak
                                            THEN s.Elde - s.Satilacak ELSE 0 END))         AS FazlaAdet,
                   CONVERT(decimal(18,2), SUM(CASE WHEN s.Elde > s.Satilacak AND {MaliyetGecerli}
                        THEN (s.Elde - s.Satilacak) * t.BirimMaliyet ELSE 0 END))          AS FazlaTutar,
                   CONVERT(int,  SUM(CASE WHEN s.Elde > s.Satilacak AND NOT {MaliyetGecerli}
                                          THEN 1 ELSE 0 END))                              AS MaliyetiYok
            {TabanSql};

            SELECT ISNULL(t.Kategori3, N'(boş)')                                           AS Kategori,
                   CONVERT(int, COUNT(*))                                                  AS Cesit,
                   CONVERT(int,  SUM(CASE WHEN s.Satilacak > s.Elde THEN 1 ELSE 0 END))    AS AcikUrun,
                   CONVERT(bigint, SUM(CASE WHEN s.Satilacak > s.Elde
                                            THEN s.Satilacak - s.Elde ELSE 0 END))         AS AcikAdet,
                   CONVERT(decimal(18,2), SUM(CASE WHEN s.Satilacak > s.Elde
                        THEN (s.Satilacak - s.Elde) * t.SatisFiyat ELSE 0 END))            AS AcikTutar,
                   CONVERT(int,  SUM(CASE WHEN s.Elde > s.Satilacak THEN 1 ELSE 0 END))    AS FazlaUrun,
                   CONVERT(bigint, SUM(CASE WHEN s.Elde > s.Satilacak
                                            THEN s.Elde - s.Satilacak ELSE 0 END))         AS FazlaAdet,
                   CONVERT(decimal(18,2), SUM(CASE WHEN s.Elde > s.Satilacak AND {MaliyetGecerli}
                        THEN (s.Elde - s.Satilacak) * t.BirimMaliyet ELSE 0 END))          AS FazlaTutar
            {TabanSql}
            GROUP BY t.Kategori3
            ORDER BY 5 DESC;
            """;

        await using var conn = await db.OpenAsync();
        await using var g = await conn.QueryMultipleAsync(
            new CommandDefinition(sql, P(f), commandTimeout: 180, cancellationToken: ct));
        var kpi = await g.ReadFirstOrDefaultAsync<SezonAksiyonKpi>()
                  ?? new SezonAksiyonKpi(0, 0, 0, 0, 0, 0, 0, 0);
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
            t.BarkodAna                               AS Barkod,
            t.stkAd                                   AS StkAd,
            t.Kategori3                               AS Kategori3,
            {YolSql}                                  AS KategoriYolu,
            t.Yayinevi                                AS Yayinevi,
            CONVERT(decimal(18,2), t.SatisFiyat)      AS SatisFiyat,
            t.SatisToplam                             AS SatisToplam,
            t.SezonToplam                             AS SezonToplam,
            s.Satilacak                               AS Satilacak,
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
            SELECT CONVERT(int, COUNT(*)) {TabanSql};

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
