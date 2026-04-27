# Plan NN — <kısa başlık>

> Bu şablon Tier 3 işler içindir. Tier 1 (yok) ve Tier 2 (TODO satırı) için kullanma.

**Tarih:** YYYY-MM-DD
**Proje:** `bkm` | `belinza` | `yonetiq` | `mcp` | `crossproject`
**Yazan:** Fikri / Claude (oturum ID: `<id>`)
**Durum:** `Taslak` | `Onaylandı` | `Uygulamada` | `Tamamlandı` | `İptal`

---

## 1. Problem

Hangi sorunu çözüyoruz? Net 2-4 cümle. "Şunu yapacağız" değil, "şu problem var, şu yüzden çözmemiz lazım".

## 2. Scope

### Kapsam dahili
- ...

### Kapsam dışı
- ... (açıkça söyle, scope creep'i engelle)

### Etkilenen dosyalar (tahmin)
- `path/to/file1.ts` — ne değişecek
- `path/to/file2.md` — ne değişecek

**Tahmini boyut:** N dosya / M satır.

## 3. Alternatifler

### A: <alternatif başlık>
**Açıklama:** ...
**Reddetme sebebi:** ...

### B: <alternatif başlık>
**Açıklama:** ...
**Reddetme sebebi:** ...

### C: <seçilen — hangisi yapılacak>
**Açıklama:** ...
**Sebep:** ...

> En az 2 alternatif reddedilmeli — yoksa "Tier 3 mü gerçekten?" sorgulanmalı. Tek yol varsa muhtemelen Tier 2.

## 4. Riskler

| Risk | Etki | Olasılık | Mitigation |
|---|---|---|---|
| ... | düşük/orta/yüksek | düşük/orta/yüksek | nasıl ele alınacak |

## 5. Done Criteria

Bu plan tamamlandı sayılması için:

- [ ] <Ölçülebilir kriter 1>
- [ ] <Ölçülebilir kriter 2>
- [ ] Test/doğrulama: ...
- [ ] Dokümantasyon: ... (varsa)
- [ ] Rollback yolu test edildi (varsa)

## 6. Rollback Planı

Eğer bu değişiklik production'da sorun yaratırsa nasıl geri alınır?

- Git revert: `git revert <commit>` — uygun mu?
- DB migration varsa down script: ...
- Config rollback: ...

## 7. Adımlar / İçerdiği TODO maddeleri

1. [ ] **<ID>** Adım 1
2. [ ] **<ID>** Adım 2
3. [ ] **<ID>** Adım 3 (test)
4. [ ] **<ID>** Adım 4 (dokümantasyon)

> TODO.md'ye de bu maddeleri ayrıca ekle, plan dosyası ve TODO senkron olsun.

## 8. İlişkili

- ADR: `docs/ADR/<NN>-<konu>.md` (varsa)
- Önceki plan: `plans/<NN-1>-<konu>.md` (varsa)
- TODO ID'leri: ...
- Konuşma referans: `docs/journal/<proje>/YYYY-MM-DD.md`

## 9. Onay

> Kullanıcı onay verene kadar implement edilmez.

- [ ] Plan kullanıcıya gösterildi
- [ ] Geri bildirim alındı (varsa düzeltildi)
- [ ] Onay alındı: <tarih, kullanıcı imzası>
