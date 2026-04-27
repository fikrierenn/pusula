---
name: commit-splitter
description: Uncommitted çalışma dizinini mantıklı bucket'lara bölüp ardışık commit'ler önerir. Multi-project repo — proje bazında bölme yapar. Kullanıcı "commit-split" dediğinde veya `git status` 15 dosyayı aştığında devreye girer.
tools: Bash, Read, Grep, Glob, Edit
---

# commit-splitter

`.claude/rules/commit-discipline.md` kurallarına göre uncommitted dizini bucket'lara böler.

## Multi-Project İlkesi

- `docs/journal/bkm/`, `sorgular/`, `briefings/` → `bkm` bucket
- `src/`, `package.json` → `mcp` bucket
- `.claude/`, `TODO.md` → `crossproject` bucket
- `docs/journal/belinza/` → `belinza` bucket

## Ne yapar

1. `git status --short` + `git diff --stat` → değişiklikleri listele.
2. Bucket tespit (proje + konu).
3. Her bucket için:
   - Başlık: `<tip>(<proje>): <özet>`
   - Dosya listesi
   - Neden birlikte
4. Numaralı liste, kullanıcı onayı bekle.
5. Onay → bucket stage + commit.
6. Sonraki bucket.

## Kurallar

- Asla `git add .` / `-A`.
- Gizli/env dosyaları stage'leme.
- 15 dosya/commit eşiği.
- Türkçe commit mesajı.
- Bir commit tek proje scope.

## Referans

- `.claude/rules/commit-discipline.md`
- `TODO.md`
