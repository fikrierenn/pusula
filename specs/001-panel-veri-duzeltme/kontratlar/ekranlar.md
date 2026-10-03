# Ekran sözleşmesi

Yerleşim değişmez (mobil düzen spec 002). Yalnız değer, etiket, not ve mesaj değişir. Renkler DaisyUI token'ı (`renk-standardi.md`). Lucide ikonu koşullu render edilmez (`coding-discipline.md`). Metinler `KullaniciMesajlari`, `StokGostergeTanimlari`, `DuzeltmeNotlari` ve `HedefTabani` sabitlerinden gelir; Razor'da metin elle tekrar yazılmaz.

## 1. Değişen göstergeler ve "Hesap düzeltildi" notu

Her satırdaki gösterge yanında `<DuzeltmeNotu Anahtar="…" />` bulunur (AC-0.1, 0.2).

| Anahtar | Ekran | Gösterge | AC |
|---|---|---|---|
| `sadakat.winback` | `/sadakat` | Win-back listesi başlığı | H2 |
| `sadakat.kartli-fis` | `/sadakat` | Kartlı/kartsız fiş sayısı ve fiş başı ortalama | AC-5.3 |
| `trafik.fis` | `/trafik` | KPI fiş, dönüşüm, sepet; ısı haritası; personel tablosu | H5 |
| `home.magaza-fis` | `/` | Mağaza kartı fiş ve sepet ortalaması | H5 |
| `home.magaza-net-kirilim` | `/` | Perakende / Sınav Okulları / Toplam satırları | H13 |
| `home.saat-kasiyer` | `/`, `/kasiyer` | Saat yoğunluğu, kasiyer tablosu | D-2 |
| `magaza.kampanya` | `/magaza/{id}` | Kampanya yükü | AC-6.1 |
| `magaza.iade` | `/magaza/{id}` | İade tutarı, iade oranı | AC-6.3 |
| `magaza.upt` | `/magaza/{id}` | UPT, saat × gün ısı haritası | AC-6.4 |
| `envanter.tedarikci` | `/envanter` | Tedarikçi karnesi stok, devir, sinyal | H3 |
| `envanter.marj` | `/envanter` | Kategori brüt marjı | AC-7.1 |
| `envanter.abc` | `/envanter` | ABC sınıflaması | AC-7.3 |
| `envanter.depo` | `/envanter` | Kategori çeşit depo kolonu, ölü stok depo bileşeni | H8 |
| `odak.depo` | `/odak` | Merkez depo stoğu | H8 |
| `odak.etic-talep` | `/odak` | E-ticaret talep kolonu | AC-4.3 |
| `etic.kategori` | `/etic` | Kategori karması, detay, yıllık grafik | H4 |
| `sinav.odeme` | `/sinav` | Ödeme sağlık kartı | H9 |
| `mizan.nakit-kdv` | `/mizan` | Nakit, Alınan çekler (yeni), KDV pozisyonu | H12 |
| `musteri.rfm` | RFM ekranı | Segment cirosu | D-1 |
| `hediye-ceki.barem` | `/hediye-ceki` | Barem brüt/indirim/net | D-4 |

Kumbara ve manuel indirim ekranda gösterilmez (AC-1.4), not yoktur.

## 2. Ekran bazında değişiklikler

### Ana sayfa (`/`)
- Mağaza kartı net bölümü üç satır: **Perakende**, **Sınav Okulları**, **Toplam** (kalın). Sınav değeri 0 ise "—". (İnsan onayı 8)
- Fiş sayısının yanında "İade: N" (AC-5.4).
- Hedef kartında `HedefTabani.Teyitli == false` iken başlık altında `text-warning` küçük metin: "Hedef tabanı teyit bekliyor" (AC-13.4). `true` iken görünmez (AC-13.5).

### Trafik (`/trafik`)
- KPI: Fiş, İade (yeni, ayrı değer), Dönüşüm = Fiş ÷ Ziyaretçi, Sepet = Net ÷ Fiş.
- Dipnot: "Fiş: yalnız perakende satış fişi. İade, fatura, personel ve Sınav Okulları belgesi sayılmaz."

### Sadakat (`/sadakat`)
- Win-back açıklaması: "Son 365 günde alışveriş yapmış, son 90 günde satış fişi olmayan müşteriler." "Son alışveriş" kolonu (gün) tüm zamanlardaki son satış fişinden.
- Kartlı/kartsız tablosu: fiş sayısı kanonik; dipnot "Fiş: yalnız satış fişi. Ciro iadeler düşülmüş olarak."

### Mağaza detay (`/magaza/{id}`)
- İade ve iade oranı etiketi: "(KDV hariç, indirim düşülmüş)".
- Kampanya yükü başlığı: "Kampanya yükü (KDV dahil)".
- UPT dipnotu: "Yalnız perakende satış fişleri."

### Envanter (`/envanter`)
- Tedarikçi karnesi stok kolonu dipnotu: "Stok: mağazalar + merkez depo (WMS, raf ve giriş alanı)."
- Ölü stok ve stokta yokluk göstergelerinin altında `StokGostergeTanimlari` metni (H14).

### ODAK (`/odak`)
- Merkez depo kolonu başlığı "Merkez depo (WMS, anlık)".

### Satınalma analiz, Satış analizi, Sezon aksiyon
- Stok göstergelerinin altında tanım metni (H14).
- Geçmiş ay merkez depo bakiyesi yanında "(31.08.2026 görüntüsü)" (AC-8.3). Görüntü yoksa değer yerine "Bu ay için stok görüntüsü yok." (AC-8.4).
- Satış analizi merkez depo kolonu: "Merkez depo (kesim: gg.aa.yyyy ss:dd)" (İnsan onayı 3).

### Satış analizi ürün detayı (`/satis-analizi/urun/{id}`)
- "← Listeye dön" `GeriAdresi.Coz(geri)` adresine gider (AC-11.1, 11.2).

### E-ticaret (`/etic`)
- "Baskısı yok" sekmelerindeki tutar başlıklarına "(KDV dahil)" (D-3).

### Mizan (`/mizan`)
- "Nakit" kartı: 100, 102, 108. Yeni kart "Alınan çekler" (101). KDV kartı: "Devreden KDV" satırı eklenir, net pozisyon buna göre (H12).

### Gün karşılaştırma, Tahmin / hedef gerçekleşme
- Dipnot: kullanılan ciro tabanı (Gün karşılaştırma: "Kasa verisi, KDV dahil (KDV hariç ayrıca gösterilir)"; Tahmin: "ERP stok hareketi, KDV hariç, satış − iade") (D-5).

### Müşteri RFM / LTV
- LTV segment etiketi "Kayıtlı, kartsız"; dipnot "Anonim (yürü-gel) müşteri bu tabloda yok." (D-1).

## 3. Mesajlar (`KullaniciMesajlari`)

| Sabit | Metin | Kullanıldığı yer |
|---|---|---|
| `VeriAlinamadi` | "Veriler şu anda alınamıyor. Sayfayı birkaç dakika sonra yenileyin; sorun sürerse sistem yöneticisine bildirin." | Sabah, Envanter, Operasyon, Satınalma analiz, Vardiya (AC-10.1) |
| `KayitYapilamadi` | "Eşik kaydedilemedi. Değerleri kontrol edip yeniden deneyin; sorun sürerse sistem yöneticisine bildirin." | Eşikler |
| `DonemdeKayitYok` | "Bu dönemde kayıt yok." | Dokunulan tablolarda boş sonuç |
| `StokGoruntusuYok` | "Bu ay için stok görüntüsü yok." | AC-8.4 |

Ekranda sunucu adı, SQL metni, istisna türü ve istisna metni **görünmez** (AC-10.1). Teknik ayrıntı `ILogger`'a ekran adı ile yazılır; zaman damgası günlük altyapısından gelir (AC-10.2).

`SatinalmaAnaliz.razor`'daki üç alt bölüm hatası ("Talep sapması hesaplanamadı: …") önekini korur, `ex.Message` yerine `VeriAlinamadi` metnini ekler.
