# Oturum ProtokolÃ¼

_Her Claude oturumunun baÅŸÄ± / ortasÄ± / sonu ritÃ¼elleri. Bu kural evrensel._

## Oturum BaÅŸÄ± â€” Ä°lk yanÄ±ttan Ã¶nce ZORUNLU

### AdÄ±m 1 â€” Hook'u KOÅULSUZ Ã§alÄ±ÅŸtÄ±r

```bash
bash .claude/hooks/session-start.sh
```

Her oturumda, istisnasÄ±z.

### AdÄ±m 2 â€” Ä°lgili projenin son 2 journal dosyasÄ±nÄ± oku

```bash
ls -t docs/journal/<proje>/*.md | head -2
```

### AdÄ±m 3 â€” TODO.md aktif Ã¶ncelikleri oku

`TODO.md` â†’ "BIRLESIK ONCELIK SIRASI" â†’ her proje altÄ±nda Faz 0 + Faz 1 ilk 3 madde.

### AdÄ±m 4 â€” Uncommitted durumu bil

`git status --porcelain | wc -l` â€” 15 Ã¼stÃ¼yse yeni iÅŸ yasak.

### KullanÄ±cÄ±ya cevap

4 adÄ±m sessizce yapÄ±lÄ±r.

---

## Oturum OrtasÄ±

- 15 dosya eÅŸiÄŸi â†’ yeni iÅŸ yasak.
- 3 paralel feature eÅŸiÄŸi.
- Kural deÄŸiÅŸikliÄŸi â†’ `.claude/rules/*.md`'ye yaz.
- Mimari karar â†’ `docs/ADR/NNN-konu.md`.
- Proje deÄŸiÅŸimi â†’ yeni klasÃ¶rÃ¼n son journal'Ä±nÄ± oku.

---

## Oturum Sonu

Tetikler: "iyi geceler" / "/handoff" / "kaydet ve kapat" / "devam edeceÄŸiz" â†’ session-handoff skill.

Skill `docs/journal/<proje>/YYYY-MM-DD.md`'ye append eder. Ã‡oklu proje deÄŸiÅŸti â†’ her proje iÃ§in ayrÄ± journal.

CLAUDE.md'ye session log YAZILMAZ.

---

## RitÃ¼el atlandÄ±ÄŸÄ±nda

1. Kabul et. Mazeret yok.
2. Hook'u manuel Ã§alÄ±ÅŸtÄ±r.
3. Ã–nlemini dosyaya yaz.
4. Journal'a sÃ¼reÃ§ notu dÃ¼ÅŸ.

---

## Ä°liÅŸkili Dosyalar

- `docs/CONTEXT_MANAGEMENT.md`
- `.claude/hooks/session-start.sh`
- `.claude/skills/session-handoff/SKILL.md`
- `.claude/rules/commit-discipline.md`
- `docs/journal/`

---

## Paralel Oturum Disiplini (ADR-002)

`session-start.sh` her oturum basinda `.claude/locks/<session-id>.lock` yaratir
ve hook ciktisinin en ustunde `>>> BU OTURUMUN ID'SI: <id> <<<` basligi ile gosterir.

### Adim 1.5 â€” Oturum ID'sini context'te tut (ZORUNLU)

Hook ciktisindan kendi ID'ni oku ve **handoff'a kadar context'te tut**.

```
>>> BU OTURUMUN ID'SI: 20260427-143022-a3f1 <<<
```

- Bu ID handoff'ta lock silmek icin lazim.
- /compact yaparsan ID'yi YENI context'e mutlaka tasi (kuralin merkezinde).
- /clear veya yeni oturum aciliyorsa eski ID gecersiz, hook yenisini yaratir.
- ID kaybolduysa fallback: `.claude/locks/.current` (ama paralel oturumda guvensiz)
  veya `ls -t .claude/locks/*.lock | head -1` (en son yaratilan).

### Aktif lock varsa (paralel oturum)

Hook stderr/stdout'a uyari yazar:

```
UYARI: <N> PARALEL AKTIF OTURUM
  Diger oturum(lar):
    - <id1> (basladi: ...)
    - <id2> (basladi: ...)
```

Bu durumda:
- TODO.md veya ayni proje journal yazimi oncesi: `git fetch && git status` kontrol.
- Conflict olasiligi varsa kullaniciya sor (overwrite/merge/iptal).
- Kendi journal'in farkli proje/dosyada ise sorun yok (multi-project ayrimi yarisi cozer).

### Lock disiplini

- Oturum sonu `session-handoff` skill kendi `<session-id>.lock`'unu siler.
- 4 saatten eski lock'lar otomatik temizlenir (stale cleanup, hook'ta).
- Lock dosyalari `.gitignore`'da; klasor (`.claude/locks/`) `.gitkeep` ile kalici.
- `.current` dosyasi paralel oturumda son acilana yazar â€” bu yuzden ID'yi context'te
  tutmak ZORUNLU (sadece `.current`'a guvenme).

### Pre-handoff git check (handoff skill icinde)

- Commit'ten once `git fetch` (origin varsa, timeout dusuk).
- Local son commit hash'i ile remote farkliysa uyari.
- Kullanici onayi olmadan auto-merge yapma.

Detay: `docs/ADR/002-paralel-oturum-koruma.md`.