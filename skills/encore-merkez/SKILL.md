# Encore POS Merkez — SQL Server Data Context

EncoreMerkez veritabanı, BKM Kitap mağazalarında kullanılan Encore POS (kasiyeri) sisteminin merkez sunucu veritabanıdır. Satış, ürün, fiyat, kampanya, mağaza ve kasa verilerini barındırır.

## Tetikleme Koşulları
"Encore", "POS", "kasa", "mağaza satış", "ciro", "kampanya", "fiş", "EncoreMerkez", "kasa raporu", "günlük satış", "ödeme tipi", "barkod fiyat" gibi ifadelerde bu skill devreye alınmalı.

---

## 1. Sistem Profili

**Platform**: Encore POS — .NET/EF Core tabanlı merkez yönetim + mağaza kasaları
**Veritabanı**: EncoreMerkez (SQL Server, compatibility level 110 / SQL 2012)
**Kullanım**: 3 mağaza, 19 aktif kasa, ~786K aktif ürün, ~883K satış kaydı
**Veri aralığı**: Temmuz 2025 – güncel (canlı sistem)

### Mağaza Yapısı

| StoreId | Code | Ad |
|---|---|---|
| 1 | M03 | IST YOLU MGZ |
| 2 | M01 | FSM Mağaza |
| 3 | M02 | ÖZLÜCE |

**Not**: Mağaza kodları BKM Kitap DerinSIS sistemiyle ortak — FSM ve Özlüce aynı mağazalar.

---

## 2. Veritabanı Mimarisi

### Şemalar

| Şema | Amaç |
|---|---|
| **dbo** | Ana tablolar (Products, Sales, Stores, Campaign, vb.) |
| **akt** | Aktarım view'ları (barkod, satış bilgi, merkez stok) |
| **crm** | CRM entegrasyon view'ları (ürün, mağaza, kategori, marka) |
| **kmpy** | Kampanya view'ları (kampanya detay, mix-match, ürün detay) |
| **log** | Audit ve log tabloları (fiyat sorgulama geçmişi) |
| **publish** | Yayınlanmış kampanya verileri |
| **snd** | Transfer/sevkiyat tabloları |
| **tmp** | Batch import staging (toplu veri yükleme) |
| **job** | Hangfire job altyapısı |

### Boyut İstatistikleri (Büyük Tablolar)

| Tablo | Satır | Boyut |
|---|---|---|
| SalesProducts | 4.18M | 712 MB |
| StorePrice | 2.5M | — |
| EInvoiceCustomers | 2M | — |
| SalesProductCampaigns | 1.9M | — |
| SalesPayments | 1.08M | 860 MB |
| Sales | 883K | 1.8 GB |
| Barcodes | 865K | — |
| Products | 841K | — |

---

## 3. Çekirdek Tablolar

### 3.1 Products (Ürün Ana Kartı)
PK: `Id` (int)

| Kolon | Tip | Açıklama |
|---|---|---|
| Code | nvarchar(50) | Ürün kodu |
| ShortName | nvarchar(30) | Kısa ad (kasa ekranı) |
| Name | nvarchar(100) | Tam ürün adı |
| IsActive | bit | Aktif/pasif |
| CategoryId | int → ProductCategory | Kategori FK |
| BrandId | int → ProductBrand | Marka FK (yayınevi) |
| GenericId | int → ProductGeneric | Jenerik grup |
| SupplierId | int → ProductSupplier | Tedarikçi FK |
| ProductCode1Id..5Id | int → ProductCode1..5 | 5 seviye sınıflandırma kodu |
| VatPercent | tinyint | Satış KDV oranı |
| BuyingVatPercent | tinyint | Alış KDV oranı |
| PaymentCurrneysTypesId | int → PaymentCurrneysTypes | Para birimi |
| Unit | nvarchar(5) | Birim (AD, KG vb.) |
| IntegrationId | bigint | Dış sistem entegrasyon ID |
| ProductType | tinyint | Ürün tipi |
| DiscountType | tinyint | İndirim tipi |
| PriceType | tinyint | Fiyat tipi |
| ReturnType | tinyint | İade tipi |
| ScaleType | tinyint | Terazi tipi |
| QuantityType | tinyint | Miktar tipi |
| MaxQuantity | decimal | Max satış adedi |
| IsGivesBonus | bit | Bonus kazandırır mı |
| BonusMultiplier | decimal | Bonus çarpanı |
| SalesmanSetting | tinyint | Satıcı zorunluluğu |
| IsDeleted | bit | Soft delete |
| Created/Updated | datetime | Audit |

### 3.2 Sales (Satış Başlık)
PK: `Id` (bigint)

| Kolon | Tip | Açıklama |
|---|---|---|
| DocumentsTypeId | int → Documents | Belge tipi FK |
| ReceiptNo | nvarchar(50) | Fiş numarası |
| DocumentNo | nvarchar(50) | Belge numarası |
| StoresId | int → Stores | Mağaza FK |
| Date | datetime | Satış tarihi |
| StartDate | datetime | İşlem başlangıç |
| UsersId | int → Users | Kasiyer FK |
| PosId | int → Pos | Kasa FK |
| CustomersId | bigint | Müşteri ID (0 = anonim) |
| CustomerCardNo | nvarchar(50) | Müşteri kart no |
| InvoiceType | tinyint | Fatura tipi |
| SalesType | tinyint | Satış tipi |
| TaxNumber | nvarchar(50) | VKN/TCKN |
| PriceId | tinyint | Fiyat listesi ID |
| GrossTotal | decimal(18) | Brüt toplam |
| DiscountTotal | decimal(18) | İndirim toplamı |
| VatTotal | decimal(18) | KDV toplamı |
| TotalAmount | decimal(18) | Net toplam |
| LineCount | smallint | Satır sayısı |
| CancelledLineCount | smallint | İptal satır sayısı |
| TransferStatus | tinyint | Merkeze aktarım durumu |
| TransferBatchId | bigint | Aktarım batch ID |
| ClosureNo | nvarchar(20) | Gün sonu kapanış no |
| LinkedDocumentNo | nvarchar(50) | Bağlı belge (iade için) |
| LinkedDocumentId | bigint | Bağlı belge ID |
| RefundReasonId | int | İade nedeni |
| PosDocumentId | bigint | Kasa tarafı belge ID |
| ExchangeRate | decimal | Döviz kuru |
| CustomerData | nvarchar(max) | Müşteri JSON |
| Details | nvarchar(max) | Ek bilgi JSON |
| Audits | nvarchar(max) | Audit trail JSON |
| Jobs | nvarchar(max) | İş kuyruğu JSON |

### 3.3 SalesProducts (Satış Satır)
PK: `Id` (bigint)

| Kolon | Tip | Açıklama |
|---|---|---|
| SalesId | bigint → Sales | Satış FK |
| Sequence | int | Satır sıra no |
| ProductsId | int → Products | Ürün FK |
| BarcodeNo | nvarchar(50) | Okunan barkod |
| Amount | decimal(18) | Miktar |
| TotalPrice | decimal(18) | Toplam fiyat (KDV dahil) |
| VatPercent | tinyint | KDV oranı |
| VatTotal | decimal(18) | KDV tutarı |
| DiscountTotalDirect | decimal(18) | Doğrudan indirim |
| DiscountTotalIndirect | decimal(18) | Dolaylı indirim |
| DiscountTotalCampaign | decimal(18) | Kampanya indirimi |
| IsValid | bit | Geçerli satır (false = iptal) |
| SalesmanId | int | Satıcı ID |
| ReturnAmount | decimal(18) | İade miktarı |
| IsPriceEnteredByUser | bit | Manuel fiyat girişi |
| RefundReasonId | int | İade nedeni |
| TaxableTotal | decimal(18) | KDV matrahı |
| PriceChangeReasonId | int | Fiyat değişim nedeni |

### 3.4 SalesPayments (Ödeme)
PK: `Id` (bigint)

| Kolon | Tip | Açıklama |
|---|---|---|
| SalesId | bigint → Sales | Satış FK |
| PaymentTypesId | int → PaymentTypes | Ödeme tipi FK |
| Amount | decimal(18) | Ödeme tutarı |
| IsChangeAmount | tinyint | Para üstü mü |
| CreditCardBatchNo | int | Batch no |
| CreditCardStanNo | int | STAN no |
| CreditCardTerminalId | nvarchar(20) | Terminal ID |
| CreditCardInstallmentCount | nvarchar(10) | Taksit sayısı |
| CreditCardNo | nvarchar(20) | Kart no (maskelenmiş) |
| CreditCardAcquirerId | int | Acquirer banka |
| ExchangeAmount | decimal(18) | Döviz tutarı |

### 3.5 StorePrice (Mağaza Fiyat)
PK: `Id` (bigint)

| Kolon | Tip | Açıklama |
|---|---|---|
| StoresId | int → Stores | Mağaza FK |
| ProductsId | int → Products | Ürün FK |
| PriceId | int | Fiyat listesi ID |
| IsActive | bit | Aktif fiyat |
| IsChanged | bit | Değişiklik flag (kasa sync) |
| Price1..Price5 | decimal | 5 adet fiyat alanı |
| IsOnSale | bit | Satışta mı |
| MaxQuantity | decimal | Max miktar |
| NextPrices | nvarchar(max) | Gelecek fiyat JSON |

### 3.6 Barcodes
PK: `Id` (bigint)

| Kolon | Tip | Açıklama |
|---|---|---|
| ProductsId | int → Products | Ürün FK |
| BarcodeNo | nvarchar(50) | Barkod numarası |
| Quantity | int | Koli adedi (1 = tekil) |
| Unit | nvarchar(5) | Birim |
| PriceId | int | Fiyat listesi ID |

### 3.7 Campaign (Kampanya Ana)
PK: `Id` (bigint) — 53 kolon

Kritik kolonlar:
- `Name`, `BeginDate`, `EndDate`, `BeginHour`, `EndHour`
- `CampaignTypeId` (tinyint) — 6 farklı tip
- `MainConditionType`, `MainDiscountType` — koşul/indirim tipi
- `ConditionAmount`, `ConditionQuantity` — koşul değerleri
- `Day1..Day7` (bit) — haftanın günleri
- `Sequence` — öncelik sırası
- `SetId` — kampanya seti
- `BuyNPayN_1ConditionNum`, `BuyNPayN_1PayNum` — N al N öde
- `ExecutionType`, `ExecutionValue` — uygulama tipi/değeri
- `ValidForAllStores` — tüm mağazalarda geçerli mi
- `IsWinningCampaign` — kazanan kampanya mantığı
- `HasScales` — kademeli kampanya

### 3.8 SalesProductCampaigns (Satışa Uygulanan Kampanya)
PK: `Id` (bigint)

| Kolon | Tip | Açıklama |
|---|---|---|
| SalesId | bigint → Sales | Satış FK |
| ProductSequence | int | Ürün satır sırası |
| CampaignId | bigint | Kampanya FK |
| TotalDiscount | decimal | Toplam indirim |
| DistributedAmount | decimal | Dağıtılan tutar |
| DistributedDiscountAmount | decimal | Dağıtılan indirim |
| CampaignVersion | int | Kampanya versiyonu |
| CampaignCode | nvarchar(16) | Kampanya kodu |
| CampaignName | nvarchar(100) | Kampanya adı |
| CouponNo | nvarchar(100) | Kupon no |
| IsOnline | bit | Online kampanya mı |

---

## 4. Referans Tablolar

### Belge Tipleri (Documents)

| Id | Tip |
|---|---|
| 1 | Fiş |
| 2 | Fatura |
| 3 | İade |
| 4 | İade-Değişim |
| 5 | Yemek Çeki |

### Ödeme Tipleri (PaymentTypes)

| Id | Tip |
|---|---|
| 1 | TÜRK LİRASI (nakit) |
| 2 | GARANTİ BANKASI |
| 3 | İŞ BANKASI |
| 4 | T.VAKIFLAR BANK |
| 5 | AKBANK |
| 6 | DENİZBANK |
| 7 | QNB BANK |
| 8 | HALK BANKASI |
| 9 | ANADOLUBANK |
| 10 | İADE ÇEKİ |
| 11 | HEDİYE ÇEKİ |
| 12 | BANKA HAVALE |
| 13 | BURFAŞ ÇEK |

### Kampanya ↔ Ürün Eşleşme Kuralı

**Campaign.Id ↔ Products.ProductCode4Id**: Kampanya tablosundaki Id, Products tablosunda `ProductCode4Id` alanıyla eşleşir. Bir ürünün hangi kampanyaya dahil olduğu bu FK üzerinden belirlenir. Kampanyadaki ürünleri bulmak için:

```sql
SELECT p.Code, p.Name, c.Name AS KampanyaAd
FROM dbo.Products p
JOIN dbo.Campaign c ON p.ProductCode4Id = c.Id
WHERE c.IsActive = 1 AND p.IsDeleted = 0
```

### Kampanya Alt Tabloları

| Tablo | Açıklama |
|---|---|
| CampaignProduct | Kampanyaya dahil ürünler |
| CampaignProductExcluded | Hariç tutulan ürünler |
| CampaignStores | Kampanyanın geçerli olduğu mağazalar |
| CampaignPayment | Kampanyaya bağlı ödeme tipleri |
| CampaignScale | Kademeli kampanya basamakları |
| CampaignSegment | Müşteri segmentleri |
| CampaignSets | Kampanya setleri |

### Ürün Sınıflandırma

| Tablo | Açıklama |
|---|---|
| ProductCategory | Kategori (Edebiyat, Çocuk, Eğitim, vb.) |
| ProductBrand | Marka / Yayınevi |
| ProductGeneric | Jenerik grup |
| ProductSupplier | Tedarikçi |
| ProductCode1..5 | 5 seviye serbest sınıflandırma |

### EInvoiceCustomers (e-Fatura Müşteri)

| Kolon | Tip |
|---|---|
| TaxNumber | nvarchar(20) |
| Name | nvarchar(250) |
| Address | nvarchar(200) |
| Date | smalldatetime |

---

## 5. View'lar

### dbo (Operasyonel)

| View | Açıklama |
|---|---|
| ANLIK_CIRO | Anlık ciro (canlı satış takibi) |
| GUNLUK_CIRO_GDSIZ | Günlük ciro (gün sonu hariç) |
| GUNLUK_CIRO_KATEGORI_GDSIZ | Günlük ciro kategori bazlı |
| Sales_vw | Satış detaylı view |
| SalesProducts_vw | Satış ürün detaylı view |
| SalesPayments_vw | Ödeme detaylı view |
| SalesBonuses_vw | Bonus bilgileri |
| CancelledSales_vw | İptal satışlar |
| CancelledSalesProducts_vw | İptal satış ürünleri |
| vatNumbers_vw | VKN listesi |

### akt (Aktarım — DerinSIS Entegrasyonu)

| View | Açıklama |
|---|---|
| barkod_vw | Barkod aktarım |
| sakMrk_vw | Mağaza-merkez stok aktarım |
| salesInformationsId_vw | Satış bilgi ID'leri |
| salesMessagesId_vw | Satış mesaj ID'leri |

### crm (CRM Entegrasyonu)

| View | Açıklama |
|---|---|
| product_vw | Ürün bilgisi |
| productBarcode_vw | Barkod bilgisi |
| productBrand_vw | Marka bilgisi |
| productCategory_vw | Kategori bilgisi |
| productCode1_vw..productCode5_vw | Sınıflandırma kodları |
| productDetail_vw | Ürün detay |
| productSupplier_vw | Tedarikçi |
| productVariant_vw | Ürün varyant |
| store_vw / storeDetail_vw | Mağaza bilgisi |
| storeGroup1_vw..storeGroup3_vw | Mağaza grupları |
| city_vw / district_vw | İl/İlçe |

### kmpy (Kampanya)

| View | Açıklama |
|---|---|
| kampanya_vw | Kampanya listesi |
| kampanyaMixMatchDetay_vw | Mix-match detay |
| kampanyaUrunDetay_vw | Kampanya ürün detay |

### log / tmp

| View | Açıklama |
|---|---|
| log.PriceQueryHistory_vw | Fiyat sorgu geçmişi |
| tmp.batchMonitor_vw | Batch import izleme |
| tmp.salesErrorMonitor_vw | Satış hata izleme |

---

## 6. Yaygın Sorgu Kalıpları

### Günlük Ciro
```sql
SELECT 
    s.StoresId,
    st.Name AS Magaza,
    CONVERT(varchar, s.Date, 104) AS Tarih,
    COUNT(*) AS FisSayisi,
    SUM(s.TotalAmount) AS ToplamCiro,
    SUM(s.DiscountTotal) AS ToplamIndirim,
    SUM(s.VatTotal) AS ToplamKDV
FROM dbo.Sales s
JOIN dbo.Stores st ON s.StoresId = st.Id
WHERE s.DocumentsTypeId = 1  -- Fiş
  AND CAST(s.Date AS date) = CAST(GETDATE() AS date)
GROUP BY s.StoresId, st.Name, CONVERT(varchar, s.Date, 104)
```

### Ödeme Dağılımı
```sql
SELECT 
    pt.Name AS OdemeTipi,
    COUNT(*) AS Adet,
    SUM(sp.Amount) AS Tutar
FROM dbo.SalesPayments sp
JOIN dbo.PaymentTypes pt ON sp.PaymentTypesId = pt.Id
JOIN dbo.Sales s ON sp.SalesId = s.Id
WHERE CAST(s.Date AS date) = CAST(GETDATE() AS date)
  AND sp.IsChangeAmount = 0
GROUP BY pt.Name
ORDER BY Tutar DESC
```

### Ürün Satış Analizi
```sql
SELECT TOP 20
    p.Code, p.Name,
    SUM(sp.Amount) AS ToplamAdet,
    SUM(sp.TotalPrice) AS ToplamTutar,
    SUM(sp.DiscountTotalCampaign) AS KampanyaIndirim
FROM dbo.SalesProducts sp
JOIN dbo.Products p ON sp.ProductsId = p.Id
JOIN dbo.Sales s ON sp.SalesId = s.Id
WHERE sp.IsValid = 1
  AND CAST(s.Date AS date) >= DATEADD(DAY, -7, CAST(GETDATE() AS date))
GROUP BY p.Code, p.Name
ORDER BY ToplamTutar DESC
```

### Mağaza Fiyat Sorgulama
```sql
SELECT 
    sp.StoresId, st.Name AS Magaza,
    p.Code, p.Name AS Urun,
    sp.Price1, sp.Price2, sp.Price3,
    sp.IsOnSale, sp.IsChanged
FROM dbo.StorePrice sp
JOIN dbo.Products p ON sp.ProductsId = p.Id
JOIN dbo.Stores st ON sp.StoresId = st.Id
WHERE p.Code = @urunKodu AND sp.IsActive = 1
```

### İade Takibi
```sql
SELECT 
    s.DocumentNo, s.ReceiptNo,
    CONVERT(varchar, s.Date, 104) AS Tarih,
    s.LinkedDocumentNo AS OrijinalBelge,
    s.TotalAmount,
    st.Name AS Magaza
FROM dbo.Sales s
JOIN dbo.Stores st ON s.StoresId = st.Id
WHERE s.DocumentsTypeId IN (3, 4)  -- İade, İade-Değişim
  AND CAST(s.Date AS date) >= DATEADD(DAY, -30, CAST(GETDATE() AS date))
ORDER BY s.Date DESC
```

### Kampanya Performans
```sql
SELECT 
    spc.CampaignName,
    COUNT(DISTINCT spc.SalesId) AS FisSayisi,
    CAST(SUM(sp.TotalPrice + ABS(spc.DistributedAmount)) AS decimal(18,2)) AS BrutCiro,
    CAST(SUM(ABS(spc.DistributedAmount)) AS decimal(18,2)) AS Indirim,
    CAST(SUM(sp.TotalPrice) AS decimal(18,2)) AS NetCiro,
    COUNT(*) AS UrunSayisi
FROM dbo.SalesProductCampaigns spc
JOIN dbo.SalesProducts sp ON spc.SalesId = sp.SalesId AND spc.ProductSequence = sp.Sequence
JOIN dbo.Sales s ON spc.SalesId = s.Id
WHERE sp.IsValid = 1
  AND CAST(s.Date AS date) >= DATEADD(DAY, -7, CAST(GETDATE() AS date))
GROUP BY spc.CampaignName
ORDER BY BrutCiro DESC
```

---

## 7. Önemli Kurallar (SQL Yazarken)

1. **Compatibility Level 110**: EncoreMerkez SQL 2012 modunda çalışır. `STRING_AGG`, `TRIM`, `IIF`, `TRY_CONVERT` gibi yeni T-SQL fonksiyonları çalışmaz. `STUFF + FOR XML PATH` kullan.
   - **CTE tercih et**: Subselect yerine `;WITH cte AS (...)` kullan.
2. **Soft Delete**: Çoğu ana tabloda `IsDeleted` bit alanı var. Sorguya `WHERE IsDeleted = 0` eklemeyi unutma.
   - **DİKKAT**: Campaign tablosunda `IsDeleted` kolonu YOK — `IsActive` alanını kullan.
3. **SalesProducts.IsValid**: İptal edilen satırlar `IsValid = 0` olur. Satış raporlarında `WHERE IsValid = 1` filtresi şart.
4. **Belge Tipi Filtresi**: Ciro hesaplarken `DocumentsTypeId = 1` (Fiş) veya `= 2` (Fatura) kullan. İade belgeleri (3, 4) ayrı tutulmalı.
5. **Para Üstü**: SalesPayments'ta `IsChangeAmount = 1` olan kayıtlar para üstüdür, ödeme toplamına dahil edilmemeli.
6. **Tarih Formatı**: DMY formatı kullan — `CONVERT(varchar, tarih, 104)` (dd.MM.yyyy).
7. **Fiyat Alanları**: StorePrice'ta Price1..Price5 var; hangisinin aktif olduğu PriceId ile belirlenir.
8. **Kampanya Versiyonu**: Campaign tablosunda `Version` alanı var. SalesProductCampaigns'teki `CampaignVersion` satış anındaki versiyonu tutar.
9. **JSON Alanlar**: Sales.CustomerData, Sales.Details, Sales.Audits, StorePrice.NextPrices gibi alanlar JSON formatındadır.
10. **Barkod Eşleşme**: Bir ürünün birden fazla barkodu olabilir (Barcodes tablosu). SalesProducts'ta okunan `BarcodeNo` saklanır.
11. **Kasa Sync**: StorePrice.IsChanged = 1 olan kayıtlar kasaya henüz iletilmemiş fiyat değişiklikleridir.
12. **Negatif Tutarlar**: SalesProductCampaigns'de hem `TotalDiscount` hem `DistributedAmount` negatif değer tutar. Raporlarda `ABS()` ile pozitife çevir.
13. **3AL2ÖDE Kırılımı**: Ciro/kampanya sorgularında 3AL2ÖDE (CampaignId IN 1,12) kırılımını CTE ile ekle. CTE mutlaka SalesProducts'a JOIN yapmalı:
    - **BrutCiro** = `SUM(sp.TotalPrice + ABS(spc.DistributedAmount))` — net fiyat + indirim = orijinal fiyat
    - **İndirim** = `SUM(ABS(spc.DistributedAmount))` — kampanyadan kaynaklanan indirim
    - **NetCiro** = `SUM(sp.TotalPrice)` — müşterinin ödediği tutar
    - **UrunSayisi** = `COUNT(*)`
    - DistributedAmount tek başına brüt ciro DEĞİLDİR — dağıtılmış kampanya indirimidir (negatif).
14. **Brüt/İndirim/Net Üçlüsü**: Her ciro sorgusunda bu üçlü birlikte olmalı, tek başına bırakılmamalı.

---

## 8. Entegrasyon Bağlantıları

### EncoreMerkez ↔ DerinSISBkm
- `akt` şemasındaki view'lar DerinSIS'e veri aktarımı için kullanılır
- `akt.barkod_vw` — barkod senkronizasyonu
- `akt.sakMrk_vw` — merkez stok aktarımı
- Ürün eşleşmesi: Products.Code veya Barcodes.BarcodeNo üzerinden

### EncoreMerkez ↔ CRM
- `crm` şemasındaki view'lar dış CRM sistemine veri paylaşır
- Ürün, marka, kategori, mağaza ve müşteri bilgileri

### EncoreMerkez ↔ Kampanya
- `kmpy` şemasındaki view'lar kampanya yönetim paneline veri sağlar
- `publish` şeması kasalara yayınlanan kampanya verilerini tutar

---

## 9. MCP Araçları

Bu skill ile birlikte şu MCP araçları kullanılabilir:

| Araç | Ne zaman kullan |
|---|---|
| `sql_browse_schema` | Şema keşfi — "EncoreMerkez'de hangi tablolar var?" |
| `sql_search_columns` | Kolon arama — "CustomersId içeren tablolar" |
| `sql_relationships` | FK haritası — "Sales neye bağlı?" |
| `sql_sample_data` | Örnek veri — "Campaign'dan 5 satır göster" |
| `sql_query` | SELECT sorgusu çalıştır |
| `sql_table_stats` | Tablo boyut istatistikleri |

**⚠️ Not**: `sql_describe_table` aracı EncoreMerkez'de compatibility level 110 nedeniyle hata verebilir. Alternatif olarak `INFORMATION_SCHEMA.COLUMNS` sorgusu kullan.
