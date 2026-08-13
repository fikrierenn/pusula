# BKM Yönetim Paneli — Tasarım V2 (Handoff)

> **Amaç:** Mevcut Blazor panosunu (`GmDashboard`) yeni "finansal kokpit" görsel diline taşımak.
> Bu klasördeki dosyalar bir **tasarım referansıdır** — HTML prototip görünümü + Home için hazır bir Razor sürümü.
> Görev: bu tasarımı **mevcut kod tabanının kendi ortamında** (Blazor Server + Tailwind/DaisyUI) yeniden inşa etmek.
> **Veri katmanını (`@code`, `Queries`, modeller) DEĞİŞTİRME** — yalnızca markup + görsel dil yenilenir.

---

## Bu paketteki dosyalar

| Dosya | Ne |
|---|---|
| `HomeV2.razor` | **Genel Bakış** ekranının bitmiş v2 Razor sürümü. `Home.razor`'un `@code` bloğu birebir korunmuş; sadece markup + yardımcı fragment sınıfları yenilenmiş. Route `/v2`. Doğrudan `Components/Pages/` altına düşer. |
| `BKM-Pano-v2-referans.dc.html` | Üç ekranın (Genel Bakış / Mağaza / E-ticaret) etkileşimli HTML görsel referansı. Renk, tipografi, boşluk, düzen buradan okunur. Üretime kopyalanmaz. |

`Magaza` ve `Eticaret` sayfaları **henüz v2'ye taşınmadı** — `HomeV2.razor` deseni + bu README + HTML referansı kullanılarak aynı dille yazılmalı (mevcut `Magaza.razor` / `Eticaret.razor` `@code`'u korunarak).

---

## Fidelity: Hi-fi

Renkler, tipografi, boşluk ve etkileşimler nihaidir. Piksel sadakatiyle eşleştirin.

---

## Tasarım dili (v2 "finansal kokpit")

Karanlık, editoryal, teknik-rakam odaklı. Işık temasından tam karanlık kanvasa geçiş.

### Renk token'ları

| Rol | Hex | Kullanım |
|---|---|---|
| Kanvas (zemin) | `#100E15` | Sayfa arka planı (full-bleed) |
| Panel | `#1A1722` | Kart / KPI / grafik kutusu zemini |
| Panel-2 / AI kart | `#241F33` → `#191524` (135° gradient) | Günün Özeti kartı |
| Çizgi (border) | `rgba(255,255,255,.08–.14)` → `border-white/10` | Kart kenarları, ayraçlar |
| Metin (ana) | `#ECE8F3` | Başlık + değer |
| Metin (muted) | `#9C94AC` → `text-white/60` | Alt etiket |
| Metin (faint) | `#6C6579` → `text-white/40` | İpucu, dipnot |
| **Accent (imza)** | `#F4A93C` (koyu `#E88A2E`) | Amber — aktif durum, vurgu, primary trend |
| Pozitif | `#48C9AF` | Teal — artış WoW, ≥%95 hedef, "önde" |
| Negatif | `#FF7D6B` | Mercan — düşüş WoW, <%85 hedef, "geride" |
| Kategori paleti | `#F4A93C · #48C9AF · #9B8CFF · #FF7D6B · #57B0F5` | Bar/dilim renkleri (sırayla) |
| Kanal (online) | `#57B0F5` | Mavi — e-ticaret CTA + Toplam İşlem KPI |

> **Not:** Renkler Tailwind arbitrary value (`bg-[#1A1722]`, `text-[#F4A93C]`, `border-white/10`) ile yazıldı — JIT derler.
> Evin "sadece DaisyUI semantic token" kuralından **bilinçli sapmadır**. Alternatif: `data-theme="business"` (dark) + semantic token
> sürümü. Hangisini isterseniz o yolla ilerleyin; `HomeV2.razor` arbitrary-value yolunu izler.

### Tipografi

- **Space Grotesk** (600/700) — tüm sayılar, KPI değerleri, başlıklar. `font-['Space_Grotesk']`.
- **Newsreader** italic — editoryal üst-etiket / selamlama (ör. "günaydın", "bugünün panoraması"). `font-['Newsreader'] italic`.
- **Public Sans** — gövde metni.
- Fontlar sayfa içinde `<HeadContent>` ile yüklenir (bkz. `HomeV2.razor`). Ekstra kurulum yok.

Ölçek:
- Sayfa başlığı (h1): `clamp(26px,4vw,34px)`, 700, `tracking-tight`, `leading-none`.
- KPI değeri: `34px`, 700, Space Grotesk.
- Bölüm başlığı (h2): `19px`, 700.
- Kart başlığı (h3): `14–15px`, 700.
- Gövde: `13px`, `leading-relaxed`.
- Alt etiket: `11–12.5px`.

### Şekil & efekt

- Köşe: kartlar `rounded-3xl` (KPI, AI), satır/kutu `rounded-2xl`, bar `rounded-full`.
- Kenar: `1px solid border-white/10`.
- Gölge: `shadow-lg` yalnızca KPI + AI kartında.
- Hover (tıklanır kart/CTA): `hover:-translate-y-0.5`, `active:scale-[.98]`, `transition-transform`.
- İkonlar: **Lucide** (mevcut `data-lucide` sistemi), `w-[18px]`–`w-[23px]`.

---

## Ekranlar

### 1. Genel Bakış  (`HomeV2.razor` — bitmiş)

Düzen (üstten alta), `max-w-[1180px]` ortalı:
1. **Başlık** — Newsreader italik selam (`Greeting()`) + iri Space Grotesk "BKM Genel Bakış".
2. **Dönem pill'leri** — `#1A1722` kapsül; aktif = amber dolgu `#F4A93C` / `#20160a` metin; pasif = muted metin. Sağda takvim (özel) butonu. `SetPeriod(key)` → mevcut veri akışı.
3. **Hero KPI** (4) — mobil `carousel` / masaüstü `grid-cols-4`. Her kart: `#1A1722` panel, üstte 3px accent şerit, sol-üst renkli nokta + uppercase etiket, sağ-üst WoW rozet (teal/mercan pill), iri değer, altta ayraçlı 2-kolon alt-stat. Sıra: Toplam Ciro (amber) · Toplam İşlem (mavi) · Sepet Ort. (teal) · İade (mercan).
4. **Günün Özeti (AI)** — `#241F33→#191524` gradient kart, amber sparkles rozet, "Genius AI/Otomatik · aralık" etiketi, `Highlight()` ile sayı vurgusu (+ teal / − mercan / düz beyaz-kalın). Altta 2 CTA (Detaylı analiz / düşen mağaza incele).
5. **Mağazalar** — başlık + "Karşılaştır"/"Kategoriler" nav linkleri (amber). Kart satırları: renkli kare ikon (kategori paletinden `/15` zemin) + ad/alt + sağda tutar & WoW trend + chevron. `<a href="magaza/{id}">`.
6. **E-ticaret CTA** — mavi tint gradient kart → `eticaret`.
7. **Hedefler** (sadece `ay`/`haftalik`) — 2 kart (Mağaza / Kategori), `HedefRow`: ad + %gerçekleşme (renk eşiği) + net/hedef + mini progress + pace dikey çizgi. Altında Hedef Tahmin CTA (amber tint).
8. **Analiz** — 3 kart: Kategori Mix (**inline renkli barlar** — koyu kartta `AppRankBars` okunmadığı için elle kuruldu, kategori paleti), Son 14 Gün Net Ciro (`AppAreaChart`, `Color="#F4A93C"`), Son 14 Gün Net Alış (`AppAreaChart`, `Color="#57B0F5"`).
9. **`<AppSozluk />`** — mevcut terim sözlüğü (dokunulmadı).

### 2. Mağaza detay  (yapılacak — `Magaza.razor` `@code`'u koru)

HTML referanstaki "Mağaza detay" ekranına göre:
- Geri butonu + Newsreader alt-etiket + mağaza adı başlığı.
- 4 KPI (Net Ciro / Fiş / UPT / İade) — hero'nun küçük varyantı (`rounded-2xl`, renkli nokta + etiket + değer + alt).
- Son 30 Gün Net Ciro area chart (`AppAreaChart`, teal `#48C9AF`).
- 2 kart: Kategori Kırılımı (inline barlar) + **Yoğunluk ısı haritası** (Saat×Gün grid; hücre yoğunluğu `color-mix(in srgb, #F4A93C X%, rgba(255,255,255,.05))`; hafta sonu gün etiketi amber). Gerçek veri: `HeatCell` / mağazanın saat verisi.

### 3. E-ticaret  (yapılacak — `Eticaret.razor` `@code`'u koru)

- Başlık (Newsreader alt-etiket "online kanal performansı" + "E-ticaret").
- 4 KPI (Net Ciro / Net Sipariş / Sepet Ort. / İptal-İade).
- 2 kart: Kanal — Net Ciro (inline barlar, kategori paleti) + İl Dağılımı (ikon + ad + %pay + adet satırları).
- **Kargo Performansı** tablosu: firma | çıkış iş günü (renkli: ≤2g teal, ≥3g mercan) | durum rozeti (hızlı/orta/yavaş). Gerçek veri: `KargoPerf` / `IlTeslimat` / `EticChannel`.

---

## Etkileşim & davranış

- Dönem değişimi → `SetPeriod` → `LoadAsync` (mevcut). Yükleme sırasında aktif pill'de `loading-spinner`.
- Tüm mağaza/CTA gezinmeleri gerçek `<a href>` (SSR-güvenli, SignalR'sız çalışır — mevcut B-48 deseni korunur).
- AI özet: önce deterministik metin anında, sonra LLM arka planda (`RefreshOzetAsync`, kuşak guard'ı korunur).
- Mobil: Hero carousel + `heroDots` (mevcut `charts.js` `heroDots`), full-bleed dark kanvas MainLayout alt-nav ile uyumlu.
- Responsive: `lg:` kırılımında sidebar MainLayout'tan gelir; içerik `max-w-[1180px]`.

---

## Uygulama notları (Blazor)

- Dosya adı = sınıf adı: nokta kullanma. `HomeV2.razor` → `class HomeV2`. `@inject ILogger<HomeV2>` bununla eşleşir.
- `PersistentComponentState` anahtarları `homev2_*` (mevcut `home_*` ile çakışmaz).
- Full-bleed dark kanvas için sayfa kökü: `-m-4 p-4 lg:p-6 pb-24 lg:pb-6 min-h-[calc(100vh-3.5rem)] bg-[#100E15]` — MainLayout'un `main` `p-4`/`pb-20` dolgusunu taşırır.
- `AppAreaChart` `Color` parametresi hex kabul eder (`Color="#F4A93C"`); eksen etiketi rengi zaten koyu-uyumlu (`#94a3b8`).
- Koyu kartta `AppRankBars` / `base-content` token'ları okunmaz → oran barlarını inline kur (bkz. Kategori Mix).
- İkon seti değişmedi (Lucide `data-lucide`).

## Yapılacaklar
- [x] Genel Bakış → `HomeV2.razor`
- [ ] Mağaza → `MagazaV2.razor` (mevcut `Magaza.razor` `@code` + v2 markup)
- [ ] E-ticaret → `EticaretV2.razor` (mevcut `Eticaret.razor` `@code` + v2 markup)
- [ ] Onay sonrası `@page` route'larını `/` , `/magaza/{Id}` , `/eticaret`'e taşı, eskileri emekliye ayır
