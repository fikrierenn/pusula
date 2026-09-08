namespace GmDashboard.Models;

/// <summary>
/// Sayfalı sorgu sonucu — 273K satırlık listelerde sayfalayıcının SESSİZ YANLIŞ durumlarını
/// kurucuda reddeder.
///
/// NEDEN KENDİ TİPİMİZ: D:\Dev\Solum'da aynı sözleşme (<c>Solum.Core</c> → <c>PagedResult&lt;T&gt;</c>)
/// ölçülmüş değişmezlerle var ve Solum oturumu paketi almamızı önerdi (08.09.2026 danışma).
/// ALINMADI, iki ölçümle: (a) pusula'da <c>nuget.config</c> YOK → yerel dosya feed'i build'i
/// <c>D:\Dev\solum\.build\packages</c> yoluna bağlar, başka makinede restore patlar;
/// (b) <c>Solum.Core</c> = varlık/denetim/depo sözleşme katmanı, pusula ise Dapper + salt-okuma
/// (repository yok, audit entity yok) → kütüphanenin 1/N'i için bağımlılık.
///
/// Solum'un haklı itirazı: "kopyalanan sözleşme sessizce ayrışır." Karşılığı KOPYALAMAMAK değil,
/// AYRIŞMAYI KIRMIZI VERDİRMEK → aşağıdaki çelişkiler kurucuda atılır, testle koşulur.
///
/// Reddedilen çelişkiler (Solum'un ölçtüğü başarısızlıklar; hepsi bu sayfada mümkün):
///  1. <c>ToplamSatir &lt; 0</c> ya da <c>SayfaBoyu &lt;= 0</c> — anlamsız.
///  2. <c>ToplamSatir = 0</c> ama <c>Satirlar</c> DOLU — sayfalayıcı "kayıt bulunamadı" yazarken
///     tabloda satır durur. İkisi aynı anda doğru olamaz → REDDET (error-handling.md § çelişki).
///  3. <c>Satirlar</c> BOŞ ama <c>ToplamSatir &gt; 0</c> ve sayfa 1 — dönüş yolu olmayan ekran.
///     (Sayfa &gt; 1'de MEŞRU: kullanıcı son sayfayı aşmış olabilir → <see cref="SayfaAsildi"/>.)
///  4. Ardışık <c>int</c> parametreler yanlış sırayla SESSİZCE derlenir → kurucu adlandırılmış
///     parametre gerektirsin diye <c>Olustur</c> fabrikası kullanılır, <c>new</c> değil.
/// </summary>
public sealed record SayfaSonucu<T>
{
    private SayfaSonucu(IReadOnlyList<T> satirlar, int toplamSatir, int sayfa, int sayfaBoyu)
    {
        Satirlar = satirlar;
        ToplamSatir = toplamSatir;
        Sayfa = sayfa;
        SayfaBoyu = sayfaBoyu;
    }

    public IReadOnlyList<T> Satirlar { get; }

    /// <summary>Filtreye uyan TÜM satır sayısı (sayfadaki değil).</summary>
    public int ToplamSatir { get; }

    /// <summary>1-tabanlı sayfa numarası.</summary>
    public int Sayfa { get; }

    public int SayfaBoyu { get; }

    public int SayfaSayisi => ToplamSatir == 0 ? 0 : (ToplamSatir + SayfaBoyu - 1) / SayfaBoyu;

    /// <summary>Kullanıcı son sayfayı aştı (satır yok ama kayıt var) — ekranda "başa dön" gerekir.</summary>
    public bool SayfaAsildi => Satirlar.Count == 0 && ToplamSatir > 0;

    public bool Bos => ToplamSatir == 0;

    /// <summary>
    /// Tek kurucu yolu. Adlandırılmış parametre ZORUNLU değil ama isim uzunlukları farklı
    /// olduğu için karıştırma derlenmez hale gelmez — bu yüzden çelişki kontrolü de burada.
    /// </summary>
    public static SayfaSonucu<T> Olustur(IReadOnlyList<T> satirlar, int toplamSatir, int sayfa, int sayfaBoyu)
    {
        ArgumentNullException.ThrowIfNull(satirlar);
        if (sayfaBoyu <= 0)
            throw new ArgumentOutOfRangeException(nameof(sayfaBoyu), sayfaBoyu, "Sayfa boyu pozitif olmalı.");
        if (sayfa <= 0)
            throw new ArgumentOutOfRangeException(nameof(sayfa), sayfa, "Sayfa 1-tabanlıdır.");
        if (toplamSatir < 0)
            throw new ArgumentOutOfRangeException(nameof(toplamSatir), toplamSatir, "Toplam satır negatif olamaz.");

        // ÇELİŞKİ 2: sayfalayıcı "kayıt yok" der, tablo satır gösterir.
        if (toplamSatir == 0 && satirlar.Count > 0)
            throw new InvalidOperationException(
                $"Çelişki: ToplamSatir=0 ama {satirlar.Count} satır geldi. " +
                "COUNT sorgusu ile liste sorgusunun filtresi ayrışmış olabilir.");

        // Sayfa dolu ama sayfa boyundan fazla satır → OFFSET/FETCH ile liste sorgusu uyuşmuyor.
        if (satirlar.Count > sayfaBoyu)
            throw new InvalidOperationException(
                $"Çelişki: {satirlar.Count} satır geldi, sayfa boyu {sayfaBoyu}.");

        return new SayfaSonucu<T>(satirlar, toplamSatir, sayfa, sayfaBoyu);
    }

    public static SayfaSonucu<T> BosSonuc(int sayfaBoyu) => Olustur([], 0, 1, sayfaBoyu);
}
