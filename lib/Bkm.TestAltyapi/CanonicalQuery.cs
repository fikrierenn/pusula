namespace Bkm.TestAltyapi;

/// <summary>Kanonik .sql dosyasından blok okur.</summary>
public static class CanonicalQuery
{
    private const string FolderName = "Kanonik";
    private const string BlockMarker = "-- blok:";

    /// <summary>Kanonik klasördeki dosyadan (isteğe bağlı olarak tek bir bloğun) ham metnini döner.</summary>
    public static string Read(string file, string? block = null)
    {
        // Dosya adı klasör içinde kalmalı; yol ayırıcı taşıyan ad reddedilir.
        if (Path.GetFileName(file) != file)
        {
            throw new ArgumentException("Kanonik dosya adı yol içeremez.", nameof(file));
        }

        string path = Path.Combine(AppContext.BaseDirectory, FolderName, Path.GetFileName(file));
        if (!File.Exists(path))
        {
            throw new FileNotFoundException($"Kanonik dosya bulunamadı: {file}", path);
        }

        string[] lines = RemoveHeader(File.ReadAllText(path)).Split('\n');
        for (int i = 0; i < lines.Length; i++)
        {
            lines[i] = lines[i].TrimEnd('\r');
        }

        if (block is null)
        {
            return string.Join('\n', lines);
        }

        List<int> markers = [];
        for (int i = 0; i < lines.Length; i++)
        {
            if (IsMarker(lines[i]))
            {
                markers.Add(i);
            }
        }

        List<int> matches = markers.Where(index => BlockName(lines[index]) == block).ToList();
        if (matches.Count == 0)
        {
            throw new InvalidOperationException($"Blok bulunamadı: {file} · blok '{block}'.");
        }

        if (matches.Count > 1)
        {
            throw new InvalidOperationException($"Blok birden çok kez tanımlı: {file} · blok '{block}'.");
        }

        int start = matches[0] + 1;
        int end = markers.Where(index => index > matches[0]).DefaultIfEmpty(lines.Length).First();
        string body = string.Join('\n', lines[start..end]);
        if (string.IsNullOrWhiteSpace(body))
        {
            throw new InvalidOperationException($"Blok boş: {file} · blok '{block}'.");
        }

        return body;
    }

    private static string RemoveHeader(string text)
    {
        int open = text.IndexOf("/*", StringComparison.Ordinal);
        if (open < 0)
        {
            return text;
        }

        // Başlık, ilk blok işaretinden önce gelen ilk /* */ yorumudur; gövdedeki yorumlara dokunulmaz.
        int firstMarker = text.IndexOf(BlockMarker, StringComparison.Ordinal);
        if ((firstMarker >= 0) && (firstMarker < open))
        {
            return text;
        }

        int close = text.IndexOf("*/", open + 2, StringComparison.Ordinal);
        return (close < 0) ? text : text.Remove(open, close + 2 - open);
    }

    private static bool IsMarker(string line)
    {
        return line.TrimStart().StartsWith(BlockMarker, StringComparison.Ordinal);
    }

    private static string BlockName(string markerLine)
    {
        string rest = markerLine.TrimStart()[BlockMarker.Length..];
        return rest.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries).FirstOrDefault() ?? string.Empty;
    }
}
