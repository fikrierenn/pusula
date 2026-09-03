# sema/ — BKM Structured Semantik Katman

Makine-okunur, canonical semantik katman. Script + MCP sorgu + rapor üretimi buradan beslenir.
İnsan-okunur özet: [`../sorgular/SEMANTIK_KATMAN.md`](../sorgular/SEMANTIK_KATMAN.md) (bu YAML'lardan türetilir/senkron).

## Dosyalar

| Dosya | İçerik |
|---|---|
| `entities.yaml` | Tablo/view sözlüğü — db, şema, PK, anahtar kolon, grain |
| `bridges.yaml` | **Köprüler** — cross-table/cross-db join tanımları (her biri confidence+evidence) |
| `codes.yaml` | Enum/lookup kodları (ehTip, eTip, emTip, COD durum, ödeme tipi, mekan/firma) |
| `metrics.yaml` | Türetilmiş iş mantığı (net ciro, depo hareket kategori, işgücü, COD ekonomi) |
| `degismezler.json` | **Koşulan** değişmezler — `python tools/sema_degismez.py`. Bayatlarsa kırmızı. `queries.yaml`'ın eksik yarısı: orada SQL saklanır, burada YENİDEN KOŞAR. Her kayıt `sunucu` taşır (`erp` · `zirve` · `joker`); yeni kayıt eklenince `--sadece <id>` ile **kırmızıya düştüğü kanıtlanır**. |
| `queries.yaml` | **Doğrulanmış sorgu kataloğu** — soru + golden SQL + last_verified (Vanna/dbt saved_queries pattern). Yeni sorgu yazarken ÖNCE buraya bak; yeni doğrulanan değerli SQL'i buraya ekle. |

## Esin kaynakları (10.06 araştırması)
dbt MetricFlow (saved_queries, derived/ratio metrik), Cube.dev (joins+measure tipleri), Wren AI MDL (kolon description = LLM intermediate representation), Vanna.ai (question+verified_sql çifti), OSI (vendor-neutral spec). Bizim fark: `confidence`+`evidence` alanları (continuous-learning).

## Continuous-Learning Disiplini (ECC instinct pattern uyarlaması)

Yeni şema gerçeği (köprü / tablo / kod / metrik) **öğrenilince**:
1. İlgili YAML'a **atomic** ekle — `id`, `confidence` (0.3-1.0), `evidence` (tarih + nasıl doğrulandı), `scope`.
2. `updated:` tarihini güncelle.
3. Köprü/kod ise `sorgular/SEMANTIK_KATMAN.md` insan-özetine de yansıt.
4. Belirsizse `status: teyit bekliyor` ile düşük confidence ekle — sonra doğrula.

**Tetik:** MCP `sql_query` yeni bir bağ/kod/grain ortaya çıkarınca. Skill: `/sema-ogren`. Kural: `.claude/rules/semantic-layer.md`.

## Confidence ölçeği
- `1.0` — kalıcı, defalarca doğrulandı (PK/FK, ehTip).
- `0.9-0.99` — canlı doğrulandı, yüksek eşleşme (%99+).
- `0.5-0.8` — gözlemlendi ama tam teyit yok.
- `0.3-0.5` — hipotez / teyit bekliyor.

## Yaşlanma / Decay (plan-12 WS-1 — Hermes curator uyarlaması)

Doğrulanmış gerçek zamanla bayatlar (şema değişir, kolon kalkar). Fact-Force Gate'in eksik yarısı: gerçek **yaşlanır**, süresi dolunca **yeniden-doğrulama** ister. Bu, sessiz-yanlış-rakam riskini azaltır (stkKod=barkod / depo key-mismatch vakalarının tekrar kaynağı = bayatlamış varsayım).

### Opsiyonel alanlar (geriye-uyumlu — okumayan kod etkilenmez)
- `last_verified: YYYY-MM-DD` — bu kaydın canlı sorguyla EN SON doğrulandığı tarih (`evidence` tarihinden farklı olabilir; evidence = ilk keşif, last_verified = son teyit).
- `ttl_days: <int>` — yeniden-doğrulama aralığı (gün). Yoksa confidence'tan türetilir (aşağı).

### Decay kuralı
- **`confidence: 1.0` MUAF** — kalıcı PK/FK/ehTip; yaşlanmaz, ttl gerekmez (pinned eşdeğeri).
- Confidence <1.0 kayıtlarda varsayılan ttl:
  - `0.9-0.99` → 180 gün
  - `0.5-0.8` → 90 gün
  - `0.3-0.5` → 30 gün (hipotez, erken teyit)
- **Süre dolumu** = `last_verified + ttl_days < bugün` → kayıt **stale** (bayrak; OTOMATİK aksiyon DEĞİL — silinmez/değişmez, sadece "yeniden doğrula" işareti).
- **Yeniden doğrulanınca** `last_verified` güncellenir (confidence aynı/yükselir). Çürürse `sema-ogren` çelişki kuralı (sil/düşür).

### Curator-check (inactivity-triggered, cron YOK)
`session-handoff` skill'i çalışırken son curator-check üstünden ≥7 gün geçtiyse hafif tarama: stale kayıt + çakışan/dar kayıt listesi. Derin konsolidasyon → `consolidate-sema` skill'i (dry-run, mutasyonsuz rapor + onay). Detay: `.claude/rules/semantic-layer.md`, `.claude/skills/consolidate-sema/SKILL.md`.

## Kullanım (gelecek)
- Rapor scriptleri köprü/kod/metrik tanımını buradan okur (hardcode yerine).
- MCP sorgu yazarken: doğru join `bridges.yaml`, doğru filtre `codes.yaml`/`metrics.yaml`.
