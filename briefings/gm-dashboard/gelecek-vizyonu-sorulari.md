# GM Dashboard — Gelecek Vizyonu & Terleten Rakam Seti Soruları

**Hedef Kitle:** Fikri Eren (Genel Müdür Yardımcısı / CFO / İcra)  
**Tarih:** 9 Ekim 2026  
**Konum:** `briefings/gm-dashboard/gelecek-vizyonu-sorulari.md` ve `docs/gm-dashboard-gelecek-vizyonu-sorulari.md`  
**Amaç:** Klasik statik ciro/satış panosunu aşarak; **nakit akışı, tedarikçi tavizi, gizli marj erozyonu, stok sermaye tuzağı ve işgücü verimsizliği** alanlarında yöneticileri ve departman liderlerini terletecek, doğrudan aksiyona ve karar almaya zorlayacak soru setleri ve veri göstergeleri.

---

## 1. Nakit Akışı, Likidite & Kasa Stresi (Finans & Cari)
>
> *"Ciro yapıyoruz ama kasadaki nakit nerede?"*

| # | Terleten Soru | Bakılacak Rakam Seti / Metrik | Neden Terletir? / Ne Gösterir? |
|---|---|---|---|
| **N-01** | **Nakit Dönüşüm Süresi (CCC) kaç gün açıldı?** | `Stokta Kalma Günü (DIO) + Alacak Tahsilat Günü (DSO) - Tedarikçi Ödeme Günü (DPO)` | Şirket kendi faaliyetini finanse edemeyip banka kredisine veya faize mi koşuyor? |
| **N-02** | **Alırken mi ödüyoruz, satıp mı ödüyoruz?** | Tedarikçi bazında `Ortalama Ödeme Vadesi (Gün)` vs. `Ürünlerin Ortalama Satış/Tükenme Günü` | Vadesi 45 gün olan ürün rafta 120 gün bekliyorsa aradaki 75 günü BKM finanse ediyor demektir. |
| **N-03** | **Cironun ne kadarı POS komisyonu ve banka blokajında eriyor?** | Brüt ciro vs. Kasa/Banka net geçen tahsilat, taksit maliyeti ve bloke çözülme günleri | Ciro yüksek görünürken net nakde dönüşüm oranındaki kaçakları ortaya koyar. |
| **N-04** | **Şüpheli alacaklar ve vadesi geçmiş kurumsal bakiyeler nakit akışını ne kadar tıkıyor?** | Vadesi 30+ / 60+ / 90+ gün geçen kurumsal B2B cari alacak toplamı ve teminat karşılığı | Tahsil edilmemiş satışın kârı sanaldır; gerçek nakit riskini gösterir. |

---

## 2. Satınalma, Alış Fiyatı Sapması & Tedarikçi Disiplini
>
> *"Doğru fiyattan mı alıyoruz, yoksa tedarikçi mi bizi yönetiyor?"*

| # | Terleten Soru | Bakılacak Rakam Seti / Metrik | Neden Terletir? / Ne Gösterir? |
|---|---|---|---|
| **S-01** | **Aynı ürünü farklı tedarikçilerden farklı fiyata mı alıyoruz?** | Son 12 ayda 2+ tedarikçiden alınan SKU'larda: `(Maksimum Alış Fiyatı - Minimum Alış Fiyatı) / Min Fiyat` ve toplam adet etkisi | Alıcının fiyat kontrolü yapmadığını veya tedarikçi kayırdığını saniyede ortaya çıkarır. |
| **S-02** | **Satış düşerken sipariş miktarı artan (şişirilen) ürünler hangileri?** | Son 3 ayda satış trendi negatif olan ama depoya giriş (irsaliye) adedi artan SKU'lar ve alıcı isimleri | Satınalmacının kotayı doldurmak veya tedarikçiyle anlaşmak için stoğu boğduğu vakaları yakalar. |
| **S-03** | **Alırken anlaşılan iskonto faturaya yansıdı mı, yoksa liste fiyatından mı geçirildi?** | Sözleşme/anlaşma iskonto yüzdesi vs. `fatAyr` gerçekleşen net iskonto oranı sapması | İskonto kaçağını ve fatura kontrol zafiyetini gösterir. |
| **S-04** | **İade edilemeyen ve depoda çürüyen malların faturası kime çıkıyor?** | İade hakkı olmayan (`frmIadeKural`) tedarikçilerden alınan ve 180 gündür satılmayan stok tutarı | Depoda biriken ölü stoğun satınalma kararı hatası olduğunu yüzleştirir. |

---

## 3. Gizli Marj Erozyonu & Kampanya Sahtekarlığı (Satış & Kârlılık)
>
> *"Ciro rekoru kırarken kâr marjımız nereye buharlaştı?"*

| # | Terleten Soru | Bakılacak Rakam Seti / Metrik | Neden Terletir? / Ne Gösterir? |
|---|---|---|---|
| **M-01** | **Hangi ürünlerde ciro artarken kâr tutarı (₺) düştü?** | SKU ve kategori bazında: `Adet Büyümesi %` vs. `Brüt Kâr Tutarı (₺) Değişimi %` | Şirketin maliyetine mal satarak ciro illüzyonu yarattığı ürünleri gösterir. |
| **M-02** | **3 Al 2 Öde ve sepet kampanyaları gerçekten kâr ettirdi mi, yoksa marjı mı kemirdi?** | Kampanyalı sepet marjı (%) vs. Kampanyasız normal sepet marjı (%) ve net sepet kârı (₺) | 3 Al 2 Öde'de müşterinin en pahalı ürünleri sepete koyup marjı eksiye düşürdüğü sepetleri deşifre eder. |
| **M-03** | **Personel indirimi veya yetkili iskontoları suistimal ediliyor mu?** | Kasa bazında: Yetkili/Personel iskontosu oranı, sepet başı indirim tutarı ve standart dışı tenzilatlar | Kasada yapılan keyfi veya kontrolsüz indirim kaçaklarını ortaya koyar. |
| **M-04** | **İadeler hangi kanaldan kârı geri alıyor?** | Net Ciro içindeki Brüt İade Oranı (%), iade edilen ürünlerin giriş maliyeti ve iade sebebi dağılımı | Satış yapıldı sanılan ama operasyonu yoran ve marjı sıfırlayan iade dalgasını gösterir. |

---

## 4. Stok Verimsizliği, Atıl Sermaye & Kayıp Satış (Envanter & WMS)
>
> *"Raflar dolu ama müşteri aradığını bulamıyor mu?"*

| # | Terleten Soru | Bakılacak Rakam Seti / Metrik | Neden Terletir? / Ne Gösterir? |
|---|---|---|---|
| **E-01** | **Merkez depoda bekleyip mağaza rafında olmadığı için kaç milyon TL kaybettik?** | Merkez depoda stoğu >10 olan ama mağazada stoğu 0 olan gün sayısı × günlük ortalama satış hızı (Kayıp Satış ₺) | Mağaza-depo lojistik kopukluğunun sebep olduğu ciro kaybını kuruşuna kadar ölçer. |
| **E-02** | **Ölü sermaye (90+ gündür satılmayan stok) toplam stoğun yüzde kaçı?** | `Hiç Hareketsiz Stok Maliyeti / Toplam Stok Maliyeti` (%) ve bunun kategori/mağaza kırılımı | Şirket sermayesinin ne kadarının raflarda tozlandığını ve likiditeyi kilitlediğini gösterir. |
| **E-03** | **Aynı ürün X şubesinde yok satarken Y şubesinde 6 aydır bekliyor mu?** | Şubeler arası zıt satış temposu: X şubesinde stok 0 & talep var vs. Y şubesinde stok >20 & satış 0 | Şubeler arası ikmal ve ters transfer mekanizmasının çalışmadığını kanıtlar. |
| **E-04** | **Stok devir hızı 1'in altında olan kaç bin çeşit ürün taşıyoruz?** | Yıllık devir hızı < 1,0 olan SKU sayısı, kapladığı raf hacmi ve toplam bağlı para | Katalog genişliği bahanesiyle çöplüğe dönen ürün çeşitliliğini sorgulatır. |

---

## 5. İşgücü, Mağaza Verimliliği & Gizli Maliyetler (İK & Operasyon)
>
> *"Her mağaza ve personel kendi maliyetini çıkarıyor mu?"*

| # | Terleten Soru | Bakılacak Rakam Seti / Metrik | Neden Terletir? / Ne Gösterir? |
|---|---|---|---|
| **O-01** | **Çalışılan saat başına ciro (SPLH) mağazalar arasında neden 2 kat farklı?** | Mağaza bazında `Toplam Net Ciro / PDKS Gerçek Çalışılan Saat` (₺ / saat) | Hangi mağazanın veya vardiyanın gereğinden fazla kadroyla atıl çalıştığını gösterir. |
| **O-02** | **Kasa yoğunluğunun olmadığı saatlerde mağazada kaç personel boş bekliyor?** | Saatlik kasa fiş/işlem adedi eğrisi vs. Saatlik mağaza personel varlığı eğrisi | Vardiya planlamasının müşteri trafiğine göre değil, ezbere yapıldığını gösterir. |
| **O-03** | **Personel devir oranı (Turnover) ve kayıp işgücünün maliyeti ne?** | İlk 6 ayda ayrılan personel oranı, işe alım maliyeti ve ayrılma sebeplerinin şube kırılımı | Mağaza yönetim zafiyetini ve sürekli eğitim/işe alım masrafını ortaya koyar. |
| **O-04** | **Depo koli/ürün toplama maliyeti ürün başına kaça geliyor?** | WMS operatör başına saatlik toplama satır/koli adedi ve birim ürün başına düşen iç lojistik maliyeti | Merkez deponun operasyonel verimliliğini ve sevkiyat darboğazlarını ölçer. |

---

## 6. GM Dashboard İçin Uygulama Yol Haritası (Panel Bileşenleri)

Bu soruları `briefings/gm-dashboard` veya Blazor `/dashboard` içine entegre ederken önerilen 4 ana alarm göstergesi:

1. **"Nakit / Sermaye Alarmı" Kartı:**
   * Kilitli Stok ₺ Tutarı, Vadesi Geçen Alacak ₺ Tutarı, Ortalama Nakit Dönüşüm Süresi (Gün).
2. **"Tedarikçi Kaçağı & Alış Sapması" Tablosu:**
   * Aynı üründe farklı fiyatla alınan ilk 10 ürün ve toplam ceza/fark maliyeti.
3. **"Kayıp Satış (Bulunurluk)" Sayacı:**
   * Depoda var ama rafta yokken kaybedilen bu haftaki tahmini ciro (₺).
4. **"Verimsiz Kadro / Mağaza SPLH" Karşılaştırması:**
   * FSM vs. Özlüce vs. İst.Yolu çalışılan saat başına ciro (₺/saat) ve fazla mesai sapmaları.
