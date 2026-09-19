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
    ///
    /// ⚠ KAYNAK ARTIK VIEW (plan 49 / V-05): <c>bkm.Vrd_KisiGunDuzeltilmis_vw</c>
    ///   ölçülen kişi-günü insan düzeltmesiyle birleştirir. Ham tabloya dönülürse
    ///   düzeltmeler SESSİZCE görünmez olur — rakam değişmez, yalnız düzeltme yok
    ///   sayılır. Düzeltme yokken view ham tabloyla BİREBİR aynıdır (mutabakat 0/0).
    /// </summary>
    public const string PersonDays = """
        (SELECT * FROM bkm.Vrd_KisiGunDuzeltilmis_vw
          WHERE Sube IN (SELECT Sube FROM bkm.Vrd_SubeKapsami(@userId)))
        """;

    /// <summary>
    /// KAPSAMLI devir kaynağı. Devir ay kapanışında bir kez yazılır ama yayınlanan
    /// raporun TOPLAMINA girer — kapsamsız hâli ikinci sızıntıyı doğurmuştu.
    ///
    /// ⚠ İKİNCİ EKSEN: <c>@donem</c> (V-20, 19.09.2026). Kapsam süzgeci EKLENMİŞTİ ama
    ///   DÖNEM süzgeci yoktu: <see cref="Vrd_Devir"/> dönem bazlıdır ve süzgeçsiz hâl
    ///   HER dönemi toplar. Dev veride tek dönem olduğu için görünmüyordu — bir kesim
    ///   ve bir dönem varken yanlış kod da doğru sayıyı verir.
    ///   ÖLÇÜLDÜ (simülasyon, sıfır yazma): GENEL MÜDÜRLÜK'e ikinci bir dönem
    ///   eklenince devir eksiği <b>69.563 → 119.563 dk</b> (+50.000) sızıyor;
    ///   dönem süzgeciyle 69.563'te kalıyor.
    ///   Sınıf: `olctum-mu-cikardim-mi.md` § NÜFUS SIFIRSA "GEÇTİ" DEĞİL "BAKAMADIM" —
    ///   burada nüfus sıfır değil ama EKSENİ TEK: tek dönem, ayrımı göstermez.
    /// </summary>
    public const string Carryover = """
        (SELECT * FROM bkm.Vrd_Devir
          WHERE Sube IN (SELECT Sube FROM bkm.Vrd_SubeKapsami(@userId))
            AND Donem = @donem)
        """;

    // `bkm.Vrd_Onay` BİLEREK boğazda değil: kapsam taşımaz, kimliği SicilNo+Tarih'tir
    // ve kapsamı ona `PersonDays` üstünden EXISTS/guard ile bağlanır. Kapsamsız bir
    // tabloyu boğaza koymak, boğazın ne için olduğunu bulanıklaştırırdı.

    // ⚠ Parametre doğrulaması burada DEĞİL: `SqlContract.Verify` ortak çekirdek
    //   (aynı kusur kimlik/ACL tarafında da çıktı — V-11). İki kopya olsaydı biri
    //   bayatlardı ve bayatlayan taraf sessizce koruma bırakırdı.
    private static string Verify(string sql, VrdParams p)
        => SqlContract.Verify(sql, p.Names, anchor: "userId");

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
/// Vardiya sorgularının parametre kümesi — <see cref="SqlParams"/> üstüne kapsam
/// çapası ekler. <b>Ad burada BİR KEZ yazılır</b> (anonim nesne kullanılmaz: orada ad
/// yerel değişkenin adıdır ve yeniden adlandırma onu sessizce ayırır — beş kez oldu).
///
/// ⚠ <see cref="For"/> <c>userId</c>'yi ZORUNLU alır: kapsamlı kaynaklar
///   (<see cref="VrdSql.PersonDays"/>) <c>@userId</c> ister, yani parametresiz bir
///   kapsam sorgusu kurulamaz.
/// </summary>
public sealed class VrdParams : SqlParams
{
    private VrdParams(string userId)
    {
        if (string.IsNullOrWhiteSpace(userId))
            throw new ArgumentException("userId boş olamaz — şube kapsamı çözülemez.", nameof(userId));
        Add("userId", userId);
    }

    /// <summary>Kapsam sahibi. Her vardiya sorgusu buradan başlar.</summary>
    public static VrdParams For(string userId) => new(userId);

    /// <summary>Kesim aralığı → <c>@bas</c> / <c>@bit</c>.</summary>
    public VrdParams Cutoff(DateOnly bas, DateOnly bit)
    {
        Add("bas", bas.ToDateTime(TimeOnly.MinValue));
        Add("bit", bit.ToDateTime(TimeOnly.MinValue));
        return this;
    }

    /// <summary>
    /// Devir dönemi → <c>@donem</c> (<c>'YYYY-MM'</c>). Kesimden TÜRETİLİR,
    /// çağıran uydurmaz — türetme tek yerde: <see cref="VrdPeriod.CarryFor"/>.
    /// </summary>
    public VrdParams CarryPeriod(string donem)
    {
        Add("donem", donem);
        return this;
    }

    /// <summary>
    /// Görüntü filtresi → <c>@branch</c>. YETKİ DEĞİLDİR: kapsam İÇİNDE daraltır,
    /// uydurulmuş değer kesişimde düşer. Boş/boşluk → NULL (süzgeç kapalı).
    /// </summary>
    public VrdParams Branch(string? branch)
    {
        Add("branch", string.IsNullOrWhiteSpace(branch) ? null : branch);
        return this;
    }

    /// <summary>Kişi-gün kimliği → <c>@sicilNo</c> / <c>@tarih</c>.</summary>
    public VrdParams StaffDay(string sicilNo, DateOnly tarih)
    {
        Add("sicilNo", sicilNo);
        Add("tarih", tarih.ToDateTime(TimeOnly.MinValue));
        return this;
    }

    /// <summary>Adı üstünde: serbest parametre. Ad DİZGE olarak verilir.</summary>
    public new VrdParams Add(string name, object? value)
    {
        base.Add(name, value);
        return this;
    }
}


/// <summary>
/// Kesim ↔ devir dönemi eşlemesi. <b>TEK YER</b>: kural değişirse burada değişir.
///
/// ⚠ BU BİR ÇIKARIMDIR, ÖLÇÜM DEĞİL (19.09.2026). Dev veride tek kesim ve tek dönem
///   var (kesim 31.08→16.09, sayım başı 01.09, devir dönemi <c>2026-08</c>), yani
///   <b>n = 1</b>. Üç aday kuralın ÜÇÜ de bu tek noktaya uyuyor:
///     (a) KesimBas'ın ayı · (b) SayimBas'ın BİR ÖNCEKİ ayı · (c) KesimBit'in bir önceki ayı.
///   (b) seçildi çünkü anlamı taşıyan tek kural o: devir, SAYILAN ayın öncesinde
///   KAPANAN ayın bakiyesidir. (a) yalnız KesimBas ayın son günü olduğu için tutuyor;
///   sayım başıyla kesim başı aynı güne gelirse (a) kendi ayını gösterir ve YANLIŞ olur.
///   ⚠ İkinci gerçek kesim yazıldığında bu eşleme ÖLÇÜLMELİ — TODO V-20.
/// </summary>
public static class VrdPeriod
{
    /// <param name="countFrom">Kesimin sayım başlangıcı (<c>Vrd_KisiGun.SayimBas</c>).</param>
    public static string CarryFor(DateOnly countFrom)
        => countFrom.AddMonths(-1).ToString("yyyy-MM");
}
