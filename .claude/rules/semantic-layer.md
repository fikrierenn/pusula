# Semantik Katman Disiplini

_BKM şema bilgisi `sema/*.yaml`'da canonical, makine-okunur tutulur. `paths:` yok — compact sonrası survive._

## Temel İlke

**Şema gerçeği öğrenilince hafızada kalmaz — `sema/`'ya yazılır.** Köprü, tablo grain'i, enum kodu, metrik formülü canlı sorguyla doğrulandığında `sema/*.yaml`'a atomic + confidence + evidence ile eklenir (ECC continuous-learning instinct pattern). Skill: `sema-ogren`.

## Dosya yönlendirme

| Öğrenilen | Hedef |
|---|---|
| Join / FK / cross-db bağ | `sema/bridges.yaml` |
| Tablo/view + PK + anahtar kolon + grain | `sema/entities.yaml` |
| Enum / lookup değerleri | `sema/codes.yaml` |
| İş kategorisi / formül / hesap modeli | `sema/metrics.yaml` |
| İnsan-okunur özet (köprü/kod) | `sorgular/SEMANTIK_KATMAN.md` (senkron) |

## Kurallar

1. **Sorgu yazmadan önce `sema/`'ya bak.** Doğru join `bridges.yaml`'da, doğru filtre/kod `codes.yaml`/`metrics.yaml`'da. Hardcode etme — oradan al.
2. **Yeni gerçek → anında kayıt.** "Sonra eklerim" yok; oturum içinde `sema-ogren` ile yaz.
3. **Atomic + kanıtlı.** Bir kayıt = bir gerçek. Her kayıt canlı doğrulanmış; tahmin `status: teyit bekliyor` + düşük confidence.
4. **Duplikasyon yok.** Aynı bağ varsa güncelle (confidence/evidence), yeni satır açma.
5. **Çelişki → düzelt.** Yeni gerçek eskiyi çürütürse eskiyi sil veya düşür (`note: süperseded`).
6. **Rapor scriptleri sema-driven.** Yeni script köprü/kod/metrik tanımını `sema/`'dan okur; tutarlılık tek kaynaktan.
7. **Keşif SQL'i ARŞİVLE (ikiz yükümlülük — KRİTİK, sık unutulur).** Bir veri sorusunu MCP ile keşfettiysen (yeni köprü/kod/metrik üreten anlamlı sorgu), oturumu kapatmadan İKİSİNİ birden yap: (a) gerçeği `sema/*.yaml`'a yaz, (b) çalıştırdığın SQL'i `sorgular/YYYY-MM-DD-<konu>.sql`'e arşivle. Biri olmadan diğeri eksik: sema "ne öğrendik", arşiv "nasıl bulduk (tekrar üretilebilir)".

## Keşif/Analiz SQL'i Arşivle (İkiz Yükümlülük)

**Tetik:** MCP `sql_query` ile anlamlı bir keşif/analiz yaptın (yeni tablo/köprü/kod ortaya çıktı, bir CFO sorusunu cevapladın, bir bug'ı SQL ile teşhis ettin). Tek-satır sanity-check HARİÇ.

**İki adım, oturum içinde, atlanmaz:**
1. **Gerçek → `sema/`** (yukarıdaki kurallar — bridges/entities/codes/metrics).
2. **SQL → `sorgular/YYYY-MM-DD-<konu>.sql`** — çalıştırılabilir, başına 2-3 satır yorum (ne sorusu, hangi DB, bulgu özeti). MCP-uyarlaması değil, SSMS-çalışır tam sorgu (CTE serbest).

**Neden:** Keşif SQL'i kaybolursa aynı soruyu yeniden keşfetmek pahalı; sema "ne" der ama "nasıl doğrulandı" arşivde durur. Bu oturum Kumbara/kartlı-kartsız keşfi sema'ya yazıldı ama SQL arşivlenmedi → bu kuralın doğuş sebebi.

**Dashboard gömülü SQL ayrı:** `dashboard/Data/*.cs` içindeki sorgu KODUN evi (arşive kopyalama). Bu kural MCP-keşif/analiz SQL'i içindir.

## ŞEMA GERÇEĞİ ≠ SATIR VERİSİ (20.08.2026 kullanıcı direktifi)

**Sema'ya KURAL yazılır, LİSTE yazılmaz.** Satır verisi (kampüs listesi, şube adları, dönem listesi, kullanıcı/kadro listesi, ürün listesi, tedarikçi adları) **değişkendir** — açılır, kapanır, yenilenir. Sema'ya yazıldığı an bayatlamaya başlar ve sonraki oturum onu doğruymuş gibi kullanır.

| ❌ Sema'ya YAZMA (satır verisi) | ✅ Sema'ya YAZ (kalıcı gerçek) |
|---|---|
| "14 kampüs: 42 DEMİRCİ · 43 MKP · …" | "Gerçek kampüs = `Aktif=1` + Test-prefix hariç; `SinavKampusId` tek başına ayraç DEĞİL" |
| "Dönem 8 → 378 sipariş, 7 → 8.723 …" | "Dönem kümesi `snv.Donem`'den CANLI okunur; Siparis'te orphan DonemId var, JOIN ile düşer" |
| "Aktif alıcılar: 48 Onurhan, 76 Aydın" | "Alıcı kadrosu Ayarlar'dan parametrik okunur; rol ayrımı `sipTip_vw` eTip ile yapılır" |
| "Kategori 10 Hediyelik, 12 Kırtasiye…" | (kod/enum ise `codes.yaml`'a — o gerçekten sabit lookup) |

**Ayrım testi:** "Bu bilgi 6 ay sonra hâlâ doğru mu?" Hayırsa → satır verisi, sema'ya girmez; kodda canlı sorgulanır.

**İstisnalar (yazılabilir):**
- **Kod/enum lookup** (`codes.yaml`) — `ehTip=4` satış, `DocumentsTypeId=3` iade: bunlar şema sözleşmesi, satır verisi değil.
- **Büyüklük mertebesi** — "≈365K satır (2026-08)" perf kararı için faydalı; **tarih damgalı** ve "mertebe" olduğu belli olacak.
- **Tuzağın kanıtı** — tek örnek kayıt ("StokId 227386'da iki sistemde ad farklı") desenin kanıtı; liste değil, örnek.
- **Ölçüm bulgusu** — "1.787 sipariş hatalı ödendi (ölçüm 2026-08-19)": `evidence` alanında, tarihli, "anlık" olduğu açık.

**Anti-pattern:** liste yazıp `last_verified` damgasıyla kendini güvende sanmak. Liste TTL ile korunmaz — bir kampüs kapanınca kayıt sessizce yanlış olur, kimse fark etmez.

## DEĞİŞMEZ — decay'in eksik yarısı (2026-09-03)

_Belinza deposunda (`D:\Devel`) tek oturumda dört ölçüm hatası
yapıldı ve dördü de "bir kez öğrenilip unutulmuş şema gerçeği"nden
doğdu. Oradan dönen ders burayı da ilgilendiriyor._

`last_verified` + `ttl_days` bir **bayraktır**, bir **ölçüm** değil:
süresi dolduğunu görmek için birinin bakması gerekir — ve bakılmaz.
`queries.yaml` doğrulanmış SQL'i **saklar**, kimse **yeniden koşmaz**.

> **Yazılan gerçek, komutla yeniden koşturulabiliyorsa koşturulur.**

`sema/degismezler.json` + `tools/sema_degismez.py`:

```bash
python tools/sema_degismez.py
```

Bayatlarsa çıkış kodu 1. Bağlanamazsa **patlar, atlamaz** — bir ölçümün
BOŞ dönmesi ile KOŞMAMASI ekranda aynı görünür.

### DEĞİŞMEZ ≠ ÖLÇÜM

Ayrım testi: *"bu iddia yarınki veriyle de doğru mu?"*

| Yazılır (değişmez) | Yazılmaz (ölçüm) |
|---|---|
| `urnTip` yalnız 0/1/2 olabilir | "ölü stok 12,4M TL" |
| `irsHrk` kolonu `ehstkID` (küçük s) | "Haziran net kâr 2,04M" |
| EncoreMerkez compat 110 | "1.787 sipariş hatalı ödendi" |

Ölçümler `evidence` alanına tarih damgasıyla yazılır; değişmezler
`degismezler.json`'a koşulmak üzere.

### Kırılabildiği kanıtlanmadan değişmez yazılmaz

Yeni değişmez eklendiğinde beklenen değer **bilerek bozulur**, kırmızı
olduğu **görülür**, sonra geri alınır. Kırılabildiği kanıtlanmamış bir
test, test değildir. (Yapıldı 2026-09-03: `encore-compat-110`
beklenen 110→150 → kırmızı → geri alındı.)

### İlk koşuda ne buldu

Sekiz değişmezin sekizi geçti, **ama yazarken bir eksik ortaya çıktı**:
`dbo.urn.urnTip` iki değil **üç** değer alıyor. Sema `0=normal ürün,
1=gider/hizmet` diyordu; **`2` = demirbaş/araç satışı, 52 kayıt**
(örn. "16 BFF 90 BMW OTOMOBİL SATIŞI") hiç belgelenmemişti. Ölü stok
sorgusu `WHERE urnTip=0` kullandığı için bu 52 kayıt sessizce dışarıda
kalıyordu.

Yani mekanizmanın değeri kırmızı vermesinden önce **yazarken ölçmeye
zorlamasında**.

### Çok sunucu — bordro da değişmez taşır (03.09 genişletme)

Değişmezler tek sunucuda başladı; bordro/İK gerçekleri **ayrı sunucuda**
(`192.168.40.25\ZRVSQL2008`, adlandırılmış örnek) olduğu için hiç
ölçülemiyordu. Her kayıt artık `sunucu` alanı taşır:

| `sunucu` | Hedef | Sürücü |
|---|---|---|
| `erp` (varsayılan) | DerinSIS / EncoreMerkez / BKM | pymssql |
| `zirve` | BKM_GENEL (bordro + İK) | **pyodbc** — adlandırılmış örneğe pymssql portsuz ulaşamaz, bağlantı asılır |
| `joker` | JOKER e-ticaret | pymssql |

Aynı hedefe tek bağlantı açılır. Sürücü seçimi sunucu adında ters bölü
olup olmamasına bakar (`scripts/verimlilik_ortak.py` ile aynı desen).

### Yapısal denetim — gerekçesiz değişmez kabul edilmez

Koşucu, SQL'leri çalıştırmadan önce kayıtları denetler (Belinza'nın xUnit
koşucusundan alındı): `id` tekil · `soru`/`neden`/`db` boş olamaz ·
`karsilastirma` ∈ {esit, enaz, encok} · `sunucu` tanımlı. Gerekçesi
yazılmayan bir değişmez, kırıldığında ne yapılacağını söylemez.

### Bordro/kadro değişmezleri (03.09, 6 kayıt — altısı da kırmızıya düşürülüp geri alındı)

| Kayıt | Neyi korur |
|---|---|
| `kadro-etiket-kumesi-kapali` | Kod yalnız `Kadro='SEZONLUK'`u ayırır, gerisini KADROLU sayar → yeni etiket sessizce kadroluya düşer |
| `sezonluk-etiketi-duruyor` | Etiket yeniden adlandırılırsa sezonluk **sıfırlanır**, herkes kadrolu görünür |
| `primgunu-30-tavani` | Tam gün karşılığı = `SUM(Primgunu)/30`; 31'i aşan satır personel sayısını şişirir |
| `puanbil-kisi-ay-tekilligi` | Mükerrer bordro satırı **veya** ikinci departman kaydı (fan-out) maliyeti iki katına çıkarır |
| `maliyet-kolonlari-duruyor` | Maliyet = `Bt + Isskk + Iisk`; kolon adı değişirse formül başka kolona kayar |
| `sinav-ikinci-kol-gerekli` | Sınav ayrıştırması iki kollu; tek kol Sınav cirosunu mağazaya yazar (55.100 ürün ikinci kola bağlı) |

Yazarken yine ölçüm zorladı: `Kadro`nun `KADROLU` değil **`KADRO`**
olduğu ve kapsam içinde `PART TIME`/boş etiketli kayıtların bulunduğu
böyle görüldü — 30.06 tabanındaki 153 kişinin 1'i part-time, 2025
tabanındaki 135'in 1'i boş etiketli. Rakamlar doğruydu, gerekçesi eksikti.

### Katalog da koşar — `queries.yaml` (03.09 genişletme)

Değişmezler şema gerçeğini koşturuyordu; `queries.yaml` hâlâ "saklanan ama
koşmayan" taraftaydı. `tools/sema_sorgu_dumani.py` her kaydın SQL'ini
`SELECT COUNT(*) FROM (<sql>) t` içine sarıp çalıştırır: sorgu ayakta mı?
Satır sayısı ÖLÇÜMDÜR, iddia edilmez — iddia edilen tek şey sorgunun koştuğu.

**İlk koşuda 15 sorgunun 3'ü kırıktı** ve sebep aynıydı:
`EncoreMerkez.dbo.Sales.SaleDate` diye bir kolon yok, doğrusu **`Date`**.
Dahası `entities.yaml` bunu zaten yazmıştı ("Date=satış datetime (SaleDate
DEĞİL)") — sema kendi içinde çelişiyordu ve `last_verified: 2026-06-09`
damgası bunu gizliyordu. Düzeltince iki katman daha çıktı: header'da
`DiscountTotalDirect` yok (**`DiscountTotal`**), `SalesProducts`ta `Quantity`/
`RowTotal` yok (**`Amount`** / **`TotalPrice`**).

> **Kırık sorgu SİLİNMEZ.** Doğru ad ölçülür, SQL düzeltilir, damga bugüne
> çekilir, sonra o sorguyu koruyan bir değişmez yazılır. Silmek öğrenilen
> sorguyu unutmaktır; atmak değil sağlamlaştırmak gerekir.

Düzeltirken ölçülen yeni gerçek: `SUM(SalesProducts.TotalPrice)` =
`GrossTotal − DiscountTotal` (KDV dahil, indirim düşülmüş) → **net KDV-hariç =
`TotalPrice − VatTotal`**; 01–03.09 penceresinde kalem ve header birebir aynı
(7.760.175,16). Bu kimlik artık `pos-kalem-header-mutabakati` değişmeziyle
korunuyor: kalem raporu ile KPI farklı ciro göstermeye başlarsa kırmızı verir.

### `korur` alanı — değişmez hangi sorguyu koruyor

Katalog sorgularının taşıyıcı yapısı 9 değişmeze çevrildi (kod kümesi kapalı ·
köprü ayakta · kolon duruyor · linked server canlı · kalem-header mutabakatı).
Her kayıt `korur: [<query-id>…]` taşır ve koşucu bunu `queries.yaml` ile
**çapraz denetler** — yazım hatalı referans sessizce bağlantısız kalmasın diye.
Tutar değişmez olamaz (ölçüm); çevrilen şey sorgunun DAYANDIĞI yapıdır.

### Araştırma dayanağı (2026-09-03)

| Bulgu | Kaynak |
|---|---|
| Semantik katman doğruluğu %84-90 → %98-100 | dbt 2026 benchmark |
| 4 KB iş-anlamı belgesi +17-23 puan | arXiv 2604.25149 |
| Öz-doğrulama şema eşlemede +%10,4 | BDCC 10040104 |
| Ölçüt SQL metni değil **çalıştırma sonucu** | promptfoo text-to-SQL eval |
| Baseline kaydet, her değişiklikte regresyon ara | Arthur AI |

## "Başka ne olabilir?" kapısı

Belinza'daki dört hatanın en tehlikelisi **yorum** hatasıydı: ölçüm
doğruydu, ona konan **ad** yanlıştı ve ölçülmüş gibi sunuldu.

> Bir bulgu rapora/sema'ya girmeden önce **en az bir alternatif
> açıklama** yazılıp elenir. Elenemiyorsa bulgu **ÇIKARIM** etiketiyle
> yazılır.

Somut: üretimde plandan sapma "fire ölçülmeye başladı" sanıldı. Sekiz
malzemenin sekizinde de oran **tam 4,67**'ydi — fire her malzemede aynı
orana denk gelmez. Gerçek sebep bölünmüş üretim emri hatasıydı. Tek
soru ("başka ne olabilir?") bunu ilk bakışta çıkarırdı.

## Confidence ölçeği
`1.0` kalıcı (PK/FK) · `0.9-0.99` canlı %99+ eşleşme · `0.5-0.8` gözlem ama tam teyit yok · `0.3-0.5` hipotez/teyit bekliyor.

## Yaşlanma (Decay) & Curator-check — plan-12 WS-1

Fact-Force Gate'in eksik yarısı: doğrulanmış gerçek **yaşlanır**. Sessiz-yanlış-rakam riski bayatlamış varsayımdan doğar (stkKod=barkod, depo key-mismatch).

1. **Yeni/güncellenen kayıtta `last_verified` zorunlu** (confidence:1.0 hariç — kalıcı, yaşlanmaz). Yaşlanma + ttl tablosu: `sema/README.md` § Decay.
2. **Sorgu yazmadan önce sema'ya bakarken** kayıt stale ise (`last_verified + ttl_days < bugün`) → körü körüne kullanma; **canlı doğrula**, sonra `last_verified`'ı bugüne çek (çürürse düşür/sil — `sema-ogren` çelişki kuralı).
3. **Stale = bayrak, otomatik aksiyon DEĞİL.** Kayıt silinmez/değişmez; sadece "yeniden doğrula" işareti. Otomatik archive YASAK — kullanıcı onayı şart.
4. **Curator-check** `session-handoff` içinde inactivity-triggered (≥7g): stale + dar/çakışan kayıt taraması. Derin konsolidasyon → `consolidate-sema` skill'i (dry-run rapor + onay).

## İlişkili
- `sema/README.md`, `.claude/skills/sema-ogren/SKILL.md`, `.claude/skills/consolidate-sema/SKILL.md`
- `.claude/rules/sql-server-conventions.md` — T-SQL yazım kuralları (DMY, compat 110, IsValid)
- `sorgular/SEMANTIK_KATMAN.md` — insan-okunur tam sözlük
