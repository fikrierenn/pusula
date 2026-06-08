# Muhasebe Modülü — CRUD + Okuma + Onay Akışı

> **Kaynak:** [`03-mhs-CRUD-sp-kaynak.sql`](./03-mhs-CRUD-sp-kaynak.sql)
> **Veritabanı:** `DerinSISBkm`

`mhs` schema'sının silme dışındaki tüm operasyon nesneleri burada
analiz edilir: 1 view + 4 SP (master upsert, detay insert, onay,
helper).

---

## 1. Modülün Tam Operasyon Haritası

| Operasyon | Nesne | Tarafı |
|---|---|---|
| READ (raporlama) | `mhs.mhsFis_vw` | Detay × Hesap planı, Borç/Alacak ayrımı |
| CREATE master | `mhs.mhsFisB_ekle` (`@ID=0`) | mhsFisBaslik INSERT + drn2 islem=2 |
| UPDATE master | `mhs.mhsFisB_ekle` (`@ID>0`) | mhsFisBaslik UPDATE + drn2 islem=3 |
| CREATE detay | `mhs.mhsFis_ekle` | mhsFis INSERT (audit yok!) |
| UPDATE detay | _yok (gözlenen)_ | Detay güncellemesi için ayrı SP yok |
| APPROVE | `mhs.mhsFis_onay` (`@onay=1`) | mhsFisBaslik.fisOnay=1 + drn2 islem=5 |
| UNAPPROVE | `mhs.mhsFis_onay` (`@onay=0`) | mhsFisBaslik.fisOnay=0 + drn2 islem=6 |
| DELETE | `mhs.mhsFis_sil` | Bkz. [`02-fis-silme-akisi.md`](./02-fis-silme-akisi.md) |
| HELPER | `mhs.mhsSonYevmiyeNo` | Yeni yevmiye no önerisi (max+1) |

---

## 2. Sign Convention (kritik!)

`mhs.mhsFis.fisTutar` **SIGNED** kolon:
- **Negatif** → **Borç**
- **Pozitif** → **Alacak**
- Aynı kural `fisTutarDvz` için de geçerli (sadece `fisDvzID <> 1` için)

Bu tek başına `mhsFis_vw`'den okunuyor:

```sql
(CASE WHEN fisTutar < 0 THEN fisTutar ELSE 0 END) AS Borc,
(CASE WHEN fisTutar > 0 THEN fisTutar ELSE 0 END) AS Alacak,
```

**Bu konvansiyon klasik muhasebe yazılımının tersi:**
- Çoğu sistemde Borç = pozitif, Alacak = pozitif, ayrım `BA` flag'iyle
- DerinSIS'te işaret yön bilgisini taşıyor → `fisBA` kolonu UI'dan ne
  geldiğini saklıyor ama gerçek hesap işaretten okunuyor

**Pratik etki — herhangi bir mhsFis sorgusunda:**
```sql
-- YANLIŞ — fisBA'yı kullanarak hesaplama:
SELECT SUM(CASE WHEN fisBA=0 THEN fisTutar ELSE 0 END) AS borc,
       SUM(CASE WHEN fisBA=1 THEN fisTutar ELSE 0 END) AS alacak
FROM mhs.mhsFis WHERE fisHspID = ?

-- DOĞRU — işaretten okuma (mhsFis_vw mantığı):
SELECT SUM(CASE WHEN fisTutar < 0 THEN -fisTutar ELSE 0 END) AS borc,
       SUM(CASE WHEN fisTutar > 0 THEN  fisTutar ELSE 0 END) AS alacak,
       SUM(fisTutar) AS net  -- denge: 0 olmalı
FROM mhs.mhsFis WHERE fisHspID = ?
```

---

## 3. `mhsFis_vw` — Raporlama view'ı

```sql
SELECT fsID, fisID, fisSirketID, yevmiyeNo, fisTarih, fisTip, fisBA,
       (CASE WHEN fisTutar<0 THEN fisTutar ELSE 0 END) AS Borc,
       (CASE WHEN fisTutar>0 THEN fisTutar ELSE 0 END) AS Alacak,
       fisEntID, fisHspID, fisAciklama,
       hspKod, hspAd,
       fisGdrMerkez, fisDvzID,
       (CASE WHEN fisDvzID=1 THEN 0 ELSE
             (CASE WHEN fisTutarDvz<0 THEN fisTutarDvz ELSE 0 END) END) AS DovizBorc,
       (CASE WHEN fisDvzID=1 THEN 0 ELSE
             (CASE WHEN fisTutarDvz>0 THEN fisTutarDvz ELSE 0 END) END) AS DovizAlacak
FROM mhs.mhsFis
INNER JOIN mhs.mhsHsp ON fisHspID = hspID
```

**Notlar:**
- INNER JOIN — fisHspID karşılığı bulunamayan kayıt view'da görünmez
  (orphan detection için kontrol değerli)
- ⚠️ JOIN composite değil! Sadece `fisHspID = hspID`. Ama mhsHsp PK'sı
  composite (hspID, hspSirketID). Aynı hspID birden fazla satıra denk
  gelmez çünkü hspID identity. **Bu işliyor**, ama composite join (hem
  fisSirketID hem fisHspID) daha güvenli olurdu.
- `fisBA` view'da bilgi olarak duruyor ama Borç/Alacak hesaplamasında
  kullanılmıyor.

**Ne olmadığına dikkat:** view master fiş başlığı bilgisini (`fisAd`,
`yevmiyeNo`'dan ÖTE şeyler — `fisGrp`, `fisEntTipID`, `fisOnay`) içermez.
Detay-orijinli rapor.

---

## 4. `mhsSonYevmiyeNo` — Helper

```sql
SELECT isnull(max(yevmiyeno + 1), 1) AS son
FROM   mhs.mhsFisBaslik
WHERE  fisbSirketID = @SirketID
```

- Boş şirkette 1 döner (default).
- **Concurrency riski:** İki kullanıcı aynı anda çağırırsa aynı no döner.
  Insert noktasında race olabilir. UNIQUE index var mı? — `mhsFisBaslik`'ta
  `IX_mhsFisBaslik_fisbSirketID_yevmiyeNo` NONCLUSTERED ama UNIQUE değil.
  Yani aynı (sirket, yevmiyeNo) iki fişe çıkabilir. **Veri kalite riski.**

---

## 5. `mhsFisB_ekle` — Master upsert

**İmza:**
```
@ID=0     → INSERT (yeni fiş; SCOPE_IDENTITY ile @ID üretilir)
@ID>0     → UPDATE (mevcut başlığın alanları güncellenir)
SELECT @ID → her durumda ID döner
```

**Insert sırasında:**
- 11 alan setleniyor (fisbSirketID, fisAd, yevmiyeno, fisTarih, fisTip,
  fisGrp, fisEntTipID, fiscID, gKisi, kKisi, oKisi)
- gKisi=kKisi=oKisi=`@kKisi` → ilk kayıtta üç tarih damgası aynı kullanıcıya
  set ediliyor
- Default'lar (defaults from table): `fisOnay=1`, `gTarih/kTarih/oTarih=getdate()`
- **fisOnay default 1!** Yani yeni fiş **otomatik onaylı** geliyor. Onay
  workflow'u opsiyonel (sonradan `mhs.mhsFis_onay` ile kaldırılabilir).

**Update sırasında:**
- 9 alan güncelleniyor (oluşturma metaları korunuyor: gKisi, gTarih)
- kKisi ve kTarih güncel kullanıcıya/zamana set
- **fisOnay UPDATE'te dokunulmuyor** — onay durumu korunuyor (UI tarafında
  ayrı sorumluluk)
- **oKisi/oTarih (onay) UPDATE'te dokunulmuyor** — onaylayan kişi metası
  da korunuyor

**Audit (drn2):**
```
INSERT: islem=2, "12345 11.05.2026 [1] kaydedildi,Prg=Mhs"
UPDATE: islem=3, "12345 11.05.2026 [1] değiştirildi,Prg=Mhs"
```
Burada `[1]` = entTip değeri (yani audit metninde entegrasyon tipi
parantez içinde duruyor — belge analizinde değerli).

**Eksik:** SP transaction içinde değil. Insert+drn2 atomic değil; çok
nadir sistem hatasında insert olur ama audit kayıt olmaz (ya da tersi).
mhsFis_sil bu disipline sahip, mhsFisB_ekle değil — **tasarım tutarsızlığı.**

---

## 6. `mhsFis_ekle` — Detay insert

```
INSERT INTO mhs.mhsFis (fisID, fisSirketID, yevmiyeno, fisTarih, fisTip,
                        fisBA, fisTutar, fisEntID, fisHspID, fisAciklama,
                        fisGdrMerkez, fisCari)
VALUES (...)
SET @ID = SCOPE_IDENTITY()
SELECT @ID
```

**Notlar:**
- Sadece insert. Update yok. Bir mahsup satırı yanlış girildiyse:
  silip yeniden eklemek gerekiyor (delete SP'si var ama tek satır için
  değil — `mhsFis_sil` tüm fişi siliyor).
- `fisDvzID` ve `fisTutarDvz` parametre LİSTESİNDE YOK → tablo default'ları
  geçerli (fisDvzID=1=TL, fisTutarDvz=0). Yani **bu SP üzerinden dövizli
  kayıt giremiyorsun.** Dövizli kayıt için ya direkt INSERT ya da farklı
  bir SP gerek (henüz keşfetmedik).
- `fisBA` parametre olarak alınıyor ama `fisTutar` da signed bekleniyor
  (sign convention'a göre). Çağıranın iki değeri tutarlı geçmesi
  sorumluluğunda — SP doğrulama yapmıyor.
- **Audit YOK.** mhsFis_ekle hiç drn2 yazmıyor. Sadece master ekle/sil/onay
  audit'leniyor; satır seviyesinde iz tutulmuyor.
- **Transaction yok**, ama tek INSERT olduğu için zaten atomic.

**Tipik kullanım örüntüsü (UI tarafından):**
```
1. EXEC mhs.mhsSonYevmiyeNo @SirketID  → @yevmiyeNo
2. EXEC mhs.mhsFisB_ekle @ID=0, ..., @YevmiyeNo, ...  → @fisbID
3. for each mahsup satırı:
       EXEC mhs.mhsFis_ekle @FisBID=@fisbID, ...
4. (opsiyonel) EXEC mhs.mhsFis_onay @fisbID, @onay=1, @oKisi
```

---

## 7. `mhsFis_onay` — Workflow

```sql
UPDATE mhs.mhsFisBaslik
SET    fisOnay=@onay, oKisi=@oKisi, oTarih=getdate()
WHERE  fisbID=@fisID

INSERT INTO drn2 ... islem = 5 + (1 - @onay)
RETURN @onay
```

**Pratik:**
- `@onay=1` → onay açık. Audit `islem=5`.
- `@onay=0` → onay kaldır. Audit `islem=6`.
- Başka bir değer (2, 3...) → SP "izin verir" (validation yok), `islem`
  formülü 5+(1-2)=4, 5+(1-3)=3 gibi yanlış kodlar üretir — ama UI
  muhtemelen sadece 0/1 geçer.
- Onayı KALDIRDIKTAN sonra `oKisi` "onayı kaldıran kişi"yi gösterir
  (eski onaylayan kayıp). Bu çelişkili bir tasarım — son işlemi
  yapan kullanıcı kalıyor.

---

## 8. drn2 Audit İslem Sözlüğü (komple)

| islem | İşlem | SP |
|---:|---|---|
| 2 | Kaydet | `mhsFisB_ekle` (insert) |
| 3 | Değiştir | `mhsFisB_ekle` (update) |
| 4 | Sil | `mhsFis_sil` |
| 5 | Onay (`@onay=1`) | `mhsFis_onay` |
| 6 | Onay kaldır (`@onay=0`) | `mhsFis_onay` |

**`izProgID = 55`** muhasebe modülü, **`izProgID = 11`** cari modülü
(mhsFis_sil entTip=5 bloğunda görülen).

**Audit sorgusu örneği — bir fişin tam yaşam döngüsü:**
```sql
SELECT izTrh, izKisi, islem,
       CASE islem WHEN 2 THEN 'Kaydet'
                  WHEN 3 THEN 'Değiştir'
                  WHEN 4 THEN 'Sil'
                  WHEN 5 THEN 'Onay'
                  WHEN 6 THEN 'Onay kaldır'
                  ELSE CAST(islem AS varchar) END AS islem_ad,
       islemNot, izBlg AS host
FROM   dbo.drn2
WHERE  izProgID = 55
  AND  izBlgID = @fisID
ORDER BY izID
```

---

## 9. Eksik / Açık Noktalar

1. **Detay UPDATE SP'si yok** — yanlış kayıt için tek seçenek tüm
   fişi silip yeniden oluşturmak (yetersiz).
2. **mhsFisB_ekle transaction'sız** — insert + drn2 atomic değil.
3. **mhsFis_ekle audit'siz** — satır seviyesi izlenebilirlik yok.
4. **Concurrency:** mhsSonYevmiyeNo + mhsFisB_ekle race — UNIQUE
   constraint olmadığı için duplicate yevmiye no riski var.
5. **Dövizli kayıt:** mhsFis_ekle parametrelerinde `fisDvzID` ve
   `fisTutarDvz` yok → ya başka SP var ya direkt INSERT ediliyor.
   Hangisi? — keşfedilecek.
6. **Detay seviyesi silme** (tek satır) yok — yalnızca tüm fiş silme
   var.
7. **Dengesizlik kontrolü** SP'si yok — fiş içinde Borç ≠ Alacak ise
   sistem sessiz. UI tarafında mı kontrol var?

---

## 10. Sıradaki Keşif Hedefleri

- [ ] `mhs.*` schema'sındaki tüm SP listesi (`SELECT * FROM
      sys.objects WHERE schema_id=SCHEMA_ID('mhs') AND type IN ('P','V')`)
- [ ] Dövizli kayıt için ayrı SP var mı?
- [ ] Detay UPDATE / single-row DELETE SP'si var mı?
- [ ] `mhs.mhsFis_geriYukle` veya benzeri restore SP?
- [ ] UI tarafından çağrılan dengesizlik kontrol fonksiyonu/SP?
- [ ] mhsFisB_ekle UPDATE bloğunda fisOnay=0'a düşürülmesi gerek mi
      iş kuralı olarak? (Onaylı fiş güncellendi → onay tekrar
      alınmalı?) — **iş süreci sorusu**
