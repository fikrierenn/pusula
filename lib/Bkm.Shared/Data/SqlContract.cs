using Dapper;

namespace Bkm.Shared.Data;

/// <summary>
/// SQL ↔ PARAMETRE SÖZLEŞMESİ — boğazların ortak çekirdeği (V-09/V-11).
///
/// NEDEN AYRI SINIF: aynı kusur 19.09.2026'da <b>BEŞ kez</b> ölçüldü ve beşinde de
/// derleme temizdi, belirti hep çalışma anında <c>Must declare the scalar variable</c>
/// oldu:
/// <list type="number">
/// <item><c>GetOvertimeSourceAsync</c> · <c>GetStayBandsAsync</c> · <c>GetRowsAsync</c>
///       — SQL <c>@sube</c>, C# <c>branch</c>.</item>
/// <item><c>SaveApprovalAsync</c> — SQL <c>@girisDk/@cikisDk/@ekMesaiDk/@kaydeden</c>,
///       C# <c>inMin/outMin/extraShiftMin/savedBy</c>. Onay yazma yolu hiç çalışmıyordu.</item>
/// <item><c>Seed</c> ACL yazması — SQL <c>@sube</c>, C# <c>branch</c>. Şube ataması
///       patlıyordu; seed Türkçe→İngilizce yeniden adlandırmadan ÖNCE koşmuştu, yani
///       kusur koşumdan SONRA girdi ve kimse bir daha koşturmadı.</item>
/// </list>
/// Ortak mekanizma tek: <b>anonim nesnede parametre adı = yerel değişken adıdır</b>,
/// dolayısıyla bir yeniden adlandırma SQL'deki adı sessizce ayırır. Panzehir de tek:
/// adı DİZGE olarak tek yerde yazmak ve her çağrıda SQL ile karşılaştırmak.
///
/// ⚠ Bu sınıf DAPPER ÇAĞIRMAZ — yalnız doğrular. Çağrıyı her boğaz kendi yapar,
///   çünkü ban listesi (V-10/V-11) Dapper'ı boğaz dosyalarına kilitliyor.
/// </summary>
public static class SqlContract
{
    // @@ROWCOUNT gibi cift-at'li sistem degiskenleri parametre DEGILDIR.
    private static readonly System.Text.RegularExpressions.Regex Token =
        new(@"(?<!@)@([A-Za-z_][A-Za-z0-9_]*)",
            System.Text.RegularExpressions.RegexOptions.Compiled);

    /// <summary>
    /// SQL'deki <c>@token</c> kümesi ile verilen parametre adlarını KARŞILAŞTIRIR.
    /// İki yönlü: eksik parametre çalışma anında patlardı; fazla parametre ise SQL'in
    /// o değeri hiç kullanmadığını — yani bir süzgecin sessizce düştüğünü — gösterir.
    /// </summary>
    /// <param name="anchor">
    /// Her çağrıda bulunan ama her SQL'de geçmeyebilen çapa (vardiya tarafında
    /// <c>userId</c>). Yalnız "fazla" yönünde muaftır; eksik yönünde muaf DEĞİLDİR.
    /// </param>
    public static string Verify(string sql, IEnumerable<string> given, string? anchor = null)
    {
        var used = Token.Matches(sql).Select(m => m.Groups[1].Value)
                        .ToHashSet(StringComparer.OrdinalIgnoreCase);
        var verilen = given.ToHashSet(StringComparer.OrdinalIgnoreCase);

        var missing = used.Except(verilen).OrderBy(x => x).ToList();
        var unused = verilen.Except(used)
                            .Where(n => anchor is null || !n.Equals(anchor, StringComparison.OrdinalIgnoreCase))
                            .OrderBy(x => x).ToList();

        if (missing.Count > 0 || unused.Count > 0)
            throw new InvalidOperationException(
                "SQL SÖZLEŞMESİ — parametre kümesi SQL ile uyuşmuyor. " +
                (missing.Count > 0 ? $"SQL'de var, verilmemiş: {string.Join(", ", missing)}. " : "") +
                (unused.Count > 0 ? $"Verilmiş, SQL'de yok: {string.Join(", ", unused)}. " : "") +
                "Ad yalnız parametre kümesinde yazılır; SQL metnindeki adı da oradan kopyala.");

        return sql;
    }
}

/// <summary>
/// Parametre kümesi — <b>ad burada BİR KEZ, DİZGE olarak yazılır</b>.
/// Anonim nesne kullanılmaz: orada ad yerel değişkenin adıdır ve yeniden adlandırma
/// onu sessizce ayırır (<see cref="SqlContract"/> başlığındaki beş vaka).
/// </summary>
public class SqlParams
{
    private readonly Dictionary<string, object?> values = new(StringComparer.OrdinalIgnoreCase);

    public IEnumerable<string> Names => values.Keys;

    public SqlParams Add(string name, object? value)
    {
        values[name] = value;
        return this;
    }

    public DynamicParameters Build()
    {
        var p = new DynamicParameters();
        foreach (var (k, v) in values) p.Add(k, v);
        return p;
    }
}
