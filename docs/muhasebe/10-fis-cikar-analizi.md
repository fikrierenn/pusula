# `mhs.mhsFis_cikar` — "Çıkar" SP'sinin Analizi

> **Kaynak:** [`09-mhsFis_cikar-kaynak.sql`](./09-mhsFis_cikar-kaynak.sql)
> **Önceki bağlam:** [`02-fis-silme-akisi.md`](./02-fis-silme-akisi.md) (sil SP'si)

Bu SP, [`07-mhs-objeleri.md`](./07-mhs-objeleri.md)'deki "yeni keşif" listesinde
tek başına duran sorunun cevabı: **mhsFis_sil'in kardeşi mhsFis_cikar ne işe
yarar?**

---

## 1. Tek Cümleyle Fark

| SP | İşi |
|---|---|
| **`mhsFis_sil`** | Bir fişi **tamamen yok et** — master + tüm detay + tüm cascade. Arşive (`sil.mhsFis`) yedeklenir. |
| **`mhsFis_cikar`** | Bir fişin **içinden bir entegrasyon belgesini ÇIKAR** — sadece o belgeye ait satırlar silinir, fiş kalır. **Arşivleme YOK.** |

**Kullanım senaryosu:**
- Sil → "Bu fiş yanlış oluşmuş, mevcut olmamalı"
- Çıkar → "Faturanın muhasebe entegrasyonu yanlış yapılmış, geri al ki düzeltilip yeniden entegre edebilsin"

---

## 2. Tam Karşılaştırma Tablosu

| Özellik | `mhsFis_sil` | `mhsFis_cikar` |
|---|---|---|
| Hedef | Tüm fiş (master + detay + cascade) | Tek bir entegrasyon belgesinin satırları |
| Etkilenen tablolar | mhsFisBaslik, mhsFis, fat, car, ith, posOzetMagazaGun, posOzetOdemeZ, sil.mhsFis, drn2 | mhsFisBaslik, mhsFis, fat, car, drn2 |
| Hedef belgenin ENTTIP kısıtı | Hepsi (0-5) | **Sadece 1 (Fatura) ve 2 (Cari)** |
| Sıralama tarihi koruması | ✓ | ✓ |
| Sil arşivi (`sil.mhsFis`) | ✓ Var (geri yükleme mümkün) | ✗ **Yok — direkt DELETE** |
| Cascade silme (POS Z, mağaza-gün) | ✓ entTip=3 için zincir reaksiyonu | ✗ |
| Master fişi siler mi? | Her zaman | **Sadece son detay da silinince** (NOT EXISTS) |
| Audit drn2.islem | 4 (sil) | 4 (sil) — aynı kod, **istemcide format'tan ayırt edilir** |
| Audit metni anahtar kelime | "silindi" | "çıkarıldı" |
| Transaction | ✓ | ✓ |
| Error handling | TRY/CATCH + raiserror | TRY/CATCH + raiserror |

---

## 3. Akış (9 Adım)

```
1. @fisEntID = 0 ise reddet (defansif)
2. Fişin entTip + sirket + tarih + sıralama tarihini çek
3. Sıralama tarihi geçmişse reddet (kapanmış dönem)
4. entTip ∉ {1, 2} ise reddet
5. Bağlantı doğrula:
     - mhsFis'te fisID + fisEntID kombinasyonu var mı?
     - YOKSA + entTip=2 ise: car.cBag (alt cari) üzerinden de bak
     - Yine yoksa "Enteg. bağlantısı yok" hatası
6. Transaction başlat:
     - entTip=1 (Fatura):
         fat.eMhsFisID = 0
         car.cMhsFisID = 0  WHERE cFatTip<13 AND cFatID=@fisEntID
     - entTip=2 (Cari):
         car.cMhsFisID = 0  WHERE cID=@fisEntID OR (cKodKarsi<>0 AND cBag=@fisEntID)
7. DELETE mhs.mhsFis WHERE fisID=@fisID AND fisEntID=@fisEntID
8. drn2'ye islem=4 audit kaydı ("çıkarıldı,Prg=...")
9. Eğer fişin BAŞKA detayı kalmadıysa:
     DELETE mhs.mhsFisBaslik WHERE fisbID=@fisID
COMMIT / CATCH-ROLLBACK
```

---

## 4. Kritik Mantık Detayları

### 4.1 entTip=2'deki "alt cari" yakalama

```sql
IF NOT EXISTS (... fisEntID = @fisEntID ...)
BEGIN
    IF @entTip = 2
        IF EXISTS (... fisEntID = cBag AND cID = @fisEntID)
            SELECT @fisEntID = cBag FROM car WHERE cID = @fisEntID
```

Anlamı: Cari hareket (entTip=2) için, gönderilen `@fisEntID = car.cID` ise
ama mhsFis'te o ID görünmüyorsa — belki orada `car.cBag` (alt cari, çift
yönlü hareket) ID'si saklanmıştır. SP otomatik düzeltme yaparak doğru
kaydı bulur.

→ Bu, DerinSIS cari modülünün **çift kayıt mantığı** — bir cari hareket iki
satır oluşturuyor (örn. müşteri Borç + karşı hesap Alacak), `cBag` ile
birbirine bağlanıyor. mhs entegrasyonu bunlardan hangisini referans aldıysa
onu bulur.

### 4.2 entTip=1'de car güncelleme şartı

```sql
UPDATE car SET cMhsFisID = 0
WHERE cFatTip < 13 AND cFatID <> 0 AND cFatID = @fisEntID
```

`cFatTip < 13` filtresi — bkz. [`08-hesap-plani-gdr-merkez.md`](./08-hesap-plani-gdr-merkez.md):
0-12 aralığı **fatura kaynaklı** cari hareketler (Alış/Satış/İade/Hizmet/Gider/
Fiyat Farkı vs.). Yani sadece bu faturanın yarattığı cari satırlar
sıfırlanır. Diğer ödeme/banka/çek hareketleri (cFatTip ≥ 13) etkilenmez.

### 4.3 İki yönlü flag protokolü

DerinSIS'in muhasebe entegrasyonu **iki yönlü flag** kullanıyor:

```
fat.eMhsFisID = 0   → fatura mhs'e entegre değil → mhsEnt_fat batch'i yakalar
fat.eMhsFisID = X   → entegre, mhsFisBaslik.fisbID = X
```

Aynı: `car.cMhsFisID`, `posOzetMagazaGun.pMhsFisID`, `posOzetOdemeZ.zMhsFisID`,
`ith.ithKapanisMhsFis`.

**mhsFis_cikar bu flag'i sıfırlayarak entegrasyonu "bekleyen" duruma
düşürüyor.** Sonradan `mhsEnt_fat` çalıştırıldığında düzeltilmiş haliyle
yeniden mhs fişi oluşturuluyor.

→ Bu pattern **idempotent re-entegrasyon** — aynı belge defalarca düzeltilip
mhs'e yansıtılabilir, sadece o anki versiyonu durur.

### 4.4 Master fişi koşullu silme

```sql
IF NOT EXISTS (SELECT TOP 1 * FROM mhs.mhsFis WHERE fisID = @fisID)
    DELETE FROM mhs.mhsFisBaslik WHERE fisbID = @fisID
```

Bir mhs fişinde **birden fazla entegrasyon belgesi** olabiliyor demek.
Örneğin:
- POS özet fişi (entTip=3) — bir master altında onlarca cari satır farklı
  fisEntID'lerle
- Birleşik mahsup (entTip=0) — birkaç fatura tek mhs fişinde

Bir entegrasyon belgesi çıkarıldığında diğerleri kalmaya devam ederse
master fiş yaşar. Sadece son belge de çıkarıldığında master ölür.

---

## 5. entTip=5 (Cari Fiş) Kapatılmış Blok

Kaynak'ta yorumlu kalan blok:

```sql
--IF @entTip = 5
--BEGIN
--    IF EXISTS(... fisCari = 1)
--        RAISERROR ('Enteg. çıkarılamaz, ... CariFiş=...', 11, 1)
--END
```

Bu, "**Cari fişlerde çıkarma yasaklı**" demek. Zaten genel `entTip NOT IN
(1,2)` kontrolüyle reddediliyor — bu blok eski bir tasarımdan kalma. Ölü
kod. Cari fişler tek başına entegre olduğu için (yorum: "tek başına entegre
olduğu için gerek yok") farklı işlem yapılmıyor.

---

## 6. Sil + Çıkar Birlikte — Karar Matrisi

Operasyonda hangi durumda hangi SP?

| Senaryo | Doğru SP |
|---|---|
| Manuel mahsup yanlış (fisEntTip=0=Kullanıcı) | `mhsFis_sil` |
| Fatura yanlış muhasebeleşti, faturayı düzelteceğim | `mhsFis_cikar` (önce) → fatura düzelt → `mhsEnt_fat` (yeniden) |
| Cari hareket muhasebeleşmiş ama hiç olmaması gerekiyor | `mhsFis_cikar` + cariyi de sil |
| POS özetinden tüm gün yanlış | `mhsFis_sil` (entTip=3 cascade'i otomatik) |
| Tek POS satırı yanlış | ⚠️ **Çıkar yok (entTip=3)**, sil tüm günü götürür → manuel müdahale |
| Geçmişe dönük fiş yenileme (sıralama tarihinden eski) | **Hiçbiri çalışmaz** — kapanmış dönem koruması |

---

## 7. Risk Notları

1. **Arşivleme yok.** `mhsFis_cikar` sonrası geri yükleme mekanizması
   yoktur — sadece "yeniden entegre et" var (kaynak fat/car ile birlikte).
   Eğer kaynak da silinmişse (mhsFis_cikar sonra fat/car'ı da silinen kayıt)
   geri çağırılamaz. **mhsFis_sil'den daha kalıcı.**
2. **Race riski:** Çoklu çağrı paralelinde aynı `@fisEntID` iki kez
   çıkarılırsa ikinci çağrı "bağlantı yok" hatası verir — temiz davranış,
   sorun yok.
3. **fat/car güncelleme + DELETE atomik** ama drn2 INSERT de aynı
   transaction'da → ya hep ya hiç. Tutarlı.
4. **entTip=2 alt cari yakalama** sağlam, ama eğer `car.cBag` zinciri 2+
   seviye derinse (cBag→cBag→cID) bu SP yakalayamaz. Sadece bir adım
   düzeltme yapıyor.

---

## 8. drn2'de Sil vs Çıkar Ayırımı (audit ipucu)

İkisi de `islem=4` kullanıyor ama `islemNot` formatı farklı:

| SP | islemNot örneği |
|---|---|
| `mhsFis_sil` | `"12345 11.05.2026 [1] silindi,Prg=Mhs"` |
| `mhsFis_cikar` | `"12345-11.05.2026 [1] [987654] çıkarıldı,Prg=Mhs"` |

Audit sorgusunda ayırt etmek için:
```sql
SELECT
    izID, izTrh, izKisi,
    CASE
        WHEN islemNot LIKE '%silindi%'    THEN 'SİL'
        WHEN islemNot LIKE '%çıkarıldı%'  THEN 'ÇIKAR'
        WHEN islemNot LIKE '%kaydedildi%' THEN 'KAYDET'
        WHEN islemNot LIKE '%değiştirildi%' THEN 'DEĞİŞTİR'
        WHEN islemNot LIKE '%onay durum=1%' THEN 'ONAY'
        WHEN islemNot LIKE '%onay durum=0%' THEN 'ONAY KALDIR'
    END AS operasyon,
    islemNot, izBlgID
FROM   dbo.drn2
WHERE  izProgID = 55
ORDER BY izID DESC
```

---

## 9. Açık Sorular (sıradaki tur)

1. `mhsEnt_fat` — fat.eMhsFisID = 0 olanları nasıl ve ne sıklıkta yeniden
   entegre ediyor? Job mı UI mı tetikliyor?
2. POS satırı (entTip=3) için tek-satır çıkarma SP yok — operasyon nasıl
   yapılıyor pratikte? (Yanlış POS satırı → tüm gün re-entegrasyonu mu?)
3. `mhsFis_cikar` UI'da hangi butona bağlı? "Entegrasyondan Çıkar" gibi bir
   menü olmalı.
4. Audit sorguladığımızda BKM'de günlük kaç çıkar/sil işlemi yapılıyor?
   (operasyonel sağlık göstergesi)
