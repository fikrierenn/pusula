using System.Reflection;
using Xunit;

namespace BkmVardiya.Tests;

/// <summary>
/// YASAK LİSTESİ AYAKTA MI — V-10/V-11'in kendi kapısı.
///
/// NEDEN VAR (ölçüldü 19.09.2026): `BannedSymbols.txt` içindeki sembol adı YANLIŞ
/// yazılırsa <b>analizör hiçbir şey demez</b>. Ban ölür, boğazı atlayan çağrı
/// derlenir, build yeşil kalır. Yani V-10/V-11 birer kapıdır ve onların da bir
/// kapısı gerekir — aksi hâlde koruma bir harf hatası kadar uzaktadır.
///
/// Bu test ihlali ARAMAZ; <b>mekanizmanın canlı olduğunu</b> ölçer. Solum'un aynı
/// gün ödeyerek öğrendiği ders (kapıyı silip yerine koyduğu yasak listesi bir harf
/// hatasıyla sessizce ölmüştü → `BannedSymbolsGateTests`); burada yansımayla
/// karşılığı kuruluyor.
///
/// ⚠ Python kapısı (`tools/vardiya_kapsam_denetimi.py`) dosyanın VARLIĞINI ve
///   beklenen girdiyi metin olarak denetler — ucuz, pre-commit'te koşar. Bu test
///   ondan fazlasını yapar: girdinin GERÇEK bir .NET tipine çözüldüğünü ölçer.
/// </summary>
public class BanListLivenessTests
{
    private static string RepoRoot()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null && !Directory.Exists(Path.Combine(dir.FullName, ".git")))
            dir = dir.Parent;
        Assert.True(dir is not null, "Depo kökü bulunamadı — test yasak listelerini okuyamaz.");
        return dir!.FullName;
    }

    public static TheoryData<string> BanLists() => new()
    {
        "lib/Bkm.Shared/BannedSymbols.txt",
        "vardiya-app/BannedSymbols.txt",
    };

    [Theory]
    [MemberData(nameof(BanLists))]
    public void Ban_list_entries_resolve_to_real_types(string relativePath)
    {
        var path = Path.Combine(RepoRoot(), relativePath);
        Assert.True(File.Exists(path), $"Yasak listesi YOK: {relativePath} — ban ölmüş demektir.");

        var lines = File.ReadAllLines(path)
                        .Where(l => !string.IsNullOrWhiteSpace(l))
                        .ToList();
        Assert.True(lines.Count > 0, $"{relativePath} BOŞ — hiçbir şeyi yasaklamıyor.");

        foreach (var line in lines)
        {
            // Yorum satiri TANINMAZ: aynisi iki kez RS0031 verir, farklilari ise
            // SESSIZCE yok sayilir (olculdu). Bu yuzden girdi olmayan satir = kirik.
            Assert.True(line.Contains(';'),
                $"{relativePath}: `{line}` bir girdi değil. Bu dosya yorum tanımaz — " +
                "gerekçe `.editorconfig`e yazılır.");

            var id = line.Split(';')[0].Trim();
            Assert.StartsWith("T:", id);   // bugün yalnız tip yasaklıyoruz

            var typeName = id[2..];
            var resolved = AppDomain.CurrentDomain.GetAssemblies()
                                    .Select(a => a.GetType(typeName, throwOnError: false))
                                    .FirstOrDefault(t => t is not null);

            Assert.True(resolved is not null,
                $"{relativePath}: `{typeName}` HİÇBİR yüklü derlemede bulunamadı. " +
                "Yazım hatası ya da kütüphane yükseltmesinde kalkan tip olabilir — " +
                "her iki hâlde de ban SESSİZCE ölmüştür (analizör uyarmaz).");
        }
    }

    /// <summary>
    /// Yasağın hedefi gerçekten Dapper'ın çağrı yüzeyi mi? Tip adı doğru ama BAŞKA
    /// bir tipe kayarsa (ör. ad değişimi) ban "canlı" görünür ama yanlış şeyi korur.
    /// </summary>
    [Fact]
    public void Banned_type_is_the_dapper_call_surface()
    {
        var sqlMapper = typeof(Dapper.SqlMapper);
        Assert.Equal("Dapper.SqlMapper", sqlMapper.FullName);
        Assert.Contains(sqlMapper.GetMethods(BindingFlags.Public | BindingFlags.Static),
                        m => m.Name == "QueryAsync");
    }
}
