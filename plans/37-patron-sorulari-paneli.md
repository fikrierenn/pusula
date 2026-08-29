# Plan 37 — Patron Soruları Paneli (6 departman × 25 soru + kapanış → tek kapı)

**Tarih:** 2026-08-29
**Proje:** `bkm`
**Yazan:** Fikri / Claude
**Durum:** `Taslak`

---

## 1. Problem

"Patron Soruları — Tüm Departmanlar" çerçevesi 6 departman × 4-5 soru = **25 hesap-sorma sorusu** + 1
kapanış sorusu ("sen olsan ne yapardın?") tanımlıyor
(hedef/gerçekleşen/fark/nakit/sorumlu · satış · satınalma · operasyon · finans · İK-BT-lojistik).

Bugün bu soruların cevabı **dağınık** (29.08 sayfa-başlığı denetimi): **10 ✅ canlı** dashboard sayfasında ·
**8 🟡 parçalı** (bir yönü var, sorunun tamamını cevaplamıyor) · **6 ❌ veri yok** · 1 kapsam dışı. GMY bir soruyu sormak istediğinde hangi sayfaya gideceğini bilmiyor,
ve **cevabı olmayan sorular görünmüyor** — "veri yok" ile "kötü sonuç" ayırt edilemiyor.

İhtiyaç: 25 sorunun tamamını tek ekranda listeleyen, her soruyu ya canlı sayıya ya da doğru sayfaya
bağlayan, cevaplanamayan soruyu **açıkça boşluk olarak işaretleyen** bir kapı sayfası.

## 2. Scope

### Kapsam dahili
- Yeni sayfa `/patron-sorulari` — 6 departman bloğu, soru satırları, durum rozeti, drill linki.
- Soru kayıt defteri (`PatronSorulariRegistry.cs`) — `NavRegistry` deseni: 25 soru tek C# listede
  (departman · soru metni · durum · kaynak sayfa/route · kaynak sorgu dosyası · not).
- **Faz A (bu plan):** statik registry + durum rozeti + drill link. Canlı sayı YOK.
- **Faz B (bu plan):** yalnız hâlihazırda hızlı servisi olan ~8 soruya canlı mini-metrik
  (ör. riskli alacak tutarı `/cari-risk`, ölü stok değeri `/envanter`, hedef gerçekleşme `/tahmin`).
  Kart açılınca (lazy) yüklenir — sayfa açılışında 25 sorgu koşmaz.
- Boşluk sorularında rozet `❌ veri yok` + tek satır gerekçe ("13-hafta nakit projeksiyonu için
  banka/kredi taksit verisi ERP'de yok") + TODO/plan referansı.
- `NavRegistry`'ye tek satır (Section: `ANALİTİK`, en üste yakın).
- **Faz C — kapanış sorusu ("Sen olsan ne yapardın?"):** her departman bloğunun altında buton →
  o bloğun canlı rakamları + rozet durumları `/asistan` (Genius) altyapısına beslenir, LLM "üç aksiyon"
  önerir. Yeni LLM servisi YOK — mevcut `LlmService`/`AsistanService` çağrılır.
  **Genel LLM değil, o departmanın DANIŞMAN rolüyle konuşur** (29.08'de yazılan skill seti):
  satış → `satis-danisman` · satınalma → `satinalma-danisman` · operasyon → `operasyon-danisman` ·
  finans → `finans-nakit-danisman` · İK → `ik-danisman` · BT → `bt-risk-danisman` ·
  **lojistik → `operasyon-danisman`** (ayrı danışman yok: depo→kargo→müşteri tek akış).
  1. departman (hedef/fark/nakit/sorumlu) kesişen blok — ilgili departmanın danışmanına yönlendirilir,
  ayrı danışman açılmaz. Not: 6. departman kutusu (İK+BT+Lojistik) modül şemasında birleşik ama
  **üç ayrı disiplin** — panelde de üç ayrı danışmana bağlanır.
  Danışmanların davranış sözleşmesi (overclaim yasak · confound · perverse-incentive) sistem promptuna
  girer → panel "üç aksiyon" üretirken uydurma iddia riski düşer.

### Soru yorumları (29.08 GMY kararı)
- **"Teklifler satışa neden dönmüyor?" → KAPSAM DIŞI.** BKM perakende; B2B teklif süreci yok.
  Registry'de `kapsam dışı` rozeti (gri) — boşluk sayılmaz, skoru bozmaz. Görünür kalır ki
  "unutuldu mu?" sorusu bir daha doğmasın.
- **"Fire ve yeniden işleme neden arttı?" → tek başlık, 3 alt-kalem:** (a) kayıp-kaçak / sayım farkı
  (shrinkage), (b) iade edilemez / yayınevine dönmeyen stok (`frmIadeKural`, B-150), (c) kafe fire (gıda).
  Üçünün de veri kaynağı **belirsiz** → Faz A'da ❌ + **keşif TODO'su** (DerinSIS sayım/imha hareket tipi
  `ehTip` var mı; kafe zayi kaydı nerede). Keşif bu planın DIŞINDA (Tier-2 keşif işi).

### Kapsam dışı
- **Yeni hesap çekirdeği YAZILMAZ.** Nakit/DSCR/İK/bus-factor hesapları bu planda YOK — ayrı planlar
  (38 nakit bloğu, 39 İK/BT). Bu sayfa onları "boşluk" olarak gösterir, doldurmaz.
- Departman bazlı hedef girişi (bugün hedef yalnız ciro/kategori bazlı) — kapsam dışı.
- Aksiyon atama akışı — mevcut `/gorevler` kullanılır, link verilir; yeni görev modeli yok.
- Fire/kayıp veri keşfi (sayım farkı · imha · kafe zayi) — ayrı Tier-2 iş; bu plan yalnız boşluğu işaretler.
- Genius'un önerdiği aksiyonun otomatik göreve dönüşmesi — Faz C yalnız metin üretir.
- Mobil btm-nav'a ekleme (yer dolu) — sidebar yeterli.

### Etkilenen dosyalar (tahmin)
- `dashboard/Models/PatronSorulariRegistry.cs` — YENİ, 25 soru kaydı (~160 satır, veri).
- `dashboard/Components/Pages/PatronSorulari.razor` — YENİ (~260 satır, Faz A+B+C).
- `dashboard/Data/PatronSorulariQueries.cs` — YENİ, yalnız Faz B mini-metrikleri; **mevcut
  `*Queries` servislerini ÇAĞIRIR**, SQL kopyalamaz (emitter-ayrimi §2).
- `dashboard/Models/NavRegistry.cs` — 1 satır.
- `dashboard/Program.cs` veya `ServiceRegistration.cs` — 1 DI satırı.
- `docs/2026-08-29-patron-sorulari-kapsam.md` — 25 sorunun kapsam matrisi (kalıcı referans).
- `TODO.md` — boşluk sorularının maddeleri.

**Tahmini boyut:** 6 dosya / ~480 satır (yarısı registry verisi).

## 3. Alternatifler

### A: 25 sorunun hepsini canlı hesaplayan tek büyük sayfa
**Açıklama:** Sayfa açılınca 25 metrik paralel sorgulanır, hepsi sayı gösterir.
**Reddetme sebebi:** 25 ağır sorgu = 60+ sn açılış (bulunurluk/FIFO tek başına 15 sn). Ayrıca 6 sorunun
verisi yok — sayfa yarı boş açılır. Perf ve dürüstlük ikisi de kaybeder.

### B: Her departmana ayrı yeni sayfa (Satış Soruları, Finans Soruları…)
**Açıklama:** 6 yeni sayfa.
**Reddetme sebebi:** footprint-ladder ihlali — mevcut `/musteri`, `/cari-risk`, `/satinalma/analiz`
zaten o departmanın sayfası. 6 yeni yüzey = nav şişer, içerik ikizlenir.

### C (SEÇİLEN): Registry-driven tek kapı sayfası, lazy mini-metrik, boşluk açıkça işaretli
**Açıklama:** 25 soru veri olarak tanımlanır; sayfa bu listeyi render eder. Cevabı olan soru mevcut
sayfaya link + (varsa) lazy mini-metrik; cevabı olmayan soru kırmızı "veri yok" + gerekçe.
**Sebep:** Yeni hesap çekirdeği yok (footprint-ladder 1. basamak, emitter-ayrimi uyumlu). Boşluklar
görünür hale gelir → sonraki planların (nakit/İK) gerekçesi ölçülebilir olur. Registry deseni repoda
zaten kanıtlı (`NavRegistry` — B-75 orphan-link kökünü çözdü).

## 4. Riskler

| Risk | Etki | Olasılık | Mitigation |
|---|---|---|---|
| Registry bayatlar (soru "veri yok" derken ekran yapılmış olur) | orta | yüksek | Durum alanı ilgili sayfa eklenince güncellenir; `docs/…-kapsam.md` tek kaynak, plan kapanışında senkron. TODO maddesi registry satırına ID ile bağlanır. |
| "Kapı sayfası" kullanılmaz, GMY doğrudan sidebar'a gider | düşük | orta | Faz B mini-metrikler değer katmazsa Faz A kalır (ucuz). Sayfa değeri = boşluk envanteri, o tek başına yeterli. |
| Lazy metrik yine yavaş (ör. bulunurluk 15 sn) | orta | orta | Faz B'ye YALNIZ <2 sn ölçülmüş servisler alınır; ölçüm plan uygulamasında yapılır, yavaş olan Faz A rozetinde kalır. |
| Mini-metrik ile hedef sayfadaki sayı çelişir | **yüksek** (güven kaybı) | orta | Mini-metrik mevcut `*Queries` metodunu ÇAĞIRIR, SQL kopyalamaz. Kopya SQL yazılırsa plan reddedilir (emitter-ayrimi §2). |

## 5. Done Criteria

- [ ] `/patron-sorulari` açılıyor, 6 departman × 25 soru eksiksiz listeleniyor (sayım testi: 25;
      1'i `kapsam dışı` rozetli).
- [ ] Her ✅/🟡 soru tıklanınca doğru sayfaya gidiyor (orphan link yok — registry route'ları
      `NavRegistry` ile çapraz doğrulanır).
- [ ] Her ❌ soru gerekçe cümlesi + TODO referansı taşıyor; `kapsam dışı` soru gri rozetle ayrı duruyor.
- [ ] Faz C: 6 departman bloğunun her birinde "Sen olsan ne yapardın?" butonu çalışıyor, Genius o bloğun
      rakamlarıyla cevap veriyor (uydurma rakam kontrolü: cevaptaki sayılar ekrandakiyle aynı olmalı).
- [ ] Faz B metrikleri hedef sayfadaki rakamla **birebir** aynı (manuel mutabakat, en az 3 metrik).
- [ ] Sayfa ilk açılış <2 sn (Faz A statik; PerfState ölçümü).
- [ ] Yalnız DaisyUI semantic token — hardcode hex yok (`renk-standardi.md`).
- [ ] `dotnet build` yeşil + preview'da görsel doğrulama (mobil 375px dahil).
- [ ] `docs/2026-08-29-patron-sorulari-kapsam.md` yazıldı; boşluk soruları `TODO.md`'ye düştü.

## 6. Rollback

Tek yeni sayfa + registry. Geri alma: `NavRegistry` satırı sil + 3 yeni dosyayı sil (`git revert`).
Mevcut hiçbir sayfa/servis değişmiyor → cascade riski yok.

## 7. Adımlar

1. **Kapsam matrisi belgesi** — 25 soru × durum × kaynak, kullanıcı onayı (durum atamaları GMY ile teyit).
2. `PatronSorulariRegistry.cs` — matristen türetilir.
3. `PatronSorulari.razor` Faz A (statik render + rozet + drill).
4. Route çapraz doğrulama + build + preview.
5. Faz B — servis süre ölçümü, <2 sn olanlara lazy mini-metrik, mutabakat.
5b. Faz C — departman bloğu → Genius besleme butonu (mevcut `AsistanService`).
6. `TODO.md` boşluk maddeleri (B-1xx) + plan `plans/archive/`.

## 8. Sonraki planlar (bu planın ürettiği boşluklardan)

- **Plan 38 — Nakit bloğu:** 13-hafta nakit projeksiyonu · DSCR · KDV/vergi karşılığı · banka mutabakat.
  (5. departmanın 4 sorusu; en büyük boşluk.)
- **Plan 39 — İK/BT:** pozisyon maliyet-katkı · bus-factor · sistem kesinti riski.
- Küçükler (Tier-2): tedarikçi alternatif matrisi · **fire/kayıp veri keşfi (3 alt-kalem)** ·
  kargo birim maliyet trendi · SKU bazlı kâr · alım vade analizi.
