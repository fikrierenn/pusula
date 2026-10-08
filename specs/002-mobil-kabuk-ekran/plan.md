# Plan 002: Telefon kabuğu ve ekranlar

**Durum:** Taslak (onay bekliyor) · **Spec:** `specs/002-mobil-kabuk-ekran/spec.md` (Onaylandı 08.10.2026) · **Tarih:** 08.10.2026
**Kardeş spec:** 001 (`specs/001-panel-veri-duzeltme/`, uygulamada; F0 tamam, F1 T-021'de) · **Seçilen yaklaşım:** C — tek kaynak, ekran genişliğine göre düzen + telefona kurulan web uygulaması (PWA). A (ayrı native uygulama) ve B (ayrı `/m` rota seti) 02–03.10.2026'da reddedildi (`.orkestra/calisma/gm-mobil-plan-taslak.md` §3).

## Özet

Panel tek bir Blazor uygulaması olarak kalır. Telefon ile masaüstü ayrımını yalnız CSS kırılma noktası (`lg` = 1024 px) yapar; sunucu cihaz tanımaz. Alt menü, `NavRegistry`'ye eklenen sınıf (A/B/C) ve sekme bilgisinden türer. 001'e bağlı bir ekranın ya da kartın telefonda görünmesini **kodda tek bir sabit** belirler: `TelefonKapisi.KapananMaddeler`. Bu küme yalnız 001 kabul sonucunu git'e yazan dosyada "tuttu" görünen maddelerle doldurulabilir; birim testi bunu zorlar. "/" adresi yeni **Bugün** sayfası olur; bugünkü Ana sayfa ve Sabah içerikleri bu sayfanın alt bileşenine dönüşür, masaüstünde eksiksiz kalır. Birleşen beş ekran ve Sabah bir yönlendirme sayfasıyla yeni yerine gider. Telefon kartlarının hesabı Razor'dan `Data/` çekirdeğine taşınır; ekran ve kart aynı metodu çağırır (FR-005). 375 px taşma, 44 px dokunma, ipucu, 16 px giriş ve kapı kuralları canlı uygulamaya karşı Playwright testleriyle ölçülür (yeni test bağımlılığı; GMY onayı 08.10.2026, ADR-007 taslağı).

İş üç dalgada yürür. **Dalga 1** 001'den bağımsızdır, şimdi başlar: kabuk, kapı, ölçüm altyapısı, 001'den bağımsız ekranlar (Görevler, Asistan, Muhasebe, Gelir tablosu; Cari/Risk düzeni hazırlanır ama kapısı 001 ek maddesine bağlı), Bellek ve Ana sayfa v2 birleşmesi, ilk Bugün (yalnız kart 7). **Dalga 2** 001 master'a alındıktan sonra başlar: 001'in dokunduğu ekranların telefon düzeni, kalan Bugün kartları, öteki üç birleşme, C ekranlarının taşma düzeltmesi. **Dalga 3** kapı açma commit'leridir; her biri 001 kabul sonucuna bağlıdır.

## Teknik bağlam

- **Çözüm / projeler:** `dashboard/GmDashboard.csproj` (değişir) · `tests/GmDashboard.Tests` (001'de açıldı; 002 testleri eklenir, Playwright paketi eklenir) · `lib/Bkm.Shared` (yalnız Dalga 2'de, kart 8 için `VardiyaQueries.GetComplianceAsync`'e şube parametresi). Toplam 3 proje (Madde 5 sınırı içinde).
- **Hedef veritabanları:** yeni SQL yok; tek istisna kart 8 (Dalga 2): `BkmPanel` (`bkm.Vrd_*`, dev, SANAL-FIKRI), salt-okuma, mevcut sorgunun şube süzgeçli hâli. ERP, POS, e-ticaret okumaları bugünkü metotlarla yapılır (compat: EncoreMerkez 110, diğerleri 150 — `config/veritabanlari.json`). **ERP'ye ve hiçbir tabloya yazma yok** (FR-013).
- **Katmanlar:** dashboard tek projeli, iki katmanlı (Razor → `Data/*Queries|*Service`). Katman eklenmez. Değişen: `Components/{App.razor, Layout/*, Pages/*, Shared/*}`, `Models/NavRegistry.cs`, `Models/TelefonKapisi.cs` (yeni), `Data/*` (hesap Razor'dan çekirdeğe taşınır), `wwwroot/{manifest.json, service-worker.js, offline.html, ikonlar}`, `Styles/app.tailwind.css`, `tailwind.config.js`, `Program.cs` (HTML yanıtına `Cache-Control: no-store`).
- **Veri erişimi:** Dapper + gömülü SQL (mevcut desen). Yeni SP yok. Dokunulan metotlar `CancellationToken` alır.
- **Test:** xUnit (001 sürümleri) · birim + `WebApplicationFactory` (manifest, yönlendirme, oturum, başlık) · canlı okuma 001 T-021 altyapısıyla (`lib/Bkm.TestAltyapi`: `LiveDb.QueryAsync/ScalarAsync/PanelDb`, `DbTarget {Erp, Joker}`, `ReadOnlyGate.Check` → `ReadOnlyGateResult(Passed, Reason)`) · **Microsoft.Playwright** (onaylı 08.10.2026, yalnız test projesi; `Channel = "chrome"`, kurulu Chrome kullanılır, tarayıcı indirilmez) — `[Trait("Tur","Mobil")]`, canlı geliştirme sunucusuna (`PANEL_URL`, varsayılan `http://localhost:5112`) karşı. bUnit kullanılmaz.
- **Saat:** yeni kod `TimeProvider` kullanır; kayıt 001 T-029'undur (002 bu commit'e bağlıdır).
- **Hata metni:** yeni ve dokunulan ekranlar 001 T-031 `KullaniciMesajlari.VeriAlinamadi` sabitini kullanır.

## Kararlar

### K1 — 001 kapısı: kod sabiti + git'teki kabul sonucu (soru 1)

| Seçenek | Ne olur | Sonuç |
|---|---|---|
| **(a) Kod sabiti** `TelefonKapisi.KapananMaddeler` + bağımlılık tablosu kodda; açma = tek satırlık commit | Değişiklik incelenir, git'te izlenir, testle kanıta bağlanır; açılış yayınla gelir | **Seçildi** |
| (b) Yapılandırma (`.env`, `appsettings`, `dbo.PanelAyar`) | Yayınsız açılır; ama kanıtsız açılabilir, ortamlar arası kayar, kim/ne zaman açtı izi yok | Reddedildi |
| (c) Çalışma anında 001 kabul raporunu okumak | Uygulama depo dosyasına bağlanır; `.orkestra/` git dışı (`.gitignore:127`) | Reddedildi |

Emsal: 001 hedef notunu da kod sabitiyle açıyor (`HedefTabani.Teyitli`, 001 plan K-C). Tek kullanıcı, yayın zaten 001 kabulüyle birlikte geliyor; yayınsız açma ihtiyacı yok.

**Nasıl çalışır (ayrıntı `kontratlar/telefon-kapisi.md`):**
1. `TelefonKapisi.Bagimlilik` sözlüğü: ekran ya da kart anahtarı → gerekli madde anahtarları (`"001:H5"`, `"001:H10.1"`, `"003:nakit"` …). Kaynak spec 002 § "001 bağımlılığı" ve H4 kart tablosu; birim testi spec tablosunu okuyup sözlükle karşılaştırır (elle kopya kaymaz).
2. `TelefonKapisi.KapananMaddeler`: bugün **boş**.
3. `TelefonKapisi.Acik(anahtar)`: gerekli maddelerin hepsi kümede ise `true`. Her çizimde değerlendirilir (sınır durum: geri alma = anahtarı kümeden çıkaran commit).
4. **Açma yolu:** 001 `/kabul-testi` hükmünden sonra denetleyici `specs/001-panel-veri-duzeltme/kabul-sonucu.md` dosyasını yazar (git'te; satır: madde · sonuç · tarih · kanıt). Ardından 002 kapı görevi kümeye anahtarı ekler: `feat(bkm): telefon kapısı H12 açıldı (spec 002)`.
5. **Zorlama:** `KapananMaddeler_HepsiKabulSonucundaTuttu` testi kümedeki her anahtar için `kabul-sonucu.md`'de "tuttu" satırı arar; yoksa kırmızı. "Koşamadı" kapanmış sayılmaz (spec varsayımı).

**Kapı neyi etkiler:** (i) telefon sekme panellerindeki bağlantılar, (ii) Bugün kartları (her görünümde — yanlış rakam yeni karta da taşınmaz), (iii) Bugün sayfasındaki eski Ana sayfa ve Sabah bölümleri: kapı kapalıyken `hidden lg:block` (telefonda gizli, masaüstünde bugünkü gibi — AC-0.9). Masaüstü menüsü kapıdan etkilenmez. Kapalı ekran doğrudan adresle açılırsa bugünkü düzeniyle açılır (spec varsayımı).

### K2 — Telefon/masaüstü ayrımı yalnız CSS kırılma noktası

Sunucu cihaz ya da genişlik bilmez. Telefon düzeni `lg` altı (< 1024 px), masaüstü `lg` ve üstü; mevcut kabuk zaten bu kırılmayı kullanıyor (`MainLayout.razor`: `lg:drawer-open`, `btm-nav lg:hidden`). B ekranında telefonda gösterilmeyen bölüm `hidden lg:block` kabına girer, yerinde `lg:hidden` "Ayrıntı masaüstünde." notu durur (FR-007).
Bedeli: CSS ile gizlenen bölümün sorgusu telefonda da koşar (risk R4). JS `matchMedia` ile görünüm bildirimi ve gecikmeli yükleme kontenjandır, ilk sürümde yapılmaz.
Not: Tailwind yalnız `Components/**/*.razor` tarar (`tailwind.config.js`). Sınıf adı C# dosyasında üretilirse (`TelefonKapisi`) `content` listesine `./Models/**/*.cs` eklenir.

### K3 — Alt menü ve sekme panelleri

- Sekmeler soldan sağa **Bugün · Satış · Finans · Asistan · Diğer**, `NavRegistry`'deki yeni `MobilSekme` alanından türer (elle ikinci liste yok). Bugünkü alt menü (Genel · Operasyon · E-ticaret · Müşteri · Envanter + Diğer, `NavRegistry.cs` `InBottomNav`) kalkar.
- **Bugün** → `/` (1 dokunuş). **Asistan** → `/asistan` (1 dokunuş; H1 "asistana tek dokunuş"). Asistan sayfasının başında **Sohbet · Görevler · Bellek** şeridi: Görevler `/gorevler` bağlantısı (2. dokunuş, AC-1.6), Bellek sayfa içi sekme (AC-2.7).
- **Satış · Finans · Diğer** → alt panel (MainLayout içinde, alt menünün üstünde açılır; bağlantılar düz `<a href>`). Hedefe 2 dokunuş (AC-1.6, SC-004).
- Satış panelindeki **Mağaza** bağlantıları `LokasyonConfig` mağaza listesinden türer (parametreli ekran).
- Diğer paneli: üstte kapısı açık Operasyon/Envanter/Vardiya, altta **Masaüstünde daha iyi** grubu `Sinif = C` öğelerinden türer. Parametre isteyen üç C ekranı (Satış analizi ürün detayı, Yevmiye, Fatura) bağlantısız satır olarak "… ekranından açılır" notuyla listelenir (spec "17 ekranın hepsi listelenir" varsayımının uygulanabilir hâli; karar raporda).
- Asistan sekmesindeki rozet **geciken** görev sayısıdır (AC-1.7); bugün MainLayout açık görev sayısını gösteriyor. Gecikme kuralı `Gorevler.razor:135`'ten `GorevService`'e taşınır.
- X ekranları `NavRegistry`'den çıkar (Sadakat, Bulunurluk, Bellek; `/v2` zaten yok). Masaüstü menüsünün grupları değişmez (AC-1.8). Kök öğenin etiketi "Genel Bakış" → "Bugün" (UI kararı 4).

### K4 — Bugün sayfası

- `Components/Pages/Bugun.razor` (`@page "/"`, yeni, küçük): üst bölüm kart şeridi (1, 1a, 3, 4, 5, 7, 8), alt bölüm kart 2 + bugünkü Ana sayfa içeriği + Sabah brifingi.
- `Home.razor` yalnız `@page "/"` satırını kaybeder ve Bugün içinde alt bileşen olur (001 T-045/T-046/T-069 ile çakışma tek satır). `Sabah.razor` Dalga 2'de aynı biçimde alt bileşen olur; LLM brifingi açılır bölümde, açıldığında üretilir (UI kararı 3).
- Kart hesapları çekirdekte, kart bileşenleri yalnız biçim (`emitter-ayrimi.md`). Kart sözleşmesi `kontratlar/bugun.md`.
- Kartın kaynağı hata verirse yalnız o kart `VeriAlinamadi` gösterir; kartlar birbirinden bağımsız yüklenir.

### K5 — Birleşmeler ve eski adresler (X sınıfı + Sabah)

- Birleşen ekran **alt bileşen** olur: dosyasından `@page` satırı kalkar, hedef ekranda sekme ya da bölüm olarak çizilir. Aynı bileşen, aynı sorgu → AC-7.3 değer eşitliği yapısal olarak sağlanır. Dosya silinmez (spec kapsam dışı; silme ayrı onay).
- Ana sayfa v2 (`HomeV2.razor`) yalnız `@page "/v2"` satırını kaybeder; hedefte bölümü yok (spec yalnız adres yönlendirmesi istiyor; AC-7.3 bu ekranı saymıyor).
- Eski adresler tek yönlendirme sayfasından gider: `Components/Pages/EskiAdres.razor`, altı `@page` (`/v2`, `/sabah`, `/sadakat`, `/bulunurluk`, `/bellek`, `/satinalma/urun/{StkId:int}`), `NavigationManager.NavigateTo(hedef, replace: true)`. Ön çizimde 302 döner, uygulama içi gezintide istemci yönlendirir. 301 kullanılmaz (geri alınırsa tarayıcı önbelleği eski yönü tutar). Sözleşme `kontratlar/yonlendirmeler.md`.
- `UseRewriter` reddedildi: Blazor etkileşimli yönlendiricisi bilinmeyen adresi sunucuya sormadan `NotFound` sayfasına çizebilir (`Routes.razor` `NotFoundPage`); uygulama içi eski bağlantı yönlenmezdi.

### K6 — PWA kurulum ve çevrimdışı

- `manifest.json`: `id`, `start_url "/?kaynak=uygulama"`, `display standalone`, `orientation portrait`, ayrı `icon-maskable-512.png` (logo %80 güvenli alan içinde), `any` ikonlar 192/512. `apple-touch-icon` 180×180, saydam olmayan zemin.
- `service-worker.js`: yalnız **gezinme** isteğine `fetch → başarısızsa offline.html`; önbellekte yalnız `offline.html`, `app.css`, ikonlar. Veri, HTML sayfa ve `/_blazor` önbelleğe girmez (FR-011). Önbellek adı sürümlü; `activate` eskileri siler.
- `offline.html`: "Bağlantı yok. İnternet bağlantınızı kontrol edip yeniden deneyin." + **Yeniden dene** (`location.reload()`); hiçbir rakam içermez (AC-1.10).
- HTML yanıtlarına `Cache-Control: no-store` (cihazda sayfa kopyası kalmaz; FR-011). Test: `WebApplicationFactory` ile başlık.
- Bağlantı kopması (AC-1.11): mevcut `ReconnectModal` Türkçe metinleriyle yeterli; telefonda görünürlüğü ve dokunma boyutu ölçülür.
- Kurulum testi güvenli bağlantı ister; 002'de geçici tünel (spec varsayımı), kalıcısı 004.

### K7 — Ölçüm: 375 px, 44 px, ipucu, 16 px, kapı (soru 3)

| Seçenek | Değerlendirme | Sonuç |
|---|---|---|
| **Microsoft.Playwright (.NET) + kurulu Chrome** (`Channel = "chrome"`) — xUnit içinde, canlı sunucuya | Çerçevenin kendisi; görünüm, dokunma, çevrimdışı benzetimi hazır. Yeni NuGet paketi (PKG-005, Madde 5) | **Seçildi** — GMY onayı 08.10.2026, `docs/ADR/007-mobil-duzen-olcumu-playwright.md` (Önerildi) |
| Node betiği + Chrome DevTools Protocol (yeni paket yok) | Bağımlılıksız ama ~150 satır elle yazılmış otomasyon; bakım bizde | Reddedildi (ADR-007) |
| Elle önizleme (Claude Preview, telefon) | Tekrarlanmaz, kapı değildir | Yalnız kabul testinde ek kanıt |

Ölçüm tanımları (`kontratlar/olcum.md`): sayfa hazır olunca sonuna kadar kaydırılır; `document.documentElement.scrollWidth <= 375`. Dokunma: görünür etkileşimli öğelerin `getBoundingClientRect()` eni ve boyu ≥ 44 (yalnız WCAG 2.5.5 "satır içi bağlantı" istisnası). İpucu: görünür her `[title]` metni sayfa görünür metninde de geçer. Giriş: görünür `input/select/textarea` hesaplanmış `font-size` ≥ 16 px. Ekran listesi elle yazılmaz, `NavRegistry` + `TelefonKapisi`'den türer: kapısı açık A/B ekranında kural kırmızı verir; kapalı ekran yalnız raporlanır; C ekranında yalnız taşma ölçülür (AC-6.2).
Blazor `@onclick` DOM'da iz bırakmaz; tıklanabilir `div/tr/span` ölçümde görünmez. Bu yüzden ek birim testi: A/B ekran kaynağında `@onclick` taşıyan öğe `button`/`a` ya da `role="button"` olmalı.
Hazır sinyali: `h1` görünür, görünür `.loading` yok, 750 ms DOM değişmedi; 45 sn'de hazır değilse **KOŞAMADI = kırmızı** (`olctum-mu-cikardim-mi.md`). Kırılabilirlik: bir ekrana bilerek 400 px'lik öğe ve 24 px'lik düğme eklenir, kırmızı görülür, geri alınır.

### K8 — 500+ satırlık ekranların bölünmesi (soru 4)

- **Kapsamda:** 002'nin değiştirdiği bölüm alt bileşene çıkar; dokunulan `.razor` dosyası 002 commit'inden sonra dokunmadan önceki satır sayısından **büyük olamaz**. Yeni bileşenler < 300 satır. RenderFragment'lı `@code` bulunan dosyada code-behind kullanılmaz, alt bileşen kullanılır (`file-size-discipline.md`).
- Birleşmede (Musteri+Sadakat, SatisAnalizi+Bulunurluk, SatisAnaliziUrun+SatinalmaUrunDetay, Asistan+Bellek) birleşen içerik kendi dosyasında kalır; hedefe en fazla ~15 satır (sekme şeridi + bileşen etiketi) eklenir.
- **Kapsam dışı:** SatisAnaliziUrun (1.212), SatisAnalizi (1.200), SatinalmaAnaliz (734), SezonAksiyon (644), HediyeCeki (586), OdakStok (514), Musteri (564) dosyalarının < 300'e tam bölünmesi; HomeV2 (653, yönlendirilir, silme ayrı onay). Gerekçe: C ekranları için spec yalnız taşmamayı istiyor; davranış değiştirmeyen büyük bölme ayrı bir `/refactor` işi ve karakterizasyon testi ister; 001 bu dosyalara dokunurken bölmek çakışmayı büyütür. TODO maddesi olarak yazılır.
- Home (607), Envanter (553), Operasyon (522), Tahmin (564), Eticaret (485), Asistan (482): telefon özeti alt bileşen olarak eklenir, dosya büyümez; tam bölme yine kapsam dışı.

### K9 — Kart 1 kıyas günü ve kart 3 kontrol kümesi (GMY 07–08.10.2026)

- **Kart 1 kıyas günü:** dün Temmuz–Ekim arasındaysa kıyas günü, okul açılışına göre aynı gün farkını taşıyan geçen yıl günüdür: `kıyas = dün − (OkulAcilis[Y] − OkulAcilis[Y−1])` (2026 için 14.09.2026 − 08.09.2025 = 371 gün; ikisi de Pazartesi, hafta günü korunur). Öteki aylarda `kıyas = dün − 364` (aynı hafta günü). `OkulAcilis` tek kaynaktır (`Models/SezonAksiyonModels.cs:178`); yıl tanımlı değilse "Kıyas günü yok", renk yok. Uygulama: `OkulHizaliKiyas.Bul(DateOnly dun)` saf fonksiyon. GMY 07.10'da okul dönemine eş kıyası seçti (spec AC-4.4); ay sınırı ve formül denetleyici kararı.
- **Kart 3 kontrol kümesi:** Ana sayfanın bugünkü iki uyarı kuralı, "dün" için: (1) mağaza cirosu bir önceki döneme göre −%10 ya da daha kötü → hata tonu; (2) iade oranı %2'nin üstü → uyarı tonu. Başarı kuralları (hedef ≥ %105, en güçlü artış) kontrol sayılmaz. Kuralın kaynağı hata verirse o kontrol "koşamadı". `Home.razor` `BuildAlerts` bu iki kuralı `Data/UyariKurallari.cs`'ten çağırır (tek kaynak; zil ve kart 3 aynı sonucu verir). Kurallar Ana sayfa cirosunu okuduğu için kart 3 kapısına kart 1'in maddeleri eklenir.

## Anayasa kapıları

| Madde | Soru | Sonuç | Not |
|---|---|---|---|
| 1 Test-önce | Her davranış için önce kırmızı test planlandı mı? | ✅ | Bugün kırmızı vermesi beklenenler ölçüldü: 02.10 denetiminde 40 ekranın yaklaşık yarısında taşma, ~24 px hedef; alt menü sırası, kapı, yönlendirme, manifest maskable ikonu, çevrimdışı sayfa, görev silme onayı bugün yok. Testler test yazarı rolünde; Playwright testleri ilk koşuda kırmızı görülür |
| 2 Runtime kuralları | DMY, compat, DECIMAL, src.*, IsValid | ✅ | Yeni SQL yok. Kart 8'in şube süzgeci (Dalga 2) mevcut sorgunun parametreli hâli; her alt sorgu kendi süzgecini taşır (`vardiya_kapsam_denetimi.py` çıkış 0). Para `decimal`. Ekranda tarih gg.aa.yyyy |
| 3 Katman yönü | ARC ihlali var mı? | ⚠ mevcut borç | Yeni katman yok. Razor'daki hesap `Data/` çekirdeğine taşınır (borç azalır, artmaz) |
| 4 Kural koddur | Kurallar araçla zorlanıyor mu? | ✅ | 375/44/16/ipucu/kapı Playwright testi; tıklanabilir öğe ve kapı anahtarı birim testi; dosya büyümezliği görev kabulünde `wc -l` |
| 5 Sadelik | Yeni proje/katman/bağımlılık? | ⚠ 1 bağımlılık | `Microsoft.Playwright` (yalnız test projesi) — GMY onayı 08.10.2026, ADR-007. Yeni proje yok. Dokunulan proje 3 |
| 6 Soyutlama karşıtı | Çerçeve sarmalanıyor mu? | ✅ | `NavLink`, `NavigationManager`, Tailwind kırılma noktası, Service Worker API doğrudan. Cihaz tanıma katmanı, sekme soyutlaması, tema sarmalayıcısı yok |
| 7 Gerçek ortam testi | Entegrasyon gerçek ortamda mı? | ✅ | Playwright canlı uygulamaya ve canlı (salt-okuma) veriye bakar; çekirdeğe taşınan sorgu metotları 001 T-021 altyapısıyla (`LiveDb`, `ReadOnlyGate`) sınanır. Kontratlar uygulamadan önce yazıldı |
| 8 Güvenlik | Negatif test, sır | ✅ | Negatif testler: oturumsuz açılış girişe gider, rakam yok (AC-1.9); çevrimdışı sayfada rakam yok, önbellekte veri yok (AC-1.10, FR-011); telefonda vardiya ad/sicil görünmez (FR-009); telefonda Ayarlar/Eşikler'de kaydet/sil yok (AC-6.6); hata ekranında sunucu/SQL/istisna metni yok (AC-0.10). Sır yok. Not: telefonda salt-okuma bir **arayüz** kuralıdır, yetki sınırı değildir (tek kullanıcı) |
| 9 İzlenebilirlik | AC → görev → test | ✅ | `kontratlar/README.md` AC → bileşen → test tablosu |
| 10 İnsan kapıları | Plan, UI, merge | ✅ | § İnsan onayı gerektirenler; UI paneli önerilir (§ UI kararları 1–2) |
| 11 Doküman | Yardım ve CHANGELOG | ✅ planlandı | `docs/yardim/telefona-kurulum.md` (Android ve iOS adımları) + `docs/yardim/telefon-menusu.md`; `dashboard/CHANGELOG.md` (001 T-078 açıyor) "Eklendi/Değişti" |

## Bileşenler ve sorumluluklar

| Bileşen | Tür | Sorumluluk | Dosya(lar) | AC | Dalga |
|---|---|---|---|---|---|
| `TelefonKapisi` | Static sınıf | Bağımlılık sözlüğü, kapanan maddeler, `Acik()`, gizleme sınıfı | `dashboard/Models/TelefonKapisi.cs` (yeni) | AC-0.1, 0.2, 3.4, 4.2, 4.14, 4.17, FR-004 | 1 |
| `NavRegistry` | Kayıt | `Sinif` (A/B/C), `MobilSekme`, X öğeleri çıkar, "Bugün" etiketi | `dashboard/Models/NavRegistry.cs` | AC-1.4, 1.8, 6.1, 7.4 | 1 |
| `MainLayout` | Kabuk | Beş sekme, sekme paneli, geciken rozeti, güvenli alan boşluğu, Sabah bağlantısı kalkar, CFO menüsü `<a href>` | `Components/Layout/MainLayout.razor` (+ yeni `Components/Layout/MobilSekmePaneli.razor`) | AC-1.4–1.8, 1.7 | 1 |
| `App.razor` | Kabuk | viewport `interactive-widget=resizes-content`, apple-touch-icon 180 | `Components/App.razor` | AC-1.1, 1.2, 2.5 | 1 |
| PWA varlıkları | Statik | Manifest, SW, çevrimdışı sayfa, maskable ve apple ikonları | `wwwroot/manifest.json`, `service-worker.js`, `offline.html` (yeni), `icon-maskable-512.png` (yeni), `apple-touch-icon.png` (yeni) | AC-1.1–1.3, 1.10, FR-001, FR-011 | 1 |
| `Program.cs` | Ara katman | HTML yanıtına `Cache-Control: no-store` | `dashboard/Program.cs` | FR-011 | 1 |
| Ortak bileşen dokunma düzeni | UI | `AppDataTable` satırı `role="button"` + `min-h-11`; `AppPeriodPills`, `Sayfalama`, `Modal` kapatma, `ExcelButton` telefonda ≥ 44 px; giriş alanları telefonda 16 px | `Components/Shared/*.razor`, `Styles/app.tailwind.css` | AC-0.6, 0.8 | 1 |
| `GorevService` | Servis | `GecikenMi(g, bugun)`, `Ozet(bugun)` → (açık, geciken); `TimeProvider` | `dashboard/Data/GorevService.cs` | AC-1.7, 2.3, 4.12 | 1 |
| `GelirTabloQueries.Ozetle` | Çekirdek | Faaliyet kârı hesabı Razor'dan (`GelirTablosu.razor:180-215`) taşınır; kapanmış son ay `Fin_AyKapanis`'ten | `dashboard/Data/GelirTabloQueries.cs` | AC-3.2 | 1 |
| `MuhasebeQueries.KontrolOzeti` | Çekirdek | Bulgu adedi, toplam, en büyük 3 kalem | `dashboard/Data/MuhasebeQueries.cs` | AC-3.1 | 1 |
| CariRisk, Görevler, Asistan, Muhasebe, Gelir tablosu | Sayfa | Telefon düzeni; hata metni `VeriAlinamadi`; Görev silme onayı. Cari/Risk göstergelerinin hesabı 001 ek maddesinin işi; 002 yalnız düzen | `Components/Pages/{CariRisk,Gorevler,Asistan,Muhasebe,GelirTablosu}.razor` + alt bileşenler | H2, H3, AC-0.10 | 1 (CariRisk: ek madde dosyaya dokunmadan önce ya da sonra, sahiplik kuralıyla) |
| Asistan + Bellek | Birleşme | `GeniusBellek.razor` alt bileşen; Asistan'da Sohbet · Görevler · Bellek şeridi; giriş çubuğu alt bileşeni | `Asistan.razor`, `GeniusBellek.razor`, `Components/Shared/Asistan/AsistanGirisCubugu.razor` (yeni) | AC-2.5–2.7, 7.1 | 1 |
| Ayarlar, Eşikler | Sayfa | Telefonda salt-okuma görünüm + "Değişiklik masaüstünden yapılır." | `Ayarlar.razor` (Dalga 1), `Esikler.razor` (Dalga 2, 001 T-059 sonrası) | AC-6.6, 6.7 | 1/2 |
| `Bugun` | Sayfa | `/`; kart şeridi; Home ve Sabah alt bileşenleri; kapı ile gizleme | `Components/Pages/Bugun.razor` (yeni), `Home.razor` (`@page` kalkar) | H4, FR-003 | 1 |
| Bugün kartları | UI | Kart çerçevesi + 9 kart bileşeni | `Components/Shared/Bugun/*.razor` (yeni) | AC-4.1–4.17 | 1 (7), 2 (diğerleri; kart 5 kapısı `001:cari-risk`) |
| `BugunRenk` | Saf fonksiyon | Kart renk eşikleri (−%5/−%10, %95/%85, 2–3 g/4 g, %3, > 0) | `dashboard/Models/BugunRenk.cs` (yeni) | AC-4.4–4.13, 2.1 | 1 |
| `EskiAdres` | Sayfa | Altı eski adres → yeni yer, `replace: true` | `Components/Pages/EskiAdres.razor` (yeni) | AC-7.1, 7.2, 4.16, FR-010 | 1 (`/v2`, `/bellek`), 2 (öteki dördü) |
| Uyarı kuralları | Çekirdek | Kart 3 kontrol kümesi (Home `BuildAlerts`'in iki uyarı kuralı taşınır; plan K9) | `dashboard/Data/UyariKurallari.cs` (yeni) | AC-4.8, 4.9 | 2 |
| `OkulHizaliKiyas` | Saf fonksiyon | Kart 1 kıyas günü (plan K9) | `dashboard/Models/SezonAksiyonModels.cs` yanında yeni dosya | AC-4.4 | 2 |
| `VardiyaQueries.GetComplianceAsync` | Sorgu | İsteğe bağlı şube parametresi; Σ şube = şirket toplamı | `lib/Bkm.Shared/Data/VardiyaQueries.cs` | AC-4.13, 6.5 | 2 |
| B ekranları telefon özeti | Sayfa | Özet üstte, masaüstü bölümü `hidden lg:block` + not | Magazalar, Magaza, Eticaret, Sinav, Toplam, Tahmin, Envanter, Operasyon, Vardiya, Mizan | H5, H6, AC-3.3 | 2 (Toplam 1) |
| X birleşmeleri | Birleşme | Sadakat → Müşteri sekmesi; Bulunurluk → Satış analizi sekmesi; Satınalma ürün detayı → Satış analizi ürün detayı sekmesi; Sabah → Bugün | ilgili `.razor` | H7 | 2 |
| C ekranları taşma | Sayfa | Sayfa yana taşmaz; tablo kendi kutusunda kayar (`overflow-x-auto`, `min-w-0`, sabit genişlik kalkar) | 17 C ekranı | AC-6.2, SC-001a | 1 (001'in dokunmadıkları), 2 |
| Testler | Test | Birim, `WebApplicationFactory`, Playwright (`Tur=Mobil`) | `tests/GmDashboard.Tests/{Birim,Mobil,Kabuk}/**` | Tümü | 1–3 |
| Yardım + CHANGELOG | Doküman | Kurulum ve menü yardımı; sürüm notu | `docs/yardim/*.md`, `dashboard/CHANGELOG.md` | Madde 11 | 1–2 |

## Veri modeli

Bkz. `veri-modeli.md`. **Yeni tablo, kolon, view, SP yok. Yazma yok. Veri kaybı: yok.** Kapı durumu, kart tanımları ve yönlendirmeler kod sabitidir.

## Kontratlar

Bkz. `kontratlar/`:
- `README.md` — AC → bileşen → test eşlemesi
- `kabuk.md` — alt menü, sekme panelleri, rozet, PWA (manifest, SW, çevrimdışı), oturum, bağlantı kopması
- `telefon-kapisi.md` — kapı veri yapısı, anahtarlar, açma/geri alma yolu, testler
- `bugun.md` — Bugün kart sözleşmesi (değer, kaynak metot, renk, kapı, dokunuş hedefi, hata, boş durum)
- `ekranlar.md` — A/B ekranlarının telefon sözleşmesi, C asgarisi, Ayarlar/Eşikler salt-okuma
- `yonlendirmeler.md` — eski adres → yeni yer
- `olcum.md` — 375/44/16/ipucu/kapı ölçüm sözleşmesi

SP, API ucu ve yeni HTTP durum kodu yok. Tek HTTP davranış değişikliği: eski adreslerde 302 ve HTML yanıtında `Cache-Control: no-store`.

## Hata kodları

SP ve API olmadığı için 5xxxx kodu ve HTTP karşılığı yok; `db/hata-kodlari.yaml` bu depoda yok, açılmaz. Kullanıcıya görünen metinler:

| Durum | Metin | Kaynak AC |
|---|---|---|
| Veri kaynağı hata döndürdü (ekran ya da kart) | 001 `KullaniciMesajlari.VeriAlinamadi` ("Veriler şu anda alınamıyor. Sayfayı birkaç dakika sonra yenileyin; sorun sürerse sistem yöneticisine bildirin.") | AC-0.10 |
| Uygulama çevrimdışı açıldı | "Bağlantı yok. İnternet bağlantınızı kontrol edip yeniden deneyin." + **Yeniden dene** | AC-1.10 |
| Bağlantı koptu | Mevcut `ReconnectModal` metinleri ("Sunucuya yeniden bağlanılıyor…" …) | AC-1.11 |
| Kıyas günü yok | "Kıyas günü yok" (renk yok) | Sınır durum |
| Mağaza dün kapalı | "Kapalı" | Sınır durum |
| Kontroller koşamadı | "Kontroller koşamadı" | Sınır durum, AC-4.9 |
| B ekranında gizlenen bölüm | "Ayrıntı masaüstünde." | FR-007 |
| Ayarlar/Eşikler telefonda | "Değişiklik masaüstünden yapılır." | AC-6.6 |
| Görev silme onayı | "Görev silinsin mi? Bu işlem geri alınamaz." [**Sil**] [**Vazgeç**] | AC-2.4 |
| Gelir tablosu notu | "Tahakkuk esaslıdır, nakit akışı değildir." | AC-3.2 |
| Gün içi gösterge | "gün içi, saatte bir güncellenir" | Sınır durum |

## UI kararları

Kullanıcıya görünen yeni yerleşim var; iki nokta düşük güvenli, **`/ui-panel` önerilir**. Diğerleri mevcut DaisyUI desenine oturur.

1. **Sekme paneli biçimi (panel önerilir):** alt panel (sheet, önerilen) · açılır menü (`dropdown-top`) · ayrı merkez sayfası. Diğer paneli 3 + 17 satır taşır; açılır menüye sığmaz.
2. **Bugün kart düzeni (panel önerilir):** kart 1 dört satır (perakende, Sınav Okulları, toplam, e-ticaret) her biri ayrı renkle; kart sırası ve yoğunluğu; masaüstünde kartlar tek satır mı ızgara mı.
3. **Sabah brifingi Bugün'de:** açılır bölüm, açıldığında LLM çağrılır (önerilen; her açılışta ikinci LLM çağrısı olmaz) · her açılışta kendiliğinden üretilir (bugünkü Sabah davranışı).
4. **Kök menü etiketi:** "Bugün" (önerilen, terim tutarlılığı) · "Genel Bakış".
5. **Masaüstünde kart 2 ile hedef bandı tekrarı:** kart 2 masaüstünde de görünür (önerilen, tek düzen) · yalnız telefonda.
6. **Asistan başındaki şerit:** Sohbet · Görevler · Bellek (önerilen).
7. **Klavye açıkken alt menü:** telefonda bir giriş alanı odaktayken alt menü gizlenir (önerilen; AC-2.5'i iOS'ta da sağlamanın en basit yolu, `arastirma.md` § 3).
8. **Ayarlar/Eşikler salt-okuma görünümü:** değerler düz metin listesi, düğmeler yok (önerilen).

## Uygulama sırası ve 001 ile dosya sahipliği (soru 2)

**Kural:** bir dosyayı aynı anda iki spec değiştirmez. 001'in o dosyadaki son görevi bitip 001 master'a alınmadan 002 o dosyayı değiştirmez. İstisna: `Home.razor`'dan `@page` satırının kaldırılması (tek satır, otomatik birleşir).
**Dal:** `ork/002-mobil-kabuk-ekran`, 001 dalından 001 T-029 (`TimeProvider`) ve T-031 (`KullaniciMesajlari`) commit'lerinden sonra açılır. 001 dalı 002'ye `git merge` ile alınır (yeniden tabanlama yok). Master'a önce 001, sonra 002 alınır (insan kararı).

| Dosya | 001 görevleri | 002 dalgası |
|---|---|---|
| `MainLayout.razor`, `NavRegistry.cs`, `App.razor`, `Program.cs`, `wwwroot/*`, `Components/Shared/*` (DuzeltmeNotu hariç) | yok | **1** |
| `CariRisk`, `Gorevler`, `Asistan`, `GeniusBellek`, `Muhasebe`, `GelirTablosu`, `Ayarlar`, `Toplam`, `HomeV2` | yok | **1** |
| C ekranları: `Kadro`, `PatronSorulari`, `StokHareket`, `GiderMerkeziMizan`, `Yevmiye`, `Fatura` | yok | **1** |
| `GorevService`, `FinansQueries`, `GelirTabloQueries`, `MuhasebeQueries` | yok | **1** |
| `Home.razor` | T-045, T-046, T-069 | 1: yalnız `@page` satırı · 2: geri kalan |
| `Sabah.razor`, `SabahService.cs` | T-059 / T-044, T-057 | **2** |
| `Magaza` (T-046, T-048), `Magazalar` (T-073), `Eticaret` (T-039), `Sinav` (T-056), `Tahmin` (T-073), `Envanter` (T-036, T-050, T-054, T-059, T-065), `Operasyon` (T-059, T-069), `Vardiya` (T-059), `Mizan` (T-063) | var | **2** |
| `Musteri` (T-067), `Sadakat` (T-033, T-034, T-046), `SatisAnalizi` (T-054, T-065), `SatisAnaliziUrun` (T-061), `Bulunurluk`, `SatinalmaUrunDetay` | var / birleşme hedefi | **2** |
| C ekranları: `Trafik` (T-046), `HediyeCeki` (T-072), `OdakStok` (T-039, T-054), `BaskisiYok` (T-070), `SatinalmaAnaliz` (T-059, T-065), `SezonAksiyon` (T-065), `Esikler` (T-059) | var | **2** |
| `Queries.cs`, `EticQueries.cs`, `SinavQueries.cs`, `RefQueries*.cs` | var | 002 değiştirmez, yalnız çağırır |
| `ServiceRegistration.cs` | T-029 | 002 değiştirmez |
| `wwwroot/app.css` (üretilen) | her UI görevi | Commit'i yapan son görev yeniden üretir (`commit-discipline.md` § paylaşılan dosya) |

| Dalga | İçerik | Başlama koşulu | Bitiş ölçütü |
|---|---|---|---|
| **1** | Ölçüm altyapısı (Playwright + kırmızı ilk koşu) · kapı · kabuk · PWA · ortak bileşen dokunma düzeni · 001'den bağımsız A/B ekranları (Cari/Risk düzeni dahil, kapısı kapalı) · Asistan+Bellek · Ana sayfa v2 yönlendirmesi · ilk Bugün (yalnız kart 7; eski bölümler telefonda gizli) · Ayarlar salt-okuma · Toplam düzeni · 001'in dokunmadığı C ekranlarında taşma | 001 T-029 ve T-031 commit'li | Birim + `Tur=Mobil` yeşil (kapısı açık ekranlar); Android ve iOS kurulum denemesi (SC-003); CHANGELOG + kurulum yardımı |
| **2** | Bugün kart 1, 1a, 2, 3, 4, 5, 8 · Sabah birleşmesi · B ekranlarının telefon özeti · Sadakat, Bulunurluk, Satınalma ürün detayı birleşmeleri · kalan C ekranlarında taşma · Eşikler salt-okuma | 001 master'da (kart 5 için 001 Cari/Risk ek maddesinin kodu da) | Testler yeşil (kapı kapalı ekranlar "rapor" kipinde); AC-0.9 masaüstü karşılaştırması |
| **3** | Kapı açma commit'leri (madde başına) | `kabul-sonucu.md`'de ilgili satır "tuttu" | `KapananMaddeler_HepsiKabulSonucundaTuttu` yeşil; açılan ekran `Tur=Mobil`'de kırmızı kipten çıkıp kural kipinde yeşil |

## Riskler (taslak; risk analisti taraması bekleniyor — en fazla 7)

| # | Risk | Sınıf | Olas. | Etki | Erken sinyal | Önleyici | Kontenjans | Güven |
|---|---|---|---|---|---|---|---|---|
| R1 | **Cari/Risk göstergesi spec'in "vadesi geçen alacak"ını göstermiyor (ÖLÇÜLDÜ 08.10.2026).** Varsayılan sekme Satıcılar (320), KPI yalnız ilk 200 kaydın toplamı (`CariRisk.razor:92,114-120`): satıcı ilk 200 −147.310.896,38 TL, tüm satıcı −72.794.717,37 TL, alıcı (284) 1.229.462.178,38 TL; limit aşan 0. **GMY kararı 08.10.2026: önce düzelt, sonra telefona** — düzeltme 001 ek maddesi (`001:cari-risk`) | Stratejik | Kesin | Yüksek | — (gerçekleşti) | Cari/Risk ekranı ve kart 5 `001:cari-risk` kapısına bağlı; ilk Bugün yalnız kart 7 | Ek madde gecikirse Cari/Risk telefonda kapalı kalır; Finans sekmesinde Muhasebe ve Gelir tablosu açılır | Yüksek |
| R2 | Kart 1 kıyas günü ve kart 3 kontrol kümesi panelde hazır değildi (ÖLÇÜLDÜ: `Magazalar.razor:183-217` −364/elle; Sabah LLM brifingi; kurallar `Home.razor:398-422`). K9 ile karara bağlandı; kalan risk: yeni saf fonksiyonların (`OkulHizaliKiyas`, `UyariKurallari`) taşıma sırasında Ana sayfa uyarılarından sapması | Operasyonel | Düşük | Orta | Ana sayfa zili ile kart 3 farklı uyarı sayısı | Ana sayfa ve kart 3 aynı `UyariKurallari`'nı çağırır; eşik sınır testleri | Kart 3 kapısı kapalı tutulur | Yüksek |
| R3 | 001 Dalga 2 dosyalarını uzun süre tutar; 002 Dalga 2 bekler, ya da sıra kuralı çiğnenip çakışma çıkar | Operasyonel | Orta | Orta | 002 görevinde 001 sahipliğindeki dosya; `git merge` çakışması | Dosya sahipliği tablosu görev metinlerine girer; dalga başlama koşulu kapı olarak denetlenir | Çakışan dosya 001 bitene kadar görev ertelenir | Yüksek |
| R4 | CSS ile gizlenen masaüstü bölümlerinin sorgusu telefonda da koşar; tünel üstünden açılış yavaşlar (Cari/Risk tek başına ~10 sn, `CariRisk.razor:34`) | Operasyonel | Orta | Orta | Bugün açılışı > 5 sn (PerfState); telefonda "Yükleniyor" asılı | Kartlar bağımsız ve paralel yüklenir; ağır kart kendi iskeletini gösterir | `matchMedia` ile görünüm bildirimi + gizli bölümün gecikmeli yüklenmesi | Orta |
| R5 | Ölçüm aracı: Playwright onayı çıkmaz ya da hazır sinyali erken gelir ve taşma "yeşil" görünür (sayfa veri yüklenmeden ölçülür) | Operasyonel | Orta | Yüksek | Ölçüm süresi < 1 sn; kırılabilirlik denemesi yeşil kalır | Hazır sinyali üç koşullu; 45 sn'de KOŞAMADI = kırmızı; bilerek taşan öğe ile kırılabilirlik kanıtı | Onay yoksa Node + CDP betiği (yeni paket yok) | Orta |
| R6 | iOS farkları: `interactive-widget` desteklenmiyor; klavye düzen görünüm alanını küçültmüyor; maskable ikon yok sayılıyor; kurulum yalnız Safari paylaş menüsünden | Operasyonel | Yüksek | Orta | iOS denemesinde giriş çubuğu klavye altında | Odakta alt menü gizlenir; giriş çubuğu akış içinde; `apple-touch-icon` 180 px ayrı; yardım dokümanında iOS adımları | `visualViewport` ile küçük JS düzeltmesi | Orta |
| R7 | Kurulum ve SignalR (wss) testi güvenli bağlantı ister; geçici tünel kopar ya da 004 gecikir | Operasyonel | Orta | Orta | SC-003 denemesi tünel yüzünden yapılamıyor | Spec varsayımı: geçici tünel (05.10.2026'da çalıştı); Playwright `localhost` (güvenli bağlam) üzerinde koşar | SC-003 004'e kadar "karar bekliyor" yazılır | Yüksek |

Karar: **ilerle.** R1 GMY kararıyla kapandı (kapıya bağlandı); R2 K9 ile kapandı.

## Karmaşıklık takibi (anayasa istisnaları)

| İstisna | Gerekçe | Daha basit alternatif neden reddedildi | Onay |
|---|---|---|---|
| Yeni test bağımlılığı `Microsoft.Playwright` (Madde 5, PKG-005) | AC-0.5–0.8, SC-001/002 ölçülebilir kapı istiyor; düzen ancak gerçek tarayıcıda ölçülür | Elle önizleme tekrarlanmaz; bUnit düzen hesaplamaz; CDP betiği elle yazılmış otomasyon | GMY onayı 08.10.2026 · ADR-007 (Önerildi) |
| Telefonda salt-okuma ve gizleme yalnız CSS ile | Tek kullanıcı, cihaz ayrımı yetki sınırı değil; sunucu cihaz tanımaz (K2) | Sunucu tarafı cihaz tespiti: kullanıcı aracısına güvenmek kırılgan, ön çizimde görünüm bilinmez | Bilgi |
| 500+ satırlık C ekranları bölünmez | K8 | Hepsini bölmek: kapsam ve 001 çakışması büyür | Gerekli (TODO maddesi) |
| `theme-color` ve manifest renkleri onaltılık değer | Manifest ve meta etiketi CSS değişkeni okuyamaz | DaisyUI token burada uygulanamaz (`renk-standardi.md` istisnası) | Bilgi |

## ADR adayları

- **A1 — Telefon kapısı:** 001 bağımlılığı kod sabitiyle, git'teki kabul sonucuna testle bağlı açılır; çalışma anı ayarı yok. Neden kalıcı: 003 kartları (nakit) aynı kapıyı kullanacak. **ADR gerekli: evet**
- **A2 — Yaklaşım C ve tek kırılma noktası:** tek kaynak ekran, telefon/masaüstü ayrımı yalnız CSS `lg`; ayrı native uygulama ve `/m` rotaları reddedildi. 02–03.10'da karar verildi ama `docs/ADR/`'de yok. **ADR gerekli: evet**
- **A3 — Mobil düzen ölçümü için Playwright (test bağımlılığı).** GMY onayı 08.10.2026; taslak `docs/ADR/007-mobil-duzen-olcumu-playwright.md` (Önerildi). Numara 004 kullanılmaz, 005/006 001 T-076'ya ayrılı. **ADR gerekli: evet**
- **A4 — Service worker politikası:** yalnız çevrimdışı sayfa ve statik varlık önbellekte, veri ve HTML asla; HTML `no-store`. Neden kalıcı: telefonda veri saklamama (FR-011) gizlilik kararıdır, 003/004 SW'yi genişletirken bağlayıcı. **ADR gerekli: evet**
- Birleşen ekran = alt bileşen + yönlendirme sayfası (K5): desen planda yazılı. **ADR gerekli: hayır**
- Telefon kartı hesabı çekirdekte: mevcut `emitter-ayrimi.md` kuralının uygulaması. **ADR gerekli: hayır**

## Spec değişikliği gerekli (spec'e dokunulmadı; spec sahibi uygular)

GMY kararı 08.10.2026 (R1): Cari/Risk düzeltmesi 001'e ek madde; ekran ve kart 5 o madde kabul testinden geçince telefona açılır. Önerilen metinler:

1. **§ 001 bağımlılığı tablosu** — son satır şöyle olur:
   > | Cari/Risk | 001 ek maddesi: Cari/Risk tam toplam ve alıcı/satıcı ayrımı |
   > | Görevler, Asistan, Muhasebe, Gelir tablosu | yok — ilk telefon sürümünde açılır |
2. **H4 kart tablosu, kart 5 satırı:**
   > | 5 | Vadesi geçen alacak | Cari/Risk | 001 ek maddesi (Cari/Risk) |
3. **AC-2.1:**
   > **AC-2.1:** Verildiğinde 001'in Cari/Risk ek maddesi kabul testinden geçmiş ve telefonda Cari/Risk ekranı, Yapıldığında ekran açıldığında, O zaman en üstte alıcıların vadesi geçen alacak toplamı (bütün cariler, ilk N kayıt değil) ve kredi limitini aşan cari sayısı görünür; vadesi geçen tutar 0'dan büyükse kırmızı, limit aşan cari varsa sayı sarı gösterilir.
4. **Yeni AC-2.1a:**
   > **AC-2.1a:** Verildiğinde 001'in Cari/Risk ek maddesi kabul testinden geçmemiş, Yapıldığında telefonda Finans sekmesi açıldığında, O zaman Cari/Risk bağlantısı görünmez (AC-0.1).
5. **AC-4.11:**
   > **AC-4.11:** Verildiğinde 001'in Cari/Risk ek maddesi kabul testinden geçmiş ve vadesi geçen alacaklar, Yapıldığında kart 5 görüntülendiğinde, O zaman tutar ve limit aşan cari sayısı Cari/Risk ekranındaki değerle (AC-2.1) aynıdır ve aynı renk kuralını izler.
6. **AC-4.17:**
   > **AC-4.17:** Verildiğinde 001 maddelerinin ve 001 Cari/Risk ek maddesinin hiçbiri kabul testinden geçmemiş (ilk telefon sürümü), Yapıldığında GMY telefonda giriş yaptığında, O zaman Bugün ekranı açılır ve yalnız kart 7 görünür; alt bölümde hedef kartı ve dönem görünümü yer almaz.
7. **FR-003** ikinci cümlesi:
   > İlk telefon sürümünde de Bugün açılır ve yalnız 001'den bağımsız kartı (7 açık görevler) gösterir; öteki kartlar bağlı 001 maddeleri kapandıkça eklenir (karar 07.10.2026, güncelleme 08.10.2026; bkz. AC-4.17).
8. **SC-004** (Cari/Risk ilk sürümde kapalı olduğu için ölçüm koşulu):
   > **SC-004:** Telefonda açılış ekranından Görevler ve Asistan'a, 001 Cari/Risk ek maddesi kapandıktan sonra Cari/Risk'e en fazla iki dokunuşla ulaşılır (bugün üç).
9. **Kart 3 (K9) için kart tablosu satırı:**
   > | 3 | Bugünün uyarıları | Ana sayfa uyarı kuralları (Sabah bölümünde) | H10 (AC-10.1) + kart 1 koşulları |
   ve § Varsayımlar'daki "Kart 3, Sabah ekranının bugün koştuğu kontrolleri taşır" cümlesi: "Kart 3, Ana sayfanın bugünkü iki uyarı kuralını (mağaza cirosu −%10 ya da daha kötü; iade oranı %2'nin üstü) dün için koşar; yeni kontrol türleri 003 ile eklenir."
10. **§ Varsayımlar**, kıyas günü cümlesi: "Okul dönemine göre eşleşen geçen yıl günü: Temmuz–Ekim arasında okul açılış tarihleri farkı kadar geri (2026 için 371 gün), öteki aylarda 364 gün geri (aynı hafta günü)."

Ayrıca 001 tarafında: `specs/001-panel-veri-duzeltme/` için yeni ek madde (Cari/Risk tam toplam, alıcı/satıcı ayrımı, limit kolonu dolu mu ölçümü) spec/görev olarak açılmalı; kanıt `arastirma.md` § 8.

## İnsan onayı gerektirenler

Kapananlar (GMY 08.10.2026): R1 → 001 ek maddesi + kapı · Playwright onaylandı (ADR-007 Önerildi) · kart 1 kıyas günü ve kart 3 kontrol kümesi K9'da.

1. Plan onayı ve § Spec değişikliği gerekli metinlerinin spec'e işlenmesi.
2. 001 Cari/Risk ek maddesinin 001'e eklenmesi.
3. ADR A1, A2, A4 (A3 taslak yazıldı).
4. UI kararları 1 ve 2 için `/ui-panel`.
5. **Vardiya telefon özeti KVKK (FR-009):** CSS ile gizlenen isimli satırlar DOM'da durur. Öneri: kabul; Playwright görünür metinde ad/sicil olmadığını ölçer. `kvkk-denetcisi` görüşü önerilir.
6. 500+ satırlık C ekranlarının bölünmemesi (K8) ve TODO maddesi.
