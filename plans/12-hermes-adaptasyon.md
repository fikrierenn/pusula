# Plan 12 — Hermes Yaşam-Döngüsü & Context-Maliyeti Desenlerinin BKM'ye Minimal-Footprint Adaptasyonu

> Bu plan Tier 3 işler içindir. Workstream'lere bölünmüş; her workstream kendi Tier'ı + kendi mini-onayı ile uygulanır (tek blok değil — bkz. §10).

**Tarih:** 2026-06-16
**Proje:** `bkm`
**Yazan:** Fikri / Claude (planner subagent, opus)
**Durum:** ✅ TAMAMLANDI 16.06 — 7/7 WS (WS-1 78c9060 · WS-4+6 86d903e · WS-2 72d3f62 · WS-5 1f40896 · WS-3 e7a5d50 · WS-7). Faz-2 ertelenenler B-93/94/95.

---

## 1. Problem

BKM Claude Code çatısı olgun: 15 rule, ~10 skill, 4 agent, 5 sema YAML (confidence+evidence'li), Blazor dashboard, pymssql script seti. Ama iki sistemik eksik var:

1. **Yaşam-döngüsü disiplini yok.** sema-fact'ler bir kez doğrulanıyor, sonra "kalıcı" varsayılıyor — eskime (decay) izlenmiyor. Fact-Force Gate'in yalnızca "ilk dokunuş keşfi" yarısı var; "doğrulanmış gerçek zamanla bayatlar" yarısı yok. TODO maddeleri "30g→ya yap ya sil" eşiğiyle anılıyor ama mekanize değil. Hangi sema-fact / skill fiilen kullanılıyor — telemetri yok, ölü kayıt birikiyor.

2. **Context-maliyeti disiplini yok.** 15 rule HER session system-prompt'a giriyor = sabit token yükü; `renk-standardi` (E-ticaret SQL session'ında alakasız) veya `turkish-ui` (script session'ında alakasız) her zaman yükleniyor. Hangi rule'un her zaman / hangisinin on-demand olduğu ayrılmamış.

Ek olarak iki nokta-risk: dashboard nav iki yerde elle yönetiliyor (sidebar + btm-nav senkron değil → orphan link riski, B-75'te yaşandı), ve DB/MCP/JOKER hataları kod tabanında dağınık inline string-match ile ele alınıyor (transient vs fatal ayrımı merkezi değil).

Hermes-agent'ın (Nous Research) olgun **curator + context-compression + error-classifier + footprint-ladder + registry** desenleri bu boşlukları tam dolduruyor — AMA Hermes'in çok-platform/çok-provider/gateway/plugin/cron-daemon karmaşıklığı BKM'nin (tek-kullanıcı/tek-makine CFO çalışma alanı) şekline uymuyor. **Amaç: olgun fikirleri al, dağıtık karmaşıklığı bırak.**

## 2. Scope

Bu plan **6 workstream + 1 destek-iş** içerir. Her biri kendi Scope/gerekçe/mevcut→hedef'iyle aşağıda. Çoğu Tier-2 (rule/skill metni), ikisi Tier-3 (kod: Registry-nav, ErrorClass).

### 2.0 Kesişen ilke (tüm workstream'lere uygulanır)
Hermes'in KENDİ felsefesi bu adaptasyona uygulanır: **narrow waist** (en dar footprint'te çöz, BKM'ye framework kurma), **mevcudu güçlendir > yeni ekle**, **ASLA silme → archive** (git zaten snapshot tutuyor; curator-tarzı state machine archive-only), **deferred invalidation** (rule/sema değişimi varsayılan sonraki session'da yürürlüğe).

---

### WS-1 — Curator: sema + TODO yaşam-döngüsü (Tier 2, rule + skill metni; KOD YOK)

**Mevcut → hedef:**
- `sema/*.yaml` kayıtları `confidence` + `evidence` (tarih) taşıyor ama `last_verified` / `verify_after` YOK → "ne zaman tekrar doğrulanmalı" bilinmiyor. **Hedef:** her kayda opsiyonel `last_verified: YYYY-MM-DD` + `verify_after: YYYY-MM-DD` (veya gün-cinsi `ttl_days`) alanı; eskiyen `evidence`'lı kayıt curator-check'te **stale bayrağı** alır (silinmez). Bu Fact-Force Gate'in eksik yarısı (decay).
- `TODO.md` "30g→ya yap ya sil" eşiği prosa olarak var → state machine değil. **Hedef:** madde durum modeli `open → stale (N gün dokunulmadı) → archive` formalize; archive = `TODO.md` içinde `## Arşiv` bölümü veya `docs/journal/`'a taşıma (git history korur). Silme yok.
- Curator-check **inactivity-triggered** (cron DEĞİL — BKM'de daemon yok): `session-handoff` skill'i çalışırken, son curator-check üstünden ≥7 gün geçtiyse hafif bir tarama tetiklensin (handoff'a 1 adım eklenir).
- `consolidate-memory` (Hermes'te LLM consolidation pass) → BKM'de **opsiyonel `consolidate-sema` skill'i**: dar/çakışan sema kayıtlarını veya stale TODO'ları **dry-run** ile rapor eder (`REPORT.md`, mutasyonsuz); kullanıcı onaylarsa uygular. Hermes hard-rule: "counter'ı consolidation'ı atlamak için kullanma" → BKM'de "stale bayrağı ≠ otomatik archive; kullanıcı onayı şart" olarak taşınır.
- Telemetri (hafif): hangi sema-fact / skill kullanılıyor — Hermes'in `.usage.json` sidecar'ı. **BKM'de minimal:** opsiyonel; yüksek-değerli değilse ERTELE (bkz. §2.6 değer/efor). Karar: **bu planda telemetri ERTELENİR** (manuel "bu kayıt 6 aydır referans edilmedi mi?" yargısı yeterli; sidecar yazma altyapısı tek-kullanıcı için over-engineering).

**Etkilenen dosyalar:**
- `sema/README.md` — `last_verified`/`verify_after` alan tanımı + decay kuralı (doküman).
- `sema/bridges.yaml`, `sema/codes.yaml`, `sema/entities.yaml`, `sema/metrics.yaml` — yeni alanlar **geriye-dönük opsiyonel** (mevcut kayıtlara dokunmadan, yeni/dokunulan kayda eklenir; toplu doldurma YOK).
- `.claude/rules/semantic-layer.md` — decay + curator-check kuralı.
- `.claude/skills/sema-ogren/SKILL.md` — yeni kayıtta `last_verified` zorunlu, `verify_after` öner.
- `.claude/skills/session-handoff/SKILL.md` — Adım 4.6 "curator-check (≥7g ise stale tarama)".
- (Opsiyonel) `.claude/skills/consolidate-sema/SKILL.md` — yeni dry-run skill.
- `TODO.md` — `## Arşiv` bölümü + state-machine notu.

---

### WS-2 — NarrowWaist: rule-tiering + footprint-ladder (Tier 2, doküman + dizin; compact-survival KRİTİK)

**Mevcut → hedef:**
- 15 rule'un tamamı her session yükleniyor. **Hedef ayrım:**
  - **Çekirdek-her-zaman (core):** `session-protocol`, `session-memory`, `commit-discipline`, `sql-server-conventions`, `semantic-layer`, `before-major-change`, `response-style`, `error-handling`, `security-principles`. Bunlar `paths:` ALMAZ (compact-survival — BKM bunu bilinçli yaptı, korunur).
  - **Konu-bazlı (on-demand):** `renk-standardi`, `turkish-ui`, `file-size-discipline`, `agent-usage`, `coding-discipline`, `test-discipline`, `todo-verification`. Bunlar ilgili iş tetiklenince devreye girmeli.
- **DİKKAT — compact-survival trade-off (Hermes "cache sacred" eşdeğeri):** BKM `paths:`'i compact sonrası kural-kaybını önlemek için kaldırdı. Çözüm: konu-bazlı rule'ları `paths:` ile DEĞİL, **ilgili skill'in içine referans/inject** ederek on-demand yap. Örn. `asistan-ui` skill'i `renk-standardi`'yi açıkça okur/atıfta bulunur; dashboard işine girince skill zaten çağrılıyor. Böylece rule dosyası system-prompt'tan çıkmaz (silinmez), ama "her zaman aktif zihinsel yük" azalır çünkü skill-bağlamında çağrılır. **Net karar:** rule dosyaları yerinde kalır (silme yok); değişiklik = rule başına 1-satır "Bu kural <skill> tetiklenince birincil; core değil" etiketi + ilgili skill'e "bu rule'u uygula" satırı. Sistem-prompt token'ı **gerçekten** düşürmek istenirse (ikinci faz, opsiyonel) konu-bazlı rule'lar `.claude/rules/topic/` alt-dizinine taşınıp skill-inject edilir — ama bu compact-survival'ı test etmeden YAPILMAZ (risk, bkz. §4).
- **Footprint-ladder:** Hermes'in "yeni yetenek en dar rung'da" merdiveni BKM diline çevrilir → yeni `.claude/rules/footprint-ladder.md` (veya `coding-discipline.md`'ye bölüm). BKM rung'ları: `mevcut script/rule'u genişlet → yeni skill → yeni rule → yeni agent → yeni sema-entity → yeni dashboard sayfası/servis (son çare)`. "MCP/plugin/core-tool" rung'ları BKM'de YOK (reddedilen — §2.5).

**Etkilenen dosyalar:**
- `.claude/rules/footprint-ladder.md` — YENİ (veya `coding-discipline.md`'ye bölüm).
- Konu-bazlı 7 rule dosyası — başına 1-satır "on-demand / core" etiketi.
- İlgili skill'ler (`asistan-ui`, `dashboard-icerik`) — "ilgili rule'u uygula" referansı.
- `CLAUDE.md` — "Rule katmanları (core vs on-demand)" 3-satır not (İçerik Haritası yakını).

---

### WS-3 — Registry: dashboard nav tek-kaynak (Tier 3, KOD — Blazor)

**Mevcut → hedef:**
- `dashboard/Components/Layout/MainLayout.razor`'da nav İKİ yerde elle: sidebar (`<aside>` `<ul class="menu">`, ~11 link) + mobil `btm-nav` (5 link). Senkron değil — `toplam`, `sadakat`, `tahmin` sidebar'da var ama btm-nav'da yok (kasıtlı olabilir ama elle takip = orphan riski; B-75'te 2 link elle eklendi).
- **Hedef (Hermes "registry single-source-of-truth"):** tek `NavItem[]` kaynak (örn. `dashboard/Models/NavRegistry.cs` — `record NavItem(string Href, string Label, string Icon, bool InBottomNav, NavLinkMatch Match)`). MainLayout sidebar VE btm-nav bu listeden `@foreach` ile türer. Tek satır eklemek tüm downstream'i (sidebar + mobil + ileride breadcrumb/help) günceller.
- Görev rozeti (`_acikGorev`) gibi dinamik öğeler NavItem'a opsiyonel `BadgeProvider` ile bağlanır veya özel-case kalır (over-engineering'den kaçın — rozet tek yerde, registry'e zorlamak gereksiz; **karar: rozet özel-case, registry sadece statik link seti**).

**Etkilenen dosyalar:**
- `dashboard/Models/NavRegistry.cs` — YENİ (`NavItem` record + statik `Items` listesi).
- `dashboard/Components/Layout/MainLayout.razor` — sidebar + btm-nav `@foreach (NavRegistry.Items...)`; mevcut görsel/DaisyUI class'ları korunur (`renk-standardi`: token, hex yok).

---

### WS-4 — Delegation: agent-usage rolleri (Tier 2, rule metni)

**Mevcut → hedef:**
- `.claude/rules/agent-usage.md` model katmanı + iş→ajan matrisi var; ama **leaf vs orchestrator rol ayrımı + depth-cap yok**. Bu session 4 paralel read-only ajan açıldı, formal sınır yoktu.
- **Hedef (Hermes delegation):** agent-usage.md'ye ekle:
  - **leaf** rol: delegate/clarify/memory ÇAĞIRAMAZ, salt-işçi (mevcut `code-explorer`, `silent-failure-hunter`, `python-reviewer` zaten leaf — etiketle).
  - **orchestrator** rol: depth-bounded, `max_concurrent=3` (BKM'nin mevcut "3+ paralel feature" eşiğiyle hizalı), subagent past-context'ten İZOLE, parent summary bekler.
  - Per-task model resolution zaten var (haiku/sonnet/opus matrisi) — "her Task çağrısında model bilinçli seç" kuralı `depth-cap` ile pekiştirilir.

**Etkilenen dosyalar:**
- `.claude/rules/agent-usage.md` — "§7 Rol & Derinlik (leaf/orchestrator, max_concurrent=3, izolasyon)" bölümü.

---

### WS-5 — ErrorClass: merkezi hata sınıflandırma (Tier 3, KOD — C# + Python)

**Mevcut → hedef:**
- BKM'de hata ele alma dağınık: `Db.cs` `CommandTimeout=240` + ConnectTimeout var, telefon circuit-recovery + commandTimeout mevcut, script'lerde inline `except`. Transient (DB-timeout / linked-server-overload / SignalR-drop → retry+backoff) vs fatal (SQL syntax / schema hatası → fail+net mesaj) ayrımı merkezi DEĞİL.
- **Hedef (Hermes error_classifier):** hafif merkezi sınıflandırıcı.
  - C#: `dashboard/Data/SqlErrorClassifier.cs` — `SqlException.Number` + message-pattern → enum `{ Transient, Fatal }` + `ShouldRetry`. Priority-ordered: SQL error number (örn. -2 timeout, 1205 deadlock, 53/40613 transient) → message-pattern → bilinmeyen=transient (retry-safe). `Db.OpenAsync`/sorgu sarmalayıcıda kullanılır (backoff retry, max 2).
  - Python: `scripts/_errors.py` — pymssql `OperationalError` vs `ProgrammingError` ayrımı + `is_transient()` helper; `send_mail.py` / `generate_brief.py` gibi script'lerin `except` blokları buradan beslenir.
  - `error-handling.md` rule'u koddaki sınıflandırıcıya bağlanır (rule "beklenen vs gerçek exception" + "sınıflandırma kod tarafında SqlErrorClassifier/_errors.py'de" referansı).
  - **Anti-thrash:** retry yalnızca transient + max 2 deneme + backoff; sessiz fallback YOK (her retry loglanır — `error-handling.md` "fallback sessiz olmasın" kuralı).

**Etkilenen dosyalar:**
- `dashboard/Data/SqlErrorClassifier.cs` — YENİ.
- `dashboard/Data/Db.cs` — retry sarmalayıcı (mevcut timeout/recovery ile BİRLEŞTİR, çakıştırma).
- `scripts/_errors.py` — YENİ (helper).
- 2-3 script (`send_mail.py`, `generate_brief.py`) — `_errors.py` kullanımı (yalnızca dokunulan, toplu refactor YOK).
- `.claude/rules/error-handling.md` — sınıflandırıcı referansı.

---

### WS-6 — Journal/handoff sertleştirme: iterative-summary + anchor (Tier 2, skill metni)

**Mevcut → hedef:**
- `session-handoff` skill'i journal yazıyor ama her seferinde sıfırdan; uzun günlerde özet kayması olabilir.
- **Hedef (Hermes context-compression: iterative-merge + anchor):** handoff skill'ine ekle:
  - **iterative-summary:** aynı gün 2. oturum → mevcut journal'ı SIFIRDAN yazma, üstüne **merge** (zaten `## Oturum 2` var — "önceki özeti koru, yeni delta ekle" netleştir).
  - **anchor disiplini:** "son kullanıcı talebi + son yarım-kalan iş ANCHOR — özetlenirken kaybolmaz" (Hermes tail-anchor). Bu zaten "Yarına Başlangıç Noktası" bölümünde örtük; "bu bölüm asla budanmaz/özetlenmez" kuralı eklenir.
  - **anti-thrash:** "son oturumda <10% yeni içerik varsa ayrı oturum bloğu açma, mevcut bloğa not düş" (gürültü azaltma).

**Etkilenen dosyalar:**
- `.claude/skills/session-handoff/SKILL.md` — "iterative-merge + anchor (budanmaz bölüm)" notları.

---

### WS-7 (opsiyonel) — Test: behavioral-contract kuralı (Tier 1-2, rule metni)

**Mevcut → hedef:**
- `test-discipline.md` "edge case + happy-path dışı" diyor ama Hermes'in **anti-snapshot** kuralı yok.
- **Hedef:** `test-discipline.md`'ye "ilişki doğrula, mevcut-veri değil" satırı: snapshot/change-detector test reddet (`len(x)==8` kötü → `len(x)>=1` veya ilişki-invariantı iyi). BKM bağlamında: rapor doğrulama testlerinde "bu hafta 37 mağaza-satırı geldi" değil "mağaza-satırı sayısı ≥1 ve net ciro = brüt − indirim" gibi invariant. **Düşük efor, makul değer — opsiyonel son sıra.**

**Etkilenen dosyalar:**
- `.claude/rules/test-discipline.md` — 3-4 satır anti-snapshot bölümü.

---

### Kapsam dışı (açık)
- WS-Curator telemetri sidecar (`.usage.json` benzeri otomatik kullanım sayacı) — ERTELENDİ (tek-kullanıcı için over-engineering; manuel yargı yeterli).
- Otomatik archive (kullanıcı onayı olmadan TODO/sema kaydı taşıma) — YASAK (yalnızca dry-run rapor + onay).
- NarrowWaist faz-2 (rule'ları fiziksel `topic/` dizine taşıma) — bu planda YALNIZCA etiketleme; fiziksel taşıma compact-survival testi geçmeden YAPILMAZ.
- Aşağıdaki Hermes desenleri tamamen reddedildi (§5).

**Tahmini boyut:** WS-1..7 toplam ~12-16 dosya değişiklik + 4 yeni dosya (`footprint-ladder.md`, `NavRegistry.cs`, `SqlErrorClassifier.cs`, `_errors.py`) + opsiyonel `consolidate-sema/SKILL.md`. Hiçbir workstream tek başına >5 dosya değil (footprint-ladder felsefesine uygun).

## 3. Alternatifler

### A: Hermes desenlerini bütünsel "BKM-curator framework" olarak kur
**Açıklama:** Tek `curator.py` + `context_compressor.py` + `error_classifier.py` portu, sema+TODO+rule+kod hepsini yöneten merkezi daemon.
**Reddetme sebebi:** Narrow-waist ihlali. BKM tek-kullanıcı/tek-makine; daemon/cron/merkezi-runner BKM'nin şekline yabancı. Hermes'in KENDİ footprint-ladder felsefesi "en dar rung'da çöz" diyor — framework en geniş rung. Bakım yükü > değer.

### B: Hiçbir şey yapma — mevcut prosa kurallar yeterli ("30g→ya yap ya sil" zaten yazıyor)
**Açıklama:** Decay/lifecycle'ı insan-yargısına bırak, rule-tiering'i görmezden gel.
**Reddetme sebebi:** Boşluk gerçek: sema-fact'ler sessizce bayatlıyor (Fact-Force Gate'in yarısı eksik — bu sessiz-yanlış-rakam riski, BKM'nin EN çok kaçındığı şey), nav orphan riski yaşandı (B-75), error-handling dağınık. Prosa kural ≠ mekanize disiplin.

### C (SEÇİLEN): Workstream'li, fazlı, minimal-footprint adaptasyon
**Açıklama:** Her Hermes deseni BKM'nin gerçek şekline ayrı ayrı haritalanır; çoğu rule/skill metni (Tier-2, sıfır kod), yalnızca gerçek-değerli 2 tanesi kod (Registry-nav, ErrorClass). Her workstream bağımsız teslim + kendi onayı.
**Sebep:** Mevcudu güçlendirir (yeni framework değil), değer/efor önceliklendirilir, riskli olanlar (rule-tiering) test-gate'li, geri-alınabilir.

## 4. Riskler

| Risk | Etki | Olasılık | Mitigation |
|---|---|---|---|
| **Rule-tiering compact-survival'ı bozar** — konu-bazlı rule `paths:` veya dizin-taşıma ile system-prompt'tan çıkınca compact sonrası kural unutulur | yüksek | orta | Bu planda FİZİKSEL taşıma YOK; yalnızca etiket + skill-inject referansı. Rule dosyaları yerinde kalır (silinmez). Faz-2 (fiziksel taşıma) ayrı plan + compact-survival smoke testi geçmeden yapılmaz. |
| **sema-decay yanlış-pozitif stale** — `ttl_days` dolduğu için 1.0-confidence kalıcı FK (`irshrk-stk`) "stale" işaretlenir, gereksiz yeniden-doğrulama | orta | orta | `confidence: 1.0` (kalıcı PK/FK) kayıtlar decay'den MUAF (pinned eşdeğeri). `verify_after` yalnızca confidence <1.0 + gözleme-dayalı kayıtlara. Stale = bayrak, otomatik aksiyon değil. |
| **Registry-nav mevcut çalışan nav'ı kırar** — `@foreach` refactor sırasında ActiveClass/Match/badge/DaisyUI class'ı kaybolur (B-48 SSR nav saga'sı tekrarı) | yüksek | orta | Görsel çıktı birebir korunur (class string'leri NavItem'a taşınır, kaybolmaz). Rozet özel-case (registry'e zorlanmaz). Smoke: build + mobil/masaüstü nav tıklama testi. Tek commit, kolay revert. |
| **ErrorClass retry mevcut timeout/recovery ile çakışır** — Db.cs'te zaten timeout var, üstüne retry eklenince çift-bekleme veya gizli-loop | orta | orta | Mevcut `CommandTimeout=240` + recovery OKUNUR, retry onunla BİRLEŞTİRİLİR (üstüne yığılmaz). max 2 retry + backoff, her retry loglanır (sessiz değil). Önce sınıflandırıcı + log, retry ikinci adım. |
| **consolidate-sema dry-run yanlış "çakışma" raporu** → kullanıcı geçerli kaydı archive'lar | orta | düşük | dry-run mutasyonsuz; archive yalnızca açık onay + git-revert'lenebilir. "Stale ≠ archive" kuralı. |
| **Scope creep — Hermes'in tüm desenlerini cargo-cult taşıma** | orta | orta | §5 reddedilenler listesi açık; her madde "değer mi cargo-cult mu?" geçti. Telemetri/faz-2/daemon ertelendi. |

## 5. REDDEDİLEN Hermes Desenleri (cargo-cult'tan kaçınma — açık gerekçe)

| Hermes deseni | Neden BKM'ye UYMAZ |
|---|---|
| **Multi-provider / provider-rotation / failover** | BKM tek MCP-set + tek DB + tek JOKER. Provider rotasyonu için ikinci sağlayıcı yok. `should_rotate`/`should_fallback` flag'leri BKM ErrorClass'ında YER ALMAZ (yalnızca `should_retry`). |
| **Gateway / service-gated tool / API katmanı** | BKM'de dağıtık servis yok; Blazor + script doğrudan DB. Gateway = gereksiz dolaylama. |
| **Profiles (multi-user/multi-config)** | Tek kullanıcı (Fikri, CFO), tek makine. Profil sistemi anlamsız. |
| **Plugin sistemi + MCP-catalog** | Yetenekler skill/rule/agent olarak zaten genişliyor (footprint-ladder'da MCP/plugin rung'ları YOK). Plugin keşif/yükleme altyapısı over-engineering. |
| **Cron-daemon / sürekli arka-plan runner** | BKM'de daemon yok, olmamalı. Curator-check **inactivity-triggered** (handoff sırasında), cron değil — bu bilinçli BKM uyarlaması. |
| **Telegram/CLI/autocomplete çoklu-arayüz türetme (COMMAND_REGISTRY)** | BKM'nin tek "registry" ihtiyacı dashboard nav (tek arayüz). Çoklu-downstream türetme yok → registry yalnızca NavItem ölçeğinde, command-bus değil. |
| **Tam context-compression (3-katman LLM özet pipeline)** | Claude Code'un kendi `/compact` mekanizması var; ayrıca runtime-compressor portu gereksiz. Hermes'in compression FİKİRLERİ (anchor, iterative-merge) yalnızca **journal/handoff** disiplinine (WS-6) süzülür — kod-pipeline olarak DEĞİL. |

## 6. Değer / Efor Matrisi & Önceliklendirme

| WS | Değer | Efor | Tier | Öncelik | Gerekçe |
|---|---|---|---|---|---|
| **WS-1 Curator (sema+TODO decay)** | Yüksek | Orta | T2 | **1** | Fact-Force Gate'in eksik yarısı; sessiz-yanlış-rakam riskini doğrudan azaltır. Sıfır kod (YAML alanı + rule). |
| **WS-4 Delegation** | Orta | Düşük | T2 | **2** | Tek rule dosyası, düşük efor, hemen değer (agent disiplini). |
| **WS-6 Journal/handoff** | Orta | Düşük | T2 | **3** | Tek skill dosyası, mevcut handoff'u sertleştirir. |
| **WS-2 NarrowWaist** | Orta-Yüksek | Orta (riskli) | T2 | **4** | Değerli ama compact-survival riski → etiketleme-only faz; fiziksel taşıma ertelenir. |
| **WS-5 ErrorClass** | Orta-Yüksek | Yüksek (kod, 2 dil) | T3 | **5** | Gerçek değer (dashboard stabilite) ama en çok kod + çakışma riski → core'lar oturduktan sonra. |
| **WS-3 Registry-nav** | Orta | Orta (kod, nav-kırılma riski) | T3 | **6** | İzole, bağımsız; istendiğinde tek başına yapılabilir. B-75 orphan'ı çözer. |
| **WS-7 Test (ops.)** | Düşük-Orta | Düşük | T1-2 | **7** | Nice-to-have; en son veya atla. |

**Kritik yol:** WS-1 → (WS-4, WS-6 paralel, bağımsız) → WS-2 → WS-5 → WS-3 → WS-7. WS-3 ve WS-5 birbirinden ve core'lardan bağımsız (istenirse erkene alınabilir), ama kod+risk taşıdıkları için rule-only'ler oturduktan sonra önerilir.

## 7. Done Criteria (workstream başına ölçülebilir)

- [ ] **WS-1:** `sema/README.md`'de `last_verified`/`verify_after` tanımlı; en az 1 yeni/dokunulan sema kaydı bu alanları taşıyor; `semantic-layer.md`'de decay kuralı + `confidence:1.0 muaf`; `session-handoff` Adım 4.6 curator-check ekli; `TODO.md`'de `## Arşiv` + state-machine notu. Smoke: handoff çalıştır → curator-check ≥7g mantığı tetiklendi.
- [ ] **WS-4:** `agent-usage.md`'de leaf/orchestrator rol + `max_concurrent=3` + izolasyon bölümü; mevcut 4 agent leaf/orchestrator etiketli.
- [ ] **WS-6:** `session-handoff/SKILL.md`'de iterative-merge + anchor(budanmaz bölüm) + anti-thrash kuralları; aynı-gün 2. oturum testi merge yapıyor (sıfırdan değil).
- [ ] **WS-2:** `footprint-ladder.md` (veya coding-discipline bölümü) var; 7 konu-bazlı rule "on-demand/core" etiketli; `asistan-ui`/`dashboard-icerik` skill'i ilgili rule'a referans veriyor; **compact-survival bozulmadı** (rule dosyaları yerinde, smoke: `/compact` sonrası core kurallar hâlâ aktif).
- [ ] **WS-5:** `SqlErrorClassifier.cs` + `_errors.py` var; transient/fatal ayrımı unit-doğrulanmış (örn. timeout=-2→transient, syntax→fatal); `Db.cs` retry mevcut timeout ile çakışmıyor (max 2, backoff, loglu); `error-handling.md` koda referans veriyor. **dashboard build yeşil + smoke: bir sayfa açıldı.**
- [ ] **WS-3:** `NavRegistry.cs` var; sidebar + btm-nav ondan türiyor; **dashboard build yeşil**; masaüstü sidebar + mobil btm-nav tüm linkler tıklanıyor, ActiveClass/badge çalışıyor, görsel birebir (DaisyUI token korundu, hex yok).
- [ ] **WS-7 (ops.):** `test-discipline.md`'de anti-snapshot bölümü.
- [ ] Her tamamlanan WS commit'inde plan referansı: `<tip>(bkm): <WS> (plan: 12)`.
- [ ] `TODO.md` ↔ bu plan senkron (her WS bir Faz başlığı).

## 8. Rollback Planı

- **Rule/skill/doküman WS'leri (1,2,4,6,7):** saf metin değişiklik → `git revert <commit>` temiz; rule dosyaları silinmediği için compact-survival riski geri-alımda da güvenli.
- **WS-3 Registry-nav:** tek commit; kırılırsa `git revert` → eski elle-nav geri gelir. `NavRegistry.cs` silinir, MainLayout eski haline döner.
- **WS-5 ErrorClass:** `git revert` → eski inline except + mevcut timeout/recovery geri. Yeni dosyalar (`SqlErrorClassifier.cs`, `_errors.py`) silinir; Db.cs retry sarmalayıcısı çıkar. Mevcut timeout davranışı bozulmadığı için kısmi-revert güvenli.
- **WS-1 sema-decay:** yeni YAML alanları opsiyonel/geriye-uyumlu → kayıt geri-alınsa bile mevcut script'ler etkilenmez (alanı okumayan kod sorunsuz). consolidate-sema yalnızca dry-run+onay olduğu için veri kaybı riski yok.
- **DB migration / şema değişikliği YOK** → hiçbir WS'de down-script gerekmez.

## 9. Adımlar / TODO Maddeleri (sıralı, bağımlılık-işaretli)

> Her WS bağımsız teslim + kendi mini-onayı. Sıra = öncelik (§6).

1. [x] **H-01** WS-1 Curator: sema alan tanımı + decay rule + handoff curator-check + TODO arşiv + consolidate-sema skill. ✅ 16.06. (T2, bağımsız)
2. [x] **H-02** WS-4 Delegation: agent-usage leaf/orchestrator + cap. ✅ 16.06 (T2, bağımsız)
3. [x] **H-03** WS-6 Journal/handoff: iterative-merge + anchor. ✅ 16.06 (T2, bağımsız)
4. [x] **H-04** WS-2 NarrowWaist: footprint-ladder.md + rule etiketleme + skill-inject referansı. ✅ 16.06 (7 rule etiketli, 2 skill referans, CLAUDE.md tier notu; compact-survival doğrulandı: paths: yok, dosyalar yerinde). (T2)
5. [x] **H-05** WS-5 ErrorClass: SqlErrorClassifier.cs + _errors.py + Db.cs retry + generate_brief.py + error-handling.md. ✅ 16.06. Build yeşil, Python OK, smoke 200. silent-failure-hunter: auth-fatal yanlışsınıflama bulgusu DÜZELTİLDİ (18456/login-failed→fatal, C#+Python). (T3, kod)
6. [x] **H-06** WS-3 Registry-nav: NavRegistry.cs + MainLayout türetme. ✅ 16.06. Build yeşil, smoke: sidebar 11 + btm-nav 5 + 2 grup, tüm href doğru, görsel birebir (btm-nav active=primary). (T3, kod)
7. [x] **H-07** WS-7 (ops.) Test: anti-snapshot kuralı. ✅ 16.06 (test-discipline.md davranışsal-kontrat bölümü). (T1-2)
8. [ ] **H-08** Her WS sonrası `TODO.md` Faz senkronu + journal not.

> Bağımlılık özeti: H-01/02/03 birbirinden bağımsız (paralel onaylanabilir). H-04 onların kararlarına dayanır. H-05/H-06 koddur, core'lardan bağımsız ama risk nedeniyle sona. H-07 opsiyonel.

## 10. Uygulama Modeli Önerisi: AYRI onaylar (tek blok DEĞİL)

**Öneri: her workstream kendi mini-onayı + kendi commit'i ile.** Gerekçe:
- Hermes'in **deferred-invalidation** felsefesi: rule/disiplin değişimi tek seferde değil, sindirilerek. Her WS'yi kullanıcı görüp onaylasın — özellikle WS-2 (compact-survival trade-off) ve WS-3/WS-5 (kod) ayrı göz ister.
- Risk izolasyonu: WS-3 nav kırılırsa WS-1 sema-decay'i etkilemez.
- BKM commit-discipline: "bir commit = bir konu", 15-dosya eşiği — fazlı zaten zorunlu.

**Akış:** Bu planın tamamı bir kez onaylanır (yön onayı) → sonra her WS implement öncesi kısa "WS-N yapıyorum, scope şu" mini-teyidi → implement → commit (`plan: 12`) → bir sonraki WS. Tek "hepsini şimdi yap" bloğu ÖNERİLMEZ (risk birikir, review zorlaşır).

## 11. KARARLAR (AskUserQuestion 16.06)

1. **WS-2 derinliği:** Yalnızca *etiketleme + skill-inject referansı* (fiziksel taşıma faz-2'ye ertelendi). Sistem-prompt token'ı fiilen düşürme bu turda öncelik DEĞİL — compact-survival riske atılmaz.
2. **WS-1 telemetri:** sema/skill kullanım sayacı (`.usage.json` sidecar) ERTELENDİ — manuel yargı yeterli.
3. **consolidate-sema skill'i:** WS-1 içinde dry-run skill olarak YAZILIR (decay-bayrağı + dry-run rapor).
4. **WS-5 kapsamı:** Python tarafında yalnızca yüksek-frekanslı 2-3 script (`send_mail.py`, `generate_brief.py`); toplu refactor YOK (footprint-ladder).

> Not: yukarıdaki kararlar uygulama sırasında teyit edilir; her WS kendi mini-onayını alır (§10).

## 12. İlişkili

- Şablon: `plans/feature-template.md`
- Önceki planlar: `plans/11-genel-bakis-redesign.md` (dashboard nav bağlamı), `plans/03-brief-otomasyon.md` (script error-handling bağlamı)
- Etkilenen rule'lar: `.claude/rules/{semantic-layer,agent-usage,error-handling,coding-discipline,test-discipline,plan-first}.md`
- Etkilenen skill'ler: `.claude/skills/{session-handoff,sema-ogren}/SKILL.md`
- sema: `sema/README.md` + 4 YAML
- Kod: `dashboard/Components/Layout/MainLayout.razor`, `dashboard/Data/Db.cs`, `scripts/*.py`
- ADR önerisi: `docs/ADR/<NN>-hermes-lifecycle-adaptasyon.md` (WS-1 decay + WS-2 narrow-waist kararı kalıcı mimari → ADR yazılması önerilir)

## 13. Onay

- [x] Plan kullanıcıya gösterildi
- [x] Yön onayı alındı (her WS ayrıca mini-onay alacak — §10) — "tamamını planlayıp adapte edelim" 16.06
- [x] 4 scope-kararı onaylı (AskUserQuestion 16.06): WS-2 etiketleme-only · telemetri ertele · consolidate-sema yaz · WS-5 2-3 script
- [x] Onay: 16.06 Fikri — uygulama WS-1'den başlıyor (sıralı, her WS mini-teyitli)
