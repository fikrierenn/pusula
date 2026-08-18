# Plan 06 — MCP Server Kodunun Ayıklanması (ete kemiğe büründürme)

**Tarih:** 10.06.2026 · **Tier:** 3 (yeni repo, kullanıcı-görünür yapı değişikliği)

## Problem
`sqlserver-mcp-server` repo'su iki kimlik taşıyor: (a) gerçek MCP server kodu (`src/` 2.194 satır TS, 8 tool, testli), (b) BKM analitik çalışma alanı (raporlar, scriptler, sema, docs). MCP server kodu bataklığa gömülü — bağımsız geliştirilemiyor, versiyonlanamıyor, başka projelere (YonetIQ/Operax) temiz dağıtılamıyor.

## Scope
- **Dahil:** `src/`, testler, package*, tsconfig, .env.example → yeni bağımsız proje `D:\Dev\sqlserver-mcp`. Yeni mimari iskeleti (rules/agents/commands/hooks/skills). Build+test yeşil doğrulama. Git init + ilk commit.
- **Dahil DEĞİL:** Eski repo'dan src/dist SİLİNMEZ (canlı config `dist/index.js`'e bağlı — sqlserver/portalhub/zirve). Config geçişi kullanıcı onayıyla ayrı adım. BKM analitik içeriği olduğu yerde kalır.

## Reddedilen alternatifler
1. **In-place `mcp/` klasörüne taşı:** repo kimlik karmaşası sürer; bağımsız clone/dağıtım çözülmez.
2. **git filter-repo ile history'li split:** temiz ama BKM gizli verileri (rapor/SQL) history'de — yeni repo'ya sızar. Fresh start daha güvenli.

## Adımlar
1. `D:\Dev\sqlserver-mcp` oluştur; src/, tsconfig, package.json, package-lock, .env.example, .env (gitignore'lu) kopyala.
2. README'yi MCP-odaklı yeniden yaz; CLAUDE.md (slim) + TODO.md + plans/ iskeleti.
3. Yeni mimari: .claude/rules (evrensel set + Fact-Force), agents (planner/commit-splitter/silent-failure-hunter), commands (learn), hooks (session-start/pre-compact/post-commit-journal), skills (session-handoff).
4. `npm ci` → `npm run build` → `npm test` — yeşil olmadan bitti sayılmaz.
5. `git init` + ilk commit.
6. Eski repo: README+CLAUDE.md'ye "MCP kodu taşındı, dist geçiş tamamlanana kadar burada" notu; bozuk `src/{tools,services,schemas}` klasörünü sil; TODO'ya config-geçiş maddesi.

## Done criteria
- [x] Yeni repo build+test yeşil. (8/8 test, build temiz)
- [x] Canlı MCP config kırılmadı (eski dist dokunulmadı).
- [x] Config geçiş snippet'i hazır (kullanıcı istediğinde uygular). → yeni repo README §Kurulum
- [x] Eski repo'da deprecation notu + TODO maddesi (M-01).

## Rollback
Yeni klasörü sil — eski repo'da hiçbir şey değişmedi (not + TODO dışında).
