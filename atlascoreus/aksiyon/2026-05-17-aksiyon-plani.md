# ATLASCOREUS — Aksiyon Planı | 17 Mayıs 2026

**Kaynak rapor:** `atlascoreus/izleme/2026-05-17-etsy-haftalik.md`
**Sprint:** 17–24 Mayıs 2026 (7 gün)
**Father's Day deadline:** 21 Haziran 2026 → 35 gün

---

## Önceliklendirme Mantığı

| Etiket | Anlamı |
|---|---|
| **P0 — BU HAFTA SONU ÖNCESİ** | Father's Day arama penceresi açık; ilk-hareket avantajı dakikalarla ölçülüyor |
| **P1 — BU SPRINT (17–24 Mayıs)** | Yapısal kazanım, hafta sonuna kadar bitmesi gerek |
| **P2 — GELECEK SPRINT (25–31 Mayıs)** | Önemli ama ertelenebilir; Father's Day öncesi bitmeli |
| **P3 — AY İÇİNDE** | İyileştirme, marj koruma, dokümantasyon |
| **TEHIR** | Şimdilik aksiyon gerekmiyor, izleme listesinde tut |

---

## P0 — BU HAFTA SONU ÖNCESİ (17–18 Mayıs, Cumartesi–Pazar)

### A1. Father's Day Top 5 Listing — ChatGPT semantic rewrite
**Neden:** ChatGPT app 5 Mayıs'ta canlı. Father's Day penceresi açık. İlk-hareket avantajı için 30 dk audit + 6 dk per listing rewrite.

**Yap:**
1. Etsy Shop Manager → Listings → "Father's Day" / "Dad" / "Father" tag'i olan ilk 5 listing'i seç. (Sales son 30 günde en yüksek olanlardan.)
2. Her birinin description'ını şu cümle iskeletleriyle yeniden yaz (atlascoreus-marka Section 13 ses tonu + Vintage Naturalist Field Guide hikâyesi):
   - "Thoughtful gift for [persona]" (ör. "dad who loves stargazing")
   - "Made for someone who [intent verb]" (ör. "spends weekends bird-watching")
   - "Perfect for [occasion + niche combo]" (ör. "Father's Day for the naturalist in your life")
3. Title'da bestseller hariç, 70 char altına çek; detayı tag/attribute/description'a kaydır.
4. Humanizer skill'inden geçir; AI klişelerini temizle.

**Ölçüm:** 24–31 Mayıs arası bu 5 listing'in impression + favorite + visit grafiğini Etsy Stats'tan al; baseline (önceki 7 gün) ile karşılaştır.

**Süre:** 1 saat audit + 30 dk rewrite = **1.5 saat**.

**Risk:** Bestseller'a dokunmak (etsy-listing-revize "bestseller dokunma kuralı"). Eğer Top 5 içinde bestseller varsa atla, 6. listing'i al.

---

## P1 — BU SPRINT (17–24 Mayıs)

### A2. Search Visibility Dashboard kontrolü + AI Title aracı denemesi
**Neden:** Etsy yeni AI title recommendations'ı dashboard'a entegre etti, rolling out. Senin mağazana gelmiş olabilir.

**Yap:**
1. Shop Manager → Stats → Search Visibility açıp **"Listings"** sekmesine bak.
2. "Recommended actions" listesinde AI title suggestion görüyor musun? (Mağaza yeterli aktiviteye ulaştıysa görünür.)
3. Görüyorsan: 3 listing seç (Father's Day OLMAYAN), AI önerisini gözden geçir → makulse uygula, değilse reddet.
4. Bulk edit özelliği denemek için: 70 char üstü 10–15 listing seç, AI önerisini toplu uygula. (Bestseller'lar hariç.)

**Ölçüm:** 14 gün sonra mobile CTR (Search Visibility Dashboard) değişimini ölç.

**Süre:** 45 dk.

### A3. Banner + About bölümü brand consistency kontrolü
**Neden:** Etsy 4 Mayıs Seller Handbook makalesinde brand impression vurgusu yaptı. Bu yumuşak ranking sinyali olabilir.

**Yap:**
1. atlascoreus-marka Section 13 ses tonu rehberini aç.
2. Mağaza banner + About bölümünü atlascoreus-marka kriterleriyle eşleştir.
3. Field Guide / Vintage Naturalist hikâyesi About'ta net mi? Comfort Colors premium pozisyonlama görünüyor mu?
4. Eksik kısımları düzelt; humanizer'dan geçir.

**Süre:** 1 saat.

### A4. Review prompting akışını sıkılaştır
**Neden:** Recency-weighted formülü rollout aşamasında. Yeni gelen her 5-yıldız altın değerinde; eski negative review'ların etkisi her yıl yarıya iniyor.

**Yap:**
1. Son 30 günde teslim edilen siparişler listesi → "How was it?" follow-up message şablonu (humanizer'dan geçmiş, Vintage Naturalist ses tonunda) hazırla.
2. Etsy Conversations üzerinden teslim sonrası 7. günde manuel veya 3rd-party araçla otomatik gönder.
3. Paket içi review request kartını gözden geçir; üretici (Podbul) ile koordine ediyorsan brief'i güncelle.

**Süre:** 1.5 saat (şablon + send setup).

---

## P2 — GELECEK SPRINT (25–31 Mayıs)

### A5. Spring/Summer 2026 trend ⇄ Vintage Naturalist mini koleksiyon brief
**Neden:** Etsy trend raporu "outdoor moments + handcrafted textures + meaningful keepsakes" diyor. Father's Day için tematik koleksiyon penceresi.

**Yap:**
1. 3 tema seç: kamp / yıldız gözlemi / bird-watching (Father's Day uyumlu, Vintage Naturalist nişine oturan).
2. atlascoreus-marka + etsy-mockup-spec skill'leriyle her tema için **1 hero design brief** yaz.
3. Podbul'a iletmeden önce Podbul margin matematiğini etsy-fiyatlandirma skill'i ile çalış (Comfort Colors premium pozisyon korunuyor mu kontrol).
4. Trademark ön taraması (etsy-trademark skill) — özellikle "stargazing" / NASA çağrışım kontrolü.

**Süre:** 3 saat (brief + margin + trademark).

### A6. etsy-personalization 5-field setup'ı Father's Day listing'lerine uygula
**Neden:** Personalization tailwind devam ediyor ("made just for them"). 11 Mayıs GA launch'la gelen multi-field sistem hâlâ rakipler tarafından az kullanılıyor.

**Yap:**
1. P0'da rewrite edilen 5 Father's Day listing'inde mevcut personalization field'larını kontrol et.
2. etsy-personalization skill'in 5-field ATLASCOREUS Field Guide formatına göre genişlet (isim, soyad, yıl, eyalet, opsiyonel custom note).
3. 120 char instructions limit + 3+ consecutive ALL CAPS yasağına uy.

**Süre:** 1 saat (5 listing × ~12 dk).

---

## P3 — AY İÇİNDE (1–17 Haziran)

### A7. Skill güncellemeleri
**Neden:** Bu hafta öğrendiklerimiz skill'lere işlenmezse sonraki sefer yine sıfırdan çıkar.

**Yap:** Sırayla güncelle (her biri ~15 dk):
- `etsy-listing` Section 5 → ChatGPT discovery channel
- `etsy-listing-revize` Section 4 → 70 char +34% CTR resmi teyit
- `etsy-analitik` Section 4 + Section 7 → Search Visibility Dashboard AI title + Review formula
- `etsy-fiyatlandirma` EU fee tablosu → France/Hungary güncelleme
- `atlascoreus-marka` Section 13 → ChatGPT discovery channel

**Süre:** 1.5 saat toplam.

### A8. ChatGPT App içinde manuel test
**Neden:** ATLASCOREUS listing'leri ChatGPT semantic search'te ne kadar görünür, sezgi geliştirmek.

**Yap:**
1. ChatGPT'de Etsy app'i aktive et.
2. 5 farklı persona-bazlı prompt dene:
   - "Father's Day gift under $40 for a dad who loves astronomy"
   - "Vintage-style nature gift for someone who hikes every weekend"
   - "Bird-watching gift idea for a retired father"
   - "Field guide aesthetic Father's Day t-shirt"
   - "Moon phases gift for a science teacher dad"
3. ATLASCOREUS listing'leri çıkıyor mu? Çıkmıyorsa hangi mağazalar çıkıyor (rakip kim), title/description'ları nasıl yapılandırılmış?
4. Bulguları `atlascoreus/izleme/2026-06-XX-chatgpt-app-rekabet-haritasi.md` olarak kaydet.

**Süre:** 1 saat.

---

## TEHIR (İzleme listesi)

| Konu | Neden tehir | Re-evaluate ne zaman |
|---|---|---|
| France/Hungary regulatory fee güncellemesi | ATLASCOREUS US-focused, EU sales marjinal | 22 Haziran yürürlük tarihinde |
| UK DMCC Act total price display | Satıcı tarafında setup gerekmiyor | UK siparişi anormal yükselirse |
| Children & Baby Products policy | Niş dışı | Personalization child theme istersen |
| NASA/Disney trademark sweep | Background enforcement, spesifik dalga yok | Yeni listing öncesi her durumda etsy-trademark çalıştır |

---

## Toplam Süre Tahmini

| Faz | Süre |
|---|---|
| P0 (Cumartesi–Pazar) | 1.5 saat |
| P1 (Hafta içi) | 3.25 saat |
| P2 (Gelecek hafta) | 4 saat |
| P3 (Ay içinde) | 2.5 saat |
| **Toplam** | **~11.25 saat / 4 hafta** |

---

## Success Metrics (24 Mayıs review)

- [ ] P0 rewrite edilen 5 Father's Day listing'inin mobile CTR'si +%10 veya üstü
- [ ] Search Visibility Dashboard'da "reduced visibility" uyarısı azalmış
- [ ] Yeni gelen review sayısı haftalık baseline'ın üzerinde
- [ ] Banner + About brand consistency atlascoreus-marka kriterlerine uyumlu
- [ ] ChatGPT'de test prompt'larından en az 2'sinde ATLASCOREUS listing görünüyor

---

## Notlar

- Bu plan otomatik tetiklenen scheduled task'ın çıktısı; Fikri'nin manuel onayı olmadan herhangi bir listing değişikliği yapılmadı.
- Aksiyonlar sıralı; P0 bitmeden P1'e geçilmemeli.
- Her aksiyon sonunda `atlascoreus/aksiyon/2026-05-17-aksiyon-plani.md` dosyasında ilgili maddeye `[done: tarih]` ekle.
