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
        "katyol" => KategoriYolu(s),
        "kat3" => s.Kat3,
        "kat4" => s.Kat4,
        "kat1" => s.Kat1,
        "kat2" => s.Kat2,
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
        // SİPARİŞ (plan-46) — hesap SQL'de (SatisAnaliziQueries.Siparis.cs), burada yalnız eşleme.
        // 0 öneri "sipariş yok" demek; hücrede "—" görünür (Metin() null/0 ayrımı: 0 sayıdır,
        // "0" yazılır ve bu DOĞRUdur — ihtiyaç yok demektir).
        "siparis_oneri" => s.SiparisOneri,
        "siparis_kapak" => s.SiparisKapak,
        "siparis_taban" => s.SiparisTaban,
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

    /// <summary>
    /// KATEGORİ YOLU — <c>KatAna → Kat1 → Kat2 → Kat3 → Kat4</c> tek satırda.
    /// GMY 14.09.2026: <i>"kat ana yı Kırtasiye→Defterler→bla bla diye yazsan satır bazlı"</i>
    /// + <i>"kaç kat varsa"</i>.
    ///
    /// ⚠ <c>Kategori1</c> alanı aslında <c>UrunBilgi.KatAna</c>'dır (taban kolonu öyle kurulmuş,
    /// ad yanıltıcı). Yolun ilk basamağı odur.
    /// ⚠ <c>Kategori3</c> BU YOLA GİRMEZ — AYRI bir sözlük (<c>urnKtgr2.ktgrAd</c>); "Çocuk
    /// Kitabı" derken KatAna "Çocuk Kitapları" diyebiliyor. İkisini tek yolda birleştirmek
    /// olmayan bir hiyerarşi uydurmak olurdu.
    /// ⚠ AĞAÇ DENGESİZ, yol kısa görünürse veri eksik demek DEĞİL: doluluk Kat1 %88,2 ·
    /// Kat2 %21,9 · Kat3 %8,7 · Kat4 %5,7 (Kat5 %0,0 — alınmadı). Kırtasiye iki basamakta
    /// biter, sınav hazırlık beşe iner.
    /// Boş basamak ATLANIR; aradaki boşluk yolu kırmaz.
    /// </summary>
    private static string KategoriYolu(SatisAnaliziSatir s)
    {
        var p = new List<string>(5);
        void Ek(string? v) { if (!string.IsNullOrWhiteSpace(v)) p.Add(v.Trim()); }
        Ek(s.Kategori1); Ek(s.Kat1); Ek(s.Kat2); Ek(s.Kat3); Ek(s.Kat4);
        return p.Count == 0 ? "" : string.Join(" → ", p);
    }
}
