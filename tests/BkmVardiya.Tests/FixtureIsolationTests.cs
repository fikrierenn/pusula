using System.Reflection;
using Xunit;

namespace BkmVardiya.Tests;

/// <summary>
/// FİKSTÜR YARIŞ KAPISI — V-14.
///
/// NEDEN VAR (ölçüldü 19.09.2026, V-13 koşarken): iki test sınıfı AYRI
/// <see cref="VardiyaAppFactory"/> örneğiyle PARALEL koşuyordu ve fikstürün açılış
/// temizliği <c>zz_test_</c> önekli HER ŞEYİ siliyor — biri ötekinin kullanıcılarını
/// koşum ORTASINDA sildi. Belirti yanıltıcıydı: kapsam testi <i>"KPI bulunamadı"</i>
/// diyerek, <b>kapsamla ilgisi olmayan</b> bir sebeple kırmızı döndü.
///
/// Çözüm koleksiyon fikstürüydü. Ama çözüm bir KONVANSİYONDU: yeni bir DB testi
/// sınıfı <c>[Collection]</c> koymayı unutursa yarış geri gelir ve <b>hiçbir şey
/// uyarmaz</b> — testler çoğu zaman yeşil, ara sıra ve açıklanamaz biçimde kırmızı
/// olur. Sızıntıdan daha kötüsü budur: güvenilmeyen bir kapı, bakılmayan bir kapıya
/// dönüşür.
///
/// Bu test o konvansiyonu MEKANİK hâle getirir: fikstürü isteyen her sınıf
/// koleksiyonda mı?
///
/// ⚠ YAKALAMAZ: fikstürü constructor yerine başka bir yoldan (statik erişim, kendi
///   <c>WebApplicationFactory</c> örneği) kuran bir sınıf. O gün gelirse bu testin
///   ölçütü genişletilir — bugün öyle bir yol YOK ve olmadığı ölçüldü.
/// </summary>
public class FixtureIsolationTests
{
    [Fact]
    public void Every_db_test_class_joins_the_serial_collection()
    {
        var suspects = typeof(FixtureIsolationTests).Assembly.GetTypes()
            .Where(t => t.IsClass && !t.IsAbstract)
            .Where(t => t.GetConstructors()
                         .Any(c => c.GetParameters()
                                    .Any(p => p.ParameterType == typeof(VardiyaAppFactory))))
            .ToList();

        Assert.True(suspects.Count > 0,
            "Fikstürü kullanan HİÇBİR test sınıfı bulunamadı — bu kapı hiçbir şey " +
            "ölçmüyor demektir (KOŞAMADI, yeşil değil).");

        // ⚠ xUnit 2.9'da `CollectionAttribute.Name` OKUNABILIR BIR OZELLIK DEGIL —
        //   deger yalnizca yapici argumaninda durur. `CustomAttributeData` ile
        //   ham argumandan okunuyor.
        var outside = suspects
            .Where(t => CollectionNameOf(t) != VardiyaDbCollection.Name)
            .Select(t => t.Name)
            .ToList();

        Assert.True(outside.Count == 0,
            $"Bu sınıf(lar) veritabanı fikstürünü kullanıyor ama `[Collection(\"{VardiyaDbCollection.Name}\")]` " +
            $"TAŞIMIYOR: {string.Join(", ", outside)}. Paralel koşacaklar ve fikstürün geniş " +
            "temizliği birbirlerinin kullanıcılarını koşum ortasında silecek — testler " +
            "ARA SIRA ve alakasız sebeplerle kırmızı döner.");
    }

    private static string? CollectionNameOf(Type t) =>
        t.GetCustomAttributesData()
         .FirstOrDefault(a => a.AttributeType == typeof(CollectionAttribute))
         ?.ConstructorArguments.FirstOrDefault().Value as string;
}
