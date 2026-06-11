namespace GmDashboard.Models;

/// <summary>Mağaza dönem satırı (EncoreMerkez Sales → posMagaza). Net = iade sign'lı.</summary>
public record StoreRow(int MekanId, decimal Net, int Fis, decimal Iade);

/// <summary>Mağaza kartı (hedef gerçekleşme + sepet dahil sunum modeli).</summary>
public record StoreCard(int MekanId, string Ad, decimal Net, int Fis, int Atv, decimal? GerPct, decimal Iade);

/// <summary>Dönem özeti (üst KPI bandı).</summary>
public record PeriodSummary(
    decimal Fiziksel, int Fis, decimal Iade, decimal Eticaret, int ESip, decimal Toplam,
    IReadOnlyList<StoreCard> Stores);
