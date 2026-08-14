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
    int SatinSezonMinTaban = 30)       // sezon-özel büyüme için min önceki-yıl sezon tabanı (SEZMIN)
{
    public static readonly int[] VarsayilanHaricMarkalar = [0, 269, 2101, 5972, 10911];
    public IReadOnlyList<int> HaricMarkalarEtkin => HaricMarkalar is { Count: > 0 } ? HaricMarkalar : VarsayilanHaricMarkalar;
}
