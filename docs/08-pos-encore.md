# 08 — EncoreMerkez POS (Kampanya, 3al2öde, Sepet)

> Üst: [`00-INDEX.md`](00-INDEX.md) · [`../CLAUDE.md`](../CLAUDE.md)
> **İlk session kaynağı:** [`../SESSION_LOG.md`](../SESSION_LOG.md) (Session 1–2)
> **Tam şema skill'i:** [`../skills/encore-merkez/SKILL.md`](../skills/encore-merkez/SKILL.md)

## Sistem Profili

- **Platform:** Encore POS (.NET/EF Core)
- **DB:** `EncoreMerkez` (SQL Server compat level 110 / SQL 2012)
- **Kapsam:** 3 mağaza, 19 aktif kasa, ~786K ürün, ~883K Sales kaydı
- **Veri aralığı:** Tem 2025 → güncel

## Stores ↔ mekanID Mapping (ÇÖZÜLDÜ)

| StoreId | Code | Ad | mekanID (DerinSIS) |
|---|---|---|---|
| 1 | M03 | IST YOLU MGZ | **4478** |
| 2 | M01 | FSM Mağaza | **1** |
| 3 | M02 | ÖZLÜCE | **4477** |

Kod bazlı ortak sistem — FSM ve Özlüce aynı mağazalar.

## Kritik Bulgular (Session 2 — 13 Nis 2026)

- **Campaign tablosunda `IsDeleted` kolonu YOK** — diğer tablolarda var
- **3 AL 2 ÖDE:** `CampaignId=1` (eski/pasif), `CampaignId=12` (güncel/aktif)
- **`TotalDiscount` negatif** — raporlarda `ABS()` ile pozitife çevrilmeli
- **`SalesProductCampaigns.DistributedAmount`** — kampanya ürün brüt tutarı
- **`CampaignId = NULL`:** 389,4M ₺ indirim → ürün bazlı fiyat indirimi (kampanya ID atanmamış)
- **Ödeme dağılımı:** %85 kredi kartı (Anadolubank %32, Garanti %25), %15 nakit
- **Eylül 2025 rekor:** 138M ₺ brüt (okul sezonu)
- **Kampanyalı sepet 2x:** 7,2 ürün vs kampanyasız 3,5 ürün

## Alan İlişkileri — Sales vs SalesProducts (Session 4 — 20 Nis 2026)

### Sales (Fiş Başlık)
- `GrossTotal` = brüt toplam (liste fiyat × adet, iptal satırları HARİÇ)
- `DiscountTotal` = toplam indirim (manuel + kampanya, iptal HARİÇ)
- `GrossTotal - DiscountTotal` = net satış tutarı (KDV hariç)
- **`LineCount` = tüm satır sayısı (iptal dahil! ÜRETİM HATASI)**

### SalesProducts (Ürün Detay)
- `TotalPrice` = satır net tutarı (indirim düşülmüş, KDV hariç)
- `DiscountTotalDirect` = satırdaki TOPLAM indirim (manuel + kampanya dahil)
- `DiscountTotalCampaign` = sadece kampanya indirim kısmı (Direct'in alt kümesi)
- `DiscountTotalIndirect` = ihmal edilebilir (~10K₺ toplam, nadir)
- `IsValid` = false → iptal/düzeltme satırı (Sales toplamlarına dahil DEĞİL)

### Doğrulama Formülleri (IsValid=1 ile)
- `SUM(TotalPrice)` = `Sales.GrossTotal - Sales.DiscountTotal` ✓
- `SUM(DiscountTotalDirect)` = `Sales.DiscountTotal` ✓
- `SUM(TotalPrice + DiscountTotalDirect)` = `Sales.GrossTotal` ✓

### İndirim Kolon Dağılımı (Nisan 2026 verisi)
| Durum | Satır | DiscDirect | DiscCampaign |
|-------|-------|-----------|-------------|
| Kampanyalı (Direct=Campaign) | 105,207 | 8.2M₺ | 8.2M₺ |
| Manuel (Direct>0, Camp=0) | 10,574 | 879K₺ | 0 |
| Karma (Direct>Campaign) | 23 | 4.8K₺ | 2.3K₺ |
| İndirimsiz | 141,334 | 0 | 0 |

**Kural:** Toplamada sadece `DiscountTotalDirect` kullan — `DiscountTotalCampaign` ile toplarsan çift sayarsın.

## Sorgu Kütüphanesi

`sorgular/` altında tematik klasörler:

| Klasör | İçerik |
|---|---|
| `01-ciro/` | Günlük/aylık ciro, mağaza bazlı |
| `02-odeme/` | Ödeme tipi dağılımı |
| `03-kampanya/` | Tüm kampanyalar, 3al2öde, sepet karşılaştırma, en çok satan |
| `04-urun/` | Kategori, marka, en çok satan |
| `05-iade/` | İade analizi, CampaignId NULL |
| `06-operasyon/` | Kasiyer, saat bazlı, gün sonu, fiyat kontrol |
| `07-sistem/` | Sistem istatistikleri |

İndeks: [`../sorgular/INDEX.md`](../sorgular/INDEX.md) (22 sorgu, hepsi CTE + 3AL2ÖDE kırılımlı)

## Kararlar (Session 2'den)

- Subselect yerine **CTE (`;WITH ... AS`)** — Fikri tercihi
- Ciro/kampanya sorgularına 3AL2ÖDE kırılımı (BrutCiro, Indirim, NetCiro, UrunSayisi) eklenmeli
- Tarih: DMY (`CONVERT(varchar, tarih, 104)`)

## Kritik Sorgu Patternleri (Session 5)

### IsValid Filtresi (ZORUNLU)
```sql
-- SalesProducts üzerinde her zaman:
WHERE sp.IsValid = 1
```

### LineCount Yerine CROSS APPLY (ZORUNLU)
```sql
-- s.LineCount KULLANMA — iptal satırlarını dahil eder
CROSS APPLY (
    SELECT COUNT(*) AS GecerliUrun
    FROM dbo.SalesProducts sp
    WHERE sp.SalesId = s.Id AND sp.IsValid = 1
) gc
-- Sonra: gc.GecerliUrun kullan
```

### İndirim Toplamı
```sql
-- Sadece DiscountTotalDirect kullan (Campaign alt kümesidir)
SUM(sp.DiscountTotalDirect) -- = Sales.DiscountTotal
-- DiscountTotalCampaign ayrıca TOPLAMA — çift sayar
```

### Belge Tipi Filtresi (ZORUNLU)
```sql
-- Sales.DocumentsTypeId → Documents.Id (DocumentTypes.Id DEĞİL!)
-- Documents tablosu:
--   1=Fiş(Fiş), 2=Fatura(Fatura), 3=İade(İade), 4=İade-Değişim(Değişim)
--   5=Yemek Çeki, 6=Personel/Sendika Fişi(Fiş), 7=Personel/Sendika Fatura(Fatura), 8=Sınav Okulları(Fatura)
WHERE s.DocumentsTypeId IN (1, 2, 3, 6, 7, 8)
-- İade (3) negatif sign ile düşülür:
SUM(CASE WHEN s.DocumentsTypeId=3 THEN -s.GrossTotal ELSE s.GrossTotal END)
-- AVG'larda İade hariç (satış ortalaması):
AVG(CASE WHEN s.DocumentsTypeId <> 3 THEN s.GrossTotal END)
```

## İlişkili Raporlar

- `encore-merkez-analiz-raporu.html` — 10 bölüm kapsamlı analiz
- `3al2ode-kampanya-raporu.html` — kampanya performans (eski)
- `sorgular/03-kampanya/3al2ode-kampanya-raporu-nisan2026.html` — **Nisan 2026 güncel** (doğrulanmış)
- `sepet-buyuklugu-etkisi-raporu.html` — sepet büyüklüğü analizi

## SQL Server Uyumluluk Notu

Compat level 110 → çalışmayan fonksiyonlar: `STRING_AGG`, `TRIM`, `IIF`, `TRY_CONVERT`. Yerine `STUFF + FOR XML PATH`, `LTRIM(RTRIM(...))`, `CASE WHEN`, `TRY_CAST` kullan.
