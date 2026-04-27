# BKM Kitap Operasyon Bilgi Tabanı

BKM Kitap'a özgü operasyonel bağlam skill'i. İş süreçleri, entegrasyon akışları, ödeme/sipariş/fiyat kuralları, terminoloji ve sistem mimarisi bilgilerini içerir.

## Tetikleme Koşulları
"BKM", "BKM Kitap", "kitap satış", "DerinSIS", "Tsoft entegrasyon", "Emek entegrasyon", "kitap sipariş", "kitap fiyat", "e-ticaret entegrasyon", "B2C sipariş" gibi ifadelerde bu skill devreye alınmalı.

---

## 1. Şirket Profili

**BKM Kitap**: Kitap perakende ve e-ticaret şirketi. Fiziksel mağazalar (Merkez Depo, FSM, Özlüce) ve Tsoft tabanlı e-ticaret sitesi üzerinden B2C satış yapıyor.

**ERP Sistemi**: DerinSIS (DerinBilgi tarafından geliştirilmiş özel ERP)

**Temel Entegrasyonlar**:
- **Emek Yayın Dağıtım**: Ana kitap tedarikçisi — ürün, fiyat ve stok verisi bu kanaldan gelir
- **Tsoft**: E-ticaret platformu — ürün, fiyat, stok, görsel ve sipariş verisi karşılıklı senkronize edilir
- **İYS (İleti Yönetim Sistemi)**: Müşteri izin yönetimi (mail, SMS, arama)

---

## 2. Veritabanı Yapısı

| Veritabanı | İçerik |
|---|---|
| **DerinSISBkm** | Ana ERP veritabanı (stok, sipariş, fatura, cari, fiyat) |
| **DerinSISBkmCrm** | CRM veritabanı (müşteri, adres, izin, iletişim) |
| **DerinSISBkmWeb** | Görsel veritabanı (ürün görselleri) |
| **BKMDATA** | BKM'nin kendi veritabanı (customers tablosu, Tsoft kaynak veri) |

---

## 3. Sabit ID'ler ve Referanslar

| Tanım | Değer | Açıklama |
|---|---|---|
| Entegrasyon Kullanıcı ID | **137** | Tüm entegrasyon işlemlerinde bu kullanıcı kullanılır, log'larda ayırt edici |
| Sistem Kullanıcı ID | **1** | Otomatik hesap gibi adımlarda |
| STM (Sanal Torba Müşteri) ID | **4590** | Bireysel (VN olmayan) müşterilerin sipariş/irsaliye/fatura belgelerinde firmaID olarak kullanılır |

### Ödeme Tanımları

| cpID | Ödeme Adı | cpFirma | cpCariTip | eArsivId |
|---|---|---|---|---|
| 1 | İyzico | 4594 | 103 | 48 |
| 2 | PTT Kapıda | 4641 | 100 | 10 |

**Kural**: Kapıda ödeme (cpID=2) için `sip_eklendi` çalıştırılmaz, ödeme kaydı faturalama sonrası üretilir.

---

## 4. Emek Entegrasyon Süreci

Emek Yayın Dağıtım'dan kitap verileri DerinSIS'e aktarılır.

### Akış: ent.emekUrunAktarim

1. **Yeni ürün insert** — Marka ve yazar tanımları → Firma-marka indirim ilişkisi → Çoklu firma tanımı → Barkod ekleme → Ürün adı güncelleme
2. **Diğer bilgiler** — Emek durum, ön sipariş, ön sipariş tarihi
3. **Stok var/yok** — Hareket tablosundan son stok değeri güncellenir (log tarihine göre sadece aktarım sonrası hareket görenler)
4. **Görsel** — Emek'ten yeni görseller DerinSISBkmWeb'e aktarılır

### Fiyat Aktarımı: ent.emekFiyatAktarim

5. **Fiyat** — Liste fiyatı → web fiyatı hesaplanır, firma marka indirimlerine göre alış/satış fiyatı belgeleri üretilir. Yeni ürünlerde piyasa marjı marka öndeğerinden gelir.

### Ürün Birleştirme
Emek'ten değişen barkodlarla gelen ürünler yeni satır olarak gelir. Satın alma "ürün birleştirme" işlemi yaparak tüm hareketleri ve barkod tanımlarını yeni kayda taşır. Tsoft aktarım tablosunda olup DerinSIS'ten silinmiş ürünler Tsoft'ta pasife alınmalı.

---

## 5. Tsoft E-Ticaret Entegrasyonu

### Ürün Tablosu
**[ent].[tsoft_urun]** — DerinSIS tarafından oluşturulur, BKM tarafından güncelleme SP'leri kullanılarak güncellenir.

### Entegrasyon View'ları

| View | İçerik |
|---|---|
| `ent.urun_degisen_vw` | Değişen ürün bilgileri (ön sipariş bilgisi dahil) |
| `ent.urun_fiyat_vw` | Satış fiyatları (KDV dahil, kampanya) |
| `ent.urun_gorsel_vw` | Ürün görselleri |
| `ent.urun_liste_fiyat_vw` | Liste fiyatları |
| `ent.urun_stok_vw` | Merkez depo stokları (eksi stok = "0") |
| `ent.urun_yeni_vw` | Yeni ürünler |
| `ent.kampanyaUrunListesi_vw` | Kampanya ürün listesi (bölen kampanya türü) |

### Entegrasyon SP'leri

| SP | İşlev |
|---|---|
| `[ent].[urun_apilogyaz]` | Entegrasyon log yazma |
| `[ent].[urun_tsofturunId]` | Tsoft urunId güncelleme |
| `[ent].[urun_tsoft_durumyaz]` | Entegrasyon durum bilgisi yazma |

### API Entegrasyon Tipleri (api_entegrasyon_tip)

| Tip | View |
|---|---|
| 1 | ent.urun_degisen_vw |
| 2 | ent.urun_fiyat_vw |
| 3 | ent.urun_gorsel_vw |
| 4 | ent.urun_liste_fiyat_vw |
| 5 | ent.urun_stok_vw |
| 6 | ent.urun_yeni_vw |

### API Durum Kodları (api_durum)

| Kod | Durum |
|---|---|
| 1 | DerinSIS (işlenmiş) |
| 2 | API Hata |
| 3 | API Başarılı |

---

## 6. Sipariş Süreci (B2C)

### Temel Akış

1. **Müşteri kaydı**: `ent.B2C_musteri_ekle` → VN 10/11 hane + e-Fatura mükellefiyse ERP cari açılır, değilse CRM'de müşteri kaydı (STM ID=4590 kullanılır)
2. **Adres kaydı**: `ent.B2C_musteriAdresSevk_ekle` (sevk) + `ent.B2C_musteriAdresFatura_ekle` (fatura)
3. **Sipariş başlık**: `ent.B2C_sip_ekle` → siparisID döner
4. **Sipariş satır**: `ent.B2C_sipSatir_ekle` → Satır sıra numarası 1'den başlar, atlamasız
5. **Ödeme kaydı**: `dbo.sip_eklendi` (kapıda ödeme hariç)
6. **Hazırlama/Kargo**: sipID bildirilir → irsaliye ve fatura oluşturulur

### Müşteri Eşleşme Kuralları
- Müşteri eşleşme: `mst.mstkod` = Tsoft müşteri ID
- VN 10 hane = şirket → standart firma (frm) mantığı
- VN yoksa/bireysel → STM ID=4590 ile ilerle, e-Arşiv bilgileri CRM'de saklanır
- Firma kod alanı: VN + boşluk + Tsoft customerID (tekrar önleme)

### Sipariş İptali
- **Belge iptali**: `dbo.sip_iptal(@eID, @kKisi)` — sipariş açıksa (irsaliye/fatura bağlantısı yoksa) belge tutarı kadar cariye ters kayıt
- **Satır iptali**: `ent.B2C_sipSatir_iptal(@eID, @kKisi, @barkod)` — satır tutarı kadar cariye ters kayıt
- **Satır düzenleme**: `ent.B2C_sipSatir_duzenle` — adet azaltma yönlü, fark kadar cariye ters kayıt
- **Ürün değiştirme**: `dbo.sipSatirUrn_Degistir` (tekil) / `dbo.sipSatirUrn_DegistirToplu` (toplu)

**Kural**: Kapıda ödeme siparişlerinde ters kayıt atılmaz.
**Kural**: Set ürünler sipariş satırlarına tek tek yazılır, satır açıklamasına set açıklaması gider.

---

## 7. Fiyat Yönetimi

### Fiyat Yapısı

| Fiyat No | Tanım |
|---|---|
| Fiyat 1 | Perakende liste fiyatı |
| Fiyat 3 | E-ticaret satış fiyatı (Web Fiyat) |
| Fiyat 4 | E-ticaret üst fiyat (liste) |

### Alış Fiyatı
- Fiyat listeleri + özel fiyat listeleri + firma marka indirimleri
- Emek entegrasyonundan gelen fiyatlar: nedeni **4-'Emek ent'**, tarihsel ve onaylı
- Marka indirimi düzenlendiğinde: nedeni **5-Marka indirim listesi**, otomatik üretilir

### Satış Fiyatı
- Fiyat listeleri + özel fiyat listeleri + marka indirim yüzdesi kampanyaları
- Özel fiyat listeleri: iki tarih arası, mağaza koşulu verilebilir
- Emek fiyatları etkinleştirilince: ürün satış fiyatı güncellenir + tarihçe + kasa gönderim işareti

### E-Ticaret Fiyatlama
- Web fiyatı = Fiyat 1 × (1 - piyasa marjı)
- E-ticaret üst fiyatı varsa: Fiyat 4 üzerinden hesaplanır
- Kampanya: liste fiyatı üzerine yüzde veya sabit fiyat (net fiyat olarak Tsoft'a aktarılır)
- E-ticaret özel liste fiyatı varsa web fiyatı hesaplamada baskın olur

### Kitaplar İçin Özel
- Emek'ten satış fiyatı = liste fiyat olarak gelir
- Satış fiyatı alış fiyatı alanına da yazılır
- İskonto firma tanımından otomatik gelir

---

## 8. Sipariş Süreci Kuralları (Günlük Web)

### Stok Hesaplama
- Depo stok = Merkez Depo + FSM + Özlüce
- A ve B grubu ürünlerde mağazalara sipariş geçilmez
- Diğer gruplarda: Mağaza stok - 1 (her mağaza için)
- Mağaza sıralı çalışır (sıra bildirilir)
- Karşılanmayan sipariş bir sonraki gün firma önerisi olarak geçilir

---

## 9. Müşteri İzin Yönetimi (İYS)

### Yeni Müşteri İzin Bilgileri
- Mail: `IsEmailNotificationOn` (true/false, boş = Hayır)
- SMS: `IsSmsNotificationOn` (true/false, boş = Hayır)
- Arama: `IsPhoneCallNotificationOn` (true/false, boş = Hayır)
- Kanal: HS_WEB
- Tarih: DerinSIS'e aktarıldığı tarih

### İzin Güncelleme Kuralı
BKM tarafındaki izin değişiklik tarihi > DerinSIS'teki son izin değişiklik tarihi VE izin durumu farklıysa → BKM'deki bilgi alınır.

### İYS Portal Senkronizasyonu
- Aktarılacak durumu "Evet" → portale gönder → durumu "Hayır" yap
- Son 7 günlük değişiklikler portalden çekilir
- Paylaşım view: `DerinSISBkmCrm.dbo.bkm_musteri_iys`

### Alınmayan Müşteriler (Veri Kalitesi)
- Mail: 50 karakterden büyük → atlanır
- Telefon: 20 karakterden büyük → atlanır
- TaxNo/IdentityNo: 11 karakterden büyük → atlanır

---

## 10. Terminoloji Sözlüğü

| Terim | Açıklama |
|---|---|
| STM | Sanal Torba Müşteri — bireysel müşteriler için sabit firma kaydı (ID=4590) |
| VN | Vergi Numarası — 10 hane şirket, 11 hane şahıs |
| Emek | Emek Yayın Dağıtım — ana kitap tedarikçisi |
| DerinSIS | DerinBilgi tarafından geliştirilmiş ERP sistemi |
| Tsoft | E-ticaret platformu |
| piyasa marjı | E-ticaret fiyatı hesaplamada kullanılan iskonto oranı |
| stokkod | Emek'ten gelen ürün eşleşme alanı |
| crmID | CRM müşteri kaydı ID'si, belgelerde taşınır |
| frmID | ERP firma kaydı ID'si |
| eFirmaMkn | Firma mekan ID'si (sevk/şube) |
| cpID | Ödeme yöntemi ID'si |
| İYS | İleti Yönetim Sistemi — izinli iletişim yönetimi |
| e-Arşiv | Bireysel müşterilere kesilen elektronik fatura türü |
| e-Fatura | Kurumsal müşterilere kesilen elektronik fatura türü |
| fiyat nedeni | Fiyat listesi oluşturma kaynağı (4=Emek ent, 5=Marka indirim) |
