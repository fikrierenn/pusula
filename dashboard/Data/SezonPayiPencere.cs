using GmDashboard.Models;

namespace GmDashboard.Data;

/// <summary>
/// Sezon payı zincirinin SQL parametreleri — okul açılışına hizalı pencereler.
///
/// ⚠ PENCEREYİ KENDİ HESAPLAMAZ: tek kaynak <see cref="SezonAksiyonFiltre"/>. Taban
/// dolumu ile panel aynı tarihleri kullanmak zorunda; ikinci bir kopya, okul açılış
/// tablosu güncellenince SESSİZCE bayatlar ve iki taraf farklı pencere ölçer.
///
/// ⚠ GEÇERSİZ PENCERE = NULL PARAMETRE, "makul varsayılan" DEĞİL. Okul açılışı
/// tanımsızsa ya da pencere 14 günün altındaysa <see cref="PencereGecerli"/> 0 olur;
/// SQL tarafında on üç kolon NULL yazılır ve panel KOŞAMADI der. Takvime düşmek
/// tahmini %23,5 saptırıyordu (ölçüldü 15.09.2026) — sessizce yapılmaz.
/// </summary>
public sealed record SezonPayiPencere(
    int PencereGecerli,
    DateTime? GpBas, DateTime? GpSonEx,
    DateTime? BpBas, DateTime? BpSonEx,
    DateTime? BtBas, DateTime? BtSonEx,
    DateTime? GsBas, DateTime? GsSonEx,
    DateTime? GdBas, DateTime? GdSonEx,
    DateTime? YlBas, DateTime? YlSonEx,
    DateTime? SnEyl, DateTime? SnEki)
{
    /// <summary>Boş pencere — hiçbir CTE satır döndürmez, on üç kolon NULL kalır.</summary>
    private static readonly SezonPayiPencere Yok = new(
        0, null, null, null, null, null, null, null, null,
        null, null, null, null, null, null);

    public static SezonPayiPencere Kur(DateOnly kesim, int sezonYil, ILogger? logger = null)
    {
        var f = new SezonAksiyonFiltre(kesim, sezonYil);
        if (!f.AcilisTanimli)
        {
            // Sessiz fallback YASAK — neden ölçülemediği loglanır (error-handling.md).
            logger?.LogWarning(
                "Sezon payı pencereleri kurulamadı: {Sezon} veya {Yil} için okul açılış "
                + "tarihi tanımsız (SezonAksiyonFiltre.OkulAcilis). On üç kolon NULL yazılacak.",
                sezonYil, kesim.Year);
            return Yok;
        }
        if (!f.PencereYeterli)
        {
            logger?.LogWarning(
                "Sezon payı pencereleri kurulamadı: okul öncesi pencere {Gun} gün "
                + "(asgari 14). On üç kolon NULL yazılacak.", f.PencereGun);
            return Yok;
        }

        // ⚠ ÜST SINIR DIŞLAYICI ve GECE YARISI. "<= son gün 23:59:59.9999999" YAZILMAZ:
        //   SQL `datetime` 3,33 ms çözünürlüklü, o değer ERTESİ GÜNE yuvarlanır ve
        //   pencereyi bir gün uzatır (ölçüldü 15.09.2026 — ekran "44 gün" yazıp 45 gün
        //   ölçüyordu, stkID 486093'te 20 adet sapma).
        static DateTime G(DateOnly d) => d.ToDateTime(TimeOnly.MinValue);
        static DateTime Ex(DateOnly d) => d.AddDays(1).ToDateTime(TimeOnly.MinValue);

        var (gp, gps) = f.GecenPencere;
        var (bp, bps) = f.BuPencere;
        var (bt, bts) = f.BuSezon;
        var (gs, gss) = f.GecenSezon;
        var (gd, gds) = f.SezonDisi;
        var (yl, yls) = f.YilPencere;
        var (snE, snK) = f.SansurDonem;

        return new SezonPayiPencere(
            PencereGecerli: 1,
            GpBas: G(gp), GpSonEx: Ex(gps),
            BpBas: G(bp), BpSonEx: Ex(bps),
            BtBas: G(bt), BtSonEx: Ex(bts),
            GsBas: G(gs), GsSonEx: Ex(gss),
            GdBas: G(gd), GdSonEx: Ex(gds),
            YlBas: G(yl), YlSonEx: Ex(yls),
            SnEyl: G(snE), SnEki: G(snK));
    }
}
