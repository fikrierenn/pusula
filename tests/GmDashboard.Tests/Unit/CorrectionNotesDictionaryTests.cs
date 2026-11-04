using System.Reflection;
using GmDashboard.Data.Definitions;

namespace GmDashboard.Tests.Unit;

// T-029: PublishDates sözlüğünün anahtar sözleşmesi, anahtarlı NoteText ve değiştirilemezlik (AC-0.1).
// K1: s_published = MinValue iken anahtarlı NoteText her anahtar için null döner; "bilinmeyen anahtar" ile
// "yayında değil" T-081'e kadar ayrışmaz (aşağıdaki "K1" testleri o güne kadar iki dal aynı sonucu verir).
public class CorrectionNotesDictionaryTests
{
    // Ekran sözleşmesi: kod sözlüğünden türetilmez, elle yazılmış literal.
    private static readonly string[] s_expectedKeys =
    [
        "sadakat.winback", "sadakat.kartli-fis", "trafik.fis", "home.magaza-fis", "home.magaza-net-kirilim",
        "home.saat-kasiyer", "magaza.kampanya", "magaza.iade", "magaza.upt", "envanter.tedarikci",
        "envanter.marj", "envanter.abc", "envanter.depo", "odak.depo", "odak.etic-talep",
        "etic.kategori", "sinav.odeme", "mizan.nakit-kdv", "musteri.rfm", "hediye-ceki.barem",
    ];

    private static readonly DateOnly s_today = new(2026, 10, 5);

    // ---- Anahtar kümesi ----

    [Fact]
    public void PublishDates_TwentyKeys_MatchScreenContract()
    {
        // Act
        IReadOnlyDictionary<string, DateOnly> dates = CorrectionNotes.PublishDates;

        // Assert
        Assert.Equal(20, dates.Count);
        Assert.Empty(s_expectedKeys.Except(dates.Keys, StringComparer.Ordinal));
        Assert.Empty(dates.Keys.Except(s_expectedKeys, StringComparer.Ordinal));
    }

    [Fact]
    public void PublishDates_Keys_AreLowercaseTrimmedAndCaseDistinct()
    {
        // Act
        string[] keys = CorrectionNotes.PublishDates.Keys.ToArray();

        // Assert
        Assert.All(keys, k => Assert.Equal(k.Trim().ToLowerInvariant(), k));
        Assert.Equal(20, keys.Distinct(StringComparer.OrdinalIgnoreCase).Count());
    }

    [Theory]
    [InlineData("SADAKAT.WINBACK")]
    [InlineData("Sadakat.Winback")]
    [InlineData("sadakat.winback ")]
    [InlineData("sadakat_winback")]
    [InlineData("sadakat")]
    [InlineData("sadakat.winback.x")]
    [InlineData("")]
    [InlineData(" ")]
    public void PublishDates_NearMissKey_IsNotContained(string key)
    {
        // Act
        bool contained = CorrectionNotes.PublishDates.ContainsKey(key);

        // Assert
        Assert.False(contained);
    }

    [Fact]
    public void PublishDates_ExactKey_IsContained()
    {
        // Act
        bool contained = CorrectionNotes.PublishDates.ContainsKey("sadakat.winback");

        // Assert
        Assert.True(contained);
    }

    // ---- Tek sabit (K3) ----

    [Fact]
    public void PublishDates_Values_AreAllEqual()
    {
        // Act
        int distinct = CorrectionNotes.PublishDates.Values.Distinct().Count();

        // Assert
        Assert.Equal(1, distinct);
    }

    [Fact]
    public void PublishDates_Values_AllComeFromSinglePrivateConstant()
    {
        // Arrange
        FieldInfo? field = typeof(CorrectionNotes).GetField("s_published", BindingFlags.NonPublic | BindingFlags.Static);

        // Act
        DateOnly? published = (DateOnly?)field?.GetValue(null);

        // Assert
        Assert.NotNull(field);
        Assert.NotNull(published);
        Assert.All(CorrectionNotes.PublishDates.Values, v => Assert.Equal(published, v));
    }

    // ---- Anahtarlı NoteText (K1, K2) ----

    [Fact]
    public void NoteText_EveryKeyNotYetPublished_ReturnsNull()
    {
        // Arrange
        string[] notPublishedKeys = CorrectionNotes.PublishDates
            .Where(p => p.Value == DateOnly.MinValue)
            .Select(p => p.Key)
            .ToArray();

        // Act
        string?[] notes = notPublishedKeys
            .SelectMany(k => new[] { DateOnly.MinValue, s_today, DateOnly.MaxValue }.Select(d => CorrectionNotes.NoteText(k, d)))
            .ToArray();

        // Assert
        Assert.All(notes, Assert.Null);
    }

    [Theory]
    [InlineData("yok.boyle")]
    [InlineData("SADAKAT.WINBACK")]   // K1: T-081'e kadar "bilinmeyen" ile "yayında değil" ayrışmaz
    [InlineData("")]
    [InlineData(" ")]
    public void NoteText_UnknownOrBlankKey_ReturnsNullWithoutThrowing(string key)
    {
        // Act
        string? note = CorrectionNotes.NoteText(key, s_today);

        // Assert
        Assert.Null(note);
    }

    [Fact]
    public void NoteText_NullKey_ReturnsNullWithoutThrowing()
    {
        // Act
        string? note = CorrectionNotes.NoteText(null!, s_today);

        // Assert
        Assert.Null(note);
    }

    [Fact]
    public void NoteText_KeyedAndPublishedOverloads_AgreeForEveryKey()
    {
        // Arrange
        DateOnly[] days = [s_today.AddDays(-1), s_today, s_today.AddDays(30), s_today.AddDays(31), DateOnly.MinValue];
        IReadOnlyDictionary<string, DateOnly> dates = CorrectionNotes.PublishDates;

        // Act
        (string? keyed, string? direct)[] pairs = dates
            .SelectMany(p => days.Select(d => (CorrectionNotes.NoteText(p.Key, d), CorrectionNotes.NoteText(p.Value, d))))
            .ToArray();

        // Assert
        Assert.NotEmpty(pairs);
        Assert.All(pairs, pair => Assert.Equal(pair.direct, pair.keyed));
    }

    // ---- Değiştirilemezlik ----

    [Fact]
    public void PublishDates_AsDictionary_IsNotLeakedMutableType()
    {
        // Act
        Dictionary<string, DateOnly>? mutable = CorrectionNotes.PublishDates as Dictionary<string, DateOnly>;

        // Assert
        Assert.Null(mutable);
    }

    [Fact]
    public void PublishDates_Add_ThrowsAndLeavesContentUnchanged()
    {
        // Arrange
        IDictionary<string, DateOnly> dict = (IDictionary<string, DateOnly>)CorrectionNotes.PublishDates;

        // Act
        Action act = () => dict.Add("yeni.anahtar", new DateOnly(2030, 1, 1));

        // Assert
        Assert.Throws<NotSupportedException>(act);
        Assert.Equal(20, CorrectionNotes.PublishDates.Count);
        Assert.False(CorrectionNotes.PublishDates.ContainsKey("yeni.anahtar"));
    }

    [Fact]
    public void PublishDates_IndexerSet_ThrowsAndLeavesValueUnchanged()
    {
        // Arrange
        IDictionary<string, DateOnly> dict = (IDictionary<string, DateOnly>)CorrectionNotes.PublishDates;
        DateOnly before = CorrectionNotes.PublishDates["trafik.fis"];

        // Act
        Action act = () => dict["trafik.fis"] = new DateOnly(2030, 1, 1);

        // Assert
        Assert.Throws<NotSupportedException>(act);
        Assert.Equal(before, CorrectionNotes.PublishDates["trafik.fis"]);
    }

    [Fact]
    public void PublishDates_Remove_ThrowsAndKeepsKey()
    {
        // Arrange
        IDictionary<string, DateOnly> dict = (IDictionary<string, DateOnly>)CorrectionNotes.PublishDates;

        // Act
        Action act = () => dict.Remove("trafik.fis");

        // Assert
        Assert.Throws<NotSupportedException>(act);
        Assert.True(CorrectionNotes.PublishDates.ContainsKey("trafik.fis"));
        Assert.Equal(20, CorrectionNotes.PublishDates.Count);
    }

    [Fact]
    public void PublishDates_Clear_ThrowsAndKeepsAllKeys()
    {
        // Arrange
        IDictionary<string, DateOnly> dict = (IDictionary<string, DateOnly>)CorrectionNotes.PublishDates;

        // Act
        Action act = () => dict.Clear();

        // Assert
        Assert.Throws<NotSupportedException>(act);
        Assert.Equal(20, CorrectionNotes.PublishDates.Count);
    }

    [Fact]
    public void PublishDates_CollectionAdd_ThrowsAndLeavesContentUnchanged()
    {
        // Arrange
        ICollection<KeyValuePair<string, DateOnly>> collection =
            (ICollection<KeyValuePair<string, DateOnly>>)CorrectionNotes.PublishDates;

        // Act
        Action act = () => collection.Add(new KeyValuePair<string, DateOnly>("yeni.anahtar", new DateOnly(2030, 1, 1)));

        // Assert
        Assert.Throws<NotSupportedException>(act);
        Assert.Equal(20, CorrectionNotes.PublishDates.Count);
    }

    [Fact]
    public void PublishDates_AfterMutationAttempts_NoteOutputIsUnchanged()
    {
        // Arrange
        IDictionary<string, DateOnly> dict = (IDictionary<string, DateOnly>)CorrectionNotes.PublishDates;
        DateOnly published = new(2026, 10, 5);
        DateOnly today = new(2026, 11, 4);
        string? noteBefore = CorrectionNotes.NoteText(published, today);
        string[] keysBefore = CorrectionNotes.PublishDates.Keys.OrderBy(k => k, StringComparer.Ordinal).ToArray();

        // Act
        Assert.Throws<NotSupportedException>(() => dict.Add("yeni.anahtar", published));
        Assert.Throws<NotSupportedException>(() => dict.Clear());

        // Assert
        Assert.Equal("Hesap düzeltildi (05.10)", noteBefore);
        Assert.Equal(noteBefore, CorrectionNotes.NoteText(published, today));
        Assert.Equal(keysBefore, CorrectionNotes.PublishDates.Keys.OrderBy(k => k, StringComparer.Ordinal).ToArray());
    }

    [Fact]
    public void NoteText_ThousandParallelKeyedCalls_AllReturnSameResult()
    {
        // Act
        string?[] results = Enumerable.Range(0, 1000)
            .AsParallel()
            .Select(_ => CorrectionNotes.NoteText("trafik.fis", s_today))
            .ToArray();

        // Assert
        Assert.Equal(1000, results.Length);
        Assert.All(results, Assert.Null);
    }
}
