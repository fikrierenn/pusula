# BKM Kitap — Veri ve Analitik Ortamı Keşif Raporu

**Hazırlanma amacı:** Google Cloud (Gemini Enterprise · BigQuery · Vertex AI) iş birliği ön değerlendirmesi
**Hazırlayan:** Fikri Eren, Genel Müdür Yardımcısı (IT · İK · Muhasebe · Finans · Perakende)
**Tarih:** 24 Eylül 2026 · **Sürüm:** 1.1 · **Gizlilik:** Kurumsal — NDA kapsamında paylaşılır

---

## 1. Yönetici Özeti

BKM Kitap, üç kanaldan satış yapan bir perakende ve e-ticaret şirketidir: mağazalar, çevrimiçi mağaza ve okullara toplu satış. Tüm operasyonel veri şirket içi (on-premise) Microsoft SQL Server sistemlerinde tutulur. Bulut ortamı bugün kullanılmamaktadır.

Toplam ham veri yaklaşık **1,1 TB**'tır. Bunun analitik değeri olan çekirdeği **100–150 GB** aralığındadır; kalanı entegrasyon logu ve e-fatura belge arşividir. Mağaza satış geçmişi **2014'ten bugüne** kesintisiz mevcuttur.

Öncelikli hedef kullanım alanları: **talep tahmini ve sipariş önerisi**, **yöneticiler için doğal dilde veri sorgulama** ve **kurumsal bilgi arama**. Kişisel veri içermeyen satış-stok-ürün verisi ilk aşama kapsamındadır; müşteri ve personel verisi KVKK gereği kapsam dışı bırakılmıştır.

---

## 2. Şirket ve İş Modeli

| Başlık | Bilgi |
|---|---|
| Sektör | Kitap, kırtasiye, oyuncak ve hediyelik perakendesi |
| Konum | Bursa merkezli; 3 mağaza, 1 merkez depo, 1 e-ticaret fulfillment deposu |
| Kanallar | Mağaza (POS) · E-ticaret (web + iOS/Android uygulama) · Sınav Okulları (B2B, okullara toplu kitap-kırtasiye) |
| Mevsimsellik | Güçlü. Okul dönemi (Temmuz–Ekim) yıllık cironun büyük kısmını oluşturur. |
| Çalışan | Yaklaşık 200 saha personeli + merkez kadro |
| Ürün çeşidi | ~840.000 tanımlı ürün, ~900.000 barkod |

---

## 3. Mevcut Sistem Mimarisi

Tüm sistemler Microsoft SQL Server üzerinde, şirket içi sunucularda çalışır. Sistemler birbirine veritabanı düzeyinde (linked server) bağlıdır.

| # | Sistem | İşlev | Platform | Veri tazeliği |
|---|---|---|---|---|
| 1 | **ERP** (DerinSIS) | Stok, satış defteri, fatura, muhasebe, cari, fiyat, depo yönetimi (WMS) | SQL Server 2019 | Anlık |
| 2 | **POS** (Encore) | Mağaza kasa fişleri, kampanya, sadakat kartı | SQL Server (2012 uyumluluk modu) | Anlık; ERP'ye saatlik aktarım |
| 3 | **Eski POS arşivi** | 2014 – Temmuz 2025 kasa verisi | SQL Server | Donmuş (yalnız okuma) |
| 4 | **E-ticaret** (JOKER) | Sipariş, müşteri, katalog | SQL Server, ayrı sunucu | Anlık; ERP ile entegre |
| 5 | **CRM** | Sadakat kartı müşteri ana verisi | SQL Server | Anlık |
| 6 | **Sınav Okulları** | Okul, dönem, sipariş listesi | SQL Server | Sezonda anlık |
| 7 | **İK / Bordro** (Zirve) | Bordro, kadro, SGK | SQL Server 2008, ayrı sunucu | Aylık |
| 8 | **PDKS** | Personel giriş-çıkış | SQL Server Express, ayrı sunucu | Anlık |
| 9 | **Raporlama** | Yönetim raporları, Excel çıktıları | SQL Server görünümleri + SQL Agent işleri | Günlük / aylık |

**Veri akışı özeti:**

```
Mağaza kasaları ──saatlik──▶ ERP stok defteri
E-ticaret siparişi ────────▶ ERP irsaliye / fatura
Okul sipariş listesi ──────▶ ERP toplu fatura ──▶ mağazadan teslim
Merkez depo (WMS) ─────────▶ mal kabul → raflama → toplama → mağaza sevk
İK / PDKS ─────────────────▶ aylık bordro, günlük devam
Tüm sistemler ──salt-okuma─▶ Raporlama (görünüm, Excel, e-posta)
```

---

## 4. Veri Varlıkları Envanteri

Rakamlar 24 Eylül 2026 tarihinde canlı sistemlerden alınmıştır.

### 4.1 Veritabanı boyutları

| Veritabanı | Boyut | Not |
|---|---|---|
| ERP | 784 GB | Analitik çekirdek ~50 GB. 177 GB entegrasyon logu, ~230 GB e-fatura XML/PDF arşivi aktarım kapsamı dışında. |
| Eski POS arşivi | 81 GB | 11 yıllık perakende satış geçmişi |
| Hedef / raporlama yardımcı | 71 GB | |
| Web / entegrasyon | 29 GB | |
| POS (güncel) | 15 GB | Temmuz 2025'ten itibaren |
| CRM | 9 GB | |
| Maliyet (FIFO) | 11 GB | |
| İK / Bordro | 0,2 GB | |
| **Toplam ham** | **≈ 1,1 TB** | |
| **Analitik çekirdek (tahmini)** | **100–150 GB** | Log ve belge arşivi düşülmüş |

### 4.2 Ana veri alanları (domain)

| Alan | İçerik | Hacim | Geçmiş derinliği | Tane (grain) |
|---|---|---|---|---|
| **Satış — mağaza (güncel POS)** | Fiş başlık + satır, kampanya, ödeme, kart | 1,4 M fiş · 6,5 M satır | Tem 2025 → | Fiş-satır |
| **Satış — mağaza (arşiv)** | Eski kasa fiş + satır | 6,4 M belge · 39 M satır | 2014 → Tem 2025 | Fiş-satır |
| **Satış — e-ticaret** | Sipariş, satır, kanal (web/iOS/Android), kargo | ~1,3 M sipariş / yıl | 2023 → (öncesi mevcut) | Sipariş-satır |
| **Stok hareketi (ERP defteri)** | Tüm giriş/çıkış: alış, satış, transfer, iade | 59 M satır · 3–4 M / yıl | 2021 → | Hareket |
| **Stok hareketi (günlük özet)** | Ürün × mağaza × gün satış/iade özeti | 13 M satır | 2021 → | Ürün-mağaza-gün |
| **Ürün ana verisi** | Ürün, kategori hiyerarşisi, marka/yayınevi, barkod, KDV | 840 K ürün · 900 K barkod | — | Ürün |
| **Fiyat** | Liste fiyatı ve tarihçesi | 16 M + 158 M satır | 2021 → | Ürün-tarih |
| **Fatura / irsaliye** | Alış-satış faturaları, satırlar | 7 M başlık · 41 M satır | 2021 → | Belge-satır |
| **Muhasebe** | Yevmiye fişleri, mizan | 40 M satır | 2021 → | Fiş-satır |
| **Cari (taraf)** | Müşteri, tedarikçi, mağaza, çalışan | 51 K kayıt | — | Taraf |
| **Depo (WMS)** | Adres, palet, iş emri, operatör hareketi | 5,3 M iş emri satırı · 1,4 M palet hareketi | 2024 → | Palet-hareket |
| **Sipariş önerisi (ERP modülü)** | Kural tabanlı öneri sonuçları | 230 M satır | 2025 → | Ürün-mağaza-gün |
| **İK / Bordro** | Kişi-ay bordro, kadro tipi, SGK gün | ~200 kişi × ay | 2024 → | Kişi-ay |
| **PDKS** | Giriş-çıkış olayı | ~200 kişi × gün | 2025 → | Olay |

### 4.3 Büyüme eğilimi

| Kaynak | Yıllık artış |
|---|---|
| ERP stok hareketi | 3–4 M satır |
| POS fiş (güncel) | ~1 M fiş · ~7 M satır |
| E-ticaret sipariş | ~1,3 M sipariş |
| Tahmini günlük ham artış | 50–100 MB |

---

## 5. Veri Yapısı ve Bilinen Durumlar

### 5.1 Anahtarlar ve ilişkiler

- **Ürün kimliği** tüm sistemlerde ortaktır: ERP ürün numarası POS ürün kodunda ve e-ticaret katalog kaydında birebir taşınır (%99,98 eşleşme). Barkod ürün başına birden fazla olabilir; birincil barkod işaretlidir.
- **Mağaza / depo kimliği** ERP'de taraf (cari) tablosunun bir alt kümesidir; POS ve e-ticarette ayrı kodla eşlenir.
- **Belge kimliği:** POS fişi, ERP irsaliyesi ve e-ticaret siparişi ayrı numaralanır; POS fişi ERP'ye günlük özet olarak geçer, fiş düzeyinde bağ POS tarafında kalır.
- **Müşteri kimliği:** sadakat kartı müşterisi CRM'de tutulur; POS fişine kart numarası ile bağlanır. Kartsız satış anonimdir.

### 5.2 Bilinen veri kalitesi durumları

Aşağıdaki durumlar bilinmekte ve raporlarda dikkate alınmaktadır; aktarım tasarımında da dikkate alınmalıdır.

| Durum | Etki |
|---|---|
| Merkez depo stoğu ERP defteri ile WMS arasında senkron değil | Depo bakiyesi için tek doğru kaynak WMS |
| "Bağlı kayıt yok" NULL yerine `0` ile kodlanmış | Join'lerde `> 0` şartı gerekir |
| Eski ve yeni POS "adet" kavramı farklı (promosyon satırları) | Dönemler arası kıyas satır-tipi süzgeci ister |
| Kod sözlükleri sistemler arası farklı anlamda | Aynı kod farklı tabloda farklı anlam taşıyabilir |
| Türkçe karakter kodlaması (Turkish_CI_AS / CP1254) | Unicode'a dönüşüm gerekir |
| POS veritabanı 2012 uyumluluk modunda | Modern T-SQL fonksiyonları yok |
| KDV oranı doğrudan değil, kod ile | 11 kod, tarihsel değişim; lookup tablosu gerekir |

### 5.3 Mevcut analitik durum

- Yönetim raporları SQL görünümleri ve Excel ile üretilir; günlük ciro, stok, bulunurluk ve İK raporları düzenli çıkar.
- Talep tahmini ve sipariş önerisi ERP'nin kural tabanlı modülüyle çalışır; istatistiksel model yoktur.
- Veri erişimi salt-okuma prensibiyle yönetilir; ERP'ye raporlama tarafından yazma yapılmaz.

---

## 6. Hedef Kullanım Alanları

Öncelik sırasıyla:

| # | Kullanım alanı | İş değeri | Gereken veri | Veri hazır mı | Başarı ölçütü |
|---|---|---|---|---|---|
| 1 | **Talep tahmini ve sipariş önerisi** (ürün × mağaza × hafta) | Sezon öncesi stok yatırımı, stoksuzluk ve fazla stok azaltımı | Satış (11 yıl), stok, fiyat, okul takvimi, kampanya | Evet | Tahmin hatası (MAPE) mevcut kural tabanlı yönteme karşı; bulunurluk oranı |
| 2 | **Doğal dilde veri sorgulama** (yönetim ekibi) | Rapor bekleme süresinin ortadan kalkması | BigQuery + tablo/kolon açıklamaları | Evet | Doğru cevap oranı, referans soru setine karşı |
| 3 | **Kurumsal bilgi arama** | Prosedür, sözleşme, rapor ve yazışmalara tek noktadan erişim | Belge arşivi (ofis dokümanları, e-posta) | Kısmi — envanter çıkarılacak | Bulma süresi, kullanıcı memnuniyeti |
| 4 | **Bulunurluk ve kayıp satış** | Raf boşluğunun gelir etkisi | Günlük stok bakiyesi, satış | Evet | Kayıp satış tahmini doğruluğu |
| 5 | **Sezon kadro planlama** | Saat × mağaza yoğunluğuna göre vardiya | Saatlik POS, bordro | Evet | Norm vs gerçek sapma |
| 6 | **Fiyat ve ölü stok analizi** | Eskime, indirim kararı | Fiyat tarihçesi, stok yaşı | Evet | — |
| 7 | **Muhasebe anomali tespiti** | Kapanış sonrası müdahale, Benford | Yevmiye (40 M) | Evet | Yanlış pozitif oranı |
| 8 | **Müşteri segmentasyonu** | Sadakat, yeniden kazanım | Kartlı müşteri işlemleri (252 K aktif) | Kısmi — KVKK değerlendirmesi gerekir | Kapsam dışı (ilk aşama) |

**Önerilen ilk PoC:** Kullanım alanı 1 veya 2, 6–8 hafta, tek kanal (mağaza), kişisel veri içermeyen veri seti.

---

## 7. Teknik Kısıtlar ve Entegrasyon Değerlendirmesi

### 7.1 Kısıtlar

- Tüm veri şirket içi; bulutta hiçbir bileşen yok. Dışa bağlantı için güvenli tünel veya VPN kurulmalı.
- ERP ve POS veritabanlarına **yazma yapılmaz**. Aktarım salt-okuma olmalı (CDC veya toplu dışa aktarım).
- Kaynak sistemler 4 ayrı sunucuda; İK sistemi SQL Server 2008, PDKS SQL Server Express.
- POS veritabanı 2012 uyumluluk modunda.
- Entegrasyon logu (5,5 milyar satır) ve e-fatura belge arşivi (~230 GB) aktarım dışıdır.
- ERP'de CDC / Change Tracking açılması ERP tedarikçisi ve DBA onayı gerektirir.

### 7.2 Ön değerlendirmemiz (Google ile teyit edilecek)

| Kaynak | Uygun görünen yol | Not |
|---|---|---|
| ERP, POS, CRM (SQL Server 2019) | **Datastream** (CDC) — gerçek zamana yakın | SQL login gerekir (Windows kimlik doğrulama desteklenmiyor) |
| Eski POS arşivi, tarihsel yük | **Dataflow** (JDBC toplu) — tek seferlik | 11 yıllık veri |
| İK (SQL 2008), PDKS (Express) | Toplu aktarım (günlük / aylık) | Datastream desteklemiyor |
| E-ticaret (ayrı sunucu) | Datastream veya toplu | Sunucu erişimi ayrıca planlanır |
| Tablo / kolon açıklamaları | BigQuery açıklama alanları + Knowledge Catalog | ERP tedarikçisi veri sözlüğü + şirket içi bilgi |

### 7.3 Hacim ve maliyet beklentisi

- BigQuery depolama: 150 GB başlangıç, günlük 50–100 MB artış.
- Sorgu yükü: günlük yönetim raporları; toplam taranan veri partition/clustering ile düşük kalır.
- Gemini Enterprise kullanıcı: ~10 yönetici (tam), ~200 saha personeli (ileri aşama, sınırlı).

---

## 8. Güvenlik, Gizlilik ve Uyum

### 8.1 Veri sınıflandırması

| Sınıf | İçerik | İlk aşama |
|---|---|---|
| **Kişisel veri yok** | Ürün, stok, fiyat, satış (fiş düzeyinde, kimliksiz), depo, muhasebe toplamları | **Kapsamda** |
| **Kişisel veri** | Müşteri ad/telefon/kart, çalışan bilgileri, bordro | Kapsam dışı; gerekirse hash'li kimlik |
| **Özel nitelikli / çocuk verisi** | Sınav Okulları öğrenci bilgileri | Kesinlikle kapsam dışı |
| **Ticari sır** | Tedarikçi anlaşma fiyatları, marj | NDA sonrası, toplam düzeyinde |

### 8.2 Uyum gereksinimleri

- **KVKK yurt dışı aktarım:** Türkiye'de Google Cloud bölgesi bulunmadığından aktarım KVKK m.9 kapsamındadır. Standart Sözleşme ve Kurul bildirimi (5 iş günü) şirket hukuk müşaviri ile yürütülür. İlk aşama kişisel veri içermediği için risk düşüktür.
- **Veri yerleşimi:** AB çoklu bölge (`eu`) tercih edilir.
- **Model eğitimi:** Kurumsal verinin model eğitiminde kullanılmayacağı sözleşmede açık madde olarak beklenir.
- **Sertifikalar:** ISO 27001 ve ISO 27701 raporları talep edilir.
- **Erişim:** Salt-okuma servis hesabı, en az yetki; ERP yazma yetkisi hiçbir bileşene verilmez.

---

## 9. Önerilen Yol Haritası

| Aşama | Süre | İçerik | Çıktı |
|---|---|---|---|
| **0. Hazırlık** | 2 hafta | NDA, sözleşme çerçevesi, ağ bağlantısı, servis hesabı, kapsam onayı | İmzalı çerçeve, erişim |
| **1. Veri aktarımı** | 2–3 hafta | Kişisel veri içermeyen çekirdek (satış, stok, ürün, fiyat) → BigQuery; tablo/kolon açıklamaları | Sorgulanabilir BigQuery veri seti |
| **2. PoC** | 4–6 hafta | Talep tahmini (tek kanal) **veya** doğal dilde sorgu (yönetim) | Ölçülmüş başarı metriği vs mevcut yöntem |
| **3. Değerlendirme** | 1 hafta | Sonuç, maliyet, genişleme kararı | Karar belgesi |

---

## 10. Google'dan Beklenen Bilgiler

1. On-premise SQL Server 2019 için önerilen aktarım mimarisi ve ağ gereksinimleri (Datastream / Dataflow).
2. Türkiye müşterisi için veri yerleşimi seçenekleri ve KVKK'ya ilişkin sözleşme belgeleri (DPA, SCC).
3. Gemini Enterprise'da kurumsal verinin model eğitiminde kullanılmadığına dair sözleşme maddesi.
4. Tablo/kolon açıklamaları ve iş metriklerinin Knowledge Catalog ve Conversational Analytics bağlamına nasıl tanımlanacağı; örnek.
5. Lisans modeli: yönetici ve saha personeli için koltuk tipleri ve fiyatlama.
6. Türkçe metin ve arama kalitesi (embedding, NL→SQL) için referans.
7. PoC için Google/partner tarafından sağlanacak kaynak ve süre önerisi.

---

## Ek A — Aktarım Kapsamındaki Ana Tablolar (teknik)

| Sistem | Tablo | İçerik | Satır | Boyut |
|---|---|---|---|---|
| ERP | `irsHrk` | Stok hareket defteri | 59,4 M | 4,9 GB |
| ERP | `posOzetUrun` | Ürün × mağaza × gün POS özeti | 13,3 M | 1,1 GB |
| ERP | `irs` / `irsAyr` | İrsaliye başlık / satır | 7,1 M / 68 M | 1,1 / 10,5 GB |
| ERP | `fat` / `fatAyr` | Fatura başlık / satır | 7,1 M / 41 M | 1,4 / 7,7 GB |
| ERP | `urn` · `urnBrkd` · `urnKtgr*` | Ürün, barkod, kategori | 840 K · 898 K | — |
| ERP | `fyt` · `fytOzl` | Fiyat, fiyat tarihçesi | 15,8 M · 158 M | 0,9 / 20 GB |
| ERP | `frm` | Taraf (müşteri/tedarikçi/mekan) | 51 K | — |
| ERP | `mhs.mhsFis` · `mhsFisBaslik` | Yevmiye satır / başlık | 39,6 M / 15,3 M | 4,1 / 1,5 GB |
| ERP | `depo.*` | WMS: adres, palet, iş emri | 5,3 M + 1,4 M | — |
| POS | `Sales` · `SalesProducts` · `Products` | Fiş, satır, ürün | 1,4 M · 6,5 M · 873 K | 14,5 GB (toplam) |
| Eski POS | `BELGE` · `HAREKET` | Fiş, satır (2014–2025) | 6,4 M · 39 M | 81 GB (toplam) |
| E-ticaret | `J_ORDERS` · `J_ORDER_DETAILS` · `J_ITEMS` | Sipariş, satır, ürün | ~1,3 M/yıl | — |

**Aktarım dışı:** `ent.api_log` (5,5 milyar satır, 177 GB), e-fatura arşiv şemaları (~230 GB), test veritabanları, kişisel veri içeren CRM/İK/PDKS/Sınav tabloları (ilk aşama).

## Ek B — Sözlük

| Terim | Anlam |
|---|---|
| ERP | Kurumsal kaynak planlama; stok, fatura, muhasebe sistemi |
| POS | Mağaza kasa sistemi |
| WMS | Depo yönetim sistemi (adres/palet düzeyi) |
| PDKS | Personel devam kontrol sistemi |
| CDC | Change Data Capture; kaynak veritabanındaki değişikliği anlık yakalama |
| Tane (grain) | Bir tablodaki tek satırın temsil ettiği birim |
