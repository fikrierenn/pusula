# Git / Commit Disiplini

_Her projede aynen uygulanır. `paths:` yok._

## Commit Kuralları

1. Kullanıcı açıkça istemedikçe commit etme.
   - İstisna: `session-handoff` skill journal+TODO commit'ler.
2. Bir commit = bir konu.
3. Save-point commit. Test yeşil → hemen commit.
4. 15 dosya eşiği. Aşıldı → yeni iş yasak.
5. Commit mesajı:
   ```
   <tip>(<proje>): <kısa özet>
   ```
   Tipler: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `perf`, `style`, `build`.
   Multi-project: `feat(bkm):`, `docs(belinza):`, `chore(mcp):`, `docs(crossproject):`.

## Branch Stratejisi

- main → production.
- feature branch → bir talep = bir branch.
- Squash-merge.

## Zararlı Komutlar (AÇIK ONAY GEREKİR)

- `git push --force` / `-f`
- `git reset --hard`
- `git clean -fd`
- `git rebase -i`
- `git checkout .` / `git restore .`

## Multi-Project Commit

- BKM dosyaları (`docs/journal/bkm/`, `sorgular/`, `briefings/`) ayrı commit.
- MCP server (`src/`, `package.json`) ayrı commit.
- Bir commit yalnızca tek proje değiştirir.
- Karışmış değişiklik → commit-splitter.

## Git Hook'ları

- post-commit (journal): `docs/journal/<proje>/YYYY-MM-DD.md`'ye commit özeti.
- Proje tespiti: scope → `feat(bkm):` → `bkm/`. Yoksa `_crossproject/`.
