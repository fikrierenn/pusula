# Plan-15 — Tahmin Motoru: Python + Öğrenen Katman (Faz 1: Toplam Ciro)

**Tarih:** 16.06.2026
**Tier:** 3 (yeni dil/servis sınırı, yeni metodoloji, harici kütüphane, öğrenen mimari)
**Karar:** Python motor (`scripts/forecast/`) + öğrenen katman; Faz 1 = toplam ciro. Hiyerarşik (kategori→marka→ürün→adet) = ayrı faz (plan-16, bu planın üstüne biner).

---

## Problem

Mevcut tahmin (B-73 + plan-14) bir **heuristik**: `tahmin = geçen_yıl × (1 + son3ay_ortalama_YoY) × çarpan`. Sorunlar:
1. **İstatistiksel temel yok.** Level/trend/mevsimsellik/tatil ayrışması yok; belirsizlik (band) ad-hoc (±std).
2. **Faktörler yamanmış.** Hafta sonu/tatil çarpanı modele dışarıdan çarpılıyor — gerçek regresör değil.
3. **Öğrenme yok.** Model hatasını ölçmüyor, nereyi şaşırdığını bilmiyor, kendini düzeltmiyor.
4. **Tek yöntem.** Alternatif yok; yöntem yarışı/ensemble yok.

CFO talebi: "tüm varsayım/hesap mantığı yazılsın+kaydedilsin, nereyi düzelttiğini bil, öğrenen katman olsun, ciddi metodoloji."

---

## Veri Kısıtı (tasarımın temeli — DÜRÜST)

- **DÜZELTME (16.06):** irsHrk günlük seri **2021-06 → 2026-06 = 1842 gün ≈ 5 yıl** (CLI doğrulandı). Eski "25 ay" yanılgısı: aylık heuristik sadece son-25-ayı çekiyordu; ham günlük veri 5 yıl. → **5 sınav sezonu gözlendi**, yıllık mevsimsellik sağlam temelli.
- Aylık grain'de model veri-aç olurdu; ama **günlük grain (1842 gün)** → haftalık + yıllık Fourier mevsimsellik + tatil regresörü rahat çalışır.
- **Karar: günlük modelle, aya topla.** Aylık hedef = günlük tahminlerin ay-toplamı.
- Bugün (kısmi gün) eğitimden çıkarılır (son tam güne kadar). Belirsizlik bandda gösterilir.

---

## Mimari

```
SQL Server (irsHrk günlük net)
   │  pymssql (mevcut _errors.connect_with_retry)
   ▼
scripts/forecast/  (Python motor — YENİ)
   ├─ data.py        SQL → günlük seri DataFrame
   ├─ calendar.py    tatil/okul/hafta sonu regresör matrisi (dashboard/data/*.json'dan)
   ├─ models.py      aday yöntemler: seasonal_naive, ets, prophet, heuristik(mevcut)
   ├─ backtest.py    rolling-origin backtest + hata atıfı
   ├─ learn.py       adaptif ensemble (AEC+unutma) + bias düzeltme
   ├─ explain.py     şeffaflık: varsayım/bileşen/regresör → kayıt
   └─ run.py         orkestrasyon → çıktı JSON + (ops.) SQL tablo
   ▼
data/forecast/  (çıktı — C# okur)
   ├─ tahmin-aylik.json       aktif tahmin + bileşen kırılımı + band
   ├─ backtest-gecmis.json    rolling-origin hata geçmişi (öğrenme kanıtı)
   └─ yontem-agirlik.json     adaptif ensemble ağırlıkları (hangi yöntem ne kadar)
   ▼
dashboard/ (C# Blazor — sadece GÖSTERİR)
   └─ Tahmin.razor + TahminKayitService genişler: JSON okur, bileşen+öğrenme panelleri
```

**Neden Python:** Prophet/statsforecast/sktime olgun; C#'ta karşılığı yok. Repo'da zaten pymssql Python rapor altyapısı var (`scripts/*.py`, `_errors.py`). Tek-dil ısrarı metodolojiyi sakatlar.

---

## Metodoloji (Faz 1 — toplam ciro)

### Aday yöntemler (6 — yarışır)
> **Karar (16.06):** statsforecast kullanıcı tarafından global Python312'ye kuruldu (OK). Aylık grain'de 60 nokta/5 sezon → AutoETS/AutoARIMA çalışır. Günlük yıllık-mevsim için saf-numpy GLM (Prophet özü, MCMC'siz, bileşen atıfı katsayıdan). Karma havuz: günlük-grain GLM + aylık-grain statsforecast + basit baseline'lar. Hepsi aylık toplam üretir → backtest'te kıyaslanır.

1. **seasonal_naive** — geçen yıl aynı ay toplamı (baseline; her şey bunu yenmeli). [numpy]
2. **glm_calendar** — OLS günlük: lineer trend + Fourier(7 haftalık)+Fourier(365 yıllık) + **tatil/okul dummy regresör** → aya topla. Katsayılar = bileşen atıfı. [numpy]
3. **dow_ewma** — günlük EWMA seviye × gün-of-hafta profili × ay endeksi. Basit-robust. [numpy]
4. **heuristik** — mevcut YoY×ivme (geriye-uyumluluk + karşılaştırma tabanı). [numpy]
5. **autoets** — statsforecast AutoETS aylık (season_length=12). [statsforecast]
6. **autoarima** — statsforecast AutoARIMA aylık mevsimsel (season_length=12). [statsforecast]

Tatil/okul = **gerçek regresör** (glm_calendar dummy sütunları), çarpan değil. Kaynak: `scripts/forecast/calendar_reg.py` gömülü TR tatil tablosu 2021-2027 + `dashboard/data/okul-takvimi.json`.

### Çıktı
Aktif tahmin = adaptif ensemble (aşağıda). Aylık toplam + senaryo bandı = günlük tahmin dağılımından (kantil), ad-hoc ±std değil.

---

## Öğrenen Katman (CFO'nun asıl isteği — dokümante pattern)

### 1. Şeffaf kayıt (explain.py)
Her tahmin → JSON'a: yöntem, ensemble ağırlıkları, kullanılan regresör değerleri, **bileşen kırılımı** {trend, haftalık_mevsim, yıllık_mevsim, tatil_etki, taban}, tahmin + band. "Ne varsayım, ne hesap" tam yazılı.

### 2. Rolling-origin backtest (backtest.py)
Her geçmiş ay için: "o ayın başında olsaydım" → her yöntemle tahmin → gerçekle kıyas. Üretir: yöntem×ay hata matrisi. **Bu, öğrenmenin eğitim verisi.** (Veri sızıntısı yok — sadece o tarihe kadarki veriyle.)

### 3. Hata atıfı (backtest.py)
Tahmin hatasını bileşene ayır: taban mı şaştı, tatil düzeltmesi mi, trend mi? Bileşen-bazlı residual saklanır → "nereyi düzelttiğini bil".

### 4. Adaptif ensemble — AEC + unutma faktörü (learn.py)
Yöntem ağırlıkları son N ayın MAPE'sine göre (unutma faktörü λ ile yakın aylar ağır). İşe yarayan yöntem kazanır. ([AEC/continuous learning](https://arxiv.org/html/2402.13916v1))

### 5. Bias düzeltme (learn.py)
Bir yöntem sürekli işaretli sapma (hep +%X şişirme) gösteriyorsa öğrenilen katsayıyla düzelt. (Dokümante: %50'ye varan iyileşme.)

### Öğrenme = zamanla
Gün 1'de akıllı değil; her ay-kapanışı bir eğitim sinyali. Backtest geçmiş aylarla **anında bir başlangıç** verir (soğuk-başlangıç değil).

---

## Veri Akışı + Saklama

- **Girdi:** irsHrk günlük net (mevcut filtreler — ehTip/iade sign), 3 mağaza. Tatil/okul JSON (plan-14).
- **Çıktı:** `data/forecast/*.json` (C# okur). Opsiyonel `bkm.ForecastSonuc` SQL tablosu (ileride, hiyerarşik için).
- **Tahmin kaydı:** mevcut `tahmin-kayitlari.json` korunur; ek olarak motor çıktısı + bileşen. CFO "kaydet" → o anki ensemble snapshot'ı.
- **Tetik:** elle (dashboard "Yenile" → script çağrısı) VEYA zamanlanmış (mevcut bat/scheduled-task altyapısı, generate_brief gibi).

---

## Entegrasyon (C# tarafı)

- `TahminKayitService` genişler / yeni `ForecastOkuService`: `data/forecast/*.json` okur (TakvimService cache pattern'i).
- `Tahmin.razor`: bileşen kırılım paneli (trend/mevsim/tatil), yöntem-ağırlık paneli (hangi yöntem ne kadar), backtest doğruluk grafiği (MAPE zaman serisi).
- Mevcut ay seçici + kayıt + MAPE (plan-14) korunur; motor çıktısıyla beslenir.

---

## Riskler

| Risk | Önlem |
|---|---|
| 2 sezon → yıllık mevsim belirsiz | Bandda göster; seasonal_naive baseline; abartma |
| Python↔C# köprü kırılganlığı | JSON sözleşmesi sabit; C# eski JSON'u toleranslı okur (versiyon alanı) |
| Prophet bağımlılık ağır (pystan/cmdstan) | statsforecast (hafif) öncelik; Prophet ops. Aday havuzu kütüphane-agnostik |
| Öğrenme drift (kötü yöne) | Bias/ağırlık clamp + her değişiklik loglu; seasonal_naive tabanın altına düşemez |
| Script sessiz yanlış rakam | _errors retry + silent-failure-hunter + backtest sayısal mutabakat (MCP eski/yeni) |
| Motor yoksa dashboard boş | C# son başarılı JSON'u cache'ler; "motor çalışmadı" uyarısı (sessiz değil) |

---

## Done Criteria (Faz 1)

- [ ] `scripts/forecast/` motoru çalışır: SQL → günlük seri → aday yöntemler → ensemble → JSON
- [ ] En az 4 aday yöntem (seasonal_naive, ets, prophet, heuristik) backtest'te yarışır
- [ ] Tatil/okul **regresör** olarak girer (çarpan değil)
- [ ] Rolling-origin backtest geçmiş ay hata matrisi üretir (veri sızıntısı yok)
- [ ] Bileşen kırılımı (trend/mevsim/tatil/taban) JSON'a yazılır + dashboard'da görünür
- [ ] Adaptif ensemble ağırlıkları + bias düzeltme uygulanır + loglanır
- [ ] Dashboard motor JSON'unu okur; bileşen + yöntem-ağırlık + backtest-doğruluk panelleri
- [ ] Sayısal mutabakat: motor toplam ciro ≈ mevcut MCP/irsHrk (sapma açıklanır)
- [ ] silent-failure-hunter + python-reviewer temiz
- [ ] Motor down → dashboard son JSON + uyarı (sessiz değil)

---

## Rollback
Motor ayrı (`scripts/forecast/`, `data/forecast/`). C# tarafı yeni okuma servisi ekler; mevcut heuristik `GetTahminAsync` korunur (fallback). Motor JSON yoksa C# eski heuristiğe düşer + uyarı. Tam geri alma = yeni dosyaları sil + C# fallback aktif.

---

## Adımlar (Faz 1)

1. `scripts/forecast/data.py` — SQL günlük seri (mevcut connect pattern + filtreler).
2. `calendar.py` — tatil/okul/DOW regresör matrisi (plan-14 JSON'dan).
3. `models.py` — 4 aday yöntem (kütüphane-agnostik arayüz: fit/predict).
4. `backtest.py` — rolling-origin + hata atıfı + yöntem×ay matrisi.
5. `learn.py` — AEC ağırlık + bias düzeltme.
6. `explain.py` + `run.py` — bileşen kırılımı + orkestrasyon → `data/forecast/*.json`.
7. Sayısal mutabakat + python-reviewer + silent-failure-hunter.
8. C# `ForecastOkuService` + `Tahmin.razor` panelleri (bileşen/ağırlık/backtest).
9. requirements: `scripts/forecast/requirements.txt` (pandas, statsforecast, [ops.] prophet).

**Sıra:** 1→2→3→4→5→6→7 (motor tam+doğrulanmış) → 8 (UI) → 9 boyunca. Motor C#'tan bağımsız test edilir (CLI).

---

## Faz 2 (ayrı plan — plan-16, ÖN-NOT)
Hiyerarşik: toplam→kategori→marka→ürün→**SKU adet**.
- Her seviye tahmin + **MinT reconciliation** (çocuklar toplama eşit, bias'sız).
- SKU adet: çoğu ürün seyrek talep → **Croston/SBA/TSB** (normal model patlar).
- Yeni ürün (geçmiş yok) → kategori/benzer-ürün profili.
- Bu planın motoru (data/calendar/backtest/learn) yeniden kullanılır; üstüne hiyerarşi + reconciliation biner.

---

## Alternatifler (reddedilen)
- **C#'ta motor:** Prophet/MinT/Croston yok → elle klasik yazım, hata+sınırlı. (Karar: Python.)
- **Saf derin öğrenme (LSTM/Transformer):** 25 ay veri yetersiz → overfit. Klasik+ensemble daha sağlam.
- **Tek yöntem (sadece Prophet):** yöntem yarışı/ensemble robustluğu kaybolur; Prophet her ayda en iyi değil.
- **Aylık grain model:** ~2 gözlem/ay → veri-aç. Günlük modelle-aya-topla seçildi.
- **Doğrudan hiyerarşik (Faz 1'de):** öğrenen altyapı olmadan büyük; önce toplam+öğrenme (kullanıcı kararı).
