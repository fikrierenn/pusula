namespace GmDashboard.Models;

/// <summary>Sınav sezonu KPI özeti — plan-35 B-155. Tutarlar KDV HARİÇ (<c>TotalPrice − VatTotal</c>);
/// <c>SalesProducts.TotalPrice</c> KDV DAHİL ve indirim sonrasıdır, doğrudan "net ciro" değildir.
/// İade (DocumentsTypeId=3) sign'lı düşülür. Fiş sayısı DEĞİL sipariş sayısı esas —
/// ping-pong (satış-iade-satış) fiş sayısını şişirir.</summary>
public sealed class SinavSezonKpi
{
    public int Siparis { get; set; }
    public int SatisFis { get; set; }
    public int IadeFis { get; set; }
    public decimal BrutKdvDahil { get; set; }
    public decimal Indirim { get; set; }
    public decimal NetKdvDahil { get; set; }
    public decimal Kdv { get; set; }
    public decimal NetKdvHaric { get; set; }
    public decimal IadeKdvHaric { get; set; }
    public int KismiSiparis { get; set; }
    public int CeliskiSiparis { get; set; }

    /// <summary>Sipariş başına ortalama sepet (KDV hariç). Payda sipariş, fiş DEĞİL.</summary>
    public decimal OrtSepet => Siparis > 0 ? NetKdvHaric / Siparis : 0m;

    /// <summary>İade / brüt satış oranı (KDV hariç). Kasa düzeltmesi de içerir — İade Radarı ayırır.</summary>
    public decimal IadeOraniYuzde => NetKdvHaric + IadeKdvHaric > 0
        ? 100m * IadeKdvHaric / (NetKdvHaric + IadeKdvHaric) : 0m;
}

/// <summary>Ödeme durumu — kalem kapsamı ekseni. Kaynak <c>snv.SiparisDetay.OdemesiYapildi</c> (kalem bazlı).
/// <c>snv.Siparis.Odendi</c> bit'i KISMİYİ TAM SANIYOR ve tarihçe tutmaz → durum buradan TÜRETİLİR,
/// flag yalnız denetim için taşınır (<c>FlagOdendi</c>).</summary>
public sealed class SinavOdemeDurum
{
    public string Durum { get; set; } = "";
    public int Siparis { get; set; }
    public int Kalem { get; set; }
    public int OdenmemisKalem { get; set; }
    public int FlagOdendi { get; set; }

    /// <summary>⚠ SİPARİŞ bazlı ciro — KPI şeridindeki FİŞ bazlı ciroyla AYNI DEĞİL.
    /// Buradaki payda yalnız <c>Kalem &gt; 0</c> olan siparişler; ayrıca her siparişin TÜM dönemlerdeki
    /// fişleri toplanır. UI'da "sipariş bazlı" etiketiyle gösterilir, KPI ile karşılaştırılmaz.</summary>
    public decimal NetKdvHaric { get; set; }

    /// <summary>Flag ile türetilmiş durum çelişiyor mu — kaç sipariş yanlış işaretli.</summary>
    public int Celiski => Durum switch
    {
        "TAM_ODENDI" => Siparis - FlagOdendi,   // tam ödendi ama flag 0
        _ => FlagOdendi,                        // kısmi/hiç ödenmedi ama flag 1
    };

    public string Etiket => Durum switch
    {
        "TAM_ODENDI" => "Tam ödendi",
        "KISMI_ODENDI" => "Kısmi ödendi",
        "HIC_ODENMEDI" => "Hiç ödenmedi",
        _ => Durum,
    };
}

/// <summary>Ödenmemiş sipariş kalemi (tahsilat/tedarik listesi). Tutar <c>snv.SinavUrun.Fiyat</c>'tan —
/// <c>SiparisDetay.BirimFiyat</c> pratikte NULL. <c>StokIstYolu</c> negatif/0 ise tedarik açığı,
/// pozitifse ürün rafta ama kasadan geçmemiş (tahsilat açığı).</summary>
public sealed class SinavEksikKalem
{
    public string SiparisKod { get; set; } = "";
    public DateTime? SiparisTarih { get; set; }
    public string Kampus { get; set; } = "";
    public string Ilce { get; set; } = "";
    public string Sinif { get; set; } = "";
    public int OgrenciId { get; set; }
    public int Kalem { get; set; }
    public int OdenmisKalem { get; set; }
    public int OdenmemisKalem { get; set; }
    public int StokId { get; set; }
    public string Urun { get; set; } = "";
    public string Kategori { get; set; } = "";
    public int Adet { get; set; }
    public decimal BirimFiyat { get; set; }
    public decimal StokIstYolu { get; set; }

    public decimal Tutar => Adet * BirimFiyat;
    public bool StokVar => StokIstYolu > 0;
    public string Sebep => StokVar ? "Tahsilat" : "Tedarik";
}

/// <summary>Sepet kovası — Paket / Kıyafet / Yan ürün. Ayraç KATEGORİ DEĞİL sipariş kapsamı:
/// kalem o siparişin <c>snv.SiparisDetay</c>'ında varsa PAKET. Kıyafet (urnKtgr2ID 13/18) sipariş
/// kapsamı dışı ama zorunlu üniforma → ayrı kova; "isteğe bağlı sepet büyütme" sayılmaz.</summary>
public sealed class SinavKova
{
    public string Kova { get; set; } = "";
    public int Satir { get; set; }
    public decimal Adet { get; set; }
    public decimal NetKdvDahil { get; set; }
    public decimal Kdv { get; set; }
    public decimal NetKdvHaric { get; set; }
    public decimal PayYuzde { get; set; }

    public string Etiket => Kova switch
    {
        "PAKET" => "Sınav paketi",
        "KIYAFET" => "Kıyafet",
        "YAN" => "Yan ürün",
        _ => Kova,
    };
}

/// <summary>Yan ürün attach (ek ciro efekti) özeti — kaç fişte sipariş dışı ürün eklenmiş.</summary>
public sealed class SinavAttach
{
    public int Fis { get; set; }
    public int YanUrunluFis { get; set; }
    public int KiyafetliFis { get; set; }
    public decimal YanKdvHaric { get; set; }
    public decimal KiyafetKdvHaric { get; set; }
    public decimal ToplamKdvHaric { get; set; }

    public decimal AttachYuzde => Fis > 0 ? 100m * YanUrunluFis / Fis : 0m;
    public decimal FisBasiYanCiro => YanUrunluFis > 0 ? YanKdvHaric / YanUrunluFis : 0m;
    public decimal SiparisDisiPayYuzde => ToplamKdvHaric > 0
        ? 100m * (YanKdvHaric + KiyafetKdvHaric) / ToplamKdvHaric : 0m;
}

/// <summary>İade fişi — orijinal Sınav fişine <c>Sales.LinkedDocumentId</c> ile bağlı.
/// <c>snv.SinavSiparisFisEncore</c> iadelerin %43'ünü kaçırır (kısmi iadeler FE'ye yazılmıyor) →
/// doğru köprü LinkedDocumentId. Aynı gün + aynı Z + kısa süre = KASA DÜZELTMESİ, ekonomik iade değil.</summary>
public sealed class SinavIade
{
    public long IadeFisId { get; set; }
    public DateTime IadeTarih { get; set; }
    public string IadeBelgeNo { get; set; } = "";
    public string Zno { get; set; } = "";
    public string Kasa { get; set; } = "";
    public int Magaza { get; set; }
    public long OrijinalFisId { get; set; }
    public DateTime OrijinalTarih { get; set; }
    public string SiparisKod { get; set; } = "";
    public int GunFarki { get; set; }
    public string FeDurumu { get; set; } = "";
    public decimal IadeKdvHaric { get; set; }
    public decimal OrijinalKdvDahil { get; set; }
    public string IadeTipi { get; set; } = "";
    public string Zno_Orijinal { get; set; } = "";

    /// <summary>Kasa düzeltmesi mi gerçek iade mi — aynı gün + aynı Z + ≤60 dk ise düzeltme.</summary>
    public string Yorum =>
        GunFarki == 0 && Zno == Zno_Orijinal ? "Kasa düzeltmesi" : "Gerçek iade";
}

/// <summary>Sınav dönemi (dropdown). <c>DonemId</c> hardcode YASAK — ne sabit ID (8 sabitlemek
/// dönem 7'nin 8.998 fişini görünmez yapar) ne sabit liste (dönem 9 açılınca eklemek gerekirdi).
/// Kaynak <c>snv.Donem</c> tablosu: tanımlı + siparişi olan dönemler DİNAMİK listelenir.
/// Tanımsız <c>DonemId</c> (−7 / −8 orphan kayıtları) tabloda karşılığı olmadığı için otomatik düşer.</summary>
public sealed class SinavDonem
{
    public int DonemId { get; set; }
    public string DonemAciklama { get; set; } = "";
    public int Siparis { get; set; }
    public int Fis { get; set; }
    public DateTime? Ilk { get; set; }
    public DateTime? Son { get; set; }

    /// <summary>Encore fişi olan dönem = panelin ciro/iade bölümleri dolu gelir.
    /// Fişsiz dönem (Encore öncesi, `snv.SiparisFis` EAR/EFA köprüsünde) sipariş gösterir ama ciro göstermez.</summary>
    public bool FisVar => Fis > 0;

    public string Etiket
    {
        get
        {
            var ad = string.IsNullOrWhiteSpace(DonemAciklama) ? $"Dönem {DonemId}" : $"{DonemAciklama} (D{DonemId})";
            return FisVar ? ad : $"{ad} — fiş yok";
        }
    }
}
