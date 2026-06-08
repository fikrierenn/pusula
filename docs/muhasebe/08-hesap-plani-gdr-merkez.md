# Hesap Planı + Gider Merkezi Detayı

> **Veritabanı:** `DerinSISBkm`
> **Çekim tarihi:** 11.05.2026
> **Tablolar:** `mhs.mhsHsp`, `mhs.mhsAnaHsp`, `dbo.frm` (frmTip=10)

DerinSIS hem klasik **Tek Düzen Hesap Planı (TDHP)** ana kataloğunu, hem
BKM'nin kendi alt hesap detaylarını, hem de **departman/mağaza bazlı gider
merkezi** yapısını taşıyor. Bu belge üçünün canlı resmini birleştirir.

---

## 1. TDHP Ana Hesap Katalogu — `mhs.mhsAnaHsp`

390 satır, sistemde gömülü hazır TDHP standardı. `aHspID` 3-haneli TDHP
kodlarına karşılık geliyor.

### Ana gruplar (1-9)

| aHspID | aHspAd |
|---:|---|
| 1 | Dönen Varlıklar (10-19) |
| 2 | Duran Varlıklar (20-29) |
| 3 | Kısa Vadeli Yabancı Kaynaklar (30-39) |
| 4 | Uzun Vadeli Yabancı Kaynaklar (40-49) |
| 5 | Özkaynaklar (50-59) |
| 6 | Gelir Tablosu Hesapları (60-69) |
| 7 | Maliyet Hesapları (70-79) |
| 9 | Nazım Hesaplar (90-99) |

(8 standart TDHP'de "Serbest" — kullanılmıyor.)

### Alt katalog yapısı (toplam 390 kategori)

3-haneli TDHP kodlarının tamamı `mhsAnaHsp`'de hazır geliyor. Aynı isim
kısa-vade / uzun-vade için iki kez tekrar (örn. "Alacak Senetleri" hem 121
hem 221, "Satıcılar" hem 320 hem 420).

**Kritik kategoriler (BKM'de en yoğun kullanılanlar):**

| Kod | Ad | Notu |
|---:|---|---|
| 100 | Kasa | Tüm nakit hareketleri |
| 102 | Bankalar | Banka hesapları (her banka ayrı kart) |
| 120 | Alıcılar | Aktif müşteri carileri |
| 320 | Satıcılar | Aktif tedarikçi carileri |
| 600 | Yurtiçi Satışlar | Brüt satış geliri |
| 610 | Satıştan İadeler (-) | İade düzeltmesi |
| 621 | Satılan Ticari Mallar Maliyeti (-) | COGS |
| 770 | Genel Yönetim Giderleri | OPEX |
| 760 | Pazarlama, Satış ve Dağıtım Giderleri | Pazarlama |

---

## 2. BKM Hesap Planı — `mhs.mhsHsp`

24.429 satır toplam (6 şirket × ~4070 unique hesap). Composite PK
`(hspID, hspSirketID)` — her şirket kendi kopyasını taşıyor.

### `hspTur` ve `hspGdrYontem` — kullanılmayan ileri özellikler

| Kolon | BKM'deki dağılım | Yorum |
|---|---|---|
| `hspTur` | 24.429 satırın **TAMAMI 0** | Hesap türü filtresi BKM'de aktif değil |
| `hspGdrYontem` | 24.429 satırın **TAMAMI 0** | Otomatik gider dağıtım yöntemi seçilmemiş |

→ DerinSIS bu özellikleri sunmuş ama BKM kullanmıyor. UI tarafında "tek tip"
çalışılmış.

### Şirket=6 (2026 aktif yıl) Hesap Dağılımı — top 20

`mhsAnaHsp` ana grup başına `mhsHsp` alt hesap sayısı:

| aHspID | Ana Grup | Alt Hesap Adet | İlk Kod | Son Kod |
|---:|---|---:|---|---|
| **320** | **Satıcılar** | **2879** | 320.10 | 320.10.Z033 |
| **120** | **Alıcılar** | **589** | 120.10 | 120.10.Z005 |
| 300 | Banka Kredileri | 110 | 300.10 | 300.99 |
| 740 | Hizmet Üretim Maliyeti | 90 | 740.00 | 740.60.007 |
| 136 | Diğer Çeşitli Alacaklar | 87 | 136.10 | 136.30 |
| 770 | Genel Yönetim Giderleri | 86 | 770.10 | 770.60.007 |
| 760 | Pazarlama, Satış ve Dağıtım | 86 | 760.10 | 760.60.007 |
| 102 | Bankalar | 86 | 102.10 | 102.60 |
| 400 | Banka Kredileri (UV) | 60 | 400.02 | 400.99 |
| 309 | Diğer Mali Borçlar | 33 | 309.02 | 309.20.Z001 |
| 689 | Diğer Olağandışı Gider/Zarar | 30 | 689.02 | 689.20.020 |
| 180 | Gelecek Aylara Ait Giderler | 25 | 180.10 | 180.99.004 |
| 280 | Gelecek Yıllara Ait Giderler | 25 | 280.10 | 280.99.004 |
| 103 | Verilen Çekler | 21 | 103.10 | 103.20.H001 |
| 360 | Ödenecek Vergi ve Fonlar | 19 | 360.10 | 360.90.001 |
| 321 | Borç Senetleri | 19 | 321.02 | 321.20.001 |
| 191 | İndirilecek KDV | 17 | 191.10 | 191.20.001 |
| 252 | Binalar | 16 | 252.10 | 252.10.015 |
| 159 | Verilen Sipariş Avansları | 16 | 159.10 | 159.10.V001 |
| 391 | Hesaplanan KDV | 15 | 391.02 | 391.20.003 |

Toplam BKM ana grup sayısı sirket=6 için: **95 ana grup** kullanılıyor.

**Operasyonel resim:**
- BKM'nin defterinin ağırlığı **cari** (Satıcılar 2.879 + Alıcılar 589 = 3.5K
  kart). Ürün/maliyet detayı değil — **karşı taraf detayı**.
- Bu cari tablo dbo.frm'le birebir bağ kurmuş olmalı: ~24K müşteri, ~2.5K
  firma → muhasebe defterinde sadece "ekonomik aktif" olanlar görünüyor.
- 770 / 760 / 740 ailesi (gider+maliyet) ~260 detay hesap — BKM yönetim
  raporu altyapısının ne kadar açıldığını gösteriyor.

### Hesap kodu kalıbı

`mhsHsp.hspKod varchar(20)` — TDHP standart kalıbı:
- **3 hane** ana hesap (örn. `100`)
- **2 hane** alt hesap (örn. `100.10`)
- **3 hane** detay (örn. `100.10.001`)
- Ek detay olabiliyor (örn. `120.10.A001` — alfa-numerik müşteri kodu)

**Aynı hspKod birden fazla şirkette → ayrı hspID:**

| hspKod | hspAd | sirket=1 hspID | sirket=6 hspID |
|---|---|---:|---:|
| 100.10 | KASA | 5986 | 23286 |
| 100.10.001 | Merkez TL.Kasa | 2853 | 23285 |
| 101.10 | ALINAN TL.ÇEKLER | 5987 | 23287 |

→ Yıl atladığında hspID değişiyor ama hspKod aynı. Cache'lerde **kod →
ID** map yenilenmeli.

---

## 3. Gider Merkezi — `dbo.frm WHERE frmTip = 10`

Gider merkezleri **firma tablosunun (dbo.frm) içinde frmTip=10 olarak
saklanıyor**. Ayrı bir tablo değil — `frmTipTnm.frmTipID = 10` ('Gider
Merkezi') filtresiyle ulaşılıyor.

### `dbo.frmTipTnm` — Tüm frm tipleri

| frmTipID | frmTipAd | dbo.frm adet |
|---:|---|---:|
| 0 | Firma | 2.503 |
| 1 | Müşteri | **23.953** |
| 2 | Mağaza | 4 |
| 3 | Depo | 7 |
| 4 | Ofis | 1 |
| 5 | Banka-Kasa | 355 |
| 6 | Çalışan | 743 |
| 7 | Gider | 249 |
| 8 | Hizmet | 38 |
| 9 | Sevk Adresi | 21.933 |
| **10** | **Gider Merkezi** | **32** |
| 11 | Demirbaş | _yok_ |

Toplam dbo.frm: 49.818 satır — 11 farklı varlık karma.

### BKM'nin 32 Gider Merkezi (kullanım yoğunluğuyla)

`mhs.mhsFis.fisGdrMerkez` üzerinden:

#### Mağazalar (en yoğun GM ailesi)

| frmID | Kod | Ad | mhsFis kullanım |
|---:|---|---|---:|
| 4587 | GIst | İstanbul Yolu Mağaza | **90.667** |
| 4581 | GFsm | Fsm Mağaza | **88.835** |
| 4582 | GOzl | Özlüce Mağaza | **81.381** |

#### Kafeler (mağaza içi kafe)

| frmID | Kod | Ad | mhsFis kullanım |
|---:|---|---|---:|
| 4627 | GKafeFsm | Kafe Fsm | 9.382 |
| 4629 | GKafeIst | Kafe İstanbul Yolu | 9.126 |
| 4628 | GKafeOzl | Kafe Özlüce | 8.819 |
| 4626 | GKafe | KAFE (genel) | 2 |

#### Merkez departmanları

| frmID | Kod | Ad | mhsFis kullanım |
|---:|---|---|---:|
| 4630 | GMerkezYonetim | Merkez Yönetim | 6.608 |
| 4621 | GEticaret | E-Ticaret | 5.711 |
| 4639 | GMerkezDiger | Merkez Diğer Genel Müdürlük | 4.314 |
| 4637 | GMerkezIdari | Merkez İdari İşler | 2.625 |
| 4634 | GMerkezSatis | Merkez Satış Operasyon | 2.515 |
| 4633 | GMerkezBim | Merkez Bilgi Teknolojileri | 2.448 |
| 4631 | GMerkezMusteri | Merkez Müşteri İlişkileri | 2.446 |
| 4638 | GMerkezMali | Merkez Mali İşler | 2.414 |
| 4635 | GMerkezPaz | Merkez Reklam ve Pazarlama | 2.389 |
| 4636 | GMerkezInk | Merkez İnsan Kaynakları | 2.382 |
| 4588 | GMerkezSat | Merkez Satın Alma | 2.361 |
| 4632 | GMerkezEticaret | Merkez E-Ticaret Lojistik | 2.247 |
| 4579 | GMerkez | Genel Müdürlük | 1.375 |

#### 2024+ eklenmiş yeni GM'ler (yeniden yapılanma sinyali)

| frmID | Kod | Ad | mhsFis kullanım |
|---:|---|---|---:|
| 8264 | GMerkezKurumsal | Merkez Kurumsal İletişim | 325 |
| 8263 | GMerkezYönetim | Merkez Yönetim Ortak Alan | 271 |
| 8262 | GMerkez Süreç | Merkez Süreç Yönetim | 78 |

#### Mağaza alt-departmanları (tasarımda var, pratikte ÖLÜ)

Bu 9 GM açılmış ama **0-1 kayıt** taşıyor — operasyonda aktif değil:

| Kod | Kayıt |
|---|---:|
| GFsmKitap, GOzlKitap, GIstKitap | 63, 64, 62 |
| GFsmKirtasiye, GOzlKirtasiye, GIstKirtasiye | 1, 1, 1 |
| GFsmOyuncak, GOzlOyuncak, GIstOyuncak | 0, 1, 0 |

→ **Karar:** ya sil (kafa karışıklığı) ya operasyon sürecini devreye al.
Şu hâliyle yapısal gürültü.

#### GENEL (atanmamış)

| Değer | Anlam | mhsFis kullanım |
|---:|---|---:|
| 0 | GENEL (frm.frmKod='GENEL', frmAd='GENEL', frmTip=0 — gider merkezi değil!) | **39.142.199** |

⚠️ **Kritik gözlem:** Tüm `mhs.mhsFis` satırlarının %99'u (39.1M / 39.5M)
**gider merkezi atanmamış**. Sadece ~329K satır gerçek bir GM'ye işaret
ediyor.

**Sonuç:** Gider merkezi tabanlı analiz BKM'de **sadece gider/maliyet
hesaplarında** anlamlı. Kasa/banka/cari hareketleri büyük ölçüde GENEL
(=0) ile yazılmış. Yönetim raporu için filtre: `WHERE fisGdrMerkez > 0`.

---

## 4. Karma Soru: Gider Merkezi × Hesap Planı

`mhsGelirTabloGiderMerkeziDetayli` SP'sinin altyapısı budur:

```sql
-- Bir GM'nin bir hesap ailesindeki toplamı
SELECT h.hspKod, h.hspAd,
       SUM(CASE WHEN m.fisTutar < 0 THEN -m.fisTutar ELSE 0 END) AS borc,
       SUM(CASE WHEN m.fisTutar > 0 THEN  m.fisTutar ELSE 0 END) AS alacak
FROM   mhs.mhsFis m
JOIN   mhs.mhsHsp h ON h.hspID = m.fisHspID
WHERE  m.fisSirketID    = 6
  AND  m.fisGdrMerkez   = ?            -- GM frmID
  AND  h.hspKod LIKE '770.%'           -- ya da '760.%', '740.%' vs.
  AND  m.fisTarih       BETWEEN ? AND ?
GROUP BY h.hspKod, h.hspAd
```

770/760/740/630-689 ailesi gider merkezi analizine en uygun hesaplar.

---

## 5. Pratik Sorgular (kullanıma hazır)

```sql
-- Bir GM'nin yıllık gider toplamı
SELECT f.frmAd AS gider_merkezi,
       SUM(CASE WHEN m.fisTutar > 0 THEN m.fisTutar ELSE 0 END) AS toplam_gider
FROM   mhs.mhsFis m
JOIN   dbo.frm f ON f.frmID = m.fisGdrMerkez
JOIN   mhs.mhsHsp h ON h.hspID = m.fisHspID
WHERE  m.fisSirketID = 6
  AND  f.frmTip = 10
  AND  h.hspKod LIKE '7%'             -- 7xx maliyet/gider hesapları
  AND  m.fisTarih >= '01.01.2026'     -- DMY!
GROUP BY f.frmAd
ORDER BY toplam_gider DESC

-- Hesap kodu → tüm şirketlerdeki hspID listesi
SELECT h.hspSirketID, s.sirketAd, s.sirketDonem, h.hspID, h.hspKod, h.hspAd
FROM   mhs.mhsHsp h
JOIN   mhs.mhsSirket s ON s.sirketID = h.hspSirketID
WHERE  h.hspKod = '100.10.001'

-- BKM aktif hesap planı (sirket=6) — hangi ana hesap ailesinde kaç alt hsp
SELECT a.aHspAd,
       COUNT(*) AS alt_hsp_adet,
       SUM(COUNT(*)) OVER () AS toplam_alt_hsp
FROM   mhs.mhsHsp h
JOIN   mhs.mhsAnaHsp a ON a.aHspID = h.hspAnaID
WHERE  h.hspSirketID = 6
GROUP BY a.aHspID, a.aHspAd

-- "Atanmamış" gider merkezli mhsFis kayıtlarının yıl-ay kırılımı
SELECT YEAR(fisTarih) yil, MONTH(fisTarih) ay,
       COUNT(*) toplam, SUM(CASE WHEN fisGdrMerkez = 0 THEN 1 ELSE 0 END) genel
FROM   mhs.mhsFis
WHERE  fisTarih >= '01.01.2025'      -- DMY!
GROUP BY YEAR(fisTarih), MONTH(fisTarih)
```

---

## 6. Açık Sorular / Sıradaki Tur

1. **Mağaza alt-GM'leri (Kitap/Kırtasiye/Oyuncak) niye ölü?** İş süreci
   mi başlatılmamış, yoksa sonradan kapatılmış mı?
2. **2024+ eklenen 3 GM** (Süreç Yönetim, Yönetim Ortak Alan, Kurumsal
   İletişim) — hangi gider hesaplarına bağlı? Yeni dağıtım kuralı var mı?
3. `mhsHspGdrOndeger` skalar fonksiyon ne yapıyor? Hesap kodu → varsayılan
   GM mapping'i tutuyor olabilir.
4. **fisGdrMerkez = 0** istatistiği — sadece kasa/banka mı, yoksa gerçek
   gider hesaplarında da var mı? Bunu drill-down ile öğrenebiliriz —
   eğer 770.x/760.x'de bile %99 GM atanmamışsa BKM gider merkezi
   raporlamasını gerçekte kullanmıyor demektir.
