namespace GmDashboard.Models;

/// <summary>Mizan ana-hesap satırı (3-haneli grup). Bakiye = Borç − Alacak (borç-pozitif).
/// Kaynak: mhs.mhsMizan_vw (Borc/Alacak hazır), fisSirketID = yıl−2020. Açılış/devir dahil → gerçek bakiye.</summary>
public record MizanRow(string AnaKod, string? AnaAd, decimal Borc, decimal Alacak, decimal Bakiye, int AltAdet);

/// <summary>Mizan drill: bir ana hesabın alt hesapları (tam hspKod + ad).</summary>
public record MizanDetayRow(string HspKod, string? HspAd, decimal Borc, decimal Alacak, decimal Bakiye);

/// <summary>Üst özet kartlar: nakit pozisyon + cari + KDV + denge. Bilanço hesabı işaret konvansiyonu:
/// varlık (nakit/alıcı) borç-bakiye pozitif; yükümlülük (satıcı) alacak-bakiye pozitif gösterilir.</summary>
public record MizanOzet(
    decimal Nakit,            // 100+101+102+108 borç bakiyesi (103 verilen çek HARİÇ — kontra hesap)
    decimal VerilenCek,       // 103 alacak bakiyesi (pozitif = verilen çek/ödeme emri yükümlülüğü)
    decimal Alicilar,         // 120 borç bakiyesi (net alacak)
    decimal Saticilar,        // 320 alacak bakiyesi (net borç) — pozitif = ödenecek
    decimal KdvIndirilecek,   // 191 borç bakiyesi
    decimal KdvHesaplanan,    // 391 alacak bakiyesi
    decimal KdvNet,           // Hesaplanan − İndirilecek (pozitif = ödenecek, negatif = devreden)
    decimal ToplamBorc,       // mizan denge: toplam borç
    decimal ToplamAlacak);    // = toplam alacak (çift-taraflı invariant)
