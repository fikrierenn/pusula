# E-Ticaret Grup Şirketi İçin Terleten Yönetim & Denetim Soru Seti

**Hedef Kitle:** E-Ticaret Şirketi Genel Müdürü / E-Ticaret Direktörü / CFO / İcra Kurulu  
**Hazırlayan:** Fikri Eren (Grup CFO / GMY)  
**Tarih:** 9 Ekim 2026  
**Kapsam:** JOKER / E-Ticaret Platformu Veri Seti (`J_ORDERS`, `J_ORDER_DETAILS`, `J_ORDER_CLIENTS`, `J_CARGO`, `J_ORDER_STATUS`, `ODAK fulfillment`)  
**Amaç:** "Bugün kaç sipariş aldık, ciromuz ne kadar" yüzeyselliğini yıkarak; **kargo sübvansiyonu, iade/iptal lojistiği, sepet başı net marj erozyonu, müşteri edinme maliyeti (CAC) kaçağı ve tedarik/fulfillment darboğazlarını** sorgulatan, e-ticaret yönetimini doğrudan terletecek stratejik sorular.

---

## 1. Kargo, Fulfillment & Gizli Lojistik Sübvansiyonu
>
> *"Siparişi alıp paketleyip müşteriye ulaştırdığımızda cebimize gerçekten ne kalıyor?"*

| # | Terleten Soru | Bakılacak Rakam Seti / Metrik | Neden Terletir? / Ne Gösterir? |
|---|---|---|---|
| **E-01** | **Müşteriden tahsil edilen kargo ile kargo firmasına (MNG, HepsiJet vb.) ödenen fatura arasındaki fark (şirket sübvansiyonu) aylık kaç milyon TL?** | `SUM(J_ORDERS.CARGOPRICE) - Kargo Firmaları Gerçek Fatura Toplamı` ve sepet baremi (örneğin "500 TL üzeri kargo bedava") maliyet etkisi | Ücretsiz kargonun yarattığı ciro illüzyonunun şirketin brüt kârını nasıl yuttuğunu kuruşuna kadar gösterir. |
| **E-02** | **Kargo desi/ağırlık uyuşmazlığı yüzünden kargo firmalarının kestiği ceza/ek fatura ne kadar?** | Sistemdeki desi hesabı vs. Kargo firması faturasındaki gerçek kesilen fatura tutarı | Hatalı ürün ağırlığı veya paketleme yüzünden her ay kargo firmalarına ödenen gizli kaçakları yakalar. |
| **E-03** | **Kapıda Ödeme (COD) siparişlerinin teslim edilmeyip geri dönme oranı nedir ve bize çift yönlü kargo maliyeti kaça patlıyor?** | `PAYDEFREF = -3` (Kapıda ödeme) siparişlerinde: `Teslim Edilmeyen / İade Dönen Sipariş Oranı %` ve gidiş+dönüş kargo zararı | Kapıda ödeme siparişlerinin aslında kârlı değil, büyük bir lojistik zararı olduğunu ortaya koyar. |
| **E-04** | **Sipariş verildiği andan kargoya verilene kadar geçen ortalama süre (Fulfillment SLA) kaç gün ve iptallerin ne kadarı bu gecikmeden kaynaklanıyor?** | `ORDERDATE` ile `Kargoya Veriliş Tarihi` arasındaki saat/gün farkı ve kargoya verilemeden gelen müşteri iptal oranı | ODAK/fulfillment deposunun operasyonel hız yetersizliğinden kaybedilen müşterileri ve ciroyu gösterir. |

---

## 2. İptal, İade & Çöp Lojistiği (Sipariş Kalitesi)
>
> *"Kayıtlarda görünen cironun ne kadarı aslında kargo yollarında gezip geri dönüyor?"*

| # | Terleten Soru | Bakılacak Rakam Seti / Metrik | Neden Terletir? / Ne Gösterir? |
|---|---|---|---|
| **I-01** | **Brüt sipariş cirosunun yüzde kaçı iptal (`1006`) ve iade (`1007`) ile buharlaşıyor?** | `Netleşen Ciro / Brüt Sipariş Cirosu` (%) ve kategori/yazar/ürün bazında iade yoğunluğu | Ciro rekoru kırdık denilen haftaların aslında %15-20'sinin iade ve operasyonel maliyetle çöpe gittiğini yüzleştirir. |
| **I-02** | **"Temin Edilemeyen Ürün" yüzünden kısmi bölünen veya iptal edilen siparişlerin oranı nedir?** | Tedarik edilemediği için sepetten düşen satırlar (`IPTALNO > 0`) ve müşteri sepeti iptal etme oranı | Sanal stoğun gerçek depoyla uyuşmadığını, satılan malın aslında rafta olmadığını deşifre eder. |
| **I-03** | **İade gelen ürünlerin depoya ulaştıktan sonra tekrar satışa açılma (yeniden raflama) süresi kaç gün?** | İade kargo teslim tarihi vs. Ürünün tekrar stokta `AVAILABLE` olma tarihi | İade edilen ürünlerin depoda haftalarca kör noktada bekleyip değer kaybettiğini gösterir. |

---

## 3. Kampanya, Kupon (Voucher) & Sepet Erozyonu
>
> *"İndirim kuponuyla satış yapmak kolay, peki net kâr nerede?"*

| # | Terleten Soru | Bakılacak Rakam Seti / Metrik | Neden Terletir? / Ne Gösterir? |
|---|---|---|---|
| **K-01** | **Hediye çeki ve kupon kodu (`VOUCHERCODE`) kullanılan siparişlerde net sepet marjı yüzde kaça düştü?** | Kuponlu sipariş brüt kâr marjı (%) vs. Normal sipariş kâr marjı (%), "1 TL'lik kitap" zararı | Pazarlamanın dağıttığı indirim çeklerinin şirket marjını sıfırlayıp sadece kargo zararı ürettiği durumları yakalar. |
| **K-02** | **Ödeme sistemleri (iyzico vb.) komisyonları ve taksit vade farkı kime yazılıyor?** | `SERVICEPRICE` (vade farkı) tahsilatı vs. iyzico komisyon kesintisi ve taksit maliyet dengesi | Şirketin müşteriye taksit sunarken banka komisyonunu kendi kârından sübvanse edip etmediğini gösterir. |
| **K-03** | **Sepet büyüklüğü 250 TL altındaki siparişler operasyonel olarak zararda mı?** | Küçük sepetlerde: `Brüt Marj - (Kargo Maliyeti + Koli/Paketleme + iyzico Komisyonu + Depo Toplama)` | Düşük tutarlı siparişlerin şirkete her bir pakette net para kaybettirdiğini netleştirir. |

---

## 4. Kanal Dinamikleri (Mobil App vs. Web) & Müşteri Bağlılığı
>
> *"Reklamla gelen müşteri ikinci kez sipariş veriyor mu?"*

| # | Terleten Soru | Bakılacak Rakam Seti / Metrik | Neden Terletir? / Ne Gösterir? |
|---|---|---|---|
| **C-01** | **Mobil App kullanıcıları ile Web/Mobil Site kullanıcılarının sepet kârlılığı ve tekrar alışveriş (Retention) sıklığı farkı nedir?** | Kanal kırılımında: Ortalama sepet tutarı (AOV), brüt marj ve 90 günlük sipariş tekrar sıklığı | App'in gerçekten sadık ve kârlı kitle mi getirdiğini, yoksa sadece bildirimle ucuza indirim kovalayan kitle mi olduğunu ayrıştırır. |
| **C-02** | **Son 1 yılda ilk siparişini veren müşterilerin (New Customer) kaçı son 6 ayda tekrar sipariş verdi?** | `CUSTOMERREF` bazlı kohort retention (Kohort analizi: 1. ay, 3. ay, 6. ay tekrar gelme oranı %) | Reklam bütçesinin "tek seferlik müşterilere" harcanıp çöpe mi gittiğini, yoksa kalıcı müşteri mi yarattığını sorgulatır. |
| **C-03** | **Müşteri Edinme Maliyeti (CAC), o müşterinin 1 yıllık Yaşam Boyu Değeri (LTV) ile karşılaştırıldığında kârlı mı?** | `Toplam Dijital Pazarlama / Yeni Müşteri Sayısı` vs. `Müşterinin 12 Aylık Kümülatif Brüt Kârı` | Pazarlamanın müşteri kazanmak için harcadığı paranın, müşterinin bıraktığı brüt kârdan fazla olduğu kör noktaları gösterir. |

---

## 5. Tedarik, Sanal Stok & Fiyatlama Disiplini
>
> *"Sitede satılan fiyat ile tedarikçiden alış fiyatımız uyuşuyor mu?"*

| # | Terleten Soru | Bakılacak Rakam Seti / Metrik | Neden Terletir? / Ne Gösterir? |
|---|---|---|---|
| **T-01** | **Sitede satışı yapılan ama tedarikçide fiyatı arttığı için eksi/zararına marjla satılan ürünler var mı?** | `J_ORDER_DETAILS.SELLINGPRICE` vs. Tedarikçinin son güncel alış fiyatı | Güncellenmeyen katalog fiyatları yüzünden her gün zararına satılan kitap ve ürünleri tespit eder. |
| **T-02** | **Sitede 'Stokta Var' görünen ama depoda fiziksel karşılığı olmadığı için günlerce tedarik bekletilen SKU oranı nedir?** | Sipariş sonrası "Tedarikçiden Bekleniyor" durumuna düşen satır sayısı ve ortalama tedarik gecikme süresi | E-ticaretin sanal stok disiplinsizliğini ve müşteri şikayetlerinin kök sebebini ortaya koyar. |
