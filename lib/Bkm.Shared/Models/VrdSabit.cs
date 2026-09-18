namespace Bkm.Shared.Models;

/// <summary>
/// Vardiya/mesai sabitleri — İŞ KURALLARININ TEK C# KAYNAĞI.
///
/// NEDEN VAR (19.09.2026 denetimi): aynı tanım üç yerde tekrarlanıyordu ve
/// `emitter-ayrimi.md` bunu yasaklıyor — bir iş kuralı emitter'a dağılırsa biri
/// güncellenir, ötekiler bayatlar ve kimse görmez.
///
/// ⚠ İKİNCİ KAYNAK PYTHON'DA: <c>tools/mesai_mevzuat_kapisi.py</c> aynı eşikleri
///   taşıyor. İki dil arasında ortak sabit yok; onun yerine <b>koşulabilir bir
///   kapı</b> var: <c>tools/mesai_esik_denetimi.py</c> iki tarafı karşılaştırır ve
///   saparsa KIRIK verir. Yorumla "aynı olmalı" demek kapı değildir.
/// </summary>
public static class VrdSabit
{
    /// <summary>Şüpheli okutma ayracı — <c>OlcumNotu</c> içinde aranan metin.</summary>
    public const string SupheliMetin = "ŞÜPHELİ";

    /// <summary>Aynı ayracın SQL <c>LIKE</c> deseni. Sorgulara PARAMETRE olarak geçer.</summary>
    public const string SupheliDesen = "%ŞÜPHELİ%";
}

/// <summary>
/// 4857 sayılı İş Kanunu sert sınırları — dakika cinsinden.
/// Python karşılığı: <c>tools/mesai_mevzuat_kapisi.py</c> (aynı adlar, aynı değerler).
/// Değer değişirse İKİ tarafta birden değişir; kapı bunu zorlar.
/// </summary>
public static class MesaiEsik
{
    /// <summary>m.63 / m.41 — günlük 11 saat. NET süredir (m.68: ara dinlenme çalışmadan sayılmaz).</summary>
    public const int GunlukTavanDk = 11 * 60;            // 660

    /// <summary>m.68 — 24 saatte kesintisiz 12 saat dinlenme ⇒ işyerinde geçen BRÜT süre tavanı.</summary>
    public const int GunlukBrutTavanDk = 12 * 60;        // 720

    /// <summary>m.69 — gece çalışması 7,5 saat.</summary>
    public const int GeceTavanDk = 7 * 60 + 30;          // 450

    /// <summary>Gece penceresi başlangıcı — 20:00.</summary>
    public const int GeceBasDk = 20 * 60;                // 1200

    /// <summary>Gece penceresi bitişi — ertesi 06:00 (gün dönümü aşıldığı için 30:00).</summary>
    public const int GeceBitDk = 30 * 60;                // 1800

    /// <summary>m.63 — haftalık normal çalışma sınırı. ⚠ Aşmak İHLAL DEĞİL, fazla çalışmadır.</summary>
    public const int HaftalikNormalDk = 45 * 60;         // 2700

    /// <summary>İkinci günün gece penceresi — çıkış 1440'ı aşabildiği için pencere iki gün taranır.</summary>
    public const int GeceBasDk2 = 1440 + GeceBasDk;      // 2640
    public const int GeceBitDk2 = 1440 + GeceBitDk;      // 3240
}
