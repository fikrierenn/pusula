# Plan 19 — Basit Auth (B-84)

## Problem
Dashboard (finansal ciro/marj + müşteri PII: ad/tel/kart) ağa **kimlik doğrulaması olmadan** açık. İç LAN + PWA bağlamı ama her ağ cihazı tüm veriyi görüyor. `security-principles.md` §7 (auth/session) ihlali.

## Scope
- Tek-kullanıcı (CFO) basit şifre auth. Çok-kullanıcı/rol YOK (over-engineering — footprint-ladder).
- Cookie auth (`HttpOnly`/`Secure`/`SameSite=Lax`), 12 saat session.
- Login sayfası (static SSR) + POST handler (minimal API).
- Global `[Authorize]` — login/healthz/ca.crt hariç. `/api/olustok-excel` korunur.
- Şifre **localhost SQL** `BkmPanel.dbo.PanelKullanici` (PBKDF2-SHA256 100k, salt+hash) — hardcode/env-plain YOK. Timing-safe.
- İlk açılış (tablo boş) → `/setup` şifre belirleme (şifre chat'e/koda girmez, kullanıcı UI'dan koyar). Sonra normal login.
- Brute-force: başarısız sayaç + kilit **SQL'de** (BasarisizSayac/KilitBitis), 5 hata → 5 dk.
- Logout.
- Bağlantı: `.env` PANEL_DB_HOST=localhost / PANEL_DB_NAME=BkmPanel / PANEL_DB_TRUSTED=true (Windows auth).

## Alternatifler (reddedilen)
- ~~ASP.NET Identity + DB kullanıcı tablosu~~ — tek-kullanıcı için ağır (migration, UI, rol). Reddedildi.
- ~~Reverse-proxy / network-level (nginx basic auth)~~ — mobil PWA + WSS cert zinciriyle çakışır, ayrı altyapı. Reddedildi.
- ~~Interactive Blazor login formu~~ — cookie SignIn `HttpContext` ister, interactive circuit'te yok → static SSR form + minimal API POST (standart Blazor Server pattern). Seçildi.

## Riskler
- Login sayfası static SSR olmalı (interactive değil) — yanlış olursa SignInAsync çalışmaz.
- Global Authorize tüm sayfaları kilitler → login/healthz/ca.crt allow-list şart yoksa login'e erişilemez (kilitlenme).
- HTTP (5112) üzerinden cookie `Secure` → HTTP'de gönderilmez. Mobil HTTP akışı var → `Secure` yerine ortam-bazlı veya SameSite ayarı. Karar: `Secure=Always` ama HTTP login çalışmaz; mobil HTTPS'e yönlendir VEYA Secure=SameAsRequest. **Seçim: `CookieSecurePolicy.SameAsRequest`** (HTTP+HTTPS paralel mevcut mimari).
- Env var yoksa: başlatmada uyarı log + login daima reddet (fail-safe, açık bırakma).

## Done Kriterleri
- Anonim istek herhangi bir sayfaya → /login'e yönlenir.
- Doğru şifre → cookie set, dashboard açılır. Yanlış → hata + sayaç artar.
- 5 hatalı deneme → geçici kilit.
- /healthz + /ca.crt auth'suz erişilir (PWA/circuit-poll bozulmaz).
- /api/olustok-excel anonim → 401/redirect.
- Logout → cookie temizlenir, /login.
- Build yeşil, login akışı smoke.

## Rollback
Tek commit (`feat(bkm): B-84 basit auth`). Sorun → `git revert`. Program.cs middleware + Routes.razor AuthorizeRouteView + Login.razor + LoginApi geri alınır.

## Adımlar
1. `Program.cs`: `AddAuthentication(CookieAuthenticationDefaults).AddCookie(...)` (LoginPath=/login, 12h, SameAsRequest, HttpOnly). `AddAuthorization` + `AddCascadingAuthenticationState`.
2. `Program.cs` pipeline: `UseAuthentication()` + `UseAuthorization()` (UseAntiforgery'den önce/uygun sıra).
3. `Routes.razor`: `AuthorizeRouteView` + yetkisiz → RedirectToLogin component.
4. `Components/Pages/Login.razor` (static SSR, `@attribute [AllowAnonymous]`): şifre formu, POST `/auth/login`.
5. `Program.cs` minimal API: `MapPost("/auth/login")` — env şifre timing-safe (`CryptographicOperations.FixedTimeEquals`) + rate-limit (IP sayaç) → `SignInAsync`. `MapPost("/auth/logout")` → SignOut.
6. Global authorize: `[Authorize]` `_Imports.razor` veya `App`/`Routes` fallback policy. Login `[AllowAnonymous]`. `/healthz`,`/ca.crt` → `.AllowAnonymous()`. `/api/olustok-excel` → `.RequireAuthorization()`.
7. Build + smoke (anonim redirect, doğru/yanlış şifre, kilit, logout).
8. `.claude/rules` veya CLAUDE.md'ye env var (`BKM_PANEL_SIFRE`) notu. TODO B-84 [x].

## Done sonrası
- Plan → `plans/archive/`. Journal + TODO sync.
