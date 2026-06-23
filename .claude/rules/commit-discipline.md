# Git / Commit Disiplini

_Her projede aynen uygulanır. `paths:` yok — compact sonrası survive._

## Commit Kuralları

0. **S1 — Commit → TODO `[x]` ZORUNLU (18.06 sertleştirme).** Bir TODO maddesini kapatan commit atılırken AYNI ANDA o madde `TODO.md`'de `[x] ✅ <tarih> (commit <hash>)` yapılır. Commit atıp TODO'yu açık bırakmak **yasak** — done-but-`[ ]` birikiminin kök sebebi bu. İstisna yok.

1. **Kullanıcı açıkça istemedikçe commit etme.** "commit et", "commit'le", "git commit" net komut olmadan commit yok.
   - **İstisna:** `session-handoff` skill'i, yalnızca `docs/journal/YYYY-MM-DD.md` dosyasını otomatik commit eder (başka path'e dokunmaz). Gerekçe: handoff artifactı dosyaya yazılıp bırakılırsa her oturum başında uncommitted olarak görünür ve pre-commit hook gürültü yapar.
2. **Bir commit = bir konu.** AI 3 katman birden çıkarırsa → 3 ayrı commit.
3. **Save-point commit.** Test yeşil → hemen commit (iş yarım olsa bile, `WIP:` prefix).
4. **15 dosya eşiği.** `git status` uncommitted > 15 → **yeni iş yasak**, önce commit-split.
5. **Commit mesajı:**
   ```
   <tip>: <kısa özet>

   <detay — opsiyonel>
   ```
   Tipler: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `perf`, `style`, `build`.

## Branch Stratejisi

- **main** → production.
- **feature branch** → bir kullanıcı talebi = bir branch (`feature/xyz`, `fix/abc`).
- İş bitince squash-merge main'e.
- **Branch-per-ask:** Yeni talep → yeni branch.

## Zararlı Komutlar (AÇIK ONAY olmadan YASAK)

- `git push --force` / `-f` — history yeniden yaz.
- `git reset --hard` — uncommitted iş uçar.
- `git clean -fd` — untracked siler.
- `git rebase -i` — interaktif, otomatik olmaz.
- `git checkout .` / `git restore .` — tüm değişiklikleri at.

Gerekirse sor: "Bu komutu çalıştırmam emin misin? Mevcut N dosya değişikliği kaybolacak."

## Commit-Split Pattern

Uncommitted > 15 olunca:
```bash
git status                           # ne değişmiş
git diff --stat                      # kaç satır
# Bucket'lara ayır, konu başına:
git add <file1> <file2>
git commit -m "feat: <konu>"
git log --oneline -10
```

Otomasyon: `commit-splitter` subagent (her projeye eklenebilir).

### Paylaşılan-dosya kuralı (B-121 — monolit bleed azalt)

Tek-app monolitte bazı dosyalar **doğası gereği kesişir** (her özellik dokunur): `Program.cs` DI, `NavRegistry.cs` nav, `wwwroot/app.css` (Tailwind build). Karışmayı azalt:
- **Paylaşılan dosya edit'i kendi özellik commit'iyle gider** — ayrı bucket'a düşmez (ör. yeni Muhasebe sayfası → `Muhasebe.razor` + `NavRegistry` muhasebe-satırı + DI AYNI commit'te).
- **DI özellik-bazlı:** yeni servis `ServiceRegistration.cs`'in ilgili `AddBkm*` grubuna eklenir, `Program.cs` değişmez → hunk-split biter.
- **`app.css` build çıktısı** (`.gitattributes` `linguist-generated`) — gitignore'lanAMAZ (csproj node-yok fallback); değiştiyse onu üreten UI commit'iyle gider.
- Monolitte bleed tamamen bitmez — disiplinle yönetilir.

## Git Hook'ları (opsiyonel)

- **pre-commit (antipattern scan):** stack-bağımlı (ör. .NET: `DateTime.Now`, `async void`, `new HttpClient()`).
- **post-commit (journal):** `docs/journal/YYYY-MM-DD.md`'ye commit özeti.

Kurulacak: `.claude/hooks/` altına, `.claude/settings.json`'da kayıtlı.
