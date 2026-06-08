# Oturum Belleği Disiplini

_Bağlam yönetimi anayasasının pratik kuralları. Detay: `docs/CONTEXT_MANAGEMENT.md`._

## Katmanlar — Nerede Ne Yazılır

| Bilgi Tipi | Hedef |
|---|---|
| Proje kimliği (değişmez) | `CLAUDE.md` |
| Davranış kuralı (kalıcı) | `.claude/rules/<konu>.md` |
| Aktif plan / backlog | `TODO.md` |
| Büyük mimari karar | `docs/ADR/NNN-<slug>.md` |
| Oturum notu / günlük | `docs/journal/YYYY-MM-DD.md` |
| Tek seferlik scratch | auto-memory (machine-local) |

**Aynı bilgi iki yerde yaşamaz.**

## Oturum Başı Ritüeli

Otomatik (SessionStart hook): git log + TODO + uncommitted + son journal.

Elle yapılabilecek:
- `/memory` ile auto-memory temizle (stale 30+ gün)
- Uncommitted > 15 ise önce `/commit-split` veya commit-splitter subagent

## Oturum Sonu Ritüeli

1. **`/handoff` skill** → `docs/journal/YYYY-MM-DD.md`
2. **Commit kontrol** — bu oturumun işini commit et
3. **TODO.md güncelle**

## CLAUDE.md Bakımı

- **200 satır altı** her zaman.
- Session log **asla** CLAUDE.md'de. Journal'a.
- Stale karar / geçersiz talimat fark edersen: dosyadan sil, gerekirse ADR'ye "superseded" notu.
- Kullanıcı yeni bir direktif verirse **önce dosyaya yaz, sonra uygula**.

## `/compact` vs `/clear`

- **`/compact <focus>`** — aynı task, context şişti.
- **`/clear`** — task tamamen değişti veya poisoned.
- **`/resume`** — aynı gün içi ara sonrası.

Compact sonrası **path-scoped rule'lar kayıp** — kritik kurallara `paths:` EKLEME.

## Sub-agent Prompt Disiplini

```
Görev: <net, tek paragraf>
Scope: <dosya listesi / modül>
YAPMAYACAKLARIN: Scope dışı dokunma. Fark ettiğin sorunu raporla, çözme.
Done tanımı: <ne dönünce bitmiş sayılır>
Raporla: <istenen çıktı format>
```

## Eşikler — Uyarı Sinyalleri

| Sinyal | Aksiyon |
|---|---|
| CLAUDE.md > 200 satır | Split to `.claude/rules/` |
| Uncommitted > 15 | Commit-split zorunlu |
| Aynı hatayı 2. kez | Rule/skill yaz |
| 3+ paralel feature | Biri bitene kadar yeni başlatma |
| 30+ gün eski TODO | Ya yap ya sil |
| Compact sonrası kural unutuldu | Rule'u `paths` olmadan yaz |

## Mental Model

Claude = **kıdemli ama yönlendirme bekleyen yazılımcı**.
- Mimari sen
- Uygulama o
- Onay her önemli değişiklikte
- Verify "bitti" demeden önce (hook zorluyor)
