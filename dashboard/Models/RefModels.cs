namespace GmDashboard.Models;

/// <summary>RFM müşteri segmenti (yazarkasa veya e-ticaret kanalı).</summary>
public record RfmSegment(string Segment, int Musteri, decimal Ciro);

/// <summary>Drill: segmentteki tekil müşteri (ad/telefon + RFM metrikleri).</summary>
public record CustomerRow(long Id, string Ad, string Tel, int Frq, decimal Mon, int Rec);

/// <summary>Drill katman 3: müşteri fiş/sipariş satırı. Ref = fiş Id (YK) / ORDERID (ET). Tutar KDV-hariç. plan-17.</summary>
public record FisRow(string Tarih, string Ref, int Kalem, decimal Tutar);

/// <summary>Aylık yeni müşteri kazanımı (ilk fiş tarihi o ayda). plan-17.</summary>
public record MusteriKazanim(string Ay, int Yeni);

/// <summary>Mağaza kart-fiş oranı (kaç fişin kaçı müşteri-kartlı). plan-17.</summary>
public record MagazaKart(string Magaza, int Fis, int Kartli, decimal Oran);

/// <summary>Müşteri istatistik özeti (kazanım serisi + mağaza kart oranı + toplam). plan-17.</summary>
public record MusteriStat(IReadOnlyList<MusteriKazanim> Kazanim, IReadOnlyList<MagazaKart> KartOran,
    int ToplamFis, int ToplamKartli);

/// <summary>Drill katman 4: fiş içeriği ürün satırı (tam fiş — brüt/indirim/net). Hepsi KDV-hariç. plan-17.
/// Brüt = liste, İndirim = uygulanan, Net = ödenen ciro (Brüt−İndirim). Birim = Brüt/Adet.</summary>
public record FisIcerikRow(string Ad, decimal Adet, decimal Brut, decimal Indirim, decimal Net, string? Kampanya);

/// <summary>Drill: kategorideki tekil ürün. Satis/Ciro = seçili dönem; S30/S90/S360 = bugünden geriye
/// trailing pencere satış adedi (kaç-gün-yeter). StokFsm/Ozl/Ist/Depo = anlık stok dağılımı (stokSonAltDepo_vw).
/// Bakiye = seçili kapsamdaki şube stoğu (cover hesabı için).</summary>
public record UrunRow(string Kod, string Ad, int Satis, decimal Ciro, int Bakiye, int S30, int S90, int S360,
    int StokFsm, int StokOzl, int StokIst, int StokDepo, int StokOdak, int YasGun);

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

/// <summary>E-ticaret kategori drill — kategori altındaki ürünler (sipariş/adet/net ciro).</summary>
public record EticKategoriUrunRow(string Urun, int Siparis, int Adet, decimal NetCiro);

/// <summary>E-ticaret kategori × ay (mevcut yıl) — yığılmış grafik için ham satır.</summary>
public record EticKategoriAyRow(int Ay, string Kategori, decimal NetCiro);

/// <summary>E-ticaret sipariş durum dağılımı (funnel aşaması, geçen ay).</summary>
public record EticFunnelRow(string Asama, int Siparis, decimal ToplamCiro);

/// <summary>Win-back hedef müşteri (son 365g aktif, son 90g yok).</summary>
public record WinBackRow(string Ad, string Tel, string Kart, int Frq, decimal ToplCiro, int GunIdle);

/// <summary>Müşteri konsantrasyonu Pareto dilimi (%10'ar, son 12 ay).</summary>
public record ParetoRow(int Dilim, int MusteriSayisi, decimal ToplamCiro);

/// <summary>Kartlı vs kartsız fiş karşılaştırması (B-69; B-102: perakende fiş, anonim kartsız dahil, sepet/fiş).</summary>
public record KartliRow(string Tip, int FisSayisi, int Musteri, decimal NetCiro, decimal AtvFis);

/// <summary>Tekrar alış özeti — toplam, tekrar eden, ortalama 2. alış günü (B-58+B-71).</summary>
public record TekrarAlisOzet(int ToplamMusteri, int TekrarMusteri, decimal OrtGun2Alis);

/// <summary>RFM segment geçiş (dönem1→dönem2, B-67).</summary>
public record RfmGecisRow(string EskiSeg, string YeniSeg, int Musteri);

/// <summary>Hediye çeki aylık satılan/kullanılan.</summary>
public record HcAyRow(string Ay, decimal SatilanTL, decimal KullanilanTL);
/// <summary>Hediye çeki yükümlülük özeti.</summary>
public record HcOzet(decimal ToplamSatilan12Ay, decimal ToplamKullanilan12Ay, IReadOnlyList<HcAyRow> Aylar);

/// <summary>Marka alış-satış rotasyon satırı (geçen ay).</summary>
public record MarkaRotasyonRow(string Marka, int SatisAdet, int AlisAdet, decimal SatisCiro);

/// <summary>Depo WMS günlük toplama verimi.</summary>
public record DepoWmsData(int? BugunIslem, int? BugunAdet, IReadOnlyList<DepoWmsTrend> Trend);
/// <summary>Depo WMS günlük trend satırı.</summary>
public record DepoWmsTrend(DateTime Gun, int Islem, int Adet);

/// <summary>Envanter sayfası toplu veri.</summary>
public record InventoryData(
    decimal ToplamDeger,
    IReadOnlyList<DevirRow> Devir,
    IReadOnlyList<AbcClass> Abc,
    IReadOnlyList<MarkaRow> Marka,
    IReadOnlyList<StockoutRow> Stockout);
