namespace Bkm.Shared.Models;

/// <summary>
/// Vardiya / Mesai paneli kayıtları (plan-47 Faz 2).
///
/// ⚠ ALAN ADLARI TÜRKÇE — BİLİNÇLİ İSTİSNA (19.09.2026).
///   `turkish-ui.md` "kod İngilizce" der ve sınıf/metot/parametre adları buna
///   uyduruldu. DTO ALANLARI uymaz ve sebebi mekanik: bunlar `bkm.Vrd_KisiGun`
///   kolonlarının BİREBİR yansımasıdır (`Sube`, `SicilNo`, `EksikDk`…). Kolonlar
///   DerinSIS mirası + plan-47 tablolarıdır, Türkçedir ve DEĞİŞTİRİLEMEZ:
///   `sp_Vrd_KisiGunDoldur`, yayınlanan Excel ve plan-47 parite kapısı onlara bağlı.
///   Alanı İngilizce yapmak SQL'de 27 takma ad gerektirirdi — kazanç yok, iki
///   sözlük arasında çeviri katmanı riski var.
///   ⇒ Kural "SQL kolonları İngilizce" maddesinde zaten ihlal hâlinde ve bu ihlal
///   devralınmıştır; DTO'yu kolona hizalı tutmak ihlali BÜYÜTMEZ, görünür kılar.
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

/// <summary>
/// Fazla mesainin KAYNAĞI ve KONTROL EDİLEBİLİRLİĞİ (GMY sorusu 17.09.2026).
/// Tek rakam yönetilemez; kalemler hukuken de ayrıdır (m.41 fazla çalışma ·
/// m.46 hafta tatili çalışması 1 yevmiye + %50 · izin gününde çalıştırma).
/// </summary>
public sealed record VrdFazlaKaynak(
    int FazlaCalismaDk, int IzinIptalDk, int HaftaTatilDk, int PlansizDk,
    int CikisSonrasiDk, int GirisOncesiDk)
{
    /// <summary>Yönetim kararı — mağazanın elinde DEĞİL (izin iptali · hafta tatili).</summary>
    public int YonetimDk => IzinIptalDk + HaftaTatilDk;
    /// <summary>Mağaza operasyonu — kapanış/hazırlık, mağazanın elinde.</summary>
    public int MagazaDk => FazlaCalismaDk + PlansizDk;
    public int ToplamDk => YonetimDk + MagazaDk;
    public double YonetimPay => ToplamDk == 0 ? 0 : 100.0 * YonetimDk / ToplamDk;
    public double MagazaPay => ToplamDk == 0 ? 0 : 100.0 * MagazaDk / ToplamDk;
}

/// <summary>Kapanış sonrası kalma süre bandı — asıl aksiyon uzun kuyrukta.</summary>
public sealed record VrdKalmaBant(string Bant, int Satir, int Dk);

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
    public bool Supheli => OlcumNotu?.Contains(VrdConstants.SuspectText) == true;
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
