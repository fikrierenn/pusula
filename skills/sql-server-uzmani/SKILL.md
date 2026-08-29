---
name: sql-server-uzmani
description: SQL Server T-SQL uzmanlık kütüphanesi. T-SQL sorgu, SP, view, function, trigger, transaction yönetimi, FIFO maliyetleme, index optimizasyonu, ERP veri modelleri, audit/log şablonları ve raporlama sorgularında kullan. KRİTİK runtime: Yerel ortamda tarih DMY (dd.MM.yyyy, CONVERT 104 style); yyyy-MM-dd YASAK. Linked server ODAKJOKER ISO (YYYYMMDD) ister. EncoreMerkez compat 110 (STRING_AGG/TRIM/IIF/TRY_CONVERT YOK). FLOAT ile para YASAK; DECIMAL(18,4) zorunlu. src.* views (DerinSIS) sadece okunur, değiştirilmez. sql-kod-inceleme, sql-refactor, veri-yorumlama, finans-butce-muhasebe, bi-dashboard ile zincirleme. Bu skill knowledge base ve runtime kural otoritesidir; review/refactor üretmez, diğer SQL skill'leri buradan runtime kuralı alır.
---

# SQL Server Uzmanlık: T-SQL Knowledge Base ve Runtime Otoritesi

> Bu skill bir review veya refactor aracı DEĞİLDİR. Bir T-SQL kütüphanesi ve runtime kural otoritesidir.
> Birincil hedef: doğru, runtime-uyumlu, ERP bağlamına oturmuş T-SQL üretmek; runtime kuralları konusunda diğer skill'lere otorite kaynak olmak.

---

## 0. Felsefe

T-SQL yazımı serbest stil değildir. Bağlamla (compat level, collation, linked server, ERP veri modeli) tutarlı olmazsa kod çalışmaz veya sessizce yanlış sonuç verir.

İki tehlike:
1. **Generic T-SQL şablonu yapıştırmak**: yerel ortamda çalışan, ODAKJOKER linked server'da patlar.
2. **Bağlam bilmeden şablon vermek**: "bu pattern her durumda doğru" diye sunmak. Doğru pattern yanlış compat level'da derlenmez.

**Kural:** Her şablon bağlam koşullarıyla birlikte sunulur. "Hangi compat level'da, hangi collation'da, hangi veri yoğunluğunda geçerli" yazılı olmalı.

---

## 1. Context Layer

Bu skill kod review, refactor veya executive raporlama üreteci DEĞİLDİR. Kod üretir, şablon verir, runtime kuralları söyler.

Hedef DEĞİLDİR:
- "bu kod prod'a hazır mı" demek (o sql-kod-inceleme)
- mevcut kodu yeniden yazmak (o sql-refactor)
- veri sonucunu yorumlamak (o veri-yorumlama)

Hedef ŞUDUR:
- doğru T-SQL şablonu üretmek
- runtime kurallarını koymak ve diğer skill'lerin onlara güvenmesini sağlamak
- ERP veri modeli pattern'ları sunmak
- FIFO, transaction, audit gibi tekrarlayan ihtiyaçlara kanonik cevap

### 1.1 Tetikleme sinyalleri

| Durum | Tetikle? |
|---|---|
| "Bu SP'yi yaz" | EVET |
| "FIFO maliyet sorgusu lazım" | EVET |
| "Stok transfer SP şablonu" | EVET |
| "Transaction nasıl yönetilir" | EVET |
| "Index önerisi" | EVET |
| "ERP veri modeli sorgusu" (sipariş, üretim, sevkiyat zinciri) | EVET |
| "Audit/log tablosu nasıl kurulur" | EVET |
| "Tarih formatı ne olmalı" | EVET |
| "Bu sorguyu incele/review et" | HAYIR (sql-kod-inceleme) |
| "Bu SP'yi temizle" | HAYIR (sql-refactor) |
| "Bu raporu yorumla" | HAYIR (veri-yorumlama) |

---

## 2. Priority Order (Talimatlar Çatıştığında)

1. **Runtime constraints**: kod çalıştırılabilir mi (DMY tarih, COLLATE, compat level, FLOAT yasağı, src.\* dokunulmaz)
2. **Doğruluk**: hesap doğru mu, edge case kapsanıyor mu
3. **Transaction bütünlüğü**: kritik yazım operasyonu atomik mi
4. **Performans**: index uyumu, set-based, plan istikrarı
5. **Okunabilirlik**: CTE, anlamlı alias, yorum bloğu
6. **Stil**: en son

Çakışma anında üst sıradaki kazanır. Stil için doğruluktan veya runtime uyumundan taviz verilmez.

---

## 3. Runtime Constraints (Mutlak Kurallar)

Bu bölüm bu skill'in DNA'sıdır. Diğer skill'ler (sql-kod-inceleme, sql-refactor) bu kurallara dayanır; çelişki halinde bu skill kazanır.

### 3.1 Tarih literal: DMY zorunluluğu (yerel ortam)

```sql
-- DOGRU: DMY format (Fikri'nin kalici tercihi, yerel ortam)
WHERE tarih >= CONVERT(datetime, '01.01.2025', 104)
WHERE tarih BETWEEN '01.01.2025' AND '31.12.2025'  -- 104 style implicit
SET @baslangic = CONVERT(date, '15.03.2026', 104)

-- YANLIS: ISO format kullanma (DATEFORMAT'a duyarli, sessiz hata uretir)
WHERE tarih >= '2025-01-01'
SET @baslangic = '2026-03-15'
```

CONVERT style referansı:
- `103` -> dd/MM/yyyy
- `104` -> dd.MM.yyyy (tercih edilen)
- `105` -> dd-MM-yyyy

Tarih literal'lerin yanına `-- DMY` etiketi yazmak okunabilirlik için tavsiye.

### 3.2 Linked server ODAKJOKER: ISO zorunluluğu

ODAKJOKER üzerinden sorgu yazılırken DMY KULLANILMAZ. ISO (YYYYMMDD) tek geçerli format:

```sql
-- ODAKJOKER icin DOGRU
SELECT ... FROM ODAKJOKER.JOKER.J_ORDERS
WHERE TARIH >= '20260101' AND TARIH < '20260201';

-- ODAKJOKER icin YANLIS (DMY)
WHERE TARIH >= '01.01.2026'  -- linked server bunu kabul etmez
```

Cross-server sorgularda iki tarafın tarih formatı ayrı doğrulanır. Varsayım yapılmaz.

### 3.3 Collation

- Cross-DB string join'lerde collation çakışması sessiz hata yaratır.
- Türkçe karakter eşleştirmesi: COLLATE Turkish_CI_AS standart.
- ODAKJOKER ile EncoreMerkez join'i: collation explicit belirtilir.

```sql
-- Cross-DB join'de COLLATE explicit
ON a.musteri_adi COLLATE Turkish_CI_AS = b.musteri_adi COLLATE Turkish_CI_AS
```

### 3.4 Compatibility level

EncoreMerkez compat 110 limiti:
- STRING_AGG YOK -> STUFF + FOR XML PATH
- TRIM YOK -> LTRIM(RTRIM(...))
- IIF YOK -> CASE WHEN
- TRY_CONVERT YOK -> CONVERT + ISDATE/ISNUMERIC
- THROW kullanılabilir (compat 110'da var) ama RAISERROR fallback'i bilinmeli

Compat level varsayım yapılmaz; `sys.databases.compatibility_level` doğrulanır.

### 3.5 Veri tipleri: Para = DECIMAL

```sql
-- DOGRU: parasal degerler DECIMAL(18,4)
DECLARE @tutar DECIMAL(18,4);
fiyat DECIMAL(18,4)

-- YASAK: FLOAT ile para (kayan nokta hatasi, kuruslar kaybolur)
DECLARE @tutar FLOAT;
fiyat REAL
```

DECIMAL(18,4) standart. Hassasiyet yetmiyorsa (kripto, mikro birim fiyat) DECIMAL(28,8). MONEY/SMALLMONEY de kabul edilebilir ama yeni kodda DECIMAL tercih.

### 3.6 src.\* dokunulmazlık

```
src.[ANYTHING] -> SADECE OKU
              -> DEGISTIRME
              -> CREATE OR ALTER yazma
              -> DROP yazma
```

DerinSIS ERP'nin SQL katmanına bağlı. Tablo yapısı DerinSIS tarafında değişebilir; view bu değişikliği absorbe etmek için var. Değiştirmek = DerinSIS güncellemesinde sistem patlaması. Üstüne yeni view yaz (örn. `argus.MagazaSatislari` -> `src.SatisOzet`'i çağırır).

### 3.7 Soft-delete ve filtre defaultları

Her sorgu yazılırken kontrol edilir:
- `IsValid = 1` (BKM standart)
- `IsDeleted = 0` (alternatif isim)
- `IsActive = 1` (alternatif isim)
- `DocumentsTypeId IN (...)` (belge tipi filtresi)

Tablo bazında hangisinin geçerli olduğu önceden doğrulanır. Filtre atlanırsa silinmiş kayıt agregaya girer.

#### BKM tablolari — 19.08.2026'da `sys.columns` ile dogrulandi

Bu tablo varsayim degil olcumdur. Sema degisirse yeniden dogrulanir.

| Tablo | Soft-delete kolonu | Ne yapilir |
|---|---|---|
| `EncoreMerkez.dbo.Sales` | **YOK** | Filtre uygulanamaz. Elek: `DocumentsTypeId`. Tam iptaller `CancelledSales`'te |
| `EncoreMerkez.dbo.SalesProducts` | `IsValid` **VAR** | `IsValid = 1` zorunlu; `BarcodeNo='1001'` eleme join'inde de |
| `ODAKJOKER..J_ORDERS` | **YOK** | Iptal/iade: `STATUS NOT IN (1006, 1007)` |
| `DerinSISBkm.bkm.MusteriSayi` | **YOK** | Kapi sayaci; filtre gerekmez. Yalniz `MekanId = 1` (FSM) besleniyor |

`Sales` tablosuna `IsValid = 1` yazmak "Invalid column name" hatasi verir. Eski
sablonlarda bu satir vardi; kaldirildi.

---

## 4. Genel Yazım Tercihi

- Alias'lar Türkçe ve anlamlı: `urun_kodu`, `toplam_tutar`, `stok_miktari`
- Tablo adları büyük harf (legacy ERP): `STOK_HAREKETLERI`, `SATIS_FATURA_DETAY`
- Yeni tablolar PascalCase ya da snake_case (proje konvansiyonu): `MagazaSatislari` veya `magaza_satislari`
- CTE ile okunabilir yapı, alt sorgu yerine tercih
- Uzun sorgularda blok yorumlar
- Stored proc başında parametre + versiyon bloğu
- SELECT * YASAK; explicit kolon listesi
- Tüm join'lerde explicit alias

---

## 5. Stored Procedure Şablonu (Kanonik)

```sql
CREATE OR ALTER PROCEDURE dbo.usp_StokRaporu
    @BaslangicTarihi  DATE,
    @BitisTarihi      DATE,
    @DepoKodu         VARCHAR(10) = NULL   -- NULL = tum depolar
AS
/*
    Amac     : Tarih araligina gore stok hareket raporu
    Versiyon : 1.0 | 15.03.2026 | Fikri
    Degisiklik: -
    Bagimliligi : URUNLER, STOK_HAREKETLERI
    Cagiran : raporlama servisi (web), gunluk job
*/
SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;  -- raporlama icin

BEGIN TRY
    -- Validasyon
    IF @BaslangicTarihi > @BitisTarihi
        THROW 50001, 'Baslangic tarihi bitis tarihinden buyuk olamaz.', 1;

    -- Ana sorgu
    WITH HareketlerCTE AS (
        SELECT
            sh.urun_kodu,
            u.urun_adi,
            sh.depo_kodu,
            SUM(CASE WHEN sh.hareket_tipi = 'G' THEN sh.miktar ELSE 0 END) AS giris_miktar,
            SUM(CASE WHEN sh.hareket_tipi = 'C' THEN sh.miktar ELSE 0 END) AS cikis_miktar
        FROM dbo.STOK_HAREKETLERI sh
        INNER JOIN dbo.URUNLER u ON u.urun_kodu = sh.urun_kodu
        WHERE sh.hareket_tarihi BETWEEN @BaslangicTarihi AND @BitisTarihi   -- DMY
          AND sh.IsValid = 1
          AND (@DepoKodu IS NULL OR sh.depo_kodu = @DepoKodu)
        GROUP BY sh.urun_kodu, u.urun_adi, sh.depo_kodu
    )
    SELECT
        urun_kodu,
        urun_adi,
        depo_kodu,
        giris_miktar,
        cikis_miktar,
        (giris_miktar - cikis_miktar) AS net_hareket
    FROM HareketlerCTE
    ORDER BY urun_kodu;
END TRY
BEGIN CATCH
    DECLARE @Hata NVARCHAR(500) = ERROR_MESSAGE();
    THROW;
END CATCH
GO
```

Yapısal kurallar:
- `CREATE OR ALTER` (PROC versiyonu net yönetilir)
- Header yorumu zorunlu (amaç, versiyon, değişiklik, bağımlılık, çağıran)
- `SET NOCOUNT ON` her zaman
- Raporlama: `READ UNCOMMITTED`; yazım: `READ COMMITTED` veya üstü
- Validasyon önce, sorgu sonra
- TRY/CATCH zorunlu, CATCH'te THROW (RAISERROR sadece compat 110 fallback'i)

---

## 6. FIFO Maliyetleme

### 6.1 Klasik FIFO stok maliyet sorgusu

```sql
-- FIFO: En eski giristen baslayarak tuket
-- Katman bazli FIFO hesaplama
WITH FifoKatmanlar AS (
    SELECT
        urun_kodu,
        giris_tarihi,
        lot_no,
        miktar                                               AS giris_miktar,
        birim_maliyet,
        SUM(miktar) OVER (
            PARTITION BY urun_kodu
            ORDER BY giris_tarihi, giris_id
            ROWS UNBOUNDED PRECEDING
        )                                                    AS kumulatif_giris
    FROM dbo.STOK_GIRISLERI
    WHERE urun_kodu = @UrunKodu
      AND IsValid = 1
),
ToplamCikis AS (
    SELECT urun_kodu, SUM(miktar) AS toplam_cikis
    FROM dbo.STOK_CIKISLARI
    WHERE urun_kodu = @UrunKodu
      AND IsValid = 1
    GROUP BY urun_kodu
),
KalanKatmanlar AS (
    SELECT
        f.urun_kodu,
        f.lot_no,
        f.birim_maliyet,
        -- Katmandan ne kadar kaldi?
        CASE
            WHEN f.kumulatif_giris <= tc.toplam_cikis
                THEN 0  -- Bu katman tamamen tuketilmis
            WHEN (f.kumulatif_giris - f.giris_miktar) >= tc.toplam_cikis
                THEN f.giris_miktar  -- Bu katmana hic dokunulmamis
            ELSE
                f.kumulatif_giris - tc.toplam_cikis  -- Kismen tuketilmis
        END AS kalan_miktar
    FROM FifoKatmanlar f
    CROSS JOIN ToplamCikis tc
    WHERE f.urun_kodu = tc.urun_kodu
)
SELECT
    urun_kodu,
    SUM(kalan_miktar)                                        AS toplam_stok,
    SUM(kalan_miktar * birim_maliyet)                        AS toplam_maliyet,
    CASE
        WHEN SUM(kalan_miktar) > 0
        THEN SUM(kalan_miktar * birim_maliyet) / SUM(kalan_miktar)
        ELSE 0
    END                                                      AS agirlikli_ort_maliyet
FROM KalanKatmanlar
WHERE kalan_miktar > 0
GROUP BY urun_kodu;
```

### 6.2 FIFO bağlam uyarısı

FIFO maliyet hesabı veriye ve mevzuata duyarlıdır:
- **Lot bazlı izlenebilirlik şart**: lot yoksa FIFO yapay olur
- **İade akışı**: iade lot'a geri döner mi, yeni katman mı olur (mevzuat: VUK 274)
- **Fire/hurda**: ayrı hareket tipi mi, yoksa toplam stok azalması mı (Belinza cam kırılması case)
- **Dönem kapanışı**: kapalı dönemde lot maliyeti değişmemeli; period lock disiplini şart

Finansal etkisi olan FIFO sorgusunda finans-butce-muhasebe skill'i eş tetiklenir.

---

## 7. ERP Veri Modeli Sorguları

### 7.1 Sipariş, Üretim, Sevkiyat zinciri

```sql
-- Siparis bazinda uretim ve sevkiyat durumu
SELECT
    so.siparis_no,
    so.musteri_kodu,
    m.musteri_adi,
    so.siparis_tarihi,
    so.termin_tarihi,
    sd.urun_kodu,
    sd.siparis_miktar,
    ISNULL(ie.uretilen_miktar, 0)    AS uretilen_miktar,
    ISNULL(sv.sevk_miktar, 0)        AS sevk_miktar,
    sd.siparis_miktar
        - ISNULL(sv.sevk_miktar, 0)  AS kalan_miktar,
    CASE
        WHEN ISNULL(sv.sevk_miktar,0) >= sd.siparis_miktar THEN 'Tamamlandi'
        WHEN ISNULL(ie.uretilen_miktar,0) > 0              THEN 'Uretimde'
        WHEN so.termin_tarihi < GETDATE()                  THEN 'GECIKIYOR'
        ELSE 'Bekliyor'
    END                              AS durum
FROM dbo.SATIS_SIPARISLERI so
INNER JOIN dbo.SATIS_SIPARIS_DETAY sd ON sd.siparis_no = so.siparis_no
INNER JOIN dbo.MUSTERILER m            ON m.musteri_kodu = so.musteri_kodu
LEFT JOIN (
    SELECT siparis_no, urun_kodu, SUM(uretilen_miktar) AS uretilen_miktar
    FROM dbo.IS_EMIRLERI
    WHERE IsValid = 1
    GROUP BY siparis_no, urun_kodu
) ie ON ie.siparis_no = so.siparis_no AND ie.urun_kodu = sd.urun_kodu
LEFT JOIN (
    SELECT siparis_no, urun_kodu, SUM(miktar) AS sevk_miktar
    FROM dbo.SEVKIYAT_DETAY
    WHERE IsValid = 1
    GROUP BY siparis_no, urun_kodu
) sv ON sv.siparis_no = so.siparis_no AND sv.urun_kodu = sd.urun_kodu
WHERE so.durum != 'Iptal'
  AND so.IsValid = 1
ORDER BY so.termin_tarihi;
```

### 7.2 BKM Encore Sales analiz pattern'i

> **Duzeltildi 19.08.2026.** Onceki surumdeki sablon calismiyordu: kolon adlari
> semayla uyusmuyor ve net hesabi iskontoyu iki kez dusuyordu. Asagidaki surum
> canli veriyle dogrulandi (17.08.2026, uc magaza, satir-baslik mutabakati tam).

```sql
-- BKM EncoreMerkez Sales: brut + iskonto + net + line count drift
-- Dogrulandi: toplam_net = satir_net_kontrol (kurusu kurusuna, 17.08.2026)
WITH SalesAgg AS (
    SELECT
        s.Id                              AS SalesId,
        s.Date,
        s.StoresId,
        s.GrossTotal,
        s.DiscountTotal,
        s.LineCount                       AS reported_line_count,
        COUNT(sp.Id)                      AS actual_line_count,
        SUM(sp.TotalPrice)                AS satir_net
    FROM EncoreMerkez.dbo.Sales s WITH (NOLOCK)
    INNER JOIN EncoreMerkez.dbo.SalesProducts sp WITH (NOLOCK)
        ON sp.SalesId = s.Id
       AND sp.IsValid = 1                 -- satirda soft-delete VAR
    WHERE s.Date >= CONVERT(date, '01.08.2026', 104)   -- DMY
      AND s.Date <  CONVERT(date, '01.09.2026', 104)
      AND s.DocumentsTypeId IN (1, 2)     -- 1=fis, 2=fatura
    GROUP BY s.Id, s.Date, s.StoresId, s.GrossTotal, s.DiscountTotal, s.LineCount
)
SELECT
    StoresId,
    COUNT(*)                                        AS belge_sayisi,
    SUM(GrossTotal)                                 AS toplam_brut,
    SUM(DiscountTotal)                              AS toplam_iskonto,
    SUM(GrossTotal - DiscountTotal)                 AS toplam_net,
    SUM(satir_net)                                  AS satir_net_kontrol,
    SUM(CASE WHEN reported_line_count <> actual_line_count THEN 1 ELSE 0 END)
                                                    AS line_count_drift
FROM SalesAgg
GROUP BY StoresId
ORDER BY toplam_net DESC;
```

#### Kolon adlari — semadan dogrulanmis

Onceki surumde kullanilan adlarin cogu `EncoreMerkez` semasinda yok. `sys.columns`
ile dogrulanan karsiliklar:

| Eski surumde yazan | Gercek kolon | Not |
|---|---|---|
| `s.SalesId` | `s.Id` | `SalesProducts.SalesId` buna baglanir |
| `s.DocumentDate` | `s.Date` | |
| `s.mekanID` | `s.StoresId` | 1=Ist.Yolu, 2=FSM, 3=Ozluce |
| `s.IsValid` | **YOK** | `Sales` tablosunda soft-delete kolonu hic yok |
| `sp.SalesProductId` | `sp.Id` | |
| `sp.QuantitySold` | `sp.Amount` | miktar |
| `sp.UnitPriceGross` | **YOK** | birim brut fiyat kolonu yok; satir toplami `sp.TotalPrice` |

#### TUZAK: `TotalPrice` zaten net — iskontoyu iki kez dusme

`SalesProducts.TotalPrice` **iskonto dusulmus** satir tutaridir. Uzerine bir daha
`DiscountTotalDirect` cikarilirsa iskonto iki kez sayilir ve ciro oldugundan dusuk
raporlanir. 17.08.2026 olcumu:

| Olcum | Tutar |
|---|---|
| `SUM(s.GrossTotal)` | 4.435.364,30 |
| `SUM(s.DiscountTotal)` | 664.137,36 |
| `SUM(s.GrossTotal - s.DiscountTotal)` | **3.771.226,94** |
| `SUM(sp.TotalPrice)` | **3.771.226,94** — ayni |
| `SUM(sp.DiscountTotalDirect)` | 593.075,91 |

Ikinci bir uyari: satir iskontosu (593.075,91) baslik iskontosundan (664.137,36)
**71.061,45 TL dusuk**. Aradaki fark satir bazinda degil belge bazinda uygulanan
iskonto. Bu yuzden:

- **Brut ve iskonto icin baslik otoritedir** (`Sales.GrossTotal`, `Sales.DiscountTotal`).
- **Net iki taraftan da ayni cikar**; satir tarafi (`SUM(sp.TotalPrice)`) mutabakat
  kontrolu olarak kullanilir.
- Urun/kategori kirilimi gerektiginde satir tarafi kullanilir, ama toplam ciro
  baslikla dogrulanir.

#### Belge tipi filtresi

`DocumentsTypeId` degerleri: `1`=Fis, `2`=Fatura, `3`=Iade, `4`=Iade-Degisim,
`6`/`7`=Personel, `8`=Sinav Okullari (toplu okul siparisi).

- Perakende ciro: `IN (1, 2)`.
- Iade isaretli (negatif) dahil edilecekse `3` eklenir ve `CASE WHEN
  DocumentsTypeId = 3 THEN -1 ELSE 1 END` carpani uygulanir.
- `8` (Sinav Okullari) tek fiste cok buyuk tutar tasir ve Agustos-Eylul sezonunda
  toplami domine eder. Rapora dahil edilecekse **tutari ayrica belirtilir**, yoksa
  "ciro %47 artti" gibi yaniltici bir basliga yol acar.

#### Tam iptal edilen fisler

Tamamen iptal edilen fisler `Sales`'te **yer almaz**, ayri `dbo.CancelledSales`
tablosunda tutulur. Yani `Sales` tek basina "net gerceklesmis islem" verir. Iptal
orani metrigi isteniyorsa o tablo ayrica sorgulanir.

#### Geri donusum fisleri

`SalesProducts.BarcodeNo = '1001'` geri donusum kagidi hareketidir, ciro degil.
Pazartesi brifingi bunlari dislar; ayni disi burada da uygulanir:

```sql
LEFT JOIN EncoreMerkez.dbo.SalesProducts spb WITH (NOLOCK)
       ON spb.SalesId = s.Id AND spb.BarcodeNo = '1001' AND spb.IsValid = 1
...
WHERE spb.Id IS NULL
```

`IsValid = 1` bu join'de de zorunlu — atlandiginda gecersiz isaretli bir `1001`
satiri yuzunden gecerli bir fis haksiz yere ciro disinda kalir (17.08 olcumunde
etkisi 0 TL, 10.08 haftasinda 1 fis / 1 TL).

### 7.3 ODAKJOKER e-ticaret pattern'i (linked server, ISO tarih)

```sql
-- JOKER: e-ticaret siparis dagimi (ISO tarih zorunlu)
SELECT
    jo.APPLICATION,
    COUNT(*)                                AS siparis_sayisi,
    SUM(jo.NETTOTAL)                        AS toplam_net,
    SUM(CASE WHEN jo.CUSTOMERREF = 0 OR jo.CUSTOMERREF IS NULL THEN 1 ELSE 0 END)
                                            AS misafir_siparis
FROM ODAKJOKER.JOKER.dbo.J_ORDERS jo
WHERE jo.ORDERDATE >= '20260101'           -- ISO! ODAKJOKER linked server
  AND jo.ORDERDATE <  '20260201'
GROUP BY jo.APPLICATION
ORDER BY siparis_sayisi DESC;

-- Beklenen APPLICATION seti:
-- 'Mobil Uygulama (Android)', 'Mobil Uygulama (iOS)', 'Mobil Site', 'Web Sitesi'
-- Bunlar disinda deger = kanal sapmasi (veri-yorumlama skill'i tetiklenir)
```

---

## 8. Transaction Yönetimi

```sql
-- Stok transferi: atomik islem
BEGIN TRY
    SET XACT_ABORT ON;
    BEGIN TRANSACTION;

    -- Kaynak depoda stok azalt
    UPDATE dbo.STOK_BAKIYE
    SET miktar = miktar - @TransferMiktar,
        guncelleme_tarihi = GETDATE(),
        guncelleme_kullanici = @KullaniciKodu
    WHERE urun_kodu = @UrunKodu
      AND depo_kodu  = @KaynakDepo
      AND lot_no     = @LotNo;

    IF @@ROWCOUNT = 0
        THROW 50010, 'Kaynak depoda stok bulunamadi.', 1;

    -- Negatif stok kontrolu
    IF EXISTS (
        SELECT 1 FROM dbo.STOK_BAKIYE
        WHERE urun_kodu = @UrunKodu
          AND depo_kodu = @KaynakDepo
          AND miktar < 0
    )
        THROW 50011, 'Stok yetersiz, negatif stoka dusuluyor.', 1;

    -- Hedef depoda stok artir
    MERGE dbo.STOK_BAKIYE AS hedef
    USING (SELECT @UrunKodu AS urun_kodu, @HedefDepo AS depo_kodu, @LotNo AS lot_no) AS kaynak
    ON hedef.urun_kodu = kaynak.urun_kodu
       AND hedef.depo_kodu = kaynak.depo_kodu
       AND hedef.lot_no = kaynak.lot_no
    WHEN MATCHED THEN
        UPDATE SET miktar = miktar + @TransferMiktar
    WHEN NOT MATCHED THEN
        INSERT (urun_kodu, depo_kodu, lot_no, miktar)
        VALUES (@UrunKodu, @HedefDepo, @LotNo, @TransferMiktar);

    -- Hareket logu
    INSERT INTO dbo.STOK_HAREKETLERI
        (urun_kodu, lot_no, kaynak_depo, hedef_depo, miktar,
         hareket_tipi, hareket_tarihi, kullanici)
    VALUES
        (@UrunKodu, @LotNo, @KaynakDepo, @HedefDepo, @TransferMiktar,
         'T', GETDATE(), @KullaniciKodu);

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH
```

Transaction kuralları:
- `SET XACT_ABORT ON` her atomik işlemde
- `@@ROWCOUNT` kontrolü her UPDATE/DELETE sonrası
- `THROW` (RAISERROR sadece compat 110 fallback'i)
- CATCH'te `@@TRANCOUNT > 0` ile ROLLBACK
- Nested transaction varsa savepoint kullanılır
- Log/audit insert'i transaction içinde (atomik) ya da dışında (bağımsız tutmak için) bilinçli karar

---

## 9. Index ve Performans

```sql
-- ERP sorgularinda sik kullanilan index stratejisi
-- Stok hareketleri: tarih + urun bazli sorgular icin
CREATE NONCLUSTERED INDEX IX_StokHareketleri_Tarih_Urun
ON dbo.STOK_HAREKETLERI (hareket_tarihi, urun_kodu)
INCLUDE (depo_kodu, miktar, hareket_tipi, IsValid);

-- Siparis detay: siparis + urun join icin
CREATE NONCLUSTERED INDEX IX_SiparisDetay_SiparisUrun
ON dbo.SATIS_SIPARIS_DETAY (siparis_no, urun_kodu)
INCLUDE (siparis_miktar, birim_fiyat);

-- Performans kontrolu: top yavas sorgular
SELECT TOP 20
    qs.total_elapsed_time / qs.execution_count  AS ort_sure_ms,
    qs.execution_count,
    qs.total_logical_reads / qs.execution_count AS ort_logical_reads,
    SUBSTRING(qt.text, 1, 200)                  AS sorgu_ozet
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) qt
ORDER BY ort_sure_ms DESC;
```

Index kuralları:
- Filtre kolonları index'in başında, INCLUDE'a SELECT kolonları
- Soft-delete kolonu (IsValid) genelde INCLUDE'da
- Çok seçici olmayan kolonu index başına koymak scan yaratır
- Composite index sırası: en seçici ilk değil; sorgu predicate sırasıyla hizalı
- `OPTION (RECOMPILE)` parameter sniffing problemine son çare; her sorguya değil

---

## 10. Audit / Log Tablosu Şablonu

```sql
-- Her kritik tablonun yaninda audit tablosu
CREATE TABLE dbo.STOK_BAKIYE_AUDIT (
    audit_id        BIGINT IDENTITY(1,1) PRIMARY KEY,
    islem_tipi      CHAR(1)       NOT NULL,  -- I=Insert, U=Update, D=Delete
    islem_tarihi    DATETIME2     NOT NULL DEFAULT GETDATE(),
    kullanici       NVARCHAR(50)  NOT NULL,
    urun_kodu       VARCHAR(30),
    depo_kodu       VARCHAR(10),
    eski_miktar     DECIMAL(18,4),
    yeni_miktar     DECIMAL(18,4),
    aciklama        NVARCHAR(500)
);

-- Trigger ile otomatik doldur
CREATE OR ALTER TRIGGER trg_StokBakiye_Audit
ON dbo.STOK_BAKIYE
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @kullanici NVARCHAR(50) = SYSTEM_USER;

    -- UPDATE
    IF EXISTS(SELECT 1 FROM inserted) AND EXISTS(SELECT 1 FROM deleted)
    INSERT INTO dbo.STOK_BAKIYE_AUDIT
        (islem_tipi, kullanici, urun_kodu, depo_kodu, eski_miktar, yeni_miktar)
    SELECT 'U', @kullanici, i.urun_kodu, i.depo_kodu, d.miktar, i.miktar
    FROM inserted i
    INNER JOIN deleted d
        ON d.urun_kodu = i.urun_kodu
       AND d.depo_kodu = i.depo_kodu;

    -- INSERT
    IF EXISTS(SELECT 1 FROM inserted) AND NOT EXISTS(SELECT 1 FROM deleted)
    INSERT INTO dbo.STOK_BAKIYE_AUDIT
        (islem_tipi, kullanici, urun_kodu, depo_kodu, eski_miktar, yeni_miktar)
    SELECT 'I', @kullanici, i.urun_kodu, i.depo_kodu, NULL, i.miktar
    FROM inserted i;

    -- DELETE
    IF NOT EXISTS(SELECT 1 FROM inserted) AND EXISTS(SELECT 1 FROM deleted)
    INSERT INTO dbo.STOK_BAKIYE_AUDIT
        (islem_tipi, kullanici, urun_kodu, depo_kodu, eski_miktar, yeni_miktar)
    SELECT 'D', @kullanici, d.urun_kodu, d.depo_kodu, d.miktar, NULL
    FROM deleted d;
END
```

Audit kuralları:
- Hard-delete yasak; tüm silme `IsValid = 0` (BKM dönem kapanışı / belge silme bulgusu hatırlatması)
- `kullanici = SYSTEM_USER` veya parametre olarak gelen kullanıcı bilgisi (kim hangisi bilinçli karar)
- Audit tablosuna tetik ile yazım atomik; ayrı transaction önerilmez (sıralama bozulur)
- Audit'i diğer veri sorgularına dahil etme; ayrı tablodur ve sadece denetim için var

---

## 11. Sık Kullanılan Snippet'ler

### 11.1 Dönemsel satış pivotu (ay bazlı)

```sql
SELECT
    urun_kodu, urun_adi,
    SUM(CASE WHEN MONTH(fatura_tarihi)=1  THEN tutar ELSE 0 END) AS Oca,
    SUM(CASE WHEN MONTH(fatura_tarihi)=2  THEN tutar ELSE 0 END) AS Sub,
    SUM(CASE WHEN MONTH(fatura_tarihi)=3  THEN tutar ELSE 0 END) AS Mar,
    SUM(CASE WHEN MONTH(fatura_tarihi)=4  THEN tutar ELSE 0 END) AS Nis,
    SUM(CASE WHEN MONTH(fatura_tarihi)=5  THEN tutar ELSE 0 END) AS May,
    SUM(CASE WHEN MONTH(fatura_tarihi)=6  THEN tutar ELSE 0 END) AS Haz,
    SUM(CASE WHEN MONTH(fatura_tarihi)=7  THEN tutar ELSE 0 END) AS Tem,
    SUM(CASE WHEN MONTH(fatura_tarihi)=8  THEN tutar ELSE 0 END) AS Agu,
    SUM(CASE WHEN MONTH(fatura_tarihi)=9  THEN tutar ELSE 0 END) AS Eyl,
    SUM(CASE WHEN MONTH(fatura_tarihi)=10 THEN tutar ELSE 0 END) AS Eki,
    SUM(CASE WHEN MONTH(fatura_tarihi)=11 THEN tutar ELSE 0 END) AS Kas,
    SUM(CASE WHEN MONTH(fatura_tarihi)=12 THEN tutar ELSE 0 END) AS Ara,
    SUM(tutar) AS Toplam
FROM dbo.FATURA_DETAY
WHERE fatura_tarihi >= CONVERT(date, '01.01.2026', 104)   -- DMY
  AND fatura_tarihi <  CONVERT(date, '01.01.2027', 104)
  AND IsValid = 1
GROUP BY urun_kodu, urun_adi
ORDER BY Toplam DESC;
```

Not: Şubat 28/29 gün; aylık trend grafiğinde günlük ortalamaya normalize etmek tavsiye (veri-yorumlama skill 5.4'e bak).

### 11.2 N gündür hareketsiz stok

```sql
SELECT
    sb.urun_kodu, sb.depo_kodu, sb.miktar,
    MAX(sh.hareket_tarihi)                                  AS son_hareket,
    DATEDIFF(day, MAX(sh.hareket_tarihi), GETDATE())        AS hareketsiz_gun
FROM dbo.STOK_BAKIYE sb
LEFT JOIN dbo.STOK_HAREKETLERI sh
    ON sh.urun_kodu = sb.urun_kodu
   AND sh.depo_kodu = sb.depo_kodu
   AND sh.IsValid = 1
WHERE sb.miktar > 0
  AND sb.IsValid = 1
GROUP BY sb.urun_kodu, sb.depo_kodu, sb.miktar
HAVING DATEDIFF(day, MAX(sh.hareket_tarihi), GETDATE()) > 90
ORDER BY hareketsiz_gun DESC;
```

### 11.3 Period lock kontrolü (BKM ay kapanışı sonrası fiş)

> **Duzeltildi 19.08.2026.** Onceki surumdeki sorgu alti farkli var olmayan kolona
> bakiyordu (`s.DocumentDate`, `s.UpdateDate`, `s.UpdateUserId`, `fak.Yil`,
> `fak.Ay`, `fak.KapanmaTarihi`) ve hicbir sey donmuyordu. Asagidaki surum canli
> veriyle dogrulandi ve gercek bir ihlal buldu.

**Once bunu bil: `EncoreMerkez.dbo.Sales` tablosunda `UpdateDate` YOK.** Mevcut
tarih kolonlari yalnizca `Date` (belge tarihi), `CreateDate` (kayit tarihi) ve
`StartDate`. Yani **bir fisin kapanistan sonra DEGISTIRILDIGI bu tablodan
anlasilamaz** — sadece kapanistan sonra OLUSTURULDUGU anlasilir. Gercek mutasyon
takibi icin §10'daki audit trigger deseni ya da temporal table / CDC gerekir; bu
eksik acikca not edilir, "kontrol ettim temiz" denmez.

**Kanonik yol: hazir SP'ler.** Bu kontrol icin `DerinSISBkm` icinde uc stored
procedure zaten var; elle sorgu yazmak yerine bunlar kullanilir:

| SP | Kapsam |
|---|---|
| `bkm.sp_AyKapanisSonrasiEvrakKontrol` | Kapanis sonrasi evrak taramasi |
| `bkm.sp_AylikKapanisSonrasiMudahaleKontrol` | Aylik mudahale kontrolu |
| `bkm.sp_KapanisMudahaleKontrol_v2` | Guncel surum |

Yeni bir kontrol sorgusu yazmadan once bu SP'lerin kaynagi okunur; ayni isi ikinci
kez ve daha kotu yapmanin anlami yok.

**Tablo seviyesinde tek sinyal** (SP'lerin yetmedigi durumda):

```sql
-- Kapanistan SONRA sisteme girilen, kapali doneme tarihli fisler
-- `bkm.Fin_AyKapanis` kolonlari: DonemYil, DonemAy, KapanisDT, KapanisKisi
SELECT TOP 100
    s.Id                                        AS SalesId,
    s.Date                                      AS belge_tarihi,
    s.CreateDate                                AS kayit_tarihi,
    s.UsersId                                   AS kaydeden_kullanici,
    fak.KapanisDT                               AS donem_kapanis,
    DATEDIFF(day, fak.KapanisDT, s.CreateDate)  AS kapanis_sonrasi_gun
FROM EncoreMerkez.dbo.Sales s WITH (NOLOCK)
INNER JOIN DerinSISBkm.bkm.Fin_AyKapanis fak
    ON fak.DonemYil = YEAR(s.Date)
   AND fak.DonemAy  = MONTH(s.Date)
WHERE s.CreateDate > fak.KapanisDT
ORDER BY s.CreateDate DESC;
```

19.08.2026 koşumunda bir kayit dondu: `SalesId 618732`, belge tarihi
**29.12.2025**, sisteme giris **18.01.2026** — Aralik donemi 13.01.2026'da
kapatilmisti, yani kapanistan 5 gun sonra kapali doneme fis girilmis. Bu bulgu
`turkiye-vergi-mevzuati` (period lock / post-close mutasyon) ve
`finans-butce-muhasebe` (donem kapanisi) skill'lerini tetikler.

---

## 12. Confidence / Bağlam Disiplini

Şablon "her durumda doğru" diye sunulmaz. Bağlam koşulları yazılı olur:

| Şablon | Bağlam koşulu |
|---|---|
| FIFO sorgusu | Lot bazlı izlenebilirlik mevcut, IsValid filtresi geçerli |
| Stok transfer SP | SET XACT_ABORT ON, deadlock retry stratejisi belirlendi |
| ODAKJOKER sorgu | ISO tarih, kanal seti tanımlı (`APPLICATION` valid set) |
| EncoreMerkez sorgu | Compat 110, STRING_AGG yok, IsValid + DocumentsTypeId filtre |
| Audit trigger | Hard-delete yasak; IsValid = 0 standardı |
| Index önerisi | Predicate sırası ile hizalı; sorgu plan'i ölçülerek doğrulandı |

> Bağlam koşulu doğrulanmadan şablon prod'a uygulanmaz. "Bu pattern Stack Overflow'da gördüm" yetmez; runtime kurallarına uyum şart.

---

## 13. Final Behavior Rule

Review aracı veya refactor aracı GİBİ DAVRANMA.

Şu rollerden gibi davran:
- T-SQL knowledge base
- runtime kural otoritesi
- şablon kütüphanesi
- ERP veri modeli pattern sahibi

**Birincil hedef:**
> Doğru, runtime-uyumlu, ERP bağlamına oturmuş T-SQL üretmek.
> Diğer SQL skill'leri (kod-inceleme, refactor) runtime kurallar için bu skill'e başvurur.

---

## 14. Skill Chain (Diğer skill'lerle ilişki)

| Birlikte tetikle | Ne zaman |
|---|---|
| **sql-kod-inceleme** | Bu skill üretti, o skill review eder; runtime kuralları bu skill'den gelir |
| **sql-refactor** | Mevcut kodu temizler; bu skill'in şablonlarına hizalanır, runtime kurallarına uyar |
| **veri-yorumlama** | Sorgu çıktısı yorumlanırken; bu skill veri çekme katmanı, o skill yorum katmanı |
| **finans-butce-muhasebe** | FIFO, KDV, dönem kapanışı sorgusu yazılırken finansal mantık temeli oradan |
| **bi-dashboard** | Metabase/Power BI dashboard için raporlama view/SP üretiminde |
| **belinza-baglan** | Belinza/BelOps veri modeli kuralları, ürün grupları |
| **yonetiq-platform** | YönetIQ Dapper sorgusu, MCP SQL Server tool şeması |
| **erp-crm-wms-mimari** | ERP/WMS mimari kararı veri modeli sorularına çıkıyorsa |
| **kok-sebep** | Aynı SQL pattern'i tekrar tekrar yanlış uygulanıyorsa "neden böyle" zinciri |
| **risk-tarama** | Yeni SP/migration prod'a çıkmadan risk değerlendirmesi |

**Override kuralı:**
- Bu skill'in runtime kuralları (DMY, COLLATE, compat 110, FLOAT yasağı, src.\* dokunulmaz) diğer hiçbir skill tarafından override edilemez. sql-kod-inceleme, sql-refactor ve veri-yorumlama bu kurallara dayanır; çelişki halinde bu skill kazanır.
- Bu skill review veya refactor üretmez; o işler ilgili skill'lere devredilir.
- veri-yorumlama ile zincirleme: sorgu yazımı bu skill'de, sonuç yorumu orada; iki katman ayrı.
- finans-butce-muhasebe ile zincirleme: finansal hesap mantığı (FIFO, KDV, dönem) o skill'de; T-SQL implementasyonu bu skill'de. Hesap mantığı çelişiyorsa o skill kazanır.
