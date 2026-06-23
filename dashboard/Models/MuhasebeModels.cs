namespace GmDashboard.Models;

/// <summary>Kapanış-sonrası müdahale ÖZET satırı (bkm.sp_KapanisMudahaleKontrol_v2 @Mod='OZET').
/// Donem = "AA.YYYY". Drill için C# tarafında Ay/Yıl'a parçalanır.</summary>
public record KontrolOzetRow(
    string Donem, string Kaynak, string? GiderKod, string? GiderAd,
    int EvrakAdet, decimal ToplamTutar, int MaxGunSonra,
    int SonradanDegAdet, int GecGirisAdet, int YuvarlakAdet, int MukerrerAdet, int GirenOnayAyniAdet,
    int MaxRiskSkor, int ToplamRiskSkor);

/// <summary>Ay kapanış kaydı (bkm.Fin_AyKapanis) — Ayarlar formu satırı. Kontrol panelinin tarama dönemini belirler.</summary>
public record KapanisDonem(int DonemYil, int DonemAy, DateTime KapanisDT, string? Aciklama, DateTime KayitDT);

/// <summary>Yevmiye fişi tek satırı (mhsFis × mhsHsp). Borç=fisBA1(-fisTutar) / Alacak=fisBA0(fisTutar).</summary>
public record YevmiyeFisSatir(string HspKod, string HspAd, string? Aciklama, decimal Borc, decimal Alacak);

/// <summary>Yevmiye fişi (başlık + satırlar) — Kontrol DETAY evrak drill'i. fisbID ile.</summary>
public record YevmiyeFis(int YevmiyeNo, string Tarih, string FisAd, IReadOnlyList<YevmiyeFisSatir> Satirlar)
{
    public decimal ToplamBorc => Satirlar.Sum(s => s.Borc);
    public decimal ToplamAlacak => Satirlar.Sum(s => s.Alacak);
    public decimal Denge => Math.Abs(ToplamBorc - ToplamAlacak);
}

/// <summary>Kapanış-sonrası müdahale DETAY satırı (@Mod='DETAY'). Giren/Onaylayan = drn1.insAd.</summary>
public record KontrolDetayRow(
    string Donem, string Kaynak, long EvrakID, string EvrakNo,
    string BelgeTarihi, string KapanisTarihi, string DegisimTarihi,
    bool GecGiris, bool SonradanDeg, int GunSonra, int Severity,
    int YuvarlakTutar, int GirenOnaylayanAyni, int Mukerrer, int RiskSkor,   // SP CASE 1/0 → int (bool DEĞİL — Dapper materialization fix)
    string? GiderKod, string? GiderAd, string? KarsiKod,
    string? Giren, string? Onaylayan, decimal Tutar, string? Notu);
