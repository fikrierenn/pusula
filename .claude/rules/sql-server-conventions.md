# SQL Server / DerinSIS / EncoreMerkez Konvansiyonları

_BKM Kitap projesinde T-SQL yazımı için kalıcı kurallar._

## Tarih (KRİTİK)

- Yerel sorgular: DMY. `dd.MM.yyyy` veya `CONVERT(varchar, tarih, 104)`.
- Linked server (ODAKJOKER.JOKER): ISO. `'YYYYMMDD'`. DMY burada sessiz hata.
- `yyyy-MM-dd` HİÇBİR yerde kullanılmaz.

## stkKod ≠ Barkod — HER ZAMAN stkID (KRİTİK)

- **`urn.stkKod` BARKOD DEĞİL.** EncoreMerkez `SalesProducts.BarcodeNo` ↔ `urn.stkKod` join **YANLIŞ** — bazı kategorileri (ör. Oyuncak) sessizce kaçırır → ciro undercount, sahte "ölü stok".
- **Kural:** Ürün/kategori/marka eşleşmesi **her zaman stkID üstünden**.
  - DerinSIS-içi: `irsHrk.ehstkID = urn.stkID` (en temiz; satış ehTip 4/100).
  - Barkod gerekiyorsa: `SalesProducts.BarcodeNo = urnBrkd.urnBarkod` → `urnBrkd.urnBrkdStkID = urn.stkID` (`urnBrkdOnce=0`). **stkKod ile join etme.**
- Kategori/marka ciro raporlarını mümkünse **irsHrk** (stkID) üzerinden al → envanter/devir ile tek kaynak, tutarlı.
- ✅ Tüm stkKod=BarcodeNo hataları düzeltildi (09.06): `generate_brief.py` (SQL_CATEGORY+TOTAL), `G4-kategori-magaza.sql`, `A6-marka-yayinevi.sql`, `04-karzarar/2026-05-07-...maliyet-karsilastirma.sql` (u_b) → hepsi Products.Code=stkID. Dashboard `gm_dashboard.py` → irsHrk. (Eski `briefings/*/brief.html` çıktıları tarihsel, regenerate ile düzelir.)

### EncoreMerkez ↔ DerinSIS KÖPRÜSÜ = Products.Code (09.06 keşif — KESİN)

- **`EncoreMerkez.Products.Code` (int) = `DerinSIS.urn.stkID`** — %99,98 eşleşme (798.349/798.527). `Code` stkKod DEĞİL (%9), barkod hiç değil.
- **Doğru POS join:** `SalesProducts.ProductsId → Products.Id`, sonra `urn.stkID = CONVERT(int, Products.Code)` (EncoreMerkez compat 110 → `TRY_CONVERT` yok; `ISNUMERIC(p.Code)=1` guard + `CONVERT(int,p.Code)`).
- Bu, EncoreMerkez POS verisini (per-mağaza, per-fiş) **doğru kategori/marka**ya bağlar — barkod join'in kaçırdığını çözer (Oyuncak ciro 700K→10,96M doğrulandı 09.06).
- Saf DerinSIS analizlerde hâlâ `irsHrk.ehstkID=urn.stkID` en temiz; POS-özel (EncoreMerkez Sales/SalesProducts) gerekince Products.Code köprüsünü kullan.

## Field Adlandırma

- DerinSIS: `urn.stkAd` / `urn.stkID` (urnAd/urnID HATA)
- DerinSIS: `urnKtgr2.ktgrAd` (ktgr2Ad HATA)
- EncoreMerkez Sales: `Sales.LineCount` GÜVENİLMEZ
- EncoreMerkez Campaign: `IsDeleted` kolonu YOK
- EncoreMerkez SalesProducts: `WHERE IsValid = 1` ZORUNLU

## Cross-DB Join

`COLLATE Turkish_CI_AS` — BKM ↔ EncoreMerkez/DerinSIS string join.

## EncoreMerkez Compat 110 (SQL 2012)

Çalışmaz: `STRING_AGG`, `TRIM`, `IIF`, `TRY_CONVERT`.
Alternatifler: `STUFF + FOR XML PATH`, `LTRIM(RTRIM(...))`, `CASE WHEN`, `CONVERT + ISDATE`.

## İndirim Kolonları

- `DiscountTotalDirect` = TOPLAM.
- `DiscountTotalCampaign` = alt küme.
- Sadece Direct kullan.

## Belge Filtresi

`DocumentsTypeId IN (1, 2, 3, 6, 7, 8)`:
- 1=Fiş, 2=Fatura, 3=İade(-), 6=Personel Fiş, 7=Personel Fatura, 8=Sınav

SUM iade sign:
```sql
CASE WHEN s.DocumentsTypeId = 3 THEN -s.GrossTotal ELSE s.GrossTotal END
```

AVG iade hariç:
```sql
CASE WHEN s.DocumentsTypeId <> 3 THEN ... END
```

## SalesProducts CROSS APPLY

```sql
SELECT s.Id, sp.UrunSayisi
FROM Sales s
CROSS APPLY (
    SELECT COUNT(*) AS UrunSayisi
    FROM SalesProducts
    WHERE SalesId = s.Id AND IsValid = 1
) sp
```

## CTE Tercih (Fikri Tercihi)

- CTE > subselect.
- Brüt + İndirim + Net her zaman birlikte.
- Ürün sayısı her ciro raporuna dahil.
- Hazır SQL: çalıştırılabilir + 3AL2ÖDE kırılımlı.

## MCP Sunucu Seçimi

- `sqlserver` (192.168.40.201) → BKM/ERP varsayılan.
- `sqlserver-express` (192.168.40.66\SQLEXPRESS) → "Express'te", "66'da".

## MCP sql_query Limitleri (gotcha)

- **CTE çalışmaz.** `mcp__sqlserver__sql_query` sorguyu auto-TOP wrap edip `(WITH...)` parantezler → `Incorrect syntax near ')'`. MCP için **tek SELECT, CTE'siz** yaz. CTE'li tam sorgular SSMS içindir.
- **ORDER BY top-level olmaz.** Wrapper derived table yapar → `ORDER BY ... unless TOP/OFFSET/FOR XML`. MCP'de ORDER BY'ı çıkar veya `TOP` ekle.
- **Multi-statement reddedilir.** `DECLARE @x; SELECT...` → "Birden fazla statement". MCP'de değişkenleri inline literal yap. SSMS'te DECLARE serbest.

## E-ticaret Müşteri Zinciri

`J_ORDERS.CLIENTREF → J_ORDER_CLIENTS.LOGICALREF → CUSTOMERREF`. J_ORDER_CLIENTS standart. CUSTOMERREF=0/NULL = misafir.

## E-ticaret Sipariş Satırı + stkID Köprüsü (09.06 — KESİN)

- **Sipariş satırları:** `J_ORDER_DETAILS.ORDERREF = J_ORDERS.ORDERID` (LOGICALREF DEĞİL! ORDERID = "TS...30323794" kodundaki sayı).
- **Ürün adı:** `J_ORDER_DETAILS.ITEMREF = J_ITEMS.LOGICALREF` → `J_ITEMS.NAME`.
- **E-ticaret stkID köprüsü:** `J_ITEMS.DERINSIS_ID = urn.stkID` (DerinSIS ürün bağı; kategori için `bkm.UrunBilgi.StkID`/`KatAna` — JOKER'den `DERINSIS` linked server ile erişilir).
- **Fiyat:** `SELLINGPRICE` = BİRİM net fiyat (satır tutarı = `QUANTITY*SELLINGPRICE`). `SELLINGPRICEWITHOUTDISCOUNT` = birim brüt; indirim = `QUANTITY*(WITHOUTDISCOUNT-SELLINGPRICE)`. Kargo `J_ORDERS.CARGOPRICE`, kapıda ödeme `SERVICEPRICE`.

## Müşteri İsmi (Yazarkasa) — kart sistemi uyumsuz (09.06)

- İsim CRM'de: `DerinSISBkmCrm.dbo.mst.mAd` (+ `mKartno`, `Tel1/Tel2`). Ek kart `mstEkkart.EkkrtNo`.
- ⚠️ **EncoreMerkez sadakat kartı (`Sales.CustomerCardNo`, "2025…" 10 hane) CRM kartıyla (`mst.mKartno`, "T…" 8 hane) DOĞRUDAN EŞLEŞMİYOR** — mstEkkart'ta da yok. Yazarkasa müşteri adı için ayrı eşleştirme tablosu/anahtarı gerekiyor (backlog). Dashboard şimdilik kart no gösteriyor.

## Kanal Değerleri (J_ORDERS.APPLICATION)

`'Mobil Uygulama (Android)'`, `'Mobil Uygulama (iOS)'`, `'Mobil Site'`, `'Web Sitesi'`.

## ISO Hafta

```sql
DATEDIFF(DAY, '20251229', CAST(ORDERDATE AS date)) / 7 + 1
```

## İlişkili Dosyalar

- `docs/01-baglanti.md`, `docs/02-tablolar-magaza.md`, `docs/03-ciro-filtreleri.md`
- `docs/05-eticaret-joker.md`, `docs/08-pos-encore.md`
