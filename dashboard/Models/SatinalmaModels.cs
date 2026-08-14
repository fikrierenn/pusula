namespace GmDashboard.Models;

// Satınalma raporları modelleri — TEK dosya, rapor başına ayrı record/class.
// Yeni satınalma raporu → kendi modelini buraya ekle (SatinalmaXxxSatir), Queries'e GetXxxAsync,
// Pages/Satinalma/Xxx.razor (route /satinalma/xxx), NavRegistry "SATINALMA" section +1 satır.

/// <summary>
/// Hesap-sorma satırı — sorgular/2026-08-12-satinalma-hesap-DINAMIK.sql çekirdeğinin dashboard
/// emitter çıktısı (emitter-ayrımı). Kolonlar Excel/DINAMIK ile birebir; Dapper-map için boşluksuz
/// alias. Nullable: LEFT JOIN kaynaklı (stoklu/ilk-giriş) + hesap-tabansız (tük).
/// </summary>
public sealed class SatinalmaAnalizSatir
{
    public int UrunKodu { get; set; }
    public string UrunAd { get; set; } = "";
    public string Kategori { get; set; } = "";
    public string Grup1 { get; set; } = "";   // ürün tipi (Kat2: Silgiler/Kalemtıraşlar/Kalemler…)
    public string Marka { get; set; } = "";
    public int AlisAdet { get; set; }
    public int AlisTutar { get; set; }
    public decimal BirimMaliyet { get; set; }
    public int AyBasi { get; set; }
    public int AySonu { get; set; }
    public int Son12 { get; set; }
    public decimal Buyume { get; set; }
    public decimal? TukAy { get; set; }
    public decimal? TukBasit { get; set; }
    public int GySezon { get; set; }
    public int GySezonOnc { get; set; }   // önceki-yıl sezon (büyüme paydası — şeffaflık)
    public int Onc12 { get; set; }         // önceki 12 ay (yıllık-tier paydası — şeffaflık)
    public int RetailSon3 { get; set; }    // son 3 ay bulk-kırpılmış retail (momentum floor tabanı — şeffaflık)
    public int RetailSon12 { get; set; }   // son 12 ay bulk-kırpılmış retail (bulk-oran göstergesi)

    /// <summary>Bulk-kanal oranı: son12 satışının % kaçı toptan (retail-cap üstü). Yüksek → ürün toptan hareket ediyor,
    /// retail forecast toplam talebi eksik gösterir. 0 (tam retail) .. 1 (tam bulk).</summary>
    public double BulkOran => Son12 > 0 ? System.Math.Max(0, 1.0 - (double)RetailSon12 / Son12) : 0;
    /// <summary>Bulk-kanal ürünü mü — son12 anlamlı VE bulk-oran yüksek (≥%40).</summary>
    public bool BulkKanal => Son12 >= 50 && BulkOran >= 0.40;
    public int BeklenenSezon { get; set; }
    public int SezonKalan { get; set; }
    public int? StokluAy { get; set; }
    public decimal? AylikHiz { get; set; }
    public int SezonPay { get; set; }
    public string BuyumeKaynak { get; set; } = "";
    public int? IlkGirisAy { get; set; }
    public int SatisAy { get; set; }
    public string Karakter { get; set; } = "";
    public string Degerlendirme { get; set; } = "";

    /// <summary>Sezonluk bağlı para (donmuş sermaye) = sezon-sonrası-kalan × birim maliyet. Sadece fazla-ailesinde.
    /// Model'in linear donmuş'u (kap−yıllık) sezonsal üründe şişer; bu sezon-farkını kullanır (öncelik sıralaması).</summary>
    public decimal BagliPara => Grup is "FAZLA" or "UZUN-KUYRUK" or "KÜÇÜK-ALIM"
        ? System.Math.Max(0, SezonKalan) * BirimMaliyet
        : Grup == "ÖLÜ-ALIM" ? AySonu * BirimMaliyet : 0m;

    /// <summary>Değerlendirme'den emoji-siz grup etiketi (filtre + renk için). Prefix eşleme.</summary>
    public string Grup =>
        Degerlendirme.Contains("FAZLA") ? "FAZLA"
        : Degerlendirme.Contains("ÖLÜ") ? "ÖLÜ-ALIM"
        : Degerlendirme.Contains("YENİDEN-STOK") ? "YENİDEN-STOK"
        : Degerlendirme.Contains("TREND-HIZLI") ? "TREND-HIZLI"
        : Degerlendirme.Contains("KÜÇÜK-ALIM") ? "KÜÇÜK-ALIM"
        : Degerlendirme.Contains("UZUN-KUYRUK") ? "UZUN-KUYRUK"
        : Degerlendirme.Contains("AZ ALMIŞ") ? "AZ ALMIŞ"
        : Degerlendirme.Contains("İZLE") ? "İZLE"
        : Degerlendirme.Contains("NORMAL") ? "NORMAL"
        : Degerlendirme.Contains("GENÇ") ? "GENÇ"
        : "DİĞER";
}

// ── Ürün detay (drill /satinalma/urun/{stkID}) ──

/// <summary>Ürün başlığı + anlık fiziki stok (şube + depo WMS).</summary>
public sealed class SatinalmaUrunOzet
{
    public int UrunKodu { get; set; }
    public string UrunAd { get; set; } = "";
    public string Kategori { get; set; } = "";
    public string Marka { get; set; } = "";
    public int SubeStok { get; set; }
    public int DepoStok { get; set; }
    public string? ResimUrl { get; set; }   // bkmkitap CDN (ent.tsoft_urun.ImageUrl); yoksa null
    public int ToplamStok => SubeStok + DepoStok;
}

/// <summary>Alış faturası satırı — fatura-bazında (eID) toplanmış. eFirma→frm.frmAd tedarikçi.</summary>
public sealed class SatinalmaFaturaSatir
{
    public DateTime Tarih { get; set; }
    public string BelgeNo { get; set; } = "";
    public string Tedarikci { get; set; } = "";
    public int Adet { get; set; }
    public decimal Tutar { get; set; }
    public decimal Birim { get; set; }
}

/// <summary>Aylık satış — şube (irsHrk 1/4/100) + e-ticaret (JOKER) ayrık + toplam.</summary>
public sealed class SatinalmaAySatis
{
    public string Ay { get; set; } = "";     // 'YYYY-MM'
    public int Sube { get; set; }
    public int Etic { get; set; }
    public int Toplam => Sube + Etic;
}

/// <summary>Geçen-yıl sezon penceresinde şube-bazlı satış + o sezonda görülen max raf stoğu.
/// Kuru şube (MaxStok küçük) = satış "talep yok" değil "stok yok" → forecast tabanı eksik-sayım sinyali.</summary>
public sealed class SatinalmaSubeSezon
{
    public int Mekan { get; set; }
    public string Ad { get; set; } = "";
    public int Satis { get; set; }
    public int MaxStok { get; set; }
    /// <summary>Sezon boyunca raf ~boş (min-stok 3 altı) → o şubede satış imkânı yoktu.</summary>
    public bool Kuru => MaxStok < 3;
}
