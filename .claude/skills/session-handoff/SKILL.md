---
name: session-handoff
description: Oturum sonu ozet yazar. docs/journal/<proje>/YYYY-MM-DD.md dosyasina yazar VE TODO.md'yi senkronlar. Multi-project repo (BKM/Belinza/YonetIQ/MCP) — hangi projede çalışıldıysa o klasöre yazar. Yazim sonunda journal+TODO'yu tek commit'te atar. Kullanici "handoff", "iyi geceler", "kaydet ve kapat" gibi ifadeler kullandiginda devreye gir.
allowed-tools: Read, Edit, Write, Bash, Grep, Glob
user-invocable: true
model: inherit
---

# Oturum Devir Skill'i (Multi-Project)

## Adim 0 — PROJE TESPITI (ZORUNLU)

1. `git status`, `git diff --name-only` ile dokunulan dosyalara bak.
2. Klasor pattern:
   - `briefings/`, `sorgular/`, `docs/0[1-9]-*.md`, `docs/journal/bkm/` → bkm
   - `docs/journal/belinza/` → belinza
   - `docs/journal/yonetiq/` → yonetiq
   - `src/`, `package.json` → _crossproject
   - `.claude/`, `CLAUDE.md`, `TODO.md` → _crossproject
3. Birden fazla proje değiştiyse: HER PROJE İÇİN AYRI journal.
4. Belirsizse kullanıcıya sor.

## Cikti Sablonu

```markdown
# Oturum Gunlugu — YYYY-MM-DD (<proje>)

## Ana Konu

## Tamamlananlar
### <Kategori>
- Madde (dosya:line)

## Build / Test Durumu

## Commit Durumu

## Yarim Kalan / Yarin'a

## Kararlar
### Reddedilenler
- ~~A~~ — sebep
- B seçildi — gerekçe

## Konuşulan ek konular
### <Konu — parked>

### Kullanıcı feedback verbatim
> "alıntı"

## Dikkat Edilmesi Gerekenler

## Yarina Baslangic Noktasi

## Yardımcı Dosyalar
```

## Adim 3 — Konusma Baglamini DERIN OKU

KRITIK: "Ne yazildi" + "ne tartisildi + nasil karar verildi". HEPSI yansitilmali:

- 3a. Parked öğeler
- 3b. Reddedilen alternatifler (NEDEN reddedildi)
- 3c. Scope creep / pivot kararları
- 3d. Kullanıcı verbatim quotes
- 3e. Domain knowledge / sözlük
- 3f. UX/UI saga'ları
- 3g. Bug fix kararları (kalıcı kural)
- 3h. İlişkili dosyalar
- 3i. "Hatırlatma" notları

Hacim eşiği: 3+ saat veya 20+ dosya → DETAYLI yaz.

## Adim 4.5 — TODO.md Senkronu (ZORUNLU)

5 zorunlu adım:

1. TODO.md'yi oku.
2. Tamamlananlari isaretle: `- [x] ~~...~~ — ✅ commit abc1234`.
3. Yeni keşfedilen işler ekle.
4. Kararları işlet (ADR/Kural/Backlog değişimi).
5. Yapilanlar ozeti: `### YYYY-MM-DD — <ana konu>` 3-5 madde.

## Adim 5 — Journal + TODO OTOMATIK commit

```bash
JOURNAL="docs/journal/$PROJ/$(date +%Y-%m-%d).md"
TODO="TODO.md"
STAGED=""

for f in "$JOURNAL" "$TODO"; do
  if ! git diff --quiet -- "$f" 2>/dev/null || git ls-files --others --exclude-standard -- "$f" | grep -q .; then
    git add "$f"
    STAGED="$STAGED $f"
  fi
done

if [ -n "$STAGED" ]; then
  git commit -m "docs($PROJ): $(date +%Y-%m-%d) handoff + TODO sync"
fi
```

Sadece bu iki dosya. `git add .` / `-A` yasak.

## Tetikleyiciler

- "iyi geceler" → otomatik
- "/handoff" → açık
- "günaydın" → ters yön: en son journal'i oku, özet ver (commit yok)

## Dikkat

1. Journal yoksa: docs/journal/<proje>/ oluştur.
2. Auto-commit SADECE journal + TODO.
3. CLAUDE.md'ye session log eklenmemeli.
4. Türkçe yaz, UTF-8.

## İlişkili Dosyalar

- `.claude/hooks/session-start.sh`
- `.claude/hooks/post-commit-journal.sh`
- `.claude/rules/commit-discipline.md`
- `docs/CONTEXT_MANAGEMENT.md`
