namespace GmDashboard.Models;

/// <summary>
/// Satış Analizi paneli modelleri (plan-42). Kaynak/tanım kanıtı:
/// sorgular/2026-09-08-satis-analizi-excel-denetim.sql §10-12 · script kardeşi:
/// scripts/satis_analizi_excel.py (emitter-ayrimi: aynı çekirdek, iki emitter).
/// </summary>

/// <summary>Panel filtresi. Kesim = son KAPALI gün; satış penceresi 365 gün (kesim dahil).</summary>
public sealed record SatisAnaliziFiltre(
    DateOnly Kesim,
    int SezonYil,
    string? Arama = null,
    string? Kategori3 = null,
    string? Kategori1 = null,
    int Mekan = 0,               // 0=hepsi · 1 FSM · 4477 Özlüce · 4478 İst.Yolu
    SatisDurumFiltre Durum = SatisDurumFiltre.Hepsi,
    /// <summary>
    /// TAZE STOK HARİÇ: son N gün içinde mal kabulü olan ürünler değerlendirmeden ÇIKARILIR
    /// (0 = kapalı). Gerekçe (satinalma-danisman adil-atıf): yeni gelen mal "aşırı stok" ya da
    /// "hareketsiz" sayılamaz — satacak zamanı olmamıştır. Ölçüt <c>SonGiris</c> (son mal kabulü),
    /// <c>IlkGiris</c> DEĞİL.
    /// </summary>
    int TazeGunHaric = 0,
    /// <summary>ODAK (tedarikçi) stoğu var mı? null=hepsi · true=var (hızlı temin) · false=yok (gerçek risk).</summary>
    bool? OdakVar = null,
    /// <summary>
    /// STOK YAŞI: ürün kartı açılışından bu yana en az N yıl geçmiş olanlar (0 = kapalı).
    /// Kullanıcı: "stoğun açılış tarihini de değerlendirmek gerek". Ölçüm 09.09 (rapor evreni):
    /// &lt;1 yıl 46.963 · 1-2 yıl 55.294 · 2-3 yıl 53.405 · 3+ yıl 630.513 çeşit.
    /// Yaşlı + satışsız + stoklu = tasfiye adayı; yaşlı olmak TEK BAŞINA suç değil.
    /// </summary>
    int MinYasYil = 0,
    string Sirala = "tutar",
    bool Azalan = true,
    int Sayfa = 1,
    int SayfaBoyu = 50)
{
    /// <summary>365 gün DAHİL → bas = kesim − 364. (Ölçüldü: orijinal rapor 07.09.2025–06.09.2026.)</summary>
    public DateOnly Baslangic => Kesim.AddDays(-364);
    public DateOnly SezonBas => new(SezonYil, 8, 1);
    public DateOnly SezonSon => new(SezonYil, 10, 31);
}

public enum SatisDurumFiltre
{
    Hepsi,
    /// <summary>Sezonda sattı, bugün stok yok.</summary>
    StoksuzSezon,
    /// <summary>Sezonda sattı, stok &gt; 5× sezon satışı.</summary>
    AsiriStok,
    /// <summary>365 günde hiç satmadı, stok var.</summary>
    Hareketsiz,
    /// <summary>Negatif stok / fiyat 0 — veri kiri.</summary>
    VeriKirli,
    /// <summary>YALNIZ taze stok (son N günde mal kabulü olanlar) — filtrenin tersi.</summary>
    SadeceTaze,
}

/// <summary>KPI şeridi. Karşı-metrikler YAN YANA durur (satinalma-danisman: tek yönlü metrik yasak).</summary
public sealed record SatisAnaliziKpi(
    long ToplamStok,
    decimal ToplamStokTutar,      // ⚠ SATIŞ fiyatıyla — bağlanan para DEĞİL
    int Cesit,
    long PerakendeSatis365,       // 3 mağaza (tüketici talebi)
    long MerkezCikis365,          // grup-içi/toptan + e-tic sevk — TALEP DEĞİL
    int StoksuzSezonCesit,
    decimal StoksuzSezonKayip,
    int StoksuzSezonOdakVarCesit, // ODAK'ta var → hızlı temin, gerçek kayıp değil
    decimal StoksuzSezonOdakVarKayip,
    int AsiriStokCesit,
    decimal AsiriStokTutar,
    int AsiriStokOdakVarCesit,    // ODAK'ta da var → grup içinde çift stok
    decimal AsiriStokOdakVarTutar,
    int HareketsizCesit,
    decimal HareketsizTutar,
    int VeriKirliCesit,
    decimal VeriKirliTutar)
{
    /// <summary>Gün-stok — YALNIZ perakende talebine göre. Karma rakam üretilmez (danışma kararı).</summary
    public decimal? PerakendeGunStok => PerakendeSatis365 <= 0 ? null
        : Math.Round((decimal)ToplamStok / ((decimal)PerakendeSatis365 / 365m), 0);
}

/// <summary>Kategori/kırılım satırı.</summary>
public sealed record SatisAnaliziKirilim(
    string Ad,
    int Cesit,
    long Stok,
    decimal Tutar,
    long Satis365,
    long Sezon,
    int StoksuzCesit,
    decimal AsiriTutar)
{
    public decimal? GunStok => Satis365 <= 0 ? null : Math.Round((decimal)Stok / ((decimal)Satis365 / 365m), 0);
    public decimal? SezonKapsama => Sezon <= 0 ? null : Math.Round((decimal)Stok / Sezon, 1);
}

/// <summary>
/// Ürün satırı — 26 kolonun tamamı + panelin eklediği karar kolonları (leadTime, ODAK durumu).
/// Dapper: 8+ kolon olduğu için ValueTuple DEĞİL record (24.06 dersi — 8. eleman sessizce 0 kalır).
/// smallint/tinyint kolonlar SQL'de CAST(... AS int) ile gelir (23.06 dersi).
/// </summary>
public sealed record SatisAnaliziSatir(
    int StkId,
    string Kategori3,
    string? BarkodAna,
    string StkAd,
    string Kategori1,
    string Yayinevi,
    string Yazar,
    decimal SatisFiyat,
    decimal ToplamStokTutar,
    int ToplamStok,
    int OdakStok,
    DateTime? IlkGirisTarihi,
    DateTime? SonGirisTarihi,
    DateOnly? AcilisTarihi,
    int StokFsm,
    int StokOzluce,
    int StokIstyolu,
    int MagazaStok,
    int MerkezStok,
    int SatisFsm,
    int SatisOzluce,
    int SatisIstyolu,
    int SatisToplam,
    int SezonAy1,
    int SezonAy2,
    int SezonAy3,
    int SezonToplam,
    int? LeadTime,
    int? OdakSatisDurum)
{
    public decimal GunlukOrtalamaSatis => SatisToplam / 365m;

    /// <summary>Stok yaşı (yıl) — ürün kartı açılışından bugüne. Açılış yoksa null.</summary>
    public decimal? YasYil => AcilisTarihi is null ? null
        : Math.Round((decimal)(DateTime.Today - AcilisTarihi.Value.ToDateTime(TimeOnly.MinValue)).TotalDays / 365m, 1);
    public decimal? SezonKapsama => SezonToplam <= 0 ? null : Math.Round((decimal)ToplamStok / SezonToplam, 1);
}

/// <summary>
/// Kolon kaydı — kullanıcı hangi kolonları göreceğini buradan seçer (kullanıcı isteği 08.09.2026).
///
/// ANAHTAR = string; indeks ya da bit maskesi DEĞİL. Gerekçe (Solum danışması): indeks/maske
/// bir kolon eklendiği gün SESSİZCE kayar; anahtar kayarsa kolon görünmez olur (görünür hata).
/// Anahtar aynı zamanda sıralama anahtarıdır (<see cref="Siralanabilir"/> ise).
/// </summary>
public sealed record KolonTanim(
    string Anahtar,
    string Baslik,
    bool Sayisal = false,
    bool Varsayilan = true,
    bool Siralanabilir = false,
    string? Ipucu = null);

public static class SatisAnaliziKolonlar
{
    /// <summary>Kolon sırası ORİJİNAL Excel ile aynı; sonda panelin eklediği karar kolonları.</summary>
    public static readonly IReadOnlyList<KolonTanim> Hepsi =
    [
        new("kategori3",  "Kategori3",  Varsayilan: true,  Siralanabilir: true),
        new("stkid",      "stkID",      Sayisal: true, Varsayilan: true, Siralanabilir: true),
        new("barkod",     "BarkodAna",  Varsayilan: false),
        new("ad",         "Ürün",       Varsayilan: true),
        new("kategori1",  "Kategori1",  Varsayilan: false, Siralanabilir: true),
        new("yayinevi",   "Yayınevi",   Varsayilan: true,  Siralanabilir: true,
            Ipucu: "UrunBilgi.mrkAd — iade/konsinye koşulu yayınevi bazlı olduğu için kırılımda önemli"),
        new("yazar",      "Yazar",      Varsayilan: false),
        new("fiyat",      "Satış Fiyat", Sayisal: true, Varsayilan: true, Siralanabilir: true),
        new("tutar",      "Stok Tutarı", Sayisal: true, Varsayilan: true, Siralanabilir: true,
            Ipucu: "SATIŞ fiyatıyla — bağlanan para (maliyet) DEĞİL"),
        new("stok",       "Toplam Stok", Sayisal: true, Varsayilan: true, Siralanabilir: true,
            Ipucu: "Mağaza + Merkez. ODAK DAHİL DEĞİL (ODAK tedarikçi stoğu)"),
        new("odak",       "ODAK Stok",  Sayisal: true, Varsayilan: true, Siralanabilir: true,
            Ipucu: "Tedarikçi (grup şirketi) elindeki stok — bizim envanterimiz değil, temin sinyali"),
        new("leadtime",   "Temin (gün)", Sayisal: true, Varsayilan: true, Siralanabilir: true,
            Ipucu: "BKMDATA.OdakUrunDurum.leadTime — ODAK'tan gelme süresi (ort. 5,03 gün)"),
        new("ilkgiris",   "İlk Giriş",  Varsayilan: false,
            Ipucu: "Ürünün MAĞAZAYA ilk girişi (merkez depoya giriş sayılmaz)"),
        new("songiris",   "Son Giriş",  Varsayilan: false, Siralanabilir: true,
            Ipucu: "Son mal kabulü — TAZE STOK ölçütü. Yeni gelen mal aşırı/hareketsiz sayılmaz"),
        new("acilis",     "Açılış",     Varsayilan: false, Siralanabilir: true,
            Ipucu: "Ürün kartının açıldığı tarih (UrunBilgi.gTarih) — stok YAŞI bununla ölçülür"),
        new("yas",        "Yaş (yıl)",  Sayisal: true, Varsayilan: false,
            Ipucu: "Kesim − açılış. 3 yıldan eski + satış yok = tasfiye adayı"),
        new("stok_fsm",   "Stok FSM",   Sayisal: true, Varsayilan: false, Siralanabilir: true),
        new("stok_ozl",   "Stok Özlüce", Sayisal: true, Varsayilan: false, Siralanabilir: true),
        new("stok_ist",   "Stok İst.Yolu", Sayisal: true, Varsayilan: false, Siralanabilir: true),
        new("magaza_stok", "Mağaza Stok", Sayisal: true, Varsayilan: false, Siralanabilir: true),
        new("merkez_stok", "Merkez Stok", Sayisal: true, Varsayilan: true, Siralanabilir: true,
            Ipucu: "WMS raf+giriş — ANLIK (geçmiş tarih seçilse bile bugünün değeri)"),
        new("satis_fsm",  "Satış FSM",  Sayisal: true, Varsayilan: false, Siralanabilir: true),
        new("satis_ozl",  "Satış Özlüce", Sayisal: true, Varsayilan: false, Siralanabilir: true),
        new("satis_ist",  "Satış İst.Yolu", Sayisal: true, Varsayilan: false, Siralanabilir: true),
        new("satis",      "Satış 365g", Sayisal: true, Varsayilan: true, Siralanabilir: true,
            Ipucu: "3 mağaza · iade netlenmiş. Merkez depo çıkışı DAHİL DEĞİL"),
        new("gunluk",     "Günlük Ort.", Sayisal: true, Varsayilan: false),
        new("sezon_ay1",  "Ağustos",    Sayisal: true, Varsayilan: false, Siralanabilir: true),
        new("sezon_ay2",  "Eylül",      Sayisal: true, Varsayilan: false, Siralanabilir: true),
        new("sezon_ay3",  "Ekim",       Sayisal: true, Varsayilan: false, Siralanabilir: true),
        new("sezon",      "Sezon Toplam", Sayisal: true, Varsayilan: true, Siralanabilir: true,
            Ipucu: "Ağu+Eyl+Eki. 365g satışla KISMEN ÖRTÜŞÜR — toplanmaz/çıkarılmaz"),
        new("kapsama",    "Sezon Kapsama", Sayisal: true, Varsayilan: true,
            Ipucu: "Stok / sezon satışı. TEK BAŞINA YANILTIR — yanına 365g satışa bak"),
    ];

    public static readonly IReadOnlySet<string> VarsayilanAnahtarlar =
        Hepsi.Where(k => k.Varsayilan).Select(k => k.Anahtar).ToHashSet(StringComparer.OrdinalIgnoreCase);

    public static KolonTanim? Bul(string anahtar) =>
        Hepsi.FirstOrDefault(k => string.Equals(k.Anahtar, anahtar, StringComparison.OrdinalIgnoreCase));
}
