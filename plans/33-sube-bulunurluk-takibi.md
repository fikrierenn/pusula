# Plan 33 — Şube Bazlı Bulunurluk (On-Shelf Availability) Takibi

**Tarih:** 2026-08-14
**Proje:** `bkm`
**Yazan:** Fikri / Claude (oturum ID: `3660fe26`)
**Durum:** `Onaylandı` (2026-08-14 · Faz 0 + B-133 ✅ · B-133b DENSE script kullanıcıda · B-134+ kodlanıyor)

---

## 1. Problem

BKM'de **şube bazlı raf bulunurluğu (On-Shelf Availability / OSA) takip edilmiyor.** Bir SKU bir mağazada stoksuz kaldığında o satış sessizce kaybolur — hiçbir rapor "bu üründe bu şubede talep vardı ama stok yoktu" demiyor. Bu iki zarar veriyor:

1. **Kayıp satış görünmez** — kuru raf = kaçan ciro, kimse ölçmüyor.
2. **Satınalma modeli yanılıyor** — düşük satış "talep yok" sanılıp forecast tabanı düşük çıkıyor; gerçekte stok yokluğundan bastırılmış.

**Kanıt (591060 Faber-Castell Grip Min):** Okul'25 sezonunda 3 mağazadan 2'si (Özlüce + İst.Yolu) TÜM sezon kuruydu; sadece FSM stokluydu. Model gy_sezon=71 gördü ama bu tek şubenin satışı — gerçek talep (stok-gate'li geçmişle) ~272. Şube-bulunurluk izlense bu otomatik yakalanırdı.

**Sistemik — Faz 0 ölçtü + DOĞRULANDI (2026-08-14, `sorgular/2026-08-14-bulunurluk-sizing.sql`):** Kat3 (10/12/16) son 12 ay **satan 42.744 SKU**. Carry-in düzeltilmiş dağılım (hareketsiz-stok şubeleri doğru sayılınca): 3-şube-stoklu **18.783 (%44)**; **kısmi (1-2 şube) 15.802 (%37)**; 0-şube 8.159 (online/churn). Kaba kayıp-satış (kısmi SKU'lar tam dağıtılsa, üst-sınır) **~263.336 adet** — hâlâ görünür satış (242K) mertebesinde. Sorun sistemik, **yüz binlerce adet**.

**Tablo semantiği KOD-DOĞRULANDI (`sorgular/2026-08-12-stok-ay-bakiye-mekan-tablo.sql`):** `StokAyBakiyeMekanBazli.Stok` = ay-SONU **kümülatif bakiye** (`ehAltDepo=0`, negatif→0), hareket-toplamı değil (591060 birebir teyit). İki tuzak motorda çözülür: (a) satırlar **sadece hareketli aylara** yazılır → **carry-forward şart** (`Donem<=@ay ORDER BY Donem DESC`); (b) **ay-sonu** bakiye → availability = **giriş-bakiyesi (M-1 ay-sonu)** (son-gün-gelen şişmesini önler). Depo (mekan 12) geçmişi YOK (sadece anlık WMS) → tarihsel bulunurluk **şube-only**.

## 2. Scope

### Kapsam dahili
- **(YENİ — kullanıcı önerisi 2026-08-14, KİLİTLENDİ) Tablo YOĞUNLAŞTIRMA (bounded explicit-0 monthly fact):** `StokAyBakiyeMekanBazli` üretim scriptini (`2026-08-12-stok-ay-bakiye-mekan-tablo.sql`) değiştir — **her ay satır yaz (0 dahil)**, hareketsiz ay önceki bakiyeyi taşır, kuru ay `Stok=0` yazılır. SINIR: sadece TAŞINAN (sku,mekan) çiftleri × son ~24-36 ay, ilk-taşıma→son-aktif span (discontinued SKU 0-spam yapmaz). Eski aylar sparse kalır. **Boyut: ~2,56M→~13,3M (son24ay) + eski sparse ≈ 12-15M toplam (~2×)** — ölçüldü, patlamıyor. Etki: carry-forward + carry-in ROW_NUMBER TÜM tüketiciden kalkar; availability = direkt `Stok≥eşik`, **OOS = direkt COUNT**. GERİYE UYUMLU (`Donem<=@ay` yine çalışır). ⚠ Regen sonrası satınalma modeli (stoklu_ay) RE-VALIDATE (birebir tutmalı).
- **Bulunurluk motoru** — yoğunlaştırılmış `StokAyBakiyeMekanBazli` × `irsHrk` satış çaprazı. Availability = o ay satır `Stok≥eşik` (carry-forward gereksiz). Emitter-ayrımı: tek çekirdek → dashboard + (opsiyonel) Excel.
- **Metrikler:** (a) şube×kategori **OOS oranı** (aktif SKU'ların % kaçı rafta <min-stok), (b) **kayıp-satış tahmini** (kuru şube + başka şubede kanıtlı talep → kaçan adet/₺, stok-gate'li), (c) **öncelik listesi** (yüksek-devir × OOS = en çok kaçıran → transfer/sipariş).
- **Gerçek-gap ayrımı (Faz 0 dersi — KRİTİK):** Ham %38 kısmi-dağıtım ÜST-SINIR; hepsi kayıp değil. Gerçek gap için 3 filtre: (1) **geçmişte-taşımış** — şube o SKU'ya daha önce raf açmış mı (yoksa kasıtlı-assortment, gap değil); (2) **mağaza-boyut normalizasyon** — eksik-şube büyük mağaza hızında değil, kendi ölçeğinde tahminlenir; (3) **online-kanal (mekan 12) ayrı** — raf-stoğu tutmaz, "kuru şube" sayılmaz.
- **Satınalma entegrasyonu:** bulunurluk-düzeltilmiş sezon tabanı (imputation'ın DOĞRU hali — stok-gate'li, online-kanal ayrımlı) → satınalma detayına "tahmini tam-dağıtım tabanı" olarak AYRI gösterim.
- **Faz 0 sizing probe** — kurmadan önce sorun boyutunu MCP ile ölç.

### Kapsam dışı
- Gerçek-zamanlı OOS alarmı / WMS canlı entegrasyonu (persisted ay-bakiye yeterli; canlı ayrı iş).
- Otomatik transfer/sipariş tetikleme (öneri listesi verir, aksiyon insanda — erp-write-policy).
- Bulunurluk-düzeltilmiş tabanın FAZLA kararını OTOMATİK değiştirmesi (accountability riski — bkz. Risk).
- Kafe/e-ticaret bulunurluğu (mekan 12 online kanalı özel-ele-alınır ama şube-raf modeli 1/4477/4478 odaklı).

### Etkilenen dosyalar (tahmin)
- `sorgular/2026-08-14-bulunurluk-sizing.sql` (YENİ) — Faz 0 probe, arşiv.
- `sema/metrics.yaml` + `sema/entities.yaml` — OSA/OOS/kayıp-satış metrik + StokAyBakiyeMekanBazli grain tanımı.
- `dashboard/Data/BulunurlukQueries.cs` (YENİ) — çekirdek sorgular.
- `dashboard/Models/BulunurlukModels.cs` (YENİ).
- `dashboard/Components/Pages/Bulunurluk.razor` (YENİ) — `/bulunurluk` VEYA Envanter/Operasyon içine bölüm.
- `dashboard/Models/NavRegistry.cs` — nav satırı (yeni sayfaysa).
- `dashboard/Data/SatinalmaQueries.UrunDetay.cs` + `SatinalmaUrunDetay.razor` — bulunurluk-düzeltilmiş taban gösterimi (GetSubeSezonAsync genişler).
- `scripts/bulunurluk_rapor.py` (opsiyonel) — Excel emitter.

**Tahmini boyut:** 6-9 dosya / ~600-900 satır (Faz'lara bölünür).

## 3. Alternatifler

### A: Satınalma modeline gömülü imputation (inline)
**Açıklama:** Kuru-şube tahminini doğrudan gy_sezon'a katıp FAZLA kararını düzelt.
**Reddetme sebebi:** (1) Accountability riski — taban şişirme overbuy'ı GİZLER (aracın asıl amacı overbuy yakalamak). (2) Bulunurluk verisi tek-ürün forecast'inden çok daha değerli (kayıp-satış, transfer önceliği) — dar kalır. (3) footprint-ladder: bulunurluk kendi başına bir yetenek, satınalma alt-detayı değil.

### B: Gerçek-zamanlı OSA alarm sistemi (canlı WMS + push)
**Açıklama:** Canlı stok akışından anlık OOS tespiti + bildirim.
**Reddetme sebebi:** Aşırı mühendislik (tek-kullanıcı analitik araç). Persisted ay-bakiye zaten var; ay-granülaritesi karar için yeterli. Canlı entegrasyon + alarm ayrı, sonra.

### C: SEÇİLEN — Analitik bulunurluk raporu/sayfası (persisted veri) + satınalmaya AYRI besleme
**Açıklama:** Mevcut `StokAyBakiyeMekanBazli` × `irsHrk` üstünde tek çekirdek → OOS oranı + kayıp-satış + öncelik. Satınalma detayına "tahmini tam-dağıtım tabanı" AYRI sayı olarak (karar gerçek gy_sezon'da kalır). Faz 0 sizing ile boyutlandırılır.
**Sebep:** Veri temeli hazır (yeni tablo yok), accountability korunur (şişirme kararı otomatik değiştirmez), yeniden-kullanılır değer (envanter+satınalma+operasyon besler), emitter-ayrımına uyar.

## 4. Riskler

| Risk | Etki | Olasılık | Mitigation |
|---|---|---|---|
| İmputation tabanı şişirir → gerçek overbuy gizlenir (accountability) | yüksek | orta | Düzeltilmiş taban SADECE ayrı gösterim; FAZLA kararı ham gy_sezon'da kalır. Otomatik yön-değiştirme YOK. |
| Kısmi-dağıtım ≠ kayıp-satış (kasıtlı assortment: niş SKU her mağazada olmaz) | yüksek | yüksek | "Geçmişte-taşımış" gate — şube daha önce raf açmadıysa gap sayma. %38 üst-sınır; gerçek-gap bunun altında. Kayıp-satış "tahmini + üst-sınır" etiketiyle sunulur, kesin ₺ iddiası YOK. |
| Mağaza-boyut farkı → eksik-şube büyük-mağaza hızıyla şişer | orta | yüksek | Şube-başı hızı kendi tarihsel ölçeğinden al (düz 1/N değil); veri yoksa kategori-şube ortalaması. |
| mekan 12 (online/merkez) raf-stoğu tutmuyor ama satıyor (Okul'24=216) | orta | kesin | Online kanalı "kuru şube" sayma; ayrı ele al (stok-gate uygulanmaz, ham satış). |
| Şube-stok rotasyonu (FSM 0→0→71, Özlüce 65→270→0) → tahmin gürültülü | orta | yüksek | Çapraz-şube oranı KULLANMA; her şube KENDİ stoklu-sezon medyanı. Geniş aralık = düşük-güven etiketi. |
| SKU×şube×ay matrisi ağır (850K ürün) | orta | orta | Kat3ID 10/12/16 + aktif-SKU filtresi; set-based GROUP BY; cache (satınalma 20dk deseni). |
| StokAyBakiyeMekanBazli recon bayat/eksik (hareketsiz ay satır yazmıyor) | orta | orta | Son-değer taşıma (stoklu_ay deseni zaten böyle okuyor); Faz 0 kapsama kontrolü. |
| min-stok eşiği (bulunurluk=raf≥3) yanlış kalibre | düşük | orta | Parametrik (Rapor Parametreleri sayfası — SatinMinStok zaten var, paylaş). |

## 5. Done Criteria

- [x] **Faz 0:** ✅ 2026-08-14 — sizing probe (`sorgular/2026-08-14-bulunurluk-sizing.sql`): 42.744 aktif SKU, %38 kısmi-dağıtım, ~377K kaba kayıp-adet. Sorun sistemik doğrulandı, scope buna göre inceltildi (gerçek-gap 3 filtre).
- [ ] Bulunurluk çekirdeği: şube×kategori OOS oranı doğru (MCP ile mutabakat, ≥1 örnek elle doğrulanmış).
- [ ] Kayıp-satış tahmini stok-gate'li (kuru sezon referansa girmez) + online-kanal ayrımlı — 591060'ta ~272 tabanı üretiyor (elle doğrulanan vaka).
- [ ] Dashboard sayfası/bölümü: OOS + kayıp-satış + öncelik listesi, DaisyUI token (renk-standardi), Türkçe (turkish-ui).
- [ ] Satınalma detayı: "tahmini tam-dağıtım tabanı" AYRI gösteriliyor; FAZLA kararı ham tabanda KALIYOR (accountability testi geçti).
- [ ] Test: davranış-kontrat (bulunurluk 0-100 arası, kayıp-satış≥0, OOS-oranı = kuru-SKU/aktif-SKU) — snapshot değil.
- [ ] sema: OSA/kayıp-satış metrikleri + kullanılan SQL `sorgular/`'a arşiv (ikiz yükümlülük).

## 6. Rollback Planı

- Yeni sayfa/servis → `git revert <commit>`; nav satırı tek yerden (NavRegistry) çıkar.
- Satınalma detayına eklenen gösterim ayrı commit → izole revert (çekirdek satınalma modeli bozulmaz).
- DB yazma YOK (salt-okuma, erp-write-policy) → migration/down-script gerekmez.

## 7. Adımlar / İçerdiği TODO maddeleri

1. [x] **B-132** ✅ 2026-08-14 Faz 0 — sizing probe (`sorgular/2026-08-14-bulunurluk-sizing.sql`) çalıştı + arşivlendi; Problem rakamlandı (%38 kısmi, ~377K kayıp), scope inceltildi (gerçek-gap 3 filtre).
2. [x] **B-133** ✅ 2026-08-14 sema — `entities.yaml` StokAyBakiyeMekanBazli (semantik+tuzaklar, conf 1.0) + `metrics.yaml` bulunurluk_osa (formül+sizing+accountability).
2b. [ ] **B-133b** (ÖNCE — B-134 buna dayanır) Tablo yoğunlaştırma: üretim scriptini bounded explicit-0 monthly fact'e çevir (taşınan çift × son 24-36 ay, 0 dahil, ilk-taşıma→son-aktif span). Regen + satınalma stoklu_ay RE-VALIDATE (birebir). ⚠ Production bkm.* regen — kullanıcı onayıyla.
3. [ ] **B-134** `BulunurlukQueries.cs` + `BulunurlukModels.cs` çekirdek — yoğunlaştırılmış tablodan şube×kategori OOS (direkt COUNT) + kayıp-satış (stok-gate'li, online-kanal ayrımlı) + öncelik. Prototip doğrulandı (FSM %30,6/İst.Yolu %32,6/Özlüce %27,2).
4. [ ] **B-135** `Bulunurluk.razor` sayfa/bölüm + NavRegistry — OOS panosu + kayıp-satış + öncelik listesi (DaisyUI, Türkçe).
5. [ ] **B-136** Satınalma detay entegrasyonu — GetSubeSezonAsync → bulunurluk-düzeltilmiş "tahmini tam-dağıtım tabanı" AYRI gösterim (karar ham tabanda kalır).
6. [ ] **B-137** Test (davranış-kontrat) + veri-dogrula skill + sizing/keşif SQL arşiv (ikiz yükümlülük).
7. [ ] **B-138** (opsiyonel) `bulunurluk_rapor.py` Excel emitter — CFO dökümü.

> Sıra: B-132 (sizing) SONUCU B-133+'ı şekillendirir — problem küçükse scope daralır. B-132 onay-kapısı.

## 8. İlişkili

- Kaynak vaka: 591060 Faber-Castell (bu oturum, `docs/journal/bkm/2026-08-14.md`).
- Önceki plan: `plans/32-satinalma-dashboard.md` (satınalma modeli — bu onun türevi).
- Kural: `.claude/rules/erp-write-policy.md` (salt-okuma), `.claude/rules/emitter-ayrimi.md` (tek çekirdek), `.claude/rules/renk-standardi.md`, `.claude/rules/footprint-ladder.md`.
- Veri: `bkm.StokAyBakiyeMekanBazli` (şube×ay stok), `dbo.irsHrk` (satış), mekan 1=FSM/4477=Özlüce/4478=İst.Yolu/12=online.

## 9. Onay

- [x] Plan kullanıcıya gösterildi
- [x] Geri bildirim alındı (sabit-sezon→carry-in→explicit-0 dense co-design; sizing kod+veri doğrulandı)
- [x] Onay alındı: 2026-08-14 (Fikri). B-133b DENSE script (`sorgular/2026-08-14-stok-ay-bakiye-DENSE.sql`) kullanıcı çalıştıracak (production regen); B-134+ kodlama Claude.
