# Oturum Protokolü

_Her Claude oturumunun başı / ortası / sonu ritüelleri. Bu kural evrensel._

## Oturum Başı — İlk yanıttan önce ZORUNLU

### Adım 1 — Hook'u KOŞULSUZ çalıştır

```bash
bash .claude/hooks/session-start.sh
```

Her oturumda, istisnasız.

### Adım 2 — İlgili projenin son 2 journal dosyasını oku

```bash
ls -t docs/journal/<proje>/*.md | head -2
```

### Adım 3 — TODO.md aktif öncelikleri oku

`TODO.md` → "BIRLESIK ONCELIK SIRASI" → her proje altında Faz 0 + Faz 1 ilk 3 madde.

### Adım 4 — Uncommitted durumu bil

`git status --porcelain | wc -l` — 15 üstüyse yeni iş yasak.

### Kullanıcıya cevap

4 adım sessizce yapılır.

---

## Oturum Ortası

- 15 dosya eşiği → yeni iş yasak.
- 3 paralel feature eşiği.
- Kural değişikliği → `.claude/rules/*.md`'ye yaz.
- Mimari karar → `docs/ADR/NNN-konu.md`.
- Proje değişimi → yeni klasörün son journal'ını oku.

---

## Oturum Sonu

Tetikler: "iyi geceler" / "/handoff" / "kaydet ve kapat" / "devam edeceğiz" → session-handoff skill.

Skill `docs/journal/<proje>/YYYY-MM-DD.md`'ye append eder. Çoklu proje değişti → her proje için ayrı journal.

CLAUDE.md'ye session log YAZILMAZ.

---

## Ritüel atlandığında

1. Kabul et. Mazeret yok.
2. Hook'u manuel çalıştır.
3. Önlemini dosyaya yaz.
4. Journal'a süreç notu düş.

---

## İlişkili Dosyalar

- `docs/CONTEXT_MANAGEMENT.md`
- `.claude/hooks/session-start.sh`
- `.claude/skills/session-handoff/SKILL.md`
- `.claude/rules/commit-discipline.md`
- `docs/journal/`
