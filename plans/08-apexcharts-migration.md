# 08 — GM Dashboard Grafik Motoru: Chart.js → Blazor-ApexCharts Geçişi

> Tier 3 · plan-first.md gereği TAM PLAN. Onaysız implement edilmez.
> Hedef: mobil-app-native grafik estetiği (gradient sparkline, rounded bar, SVG touch-tooltip — Revolut/Apple Health hissi).
> Karar verildi: **apexcharts/Blazor-ApexCharts NuGet wrapper** (vanilla CDN+interop DEĞİL).

---

## Faz 1 — Gereksinimler

### Problem
Mevcut grafik motoru `dashboard/wwwroot/js/charts.js` Chart.js@4 (CDN) + `chartjs-plugin-datalabels@2` üzerine kurulu. Estetik kısmen mobil-uyumlu hâle getirilmiş (area gradient + gridsiz, datalabel mobilde kapalı, x-rot 0), ama:
- Canvas-tabanlı → SVG'nin keskinliği/anti-alias kalitesi yok (retina'da bar kenarları yumuşamıyor).
- Native rounded-bar, animasyonlu sparkline, dokunmatik-optimize SVG tooltip yok — elle CSS/JS ile taklit ediliyor.
- Grafik konfigürasyonu imperatif JS interop (`InvokeVoidAsync("bar", ...)`) — tip-güvenli değil, Razor'dan kopuk, derleme zamanı kontrolü yok.

Amaç: ApexCharts'ın native verdiği mobil-app estetiğine (gradient fill, rounded column, smooth area, touch tooltip) geçmek; aynı zamanda imperatif JS interop'u tip-güvenli Razor component'lerine (`<ApexChart>`/`<ApexPointSeries>`) çevirmek.

### Scope — NELER DAHİL
- `dashboard/GmDashboard.csproj` → `Blazor-ApexCharts` NuGet eklenir.
- `dashboard/Components/App.razor` → Chart.js + datalabels CDN script'leri kaldırılır (taşıma bitince); ApexCharts JS asset NuGet wrapper'ı tarafından sağlanır.
- `dashboard/Program.cs` → `AddApexCharts()` DI kaydı + `_Imports.razor`'a `@using ApexCharts`.
- `dashboard/Components/Pages/Home.razor` — 3 grafik.
- `dashboard/Components/Pages/Eticaret.razor` — 6 grafik.
- `dashboard/Components/Pages/Operasyon.razor` — 1 grafik.
- `dashboard/Components/Pages/Envanter.razor` — 1 grafik.
- `dashboard/Styles/app.tailwind.css` — DaisyUI token → ApexCharts renk köprüsü için (gerekirse) yardımcı CSS değişkeni; `app.css` rebuild.
- `dashboard/wwwroot/js/charts.js` — grafik fonksiyonları silinir, **`heroDots` KALIR** (grafik değil, carousel scroll-dot UI helper).

### Scope — NELER DAHİL DEĞİL
- `heroDots` mantığı — grafik değil, dokunulmaz.
- `Magaza.razor` — grafik İÇERMİYOR, kapsam dışı.
- `Asistan`, `Gorevler`, `Musteri`, `Error`, `NotFound` — grafik yok.
- Veri katmanı (`Queries`, `RefQueries`, `EticQueries`, `Models`) — DEĞİŞMEZ. Render motoru değişir, seriler aynı.
- Yeni grafik/metrik EKLENMEZ. Bire-bir görsel eşdeğer + native estetik.
- Lucide ikon / PWA / service-worker — dokunulmaz.

### Grafik envanteri (canlı doğrulanmış — 11 grafik, 4 sayfa)

| Sayfa | canvas id | charts.js fn | Veri | ApexChart hedef tip |
|---|---|---|---|---|
| Home | `ch_kat` | `bar` (horizontal) | Kategori mix (ad/ciro) | bar horizontal, rounded |
| Home | `ch_trend` | `area` | 14g fiziksel net (tarih/net) | area sparkline-gradient |
| Home | `ch_alis` | `area` | 14g net alış (tarih/net) | area sparkline-gradient |
| Eticaret | `ch_etic` | `donut` | Kanal net (ad/ciro) | donut |
| Eticaret | `ch_kargo` | `donut` | Kargo firma (ad/adet) | donut |
| Eticaret | `ch_il` | `bar` (horizontal) | İl top12 (ad/adet) | bar horizontal, rounded |
| Eticaret | `ch_bekleyen` | `bar` (vertical) | Bekleyen bucket (yaş/adet) | bar vertical, rounded |
| Eticaret | `ch_kargogun` | `bar` (vertical) | Çıkış günü (gün/adet) | bar vertical, rounded |
| Eticaret | `ch_aykargo` | `area` | 13 ay iş günü (ay/değer) | area gradient |
| Operasyon | `ch_saat` | `barDual` | Saat: fiş(bar)+net(line) | mixed (column + line, 2 y-eksen) |
| Envanter | `ch_cve` | `scatter` | Kategori: ciro(x)/stok(y) | scatter |

`heroDots` (Home, `hero`/`heroDots`) = grafik DEĞİL → migrasyon dışı, charts.js'te kalır.

### Kabul kriterleri
1. Her 11 grafik ApexChart ile render olur; **görsel değerler Chart.js sürümüyle bire-bir** (aynı dönem seçili iken yan-yana smoke).
2. Donut yüzdeleri Chart.js datalabel formatter'ı ile aynı (≥%4 dilimde % gösterilir). Kanal donut'unda %'ler toplamla %100.
3. `ch_saat` (barDual) iki y-eksenli: sol=fiş (column), sağ=net ₺ (line, ikincil eksen).
4. Renkler DaisyUI `--p` (corporate primary ≈ `#4063e6`) — hardcode hex YOK. Tema değişince grafik primary'si otomatik uyar.
5. Tüm UI metin Türkçe, tooltip `tr-TR` binlik + `M` kısaltması.
6. Mobil (≤420px): tooltip dokunmayla, grafik taşmaz (`h-[220px]`), datalabel gürültü yapmaz.
7. Build yeşil, her sayfa runtime'da hatasız (boş catch'e düşmeden).

### Edge case'ler
- Boş dönem / sıfır seri → ApexChart patlamaz, boş grafik gösterir.
- İade sign/negatif → veri katmanı garantisi, grafik ham gösterir.
- Olgunlaşmamış pencere (`ch_aykargo` son ay kısmi) → olduğu gibi.
- Prerender timing → component yaşam döngüsü (OnAfterRender çizim çağrısı kalkar).
- Tek-elemanlı seri (tek-gün dönem) → marker göster, patlamaz.

---

## Faz 2 — Mimari

### Dokunulacak dosyalar
- `GmDashboard.csproj` — `<PackageReference Include="Blazor-ApexCharts" Version="6.*" />`.
- `Program.cs` — `builder.Services.AddApexCharts();`.
- `Components/_Imports.razor` — `@using ApexCharts`.
- `Components/App.razor` — Chart.js + datalabels CDN `<script>` kaldır (taşıma TAMAMLANINCA).
- `Components/Pages/Home.razor` — 3 canvas → `<ApexChart>`; `DrawChartsAsync` yeniden (heroDots interop kalır).
- `Components/Pages/Eticaret.razor` — 6 canvas → `<ApexChart>`; `DrawAsync` sadeleşir.
- `Components/Pages/Operasyon.razor` — 1 (barDual) → mixed.
- `Components/Pages/Envanter.razor` — 1 (scatter).
- `wwwroot/js/charts.js` — `bar/donut/area/scatter/barDual` silinir; **`heroDots` KALIR**.
- `Styles/app.tailwind.css` — token köprüsü (gerekirse) + rebuild.

### Grafik tipi eşleme

| Chart.js fn | ApexChart | Native özellik |
|---|---|---|
| `bar(horizontal)` | `bar` + `plotOptions.bar.horizontal=true` | `borderRadius`, datalabel fmtK |
| `bar(vertical)` | `bar` horizontal=false | rounded column |
| `donut` | `donut` | dataLabels ≥%4, legend sağ |
| `area` | `area` | `fill.type=gradient` (0.28→0), `stroke.curve=smooth`, gridsiz |
| `scatter` | `scatter` | x=ciro, y=stok, eksen başlıkları |
| `barDual` | `bar` + line (mixed) | 2 yaxis (sol fiş / sağ net, `opposite`) |

### Veri akışı (değişen)
Önce: `LoadAsync` → `_data` → `DrawChartsAsync` → `JS.import` → `InvokeVoidAsync` (imperatif, OnAfterRender, prerender sessiz-catch).
Sonra: `LoadAsync` → `_data` → `StateHasChanged` → `<ApexChart>` deklaratif render; dönem değişiminde `UpdateSeriesAsync`/`@key`. Manuel `destroy()` gerekmez (wrapper yönetir).

---

## Faz 3 — DaisyUI token → ApexCharts renk köprüsü

ApexCharts `colors: string[]` + `theme` bekler; CSS `oklch(...)` string'ini kabul eder. DaisyUI `--p`/`--su`/`--er`/`--in` ham `oklch` bileşeni (`L C H`) → `oklch()` sarmalı gerekir.

**Mekanizma:**
1. **JS köprü** (`wwwroot/js/theme-colors.js`, ~15 satır): `daisyColors()` → `{p, in, su, er, wa}` nesnesi, `getComputedStyle` ile `--p` vb. okur, `oklch(...)` döndürür, fallback `#4063e6`.
2. **Blazor:** `AddApexCharts(o => ...)` global; sayfa `OnAfterRenderAsync(firstRender)`'da bir kez `JS.InvokeAsync` ile çekip `Options.Colors`/`Theme`'e ata, cache'le.
3. **Donut çoklu-palet:** charts.js `PAL` (8 renk) ApexChart `colors`'a sabit taşınır (tema-bağımsız, mevcut davranış — AÇIK SORU 2).

**Gradient (area):** native `fill.type=gradient` + `opacityFrom=0.28, opacityTo=0` (charts.js değerleri birebir).

---

## Faz 4 — Reddedilen Alternatifler

**(a) Chart.js'te kal + stille:** Canvas raster → SVG keskinliği yok; rounded-bar/native-gradient/touch-tooltip elle taklit (146 satır imperatif). Mobil-native his için SVG + hazır animasyon/touch gerekir; orantısız maliyet. Tip-güvensiz interop kalır.

**(b) Vanilla ApexCharts CDN + manuel interop:** charts.js kalıbının tercümesi — yine imperatif, OnAfterRender timing + prerender sessiz-catch, tip-güvensiz. NuGet wrapper tip-güvenli component + yaşam döngüsü + DI verir; deklaratif Razor = derleme kontrolü + az kırılganlık + paylaşılabilir component.

**(Notlanan) Recharts/diğer SVG:** React-bağımlı veya Blazor wrapper olgun değil. ApexCharts resmî Blazor wrapper'ı seçildi.

---

## Faz 5 — Riskler

| Risk | Etki | Azaltma |
|---|---|---|
| **net10 + wrapper uyumu** | csproj net10.0; wrapper v6 resmî net8+. | Adım 1'de erken kanıt; uyumsuzsa plan en başta durur (AÇIK SORU 1). |
| **Prerender + interop timing** | Boş grafik | Component yaşam döngüsü kendini yönetir; manuel OnAfterRender çizim kalkar; renk firstRender'da bir kez, fallback `#4063e6`. |
| **Sessiz yanlış grafik** | Boş `catch{}` hatayı yutar | Done öncesi yan-yana mutabakat (kriter 1-3); boş catch yasak (error-handling.md); silent-failure-hunter taraması. |
| **DaisyUI tema senkronu** | Tema değişiminde uyumsuz | Faz 3 köprü; hardcode hex grep denetimi (fallback `#4063e6` istisna). |
| **Bundle boyutu** | İlk yük artar | Net etki ölç; PWA cache var; Chart.js CDN kalkar (denge). |
| **Mobil touch/tooltip** | Masaüstü-merkezli | Mobil smoke ≤420px; datalabel mobilde kapalı; `h-[220px]` taşmaz. |
| **file-size patlaması** | Home/Eticaret 300 satır aşar | Tekrar eden tanımlar `Components/Shared/` (AppArea/AppBar/AppDonut <150 satır). |

---

## Faz 6 — Adımlar (kademeli, her adım build + mobil smoke, Chart.js paralel canlı)

**Adım 1 — Altyapı + köprü (çizim yok):** NuGet + `AddApexCharts()` + `@using` + theme-colors.js. → Build yeşil (**net10 uyumu KANITLANIR — kapanmazsa plan durur**). Regresyon yok.

**Adım 2 — Pilot: Home `ch_trend` area:** canvas → `<ApexChart>` area gradient/smooth/gridsiz/`--p`. ch_kat/ch_alis/heroDots Chart.js'te kalır (hibrit). → Yan-yana mutabakat (tepe/dip birebir), mobil gradient+touch, boş/tek-gün edge.

**Adım 3 — Home kalan (`ch_alis` area, `ch_kat` bar):** ortak area/bar → `Components/Shared/`. → bar uzunluk+%, alış değerleri birebir; heroDots çalışır.

**Adım 4 — Eticaret (6):** 2 donut (≥%4, legend sağ), ch_il bar-h, ch_bekleyen+ch_kargogun bar-v, ch_aykargo area. `DrawAsync` kalkar. → donut %100, adet birebir, boş dönem patlamaz.

**Adım 5 — Operasyon `ch_saat` mixed:** fiş column (sol) + net ₺ line (sağ `opposite`, `--in`). → iki eksen ayrı, değerler birebir.

**Adım 6 — Envanter `ch_cve` scatter:** x=ciro/y=stok, tooltip kategori, eksen başlıkları. Boş → boş grafik. → koordinatlar birebir.

**Adım 7 — Temizlik:** charts.js `bar/donut/area/scatter/barDual`+`store/draw/KP/PAL/fmt` sil (**heroDots KALIR**); App.razor CDN script sil; `build:css`. → **silent-failure-hunter taraması**; son yan-yana mutabakat; hardcode hex grep; tam mobil smoke 4 sayfa. **Ayrı commit (kolay revert).**

---

## Done criteria
- [ ] Blazor-ApexCharts v6 NuGet + `AddApexCharts()` DI; net10 build yeşil.
- [ ] theme-colors.js `--p`/`--in`/`--su`/`--er` okur; hardcode hex YOK (fallback hariç).
- [ ] 11 grafik render + Chart.js ile yan-yana mutabakat geçti.
- [ ] Donut %100; barDual iki eksen; area native gradient (0.28→0).
- [ ] Türkçe + tr-TR + M kısaltma.
- [ ] Edge: boş/tek-gün/boş seri patlamıyor.
- [ ] heroDots korundu+çalışıyor; grafik fn'leri silindi; CDN script kaldırıldı.
- [ ] silent-failure-hunter temiz.
- [ ] Mobil ≤420px smoke 4 sayfa.
- [ ] Magaza.razor + veri katmanı DEĞİŞMEDİ.

## Rollback
- Her adım Chart.js'i canlı bırakır → sorunlu sayfa `<canvas>`+interop'a geri alınır; charts.js fonksiyonları **Adım 7'ye kadar SİLİNMEZ**.
- Tam rollback: `git revert` (Adım 7 ayrı commit → kolay). NuGet/DI bırakılabilir (zararsız).

## Sıra / Bağımlılık
- Adım 1 → ön koşul (net10 kanıtı); başarısızsa durur.
- Adım 2 (pilot) → desen; mutabakat geçmeden sayfa taşıma yok.
- Adım 3 → Shared component'ler; 4-6 onları kullanır.
- Adım 4,5,6 bağımsız (tek-tek commit+smoke).
- Adım 7 → EN SON; hepsi kanıtlanmadan silme yok.

---

## AÇIK SORULAR
1. **net10 + Blazor-ApexCharts v6 uyumu:** csproj net10, wrapper resmî net8+. Adım 1'de erken doğrulanır; net10'da çalışmazsa net8 multi-target mı, net10-uyumlu sürüm mü beklenir? **Karar gerekli.**
2. **Donut `PAL` (8 renk):** sabit taşıma (mevcut davranış) mı, semantic token mı? Öneri: sabit taşıma (regresyon değil).
3. **Shared component:** `Components/Shared/AppArea/AppBar/AppDonut` mı, sayfa-içi mi? Öneri: Shared (file-size-discipline).
