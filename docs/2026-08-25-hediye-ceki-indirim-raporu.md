# Hediye Çeki — Kârlılık, İndirim Oranı ve İndirim Tavanı

**Tarih:** 25.08.2026 · **Hazırlayan:** Pusula analitik · **Kapsam:** 01.08.2025 – 31.07.2026 (12 ay)
**Kaynak:** DerinSIS `irsHrk` (kanal/çek satışı) + `fatAyr`/`fat` (fatura indirimi, fat5 maliyet) + EncoreMerkez POS (sepet/kullanım)
**Sorgu arşivi:** [`sorgular/2026-08-25-hediye-ceki-karlilik-indirim.sql`](../sorgular/2026-08-25-hediye-ceki-karlilik-indirim.sql)

> **Sürüm notu.**
> **v2 — iki hata düzeltildi:** (1) maliyet `UrunBilgi.SonAlis` ile hesaplanmıştı — kanonik yöntem **son 5 alış faturası ortalaması (fat5)**; marj %27,3 → **%32,4**. (2) Çek satışı yalnız POS'tan sayılmıştı — çekler **DerinSIS satış faturasıyla da** satılıyor ve asıl kanal orası; "1,19 M₺ yükümlülük açığı" bulgusu **geçersiz**, gerçek tablo pozitif bakiye.
> **v6 — panel kanonik oldu.** Analiz dashboard'a taşındı (`/hediye-ceki`, plan-36). Panel marjı **ürün bazlı** fat5 ile hesaplıyor; bu belgedeki §7 barem marjları **kategori-ortalama** yaklaşımıydı ve 1–2 puan yüksek çıkıyor (2.500 ₺+ marj %37,4 → **%35,5**, kırılma %38,4 → **%36,2**). Panel rakamları esastır. **Tavan önerisi (%15) değişmiyor** — %15, %36,2 kırılmanın hâlâ çok altında. §6'da iki kategori satırı da panelde biraz farklı: blok 12 geri dönüşüm filtresinden ÖNCE yazılmıştı, panel filtreli.
> **v5 — alternatif enstrüman:** İndirim yerine **hediye çeki fazlası (bonus)** teklifi değerlendirildi (§9). Sonuç: aynı kupürde verilirse **matematiksel olarak indirimle aynı**; avantaj yalnız bonus **küçük kupürlerde** verilirse doğuyor — o zaman %15 bonus, %15 indirime göre brüt kârı **%52 artırıyor** ve kırılma noktası ortadan kalkıyor. Ama tek bir tasarım kuralına bağlı: *tek fişte en fazla 1 bonus çek*.
> **v4 — sonuç DEĞİŞTİ:** (5) **Barem analizi** (çek dilimi × ortalama sepet × marj) eklendi ve önceki "kitap senaryosu bağlayıcı" tezimi **çürüttü**: büyük çek dilimlerinde kitap payı %9'a iniyor, marj %37,4'e çıkıyor → kırılma noktası %15,2 değil **%38,4**. Tavan önerisi **%10 → %15**. (6) İNALLAR/GÖNYE **aynı grubun 3 şirketi** (kullanıcı teyidi + ortak adres) → konsolide edildi; "indirim–hacim ters ilişkisi" yorumu da düzeltildi.
> **v3 — iki açık kapatıldı:** (3) **geri dönüşüm çekleri** ayıklandı — hediye çekli sepette sıfır çıktı, dolayısıyla marj ve kaldıraç etkilenmedi; kirlenen yalnız kontrol grubuydu (indirim oranı %18,83 → **%18,74**). (4) **`fatAyr` eTip=4 tutarsızlığı** çözüldü: mağaza satışında `ehTutarN` beslenmiyor — çek-özel değil, 4 yıllık genel bir tuzak (§10).

---

## 1. Özet — Tek Cümlelik Cevap

Hediye çeki nominali üzerinden **tavan %15**; kademeli ve sözleşmeli olmak kaydıyla. Gerekçe: büyük çek dilimlerinde gerçekleşen marj **%37,4** ve kırılma noktası **%38,4** — %15 indirimde nominal 1 ₺ başına **+0,234 ₺** brüt kâr kalıyor, yani marjın yaklaşık üçte ikisi korunuyor.

**Bugün fiilen %15 veriliyor** — tek bir müşteri grubuna (İNALLAR/GÖNYE, 3 şirket, 480.000 ₺). Bu oran **savunulabilir**; asıl sorun oranın yüksekliği değil, **kuralın olmaması**: aynı dönemde en büyük ikinci ve üçüncü alıcı (250.000 ₺ ve 227.550 ₺) **%0** ödemiş, indirim bütçesinin **%78'i tek gruba** gitmiş.

| Karar sorusu | Cevap | Bölüm |
|---|---|---|
| Çekle alışverişte müşteri fazladan indirim mi kullanıyor? | **Hayır** — çekli sepette %18,07, normal sepette %18,74 | §5 |
| Çekli sepet daha mı büyük? | **Evet, 2,03×** (1.621 ₺ vs 798 ₺ brüt/fiş) | §5 |
| Çekin harcandığı sepetin marjı? | **%32,4 ortalama** — ama dilime göre %28,2 → **%37,4** | §6, §7 |
| Bugün çekte indirim veriyor muyuz? | **Evet, ortalama %4,99** — dağılım %0–15, kuralsız | §4 |
| Verilebilecek tavan? | **%15** (kademeli: %8 / %12 / %15) | §8 |
| İndirim yerine çek fazlası verilse? | **Daha iyi — ama sadece küçük kupürde.** %15 bonus / 50-100 ₺ kupür → brüt kâr %52 artıyor | §9 |

## 2. Neden bu rapor

Müşteri, hediye çeki alırken çekin **nominal değeri üzerinden** indirim istiyor (ör. 1.000 ₺'lik çeki 900 ₺'ye). Cevap tek bir zincire bağlı: çek satışı hasılat değil **avans**dır (KDV = 0). Kâr, çekin mağazada harcandığı anda doğar. Nominalden verilen indirim ise doğrudan o kârdan düşer. Dolayısıyla sorulacak soru "çeki kaça satalım" değil, **"çek harcandığında geride ne kalıyor"**dur.

---

## 3. Çek hangi kanaldan satılıyor

Çek üç kanaldan çıkıyor ve **POS azınlık kanal**. Tek doğru ölçüm yeri DerinSIS `irsHrk` (hareket tipi bazlı); POS'a bakıp karar vermek hacmi ~3 kat eksik gösterir.

| Kanal (hareket tipi) | Net ₺ | Pay |
|---|---|---|
| **Satış faturası** (`ehTip 1`) — kurumsal/toplu | **1.750.480** | **%54,7** |
| POS Satış (`ehTip 100`) — kasa | 1.124.278 | %35,2 |
| Mağaza Satış (`ehTip 4`) | 323.550 | %10,1 |
| **Brüt satış** | **3.198.307** | |
| İadeler (`3` + `5` + `101`) | −137.379 | |
| **Net satılan çek** | **3.060.928** | |

Ayrıca kanal dışı hareketler: **Diğer Giriş (`88`) 2.219.570 ₺** = çek basımı / stok girişi (satış değil), **Diğer Çıkış + Şirket İçi Kullanım (`89`+`98`) 122.000 ₺** = imha, merkeze iade ve kişiye hediye (bedelsiz — 16 kaydın notları tek tek okundu).

**Kupürler:** 50 / 100 / 200 / 500 / 750 / 1.000 ₺ + açık tutarlı "HEDİYE ÇEKİ" (`stkID 551353`, `fiyatS = 0` — fatura kanalının ana kalemi, 849.420 ₺). Hacim 1.000 ₺ ve 500 ₺'de yoğun.

---

## 4. Bugün ne veriyoruz — politika yok, pazarlık var

Fatura kanalında indirim **zaten uygulanıyor**: brüt 1.842.370 ₺ üzerinden 91.890 ₺, ortalama **%4,99**. Ortalama yanıltıyor; dağılım kuralsız.

**Grup konsolidasyonu şart.** İNALLAR OTOMOTİV, İNALLAR SİGORTA ve GÖNYE OTOMOTİV **aynı grubun üç şirketi** (kullanıcı teyidi; üçü de Ovaakça Çeşmebaşı / İstanbul Cad. adresinde). Ayrı `frmID` oldukları için tek tek bakınca üç orta ölçekli müşteri görünüyorlar — konsolide edildiğinde **en büyük alıcı** oluyorlar.

| # | Alıcı (grup) | Brüt ₺ | İndirim ₺ | Oran | Brüt payı | İndirim payı |
|---|---|---|---|---|---|---|
| 1 | **İNALLAR / GÖNYE grubu** (3 şirket) | **480.000** | **72.000** | **%15,0** | %26,0 | **%78,4** |
| 2 | BURSA KÜLTÜR MERKEZİ *(grup-içi)* | 316.500 | 0 | %0 | %17,1 | — |
| 3 | HPA PLASTİK | 250.000 | 0 | **%0** | %13,6 | — |
| 4 | EPSAN PLASTİK | 227.550 | 0 | **%0** | %12,3 | — |
| 5 | OSKİM OTOMOTİV | 172.000 | 7.140 | %4,15 | %9,3 | %7,8 |
| 6 | ULUDAĞ ONKOLOJİ DERNEĞİ | 150.000 | 7.500 | %5,0 | %8,1 | %8,2 |
| 7 | BURSA TİCARET VE SANAYİ ODASI | 105.000 | 5.250 | %5,0 | %5,7 | %5,7 |
| 8 | ASİYE BİNGÖLBALİ *(ilişkili? aynı bina)* | 66.000 | 0 | %0 | %3,6 | — |
| — | Diğer 8 alıcı (24.000 ₺ ve altı) | 75.320 | 0 | %0 | %4,1 | — |
| | **Toplam** | **1.842.370** | **91.890** | **%4,99** | | |

**Bulgu:** kademe yok. Tek bir gruba %15 verilmiş, iki büyük alıcı tam fiyat ödemiş, ortada iki-üç müşteri %4–5 almış. Fiyat merkezî bir kurala değil **görüşmeyi kimin yaptığına** bağlı. İndirim bütçesinin **%78,4'ü tek müşteri grubunda** — konsantrasyon riski.

> **Bayraklar.** (a) `frm.frmBagID` ve `frmGrup1..5` alanları **hepsinde 0** — ERP'de grup alanı var ama kullanılmıyor; müşteri grup haritası olmadan her analiz elle konsolide etmek zorunda. (b) ÇETİN ELEKTRİK ve ÇETİN PROJE (mağaza satışı kanalında, 6.500 ₺) muhtemelen aynı grup — teyit gerekiyor, karar etkisi yok. (c) ASİYE BİNGÖLBALİ, Bursa Kültür Merkezi ile aynı iş merkezinde (Sönmez İş Sarayı) — ilişkili taraf olabilir, teyit gerekiyor. (d) Grup-içi taraflar piyasa fiyatı kıyasına girmez, ayrı kovada tutulur.

## 5. "Çekli müşteri üstüne indirim de alıyor" — veri çürütüyor

Aşağıdaki kıyas **geri dönüşüm ayıklanmış** haliyle. Geri dönüşüm iadeleri kontrol grubunda 10.850 fiş / 1,92 M₺ tutuyordu; çıkarılınca kontrol grubu 1.129.750 fişe iniyor.

| Ölçü | Hediye çekli fiş | Normal fiş |
|---|---|---|
| Fiş sayısı | 2.855 | 1.129.750 |
| Brüt ciro ₺ | 4.628.592 | 901.050.460 |
| İndirim ₺ | 836.208 | 168.884.474 |
| **İndirim oranı** | **%18,07** | %18,74 |
| Brüt / fiş ₺ | **1.620,9** | 797,6 |

Çekli sepette ürün indirimi **0,67 puan daha düşük**, sepet **2,03× daha büyük**. Çek indirim avcılığı değil, sepet büyütme davranışı üretiyor. (Ayıklama öncesi rakamlar %18,08 / %18,83 ve 2,05× idi — sonuç yönü değişmiyor.)

### Geri dönüşüm çekleri neden bu analizde yok

Geri dönüşüm, kasada **iade sebebi** olarak işliyor: `RefundReasons.Id = 12 "Geri Dönüşüm"` (21.07.2025'te açılmış), ürünü `stkID 583160 "Geri Dönüşüm Kağıt Madde Alımı"` (kilo bazlı). 12 ayda **10.850 fiş / 368.269 kg / 1.923.399 ₺**.

Karşılığında verilen çek **İADE ÇEKİ** (`PaymentTypesId = 10`) — 10.679 hareket / 1.733.514 ₺. Hediye çeki tahsilatında (tip 11) **hiç görünmüyor**; tip 11'in %100'ü hediye kartı bayraklı, tek bir iade-çeki kaydı yok.

**Hediye çekli sepette geri dönüşüm sıfır** — hem sebep kodu hem ürün kodu üzerinden ayrı ayrı doğrulandı. Bu yüzden §6 marjı ve §7 kaldıracı geri dönüşümden etkilenmiyor; yalnız kontrol grubu kirliydi ve yukarıda düzeltildi.

> **Ayıklama iki koşullu olmak zorunda:** `RefundReasonId <> 12` **ve** `Products.Code <> '583160'`. Sebep kodu güvenilmez — geri dönüşüm ürünü 416 satırda yanlış sebeple (Fiyat Avantajı / Müşteri Memnuniyetsizliği / Hasarlı Ürün / Hatalı Satış) ve 12 satırda iade değil **satış** fişiyle geçmiş.

**Bakiye:** net satılan 3.060.928 − kullanılan 2.589.048 = **+471.880 ₺** kullanılmamış çek (üstüne 122.000 ₺ bedelsiz çıkış). Yükümlülük tarafı pozitif ve normal.

---

## 6. Çek nereye harcanıyor, ne bırakıyor

Maliyet **kanonik yöntemle**: son 5 alış faturası ortalaması — `SUM(ehTutarN)/SUM(ehAdetN)`, `fatAyr`+`fat` (`eTip=0`, `eDurum<>2`) ve ODAK faturaları birleşik, tarih çıpası 31.07.2026. Kapsama %99.

| Kategori | Brüt ₺ | İndirim % | Marj % | Brüt kâr ₺ |
|---|---|---|---|---|
| Kırtasiye | 1.707.175 | 16,2 | **45,3** | 557.620 |
| Eğitim / Sınavlara Hazırlık | 737.721 | 20,2 | 24,7 | 145.341 |
| Hobi ve Oyuncak | 632.231 | 5,7 | **37,0** | 184.130 |
| Edebiyat Kitapları | 562.197 | 27,2 | **14,3** | 58.340 |
| Çocuk Kitapları | 431.201 | 27,4 | **14,7** | 45.816 |
| Hediyelik | 126.472 | 16,8 | **44,8** | 38.749 |
| İslam Kitapları | 94.624 | 29,6 | 24,0 | 15.663 |
| Elektronik | 43.352 | 14,4 | 38,2 | 11.798 |
| Süpermarket | 39.138 | 7,1 | 33,1 | 11.111 |
| **TOPLAM** | **4.624.125** | **18,1** | **32,4** | **1.117.505** |

Kritik dağılım: **kırtasiye/oyuncak/hediyelik %37–45, kitap %14–15.** Çekin nereye harcandığı sonucu ikiye katlıyor.

> **Yöntem notu.** Aynı sepet `UrunBilgi.SonAlis` (tek son alış) ile %27,3 çıkıyordu; fat5 ile %32,4. Fark 5,1 puan — tek faturaya bakmak enflasyonda maliyeti yukarı çekiyor. Kanonik olan fat5'tir (`sema/metrics.yaml` → `birim_maliyet.MLYT`). FIFO (`BKMMaliyet`) ile çapraz mutabakat yapılamadı: o veritabanı MCP izin listesinde değil — açık iş.

---

## 7. Baremli kârlılık — çek dilimi × ortalama sepet × marj

Bu tablo kararın merkezi. Her satır bir çek büyüklüğü baremi; marj o baremin **gerçek kategori mixinden** hesaplandı (kategori marjları §6'daki fat5 değerleri).

| Barem | Fiş | Ort. çek ₺ | Ort. sepet ₺ | Kaldıraç | Sepet indirimi | **Marj** | Brüt kâr / fiş ₺ | **Kâr / 1 ₺ çek** | Kitap payı |
|---|---|---|---|---|---|---|---|---|---|
| ≤ 100 ₺ | 275 | 61 | 655 | **10,66×** | %18,2 | %28,2 | 176 | **2,858** | %22,9 |
| 101–250 ₺ | 465 | 186 | 737 | 3,96× | %19,4 | %28,8 | 200 | 1,076 | %25,4 |
| 251–500 ₺ | 788 | 448 | 870 | 1,94× | %18,9 | %29,4 | 237 | 0,529 | %32,0 |
| 501–1.000 ₺ | 786 | 907 | 1.329 | 1,47× | %18,1 | %31,1 | 379 | 0,418 | %27,0 |
| 1.001–2.500 ₺ | 382 | 1.815 | 2.221 | 1,22× | %17,1 | %35,6 | 714 | 0,393 | %15,8 |
| **2.500 ₺ +** | 159 | 3.813 | 4.344 | **1,14×** | %17,6 | **%37,4** | **1.463** | **0,384** | **%9,2** |
| **Ortalama** | 2.855 | 865 | 1.328 | 1,54× | %18,1 | %32,6 | 396 | 0,458 | — |

### Üç şey birlikte okunuyor

1. **Kaldıraç çek büyüdükçe çöküyor** (10,66× → 1,14×). Küçük çek kapıdan içeri sokan kupon; büyük çek birebir harcanıyor, nakit tamamlama yok.
2. **Ama marj tersine yükseliyor** (%28,2 → %37,4) — çünkü **kitap payı %23'ten %9'a iniyor**. Büyük çek sahipleri kırtasiye ve oyuncak alıyor, kitap değil.
3. **Kâr/fiş büyük çekte en yüksek** (1.463 ₺ vs 176 ₺). Kâr/1 ₺ çek düşüyor (2,858 → 0,384) ama **hiçbir baremde tehlikeli seviyeye inmiyor**.

### Kırılma noktası — önceki tezim çürüdü

| Barem | Kırılma (gerçek mix) | Kitap payı |
|---|---|---|
| ≤ 100 ₺ | %285,8 | %22,9 |
| 101–250 ₺ | %107,6 | %25,4 |
| 251–500 ₺ | %52,9 | %32,0 |
| 501–1.000 ₺ | %41,8 | %27,0 |
| 1.001–2.500 ₺ | %39,3 | %15,8 |
| **2.500 ₺ +** | **%38,4** | %9,2 |

**v3'te "bağlayıcı kısıt kitap senaryosu, kırılma %15,2" demiştim — barem verisi bunu çürüttü.** O senaryo büyük çekin tamamının kitaba gitmesini varsayıyordu; gerçekte 2.500 ₺+ dilimde kitap payı **%9,2**. Kırılma noktası %15,2 değil **%38,4**.

Neden kitap senaryosu gerçekleşmiyor: kurumsal alıcı çeki personeline/öğrencisine dağıtıyor, alıcı ne alacağını çekin indirim oranından bağımsız seçiyor. Yani indirim verilince mixin kitaba kayması beklenmez — davranışsal bağ yok.

### Nominal 1 ₺ başına kalan brüt kâr

| Barem | %0 | %5 | %8 | %10 | %15 | %20 |
|---|---|---|---|---|---|---|
| ≤ 100 ₺ | 2,858 | 2,808 | 2,778 | 2,758 | 2,708 | 2,658 |
| 101–250 ₺ | 1,076 | 1,026 | 0,996 | 0,976 | 0,926 | 0,876 |
| 251–500 ₺ | 0,529 | 0,479 | 0,449 | 0,429 | 0,379 | 0,329 |
| 501–1.000 ₺ | 0,418 | 0,368 | 0,338 | 0,318 | 0,268 | 0,218 |
| 1.001–2.500 ₺ | 0,393 | 0,343 | 0,313 | 0,293 | 0,243 | 0,193 |
| **2.500 ₺ +** | 0,384 | 0,334 | 0,304 | 0,284 | **0,234** | 0,184 |

%15'te en zayıf baremde bile **0,234 ₺** kalıyor — marjın %61'i korunuyor. %20'de 0,184 ₺ (marjın %48'i).

> **Yöntem notu.** Barem marjı, dilimin kategori mixi × kategori fat5 marjı ile hesaplandı (kategori-içi ürün mixi farkı ihmal edildi). Dilim × ürün bazında doğrudan fat5 koşumu MCP'de 30s'yi aştı — sqlcli ile tekrarlanabilir.

## 8. Öneri

1. **Tavanı %15'te sabitle, kademeli uygula.** Kural merkezî olsun, görüşmeye bırakılmasın:

   | Nominal | Tavan | Gerekçe (2.500 ₺+ barem, kırılma %38,4) |
   |---|---|---|
   | < 2.500 ₺ — perakende tek çek | **%0** | Kaldıraç 1,47×–10,66×, talep de yok; indirim karşılıksız bedel |
   | 2.500 – 24.999 ₺ | **%8** | Kalan kâr 0,304 ₺/₺ |
   | 25.000 – 99.999 ₺ | **%12** | Kalan kâr 0,264 ₺/₺ |
   | 100.000 ₺ + | **%15** | Kalan kâr 0,234 ₺/₺ — marjın %61'i |

   %15 üstü GMY onayına tabi. %20'ye kadar teknik olarak pozitif (0,184 ₺/₺) ama marjın yarısını verir — ancak stratejik hacim taahhüdüyle.

2. **İNALLAR/GÖNYE grubunun %15'i korunur.** v3'teki "sıfır kâr sınırında" değerlendirmesi geçersiz; grubun 480.000 ₺'lik alımı %15 indirimle bile ≈ **112.000 ₺ net brüt kâr** bırakıyor (480.000 × 0,234). Ama bundan sonra bu oran **kurala bağlı** olmalı, kişiye özel değil — grup 100.000 ₺+ kademesine doğal olarak giriyor.

3. **Tam fiyat ödeyen büyük alıcılara kademeyi teklif et.** HPA (250.000 ₺) ve EPSAN (227.550 ₺) bugün %0 ödüyor ve yeni kurala göre %15 hakkı doğacak — bu karşılıksız kayıp değil, **hacim büyütme kozu**: indirim karşılığında yıllık taahhüt iste. Aksi hâlde kuralın kendisi bir maliyet kalemi olur.

4. **Kitap payını çeyreklik izle.** Tavan, 2.500 ₺+ baremde kitap payının **%9,2** olmasına dayanıyor. Bu pay %25'e çıkarsa kırılma %38,4'ten ~%25'e iner ve %15 tavanı daralır. İzleme metriği: barem-6 kitap payı ve gerçekleşen marj.

5. **Süre koşulu koy.** Geçerlilik süresi (ör. 12 ay) hem kullanılmayan çek hem bilanço yükümlülüğü açısından lehimize; indirimin karşılığı olarak masaya konabilir.

6. **Müşteri grup haritasını ERP'ye gir.** `frmBagID` (veya `frmGrup1`) bugün boş. Grup kodu girilmezse her kademe kararı elle konsolidasyona bağlı kalır ve aynı grup üç ayrı kademeden indirim alabilir. Satınalma tarafındaki grup-içi tedarikçi listesi deseninin müşteri karşılığı.

7. **Muhasebeye kayıt biçimini teyit ettir.** İndirimli çek satışında avans nominal mi tahsilat mı yazılacak, kullanım anındaki hasılat ve KDV nasıl doğacak. Bu rapor kâr etkisini ölçer, kayıt biçimini belirlemez.

## 9. Alternatif: indirim yerine hediye çeki fazlası (bonus)

Soru: nominalden indirim vermek yerine "100.000 ₺ öde, 115.000 ₺ çek al" demek daha iyi mi?

### 9.1 Aynı kupürde verilirse fark yok — bu bir muhasebe illüzyonu değil, kimlik

Müşteri açısından iki teklif, satın alma gücü eşitlendiğinde aynıdır:

- **İndirim x:** 1 ₺ nakit → `1/(1−x)` ₺ çek yüzü
- **Bonus b:** 1 ₺ nakit → `1+b` ₺ çek yüzü
- Eşitlik: **`b = x/(1−x)`** → %15 indirim ≡ **%17,65 bonus**

Bizim açımızdan da, bonus **aynı kupürde** verilirse sonuç birebir aynı çıkıyor. 1 ₺ nakit başına brüt kâr:

| | Formül | %15 senaryosu |
|---|---|---|
| İndirim | `(r − x) / (1 − x)` | 0,283 |
| Bonus, aynı kupür | `r + b(r − 1)` | 0,283 |

(`r` = o kupürün 1 ₺ çek yüzü başına brüt kârı; 2.500 ₺+ basılı kupürde 0,391.)

**Yani "indirim değil bonus verelim" tek başına bedava öğle yemeği değil.** Avantaj başka üç yerden geliyor.

### 9.2 Avantaj 1 — kupür küçültme (asıl kaldıraç)

Bonusun hangi kupürde verildiği her şeyi değiştiriyor. Aşağıdaki oranlar **yalnız basılı kupürlerden** (yuvarlak tutarlı çekler) hesaplandı — kısmi bakiye artıkları ayıklandı, çünkü bir bonus programı basılı kupür ihraç eder:

| Kupür | Fiş | Çek ₺ | Kaldıraç | Marj | **Kâr / 1 ₺ çek** |
|---|---|---|---|---|---|
| 50 / 100 ₺ | 28 | 2.500 | **4,75×** | %28,2 | **1,228** |
| 200 ₺ | 185 | 40.750 | 3,30× | %28,8 | 0,872 |
| 500 ₺ | 664 | 309.700 | 1,86× | %29,4 | 0,501 |
| 1.000 ₺ | 744 | 685.050 | 1,45× | %31,1 | 0,414 |
| 1.001–2.500 ₺ | 377 | 685.650 | 1,22× | %35,6 | 0,398 |
| 2.500 ₺ + | 158 | 602.950 | 1,14× | %37,4 | 0,391 |

50–100 ₺ kupürde **kâr/1 ₺ çek = 1,228 > 1**. Yani o kupürün yüzü bize maliyetinden fazla kâr getiriyor — çünkü müşteri 100 ₺ çekle 475 ₺'lik sepet alıyor, üstünü nakit tamamlıyor.

**Sonuç: bonus küçük kupürde verilirse kırılma noktası ortadan kalkıyor** — bonus arttıkça kâr artıyor.

1 ₺ nakit başına brüt kâr, bonus hangi kupürde verilirse:

| İndirim eşdeğeri | Bonus | İndirim | Bonus 50/100 ₺ | Bonus 200 ₺ | Bonus 500 ₺ | Bonus aynı kupür |
|---|---|---|---|---|---|---|
| %5 | %5,3 | 0,359 | 0,403 | 0,384 | 0,365 | 0,359 |
| %10 | %11,1 | 0,323 | 0,416 | 0,377 | 0,336 | 0,323 |
| %15 | %17,6 | **0,283** | **0,431** | 0,368 | 0,303 | 0,283 |
| %20 | %25,0 | 0,239 | 0,448 | 0,359 | 0,266 | 0,239 |

%15 indirim yerine eşdeğer bonusu 50–100 ₺ kupürde vermek brüt kârı **0,283 → 0,431**, yani **%52** artırıyor.

### 9.3 Avantaj 2 — aynı başlık, daha az maliyet

`b = x/(1−x)` olduğu için bonus rakamı hep indirimden büyük görünür. Bu, aynı "%15" başlığıyla daha az vermeyi mümkün kılıyor:

- **%15 bonus**, müşteri gözüyle **%13,04 indirime** eşittir → 1,96 puan tasarruf, aynı iletişim.
- Tersi: **%15 indirimi karşılamak için %17,65 bonus** gerekir → daha büyük rakam söyleyip aynı parayı verirsin.

### 9.4 Avantaj 3 — maliyet kesin değil, koşullu (+ nakit)

İndirimde verilen nakit anında ve kesin gider. Bonus çek yüzü **kullanılmazsa maliyeti sıfırdır.** Mevcut kullanılmamış bakiye 471.880 ₺ — satışın ~%15'i. Bonus yüzünün bir kısmı da kullanılmayacaktır; bu tarafta indirimin karşılığı yok.

Nakit akışı da farklı: 480.000 ₺'lik alımda %15 indirim 408.000 ₺ nakit getirir, %15 bonus 480.000 ₺ — **72.000 ₺ fazla nakit, bugün.**

### 9.5 480.000 ₺ ölçeğinde (İNALLAR/GÖNYE grubu)

| Teklif | Alınan nakit ₺ | Verilen çek yüzü ₺ | **Brüt kâr ₺** |
|---|---|---|---|
| %15 indirim | 408.000 | 480.000 | **115.667** |
| %15 bonus — aynı büyük kupür | 480.000 | 552.000 | 143.817 |
| %15 bonus — 200 ₺ kupür | 480.000 | 552.000 | 178.416 |
| **%15 bonus — 50/100 ₺ kupür** | 480.000 | 552.000 | **204.106** |

En iyi tasarım, indirime göre **+88.439 ₺** (+%76) brüt kâr bırakıyor. (Aynı büyük kupürdeki 143.817 ₺ de indirimden yüksek, ama bu eşdeğer teklif değil — %15 bonus müşteriye %13,04 indirim değerinde.)

### 9.6 Bunu bozacak tek şey: arbitraj

**Avantajın tamamı "bonus küçük sepette harcanır" varsayımına dayanıyor.** Kurumsal alıcı 10 adet 100 ₺ çeki tek kişiye verir ve o kişi hepsini tek fişte harcarsa, sepet 2.500 ₺+ barem davranışına döner: kâr/1 ₺ çek 1,228'den 0,391'e çöker ve bonusun indirime üstünlüğü sıfırlanır.

> **Zorunlu tasarım kuralı: tek fişte en fazla 1 bonus çek kullanılabilir.** Bu kural POS'ta zorlanmazsa bonus, adı değişmiş bir indirimdir.

İkinci koruma: bonus çeke **süre sınırı** (12 ay) — hem breakage'ı hem bilanço yükümlülüğünü yönetir.

### 9.7 Öneri ve uyarılar

**Teklif edilecek yapı:** 100.000 ₺+ alımda **%15 bonus**, yalnız 50 ₺ ve 100 ₺ kupürlerde, tek fişte 1 çek kuralı, 12 ay geçerlilik. Bu, %13 indirim maliyetiyle %15 başlığı verir ve iyi senaryoda indirime göre %52 daha yüksek brüt kâr bırakır.

**Ama üç uyarı, hepsi ciddi:**

1. **Kanıt zayıf.** 50–100 ₺ basılı kupür kaldıracı (4,75×) yalnız **28 fiş / 2.500 ₺**'ye dayanıyor. Bu, karar için yeterli örneklem değil — mertebe göstergesi. Ayrıca §7'deki 10,66× rakamı bu tasarımda **kullanılamaz**: o, 247 fişlik **kısmi bakiye artığı** davranışıydı (müşteri zaten alışverişteydi, çek artığını kullandı), tasarımla üretilemez.
2. **Popülasyon farklı.** Bugün küçük çek kullananlar perakende müşteri; bonus çeki alan kurumsal hediye alıcısı olacak. Davranışın aynı olacağı varsayımı test edilmedi.
3. **Muhasebe teyidi şart.** Bonus, alınan nakitten büyük bir yükümlülük yaratıyor (480.000 nakit / 552.000 çek yüzü). İhraç anında promosyon gideri mi, kullanım anında hasılat indirimi mi? Bilanço yükümlülüğü de büyüyor. Bu rapor kâr etkisini ölçer, kayıt biçimini belirlemez.

**Bu yüzden: pilot.** Tek grupta 3 ay, 50/100 ₺ bonus + tek-fiş kuralı. Ölçülecek: bonus çeklerin gerçek kaldıracı, tek-fiş kuralının tutup tutmadığı, kullanılmama oranı. Pilot 4,75×'i doğrularsa kalıcı politika; doğrulamazsa §8'deki düz indirim kademesine dönülür.

---

## 10. Yöntem ve sınırlar

- **Kanal/çek satışı** DerinSIS `irsHrk` (`ehTrhS` tarihli, `ehTutarN` KDV-hariç, hareket tipi `irsTip_vw`). POS-only ölçüm hacmi ~3 kat eksik gösterir — v1'in hatası buydu.
- **Sepet/kullanım** EncoreMerkez POS: perakende fiş (`DocumentsTypeId` 1 satış, 3 iade ters işaretli). Fatura (2), Personel (6/7) ve Sınav Okulları (8) sepet analizinden hariç — Sınav'da 12 fiş / 68.533 ₺ çek kullanımı var ve sepeti 7,2× kaldıraçlı, kurumsal nitelikte.
- **Geri dönüşüm çekleri ayıklandı** (§5): `RefundReasonId <> 12` **ve** `Products.Code <> '583160'`. Hediye çekli sepette sıfır; kontrol grubundan çıkarıldı. Hediye çeki SKU'larındaki bedelsiz çıkışlar (122.000 ₺) tek tek okundu: imha, merkeze iade, kişiye hediye — geri dönüşüm değil.
- **Ciro** KDV-hariç net. **İndirim** POS tarafında yalnız `DiscountTotalDirect` (kampanya kolonu alt kümedir, toplanırsa çift sayar); fatura tarafında `ehIndirim`.
- **Maliyet** kanonik fat5: son 5 alış faturası `SUM(ehTutarN)/SUM(ehAdetN)`, DerinSIS + ODAK birleşik, `eTip=0`, `eDurum<>2`, tarih çıpası pencere sonu. Kapsama %99. Hediye çeki kalemleri marj hesabından çıkarıldı — stok değil, avans.
- **Ürün köprüsü** `Products.Code (int) = urn.stkID`. Barkod/`stkKod` eşleşmesi kullanılmadı (kategori kaçırma riski).
- **Veri tutarsızlığı — çözüldü, §11.** `fatAyr` eTip=4'te `ehTutarN` beslenmiyor; kanal toplamlarında `irsHrk` esas alındı (doğru olan o).
- **Ölçülmeyen:** kanibalizasyon (çek alan müşteri o alışverişi zaten yapacak mıydı), kullanılmayan çekin nihai kaderi (süre sınırı yok), kategori bazlı FIFO mutabakatı.
- **Bonus (§9) hesabı** basılı-kupür (yuvarlak tutarlı) kaldıraçlarına dayanır; kısmi bakiye artıkları ayıklandı. 50–100 ₺ kupür oranı yalnız 28 fiş / 2.500 ₺ örnekleme dayanıyor — mertebe göstergesi, karar kanıtı değil.
- **Grup konsolidasyonu elle yapıldı** — ERP'de grup alanı boş. İNALLAR/GÖNYE birleştirmesi kullanıcı teyidi + ortak adres kanıtına dayanır; vergi numarası öneki grup kanıtı DEĞİLDİR (ÇETİN çifti bu yüzden "teyit bekliyor" olarak işaretlendi).
- **Barem marjı** dilim kategori mixi × kategori fat5 marjı ile hesaplandı; kategori-içi ürün mixi farkı ihmal edildi. Dilim × ürün bazında doğrudan fat5 koşumu MCP'de zaman aşımına uğradı.
- **Kaldıraç bir korelasyondur, nedensellik iddiası değildir.** "Çek büyütünce kaldıraç düşer" denmiyor; "büyük çek dilimindeki müşteri nakit tamamlama yapmıyor" deniyor.


---

## 11. İki veri kalitesi bulgusu (hediye çeki dışında da geçerli)

### 11.1 `fatAyr` eTip=4 → `ehTutarN` beslenmiyor

Çek kanalını ölçerken çıktı: fatura satırlarında mağaza satışı brüt 323.550 ₺ görünürken net 6.000 ₺ yazıyordu. Sebep **hediye çekine özel değil, genel bir tuzak.**

Ocak 2026, tüm ürünler, hareket tipi kıyası — `ehTutar` dolu ama `ehTutarN = 0` olan satır oranı:

| eTip | Satır | Net = 0 oranı |
|---|---|---|
| 0 Alış | 56.159 | %0,01 |
| 1 Satış | 1.808 | %0,28 |
| 2 Alış İade | 24.793 | %0 |
| **4 Mağaza Satış** | **2.832** | **%79,87** |
| 7 Gider | 1.613 | %0,19 |
| 10 Yerel Alım | 220 | %0 |

Yıllara göre eTip=4 — sistematik ve **kötüleşiyor**:

| Yıl | Satır | Brüt (`ehTutar`) ₺ | İndirim ₺ | Net (`ehTutarN`) ₺ | Net = 0 oranı |
|---|---|---|---|---|---|
| 2023 | 38.106 | 19.630.064 | 2.786.049 | 6.247.543 | %65,4 |
| 2024 | 48.778 | 39.228.169 | 4.735.951 | 9.653.568 | %63,7 |
| 2025 | 65.551 | 67.805.514 | 2.903.432 | 12.693.311 | **%72,5** |
| 2026 (7,5 ay) | 23.743 | 14.902.303 | 1.495.643 | 3.233.147 | **%76,8** |

**Büyüklük:** 2025'te beklenen net (67,8 M − 2,9 M) = 64,9 M₺, okunan `ehTutarN` 12,7 M₺ → **~52 M₺ eksik okuma**. `ehIndirim` de eTip=4'te çoğunlukla sıfır, yani tek güvenilir kolon `ehTutar`.

**Kural:** eTip=4'te `fatAyr.ehTutarN` kullanılmaz. Doğrusu `irsHrk` (`ehTip=4` — orada tutar doğru) veya `ehTutar − ehIndirim`. Diğer hareket tiplerinde `ehTutarN` güvenilir.

> Bu bir ciro kaybı değil — mağaza satışı `irsHrk`/POS tarafında doğru sayılıyor. Risk, `fatAyr.ehTutarN` okuyan raporların mağaza satışını sessizce eksik göstermesi. Mevcut raporlarda taranması gereken bir kalem.

### 11.2 `Sales.RefundReasonId` beslenmiyor, sebep filtresi satır seviyesinden yapılır

Geri dönüşümü ararken çıktı: `Sales.RefundReasonId <> 0` sorgusu **sıfır satır** döndü; sebep yalnız `SalesProducts.RefundReasonId`'de dolu. Fiş seviyesinden sebep filtresi yazan sorgu sessizce boş döner.

Ayrıca `RefundReasons` tablosu iki farklı enstrümanı aynı yerde tutuyor: `Type = 0` iade sebebi, `Type = 1` indirim sebebi. Ayırmadan kullanmak iade ile indirimi karıştırır.
