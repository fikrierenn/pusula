using System.Data;
using Bkm.Shared.Data;
using Dapper;

namespace BkmVardiya.Security;

/// <summary>
/// KİMLİK / ACL SORGU BOĞAZI — plan 48 / V-11.
///
/// NEDEN AYRI BİR BOĞAZ (ve neden Dapper'ı burada da yasaklıyoruz):
/// V-10 yasağı yalnız <c>lib/Bkm.Shared</c>'daydı. V-11'de bu uygulamanın Dapper
/// kullanımı ÖLÇÜLDÜ — 5 çağrı, 2 dosya, hepsi kimlik/ACL:
/// <c>Vrd_Roles · Vrd_UserRoles · Vrd_KullaniciSube · Vrd_Sube · SolumPermissionGrant</c>.
/// Kapsamlı kişi-gün verisi YOK, yani vardiya boğazı buraya uymuyordu.
///
/// ⚠ ÖLÇÜM YASAĞI HAKLI ÇIKARDI: <c>Seed</c>'in ACL yazması SQL'de <c>@sube</c>
///   isterken C# <c>branch</c> gönderiyordu — aynı kusurun BEŞİNCİ örneği. Seed
///   Türkçe→İngilizce yeniden adlandırmadan ÖNCE koşmuştu; kusur koşumdan SONRA
///   girdi ve bir daha koşturulmadığı için görünmedi. Yani kimlik tarafı "riski
///   düşük" değildi, sadece ÖLÇÜLMEMİŞTİ.
///
/// ⚠ SOLUM'UN ÖN KOŞULU KARŞILANDI: yasak, var olan bir boğazı ZORUNLU kılar;
///   yoktan boğaz yaratmaz. Bu dosya o boğazdır — yasak ondan SONRA kondu.
///
/// KAPSAM: burada kapsam ÇAPASI yok (<c>userId</c> zorunlu değil), çünkü bu tablolar
/// şube kapsamı taşımaz. Kapsamın KENDİSİ burada KURULUR (<c>Vrd_KullaniciSube</c>) —
/// o yüzden yazan yolun tek olması ayrıca değerli.
/// </summary>
public static class AuthSql
{
    public static async Task<IReadOnlyList<T>> QueryAsync<T>(
        IDbConnection cn, string sql, SqlParams p, IDbTransaction? tx = null)
        => (await cn.QueryAsync<T>(SqlContract.Verify(sql, p.Names), p.Build(), tx)).AsList();

    public static Task<int> ExecuteAsync(
        IDbConnection cn, string sql, SqlParams p, IDbTransaction? tx = null)
        => cn.ExecuteAsync(SqlContract.Verify(sql, p.Names), p.Build(), tx);

    /// <summary>Parametresiz okuma (sabit liste sorguları). Boş parametre kümesi de doğrulanır.</summary>
    public static Task<IReadOnlyList<T>> QueryAsync<T>(IDbConnection cn, string sql)
        => QueryAsync<T>(cn, sql, new SqlParams());
}
