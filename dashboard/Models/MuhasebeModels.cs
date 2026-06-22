namespace GmDashboard.Models;

/// <summary>Kapanış-sonrası müdahale ÖZET satırı (bkm.sp_KapanisMudahaleKontrol_v2 @Mod='OZET').
/// Donem = "AA.YYYY". Drill için C# tarafında Ay/Yıl'a parçalanır.</summary>
public record KontrolOzetRow(
    string Donem, string Kaynak, string? GiderKod, string? GiderAd,
    int EvrakAdet, decimal ToplamTutar, int MaxGunSonra,
    int SonradanDegAdet, int GecGirisAdet, int YuvarlakAdet, int MukerrerAdet, int GirenOnayAyniAdet,
    int MaxRiskSkor, int ToplamRiskSkor);

/// <summary>Kapanış-sonrası müdahale DETAY satırı (@Mod='DETAY'). Giren/Onaylayan = drn1.insAd.</summary>
public record KontrolDetayRow(
    string Donem, string Kaynak, long EvrakID, string EvrakNo,
    string BelgeTarihi, string KapanisTarihi, string DegisimTarihi,
    bool GecGiris, bool SonradanDeg, int GunSonra, int Severity,
    bool YuvarlakTutar, bool GirenOnaylayanAyni, bool Mukerrer, int RiskSkor,
    string? GiderKod, string? GiderAd, string? KarsiKod,
    string? Giren, string? Onaylayan, decimal Tutar, string? Notu);
