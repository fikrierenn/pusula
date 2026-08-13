# Plan 29 — MCP App Pilot (Home KPI bandı sohbet-içi interaktif)

> Tier 3. MCP 2026-07-28 spec "MCP Apps" extension pilotu.

**Tarih:** 2026-07-29
**Proje:** `bkm`
**Yazan:** Fikri / Claude
**Durum:** `Taslak`

---

## 1. Problem

Dashboard (Blazor, localhost:5081) Claude sohbetinden AYRI yüzey. "Bugün ciro?" sorusu → Claude MCP ile SQL çalıştırıp **metin** döner; grafik/drill için ayrı Blazor açmak, restart, stale-binary derdi. AFCP tezi Claude'u kontrol düzleminin arayüzü kılıyor — ama şu an Claude tablo/grafik ÇİZEMİYOR, sadece anlatıyor. MCP Apps extension bu boşluğu kapatır: sunucu tool yanıtında sohbet-içi interaktif UI render eder.

Amaç: **tek sayfa** (Home KPI bandı) ile MCP Apps'in BKM'de çalışıp çalışmadığını kanıtla. Tüm dashboard'ı taşıma DEĞİL — pilot.

## 2. Scope

### Kapsam dahili
- Yeni minik MCP server `bkm-app` (veya mevcut dev repo `D:\Dev\sqlserver-mcp`'ye 1 tool ekleme).
- **1 tool:** `home_kpi` → bugünkü net ciro + hedef gerçekleşme + kategori mini-bar (top 5).
- SQL katmanı mevcut Blazor sorgularından TAŞINIR (`TrafikQueries.cs` / `RefQueries.cs` → aynı T-SQL, yeni yer).
- MCP App UI payload: DaisyUI-token renk mantığı (`charts.js` KP/PAL) korunur.
- Blazor Home **paralel kalır** — pilot kanıtlanana kadar silinmez.

### Kapsam dışı
- Tüm dashboard sayfalarının taşınması (pilot kanıtlanırsa plan-30).
- `sqlserver` MCP'nin genel stateless-spec migration'ı (ayrı iş — bkz. §8).
- Yazma işlemi (ERP-write policy: pilot **salt-okuma**).
- Drill-down 2. seviye (önce tek-band render kanıtı; drill pilot-2).

### Etkilenen dosyalar (tahmin)
- `<mcp-server>/tools/home_kpi.*` — yeni tool (SQL + UI payload)
- `<mcp-server>/ui/home-kpi.html` (veya JS) — MCP App render şablonu
- `sema/` — yeni köprü/kod çıkarsa (beklenmiyor, mevcut SQL)
- `plans/29-mcp-app-pilot.md` — bu dosya
- `TODO.md` — madde ekleme

**Tahmini boyut:** 3-4 dosya / ~200 satır (SQL zaten var, taşınıyor).

## 3. Alternatifler

### A: Tüm dashboard'ı MCP Apps'e taşı
**Açıklama:** Blazor'u komple MCP App yüzeyine çevir.
**Reddetme sebebi:** Big-bang, SDK olgunluğu belirsiz, geri-alma zor. `before-major-change` + `footprint-ladder` ihlali. Önce 1 sayfa kanıtla.

### B: MCP Apps'i atla, Blazor'da kal
**Açıklama:** Mevcut ayrı-dashboard modeli sürsün.
**Reddetme sebebi:** AFCP tezinin çekirdeği (Claude=arayüz) gerçekleşmez; iki-yüzey bakım yükü kalıcı olur. Yeni spec'in en yüksek-değerli kazanımını kaçırırız.

### C (SEÇİLEN): Tek-sayfa pilot (Home KPI bandı)
**Açıklama:** En görünür, en küçük yüzey. SQL zaten var, sadece render katmanı yeni. Kanıtlanırsa genişlet, kanıtlanmazsa 3 dosya çöpe — ucuz.
**Sebep:** Düşük risk + yüksek öğrenme. Footprint-ladder en-dar basamak. Blazor paralel → rollback bedava.

## 4. Riskler

| Risk | Etki | Olasılık | Mitigation |
|---|---|---|---|
| MCP Apps SDK olgun değil / Claude Code'da desteklenmiyor | yüksek | orta | Pilot ÖNCE: claude.ai + Claude Code'da "MCP App render ediliyor mu?" smoke-test. Render yoksa plan durur, Blazor kalır. |
| Stateless spec migration gerektirir | orta | orta | Pilot server'ı baştan stateless yaz (request/response, state yok). Mevcut `sqlserver` MCP'ye dokunma. |
| SQL master-katalog 208 hatası (3-parçalı isim) | orta | orta | Tool SQL'i 3-parçalı (`DerinSISBkm.dbo.irsHrk`) — sql-server-conventions kuralı. |
| ERP-write kazası | yüksek | düşük | Pilot salt-okuma. Server DB login salt-okuma (erp-write-policy). |
| Renk/tema tutarsızlığı | düşük | orta | DaisyUI token mantığı taşınır, hardcode hex yok (renk-standardi). |

## 5. Done Criteria

- [ ] `home_kpi` tool bir MCP server'da canlı; Claude sohbetinde çağrılıyor.
- [ ] Sohbet-içi interaktif KPI bandı RENDER oluyor (metin değil, görsel) — claude.ai VE/VEYA Claude Code'da kanıt (screenshot).
- [ ] Rakamlar Blazor Home ile birebir (mutabakat: aynı gün ciro/hedef).
- [ ] Salt-okuma doğrulandı (write yok, ERP-write-policy uyumlu).
- [ ] Renk DaisyUI-token (hardcode hex yok).
- [ ] Karar notu: "render çalıştı → plan-30 genişletme" VEYA "çalışmadı → Blazor kalır, neden".

## 6. Rollback Planı

- Pilot server ayrı proses → durdur, `sqlserver` MCP'ye dokunulmadı, sıfır etki.
- Git revert: yeni dosyalar, `git revert <commit>` temiz.
- Blazor Home hiç değişmedi → dashboard aynen çalışır.

## 7. Adımlar

1. [ ] **P29-1** Smoke: MCP Apps Claude Code + claude.ai'de render ediliyor mu? (minimal "hello UI" tool). Render YOKSA dur, kullanıcıya bildir.
2. [ ] **P29-2** `home_kpi` SQL'i mevcut Blazor sorgusundan çıkar (3-parçalı, salt-okuma).
3. [ ] **P29-3** MCP App UI payload (KPI bandı + kategori mini-bar, DaisyUI token).
4. [ ] **P29-4** Canlı test + Blazor mutabakat (aynı gün rakam).
5. [ ] **P29-5** Karar notu + journal + (kanıtlanırsa) plan-30 taslak.

## 8. İlişkili

- Önceki plan: `plans/06-mcp-server-ayiklama.md` (MCP server ayrıştırma), `plans/28-homev2-dark-theme.md`
- Kural: `.claude/rules/erp-write-policy.md` (salt-okuma), `sql-server-conventions.md` (3-parçalı isim), `renk-standardi.md`, `footprint-ladder.md`
- Ayrı iş: `sqlserver` MCP genel stateless-spec migration (pilot kanıtlanınca ayrı plan)
- Kaynak: MCP 2026-07-28 spec (claude.com/blog/bringing-mcp-2026-07-28-to-claude)

## 9. Onay

- [ ] Plan kullanıcıya gösterildi
- [ ] Onay alındı: <tarih>
