# ADR-003 — Plan-First Tier Sistemi

## Durum

`Kabul edildi`

## Tarih

2026-04-27

## Proje

`crossproject`

## Bağlam

Kullanıcı geri dönüşü (Oturum 4):

> "Bu projede çalışma şeklimizi değiştiriyoruz. KOD YAZMAK YASAK — önce plan üretilecek."

Sonra hemen ardından:

> "en küçük şeye plan yapmakta mantıksız olabilir ama?"

İki gerilim:

1. **Disiplin ihtiyacı**: Atlasops adaptasyon oturumu (sabah) ve Mayıs kampanya scope'u (paralel oturum) gösterdi ki — büyük işler net plan olmadan başlayınca scope explosion + düzeltme döngüsüne giriyor. Plan-first bunun çözümü.

2. **Overengineering riski**: Her typo veya version bump için 200 satır plan yazmak disiplinin dead letter olmasıyla sonuçlanır. Kullanıcı disiplinden kaçar.

`docs/CONTEXT_MANAGEMENT.md` "İlke 6 — Spec → Plan → Execute" zaten 3+ dosya eşiği koymuş, ama sistemik değil — sadece soyut bir ilke. Operasyonel kural eksik.

## Karar

**3-Tier sistemi:**

| Tier | Plan zorunluluğu | Koşul |
|---|---|---|
| **1 — Trivial** | YOK | <30 satır, 1-2 dosya, sıfır yeni pattern |
| **2 — Standard** | TODO satırı yeterli | <5 dosya, mevcut pattern |
| **3 — Substantial** | TAM PLAN (`plans/NN-<slug>.md`) | 3+ klasör / yeni pattern / schema-security-UX / harici dep / kullanıcı-görünür |

Tier 3 commit'lerde plan referansı zorunlu (`(plan: NN)` mesajda).

## Sebepler

- Kullanıcı endişesi (küçük işlere plan zaman kaybı) haklı — Tier 1 dışında tutulur.
- Büyük işlerde (Tier 3) plan **gerçek scope explosion'ı önler** — Mayıs kampanyası 6+ adım oldu paralel oturumda; tam plan olmadan dağılırdı.
- Tier 2 zaten mevcut TODO disiplinini takip ediyor — yeni yük gelmiyor.
- Sezgisel "3+ dosya/klasör sinyali" — kullanıcının aklıyla eşleşen rasyonel eşik.

## Alternatifler (Reddedilenler)

### A: Blanket plan-first (her commit öncesi plan)
**Reddetme sebebi:** Kullanıcı uyarısı: "küçük şeye plan mantıksız". Disiplin dead letter olur, plan yorgunluğu yaratır, kullanıcı sistemi bypass eder.

### B: Vazgeç — TODO + ADR yeterli
**Reddetme sebebi:** Tier 3 işler bilfiil scope explosion üretti (atlasops adaptasyonu 6+ saat, Mayıs kampanya scope'u + execution ayrı). Mevcut sistem "sezgisel" ilke koymuş ama operasyonel disiplin yok.

### C: İki-tier (plan vs no-plan, eşik 5 dosya)
**Reddetme sebebi:** Tier 2 (mevcut pattern, küçük feature) ile Tier 1 (typo) farklı operasyonel ihtiyaç. Tier 2'de TODO satırı yeterli; Tier 1'de TODO bile yok. İki-tier'da bu nüans kaybolur.

### D: Plan zorunlu ama eşik = 10+ dosya
**Reddetme sebebi:** Çok yüksek eşik. 5-10 dosya aralığında gerçek mimari karar olabilir. Eşik 3+ klasör pratikte daha iyi çalışır.

## Sonuçlar

### Olumlu
- Tier 3 disiplinli, scope explosion önlenir.
- Tier 1/2'de plan-fatigue yok.
- Tier sinyalleri net (3+ klasör, schema vb.).
- Mevcut TODO + ADR + journal entegrasyonu kolay (plan referansı commit mesajında).

### Olumsuz / Risk
- Tier tespiti sübjektif. Mitigation: şüphede kullanıcıya sor.
- Plan archive'a taşınmazsa `plans/` şişer. Mitigation: handoff skill plan tamamlanma kontrolü (C-18).
- Pre-commit hook ile zorlanmıyor — manuel disiplin. Mitigation: gelecekte hook (C-17).

### Bilinmeyen
- 1-2 ay sonra plans/ ne kadar dolacak? Tier sınırları sertleştirilmesi gerekirse karara dön.

## Uygulama

- [x] `plans/` + `plans/archive/` klasörü
- [x] `plans/README.md` (klasör yapısı + workflow)
- [x] `plans/feature-template.md` (Tier 3 şablonu)
- [x] `.claude/rules/plan-first.md` (Tier eşikleri + workflow + istisnalar)
- [x] `.claude/rules/commit-discipline.md` güncellendi (Tier 3 plan referansı)
- [x] Bu ADR yazıldı
- [ ] **C-17**: Pre-commit hook (gelecekte) — Tier 3 sinyali varsa plan referansı yoksa uyarı (block değil, fail-soft)
- [ ] **C-18**: Handoff skill plan tamamlanma kontrolü
- [ ] Test: ilk Tier 3 işi (Mayıs kampanya tahmini, B-NEW serisi) bu şablon ile yazılsın

## İlişkili Dosyalar

- `plans/README.md`
- `plans/feature-template.md`
- `.claude/rules/plan-first.md`
- `.claude/rules/commit-discipline.md` (Plan-First Referansı bölümü)
- `docs/CONTEXT_MANAGEMENT.md` (§ İlke 6)
- ADR-001, ADR-002 (multi-project + paralel oturum — bu kararın temelinde)

## Referanslar

- Konuşma: `docs/journal/_crossproject/2026-04-27.md` (Oturum 4)
- TODO ID: `C-16` (kurulum), `C-17` (pre-commit hook), `C-18` (handoff plan check)
- Kullanıcı verbatim: "kod yazmak yasak — önce plan üretilecek" + "en küçük şeye plan yapmakta mantıksız olabilir ama?"
