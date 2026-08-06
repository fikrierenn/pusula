namespace GmDashboard.Models;

/// <summary>Gider Merkezi Dağılımlı Mizan — düz satır (hesap × gider merkezi). Pivot C#'ta kurulur.</summary>
public sealed record GiderMizanSatir(
    string Grup,        // ana hesap kodu (740/760/770/780…)
    string GrupAd,      // ana hesap adı (mhsAnaHsp)
    string HspKod,      // detay hesap kodu (740.30.001)
    string HspAd,       // detay hesap adı
    int MerkezId,       // frmID (0 = GENEL/dağıtılmamış)
    string MerkezAd,    // temizlenmiş merkez adı
    decimal Gider);     // Borç − Alacak (pozitif = gider)

/// <summary>Hücre drill — bir (hesap × merkez × dönem) arkasındaki tek yevmiye satırı.</summary>
public sealed record GiderMizanDetay(
    int FisId, int Sirket, int YevmiyeNo, string Tarih,
    string? Aciklama, decimal Tutar, int? FaturaEID, string? FaturaNo);
