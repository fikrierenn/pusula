# Plan 28 — HomeV2 dark-theme (renk-standardi uyumu, bespoke koyu tasarım korunur)

> **Tier 3.** UI-görünür + tailwind.config yeni tema + tek sayfa 64 hex→token. Başlangıç: 04.07.2026 · Durum: **onay bekliyor**

## Problem
`HomeV2.razor` bespoke **koyu** redesign — **64 hardcode hex** (`renk-standardi` ihlali: hex yasak, DaisyUI token). Hex'lerin çoğu **yapısal koyu palet** (`#1A1722` kart, `#ECE8F3` metin, `#6C6579` sönük), bir kısmı **semantic** (`#48C9AF` yeşil, `#FF7D6B` kırmızı, `#F4A93C` amber, `#57B0F5` mavi). Mevcut "corporate" (açık) token'a find-replace edersem → koyu tasarım açık-temaya çözülür, **BOZULUR**. Diğer TÜM sayfalar temiz (token kullanıyor); HomeV2 tek istisna.

## Amaç / Done kriteri
1. **HomeV2'de 0 hardcoded hex** — hepsi DaisyUI token.
2. **Koyu görünüm KORUNUR** (tema tokenları taşır).
3. **Sayfa-kapsamlı tema** — HomeV2 kök `data-theme="bkm-dark"`; app'in geri kalanı corporate (açık) kalır, etkilenmez.
4. Build yeşil + her widget görsel smoke (renk kayması yok).

## Karar (netleşecek — onay öncesi)
- **HomeV2 canlıya mı geçecek?** Şu an untracked/deneysel. (a) Home'un yerine geçecekse → belki app default dark tartışması; (b) parallel deneyse → sayfa-kapsamlı `data-theme` yeter. **Varsayım: (b)** — sayfa-scoped, diğer sayfalara dokunma.

## Çözüm — DaisyUI özel tema (renk-standardi'nin önerdiği yol)
`renk-standardi` zaten diyor: *"özel tema istenirse tailwind.config.js'e ekle, data-theme değiştir — KOD DEĞİŞMEZ."* HomeV2'nin paleti = `bkm-dark` DaisyUI teması.

### Palet → token eşlemesi (ÇEKİRDEK)
| Bespoke hex | Kullanım | DaisyUI token |
|---|---|---|
| `#100E15` | en koyu zemin (sayfa) | `base-100` |
| `#1A1722` | kart zemini | `base-200` |
| `white/10` sınır | ayraç/kenar | `base-300` |
| `#ECE8F3` | ana metin | `base-content` |
| `#9C94AC` | ikincil metin | `base-content/60` |
| `#6C6579` | sönük/dipnot | `base-content/40` |
| `#F4A93C` | **accent (başlık/ikon)** + "sarı" band | `primary` (marka-accent) · durum-sarı için ayrı `warning` |
| `#48C9AF` | iyi/artış | `success` |
| `#FF7D6B` | kötü/azalış/geride | `error` |
| `#57B0F5` | bilgi/ikincil seri | `info` |
| `#9B8CFF` | mor accent | `secondary` |
| `#20160a` | amber-tint zemin | `warning/10` (color-mix) |

> ⚠️ **`#F4A93C` çift-kullanım** (marka-accent vs durum-sarı) — tema kararı: accent→`primary`, durum-bandı→`warning`. HedefRow'da 85-95 sarısı `warning`, başlık/ikon `primary`. Karıştırma.

## Alternatifler (reddedilen)
1. **Find-replace → corporate token** — koyu tasarım açık'a çözülür, BOZAR. ❌
2. **Hex bırak** — renk-standardi kalıcı ihlal, tema-kırılgan. ❌
3. **Kendi CSS-var custom katmanı** — DaisyUI'yi yeniden icat, `renk-standardi` "custom token icat etme" ihlali. ❌
4. **Tüm app'i dark yap** — kapsam patlar, diğer 20 sayfa etkilenir; şimdilik gereksiz. ❌ (b seçildi: sayfa-scoped.)

## Riskler
- `#F4A93C` çift-anlam → yanlış token'da görsel karışıklık (accent yerde warning görünür). Dikkatli ayır.
- Görsel regresyon: token opaklıkları (base-content/60) hex ile birebir tutmayabilir → widget-widget göz kontrolü.
- `bkm-dark` teması app.css build çıktısını büyütür (yeni tema seti) — `.gitattributes` app.css generated, sorun değil.
- Tema `data-theme` sayfa-kökte: charts.js `--p/--su` o kök altında doğru okumalı (HomeV2 grafiği varsa `getComputedStyle(document.documentElement)` yerine kök-element gerekebilir — kontrol).

## Rollback
- Tema + HomeV2 değişikliği tek commit → `git revert`. Diğer sayfalar dokunulmadığı için app etkilenmez.

## Adımlar (sıra)
- [ ] **1.** Karar teyidi: HomeV2 scope (sayfa-scoped dark, varsayım-b).
- [ ] **2.** `tailwind.config.js` → `bkm-dark` DaisyUI teması (palet→token eşlemesi yukarıdaki tabloya göre; base-100/200/300, base-content, primary/secondary/accent, success/warning/error/info).
- [ ] **3.** HomeV2 kök `<div data-theme="bkm-dark">` sarmala.
- [ ] **4.** 64 hex → token değiştir (tabloya göre; `#F4A93C` çift-kullanım ayrımına dikkat). Tailwind utility: `bg-base-200`/`text-base-content`/`text-success` vb.
- [ ] **5.** charts.js kök-okuma kontrolü (HomeV2 grafiği tema-kökten renk alıyor mu).
- [ ] **6.** app.css rebuild (tailwind) + build.
- [ ] **7.** Görsel smoke — her widget (KPI, hedef bar, trend, grafik) koyu + renk-anlam doğru. Login gerektiğinden Fikri doğrular veya preview.

## İlişkili
- `.claude/rules/renk-standardi.md` — özel tema = tailwind.config + data-theme (bu planın dayanağı).
- `dashboard/Styles/app.tailwind.css` · `tailwind.config.js` · `dashboard/wwwroot/js/charts.js` (--p/--su okur).
- `HomeV2.razor` — hedef sayfa (proration+renk mantığı bu oturumda düzeltildi; bu plan sadece renk-token'laştırma).
