# Özellik 001: Panel veri düzeltmeleri

**Durum:** Onaylandı (03.10.2026) · **Oluşturma:** 03.10.2026 · **Boy:** Büyük
**Değişiklik notu:** 04.10.2026 GMY kararıyla H7 güncellendi (maliyetli / maliyetsiz ciro ayrımı, marj paydası, maliyeti bilinen ciro yüzdesi).
**Girdi (kullanıcı isteği):** "pusula içindeki gm dashboardı orkestrayı kullanarak elden geçir tamamen mobil app olarak şekilde güncelle raporları ekranları rapor verilerini kontrol et yenilerini eklemelisin gerekli danışmanları ekleyerek onlara danış"
Kullanıcı kararı (03.10.2026): iş dört spec'e bölündü. Bu spec yalnız **rapor verilerini kontrol et** kısmını kapsar. 002 (mobil ekranlar) bu spec bitmeden başlamaz.

## Amaç / Neden

GMY panelde gördüğü bazı rakamları bugün sorgu ve Excel ile elle doğruluyor. 02.10.2026 denetimi, beş ekranda rakamın bağımsız ölçümden saptığını gösterdi. En büyük sapma: kampanya indirim tutarı 27 kat şişik hesaplanıyor. Win-back listesindeki müşterilerin %45'i aslında son 90 günde alışveriş yapmış. Panel telefona taşınmadan önce yanlış rakamlar düzeltilmeli; aksi hâlde hata mobilde de sürer.

Kanıt: `.orkestra/calisma/001-panel-veri-duzeltme/sql-bulgulari.md`, `.orkestra/gm-denetim-2026-10-02.json`.

## Doğrulama ilkesi (bütün hikâyeler için ortak)

- **Kanonik değer:** proje kural setindeki tanımla (şube cirosu, merkez depo stoğu, müşteri raporu, belge türü, indirim, iptal/iade) panelden **bağımsız** yazılmış bir sorgunun aynı dönem için verdiği değer.
- **Doğrulama dönemi:** son kapalı ay, Eylül 2026 (01.09.2026–30.09.2026). Açık gün kıyaslanmaz; kasadan ERP'ye aktarım saatte birdir.
- **Tolerans:** aksi yazılmadıkça adet ve sayılarda **birebir eşitlik**, tutarlarda **en fazla 1,00 TL** fark (satır başı yuvarlama).
- Her düzeltme için **önce** ve **sonra** değeri ile kanıt sorgusu proje sorgu arşivine yazılır.

**Ortak kabul kriterleri (değişiklik bildirimi — kullanıcı kararı 03.10.2026):**
- **AC-0.1:** Verildiğinde bu spec ile değeri değişen bir gösterge, Yapıldığında düzeltmenin yayına alındığı günden itibaren 30 gün içinde ekran açıldığında, O zaman göstergenin yanında "Hesap düzeltildi (gg.aa)" notu görünür; tarih yayına alma tarihidir.
- **AC-0.2:** Verildiğinde aynı gösterge, Yapıldığında yayına alma tarihinden 31 gün sonra ekran açıldığında, O zaman not görünmez; değişiklik (gösterge, önce ve sonra değeri) oturum günlüğünde (journal) kayıtlıdır.

## Kullanıcı hikâyeleri

### H1 — Kampanya indirimi gerçek tutarıyla görünür (P1)
GMY olarak Kumbara ve manuel indirim tutarlarını fiş başına bir kez sayılmış hâliyle görmek istiyorum, böylece indirim yükünü 27 kat şişik rakamla değerlendirmem.
**Bağımsız test:** Eylül 2026 Kumbara brüt ve indirim tutarı, fiş başına tekil toplamla karşılaştırılır.
**Kabul kriterleri:**
- **AC-1.1:** Verildiğinde Eylül 2026 dönemi ve Kumbara kampanyası, Yapıldığında panel Kumbara brüt tutarını hesapladığında, O zaman sonuç fiş başına bir kez sayılan kanonik toplama eşittir (02.10.2026 ölçümü: 223.717,80 TL; düzeltme öncesi 6.106.723,80 TL) ve fark en fazla 1,00 TL'dir.
- **AC-1.2:** Verildiğinde aynı dönem, Yapıldığında Kumbara ve manuel indirim tutarları hesaplandığında, O zaman her biri kanonik indirim tanımıyla (yalnız doğrudan indirim toplamı, geçerli kalemler) bağımsız hesaplanan değere 1,00 TL toleransla eşittir.
- **AC-1.3:** Verildiğinde dönemde iade belgesi bulunan bir kampanya, Yapıldığında tutarlar hesaplandığında, O zaman iade tutarı toplamdan düşülür; fatura, personel ve Sınav Okulları belgeleri proje belge kuralına göre ele alınır ve kanonik değerle eşitlik AC-1.1 toleransında kalır.
- **AC-1.4:** Verildiğinde düzeltilmiş hesap, Yapıldığında bu spec teslim edildiğinde, O zaman Kumbara ve manuel indirim için hiçbir ekranda yeni gösterge görünmez; ekranda gösterme spec 003'ün (indirim ve kasa kontrolü raporu) işidir ve 003, AC-1.1–1.3 ile doğrulanmış hesabı kullanır. (Kullanıcı kararı 03.10.2026.)

### H2 — Win-back listesi yalnız gerçekten kaybedilen müşterileri gösterir (P1)
GMY olarak geri kazanım listesinde son 90 günde alışveriş yapmamış müşterileri görmek istiyorum, böylece aktif müşteriye "kayıp" diye kampanya yapmam.
**Bağımsız test:** Listedeki müşteriler son 90 günün satış fişleriyle kesiştirilir.
**Kabul kriterleri:**
- **AC-2.1:** Verildiğinde win-back listesi üretildiği gün, Yapıldığında listedeki müşteriler son 90 günün satış fişleriyle karşılaştırıldığında, O zaman kesişim **0 müşteridir** (02.10.2026 ölçümü: 51.309 adayın 23.110'u son 90 günde fiş kesmişti).
- **AC-2.2:** Verildiğinde listedeki bir müşteri, Yapıldığında "son alışverişten bu yana geçen gün" gösterildiğinde, O zaman değer müşterinin tüm zamanlardaki son satış fişinin tarihinden hesaplanır ve 90'dan büyüktür.
- **AC-2.3:** Verildiğinde dönemde iade belgesi olan bir müşteri, Yapıldığında alışveriş sıklığı gösterildiğinde, O zaman sıklık yalnız satış fişlerini sayar; iade belgesi sıklığı artırmaz.
- **AC-2.4:** Verildiğinde listeye girme koşulu (son 365 günde aktif, son 90 günde alışveriş yok), Yapıldığında liste bağımsız kanonik sorguyla aynı gün üretildiğinde, O zaman iki listenin müşteri kümesi birebir aynıdır.

### H3 — Tedarikçi performansında merkez depo stoğu doğru kaynaktan gelir (P1)
GMY olarak tedarikçi/yayınevi karnesinde stok devir hızını ve sipariş sinyalini depo yönetim sisteminin (WMS) stoğuyla görmek istiyorum, böylece 1,4–1,6 kat şişik stokla "sipariş kesme" kararı vermem.
**Bağımsız test:** Karnedeki merkez depo stok bileşeni, WMS stoğuyla aynı tarih için karşılaştırılır.
**Kabul kriterleri:**
- **AC-3.1:** Verildiğinde bir tedarikçi, Yapıldığında karnede merkez depo stoğu hesaplandığında, O zaman değer WMS satılabilir stoğuna (raf + giriş alanı; çıkış alanı hariç) eşittir; ERP defterindeki merkez depo bakiyesi kullanılmaz.
- **AC-3.2:** Verildiğinde tüm tedarikçiler, Yapıldığında karnedeki merkez depo stokları toplandığında, O zaman toplam, aynı stok tabanı ve tarih için bağımsız WMS toplamına birebir eşittir (02.10.2026 ölçümü: ERP defteri 5.884.929 adet, WMS 3.628.661 adet).
- **AC-3.3:** Verildiğinde aynı ürün, Yapıldığında karne ile kategori çeşit ekranı merkez depo stoğunu gösterdiğinde, O zaman iki ekran aynı stok tabanından (aynı tarih, aynı kaynak) aynı değeri verir.
- **AC-3.4:** Verildiğinde mağaza stokları, Yapıldığında karne hesaplandığında, O zaman mağaza stoğu bugünkü kaynağından okunmaya devam eder ve değeri düzeltme öncesiyle aynıdır.

### H4 — E-ticaret kategori kırılımı ana ciroyla tutar (P2)
GMY olarak e-ticaret kategori karmasında iptal ve iade edilmiş siparişleri görmemek istiyorum, böylece kategori toplamı ana e-ticaret cirosuyla aynı olur.
**Bağımsız test:** Eylül 2026 kategori toplamı ana net ciroyla karşılaştırılır.
**Kabul kriterleri:**
- **AC-4.1:** Verildiğinde Eylül 2026, Yapıldığında kategori karması, kategori detayı ve yıllık yığılmış grafik hesaplandığında, O zaman iptal, iade ve kayıp durumundaki siparişler, ana e-ticaret cirosunda hariç tutulanlarla aynı kurala göre hariçtir.
- **AC-4.2:** Verildiğinde Eylül 2026, Yapıldığında kategori toplamı ile kategorisi bilinmeyen satırların toplamı birleştirildiğinde, O zaman sonuç ana net ciroya (121.955.096,47 TL) 1,00 TL toleransla, sipariş sayısı ana sipariş sayısına (113.731) birebir eşittir. Düzeltme öncesi: 126.329.033,57 TL / 117.884 sipariş.
- **AC-4.3:** Verildiğinde ODAK stok ekranının e-ticaret talep kolonu, Yapıldığında talep adedi hesaplandığında, O zaman iptal veya iade edilmiş sipariş satırlarının adedi talebe girmez ve değer bağımsız kanonik adede birebir eşittir.

### H5 — Fiş sayısı her ekranda aynı (P2)
GMY olarak bir mağazanın bir dönemdeki fiş sayısını Ana sayfa, Trafik ve Sadakat ekranlarında aynı görmek istiyorum, böylece dönüşüm oranı ve sepet ortalaması ekranlar arası çelişmez.
**Bağımsız test:** FSM Eylül 2026 fiş sayısı üç ekranda karşılaştırılır.
**Kabul kriterleri:**
Kanonik fiş tanımı (kullanıcı kararı 03.10.2026): **yalnız perakende satış fişi; geri dönüşüm (1001) fişi hariç.** İade, fatura, personel ve Sınav Okulları belgeleri fiş sayılmaz. İade ayrı bir sayı olarak gösterilir.
- **AC-5.1:** Verildiğinde FSM ve Eylül 2026, Yapıldığında Ana sayfa mağaza kartı, Trafik KPI'ı, saat ısı haritası ve personel tablosu fiş sayısını gösterdiğinde, O zaman dört değer birbirine ve kanonik fiş tanımıyla yapılan bağımsız sayıma birebir eşittir (düzeltme öncesi Trafik 44.205, Ana sayfa 42.311; %4,5 fark — 04.10.2026 ölçümü; 02.10 notundaki 44.776 1001 dışlamasız tip sayımıydı, panel değeri değil).
- **AC-5.2:** Verildiğinde kanonik fiş tanımı, Yapıldığında dönüşüm oranı (fiş ÷ ziyaretçi) ve sepet ortalaması hesaplandığında, O zaman pay olarak AC-5.1'deki aynı fiş sayısı kullanılır.
- **AC-5.3:** Verildiğinde Sadakat kartlı/kartsız karşılaştırması, Yapıldığında fiş sayısı ve fiş başı ortalama hesaplandığında, O zaman fiş sayısı kanonik tanıma uyar ve iade belgelerini içermez; ciro iade düşülmüş olarak kalır.
- **AC-5.4:** Verildiğinde FSM ve Eylül 2026, Yapıldığında fiş sayısının gösterildiği ekranlarda iade sayısı gösterildiğinde, O zaman iade sayısı fiş sayısından ayrı bir değer olarak görünür ve bağımsız iade belgesi sayımına birebir eşittir (geri dönüşüm satırı taşıyan iade belgeleri hariç; 03.10.2026 ölçümü: 947 — KR-1 onaylandı).

### H6 — Mağaza sayfasında indirim, iade ve UPT tek tabanda (P2)
GMY olarak mağaza detay sayfasında kampanya yükünü, iade tutarını ve kalem/fiş oranını (UPT) tutarlı tabanda görmek istiyorum, böylece Ana sayfa ile mağaza sayfası aynı mağaza için farklı iade göstermez.
**Bağımsız test:** Eylül 2026 için üç mağazada kampanya yükü, iade ve UPT bağımsız sorguyla karşılaştırılır.
**Kabul kriterleri:**
- **AC-6.1:** Verildiğinde iptal edilmiş fiş kalemine bağlı kampanya kaydı, Yapıldığında kampanya yükü (3AL2ÖDE ve diğer indirimler) hesaplandığında, O zaman o kaydın indirimi toplama girmez.
- **AC-6.2:** Verildiğinde Eylül 2026 ve her mağaza, Yapıldığında kampanya yükü gösterildiğinde, O zaman aynı KDV tabanında "brüt − indirim = net" eşitliği 1,00 TL toleransla sağlanır.
- **AC-6.3:** Verildiğinde aynı mağaza ve dönem, Yapıldığında iade tutarı Ana sayfa mağaza kartında ve mağaza detay sayfasında gösterildiğinde, O zaman iki değer KDV hariç, indirim düşülmüş tabanda ve birbirine 1,00 TL toleransla eşittir; iade oranı da bu tabandan hesaplanır.
- **AC-6.4:** Verildiğinde Eylül 2026 ve İstanbul Yolu mağazası, Yapıldığında UPT hesaplandığında, O zaman kalem ve fiş sayısı yalnız H5'teki kanonik fiş tanımına giren belgelerden alınır; Sınav Okulları ve fatura belgeleri payı ve paydayı etkilemez. Saat × gün ısı haritası aynı tanımı kullanır.

### H7 — Kategori marjı ve ABC sınıflaması iadeyi düşer, maliyeti bilinmeyen ciroyu ayrı gösterir (P2)
GMY olarak kategori brüt marjını ve ABC ürün sınıflamasını iadeler düşülmüş satışla görmek istiyorum, böylece iade edilen ürün A sınıfında, toptan depo sevki perakende marjında görünmez. Maliyeti kayıtlı olmayan satışın cirosunu da ayrı görmek istiyorum, böylece ne ciroyu kaybederim ne de marjı şişik okurum.
GMY kararı (04.10.2026): kategori marjında ciro iki kolondur: **maliyetli ciro** ve **maliyetsiz ciro**. Marj yüzdesi yalnız maliyetli ciro üzerinden hesaplanır. Ek kolon: **maliyeti bilinen ciro yüzdesi**. Gerekçe (ölçüm, T-011): bugün maliyetsiz ürün cirosu tamamen düşüyor (Eylül 2026, üç mağaza: 260,1 milyon TL; bunun 254,3 milyon TL'si Sınav Okulları'nın 31 ürünü). Bu ciro marj paydasına konsaydı Sınav marjı %100'e yakın görünürdü.
**Bağımsız test:** Eylül 2026 kategori cirosu (maliyetli + maliyetsiz) ve satılan malın maliyeti, kanonik şube cirosu tanımıyla karşılaştırılır.
**Kabul kriterleri:**
- **AC-7.1:** Verildiğinde Eylül 2026, Yapıldığında kategori marjı hesaplandığında, O zaman ciro ve satılan malın maliyeti iade hareketleri düşülmüş olarak, yalnız üç mağazanın perakende satışından gelir; merkez deponun toptan sevki girmez.
- **AC-7.2:** Verildiğinde Eylül 2026 ve her kategori, Yapıldığında kategori marjı tablosu gösterildiğinde, O zaman "Maliyetli ciro" ve "Maliyetsiz ciro" ayrı kolonlarda görünür ve Maliyetli ciro + Maliyetsiz ciro = toplam kategori cirosu eşitliği 1,00 TL toleransla sağlanır.
- **AC-7.2a:** Verildiğinde Eylül 2026, Yapıldığında tüm kategorilerin toplam kategori cirosu (maliyetli + maliyetsiz) toplandığında, O zaman sonuç üç mağaza için kanonik şube cirosuna (satış − iade, mağaza satışı dahil) 1,00 TL toleransla eşittir; maliyeti kayıtlı olmayan satışların cirosu toplamdan düşmez.
- **AC-7.2b:** Verildiğinde Eylül 2026, Yapıldığında tüm kategorilerin maliyetsiz cirosu toplandığında, O zaman sonuç, satılan malın maliyeti kayıtlı olmayan satışların bağımsız hesaplanan cirosuna 1,00 TL toleransla eşittir (T-011 ölçümü: yaklaşık 260,1 milyon TL).
- **AC-7.2c:** Verildiğinde bir kategori, Yapıldığında marj yüzdesi hesaplandığında, O zaman marj % = (Maliyetli ciro − satılan malın maliyeti) ÷ Maliyetli ciro × 100'dür; maliyetsiz ciro paydaya ve paya girmez. Maliyetli cirosu 0 olan kategoride marj yüzdesi "—" gösterilir, %0 ya da %100 gösterilmez.
- **AC-7.2d:** Verildiğinde bir kategori, Yapıldığında "Maliyeti bilinen ciro %" kolonu gösterildiğinde, O zaman değer Maliyetli ciro ÷ (Maliyetli ciro + Maliyetsiz ciro) × 100'dür, 0 ile 100 arasındadır ve toplam cirosu 0 olan kategoride "—" gösterilir.
- **AC-7.3:** Verildiğinde dönemde iadesi olan bir ürün, Yapıldığında ABC sınıflaması hesaplandığında, O zaman ürünün sınıflama cirosu iadesi düşülmüş tutardır ve bağımsız hesaplanan değere 1,00 TL toleransla eşittir.

### H8 — Merkez depo stoğu bugün için canlı, geçmiş için tarihli (P2)
GMY olarak bugünkü merkez depo stoğunu canlı WMS'ten, geçmiş ay bakiyesini ise hangi tarihe ait olduğunu görerek izlemek istiyorum, böylece bir ay eski stoğu bugünkü stok sanmam ve ekranlar arasında farklı depo rakamı görmem.
Kullanıcı kararı (03.10.2026): bugünün stoğu canlı WMS'ten; geçmiş ay bakiyesi ay sonu görüntüsünden, tarih etiketiyle.
**Bağımsız test:** Aynı gün, aynı ürün için merkez depo stoğu her ekranda canlı WMS toplamıyla; geçmiş ay bakiyesi ay sonu görüntüsüyle karşılaştırılır.
**Kabul kriterleri:**
- **AC-8.1:** Verildiğinde bugünkü merkez depo stoğunu gösteren bir ekran (ODAK stok, kategori çeşit depo kolonu, ölü stok depo bileşeni, satış analizi, satınalma), Yapıldığında ekran açıldığında, O zaman gösterilen stok, aynı anda bağımsız sorgulanan canlı WMS satılabilir stoğuna (raf + giriş alanı) birebir eşittir. (02.10.2026: ODAK stok ay sonu görüntüsünden 4.249.866 adet gösteriyordu; canlı WMS 3.628.661 adet.)
- **AC-8.2:** Verildiğinde aynı gün ve aynı ürün, Yapıldığında AC-8.1'deki ekranların ikisinde merkez depo stoğu okunduğunda, O zaman iki değer birebir eşittir.
- **AC-8.3:** Verildiğinde geçmiş bir ayın merkez depo bakiyesini gösteren ekran ya da kolon, Yapıldığında ekran açıldığında, O zaman değerin yanında ay sonu görüntüsünün tarihi gg.aa.yyyy biçiminde yazılıdır, kaynaktaki görüntü tarihine eşittir ve değer o tarihin görüntüsüne birebir eşittir.
- **AC-8.4:** Verildiğinde istenen ay için ay sonu görüntüsü bulunmuyor, Yapıldığında geçmiş bakiye istendiğinde, O zaman ekran başka bir ayın değerini göstermez; "Bu ay için stok görüntüsü yok." der.

### H9 — Sınav ödeme sağlık kartı aynı neti verir (P3)
GMY olarak Sınav Okulları sayfasında ödeme sağlık kartının net tutarını KPI'daki net tutarla aynı görmek istiyorum, böylece bir faturanın birden çok siparişe tam tutarla yazılması rakamı şişirmez.
**Bağımsız test:** Eylül 2026 kart toplamı ile KPI neti karşılaştırılır.
**Kabul kriterleri:**
- **AC-9.1:** Verildiğinde Eylül 2026, Yapıldığında ödeme sağlık kartındaki net tutarlar toplandığında, O zaman toplam aynı sayfadaki KPI net tutarına 1,00 TL toleransla eşittir.
- **AC-9.2:** Verildiğinde birden çok siparişe bağlı tek fatura, Yapıldığında kart hesaplandığında, O zaman fatura tutarı toplamda bir kez sayılır ve iade, KPI'daki iade bağıyla aynı kurala göre işaretlenir.

### H10 — Hata durumunda ekran çökmez, teknik ayrıntı sızmaz (P3)
GMY olarak bir sorgu hata verdiğinde anlaşılır bir Türkçe mesaj görmek istiyorum, böylece ekranda bağlantı ya da SQL ayrıntısı görmem.
**Bağımsız test:** Bu spec'te dokunulan ekranlarda veri kaynağı erişilemez yapılır ve ekran metni okunur.
**Kabul kriterleri:**
- **AC-10.1:** Verildiğinde Sabah, Envanter, Operasyon, Satınalma analiz, Eşikler ve Vardiya ekranları, Yapıldığında veri kaynağı hata döndürdüğünde, O zaman ekranda sunucu adı, SQL metni ya da istisna metni görünmez; ne olduğunu ve ne yapılacağını söyleyen Türkçe mesaj görünür.
- **AC-10.2:** Verildiğinde AC-10.1'deki hata, Yapıldığında hata oluştuğunda, O zaman teknik ayrıntı uygulama günlüğüne yazılır; günlükte hatanın oluştuğu ekran ve zaman bulunur.
- **AC-10.3:** Verildiğinde ürün kodu sayıya çevrilemeyen bir POS ürün kaydı, Yapıldığında kategori detay, hediye çeki, Ana sayfa kategori, mağaza detayı ve Sınav ekranları açıldığında, O zaman ekran hata vermez ve o kayıt yalnız ürün eşleşmesi dışında kalır. (02.10.2026: bu tür kayıt sayısı 0; risk gizli.)

### H11 — Satış analizi ürün detayından geri dönüş doğru sayfaya gider (P3)
GMY olarak sezon aksiyon listesinden açtığım ürün detayından geri döndüğümde sezon aksiyon listesine dönmek istiyorum.
**Bağımsız test:** Sezon aksiyon → ürün detay → Geri akışı denenir.
**Kabul kriterleri:**
- **AC-11.1:** Verildiğinde sezon aksiyon listesinden açılmış ürün detayı, Yapıldığında **Geri** seçildiğinde, O zaman sezon aksiyon listesi açılır (bugün geçersiz bir satış analizi adresine gidiyor).
- **AC-11.2:** Verildiğinde satış analizi listesinden açılmış ürün detayı, Yapıldığında **Geri** seçildiğinde, O zaman satış analizi listesi açılır.

### H12 — Mizan nakit göstergesi doğru hesapları toplar (P3)
GMY olarak mizan özetinde nakit ve KDV pozisyonunu doğru hesap gruplarıyla görmek istiyorum.
**Bağımsız test:** Kapanmış bir ay için gösterge, aynı hesap kümesiyle bağımsız toplanan mizan bakiyesiyle karşılaştırılır.
**Kabul kriterleri:**
Kullanıcı kararı (03.10.2026): alınan çekler (101) nakitten ayrı gösterilir; devreden KDV (190) KDV pozisyonuna eklenir.
- **AC-12.1:** Verildiğinde kapanmış son ay, Yapıldığında nakit göstergesi hesaplandığında, O zaman değer alınan çekleri (101) içermez ve nakit hesap kümesinin bağımsız mizan toplamına 1,00 TL toleransla eşittir.
- **AC-12.2:** Verildiğinde aynı ay, Yapıldığında mizan özeti açıldığında, O zaman alınan çekler nakitten ayrı bir gösterge olarak görünür ve değeri 101 hesabının bağımsız mizan bakiyesine 1,00 TL toleransla eşittir.
- **AC-12.3:** Verildiğinde aynı ay, Yapıldığında KDV pozisyonu hesaplandığında, O zaman değer devreden KDV'yi (190) içerir ve bu hesap kümesinin bağımsız mizan toplamına 1,00 TL toleransla eşittir.

### H13 — Ana sayfa mağaza neti perakende ve Sınav ayrımıyla okunur (P3)
GMY olarak Ana sayfada mağaza netini perakende ve Sınav Okulları ayrı satırlarda, altında toplamla görmek istiyorum; hedef karşılaştırmasının tabanı henüz teyitli değilse bunu ekranda görmek istiyorum.
Kullanıcı kararı (03.10.2026): perakende ve Sınav ayrı satır, altında toplam. Hedef tabanı plan aşamasında bir kapalı ay üzerinden ölçülüp önerilir; teyit gelene kadar ekranda not durur.
**Bağımsız test:** Eylül 2026 Ana sayfa mağaza satırları kanonik şube cirosu ve Sınav Okulları belge toplamıyla karşılaştırılır.
**Kabul kriterleri:**
- **AC-13.1:** Verildiğinde Eylül 2026 ve bir mağaza, Yapıldığında Ana sayfa mağaza neti gösterildiğinde, O zaman "Perakende" ve "Sınav Okulları" ayrı satırlarda, altında "Toplam" satırıyla görünür ve Perakende + Sınav Okulları = Toplam eşitliği 1,00 TL toleransla sağlanır.
- **AC-13.2:** Verildiğinde Eylül 2026, Yapıldığında Sınav Okulları satırı gösterildiğinde, O zaman değer o mağazanın Sınav Okulları belgelerinden bağımsız hesaplanan KDV hariç nete 1,00 TL toleransla eşittir.
- **AC-13.3:** Verildiğinde Eylül 2026 ve üç mağaza, Yapıldığında Toplam satırları toplandığında, O zaman sonuç kanonik şube cirosuna %0,30 toleransla eşittir (02.10.2026 ölçümü: panel 469.938.584 TL, kanonik 470.550.331 TL, fark −%0,13; fark geri dönüşüm fişlerinin dışlanmasından).
- **AC-13.4:** Verildiğinde hedef tabanı GMY tarafından henüz teyit edilmemiş, Yapıldığında Ana sayfada hedef ile gerçekleşen yan yana gösterildiğinde, O zaman karşılaştırmanın yanında "Hedef tabanı teyit bekliyor" notu görünür.
- **AC-13.5:** Verildiğinde hedef tabanı teyit edilmiş, Yapıldığında hedef karşılaştırması gösterildiğinde, O zaman "teyit bekliyor" notu görünmez ve hedef ile gerçekleşen teyit edilen tabanda (KDV, Sınav, merkez depo kapsamı) hesaplanır; gerçekleşen değer o tabanda bağımsız hesaplanan değere 1,00 TL toleransla eşittir.

### H14 — Stok göstergeleri kullandığı tanımı söyler (P3)
GMY olarak "ölü stok", "aşırı stok" ve "stokta yokluk" göstergelerinin yanında o ekranın hangi tanımı kullandığını okumak istiyorum, böylece iki ekran farklı rakam verdiğinde sebebini anlarım.
Kullanıcı kararı (03.10.2026): kavramların tek tanıma indirilmesi spec 003'e ertelendi; 001'de yalnız tanımı açıklayan kısa metin eklenir.
**Bağımsız test:** Her stok göstergesinin açıklama metni, göstergenin hesabında kullanılan süre ve eşikle karşılaştırılır.
**Kabul kriterleri:**
- **AC-14.1:** Verildiğinde Envanter, Satış analizi, Sezon aksiyon ve Satınalma analiz ekranlarında ölü stok, aşırı stok ya da stokta yokluk göstergesi, Yapıldığında ekran açıldığında, O zaman her göstergenin yanında (ipucu ya da dipnot) o ekranın tanımını anlatan en fazla iki cümlelik Türkçe metin görünür.
- **AC-14.2:** Verildiğinde AC-14.1'deki açıklama metni, Yapıldığında metin göstergenin hesabıyla karşılaştırıldığında, O zaman metinde geçen her süre, eşik ve kapsam (gün sayısı, kat, mağaza/depo) hesapta kullanılan değerle birebir aynıdır.

## Düşük öncelikli bulgular (toplu)

Tek başına değer üretmeyen, aynı turda kapanacak düzeltmeler. Her biri kendi doğrulamasıyla:
- **D-1:** Müşteri ömür boyu değeri (LTV) özetindeki "Kartsız" etiketi, anonim (yürü-gel) müşteriyi kapsamadığını açıkça söyler. RFM segment cirosu iade düşülmüş tutarla hesaplanır.
- **D-2:** Ana sayfa saat yoğunluğu, kasiyer tablosu ve kategori karması, mağaza netiyle aynı kapsamı kullanır (geri dönüşüm fişi, mağaza kümesi). Eylül 2026 kasiyer toplamı, Ana sayfa mağaza netine 1,00 TL toleransla eşittir.
- **D-3:** E-ticaret "Baskısı yok" sekmelerindeki tutarlar "KDV dahil" etiketi taşır.
- **D-4:** Hediye çeki barem tablosunda brüt, indirim ve net aynı KDV tabanındadır; "brüt − indirim = net" 1,00 TL toleransla sağlanır.
- **D-5:** Gün karşılaştırma ve tahmin/hedef gerçekleşme ekranları kullandıkları ciro tabanını (KDV dahil/hariç, kaynak) dipnotta yazar.

## Sınır durumlar
- Dönemde hiç fiş, sipariş ya da hareket yoksa: ekran sıfır değil "Bu dönemde kayıt yok" der; tolerans karşılaştırması "ölçülemedi" sayılır, "tuttu" sayılmaz.
- Doğrulama sırasında ERP ya da e-ticaret kaynağına bağlanılamazsa: kabul kriteri "geçti" değil "koşamadı" olarak raporlanır.
- Açık gün (bugün) için kıyas yapılmaz; kasa→ERP aktarımı saatlik olduğundan fark beklenir.
- İstenen geçmiş ay için ay sonu stok görüntüsü yoksa: ekran başka ayın değerini göstermez, "Bu ay için stok görüntüsü yok." der (AC-8.4).
- Canlı WMS'e bağlanılamazsa: bugünkü merkez depo stoğu yerine ay sonu görüntüsü sessizce gösterilmez; H10'daki hata mesajı görünür.
- Düzeltme sonrası rakam GMY'nin dün gördüğünden farklıdır: bkz. FR-013.

## Fonksiyonel gereksinimler
- **FR-001:** Sistem kampanya indirim tutarlarını fiş başına bir kez sayılmış, iade düşülmüş olarak hesaplamak ZORUNDADIR (H1).
- **FR-002:** Sistem win-back listesine son 90 günde satış fişi olan müşteriyi almamak ZORUNDADIR (H2).
- **FR-003:** Sistem bugünkü merkez depo stoğunu her ekranda canlı WMS satılabilir stoğundan okumak ZORUNDADIR; ERP defteri merkez depo için kullanılmaz (H3, H8).
- **FR-004:** Sistem e-ticaret ciro ve adetlerinde iptal ve iade edilmiş sipariş ve satırları her ekranda aynı kuralla hariç tutmak ZORUNDADIR (H4).
- **FR-005:** Sistem "fiş" sayısını tek bir tanımla hesaplamak ve bu tanımı her ekranda kullanmak ZORUNDADIR: yalnız perakende satış fişi, geri dönüşüm (1001) fişi hariç; iade ayrı sayı olarak gösterilir (H5, H6).
- **FR-006:** Sistem aynı tabloda ya da kartta gösterilen brüt, indirim, net ve iade tutarlarını tek KDV tabanında hesaplamak ZORUNDADIR (H6, D-4).
- **FR-007:** Sistem satış tutarı ve adet toplamlarında iadeyi düşmek, iptal edilmiş kalemi saymamak ZORUNDADIR (H6, H7, D-1).
- **FR-017:** Sistem kategori marjında maliyeti kayıtlı olmayan satışların cirosunu düşürmeden "maliyetsiz ciro" olarak ayrı göstermek, marj yüzdesini yalnız maliyetli ciro üzerinden hesaplamak ve maliyeti bilinen ciro yüzdesini göstermek ZORUNDADIR (H7; GMY kararı 04.10.2026).
- **FR-008:** Sistem geçmiş ay merkez depo bakiyesini ay sonu görüntüsünden okumak ve görüntünün tarihini değerin yanında göstermek ZORUNDADIR (H8).
- **FR-009:** Sistem bir faturanın tutarını, kaç siparişe bağlı olursa olsun, toplamda bir kez saymak ZORUNDADIR (H9).
- **FR-010:** Sistem dokunulan ekranlarda hata metnini kullanıcıya göstermemek, Türkçe açıklayıcı mesaj göstermek ve teknik ayrıntıyı günlüğe yazmak ZORUNDADIR (H10).
- **FR-011:** Sistem sayıya çevrilemeyen ürün kodlu POS kaydında ekranı çökertmemek ZORUNDADIR (H10).
- **FR-012:** Sistem her düzeltme için önce ve sonra değerini, dönemi ve kanıt sorgusunu proje sorgu arşivinde saklamak ZORUNDADIR.
- **FR-013:** GMY, değeri bu spec ile değişen rakamın değiştiğini ÖĞRENEBİLMELİDİR: göstergenin yanında "Hesap düzeltildi (gg.aa)" notu 30 gün görünür ve değişiklik oturum günlüğüne (journal) yazılır (AC-0.1, AC-0.2).
- **FR-016:** Sistem ana sayfada hedef tabanı teyit edilene kadar hedef karşılaştırmasının yanında "Hedef tabanı teyit bekliyor" notunu göstermek ZORUNDADIR (H13).
- **FR-014:** Sistem yeni öğrenilen veri kuralını (tanım, köprü, kod) proje semantik katmanına yazmak ZORUNDADIR.
- **FR-015:** Sistem bu spec kapsamında hiçbir ERP, POS ya da e-ticaret verisini değiştirmemek ZORUNDADIR; düzeltmeler yalnız panelin okuma ve gösterme davranışını değiştirir.

## Yetki
| Rol | Yapabilir | Yapamaz |
|---|---|---|
| GMY (tek panel kullanıcısı, oturum açmış) | Düzeltilmiş rakamları, veri tarihini ve uyarıları görmek; Excel'e dökmek | ERP, POS, e-ticaret verisini bu ekranlardan değiştirmek; düzeltme tanımlarını ekrandan değiştirmek |
| Oturum açmamış ziyaretçi | Giriş sayfasını görmek | Bu spec'teki hiçbir ekranı ve rakamı görmek |
| Panel uygulaması | ERP/POS/e-ticaret kaynaklarını okumak | Bu spec kapsamında ERP'de herhangi bir tabloya yazmak (izinli iki uygulama tablosu bu spec'te kullanılmaz) |

Yetki modeli değişmiyor (tek kullanıcı).

## Anahtar varlıklar
- **Satış fişi / iade belgesi / fatura / personel belgesi / Sınav Okulları belgesi:** kasa belgesi türleri; fiş sayımına ve ciroya hangisinin girdiği kurallarla belirlenir.
- **Fiş kalemi:** fişteki ürün satırı; geçerli ya da iptal edilmiş olabilir.
- **Kampanya indirimi:** bir kaleme uygulanan indirim; fiş başlığındaki toplamla aynı tutarı ikinci kez temsil eder.
- **Müşteri:** kartlı (kayıtlı ve kartı var), kayıtlı kartsız, anonim (yürü-gel).
- **E-ticaret siparişi ve sipariş satırı:** her biri iptal/iade durumu taşır.
- **Merkez depo stoğu:** WMS satılabilir stok (canlı ya da ay sonu görüntüsü, tarihli).
- **Şube cirosu:** üç mağazanın satış − iade (mağaza satışı dahil) net tutarı, KDV hariç.
- **Maliyetli ciro / maliyetsiz ciro:** satılan malın maliyeti kayıtlı olan ve olmayan satışların cirosu; ikisinin toplamı kategori cirosudur.
- **Kanıt kaydı:** düzeltme, dönem, önce değeri, sonra değeri, bağımsız değer, sorgu.

## Veri kaynağı ve ortam
- Hedef veritabanları: ERP DerinSISBkm (compat 150) · POS EncoreMerkez (compat 110) · Sınav BKM (compat 150) · hedef BKMDATA (compat 150) · müşteri DerinCrm (compat 150) · e-ticaret JOKER (compat 150). Ölçüm: `docs/proje/veritabani.md`, 03.10.2026.
- Dış sistemler: e-ticaret bağlantılı sunucu ODAKJOKER (compat 150, K2). Tümü salt-okuma.
- Doğrulama ortamı: canlı ERP sunucusu 192.168.40.201, son kapalı ay.

## Başarı kriterleri
- **SC-001:** H1–H9'daki her düzeltilmiş rakam, Eylül 2026 için bağımsız kanonik sorguyla belirtilen tolerans içinde eşleşir; sonuç "tuttu / saptı / koşamadı" etiketiyle raporlanır ve "saptı" kalan kalem yoktur.
- **SC-002:** Düzeltilen her rakam için önce, sonra ve bağımsız değer ile kanıt sorgusu arşivdedir (H1–H9 ve D-1–D-5 için %100).
- **SC-003:** Win-back listesi ile son 90 günün satış fişleri kesişimi 0 müşteridir.
- **SC-004:** FSM Eylül 2026 fiş sayısı Ana sayfa, Trafik ve Sadakat ekranlarında aynıdır.
- **SC-005:** Dokunulan ekranlarda hata metni kullanıcıya gösterilen yer sayısı 0'dır.
- **SC-006:** Daha önce tutan rakamlar (Eylül 2026 üç şube net cirosu, e-ticaret sipariş sayısı ve net ciro) düzeltmeden sonra da aynı değeri verir.
- **SC-007:** Projenin mevcut değişmez denetimleri düzeltme sonrası yeşildir; kırılan değişmez yoktur.

## Kapsam dışı
- Mobil görünüm, yerleşim, gezinme ve PWA (spec 002).
- Yeni rapor ve yeni gösterge (spec 003). Kumbara ve manuel indirimin ekranda gösterilmesi 003'teki indirim ve kasa kontrolü raporuna devredildi (H1).
- "Ölü stok", "aşırı stok" ve "stokta yokluk" kavramlarının tek tanıma indirilmesi ve ekranlar arası aynı ürün kümesini vermesi (spec 003'e devir; 001'de yalnız tanım açıklaması, H14).
- Hedef tabanının kesin seçimi: plan aşamasında bir kapalı ay üzerinden ölçülüp GMY'ye önerilir; teyit bu spec'in teslimini beklemez (H13 notla çalışır).
- BT-FIKRI kurulumu, HTTPS ve servis (spec 004).
- ERP, POS ya da e-ticaret verisine yazma; yeni tablo; SQL Agent job; ay sonu stok görüntüsünü otomatik dolduran iş.
- Yetki modeli değişikliği.
- Dokunulmayan ekranlardaki eski kural ihlalleri (K1: borç olarak kalır).
- Sonucu değiştirmeyen kod kuralı bulguları (tarih biçimi, sıfır kontrolü yazımı, karakter karşılaştırma kuralı): plan aşamasında dokunulan kodda ele alınır, kullanıcı-görünür davranış değişmez.
- Stok tutarı (₺) doğrulaması: denetimde ölçülecek sorgu bulunmadı.

## Varsayımlar
- Doğrulama tabanı Eylül 2026 ve canlı ERP'dir; ölçümler 02.10.2026 denetiminden alınmıştır, plan aşamasında yeniden ölçülür.
- "Son 90 gün" ve "son 365 gün" listenin üretildiği güne göre sayılır.
- Merkez depo satılabilir stoğu = raf alanı + giriş alanı (çıkış alanı hariç); proje kuralıyla aynı.
- İade, satış tutarından düşülür (proje belge kuralı); fatura ve personel belgeleri ciroya girer, müşteri raporlarına girmez.
- Ana sayfadaki geri dönüşüm fişi dışlaması geçerli bir iş kuralıdır; kanonik şube cirosundan farkı (%0,08–1,28 bandı) kabul edilir. Fiş sayımında da aynı fişler hariçtir (kullanıcı kararı).
- Ana sayfa "Perakende" satırı satış fişi ve iadeyle birlikte fatura ve personel belgelerini de taşır; "Sınav Okulları" satırı yalnız Sınav Okulları belgelerini taşır. Böylece iki satırın toplamı bugünkü mağaza netine eşit kalır. (Fatura ve personel tutarı küçük: FSM Eylül 2026'da 484 belge.)
- Hedef tabanı teyit edilene kadar hedef karşılaştırması bugünkü hesabıyla ve "teyit bekliyor" notuyla gösterilir.
- Kumbara ve manuel indirim hesabı 001'de düzeltilir ve doğrulanır, ekranda gösterilmez (kullanıcı kararı).
- Canlı WMS stoğu ekran açıldığı andaki stoktur; ekranlar arası eşitlik (AC-8.2) aynı dakika içinde okunan değerler için aranır.
- Değişiklik notunun 30 günü, düzeltmenin yayına alındığı günden sayılır.
- Panel için otomatik davranış testi yazılır (test-discipline: sabit değer değil ilişki/eşitlik testi).
- Tutarlarda 1,00 TL tolerans satır başı yuvarlamayı karşılar.

## Kontrol listesi
- [x] Açık belirsizlik işareti kalmadı (10 soru kullanıcı tarafından 03.10.2026'da cevaplandı)
- [x] Her AC Verildiğinde/Yapıldığında/O zaman biçiminde ve test edilebilir
- [x] NASIL detayı yok (tablo/sınıf/endpoint adı, teknoloji)
- [x] Yetki negatifleri yazılı
- [x] Kapsam dışı yazılı
