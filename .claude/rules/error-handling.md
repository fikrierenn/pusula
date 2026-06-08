# Hata Yönetimi (Beklenen Sonuç vs Gerçek Exception)

_Her stack'te geçerli ilke. `paths:` yok — compact sonrası survive._

## Temel Ayrım

**Beklenen sonuç (business outcome)** ≠ **gerçek exception (system failure)**.

| Durum | Tip | Mekanizma |
|---|---|---|
| "Kayıt bulunamadı", "yetki yok", "stok yetersiz", "geçersiz girdi" | Beklenen | **Result/Either pattern** veya tipli dönüş (`Result<T>`, `{ ok, error }`, `Option`) |
| DB connection loss, network timeout, JSON parse fail, file I/O fail | Gerçek exception | `try/catch` + log + generic kullanıcı mesajı |
| Bug / impossible state (null check fail, off-by-one) | Programming error | Fırlat, üst handler yakalasın |

**Anti-pattern:** Beklenen iş sonucu için exception fırlatmak (`throw new Error("bulunamadı")`) → exception ile akış kontrolü pahalı + okunabilirlik düşürür + gerçek hatayı maskeler.

## İlkeler

1. **Beklenen başarısızlık tipli dönsün.** Çağıran, hata olasılığını imzadan görsün — try/catch'e gömülü sürpriz olmasın.

2. **Gerçek exception loglanır + maskeli kullanıcı mesajı.**
   - Kullanıcıya: "Beklenmedik bir hata oluştu." (generic, Türkçe).
   - Logger'a: tam stack trace + context (sensitive maskeli).
   - Stack trace / exception message **asla** kullanıcıya/response'a sızmaz (bkz. `security-principles.md`).

3. **Boş catch yasak.** `catch {}` / `except: pass` → en azından logla. Yutulan hata = takip edilemeyen bug.

4. **Fallback sessiz olmasın.** Fallback'e düşüldüyse logla ("primary X failed, falling back to Y"). Sessiz fallback yanlış veriyi doğruymuş gibi gösterir.

5. **Hata sınıflandırması tutarlı.** Projede hata kodu/aralığı veya tip hiyerarşisi varsa ona uy.

## Anti-pattern

1. `throw` ile business validation (beklenen sonucu exception yapma).
2. `catch (e) { /* ignore */ }` — sessiz yutma.
3. `catch (e) { return null }` — neden null döndüğü kaybolur, çağıran ayırt edemez.
4. Exception message'ı kullanıcıya basmak — bilgi sızıntısı.
5. Try/catch'i fonksiyonun tamamına sarıp her şeyi tek "hata oldu"ya indirgemek.

## İlişkili
- `.claude/rules/security-principles.md` — exception sızıntısı, log maskeleme.
- `silent-failure-hunter` agent — sessiz hata avı.
