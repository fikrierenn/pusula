namespace GmDashboard.Models;

// ── Hediye Çeki paneli (plan-36) ────────────────────────────────────────────────
// Çekirdek: sorgular/2026-08-25-hediye-ceki-karlilik-indirim.sql (18 blok)
// Belge:    docs/2026-08-25-hediye-ceki-indirim-raporu.md (v5)
// Tüm tutarlar KDV-HARİÇ net (istisna: SepetOdenen = gerçek tahsilat, KDV-dahil).

/// <summary>Çek satış/çıkış kanalı — irsHrk hareket tipi bazlı. POS azınlık kanal (%35);
/// asıl kanal satış faturası (ehTip 1, ~%55). POS-only ölçüm hacmi ~3 kat eksik gösterir.</summary>
public record HcKanal(int Tip, string TipAd, int Satir, decimal Adet, decimal TutarNet)
{
    /// <summary>Satış kanalı mı (1 Satış · 4 Mağaza Satış · 100 POS Satış)?</summary>
    public bool Satis => Tip is 1 or 4 or 100;
    /// <summary>İade mi (3 Satış İade · 5 Mağaza Satış İade · 101 POS Satış İade)?</summary>
    public bool Iade => Tip is 3 or 5 or 101;
    /// <summary>Bedelsiz çıkış mı (89 Diğer Çıkış · 98 Şirket İçi Kullanım) — imha/hediye/merkeze iade.</summary>
    public bool Bedelsiz => Tip is 89 or 98;
    /// <summary>Çek basımı / stok girişi (88 Diğer Giriş) — SATIŞ DEĞİL, karışırsa hacim iki katına çıkar.</summary>
    public bool StokGirisi => Tip == 88;
}

/// <summary>POS'ta çek tahsilatı (PaymentTypesId=11). Yuvarlak = basılı kupür,
/// kusurlu = kısmi harcama artığı. ⚠ İADE ÇEKİ (tip 10) BURAYA GİRMEZ — geri dönüşüm çeki orada.</summary>
public record HcKullanim(int Hareket, decimal Tutar, decimal YuvarlakTutar, decimal KusurluTutar);

/// <summary>Barem paydası — çek dilimi bazlı fiş/çek/sepet. Kaldıraç = SepetOdenen / HcOdenen.</summary>
public record HcBaremPayda(int Dilim, int Fis, decimal HcOdenen, decimal OrtCek, decimal SepetOdenen);

/// <summary>Barem kalemi — dilim × ürün × kategori. Maliyet AYRI sorgudan gelir (perf: plan-36 §4).</summary>
public record HcBaremKalem(int Dilim, int StkID, string KatAna, decimal Adet,
                           decimal Brut, decimal Indirim, decimal Net);

/// <summary>fat5 birim maliyet — son 5 alış faturası SUM(ehTutarN)/SUM(ehAdetN), DerinSIS + ODAK birleşik.</summary>
public record HcMaliyet(int StkID, decimal Birim);

/// <summary>Fatura kanalında müşteri bazlı mevcut indirim. Kararın asıl konusu: oran KURALSIZ (%0–15).
/// ⚠ Grup konsolidasyonu ERP'de YOK (frm.frmBagID + frmGrup1..5 hepsi 0) → liste HAM gelir.</summary>
public record HcFaturaIndirim(int FrmID, string FirmaAd, int Fatura, decimal Adet,
                              decimal Brut, decimal Indirim, decimal Net)
{
    public decimal Oran => Brut == 0 ? 0 : 100m * Indirim / Brut;
}

// ── Türetilmiş (panel içinde hesaplanan, SQL'den gelmeyen) ──────────────────────

/// <summary>Barem satırı — payda + kalem/maliyet birleşimi. Kâr/1 ₺ çek = kararın merkezi metriği.</summary>
public record HcBaremSatir(
    int Dilim, string Etiket, int Fis, decimal OrtCek, decimal OrtSepet, decimal Kaldirac,
    decimal Brut, decimal Indirim, decimal Net, decimal NetKapsanan, decimal Maliyet,
    decimal KitapNet)
{
    public decimal IndirimOran => Brut == 0 ? 0 : 100m * Indirim / Brut;
    public decimal Kapsama => Net == 0 ? 0 : 100m * NetKapsanan / Net;
    public decimal BrutKar => NetKapsanan - Maliyet;
    public decimal Marj => NetKapsanan == 0 ? 0 : 100m * BrutKar / NetKapsanan;
    public decimal KarFis => Fis == 0 ? 0 : BrutKar / Fis;
    /// <summary>1 ₺ çek yüzü başına brüt kâr. &gt;1 ise o kupürün yüzü maliyetinden fazla kâr getirir.</summary>
    public decimal KarCek => HcOdenenGuvenli == 0 ? 0 : BrutKar / HcOdenenGuvenli;
    /// <summary>Kırılma noktası: brüt kârı sıfırlayan nominal indirim oranı (%).</summary>
    public decimal Kirilma => KarCek * 100m;
    public decimal KitapPay => Net == 0 ? 0 : 100m * KitapNet / Net;
    public decimal HcOdenenGuvenli { get; init; }
}

/// <summary>Kategori marjı — §6 tablosu. Barem kalemleri + fat5'ten türer.</summary>
public record HcKategori(string KatAna, decimal Brut, decimal Indirim, decimal Net,
                         decimal NetKapsanan, decimal Maliyet)
{
    public decimal IndirimOran => Brut == 0 ? 0 : 100m * Indirim / Brut;
    public decimal BrutKar => NetKapsanan - Maliyet;
    public decimal Marj => NetKapsanan == 0 ? 0 : 100m * BrutKar / NetKapsanan;
    public decimal Kapsama => Net == 0 ? 0 : 100m * NetKapsanan / Net;
}

/// <summary>Basılı kupür kaldıracı — bonus simülatörünün DAYANAĞI.
/// ⚠ Kısmi bakiye artıkları AYIKLANMIŞ: bonus programı basılı kupür ihraç eder,
/// artık-davranışı (barem-1'in 10,66×) tasarımla ÜRETİLEMEZ.</summary>
public record HcKupur(int Dilim, string Etiket, int Fis, decimal HcOdenen,
                      decimal SepetOdenen, decimal Marj)
{
    public decimal Kaldirac => HcOdenen == 0 ? 0 : SepetOdenen / HcOdenen;
    /// <summary>1 ₺ çek yüzü başına brüt kâr = kaldıraç × KDV-hariç oran × marj.</summary>
    public decimal KarCek => Kaldirac * HediyeCekiSabit.NetOran * Marj / 100m;
    /// <summary>Örneklem güvenilir mi? 50 fişin altı yalnız mertebe göstergesidir.</summary>
    public bool ZayifOrneklem => Fis < 50;
}

/// <summary>Panel sabitleri — hesap formülleri tek yerde (emitter-ayrimi).</summary>
public static class HediyeCekiSabit
{
    /// <summary>Sepet ödenen (KDV-dahil) → net (KDV-hariç) dönüşüm oranı. Ölçülen: 3.478.668 / 3.792.384.
    /// Kitap %0 KDV ağırlıklı olduğu için 1'e yakın.</summary>
    public const decimal NetOran = 0.917m;

    /// <summary>Kitap sayılan kategoriler — barem kitap payı hesabı. Marj tabanı %14-15
    /// (yayınevi iskontosu ~%35 + rafta ~%27 indirim) → tavan riskinin kaynağı.</summary>
    public static readonly string[] KitapKategorileri =
    {
        "Edebiyat Kitapları", "Çocuk Kitapları", "Psikolojik Kitaplar", "Felsefe Kitapları",
        "Bilim ve Mühendislik Kitapları", "Periyodik Yayın Kitapları",
        "Sınavlara Hazırlık Kitapları", "Gezi ve Rehber Kitapları",
    };

    /// <summary>Geri dönüşüm ürünü — "Geri Dönüşüm Kağıt Madde Alımı", kilo bazlı.
    /// Ayıklama İKİ koşullu: sebep kodu 416 satırda yanlış işaretlenmiş.</summary>
    public const string GeriDonusumStkKod = "583160";

    /// <summary>POS geri dönüşüm iade sebebi (RefundReasons.Id, Type=0).</summary>
    public const int GeriDonusumSebep = 12;

    public static string DilimEtiket(int d) => d switch
    {
        1 => "≤ 100 ₺",
        2 => "101–250 ₺",
        3 => "251–500 ₺",
        4 => "501–1.000 ₺",
        5 => "1.001–2.500 ₺",
        _ => "2.500 ₺ +",
    };

    /// <summary>Müşteri eşdeğerliği: indirim x ↔ bonus b. b = x/(1−x)</summary>
    public static decimal BonusEsdeger(decimal x) => x >= 1m ? 0m : x / (1m - x);

    /// <summary>Tersi: bonus b, müşteri gözüyle hangi indirime eşit? x = b/(1+b)</summary>
    public static decimal IndirimEsdeger(decimal b) => b / (1m + b);

    /// <summary>İndirim x verildiğinde 1 ₺ NAKİT başına brüt kâr = (r − x) / (1 − x)</summary>
    public static decimal IndirimKar(decimal r, decimal x) => x >= 1m ? 0m : (r - x) / (1m - x);

    /// <summary>Bonus b verildiğinde 1 ₺ NAKİT başına brüt kâr = r_ana + b × (r_bonus − 1).
    /// r_bonus &gt; 1 ise bonus arttıkça kâr ARTAR (kırılma yok). Aynı kupürde r_bonus = r_ana
    /// ve b = x/(1−x) ise sonuç indirimle BİREBİR aynıdır — bonus tek başına kazanç değil.</summary>
    public static decimal BonusKar(decimal rAna, decimal rBonus, decimal b) => rAna + b * (rBonus - 1m);
}
