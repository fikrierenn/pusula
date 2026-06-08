# `mhs.cariIsle_oto` — Günlük Cari → Muhasebe Robot Pipeline'ı

> **Kaynak:** [`13-cariIsle_oto-kaynak.sql`](./13-cariIsle_oto-kaynak.sql)
> **Bağlam:** [`07-mhs-objeleri.md`](./07-mhs-objeleri.md) #2 — Yapısal İşlemler

---

## 1. Tek Cümle Özeti

**"Bugün CRM/e-fatura tarafından üretilen yeni cari hareketleri sessizce
muhasebeleştir."** Robot kullanıcı adıyla çalışan, gecelik job ile
tetiklenmek üzere tasarlanmış otomatik entegrasyon SP'si.

⚠️ **İsim yanıltıcı:** "cariIsle_oto" → "cari otomatik kapanış" gibi
duruluyor. Aslında **akış otomasyonu** — yıl-sonu işlemiyle hiçbir ilişkisi
yok.

---

## 2. Parametresiz Çalışıyor

```sql
CREATE PROC [mhs].[cariIsle_oto]
AS ...
```

Hiç parametre almıyor. Tüm yapılandırma **`drn2ayar` ayar tablosundan** ve
mevcut tarihten okunuyor. Bu da SP'nin SQL Agent Job ile günlük
çalıştırılmak üzere tasarlandığını gösteriyor (parametre vermek zahmetsiz
olsun diye).

---

## 3. Akış (4 Adım)

```
1. Bağlam ayarlarını al:
     - mhsSirket.sirketOnce=1 + YEAR(GETDATE())=sirketDonem → @sirket
     - drn2ayar.ayarID=920 → @kisi (robot kullanıcı)
     - drn2ayar.ayarID=154 → @cariIlkTarih (cari mali başlangıç)

2. Aday cari hareketlerini topla:
     EXEC mhs.mhsEntKontrolCar @tarih1=GETDATE()-3, @tarih2=GETDATE()
       → 3 günlük pencerede entegre edilmemiş kayıtlar

3. Cursor ile filtrele:
     - car.cgTarih >= @cariIlkTarih       (mali geçerlilik)
     - car.cgTarih = bugün                 (sadece BUGÜN girilmiş)
     - car.cCrmID > 0                      (CRM kaynaklı, manuel hariç)

4. Her birini tek tek mhs'e entegre et:
     EXEC mhs.mhsEnt_car @cariID, @sirket, 0, @kisi
```

---

## 4. Yeni Keşfedilen Sistem Ayarları (`drn2ayar`)

İlk kez bu tabloyu görüyoruz:

| ayarID | Ne işe yarıyor | Bu SP'de kullanımı |
|---:|---|---|
| **154** | Cari işlemler başlangıç tarihi | Mali açıdan cari modülün ne zamandan itibaren güvenilir olduğu — bu tarihten önceki hareketler entegre edilmez |
| **920** | E-fatura robot kullanıcı ID | drn2 audit'te `kKisi=920` ile robot tarafından yapılan tüm işlemler izlenebilir |

→ `drn2ayar` BKM'de **system-wide ayar deposu**. İleride başka SP'lerde
başka ayarID'ler çıkacaktır. Bu tablo BKM'nin "feature flag" deposu olarak
da kullanılıyor olabilir.

---

## 5. Yeni Keşif: `mhsSirket` Tablosunun Sezgisel Kolonları

```sql
SELECT @sirket = sirketID
FROM   mhs.mhsSirket
WHERE  sirketOnce = 1
   AND YEAR(GETDATE()) = sirketDonem
```

| Kolon | Anlamı |
|---|---|
| `sirketOnce` | "Öne çıkan / varsayılan" şirket flag (1 = aktif kullanılan) |
| `sirketDonem` | Mali yıl (YYYY) |
| `sirketSiraliTarih` | Sıralama / kapanmış dönem tarihi (mhsFis_sil ve mhsFis_cikar koruması için) |
| `sirketSonFisID` | Son üretilen kapanış fişi ID (mhsKapanis tarafından güncelleniyor) |

→ Yıl atlama anında **`sirketOnce` flag'inin yeni şirkete taşınması** kritik.
Aksi takdirde `cariIsle_oto` eski yıl şirketine yazmaya devam eder.

---

## 6. Cursor Filtre Mantığı — İncelik

```sql
SELECT id FROM @tablo
INNER JOIN car ON cID = id
WHERE CAST(cgTarih AS DATE) >= @cariIlkTarih
  AND CAST(cgTarih AS DATE) =  CAST(GETDATE() AS DATE)
  AND cCrmID > 0
```

### `cgTarih` ≠ fiş tarihi

`car.cgTarih` = cari hareketin **giriş tarihi** (kayıt edilme zamanı), fiş
tarihi değil. Bir e-fatura 3 gün önceye tarihli olabilir ama bugün cari
modüle düşmüştür → bu kayıt yakalanır.

### `cCrmID > 0` filtresi — KRİTİK

CRM tarafından otomatik üretilen cari hareketler `car.cCrmID` doldurarak
işaretleniyor. Bu filtre **manuel cari hareketleri otomasyonun dışında
tutuyor**. Manuel kayıtlar muhasebeci tarafından elle (UI üzerinden) mhs'e
aktarılmalı.

### 3 günlük pencere ama bugün filtresi — paradoks?

`mhsEntKontrolCar` 3 günlük pencerede çağrılıyor (`@tarih1 = GETDATE()-3`),
ama cursor sadece bugün'ü işliyor. Sebep büyük olasılıkla:

- `mhsEntKontrolCar` pahalı bir SP — geniş arama performans için optimize
- 3 gün geriye baksa bile yine sadece bugün kayıtları işleyecek
- Geriye gerek yok ama "emniyet penceresi" bırakılmış

⚠️ **Risk:** Eğer job dün başarısız olduysa → dün girilmiş kayıtlar bugün
filtreden kaçar (`cgTarih = bugün` koşulu). **Sonsuza dek atlanır.** Sadece
manuel müdahale ile yakalanabilir.

→ **Düzeltme önerisi:**
```sql
AND CAST(cgTarih AS DATE) <= CAST(GETDATE() AS DATE)        -- bugün VEYA önce
AND CAST(cgTarih AS DATE) >= CAST(GETDATE() - 3 AS DATE)    -- son 3 gün
```

---

## 7. mhsEnt_car Çağrı Pattern'ı

```sql
EXEC mhs.mhsEnt_car @cariID, @sirket, 0, @kisi
                    └─ ID    └─şirket └─?  └─robot
```

3. parametre (`0`) muhtemelen "dövizID" veya "yöntem" gibi bir flag.
`mhsEnt_car` analizi yapıldığında netleşecek (henüz kaynağı çekilmedi —
sıradaki tur).

---

## 8. Operasyonel Pratik (Tahmini)

### Çağrılma Senaryosu — SQL Agent Job

```
Job adı: BKM_E-Fatura_Cari_Entegrasyon_Gecelik (tahmini)
Schedule: Her gün 23:30
Command: EXEC mhs.cariIsle_oto
```

### Günün akışı

```
Sabah 09:00  CRM'e e-fatura/e-arşiv akmaya başlar
Gün boyu     dbo.car tablosuna cCrmID > 0 kayıtlar eklenir
              car.cMhsFisID = 0 (henüz entegre değil)
Saat 23:30   cariIsle_oto çalışır:
              - Bugün girilenleri yakalar
              - mhsEnt_car ile mhs.mhsFisBaslik + mhs.mhsFis üretir
              - car.cMhsFisID güncellenir (mhsEnt_car içinde)
              - drn2 audit kayıtları (robot user @kisi=920 adına)
Ertesi gün   Yeni döngü
```

### Audit izleme

```sql
-- Robot kullanıcının yaptığı tüm cari entegrasyonlar
SELECT izTrh, islem, islemNot, izBlgID
FROM   dbo.drn2
WHERE  izKisi = 920
  AND  izProgID = 55                  -- mhs
  AND  izTrh >= '01.05.2026'           -- DMY!
ORDER BY izID DESC
```

### Job sağlık kontrolü

```sql
-- Bugün cariIsle_oto çalıştıysa robot'un en az bir kaydı olmalı
DECLARE @bugun date = CAST(GETDATE() AS date)
SELECT
    COUNT(*) AS robot_kayit_adet,
    MIN(izTrh) AS ilk_islem,
    MAX(izTrh) AS son_islem
FROM   dbo.drn2
WHERE  izKisi = 920
  AND  izProgID = 55
  AND  CAST(izTrh AS date) = @bugun
```

Sıfır dönerse **gecelik job çalışmamış** demektir → izleme alarmı kurulabilir.

---

## 9. Risk Listesi

| Risk | Seviye | Senaryo | Önlem |
|---|:--:|---|---|
| Job başarısız → kayıtlar atlanır | **YÜKSEK** | Dün job hata verdi, bugün cursor sadece bugünü işler, dünkü kayıtlar kalır | Cursor filtresi 3 günlük pencereye genişletilmeli |
| Transaction yok | YÜKSEK | Cursor ortasında hata, yarı entegre durum | mhsEnt_car kendi içinde TX kullanıyor olmalı, doğrula |
| Robot kullanıcı disable | ORTA | drn2ayar.920 boş/null → @kisi=null → mhsEnt_car hata | Pre-flight @kisi NULL kontrolü ekle |
| sirketOnce yanlış | ORTA | Yıl atlamada flag taşınmadıysa → eski yıla yazar | Yıl atlama checklist'inde sirketOnce kontrolü |
| Cursor performansı | DÜŞÜK | Günde 100+ kayıt yavaş | Set-based mhsEnt_car alternatifi geliştirilebilir |
| `cCrmID > 0` filtresi | DÜŞÜK-ORTA | Manuel kayıtlar atlanır — doğru ama farkındalık lazım | Manuel cari için ayrı UI/job |
| `mhsEntKontrolCar` parametresi `@sirket, 0, 0` | DÜŞÜK | 0,0 ne demek bilinmiyor | mhsEntKontrolCar kaynağı çek, parametre anlamı netleşsin |

---

## 10. Açık Sorular (sıradaki tur)

1. **`mhsEnt_car` SP'si ne yapıyor?** Cari → mhsFisBaslik + mhsFis üretiminin
   gerçek mantığı orada. Hesap mapping'i (cari → 120/320 + karşı taraf
   hesabı) nasıl çözülüyor?
2. **`mhsEntKontrolCar`** SP'sinin döndürdüğü `@tablo` hangi denetimleri
   yapıyor? Hangi kayıtları "uygun değil" diyor?
3. **`drn2ayar`** tablosunda başka kaç ayarID var? BKM'de bu
   "feature flag / system config" deposunun tam haritası.
4. **`car.cCrmID`** kolonunun tam yapısı — BKM CRM neye işaret ediyor,
   e-fatura eşleştirmesi nasıl yapılıyor?
5. **SQL Agent Job kaydı** — `cariIsle_oto` hangi job tarafından çağrılıyor,
   schedule nedir, son 30 gün başarı oranı?
6. Manuel cari hareketler için kardeş bir job/SP var mı? (`cariIsle_manuel`
   gibi)

---

## 11. Bağlantı: Diğer mhs SP'leriyle İlişki

```
KRONOLOJİK AKIŞ (bir cari hareketin yaşam döngüsü):

[CRM tetikler]
  → dbo.car insert (cCrmID > 0, cMhsFisID = 0)

[Aynı gün gece]
  → cariIsle_oto çalışır
     → mhsEntKontrolCar (denetim — bu belge)
     → mhsEnt_car      (gerçek entegrasyon — kardeş SP, henüz incelenmedi)
        → mhsFisB_ekle (master fiş yaratır, internal)
        → mhsFis_ekle  (detay satırlar, internal)
        → car.cMhsFisID = yeni fisID (geri-bağlama)
     → drn2.islem=2 audit (robot user)

[Hata bulunursa — günlük operasyon]
  → mhsFis_cikar (entegrasyonu geri al, car.cMhsFisID=0)
  → manuel düzeltme
  → cariIsle_oto bir sonraki gece tekrar yakalar VEYA mhsEnt_car manuel çağrılır

[Yıl sonu]
  → mhsKapanis (teknik bakiye sıfırlama, klasik TDHP zinciri YOK)
```

→ Sistemin "kalbi" `mhsEnt_car` ve `mhsEntKontrolCar`. Bunlar bir sonraki
turda incelenmeli.
