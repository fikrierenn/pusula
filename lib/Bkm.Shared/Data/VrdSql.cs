using System.Data;
using System.Text.RegularExpressions;
using Dapper;

namespace Bkm.Shared.Data;

/// <summary>
/// VARDİYA SORGU BOĞAZI — plan 48 / V-09.
///
/// NEDEN VAR (üç ölçülmüş sızıntı, üçü de derleme temizken):
/// <list type="number">
/// <item>19.09 — sekiz sorguya elle kapsam süzgeci eklendi, <b>biri atlandı</b>.</item>
/// <item>19.09 — kapsam vardı ama <b>devir alt-sorgusunda yoktu</b>: müdür kendi
///       döneminin 334 saatini, tüm şirketin 1.858 saatlik devrini görüyordu.</item>
/// <item>19.09 — SQL <c>@sube</c> isterken C# <c>branch</c> gönderiyordu; üç sorgu
///       çalışma anında patlıyordu. Aynı sınıf dördüncü kez <c>SaveApprovalAsync</c>'te
///       bulundu (<c>@girisDk</c> ↔ <c>inMin</c>).</item>
/// </list>
///
/// Metin kapısı (<c>tools/vardiya_kapsam_denetimi.py</c>) birincisini yakalar,
/// ikincisini zor yakalar, üçüncüsünü <b>hiç</b> yakalamaz: "süzgeç var mı" diye
/// sorar, "süzgeç çalışıyor mu" diye sormaz. Solum'un ölçümü (19.09): hiçbir araç
/// (BannedApiAnalyzers, ArchUnitNET, NetArchTest) bir <b>birlikte-bulunma</b>
/// gereksinimini ifade edemez — onu yalnız YAPI çözer.
///
/// BU SINIFIN VERDİĞİ İKİ GARANTİ:
/// <list type="bullet">
/// <item><b>Kapsam unutulamaz.</b> Kapsamlı tabloya erişen tek yol
///       <see cref="PersonDays"/> / <see cref="Carryover"/>; süzgeç kaynağın
///       İÇİNDEDİR. Alt-sorgu da aynı sabiti kullandığı için otomatik kapsanır —
///       kapsam tablo adının değil <b>kaynağın</b> üstünde yaşar.</item>
/// <item><b>Parametre adı çatallanamaz.</b> Ad yalnız <see cref="VrdParams"/>'ta
///       yazılır (anonim nesne YOK: orada ad = yerel değişken adıdır ve yeniden
///       adlandırma onu sessizce ayırır). Üstüne her çağrıda SQL'deki
///       <c>@token</c> kümesi ile parametre kümesi KARŞILAŞTIRILIR.</item>
/// </list>
///
/// ⚠ ATLATMA YOLU ARANDI (Solum'un uyarısı: "bu tipi atlatmanın sessiz bir yolu
///   var mı?"). Bilinen ikisi AÇIKÇA yazılıyor:
///   (a) Bu sınıfı hiç kullanmayıp doğrudan <c>cn.QueryAsync</c> çağırmak —
///       derleyici engellemez, <c>tools/vardiya_kapsam_denetimi.py</c> yakalar.
///   (b) Ham tablo adını başka bir dosyada yazmak — aynı kapı yakalar.
///   Yani YAPI + KAPI birlikte çalışır; yapı tek başına yetmez ve öyleymiş gibi
///   davranılmıyor.
/// </summary>
public static class VrdSql
{
    /// <summary>
    /// KAPSAMLI kişi-gün kaynağı. <c>FROM {VrdSql.PersonDays} k</c> biçiminde kullanılır;
    /// takma ad ZORUNLUDUR (türetilmiş tablo).
    /// </summary>
    public const string PersonDays = """
        (SELECT * FROM bkm.Vrd_KisiGun
          WHERE Sube IN (SELECT Sube FROM bkm.Vrd_SubeKapsami(@userId)))
        """;

    /// <summary>
    /// KAPSAMLI devir kaynağı. Devir ay kapanışında bir kez yazılır ama yayınlanan
    /// raporun TOPLAMINA girer — kapsamsız hâli ikinci sızıntıyı doğurmuştu.
    /// </summary>
    public const string Carryover = """
        (SELECT * FROM bkm.Vrd_Devir
          WHERE Sube IN (SELECT Sube FROM bkm.Vrd_SubeKapsami(@userId)))
        """;

    // `bkm.Vrd_Onay` BİLEREK boğazda değil: kapsam taşımaz, kimliği SicilNo+Tarih'tir
    // ve kapsamı ona `PersonDays` üstünden EXISTS/guard ile bağlanır. Kapsamsız bir
    // tabloyu boğaza koymak, boğazın ne için olduğunu bulanıklaştırırdı.

    // @@ROWCOUNT gibi çift-at'lı sistem değişkenleri parametre DEĞİLDİR; desen
    // tek '@' ile başlayanı alır ve öncesinde '@' olmamasını şart koşar.
    private static readonly Regex Token = new(@"(?<!@)@([A-Za-z_][A-Za-z0-9_]*)",
        RegexOptions.Compiled);

    /// <summary>
    /// SQL'deki <c>@token</c> kümesi ile verilen parametre kümesini KARŞILAŞTIRIR.
    /// İki yönlü: eksik parametre çalışma anında <c>Must declare the scalar variable</c>
    /// verirdi (dört kez oldu), fazla parametre ise SQL'in o değeri hiç kullanmadığını
    /// yani süzgecin sessizce düştüğünü gösterir.
    /// </summary>
    private static string Verify(string sql, VrdParams p)
    {
        var used = Token.Matches(sql).Select(m => m.Groups[1].Value)
                        .ToHashSet(StringComparer.OrdinalIgnoreCase);
        var given = p.Names.ToHashSet(StringComparer.OrdinalIgnoreCase);

        var missing = used.Except(given).OrderBy(x => x).ToList();
        // `userId` kapsam çapasıdır ve HER çağrıda bulunur; kapsam taşımayan bir
        // sorguda (ör. Vrd_Onay okuması) SQL'de geçmemesi kusur değildir. Diğer
        // her ad için "verilmiş ama SQL'de yok" bir bulgudur: süzgeç sessizce düşmüş
        // ya da SQL'deki adı ayrılmış demektir.
        var unused = given.Except(used).Where(n => !n.Equals("userId", StringComparison.OrdinalIgnoreCase))
                          .OrderBy(x => x).ToList();

        if (missing.Count > 0 || unused.Count > 0)
            throw new InvalidOperationException(
                "VARDİYA SORGU BOĞAZI — parametre kümesi SQL ile uyuşmuyor. " +
                (missing.Count > 0 ? $"SQL'de var, verilmemiş: {string.Join(", ", missing)}. " : "") +
                (unused.Count > 0 ? $"Verilmiş, SQL'de yok: {string.Join(", ", unused)}. " : "") +
                "Ad yalnız VrdParams'ta yazılır; SQL metnindeki adı da oradan kopyala.");

        return sql;
    }

    public static async Task<IReadOnlyList<T>> QueryAsync<T>(
        IDbConnection cn, string sql, VrdParams p, IDbTransaction? tx = null)
        => (await cn.QueryAsync<T>(Verify(sql, p), p.Build(), tx)).AsList();

    public static Task<T?> QuerySingleOrDefaultAsync<T>(
        IDbConnection cn, string sql, VrdParams p, IDbTransaction? tx = null)
        => cn.QuerySingleOrDefaultAsync<T?>(Verify(sql, p), p.Build(), tx);

    public static Task<T?> ExecuteScalarAsync<T>(
        IDbConnection cn, string sql, VrdParams p, IDbTransaction? tx = null)
        => cn.ExecuteScalarAsync<T?>(Verify(sql, p), p.Build(), tx);

    public static Task<int> ExecuteAsync(
        IDbConnection cn, string sql, VrdParams p, IDbTransaction? tx = null)
        => cn.ExecuteAsync(Verify(sql, p), p.Build(), tx);
}

/// <summary>
/// Vardiya sorgularının parametre kümesi. <b>Ad burada BİR KEZ yazılır.</b>
///
/// ⚠ Anonim nesne (<c>new { userId, bas, bit }</c>) KULLANILMAZ: orada parametre adı
///   yerel değişkenin adıdır, dolayısıyla bir yeniden adlandırma SQL'deki adı sessizce
///   ayırır. Dört kez bu oldu. Burada ad bir dizgedir ve değişken adından bağımsızdır.
///
/// ⚠ <see cref="For"/> <c>userId</c>'yi ZORUNLU alır: kapsamlı kaynaklar
///   (<see cref="VrdSql.PersonDays"/>) <c>@userId</c> ister, yani parametresiz bir
///   kapsam sorgusu kurulamaz.
/// </summary>
public sealed class VrdParams
{
    private readonly Dictionary<string, object?> values = new(StringComparer.OrdinalIgnoreCase);

    private VrdParams(string userId)
    {
        if (string.IsNullOrWhiteSpace(userId))
            throw new ArgumentException("userId boş olamaz — şube kapsamı çözülemez.", nameof(userId));
        values["userId"] = userId;
    }

    /// <summary>Kapsam sahibi. Her vardiya sorgusu buradan başlar.</summary>
    public static VrdParams For(string userId) => new(userId);

    public IEnumerable<string> Names => values.Keys;

    /// <summary>Kesim aralığı → <c>@bas</c> / <c>@bit</c>.</summary>
    public VrdParams Cutoff(DateOnly bas, DateOnly bit)
    {
        values["bas"] = bas.ToDateTime(TimeOnly.MinValue);
        values["bit"] = bit.ToDateTime(TimeOnly.MinValue);
        return this;
    }

    /// <summary>
    /// Görüntü filtresi → <c>@branch</c>. YETKİ DEĞİLDİR: kapsam İÇİNDE daraltır,
    /// uydurulmuş değer kesişimde düşer. Boş/boşluk → NULL (süzgeç kapalı).
    /// </summary>
    public VrdParams Branch(string? branch)
    {
        values["branch"] = string.IsNullOrWhiteSpace(branch) ? null : branch;
        return this;
    }

    /// <summary>Kişi-gün kimliği → <c>@sicilNo</c> / <c>@tarih</c>.</summary>
    public VrdParams StaffDay(string sicilNo, DateOnly tarih)
    {
        values["sicilNo"] = sicilNo;
        values["tarih"] = tarih.ToDateTime(TimeOnly.MinValue);
        return this;
    }

    /// <summary>Adı üstünde: serbest parametre. Ad DİZGE olarak verilir.</summary>
    public VrdParams Add(string name, object? value)
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
