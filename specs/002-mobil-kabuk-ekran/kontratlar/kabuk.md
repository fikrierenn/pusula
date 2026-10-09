# Kabuk sözleşmesi — alt menü, sekme panelleri, PWA, oturum, bağlantı

Spec: H1 (AC-1.1–1.11), FR-001, FR-002, FR-003, FR-011 · Plan: K2, K3, K6
"Telefon görünümü" = `lg` altı (< 1024 px); kabul ölçümü 375×812. "Masaüstü" = `lg` ve üstü; kabul ölçümü 1280 px.

## 1. `NavRegistry` değişikliği

```csharp
public enum EkranSinifi { A, B, C }
public enum MobilSekme { Yok, Bugun, Satis, Finans, Asistan, Diger }

public record NavItem(
    string Href, string Label, string Icon,
    EkranSinifi Sinif,                 // yeni, zorunlu
    MobilSekme Sekme = MobilSekme.Yok, // yeni
    string? KapiAnahtari = null,       // yeni; TelefonKapisi.Bagimlilik anahtarı ("ekran:mizan")
    bool MatchAll = false, string Section = "ANALİTİK", bool GorevBadge = false);
```

- `InBottomNav` ve `BottomLabel` kalkar; alt menü sabit beş sekmedir (aşağıda), paneller `Sekme`den türer.
- Çıkan öğeler: `sadakat`, `bulunurluk`, `bellek` (X). `/v2` zaten kayıtta yok.
- Yeni öğe eklenmez; masaüstü menüsü bugünkü gruplarıyla kalır. Parametreli üç C ekranı (Satış analizi ürün detayı, Yevmiye, Fatura) bugün de menüde yok; `MobilSekmePaneli` içinde bağlantısız sabit satır olarak yazılır.
- Kök öğe etiketi "Genel Bakış" → "Bugün" (UI kararı 4).

| Sekme | Öğeler (`Sekme` alanı) |
|---|---|
| Bugün | `/` |
| Satış | Mağazalar, Mağaza (× `LokasyonConfig` mağazaları, `/magaza/{id}`), E-ticaret, Sınav Okulları, TOPLAM, Hedef Tahmin |
| Finans | Cari/Risk, Muhasebe, Gelir tablosu, Mizan |
| Asistan | `/asistan` (panel yok) |
| Diğer | Operasyon, Envanter, Vardiya + "Masaüstünde daha iyi": `Sinif = C` öğelerinin hepsi |

## 1a. Görünüm bildirimi (`GorunumSaglayici`, plan K2)

- `wwwroot/js/gorunum.js`: `matchMedia('(min-width: 1024px)')` ilk etkileşimli çizimde ve `change` olayında `DotNetObjectReference` ile `GorunumDegisti(bool masaustu)` çağırır.
- `Components/Layout/GorunumSaglayici.razor` MainLayout'u sarar, `CascadingValue<Gorunum>` dağıtır; ön çizimde ve bildirim gelene kadar `Bilinmiyor`.
- Kural: masaüstüne özgü içerik, vardiya isimli satırları ve dışa aktarma düğmeleri yalnız `Masaustu` iken çizilir ve verisi yüklenir. `Bilinmiyor` = telefon gibi davran (güvenli taraf).
- Testler: `CizimKurali_*` (birim, teori), `Gorunum_375_MasaustuIcerigiYuklenmez` (Playwright: DOM ve SignalR çerçevelerinde masaüstü bölümünün verisi yok), `Gorunum_PencereDaralinca_IsimliListeSilinir`.

## 2. Alt menü (`MainLayout.razor`)

| Öğe | Sözleşme | AC |
|---|---|---|
| Görünürlük | `lg:hidden`; masaüstünde DOM'da olsa da görünmez | AC-1.8 |
| Sıra | Bugün · Satış · Finans · Asistan · Diğer (soldan sağa) | AC-1.4 |
| Etkin sekme | Bulunulan sayfanın `Sekme` değeri; `text-primary` + `aria-current="page"`. Panel açıkken paneli açan sekme etkin | AC-1.4 |
| Bugün, Asistan | Düz `<a href>` (`/`, `/asistan`) | AC-1.6 |
| Satış, Finans, Diğer | `<button aria-expanded>`; `MobilSekmePaneli`'ni açar/kapar | AC-1.6 |
| Rozet | Asistan sekmesinde `badge badge-error`: **geciken** görev sayısı (`GorevService.Ozet(bugun).Geciken`); 0 ise rozet çizilmez (rozet `<span>`'dır, Lucide değil; koşullu çizim güvenli) | AC-1.7 |
| Boyut | Her sekme ≥ 44×44 px; etiket 11 px kalın (çakışan `text-[10px]` kalkar) | AC-0.6 |
| Güvenli alan | Alt menü `pb-[env(safe-area-inset-bottom)]`; `main` alt boşluğu `calc(4rem + env(safe-area-inset-bottom))` | AC-1.5 |
| Klavye | Telefonda bir giriş alanı odaktayken alt menü gizlenir (`body:has(:is(input,textarea,select):focus) .btm-nav { display:none }`) | AC-2.5 (UI kararı 7) |

Masaüstü üst barındaki CFO menüsü: `@onclick` + `NavigateTo` öğeleri `<a href>` olur (bağlantı kopukken de çalışır); "Sabah Brifingi" öğesi kalkar (Sabah Bugün'e birleşir). Kullanılmayan hamburger etiketi (`hidden lg:hidden`) kalkar.

## 3. Sekme paneli (`Components/Layout/MobilSekmePaneli.razor`, yeni)

- Parametreler: `MobilSekme Sekme`, `EventCallback Kapat`.
- Alt menünün hemen üstünde, ekran genişliğinde, en fazla ekranın %70'i yüksekliğinde, kendi içinde kayar. Arka plana dokununca ve bir bağlantıya dokununca kapanır; sayfa değişince kapanır (`LocationChanged`).
- Öğeler: `NavRegistry.Items.Where(i => i.Sekme == Sekme)`; `KapiAnahtari` doluysa `TelefonKapisi.Acik` false olan öğe **çizilmez** (AC-0.1, AC-3.4, AC-5.1, AC-6.1).
- Her satır `<a href>` (ikon + etiket), ≥ 44 px yükseklik.
- Diğer: üstte kapısı açık Operasyon/Envanter/Vardiya; altta başlık **"Masaüstünde daha iyi"** ve C ekranları; parametreli üç ekran bağlantısız satır: "Satış analizi ürün detayı — Satış analizinden açılır", "Yevmiye fişi — Muhasebe ekranından açılır", "Fatura — Muhasebe ekranından açılır".
- Lucide ikonları her öğede koşulsuz çizilir; kapalı öğe tüm satırıyla birlikte çizilmez (alt ağacın tümden kalkması güvenli, `coding-discipline.md`).
- Modal içinde modal oluşmaz: panel düzende durur, sayfa `Modal`'ları ondan bağımsızdır; panel açıkken sayfa modalı açılmaz (panel bağlantıyla kapanır).

## 4. Açılış ve oturum

| Durum | Davranış | AC |
|---|---|---|
| Oturum yok / süresi dolmuş (Development dışı) | `/` → 302 `/login`; giriş sayfası statik HTML, rakam yok | AC-1.9 |
| Giriş başarılı | 302 `/` → Bugün | AC-1.9, FR-003 |
| Simgeden açılış | `start_url` `/?kaynak=uygulama` → Bugün. Sorgu parametresi yalnız günlük için okunur: `LogInformation("Uygulama açılışı {Kaynak}", "uygulama")` (SC-008 ölçütü) | FR-003, SC-008 |

## 4a. Oturum yönetimi (plan K12)

```csharp
public static class OturumKurali   // saf, TimeProvider'dan "şimdi" alır
{
    public static readonly TimeSpan MutlakSure = TimeSpan.FromDays(7);
    public static readonly TimeSpan BostaSure  = TimeSpan.FromHours(12);
    public static readonly TimeSpan YenidenDogrulama = TimeSpan.FromMinutes(1);
    public static OturumDurumu Degerlendir(PanelOturumSatiri? satir, DateTime simdiUtc);
        // Satır yok → Gecersiz · IsValid=0 → Iptal · simdi >= MutlakBitis → MutlakDoldu · simdi - SonGorulme >= BostaSure → Bosta · aksi → Gecerli
}

public sealed class OturumService(Db db, TimeProvider saat)
{
    Task<Guid> AcAsync(int kullaniciId, string? cihazOzeti, CancellationToken ct);
    Task<PanelOturumSatiri?> GetirAsync(Guid id, CancellationToken ct);
    Task SonGorulmeYazAsync(Guid id, DateTime zamanUtc, CancellationToken ct);
    Task KapatAsync(Guid id, string neden, CancellationToken ct);              // cikis · bosta · mutlak
    Task<int> HepsiniKapatAsync(int kullaniciId, CancellationToken ct);        // hepsi; dönen = kapanan satır sayısı
    Task<IReadOnlyList<OturumOzeti>> AcikOturumlarAsync(int kullaniciId, CancellationToken ct);
}
```

| Akış | Davranış | AC |
|---|---|---|
| Giriş (`/auth/login` başarılı) | `AcAsync` → çereze `oid`; `IsPersistent = true`, `ExpiresUtc = MutlakBitis`; `SlidingExpiration = false` | AC-1.14 |
| Her HTTP isteği | `OnValidatePrincipal`: `Degerlendir`; `Gecerli` değilse satır `KapatAsync(neden)` (zaten kapalı değilse), `RejectPrincipal` + `SignOutAsync`; değilse `SonGorulme` (dakikada en çok bir) | AC-1.13, 1.14 |
| Açık devre | `RevalidatingServerAuthenticationStateProvider`, `RevalidationInterval = 1 dk`, aynı kural; `CircuitHandler.CreateInboundActivityHandler` son etkinliği bellekte tutar, turda `SonGorulme`'ye yazılır. Geçersiz → anonim; `MainLayout` `AuthenticationStateChanged` → `NavigateTo("/login", forceLoad: true)` | AC-1.12, 1.13 |
| Çıkış (`/auth/logout`) | `KapatAsync(oid, "cikis")` sonra `SignOutAsync` | AC-1.16 |
| Ayarlar → Oturumlar (masaüstü) | `AcikOturumlarAsync`: cihaz özeti + son görülme (gg.aa.yyyy ss:dd, yerel saat), bu cihaz işaretli. **Bütün oturumları kapat** (`Modal` onayı: "Bütün oturumlar kapatılsın mı? Bu cihaz dahil her yerde yeniden giriş gerekir." [Kapat] [Vazgeç]) → `HepsiniKapatAsync` → bu cihaz `/login`. Sonuç: "N oturum kapatıldı." | AC-1.12, 1.15 |
| Ayarlar → Oturumlar (telefon) | Liste salt okunur; düğme çizilmez (`Gorunum != Masaustu`) | AC-1.15 |
| Development, anonim istek | Satır aranmaz, kural koşmaz (anonim ön izleme bozulmaz) | — |
| BkmPanel erişilemez | HTTP: istek reddedilmez ama `LogError`; devre turu: oturum geçerli sayılmaz → `/login` (güvenli taraf). Giriş zaten BkmPanel'e bağlı | — |

Denetim günlüğü (`security-principles.md` § 10): oturum açma, çıkış, "bütün oturumları kapat" (kapanan sayı), süre dolması `LogInformation` ile; kişisel veri olarak yalnız kullanıcı adı.

Testler:

| Test | Tür | AC |
|---|---|---|
| `OturumKurali_Degerlendir` (teori: geçerli · iptal · mutlak sınırda ve 1 ms sonra · boşta 11:59 ve 12:00 · satır yok) | birim (sahte `TimeProvider`) | AC-1.13, 1.14 |
| `OturumService_AcKapatHepsini_BkmPanel` (geri alınan transaction, `zz_test_` kullanıcı) | entegrasyon (BkmPanel dev) | AC-1.12, 1.16 |
| `Cikis_YalnizKendiOturumunuKapatir` | entegrasyon | AC-1.16 |
| `HepsiniKapat_TelefonBirDakikadaGiriseDoner` (iki tarayıcı bağlamı: telefon 375 + masaüstü 1280; Production yayın turunda, `olcum.md` § 1) | Playwright | AC-1.12 |
| `Oturumlar_375_DugmeYok`, `Oturumlar_1280_ListeIpYok` | Playwright | AC-1.15 |
| `GecersizOturum_HttpIstegi_GiriseYonlenir` (`WebApplicationFactory`, Production, sahte oturum deposu) | `WebApplicationFactory` | AC-1.13, 1.14 |

Kırılabilirlik: `BostaSure` geçici olarak 1 dakikaya indirilir → telefon bağlamı 2 dakika etkileşimsiz bekletilir → `/login` görülür → değer elle geri alınır.

## 5. PWA varlıkları

### `wwwroot/manifest.json`

| Alan | Değer |
|---|---|
| `id` | `"/"` |
| `name` / `short_name` | "BKM Yönetim Paneli" / "BKM Panel" |
| `start_url` / `scope` | `"/?kaynak=uygulama"` / `"/"` |
| `display` | `"standalone"` |
| `orientation` | `"portrait"` |
| `lang` | `"tr"` |
| `icons` | `icon-192.png` 192 `any` · `icon-512.png` 512 `any` · **`icon-maskable-512.png` 512 `maskable`** (logo merkezde, çapı genişliğin %80'i olan daire içinde; zemin dolu) |
| `background_color`, `theme_color` | Onaltılık sabit (manifest CSS değişkeni okuyamaz; renk standardı istisnası) |

### `App.razor` `<head>`

- `viewport`: `width=device-width, initial-scale=1, viewport-fit=cover, interactive-widget=resizes-content`. `maximum-scale`/`user-scalable=no` **yazılmaz** (erişilebilirlik; yakınlaşma 16 px kuralıyla önlenir).
- `<link rel="apple-touch-icon" sizes="180x180" href="/apple-touch-icon.png">` (saydam olmayan zemin). Mevcut `apple-mobile-web-app-*` meta etiketleri kalır.

### `wwwroot/service-worker.js`

```text
CACHE = "bkm-kabuk-v1"   (sürüm değişince activate eski önbellekleri siler)
install : caches.open(CACHE).addAll(["/offline.html", "/app.css", "/icon-192.png"]); skipWaiting
activate: CACHE dışındaki önbellekleri sil; clients.claim
fetch   : yalnız request.mode === "navigate" ise
            respondWith(fetch(request).catch(() => caches.match("/offline.html")))
          öteki istekler: respondWith ÇAĞRILMAZ (ağa geçer; /_blazor, /api, statik)
```

Önbelleğe veri, HTML sayfa, `/_blazor` yanıtı **girmez** (FR-011).

### `wwwroot/offline.html`

- Bağımsız sayfa; yalnız önbellekteki `app.css`'i kullanır.
- Metin: "Bağlantı yok. İnternet bağlantınızı kontrol edip yeniden deneyin." Düğme: **Yeniden dene** → `location.reload()`. Düğme ≥ 44 px.
- Hiçbir rakam, mağaza adı ya da kullanıcı verisi içermez (AC-1.10).

### HTML yanıt başlığı (`Program.cs`)

`text/html` yanıtlarına `Cache-Control: no-store` (cihazda sayfa kopyası kalmaz). `/manifest.json`, `/service-worker.js`, statik varlıklar bundan etkilenmez.

## 6. Bağlantı kopması

`ReconnectModal` bugünkü Türkçe metinleriyle kalır ("Sunucuya yeniden bağlanılıyor…", "Bağlantı başarısız… N sn içinde tekrar denenecek.", "Yeniden bağlanılamadı…" + **Tekrar Dene**). Telefonda tam genişlikte görünür, düğme ≥ 44 px, bağlantı dönene kadar durur; `/healthz` yoklaması bugünkü gibi (AC-1.11).

## 7. Testler

| Test | Tür | AC |
|---|---|---|
| `Manifest_KurulumAlanlariTam` (alanlar + üç ikon dosyası var, maskable ayrı dosya) | `WebApplicationFactory` | AC-1.1, 1.3 (otomatik kısmı) |
| `KokIstek_OturumYok_GiriseYonlenirRakamYok` (Production ortamı) | `WebApplicationFactory` | AC-1.9 |
| `HtmlYaniti_NoStoreTasir` | `WebApplicationFactory` | FR-011 |
| `NavRegistry_XEkranlariYok`, `NavRegistry_HerOgeninSinifiVar`, `NavRegistry_SekmeSirasi` | birim | AC-1.4, 1.8, 7.4 |
| `GorevOzet_SonTarihGecmisVeAcik_Geciken` (+ kapalı, tarihsiz, bugün sınırı) | birim | AC-1.7, 2.3, 4.12 |
| `AltMenu_375_BesSekmeSiraVeEtkin`, `AltMenu_1280_Gorunmez`, `AltMenu_375_SonSatirMenununUstunde`, `Hedef_BugundenIkiDokunusta` (Cari/Risk, Görevler), `Rozet_GecikenYoksaYok` | Playwright | AC-1.4–1.8, SC-004 |
| `Cevrimdisi_UygulamaAcilisi_UyariVeYenidenDene_RakamYok`, `Cevrimdisi_OnbellekteYalnizKabukVarliklari` | Playwright (`SetOfflineAsync`) | AC-1.10, FR-011 |
| `BaglantiKoptu_UyariGorunurVeDurur` | Playwright | AC-1.11 |
| Kurulum, tam ekran açılış, ikon kırpılmaması, klavye (AC-1.1–1.3, 2.5, SC-003) | **Elle, cihazda, yalnız LAN 5443 üzerinden** (Android Chrome + iOS Safari); ekran görüntüsü kişisel veri içermeyen ekrandan (Bugün kart 7, çevrimdışı sayfa, giriş) alınır ve commit edilmez | — |

## 8. Kayıp telefon (yardım dokümanı, KVKK K3)

`docs/yardim/telefona-kurulum.md` bir "Telefonunuz kaybolursa" bölümü taşır (görev odaklı adımlar): 1. Masaüstünde **Ayarlar** → **Oturumlar** → **Bütün oturumları kapat** (telefondaki uygulama en geç 1 dakikada giriş sayfasına döner; § 4a). 2. **Parolayı değiştirin**. 3. Telefon bulunursa ana ekrandaki uygulamayı kaldırın. Masaüstüne erişim yoksa: sistem yöneticisi Data Protection anahtarlarını yeniler (bütün çerezler geçersiz olur). Ayrıca "telefonda ekran kilidi zorunlu" notu (KVKK K10).
