using System.Globalization;
using GmDashboard.Data.Definitions;

namespace GmDashboard.Tests.Unit;

// T-029 (spec 001, AC-0.1 / AC-0.2): "Hesap düzeltildi (gg.aa)" notunun metin ve görünme kuralı.
// Gün hesabı anahtarsız aşırı yüklemeyle sınanır; sınır sayıları literal 30/31 (VisibleDays sabiti değil).
public class CorrectionNotesTests
{
    private static DateOnly D(string dmy) => DateOnly.ParseExact(dmy, "dd.MM.yyyy", CultureInfo.InvariantCulture);

    // ---- A/B. Gün sınırları ve takvim geçişleri ----

    [Theory]
    [InlineData("05.10.2026", "05.10.2026", "Hesap düzeltildi (05.10)")]   // 0 gün
    [InlineData("05.10.2026", "06.10.2026", "Hesap düzeltildi (05.10)")]   // 1 gün: bugün değil yayın tarihi yazılır
    [InlineData("05.10.2026", "20.10.2026", "Hesap düzeltildi (05.10)")]   // 15 gün
    [InlineData("05.10.2026", "03.11.2026", "Hesap düzeltildi (05.10)")]   // 29 gün
    [InlineData("05.10.2026", "04.11.2026", "Hesap düzeltildi (05.10)")]   // 30 gün dahil
    [InlineData("31.10.2026", "30.11.2026", "Hesap düzeltildi (31.10)")]   // ay dönümü, 30 gün
    [InlineData("15.12.2026", "14.01.2027", "Hesap düzeltildi (15.12)")]   // yıl dönümü, 30 gün
    [InlineData("31.12.2026", "01.01.2027", "Hesap düzeltildi (31.12)")]   // bugünün ay/günü sızmaz
    [InlineData("01.02.2028", "02.03.2028", "Hesap düzeltildi (01.02)")]   // artık yıl, 30 gün
    [InlineData("01.02.2027", "03.03.2027", "Hesap düzeltildi (01.02)")]   // artık olmayan yıl, 30 gün
    [InlineData("29.02.2028", "29.02.2028", "Hesap düzeltildi (29.02)")]   // 0 gün
    [InlineData("29.02.2028", "29.03.2028", "Hesap düzeltildi (29.02)")]   // 29 gün
    [InlineData("29.02.2028", "30.03.2028", "Hesap düzeltildi (29.02)")]   // 30 gün
    public void NoteText_WithinThirtyDays_ReturnsPublishDateNote(string published, string today, string expected)
    {
        // Arrange
        DateOnly publishedDate = D(published);
        DateOnly todayDate = D(today);

        // Act
        string? note = CorrectionNotes.NoteText(publishedDate, todayDate);

        // Assert
        Assert.Equal(expected, note);
    }

    [Theory]
    [InlineData("05.10.2026", "05.11.2026")]   // 31 gün
    [InlineData("05.10.2026", "04.10.2026")]   // -1 gün
    [InlineData("05.10.2026", "05.10.2027")]   // +365
    [InlineData("05.10.2026", "05.10.2025")]   // -365
    [InlineData("31.10.2026", "01.12.2026")]   // ay dönümü 31 gün
    [InlineData("15.12.2026", "15.01.2027")]   // yıl dönümü 31 gün
    [InlineData("01.02.2028", "03.03.2028")]   // artık yıl 31 gün
    [InlineData("01.02.2027", "04.03.2027")]   // artık olmayan yıl 31 gün
    [InlineData("29.02.2028", "31.03.2028")]   // 31 gün
    [InlineData("29.02.2028", "28.02.2028")]   // -1 gün
    public void NoteText_OutsideWindow_ReturnsNull(string published, string today)
    {
        // Arrange
        DateOnly publishedDate = D(published);
        DateOnly todayDate = D(today);

        // Act
        string? note = CorrectionNotes.NoteText(publishedDate, todayDate);

        // Assert
        Assert.Null(note);
    }

    [Fact]
    public void NoteText_TodayIsMaxValue_ReturnsNullWithoutThrowing()
    {
        // Arrange
        DateOnly published = D("05.10.2026");

        // Act
        string? note = CorrectionNotes.NoteText(published, DateOnly.MaxValue);

        // Assert
        Assert.Null(note);
    }

    // ---- C. Yayında değil (DateOnly.MinValue) ----

    [Theory]
    [InlineData("05.10.2026")]
    [InlineData("01.01.0001")]
    [InlineData("11.01.0001")]
    [InlineData("31.12.9999")]
    public void NoteText_NotYetPublishedMinValue_ReturnsNull(string today)
    {
        // Arrange
        DateOnly todayDate = D(today);

        // Act
        string? note = CorrectionNotes.NoteText(DateOnly.MinValue, todayDate);

        // Assert
        Assert.Null(note);
    }

    [Fact]
    public void NoteText_DayAfterMinValue_IsRealPublishDate()
    {
        // Arrange
        DateOnly published = D("02.01.0001");

        // Act
        string? note = CorrectionNotes.NoteText(published, published);

        // Assert
        Assert.Equal("Hesap düzeltildi (02.01)", note);
    }

    [Fact]
    public void NoteText_PublishedMaxValueTodayMaxValue_ReturnsNoteWithoutOverflow()
    {
        // Act
        string? note = CorrectionNotes.NoteText(DateOnly.MaxValue, DateOnly.MaxValue);

        // Assert
        Assert.Equal("Hesap düzeltildi (31.12)", note);
    }

    [Fact]
    public void NoteText_PublishedMaxValueTodayMinValue_ReturnsNull()
    {
        // Act
        string? note = CorrectionNotes.NoteText(DateOnly.MaxValue, DateOnly.MinValue);

        // Assert
        Assert.Null(note);
    }

    // ---- D. Biçim ----

    [Theory]
    [InlineData("01.03.2027", "Hesap düzeltildi (01.03)")]
    [InlineData("09.01.2027", "Hesap düzeltildi (09.01)")]
    [InlineData("13.02.2027", "Hesap düzeltildi (13.02)")]
    [InlineData("05.10.2026", "Hesap düzeltildi (05.10)")]
    public void NoteText_PublishDay_UsesZeroPaddedDayMonthOrder(string published, string expected)
    {
        // Arrange
        DateOnly date = D(published);

        // Act
        string? note = CorrectionNotes.NoteText(date, date);

        // Assert
        Assert.Equal(expected, note);
    }

    [Fact]
    public void NoteText_PublishDay_HasNoYearAndNoSlash()
    {
        // Arrange
        DateOnly date = D("05.10.2026");

        // Act
        string? note = CorrectionNotes.NoteText(date, date);

        // Assert
        Assert.NotNull(note);
        Assert.DoesNotContain("2026", note);
        Assert.DoesNotContain("/", note);
    }

    [Fact]
    public void NoteText_PublishDay_UsesRealTurkishLetterAndHasNoTrailingText()
    {
        // Arrange
        DateOnly date = D("05.10.2026");

        // Act
        string? note = CorrectionNotes.NoteText(date, date);

        // Assert
        Assert.NotNull(note);
        Assert.Contains("ü", note);
        Assert.DoesNotContain("duzeltildi", note);
        Assert.Equal(note.Trim(), note);
        Assert.EndsWith(")", note, StringComparison.Ordinal);
    }

    [Theory]
    [InlineData("en-US", "05.10.2026", "Hesap düzeltildi (05.10)")]
    [InlineData("en-US", "25.12.2026", "Hesap düzeltildi (25.12)")]
    [InlineData("", "05.10.2026", "Hesap düzeltildi (05.10)")]        // InvariantCulture
    [InlineData("fr-FR", "05.10.2026", "Hesap düzeltildi (05.10)")]
    [InlineData("ar-SA", "05.10.2026", "Hesap düzeltildi (05.10)")]   // Hicri takvim / farklı rakam riski
    [InlineData("tr-TR", "05.10.2026", "Hesap düzeltildi (05.10)")]
    public void NoteText_AnyCurrentCulture_ReturnsSameText(string culture, string published, string expected)
    {
        // Arrange
        CultureInfo original = CultureInfo.CurrentCulture;
        CultureInfo originalUi = CultureInfo.CurrentUICulture;
        DateOnly date = D(published);
        try
        {
            CultureInfo.CurrentCulture = CultureInfo.GetCultureInfo(culture);
            CultureInfo.CurrentUICulture = CultureInfo.GetCultureInfo(culture);

            // Act
            string? note = CorrectionNotes.NoteText(date, date);

            // Assert
            Assert.Equal(expected, note);
        }
        finally
        {
            CultureInfo.CurrentCulture = original;
            CultureInfo.CurrentUICulture = originalUi;
        }
    }

    [Fact]
    public void NoteText_UnderAmericanEnglishCulture_DoesNotChangeThreadCulture()
    {
        // Arrange
        CultureInfo original = CultureInfo.CurrentCulture;
        DateOnly date = D("05.10.2026");
        try
        {
            CultureInfo.CurrentCulture = CultureInfo.GetCultureInfo("en-US");

            // Act
            string? note = CorrectionNotes.NoteText(date, date);

            // Assert
            Assert.NotNull(note);
            Assert.Equal("en-US", CultureInfo.CurrentCulture.Name);
        }
        finally
        {
            CultureInfo.CurrentCulture = original;
        }
    }

    // ---- Eşzamanlılık ----

    [Fact]
    public void NoteText_ThousandParallelCalls_AllReturnSameResult()
    {
        // Arrange
        DateOnly published = D("05.10.2026");
        DateOnly today = D("04.11.2026");

        // Act
        string?[] results = Enumerable.Range(0, 1000)
            .AsParallel()
            .Select(_ => CorrectionNotes.NoteText(published, today))
            .ToArray();

        // Assert
        Assert.Equal(1000, results.Length);
        Assert.All(results, r => Assert.Equal("Hesap düzeltildi (05.10)", r));
    }
}
