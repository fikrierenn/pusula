# 02 — Mekan Mapping & Temel Tablolar

> Üst: [`00-INDEX.md`](00-INDEX.md) · [`../CLAUDE.md`](../CLAUDE.md)

## Mağazalar

| mekanID | Ad | EncoreMerkez StoreId | Encore Code |
|---|---|---|---|
| 1 | FSM | 2 | M01 |
| 4477 | Özlüce | 3 | M02 |
| 4478 | İst.Yolu | 1 | M03 |

Başka şube YOK. **Sınav Okulları operasyonu Ağu 2024'te FSM'den İst.Yolu'na taşındı** (kapasite+otopark). Ağu-Eyl sezonunda İst.Yolu cironun %80+'ı alır.

## Ana Tablolar (`DerinSISBkm`)

- `urn` — Ürün ana tablosu (stkID, stkAd, urnKtgrID, urnKtgr1ID, urnKtgr2ID, urnTip)
- `urnKategori_vw` — Kategori hiyerarşisi view
- `urnKtgr2` — Kategori3 isimleri (`ktgrAd` kolonu — **`ktgr2Ad` DEĞİL**)
- `irsHrk` — İrsaliye/stok hareketleri (minimal; satış kanalı kolonu YOK → köprü: [`04-kanal-koprusu.md`](04-kanal-koprusu.md))
- `fyt` — Fiyat tablosu (fTur=0 satış üst fiyatı)
- `fat`, `fatAyr` — Fatura başlık/satır
- `bkm.ENVANTER_RAPORU` — Günlük envanter raporu (98 satır/gün, 2 maliyet tipi)
- `bkm.TarihtekiUstFiyat(stkID, tarih)` — Skaler fonksiyon (fyt'den fTur=0 üst fiyat)
- `depo.paletUrnTnm`, `depo.paletTnm`, `depo.adres` — WMS

## Kritik İsimlendirme Uyarısı

`urn` tablosu:
- **Ürün adı = `stkAd`** (`urnAd` DEĞİL — invalid column hatası verir)
- **Ürün ID = `stkID`** (`urnID` DEĞİL) — `SiparisDetay.StokId`, `irsHrk.ehstkID` ile eşleşir

## BKM (Sınav) Şeması

`BKM.snv.*` — sınav operasyonu:
- `Siparis` (SiparisId, SiparisKod, OkulId, OgrenciId, DonemId, Odendi, Hazirlandi, IrsaliyeId)
- `SiparisDetay` (SiparisDetayId, SiparisId, StokId, Adet, FisId)
- `SinavSiparisFisEncore` (SiparisKod, **InvoiceNo** = Sales.DocumentNo köprüsü)
- `SiparisFis`, `Okul`, `Ogrenci`, `Donem`, `SinavUrun`

## EncoreMerkez (POS) Şeması

`EncoreMerkez.dbo.*`:
- `Sales` (889K) — POS fiş başlığı: Id, DocumentNo, Date, StoresId, GrossTotal, DiscountTotal, TotalAmount, LineCount
- `SalesProducts` (4.2M) — POS fiş satırı: SalesId, Sequence, ProductsId, BarcodeNo, Amount, TotalPrice, DiscountTotalDirect
- `Products` — ürün master (urn eşlemesi henüz kurulmadı)
- `Stores` — mağaza (StoresId ↔ mekanID mapping doğrulanacak)

**Formül:** `InvoiceTotal = Sales.GrossTotal − Sales.DiscountTotal`
