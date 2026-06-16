# Plan-16 — Tüm Ciro KDV-Hariç + Kargo-Hariç Birleştirme

**Tarih:** 16.06.2026
**Tier:** 3 (headline ana ciro değişir, 28 sorgu, belgelenmiş kararı tersine çevirir, MCP mutabakatlı)
**Direktif:** Kullanıcı (CFO) 16.06 — "her şey KDVsiz olmalı, kargo da olmasın". sema `metrics.yaml:tum_ciro_kdv_kargo_haric` (14.06 "ana ciro KDV-dahil DOKUNMA" kararı iptal).

---

## Problem

Dashboard iki ölçek karışık:
- **irsHrk tabanlı** (tahmin motoru, envanter, devir, marka/kategori-stkID) → zaten **KDV-hariç**.
- **EncoreMerkez Sales + JOKER e-ticaret** → **KDV-DAHİL** (e-ticaret ayrıca **kargo-dahil**).

CFO net ciro istiyor (kasanın aldığı perakende-brüt değil). Genel Bakış "Toplam Ciro" KDV-dahil → tahminle (KDV-hariç) aynı ölçekte değil; kafa karıştırıyor.

---

## Kanonik Formül (16.06 canlı doğrulandı)

| Kaynak | Yanlış (mevcut) | Doğru (KDV+kargo-hariç) |
|---|---|---|
| **EncoreMerkez** | `Sales.GrossTotal − DiscountTotal` (başlık, KDV-dahil) | `SUM(SalesProducts.TotalPrice − VatTotal)` per-satır, `IsValid=1` |
| **E-ticaret** | `J_ORDERS.TOTALPRICE` (KDV+kargo) / `QTY×SELLINGPRICE` (KDV-dahil) | `SUM(J_ORDER_DETAILS.QUANTITY × SELLINGPRICEWITHOUTVAT)` |
| **irsHrk** | `ehTutarN` | DEĞİŞMEZ (zaten KDV-hariç) |

Kanıt: `J_ORDER_DETAILS` temiz KDV alanları — `VAT`(oran), `VATPRICE`(KDV), `SELLINGPRICEWITHOUTVAT`(KDV-hariç birim), `SELLINGPRICE`(KDV-dahil). `TOTALPRICE = SUM(QTY×SELLINGPRICE)+CARGOPRICE+SERVICEPRICE` (ORDERID 110015826: 2086,9=1997+89,9). EncoreMerkez `SalesProducts.VatTotal` KDV (sema 14.06).

---

## Kapsam — 28 Sorgu (Explore envanteri 16.06)

### WP-A — EncoreMerkez Sales-başlık → SalesProducts-satır (Net = TotalPrice−VatTotal) — 10 sorgu
Headline + mağaza + operasyon. `GrossTotal−DiscountTotal` → `SalesProducts` join (IsValid=1) + KDV-hariç. İade sign (DocumentsTypeId=3) KORUNUR.
- `Queries.GetPeriodAsync` storeSql (Queries.cs:24) **← HEADLINE ana ciro + mağaza kartı**
- `Queries.GetPeriodAsync` saatSql (138), kasSql (148)
- `Queries.GetHedefAsync` netSql (211)
- `Queries.GetTrendAsync` (277)
- `Queries.GetKasiyerDeltaAsync` (341)
- `MagazaQueries.GetDetayAsync` kpiSql (34), GetTrendAsync (215)
- `RefQueries.GetOpsAsync` splh (366)
- `SadakatQueries` / `RefQueries.GetRfmAsync` yk (aşağıda WP-D)

### WP-B — EncoreMerkez SalesProducts.TotalPrice → −VatTotal — 6 sorgu
Kategori/ABC/hediye çeki (zaten satır-bazlı, sadece −VatTotal ekle).
- `Queries.GetPeriodAsync` skatSql (75), katSql (123)
- `Queries.GetHedefAsync` katNetSql (237)
- `MagazaQueries.GetDetayAsync` katSql (140), kampSql (85)
- `RefQueries.GetInventoryAsync` tAbc (108), `GetHediyeCekiAsync` (422)

### WP-C — E-ticaret TOTALPRICE/SELLINGPRICE → SELLINGPRICEWITHOUTVAT (kargo-hariç) — 8 sorgu
- `Queries.GetPeriodAsync` eticSql (50) **← online ana ciro**, eticKanalSql (107)
- `EticQueries.GetEticKategoriAsync` (236), GetEticKategoriUrunAsync (254), GetEticKategoriYilAsync (275), GetFunnelAsync (302)
- `RefQueries.GetRfmAsync` et (40), GetEtCustomersAsync (212)

### WP-D — Müşteri/RFM/Sadakat EncoreMerkez — 4 sorgu
- `SadakatQueries.GetWinBackAsync` (19), GetParetoAsync (49)
- `RefQueries.GetRfmAsync` yk (26), GetYkCustomersAsync (195)

### Belirsiz/teyit
- `MagazaQueries` odemeSql (64) `SalesPayments.Amount` — ödeme tutarı KDV-dahil (kasanın aldığı); ödeme MİX yüzdesi için kalabilir AMA toplam ciroyla kıyas ediliyorsa KDV-hariç'e çekilemez (ödeme gerçek tahsilat=KDV-dahil). **Karar: ödeme tutarı KDV-DAHİL kalır (gerçek tahsilat), not düşülür** — ciro değil.

---

## Mutabakat Disiplini (B-81 ile aynı)

Her sorgu düzeltmesi: MCP'de eski (KDV-dahil) vs yeni (KDV-hariç) toplam çek → fark ~%5-6 (kitap %0 ağırlıklı aylarda düşük) **beklenen aralıkta mı** doğrula. Sapma absürtse (join çoğaltması, IsValid eksik) dur. Headline storeSql önce + en dikkatli.

---

## Riskler

| Risk | Önlem |
|---|---|
| Sales-başlık → SalesProducts-satır JOIN çoğaltma/eksik | IsValid=1 + hediye-çeki barkod filtresi; MCP fiş-sayısı + toplam mutabakat |
| Performans (her Sales sorgusuna SalesProducts join) | Dashboard load süresi ölç (PerfState); gerekirse CROSS APPLY SUM |
| İade sign (DocType=3) bozulur | Her sorguda IIF/CASE iade işareti korunur + test |
| B-81 iade-netleme ile çakışma | SalesProducts'a geçiş B-81'in EncoreMerkez ayağını KISMEN çözer; koordine et (ReturnAmount netleme tek seferde) |
| Headline ~%5-6 düşer → kullanıcı şaşırır | Beklenen; CFO onaylı. Yine de ilk deploy'da bilgilendir |
| E-ticaret SELLINGPRICEWITHOUTVAT iptal/iade satırı | STATUS filtresi (iptal 1006/2005, iade) mevcut mantıkla korunur |

---

## Done Criteria

- [ ] 28 sorgu KDV-hariç (+ e-ticaret kargo-hariç); irsHrk dokunulmadı
- [ ] Headline storeSql KDV-hariç, fiş sayısı değişmedi, toplam ~%5-6 düştü (mutabakatlı)
- [ ] E-ticaret ciro = SELLINGPRICEWITHOUTVAT (kargo/servis hariç), kanal+funnel+RFM tutarlı
- [ ] Tahmin motoru (KDV-hariç) ile Genel Bakış ciro artık **aynı ölçek** (kıyaslanabilir)
- [ ] Her WP MCP eski/yeni mutabakatlı (fark beklenen aralıkta)
- [ ] Dashboard load süresi kabul edilebilir (join sonrası)
- [ ] silent-failure-hunter + smoke test (4 sayfa)
- [ ] sema güncel (bu plan + karar), eski KDV-dahil referansları süperseded

---

## Rollback
Sorgu-bazlı; her WP ayrı commit. Sapma/perf sorunu → o WP `git revert`. irsHrk dokunulmadığı için tahmin motoru etkilenmez.

---

## Sıra
WP-A headline ÖNCE (en kritik, en görünür) → mutabakat → WP-B kategori → WP-C e-ticaret → WP-D müşteri. Her WP: düzelt → MCP mutabakat → commit. Sonda smoke + perf + sema.

---

## Alternatifler (reddedilen)
- **KDV-dahil bırak + tahmini KDV-dahile çevir:** kullanıcı reddetti ("her şey KDVsiz").
- **Blended KDV çarpanı (~%5-6 sabit):** kategori karışımı kayar, yanlış. Satır-bazlı VatTotal/SELLINGPRICEWITHOUTVAT kesin.
- **irsHrk'ye toptan geçiş:** EncoreMerkez fiş/kasiyer/ödeme/kampanya detayı irsHrk'de yok; sadece tutarı KDV-hariç'e çek, kaynağı koru.
