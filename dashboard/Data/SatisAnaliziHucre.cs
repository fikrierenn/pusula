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
        "songiris" => s.SonGirisTarihi,
        "stok_fsm" => s.StokFsm,
        "stok_ozl" => s.StokOzluce,
        "stok_ist" => s.StokIstyolu,
        "magaza_stok" => s.MagazaStok,
        "merkez_stok" => s.MerkezStok,
        "merkez_cikis" => s.MerkezCikis,
        "satis_fsm" => s.SatisFsm,
        "satis_ozl" => s.SatisOzluce,
        "satis_ist" => s.SatisIstyolu,
        "satis" => s.SatisToplam,
        "gunluk" => s.GunlukOrtalamaSatis,
        "ay1" => s.SezonAy1,
        "ay2" => s.SezonAy2,
        "ay3" => s.SezonAy3,
        "sezon" => s.SezonToplam,
        "sezon_kapsama" => s.SezonKapsama,
        "gun_stok" => s.GunStok,
        "acilis" => s.AcilisTarihi,
        "yas" => s.YasYil,
        "odak_durum" => s.OdakSatisDurum,
        _ => null,
    };
}
