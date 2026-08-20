# QA — /sinav Paneli (plan-35, B-159)

**Tarih:** 20.08.2026 · **Kapsam:** `SinavQueries.cs` (6 metot) + `Sinav.razor` (5 bölüm) · **Dönem:** 8 (canlı)
**Yöntem:** `veri-dogrula` skill — metodoloji + BKM çek-liste + spot-check + cross-source mutabakat

---

## 1 · BKM-özel çek-liste

| # | Kontrol | Sonuç | Kanıt |
|---|---|---|---|
| 1 | `SalesProducts` → `IsValid = 1` | ✓ | `SalesProducts` dosyada 1 kez geçiyor, aynı satırda `IsValid = 1` |
| 2 | İade SUM'da negatif sign | ✓ | `FisSet.Isaret` (+1/−1) 11 yerde; KPI'da iade ayrı CTE'den çıkarılıyor |
| 3 | Müşteri raporu fiş bazlı | N/A | Bu panel Sınav-özel. B-103 direktifi müşteri raporlarından Sınav'ı **dışlar**; ters yönde çakışma yok |
| 4 | İndirim = `DiscountTotalDirect` | ⚠ bilinçli sapma | KPI **header** `Sales.DiscountTotal` kullanıyor. 19.08 keşfi: header = Direct + Indirect; Sınav fişlerinde indirimin %85'i Indirect (5.981,79 vs 39.212,79). Yalnız Direct kullanmak indirimi eksik ölçer. Kural metni satır-düzeyi kolonlar için yazılmış, header için değil |
| 5 | Net ciro = `GrossTotal − DiscountTotal − VatTotal` | ✓ | `TotalAmount` dosyada **0 kez** geçiyor |
| 6 | Ürün eşleşmesi stkID üstünden | ✓ | `U.stkID = PR.Code` (Products.Code köprüsü). `BarcodeNo` join YOK |
| 7 | Tarih DMY / ISO | ✓ | Sorgularda tarih literali **yok** — filtre `@donemId` parametresi |
| 8 | Cross-db string join → COLLATE | ✓ | Gerekmiyor: `FE.InvoiceNo`, `FE.SiparisKod`, `Siparis.SiparisKod`, `SiparisDetay.FisId` ve `Sales.DocumentNo` **hepsi `Turkish_CI_AS`** (canlı `sys.columns` ile doğrulandı) → sessiz kaçak riski yok |
| 9 | `ehAdetN` işareti | N/A | `irsHrk` kullanılmıyor |
| 10 | Hedef prorate | N/A | Hedef kıyası yok |
| 11 | İç-kart filtresi | N/A | Müşteri/sadakat metriği yok |
| 12 | Dapper 8+ kolon ValueTuple | ✓ | `QueryAsync<(` **0 kez**; tüm modeller settable-prop `sealed class` |

## 2 · Metodoloji

| Konu | Sonuç |
|---|---|
| Soru çerçevesi | ✓ Panel "Sınav sipariş → fiş → tahsilat" zincirini ölçüyor; başlıkta kapsam açık |
| Dönem kıyası | N/A — bu sürümde YoY/MoM yok (momentum eğrisi kapsam dışı, öneri #9) |
| Popülasyon | ✓ Dönem dropdown'la açık; `DonemId` **parametre** (hardcode 8 dönem 7'nin 8.998 fişini silerdi) |
| Baz / payda | ✓ Ort. sepet paydası **sipariş** (fiş değil) — ping-pong fiş sayısını şişirir. Attach paydası fiş |
| Kapsam etiketi | ✓ "Tüm tutarlar KDV hariç" + "İade LinkedDocumentId zincirinden düşülür" sayfa başında |

## 3 · Spot-check (bağımsız yeniden hesap)

| Test | A | B | Fark |
|---|---|---|---|
| **Header ↔ satır** (satış fişleri) | `Σ(GrossTotal−DiscountTotal−VatTotal)` = 18.705.473,89 | `Σ(TotalPrice−VatTotal)` = 18.705.473,89 | **0,00** · 341/341 fiş sapmasız |
| **KPI ↔ kova** (aynı sayfa iki bölüm) | KPI net = 19.361.373 | Kova toplamı = 19.361.373 | **0,00** |
| **Alt-toplam = genel** | Paket 87,8 + Yan 7,7 + Kıyafet 4,5 | %100,0 | ✓ |
| **Ödeme kartı sipariş sayısı** | 314 + 37 + 27 = 378 | KPI sipariş = 378 | ✓ |
| **Büyüklük mantığı** | Ort. sepet 51.221 ₺ | Sınav paket seti (kitap+kırtasiye, 8-29 kalem) | ✓ makul |

## 4 · Cross-source mutabakat

| Metrik | Kaynak A (uygulama) | Kaynak B (ERP) | Fark | Sonuç |
|---|---|---|---|---|
| Dönem 8 satış (KDV dahil) | `snv.SinavSiparisFisEncore.InvoiceTotal` = **19.879.286,19** | `EncoreMerkez.Sales.GrossTotal − DiscountTotal` = **19.879.286,19** | **0,00** · sapan fiş **0/354** | ✓ **iki bağımsız kaynak mutabık** |

`InvoiceTotal` uygulama tarafının kendi yazdığı tutar, `Sales` ERP'nin — gerçekten bağımsız iki kayıt. Kuruş sapması yok.

**Join explosion testi:** FE dönem-8 satırı `EXISTS` ile 359 = `JOIN` ile 359 = tekil `Sales.Id` 359 → **fan-out yok**. (354 satış + 5 FE-içi iade.)

## 5 · Düzeltilen bulgu

**✗ → ✓ Ödeme kartındaki ciro sapması.** Ödeme sorgusunun `NetKdvHaric` kolonu sipariş-bazlı ve FE-kapsamlı (dönem-üstü) hesaplanıyor; KPI/kova ciro rakamıyla **9.228 ₺** sapıyordu (FE-dışı 1 iade fişi). Aynı sayfada iki farklı ciro = CFO'nun ilk fark edeceği tutarsızlık. **Ciro satırı ödeme kartından kaldırıldı**; tek ciro kaynağı KPI şeridi. Model alanı belgeli olarak duruyor, UI'da gösterilmiyor. Build yeşil.

## 6 · Kalan belirsizlikler (overclaim değil, dürüst not)

1. **Dönem listesinde şüpheli kayıtlar:** `DonemId` 1 (13 sipariş), −7 (15), −8 (1 sipariş / 08.2026). Negatif ID'ler test/hata kaydı olabilir — dropdown'da görünüyorlar. **Teyit bekliyor.**
2. **`snv.SinifKitap`'ta canlı TEST verisi:** MOMO için `SinifId 39 = "TEST 21.06sınıfı"`. Panel bunu kullanmıyor ama sınıf listesi raporlarında görünür.
3. **Tek-kaynak metrikler:** eksik kalem tutarı yalnız `SinavUrun.Fiyat`'tan geliyor (`SiparisDetay.BirimFiyat` NULL) → **mutabakat yok, tek kaynak.** Fiyat kartı bayatsa tutar yanlış olur; kalem SAYISI güvenilir.
4. **Kasa düzeltmesi / gerçek iade ayrımı sezgisel:** aynı gün + aynı Z kuralı. Farklı günde yapılan düzeltme "gerçek iade" sayılır (yanlış pozitif). Ölçek küçük (dönem 8'de 6 iade, 3'ü düzeltme).
5. **Dönem 5-6 kapsam dışı** — o dönemler `snv.SiparisFis` (EAR/EFA) köprüsünde, panel yalnız Encore dönemlerini (7-8) doğru gösterir. Dropdown 5/6'yı da listeliyor ama fiş tarafı boş kalır.

---

## Güven notu

**Yüksek** — rakam tarafı iki bağımsız kaynakta kuruş sapmasız mutabık, üç spot-check tuttu, konvansiyon çek-listesi temiz, fan-out yok. Tek bilinçli kural sapması (#4 header indirimi) canlı kanıtla gerekçeli. Kalan belirsizlikler kapsam/veri-kalitesi notları; rakamları geçersiz kılmıyor.

**Teslime uygun.** Madde 1 (şüpheli dönem ID'leri) ve madde 5 (dönem 5-6) kullanıcı kararı bekliyor — dropdown filtresi eklenirse panel daha net olur.
