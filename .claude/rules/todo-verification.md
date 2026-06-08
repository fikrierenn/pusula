# TODO Doğrulama Disiplini

_Kapsam: `TODO.md`, `docs/journal/*`, `plans/`, bug listeleri. Action almadan önce **canlı kod** ile karşılaştırılır._
_`paths:` yok — compact sonrası survive._

## Mutlak Kurallar

1. **TODO listesi bilgi değildir, hipotez tahtasıdır.** "Açık" yazısı bugün açık olduğunu kanıtlamaz; yazıldığı tarihte açıktı. Bugün de açık olduğunu kanıtlamak senin işin.

2. **Action almadan önce file:line ile doğrula.** Madde `auth/login.ts:128 yetki kontrolü yok` diyorsa:
   - `Read` ile o satırı oku
   - İlgili guard/koruma anahtar kelimesini ara (`@Authorize`, `requireAuth`, `if (!user)`, vb.)
   - Yoksa açık, varsa kapalı — kullanıcıya bildir, kapalıysa fix etme

3. **"hardening" / "fix" commit'leri kırmızı bayraktır.** `git log --grep='hardening\|fix(security)\|post-review'` çıkıyorsa eski TODO **muhtemelen stale**. Action öncesi sweep zorunlu.

4. **Fix'lemeden önce sweep, fix sırasında değil.** 10 madde fix'liyormuş gibi başlayıp 5'incide "bu zaten kapalı" demek maliyetli. Önce tüm 10'u paralel `Read`/`Grep` ile doğrula, sonra açık olanları sırayla fix et.

## Workflow

### Adım 1 — TODO maddesini oku
Madde için file:line referansı yoksa → reddet, kullanıcıdan net file:line iste.

### Adım 2 — Paralel doğrulama (tek mesajda)
HIGH/CRITICAL maddelerin tümü için **paralel** `Read` + `Grep` çağrısı:

```
Read(auth/login.ts:120-135)
Read(services/payment.ts:50-90)
Grep("validateInput", "src/")
```

### Adım 3 — Gerçek açık listesi çıkar

| # | İddia | Kod kanıtı | Durum |
|---|---|---|---|
| H1 | login input validate edilmiyor | `validateInput` çağrısı YOK | ❌ AÇIK |
| H2 | rate-limit yok | `rateLimiter` middleware var | ✅ KAPALI |

Kullanıcıya bu tabloyu göster. **Onay almadan fix etme.**

### Adım 4 — TODO.md güncelle
Kapanmış maddeleri `[ ]` → `[x] ✅ KAPALI <tarih> — <kod kanıtı>` yap. Commit hash ekle.

### Adım 5 — Sadece açık olanları fix et
Doğrulanmış açık maddeleri sırayla. Her fix sonrası ilgili test/smoke.

## Anti-pattern

1. **TODO'yu okuyup direkt fix'e başlamak** — yarısı zaten kapalı olabilir.
2. **"Açık yazıyor, demek ki açık"** — tarih damgası eskidir, kod değişmiştir.
3. **Doğrulama yapmadan "tamam, kapattım" demek** — `.claude/rules/test-discipline.md` ile birlikte oku.

## İlişkili
- `.claude/rules/test-discipline.md` — "bitti" demeden önce çalıştır.
- `.claude/rules/session-protocol.md` — oturum başı TODO okuma.
