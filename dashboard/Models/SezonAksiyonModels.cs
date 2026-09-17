namespace GmDashboard.Models;

/// <summary>
/// SEZON SİPARİŞ LİSTESİ — <b>sezon payı</b> yöntemi.
///
/// GMY 15.09.2026 verbatim: <i>"toplam sezon da satılacak miktarı da yazalım bir yere,
/// şu ana kadar satılanı çıkartıp ihtiyacı bulalım, depoda o kadar varsa sorun yok
/// yoksa sipariş lazım"</i> · <i>"sezonda satılan 3235, 44 günde % kaçı satılmış,
/// o yüzde bizim için; 17416 adet, kalanı bul"</i>.
///
/// <code>
///   ORAN          = geçen sezon OKUL ÖNCESİ satılan ÷ geçen SEZON TOPLAMI
///   TAHMİN        = bu sezon OKUL ÖNCESİ satılan ÷ ORAN
///   KALAN İHTİYAÇ = TAHMİN − bu sezon BUGÜNE KADAR satılan
///   SİPARİŞ       = şubelerin toplam eksiği − merkez depo stoğu
/// </code>
///
/// ⚠ <b>BÜYÜME PARAMETRESİ YOK.</b> Hacmi ürünün bu sezonki kendi satışı taşır; oran
/// yalnız "sezonun neresindeyiz" sorusunu yanıtlar. Alıcının çevirebileceği kadran
/// kalmadı (satinalma-danisman 15.09.2026: tek kadran hem AÇIK'ı büyütüp hem FAZLA'yı
/// siliyordu).
///
/// ⚠ <b>ZİNCİR ŞUBE DÜZEYİNDE</b> kurulur; ürün satırı üç şubenin TOPLAMIDIR. Ürün
/// düzeyinde ayrı hesap YAPILMAZ — ölçüldü 15.09.2026 (Kırtasiye, 20.218 çeşit):
/// iki ayrı hesap varken şube eksikleri toplamı ile sipariş adedi 4.922 çeşitte
/// (%24,3) uyuşmuyordu, fark 133.594 adet.
///
/// Üç emitter tek çekirdek: bu panel · <c>scripts/sezon_aksiyon_listesi_excel.py</c> ·
/// <c>sorgular/2026-09-15-sezon-aksiyon-listesi.sql</c> — biri değişirse üçü değişir
/// (emitter-ayrimi.md).
/// </summary>
/// <remarks>
/// ⚠ Dapper POZİSYONEL record: SIRA sözleşmedir, isim değil. SQL SELECT'e araya kolon
/// eklenip buranın SONUNA yazılırsa değer SESSİZCE kayar (tipler uyuşursa derleyici de
/// yakalamaz). Kapı: <c>python tools/panel_kolon_denetimi.py</c>.
/// </remarks>
public sealed record SezonAksiyonSatir(
    int StkId,
    string? StkKod,          // ⚠ urn.stkKod — BARKOD DEĞİL (sql-server-conventions)
    string? Barkod,
    string StkAd,
    string? Kategori3,
    string? Kat1,            // ürün grubu
    string? Kat2,            // alt kategori — yedek oranın alındığı kırılım
    string? KategoriYolu,
    string? Yayinevi,
    // ── GEÇEN SEZONUN ÖLÇÜMÜ ─────────────────────────────────────────────────
    // 01.08–31.10.<sezon> · üç şubenin toplamı
    int SezonToplam,
    int GecenOkulOncesi,     // oranın PAYI — okul açılışına hizalı pencere
    /// <summary>Geçen sezonun Eylül/Ekim ay sonlarında şube stoğu 0 mıydı — öyleyse
    /// gözlenen satış talebin ALTINDADIR (sağdan sansür) ve oran 1'e yaklaşır.
    /// Ölçüldü (Kırtasiye): stoksuz kalanların oran medyanı 0,821 · stoğu olanların
    /// 0,588. Bayrak GÖRÜNÜR; düzeltme UYGULANMADI (backtest kötüleşti %18,5 → %48,5).</summary>
    bool StoksuzKaldi,
    /// <summary>Şubenin kendi ölçümü zayıfsa kullanılan yedek oran (önce Kat2, yoksa
    /// Kategori3, o da yoksa 0,60). ⚠ 4 haneye YUVARLANMIŞ hâliyle çarpılır —
    /// gösterilen oran = çarpılan oran (ölçüldü: yuvarlanmazsa Excel ile 3 adet ayrışıyordu).</summary>
    decimal KatOran,
    string? OranKirilim,
    /// <summary>Ürünün sezon payı (sezon ÷ yıllık). Düşükse ürün sezonluk DEĞİLDİR ve
    /// yöntem o satırda zayıftır — ölçüldü (Kırtasiye): medyan 0,500, %38,7'si 0,40 altı.</summary>
    decimal? SezonPayi,
    // ── BU SEZONUN ÖLÇÜMÜ ────────────────────────────────────────────────────
    int BuOkulOncesi,
    int BuBugune,            // sezon başından kesime — tahminden ÇIKARILAN
    // ── ŞUBE ZİNCİRİ (ürün satırı bunların toplamı) ──────────────────────────
    decimal OranFsm, int TahminFsm, int KalanFsm, int StokFsm, int EksikFsm,
    decimal OranOzl, int TahminOzl, int KalanOzl, int StokOzl, int EksikOzl,
    decimal OranIst, int TahminIst, int KalanIst, int StokIst, int EksikIst,
    // ── TOPLAMLAR ────────────────────────────────────────────────────────────
    int TahminToplam,
    int KalanToplam,
    int EksikToplam,
    int MagazaStok,
    int MerkezStok,
    int ToplamStok,
    // ── SONUÇ ────────────────────────────────────────────────────────────────
    /// <summary>1 SİPARİŞ VER · 4 DEPODAN GÖNDER · 2 FAZLA VAR · 5 ÖLÜ STOK · 0 YETERLİ</summary>
    int Sinif,
    int Siparis,
    string? Nereden,
    int OdakStok,            // tedarikçide bulunan — BİZİM stoğumuz DEĞİL
    // ── BAĞLAM ───────────────────────────────────────────────────────────────
    int SezonDisi,           // geçen yıl Kas–Tem — sipariş TETİKLEMEZ
    int Yillik,
    int Fazla,               // gelecek sezona kalacak
    // ── PARA ─────────────────────────────────────────────────────────────────
    decimal SatisFiyat,
    decimal? BirimMaliyet,
    /// <summary>Siparişte satış fiyatıyla (kaçacak CİRO), fazla/ölüde maliyetle
    /// (bağlı sermaye). ⚠ İKİSİ TOPLANMAZ.</summary>
    decimal? Tutar)
{
    public string DurumAd => SezonAksiyonSinif.Ad(Sinif);
}

/// <summary>Beş sınıf — tek yerde adlandırılır (ekran · Excel · SQL aynı sözcük).</summary>
public static class SezonAksiyonSinif
{
    public const int Yeterli = 0, Siparis = 1, Fazla = 2, Depodan = 4, Olu = 5;

    public static string Ad(int s) => s switch
    {
        Siparis => "SİPARİŞ VER",
        Depodan => "DEPODAN GÖNDER",
        Fazla => "FAZLA VAR",
        Olu => "ÖLÜ STOK",
        _ => "YETERLİ",
    };

    /// <summary>URL süzgeç anahtarı → sınıf. Tanınmayan anahtar REDDEDİLİR.</summary>
    public static int? Anahtardan(string? k) => k switch
    {
        "siparis" => Siparis,
        "depodan" => Depodan,
        "fazla" => Fazla,
        "olu" => Olu,
        _ => null,
    };
}

/// <summary>Kategori kırılımı — ÖZET tablosunun satırı.</summary>
public sealed record SezonAksiyonKategori(
    string Kategori,
    int Cesit,
    int SiparisUrun,
    long SiparisAdet,
    decimal SiparisTutar,
    int FazlaUrun,
    long FazlaAdet,
    decimal FazlaTutar);

/// <summary>
/// KPI — beş kohort. ⚠ SİPARİŞ ₺ SATIŞ fiyatıyla, FAZLA/ÖLÜ ₺ MALİYETLE ölçülür;
/// AYNI TABAN DEĞİLDİR ve TOPLANMAZ. Kartlarda taban etiketi bu yüzden zorunlu.
/// Siparişteki tutar kaybedilen CİRODUR, kaybedilen KÂR DEĞİL (marj ölçülmedi).
/// </summary>
public sealed record SezonAksiyonKpi(
    int Cesit,
    int SiparisUrun, long SiparisAdet, decimal SiparisTutar,
    int DepodanUrun, long DepodanAdet,
    int FazlaUrun, long FazlaAdet, decimal FazlaTutar,
    int OluUrun, long OluAdet, decimal OluTutar,
    int YeterliUrun,
    /// <summary>Maliyeti yok/şüpheli (TMS 2: 0 &lt; maliyet ≤ satış fiyatı) çeşit —
    /// adet sayılır, paraya girmez ⇒ fazla ve ölü tutarı ALT SINIRDIR.</summary>
    int MaliyetiYok);

public sealed record SezonAksiyonOzet(SezonAksiyonKpi Kpi, IReadOnlyList<SezonAksiyonKategori> Kategoriler);

/// <summary>Ekran + Excel AYNI filtreyi kullanır (emitter-ayrımı) — URL'den çözülür.</summary>
public sealed record SezonAksiyonFiltre(
    DateOnly Kesim,
    int SezonYil,
    string? Durum = null,          // siparis | depodan | fazla | olu | null
    string? Kategori3 = null,
    string? Grup = null,           // Kat1 — ürün grubu
    string? Arama = null,
    string Sirala = "tutar",
    bool Azalan = true,
    int Sayfa = 1,
    int SayfaBoyu = 100)
{
    /// <summary>Sezon ayları — GMY kararı 15.09.2026: <i>"sezon 8 9 10 olsun"</i>.</summary>
    public const int SezonBasAy = 8;
    public const int SezonSonAy = 10;

    /// <summary>
    /// OKUL AÇILIŞ TARİHLERİ — pencere buna hizalanır, TAKVİME DEĞİL.
    /// ÖLÇÜLDÜ 15.09.2026: takvim hizasıyla Kırtasiye sezon tahmini 521.262, açılış
    /// hizasıyla 643.912 — %23,5 fark. Sebep: 01.08–13.09.2025 penceresi açılıştan
    /// (08.09.2025) SONRAKİ altı günü içeriyor, 2026'nınki içermiyor → oran şişip
    /// talebi eksik ölçüyordu.
    /// ⚠ Yeni yıl eklenmezse rapor KOŞMAZ (aşağıda <see cref="AcilisTanimli"/>) —
    /// sessizce takvime düşmek yanlış rakam üretirdi.
    /// </summary>
    public static readonly IReadOnlyDictionary<int, DateOnly> OkulAcilis =
        new Dictionary<int, DateOnly>
        {
            [2023] = new(2023, 9, 11),
            [2024] = new(2024, 9, 9),
            [2025] = new(2025, 9, 8),
            [2026] = new(2026, 9, 14),
        };

    /// <summary>Pencere kurulamıyorsa sorgu ÇALIŞTIRILMAZ; ekran sebebini yazar.</summary>
    public bool AcilisTanimli =>
        OkulAcilis.ContainsKey(SezonYil) && OkulAcilis.ContainsKey(Kesim.Year);

    /// <summary>Okul öncesi pencerenin son günü — açılıştan BİR GÜN ÖNCE.</summary>
    private DateOnly GecenPenSon => OkulAcilis[SezonYil].AddDays(-1);

    private DateOnly BuPenSon
    {
        get
        {
            var acilisOncesi = OkulAcilis[Kesim.Year].AddDays(-1);
            return Kesim < acilisOncesi ? Kesim : acilisOncesi;
        }
    }

    /// <summary>
    /// Pencere uzunluğu — İKİ YIL İÇİN DE AYNI. Her yıl 1 Ağustos'tan açılışın bir gün
    /// öncesine kadar sayılır; KÜÇÜK olana eşitlenir. Serbest iki pencere verilseydi
    /// 30 güne karşı 60 gün kıyaslanıp SAHTE oran üretirdi (hata vermeden).
    /// </summary>
    public int PencereGun
    {
        get
        {
            var g = GecenPenSon.DayNumber - new DateOnly(SezonYil, SezonBasAy, 1).DayNumber;
            var b = BuPenSon.DayNumber - new DateOnly(Kesim.Year, SezonBasAy, 1).DayNumber;
            return 1 + Math.Min(g, b);
        }
    }

    /// <summary>Pencere 14 günün altındaysa oran güvenilmez — koşulmaz.</summary>
    public bool PencereYeterli => AcilisTanimli && PencereGun >= 14;

    public (DateOnly Bas, DateOnly Son) GecenPencere =>
        (GecenPenSon.AddDays(-(PencereGun - 1)), GecenPenSon);

    public (DateOnly Bas, DateOnly Son) BuPencere =>
        (BuPenSon.AddDays(-(PencereGun - 1)), BuPenSon);

    /// <summary>Geçen sezonun TAMAMI — oranın PAYDASI.</summary>
    public (DateOnly Bas, DateOnly Son) GecenSezon =>
        (new DateOnly(SezonYil, SezonBasAy, 1), new DateOnly(SezonYil, SezonSonAy, 31));

    /// <summary>
    /// Bu sezon başından kesime — "şu ana kadar satılan". ⚠ Hizalı pencere DEĞİL:
    /// tahmin TÜM sezonu söyler, ondan sezon başından beri satılan HER ŞEY düşülür.
    /// </summary>
    public (DateOnly Bas, DateOnly Son) BuSezon =>
        (new DateOnly(Kesim.Year, SezonBasAy, 1), Kesim);

    /// <summary>Geçen yılın SEZON DIŞI dilimi (Kas–Tem) — sipariş TETİKLEMEZ.
    /// GMY 15.09.2026: <i>"kritik olan bizim için sezonda yoka düşmemek; sezon sonrası
    /// sipariş verilebilir, sorun değil."</i></summary>
    public (DateOnly Bas, DateOnly Son) SezonDisi =>
        (new DateOnly(SezonYil, 11, 1), new DateOnly(SezonYil + 1, 7, 31));

    /// <summary>YILLIK 365 gün: 01.08.&lt;sezon&gt; – 31.07.&lt;sezon+1&gt; — bağlam, karar vermez.</summary>
    public (DateOnly Bas, DateOnly Son) YilPencere =>
        (new DateOnly(SezonYil, SezonBasAy, 1),
         new DateOnly(SezonYil + 1, SezonBasAy, 1).AddDays(-1));

    /// <summary>Sansür bayrağının bakacağı ay sonları (snapshot yalnız ay sonu tutar).</summary>
    public (DateOnly Eyl, DateOnly Eki) SansurDonem =>
        (new DateOnly(SezonYil, 9, DateTime.DaysInMonth(SezonYil, 9)),
         new DateOnly(SezonYil, 10, DateTime.DaysInMonth(SezonYil, 10)));

    /// <summary>Sorgu dizesine çevir — Excel bağlantısı ekrandakiyle AYNI kohortu indirir.</summary>
    public string SorguDizesi()
    {
        var p = new List<string>
        {
            $"kesim={Kesim:yyyy-MM-dd}",
            $"sezon={SezonYil}",
        };
        if (!string.IsNullOrWhiteSpace(Durum)) p.Add($"durum={Uri.EscapeDataString(Durum)}");
        if (!string.IsNullOrWhiteSpace(Kategori3)) p.Add($"kategori={Uri.EscapeDataString(Kategori3)}");
        if (!string.IsNullOrWhiteSpace(Grup)) p.Add($"grup={Uri.EscapeDataString(Grup)}");
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

        string? durum = null;
        if (q.TryGetValue("durum", out var ds) && !string.IsNullOrWhiteSpace(ds))
        {
            if (SezonAksiyonSinif.Anahtardan(ds) is not null) durum = ds;
            else atla.Add($"durum='{ds}' tanınmadı (siparis|depodan|fazla|olu), süzgeç uygulanmadı");
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
            Durum: durum,
            Kategori3: string.IsNullOrWhiteSpace(q.GetValueOrDefault("kategori")) ? null : q["kategori"],
            Grup: string.IsNullOrWhiteSpace(q.GetValueOrDefault("grup")) ? null : q["grup"],
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
            // PARA: sipariş satırında kaçacak ciro, ötekinde bağlı sermaye.
            ["tutar"] = "CASE WHEN x.Siparis > 0 THEN x.Siparis * t.SatisFiyat "
                      + "WHEN g.Sinif = 2 THEN x.Fazla * ISNULL(t.BirimMaliyet, 0) "
                      + "WHEN g.Sinif = 5 THEN (t.MagazaStok + t.MerkezStok) * ISNULL(t.BirimMaliyet, 0) "
                      + "ELSE 0 END",
            ["siparis"] = "x.Siparis",
            ["eksik"] = "s.Eksik",
            ["fazla"] = "x.Fazla",
            ["urun"] = "t.stkAd",
            ["kategori"] = "t.Kategori3",
            ["grup"] = "t.Kat1",
            ["sezon"] = "t.SezonToplam",
            ["gecenoncesi"] = "ht.GecTop",
            ["buoncesi"] = "ht.BuTop",
            ["bubugune"] = "ht.BugTop",
            ["tahmin"] = "th.TahF + th.TahO + th.TahI",
            ["kalan"] = "s.Kalan",
            ["magaza"] = "t.MagazaStok",
            ["depo"] = "t.MerkezStok",
            ["stok"] = "t.MagazaStok + t.MerkezStok",
            ["odak"] = "t.OdakStok",
            ["sezondisi"] = "s.DisT",
            ["yillik"] = "ISNULL(t.YillikAdet, 0)",
            // Yıllık 0 ise sezon payı YOK — uydurulmaz, en sona düşer.
            ["sezonpayi"] = "CASE WHEN ISNULL(t.YillikAdet,0) > 0 "
                          + "THEN CONVERT(float, t.SezonToplam) / t.YillikAdet END",
            ["fiyat"] = "t.SatisFiyat",
            ["durum"] = "g.Sinif",
        };

    public static bool Gecerli(string? anahtar) => anahtar is not null && Harita.ContainsKey(anahtar);

    public static string Sql(string anahtar) => Harita.TryGetValue(anahtar, out var v) ? v : Harita["tutar"];
}
