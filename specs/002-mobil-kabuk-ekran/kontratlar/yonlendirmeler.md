# Eski adres yönlendirmeleri

Spec: H7 (AC-7.1–7.4), AC-4.16, FR-010, SC-007 · Plan: K5

## Bileşen

`Components/Pages/EskiAdres.razor` — yalnız yönlendirir, içerik çizmez.

```razor
@page "/v2"
@page "/sabah"
@page "/sadakat"
@page "/bulunurluk"
@page "/bellek"
@page "/satinalma/urun/{StkId:int}"
@inject NavigationManager Nav
@code {
    [Parameter] public int? StkId { get; set; }
    protected override void OnInitialized() => Nav.NavigateTo(EskiAdresler.Hedef(Nav.ToBaseRelativePath(Nav.Uri), StkId), replace: true);
}
```

`EskiAdresler.Hedef` saf fonksiyondur (`dashboard/Models/EskiAdresler.cs`), birim testiyle sınanır. Eski ekranın `@page` satırı aynı commit'te kalkar (iki bileşen aynı adresi tutarsa uygulama açılışta hata verir).

## Eşleme

| Eski adres | Hedef | Hedefte yer | Dalga |
|---|---|---|---|
| `/v2` | `/` | Bugün | 1 |
| `/bellek` | `/asistan?sekme=bellek` | Asistan → Bellek sekmesi | 1 |
| `/sabah` | `/#sabah` | Bugün → Sabah brifingi | 2 |
| `/sadakat` | `/musteri?sekme=sadakat` | Müşteri → Sadakat | 2 |
| `/bulunurluk` | `/satis-analizi?sekme=bulunurluk` | Satış analizi → Bulunurluk | 2 |
| `/satinalma/urun/{StkId}` | `/satis-analizi/urun/{StkId}?sekme=satinalma` | Aynı ürünün detayı → Satınalma | 2 |

- Hedef sekme `[SupplyParameterFromQuery(Name = "sekme")]` ile seçilir; tanınmayan değer varsayılan sekmeye düşer.
- Eski adresin sorgu parametreleri bu spec'te taşınmaz (eski Bulunurluk/Sadakat filtreleri yer imi olarak kullanılmıyor; ÇIKARIM, ölçülmedi). Taşınması gerekirse hedef ekranın filtre çözücüsüne eklenir.
- Ön çizimde `NavigateTo` → **302** (`Location` = hedef). 301 kullanılmaz: geri alındığında tarayıcı kalıcı yönlendirmeyi önbellekte tutar.
- Uygulama içinde eski adrese bağlantı kalmaz: `Asistan.razor:48` (`NavigateTo("bellek")`), MainLayout "Sabah Brifingi" öğesi, `NavRegistry` X öğeleri aynı commit'lerde değişir. Tarama: `grep -rn '"/\?\(v2\|sabah\|sadakat\|bulunurluk\|bellek\|satinalma/urun\)' dashboard/Components dashboard/Data` → yalnız `EskiAdres.razor` ve `EskiAdresler.cs`.
- Asistan araçları ya da LLM yanıtları eski adres üretirse yönlendirme onları da karşılar.

## Testler

| Test | Tür | AC |
|---|---|---|
| `EskiAdresler_Hedef` (teori: 6 satır + `StkId` korunur) | birim | AC-7.1, 7.2, 4.16 |
| `EskiAdres_GetIstegi_302VeHedef` (teori, 6 adres; Development ortamı) | `WebApplicationFactory` | FR-010, SC-007 |
| `EskiAdres_UygulamaIcindeBaglantiYok` (kaynak taraması) | birim | AC-7.4 |
| `BirlesenGosterge_HedefteAyniDeger` (Sadakat, Bulunurluk, Satınalma ürün detayı, Bellek: eski ekranın `data-gosterge` değerleri hedef sekmede) | Playwright (Dalga 2 öncesi önce-değerleri kaydedilir) | AC-7.3 |
