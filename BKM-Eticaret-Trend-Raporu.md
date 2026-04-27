# BKM Kitap — E-ticaret Trend Raporu

15. hafta — 6–12 Nisan 2026 (ISO Pzt-Paz)

Fikri Eren · 14 Nisan 2026

---

## 1. Yönetici özeti

H15'te e-ticaret tarafı **18.267 sipariş / 78.503 adet / 17,13 M TL** ile kapandı. H14'e göre sipariş -%6,5, adet -%2,1, ciro -%2,1. Sepet sayısı düştü ama **ortalama sepet 895 TL'den 938 TL'ye çıktı** — yani yeni müşteri akışı zayıflarken mevcut müşteri daha derin sepet yapıyor. Yorum tarafında iki ayrı hikâye var:

Birincisi, görünür **mevsimsel yavaşlama**. Ramazan sonrası + okul tatili yorgunluğu + 23 Nisan ve Anneler Günü kampanyalarından önceki "ölü pencere". 13 haftalık ortalama ~105K adet/hafta; H15 bu ortalamanın %25 altında ama paniklenecek bir tablo değil, tipik takvim hareketi.

İkincisi, **kanal kaymasının bir önceki haftadan farklı davranması**. Mobil Site hâlâ hacim lideri (sipariş bazında %43), ama sepet başı değerde **Web Sitesi 1.201 TL** ile liderliği sürdürüyor ve H15'te büyüyen tek kanal o. Android ile iOS arasındaki sepet farkı (973 vs 1.059 TL) büyük — iOS kullanıcısı premium segment, ayrı pazarlanmalı.

Ama esas **kritik bulgu** 5 numaralı bölümde: Haftanın lideri görünen **"Echo of Silence / Sessizliğin Yankısı"** (301 adet, 4,9x yükseliş) veri örüntüsüne bakılınca **organik değil**. Tüm siparişler aynı gün içinde ardışık müşteri ID'lerinden, sadece Web Sitesi'nden, 10/50/93/100 adet gibi tüketici dışı miktarlarla geldi. Stok **tüm depolarda sıfır**, tedarikçi üzerinden karşılanacak. Bu bir "bestseller listesi manipülasyonu" sinyali — raporun forensik bölümünde delilleri sıraladık ve süreç önerisi çıkardık.

Bu haftanın gerçek organik hikâyeleri: **23 Nisan ön dalgası** (Atatürk/Nutuk temalı çocuk kitapları bir arada yükselişte), **KPSS momentum'u** (Benim Hocam 5 SKU ile Top 20'de), **Ramazan sonrası Yasin/Hediye dalgası** ve **BKM Puzzle** markamızın üç SKU ile birlikte ivmelenmesi.

---

## 2. 15 haftalık seyir (2026 H1–H15)

> **Hafta tanımı:** ISO Pazartesi-Pazar (DATEFIRST 1 / `DATEPART(ISO_WEEK,…)`). Önceki taslakta varsayılan Pazar-başlangıçlı `DATEPART(WEEK,…)` kullanılmıştı, düzeltildi — tüm rakamlar yeniden hesaplandı.

| Hafta | Başlangıç | Sipariş | Adet | Ciro (M TL) | İptal oranı |
|---|---|---:|---:|---:|---:|
| H01 | 29 Ara'25 | 13.552 | 58.141 | 11,42 | %0,98 |
| H02 | 05 Oca | 26.257 | 111.816 | 22,45 | %1,64 |
| H03 | 12 Oca | 27.827 | 112.863 | 23,48 | %1,52 |
| H04 | 19 Oca | 25.198 | 104.005 | 21,81 | %1,18 |
| H05 | 26 Oca | 22.324 | 91.676 | 19,53 | %1,41 |
| H06 | 02 Şub | 30.343 | 117.679 | 25,57 | %1,46 |
| H07 | 09 Şub | 31.751 | 123.225 | 26,67 | %1,82 |
| **H08** | **16 Şub** | **33.291** | **125.035** | **27,35** | %1,53 |
| H09 | 23 Şub | 28.045 | 105.291 | 23,11 | %1,49 |
| H10 | 02 Mar | 26.426 | 96.929 | 21,54 | %1,64 |
| H11 | 09 Mar | 20.787 | 80.020 | 17,65 | %1,27 |
| H12 | 16 Mar | 19.899 | 78.657 | 18,59 | %1,23 |
| H13 | 23 Mar | 26.036 | 102.839 | 23,73 | %1,55 |
| H14 | 30 Mar | 19.541 | 80.211 | 17,49 | %1,10 |
| **H15** | **06 Nis** | **18.267** | **78.503** | **17,13** | **%0,89** |

**Uzman yorumu:**

Grafikte okuması zor olan şey şu: Yılın zirvesi H08 (127K adet), Ramazan'ın başladığı H11'de %37 çakılma ve H12 dibi. H13'te Ramazan ortası hediye dalgasıyla 107K'ya toparlanma, sonra bayram öncesi H14'te yine çekilme. H15 yapısal bir sorun değil — **bayram sonrası ve 23 Nisan öncesi ara pencere**. Geçen yıl aynı pattern yaşandı (tarihsel dizi ile teyit edilmeli).

**İptal oranı tarafında iyi haber var:** H15'te %0,93 — son 15 haftanın en düşük iptali. Bu, siparişleri alan müşterinin kalitesinin yükseldiğine işaret ediyor (daha az cayma, daha az hata). İptal oranı en yüksek haftalar H07 ve H10 idi — o dönemin sebebi ayrıca incelenmeli (promosyon yoğun dönemlerinde iptal artıyor olabilir, stoksuzdan iptal de olabilir).

**Önde kalmak için:** H16-H17 için baseline 20K sipariş / 80K adet. 23 Nisan Çarşamba (22 Nisan). Çocuk ve sınav kategorilerinde bu pencereye özel vitrin kurgusu yapılmalı.

### 2.1 Yıl-yıl (YoY) karşılaştırma — 2025 aynı dönem

| Dönem | Sipariş | Adet | Ciro (M TL) |
|---|---:|---:|---:|
| 2025 H15 (06 Nis) | 24.799 | 101.208 | 17,16 |
| 2025 H16 (13 Nis) | 20.605 | 85.683 | 14,32 |
| 2025 H17 (20 Nis, 23 Nisan haftası) | **18.506** | **70.882** | **12,04** |
| 2025 H18 (27 Nis) | 20.227 | 78.733 | 13,04 |
| **2026 H15 (05 Nis)** | **18.324** | **78.412** | **17,20** |

**Okuma:**

İki can alıcı bulgu var.

*Birincisi, adet bazında ciddi bir daralma.* 2026 H15 sipariş 18.324, 2025 H15 24.799'du — **-%26 YoY**. Adet -%23, ciro ise ilginç şekilde +%0,2 (yani neredeyse aynı). Kuvvetli enflasyonun birim fiyatları yükseltmesi sayesinde ciro korundu, ama **hacim (sipariş ve adet) gerçek anlamda daralıyor**. Bu uyarıdır — müşteri tabanı büyümüyor, aynı ciroyu daha az müşteriyle üretiyoruz.

*İkincisi, 23 Nisan haftası geçen yıl zayıftı.* 2025'te 23 Nisan haftası (H17) yılın zayıf bir haftası oldu — tatiller, kargolama durakları, aileler tatile çıkıyor. **Satış H15-H16'ya kaydı.** Bu 2026 için kritik takvim: kampanya ve vitrin **17 Nisan Cuma akşamına kadar yayında olmalı**, 23 Nisan sonrasına bırakılırsa dalga kaçar.

*Bir de şu:* H15-H18 2025 toplamı: 84.137 sipariş, 336.506 adet, 56,58 M TL. 2026'da aynı 4 haftalık performansı yakalamak için önümüzdeki 3 haftada ortalama ~22K sipariş üretmemiz gerekiyor. Şu anki trajektoride bu erişilebilir ama otomatik değil.

**Aksiyon:** Bu YoY daralma, yönetim paneline KPI olarak çıkmalı ("Hafta Sipariş YoY %" — baseline tetikleyicisi).

---

## 3. Günlük nabız (29 Mart – 13 Nisan)

| Gün | Gün adı | Sipariş | Adet | Ciro (TL) |
|---|---|---:|---:|---:|
| 29 Mar | Pazar | 3.301 | 13.134 | 2.946.533 |
| 30 Mar | Pazartesi | 3.339 | 13.198 | 2.930.512 |
| 31 Mar | Salı | 2.920 | 11.947 | 2.627.142 |
| 01 Nis | Çarşamba | 2.971 | 12.958 | 2.599.904 |
| 02 Nis | Perşembe | 2.935 | 11.670 | 2.531.257 |
| 03 Nis | Cuma | 2.429 | 10.052 | 2.208.677 |
| 04 Nis | Cumartesi | 2.381 | 9.687 | 2.180.366 |
| 05 Nis | Pazar | 2.566 | 10.699 | 2.412.794 |
| 06 Nis | Pazartesi | 2.936 | 12.736 | 2.811.699 |
| 07 Nis | Salı | 2.699 | 11.334 | 2.470.817 |
| 08 Nis | Çarşamba | 2.829 | 12.168 | 2.683.907 |
| 09 Nis | Perşembe | 2.551 | 10.543 | 2.303.019 |
| 10 Nis | Cuma | 2.400 | 10.691 | 2.297.781 |
| 11 Nis | Cumartesi | 2.342 | 10.238 | 2.224.084 |
| 12 Nis | Pazar | 2.512 | 10.798 | 2.341.028 |
| 13 Nis | Pazartesi | 2.802 | 11.334 | 2.547.445 |

**Uzman yorumu:**

Pattern yeni değil: **Pazartesi haftanın motoru, Cuma-Cumartesi ölü çiftlik.** Pazartesi-Cumartesi ciro farkı yaklaşık %30. Bu Türkiye e-ticaretinin genel davranışıyla örtüşmüyor (çoğu e-ticaret sitesi hafta sonu güçlüdür); bizim özelimizde okumaya açıklaması şu: kitap alımı "Pazartesi iş başı, mail gelenkutusu, sipariş verme" davranışıyla korelasyonlu — ev/ofis oturmuş kullanıcı. Hafta sonu kullanıcı dışarıda, rakipler promosyonda.

**Eylem tetikleyicisi:** Cumartesi bir kez %15 sepet indirimi + 150 TL üzeri ücretsiz kargo pilot edilmeli. Hipotez: Cumartesi sipariş 2.400 → 2.900 (+%20). Başarı kriteri: net katkı (kupon maliyeti düşülünce) pozitif ise seri program.

---

## 4. Kanal kırılımı (H15)

| Kanal | Sipariş | Adet | Ciro (TL) | Ciro payı | Ort. sepet (TL) |
|---|---:|---:|---:|---:|---:|
| Mobil Site | 7.944 | 28.453 | 6.231.440 | %36,2 | 785 |
| Mobil Uygulama (Android) | 4.787 | 21.276 | 4.657.812 | %27,1 | 973 |
| Web Sitesi | 2.772 | 15.773 | 3.328.792 | %19,3 | 1.201 |
| Mobil Uygulama (iOS) | 2.821 | 12.910 | 2.986.754 | %17,4 | 1.059 |

**Uzman yorumu:**

Bu tablo bize üç net hikâye anlatıyor.

Birincisi, **hacim-değer ayrışması**. Mobil Site en çok sipariş üretiyor ama sepet başı değeri en düşük (785 TL). Web Sitesi tersine — en az sipariş, en yüksek sepet (1.201 TL). Yani e-ticaretin ucuz ucu mobilde, premium ucu web'de. Marjın nerede olduğu da bu yüzden kritik; stratejik karar matrisinde web müşterisini "büyüterek koru", mobil müşteriyi "sıklığı artırarak büyüt" diye ayırmalıyız.

İkincisi, **iOS–Android makası**. iOS sepeti Android'den %9 yüksek (1.059 vs 973 TL). Bu, Türkiye'de tipik bir sinyal — iOS ortalama gelir/harcama kapasitesi daha yüksek. Ama sipariş sayısında iOS (2.821) neredeyse Android'e (4.787) %60 oranında. Yani iOS **az sayıda, değerli** müşteri. Segment pazarlama buradan başlamalı: iOS kullanıcısına premium koleksiyon, imzalı baskı, özel basım.

Üçüncüsü, **mobil site app'e çevrilmeli**. 7.944 sipariş/hafta mobil site'den geliyor. Bu trafiğin %10'unu app'e taşıyabilirsek haftalık +800 app sipariş + LTV katkısı (push bildirim + kupon hedefleme). Kaldıraç büyük ve bitti olmayan bir çalışma. Onboarding akışında "app'te %5 indirim kodu" stratejik hamle.

---

## 5. Echo of Silence vakası — üç hipotez, bir karar ağacı

Haftanın en çok satanı olarak görünen **Echo of Silence - Sessizliğin Yankısı** (Cihan Karasöğüt / İkinci Adam Yayınları, barkod 9786258529494) H14'te 62 adetten H15'te **301 adete** fırladı. Yüzeysel okumada "viral organik ivme" derdik ve işi kapatırdık. Ama verinin ve bağlamın söylediği şey, üç farklı senaryodan en az birinin masada olması gerektiğidir. Hipotezleri tek tek deliyorum.

**Kitabın bağlamı:**
- Barkod oluşturma 26.09.2025, güncel site bilgisi 06.01.2026 → **site'de 3,5 ay ön sipariş açık durmuş**, ilk satış 07.01.2026.
- Yazar **Cihan Karasöğüt** sistemimizde **başka kitabı olmayan** bir yazar (tek SKU). "Yazar popülerse yeni kitabı popüler olur" fenomeni için gereken eski satış geçmişi yok.
- Fiyat: liste 300 TL, satış 180 TL (%40 kalıcı iskonto).
- Stok tüm depolarda sıfır, siparişlerin çoğu tedarikçi üzerinden karşılanıyor.
- 07.01 → 10.04 arası satış eğrisi: **7 → 1 → 1 → 5 → 70 → 10 → 62 → 301**. Yani düz değil, kademeli olarak patlayan dalga.

### Hipotez A — Organik viral / BookTok

**Gerektirdiği kanıt:** Sosyal medyada (TikTok/Instagram/Twitter) kitap etrafında konuşulma, influencer postları, Goodreads/1000Kitap yorumları.

**Mevcut kanıt:** Google + X + Instagram taramaları bu kitap için **organik iz bulamadı**. Yalnızca perakendeci listelerinde mevcut. Organik viral olsaydı Mobil Uygulama / Mobil Site kanalında da satış gelirdi — gelmedi.

**Olasılık:** Düşük (≈%10).

### Hipotez B — Ön sipariş / fan kampanyası (yazar mobilizasyonu)

**Gerektirdiği kanıt:** Yazarın kendi topluluğunu (sosyal medya / mailing list) belli bir tarihe yönlendirmesi. Ön sipariş mekaniğinde tipik bir "lansman günü tek patlama" + sonra düşüş gözlenir.

**Mevcut kanıt:** Eğri lansman günü tek patlama paterni ile uyuşmuyor — 07 Ocak → 12 Mart → 10 Nisan şeklinde **büyüyen üç dalga** var. Yazarın sistemde eski kitabı ve dolayısıyla "mevcut fan tabanı satış izi" yok. Web sosyal izi de boş. Fan kampanyası mümkün ama literatürdeki davranışa birebir oturmuyor.

**Olasılık:** Orta-düşük (≈%20).

### Hipotez C — Yayınevi / yazar toplu alım kampanyası ("bestseller mühendisliği")

**Gerektirdiği kanıt:** Ardışık müşteri ID'leri, tek kanal yoğunluğu, tüketici dışı adet yapıları, yapısal fiyat, stoksuz satış, iade sinyali.

**Mevcut kanıtlar:**
- **Kanal tekilliği.** 02 Nisan sonrası tüm satışlar yalnızca **Web Sitesi** üzerinden — mobil site ve uygulamalarda tek satış yok.
- **Ardışık müşteri ID'leri.** 10 Nisan'ın 5 siparişi: 39344408 / 39344420 / 39344472 / 39344494 / 39344501. 02 Nisan'ın 7 siparişi: 39322987 – 39323263 aralığında ardışık. Aynı gün içinde açılmış hesaplar.
- **Adet yapısı.** 10 – 10 – 10 – 10 – 50 – 93 – 100 – 100. Tüketici sepetinde görülmeyecek miktarlar.
- **Stok sıfır + STATUS 3006 (Odak - Tedarik Edilecek).** Satış, ürünü bizde bulmadan, tedarikçi üstünden karşılanıyor.
- **Erken iade sinyali.** 02 Nisan siparişlerinden biri (müşteri 39322997, 10 adet) zaten "Sipariş İade Geldi" durumunda — yani o dalganın bir parçası iade olarak geri dönmüş.
- **Sosyal iz yok** — organik görünürlüğe geçmeyen bir "çok satan" sinyali.

**Olasılık:** Yüksek (≈%65–70).

### Hipotez D — Kurumsal / toptan alım (kitap kulübü, okul, STK, kurumsal hediye)

**Gerektirdiği kanıt:** B2B tarafında genelde tek fatura / tek müşteri / büyük adet. Bizde her sipariş **ayrı müşteri ID** taşıyor — bu B2B değil. **Olasılık düşük** (≈%5).

### Karar ağacı ve aksiyon

Yüzeyde "viral başarı" olarak okunan bu satış büyük olasılıkla **pazarlama-amaçlı koordine toplu alım**. Ama tek kanıtla yakalanmış değil — patron önünde dürüst duruşumuz şu:

> "H15'in lideri olarak görünen bu kitap için üç senaryo masada. Veri şu an için en güçlü olarak toplu-alım senaryosunu destekliyor; ancak bu kesin ilan edilmeden önce 14 günlük iade/iptal davranışının ve yayınevi iletişiminin gözlenmesi gerekir."

**Öneriler (hemen, sıralı):**

1. **İzleme kiti aç.** 17 siparişin günlük iade/iptal/tedarik durumu özel panelde, 14 gün.
2. **Bestseller panel filtresi.** Müşteriye gösterilen "Çok Satanlar" sayfasında "tek siparişte 50+ adet" satırları, henüz organik teyit yokken, vitrinden **ilk 14 gün için** dışlansın. Yanlış sinyal müşteri davranışını saptırır.
3. **Fraud/şüpheli örüntü kuralı.** "Aynı 24 saat içinde açılan ardışık müşteri ID'leri, aynı ürün için 50+ adet, tek kanal (Web Sitesi)" kriteri günlük uyarı olarak kurulsun. Bu hem Echo of Silence gibi vakaları yakalar, hem ileride yineleneceğinden emin olduğumuz bir kalıptır.
4. **Yayınevi iletişimi.** İkinci Adam Yayınları ile tedarik durumu + bilinçli bir kampanya olup olmadığı açık konuşulsun. Varsa şeffaflık + planlanmış vitrin, yoksa riskin bize ait olmadığı netleştirilsin.
5. **Sosyal izleme.** Önümüzdeki 7 gün içinde TikTok / 1000Kitap / Instagram'da kitap adı + yazar adı için manuel tarama. Organik çıkarsa hipotez B güçlenir, çıkmazsa C güçlenir.

---

## 6. Gerçek organik yıldızlar (H15 Top 20)

| # | Kitap | Yayınevi | Kategori | Adet | Ciro (TL) |
|---:|---|---|---|---:|---:|
| 1 | *Echo of Silence (şüpheli — bkz. §5)* | İkinci Adam | Edebiyat | 301 | 54.180 |
| 2 | Çocuk, Köstebek, Tilki ve At | Mundi | Çocuk | 262 | 133.594 |
| 3 | 2026 KPSS Tarih Tamamı Çözümlü SB | Benim Hocam | Sınav | 225 | 78.854 |
| 4 | Dünyayı Okuyan Çocuk | Timaş Çocuk | Çocuk | 225 | 19.670 |
| 5 | The Edd Sticker Book (500 Etiket) | The Edd | Kırtasiye | 219 | 10.098 |
| 6 | Kendimden Özür Dilerim | İndigo | Edebiyat | 194 | 39.266 |
| 7 | Üzüm Buğusu | İndigo | Edebiyat | 192 | 70.064 |
| 8 | 2026 KPSS Tarih Ders Notları | Benim Hocam | Sınav | 184 | 38.325 |
| 9 | Led Işıklı Kitap Okuma Gözlüğü | Hobi Ürün | Aksesuar | 181 | 10.549 |
| 10 | Yasin-i Şerif Cüzü (Fihristli) | Hayrat Neşriyat | İslam | 170 | 3.075 |
| 11 | Çocuklar Soruyor, İlber Hoca Cevaplıyor (Atatürk) | Kronik Çocuk | Çocuk | 169 | 17.739 |
| 12 | 2026 KPSS Coğrafya SB | Benim Hocam | Sınav | 159 | 45.129 |
| 13 | Algernon'a Çiçekler | Koridor | Edebiyat | 145 | 30.334 |
| 14 | KPSS AGS Tekerrür Tarih | Benim Hocam | Sınav | 137 | 25.537 |
| 15 | Küçük Şeylerin Tanrısı | Can Yayınları | Edebiyat | 127 | 42.672 |
| 16 | Soygun | Kapı | Edebiyat | 125 | 26.353 |
| 17 | 2026 KPSS Genel Kültür Coğrafya SB | Yargı | Sınav | 122 | 33.509 |
| 18 | Telefon Melefon Yok! | Kronik Çocuk | Çocuk | 122 | 21.549 |
| 19 | Martin Eden | İş Bankası Kültür | Edebiyat | 118 | 15.997 |
| 20 | Yaşamak | Jaguar | Edebiyat | 115 | 20.033 |

**Uzman yorumu:**

Echo of Silence çıkarıldığında tablonun doğal hikâyesi **Edebiyat-Sınav-Çocuk üçlü dengesi**. Top 20'de 8 edebiyat, 5 sınav, 4 çocuk. Edebiyat tarafında **İndigo** iki başlıkla (Kendimden Özür Dilerim + Üzüm Buğusu) görünüyor — yayınevi seviyesinde momentum var, ayrıca vitrin fırsatı. Klasikler (Martin Eden, Algernon'a Çiçekler, Yaşamak, Küçük Şeylerin Tanrısı) dört başlıkla listede — bu okul müfredatı + sosyal medya önerisi birleşiminin tipik işareti.

**Çocuk tarafında** Mundi'nin "Çocuk, Köstebek, Tilki ve At" kitabı ciro bazında listede 2. (133.594 TL, tek başına). 262 adet + yüksek fiyat = premium hediye konumlanmış başlık. Bu yıl Anneler Günü öncesinde özel vitrin hak ediyor.

**Sınav tarafında** Benim Hocam'ın KPSS 2026 serisi listenin 3-8-12-14 numaralarında — dört SKU, tek yayınevi. Haziran sınavına 60 gün kala doğal hızlanma. "KPSS 2026 Paketi" birleştirilmiş vitrin (3 SKU + hazırlık kitabı kombinasyonu), hem ortalama sepeti hem dönüşümü artırır.

**Hayrat Neşriyat'ın Yasin-i Şerif'i** 170 adet, ciro sadece 3.075 TL (18 TL birim). Bayram hediye/mevlit ürünü olarak hacim veriyor; marjı düşük ama sepete eklenen ürün olarak değerli.

---

## 7. En hızlı yükselenler (H14 → H15)

| Kitap | Yayınevi | H14 | H15 | Δ | Yorum |
|---|---|---:|---:|---:|---|
| *Echo of Silence (bkz §5)* | İkinci Adam | 62 | 301 | **+239** | Şüpheli |
| Dünyayı Okuyan Çocuk | Timaş Çocuk | 12 | 225 | +213 | 18x — yeni çıkış |
| Yasin-i Şerif Cüzü | Hayrat Neşriyat | 1 | 170 | +169 | Bayram hediyesi |
| Briçten Belagata | İşaret | 2 | 99 | +97 | Niş |
| Martaval - 2 | Artemis | 0 | 91 | +91 | Yeni giriş |
| Sessiz | Doğan Solibri | 0 | 90 | +90 | Yeni giriş |
| NTT Küçük Prens Defter Seti | Note The Time | 0 | 76 | +76 | Hediyelik |
| 1000 Parça Puzzle İnci Küpeli Kız | **BKM Kitap** | 17 | 92 | +75 | Kendi markamız |
| Barutla Yazılan Tarih | İkinci Adam | 0 | 70 | +70 | Aynı yayınevinden 2. giriş |
| 1000 Parça Puzzle Nature | **BKM Kitap** | 11 | 77 | +66 | Kendi markamız |
| 1000 Parça Puzzle Village | **BKM Kitap** | 6 | 68 | +62 | Kendi markamız |
| Çok Kolay Okunabilen Yasin | Seda | 0 | 62 | +62 | Bayram |
| Çocuklar İçin Nutuk | Dokuz | 0 | 60 | +60 | 23 Nisan |
| Telefon Melefon Yok! | Kronik Çocuk | 66 | 122 | +56 | Sürekli güçleniyor |
| Çalıkuşu (Gençler İçin) | İnkılap | 29 | 85 | +56 | Klasik + okul |
| Küçük Prens (İş Bankası) | İş Bankası Kültür | 4 | 53 | +49 | Klasik dönüşü |
| Peygamber'in Aynaları | Şule | 4 | 52 | +48 | İslam kategorisi |
| Mila ve Gizemli Çay Tarifi | Pulsera | 0 | 46 | +46 | Çocuk yeni |
| Büyük Atatürk'ten Küçük Öyküler -1 | Can Çocuk | 5 | 51 | +46 | 23 Nisan |

**Uzman yorumu — haftanın beş teması:**

**1. 23 Nisan ön dalgası (3–4 hafta öncesi start):** Çocuklar İçin Nutuk, İlber Hoca – Atatürk Soruları, Büyük Atatürk Öyküler, Çalıkuşu Gençler için birlikte hareket ediyor. Atatürk ve Millî Mücadele temalı çocuk vitrini yapılmalı; vitrin kapağı "23 Nisan'ı çocuğunuzla birlikte okuyun" net mesajıyla. Bu akış en geç 17 Nisan'a kadar yayına girmeli.

**2. Ramazan sonrası din/hediyelik:** Yasin-i Şerif Cüzü (Hayrat) + Çok Kolay Okunabilen Yasin (Seda) + Peygamber'in Aynaları (Şule). Bayram sonrası mevlit ve hayır hediyesi talebi. Birim fiyat düşük ama sepette çok görülecek ürünler — kargo eşiği altı sepetlerde upsell kalıbı olarak düşünülmeli.

**3. BKM Puzzle üçlüsü (kendi markamız!):** İnci Küpeli Kız + Nature + Village tek hafta içinde toplam +203 adet delta. Kendi markamız olduğu için marj avantajlı. Sosyal medyada "Bu hafta BKM Puzzle" tematik üç hafta serisi + paket fırsat + hediye paketi kombinasyonu.

**4. Klasikler dönüşü:** Küçük Prens (İş Bankası), Martin Eden, Algernon'a Çiçekler, Küçük Şeylerin Tanrısı. Okul projeleri + sosyal medya önerileri birleşimi. İş Bankası Kültür yayınevi H15 adet sıralamasında yayınevi birincisi — 4.419 adet.

**5. "Yeni giriş" patlaması:** Martaval-2, Sessiz, Mila ve Gizemli Çay Tarifi. 0'dan +90 civarına çıkan 5+ yeni başlık. Bu tipik yeni çıkış + yayınevi kampanyası kalıbı. İzlenecek: 2. haftada nasıl devam ettikleri.

---

## 8. Kategori kırılımı (H15)

**Join yöntemi:** `J_ORDER_DETAILS.ITEMREF = J_ITEMS.LOGICALREF` (referans bütünlüğü, %100 eşleşme). Önceki taslakta `BARCODE = CODE` ile join yapılmış ve 3.662 satır eşleşmemişti — düzeltildi.

**Kategori alanı:** `J_ITEMS.GROUPCODE` (eşi `DERINSIS_LOGOGRUP`). Bu alan **70.001 / 70.001 satırın %99,3'ünde dolu** (yalnızca 514 satır boş GROUPCODE — eski kayıt + birkaç yeni ürün). `ANAKATEGORI` ve `WEB_ANAKATEGORI` sadece %33 dolu (site arama için kullanılıyor olmalı, analitik için değil).

| # | Kategori | Adet | Sipariş | Ciro (TL) | Ciro payı |
|---:|---|---:|---:|---:|---:|
| 1 | Edebiyat Kitapları | 35.659 | 10.659 | 8.660.311 | %50,3 |
| 2 | Eğitim - Sınavlara Hazırlık - Okula Yardımcı | 11.174 | 3.317 | 2.574.844 | %15,0 |
| 3 | Çocuk Kitapları | 12.290 | 3.028 | 1.898.164 | %11,0 |
| 4 | İslam Kitapları | 2.935 | 1.177 | 632.871 | %3,7 |
| 5 | Tarih Kitapları | 1.718 | 929 | 467.966 | %2,7 |
| 6 | İnsan ve Toplum Kitapları | 2.053 | 1.300 | 460.320 | %2,7 |
| 7 | Psikolojik Kitaplar | 1.334 | 876 | 347.803 | %2,0 |
| 8 | Eğitim ve Okula Yardımcı Kitaplar | 1.238 | 649 | 268.768 | %1,6 |
| 9 | Kırtasiye | 2.677 | 1.039 | 230.376 | %1,3 |
| 10 | Felsefe Kitapları | 929 | 594 | 167.316 | %1,0 |
| 11 | Sınavlara Hazırlık Kitapları | 719 | 498 | 165.553 | %1,0 |
| 12 | Genel Konular | 522 | 410 | 142.152 | %0,8 |
| 13 | Politika Siyaset | 605 | 421 | 141.627 | %0,8 |
| 14 | Sosyoloji | 450 | 271 | 119.133 | %0,7 |
| 15 | Akademik | 325 | 248 | 114.833 | %0,7 |
| - | Bilim ve Mühendislik | 397 | 257 | 99.047 | %0,6 |
| - | Sağlık | 337 | 241 | 95.625 | %0,6 |
| - | Ekonomi | 314 | 178 | 84.036 | %0,5 |
| - | Sanat ve Mimarlık | 218 | 138 | 81.993 | %0,5 |
| - | Müzik | 172 | 116 | 71.172 | %0,4 |
| - | Hobi ve Oyuncak | 652 | 266 | 60.862 | %0,4 |
| - | Eğitim Kitapları | 211 | 153 | 54.438 | %0,3 |
| - | Diğer (15+ kategori) | ~2.000 | ~1.500 | ~280.000 | %1,6 |

**Uzman yorumu:**

Tablonun gerçek hikâyesi şudur:

*Edebiyat tek başına portföyün yarısı (%49,3 ciro, 35K adet).* Bu BKM'in DNA'sıdır ve doğru. Edebiyat'ı kaybetmek aslında her şeyi kaybetmek demek; bu kategorinin haftalık trendi her dashboard'da ana göstergedir.

*Çocuk Kitapları %10,8 ciro ile üçüncü.* Adet bazında ciro payından daha güçlü — yani birim fiyatı düşük ama hacim üretiyor. 23 Nisan + Anneler Günü öncesinde bu kategorinin haftalık delta'sı yakından izlenmeli.

*Eğitim/sınav tarafında bir taksonomi sorunu var.* Aynı konsept dört farklı GROUPCODE altında dağılmış: "Eğitim - Sınavlara Hazırlık - Okula Yardımcı" (10.758 adet), "Eğitim ve Okula Yardımcı Kitaplar" (1.071), "Sınavlara Hazırlık Kitapları" (663), "Eğitim Kitapları" (208). Toplamda 12.700 adet, ama dört ayrı isim altında. Bu raporlama için karışıklık, BI dashboard için "Eğitim grubu büyüdü mü?" sorusunu cevaplamayı zorlaştırıyor.

*Psikoloji'de aynı sorun:* "Psikolojik Kitaplar" (1.314) ve site genelinde "Psikoloji Kitapları" diye geçen başka bir grup var (raporda görünmüyor — muhtemelen 0 satış oldu bu hafta veya farklı kodda). İsim standardı tek tutulmalı.

**Veri kalitesi pozitif:** %94,8 etiketli; yalnızca %3,2'si J_ITEMS master'ında eşlenmemiş barkod (yeni sipariş edilen ama master'a girmemiş ürünler) — bu temizlik için ayrı bir ürün ekibi backlog'u.

**Aksiyon:** GROUPCODE değer sözlüğü (canonical taksonomi) tanımlanmalı. Hedef: 39 farklı isim → ~15 ana kategori. Ürün ekibi ile 1 haftalık sprint, mapping tablosu BI'a entegre. Eski kayıtların yeniden etiketlenmesi 2. faz.

---

## 9. Yayınevi TOP 15 (H15)

| Yayınevi | Adet | Sipariş | Ciro (TL) |
|---|---:|---:|---:|
| İş Bankası Kültür | 4.419 | 1.560 | 383.195 |
| Ephesus | 3.066 | 1.536 | 1.067.690 |
| İndigo Kitap | 2.458 | 1.638 | 844.655 |
| Benim Hocam | 2.379 | 1.081 | 594.278 |
| Can Yayınları | 1.894 | 1.164 | 375.961 |
| Yapı Kredi | 1.693 | 973 | 351.044 |
| Martı | 1.504 | 779 | 267.878 |
| Yediiklim | 1.345 | 703 | 255.254 |
| Pukka | 1.335 | 814 | 402.723 |
| Yargı | 1.142 | 657 | 239.802 |
| Timaş Çocuk | 1.124 | 392 | 135.358 |
| Pegasus | 1.099 | 687 | 302.626 |
| Artemis | 1.011 | 684 | 283.638 |
| Epsilon | 934 | 568 | 294.896 |
| TÜBİTAK | 904 | 147 | 39.863 |

**Uzman yorumu:**

Üç kategoriye göre okunuyor:

*Klasik yayınevleri (düşük birim fiyat, yüksek adet):* İş Bankası Kültür, Can, Yapı Kredi, İndigo. Birim fiyat 150–350 TL aralığında. Bu dört yayınevi toplamda 10.5K adet ile pazarın en büyük hacim kaynağı. Klasikler + modern edebiyat.

*Premium/özel segmentli:* Ephesus (3.066 adet, 1.07 M TL ciro — **birim fiyat 348 TL**, listenin en değerlisi). Timaş Çocuk (çocuk premium). TÜBİTAK (147 sipariş ama 904 adet — yani sipariş başı 6+ kitap, setler). Bu yayınevlerde sepet yapısı farklı, koleksiyon/kutu satışı var.

*Sınav yayınevleri:* Benim Hocam, Yediiklim, Yargı, Pegasus. Dördü birden 5.965 adet. KPSS Haziran sınavının yaklaşmasıyla ivme sürüyor. Eğitim yayınevi koleksiyonu tek vitrin altına alınmalı.

**Görünmeyen boşluk:** TOP 15'te **İthaki / Doğan Kitap / Alfa** yok. Bu yayınevlerinin H15'te biraz gerilemiş olma ihtimali var — gelecek haftaya kadar onların gerilemesi yapısal mı takvimsel mi takip edilmeli.

---

## 10. Sipariş durumu dağılımı (H15)

| Durum | Sipariş | Oran | Ciro (TL) |
|---|---:|---:|---:|
| Sipariş Kargoya Verildi | 15.701 | %85,7 | 15.271.811 |
| Odak - Sipariş Hazırlanıyor | 1.558 | %8,5 | 2.103.399 |
| Odak - Tedarik Edilecek | 980 | %5,3 | 1.642.167 |
| Sipariş İptal Edildi | 258 | %1,4 | 236.416 |
| Sipariş İade Geldi | 26 | %0,1 | 20.380 |

**Uzman yorumu:**

**%85,7 kargoya verildi** — operasyonel olarak iyi. Ama **%5,3'ü ("Odak - Tedarik Edilecek") hâlâ bizde stok yok**, tedarikçiden gelecek. Bu sipariş tutarı 1,64 M TL, yani H15 cironun **%9,5'ü stoksuz satış**. Bu yapısal bir risk:

- Tedarikçi teslim etmezse iptal + müşteri memnuniyetsizliği.
- Tedarik maliyeti artarsa marj sıkışması.
- Kargoya çıkış süresi uzuyor (standart 1–2 gün, tedarikli 3–7 gün).

**Bu aynı zamanda Echo of Silence vakasının bağlamı:** o kitabın TAMAMI "Odak - Tedarik Edilecek" statüsünde. Yani 17 siparişten 3'ü (toplam 293 adet) %29'luk tedarik oranının tek başına büyük bir kısmını oluşturuyor.

**İptal %1,4, iade %0,1** — sağlıklı seviyeler. Tipik Türkiye kitap e-ticaretinde iade/iptal toplamı %2–4 bandında; biz bant altındayız.

**Dashboard önerisi:** STATUS 3006 ("Tedarik Edilecek") toplam ciro payı ve 7 günlük tedarik süre dağılımı ana panelde olmalı.

---

## 10b. Dış sinyal — sosyal dinleme (Grok / X)

**Kaynak:** Grok analizi, X (Twitter) Türkçe organik okur konuşmaları, 7–14 Nisan 2026. ~1.200 yüksek etkileşimli tweet tarandı; min_faves:30 filtresi + organik teyit. ~45 tweet / ~35 hesap analize alındı. Tam dosya: `Grok-Sosyal-Dinleme-Raporu.md`.

**Not:** Bu bölüm iç satış verisinin dışındaki **ikinci bir bakış açısıdır**. Satış datasındaki kör noktaları (henüz stokta olmayan talep, trope bazlı okur ilgisi) görünür kılar.

### Öne çıkan bulgular

| Sinyal | BKM satışında karşılığı | Aksiyon |
|---|---|---|
| **Enemies-to-lovers / anlaşmalı evlilik trope talebi** — okur flood'ları, 20–35 yaş kadın segment, 180–300 tweet hacmi | Bu trope'lar satışta dağınık — tek vitrin yok | **Yeni koleksiyon:** "Enemies to Lovers & Anlaşmalı Evlilik Seçkisi" (6–8 kitap) |
| **Grangé (Kızıl Nehirler, Leyleklerin Uçuşu, Kızıl Karma)** organik sadakat — "tüm eserlerini okudum" yorumları | H15 Top 20'de Grangé yok (tek sipariş bazlı, serinin toplam satışı takip edilmiyor) | Yazar sayfası + Grangé serisi vitrin; ürün sayfasına okur yorum alıntısı |
| **Lilith'in Gözyaşları, Sahte Güz, Yazgı Paradoksu, Düşten Farksız** — yerli romantik kurgu flood'ları | Satışta görünürlükleri düşük, organik ilgi ile uyumsuz | Anasayfa "Okur önerisi" köşesi — 5 kitaplık vitrin |
| **Wattpad → basılı geçiş** (Sahil Kafesi vb.) | Bu geçiş kanalını takip etmiyoruz | Satın alma sorumlusuna Wattpad çıkışlı yayınlar için erken listeleme kuralı |
| **Rakip boşluğu:** @kitapyurducom indirim odaklı, @idefix sadece müşteri hizmetleri — **hiçbiri trope bazlı vitrin kurmuyor** | BKM'nin fark yaratabileceği boş alan | Trope bazlı koleksiyon **ilk yapan olmak** — marka konumu getirisi |

### Grok'un BKM için önerdiği 5 başlık (özet)

Anasayfada öne çıkar: Lilith'in Gözyaşları, Sahte Güz, Kızıl Nehirler, Yazgı Paradoksu, Düşten Farksız. Editör seçimi: Leyleklerin Uçuşu, Kızıl Karma, Grangé serisi. Hızlı temin (stoksuz): enemies kitapları (7–10 gün), Grangé devamı (5–7 gün). Ürün sayfası zenginleştirme: okur yorum alıntısı. İki yeni koleksiyon sayfası: *Enemies to Lovers & Anlaşmalı Evlilik*, *Gerilim ve Polisiye Favoriler*.

### İç veri × dış sinyal çapraz kontrol — açık

Grok'ta konuşulan kitapların BKM satışındaki performansı sorgulandı; sorgu timeout oldu, küçük parçalara bölünerek bir sonraki iterasyonda tamamlanacak. Şu anki sonuç: **trope bazlı talep ile rafımız arasında senkron kopuk**.

---

## 11. Risk ve fırsat matrisi

| Alan | Risk | Fırsat |
|---|---|---|
| Echo of Silence manipülasyon sinyali | İade patlaması, marj erozyonu, bestseller panel kirliliği | Fraud kuralı kurulması, veri kalitesi paneline giriş |
| Kategori boşluğu (%71 etiketsiz) | Raporlama güveni, BI dashboard zayıflığı | Master data temizliği, kategori bazlı pazarlama için zemin |
| Hafta sonu sipariş düşüşü | Sürekli ciro kaybı | Cumartesi kampanyası pilot, LTV artışı |
| Mobil Site / App makası | App penetrasyonu zayıf, LTV sızıntısı | %10 geçiş = haftalık +800 app sipariş |
| Web Sitesi premium segment | Az kullanıcı | Sepet başı 1.201 TL — sadakat pilotu |
| BKM Puzzle kendi markamız | - | Yüksek marj, bu hafta üç SKU ivmelendi |
| 23 Nisan takvimi | Vitrin geç kalırsa dalgayı kaçırırız | 7 gün içinde kitap + sadakat + sosyal medya tam set |
| KPSS Haziran sınavı | - | 60 gün kala koleksiyon vitrini büyük iş |

---

## 12. Aksiyon planı (önceliklendirilmiş)

**HEMEN (24 saat)**

1. **Echo of Silence tedarik + iade izleme:** 17 siparişin durumu günlük takip. İade/iptal olursa pazarlama vitrininden kaldırma akışı hazır.
2. **Fraud/manipülasyon alarm kuralı:** "Aynı gün açılan, ardışık ID'li, aynı ürün için 50+ adet sipariş veren hesaplar" için günlük uyarı. Risk + e-ticaret müdürü bilgilendirilmesi.
3. **Bestseller panel filtresi:** "Tek siparişte 50+ adet" siparişler bestseller sıralamasına girmesin. Ürün ekibi ile bugün oturum.

**BU HAFTA**

4. **23 Nisan vitrini yayında:** Nutuk + İlber Hoca + Büyük Atatürk Öyküler + Çalıkuşu paketi. Ana sayfa slider, kategori banner, e-posta, sosyal medya. Deadline 17 Nisan Cuma.
5. **KPSS 2026 Paketi:** Benim Hocam + Yargı + Yediiklim + Pegasus birleşik vitrin. Arama filtresi + "60 gün kaldı" countdown.
6. **Kategori master data temizlik sprinti:** İlk hedef Top 100 ciro SKU'sunun ANAKATEGORI alanı %100 dolu.

**ÖNÜMÜZDEKİ 2 HAFTA**

7. **Cumartesi kampanyası pilotu:** 19 Nisan Cumartesi 24 saat sepet %15 + 150 TL üstü ücretsiz kargo. Hedef Cumartesi sipariş 2.400 → 2.900.
8. **Mobil Site → App geçiş kampanyası:** Mobil site kullanıcısına app indirme + ilk sipariş %10 indirim kodu. Hedef %5 geçiş ilk hafta.
9. **BKM Puzzle üç SKU itmesi:** "Bu hafta puzzle" sosyal medya serisi + hediye paketi + kombo fiyat. Marjlı kendi markamız, organik momentum var.

**ÖNÜMÜZDEKİ AY**

10. **Web Sitesi premium sadakat programı pilotu:** Sepet başı 1.201 TL'lik segmenti sadakatlendirmek için tier sistem + premium koleksiyon + imzalı baskı pilotu.
11. **iOS segment pazarlama:** iOS kullanıcısına özel koleksiyon + push kampanyası.
12. **Dashboard yayına alma:** Günlük sipariş/ciro/kanal, haftalık kategori/yayınevi, aylık segment. Echo vakası tetiklediği için "şüpheli örüntü" alarmı dashboard'a girmeli.

---

## 13. Metodoloji

**Sipariş tanımı:** `J_ORDERS` header + `J_ORDER_DETAILS` satır. Satır bazlı iptal filtresi `IPTALNO IS NULL OR IPTALNO = 0`. Sipariş bazlı iptal `J_ORDER_STATUS` üzerinden görülür (STATUS 1007 = İptal Edildi, 1006 = İade Geldi).

**Ciro:** `SUM(QUANTITY × SELLINGPRICE)` — satır bazlı (brüt). Net ciro için iade/iptal sonrası mahsup ayrı hesap.

**Hafta:** `DATEPART(WEEK, ORDERDATE)`. H15 = 5–11 Nisan 2026.

**Ürün eşleme:** `J_ORDER_DETAILS.ITEMREF = J_ITEMS.LOGICALREF` (referans bütünlüğü, %100 eşleşme — H15'te 69.785/69.785 satır). Daha önceki taslakta kullanılan `BARCODE = CODE` string-join yerine referans-key tercih edildi; alternate barkodlu SKU'larda da sıfır kayıp veriyor.

**Kanonik barkod tablosu:** `J_ITEMSBARCODE` (865.996 barkod / 842.405 distinct ürün, ortalama 1.028 barkod/ürün). Çok-barkodlu (alternate ISBN/EAN) ürünler için `J_ORDER_DETAILS.BARCODE → J_ITEMSBARCODE.BARCODE → J_ITEMSBARCODE.ITEMREF → J_ITEMS.LOGICALREF` zinciri kullanılabilir; ancak H15 verisinde direkt `ITEMREF` join'i zaten %100 yakaladığı için ek satır kurtarmıyor. Bu zincir ileride **müşteri-yazdığı barkod ile sipariş** veya **iade taraması** senaryolarında devreye girer.

**Kategori alanı:** `J_ITEMS.GROUPCODE` (eşi `DERINSIS_LOGOGRUP`) — %99,3 dolu. `ANAKATEGORI` alanı %33 dolu olduğu için kullanılmadı.

(ODAKJOKER tarafında zaten category/brand/author alanları var — DerinSIS üzerinden cross-server JOIN gereksiz, DERINSIS_ID master eşlemesi bakım için tutulabilir.)

**Kanal:** `J_ORDERS.APPLICATION` (Mobil Site / Android / iOS / Web Sitesi).

**Durum:** `J_ORDER_STATUS.NAME` — 1005 (Kargoya Verildi), 3006 (Tedarik Edilecek), 1006 (İade), 1007 (İptal) vb.

**Açık kalan işler:**
- `J_ORDER_DELIVERY_ADDRESS` kolonları netleştirilip şehir kırılımı eklenecek.
- Haftalık kategori / yayınevi delta analizi için materialize edilmiş haftalık tablo (timeout sorunu).
- İade + iptal sonrası net ciro hesabı standart hale getirilecek.
- Fraud/şüpheli örüntü kuralı tanımı bu raporun çıktısı.

---

**Bir sonraki rapor:** 20 Nisan 2026 Pazartesi — H16 kapanışı + 23 Nisan vitrin sonuçları.
