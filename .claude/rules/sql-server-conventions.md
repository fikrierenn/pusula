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

## Aggregate + Kolon Gotcha (17.06 dersi)

- **`SUM(CASE WHEN ... NOT IN (subquery) ...)` YASAK** — SQL: "Cannot perform an aggregate function on an expression containing a subquery". Aggregate'in CASE'i içinde alt-sorgu olmaz. Çözüm: filtreyi WHERE'e taşı, VEYA Customer-join'li kolon-form kullan (`IcKartFiltre.SqlCols`). WHERE içinde NOT IN(subquery) SERBEST — sadece aggregate-CASE içinde yasak.
- **`EncoreMerkez.Sales.TotalAmount` ≠ NET CİRO.** TotalAmount küçük/adet-benzeri değer (örn. GrossTotal=1320 iken TotalAmount=13) — ciro DEĞİL. Net ciro daima `GrossTotal - DiscountTotal - VatTotal` (KDV-hariç). `SUM(TotalAmount)`'ı ciro sanma (10_01/10_02 bu yüzden çöp üretiyordu).

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

## MÜŞTERİ RAPORLARI = FİŞ BAZLI (KRİTİK — 16.06.2026 CFO direktifi)

**Tüm müşteri/sadakat raporları SADECE perakende fiş üzerinden çalışır.** Fatura(2)/Personel(6,7)/**Sınav Okulları(8)** belge tipleri HARİÇ — bunlar kurumsal/B2B, perakende müşteri davranışı değil (Sınav tek başına "kartsız"ı 266M şişiriyordu, B-102).

- **Sayım/frekans/recency raporu** (RFM segment, RFM geçiş, tekrar-alış, kazanım, kart-oranı): `DocumentsTypeId = 1` (sadece satış fişi). İade(3) bir "alış" değil → frekansa katma.
- **Ciro (Monetary) raporu** (Pareto, win-back, kartlı/kartsız sepet): `DocumentsTypeId IN (1,3)` — iade sign'lı düşülür (`CASE WHEN =3 THEN -net ELSE net`).
- **Kartsız = anonim DAHİL** (`CustomersId=0` yürü-gel müşteri). `CustomersId>0` şartı kartsız tarafını yok eder — KULLANMA. Kartlı = `CustomersId>0 AND CardNumber<>''`.
- İç-kart hariç tutma her zaman `IcKartFiltre` (isim Mağaza/Kumbara + tel 599/699 + elle liste).
- **UI'da belirgin yazılır:** her müşteri sayfası/paneli "fiş bazlı (perakende)" etiketi taşır.

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

## Müşteri İsmi (Yazarkasa) = DerinCrm.Customer (09.06 — ÇÖZÜLDÜ)

- **`DerinCrm.dbo.Customer.Id = EncoreMerkez.Sales.CustomersId`** (int, temiz 1:1 köprü). `Customer.Name` = ad, `Customer.PhoneNumber` = tel, `Customer.CardNumber` = "2025…" sadakat kartı.
- Join: `LEFT JOIN DerinCrm.dbo.Customer c ON c.Id=s.CustomersId` → `ISNULL(c.Name, s.CustomerCardNo)`.
- ⚠️ Yanlış izler: `DerinSISBkmCrm.dbo.mst` (kart "T…" formatı — EncoreMerkez "2025…" ile EŞLEŞMEZ, ayrı sistem). `EncoreMerkezCrm.Customer` BOŞ (tek "Genel"). `Sales.CustomerData` JSON'unda da var (`"Name"`/`"MobilePhone"`) ama JSON-parse yerine DerinCrm join temiz.
- Not: En yüksek-frekanslı "müşteriler" mağaza iç kartları (İstanbulyolu Mağaza, Kumbara) — gerçek müşteri değil, RFM yorumunda dikkat.

## Kanal Değerleri (J_ORDERS.APPLICATION)

`'Mobil Uygulama (Android)'`, `'Mobil Uygulama (iOS)'`, `'Mobil Site'`, `'Web Sitesi'`.

## ISO Hafta

```sql
DATEDIFF(DAY, '20251229', CAST(ORDERDATE AS date)) / 7 + 1
```

## DerinSIS Alış Faturası Convention (ADR-004 — KRİTİK)

- **`ehAdet` alış faturasında NEGATİF gelir** (irsHrk ehTip=1 alış). Satış ehTip=4/100'de pozitif. Toplarken `ABS(ehAdet)` veya işaret farkını hesaba kat.
- **`ehMaliyet` alış faturasında 0 olabilir** — maliyet ayrı job ile güncellenir, anlık sorguda sıfır gelirse job henüz çalışmamış demektir.
- Alış faturası filtresi: `ehTip IN (1)` veya `ehTip IN (1,2)` (iade alış dahilse).

## Arama Perf: `OR EXISTS` yerine `stkID IN (alt-sorgu UNION)` (17.06 dersi)

- **`WHERE ... OR EXISTS(SELECT 1 FROM urnBrkd ...)` YASAK büyük tabloda** — optimizer urn'u (850K) full tarayıp her satıra EXISTS çalıştırır → 5.8s. Barkod/kod araması böyle yavaşladı.
- **Doğrusu:** eşleşen ID'leri ÖNCE indexli alt-sorgudan topla, sonra ana tabloyu daralt:
  `WHERE u.stkID IN (SELECT stkID FROM urn WHERE stkKod=@q UNION SELECT urnBrkdStkID FROM urnBrkd WHERE urnBarkod=@q AND urnBrkdOnce=0)` → 0.14s (42×).
- Genel kural: `OR` ile birden çok tabloya yayılan filtre → optimizer kötü plan; `IN (alt-sorgu)` veya `UNION` ile ayır.
- Korelasyonlu agregat (bakiye/stok) çok-satırlı derived-table JOIN yerine **OUTER APPLY** ile sadece eşleşen ≤N satıra indir (tüm view agg etme).

## Dapper DateOnly ↔ SQL `date` (17.06 dersi)

- **SQL `date` kolonu Dapper'da DateTime döner; record ctor `DateOnly` ise eşleşmez** → `materialization` hatası ("matching signature ... System.DateTime").
- **Çözüm:** global TypeHandler (Program.cs'te bir kez): `Dapper.SqlMapper.AddTypeHandler(new DateOnlyTypeHandler())` — `Parse: DateOnly.FromDateTime((DateTime)v)`, `SetValue: DbType.Date + value.ToDateTime(TimeOnly.MinValue)`. Hem okuma hem yazma (param) çözer.

## İlişkili Dosyalar

- `docs/01-baglanti.md`, `docs/02-tablolar-magaza.md`, `docs/03-ciro-filtreleri.md`
- `docs/05-eticaret-joker.md`, `docs/08-pos-encore.md`
