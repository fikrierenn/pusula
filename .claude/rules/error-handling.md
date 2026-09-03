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

## Reddet mi, Say mı? — Doğrulama Sınırının Ölçütü

> Belinza deposundan uyarlandı (`D:\Dev\bel/.claude/rules/dogrulama-siniri.md`, 03.09.2026).
> Bir doğrulayıcı ne zaman KOŞUYU DURDURUR, ne zaman RAPORLAYIP devam eder?

**REDDET** — durum **ÇELİŞKİLİYSE**. İki doğru bilgi aynı anda tutamıyorsa.
**SAY** — durum **EKSİKSE**. Bilgi doğru ama tam değil.

Tek cümlede: *"bu iki şey aynı anda doğru olabilir mi?"* Olamazsa reddet.

**Neden:** çelişki bir VERİ durumu değil, bir **KOD hatasıdır**. Çalıştırmaya devam
etmek onu gizler — gizlenen kod hatası tam olarak "sessiz yanlış rakam" sınıfıdır.
Eksiklik ise meşru olabilir: bordro son kapanan aya kadar gelir, ötesi henüz yoktur;
reddetmek doğru veriyi de atar.

| Durum | Tanı | Karar |
|---|---|---|
| `net != brüt − indirim` | ikisi aynı anda doğru olamaz | **REDDET** (tutarlılık kontrolü patlar) |
| `fte > kayıt sayısı` | tam gün karşılığı, kişi sayısını geçemez | **REDDET** |
| Sezon toplamı ≠ sezon aylarının toplamı | aritmetik çelişki | **REDDET** |
| Ağustos bordrosu henüz işlenmemiş | henüz gelmemiş olabilir | **SAY** (`tam_mi: false` + uyarı) |
| Norm tablosunda personeli olmayan satır | kadro boş olabilir | **SAY** (açığa katmadan "teyit bekliyor") |
| Eylül–Ekim satışı yok | gelecek | **SAY** (tahmin, `ciro_tip` etiketli) |

**Sınırın bittiği yer: eksiklik çelişkiye döndüğü an.** O an sayma — reddet ya da
tamamla. Örnek: "bu ay çekildi" + "bu ayın eski kayıtları duruyor" çelişkidir.

## Anti-pattern

1. `throw` ile business validation (beklenen sonucu exception yapma).
2. `catch (e) { /* ignore */ }` — sessiz yutma.
3. `catch (e) { return null }` — neden null döndüğü kaybolur, çağıran ayırt edemez.
4. Exception message'ı kullanıcıya basmak — bilgi sızıntısı.
5. Try/catch'i fonksiyonun tamamına sarıp her şeyi tek "hata oldu"ya indirgemek.

## Sınıflandırıcı (kod tarafı — plan-12 WS-5)

"Gerçek exception" tipini koda gömme; **merkezi sınıflandırıcıdan** sor (transient → retry+backoff, fatal → fail). Dağınık inline string-match yasak.
- **C#:** `dashboard/Data/SqlErrorClassifier.cs` — `SqlErrorKind {Transient,Fatal}` + `ShouldRetry`. `Db.OpenAsync`/`OpenJokerAsync` transient bağlantı hatasında max-2 retry+backoff (loglu, sessiz değil).
- **Python:** `scripts/_errors.py` — `is_transient()` + `connect_with_retry()` (pymssql OperationalError=transient, ProgrammingError=fatal).
- **Kural:** retry yalnızca transient + bounded (max 2) + her deneme loglanır. Bilinmeyen=transient ama bounded (sonsuz loop yok). BKM tek-DB → `should_rotate`/`should_fallback` YOK, sadece `should_retry`.

## İlişkili
- `.claude/rules/security-principles.md` — exception sızıntısı, log maskeleme.
- `silent-failure-hunter` agent — sessiz hata avı.
- `dashboard/Data/SqlErrorClassifier.cs` · `scripts/_errors.py` — sınıflandırıcı kaynağı.
