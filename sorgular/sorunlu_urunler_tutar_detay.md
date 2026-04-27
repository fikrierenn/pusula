# Sorunlu Ürünler — Tutar vs Eksi Düşme Detayı
**Tarih:** 14 Nisan 2026
**Filtre:** urnKtgrID=78 AND urnKtgr1ID=5 AND urnKtgr2ID=19 (Sınav Okul Malzemeleri > Genel > Sınav Okulları)

---

## Özet

- **Eksiye düşüren ürün sayısı:** 22 (hepsi İst.Yolu'nda)
- **Toplam eksi etkisi:** **-299.925.747 TL**
- **Diğer 171 ürün:** Bakiye=0 veya hareket yok → envantere etki etmiyor
- **FSM & Özlüce:** Bu paket kodlarında hiç hareket yok → NULL

## Eksiye Düşüren 22 Paket (İst.Yolu)

| # | stkID | Ürün Adı | Üst Fiyat | Bakiye | Tutar (TL) |
|---|-------|----------|-----------|--------|------------|
| 1 | 1606346 | 8. SINIF SÜRELİ YAYIN 2026 | 43.403 | -711 | **-30.859.533** |
| 2 | 1606337 | 3. SINIF SÜRELİ YAYIN 2026 | 44.842 | -668 | **-29.954.456** |
| 3 | 1606336 | 2. SINIF SÜRELİ YAYIN 2026 | 46.062 | -639 | **-29.433.465** |
| 4 | 1606335 | 1. SINIF SÜRELİ YAYIN 2026 | 46.020 | -587 | **-27.013.822** |
| 5 | 1606338 | 4. SINIF SÜRELİ YAYIN 2026 | 43.986 | -484 | **-21.289.224** |
| 6 | 1606347 | 9. SINIF SÜRELİ YAYIN 2026 | 39.002 | -513 | **-20.008.026** |
| 7 | 1606340 | 5. SINIF SÜRELİ YAYIN 2026 | 38.713 | -499 | **-19.317.787** |
| 8 | 1606349 | 10. SINIF SÜRELİ YAYIN 2026 | 37.930 | -415 | **-15.740.950** |
| 9 | 1606342 | 6. SINIF SÜRELİ YAYIN 2026 | 40.039 | -372 | **-14.894.508** |
| 10 | 1606355 | 12. SINIF FEN SAYISAL SÜRELİ YAYIN 2026 | 42.816 | -320 | **-13.701.120** |
| 11 | 1606344 | 7. SINIF SÜRELİ YAYIN 2026 | 39.083 | -299 | **-11.685.817** |
| 12 | 1606356 | 12. SINIF EŞİT AĞIRLIK SÜRELİ YAYIN 2026 | 42.638 | -227 | **-9.678.826** |
| 13 | 1606341 | 5. SINIF DEMİRCİ ÖZLÜCE BALAT SÜRELİ YAYIN 2026 | 38.713 | -250 | **-9.678.250** |
| 14 | 1606339 | 4. SINIF DEMİRCİ ÖZLÜCE BALAT SÜRELİ YAYIN 2026 | 43.986 | -219 | **-9.632.934** |
| 15 | 1606351 | 11. SINIF FEN SAYISAL SÜRELİ YAYIN 2026 | 40.233 | -231 | **-9.293.823** |
| 16 | 1606343 | 6. SINIF DEMİRCİ ÖZLÜCE BALAT SÜRELİ YAYIN 2026 | 40.039 | -221 | **-8.848.619** |
| 17 | 1606345 | 7. SINIF DEMİRCİ ÖZLÜCE BALAT SÜRELİ YAYIN 2026 | 39.083 | -199 | **-7.777.517** |
| 18 | 1606353 | 11. SINIF EŞİT AĞIRLIK SÜRELİ YAYIN 2026 | 39.595 | -125 | **-4.949.375** |
| 19 | 1606350 | 10. SINIF İHSANİYE SÜRELİ YAYIN 2026 | 37.930 | -72 | **-2.730.960** |
| 20 | 1606348 | 9. SINIF İHSANİYE SÜRELİ YAYIN 2026 | 39.002 | -64 | **-2.496.128** |
| 21 | 1606354 | 11. SINIF İHSANİYE EŞİT AĞIRLIK SÜRELİ YAYIN 2026 | 39.595 | -48 | **-1.900.560** |
| 22 | 1606352 | 11. SINIF İHSANİYE SAYISAL SÜRELİ YAYIN 2026 | 40.233 | -26 | **-1.046.058** |
| | | **TOPLAM** | | **-7.389** | **-299.931.758** |

## Bulgular

1. **Tek lokasyon:** Hepsi sadece İst.Yolu'nda hareket görmüş. FSM ve Özlüce'de bu paket kodları hiç kullanılmamış.
2. **Nominal adet büyük değil** (-7.389 adet) ama **fiyat yüksek** (37K-46K TL) → tutarsal etki devasa.
3. **En ağır 5 ürün** toplam etkinin **%46'sını** oluşturuyor: 8/3/2/1/4. Sınıf Süreli Yayın.
4. **İhsaniye + Demirci özel varyantları** da var (bunlar mağaza/şube özelinde paketler).

## Ayıklama Filtresi (Job'a Eklenecek)

```sql
-- Mevcut:
WHERE U.urnKtgr2ID not in (11,25,23,9,5,6)

-- Eklenmeli:
AND NOT (U.urnKtgrID = 78 AND U.urnKtgr1ID = 5 AND U.urnKtgr2ID = 19)
```

Bu tek satır 22 paketi job'dan dışlar → İst.Yolu üst fiyatı **-53.6M TL → +182.2M TL**'ye düzelir.

## Not

Envanter_Raporu'nda sıfır ya da hareketsiz kalan 171 diğer ürün (BKM SINAV SİPARİŞ kodlu 0.01 TL ürünler + eski yıl paketleri) şu an **zarar vermiyor** ama kategori düzeltmesi yapılmazsa gelecek dönemlerde risk taşıyor. Uzun vadede yeni Kategori3 ("Sınav Süreli Yayın") açılıp tüm bu 193 ürünün taşınması en temiz çözüm.
