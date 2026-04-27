# Bağlam Yönetimi Anayasası

_Multi-project SQL Server MCP repo'su için bağlam yönetimi ilkeleri. Atlasops + claude-context-template'den adapte._

## Problem Tanımı

Büyüyen projelerde yaygın bağlam çöküşü belirtileri:

| Belirti | Sebep |
|---|---|
| "Dün konuştuğumuz karar hatırlanmıyor" | Kararlar CLAUDE.md'de değil, konuşma geçmişinde kaldı — `/compact` yedi |
| "Uncommitted dosyalar birikiyor" | Oturum sonu commit disiplini yok, çoklu feature paralel |
| "CLAUDE.md her gün şişiyor" | Session journal CLAUDE.md'ye yazılıyor — yanlış yer |
| "Sub-agent proje kurallarını bilmiyor" | Path-scoped rule'lar kapsamda değil |
| "`/compact` sonrası kural unutuldu" | Path-scoped rule'lar compact sonrası kayıp |

## Tasarım İlkeleri

### İlke 1 — Üç Katman Ayrımı

| Katman | Nerede | Ne yazılır |
|---|---|---|
| Kimlik | `CLAUDE.md` | Proje tanımı, stack, değişmez kurallar, dosya konvansiyonları |
| Kurallar | `.claude/rules/*.md` | Davranış kuralları, konu başına bölünmüş |
| Süreç | `TODO.md` + `docs/ADR/` + `docs/journal/<proje>/` | Planlar, geçmiş kararlar, oturum notları |

KURAL: Aynı bilgi iki yerde durmaz.

### İlke 2 — 200 Satır Eşiği

`CLAUDE.md` her zaman 200 satır altında. Bir `.claude/rules/*.md` dosyası da 200 satır altında.

### İlke 3 — Session Journal CLAUDE.md'de Yaşamaz

"Bu oturumda olanlar" yanlış yer. Alternatifler:
- `docs/journal/<proje>/YYYY-MM-DD.md` (git'te, tarih bazlı)
- Auto-memory (makine-yerel)

CLAUDE.md'de geçmiş tarih YOK. Sadece bugün geçerli kurallar.

### İlke 4 — 15 Dosya Eşiği

Uncommitted > 15 → yeni iş yasak, önce commit-split.

### İlke 5 — 3 Paralel Özellik Eşiği

Aynı anda 3'ten fazla in-flight feature olmaz.

### İlke 6 — Spec → Plan → Execute

3+ dosyaya dokunacak iş:
1. Kullanıcıya AskUserQuestion ile tanım
2. TODO.md'ye plan
3. Sonra koda

"Hızlıca şunu yap" doğrudan koda başlamak → scope explosion.

### İlke 7 — Karar Kalıcılığı

- Büyük mimari seçim → `docs/ADR/NNN-*.md`
- Küçük konvansiyon → `.claude/rules/<konu>.md`
- Bir seferlik iş → `TODO.md`

### İlke 8 — Multi-Project Ayrımı

Bu repo birden fazla projeye köprü kuruyor. Her projenin journal/TODO satırları kendi başlığı altında.

- `docs/journal/bkm/` — BKM Kitap
- `docs/journal/belinza/` — Belinza
- `docs/journal/yonetiq/` — YonetIQ
- `docs/journal/_crossproject/` — MCP server kodu, multi-proje işler

Belirsiz oturumlarda `_crossproject/`. Çoklu proje değiştiren oturum: HER PROJE İÇİN AYRI journal yaz.

## Oturum Disiplini

### Oturum Başlangıcı

Otomatik (SessionStart hook): git log + TODO özet + uncommitted sayısı + tüm projelerin son journal'ı.

Elle:
- `/memory` ile auto-memory gözden geçir
- Uncommitted > 15 → `/commit-split` öncelik

### Oturum Ortası (her 30-45 dk)

- `/context` ile kullanım kontrol — %60+ ise `/compact` planı
- Task değişti → `/compact <özet>` veya `/clear`
- Karar çıktı → ADR'ye veya rules/'a yaz

### Oturum Sonu (son 5 dk)

Zorunlu 3 adım:
1. `/handoff` skill → `docs/journal/<proje>/YYYY-MM-DD.md`
2. Commit kontrol — bu oturumun işini commit et
3. TODO.md güncelle

## Bağlam Korunumu

### `/compact` ne zaman
- `/context` %60+, aynı task'a devam.
- Her zaman focus: `/compact focus on X; drop Y`.

### `/clear` ne zaman
- Task tamamen değişti.
- Claude poisoned (aynı yanlışa düşüyor).
- Uzun oturum sonrası yeni session.

### Compact sonrası hayatta kalan/kalmayan

| Veri | Compact sonrası |
|---|---|
| Root CLAUDE.md | ✅ Re-inject |
| `.claude/rules/*.md` (paths yok) | ✅ Re-inject |
| `.claude/rules/*.md` (paths: scoped) | ❌ Kayıp |
| Auto-memory | ✅ Re-inject |
| Konuşma geçmişi | ❌ Özetlenir |

KURAL: Kritik kurallar `paths:` KULLANMADAN yaz.

## Git Disiplini

- Branch-per-ask: Her talep = bir branch.
- Save-point commit: Test yeşil = hemen commit.
- 15 eşiği: Aşıldı → commit-split.
- Kullanıcı açıkça istemeden commit yok.
- Multi-project repo: scope = proje adı (`feat(bkm):`, `chore(mcp):`).

## Eşikler (uyarı sinyalleri)

| Sinyal | Aksiyon |
|---|---|
| CLAUDE.md > 200 satır | `.claude/rules/`'a split |
| Uncommitted > 15 | commit-splitter |
| Aynı hatayı 2. kez | Rule / skill'e yaz |
| 3+ paralel feature | Biri bitene kadar yeni başlatma |
| 30 gün önceki TODO | Ya yap ya sil |
| `/compact` sonrası kritik kural unutuldu | O kuralı `.claude/rules/`'a taşı (`paths:` yok) |
| Proje karışmış commit | commit-splitter ile böl |

## Mental Model

Claude = "kıdemli ama yönlendirme bekleyen yazılımcı".
- Mimari kararı sen verirsin.
- Uygulamayı o çıkarır.
- Her önemli değişiklik öncesi onay.
- "Bitti" demeden önce verify (hook zorluyor).

## Kaynaklar

- https://docs.claude.com/en/docs/claude-code/memory
- https://docs.claude.com/en/docs/claude-code/sub-agents
- https://docs.claude.com/en/docs/claude-code/skills
- https://docs.claude.com/en/docs/claude-code/hooks
- Atlasops .claude/ yapısı + claude-context-template
