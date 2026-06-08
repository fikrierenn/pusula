# Güvenlik İlkeleri (evrensel)

_Her projede aktif. `paths:` yok — compact sonrası survive._

## Mutlak Kurallar

1. **Sır / şifre yönetimi:**
   - Connection string, API key, token → **env var** veya secret manager.
   - Plain-text hardcode **yasak** (config dosyası, source, test dosyası dahil).
   - `.gitignore` kontrol: `.env*`, `appsettings.Production.json`, `secrets.json`, `.pgpass` vs.

2. **SQL Injection:**
   - Her query parametreli. String concat + user input **yasak**.
   - Stack-özel: detay `stacks/<name>/sql-conventions.md` veya benzeri.

3. **XSS:**
   - Framework'ün escape mekanizması (React, Vue, Razor otomatik; manuel HTML üretiminde dikkat).
   - `innerHTML` / `dangerouslySetInnerHTML` / `@Html.Raw` minimum — user-data içerse yasak.
   - DOM API + `textContent` tercih.

4. **CSRF:**
   - Framework token mekanizması aktif her POST/PUT/DELETE'te.
   - API + cookie auth → SameSite=Strict veya Lax.

5. **Open Redirect:**
   - `returnUrl` query param → whitelist veya `IsLocalUrl` + ek kontrol (`StartsWith("/") && !StartsWith("//")`).

6. **Exception Handling:**
   - User'a stack trace / exception message gösterme. Generic mesaj.
   - Detay logger'a, sensitive info maskeli.

7. **Auth/Session:**
   - Cookie: `HttpOnly`, `Secure`, `SameSite`.
   - Session timeout makul (8-12h).
   - Brute-force koruma: failed attempt sayacı, lock veya rate limit.

8. **Password Hashing:**
   - Argon2id / bcrypt / PBKDF2 (iteration 100k+).
   - Timing-safe compare (`constant_time_compare` / `CryptographicOperations.FixedTimeEquals`).

9. **Input Validation:**
   - Whitelist > blacklist.
   - Regex, length limit, type check.
   - Dosya upload: extension + magic number + size + antivirus (gerekirse).

10. **Audit Logging:**
    - Login/logout (başarılı + başarısız), role change, delete, export, admin config change.
    - Log olmayan aksiyon = takip edilemez.

## Security Review Ritüeli

Her büyük değişiklik **öncesi ve sonrası**:
```
/security-review
```
Skill bulgulara göre düzelt, commit'le.

## Yaygın Antipattern'ler

- `new HttpClient()` (her çağrıda — IHttpClientFactory kullan).
- `DateTime.Now` (timezone — `UtcNow`).
- `async void` (event handler hariç).
- `catch { /* ignore */ }` (en azından log).
- `console.log(token)` / `print(password)` — **yasak**.
