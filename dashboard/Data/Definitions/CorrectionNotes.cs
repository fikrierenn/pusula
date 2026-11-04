using System.Collections.Frozen;
using System.Globalization;

namespace GmDashboard.Data.Definitions;

/// <summary>
/// "Hesap düzeltildi" note shown next to each corrected indicator for a limited number of days after publish.
/// </summary>
public static class CorrectionNotes
{
    public const int VisibleDays = 30;

    // Tek yayın tarihi; T-081 yalnız bu satırı değiştirir. Aşağıdaki sözlükten ÖNCE bildirilmeli (statik başlatma sırası).
    private static readonly DateOnly s_published = DateOnly.MinValue;

    private static readonly FrozenDictionary<string, DateOnly> s_publishDates = new Dictionary<string, DateOnly>
    {
        ["sadakat.winback"] = s_published,
        ["sadakat.kartli-fis"] = s_published,
        ["trafik.fis"] = s_published,
        ["home.magaza-fis"] = s_published,
        ["home.magaza-net-kirilim"] = s_published,
        ["home.saat-kasiyer"] = s_published,
        ["magaza.kampanya"] = s_published,
        ["magaza.iade"] = s_published,
        ["magaza.upt"] = s_published,
        ["envanter.tedarikci"] = s_published,
        ["envanter.marj"] = s_published,
        ["envanter.abc"] = s_published,
        ["envanter.depo"] = s_published,
        ["odak.depo"] = s_published,
        ["odak.etic-talep"] = s_published,
        ["etic.kategori"] = s_published,
        ["sinav.odeme"] = s_published,
        ["mizan.nakit-kdv"] = s_published,
        ["musteri.rfm"] = s_published,
        ["hediye-ceki.barem"] = s_published,
    }.ToFrozenDictionary(StringComparer.Ordinal);

    public static IReadOnlyDictionary<string, DateOnly> PublishDates => s_publishDates;

    public static string? NoteText(string indicatorKey, DateOnly today)
    {
        if (string.IsNullOrWhiteSpace(indicatorKey))
        {
            return null;
        }

        return s_publishDates.TryGetValue(indicatorKey, out DateOnly published)
            ? NoteText(published, today)
            : null;
    }

    public static string? NoteText(DateOnly published, DateOnly today)
    {
        if (published == DateOnly.MinValue)
        {
            return null;
        }

        int elapsedDays = today.DayNumber - published.DayNumber;
        if ((elapsedDays < 0) || (elapsedDays > VisibleDays))
        {
            return null;
        }

        return "Hesap düzeltildi (" + published.ToString("dd.MM", CultureInfo.GetCultureInfo("tr-TR")) + ")";
    }
}
