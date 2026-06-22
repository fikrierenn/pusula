namespace GmDashboard.Models;

/// <summary>Gradient hero carousel KPI kartı (AppKpiCarousel). Gradient = DaisyUI token sınıfı (ör. "from-primary to-primary/80").</summary>
public record KpiCardData(string Label, string Value, string Gradient, string Sub, Microsoft.AspNetCore.Components.EventCallback OnClick = default);

/// <summary>Bildirim merkezi uyarısı. Ico=lucide adı; Tone=error|warning|success.</summary>
public record AlertItem(string Ico, string Tone, string Title, string Desc);

/// <summary>Aylık net ciro noktası (irsHrk, KDV-hariç). Ay = "yyyy-MM".</summary>
public record AylikNokta(string Ay, decimal Net);

/// <summary>Hedef tahmin sonucu (B-73). YoY taban × son-3-ay YoY ivmesi + senaryo bandı.
/// Yetersiz veri (YoY yok) → Yeterli=false. Mtd = tahmin ayının şu ana kadarki gerçekleşmesi.
/// plan-14: Gelecek/Gecmis = hedef ay bugüne göre konumu. Gercek = geçmiş ay tam gerçekleşme (varsa).
/// Carpan = uygulanan takvim etmen çarpanı (1.0 = etmen kapalı/etkisiz).</summary>
public record TahminSonuc(string TahminAy, decimal YoYTaban, decimal IvmePct, decimal Tahmin,
    decimal Alt, decimal Ust, decimal Mtd, decimal? MtdPace, bool Yeterli,
    IReadOnlyList<AylikNokta> Seri,
    bool Gelecek = false, bool Gecmis = false, decimal? Gercek = null, decimal Carpan = 1m);

/// <summary>Kategori bazlı YoY MTD karşılaştırma (bu ay MTD vs geçen yıl aynı MTD). plan-13.</summary>
public record TahminKategori(string Ad, decimal MtdBuYil, decimal MtdGecenYil, decimal? YoyPct);

/// <summary>Mağaza tahmin satırı — PersistentComponentState için ValueTuple yerine.</summary>
public record TahminMagazaItem(string Ad, TahminSonuc T);

/// <summary>Kaydedilmiş tahmin (plan-14). data/tahmin-kayitlari.json. MekanId 0=toplam.
/// Carpan = kayıt anında uygulanan takvim çarpanı (1.0 = etmensiz).</summary>
public record TahminKayitEntry(string Id, int Year, int Month, int MekanId,
    decimal Tahmin, decimal Alt, decimal Ust, decimal IvmePct, decimal YoYTaban,
    decimal Carpan, string KayitTarih);

/// <summary>Kayıt vs gerçek karşılaştırma (plan-14). Gercek null = ay henüz tamamlanmadı.</summary>
public record TahminKarsilastirma(TahminKayitEntry Kayit, decimal? Gercek, decimal? SapmaPct);

/// <summary>Takvim günü (plan-14). Ulusal+dini API'den, okul elle JSON'dan.</summary>
public record TakvimGun(DateOnly Tarih, string Ad, TakvimTip Tip, bool YarimGun);
public enum TakvimTip { Ulusal, DiniBayram, OkulAcik, OkulKapali, Sinav }

/// <summary>Bir ay için hesaplanan takvim etmen özeti (plan-14). Çarpanlar deterministik.</summary>
public record AyEtmen(int HaftaSonuSayisi, int TatilKapaliGun, bool OkulAcik, bool SinavAyi,
    decimal HaftaSonuCarpan, decimal OkulCarpan, decimal BayramDuzeltme);

// --- Tahmin motoru (plan-15) çıktısı: scripts/forecast/ → data/forecast/*.json ---

/// <summary>Bir modelin ensemble katkısı (tahmin + ağırlık).</summary>
public record ForecastModelKatki(decimal Tahmin, decimal Agirlik);

/// <summary>Bir ay için motor tahmini: ensemble nokta/band + model katkıları + bileşen kırılımı (glm yorumu).</summary>
public record ForecastAy(int Yil, int Ay, decimal? Point, decimal? Alt, decimal? Ust,
    [property: System.Text.Json.Serialization.JsonPropertyName("model_sayisi")] int ModelSayisi,
    IReadOnlyList<string> Atlanan,
    IReadOnlyDictionary<string, ForecastModelKatki> Modeller,
    IReadOnlyDictionary<string, decimal> Bilesen);

/// <summary>tahmin-aylik.json kökü.</summary>
public record ForecastCikti(string Uretim,
    [property: System.Text.Json.Serialization.JsonPropertyName("seri_son")] string SeriSon,
    IReadOnlyList<ForecastAy> Aylar);

/// <summary>Bir yöntemin öğrenilen performansı (backtest).</summary>
public record ForecastYontem(decimal Wmape,
    [property: System.Text.Json.Serialization.JsonPropertyName("bias_pct")] decimal BiasPct,
    decimal Agirlik);

/// <summary>Ensemble band yüzdeleri + gözlemlenen MAPE.</summary>
public record ForecastBand(
    [property: System.Text.Json.Serialization.JsonPropertyName("alt_pct")] decimal AltPct,
    [property: System.Text.Json.Serialization.JsonPropertyName("ust_pct")] decimal UstPct,
    [property: System.Text.Json.Serialization.JsonPropertyName("ensemble_mape")] decimal EnsembleMape);

/// <summary>yontem-agirlik.json kökü (öğrenen katman şeffaflığı).</summary>
public record ForecastAgirlik(string Uretim,
    IReadOnlyDictionary<string, ForecastYontem> Modeller, ForecastBand Band);

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

/// <summary>Elle işaretlenmiş iç/mağaza kartı (plan-16 ek). RFM + müşteri analizlerinden hariç. CustomersId = EncoreMerkez/DerinCrm.</summary>
public record IcKart(long Id, string Ad, string KayitTarih);

/// <summary>Kasiyer + önceki döneme göre net değişim (B-57). DeltaPct null = önceki dönemde yok.</summary>
public record KasiyerDelta(string Magaza, string Ad, int Fis, decimal Net, int Atv, decimal? DeltaPct);

/// <summary>Saat×gün yoğunluk hücresi (B-55 heatmap). Gun: 0=Pzt..6=Paz (DATEDIFF%7). Fis = fiş adedi.</summary>
public record HeatCell(int Gun, int Saat, int Fis);

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

/// <summary>COD il bazlı iade oranı (B-56): coğrafi risk. PAYDEFREF=-3 + DCITY + CARGODELIVERYSTATUS=2.</summary>
public record CodIl(string Sehir, int Siparis, int Iade, decimal Oran);

/// <summary>Bekleyen gün bucket'ı (kargoya çıkmamış sipariş yaşı; anlık).</summary>
public record BekleyenBucket(string Bucket, int Adet);

/// <summary>B-111 WMS bekleyen doluluk — aşama split (anlık, SENDDATE NULL). Toplanma=raflanmayı bekleyen (en kritik).</summary>
public record BekleyenDurum(int ToplanmaBekleyen, int Hazirlanan, int TeminBekleyen)
{
    public int Toplam => ToplanmaBekleyen + Hazirlanan + TeminBekleyen;
}

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
