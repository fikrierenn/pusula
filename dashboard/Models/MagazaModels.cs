namespace GmDashboard.Models;

// Mağaza detay sayfası (/magaza/{id}) modelleri — B-40

/// <summary>Ödeme tipi banka/alt-kalem (G2 ham satır — grup detayında).</summary>
public record OdemeRow(string Tip, int Islem, decimal Tutar, decimal Pay);

/// <summary>Ödeme üst-grubu (Kredi/Banka Kartı · Nakit · İade Çeki · Hediye Çeki). Detay = bankalar.</summary>
public record OdemeGrup(string Grup, int Islem, decimal Tutar, decimal Pay, IReadOnlyList<OdemeRow> Detay);

/// <summary>Kampanya yükü (M2). İki bakış:
/// A) kalem: Brut/Indirim/Oran = sadece kampanyaya giren ürünler (kampanyanın indirim gücü).
/// B) fiş: FisCiro = o kampanyalı fişlerin TÜM sepeti (yanında alınan diğer ürünler dahil — çapraz satış etkisi).</summary>
public record KampanyaRow(string Ad, int Gun, decimal Brut, decimal Indirim, decimal Oran, int Fis, decimal FisCiro);

/// <summary>Kampanya üst-grubu: 3AL2ÖDE ayrı · Diğer İndirimler toplu (Detay=tek tek kampanyalar).</summary>
public record KampanyaGrup(string Ad, decimal Brut, decimal Indirim, decimal Oran, decimal FisCiro, int Fis, IReadOnlyList<KampanyaRow> Detay);

/// <summary>Tek mağaza detay: KPI + ödeme/iade/kampanya/UPT + kategori.</summary>
public record MagazaDetay(
    int MekanId,
    string Ad,
    decimal Net,
    int Fis,
    int Atv,           // sepet ort = net / fiş
    decimal Upt,       // sepet adedi = SalesProducts.Amount toplamı / fiş
    decimal Iade,
    decimal IadeOran,  // iade brüt / satış brüt %
    decimal? GerPct,   // aylık hedef gerçekleşme (sadece ay döneminde)
    IReadOnlyList<OdemeGrup> Odeme,
    IReadOnlyList<KampanyaGrup> Kampanya,
    IReadOnlyList<CategorySlice> Kategori);
