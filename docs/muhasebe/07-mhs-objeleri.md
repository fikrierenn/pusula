# mhs Schema — Tam Obje Envanteri

> **Veritabanı:** `DerinSISBkm`
> **Çekim tarihi:** 11.05.2026
> **Toplam:** 92 obje (61 SP + 14 view + 9 function + 8 tablo)
> **Sorgu:** `sys.objects + sys.schemas WHERE schema_name='mhs'`

Aşağıda DerinSIS muhasebe modülünün arka uçtaki tüm yapı taşları kategorilere
göre ayrılmıştır. Hiçbiri ENCRYPTION ile derlenmemiş — kaynaklar açık. **6 ana
operasyon kümesi** var.

---

## 1. CRUD + Onay + Helper (zaten incelenenler)

| Obje | Tür | Notu |
|---|---|---|
| `mhsFisB_ekle` | SP | Master upsert (`@ID=0` insert / `>0` update) — bkz. [`05-CRUD-onay-akisi.md`](./05-CRUD-onay-akisi.md) |
| `mhsFis_ekle` | SP | Detay insert |
| `mhsFis_onay` | SP | Onay / onay-kaldır + audit |
| `mhsFis_sil` | SP | Tüm fişi sil (cascade'li) — bkz. [`02-fis-silme-akisi.md`](./02-fis-silme-akisi.md) |
| **`mhsFis_cikar`** | SP | ⚠️ **YENİ — incelenmedi.** "Çıkar" muhtemelen tek satır silme veya geri yükleme. Bir sonraki tur. |
| `mhsSonYevmiyeNo` | SP | Yeni yevmiye no önerisi |
| `mhsFis_vw` | VIEW | Detay × hsp Borç/Alacak rapor view'ı |

---

## 2. Hesap Planı / Mizan / Yapısal İşlemler

| Obje | Tür | Açıklama |
|---|---|---|
| `mznGuncelle` | SP | Mizan tablosu (`mhs.mzn`) güncelleme — periyodik mizan yenileme |
| `mhsSirala` | SP | Yevmiye no yeniden sıralama — fiş silindikten sonra boş no'ları kapatma |
| `hspKodDegistir` | SP | Hesap kodu yeniden adlandırma (örn. `120.10` → `120.10.001`); tüm referanslar kaskat |
| `hspTasi` | SP | Bir hesabın tüm hareketlerini başka hesaba taşıma (birleştirme) |
| `mhsKapanis` | SP | Mali yıl kapanış işlemi (yansıtma + dönem net karı oluştur) |
| `cariIsle_oto` | SP | Cari otomatik işleme (entegrasyondan üretilmiş cari hareketleri batch işle) |

---

## 3. Raporlama (kritik)

| Obje | Tür | Açıklama |
|---|---|---|
| `mhsGelirTablo` | SP | Gelir tablosu raporu (klasik P&L) |
| **`mhsGelirTabloGiderMerkeziDetayli`** | SP | **Gider merkezi bazlı gelir tablosu** — yönetim raporu altın değerinde |
| `mhsHesap_vw` | VIEW | Hesap bakış view |
| `mhsHesapPlani_vw` | VIEW | Hesap planı (mhsHsp + mhsAnaHsp join) |
| `mhsBakiye_vw` | VIEW | Hesap bakiyeleri |
| `mhsBakiyeAyr_vw` | VIEW | Bakiye ayrıntılı (alt hesap kırılımı) |
| `mhsMizan_vw` | VIEW | Mizan view (Borç/Alacak/Bakiye) |
| `mhsPOSSatisKDV_vw` | VIEW | POS satışı KDV ayrıştırması |

---

## 4. Denge / Kontrol View'ları

`mhsFisB_ekle` ve `mhsFis_ekle` SP'leri denge kontrolü yapmıyor demiştik.
Sistem bu view'larla retrospektif denetim yapıyor olabilir:

| View | İhtimali işi |
|---|---|
| `mhsFisKontrol_vw` | Fiş bütünlüğü (sayı, tarih, kullanıcı vs. tutarsızlık) |
| `mhsFisKontrolBakiye_vw` | Borç ≠ Alacak fişler (denge bozukluğu) |
| `kontrolFaturaMhsFis_vw` | Fatura ↔ mhsFis bağlantısı kopukluk |
| `kontrolCariMhsFis_vw` | Cari ↔ mhsFis bağlantısı kopukluk |
| `mhsEntCiftFat_vw` | Aynı faturadan iki kez mhs fişi (çift kayıt) |
| `mhsEntCiftCar_vw` | Aynı cari hareketten iki kez mhs fişi |
| `mhsEntSilFat_vw` | Silinmiş fatura ama mhs fişi duruyor (orphan) |
| `mhsEntSilCar_vw` | Silinmiş cari ama mhs fişi duruyor (orphan) |

**→ İleride veri temizliği için bu 8 view'ı sırayla query'leyip orphan/dengesiz
durumları çıkarmak mantıklı bir kontrol turu.**

---

## 5. Entegrasyon — Tampon Tablolar

`mhsEnt*` tabloları, kaynak modülden (POS/Cari/Fatura/Firma/Ürün) muhasebe
fişine "ne aktarılacak" eşlemesini tutar. Yani **mapping tabloları**:

| Tablo | Kaynak | Notu |
|---|---|---|
| `mhsEntFat` | dbo.fat | Fatura → mhs fiş eşleşmesi (eMhsFisID) |
| `mhsEntFrm` | dbo.frm | Firma → mhs hesabı (cari kart açılınca hsp kodu) |
| `mhsEntPos` | POS | POS fişleri eşlemesi |
| `mhsEntPosOdm` | POS | POS ödeme satırları |
| `mhsEntPosKsyr` | POS | POS kasiyer hareketleri |
| `mhsEntUrn` | dbo.urn | Ürün → muhasebe maliyet hesabı eşleşmesi |

---

## 6. Entegrasyon — Kontrol SP'leri (3'lü pattern)

Her entegrasyon türü için **üç katmanlı kontrol** var:

| Katman | İşi |
|---|---|
| `_Hata` | Engelleyen tutarsızlıkları döner (örn. KDV oranı yok) |
| `_Uyari` | Engellemez ama dikkat çeker (örn. sıra dışı tutar) |
| (ana ad) | Birleşik denetim |

Bütün liste:

| Tür | Hata SP | Uyarı SP | Ana SP |
|---|---|---|---|
| POS | `mhsEntKontrolPos_Hata` | `mhsEntKontrolPos_Uyari` | `mhsEntKontrolPos` |
| POS Ödeme | `mhsEntKontrolPosOdm_Hata` | `mhsEntKontrolPosOdm_Uyari` | `mhsEntKontrolPosOdm` |
| Cari | `mhsEntKontrolCar_Hata` | `mhsEntKontrolCar_Uyari` | `mhsEntKontrolCar` + `mhsEntKontrolCarKullanici` |
| Cari Fiş | `mhsEntKontrolCarFis_Hata` | `mhsEntKontrolCarFis_Uyari` | `mhsEntKontrolCarFis` |
| Fatura | `mhsEntKontrolFat_Hata` | `mhsEntKontrolFat_Uyari` | `mhsEntKontrolFat` + `mhsEntKontrolFatKullanici` |
| Fatura Ürün | `mhsEntKontrolFatUrun_Hata` | _yok_ | `mhsEntKontrolFatUrun` |

`fn_mhsEntKontrolPos` ek olarak inline TVF (sorgu içinden çağrılabilir).

---

## 7. Entegrasyon — Üretim SP'leri (`mhsEnt_*`)

Kontrol geçtikten sonra gerçek mhs fişlerini bunlar üretiyor:

| SP | Üretim |
|---|---|
| `mhsEnt_pos` | POS satış fişlerini → mhsFisBaslik + mhsFis (entTip=3) |
| `mhsEnt_posOdm` | POS ödemeleri → mhs |
| `mhsEnt_posKsyrOzet` | POS kasiyer özet (özetlenmiş tek mhs fişi) |
| `mhsEnt_posKsyrOzetEDefter` | Aynı, e-Defter formatında |
| `mhsEnt_car` | Cari hareketleri → mhs (entTip=2) |
| `mhsEnt_carFis` | Cari fişler → mhs (entTip=5 — ama BKM'de hiç kullanılmıyor) |
| `mhsEnt_fat` | Faturaları → mhs (entTip=1) |
| `mhsEnt_fatUrun` | Fatura ürün satırlarını → mhs |
| `mhsEnt_fatYD` | Yurtdışı fatura → mhs |
| `mhsEnt_fatYD_IHRCT` | İhracat faturası → mhs |
| `mhsEnt_fatUrun_test` | Test versiyonu (2025-05-23 tarihli) |

### `entTasi*` (taşıma — kaynak referans güncelleme)

Kaynak tablolardan mhs entegrasyon tamponlarına veri taşıma:

| SP | İşi |
|---|---|
| `entTasiPos` / `entTasiPosOdm` / `entTasiPosKsyr` | POS verilerini mhsEnt* tamponlarına |
| `entTasiFat` | Fatura verilerini mhsEntFat'a |
| `entTasiFrm` | Firma verilerini mhsEntFrm'e |
| `entTasiUrn` | Ürün verilerini mhsEntUrn'e |

---

## 8. Yardımcı Fonksiyonlar

| Fonksiyon | Tür | İşi |
|---|---|---|
| `fn_SonDal` | Skalar | TDHP ağaç hiyerarşisinde son seviye (yaprak) hesap kodu |
| `fn_kirilimSonHspKod` | Skalar | Kırılım sonu hesap kodu |
| `fn_HesapBol` | TVF | Hesap kodunu parçalama (örn. "100.10.001" → ["100","10","001"]) |
| `fn_mhsHsp` | Inline TVF | Hesap arama (parametreli) |
| `fn_mhsHesap_Borc` | Skalar | Bir hesabın tarih aralığında Borç toplamı |
| `fn_mhsHesap_Alacak` | Skalar | Aynı, Alacak |
| `fn_magazaKasaDevir` | Inline TVF | Mağaza kasası devir hesabı |
| `mhsHspGdrOndeger` | Skalar | Gider varsayılanı (otomatik atama mantığı) |
| `fn_mhsSonFatListe` | Inline TVF | Bir hesaba bağlı son N fatura listesi |
| `fn_mhsEntKontrolPos` | Inline TVF | POS entegrasyon kontrolü (subquery'de kullanılabilir) |

---

## 9. Tablolar (mhs schema)

| Tablo | Satır | Notu |
|---|---|---|
| `mhsFisBaslik` | 15.278.129 | Master fiş başlığı |
| `mhsFis` | 39.471.113 | Detay (signed) |
| `mhsHsp` | 24.429 | Hesap planı (per-şirket) |
| `mhsAnaHsp` | 390 | TDHP ana hesap katalogu (sistemde gömülü) |
| `mhsSirket` | 6 | Mali şirket / yıl |
| `mhsFisTip` | 4 | Tahsil/Tediye/Mahsup/Yansıtma |
| `mhsFisGrp` | 1 | Genel |
| `mhsEntTip` | 6 | Kullanıcı/Fatura/Cari/POS/Mağaza Kasası/Cari Fiş |
| `mhsEntFat` | _?_ | Fatura→mhs eşleşme tampon |
| `mhsEntFrm` | _?_ | Firma→mhs eşleşme |
| `mhsEntPos` / `mhsEntPosOdm` / `mhsEntPosKsyr` | _?_ | POS tamponları |
| `mhsEntUrn` | _?_ | Ürün→muhasebe tamponu |
| **`mhsYnsFis`** + `mhsYnsFisAyr` | _?_ | **Yansıtma fişi** master+detay (mhsKapanis çıktısı) |
| **`mzn`** | _?_ | **Mizan** (mznGuncelle output — periyodik snapshot) |

---

## 10. Şu Anda Açık Sorular

1. **`mhsFis_cikar` ne yapar?** "Çıkar" → tek satır silme mi, dışarı export mu, geri yükleme mi? Kaynak okumalı.
2. `mhsKapanis` mantığı — hangi hesaplar yansıtılıyor, hangi hesap dönem net karını taşıyor?
3. `cariIsle_oto` — otomatik cari işleme: tetikleyicisi nedir? (job mı UI mı)
4. `mzn` tablosu yapısı — periyodik mi günlük mi, kim okuyor (Power BI?)
5. `mhsYnsFis` — yansıtma fişleri burada arşivleniyor mu, yoksa mhsFisBaslik'te entTip=??
6. **8 kontrol view'ının çıktıları** — bunlar bizim "veri temizliği görevi" listemiz. Tek tek query'lenmeli.
7. Entegrasyon kontrol SP'lerinin 3'lü pattern'ı (Hata/Uyarı/Ana) → çağıranlar ne sıklıkta tetikliyor? (Job mı manuel mi)

---

## 11. Sıradaki Tur — Önerilen Sıra

| Öncelik | İş | Çıktı |
|---|---|---|
| 1 | `mhsFis_cikar` kaynak oku + analiz | 09-fis-cikar-analizi.md |
| 2 | 8 kontrol view'ını sırayla query'le, sonuç var mı? | 10-veri-saglik-kontrolu.md (BKM canlı durumu) |
| 3 | `mhsKapanis` SP analizi | 11-yil-sonu-kapanis.md |
| 4 | `mhsEntKontrolFat_Hata` + `_Uyari` çıktıları (canlı) | 12-fat-mhs-tutarsizliklari.md |
| 5 | `mhsGelirTabloGiderMerkeziDetayli` SP'yi parametreli çalıştır | yönetim raporu örneği |
