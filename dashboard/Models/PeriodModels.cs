namespace GmDashboard.Models;

/// <summary>Mağaza dönem satırı (EncoreMerkez Sales → posMagaza). Net = iade sign'lı.</summary>
public record StoreRow(int MekanId, decimal Net, int Fis, decimal Iade);

/// <summary>Mağaza kartı (hedef gerçekleşme + sepet + kategori drill).</summary>
public record StoreCard(int MekanId, string Ad, decimal Net, int Fis, int Atv, decimal? GerPct, decimal Iade,
    IReadOnlyList<CategorySlice> Kategori);

/// <summary>Kategori dilimi (mağaza×kategori aggregate → toplam).</summary>
public record CategorySlice(string Ad, decimal Ciro);

/// <summary>E-ticaret kanal (JOKER APPLICATION; net = iptal/iade hariç).</summary>
public record EticChannel(string Ad, int Sip, int Ipt, decimal Ciro);

/// <summary>Saat bazlı yoğunluk (DATEPART HOUR).</summary>
public record HourBar(int Saat, int Fis, decimal Net);

/// <summary>Kasiyer performansı (Sales.UsersId=Users.Id).</summary>
public record KasiyerRow(string Magaza, string Ad, int Fis, decimal Net, int Atv, int Iade);

/// <summary>14 gün trend noktası (fiziksel net, tarih).</summary>
public record TrendPoint(string Tarih, decimal Net);

/// <summary>E-ticaret kargo firma / il dağılımı (ad + sipariş adedi).</summary>
public record NameCount(string Ad, int Adet);

/// <summary>Kargo performansı: firma × adet × ortalama çıkış günü × ortalama teslim günü (dönem).</summary>
public record KargoPerf(string Kargo, int Adet, decimal? CikisGun, decimal? TeslimGun);

/// <summary>Bekleyen gün bucket'ı (kargoya çıkmamış sipariş yaşı; anlık).</summary>
public record BekleyenBucket(string Bucket, int Adet);

/// <summary>Dönem özeti (tüm üst paneller).</summary>
public record PeriodSummary(
    decimal Fiziksel, int Fis, decimal Iade, decimal Eticaret, int ESip, decimal Toplam,
    IReadOnlyList<StoreCard> Stores,
    IReadOnlyList<CategorySlice> Kategori,
    IReadOnlyList<EticChannel> Etic,
    IReadOnlyList<HourBar> Saat,
    IReadOnlyList<KasiyerRow> Kasiyer,
    IReadOnlyList<NameCount> Kargo,
    IReadOnlyList<NameCount> Il);
