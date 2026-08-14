using System.Globalization;

namespace GmDashboard.Data;

/// <summary>
/// SABİT takvim sezonları (kaymaz — analiz tarihi kayar, sezon yerinde durur). Verilen ay0'a (son biten ay)
/// göre EN YAKIN gelen sezonu bulur; forecast tabanı = o sezonun GEÇEN YIL occurrence'ı, büyüme paydası = önceki yıl.
/// Tek kaynak: dashboard bu sınıfı kullanır, SQL sezon pencerelerini (@SEZb/@SEZe/@PSEZb/@PSEZe) buradan param alır.
/// BKM kırtasiye/oyuncak sezonları: Yaz (Haz-Tem) · Okul (Ağu-Eki, ana) · Ara Tatil (Kas) · Sömestr (Oca-Şub).
/// </summary>
public static class SatinalmaSezon
{
    public readonly record struct Sezon(int Bas, int Son, string Ad);

    // Çakışmasız, takvim-sırasız (yıl-içi). Aralık/Mart-Mayıs = düşük/genel (sezon değil).
    static readonly Sezon[] Tablo =
    {
        new(6, 7, "Yaz"), new(8, 10, "Okul"), new(11, 11, "Ara Tatil"), new(1, 2, "Sömestr"),
    };
    static readonly string[] AyKisa = { "Oca", "Şub", "Mar", "Nis", "May", "Haz", "Tem", "Ağu", "Eyl", "Eki", "Kas", "Ara" };

    /// <summary>ay0='YYYYMMDD' (son biten ay başı). Sonuç: geçen-yıl sezon [SEZb,SEZe) + önceki-yıl [PSEZb,PSEZe)
    /// (hepsi 'YYYYMMDD'), okunur etiket ("Okul (Ağu-Eki)") ve bu-yıl sezon ay-numaraları ("08","09","10").</summary>
    public static (string SEZb, string SEZe, string PSEZb, string PSEZe, string Ad, string[] AylarMM) Hesapla(string ay0)
    {
        var d = DateTime.ParseExact(ay0, "yyyyMMdd", CultureInfo.InvariantCulture);
        // ay0'dan SONRA başlayan ilk sezon (en yakın gelen).
        Sezon en = default; var enBas = DateTime.MaxValue;
        foreach (var s in Tablo)
        {
            var st = new DateTime(d.Year, s.Bas, 1);
            if (st <= d) st = st.AddYears(1);
            if (st < enBas) { enBas = st; en = s; }
        }
        int gyYil = enBas.Year - 1, pyYil = enBas.Year - 2;   // forecast tabanı = geçen yıl; payda = önceki yıl
        static string Ymd(int yil, int ay) => new DateTime(yil, ay, 1).ToString("yyyyMMdd");
        var sezb = Ymd(gyYil, en.Bas);
        var seze = new DateTime(gyYil, en.Son, 1).AddMonths(1).ToString("yyyyMMdd");
        var psezb = Ymd(pyYil, en.Bas);
        var pseze = new DateTime(pyYil, en.Son, 1).AddMonths(1).ToString("yyyyMMdd");
        var aylarMM = Enumerable.Range(en.Bas, en.Son - en.Bas + 1).Select(m => m.ToString("00")).ToArray();
        var etiket = en.Bas == en.Son
            ? $"{en.Ad} ({AyKisa[en.Bas - 1]})"
            : $"{en.Ad} ({AyKisa[en.Bas - 1]}-{AyKisa[en.Son - 1]})";
        return (sezb, seze, psezb, pseze, etiket, aylarMM);
    }
}
