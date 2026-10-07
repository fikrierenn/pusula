# Özellik 002: Telefon kabuğu ve ekranlar

**Durum:** Onaylandı (08.10.2026 — GMY "speci ölç ve karar ver"; denetleyici ölçümü: 70 AC biçimi tam, açık işaret 0, sınıflar 5/12/17/5 tarama ile birebir, doküman kapıları 4/4) · **Oluşturma:** 06.10.2026 · **Boy:** Büyük
**Girdi (kullanıcı isteği):** "pusula içindeki gm dahboardı orkestrayı kullanarak elden geçir tamamen mobil app olarak şekilde güncelle raporları ekranları rapor verilerini kontrol et yenilerini eklemelisin gerekli danışmanları ekleyerek onlara danış" (02.10.2026)
Kullanıcı kararı (03.10.2026): iş dört spec'e bölündü. Bu spec **telefon kabuğu ve ekranları** kapsar. 001 rakamları düzeltir, 003 yeni raporları ekler, 004 sunucu ve dışarıdan erişimi kurar.
Kaynaklar: `.orkestra/calisma/002-mobil-kabuk-ekran/spec-notlari.md` (kararlar), `ekran-oncelik.md` (uzman ekran taraması, 05.10.2026), `.orkestra/calisma/gm-mobil-plan-taslak.md`.

## Amaç / Neden

Panel masaüstü için yazıldı. 02.10.2026 denetiminde 40 ekranın yaklaşık yarısı 375 px genişlikte yana taştı. Dokunma hedefleri yaklaşık 24 px. Bazı bilgiler yalnız fareyle açılan ipucunda duruyor. 05.10.2026 denemesinde telefondan giriş çalıştı ama ekranlar telefona uymadı.

GMY sabah ilk bakışı telefondan yapmak istiyor: dün ne oldu, ne ters gidiyor. Bu spec paneli telefona kurulan bir uygulamaya çevirir. Derin analiz masaüstünde kalır. Rakamı 001'de düzeltilen ekranlar telefona ancak o düzeltme bitince çıkar; yanlış rakam cebe taşınmaz.

## Ekran sınıfları

Uzman taraması (05.10.2026) her ekranı bir sınıfa koydu. Bu spec o sınıflandırmayı kullanır.

| Sınıf | Telefonda davranış | Ekranlar |
|---|---|---|
| **A** — telefonda tam | Bütün içerik telefon düzeninde | Ana sayfa ve Sabah (birleşip **Bugün** olur), Cari/Risk, Görevler, Asistan |
| **B** — özet | Üstte özet; masaüstüne özgü bölümler yerine "Ayrıntı masaüstünde." notu | Mağazalar, Mağaza, E-ticaret, Sınav Okulları, Toplam, Tahmin, Envanter, Operasyon, Vardiya, Muhasebe, Mizan, Gelir tablosu |
| **C** — yalnız masaüstü | Alt menüde yok; **Diğer** altında "Masaüstünde daha iyi" grubunda | Müşteri, Trafik, Hediye çeki, Patron soruları, ODAK stok, Stok hareket, Baskısı yok, Satınalma analiz, Satış analizi, Satış analizi ürün detayı, Sezon aksiyon, Eşikler, Kadro, Yevmiye, Gider merkezi mizanı, Fatura, Ayarlar |
| **X** — birleşir | Eski adres yeni ekrana gider | Ana sayfa v2 → Ana sayfa · Sadakat → Müşteri · Bulunurluk → Satış analizi · Satınalma ürün detayı → Satış analizi ürün detayı · Asistan belleği → Asistan |

## 001 bağımlılığı

Bir ekran telefona, aşağıdaki 001 maddelerinin **hepsi** 001 kabul testinden geçince açılır. Tablo `ekran-oncelik.md` §2 ve §5'ten alındı.

| Ekran (telefon) | 001 maddeleri |
|---|---|
| Bugün (Ana sayfa + Sabah) | H5, H13, D-2, D-5, H10 (AC-10.1, AC-10.3) |
| Toplam | H10 (AC-10.3) |
| Mağaza | H6, H10 (AC-10.3) |
| Mağazalar | D-5 |
| E-ticaret | H4, D-3 |
| Sınav Okulları | H9, H10 (AC-10.3) |
| Tahmin | D-5 |
| Envanter | H3, H7, H8, H14, H10 (AC-10.1) |
| Operasyon | H1, H10 (AC-10.1) |
| Vardiya | H10 (AC-10.1) |
| Mizan | H12 |
| Cari/Risk, Görevler, Asistan, Muhasebe, Gelir tablosu | yok — ilk telefon sürümünde açılır |

Bugün ekranındaki kartların bağımlılığı, kaynak ekranınınkidir (bkz. H4).

## Ortak kabul kriterleri (bütün hikâyeler için)

"Telefon görünümü": dikey tutulan, 375×812 px ekran. Masaüstü görünümü: en az 1280 px genişlik.

- **AC-0.1:** Verildiğinde 001 bağımlılığı tablosunda maddesi henüz kabul testinden geçmemiş bir ekran, Yapıldığında GMY telefon görünümünde alt menüyü ve sekmeleri açtığında, O zaman o ekranın bağlantısı ve özet kartı hiçbir sekmede görünmez.
- **AC-0.2:** Verildiğinde aynı ekranın bütün 001 maddeleri kabul testinden geçmiş, Yapıldığında GMY ilgili sekmeyi açtığında, O zaman ekranın bağlantısı görünür ve ekran telefon görünümünde açılır.
- **AC-0.3:** Verildiğinde telefonda açılmış bir ekran ve seçili dönem, Yapıldığında aynı gösterge aynı dönem için masaüstünde okunduğunda, O zaman iki değer birebir aynıdır.
- **AC-0.4:** Verildiğinde 001'in "Hesap düzeltildi (gg.aa)" ya da "Hedef tabanı teyit bekliyor" notunu taşıyan bir gösterge, Yapıldığında gösterge telefonda görüntülendiğinde, O zaman not telefonda da göstergenin yanında görünür.
- **AC-0.5:** Verildiğinde telefonda açılmış herhangi bir A ya da B ekranı, Yapıldığında sayfa sonuna kadar kaydırıldığında, O zaman sayfa yatay kaymaz ve sayfa genişliği 375 px'i aşmaz.
- **AC-0.6:** Verildiğinde telefonda açılmış bir A ya da B ekranı, Yapıldığında dokunulabilir her öğe (düğme, sekme, bağlantı, filtre, satır, sayfalama) ölçüldüğünde, O zaman her biri en az 44×44 px'tir.
- **AC-0.7:** Verildiğinde masaüstünde yalnız fareyle açılan ipucunda duran bir bilgi, Yapıldığında aynı ekran telefonda açıldığında, O zaman o bilgi görünür metin olarak ya da dokununca açılan açıklamada okunur.
- **AC-0.8:** Verildiğinde telefonda bir metin ya da tarih giriş alanı, Yapıldığında alana dokunulduğunda, O zaman ekran kendiliğinden yakınlaşmaz.
- **AC-0.9:** Verildiğinde masaüstü görünümünde açılmış herhangi bir ekran, Yapıldığında bu spec teslim edildikten sonra ekran açıldığında, O zaman bugün gösterilen her gösterge, tablo ve grafik yerinde durur; yalnız X sınıfı ekranlar birleştiği yere taşınmıştır.
- **AC-0.10:** Verildiğinde telefonda açık bir ekranın veri kaynağı hata döndürüyor, Yapıldığında ekran yüklendiğinde, O zaman sunucu adı, sorgu metni ya da istisna metni görünmez; ne olduğunu ve ne yapılacağını söyleyen Türkçe mesaj görünür (001 H10 ile aynı ilke).

## Kullanıcı hikâyeleri

### H1 — Panel telefona uygulama olarak kurulur ve alt menüyle gezilir (P1)
GMY olarak paneli telefonun ana ekranına uygulama gibi eklemek ve beş sekmeyle gezmek istiyorum, böylece her sabah tarayıcı açıp adres yazmam ve finans ya da asistana tek dokunuşla ulaşırım.
**Bağımsız test:** Telefonda panel ana ekrana eklenir, simgeden açılır, beş sekme sırayla dokunularak açılır.
**Kabul kriterleri:**
- **AC-1.1:** Verildiğinde güvenli bağlantıyla telefonda açılmış panel, Yapıldığında tarayıcının "Ana ekrana ekle" seçeneği kullanıldığında, O zaman telefonun ana ekranında panelin adını ve simgesini taşıyan bir simge oluşur.
- **AC-1.2:** Verildiğinde ana ekrana eklenmiş simge, Yapıldığında simgeye dokunulduğunda, O zaman panel tarayıcı adres çubuğu olmadan, dikey ve tam ekran açılır.
- **AC-1.3:** Verildiğinde yuvarlak ya da başka biçimde simge kırpan bir telefon, Yapıldığında simge ana ekranda görüntülendiğinde, O zaman simgenin içindeki işaret kırpılmadan bütün görünür.
- **AC-1.4:** Verildiğinde telefon görünümünde herhangi bir ekran, Yapıldığında ekran açıldığında, O zaman ekranın altında soldan sağa **Bugün · Satış · Finans · Asistan · Diğer** sekmeleri görünür ve etkin sekme ayırt edilir.
- **AC-1.5:** Verildiğinde telefonda uzun bir ekran, Yapıldığında sayfa aşağı kaydırıldığında, O zaman alt menü ekranın altında kalır ve içerik alt menünün arkasında kaybolmaz; son satır alt menünün üstünde okunur.
- **AC-1.6:** Verildiğinde telefonda herhangi bir ekran, Yapıldığında Finans sekmesinden Cari/Risk ya da Asistan sekmesinden Görevler açıldığında, O zaman hedef ekrana en fazla iki dokunuşla ulaşılır.
- **AC-1.7:** Verildiğinde geciken en az bir görev, Yapıldığında telefonda alt menü görüntülendiğinde, O zaman **Asistan** sekmesinde geciken görev sayısını gösteren bir rozet görünür; geciken görev yoksa rozet görünmez.
- **AC-1.8:** Verildiğinde masaüstü görünümü, Yapıldığında herhangi bir ekran açıldığında, O zaman alt menü görünmez ve masaüstü menüsü bugünkü gruplarıyla durur; X sınıfı ekranlar menüde yer almaz.
- **AC-1.9:** Verildiğinde oturum açılmamış ya da süresi dolmuş, Yapıldığında uygulama simgeden açıldığında, O zaman giriş sayfası açılır, hiçbir rakam görünmez; giriş başarılı olunca telefonun açılış ekranı açılır (bkz. FR-003).
- **AC-1.10:** Verildiğinde telefonun internet bağlantısı yok, Yapıldığında uygulama simgeden açıldığında, O zaman "Bağlantı yok. İnternet bağlantınızı kontrol edip yeniden deneyin." mesajı ve **Yeniden dene** düğmesi görünür; daha önce görülmüş hiçbir rakam gösterilmez.
- **AC-1.11:** Verildiğinde telefonda açık bir ekran, Yapıldığında sunucuyla bağlantı koptuğunda, O zaman ekranda bağlantının koptuğunu söyleyen bir uyarı görünür ve bağlantı dönene kadar durur.

### H2 — Cari/Risk, Görevler ve Asistan telefonda tam çalışır (P1)
GMY olarak vadesi geçen alacakları, görevlerimi ve asistanı telefonda masaüstündeki kadar eksiksiz kullanmak istiyorum, böylece bu günlük işler için bilgisayara dönmem.
**Bağımsız test:** Üç ekran telefon görünümünde açılır; göstergeler masaüstüyle karşılaştırılır, görev ve asistan işlemleri telefondan yapılır.
**Kabul kriterleri:**
- **AC-2.1:** Verildiğinde telefonda Cari/Risk ekranı, Yapıldığında ekran açıldığında, O zaman en üstte vadesi geçen alacak tutarı ve kredi limitini aşan cari sayısı görünür; vadesi geçen tutar 0'dan büyükse kırmızı, limit aşan cari varsa sayı sarı gösterilir.
- **AC-2.2:** Verildiğinde telefonda Cari/Risk listesi, Yapıldığında liste görüntülendiğinde, O zaman her cari tek bir kart olarak cari adı ve net bakiyeyle görünür; kartın öteki alanları karta dokununca açılır ve masaüstündeki alanların tamamını içerir.
- **AC-2.3:** Verildiğinde telefonda Görevler ekranı, Yapıldığında ekran açıldığında, O zaman açık görev sayısı ve geciken görev sayısı en üstte görünür; geciken görevler kırmızı rozetle işaretlidir.
- **AC-2.4:** Verildiğinde masaüstünde yapılabilen görev işlemleri (ekleme, tamamlama, silme), Yapıldığında aynı işlemler telefonda yapıldığında, O zaman sonuç masaüstündekiyle aynıdır ve silme bir onay sorusundan sonra gerçekleşir.
- **AC-2.5:** Verildiğinde telefonda Asistan ekranı, Yapıldığında soru yazmak için giriş alanına dokunulduğunda ve klavye açıldığında, O zaman giriş alanı ve gönder düğmesi klavyenin ve alt menünün üstünde görünür kalır.
- **AC-2.6:** Verildiğinde asistanın önerdiği bir görev ya da e-posta, Yapıldığında GMY telefonda onaylama ya da reddetme düğmesine dokunduğunda, O zaman sonuç masaüstündeki aynı işlemle aynıdır.
- **AC-2.7:** Verildiğinde asistan belleği, Yapıldığında Asistan ekranı telefonda açıldığında, O zaman bellek Asistan ekranının içinde bir sekme olarak açılır (bkz. H7).

### H3 — Finans özetleri telefonda okunur (P1)
GMY olarak muhasebe kontrolünü, son ayın faaliyet kârını ve mizan özetini telefonda kısa kartlarla görmek istiyorum, böylece ay kapanışını beklerken masaüstüne bağlı kalmam.
**Bağımsız test:** Finans sekmesinde Muhasebe, Gelir tablosu ve (001 H12 kapandıysa) Mizan özetleri açılır ve masaüstüyle karşılaştırılır.
**Kabul kriterleri:**
- **AC-3.1:** Verildiğinde telefonda Muhasebe ekranı, Yapıldığında ekran açıldığında, O zaman en üstte seçili dönemin kontrol bulgusu adedi, toplam tutarı ve tutarı en büyük üç kalem görünür; değerler masaüstündeki aynı dönemle aynıdır.
- **AC-3.2:** Verildiğinde telefonda Gelir tablosu ekranı, Yapıldığında ekran açıldığında, O zaman kapanmış son ayın faaliyet kârı görünür ve altında "Tahakkuk esaslıdır, nakit akışı değildir." notu yazar.
- **AC-3.3:** Verildiğinde 001 H12 kabul testinden geçmiş, Yapıldığında telefonda Mizan ekranı açıldığında, O zaman nakit, alınan çekler (nakitten ayrı) ve KDV pozisyonu göstergeleri görünür; hesap ağacı telefonda gösterilmez, yerinde "Ayrıntı masaüstünde." notu yazar.
- **AC-3.4:** Verildiğinde 001 H12 kabul testinden geçmemiş, Yapıldığında telefonda Finans sekmesi açıldığında, O zaman Mizan bağlantısı görünmez (AC-0.1).
- **AC-3.5:** Verildiğinde telefonda bir finans ekranında yıl/ay seçimi, Yapıldığında seçim değiştirildiğinde, O zaman seçim yatay taşmadan ekrana sığar ve gösterge yeni döneme göre yenilenir.

### H4 — Bugün ekranı sabahın ilk bakışını tek ekranda verir (P2)
GMY olarak telefonu açınca dünü, ters giden şeyleri ve ayın durumunu tek ekranda görmek istiyorum, böylece sabah ayrı ayrı ekran açmam.
Kullanıcı kararı (05.10.2026): Sabah ekranı Ana sayfaya birleşir. Üstte dün ve uyarılar, altta dönem görünümü. Günlük ciro, okul dönemine göre eşleşen geçen yıl günüyle kıyaslanır.
**Bağımsız test:** 001 maddeleri kapandıktan sonra Bugün ekranı açılır; her kart kaynak ekranındaki değerle ve eşik kurallarıyla karşılaştırılır.
**Kart bağımlılığı:**

| # | Kart | Kaynak ekran | Telefonda görünme koşulu |
|---|---|---|---|
| 1 | Dünkü ciro | Ana sayfa | H5, H13, D-2, H10 (AC-10.3) |
| 1a | Sınav iade oranı | Sınav Okulları | H9 + Temmuz–Ekim |
| 2 | Ay hedefi ve ay sonu tahmini | Ana sayfa + Tahmin | H13, D-5 |
| 3 | Bugünün uyarıları | Sabah | H10 (AC-10.1) |
| 4 | E-ticaret bekleyen sipariş | E-ticaret | H4, D-3 |
| 5 | Vadesi geçen alacak | Cari/Risk | yok |
| 6 | Nakit ve en düşük hafta | — | spec 003 tamamlanınca |
| 7 | Açık görevler | Görevler | yok |
| 8 | Personel çalışma süresi uyumu | Vardiya | H10 (AC-10.1) |

**Kabul kriterleri:**
- **AC-4.1:** Verildiğinde Bugün ekranı, Yapıldığında ekran telefonda açıldığında, O zaman üst bölümde görünme koşulu sağlanan kartlar 1, 1a, 3, 4, 5, 7, 8 sırasıyla; alt bölümde kart 2 ve ana sayfanın dönem görünümü yer alır.
- **AC-4.2:** Verildiğinde bir kartın görünme koşulu sağlanmamış, Yapıldığında Bugün ekranı açıldığında, O zaman o kart görünmez ve yerinde boş kutu kalmaz.
- **AC-4.3:** Verildiğinde dünkü satışlar, Yapıldığında kart 1 görüntülendiğinde, O zaman perakende, Sınav Okulları ve toplam ayrı satırlarda, e-ticaret ayrı bir satırda görünür; perakende + Sınav Okulları = toplam eşitliği 1,00 TL toleransla sağlanır.
- **AC-4.4:** Verildiğinde dün ve okul dönemine göre eşleşen geçen yıl günü, Yapıldığında kart 1 görüntülendiğinde, O zaman kıyas günü "gg.aa.yyyy, gün adı" biçiminde ve değişim yüzdesi görünür; perakende, Sınav Okulları, toplam ve e-ticaret satırlarının her biri kendi geçen yıl değerine göre ayrı değişim yüzdesi ve ayrı renk taşır: değişim −%5 ile −%10 arasında (−%5 dahil) ise sarı, −%10 ya da daha düşükse kırmızı. Bir satırın rengi öteki satırların değişiminden etkilenmez. (Karar 07.10.2026.)
- **AC-4.5:** Verildiğinde tarih Temmuz–Ekim arasında ve 001 H9 kapanmış, Yapıldığında Bugün ekranı açıldığında, O zaman kart 1'in altında Sınav Okulları iade oranı görünür; oran %3 ya da üstündeyse kırmızıdır. Kasım–Haziran arasında bu satır görünmez.
- **AC-4.6:** Verildiğinde içinde bulunulan ay, Yapıldığında kart 2 görüntülendiğinde, O zaman gerçekleşen, hedef, gerçekleşme yüzdesi, ay sonu tahmini ve tahmin aralığı görünür; gerçekleşme %95 ve üstü yeşil, %85 ile %95 arası sarı, %85 altı kırmızıdır.
- **AC-4.7:** Verildiğinde hedef tabanı GMY tarafından henüz teyit edilmemiş, Yapıldığında kart 2 görüntülendiğinde, O zaman kartta "Hedef tabanı teyit bekliyor" notu görünür (001 AC-13.4).
- **AC-4.8:** Verildiğinde Sabah ekranının bugün koştuğu kontroller ve hiçbiri uyarı üretmemiş, Yapıldığında kart 3 görüntülendiğinde, O zaman kart "N kontrol koştu, 0 uyarı" der; N koşan kontrol sayısıdır.
- **AC-4.9:** Verildiğinde kontrollerden en az biri koşamamış, Yapıldığında kart 3 görüntülendiğinde, O zaman koşamayan kontrol sayısı ve adı ayrı satırda yazılır; koşamayan kontrol "0 uyarı" sayısına katılmaz ve kart yeşil gösterilmez.
- **AC-4.10:** Verildiğinde kargoya çıkmamış e-ticaret siparişleri, Yapıldığında kart 4 görüntülendiğinde, O zaman bekleyen sipariş sayısı ve 4 gün ve üstü bekleyen sayısı görünür; 2–3 gün bekleyen varsa sarı, 4 gün ve üstü bekleyen varsa kırmızıdır.
- **AC-4.11:** Verildiğinde vadesi geçen alacaklar, Yapıldığında kart 5 görüntülendiğinde, O zaman tutar ve limit aşan cari sayısı Cari/Risk ekranındaki değerle (AC-2.1) aynıdır ve aynı renk kuralını izler.
- **AC-4.12:** Verildiğinde açık ve geciken görevler, Yapıldığında kart 7 görüntülendiğinde, O zaman açık ve geciken görev sayısı görünür; geciken sayısı 0'dan büyükse kırmızıdır.
- **AC-4.13:** Verildiğinde dinlenme ve gece çalışma süresi sınırlarını aşan vardiya kayıtları, Yapıldığında kart 8 görüntülendiğinde, O zaman aşım sayısı mağaza bazında görünür, hiçbir çalışanın adı ya da sicili yazmaz; aşım sayısı 0'dan büyükse sarıdır.
- **AC-4.14:** Verildiğinde spec 003 nakit raporu teslim edilmemiş, Yapıldığında Bugün ekranı açıldığında, O zaman kart 6 görünmez.
- **AC-4.15:** Verildiğinde Bugün ekranındaki bir kart, Yapıldığında karta dokunulduğunda, O zaman kartın kaynak ekranı açılır.
- **AC-4.16:** Verildiğinde Sabah ekranının eski adresi, Yapıldığında bu adres telefonda ya da masaüstünde açıldığında, O zaman Bugün ekranı açılır.
- **AC-4.17:** Verildiğinde 001 maddelerinin hiçbiri kabul testinden geçmemiş (ilk telefon sürümü), Yapıldığında GMY telefonda giriş yaptığında, O zaman Bugün ekranı açılır ve yalnız kart 5 ile kart 7 görünür; alt bölümde hedef kartı ve dönem görünümü yer almaz.

### H5 — Satış ekranları telefonda özet verir (P2)
GMY olarak mağaza, e-ticaret, Sınav Okulları, kategori ve tahmin ekranlarının özetini telefonda görmek istiyorum, böylece haftalık satış durumunu yolda da izlerim.
**Bağımsız test:** 001 maddesi kapanmış her satış ekranı Satış sekmesinden açılır; özet göstergeleri masaüstüyle karşılaştırılır, masaüstüne özgü bölümlerin yerinde not aranır.
**Kabul kriterleri:**
- **AC-5.1:** Verildiğinde Satış sekmesi, Yapıldığında sekme telefonda açıldığında, O zaman Mağazalar, Mağaza, E-ticaret, Sınav Okulları, Toplam ve Tahmin bağlantılarından yalnız 001 koşulu sağlananlar görünür.
- **AC-5.2:** Verildiğinde Mağazalar ekranı telefonda, Yapıldığında ekran açıldığında, O zaman her mağaza bir kart olarak görünür ve okul açılışı uyarısı masaüstündeki gibi okunur.
- **AC-5.3:** Verildiğinde Mağaza ekranı telefonda, Yapıldığında ekran açıldığında, O zaman göstergeler en çok iki sütunda dizilir; saat × gün ısı haritası yerine dönemin en yoğun 5 saati liste olarak görünür.
- **AC-5.4:** Verildiğinde E-ticaret ekranı telefonda, Yapıldığında ekran açıldığında, O zaman bekleyen sipariş kartı en üstte, net ciro altında görünür; değerler masaüstüyle aynıdır.
- **AC-5.5:** Verildiğinde Sınav Okulları ekranı telefonda, Yapıldığında ekran açıldığında, O zaman ana göstergeler görünür ve iade oranı %3 ya da üstündeyse kırmızıdır.
- **AC-5.6:** Verildiğinde Toplam ekranı telefonda, Yapıldığında ekran açıldığında, O zaman cirosu en yüksek 5 kategori ve payları görünür; tüm kategori listesinin yerinde "Ayrıntı masaüstünde." notu yazar.
- **AC-5.7:** Verildiğinde Tahmin ekranı telefonda, Yapıldığında ekran açıldığında, O zaman tahmin ve tahmin aralığı görünür; modellerin karşılaştırması yerinde "Ayrıntı masaüstünde." notu yazar.
- **AC-5.8:** Verildiğinde B sınıfı bir ekranın telefonda gösterilmeyen bölümü, Yapıldığında aynı ekran masaüstünde açıldığında, O zaman o bölüm masaüstünde eksiksiz görünür (AC-0.9).

### H6 — Diğer sekmesi operasyon özetlerini ve masaüstü ekranlarını toplar (P3)
GMY olarak operasyon, envanter ve vardiya özetine telefonda ulaşmak; derin ekranların telefonda dar kalacağını önceden bilmek istiyorum, böylece yanlış ekranda vakit kaybetmem.
**Bağımsız test:** Diğer sekmesi açılır; özet ekranları 001 koşuluna göre görünür, C sınıfı ekranlar ayrı grupta listelenir.
**Kabul kriterleri:**
- **AC-6.1:** Verildiğinde Diğer sekmesi, Yapıldığında sekme telefonda açıldığında, O zaman üstte Operasyon, Envanter ve Vardiya bağlantılarından 001 koşulu sağlananlar, altta "Masaüstünde daha iyi" başlıklı grupta C sınıfı ekranlar listelenir.
- **AC-6.2:** Verildiğinde "Masaüstünde daha iyi" grubundaki bir ekran, Yapıldığında telefonda bağlantısına dokunulduğunda, O zaman ekran açılır, sayfa sonuna kadar kaydırıldığında sayfa yatay kaymaz ve sayfa genişliği 375 px'i aşmaz; geniş tablolar yalnız kendi kutusu içinde yatay kayabilir. 44 px dokunma kuralı (AC-0.6) C ekranlarına uygulanmaz. (Karar 07.10.2026; 02.10 denetiminde 17 C ekranın 15'i yana taşıyordu.)
- **AC-6.3:** Verildiğinde Operasyon ekranı telefonda, Yapıldığında ekran açıldığında, O zaman yalnız uyarı (istisna) kartı görünür; Kumbara ve manuel indirim göstergesi görünmez (001 AC-1.4); personel saati başına satış göstergesi de telefon özetinde görünmez. Masaüstündeki gösterge bu spec'te değişmez.
- **AC-6.3a:** Verildiğinde personel saati başına satış hesabı düzeltilmiş ve ayrı bir kayıtta (001 ek maddesi ya da 003) kabul testinden geçmiş, Yapıldığında Operasyon ekranı telefonda açıldığında, O zaman gösterge telefon özetinde görünür (AC-0.2 ile aynı kapı). Gizleme gerekçesi (ölçüm 06.09–06.10.2026): göstergenin payına fatura ve Sınav Okulları satışı giriyor, paydası yalnız mağaza personelinin saati; İst.Yolu'nda pay olarak alınan satışın %87,9'u fatura ve Sınav Okulları (FSM %1,8, Özlüce %2,7). (Karar 07.10.2026.)
- **AC-6.4:** Verildiğinde Envanter ekranı telefonda, Yapıldığında ekran açıldığında, O zaman üç stok göstergesi ve 001 H14'teki tanım açıklamaları görünür; listeler yerinde "Ayrıntı masaüstünde." notu yazar.
- **AC-6.5:** Verildiğinde Vardiya ekranı telefonda, Yapıldığında ekran açıldığında, O zaman yalnız mağaza bazında, isimsiz özet görünür; çalışan adı ya da sicili içeren satır telefonda gösterilmez.
- **AC-6.6:** Verildiğinde Ayarlar ve Eşikler ekranları (veri değiştiren ekranlar), Yapıldığında telefonda açıldığında, O zaman kayıtlı değerler okunur, hiçbir alan düzenlenemez, kaydetme ya da silme düğmesi görünmez ve "Değişiklik masaüstünden yapılır." notu yazar. (Karar 07.10.2026.)
- **AC-6.7:** Verildiğinde aynı iki ekran masaüstü görünümünde, Yapıldığında açıldığında, O zaman bugünkü değiştirme işlemleri (ay kapanış tarihi girişi, eşik kaydı) masaüstündeki gibi yapılabilir.

### H7 — Birleşen ekranların eski adresleri yeni yere gider (P3)
GMY olarak eski yer imlerim ve bağlantılarım bozulmadan birleşen ekranlara ulaşmak istiyorum, böylece telefon menüsü sade kalırken hiçbir bilgiyi kaybetmem.
**Bağımsız test:** Beş eski adres sırayla açılır; her biri hedef ekrana gider ve eski ekrandaki bilgi hedefte bulunur.
**Kabul kriterleri:**
- **AC-7.1:** Verildiğinde Ana sayfa v2, Sadakat, Bulunurluk, Satınalma ürün detayı ve Asistan belleği ekranlarının eski adresleri, Yapıldığında her biri açıldığında, O zaman sırasıyla Ana sayfa (Bugün), Müşteri, Satış analizi, Satış analizi ürün detayı ve Asistan ekranı açılır.
- **AC-7.2:** Verildiğinde ürün kimliği taşıyan eski Satınalma ürün detayı adresi, Yapıldığında adres açıldığında, O zaman aynı ürünün Satış analizi ürün detayı açılır.
- **AC-7.3:** Verildiğinde Sadakat, Bulunurluk, Satınalma ürün detayı ve Asistan belleği ekranlarında bugün gösterilen her gösterge, Yapıldığında hedef ekran masaüstünde açıldığında, O zaman her gösterge hedef ekranın bir bölümünde ya da sekmesinde aynı değerle bulunur.
- **AC-7.4:** Verildiğinde birleşme tamamlanmış, Yapıldığında masaüstü menüsü ve telefon sekmeleri açıldığında, O zaman beş eski ekranın hiçbiri ayrı menü öğesi olarak görünmez.

## Sınır durumlar
- 001 maddesi kabul testinden sonra geri alınırsa: ilgili ekran ve kartlar telefondan yeniden kalkar (AC-0.1 her açılışta geçerli).
- Okul dönemine göre eşleşen geçen yıl günü yoksa ya da o gün satış yoksa: kart 1 değişim yüzdesi yerine "Kıyas günü yok" yazar ve renk göstermez.
- Dün mağaza kapalıysa (bayram, tatil): kart 1 o mağaza için "Kapalı" yazar, 0'ı düşüş saymaz.
- Bugünün ciro rakamı: kasadan ERP'ye aktarım saatte birdir. Bugün ekranı "dün" için kapalı günü kullanır; bugüne ait gösterge varsa yanında "gün içi, saatte bir güncellenir" notu yazar.
- Bir kart kaynağı hata verirse: yalnız o kart hata mesajını gösterir (AC-0.10); öteki kartlar yüklenir.
- Kontrol listesi hiç koşamazsa: kart 3 "Kontroller koşamadı" der, "0 uyarı" demez.
- Telefon yatay çevrilirse: ekran okunur kalır; kabul testi yalnız dikey yapılır.
- Görev sayısı ya da bekleyen sipariş 0 ise: kart "0" gösterir ve renksizdir; kart gizlenmez.

## Fonksiyonel gereksinimler
- **FR-001:** Sistem telefona ana ekran simgesiyle kurulabilmek ve simgeden adres çubuksuz, tam ekran açılmak ZORUNDADIR (H1).
- **FR-002:** Sistem telefon görünümünde beş sekmeli alt menü (Bugün · Satış · Finans · Asistan · Diğer) sunmak, masaüstünde bugünkü menüyü korumak ZORUNDADIR (H1).
- **FR-003:** Sistem telefonda girişten sonra açılış ekranı olarak Bugün ekranını açmak ZORUNDADIR. İlk telefon sürümünde de Bugün açılır ve yalnız 001'den bağımsız kartları (5 vadesi geçen alacak, 7 açık görevler) gösterir; öteki kartlar bağlı 001 maddeleri kapandıkça eklenir (karar 07.10.2026; bkz. AC-4.17).
- **FR-003a:** Sistem C sınıfı ekranlarda telefonda yatay sayfa taşması üretmemek ZORUNDADIR; geniş tablo kendi kutusu içinde kayabilir (AC-6.2).
- **FR-003b:** Sistem Ayarlar ve Eşikler ekranlarını telefonda yalnız okunur açmak ZORUNDADIR (AC-6.6).
- **FR-004:** Sistem 001 bağımlılığı olan bir ekranı ya da kartı, bağlı 001 maddelerinin hepsi kabul testinden geçene kadar telefon menüsünde ve Bugün ekranında göstermemek ZORUNDADIR (AC-0.1, AC-4.2).
- **FR-005:** Sistem telefonda ve masaüstünde aynı göstergeyi aynı hesapla ve aynı değerle göstermek ZORUNDADIR; telefon için ayrı hesap yapılmaz (AC-0.3).
- **FR-006:** Sistem A ve B ekranlarında telefon görünümünde yatay sayfa taşması üretmemek, dokunulabilir öğeleri en az 44×44 px yapmak ve yalnız fareyle görülen bilgi bırakmamak ZORUNDADIR (AC-0.5–0.7).
- **FR-007:** Sistem B ekranlarında telefonda gösterilmeyen bölümün yerine "Ayrıntı masaüstünde." notunu koymak ZORUNDADIR (H5, H6).
- **FR-008:** Sistem Bugün ekranında kartların renklerini bu spec'teki eşiklere göre vermek ve koşamayan kontrolü "uyarı yok" saymamak ZORUNDADIR (H4).
- **FR-009:** Sistem telefonda çalışan adı ya da sicili içeren vardiya satırı göstermemek ZORUNDADIR (AC-4.13, AC-6.5).
- **FR-010:** Sistem birleşen beş ekranın ve Sabah ekranının eski adreslerini yeni ekrana yönlendirmek, eski ekranlardaki her göstergeyi hedef ekranda korumak ZORUNDADIR (H7, AC-4.16).
- **FR-011:** Sistem bağlantı yokken önceden görülmüş rakam göstermemek ZORUNDADIR; telefonda veri saklanmaz (AC-1.10).
- **FR-012:** Sistem bu spec kapsamında hiçbir rakamın hesabını değiştirmemek ZORUNDADIR; rakam düzeltmesi 001'in, yeni gösterge 003'ün işidir.
- **FR-013:** Sistem hiçbir ERP, POS ya da e-ticaret verisini değiştirmemek ZORUNDADIR.

## Yetki
| Rol | Yapabilir | Yapamaz |
|---|---|---|
| GMY (tek kullanıcı, oturum açmış; telefon ya da masaüstü) | Telefona kurmak; bütün açık ekranları görmek; görev eklemek, tamamlamak, silmek; asistan önerisini onaylamak ya da reddetmek; masaüstünde bugünkü bütün işlemleri yapmak | 001 koşulu sağlanmamış ekranı telefon menüsünden açmak; telefonda çalışan adlı vardiya satırı görmek; telefondan Ayarlar ya da Eşikler değerini değiştirmek; ERP, POS, e-ticaret verisini değiştirmek |
| Oturum açmamış kişi (telefonda kurulu simgeyi açan dahil) | Giriş sayfasını görmek | Hiçbir ekranı, kartı ya da daha önce görülmüş rakamı görmek |
| Panel uygulaması | ERP, POS, e-ticaret, İK verisini okumak; panelin kendi görev ve asistan kayıtlarını bugünkü gibi yazmak | Telefonda rakam saklamak; telefona bildirim göndermek; ERP'de herhangi bir tabloya yazmak |

Yetki modeli değişmiyor (tek kullanıcı).

## Anahtar varlıklar
- **Ekran sınıfı:** A, B, C ya da X; telefondaki davranışı belirler.
- **001 bağımlılığı:** bir ekranın telefona açılması için kabul testinden geçmesi gereken 001 maddeleri.
- **Bugün kartı:** tek göstergeyi, rengini ve kaynak ekranını taşır; görünürlüğü kaynak ekranın 001 bağımlılığına bağlıdır.
- **Kıyas günü:** dün için okul dönemine göre eşleşen geçen yıl günü.
- **Kontrol sonucu (uyarı):** Sabah kontrollerinin her biri için "uyarı var / uyarı yok / koşamadı".
- **Birleşme eşlemesi:** eski ekran → yeni ekran ve yeni ekrandaki yeri.

## Veri kaynağı ve ortam
- Yeni veri kaynağı yok. Ekranlar bugünkü kaynaklarını okur: ERP DerinSISBkm (compat 150), POS EncoreMerkez (compat 110), Sınav BKM (compat 150), hedef BKMDATA (compat 150), müşteri DerinCrm (compat 150), e-ticaret JOKER (compat 150), İK/bordro Zirve (compat bilinmiyor; bu spec yeni sorgu yazmaz). Ölçüm: `docs/proje/veritabani.md`, 03.10.2026 (001 spec ile aynı).
- Panelin kendi kayıtları (görev, asistan belleği) bugünkü panel veritabanında kalır.
- Kurulum ve telefon testi güvenli bağlantı ister. Kalıcı dışarıdan erişim 004'ün işidir.

## Başarı kriterleri
- **SC-001:** 375×812 telefon görünümünde telefona açılmış A ve B ekranlarının hiçbirinde yatay sayfa kaydırması yoktur (ekran başına ölçüm, %100).
- **SC-001a:** 375×812 telefon görünümünde 17 C sınıfı ekranın hiçbirinde yatay sayfa kaydırması yoktur (02.10.2026'da 15'inde vardı).
- **SC-002:** A ve B ekranlarında 44×44 px'ten küçük dokunulabilir öğe sayısı 0'dır.
- **SC-003:** Panel en az bir Android ve bir iOS telefonda ana ekrana kurulur ve simgeden tam ekran açılır.
- **SC-004:** Telefonda açılış ekranından Cari/Risk, Görevler ve Asistan'a en fazla iki dokunuşla ulaşılır (bugün üç).
- **SC-005:** Telefonda gösterilen her gösterge, masaüstündeki aynı göstergeyle aynı dönem için birebir aynıdır (örnekleme: her açık ekrandan en az bir gösterge).
- **SC-006:** 001 maddesi kapanmamış ekranların telefon menüsünde görünme sayısı 0'dır.
- **SC-007:** Birleşen beş ekranın eski adreslerinin beşi de hedef ekrana gider.
- **SC-008 (ÇIKARIM ölçüt):** GMY sabah ilk bakışını telefondan yapar. Nasıl ölçüleceği plan aşamasında belirlenir.

## Kapsam dışı
- Yeni rapor ve yeni veri: nakit takvimi (kart 6), vergi ve SGK karşılığı, borç servisi, kanal katkı payı, İK ve BT kartları, Bugün kart 3'e eklenecek yeni uyarı türleri (kapanmayan kasa, kasa↔ERP farkı, manuel indirim sapması) → spec 003.
- Sunucu, servis kurulumu, kalıcı güvenli bağlantı, dışarıdan erişim, erişim koruması, parola sıfırlama → spec 004.
- Rakam düzeltmeleri → spec 001.
- Telefona bildirim gönderme (uyarılar uygulama açılınca görünür; kullanıcı kararı 05.10.2026).
- Çevrimdışı çalışma ve telefonda veri saklama.
- C sınıfı ekranların telefon için yeniden tasarımı ve 44 px dokunma kuralı; C ekranlarında yalnız yana taşmama asgarisi bu spec'tedir (AC-6.2).
- Operasyon'daki personel saati başına satış hesabının düzeltilmesi: göstergenin payına fatura ve Sınav Okulları satışı girdiği için telefonda gizlenir (AC-6.3); düzeltme ayrı kayıtta (001 ek maddesi ya da 003) yapılır.
- Ayarlar ve Eşikler ekranlarında telefondan değişiklik yapma (telefonda yalnız okunur, AC-6.6).
- Ayrı telefon uygulaması ve ayrı telefon ekran seti (02–03.10.2026'da reddedildi).
- Çok kullanıcı ve yetki modeli değişikliği.
- Birleşen ekranların dosyalarının kalıcı silinmesi (ayrı onay ister).

## Varsayımlar
- X sınıfı birleştirmeler bu spec'te yapılır, çünkü telefon menüsü onlarsız kurulur (notlardaki VARSAYIM).
- "001 maddesi kapandı" = o maddenin bütün kabul kriterleri 001 kabul testinden "tuttu" sonucuyla geçti. "Koşamadı" kapanmış sayılmaz.
- 001 koşulu sağlanmamış bir ekran telefonda doğrudan adresle açılırsa bugünkü (uyarlanmamış) düzeniyle açılır; menüde ve Bugün ekranında görünmez.
- Telefon kabul testi dikey 375×812 görünümde yapılır; ayrıca kullanıcı kendi telefonunda dener.
- Kurulum testi geçici bir güvenli bağlantı üzerinden yapılır (05.10.2026 denemesindeki gibi); kalıcı erişim 004'tedir.
- Kart 1 eşik sınırları: −%5 sarıya, −%10 kırmızıya dahildir; −%5'ten iyi değişim renksizdir.
- Okul dönemine göre eşleşen geçen yıl günü, panelin bugün kullandığı okul dönemi eşleşmesiyle aynı kuralla bulunur.
- Kart 1 ve kart 2'deki ciro tabanı Ana sayfadakiyle aynıdır (001 H13, D-5 dipnotuyla).
- Kart 3, Sabah ekranının bugün koştuğu kontrolleri taşır; yeni kontrol türleri 003 ile eklenir.
- Kart 8 uyum sınırları Vardiya ekranının bugün kullandığı sınırlardır (11 saat, 12 saat dinlenme, gece 7,5 saat).
- Envanter telefon özetindeki üç gösterge ölü stok, aşırı stok ve stokta yokluktur (uzman: "telefona 3 sayı"); plan aşamasında teyit edilir.
- Muhasebe kartındaki "kontrol bulgusu", Muhasebe ekranının bugün listelediği ay kapanışı kontrol kalemleridir.
- Görev ve asistan işlemleri telefonda masaüstüyle aynı kalır; yeni işlem eklenmez.
- "Masaüstünde daha iyi" grubunda 17 C sınıfı ekranın hepsi listelenir; plan taslağındaki "mobil menüden çıkar" listesi bu kararla değişti.
- Kullanıcı tek kişidir (GMY); telefon ve masaüstü aynı oturum kurallarını kullanır.

## Kontrol listesi
- [x] `[NEEDS CLARIFICATION]` kalmadı — 5 soru 07.10.2026'da kararlandı (AC-4.4, AC-6.2, AC-6.3, AC-6.6, FR-003)
- [x] Her AC Verildiğinde/Yapıldığında/O zaman biçiminde ve test edilebilir
- [x] NASIL detayı yok (tablo/sınıf/endpoint adı, teknoloji)
- [x] Yetki negatifleri yazılı
- [x] Kapsam dışı yazılı
