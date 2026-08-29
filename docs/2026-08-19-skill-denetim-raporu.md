# Skill Denetim Raporu

**Tarih:** 19.08.2026 · **Kapsam:** 19 org skill · **Yöntem:** canlı SQL Server şeması, dosya içi çapraz okuma, web (kısıtlı)

---

## Önce: benim hatam

Bugün `sql-server-uzmani`'nı düzeltirken bir iddiayı **doğrulamadan koruduğum** için sana yanlış bilgi aktardım.

Skill diyor: *"EncoreMerkez compat 110 → `STRING_AGG` / `TRIM` / `IIF` / `TRY_CONVERT` YOK."* Ben bunu doğru varsaydım, üstüne `sabah` skill'ine de yazdım. Test ettim, **dördü de çalışıyor**:

| Test | Sonuç |
|---|---|
| `sys.databases` compatibility_level (EncoreMerkez) | **110** ✔ doğru |
| Sunucu sürümü | SQL Server 2019, 15.0.2110.4 |
| `STRING_AGG(x,',')` | `a,b` — **çalıştı** |
| `TRIM('  bosluk  ')` | `bosluk` — **çalıştı** |
| `IIF(1=1,'a','b')` | `a` — **çalıştı** |
| `TRY_CONVERT(int,'42')` | `42` — **çalıştı** |
| `OPENJSON` | **çalışmadı** — `Invalid object name` |

Sebebi şu: bu skaler ve toplama fonksiyonları **motor sürümüne** bağlı, veritabanı uyumluluk seviyesine değil. Compat seviyesi optimizer davranışını ve bazı sözdizimlerini kapatır — JSON fonksiyonları compat 130+ ister, o yüzden `OPENJSON` gerçekten yok.

**Sonuç:** kural yanlış değil, yanlış yere bağlanmış. Doğrusu: *"EncoreMerkez compat 110 → JSON fonksiyonları (`OPENJSON`, `JSON_VALUE`) yok. Skaler fonksiyonlar serbest."* Bu hata dört skill'de birden var (`sql-server-uzmani`, `veri-yorumlama`, `sql-kod-inceleme`, `sql-refactor`) ve gereksiz `STUFF + FOR XML PATH` külfeti dayatıyor.

---

## İkinci uyarı: ajanlar çelişti, ben çözdüm

Denetimi dört alt ajana paylaştırdım. İkisi aynı rakam için farklı sonuç verdi:

- Ajan A: *"389.4M TL iddiası 392 kat şişik, gerçek 992.028,68 TL"*
- Ajan B: *"en yakın ölçüm 419,4M TL, aynı büyüklük mertebesi"*

Kendim ölçtüm. **Ajan B doğru:**

```
dbo.SalesProductCampaigns  —  2.635.892 satır
  CampaignId NULL          —    434.578 satır
  NULL satırların TotalDiscount toplamı  =  -419.380.909,23 TL
  Tüm TotalDiscount toplamı              =  -595.837.935,07 TL
```

Yani skill'deki 389,4M rakamı 392 kat hatalı değil — **daha erken bir tarihte alınmış, etiketlenmemiş bir tüm-zaman ölçümü**. Ajan A muhtemelen daha dar bir tanımı (köprüye hiç bağlanmayan doğrudan iskonto) ölçtü.

Gerçek kusur bu yüzden farklı ve daha kolay düzeltilir: rakamın **tablosu, kolonu, dönemi ve işaret yönü yazılmamış.** Değerler negatif tutuluyor; skill bunu söylemediği için okuyan `SUM()` sonucunu ters işaretle raporlar.

Bunu buraya yazıyorum çünkü doğrulanmamış bulgu aktarmak, bulgu bulmamaktan daha kötü.

---

## Kritik — rakamı veya kararı değiştirenler

### 1. Ciro tanımı eleksiz (bi-dashboard §10.1, kpi-tasarim §13.2)

"Bugünkü ciro | Sales" diyor; belge tipi, iade ve geri dönüşüm eleği yok.

| Tanım | 17.08.2026 |
|---|---|
| Filtresiz `GrossTotal − DiscountTotal` | 3.771.227 TL |
| Perakende (`DocumentsTypeId IN (1,2)`) | 1.965.265 TL |
| Sınav Okulları (tip 8, hepsi İst.Yolu) | 1.720.417 TL |
| Geri dönüşüm (`BarcodeNo='1001'`) | 7.216 TL |

Yönetim panosu bugünkü tanımıyla **yaklaşık iki kat şişik.** Sınav sezonunda fark daha da açılıyor.

### 2. `SalesProducts.TotalPrice` tuzağı — hiçbir skill yazmıyor

`TotalPrice` **zaten iskonto düşülmüş.** Üstüne `DiscountTotalDirect` çıkarılırsa iskonto iki kez sayılır. Doğrulama (17.08.2026):

```
SUM(sp.TotalPrice)                    = 3.771.226,94
SUM(s.GrossTotal - s.DiscountTotal)   = 3.771.226,94   ← kuruşu kuruşuna aynı
SUM(sp.DiscountTotalDirect)           =   593.075,91   ← ikinci kez düşülürse -%15,7
```

Bunu `sql-server-uzmani` §7.2'ye yazdım. `finans-butce-muhasebe`'ye de girmeli, çünkü kâr/marj formül otoritesi orada.

### 3. Finans skill'inde BKM ciro formülü hiç yok

`kpi-tasarim` ve `bi-dashboard` ikisi de *"formül otoritesi finans-butce-muhasebe'de"* diyor. O skill'de `Sales`/`SalesProducts` formülü **geçmiyor**. Yani her dashboard kendi formülünü uyduruyor — yukarıdaki iki bulgu bunun sonucu.

İki varyant birlikte yazılmalı, hangisinin nerede geçerli olduğu etiketlenerek:
- KDV **dahil**: `GrossTotal − DiscountTotal` (Pazartesi brifingi, sabah brifingi)
- KDV **hariç**: `− VatTotal` de düşülür (`dashboard/Data/TrafikQueries.cs` KPI'ları)

17.08 perakende farkı: 1.965.265 (dahil) vs 1.832.560 (hariç) → günde 133 bin TL, %6,8 sessiz sapma.

### 4. Var olmayan kolonlar — sorgu çalışmıyor

`Sales` tablosunda **olmayan** ama skill'lerde kullanılan kolonlar: `IsValid`, `CampaignId`, `DocumentDate`, `mekanID`, `UpdateDate`, `UpdateUserId`, `DiscountTotalDirect`.

| Skill'de yazan | Gerçek |
|---|---|
| `Sales.IsValid = 1` | Kolon yok. `SalesProducts.IsValid` var |
| `Sales.CampaignId` | Yok. Köprü: `SalesProductCampaigns(SalesId, ProductSequence, CampaignId)` |
| `Sales.mekanID` | `Sales.StoresId` |
| `Sales.DocumentDate` | `Sales.Date` |
| `Sales.UpdateDate` | **Yok** — mutasyon tespit edilemez, sadece `CreateDate` ile oluşturma |
| `J_ORDERS.CUSTOMERREF` | `CLIENTREF` |
| `J_ORDER_LINES` | `J_ORDER_DETAILS` |
| `Encore Muhasebe.FATURA_BAKIYE` | Yok. Var olan: `BKMDATA.dbo.ODAK_FATURA` |
| `Sales History` | Yok. `SalesTransferHistory` transfer logu |

### 5. Sessiz sıfır — en tehlikeli hata tipi

`veri-yorumlama` orphan iade kontrolü `LinkedDocumentNo IS NULL` diyor. **Hiç satır dönmüyor**, yani "temiz" görünüyor. Gerçek: alan boş string (`= ''`) veya `LinkedDocumentId = 0` tutuluyor ve **13.597 iade** (%40,9) bağsız.

Bu tip hata en kötüsü çünkü hata vermiyor, yanlış güven veriyor.

### 6. Ölçülemez KPI'lar "temiz" raporluyor

- *"Dönem kapanışı sonrası fiş değişikliği = 0 belge"* → `Sales`'te `UpdateDate` olmadığı için ölçülemez, ama 0 raporlanıyor.
- *"CampaignId NULL sızıntısı = 0 TL"* → kaynak tablo yazılmamış; gerçekte 434.578 satır.

Düzeltme: birincisini *"post-close oluşturulan evrak (`CreateDate > KapanisDT`)"* olarak yeniden tanımla ve mevcut üç SP'ye bağla — `bkm.sp_AyKapanisSonrasiEvrakKontrol`, `bkm.sp_AylikKapanisSonrasiMudahaleKontrol`, `bkm.sp_KapanisMudahaleKontrol_v2`. Üçü de mevcut.

Bu sorguyu düzeltip çalıştırdım ve **gerçek bir ihlal buldu**: `SalesId 618732`, belge 29.12.2025, sisteme giriş 18.01.2026 — Aralık dönemi 13.01'de kapanmıştı.

### 7. Hedef kaynağı yanlış

`kpi-tasarim` §13.2 *"Hedef: aylık plan / 30"* diyor. Oysa `BKMDATA.dbo.Hedef` **var** ve gün + kategori kırılımı hazır: `mekanId, tarih, yil, ay, gun, hafta, ktgId, hedef` — 133.080 satır. FSM Ağustos günlük hedefleri 447.779–588.747 TL bandında; 17.08 için 575.229 TL.

"Aylık/30" tek günde ±%15'e kadar sahte yeşil/kırmızı üretiyor.

### 8. Ulaşılamaz KPI eşiği

*"İskonto oranı < %10"* hedefi konmuş. Gerçek: 01–17.08 perakende **%21,92** (mağaza bazında %20,99 / %22,70 / %23,21). Kalıcı kırmızı KPI, sinyal değeri sıfır — ve `kpi-tasarim`'ın kendi SMART-A (achievable) kuralını ihlal ediyor.

---

## Mevzuat skill'leri — DENETLENEMEDİ

Bunu net söylemem gerek: dört mevzuat skill'i **doğrulanamadı.** Birincil kaynakların hemen hepsi bu ortamdan erişilemiyor:

| Kaynak | Durum |
|---|---|
| `mevzuat.gov.tr` | TLS / timeout — kanun metni alınamadı |
| `resmigazete.gov.tr` | robots TLS hatası — tebliğ alınamadı |
| `kvkk.gov.tr` alt sayfaları | robots kapalı |
| `gib.gov.tr` | JS ile yükleniyor, gövde boş — vergi takvimi okunamadı |
| WebSearch | HTTP 403, organizasyon egress politikası |

Dolayısıyla 2026 parametre katmanının tamamı (asgari ücret, kıdem tavanı, SGK oranları, gelir vergisi dilimleri, KVKK ceza bantları, VUK cezaları, Ba-Bs eşiği, e-Fatura eşiği, gıda cezaları) **teyit edilmemiş** sayılmalı.

Buna rağmen **dosya içi çelişkiler** bulundu, bunlar dış kaynak gerektirmiyor:

| Konu | Çelişki | Önem |
|---|---|---|
| VERBİS muafiyet eşiği | `turkiye-is-mevzuati`: 50+ çalışan **veya 25M ciro** · `kvkk-veri-envanteri`: 50'den az **ve** 100M **mali bilanço** | **Kritik** — biri yanlış, kayıt olmamak idari para cezası |
| Net asgari ücret formülü | `turkiye-is-mevzuati` §18: işçi kesintisi %15 içinde işsizlik %1 zaten var, formül **ikinci kez** düşüyor; ayrıca §23.2 "asgari ücrette damga istisnası" derken formül damgayı kesiyor | **Kritik** — her bordro hesabını bozar |
| MUHSGK ödeme tarihi | `turkiye-is-mevzuati`: takip eden ayın **son günü** · `turkiye-vergi-mevzuati`: **26** | Yüksek — gecikme zammı |
| Belge saklama süresi | `turkiye-vergi-mevzuati`: **10 yıl, VUK** · `kvkk-veri-envanteri`: **5 yıl VUK m.253**, 10 yıl TTK m.82 | Yüksek — erken imha hem vergi hem KVKK ihlali |
| VUK 359 hapis bantları | 2022 öncesi metne benziyor, **Confidence High** işaretli, teyit uyarısı yok | **Kritik** — resmî yazışmaya kopyalanır |
| Fatura haddi 1.000 TL | Confidence Low listesinde **hiç yok**, yani teyit zorunluluğu olmadan kullanılabilir | **Kritik** |
| VERBİS kategori sayısı | Başlık "22 Kategori", liste **23 kalemle** numaralı | Yüksek |
| Saatlik ücret böleni | "225 = 45 saat × 4,33 hafta" — 45 × 4,33 = 194,85. Bölen doğru (30 × 7,5), **gerekçe yanlış** | Yüksek |
| İdari para cezası itirazı | Tek süre + tek mercii veriliyor, oysa skill'de 2872 / 5996 / 6331 cezaları var | **Kritik** — hak düşürücü süre |
| Yeniden değerleme %25,49 | Skill kendi kuralı "güven yoksa rakam söylenmez" derken "%25,49 **uygulanmıştır**" diye kesinlik dili kullanıyor | Yüksek |

**Öneri:** egress politikasına `mevzuat.gov.tr`, `resmigazete.gov.tr`, `kvkk.gov.tr`, `gib.gov.tr` ve bir arama motoru eklenirse bu katman tek oturumda kapatılabilir.

---

## Kırık zincir — 16 skill yok

Skill'ler işi var olmayan skill'lere devrediyor. Devredilen iş **sessizce düşüyor**.

| Eksik skill | Kaç skill çağırıyor | Ne düşüyor |
|---|---|---|
| **risk-tarama** | **7** | Tüm proaktif risk değerlendirmesi. `gorev-planlama` ve `kok-sebep` ikisi de riski buraya atıyor; kimse yapmıyor |
| **mvp-mimari** | 2 | Fikir hattının çıkışı. `konsept-eleme` Yeşil kararı "mvp-mimari'ye geçilebilir" diyor, varış yok |
| **fikri-profil** | 5 | Çıktı formatı / ton otoritesi |
| **atlascoreus-marka** | 3 | Marka ses tonu. `humanizer`'ın ton hiyerarşisinin tepesi boş |
| **belinza-baglan** | 3 | Belinza domain kısıtları |
| **yonetiq-platform** | 3 | YönetIQ platform kuralları |
| **erp-crm-wms-mimari** | 3 | Mimari değişiklik önerisi |
| **etsy-*** (6 skill) | 3 | ATLASCOREUS listing akışının tamamı |
| **dusakabin-mobilya** | 1 | Montaj ekipleri saha disiplini |
| **turkiye-sozlesme-hukuku** | 2 | Sözleşme hukuku katmanı |

Bunlar ya yazılmalı, ya referanslar kaldırılmalı. Şu hali en kötüsü: skill "bu iş orada yapılır" diyor, orada kimse yok.

---

## Sahiplik ve tetikleme sorunları

**Sahipsiz kalan işler**

| Konu | Durum |
|---|---|
| Faz kapanış retrospektifi | `gorev-planlama` "kapsam dışı, kok-sebep'in işi" diyor **ama §7.2'de kendi 3 soruluk şablonunu uyguluyor**; `kok-sebep` 9 satırlık başka bir şablon veriyor. İki sahip, iki şablon |
| Çalışan AI eğitimi | `ai-surec-tasarim` "insan-kaynaklari'nın işi" diyor; `insan-kaynaklari` "kurumsal eğitim aracı DEĞİLDİR" diyor. Gerçek sahip `egitim-tasarim`, ama kimse onu göstermiyor |
| KVKK personel verisi | `insan-kaynaklari` otoriteyi `turkiye-is-mevzuati`'na yönlendiriyor; gerçek otorite `kvkk-veri-envanteri` |

**Tetikleme çakışmaları** (tie-breaker yok)

| İfade | Çakışan |
|---|---|
| "AI'ı şu işe nasıl katarız" | `konsept-uretimi` ↔ `ai-surec-tasarim` |
| "faz bitti / retrospektif" | `kok-sebep` ↔ `gorev-planlama` |
| "değerlendir / puanla" | `konsept-eleme` ↔ `insan-kaynaklari` |
| "eğitim modülü" | `egitim-tasarim` ↔ `ai-surec-tasarim` ↔ `insan-kaynaklari` |

**Emoji kuralı üç yönlü çelişki:** `humanizer` "emoji sil", `egitim-tasarim` "emoji YAPMA", ama `konsept-eleme`'nin **zorunlu çıktı şablonu** 🟢🟡🔴 emojili ve aynı skill `humanizer`'ı eş zamanlı çağırıyor.

---

## Skill içi tutarsızlıklar (özet)

**insan-kaynaklari** — gece vardiyası yasağı listesi otoriteyle uyuşmuyor: skill "hamile / 18 altı / **engelli**" diyor; `turkiye-is-mevzuati` "gebe / **süt çocuğu olan kadın** / 18 altı / **sağlık raporu uygun olmayan**". "Engelli" uydurma, iki gerçek kategori düşmüş — ve skill kendi §24'ünde "turkiye-is-mevzuati override edilemez" diyor. Ayrıca vardiya planı "önceki hafta Çarşamba" (≈5 gün) derken kendi kontrolü "7 günden az mı" diye soruyor.

**humanizer** — "8 Adım" başlığı altında 10 alt bölüm; "Türkçe özgü 10 kalıp" derken tabloda 8 satır. Kendi yasakladığı kalıpları kullanıyor: inline bold-header (pattern 16), üçlemeler (pattern 10), Title Case başlıklar (pattern 17).

**konsept-eleme** — karar kuralı boyut skalalarıyla uyuşmadığı için **matris uygulanamaz**: Yeşil "5 boyut en az orta" diyor ama Boyut 2'nin skalası Boş/Yarı/Dolu, Boyut 5'in skalası hiç yok. Kendi örnek kütüphanesi "en az 1 kırmızı zorunlu" kuralını ihlal ediyor.

**ai-surec-tasarim** — "üç gate'ten az: öneri dışı" (§5.1) ↔ "5 dakika altı: 1 gate yeterli" (§12.3). Ayrıca §7.3 Odoo kod örneği `"veUstu"/"veAltinda"` yazıyor, kopyalanınca çalışmıyor.

**egitim-tasarim** — "en az **iki** tam pedagojik birim" (§3) ↔ checklist "en az **bir** worked example" (§9). Skill Chain bölümü hiç yok; Türkçe metin üretmesine rağmen `humanizer`'a bağlanmıyor.

**konsept-uretimi** — "5-8 fikir" ↔ "her seviyeden 2-3 = 6-9 fikir".

**gorev-planlama** — şablon tablosunda kolon adı `Bagimliik` (yazım hatası; şablon kopyalandıkça yayılıyor).

**kok-sebep** — iç mantığı sağlam. Tek kusuru "5. **sayfaya** indiysen" (neden kademesi kastediliyor).

---

## Yapılacaklar sırası

**Hemen — rakam bozan**
1. Ciro tanımına belge tipi + iade + `1001` eleği ekle (`bi-dashboard`, `kpi-tasarim`)
2. `finans-butce-muhasebe`'ye kanonik ciro formülünü yaz, KDV dahil/hariç etiketiyle
3. `TotalPrice` çift-iskonto tuzağını finans skill'ine ekle
4. Hedef kaynağını `BKMDATA.dbo.Hedef`'e çek
5. Orphan iade predicate'ini `= ''` / `= 0` yap

**Hemen — hukuki**
6. VERBİS eşiği çelişkisini çöz (25M ciro ↔ 100M mali bilanço)
7. Net asgari ücret formülünü düzelt (işsizlik çift sayımı)
8. VUK 359 bantlarını Confidence Low'a indir, teyit notu ekle
9. Fatura haddini teyit listesine ekle
10. İdari para cezası itiraz süresi/merciini kanun bazında ayır

**Sonra — yapısal**
11. compat 110 kuralını dört skill'de JSON kısıtına indir
12. `IsValid = 1`'i koşulsuzdan tablo bazlıya çevir (doğrulanmış tablo `sql-server-uzmani` §3.7'de)
13. Var olmayan kolon/tablo referanslarını düzelt (liste yukarıda)
14. 16 eksik skill: yaz ya da referansları kaldır — `risk-tarama` en acil (7 skill ona bağlı)
15. Sahiplik çakışmalarını tek sahibe indir
16. Skill içi sayı/eşik tutarsızlıklarını düzelt

---

## Denetlenmeyenler

`skill-creator`, `analyze`, `sabah` (bugün yazıldı), ve Anthropic'in kendi skill'leri (`docx`, `xlsx`, `pptx`, `pdf`, `dataviz`, `morning`, `humanizer` dışındaki eklenti skill'leri) kapsam dışı tutuldu.
