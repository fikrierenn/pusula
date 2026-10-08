# Ölçüm sözleşmesi — 375 px, 44 px, ipucu, 16 px, kapı

Spec: AC-0.1, 0.5–0.8, 6.2, SC-001, SC-001a, SC-002, SC-006 · Plan: K7
Araç: Microsoft.Playwright (.NET), `Channel = "chrome"` (kurulu Chrome; tarayıcı indirilmez). GMY onayı 08.10.2026; `docs/ADR/007-mobil-duzen-olcumu-playwright.md`. Canlı veri okuması gereken testler 001 T-021 altyapısını kullanır (`LiveDb`, `ReadOnlyGate`).

## 1. Koşu

- Test projesi: `tests/GmDashboard.Tests`, klasör `Mobil/`, `[Trait("Tur","Mobil")]`.
- Hedef: çalışan geliştirme sunucusu `PANEL_URL` (varsayılan `http://localhost:5112`, Development → oturum gerekmez). `localhost` güvenli bağlamdır; service worker ölçülebilir.
- Komut: `dotnet run --project dashboard --launch-profile http` (ayrı süreç) → `dotnet test tests/GmDashboard.Tests --filter Tur=Mobil`.
- Sunucuya ulaşılamazsa test **KOŞAMADI** mesajıyla kırmızı döner (atlama yok).
- Veriler canlıdır (ERP salt-okuma). Mesai içinde koşabilir; tek tur ~40 sayfa açılışı, kanonik testler kadar ağır değildir (ÇIKARIM, ilk koşuda süre ölçülüp rapora yazılır).
- Commit kapısına bağlanmaz (sunucu ister); dalga sonunda ve kabul testinde koşulur.

## 2. Görünümler

| Ad | Ayar |
|---|---|
| Telefon | `ViewportSize 375×812`, `DeviceScaleFactor 3`, `IsMobile true`, `HasTouch true` |
| Masaüstü | `ViewportSize 1280×800` |

## 3. Ekran listesi (elle yazılmaz)

`NavRegistry.Items` + parametreli adresler:
- `/magaza/{id}` → `LokasyonConfig` mağazaları (üçü),
- `/satis-analizi/urun/{id}` → `MOBIL_ORNEK_STKID` ortam değişkeni; yoksa o satır KOŞAMADI,
- `/yevmiye-fis?fis=…`, `/fatura?fat=…` → `MOBIL_ORNEK_FIS`, `MOBIL_ORNEK_FAT`; yoksa KOŞAMADI.

| Sınıf | Kapı | Kural kipi |
|---|---|---|
| A/B | açık | Taşma + 44 px + ipucu + 16 px → ihlal **kırmızı** |
| A/B | kapalı | Aynı ölçüm **rapor** (test çıktısına yazılır, kırmızı değil) |
| C | — | Yalnız taşma → ihlal **kırmızı** |

## 4. Hazır sinyali

Sayfa açılır; şu üçü birlikte sağlanınca ölçülür: (1) `h1` görünür, (2) görünür `.loading` öğesi yok, (3) 750 ms boyunca DOM değişmedi (`MutationObserver`). Ardından sayfa sonuna kadar adım adım kaydırılır, (1)–(3) yeniden beklenir. 45 sn içinde hazır olmazsa **KOŞAMADI = kırmızı**.

## 5. Ölçümler

| Kural | Ölçüm (tarayıcıda) | Eşik | AC |
|---|---|---|---|
| Yatay taşma | `document.documentElement.scrollWidth` ve `document.body.scrollWidth` | ≤ 375 | AC-0.5, 6.2, SC-001, SC-001a |
| Dokunma hedefi | Seçici: `a[href], button, [role=button], [role=tab], [role=link], input:not([type=hidden]), select, textarea, summary, label[for]`. Görünür olanlar (`getBoundingClientRect` en ve boy > 0, `visibility != hidden`, kapalı `details` içinde değil). İstisna: yalnız `display: inline` ve metin bloğu (`p`, `li` metni) içindeki bağlantı (WCAG 2.5.5 satır içi) | en ≥ 44 ve boy ≥ 44 | AC-0.6, SC-002 |
| Yalnız fareyle görülen bilgi | Görünür her `[title]` öğesinin `title` metni `document.body.innerText` içinde geçer | ihlal 0 | AC-0.7 |
| Giriş yakınlaşması | Görünür `input, select, textarea` için `getComputedStyle(el).fontSize` | ≥ 16 px | AC-0.8 |
| Alt menü örtmesi | Sayfa sonundayken `main` son çocuğunun alt kenarı ≤ `.btm-nav` üst kenarı | — | AC-1.5 |
| Kapı | Satış/Finans/Diğer panelleri açılır; panelde görünen bağlantılar = `NavRegistry` öğeleri ∩ `TelefonKapisi.Acik` (test aynı kodu çağırarak beklenen kümeyi kurar) | fark 0 | AC-0.1, 0.2, SC-006 |

İhlal raporu: ekran, kural, öğe (etiket adı + ilk 40 karakter metin + boyut). Kişisel veri yazılmaz.

## 6. Kırılabilirlik (test-discipline)

Her kural için bir kez: bir ekrana bilerek 400 px genişliğinde öğe, 24 px'lik düğme, görünür metinde olmayan `title`, 12 px'lik `input` eklenir → ilgili test kırmızı görülür → değişiklik elle geri alınır (`git reset --hard`/`checkout -- .` yok) → takım yeniden koşulur. Kapı için `KapananMaddeler`'e geçici anahtar eklenir, panel testinin beklenen kümeyle değiştiği görülür.

## 7. Elle (cihazda) kalanlar

Playwright bunları ölçemez; kabul testinde Android (Chrome) ve iOS (Safari) cihazda yapılır, ekran görüntüsüyle kaydedilir:
- Ana ekrana ekleme, simge ve adres çubuksuz tam ekran açılış (AC-1.1, 1.2, SC-003),
- Simgenin yuvarlak maskede kırpılmaması (AC-1.3; maskable dosya ayrıca maskable.app'te önizlenir),
- Klavye açıkken giriş çubuğu ve gönder düğmesinin görünür kalması (AC-2.5),
- Yatay çevirmede okunurluk (sınır durum; kabul ölçütü değil).
