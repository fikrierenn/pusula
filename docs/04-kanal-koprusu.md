# 04 — Sınav / Perakende Kanal Köprüsü (Özet)

> Üst: [`00-INDEX.md`](00-INDEX.md) · [`../CLAUDE.md`](../CLAUDE.md)
> **Derin keşif notları:** [`../sorgular/sinav_kanal_koprusu.md`](../sorgular/sinav_kanal_koprusu.md)

## Problem

`irsHrk` minimal — satış kanalı kolonu yok, kolon eklenemiyor. 2026 tahmini için Sınav işini Perakende'den ayırmak zorunlu → dış tablo köprüsü.

## Köprü Zinciri

```
BKM.snv.Siparis  (SiparisId, SiparisKod, OkulId, OgrenciId)
  └─ BKM.snv.SiparisDetay  (StokId, Adet, FisId = InvoiceNo)
       └─ BKM.snv.SinavSiparisFisEncore  (SiparisKod, InvoiceNo)
            └─ EncoreMerkez.dbo.Sales  (DocumentNo = InvoiceNo)
                 └─ EncoreMerkez.dbo.SalesProducts  (SalesId, BarcodeNo, ProductsId)
```

## Kilit Eşitlik

**`BKM.snv.SinavSiparisFisEncore.InvoiceNo = EncoreMerkez.dbo.Sales.DocumentNo`**

| Kontrol | Sonuç |
|---|---|
| Format | 14 haneli (`1775...0003` — Unix ms + 4 hane POS seq) |
| Kapsama | 9.014 sınav fişi → 8.995 eşleşti → **%99,79** |
| Tutar formülü | `InvoiceTotal = GrossTotal − DiscountTotal` |
| Toplu eşleşme | 413.091.570 TL vs 413.091.885 TL, fark **−315 TL** |
| Birebir tutan | 8.994 / 8.995 (%99,99) |

## Collation Tuzağı

`BKM.snv.*` = `Turkish_CS_AS` · `EncoreMerkez.dbo.*` = `Turkish_CI_AS`

```sql
ON E.InvoiceNo  COLLATE Turkish_CI_AS
 = S.DocumentNo COLLATE Turkish_CI_AS
```

## Satır Bazında Etiketleme (Tercih Edilen)

Aynı POS fişinde sınav paketi + perakende karışabiliyor. Örnek fiş `17755464660003`: 17 satır, 20 adet. Seq 1 = sınav paketi (özel barkod `2025202600002`, 27.637 TL). Seq 2-17 = standart EAN-13 perakende (757 TL).

| Kanal | Barkod Paterni |
|---|---|
| Sınav paket | `____202__0000_` (13 hane, yıl+dönem+sıra) |
| Retail | Standart EAN-13 (`8681...`, `8690...`, `8691...`, `9786...`) |

## Kullanıma Hazır Snippet

```sql
SELECT S.Id, S.DocumentNo, S.Date, S.StoresId,
       (S.GrossTotal - S.DiscountTotal) AS NetTutar,
       CASE WHEN E.Id IS NOT NULL THEN 'SINAV' ELSE 'RETAIL' END AS Kanal
FROM EncoreMerkez.dbo.Sales S
LEFT JOIN BKM.snv.SinavSiparisFisEncore E
       ON E.InvoiceNo COLLATE Turkish_CI_AS = S.DocumentNo COLLATE Turkish_CI_AS
WHERE S.Date >= '01.04.2026' AND S.Date < '01.05.2026';
```

## Atıl Alanlar (snv tarafı)

| Alan | Durum |
|---|---|
| `snv.Siparis.IrsaliyeId` | 27.471 siparişten 3'ünde dolu → kullanılmıyor |
| `snv.Siparis.Hazirlandi` | 23 kayıt → kullanılmıyor |
| `snv.SiparisFis.DerinsisId` | Atıl |
| `snv.Siparis.Odendi` | 26.969 / 27.471 → **aktif** |

DerinSIS'e geçiş bu alanlar üzerinden değil, **POS → Sales** aktarımıyla.

## Bekleyen İşler

1. `EncoreMerkez.Products ↔ DerinSIS.urn` eşleşmesi (ProductsId ↔ stkID?)
2. `Stores ↔ mekanID` mapping (1 = FSM mi?)
3. Sınav paket barkod paterninin 8.995 fişte doğrulaması
4. 19 eksik fiş nedeni
5. `Sales → fat/irsHrk` köprüsü (LinkedDocumentNo / ClosureNo / TransferHistory)
6. `bkm.HareketKanal_vw` view tasarımı
7. 2026 yıllık tahmin (Sınav / Retail ayrıştırılmış)
