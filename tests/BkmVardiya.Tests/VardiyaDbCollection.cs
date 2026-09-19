using Xunit;

namespace BkmVardiya.Tests;

/// <summary>
/// VERİTABANINA DOKUNAN TESTLER TEK KOLEKSİYONDA — ve bu bir performans kararı değil,
/// bir DOĞRULUK kararı.
///
/// ⚠ ÖLÇÜLDÜ (19.09.2026, V-13'te ortaya çıktı): fikstürün açılış temizliği
///   <c>zz_test_</c> önekli HER ŞEYİ siler — bu bilinçlidir (çökmüş koşumun artığı
///   başka türlü temizlenmez). Ama iki test sınıfı AYRI fikstür örnekleriyle PARALEL
///   koşunca birinin açılışı ÖTEKİNİN kullanıcılarını koşum ortasında siliyor:
///   oturum düşüyor, sayfa boş dönüyor ve hata "KPI bulunamadı" diye okunuyor —
///   yani kapsam testi, kapsamla İLGİSİ OLMAYAN bir sebeple kırmızı veriyor.
///
/// Koleksiyon fikstürü ikisini de TEK örnek üzerinde ve SIRAYLA koşturur: tek
/// açılış, tek temizlik.
///
/// ⚠ Alternatif (temizliği yalnız kendi damgasına daraltmak) REDDEDİLDİ: o zaman
///   çökmüş koşumların artığı sonsuza dek kalırdı — insanların giriş yaptığı bir
///   veritabanında bilinmeyen test kullanıcıları. Geniş temizlik korunuyor, paralellik
///   kaldırılıyor.
/// </summary>
[CollectionDefinition(Name)]
public sealed class VardiyaDbCollection : ICollectionFixture<VardiyaAppFactory>
{
    public const string Name = "vardiya-db";
}
