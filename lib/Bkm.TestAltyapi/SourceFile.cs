using Xunit;

namespace Bkm.TestAltyapi;

/// <summary>Depo köküne göre kaynak dosya okur.</summary>
public static class SourceFile
{
    private const string SolutionName = "Pusula.sln";

    /// <summary>Depo köküne göreli yoldaki dosyanın metnini döner.</summary>
    public static string Read(string repoRelativePath, string? startDirectory = null)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(repoRelativePath);

        string root = FindRoot(startDirectory ?? AppContext.BaseDirectory);
        string normalized = repoRelativePath.Replace('\\', '/');
        string full = Path.GetFullPath(Path.Combine(root, normalized));
        string rootWithSeparator = Path.TrimEndingDirectorySeparator(root) + Path.DirectorySeparatorChar;

        if (!full.StartsWith(rootWithSeparator, StringComparison.OrdinalIgnoreCase))
        {
            throw new ArgumentException("Yol depo dışına çıkıyor.", nameof(repoRelativePath));
        }

        if (!File.Exists(full))
        {
            throw new FileNotFoundException("Kaynak dosya bulunamadı.", full);
        }

        return File.ReadAllText(full);
    }

    private static string FindRoot(string start)
    {
        DirectoryInfo? current = new(Path.GetFullPath(start));
        while (current is not null)
        {
            if (File.Exists(Path.Combine(current.FullName, SolutionName)))
            {
                return current.FullName;
            }

            current = current.Parent;
        }

        Assert.Fail("KOŞAMADI: depo kökü bulunamadı");
        return string.Empty;
    }
}
