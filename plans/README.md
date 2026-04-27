# Planlar (Plan-First Sistemi)

Tier 3 işler için zorunlu plan dokümanları. Detay: `docs/ADR/003-plan-first-tier-system.md`.

## Tier sistemi

| Tier | Plan? | Örnek |
|---|---|---|
| **1 — Trivial** | YOK | Typo, version bump, config tarih güncellemesi, 1-2 dosya <30 satır |
| **2 — Standard** | TODO satırı yeterli | Küçük feature/fix, mevcut pattern, <5 dosya |
| **3 — Substantial** | TAM PLAN ZORUNLU | 3+ dosya yeni pattern, schema/security/UX, harici bağımlılık |

## Klasör yapısı

```
plans/
├── README.md                # bu dosya
├── feature-template.md      # Tier 3 plan şablonu
├── NN-<slug>.md             # aktif planlar (NN sıralı, örn. 01-mayis-kampanya.md)
└── archive/
    └── NN-<slug>.md         # tamamlanmış planlar
```

## Workflow

### 1. Plan yaz (Tier 3)

```bash
# Son plan ID'sini bul
ls plans/*.md | grep -E '^plans/[0-9]' | tail -1

# Yeni plan
cp plans/feature-template.md plans/01-mayis-kampanya-tahmini.md
```

Doldur: Problem, Scope, Alternatifler (en az 2 reddedilen), Riskler, Done criteria, Rollback, Adımlar.

### 2. Onay

Kullanıcıya göster, "tamam" / "şu değişiklik" / "iptal" geri bildirim al.

### 3. Implementation

- Her commit message'da plan referansı: `feat(bkm): X (plan: 01)`
- TODO.md'de plan adımları (Faz 0/1 altında)

### 4. Tamamlanma

- Plan dosyasını arşive taşı: `git mv plans/01-*.md plans/archive/`
- Done criteria check'le
- Journal'da plan'in çıktı özeti

## Tier nasıl tespit edilir?

Sezgisel kontroller:

- 3+ farklı klasöre dokunuyorum → Tier 3
- Yeni dosya tipi (yeni schema, yeni servis, yeni rule) → Tier 3
- Geri alınması zor (DB migration, security policy) → Tier 3
- Kullanıcı-görünür değişiklik → Tier 3
- Mevcut pattern + 1 dosya → Tier 1 veya 2
- Sadece içerik (typo, copy update) → Tier 1

Şüphede dururken: kullanıcıya sor.

## İstisnalar

### Acil bug fix (production down)
Plan-first bypass edilebilir ama:
1. Kullanıcıya: "Bypass yapıyorum, retro plan yazacağım"
2. Commit: `fix(<proje>): bug X (plan: BYPASS-<tarih>)`
3. Sonradan retro plan: `plans/archive/BYPASS-<tarih>.md`

### "Hızlıca yap"
- Tier 3 sinyali varsa uyarı: "Bu 3+ dosyayı etkiliyor, mini-plan yazayım mı (5 dk)?"
- "Direkt" derse: TODO'ya `[plan-skipped: <gerekçe>]` notu

## İlişkili

- `.claude/rules/plan-first.md` — kural detayı
- `.claude/rules/commit-discipline.md` — Tier 3 commit referansı
- `docs/ADR/003-plan-first-tier-system.md` — kararın gerekçesi
