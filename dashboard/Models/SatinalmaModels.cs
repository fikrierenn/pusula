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
    // === plan-34 B-143 RATCHET (sistematiklik) ===
    public int RatchetAlimAy { get; set; }      // ratchet penceresinde kaç ay alım yapıldı (ay0 dahil)
    public int RatchetAlimSon3 { get; set; }    // son 3 ay alım adedi
    public int RatchetAlimOnc3 { get; set; }    // önceki 3 ay alım adedi
    public int RatchetSatisSon3 { get; set; }   // son 3 ay satış (ay0 hariç — #aylik grain'i)
    public int RatchetSatisOnc3 { get; set; }   // önceki 3 ay satış

    /// <summary>SİSTEMATİK AŞIRI-ALIM (çekirdekte hesaplanır): ≥3 ayda alım VE stok basit-kapsamı eşik ayı aşıyor.
    /// GENÇ muafiyetinden bağımsız — 5 ayda 7 sipariş + 100 ay kapsam 'yargı için erken' değildir (Serve Deep HP vakası).
    /// Sinyal-vs-gürültü: tek kötü ay gürültü, tekrar eden desen sinyal.</summary>
    public bool Ratchet { get; set; }
    /// <summary>TERS MOMENTUM: sipariş artarken satış düşüyor. Tek başına suçlama DEĞİL — sistematikliğin yönünü gösterir.</summary>
    public bool RatchetTers { get; set; }

    /// <summary>Sinyal şiddeti (sıralama): sattığının kaç katını alıyor (son 3 ay). Ratchet değilse 0.</summary>
    public double RatchetSkor => !Ratchet ? 0
        : RatchetSatisSon3 > 0 ? (double)RatchetAlimSon3 / RatchetSatisSon3
        : RatchetAlimSon3 > 0 ? 99.0 : 0;

    // === plan-34 B-144 KARŞI-METRİK (ters teşvik dengesi) ===
    public int KayipAdet { get; set; }          // bulunurluk kaybı: stok yokken tahmini kaçan adet
    public int KuruSube { get; set; }           // kaç şubede stok yok
    /// <summary>Stockout sinyali var mı — 'az al' davranışının maliyeti. FAZLA cezasının karşı-ağırlığı.</summary>
    public bool Stockout => KayipAdet > 0;

    // === plan-34 İADE HAKKI (parametre) ===
    /// <summary>Bu ayın alımı iade-hakkı sayılan tedarikçiden mi (Ayarlar'daki frmIadeKural kodları).
    /// TRUE → fazla stok geri çevrilebilir, DONMUŞ SERMAYE SAYILMAZ; 'fazla aldı' iddiası bu satırda zayıflar.</summary>
    public bool IadeHakki { get; set; }

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
    public decimal BagliPara => IadeHakki ? 0m      // plan-34: iade edilebilir stok donmuş sermaye değil (Ayarlar'da kod girilmişse)
        : Grup is "FAZLA" or "UZUN-KUYRUK" or "KÜÇÜK-ALIM"
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

/// <summary>Toptan/bulk satış hareketi (retail-cap üstü tek hareket) — TOPTAN KANAL drill.</summary>
public sealed class SatinalmaBulkHareket
{
    public DateTime Tarih { get; set; }
    public int Mekan { get; set; }
    public string MekanAd { get; set; } = "";
    public int Adet { get; set; }
    public string EvrakNo { get; set; } = "";   // irs.eNo — depo sevk (D01…) gerçek belge; POS'ta "POS Satış"
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

/// <summary>plan-34 B-145 — fiyat sapması satırı: aynı ürün, farklı tedarikçi, farklı birim fiyat.
/// FazlaOdenen = en ucuz tedarikçiye göre fazladan ödenen tutar (yalnız kıyasa giren faturalar).</summary>
public sealed class FiyatSapmaRow
{
    public int UrunKodu { get; set; }
    public string UrunAd { get; set; } = "";
    public string Kategori { get; set; } = "";
    public string Marka { get; set; } = "";
    public int TedarikciSayi { get; set; }
    public int ToplamAdet { get; set; }
    public decimal EnAzBirim { get; set; }
    public decimal EnCokBirim { get; set; }
    public decimal FarkPct { get; set; }
    public decimal FazlaOdenen { get; set; }
    public string EnAzTedarikci { get; set; } = "";
    public string EnCokTedarikci { get; set; } = "";
    public string? EnCokSonTarih { get; set; }
    /// <summary>en pahalı/en ucuz > 10× → aynı satılabilir birim değil (paket/koli/bundle farkı ya da jenerik SKU).
    /// Aşırı-ödeme KANITI SAYILMAZ; ayrı kovaya alınır (overclaim yasağı).</summary>
    public bool OlcekSuphesi { get; set; }
    /// <summary>Kıyasın uçlarından biri GRUP-İÇİ / ilişkili taraf. Fark alıcı hatası değil, transfer fiyatlaması —
    /// manşet 'fazla ödenen' toplamına KATILMAZ, ayrı gösterilir (haksız atıf önlemi).</summary>
    public bool IliskiliTaraf { get; set; }
}

/// <summary>plan-34 B-146 — atıf satırı: kullanıcı (birleştirilmiş) × şube öneri-sapması.
/// TÜM göstergeler ORAN; mutlak talep/adet ile kişi kıyası YASAK (benimseme asimetriği).</summary>
public sealed class AtifRow
{
    public string Kullanici { get; set; } = "";
    public int MekanId { get; set; }
    public string SubeAd { get; set; } = "";
    public int Talep { get; set; }          // payda — kıyas ölçüsü DEĞİL
    public int AktifGun { get; set; }
    public int Urun { get; set; }
    public int OneriEslesen { get; set; }
    public int Aynen { get; set; }
    public int Fazla { get; set; }
    public int Az { get; set; }
    public int Onayli { get; set; }
    public decimal? OrtSapmaYuzde { get; set; }   // satır oranları [-100,+200] kırpılmış ortalama (uç satır sürüklemesin)
    public int UcSapma { get; set; }              // sapması +200%'ü aşan talep sayısı (kırpma şeffaflığı)

    /// <summary>Öneri motoruyla eşleşme oranı — veri kalitesi (düşükse alttaki oranlar şüpheli).</summary>
    public decimal EslesmeOran => Talep > 0 ? 100m * OneriEslesen / Talep : 0;
    /// <summary>Öneriyi AYNEN kabul oranı. %100'e yakın = öneri motorunu onaylıyor (karar değil onay).</summary>
    public decimal AynenOran => OneriEslesen > 0 ? 100m * Aynen / OneriEslesen : 0;
    /// <summary>ÖNERİDEN FAZLA isteme oranı — ana atıf sinyali (aşırı-alım yönü).</summary>
    public decimal FazlaOran => OneriEslesen > 0 ? 100m * Fazla / OneriEslesen : 0;
    /// <summary>Öneriden AZ isteme oranı — karşı yön (stockout riski üretir).</summary>
    public decimal AzOran => OneriEslesen > 0 ? 100m * Az / OneriEslesen : 0;
    /// <summary>Onay oranı — KONTROL katmanı (Ekleyen=karar, Onaylayan=kontrol ayrımı).</summary>
    public decimal OnayOran => Talep > 0 ? 100m * Onayli / Talep : 0;
    /// <summary>Aktif güne normalize günlük talep yoğunluğu — 358 talep/1 gün ile 29.253/131 günü ayırır.</summary>
    public decimal GunlukTalep => AktifGun > 0 ? Math.Round((decimal)Talep / AktifGun, 1) : 0;
    /// <summary>Tek-seferlik toplu iş mi (≤2 aktif gün) — süreklilik yoksa oranlar davranışı temsil etmez.</summary>
    public bool TekSeferlik => AktifGun <= 2;
}

/// <summary>plan-34 B-153 — SATINALMA tarafı atıf satırı. Mağaza talebinden AYRI eksen:
/// mağaza "ne istediğine", satınalma "dış tedarikçiden ne kadar / kimden aldığına" hesap verir.
/// Kaynak: dbo.sip eTip 0 (Alış) + 3 (Yerel Alım) — eTip 13 Depo→Mağaza ve 9 Alış İade Emri BURAYA GİRMEZ.</summary>
public sealed class SatinalmaAtifRow
{
    public int InsId { get; set; }
    public string Kisi { get; set; } = "";
    public int Siparis { get; set; }
    public int AktifGun { get; set; }
    public int Tedarikci { get; set; }
    public int Urun { get; set; }
    public long SiparisAdet { get; set; }
    public int GrupIciSiparis { get; set; }
    public long KarsilananAdet { get; set; }

    /// <summary>Aktif güne normalize sipariş yoğunluğu.</summary>
    public decimal SiparisGun => AktifGun > 0 ? Math.Round((decimal)Siparis / AktifGun, 1) : 0;
    /// <summary>Sipariş başına ortalama kalem-adedi (parti büyüklüğü göstergesi).</summary>
    public decimal AdetSiparis => Siparis > 0 ? Math.Round((decimal)SiparisAdet / Siparis, 0) : 0;
    /// <summary>Grup-içi (ilişkili taraf) sipariş oranı — transfer fiyatlaması ayrımı, dış tedarikçi kararı değil.</summary>
    public decimal GrupIciOran => Siparis > 0 ? 100m * GrupIciSiparis / Siparis : 0;
    /// <summary>KARŞILANMA ORANI = irsaliyeye bağlanan adet / sipariş adedi. Düşükse: tedarikçi teslim etmedi
    /// VEYA sipariş gerçekçi değildi. Tedarikçi başarısızlığı ile alıcı hatasını AYIRMAK için tedarikçi kırılımı şart.</summary>
    public decimal KarsilanmaOran => SiparisAdet > 0 ? Math.Round(100m * KarsilananAdet / SiparisAdet, 1) : 0;
}
