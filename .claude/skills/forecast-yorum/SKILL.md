---
name: forecast-yorum
description: Tahmin motoru (plan-15) çıktısını yorumlar — data/forecast/*.json (tahmin-aylik, yontem-agirlik, backtest-gecmis) okuyup hangi model neden iyi/kötü, ensemble ağırlık dağılımı, bias eğilimi, band güvenilirliği analiz eder. "tahmin yorumla", "model neden kötü", "AutoARIMA niye düştü", "ensemble ağırlık öner", "backtest analiz", "/forecast-yorum" denildiğinde devreye gir.
---

# forecast-yorum — Tahmin Motoru Analiz/Yorum

plan-15 motoru `scripts/forecast/` 6 model yarıştırıp `data/forecast/*.json` üretir (ensemble + backtest + öğrenilen ağırlık). Bu skill o çıktıyı **okur ve yorumlar** — sayıları iş diline çevirir, model davranışını açıklar. Motoru ÇALIŞTIRMAZ (o `python scripts/forecast/run.py`), sadece sonucu yorumlar.

## Ne zaman tetiklenir
- "Bu ayın tahmini neden böyle / model neden kötü / X niye düştü."
- "Ensemble ağırlıkları doğru mu, öneri var mı."
- "Backtest doğruluğu / bias / band güvenilir mi."
- Aylık motor koşumu sonrası özet istenince.

## Kaynak dosyalar (oku)
- `dashboard/data/forecast/tahmin-aylik.json` — aktif aylar: ensemble point/band, model katkıları, bileşen kırılımı (trend/mevsim/tatil), atlanan modeller.
- `dashboard/data/forecast/yontem-agirlik.json` — öğrenilen: model×{wmape, bias_pct, agirlik}, band {alt/üst/ensemble_mape}, ozet (ham mape/n).
- `dashboard/data/forecast/backtest-gecmis.json` — rolling-origin: model×ay×{tahmin, gercek, ape}.

## Analiz adımları
1. **Model sıralaması:** wmape artan → en iyi/kötü. Ağırlık dağılımı (kim dominant). Elenen (ağırlık 0, mape>tavan) modeller.
2. **Bias yönü:** model sürekli şişiriyor mu (+) / düşürüyor mu (−). De-bias sonrası ensemble bias'ı.
3. **Backtest derinliği:** kaç ay (n), MAPE zaman içinde artıyor mu (rejim değişimi sinyali). Bir modelin belirli aylarda patlaması (mevsimsel zayıflık).
4. **Bileşen:** glm_calendar kırılımı — tahmin çoğunlukla taban/trend mi, mevsim mi, tatil mi sürüyor.
5. **Band:** ensemble_mape ile band genişliği tutarlı mı; gerçek band içine düşüyor mu (backtest'ten).
6. **Atlanan:** gelecek ay heuristik atlanmış mı (yakın momentum yok) — şeffaflık.

## Yorum çıktısı (iş dili)
- "Bu ay tahmin X ₺ (band Y–Z). En güvenilir model heuristik (MAPE %7,3), ağırlık %44. AutoETS sürekli %11 düşük tahmin ediyor (bias −%11) → de-bias düzeltiyor."
- Öneri: "dow_ewma elendi (MAPE %63) — kaldırılabilir. Veri biriktikçe band daralır."
- Uyarı: rejim değişimi (son aylar MAPE artışı), tek-model bağımlılığı, az-veri ayları.

## Sınırlar
- JSON yoksa → "motor çalışmamış, `python scripts/forecast/run.py` çalıştır."
- Ağırlık/parametre DEĞİŞTİRMEZ — öneri sunar; uygulama `scripts/forecast/learn.py` parametresi (lam, mape_tavan) elle.
- Az veri gerçeğini saklamaz (2 değil ama 5 yıl/sezon; yine de belirsizlik bandda).

## İlişkili
- `plans/archive/15-tahmin-motoru-ogrenen.md` (mimari), `scripts/forecast/*.py` (motor).
- Dashboard görünüm: `/tahmin` (Tahmin.razor) + `ForecastOkuService`. Hesap mantığı `learn.py`/`backtest.py`.
