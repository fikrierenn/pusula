---
name: session-handoff
description: Oturum sonu ozet yazar. Bugun yapilanlari, build durumunu, yarim kalan islari, yarina baslangic noktasini docs/journal/YYYY-MM-DD.md dosyasina yazar VE TODO.md'yi senkronlar (tamamlananlari isaretler, yeni kesfedilen islari ekler). Yazim sonunda journal+TODO'yu tek commit'te atar. Kullanici "handoff", "oturum sonu", "iyi geceler", "kaydet ve kapat", "gunaydin ozet" gibi ifadeler kullandiginda veya /handoff calistirildiginda devreye gir.
allowed-tools: Read, Edit, Write, Bash, Grep, Glob
user-invocable: true
model: inherit
---

# Oturum Devir Skill'i

## Amac
Her oturum sonunda gun icinde olanlari kalici bir journal dosyasina yazar ve journal'i otomatik commit eder.

## Kaynak Dosya

`docs/journal/YYYY-MM-DD.md` — bugunun gunlugu.

## Cikti Sablonu

```markdown
# Oturum Gunlugu — YYYY-MM-DD

## Ana Konu
<2-4 cumle>

## Tamamlananlar
### <Kategori 1>
- Madde (dosya:line)

## Build / Test Durumu
- Build: yesil / kirmizi / calistirilmadi
- Test: X yesil, Y kirmizi
- Smoke test: yapildi / yapilmadi

## Commit Durumu
- Uncommitted: N
- Yeni commit'ler: ...

## Yarim Kalan / Yarin'a
### Üst öncelik
- ...

## Kararlar
### Reddedilenler
- ~~A~~ — sebep
- B seçildi — gerekçe

## Konuşulan ek konular (parked / context)
### <Konu — parked: neden>

### Kullanıcı feedback verbatim
> "alıntı" — konteks

## Dikkat Edilmesi Gerekenler

## Yarina Baslangic Noktasi
1. ...

## Yardımcı Dosyalar
### Yeni / Değişen
- `path/to/file` — ne değişti
```

## Adim Adim

### Adim 1 — Bilgi Topla
```bash
date +%Y-%m-%d
git status --porcelain | wc -l
git log --since=midnight --oneline
git diff --name-only HEAD --diff-filter=AM
```

### Adim 2 — Journal Kontrol
```bash
JOURNAL="docs/journal/$(date +%Y-%m-%d).md"
mkdir -p docs/journal
```

### Adim 3 — Konusma Baglamini DERIN OKU

KRİTİK: "Ne yazildi" + "ne tartisildi + nasil karar verildi".

- **3a. Parked öğeler** — "büyüdükçe", "şimdilik gerek yok"
- **3b. Reddedilen alternatifler** — A/B/C tartışıldı, hangi seçildi NEDEN
- **3c. Scope creep / pivot kararları**
- **3d. Kullanıcı verbatim quotes**
- **3e. Domain knowledge / sözlük**
- **3f. UX/UI saga'ları**
- **3g. Bug fix kararları (kalıcı kural)**
- **3h. İlişkili dosyalar (yeni + değişen)**
- **3i. "Hatırlatma" / "Dikkat" notları**

Hacim eşiği: 3+ saat veya 20+ dosya değişti → DETAYLI yaz.

### Adim 4 — Journal Dosyasina Yaz
- Dosya yoksa: şablondan yeni.
- Dosya varsa: `---` + `## Oturum 2`.

### Adim 4.5 — TODO.md Senkronu (ZORUNLU)

5 zorunlu adım:

1. TODO.md'yi oku.
2. Tamamlananları işaretle: `- [x] ~~...~~ — ✅ commit abc1234`.
3. Yeni keşfedilen işler ekle (Faz 1/2/3/Backlog'a, ID süreklilik).
4. Kararları işlet:
   - Mimari → "ADR yaz: <konu>" maddesi
   - Kural → ".claude/rules/<konu>.md yaz" maddesi
   - Backlog değişimi → sıra güncelle
5. Yapılanlar özeti: `### YYYY-MM-DD — <ana konu>` 3-5 madde.

Önemli kısıtlar:
- TODO.md formatı değişmesin (Faz 0/1/2/3 + Backlog).
- 400+ satır → bildirim ver, eski kayıtlar arşive.
- Aynı konu iki yerde olmasın.

### Adim 5 — Journal + TODO OTOMATIK commit

```bash
JOURNAL="docs/journal/$(date +%Y-%m-%d).md"
TODO="TODO.md"
STAGED=""

for f in "$JOURNAL" "$TODO"; do
  if ! git diff --quiet -- "$f" 2>/dev/null || git ls-files --others --exclude-standard -- "$f" | grep -q .; then
    git add "$f"
    STAGED="$STAGED $f"
  fi
done

if [ -n "$STAGED" ]; then
  git commit -m "docs: $(date +%Y-%m-%d) handoff + TODO sync"
fi
```

Sadece bu iki dosya. `git add .` / `-A` yasak.

### Adim 6 — Ozet Goster

```
Oturum kaydedildi: docs/journal/2026-06-03.md
- Tamamlanan: 4 madde
- Yarım kalan: 2 madde
- Commit: abc1234 docs: 2026-06-03 handoff + TODO sync
- Uncommitted: N dosya (15 eşiğin altında, iyi)
- Yarına başlangıç: <ilk adım>
```

## Tetikleyiciler

- "iyi geceler" → otomatik
- "/handoff" → açık
- "devam edeceğiz" → kaydet
- "günaydın" → ters yön: en son journal'i oku ve "nerede kaldık?" özet (commit yok)

## Dikkat

1. Hiç journal yoksa: docs/journal/ oluştur.
2. Auto-commit SADECE journal + TODO.
3. Başka dosya uncommitted ise dokunma.
4. CLAUDE.md'ye session log eklenmemeli.
5. Aynı gün ikinci çağrı: `## Oturum 2` ekle.
6. Türkçe yaz, UTF-8.

## İlişkili Dosyalar

- `.claude/hooks/session-start.sh`
- `.claude/hooks/post-commit-journal.sh`
- `.claude/rules/commit-discipline.md`
- `docs/CONTEXT_MANAGEMENT.md`
