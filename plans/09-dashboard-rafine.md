# 09 — Dashboard Rafine (5 iş, sırayla)

> Tier 3 · plan-first. Onaysız implement edilmez. Her adım: build + 390px smoke + MCP doğrulama (veri) + commit.
> Kullanıcı isteği (tek tek, performanstan başla): hız · grid oran · E-tic/Magaza üst-KPI carousel · filtre testi · irsHrk kaynak birliği.

---

## Adım 1 — PERFORMANS (paralel sorgu) [B-49]
**Problem:** Sayfa LoadAsync'lerinde sorgular SERİ → yavaş (Eticaret 7 sorgu, Home 4, Operasyon 2).
**Çözüm:** Bağımsız sorguları `Task.WhenAll` ile paralel (her metod kendi connection'ını açıyor → güvenli).
- Home: GetPeriodAsync + GetTrend + GetAlisTrend paralel (hedef koşullu ayrı). ✅ agent taslağı
- Eticaret: 7 sorgu paralel. ⚠ JOKER linked server eşzamanlı 2-3 sorgu — smoke'ta timeout izle, gerekirse JOKER'a gidenleri grupla.
- Operasyon: GetPeriodAsync + GetOpsAsync paralel. ✅ agent taslağı
**Done:** Build yeşil, her sayfa açılış belirgin hızlanır, veri AYNI (smoke karşılaştır). Risk: JOKER eşzamanlılık → izle.
**Rollback:** seri await'e geri (git revert).

## Adım 2 — GRID'LERDE DEĞER + ORAN
**Problem:** Listelerde sadece değer var, oran (%) yok (kategori'de eklendi, diğerlerinde yok).
**Çözüm:** AppRankBars/AppDataTable kullanan yerlerde ValueText'e `· %pay` ekle (toplam-içi pay). Eticaret kanal/il/kargo, Envanter marka, vb.
**Done:** Her ranked liste değer + %pay gösterir. Toplam satırı olan yerlerde tutarlı.

## Adım 3 — E-TİCARET + (MAGAZA✅) ÜST-KPI CAROUSEL
**Problem:** Ana sayfa gibi çok-KPI swipe carousel sadece Home + Magaza'da. E-ticaret düz.
**Çözüm:** Eticaret üstüne gradient hero carousel (Net Ciro · Sipariş · Sepet Ort · İade/İptal) — Home/Magaza KpiCard deseni. Paylaşılan bir `AppKpiCarousel` component'e çıkarmak (Home+Magaza+Eticaret tek kaynak) tercih edilebilir (file-size + tutarlılık).
**Done:** Eticaret üst KPI swipe carousel + dot, masaüstü grid. Responsive.

## Adım 4 — FİLTRE TESTİ (tüm yapı)
**Problem:** Dönem değişimi (Günlük/Haftalık/Aylık/Özel) her sayfada doğru mu — sweep yok.
**Çözüm:** 5 sayfa × 4 dönem (+özel) preview smoke: pill aktif değişiyor mu, _aralik doğru mu, veri reload oluyor mu, drill aynı dönemi kullanıyor mu, hata/taşma var mı. Bulunan kırıkları düzelt.
**Done:** Tüm sayfa×dönem kombinasyonu hatasız + doğru aralık + drill dönem-tutarlı.

## Adım 5 — irsHrk KAYNAK BİRLİĞİ (BÜYÜK, riskli)
**Problem:** Ciro/kategori EncoreMerkez'den, drill/envanter irsHrk'den → ~%15 fark, tutarsız.
**Kullanıcı kararı:** Fiş-sayısı + saat (kasiyer, saat yoğunluk — EncoreMerkez Sales fiş-seviye gerekir) DIŞINDA her yerde **irsHrk** (DerinSIS, ehTip 4/100, stkID).
**Kapsam:** Queries.cs storeSql/katSql/saatSql/kasSql → ciro/kategori irsHrk'ye taşı; fiş-sayısı + kasiyer + saat EncoreMerkez kalır. MagazaQueries kategori/net de irsHrk.
**Risk:** TÜM ciro/kategori rakamları değişir. Her metrik MCP ile ESKİ vs YENİ karşılaştır + kullanıcı onayı (hangi doğru). Mağaza-bazlı: irsHrk `ehMekan` ile.
**Done:** Ciro/kategori tek kaynak (irsHrk), fiş/kasiyer/saat EncoreMerkez; her metrik MCP-doğrulanmış; kategori kartı = drill toplamı (artık tutarlı).
**Bu adım kendi MCP-keşif + onay turunu gerektirir — Adım 1-4 bittikten sonra ayrı ele alınır.**

---

## Sıra / Bağımlılık
1 → 2 → 3 → 4 bağımsız, sırayla. 5 EN SON (en riskli, ayrı doğrulama turu). Her adım ayrı commit.

## Genel Done
5 adım tamam, her sayfa hızlı + tutarlı app dili + tek veri kaynağı (uygun yerde) + filtre her yerde doğru.
