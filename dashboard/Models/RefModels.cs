namespace GmDashboard.Models;

/// <summary>RFM müşteri segmenti (yazarkasa veya e-ticaret kanalı).</summary>
public record RfmSegment(string Segment, int Musteri, decimal Ciro);

/// <summary>Kategori devir/verim satırı (envanter).</summary>
public record DevirRow(string Kategori, decimal Devir, decimal? Wos, decimal? SellThrough, decimal StokTl, int Satilan);

/// <summary>ABC sınıfı (Pareto).</summary>
public record AbcClass(string Sinif, int Adet, decimal Ciro);

/// <summary>Marka/yayınevi performansı.</summary>
public record MarkaRow(string Ad, decimal Ciro, int Adet, int Cesit);

/// <summary>Stockout kategori satırı.</summary>
public record StockoutRow(string Kategori, int Cesit, int Yok, decimal Pct);

/// <summary>SPLH işgücü verimi (mağaza, ₺/saat).</summary>
public record SplhRow(string Magaza, decimal NetCiro, int Fis, decimal Saat, int Personel);

/// <summary>COD kapıda ödeme satırı.</summary>
public record CodRow(string Tip, int Siparis, int Teslim, int Iade);

/// <summary>Operasyon ek veri (SPLH + COD).</summary>
public record OpsData(IReadOnlyList<SplhRow> Splh, IReadOnlyList<CodRow> Cod, decimal CodZarar);

/// <summary>Envanter sayfası toplu veri.</summary>
public record InventoryData(
    decimal ToplamDeger,
    IReadOnlyList<DevirRow> Devir,
    IReadOnlyList<AbcClass> Abc,
    IReadOnlyList<MarkaRow> Marka,
    IReadOnlyList<StockoutRow> Stockout);
