namespace GmDashboard.Models;

/// <summary>Şube × kategori raf bulunurluğu (On-Shelf Availability) özeti — plan-33.
/// Taşınan-aktif = o şubede geçmişte raf açılmış + son12 satan SKU. Kuru = pencerede raf &lt; min-stok
/// (giriş-bakiyesi + carry-forward dahil). OOS% = kuru / taşınan.</summary>
public sealed class SubeOos
{
    public int Mekan { get; set; }
    public string MekanAd { get; set; } = "";
    public int Kat3ID { get; set; }
    public string Kategori { get; set; } = "";
    public int TasinanAktif { get; set; }
    public int Bulunur { get; set; }
    public int Kuru { get; set; }
    public decimal OosYuzde { get; set; }
}

/// <summary>Kayıp-satış öncelik satırı — kuru şubede kanıtlı-talep olan SKU. Tahmini kayıp = görünür satış ×
/// (eksik-şube / stoklu-şube) (kaba üst-sınır). ₺ = × son alış birim maliyeti.</summary>
public sealed class BulunurlukKayip
{
    public int StkID { get; set; }
    public string StkAd { get; set; } = "";
    public string Kategori { get; set; } = "";
    public string Marka { get; set; } = "";
    public int StokluSube { get; set; }
    public int KuruSube { get; set; }
    public string KuruSubeAd { get; set; } = "";
    public int GorunurSatis { get; set; }
    public int TahminiKayipAdet { get; set; }
    public decimal BirimMaliyet { get; set; }
    public decimal TahminiKayipTl => TahminiKayipAdet * BirimMaliyet;
}
