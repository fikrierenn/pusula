namespace GmDashboard.Models;

/// <summary>
/// Vardiya / Mesai paneli kayıtları (plan-47 Faz 2).
///
/// ⚠ SÜRELER DAKİKA (int), <c>TimeSpan</c> değil: gece mesaisinde çıkış ertesi güne
///   sarkar (&gt;1440) ve saat tipleri bunu tutamaz. Biçimleme <see cref="VrdBicim"/>.
/// ⚠ Dapper POZİSYONEL record'da SIRA sözleşmedir: SQL'e araya kolon eklenirse
///   record'da AYNI yere eklenir, sonuna DEĞİL — tipler uyuşursa değer sessizce kayar
///   (`sql-server-conventions.md`).
/// </summary>
public sealed record VrdKesim(
    DateTime KesimBas, DateTime KesimBit, DateTime SayimBas,
    int KisiGun, int SubeSay, DateTime Yazilma);

public sealed record VrdOzet(
    int KisiGun, int SubeSay, int KisiSay,
    int EksikDk, int FazlaDk, int SayimDisi, int GunDonumu, int Supheli,
    int DevirEksikDk, int DevirFazlaDk)
{
    /// <summary>Yayınlanan raporun toplamı = dönem + önceki ay devri.</summary>
    public int ToplamEksikDk => EksikDk + DevirEksikDk;
    public int ToplamFazlaDk => FazlaDk + DevirFazlaDk;
}

public sealed record VrdDurum(string Durum, int KisiGun);

public sealed record VrdSube(string Sube, int KisiGun, int KisiSay, int EksikDk, int FazlaDk);

/// <summary>
/// Mesai mevzuat kapısı sayıları — `tools/mesai_mevzuat_kapisi.py` ile AYNI eşikler.
/// <b>Ustu45 İHLAL DEĞİLDİR</b>: haftalık 45 saat normal çalışma sınırıdır, üstü fazla
/// çalışmadır ve meşrudur. Sert sınır yıllık 270 saat + yazılı muvafakat (m.41/7).
/// </summary>
public sealed record VrdUyum(
    int Gunluk11, int Brut12, int Gece75, int HaftaTat, int Ustu45, int Supheli);

public sealed record VrdSatir(
    string Sube, string SicilNo, string? Personel, string? Bolum, string? Gorev,
    DateTime Tarih, string? VardiyaTanim,
    int? KartGirisDk, int? KartCikisDk, int? GirisDk, int? CikisDk,
    int? BrutDk, int? MolaDk, int? CalismaDk, int PlanCalismaDk,
    // ⚠ SIRA SÖZLEŞMEDİR (Dapper pozisyonel record): SQL'e araya kolon eklenirse
    //   buraya da AYNI yere eklenir. Aşağıdaki dördü SP'nin yazdığı YAYIN ölçüsü —
    //   `CalismaDk`/`PlanCalismaDk` aracın ölçüsü, ikisi kasıtlı farklı.
    int? GerekenDk, int? Net2Dk, int? HaftalikPrimDk, int? EksikDk, int? FazlaDk,
    string Durum, bool GunDonumu, bool SayimDisi, string? OlcumNotu,
    int? OnayGirisDk, int? OnayCikisDk, int? EkMesaiDk)
{
    public bool Supheli => OlcumNotu?.Contains("ŞÜPHELİ") == true;
}

/// <summary>Süre biçimleme — dakika tabanı tek yerde.</summary>
public static class VrdBicim
{
    /// <summary>450 → "7:30". Gün dönümünde 1470 → "24:30" (kasıtlı, gizlenmez).</summary>
    public static string Sure(int? dk) =>
        dk is null ? "—" : $"{dk.Value / 60}:{Math.Abs(dk.Value) % 60:00}";

    /// <summary>Gün-içi saat gösterimi: 1470 → "00:30" (ham okutma neyse o).</summary>
    public static string Saat(int? dk) =>
        dk is null ? "—" : $"{dk.Value % 1440 / 60:00}:{dk.Value % 60:00}";

    /// <summary>KPI için: 1234 dk → "20,6 saat".</summary>
    public static string SaatOndalik(int dk) => (dk / 60.0).ToString("N1") + " saat";
}
