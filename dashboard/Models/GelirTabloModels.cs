namespace GmDashboard.Models;

/// <summary>Ayrıntılı Gelir Tablosu — ham detay satır (hesap bazlı, signed fisTutar). P&L hiyerarşisi C#'ta kurulur.</summary>
/// <param name="Bolum">P&L bölümü: NETSATIS · GIDER · FINANSMAN · DIGERGELIR · DIGERGIDER · KKEG</param>
/// <param name="Kategori">GIDER için .YY kategori adı (İşçi Ücret…); diğerlerinde bölüm adı.</param>
public sealed record GelirDetay(string Bolum, string Kategori, string HspKod, string HspAd, decimal Tutar);
