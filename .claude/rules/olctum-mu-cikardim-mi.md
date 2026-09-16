# Ölçtüm mü, Çıkardım mı — Her Sayının Arkasında Komut Olsun

> **Rule katmanı:** core (her oturum birincil). `paths:` yok — compact sonrası survive.
>
> Belinza deposundan (`D:\Dev\bel/.claude/rules/olctum-mu-cikardim-mi.md`) uyarlandı
> (03.09.2026). Orada Odoo/ETL vakalarından doğmuştu; buradaki vakalar BKM'nin kendi
> ölçülmüş hatalarıdır. Kural aynı, kanıt yerli.

## Ortak mekanizma

> Ölçümün yerine **makul bir çıkarım** koymak ve onu ölçümmüş gibi sunmak.

Bu sınıf sinsi: çıkarım yanlış olduğunda sonuç **saçma değil, makul** çıkar. Saçma
sayı fark edilir; makul sayı kabul edilir ve CFO kararına dayanak olur.

## BKM'de ölçülmüş vakalar

| İddia | Nasıl "biliniyordu" | Gerçek |
|---|---|---|
| `SalesProducts.BarcodeNo = urn.stkKod` ürünü eşler | `stkKod` "kod" adını taşıyor → barkod **sanıldı** | eşleşmiyor; Oyuncak cirosu 700K göründü, gerçek **10,96M** |
| `ehTip=1` alış (ADR-004) | bir kez yazılmış, kimse yeniden ölçmedi | 201 kanıt: `1` **satış**; alış `0` ve adet **pozitif** — tam tersi |
| Personel sayısı = bordro satırı | satır sayısı kişi sanıldı | ay içinde 1 gün çalışan da 1 sayılıyor: 211 kayıt = **168,9** tam gün karşılığı |
| Sezon = Temmuz–Ağustos | takvim sezgisi | ölçüm: Eyl **313,0M**, Ağu 186,9M → sezon Temmuz–**Ekim** |
| Dapper 8. kolon map ediliyor | 7 kolonda çalıştı → 8'de de çalışır **sanıldı** | `Alacak` sessizce **0**; hata yok, rakam yanlış |
| `OBJECT_DEFINITION('dbo.X')` NULL → şifreli | tek olasılık varsayıldı | obje `mhs` şemasındaydı; şifreli değildi |
| "MCP'de doğrulandı, app'te çalışır" | ölçüm kapsamı ≠ kod kapsamı | app `master` bağlamında; 2-parçalı isim Err 208 |

Yedi vakanın hiçbiri saçma sayı üretmedi. Hepsi makul görünüp karara girdi.

## Kural

**1. Her olgusal cümle etiketli olmalı.**

- **ÖLÇÜLDÜ** — yanında sorgu/komut ve sayı var.
- **ÇIKARIM** — ölçülmedi, benzer bir yerden türetildi. Bu etiket olmadan söylenmez.

Etiketleyemiyorsam cümleyi kurmam; önce ölçerim. Sunuma/rapora giren her rakam
ÖLÇÜLDÜ sınıfında olmak zorunda (bkz. `veri-dogrula` skill).

**2. Ölçümün KAPSAMI, kodun kapsamıyla aynı olmalı.**

En pahalı hata burada. Ölçüm doğru koştu ama süzgeç farklıydı:
- Denetim 3 POS mağazasını ölçtü, kadro 5 mağazayı sayıyordu.
- `DocumentsTypeId` filtresi raporda 1,2,3,6,7,8; doğrulamada yalnız 1.

Sınama: *"bu ölçümün süzgeci, koddaki süzgecin AYNISI mı?"*

**2b. YoY kıyasta İKİ YILIN METRİĞİ AYNI TANIMLA kurulmalı (14.09.2026, ölçüldü).**
Kapsam eşitliğinin zaman eksenindeki hâli. Defter stok kontrolünde "kuru giren
çeşit" iki yıl için farklı tanımla hesaplandı — 2025'e AYNI-yıl sezon talebi,
2026'ya ÖNCEKİ-yıl talebi bayrağı kondu. Sonuç **"336 → 1.239, 3,7 KAT ARTIŞ"**
diye alarm verdi. Metrik simetrik hâle getirilince (her iki yıl için önceki-yıl
bayrağı) oran **%18,7 → %19,5** yani DEĞİŞMEDİ. Rakamların ikisi de doğru
hesaplanmıştı; kıyaslanamaz olan TANIMDI. Yön bile uydurmaydı.

Sınama: *"bu iki sayı aynı soruya mı cevap veriyor, yoksa iki ayrı soruya mı?"*
Kıyas tablosunda her kolonun tanımı yazılamıyorsa kıyas kurulmamıştır.

⚠ **Bunu bugün hiçbir denetim yakalamıyor** (`test-discipline.md` § yazılı kural ≠
uygulanan kural gereği açıkça yazılıyor). Kapı, kıyas tablosunu üreten kodda
tanımın tek yerden gelmesidir (`emitter-ayrimi.md` § biçim de tek yerde); henüz
genel bir koşucu yok.

**3. Liste elle yazılmaz.** Kolon listesi `sys.columns`tan, tablo listesi
`sys.tables`tan, kod kümesi `GROUP BY`dan gelir. Elle yazılan liste eksik olur ve
eksikliği ancak patlayınca (ya da hiç) görülür. Sema'ya liste değil **kural** yazılır
(`semantic-layer.md` § ŞEMA GERÇEĞİ ≠ SATIR VERİSİ).

**4. Kopyalanan desende gerekçe de kopyalanmaz.** `WHERE IsValid=1`, `urnTip=0`,
`COLLATE Turkish_CI_AS` üç sorguda doğruydu diye dördüncüde doğru değildir. Gerekçe
her hedefte yeniden kurulur (`before-major-change.md` § İlk Dokunuş).

## BULGUYU ölçüp KARARI tahmin etme

"Ertelendi / uygulanmaz / gerek yok" **bir karardır ve ölçüm ister**. Denetim
tablosunun geri kalanı ölçülü olduğu için, tahmin olan satır da ölçülü sanılır.
Gerekçesi ÖLÇÜLDÜ diye etiketlenemiyorsa erteleme değil, **açık soru** olarak yazılır
(TODO'da "teyit bekliyor" — ör. K-06 OYUN ALANI, norm tablosundaki 2 boş satır).

## İki yardımcı kural

**Sessizlik kanıt değil.** Bir ölçümün BOŞ dönmesi ile KOŞMAMASI ekranda aynı görünür.
ERP kesintisinde (10053) sorgular boş döndü; "veri yok" değil "ölçmedik" demekti.
`tools/sema_degismez.py` bu yüzden bağlanamazsa **patlar**, yeşil demez.

**Değeri gördüm, tarihini görmedim.** Bir ölçümün DEĞERİ kadar **ne zamanı** da
ölçümün parçasıdır. `irs.eTip=100` gün içinde yeniden yazılır → bugünün satırı ölçüm
sanılırsa rakam akşam değişir. Bordro son kapanan aya kadar gerçektir; ötesi tahmindir.

## Düzeltmeden sonra da ölç

Bir düzeltmenin **tuttuğu** ayrıca ölçülür. FTE'ye geçtikten sonra tutarlılık
kontrolüne `fte = prim_gun/30` ve `fte <= kayit_sayisi` kontrolleri eklendi; o
kontroller koşmasaydı sapma bir sonraki sunumda çıkardı.

## NÜFUS SIFIRSA "GEÇTİ" DEĞİL "BAKAMADIM" (2026-09-11, iki vaka ölçüldü)

`sema kostur` NULL sonucu zaten KOŞAMADI sayıyordu. Eksik olan yarısı şuydu:
**boş nüfus NULL döndürmez, 0 döndürür** — ve `eq 0` bekleyen bir kapı için 0 "ihlal
yok" demektir. INNER JOIN, tarih penceresi ya da sabit id listesi taşıyan her denetim
bu sınıftadır: karşı taraf boşalınca kapı sessizce yeşile döner.

| Değişmez | Nüfusu ne boşaltır | Boşalınca ne okunurdu |
|---|---|---|
| `pos-kalem-header-mutabakati` | son 7 günde satış yok (ERP kesintisi) | `ABS(0−0) < 1` → **kusursuz ciro mutabakatı** |
| `muhasebe-hesap-kodu-panelde-yok` | `bkm.SatisAnaliziTaban` boş (istek üzerine dolar) | `MAX(Kesim)` NULL → hiç satır → temiz |
| `palet-yon-ilkid-sahibi` | sabit iki `stkID` view'i terk eder | fark yok |
| `puanbil-kisi-ay-tekilligi` | `Lokasyon LIKE 'MA%'` adlandırması değişir | mükerrer bordro satırı yok |
| fifo'nun 10 kapısı | master deploy tabloları DROP eder (yaşandı) | on kapı birden temiz |

**Kural:** `eq 0` bekleyen her değişmez ya bir `population` sorgusu taşır (ihlal koşulu
ATILMIŞ hâli; JOIN korunur, çünkü JOIN'in daralması da ölçülmeli) ya da
`population_exempt` ile boşalamayacağını YAZAR. Nüfus 0 dönerse **KOŞAMADI (çıkış 2)** —
KIRIK değil, yeşil hiç değil.

**Bir soru olarak:** *bu sayı "ihlal yok" mu diyor, "bakamadım" mı?* Ayırt edemiyorsan
kapı yoktur; nüfusu ölç.

## Sınır testi

> *"Bu cümlenin arkasında bir komut çıktısı var mı, yoksa 'olması gereken' mi?"*

İkincisiyse ya ölç, ya **ÇIKARIM** diye yaz.

## İlişkili
- `.claude/rules/before-major-change.md` § Fact-Force Gate — ilk dokunuş öncesi keşif.
- `.claude/rules/semantic-layer.md` § DEĞİŞMEZ — öğrenilen gerçek komutla yeniden koşar.
- `.claude/skills/veri-dogrula/SKILL.md` — bağımsız rakam mutabakatı.
- `sema/degismezler.json` · `tools/sema_degismez.py` — koşulan değişmezler.

## EŞİK TÜRETME — "veriden çıkardım" da bir yöntem gerektirir (10.09.2026)

_Kullanıcı direktifi: **"bence bunlar için kabul görmüş istatistik yöntemleri varsa onları da
kullanarak değerlendirme yapmak gerekiyor sanki litaratür araştırmalısın"**. Aşağıdaki dört
kural o araştırmadan çıktı ve BKM'nin kendi ölçümleriyle sınandı._

Bir eşik (aşırı stok 3× · sezon 0,50 · raf kaybı 5 adet) "veriden türetildi" denilerek
ÖLÇÜLDÜ sınıfına yazılamaz. Bantlara gözle bakıp kırılma noktası seçmek bir yöntem değil.

**1. Trend testi ZORUNLU, ama tek başına YETMEZ.** Sıralı bantlarda oran trendi
**Cochran-Armitage** ile sınanır (ki-kare 1 sd; omnibus ki-kareden güçlü çünkü sıralamayı
kullanır). ⚠ Yalnız DOĞRUSAL trende karşı güçlüdür — U-şeklini ve monoton olmayanı KAÇIRIR.
BKM vakası: "merkez stoğu" ekseninde `chi2(1)=95,6 · p=1,4e-22` çıktı ama desen
`3,2 → 4,9 → 8,2 → 7,4 → 6,4 → 11,9` yani monoton DEĞİLDİ ve ölçüt REDDEDİLDİ.
**Küçük p bir ölçütü doğrulamaz.** Monotonluk ayrıca kontrol edilir.

**2. Oranlara güven aralığı — Wilson skor aralığı.** Bant n'leri uçlarda çok farklı olur
(BKM: 10 ile 8.736 arası) ve normal yaklaşım orada güvenilmez. Kesim ancak **komşu bantların
GA'ları ÇAKIŞMIYORSA** desteklenmiş sayılır. BKM: `1-4 → %13,3 [11,6-15,2]` ile
`5-19 → %38,4 [32,4-44,9]` ayrık → 5 kesimi destekli; `20-49` (n=47) ile `50+` (n=10)
çakışık → aralarında ayrım YAPILMADI.

**3. Veriden seçilen kesimin bedeli BEYAN EDİLİR.** Literatür bu yöntemi eleştirir: veriden
türetilen "optimal kesim" gruplar arası farkı **abartır**, spuriously significant sonuç üretir
ve tekrarlanabilirliği düşüktür — Altman & Royston 2006 (BMJ, _The cost of dichotomising
continuous variables_) · Royston, Altman & Sauerbrei 2006 (Stat Med, _Dichotomizing continuous
predictors in multiple regression: a bad idea_); medyandan bölmek verinin üçte birini atmakla
aynı güç kaybını verir. ⇒ **Kesimdeki oran farkı bir ETKİ ÖLÇÜSÜ olarak sunulmaz**, yalnız
kohort seçiminde kullanılır. Sürekli değişken korunabiliyorsa (spline/kesirli polinom) kesim
hiç yapılmaz; bir LİSTE üretmek zorunluysa kesim kaçınılmazdır ama bedeli yazılır.

**4. Alan literatürünün sınırını da yaz.** Kendi ölçümünü alanın bilinen büyüklükleriyle
karşılaştır; sapma varsa neyi ölçmediğini anlamışsın demektir:
- **Kayıt doğruluğu:** perakendede kayıt-fiziksel uyuşmazlığı (_inventory record inaccuracy_)
  SKU'ların %50-70'inde görülür (DeHoratius & Raman: 369.567 kaydın %65'i; hataların %41'i
  "fiziksel > kayıt" yönünde), hayalet stok kaynaklı kayıp ~yıllık cironun %4'ü. BKM panelinin
  "doğrulanamıyor" oranı %0,12 — bu DOĞRULUK ORANI DEĞİL, yalnız aritmetik olarak imkânsız
  (negatif stok / fiyat 0) kayıtların oranı. Gerçek sapma yalnız **fiziksel sayımla** bilinir.
- **Kayıp satış:** gözlenen satış stok tükenen günlerde kesilir (**sağdan sansürlü**). Geçen
  yılın satışını talep vekili yapmak kaybı ALT SINIRDAN tahmin eder. Kabul görmüş düzeltme
  EM tabanlı sansürlü-talep tahmini ve ikame modellemesidir (Anupindi/Dada/Gupta 1998 ·
  Conlon & Mortimer). Uygulanmadıysa "tahminimiz alt sınırdır" yazılır.

**Sınama:** _"eşiği bir başkası aynı veriyle bağımsız türetse aynı sayıyı bulur muydu?"_
Bulamayacaksa eşik SEÇİLMİŞTİR — öyle yazılır.
