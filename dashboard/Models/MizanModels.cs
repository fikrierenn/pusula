namespace GmDashboard.Models;

/// <summary>Mizan ağaç düğümü — 3-haneli ana hesap → alt (100.10) → en alt/leaf (100.10.001). Excel hiyerarşisi.
/// Bakiye = Borç − Alacak (borç-pozitif). Kapanmış yılda "Kapanış" fişi hariç (kesin mizan).
/// Mutable: ağaç inşasında alt-toplamlar yukarı biriktirilir.</summary>
public sealed class MizanNode
{
    public required string Kod { get; init; }
    public required string Ad { get; set; }
    public int Seviye { get; init; }            // 1 = 3-haneli ana, 2 = alt, 3 = en alt
    public decimal Borc { get; set; }
    public decimal Alacak { get; set; }
    public decimal Bakiye => Borc - Alacak;
    public List<MizanNode> Cocuklar { get; } = [];
    public bool YaprakMi => Cocuklar.Count == 0;
}

/// <summary>Üst özet kartlar: nakit + cari + KDV + denge. Bilanço işaret konvansiyonu (varlık borç-pozitif, yükümlülük alacak-pozitif).</summary>
public record MizanOzet(
    decimal Nakit, decimal VerilenCek, decimal Alicilar, decimal Saticilar,
    decimal KdvIndirilecek, decimal KdvHesaplanan, decimal KdvNet,
    decimal ToplamBorc, decimal ToplamAlacak);

/// <summary>Mizan sayfası tek yükleme sonucu: özet kartlar + tam ağaç (3-haneli kök liste).</summary>
public record MizanSonuc(MizanOzet Ozet, IReadOnlyList<MizanNode> Agac);
