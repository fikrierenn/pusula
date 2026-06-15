namespace GmDashboard.Models;

/// <summary>RFM müşteri segmenti (yazarkasa veya e-ticaret kanalı).</summary>
public record RfmSegment(string Segment, int Musteri, decimal Ciro);

/// <summary>Drill: segmentteki tekil müşteri (ad/telefon + RFM metrikleri).</summary>
public record CustomerRow(long Id, string Ad, string Tel, int Frq, decimal Mon, int Rec);

/// <summary>Drill: kategorideki tekil ürün. Satis/Ciro = seçili dönem; S30/S90/S360 = bugünden geriye
/// trailing pencere satış adedi (kaç-gün-yeter). StokFsm/Ozl/Ist/Depo = anlık stok dağılımı (stokSonAltDepo_vw).
/// Bakiye = seçili kapsamdaki şube stoğu (cover hesabı için).</summary>
public record UrunRow(string Kod, string Ad, int Satis, decimal Ciro, int Bakiye, int S30, int S90, int S360,
    int StokFsm, int StokOzl, int StokIst, int StokDepo, int StokOdak);

/// <summary>Ciro-vs-envanter scatter noktası (kategori).</summary>
public record CveRow(string Kategori, decimal Ciro, decimal Env);

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

/// <summary>Kategori brüt marj satırı (son 30g fatAyr maliyet).</summary>
public record MarjRow(string Kategori, decimal Ciro, decimal Smm, decimal MarjPct);

/// <summary>E-ticaret kategori mix (JOKER, geçen ay).</summary>
public record EticKategoriRow(string Kategori, int Siparis, decimal NetCiro, int Adet);

/// <summary>Depo WMS günlük toplama verimi.</summary>
public record DepoWmsData(int BugunIslem, int BugunAdet, IReadOnlyList<DepoWmsTrend> Trend);
/// <summary>Depo WMS günlük trend satırı.</summary>
public record DepoWmsTrend(DateOnly Gun, int Islem, int Adet);

/// <summary>Envanter sayfası toplu veri.</summary>
public record InventoryData(
    decimal ToplamDeger,
    IReadOnlyList<DevirRow> Devir,
    IReadOnlyList<AbcClass> Abc,
    IReadOnlyList<MarkaRow> Marka,
    IReadOnlyList<StockoutRow> Stockout);
