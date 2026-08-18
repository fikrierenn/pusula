namespace GmDashboard.Models;

/// <summary>İş eşiği ayarları (PanelAyar, BkmPanel app-local). Hardcode'dan çıkarıldı — CFO tunelar.
/// Varsayılanlar = eski hardcode değerleri (devir 1,5/3 · stockout %5 · risk 100/200/300 · iç-op/ev-markası).</summary>
public record PanelAyarlar(
    decimal DevirOlu = 1.5m,           // < bu = ölü stok (error)
    decimal DevirSaglikli = 3.0m,      // > bu = sağlıklı (success); arası warning
    decimal StokYoklukHedef = 5.0m,    // stockout hedef üst sınır (%)
    int RiskDusuk = 100,               // Kontrol paneli risk renk eşiği (info)
    int RiskOrta = 200,                // warning
    int RiskYuksek = 300,              // error
    IReadOnlyList<int>? HaricMarkalar = null,  // tedarikçi scorecard dışı mrkID (iç-op/ev-markası)
    int SatinFazlaAy = 12,             // Alım Analizi: tükenme > bu ay → FAZLA şüphesi (ESIK)
    int SatinMaterialite = 5000,       // bağlı para < bu ₺ → düşük öncelik (MAT + tolerans varsayılanı)
    int SatinMinKoli = 24,             // bu ay alış ≤ bu → küçük-koli (MINKOLI)
    int SatinMinStok = 3,              // stoklu-ay için min şube bakiye (≈1/şube×3; MINSTOK)
    int SatinSezonMinTaban = 30,       // sezon-özel büyüme için min önceki-yıl sezon tabanı (SEZMIN)
    int SatinRetailCap = 50,           // retail-momentum: tek-hareket bu adedin üstü = toptan/bulk, tavana kırpılır (RETAILCAP)
    // --- plan-34: hesap-sorma derinleşmesi ---
    string? SatinIadeKurallari = null,   // frm.frmIadeKural kodları "iade hakkı VAR" sayılacaklar (ör. "1,2"). BOŞ = özellik kapalı, davranış eskisi gibi.
    string? SatinAliciHaric = null,      // atıf dışı hesaplar (yazılımcı/denetim) — varsayılan hakan.cetin, kubra.kulaksizoglu
    string? SatinAliciBirlestir = null,  // aynı kişinin çok hesabı: "ana=digeri;ana2=digeri2" (varsayılan eren.boran2=eren.boran)
    int SatinRatchetAy = 6,              // ratchet penceresi (ay) — üst üste alım/trend taraması
    string? SatinAtifBaslangic = null)   // atıf pencere başı YYYYMMDD — varsayılan 20250201 (kanal kırılması + talep verisi güvenilir sınırı)
{
    public static readonly int[] VarsayilanHaricMarkalar = [0, 269, 2101, 5972, 10911];
    public IReadOnlyList<int> HaricMarkalarEtkin => HaricMarkalar is { Count: > 0 } ? HaricMarkalar : VarsayilanHaricMarkalar;

    // --- plan-34 türetilmiş ayarlar ---
    /// <summary>İade-hakkı sayılan frmIadeKural kodları. BOŞ liste = özellik KAPALI (FAZLA işareti koşullanmaz, regresyon yok).</summary>
    public IReadOnlyList<int> IadeKuralKodlari => Ayir(SatinIadeKurallari)
        .Select(x => int.TryParse(x, out var n) ? n : (int?)null).Where(n => n.HasValue).Select(n => n!.Value).ToArray();

    /// <summary>Atıf dışı tutulacak hesaplar (alıcı olmayan: yazılımcı, iç denetim). Boşsa varsayılan liste.</summary>
    public IReadOnlyList<string> AliciHaricEtkin
    {
        get { var l = Ayir(SatinAliciHaric); return l.Count > 0 ? l : VarsayilanAliciHaric; }
    }
    public static readonly string[] VarsayilanAliciHaric = ["hakan.cetin", "kubra.kulaksizoglu"];

    /// <summary>İkincil hesap → ana hesap eşlemesi (aynı kişi çok hesap; atıfta birleştirilir).</summary>
    public IReadOnlyDictionary<string, string> AliciBirlestirMap
    {
        get
        {
            var ham = string.IsNullOrWhiteSpace(SatinAliciBirlestir) ? "eren.boran2=eren.boran" : SatinAliciBirlestir!;
            var d = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            foreach (var parca in ham.Split(';', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
            {
                var kv = parca.Split('=', 2, StringSplitOptions.TrimEntries);
                if (kv.Length == 2 && kv[0].Length > 0 && kv[1].Length > 0) d[kv[1]] = kv[0];   // ikincil → ana
            }
            return d;
        }
    }

    /// <summary>Atıf pencere başı (YYYYMMDD). 2025-02-01 öncesi veri güvenilmez: e-tic kanal devri (06.01.2025) + talep sistemi ısınma dönemi + 2024-08/09/10 kayıt boşluğu.</summary>
    public string AtifBaslangicEtkin =>
        !string.IsNullOrWhiteSpace(SatinAtifBaslangic) && SatinAtifBaslangic!.Length == 8 ? SatinAtifBaslangic! : "20250201";

    static IReadOnlyList<string> Ayir(string? s) => string.IsNullOrWhiteSpace(s)
        ? []
        : s.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
}
