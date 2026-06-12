# BKM Yönetim Paneli — Dashboard

Blazor Server (.NET 10) GM BI panosu + BKM-Asistan. Stil katmanı **Tailwind CSS v3 + DaisyUI v4** (corporate teması).

## Stil (CSS) build pipeline

`wwwroot/app.css` **üretilen** dosyadır — elle düzenleme. Kaynak: `Styles/app.tailwind.css`.

```bash
cd dashboard
npm install            # tailwindcss@3 + daisyui@4 (ilk sefer)
npm run build:css      # Styles/app.tailwind.css -> wwwroot/app.css (--minify)
npm run watch:css      # geliştirirken canlı izle
```

`.csproj` içindeki `BuildTailwindCss` target'ı `node_modules` varsa `dotnet build` öncesi `npm run build:css` çalıştırır. `node_modules` yoksa (CI) atlanır; commit'li `wwwroot/app.css` kullanılır.

## Çalıştırma

```bash
npm run build:css                 # önce CSS
dotnet run                        # http://localhost:5112
```

## Tema

DaisyUI **corporate** (light, kurumsal) varsayılan — `Components/App.razor` `<html data-theme="corporate">`.
İkincil: **business** (dark) — `tailwind.config.js` `daisyui.themes`'te tanımlı. Önceki BKM kırmızısı (#E30622) yerine corporate'in nötr primary'si kullanılır; renkler artık semantic token (primary/base/neutral) üzerinden gelir.

## Yapı

- `Styles/app.tailwind.css` — Tailwind direktifleri + eski semantik sınıf adlarının (`hd/big/card/panel/btn/onc/durum/modal` …) DaisyUI/Tailwind ile yeniden tanımı (`@layer components`).
- `Components/Layout/MainLayout.razor` — DaisyUI `drawer` + `menu` + `navbar` shell (responsive, `lg:drawer-open`).
- Veri/mantık katmanı (`Data/`, `Models/`, Chart.js `wwwroot/js/charts.js`) değişmedi.
