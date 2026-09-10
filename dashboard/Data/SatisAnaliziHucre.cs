using GmDashboard.Models;

namespace GmDashboard.Data;

/// <summary>
/// Kolon anahtarı → satır değeri. Ekran tablosu ve Excel endpoint'i AYNI yerden okur.
///
/// ⚠ NEDEN ORTAK: eşleme eskiden yalnız Razor'un içindeydi; Excel indirmesi endpoint'e
/// taşınınca (circuit çöküyordu — 275 bin satır base64) ikinci bir kopya gerekiyordu.
/// İki kopya = ekran bir değer, Excel başka değer riski. Tek yerde tutuluyor.
/// </summary>
public static class SatisAnaliziHucre
{
    public static object? Deger(SatisAnaliziSatir s, string anahtar) => anahtar switch
    {
        "kategori3" => s.Kategori3,
        "stkid" => s.StkId,
        "barkod" => s.BarkodAna,
        "ad" => s.StkAd,
        "kategori1" => s.Kategori1,
        "yayinevi" => s.Yayinevi,
        "yazar" => s.Yazar,
        "fiyat" => s.SatisFiyat,
        "tutar" => s.ToplamStokTutar,
        "stok" => s.ToplamStok,
        "odak" => s.OdakStok,
        "leadtime" => s.LeadTime,
        "ilkgiris" => s.IlkGirisTarihi,
        "sonsatis" => s.SonSatisTarihi,
        "talepdeseni" => s.TalepDeseniAd,
        "satanay" => s.SatanAy,
        "maliyettarih" => s.MaliyetTarih,
        "maliyetyas" => s.MaliyetYasGun,
        "songiris" => s.SonGirisTarihi,
        "stok_fsm" => s.StokFsm,
        "stok_ozl" => s.StokOzluce,
        "stok_ist" => s.StokIstyolu,
        "magaza_stok" => s.MagazaStok,
        "merkez_stok" => s.MerkezStok,
        // ⚠ Kolon tanımı YOK (Models.SatisAnaliziKolonlar) → hiçbir çıktıda seçilemez.
        // Silinmedi: satırda veri var, kolon eklenirse çalışır. Silmek öğrenilen eşlemeyi
        // atmak olurdu.
        "merkez_cikis" => s.MerkezCikis,
        "satis_fsm" => s.SatisFsm,
        "satis_ozl" => s.SatisOzluce,
        "satis_ist" => s.SatisIstyolu,
        "satis" => s.SatisToplam,
        "gunluk" => s.GunlukOrtalamaSatis,
        "sezon_ay1" => s.SezonAy1,
        "sezon_ay2" => s.SezonAy2,
        "sezon_ay3" => s.SezonAy3,
        "sezon" => s.SezonToplam,
        "kapsama" => s.SezonKapsama,
        "gun_stok" => s.GunStok,
        "acilis" => s.AcilisTarihi,
        "yas" => s.YasYil,
        "odak_durum" => s.OdakSatisDurum,
        _ => null,
    };

    /// <summary>
    /// EKRAN METNİ — <see cref="Deger"/>'in üstüne biçim. Razor'daki yerel kopya
    /// kaldırıldı (10.09.2026); orada anahtarlar da FARKLI yazılmıştı ve iki yönlü sessiz
    /// veri kaybı üretiyordu: ekranda <c>sonsatis</c>/<c>talepdeseni</c>/<c>satanay</c> boş,
    /// Excel'de <c>kapsama</c> ve <c>sezon_ay1..3</c> boş. Anahtar kümesi artık tek:
    /// kanonik kaynak <c>Models.SatisAnaliziKolonlar</c>.
    /// </summary>
    public static string Metin(SatisAnaliziSatir s, string anahtar) => Deger(s, anahtar) switch
    {
        null => "—",
        string t => string.IsNullOrWhiteSpace(t) ? "—" : t,
        DateTime d => d.ToString("dd.MM.yyyy"),
        // Kapsama "x" ile yazılır (5,2x = sezon satışının 5,2 katı stok)
        decimal v when anahtar == "kapsama" => v.ToString("N1") + "x",
        double v when anahtar == "gunluk" => v.ToString("N2"),
        decimal v when anahtar == "gunluk" => v.ToString("N2"),
        decimal v => v.ToString("N0"),
        double v => v.ToString("N2"),
        int v => v.ToString("N0"),
        long v => v.ToString("N0"),
        var o => o.ToString() ?? "—",
    };
}
