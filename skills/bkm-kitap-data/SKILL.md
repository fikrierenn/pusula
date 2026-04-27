# BKM Kitap Data Context — SQL Server

BKM Kitap'ın SQL Server veri modeli, tablo yapıları, stored procedure'ler, view'lar ve yaygın sorgu kalıpları.
Data plugin ile birlikte kullanıldığında, Claude'un BKM Kitap veritabanına yönelik doğru SQL yazmasını sağlar.

## Tetikleme Koşulları
"BKM sorgu", "BKM SQL", "BKM rapor", "DerinSIS sorgu", "sipariş raporu", "stok sorgusu", "fiyat sorgusu", "müşteri sorgusu", "Tsoft veri", "Emek veri", "entegrasyon sorgu" gibi ifadelerde bu skill devreye alınmalı.

---

## 1. Veritabanı Mimarisi

```
SQL Server Instance (192.168.40.201:1433)
├── DerinSISBkm          ← Ana ERP (stok, sipariş, fatura, cari, fiyat)
├── DerinSISBkmCrm       ← CRM (müşteri, adres, izin, İYS)
├── DerinSISBkmWeb       ← Görsel DB (ürün görselleri)
└── BKMDATA              ← BKM kaynak veri (Tsoft müşteri)
```

**SQL Dialect**: Microsoft SQL Server (T-SQL)
**Tarih formatı**: DMY — `dd.MM.yyyy` veya `CONVERT(varchar, tarih, 104)`. Asla yyyy-MM-dd kullanılmaz.

---

## 2. Entegrasyon Şeması: [ent]

### Tablolar

#### ent.emek_urun
Emek Yayın Dağıtım'dan gelen ürün verileri. BKM Kitap tarafından doldurulur.
- Eşleşme alanı: `stokkod`
- DerinSIS'te yoksa insert, varsa update

#### ent.tsoft_urun
Tsoft e-ticaret platformuna gönderilen ürün bilgileri. DerinSIS tarafından oluşturulur.

### View'lar (Tsoft Entegrasyonu)

```sql
-- Değişen ürünler (genel bilgi + ön sipariş)
SELECT * FROM ent.urun_degisen_vw

-- Satış fiyatları
SELECT barkod, KDV_dahil_satis_fiyat, kampanya_yuzde, 
       kampanya_sabit_fiyat, kampanya_tip, urun_fiyat_tarih
FROM ent.urun_fiyat_vw

-- Görseller  
SELECT barkod, gorsel, urun_gorsel_tarih
FROM ent.urun_gorsel_vw

-- Liste fiyatları
SELECT barkod, satis_fiyat_kdvsiz, indirimsiz_KDV_dahil_satis_fiyat,
       KDV_dahil_satis_fiyat, kampanya_yuzde, kampanya_sabit_fiyat,
       kampanya_tip, urun_liste_fiyat_tarih
FROM ent.urun_liste_fiyat_vw

-- Stok (merkez depo, eksi stok = 0)
SELECT barkod, stok, urun_stok_tarih
FROM ent.urun_stok_vw

-- Yeni ürünler
SELECT barkod, urun_kayit_tarih
FROM ent.urun_yeni_vw

-- Kampanya ürün listesi
SELECT kmpID, kmpAd, EslesmeKodu, stkID
FROM ent.kampanyaUrunListesi_vw
```

### Stored Procedure'ler (Entegrasyon)

```sql
-- Emek ürün aktarımı
EXEC ent.emekUrunAktarim

-- Emek fiyat aktarımı
EXEC ent.emekFiyatAktarim

-- Tsoft log yazma
EXEC [ent].[urun_apilogyaz] 
    @barkod, @stkid, @tsoft_urun_id,
    @api_entegrasyon_tip, @api_durum, @api_tarih, @api_cevap

-- Tsoft ürün ID güncelleme
EXEC [ent].[urun_tsofturunId] @barkod, @tsoftId

-- Tsoft durum güncelleme (NULL kabul eder, sadece dolu alanlar güncellenir)
EXEC [ent].[urun_tsoft_durumyaz]
    @barkod,              -- varchar(20) ZORUNLU
    @api_kayit_durum,     -- smallint
    @api_gorsel_durum,    -- smallint
    @api_stok_durum,      -- smallint
    @api_fiyat_durum,     -- smallint
    @api_liste_fiyat_durum -- smallint
```

### API Entegrasyon Tip Kodları

| Tip | View | Açıklama |
|---|---|---|
| 1 | ent.urun_degisen_vw | Ürün bilgi değişikliği |
| 2 | ent.urun_fiyat_vw | Fiyat değişikliği |
| 3 | ent.urun_gorsel_vw | Görsel değişikliği |
| 4 | ent.urun_liste_fiyat_vw | Liste fiyat değişikliği |
| 5 | ent.urun_stok_vw | Stok değişikliği |
| 6 | ent.urun_yeni_vw | Yeni ürün |

### API Durum Kodları

| Kod | Durum |
|---|---|
| 1 | DerinSIS tarafından işlenmiş |
| 2 | API Hata |
| 3 | API Başarılı |

---

## 3. B2C Sipariş Şeması

### Müşteri İşlemleri

```sql
-- Müşteri ekle/güncelle (VN eşleşme)
-- Dönüş: @frmID, @eFirmaMkn, @eCrmID, @eCrmFatID, @eCrmSevkID
EXEC ent.B2C_musteri_ekle ...

-- CRM müşteri ekle (tam parametre)
EXEC ent.b2c_crm_ekle
    @CustomerName, @CustomerUsername, @CustomerPhone,
    -- Fatura
    @Fat_AddressId, @Fat_Name, @Fat_Mobile, @Fat_Address,
    @Fat_Citycode, @Fat_Towncode, @Fat_Zipcode,
    @Fat_Type, @Fat_Taxdep, @Fat_Taxno, @Fat_Phone,
    -- Sevkiyat
    @Sevk_AddressId, @Sevk_Name, @Sevk_Mobile, @Sevk_Phone,
    @Sevk_Address, @Sevk_City, @Sevk_Town, @Sevk_Zipcode
-- Dönüş: @eCrmID, @eCrmFatID, @eCrmSevkID, @frmID, @eFirmaMkn

-- Sevk adresi
EXEC ent.B2C_musteriAdresSevk_ekle ...

-- Fatura adresi
EXEC ent.B2C_musteriAdresFatura_ekle ...
```

### Sipariş İşlemleri

```sql
-- Sipariş başlık oluştur → RETURN @siparisID
EXEC ent.B2C_sip_ekle
    @eNo,               -- varchar(20) sipariş no
    @frmID,              -- int (musteri_ekle'den)
    @neden,              -- smallint (sipNeden tablosu, 0=yok)
    @eTarih,             -- smalldatetime
    @eFirmaMkn,          -- int (musteri_ekle'den)
    @eOdm,               -- smallint (ödeme ID, default 1)
    @belgeNot,           -- varchar(250) müşteriye yansıyan not
    @eNot,               -- varchar(30) dahili not
    @eFatArsvEticaretKargoFrmId,  -- int kargo firmaID
    @eFatArsvEticaretSiteId,      -- tinyint (1 = e-ticaret)
    @eCrmID,             -- int (musteri_ekle'den)
    @eCrmSevkID,         -- int (musteri_ekle'den)
    @eCrmFatID           -- int (musteri_ekle'den)

-- Sipariş satır ekle (sıra 1'den başlar, atlamasız)
EXEC ent.B2C_sipSatir_ekle
    @siparisID,          -- int (sip_ekle'den dönen)
    @satirSira,          -- int (1,2,3...)
    @barkod,             -- varchar(20)
    @adet,               -- decimal(9,3)
    @tutar,              -- decimal(9,2) KDV hariç brüt tutar
    @indirim,            -- decimal(9,2) KDV hariç indirim tutarı
    @ehKDV,              -- tinyint (0→%0, 1→%1, 2→%8, 3→%18)
    @KDVtutari,          -- decimal(9,2)
    @indirimYuzde,       -- decimal(5,2)
    @satirNotu           -- varchar(50)

-- Ödeme kaydı oluştur
EXEC dbo.sip_eklendi @siparisID

-- Sipariş iptali
EXEC dbo.sip_iptal @eID, @kKisi

-- Satır iptali
EXEC ent.B2C_sipSatir_iptal @eID, @kKisi, @barkod

-- Satır düzenleme (adet azaltma)
EXEC ent.B2C_sipSatir_duzenle ...

-- Ürün değiştirme (tekil)
EXEC dbo.sipSatirUrn_Degistir @siparisID, @eskiBarkod, @yeniBarkod

-- Ürün değiştirme (toplu — sipariş tipindeki tüm açık siparişlerde)
EXEC dbo.sipSatirUrn_DegistirToplu @sipTip, @eskiBarkod, @yeniBarkod
```

### KDV Kodları (urnKDV tablosu)

| kdvID | KDV Oranı |
|---|---|
| 0 | %0 |
| 1 | %1 |
| 2 | %8 |
| 3 | %18 |

---

## 4. CRM / Müşteri Şeması

### Müşteri Veri Kaynağı
```sql
-- BKM'nin Tsoft müşteri verileri
SELECT * FROM BKMDATA.dbo.customers

-- DerinSIS CRM müşteri tablosu
-- Eşleşme: mst.mstkod = Tsoft CustomerID
SELECT * FROM DerinSISBkmCrm.dbo.mst
WHERE mstkod = @TsoftCustomerID
```

### İYS İzin Yönetimi
```sql
-- İYS izin bilgileri paylaşım view'ı
SELECT * FROM DerinSISBkmCrm.dbo.bkm_musteri_iys
```

**İzin alanları**: IsEmailNotificationOn, IsSmsNotificationOn, IsPhoneCallNotificationOn
**Güncelleme koşulu**: BKM tarih > DerinSIS tarih VE izin durumu farklı

---

## 5. Fiyat Şeması

### Fiyat Numaraları

| Fiyat # | Alan | Açıklama |
|---|---|---|
| 1 | Perakende liste fiyatı | Mağaza satış fiyatı |
| 3 | Web fiyat | E-ticaret satış fiyatı = Fiyat1 × (1 - piyasa marjı) |
| 4 | E-ticaret üst fiyat | Varsa web fiyat hesabında baskın olur |

### Fiyat Nedenleri

| Neden | Açıklama |
|---|---|
| 4 | Emek entegrasyonu (otomatik) |
| 5 | Marka indirim listesi (marka indirimi düzenlenince otomatik) |

### Kampanya Tipleri
- **Yüzde**: Liste fiyatından hesaplanan indirim
- **Sabit fiyat**: Net KDV dahil fiyat
- Tsoft'a her zaman net fiyat olarak aktarılır

---

## 6. Depo ve Mağaza Yapısı

| Lokasyon | Rol |
|---|---|
| Merkez Depo | Ana depo, e-ticaret stoku buradan |
| FSM | Mağaza |
| Özlüce | Mağaza |

**Depo stok** = Merkez Depo + FSM + Özlüce
**E-ticaret stok** = Sadece Merkez Depo (eksi stok "0" olarak gönderilir)

---

## 7. Yaygın Sorgu Kalıpları

### Stok Durumu Sorgulama
```sql
-- E-ticaret stok durumu
SELECT barkod, stok, urun_stok_tarih
FROM ent.urun_stok_vw
WHERE stok > 0
ORDER BY urun_stok_tarih DESC
```

### Fiyat Karşılaştırma
```sql
-- Liste fiyat vs e-ticaret fiyat
SELECT 
    lf.barkod,
    lf.indirimsiz_KDV_dahil_satis_fiyat AS ListeFiyat,
    sf.KDV_dahil_satis_fiyat AS EticaretFiyat,
    sf.kampanya_yuzde,
    sf.kampanya_tip
FROM ent.urun_liste_fiyat_vw lf
JOIN ent.urun_fiyat_vw sf ON lf.barkod = sf.barkod
```

### Entegrasyon Log Kontrolü
```sql
-- Son başarısız entegrasyonlar
SELECT *
FROM ent.tsoft_urun
WHERE api_durum = 2  -- API Hata
ORDER BY api_tarih DESC
```

---

## 8. Önemli Kurallar (SQL Yazarken)

1. **Tarih formatı**: Her zaman `CONVERT(varchar, tarih, 104)` kullan (dd.MM.yyyy)
2. **Stok negatif**: E-ticaret view'larında eksi stok "0" olarak gösterilir, ham veri sorgularında dikkat
3. **Entegrasyon kullanıcısı**: Loglarda kullanıcı ID=137 entegrasyon işlemlerini filtreler
4. **STM müşteri**: firmaID=4590 bireysel müşteri belgelerini gösterir
5. **Kapıda ödeme**: cpID=2, ödeme kaydı faturalama sonrası üretilir
6. **Cross-database join**: `DerinSISBkm`, `DerinSISBkmCrm`, `BKMDATA` arasında cross-database sorgular yazılabilir
7. **Barkod**: varchar(20), ürün eşleşme birincil alanı
8. **KDV**: Fiyat view'larında KDV dahil/hariç ayrımına dikkat, Tsoft'a KDV dahil gönderilir

---

## 9. MCP Araçları (sqlserver-mcp-server)

Bu skill ile birlikte şu MCP araçları kullanılabilir:

| Araç | Ne zaman kullan |
|---|---|
| `sql_browse_schema` | Tablo/view keşfi — "ent schema'sında ne var?" |
| `sql_describe_table` | Kolon detayı — "ent.tsoft_urun yapısı ne?" |
| `sql_search_columns` | Semantik arama — "barkod içeren tüm tablolar" |
| `sql_relationships` | FK haritası — "sipariş tablosu neye bağlı?" |
| `sql_sample_data` | Örnek veri — "ent.emek_urun'dan 5 satır göster" |
| `sql_query` | SELECT sorgusu çalıştır |
| `sql_table_stats` | Tablo boyut/kullanım istatistikleri |
| `sql_index_analysis` | Eksik/kullanılmayan index önerileri |
