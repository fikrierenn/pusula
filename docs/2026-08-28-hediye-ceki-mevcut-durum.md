# Hediye Çeki — Mevcut Durum Mutabakatı (kaç verildi / kaç kullanıldı)

**Tarih:** 28.08.2026 · **Kaynak:** `PUAN.dbo.Siparis` + `PUAN.dbo.CekListesi` → `DerinCrm.cmp.GiftCard`
**Kapsam:** tüm zamanlar, `isCancel=0 AND isWrite=1` (gerçekten basılıp teslim edilen çekler)
**İlişkili:** [`2026-08-25-hediye-ceki-indirim-raporu.md`](2026-08-25-hediye-ceki-indirim-raporu.md) (indirim politikası) · `sema/metrics.yaml` → `hediye_ceki`

---

## 1. Tek bakışta

| | Adet | ₺ |
|---|---:|---:|
| **Basılan çek (toplam)** | 16.832 | **7.276.174** |
| — CRM'de kaydı YOK (izlenemiyor) | 10.824 | **4.374.370** |
| — CRM'de kayıtlı (izlenebilir) | 6.008 | **2.901.804** |
| &nbsp;&nbsp;&nbsp;&nbsp;· Harcanan | 2.431 tükenmiş | **1.673.750** |
| &nbsp;&nbsp;&nbsp;&nbsp;· Kalan (açık bakiye) | | **1.228.054** |
| **Vadesi geçmiş kalan** | 1.494 | **583.500** |

237 sipariş · 51 farklı firma adı.

**Kullanım oranı yalnız izlenebilir kısımda ölçülebiliyor: %57,7.** Toplam basılan nominale oranlarsan %23 — ama bu rakam yanıltıcı, çünkü izlenemeyen %60'lık kısmın ne kadarının harcandığı bilinmiyor.

## 2. Kasa değişimi (11.07.2025) — her şeyi belirleyen kırılma

**EncoreMerkez'deki tüm satış verisi 11.07.2025'te başlıyor** (1.264.116 fiş, öncesi yok). `DerinCrm.cmp.GiftCard`'ın ilk kaydı da aynı gün. Yani o tarihte kasa sistemi değişti; öncesi başka bir sistemde ve bu sunucuda yok.

Göçte çeklerin bir kısmı taşındı, bir kısmı taşınmadı:

| | Çek | Nominal ₺ |
|---|---:|---:|
| Göç öncesi sipariş — **taşındı** (CreatedAt 11.07.2025) | 4.306 | 1.782.504 |
| Göç öncesi sipariş — **taşınmadı** | 10.824 | 4.374.370 |
| Göç sonrası sipariş (doğrudan yeni sistemde) | 1.702 | 1.119.300 |

Taşınmayan 10.824 çeki vadeye göre ayırınca tablo netleşiyor:

| Göç anındaki durum | Çek | Nominal ₺ | Değerlendirme |
|---|---:|---:|---|
| Vadesi zaten geçmişti (SKT 31.12.2023 / 31.12.2024) | 6.231 | 2.322.000 | Taşınmaması **normal** |
| **Göç anında hâlâ geçerliydi** | **4.593** | **2.052.370** | **Sorun** — bkz. §13 |

**Düzeltme:** Bu raporun ilk halinde "4,37 M₺ izlenemiyor" yazıyordu. Doğrusu: 2,32 M₺'si zaten ölü çek (vadesi göçten önce dolmuş, taşınmaması doğru), **2,05 M₺'si göç anında geçerli olmasına rağmen taşınmamış.** İkisi çok farklı şeyler.

Ölçüm penceresi de bu tarihte başlıyor: **11.07.2025 öncesi hiçbir çek harcaması görünmüyor.** "2024 partileri kullanılmadı" gibi çıkarımlar bu yüzden temkinli okunmalı (§8.2).

## 3. Segment kırılımı (nominal ₺)

| Segment | ₺ | Pay |
|---|---:|---:|
| Kendi mağazalarımız (BKMKitap-FSM/Özlüce/İst.Yolu/BKMKitap) | 3.022.340 | %42 |
| **Test (çöp kayıt — bkz. §6)** | **1.128.954** | %16 |
| Grup-içi (Bursa Kültür Merkezi) | 524.350 | %7 |
| Dış kurumsal müşteri | 2.600.530 | %36 |
| **Toplam** | **7.276.174** | |

Kendi mağaza kayıtları = perakende hediye kartı satışı (kurumsal değil). Test hariç tutulunca gerçek hacim **6.147.220 ₺**.

> İlk hesapta kendi mağaza 3.018.340 / dış kurumsal 2.604.530 yazılmıştı — firma tablosundaki 10.000 ₺ alt kesme, 4.000 ₺'lik bir mağaza siparişini dışarıda bırakmıştı. Düzeltildi.

## 4. Dış kurumsal müşteriler — firma bazında

Mükerrer yazımlar birleştirildi (⚠ işaretli satırlar iki farklı `FirmaIsmi` kaydından toplanmıştır).

| Firma | Basılan çek | Nominal ₺ | CRM'de yok ₺ | Harcanan ₺ | Kalan ₺ | Kullanım* |
|---|---:|---:|---:|---:|---:|---:|
| **İNALLAR** ⚠ (Otomotiv + Makyağsan) | 1.152 | 672.000 | 134.000 | **321.500** | 216.500 | %60 |
| **EPSAN PLASTİK** | 300 | 474.700 | 197.650 | **205.350** | 71.700 | %74 |
| **OSKİM OTOMOTİV** ⚠ | 189 | 189.000 | 72.500 | 83.500 | 33.000 | %72 |
| **HPA PLASTİK** ⚠ | 166 | 175.200 | 148.200 | 1.500 | 24.000 | %6 |
| **İBRAŞ KAUÇUK** | 200 | 150.000 | 69.000 | 5.250 | 75.750 | %6 |
| **BTSO** ⚠ (iki oda kaydı) | 514 | 196.100 | 179.100 | 5.000 | 12.000 | %29 |
| ÖZLEM KONUKOĞLU | 100 | 100.000 | 100.000 | 0 | 0 | izlenemiyor |
| MEDİCABİL | 188 | 94.000 | 65.500 | 7.500 | 21.000 | %26 |
| Tredin Oto Donanım | 90 | 90.000 | 27.000 | 46.000 | 17.000 | %73 |
| GÜRBÜZ HOCA ISI MARKET | 18 | 72.000 | 0 | 0 | **72.000** | %0 |
| YILDIRIM BELEDİYESİ | 18 | 72.000 | 30.000 | 36.000 | 6.000 | %86 |
| Şentürk Oto | 72 | 72.000 | 72.000 | 0 | 0 | izlenemiyor |
| RAPİER OTOMOTİV | 32 | 64.000 | 56.000 | 2.000 | 6.000 | %25 |
| YILDIRIM KÜLTÜR | 72 | 39.250 | 37.250 | 0 | 2.000 | %0 |
| Muhtelif | 30 | 30.000 | 30.000 | 0 | 0 | izlenemiyor |
| Bursalı Tekstil | 27 | 15.750 | 15.750 | 0 | 0 | izlenemiyor |
| EĞİTİM-BİRSEN | 9 | 13.500 | 10.000 | 1.000 | 2.500 | %29 |
| ŞURA KİTAPEVİ | 32 | 13.400 | 8.750 | 1.000 | 3.650 | %22 |
| ENDERUN TANITIM | 100 | 10.000 | 8.100 | 600 | 1.300 | %32 |
| BORÇELİK | 14 | 9.250 | 7.250 | 0 | 2.000 | %0 |
| Ahi Hasan Ortaokulu ⚠ | 8 | 1.600 | 0 | 200 | 1.400 | %13 |
| 10.000 ₺ altı diğer 23 firma | — | 64.630 | — | — | — | — |

\* Kullanım = Harcanan ÷ (Nominal − CRM'de yok). İzlenebilir kısım üzerinden.

**İki uç:**
- **Yüksek kullanım:** EPSAN %74, OSKİM %72, Tredin %73, YILDIRIM BELEDİYESİ %86 — çekler gerçekten dağıtılmış ve harcanmış.
- **Sıfıra yakın:** İBRAŞ %6 (200 çek / 150.000 ₺, sadece 5.250 ₺ kullanılmış), HPA %6, GÜRBÜZ HOCA %0 (72.000 ₺'nin tamamı duruyor), YILDIRIM KÜLTÜR %0, BORÇELİK %0. Bu firmalar çekleri almış ama çalışanlarına dağıtmamış görünüyor.

⚠ **İNALLAR harcanan rakamı iki yöntemde farklı:** GiftCard bakiye farkı 321.500 ₺, POS fişi (`SalesPayments`) toplamı 305.500 ₺. 16.000 ₺'lik fark muhtemelen POS dışı (fatura kanalı) kullanım veya kayıt gecikmesi. Kârlılık analizinde POS rakamı (305.500) esas alındı — fiş kırılımı oradan geliyor.

## 5. Vadesi geçmiş kalan bakiye: 583.500 ₺

24 firma adı, hepsinin vadesi **31.12.2025**, 1.494 çek. Hiçbiri kısmen bile kullanılmamış — tam bakiyeli, artık kullanılamaz.

| Segment | ₺ |
|---|---:|
| **Dış müşteri** | **259.350** |
| Kendi mağazalarımız | 239.700 |
| Grup-içi (Bursa Kültür Merkezi) | 83.450 |
| Test | 1.000 |

Dış müşteri ilk beş: İBRAŞ 75.750 · İNALLAR 49.000 · EPSAN 40.750 · HPA 25.500 · MEDİCABİL 21.000 (toplamın %79'u).

**Muhasebe sorusu:** dış müşteri kısmı olan 259.350 ₺ tahsil edilmiş, mal verilmemiş, vade dolmuş. Avans yükümlülüğünden düşülüp gelir yazılması gerekip gerekmediği muhasebeye sorulmalı. Kalan 324.150 ₺ iç işlem — tahsilat yok, sadece kayıt temizliği.

> ⚠ **Düzeltme:** İlk ölçümde 593.500 ₺ çıkmıştı. `isWrite=1` filtresi eksikti — aradaki 10.000 ₺ (ENDERUN, 100 çek) **basılmamış** sipariş satırı. Doğru rakam 583.500 ₺. Aynı düzeltme dış müşteri toplamını da 269.350 → **259.350 ₺** yapar; ENDERUN'un vadesi geçmiş kalanı 11.300 değil **1.300 ₺**.

## 6. Veri kalitesi bulguları

### 6.1 "Test" adına 100.000 ₺ gerçek çek

`FirmaIsmi = "Test"` altında 13 siparişte çek basılmış. İkisi ayrı:

**Gerçek test (önemsiz):** siparis 1730 (5 çek × 2 ₺), 1541 (2 × 2 ₺).

**Gerçek para — hepsi 24.05.2025, aynı gün:**

| Sipariş | Çek | Kupür ₺ | Nominal ₺ | Harcanan ₺ | Kalan ₺ |
|---|---:|---:|---:|---:|---:|
| 1531 | 50 | 1.000 | 50.000 | 26.000 | 24.000 |
| 1532 | 100 | 250 | 25.000 | 9.000 | 16.000 |
| 1533 | 100 | 250 | 25.000 | 11.750 | 13.250 |
| **Toplam** | **250** | | **100.000** | **46.750** | **53.250** |

Vade 31.12.2026 — hâlâ aktif. Yetkili alanı `dasdas asd as das dasd as d`, telefon 5468668812. Harcama izi M01/M02'de, 2026-04 ile 2026-07 arası, kasiyer 144/218/223/229.

**100.000 ₺'lik gerçek çek partisi "Test" adına basılmış, yarısı harcanmış, 53.250 ₺ hâlâ açık, kime verildiği kayıtlı değil.** Sistemdeki en net kontrol açığı.

**Ayrıca sipariş 1243 (26.07.2023): tek çek, 1.000.000 ₺ nominal.** CRM'e hiç aktarılmamış, vadesi 31.12.2024'te dolmuş, harcanmamış. "Test" segmentindeki 1,13 M₺'nin 1 M₺'si bu tek kayıt. Muhtemelen gerçek bir test ama fiziksel basıldıysa o barkod hâlâ ortada.

### 6.2 `FirmaIsmi` serbest metin — cari bağı yok

`PUAN.dbo.Siparis`'te ERP cari (`frmID`) bağı yok; firma adı elle yazılıyor. Sonuçları:
- Aynı firma 2+ farklı yazımla: HPA/hpa · OSKİM (2) · BTSO (2) · Ahi Hasan (2) · İNALLAR (5+ varyant)
- "Test", "Muhtelif" gibi kayıtlar mümkün
- Firma bazlı raporlama LIKE ile yapılmak zorunda, ID ile yapılamıyor
- Cari bakiye / tahsilat ile otomatik mutabakat imkânsız

### 6.3 Kategori kısıtı basılı ama zorlanmıyor

`Siparis.aciklama` çekin üzerine basılan metni tutuyor ("Sadece Kırtasiye Ürünlerinde Geçerlidir"). POS bunu **kontrol etmiyor** — İNALLAR çeklerinin %13,2'si kırtasiye dışında harcanmış. Kısıt basılı bilgi, kontrol değil.

### 6.4 `isWrite` filtresi zorunlu

`isWrite=0` = sipariş girilmiş ama basılmamış. Filtresiz sayarsan nominal şişer (İNALLAR'da %67 fazla çıkıyordu). Her ölçümde `isCancel=0 AND isWrite=1`.

## 7. Aksiyon önerileri

| # | Konu | Aksiyon |
|---|---|---|
| 1 | Test siparişleri 1531/1532/1533 | 53.250 ₺ açık bakiye kimde? Siparişi giren kişi ve çeklerin gittiği yer sorulmalı; gerekirse kalan çekler `isCancel` ile iptal |
| 2 | 1.000.000 ₺'lik test çeki (1243) | Fiziksel basılıp basılmadığı teyit edilmeli; basıldıysa imha kaydı |
| 3 | `FirmaIsmi` serbest metin | Cari seçimi zorunlu hale getirilmeli (`frmID` alanı) — yoksa mükerrer isimler ve "Test" kayıtları tekrarlar |
| 4 | 4,37 M₺ izlenemeyen çek | Eski partilerin CRM'e aktarımı veya toplu vade-kapatma kararı; mevcut halde yükümlülük ölçülemiyor |
| 5 | Vadesi geçmiş 269.350 ₺ (dış müşteri) | Muhasebeye sorulmalı: gelir yazılacak mı? |
| 6 | Düşük kullanımlı müşteriler | İBRAŞ (%6), HPA (%6), GÜRBÜZ HOCA (%0) — çekler dağıtılmamış. Müşteri ilişkisi açısından temas edilmeli; yeni satış öncesi eski stok konuşulmalı |
| 7 | Kategori kısıtı | POS'ta kategori bazlı ödeme kısıtı yoksa %13 sızma devam eder — ürün grubu kontrolü Encore tarafında değerlendirilmeli |


---

## 8. Ek — Firma × ay × SKT dökümü

Kendi mağaza kayıtları (BKMKitap*) ve grup-içi (Bursa Kültür Merkezi) hariç. 67 sipariş-ayı.
**İzlenmeyen** = CRM'de kaydı olmayan, harcanıp harcanmadığı bilinmeyen tutar.

### 8.1 SKT 31.12.2026 — hâlâ geçerli

| Firma | Veriliş ayı | Verilen ₺ | Kullanılan ₺ | Kalan ₺ | İzlenmeyen ₺ |
|---|---|---:|---:|---:|---:|
| İNALLAR OTOMOTİV-MAKYAĞSAN | 09.2025 | 320.000 | 207.500 | 112.500 | 0 |
| EPSAN PLASTİK | 08.2025 | 227.550 | 196.600 | 30.950 | 0 |
| İNALLAR OTOMOTİV | 08.2025 | 160.000 | 105.000 | 55.000 | 0 |
| **Test** ⚠ | 05.2025 | 100.000 | 46.750 | 53.250 | 0 |
| OSKİM OTOMOTİV SA. | 08.2025 | 97.500 | 81.000 | 16.500 | 0 |
| Tredin Oto Donanım | 04.2025 | 90.000 | 46.000 | 17.000 | 27.000 |
| GÜRBÜZ HOCA ISI MARKET | 06.2025 | 72.000 | **0** | **72.000** | 0 |
| YILDIRIM BELEDİYESİ | 06.2025 | 72.000 | 36.000 | 6.000 | 30.000 |
| MUDANYA BELEDİYESİ | 04.2025 | 6.000 | 2.250 | 750 | 3.000 |
| GAZİ ANADOLU LİSESİ AB | 01.2025 | 6.000 | 2.000 | 0 | 4.000 |
| BURSA ZEKİ MÜREN GSL | 02.2025 | 4.500 | 1.300 | 500 | 2.700 |
| BURFAŞ | 03.2025 | 3.000 | 1.000 | 2.000 | 0 |
| Fazla ödeme karşılığı | 01.2025 | 426 | 0 | 0 | 426 |
| Test (gerçek test) | 06.2025 | 4 | 0 | 4 | 0 |
| **Toplam** | | **1.158.980** | **725.400** | **366.454** | **67.126** |

Aktif portföyün tamamı 2025 siparişi. İzlenebilirlik burada iyi (%94) — CRM entegrasyonu 2025'te oturmuş.

### 8.2 SKT 31.12.2025 — vadesi doldu

| Firma | Veriliş ayı | Verilen ₺ | Kullanılan ₺ | Kalan ₺ | İzlenmeyen ₺ |
|---|---|---:|---:|---:|---:|
| İNALLAR OTOMOTİV-MAKYAĞSAN | 09.2024 | 192.000 | 9.000 | 49.000 | 134.000 |
| İBRAŞ KAUÇUK | 08.2024 | 150.000 | 5.250 | **75.750** | 69.000 |
| EPSAN PLASTİK | 08.2024 | 149.750 | 8.750 | 40.750 | 100.250 |
| HPA PLASTİK | 09.2024 | 121.200 | 1.500 | 22.500 | 97.200 |
| MEDİCABİL | 05.2024 | 94.000 | 7.500 | 21.000 | 65.500 |
| BURSA SANAYİ VE TİCARET ODASI | 09.2024 | 65.000 | 3.500 | 9.000 | 52.500 |
| RAPİER OTOMOTİV | 08.2024 | 64.000 | 2.000 | 6.000 | 56.000 |
| OSKİM OTOMOTİV SA. | 09.2024 | 59.000 | 2.000 | 12.000 | 45.000 |
| OSKİM OTOMOTİV | 04.2024 | 32.500 | 500 | 4.500 | 27.500 |
| EĞİTİM-BİRSEN | 11.2024 | 13.500 | 1.000 | 2.500 | 10.000 |
| ENDERUN TANITIM | 06.2024 | 10.000 | 600 | 1.300 | 8.100 |
| Bursa Ticaret ve Sanayi Odası | 09.2024 | 10.000 | 1.500 | 3.000 | 5.500 |
| Test | 12.2024 | 9.500 | 500 | 0 | 9.000 |
| Test | 05.2024 | 8.750 | 0 | 1.000 | 7.750 |
| ŞURA KİTAPEVİ | 01.2025 | 8.000 | 1.000 | 3.000 | 4.000 |
| BORÇELİK | 10.2024 | 6.000 | 0 | 2.000 | 4.000 |
| hpa | 09.2024 | 3.000 | 0 | 1.500 | 1.500 |
| HPA PLASTİK | 10.2024 | 3.000 | 0 | 1.500 | 1.500 |
| ŞURA KİTAPEVİ | 05.2024 | 3.000 | 0 | 250 | 2.750 |
| YILDIRIM KÜLTÜR | 02.2024 | 2.500 | 0 | 2.000 | 500 |
| ŞURA KİTAPEVİ | 12.2024 | 2.400 | 0 | 400 | 2.000 |
| "1393 eksik basılan çek" ⚠ | 09.2024 | 1.000 | 0 | 0 | 1.000 |
| AKI KİTAP KIRTASİYE | 12.2024 | 804 | 0 | 0 | 804 |
| Ahi Hasan Ortaokulu | 04.2024 | 800 | 200 | 600 | 0 |
| Ahi Hasan Ortaokulu OAB | 02.2024 | 800 | 0 | 800 | 0 |
| Test | 10.2024 | 500 | 0 | 0 | 500 |
| Test | 06.2024 | 200 | 0 | 0 | 200 |
| **Toplam** | | **1.011.204** | **44.800** | **260.350** | **706.054** |

**⚠ Bu tablo olduğu gibi okunamaz.** İzlenebilir 305.150 ₺'nin 44.800 ₺'si (%14,7) harcanmış görünüyor — ama **ölçüm 11.07.2025'te başlıyor** (§2). 2024 partilerinin 2024 ve 2025'in ilk yarısındaki harcamaları eski kasa sisteminde kaldı, bu veride yok.

Yani "%15 kullanım" gerçek kullanım oranı DEĞİL, göç sonrası kalan kuyruk. Gerçek oran daha yüksek; ne kadar yüksek olduğu bu sunucudan ölçülemez. "İzlenmeyen" kolonundaki 706.054 ₺'nin büyük kısmı da göçte taşınmayan (yani muhtemelen göçten önce harcanmış) çekler.

### 8.3 SKT 31.12.2024 — 2023 siparişleri (tamamı izlenemiyor)

| Firma | Ay | Verilen ₺ |
|---|---|---:|
| **Test** (tek çek, 1 M₺) ⚠ | 07.2023 | 1.000.000 |
| ÖZLEM KONUKOĞLU | 09.2023 | 100.000 |
| EPSAN PLASTİK | 08.2023 | 97.400 |
| Bursa Ticaret ve Sanayi Odası | 12.2023 | 95.000 |
| Şentürk Oto | 09.2023 | 72.000 |
| HPA PLASTİK | 08.2023 | 48.000 |
| YILDIRIM KÜLTÜR | 12.2023 | 12.000 |
| Test | 05.2023 | 10.000 |
| Bursalı Tekstil | 09.2023 | 6.750 |
| Türk Kızılay Bursa | 01.2023 | 3.150 |
| NİLÜFER KOÇ Ortaokulu OAB | 10.2023 | 1.350 |
| TSOFT | 10.2023 | 900 |
| TEKROM TEKNOLOJİ | 10.2023 | 900 |
| KULAKSIZOĞLU DIŞ TİCARET | 07.2023 | 250 |
| **Toplam** | | **1.447.700** |

Kullanılan/kalan **0** — hepsi CRM öncesi, harcandı mı bilinmiyor.

### 8.4 SKT 31.12.2023 — 2022 siparişleri (tamamı izlenemiyor)

| Firma | Ay | Verilen ₺ |
|---|---|---:|
| Muhtelif | 09.2022 | 30.000 |
| Bursa Ticaret ve Sanayi Odası | 12.2022 | 26.100 |
| YILDIRIM KÜLTÜR | 10.2022 | 24.750 |
| Bursalı Tekstil | 09.2022 | 9.000 |
| YANIT YAYINCILIK | 11.2022 | 6.000 |
| S.S. BOSCH Çalışanları Koop. | 09.2022 | 4.000 |
| SİRENA MARİNE | 05.2022 | 3.950 |
| AKWEL BURSA | 05.2022 | 3.200 |
| BORÇELİK | 05.2022 | 2.500 |
| LİMAK ULUDAĞ ELEKTRİK | 08.2022 | 1.000 |
| BORÇELİK | 06.2022 | 750 |
| Mustafa Bulut | 09.2022 | 350 |
| **Toplam** | | **111.600** |

### 8.5 Okuma

| SKT | Verilen ₺ | Kullanılan ₺ | Kalan ₺ | İzlenmeyen ₺ | Kullanım* |
|---|---:|---:|---:|---:|---:|
| 31.12.2026 (aktif) | 1.158.980 | 725.400 | 366.454 | 67.126 | **%66** |
| 31.12.2025 (doldu) | 1.011.204 | 44.800 | 260.350 | 706.054 | **%15** |
| 31.12.2024 (doldu) | 1.447.700 | 0 | 0 | 1.447.700 | ölçülemiyor |
| 31.12.2023 (doldu) | 111.600 | 0 | 0 | 111.600 | ölçülemiyor |

\* İzlenebilir kısım üzerinden.

**Üç şey görünüyor:**

1. **Kurumsal çek satışı 2025'te patladı ve kullanım da yükseldi (%66).** CRM entegrasyonu oturduğu için de ilk kez düzgün ölçülebiliyor.
2. **2024 partileri kullanılmadan yandı.** İzlenebilir kısımda %15 kullanım — çekler müşterilerin elinde kaldı, dağıtılmadı. İBRAŞ ve HPA bunun uç örnekleri.
3. **2022–2023'ün 1,56 M₺'si kara kutu.** İçinde 1 M₺'lik tek "Test" çeki var; onu düşünce gerçek tutar 559.300 ₺.

**Satış tarafına not:** aynı müşteriye yeni parti satmadan önce eski partisinin kullanım oranına bakılmalı. İBRAŞ'a 2024'te 150.000 ₺ satılmış, 5.250 ₺ kullanılmış — o müşteriye indirim tartışmadan önce konuşulacak konu bu.


---

## 9. İnallar — çek ne ciro getirdi, ne kâr getirdi

**Soru:** İnallar'a %15 indirimle çek sattık. Bu çek bize gerçekte ne kazandırdı?

**Ölçüm tabanı:** perakende fiş (`DocumentsTypeId=1`), 231 fiş. Zincir: `PUAN.Siparis` (FirmaIsmi LIKE '%NALLAR%') → `CekListesi.barcode` → `GiftCard` → `GiftCardTransaction.SalesId` → `Sales.PosDocumentId`. Maliyet fat5 (son 5 alış faturası), kapsama %98,1.

### 9.1 Verdik

| | ₺ |
|---|---:|
| Basılan çek nominali (1.152 çek) | 672.000 |
| Faturalanan brüt | 655.400 |
| Verilen indirim (%14,76) | −96.750 |
| **Tahsil ettiğimiz nakit** | **558.650** |

### 9.2 Kullanıldı

| | ₺ |
|---|---:|
| Perakende fişte harcanan (231 fiş) | **300.500** |
| Sınav Okulları fişi (3 fiş) | 4.500 |
| Fatura (1 fiş) | 1.000 |
| **POS toplam** | **306.000** |
| CRM bakiye farkına göre harcanan | 321.500 |
| CRM'de kaydı olmayan (izlenemiyor) | 134.000 |
| Hâlâ açık bakiye | 216.500 |
| — bunun vadesi dolup yananı (31.12.2025) | 49.000 |

Kullanım oranı **hangi tabana böldüğüne göre değişir** — karıştırmamak lazım:

| Taban | Hesap | Oran |
|---|---|---:|
| İzlenebilir nominal (672.000 − 134.000 = 538.000) | 321.500 / 538.000 | **%59,8** |
| Basılan nominalin tamamı | 321.500 / 672.000 | %47,8 |
| Kâr hesabına giren perakende POS | 300.500 / 672.000 | %44,7 |

§4'teki "%60" birinci satırdır. Aşağıdaki kâr hesabı **300.500 ₺** üzerinden yürür (fiş kırılımı yalnız orada var).

### 9.3 Ne ciro getirdi

| | ₺ |
|---|---:|
| Sepet brüt (KDV hariç, indirim öncesi) | 401.060 |
| POS'ta verilen indirim (%17,5) | −70.337 |
| **Net ciro (KDV hariç)** | **330.723** |
| | |
| Tahsilat (KDV dahil) | 373.947 |
| — hediye çeki | 300.500 |
| — kart + nakit | **73.447** |

**Kaldıraç 1,24×** — müşteri her 1 ₺ çekin üstüne 24 kuruş kendi parasını koydu.

### 9.4 Ne kâr getirdi

| | ₺ |
|---|---:|
| Net ciro (maliyeti bilinen kısım) | 324.443 |
| Satılan malın maliyeti (fat5) | −184.685 |
| **Brüt kâr** | **139.757** |
| **Marj** | **%43,1** |

Kategori kırılımı:

| Kategori | Net ciro ₺ | Pay | Marj | Brüt kâr ₺ |
|---|---:|---:|---:|---:|
| **Kırtasiye** | 284.737 | %86,1 | **%45,8** | 129.079 |
| Kitap (11 alt kategori) | 29.870 | %9,0 | **%18,8** | 5.232 |
| Diğer (hediyelik/oyuncak/süpermarket/elektronik) | 16.116 | %4,9 | %36,2 | 5.446 |

Kısıt "sadece kırtasiye" yazıyor ama **%13,9'u kırtasiye dışına gitti** — ve o kısmın büyüğü olan kitapta marj %18,8, kırtasiyenin yarısından az. Sızma sadece kural ihlali değil, kâr kaybı.

### 9.5 Net hesap

| | ₺ |
|---|---:|
| Brüt kâr | 139.757 |
| Kullanılan 300.500 ₺'ye düşen indirim (%14,76) | −44.354 |
| **Net katkı** | **95.403** |

**Kâr / 1 ₺ çek = 0,465.** Yani **kırılma noktası %46,5** — teorik olarak %46,5'e kadar indirim verilse başa baş kalınır. %15'te marjın **%68'i** korunuyor.

### 9.6 Kullanılmayan çeklerin ayrı hikâyesi

Yukarıdaki hesap yalnız kâr tabanına giren 300.500 ₺ için. Harcanmayan kısım ayrı:

| | Nominal ₺ | Tahsil edilen nakit ₺ (×0,8524) |
|---|---:|---:|
| **Açık bakiye** (CRM'de duruyor) | 216.500 | 184.545 |
| — vadesi dolup yanan | 49.000 | **41.767** |
| — hâlâ geçerli (31.12.2026) | 167.500 | 142.778 |
| **CRM'de kaydı yok** (harcandı mı bilinmiyor) | 134.000 | 114.222 |

- Vadesi yanan 49.000 ₺: mal hiç verilmeyecek → tahsil edilen **41.767 ₺ tamamen kâr**, maliyeti sıfır.
- 167.500 ₺ hâlâ açık yükümlülük; 31.12.2026'da aynı soru tekrar gelecek.
- 134.000 ₺ belirsiz — eski sistemde harcanmış da olabilir, kâr yazılamaz.

Yani çekin gerçek getirisi iki parçalı: **harcanan kısmın ticari kârı** + **harcanmayan kısmın yanan bakiyesi**. İkincisi muhasebe kararına bağlı (§5).

### 9.7 Mutabakat — §4 ve önceki tablolarla neden farklı

Üç ayrı taban var, üçü de doğru ama **birbirinin yerine kullanılamaz**:

**Çek tarafı (nominal):**

| | ₺ |
|---|---:|
| Basılan | 672.000 |
| − CRM'de kaydı yok | 134.000 |
| = İzlenebilir | 538.000 |
| &nbsp;&nbsp;· Harcanan (CRM bakiye farkı) | 321.500 |
| &nbsp;&nbsp;· Açık bakiye | 216.500 |

**POS ödeme tarafı** (`SalesPayments`, PaymentTypesId=11): 306.000 ₺ — perakende 300.500 + Sınav 4.500 + fatura 1.000. CRM'deki 321.500 ile **15.500 ₺ fark** (bakiye düşülmüş, POS ödeme kaydı yok).

**Sepet tarafı (fiş):**

| | Fiş | Net ciro ₺ |
|---|---:|---:|
| Firma bazlı toplam (önceki mesajdaki tablo) | 238 | 430.824 |
| − 3 fiş iki İnallar şirketinde birden sayılmış | −3 | −8.461 |
| = Tekil | 235 | 422.364 |
| − Sınav Okulları (tip 8) | −3 | −90.368 |
| − Fatura (tip 2) | −1 | −1.273 |
| **= Perakende fiş — kâr hesabının tabanı** | **231** | **330.723** |

Önceki mesajda İNALLAR OTOMOTİV 113.814 + MAKYAĞSAN 317.010 = 430.824 ₺ yazmıştım; o rakam iki şirketi ayrı ayrı topluyor ve Sınav/fatura fişlerini içeriyordu. Kâr hesabı için doğru taban 330.723 ₺.

### 9.8 Ölçüm notları

- **Çek harcaması iki kaynakta farklı:** `GiftCard` bakiye farkı 321.500 ₺, `SalesPayments` (PaymentTypesId=11) 306.000 ₺. 15.500 ₺'lik fark POS'ta iz bırakmamış — bakiye düşülmüş ama ödeme kaydı yok. Kâr hesabında POS rakamı (300.500, perakende) esas alındı; fiş kırılımı oradan geliyor.
- **3 Sınav Okulları fişi hesaptan çıkarıldı.** O fişlerde 4.500 ₺ çek kullanılmış ama 90.368 ₺ net ciro var — dahil edilse kaldıraç 1,24× yerine 1,53× görünüyor ve tablo yanıltıcı oluyor. Bunlar okul paketi satışı; çekin getirdiği alışveriş değil, çekin küçük bir parçasının kullanıldığı büyük işlemler.
- **3 fiş iki İnallar şirketinde birden sayılıyordu** (hem "İNALLAR OTOMOTİV" hem "İNALLAR OTOMOTİV-MAKYAĞSAN" çeki kullanılmış). Firma bazında toplarken 238 çıkıyor; tekilleştirilince **235** (perakende 231).
- **`SalesProducts.TotalPrice` indirim SONRASI değerdir.** Net = `TotalPrice − VatTotal`, Brüt = `TotalPrice + DiscountTotalDirect`. `TotalPrice − DiscountTotalDirect − VatTotal` yazmak indirimi iki kez düşer (ilk denemede net %17 eksik çıktı). Dashboard sorguları doğru yazılmış.


---

## 10. Fiş fiş doğrulama — kaldıraç gerçek mi?

Agregat rakama güvenmeden önce 231 perakende fişin tamamı çek payına göre dağıtıldı (dünkü sızma ölçümünde agregat 2,3× yanıltmıştı — aynı hataya düşmemek için).

| Çek payı (fişin ne kadarı çekle ödendi) | Fiş | Çek ₺ | Tahsilat ₺ | Net ciro ₺ |
|---|---:|---:|---:|---:|
| %100 (tamamı çek) | 9 | 15.500 | 15.500 | 13.675 |
| %75–99 | 163 | 216.500 | 234.867 | 206.883 |
| %50–74 | 43 | 54.000 | 85.428 | 75.666 |
| %25–49 | 14 | 13.500 | 33.164 | 29.690 |
| %25 altı | 2 | 1.000 | 4.988 | 4.808 |
| **Toplam** | **231** | **300.500** | **373.947** | **330.723** |

**Sonuç: agregat temiz.** Fişlerin %71'inde çek, sepetin %75–99'unu karşılıyor — yani sepetler gerçekten çek etrafında oluşmuş, çekin iliştirildiği büyük alışverişler değil. En uç fiş 8.994 ₺ tahsilatlı, müşteri 4.494 ₺ eklemiş; Sınav fişlerindeki gibi (4.500 ₺ çek → 90.368 ₺ ciro) çarpıtma yok.

Kaldıraç **1,24×** dürüst bir rakam.

## 11. Vadesi geçen çek talep edilirse kullandırmalı mı?

### Durum: karar verilmemiş, sistem karar veriyor

Ağustos 2026'nın 28 gününde **vadesi geçmiş tek bir çek bile kullanılmadı** — POS bunları kesiyor. Yani bugünkü fiili politika "hayır", ama bu bilinçli bir ticari karar değil, yazılımın varsayılanı.

### Hukuki taraf — sorulmalı, burada karara bağlanamaz

Hediye çeki ön ödemeli bir araç; bedeli tahsil edilmiş, ifa borcu doğmuş durumda. Üzerine geçerlilik süresi konması B2B satışta (alıcı kurumsal firma) sözleşme serbestisi kapsamında savunulabilir, ama çeki kullanan çalışan tüketici konumunda. **Bu bir hukuk sorusu — mali müşavir ve avukat görüşü alınmalı.** Aşağıdaki sadece ticari maliyet hesabıdır.

### Ticari hesap

Vadesi geçen dış müşteri bakiyesi 259.350 ₺ nominal.

| Senaryo | Sonuç |
|---|---|
| **Kullandırmam** | 221.070 ₺ (tahsil edilmiş nakit) gelir yazılır, maliyet sıfır → **~221.000 ₺ kâr** |
| **Kullandırırım** | Müşteri kaldıraçla ~62.000 ₺ daha koyar; satılan malın maliyeti ~166.000 ₺ → **~118.000 ₺ kâr** |

Kullandırmak yaklaşık **103.000 ₺ daha az kâr** demek — ama **zarar değil**. Çekin nominali başına maliyetimiz ~0,54 ₺, cebimizde duran ~0,85 ₺. Her durumda kârlıyız.

### Öneri

1. **Politika yaz, kasiyerin insafına bırakma.** Bugün cevap "sistem kesti" — müşteri karşısında savunulabilir bir duruş değil.
2. **Ayrım aktif/pasif müşteri olsun.** İnallar gibi hâlâ parti alan müşteriye 49.000 ₺ için "hayır" demek 672.000 ₺'lik ilişkiyi riske atar — kullandır. İlişkisi bitmiş firmada vade uygulanır.
3. **Uzatma kampanyası alternatifi:** "31.12.2025 vadeli çekler 31.03.2027'ye kadar geçerli" duyurusu, hem itibarı korur hem kullanımı öne çeker hem de yeni parti görüşmesine kapı açar. Kontrolsüz açmaktan iyidir.
4. Karar ne olursa olsun **§5'teki 259.350 ₺ muhasebe sorusu ayrıca durur** — kullandırma kararı verilirse gelir yazılamaz, karşılık ayrılır.


---

## 12. "Çek olmasa gelirler miydi?" — ölçülebilirliğin sınırı

### 12.1 Kimlik izi çok zayıf

İnallar'ın 231 perakende fişinden:

| | Fiş | Pay | Net ciro ₺ | Pay |
|---|---:|---:|---:|---:|
| Kartlı (CustomersId var) | 64 | %27,7 | 70.868 | %21,4 |
| **Kartsız (anonim)** | **167** | **%72,3** | **259.855** | **%78,6** |

Cironun **%79'unda müşterinin kim olduğu bilinmiyor.** Bu kısım için soru cevaplanamaz — tahmin bile yürütülemez.

Genel hediye çeki fişlerinde durum daha iyi (01.08.2025 sonrası 1.403 kartlı / 1.530 kartsız ≈ yarı yarıya); İnallar'da kartlı oranı belirgin düşük.

### 12.2 "Çek öncesi alışverişi yoktu" denemez — veri yok

59 kartlı müşterinin 01.09.2024 öncesinde hiç kartlı alışverişi görünmüyor. **Bu bulgu KULLANILAMAZ:** sistemdeki en eski kartlı fiş **11.07.2025** tarihli. Yani sadakat kartı verisi 2025 Temmuz'da başlıyor; öncesinde davranış yok değil, **kayıt yok**.

2024 partisi (165 çek / 165.000 ₺) için incrementality sorusu **tümüyle ölçülemez**.

### 12.3 2025 partisinde gerçek bir sinyal var

59 kartlı müşterinin çek fişleri dışındaki alışverişi:

| | Fiş | Müşteri | Net ciro ₺ | İlk | Son |
|---|---:|---:|---:|---|---|
| Çekli fiş | 64 | 59 | 70.868 | 16.09.2025 | 08.08.2026 |
| **Çeksiz — kendi parasıyla** | **151** | **32** | **78.794** | 22.09.2025 | 25.08.2026 |

- **59 kişiden 32'si (%54) çek bittikten sonra kendi parasıyla geri geldi.**
- Getirdikleri ciro **78.794 ₺** — çekle yaptıkları alışverişten (70.868 ₺) **fazla**.
- Kişi başı 4,7 fiş / 2.462 ₺ ilave.
- İlk çekli fiş 16.09.2025, ilk çeksiz 22.09.2025 — yani kart ilişkisi çek kullanımı anında başlamış; bu müşteriler bizim için o gün doğmuş.

**Yorum:** kartlı dilimde çek, harcadığı tutarın üzerine **1,11×** daha ciro getirmiş. Bu, kaldıraçtan (1,24×) ayrı ve ona ek bir etki — aynı ziyarette değil, sonraki ziyaretlerde.

⚠ **Yukarı sapma uyarısı:** kart açtıran müşteri zaten daha bağlıdır. Bu %54'ü kartsız %72'lik dilime aynen uygulamak yanlış olur. Rakam bir üst sınır göstergesi, ortalama değil.

### 12.4 Yapısal düzeltme — tek satırlık kural

Bugün çek harcamasının %72'si anonim. **Hediye çeki tahsilatında sadakat kartı okutmayı zorunlu hale getirmek** bu programı ilk kez ölçülebilir kılar:

- "Çek olmasa gelir miydi?" sorusu cevaplanabilir hale gelir (öncesi/sonrası davranış).
- Kurumsal müşteriye "çeklerinizi kullanan 340 kişinin %54'ü size ek olarak geri döndü" denebilir — satış argümanı.
- Vade uzatma / kampanya kararları hedeflenebilir olur.

Maliyeti sıfıra yakın (kasada bir alan zorunlu), getirisi bu raporun tamamının belirsizliğini kaldırmak.


---

## 13. AKSİYON — dolaşımda 230.226 ₺'lik geçerli ama POS'un tanımadığı çek var

Göçte taşınmayan 4.593 geçerli çekin (§2) bir kısmının vadesi bu arada doldu. **Ama 442 tanesinin vadesi 31.12.2026 — bugün hâlâ geçerliler ve kasada okutulursa tanınmıyorlar.**

| Segment | Çek | Nominal ₺ |
|---|---:|---:|
| **Kendi mağazalarımızda satılan hediye kartı** | **393** | **163.100** |
| — BKMKitap-Özlüce | 231 | 90.850 |
| — BKMKitap-FSM | 139 | 38.650 |
| — BKMKitap-İstanbul Yolu | 23 | 33.600 |
| **Dış müşteri** | **49** | **67.126** |
| — YILDIRIM BELEDİYESİ (06.2025) | 6 | 30.000 |
| — Tredin Oto Donanım (04.2025) | 27 | 27.000 |
| — GAZİ ANADOLU LİSESİ AB (01.2025) | 2 | 4.000 |
| — MUDANYA BELEDİYESİ (04.2025) | 4 | 3.000 |
| — BURSA ZEKİ MÜREN GSL (02.2025) | 9 | 2.700 |
| — "Fazla ödeme karşılığı" (01.2025) | 1 | 426 |
| **Toplam** | **442** | **230.226** |

Hepsi 2025 Ocak–Haziran basımı — yani göçten sadece birkaç ay önce. Harcanmamış olma ihtimalleri yüksek.

**Neden ciddi:** 163.100 ₺'lik kısım bireysel müşterilere satılmış hediye kartı. Müşteri geliyor, elindeki kart geçerli, kasa tanımıyor. Bu şikâyet üretir ve karşı taraf haklıdır — parayı almışız.

**Ayrıca:** göç anında geçerli olup vadesi bu arada dolan 4.151 çek / 1.822.144 ₺ (SKT 31.12.2025) da Temmuz–Aralık 2025 arasında aynı durumu yaşamış olabilir. O dönemde reddedilen çek şikâyeti olup olmadığı mağazalara sorulmalı.

### Yapılacaklar

1. **442 çeği TOPLUCA yüklemek riskli — bkz. §14.** Bir kısmı eski kasada harcanmış olabilir ve eski veride barkod izi yok; topluca yüklersek ikinci kez harcanmalarına izin vermiş oluruz. **Talep geldikçe tek tek açmak** daha güvenli: müşteri fiziksel çeği getirir, barkod `PUAN.dbo.CekListesi`'nden doğrulanır, elle tanımlanır.
2. **Kasalara geçici talimat:** 2025 öncesi basılmış, POS'ta bulunamayan çek geldiğinde reddetme — barkodu not al, merkeze bildir.
3. **Göç kontrolü yapılmamış.** 2,05 M₺'lik geçerli çek taşınmadan geçişe izin verilmiş. Bir sonraki sistem değişiminde mutabakat adımı şart.
4. **Eski POS verisi hâlâ erişilebilir mi?** Erişilebiliyorsa 11.07.2025 öncesi çek harcamaları oradan çekilip bu raporun ölçüm penceresi geriye tamamlanabilir — o zaman gerçek kullanım oranları ve İnallar'ın 2024 partisinin akıbeti de ölçülebilir hale gelir.


---

## 14. Eski kasa verisi — erişilebiliyor, ama çek izi yok

### 14.1 Erişim var

Eski POS sistemi **`INTER_BOS`** veritabanında duruyor (83 GB, aynı sunucu):

| Tablo | Satır | İçerik |
|---|---:|---|
| `BELGE` | 6.404.267 | Fiş başlıkları |
| `HAREKET` | 39.084.989 | Satır kalemleri |
| `ODEME` | 6.341.393 | Ödeme satırları |
| `ISKONTO` | 476.078 | İndirim satırları |

**Tarih aralığı: 01.09.2014 – 31.05.2025.** Yani 11 yıllık satış geçmişi erişilebilir durumda.

⚠ **Boşluk:** eski sistem 31.05.2025'te bitiyor, yenisi 11.07.2025'te başlıyor. Arada **~40 günlük veri boşluğu** var (01.06–10.07.2025). Bu dönemin fişleri her iki sistemde de yok — ayrıca sorulmalı.

### 14.2 Ama kurumsal çek izi YOK

PUAN'da basılan kurumsal çek barkodları (`2141…`, 13 hane) eski POS verisinde **hiçbir kolonda bulunamadı**:

| Aranan yer | Sonuç |
|---|---|
| `ODEME.Cek_Kodu` | 6,3 M satırın **0**'ı dolu |
| `ISKONTO.Cek_Kodu` | 476 K satırın **2**'si dolu |
| `HAREKET.Barkod` / `Stok_Kodu` `'2141%'` | 3.038 satır — ama hepsi **24,90 ₺'lik gerçek bir ürün**, çek değil |
| `ODEME.Ref_No` `'2141%'` | 40 satır (gürültü) |
| `ISKONTO.Aciklama` / `Tus_No` | Tamamı boş/0 — etiketsiz |

Kasadan basılan hediye çekleri izlenebiliyor (`Belge_Tipi='HDY'` 53.798 belge, `HEDIYEDEGISIM` 17.897 kullanım, 2017+) — **ama bunlar kampanya/iade çekleri**, kasa-GUID'i ile çalışıyorlar, PUAN'ın matbaa basımı kurumsal çekleriyle bağları yok.

**Sonuç: eski kasada kurumsal çek, barkod okutulmadan elle indirim/ödeme olarak giriliyordu.** Hangi çeğin ne zaman harcandığı geri getirilemez.

### 14.3 Bunun anlamı

| Soru | Cevaplanabilir mi? |
|---|---|
| 2014–2025 mağaza/kategori satış geçmişi | ✅ Evet — `INTER_BOS` tam |
| 2024 partilerinin gerçek kullanım oranı | ❌ Hayır |
| Taşınmayan 4.593 geçerli çek harcandı mı | ❌ Hayır |
| §13'teki 442 çek daha önce kullanıldı mı | ❌ Hayır |

Bu yüzden §13'ün 1. maddesi değişti: **442 çeği topluca yüklemek riskli.** Bir kısmı eski kasada harcanmış olabilir; topluca yüklemek onlara ikinci kez harcama hakkı verir. Talep geldikçe tek tek açmak doğru yol.

**Yan kazanım:** `INTER_BOS`'un erişilebilir olması bu rapor dışında da değerli — 2014'e uzanan mağaza, kategori ve müşteri satış geçmişi demek. Bugün dashboard'daki tüm tarihsel karşılaştırmalar 11.07.2025'te başlıyor; bu kaynakla 11 yıl geriye gidilebilir. Ayrı bir iş olarak değerlendirilmeli.
