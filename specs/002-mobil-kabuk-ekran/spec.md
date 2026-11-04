# Özellik 002: Telefon kabuğu ve ekranlar

**Durum:** Onaylandı (08.10.2026) · Değişiklik 1: 08.10.2026 — Cari/Risk 001 ek maddesine bağlandı, kart 3/kıyas günü netleşti (GMY kararı) · Değişiklik 2: 08.10.2026 — maskeleme, oturum yönetimi, ilk sürüm kapsamı · Değişiklik 3: 09.10.2026 — Müşteri/Trafik/Sadakat 001 kapısına bağlandı · **Oluşturma:** 06.10.2026 · **Boy:** Büyük
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
| **C** — yalnız masaüstü | Alt menüde yok; **Diğer** altında "Masaüstünde daha iyi" grubunda. Müşteri ve Trafik (ve Müşteri'ye birleşen Sadakat) telefonda yalnız 001 maddeleri kapanınca ve kişisel alanları maskeli açılır (H8) | Müşteri, Trafik, Hediye çeki, Patron soruları, ODAK stok, Stok hareket, Baskısı yok, Satınalma analiz, Satış analizi, Satış analizi ürün detayı, Sezon aksiyon, Eşikler, Kadro, Yevmiye, Gider merkezi mizanı, Fatura, Ayarlar |
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
| Cari/Risk | 001 ek maddesi: Cari/Risk tam toplam ve alıcı/satıcı ayrımı |
| Müşteri (C, maskeli) | D-1 |
| Trafik (C, maskeli) | H5 |
| Sadakat (X → Müşteri, maskeli) | H2, H5 |
| Görevler, Asistan, Muhasebe, Gelir tablosu | yok — ilk telefon sürümünde açılır |

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
- **AC-0.11:** Verildiğinde masaüstünde dışa aktarma (Excel'e dökme) düğmesi taşıyan herhangi bir ekran, Yapıldığında ekran telefon görünümünde açıldığında, O zaman hiçbir dışa aktarma düğmesi görünmez ve telefona dosya inmez; aynı ekran masaüstünde açılınca düğmeler bugünkü gibi çalışır. (KVKK kararı 08.10.2026.)

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
- **AC-1.6:** Verildiğinde telefonda herhangi bir ekran, Yapıldığında Finans sekmesinden Cari/Risk (001 Cari/Risk ek maddesi kapandıktan sonra) ya da Asistan sekmesinden Görevler açıldığında, O zaman hedef ekrana en fazla iki dokunuşla ulaşılır.
- **AC-1.7:** Verildiğinde geciken en az bir görev, Yapıldığında telefonda alt menü görüntülendiğinde, O zaman **Asistan** sekmesinde geciken görev sayısını gösteren bir rozet görünür; geciken görev yoksa rozet görünmez.
- **AC-1.8:** Verildiğinde masaüstü görünümü, Yapıldığında herhangi bir ekran açıldığında, O zaman alt menü görünmez ve masaüstü menüsü bugünkü gruplarıyla durur; X sınıfı ekranlar menüde yer almaz.
- **AC-1.9:** Verildiğinde oturum açılmamış ya da süresi dolmuş, Yapıldığında uygulama simgeden açıldığında, O zaman giriş sayfası açılır, hiçbir rakam görünmez; giriş başarılı olunca telefonun açılış ekranı açılır (bkz. FR-003).
- **AC-1.10:** Verildiğinde telefonun internet bağlantısı yok, Yapıldığında uygulama simgeden açıldığında, O zaman "Bağlantı yok. İnternet bağlantınızı kontrol edip yeniden deneyin." mesajı ve **Yeniden dene** düğmesi görünür; daha önce görülmüş hiçbir rakam gösterilmez.
- **AC-1.11:** Verildiğinde telefonda açık bir ekran, Yapıldığında sunucuyla bağlantı koptuğunda, O zaman ekranda bağlantının koptuğunu söyleyen bir uyarı görünür ve bağlantı dönene kadar durur.
- **AC-1.12:** Verildiğinde GMY telefonda ve masaüstünde oturum açmış, Yapıldığında masaüstünde Ayarlar'daki **Bütün oturumları kapat** düğmesine basıp onayladığında, O zaman telefondaki açık uygulama en geç 1 dakika içinde giriş sayfasına döner ve hiçbir rakam görünmez; masaüstündeki oturum da kapanır ve giriş sayfası açılır.
- **AC-1.13:** Verildiğinde oturumdaki son etkileşimin üzerinden 12 saat geçmiş, Yapıldığında uygulama açıldığında ya da açık ekranda bir öğeye dokunulduğunda, O zaman giriş sayfası açılır ve hiçbir rakam görünmez.
- **AC-1.14:** Verildiğinde oturum açılışının üzerinden 7 gün geçmiş, Yapıldığında uygulama kullanılırken ya da açıldığında, O zaman etkileşim sürmüş olsa da giriş sayfası açılır.
- **AC-1.15:** Verildiğinde masaüstünde Ayarlar ekranı, Yapıldığında **Oturumlar** bölümü açıldığında, O zaman açık her oturum cihaz özeti ve son görülme zamanıyla (gg.aa.yyyy ss:dd) listelenir; IP adresi gösterilmez. Telefonda bölüm salt okunurdur, kapatma düğmesi görünmez.
- **AC-1.16:** Verildiğinde açık bir oturum, Yapıldığında **Çıkış yap** seçildiğinde, O zaman yalnız o cihazın oturumu kapanır; öteki cihazlardaki oturumlar açık kalır.

### H2 — Cari/Risk, Görevler ve Asistan telefonda tam çalışır (P1)
GMY olarak vadesi geçen alacakları, görevlerimi ve asistanı telefonda masaüstündeki kadar eksiksiz kullanmak istiyorum, böylece bu günlük işler için bilgisayara dönmem.
**Bağımsız test:** Üç ekran telefon görünümünde açılır; göstergeler masaüstüyle karşılaştırılır, görev ve asistan işlemleri telefondan yapılır.
**Kabul kriterleri:**
- **AC-2.1:** Verildiğinde 001'in Cari/Risk ek maddesi kabul testinden geçmiş ve telefonda Cari/Risk ekranı, Yapıldığında ekran açıldığında, O zaman en üstte alıcıların vadesi geçen alacak toplamı (bütün cariler, ilk N kayıt değil) ve kredi limitini aşan cari sayısı görünür; vadesi geçen tutar 0'dan büyükse kırmızı, limit aşan cari varsa sayı sarı gösterilir.
- **AC-2.1a:** Verildiğinde 001'in Cari/Risk ek maddesi kabul testinden geçmemiş, Yapıldığında telefonda Finans sekmesi açıldığında, O zaman Cari/Risk bağlantısı görünmez (AC-0.1).
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
| 3 | Bugünün uyarıları | Ana sayfa uyarı kuralları (Sabah bölümünde) | H10 (AC-10.1) + kart 1 koşulları |
| 4 | E-ticaret bekleyen sipariş | E-ticaret | H4, D-3 |
| 5 | Vadesi geçen alacak | Cari/Risk | 001 ek maddesi (Cari/Risk) |
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
- **AC-4.8:** Verildiğinde kart 3'ün dün için koştuğu kontroller (mağaza cirosu −%10 ya da daha kötü; iade oranı %2'nin üstü) ve hiçbiri uyarı üretmemiş, Yapıldığında kart 3 görüntülendiğinde, O zaman kart "N kontrol koştu, 0 uyarı" der; N koşan kontrol sayısıdır.
- **AC-4.9:** Verildiğinde kontrollerden en az biri koşamamış, Yapıldığında kart 3 görüntülendiğinde, O zaman koşamayan kontrol sayısı ve adı ayrı satırda yazılır; koşamayan kontrol "0 uyarı" sayısına katılmaz ve kart yeşil gösterilmez.
- **AC-4.10:** Verildiğinde kargoya çıkmamış e-ticaret siparişleri, Yapıldığında kart 4 görüntülendiğinde, O zaman bekleyen sipariş sayısı ve 4 gün ve üstü bekleyen sayısı görünür; 2–3 gün bekleyen varsa sarı, 4 gün ve üstü bekleyen varsa kırmızıdır.
- **AC-4.11:** Verildiğinde 001'in Cari/Risk ek maddesi kabul testinden geçmiş ve vadesi geçen alacaklar, Yapıldığında kart 5 görüntülendiğinde, O zaman tutar ve limit aşan cari sayısı Cari/Risk ekranındaki değerle (AC-2.1) aynıdır ve aynı renk kuralını izler.
- **AC-4.12:** Verildiğinde açık ve geciken görevler, Yapıldığında kart 7 görüntülendiğinde, O zaman açık ve geciken görev sayısı görünür; geciken sayısı 0'dan büyükse kırmızıdır.
- **AC-4.13:** Verildiğinde dinlenme ve gece çalışma süresi sınırlarını aşan vardiya kayıtları, Yapıldığında kart 8 görüntülendiğinde, O zaman aşım sayısı mağaza bazında görünür, hiçbir çalışanın adı ya da sicili yazmaz; aşım sayısı 0'dan büyükse sarıdır.
- **AC-4.14:** Verildiğinde spec 003 nakit raporu teslim edilmemiş, Yapıldığında Bugün ekranı açıldığında, O zaman kart 6 görünmez.
- **AC-4.15:** Verildiğinde Bugün ekranındaki bir kart, Yapıldığında karta dokunulduğunda, O zaman kartın kaynak ekranı açılır.
- **AC-4.16:** Verildiğinde Sabah ekranının eski adresi, Yapıldığında bu adres telefonda ya da masaüstünde açıldığında, O zaman Bugün ekranı açılır.
- **AC-4.17:** Verildiğinde 001 maddelerinin ve 001 Cari/Risk ek maddesinin hiçbiri kabul testinden geçmemiş (ilk telefon sürümü), Yapıldığında GMY telefonda giriş yaptığında, O zaman Bugün ekranı açılır ve yalnız kart 7 görünür; alt bölümde hedef kartı ve dönem görünümü yer almaz.

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
- **AC-6.1:** Verildiğinde Diğer sekmesi, Yapıldığında sekme telefonda açıldığında, O zaman üstte Operasyon, Envanter ve Vardiya bağlantılarından 001 koşulu sağlananlar, altta "Masaüstünde daha iyi" başlıklı grupta C sınıfı ekranlar listelenir; Müşteri ve Trafik bu grupta yalnız 001 koşulu sağlanınca yer alır (AC-8.0).
- **AC-6.2:** Verildiğinde "Masaüstünde daha iyi" grubundaki bir ekran, Yapıldığında telefonda bağlantısına dokunulduğunda, O zaman ekran açılır, sayfa sonuna kadar kaydırıldığında sayfa yatay kaymaz ve sayfa genişliği 375 px'i aşmaz; geniş tablolar yalnız kendi kutusu içinde yatay kayabilir. 44 px dokunma kuralı (AC-0.6) C ekranlarına uygulanmaz. (Karar 07.10.2026; 02.10 denetiminde 17 C ekranın 15'i yana taşıyordu.)
- **AC-6.3:** Verildiğinde Operasyon ekranı telefonda, Yapıldığında ekran açıldığında, O zaman yalnız uyarı (istisna) kartı görünür; Kumbara ve manuel indirim göstergesi görünmez (001 AC-1.4); personel saati başına satış göstergesi de telefon özetinde görünmez. Masaüstündeki gösterge bu spec'te değişmez.
- **AC-6.3a:** Verildiğinde personel saati başına satış hesabı düzeltilmiş ve ayrı bir kayıtta (001 ek maddesi ya da 003) kabul testinden geçmiş, Yapıldığında Operasyon ekranı telefonda açıldığında, O zaman gösterge telefon özetinde görünür (AC-0.2 ile aynı kapı). Gizleme gerekçesi (ölçüm 06.09–06.10.2026): göstergenin payına fatura ve Sınav Okulları satışı giriyor, paydası yalnız mağaza personelinin saati; İst.Yolu'nda pay olarak alınan satışın %87,9'u fatura ve Sınav Okulları (FSM %1,8, Özlüce %2,7). (Karar 07.10.2026.)
- **AC-6.4:** Verildiğinde Envanter ekranı telefonda, Yapıldığında ekran açıldığında, O zaman üç stok göstergesi ve 001 H14'teki tanım açıklamaları görünür; listeler yerinde "Ayrıntı masaüstünde." notu yazar.
- **AC-6.5:** Verildiğinde Vardiya ekranı telefonda, Yapıldığında ekran açıldığında, O zaman yalnız mağaza bazında, isimsiz özet görünür ve kişi listesinin yerinde "Kişi satırları masaüstünde." notu yazar. Çalışan adı, sicili ya da notu içeren satır telefona hiç gönderilmez: sayfanın görünmeyen bölümleri dahil sayfa içeriğinde ad ya da sicil bulunmaz (gizlenmiş satır kabul edilmez). (KVKK kararı 08.10.2026.)
- **AC-6.5a:** Verildiğinde Vardiya ekranı masaüstünde açık ve kişi listesi görünüyor, Yapıldığında pencere telefon genişliğine daraltıldığında, O zaman kişi listesi sayfa içeriğinden kalkar ve AC-6.5'teki not görünür.
- **AC-6.6:** Verildiğinde Ayarlar ve Eşikler ekranları (veri değiştiren ekranlar), Yapıldığında telefonda açıldığında, O zaman kayıtlı değerler okunur, hiçbir alan düzenlenemez, kaydetme ya da silme düğmesi görünmez ve "Değişiklik masaüstünden yapılır." notu yazar. (Karar 07.10.2026.)
- **AC-6.7:** Verildiğinde aynı iki ekran masaüstü görünümünde, Yapıldığında açıldığında, O zaman bugünkü değiştirme işlemleri (ay kapanış tarihi girişi, eşik kaydı) ve oturum kapatma (AC-1.12) masaüstünde yapılabilir.

### H7 — Birleşen ekranların eski adresleri yeni yere gider (P3)
GMY olarak eski yer imlerim ve bağlantılarım bozulmadan birleşen ekranlara ulaşmak istiyorum, böylece telefon menüsü sade kalırken hiçbir bilgiyi kaybetmem.
**Bağımsız test:** Beş eski adres sırayla açılır; her biri hedef ekrana gider ve eski ekrandaki bilgi hedefte bulunur.
**Kabul kriterleri:**
- **AC-7.1:** Verildiğinde Ana sayfa v2, Sadakat, Bulunurluk, Satınalma ürün detayı ve Asistan belleği ekranlarının eski adresleri, Yapıldığında her biri açıldığında, O zaman sırasıyla Ana sayfa (Bugün), Müşteri, Satış analizi, Satış analizi ürün detayı ve Asistan ekranı açılır.
- **AC-7.2:** Verildiğinde ürün kimliği taşıyan eski Satınalma ürün detayı adresi, Yapıldığında adres açıldığında, O zaman aynı ürünün Satış analizi ürün detayı açılır.
- **AC-7.3:** Verildiğinde Sadakat, Bulunurluk, Satınalma ürün detayı ve Asistan belleği ekranlarında bugün gösterilen her gösterge, Yapıldığında hedef ekran masaüstünde açıldığında, O zaman her gösterge hedef ekranın bir bölümünde ya da sekmesinde aynı değerle bulunur.
- **AC-7.4:** Verildiğinde birleşme tamamlanmış, Yapıldığında masaüstü menüsü ve telefon sekmeleri açıldığında, O zaman beş eski ekranın hiçbiri ayrı menü öğesi olarak görünmez.

### H8 — Müşteri ve personel kişisel bilgisi telefonda maskeli görünür (P1)
GMY olarak Müşteri ve Trafik ekranlarını telefonda da açabilmek ama kişi adlarını, telefonlarını ve kart numaralarını açık görmemek istiyorum, böylece telefon kaybolsa ya da başkası ekrana baksa kişisel veri açığa çıkmaz.
Karar (GMY 08.10.2026, KVKK): Müşteri ve Trafik telefonda maskeli açılır; masaüstü değişmez. Karar (GMY 09.10.2026): bu ekranlar telefonda ancak bağlı 001 maddeleri (Müşteri D-1, Trafik H5, Sadakat H2 ve H5) kabul testinden geçince açılır; AC-8.1–8.7 ekran telefonda açıldığı andan itibaren geçerlidir.
**Bağımsız test:** Müşteri, Sadakat ve Trafik telefon görünümünde açılır; sayfa içeriğinde açık ad, telefon ve kart numarası aranır; aynı ekranlar masaüstünde açık değerle karşılaştırılır.
**Kabul kriterleri:**
- **AC-8.0:** Verildiğinde Müşteri, Trafik ya da Sadakat ekranının bağlı 001 maddelerinden en az biri kabul testinden geçmemiş, Yapıldığında GMY telefonda Diğer sekmesini açtığında ya da ekranın adresini telefonda doğrudan açtığında, O zaman ekran "Masaüstünde daha iyi" listesinde görünmez; doğrudan adreste ekran açılmaz, yerinde "Bu ekran telefonda henüz kapalı. Masaüstünden açın." notu görünür ve ekranın hiçbir rakamı ya da kişisel bilgisi telefona gönderilmez.
- **AC-8.0a:** Verildiğinde aynı ekranın bağlı 001 maddelerinin hepsi kabul testinden geçmiş, Yapıldığında Diğer sekmesi telefonda açıldığında, O zaman ekran "Masaüstünde daha iyi" listesinde görünür ve telefonda AC-8.1–8.7'ye göre maskeli açılır.
- **AC-8.1:** Verildiğinde Müşteri ekranı telefonda açılmış (liste, satır ayrıntısı, RFM ve ömür boyu değer tabloları), Yapıldığında ekran açıldığında, O zaman müşteri adı her kelimenin ilk harfi ve "***" ile ("Ahmet Yılmaz" → "A*** Y***"), telefon ilk 4 ve son 2 rakamı açık ("05321234545" → "0532 *** ** 45"), kart numarası son 4 karakteri açık ("2025000012341234" → "**** 1234") görünür.
- **AC-8.2:** Verildiğinde Sadakat ekranının geri kazanım listesi (ya da Müşteri'ye birleşmiş hâli) telefonda açılmış, Yapıldığında liste açıldığında, O zaman ad, telefon ve kart numarası AC-8.1 kuralıyla maskelidir.
- **AC-8.3:** Verildiğinde Trafik ekranının personel tablosu telefonda açılmış, Yapıldığında tablo açıldığında, O zaman kasiyer adı AC-8.1'deki ad kuralıyla maskelidir; fiş sayısı, net tutar, gün ve saat açık kalır.
- **AC-8.4:** Verildiğinde AC-8.1–8.3'teki ekranlar telefonda açık, Yapıldığında sayfa içeriğinin tamamı (görünmeyen bölümler ve dokununca açılan ayrıntılar dahil) aranır, O zaman maskelenen alanların açık değeri hiçbir yerde bulunmaz.
- **AC-8.5:** Verildiğinde ekranın telefon mu masaüstü mü olduğu henüz belli değil (sayfanın ilk çizimi), Yapıldığında sayfa yüklenirken içerik okunduğunda, O zaman alanlar maskelidir.
- **AC-8.6:** Verildiğinde maskelenecek alan boş, Yapıldığında gösterildiğinde, O zaman "—" görünür. Telefon numarası 6 rakamdan kısaysa "***", kart numarası 4 karakter ya da kısaysa "****" görünür.
- **AC-8.7:** Verildiğinde aynı ekranlar masaüstünde, Yapıldığında açıldığında, O zaman ad, telefon ve kart numarası bugünkü gibi açık görünür; sayılar (ciro, sıklık, fiş) telefonla masaüstünde birebir aynıdır.

## Sınır durumlar
- 001 maddesi kabul testinden sonra geri alınırsa: ilgili ekran ve kartlar telefondan yeniden kalkar (AC-0.1 her açılışta geçerli).
- Okul dönemine göre eşleşen geçen yıl günü yoksa ya da o gün satış yoksa: kart 1 değişim yüzdesi yerine "Kıyas günü yok" yazar ve renk göstermez.
- Dün mağaza kapalıysa (bayram, tatil): kart 1 o mağaza için "Kapalı" yazar, 0'ı düşüş saymaz.
- Bugünün ciro rakamı: kasadan ERP'ye aktarım saatte birdir. Bugün ekranı "dün" için kapalı günü kullanır; bugüne ait gösterge varsa yanında "gün içi, saatte bir güncellenir" notu yazar.
- Bir kart kaynağı hata verirse: yalnız o kart hata mesajını gösterir (AC-0.10); öteki kartlar yüklenir.
- Kontrol listesi hiç koşamazsa: kart 3 "Kontroller koşamadı" der, "0 uyarı" demez.
- Telefon yatay çevrilirse: ekran okunur kalır; kabul testi yalnız dikey yapılır.
- Görev sayısı ya da bekleyen sipariş 0 ise: kart "0" gösterir ve renksizdir; kart gizlenmez.
- Telefon kaybolursa: GMY masaüstünden bütün oturumları kapatır (AC-1.12); telefondaki uygulama en geç 1 dakikada giriş sayfasına döner. Masaüstüne erişim yoksa oturum en geç 12 saat etkileşimsizlikte, en geç 7 günde kendiliğinden kapanır.
- Uzaktan kapatma sırasında telefon çevrimdışıysa: telefon yeniden bağlandığı ilk anda giriş sayfasına döner; çevrimdışıyken zaten rakam göstermez (AC-1.10).
- Maske bir gösterim kuralıdır, yetki sınırı değildir: aynı oturum masaüstü genişliğine geçerse açık değeri görür.

## Fonksiyonel gereksinimler
- **FR-001:** Sistem telefona ana ekran simgesiyle kurulabilmek ve simgeden adres çubuksuz, tam ekran açılmak ZORUNDADIR (H1).
- **FR-002:** Sistem telefon görünümünde beş sekmeli alt menü (Bugün · Satış · Finans · Asistan · Diğer) sunmak, masaüstünde bugünkü menüyü korumak ZORUNDADIR (H1).
- **FR-003:** Sistem telefonda girişten sonra açılış ekranı olarak Bugün ekranını açmak ZORUNDADIR. İlk telefon sürümünde de Bugün açılır ve yalnız 001'den bağımsız kartı (7 açık görevler) gösterir; öteki kartlar bağlı 001 maddeleri kapandıkça eklenir (karar 07.10.2026, güncelleme 08.10.2026; bkz. AC-4.17).
- **FR-003a:** Sistem C sınıfı ekranlarda telefonda yatay sayfa taşması üretmemek ZORUNDADIR; geniş tablo kendi kutusu içinde kayabilir (AC-6.2).
- **FR-003b:** Sistem Ayarlar ve Eşikler ekranlarını telefonda yalnız okunur açmak ZORUNDADIR (AC-6.6).
- **FR-004:** Sistem 001 bağımlılığı olan bir ekranı ya da kartı, bağlı 001 maddelerinin hepsi kabul testinden geçene kadar telefon menüsünde ve Bugün ekranında göstermemek ZORUNDADIR (AC-0.1, AC-4.2).
- **FR-005:** Sistem telefonda ve masaüstünde aynı göstergeyi aynı hesapla ve aynı değerle göstermek ZORUNDADIR; telefon için ayrı hesap yapılmaz (AC-0.3).
- **FR-006:** Sistem A ve B ekranlarında telefon görünümünde yatay sayfa taşması üretmemek, dokunulabilir öğeleri en az 44×44 px yapmak ve yalnız fareyle görülen bilgi bırakmamak ZORUNDADIR (AC-0.5–0.7).
- **FR-007:** Sistem B ekranlarında telefonda gösterilmeyen bölümün yerine "Ayrıntı masaüstünde." notunu koymak ZORUNDADIR (H5, H6).
- **FR-008:** Sistem Bugün ekranında kartların renklerini bu spec'teki eşiklere göre vermek ve koşamayan kontrolü "uyarı yok" saymamak ZORUNDADIR (H4).
- **FR-009:** Sistem çalışan adı, sicili ya da notu içeren vardiya satırını telefona hiç göndermemek ZORUNDADIR; gizleyerek göndermek yetmez (AC-4.13, AC-6.5, AC-6.5a).
- **FR-010:** Sistem birleşen beş ekranın ve Sabah ekranının eski adreslerini yeni ekrana yönlendirmek, eski ekranlardaki her göstergeyi hedef ekranda korumak ZORUNDADIR (H7, AC-4.16).
- **FR-011:** Sistem bağlantı yokken önceden görülmüş rakam göstermemek ZORUNDADIR; telefonda veri saklanmaz (AC-1.10).
- **FR-012:** Sistem bu spec kapsamında hiçbir rakamın hesabını değiştirmemek ZORUNDADIR; rakam düzeltmesi 001'in, yeni gösterge 003'ün işidir.
- **FR-013:** Sistem hiçbir ERP, POS ya da e-ticaret verisini değiştirmemek ZORUNDADIR.
- **FR-014:** Sistem her oturumu sunucuda kaydetmek, masaüstünden bütün oturumların kapatılmasına izin vermek, oturumu 12 saat etkileşimsizlikten ya da 7 gün sonra kendiliğinden kapatmak ve kapanan oturumda açık ekranı en geç 1 dakikada giriş sayfasına döndürmek ZORUNDADIR (AC-1.12–1.16).
- **FR-015:** Sistem Müşteri, Sadakat ve Trafik ekranlarında kişi adı, telefon ve kart numarasını telefonda ve görünümü henüz belli olmayan ilk çizimde maskeli göndermek ZORUNDADIR; açık değer telefona gitmez. Hesap ve sorgu değişmez (H8).
- **FR-016:** Sistem telefon görünümünde dışa aktarma düğmesi göstermemek ve telefona dosya indirmemek ZORUNDADIR (AC-0.11).

## Yetki
| Rol | Yapabilir | Yapamaz |
|---|---|---|
| GMY (tek kullanıcı, oturum açmış; telefon ya da masaüstü) | Telefona kurmak; bütün açık ekranları görmek; görev eklemek, tamamlamak, silmek; asistan önerisini onaylamak ya da reddetmek; masaüstünde bugünkü bütün işlemleri yapmak; masaüstünden bütün oturumları kapatmak; her cihazda kendi oturumundan çıkmak | 001 koşulu sağlanmamış ekranı telefon menüsünden açmak; telefonda çalışan adlı vardiya satırı görmek; telefonda müşteri ya da kasiyer kişisel bilgisini açık görmek; telefondan dışa aktarmak; telefondan Ayarlar ya da Eşikler değerini değiştirmek; telefondan oturum kapatma düğmesini kullanmak; ERP, POS, e-ticaret verisini değiştirmek |
| Oturum açmamış kişi (telefonda kurulu simgeyi açan, oturumu uzaktan ya da süre dolduğu için kapanmış cihaz dahil) | Giriş sayfasını görmek | Hiçbir ekranı, kartı ya da daha önce görülmüş rakamı görmek |
| Panel uygulaması | ERP, POS, e-ticaret, İK verisini okumak; panelin kendi görev, asistan ve oturum kayıtlarını panel veritabanına yazmak | Telefonda rakam saklamak; telefona bildirim göndermek; telefona açık kişisel veri ya da vardiya kişi satırı göndermek; ERP'de herhangi bir tabloya yazmak |

Yetki modeli değişmiyor (tek kullanıcı).

## Anahtar varlıklar
- **Ekran sınıfı:** A, B, C ya da X; telefondaki davranışı belirler.
- **001 bağımlılığı:** bir ekranın telefona açılması için kabul testinden geçmesi gereken 001 maddeleri.
- **Bugün kartı:** tek göstergeyi, rengini ve kaynak ekranını taşır; görünürlüğü kaynak ekranın 001 bağımlılığına bağlıdır.
- **Kıyas günü:** dün için okul dönemine göre eşleşen geçen yıl günü.
- **Kontrol sonucu (uyarı):** Sabah kontrollerinin her biri için "uyarı var / uyarı yok / koşamadı".
- **Birleşme eşlemesi:** eski ekran → yeni ekran ve yeni ekrandaki yeri.
- **Oturum:** bir cihazdaki giriş; cihaz özeti, açılış zamanı, son görülme zamanı ve açık/kapalı durumu taşır. IP adresi gösterilmez.
- **Maskeli alan:** kişi adı, telefon, kart numarası; telefonda yalnız maskeli hâli gösterilir.

## Veri kaynağı ve ortam
- Yeni veri kaynağı yok. Ekranlar bugünkü kaynaklarını okur: ERP DerinSISBkm (compat 150), POS EncoreMerkez (compat 110), Sınav BKM (compat 150), hedef BKMDATA (compat 150), müşteri DerinCrm (compat 150), e-ticaret JOKER (compat 150), İK/bordro Zirve (compat bilinmiyor; bu spec yeni sorgu yazmaz). Ölçüm: `docs/proje/veritabani.md`, 03.10.2026 (001 spec ile aynı).
- Panelin kendi kayıtları (görev, asistan belleği) bugünkü panel veritabanında kalır. Oturum kayıtları da panel veritabanına yazılır; ERP'ye yazılmaz.
- Kurulum ve telefon testi güvenli bağlantı ister ve bu spec'te **yalnız şirket iç ağında (LAN)** yapılır. Dışarıdan erişim ve tünel 004'ün işidir; kişisel veri taşıyan hiçbir ekran, hukuki görüş gelene kadar tünelden geçmez (KVKK kararı K6, 08.10.2026).

## Başarı kriterleri
- **SC-001:** 375×812 telefon görünümünde telefona açılmış A ve B ekranlarının hiçbirinde yatay sayfa kaydırması yoktur (ekran başına ölçüm, %100).
- **SC-001a:** 375×812 telefon görünümünde 17 C sınıfı ekranın hiçbirinde yatay sayfa kaydırması yoktur (02.10.2026'da 15'inde vardı).
- **SC-002:** A ve B ekranlarında 44×44 px'ten küçük dokunulabilir öğe sayısı 0'dır.
- **SC-003:** Panel şirket iç ağında en az bir Android ve bir iOS telefonda ana ekrana kurulur ve simgeden tam ekran açılır. iOS'ta iç ağda güvenli bağlantı kurulamazsa iOS adımı 004'e kadar "karar bekliyor" yazılır, "geçti" sayılmaz.
- **SC-004:** Telefonda açılış ekranından Görevler ve Asistan'a, 001 Cari/Risk ek maddesi kapandıktan sonra Cari/Risk'e en fazla iki dokunuşla ulaşılır (bugün üç).
- **SC-005:** Telefonda gösterilen her gösterge, masaüstündeki aynı göstergeyle aynı dönem için birebir aynıdır (örnekleme: her açık ekrandan en az bir gösterge).
- **SC-006:** 001 maddesi kapanmamış ekranların telefon menüsünde görünme sayısı 0'dır.
- **SC-007:** Birleşen beş ekranın eski adreslerinin beşi de hedef ekrana gider.
- **SC-009a:** Bağlı 001 maddeleri kapanmadan telefonda Diğer listesinde Müşteri ve Trafik'in görünme sayısı 0'dır.
- **SC-009:** Telefon görünümünde açılmış Müşteri, Sadakat ve Trafik ekranlarının sayfa içeriğinde açık ad, telefon ve kart numarası sayısı 0'dır; Vardiya ekranında ad ve sicil sayısı 0'dır.
- **SC-010:** Masaüstünden bütün oturumlar kapatıldığında açık telefon oturumu en geç 1 dakikada giriş sayfasına döner (en az bir ölçüm).
- **SC-011:** Telefon görünümünde dışa aktarma düğmesi sayısı 0'dır.
- **SC-008 (ÇIKARIM ölçüt):** GMY sabah ilk bakışını telefondan yapar. Nasıl ölçüleceği plan aşamasında belirlenir.

## Kapsam dışı
- Yeni rapor ve yeni veri: nakit takvimi (kart 6), vergi ve SGK karşılığı, borç servisi, kanal katkı payı, İK ve BT kartları, Bugün kart 3'e eklenecek yeni uyarı türleri (kapanmayan kasa, kasa↔ERP farkı, manuel indirim sapması) → spec 003.
- Sunucu, servis kurulumu, kalıcı güvenli bağlantı, dışarıdan erişim, dışarıdan erişim koruması, parola sıfırlama → spec 004. (Oturum kaydı, uzaktan kapatma ve oturum süreleri bu spec'tedir; karar 08.10.2026.)
- Tünelle kurulum ve tünelden telefon testi (004'e ve hukuki görüşe kadar; K6).
- Dışa aktarma günlüğü (kim, hangi ekran, kaç satır) → 004 ya da ayrı iş.
- Asistan'ın kişisel veri maskesi ve Vardiya serbest metin notlarının incelenmesi (mevcut işleme; ayrı iş).
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
- 001 koşulu sağlanmamış bir ekran telefonda doğrudan adresle açılırsa bugünkü (uyarlanmamış) düzeniyle açılır; menüde ve Bugün ekranında görünmez. İstisna: kişisel veri taşıyan Müşteri, Trafik ve Sadakat doğrudan adresle de açılmaz (AC-8.0).
- Telefon kabul testi dikey 375×812 görünümde yapılır; ayrıca kullanıcı kendi telefonunda dener.
- Kurulum testi yalnız şirket iç ağında, panelin mevcut güvenli bağlantısıyla yapılır; 05.10.2026'daki tünel denemesi yöntemi bu spec'te kullanılmaz (K6).
- İlk telefon sürümü 001'i beklemeden yayına çıkar (GMY kararı K10, 08.10.2026: "maskele sürüm çıksın"). İçeriği: kabuk ve kurulum, alt menü, 001 kapısı, oturum yönetimi, Görevler, Asistan, Muhasebe, Gelir tablosu, Bugün kart 7 ve 001'e bağlı olmayan C ekranları. Müşteri, Trafik ve Sadakat ilk sürümde telefonda kapalıdır; bağlı 001 maddeleri kapanınca maskeli açılır (GMY kararı 09.10.2026). Oturum yönetimi (AC-1.12–1.16) GMY'nin telefona kalıcı kurulumundan önce tamamlanır. Öteki ekranlar ve kartlar 001 maddeleri kapandıkça açılır.
- Kart 1 eşik sınırları: −%5 sarıya, −%10 kırmızıya dahildir; −%5'ten iyi değişim renksizdir.
- Okul dönemine göre eşleşen geçen yıl günü: Temmuz–Ekim arasında okul açılış tarihleri farkı kadar geri (2026 için 371 gün), öteki aylarda 364 gün geri (aynı hafta günü). (Kanıt: `arastirma.md` § 7.)
- Kart 1 ve kart 2'deki ciro tabanı Ana sayfadakiyle aynıdır (001 H13, D-5 dipnotuyla).
- Kart 3, Ana sayfanın bugünkü iki uyarı kuralını (mağaza cirosu −%10 ya da daha kötü; iade oranı %2'nin üstü) dün için koşar; yeni kontrol türleri 003 ile eklenir.
- Kart 8 uyum sınırları Vardiya ekranının bugün kullandığı sınırlardır (11 saat, 12 saat dinlenme, gece 7,5 saat).
- Envanter telefon özetindeki üç gösterge ölü stok, aşırı stok ve stokta yokluktur (uzman: "telefona 3 sayı"); plan aşamasında teyit edilir.
- Muhasebe kartındaki "kontrol bulgusu", Muhasebe ekranının bugün listelediği ay kapanışı kontrol kalemleridir.
- Görev ve asistan işlemleri telefonda masaüstüyle aynı kalır; yeni işlem eklenmez.
- "Masaüstünde daha iyi" grubunda 17 C sınıfı ekranın hepsi listelenir (Müşteri ve Trafik 001 koşulu sağlanınca, AC-8.0); plan taslağındaki "mobil menüden çıkar" listesi bu kararla değişti.
- Kullanıcı tek kişidir (GMY); telefon ve masaüstü aynı oturum kurallarını kullanır, ama her cihazın oturumu ayrı kaydedilir.
- Telefon/masaüstü ayrımı ekran genişliğine göre yapılır; genişlik henüz bilinmiyorsa telefon kuralları (maske, vardiya kişi satırı yok, dışa aktarma yok) uygulanır.

## Kontrol listesi
- [x] `[NEEDS CLARIFICATION]` kalmadı — 5 soru 07.10.2026'da kararlandı (AC-4.4, AC-6.2, AC-6.3, AC-6.6, FR-003)
- [x] Her AC Verildiğinde/Yapıldığında/O zaman biçiminde ve test edilebilir
- [x] NASIL detayı yok (tablo/sınıf/endpoint adı, teknoloji)
- [x] Yetki negatifleri yazılı
- [x] Kapsam dışı yazılı
- [x] Değişiklik 2 (08.10.2026): K10 ilk sürüm, K11 maskeleme (H8), K12 oturum (AC-1.12–1.16, FR-014), vardiya kişi satırı, dışa aktarma, LAN kuralı (K6) işlendi
