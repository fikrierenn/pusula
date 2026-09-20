# Plan 50 — Mağaza Ürün Bulma / Raf Adresi Uygulaması (BKM Mağaza)

**Tier:** 3 · **Tarih:** 20.09.2026 · **Talep:** GMY (Fikri Eren) · **Karar:** BYOD — herkes kendi telefonu → PWA
**Danışman:** `operasyon-danisman` kurulu · **Mockup:** `magaza/mockup/` (11 ekran) · `https://claude.ai/artifact/Jph1MioGGAtazwM6w5LRMP`
**Arşiv SQL:** `sorgular/2026-09-20-ryn-raf-haritasi-kesif.sql` · `sorgular/2026-09-20-magaza-app-kategori-ve-arama.sql`

> **Bu plan bir kez baştan yazıldı.** İlk sürümdeki "kapsama %74-81, yeni üründe %65" tablosu
> **yanlış paydaya** dayanıyordu (kitap + kırtasiye + oyuncak aynı kefede). GMY düzeltmesi
> (*"sadece kitap raflanıyor"*) ölçümle doğrulandı; doğru rakamlar §2.4'te. Eski rakamlar
> hiçbir yerde bırakılmadı.

---

## 1. Problem

Mağaza personeli bir ürünün (a) mağazada olup olmadığını, (b) nerede durduğunu, (c) fiyatını
müşteri yanındayken hızlı öğrenemiyor. Bugün bu iş **terminal sunucusundaki masaüstü
uygulamasından** yapılıyor (§2.2) — yani kasaya/bilgisayara gitmek gerekiyor.

Kaybın büyüklüğü **ÖLÇÜLMEDİ** — Faz 0 onu ölçer.

---

## 2. Ölçülmüş zemin (20.09.2026)

### 2.1 Hazır raflama alt sistemi VAR ve CANLI

`bkm` şemasında tam bir raf yönetimi API'si duruyor:

| Obje | Tür | İşi |
|---|---|---|
| `bkm.SUBE_RAFLARI` | view | Raf master — 23.327 raf (mekan, kat, alan, reyon, rafgrp, rafAD, **CokluRaf**) |
| `bkm.SUBE_RAF_LISTE` | view | Raf + ürün ataması (475.871 satır) |
| `bkm.SayimRaflari` | tablo | Ürün→raf adı (487.092) — **çoklu konumun yaşadığı yer** |
| `bkm.UrunRafla` · `UrunRafCikar` · `UrunRafBosalt` · `UrunTasi` · `UrunTumUrunleriCikar` | SP | raflama işlemleri |
| `bkm.SayimRafAktar` · `SayimRafGuncelle` · `RaflanmamisDuzenle` | SP | aktarım / güncelleme / raflanmamışları düzeltme |
| `bkm.SayimLog` | tablo | **13,5M+ satır** günlük (SayimLogId, LogDate, MekanId, RafNo, Tip, StokId) |

**Bakım canlı:** son kayıt ölçüm anında (20.09.2026 15:10). Son 30 günde raflama (Tip=6):
FSM 19.190 · İst.Yolu 16.876 · Özlüce 13.435 — **31 günün 31'inde** işlem.
⚠ `SayimLog`'da **kullanıcı kolonu YOK** → kişi bazlı raflama performansı çıkarılamaz.

### 2.2 Bugünkü araçlar — rakip masaüstünde

Canlı oturumlar (`sys.dm_exec_sessions`) DerinBilgi'nin thick-client takımını gösteriyor,
çoğu **`SRVTERM` terminal sunucusu** üzerinden:

`DerinSis` (56+46 oturum) · `UrunAnaliz` 34 · `Irsaliye` 20 · `DepoPaletTanim` 19 ·
**`UrunSorgulama` 8 (+4 IST-KIRTASIYE)** · `Siparis` 9 · **`DerinUs` 9+1** · `DepoEmir` ·
`MagazaKasa` · `CiroAnaliz` · `DerinHQ.Hub.Client` (NCRSERVER).

⇒ **Ürün sorgulama zaten var** (`UrunSorgulama`), ama masaüstü/terminal. El terminali tarafı
`DerinUs` (`drs.derinus1/2/3`, 5,99M + 1,59M + 0,73M satır; `derinus2` barkod/rafNo/palet taşır).
Yeni uygulamanın farkı: **rafın önünde, kendi telefonunda**.

**⭐ `SayimLog` ve `bkm.*` raflama SP'leri BKM'nin KENDİ sayım programına aittir**
(GMY bildirimi 20.09.2026: *"sayımlog bizim sayım programımız"*). Yani `UrunRafla` ·
`UrunTasi` · `SayimRafAktar` · `RaflanmamisDuzenle` DerinBilgi ürünü değil, BKM yazılımıdır —
`bkm` şeması adlandırması da bunu doğruluyor. Kaynak kodu bu depoda **DEĞİL** (arandı, yok);
nerede tutulduğu ve hangi cihazda koştuğu Faz 0'da netleşecek.

**Sonucu:** K8 (çakışma riski) sınıf değiştirdi — karşı taraf üçüncü parti değil, **aynı kurumun
kendi yazılımı**. Bu, v2'de raflama yazmasının mevcut SP'ler üzerinden yapılmasını gerçekçi kılar;
ama tek-yazıcı disiplini aynen geçerli: iki uygulama aynı veriye iki ayrı yoldan yazmaz.

### 2.2b ⭐ Kaynak kod BULUNDU: `D:\Dev\Bkm-Toolbox`

GMY yönlendirmesiyle bulundu (20.09.2026). .NET 10 WinForms çözümü; ilgili projeler:
**`BKmTerminal`** (el terminali) · **`BkmSayim`** (desktop, RDP ile) · `WMSTool` ·
`BKMIadeFatOlustur` · ortak `Core` + `Entites` (EF Migrations 2023-06).

`BKmTerminal` ekranları **bu planın v1 kapsamıyla birebir örtüşüyor**:
`FrmUrunKontrol` (ürün sorgulama) · `FrmUrunRafla` (raflama) · `FrmRafKontrol` · `FrmRafListele` ·
`FrmStokListele` · `FrmYazarListele` · `FrmGorsel` · `Sayım/RaflayarakSayim/FrmRaflayarakUrunSayim`.

**Hazır veri katmanı — yeniden yazılmayacak.** `Core/Get/Terminal/UrunRafBilgi.cs`
→ `UrunBilgiGetir(barkod)` tek sorguda şunları döndürüyor: barkod · ad · **yazar + YazarId** ·
Kategori3 · marka · satış fiyatı · **RafKodu + kat/alan/reyon/rafgrp** · tüm barkodlar ·
mağaza stoğu · **`Raflar` (string_agg — çoklu konum)** + `RafSayisi` + `CokluRaf` ·
**DepoStok** · **OdakStok** · özel fiyat · `SatisTur`. Ayrıca `bkm.SayimStokSatis` SP'si
ürün satış geçmişini veriyor (Hareket sekmesinin kaynağı).
⇒ Mobil app bu sorguları **port eder**, yeniden keşfetmez.

**Raflama akışı zaten "önce raf" (K9 doğrulandı):** `FrmUrunRafla` açılışta `txtRaf.Focus()` —
raf okutulmadan barkod alanına geçilmiyor. Mockup'taki Ekran 9 mevcut davranışla uyumlu.

**Yazar köprüsü:** `FrmYazarListele` yazarın kitaplarını `urn.kod5ID = YazarId` ile buluyor —
yani `bkm.UrunBilgi.YazarId` = `urn.kod5ID`. Arama tasarımı (§2.7) bu alanı kullanır.

#### ⚠ Devralınırken DÜZELTİLECEK iki kusur (mevcut kodda ölçüldü)

1. **SQL injection yüzeyi.** Sorgular string interpolasyonla kuruluyor
   (`WHERE bar.urnBarkod='{barkod}'`, `WHERE u.kod5ID={yazarId}`, `mekan={Tool.KullaniciMekanId}`).
   El terminalinde girdi çoğunlukla okuyucudan gelse de **elle giriş alanları var**
   (`txtRaf`, `txtBarkod`) ve `UrunYukleRafNo(rafNo)` doğrudan gömüyor. Port ederken
   **parametreli** yazılacak (`security-principles.md`). Mevcut uygulama için ayrı bir
   düzeltme işi olarak not edilmeli — bu planın kapsamı değil ama bildirilmeli.
2. **Merkez depo stoğu yanlış kaynaktan.** `DepoStok` = `stokSonAltDepo_vw` `ehMekan=12`,
   yani **ERP defteri**. BKM kuralı: merkez depo stoğu **HER ZAMAN WMS**
   (`sql-server-conventions.md`; ERP defteri mekan 12'de −4.242.441 adet negatif taşıyor).
   Mobil app WMS'ten okuyacak; aradaki farkın büyüklüğü Faz 0'da ölçülüp mevcut ekiple
   paylaşılmalı (terminalde bugün yanlış depo sayısı görülüyor olabilir).

### 2.3 ⚠ Çoklu konum — "tek raf" ölçümüm yanıltıcıydı

GMY: *"bir ürün birden fazla reyona girebilir — çok satanlar adaları, mağaza deposu gibi."*
Sebebi `bkm.UrunRafla` gövdesinde:

```sql
DELETE u FROM ... ryn.rafUrun u ... WHERE k.katMekan = @MekanId  -- mekandaki TÜM satırları sil
INSERT INTO ryn.rafUrun(...) VALUES(@RafId,@RafGrpId,@StkId,@RafSiraNo)
IF (@CokluRaf = 0)  -> SayimRaflari'nda sil-yaz      (tek konum)
ELSE IF NOT EXISTS  -> SayimRaflari'na EKLE          (ÇOKLU konum)
```

⇒ `ryn.rafUrun` ürün başına tek satır tutar; çoklu konum **yalnız `bkm.SayimRaflari`**'nda:

| Mekan | ürün | tek | 2 konum | 3+ | en fazla |
|---|--:|--:|--:|--:|--:|
| Özlüce | 163.801 | 158.076 | 4.961 | 764 | **20** |
| İst.Yolu | 141.986 | 139.209 | 2.487 | 290 | 8 |
| FSM | 170.059 | 168.833 | 1.094 | 132 | 5 |

İkinci adresler: `ADA-0013` · `KLADA-01..04` · `CO-ADA2/3` (**adalar**) · `HZDP*` `HZM*` `HZA*`
(**hazırlık / mağaza deposu**) · `VIP-0001` `STA-*` (**stant**).
`SUBE_RAFLARI.CokluRaf` (= `raf.rafOnyuzAdet`): 23.327 rafın **3.641'i** çoklu yerleşime açık.

> **KARAR: konum kaynağı `bkm.SayimRaflari`** (+ ad için `SUBE_RAFLARI`).
> `SUBE_RAF_LISTE` tek kaynak yapılırsa ada ve depo konumları **sessizce kaybolur**.

### 2.4 ⭐ RAF YALNIZ KİTAPTA — kapsama aslında neredeyse tam

GMY: *"sadece kitap raflanıyor, kırtasiye oyuncak hediyelik ürünler rafsız."* Ölçüldü (FSM, stoktaki çeşit):

| Kategori | stokta | rafı var | oran |
|---|--:|--:|--:|
| Edebiyat Kitapları | 35.992 | 35.979 | **%100,0** |
| Çocuk Kitapları | 27.132 | 26.547 | %97,8 |
| Tarih / İslam / Akademik / Felsefe … | — | — | %99,2–100 |
| **Kırtasiye** | 32.368 | 205 | **%0,6** |
| **Hobi ve Oyuncak** | 6.152 | 723 | **%11,8** |
| **Hediyelik** | 2.197 | 4 | **%0,2** |
| **Elektronik / Süpermarket** | 1.072 | 0 | **%0,0** |

Doğru paydayla (kitap / kitap dışı):

| Mekan | KİTAP çeşit | raflı | oran | KİTAP DIŞI | raflı | oran |
|---|--:|--:|--:|--:|--:|--:|
| FSM | 123.545 | 122.500 | **%99,2** | 52.250 | 11.289 | %21,6 |
| Özlüce | 121.274 | 120.056 | **%99,0** | 55.818 | 11.329 | %20,3 |
| İst.Yolu | 109.842 | 109.224 | **%99,4** | 42.983 | 15.288 | %35,6 |

**Yeni ürün korkusu da dağıldı** — kitapta (FSM): son 90 günde gelen **%96,7** · 90g-1yıl %99,3 ·
eski %99,2. İlk sürümdeki "%65,4" tamamen kategori karmasıydı.

⇒ **Gerçek eksik FSM'de 1.045 kitap** (123.545 − 122.500). Bu, yönetilebilir bir görev listesidir
(Ekran 8), "veri bakım krizi" değil. Kitap dışı ürünlerde raf adresi **beklenmez** — ekranda
"eksik" gibi gösterilmesi hatadır (Ekran 6 bu yüzden ayrı).

### 2.5 Raf granülaritesi gerçek

Raf başına ürün: FSM ort. 29,9 · Özlüce 23,7 · İst.Yolu 22,7; mağaza başına 5.688-6.898 raf.
Dev kovalar küçük: FSM `SHF-0001` 3.693 ürün (%2,2, "Sahaf" reyonu) · İst.Yolu %3,2 · Özlüce %1,3.
⚠ `RafSira` **fiziksel sıra değil**, ekleme sayacıdır (çöp rafta 3.976'ya çıkıyor) — arayüzde kullanılmaz.

### 2.6 ⚠ Mağaza krokisi ÇİZİLEMEZ

`ryn.reyon.reyonX` / `reyonY` / `reyonEbat` kolonları var **ama 576 reyonun 576'sında BOŞ (0)**.
İlk sürümde "koordinat var → kroki mümkün" yazmıştım; o bir **çıkarımdı**, ölçüm çürüttü.
Kroki istenirse ayrı bir veri-girişi işidir.

### 2.7 Arama — yazar verisi dağınık (ÖLÇÜLDÜ)

GMY: *"yazar isimleri çok sıkıntılı, aynı yazar 3-5 farklı şekilde yazılmış olabilir."* Ölçüm:

- `bkm.UrunBilgi.Yazar`: **173.055 farklı yazım**. Basit normalizasyon (boşluk/nokta/virgül,
  Turkish_CI_AI) yalnız 586'sını birleştiriyor — sorun büyük/küçük harf değil.
- **Soyad tokenıyla anahtarlama 59.201 kümeye indiriyor (%66 birleşme)**; 1.381 kümenin soyadı
  3 harften kısa (riskli).
- Somut vaka: `Fyodor Mihayloviç Dostoyevski` 900 kitap · `Fyodor Mihailoviç Dostoyevski` 3 ·
  `Fyodor Dostoyevski` 2 · `Fyodor Dostoyevsky` 2 — **dördü ayrı `YazarId`**.
- ⚠ **Soyad kimlik DEĞİL, aday üretir:** aynı soyadda `Anna Grigoriyevna Dostoyevski` (4 kitap) ve
  `Aimee Dostoyevski` (1) **başka kişilerdir**. Otomatik birleştirme yanlış olur — kullanıcı seçer.

**Arama sözleşmesi (v1):**
1. **Sıralama:** (1) burada stokta **ve** raflı → (2) burada stokta → (3) başka noktada var
   (diğer mağaza / merkez depo / e-tic) → (4) hiçbir yerde yok **en altta, soluk**.
2. Barkod tam eşleşme → tek sonuç, doğrudan ürün kartı.
3. Türkçe karakter duyarsız (`Turkish_CI_AI`) — "kurk mantolu" → "Kürk Mantolu".
4. Kelime sırası serbest (her token AND'li), önek eşleşmesi.
5. **"Şunu mu dedin"**: sonuç yoksa/azsa soyad kümesi + baş harf ile aday yazar önerisi,
   varyantlar rozet olarak gösterilir (kaç kitap taşıdığı yazılır).
6. Perf: `stkID IN (alt-sorgu UNION)` deseni zorunlu — `OR EXISTS` 5,8s, bu yol 0,14s.

### 2.8 Görsel

`ent.tsoft_urun.ImageUrl`: 441.163 satırın **441.097'si dolu (%99,98)**; değer dosya adı → CDN tabanı gerek.
⚠ Kapsam e-ticarete açılmış ürün; mağaza stoğuna göre kapsama ÖLÇÜLMEDİ. `web.urnWeb` BOŞ.

### 2.9 Stok tabanı

Mağaza `dbo.stokSonAltDepo_vw` · **merkez depo HER ZAMAN WMS** · kasa→ERP aktarımı **saatlik**
(gün içi ERP eksik) · e-tic `ent.odak_depo_Stok` · WMS hayalet stok 349 çeşit.
⚠ **Adet konum bazında ayrışmaz** — "adada kaç tane" cevaplanamaz, ekranda yazar.

---

## 3. Kurul eleştirisi (revize)

**K1 — Veri bakım riski büyük ölçüde YOK.** Kitapta kapsama %99+ ve süreç günlük işliyor.
Kalan iş 1.045 kitaplık kuyruk ve onun görünür kılınması. (İlk sürümdeki alarm yanlış paydadandı.)

**K2 — Başarı metriği "kullanım" değil** (§5).

**K3 — Bildirim kişiye yazılmaz.** Ceza aracına dönerse veri ölür. (`SayimLog`'da kullanıcı yok.)

**K4 — Transfer talebi sahipsizse v1'den çıkar.**

**K5 — HEYKEL haritasız** → ya harita çıkar ya "yalnız stok+fiyat" modunda açılır, ekranda yazar.

**K6 — Mağaza kıyası yapılamaz** (Sınav taşınması, kapı sayıcı yalnız FSM, kategori karması).

**K7 — Müşteriye açık kiosk v1'de yok.** Kitapta %99 iyi olsa da kırtasiyede raf yok; müşteri
"nerede" sorusunun yarısına cevap alamaz.

**K8 — Mevcut sistemle çakışma (REVİZE).** Günde ~1.600 raflama yapan istemci **BKM'nin kendi
sayım programı** (§2.2). Üçüncü parti engeli yok; risk teknik değil **ürün stratejisi**:
iki BKM uygulaması aynı işi iki yerden yaparsa personel hangisini kullanacağını bilemez ve
harita iki yoldan bozulur. ⇒ Sınır net çizilmeli (§4.5). v1 salt-okuma; yazma gerekirse
**mevcut SP'ler** çağrılır, ikinci yazma yolu açılmaz.

**K9 (YENİ) — Raflama RAFTA okutularak yapılır.** GMY kuralı: raf elle seçilemez; atama ancak
rafın etiketi okutulduktan sonra. Aksi hâlde uygulama "masa başından raf atama" aracına döner ve
haritayı bozar. Ekran 9 buna göre kurgulandı.

**K10 (YENİ) — Yazar birleştirme sessizce yapılamaz.** Otomatik soyad birleştirme Anna/Aimee
Dostoyevski'yi Fyodor'a yazar. Öneri gösterilir, seçim kullanıcınındır (§2.7).

---

## 4. Kapsam

### 4.1 v1 — YAPILACAK (salt-okuma, **yalnız ÜRÜN BULMA**, 6 ekran)

> **KAPSAM DARALTILDI (GMY, 20.09.2026):** *"sadece ürün bulma falan kısımlarını yapalım."*
> Raflama, sayım, görev kuyruğu ve transfer talebi v1'de **YOK** — bunlar mevcut
> `BKmTerminal` uygulamasının işi ve orada kalıyor. v1'in tek işi: **ürünü bulmak.**

1. **Akıllı arama** (§2.7 sözleşmesi) — stoksuzlar en altta, "şunu mu dedin", yazar kümesi.
2. **Barkod okut** — iOS için wasm (ZXing) fallback.
3. **Sonuçlar** — üç grup: burada var / başka noktada / hiç yok (soluk).
4. **Kitap kartı** — kapak · fiyat · stok · **ana raf** + **ek konumlar** (ADA/DEPO/STANT) ·
   son raflama yaşı · diğer noktalar (mağazalar + merkez depo + e-tic).
5. **Kitap · rafı atanmamış** — durum ekranı: "rafı yok" dürüstçe söylenir, aynı yazar/yayınevinin
   rafları gösterilir. ⚠ v1'de **atama YOK** — atama `BKmTerminal`'de yapılır.
6. **Kırtasiye · raf sistemi dışı** — "eksik değil, kural bu"; reyon düzeyi bilgi.
7. **Müşteriye göster** — fiyat + raf + var/yok; adet ve maliyet gizli.

**v1'de YAZMA HİÇ YOK.** §4.3'teki iki app-owned tablo da v1'den çıktı — hiçbir tablo
oluşturulmuyor, ERP salt-okuma. Bu, Faz 0'daki onay yükünü de kaldırır.

### 4.2 v2 (mockup'ta çizili, kapsam dışı)

**Reyon görevlerim** (raflanmamış kitap kuyruğu) · **Rafı doğrula** (rafta okutarak) ·
**Rafta bulamadım** bildirimi · **Transfer iste**. Dördü de bir **kuyruk sahibi** ister
(K3/K4) ve raflama tarafına dokunur — `BKmTerminal` ekibiyle (Erkan) birlikte kararlaştırılır.

### 4.2b Daha sonra

Atama/düzeltmenin **mevcut SP'ler üzerinden** yazması (müdür onayı) · reyon sorumlusu
(`bkm.OneriSiparisReyon`) · yazar otoritesi tablosu (kalıcı kümeleme) · HEYKEL haritası ·
mağaza krokisi (önce koordinat verisi girilmeli, §2.6) · planogram uyumu.

### 4.3 Yeni app-owned tablolar — **v1'de YOK, v2 işi**

`bkm.MagazaRafBildirim` · `bkm.MagazaTransferTalep` yalnız v2'de gündeme gelir ve o zaman
GMY onayı + `erp-write-policy.md` güncellemesi gerekir. **v1 hiçbir tablo oluşturmaz.**

### 4.5 Mevcut sayım programıyla sınır (AÇIK KARAR — GMY)

`SayimLog`'u yazan program BKM'nin kendi yazılımı olduğu için üç yol var:

| Yol | Ne demek | Bedeli |
|---|---|---|
| **A — Yan yana (v1 planı)** | Mobil app salt-okuma + bildirim/öneri; raflama ve sayım eski programda kalır | En hızlı, en düşük risk. İki uygulama yan yana yaşar; personel "nerede ne yapılır"ı öğrenmek zorunda |
| **B — Raflamayı devral** | Mobil app rafta okutarak raflar (mevcut SP'leri çağırarak); sayım eski programda kalır | Tek yazma yolu korunur (SP'ler). Eski programın raflama ekranı kapatılmalı, yoksa çift kapı |
| **C — Sayım programını kapsa** | Sayım + raflama + sorgulama tek mobil app | En temiz son durum, en büyük iş. Sayım akışı (parti, sayfa, fark raporu) baştan tasarlanır |

> **✅ KARAR: A (GMY, 20.09.2026).** Mobil app salt-okuma başlar; raflama ve sayım BKM'nin
> mevcut programında kalır. B (raflamayı devralma) Faz 4 hedefi olarak açık tutulur, C
> gündemde değil. Bu karar §4.1 kapsamını ve §7 mimarisini olduğu gibi geçerli kılar —
> yazma katmanı v1'de kurulmaz.

**Mevcut programın koştuğu yer (GMY, 20.09.2026):** hem **el terminali** hem **uzak masaüstü
üzerinden desktop uygulaması**. Bu, §2.2'deki oturum tablosuyla tutarlı: `SRVTERM` = RDP
oturumları, `DerinUs` = el terminali kolu.

⚠ **Bundan doğan asıl soru teknik değil, benimseme:** personelin elinde zaten bir el terminali
varken telefon neden kullanılsın? Dürüst cevap ve v1'in tek gerekçesi şu olmalı — el terminali
**sayım/raflama işinin aracı**, sayıca sınırlı ve depo-odaklı; telefon **her personelde** ve
müşteri yanındayken elinin altında. Bu iddia Faz 0'da ölçülür (R9).

### 4.4 ASLA

❌ Müşteriye açık kiosk (K7) · ❌ kişi bazlı bildirim raporu (K3) · ❌ mağaza karnesi (K6) ·
❌ ERP'ye yazan transfer · ❌ `ryn.*`'a kendi yazma yolu (K8) · ❌ masa başından raf atama (K9) ·
❌ otomatik yazar birleştirme (K10) · ❌ offline cache (BYOD/KVKK) · ❌ RFID.

---

## 5. Başarı ölçütü + karşı-metrik

| # | Ölçüt | Kaynak | Karşı-metrik |
|---|---|---|---|
| **B1** | **Kitap** kapsaması (payda = kitap, §2.4) | haftalık sorgu | Kitap dışı ölçüye KARIŞTIRILMAZ |
| ~~B2~~ | ~~Bildirim / arama oranı~~ | — | **v2** (bildirim v1'de yok) |
| **B3** | Arama → kart → sonuç tamamlanma | app log | Tek başına hedef değil (K2) |
| **B4** | Bulunurluk (OSA) etkisi | `bkm.BulunurlukOzet` | Nedensellik iddia edilmez |
| **B5** | Raflama gecikmesi (giriş → ilk `SayimLog` Tip=6) | SayimLog + irsHrk | Hız artarken yanlış raflama (B2) artıyor mu |
| **B6** | "Sonuç bulunamadı" oranı | app log | Düşerken yanlış eşleşme artmasın (B2) |

**Eşik:** kitapta kapsama **%98 altına inerse** operasyon bulgusudur (bugün %99,0-99,4).
⚠ %98 SEÇİLMİŞ eşiktir; ilk çeyrek sonunda gözden geçirilir.

---

## 6. Yönetişim

| Rol | Sorumluluk |
|---|---|
| Reyon sorumlusu | Yeni kitabı rafa koyarken **rafta okutarak** raflar (mevcut süreç) |
| Mağaza müdürü | Bildirim + atama öneri kuyruğunu haftalık kapatır |
| Merkez (IT/operasyon) | Haftalık B1/B5/B6; eşik altına inince uyarı |

---

## 7. Mimari

Ayrı **Blazor PWA** (`BkmMagaza`) · BYOD: PIN + uzun ömürlü token (uzaktan iptal), offline veri yok ·
barkod: Android native API, iOS wasm (ZXing) · veri: `Db.OpenAsync` salt-okuma, **3-parçalı isim** ·
konum `bkm.SayimRaflari` + `bkm.SUBE_RAFLARI` · stok `stokSonAltDepo_vw` / WMS / ODAK ·
görsel `ent.tsoft_urun.ImageUrl` + CDN · yazma yalnız iki app-owned `bkm.*` tablo.

---

## 8. Fazlar

**Faz 0 — kısaldı (kod yok).** Sınır kararı ✅ A · cihaz ✅ (el terminali + RDP desktop) ·
kaynak ✅ `D:\Dev\Bkm-Toolbox` · **bakım ✅ Erkan** · R9 ✅ (terminal sayısı yetersiz) ·
yazma onayı **gerekmiyor** (v1'de tablo yok).
Kalan: (a) **Erkan ile hizalanma** — `BKmTerminal` sorgularının portu, iki kusurun bildirimi
(§2.2b), v2 sınırı; (b) terminal/personel oranını kayda geç; (c) ~20 gözlemlik iş etüdü
(bugün ürün ararken ne yapılıyor, kaç dakika) — B1/B3/B6 için "önce" tabanı;
(d) 1.045 kitaplık eksik listesini çıkar,
reyonlara dağıt; (c) ~20 gözlemlik iş etüdü (personel kaç kez arıyor, kaç dakika); (d) GMY onayı:
iki tablo + yönetişim + HEYKEL.

**Faz 1 — Veri katmanı + değişmezler.** `sqlcli assert`: (i) çoklu konum sayısı > 0 (ada/depo
kaybolursa kırmızı), (ii) `SUBE_RAF_LISTE` satırı = çift-kolon join satırı, (iii) **kitap**
kapsaması eşiği, (iv) `SayimLog` son 24 saatte hareket. Kırılabilirlik kanıtı zorunlu.

**Faz 2 — PWA iskelet** (kimlik, akıllı arama, kart, barkod).

**Faz 3 — FSM pilotu** 2-4 hafta; B1-B6.

**Faz 4 — Yaygınlaştırma + v2.**

---

## 9. Reddedilen alternatifler

| Alternatif | Neden |
|---|---|
| Dashboard içine mobil rota | GMY paneli; personel kitlesi/yetki/mobil yerleşim sığmaz |
| Zebra/Android native | BYOD kararı; Zebra zaten PWA koşturur |
| Mevcut `UrunSorgulama`'yı mobile port etmek | Terminal-sunucu thick client; kaynak DerinBilgi'de, mobil tasarım yok |
| RFID | Kitapta etiket maliyeti |
| Raf verisini sıfırdan kurmak | 475.871 satır + günlük bakım var |
| `SUBE_RAF_LISTE` tek kaynak | Ada + depo konumlarını düşürür (§2.3) |
| Otomatik yazar birleştirme | Farklı kişileri birleştirir (§2.7, K10) |
| Mağaza krokisi v1'de | Koordinat verisi boş (§2.6) |

---

## 10. Riskler

| # | Risk | Ölçülmüş | Azaltma |
|---|---|---|---|
| R1 | ~~Yeni üründe kapsama düşük~~ | ✅ **ÇÜRÜTÜLDÜ** (kitapta %96,7) | — |
| R2 | Kitap dışı üründe "nerede" sorusu cevapsız | ✅ (%0,6-11,8) | Ekran 6: reyon düzeyi + "kural bu" |
| R3 | Bildirim/öneri kuyruğu sahipsiz | ✗ | §6; sahipsizse v1'den çıkar |
| R4 | Gün içi ERP eksik | ✅ (saatlik) | Ekranda uyarı |
| R5 | Mevcut raflama istemcisiyle çakışma | ✅ (canlı) | v1 salt-okuma (K8) |
| R6 | Yanlış yazar birleştirme | ✅ (Anna/Aimee) | Öneri + kullanıcı seçimi (K10) |
| R7 | Adet konum bazında yok | ✅ | Ekranda yazar |
| R8 | BYOD kayıp/KVKK | ✗ | Offline veri yok, token iptal |
| ~~R9~~ | ~~El terminali zaten var → telefon benimsenmez~~ | **ÇÖZÜLDÜ** | GMY (20.09.2026): **terminal sayısı yetersiz.** Telefonun gerekçesi budur: her personelde var. Sayısal oran Faz 0'da yine de kayda geçer |

---

## 11. Done criteria (v1)

- [ ] Erkan ile hizalanma yapıldı (port kapsamı + iki kusur bildirimi + v2 sınırı)
- [ ] `sqlcli assert` değişmezleri yazıldı ve kırılabilirliği kanıtlandı
- [ ] **7 ekran** çalışıyor; iOS Safari + Android Chrome barkod okuyor
- [ ] Çoklu konum (ada/depo/stant) kartta görünüyor
- [ ] Arama sözleşmesi (§2.7): stoksuz en altta, "şunu mu dedin", Türkçe duyarsız
- [ ] Kitap / kitap-dışı ayrımı doğru (kırtasiyede "rafı yok" uyarısı ÇIKMIYOR)
- [ ] Merkez depo stoğu **WMS'ten** okunuyor (mevcut terminalin kusuru tekrarlanmıyor)
- [ ] Tüm sorgular parametreli (injection yüzeyi porta taşınmadı)
- [ ] **Hiçbir yere yazılmıyor** — ne ERP'ye ne yeni tabloya
- [ ] FSM pilotu koştu; B1/B3/B4/B5/B6 "önce/sonra" tablosu
- [ ] Sema + arşiv SQL yazıldı

## 12. Rollback

PWA ayrı deploy → kapatmak tek adım. **v1 salt-okuma ve tablosuz** olduğu için geri alınacak
hiçbir veri durumu yok: uygulama kapatılır, arkasında iz kalmaz.
