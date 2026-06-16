# Plan 13 — Genel Bakış Redesign (Home + Toplam + Mağazalar + Tahmin)

**Tarih:** 2026-06-16 · **Proje:** `bkm` · **Durum:** Taslak

## 1. Problem
Home ve alt sayfalar (`/toplam`, `/magazalar`, `/tahmin`) kısmen hazır ama tamamlanmamış: Hero KPI kartlarında tıklama-nav yok; Home'da Tahmin sadece gradient link (projeksiyon ₺ + güven aralığı görünmüyor); `/toplam`da mağaza/online filtre sekmesi yok; `/magazalar` yan-yana bar chart içermiyor. Amaç: mevcut sorguları yeniden kullanarak (yeni SQL minimum), modalsız, tümü `<a href>` SSR-güvenli (B-48) bu 4 sayfayı tamamlamak.

## 2. Scope
**Dahil:** Home Hero KPI nav + Tahmin özet kartı (₺ + band); /tahmin grafik güven bandı; /toplam üst KPI satırı + mağaza/online filtre sekmesi (client-side `StoreCard.Kategori`); /magazalar yan-yana karşılaştırma bar.

**Hariç:** Modal (yok kararı); AI Günün Özeti / Store Row / E-ticaret özet (DOKUNMA — zaten `<a href>`); /tahmin hesap adımları (ZATEN var, satır 52-93); yeni sayfa; **kategori bazlı tahmin tablosu** (yeni SQL ister → AÇIK SORU 2); online kategori kırılımı (veri yok).

**Etkilenen dosyalar:**
- `dashboard/Components/Pages/Home.razor` (536 satır — KIRMIZI ÇİZGİ, net +25 tavanı)
- `dashboard/Components/Pages/Toplam.razor` (~192) — +KPI + filtre (~+45)
- `dashboard/Components/Pages/Magazalar.razor` (~142) — +bar (~+15-30)
- `dashboard/Components/Pages/Tahmin.razor` (184) — +band (~+20)

**Tahmini boyut:** 4 dosya / ~120 satır net.

## 3. Alternatifler Reddedilen
**A — Modal/drawer:** Reddedildi (modal yok kararı + B-48: modal SignalR-bağımlı, mobilde SSR-güvenli değil).
**B — Home Tahmin için yeni sorgu:** Reddedildi (`GetTahminAsync(bugun,0)` zaten tüm-mağaza Tahmin/Alt/Ust veriyor → duplikasyon, tek-kaynak ihlali).
**C (seçilen) — Mevcut sorguları yeniden kullan, sadece sunum/nav:** Sıfır yeni SQL = sıfır yeni sessiz-yanlış-rakam yüzeyi. Footprint-ladder basamak 1.

## 4. Riskler
| Risk | Etki | Olasılık | Mitigation |
|---|---|---|---|
| Home Tahmin özeti yanlış (band ters / ivme işareti) | yüksek | orta | Home ₺ = /tahmin büyük kart ₺ **birebir** (aynı metot). Farklıysa dur. |
| Home.razor (536) kırmızı çizgi şişer | orta | orta | Sadece HeroCard `href` param + Tahmin RenderFragment; +25 tavan. Aşarsa component'e çıkar. |
| /toplam online sekmesi sessiz boş liste | yüksek | orta | `StoreCard.Kategori` online HARİÇ → online'da kategori-kırılım-yok **notu** (sessiz boş YASAK). |
| ApexCharts grouped/range Blazor wrapper yok | orta | orta | Önce `AppRankBars` (DaisyUI, JS'siz) ile fallback; ApexChart ancak gerekirse. |
| Hero nav hedefi belirsiz (İşlem/İade nereye?) | düşük | orta | AÇIK SORU 1 — onaysız nav verme. |

## 5. Done Criteria
- [ ] Home Hero 4 KPI `<a href>` ile sayfaya gidiyor (SignalR kapalıyken de)
- [ ] Home Tahmin özet kartı: projeksiyon ₺ + band; **değer /tahmin ile birebir** (mutabakat yapıldı)
- [ ] /toplam üst KPI satırı + mağaza sekmesi kategori mix değiştiriyor; online sekmesinde kırılım-yok notu
- [ ] /magazalar yan-yana karşılaştırma bar + kartlarda WoW/Hedef%/İade%
- [ ] /tahmin grafikte güven bandı (Alt–Ust); Alt≤Tahmin≤Ust
- [ ] `dotnet build` yeşil + 4 sayfa smoke (gerçek veri)
- [ ] silent-failure-hunter taraması 4 sayfada temiz
- [ ] Yeni kodda `yyyy-MM-dd` literal yok

## 6. Rollback
Her adım ayrı commit (`feat(bkm): ... (plan: 13)`) → `git revert`. Yeni SQL/migration YOK. 4 sayfa bağımsız → tek commit revert diğerlerini etkilemez.

## 7. Adımlar

### Adım 1 — Home Hero KPI nav (`Home.razor` 50-55)
`HeroCard` imzasına `string? href`; carousel-item div → `<a href>` (StoreRow:517 deseni). 4 href ekle (AÇIK SORU 1'e tabi). LOC +8.
**Doğrulama:** SignalR kapalıyken link çalışır; route NavRegistry'de kayıtlı (404 yok).

### Adım 2 — Home Tahmin özet (`Home.razor` 128-136 + LoadAsync)
`_tahmin` alanı; `GetTahminAsync(bugun,0)` WhenAll'a ekleme — fire-and-forget (Home'u bekletme), yüklenince StateHasChanged. Kartta `_tahmin.Yeterli` ise "Bu ay ~₺ · band Alt–Ust". LOC +15.
**Doğrulama (KRİTİK):** Home ₺ = /tahmin büyük kart ₺ birebir.

### Adım 3 — /toplam filtre + KPI (`Toplam.razor`)
Üst KPI satırı (`Fiziksel`/`Eticaret`/`Fis` — mevcut alanlar); DaisyUI `tabs` Hepsi/FSM/Özlüce/İst.Yolu/Online, state `_selMekan`; birleşik seçili mekan filtreli (client-side `StoreCard.Kategori`); online→kategori-yok notu. LOC +45.
**Doğrulama:** 3 mağaza sekme kategori-toplamı ≈ "Hepsi"; sekme-net = `_data.Fiziksel`.

### Adım 4 — /magazalar karşılaştırma bar (`Magazalar.razor`)
Önce `AppRankBars` (JS'siz, 3 mağaza net) — SSR-güvenli; ApexChart grouped sadece AÇIK SORU 3 yanıtına göre. LOC +15/+30.
**Doğrulama:** Bar değerleri kart `@Tl(s.Net)` ile aynı; en uzun bar = crown lider.

### Adım 5 — /tahmin güven bandı (`Tahmin.razor`)
Mevcut AppAreaChart çok-seri alıyor mu kontrol; almıyorsa band grafik altında Alt–Tahmin–Ust metin/mini-bar (AÇIK SORU 4'e tabi). LOC +20.
**Doğrulama:** Alt≤Tahmin≤Ust; değer büyük kartla aynı.

### Adım 6 — Doğrulama + denetim (ZORUNLU, en sonda)
silent-failure-hunter (opus, read-only) 4 sayfada; mutabakat: Home toplam = Mağazalar net toplam + online, /toplam "Hepsi" ≈ Fiziksel, Home Tahmin ₺ = /tahmin ₺; dotnet build + smoke; davranış-kontratı (kategori≥1 VE parça=bütün VE Alt≤Tahmin≤Ust).

## 8. Sıra + Bağımlılık
`1+2` aynı dosya → tek commit (+25 tavan izle) → `3, 4, 5` bağımsız paralel (ayrı commit) → `6` hepsinden SONRA. Adım 6 onaylanmadan "tamamlandı" sayılmaz.

## 9. AÇIK SORULAR (impl öncesi yanıt gerekli)
1. **Hero KPI nav hedefleri:** Toplam Ciro → /toplam, öneri diğerleri → /magazalar. İade tıklanamaz mı kalsın?
2. **Kategori bazlı tahmin tablosu:** `TahminSonuc` per-kategori vermiyor → yeni SQL ister. Bu plana dahil mi?
3. **/magazalar bar:** Tek-seri (bu dönem) yeterli mi, yoksa bu-dönem vs geçen-dönem 2-seri grouped mı?
4. **/tahmin band:** ApexCharts rangeArea için yeni JS'ye değer mi, yoksa Alt–Tahmin–Ust metin/mini-bar yeterli mi?

## 10. İlişkili
B-48, B-73, B-88 · `file-size-discipline.md` (Home 536 kırmızı çizgi) · `renk-standardi.md` · `Queries.cs` (GetTahminAsync:311) · `PeriodModels.cs` (StoreCard.Kategori:22, TahminSonuc:14)
