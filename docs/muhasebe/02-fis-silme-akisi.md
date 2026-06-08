# Muhasebe Fişi Silme Akışı — `mhs.mhsFis_sil` Analizi

> **Kaynak:** [`01-mhsFis_sil-kaynak.sql`](./01-mhsFis_sil-kaynak.sql)
> **Veritabanı:** `DerinSISBkm`
> **Schema:** `mhs` (muhasebe), bağlı: `dbo` (cari/fatura/POS), `sil` (silinen fiş arşivi)
> **Son güncelleme:** 11.05.2026

Bu SP, muhasebe modülünün **silme tarafındaki tüm bağlantı kurallarını tek
yerde** anlatıyor. Yani aslında modülün omurgasının yarısı bu SP'nin içinde.
Aşağı yukarı bütün muhasebe-entegrasyon haritası buradan çıkarılabilir.

---

## 1. Parametreler

| Parametre | Tip | Default | Anlam |
|---|---|---|---|
| `@fisID` | int | — | Silinecek fişin ID'si (master `fisbID` = detay `fisID`) |
| `@belgeyi` | tinyint | 0 | 1 → master da silinir; 0 → sadece detay temizlenir |
| `@kisi` | int | 0 | Audit (`drn2.izKisi`) için kullanıcı |
| `@progAd` | varchar(10) | `'Mhs'` | Audit için çağıran program kodu (örn. `IthKpn`) |

---

## 2. Akış — Tek Bakışta

```
┌──────────────────────────────────────────────────────────────────────┐
│ ÖN KONTROLLER (RAISERROR ile kesilir)                               │
│  1. Fişi yükle (mhsFisBaslik + mhsSirket)                            │
│  2. Mali sıralama tarihi koruması  (fisTarih > sirketSiraliTarih ?)  │
│  3. İth/İhr KAPANIŞ fişi mi? → sadece IthKpn programı silebilir     │
│  4. Açık ith/ihr DOSYASINA bağlı mı? (entTip 1,2,5)                  │
│  5. POS entTip=3 ise: ANA mekan-gün fişi mi?                        │
└──────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────────┐
│ TRANSACTION                                                          │
│                                                                      │
│  if @belgeyi > 0 :                                                   │
│    • mhsSirket.sirketIlkFisID / sirketSonFisID temizle               │
│    • entTip'e göre dış referansları boşa çek (fat / car / pos)       │
│      ─ entTip=1  →  fat.eMhsFisID=0, car.cMhsFisID=0  (cFatTip<13)  │
│      ─ entTip=2,4 → car.cMhsFisID=0  (cID veya cBag eşleşen)        │
│      ─ entTip=5  →  +carNot/car (cFatTip 20–199, cFatID=fiscID) SİL │
│      ─ entTip=3  →  posOzetMagazaGun.pMhsFisID=0                    │
│                       + aynı tarih+mağaza diğer kasa fişleri SİL    │
│                       + Z bazlı kasa fişleri SİL + posOzetOdemeZ    │
│                                                                      │
│  ARŞİVLE:  sil.mhsFis ← snapshot (master+detay birleşik)             │
│  DELETE  mhs.mhsFis (detay)                                          │
│                                                                      │
│  if @belgeyi > 0 :                                                   │
│    • drn2 audit log INSERT                                           │
│    • DELETE mhs.mhsFisBaslik (master)                                │
│                                                                      │
│  COMMIT  /  ROLLBACK + RAISERROR                                     │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 3. SP'den Çıkardığım Tablo Haritası

### 3.1 Çekirdek — Muhasebe (`mhs` schema)

| Tablo | Rolü | SP'den okunan kolonlar |
|---|---|---|
| **`mhs.mhsFisBaslik`** | Fiş başlığı (master) | `fisbID` (PK), `fisbSirketID`, `yevmiyeNo`, `fisTarih`, `fisTip`, `fisAciklama`, `fisEntID`, `fisEntTipID`, `fiscID`, `fisOnay`, `gKisi/kKisi/oKisi`, `gTarih/kTarih/oTarih` |
| **`mhs.mhsFis`** | Fiş detay/mahsup satırları | `fisID` (= baslık `fisbID`), `fisHspID` (hesap), `fisBA` (Borç/Alacak), `fisTutar`, `fisEntID`, `fisGdrMerkez`, `fisCari`, `fisAd`, `fisGrp` |
| **`mhs.mhsSirket`** | Mali şirket / dönem | `sirketID`, `sirketSiraliTarih`, `sirketIlkFisID`, `sirketSonFisID` |
| **`sil.mhsFis`** | Silinen fiş arşivi | Master + detay birleşik snapshot |

### 3.2 Entegrasyon hedefleri (dokunulan dış tablolar)

| Tablo | Schema | Bağlanma noktası | Kullanım |
|---|---|---|---|
| `fat` | `dbo` | `eMhsFisID`, `eID` | Fatura — entTip=1 silmede mhs referansı sıfırlanır |
| `car` | `dbo` | `cMhsFisID`, `cID`, `cFatTip`, `cFatID`, `cIthID`, `cKod/cKodKarsi`, `cBag`, `cTarih` | Cari hareket — tüm entTip'lerde dokunuluyor |
| `carNot` | `dbo` | `cnID` | Cari not — entTip=5'te toplu silinir |
| `ith` | `dbo` | `ithID`, `ithKapanisMhsFis`, `ithDurum`, `ithTip` | İthalat/İhracat dosyası |
| `posOzetMagazaGun` | `dbo` | `pMhsFisID`, `magazaID` | POS günlük özet (e-Defter ana fişi) |
| `posOzetOdemeZ` | `dbo` | `zMhsFisID` | POS Z raporu ödeme detayı |

### 3.3 Audit

| Tablo | Anlam |
|---|---|
| `drn2` | Denetim izi — `izProgID` (55=mhs, 11=cari), `izTip`, `izBlg=host_name()`, `izKisi`, `islem` (4=sil), `islemNot`, `izBlgID` |

---

## 4. fisEntTipID — Entegrasyon Türleri (SP'den çıkarılan tahminler)

| EntTip | SP'deki davranış | Çıkarılan anlamı |
|---|---|---|
| **1** | `fat.eMhsFisID=0` + `car.cMhsFisID=0` (cFatTip<13) | **Fatura** entegrasyonu |
| **2** | `car.cMhsFisID=0` (cID/cBag) | **Cari** entegrasyonu (klasik) |
| **3** | POS özel mantığı (mekan-gün, Z raporu, diğer kasa fişleri) | **POS / e-Defter** entegrasyonu |
| **4** | EntTip 2 ile aynı blok | **Cari** entegrasyonu (varyant?) |
| **5** | Cari + ith dosya bağlantısı + cFatTip 20–199 carNot/car silme | **İthalat/İhracat** entegrasyonu |
| **6+** | SP'de yok | **?** (masraf, kasa, banka, dövizli vb. — doğrulanacak) |

### Önemli sayısal eşikler

| Değer | Nerede | Anlam (SP'den çıkarım) |
|---|---|---|
| `cFatTip < 13` | entTip=1 fatura blok | Fatura tipleri |
| `cFatTip = 13` | entTip=3 POS blok | POS kasa fişi (?) |
| `cFatTip BETWEEN 20 AND 199` | entTip=3,5 | Diğer cari hareket tipleri (kasa, çek, senet, dövizli vb.) |

---

## 5. Kritik İş Kuralları (SP içine gömülü)

1. **Mali sıralama tarihi.** `mhsSirket.sirketSiraliTarih`'ten önceki tarihli fiş
   silinemez. Yani dönem kapatma yapıldıysa o dönemin fişi kapı dışı.

2. **İth/İhr kapanış fişi koruması.** Bir ithalat/ihracat dosyasının kapanış
   muhasebe fişi normal yoldan silinemez; sadece IthKpn programı silebilir.

3. **Açık dosya koruması.** EntTip 1/2/5 fişlerden biri açık (`ithDurum=1`)
   bir dosyaya bağlıysa silinmez.

4. **POS ana fiş koruması.** EntTip=3'te bir mekan-gün için sadece
   `posOzetMagazaGun.pMhsfisID` ile bağlı **ana** fiş silinebilir. Ana fiş
   silinince **aynı tarih+mağaza için Z bazlı + diğer kasa fişleri otomatik
   olarak da silinir** (cascade).

5. **Açılış/kapanış fişi referansı.** Eğer silinen fiş şirketin ilk veya son
   fişiyse `mhsSirket.sirketIlkFisID/sirketSonFisID` sıfırlanır + audit'e
   düşülür.

6. **Snapshot before delete.** Silmeden önce `sil.mhsFis`'e master+detay
   birleşik kopya yazılır (geri çağırma için).

7. **`@belgeyi=0` davranışı.** SP `@belgeyi=0` ile çağrılırsa **sadece detay
   silinir**; master `mhsFisBaslik` ve dış referanslar olduğu gibi kalır.
   Bu garip — büyük ihtimalle "satır temizle, başlığı tekrar oluşturacağım"
   senaryosu için. → **Doğrulanacak.**

---

## 6. Açık Sorular — Birlikte Çözülecek

> Bu liste tablo şemasını canlı çekmeden önce SP'den okuyarak çıkarıldı.
> Doğrulama için `mcp__sqlserver__sql_describe_table` ile tablo tablo bakacağız.

1. **`fisEntTipID`** değerlerinin tam listesi nedir? 6+ var mı? Gerçek
   dağılım ne (`SELECT fisEntTipID, COUNT(*) FROM mhs.mhsFisBaslik GROUP BY 1`)?

2. **`mhs.mhsFis` vs `mhs.mhsFisBaslik`** — tam ilişki şeması (FK var mı,
   `fisID = fisbID` 1:1 mi 1:N mi)?

3. **`cFatTip` kodları** — 1–12, 13, 20–199 aralıklarının tam tanımı?
   `dbo.car` üzerinde lookup tablosu var mı (`carFatTip` gibi)?

4. **`fisHspID`** — DerinSIS hesap planı tablosu hangi şemada (`mhs.hsp`?
   `dbo.muhHesap`?)? Master mi detayda mı (SP arşive `fisHspID`'i detaydan
   yazıyor → detayda).

5. **`fiscID`** — "fiş cari ID" muhtemelen — `car` üzerindeki master cari
   hareketin ID'si mi? entTip=5'te kullanılıyor.

6. **`drn2.izProgID`** kodları — 55=Mhs, 11=Cari görünüyor; tam liste?

7. **`@belgeyi=0`** kullanım senaryosu — gerçekte hangi program bu modda
   çağırıyor? `mhs.mhsFis` boş satırlı master kalmasına yol açar mı?

8. **Soft delete vs hard delete** — `sil.mhsFis` snapshot var ama `mhsFis`
   gerçek `DELETE`. Geri yükleme prosedürü var mı (`mhs.mhsFis_geriYukle`)?

9. **POS entegrasyonu cascade** — entTip=3'te aynı tarih+mağaza diğer fişler
   otomatik siliniyor; bu davranış ne kadar agresif? Yanlışlıkla başka mekanın
   fişini silme riski var mı (`cKod` / `cKodKarsi` filtreleri yeterli mi)?

10. **`fat`** tablosu — schema `dbo` mu `fat` mı? SP'de `dbo` öneki yok ama
    `dbo.car` açıkça yazılmış; bu tutarsızlık belirsizlik yaratıyor.

---

## 7. Sonraki Adımlar (Karar Verilecek)

- [ ] `mhs` ve ilgili `dbo` tablolarının canlı şemasını çekip burayı
      doğrula → `03-tablo-semasi.md`
- [ ] `fisEntTipID` ve `cFatTip` enum tablolarını / referans listelerini
      bul → `04-enum-katalog.md`
- [ ] Modülün OKUMA tarafını (fiş ekle, fiş güncelle, raporlar) keşfet →
      ayrı dosya
- [ ] Hesap planı (`fisHspID` lookup) ve ana hesap akışını çıkar
- [ ] DerinSIS muhasebe modülünün **mantıksal veri modeli** diyagramı
      (Mermaid) → `05-veri-modeli.mmd`
