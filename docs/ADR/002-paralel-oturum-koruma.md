# ADR-002 — Paralel Oturum Koruma

## Durum

`Kabul edildi (minimum kapsam — implementasyon C-14 ile ertelendi)`

## Tarih

2026-04-27

## Proje

`crossproject`

## Bağlam

27.04.2026 oturumunda gerçek bir paralel-oturum vakası yaşandı:

- **Oturum A** (Cowork): atlasops session/memory disiplinini repo'ya adapte etti (`.claude/`, journal, TODO.md ilk yazımı, B-01/03/04 fix'leri).
- **Oturum B** (paralel, başka Claude penceresi): MCP CWD bug'ını teşhis etti, `claude_desktop_config.FIXED.json` + `fix-mcp-config.{bat,ps1}` yazdı, BKM Mayıs %50 kampanya tahminini SCOPE'ladı, `docs/journal/bkm/2026-04-27.md`'ye yazdı, **TODO.md'ye "Oturum 3" başlığını ekledi**.

Vaka **şanslı** geçti çünkü:
- A oturum `docs/journal/_crossproject/2026-04-27.md` yazdı (cross-project scope)
- B oturum `docs/journal/bkm/2026-04-27.md` yazdı (bkm scope)
- ADR-001 multi-project ayrımı sayesinde **journal dosyaları çakışmadı**.

Ama riskler net:

1. **TODO.md ortak** — Race condition. Son yazan kazanır, diğerinin değişikliği kaybolur. Bu sefer A oturumu sabah yazdı, B oturumu sonra üzerine yazdı, A oturumu handoff'ta git status'tan B'nin yazımını gördü. Aynı anda iki oturum Edit yapsaydı, biri kaybolurdu.
2. **Aynı projede paralel oturum** — İki oturum aynı `docs/journal/bkm/2026-04-27.md`'i yazsa son commit kazanır. `## Oturum 2` ile `## Oturum 3` çakışabilir.
3. **Handoff commit yarışı** — `git commit` lock'lanmıyor, race var. İki handoff aynı anda → biri "your branch is ahead" hatası alır, fast-forward conflict.
4. **Hook tek script** — `SessionStart` hook her oturumda çalışır, dosyalara erişir, lock yok.

ADR-001 (multi-project) bu sorunun **yarısını** çözüyor — proje ayrımı sayesinde farklı proje paralel oturumları çakışmaz. Ama:
- TODO.md ortak
- Aynı proje paralel hâlâ açık
- Commit yarışı hâlâ açık

## Karar

İki katmanlı çözüm:

### 1. Minimum koruma (HEMEN — bu ADR ile kararlaştırıldı, implementasyonu C-14)

**a) Lock dosyası mekanizması:**
- Oturum başında `.claude/locks/<session-id>.lock` yaratılır.
- `<session-id>` = `YYYYMMDD-HHMMSS-<random4>` (timestamp + 4-digit random).
- Lock dosyası içeriği: `{ "started_at": "...", "pid": ..., "cwd": "..." }`.
- Oturum sonu (handoff) lock silinir.
- Stale lock detection: 4 saatten eski lock'lar otomatik temizlenir (oturum unutulmuş).

**b) Hook uyarısı:**
- `session-start.sh` mevcut lock'ları sayar.
- 1+ aktif lock varsa stderr'a uyarı: `"DIKKAT: <N> aktif paralel oturum tespit edildi. TODO.md / aynı-proje journal yazımı çakışabilir. Önce git pull/status kontrol et."`
- Manuel disiplin, otomatik blok yok (üretkenliği kesmesin).

**c) Pre-handoff git check:**
- `session-handoff` skill commit'ten önce `git fetch` (varsa) + son local commit hash'ini akılda tut.
- TODO.md veya journal dosyasını yazmadan önce `git log -1` ile başkasının commit attığını tespit et.
- Çakışma tespit edilirse kullanıcıya: `"Başka oturum commit attı (hash: X). Üzerine yazmak (overwrite) / merge (manuel) / iptal?"`

**d) TODO.md split (opsiyonel C-15):**
- Tek `TODO.md` yerine `TODO/bkm.md` + `TODO/_crossproject.md` + `TODO/belinza.md` + `TODO/yonetiq.md`.
- Aynı projede paralel oturum hâlâ çakışabilir, ama farklı proje çakışmaz.

### 2. SaaS-grade (ileri — başka oturuma)

**Branch-per-session:**
- Her oturum otomatik kendi feature branch'ında çalışır: `session/YYYY-MM-DD_<id>`.
- Handoff sonu main'e auto-merge (squash veya rebase).
- Conflict resolve git'in kendi mekanizmasıyla.
- Trade-off: git geçmişi karmaşıklaşır, kullanıcı git workflow'una hâkim olmalı.

**Şimdilik 2'ye gerek yok** — multi-project + lock + git check kombinasyonu kullanıcı yükünü yönetilebilir tutuyor.

## Sebepler

- 27.04 vakası multi-project'in yarısını çözdüğünü kanıtladı, eksiklikler net.
- Lock dosyası lightweight — git workflow'u bozmuyor, gerçek çakışmayı ölçüyor.
- Pre-handoff git check — uyarıcı, otomatik blok değil. Kullanıcı yetkisi korunur.
- Branch-per-session aşırı — single-user repo'da overengineering.

## Alternatifler (Reddedilenler)

### A: Tam blok (lock varsa yeni oturum açılamaz)
**Reddetme sebebi:** Stale lock unutulduysa kullanıcı kilitli kalır. "Manuel temizle" UX kötü.

### B: Database-backed locking (Redis vs.)
**Reddetme sebebi:** Bu repo SaaS değil. Local file system yeterli. Backend sürdürmek operasyonel yük.

### C: Sadece Git'e güven (no lock)
**Reddetme sebebi:** Race condition gerçek — TODO.md aynı anda Edit'lenince git lock değil dosya seviyesinde sorun. Git pre-commit aşamasından önce edit conflict.

### D: Branch-per-session direkt
**Reddetme sebebi:** Single-user repo'da overengineering. 2026 sonunda multi-user / SaaS-grade gerekirse buraya gel.

## Sonuçlar

### Olumlu
- Paralel oturum kullanılabilir (aynı bilgisayarda iki Claude penceresi normaldir).
- Disiplin kullanıcıya açık ve uyarıcı.
- Multi-project ayrımı + lock kombinasyonu %90+ vakayı çözüyor.

### Olumsuz / Risk
- Lock dosyası unutulursa stale durum (4 saat TTL ile mitige).
- Pre-handoff git check yanlış pozitif olabilir (başkasının commit'i kabul edilebilir, çakışma olmayabilir).
- Implementation gecikirse (C-14) bu risk açık kalır.

### Bilinmeyen
- Pratikte paralel oturum ne sıklıkta? Vaka bazlı ölçülmedi. 27.04'te ilk oluştu.
- Stale lock TTL doğru mu (4 saat)? Daha kısa olsa unutulan oturum bloklamaz, daha uzunsa stale lock kullanıcıyı yanıltır.

## Uygulama

- [x] ADR yazıldı (bu dosya).
- [ ] **C-14**: `session-start.sh` hook'a lock yaratma + uyarı.
- [ ] **C-14**: `session-handoff` skill'a lock silme + pre-commit git check.
- [ ] **C-14**: `.claude/locks/` klasörü ve `.gitignore`'a ekle.
- [ ] **C-14**: Stale lock cleanup script (4 saatten eski silinir).
- [ ] **C-15** (opsiyonel): TODO.md split per-project.
- [ ] Test: İki paralel oturum aç, lock + uyarı + handoff sequence'i doğrula.

## İlişkili Dosyalar

- `.claude/hooks/session-start.sh` — Lock yaratma + uyarı eklenecek
- `.claude/skills/session-handoff/SKILL.md` — Lock silme + git check eklenecek
- `.claude/rules/session-protocol.md` — Lock disiplini kuralı eklenecek
- `.gitignore` — `.claude/locks/` ekle
- ADR-001 — Multi-project journal yapısı (bu ADR'nin temeli)

## Referanslar

- Vaka: `docs/journal/_crossproject/2026-04-27.md` (Oturum 1+2 ben) + `docs/journal/bkm/2026-04-27.md` (Oturum 3 paralel)
- Konuşma: kullanıcı verbatim — `"aynı anda iki oturum olabilir ama sistem ona göre olmalı"`
- TODO ID: `C-14` (implementasyon), `C-15` (TODO.md split opsiyonel)
