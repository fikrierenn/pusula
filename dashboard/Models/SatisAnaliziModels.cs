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
    /// <summary>
    /// YENİ ÜRÜN EŞİĞİ (gün) — bundan yeni ürün "hareketsiz" sayılmaz (satacak zamanı olmadı).
    /// Kullanıcı kararı 09.09.2026: 90 gün çok uzun → 45. Ekrandaki "taze gün" kutusu doluysa
    /// o değer kullanılır; bu yalnız varsayılan. TEK YER — KPI ve liste süzgeci ikisi de bunu alır.
    /// </summary>
    public const int YeniUrunGunVarsayilan = 45;

    /// <summary>
    /// Filtreyi URL sorgu dizesine çevirir — drill'e gidip GERİ DÖNÜNCE aynı görünüm.
    ///
    /// ⚠ TEK YER: <see cref="SorguDizesi"/> yazar, <see cref="Coz"/> okur. İkisi ayrışırsa
    /// kullanıcı "geri geldim ayarlarım gitti" der (bu kod tam o hatayı kapatmak için yazıldı:
    /// eski sürüm yalnız kesim+sezon taşıyordu, panel de onları hiç okumuyordu).
    ///
    /// Varsayılan değerler YAZILMAZ — URL kısa kalsın ve "boş = varsayılan" tek anlam taşısın.
    /// </summary>
    public string SorguDizesi()
    {
        var q = new List<string>
        {
            $"kesim={Kesim:yyyy-MM-dd}",
            $"sezon={SezonYil}",
        };
        if (!string.IsNullOrWhiteSpace(Arama)) q.Add($"arama={Uri.EscapeDataString(Arama)}");
        if (!string.IsNullOrWhiteSpace(Kategori3)) q.Add($"kat3={Uri.EscapeDataString(Kategori3)}");
        if (!string.IsNullOrWhiteSpace(Kategori1)) q.Add($"kat1={Uri.EscapeDataString(Kategori1)}");
        if (Mekan != 0) q.Add($"mekan={Mekan}");
        if (Durum != SatisDurumFiltre.Hepsi) q.Add($"durum={(int)Durum}");
        if (TazeGunHaric > 0) q.Add($"taze={TazeGunHaric}");
        if (OdakVar is not null) q.Add($"odak={(OdakVar.Value ? 1 : 0)}");
        if (MinYasYil > 0) q.Add($"yas={MinYasYil}");
        if (Sirala != "tutar") q.Add($"sirala={Uri.EscapeDataString(Sirala)}");
        if (!Azalan) q.Add("azalan=0");
        if (Sayfa > 1) q.Add($"sayfa={Sayfa}");
        if (SayfaBoyu != 50) q.Add($"boyut={SayfaBoyu}");
        return string.Join("&", q);
    }

    /// <summary>
    /// Sorgu dizesinden filtre kurar. Tanınmayan/bozuk değer SESSİZCE YUTULMAZ:
    /// o alan varsayılanda kalır ve <paramref name="atlanan"/> listesine yazılır — çağıran
    /// isterse kullanıcıya söyler (sessiz fallback yasağı, error-handling kuralı).
    /// </summary>
    public static SatisAnaliziFiltre Coz(
        IReadOnlyDictionary<string, string> q, DateOnly kesimVarsayilan, int sezonVarsayilan,
        out List<string> atlanan)
    {
        var atl = new List<string>();

        var kesim = kesimVarsayilan;
        if (q.TryGetValue("kesim", out var kv))
        {
            if (DateOnly.TryParse(kv, System.Globalization.CultureInfo.InvariantCulture, out var k2)) kesim = k2;
            else atl.Add($"kesim={kv}");
        }

        var sezon = sezonVarsayilan;
        if (q.TryGetValue("sezon", out var sv))
        {
            if (int.TryParse(sv, out var s2) && s2 is >= 2000 and <= 2100) sezon = s2;
            else atl.Add($"sezon={sv}");
        }

        int Sayi(string ad, int varsayilan)
        {
            if (!q.TryGetValue(ad, out var v)) return varsayilan;
            if (int.TryParse(v, out var n)) return n;
            atl.Add($"{ad}={v}");
            return varsayilan;
        }

        var durum = SatisDurumFiltre.Hepsi;
        if (q.TryGetValue("durum", out var dv))
        {
            if (int.TryParse(dv, out var d2) && Enum.IsDefined(typeof(SatisDurumFiltre), d2))
                durum = (SatisDurumFiltre)d2;
            else atl.Add($"durum={dv}");
        }

        bool? odak = null;
        if (q.TryGetValue("odak", out var ov))
        {
            if (ov == "1") odak = true;
            else if (ov == "0") odak = false;
            else atl.Add($"odak={ov}");
        }

        atlanan = atl;
        return new SatisAnaliziFiltre(
            Kesim: kesim,
            SezonYil: sezon,
            Arama: q.GetValueOrDefault("arama"),
            Kategori3: q.GetValueOrDefault("kat3"),
            Kategori1: q.GetValueOrDefault("kat1"),
            Mekan: Sayi("mekan", 0),
            Durum: durum,
            TazeGunHaric: Sayi("taze", 0),
            OdakVar: odak,
            MinYasYil: Sayi("yas", 0),
            Sirala: q.GetValueOrDefault("sirala") ?? "tutar",
            Azalan: q.GetValueOrDefault("azalan") != "0",
            Sayfa: Math.Max(1, Sayi("sayfa", 1)),
            SayfaBoyu: Sayi("boyut", 50));
    }

    /// <summary>365 gün DAHİL → bas = kesim − 364. (Ölçüldü: orijinal rapor 07.09.2025–06.09.2026.)</summary>
    public DateOnly Baslangic => Kesim.AddDays(-364);
    public DateOnly SezonBas => new(SezonYil, 8, 1);
    public DateOnly SezonSon => new(SezonYil, 10, 31);
}

/// <summary>
/// Durum süzgeci görünen adları — ekrandaki açılır liste BUNDAN üretilir.
///
/// ⚠ Açılır liste eskiden Razor'da ELLE yazılıydı: enum 8 üyeye çıkmıştı ama listede 5
/// seçenek vardı → yeni eklenen <c>Rafsiz</c>/<c>RafBos</c>/<c>SadeceTaze</c> SEÇİLEMİYORDU
/// (ölçüldü 09.09, tarayıcıdan: 5 option). "Liste elle yazılmaz" kuralı — yeni enum üyesi
/// buraya bir satır ekleyince ekranda kendiliğinden çıkar.
/// Haritada karşılığı olmayan üye <c>Enum.GetValues</c> ile yine listelenir (adı ham gelir),
/// yani sessizce KAYBOLMAZ.
/// </summary>
public static class DurumAdlari
{
    public static readonly IReadOnlyDictionary<SatisDurumFiltre, string> Hepsi = new Dictionary<SatisDurumFiltre, string>
    {
        [SatisDurumFiltre.Hepsi] = "(hepsi)",
        [SatisDurumFiltre.StoksuzSezon] = "Stokta yokluk — sezon ürünü",
        [SatisDurumFiltre.AsiriStok] = "Aşırı stok (2× sezon ve 5× ikmal kapağı)",
        [SatisDurumFiltre.Hareketsiz] = "Ölü stok (satış yok)",
        [SatisDurumFiltre.VeriKirli] = "Veri kirli",
        [SatisDurumFiltre.MaliyetSupheli] = "Maliyet kaydı şüpheli (maliyet > fiyat)",
        [SatisDurumFiltre.SadeceTaze] = "Yalnız taze stok",
        [SatisDurumFiltre.Rafsiz] = "Rafa hiç çıkmamış envanter",
        [SatisDurumFiltre.RafBos] = "Raf bulunurluk kaybı (merkezde var)",
        [SatisDurumFiltre.Yeni] = "Yeni ürün (değerlendirilemez)",
        [SatisDurumFiltre.Dengesiz] = "Mağaza arası dengesizlik → transfer",
        [SatisDurumFiltre.SezonAcik] = "Sezon stok açığı",
        [SatisDurumFiltre.SezonRafAcigi] = "Sezonluk raf açığı → transfer",
        [SatisDurumFiltre.AraliklıTalep] = "Aralıklı talep (gün-stok geçersiz)",
        [SatisDurumFiltre.HicSatilmamis] = "Ölü stok — HİÇ satılmamış",
        [SatisDurumFiltre.SatmisDurmus] = "Ölü stok — satmış, sonra durmuş",
        [SatisDurumFiltre.SiparisIhtiyaci] = "Sipariş ihtiyacı (kapak altı)",
        [SatisDurumFiltre.SiparisAcil] = "Sipariş — ACİL (hiç stok yok)",
        [SatisDurumFiltre.DuzgunTalep] = "Düzgün talep (gün-stok geçerli)",
    };

    public static string Ad(SatisDurumFiltre d) => Hepsi.TryGetValue(d, out var a) ? a : d.ToString();
}

public enum SatisDurumFiltre
{
    Hepsi,
    /// <summary>Sezonda sattı, bugün stok yok.</summary>
    StoksuzSezon,
    /// <summary>Sezonda sattı, stok kategori eşiğini aşıyor — panel geneli 3×, Kırtasiye 2×,
    /// Hazırlık Kitapları 8× (hepsi ölçümle türetildi 10.09.2026).</summary>
    AsiriStok,
    /// <summary>365 günde hiç satmadı, stok var.</summary>
    Hareketsiz,
    /// <summary>Negatif stok / fiyat 0 — veri kiri.</summary>
    VeriKirli,

    /// <summary>
    /// Maliyet kaydı şüpheli — <c>BirimMaliyet &gt; SatisFiyat</c>. Değerlemeye girmez,
    /// ayrı listelenir (muhasebe kalemi / yanlış maliyet güncellemesi adayı).
    /// </summary>
    MaliyetSupheli,
    /// <summary>YALNIZ taze stok (son N günde mal kabulü olanlar) — filtrenin tersi.</summary>
    SadeceTaze,

    /// <summary>Rafa hiç çıkmamış — merkezde var, mağazaya hiç girmemiş (satması imkânsız).</summary>
    Rafsiz,

    /// <summary>Rafta yok, merkezde var — daha önce çıkmış; transfer sorusu.</summary>
    RafBos,

    /// <summary>YENİ ürün — değerlendirilecek kadar zamanı olmamış (hareketsiz/aşırı dışı).</summary>
    Yeni,

    /// <summary>Mağazalar arası dengesizlik — bir rafta yok, ötekinde talebe göre fazla.</summary>
    Dengesiz,

    /// <summary>Sezon hazırlığı açığı — geçen sezon sattı, stoğu o satışın yarısından az.</summary>
    SezonAcik,

    /// <summary>
    /// Geçen sezon O MAĞAZADA sattı · bugün O RAFTA stok yok · merkez depoda mal var.
    /// <c>SezonAcik</c>'tan FARKLI: orada TOPLAM stok yetmiyor (sipariş gerekebilir),
    /// burada mal şirketin elinde ama yanlış yerde — eylem TRANSFER.
    /// </summary>
    SezonRafAcigi,

    /// <summary>
    /// Talep-arası aralık ADI &gt; 1,32 (aralıklı/sıçramalı) — gün-stok ve günlük ortalama
    /// satış bu ürünlerde GEÇERSİZ. Syntetos/Boylan/Croston 2005 eşiği.
    /// </summary>
    AraliklıTalep,

    /// <summary>
    /// SİPARİŞ İHTİYACI (plan-46) — eldeki stok kapağın (temin + 30 gün) altında ve
    /// önerilen miktar &gt; 0. ⚠ Kohort "stok = 0" DEĞİL: o ölçüt gerçek ihtiyacın
    /// ~1/13'ünü görüyordu (Kırtasiye 796 vs 1.687 çeşit / 14.528 adet, ölçüldü 11.09.2026).
    /// </summary>
    SiparisIhtiyaci,

    /// <summary>Sipariş gerekiyor VE hiç stok yok — kayıp bugün yaşanıyor, ilk yazılacak liste.</summary>
    SiparisAcil,

    /// <summary>ADI ≤ 1,32 (düzgün/değişken) — panelin hız metrikleri yalnız burada geçerli.</summary>
    DuzgunTalep,

    /// <summary>
    /// ÖLÜ STOĞUN İKİ ALT KÜMESİ (12.09.2026). Kart ikisini tek sayıda topluyordu ve
    /// hangisinin hangisi olduğu okunmuyordu. Ölçüldü — aynı kohortun iki yarısı ÇOK farklı:
    /// hiç satmamış 43.715 çeşit / maliyet 46,8M ₺ (etiket/maliyet 1,1×) · satmış-durmuş
    /// 72.217 çeşit / 24,2M ₺ (3,8×). Çeşidin %38'i maliyetin %66'sını taşıyor.
    /// İki AYRI problem: biri alım hatası, öteki talep kaybı.
    /// </summary>
    HicSatilmamis,
    SatmisDurmus
}

/// <summary>KPI şeridi. Karşı-metrikler YAN YANA durur (satinalma-danisman: tek yönlü metrik yasak).</summary>
public sealed record SatisAnaliziKpi(
    long ToplamStok,
    decimal ToplamStokTutar,      // ⚠ SATIŞ fiyatıyla — bağlanan para DEĞİL
    int Cesit,
    long MagazaStok,              // raf stoğu — gün-stok payı BUDUR (kapsam asimetrisi 09.09)
    long MerkezStok,              // toptan/grup deposu — ayrı ölçülür
    long PerakendeSatis365,       // 3 mağaza (tüketici talebi)
    long MerkezCikis365,          // panel evreni içi — ürün bazlı MerkezCikis toplamıyla TUTAR
    long MerkezCikisEvrenDisi,    // Kategori3 filtresi yüzünden görünmeyen kısım (ölçüm: 670.659)          // grup-içi/toptan + e-tic sevk — TALEP DEĞİL
    int StoksuzSezonCesit,
    decimal StoksuzSezonKayip,
    /// <summary>Kaçan adedin MALİYETİ — kayıp ile arasındaki fark KAÇAN BRÜT KÂR.</summary>
    decimal StoksuzSezonMaliyet,
    /// <summary>
    /// AĞIRLAŞTIRICI (B-172a): talebi KANITLI dilim — geçen sezon ≥ 20 adet satmış.
    /// Ölçüldü: 356 çeşit (%4,4) kaybın %46'sını taşıyor. Kayıp tahmini zaten ALT SINIR
    /// (sağdan sansür) olduğu için bu dilim "kesin kaçan satış"a en yakın olanıdır.
    /// </summary>
    int StoksuzKanitliCesit,
    decimal StoksuzKanitliKayip,
    int StoksuzSezonOdakVarCesit, // ODAK'ta var → hızlı temin, gerçek kayıp değil
    decimal StoksuzSezonOdakVarKayip,
    int AsiriStokCesit,
    decimal AsiriStokTutar,
    /// <summary>Aşırı stoğun TOPLAM stok maliyeti (B-172(b)). Etiket 325,3M ₺ iken 111,6M ₺.</summary>
    decimal AsiriStokMaliyet,
    /// <summary>
    /// Eşik ÜSTÜ fazla kısmın maliyeti — ADİL CEZA ÖLÇÜSÜ (B-172(b), 12.09.2026).
    /// Eşiğe kadarki stok meşrudur; alıcıya yazılacak olan yalnız fazlasıdır: 73,2M ₺.
    /// ⚠ Maliyeti bilinmeyen çeşit 0 sayılır → rakam ALT SINIR (kapsam %95,3 çeşit / %97,5 etiket).
    /// </summary>
    decimal AsiriStokFazlaMaliyet,
    /// <summary>
    /// HAFİFLETİCİ (B-172a): aşırı stoğun tedarikçiye İADE KANALI gözlenmiş dilimi
    /// (son 24 ayda bu üründen fiilen alış iadesi yapılmış). Ölçüldü 12.09.2026 (eşik iki
    /// ayaklı, kohort 37.103): 12.671 çeşit / 10,8M ₺ — fazla maliyetin %14,5'i.
    /// ⚠ VEKİL: ürün bazında iade HAKKI veride yok; ölçülen şey kanalın çalıştığıdır.
    /// </summary>
    int AsiriIadeCesit,
    decimal AsiriIadeFazlaMaliyet,
    int AsiriStokOdakVarCesit,    // ODAK'ta da var (kartta GÖSTERİLMİYOR — bkz. AsiriYeniGiris*)
    /// <summary>
    /// AĞIRLAŞTIRICI (12.09.2026): fazla stoğa SON 6 AYDA mal girmiş dilim.
    /// ODAK ağırlaştırıcısının yerine geldi — o ÇİFT SAYIMDI (kapak ayağı LeadTime'ı zaten
    /// içeriyor) ve kontrol-edilebilirliği yoktu (ODAK tedarikçinin envanteri).
    /// ÖLÇÜLDÜ: 21.022 çeşit / 59,3M ₺ = fazla maliyetin %79'u.
    /// ⚠ SonGiris = SON mal kabulü → "son 6 ayda mal GİRMİŞ", "son 6 ayda ALINDI" değil.
    /// </summary>
    int AsiriYeniGirisCesit,
    decimal AsiriYeniGirisMaliyet,
    decimal AsiriStokOdakVarTutar,
    int HareketsizCesit,
    decimal HareketsizTutar,
    /// <summary>Ölü stoğun MALİYETİ (B-172(b) devamı) — etiket 144,7M ₺ iken 71,0M ₺.</summary>
    decimal HareketsizMaliyet,
    /// <summary>
    /// Hiç satılmamışların maliyeti. ⚠ Çeşidin %38'i, etiketin %36'sı ama MALİYETİN %66'sı
    /// (46,8M / 71,0M) — etiket fiyatı bu kohortu küçük gösteriyordu.
    /// </summary>
    decimal HicSatilmamisMaliyet,
    /// <summary>
    /// RAFA HİÇ ÇIKMAMIŞ — merkeze girmiş, mağazaya hiç girmemiş, merkezde stoğu var.
    /// Kullanıcı isteği 09.09: "gelmiş ama mağazaya gitmemiş te bir kpi olmalı".
    /// Satması İMKÂNSIZ: raf yoksa satış olmaz. ÖLÇÜLDÜ: 1.182 çeşit / 24,17M ₺.
    /// </summary>
    int RafsizCesit,
    decimal RafsizTutar,
    /// <summary>
    /// RAFTA YOK ama MERKEZDE VAR — daha önce rafa çıkmış, şimdi raf boş, depoda mal duruyor.
    /// Satışı olanlar kanıtlı talep + boş raf = kayıp satış. TRANSFER sorusu, alım değil.
    /// ÖLÇÜLDÜ: 3.539 çeşit / 10,46M ₺, 1.218'inin satışı var.
    /// </summary>
    /// <summary>Raf bulunurluk kaybının stok MALİYETİ (12.09.2026 taban birleştirmesi).</summary>
    decimal RafBosMaliyet,
    /// <summary>Rafa çıkmamış envanterin MALİYETİ.</summary>
    decimal RafsizMaliyet,
    /// <summary>Mağaza arası dengesiz stoğun MALİYETİ.</summary>
    decimal DengesizMaliyet,
    int RafBosCesit,
    decimal RafBosTutar,
    long RafBosSatisliCesit,
    int VeriKirliCesit,
    decimal VeriKirliTutar,
    /// <summary>
    /// MALİYET KAYDI ŞÜPHELİ (12.09.2026): <c>BirimMaliyet &gt; SatisFiyat</c>. TMS 2 gereği
    /// stok, maliyet ile net gerçekleşebilir değerin DÜŞÜĞÜ ile değerlenir; bu kayıtlar
    /// değerlemeye GİRMEZ ama gizlenmez — dışlanan para bu alanda görünür.
    /// ÖLÇÜLDÜ: 258 çeşit / 31,4M ₺ yazılı maliyet (evren maliyetinin %7,7'si). İki kalem
    /// ürün bile değil: "Muhtelif Ürün" 23,2M ₺ · "İskonto ve Fiyat Farkı" 6,6M ₺.
    /// </summary>
    int MaliyetSupheliCesit,
    decimal MaliyetSupheliMaliyet,
    decimal MaliyetSupheliTutar,
    /// <summary>YENİ ÜRÜN — hareketsiz/aşırı ölçütlerinin KASITLI dışladığı kova.
    /// Dışlama sessiz kalmasın diye ayrı gösterilir (adil-atıf).</summary>
    int YeniCesit,
    decimal YeniTutar,
    /// <summary>Bir mağazada stok yok, başka mağazada 20+ adet var ve sezonda satıyor →
    /// TRANSFER sorusu, alım sorusu DEĞİL. Mal şirkette, yeri yanlış.</summary>
    int DengesizCesit,
    decimal DengesizTutar,
    /// <summary>SEZON HAZIRLIĞI — geçen sezon sattı, stoğu o satışın yarısından az.
    /// Tutar = EKSİK adet × fiyat (kayıp potansiyeli), stok değeri değil.</summary>
    int SezonAcikCesit,
    decimal SezonAcikTutar,
    /// <summary>Sezon açığının maliyet karşılığı (kaçan adet × birim maliyet).</summary>
    decimal SezonAcikMaliyet,
    int SezonAcikOdakCesit,
    decimal SezonAcikOdakTutar,
    /// <summary>Stoğun MALİYETLE değeri — "bağlanan para" sorusunun gerçek cevabı.
    /// Etiket değeri bunun ~2,5 katı görünüyor (ölçüldü 10.09.2026: 1.018,5M ₺ vs 409,1M ₺).
    /// Maliyeti bilinmeyen ürün toplama GİRMEZ; kapsam <see cref="MaliyetKapsamEtiket"/>.</summary>
    decimal MaliyetliDeger,
    /// <summary>Maliyeti BİLİNEN ürünlerin etiket değeri — kapsam beyanı için.
    /// Ölçüldü 10.09: etiket değerinin %94,73'ü (33.723 çeşit / 53,7M ₺ kapsam dışı).</summary>
    decimal MaliyetKapsamEtiket,
    /// <summary>365 gün POS net satışı, KDV HARİÇ — yalnız maliyeti DE bilinen ürünler.</summary>
    decimal PosNetKdvHaric,
    /// <summary>Satılan malın maliyeti (POS adedi × birim maliyet).</summary>
    decimal SatilanMaliyet,
    decimal PosBrutToplam,
    decimal PosNetToplam,
    /// <summary>Marj hesabına giren çeşit — maliyeti VE POS satışı olanlar.</summary>
    int MarjCesit,
    /// <summary>
    /// HAREKETSİZ ama HİÇ SATILMAMIŞ — <c>SonSatis IS NULL</c>. Hareketsiz kartının içindeki
    /// ayrım (kullanıcı isteği 10.09.2026): "hiç satılmamış" ALIM hatasıdır, "satıyordu
    /// durdu" TALEP kaybıdır. Tek sayıda toplanınca bu ayrım kayboluyordu.
    /// </summary>
    int HicSatilmamisCesit,
    decimal HicSatilmamisTutar,
    /// <summary>Rafa çıkmamış stoğun adedi (merkezde bekleyen).</summary>
    long RafsizAdet,
    /// <summary>Sezonluk raf açığı — geçen sezon o mağazada sattı, bugün o rafta yok, merkezde var.</summary>
    int SezonRafCesit,
    /// <summary>Sezonluk raf açığının kayıp tutarı — yalnız açığı olan mağazanın sezon adedi.</summary>
    decimal SezonRafTutar,
    /// <summary>Sezonluk raf açığının maliyet karşılığı.</summary>
    decimal SezonRafMaliyet,
    /// <summary>Sezonluk raf açığı olan ürünlerin merkezde bekleyen adedi (transferin hammaddesi).</summary>
    long SezonRafMerkezAdet,
    /// <summary>Düzgün/değişken talepli çeşit (ADI ≤ 1,32) — gün-stok YALNIZ burada güvenilir.</summary>
    int DuzgunTalepCesit,
    decimal DuzgunTalepTutar,
    /// <summary>Aralıklı/sıçramalı talepli çeşit (ADI &gt; 1,32) — gün-stok yanıltıcı.</summary>
    int ArelikliTalepCesit,
    decimal ArelikliTalepTutar,
    /// <summary>SİPARİŞ İHTİYACI (plan-46) — kapağın altına düşmüş, önerisi &gt; 0 olan çeşit.</summary>
    int SiparisCesit,
    /// <summary>Önerilen toplam sipariş adedi (MOQ/koli katı YOK — tedarikçiyle yuvarlanır).</summary>
    long SiparisAdet,
    /// <summary>Önerinin maliyeti — bağlanacak para. Birim maliyeti olmayan çeşitte 0 sayılır.</summary>
    decimal SiparisMaliyet,
    /// <summary>Önerinin satış fiyatıyla karşılığı — bağlanacak paranın döneceği ciro.</summary>
    decimal SiparisEtiket,
    /// <summary>ACİL: sipariş gerekiyor VE hiç stok yok — kayıp ZATEN yaşanıyor.</summary>
    int SiparisAcilCesit,
    long SiparisAcilAdet,
    // Ürün bazında ETKİN GÜNE bölünüp toplanmış günlük hız (adet/gün). SQL'de hesaplanır;
    // burada yeniden bölme YAPILMAZ (kullanıcı uyarısı 09.09 — aşağıdaki nota bak).
    double PerakendeGunlukHiz = 0)
{
    /// <summary>
    /// Gün-stok — YALNIZ perakende talebine göre. Karma rakam üretilmez (danışma kararı).
    ///
    /// ⚠ DÜZELTME 09.09.2026 (kullanıcı uyarısı: "stok gireli 365 gün olmadıysa satış
    /// ortalaması için 365'e bölmek mantıksız"). Eski hâli <c>Satis365 / 365</c> idi ve
    /// rafa yeni girmiş ürünün hızını olduğundan DÜŞÜK gösteriyordu → gün-stok şişiyordu.
    /// ÖLÇÜLDÜ (kesim 08.09.2026, 275.059 ürün): 38.180 ürün (%13,9) pencereden yeni;
    /// bunların 22.385'i hem satışlı hem stoklu. O 22.385'te ortalama gün-stok
    /// <b>1.644 → 524</b> (ortalama 1.120 gün şişme); <b>4.468</b> ürün haksız yere
    /// "&gt;400 gün" kırmızısında, <b>9.851</b> ürün en az 2 kat şişmiş.
    /// Doğrusu: her ürünün hızı KENDİ raf süresine bölünür, sonra toplanır.
    /// </summary>
    public decimal? PerakendeGunStok => PerakendeGunlukHiz <= 0 ? null
        : Math.Round((decimal)MagazaStok / (decimal)PerakendeGunlukHiz, 0);

    /// <summary>
    /// GERÇEKLEŞEN KÂR (365 gün) = POS net satış (KDV hariç) − satılan malın maliyeti.
    /// Kart fiyatıyla hesaplanan marj İYİMSER: ölçüldü 09.09 (90 gün), gerçekleşen net kart
    /// fiyatının %71-88'i. Bu ölçü POS'ta fiilen alınan paraya dayanır.
    /// </summary>
    public decimal GerceklesenKar => PosNetKdvHaric - SatilanMaliyet;

    /// <summary>Gerçekleşen brüt marj = kâr ÷ satış. Null = hesaplanacak satış yok.</summary>
    public decimal? GerceklesenMarj =>
        PosNetKdvHaric <= 0 ? null : GerceklesenKar / PosNetKdvHaric;

    /// <summary>Ortalama indirim oranı (brüt→net, POS'un kendi indirim kolonundan).</summary>
    public decimal? IndirimOrani =>
        PosBrutToplam <= 0 ? null : (PosBrutToplam - PosNetToplam) / PosBrutToplam;

    /// <summary>Maliyet kapsamı — etiket değerinin ne kadarında maliyet biliniyor.</summary>
    public decimal? MaliyetKapsamOrani =>
        ToplamStokTutar <= 0 ? null : MaliyetKapsamEtiket / ToplamStokTutar;

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
    decimal AsiriTutar,
    // Ürün bazında etkin güne bölünüp toplanmış günlük hız — bkz. SatisAnaliziKpi.PerakendeGunStok
    double GunlukHiz = 0)
{
    /// <summary>Gün-stok. Etkin güne göre (365'e sabit bölme YOK — 09.09 düzeltmesi).</summary>
    public decimal? GunStok => GunlukHiz <= 0 ? null
        : Math.Round((decimal)Stok / (decimal)GunlukHiz, 0);
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
    /// <summary>SON SATIŞ TARİHİ — pencere YOK. NULL = hiç satılmamış.
    /// ⚠ SIRA SÖZLEŞMESİ: Dapper konumsal record — SELECT'te de SatisToplam'dan
    /// hemen sonra gelmeli (yanlış yer → materialization patlar).</summary>
    DateTime? SonSatisTarihi,
    /// <summary>Son 12 tam ayda satış olan ay sayısı (ADI = 12 / SatanAy). NULL = hiç satmadı.</summary>
    int? SatanAy,
    /// <summary>Sıfır-olmayan aylık talep büyüklüklerinin kareli değişim katsayısı (CV²).</summary>
    decimal? TalepCV2,
    /// <summary>
    /// Birim maliyetin kaynağı olan SON alış faturasının tarihi (B11). Marj bu yaşı taşır:
    /// satış 365 günlük, maliyet bu tarihten. Enflasyonda eski maliyet marjı şişirir.
    /// NULL = alış faturası yok → maliyet ve marj hesaplanmaz.
    /// </summary>
    DateTime? MaliyetTarih,
    /// <summary>
    /// Maliyetin yaşı (gün) — <b>SQL'de KESİM TARİHİNE göre</b> hesaplanır, bugüne göre değil
    /// (satır kaydı kesimi taşımıyor; geçmiş kesim seçilirse yaş kaymasın).
    /// B11: marj bu yaşı taşıyor — ölçüldü 10.09.2026, maliyet yaşına göre gerçekleşen marj
    /// %24,4 (&lt;3 ay) → %63,0 (2+ yıl). Enflasyon ile yavaş devir AYRIŞTIRILAMIYOR; bu
    /// yüzden maliyet yeniden DEĞERLENMEDİ, yaşı görünür kılındı.
    /// </summary>
    int? MaliyetYasGun,
    int SezonAy1,
    int SezonAy2,
    int SezonAy3,
    int SezonToplam,
    int? LeadTime,
    int? OdakSatisDurum,
    /// <summary>
    /// Merkez depodan 365 günde çıkan adet — TOPTAN/GRUP dağıtımı, tüketici talebi DEĞİL
    /// (%72 grup şirketi · %16 ODAK e-tic · %6 Sınav; ölçüldü 09.09.2026).
    /// Mağaza satışıyla TOPLANMAZ: iki ayrı talep kanalı, iki ayrı hız.
    /// </summary>
    int MerkezCikis,
    /// <summary>
    /// Merkez çıkışı kaç AYRI günde oldu (365g). Sıçramalılık ölçüsü — ölçüldü 09.09:
    /// 17.713 çeşidin %67'si TEK GÜNDE çıkmış, çıkışın ortalama %82,7'si tek güne yığılı.
    /// </summary>
    int MerkezCikisGun,
    /// <summary>
    /// SATIŞ HIZI PAYDASI (gün). = min(365, mağazaya ilk girişten kesime kadar geçen gün).
    /// İlk giriş bilinmiyorsa 365 (1.186 ürün — ölçüldü 09.09).
    /// ⚠ SIRA SÖZLEŞMESİ: Dapper positional record — SELECT'te de EN SON kolon olmalı.
    /// </summary>
    int EtkinGun,
    // ⚠ SQL'de EtkinGun'dan HEMEN SONRA gelir (Dapper POZİSYONEL — ListeKolonlarSql).
    /// <summary>Önerilen sipariş adedi (plan-46). 0 = ihtiyaç yok / tavan kırptı.</summary>
    int SiparisOneri,
    /// <summary>Kapak: temin + 30 günü karşılayan stok düzeyi (emniyet dahil).</summary>
    int SiparisKapak,
    /// <summary>Kapağın hangi hızdan geldiği: "365g düz" | "sezon penceresi".</summary>
    string? SiparisTaban)
{
    /// <summary>
    /// Günlük ortalama satış. ⚠ 365'e SABİT bölünmez (09.09 düzeltmesi, kullanıcı uyarısı):
    /// ürün rafa 4 ay önce girdiyse paydası 365 değil ~120'dir. Ölçülen etki:
    /// 22.385 üründe gün-stok ortalama 1.644 → 524. Orijinal Excel raporu 365'e bölüyordu;
    /// bu kolon bilinçli olarak ondan AYRIŞIR (ekranda ipucu ile yazılı).
    /// </summary>
    public decimal GunlukOrtalamaSatis => SatisToplam / (decimal)Math.Max(1, EtkinGun);

    /// <summary>Raf süresi 365 günden kısa mı — hız paydası daralmış demektir (ekranda işaretlenir).</summary>
    public bool RafKisa => EtkinGun < 365;

    /// <summary>
    /// RAF GÜN-STOĞU — mağaza stoğu, mağaza satış hızına göre.
    ///
    /// ⚠ DÜZELTME 09.09.2026 (kurul bulgusu + kullanıcı bilgisi). Eski hâli
    /// <c>ToplamStok / mağaza hızı</c> idi ve KAPSAM ASİMETRİSİ taşıyordu: payda mağaza
    /// + merkez stoğu, paydada yalnız 3 mağaza satışı. Merkezden yılda 1.895.799 adet
    /// çıkıyor (ölçüldü) ve paydada yoktu → rakam sistematik olarak "stok yeter" yönünde
    /// sapıyor, alıcıyı az almaya itiyordu.
    ///
    /// E-ticaret paydaya EKLENMEDİ çünkü (kullanıcı 09.09) "e-ticaret stoğu bizde değil
    /// ODAK tarafında" — o talep ODAK'ın stoğunu tüketir. Bizim payımız ODAK'a yapılan
    /// satış olarak <see cref="MerkezCikis"/> içinde.
    ///
    /// Artık pay ve payda AYNI KAPSAM: raf stoğu ÷ raf hızı. Merkez ayrı
    /// (<see cref="MerkezGunStok"/>), toplanmaz.
    /// Raf süresi &lt; 28 gün ise hız güvenilmez → null (sessiz sayı üretilmez).
    ///
    /// ⚠ NEGATİF STOK GUARD'I (09.09.2026, kullanıcı: "-365 falan yazıyor ama saçma sapan
    /// bir şekilde"). Eksi mağaza stoğu hıza bölününce ANLAMSIZ NEGATİF GÜN üretiyordu:
    /// stkID 1739183'te MagazaStok −37, hız 37/365 = 0,101 → gün-stok tam <b>−365</b>.
    /// Bu sayı bir kapsam değil, bölme artığı. ÖLÇÜLDÜ (kesim 08.09.2026): 93 üründe
    /// negatif gün-stok gösteriliyordu. Eksi stok bir kapsama çevrilemez → null; eksi
    /// stoğun kendisi "Veri Kirli" KPI'sında ve mağaza kırılımında zaten görünüyor.
    /// (0 stok null DEĞİL: "0 gün" doğru ve bilgilendirici — raf boş demektir.)
    /// </summary>
    /// <summary>
    /// Raf gün-stoğu. <b>ARALIKLI TALEPTE HESAPLANMAZ</b> (düzeltme 10.09.2026):
    /// çeşitlerin %91,9'unda talep aralıklı ve orada "günlük ortalama satış" çoğu SIFIR olan
    /// aylara yayılıyor → gün-stok anlamını yitiriyor. Ölçüt ADI ≤ 1,32
    /// (Syntetos/Boylan/Croston 2005, yayınlanmış eşik). Sayı basmak yerine <c>null</c>
    /// döner ve ekranda sebebi yazılır — uydurma sayıdan iyidir.
    /// </summary>
    public decimal? GunStok => SatisToplam <= 0 || EtkinGun < 28 || MagazaStok < 0
            || !DuzgunTalep ? null
        : Math.Round((decimal)MagazaStok / GunlukOrtalamaSatis, 0);

    /// <summary>Talep deseni düzgün/değişken mi (ADI ≤ 1,32)? Gün-stok yalnız o zaman geçerli.</summary>
    public bool DuzgunTalep => SatanAy is > 0 && 12.0m / SatanAy.Value <= 1.32m;

    /// <summary>Talep deseni adı — ekranda ve Excel'de.</summary>
    public string TalepDeseniAd => SatanAy is null or 0 ? "satış yok"
        : 12.0m / SatanAy.Value <= 1.32m
            ? ((TalepCV2 ?? 0) <= 0.49m ? "düzgün" : "değişken")
            : ((TalepCV2 ?? 0) <= 0.49m ? "aralıklı" : "sıçramalı");

    /// <summary>
    /// MERKEZ ÇIKIŞI SIÇRAMALI MI — kullanıcı uyarısı 09.09: "merkez çıkış spontane".
    ///
    /// ⚠ BURADA BİR "MERKEZ GÜN-STOĞU" YOK ve olmayacak. Yazıldı, ölçüldü, KALDIRILDI:
    /// merkez çıkışını ortalama bir hıza bölmek anlamsız, çünkü çıkış hız değil sıçrama.
    /// ÖLÇÜLDÜ (365g, 17.713 çeşit): %67'si TEK GÜNDE çıkmış · %30'u 2-5 günde ·
    /// yalnız 1 ürün 30+ günde. Çıkışın ortalama %82,7'si tek güne yığılı; 15.569
    /// çeşitte (%88) yarısından fazlası tek gün. Uç: 110.100 adet / TEK belge.
    /// Ortalamaya bölmek "merkez şu kadar gün yeter" diye sahte güven üretirdi.
    /// </summary>
    public bool MerkezCikisSicramali => MerkezCikis > 0 && MerkezCikisGun <= 5;

    /// <summary>Çıkış olan günlerdeki ortalama parti büyüklüğü (adet/gün). Hız DEĞİL.</summary>
    public decimal? MerkezPartiBuyuklugu => MerkezCikisGun <= 0 ? null
        : Math.Round((decimal)MerkezCikis / MerkezCikisGun, 0);

    /// <summary>
    /// ESKİ (kapsam karışık) gün-stok — yalnız orijinal Excel raporuyla mutabakat için.
    /// Karara dayanak YAPILMAZ; ekranda gösterilmez.
    /// </summary>
    public decimal? GunStokKarisikKapsam => SatisToplam <= 0 ? null
        : Math.Round((decimal)ToplamStok / (SatisToplam / 365m), 0);

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
        // ⚠ Bu üçü EŞLEMEDE VARDI ama kolon tanımı YOKTU → hiçbir çıktıda seçilemiyordu
        // (10.09.2026, tools/panel_kolon_denetimi.py uyarısı ile bulundu).
        new("gun_stok",   "Gün-Stok",   Varsayilan: false, Siralanabilir: false, Sayisal: true,
            Ipucu: "Raf gün-stoğu = mağaza stoğu ÷ günlük ortalama mağaza satışı. "
                 + "ARALIKLI TALEPTE HESAPLANMAZ, '—' gösterir: çeşitlerin %91,9'unda ortalama "
                 + "çoğu sıfır olan aylara yayılıyor (Syntetos/Boylan/Croston eşiği ADI 1,32). "
                 + "Yeni ürün koruması: mağazada 28 günden az olan üründe de hesaplanmaz."),
        new("merkez_cikis", "Merkez Çıkış", Varsayilan: false, Siralanabilir: false, Sayisal: true,
            Ipucu: "Merkez deponun 365 günlük çıkış adedi. TÜKETİCİ TALEBİ DEĞİL: %72'si grup "
                 + "şirketine (frmID 56), %16 ODAK e-ticaret, %6 Sınav. Gün-stok paydasına "
                 + "girmez; buradaki büyük sayı mağaza talebi anlamına gelmez."),
        new("odak_durum", "ODAK Durum", Varsayilan: false, Siralanabilir: false, Sayisal: true,
            Ipucu: "ODAK satış durumu kodu (saleStatus). ODAK grup şirketi ama TEDARİKÇİ — "
                 + "o stok bizim envanterimiz değil, temin edilebilirlik sinyali."),
        new("talepdeseni", "Talep Deseni", Varsayilan: false, Siralanabilir: false,
            Ipucu: "Syntetos/Boylan/Croston sınıfı — düzgün · değişken · aralıklı · sıçramalı. "
                 + "Ölçüt: talep-arası aralık ADI = 12 / (satış olan ay sayısı), eşik 1,32; "
                 + "büyüklük değişkenliği CV², eşik 0,49. Bu eşikler YAYINLANMIŞTIR, bizim "
                 + "verimizden türetilmedi. GÜN-STOK YALNIZ düzgün/değişken sınıfta geçerli — "
                 + "ölçüldü 10.09.2026: çeşitlerin %91,9'u aralıklı ya da hiç satmıyor, orada "
                 + "ortalama çoğu sıfır olan aylara yayılıyor."),
        new("maliyettarih", "Maliyet Tarihi", Varsayilan: false, Siralanabilir: true,
            Ipucu: "Birim maliyetin kaynağı olan SON alış faturasının tarihi. Boş = alış "
                 + "faturası yok, maliyet ve marj hesaplanmıyor."),
        new("maliyetyas", "Maliyet Yaşı", Varsayilan: false, Siralanabilir: true, Sayisal: true,
            Ipucu: "Maliyetin kaç gün önceki faturadan geldiği. MARJ BU YAŞI TAŞIYOR: satış "
                 + "365 günlük, maliyet bu tarihten. Ölçüldü 10.09.2026 — maliyet yaşına göre "
                 + "gerçekleşen marj %24,4 (<3 ay) → %63,0 (2+ yıl). İki mekanizma aynı yöne "
                 + "çalışıyor ve ayrıştırılamıyor: enflasyon (eski maliyet düşük → marj şişkin) "
                 + "ve yavaş dönen ürünün zaten yüksek marjlı olması. Maliyet yeniden "
                 + "değerlenmedi; yaşı görünür kılındı ki marj okunurken bilinsin."),
        new("siparis_oneri", "Sipariş Önerisi", Varsayilan: false, Siralanabilir: true, Sayisal: true,
            Ipucu: "Önerilen sipariş adedi = kapak + emniyet − eldeki stok, kategori tavanıyla "
                 + "kırpılmış. Kapak = max(365g düz hız, SEZON penceresi) × (temin + 30 gün). "
                 + "Sezon penceresi geçen yılın AYNI takvim aralığındaki satışıdır ve bu yıl/"
                 + "geçen yıl oranıyla ölçeklenir (ölçüldü 11.09.2026: Kırtasiye 0,82 · Oyuncak "
                 + "1,50). ⚠ ÖNERİ, SİPARİŞ DEĞİL: MOQ/koli katı veride yok, tedarikçi iade "
                 + "hakkı izli değil, talep tahmini sağdan sansürlü (ALT SINIR)."),
        new("siparis_kapak", "Kapak", Varsayilan: false, Siralanabilir: true, Sayisal: true,
            Ipucu: "Temin süresi + 30 günlük gözden geçirme aralığını karşılayacak stok düzeyi "
                 + "(emniyet dahil). Eldeki stok bunun altındaysa ürün sipariş kohortuna girer."),
        new("siparis_taban", "Hız Tabanı", Varsayilan: false, Siralanabilir: false,
            Ipucu: "Kapağın hangi hızdan hesaplandığı. '365g düz' = yıllık ortalama. 'sezon "
                 + "penceresi' = geçen yılın aynı takvim aralığı; ölçüldü (11.09.2026) düz hız "
                 + "sezon ürününde talebi 4 KAT az sayıyor — Kırtasiye'de aylık dağılım "
                 + "Ağu 10.510 · Eyl 29.193 · Eki 10.437, zirve eylül ve 365 günlük pencere "
                 + "onu dışarıda bırakıyor."),
        new("satanay",    "Satan Ay",   Varsayilan: false, Siralanabilir: true,
            Ipucu: "Son 12 TAM ayda satış olan ay sayısı. 12 = her ay satmış; 1-2 = şiddetli "
                 + "aralıklı. Gün-stok ve günlük ortalama satış bu sayı düşükken yanıltıcı."),
        new("sonsatis",   "Son Satış",  Varsayilan: false, Siralanabilir: true,
            Ipucu: "Son satış tarihi — 365 günlük pencere YOK. Boş = hiç satılmamış. "
                 + "Hareketsiz stokta asıl soru bu: hiç satmadı mı, satıyordu da durdu mu?"),
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
        new("gunluk", "Günlük Ort.", Sayisal: true, Varsayilan: false, Ipucu: "Payda = raf süresi (en çok 365 gün), 365 sabit DEĞİL. Rafa yeni giren üründe 365'e bölmek hızı düşük gösterirdi — ölçüldü: 22.385 üründe gün-stok 1.644 yerine 524."),
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

/// <summary>
/// Bir günün BİR MAĞAZADAKİ kasa özeti (GunKarsilastirQueries).
/// ⚠ Dapper kolon ADIYLA eşler (pozisyonel değil) — SELECT takma adlarıyla birebir aynı olmalı.
/// </summary>
/// <param name="Fis">Perakende fiş sayısı = MÜŞTERİ SAYISI vekili. Tekil müşteri DEĞİL.</param>
/// <param name="IadeBelirsiz">Kaynağı çözülemeyen iade — hiçbir kanaldan düşülmedi.</param>
public sealed record GunMagazaSatir(
    string Magaza,
    int Fis,
    int SinavBelge,
    int IadeBelge,
    decimal PerakendeDahil,
    decimal SinavDahil,
    decimal PerakendeHaric,
    decimal SinavHaric,
    decimal IadePerakende,
    decimal IadeSinav,
    decimal IadeBelirsiz);

/// <summary>İki günün karşılaştırması. <paramref name="KesimDk"/> 1440 ise gün tamamı.</summary>
public sealed record GunKarsilastirSonuc(
    DateOnly Gun,
    DateOnly KiyasGun,
    int KesimDk,
    IReadOnlyList<GunMagazaSatir> Bugun,
    IReadOnlyList<GunMagazaSatir> Kiyas);
