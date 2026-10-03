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

## 4. Sorunlar — hepsi ölçüldü (ikinci tur, SP + satır)

Satır numaraları `sys.sql_modules` tanımına göre. Ayrıntı (kod alıntısı, kanıt, öneri): `docs/13-odak-entegrasyon-brief.docx` §7. Kanıt SQL: arşiv dosyası "EK" bölümü.

| # | Önem | Sorun | Nerede | Kanıt |
|---|---|---|---|---|
| S-1 | Yüksek | 228'li ürüne her saat fiyat belgesi (döngü), "önceki fiyat" sahte | `odakFiyatAktarim` 63–84, 73, 130–131 | 30g 4.702.211 satış satırı / 36.497 ürün; 4.630.424 sahte önceki; 228'li 10.108 ürün → 4.560.438 satır; saatte ~10.465 |
| S-2 | Yüksek | 220 "Fiyat Güncellenmesin" ikinci blokta yok → elle fiyat eziliyor | `odakFiyatAktarim` 53–55 vs 63–84 | 15 ürün, 3.037 satır; 1677679 elle 800 → 864 |
| S-3 | Orta | Satış satırı ürün başı değil firma başı | `odakFiyatAktarim` 49 | aynı ürün-gün çok satır 323.590 |
| S-4 | Orta | Ürün Web Adı (10) eklenmiyor | `odakUrunAktar` 212–219 | blok 0 satır; 599.333 üründe yok |
| S-5 | Orta | Basım yılı/sayısı/sayfa `stkKod=barkod` ile | `odakUrunAktar` 389–391, 424–426, 449–451 | stkKod≠barkod 23.230'da 2.360/115/60, diğer grupta 0 |
| S-6 | Orta | Boy/alt başlık/açıklama yalnız INSERT | `odakUrunAktar` 538, 195, 255 (273 kapalı) | boy 5.392, alt başlık 4.578 |
| S-7 | Orta | ERP'de kapalı ürün web'de aktif | `tsofturunaktarim` 11–12 → 15–21 | 130/130 ODAK satışta |
| S-8 | Orta | Çift ürün durum çakışması | `odakUrunAktar` 882–887 ↔ `tsofturunaktarim` 15–21 | 141/141; 140'ı Yasaklı |
| S-9 | Orta | Görsel yenilenmiyor | `OdakUrunGuncellemeEslestir` 30–37 (34), `odakUrunAktar` 815–823 | bayat: farklı grup 1.761/23.446, eşit 183/623.357 |
| S-10 | Orta | Kısa ad TÜM ürünlerde ezilir (29 karakter) | `odakUrunAktar` 879 | 842.648/842.648; 194.128 ODAK dışı |
| S-11 | Orta | Her ürüne 56 + 9525 tedarikçi | `odakUrunAktar` 145–151 | 9525: 808.775, 56: 810.054 |
| S-12 | Düşük | stkFirma her saat yeniden yazılıyor | `odakUrunAktar` 178–181 | 25.480 ürün her koşumda |
| S-13 | Düşük | Mağaza log'unda Tip yok (DEFAULT 0) | `OdakUrunGuncellemeMagazaEslestir` 16 | DEFAULT ((0)) |
| S-14 | Düşük | Stok log sınırsız | `OdakDegisenStokGuncelle` 58–63 | 21 günde +2,35M (94,7M) |
| S-15 | Düşük | Maliyet view çok satır + FLOAT | `ent.OdakUrunMaliyet` 5 | 40 stkID çoklu |

Kural riski (ölçülemedi): `odakUrunAktar` 890–898 pasif ürünü (ODAK KDV 0 + stok ≥1) Tükendi'ye çeviriyor; elle pasif ayırt edilmiyor.

İrsaliye kapsamındaki bulgular (ürün brief'inden çıkarıldı, kayıt için): `bkm.OdakIadeIrsaliyeleriFaturalasmamis` `'2025-11-01'` → Türkçe oturumda 11.01.2025 (bugün 0 satır) · `OdakIrsaliyeBaslik` son aktarım 27.03.2024 · `OneriSiparisOdakKullanici.OdakSifre` 7/8 dolu.

### Performans (03.10.2026 — ayrıntı: `docs/13-odak-performans.docx`, kod: düzeltme dosyası P-1..P-5)

`odakUrunAktar_job` ort. 217 sn (en uzun 295), günde 54 dk. En pahalı ifadeler (koşum başı): `odakFiyatAktarim` 117 fytOzl
yazımı 27 sn (S-1 döngüsü, 20 index) · 63 son alış seçimi 24 sn · `tsofturunaktarim` 177 açıklama kıyası 14,5 sn ·
stok 11 → 7,6 sn · `odakUrunAktar` ~25 öznitelik bloğu her biri 3,6-6,5 sn. Ölçülen öneriler: ortak eşleme blok başı
6,47 → 0,75 sn · fiyat seçimi mevcut index'le 19,3 → 9,05 sn (17 üründe farklı sonuç) · stok yerel 1,88 → 0,05 sn.
Reddedilen: ürün başı TOP 1 = 1.210 sn. TODO B-201.

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
