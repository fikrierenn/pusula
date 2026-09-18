using System.Text.Json;
using Dapper;

namespace Bkm.Shared.Data;

/// <summary>
/// Denetim izi yazıcısı — <c>bkm.SolumAuditTrail</c> (Solum 0025 şeması).
///
/// NEDEN KENDİ YAZICIMIZ: Solum'un denetim izi EF Core tarafında otomatik
/// dolar (<c>SaveChanges</c> kancası). Biz Dapper + SP kullanıyoruz, o makineye
/// hiç girmiyoruz — tabloyu kendimiz yazıyoruz. Tablo AYNI, yani ileride EF
/// tarafı gelirse iki kaynak değil tek tablo olur.
///
/// ⚠ İZ, İŞLEMİN KENDİSİYLE AYNI BAĞLANTIDA yazılır. Ayrı bağlantı/ayrı işlem
///   olsaydı onay yazılıp iz yazılmayan bir aralık doğardı ve o aralık tam olarak
///   denetimin sorduğu yerdir.
/// ⚠ İZ YAZILAMAZSA İŞLEM DE YAZILMAZ: hata yutulmaz, yukarı fırlar. "Kaydettim
///   ama izini tutamadım" bir denetim izi sisteminde kabul edilemez — sessiz
///   kalması, hiç tutmamaktan kötüdür.
/// </summary>
public static class AuditTrail
{
    /// <summary>Solum <c>AuditAction</c> karşılıkları (0025 betiğindeki int kolon).</summary>
    public enum Action { Created = 0, Updated = 1, Deleted = 2 }

    /// <summary>
    /// Bir kaydın izini yazar. <paramref name="changes"/> serbest bir nesnedir
    /// ve JSON'a çevrilir — eski/yeni değer birlikte verilmelidir, yoksa iz
    /// "ne değişti" sorusuna cevap veremez.
    /// </summary>
    public static Task WriteAsync(
        System.Data.Common.DbConnection cn,
        string entityName, string recordId, Action action,
        string userId, string? userName, object changes,
        System.Data.Common.DbTransaction? tx = null)
    {
        var json = JsonSerializer.Serialize(changes,
            new JsonSerializerOptions { Encoder = System.Text.Encodings.Web.JavaScriptEncoder.UnsafeRelaxedJsonEscaping });

        return cn.ExecuteAsync("""
            INSERT INTO bkm.SolumAuditTrail (EntityName, RecordId, [Action], UserId, UserName, [At], CompanyId, Changes)
            VALUES (@entityName, @recordId, @action, @userId, @userName, SYSDATETIMEOFFSET(), NULL, @json)
            """,
            new { entityName, recordId, action = (int)action, userId, userName, json },
            transaction: tx);
    }
}
