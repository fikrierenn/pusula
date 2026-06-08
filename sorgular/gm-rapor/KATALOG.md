# Genel Müdür Rapor Kataloğu

> GM gözüyle "her gün" + "her Pazartesi" görmem gereken raporlar. Her satır: amaç (1 cümle) · KPI · kaynak sorgu · durum.
> Kapsam: 3 Bursa fiziksel mağaza (FSM=1, Özlüce=4477, İst.Yolu=4478). Kanonik ciro pattern: `scripts/generate_brief.py` (`SUM(IIF(DocumentsTypeId=3,-1,1)*(GrossTotal-DiscountTotal))`, Pos→Stores→posMagaza, geri dönüşüm BarcodeNo='1001' hariç).

---

## A. HER GÜN (sabah, dün kapanışı)

Amaç: operasyonel nabız. 5 dakikada "dün ne oldu, anormal bir şey var mı".

| # | Rapor | KPI | Kaynak sorgu | Durum |
|---|---|---|---|---|
| **G0** | **Birleşik günlük toplam** (fiziksel + online) | Toplam ciro · kanal payı — GERÇEK günlük resim | `sorgular/gm-rapor/gunluk/G0-birlesik-toplam.sql` | ✅ doğrulandı (online %61) |
| G1 | **Günlük GM panosu** — mağaza kırılımı | Net ciro · Fiş · Sepet ort · UPT · WoW · YoY · MTD hedef gerçekleşme | `sorgular/gm-rapor/gunluk/G1-gm-panosu.sql` | ✅ doğrulandı |
| G2 | Ödeme tipi dağılımı (dün) | Nakit / Kredi / çek % — kasa mutabakat | `sorgular/gm-rapor/gunluk/G2-odeme-mix.sql` | ✅ doğrulandı (nakit ~%17) |
| G3 | İade kontrolü (dün) | İade fiş adedi · iade tutarı · iade oranı % | `sorgular/gm-rapor/gunluk/G3-iade.sql` | ✅ doğrulandı (İst.Yolu %3,5) |
| G4 | Kategori mix (dün, mağaza kırılımlı) | Kategori payı — hangi mağaza nerede zayıf | `sorgular/gm-rapor/gunluk/G4-kategori-magaza.sql` | ✅ doğrulandı (kategori=DerinSIS KTGR3) |
| G5 | Saat bazlı yoğunluk (dün) | Saatlik fiş + net ciro — kasiyer/vardiya planı | `sorgular/gm-rapor/gunluk/G5-saat-bazli.sql` | ✅ doğrulandı (pik 16:00) |
| G6 | Anomali bayrağı (dün) | Sıfır/neg fiyat · kampanyasız (manuel) indirim | `sorgular/gm-rapor/gunluk/G6-anomali.sql` | ✅ doğrulandı (07.06 temiz) |
| G7 | E-ticaret (JOKER) dün | Sipariş · ciro · sepet · kanal (App/Mobil/Web) | `sorgular/gm-rapor/gunluk/G7-eticaret-kanal.sql` | ✅ doğrulandı (ISO tarih) |

**Asgari günlük set:** G1 + G2 + G3. Gerisi sinyal varsa drill-down.

> ⚡ **Kritik içgörü (07.06.2026):** E-ticaret günlük ciro **3,02M ₺** = 3 fiziksel mağaza toplamından (1,93M) **BÜYÜK**. App (Android+iOS) ciro %57,5, sepet 1.208-1.268 ₺ (mağaza ATV 555-677 ₺'nin ~2 katı). GM panosu yalnız fizikseli gösterirse cironun yarısından fazlası görünmüyor. Birleşik (fiziksel+online) günlük toplam KPI gerekli — B-21 ile bağlantılı.

---

## B. HER PAZARTESİ (haftalık kapanış)

Amaç: stratejik review. Otomatik mail zaten gidiyor (`scripts/generate_brief.py`, Task Scheduler Pzt 09:00).

| # | Rapor | KPI | Kaynak | Durum |
|---|---|---|---|---|
| P1 | **Haftalık brief** (otomatik mail) | Net ciro · WoW · fiş · sepet · mağaza + MTD hedef · günlük seyir | `scripts/generate_brief.py` → `briefings/YYYY-MM-DD/brief.html` | ✅ otomatik |
| P2 | Kategori/marka haftalık trend | KİTAP vs DİĞER ara toplam · kategori payı · birim fiyat Δ | `01-ciro/2026-05-08-ciro-magaza-kategori-aratoplamli.sql` (tarih → hafta) | mevcut |
| P3 | Kampanya performansı (hafta) | 3Al2Öde fiş/ürün/indirim · %50 kampanya · kampanyalı fiş payı | `03-kampanya/10_07_3al2ode-detay.sql` · `10_10_sepet-karsilastirmasi.sql` | mevcut |
| P4 | Kâr/zarar — maliyet karşılaştırma (hafta) | Brüt marj · maliyet · net kâr (mağazalı) | `04-karzarar/2026-05-07-karzarar-v7-prodparity.sql` | mevcut |
| P5 | İade analizi (hafta) | İade oranı trend · top iade ürün/sebep | `05-iade/10_14_iade-analizi.sql` | mevcut |
| P6 | Operasyon — kasiyer (hafta) | Kasiyer fiş/ciro · gün sonu mutabakat | `06-operasyon/10_16_kasiyer.sql` · `10_18_gun-sonu.sql` | mevcut |
| P7 | Personel / PDKS (hafta) | Fazla mesai · devamsızlık · vardiya plan vs fiili | `sorgular/pdks/sp_PdksPano.sql` | mevcut |
| P8 | Önümüzdeki hafta | Özel gün · aksiyon önerisi | brief P1 §4 (manuel takvim) | brief'te |

**Brief'te eksik (B-21 backlog):** Heykel, JOKER e-ticaret, kitapsepeti, kafeler haftalık brief'e dahil değil — kapsam genişletme bekliyor.

---

## D. STOK / ENVANTER

Amaç: sermaye nerede kilitli, hayalet kayıt var mı, ne tükeniyor. Kaynak: gece job'u `DerinSISBkm.bkm.ENVANTER_RAPORU` (00:05 dolar) — canlı değil, snapshot.

| # | Rapor | KPI | Kaynak sorgu | Durum |
|---|---|---|---|---|
| E1 | **Envanter snapshot özet** | Mağaza+depo toplam değer · 2 maliyet bazı (ÜstFiyat/Ort.Maliyet) | `sorgular/gm-rapor/envanter/E1-snapshot-ozet.sql` | ✅ YENİ |
| E2 | Hayalet stok filtresi | Sınav Okulları (urnKtgr2ID=19) E1'de DIŞLANDI — İst.Yolu ±sahte değer temizlendi | `sorgular/tum_stoklar_anomali_taramasi.md` + E1 | ✅ filtreli |
| E3 | Anlık/derin envanter (SSMS) | Ürün bazlı stok × maliyet, WMS+Odak dahil | `sorgular/envanter_raporu_job_sorgusu.sql` | mevcut (ağır) |

**Kritik kural:** Sınav Okulları (urnKtgr2ID=19) **envanter dışı** (E1/E4/E6 hepsinde filtreli) — paket-koduyla-giriş/parça-koduyla-çıkış İst.Yolu'nu bozuyordu (ÜstFiyat −190M sahte negatif, Ort.Maliyet +149M sahte pozitif). GM'e **Ort.Maliyet** bazı birincil. Doğrulama (08.06.2026, Sınav hariç): Ort.Maliyet toplam **1,20 milyar TL**, İst.Yolu 70,1M (önce 216,8M görünüyordu).

**Frekans:** E1 günlük bakılabilir (snapshot her gece tazelenir), E2 her gün kontrol, E3 haftalık/aylık derin analiz.

---

## C. AYLIK (ay kapanışı — referans)

| # | Rapor | Kaynak |
|---|---|---|
| A1 | Aylık ciro trend | `01-ciro/10_02_aylik-ciro-trend.sql` |
| A2 | Kampanya aylık trend | `03-kampanya/10_08_kampanya-aylik-trend.sql` |
| A3 | Bordro / headcount / devir hızı | `sorgular/2026-06-03-*.sql` |
| A4 | Envanter anomali | `sorgular/envanter_raporu_job_sorgusu.sql` |
| A5 | **ABC analizi (Pareto 80/20)** ✅ | `sorgular/gm-rapor/merchandising/A5-abc-analizi.sql` — A %25 SKU→%80 ciro · C %40 SKU→%5 (clearance) |
| A6 | **Marka/yayınevi performansı** ✅ | `sorgular/gm-rapor/merchandising/A6-marka-yayinevi.sql` — top yayınevi + ciro/çeşit verimi |

---

## C2. MÜŞTERİ (omnichannel)

| # | Rapor | KPI | Kaynak | Durum |
|---|---|---|---|---|
| C1 | **RFM segmentasyonu** (e-ticaret + yazarkasa) | Recency/Frequency/Monetary → Şampiyon/Sadık/Yeni/Risk/Kayıp | `sorgular/gm-rapor/musteri/C1-rfm-segmentasyon.sql` | ✅ doğrulandı |

İki ayrı müşteri evreni (kimlik köprüsü yok — JOKER CUSTOMERREF ≠ EncoreMerkez CustomersId):
- **E-ticaret** (JOKER): Şampiyon 8.923 (11K ₺, 9,2 sip.) · Kayıp 335.512 (353M = reaktivasyon) · yüksek sepet.
- **Yazarkasa** (sadakat kartı, %50 fiş penetrasyonu, DocType=1): Şampiyon 4.082 (12,6K ₺, **19,9 fiş/yıl** ≈ haftada bir!) · Sadık 21.347 · yüksek frekans.
- Kurumsal/Sınav tek-seferlik dev alımlar yazarkasada DocType=1 ile hariç (Kayıp şişmesini önler).

---

## Boşluk Analizi

- **G1 günlük panosu yeni üretildi** — geri kalan günlük raporlar mevcut sorgulara tarih daraltmasıyla bağlanıyor.
- **Otomasyon:** Sadece P1 (haftalık) otomatik. Günlük panonun (G1) da Task Scheduler ile sabah 08:30 mail'i değerlendirilebilir → ayrı plan (Tier 3).
- **Kapsam:** Hem günlük hem haftalık şu an sadece 3 fiziksel mağaza. E-ticaret + Heykel + kafe entegrasyonu B-21.

---

## E. GENİŞLETME — Araştırma Bulguları (deep-research 08.06.2026)

Kaynak taraması (6 açı, 27 kaynak, 16 doğrulanmış iddia). Perakende KPI best-practice'leri + Türkiye bağlamı. Senin panoda **olmayan** metrikler.

### KPI Sözlüğü (doğrulanmış formüller)

| KPI | Formül | Frekans | Neden | Durum |
|---|---|---|---|---|
| **ATV** (sepet ort) | Net ciro / Fiş | günlük | Çapraz satış / fiyat | ✅ G1'de var |
| **UPT** (sepet adedi) | Net adet / Fiş | günlük | Sepet derinliği; 3al2öde etkisi | ✅ G1'e eklendi |
| **Dönüşüm oranı** | İşlem / Trafik | günlük | Erken uyarı (ciro düşmeden önce) | ⛔ B-22 kapı sayıcı bekliyor |
| **YoY** | dönem / geçen yıl aynı dönem | günlük/haftalık | Mevsimsellik (sınav/okula dönüş) | ⏳ G1'de, ~11.07.2026'da aktif |
| **Stok devir hızı** | Satılan adet / Ort. stok adet ×12 | aylık | Stok→nakit hızı; ölü stok | ✅ E4 `gm-rapor/envanter/E4-E6-devir-sellthrough.sql` |
| **GMROI** | Brüt marj / Ort. stok maliyeti | aylık | Envantere yatan 1 TL'nin marj getirisi | ✅ E5 `gm-rapor/envanter/E5-gmroi.sql` (SSMS, pay=karzarar) |
| **Sell-through** | Satılan adet / (Açılış stok + Gelen adet) | haftalık/aylık | Reorder/clearance kararı | ✅ E6 (aynı dosya) |
| **Weeks of Supply** | Ort. stok / haftalık satış | aylık | Kaç haftalık stok; yüksek=ölü sermaye | ✅ E7 (E4-E6 dosyasında kolon) |
| **RFM** | Recency/Frequency/Monetary | aylık | Müşteri segmenti; reaktivasyon | ✅ C1 (e-ticaret) |
| **Marka/yayınevi** | ciro + ciro/çeşit | aylık | Tedarikçi karnesi | ✅ A6 |
| **Stokta yokluk** | SKU stok≤0 / satışı olan | günlük/aylık | Fiziksel <%5 hedef; kayıp satış | ✅ E8 `gm-rapor/envanter/E8-stockout.sql` |
| **SPLH** | Net ciro / çalışılan saat | aylık | İşgücü verimi (PDKS) | ✅ S1 `gm-rapor/operasyon/S1-splh-isgucu-verimi.sql` |

Kaynaklar: [Umbrex Retail KPI Playbook](https://umbrex.com/resources/retail-industry-playbooks/retail-kpi-dashboard-weekly-business-review-playbook/retail-kpi-architecture-and-metric-definitions/), [ICSC 6 Inventory Metrics](https://www.icsc.com/news-and-views/icsc-exchange/6-inventory-metrics-you-should-track-and-how-to-do-it), [frekansdenetim.com.tr (TR)](https://frekansdenetim.com.tr/perakende-sektoru-performans-metrikleri/), [Slimstock](https://www.slimstock.com/blog/inventory-turnover/).

### 3 Katmanlı Mimari (frekans ≠ tek eksen)
- **Sürücü metrikler** (trafik, dönüşüm, ATV, UPT, sell-through, stockout) → **günlük**, erken uyarı.
- **Sonuç metrikler** (ciro, marj, kâr, GMROI) → haftalık/aylık.
- **Teşhis** (SKU/başlık bazlı, iade sebebi) → drill-down.

### ⚠️ Caveat'lar
1. **Benchmark sayıları güvenilmez** ("devir 6-8x", "GMROI>2,5", "sell-through %70-85" iddiaları doğrulamada ELENDİ). Kendi tarihsel baseline'ını kur, hazır hedef sayısı kullanma.
2. **Türkiye yüksek enflasyon** → TL bazlı marj + ortalama envanter değeri şişer, devir/GMROI yanıltır. Reel/maliyet-güncel bak.
3. **Mevsimsellik** (sınav, Ramazan) → YoY şart, sadece WoW yetmez.
4. **Stockout <%5 fiziksel mağaza için**; e-ticaret %8-12 normal — kanal ayrı hedefle.

### Doğrulanamayan (ileride araştır)
RFM segmentasyon, tekrar alım, CLV, sadakat (müşteri açısı) + yayıncı/tedarikçi karnesi, başlık bazlı iade (merchandising) — doğrulama turunu geçemedi, formül seçimi dikkatli yapılmalı. JOKER `J_ORDER_CLIENTS` müşteri zinciri RFM için başlangıç noktası. **ABC analizi ✅ kuruldu** (A5).

### E4-E6 Durum (Plan 05 — 08.06.2026)
- **E4 Devir + E6 Sell-through ✅ KURULDU + doğrulandı** (`gm-rapor/envanter/E4-E6-devir-sellthrough.sql`). Kilit içgörü: adet-bazlı devirde birim maliyet sadeleşir → **COGS motoru gerekmez**, üstelik enflasyondan etkilenmez. Hareket tipleri: satış 4/100, gelen 10 (alış)+13 (depo transfer), Sınav Okulları hayalet hariç.
- **E5 GMROI ✅ kuruldu** (`gm-rapor/envanter/E5-gmroi.sql`) — pay=karzarar v7 Marj_TL (SSMS, prod-parity COGS), payda=ENVANTER ort. maliyet (MCP-doğrulandı). Tek-tablo ORT_ALIS kısayolu reddedildi (kapsam zayıf, COGS eksik). Pay SSMS-only doğrulanır.
- Doğrulama (May 2026): devir Dergi 8,53x · Kitap 1,46x · Kırtasiye 1,32x; sell-through Gıda %32,5 · Kitap %10,7.
