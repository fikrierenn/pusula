# Renk Standardı (BKM Yönetim Paneli)

_Tek kaynak: DaisyUI semantic token (corporate tema). Hardcode hex YASAK. `paths:` yok — compact sonrası survive._

## Temel İlke

**Hiçbir yerde ham hex renk yazma** (`#dc2626`, `#16a34a`, `#E30622`…). Her renk bir ANLAM taşır → o anlamın DaisyUI token'ını kullan. Tema değişince (corporate↔business↔BKM) tüm panel otomatik uyar.

## Anlam → Token Eşlemesi (KANONİK)

| Anlam | DaisyUI token | Utility class | Nerede |
|---|---|---|---|
| **Ana vurgu / marka** | `primary` | `text-primary` `bg-primary` `border-primary` | aktif nav, KPI bandı, ana buton, grafik ana seri |
| **Kötü / azalış / iade / risk** | `error` | `text-error` | iade tutarı, düşüş, devir<1.5x, gecikme, COD iade, stockout>%5 |
| **İyi / artış / hedef-üstü / sağlıklı** | `success` | `text-success` | artış, hedef tut (≥%95), devir sağlıklı, teslim |
| **Dikkat / orta** | `warning` | `text-warning` | orta öncelik, hedef %85-95, bekleyen 2-3g |
| **Bilgi / ikincil seri** | `info` | `text-info` | e-ticaret, ikincil grafik çizgi |
| **Soluk / meta** | `base-content/40` | `text-base-content/40` `opacity-60` | sıra no, dipnot, placeholder, "—" |
| **Normal metin** | `base-content` | (varsayılan) | gövde metin |
| **Kart / zemin** | `base-100` / `base-200` | `bg-base-100` `bg-base-200` | panel, sayfa, zebra satır |
| **Kenarlık** | `base-300` | `border-base-300` | kart border, ayraç |

## Kurallar

1. **Razor'da renk = utility class.** `style="color:#dc2626"` → `class="text-error"`. Koşullu: `class="@(x<0 ? "text-error" : "text-success")"`.
2. **Grafik (Chart.js) = CSS değişkeni oku.** `getComputedStyle(root).getPropertyValue('--p'/'--er'/'--su'…)` → `oklch(...)`. Hardcode palet YASAK. (charts.js KP/PAL bunu yapar.)
3. **Yeni renk gerekiyorsa** önce "bu hangi anlam?" sor → mevcut token'a bağla. Yeni token uydurma.
4. **Tema BKM kırmızısı istenirse:** `tailwind.config.js`'e özel tema ekle (primary=#E30622), `data-theme` değiştir — KOD DEĞİŞMEZ (semantic token sayesinde).
5. **Durum renkleri evrensel:** kırmızı=kötü, yeşil=iyi her temada `error`/`success` — bunlar tema-primary'den BAĞIMSIZ, anlam sabit.

## MÜMKÜN OLDUĞUNCA DAİSYUI — özelleştirme minimum

**DaisyUI ne veriyorsa onu kullan.** Kendi renk değişkeni / köprü / custom token İCAT ETME.
- Renk: `text-error`/`text-success`/`text-warning`/`text-info`/`text-primary` (DaisyUI hazır utility).
- Component: `card`/`btn`/`badge`/`table`/`stat`/`alert`/`menu`/`drawer`/`navbar` (DaisyUI hazır).
- Grafik: charts.js DaisyUI token (`--p`/`--er`/`--su`) okur — kendi palet sabiti yok.
- Custom CSS sadece DaisyUI'nin VERMEDİĞİ şey için (ör. Chart.js canvas wrapper). Onun dışında DaisyUI utility.

## Anti-pattern
- ❌ `style="color:#16a34a"` (hardcode) → `text-success`
- ❌ Kendi `--c-vurgu` / `:root` renk değişkeni → DaisyUI utility yeter, custom token icat etme
- ❌ charts.js `const KP='#E30622'` (sabit) → DaisyUI `--p` oku
- ❌ DaisyUI'nin verdiği component'i custom CSS ile yeniden yapma → hazır `card`/`btn`/`badge` kullan
- ❌ Tema-primary'yi durum için kullanma (primary=marka, error/success=durum ayrı)

## İlişkili
- `.claude/skills/asistan-ui/SKILL.md` — UI tasarım (bu standardı uygular)
- `dashboard/Styles/app.tailwind.css` — DaisyUI tema + token
- `dashboard/wwwroot/js/charts.js` — grafik (--p/--er/--su okur)
