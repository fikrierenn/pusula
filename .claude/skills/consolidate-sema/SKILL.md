---
name: consolidate-sema
description: sema/*.yaml + TODO.md yaşam-döngüsü bakımı. Stale (yaşı dolmuş) kayıtları, dar/çakışan kayıtları ve eski TODO maddelerini DRY-RUN ile raporlar (mutasyonsuz REPORT.md); kullanıcı onaylarsa uygular. ASLA silmez — archive-only. "sema konsolide", "sema bakım", "curator", "stale kayıtları göster", "/consolidate-sema" denildiğinde veya curator-check derin tarama isteyince devreye gir.
allowed-tools: Read, Edit, Write, Bash, Grep, Glob
user-invocable: true
model: inherit
---

# consolidate-sema — sema/TODO Yaşam-Döngüsü Bakımı (Hermes curator uyarlaması)

BKM sema katmanı + TODO zamanla birikir: bayatlamış gerçek, dar/çakışan kayıt, eski açık madde. Bu skill onları **dry-run** ile rapor eder; kullanıcı onayıyla archive/birleştirme uygular. ECC continuous-learning + Hermes curator (`curator.py`) deseninin BKM uyarlaması. Detay kural: `.claude/rules/semantic-layer.md` § Decay.

## Temel İlkeler (Hermes hard-rule uyarlaması)
- **ASLA silme → archive.** Maksimum yıkıcı aksiyon = arşive taşıma (git history zaten korur). Stale kayıt SİLİNMEZ.
- **Stale = bayrak, otomatik aksiyon değil.** Her archive/birleştirme **kullanıcı onayı** ister.
- **counter'ı consolidation atlamak için kullanma** — telemetri yok (plan-12 ertelendi); karar içerik-temelli (çakışma/bayatlık), kullanım-sayısı değil.
- **confidence:1.0 MUAF** (kalıcı PK/FK/ehTip — pinned eşdeğeri, hiç dokunma).
- **dry-run varsayılan.** Önce REPORT.md, sonra onay, sonra uygula.

## Mod 1 — DRY-RUN (varsayılan)

### Adım 1 — Stale tarama
sema/*.yaml içinde `last_verified + ttl_days < bugün` olan kayıtlar (confidence:1.0 hariç). ttl yoksa confidence'tan türet (`sema/README.md` § Decay). Liste: `id` · `last_verified` · gün-aşımı · confidence · `note` özeti.

### Adım 2 — Dar/çakışan tarama
- **Prefix-cluster:** aynı domain'i paylaşan dar kayıtlar (örn. çok sayıda `joker-*` köprü tek umbrella'ya sığabilir mi).
- **Çakışma:** aynı `from→to` veya aynı gerçeği iki YAML'da anlatan kayıtlar (tek-doğruluk-kaynağı ihlali).
- **Süperseded:** `note: süperseded` ama hâlâ duran kayıtlar.

### Adım 3 — Eski TODO tarama
TODO.md açık `[ ]` maddeleri: ≥30 gün dokunulmamış (tarih damgası / ilgili commit yokluğu). Aday: arşiv veya "hâlâ geçerli mi?" doğrulama.

### Adım 4 — REPORT.md yaz (mutasyonsuz)
`docs/curator/REPORT-YYYY-MM-DD.md`:
```markdown
# Curator Dry-Run — YYYY-MM-DD
## Stale sema (N)
| id | last_verified | aşım(gün) | öneri |
## Dar/çakışan (N)
| id'ler | tip | önerilen aksiyon (birleştir→umbrella / archive süperseded) |
## Eski TODO (N)
| madde | yaş | öneri (doğrula / arşiv) |
## Önerilen aksiyonlar (onay bekliyor)
- [ ] ...
```
**Dosya yazar, sema/TODO'ya DOKUNMAZ.** Kullanıcıya özet göster.

## Mod 2 — UYGULA (yalnızca açık onay sonrası)
Kullanıcı REPORT'tan aksiyon seçince:
- **Stale yeniden-doğrula:** canlı sorgu → `last_verified` bugüne çek (sema-ogren). Çürürse düşür/sil-değil-not.
- **Birleştir:** dar kayıtları umbrella kayda taşı; eskileri `note: "süperseded by <id>"` + (onayla) arşiv bölümüne.
- **Archive:** sema kaydı → ilgili YAML'da `## archive` bölümü VEYA TODO maddesi → `## Arşiv`. **Silme yok.**
- Her uygulama tek commit (`chore(bkm): sema/TODO curator bakım (plan: 12)`), önce git-status temiz olsun (revert kolaylığı).

## Tetik
- "/consolidate-sema", "sema bakım", "stale göster", "curator derin tarama".
- `session-handoff` Adım 4.6 curator-check derin konsolidasyon önerince.

## İlişkili
- `.claude/rules/semantic-layer.md` § Decay & Curator-check
- `sema/README.md` § Yaşlanma/Decay
- `.claude/skills/sema-ogren/SKILL.md` — kayıt yazımı + çelişki kuralı
- `.claude/skills/session-handoff/SKILL.md` — Adım 4.6 (hafif curator-check)
