using GmDashboard.Models;

namespace GmDashboard.Data;

/// <summary>
/// Excel "Detay" sayfası satırı — drill ekranındaki TÜRETİLMİŞ ölçüler.
///
/// ⚠ Hesaplar drill ile AYNI metotlardan geçer (<see cref="UrunHiz"/>): sezon/sezon-dışı hız,
/// sıçramalılık, tükenme simülasyonu. Kopyalanmaz — emitter-ayrimi kuralı: bir çekirdek,
/// çok çıktı. Buradaki kod yalnız BİÇİM (sütun adı, sıra), iş mantığı değil.
/// </summary>
public static class ExcelDetayCevir
{
    public static IDictionary<string, object?> Satir(ExcelDetaySatir x, SatisAnaliziFiltre f)
    {
        // Gün sayıları takvimden — drill'deki GetHizAsync ile aynı yöntem.
        var bas = f.Kesim.AddDays(-364);
        int sezonGun = 0, disiGun = 0;
        for (var g = bas; g <= f.Kesim; g = g.AddDays(1))
        {
            if (g.Month is 8 or 9 or 10) sezonGun++; else disiGun++;
        }
        var hiz = new UrunHiz(x.SezonAdet, sezonGun, x.DisiAdet, disiGun);
        var tuk = hiz.Tukenme(x.MagazaStok, f.Kesim);

        // Etkin gün: ürün rafa yeni girdiyse payda daralır (drill ile aynı kural).
        var etkinGun = x.IlkGiris is { } ig
            ? Math.Clamp((f.Kesim.ToDateTime(TimeOnly.MinValue) - ig).Days + 1, 1, 365)
            : 365;
        decimal? rafGunStok = x.SatisToplam <= 0 || etkinGun < 28
            ? null
            : Math.Round(x.MagazaStok / (x.SatisToplam / (decimal)etkinGun), 0);

        // KDV: satış fiyatı KDV DAHİL, maliyet KDV HARİÇ (ölçüldü 09.09) → aynı tabana çekilir.
        decimal? netSatis = x.KdvOran is { } o && x.SatisFiyat > 0
            ? x.SatisFiyat / (1m + o / 100m) : null;
        var birimKar = netSatis - x.BirimMaliyet;
        decimal? brutMarj = netSatis > 0 && birimKar is not null ? birimKar / netSatis * 100m : null;
        decimal? markup = x.BirimMaliyet > 0 && birimKar is not null ? birimKar / x.BirimMaliyet * 100m : null;

        var tedarik = x.SonAlis is null ? "son 365g alış yok"
            : x.TedarikOdakAdet > 0 && x.TedarikDigerAdet <= 0 ? "ODAK"
            : x.TedarikOdakAdet > 0 ? "ODAK + başka tedarikçi"
            : "ODAK DIŞI — leadTime geçersiz";

        return new Dictionary<string, object?>
        {
            ["stkID"] = x.StkId,
            ["Ürün"] = x.StkAd,
            ["Kategori3"] = x.Kategori3,
            ["Raf stoğu"] = x.MagazaStok,
            ["Merkez stoğu"] = x.MerkezStok,
            ["Satış 365g"] = x.SatisToplam,
            ["Raf gün-stoğu"] = rafGunStok,
            ["Etkin gün (payda)"] = etkinGun,
            ["Sezon günlük"] = hiz.SezonGun > 0 ? Math.Round(hiz.SezonHiz, 2) : null,
            ["Sezon dışı günlük"] = hiz.DisiGun > 0 ? Math.Round(hiz.DisiHiz, 2) : null,
            ["Sezon ağırlığı"] = hiz.OranGuvenilir && hiz.Kat is { } k ? Math.Round(k, 1) : null,
            ["Sezon yorumu"] = !hiz.OranGuvenilir ? $"veri az ({hiz.Toplam:N0} adet)"
                : hiz.Kat is null ? "sezon dışı satış yok"
                : hiz.Kat >= 1.5m ? "sezonluk"
                : hiz.Kat <= 0.67m ? "sezon dışı daha hızlı" : "sezon farkı zayıf",
            ["Tükenme tarihi (tahmin)"] = tuk?.Tarih.ToDateTime(TimeOnly.MinValue),
            ["Tükenmeye gün"] = tuk?.Gun,
            ["Merkez çıkışı 365g"] = x.MerkezCikis,
            ["Merkez çıkış günü"] = x.MerkezCikisGun,
            ["Merkez parti ort."] = x.MerkezCikisGun > 0 ? Math.Round((decimal)x.MerkezCikis / x.MerkezCikisGun, 0) : null,
            ["Merkez çıkışı sıçramalı"] = x.MerkezCikis > 0 && x.MerkezCikisGun <= 5 ? "evet" : "",
            ["ODAK temin (gün)"] = x.LeadTime,
            ["Tedarik kaynağı"] = tedarik,
            ["Son alış"] = x.SonAlis,
            ["Birim maliyet (KDV hariç)"] = x.BirimMaliyet,
            ["Fatura sayısı"] = x.FaturaSayisi,
            ["KDV %"] = x.KdvOran,
            ["Satış fiyatı (etiket)"] = x.SatisFiyat,
            ["Satış (KDV hariç)"] = netSatis is null ? null : Math.Round(netSatis.Value, 2),
            ["Birim brüt kâr"] = birimKar is null ? null : Math.Round(birimKar.Value, 2),
            ["Brüt marj %"] = brutMarj is null ? null : Math.Round(brutMarj.Value, 1),
            ["Markup %"] = markup is null ? null : Math.Round(markup.Value, 1),
            ["Bağlanan para (maliyetle)"] = x.BirimMaliyet is { } bm ? Math.Round(x.ToplamStok * bm, 0) : null,
            ["Rafa ilk giriş"] = x.IlkGiris,
        };
    }
}
