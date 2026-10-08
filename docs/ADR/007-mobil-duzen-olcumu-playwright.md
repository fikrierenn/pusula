# ADR-007 — Telefon düzeninin ölçümü için Playwright

## Durum

`Önerildi`

## Tarih

2026-10-08

## Proje

`bkm`

## Bağlam

Spec 002 (telefon kabuğu ve ekranlar) ölçülebilir düzen kuralları istiyor: 375×812 px'te sayfa yana taşmaz (AC-0.5, AC-6.2, SC-001, SC-001a), dokunulabilir öğe en az 44×44 px (AC-0.6, SC-002), yalnız fareyle görülen bilgi kalmaz (AC-0.7), giriş alanı iOS'ta yakınlaştırmaz (AC-0.8), 001'e bağlı ekran telefon menüsünde görünmez (AC-0.1, SC-006). 02.10.2026 denetiminde 40 ekranın yaklaşık yarısı 375 px'te taşıyordu; denetim elle yapılmıştı ve tekrarlanamıyordu.

Bu kurallar ancak gerçek bir tarayıcı motorunda, sayfa veriyle çizildikten sonra ölçülebilir. Dashboard'da test projesi 001 ile açıldı (`tests/GmDashboard.Tests`, xUnit); tarayıcı otomasyonu yok. Makinede (ölçüldü 08.10.2026) Python `playwright`/`selenium` yok, Node v24.19.0 var, Google Chrome ve Edge kurulu.

GMY yeni test bağımlılığını 08.10.2026'da onayladı.

## Karar

- `tests/GmDashboard.Tests` projesine **Microsoft.Playwright** NuGet paketi eklenir (yalnız test projesi; uygulama bağımlılığı değil). Paket CLI ile eklenir, sürüm projenin yerel `Directory.Packages.props` dosyasında tutulur.
- Tarayıcı indirilmez: `BrowserTypeLaunchOptions.Channel = "chrome"` ile kurulu Chrome kullanılır.
- Testler `[Trait("Tur","Mobil")]` taşır ve ayrı süreçte çalışan geliştirme sunucusuna (`PANEL_URL`, varsayılan `http://localhost:5112`) bağlanır; uygulama test sürecinde barındırılmaz.
- Sunucuya ulaşılamazsa ya da sayfa 45 sn içinde hazır olmazsa test **KOŞAMADI** mesajıyla kırmızı döner; atlama yok.
- Ölçüm tanımları `specs/002-mobil-kabuk-ekran/kontratlar/olcum.md`'dedir. Ekran listesi elle yazılmaz, `NavRegistry` ve `TelefonKapisi`'nden türer.
- `Tur=Mobil` hiçbir commit kapısına bağlanmaz (çalışan sunucu ister); dalga sonunda ve kabul testinde koşulur.

## Sebepler

- Düzen (genişlik, öğe boyutu, hesaplanmış yazı boyutu) yalnız tarayıcıda ölçülür; bUnit ve `WebApplicationFactory` HTML üretir ama yerleşim hesaplamaz.
- Playwright telefon görünümü (`IsMobile`, `HasTouch`, `DeviceScaleFactor`), çevrimdışı benzetimi (`SetOfflineAsync`, AC-1.10) ve service worker'ı aynı API ile veriyor; bunları elle yazmak gerekmiyor.
- Testler mevcut xUnit projesinde kalır; yeni proje açılmaz (anayasa Madde 5).
- Ölçüm tekrarlanabilir olur; "taşma düzeldi" iddiası komut çıktısına bağlanır (`olctum-mu-cikardim-mi.md`).

## Alternatifler (Reddedilenler)

### A: Node betiği + Chrome DevTools Protocol (yeni paket yok)

**Reddetme sebebi:** Bağımlılık eklemez ama tarayıcı başlatma, bekleme, görünüm benzetimi ve çevrimdışı benzetimi yaklaşık 150 satır elle yazılmış otomasyon olur; bakımı bize kalır ve test sonuçları xUnit raporuna girmez.

### B: Elle önizleme (geliştirici aracı, telefonda deneme)

**Reddetme sebebi:** Tekrarlanmaz, kapı değildir. Yalnız cihaz gerektiren kabul adımlarında (ana ekrana ekleme, simge, klavye) kullanılır.

### C: Uygulamayı `WebApplicationFactory` + Kestrel ile test sürecinde barındırmak

**Reddetme sebebi:** Uygulama açılışta ERP'ye bağlanıyor (`LokasyonConfig.InitAsync`); `UseKestrel` port ayarının `WithWebHostBuilder` ile yok sayıldığı bildirilmiş. Ayrı süreçteki sunucu daha az hareketli parça taşır.

## Sonuçlar

### Olumlu

- AC-0.1, AC-0.5–0.8, AC-1.4–1.8, AC-1.10–1.11 ve SC-001/002/004/006 otomatik ölçülür.
- Kırılabilirlik kanıtlanabilir: bilerek taşan öğe eklenince test kırmızı verir.

### Olumsuz / Risk

- Markalı Chrome sürümüyle uyum garanti değil; Playwright en iyi kendi Chromium'uyla çalışır. Chrome güncellemesi testi bozarsa `playwright install chromium` ile paketli tarayıcıya geçilir.
- Ölçüm canlı veriye bağlı; veri değişince taşma ortaya çıkabilir ya da kaybolabilir.
- Hazır sinyali erken gelirse sayfa veri yüklenmeden ölçülür ve yanlış yeşil verir. Önlem: üç koşullu hazır sinyali + KOŞAMADI kuralı.

### Bilinmeyen

- Tek tam turun süresi (ilk koşuda ölçülüp `specs/002-mobil-kabuk-ekran` raporuna yazılacak).

## Uygulama

- [ ] `dotnet add tests/GmDashboard.Tests package Microsoft.Playwright` (sürüm yerel `Directory.Packages.props`'ta); `dotnet list package --vulnerable` temiz
- [ ] `tests/GmDashboard.Tests/Mobil/` altyapısı: görünümler, hazır sinyali, KOŞAMADI
- [ ] Kırmızı ilk koşu (bugünkü taşmalar) ve kırılabilirlik kanıtı
- [ ] ADR durumu `Kabul edildi` olarak güncellenir

## İlişkili Dosyalar

- `specs/002-mobil-kabuk-ekran/plan.md` (K7)
- `specs/002-mobil-kabuk-ekran/kontratlar/olcum.md`
- `specs/002-mobil-kabuk-ekran/arastirma.md` § 6
- `tests/GmDashboard.Tests/` (001 T-021), `lib/Bkm.TestAltyapi/`
- `.claude/rules/test-discipline.md`, `.claude/rules/olctum-mu-cikardim-mi.md`

## Referanslar

- [Playwright .NET: Browsers](https://playwright.dev/dotnet/docs/browsers)
- [Playwright .NET: BrowserType](https://playwright.dev/dotnet/docs/api/class-browsertype)
- [source.dot.net: WebApplicationFactory.cs](https://source.dot.net/Microsoft.AspNetCore.Mvc.Testing/WebApplicationFactory.cs.html)
- GMY onayı: 08.10.2026 oturumu (denetleyici iletisi)
- Numara: 004 kullanılmaz (kurallarda dosyası olmayan "eski ADR-004" başvurusu var); 005 ve 006 001 T-076'ya ayrılı.
