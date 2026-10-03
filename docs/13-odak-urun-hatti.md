# ODAK Ürün · Fiyat · Özellik · Stok Hattı — Kurallar ve Bulgular

**Ölçüm tarihi:** 03.10.2026 (canlı, salt-okuma) · **Kanıt SQL:** [`sorgular/2026-10-03-odak-urun-hatti.sql`](../sorgular/2026-10-03-odak-urun-hatti.sql)
**Kapsam:** DerinSISBkm + BKMDATA içinde adı ya da kodu "odak" geçen 74 modül (SP/view/fn) + 40 tablo + SQL Agent job'ları.
Her olgu **ÖLÇÜLDÜ** (sorgu + sayı var) ya da **ÇIKARIM** (koddan türetildi, sayıyla teyit edilmedi) diye etiketlidir.

> ⚠ `ent.OdakUrunGuncellemeEslestir` ve `bkm.OdakTukendileriTukendiYap` **bugün (03.10.2026) değiştirilmiş**
> (`sys.objects.modify_date`). Aşağıdaki kod okuması değişiklik sonrasının kodudur.

---

## 1. Akış — kim, ne zaman, neyi çalıştırıyor

| # | Adım | Tetikleyen | Sıklık | Süre | Kanıt |
|---|---|---|---|---|---|
| 1 | Dış yükleyici `odak_urun_temp` / `odak_urun_magaza_temp`'i doldurur, `BKMDATA.ent.OdakUrunGuncellemeEslestir`'i çağırır | **SQL job DEĞİL, modül DEĞİL** (dış uygulama) | saatte bir (~:50–:03) | 7–9 sn | ÖLÇÜLDÜ: `OdakDataProcedureRunTime` Tip 0 → Tip 1 çiftleri saatlik; msdb'de çağıran job yok |
| 2 | `ent.odakUrunAktar 0` → sonunda `ent.odakFiyatAktarim 0` | job `odakUrunAktar_job` adım 1 | saatte bir 08:30–23:01 | ~3 dk (fiyat ~75 sn) | ÖLÇÜLDÜ: msdb + `dm_exec_procedure_stats` |
| 3 | `ent.tsofturunaktarim 0` (T-Soft'a gönderim bayrakları) | aynı job adım 2 | saatte bir | ~40 sn | ÖLÇÜLDÜ |
| 4 | `BKMDATA.dbo.OdakDegisenStokGuncelle` — KITAPSEPETI'den stok değişimi | job `OdakDegisenStokGuncelle` | 5 dakikada bir | ~10,7 sn | ÖLÇÜLDÜ |
| 5 | `OdakStokAktar` (52 koşum/3 gün) · `OdakMarkaAktar` (35) · `OdakUrunlerineGoreTsoftUrunAc` (7) · `OdakStoklariniSiteyeBas` (7) · `OdakSatisIrsaliyeFiyatOlustur` (7) · `OdakTukendileriTukendiYap` (bugün 1) | **çağıran bilinmiyor** — job ve modül yok | düzensiz | — | ÖLÇÜLDÜ (çağıranın yokluğu); kimin çağırdığı açık soru |

`odakFiyatAktarim`'in çağıranı (12.09'da açık soruydu) **çözüldü:** `odakUrunAktar`'ın son satırı `EXEC ent.odakFiyatAktarim 0`.

Ayrıca `odakUrunAktar` 3 günde **54 kez parametresiz** çağrılmış (0 ms → `@cikis=1` korumasına takılıp hiçbir şey yapmadan dönüyor). Çağıran bilinmiyor. Zararsız ama unutulmuş bir çağrı noktasına işaret ediyor.

Bağlı sunucular: `KITAPSEPETI` = 192.168.40.171 (stok kaynağı) · `ODAKJOKER` = .70 · `JOKER` = .50.

---

## 2. Tablolar — hangi tabloda hangi bilgi var

### BKMDATA (ODAK'ın BKM tarafındaki kopyası)

| Tablo | Satır | İçerik | Yazan |
|---|--:|---|---|
| `ent.odak_urun_temp` | 2.505 | Saatlik **değişen** web ürünleri (ara alan) | dış yükleyici |
| `ent.odak_urun_tam` | 648.888 | **Web kataloğunun tam kopyası** — ad, barkod, `etiket_fiyat`, KDV, marka, yazar, künye (basım, sayfa, en/boy/ağırlık, cilt, kağıt), 5+7 kategori, görsel, `satis_durum`, `SadeceMagaza`, `SilinecekUrun` | `OdakUrunGuncellemeEslestir` |
| `ent.odak_urun_magaza_temp` / `_tam` | 93 / 648.875 | Mağaza kataloğu, aynı yapı | `OdakUrunGuncellemeMagazaEslestir` |
| `ent.odak_urun` | 648.398 | İnce tablo: fiyat, `Durum` metni, `leadtime` | dış yükleyici (modül yazmıyor) |
| `ent.odak_urun_gecici` / `odak_urun_magaza_gecici` | 490.000 / 9.000 | Bugün yazılmış, **hiçbir SQL modülü okumuyor** | dış yükleyici (amacı ÇIKARIM: yükleyicinin ara alanı) |
| `ent.odak_silinen_urunler` (+`_gecici`, `_log`) | 9.632 | Web'den silinen `urun_id` | dış yükleyici |
| `ent.odak_magaza_silinen_urunler` | 3.625 | Mağazadan silinen | dış yükleyici |
| `ent.odak_urun_log` | 5.693.275 | Yeni/değişen ürünün fiyat + satış durumu geçmişi (`Tip` 0 web, 1 mağaza) | iki eşitleme SP'si |
| `ent.odak_marka` (+`_temp`) | 17.118 | Marka ağacı (`group_id`/`parent_id`) + **`discount` = ODAK alış iskontosu** (decimal 9,2) | `OdakMarkaAktar` |
| `dbo.OdakUrunDurum` + `OdakUrunDurumStatus` | 650.421 + 6 | Ürünün ODAK satış statüsü | dış yükleyici |
| `dbo.stok_aktarim_odak` | 501.438 | ODAK depo stoğu, `urun_id` bazında | `OdakDegisenStokGuncelle` |
| `dbo.OdakStokDegisenStok_Log` | **94.739.458** | 5 dakikalık stok değişim geçmişi | aynı |
| `dbo.bakiye_aktarim_odak` / `log_` | 142 / 3,3M | Açık sipariş bakiyesi | dış + `BakiyeSiparisLogla` |
| `dbo.TSOFTProduct` | 602.015 | **T-Soft sitesinin aynası** (stok, aktiflik, fiyat, görsel var mı) | dış yükleyici |
| `dbo.OdakDataProcedureRunTime` | 45.930 | Eşitleme koşum zamanları | iki eşitleme SP'si |
| `dbo.OdakTotalOrder` | 11.621 | Günlük sipariş özetleri | dış |

### DerinSISBkm

| Tablo | Satır | İçerik |
|---|--:|---|
| `ent.odak_depo_Stok` | 500.909 | ODAK depo stoğu **stkID bazında** — 5 dakikada bir silinip yeniden yazılır |
| `ent.odak_bakiye_siparisler` | 140 | Açık sipariş bakiyesi stkID bazında |
| `ent.tsoft_urun` | 446.272 | Siteye gönderilecek ürün kartı + `api_kayit/gorsel/stok/fiyat_durum` bayrakları (1 = gönder) |
| `bkm.OdakIrsaliyeBaslik/Detay` | 1.795 / 1,83M | ODAK→merkez depo transfer irsaliyeleri — **son aktarım 27.03.2024, hat durmuş** |
| `bkm.OneriSiparisOdakKullanici` | 8 | Mekân başına ODAK kullanıcı adı + **şifre kolonu** (bkz. S-7) |

### ERP'de ODAK'ın yazdığı yerler
`dbo.urn` (ürün kartı) · `urnBrkd` (barkod) · `urnBilgi` (öznitelik EAV) · `urnFrm` (ürün-tedarikçi) · `urnMrk` (marka) · `urnkod5` (yazar) · `fytB`/`fytOzl` (fiyat belgesi) · `DerinSISBkmWeb.web.urnWeb` (görsel).

### Kodlar (lookup'tan okundu)
- **ODAK satış statüsü** (`OdakUrunDurumStatus`): 1 Satışta → 1 · 2 Tükendi · 3 Yeni baskıya hazırlanıyor · 4 Liste dışı/telif bitti · 6 Eski baskı → 0 (stokla kısıtlı) · 5 **Yasaklı** → −1.
- **`urn.kod1ID`** (web durumu): 0 Pasif · 1 Aktif · 2 Tükendi.
- **Kişi 137** = otomasyon hesabı (açılan ürün, fiyat belgesi, transfer irsaliyesi hepsinde).

---

## 3. Kurallar — SP'ler ne yapıyor

### 3.1 Katalog eşitleme (`OdakUrunGuncellemeEslestir` + `...MagazaEslestir`)
1. Yeni ürün ve fiyatı/satış durumu değişen ürün `odak_urun_log`'a yazılır.
2. 50+ alandan biri değişen ürün `_tam`'da güncellenir, yenisi eklenir.
3. Görsel değişince ERP'deki eski görsel (`web.urnWeb`) silinir, `urun_gorsel_bn` boşaltılır.
4. Web'den silinen ürün: `satis_durum=0`, `SilinecekUrun=1`. Listeden çıkınca `SilinecekUrun=0`.
5. `DefaultCategory` = dolu olan **en derin** varsayılan kategori (7→1).
6. `sayfa_sayisi` 1 veya 2 ise NULL yapılır.
7. Mağaza kataloğundaki ürün web'de yoksa web tablosuna eklenir (`SadeceMagaza=1`).
8. Web'den silinen ama mağazada duran ürünün ad/barkod/fiyat/KDV/marka bilgisi **mağazadan** alınır.
9. **Fiyat = web ile mağazanın BÜYÜĞÜ.** ÖLÇÜLDÜ: bugün 648.875 ürünün hepsinde iki fiyat eşit.

### 3.2 Ürün açma ve öznitelik (`odakUrunAktar`)
1. ODAK'taki yeni marka `urnMrk`'e, yeni yazar `urnkod5`'e eklenir. **Marka ve yazar ERP'de ODAK'a göre düzeltilir** (ODAK baskındır).
2. **Ürün açılır** eğer barkod hiçbir ERP barkodunda yoksa, `stkKod` olarak da yoksa ve ürün silinecek değilse (ya da yalnız mağazadaysa).
   Açılış değerleri: `stkKod = barkod`, ad ilk 100 karakter, `urnTip=0`, kategori önce 1 (sonra pazaryeri kategori eşlemesiyle `esktgrPazaryeriID=2` gerçek kategoriye taşınır), `ugKisi=137`.
   `kod1ID`: yalnız mağazada ise 0, ODAK'ta satışta değilse 2, satıştaysa 1.
   `piyasaMarj`: marka grubu 3 ve tanımlı açılış marjı 0–99 ise o marj; tanımlı marj 100 ise 0; değilse `discount − 13` (iskonto 13'ten büyükse).
   Üç barkod elle hariç: `9786051705484`, `887961954265`, `4440000002417`.
3. Açılan her ürüne **169 "Stok Kontrolü Yok" = True** yazılır. Sonra her koşumda 169 = ODAK satış durumu yapılır.
4. ÖLÇÜLDÜ — otomatik açılan ürün (`ugKisi=137`, `gTarih`): ayda **3.000–4.650**. Eylül 2026: 4.654. Kategorisi 1'de kalan ihmal edilebilir (21 / 498, Ekim ilk 3 gün).
5. **Tedarikçi bağı:** marka→firma tanımından `urnFrm`. Ayrıca kategori 43 ve 35 dışındaki **her ürüne** 56 (Bursa Kültür Merkezi) ve 9525 (ODAK-POINT) tedarikçi olarak eklenir.
   ÖLÇÜLDÜ: 9525 bağlı ürün 808.775 / 842.648 · eksik 0 · `stkFirma=9525` olan ürün **679.076 (%80,6)**.
6. **Öznitelikler** (`urnBilgi`) — "yoksa ekle, farklıysa güncelle" yapısında, ama her alan için iki yol da yok (S-1, S-3):
   174 Odak Ürün ID · 175 açıklama · 176 orijinal başlık · 177 alt başlık · 181 editör · 183 çevirmen · 184/198 ön sipariş · 185 cep boy · 189 kağıt · 190 cilt · 191 sayfa · 192 basım sayısı · 193 basım yılı · 101 en · 102 boy · 106 ağırlık · 10 web adı.
   Bir stkID birden çok ODAK ürününe denk geliyorsa (350 ürün, `bkm.CiftUrunlerMaxFyat`) öznitelik yazılmaz.
7. Görsel: ERP'de görseli olmayan ürüne ODAK görseli eklenir; ODAK görseli daha yeniyse eski silinir.
8. Ürün adındaki `“ ”` tırnakları boşlukla değiştirilir. Boş adlı yazar bağı sıfırlanır.
9. ODAK'ta KDV'si 0 olan (kitap), stoğu ≥1, pasif ürün **Tükendi (2)** yapılır.

### 3.3 Fiyat (`odakFiyatAktarim`) — ayrıntı `sema/entities.yaml: odak_fiyat_aktarim_motoru`
ÖLÇÜLDÜ: **bayraksız tekil ürünlerin 645.914'ünün 645.914'ünde ERP satış fiyatı = ODAK etiket fiyatı.** Fark yalnız iki yerde:
- 220 "Odak Fiyat Güncellenmesin" bayraklı 501 üründen 401'i farklı (bayrak çalışıyor).
- Birden çok ODAK ürününe bağlı stkID'lerde fiyat = **en yüksek** ODAK fiyatı (ya da 1 kuruş eksiği); 28 ürün.
Son 7 günde günde 51–177 fiyat belgesi (`fytB`, "Odak2 Ent").

### 3.4 Web durumu (`kod1ID`) — dört ayrı yer yazıyor
| SP | Kural |
|---|---|
| `odakUrunAktar` | silinecek ya da yalnız mağazada → 0 · pasif + KDV 0 + stok ≥1 → 2 |
| `tsofturunaktarim` | `urnDurum=0` → 0 · ODAK'ta satışta + kod1 0/2 → 1 |
| `OdakUrunlerineGoreTsoftUrunAc` | ODAK'ta satışta + kod1 2 → 1 |
| `OdakTukendileriTukendiYap` | ODAK statüsü 0 (tükendi/eski baskı/liste dışı) → 2 |

ÖLÇÜLDÜ — tutarlılık: satışta+aktif 345.424 · satışta değil+pasif 198.880 · satışta değil+tükendi 96.460. Sapan satır: 141 + birkaç düzine (bkz. S-4).

### 3.5 Stok (`OdakDegisenStokGuncelle`, 5 dakikada bir, tek transaction)
KITAPSEPETI son 24 saat değişimleri → `stok_aktarim_odak` → `odak_depo_Stok` (truncate + barkod→stkID toplamı) → değişen ürünler için `tsoft_urun.api_stok_durum=1`.
ÖLÇÜLDÜ, **adedi adedine mutabık:** kaynak 7.591.652 − ERP'de barkodu olmayan 2.469 (508 satır) − elle hariç barkod `9786257283298` 7 = hedef **7.589.176**.

### 3.6 Alış irsaliyesi fiyatı (`OdakSatisIrsaliyeFiyatOlustur @IrsaliyeNo`)
İrsaliye satırına 9525 firmasının son tarihsel alış fiyatı (`fytOzl fTur=1, fTip=1`) ve üç iskontosu yazılır; yoksa `urn.fiyatS`.

### 3.7 Görünümler
- `ent.OdakUrunMaliyet` = `etiket_fiyat × (100 − marka iskontosu)/100` → rakip fiyat görünümlerinin maliyet girdisi.
- `bkm.OdaktaDatasiOlupMarjiSorunluUrunler` = site fiyatından hesaplanan marj − ODAK iskontosu.
- `bkm.CiftUrunlerMaxFyat` = birden çok ODAK ürününe bağlı stkID + en yüksek fiyat (350 satır).

---

## 4. Sorunlar — hepsi ölçüldü

| # | Sorun | Kanıt | Etki |
|---|---|---|---|
| **S-1** | **"Ürün Web Adı" (10) eklenmiyor.** Ekleme bloğu boş satırın `bDeger`'ini karşılaştırıyor; NULL ile karşılaştırma hiçbir zaman doğru olmuyor. | Blok aynen koşturuldu: **0 satır**; karşılaştırma çıkarılınca 599.370. Bağlı 646.764 üründen **599.333'ünde** 10 yok. | Site adı `stkAd`'a düşüyor (`tsofturunaktarim`). Bunun sonucu: 100 karakterden uzun 1.389 ad kesik, marka önekli olması gereken kategoride (`001007002`) 1.316 ürün öneksiz, 364 ürünün tırnakları silinmiş. |
| **S-2** | **Basım yılı / basım sayısı / sayfa sayısı güncellemesi `stkKod = barkod` ile bağlanıyor** (barkod köprüsü yerine). | Sapma **yalnız** stkKod≠barkod grubunda: 23.230 üründe yıl **2.360**, basım sayısı **115**, sayfa **60**. stkKod=barkod grubunda (623.185 ürün) üçü de **0**. | Önceden açılmış ya da ikinci barkodlu ürünlerde künye bayat (örnek: ODAK 2023, ERP 2021). |
| **S-3** | **Bazı öznitelikler yalnız eklenir, hiç güncellenmez:** boy (102), alt başlık (177), açıklama (175), web adı (10). | Boy farkı **5.392** (her iki grupta), alt başlık **4.578**. Açıklamada 292.562 fark var, ama çoğu HTML karakter kodlaması farkı (`&ccedil;` ↔ `ç`); gerçek içerik değişimi bu yöntemle **ayrılamadı**. | ODAK'ta düzeltilen bilgi ERP'ye ve siteye geçmiyor. En (101) ve ağırlık (106) güncel: fark 0. |
| **S-4** | **Aynı stkID'ye bağlı iki ODAK ürününden biri silinmiş, biri aktifse durum her saat iki kez yazılıyor.** `odakUrunAktar` 0 yapıyor, aynı job'ın 2. adımı `tsofturunaktarim` 1 yapıyor. | Silinecek/yalnız-mağaza satırı olup aktif kalan **141 ürünün 141'i** çift ve hepsinin aktif bir ikinci satırı var. Saatlik gidip gelme kod sırasından türetildi — ÇIKARIM, log'da gözlenmedi. | 140'ının bir satırı ODAK'ta **"Yasaklı"** statüde. Ürün aktif kalıyor çünkü ikinci barkodu satışta. Elle bakılmalı. |
| **S-5** | **Tarih metni `'2025-11-01'`** (`bkm.OdakIadeIrsaliyeleriFaturalasmamis`). | Türkçe oturumda **11.01.2025** okunuyor (test edildi). | Görünüm bugün **0 satır** döndürüyor, şu an etkisi yok. Ama süzgeç 10 ay geniş. |
| **S-6** | **Mağaza fiyat değişimi log'da web değişimi gibi görünüyor.** Mağaza SP'si değişen kayıtta `Tip` yazmıyor, varsayılan **0** (web). | `DEFAULT ((0))` ölçüldü. | `odak_urun_log`'dan "mağaza fiyatı ne zaman değişti" sorusu cevaplanamaz. |
| **S-7** | **`bkm.OneriSiparisOdakKullanici.OdakSifre`** — 8 satırın 7'sinde dolu. | Sayıldı, değer bilinçli olarak okunmadı. Düz metin mi şifreli mi **bakılmadı**. | Düz metinse ERP'yi okuyan herkes ODAK hesaplarına erişir. Güvenlik kontrolü gerekli. |
| **S-8** | **`OdakStokDegisenStok_Log` sınırsız büyüyor.** | 12.09: 92.392.737 → 03.10: 94.739.458 = **21 günde +2,35M** (günde ~112 bin). Silme yok. | Disk ve 5 dakikalık job süresi yavaş yavaş artar. |
| **S-9** | **Tedarikçi alanı gerçek tedarikçiyi göstermiyor.** Her ürüne 56 ve 9525 ekleniyor, `stkFirma` 679.076 üründe 9525. | Bölüm 3.2/5. | `urnFrm` / `stkFirma` ile "hangi tedarikçiden" analizi yanıltıcı. Tedarikçi alıştan (`irs.eFirma`) okunmalı. |
| **S-10** | **Elle yazılmış sabitler:** barkod `9786257283298` stoktan hariç (7 adet), 3 barkod açılıştan hariç, kişi 137, firma 56/9525, kategori 43/35, pazaryeri 2, iskonto eşiği 13, KITAPSEPETI IP'si. | Kod. | Gerekçesi kodda yok. Değişince sessizce eskir. |
| **S-11** | **ODAK→merkez depo transfer hattı ölü.** | `OdakIrsaliyeBaslik` son aktarım 27.03.2024; 3 başlık `9999-12` tarihli ve aktarılmamış. `ODAK_DEPO_TRANSFER` 3 günlük plan önbelleğinde yok. | Ölü kod + 1,83M satırlık kullanılmayan tablo. |
| **S-12** | **`ent.OdakUrunMaliyet` 40 stkID'de birden çok satır döndürüyor.** | Ölçüldü. | Bu görünüme stkID ile bağlanan sorgu o ürünlerde satırı çoğaltır (rakip fiyat görünümleri). |
| **S-13** | **Kaynak kod sürüm kontrolünde görünmüyor ve bugün iki SP değişti.** | `modify_date` 03.10.2026. | Neyin değiştiği izlenemiyor. ÇIKARIM: repo yok (ölçülmedi). |

### Şüphelenildi, ölçüldü, **elendi**
- `OdakUrunMaliyet`'te tam sayı bölmesi → `discount` decimal(9,2), bölme doğru.
- En (101) güncellemesindeki garip `UPDATE urnBilgi` yazımı başka öznitelikleri bozuyor mu → en/ağırlık farkı 0, bozulma yok.
- `OdakSatisIrsaliyeFiyatOlustur` KDV'yi iskontodan önce hesaplıyor → kayıtlı KDV iskonto **sonrası** (son 30 gün 797 satır: 719 sonrası, 0 yalnız öncesi). Sonradan yeniden hesaplanıyor.
- Yazar güncellemesindeki `OR` koşulu → yalnız boş yazarı dışarıda bırakıyor, doğru.
- Ön sipariş tarihi silme önceliği (`OR`/`AND`) → kalan bayat kayıt 2 / 122.

---

## 5. Açık sorular
1. `odak_urun_temp`'i dolduran ve eşitleme SP'sini çağıran dış uygulama hangisi, nerede çalışıyor?
2. Saatlik job dışındaki altı SP'yi (Bölüm 1 / 5) kim çağırıyor? 54 parametresiz `odakUrunAktar` çağrısı nereden geliyor?
3. `odak_urun_gecici` (490 bin) ve `odak_urun_magaza_gecici` ne için tutuluyor?
4. 03.10.2026'daki iki SP değişikliği neydi?
5. 228 "Odak Alış Fiyat Güncellemesin" bayrağının iş gerekçesi (12.09'dan açık).
