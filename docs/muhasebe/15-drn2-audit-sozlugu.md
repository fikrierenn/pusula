# `dbo.drn2` Audit Sözlüğü — `izProgID = 55` (mhs)

> **Tarih:** 11.05.2026
> **Bağlam:** Önceki turlardaki "islem=14 = Kapanış" varsayımı **YANLIŞ** çıktı.
> Canlı drn2 sorgusuyla audit kodlarının tam haritası çıkarıldı.

---

## 1. izProgID = 55 → mhs Modülü Audit'i

mhs schema'daki tüm sistemli işlemler `dbo.drn2` tablosuna `izProgID = 55`
ile yazılır. `islem` kolonu ise **işlem tipini** belirler. Aynı `islem` kodu
birden fazla SP tarafından kullanılabilir — `islemNot` text formatından
gerçek SP tahmin edilir.

---

## 2. islem Kodu Sözlüğü

| islem | Kullanan SP | islemNot Formatı | Notu |
|---:|---|---|---|
| **2** | `mhsFisB_ekle` (insert) | `"yevmiyeNo dd.MM.yyyy [entTip] kaydedildi"` | Tek satır CRUD insert |
| **3** | `mhsFisB_ekle` (update) | `"yevmiyeNo dd.MM.yyyy [entTip] değiştirildi"` | Tek satır CRUD update |
| **4** | `mhsFis_sil` | `"yevmiyeNo dd.MM.yyyy [entTip] silindi"` | Tek fiş tamamen sil |
| **4** | `mhsFis_cikar` | `"yevmiyeNo-dd.MM.yyyy [entTip] [BelgeID] çıkarıldı"` | Aynı kod, farklı format |
| **5** | `mhsFis_onay` (@onay=1) | `"yevmiyeNo dd.MM.yyyy [entTip] onay durum=1"` | Onaylama |
| **6** | `mhsFis_onay` (@onay=0) | `"yevmiyeNo dd.MM.yyyy [entTip] onay durum=0"` | Onay kaldırma |
| **14** | `mhsKapanis` | `"Kapanış fişi oluşturuldu. Şirket no:X"` | ⚠️ Çok-amaçlı kod |
| **14** | **`mhsSirala`** (yeni keşif) | `"Sıralama yapıldı. Şirket no:X"` | Aynı kod, sıralama mesajı |
| **14** | **Yıl başı açılış kaydı** (SP belirsiz) | `"1 dd/MM/yyyy [0] kaydedildi"` | yevmiyeNo=1 + 01/01 → açılış |
| 7-13, 15+ | _bilinmiyor_ | _bilinmiyor_ | Henüz canlı veri görülmedi |

→ **Önemli düzeltme:** `islem=14` "Kapanış" değil, **"sistemli muhasebe
operasyonu"** üst kategorisi. mhsKapanis, mhsSirala ve açılış SP'si
hepsi aynı kodu paylaşıyor — UI'da bu işlemler "yıl atlama wizard'ı"
gibi tek bir akışın parçası olarak gruplanmış olabilir.

---

## 3. Canlı Audit'ten Çıkan Pattern'lar

### 3.1 Yıl Atlama Pattern'ı (gece yarısı)

```
2026-01-01 01:41  kKisi=145  "Kapanış fişi oluşturuldu. Şirket no:5"   ← mhsKapanis
2026-01-01 01:43  kKisi=6    "1 01/01/2026 [0] kaydedildi"             ← Açılış (yevmiyeNo=1)

2025-01-01 16:23  kKisi=145  "Kapanış fişi oluşturuldu. Şirket no:4"   ← mhsKapanis
2025-01-01 16:26  kKisi=5    "1 01/01/2025 [0] kaydedildi"             ← Açılış

2024-01-01 18:13  kKisi=145  "Kapanış fişi oluşturuldu. Şirket no:3"   ← mhsKapanis
2024-01-01 18:14  kKisi=4    "1 01/01/2024 [0] kaydedildi"             ← Açılış
```

**Net pattern:** Yıl başında (01.01) → mhsKapanis (eski yılı kapat) → 1-3
dakika sonra → "1 [tarih] [0] kaydedildi" (yeni yılın 1. yevmiye no'lu fişi).

→ **Bu mhs.mhsAcilis veya benzeri bir SP'nin varlığını doğrular.** Henüz
keşfedilmedi (mhs schema'da bu isimle obje yok). Olasılıklar:
- UI'dan `mhsFisB_ekle` çağrılıyor ama farklı islem kodu (14) ile audit yazıyor
- Bizim listemizdeki "mhsFis_ekle" SP'si de `islem=14` kullanıyor olabilir
  (henüz audit format'ı kontrol edilmedi)
- Henüz keşfetmediğimiz bir SP var (encrypted çıktığı için kaynak görülemedi)

### 3.2 Mali Müşavir Tashih Pattern'ı (kapanışın tekrarlanması)

```
Şirket 5 (2025) için kapanış kayıtları:
  2026-01-01 01:41  ← İlk kapanış (yıl başı otomatik)
  2026-02-11 11:39  ← 2. tashih
  2026-02-16 12:57  ← 3. tashih
  2026-04-08 12:55  ← 4. tashih
  2026-04-28 09:45  ← 5. tashih (en son)

Şirket 4 (2024) için 5 kez kapanış (2025-02 → 2025-05)
Şirket 3 (2023) için 5 kez kapanış (2024-01 → 2024-05)
Şirket 2 (2022) için 6+ kez kapanış (2023-01 → 2023-05)
```

**Operasyonel anlamı:** BKM yıl-sonu kapanışını **birden fazla kez**
yapıyor. Her tashih şu adımları içeriyor:
- Mali müşavir mizan kontrolü → düzeltme mahsupları
- Önceki kapanış fişi UI'dan silinir (drn2'de görünmüyor → mhsFis_sil
  beklenir ama kapanış için islem=4 audit yok... başka mekanizma olabilir)
- Yeni mhsKapanis çağrısı

→ **Kritik soru:** Yapılan eski kapanış fişleri tabloda kalıyor mu yoksa
silindi mi? `mhs.mhsFisBaslik WHERE fisAd='Kapanış' AND fisbSirketID=5`
sorgusu bunu ortaya çıkarır.

### 3.3 Sıralama (`mhsSirala`) Pattern'ı

mhsSirala **çok sık** çağrılıyor:
- Ay sonu (2-3 gün boyunca yoğun): muhasebeci aylık kapanış öncesi sıralama yapıyor
- Yıl-sonu kapanış civarında (Kasım/Aralık ve Ocak): kapanışa hazırlık
- Mali müşavir tashih dönemlerinde: kapanış tashihi sırasında

→ **mhsSirala** muhtemelen **`mhsSirket.sirketSiraliTarih`'i ileri
güncelliyor** (kapanmış dönem tarihi). Sıralama yapılınca o tarihten önceki
fişler kilit altına alınıyor (mhsFis_sil/cikar/Kapanis koruması).

### 3.4 Aktif Kullanıcılar (kKisi audit'ten)

| kKisi | Tahmini rol | İşlem türü |
|---:|---|---|
| **145** | Mali müşavir / senior muhasebeci | Yıl başı otomatik kapanış (gece yarısı) |
| **450** | Operasyonel muhasebeci | En sık sıralama yapan |
| 449 | Operasyonel muhasebeci 2 | Sıralama (450 ile aynı sıkılıkta) |
| 16 | Senior muhasebeci | Sıralama + bazı kapanışlar |
| 137 | Eski mali müşavir? | 2023'te aktif, sonra yok |
| 136 | Eski operasyonel? | 2021-2023 aktif, sonra yok |
| **6** | 2026 yılı açılış kaydı kullanıcısı | Açılış fişini yaratan |
| 5 | 2025 yılı açılış kullanıcısı | (önceki yıl) |
| 4 | 2024 yılı açılış kullanıcısı | (önceki yıl) |
| 3 | 2023 yılı açılış kullanıcısı | (önceki yıl) |
| 2 | 2022 yılı açılış kullanıcısı | (önceki yıl) |

→ **Pattern:** Açılış kullanıcısı ID'si yıllarla aynı sayı + 1 (sirketID).
2026 → kKisi=6, 2025 → kKisi=5, 2024 → kKisi=4. Bu **"sirketID = açılış
kullanıcı ID"** kuralı olabilir veya tesadüf.

---

## 4. mhs.mhsSirket — Şirket / Mali Yıl Tablosu

Canlı sorgu (11.05.2026):

| sirketID | sirketAd | sirketDonem | sirketOnce | sirketSiraliTarih | sirketSonFisID |
|---:|---|---:|---:|---|---:|
| 1 | Bkm Kitap Kırtasiye | 2021 | 0 | 31.12.2021 | 5.979.219 |
| 2 | BKM Kitap Kırtasiye | 2022 | 0 | 31.12.2022 | 10.184.739 |
| 3 | BKM Kitap Kırtasiye | 2023 | 0 | 31.12.2023 | 13.358.544 |
| 4 | BKM Kitap Kırtasiye | 2024 | 0 | 31.12.2024 | 15.366.992 |
| 5 | BKM Kitap Kırtasiye | 2025 | 0 | 30.11.2025 | 15.449.238 |
| **6** | **BKM Kitap Kırtasiye** | **2026** | **1** | 31.12.2025 | **0** |

### Bulgular

- **`sirketID = sirketDonem - 2020`** → Şirket numarası mali yıldan basit map
  (2021 → 1, 2026 → 6). Yıl atladığında BKM yeni `sirketID = max+1` ekliyor.
- **`sirketOnce = 1` SADECE şirket 6'da** (2026) — `cariIsle_oto`'nun
  filtresi (`WHERE sirketOnce=1 AND YEAR(GETDATE())=sirketDonem`) doğru
  şekilde 2026'yı yakalıyor.
- **`sirketSonFisID = 0` SADECE şirket 6'da** — 2026 henüz kapatılmamış,
  diğer 5 yıl kapatılmış (mhsKapanis çağrılmış).
- **`sirketSiraliTarih`** ilginç:
  - Şirket 5 (2025): **30.11.2025** → 2025 Kasım sonuna kadar fişler
    kilitli, Aralık fişleri hâlâ silinebilir/çıkarılabilir
  - Şirket 6 (2026): **31.12.2025** → 2025 sonuna kadar kilitli, 2026 yılı
    içi fişlerde değişiklik serbest (henüz hiç sıralama yapılmamış)
  - Bu kolon **mhsSirala** tarafından güncelleniyor olmalı (audit'te en sık
    görünen işlem)

---

## 5. Düzeltilecek Önceki Belgeler

### 5.1 [`12-yil-sonu-kapanis-analizi.md`](./12-yil-sonu-kapanis-analizi.md) #5.4

**Eski (yanlış):**
> drn2 İslem Kodu Sözlüğüne YENİ EKLEME: 14 = Kapanış (yeni)

**Düzeltme:**
> drn2.islem=14 çok-amaçlı: Kapanış (mhsKapanis) + Sıralama (mhsSirala) +
> Yıl başı açılış kaydı (SP belirsiz). Tek SP'ye atfedilemez. Ayırt etmek
> için `islemNot` text format'ı kullanılır.

### 5.2 [`00-INDEX.md`](./00-INDEX.md)

**Eski:**
> islem sözlüğü 2=Kaydet/3=Değiştir/4=Sil veya Çıkar/5=Onay/6=Onay kaldır/14=Kapanış

**Düzeltme:**
> islem sözlüğü 2=Kaydet/3=Değiştir/4=Sil veya Çıkar/5=Onay/6=Onay kaldır/
> 14=Sistemli muhasebe operasyonu (Kapanış + Sıralama + Yıl başı açılış)

---

## 6. Encrypted SP'ler — Kaynak İstenmeli

Aşağıdaki 5 SP `WITH ENCRYPTION` ile derlenmiş, `sys.sql_modules.definition`
NULL döndürüyor. Kaynak BKM'den manuel istenmeli (DerinSIS standart
SP'leri encrypted, BKM özel yazılan `cariIsle_oto` encrypted değil).

| SP | Önemi | İlişkili audit |
|---|:--:|---|
| **`mhsSirala`** | YÜKSEK | islem=14 "Sıralama yapıldı." — en sık çağrılan |
| `mhsSonYevmiyeNo` | DÜŞÜK | Helper, audit yazmıyor |
| `mznGuncelle` | ORTA | Mizan periyodik snapshot — audit'i bilinmiyor |
| `hspKodDegistir` | ORTA | Hesap kodu değiştirme |
| `hspTasi` | ORTA | Hesap birleştirme |

→ **mhsSirala kaynağı bu turun en yüksek değerli ek bilgisi.**
sirketSiraliTarih güncelleme mantığı ve hangi koşullarda dönem
"kilitleniyor" — operasyonel sağlık için kritik.

---

## 7. Pratik Audit Sorguları

### 7.1 Bugün ne yapıldı?

```sql
SELECT izTrh, izKisi, islem, islemNot
FROM   dbo.drn2
WHERE  izProgID = 55
  AND  CAST(izTrh AS date) = CAST(GETDATE() AS date)
ORDER BY izID DESC
```

### 7.2 Bir kullanıcının son hareketleri

```sql
SELECT TOP 100 izTrh, islem, islemNot, izBlgID
FROM   dbo.drn2
WHERE  izProgID = 55 AND izKisi = 145
ORDER BY izID DESC
```

### 7.3 Bir fişin tüm hayat döngüsü

```sql
SELECT izTrh, izKisi, islem,
       CASE
         WHEN islemNot LIKE '%kaydedildi%'    THEN 'KAYDET (insert)'
         WHEN islemNot LIKE '%değiştirildi%'  THEN 'DEĞİŞTİR (update)'
         WHEN islemNot LIKE '%silindi%'       THEN 'SİL'
         WHEN islemNot LIKE '%çıkarıldı%'     THEN 'ÇIKAR'
         WHEN islemNot LIKE '%onay durum=1%'  THEN 'ONAYLA'
         WHEN islemNot LIKE '%onay durum=0%'  THEN 'ONAY KALDIR'
         WHEN islemNot LIKE '%Kapanış fişi%'  THEN 'KAPANIŞ'
         WHEN islemNot LIKE '%Sıralama yapı%' THEN 'SIRALAMA'
       END AS operasyon,
       islemNot
FROM   dbo.drn2
WHERE  izProgID = 55 AND izBlgID = 12345    -- @fisID
ORDER BY izID
```

### 7.4 BKM mhsSirala günlük kullanım yoğunluğu

```sql
SELECT CAST(izTrh AS date) AS gun, COUNT(*) AS sirala_adet
FROM   dbo.drn2
WHERE  izProgID = 55
  AND  islem    = 14
  AND  islemNot LIKE 'Sıralama%'
  AND  izTrh   >= '01.01.2026'
GROUP BY CAST(izTrh AS date)
ORDER BY gun DESC
```

### 7.5 Bir şirket için tüm kapanış fişleri (tashih sayma)

```sql
SELECT izTrh, izKisi, islemNot, izBlgID AS fisID
FROM   dbo.drn2
WHERE  izProgID = 55
  AND  islem    = 14
  AND  islemNot LIKE 'Kapanış fişi oluşturuldu. Şirket no:5%'
ORDER BY izID
```
