# Plan 34 — Satınalma Hesap-Sorma Derinleşmesi (ratchet · fiyat sapması · karşı-metrik · atıf)

**Tarih:** 2026-08-18
**Proje:** `bkm`
**Yazan:** Claude (satinalma-danisman denetimi + 2026-08-18 keşifleri)
**Durum:** `Taslak`

---

## 1. Problem

Alım Analizi (`/satinalma/analiz`) bugün **ürün teşhis aracı**: "bu SKU'da fazla alım var" diyor. Hesap sorma için üç şey eksik: (a) **kim** karar verdi — alıcı boyutu sayfada yok, (b) **sistematiklik** — sayfa tek-ay snapshot, "üst üste kaç ay fazla aldı" görünmüyor (Serve Deep ratchet vakasını elle bulduk), (c) **karşı-metrik** — yalnız FAZLA/ÖLÜ cezalandırılıyor, stockout görünmüyor; bu alıcıyı "az al" davranışına iter (`AZ ALMIŞ` şu an yeşil).

Ayrıca **adalet boşluğu**: "fazla aldı" iddiası, tedarikçinin iade hakkı bilinmeden kurulamaz — iade edilebilir stok donmuş sermaye değildir.

## 2. Scope

### Kapsam dahili

1. **Ratchet (sistematiklik) kolonu** — son 6 ayda tekrar eden alım + sipariş trendi (artan/azalan) + stok trendi. Tek geçişte proxy; model 6 kez koşturulMAZ.
2. **Fiyat sapması sekmesi** — aynı stkID, farklı tedarikçi/tarih birim-fiyat farkı (kanıt: HP kalemi Budak 226,11 ₺ vs Promarka 233,10 ₺).
3. **Stockout karşı-metriği** — `bkm.BulunurlukKayip` / `BulunurlukOzet`'ten kayıp-adet rozeti; `AZ ALMIŞ` rengi yeşil → nötr.
4. **Atıf boyutu (kişi + reyon)** — `bkm.OneriSiparisTalep.EkleyenKullanici` / `OnaylayanKullanici`; whitelist + hesap birleştirme + aktif-gün normalizasyonu (§4 riskler).
5. **İade koşulu PARAMETRE** — `frm.frmIadeKural` 0/1/2 kod anlamı bilinmiyor → Ayarlar'a "iade-hakkı sayılan kural kodları" çoklu-seçim; FAZLA / bağlı-para bu bayrağa göre **koşullu** işaretlenir. Kod anlamı öğrenilince yalnız veri girişi yeterli, kod değişmez.

### Kapsam dışı

- Gerçekleşen marj (BKMMaliyet/FIFO entegrasyonu) → ayrı plan.
- Vade/ödeme koşulunun gerçek maliyete etkisi (`frmVade*`) → ayrı plan.
- Rol geçmişi tablosu (rol başlangıç/bitiş) → İK verisi yok; bu planda **unvan etiketi hiç kullanılmaz** (§4).
- Yeni sayfa/servis (footprint-ladder: mevcut sayfa + sorgu genişletilir).
- EncoreMerkez receipt-level bulk tespiti (B-140).

### Etkilenen dosyalar (tahmin)

- `dashboard/Data/SatinalmaQueries.cs` — ratchet + atıf + iade bayrağı; `#ay` / `#agg` genişler
- `dashboard/Data/SatinalmaQueries.FiyatSapma.cs` — YENİ partial (yeni rapor = yeni metod + SQL dosyası kuralı)
- `dashboard/Models/SatinalmaModels.cs` — yeni alanlar + `FiyatSapmaRow`
- `dashboard/Components/Pages/SatinalmaAnaliz.razor` — ratchet kolonu, fiyat sekmesi, stockout rozeti, AZ ALMIŞ rengi
- `dashboard/Data/AyarService.cs` + `Components/Pages/Esikler.razor` — iade kural kodları + alıcı whitelist
- `sorgular/2026-08-12-satinalma-hesap-DINAMIK.sql` + `scripts/satinalma_hesap_sorma.py` — **3 emitter senkronu** (emitter-ayrimi kuralı)
- `TODO.md` — B-142..B-148

**Tahmini boyut:** 8-9 dosya / ~600 satır.

## 3. Alternatifler

### A: Ayrı "Alıcı Performans" sayfası

**Açıklama:** Yeni sayfa, alıcı bazlı scorecard (isabet, fazla-oranı, stockout).
**Reddetme sebebi:** footprint-ladder 6. basamak (en pahalı) — mevcut sayfaya kolon/sekme eklemek aynı bilgiyi veriyor. Ayrıca atıf henüz oran-bazlı ve kısıtlı (FSM'de isimli hesap yok); ayrı sayfa "tam scorecard" beklentisi yaratır, veri onu taşımıyor.

### B: Ratchet'i modeli 6 kez koşturarak hesapla (gerçek geçmiş FAZLA etiketi)

**Açıklama:** Her ay için modeli çalıştır, "kaç ay üst üste FAZLA" say.
**Reddetme sebebi:** 6× maliyet (sayfa şu an tek geçişte ~2-3s); ayrıca geçmiş aylarda eşikler farklıydı (Ayarlar'dan değişiyor) → geriye dönük etiket tutarsız olur. Proxy (tekrar-alım + trend) yeterli sinyal veriyor.

### C: İade kuralı öğrenilene kadar erteleme

**Açıklama:** `frmIadeKural` anlamı muhasebeden gelene kadar planı yazma.
**Reddetme sebebi:** Kullanıcı kararı (2026-08-18): parametre bırak, planı şimdi yaz. Bayrak parametrik olduğu için öğrenme anı **veri girişine** düşer, kod değişmez.

### D — SEÇİLEN: Mevcut sayfayı genişlet + iade koşulunu parametre yap

**Açıklama:** Kapsam §2. Tek çekirdek, üç emitter senkron; atıf oran-bazlı; iade bayrağı Ayarlar'dan.
**Sebep:** En dar basamak, adalet kurallarını kod düzeyinde zorlar, eksik bilgi (iade kodu) planı bloklamaz.

## 4. Riskler

| Risk | Etki | Olasılık | Mitigation |
|---|---|---|---|
| **Haksız atıf** — mutlak talep/adet ile alıcı kıyası | yüksek | orta | Kod düzeyinde yasak: atıf metrikleri yalnız ORAN + aktif-güne normalize. Şube-arası kişi kıyası UI'da kapalı (İst.Yolu %70 benimseme, FSM'de isimli hesap yok). |
| **Rol etiketi yanlış** — roller değişti (omerfaruk akademi şefi → md yrd) | orta | **yüksek** (kanıtlı) | Unvan etiketi HİÇ kullanılmaz; atıf = kişi + şube + kategori + karar tarihi. |
| **Aynı kişi iki hesap** (eren.boran / eren.boran2) | orta | orta | Whitelist'te birleştirme eşlemesi (Ayarlar'da hesap→kişi). |
| **Test/IT hesabı atıfa karışır** (hakan.cetin, kubra.kulaksizoglu) | orta | orta | Whitelist ZORUNLU filtre; hardcode değil Ayarlar'da (IcKartFiltre deseni). |
| **Pencere kirliliği** — 2025-02 öncesi güvenilmez (kanal kırılması + talep ısınma + 2024-08/09/10 boşluk) | yüksek | yüksek | Atıf pencereleri **≥ 01.02.2025** sabit; UI'da pencere görünür yazılır. |
| **3 emitter çatallanır** (dashboard / DINAMIK / Python sapar) | yüksek | orta | Aynı sürümde üçü güncellenir + B-136 mutabakat koşusu done-criteria. |
| **Perf** — ratchet/fiyat sorguları sayfayı yavaşlatır | orta | orta | Ratchet tek geçiş; fiyat sapması AYRI sekme (tıklanınca yüklenir). Korelasyonlu alt-sorgu YASAK (24,9s dersi). |
| **Ters teşvik dengelenmezse** az-alım davranışı | yüksek | orta | Stockout karşı-metriği aynı sürümde; `AZ ALMIŞ` yeşil → nötr. Ratchet tek başına yayınlanMAZ. |

## 5. Done Criteria

- [ ] Ratchet kolonu: son 6 ay tekrar-alım + trend; Serve Deep kümesi (stkID 1701937-1701944) **otomatik** işaretleniyor (elle bulmaya gerek yok).
- [ ] Fiyat sapması sekmesi: aynı stkID farklı tedarikçi/tarih birim-fiyat farkı; HP kaleminde Budak↔Promarka %3 farkı görünüyor.
- [ ] Stockout rozeti: `BulunurlukKayip`'tan kayıp-adet; `AZ ALMIŞ` rengi nötr.
- [ ] Atıf: talep eden + onaylayan; whitelist filtresi aktif (hakan/kubra hariç), eren hesapları birleşik, metrikler aktif-güne normalize, **mutlak sayı UI'da yok**.
- [ ] İade bayrağı: Ayarlar'dan girilen kural kodları FAZLA / bağlı-para işaretini koşullandırıyor; boş bırakılırsa mevcut davranış (regresyon yok).
- [ ] Pencere ≥ 01.02.2025 tüm atıf sorgularında; UI'da yazılı.
- [ ] **3 emitter mutabakat**: dashboard = DINAMIK (SSMS) = Python (openpyxl) — Temmuz 2026 için satır/rakam birebir (B-136 kapanır).
- [ ] Build yeşil + canlı smoke (5112) + `veri-dogrula` QA geçti.
- [ ] Keşif SQL arşiv + sema güncel (ikiz yükümlülük).

## 6. Rollback Planı

- `git revert <commit>` temiz — salt-okuma sorgu + UI; şema değişikliği YOK, ERP yazması YOK.
- Ayarlar parametreleri (iade kodları, whitelist) app-owned `bkm.*` tabloda; boş bırakılırsa kod eski davranışa döner (feature-flag etkisi).
- Emitter senkronu bozulursa: Python/DINAMIK eski sürüm git'ten geri alınır, dashboard tek başına çalışır (mutabakat farkı loglanır).

## 7. Adımlar / TODO maddeleri

1. [ ] **B-142** Ayarlar altyapısı: iade kural kodları (çoklu seçim) + alıcı whitelist (hesap → kişi/şube/kategori, hariç bayrağı) + hesap birleştirme eşlemesi.
2. [ ] **B-143** Ratchet kolonu (çekirdek + UI) — tek geçiş proxy; Serve Deep doğrulaması.
3. [ ] **B-144** Stockout karşı-metriği + `AZ ALMIŞ` renk nötrleme (**B-143 ile AYNI sürümde** — ters teşvik).
4. [ ] **B-145** Fiyat sapması sekmesi (`SatinalmaQueries.FiyatSapma.cs`, tıklanınca yüklenir).
5. [ ] **B-146** Atıf kolonu/sekmesi — oran-bazlı, aktif-güne normalize, unvan etiketi yok, pencere ≥ 01.02.2025.
6. [ ] **B-147** 3 emitter senkronu + B-136 mutabakat koşusu (dashboard / DINAMIK / Python birebir).
7. [ ] **B-148** `veri-dogrula` QA + sema/arşiv güncelleme + journal notu.

## 8. İlişkili

- Önceki plan: `plans/32-satinalma-dashboard.md`, `plans/33-sube-bulunurluk-takibi.md`
- Denetim kaynağı: `satinalma-danisman` skill (2026-08-18 oturumu)
- Keşifler: `sorgular/2026-08-18-alici-boyutu-ve-iade-kurali-kesif.sql` (10 blok) · `sorgular/2026-08-18-gl-kanal-kirilmasi-subat2025.sql` (9 blok) · `sorgular/2026-08-17-serve-deep-alim-kumesi.sql`
- Sema: `bkm.OneriSiparisTalep` (rol haritası · whitelist · normalizasyon · rol zaman-bağımlılığı · adalet uyarısı) · `frm_iade_vade_kosullari` · `mhs.mhsFis_granulerlik_kirilmasi` (pencere)
- Kurallar: `.claude/rules/emitter-ayrimi.md` · `footprint-ladder.md` · `erp-write-policy.md` (salt-okuma)
- TODO: B-136 (mutabakat), B-139 (model zaafı — kanal DEĞİL), B-141 (GL kanal normalizasyonu)
- Açık soru: `frmIadeKural` 0/1/2 anlamı (muhasebe) — planı bloklamaz, parametre.

## 9. Onay

- [x] Plan kullanıcıya gösterildi (2026-08-18)
- [ ] Geri bildirim alındı
- [ ] Onay alındı: `<tarih>`
