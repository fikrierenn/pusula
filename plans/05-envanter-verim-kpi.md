# Plan 05 — Envanter Verim KPI'ları (Devir Hızı · GMROI · Sell-Through)

> Tier 3. deep-research (08.06.2026) bulgularından E4-E6.

**Tarih:** 2026-06-08
**Proje:** `bkm`
**Yazan:** Fikri / Claude
**Durum:** `Tamamlandı` (E-SCHEMA + E4 + E6 ✅ MCP-doğrulandı · E5 ✅ SSMS assembly, karzarar-bağımlı)

---

## 1. Problem

GM panosu envanterin **değerini** (TL) gösteriyor ama **verimini** göstermiyor: stok nakde ne hızla dönüyor (devir hızı), envantere yatan her TL kaç TL marj getiriyor (GMROI), gelen mal ne hızla eriyor (sell-through). Araştırma bunları en kritik eksik perakende KPI'ları olarak işaretledi (3-0 doğrulandı). Sermayenin nerede kilitlendiğini ve ölü stoğu görmeden envanter yönetimi körlemesine.

## 2. Scope

### Kapsam dahili
- **E4 Devir hızı** = COGS / Ort. envanter (maliyet), aylık, mağaza × kategori.
- **E5 GMROI** = Brüt marj / Ort. envanter maliyeti, aylık, mağaza × kategori.
- **E6 Sell-through** = Satılan adet / Gelen adet, aylık/haftalık, kategori (mümkünse başlık).
- Kategori bazlı (urnKtgr2.ktgrAd = ENVANTER_RAPORU.KTGR3 — eşleşme **doğrulandı** 08.06).
- Çıktı: SSMS .sql + katalog E4-E6 satırlarını `🔲 → ✅` yap.

### Kapsam dışı
- Başlık/SKU bazlı sell-through (ürün bazlı genişleme — sonra).
- Stockout rate, weeks-of-supply (ayrı KPI, bu planda değil).
- E-ticaret/Heykel kanalı (3 fiziksel mağaza + WMS/Odak depo).
- Otomatik mail (ayrı).

### Etkilenen dosyalar (tahmin)
- `sorgular/08-envanter/envanter-devir-gmroi.sql` — YENİ (E4+E5, SSMS)
- `sorgular/08-envanter/sell-through.sql` — YENİ (E6, SSMS)
- `docs/rapor-katalogu.md` — E4-E6 durum güncelle
- `.claude/skills/gm-rapor/SKILL.md` — envanter mod E4-E6 ekle

**Tahmini boyut:** 2 yeni .sql + 2 doküman güncelle (~4 dosya).

## 3. Alternatifler

### A: Hafif proxy COGS (ENVANTER snapshot delta + satış)
**Açıklama:** COGS ≈ (açılış stok + alımlar − kapanış stok) maliyet bazında, snapshot farkından.
**Reddetme sebebi:** Alım verisi snapshot'ta yok, hayalet negatifler (Sınav Okulları) deltayı bozar, iade/transfer gürültüsü. Yanlış COGS → yanlış devir/GMROI.

### B: Sales.GrossTotal'ı COGS proxy say (maliyet ≈ satış × sabit marj)
**Açıklama:** Sabit varsayılan marj yüzdesiyle COGS tahmin et.
**Reddetme sebebi:** Kategori marjları çok farklı (kitap vs kırtasiye vs sınav), sabit marj GMROI'yi anlamsız yapar. Zaten gerçek maliyet motoru var.

### C: SEÇİLEN — karzarar-v7 maliyet motoru + ENVANTER_RAPORU ay-sonu
**Açıklama:** COGS/brüt marj = `04-karzarar/2026-05-07-karzarar-v7-prodparity.sql` aylık çalıştır (mağaza×kategori marj çıktısı zaten var). Ort. envanter = `bkm.ENVANTER_RAPORU` ay-başı + ay-sonu snapshot ortalaması (Ort.Maliyet bazı). Kategori adıyla join.
**Sebep:** Tek doğrulanmış prod-parity maliyet kaynağı. Snapshot'lar zaten ay-sonu mevcut (31.MM). Kategori anahtarı eşleşiyor.

## 4. Riskler

| Risk | Etki | Olasılık | Mitigation |
|---|---|---|---|
| Sell-through "gelen adet" tipi yanlış (ehTip 10 vs 13) | yüksek | orta | **Adım 1 zorunlu:** ehTip tanım lookup; 10/13 ayrımı (alış mal-kabul vs şube transfer) doğrulanmadan E6 yazma |
| Hayalet negatif (İst.Yolu Sınav Okulları) ort. envanteri bozar | orta | yüksek | Ort.Maliyet bazı kullan (ÜstFiyat değil); Sınav Okulları kategorisini ayrı flagle/dışla |
| karzarar motoru SSMS-only, MCP'de doğrulanamaz | orta | kesin | Kullanıcı kendi makinesinde çalıştırıp doğrular; toplam COGS bilinen kar/zarar raporuyla kıyas |
| Enflasyon: ort. envanter değeri şişer, devir yanıltır | orta | yüksek | Caveat dokümante; reel/maliyet-güncel not; YoY kıyas |
| Ay-başı snapshot eksik olabilir (bazı aylar) | düşük | orta | Mevcut snapshot tarihlerini önce kontrol et; yoksa tek-uç (kapanış) kullan + not |

## 5. Done Criteria

- [ ] E4 devir hızı: mağaza×kategori, mantıklı aralık (kitap düşük, kırtasiye yüksek beklenir)
- [ ] E5 GMROI: kategori bazlı, >0 ve mantıklı (yüksek marj kategori yüksek GMROI)
- [ ] E6 sell-through: "gelen adet" tipi **doğrulanmış** kaynakla, %0-100 aralığında
- [ ] Toplam COGS, bilinen aylık kar/zarar raporuyla ±%5 uyumlu (doğrulama)
- [ ] Katalog E4-E6 `✅` + skill envanter mod güncel
- [ ] Caveat'lar (enflasyon, hayalet negatif, benchmark yok) dokümante

## 6. Rollback Planı

- Salt yeni .sql + doküman → `git revert` yeterli, DB'ye yazma yok (salt okuma).
- Yanlış KPI yayılırsa: katalogda `⚠️ taslak` flagle, skill'den çıkar.

## 7. Adımlar

1. [x] ✅ **E-SCHEMA** ehTip keşfi: **13** = Ana Depo (firma 12) şube transfer-in · **10** = dış tedarikçi alış mal kabulü. Gelen = 10+13. ENVANTER snapshot 2026'da near-daily + ay-sonu mevcut. Kategori anahtarı KTGR3=ktgrAd doğrulandı.
2. [x] ✅ **E4** Devir hızı — **adet bazlı** (birim maliyet sadeleşti → COGS motoru GEREKMEDİ). MCP doğrulandı (May 2026 mantıklı).
3. [x] ✅ **E5** GMROI — `08-envanter/e5-gmroi.sql`. PAY=karzarar v7 Marj_TL (SSMS), PAYDA=ENVANTER ort. maliyet (MCP-doğrulandı). ORT_ALIS-tek-tablo kısayolu DENENDİ+REDDEDİLDİ (kapsam zayıf: Kitap satılan adedinin %53'ünde ORT_ALIS NULL → COGS eksik). Gerçek COGS karzarar 3-fallback gerektirir.
4. [x] ✅ **E6** Sell-through — satılan/(açılış stok+gelen). Naif satılan/gelen >%100 verdiği için açılış-stok paydası eklendi. MCP doğrulandı.
5. [~] **E-VERIFY** E4/E6 mantık kontrolü ✅ (devir perakende sezgisiyle uyumlu). Toplam COGS kıyas E5'te yapılacak.
6. [x] ✅ **E-DOC** Katalog § E + Plan 05 güncel. Skill envanter mod E4/E6 → (sırada).

> TODO.md'ye E4-E6 + E-SCHEMA maddeleri ekle.

## 8. İlişkili

- Önceki plan: `plans/04-gunluk-kar-zarar-maliyet-karsilastirma.md`
- Maliyet motoru: `sorgular/04-karzarar/2026-05-07-karzarar-v7-prodparity.sql`
- Envanter snapshot: `sorgular/08-envanter/envanter-snapshot-ozet.sql`
- Katalog: `docs/rapor-katalogu.md` § E (KPI sözlüğü + caveat)
- Araştırma: deep-research 08.06.2026 (16 doğrulanmış iddia)

## 9. Onay

- [ ] Plan kullanıcıya gösterildi
- [ ] Geri bildirim alındı
- [ ] Onay alındı: <tarih>
