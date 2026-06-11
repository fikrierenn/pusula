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

## Kullanım (gelecek)
- Rapor scriptleri köprü/kod/metrik tanımını buradan okur (hardcode yerine).
- MCP sorgu yazarken: doğru join `bridges.yaml`, doğru filtre `codes.yaml`/`metrics.yaml`.
