namespace GmDashboard.Data.Definitions;

/// <summary>
/// "Hesap düzeltildi" note shown next to each corrected indicator for a limited number of days after publish.
/// </summary>
public static class CorrectionNotes
{
    public const int VisibleDays = 30;

    public static IReadOnlyDictionary<string, DateOnly> PublishDates
    {
        get { throw new NotImplementedException(); }
    }

    public static string? NoteText(string indicatorKey, DateOnly today)
    {
        throw new NotImplementedException();
    }

    public static string? NoteText(DateOnly published, DateOnly today)
    {
        throw new NotImplementedException();
    }
}
