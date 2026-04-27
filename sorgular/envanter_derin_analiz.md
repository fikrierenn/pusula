# Envanter Derin Analiz — Tüm Stoklar
**Tarih:** 14 Nisan 2026
**Kapsam:** Envanter_Raporu'nun baktığı tüm kategoriler (Kategori3 ≠ 11,25,23,9,5,6), urnTip=0
**Toplam envanter görünen değer:** 2.71 milyar TL
**Kirlilik tahmini:** -268M ila -300M TL (bakış açısına göre)

---

## 1. GENEL NEGATİF BAKİYE TARAMASI

**328 ürün** bir mağazada negatif bakiyede, toplam etkisi **-312.9M TL**.

| Lokasyon | Negatif Etki |
|---|---:|
| FSM | -68 bin TL |
| Özlüce | -191 bin TL |
| **İst.Yolu** | **-312.6M TL** |

Dağılım net: negatif sorunun **%99.9'u İst.Yolu'nda**. FSM ve Özlüce'deki rakamlar operasyonel normlar içinde (belgelenmemiş fire, müşteri iadesi bekleyen kayıt vb.).

---

## 2. KATEGORİ3 BAZINDA NET ENVANTER

| Kategori3 | SKU | Net Tutar (TL) | Negatif Etki | Pozitif Etki |
|---|---:|---:|---:|---:|
| Kırtasiye | 92.638 | **+414.6M** | -26K | 414.6M |
| Kitap | 351.579 | +151.8M | -13K | 151.8M |
| Oyuncak | 28.697 | +83.2M | -94K | 83.3M |
| Çocuk Kitabı | 98.442 | +66.0M | -28K | 66.0M |
| Hazırlık Kitapları | 52.015 | +43.7M | **-196K** | 43.9M |
| Akademi | 116.550 | +39.8M | -36 TL | 39.8M |
| Hediyelik | 13.686 | +27.7M | -79K | 27.8M |
| Sınav Kıyafet | 1.093 | +25.1M | -11K | 25.1M |
| Elektronik | 1.647 | +3.2M | -170 TL | 3.2M |
| Kişisel Bakım | 415 | +2.4M | -60 TL | 2.4M |
| Gıda | 1.113 | +1.8M | -1.7K | 1.8M |
| Dergi | 10.387 | +542K | -52 TL | 542K |
| Tanımsız | 17.544 | +255K | 0 | 255K |
| Spor & Outdoor | 32 | +27K | 0 | 27K |
| **Sınav Okulları** | **1.402** | **-219.3M** | **-312.3M** | **+93.0M** |

### Önemli Bulgular
- **Sınav Okulları** tek başına tüm kategori negatifini taşıyor: toplam negatifin %99.9'u.
- **Hazırlık Kitapları** -196K TL ile ikinci en kirli — tek kalem (6. Sınıf Yaz Tatil Kitabı -199K TL) neredeyse hepsini üretiyor.
- **Akademi:** 116.550 SKU sadece 92.396 adet bakiye → SKU başına 0.79 adet. **Katalog şişmiş**, muhtemelen silinmesi gereken ölü SKU'lar var.
- **Kitap:** 351.579 SKU, 449.888 adet → SKU başına 1.28 adet. Yine yüksek fragmentasyon.
- **Tanımsız** kategorisi hâlâ var (17.544 SKU) — ERP hijyeni.

---

## 3. SINAV OKULLARI — İKİ TARAFLI DİSTORSİYON

**Tek bir kategori** (Kategori3=19, Sınav Okulları) envanter yapısını bozuyor. İki alt tabaka:

### 3A. Negatif Paket Kodları (İst.Yolu'nda hayalet negatif)

**22 süreli yayın paketi, -299.9M TL.** (Detay: `sorunlu_urunler_tutar_detay.md`)

Bu paketler öğrenciye çıkar, BKM'ye parça kodlarla fatura gelir. Paket koduna hiç giriş olmaz → sonsuza kadar negatif.

### 3B. Pozitif Parça & Modül Kodları (İst.Yolu'nda hayalet pozitif)

**~18 ürün, +~30M TL.** Bunlar paketin içindeki parça/modüllerin depo tarafı kodları. BKM'ye parça/modül olarak gelip hiç çıkış görmüyor.

| stkID | Ürün | Adet | Tutar |
|---|---|---:|---:|
| 1546680 | BÇÜ 6 YAŞ COSMOLAND EĞİTİM SETİ TÜRKÇE | 1.158 | +4.3M |
| 1681867 | KEŞŞİF KUTUSU BİLİM PORTALI ETKİNLİK SETİ | 4.474 | +3.4M |
| 1546678 | BÇÜ 5 YAŞ COSMOLAND EĞİTİM SETİ İNGİLİZCE | 741 | +2.8M |
| 1619966 | ÜÇDÖRTBEŞ ALLSTAR LGS ONLİNE | 1.089 | +2.2M |
| 1605974 | Eng Time Activity Book 6 Yaş | 480 | +1.9M |
| 1559974 | Sınav 9.Sınıf Konu/Soru Modülü | 3.494 | +1.7M |
| 1559992 | Sınav 3.Sınıf Konu/Soru Modülü | 4.720 | +1.7M |
| 1559991 | Sınav 2.Sınıf Konu/Soru Modülü | 4.469 | +1.5M |
| 1559971 | Sınav 10.Sınıf Konu/Soru Modülü | 2.938 | +1.5M |
| 1675708 | SINAV SIDE TO SIDE TRICKY WORDS YEAR 1 | 3.551 | +1.4M |
| 1560100 | Sınav 9.Sınıf Flıpıt | 7.786 | +1.2M |
| 1560005 | Sınav 5.Sınıf Outside Re-Cap Yeşil | 7.517 | +1.2M |
| 1560097 | Sınav 1.Sınıf İlk Okuma Kitabım | 5.950 | +1.2M |
| 1560010 | Sınav 4.Sınıf Outside Re-Cap Yeşil | 7.310 | +1.2M |
| 1605978 | Eng Time Activity Book 4-5 Yaş | 290 | +1.1M |

### Net Etki
Sınav Okulları kategorisinden **-219.3M TL** net distorsiyon. Paketler (-300M) + Parçalar (+80M) farkı → -220M civarı. Çifte sorun:
- **Paket tarafı:** stok eksiye gidiyor, envanteri düşürüyor
- **Parça tarafı:** stok eksilmediği için envanteri kalıcı şişiriyor (öğrenciye çıkmıyor ki sistemde fiili satış yok)

Fiziksel gerçek: kitapların çoğu öğrenci elinde. Envanter, ne negatif kadar boş ne pozitif kadar dolu.

---

## 4. FİYAT ANOMALİLERİ (Kategori Medyanından >5x P95 Sapma)

Kategori içi fiyat outlier'ları. Bazıları gerçek (premium ürünler), bazıları şüpheli (veri giriş hatası):

### 4A. Şüpheli (Fiyat Giriş Hatası Olası)
| stkID | Ürün | Kategori | Üst Fiyat | Medyan | Kat |
|---|---|---|---:|---:|---:|
| 1697911 | Mileo Fon Kartonu 160gr 50x70 | Kırtasiye | **1.999** | 109 | 18x |
| 272205 | Mapibind Plastik Spiral Cilt Makinesi 165 | Kırtasiye | **16.499** | 109 | 151x |
| 1686834 | YILBAŞI BİBLO SESLİ (MT18A-6) | Hediyelik | **7.990** | 69.9 | 114x |
| 1686833 | YILBAŞI MÜZİKLİ FANUS (DS809) | Hediyelik | **7.990** | 69.9 | 114x |
| 1686835 | YILBAŞI BİBLO SESLİ (BFD22-7B) | Hediyelik | **9.990** | 69.9 | 143x |
| 1682511 | YILBAŞI MÜZİKLİ (W269) | Hediyelik | **8.990** | 69.9 | 129x |
| 1686829-32 | YILBAŞI FANUS serisi | Hediyelik | 3.990-5.990 | 69.9 | 57-86x |

→ Mileo Fon Kartonu fiyatı **19,99 TL** olması gerekiyor gibi duruyor. Yılbaşı fanusları 79,90 TL olabilir. **Tek başına bu 8 SKU envanteri ~1.7M TL şişiriyor.**

### 4B. Gerçek Premium (Fiyat Muhtemelen Doğru)
| stkID | Ürün | Kategori | Üst Fiyat | WMS |
|---|---|---|---:|---:|
| 1701935 | Lamy Safari Harry Potter Dolma Kalem 4'lü | Kırtasiye | 9.699 | 12 |
| 459468 | Lamy Dialog 14K Altın Dolma Kalem | Kırtasiye | 22.499 | 1 |
| 1645596 | Lego Technic Ferrari SF-24 F1 42207 | Oyuncak | 13.199 | 2 |
| 235636 | Hoverway Drift Scooter Hiphop | Elektronik | 22.500 | 5 |

### 4C. Akademik Tıp Kitapları (Kitap Kategori3 Medyanı 200 TL, bunlar 4K-11K)
| 1679732 | A'dan Z'ye Temel Ebelik 2 Cilt | 11.100 TL |
| 1680688 | Koneman's Diagnostic Microbiology | 6.200 TL |
| 1675740 | Üst Ekstremite Yaralanmaları Rehabilitasyon | 3.750 TL |

→ Bunlar özel akademik fiyatlama, doğru. Ama Kitap kategorisinin alt segmentine ayrılmaları envanter analizini temizler.

---

## 5. WMS'TE AŞIRI BİRİKEN SKU'LAR (Pozitif Anomali)

5000+ adetlik yığılmalar — hepsi Merkez Depo'da, mağazalarda yok:

| stkID | Ürün | Üst Fiyat | WMS | Tutar |
|---|---|---:|---:|---:|
| 1590653 | The Edd Duygulu Mini Not Defter | 15 | **97.178** | 1.46M |
| 53524 | Fatih Kırmızı Kopya Kalem | 15 | 57.314 | 860K |
| 1623731 | Sevimli Hayvanlar Kum Boyama Mini | 9.9 | 55.089 | 545K |
| 1511929 | Araçlar Sticker Seti | 9.9 | 52.440 | 519K |
| 51423 | Fatih Mercanlı Kurşun Kalem | 15 | 52.362 | 785K |
| 1539153 | Touch Marker | 20 | 49.696 | 994K |
| 1539240 | Mabbels 80 Sayfa Not Defteri Yeşilçam | 15 | 47.242 | 709K |
| 1666161 | OMT Karışık Kalem Başlığı | 10 | 30.442 | 304K |
| 271573 | Adel 2165 Kurşun Kalem Writer | 20 | 28.272 | 565K |
| 10231 | Faber-Castell Kırmızı Kopya | 29 | 26.877 | 779K |
| 1493424 | Mas 1791 Termal Rulo 56X16 | 119 | 11.547 | **1.37M** |
| 1685327 | Temalı Çorap Serisi | 49 | 12.742 | 624K |
| 1528260 | Balloons 500 Parça Puzzle | 99 | 8.864 | 878K |
| 1698878 | Karışık Frame Puzzle Modelleri | 69 | 10.320 | 712K |

**Yorum:**
- The Edd Mini Not Defter ve Mabbels Yeşilçam → tek ürün aile 175K+ adet. Fiziksel sayım önerilir.
- Touch Marker 50K adet → depo hijyeni açısından gerçek mi kontrol edilmeli.
- Fatih kalem çeşitleri (kırmızı+mercanlı+Faber Castell) birikim normal — yüksek döner SKU'lar.
- Mas Termal Rulo 11.547 adet × 119 TL = 1.37M TL → kasa ruloları, gerçekten kullanım yoğun olabilir.

---

## 6. ÖLÜ STOK (365+ Gün Satılmamış, 100K+ TL)

Hiç satılmamış veya 1 yıldan fazla hareketsiz yüksek tutarlı SKU'lar:

| stkID | Ürün | Üst Fiyat | WMS | Tutar | Son Satış |
|---|---|---:|---:|---:|---|
| 1697911 | Mileo Fon Kartonu | 1.999 | 800 | **1.60M** | **Hiç** |
| 1708289 | Lilamor Kumaş Kol Çantası | 349 | 480 | 168K | Hiç |
| 1697002 | Noki Tumbler Termos 1200ML Beyaz | 1.899 | 72 | 137K | Hiç |
| 1697003 | Noki Tumbler Termos 1200ML Pembe | 1.899 | 72 | 137K | Hiç |
| 1697004 | Noki Tumbler Termos 1200ML Mavi | 1.899 | 72 | 137K | Hiç |
| 1697005 | Noki Tumbler Termos 1200ML Siyah | 1.899 | 72 | 137K | Hiç |
| 1559655 | Bagbound Sırt Çantası Myra | 770 | 159 | 122K | 07.02.2025 |
| 1701935 | Lamy Safari Harry Potter Dolma Kalem | 9.699 | 12 | 116K | Hiç |

**Toplam ölü stok:** ~2.55M TL (sadece büyük kalemler, daha düşük eşikte çok daha fazla çıkar).
**Noki Tumbler 4 renk:** toplam 547K TL, hiçbiri satılmamış → ya lansman beklemede ya yanlış satın alma kararı.

---

## 7. STKIDyleri / STKAD DUPLİKASYONU (ERP Hijyeni)

Aynı isimde birden fazla kart → sorgulama, raporlama ve stok yönetimi kırılıyor.

### En Ağır Duplikasyonlar
| Ürün Adı | SKU Sayısı | Toplam Bakiye | Tutar |
|---|---:|---:|---:|
| **Note The Time Sert Kapak Lastikli Not Defteri** | **17** | 3.063 | 303K |
| **OBM Harry Potter Okul Çantası** | **12** | 243 | 460K |
| Faber-Castel Desenli Kırmızı Kopya Kalemi | 5 | 12.279 | 356K |
| Options 1 Student's Book | 3 | 11 | 30K |
| Kuromi Islak Mendil | 3 | 3.555 | 281K |
| Sınav 3.Sınıf Konu/Soru Modülü | 2 | 4.720 | 1.70M |
| Sınav 2.Sınıf Konu/Soru Modülü | 2 | 4.469 | 1.52M |
| SINAV 4.SINIF KONU/SORU MODÜLÜ | 2 | 4.948 | 1.37M |
| SINAV 1.SINIF İLK OKUMA KİTABIM | 2 | 5.950 | 1.19M |
| SINAV 1.SINIF KONU/SORU MODÜLÜ | 2 | 4.157 | 1.08M |
| B.Ç.Ü. 7-8 YAŞ EŞOFMAN TAKIMI | 2 | 286 | 615K |
| Galatasaray Pre-Season 2025/26 | 2 | 4.055 | 401K |
| Uni Posca 0.7 Poster Markörü 8'li | 2 | 204 | 321K |
| Faber-Castell Siyah Silgi | 2 | 7.982 | 279K |
| Led Işıklı Kitap Okuma Gözlüğü | 2 | 3.185 | 254K |

**Yorumlar:**
- **Note The Time 17 SKU:** muhtemelen renk/kapak varyantları ama aynı isim → kart açarken varyant farkı isme eklenmemiş.
- **OBM Harry Potter 12 SKU:** aynı mantık, desen/renk varyantı.
- **Sınav Modülleri çiftleri:** eski yıl (2023-24) ve yeni yıl (2025-26) aynı isme sahip → eskiler pasife alınmalı.
- **Faber-Castel Desenli 5 SKU:** aynı ürün, farklı tarihlerde kart açılmış.

**İş etkisi:** Stok seviyesi raporu bu ürünlerde yanıltıcı — bir stkID'de stok görünürken başka stkID'de aynı ürün bitmiş gibi raporlanıyor.

---

## 8. MAĞAZA DENGESİZLİĞİ (Bir Yerde Negatif, Başka Yerde Pozitif)

Mağazalar arası transfer kaydedilmemiş gibi görünen 16 SKU:

| stkID | Ürün | FSM | Özlüce | İst.Yolu | Yorum |
|---|---|---:|---:|---:|---|
| 1636232 | Peluş Anahtarlık | **-1** | 1.793 | 192 | FSM'de 1 adet ters |
| 1670332 | Peluş Anahtarlık New | 410 | **-326** | 85 | Özlüce 326 fazla çıkmış |
| 1694607 | Bricks Florist Seri 1 | 19 | **-198** | 12 | Özlüce 198 fazla çıkmış |
| 1694605 | BRİCKS FLORİST ŞEFFAF ÇİÇEKLER | 1 | **-141** | 0 | Özlüce aynı sorun |
| 1650500 | Pinch Family Slimy Figür | 73 | -10 | 168 | Özlüce -10 |
| 1673664 | Mini Cep Islak Mendil 8'li | 0 | **-1** | 1.231 | Toplu gelen Özlüce'ye de düşmüş gibi |
| 643638 | Missim Bijuteri 49,50 TL | **-103** | **-124** | 18 | FSM+Özlüce birlikte negatif |
| 196021 | 2026 AYT Matematik 10'lu Deneme | 30 | -2 | 12 | Minör |
| 1512786 | Elit 8. Sınıf Fen Deneme | 41 | -2 | 31 | Minör |
| 1695745 | MİNİ STİCKER | 2.501 | 1.022 | -36 | İst.Yolu -36 |
| 1653854 | 6. Sınıf Yaz Tatil Kitabı | 8 | 4 | **-571** | İst.Yolu ciddi |

**Kök nedenler:** (a) mağazalar arası transfer fişi kesilmeden ürün gitmiş, (b) sayımda yanlış kaydedilmiş, (c) iade sürecinde ters kayıt, (d) POS'ta fazla satış girişi.

### Özel Vurgu: 6. Sınıf Yaz Tatil Kitabı (1653854)
- Kategori3=Hazırlık Kitapları (Sınav Okulları değil!)
- İst.Yolu bakiyesi: **-571 adet × 349 TL = -199K TL**
- Hazırlık Kitapları kategorisindeki -196K TL negatifin neredeyse tamamı bu tek ürün.
- Büyük ihtimalle okulun yaz tatili öncesi toplu öğrenci çıkışı olmuş, paketten çıkmış ama giriş görmüyor (Sınav Okulları paket sorununun küçük versiyonu).

---

## 9. ÖNCELİKLENDİRİLMİŞ AKSİYON LİSTESİ

### Öncelik 0 — Acil (Bu Hafta)
1. **Mileo Fon Kartonu 1.999 TL kontrolü** — Tek kalemde 1.6M TL. Muhtemelen 19,99 TL girilecekken hata. Düzeltilirse envanter 1.58M TL azalır.
2. **Yılbaşı Fanus/Biblo serisi fiyatları** — 8 SKU toplam ~200K TL şişme, 79,90 TL mi 7.990 TL mi kontrol.
3. **Mapibind Spiral Cilt Makinesi 16.499 TL** — tek adet ama kategori medyanının 151 katı.

### Öncelik 1 — Sınav Okulları Kategori Yeniden Yapılandırma
1. Yeni Kategori3 aç: **"Sınav Süreli Yayın"**
2. 22 paket kodu + ~18 parça/modül kodu (40 SKU) bu kategoriye taşı
3. Job SQL'ine ekle: `AND u.urnKtgr2ID <> [YENİKTGR]`
4. **6. Sınıf Yaz Tatil Kitabı (1653854)** aynı mekanizmaya sahip ama Hazırlık Kitapları'nda — o da taşınmalı
5. Sonuç: envanter **-219M TL distorsiyon giderilir**, İst.Yolu +182M TL'ye döner.

### Öncelik 2 — ERP Hijyeni (Duplikasyon Temizliği)
1. **Note The Time Not Defteri** 17 SKU → varyant isimleri netleştir veya tek kart altında renk attribute'u
2. **OBM Harry Potter Okul Çantası** 12 SKU → aynı
3. **Sınav Modülleri eski yıl kartları** (1559987-96 vs 1615876-79) → eskileri pasife al
4. **Options 1 Student's Book** 3 stkID → tek karta konsolide
5. **Tanımsız kategorisindeki 17.544 SKU** → mass-update ile gerçek kategorilere çek

### Öncelik 3 — Ölü Stok Aksiyonu
1. **Noki Tumbler Termos 4 renk** (547K TL) → satış stratejisi (lansman? indirim? iade?)
2. **Bagbound Sırt Çantası Myra** (122K TL, 431 gün) → sezon ürünü mü, iade mi?
3. **Lamy Harry Potter Dolma Kalem** (116K TL) — lisanslı premium, pazarlama aksiyonu

### Öncelik 4 — Fiziksel Sayım (WMS)
1. **The Edd Mini Not Defter 97.178 adet** — gerçekten bu kadar var mı? Ucuz ama adet anormal
2. **Touch Marker 49.696 adet** — aynı soru
3. **Mabbels Yeşilçam 47.242 adet**
4. **Fatih + Faber-Castell kalem serisi** (150K+ adet toplam) — top down sayım

### Öncelik 5 — Mağaza Dengesizliği Düzeltmesi
16 SKU'da mağaza transfer fişleri kontrol edilmeli. Özlüce'de Peluş Anahtarlık -326, Bricks Florist -198 gibi ters kayıtlar tek tek incelenmeli.

---

## 10. SAYISAL ÖZET

| Kategori | SKU Adedi | Net Etki (TL) | Aksiyon |
|---|---:|---:|---|
| Sınav Okulları paket negatif | 22 | -299.9M | Kategori ayır, exclude |
| Sınav Okulları parça pozitif | ~18 | +30.0M | Kategori ayır, exclude |
| 6. Sınıf Yaz Tatil Kitabı | 1 | -199K | Kategori ayır |
| Fiyat giriş hatası adayları | ~10 | ~+2M | Fiyat düzeltme |
| Ölü stok (>365 gün) | ~8 | ~+2.5M | Satış/iade/konsinye |
| Duplikasyon (17+12+5 ana) | ~40 SKU | Veri bozuklu. | Kart birleştirme |
| Mağaza dengesizliği | 16 | ~-150K | Transfer fişi audit |
| **Net düzeltilebilir distorsiyon** | **~115 SKU** | **~-268M TL** | |

Düzeltilmiş envanter tahmini: **2.71B TL → ~3.0B TL**

---

## 11. BİR SONRAKİ ADIMLAR

1. Bu raporu Ceren'le paylaş — Job SQL düzeltmesi ve kategori taşıma için onay al
2. Öncelik 0 aksiyonları bu hafta içinde tamamlansın (sadece fiyat düzeltme = 1.8M TL envanter etkisi)
3. Sınav Okulları kategori restrüktürü için satış ekibiyle toplantı (yeni kategori3 kodu belirleme)
4. Fiziksel sayım planı için depo ekibiyle koordinasyon (özellikle The Edd + Touch Marker)
5. ERP hijyeni için IT ile 1 gündem: duplikasyon temizliği ve Tanımsız kategorisi boşaltma

## Kaynak Dosyalar
- `envanter_raporu_job_sorgusu.sql` — Job'ın tam kaynağı
- `envanter_raporu_analiz.md` — İlk analiz bulguları
- `sorunlu_urunler_tutar_detay.md` — 22 süreli yayın paketi detayı
- `tum_stoklar_anomali_taramasi.md` — Özet anomali taraması
- `envanter_derin_analiz.md` — **Bu belge**
