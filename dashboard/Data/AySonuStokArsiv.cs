using System.Globalization;
using System.Text.RegularExpressions;

namespace GmDashboard.Data;

/// <summary>
/// Ay sonu "Stok ve Satış Raporu Şube Detaylı" arşivi (Kırtasiye+Oyuncak+Hediyelik, wide formüllü).
/// Üretici: scripts/stok_satis_aylik_wide.py → raporlar/ay-sonu-stok-satis/stok-satis-sube-detayli-YYYY-MM.xlsx
///
/// Neden ARŞİV, neden canlı üretim değil: depo stoğu WMS anlık hücreden (depo.stok_adres_palet_vw) gelir,
/// geriye dönük kurulamaz. Ay sonu raporu o günün fotoğrafıdır → her ay üretilip saklanır, panel seçtirir.
/// </summary>
public static partial class AySonuStokArsiv
{
    public const string ContentType = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";
    private const string Onek = "stok-satis-sube-detayli-";

    public sealed record Kayit(string Ay, string AyAdi, DateTime Uretim, long Boyut, string Yol);

    [GeneratedRegex(@"^\d{4}-(0[1-9]|1[0-2])$")]
    private static partial Regex AyDeseni();

    /// <summary>Arşiv klasörü — dashboard content root'un kardeşi: pusula/raporlar/ay-sonu-stok-satis.</summary>
    public static string Klasor(string contentRoot) =>
        Path.GetFullPath(Path.Combine(contentRoot, "..", "raporlar", "ay-sonu-stok-satis"));

    /// <summary>Arşivdeki aylar, yeniden eskiye.</summary>
    public static IReadOnlyList<Kayit> Listele(string contentRoot)
    {
        var dir = Klasor(contentRoot);
        if (!Directory.Exists(dir)) return [];
        return Directory.EnumerateFiles(dir, Onek + "*.xlsx")
            .Select(p => (Yol: p, Ay: Path.GetFileNameWithoutExtension(p)[Onek.Length..]))
            .Where(x => AyDeseni().IsMatch(x.Ay))
            .Select(x =>
            {
                var fi = new FileInfo(x.Yol);
                return new Kayit(x.Ay, AyAdi(x.Ay), fi.LastWriteTime, fi.Length, x.Yol);
            })
            .OrderByDescending(k => k.Ay)
            .ToList();
    }

    public static bool GecerliAy(string? ay) => ay is not null && AyDeseni().IsMatch(ay);

    /// <summary>Üretilebilir (kapanmış) aylar: geçen aydan geriye, yeniden eskiye. İçinde bulunulan ay yok.</summary>
    public static IReadOnlyList<string> KapanmisAylar(int adet = 24)
    {
        var bas = new DateTime(DateTime.Today.Year, DateTime.Today.Month, 1);
        return Enumerable.Range(1, adet).Select(i => bas.AddMonths(-i).ToString("yyyy-MM")).ToList();
    }

    /// <summary>Ay → dosya yolu. Desen dışı girdi (yol gezinme dahil) ya da olmayan dosya → null.</summary>
    public static string? Bul(string contentRoot, string ay)
    {
        if (!AyDeseni().IsMatch(ay)) return null;
        var yol = Path.Combine(Klasor(contentRoot), $"{Onek}{ay}.xlsx");
        return File.Exists(yol) ? yol : null;
    }

    /// <summary>"2026-09" → "Eylül 2026".</summary>
    public static string AyAdi(string ay)
    {
        var d = DateTime.ParseExact(ay + "-01", "yyyy-MM-dd", CultureInfo.InvariantCulture);
        return d.ToString("MMMM yyyy", new CultureInfo("tr-TR"));
    }

    /// <summary>İndirmede kullanıcının alışık olduğu ad: "bkm eylül 2026 Stok ve Satış Raporu Şube Detaylı.xlsx".</summary>
    public static string IndirmeAdi(string ay) =>
        $"bkm {AyAdi(ay).ToLower(new CultureInfo("tr-TR"))} Stok ve Satış Raporu Şube Detaylı.xlsx";
}
