namespace Bkm.Shared.Models;

/// <summary>
/// Vardiya / Mesai paneli kayıtları (plan-47 Faz 2).
///
/// ⚠ ALAN ADLARI TÜRKÇE — BİLİNÇLİ İSTİSNA (19.09.2026).
///   `turkish-ui.md` "kod İngilizce" der ve sınıf/metot/parametre adları buna
///   uyduruldu. DTO ALANLARI uymaz ve sebebi mekanik: bunlar `bkm.Vrd_KisiGun`
///   kolonlarının BİREBİR yansımasıdır (`Branch`, `StaffNo`, `ShortMin`…). Kolonlar
///   DerinSIS mirası + plan-47 tablolarıdır, Türkçedir ve DEĞİŞTİRİLEMEZ:
///   `sp_Vrd_KisiGunDoldur`, yayınlanan Excel ve plan-47 parite kapısı onlara bağlı.
///   Alanı İngilizce yapmak SQL'de 27 takma ad gerektirirdi — kazanç yok, iki
///   sözlük arasında çeviri katmanı riski var.
///   ⇒ Kural "SQL kolonları İngilizce" maddesinde zaten ihlal hâlinde ve bu ihlal
///   devralınmıştır; DTO'yu kolona hizalı tutmak ihlali BÜYÜTMEZ, görünür kılar.
///
/// ⚠ SÜRELER DAKİKA (int), <c>TimeSpan</c> değil: gece mesaisinde çıkış ertesi güne
///   sarkar (&gt;1440) ve saat tipleri bunu tutamaz. Biçimleme <see cref="VrdFormat"/>.
/// ⚠ Dapper POZİSYONEL record'da SIRA sözleşmedir: SQL'e araya kolon eklenirse
///   record'da AYNI yere eklenir, sonuna DEĞİL — tipler uyuşursa değer sessizce kayar
///   (`sql-server-conventions.md`).
/// </summary>
public sealed record VrdCutoff(
    DateTime CutoffFrom, DateTime CutoffTo, DateTime CountFrom,
    int PersonDays, int BranchCount, DateTime WrittenAt);

public sealed record VrdSummary(
    int PersonDays, int BranchCount, int PersonCount,
    // ⚠ SIRA SÖZLEŞMEDİR (Dapper pozisyonel record): `CorrectedDays` SQL'de
    //   `OvertimeMin`den HEMEN SONRA geliyor ve burada da öyle duruyor. Sona
    //   eklenseydi tipler uyuştuğu için DEĞERLER SESSİZCE KAYARDI.
    int ShortMin, int OvertimeMin, int CorrectedDays,
    int OutOfCount, int DayRollover, int Suspect,
    int CarryShortMin, int CarryOvertimeMin, string CarryPeriod)
{
    /// <summary>Yayınlanan raporun toplamı = dönem + önceki ay devri.</summary>
    public int TotalShortMin => ShortMin + CarryShortMin;
    public int TotalOvertimeMin => OvertimeMin + CarryOvertimeMin;
}

public sealed record VrdStatus(string Status, int PersonDays);

/// <summary>
/// Fazla mesainin KAYNAĞI ve KONTROL EDİLEBİLİRLİĞİ (GMY sorusu 17.09.2026).
/// Tek rakam yönetilemez; kalemler hukuken de ayrıdır (m.41 fazla çalışma ·
/// m.46 hafta tatili çalışması 1 yevmiye + %50 · izin gününde çalıştırma).
/// </summary>
public sealed record VrdOvertimeSource(
    int ExtraWorkMin, int LeaveCancelledMin, int WeeklyRestMin, int UnplannedMin,
    int AfterCloseMin, int BeforeOpenMin)
{
    /// <summary>Yönetim kararı — mağazanın elinde DEĞİL (izin iptali · hafta tatili).</summary>
    public int ManagementMin => LeaveCancelledMin + WeeklyRestMin;
    /// <summary>Mağaza operasyonu — kapanış/hazırlık, mağazanın elinde.</summary>
    public int StoreMin => ExtraWorkMin + UnplannedMin;
    public int TotalMin => ManagementMin + StoreMin;
    public double ManagementShare => TotalMin == 0 ? 0 : 100.0 * ManagementMin / TotalMin;
    public double StoreShare => TotalMin == 0 ? 0 : 100.0 * StoreMin / TotalMin;
}

/// <summary>Kapanış sonrası kalma süre bandı — asıl aksiyon uzun kuyrukta.</summary>
public sealed record VrdStayBand(string Band, int DayCount, int Minutes);

public sealed record VrdBranch(string Branch, int PersonDays, int PersonCount, int ShortMin, int OvertimeMin);

/// <summary>
/// Mesai mevzuat kapısı sayıları — `tools/mesai_mevzuat_kapisi.py` ile AYNI eşikler.
/// <b>Over45 İHLAL DEĞİLDİR</b>: haftalık 45 saat normal çalışma sınırıdır, üstü fazla
/// çalışmadır ve meşrudur. Sert sınır yıllık 270 saat + yazılı muvafakat (m.41/7).
/// </summary>
public sealed record VrdCompliance(
    int Daily11, int Gross12, int Night75, int NoWeeklyRest, int Over45, int Suspect);

public sealed record VrdRow(
    string Branch, string StaffNo, string? PersonName, string? Department, string? JobTitle,
    DateTime Date, string? ShiftPlan,
    int? CardInMin, int? CardOutMin, int? InMin, int? OutMin,
    int? GrossMin, int? BreakMin, int? WorkMin, int PlanWorkMin,
    // ⚠ SIRA SÖZLEŞMEDİR (Dapper pozisyonel record): SQL'e araya kolon eklenirse
    //   buraya da AYNI yere eklenir. Aşağıdaki dördü SP'nin yazdığı YAYIN ölçüsü —
    //   `WorkMin`/`PlanWorkMin` aracın ölçüsü, ikisi kasıtlı farklı.
    int? RequiredMin, int? Net2Min, int? WeeklyPremiumMin, int? ShortMin, int? OvertimeMin,
    string Status, bool DayRollover, bool OutOfCount, string? MeasureNote,
    int? ApprovedInMin, int? ApprovedOutMin, int? ExtraShiftMin)
{
    public bool Suspect => MeasureNote?.Contains(VrdConstants.SuspectText) == true;
}

/// <summary>Süre biçimleme — dakika tabanı tek yerde.</summary>
public static class VrdFormat
{
    /// <summary>450 → "7:30". Gün dönümünde 1470 → "24:30" (kasıtlı, gizlenmez).</summary>
    public static string Duration(int? dk) =>
        dk is null ? "—" : $"{dk.Value / 60}:{Math.Abs(dk.Value) % 60:00}";

    /// <summary>Gün-içi saat gösterimi: 1470 → "00:30" (ham okutma neyse o).</summary>
    public static string TimeOfDay(int? dk) =>
        dk is null ? "—" : $"{dk.Value % 1440 / 60:00}:{dk.Value % 60:00}";

    /// <summary>KPI için: 1234 dk → "20,6 saat".</summary>
    public static string HoursDecimal(int dk) => (dk / 60.0).ToString("N1") + " saat";
}
