# Plan 002: Telefon kabuğu ve ekranlar

**Durum:** Onaylandı (09.10.2026 — GMY; risk ŞART ve KVKK şartları işlendi) · **Spec:** `specs/002-mobil-kabuk-ekran/spec.md` (Onaylandı 08.10.2026) · **Tarih:** 08.10.2026
**Kardeş spec:** 001 (`specs/001-panel-veri-duzeltme/`, uygulamada; F0 tamam, F1 T-021'de) · **Seçilen yaklaşım:** C — tek kaynak, ekran genişliğine göre düzen + telefona kurulan web uygulaması (PWA). A (ayrı native uygulama) ve B (ayrı `/m` rota seti) 02–03.10.2026'da reddedildi (`.orkestra/calisma/gm-mobil-plan-taslak.md` §3).

## Özet

Panel tek bir Blazor uygulaması olarak kalır. Telefon ile masaüstü ayrımında tek kırılma noktası `lg` (1024 px): düzen CSS ile, içerik sunucuda — tarayıcı `matchMedia` ile görünümü bildirir, masaüstüne özgü bölüm, vardiya isimli satırları ve dışa aktarma telefonda hiç çizilmez ve yüklenmez (K2). Alt menü, `NavRegistry`'ye eklenen sınıf (A/B/C) ve sekme bilgisinden türer. 001'e bağlı bir ekranın ya da kartın telefonda görünmesini **kodda tek bir sabit** belirler: `TelefonKapisi.KapananMaddeler`. Bu küme yalnız 001 kabul sonucunu git'e yazan dosyada "tuttu" görünen maddelerle doldurulabilir; birim testi bunu zorlar. "/" adresi yeni **Bugün** sayfası olur; bugünkü Ana sayfa ve Sabah içerikleri bu sayfanın alt bileşenine dönüşür, masaüstünde eksiksiz kalır. Birleşen beş ekran ve Sabah bir yönlendirme sayfasıyla yeni yerine gider. Telefon kartlarının hesabı Razor'dan `Data/` çekirdeğine taşınır; ekran ve kart aynı metodu çağırır (FR-005). 375 px taşma, 44 px dokunma, ipucu, 16 px giriş ve kapı kuralları canlı uygulamaya karşı Playwright testleriyle ölçülür (yeni test bağımlılığı; GMY onayı 08.10.2026, ADR-007 taslağı).

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

**Kapı neyi etkiler:** (i) telefon sekme panellerindeki bağlantılar, (ii) Bugün kartları (her görünümde — yanlış rakam yeni karta da taşınmaz), (iii) Bugün sayfasındaki eski Ana sayfa ve Sabah bölümleri: kapı kapalıyken telefonda **çizilmez ve verisi yüklenmez**, masaüstünde bugünkü gibi çizilir (AC-0.9; mekanizma K2). Masaüstü menüsü kapıdan etkilenmez. Kapalı ekran doğrudan adresle açılırsa bugünkü düzeniyle açılır (spec varsayımı).

### K2 — Telefon/masaüstü ayrımı: düzen CSS'te, içerik sunucuda (güncelleme 2, risk taraması R6/R7)

Tek kırılma noktası `lg` (1024 px): altı telefon, üstü masaüstü; mevcut kabuk bu kırılmayı kullanıyor (`MainLayout.razor`: `lg:drawer-open`, `btm-nav lg:hidden`). İlk taslak ayrımı yalnız CSS'e bırakıyordu; risk taraması iki sonucu kabul etmedi: telefonda gizli bölümün sorgusu yine koşuyordu (R7) ve vardiya isimli satırlar DOM'da kalıyordu (R6). Bu yüzden ayrım ikiye bölündü:

- **Düzen** (sütun sayısı, boşluk, dokunma boyutu, alt menünün görünmesi) CSS'te kalır: `lg:` önekli sınıflar.
- **İçerik** (yalnız masaüstünde gösterilen bölüm, isimli satır, düzenleme formu) sunucuda karar verilir: bölüm `Gorunum == Masaustu` değilse **çizilmez ve verisi yüklenmez**; yerinde "Ayrıntı masaüstünde." notu durur (FR-007).
- `Gorunum` bilgisi: `wwwroot/js/gorunum.js` içinde `matchMedia('(min-width: 1024px)')` sonucu ilk etkileşimli çizimde ve her değişimde (döndürme, pencere boyutu) Blazor'a bildirilir. `Components/Layout/GorunumSaglayici.razor` bunu `CascadingValue<Gorunum>` (`Bilinmiyor`, `Telefon`, `Masaustu`) olarak dağıtır. Çerçeve sarmalanmıyor: tek JS çağrısı + Blazor'un kendi `CascadingValue`'su.
- **Ön çizimde ve `Bilinmiyor` iken** masaüstüne özgü bölüm çizilmez (güvenli taraf: isimli satır ve ağır sorgu önce telefon varsayımıyla durur). Masaüstünde bu bölümler bağlantı kurulup görünüm bildirilince yüklenir; masaüstü açılışı ön çizim kadar gecikir (ÇIKARIM, Dalga 1 sonunda ölçülür).
- Kapı (K1) ile birlikte kural: `Çiz = Gorunum == Masaustu || TelefonKapisi.Acik(anahtar)`. `TelefonKapisi.TelefondaGizle` CSS yardımcısı kaldırıldı.
- Bu bir arayüz kararıdır, yetki sınırı değil (tek kullanıcı): telefonda tarayıcıyı masaüstü kipine alan kullanıcı masaüstü içeriğini görür.
- **Vardiya isimli satırlar (KVKK K2, karar):** telefonda DOM'a **ve SignalR akışına** hiç gönderilmez; CSS gizleme kabul edilmez. Seçilen yol **`matchMedia` bildirimi**: `GetRowsAsync` (ad, sicil, not) yalnız `Gorunum == Masaustu` iken çağrılır; `Telefon` ve `Bilinmiyor` iken sorgu koşmaz, bileşen durumunda isimli kayıt tutulmaz, yerinde "Kişi satırları masaüstünde." notu durur. Masaüstünden telefona geçişte (pencere daralması) isimli liste bileşen durumundan silinir.
  Reddedilen yol — masaüstünde "Kişi satırlarını göster" düğmesiyle istek üzerine yükleme: daha az hareketli parça taşır ama masaüstündeki bugünkü davranışı değiştirir (satırlar açılışta görünmez olur; AC-0.9 "masaüstünde her tablo yerinde durur" ile çelişir) ve aynı mekanizma R7 için zaten kuruluyor.
- **Dışa aktarma (KVKK K5):** `ExcelButton` ve öteki dışa aktarma düğmeleri yalnız `Gorunum == Masaustu` iken çizilir; telefonda cihaza dosya inmez (FR-011). Kural `kontratlar/olcum.md`'de ölçülür.

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
- **Kurulum testi ve tünel kuralı (risk taraması R1, varoluşsal):**
  1. SC-003 kurulum testi önce **tünelsiz** yapılır: LAN'da mevcut HTTPS 5443 + `/ca.crt` (telefon CA'yı indirip güvenir; `Program.cs` "PWA için CA sertifikası indirme" ucu). Android'de bu yol 05.10.2026'dan önce çalışıyordu. iOS'ta CA profili ayrıca "tam güven" ayarı ister; yardım dokümanına yazılır.
  2. Tünel yalnız LAN yolu yetmezse ve şu koşulların **hepsi** sağlanınca açılır: **kişisel veri taşıyan sayfaların tünelden geçmesi için hukuki görüş (KVKK raporu S1, gerekirse S2) alınmış** · `dotnet publish` çıktısı · `ASPNETCORE_ENVIRONMENT=Production` · `UseForwardedHeaders` devrede (yönlendirme ve çerez `https` görür) · panel kullanıcı tablosu dolu (`/setup` → `/login` yönlendirmesi önce ölçülür) · Cloudflare Access (e-posta tek kullanımlık kod) önünde · süreli (test bitince kapatılır, kapanış saati journal'a yazılır).
  3. Tünel açılmadan önce **duman testi**: tünel adresine oturumsuz `GET /` → 302 `/login` ve `Location` `https` ile başlar; `/mizan`, `/magaza/1`, `/vardiya` için de 302. Biri 200 dönerse tünel açılmaz.
  4. **Development örneği hiçbir tünele bağlanmaz** (Development'ta oturum kuralı yok, `Program.cs:32-37`).
  5. Ölçülmüş durum (denetleyici, 05.10.2026): Production + publish + 127.0.0.1 ile tünel denendi; `/`, `/mizan`, `/magaza` → 302 `/login`; ancak `UseForwardedHeaders` yoktu, yönlendirme `http`'ye düşüyordu. Bu yüzden 2. maddenin `UseForwardedHeaders` koşulu bugün sağlanmıyor.
- **Karar — `UseForwardedHeaders` 004'te yapılır, 002'de değil.** Gerekçe: ters vekil arkasında yayın (bilinen vekil adresleri, `X-Forwarded-Proto`, HSTS) 004'ün kapsamı (sunucu, kalıcı erişim); 002'de eklenirse vekil güven listesi 004'ten önce ve onsuz yazılmış olur. Sonuç: 002 Dalga 1 kurulum doğrulaması **yalnız LAN'da (5443)** yapılır; tünelle kurulum testi 004 tamamlanana ve S1 hukuki görüşü gelene kadar yapılmaz.
- **Kanıt dosyaları (KVKK K6):** canlı veriyle alınan Playwright ekran görüntüsü, trace ve video çıktıları ile cihaz ekran görüntüleri commit edilmez. Dalga 1 görevi: `tests/GmDashboard.Tests/Mobil/cikti/` (Playwright çıktı klasörü) `.gitignore`'a eklenir; kabul kanıtında kişisel veri taşıyan ekranlar için yalnız ölçüm sonucu (sayılar) yazılır, görüntü gerekiyorsa maskelenir. SC-003 iOS adımı LAN'da CA güveni kurulamazsa 004'e kadar "karar bekliyor" yazılır.

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

### K10 — Dalga 1 001'i beklemeden yayınlanır (GMY 08.10.2026, risk R4 Seçenek 1)

GMY: "maskele sürüm çıksın". 002 dalı master'dan açılır; Dalga 1 001 bitmeden master'a ve yayına çıkar. İlk telefon sürümünün içeriği: kabuk + PWA + kapı + Görevler/Asistan/Muhasebe/Gelir tablosu + Bugün kart 7. Müşteri, Trafik ve Sadakat ilk sürümde telefonda **kapalı** (K11, GMY 09.10.2026). T-029/T-031 ihtiyacı ve dosya sahipliği § Uygulama sırası'nda (ON-1, dar istisna yalnız `Home.razor` `@page`). Oturum yönetimi (K12) Dalga 1'in parçasıdır ve telefon kurulumundan önce biter; böylece GMY'nin kalıcı telefon kurulumu 004'ü beklemez.

### K11 — Müşteri, Trafik, Sadakat: ilk sürümde telefonda kapalı, 001 maddesi kapanınca maskeli açılır (GMY 08.10 + 09.10.2026, KVKK K4 Seçenek B)

- **Kapı:** üç ekran telefon kapısına bağlanır: `ekran:trafik` → `001:H5`; `ekran:musteri` → `001:D-1`; `ekran:sadakat` → `001:H2`, `001:H5` (`kontratlar/telefon-kapisi.md` § 3). Kapı kapalıyken bağlantı "Masaüstünde daha iyi" listesinde **bağlantısız** satır olarak durur ("Masaüstünde açılır").
- **Doğrudan adres koruması (Dalga 1, 001 dosyalarına dokunmadan):** spec varsayımı "kapısı kapalı ekran doğrudan adresle bugünkü düzeniyle açılır" bu üç ekran için **uygulanmaz**, çünkü bugünkü düzen maskesiz kişisel veri gösterir. `MainLayout` (002'nin dosyası) bulunulan adres `TelefonKapisi.KisiselVeriEkranlari` kümesindeyse, `Gorunum != Masaustu` ve kapı kapalıysa `@Body` yerine "Bu ekran masaüstünde açılır." notunu çizer. Sayfa bileşeni hiç kurulmaz, sorgu koşmaz, DOM'a ve devreye veri gitmez. Masaüstünde değişiklik yok.
- **Maskenin yeri — karar: saf maske katmanı Dalga 1'de, Razor hücreleri Dalga 2'de.** `KisiselVeriMaske.cs` (saf fonksiyonlar + birim testleri) yeni dosyadır, 001 ile çakışmaz; Dalga 1'de yazılır. `Musteri.razor` (001 T-067), `Trafik.razor` (T-046), `Sadakat.razor` (T-033, T-034, T-046) hücrelerinin maskeye bağlanması **Dalga 2'de, 001 master'a girdikten sonra** yapılır. Gerekçe: kapı ancak 001 maddesi kapanınca açılır; 001 bu üç dosyayı değiştirmeyi bitirmeden maske hücresi yazmak hiçbir şey kazandırmaz, yalnız çakışma üretir. Kapı açma commit'i (Dalga 3) maskeli hücreler ve maske ölçümü yeşil değilse yapılmaz (`kontratlar/telefon-kapisi.md` § 5 ön koşul testi).

- Bağlantılar "Masaüstünde daha iyi" listesinde kalır. Ekran telefonda açılınca kişisel alanlar **sunucuda, çizim anında** maskelenir. DOM'a ve SignalR akışına açık değer gitmez. Masaüstü (`Gorunum == Masaustu`) değişmez.
- `Gorunum` `Bilinmiyor` iken (ön çizim dahil) maske uygulanır (güvenli taraf).
- Maske tek yerde: `dashboard/Models/KisiselVeriMaske.cs` (saf fonksiyonlar). Kurallar `kontratlar/ekranlar.md` § Maskeleme.
- Kapsam: Müşteri (ad, telefon, kart no), Sadakat (win-back listesi; Dalga 2'de Müşteri'ye birleşir, maske birlikte taşınır), Trafik (kasiyer adı). Dışa aktarma telefonda zaten yok (K2).
- Sorgu ve hesap değişmez (FR-012); maske yalnız gösterim. Dalga 1'de 001 dosyalarına dokunulmaz.
- Sınır: maske arayüz kuralıdır, yetki sınırı değildir; masaüstü görünümüne geçen aynı oturum açık değeri görür.

### K12 — Oturum kaydı, uzaktan kapatma, mutlak ve boşta süre (denetleyici kararı 08.10.2026, GMY yetkisiyle; KVKK K3 Seçenek B)

Gerekçe: GMY K10 ile gerçek telefon kullanımını 004'ü beklemeden istedi; kaybolan telefonda oturumu kapatamamak KVKK raporunda Yüksek (K3). Bu yüzden oturum yönetimi Dalga 1'in parçasıdır ve **telefon kurulumundan önce** biter. Parola sıfırlama ve dışarıdan erişim koruması 004'te kalır.

- **Kayıt:** girişte BkmPanel'de `dbo.PanelOturum`'a satır yazılır (şema `veri-modeli.md` § 6). Oturum kimliği (`Guid`) çereze `oid` talebi olarak girer. ERP'ye yazma yok; `dbo.Panel*` panelin kendi deposu (`erp-write-policy.md` § bağlantı bazlı yetki).
- **Denetim iki katmanda**, çünkü Blazor Server'da çerez yalnız HTTP isteğinde okunur, açık devre (SignalR) çerezi yeniden görmez:
  1. HTTP: `CookieAuthenticationEvents.OnValidatePrincipal` her istekte satırı okur. İptal edilmiş, mutlak süresi dolmuş ya da boşta süresi aşılmışsa `RejectPrincipal()` + `SignOutAsync` → `/login`.
  2. Açık devre: çerçevenin kendi `RevalidatingServerAuthenticationStateProvider`'ı **1 dakikada bir** aynı kuralı koşar. Geçersizse kimlik anonime döner; `MainLayout` `AuthenticationStateChanged`'i dinler ve `NavigateTo("/login", forceLoad: true)` yapar. Ekranda rakam kalmaz.
- **Boşta süre ölçümü:** kullanıcı etkileşimi çerçevenin `CircuitHandler.CreateInboundActivityHandler`'ı ile yakalanır (devreye gelen her olay). HTTP isteği de etkinlik sayılır. `SonGorulme` en fazla 1 dakikada bir yazılır (yeniden doğrulama turunda), her olayda değil.
- **Süreler (öneri, gerekçeli):** **mutlak 7 gün, boşta 12 saat.** Çerez kalıcı (`IsPersistent = true`, son kullanma = mutlak bitiş); `SlidingExpiration` kapatılır, süre kararını sunucudaki satır verir.
  - Neden boşta 30 dk değil: GMY uygulamayı sabah açar, gün içinde arada bir bakar. 30 dakikalık boşta süreyle neredeyse her açılışta telefona parola yazılır. Bu durumda mutlak 7 gün anlamsızlaşır, kullanım bırakılır (risk R4). Biyometrik giriş (WebAuthn) bu spec'te yok.
  - Neden 12 saat: gece boyunca açık kalan oturum sabah yeniden parola ister. Bir oturum en fazla bir iş günü sahipsiz kalır. Günde en çok bir parola girişi olur.
  - Neden mutlak 7 gün: haftada bir kesin yeniden giriş; çalınmış bir çerezin ömrünü sınırlar.
  - Kayıp telefonda asıl önlem süre değil, **"Bütün oturumları kapat"** düğmesi (en geç 1 dakikada etkili) ve telefonda ekran kilidi şartıdır (yardım dokümanı).
  - Daha sıkı seçenek (KVKK raporunun önerdiği mutlak 12 saat + boşta 30–60 dk): sabit değiştirilerek tek satırla geçilir. Bedeli her açılışta parola yazmak. Süreler kodda tek yerdedir (`OturumKurali.MutlakSure`, `BostaSure`); yapılandırmaya taşınmaz.
- **"Bütün oturumları kapat":** masaüstünde Ayarlar → **Oturumlar** bölümü. Bölüm açık oturumları cihaz özeti ("Android · Chrome", "Windows · Edge") ve son görülme zamanıyla listeler. Düğme onay ister ("Bütün oturumlar kapatılsın mı? Bu cihaz dahil her yerde yeniden giriş gerekir. [Kapat] [Vazgeç]"). Onaylanınca kullanıcının bütün satırlarında `IsValid = 0`, `IptalNedeni = 'hepsi'` olur; bu cihaz da `/login`'e gider. Telefonda bölüm salt okunur (K2 kuralı); düğme yalnız masaüstünde.
- **Çıkış:** `/auth/logout` kendi satırını `IptalNedeni = 'cikis'` ile kapatır.
- **Kişisel veri en aza:** IP adresi tutulmaz. Cihaz özeti `User-Agent`'tan türetilmiş kısa metindir (en çok 60 karakter), ham `User-Agent` saklanmaz. Saklama süresi hukuka soruldu (KVKK S8); karar gelene kadar satır silinmez (hard delete yok, RUN-008).
- **Development:** oturum kuralı Development'ta da çalışır, ancak yalnız bir kullanıcı oturum açmışsa (Development anonim ön izlemeyi bozmaz: anonim istekte satır aranmaz).
- Spec etkisi: yeni AC'ler ve FR, § Spec değişikliği gerekli madde 11–16.

## Anayasa kapıları

| Madde | Soru | Sonuç | Not |
|---|---|---|---|
| 1 Test-önce | Her davranış için önce kırmızı test planlandı mı? | ✅ | Bugün kırmızı vermesi beklenenler ölçüldü: 02.10 denetiminde 40 ekranın yaklaşık yarısında taşma, ~24 px hedef; alt menü sırası, kapı, yönlendirme, manifest maskable ikonu, çevrimdışı sayfa, görev silme onayı bugün yok. Testler test yazarı rolünde; Playwright testleri ilk koşuda kırmızı görülür |
| 2 Runtime kuralları | DMY, compat, DECIMAL, src.*, IsValid | ✅ | Tek yeni tablo `BkmPanel.dbo.PanelOturum` (K12): PK, adlı FK + indeks, `IsValid` soft delete (hard delete yok), `datetime2(3)` UTC, idempotent kurulum + geri alma betiği; ERP değil. Okuma tarafında yeni ERP SQL yok. Kart 8'in şube süzgeci (Dalga 2) mevcut sorgunun parametreli hâli; her alt sorgu kendi süzgecini taşır (`vardiya_kapsam_denetimi.py` çıkış 0). Para `decimal`. Ekranda tarih gg.aa.yyyy |
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
| `TelefonKapisi` | Static sınıf | Bağımlılık sözlüğü, kapanan maddeler, `Acik()` | `dashboard/Models/TelefonKapisi.cs` (yeni) | AC-0.1, 0.2, 3.4, 4.2, 4.14, 4.17, FR-004 | 1 |
| `NavRegistry` | Kayıt | `Sinif` (A/B/C), `MobilSekme`, X öğeleri çıkar, "Bugün" etiketi | `dashboard/Models/NavRegistry.cs` | AC-1.4, 1.8, 6.1, 7.4 | 1 |
| `MainLayout` | Kabuk | Beş sekme, sekme paneli, geciken rozeti, güvenli alan boşluğu, Sabah bağlantısı kalkar, CFO menüsü `<a href>` | `Components/Layout/MainLayout.razor` (+ yeni `Components/Layout/MobilSekmePaneli.razor`) | AC-1.4–1.8, 1.7 | 1 |
| `KisiselVeriMaske` | Saf fonksiyon | Ad, telefon, kart no maskesi (K11); `Gorunum != Masaustu` iken Müşteri/Sadakat/Trafik hücrelerinde | `dashboard/Models/KisiselVeriMaske.cs` (yeni) | KVKK K4 | 1 (fonksiyon + birim test), 2 (Razor hücreleri) |
| Kişisel veri ekranı koruması | Kabuk | Kapısı kapalı Müşteri/Trafik/Sadakat telefonda doğrudan adresle açılırsa `@Body` yerine not | `Components/Layout/MainLayout.razor`, `Models/TelefonKapisi.cs` (`KisiselVeriEkranlari`) | KVKK K4, K11 | 1 |
| Oturum yönetimi | Servis + kabuk | `dbo.PanelOturum` yazma/okuma (`OturumService`), süre kuralı (`OturumKurali`, saf, `TimeProvider`), `OnValidatePrincipal`, `RevalidatingServerAuthenticationStateProvider` (1 dk), `CircuitHandler` etkinlik, giriş/çıkış uçlarında satır, MainLayout'ta anonime dönünce `/login`; Ayarlar → Oturumlar + "Bütün oturumları kapat" | `dashboard/Data/OturumService.cs` (yeni), `dashboard/Models/OturumKurali.cs` (yeni), `dashboard/Data/OturumDogrulayici.cs` (yeni), `dashboard/Program.cs`, `dashboard/ServiceRegistration.cs` (`AddBkmDurum`), `Components/Layout/MainLayout.razor`, `Components/Pages/Ayarlar.razor` (+ alt bileşen `Components/Shared/Oturumlar.razor`), `sorgular/2026-10-xx-panel-oturum-kur.sql` (yeni, idempotent) | AC-1.12–1.16, FR-014 | 1 (kurulumdan önce) |
| `GorunumSaglayici` + `gorunum.js` | Kabuk | `matchMedia('(min-width: 1024px)')` → `CascadingValue<Gorunum>` (`Bilinmiyor`/`Telefon`/`Masaustu`); masaüstüne özgü içerik, vardiya isimli satırlar ve dışa aktarma yalnız `Masaustu` iken çizilir/yüklenir | `Components/Layout/GorunumSaglayici.razor` (yeni), `wwwroot/js/gorunum.js` (yeni) | FR-007, FR-009, FR-011, AC-0.9 | 1 |
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
| B ekranları telefon özeti | Sayfa | Özet üstte; masaüstü bölümü yalnız `Gorunum == Masaustu` iken çizilir ve yüklenir, telefonda yerinde not (K2) | Magazalar, Magaza, Eticaret, Sinav, Toplam, Tahmin, Envanter, Operasyon, Vardiya, Mizan | H5, H6, AC-3.3 | 2 (Toplam 1) |
| X birleşmeleri | Birleşme | Sadakat → Müşteri sekmesi; Bulunurluk → Satış analizi sekmesi; Satınalma ürün detayı → Satış analizi ürün detayı sekmesi; Sabah → Bugün | ilgili `.razor` | H7 | 2 |
| C ekranları taşma | Sayfa | Sayfa yana taşmaz; tablo kendi kutusunda kayar (`overflow-x-auto`, `min-w-0`, sabit genişlik kalkar) | 17 C ekranı | AC-6.2, SC-001a | 1 (001'in dokunmadıkları), 2 |
| Testler | Test | Birim, `WebApplicationFactory`, Playwright (`Tur=Mobil`) | `tests/GmDashboard.Tests/{Birim,Mobil,Kabuk}/**` | Tümü | 1–3 |
| Yardım + CHANGELOG | Doküman | Kurulum ve menü yardımı; sürüm notu | `docs/yardim/*.md`, `dashboard/CHANGELOG.md` | Madde 11 | 1–2 |

## Veri modeli

Bkz. `veri-modeli.md`. **Bir yeni tablo: `BkmPanel.dbo.PanelOturum`** (K12; panelin kendi deposu, ERP değil). Başka tablo, kolon, view, SP yok. ERP'ye yazma yok. **Veri kaybı: yok** (yeni tablo; mevcut veri değişmez). Kapı durumu, kart tanımları ve yönlendirmeler kod sabitidir.

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

## Uygulama sırası ve 001 ile dosya sahipliği (soru 2; K10 ile yeniden yazıldı)

**Dal (K10):** `ork/002-mobil-kabuk-ekran` **master'dan** açılır. Dalga 1 001'i beklemeden master'a alınır (merge insan kararı). 001 dalı master'ı `git merge` ile alır (yeniden tabanlama yok); 001 master'a daha sonra girer. Dalga 2, 001 master'a girdikten sonra başlar.

**Kural:** bir dosyayı aynı anda iki spec değiştirmez. 002 Dalga 1, 001'in görevlerinin dokunduğu dosyalara yalnız aşağıdaki **dar istisnalarla** dokunur. İstisnalar, 001'in o dosyadaki değişikliğinden farklı bir bölgede birkaç satırdır. Böylece 001 master'ı aldığında `git merge` bunları otomatik birleştirir. Her istisna commit'inin gövdesinde "001 dosyası, dar istisna" yazar. 001 dalı her 002 Dalga 1 merge'ünden sonra master'ı alır; çakışma 001 tarafında çözülür ve 002'nin satırları korunur.

**Ön koşul (ON-1, Dalga 1'in ilk görevi) — T-029/T-031 ihtiyacı:** 002'nin 001'den ihtiyacı iki şeydir: DI'da `TimeProvider` ve `KullaniciMesajlari.VeriAlinamadi`.
- ON-1 `dashboard/ServiceRegistration.cs` `AddBkmVeri` içine **001 T-029'daki satırın birebir aynısını** ekler: `s.AddSingleton(TimeProvider.System);`.
- ON-1 `dashboard/Data/Tanimlar/KullaniciMesajlari.cs` dosyasını **001 T-031 "Üretir" satırındaki dört sabitle birebir aynı** içerikle yazar (ad, sıra, metin).
- `DuzeltmeNotlari` (T-029'un geri kalanı) 002'ye alınmaz; 002 ona ihtiyaç duymaz.
- Sonuç: 001 master'ı aldığında T-031 "dosya zaten var, sözleşmeyle aynı mı doğrula" görevine, T-029 yalnız `DuzeltmeNotlari` görevine iner (bkz. § 001'e eklenecek görevler G-3). Aynı satırı iki dalın eklemesi, satırlar birebir aynıysa çakışma üretmez. Fark varsa çakışma 001 tarafında görünür; sessiz kalmaz.
- Reddedilen yollar: (a) 002 dalını 001'den açmak — Dalga 1'i 001'e bağlar, K10 ile çelişir. (b) 001'in T-029/T-031 commit'lerini cherry-pick etmek — T-029 henüz yazılmadı ve T-023'e bağlı; yazılınca `DuzeltmeNotlari`'nı da taşır. (c) 002'de ayrı bir hata metni sabiti — iki doğruluk kaynağı oluşur (`emitter-ayrimi.md`).

| Dosya | 001 görevleri | 002 |
|---|---|---|
| `MainLayout.razor`, `NavRegistry.cs`, `App.razor`, `Program.cs`, `wwwroot/*`, `Components/Shared/*` (DuzeltmeNotu hariç), yeni `Components/Layout/*`, `Models/TelefonKapisi.cs`, `Models/KisiselVeriMaske.cs` | yok | **Dalga 1** |
| `ServiceRegistration.cs` (yalnız `TimeProvider` satırı), `Data/Tanimlar/KullaniciMesajlari.cs` | T-029, T-031 | **Dalga 1, ON-1** (birebir 001 sözleşmesi) |
| `CariRisk`, `Gorevler`, `Asistan`, `GeniusBellek`, `Muhasebe`, `GelirTablosu`, `Ayarlar`, `Toplam`, `HomeV2` | yok | **Dalga 1** |
| C ekranları: `Kadro`, `PatronSorulari`, `StokHareket`, `GiderMerkeziMizan`, `Yevmiye`, `Fatura` | yok | **Dalga 1** |
| `GorevService`, `GelirTabloQueries`, `MuhasebeQueries` | yok | **Dalga 1** |
| `Home.razor` | T-045, T-046, T-069 | Dalga 1 dar istisna: yalnız `@page` satırı · Dalga 2: geri kalan |
| `Musteri.razor` (T-067), `Trafik.razor` (T-046), `Sadakat.razor` (T-033, T-034, T-046) | var | **Dalga 2** (001 master'da): maske hücreleri (`KisiselVeriMaske` + `CascadingParameter Gorunum`), taşma, düzen, Sadakat birleşmesi. Dalga 1 bu dosyalara dokunmaz; telefonda erişimi `MainLayout` koruması keser (K11) |
| `Sabah.razor`, `SabahService.cs` | T-059 / T-044, T-057 | **Dalga 2** |
| `Magaza` (T-046, T-048), `Magazalar` (T-073), `Eticaret` (T-039), `Sinav` (T-056), `Tahmin` (T-073), `Envanter` (T-036, T-050, T-054, T-059, T-065), `Operasyon` (T-059, T-069), `Vardiya` (T-059), `Mizan` (T-063) | var | **Dalga 2** |
| `SatisAnalizi` (T-054, T-065), `SatisAnaliziUrun` (T-061), `Bulunurluk`, `SatinalmaUrunDetay` | var / birleşme hedefi | **Dalga 2** |
| C ekranları: `HediyeCeki` (T-072), `OdakStok` (T-039, T-054), `BaskisiYok` (T-070), `SatinalmaAnaliz` (T-059, T-065), `SezonAksiyon` (T-065), `Esikler` (T-059) | var | **Dalga 2** |
| `Queries.cs`, `EticQueries.cs`, `SinavQueries.cs`, `RefQueries*.cs`, `SadakatQueries.cs`, `TrafikQueries.cs` | var | 002 değiştirmez, yalnız çağırır (maske Razor'da çizim anında, sorguda değil) |
| `FinansQueries.cs` | 001 G-1 (Cari/Risk ek maddesi) | 002 değiştirmez |
| `wwwroot/app.css` (üretilen) | her UI görevi | Commit'i yapan son görev yeniden üretir; 001 master'ı alınca yeniden üretilir (`commit-discipline.md` § paylaşılan dosya) |

| Dalga | İçerik | Başlama koşulu | Bitiş ölçütü |
|---|---|---|---|
| **1 — ilk telefon sürümü (001'den önce yayınlanır)** | ON-1 · **oturum yönetimi (K12) — kurulum denemesinden önce biter** · ölçüm altyapısı (Playwright + kırmızı ilk koşu) · kapı (`KapananMaddeler` boş) · görünüm bildirimi (`GorunumSaglayici`) · kabuk (beş sekme, paneller, rozet) · PWA (manifest, ikonlar, SW, çevrimdışı sayfa, `no-store`) · ortak bileşen dokunma düzeni · **Görevler, Asistan (+ Bellek sekmesi), Muhasebe, Gelir tablosu** telefon düzeni · **Bugün yalnız kart 7** (eski bölümler telefonda çizilmez) · `KisiselVeriMaske` saf fonksiyonu + birim testleri · Müşteri/Trafik/Sadakat telefonda **kapalı**: panelde bağlantısız satır + `MainLayout` doğrudan adres koruması (K11) · Ana sayfa v2 ve `/bellek` yönlendirmeleri · Ayarlar salt-okuma · Cari/Risk ve Toplam düzeni (kapıları kapalı) · 001'in dokunmadığı C ekranlarında taşma · Playwright çıktı klasörü `.gitignore` · CHANGELOG + kurulum yardımı (kayıp telefon bölümü dahil) | Plan onayı | Birim + `Tur=Mobil` yeşil (Development ve Production yayın turu, `olcum.md` § 1) · kişisel veri ekranı koruması ölçümü yeşil ve kırılabilirliği gösterilmiş · oturum testleri yeşil (süre kuralı birim, BkmPanel entegrasyon, "Bütün oturumları kapat" Playwright) · LAN 5443 üzerinden Android ve iOS kurulum denemesi (SC-003; K12 bittikten sonra) · master'a merge (insan kararı) |
| **2** | Bugün kart 1, 1a, 2, 3, 4, 5, 8 · Sabah birleşmesi · B ekranlarının telefon özeti · Sadakat, Bulunurluk, Satınalma ürün detayı birleşmeleri · **Müşteri/Trafik/Sadakat maske hücreleri + maske ölçümü** (kapıları kapalı kalır) · Müşteri/Trafik taşma ve düzen · kalan C ekranlarında taşma · Eşikler salt-okuma | 001 master'da (kart 5 için 001 G-1'in kodu da) | Testler yeşil (kapı kapalı ekranlar "rapor" kipinde); AC-0.9 masaüstü karşılaştırması |
| **3** | Kapı açma commit'leri (madde başına) | `kabul-sonucu.md`'de ilgili satır "tuttu" ve dolu `Kanıt` | `KapananMaddeler_HepsiKabulSonucundaTuttu` yeşil; açılan ekran `Tur=Mobil`'de rapor kipinden kural kipine geçip yeşil |

## Riskler (risk analisti taraması 08.10.2026 — karar ŞART; kaynak `.orkestra/calisma/002-mobil-kabuk-ekran/risk-raporu.md`)

Taslaktaki Cari/Risk ve kart 1/3 riskleri GMY kararıyla kapandı (§ Spec değişikliği gerekli, K9). Numaralar risk raporununkidir.

| # | Risk | Sınıf | Olas. | Etki | Önleyici (planda nerede) | Kontenjans | Durum |
|---|---|---|---|---|---|---|---|
| R1 | **Kurulum testi için açılan tünel finans ve personel verisini internete açar.** Development'ta oturum kuralı yok (`Program.cs:32-37`); kullanıcı tablosu boşken `/setup` açık; çerez `SameAsRequest`, `UseForwardedHeaders` yok; 05.10 denemesinde Production `dotnet run` statik dosya vermedi, bu da "Development + tünel"i en kolay yol yapıyor | **Varoluşsal** | Orta | Yüksek | K6 tünel kuralı: önce tünelsiz LAN 5443 + `/ca.crt`; tünel yalnız publish + Production + `UseForwardedHeaders` + kullanıcı tablosu dolu + Cloudflare Access, süreli, açılıştan önce oturumsuz `GET /` → 302 `/login` duman testi; Development hiçbir tünele bağlanmaz. `UseForwardedHeaders` 004'te → 002 kurulum testi LAN'da | Tüneli kapat; parolayı değiştir; Data Protection anahtarını yenile (12 saatlik çerezler düşer); Cloudflare günlüğünden erişimi çıkar; KVKK değerlendirmesi | Önlendi (kural) |
| R2 | Kapı sözleşmesinde `gosterge:operasyon-splh` yanlış maddeye (`001:cari-risk`) bağlanmıştı; Cari/Risk kapanınca düzeltilmemiş SPLH telefonda açılırdı | Stratejik | Orta | Yüksek | `kontratlar/telefon-kapisi.md` düzeltildi (`ek:splh`); `Bagimlilik_GostergeAnahtarlari_BeklenenMadde` testi bozuk satırla kırmızı vermeli (kabul ölçütü) | Anahtar kümeden çıkarılır, GMY'ye yazılı bildirilir | Önlendi |
| R3 | Kapıyı açacak `kabul-sonucu.md`'yi yazan iş yok; elle yazılırsa kanıtsız "tuttu" geçer | Stratejik | Yüksek | Orta | § 001'e eklenecek görevler (G-2); kapı testi `Kanıt` hücresinin boş olmamasını ve var olan commit/dosyayı ister | Kapı maddeleri GMY onayıyla elle açılır, onay `ork not karar` ile journal'a | Önlendi (001'e görev eklenmesi bekleniyor) |
| R4 | Dalga 1 001'e bağlı yayınlansaydı ilk telefon sürümü 001 bitene kadar gelmezdi; GMY masaüstüne dönerdi | Stratejik | Yüksek | Orta | **K10: Dalga 1 001'i beklemeden yayınlanır** (master'dan dal, ON-1, dar istisnalar); SC-008 açılış günlüğü yayından 2 hafta sonra okunur | İlk sürüm değer vermezse kapısı en erken açılacak madde (ör. `001:H12` Mizan) öne çekilir | Karara bağlandı (08.10.2026); kalan risk: dar istisna dosyalarında 001 merge çakışması (izleme) |
| R5 | Ölçüm Development'a yapılıyor, yayın Production'a gidiyor (statik dosya, oturum, `no-store`, HSTS, hata sayfası farklı); Playwright hazır sinyali, `@onclick`'li `div`, Chrome sürüm uyumu | Operasyonel | Orta | Orta | Dalga 1 bitiş ölçütüne: `dotnet publish` çıktısı Production ortamıyla localhost'ta başlatılır, kabuk testleri ona karşı da koşar (`kontratlar/olcum.md` § 1) | Chrome uyumsuzsa paketli Chromium; Production farkı çıkan test Production örneğine taşınır | İzleniyor |
| R6 | Kaybolan/paylaşılan telefon: 12 saatlik çerez tek tek iptal edilemez; vardiya adları DOM'da kalıyordu | Stratejik | Düşük | Yüksek | Vardiya isimli satırlar telefonda sunucuda hiç üretilmez (K2, `kontratlar/ekranlar.md`); FR-009 testi `innerHTML`'e bakar; uzaktan çıkış adımı (Data Protection anahtar yenileme) `docs/yardim/telefona-kurulum.md`'ye; `kvkk-denetcisi` görüşü plan onayından önce | Anahtar yenilenir, parola değişir | Önlendi (KVKK görüşü bekleniyor) |
| R7 | Gizli bölümün sorgusu telefonda koşar; prerender çift sorgu; mobil ağda Bugün yavaş, ERP'ye yük | Operasyonel | Orta | Orta | K2: masaüstü bölümü telefonda çizilmez ve yüklenmez; Dalga 1 sonunda Bugün'ün telefon açılış süresi ve açılış başına SQL çağrı sayısı ölçülüp rapora yazılır | Ağır kartın gecikmeli yüklenmesi | İzleniyor |

### İzleme listesi

- Service worker önbellek adı sabit (`bkm-kabuk-v1`); `app.css` değişince çevrimdışı sayfa eski stille kalabilir; sürüm adı CSS içerik hash'ine bağlanabilir.
- Dar istisnalar (`Home.razor` `@page`, ON-1 satırları) ve `app.css` yeniden üretimi: 001 master'ı aldığında çakışma sayısı izlenir (G-3).
- `Bagimlilik_SpecTablosuylaAyni` 001 T-023'ün depo dosyası okuyucusuna bağlı; T-023 gecikirse test yazılamaz.
- Lucide `unpkg.com/lucide@latest` sürüm sabitlenmeden yükleniyor.
- iOS farkları (klavye, maskable yok, yalnız Safari'den kurulum, CA "tam güven"); elle kabul adımı planlı.
- Tek onaycı (GMY) ve tek makine (SANAL-FIKRI): 2 haftalık yokluk yayını durdurur.
- Hesap taşıma (Razor → `Data/`) ile düzen değişikliği aynı commit'e girmez; taşıma öncesi/sonrası değer eşitliği testi görev metnine yazılır (FR-012).
- 001, 002, 003, 004 aynı dönemde açık: `session-memory.md` "3+ paralel özellik" eşiği aşılmış.
- R5 ve R7 ölçümleri (Production turu, açılış süresi, SQL çağrı sayısı) Dalga 1 raporunda.

Karar: **ŞART karşılandı, ilerle** — R1, R2, R6 önleyicileri plana ve kontratlara işlendi; R3 001'e görev eklenmesini, R4 K10 ile karara bağlandı. Gözden geçirme: Dalga 1 bitişinde ya da ilk tünel açılışından önce, en geç 22.10.2026.

## Karmaşıklık takibi (anayasa istisnaları)

| İstisna | Gerekçe | Daha basit alternatif neden reddedildi | Onay |
|---|---|---|---|
| Yeni test bağımlılığı `Microsoft.Playwright` (Madde 5, PKG-005) | AC-0.5–0.8, SC-001/002 ölçülebilir kapı istiyor; düzen ancak gerçek tarayıcıda ölçülür | Elle önizleme tekrarlanmaz; bUnit düzen hesaplamaz; CDP betiği elle yazılmış otomasyon | GMY onayı 08.10.2026 · ADR-007 (Önerildi) |
| Telefonda salt-okuma ve masaüstü içeriği görünüm bildirimine (`matchMedia`) bağlı; sunucuda çizilmez | Tek kullanıcı, cihaz ayrımı yetki sınırı değil (K2) | Sunucu tarafı cihaz tespiti: kullanıcı aracısına güvenmek kırılgan, ön çizimde görünüm bilinmez | Bilgi |
| 500+ satırlık C ekranları bölünmez | K8 | Hepsini bölmek: kapsam ve 001 çakışması büyür | Gerekli (TODO maddesi) |
| `theme-color` ve manifest renkleri onaltılık değer | Manifest ve meta etiketi CSS değişkeni okuyamaz | DaisyUI token burada uygulanamaz (`renk-standardi.md` istisnası) | Bilgi |

## ADR adayları

- **A1 — Telefon kapısı:** 001 bağımlılığı kod sabitiyle, git'teki kabul sonucuna testle bağlı açılır; çalışma anı ayarı yok. Neden kalıcı: 003 kartları (nakit) aynı kapıyı kullanacak. **ADR gerekli: evet**
- **A2 — Yaklaşım C ve tek kırılma noktası:** tek kaynak ekran, tek kırılma noktası `lg`, düzen CSS ile, içerik sunucuda `matchMedia` görünüm bildirimiyle (K2); ayrı native uygulama ve `/m` rotaları reddedildi. 02–03.10'da karar verildi ama `docs/ADR/`'de yok. **ADR gerekli: evet**
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

11. **Yeni AC-1.12 (uzaktan kapatma, K12):**
   > **AC-1.12:** Verildiğinde GMY telefonda ve masaüstünde oturum açmış, Yapıldığında masaüstünde Ayarlar'daki **Bütün oturumları kapat** düğmesine basıp onayladığında, O zaman telefondaki açık uygulama en geç 1 dakika içinde giriş sayfasına döner ve hiçbir rakam görünmez; masaüstündeki oturum da kapanır ve giriş sayfası açılır.
12. **Yeni AC-1.13 (boşta süre):**
   > **AC-1.13:** Verildiğinde oturumdaki son etkileşimin üzerinden 12 saat geçmiş, Yapıldığında uygulama açıldığında ya da açık ekranda bir öğeye dokunulduğunda, O zaman giriş sayfası açılır ve hiçbir rakam görünmez.
13. **Yeni AC-1.14 (mutlak süre):**
   > **AC-1.14:** Verildiğinde oturum açılışının üzerinden 7 gün geçmiş, Yapıldığında uygulama kullanılırken ya da açıldığında, O zaman etkileşim sürmüş olsa da giriş sayfası açılır.
14. **Yeni AC-1.15 (oturum listesi):**
   > **AC-1.15:** Verildiğinde masaüstünde Ayarlar ekranı, Yapıldığında **Oturumlar** bölümü açıldığında, O zaman açık her oturum cihaz özeti ve son görülme zamanıyla (gg.aa.yyyy ss:dd) listelenir; IP adresi gösterilmez. Telefonda bölüm salt okunurdur, kapatma düğmesi görünmez.
15. **Yeni AC-1.16 (çıkış):**
   > **AC-1.16:** Verildiğinde açık bir oturum, Yapıldığında **Çıkış yap** seçildiğinde, O zaman yalnız o cihazın oturumu kapanır; öteki cihazlardaki oturumlar açık kalır.
16. **Yeni FR-014, Yetki tablosu ve Kapsam dışı:**
   > **FR-014:** Sistem her oturumu sunucuda kaydetmek, masaüstünden bütün oturumların kapatılmasına izin vermek, oturumu 12 saat etkileşimsizlikten ya da 7 gün sonra kendiliğinden kapatmak ve kapanan oturumda açık ekranı en geç 1 dakikada giriş sayfasına döndürmek ZORUNDADIR (AC-1.12–1.16).

   Yetki tablosu, GMY "Yapabilir" hücresine: "masaüstünden bütün oturumları kapatmak". "Yapamaz" hücresine: "telefondan oturum kapatma düğmesini kullanmak". Kapsam dışı satırı şöyle olur: "Sunucu, servis kurulumu, kalıcı güvenli bağlantı, dışarıdan erişim, dışarıdan erişim koruması, parola sıfırlama → spec 004. (Oturum kaydı, uzaktan kapatma ve oturum süreleri bu spec'tedir; karar 08.10.2026.)"


## 001'e eklenecek görevler (002 yazmaz; 001 sahibi ekler)

**G-1 — Cari/Risk ek maddesi (`001:cari-risk`), GMY kararı 08.10.2026.**
> **Hikâye (öneri):** GMY olarak Cari/Risk ekranında vadesi geçen alacağın ve borcun bütün carilerden hesaplanmış, alıcı ve satıcı için ayrı toplamını görmek istiyorum, böylece ilk 200 kaydın toplamını gerçek toplam sanmam.
> - **AC-a:** Verildiğinde alıcı (120) ve satıcı (320) carileri, Yapıldığında Cari/Risk açıldığında, O zaman "Vadesi geçen alacak" alıcıların tümünden, "Vadesi geçen borç" satıcıların tümünden hesaplanır; liste ilk N kayıtla sınırlı olsa da toplamlar sınırlı değildir. Bağımsız kanonik sorguyla tolerans ≤ 1,00 TL.
> - **AC-b:** Verildiğinde aynı dönem, Yapıldığında iki toplam masaüstünde ve Bugün kart 5'te okunduğunda, O zaman değerler birebir aynıdır (aynı çekirdek metot).
> - **AC-c:** Verildiğinde `frm.frmBakiyeLimit` dolu kayıt sayısı, Yapıldığında ölçüldüğünde, O zaman sayı kanıt başlığına yazılır; 0 ise "Limit aşan cari" göstergesi "Limit tanımlı değil" notunu taşır.
> - Çekirdek: `FinansQueries` içinde toplam sorgusu (TOP'suz) + liste sorgusu ayrı; KPI Razor'dan çekirdeğe taşınır (`CariRisk.razor:40-56` bugün ilk 200 satırdan topluyor). Kanıt: `specs/002-mobil-kabuk-ekran/arastirma.md` § 8 (satıcı ilk 200 −147.310.896,38 · tümü −72.794.717,37 · alıcı 1.229.462.178,38 · limit aşan 0). Ölçüm SQL'i `sorgular/2026-10-08-cari-risk-kapsam.sql`'e arşivlenir.

**G-2 — 001 kabul sonucunun git'e yazılması (risk taraması R3).**
> **Görev (öneri):** `[DOC]` 001 kabul sonucu dosyası. **Bağımlılık:** 001 `/kabul-testi` hükmü. **Dosya:** oluştur `specs/001-panel-veri-duzeltme/kabul-sonucu.md`. **Gereksinim:** her 001 maddesi (H1–H14, H10 için `001:H10.1` ve `001:H10.3` ayrı, D-1–D-5, `001:cari-risk`) için bir satır: `| Madde | Sonuç | Tarih | Kanıt |`; `Sonuç` ∈ {tuttu, saptı, koşamadı, karar bekliyor}; `Kanıt` boş olamaz: kabul hükmünü kaydeden commit'in kısa hash'i ya da depoda var olan bir dosya yolu (git dışı `.orkestra/` yolu tek başına kanıt sayılmaz). Dosyayı denetleyici yazar, GMY onayı satırı dosya başında. **Kabul:** 002 `KapananMaddeler_HepsiKabulSonucundaTuttu` testi bu dosyayla koşar; `Kanıt`'ı boş bir satır testi kırmızıya düşürür.

**G-3 — 001'in master'ı alması ve T-029/T-031 uyarlaması (K10).**
> 002 Dalga 1'in ON-1 commit'i master'a girince 001 dalı master'ı `git merge` ile alır. **T-031:** dosya zaten var; görev "içerik sözleşmeyle birebir aynı mı" doğrulamasına iner (derleme + `turkce_tanimlayici_denetimi.py`). **T-029:** `ServiceRegistration.cs` satırı zaten var; görev yalnız `DuzeltmeNotlari` ve testlerine iner. Dar istisna dosyalarında (`Home.razor` `@page`, `Musteri/Trafik/Sadakat` maske hücreleri) çakışma çıkarsa 001 tarafında çözülür, 002'nin satırları korunur.

## Kapsam dışı, TODO'ya (KVKK raporu, 08.10.2026)

- **K7 — Asistan maske kuralı:** maske kolon adına bakıyor (`AsistanAraclar.cs:202-208`), `Personel`, `Sicil`, `Unvan`, `frmAd` kaçıyor; izin listesine dayalı maskeye geçiş. Mevcut işleme, 002 yaratmıyor. Hukuk sorusu S3.
- **K9 — Vardiya serbest metin notu:** sağlık bilgisi şüphesi için örnekleme ölçümü (yalnız sayı); "Personel / TC" arama etiketinin gerçek arama alanına göre düzeltilmesi.
- Dışa aktarma günlüğü (kullanıcı + ekran + satır sayısı) — 004 ya da ayrı iş (K5'in ikinci yarısı).
- 500+ satırlık C ekranlarının bölünmesi (K8 kararı).
- Lucide `@latest` sürüm sabitleme.

## İnsan onayı gerektirenler

Karara bağlananlar (GMY 08.10.2026): Cari/Risk → 001 ek maddesi + kapı · Playwright onaylandı (ADR-007 Önerildi) · kart 1 kıyas günü ve kart 3 kontrol kümesi (K9) · **R4 → Dalga 1 001'i beklemeden yayınlanır (K10)** · **K4 → Müşteri, Trafik, Sadakat ilk sürümde telefonda kapalı, 001 maddesi kapanınca maskeli açılır (K11; 09.10.2026)** · **KVKK K3 → oturum yönetimi 002 Dalga 1'de, kurulumdan önce (K12; denetleyici kararı, GMY yetkisiyle)**.

1. **KVKK S1 — tünel ve yurt dışı aktarım:** hukuki görüş gelene kadar kişisel veri taşıyan hiçbir sayfa tünelden geçmez (K6). Hukuka S1 ve S2 (VPN alternatifi) sorulacak; 004'ü bloklar.
2. Plan onayı ve § Spec değişikliği gerekli metinlerinin spec'e işlenmesi (madde 11–16 K12 için; K11 için: § 001 bağımlılığı tablosuna "Trafik | H5", "Müşteri | D-1", "Sadakat (Müşteri içinde) | H2, H5" satırları ve § Ekran sınıfları C satırına "Müşteri, Trafik ve Sadakat telefonda yalnız bağlı 001 maddeleri kapanınca, kişisel alanları maskeli açılır; o zamana kadar doğrudan adresle de açılmaz" notu; § Varsayımlar'daki "kapısı kapalı ekran doğrudan adresle bugünkü düzeniyle açılır" cümlesine "(Müşteri, Trafik ve Sadakat hariç)" eki).
3. § 001'e eklenecek görevler G-1, G-2, G-3'ün 001'e eklenmesi.
4. ADR A1, A2, A4 (A3 taslak yazıldı).
5. UI kararları 1 ve 2 için `/ui-panel`.
6. 500+ satırlık C ekranlarının bölünmemesi (K8) ve TODO maddesi.
