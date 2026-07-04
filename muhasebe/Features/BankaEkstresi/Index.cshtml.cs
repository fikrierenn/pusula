using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Muhasebe.Lib;

namespace Muhasebe.Pages.BankaEkstresi;

// Banka ekstresi satırlarını yapıştır → cari önerisi + onay/düzeltme ile öğrenme.
public sealed class IndexModel(BankaSiniflandirmaService svc) : PageModel
{
    // Yön: "1"=giden/ödeme, "0"=gelen/tahsilat.
    [BindProperty] public string Yon { get; set; } = "1";
    [BindProperty] public string? Girdi { get; set; }
    [BindProperty] public int BankaHesapId { get; set; }   // bu ekstre hangi banka hesabı (cKod)

    public IReadOnlyList<BankaOneri> Sonuclar { get; private set; } = [];
    public IReadOnlyList<BankaHesap> BankaHesaplari => svc.BankaHesaplari;
    public int AutoSayi { get; private set; }
    public int IstisnaSayi { get; private set; }
    public int YokSayi { get; private set; }
    public string? Mesaj { get; private set; }
    public DateTime? SonYukleme => svc.SonYukleme;
    public int AnahtarSayisi => svc.IndexAnahtarSayisi;
    public int OgrenilenSayisi => svc.OgrenilenSayisi;

    // İlk GET'te index'i yükle → banka hesabı dropdown dolsun.
    public async Task OnGetAsync() => await svc.YukleAsync();

    public async Task OnPostAsync() => await Siniflandir();

    // Cari arama (İstisna düzeltmesi — isimle/kodla bul). Razor Pages handler, JSON döner (ayrı API değil).
    public async Task<IActionResult> OnGetCariAraAsync(string? q) => new JsonResult(await svc.CariAraAsync(q));

    // ÖĞRET: onay ('onay') veya düzeltme ('duzeltme') → yeniden sınıflandır (öğrenilen satır AUTO olur).
    public async Task OnPostOgretAsync(string? aciklama, int onerilenCariId, int dogruCariId)
    {
        if (dogruCariId > 0 && !string.IsNullOrWhiteSpace(aciklama))
        {
            var ba = Yon == "0" ? 0 : 1;
            var kaynak = dogruCariId == onerilenCariId ? "onay" : "duzeltme";
            var kim = User.Identity?.Name is { Length: > 0 } n ? n : "muhasebe";
            await svc.OgrenmeKaydet(ba, aciklama, dogruCariId, kaynak, kim);
            Mesaj = (kaynak == "onay" ? "Onaylandı" : "Düzeltildi") + $": “{aciklama}” → #{dogruCariId}";
        }
        await Siniflandir();
    }

    private async Task Siniflandir()
    {
        if (string.IsNullOrWhiteSpace(Girdi)) return;
        var ba = Yon == "0" ? 0 : 1;
        var satirlar = Girdi.Split('\n', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        Sonuclar = await svc.ClassifyBatchAsync(ba, satirlar);
        AutoSayi = Sonuclar.Count(s => s.Kademe == "AUTO");
        IstisnaSayi = Sonuclar.Count(s => s.Kademe == "ISTISNA");
        YokSayi = Sonuclar.Count(s => s.Kademe == "YOK");
    }
}
