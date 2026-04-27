# ENVANTER_RAPORU Analiz Bulguları
**Tarih:** 14 Nisan 2026

---

## 1. Tablo Bilgisi

- **Tablo:** `bkm.ENVANTER_RAPORU` (DerinSISBkm)
- **Satır sayısı:** ~41.346 (günde 98 satır ekleniyor)
- **Doldurma zamanı:** Her gece 00:05:05
- **Kaynak Job:** `MaliyetRaporu-Ceren` → Step: `Maliyet_Rapor`
- **İki maliyet tipi:** ÜstFiyat, Ort.Maliyet
- **Kırılım:** KTGR3 (Kategori3 = urnKtgr2) × kdvYuzde → günde 49 satır × 2 tip = 98 satır

## 2. Job Akışı (MaliyetRaporu-Ceren)

```
1. WMS Depo stok  → depo.paletUrnTnm + paletTnm + adres (CK01 hariç)
2. Ürün filtresi  → urnKategori_vw, urnKtgr2ID NOT IN (11,25,23,9,5,6), urnTip=0
3. Mağaza stokları → irsHrk (ehTrhS <= @tarih, ehAltDepo=0, mekan IN 1,4477,4478)
4. Odak Depo      → ent.odak_depo_Stok
5. PIVOT           → [FSM Mğz], [ÖZLÜCE Mğz], [İST YOLU Mğz], [WMS Depo], [Odak Depo]
6. Üst Fiyat      → bkm.TarihtekiUstFiyat(stkID, @tarih) scalar function
7. Ort. Maliyet   → Son 5 alış faturası ort. → fallback: Aktarim.dbo.BKM_STOKLAR_MALIYETLI → fallback: gelecek fatura
8. Final INSERT   → KTGR3 + kdvYuzdesi bazında GROUP BY, 2 set (ÜstFiyat + Ort.Maliyet)
```

### Mekan Eşleşmesi
| mekanID | mekanAd |
|---------|---------|
| 1 | FSM Mğz |
| 4477 | ÖZLÜCE Mğz |
| 4478 | İST YOLU Mğz |

## 3. bkm.TarihtekiUstFiyat Fonksiyonu

```sql
-- Sırasıyla dener:
1. fyt tablosu: fStkID=@stkID, fTarih<=@tarih, fTur=0 → TOP 1 sonrakiFiyat (DESC)
2. fyt tablosu: fStkID=@stkID, fTarih>=@tarih, fTur=0 → TOP 1 sonrakiFiyat (ASC)
3. urn.fiyatS (ürün kartı satış fiyatı)
```

### fyt.fTur Değerleri
| fTur | Adet | Açıklama |
|------|------|----------|
| 0 | 3.887.862 | Üst fiyat (satış/perakende) |
| 1 | 1.906.843 | Alış fiyatı |
| 4 | 9.332.145 | Emek fiyat (BATIK - ölü kod) |

## 4. BULUNAN SORUN: İst.Yolu Negatif Değer

### Belirti
İst.Yolu üst fiyat değeri tüm hafta boyunca **negatif** çıkıyor (~-54M TL).

### Kök Neden
**"Sınav Okulları" kategorisindeki süreli yayın abonelik paketleri.**

22 adet "X. Sınıf Süreli Yayın 2026" ürünü (stkID 1606335-1606356):
- Birim fiyat: 37.930 - 46.061 TL (yıllık abonelik paketi)
- İst.Yolu bakiye: negatif (örn. -711 adet)
- Tek satır etkisi: -711 × 43.403 = **-30.8M TL**
- 22 paketin toplam etkisi: **-300M TL**

### İş Mantığı
- **Öğrenciye satış:** Paket stok koduyla çıkış yapılıyor (irsHrk'da negatif hareket)
- **Yayınevinden alış:** Parça kitap stok kodlarıyla fatura geliyor (farklı stkID'ler)
- Sonuç: Paket koduna hiç giriş olmuyor → bakiye sonsuza kadar negatif

### Çift Taraflı Bozulma

| | Paket Kodları | Parça Kodları |
|---|---|---|
| Ürün çeşit | 54 | 182 |
| Bakiye | 3.883 (ama fiyatla -300M) | 227.588 (+48M TL) |
| Giriş | ❌ yok | ✅ sürekli giriyor |
| Çıkış | ✅ öğrenciye satış | ❌ yok |
| Envanter etkisi | **-300M TL hayalet negatif** | **+48M TL hayalet pozitif** |

Fark (-252M TL) dengelenmiyor çünkü paket fiyatı içinde eğitim hizmeti, online erişim vs. var — bunlar fiziksel ürün değil.

### Kategori Bilgisi (Sorunlu Ürünler)
- urnKtgrID = 78 (KatAna: "Sınav Okul Malzemeleri")
- urnKtgr1ID = 5 (Kategori2: "Genel")
- urnKtgr2ID = 19 (Kategori3: "Sınav Okulları")
- KDV: %0

### Düzeltilmiş İst.Yolu Değeri
| | Mevcut | Düzeltilmiş |
|---|---|---|
| İst.Yolu Üst Fiyat | -53.608.646 TL | **182.157.646 TL** |

## 5. Çözüm Önerileri

### Kısa Vadeli (Job Düzeltmesi)
Job sorgusundaki URUNLER CTE'sine filtre ekle:
```sql
AND NOT (u.urnKtgr2ID = 19 AND u.urnKtgrID = 78 AND u.urnKtgr1ID = 5)
```
Bu, "Sınav Okul Malzemeleri + Genel + Sınav Okulları" üçlüsünü hariç tutar.

### Uzun Vadeli (Kategori Düzeltmesi)
1. Yeni Kategori3 aç: "Sınav Süreli Yayın" (veya "Sınav Abonelik Paketi")
2. 22 süreli yayın paketini + 54 Genel kategorisindeki sanal ürünleri yeni kategoriye taşı
3. Job'daki `NOT IN` listesine yeni Kategori3 ID'sini ekle
4. Parça kodları da ayrı Kategori3'e alınabilir (envanterde kalmaları sorunlu)

### Dikkat
- Sınav Okulları (19) Kategori3'ü tamamen hariç TUTULAMAZ — içinde gerçek kitaplar var (409 ürün, Kategori2=Kitap)
- Sadece Kategori2=Genel (urnKtgr1ID=5) olan alt grup sorunlu

## 6. Haftalık Envanter Özeti (Üst Fiyat)

| Gün | Toplam Adet | Toplam Üst Fiyat (TL) |
|-----|------------|----------------------|
| 07.04 | 13.383.401 | 2.700.396.026 |
| 08.04 | 13.439.864 | 2.707.861.019 |
| 09.04 | 13.436.511 | 2.713.055.686 |
| 10.04 | 13.490.576 | 2.729.567.702 |
| 11.04 | 13.507.283 | 2.738.050.293 |
| 12.04 | 13.466.300 | 2.727.833.795 |
| 13.04 | 13.423.337 | 2.716.921.988 |
| 14.04 | 13.409.484 | 2.709.109.468 |

### Lokasyon Bazlı (14.04)
| Lokasyon | Adet | Üst Fiyat (TL) |
|----------|------|----------------|
| Odak Depo | 7.138.722 | 2.124.887.123 |
| Merkez Depo | 3.271.945 | 333.681.806 |
| İst.Yolu | 1.291.759 | -53.608.646 ⚠️ |
| Özlüce | 1.090.552 | 200.291.061 |
| FSM | 875.189 | 161.046.785 |

### Not
- 12-13 Nisan (hafta sonu) Merkez Depo rakamları birebir aynı (hareket yok veya hesaplama çalışmamış)
- Düzeltme sonrası İst.Yolu: ~182M TL, genel toplam: ~3.0B TL
