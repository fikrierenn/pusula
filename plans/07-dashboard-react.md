# Plan 07 — GM Dashboard React + JSON API (sunum katmanı yeniden yazımı)

**Tier:** 3 (yeni stack, npm bağımlılığı, 3+ klasör, kullanıcı-görünür)
**Tarih:** 11.06.2026 · **Durum:** onay bekliyor

## Problem

`scripts/gm_dashboard.py` HTML'i **Python string template** içinde üretiyor (~800 satır, CSS gömülü). Sonuç: panel overlap'ları, kırılgan layout, bakımı zor. Kullanıcı "üst üste binmeler var, py değil daha şık bir şey" dedi.

**Kritik gözlem:** Backend zaten JSON API. `serve()` şu endpoint'leri sunuyor → `/api/period`, `/api/urun`, `/api/urunler`, `/api/musteri`, `/api/hareket`, `/api/fis`, `/api/stok`. Sadece `/` rotası string-HTML. Yani **veri katmanı %80 hazır, sadece sunum atılacak.**

## Scope

- **DEĞİŞMEZ:** pymssql bağlantı, `period_data()`, tüm SQL sorguları, sema, drill query'leri (`URUN_SQL`, `MUS_YK` vs). Veri mantığı aynen korunur.
- **YENİ:** `dashboard/` — Vite + React + TypeScript + Tailwind + Recharts frontend.
- **EKLENİR:** Backend'e tek `/api/init` endpoint (REF + 3 dönem DATA + env + trend → tek JSON; şu an HTML'e gömülü olan her şey).
- **SİLİNİR (en son, onayla):** `gm_dashboard.py` içindeki `TEMPLATE` string + `render()` HTML üretimi. Veri fonksiyonları kalır.

## Stack kararı

| Katman | Teknoloji | Gerekçe |
|---|---|---|
| Backend | Mevcut `http.server` + `/api/init` | FastAPI gereksiz — çalışan JSON server var, az değişiklik |
| Build | Vite | Hızlı, sıfır-config, React+TS hazır |
| UI | React 18 + TypeScript | Component bazlı → overlap imkânsız (CSS grid/flex izole) |
| Stil | Tailwind CSS | Utility, BKM kırmızı (#E30622) tema token |
| Grafik | Recharts | React-native, responsive, donut/bar/area/scatter |

**Reddedilen:** Streamlit (yine py, drill modal zayıf) · Metabase (sema/özel drill kaybolur) · Next.js (SSR overkill, statik yeter).

## Mimari

```
dashboard/                    # YENİ frontend
  index.html
  vite.config.ts             # build → ../briefings/gm-dashboard/dist/
  tailwind.config.js
  src/
    main.tsx, App.tsx
    api.ts                   # fetch wrapper (/api/*)
    types.ts                 # Period, Ref, Store, Kasiyer...
    components/
      Header.tsx PeriodSelect.tsx
      KpiBand.tsx StoreCard.tsx
      CategoryBar.tsx EticDonut.tsx TrendArea.tsx HourBar.tsx
      KasiyerTable.tsx DevirTable.tsx AbcTable.tsx RfmTable.tsx
      MarkaPanel.tsx StockoutTable.tsx SplhTable.tsx CodTable.tsx
      CveScatter.tsx
      DrillModal.tsx         # /api/urun, /api/musteri, /api/stok
backend (gm_dashboard.py):
  + /api/init  → {data:{gunluk,haftalik,ay}, ref, env, trend, bas}
  serve() → dist/ statik sun (index.html + assets)
```

## Adımlar (aşamalı, her aşama commit)

1. **Backend `/api/init`** — `render()` içindeki DATA+REF+env+trend hesabını endpoint'e taşı (JSON döndür, HTML üretme). `serve()` `dist/`'i statik sunsun. `gm_dashboard.py --build-data` opsiyonu (ön-hesap cache JSON yaz, ilk yük hızlı).
2. **Vite iskelet** — `dashboard/` kur (React+TS+Tailwind+Recharts), `npm run dev` proxy `/api`→8000. Layout shell: header + dönem seçici + KPI bandı + responsive grid (CSS Grid, `gap`, overlap yok).
3. **Üst paneller** — KpiBand, StoreCard, CategoryBar, EticDonut, TrendArea, HourBar, KasiyerTable (mağaza gruplu). Recharts.
4. **Referans paneller** — Devir/Abc/Rfm/Marka(full-width)/Stockout/Splh/Cod tabloları + CveScatter.
5. **Drill modal** — panel tıkla → modal, `/api/urun|musteri|stok|urunler` fetch. Ürün embed (server'sız ilk veri REF'ten).
6. **Build + serve** — `npm run build` → `dist/`, `python gm_dashboard.py --serve` dist sunar. Tek komut akışı. Eski TEMPLATE/render sil.

## Done kriterleri

- `npm run build` temiz, `--serve` dist sunuyor, tüm paneller dolu + overlap YOK (responsive 1280/1920).
- Dönem seçici (günlük/haftalık/aylık) çalışıyor, drill modal'lar canlı.
- Rakamlar mevcut panoyla birebir (kategori mix = drill, kasiyer 18 tam, marka top20).
- `gm_dashboard.py` veri fonksiyonları değişmedi (SQL/sema sabit).

## Riskler

- **pymssql tek-server, ilk yük yavaş** → `/api/init` ön-hesap JSON cache (`dist/init.json` build-time veya ilk istek cache).
- **Türkçe charset** → fetch JSON UTF-8 (zaten `ensure_ascii=False`).
- **Drill SQL injection** → param'lı (mevcut), kat/seg whitelist.
- **İş büyük** → aşamalı commit, her faz çalışır halde bırak. Eski pano son adıma kadar bozulmaz.

## Rollback

`gm_dashboard.py` git'te; `dashboard/` ayrı klasör. Eski string-template son adımda silinene dek paralel durur — `git checkout` ile dönülür.
