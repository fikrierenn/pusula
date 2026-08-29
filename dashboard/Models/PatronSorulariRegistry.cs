namespace GmDashboard.Models;

/// <summary>Bir sorunun bugünkü cevaplanabilirlik durumu.</summary>
public enum SoruDurum
{
    /// <summary>Canlı bir sayfada isimli kart/bölüm ile cevaplanıyor.</summary>
    Canli,
    /// <summary>Bir yönü var, sorunun tamamını cevaplamıyor.</summary>
    Parcali,
    /// <summary>Veri veya ekran yok — boşluk.</summary>
    VeriYok,
    /// <summary>BKM'de bu iş yok — boşluk sayılmaz, skoru bozmaz.</summary>
    KapsamDisi,
}

/// <param name="Id">PS-&lt;departman&gt;.&lt;sıra&gt; — kapsam belgesiyle birebir.</param>
/// <param name="Route">Cevabın bulunduğu sayfa (NavRegistry href'i). null = kaynak yok.</param>
/// <param name="Kanit">Durumun gerekçesi: hangi kartta cevaplanıyor ya da neden yok.</param>
/// <param name="Eksik">Parçalı ise sorunun cevaplanmayan yarısı.</param>
/// <param name="Is">Boşluğu kapatacak plan/TODO referansı.</param>
/// <param name="Danisman">Departman varsayılanını ezer (6. departman üç disipline ayrılır).</param>
/// <param name="Metrik">Faz B lazy mini-metrik anahtarı (PatronSorulariQueries). null = rakam yok.</param>
public record PatronSorusu(
    string Id,
    int DepartmanNo,
    string Soru,
    SoruDurum Durum,
    string? Route,
    string Kanit,
    string? Eksik = null,
    string? Is = null,
    string? Danisman = null,
    string? Metrik = null);

/// <param name="Danisman">Bloğun "Sen olsan ne yapardın?" butonunun konuşacağı danışman skill'i.</param>
public record PatronDepartman(int No, string Ad, string Ikon, string Danisman);

/// <summary>
/// "Patron Soruları — Tüm Departmanlar" kayıt defteri — TEK kaynak (plan-37, NavRegistry deseni).
/// Sayfa bu listeyi render eder; hesap YAPMAZ. Rozet/route değişikliği önce
/// <c>docs/2026-08-29-patron-sorulari-kapsam.md</c>'ye, sonra buraya yazılır — belge otoritedir.
/// Kanıtsız rozet değişikliği yasak: Canli demek için sayfada isimli bir kart bulunmalı.
/// </summary>
public static class PatronSorulariRegistry
{
    /// <summary>Soru sayısı sabittir; değişirse kapsam belgesi de değişmiş olmalı.</summary>
    public const int ToplamSoru = 25;

    public static readonly IReadOnlyList<PatronDepartman> Departmanlar = new[]
    {
        new PatronDepartman(1, "Her Departmana Önce", "target", "satis-danisman"),
        new PatronDepartman(2, "Satış ve Pazarlama", "users", "satis-danisman"),
        new PatronDepartman(3, "Satın Alma ve Stok", "shopping-bag", "satinalma-danisman"),
        new PatronDepartman(4, "Operasyon (mağaza · depo · kafe · lojistik)", "store", "operasyon-danisman"),
        new PatronDepartman(5, "Finans, Muhasebe ve Vergi", "landmark", "finans-nakit-danisman"),
        new PatronDepartman(6, "İK · Bilgi Teknolojileri · Lojistik", "shield", "ik-danisman"),
    };

    public static readonly IReadOnlyList<PatronSorusu> Sorular = new[]
    {
        // ── 1 — Her departmana önce (kesişen blok; danışman ilgili departmanınki) ──
        new PatronSorusu("PS-1.1", 1, "Hedef neydi?", SoruDurum.Canli, "tahmin",
            "Mağaza Bazlı Tahmin · Hedef (MTD) kartı", Metrik: "hedef-gerceklesme"),
        new PatronSorusu("PS-1.2", 1, "Gerçekleşen ne oldu?", SoruDurum.Canli, "",
            "Genel Bakış KPI bandı · TOPLAM — Kategoriler", Metrik: "mtd-ciro"),
        new PatronSorusu("PS-1.3", 1, "Fark neden oluştu?", SoruDurum.Parcali, "tahmin",
            "Hesap Adımları + Bileşen Kırılımı",
            Eksik: "Fiyat × miktar × mix variance ayrıştırması yok — farkın kaynağı sayısal bölünmüyor",
            Is: "Tier-2"),
        new PatronSorusu("PS-1.4", 1, "Para ve nakit etkisi ne?", SoruDurum.VeriYok, null,
            "Gelir tablosu tahakkuk esaslı; nakit görünümü hiç yok",
            Is: "plan-38 (nakit bloğu)"),
        new PatronSorusu("PS-1.5", 1, "Kim, ne zamana kadar düzeltecek?", SoruDurum.Canli, "gorevler",
            "Görev + son tarih + açık görev rozeti", Metrik: "acik-gorev"),

        // ── 2 — Satış ve pazarlama ──
        new PatronSorusu("PS-2.1", 2, "Hangi müşteri ve ürün gerçekten kazandırıyor?", SoruDurum.Parcali, "sadakat",
            "Müşteri Konsantrasyonu (Pareto) · RFM Segment · Kohort Retention; ürün tarafı kategori/marka/tedarikçi marjı (/envanter)",
            Eksik: "SKU bazlı kâr yok (FIFO maliyet katmanı D:\\Dev\\fifo'da hazır, dashboard'a bağlanmamış)",
            Is: "Tier-2"),
        new PatronSorusu("PS-2.2", 2, "İndirim katkı payını ne kadar düşürüyor?", SoruDurum.Parcali, "hediye-ceki",
            "Baremli kârlılık · İndirim mi çek fazlası mı · /operasyon İndirim Kaynağı dağılımı",
            Eksik: "İndirim → marj erozyonu köprüsü yok (tüm indirim türleri birlikte, kategori üstü)",
            Is: "Tier-2", Metrik: "hediye-ceki-12ay"),
        new PatronSorusu("PS-2.3", 2, "Teklifler satışa neden dönmüyor?", SoruDurum.KapsamDisi, null,
            "BKM perakende; B2B teklif süreci yok (GMY kararı 29.08.2026). Tekrar sorulmasın diye listede tutuluyor"),
        new PatronSorusu("PS-2.4", 2, "Hangi alacağın tahsilatı riskli?", SoruDurum.Canli, "cari-risk",
            "Vadesi Geçen (toplam) · Limit Aşan Cari · net bakiye"),

        // ── 3 — Satın alma ve stok ──
        new PatronSorusu("PS-3.1", 3, "Doğru fiyat ve vadeyle mi alıyoruz?", SoruDurum.Parcali, "satinalma/analiz",
            "Fiyat Sapması sekmesi (3 adalet filtresi: birim<1₺ · ölçek-uyumsuz · grup-içi taraf)",
            Eksik: "Vade ekseni yok — iade/ödeme koşulu analizi yapılmıyor",
            Is: "B-150 (frmIadeKural anlamı muhasebeden bekleniyor)"),
        new PatronSorusu("PS-3.2", 3, "Stok kaç gün bekliyor?", SoruDurum.Canli, "envanter",
            "Kategori Devir Hızı · ölü stok listesinde \"gün listede\""),
        new PatronSorusu("PS-3.3", 3, "Hangi mal yavaşlıyor veya değer kaybediyor?", SoruDurum.Canli, "envanter",
            "Ölü Sermaye — Kilitli Stok · Marka Alış-Satış Dengesi · /baskisi-yok · /bulunurluk", Metrik: "bulunurluk-oos"),
        new PatronSorusu("PS-3.4", 3, "Alternatif tedarikçimiz var mı?", SoruDurum.VeriYok, null,
            "Tedarikçi ↔ ürün alternatif matrisi yok; tek-yayınevi bağımlılığı ölçülmüyor",
            Is: "Tier-2"),

        // ── 4 — Operasyon (üretim yok → mağaza · depo · kafe · lojistik) ──
        new PatronSorusu("PS-4.1", 4, "Kapasitenin ne kadarı kullanılıyor?", SoruDurum.Canli, "operasyon",
            "İşgücü Verimi (SPLH) · Depo Toplama Verimi · Kayıp İşgücü Potansiyeli · Bekleyen Sipariş Doluluk"),
        new PatronSorusu("PS-4.2", 4, "Fire ve yeniden işleme neden arttı?", SoruDurum.VeriYok, null,
            "Üç alt-kalem, üçünün de veri kaynağı belirsiz: (a) kayıp-kaçak/sayım farkı (b) iade edilemez stok (c) kafe zayi",
            Is: "Tier-2 KEŞİF — kaynak doğrulanmadan analiz tasarlanmaz (fact-force gate)"),
        new PatronSorusu("PS-4.3", 4, "Birim maliyet neden değişti?", SoruDurum.Canli, "satinalma/analiz",
            "Alış fiyat sapması + kanonik maliyet şelalesi (son 5 alış faturası). Fiyat/mix/fire ayrımı yorumda"),
        new PatronSorusu("PS-4.4", 4, "Teslimat nerede gecikiyor?", SoruDurum.Canli, "eticaret",
            "Bekleyen Gün (kargoya çıkmamış) · sipariş→kargo gün · Kargo Performansı (firma bazlı)", Metrik: "bekleyen-kargo"),

        // ── 5 — Finans, muhasebe ve vergi (en zayıf blok) ──
        new PatronSorusu("PS-5.1", 5, "13 haftada en düşük nakit ne zaman?", SoruDurum.VeriYok, null,
            "Haftalık nakit projeksiyonu yok. Eksik veri: banka hareketi · kredi taksit takvimi · tedarikçi vade dağılımı · POS valörü · vergi/SGK takvimi",
            Is: "plan-38 (şartnamesini finans-nakit-danisman üretir)"),
        new PatronSorusu("PS-5.2", 5, "Borç taksiti faaliyet nakdini karşılıyor mu (DSCR)?", SoruDurum.VeriYok, null,
            "Borç servisi takvimi veride yok; faaliyet nakdi türetilmiyor (işletme sermayesi değişimi hesaplanmıyor)",
            Is: "plan-38"),
        new PatronSorusu("PS-5.3", 5, "KDV ve vergi için para ayrıldı mı?", SoruDurum.Parcali, "mizan",
            "Kesin mizan hesapları görülebiliyor",
            Eksik: "Karşılık görünümü yok (ödenecek vergi vs ayrılan para). Kitap %0 KDV → girdi KDV'si devreden olarak birikir, ayrı okunmalı",
            Is: "plan-38"),
        new PatronSorusu("PS-5.4", 5, "Banka, POS, stok ve kayıtlar tutarlı mı?", SoruDurum.Parcali, "muhasebe",
            "Kapanış-sonrası müdahale denetimi · /operasyon Ödeme Grubu mutabakatı",
            Eksik: "Banka mutabakatı yok (banka hareketi otomatik akmıyor; POS valör + komisyon netleşmesi yok)",
            Is: "plan-38"),

        // ── 6 — İK · BT · Lojistik (tek kutu, ÜÇ ayrı disiplin → üç danışman) ──
        new PatronSorusu("PS-6.1", 6, "Pozisyonun şirkete katkısı ve maliyeti ne?", SoruDurum.Parcali, "trafik",
            "Kasiyer verimi + PDKS; maaş dökümü scripts/beyaz_yaka_maas_excel.py (ekran yok)",
            Eksik: "Pozisyon maliyet-katkı ekranı yok. Ücret birimi tuzağı: GÜNLÜK (kadronun ~%99) vs AYLIK karışırsa 30× hata",
            Is: "plan-39 · B-161 (maskeleme modları)",
            Danisman: "ik-danisman"),
        new PatronSorusu("PS-6.2", 6, "Tek kişiye bağımlı iş var mı?", SoruDurum.VeriYok, null,
            "Bus-factor envanteri yok. İki yarısı ayrı: kim yapabilir listesi (İK) · SQL job/ERP parametresi bilgisi kimde (BT)",
            Is: "plan-39",
            Danisman: "ik-danisman"),
        new PatronSorusu("PS-6.3", 6, "Veri ve sistem kesintisi riski ne?", SoruDurum.VeriYok, null,
            "RTO/RPO ölçülmemiş, geri yükleme testi kaydı yok. Yoğunlaşma: 192.168.40.201 tek sunucuda 4 kritik DB; gece job'ı sessiz başarısız olursa dashboard bayat veri gösterir",
            Is: "plan-39",
            Danisman: "bt-risk-danisman"),
        new PatronSorusu("PS-6.4", 6, "Sevkiyat ve teslimat maliyeti neden değişti?", SoruDurum.Parcali, "eticaret",
            "Kargo firma dağılımı · COD iade maliyeti · kapıda bedel",
            Eksik: "Birim kargo maliyet trendi yok (desi/mesafe/firma mix ayrıştırılmamış)",
            Is: "Tier-2",
            Danisman: "operasyon-danisman"),
    };

    /// <summary>Kapanış sorusu — her departman bloğunun altında, o bloğun danışman rolüyle sorulur.</summary>
    public const string KapanisSorusu = "Sen olsan ne yapardın?";

    public static IEnumerable<PatronSorusu> DepartmanSorulari(int no) =>
        Sorular.Where(s => s.DepartmanNo == no);

    /// <summary>Sorunun danışmanı: kendi alanı varsa o, yoksa departman varsayılanı.</summary>
    public static string DanismanBul(PatronSorusu s) =>
        s.Danisman ?? Departmanlar.First(d => d.No == s.DepartmanNo).Danisman;

    public static int Sayim(SoruDurum d) => Sorular.Count(s => s.Durum == d);

    /// <summary>
    /// Bütünlük denetimi (plan-37 done criteria). Boş liste = temiz.
    /// Orphan link (B-75 kökü) ve kayıp/fazla soru burada yakalanır.
    /// </summary>
    public static IReadOnlyList<string> Dogrula()
    {
        var hatalar = new List<string>();

        if (Sorular.Count != ToplamSoru)
            hatalar.Add($"Soru sayısı {Sorular.Count}, beklenen {ToplamSoru} — kapsam belgesiyle ayrıştı.");

        var mukerrer = Sorular.GroupBy(s => s.Id).Where(g => g.Count() > 1).Select(g => g.Key);
        foreach (var id in mukerrer)
            hatalar.Add($"Mükerrer soru ID: {id}");

        var rotalar = NavRegistry.Items.Select(i => i.Href).ToHashSet();
        foreach (var s in Sorular.Where(s => s.Route is not null && !rotalar.Contains(s.Route!)))
            hatalar.Add($"{s.Id}: NavRegistry'de olmayan route '{s.Route}'");

        foreach (var s in Sorular.Where(s => s.DepartmanNo is < 1 or > 6))
            hatalar.Add($"{s.Id}: geçersiz departman {s.DepartmanNo}");

        // Rozet ↔ alan tutarlılığı: kaynağı olan soru Canli/Parcali, olmayan VeriYok/KapsamDisi olmalı.
        foreach (var s in Sorular)
        {
            var kaynakVar = s.Route is not null;
            var cevapVar = s.Durum is SoruDurum.Canli or SoruDurum.Parcali;
            if (kaynakVar != cevapVar)
                hatalar.Add($"{s.Id}: durum {s.Durum} ile route ({s.Route ?? "yok"}) tutarsız");
            if (s.Durum == SoruDurum.Parcali && string.IsNullOrWhiteSpace(s.Eksik))
                hatalar.Add($"{s.Id}: parçalı ama eksik yarısı yazılmamış");
            if (s.Durum == SoruDurum.VeriYok && string.IsNullOrWhiteSpace(s.Is))
                hatalar.Add($"{s.Id}: boşluk ama bağlandığı iş (plan/TODO) yazılmamış");
        }

        return hatalar;
    }
}
