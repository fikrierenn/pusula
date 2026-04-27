# Sınav / Perakende Kanal Köprüsü — Keşif Notları

**Tarih:** 15 Nisan 2026
**Bağlam:** `irsHrk`'ya kolon ekleyemiyoruz. 2026 tahmini için Sınav işini Perakende'den ayırmak zorunlu. Kolon eklemeden satış kanalı etiketlemesi için dış tablo zinciri arandı.

---

## Köprü Zinciri

```
BKM.snv.Siparis  (sınav siparişi — okul, öğrenci, dönem)
  │ SiparisId ← SiparisKod "3812026277987"
  ▼
BKM.snv.SiparisDetay  (sipariş satırları — her ürün ayrı)
  │ FisId = InvoiceNo (POS fişi 14 haneli)
  ▼
BKM.snv.SinavSiparisFisEncore  (sipariş ↔ fiş köprüsü)
  │ InvoiceNo = "17755464660003"
  ▼  (COLLATE Turkish_CI_AS zorunlu!)
EncoreMerkez.dbo.Sales  (POS fiş başlığı)
  │ Id = SalesId
  ▼
EncoreMerkez.dbo.SalesProducts  (POS fiş satırları — barkod bazında)
```

## Kritik Eşitlik

**`BKM.snv.SinavSiparisFisEncore.InvoiceNo = EncoreMerkez.dbo.Sales.DocumentNo`**

| Kontrol | Sonuç |
|---|---|
| Kapsama | 9.014 sınav fişi → 8.995 eşleşti → **%99,79** |
| Eksik | 19 fiş (araştırılmadı, muhtemelen test/iptal) |
| Tutar formülü | `InvoiceTotal = GrossTotal − DiscountTotal` |
| Toplu doğrulama | 413.091.570 TL vs 413.091.885 TL — fark **−315 TL** |
| Birebir tutan | 8.994 / 8.995 (%99,99), 1 fiş 315 TL sapıyor |

## Collation Tuzağı — Hayat Kurtaran Not

`BKM.snv.*` tabloları **`Turkish_CS_AS`** (case-sensitive).
`EncoreMerkez.dbo.*` tabloları **`Turkish_CI_AS`** (case-insensitive).

Cross-db string join'lerde zorunlu:
```sql
ON E.InvoiceNo COLLATE Turkish_CI_AS = S.DocumentNo COLLATE Turkish_CI_AS
```

Aksi halde: `Cannot resolve the collation conflict between "Turkish_CI_AS" and "Turkish_CS_AS"`.

## Örnek Fiş Anatomisi

**Fiş:** InvoiceNo 17755464660003 | Sipariş 27588 | SiparisKod 3812026277987
**Öğrenci:** 208, Okul 42, Tarih 07.04.2026

### snv.SiparisDetay (6 satır)

6 farklı ürün, ama sadece **1'inde** `FisId = 17755464660003` (yani bu fişe sadece 1 ürün yazılmış). Kalan 5 ürün daha teslim edilmemiş.

| SiparisDetayId | StokId | Adet | FisId | Durum |
|--:|--:|--:|---|---|
| 437864 | 141962 | 1 | NULL | Henüz yazılmamış |
| 437865 | 1541483 | 1 | NULL | Henüz yazılmamış |
| 437866 | 1589602 | 1 | NULL | Henüz yazılmamış |
| 437867 | 217289 | 1 | NULL | Henüz yazılmamış |
| 437868 | 1582568 | 1 | NULL | Henüz yazılmamış |
| 437869 | 1692390 | 1 | **17755464660003** | Bu fişte |

### EncoreMerkez.Sales (1 fiş)

| Alan | Değer |
|---|--:|
| GrossTotal | 28.668,06 |
| DiscountTotal | 274,50 |
| **Net (InvoiceTotal)** | **28.393,56** |
| LineCount | 17 |
| TotalAmount (adet) | 20 |
| StoresId | 1 (FSM) |

### EncoreMerkez.SalesProducts (17 satır, 20 adet)

| Seq | BarcodeNo | Adet | Tutar | Yorum |
|--:|---|--:|--:|---|
| 1 | `2025202600002` | 1 | **27.637,06** | **Sınav paketi** (özel format) |
| 2 | 8693043059818 | 1 | 45 | Retail (silgi) |
| 3 | 9786256115361 | 1 | 274,50 | Retail kitap (iskonto 274,50) |
| 4 | 8691451020956 | 2 | 30 | Retail kırtasiye |
| 5–17 | 8681... / 8690... / 8681... | 14 | 407 | Retail kırtasiye |

**Özet:** Sınav paketi **27.637 TL**, aynı fişte perakende ek satış **757 TL**.

## Satır Bazında Kanal Etiketleme (Tercih Edilen)

Fiş bazında "bu fiş sınav listesinde mi?" şeklinde etiketlemek **basit ama kirli** (aynı fişteki perakendeyi de sınava atar, yukarıdaki örnekte %2,7 sapma).

**Daha temiz yöntem:** `SalesProducts.BarcodeNo` patternine bakmak.

| Kanal | Barkod Paterni | Örnek |
|---|---|---|
| Sınav | Özel format `YYYY202YY0000X` (13 hane, "2025" ile başlıyor) | `2025202600002` |
| Retail | Standart EAN-13 (8681, 8690, 8691, 8693, 9786...) | `8690826141005` |

Alternatif: `ProductsId IN (<sınav paket ürün listesi>)` — bu liste snv.SiparisDetay.StokId × DerinSISBkm.urn haritalamasından çıkarılabilir.

## Siparis Tarafındaki Atıl Kolonlar

`snv` şemasında var ama **kullanılmıyor**:

| Alan | Toplam | Dolu | Not |
|---|--:|--:|---|
| `snv.Siparis` toplam | 27.471 | — | 2023-07-31'den beri |
| `Hazirlandi = 1` | 27.471 | 23 | Neredeyse hiç kullanılmamış |
| `IrsaliyeId NOT NULL` | 27.471 | 3 | Tamamen atıl |
| `Odendi = 1` | 27.471 | 26.969 | Aktif kullanılıyor |
| `snv.SiparisFis` | — | — | Kayıtlar var ama SiparisKod/InvoiceNo ile eşleşmedi |

Sonuç: DerinSIS'e kayıt geçişi bu alanlar üzerinden değil, POS → Sales aktarımıyla yapılıyor.

## Henüz Kurulmamış Bağlantı — ERP (fat/irsHrk)

Sales → DerinSIS (fat / irsHrk) bağlantısı bu oturumda kurulmadı. Olası yollar:

1. `Sales.LinkedDocumentNo` — 0 olmayanları incele
2. `Sales.ClosureNo` (Z raporu) — günlük toplam irsHrk kaydıyla eşleşebilir
3. `Sales.TransferStatus` / `SalesTransferHistory` — aktarım logu
4. `EncoreMerkez.Documents` tablosu üzerinden tip eşleşmesi

## Kullanıma Hazır Sorgu Snippet'leri

### 1) Fiş bazında kanal etiketli Sales

```sql
SELECT S.Id, S.DocumentNo, S.Date, S.StoresId,
       (S.GrossTotal - S.DiscountTotal) AS NetTutar,
       CASE WHEN E.Id IS NOT NULL THEN 'SINAV' ELSE 'RETAIL' END AS Kanal
FROM EncoreMerkez.dbo.Sales S
LEFT JOIN BKM.snv.SinavSiparisFisEncore E
       ON E.InvoiceNo COLLATE Turkish_CI_AS = S.DocumentNo COLLATE Turkish_CI_AS
WHERE S.Date >= '01.04.2026' AND S.Date < '01.05.2026';
```

### 2) Aylık Sınav vs Retail ciro (Sales net)

```sql
SELECT FORMAT(S.Date, 'yyyy-MM') AS Ay,
       S.StoresId,
       SUM(CASE WHEN E.Id IS NOT NULL THEN S.GrossTotal - S.DiscountTotal ELSE 0 END) AS Sinav,
       SUM(CASE WHEN E.Id IS     NULL THEN S.GrossTotal - S.DiscountTotal ELSE 0 END) AS Retail
FROM EncoreMerkez.dbo.Sales S
LEFT JOIN BKM.snv.SinavSiparisFisEncore E
       ON E.InvoiceNo COLLATE Turkish_CI_AS = S.DocumentNo COLLATE Turkish_CI_AS
WHERE S.Date >= '01.01.2024'
GROUP BY FORMAT(S.Date, 'yyyy-MM'), S.StoresId;
```

### 3) Satır bazında kanal (barcode patternli — deneme)

```sql
SELECT SP.SalesId, SP.Sequence, SP.BarcodeNo, SP.TotalPrice,
       CASE WHEN SP.BarcodeNo LIKE '____202__0000_' THEN 'SINAV_PAKET' ELSE 'RETAIL' END AS Kanal
FROM EncoreMerkez.dbo.SalesProducts SP
WHERE SP.SalesId = <SalesId>;
```

Pattern doğrulanmadan production'a alınmamalı — önce `2025...` ve `2024...` ile başlayan barkodları tarayıp hepsinin gerçekten sınav paketi olduğunu kontrol et.

## Bekleyen İşler

1. EncoreMerkez.Products ↔ DerinSIS.urn eşleştirmesi (ProductsId ↔ stkID?)
2. Stores ↔ mekanID mapping (1 = FSM mi gerçekten?)
3. Sınav paket barkod patterninin tüm 8.995 eşleşen fişte doğruluğu
4. 19 eksik fiş nedeni
5. Sales → fat/irsHrk köprüsü (LinkedDocumentNo / ClosureNo / TransferHistory)
6. `bkm.HareketKanal` eleme tablosu + view kurgusu (veya view'ı direkt bu köprü üzerine kur)
7. 2026 yıllık tahmin (Sınav / Retail ayrıştırılmış)
