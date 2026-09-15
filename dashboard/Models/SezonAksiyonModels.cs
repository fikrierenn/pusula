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
    string? StkKod,         // ⚠ urn.stkKod — BARKOD DEĞİL (sql-server-conventions);
    string? Barkod,         //    ikisi ayrı alan, ikisi de listede
    string StkAd,
    string? Kategori3,
    string? KategoriYolu,
    string? Yayinevi,
    decimal SatisFiyat,
    // ── AYNI PENCERE (GMY 15.09.2026: "aynı pencereye getirelim") ──────────────
    // Eski "365 günde satılan" KALDIRILDI: penceresi [kesim−364, kesim] idi ve
    // geçen sezonun 1 Ağu–13 Eyl kısmı 365 günden eski olduğu için DIŞINDA kalıyordu.
    // İki kolon iç içe geçmediği için 365g=33 / sezon=652 gibi satırlar okuyanı
    // yanıltıyordu (ölçüldü — sorgular/2026-09-15-ayni-pencere-ve-yanlis-alarm.sql).
    int GecenAyni,          // geçen yıl, okul açılışından geriye N gün
    int BuAyni,             // BU yıl, AYNI N gün — kıyaslanabilir
    int SezonToplam,        // geçen sezon TAMAMI (Ağu–Eki) — "Satılacak"ın tabanı
    // YILLIK: 01.08.<sezon> – 31.07.<sezon+1> (365 gün). HER ŞEY dahil.
    // Sezon dışı = Yillik − SezonToplam (Kas–Tem); EKSİ olabilir (iade fazlası) ve
    // sıfıra KIRPILMAZ — kırpmak iadeyi gizlemek olurdu (ölçüldü: 29 çeşit).
    int Yillik,
    // GEÇEN yılın KALAN sezon dilimi — AÇIK/FAZLA'nın tabanı.
    // ⚠ TÜM SEZON DEĞİL (GMY 15.09.2026: "açık sadece sezonu geçirmek için gerekli olan
    //   değil mi"). Sezonun geçen günleri ZATEN SATILDI; tüm sezon talebini istemek açığı
    //   2,4 KAT şişiriyordu — ölçüldü: 254,7M ₺ → 106,9M ₺.
    int GecenKalan,
    int Satilacak,          // = CEILING(GecenKalan × (1 + büyüme)) — "kalan sezon talebi"
    int StokFsm,
    int StokOzl,
    int StokIst,
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
    // SEZONU BİTTİ — geçen yıl KALAN dilimde hiç satmamış, stoğu duran ürünler.
    // ⚠ FAZLA'dan AYRI tutulur: eylemi farklı (indirimle dönmez; iade / gelecek sezon).
    //   Ölçüldü 15.09.2026: 17.197 ürün · 215.984 adet · 20.602.846 ₺ — FAZLA'nın içindeydi.
    int BittiUrun,
    long BittiAdet,
    decimal BittiTutar,
    int MaliyetiYok);

public sealed record SezonAksiyonOzet(SezonAksiyonKpi Kpi, IReadOnlyList<SezonAksiyonKategori> Kategoriler);

/// <summary>Ekran + Excel AYNI filtreyi kullanır (emitter-ayrımı) — URL'den çözülür.</summary>
public sealed record SezonAksiyonFiltre(
    DateOnly Kesim,
    int SezonYil,
    decimal Buyume = 0.20m,
    // PENCERE — kullanıcı BU yılınkini seçer; geçen yılınki ay/gün AYNASI olarak
    // TÜRETİLİR. Serbest iki pencere verilseydi 30 güne karşı 60 gün kıyaslanabilir
    // ve SAHTE büyüme üretirdi (hata vermeden). Aynalama bunu yapısal olarak engeller.
    DateOnly? PencereBas = null,   // null → 1 Ağustos
    DateOnly? PencereSon = null,   // null → kesim (sezon sonunu aşmaz)
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

    /// <summary>Sezon ayları — GMY kararı 15.09.2026: <i>"sezon 8 9 10 olsun"</i>.</summary>
    public const int SezonBasAy = 8;

    /// <summary>
    /// KALAN sezon dilimi: kesimin ERTESİ günü – 31.10. AÇIK/FAZLA bunun üzerinden ölçülür.
    /// Geçen yıl karşılığı ay/gün aynasıdır → gün sayısı eşit.
    /// </summary>
    public (DateOnly Bas, DateOnly Son) KalanPencere
    {
        get
        {
            var (_, bs) = BuPencere;
            return (bs.AddDays(1), new DateOnly(bs.Year, SezonSonAy, 31));
        }
    }

    public (DateOnly Bas, DateOnly Son) GecenKalanPencere
    {
        get
        {
            var (kb, ks) = KalanPencere;
            var fark = Kesim.Year - SezonYil;
            return (Aynala(kb, kb.Year - fark), Aynala(ks, ks.Year - fark));
        }
    }

    /// <summary>YILLIK pencere: 01.08.&lt;sezon&gt; – 31.07.&lt;sezon+1&gt; (365 gün).</summary>
    public (DateOnly Bas, DateOnly Son) YilPencere =>
        (new DateOnly(SezonYil, SezonBasAy, 1),
         new DateOnly(SezonYil + 1, SezonBasAy, 1).AddDays(-1));
    public const int SezonSonAy = 10;

    /// <summary>
    /// KARŞILAŞTIRMA PENCERESİ — iki yıl da <b>1 Ağustos'tan</b> başlar ve kesimin
    /// ay/gününde biter. GMY kararı 15.09.2026: <i>"okul açılışına takılma, rapor 01/08'den
    /// başlasın, sezon 8 9 10 olsun"</i>.
    ///
    /// ⚠ BEYAN: bu TAKVİM hizalamasıdır, okul hizalaması DEĞİL. Okul açılışı yıldan yıla
    /// kayıyor (08.09.2025 → 14.09.2026, altı gün) ve ölçüldüğünde bu fark bazı kategorilerde
    /// yönü çevirebiliyor (Hazırlık Kitapları büyümesi takvimle 0,727 · okula hizalı 1,104).
    /// Karar bilerek takvim yönünde verildi; sayı okunurken bu bilinmeli.
    /// Kanıt: sorgular/2026-09-15-ayni-pencere-ve-yanlis-alarm.sql
    ///
    /// Üst sınır sezon sonunu (31 Ekim) AŞMAZ — kesim kasımdaysa pencere sezonda biter.
    /// İki pencere aynı ay/güne kadar gittiği için uzunlukları EŞİTTİR.
    /// </summary>
    public (DateOnly Bas, DateOnly Son) BuPencere
    {
        get
        {
            var bas = PencereBas ?? new DateOnly(Kesim.Year, SezonBasAy, 1);
            var son = PencereSon ?? Kesim;
            var sezonSonu = new DateOnly(son.Year, SezonSonAy, DateTime.DaysInMonth(son.Year, SezonSonAy));
            if (son > sezonSonu) son = sezonSonu;      // pencere sezon sonunu aşmaz
            if (son < bas) son = bas;
            return (bas, son);
        }
    }

    /// <summary>GEÇEN yıl — bu yılın penceresinin ay/gün AYNASI. Uzunluk eşit kalır.</summary>
    public (DateOnly Bas, DateOnly Son) GecenPencere
    {
        get
        {
            var (bb, bs) = BuPencere;
            var fark = Kesim.Year - SezonYil;
            return (Aynala(bb, bb.Year - fark), Aynala(bs, bs.Year - fark));
        }
    }

    /// <summary>Ay/günü başka yıla taşı; 29 Şubat gibi olmayan güne düşerse bir gün geri al.</summary>
    private static DateOnly Aynala(DateOnly d, int yil) =>
        new(yil, d.Month, Math.Min(d.Day, DateTime.DaysInMonth(yil, d.Month)));

    /// <summary>İki pencere eşit uzunlukta mı — değilse kıyas SAHTEdir, ekranda söylenir.</summary>
    public bool PencereEsit =>
        BuPencere.Son.DayNumber - BuPencere.Bas.DayNumber
        == GecenPencere.Son.DayNumber - GecenPencere.Bas.DayNumber;

    /// <summary>Pencere gün sayısı (ekranda yazılır) — iki yıl için de aynı olmalı.</summary>
    public int PencereGun => BuPencere.Son.DayNumber - BuPencere.Bas.DayNumber + 1;

    /// <summary>Sorgu dizesine çevir — Excel bağlantısı ekrandakiyle AYNI kohortu indirir.</summary>
    public string SorguDizesi()
    {
        var p = new List<string>
        {
            $"kesim={Kesim:yyyy-MM-dd}",
            $"sezon={SezonYil}",
            $"buyume={Buyume.ToString(System.Globalization.CultureInfo.InvariantCulture)}",
        };
        if (PencereBas is { } pb) p.Add($"pbas={pb:yyyy-MM-dd}");
        if (PencereSon is { } ps) p.Add($"pson={ps:yyyy-MM-dd}");
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

        DateOnly? pbas = null, pson = null;
        foreach (var (ad, hedef) in new[] { ("pbas", 0), ("pson", 1) })
        {
            if (!q.TryGetValue(ad, out var dv) || string.IsNullOrWhiteSpace(dv)) continue;
            if (DateOnly.TryParse(dv, System.Globalization.CultureInfo.InvariantCulture, out var d))
            {
                if (hedef == 0) pbas = d; else pson = d;
            }
            else atla.Add($"{ad}='{dv}' okunamadı, varsayılan pencere kullanıldı");
        }

        string? durum = null;
        if (q.TryGetValue("durum", out var ds) && !string.IsNullOrWhiteSpace(ds))
        {
            if (ds is "acik" or "fazla" or "bitti") durum = ds;
            else atla.Add($"durum='{ds}' tanınmadı (acik|fazla|bitti), süzgeç uygulanmadı");
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
        // ⚠ ADLANDIRILMIŞ parametre ZORUNLU: kayda araya yeni alan eklenince konum
        //   bazlı çağrı SESSİZCE kayar (tipler uyuşursa derleyici de yakalamaz).
        return new SezonAksiyonFiltre(
            Kesim: kesim,
            SezonYil: sezon,
            Buyume: buyume,
            PencereBas: pbas,
            PencereSon: pson,
            Durum: durum,
            Kategori3: string.IsNullOrWhiteSpace(q.GetValueOrDefault("kategori")) ? null : q["kategori"],
            Arama: string.IsNullOrWhiteSpace(q.GetValueOrDefault("ara")) ? null : q["ara"],
            Sirala: sirala,
            Azalan: azalan);
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
            ["gecenayni"] = "ISNULL(gh.Adet, 0)",
            ["yillik"] = "ISNULL(yl.Adet, 0)",
            ["gecenkalan"] = "ISNULL(gk.Adet, 0)",
            ["sezondisi"] = "(ISNULL(yl.Adet, 0) - t.SezonToplam)",
            ["buayni"] = "ISNULL(bh.Adet, 0)",
            // Geçen yıl 0 ise oran YOK — sonsuz büyüme uydurulmaz, en sona düşer.
            ["degisim"] = "CASE WHEN ISNULL(gh.Adet,0) > 0 THEN CONVERT(float, ISNULL(bh.Adet,0)) / gh.Adet END",
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
