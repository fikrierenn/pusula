# Araştırma — 002 Telefon kabuğu ve ekranlar

Yalnız bu plan için gerçekten araştırılan ya da ölçülen konular. Tarih: 08.10.2026. Etiketler `olctum-mu-cikardim-mi.md`'ye göredir.

## 1. PWA kurulum şartları — Android (Chrome)

- Chrome, menüden kurulum için **fetch işleyicili service worker şartını** mobilde 108, masaüstünde 112 sürümünden itibaren kaldırdı. Çevrimdışı deneyim için kendi varsayılan sayfasını gösteriyor. Ancak otomatik kurulum önerisini gösteren algoritma hâlâ bir fetch işleyicisi arıyor ([Chrome: Revisiting installability criteria](https://developer.chrome.com/blog/update-install-criteria)).
- Bizim için anlamı: mevcut boş fetch işleyicisi (`wwwroot/service-worker.js`, "network passthrough — cache yok") kurulumu sağlıyordu ama çevrimdışında Chrome'un genel sayfası açılırdı; AC-1.10'daki Türkçe mesaj için gezinme isteğinde `offline.html` dönen işleyici gerekiyor (plan K6).
- Manifest alanları (ad, kısa ad, 192 ve 512 ikon, `start_url`, `display: standalone`) ve güvenli bağlantı şartı yerinde kalıyor; güvenli bağlantı yalnız `localhost`'ta muaf. Telefon denemesi bu yüzden tünel ya da 004'ün kalıcı HTTPS'i ister.
- Maskable ikon: önemli içerik, çapı ikon genişliğinin %80'i olan merkez dairede durmalı (yarıçap %40); `purpose: "maskable"` ayrı ikonda verilir ([web.dev: Maskable icon](https://web.dev/maskable-icon) · [MDN: Define your app icons](https://developer.mozilla.org/en-US/docs/Web/Progressive_web_apps/How_to/Define_app_icons)). Bugünkü manifest aynı `icon-512.png`'yi hem `any` hem `maskable` olarak veriyor (ÖLÇÜLDÜ, `wwwroot/manifest.json`); güvenli alan dolgusu yok → AC-1.3 için ayrı dosya.

## 2. PWA kurulum şartları — iOS (Safari)

- iOS 16.4'ten itibaren manifest `display: standalone` (ya da `fullscreen`) ile sunulan site, Safari'den ana ekrana eklenince ana ekran web uygulaması olur ([WebKit: Web Push for Web Apps on iOS and iPadOS](https://webkit.org/blog/13878/web-push-for-web-apps-on-ios-and-ipados/)). Ekleme yalnız Safari paylaş menüsündeki **Ana Ekrana Ekle** ile yapılır; Chrome'daki gibi kurulum önerisi yok → yardım dokümanında ayrı adımlar gerekir.
- iOS simgesi `apple-touch-icon` bağlantısından gelir; 180×180 (ya da 192) px, **saydam olmayan** zemin önerilir ([webhint: Use Apple touch icon](https://webhint.io/docs/user-guide/hints/hint-apple-touch-icons/) · [Apple: Configuring Web Applications](https://developer.apple.com/library/safari/documentation/AppleApplications/Reference/SafariWebContent/ConfiguringWebApplications/ConfiguringWebApplications.html)). Bugün `apple-touch-icon` 192 px'lik `icon-192.png`'ye bağlı (ÖLÇÜLDÜ, `App.razor`); zeminin saydam olup olmadığı plan aşamasında açılıp bakılmadı ([?] doğrulanmadı).
- iOS maskable ikonu kullanmaz; köşeleri kendisi yuvarlar. AC-1.3'ün iOS karşılığı "saydam olmayan, kenara taşmayan 180 px simge"dir.

## 3. Klavye ve görünüm alanı (AC-2.5)

- `<meta name="viewport" content="…, interactive-widget=resizes-content">` klavye açılınca hem görsel hem düzen görünüm alanını küçültür; yalnız Chrome 108+ destekliyor. iOS WebKit bu özelliği uygulamıyor; iOS klavyede yalnız görsel görünüm alanını küçültüyor ([MDN: viewport meta](https://developer.mozilla.org/en-US/docs/Web/HTML/Guides/Viewport_meta_element) · [WebKit Bugzilla 259770](https://bugs.webkit.org/show_bug.cgi?id=259770) · [Chromium intent to ship](https://groups.google.com/a/chromium.org/g/blink-dev/c/ge7xTu-VhJ0/m/hq_kcusHAQAJ)).
- Sonuç (plan K3, UI kararı 7): Android'de meta etiketi yeterli; iOS'ta en basit yol giriş çubuğunu akış içinde tutmak ve odakta alt menüyü gizlemek. Yetmezse `visualViewport` olayıyla küçük bir düzeltme (risk R6 kontenjanı). Doğrulama cihazda elle.

## 4. iOS giriş yakınlaşması (AC-0.8)

- iOS Safari, odaklanan `input/select/textarea`'nın hesaplanmış yazı boyutu 16 px'ten küçükse sayfayı yakınlaştırıyor ve geri uzaklaştırmıyor. Çözüm 16 px (ya da `max(16px, 1em)`); `maximum-scale=1`/`user-scalable=no` erişilebilirliği bozar, kullanılmaz ([Rick Strahl: Preventing iOS textbox auto zooming](https://weblog.west-wind.com/posts/2023/Apr/17/Preventing-iOS-Textbox-Auto-Zooming-and-ViewPort-Sizing) · [specification.website: mobile form inputs](https://specification.website/spec/accessibility/mobile-form-inputs/)).
- Panelde `input-sm`/`select-sm` (~14 px) yaygın (ÖLÇÜLDÜ: `Gorevler.razor` 11, `Asistan.razor` 20 adet `btn/input/select-sm|xs` geçişi) → telefonda 16 px kuralı ortak stilde.

## 5. 44 px dokunma hedefi (AC-0.6)

- WCAG 2.5.5 (AAA): hedef en az 44×44 CSS px; istisnalar eşdeğer büyük hedef, **metin içi bağlantı**, tarayıcının belirlediği boyut, zorunlu sunum ([W3C: Understanding Target Size (Enhanced)](https://w3.org/WAI/WCAG22/Understanding/target-size-enhanced.html)). Ölçümde yalnız metin içi bağlantı istisnası kullanılır (`kontratlar/olcum.md`).
- Blazor `@onclick` DOM'a öznitelik yazmaz; tıklanabilir `div` ölçümde görünmez. `AppDataTable` satırı bugün böyle (ÖLÇÜLDÜ, `AppDataTable.razor:14-16`) → `role="button"` + kaynak taraması testi.

## 6. Ölçüm aracı (plan K7)

- Playwright .NET, kurulu Google Chrome ya da Edge'i `Channel = "chrome"`/`"msedge"` ile sürebiliyor; Playwright bunları kendisi indirmiyor. Uyarı: en iyi kendi paketlediği Chromium sürümüyle çalışıyor, markalı sürümle uyum garanti değil ([Playwright .NET: Browsers](https://playwright.dev/dotnet/docs/browsers) · [BrowserType API](https://playwright.dev/dotnet/docs/api/class-browsertype)).
- Makinede durum (ÖLÇÜLDÜ, 08.10.2026): Python `playwright`/`selenium` yok; Node v24.19.0 var; Chrome (`C:\Program Files\Google\Chrome`) ve Edge kurulu; `ms-playwright` tarayıcı önbelleği yok.
- `WebApplicationFactory` varsayılan olarak bellek içi `TestServer` kullanır; tarayıcı testi için gerçek Kestrel gerekir. .NET 10 kaynağında `UseKestrel` desteği var ([source.dot.net: WebApplicationFactory.cs](https://source.dot.net/Microsoft.AspNetCore.Mvc.Testing/WebApplicationFactory.cs.html)), ancak `WithWebHostBuilder` ile port parametresinin yok sayıldığı bildirilmiş ([blog.pluggy.ai](https://blog.pluggy.ai/blog/ports-fall-silent-in-asp)). Panel açılışta ERP'ye bağlanıyor (`LokasyonConfig.InitAsync`, `Program.cs:53-55`). **Karar:** Playwright testleri ayrı süreçte çalışan geliştirme sunucusuna (`PANEL_URL`) bağlanır; uygulama test sürecinde barındırılmaz.

## 7. Kod tabanı ölçümleri (plan kararlarına girdi)

| Bulgu | Kanıt | Plan |
|---|---|---|
| Sabah ekranı kural tabanlı kontrol koşmuyor; `SabahService` dün cirosu, stokta yokluk ve Pazartesi haftalık verisini çekiyor, ekran bunu LLM'e brifing yazdırıyor | `Data/SabahService.cs:42-150`, `Sabah.razor` `YukleAsync` | R2, İnsan onayı 2 |
| Kural tabanlı uyarılar Ana sayfada: mağaza cirosu ≤ −%10 (hata), iade oranı > %2 (uyarı), hedef ≥ %105 ve en güçlü artış (başarı) | `Home.razor:398-422` (`BuildAlerts`) | Kart 3 önerisi |
| Okul hizalı otomatik kıyas günü yok: Mağazalar varsayılanı −364 gün, okul hizalı kıyas elle seçiliyor; okul açılış tarihleri tek yerde | `Magazalar.razor:183-217`, `Models/SezonAksiyonModels.cs:178-185` (2023–2026), `sorgular/2026-09-08-okul-hizali-ciro-tahmini.sql` | R2, İnsan onayı 3 |
| Cari/Risk göstergeleri Razor'da, yüklenen ilk 200 satırdan toplanıyor; varsayılan sekme Satıcılar (320) | `CariRisk.razor:40-56, 92, 114-120`; `FinansQueries.cs:14-41` | R1 |
| Görev gecikme kuralı Razor'da; silme onaysız | `Gorevler.razor:54, 135, 138` | K3, AC-2.4 |
| Gelir tablosu faaliyet kârı Razor'da hesaplanıyor; varsayılan ay içinde bulunulan ay | `GelirTablosu.razor:130, 180-215` | Çekirdeğe taşıma, AC-3.2 |
| Ekrana istisna metni yazan 002 ekranları | `CariRisk.razor:120`, `Muhasebe.razor:40, 171` | AC-0.10 |
| Uyum (4857) sayaçları şirket geneli; şube parametresi yok | `lib/Bkm.Shared/Data/VardiyaQueries.cs:209` | Kart 8, Dalga 2 |
| Alt menü bugün Genel · Operasyon · E-ticaret · Müşteri · Envanter + Diğer (çekmece) | `Models/NavRegistry.cs` `InBottomNav`, `MainLayout.razor` | K3 |
| Parametre isteyen C ekranları | `Yevmiye.razor:132` (`fis`), `Fatura.razor:139` (`fat`), `/satis-analizi/urun/{StkId:int}` | K3, "Masaüstünde daha iyi" listesi |
| 500+ satırlık `.razor` dosyaları (12) | `wc -l`: SatisAnaliziUrun 1.212 · SatisAnalizi 1.200 · SatinalmaAnaliz 734 · HomeV2 653 · SezonAksiyon 644 · Home 607 · HediyeCeki 586 · Tahmin 564 · Musteri 564 · Envanter 553 · Operasyon 522 · OdakStok 514 | K8 |

## 8. Cari/Risk göstergesinin kapsamı (ÖLÇÜLDÜ)

Soru: Cari/Risk ekranının açılışta gösterdiği "Vadesi Geçen (toplam)" ve "Limit Aşan Cari" değerleri spec'teki "vadesi geçen alacak" ile aynı şey mi?

```sql
-- DerinSISBkm, sqlcli --profile erp --read-only, 08.10.2026
WITH b AS (
    SELECT fr.frmKod,
           CAST(b.bakiye AS decimal(18,2)) AS Bakiye,
           CAST(b.GecenB AS decimal(18,2)) AS Gecen,
           CAST(ISNULL(fr.frmBakiyeLimit, 0) AS decimal(18,2)) AS Limit,
           ROW_NUMBER() OVER (PARTITION BY LEFT(fr.frmKod, 3) ORDER BY ABS(b.bakiye) DESC) AS Sira
    FROM DerinSISBkm.dbo.bakiyeVDGG_vw b
    JOIN DerinSISBkm.dbo.frm fr ON fr.frmID = b.cKod
    WHERE ABS(b.bakiye) > 0 AND (fr.frmKod LIKE '320%' OR fr.frmKod LIKE '120%'))
SELECT LEFT(frmKod, 3) AS Grup, COUNT(*) AS Kayit,
       SUM(Gecen) AS GecenTum,
       SUM(CASE WHEN Sira <= 200 THEN Gecen ELSE 0 END) AS GecenIlk200,
       SUM(CASE WHEN Limit > 0 AND ABS(Bakiye) > Limit THEN 1 ELSE 0 END) AS LimitAsanTum,
       SUM(CASE WHEN Sira <= 200 AND Limit > 0 AND ABS(Bakiye) > Limit THEN 1 ELSE 0 END) AS LimitAsanIlk200
FROM b GROUP BY LEFT(frmKod, 3);
```

| Grup | Kayıt | Vadesi geçen (tümü) | Vadesi geçen (ilk 200, ekran) | Limit aşan |
|---|--:|--:|--:|--:|
| 120 Alıcılar | 284 | 1.229.462.178,38 | 1.229.471.096,77 | 0 |
| 320 Satıcılar (ekran varsayılanı) | 300 | −72.794.717,37 | **−147.310.896,38** | 0 |

- Ekran açılışta satıcı (borç) tarafını ve yalnız ilk 200 kaydı topluyor; satıcı tarafında bu, tümünün iki katı bir değer veriyor. "Alacak" alıcı tarafıdır.
- Limit aşan cari iki grupta da 0: `frmBakiyeLimit` tanımlı değil gibi görünüyor ([?] doğrulanmadı: limit kolonunun dolu olduğu kayıt sayısı ölçülmedi).
- Alıcı tarafındaki 1,23 milyar TL'nin içeriği (grup içi cariler olabilir) yorumlanmadı — ÇIKARIM yapılmadı, yalnız ölçüm.
- Başka ne olabilir: ekranın amacı bilerek "satıcılara vadesi geçen borç" olabilir; o zaman yanlış olan spec metnidir, ekran değil. Bu yüzden plan bunu karar olarak GMY'ye götürüyor (R1).
- Arşiv: bu sorgu uygulama görevinde `sorgular/2026-10-08-cari-risk-kapsam.sql`'e alınır (`semantic-layer.md` § ikiz yükümlülük); mimar rolü `sorgular/`'a yazmaz.
