# Plan 26 — Z.ai (BigModel) LLM Sağlayıcı (free GLM-Flash)

**Tarih:** 2026-06-22
**Proje:** `bkm`
**Yazan:** Fikri / Claude
**Durum:** Taslak

---

## 1. Problem

BKM-Asistan LLM zinciri OpenRouter (birincil) → Gemini → Groq. OpenRouter free havuzu 50/gün ve flash GLM modelleri OpenRouter'da ücretli. Z.ai kendi platformu (BigModel) `glm-4.5-flash` / `glm-4.7-flash` modellerini **ücretsiz** sunuyor. Bunları zincire birincil free GLM olarak eklemek istiyoruz.

## 2. Scope

### Kapsam dahili
- Yeni `ZaiProvider` (OpenRouterProvider'ın OpenAI-uyumlu klonu, base-URL `https://api.z.ai/api/paas/v4`).
- DI kaydı + `FallbackLlmProvider` zincirine ekleme.
- `.env`: `ZAI_API_KEY` + `ZAI_MODELS`.

### Kapsam dışı
- OpenRouter/Gemini/Groq sağlayıcı davranışı değişmez.
- Yeni UI / model-seçim ekranı yok.

### Etkilenen dosyalar
- `dashboard/Data/Asistan/ZaiProvider.cs` — YENİ (~110 satır, OpenRouterProvider klonu).
- `dashboard/Data/Asistan/FallbackLlmProvider.cs` — zincire Zai ekle.
- `dashboard/Program.cs` — DI kaydı (2 satır).
- `.env` — ZAI_API_KEY + ZAI_MODELS.

**Tahmini boyut:** 4 dosya / ~120 satır.

## 3. Alternatifler

### A: OpenRouterProvider'ı base-URL parametrik yap
**Reddetme sebebi:** OpenRouter-özel header (HTTP-Referer/X-Title) + iç-rotasyon mantığı karışır; mevcut idiom her sağlayıcı ayrı dosya (Gemini/Groq).

### B: OpenRouter'da ücretli `z-ai/glm-4.7-flash`
**Reddetme sebebi:** Kullanıcı free istiyor; Z.ai direkt ücretsiz.

### C (seçilen): Ayrı ince ZaiProvider klonu
**Sebep:** Mevcut konvansiyona uyar (provider-per-file), izole, OpenAI-uyumlu olduğu için kod neredeyse birebir.

## 4. Riskler

| Risk | Etki | Olasılık | Mitigation |
|---|---|---|---|
| Z.ai endpoint/model-id farkı | orta | orta | Canlı test; 404→KotaHatasi ile sıradaki modele/sağlayıcıya düşer |
| Free kota/rate-limit | düşük | orta | Zincirde fallback zaten var (Gemini/Groq) |
| Tool-calling format farkı | orta | düşük | Z.ai OpenAI-uyumlu; aynı tool_calls şeması |

## 5. Done Criteria

- [ ] `ZaiProvider` build yeşil.
- [ ] DI + zincir kayıtlı.
- [ ] Asistan'da bir tool-use sorusu Z.ai üzerinden yanıt veriyor (canlı kanıt).
- [ ] `.env` ZAI_* dolu, key gizli (commit'lenmez — .env zaten gitignore).

## 6. Rollback

- `git revert <commit>` — provider izole, zincirden çıkar.
- `.env` ZAI_API_KEY boş bırak → ZaiProvider.Hazir=false → zincir Z.ai'yi atlar.

## 7. Adımlar

1. [ ] ZaiProvider.cs yaz (OpenRouter klonu, base-URL + header farkı).
2. [ ] Program.cs DI kaydı.
3. [ ] FallbackLlmProvider zincirine Zai (birincil) ekle.
4. [ ] .env ZAI_API_KEY + ZAI_MODELS.
5. [ ] Build + canlı test.

## 8. İlişkili
- Önceki: `plans/archive/21-*` (OpenRouter), `plans/archive/20-*` (LLM soyutlama).

## 9. Onay
- [ ] Onay alındı: <bekliyor>
