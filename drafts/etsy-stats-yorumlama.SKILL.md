---
name: etsy-stats-yorumlama
description: Etsy Stats / Search Visibility Dashboard / Marketplace Insights (Eylül 2025) verilerini yorumlama disiplini. ATLASCOREUS mağazası için listing veya shop seviyesi performans verisi yapıştırıldığında funnel analizi (impression → visit → favorite → sale), dwell time yorumu, rank kaybı tespiti, mevsim vs algoritma vs kalite ayrımı yapar; revize kararı çıkarır. "Bu listing düşük performansta neden", "Etsy Stats yorumla", "trafik düştü", "conversion neden zayıf", "Marketplace Insights ne diyor", "Search Visibility Dashboard sebep ne" ifadelerinde tetikle. Eşik bantları (CTR %1 altı kötü, %5 üzeri mükemmel; conversion %1 altı kötü, %3 üzeri iyi), benchmark karşılaştırma, Confidence Discipline (Etsy resmi dashboard vs 3rd party tool), 5 olası sebep listesi (algoritma/mevsim/rakip/kalite/listing içi) içerir. etsy-listing-revize'ye direkt input; veri-yorumlama generic disiplini referans; kok-sebep ile zincirleme.
---

# Etsy Analitik: Stats ve Search Visibility Yorum Disiplini

Bu skill bir Etsy Stats raporu üreteci, 3rd party SEO tool (Marmalead / eRank / EverBee) entegrasyonu veya dashboard oluşturucu DEĞİLDİR. ATLASCOREUS mağazasının Etsy Stats / Search Visibility Dashboard / Marketplace Insights verilerini sistematik yorumlama disiplinidir. Birincil hedef: Performans verisi yapıştırıldığında "ne anlama geliyor + ne yapmalı" sorularını karar değerli cevaplamak; revize kararının kaynağı olmak.

---

## 0. Felsefe

Listing yayınlamak yarısı; performansı okumak diğer yarısı. Etsy Stats karmaşık görünüyor ama 4 temel funnel adımı var:

**Impression → Visit → Favorite → Sale**

Her geçişin oranı *ne* olduğunu anlatıyor, *neden* olduğunu değil. "Neden" sorusu için Search Visibility Dashboard + Marketplace Insights + dış kanıtlar (rakip, mevsim) gerekli.

Üç tehlike:
- **Mevsimi algoritmaya yormak:** Eylül-Kasım Father's Day fiyaskosu beklenebilir; "rank düştü, algoritma değişti" yanılgısı yanlış müdahaleye götürür.
- **Tek metric'e bakmak:** Sadece impression veya sadece conversion bakmak misleading; funnel her aşaması karşılaştırılır.
- **Etsy resmi data yerine 3rd party tahmin:** eRank / Marmalead estimate ediyor; resmi data Etsy Stats + Marketplace Insights. Karar resmi data ile verilir.

**Kural:** Her yorum funnel'ın hangi aşaması sorunlu + Confidence + sebep adayı listesi + revize tipi önerisi ile çıkar; "trafik düşük" yorumu yetmez.

---

## 1. Context Layer

**Hedef DEĞİLDİR:**
- Dashboard tasarımı (bi-dashboard)
- KPI tanımlama (kpi-tasarim)
- Yeni listing yazımı (etsy-listing)
- Listing revizyon (etsy-listing-revize, ama bu skill onun input'u)
- 3rd party tool eğitimi (Marmalead/eRank dokümantasyonu)
- Etsy Ads ROI hesabı (ayrı disiplin)

**Hedef ŞUDUR:**
- Etsy Stats verisi (yapıştırılan) yorumu
- Search Visibility Dashboard "reduced visibility" sebep okuma
- Marketplace Insights tool sonuçlarını listing kararına dönüştürmek
- Funnel breakdown: hangi aşamada düşüş var
- Benchmark karşılaştırma (kendi geçmişi vs kategori ortalaması vs ATLASCOREUS hedef)
- Sebep adayı listesi + Confidence (algoritma/mevsim/rakip/kalite/listing içi)
- Revize tipi önerisi (etsy-listing-revize'ye geçiş)

### 1.1 Tetikleme sinyalleri

| Durum | Tetikle? |
|---|---|
| "Bu listing'in stats'i" + veri yapıştır | EVET |
| "Trafik düştü, neden" | EVET |
| "CTR neden zayıf" | EVET |
| "Conversion düşük yorumla" | EVET |
| "Marketplace Insights ne diyor" | EVET |
| "Search Visibility Dashboard sebep" | EVET |
| "Mağaza geneli performans" | EVET |
| "Bu listing'i revize edelim mi" | KISMI, önce bu skill → sonra etsy-listing-revize |
| "Yeni listing yaz" | HAYIR, etsy-listing |
| "KPI tasarla" | HAYIR, kpi-tasarim |
| Generic "Etsy nasıl çalışır" | HAYIR, eğitim işi |

---

## 2. Priority Order (Yorum Çatışmaları)

1. **Etsy resmi data:** Etsy Stats + Search Visibility Dashboard + Marketplace Insights önce; 3rd party tahmin sonra
2. **Funnel breakdown:** Impression → Visit → Favorite → Sale her aşaması ayrı yorumlanır
3. **Confidence Discipline:** Sebep iddiası kanıt katmanı (H/M/L); düşük güvenli karar olmaz
4. **Karşılaştırma yöntemi:** Kendi geçmişi (önceki dönem) + kategori ortalaması + ATLASCOREUS hedefi
5. **Mevsim filtresi:** Mevsim normal düşüşü algoritma sanma; yıllık trend kontrolü
6. **Revize karar:** Hangi revize tipi (etsy-listing-revize Section 4 referansı)
7. **Format:** en son

Çakışma anında üst sıradaki kazanır. "Hemen müdahale" baskısı sebep teşhisini geçemez.

---

## 3. Etsy Stats Funnel Anatomisi

Her listing/shop verisi bu 4 adımda okunur:

**Stage 1: Impression (Görüntülenme)**
- Etsy search/category'de listing kaç kez gösterildi
- Ölçü: kaç binlerce
- Sağlayıcılar: title/tags relevance + recency + category dolu

**Stage 2: Visit (Tıklama / Ziyaret)**
- Impression'lardan kaç tanesi tıklandı
- Ölçü: CTR = Visit / Impression
- Sağlayıcılar: thumbnail + title ilk 50-70 char + price + free shipping badge

**Stage 3: Favorite (Beğeni)**
- Visit'lerin kaç tanesi favoriye eklendi
- Ölçü: Favorite rate = Favorite / Visit
- Sağlayıcılar: description hook + image kalitesi + dwell time

**Stage 4: Sale (Satın Alma)**
- Visit'lerin kaç tanesi satın alındı (favori önemli ara metric)
- Ölçü: Conversion rate = Sale / Visit
- Sağlayıcılar: tüm önceki + review + price + variations + personalization friction

### 3.1 Eşik Bantları (ATLASCOREUS hedef)

| Metric | Kötü | Orta | İyi | Mükemmel |
|---|---|---|---|---|
| CTR (Visit/Impression) | <1% | 1-2% | 2-5% | >5% |
| Favorite rate (Favorite/Visit) | <2% | 2-5% | 5-10% | >10% |
| Conversion rate (Sale/Visit) | <1% | 1-3% | 3-5% | >5% |
| Dwell time (saniye) | <10s | 10-30s | 30-60s | >60s |
| Review skoru | <4.5 | 4.5-4.8 | 4.8-5.0 | 5.0 stable |

Eşikler kategori bağımlı. POD apparel için orta-üst beklenir; handmade jewellery daha yüksek.

### 3.2 Hangi aşama sorunlu (Diagnosis)

**Yüksek impression + Düşük CTR:**
- Sorun: Thumbnail veya title ilk 50-70 char zayıf
- Çözüm: CTR Boost revize (etsy-listing-revize Section 4.3)

**Yüksek visit + Düşük favorite:**
- Sorun: Description hook zayıf veya image kalitesi düşük
- Çözüm: Conversion Boost description rewrite

**Yüksek visit + Düşük conversion:**
- Sorun: Fiyat + shipping rate + review skoru
- Çözüm: Shipping >$6 ise fiyat yedir; review sayısı artır
- Veya: Conversion Boost description (dwell time uzatıcı içerik)

**Düşük impression (başta sorun):**
- Sorun: Keyword relevance + recency veya compliance
- Çözüm: SEO Refresh veya Compliance Fix

---

## 4. Search Visibility Dashboard (Etsy 2026)

Etsy 2026'da hangi listing'in visibility düştüğünü ve neden olduğunu gösteriyor. Erişim: **Shop Manager → Marketing → Search Visibility**.

### 4.1 Tipik "reduced visibility" sebepleri

| Sebep | Etsy mesajı | Aksiyon |
|---|---|---|
| Compliance ihlali | "Listing may violate Creativity Standards" | Compliance Fix derhal |
| Shipping >$6 ABD | "High shipping price may reduce visibility" | Fiyat yedirme veya $35+ free shipping |
| Trademark çağrışım | "Possible IP concern" | etsy-trademark skill devreye |
| Listing completeness | "Add more attributes / about / materials" | Eksik attribute doldur |
| Photo quality | "Low resolution / cluttered" | Image revize (atlascoreus-marka Section 14) |
| Recency | "Listing has not been updated recently" | Recency Micro-Edit |
| Star Seller etki | "Shop-level signals" | Response time + on-time shipping + case rate düzelt |
| Personalization compliance | "Primary image placeholder" | etsy-personalization Section 7 |

### 4.2 Search Visibility Dashboard kullanım disiplini

- Her revize kararından önce dashboard kontrol et; Etsy doğrudan sebep söylüyorsa diagnosis süresi kısalır
- "Reduced visibility" yoksa sebep listing dışı (mevsim, rakip, algoritma update)
- Tek listing değil tüm mağaza tara; pattern varsa shop-level sorun

---

## 5. Marketplace Insights Tool (Eylül 2025+)

Etsy Eylül 2025'te gerçek search volume veren bir tool çıkardı (önceden 3rd party eRank/Marmalead estimate veriyordu).

### 5.1 Kullanım

- Erişim: **Shop Manager → Marketing → Marketplace Insights**
- Keyword ara: gerçek volume + trend (artıyor mu, azalıyor mu)
- ATLASCOREUS niş'inde "vintage naturalist tee", "field guide t-shirt", "cottagecore father's day" sorgulanır

### 5.2 Sınırlamalar

- Etsy app traffic'i kapsamıyor olabilir (Etsy resmi açıklama tam değil)
- Mağaza level değil keyword level data
- Niş'inde düşük volume keyword'ler için veri yetersiz olabilir

### 5.3 3rd Party Tool Karşılaştırması

| Tool | Volume verisi | Confidence | Maliyet |
|---|---|---|---|
| Marketplace Insights (resmi) | Etsy data | High | Ücretsiz |
| Marmalead | Etsy estimate | Medium | $19+/ay |
| eRank | Etsy estimate | Medium | $5.99-$29.99/ay |
| EverBee | Etsy estimate + revenue tahmin | Medium-Low | $19.99+/ay |

Karar resmi data ile verilir; 3rd party tool çapraz doğrulama olarak kullanılır.

---

## 6. Confidence Discipline (Sebep İddia Kanıtı)

"Trafik düştü çünkü algoritma değişti" iddiasında kanıt katmanı:

| Seviye | Koşullar | Dil |
|---|---|---|
| **High** | Etsy resmi duyuru + Search Visibility Dashboard mesajı + tarih kanıtı | "X sebebiyle; resmi kaynak: Etsy Seller Handbook tarih" |
| **Medium** | 3rd party tool + topluluk gözlemi + birden fazla satıcı teyit | "Topluluk gözlemi; resmi doğrulama Search Visibility Dashboard'da kontrol" |
| **Low** | Sezgisel "algoritma değişti", anekdot, tek satıcı şikayet | "Sezgisel; başka sebep olabilir (mevsim, rakip, listing içi)" |

Düşük güvenli sebep → "önce diğer sebepleri ekarte et" önerisi; doğrudan revize kararı yok.

---

## 7. 5 Olası Sebep Listesi (Düşüş Tanılaması)

Performans düştüğünde her sebep tek tek ekarte edilir.

### 7.1 Algoritma güncellemesi
- Etsy Seller Handbook tarihli duyuru var mı
- Search Visibility Dashboard "reduced visibility" işaretli mi
- Toplulukta yaygın şikayet var mı (Reddit r/EtsySellers, Etsy Community Forum)
- Şubat 2026 title 70 char + shipping >$6 gibi major update'ler

### 7.2 Mevsim
- Yıllık trend kontrol (Etsy Stats yıllık karşılaştırma)
- Ürün niche'inin doğal düşüş dönemi mi (Father's Day Temmuz'da düşer, Aralık'ta sıfır)
- Mevsim normal düşüş algoritma sanmak en yaygın yanılgı

### 7.3 Rakip yoğunluğu
- Aynı niş'te yeni listing dalgası mı (Marmalead/eRank competition score)
- Rakip yeni özellik mi getirdi (personalization, video, free shipping)
- Etsy app reklamı rakibin lehine mi çalışıyor

### 7.4 Listing kalitesi
- Listing 6+ ay güncellendi mi (recency cezası %3/ay)
- Compliance eksiklik var mı (disclosure, primary image)
- Photo quality kötü mü
- Title 70 char altı mı (Şubat 2026 standartı)

### 7.5 Mağaza seviyesi
- Star Seller status değişti mi
- Response time düştü mü (24 saat aşıldı mı)
- On-time shipping oranı düştü mü
- Case rate (anlaşmazlık) yükseldi mi
- Review skoru 5.0'dan düştü mü

### 7.6 Listing içi spesifik
- Personalization compliance (primary image, 5 field disiplini)
- Trademark çağrışım sinyali
- File upload IP riski

---

## 8. Karşılaştırma Disiplini

Yorum yaparken 3 kıyaslama düzlemi:

### 8.1 Kendi geçmişi (Self benchmark)
- Bu listing'in son 7/30/90 gün stats vs aynı dönem geçen yıl
- "Trafik düştü" → ne ile karşılaştırıyoruz

### 8.2 Mağaza ortalaması (Shop benchmark)
- Bu listing'in performansı mağaza ortalamasıyla nasıl
- Mağazanın diğer listing'leri stable mı, bu özelinde mi sorun

### 8.3 Kategori ortalaması (Market benchmark)
- POD apparel kategorisinde ortalama CTR/conversion ne
- Marmalead/eRank competition score
- ATLASCOREUS niş'inde ortalama performance

### 8.4 ATLASCOREUS hedef (Target benchmark)
- Hedef CTR >2%, conversion >3% (Section 3.1)
- Hedefe ne kadar uzak

---

## 9. Çıktı Formatı (Stats Yorum Raporu)

```markdown
## ETSY STATS YORUMU: [listing adı veya mağaza]

### 1. DATA ÖZETİ
- Tarih aralığı: [son 7/30/90 gün]
- Impression: XX
- Visit: XX  (CTR: %X)
- Favorite: XX  (Favorite rate: %X)
- Sale: XX  (Conversion: %X)
- Review skoru: X.X
- Dwell time tahmini: XX saniye (varsa)

### 2. FUNNEL ANALİZİ
- Stage 1 (Impression): İYİ / ORTA / KÖTÜ + sebep
- Stage 2 (Visit, CTR): EŞİK BAND
- Stage 3 (Favorite): EŞİK BAND
- Stage 4 (Sale, Conversion): EŞİK BAND

**Hangi aşama sorunlu:**
[Funnel'da en zayıf geçiş + olası sebep]

### 3. KARŞILAŞTIRMA
- Kendi geçmişi: [son 90 gün vs önceki 90 gün]
- Mağaza ortalaması: [bu listing ortalamadan + veya −]
- Kategori benchmark: [POD apparel ortalaması]
- ATLASCOREUS hedef: [eşik bandı]

### 4. SEARCH VISIBILITY DASHBOARD
- Reduced visibility: VAR / YOK
- Etsy sebep mesajı: [varsa]
- Hızlı aksiyon önerisi: [varsa]

### 5. SEBEP ADAYI LİSTESİ
**Confidence: High / Medium / Low**

1. **Algoritma:** [evet/hayır + kanıt]
2. **Mevsim:** [evet/hayır + yıllık trend]
3. **Rakip:** [evet/hayır + competition score]
4. **Listing kalite:** [evet/hayır + son edit tarihi]
5. **Mağaza seviyesi:** [evet/hayır + Star Seller durumu]

### 6. ASIL SEBEP TAHMİNİ
[En güçlü sebep + Confidence]

### 7. REVİZE TİPİ ÖNERİSİ
**Önerilen:** SEO Refresh / Compliance Fix / CTR Boost / Conversion Boost / Recency Micro-Edit
**etsy-listing-revize'ye geç:** [hangi tip ile başlamalı]

### 8. NOTLAR
- Verinin sınırlamaları: [tahmin edilen, kesin olmayan kısım]
- 30 gün sonra tekrar bakılacak metric: [...]
```

---

## 10. Operational Memory (Pattern Library)

### 10.1 Sık görülen yorum kalıpları

| Pattern | Sinyal | Sebep tahmini | Aksiyon |
|---|---|---|---|
| Yüksek impression + düşük CTR | %1 altında CTR | Thumbnail veya title zayıf | CTR Boost (etsy-listing-revize 4.3) |
| Düşük impression genel | 30 günde <500 impression | Keyword relevance / compliance / recency | SEO Refresh veya Compliance Fix |
| Yüksek visit + düşük conversion | %1 altında conversion | Fiyat, shipping, review | Conversion Boost veya shipping fix |
| Stable trafik, sıfır sale | 100+ visit, 0 sale | Description, fiyat, dwell time | Conversion Boost |
| Aniden trafik kaybı (%20+) | 7 günde kayıp | Algoritma update veya rakip | Search Visibility Dashboard önce |
| Mevsim düşüşü algoritma sanılması | Father's Day sonrası Temmuz | Mevsim normal | Bekle, micro-edit yeterli |
| 6+ ay güncellenmemiş listing | Stabil ama yavaş düşüyor | Recency cezası (%3/ay) | Recency Micro-Edit |
| Yeni rakip dalgası | Marmalead competition score arttı | Rakip yoğunluğu | Niş kayması veya farklılaşma |
| Star Seller kaybı sonrası | Tüm listing'lerde düşüş | Mağaza seviyesi | Response time + shipping disiplin |
| Compliance ihlali takedown sonrası | Visibility sıfıra düştü | Etsy enforcement | Compliance Fix + appeal (Temmuz 2025+) |

### 10.2 Yaygın yanılgılar (anti-pattern)

- **"Trafik düştü, algoritma değişti":** %80 olasılıkla mevsim veya rakip; algoritma son sebep
- **"Conversion düşük, fiyat düşürelim":** Fiyat düşürmek conversion'ı arttırmayabilir; description + dwell time öncelikli
- **"3rd party tool'a göre rank 3, neden bu kadar az visit":** tool estimate; gerçek visit Etsy Stats'tan
- **"Tek listing'in stats'ine bakıp mağaza geneli yorum":** pattern için 5-10 listing karşılaştır
- **"Kategori ortalaması yok, sadece kendi geçmişine bak":** external benchmark olmadan yorum eksik

### 10.3 ATLASCOREUS özelinde

- **Moon serisi performans:** 4 listing'in ortalaması; eğer Field Guide formatına geçişle düştüyse mevcut başarısızlık trademark çağrışım korkusundan değil olabilir
- **Comfort Colors premium pozisyonlama:** Ivory en güvenli, Mustard sezonsal (Halloween/Thanksgiving), Blue Spruce kış
- **Father's Day / Mother's Day seasonal:** 6 hafta öncesinden listing indekslenmeli; mevsim sonrası %50 düşüş normal
- **POD apparel kategori CTR ortalaması:** ~2-3% (kategori bağımlı)

---

## 11. Final Behavior Rule

3rd party SEO tool, dashboard üreteci veya rapor sunum aracı GİBİ DAVRANMA.

Şu rollerden gibi davran:
- funnel breakdown disiplini hatırlatıcısı
- mevsim vs algoritma vs kalite ayrımı yapıcısı
- Etsy resmi data önce, 3rd party tahmin sonra önceliği
- revize tipi karar verici (etsy-listing-revize Section 4 referansı)
- "trafik düştü" yüzeysel yorumuna karşı koruyucu

**Birincil hedef:**
- ATLASCOREUS performans verisi yorumlarken funnel'ın hangi aşaması sorunlu + Confidence + sebep adayı listesi + revize tipi önerisi sunmak
- Yüzeysel yorumla yanlış müdahale yaptırmamak
- Etsy resmi data (Stats + Search Visibility + Marketplace Insights) önce; 3rd party tahmin sonra
- Mevsim düşüşünü algoritma değişikliği saydırmamak

---

## 12. Skill Chain (Diğer skill'lerle ilişki)

| Birlikte tetikle | Ne zaman |
|---|---|
| **etsy-listing-revize** | Revize tipi tespit edildikten sonra direkt input; bu skill diagnosis, o skill aksiyon |
| **veri-yorumlama** | Generic disiplin referansı (5 lens framework, Severity Filter, Pattern Library); bu skill onun Etsy spesifik uygulaması |
| **etsy-listing** | Yorum sonucu "yeni listing daha iyi" çıkarsa (mevcut çok bozuk); deaktif + yeni |
| **kok-sebep** | Düşüş tekrarlanıyorsa veya çoklu listing'de aynı pattern; "neden böyle" zinciri |
| **kpi-tasarim** | Mağaza KPI tasarımı için bu skill'in funnel'ı baz alınır |
| **bi-dashboard** | Mağaza panosu kurulacaksa Etsy Stats datası buraya akar (gelişmiş senaryo) |
| **risk-tarama** | Aniden büyük trafik kaybı = ciddi risk; risk değerlendirme tetiklenir |

**Override kuralı:**
- Etsy resmi data (Stats + Search Visibility + Marketplace Insights) her zaman öncelikli; 3rd party tool sonuçları çapraz doğrulama olarak kullanılır
- Düşük Confidence (Low) sebep iddiasıyla revize kararı verilmez; önce diğer sebepleri ekarte et
- Mevsim düşüşü algoritma değişikliği saydırılmaz; yıllık trend kontrolü zorunlu
- Tek listing yorumla mağaza geneli karar verilmez; pattern için 5-10 listing karşılaştırma

---

## 13. Versiyonlama

- **v1.0 (2026-05-17):** İlk sürüm. Universal Upgrade Framework + Etsy Stats funnel anatomisi + Search Visibility Dashboard (2026) + Marketplace Insights Tool (Eylül 2025) + 5 olası sebep listesi + eşik bantları + karşılaştırma disiplini + 10 pattern + ATLASCOREUS özelinde gözlemler.
