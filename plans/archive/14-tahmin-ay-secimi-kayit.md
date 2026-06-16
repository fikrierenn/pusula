# Plan-14 — Tahmin: Ay Seçimi + Takvim Etmenleri + Kayıt/Karşılaştırma

**Tarih:** 16.06.2026
**Tier:** 3 (yeni parametre mantığı + harici API + kalıcı kayıt + karşılaştırma UI + takvim etmen modeli)
**Scope:**
- `dashboard/Components/Pages/Tahmin.razor`
- `dashboard/Data/Queries.cs`
- `dashboard/Data/TahminKayitService.cs` (yeni)
- `dashboard/Data/TakvimService.cs` (yeni)
- `dashboard/Models/PeriodModels.cs`
- `dashboard/Program.cs` (DI kayıt)
- `data/okul-takvimi.json` (yeni, elle) · `data/takvim-cache.json` (yeni, API cache)
- `.gitignore`

---

## Problem

/tahmin yalnızca mevcut ayı tahmin ediyor, salt YoY×ivme ile. CFO istiyor:
1. **Ay seçimi** — Temmuz/Ağustos gelecek ay tahmini.
2. **Takvim etmenleri** — özel gün/tatil/hafta sonu/okul açılış/bayram tahmine girsin.
3. **Kayıt** — tahmini sakla, ay sonu gerçekle kıyasla.
4. **İyileştirme** — model doğruluğunu (MAPE) ölç, işe yaramayan etmeni at.

### Asıl bug: kayan dini bayram YoY'u bozuyor
Mevcut model "geçen yıl aynı ay" der. Ramazan/Kurban her yıl ~11 gün kayar → geçen yıl Haziran'da bayram kapanışı vardı bu yıl yok (ya da tersi). YoY taban **yanlış mevsim** kıyaslıyor. Literatür çözümü: "bayramdan N gün önce/sonra" hizalama + kapalı-gün düzeltmesi.

---

## Veri Kısıtı (tasarımın temeli)

irsHrk ~25 ay günlük = her ay **~2 gözlem**. Çok-regresörlü ML (CNN-LSTM, 20 değişken) bizde **overfit**. Doğru yol: **deterministik çarpan/düzeltme** — her biri şeffaf, açıklanır, kayıt-karşılaştırma ile validasyonlu. İşe yaramayan çarpan atılır.

---

## Takvim Verisi Mimarisi

| Veri | Kaynak | Saklama | Yenileme |
|---|---|---|---|
| Ulusal + dini + arefe tatil | Google Apps Script API* | `data/takvim-cache.json` | Yılda 1 (manuel "Yenile" butonu) |
| Okul açılış/kapanış, LGS/YKS sınav | Elle (MEB takvimi) | `data/okul-takvimi.json` | Yılda 1 |

\* `https://script.google.com/macros/s/AKfycbzVHms-rNzPCAXTWQkqJncuHBhcaW9Yhx4vY_njRhkmQY3fdgmrcIyjCqyttkkcjEvo/exec`
- GET, key yok, DMY format (`localeDateString`), `date` = epoch ms.
- İçerir: dini bayram + **arefe yarım gün** + ulusal. `(kesin değil)` = gelecek dini bayram tahmini.
- **Gürültülü:** ör. 25.05.2026 fazladan "Sacrifice Feast Holiday" — temizle (dedup + bilinen pattern).
- **CANLI BAĞIMLILIK YASAK:** kişisel deployment, kaybolabilir. Sadece cache yenilerken çağrılır; tahmin daima cache'ten okur. API down → cache yaşar, log + uyarı.

---

## Veri Modeli (`PeriodModels.cs`)

```csharp
public record TahminKayitEntry(
    string Id, int Year, int Month, int MekanId,
    decimal Tahmin, decimal Alt, decimal Ust,
    decimal IvmePct, decimal YoYTaban,
    decimal? CarpanToplam,          // uygulanan takvim çarpanı (1.0 = etmen yok)
    string KayitTarih);             // "dd.MM.yyyy HH:mm"

public record TahminKarsilastirma(
    TahminKayitEntry Kayit,
    decimal? Gercek, decimal? SapmaPct);

public record TakvimGun(DateOnly Tarih, string Ad, TakvimTip Tip, bool YarimGun);
public enum TakvimTip { Ulusal, DiniBayram, OkulAcik, OkulKapali, Sinav }

public record AyEtmen(                // bir ay için hesaplanan etmen özeti
    int HaftaSonuSayisi, int TatilKapaliGun,
    bool OkulAcik, bool SinavAyi,
    decimal HaftaSonuCarpan, decimal OkulCarpan, decimal BayramDuzeltme);
```

---

## Etmen Modeli (deterministik)

```
Düzeltilmiş_tahmin = YoY_taban × (1 + ivme) × C_haftasonu × C_okul − D_bayram
```

| Etmen | Hesap | Gerekçe |
|---|---|---|
| **C_haftasonu** | bu_ay_haftasonu# / geçen_yıl_aynı_ay_haftasonu# | Ay 4 vs 5 cumartesi ciro farkı |
| **C_okul** | okul açık gün oranı eşleşmesi (bu ay vs taban ay) | Kırtasiye+sınav kitabı okula bağlı |
| **D_bayram** | (bu ay kapalı gün − taban ay kapalı gün) × günlük_ort | Kayan bayram kapanış düzeltmesi |
| **Sınav ayı** | LGS/YKS ayı bilgi rozeti (Haziran zirvesi) | Şimdilik bilgi; çarpan validasyon sonrası |

Her çarpan "Hesap Adımları" panelinde ayrı satır + değer + açıklama. Çarpan 1.0 ise "etkisiz" gösterilir.

**Validasyon kapısı:** çarpanlar opsiyonel toggle. MAPE'yi çarpanlı vs çarpansız kıyasla; düşürmüyorsa varsayılan kapalı.

---

## Adımlar

### Adım 1 — TakvimService.cs (yeni)
- `Load()` → `takvim-cache.json` + `okul-takvimi.json` birleşik `List<TakvimGun>`.
- `RefreshFromApiAsync()` → API çek, temizle (dedup, gürültü pattern), DMY parse, cache'e yaz. Hata → log + eski cache korunur (silent fail YOK).
- `GetAyEtmen(int year, int month)` → o ay için `AyEtmen` hesapla (hafta sonu#, kapalı gün#, okul durumu).
- Cache yoksa ilk açılışta tek sefer API çağrısı; sonra dosyadan.

### Adım 2 — Queries.cs: ay parametreli tahmin
- `GetTahminAsync(int year, int month, int mekanId, AyEtmen? etmen)`:
  - MTD: seçilen ay == bugün ay → gerçek MTD; geçmiş → tam ay gerçek; gelecek → 0.
  - İvme: son 3 **tamamlanmış** ay YoY (değişmez).
  - `etmen` verilirse çarpan/düzeltme uygula; sonuç `TahminSonuc`'a `CarpanToplam` ekle.
- `GetTahminKategoriAsync(int year, int month)` → aynı parametre.
- Geçmiş ay için `GetGercekCiroAsync(year, month, mekanId)` → karşılaştırma gerçeği.

### Adım 3 — TahminKayitService.cs (yeni)
- `data/tahmin-kayitlari.json` ↔ `List<TahminKayitEntry>`.
- `Save` (year+month+mekanId upsert), `Delete(id)`, `Load()`.
- Hata → log + boş liste fallback + kullanıcı uyarısı (silent fail YOK).

### Adım 4 — Program.cs DI
`AddSingleton<TakvimService>()`, `AddSingleton<TahminKayitService>()`.

### Adım 5 — Tahmin.razor: ay seçici + etmen paneli
- Header altı: `‹ [Haziran 2026] ›` (−24 ay … +3 ay sınır).
- Gelecek ay → MTD paneli gizli, "MTD yok — saf projeksiyon" notu.
- Geçmiş ay → "Ay tamamlandı · gerçek X ₺" + sapma.
- **Etmen paneli:** hafta sonu#, tatil kapalı gün, okul durumu, sınav rozeti + her çarpan satırı.
- Çarpan toggle (etmenli/etmensiz görünüm).

### Adım 6 — Tahmin.razor: kayıt + karşılaştırma + MAPE
- "Bu tahmini kaydet" → Save. Kayıtlıysa "Kaydedildi X ₺ · [Sil]".
- Geçmiş ay + gerçek → sapma paneli (Gerçek/Tahmin/±%).
- "Kayıtlı tahminler" accordion → son 12 (Ay, Tahmin, Gerçek, Sapma).
- **Model doğruluğu:** gerçek bilinen kayıtlardan MAPE → "ortalama ±X%". Etmenli vs etmensiz MAPE kıyas (etmenler işe yarıyor mu).

### Adım 7 — Denetim
- `.gitignore` → `data/` (kişisel veri + cache).
- API çağrısı timeout + try/catch + log (silent fail YOK).
- API gürültü temizleme test edilir (dedup doğru mu).
- `silent-failure-hunter` agent ile TakvimService + KayitService taraması.

---

## Riskler

| Risk | Önlem |
|---|---|
| Apps Script API ölür | Cache canlı; tahmin daima cache'ten. Refresh fail → eski cache + uyarı |
| API gürültüsü (fazladan kayıt) | Temizleme katmanı + dedup; bilinen pattern filtresi |
| Gelecek dini bayram `(kesin değil)` | Flag korunur, etmen "tahmini" işaretlenir |
| 25 ay = az veri, çarpan overfit | Çarpanlar toggle; MAPE validasyonu, düşürmüyorsa kapalı |
| Okul takvimi elle bayatlar | Yılda 1 hatırlatma; JSON eksikse C_okul=1.0 (etkisiz, güvenli) |
| JSON dosya bozulur | Try/catch + boş liste + uyarı |

---

## Done Criteria

- [ ] Ay seçici ile Temmuz/Ağustos tahmini görüntülenir
- [ ] Gelecek ay → "MTD yok" notu; geçmiş ay → gerçek + sapma
- [ ] TakvimService API'den çeker, `takvim-cache.json` oluşur, gürültü temizlenir
- [ ] `okul-takvimi.json` okunur; etmen paneli hafta sonu#/tatil/okul/sınav gösterir
- [ ] Çarpan toggle çalışır; "Hesap Adımları"nda her çarpan satırı görünür
- [ ] "Bu tahmini kaydet" → `tahmin-kayitlari.json`; sil çalışır
- [ ] Kayıtlı tahminler tablosu + MAPE skoru (en az 1 tamamlanmış kayıt)
- [ ] Etmenli vs etmensiz MAPE kıyası görünür
- [ ] API down senaryosunda cache'ten çalışır + uyarı (silent fail yok)

---

## Rollback
Yeni dosyalar silinir; `Tahmin.razor`/`Queries.cs`/`Program.cs` `git revert`. `data/` gitignore'da → veri kaybı yok.

---

## Sıra
1 (Takvim) → 2 (Queries) → 3 (Kayıt) → 4 (DI) → 5 (UI seçici/etmen) → 6 (UI kayıt/MAPE) → 7 (denetim). Sıralı; her adım öncekine bağımlı.

---

## Kilitli Kararlar (16.06.2026)

1. **Çarpanlar KAPALI başlar.** Tahmin önce salt YoY×ivme. Etmen çarpanları toggle ile açılır; birkaç ay kayıt birikip MAPE'yi düşürdüğü kanıtlanınca varsayılan açılır. Veri-güdümlü.
2. **API cache + elle düzeltme yeter.** Apps Script yılda 1 çekilir, `takvim-cache.json`'a yazılır, gürültü temizlenir. Ölürse cache + elle JSON düzenleme. Ek bağımlılık yok.

## Alternatifler (reddedilen)

- **Çok-regresörlü ML (Prophet/LSTM):** 25 ay veri yetersiz → overfit. Deterministik çarpan seçildi.
- **Nager.Date API:** dini bayram YOK (sadece 7 ulusal). Apps Script dini+arefe veriyor.
- **Hava durumu etmeni:** kitap/kırtasiye hava-duyarsız + geçmiş hava verisi saklanmıyor + API overhead. Sinyal/çaba düşük → kapsam dışı.
- **SQL Server kayıt tablosu:** DDL yetki belirsiz + migration. JSON dosya (tek kullanıcı) yeterli.
