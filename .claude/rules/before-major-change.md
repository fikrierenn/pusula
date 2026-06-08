# Büyük Değişiklik Öncesi Zorunlu Çek-Liste

_Kapsam: Silme, rename, refactor, route attribute kaldırma, kolon drop, view silme, endpoint silme._
_Tetik: Bir değişiklik 30+ satır etkileniyor veya kullanıcı-görünür davranış değişiyor._

## Silme / Rename / Refactor Öncesi Adımlar

Her adım **sırayla** ve **atlanmadan**:

### 1. Mimari Haritayı Oku (varsa)
- Projenin `docs/ARCHITECTURE_MAP.md` veya benzeri canonical dokümanı var mı?
- Silmek üzere olduğun şey deprecated mi, yoksa hâlâ aktif mi?
- Cascade etkileri var mı?

### 2. Referans Tara (zorunlu — atlanırsa hata yapılır)

```bash
# Hangi dosyalar bu ismi referans alıyor?
grep -rn "<silinecek-isim>" src/ --include="*.ts" --include="*.tsx" \
  --include="*.cs" --include="*.cshtml" --include="*.py"
```

Sonuç **sıfır** olsa bile şüphelen — farklı string'le yazılmış olabilir.

### 3. Cascade Kontrol
- Bu endpoint/route/view/servis silinince kim kırılır?
- Frontend → API çağrısı var mı?
- Başka servis bu servisi import ediyor mu?

### 4. Kullanıcıya Net Soru Sor (TEHLİKELİ SİLME ÖNCESİ ZORUNLU)

Şu durumlarda **kullanıcı onayı olmadan SILME:**
- Görünür sayfa / component silme
- API route kaldırma (mevcut client'lar kırılır)
- DB kolon drop (data loss)
- Migration rollback

Soru kalıbı: **"X hâlâ kullanılıyor mu? Silersem Y kırılır — onaylıyor musun?"**

### 5. Plan Ekle (Tier 3 ise)
3+ klasör / yeni pattern / kullanıcı-görünür değişiklik → `plan-first.md` Tier 3 ZORUNLU plan. Plansız refactor yasak.

### 6. Refactor Sonrası
- Build + smoke test
- Commit mesajında net belirt: "`<X> silindi — <Y> canonical, eski URL <Z>'ye redirect`"
- Architecture dokümanı güncelle (varsa)

---

## Anti-pattern

1. **"Sanırım bu kullanılmıyor" → silme.** Sanmak yetmez — grep ile doğrula.
2. **Paralel canonical var gibi görünüyor → ikisini de refactor ettim.** Yanlış. Önce hangisinin canonical olduğunu sor.
3. **GET silinince POST otomatik silinir.** Yanlış — POST ayrı endpoint, başka yerden çağrılıyor olabilir.
4. **Plan yazmadan refactor.** → kapsam patlar, geri alma zor.

## Hata Yapıldığında

1. Kabul et.
2. `git revert` veya manuel restore.
3. Bu dosyaya örnek anti-pattern olarak ekle.
4. Memory'e `feedback_*.md` yaz: aynı hatayı tekrarlamamak için.
