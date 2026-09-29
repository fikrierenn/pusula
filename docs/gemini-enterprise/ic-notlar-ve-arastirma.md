# İÇ NOTLAR — Gemini Enterprise girişimi (dışa GİTMEZ; ölçüm taslağı + web araştırması, 24.09.2026)

> Google tarafının "veri büyüklüğü · yapı · süreç · işleyiş" talebine cevap taslağı.
> Hazırlayan: Fikri Eren (GMY) · 24.09.2026 · Ölçüm sorguları: `sorgular/2026-09-24-veri-envanteri-olcum.sql`
> Her rakam ÖLÇÜLDÜ (24.09.2026, canlı). ÇIKARIM olanlar etiketli.
> ⚠ İç sürüm. Dışa giden kopyada **§9 maskeleme** uygulanır (IP / sunucu adı / kimlik / tutar yok).

---

## 1. Şirket ve kapsam

BKM Kitap: kitap + kırtasiye + oyuncak perakendesi (3 mağaza, Bursa), e-ticaret (bkmkitap.com + mobil), Sınav Okulları kurumsal kanalı, merkez depo (WMS). Çalışan ~200 saha + merkez.

Üç kanal: **Mağaza POS** · **E-ticaret** · **Sınav Okulları (B2B, sezonluk Tem–Eki)**. Sezon cironun büyük kısmını taşır.

## 2. Sistem haritası

| Sistem | Rol | Teknoloji | Boyut | Ana varlıklar | Güncelleme |
|---|---|---|---|---|---|
| **DerinSIS (ERP)** | Stok, satış defteri, fatura, muhasebe, cari, fiyat | SQL Server 2019, on-prem | **784 GB** — analitik çekirdek ~50 GB; kalanı API log 177 GB + e-fatura arşivi ~230 GB (§3) | ürün 840K · taraf (müşteri/tedarikçi/mağaza) 50,8K · stok hareketi 59,4M · fatura satırı 41M · muhasebe fişi 39,6M | Anlık (işlemsel) |
| **EncoreMerkez (POS)** | Kasa fişi, satır, kampanya, müşteri kartı | SQL Server, compat 110 (2012 sözdizimi) | 14,5 GB | fiş 1,38M · satır 6,5M · ürün 873K (Tem 2025'ten) | Kasa → ERP **saatte bir** |
| **INTER_BOS (eski kasa)** | 2014 – Tem 2025 POS arşivi | SQL Server | 81 GB | belge 6,4M · satır 39,1M | Donmuş |
| **JOKER (e-ticaret)** | Sipariş, müşteri, katalog | SQL Server, ayrı sunucu, linked server | ölçülmedi (ayrı sunucu) | sipariş 1,25–1,38M/yıl | Anlık; ERP'ye entegre |
| **WMS (`depo` şeması)** | Merkez depo: adres, palet, iş emri, operatör | ERP içinde şema | ERP içinde | iş emri detayı 5,3M · palet hareketi 1,4M | Anlık |
| **Sınav (`BKM.snv`)** | Okul, öğrenci, dönem, sipariş | SQL Server | — | sezonluk | Sezonda anlık |
| **BKMDATA / BKMMaliyet** | Hedef, FIFO maliyet, rapor yardımcı | SQL Server | 71 GB + 11 GB | — | Günlük/aylık job |
| **Zirve (İK/bordro)** | Bordro, kadro, SGK | SQL Server 2008, ayrı sunucu | 206 MB | bordro kişi-ay | Aylık |
| **PDKS** | Personel giriş/çıkış | SQL Express, ayrı sunucu | küçük | kart basma olayı | Anlık |
| **DerinCrm** | Sadakat kartı müşteri master | SQL Server | 8,6 GB | müşteri | Anlık |

Toplam SQL Server ayak izi ≈ **1,1 TB** ham. **Analitik değeri olan çekirdek ≈ 100–150 GB** (ÇIKARIM: log + blob arşivi düşüldü).

## 3. Hacim ve büyüme (ölçülmüş)

**ERP stok hareketi (`irsHrk`):**

| Yıl | Satır | Farklı ürün |
|---|--:|--:|
| 2022 | 20,1M | 315K |
| 2023 | 9,8M | 291K |
| 2024 | 9,3M | 287K |
| 2025 | 4,3M | 400K |
| 2026 (Eyl'e kadar) | 3,1M | 192K |

(2022 yüksekliği yorumlanmadı — göç/toplu kayıt olabilir, ÇIKARIM.)

**POS fiş (EncoreMerkez):** 2025 (Tem–Ara) 541K · 2026 YTD 839K. Kartlı tekil müşteri 2026: 252K.
**E-ticaret sipariş:** 2023 1,38M · 2024 1,25M · 2025 1,27M · 2026 YTD 852K.
**Eski kasa:** 2014–2025 arası 6,4M belge / 39M satır — **11 yıllık perakende tarihi** ML eğitimi için mevcut.

**En büyük tablolar (ERP):**

| Tablo | Satır | GB | Not |
|---|--:|--:|---|
| `ent.api_log` | 5,55 **milyar** | 177 | Entegrasyon logu — aktarılmaz |
| `earsv.efatArsv` + `eftr.efat` + `sil.efatArsv` | 26M | 228 | e-Fatura XML/PDF blob — aktarılmaz |
| `bkm.OneriSiparis` | 230M | 31 | Öneri sipariş çıktısı (kendi hesabımız) |
| `dbo.fytOzl` | 158M | 20 | Fiyat tarihçesi |
| `dbo.irsAyr` | 68M | 10,5 | İrsaliye satırı |
| `dbo.irsHrk` | 59M | 4,9 | **Stok hareket defteri — ML çekirdeği** |
| `dbo.fatAyr` | 41M | 7,7 | Fatura satırı |
| `mhs.mhsFis` | 39,6M | 4,1 | Muhasebe fişi |

## 4. Veri yapısı — hazır semantik katman

`sema/` altında **10.202 satır makine-okunur YAML**:
- `entities.yaml` — tablo, PK, tane (grain), ölçülmüş notlar
- `bridges.yaml` — sistemler arası anahtar köprüleri (ERP ↔ POS ↔ e-tic ↔ İK), güven puanı + kanıt sorgusu
- `codes.yaml` — kod sözlükleri, canlı kullanım sayılarıyla (belge tipi, hareket tipi, KDV kodu…)
- `metrics.yaml` — metrik tanımları (net ciro, iade işareti, kanal ayracı)
- `queries.yaml` + `sorgular/` (138 arşiv sorgusu) — tekrar koşulabilir ölçümler
- `degismezler.json` — koşulan şema değişmezleri (CI kapısı)

BigQuery'de **data dictionary / semantic model**, Gemini için **grounding bağlamı** olarak doğrudan kullanılabilir. Bu katman çoğu şirkette yoktur; 5 aydır ölçerek yazıldı.

**Ana anahtarlar:** ürün `stkID` (POS `Products.Code`, e-tic `J_ITEMS.DERINSIS_ID` ile köprü) · mekan `mekanID` · taraf `frmID` · belge `Sales.Id` / `irs.eID`.
**Grain:** POS fiş-satır · ERP hareket · ürün×mekan×gün özet (`posOzetUrun`) · e-tic sipariş-satır · bordro kişi-ay · WMS palet-hareket.

## 5. Süreç ve işleyiş (veri akışı)

1. **Mağaza satışı:** kasa (Encore) → saatte bir ERP defterine. Gün içinde ERP eksik, kasa doğru. Kapalı günde ikisi kuruşuna tutar (ölçüldü).
2. **E-ticaret:** JOKER sipariş → ERP irsaliye/fatura; stok ODAK fulfillment deposundan.
3. **Sınav Okulları:** okul sipariş listesi → toplu fatura (`DocumentsTypeId=8`) → İst.Yolu'ndan teslim. Tem–Eki yoğun.
4. **Merkez depo (WMS):** mal kabul → raflama → toplama → mağaza sevk; palet/adres düzeyinde. ERP defteri ile **senkron sorunu** var (merkez depo stoğu WMS'ten okunur).
5. **Muhasebe:** aylık kapanış; kapanış-sonrası müdahale denetimi kendi SP'lerle.
6. **İK:** Zirve aylık bordro; PDKS anlık; vardiya eksik/fazla hesabı kendi tabloları (dev).
7. **Analitik katman (mevcut):** salt-okuma; app-owned `bkm.*` ön-agrega tabloları (aylık stok bakiye, bulunurluk, satış analizi) SQL job / uygulama ile dolar. Panel Blazor + Dapper; ölçüm aracı `sqlcli`; doğal-dil sorgu Claude Code + MCP.

## 6. Bilinen veri kalitesi durumları (dürüst liste)

- ERP ↔ WMS merkez depo defteri senkron değil (ERP negatif bakiye 4,2M adet; WMS doğru kaynak).
- **Sıfır sentinel:** FK-benzeri kolonlarda "yok" = `0`, NULL değil. Join'de `> 0` şart.
- Kod sözlükleri sistemler arası farklı (`irsHrk.ehTip=10` yerel alım, `fat.eTip=10` iade fark faturası).
- Eski kasa satır tipi süzgeci (`SAT`/`IPT`) olmadan adet %38 şişer; yeni kasada karşılığı yok.
- Collation Turkish_CI_AS / CP1254 varchar — Unicode dışa aktarımda dönüşüm gerekir.
- EncoreMerkez compat 110 — modern T-SQL yok.
- KDV kodu ≠ oran; 11 kod, tarihsel değişim.
- Sadakat müşteri master ayrı DB (DerinCrm); iç mağaza kartları gerçek müşteri değil.
- İK view tanımları okunamıyor (izin); yalnız veri.

## 7. Aday kullanım alanları (ML / BigQuery / Gemini)

| Alan | Veri hazır mı | Bugün | Beklenti |
|---|---|---|---|
| **Talep tahmini + sipariş önerisi** (ürün×mağaza×hafta) | Evet — 11 yıl perakende, 3 yıl e-tic | Kural tabanlı `OneriSiparis` + YoY/MoM | BQML ARIMA_PLUS / Vertex Forecast; okul takvimi dış değişken |
| **Bulunurluk (OSA) / kayıp satış** | Evet — pre-agg var | Kural tabanlı; sansürlü talep alt sınır | Sansürlü talep modeli |
| **Sezon kadro planlama** | Evet — bordro FTE + saatlik POS | Manuel norm vs gerçek | Saat×mağaza yoğunluk → vardiya |
| **Ölü stok / fiyat elastikiyeti** | Evet — fiyat tarihçesi 158M | Eşik bazlı | — |
| **Müşteri segmentasyonu (RFM, churn)** | Kısmi — kartlı 252K, fiş bazlı | RFM panel | KVKK: kart-ID ile, kimlik yok |
| **Doğal dilde soru → SQL** (yönetici) | **Evet — sema/ grounding hazır** | Claude Code + MCP | Gemini Enterprise agent + BigQuery |
| **Kurumsal bilgi arama (RAG)** | Evet — 40 plan, 138 sorgu, kurallar | Claude Code | Gemini Enterprise Search |
| **Muhasebe anomali** (Benford, kapanış-sonrası) | Evet — 39M fiş | Kendi SP'ler | — |

## 8. Entegrasyon kısıtları ve Google'a sorular

**Kısıtlar (bizim taraf):**
- Tüm veri **on-prem SQL Server**, bulut yok. Gelen bağlantı için VPN/Interconnect gerekir.
- **ERP'ye yazma yasak** (politika). Aktarım salt-okuma: CDC / okuma replikası / gece toplu.
- 4 ayrı sunucu (ERP, e-tic, İK, PDKS), linked server ile bağlı.
- e-Fatura blob + API log aktarılmaz (≈400 GB elenir).

**Sorular:**
1. SQL Server on-prem → BigQuery önerilen yol: Datastream (CDC) mi, toplu Dataflow mu? SQL 2019 + compat 110 DB destekli mi?
2. Veri yerleşimi: TR bölgesi yok; hangi EU bölgesi, KVKK yurt dışı aktarım için hangi belge?
3. Gemini Enterprise: kurumsal veri **model eğitiminde kullanılmaz** garantisi — sözleşme maddesi.
4. Grounding: mevcut YAML semantik katmanı doğrudan bağlam olur mu, Looker/Dataplex'e çevrilir mi?
5. Fiyat: depolama ~150 GB + günlük ~50–100 MB artış (ÇIKARIM); Gemini koltuk ~10 yönetici + 200 saha?
6. Türkçe: CP1254 → UTF-8 dönüşümü connector'da mı? Türkçe embedding/arama kalitesi?
7. PoC: **tek kullanım alanı** öneriyoruz — talep tahmini veya doğal-dil-SQL — 6–8 hafta.

*(§8'in Google tarafı cevapları ve yapı araştırması: bkz. §11 — araştırma tamamlanınca eklenir.)*

## 9. Paylaşma / paylaşmama (KVKK + güvenlik)

**Paylaş:**
- Sistem haritası, boyut, satır sayısı, büyüme, yenilenme sıklığı
- Şema özeti: tablo + kolon + tip + grain (`sema/entities.yaml` süzülmüş export)
- Köprüler ve kod sözlükleri (`bridges.yaml`, `codes.yaml`)
- Süreç akışı, bilinen kalite sorunları
- Kullanım alanı öncelikleri

**Paylaşma (ilk aşamada):**
- Sunucu adı, IP, port, kullanıcı, bağlantı dizesi, `.env`
- Satır verisi: müşteri ad/telefon/kart no, personel ad/TC/maaş, tedarikçi anlaşma fiyatı
- Gerçek ciro/marj tutarları (NDA öncesi) — bu belgedeki tutarları çıkar veya yuvarla
- Öğrenci/okul verisi (`snv` — çocuk verisi, KVKK özel nitelik riski)

**Örnek veri gerekirse:** maskelenmiş ≤1.000 satır; `stkID`/`mekanID` gerçek, kişi alanları hash. NDA öncesi hiç.

## 10. Paket içeriği (Google'a giden)

1. Bu belgenin dış sürümü (§9 maskeli) — PDF
2. `sema/entities.yaml` + `bridges.yaml` + `codes.yaml` — süzülmüş
3. Sistem-akış diyagramı (1 sayfa) — §5
4. Kullanım alanı öncelik listesi + PoC önerisi — §7 / §8.7
5. Soru listesi — §8

## 11. Google tarafı — yapı ve süreç (web araştırması, 24.09.2026)

_Kaynaklar: Google Cloud dokümanları + üçüncü parti (fiyatlar üçüncü parti, satış kotasyonu şart). "Bulunamadı" yazılanlar tahmin edilmedi._

### 11.1 Gemini Enterprise nedir
- Eski **Agentspace**; Ekim 2025'te yeniden adlandırıldı. Bileşenler: **Agents** (hazır + no-code Agent Designer + Gallery), **Data Stores** (Workspace, Google Search), **Connectors** (Drive, SharePoint, ServiceNow, Salesforce, Confluence, Jira GA), NotebookLM Enterprise.
- **BigQuery connector var** (şema otomatik/elle, periyodik senkron; "federe" ya da "ingested"). Cloud SQL verisi önce Cloud Storage'a staged edilir.
- **On-prem SQL Server'a doğrudan connector BULUNAMADI.** ⇒ Veri önce **BigQuery'ye** taşınır, Gemini oradan okur. Bu, mimarinin temel varsayımı.
- **Fiyat (üçüncü parti liste, 2026):** Business ~$21/koltuk/ay (25 GiB havuz depolama) · Standard/Plus ~$30/koltuk/ay'dan; 12 ay taahhüt ~%20 fark. Resmi liste yayınlanmıyor → **kotasyon iste**.
- **Veri yerleşimi:** `us` / `eu` multi-region + Kanada, Hindistan, Japonya, Singapur, UK. **Türkiye YOK.** EU'da bazı özellikler kısıtlı (Agent Runtime code execution, bazı modeller). Business Edition bu listede değil.
- **Eğitimde kullanılmama:** Workspace DPA kapsamında müşteri verisi eğitimde kullanılmıyor; Gemini Enterprise'a özel açık sözleşme cümlesi **doğrulanamadı** → sözleşmede madde olarak iste (§8.3).

### 11.2 SQL Server → BigQuery yolları
| Yol | Tür | Bizim durum |
|---|---|---|
| **Datastream for SQL Server** | CDC, gerçek-zamana yakın | ERP SQL 2019 Standard ✓ (2016 SP1+ şart). **PDKS SQL Express desteklenmez.** Windows AD auth yok → SQL login gerekir. CDC yöntemi: Change Tables (düşük yük) ya da Transaction Log (yüksek throughput, log kesme riski). SQL_VARIANT/GEOGRAPHY desteklenmez. 500M+ satır tabloda unique indeks şart (`api_log` zaten dışarıda). Ağ: IP allowlist / **Forward SSH tunnel** / Private Service Connect — VPN şart değil. |
| **Dataflow "SQL Server to BigQuery" şablonu** | Batch (JDBC) | Her sürümle çalışır; tek seferlik yükleme + gece toplu için uygun. Büyük tablo parçalı okuma. |
| BigQuery Data Transfer Service | SaaS/bulut DW kaynakları | On-prem SQL Server connector **bulunamadı** |
| Database Migration Service | Operasyonel DB → Cloud SQL | Analitik için birincil değil |

**Öneri (ÇIKARIM):** ilk yük Dataflow JDBC (tarihsel 11 yıl), sonra `irsHrk`/`Sales`/`SalesProducts`/`J_ORDERS` için Datastream CDC. PDKS ve Zirve (SQL 2008) batch.

### 11.3 BigQuery yapı ve maliyet
- dataset → table → **partition** (tarih) → **clustering** (`stkID`, `ehMekan`). Bizim veri için doğal.
- **On-demand $6,25/TB taranan** (ilk 1 TB/ay ücretsiz). Editions slot-bazlı: Standard $0,04 / Enterprise $0,06 slot-saat (min 100 slot ≈ $4.380/ay) → bizim hacimde **on-demand çok daha ucuz**.
- Depolama $0,01–0,04/GB-ay. **150 GB ≈ $3/ay**; günlük 100 MB artış ihmal. Sorgu: hafif kullanımda **$10–50/ay**, partition'sız tam tarama raporlamada $100+. (Üçüncü parti kaynak; resmi hesaplayıcıyla teyit.)
- **Forecast:** `ML.FORECAST` + `ARIMA_PLUS` / `ARIMA_PLUS_XREG` (dış değişken: okul takvimi, kampanya) · 2026 yeni: `AI.FORECAST` + gömülü **TimesFM** (model kurmadan). Vertex AI Pipelines ile toplu tahmin.
- **Gemini in BigQuery:** Data Canvas, NL→SQL, BigQuery DataFrames.

### 11.4 Semantik katman / grounding — `sema/` nereye oturur
- **Knowledge Catalog** (eski Dataplex Universal Catalog, Nisan 2026 yeniden ad): tablo/kolon açıklaması, PII işareti, kalite skoru, glossary, lineage; Looker LookML içe alır.
- **Conversational Analytics API:** "data agent" = özel tablo/kolon metadata + yorumlama talimatı + **verified queries**. Bizim `metrics.yaml` (net ciro formülü, iade işareti) ve `queries.yaml` (138 doğrulanmış sorgu) **birebir bu alana** karşılık gelir.
- **YAML doğrudan import BULUNAMADI.** ⇒ `sema/*.yaml` → script ile BigQuery table/column `description` + Knowledge Catalog glossary + agent context'e yazılır (ÇIKARIM; küçük iş — YAML zaten yapısal).

### 11.5 Google discovery / PoC süreci — bizden ne isterler
- **BigQuery Migration Assessment:** mevcut DW taranır → depolama maliyeti, iş yükü optimizasyonu, süre/efor planı. Bizim §2–3 bunun girdisi.
- **Kullanım senaryosu anketi:** amaç, iş değeri, veri tazeliği, eşzamanlı kullanıcı, bağımlı tablo/şema. §7 tablosu bunu cevaplar.
- **PoC seçimi:** en sık / en ağır sorgular + etkilenen tablolar. Bizde: satış analizi tabanı (274.933 ürün, CTE 5 s → pre-agg 15 ms) tipik örnek.
- **Migration Service:** assessment + SQL çeviri + DTS + Data Validation Tool tek çatı.
- Resmi "security questionnaire" şablonu **bulunamadı**; satış/partner kendi belgesini kullanıyor → bizim §9 onun cevabı.

### 11.6 KVKK / uyum (2026)
- **7499 sonrası:** yurt dışı aktarımda asıl yol **Standart Sözleşme** (Kurul metni, değiştirilemez) + **5 iş günü içinde** KVKK bildirim modülüne bildirim. 2026 bildirim ihlali cezası **1.806.177 TL**; Kurul denetim odağı bulut/AI/SaaS.
- Google veri fiziksel olarak yurt dışında → KVKK m.9 "aktarım". Google DPA + SCC var; **Türkiye'ye özel Google Cloud KVKK belgesi bulunamadı** → Standart Sözleşme bizim tarafımızca ayrıca yapılır. Hukuk müşaviri devrede olmalı.
- ISO 27001 (GCP + Workspace) ve **ISO 27701** (PIMS, PII işlemcisi) sertifikalı; Compliance Reports Manager'dan rapor istenir.
- Pratik sonuç: **kişisel veri BigQuery'ye gitmez** (müşteri ad/tel/kart, personel, öğrenci). Ürün×mekan×gün satış, stok, fiyat — kişisel veri değil, aktarım riski düşük. Müşteri analizi gerekirse hash'li kart-ID.

### 11.7 Bu araştırmadan çıkan düzeltmeler (§8 sorularına)
1. Soru 1 cevabı büyük ölçüde belli: **Datastream CDC (ERP/POS) + Dataflow batch (tarihsel, Zirve, PDKS)**. Google'a "onaylıyor musunuz" diye sor.
2. Soru 2: TR bölgesi yok teyit; **`eu` multi-region** iste, EU kısıtlı özellik listesini sor.
3. Soru 4: YAML doğrudan alınmıyor; **Conversational Analytics API agent context + Knowledge Catalog** yolu — Google'dan örnek iste.
4. Yeni soru: **Gemini Enterprise koltuk tipi** — 200 saha personeli için "Frontline" kademesi var mı, fiyatı?
5. Yeni soru: Datastream için ERP'de **CDC/Change Tracking açılması** gerekir — bu ERP satıcısı (Derin) onayı ister; yazma politikamıza takılmaz (sistem düzeyi ayar) ama **DBA onayı** şart.
