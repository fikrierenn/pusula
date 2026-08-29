# Çok Satan Ürünler × Stok × Bulunurluk (OSA) — 25.08.2026

**Soru:** En çok satan 50 ürünün stok seviyesi ve bulunurluğu ne? Ne çıkarıyoruz?
**Pencere:** 01.08.2025 – 31.07.2026 (son 12 TAM ay; Ağustos 2026 kısmi olduğu için hariç)
**Evren:** Şube perakende satışı — `irsHrk` ehTip 4/100 (satış) − 5/101 (iade), `ehMekan IN (1 FSM, 4477 Özlüce, 4478 İst.Yolu)`, `ehAltDepo=0`, `urnTip=0`. Tutarlar **KDV hariç net**.
**Kaynaklar:** stok (şube) = irsHrk kümülatif · stok (depo) = `ent.odak_depo_Stok` (kanonik) · tarihsel bulunurluk = `bkm.StokAyBakiyeMekanBazli` (carry-forward, giriş bakiyesi ≥3) · master = `bkm.UrunBilgi`
**Üretim:** `scripts/cok_satan_bulunurluk.py` · SQL arşivi: `sorgular/2026-08-25-cok-satan-50-stok-bulunurluk.sql`

---

## 0. Önce evren temizliği — "çok satan" listesi ham haliyle YANILTIYOR

Ham sıralama iki ayrı şeyi karıştırıyor:

| Ne | Ciro (son 12 ay) | Neden listede olmamalı |
|---|---|---|
| **Sınav Okulları paketleri** ("3. Sınıf Süreli Yayın 2026" vb., 54 SKU) | **322,2M ₺ — şube cirosunun %40'ı** | Eğitim hizmeti/abonelik paketi. Raf stoğu YOK, olması da beklenmez. Bulunurluk metriğinde **12/12 ay "kuru"** görünüp OOS oranını sahte şişiriyor. |
| **Poşet** (2/3/4/5 No, "Genel" kategori) | 0,3M ₺ ama **~465 bin adet** | Ambalaj. Adet sıralamasının ilk 6 sırasının 4'ünü kaplıyor. |

Temizlenmiş **raf ürünü evreni: 8.856 SKU / 431,2M ₺**. Aşağıdaki tüm çıkarımlar bu evrende.

> **Not:** Ham 802,9M ₺'nin 371,8M ₺'si (%46) bu iki başlıkla eleniyor. Yani "mağaza cirosu" dendiğinde neyin sayıldığı kritik — Sınav Okulları paket satışını perakende raf performansıyla aynı tabloda kıyaslamak yanlış sonuç üretir.

---

## 1. TOP 50 — CİRO (raf ürünü)

`stokS` = 3 şube toplam anlık stok · `stokDP` = ODAK/e-tic depo · `gün` = kapsam (stok ÷ son-3-ay günlük hız) · `kuru_ay` = son 12 ayın kaç ayında giriş bakiyesi <3 (FSM/Özlüce/İst.Yolu) · `ŞİMDİ KURU` = o şubede stok <3 ama son 12 ayda satış var

| # | Ürün | Kategori | adet12 | ciro12 ₺ | stokS | stokDP | gün | kuru_ay | ŞİMDİ KURU |
|---:|---|---|---:|---:|---:|---:|---:|:---:|---|
| 1 | Bricks Lego Modelleri | Oyuncak | 27.772 | 3.472.352 | 2.529 | 0 | 38 | 2/0/2 | |
| 2 | Hot Wheels Tekli Arabalar | Oyuncak | 16.571 | 1.768.832 | 2.927 | 0 | 77 | 0/0/0 | |
| 3 | Key Chain - Süs | Hediyelik | 91.270 | 1.139.364 | 34.659 | 0 | 296 | 1/1/1 | |
| 4 | Telefon Melefon Yok! | Çocuk Kitabı | 5.457 | 1.062.754 | 271 | 1.002 | 31 | 1/1/1 | |
| 5 | Bekle Beni | Kitap | 4.078 | 1.013.328 | 320 | 2.451 | 55 | 2/2/2 | |
| 6 | 8. Sınıf LGS Gün Gün Paragraf Soru Bankası | Hazırlık | 2.007 | 1.006.376 | 604 | 152 | 172 | 0/0/0 | |
| 7 | Stitch Figür | Oyuncak | 1.655 | 986.302 | 94 | 0 | 77 | 0/0/0 | |
| 8 | Sırların Sırrı | Kitap | 1.831 | 967.474 | 42 | 970 | 22 | 2/2/2 | |
| 9 | Çalıkuşu | Kitap | 1.528 | 937.246 | 754 | 788 | 414 | 0/0/0 | |
| 10 | 2027 TYT Matematik Soru Bankası | Hazırlık | 2.143 | 929.717 | 227 | 251 | 73 | 1/1/1 | |
| 11 | Ve-Ge Fotokopi Kağıdı Copier Bond 500'lü | Kırtasiye | 7.672 | 919.740 | 851 | 0 | 101 | 0/0/1 | |
| 12 | **Bic Yazı Tahtalı Set** | Kırtasiye | 656 | 918.144 | **0** | 0 | – | **12/12/4** | **İst.Yolu** |
| 13 | **8. Sınıf LGS Matematik A Fenomen SB** | Hazırlık | 1.905 | 906.079 | 167 | **495** | 64 | 0/0/0 | **İst.Yolu** |
| 14 | **Touch Marker 24'lü Çift Uçlu** | Kırtasiye | 4.341 | 895.150 | 84 | 0 | 90 | 0/0/0 | **FSM** |
| 15 | 2027 TYT Paragraf Sıfır Risk SB | Hazırlık | 2.023 | 874.322 | 276 | 0 | 106 | 1/0/0 | |
| 16 | **Tuval Boyama Seti Yeni Model** | Kırtasiye | 12.725 | 815.097 | 162 | 0 | 20 | 5/5/5 | **FSM** |
| 17 | Cumhuriyet'in İlk Sabahı | Çocuk Kitabı | 4.097 | 796.758 | 186 | 1.519 | 79 | 0/0/1 | |
| 18 | 8. Sınıf IQ Matematik Soru Kütüphanesi | Hazırlık | 1.419 | 794.121 | 112 | 116 | 113 | 0/0/0 | |
| 19 | **8. Sınıf Fen Bilimleri Soru Bankası** | Hazırlık | 1.474 | 779.399 | **1** | 0 | 2 | 1/2/0 | **FSM, Özlüce, İst.Yolu** |
| 20 | Fidget Keys Işıklı Stres Anahtarlığı | Hediyelik | 5.102 | 760.399 | 1.635 | 0 | 38 | 8/6/9 | |
| 21 | Bkmkitap 1000₺ Hediye Çeki | Hediye Çeki | 759 | 758.850 | 110 | 0 | 33 | 0/0/2 | |
| 22 | 2027 AYT Matematik Soru Bankası | Hazırlık | 1.779 | 758.499 | 210 | 88 | 123 | 1/1/0 | |
| 23 | **8. Sınıf Matematik Soru Bankası** | Hazırlık | 1.449 | 747.474 | **1** | 0 | 2 | 0/2/0 | **FSM, Özlüce, İst.Yolu** |
| 24 | 8. Sınıf IQ Fen Bilimleri Soru Küt. | Hazırlık | 1.333 | 745.725 | 146 | 97 | 151 | 0/0/0 | |
| 25 | **7. Sınıf Gün Gün Paragraf SB** | Hazırlık | 1.671 | 739.456 | **3** | 0 | 1 | 1/0/0 | **FSM, Özlüce, İst.Yolu** |
| 26 | **Panini FIFA World Cup 2026 Çıkartma** | Oyuncak | 8.625 | 692.647 | 626 | 78 | **7** | **10/11/11** | |
| 27 | Projecta Ultra A4 Fotokopi Kağıdı | Kırtasiye | 6.617 | 668.807 | 503 | 0 | 58 | 0/1/3 | |
| 28 | Faber-Castell Sınav Silgisi | Kırtasiye | 18.766 | 664.567 | 10.692 | 1 | 329 | 0/0/1 | |
| 29 | Temalı Çorap Serisi | Hediyelik | 16.128 | 662.620 | 940 | 0 | 49 | 4/4/4 | |
| 30 | TYT IQ Paragraf Soru Kütüphanesi | Hazırlık | 1.701 | 661.221 | 177 | 260 | 77 | 0/0/0 | |
| 31 | Pritt-Stick Yapıştırıcı 22gr | Kırtasiye | 11.634 | 660.278 | 5.171 | 32 | **1.130** | 0/0/1 | |
| 32 | Suprise Figüre | Oyuncak | 16.859 | 636.876 | 2.734 | 0 | 288 | 2/2/2 | |
| 33 | Dedemin Bakkalı – Fleksi Kapak | Çocuk Kitabı | 2.028 | 634.452 | 280 | 2.940 | 57 | 0/0/0 | |
| 34 | Key Chain - Peluş | Hediyelik | 21.859 | 632.427 | 11.417 | 0 | 150 | 6/6/6 | |
| 35 | 6. Sınıf Gün Gün Paragraf SB | Hazırlık | 1.280 | 631.112 | 741 | 140 | 417 | 0/0/0 | |
| 36 | **Yanıt 4. Sınıf Tüm Dersler SB** | Hazırlık | 1.061 | 630.210 | **0** | 0 | – | 7/7/7 | **FSM, Özlüce, İst.Yolu** |
| 37 | Pınar Yaşam Pınarım Su 0,5 lt | Gıda | 42.520 | 625.677 | 6.564 | 0 | 40 | 0/0/0 | |
| 38 | Gece Yarısı Kütüphanesi | Kitap | 2.478 | 611.486 | 204 | 1.123 | 29 | 0/0/0 | |
| 39 | Resimino 35x50 Resim Defteri | Kırtasiye | 2.102 | 597.032 | 188 | 0 | **1.880** | 0/0/0 | |
| 40 | 5. Sınıf Gün Gün Paragraf Yeni Nesil SB | Hazırlık | 1.315 | 580.063 | 569 | 65 | 430 | 0/0/0 | |
| 41 | Bic Visa Fırça Uçlu Keçeli Boya 10'lu | Kırtasiye | 1.873 | 579.288 | 296 | 7 | **1.776** | 0/0/2 | |
| 42 | 8. Sınıf Matematik Soru Bankası (2) | Hazırlık | 1.093 | 578.417 | 71 | 40 | 183 | 0/0/0 | |
| 43 | Annemin Uyurgezer Geceleri | Kitap | 1.808 | 568.229 | 152 | 2.114 | 28 | 4/4/4 | |
| 44 | Kenko KK-613D Dijital Masa Saati | Kırtasiye | 6.959 | 567.891 | 1.221 | 1.475 | 103 | 0/0/0 | |
| 45 | **2026 KPSS Tarih Tamamı Çözümlü SB** | Akademi | 1.508 | 562.405 | 26 | 0 | 7 | 2/1/2 | **FSM** |
| 46 | Pritt Kuruboya 12 Renk Jumbo | Kırtasiye | 1.418 | 560.475 | 95 | 12 | **8.550** | 0/3/0 | |
| 47 | **8. Sınıf Paragraf Soru Bankası** | Hazırlık | 1.049 | 551.060 | **1** | 0 | 2 | 2/2/2 | **FSM, Özlüce, İst.Yolu** |
| 48 | Antrenmanlarla Matematik 1 | Hazırlık | 1.131 | 550.811 | 82 | 144 | 50 | 0/0/0 | |
| 49 | 8. Sınıf Türkçe Soru Bankası | Hazırlık | 1.015 | 541.619 | 71 | 106 | 355 | 0/0/0 | |
| 50 | **9. Sınıf Tüm Dersler Soru Bankası** | Hazırlık | 1.070 | 534.724 | 9 | 71 | 11 | 1/2/1 | **Özlüce, İst.Yolu** |

**Top 50 ciro payı: raf evreninin %9,4'ü.** Konsantrasyon düşük — top 1.000 SKU ancak %51,2. Yani "50 ürünü yönet, iş biter" değil; kuyruk uzun (top100 %14,8 · top250 %25,6 · top500 %36,8).

## 2. TOP 50 — ADET (ilk 20)

| # | Ürün | Kategori | adet12 | ciro12 ₺ | birim ₺ | stokS | kapsam gün |
|---:|---|---|---:|---:|---:|---:|---:|
| 1 | Key Chain - Süs | Hediyelik | 91.270 | 1.139.364 | 12,5 | 34.659 | 296 |
| 2 | OMT Karışık Kalem Başlığı | Kırtasiye | 65.281 | 273.306 | 4,2 | 17.771 | 231 |
| 3 | The Edd Duygulu Mini Not Defter | Kırtasiye | 48.104 | 390.226 | 8,1 | 8.236 | 76 |
| 4 | Pınar Su 0,5 lt | Gıda | 42.520 | 625.677 | 14,7 | 6.564 | 40 |
| 5 | Sevimli Hayvanlar Kum Boyama Mini | Kırtasiye | 39.058 | 322.037 | 8,2 | 4.097 | 31 |
| 6 | Figürlü Crocs Terlik Süs | Hediyelik | 33.449 | 275.486 | 8,2 | 25.661 | 221 |
| 7 | Vatan Mini Su Balon | Hediyelik | 30.456 | 26.283 | 0,9 | 17.339 | 83 |
| 8 | Bricks Lego Modelleri | Oyuncak | 27.772 | 3.472.352 | 125,0 | 2.529 | 38 |
| 9 | Faber-Castell Super Fine 2B 0.7 | Kırtasiye | 22.015 | 528.583 | 24,0 | 4.702 | 75 |
| 10 | Key Chain - Peluş | Hediyelik | 21.859 | 632.427 | 28,9 | 11.417 | 150 |
| 11 | Touch Marker | Kırtasiye | 19.403 | 201.747 | 10,4 | 3.529 | 90 |
| 12 | 3D Baskı Anahtarlık | Hediyelik | 19.272 | 464.991 | 24,1 | 3.655 | 71 |
| 13 | Araçlar Sticker Seti | Kırtasiye | 19.025 | 109.576 | 5,8 | 10.735 | 170 |
| 14 | Faber-Castell Sınav Silgisi | Kırtasiye | 18.766 | 664.567 | 35,4 | 10.692 | 329 |
| 15 | MİNİ STİCKER | Kırtasiye | 17.496 | 92.520 | 5,3 | 1.962 | 40 |
| 16 | Faber-Castell Köşeli Mercanlı K.Kalem | Kırtasiye | 17.419 | 383.619 | 22,0 | 23.742 | **2.219** |
| 17 | Suprise Figüre | Oyuncak | 16.859 | 636.876 | 37,8 | 2.734 | 288 |
| 18 | **Karne Hediyesi** | Etkinlik | 16.842 | **168** | 0,01 | 7.878 | 102 |
| 19 | Hot Wheels Tekli Arabalar | Oyuncak | 16.571 | 1.768.832 | 106,7 | 2.927 | 77 |
| 20 | Temalı Çorap Serisi | Hediyelik | 16.128 | 662.620 | 41,1 | 940 | 49 |

Adet listesi **düşük birim fiyatlı impuls/aksesuar** ürünlerden oluşuyor. Ciro listesiyle kesişim sadece 8 SKU. Yönetim kararı için **ciro listesi**, raf/planogram kararı için **adet listesi** kullanılmalı.

---

## 3. Ana Bulgular

### B1 — Okul sezonuna 56 çok satan SKU stoksuz giriliyor (DOĞRULANMIŞ)
Bugün 25 Ağustos; okul sezonu başlıyor. Geçen yıl Ağu–Eki'de ≥100 adet satan **341 SKU**'nun bugünkü stoğu (şube+depo) geçen yılın sezon talebine oranlandı:

| Durum | SKU | Yorum |
|---|---:|---|
| Stok/sezon-talep **<%25** | **108** | Ham "kritik" |
| ↳ geçen yıl da aynı tarihte düşüktü | 52 | **JIT normal işletme modu — anomali DEĞİL** |
| ↳ **yalnız bu yıl kritik** | **56** | **Gerçek gerileme.** Geçen yıl aynı tarihte stok VARDI. |
| Stok/sezon-talep %25–50 | 58 | Riskli |

**En büyük 10 gerileme** (geçen yıl 25.08'de stok vardı, bugün yok):

| Ürün | Geçen yıl sezon satışı (ad) | 25.08.2025 stok | Bugün stok | Sipariş (60g) |
|---|---:|---:|---:|---|
| Bic Yazı Tahtalı Set | 652 | 1.152 | **0** | YOK |
| 8. Sınıf IQ Matematik Soru Küt. | 1.082 | 780 | 228 | YOK |
| Resimino 35x50 Resim Defteri | 2.007 | 3.699 | 188 | sevk 168 |
| Ve-Ge Fotokopi Kağıdı 500'lü | 5.142 | 1.754 | 851 | alım 1.080 |
| Yanıt 4. Sınıf Tüm Dersler SB | 891 | 528 | **0** | YOK |
| Pritt Kuruboya 12 Renk Jumbo | 1.406 | 1.419 | 107 | sevk 34 |
| 8. Sınıf Matematik SB | 900 | 754 | 111 | YOK |
| 7. Sınıf Gün Gün Paragraf SB | 944 | 610 | **3** | YOK |
| 8. Sınıf Türkçe SB | 882 | 750 | 177 | YOK |
| 3. Sınıf Tüm Dersler SB | 708 | 534 | **0** | YOK |

**Kritik 108 SKU'nun 79'unda son 60 günde hiç sipariş satırı yok** (`dbo.sip` + `sipAyr`, eDurum≠2). Yani eksiklik "mal yolda" ile açıklanmıyor — sipariş açılmamış.

Bu 56 SKU'nun geçen yıl aynı sezondaki cirosu toplamı: **~10,3M ₺** (en kritik 45 SKU üzerinden hesaplanan açık). Rakam **üst sınır** — talebin tamamının ikame edilmeden kaybolduğunu varsayar.

### B2 — LGS/soru bankası kümesi sistematik olarak kuru
Top 50 ciro listesinde **6 SKU'nun 3 şubede de stoğu 0–3 adet** (8. Sınıf Fen Bilimleri, 8. Sınıf Matematik, 7. Sınıf Gün Gün Paragraf, Yanıt 4. Sınıf Tüm Dersler, 8. Sınıf Paragraf, 9. Sınıf Tüm Dersler). Hepsi hazırlık kitabı, hepsi yıllık 1.000–1.900 adet satıyor, hepsi sezon öncesinde kuru. Bu tek tek "unutma" değil, **kategori-seviyesi yeniden-sipariş boşluğu**.

### B3 — Kuru raf yaygın: raf evreninin %30'u en az bir şubede stoksuz
- **2.696 SKU (%30)** en az bir şubede stok <3 ama o şubede son 12 ayda satış var → 120,6M ₺ ciro taşıyan SKU'lar.
- **392 SKU** üç şubede de kuru ama son 3 ayda satış var (22,2M ₺) → aktif talep, sıfır raf.
- Tarihsel: ortalama **2,6 / 12 ay kuru (%21 OOS-ay)**; SKU'ların **%17'si yılın yarısından fazlasını kuru geçirdi**.

### B4 — Kısmi dağıtım: 3 şubede satıp 1-2 şubede stoklanan ürünler
Top 50 ciro içinde **10 SKU**. Örnek: *8. Sınıf LGS Matematik A Fenomen* — FSM 56 / Özlüce 110 / **İst.Yolu 1** adet stok, oysa İst.Yolu son 12 ayda 439 adet satmış **ve depoda 495 adet duruyor**. Bu bir satınalma değil, **dağıtım/sevk** hatası.
*9. Sınıf Tüm Dersler SB* aynı desende (depoda 71, Özlüce+İst.Yolu kuru).

### B5 — Aşırı stok: 22,6M ₺ bağlı para
Raf evreninde **1.986 SKU'nun kapsamı >365 gün** → son alış birim maliyetiyle **~22,6M ₺** donmuş sermaye. Uç örnekler (top 50 adet içinden): Faber-Castell Köşeli Kurşun Kalem 23.742 ad / 2.219 gün (253K ₺), Faber-Castell Mavi Kopya Kalemi 8.449 ad / 3.168 gün, Pritt-Stick 5.171 ad / 1.130 gün (175K ₺).
⚠️ Kapsam metriği son-3-ay hızına dayanır; **mevsimsel üründe sezon dışı şişer** (kırtasiye Mayıs–Temmuz'da yavaş). Kırtasiye kalemlerinde bu liste sezon-bazlı yeniden okunmalı — ama 2.000+ gün kapsam mevsimsellikle açıklanamaz.

### B6 — Panini FIFA WC 2026: talep patlıyor, raf 7 günlük
Son 1 ayda 2.981 adet (12-ay ortalamasının **4,1 katı**), kapsam **7 gün**, geçmiş 12 ayın **10-11'i kuru**. Tek yükselen momentum kalemi ve elde tutulamıyor. Dünya Kupası takvimi (Haz-Tem 2026) sonrası koleksiyon talebi sürüyor.

### B7 — Şemsiye SKU sorunu (veri kalitesi)
"Bricks Lego Modelleri" (27.772 ad / 3,47M ₺ / birim 125 ₺), "Key Chain - Süs" (91.270 ad), "Suprise Figüre", "Temalı Çorap Serisi" — **tek stkID altında onlarca fiziksel varyant**. Sonuç: SKU-bazlı stok/bulunurluk/devir bu kalemlerde anlamsız (34.659 adet "Key Chain - Süs" stoğunun hangi modelden olduğu bilinmiyor). Bu 4 kalem top-50 cironun önemli bölümünü taşıyor → **model-bazlı barkodlama olmadan bu kalemlerde raf yönetimi yapılamaz**.

### B8 — "Karne Hediyesi" 16.842 adet / 168 ₺ ciro
Adet listesinde 18. sırada ama cirosu neredeyse sıfır (birim 0,01 ₺). Promosyon/bedelsiz kalem POS'ta satış gibi kaydediliyor. Adet-bazlı her sıralamayı ve "en çok satan" iddiasını bozuyor → ciro filtresi olmadan adet listesi kullanılamaz.

---

## 4. Aksiyon Önerisi (öncelik sıralı)

1. **Bugün:** 56 "yalnız bu yıl kritik" SKU için sipariş aç — 79'unda hiç sipariş satırı yok. Sezon 2-3 hafta içinde pik yapar, kitap tedarik süresi bunu yakalar.
2. **Bu hafta:** B4 dağıtım hataları — depoda stok varken kuru şubeye sevk (LGS Matematik A Fenomen 495 ad, 9. Sınıf Tüm Dersler 71 ad). Sıfır satınalma maliyeti, anında ciro.
3. **Bu hafta:** Hazırlık kitabı kategorisinde reorder eşiği gözden geçir (B2). Yıllık 1.000+ adet satan SKU'nun sezon başında 1 adet stokla durması eşik/öneri motoru sorunudur, tek tek insan hatası değil.
4. **Bu ay:** 22,6M ₺ aşırı stok listesini sezon-normalize et, gerçek ölü kalemleri iade/kampanya kuyruğuna al (`frm.frmIadeKural` iade hakkı olan tedarikçilerden başla).
5. **Bu çeyrek:** Şemsiye SKU'ları (B7) model-bazlı ayır — aksi halde en çok ciro getiren oyuncak/hediyelik kalemlerinde bulunurluk yönetimi imkânsız.
6. **Raporlama:** Sınav Okulları paketlerini ve poşeti tüm "çok satan / bulunurluk / stockout" raporlarından yapısal olarak çıkar (bkz. §0).

---

## 5. Metodoloji sınırları (overclaim önleme)

- **Kayıp satış tahminleri ÜST SINIR.** Müşteri ikame ürün almış olabilir (aynı sınıf, başka yayınevi). "X ₺ kaybettik" değil, "X ₺'ye kadar risk" okunmalı.
- **Kapsam (gün) metriği son-3-ay hızına dayanır** → mevsimsel üründe sezon dışında şişer, sezon içinde daralır. Okul ürünlerinde §3-B1'deki sezon-bazlı ölçüm geçerlidir.
- **Şube stoğu `irsHrk` kümülatifidir** (sayım farkları/negatif düzeltmeler 0'a çekildi). Fiziksel raf sayımı değildir.
- **Depo stoğu = ODAK e-ticaret fulfillment stoğu** (`ent.odak_depo_Stok`). WMS raf detayı ve transit mekanlar (26142/4480/4835) hariç.
- **Bulunurluk tanımı gevşek:** aylık giriş bakiyesi ≥3 → "bulunur". Ay içinde tükenip yeniden gelen ürün "bulunur" sayılır; gerçek gün-bazlı raf doluluğu bundan kötüdür (günlük veri `bkm.OneriSiparis`'te 2025-01+ mevcut, bu raporda kullanılmadı).
- **Sipariş kontrolü var/yok seviyesindedir.** `sipAyr.ehSevkAdet` kullanılmıyor, karşılanma oranı ölçülemiyor (bkz. sema `dbo.sip.karsilanma_uyarisi`).
- **E-ticaret satışı bu rapordaki talep hesabına dahil DEĞİL** (şube POS + mağaza satışı). Depo stoğu ise e-tic'i besler — kuru şubeye sevk kararı e-tic talebini de düşürebilir.
