# plan-43 — Merkez Depo WMS ↔ ERP Defter Eşitlemesi

**Durum:** BEKLEMEDE (ölçüm + mekanizma çözümlemesi bitti, uygulama yapılmadı)
**Açılış:** 09.09.2026 · **Tier:** 3 · **Sahip:** Fikri Eren (GMY)
**Kısıt (kullanıcı, verbatim):** _"aman tablolara dokunma sakın"_ → bu plan hiçbir tabloya
yazmadı ve yazmayacak; uygulama kararı ve koşumu kullanıcıdadır.

> Bu doküman, konuyu **hiç bilmeyen birinin** sıfırdan hakim olabilmesi için yazıldı.
> Sırayla okuyun; §1-§3 zemin, §4-§6 mekanizma, §7-§9 karar ve uygulama.

---

## 1. Problem tek paragrafta

BKM'nin merkez deposunda (mekan 12) stok **iki yerde** tutuluyor: WMS (hücresel — hangi
palet, hangi adres) ve ERP defteri (`irsHrk` hareket toplamı). İkisi birbirini tutmuyor.
Panel ve raporlar merkez stoğunu WMS'ten okuyor (kural: `sql-server-conventions.md` §MERKEZ
DEPO STOĞU), çünkü ERP defteri fiziksel olarak imkânsız negatifler taşıyor. Ama WMS de
mutlak doğru değil: ERP'de kesilen bir satış WMS'ten düşülmediğinde WMS şişik kalıyor
("hayalet stok"). Sonuç: **17.027 çeşitte iki sistem farklı sayı söylüyor** ve hiçbir
otomatik mekanizma bunu kapatmıyor.

---

## 2. Sözlük — isim tuzakları (ÖNCE BUNU OKU)

Bu alanda kolon adları yanıltıcı. Yanlış okuma = sessiz yanlış rakam.

| İsim | Gerçekte ne | Tuzak |
|---|---|---|
| `depo.stok_adres_palet_vw.Stok` | `SUM(paletUrnTnm.pUAdetN)` | View **`pUAdetN > 0` süzüyor** → sıfır ve negatif satırlar GÖRÜNMÜYOR |
| `depo.sayım` / `sayımAyr` | WMS sayım **beyanı** | Türkçe ı ile. `sayımAyr.sAyrID` = sayım başlığı ID'si (satır ID'si değil) |
| `sayımAyr.spID` | **PALET** id | "sp" stok-palet; ürün değil |
| `sayımAyr.spStkID` | ürün (stkID) | — |
| `sayımAyr.sAdrsID` / `sSonPozAdrsID` | **KULLANILMIYOR** | `depo.sayimIsle` bu ikisini hiç okumuyor (§4) |
| `depo.emirAyr.emİlkPozID` | **PALET** id | Türkçe İ. ASCII `emIlkPozID` → Err 207 |
| `depo.emirAyr.emSonPozID` | **ÜRÜN (stkID)** | "Poz" diyor ama pozisyon DEĞİL. Kanıt: `paletUrnTnm ON pUID=emİlkPozID AND pUStkID=emSonPozID` |
| `depo.emirAyr.emAyrID` | **EMİR** id (`depo.emir.emID`) | satır ID değil |
| `depo.paletIcHrk.piİlkID` | hareketin **sahibi** palet | Türkçe İ zorunlu |
| `depo.adresSnl.adrs3` | adres koordinatı (0..12, kat) | `adrs3 = 0` olan 3.231 adres sayım emrinden ATILIYOR (§5) |
| `depo.adres.adrsAlanTipID` | 0 RAF · 1 GİRİŞ · 2 ÇIKIŞ · 5 HAVUZ · 6 İADE | Merkez stoğu = 0 + 1. ÇIKIŞ sevke hazır mal, sayılmaz |
| `irs.eTip = 99` | 'Sayım' (`dbo.irsTip_vw`) | 16 'Stok EKLE' · 90 'Ürün SAY' ayrı |
| `ent.odak_depo_Stok` | ODAK e-ticaret deposu | Merkez depo DEĞİL, karıştırma |

---

## 3. Ölçülen büyüklük (09.09.2026)

### 3.0 KAPSAM DÜZELTMESİ — ÇIKIŞ ALANI dahil (ölçümle karara bağlandı)

İlk ölçüm panel kuralını (RAF+GİRİŞ, ÇIKIŞ hariç) kopyalamıştı. **Yanlış kapsam.**
Panel "satılabilir stok" sorar; mutabakat "defterde ne var" sorar. ÇIKIŞ alanındaki mal
sevke ayrılmış ama hâlâ bizim ve ERP defterinde duruyor.

| Mutabık (WMS == ERP) ürün sayısı | |
|---|---|
| `adrsAlanTipID IN (0,1)` | 409.229 |
| süzgeç yok (0+1+2) | **417.812** |
| yalnız ÇIKIŞ dahil olunca mutabık olan | 9.820 ürün |
| yalnız ÇIKIŞ hariç olunca mutabık olan | 1.237 ürün |

8× asimetri → tesadüf açıklaması elendi. **Mutabakat kapsamı: tüm alanlar.**
Uyumsuz çeşit **17.027 → 8.476**. Ayrıca ölçüldü: mekan 12 defterinde `ehAltDepo`
tek değer 0 (39.858.210 satır) → alt depo süzgeci gereksiz.
⚠ İki kapsam karıştırılmaz — panel stoğu (0,1) · defter mutabakatı (0,1,2).

### 3.1 EVREN DÜZELTMESİ — hizmet/sarf kalemleri farkın %96'sıydı

`urnTip = 0` guard'ı yetmiyor. `KARGO GELİRİ` (stkID 144860) urnTip=0, satisTur=0,
`urnKtgrID=10` ("Çocuk Kitapları" — veri kiri) → guard'a takılmıyor. Farkın iki tarafını
da **5 kalem** taşıyordu, hiçbiri WMS'te yok (`Wms = 0`):

| stkID | Ad | Kategori3 | ERP defteri | Yarattığı sahte fark |
|---|---|---|---|---|
| 144860 | KARGO GELİRİ | KARGO | −2.798.582 | GİRİŞ +2.798.582 |
| 583160 | Geri Dönüşüm Kağıt Madde Alımı | Genel | +1.764.200 | ÇIKIŞ −1.764.200 |
| 144963 | KAPIDA ÖDEME GELİRİ | KARGO | −1.194.588 | GİRİŞ |
| 436306 | KOMİSYON BEDELİ | KARGO | −207.999 | GİRİŞ |
| 1543633 | TANIMSIZ ÜRÜN %20 | Tanımsız | +37.504 | ÇIKIŞ |

Bunlar hizmet/sarf/muhasebe kalemi — WMS'te hiç durmazlar. **Düzeltilmez, evrenden
çıkarılır.** Süzgeç kategori bazlı (elle stkID listesi tutulmaz):
`bkm.UrunBilgi.Kategori3 NOT IN ('KARGO','Genel','Tanımsız','Zkargo')`.

### 3.2 Fark (TÜM ALANLAR, hizmet/sarf hariç) — GERÇEK BÜYÜKLÜK

Kaynak: [sorgular/2026-09-09-wms-erp-sayim-evraki-URET.sql](../sorgular/2026-09-09-wms-erp-sayim-evraki-URET.sql) Blok 1-3.

| Belge | Çeşit | Adet | Maliyet proxy | Maliyeti bilinmeyen |
|---|---|---|---|---|
| **GİRİŞ** `@GC=0` — ERP eksik | 5.443 | 152.105 | 231.979 ₺ | 3.761 çeşit |
| **ÇIKIŞ** `@GC=1` — ERP fazla | 2.952 | 41.952 | 177.172 ₺ | 1.450 çeşit |
| Net defter etkisi | — | **+110.153** | **~+54.806 ₺** | 5.211 çeşit |

⚠ Hariç bırakmadan önceki (yanlış) rakam: GİRİŞ 4.389.670 adet / 32.304.553 ₺ ·
ÇIKIŞ 1.843.671 / 180.134 ₺ → net +32,1M ₺. **Kapsam hatası tutarı 590 kat
şişiriyordu.** "urnTip=0 → gerçek ürün" bir ÇIKARIMDI, ölçüm değildi.

### 3.2 Eski (yanlış kapsamlı) ölçüm — tarihsel kayıt

RAF+GİRİŞ ile: ERP eksik 3.562 çeşit / 4.258.229 adet · ERP fazla 13.465 / 2.254.001.
"ERP fazla" tarafı ÇIKIŞ alanı hariç bırakıldığı için **şişikti** — 9.820 ürün sahte
uyumsuz görünüyordu.

Sınıf dağılımı (aynı gün, biraz farklı süzgeçle ölçüldü — mertebeler geçerli):
ikisi de boş 390.514 · **MUTABIK 17.960** · ERP negatif 3.011 (−4.244.015 adet) ·
hayalet 244 çeşit / 738 adet · defter kalıntısı 9.230 / 1.997.663 · WMS fazla 754 / 10.818 ·
ERP fazla 4.574 / 261.234.

### 3.3 Parasal etki — YÖN BİLE ÖLÇÜME BAĞLI (kritik uyarı)

Aşağıdaki tablo **eski (RAF+GİRİŞ) kapsamla** ölçüldü; dersi kapsamdan bağımsız geçerli:

| Yön | Etiket fiyatıyla (`urn.fiyatS`) | Maliyetle (`ORT_ALIS` proxy) | Maliyeti bilinmeyen |
|---|---|---|---|
| ERP azalır | 70.434.250 ₺ | **1.639.833 ₺** | 7.201 çeşit |
| ERP artar | 6.835.396 ₺ | **32.154.572 ₺** | 2.410 çeşit |
| **Net** | **−63,6M ₺ (düşüş)** | **+30,5M ₺ (ARTIŞ)** | 9.611 çeşit |

Doğru evrenle (§3.2) net etki **~+54.806 ₺** — ders şu: hem taban (etiket/maliyet) hem
evren (hizmet/sarf) yanlışken tutar 32 milyon görünüyordu, ikisi düzeltilince ~55 bin.

### 3.4 GEÇMİŞ: Aralık 2025 temizliği (kullanıcı hatırlattı, ölçümle doğrulandı)

Kullanıcı: _"ben yılbaşında sıfırlamıştım diye hatırlıyorum eşitlemiştim daha doğrusu"_ — **doğru.**

Merkez defterinde NEGATİF bakiyeli çeşit sayısı, yıl sonları itibarıyla:

| Tarih | Negatif çeşit | Negatif adet |
|---|---|---|
| 31.12.2021 | 11.896 | −1.023.505 |
| 31.12.2022 | 171.143 | −6.236.968 |
| 31.12.2023 | 243.606 | −12.988.784 |
| 31.12.2024 | 298.353 | −19.656.508 |
| **31.12.2025** | **37** | **−4.221.086** |

Kırılma Aralık 2025 içinde: 01.12.2025'te 302.859 çeşit → 31.12.2025'te 37.

**Hangi mekanizma:** sayım evrakı DEĞİL. Aralık 2025'te mekan 12'de
`ehTip=88 'Diğer Giriş'` **310.116 satır / 310.100 çeşit / +22.859.643 adet** ve
`ehTip=89 'Diğer Çıkış'` 26.291 satır / −40.073.558 adet işlendi. Aynı ayın `eTip=99`
sayım hacmi yalnız 44 satır.

**Kalıcı olmadı — sızıntı sürüyor:**

| İtibarıyla | Negatif çeşit |
|---|---|
| 31.12.2025 | 37 |
| 31.01.2026 | 27 |
| 31.03.2026 | 80 |
| 30.06.2026 | 584 |
| 09.09.2026 | **2.545** |

Yani tek seferlik temizlik çözüm değil; **tekrar eden bir mekanizma** gerekiyor. Kalan
−4,22M adedin %99,5'i zaten hizmet kalemi (§3.1) — mutabakat evreni dışı.

**Doğrulanamayan:** o temizliğin WMS'e mi eşitlendiği geriye dönük ölçülemiyor —
`bkm.StokAyBakiyeMekanBazli` mekan 12 için yalnız tek dönem taşıyor (2026-08-31),
Aralık-2025 WMS snapshot'ı yok.

**Ek gerçek:** `depo.sayım` zinciri (JOKER eşitleme deseni) **22.01.2024'te durmuş** —
o tarihe kadar her gün `kKisi=323 / sDepoID=12 / paletBazliSifirlansin=1` kaydı var.
Sonrası yalnız iki başıboş satır: 08.04.2025 (1 satır) ve 13.01.2026 (`sNo='reyreu'`,
0 satır, `sDurum=0` — yarım kalmış).

**Yorum:** etiket fiyatı stok değeri için yanlış tabandır (stok maliyetle taşınır).
Etiketle "72M ₺ stok silinecek" gibi görünen tablo, maliyetle **tersine** dönüyor: az
sayıda ama pahalı ürün ERP'de eksik, çok sayıda ama ucuz ürün ERP'de fazla. Kesin tutar
ancak `bkm.UrunMaliyet` ürün-ürün koşularak bulunur; **9.611 çeşitte maliyet bilinmiyor
ve o ürünler deftere 0 ₺ ile girer** (§6.4).

---

### 3.5 Aralık 2025 eşitlemesi WMS'E YAPILMIŞ — kanıtlandı, ve problemi yeniden tanımlıyor

Kullanıcı: _"wms ile aynı yapmıştım stokları"_. Geriye dönük WMS snapshot olmadığı için
dolaylı test kuruldu: **eşitlemeden beri hiç hareket görmemiş ürünler bugün mutabık mı?**

| Grup (hizmet/sarf hariç) | Çeşit | Mutabık | Uyumsuz | Mutabık % |
|---|---|---|---|---|
| 2026'da **hiç hareket yok** (ne ERP ne WMS) | 6.182 | 6.181 | 1 | **%99,98** |
| 2026'da hareket var | 29.238 | 21.011 | 8.227 | %71,86 |

**Eşitleme tuttu.** Dokunulmayan 6.182 çeşidin 6.181'i hâlâ birebir aynı. Yani bugünkü
farkın **tamamı 2026 hareketlerinden** doğuyor — tarihsel birikmiş kir değil.

Nicel doğrulama — 2026 delta farkı, mevcut farkı birebir açıklıyor:

| Grup | Çeşit | 2026 ERP Δ | 2026 WMS Δ | Δ farkı | Mevcut fark |
|---|---|---|---|---|---|
| Mutabık | 27.192 | +487.879 | +493.176 | −5.297 | 0 |
| ERP eksik | 5.224 | +161.327 | +306.224 | −144.897 | **+151.670** |
| ERP fazla | 2.952 | −36.129 | −72.074 | +35.945 | **−37.791** |

WMS her iki yönde de ERP'den daha çok hareket ediyor → **ERP hareketleri kaçırıyor.**

#### Sızıntı kaynakları (ölçüldü, sıralı)

1. **`pHrkTip = 0` KULLANICI (manuel WMS hareketi)** — baskın kanal. ERP-eksik grubunda
   belgeli +745.077 · belgesiz −357.759 · SAYIM (tip 2) −81.094 → net +306.224
   (WMS Δ ile birebir). `pHrkTip = 1` EMİR hareketleri net **0** (iç taşıma, beklenen).
2. **`ehTip = 2` Alış İade → %84,65 uyumsuz** (2.358 çeşitten 1.996). Baskın yön
   **ERP fazla**: 1.748 çeşit / 21.602 adet = tüm ERP-fazla farkının **%51'i**.
   Mal WMS'ten çıkmış, iade ERP'de tam işlenmemiş.
3. **Onaylanmamış irsaliye** — katkı var ama tek başına açıklamıyor: onaysız belgede geçen
   1.881 çeşidin %44,28'i uyumsuz (2026'da hareket görenlerin taban oranı %28).
   Onaysız hacim: `eTip 13` Depo→Mağaza 11 belge / 1.974 satır / +52.989 adet ·
   `eTip 16` 535 satır · `eTip 99` 517 · `eTip 90` 51 · `eTip 9` 22.
4. Uyumsuzluk oranı hareket tipine göre: Alış İade %84,7 · Diğer Giriş %76,6 ·
   Sayım %66,1 · Ürün SAY %50,7 · Satış %39,7 · Alış %36,4 · Mağaza Depo %30,9 ·
   Depo Mağaza %29,6 · Stok EKLE %27,3. (88/99/90 düzeltme belgeleri olduğu için
   yüksek oranları kısmen dairesel — o ürünler zaten sorunlu oldukları için düzeltilmiş.)

#### Bu bulgunun planı değiştirdiği yer

Problem "tarihsel kir temizliği" DEĞİL, **süregelen sızıntı**. İki ayrı iş:

| | İş | Büyüklük | Not |
|---|---|---|---|
| **A** | Yeniden eşitleme (± sayım evrakı) | 8.395 çeşit / ~194K adet / ~55K ₺ | Ucuz, tek seferlik |
| **B** | **Sızıntıyı kapatmak** | — | Asıl iş. Yapılmazsa A'yı her yıl tekrarlarsın |

Kanıt: Aralık 2025'te negatif çeşit 302.859 → 37 indi, dokuz ayda **2.545**'e çıktı.
A'yı B olmadan yapmak sayacı sıfırlamaktan ibaret.

**B için ilk üç aksiyon (öneri, onay bekliyor):**
1. `pHrkTip=0` manuel WMS hareketlerinin ERP karşılığı neden oluşmuyor — belgeli olanlarda
   irsaliye onay zinciri (`paletDegistir ve günlük wms irsaliye onay` job'ı) hangi koşulda
   atlıyor? Onay job'ı yalnız `eTip IN (16,90,99)` işliyor; `eTip 13` onaysız duruyor.
2. Alış iade sürecinde WMS-çıkış ↔ ERP-iade eşleşmesi zorunlu kılınmalı (%84,65 uyumsuz).
3. Günlük fark izleme: bu mutabakat sorgusu periyodik koşup eşiği aşınca uyarmalı —
   yıl sonunu beklemek 300 bin çeşide çıkmasına izin veriyor.

---

## 4. Mekanizma 1 — `depo.sayimIsle` (WMS beyan → ERP) — **BU İŞ İÇİN UYGUN DEĞİL**

`ent.JokerJokerCKEsitleme` bunu kullanıyor; ilham kaynağı buydu. Gövdesi okundu (3.830 krk).

**İmza:** `depo.sayimIsle(@sayimID int, @paletBazliSifirlansin tinyint, @kisi int)`

**Adım adım ne yapıyor:**

1. İki `irs` başlığı açar: `eTip=99`, `eMekan=12`, biri `eGC=1` (çıkış) `eNo='JokerStok Ç'`,
   diğeri `eGC=0` (giriş) `eNo='JokerStok G'`. **eNo metni SP'ye gömülü** — merkez
   eşitlemesi de defterde "JokerStok" diye görünür.
2. `UPDATE depo.sayım SET paletBazliSifirlansin=@param, cikisIrsaliyeID, girisIrsaliyeID`
   → **başlığa yazdığın bayrağı SP parametresi ezer.**
3. `#tempSayim` üç koldan doluyor:
   - **farkTip 0** (yalnız `@paletBazliSifirlansin=1`): sayımAyr'da adı geçen paletlerdeki
     **listelenmemiş** ürünler → `−pUAdetN`, çıkış. Yani **listelemediğin ürün paletten silinir.**
   - **farkTip 1**: `sAdet <> pUAdetN` → fark = `sAdet − pUAdetN`.
   - **farkTip 2**: sayımAyr'da var, paletUrnTnm'de yok → `sAdet`, giriş.
   - Üç kolda da `INNER JOIN depo.paletTnm ON pID = spID` → **paletTnm'de olmayan palet
     sessizce düşer** (hata yok, satır yok).
   - Adres üç kolda da `paletTnm.pSonPozID` → **`sAdrsID` okunmuyor.**
4. `INSERT depo.paletIcHrk` — eşleşme: `piTermID = 1+farkTip` (terminal değil!),
   `pGC = yön`, `pHrkTip = 2` (SAYIM, sabit), `piIrsID = irsaliyeID`, `piSonAdrsID = 0`.
5. `INSERT irsAyr` — `ehKdv=1` sabit, `ehSira=1` her satırda, **`ehTutar=0`**.
   → bu yol deftere **tutarsız** yazar; parasal etki üretmez.
6. `EXEC dbo.irsSatirHrk_ekle` ×2 → `irsHrk` üretir. **ŞİFRELİ** (`sys.sql_modules.definition`
   NULL; obje `dbo` şemasında ve SP, yani yanlış şema değil). Zincirin son mili kara kutu.
7. `DELETE depo.paletUrnTnm` (farkTip 0 karşılığı).
8. `UPDATE depo.paletUrnTnm SET pUAdetN = sAdet`.
9. `INSERT depo.paletUrnTnm` (yeni palet-ürün) — `INNER JOIN urnBarkod_vw`
   → **barkodsuz ürün sessizce düşer**: hareket + irsAyr yazılmış ama WMS'e girmemiş
   (yeni tutarsızlık). Ölçüldü: WMS'te barkodsuz **3 çeşit**; çok-barkodlu ürün 0 (fan-out yok).
10. `UPDATE depo.sayım SET sDurum = 1`.

**Yok olan güvenlikler:** `BEGIN TRAN` yok · `TRY/CATCH` yok · `@sayimID` doğrulaması yok ·
satır sınırı yok. Yarıda kalırsa başlık satırsız, palet oynamış kalır.

### 4.1 Niçin bu yolla WMS↔ERP eşitlenemez

`sayimIsle`'nin karşılaştırdığı iki şey: **beyan ettiğin `sAdet`** ↔ **WMS'in kendi
`paletUrnTnm`'i**. ERP defteri karşılaştırmaya hiç girmez, yalnız sonucu alır.

- `sAdet = WMS Stok` verirsen → `Stok` zaten `SUM(pUAdetN)` olduğundan fark **sıfır** →
  `#tempSayim` boş → `irsAyr` satırı yok → **ERP defteri değişmez.** (Bu dosyanın ilk
  sürümü tam bunu yapıyordu: 17 bin satır üretip sıfır düzeltme.)
- `sAdet = ERP defteri` verirsen → 8-9. adımlar **WMS'i ERP'ye çeker**. Ters yön; kural
  merkez stoğunun doğru kaynağının WMS olduğunu söylüyor.

**JOKER'de çalışmasının sebebi:** `20353` paleti JOKER stoğunun ERP-tarafı aynasıdır ve
karşılaştırılan `sAdet` **dış** kaynaktan (`JOKER_RAF_STOK`) gelir → fark doğar. Merkezde
böyle bir dış kaynak yok; fark zaten defterin içinde.

---

## 5. Mekanizma 2 — `WMS-GunlukSayimEmiri` (FİZİKİ sayım emri) — **doğru desen**

Aktif SQL Agent job'u. Beyan etmez, **saydırır**: terminal operatörü rafa gidip sayar.

- `INSERT depo.emir` → `emTip=5`, `emDurum=0`, `emDepoID=12`, `emHavuz=1`, `emBesOto=1`.
- `INSERT depo.emirAyr` → `emIlkAdres = emSonAdres = adrsID` (**yerinde sayım**, taşıma yok) ·
  `emİlkPozID = palet` · `emSonPozID = stkID` · `emAdet = sistemAdet` (sistemin iddiası) ·
  `emTamam = 0` · `emPaletID = 217542` **gömülü**.
  - Ölçüldü: `pID 217542` → `pSonPozID 82157`, adres **'CK01'**, alanTip **2 (ÇIKIŞ ALANI)**,
    içerik 0 satır → sanal hedef palet. JOKER'in 20353'ü ile aynı sınıf gömme.
- Kimler sayacak: `EXEC dbo.BKM_TerminalSayimKullaniciEkle @EmirID` (667 krk, okunur) →
  `depo.emirTerm`e `termID=14` + **gömülü 17 termKod** ('ebahar','erkan.bahar','1008','1002',
  '1049','1055','1056','1079','1105','1137','1170','1229','1300','1301','2000') ekler; ayrıca
  satırı biten emTip=5 emirlerini `emDurum=1` yapar. ⚠ Personel listesi SP'de gömülü →
  kadro değişince sessizce bayatlar.
- **Kimin sayılacağını seçen yer = `sayilcaklar` CTE'si**, iki kol:
  1. Dün, `eMekan=12 OR eFirma=12`, `eTip IN (13,9)` ('Depo Mağaza' / 'Mağaza Depo'),
     `eNo LIKE '%-F1' OR '%-E1'` belgelerinde geçen ürünler.
  2. Dün iptal edilen emir satırları (`emirAyrIptal`, `emIptalNeden <> 4`, `pUAdetN > 0`).
  → **Hayalet stok bu iki ölçüte girmiyor.** Genişletme yeri tam burası.
- `#src` ürünün bulunduğu **tüm** palet/adresleri alır (`Stok > 0`) — kasıtlı fan-out
  (ürün nerede varsa hepsi sayılsın).
- **Son `DELETE` üç şeyi birden yapıyor** (dikkat, gözden kaçıyor):
  kaynak adresin `adresSnl.adrs3 = 0` olduğu satırları emirden **atar**.
  Ölçüldü: `adrs3 = 0` → **3.231 adres, 3.224'ü RAF ALANI** (kalanı ÇIKIŞ 2 · HAVUZ 3 ·
  GİRİŞ 1 · İADE 1); `adrs3` 0..12 arası dağılıyor. Yani sıfır-koordinatlı adresler
  sayıma alınmıyor. Aynı DELETE `urnBarkod_vw` INNER JOIN'i taşıdığından **barkodsuz satır
  silinmez, emirde kalır** (sayimIsle'nin tam tersi davranış).
- `@EmNo = 'GUN' + yyMMdd` → gün içinde ikinci koşumda **aynı emNo** (tekillik guard yok).

### 5.1 Genişletme önerisi (yazılmış, çalıştırılmamış)

[sorgular/2026-09-09-wms-erp-fark-sayim-emri-ONERI.sql](../sorgular/2026-09-09-wms-erp-fark-sayim-emri-ONERI.sql)
— `sayilcaklar`a `UNION ALL` ile üçüncü kol: "WMS'te var, ERP defterinde yok" (hayalet).
Günlük `TOP 50` (en yüksek değer), 30 gün içinde sayıma verilmişse tekrar vermeyen guard.
Yeni job YAZILMAZ; mevcut job'un CTE'si genişletilir (`footprint-ladder`: en dar basamak).

---

## 6. Mekanizma 3 — `bkm.SayimIrsaliye*` (ERP-only defter düzeltmesi) — **aranan araç**

`bkm` şemalı sayım evrakı SP'leri. **WMS'e dokunmaz**: yalnız `irs`/`irsAyr` yazar,
`paletUrnTnm`'e hiç girmez. "ERP'yi düzelt, WMS'e dokunma" ihtiyacının cevabı bu.

### 6.1 `bkm.SayimIrsaliyeBaslikOlustur`
```
@SUBE int, @EVRAKNO varchar(50), @TARIH date, @KULLANICI int, @GC int,
@belgeNot varchar(250)='', @eTip tinyint=99, @frmID int=0, @eNot varchar(30)=''
```
- `EXEC dbo.irs_ekle ...` çağırır, **`@onay = 1`** → belge **anında onaylı**, gece onay
  job'unu beklemez.
- `RETURN` = irsaliye no. Hata olursa **`-1`** döner ve `BKMDATA.dbo.EXCEPTION_LOG`'a yazar
  (`ERROR_NUMBER/SEVERITY/STATE/PROCEDURE/LINE/MESSAGE`). Dönüş değeri kontrol edilmezse
  hata sessiz kalır.
- `@GC`: **0 = giriş, 1 = çıkış** → ERP-eksik ve ERP-fazla için **iki ayrı belge** gerekir.

### 6.2 `bkm.SayimIrsaliyeSatirEkle`
```
@IRSALIYE_NO int, @STKID int, @ADET int, @ehTutar decimal(15,2)=0,
@ehi1 decimal(15,2)=0, @ehNot varchar(50)=''
```
- KDV'yi **kanonik yoldan** alır: `urn.KDVs → urnKDV.kdvYuzde`
  (bugün düzelttiğimiz lookup; `kdvYuzde_vw` DEĞİL — SP zaten doğrusunu kullanıyor).
- `eTip = 99` ise **tutarı kendisi hesaplar**:
  `ehTutar = bkm.UrunMaliyet(@STKID, irs.eTarih) * ABS(@ADET)`,
  `ehTutarKDV = ehTutar * kdvOran/100`.
  → sayım farkı burada **maliyetle** deftere girer (sayimIsle'nin `ehTutar=0`'ının tersi).
- `ehSira`yı `MAX+1` ile kendisi verir. `RETURN 1` başarı / `-1` hata (+EXCEPTION_LOG).

### 6.3 `bkm.UrunMaliyet(@STKID, @TARIH)` — dört kademe
1. Son 5 alış faturası satırı (`fat.eTip=0`, `eDurum<>2`, `Neden<>243`; `eFirma=9525` için
   yalnız 01.09.2022 sonrası) **∪** son 5 `BKMDATA..ODAK_FATURA` satırı →
   ağırlıklı ortalama `SUM(ehTutarN)/SUM(ehAdetN)`.
2. NULL ise `Aktarim.dbo.BKM_STOKLAR_MALIYETLI.ORT_ALIS`.
3. NULL ise fiyat listesi `fytOzl` (`fTur=1, fTip=1`, `fFrmID IN (0, urn.stkFirma)`) × beş
   kademe iskonto.
4. Hâlâ NULL ise **`0`** → maliyeti bilinmeyen ürün deftere **0 ₺** ile girer. **Sessiz.**

### 6.4 Bunun sonucu
9.611 çeşitte `ORT_ALIS` yok (§3.1). Kademe 1 veya 3 bunların bir kısmını kurtarır ama
kurtarmadığı her ürün 0 ₺ ile yazılır → **stok adedi düzelir, değeri düzelmez.** Muhasebe
tarafı bunu bilerek onaylamalı.

### 6.5 Yardımcı: `bkm.SayımEksiStokGetir(@MekanId)`
Defterde negatif bakiyeli ürünleri getirir — bizim "ERP negatif 3.011 çeşit" kümesinin
kurumsal karşılığı. Süzgeçleri: `ehAltDepo=0`, `urnTip=0`, `satisTur=0`, `urnKtgrID<>78`,
`bkm.SINAV_URUN` hariç, 9 stkID elle hariç, `HAVING SUM(ehAdetN) < 0`.
⚠ İçindeki `u.stkAd NOT LIKE 'Sınav okulları'` **joker karaktersiz** → tam eşleşme dışında
hiçbir şeyi süzmüyor, fiilen etkisiz satır. Gerçek süzgeç `urnKtgrID` + `SINAV_URUN`.

### 6.6 Aynı ailedeki diğerleri (envanter, ileride gerekebilir)
`SayimIrsaliyeSatirEkle2` · `SayimSatirGirisCikisDuzenle` · `SayimRafAktar` ·
`SayimRafGuncelle` · `SayimUrunEkle` · `SayimLogEkle` · `SayimStokSatis` ·
`SayimSatOdeTemizle` + tablolar (`SayimBaslik`, `SayimEmirBaslik/Detaylari`,
`SayimDetayTanimlar`, `SayimRaflari`, `SayimKullanici`, `SayimLog`, `SayimTip`,
`SayimDuzeltmeNedenleri`, `SayimYetki`, `SayimMekan`, `SayimSaatleri`).
`bkm.ReyonSayimEmriOlustur` günlük reyon sayım emrini üretir; POS köprüsü
`urnBrkd.urnBarkod = SalesProducts.BarcodeNo` (stkKod DEĞİL — doğru köprü).

**Şifreli, okunamayan:** `dbo.irs_ekle`, `dbo.irsSatir_ekle`, `dbo.irsSatirHrk_ekle`.
Yani **iki yolun da son mili kara kutu**; belgeyi/hareketi fiilen yazan kod okunamadı.

---

## 7. Uygulama tasarımı — KULLANICI KARARI (09.09.2026)

Kullanıcı tasarımı (verbatim): _"zaten wms e dokunmyacak wms toplamını hesaplayıp erp ile
bakacak +- sayım evrak girişi yapmalı"_

**Yol: WMS'e DOKUNULMAZ. WMS toplamı ↔ ERP defteri karşılaştırılır, fark ± sayım evrakı
olarak ERP'ye yazılır.** Araç `bkm.SayimIrsaliyeBaslikOlustur` + `SayimIrsaliyeSatirEkle`
(§6) — bunlar yalnız `irs`/`irsAyr` yazar, `paletUrnTnm`e hiç dokunmaz.
`depo.sayimIsle` KULLANILMAZ (aynı koşuda WMS'i de oynatır, `ehTutar=0` yazar).

Üretici (salt-okuma, EXEC metnini basar):
[sorgular/2026-09-09-wms-erp-sayim-evraki-URET.sql](../sorgular/2026-09-09-wms-erp-sayim-evraki-URET.sql)

| Adım | Ne | Nerede |
|---|---|---|
| 0 | Kapsam teyidi (ÇIKIŞ dahil) | ÜRET Blok 1 |
| **1** | **PİLOT — tek ürünle evrak.** `dbo.irsSatir_ekle` şifreli olduğu için `@ADET` işaretinin nasıl yorumlandığı OKUNAMADI; ampirik belirlenecek | ÜRET Blok 6 + iki varyant |
| 2 | Dilim seç (kategori / tutar eşiği), `@DilimTavani ≤ 200` | ÜRET Blok 4 |
| 3 | Üretilen EXEC metnini gözden geçir → başlık, sonra satırlar | ÜRET Blok 5 |
| 4 | Farkın azaldığını **ölç**. Azalmadıysa DUR | ÜRET Blok 2 |
| 5 | Sonraki dilim; her dilim kendi evrak no'sunu alır | — |

**Dilim büyüklüğü:** ilk parti ≤ 200 çeşit, en yüksek **maliyetli** tutardan (etiketten
değil — §3.3).

### 7.1 Bu yolun kabul ettiği varsayım (açıkça yazılıyor)

Defter düzeltmesi **WMS'i doğru kabul eder**. WMS'in kendisi yanlışsa (hayalet stok —
§1, mekanizma plan içinde) düzeltme yanlışı deftere **kopyalar**. Bu yüzden:

- Hayalet şüphesi olan ürünler (WMS var / defter 0, kitap tarafında yığılı) önce **fiziki
  sayılmalı**: `sorgular/2026-09-09-wms-erp-fark-sayim-emri-ONERI.sql` (mevcut
  `WMS-GunlukSayimEmiri` job'ının CTE'sine üçüncü kol).
- `paletUrnTnm`'de 80.108 sıfır + 43 negatif satır var ve view bunları göstermiyor (§2) —
  "WMS'te yok" ile "WMS'te kaydı yok" farklı şeyler.
- Fiziki sayım ve defter düzeltmesi **birbirinin alternatifi değil**: sayım WMS'i teyit
  eder, evrak defteri düzeltir. Şüpheli küme için ikisi sırayla.

---

## 8. Riskler ve kapılar (uygulamadan önce her biri cevaplanmalı)

| # | Risk | Neden önemli | Ne yapılmalı |
|---|---|---|---|
| R1 | `@onay=1` → belge anında deftere işler | Geri alma ayrı belge ister, iz kalır | Küçük dilimle başla, ilk dilimi kontrol et |
| R2 | Maliyeti bilinmeyen 9.611 çeşit 0 ₺ girer | Adet düzelir, değer düzelmez | Muhasebe bunu bilerek onaylasın; gerekirse önce maliyet tamamlama |
| R3 | `adrs3 = 0` adresler sayım emrinden düşüyor (3.224 raf) | Hayaletin bir kısmı hiç sayılmaz | Genişletmede bu kapıyı bilerek aş veya adrs3'ü düzelt |
| R4 | Barkodsuz 3 çeşit | sayimIsle yolunda WMS'e girmez, emir yolunda terminalde okunamaz | Önce barkod tanımla |
| R5 | `emPaletID=217542` / `termKod` listesi SP'de gömülü | Kadro/palet değişince sessizce bozulur | Değişiklikte SP güncellenmeli — kural olarak yazıldı |
| R6 | `@EmNo='GUN'+yyMMdd` tekil değil | Gün içi ikinci koşum çakışır | Genişletmede emNo'ya sıra ekle |
| R7 | `sayimIsle` yolunda `paletBazliSifirlansin=1` | Listelenmeyen ürün paletten SİLİNİR | Bu yol kullanılmayacak; kullanılırsa bayrak 0 |
| R8 | Son mil şifreli (`irs_ekle` / `irsSatir_ekle` / `irsSatirHrk_ekle`) | Yan etkileri okunamıyor | Küçük dilimle ampirik doğrula; DerinSIS satıcısına sor |
| R9 | Transaction yok (`sayimIsle`) | Yarıda kalırsa tutarsız kalır | `bkm.SayimIrsaliye*` yolu tercih edilir (TRY/CATCH + log var) |

---

## 9. Karar bekleyenler (kullanıcı/muhasebe)

1. Stok değerindeki değişim kabul edilebilir mi, hangi dilimlerde? (§3.1 — yön ölçüme bağlı)
2. 3.011 ERP-negatif ürün nasıl kapanacak: fiziki sayım mı, doğrudan defter düzeltmesi mi?
3. `WmsStok = 0` olan 9.230 çeşit / 1.997.663 adet sayılamıyor — defter düzeltmesi onayı?
4. Maliyeti bilinmeyen ürünler 0 ₺ ile deftere girsin mi, yoksa önce maliyet tamamlanacak mı?
5. Bu iş bir SQL Agent job'una mı bağlanacak, yoksa elle dilim dilim mi koşacak?
   (Job kurulumu **ayrı onay** ister — `erp-write-policy.md`.)

---

## 10. Done kriterleri

- [ ] Dilimleme ölçütü kararlaştı ve yazıldı
- [ ] İlk dilim (≤200 çeşit) fiziki sayıldı; sonuç WMS ile karşılaştırıldı
- [ ] İlk dilim defter düzeltmesi yapıldı; `irsHrk` ve stok değeri **ölçülerek** doğrulandı
- [ ] Fark yeniden ölçüldü; azalma rakamla gösterildi (DRYRUN Blok 1)
- [ ] Kalan fark için tekrar eden mekanizma (job veya periyodik koşum) kararı verildi
- [ ] `sema/` güncellendi; bu plan `plans/archive/`e taşındı

## 11. Rollback

`bkm.SayimIrsaliye*` belgeleri `eTip=99` ve `eNo`/`belgeNot`'ta işaretli olacak
(`@belgeNot='WMS-ERP mutabakat <dilim>'`) → yanlışlık halinde **ters yönlü (`@GC` tersi)
ikinci sayım belgesi** ile netlenir. Belge silme YOK. Hangi belgelerin bu işten geldiği
`eNo` deseninden sorgulanabilir olmalı.

---

## 12. Kaynak dosyalar ve yeniden ölçüm komutları

**Dosyalar**
- [sorgular/2026-09-09-wms-erp-esitleme-DRYRUN.sql](../sorgular/2026-09-09-wms-erp-esitleme-DRYRUN.sql) — mekanizma çözümlemesi + salt-okuma ölçüm blokları (hiçbir yazma yok)
- [sorgular/2026-09-09-wms-erp-fark-sayim-emri-ONERI.sql](../sorgular/2026-09-09-wms-erp-fark-sayim-emri-ONERI.sql) — sayım emri CTE genişletme önerisi (çalıştırılmadı)
- [sorgular/2026-09-09-wms-erp-hayalet-stok.sql](../sorgular/2026-09-09-wms-erp-hayalet-stok.sql) — hayalet stok keşfi, 248104 uçtan uca izi
- [scripts/wms_erp_mutabakat_excel.py](../scripts/wms_erp_mutabakat_excel.py) — tam ürün-bazlı mutabakat Excel'i (SALT-OKUMA)
- [scripts/gr_palet_supheli_excel.py](../scripts/gr_palet_supheli_excel.py) — GR paletlerindeki şüpheli stok listesi

**SP gövdesini yeniden okumak**
```bash
sqlcli query --profile erp --format json "SELECT SUBSTRING(m.definition,1,800) AS P FROM sys.sql_modules m JOIN sys.objects o ON o.object_id=m.object_id JOIN sys.schemas s ON s.schema_id=o.schema_id WHERE s.name='depo' AND o.name='sayimIsle'"
```
(offset'i 801, 1601… diye kaydırarak devam et; toplam 3.830 karakter.)

**Şifreli mi, yanlış şema mı ayırt etmek** (`OBJECT_DEFINITION` NULL'u yanıltır):
```bash
sqlcli query --profile erp --format json "SELECT s.name AS Sema, o.name, o.type_desc, CASE WHEN m.definition IS NULL THEN 'NULL' ELSE 'OKUNUR' END AS D FROM sys.objects o JOIN sys.schemas s ON s.schema_id=o.schema_id LEFT JOIN sys.sql_modules m ON m.object_id=o.object_id WHERE o.name='irsSatir_ekle'"
```

**Farkı yeniden ölçmek:** DRYRUN dosyasını SSMS'te aç, Blok 1'i koş (salt-okuma).

---

## 13. Reddedilen alternatifler

| Alternatif | Neden reddedildi |
|---|---|
| `ent.JokerJokerCKEsitleme`'yi merkez için kopyalamak | `sAdet=WMS` verince fark 0 → hiçbir şey düzelmez (§4.1). Ayrıca sabit palet/adres merkez topolojisini çökertir |
| Doğrudan `irsHrk`'a düzeltme kaydı yazmak | DerinSIS native tablo — `erp-write-policy.md` MUTLAK YASAK. Belge izi de olmaz |
| WMS'i ERP'ye eşitlemek | Ters yön; merkez stoğunun doğru kaynağı WMS (kural) |
| Tek koşuda tüm evreni eşitlemek | 17.027 çeşit tek partide depoyu boğar, tek muhasebe kaydında büyük değer oynatır, hata izlenemez |
| Yeni bir eşitleme job'u yazmak | `footprint-ladder`: mevcut `WMS-GunlukSayimEmiri` CTE'sini genişletmek yeterli |
