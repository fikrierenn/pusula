# Bağlam Yönetimi Anayasası
_Proje-bağımsız referans. Her yeni projede aynen kopyalanır._

## Problem Tanımı

Büyüyen projelerde yaygın bağlam çöküşü belirtileri:

| Belirti | Sebep |
|---|---|
| "Dün konuştuğumuz karar hatırlanmıyor" | Kararlar CLAUDE.md'de değil, konuşma geçmişinde kaldı — `/compact` yedi |
| "Uncommitted dosyalar birikiyor" | Oturum sonu commit disiplini yok, çoklu feature paralel |
| "CLAUDE.md her gün şişiyor" | Session journal CLAUDE.md'ye yazılıyor — yanlış yer |
| "Sub-agent proje kurallarını bilmiyor" | Sub-agent CLAUDE.md görüyor ama skill'leri görmüyor; path-scoped rule'lar kapsamda değil |
| "`/compact` sonrası kural unutuldu" | Path-scoped rule'lar compact sonrası kayıp |

## Tasarım İlkeleri (anayasa)

### İlke 1 — Üç Katman Ayrımı

| Katman | Nerede | Ne yazılır |
|---|---|---|
| **Kimlik** | `CLAUDE.md` | Proje tanımı, stack, değişmez kurallar, dosya konvansiyonları |
| **Kurallar** | `.claude/rules/*.md` | Davranış kuralları, konu başına bölünmüş |
| **Süreç** | `TODO.md` + `docs/ADR/` + `docs/journal/` | Planlar, geçmiş kararlar, oturum notları |

**KURAL:** Aynı bilgi iki yerde durmaz. Yer seçimi:
- Her oturumda mı gerekli? → CLAUDE.md
- Belli bir konuda iş yapılırken mi? → `.claude/rules/<konu>.md`
- Tarihli, geçici mi? → `docs/journal/` veya `docs/ADR/`

### İlke 2 — 200 Satır Eşiği
- `CLAUDE.md` her zaman **200 satır altında**.
- Bir `.claude/rules/*.md` dosyası da 200 satır altında — aşarsa konu bölünür.

### İlke 3 — Session Journal CLAUDE.md'de Yaşamaz
"Bu oturumda olanlar" yanlış yer. Alternatifler:
- `docs/journal/YYYY-MM-DD.md` (git'te, tarih bazlı)
- Auto-memory (makine-yerel)
- `/export` ile Markdown dump

**CLAUDE.md'de geçmiş tarih YOK. Sadece bugün geçerli kurallar.**

### İlke 4 — 15 Dosya Eşiği
Uncommitted > 15 → yeni iş **yasak**, önce commit-split.

### İlke 5 — 3 Paralel Özellik Eşiği
Aynı anda 3'ten fazla in-flight feature olmaz. Her oturumda tek öncelik.

### İlke 6 — Spec → Plan → Execute
3+ dosyaya dokunacak iş:
1. Kullanıcıya `AskUserQuestion` ile tanım
2. TODO.md'ye plan
3. Sonra koda

"Hızlıca şunu yap" doğrudan koda başlamak → scope explosion.

### İlke 7 — Karar Kalıcılığı
Her tartışmanın sonu bir karar ve kalıcı yer bulmalı:
- Büyük mimari seçim → `docs/ADR/NNN-*.md`
- Küçük konvansiyon → `.claude/rules/<konu>.md`
- Bir seferlik iş → `TODO.md`

## Oturum Disiplini

### Oturum Başlangıcı
**Otomatik** (SessionStart hook): git log + TODO özet + uncommitted sayısı + son journal.

**Elle:**
- `/memory` ile auto-memory gözden geçir
- Uncommitted > 15 → `/commit-split` öncelik

### Oturum Ortası (her 30-45 dk)
- `/context` ile kullanım kontrol — %60+ ise `/compact` planı
- Task değişti → `/compact <özet>` veya `/clear` (tam pivot)
- Karar çıktı → ADR'ye veya rules/'a yaz

### Oturum Sonu (son 5 dk)
Zorunlu 3 adım:
1. **`/handoff` skill** → `docs/journal/YYYY-MM-DD.md`
2. **Commit kontrol** — bu oturumun işini commit et
3. **TODO.md güncelle** — biten çıkar, yeni açılan ekle

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
| `.claude/rules/*.md` (paths: scoped) | ❌ Kayıp (dosya tekrar okunana kadar) |
| Nested CLAUDE.md | ❌ Kayıp |
| Auto-memory | ✅ Re-inject |
| Invoked skill body | ⚠️ 5K/skill, 25K toplam |
| Konuşma geçmişi | ❌ Özetlenir |

**Kural:** Kritik kurallar **`paths:` KULLANMADAN** yaz. Path-scoped sadece kod konvansiyonları.

## Agent Orkestrasyonu (Ralph pattern)

**Primary context = scheduler.** Büyük iş subagent'a spawn edilir, özet alınır, bir sonrakine geçilir.

| İş | Primary mi, subagent mi? |
|---|---|
| Kod okuma, grep, file listing | Primary |
| Büyük tool-result (tüm SP'leri tara, XSS audit 50 dosya) | subagent |
| Araştırma (web fetch) | subagent |
| Hızlı edit | Primary |
| Uzun refactor | subagent (`isolation: worktree`) |

**Prompt disiplini — subagent'a:**
```
Görev: <net, tek paragraf>
Scope: <dosya listesi>
YAPMAYACAKLARIN: Scope dışına çıkma.
Done tanımı: <ne dönünce bitmiş>
Raporla: <çıktı format>
```

## Git Disiplini

- **Branch-per-ask:** Her talep = bir branch. İş bitince squash-merge.
- **Save-point commit:** Test yeşil = hemen commit (yarım olsa bile, "WIP:" prefix).
- **15 eşiği:** Aşıldı → commit-split.
- **Kullanıcı açıkça istemeden commit yok.**
- **Zararlı komutlar açık onay ister:** `git push --force`, `git reset --hard`, `git clean -fd`, `git rebase -i`, `git checkout .`.

## Eşikler (uyarı sinyalleri)

| Sinyal | Aksiyon |
|---|---|
| CLAUDE.md > 200 satır | `.claude/rules/`'a split |
| Uncommitted > 15 | `/commit-splitter` |
| Aynı hatayı 2. kez yapıyorum | Rule / skill'e yaz |
| 3+ paralel feature | Biri bitene kadar yeni başlatma |
| 30 gün önceki TODO | Ya yap ya sil |
| `/compact` sonrası kritik kural unutuldu | O kuralı `.claude/rules/`'a taşı (`paths:` **yok**) |

## Mental Model

Claude = **"kıdemli ama yönlendirme bekleyen yazılımcı"**.
- Mimari kararı sen verirsin.
- Uygulamayı o çıkarır.
- Her önemli değişiklik öncesi onay.
- "Bitti" demeden önce verify (hook zorluyor).

## Kaynaklar

### Claude Code resmi dokümanları
- https://docs.claude.com/en/docs/claude-code/memory
- https://docs.claude.com/en/docs/claude-code/sub-agents
- https://docs.claude.com/en/docs/claude-code/skills
- https://docs.claude.com/en/docs/claude-code/hooks
- https://docs.claude.com/en/docs/claude-code/context-window

### Workflow makaleleri
- [Addy Osmani — AI coding workflow 2026](https://addyosmani.com/blog/ai-coding-workflow/)
- [Geoffrey Huntley — Ralph pattern](https://ghuntley.com/ralph/)
- [Rick Hightower — Stop Stuffing Everything](https://medium.com/@richardhightower/claude-code-rules-stop-stuffing-everything-into-one-claude-md-0b3732bca433)
- [claudefa.st — Rules Directory](https://claudefa.st/blog/guide/mechanics/rules-directory)
