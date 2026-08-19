# Sınav POS Fişleri — KDV / Ciro Kontrol Listesi
**Tarih:** 18.08.2026 · **Kaynak:** EncoreMerkez.Sales + SalesProducts (IsValid=1) · **Hazırlayan:** analiz (2026-08-19)

Amaç: raporda kullanılan `SalesProducts.TotalPrice` kolonunun KDV DAHİL olduğunu, fiş indiriminin satırda görünmediğini ve kıyafet bloğuna Sınav-dışı satış + iade karıştığını **kasa fişi/Z raporu ile** teyit etmek.

Günün tamamı (Sınav, belge tipi 8 · 24 fiş / 721 satır):
Brüt 1.273.063,30 − İndirim 39.212,79 = **Net 1.233.850,51 (KDV DAHİL)** · KDV 22.359,94 · **Net KDV hariç 1.211.490,57**

---

## A · KDV-dahil testi — karışık oranlı 2 fiş

Kasa fişindeki **yazan toplam**, aşağıdaki "Satır toplamı (KDV dahil)" ile aynı çıkmalı. Aynıysa `TotalPrice` KDV dahildir (rapordaki "NetTutar" adı yanlış).

### A1 · Fiş Id 1253461
| Alan | Değer |
|---|---|
| Belge No | 17870442910003 |
| Fiş No (ReceiptNo) | 50 |
| Z No | 426 |
| Kasa (POS SerialNumber) | 32 |
| Sipariş Kod | 3812026281199 |

| KDV | Satır | Tutar (KDV dahil) | KDV | KDV hariç |
|---|---|---|---|---|
| %0 | 7 | 18.250,00 | 0,00 | 18.250,00 |
| %10 | 4 | 3.085,00 | 280,45 | 2.804,55 |
| %20 | 6 | 6.776,00 | 1.129,33 | 5.646,67 |
| **Toplam** | **17** | **28.111,00** | **1.409,78** | **26.701,22** |

Header: GrossTotal 28.756,00 − İndirim 645,00 = 28.111,00 ✓

### A2 · Fiş Id 1253388
| Alan | Değer |
|---|---|
| Belge No | 17870415870002 |
| Fiş No | 50 · **Z No** 157 · **Kasa** 31 |
| Sipariş Kod | 3812026281182 |

| KDV | Satır | Tutar (KDV dahil) | KDV | KDV hariç |
|---|---|---|---|---|
| %0 | 5 | 57.250,37 | 0,00 | 57.250,37 |
| %10 | 22 | 14.390,97 | 1.308,27 | 13.082,70 |
| %20 | 25 | 5.005,46 | 834,24 | 4.171,22 |
| **Toplam** | **52** | **76.646,80** | **2.142,51** | **74.504,29** |

Header: 79.138,30 − 2.491,50 = 76.646,80 ✓

---

## B · Fiş indirimi satırda görünmüyor (Indirect)

`DiscountTotalDirect` tek başına kullanılırsa indirim eksik ölçülüyor. Kontrol: fiş üzerinde **fiş sonu / genel indirim** satırı var mı?

| Fiş Id | Belge No | Fiş No | Z No | Kasa | Sipariş Kod | Brüt | İndirim (header) | Direct | **Indirect** | Net (KDV dahil) |
|---|---|---|---|---|---|---|---|---|---|---|
| 1254543 | 17870610920006 | 113 | 205 | 35 | 3812026281267 | 74.484,00 | 6.484,00 | 0,00 | **6.484,00** | 68.000,00 |
| 1254758 | 17870626860004 | 104 | 461 | 33 | 3812026281298 | 74.068,00 | 6.068,00 | 0,00 | **6.068,00** | 68.000,00 |
| 1255303 | 17870693780006 | 173 | 205 | 35 | 3812026281366 | 75.512,00 | 6.484,00 | 0,00 | **6.484,00** | 69.028,00 |
| 1255422 | 17870713020007 | 38 | 107 | 36 | 3812026281373 | 73.304,00 | 4.504,00 | 200,00 | **4.304,00** | 68.800,00 |
| 1253388 | 17870415870002 | 50 | 157 | 31 | 3812026281182 | 79.138,30 | 2.491,50 | 279,50 | **2.212,00** | 76.646,80 |
| 1255037 | 17870661110006 | 144 | 205 | 35 | 3812026281311 | 70.426,20 | 2.398,88 | 460,38 | **1.938,50** | 68.027,32 |

Gün toplamı: Direct 5.981,79 + **Indirect 33.231,00** = 39.212,79 (indirimin %85'i Indirect'te).

---

## C · Kıyafet İADE fişi — ciroya ARTI olarak eklenmiş

Kıyafet sorgusunda `IIF(DocumentsTypeId=3,-1,1)` yok → bu iade ciroya (+) yazılıyor. Hata etkisi 2 × 10.150,80 = **20.301,60 ₺**.

| Alan | Değer |
|---|---|
| Fiş Id | 1255737 |
| Belge No | GTY10012597000107/000436 |
| Fiş No | 58 · **Z No** 107 · **Kasa** 36 |
| Saat | 18.08.2026 20:54:48 |
| Belge tipi | **İade (3)** |
| Sipariş Kod | **YOK (Sınav değil, perakende)** |

| Ürün | Adet | KDV | Tutar (dahil) |
|---|---|---|---|
| EŞOFMAN TAKIMI LACİVERT 9-10 | 1 | %10 | 2.671,26 |
| LACOSTE UZUN G. YAKA 9-10 BEYAZ | 1 | %10 | 1.408,48 |
| LACOSTE KISA G.YAKA KIRMIZI 9-10 | 1 | %10 | 1.262,78 |
| PENYE UZUN KIRMIZI 9-10 | 1 | %10 | 1.019,94 |
| PENYE UZUN K.GRİ MELANJ 9-10 | 1 | %10 | 1.019,94 |
| PENYE KISA KIRMIZI 9-10 | 1 | %10 | 922,80 |
| PENYE KISA K.GRİ MELANJ 9-10 | 1 | %10 | 922,80 |
| PENYE BULMACA KISA BEYAZ 9-10 | 1 | %10 | 922,80 |
| **Toplam** | **8** | | **10.150,80** |

---

## D · Sınav DIŞI perakende kıyafet fişleri — Sınav raporuna girmemeli

Kıyafet sorgusu `SinavSiparisFisEncore`'a bağlı olmadığı için bu fişler de geliyor (Sipariş Kod'u YOK).

| Fiş Id | Belge No | Fiş No | Z No | Kasa | Saat | Kıyafet satır | Tutar (dahil) | KDV |
|---|---|---|---|---|---|---|---|---|
| 1253287 | 17870389690002 | 19 | 157 | 31 | 10:45 | 4 | 2.885,00 | 262,27 |
| 1253593 | 17870469760003 | 78 | 426 | 32 | 12:59 | 4 | 6.200,00 | 563,64 |
| 1253806 | 17870501710007 | 11 | 107 | 36 | 13:49 | 1 | 1.890,00 | 171,82 |
| 1254344 | 17870582760005 | 111 | 389 | 34 | 16:09 | 3 | 2.499,00 | 227,18 |
| 1254399 | 17870590100006 | 88 | 205 | 35 | 16:19 | 4 | 4.700,00 | 268,18 |
| 1255171 | 17870681020005 | 209 | 389 | 34 | 18:50 | 1 | 950,00 | 158,33 |

Günün kıyafet kırılımı: **Sınav (tip 8) 38.949,83** · perakende Fiş 77.306,30 · perakende İade 10.150,80.

---

## Tek fiş sorgulama (kontrol eden kişi için)

```sql
DECLARE @FisId bigint = 1253461;   -- kontrol edilecek fiş

SELECT S.Id, S.DocumentNo, S.ReceiptNo, S.ClosureNo AS Zno, PS.SerialNumber AS Kasa,
       DT.Name AS BelgeTip, S.Date, SP.Sequence, PR.Name AS Urun, SP.Amount,
       SP.VatPercent, SP.TotalPrice AS TutarKdvDahil, SP.VatTotal AS Kdv,
       SP.TotalPrice - SP.VatTotal AS TutarKdvHaric,
       SP.DiscountTotalDirect, SP.DiscountTotalIndirect
FROM EncoreMerkez.dbo.Sales S
     JOIN EncoreMerkez.dbo.Pos PS           ON PS.Id = S.PosId
     JOIN EncoreMerkez.dbo.Documents DT     ON DT.Id = S.DocumentsTypeId
     JOIN EncoreMerkez.dbo.SalesProducts SP ON SP.SalesId = S.Id AND SP.IsValid = 1
     JOIN EncoreMerkez.dbo.Products PR      ON PR.Id = SP.ProductsId
WHERE S.Id = @FisId
ORDER BY SP.Sequence;
```
