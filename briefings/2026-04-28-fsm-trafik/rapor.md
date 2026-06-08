# FSM Trafik & Dönüşüm Analizi — 8-28 Nis 2026

**Mağaza:** Bursa Nilüfer FSM (StoresId=2) · **Dönem:** 21 gün · **Üretim:** 28 Nis 2026 Salı
**Kaynak:** Kapı sayıcı (yeni) + EncoreMerkez Sales

---

## Üst Özet

- **Dönüşüm: %52,1** (toplam 41.831 giriş → 21.798 fiş, 21 gün ortalama). Bant çok dar (%47-53), sektör için sağlıklı.
- **Sepet ortalaması: 530 ₺** · **Müşteri başı (kişi-başı ciro): 276 ₺**
- **23 Nis Çocuk Bayramı patlaması teyit:** Trafik +%48, sepet +%25, ciro +%85 (hafta içi ortalamasına göre).
- **FSM düşük sepet sorunu** trafik veya dönüşüm değil — **ürün karışımı + müşteri profili**.

---

## 1) 21 Gün Tablo

| Tarih | Gün | Giriş | Fiş | Net Ciro ₺ | Dönüşüm % | Sepet ₺ | Kişi başı ₺ |
|---|---|---:|---:|---:|---:|---:|---:|
| 08.04 | Çar | 1.598 | 974 | 530.593 | 61,0 | 545 | 332 |
| 09.04 | Per | 1.669 | 870 | 480.370 | 52,1 | 552 | 288 |
| 10.04 | Cum | 1.631 | 818 | 449.036 | 50,2 | 549 | 275 |
| **11.04** | **Cmt** | **2.716** | 1.421 | 791.735 | 52,3 | 557 | 291 |
| 12.04 | Pzr | 2.568 | 1.266 | 748.839 | 49,3 | 591 | 292 |
| 13.04 | Pzt | 1.873 | 922 | 441.393 | 49,2 | 479 | 236 |
| 14.04 | Sal | 1.814 | 951 | 486.503 | 52,4 | 512 | 268 |
| 15.04 | Çar | 1.986 | 1.056 | 496.893 | 53,2 | 471 | 250 |
| 16.04 | Per | 1.795 | 905 | 458.171 | 50,4 | 506 | 255 |
| 17.04 | Cum | 1.929 | 1.021 | 524.274 | 52,9 | 513 | 272 |
| 18.04 | Cmt | 2.565 | 1.324 | 742.296 | 51,6 | 561 | 289 |
| 19.04 | Pzr | 2.384 | 1.217 | 671.015 | 51,1 | 551 | 281 |
| 20.04 | Pzt | 1.703 | 872 | 422.149 | 51,2 | 484 | 248 |
| 21.04 | Sal | 1.796 | 851 | 460.583 | **47,4** | 541 | 256 |
| 22.04 | Çar | 1.589 | 817 | 393.959 | 51,4 | 482 | 248 |
| **23.04** 🇹🇷 | **Per** | **2.658** | **1.390** | **874.597** | **52,3** | **629** | **329** |
| 24.04 | Cum | 1.793 | 892 | 445.451 | 49,8 | 499 | 248 |
| 25.04 | Cmt | 2.475 | 1.293 | 644.741 | 52,2 | 499 | 261 |
| 26.04 | Pzr | 2.173 | 1.151 | 628.003 | 53,0 | 546 | 289 |
| 27.04 | Pzt | 1.804 | 857 | 403.314 | **47,5** | 471 | 224 |
| 28.04 | Sal | 1.812 | 909 | 410.752 | 50,2 | 452 | 227 |
| **TOPLAM** | 21 gün | **41.831** | **21.798** | **11.555.661** | **52,1** | **530** | **276** |

---

## 2) Gün-Tipi Karşılaştırma

| Gün Tipi | Gün | Ort. Giriş/gün | Ort. Fiş/gün | Dönüşüm % | Sepet ₺ | Kişi başı ₺ |
|---|---:|---:|---:|---:|---:|---:|
| Hafta içi (Pzt-Per) | 12 | 1.792 | 935 | 52,2 | 505 | 264 |
| Cuma | 3 | 1.784 | 910 | 51,0 | 516 | 263 |
| **Cumartesi** | 3 | **2.585** | 1.346 | 52,1 | 540 | 281 |
| Pazar | 3 | 2.375 | 1.211 | 51,1 | 562 | 287 |

**Yorumlar:**
- **Cumartesi haftanın trafik zirvesi** (+%44 hafta içine göre).
- Dönüşüm günden güne **çok stabil** (%51-52 bandı) — operasyon istikrarlı.
- Hafta sonu sepet 540-562 ₺ vs hafta içi 505 ₺ → aile alışverişi etkisi (+%7-11).
- **Cuma şaşırtıcı:** trafiği hafta içi seviyesinde, "hafta sonu öncesi alışveriş" yok — gerçek alışveriş Cmt-Pzr blok.

---

## 3) 23 Nis Çocuk Bayramı — Patlama

| Metrik | 23 Nis | Hafta içi ort. | Δ | Cmt-Pzr ort. | Δ |
|---|---:|---:|---:|---:|---:|
| Giriş | **2.658** | 1.792 | **+%48** | 2.480 | +%7 |
| Fiş | **1.390** | 935 | **+%49** | 1.279 | +%9 |
| Net Ciro | **874.597** | 472.535 | **+%85** | 704.438 | **+%24** |
| Dönüşüm % | 52,3 | 52,2 | ≈eşit | 51,6 | +0,7pp |
| **Sepet ₺** | **629** | 505 | **+%25** | 551 | **+%14** |
| **Kişi başı ₺** | **329** | 264 | **+%25** | 284 | **+%16** |

**Yapısal mesaj:** Bayram günü sadece "daha fazla insan geldi" değil — **gelen müşteri daha pahalı/özel ürünler aldı**. Sepet hafta içine göre +%25, hafta sonuna göre +%14. Bu bir "özel gün davranışı" — hediyelik / oyuncak / çok satan kitap kategorileri patladı muhtemelen.

**→ 1 May Cuma Emek Bayramı için aynı pattern beklenir.** Aksiyon: hediyelik + premium kategori stok takviyesi, vitrin önde, mağaza açık + personel.

---

## 4) FSM Düşük Sepet Sorunu — Anatomi

Geçen Pazartesi briefing'inde FSM sepet 533 ₺ ile en düşüktü (Özlüce 686, İst.Yolu 633). Sayıcı kanıtları:

| Hipotez | Sayıcı kanıtı | Sonuç |
|---|---|---|
| Trafik az | 14.187 giriş/hafta (~2.000/gün) | ❌ RED — trafik bol |
| Dönüşüm düşük | %51,2 (sektör %30-40) | ❌ RED — dönüşüm yüksek |
| Personel zayıf cross-sell | Ürün/giren 1,84 | ⚠️ OLASI |
| Düşük fiyat ürün ağırlıkta | Sepet 533, ürün/fiş 3,5 → birim ürün ~152 ₺ | ✅ GÜÇLÜ |
| Demografik (öğrenci/genç) | 23 Nis sepet 629 — özel günde fark, normal günde rutinde kalıyor | ✅ GÜÇLÜ |

**Sonuç:** Pazarlama kampanyası değil → **ürün kompozisyonu yeniden konumlandırma + cross-sell odaklı kasiyer eğitimi**. B-08 (kategori mapping) ile bağlantılı — kategori bazlı sepet kırılımı çıkarılmalı.

---

## 5) Aksiyonlar (5 madde)

1. **1 May Cuma Emek Bayramı:** 23 Nis pattern uygula. Beklenti: 2.500-2.700 giriş, sepet 600+ ₺, ciro 800K-1M.
2. **FSM ürün karışım analizi:** B-08 mapping kurulup kategori bazlı sepet kırılımı (düşük-fiyat kategori payı ölçümü).
3. **Cross-sell potansiyeli:** ürün/giren 1,84 (23 Nis 2,15) — kasiyer cross-sell scripti, checkout impulse.
4. **Cumartesi zirvesi koruma:** 2.585 ort. giriş — kaynak analizi (öğrenci/aile/kampanya), kaybedilirse haftalık ciro %20+ etkilenir.
5. **Sayıcı entegrasyonu (Tier 3):** Bu rapor manuel veri ile. Yarın `plans/02-trafik-analiz.md` ile sistematize.

---

## 6) Veri Uyarıları

- **29-30 Nis future timestamps:** Sayıcıda 29 Nis 1.855 ve 30 Nis 8 giriş — bugün 28 Nis, bu kayıtlar gelmemiş olmalı. Cihaz saat senkronu kontrol gerekli.
- **30 Nis = 8 giriş anomalisi:** muhtemelen cihaz reset / gün başlangıcı.
- **Ziyaret Oranı kolonu boş:** Sayıcı raporunda 0 — "unique visitor" hesabı yok, vendor'a sorulacak.
- **Sadece FSM:** Özlüce + İst.Yolu sayıcı yok henüz — karşılaştırmalı analiz için 3 mağazada kurulum (Tier 3 plan).
- **Saat bazlı kırılım yok:** Sadece günlük toplam — cihazda saatlik veri varsa çıkarılmalı (peak saat / kuşak analizi kritik).
- **Personel/iç giriş:** Sayıcı çalışanları da sayıyor olabilir — açılış öncesi/kapanış sonrası kayıtlar düzeltilirse daha temiz.

---

**Tier 2 hızlı çıktı · 28 Nis 2026** · Sistematize plan: `plans/02-trafik-analiz.md` (yarın)
