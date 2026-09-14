namespace GmDashboard.Models;

/// <summary>
/// SEZON AKSİYON LİSTESİ — sade kohort: "satılacak miktar" ile "elde" karşılaştırılır,
/// fark AÇIK ya da FAZLA olur. GMY 14.09.2026: <i>"365 günde satılan, sezonda satılan,
/// sezon büyümesi %20, satılacak miktar, mağaza+depo stok, açık, fazla — daha basit,
/// satınalma ile paylaşıp aksiyon alınacak liste"</i>.
///
/// ⚠ Satış Analizi panelinden AYRI: orada büyüme ürün/kategori bazlı ölçülüyor ve sezon
/// penceresi hizalanıyor. Burada büyüme TEK SAYI (varsayılan %20) ve kullanıcı değiştirir —
/// alıcıyla paylaşılacak liste, tartışılacak tek parametresi olsun diye.
/// Kardeş emitter: <c>scripts/sezon_aksiyon_listesi_excel.py</c> — İŞ MANTIĞI AYNI KALMALI.
/// </summary>
/// <remarks>
/// ⚠ Dapper POZİSYONEL record: sıra sözleşmedir. SQL SELECT'e araya kolon eklenip buranın
/// SONUNA yazılırsa değer SESSİZCE kayar (tipler uyuşuyorsa hata bile vermez).
/// SQL'de nereye eklendiyse burada AYNI yere eklenir.
/// </remarks>
public sealed record SezonAksiyonSatir(
    int StkId,
    string? Barkod,
    string StkAd,
    string? Kategori3,
    string? KategoriYolu,
    string? Yayinevi,
    decimal SatisFiyat,
    int SatisToplam,
    int SezonToplam,
    int Satilacak,
    int MagazaStok,
    int MerkezStok,
    int ToplamStok,
    int Acik,
    int Fazla,
    decimal? AcikTutar,
    decimal? FazlaTutar,
    decimal? BirimMaliyet);

/// <summary>Kategori kırılımı — ÖZET tablosunun satırı.</summary>
public sealed record SezonAksiyonKategori(
    string Kategori,
    int Cesit,
    int AcikUrun,
    long AcikAdet,
    decimal AcikTutar,
    int FazlaUrun,
    long FazlaAdet,
    decimal FazlaTutar);

/// <summary>
/// KPI — iki kohort ve tabanları. ⚠ AÇIK ₺ SATIŞ fiyatıyla, FAZLA ₺ MALİYETLE ölçülür;
/// ikisi AYNI TABAN DEĞİLDİR ve TOPLANMAZ. Kartlarda taban etiketi bu yüzden zorunlu.
/// </summary>
public sealed record SezonAksiyonKpi(
    int Cesit,
    int AcikUrun,
    long AcikAdet,
    decimal AcikTutar,
    int FazlaUrun,
    long FazlaAdet,
    decimal FazlaTutar,
    int MaliyetiYok);

public sealed record SezonAksiyonOzet(SezonAksiyonKpi Kpi, IReadOnlyList<SezonAksiyonKategori> Kategoriler);

/// <summary>Ekran + Excel AYNI filtreyi kullanır (emitter-ayrımı) — URL'den çözülür.</summary>
public sealed record SezonAksiyonFiltre(
    DateOnly Kesim,
    int SezonYil,
    decimal Buyume = 0.20m,
    string? Durum = null,          // "acik" | "fazla" | null (hepsi)
    string? Kategori3 = null,
    string? Arama = null,
    string Sirala = "tutar",
    bool Azalan = true,
    int Sayfa = 1,
    int SayfaBoyu = 100)
{
    public const decimal BuyumeAlt = -0.50m;
    public const decimal BuyumeUst = 3.00m;

    /// <summary>Sorgu dizesine çevir — Excel bağlantısı ekrandakiyle AYNI kohortu indirir.</summary>
    public string SorguDizesi()
    {
        var p = new List<string>
        {
            $"kesim={Kesim:yyyy-MM-dd}",
            $"sezon={SezonYil}",
            $"buyume={Buyume.ToString(System.Globalization.CultureInfo.InvariantCulture)}",
        };
        if (!string.IsNullOrWhiteSpace(Durum)) p.Add($"durum={Uri.EscapeDataString(Durum)}");
        if (!string.IsNullOrWhiteSpace(Kategori3)) p.Add($"kategori={Uri.EscapeDataString(Kategori3)}");
        if (!string.IsNullOrWhiteSpace(Arama)) p.Add($"ara={Uri.EscapeDataString(Arama)}");
        p.Add($"sirala={Sirala}");
        p.Add($"azalan={(Azalan ? 1 : 0)}");
        return string.Join('&', p);
    }

    /// <summary>
    /// URL sözlüğünden çöz. ⚠ Tanınmayan/geçersiz değer SESSİZCE yutulmaz —
    /// <paramref name="atlanan"/> listesine yazılır (error-handling § sessiz fallback yasak).
    /// </summary>
    public static SezonAksiyonFiltre Coz(
        IReadOnlyDictionary<string, string> q, DateOnly varsayilanKesim, int varsayilanSezon,
        out IReadOnlyList<string> atlanan)
    {
        var atla = new List<string>();

        var kesim = varsayilanKesim;
        if (q.TryGetValue("kesim", out var ks) && !string.IsNullOrWhiteSpace(ks))
        {
            if (DateOnly.TryParse(ks, System.Globalization.CultureInfo.InvariantCulture, out var d)) kesim = d;
            else atla.Add($"kesim='{ks}' okunamadı, {varsayilanKesim:dd.MM.yyyy} kullanıldı");
        }

        var sezon = varsayilanSezon;
        if (q.TryGetValue("sezon", out var sz) && !string.IsNullOrWhiteSpace(sz))
        {
            if (int.TryParse(sz, out var y) && y is >= 2000 and <= 2100) sezon = y;
            else atla.Add($"sezon='{sz}' geçersiz, {varsayilanSezon} kullanıldı");
        }

        var buyume = 0.20m;
        if (q.TryGetValue("buyume", out var bs) && !string.IsNullOrWhiteSpace(bs))
        {
            if (decimal.TryParse(bs, System.Globalization.NumberStyles.Float,
                                 System.Globalization.CultureInfo.InvariantCulture, out var b)
                && b >= BuyumeAlt && b <= BuyumeUst) buyume = b;
            else atla.Add($"buyume='{bs}' geçersiz (−50% … +300% arası), %20 kullanıldı");
        }

        string? durum = null;
        if (q.TryGetValue("durum", out var ds) && !string.IsNullOrWhiteSpace(ds))
        {
            if (ds is "acik" or "fazla") durum = ds;
            else atla.Add($"durum='{ds}' tanınmadı (acik|fazla), süzgeç uygulanmadı");
        }

        var azalan = true;
        if (q.TryGetValue("azalan", out var az) && az is "0" or "false") azalan = false;

        var sirala = q.GetValueOrDefault("sirala") ?? "tutar";
        if (!SezonAksiyonSiralama.Gecerli(sirala))
        {
            atla.Add($"sirala='{sirala}' tanınmadı, 'tutar' kullanıldı");
            sirala = "tutar";
        }

        atlanan = atla;
        return new SezonAksiyonFiltre(
            kesim, sezon, buyume, durum,
            string.IsNullOrWhiteSpace(q.GetValueOrDefault("kategori")) ? null : q["kategori"],
            string.IsNullOrWhiteSpace(q.GetValueOrDefault("ara")) ? null : q["ara"],
            sirala, azalan);
    }
}

/// <summary>
/// Sıralanabilir kolonlar — anahtar → SQL ifadesi. ⚠ Kullanıcı girdisi SQL'e ancak
/// bu İZİN LİSTESİNDEN geçerek girer (yasak listesi değil: tanınmayan REDDEDİLİR).
/// </summary>
public static class SezonAksiyonSiralama
{
    public static readonly IReadOnlyDictionary<string, string> Harita =
        new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
        {
            ["tutar"] = "CASE WHEN s.Satilacak > s.Elde THEN (s.Satilacak - s.Elde) * t.SatisFiyat "
                      + "ELSE (s.Elde - s.Satilacak) * ISNULL(t.BirimMaliyet, 0) END",
            ["acik"] = "CASE WHEN s.Satilacak > s.Elde THEN s.Satilacak - s.Elde ELSE 0 END",
            ["fazla"] = "CASE WHEN s.Elde > s.Satilacak THEN s.Elde - s.Satilacak ELSE 0 END",
            ["urun"] = "t.stkAd",
            ["kategori"] = "t.Kategori3",
            ["satis365"] = "t.SatisToplam",
            ["sezon"] = "t.SezonToplam",
            ["satilacak"] = "s.Satilacak",
            ["magaza"] = "t.MagazaStok",
            ["depo"] = "t.MerkezStok",
            ["stok"] = "s.Elde",
            ["fiyat"] = "t.SatisFiyat",
        };

    public static bool Gecerli(string? anahtar) => anahtar is not null && Harita.ContainsKey(anahtar);

    public static string Sql(string anahtar) => Harita.TryGetValue(anahtar, out var v) ? v : Harita["tutar"];
}
