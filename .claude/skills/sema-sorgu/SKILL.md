---
name: sema-sorgu
description: Doğal dil isteğinden çalıştırılabilir T-SQL üretir. sema/*.yaml (köprü/kod/metrik/entity) + CLAUDE.md kurallarını (DMY, COLLATE, compat-110, IsValid, belge filtresi) + benzer sorgular/*.sql referansını okuyup doğru JOIN/filtre ile sorgu yazar. "sorgu yaz", "SQL üret", "şu cironun sorgusu", "/sema-sorgu" denildiğinde veya kullanıcı veri sorusu sorup SQL beklediğinde devreye gir.
---

# sema-sorgu — Doğal Dil → Doğru T-SQL (Semantik Katman Destekli)

BKM şemasında sorgu yazmak köprü/kod/filtre bilgisini gerektirir (stkKod≠barkod, Products.Code=stkID, iade netleme, DMY vs ISO). Bu skill **sorgu yazmadan ÖNCE sema/'ya bakar** (semantic-layer.md kuralı), kuralları uygular, çalıştırılabilir SQL üretir. Tahmin değil — kaynaktan okur.

## Ne zaman tetiklenir
- Kullanıcı bir veri sorusu sorup SQL/rakam istiyor ("FSM geçen hafta kampanyalı ciro", "Oyuncak kategorisi devir hızı").
- "sorgu yaz / SQL üret / bunu sorgula" dendi.
- Mevcut bir sorguyu uyarlama/düzeltme istendi.

## Adımlar (SIRAYLA — atlanırsa sessiz yanlış rakam)

1. **sema/'ya bak (ZORUNLU):**
   - Join/köprü → `sema/bridges.yaml` (ör. `irsHrk.ehstkID=urn.stkID`, `Products.Code=stkID`, `J_ITEMS.DERINSIS_ID=urn.stkID`).
   - Enum/kod → `sema/codes.yaml` (ehTip 1/3/4/5/100/101, DocumentsTypeId, STATUS).
   - Metrik/formül → `sema/metrics.yaml` (net_ciro, KDV-hariç, iade netleme, devir).
   - Tablo/grain/PK → `sema/entities.yaml`.
   - Kayıt **stale** ise (last_verified+ttl geçmiş) → körü körüne kullanma, canlı doğrula (semantic-layer.md decay).

2. **Benzer sorgu ara:** `sorgular/**/*.sql` (91 dosya) içinde aynı konuyu grep et — kalıbı taklit et (kendi stilini dayatma).

3. **Kuralları uygula** (`.claude/rules/sql-server-conventions.md`):
   - Tarih: yerel **DMY** (`CONVERT(...,104)` / `dd.MM.yyyy`); ODAKJOKER linked **ISO YYYYMMDD**. `yyyy-MM-dd` YASAK.
   - Cross-db string join → `COLLATE Turkish_CI_AS`.
   - EncoreMerkez compat 110: `STRING_AGG`/`TRIM`/`IIF`/`TRY_CONVERT` YOK → alternatif.
   - `SalesProducts` → daima `WHERE IsValid=1`. `LineCount` KULLANMA → CROSS APPLY COUNT.
   - İndirim: sadece `DiscountTotalDirect`. Belge: `DocumentsTypeId IN (1,2,3,6,7,8)`, iade(3) negatif sign.
   - **Müşteri/RFM/sadakat sorgusu → FİŞ bazlı**: sayım/frekans `DocumentsTypeId=1`, ciro `(1,3)`; Fatura(2)/Personel(6,7)/Sınav(8) HARİÇ. Kartsız=anonim(CustomersId=0) dahil. Bkz. `sql-server-conventions.md` § MÜŞTERİ RAPORLARI FİŞ BAZLI.
   - **stkKod≠barkod** → ürün/kategori eşleşmesi daima stkID (`irsHrk.ehstkID=urn.stkID` veya `Products.Code=stkID`).
   - **KDV-hariç** (plan-16): EncoreMerkez `GrossTotal-DiscountTotal-VatTotal` / SalesProducts `TotalPrice-VatTotal`; e-ticaret `SELLINGPRICEWITHOUTVAT` (kargo-hariç). irsHrk `ehTutarN` zaten KDV-hariç.
   - Net ciro irsHrk: `SUM(CASE WHEN ehTip IN(1,4,100) THEN ehTutarN WHEN ehTip IN(3,5,101) THEN -ehTutarN END)`.

4. **MCP gotcha'ları** (eğer `mcp__sqlserver__sql_query` ile çalıştırılacaksa):
   - CTE çalışmaz (auto-TOP wrap) → tek SELECT. ORDER BY top-level olmaz → TOP ekle veya çıkar. Multi-statement reddedilir → değişken yerine inline literal.
   - SSMS için CTE'li tam sorgu ayrı verilebilir (Fikri CTE tercih eder).

5. **Üret + açıkla:** SQL + tek cümle "hangi köprü/filtre neden". Sunucu seçimi: BKM/ERP → `sqlserver` (40.201); Express → `sqlserver-express` (66).

6. **Yeni gerçek çıktıysa** → `sema-ogren` ile kaydet (köprü/kod/grain doğrulandıysa).

## Çıktı formatı
```sql
-- Soru: <doğal dil>
-- Köprü/filtre: <sema'dan hangi join+kod+metrik, neden>
<SELECT ...>
```
+ 1 cümle: "Bu sorgu X köprüsünü kullanır çünkü Y (stkKod=barkod tuzağından kaçınır vb.)."

## Anti-pattern
- sema'ya bakmadan ezberden join yazmak (stkKod=barkod, eksik IsValid → sessiz undercount).
- `yyyy-MM-dd` tarih, COLLATE'siz cross-db join, KDV-dahil ciro (plan-16 sonrası).
- CTE'yi MCP'ye göndermek (wrap hatası).

## İlişkili
- `.claude/rules/semantic-layer.md` (sorgu öncesi sema), `.claude/rules/sql-server-conventions.md` (T-SQL kuralları).
- `sema/*.yaml` (canonical), `sorgular/SEMANTIK_KATMAN.md` (insan-okunur), `sorgular/**/*.sql` (örnek).
- Keşif → `sema-ogren`. Üretilen scriptin kalitesi → `python-reviewer` (Python ise).
