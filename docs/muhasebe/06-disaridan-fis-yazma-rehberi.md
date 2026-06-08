# Dışarıdan DerinSIS'e Muhasebe Fişi Nasıl Yazılır?

> **Hedef:** DerinSIS UI'sına dokunmadan, kendi script / entegrasyon /
> servisinden `mhs.mhsFisBaslik` + `mhs.mhsFis`'e güvenli fiş kaydı.
> **Veritabanı:** `DerinSISBkm`
> **Kullanılan SP'ler:** [`03-mhs-CRUD-sp-kaynak.sql`](./03-mhs-CRUD-sp-kaynak.sql)

---

## 1. Tek Bakışta Akış

```
┌─────────────────────────────────────────────────────────┐
│ HAZIRLIK                                                 │
│  1. Hangi şirket? (mhsSirket — her yıl ayrı, BKM'de 6)   │
│  2. Sıralama tarihi geçilmedi mi? (kapanmış dönem koruma)│
│  3. Hangi hesaplar? (hspKod → hspID lookup, per-şirket)  │
│  4. Hangi entegrasyon tipi? (entTip=0 Kullanıcı önerilir)│
└─────────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────┐
│ TRANSACTION (kendi tarafında!)                           │
│  5. EXEC mhs.mhsSonYevmiyeNo @SirketID  → @yevmiyeNo     │
│  6. EXEC mhs.mhsFisB_ekle @ID=0, ...    → @fisbID         │
│  7. for each mahsup satırı:                              │
│        EXEC mhs.mhsFis_ekle @FisBID=@fisbID, ...         │
│  8. Denge kontrol: SUM(fisTutar) WHERE fisID=@fisbID = 0 │
│  9. (Opsiyonel) EXEC mhs.mhsFis_onay  — default zaten 1  │
│  COMMIT  /  ROLLBACK                                      │
└─────────────────────────────────────────────────────────┘
```

---

## 2. BKM Şirket Tablosu (canlı)

| sirketID | Ad | Dönem | Sıralama Tarihi | Yazılabilir mi? |
|---:|---|---:|---|---|
| 1 | Bkm Kitap Kırtasiye | 2021 | 31.12.2021 | Evet ama tarih > 31.12.2021 olmalı |
| 2 | BKM Kitap Kırtasiye | 2022 | 31.12.2022 | Evet ama tarih > 31.12.2022 olmalı |
| 3 | BKM Kitap Kırtasiye | 2023 | 31.12.2023 | Evet ama tarih > 31.12.2023 olmalı |
| 4 | BKM Kitap Kırtasiye | 2024 | 31.12.2024 | Evet ama tarih > 31.12.2024 olmalı |
| 5 | BKM Kitap Kırtasiye | 2025 | 30.11.2025 | Evet ama tarih > 30.11.2025 olmalı |
| **6** | **BKM Kitap Kırtasiye** | **2026** | **31.12.2025** | **Aktif — 2026 fişleri için** |

→ Bugün (Mayıs 2026) için: **`@SirketID = 6`**, `@Tarih > 31.12.2025`.

---

## 3. Hesap Kodu → hspID Lookup

`mhsFis_ekle.@HspID` parametresi `mhsHsp.hspID` integer'ı. Hesap kodundan
elde edilir:

```sql
SELECT hspID
FROM   DerinSISBkm.mhs.mhsHsp
WHERE  hspSirketID = @SirketID    -- ŞART
  AND  hspKod      = @hspKod      -- örn '100.10.001'
```

**KRİTİK:** Aynı `hspKod` her şirket için **ayrı `hspID`** taşır
(composite PK). Yanlış şirketin hsp'sini geçersen FK hatası alırsın.

**Örnek (sirketID=6 için bilinen hspID'ler):**

| hspKod | hspAd | hspID (sirket=6) |
|---|---|---:|
| 100.10 | KASA (üst grup) | 23286 |
| 100.10.001 | Merkez TL.Kasa | 23285 |
| 101.10 | ALINAN TL.ÇEKLER | 23287 |

(Tam liste için yukarıdaki SELECT'i kullan.)

---

## 4. Adım Adım Çağrı Dizisi

### Adım 4.1 — Yevmiye no al (önerilen, zorunlu değil)

```sql
DECLARE @yevmiyeNo int
EXEC DerinSISBkm.mhs.mhsSonYevmiyeNo @SirketID = 6
-- Helper SELECT döner — output'u yakalamak için:
DECLARE @t TABLE (son int)
INSERT INTO @t EXEC DerinSISBkm.mhs.mhsSonYevmiyeNo @SirketID = 6
SELECT @yevmiyeNo = son FROM @t
```

> **Concurrency uyarısı:** `mhsSonYevmiyeNo` SELECT'tir, lock almaz. İki
> paralel çağrı aynı no'yu döndürebilir → INSERT noktasında duplicate
> riski. Tek-yazıcı bir entegrasyon servisinden çalıştırıyorsan (sıralı)
> sorun yok. Çoklu paralel yazıcı varsa kendi tarafında SERIALIZABLE
> transaction veya APPLOCK önerilir.

### Adım 4.2 — Master fiş başlığı ekle

```sql
DECLARE @fisbID int
DECLARE @ID int = 0   -- 0 = INSERT modu

DECLARE @ret TABLE (id int)
INSERT INTO @ret
EXEC DerinSISBkm.mhs.mhsFisB_ekle
       @ID         = @ID,
       @SirketID   = 6,                       -- aktif yıl
       @Ad         = 'Dış entegrasyon fişi',  -- başlık metni
       @YevmiyeNo  = @yevmiyeNo,
       @Tarih      = '11.05.2026',            -- DMY!
       @Tip        = 2,                       -- 2 = Mahsup (default seçim)
       @Grp        = 0,                       -- 0 = Genel (BKM'de tek değer)
       @EntTip     = 0,                       -- 0 = Kullanıcı (manuel/dış)
       @kKisi      = 999,                     -- senin servis kullanıcı ID'n
       @fiscID     = 0,                       -- ith bağı yok
       @kTarih     = NULL,                    -- INSERT'te kullanılmıyor
       @progAd     = 'EntApi'                 -- audit'e bu metin düşer

SELECT @fisbID = id FROM @ret
```

**Notlar:**
- `@EntTip = 0` (Kullanıcı) — dış entegrasyon için en uygun. Diğer
  entTip'ler (1=Fatura, 2=Cari, 3=POS) DerinSIS'in iç modülleri için.
  Yanlış entTip seçersen `mhsFis_sil` SP'si o davranışları tetikler
  (silme zincir reaksiyonu).
- `@progAd = 'EntApi'` — audit'te seni ayırt etmek için kendi servis
  kodunu yaz. drn2'ye `Prg=EntApi` yazılır.
- Default ile **fişiOnay = 1** geliyor. Onay istemiyorsan `mhsFis_onay`
  ile sonra düşür ya da doğrudan UPDATE.

### Adım 4.3 — Detay satırlarını ekle (Borç + Alacak çiftleri)

**KRİTİK SIGNED CONVENTION:**
- **Borç → `@Tutar = NEGATIF`**
- **Alacak → `@Tutar = POZİTİF`**
- Toplam **0** olmalı (denge).

```sql
-- Satır 1: Borç (örn. Kasaya giriş — 100.10.001)
EXEC DerinSISBkm.mhs.mhsFis_ekle
       @FisBID     = @fisbID,
       @SirketID   = 6,
       @YevmiyeNo  = @yevmiyeNo,
       @Tarih      = '11.05.2026',
       @Tip        = 2,
       @BA         = 0,                       -- 0 = Borç (UI bilgisi)
       @Tutar      = -1000.00,                -- NEGATİF = Borç!
       @EntID      = 0,                       -- entTip=0 için 0
       @HspID      = 23285,                   -- 100.10.001 (sirket=6)
       @Aciklama   = 'Kasaya nakit giriş',
       @gdrMerkez  = 0,
       @fisCari    = 0

-- Satır 2: Alacak (örn. Diğer Gelirler — 679.xx)
EXEC DerinSISBkm.mhs.mhsFis_ekle
       @FisBID     = @fisbID,
       @SirketID   = 6,
       @YevmiyeNo  = @yevmiyeNo,
       @Tarih      = '11.05.2026',
       @Tip        = 2,
       @BA         = 1,                       -- 1 = Alacak (UI bilgisi)
       @Tutar      = 1000.00,                 -- POZİTİF = Alacak!
       @EntID      = 0,
       @HspID      = ???,                     -- karşı hesap hspID'si
       @Aciklama   = 'Diğer gelir',
       @gdrMerkez  = 0,
       @fisCari    = 0
```

**Notlar:**
- N satır olabilir (mahsup tipi 2'den fazla satıra çıkabilir).
- Her satır için aynı `@FisBID`, `@SirketID`, `@YevmiyeNo`, `@Tarih`,
  `@Tip` (denormalize — master ile tutarlı tut).
- `@BA` UI'ın gösterdiği yön bilgisi; **gerçek hesaplama `@Tutar`'ın
  işaretinden** yapılıyor. İkisini tutarlı geç (`@BA=0` → tutar negatif,
  `@BA=1` → tutar pozitif).
- `@fisCari = 1` set edilirse satır cariyle ilişkili sayılır (rapor
  filtreleri etkilenir). Manuel mahsupta genellikle 0.
- `@gdrMerkez` — gider merkezi ID'si (cost center). Sıfır = genel.
- **Dövizli kayıt için bu SP yetmez** — `fisDvzID` ve `fisTutarDvz`
  parametreleri yok. Doğrudan INSERT veya başka SP gerek (henüz
  keşfedilmedi).

### Adım 4.4 — Denge kontrolü (zorunlu — SP yapmıyor)

```sql
DECLARE @denge decimal(15,2)
SELECT @denge = SUM(fisTutar)
FROM   DerinSISBkm.mhs.mhsFis
WHERE  fisID = @fisbID

IF @denge <> 0
BEGIN
    -- ROLLBACK yap, hata fırlat
    RAISERROR('Fiş dengeli değil. Net: %s', 16, 1, CAST(@denge AS varchar(20)))
    RETURN
END
```

**Bu kontrol DerinSIS SP'sinde YOK.** Dengesiz fiş eklenirse sistem
sessiz kalır, ama raporlar bozulur. Kendi tarafında yap.

### Adım 4.5 — (Opsiyonel) Onay

Default'ta `fisOnay=1` geliyor. Eğer onaysız bırakıp sonra UI'dan
onaylatacaksan:

```sql
EXEC DerinSISBkm.mhs.mhsFis_onay
       @fisID = @fisbID,
       @onay  = 0,         -- 0 = onay kaldır, 1 = onayla
       @oKisi = 999
```

---

## 5. Tam Çalışan Örnek (kopyala-çalıştır)

**Senaryo:** Kasaya 1.000 TL diğer gelir nakit girişi (sirket 2026, 11.05.2026).

```sql
USE DerinSISBkm
GO

BEGIN TRY
    BEGIN TRANSACTION

    -- Sabitler
    DECLARE @sirket  tinyint       = 6
    DECLARE @tarih   smalldatetime = '11.05.2026'   -- DMY
    DECLARE @tutar   decimal(15,2) = 1000.00
    DECLARE @kKisi   int           = 999
    DECLARE @progAd  varchar(10)   = 'EntApi'

    -- Hesap kodları → hspID
    DECLARE @hspKasa     int
    DECLARE @hspGelir    int

    SELECT @hspKasa  = hspID FROM mhs.mhsHsp
    WHERE  hspSirketID = @sirket AND hspKod = '100.10.001'   -- Merkez TL.Kasa

    SELECT @hspGelir = hspID FROM mhs.mhsHsp
    WHERE  hspSirketID = @sirket AND hspKod = '679.10.001'   -- örn. diğer gelir
    -- DİKKAT: yukarıdaki hsp kodu BKM'de var olmayabilir, lookup'la

    IF @hspKasa IS NULL OR @hspGelir IS NULL
        THROW 50001, 'Hesap kodu bulunamadı', 1

    -- Sıralama tarihi koruması
    DECLARE @siralama smalldatetime
    SELECT @siralama = sirketSiraliTarih FROM mhs.mhsSirket WHERE sirketID = @sirket
    IF @tarih <= @siralama
        THROW 50002, 'Sıralama tarihinden önce fiş yazılamaz', 1

    -- Yevmiye no
    DECLARE @yevmiyeNo int
    DECLARE @t TABLE (son int)
    INSERT INTO @t EXEC mhs.mhsSonYevmiyeNo @SirketID = @sirket
    SELECT @yevmiyeNo = son FROM @t

    -- Master
    DECLARE @fisbID int
    DECLARE @r TABLE (id int)
    INSERT INTO @r
    EXEC mhs.mhsFisB_ekle
        @ID = 0, @SirketID = @sirket, @Ad = 'Diğer gelir kasa girişi',
        @YevmiyeNo = @yevmiyeNo, @Tarih = @tarih, @Tip = 2, @Grp = 0,
        @EntTip = 0, @kKisi = @kKisi, @fiscID = 0, @kTarih = NULL,
        @progAd = @progAd
    SELECT @fisbID = id FROM @r

    -- Detay 1: Borç — Kasa
    EXEC mhs.mhsFis_ekle
        @FisBID = @fisbID, @SirketID = @sirket, @YevmiyeNo = @yevmiyeNo,
        @Tarih = @tarih, @Tip = 2, @BA = 0, @Tutar = -@tutar,    -- NEGATİF
        @EntID = 0, @HspID = @hspKasa, @Aciklama = 'Kasaya giriş',
        @gdrMerkez = 0, @fisCari = 0

    -- Detay 2: Alacak — Gelir hesabı
    EXEC mhs.mhsFis_ekle
        @FisBID = @fisbID, @SirketID = @sirket, @YevmiyeNo = @yevmiyeNo,
        @Tarih = @tarih, @Tip = 2, @BA = 1, @Tutar = @tutar,     -- POZİTİF
        @EntID = 0, @HspID = @hspGelir, @Aciklama = 'Diğer gelir',
        @gdrMerkez = 0, @fisCari = 0

    -- Denge kontrolü
    DECLARE @denge decimal(15,2)
    SELECT @denge = SUM(fisTutar) FROM mhs.mhsFis WHERE fisID = @fisbID
    IF @denge <> 0
        THROW 50003, 'Fiş dengeli değil', 1

    COMMIT TRANSACTION

    SELECT @fisbID AS olusturulan_fis_id, @yevmiyeNo AS yevmiye_no
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
    ;THROW
END CATCH
```

---

## 6. Yaygın Hatalar

| # | Hata | Sebep | Çözüm |
|---|---|---|---|
| 1 | FK hatası `fisHspID` | Yanlış şirketin hspID'si | hspSirketID = @SirketID filtresiyle lookup |
| 2 | Dengesiz fiş raporlarda görünüyor | SP denge kontrolü yapmıyor | Adım 4.4 — manuel SUM=0 kontrol |
| 3 | Fiş silinemiyor (`Sıralama tarihinden önce`) | fisTarih ≤ sirketSiraliTarih | Tarih ileriye al ya da kapanmış dönemde işin yok |
| 4 | Audit'te `[1]` `[2]` görüyorsun | drn2.islemNot'taki entTip placeholder'ı | Normal — entTip değeri parantez içinde |
| 5 | Aynı yevmiye no iki fişe çıktı | mhsSonYevmiyeNo race | Kendi tarafında SERIALIZABLE veya APPLOCK |
| 6 | Default fisOnay=1 ama UI'da onay bekliyor | mhsFisB_ekle UPDATE moda fisOnay'a dokunmuyor | INSERT sonrası `mhsFis_onay @onay=0` çağır |
| 7 | Dövizli tutar 0 görünüyor | mhsFis_ekle parametre listesinde fisDvzID/fisTutarDvz yok | Doğrudan INSERT veya UPDATE — SP yetmez |
| 8 | `mhsFis_sil` çağırınca her şey siliniyor (POS) | entTip=3 ana fişin cascade'i var | Kendi yazdığın fişlerde @EntTip=0 kullan, kendi mantığında çağırma |

---

## 7. Atomic Wrapper SP Önerisi (kendi tarafında)

DerinSIS'in CRUD SP'leri transaction sarmalı değil ve denge/sıralama
kontrolü yok. Kendi tarafında bir wrapper SP yazıp atomic + validated
yapmak en güvenlisi:

```sql
CREATE PROCEDURE [ent].[FisYaz]
    @SirketID  tinyint,
    @Tarih     smalldatetime,
    @Aciklama  varchar(50),
    @Mahsup    [ent].[MahsupSatirlari] READONLY,   -- TVP
    @kKisi     int,
    @progAd    varchar(10) = 'EntApi',
    @onay      tinyint = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- 1) Validasyonlar (sıralama tarihi, denge, hesap varlığı)
    -- 2) BEGIN TRAN
    -- 3) mhsSonYevmiyeNo, mhsFisB_ekle, foreach mhsFis_ekle
    -- 4) Denge kontrolü
    -- 5) (Opsiyonel) mhsFis_onay
    -- 6) COMMIT
END
```

`MahsupSatirlari` tipi:
```sql
CREATE TYPE [ent].[MahsupSatirlari] AS TABLE
(
    Sira      int IDENTITY(1,1),
    HspKod    varchar(20),
    BorcAlacak tinyint,    -- 0=Borç, 1=Alacak
    Tutar     decimal(15,2), -- her zaman pozitif — wrapper signed'a çevirir
    Aciklama  varchar(50),
    GdrMerkez int           NULL,
    fisCari   tinyint       NULL
)
```

Bu yaklaşımın faydası:
- Çağıran taraf işaret konvansiyonunu bilmek zorunda değil.
- Denge ve sıralama kontrolü merkezi.
- Tek transaction — yarı kalmış fiş riski sıfır.
- Audit'te tek "EntApi" kaynağı görünür.

---

## 8. Test Etmeden Önce Şunlara Dikkat

1. **Test ortamı yok mu?** — Production yazma yapacaksan önce **küçük
   tutarlı bir test fişi** at, denge ve audit'i kontrol et, sonra silebilir
   misin gör. `mhsFis_sil` çağırarak temizle.
2. **Sıralama tarihi sürpriz** — eğer ay sonu kapanış otomatik atılıyorsa
   senin servis dünden bugüne yazamayabilir. Önce `sirketSiraliTarih`'i
   sorgula.
3. **Audit kaynağı net** — `@progAd` parametresine kendi servis kodun.
   `'Mhs'` (default) ile karıştırma — ileride kim ne yazmış belli olsun.
4. **Hesap planı per-şirket** — yıl sonu şirket atladığında (5→6) hesap
   planı kopyalanıyor ama hspID'ler değişiyor. Servisin yıl bazlı hsp
   cache'ini her yıl yeniden kurmalı.
5. **mhsHsp değişiklikleri canlı** — kullanıcı UI'dan hesap eklerse hspID
   üretilir, ama senin servisinde cache'lenmiş hspKod→hspID map eskiyebilir.
   Cache TTL 1 saat civarı önerilir.
