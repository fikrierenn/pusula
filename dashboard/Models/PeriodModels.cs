namespace GmDashboard.Models;

/// <summary>Mağaza dönem satırı (EncoreMerkez Sales → posMagaza). Net = iade sign'lı.</summary>
public record StoreRow(int MekanId, decimal Net, int Fis, decimal Iade);

/// <summary>Mağaza kartı (hedef gerçekleşme + sepet + kategori drill + WoW trend).</summary>
public record StoreCard(int MekanId, string Ad, decimal Net, int Fis, int Atv, decimal? GerPct, decimal Iade,
    IReadOnlyList<CategorySlice> Kategori, decimal? Wow = null);

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

/// <summary>Kargo performansı: firma × adet × çıkış (takvim+iş günü) × teslim gün (dönem).</summary>
public record KargoPerf(string Kargo, int Adet, decimal? CikisTakvim, decimal? CikisIsGunu, decimal? TeslimGun);

// İl teslimat (B-41): şehir × adet × çıkış (CikisTakvim=müşteri algısı, CikisIsGunu=depo gerçek) × teslim. Çıkış (SENDDATE) dönemi.
public record IlTeslimat(string Sehir, int Adet, decimal CikisTakvim, decimal CikisIsGunu, decimal TeslimGun);

// Aylık çıkış trendi (B-41): ay × sipariş × çıkış takvim+iş günü. Son 13 ay sabit. AyKod=YYYYMM (gün drill için).
public record AyKargo(int AyKod, string Ay, int Siparis, decimal CikisTakvim, decimal CikisIsGunu);

// Gün çıkış detayı (B-41 drill): aya tıkla → o ayın günleri. gün × sipariş × çıkış takvim+iş günü.
public record GunKargo(string Gun, int Siparis, decimal CikisTakvim, decimal CikisIsGunu);

// Kapıda ödeme (COD) özeti (B-41): PAYDEFREF=-3. İade maliyeti = 2×kargo (BKM yutar). SENDDATE dönemi.
public record CodOzet(int Siparis, int Teslim, int Iade, decimal IadeOran, decimal KapidaBedel, decimal IadeMaliyet);

/// <summary>Bekleyen gün bucket'ı (kargoya çıkmamış sipariş yaşı; anlık).</summary>
public record BekleyenBucket(string Bucket, int Adet);

/// <summary>Mağaza hedef-gerçekleşen satırı (MTD net × aylık hedef × gerçekleşme %).</summary>
public record HedefMagaza(int MekanId, string Ad, decimal Net, decimal Hedef, decimal? GerPct);

/// <summary>Kategori hedef-gerçekleşen satırı (MTD net × aylık hedef × gerçekleşme %).</summary>
public record HedefKategori(string Ad, decimal Net, decimal Hedef, decimal? GerPct);

/// <summary>Günlük kargo çıkış dağılımı (sipariş→kargo gün farkı × paket adedi).</summary>
public record KargoGun(int Gun, int Adet);

/// <summary>Dönem özeti (tüm üst paneller). Prev* = bir önceki eş-uzunluk dönem (hero WoW trendi).</summary>
public record PeriodSummary(
    decimal Fiziksel, int Fis, decimal Iade, decimal Eticaret, int ESip, decimal Toplam,
    IReadOnlyList<StoreCard> Stores,
    IReadOnlyList<CategorySlice> Kategori,
    IReadOnlyList<EticChannel> Etic,
    IReadOnlyList<HourBar> Saat,
    IReadOnlyList<KasiyerRow> Kasiyer,
    IReadOnlyList<NameCount> Kargo,
    IReadOnlyList<NameCount> Il,
    decimal PrevFiziksel = 0, int PrevFis = 0, decimal PrevIade = 0, decimal PrevEticaret = 0, int PrevESip = 0);
