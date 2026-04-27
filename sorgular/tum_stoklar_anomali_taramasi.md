# Tüm Stoklar — Anomali/Abartı Taraması
**Tarih:** 14 Nisan 2026
**Kriter:** |Bakiye × ÜstFiyat| > 1.000.000 TL → tek ürünün envantere devasa etki ettiği durumlar
**Kapsam:** Envanter Job'ının baktığı tüm kategoriler (urnKtgr2ID NOT IN 11,25,23,9,5,6), urnTip=0

---

## Anomali Kategorileri

### 🔴 A. HAYALET NEGATİFLER (-300M TL)
Bakiyesi eksiye gitmiş, fiyat yüksek → çıkış var giriş yok.

**Sınav Okulları süreli yayın paketleri** (22 ürün, daha önceki raporda detaylı):
- Toplam: **-299.9M TL**
- Hepsi İst.Yolu'nda
- Kök neden: Paket koduyla çıkış, parça koduyla giriş

**Diğer Sınav Okulları negatifleri:**
| stkID | Ürün | Üst Fiyat | Bakiye | Tutar |
|---|---|---|---|---|
| 227386 | Duyun Sesimi (9786059198882) | 2.750 | -510 | **-1.402.500** |
| 1668021 | Options 1 Student's Book (9783711402028) | 2.750 | -495 | **-1.361.250** |

→ Aynı ürün farklı barkodla (1673526 Options 1 +506 adet, 1668021 Options 1 -495 adet). **Barkod/stkID karmaşası** var. Envanter nötr ama ERP'de 2 ayrı kart olduğu için anlamsız.

---

### 🟡 B. HAYALET POZİTİFLER — SINAV OKULLARI

Tek mağazada (İst.Yolu) sırf birikmiş, hiç çıkış yok. Çıkışı öğrenci ile paketten olduğu için bunlar da kalıcı stokta duruyor:

| stkID | Ürün | Üst Fiyat | Bakiye | Tutar |
|---|---|---|---|---|
| 1546680 | BÇÜ 6 YAŞ COSMOLAND EĞİTİM SETİ TÜRKÇE | 3.750 | 1.158 | **4.342.500** |
| 1681867 | KEŞŞİF KUTUSU BİLİM PORTALI ETKİNLİK SETİ | 750 | 4.474 | **3.355.500** |
| 1546678 | BÇÜ 5 YAŞ COSMOLAND EĞİTİM SETİ İNGİLİZCE | 3.750 | 741 | **2.778.750** |
| 1619966 | ÜÇDÖRTBEŞ ALLSTAR LGS (ONLİNE EĞİTİM SİSTEMİ) | 2.000 | 1.089 | **2.178.000** |
| 1605974 | Eng Time Activity Book 6 Yaş | 3.900 | 480 | **1.872.000** |
| 1559974 | Sınav 9.Sınıf Konu/Soru Modülü | 500 | 3.494 | **1.747.000** |
| 1559992 | Sınav 3.Sınıf Konu/Soru Modülü | 360 | 4.720 | **1.699.200** |
| 1559991 | Sınav 2.Sınıf Konu/Soru Modülü | 340 | 4.469 | **1.519.460** |
| 1559971 | Sınav 10.Sınıf Konu/Soru Modülü | 500 | 2.938 | **1.469.000** |
| 1675708 | SINAV SIDE TO SIDE TRICKY WORDS YEAR 1 | 400 | 3.551 | **1.420.400** |
| 1673526 | Options 1 Student's Book (9783711405425) | 2.750 | 506 | **1.391.500** |
| 1560100 | Sınav 9.Sınıf Flıpıt | 160 | 7.786 | **1.245.760** |
| 1560005 | Sınav 5.Sınıf Outside Re-Cap Yeşil | 160 | 7.517 | **1.202.720** |
| 1560097 | Sınav 1.Sınıf İlk Okuma Kitabım | 200 | 5.950 | **1.190.000** |
| 1675706 | SINAV SIDE TO SIDE PBL FASİKÜL | 400 | 2.970 | **1.188.000** |
| 1560010 | Sınav 4.Sınıf Outside Re-Cap Yeşil | 160 | 7.310 | **1.169.600** |
| 1605978 | Eng Time Activity Book 4-5 Yaş | 3.900 | 290 | **1.131.000** |
| 1559977 | Sınav 5.Sınıf Konu/Soru Modülü | 240 | 4.516 | **1.083.840** |

**Toplam hayalet pozitif (Sınav Okulları):** ~**+30.0M TL**

Dikkat: Bunlar Kategori3=Sınav Okulları ama negatif paketlerden farklı urnKtgr1ID'ye (2=Kitap) düşmüş olabilir — yani "pek bunların girişleri normal ürün" dediğin grup burası. Öğrenciye paket üzerinden verildiği için envanterden hiç düşmüyor → WMS/İst.Yolu'nda kalıcı şişme.

---

### 🟠 C. WMS'TE ABARTILI BİRİKEN NORMAL ÜRÜNLER
Bunlar kategori sorunu değil — ya gerçekten fazla sipariş verilmiş ya yazım/fiyat hatası olabilir:

| stkID | Ürün | Üst Fiyat | WMS Bakiye | Tutar | Değerlendirme |
|---|---|---|---|---|---|
| 1697911 | Mileo Fon Kartonu 160gr 50x70 | 1.999 | 800 | 1.6M | ⚠️ Birim fiyat çok yüksek (1.999 TL fon kartonu? kontrol) |
| 1701281 | Funni Go Flowers (Oyuncak) | 199 | 6.048 | 1.5M | ⚠️ 6K adet WMS'te — derin stok |
| 1590653 | The Edd Duygulu Mini Not Defter | 15 | 97.178 | 1.5M | ⚠️ **97 bin adet** tek üründe — anormal yığılma |
| 1493424 | Mas 1791 Termal Rulo 56X16 | 119 | 11.547 | 1.4M | Tüketilen bir ürün, muhtemelen normal |
| 1521927 | Kenko KK-613D Dijital Saat | 169 | 5.409 | 1.3M | ⚠️ 5K adet dijital saat — yavaş döner |
| 249804 | Adel Blackline Versatil 3'lü Set | 279 | 4.070 | 1.3M | Kontrol önerilir |
| 1689676 | Keychain 6'lı Süs | 149 | 7.340 | 1.2M | ⚠️ 7K adet anahtarlık |
| 1539153 | Touch Marker | 20 | 49.696 | 1.1M | ⚠️ **50 bin adet** marker — anormal |
| 1661284 | Mas 6464 Fosforlu Kalem 6 Renk | 249 | 4.296 | 1.1M | Kontrol önerilir |

---

## Ajanda — Sorgulanması Gereken Ürünler

### Öncelik 1: Kategori Yapısal Düzeltme
**Sınav Okulları** Kategori3'ü envanter raporu için kirli. 3 farklı durum var:
- (a) Paket kodu → negatif giden 22 ürün (-300M TL) → Job'dan çıkar
- (b) Parça/modül → pozitifte kalan ~18 ürün (+30M TL) → bunlar da envanterden çıkarılmalı (öğrenci üzerinden fiili tüketim var)
- (c) Normal kitap satışı (Duyun Sesimi, Options 1 gibi) → bunlar kalsın ama barkod/stkID duplikasyonu var (1673526 vs 1668021) → IT'ye bildirilmeli

**Aksiyon:** "Sınav Süreli Yayın" diye yeni bir Kategori3 aç, (a)+(b) buraya taşı, Job'dan exclude et.

### Öncelik 2: Fiziksel Sayım İhtiyaçları (Operasyonel)
WMS'te birikmiş anormal yüksek adetli SKU'lar:
- The Edd Duygulu Mini Not Defter (97.178 adet) — gerçekten bu kadar var mı?
- Touch Marker (49.696 adet) — fiyatı 20 TL ama adet anormal
- Mileo Fon Kartonu (800 adet × **1.999 TL**) — fiyat 1999 TL olması doğru mu? (Belki 19.99 TL girilecekken 1999 yazıldı)

### Öncelik 3: stkID Duplikasyonu (Veri Kalite)
Aynı ürün (Options 1 Student's Book) iki farklı stkID'de:
- 1673526 (barkod: 9783711405425) → +506 adet
- 1668021 (barkod: 9783711402028) → -495 adet
→ Tek ürüne konsolide edilmeli, aksi takdirde stok ters işlem yapıldığında hiç görünmüyor.

---

## Özet Tablo

| Anomali Tipi | Ürün Sayısı | Net Tutar Etkisi |
|---|---:|---:|
| A. Sınav Paketleri hayalet negatif | 22 | **-299.9M TL** |
| A. Sınav Okulları kitap negatif | 2 | -2.8M TL |
| B. Sınav Okulları hayalet pozitif | ~18 | **+30.0M TL** |
| C. WMS'te şüpheli yığılma (fiyat/adet) | ~3 | +4.3M TL |
| **Net Envanter Kirliliği** | **~45** | **~-268M TL** |

Düzelme sonrası beklenen envanter toplamı: **~3.0 milyar TL** (şu an 2.7 milyar TL).
