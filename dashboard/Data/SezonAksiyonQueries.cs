using Dapper;
using GmDashboard.Models;

namespace GmDashboard.Data;

/// <summary>
/// SEZON SİPARİŞ LİSTESİ sorguları — SALT-SELECT (erp-write-policy).
/// Kaynak: <c>bkm.SatisAnaliziTaban</c> ön-agregası + canlı <c>irsHrk</c> pencereleri.
///
/// HESAP (sezon payı — tek yerde, <see cref="GovdeSql"/>):
///   ORAN    = geçen sezon OKUL ÖNCESİ ÷ geçen SEZON TOPLAMI          (ŞUBE bazlı)
///   TAHMİN  = bu sezon OKUL ÖNCESİ ÷ ORAN                            (ŞUBE bazlı)
///   KALAN   = TAHMİN − bu sezon bugüne kadar satılan                 (ŞUBE bazlı)
///   EKSİK   = Σ max(0, şube kalanı − şube stoğu)
///   SİPARİŞ = EKSİK − merkez depo stoğu   (mağazalar arası aktarma varsayılmaz)
///
/// ⚠ 3-PARÇALI İSİM ZORUNLU: <c>Db.OpenAsync</c> varsayılan katalog = master (Err 208).
/// ⚠ Kardeş emitter'lar: <c>scripts/sezon_aksiyon_listesi_excel.py</c> ve
///   <c>sorgular/2026-09-15-sezon-aksiyon-listesi.sql</c> — iş mantığı AYNI kalmalı
///   (emitter-ayrimi.md). ÖLÇÜLDÜ 16.09.2026 (Defterler, 7.784 çeşit):
///   SİPARİŞ VER 703 / 13.221 adet / 2.077.342 ₺ · DEPODAN GÖNDER 511 / 22.442 ·
///   FAZLA VAR 2.141 / 270.308 / 10.805.472 ₺ · ÖLÜ STOK 3.599 / 44.515 / 2.643.632 ₺ ·
///   YETERLİ 830.
///
/// SINIRLAR (ekranda da yazılı — beyan edilmeyen sınır yanıltır):
///  · Açık sipariş DÜŞÜLMEZ. ERP'de "kapalı" durumu (<c>sip.eDurum=2</c>) 24.02.2025'ten
///    beri hiç yazılmıyor; kapatılmamış alış siparişinin %86,4'ü bir yıldan eski.
///  · SİPARİŞ ₺ satış fiyatıyla, FAZLA/ÖLÜ ₺ maliyetle — TOPLANMAZ. Siparişteki tutar
///    kaybedilen CİRODUR, kaybedilen KÂR DEĞİL (marj ölçülmedi).
///  · Maliyeti yok/şüpheli (TMS 2: 0 &lt; maliyet ≤ satış fiyatı) satır adet olarak
///    sayılır, paraya girmez → fazla/ölü tutarı ALT SINIRDIR.
///  · Depo stoğu WMS kaynaklı; ERP defteriyle çelişebilir (hayalet stok).
///  · Alıcı (satınalmacı) boyutu veride YOK — GÖREV listesidir, kişiye atıf değildir.
/// </summary>
public sealed class SezonAksiyonQueries(Db db, ILogger<SezonAksiyonQueries> logger)
{
    private const string Taban = "DerinSISBkm.bkm.SatisAnaliziTaban";

    private const string MaliyetGecerli = "(t.BirimMaliyet > 0 AND t.BirimMaliyet <= t.SatisFiyat)";

    /// <summary>Üç şubenin satış hareketi — tek yerde (kod kopyalanınca biri bayatlar).</summary>
    private const string SatisFiltre =
        "h.ehMekan IN (1,4477,4478) AND h.ehTip IN (1,3,4,5,100,101)";

    /// <summary>
    /// SEZON PAYI GİRDİLERİ ARTIK TABANDA (16.09.2026).
    ///
    /// Önceden bu sınıf sekiz CTE (gp · gps · bps · bt · sn · kb · kb3 · gd · yl) kurup
    /// tabana ON LEFT JOIN ile bağlıyordu. ÖLÇÜLDÜ (kesim 13.09.2026, tüm evren
    /// 266.332 çeşit): CTE'ler tek başına ~7 s, taban-only tarama + tüm CROSS APPLY
    /// aritmetiği ~2 s, ikisi birleşik <b>36,6 s</b> — yani maliyet CTE'lerde değil,
    /// 266K satırı onlara bağlayan JOIN zincirindeydi. Üstelik gövde istek başına DÖRT
    /// kez koşuyordu (KPI · kategori · sayım · sayfa).
    ///
    /// Girdiler <c>SatisAnaliziTabanService</c> tarafından kesim başına BİR KEZ yazılıyor;
    /// burada yalnız okunuyor. Pencere tanımı tek kaynakta: <see cref="SezonPayiPencere"/>
    /// → <see cref="SezonAksiyonFiltre"/>.
    ///
    /// ⚠ Kolonlar NULL ise taban o kesim için bu girdiler OLMADAN doldurulmuştur.
    /// O durumda sorgu KOŞTURULMAZ — <see cref="SezonPayiHazirAsync"/> kapısı ekranı
    /// KOŞAMADI'ya düşürür. ISNULL(...,0) ile devam etmek "sipariş yok" diye sessiz
    /// yanlış rakam üretirdi.
    /// </summary>
    /// <summary>
    /// FROM + APPLY + WHERE — KPI · kategori · liste · Excel'in ORTAK gövdesi.
    /// ⚠ Kohort tanımı TEK yerde: KPI ile listenin ayrışması "kart 100 diyor, listede
    /// 80 var" sınıfı sessiz hatadır.
    /// </summary>
    private const string GovdeSql = $"""
        FROM {Taban} t WITH (NOLOCK)
        -- stkKod tabanda YOK (yalnız BarkodAna var) — ürün master'ından okunur.
        -- ⚠ stkKod BARKOD DEĞİLDİR; eşleşme her zaman stkID üstünden.
        LEFT JOIN DerinSISBkm.dbo.urn u WITH (NOLOCK) ON u.stkID = t.stkID
        -- ⚠ TEK JOIN KALDI (stkKod için). Sekiz CTE + on LEFT JOIN 16.09.2026'da
        --   tabana taşındı; ölçüm gerekçesi yukarıda.
        -- Ham girdiler tek yerde adlandırılır — aşağıdaki APPLY'lar bunları kullanır.
        CROSS APPLY (SELECT
                GecF = CONVERT(int, ISNULL(t.OncesiGecenFsm, 0)),
                GecO = CONVERT(int, ISNULL(t.OncesiGecenOzl, 0)),
                GecI = CONVERT(int, ISNULL(t.OncesiGecenIst, 0)),
                BuF  = CONVERT(int, ISNULL(t.OncesiBuFsm, 0)),
                BuO  = CONVERT(int, ISNULL(t.OncesiBuOzl, 0)),
                BuI  = CONVERT(int, ISNULL(t.OncesiBuIst, 0)),
                BugF = CONVERT(int, ISNULL(t.BuguneFsm, 0)),
                BugO = CONVERT(int, ISNULL(t.BuguneOzl, 0)),
                BugI = CONVERT(int, ISNULL(t.BuguneIst, 0))) h
        CROSS APPLY (SELECT
                GecTop = h.GecF + h.GecO + h.GecI,
                BuTop  = h.BuF  + h.BuO  + h.BuI,
                BugTop = h.BugF + h.BugO + h.BugI) ht
        -- YEDEK ORAN tabanda ÇÖZÜLMÜŞ (Kat2 → Kategori3); yoksa 0,60.
        -- ⚠ decimal(6,4) olarak SAKLANIR ve bu hâliyle çarpılır: GÖSTERİLEN oran =
        --   ÇARPILAN oran. Tam hassasiyet Excel emitter'ı ile ayrışıyordu — ÖLÇÜLDÜ
        --   16.09.2026: "depodan gönder" adedi SQL'de 22.445, Excel'de 22.442.
        CROSS APPLY (SELECT Kat = CONVERT(float, ISNULL(t.YedekOran, 0.60))) kk
        -- ⚠ TABAN EŞİĞİ 30 ADET: 1 adetten 3'e çıkan şube "oranım 0,33" demesin.
        -- ⚠ ALT SINIR 0,05: payda sıfıra yaklaşırsa bölme tahmini sonsuza götürür.
        -- ⚠ ÜST SINIR 1,00: oran 1'i geçemez (iade fazlası negatif kalan üretirdi).
        CROSS APPLY (SELECT
                OrF = CASE WHEN t.SezonFsm >= 30 AND h.GecF >= 30
                            AND CONVERT(float, h.GecF) / t.SezonFsm BETWEEN 0.05 AND 1.0
                           THEN CONVERT(float, h.GecF) / t.SezonFsm ELSE kk.Kat END,
                OrO = CASE WHEN t.SezonOzl >= 30 AND h.GecO >= 30
                            AND CONVERT(float, h.GecO) / t.SezonOzl BETWEEN 0.05 AND 1.0
                           THEN CONVERT(float, h.GecO) / t.SezonOzl ELSE kk.Kat END,
                OrI = CASE WHEN t.SezonIst >= 30 AND h.GecI >= 30
                            AND CONVERT(float, h.GecI) / t.SezonIst BETWEEN 0.05 AND 1.0
                           THEN CONVERT(float, h.GecI) / t.SezonIst ELSE kk.Kat END) po
        CROSS APPLY (SELECT
                TahF = CONVERT(int, CEILING(h.BuF / po.OrF)),
                TahO = CONVERT(int, CEILING(h.BuO / po.OrO)),
                TahI = CONVERT(int, CEILING(h.BuI / po.OrI))) th
        -- KALAN = tahmin − şu ana kadar satılan. Eksi olamaz: tahmin aşılmışsa
        -- "eksi ihtiyaç" değil, ihtiyaç YOK demektir.
        CROSS APPLY (SELECT
                KalF = CASE WHEN th.TahF > h.BugF THEN th.TahF - h.BugF ELSE 0 END,
                KalO = CASE WHEN th.TahO > h.BugO THEN th.TahO - h.BugO ELSE 0 END,
                KalI = CASE WHEN th.TahI > h.BugI THEN th.TahI - h.BugI ELSE 0 END) kl
        CROSS APPLY (SELECT
                Eksik = CASE WHEN kl.KalF > t.StokFsm THEN kl.KalF - t.StokFsm ELSE 0 END
                      + CASE WHEN kl.KalO > t.StokOzl THEN kl.KalO - t.StokOzl ELSE 0 END
                      + CASE WHEN kl.KalI > t.StokIst THEN kl.KalI - t.StokIst ELSE 0 END,
                Kalan = kl.KalF + kl.KalO + kl.KalI,
                DisT  = CONVERT(int, ISNULL(t.SezonDisiAdet, 0))) s
        -- SİPARİŞ = şubelerin toplam eksiği − merkez depo. Önce depodan gönderilir,
        -- ancak yetmeyen kısmı sipariş edilir. GMY: "mağazalar arası değil, depoda
        -- veya ODAK'ta varsa mümkün; diğer türlü hayal."
        CROSS APPLY (SELECT
                Siparis = CASE WHEN s.Eksik > t.MerkezStok THEN s.Eksik - t.MerkezStok ELSE 0 END,
                Fazla   = t.MagazaStok + t.MerkezStok - s.Kalan - s.DisT) x
        CROSS APPLY (SELECT Sinif = CASE
                WHEN t.SezonToplam <= 0 AND ht.BugTop <= 0
                     AND t.MagazaStok + t.MerkezStok > 0 THEN 5   -- ÖLÜ STOK
                WHEN x.Siparis > 0 THEN 1                         -- SİPARİŞ VER
                WHEN s.Eksik   > 0 THEN 4                         -- DEPODAN GÖNDER
                WHEN x.Fazla   > 0 THEN 2                         -- FAZLA VAR
                ELSE 0 END) g
        WHERE t.Kesim = @kesim AND t.SezonYil = @sezon
          -- KAPSAM: "geçen sezon fiilen satmış" şartı KALDIRILDI — bu sezon satan ama
          -- geçen sezon tabanı olmayan ürünleri dışarıda bırakıyordu. ÖLÇÜLDÜ
          -- (Defterler): 681'i 2026'da açılmış yeni ürün, 380'i eski ama geçen sezon
          -- satmamış; ikisi birlikte bu sezon 11.852 adet satmış.
          AND (t.SezonToplam > 0 OR ht.BugTop > 0
               OR t.MagazaStok + t.MerkezStok > 0)
          -- DEFTER GÜVENİLİR: negatif stok fiziksel durum değil, defter hatasıdır.
          AND t.StokFsm >= 0 AND t.StokOzl >= 0 AND t.StokIst >= 0 AND t.MerkezStok >= 0
          AND t.SatisFiyat > 0
          AND (@kategori IS NULL OR t.Kategori3 = @kategori)
          AND (@grup     IS NULL OR t.Kat1      = @grup)
          AND (@sinif    IS NULL OR g.Sinif     = @sinif)
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

    /// <summary>
    /// Parametreler — YALNIZ süzgeç. Pencere tarihleri BURADA YOK: sezon payı girdileri
    /// taban dolumunda (<see cref="SezonPayiPencere"/>) hesaplanıp saklanıyor, sorgu
    /// yalnız okuyor. İkinci bir pencere hesabı, okul açılış tablosu güncellenince
    /// sessizce bayatlardı.
    /// </summary>
    private static DynamicParameters P(SezonAksiyonFiltre f)
    {
        var p = new DynamicParameters();
        p.Add("kesim", f.Kesim.ToDateTime(TimeOnly.MinValue));
        p.Add("sezon", f.SezonYil);
        p.Add("sinif", SezonAksiyonSinif.Anahtardan(f.Durum));
        p.Add("kategori", string.IsNullOrWhiteSpace(f.Kategori3) ? null : f.Kategori3);
        p.Add("grup", string.IsNullOrWhiteSpace(f.Grup) ? null : f.Grup);
        var ara = string.IsNullOrWhiteSpace(f.Arama) ? null : f.Arama.Trim();
        p.Add("ara", ara);
        p.Add("araLike", ara is null ? null : "%" + ara + "%");
        return p;
    }

    /// <summary>
    /// TABAN KAPISI — o kesimde sezon payı girdileri yazılmış mı.
    ///
    /// ⚠ Taban bu kolonlar EKLENMEDEN önce doldurulmuşsa hepsi NULL olur. ISNULL(...,0)
    /// ile devam etmek her ürünü "talebi yok" gösterir ve ekran sessizce "sipariş yok"
    /// der — hata vermez. Bu yüzden eksik satır varsa sorgu KOŞTURULMAZ; ekran taban
    /// yenilenene kadar KOŞAMADI yazar.
    /// </summary>
    public async Task<(bool Hazir, int Toplam, int Eksik)> SezonPayiHazirAsync(
        SezonAksiyonFiltre f, CancellationToken ct = default)
    {
        const string sql = $"""
            SELECT CONVERT(int, COUNT(*)) AS Toplam,
                   CONVERT(int, SUM(CASE WHEN t.OncesiGecenFsm IS NULL THEN 1 ELSE 0 END)) AS Eksik
            FROM {Taban} t WITH (NOLOCK)
            WHERE t.Kesim = @kesim AND t.SezonYil = @sezon
            """;
        await using var conn = await db.OpenAsync();
        var p = new DynamicParameters();
        p.Add("kesim", f.Kesim.ToDateTime(TimeOnly.MinValue));
        p.Add("sezon", f.SezonYil);
        var r = await conn.QuerySingleAsync<(int Toplam, int Eksik)>(
            new CommandDefinition(sql, p, commandTimeout: 60, cancellationToken: ct));
        return (r.Toplam > 0 && r.Eksik == 0, r.Toplam, r.Eksik);
    }

    /// <summary>
    /// Tabanda hazır kesimler + o kesimin sezon yılı (en yeni önce).
    /// ⚠ Sezon yılı EKRANDAN SORULMAZ: ölçüldü (15.09.2026) — her kesimde TEK sezon
    /// yılı var. Cevabı tek olan soruyu ekrana koymak, soru sormak değildir.
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

    /// <summary>
    /// KPI kolonları — AYRI sabit. ⚠ Kategori bloğuyla aynı metottaki gömülü SELECT
    /// olarak dursaydı <c>tools/panel_kolon_denetimi.py</c> ikisinin alias'larını
    /// birleştirip okuyor ve sıra kıyası anlamsızlaşıyordu (ölçüldü 16.09.2026:
    /// "SQL 21, record 14"). Kapının görebilmesi için blok adlandırıldı.
    /// SİPARİŞ ₺ SATIŞ fiyatıyla, FAZLA/ÖLÜ ₺ MALİYETLE — ayrı tabanlar, toplanmaz.
    /// </summary>
    private const string OzetKolonlarSql = $"""
            CONVERT(int, COUNT(*))                                                AS Cesit,
            CONVERT(int,    SUM(CASE WHEN g.Sinif = 1 THEN 1 ELSE 0 END))         AS SiparisUrun,
            CONVERT(bigint, SUM(CASE WHEN g.Sinif = 1 THEN x.Siparis ELSE 0 END)) AS SiparisAdet,
            CONVERT(decimal(18,2), SUM(CASE WHEN g.Sinif = 1
                 THEN x.Siparis * t.SatisFiyat ELSE 0 END))                       AS SiparisTutar,
            CONVERT(int,    SUM(CASE WHEN g.Sinif = 4 THEN 1 ELSE 0 END))         AS DepodanUrun,
            CONVERT(bigint, SUM(CASE WHEN g.Sinif = 4 THEN s.Eksik ELSE 0 END))   AS DepodanAdet,
            CONVERT(int,    SUM(CASE WHEN g.Sinif = 2 THEN 1 ELSE 0 END))         AS FazlaUrun,
            CONVERT(bigint, SUM(CASE WHEN g.Sinif = 2 THEN x.Fazla ELSE 0 END))   AS FazlaAdet,
            CONVERT(decimal(18,2), SUM(CASE WHEN g.Sinif = 2 AND {MaliyetGecerli}
                 THEN x.Fazla * t.BirimMaliyet ELSE 0 END))                       AS FazlaTutar,
            CONVERT(int,    SUM(CASE WHEN g.Sinif = 5 THEN 1 ELSE 0 END))         AS OluUrun,
            CONVERT(bigint, SUM(CASE WHEN g.Sinif = 5
                 THEN t.MagazaStok + t.MerkezStok ELSE 0 END))                    AS OluAdet,
            CONVERT(decimal(18,2), SUM(CASE WHEN g.Sinif = 5 AND {MaliyetGecerli}
                 THEN (t.MagazaStok + t.MerkezStok) * t.BirimMaliyet ELSE 0 END)) AS OluTutar,
            CONVERT(int,    SUM(CASE WHEN g.Sinif = 0 THEN 1 ELSE 0 END))         AS YeterliUrun,
            CONVERT(int,    SUM(CASE WHEN g.Sinif IN (2,5) AND NOT {MaliyetGecerli}
                                     THEN 1 ELSE 0 END))                          AS MaliyetiYok
        """;

    /// <summary>Kategori kırılımı kolonları — ÖZET tablosunun satırı.</summary>
    private const string KategoriKolonlarSql = $"""
            ISNULL(t.Kategori3, N'(boş)')                                         AS Kategori,
            CONVERT(int, COUNT(*))                                                AS Cesit,
            CONVERT(int,    SUM(CASE WHEN g.Sinif = 1 THEN 1 ELSE 0 END))         AS SiparisUrun,
            CONVERT(bigint, SUM(CASE WHEN g.Sinif = 1 THEN x.Siparis ELSE 0 END)) AS SiparisAdet,
            CONVERT(decimal(18,2), SUM(CASE WHEN g.Sinif = 1
                 THEN x.Siparis * t.SatisFiyat ELSE 0 END))                       AS SiparisTutar,
            CONVERT(int,    SUM(CASE WHEN g.Sinif = 2 THEN 1 ELSE 0 END))         AS FazlaUrun,
            CONVERT(bigint, SUM(CASE WHEN g.Sinif = 2 THEN x.Fazla ELSE 0 END))   AS FazlaAdet,
            CONVERT(decimal(18,2), SUM(CASE WHEN g.Sinif = 2 AND {MaliyetGecerli}
                 THEN x.Fazla * t.BirimMaliyet ELSE 0 END))                       AS FazlaTutar
        """;

    /// <summary>KPI + kategori kırılımı — tek gidiş dönüş (iki sonuç kümesi).</summary>
    public async Task<SezonAksiyonOzet> GetOzetAsync(SezonAksiyonFiltre f, CancellationToken ct = default)
    {
        var sql = $"""
            SELECT {OzetKolonlarSql}
            {GovdeSql};

            SELECT {KategoriKolonlarSql}
            {GovdeSql}
            GROUP BY t.Kategori3
            ORDER BY 5 DESC;
            """;

        await using var conn = await db.OpenAsync();
        await using var g = await conn.QueryMultipleAsync(
            new CommandDefinition(sql, P(f), commandTimeout: 180, cancellationToken: ct));
        var kpi = await g.ReadFirstOrDefaultAsync<SezonAksiyonKpi>()
                  ?? new SezonAksiyonKpi(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
        var kat = (await g.ReadAsync<SezonAksiyonKategori>()).ToList();
        return new SezonAksiyonOzet(kpi, kat);
    }

    /// <summary>
    /// Kategori3 ve ürün grubu (Kat1) seçenekleri — süzgeç açılırları. Kohort
    /// filtresinden BAĞIMSIZ (aksi hâlde bir kategoriyi seçince ötekiler kaybolurdu).
    /// </summary>
    public async Task<(IReadOnlyList<string> Kategoriler, IReadOnlyList<string> Gruplar)>
        GetSecenekleriAsync(SezonAksiyonFiltre f, CancellationToken ct = default)
    {
        const string sql = $"""
            SELECT DISTINCT t.Kategori3
            FROM {Taban} t WITH (NOLOCK)
            WHERE t.Kesim = @kesim AND t.SezonYil = @sezon
              AND t.Kategori3 IS NOT NULL AND t.Kategori3 <> N''
            ORDER BY t.Kategori3;

            SELECT DISTINCT t.Kat1
            FROM {Taban} t WITH (NOLOCK)
            WHERE t.Kesim = @kesim AND t.SezonYil = @sezon
              AND t.Kat1 IS NOT NULL AND t.Kat1 <> N''
              AND (@kategori IS NULL OR t.Kategori3 = @kategori)
            ORDER BY t.Kat1;
            """;
        await using var conn = await db.OpenAsync();
        var p = new DynamicParameters();
        p.Add("kesim", f.Kesim.ToDateTime(TimeOnly.MinValue));
        p.Add("sezon", f.SezonYil);
        p.Add("kategori", string.IsNullOrWhiteSpace(f.Kategori3) ? null : f.Kategori3);
        await using var g = await conn.QueryMultipleAsync(
            new CommandDefinition(sql, p, commandTimeout: 60, cancellationToken: ct));
        var kat = (await g.ReadAsync<string>()).ToList();
        var grp = (await g.ReadAsync<string>()).ToList();
        return (kat, grp);
    }

    /// <summary>
    /// SELECT kolonları — ekran, sayfalama ve Excel AYNI listeyi kullanır.
    /// ⚠ SIRA = <see cref="SezonAksiyonSatir"/> parametre sırası (Dapper pozisyonel record).
    ///   Araya kolon eklenirse record'a da AYNI yere eklenir; sona yazmak değeri
    ///   SESSİZCE kaydırır. Kapı: <c>python tools/panel_kolon_denetimi.py</c>.
    /// </summary>
    private static string KolonlarSql => $"""
            t.stkID                                      AS StkId,
            u.stkKod                                     AS StkKod,
            t.BarkodAna                                  AS Barkod,
            t.stkAd                                      AS StkAd,
            t.Kategori3                                  AS Kategori3,
            t.Kat1                                       AS Kat1,
            t.Kat2                                       AS Kat2,
            {YolSql}                                     AS KategoriYolu,
            t.Yayinevi                                   AS Yayinevi,
            t.SezonToplam                                AS SezonToplam,
            ht.GecTop                                    AS GecenOkulOncesi,
            ISNULL(t.SansurluMu, CONVERT(bit, 0))        AS StoksuzKaldi,
            CONVERT(decimal(6,4), kk.Kat)                AS KatOran,
            ISNULL(t.Kat2, t.Kategori3)                  AS OranKirilim,
            CONVERT(decimal(6,3), CASE WHEN ISNULL(t.YillikAdet,0) > 0
                 THEN CONVERT(float, t.SezonToplam) / t.YillikAdet END) AS SezonPayi,
            ht.BuTop                                     AS BuOkulOncesi,
            ht.BugTop                                    AS BuBugune,
            CONVERT(decimal(6,4), po.OrF)                AS OranFsm,
            th.TahF                                      AS TahminFsm,
            kl.KalF                                      AS KalanFsm,
            t.StokFsm                                    AS StokFsm,
            CONVERT(int, CASE WHEN kl.KalF > t.StokFsm THEN kl.KalF - t.StokFsm ELSE 0 END) AS EksikFsm,
            CONVERT(decimal(6,4), po.OrO)                AS OranOzl,
            th.TahO                                      AS TahminOzl,
            kl.KalO                                      AS KalanOzl,
            t.StokOzl                                    AS StokOzl,
            CONVERT(int, CASE WHEN kl.KalO > t.StokOzl THEN kl.KalO - t.StokOzl ELSE 0 END) AS EksikOzl,
            CONVERT(decimal(6,4), po.OrI)                AS OranIst,
            th.TahI                                      AS TahminIst,
            kl.KalI                                      AS KalanIst,
            t.StokIst                                    AS StokIst,
            CONVERT(int, CASE WHEN kl.KalI > t.StokIst THEN kl.KalI - t.StokIst ELSE 0 END) AS EksikIst,
            CONVERT(int, th.TahF + th.TahO + th.TahI)    AS TahminToplam,
            CONVERT(int, s.Kalan)                        AS KalanToplam,
            CONVERT(int, s.Eksik)                        AS EksikToplam,
            t.MagazaStok                                 AS MagazaStok,
            t.MerkezStok                                 AS MerkezStok,
            CONVERT(int, t.MagazaStok + t.MerkezStok)    AS ToplamStok,
            g.Sinif                                      AS Sinif,
            CONVERT(int, x.Siparis)                      AS Siparis,
            CASE WHEN x.Siparis = 0 THEN NULL
                 WHEN t.OdakStok >= x.Siparis THEN N'Tedarikçide var'
                 ELSE N'Yeni alım gerekiyor' END         AS Nereden,
            t.OdakStok                                   AS OdakStok,
            CONVERT(int, s.DisT)                         AS SezonDisi,
            CONVERT(int, ISNULL(t.YillikAdet, 0))        AS Yillik,
            CONVERT(int, CASE WHEN x.Fazla > 0 THEN x.Fazla ELSE 0 END) AS Fazla,
            -- ⚠ 4 HANE: 2 haneye yuvarlayıp çarpınca toplam sapıyordu (ölçüldü).
            CONVERT(decimal(18,4), t.SatisFiyat)         AS SatisFiyat,
            CONVERT(decimal(18,4), CASE WHEN {MaliyetGecerli}
                 THEN t.BirimMaliyet END)                AS BirimMaliyet,
            CONVERT(decimal(18,2), CASE
                 WHEN x.Siparis > 0 THEN x.Siparis * t.SatisFiyat
                 WHEN g.Sinif IN (2,5) AND {MaliyetGecerli}
                 THEN CASE WHEN g.Sinif = 5 THEN t.MagazaStok + t.MerkezStok
                           ELSE x.Fazla END * t.BirimMaliyet END) AS Tutar
        """;

    public async Task<SayfaSonucu<SezonAksiyonSatir>> GetListeAsync(
        SezonAksiyonFiltre f, CancellationToken ct = default)
    {
        var yon = f.Azalan ? "DESC" : "ASC";
        // ⚠ COUNT(*) OVER () KULLANILMIYOR: Satış Analizi'nde sayfa başına 1,2 s ekliyordu.
        var sql = $"""
            SELECT CONVERT(int, COUNT(*)) {GovdeSql};

            SELECT {KolonlarSql}
            {GovdeSql}
            ORDER BY {SezonAksiyonSiralama.Sql(f.Sirala)} {yon}, ht.BugTop DESC, t.stkID
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
            {GovdeSql}
            ORDER BY {SezonAksiyonSiralama.Sql(f.Sirala)} {yon}, ht.BugTop DESC, t.stkID
            """;
        await using var conn = await db.OpenAsync();
        var r = (await conn.QueryAsync<SezonAksiyonSatir>(
            new CommandDefinition(sql, P(f), commandTimeout: 600, cancellationToken: ct))).ToList();
        logger.LogInformation(
            "Sezon sipariş Excel: {Satir} satır (kesim {Kesim}, sezon {Sezon}, pencere {Gun} gün)",
            r.Count, f.Kesim, f.SezonYil, f.PencereGun);
        return r;
    }
}
