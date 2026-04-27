---
name: session-handoff
description: Oturum sonu ozet yazar. docs/journal/<proje>/YYYY-MM-DD.md dosyasina yazar VE TODO.md'yi senkronlar. Multi-project repo (BKM/Belinza/YonetIQ/MCP) â€” hangi projede Ã§alÄ±ÅŸÄ±ldÄ±ysa o klasÃ¶re yazar. Yazim sonunda journal+TODO'yu tek commit'te atar. Kullanici "handoff", "iyi geceler", "kaydet ve kapat" gibi ifadeler kullandiginda devreye gir.
allowed-tools: Read, Edit, Write, Bash, Grep, Glob
user-invocable: true
model: inherit
---

# Oturum Devir Skill'i (Multi-Project)

## Adim 0 â€” PROJE TESPITI (ZORUNLU)

1. `git status`, `git diff --name-only` ile dokunulan dosyalara bak.
2. Klasor pattern:
   - `briefings/`, `sorgular/`, `docs/0[1-9]-*.md`, `docs/journal/bkm/` â†’ bkm
   - `docs/journal/belinza/` â†’ belinza
   - `docs/journal/yonetiq/` â†’ yonetiq
   - `src/`, `package.json` â†’ _crossproject
   - `.claude/`, `CLAUDE.md`, `TODO.md` â†’ _crossproject
3. Birden fazla proje deÄŸiÅŸtiyse: HER PROJE Ä°Ã‡Ä°N AYRI journal.
4. Belirsizse kullanÄ±cÄ±ya sor.

## Cikti Sablonu

```markdown
# Oturum Gunlugu â€” YYYY-MM-DD (<proje>)

## Ana Konu

## Tamamlananlar
### <Kategori>
- Madde (dosya:line)

## Build / Test Durumu

## Commit Durumu

## Yarim Kalan / Yarin'a

## Kararlar
### Reddedilenler
- ~~A~~ â€” sebep
- B seÃ§ildi â€” gerekÃ§e

## KonuÅŸulan ek konular
### <Konu â€” parked>

### KullanÄ±cÄ± feedback verbatim
> "alÄ±ntÄ±"

## Dikkat Edilmesi Gerekenler

## Yarina Baslangic Noktasi

## YardÄ±mcÄ± Dosyalar
```

## Adim 3 â€” Konusma Baglamini DERIN OKU

KRITIK: "Ne yazildi" + "ne tartisildi + nasil karar verildi". HEPSI yansitilmali:

- 3a. Parked Ã¶ÄŸeler
- 3b. Reddedilen alternatifler (NEDEN reddedildi)
- 3c. Scope creep / pivot kararlarÄ±
- 3d. KullanÄ±cÄ± verbatim quotes
- 3e. Domain knowledge / sÃ¶zlÃ¼k
- 3f. UX/UI saga'larÄ±
- 3g. Bug fix kararlarÄ± (kalÄ±cÄ± kural)
- 3h. Ä°liÅŸkili dosyalar
- 3i. "HatÄ±rlatma" notlarÄ±

Hacim eÅŸiÄŸi: 3+ saat veya 20+ dosya â†’ DETAYLI yaz.

## Adim 4.5 â€” TODO.md Senkronu (ZORUNLU)

5 zorunlu adÄ±m:

1. TODO.md'yi oku.
2. Tamamlananlari isaretle: `- [x] ~~...~~ â€” âœ… commit abc1234`.
3. Yeni keÅŸfedilen iÅŸler ekle.
4. KararlarÄ± iÅŸlet (ADR/Kural/Backlog deÄŸiÅŸimi).
5. Yapilanlar ozeti: `### YYYY-MM-DD â€” <ana konu>` 3-5 madde.

## Adim 5 â€” Journal + TODO OTOMATIK commit

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

- "iyi geceler" â†’ otomatik
- "/handoff" â†’ aÃ§Ä±k
- "gÃ¼naydÄ±n" â†’ ters yÃ¶n: en son journal'i oku, Ã¶zet ver (commit yok)

## Dikkat

1. Journal yoksa: docs/journal/<proje>/ oluÅŸtur.
2. Auto-commit SADECE journal + TODO.
3. CLAUDE.md'ye session log eklenmemeli.
4. TÃ¼rkÃ§e yaz, UTF-8.

## Ä°liÅŸkili Dosyalar

- `.claude/hooks/session-start.sh`
- `.claude/hooks/post-commit-journal.sh`
- `.claude/rules/commit-discipline.md`
- `docs/CONTEXT_MANAGEMENT.md`


## Adim -1 â€” KENDI OTURUM ID'NI BUL (ZORUNLU)

Handoff'a baslamadan once oturum ID'ni tespit et:

### Oncelik sirasi
1. **Context'te hatirliyor musun?** Hook oturum basinda buyuk basliklarla verdi:
   ```
   >>> BU OTURUMUN ID'SI: 20260427-143022-a3f1 <<<
   ```
   Hatirliyorsan dogrudan kullan.

2. **Hatirlamiyorsan**: `cat .claude/locks/.current` (PARALEL oturumda guvensiz â€”
   son acilan ustune yazmis olabilir).

3. **Yine yoksa**: `ls -t .claude/locks/*.lock | head -1` (en son yaratilan lock).

4. **Hala yoksa**: Kullaniciya sor, hook ciktisinda hangi ID gordugunu hatirla.

### Onay
Lock dosyasini oku ve `started_at` ile bu oturumun baslangiciyla makul uyumlu mu kontrol et:

```bash
SESSION_ID="20260427-143022-a3f1"  # context'ten
if [ -f ".claude/locks/$SESSION_ID.lock" ]; then
    cat ".claude/locks/$SESSION_ID.lock"
fi
```

**Yanlis ID ile yanlis lock'u silme** â€” paralel oturum varsa diger oturumun lock'unu
silersen onun stale cleanup beklemesi gerekir.


## Adim 6 â€” Pre-commit Git Check + Lock Silme (ADR-002)

### Pre-commit git check

Commit'ten once paralel oturum cakismasini kontrol et:

```bash
# Origin varsa fetch (timeout dusuk, takilmasin)
git fetch --quiet 2>/dev/null || true

# Son commit info
LOCAL_HEAD=$(git rev-parse HEAD 2>/dev/null)
LAST_COMMIT_AUTHOR=$(git log -1 --format='%an' 2>/dev/null)
LAST_COMMIT_TIME=$(git log -1 --format='%ar' 2>/dev/null)
LAST_COMMIT_MSG=$(git log -1 --format='%s' 2>/dev/null)
echo "Son commit: $LOCAL_HEAD"
echo "  Author: $LAST_COMMIT_AUTHOR ($LAST_COMMIT_TIME)"
echo "  Mesaj: $LAST_COMMIT_MSG"
```

Eger son commit son 5 dakika icinde + farkli scope (paralel oturumdan)
ise kullaniciya bilgi ver: "Paralel oturum az once commit atti, devam edeyim mi?"

### Lock silme â€” kendi oturumumun

```bash
# Adim -1'de bulunan SESSION_ID
if [ -f ".claude/locks/$SESSION_ID.lock" ]; then
    rm -f ".claude/locks/$SESSION_ID.lock"
    echo "Lock silindi: $SESSION_ID"

    # .current dosyasi sadece bu ID'ye aitse temizle
    CURRENT=$(cat ".claude/locks/.current" 2>/dev/null)
    if [ "$CURRENT" = "$SESSION_ID" ]; then
        rm -f ".claude/locks/.current"
    fi
fi

# Yan etki: stale cleanup (4+ saat eski)
find .claude/locks -name "*.lock" -mmin +240 -delete 2>/dev/null || true
```

### Aktif kalan oturum varsa bilgi

```bash
REMAINING=$(ls -1 .claude/locks/*.lock 2>/dev/null | wc -l | tr -d ' ')
if [ "$REMAINING" -gt 0 ]; then
    echo ""
    echo "Not: $REMAINING aktif paralel oturum daha var (kendi handoff'unu yapmadi)."
    ls -1 .claude/locks/*.lock 2>/dev/null
fi
```