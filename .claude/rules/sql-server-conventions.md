# SQL Server / DerinSIS / EncoreMerkez Konvansiyonları

_BKM Kitap projesinde T-SQL yazımı için kalıcı kurallar._

## Tarih (KRİTİK)

- Yerel sorgular: DMY. `dd.MM.yyyy` veya `CONVERT(varchar, tarih, 104)`.
- Linked server (ODAKJOKER.JOKER): ISO. `'YYYYMMDD'`. DMY burada sessiz hata.
- `yyyy-MM-dd` HİÇBİR yerde kullanılmaz.

## stkKod ≠ Barkod — HER ZAMAN stkID (KRİTİK)

- **`urn.stkKod` BARKOD DEĞİL.** EncoreMerkez `SalesProducts.BarcodeNo` ↔ `urn.stkKod` join **YANLIŞ** — bazı kategorileri (ör. Oyuncak) sessizce kaçırır → ciro undercount, sahte "ölü stok".
- **Kural:** Ürün/kategori/marka eşleşmesi **her zaman stkID üstünden**.
  - DerinSIS-içi: `irsHrk.ehstkID = urn.stkID` (en temiz; satış ehTip 4/100).
  - Barkod gerekiyorsa: `SalesProducts.BarcodeNo = urnBrkd.urnBarkod` → `urnBrkd.urnBrkdStkID = urn.stkID` (`urnBrkdOnce=0`). **stkKod ile join etme.**
- Kategori/marka ciro raporlarını mümkünse **irsHrk** (stkID) üzerinden al → envanter/devir ile tek kaynak, tutarlı.
- ✅ Tüm stkKod=BarcodeNo hataları düzeltildi (09.06): `generate_brief.py` (SQL_CATEGORY+TOTAL), `G4-kategori-magaza.sql`, `A6-marka-yayinevi.sql`, `04-karzarar/2026-05-07-...maliyet-karsilastirma.sql` (u_b) → hepsi Products.Code=stkID. Dashboard `gm_dashboard.py` → irsHrk. (Eski `briefings/*/brief.html` çıktıları tarihsel, regenerate ile düzelir.)

### EncoreMerkez ↔ DerinSIS KÖPRÜSÜ = Products.Code (09.06 keşif — KESİN)

- **`EncoreMerkez.Products.Code` (int) = `DerinSIS.urn.stkID`** — %99,98 eşleşme (798.349/798.527). `Code` stkKod DEĞİL (%9), barkod hiç değil.
- **Doğru POS join:** `SalesProducts.ProductsId → Products.Id`, sonra `urn.stkID = CONVERT(int, Products.Code)` (EncoreMerkez compat 110 → `TRY_CONVERT` yok; `ISNUMERIC(p.Code)=1` guard + `CONVERT(int,p.Code)`).
- Bu, EncoreMerkez POS verisini (per-mağaza, per-fiş) **doğru kategori/marka**ya bağlar — barkod join'in kaçırdığını çözer (Oyuncak ciro 700K→10,96M doğrulandı 09.06).
- Saf DerinSIS analizlerde hâlâ `irsHrk.ehstkID=urn.stkID` en temiz; POS-özel (EncoreMerkez Sales/SalesProducts) gerekince Products.Code köprüsünü kullan.

## Field Adlandırma

- DerinSIS: `urn.stkAd` / `urn.stkID` (urnAd/urnID HATA)
- DerinSIS: `urnKtgr2.ktgrAd` (ktgr2Ad HATA)
- EncoreMerkez Sales: `Sales.LineCount` GÜVENİLMEZ
- EncoreMerkez Campaign: `IsDeleted` kolonu YOK
- EncoreMerkez SalesProducts: `WHERE IsValid = 1` ZORUNLU

## Cross-DB Join

`COLLATE Turkish_CI_AS` — BKM ↔ EncoreMerkez/DerinSIS string join.

## EncoreMerkez Compat 110 (SQL 2012)

Çalışmaz: `STRING_AGG`, `TRIM`, `IIF`, `TRY_CONVERT`.
Alternatifler: `STUFF + FOR XML PATH`, `LTRIM(RTRIM(...))`, `CASE WHEN`, `CONVERT + ISDATE`.

## Aggregate + Kolon Gotcha (17.06 dersi)

- **`SUM(CASE WHEN ... NOT IN (subquery) ...)` YASAK** — SQL: "Cannot perform an aggregate function on an expression containing a subquery". Aggregate'in CASE'i içinde alt-sorgu olmaz. Çözüm: filtreyi WHERE'e taşı, VEYA Customer-join'li kolon-form kullan (`IcKartFiltre.SqlCols`). WHERE içinde NOT IN(subquery) SERBEST — sadece aggregate-CASE içinde yasak.
- **`EncoreMerkez.Sales.TotalAmount` ≠ NET CİRO.** TotalAmount küçük/adet-benzeri değer (örn. GrossTotal=1320 iken TotalAmount=13) — ciro DEĞİL. Net ciro daima `GrossTotal - DiscountTotal - VatTotal` (KDV-hariç). `SUM(TotalAmount)`'ı ciro sanma (10_01/10_02 bu yüzden çöp üretiyordu).

## İndirim Kolonları

- `DiscountTotalDirect` = TOPLAM.
- `DiscountTotalCampaign` = alt küme.
- Sadece Direct kullan.

## Belge Filtresi

`DocumentsTypeId IN (1, 2, 3, 6, 7, 8)`:
- 1=Fiş, 2=Fatura, 3=İade(-), 6=Personel Fiş, 7=Personel Fatura, 8=Sınav

SUM iade sign:
```sql
CASE WHEN s.DocumentsTypeId = 3 THEN -s.GrossTotal ELSE s.GrossTotal END
```

AVG iade hariç:
```sql
CASE WHEN s.DocumentsTypeId <> 3 THEN ... END
```

## ŞUBE CİROSU: `eTip = 100` TEK BAŞINA YETMEZ (B-162/B-164, 08.09.2026)

**Kanonik formül: `eTip 100 − 101 + 4 − 5`.** (`irsHrk` tarafında `ehTip` aynı kodlar.)

- `eTip 4` **"Mağaza Satış"**, `eTip 100` (POS Satış) ile AYRI bir kanal — ikisi kesişmez.
  Pratikte **yalnız İst.Yolu'nda** anlamlı: son 12 ay 50,0M ₺ / 2.170 belge; FSM ve Özlüce
  0,3-0,6M/ay (ihmal). İçeriğinin %86-89'u Sınav kategorisi. `eTip 101/5` = POS / Mağaza
  Satış İadesi, ayrı satır — `100` içinde netlenmez.
  ⚠ **ORANIN YÖNÜNE DİKKAT — bu satır önce "Sınav Okulları toplu faturaları buradan akar"
  diyordu ve YANILTICIYDI (düzeltildi 2026-09-12).** İki ayrı iddia var ve ikisi de doğru
  ama YÖNLERİ ters: *"eTip 4'ün içeriğinin %86-89'u Sınav'dır"* ≠ *"Sınav'ın çoğu eTip 4'ten
  akar"*. Ölçüldü (Ağu-2026, İst.Yolu): EncoreMerkez `DocumentsTypeId=8` (Sınav) **121,0M ₺**
  / 2.031 belge iken irsHrk `ehTip=4` yalnız **14,1M ₺** — **8,6 kat fark.** Yani Sınav'ın
  ~107M'si `ehTip=100`'ün İÇİNDE. Bu zaten aşağıdaki "eTip 100 günlük ÖZET belge, belge-bazlı
  ayrım YAPILAMAZ" kuralıyla tutarlı; ama "buradan akar" ifadesi okuyanı `eTip 4`'ü Sınav
  vekili sanmaya iter. Sınav'ı ayırmak isteyen **belge bazlı** (`DocumentsTypeId=8`) ya da
  **ürün bazlı** (`KatAna LIKE 'Sınav Okul%'`) gitmek zorundadır — `eTip 4` vekil DEĞİLDİR.
  Kanıt: `sorgular/2026-09-12-net-ciro-mutabakat.sql` blok 4.
- **KASA MUTABAKATINDA `100−101` TEK BAŞINA YETMEZ** (ölçüldü 2026-09-12, Ağu-2026):
  yalnız `100−101` ile EncoreMerkez toplamı FSM −%0,98 · Özlüce −%1,13 · **İst.Yolu −%9,50**
  sapar; `4` eklenince +%1,35 / +%0,27 / **+%0,57**'ye iner. Sebep: kasa (Encore) Sınav
  faturasını da kaydeder, ERP tarafında o tutarın bir kısmı `eTip 4`'tedir.
  ⭐ Buna karşılık **`ehTip=101` ↔ Encore `DocumentsTypeId=3` KURUŞU KURUŞUNA tutar**
  (üç mağazada fark 0,33-0,37 ₺, yuvarlama). İade tarafı birebir eşleşen tek uçtur.
- **Ölçülen sapma** (Oca-2025..Eyl-2026, yalnız `100` vs kanonik formül):
  · Sınav **hariç** (perakende): FSM −%0,5..1,0 · Özlüce −%0,4..0,8 · **İst.Yolu +%2,7..4,4** · 3 mağaza toplamı +%0,5
  · Sınav **dahil** (toplam ciro): **İst.Yolu +%8,2..9,8** · Sınav kanalı +%12,4
  Yani maliyet/ciro oranı gibi Sınav-dahil paydalarda hata BÜYÜK, Sınav-hariç perakende
  metriklerinde küçük ama İst.Yolu'nda hâlâ gürültü üstü.
- **Mutabakat kanıtı:** kanonik formül EncoreMerkez toplamıyla üç şubede de %0,08-1,28 içinde
  tutuyor; yalnız `eTip 100` ile İst.Yolu −%10,24 sapıyordu.
- **Zaten doğru olan kalıp:** `ehTip IN (4,100)` / `IN (1,4,100)` yazan sorgular etkilenmez
  (dashboard'un çoğu böyle). Tehlikeli olan `eTip = 100` **tek başına**.
- ⚠ İstisna: `CASE WHEN ehTip=100 ...` bir alt-metrik ayırmak için kullanılıyorsa (satınalma
  retail-cap, kanal kırılması analizi) ve WHERE zaten geniş küme ise DOĞRUdur — dokunma.

### KANAL AYRACI: belge tipi ≠ ürün kategorisi

- **Kanal sorusu** (raf/walk-in vs kurumsal Sınav) → **belge bazlı**: EncoreMerkez
  `DocumentsTypeId = 8`. DerinSIS'ten belge-bazlı ayrım **YAPILAMAZ** (`eTip 100` günlük ÖZET
  belge, ayda 32 satır). Belge-bazlı ölçüm yalnız **Ağu-2025 sonrası** güvenli (POS geçişi).
- **Ürün/kategori sorusu** → **ürün bazlı**: `bkm.UrunBilgi.Kategori3` (+ `KatAna LIKE 'Sınav Okul%'`).
- İkisi aynı tabloda karıştırılmaz. Ölçülen fark: Sınav faturasında satılan kitap/kırtasiye
  21,8M ₺ (2026 · 32 gün), perakende fişindeki Sınav ürünü 0,2M → İst.Yolu Eyl-2025 perakendesi
  belge bazlı 26,0M, ürün bazlı 43,1M. Ekim'de yakınsar (Sınav sezonu bittiği için).
- Değişmez: `etip4-magaza-satis-istyolu-anlamli` · sema: `MEKAN_CIRO_MUTABAKAT_FORMULU`,
  `KANAL_AYRACI_KANONIK`. Kanıt: `sorgular/2026-09-08-okul-hizali-ciro-tahmini.sql` blok 9.

## POS ÖZET ↔ STOK DEFTERİ: KURUŞU KURUŞUNA KİMLİK (12.09.2026 ölçüldü)

`dbo.posOzetUrun` DerinSIS'in **POS ürün-gün özeti**dir ve `irsHrk` ile kanonik
köprüyü kurar. ERP satıcısı bu köprü için iki kontrol view'ı da yazmış:
`dbo.kontrol_posOzetUrunirsHrk_vw` (POS'ta var, defterde YOK = öksüz) ve
`dbo.kontrol_posOzetUrunirsHrkAdet_vw` (ikisi var, ADET uyuşmuyor).
Ölçüm (İst.Yolu Ağu-2026): **öksüz 0 · adet uyuşmazlığı 0.**

**Kanonik formül:**
```sql
-- join: posMekan=ehMekan AND posTarih=ehTrhS AND posStkID=ehstkID
-- KDV:   posOzetUrun.posKDV = urnKDV.kdvID
irsHrk.ehTutarN (ehTip=100) = SUM( posOzetUrun.satTutar  / (1 + urnKDV.kdvYuzde/100) )
irsHrk.ehTutarN (ehTip=101) = SUM( posOzetUrun.iadeTutar / (1 + urnKDV.kdvYuzde/100) )
```
Tam-ay koşumu: POS 128.097.715,43 ↔ defter 128.097.709,99 → **fark +5,44 ₺**
(128 milyon üzerinde; satır-başı yuvarlama). İade: 1.677.233,89 ↔ 1.677.233,65.

⚠ **ÜÇ TUZAK BİR ARADA** (üçü de 12.09'da yaşandı, ölçümle yakalandı):
1. **`posKDV` ORAN DEĞİL KOD** — `tinyint`, `urnKDV.kdvID`e karşılık gelir
   (1=%0 · 2=%1 · 6=%10 · 7=%20). `/(1+posKDV/100)` yazmak sessiz yanlış rakam üretir.
   `urn.KDVs` için zaten yazılı olan tuzağın POS ikizi.
2. **`satTutar` KDV DAHİLDİR** — `ehTutarN` KDV hariçtir, doğrudan karşılaştırılamaz.
3. **`satIndirim` ÇIKARILMAZ** — indirim `satTutar` içinde ZATEN uygulanmıştır; bu kolon
   yalnız indirimin TUTARINI bildirir. Çıkarınca tutar yarıya iner ve "fiyat tabanı
   farklı" gibi **SAHTE bir bulgu** doğar (tam bu oldu: "~1,97 kat" diye açık soru
   yazıldı, sebep ölçüm hatasıydı).

Kanıt: `sorgular/2026-09-12-posozeturun-irshrk-kimlik.sql` · sema: `entities:dbo.posOzetUrun`.

## MERKEZ DEPO STOĞU = HER ZAMAN WMS (KRİTİK — kullanıcı direktifi 03.09.2026)

_"ERP merkez depo defteri senkron sorunu var, her zaman WMS stoklarına bakmalısın."_

- **Merkez depo (mekan 12) stoğu ERP defterinden OKUNMAZ.** `dbo.stokSonAltDepo_vw` mekan 12
  değeri ERP defteridir ve WMS ile senkron değildir: ölçüm 03.09.2026 → pozitifler 6.230.071,
  negatifler **−4.242.441** (fiziksel olarak imkânsız), net 1.987.630.
- **Kaynak = WMS hücresel stok:** `depo.stok_adres_palet_vw` (adres + palet düzeyi;
  kolonlar `adrsAlanTipID · adrsID · adrsAd · PaletID · stkID · Stok`). Alan tipleri
  (`depo.adresAlanTip`): **0 RAF ALANI** (03.09: 3.799.795 / 21.842 ürün) · **1 GİRİŞ ALANI**
  (195.470 / 4.633) · **2 ÇIKIŞ ALANI** (543.555 / 12.082).
- **Ay-sonu snapshot:** `bkm.StokAyBakiyeMekanBazli` (`Kaynak='WMS'`, `ehMekan=12`) — bu tablo
  aynı view'dan `adrsAlanTipID IN (0,1)` ile doldurulur, yani **ÇIKIŞ ALANI hariç** (sevke
  hazırlanmış mal). Geçmiş depo bakiyesi YALNIZ bu snapshot'tan okunur; irsHrk ile backfill
  edilmez (değişmez: `depo-bakiyesi-irshrk-den-doldurulmaz`).
- **Mağaza stoğu farklı:** mekan 1/4477/4478 için `stokSonAltDepo_vw` DOĞRUdur (irsHrk ve
  snapshot ile %0,3-4,8 içinde tutuyor). Kural yalnız merkez depo için geçerli.
- **Kapsam farkı bilinsin:** ERP defteri ambalaj/sarf da taşır (ör. "Geri Dönüşüm Kağıt Madde
  Alımı" 1.758.386 + poşetler ~370K, `Genel` kategorisi); WMS hücresel stok satılabilir malı
  tutar. Kitap tarafında ERP defteri kalıntı taşır (çeşit 1.254 vs WMS 127).
- **Uygulanan yerler (K-37):** `dashboard/Data/OdakQueries.cs` (`depo` CTE) ·
  `dashboard/Data/RefQueries.Envanter.cs` (kategori-çeşit UNION ALL) ·
  `scripts/export_odak_stok.py`. Yeni bir depo-stok sorgusu yazarken bu deseni izle.
- ⚠ `ent.odak_depo_Stok` BAŞKA BİR ŞEY: ODAK (e-ticaret fulfillment) deposu, ~7,2M adet.
  Merkez depo ile karıştırılmaz.

### ⚠ WMS DE MUTLAK DOĞRU DEĞİL — kural ÇİFT YÖNLÜ (09.09.2026 genişletme)

Yukarıdaki kural "defter bozuk, WMS'i kullan" diyor ve bu **tek yönlü** okunuyordu. Ters yön
de ölçüldü: **satış ERP'de kesilip WMS'ten düşülmediğinde WMS şişik kalıyor.**

| Yön | Çeşit | Adet | Anlamı |
|---|---|---|---|
| Defter pozitif, WMS'te yok | 9.146 | 1.996.995 | Defter kalıntı/negatif taşıyor → WMS'in tercih sebebi |
| **WMS pozitif, defter ≤ 0** | **349** | **3.757** | **HAYALET** — mal fiilen olmayabilir |

Hayaletin 261'inde merkez satışı, 342'sinde belgesiz palet hareketi var. **KİTAP tarafında
yığılı:** Akademi 84 çeşidin 76'sı (%90) · Kitap 127'nin 77'si (%61) · Kırtasiye %0,9 ·
Oyuncak %0,8. Merkez depo kitap tutmuyor; oradaki tek-adetler kalıntı.

**Mekanizma** (stkID 248104 uçtan uca izlendi): 23.02.2026 İst.Yolu→merkez transfer (+1,
irsaliye 7121400, WMS'e de işlendi) → 22.05.2026 merkez **satış −1** (belge 7135278, WMS'te
karşılığı YOK) → 10.07.2026 elle palet taşıması raf 44711 → GR01 37250 (`piIrsID=0`, belgesiz).
Sonuç: ERP 0, WMS 1 adet.

**Kural:** merkez stoğunu WMS'ten oku **ama defterle karşılaştır**; çelişiyorsa sayı
ŞÜPHELİ'dir ve fiziksel sayım yapılmadan karara dayanak alınmaz. Panelde bu uyarı ekranda
(`GetDepoAdresAsync` adresleri + defter bakiyesini birlikte döner); liste raporu
`scripts/gr_palet_supheli_excel.py`.

**Palet defteri okuma kuralı:** `depo.paletIcHrk`'da `piİlkID` hareketin SAHİBİ palet,
`piSonID` karşı palet (iki hipotez view ile kıyaslandı, yalnız bu tuttu). `pGC` 0=giriş /
1=çıkış · `pHrkTip` 0 KULLANICI · 1 EMİR · 2 SAYIM · 3 GERİ AL · `piIrsID=0` belgesiz taşıma.
⚠ Kolon adı Türkçe İ ile: **`piİlkID`** — ASCII `piIlkID` Err 207 verir.

## MÜŞTERİ RAPORLARI = FİŞ BAZLI (KRİTİK — 16.06.2026 CFO direktifi)

**Tüm müşteri/sadakat raporları SADECE perakende fiş üzerinden çalışır.** Fatura(2)/Personel(6,7)/**Sınav Okulları(8)** belge tipleri HARİÇ — bunlar kurumsal/B2B, perakende müşteri davranışı değil (Sınav tek başına "kartsız"ı 266M şişiriyordu, B-102).

- **Sayım/frekans/recency raporu** (RFM segment, RFM geçiş, tekrar-alış, kazanım, kart-oranı): `DocumentsTypeId = 1` (sadece satış fişi). İade(3) bir "alış" değil → frekansa katma.
- **Ciro (Monetary) raporu** (Pareto, win-back, kartlı/kartsız sepet): `DocumentsTypeId IN (1,3)` — iade sign'lı düşülür (`CASE WHEN =3 THEN -net ELSE net`).
- **Kartsız = anonim DAHİL** (`CustomersId=0` yürü-gel müşteri). `CustomersId>0` şartı kartsız tarafını yok eder — KULLANMA. Kartlı = `CustomersId>0 AND CardNumber<>''`.
- İç-kart hariç tutma her zaman `IcKartFiltre` (isim Mağaza/Kumbara + tel 599/699 + elle liste).
- **UI'da belirgin yazılır:** her müşteri sayfası/paneli "fiş bazlı (perakende)" etiketi taşır.

## SalesProducts CROSS APPLY

```sql
SELECT s.Id, sp.UrunSayisi
FROM Sales s
CROSS APPLY (
    SELECT COUNT(*) AS UrunSayisi
    FROM SalesProducts
    WHERE SalesId = s.Id AND IsValid = 1
) sp
```

## CTE Tercih (Fikri Tercihi)

- CTE > subselect.
- Brüt + İndirim + Net her zaman birlikte.
- Ürün sayısı her ciro raporuna dahil.
- Hazır SQL: çalıştırılabilir + 3AL2ÖDE kırılımlı.

## Dashboard Bağlantısı master'a Açılır → 3-PARÇALI İSİM ZORUNLU (23.06 dersi)

- **`Db.OpenAsync()` varsayılan katalog = `master`** (`.env MSSQL_DATABASE=master`; app cross-DB: DerinSISBkm + EncoreMerkez + DerinCrm). 2-parçalı isim (`bkm.x`, `mhs.x`, `dbo.car`) master'dan çözülmez → **"Geçersiz nesne adı" (Err 208).**
- **Kural:** Dashboard Dapper sorgularında ERP nesnesi her zaman **3-parçalı**: `DerinSISBkm.bkm.Fin_AyKapanis`, `DerinSISBkm.mhs.mhsMizan_vw`, `DerinSISBkm.dbo.irsHrk`. (RefQueries zaten böyle; MuhasebeQueries/MizanQueries 2-parçalı yazıldı → login-arkası 208 patladı: Mizan/Kontrol/Ayarlar.)
- **MCP test YANILTIR:** `mcp__sqlserver__sql_query` `database=DerinSISBkm` ile çağrılır → 2-parçalı orada ÇALIŞIR ama app (master) bağlamında ÇALIŞMAZ. "MCP'de doğrulandı" ≠ "app'te çalışır". 3-parçalı yaz, gerekirse `database=master` ile doğrula.

## SORGU ARACI: `sqlcli` VARSAYILAN (kullanıcı direktifi 03.09.2026)

**Tek-sorgu keşif/ölçüm için varsayılan araç `sqlcli`** — ad-hoc pymssql/pyodbc
snippet'i yazma. Kullanıcı iki kez hatırlatmak zorunda kaldı ("sqlcli neden
kullanmıyorsun", "kullanmayı sürekli unutuyorsun").

**Profil (en kısa yol — `sqlcli.json` depoda, şifresiz):**
```bash
sqlcli query  --profile erp   --format json "SELECT COUNT(*) FROM dbo.urn"
sqlcli query  --profile zirve "SELECT TOP 5 * FROM dbo.vw_PuanBil"
sqlcli lookup --profile erp   dbo.irsTip_vw --count-from dbo.irsHrk.ehTip
sqlcli assert --profile zirve --eq 0 --label primgunu "SELECT COUNT(*) FROM dbo.vw_PuanBil WHERE Primgunu > 31"
```
Profiller: `erp` (DerinSISBkm) · `encore` (EncoreMerkez) · `zirve` (BKM_GENEL) · `panel`.
Şifre `sqlcli.json`'da DURMAZ — `${MSSQL_PASSWORD}` yer tutucusu `.env`'den doldurulur
(v2.2 `${ENV}` genişletmesi); karşılığı yoksa **hata verir**, sessizce boş bağlanmaz.

`bash tools/sq.sh [--zirve|--joker] [--json] [--db X] "<SELECT>"` sarmalayıcısı hâlâ
çalışır (profil yoksa/başka depoda işe yarar) ama profil varken gerek kalmaz.

**v2.2 yetenekleri (03.09.2026 eklendi — `D:\Dev\sqlcli`, git altında, v2.2.0):**

| Yetenek | Kullanım | Ne için |
|---|---|---|
| **`assert`** | `sqlcli assert --eq 0 --label x --why "..." "SELECT COUNT(*)…"` | Öğrenilen şema gerçeğini koşulabilir denetime çevirir. **exit 0 geçti · 1 KIRIK · 2 KOŞAMADI** — üçüncüsü bilinçli: koşamamak yeşil değildir |
| **`lookup`** | `sqlcli lookup dbo.fatTip_vw --count-from dbo.fat.eTip` | Kod kümesini lookup'tan YAML/JSON döker + canlı kullanım sayısı; kullanılmayanı "canlıda yok" işaretler. "Liste elle yazılmaz" kuralının aracı |
| **`--read-only`** | bayrak veya `SQLCLI_READONLY=1` | Yazma anahtar kelimesi içeren sorguyu reddeder (string/yorum elenerek taranır) → `erp-write-policy` araç düzeyinde zorlanır |
| **`--param ad[:tip]=deger`** | `--param bas:date=2026-09-01` · `--param kod:str=20260901` | String birleştirme yok (injection + tarih tuzağı). **`dd.MM.yyyy` REDDEDİLİR** (gün/ay belirsiz) — ISO yaz ya da `:str` + `CONVERT(...,104)` |
| **`--timeout` / `--retry`** | `--timeout 60 --retry 2` | Yalnız geçici hatada (10053/10060/-2/1205) sınırlı ve **görünür** yeniden deneme; kalıcı hata (207) denenmez |

⚠ **`--max-rows` varsayılanı 1000 ve SESSİZ keser** (server-side TOP wrap; uyarı satırı yok).
Toplu çekimde (kişi-gün, segment, saat×mağaza matrisi) 1000'e dayanırsan eksik veriyi TAM sanırsın —
04.09 vardiya çekiminde tam bu oldu: 1.217 satırlık sonuç 1.000'de kesildi, son gün hiç görünmedi.
**Kural:** satır sayısı belirsiz her çekimde `--max-rows` açıkça ver ve dönen satır sayısını beklenenle
karşılaştır (tam 1000/verilen değer = kesilme şüphesi).

**Kodlama:** v2.2'den beri sqlcli **UTF-8** yazar (Türkçe doğru, dosyaya/pipe'a alınabilir).
v2.1 ve öncesi cp857 yazıyordu — `tools/sq.sh` ikisini de okur (UTF-8 dene, olmazsa cp857).

**KANONİK KOPYA = `D:\Dev\sqlcli`** (global dotnet tool; 03.09'da `git init` edildi).
`D:\Dev\fifo\sqlcli` ve `MIMBAL/tools/sqlcli` **eski fork**'lar — çağırma. Yeniden kurulum:
`cd D:/Dev/sqlcli && dotnet pack && cp bin/Release/SqlCli.*.nupkg nupkg/ && dotnet tool update -g --add-source ./nupkg SqlCli`.

**Hangi araç ne zaman:**

| İş | Araç |
|---|---|
| Tek sorgu keşif/ölçüm/sayım | **`bash tools/sq.sh`** (sqlcli) |
| Şema keşfi (kolon/FK/index/ilişki) | `sqlcli describe` / `relationships` / `search`, ya da MCP `sql_describe_table` |
| Değişmez koşumu (28 kayıt, çok sunucu) | `tools/sema_degismez.py` |
| Tek denetim / CI kapısı | **`sqlcli assert`** (exit 1/2) |
| Kod kümesini sema'ya yazma | **`sqlcli lookup --count-from`** |
| Katalog dumanı | `tools/sema_sorgu_dumani.py` |
| Rapor/Excel üretimi (script içi çekim) | **pyodbc** (Türkçe doğru, `coding-discipline.md`) |
| Çok adımlı MCP oturumu, hızlı tek-satır sanity | MCP `mcp__sqlserver__*` / `mcp__zirve__*` |

**Yazma:** `sq.sh` yalnız SELECT içindir. ERP'ye yazma yasak (`erp-write-policy.md`).

### Dört sözleşme (araç sınırı — 03.09.2026 kararı)

Bir başka depoda (Belinza/Odoo) aynı ihtiyaçlar çıktı ve **sqlcli'ye Odoo yeteneği
EKLENMEDİ**: `ISqlDialect` dikişi SQL lehçeleri içindir, `search_read`/`fields_get` oraya
sokulursa soyutlama yalan söyler. sqlcli kanonik ve paylaşımlıdır (README "kaynak
fork'lamayın" diyor; `MIMBAL/tools/sqlcli` ve `fifo/sqlcli` kopyaları zaten drift olmuş).
**Taşınan şey kod değil, dört sözleşme** — hangi araçla çalışıyorsak bunlar geçerli:

| Sözleşme | Bu depoda karşılığı |
|---|---|
| **Tek kimlik yolu** | Kimlik yalnız `.env` (+ `sqlcli.json` içindeki `${ENV}` yer tutucusu). Başka dosyaya kopyalanmaz, komut satırına yazılmaz, ekrana basılmaz. Karşılığı olmayan yer tutucu **hata verir** — sessizce boş şifreyle bağlanmaz |
| **Salt-okuma muhafızı = İZİN LİSTESİ** | `--read-only` yalnız `SELECT` ve `WITH…SELECT` geçirir; **tanınmayan her şey reddedilir**. Yasak listesi yaklaşımı yanlıştı: listede olmayan yazma yolunu (Odoo'da `action_post`/`button_validate`, SQL'de `EXEC`/`SET`) kaçırır ve **kaçırdığını söylemez**. Red mesajı neyi tanımadığını yazar |
| **Çıkış kodu 0/1/2** | `assert`: 0 geçti · 1 KIRIK · **2 = KOŞAMADI**. İkisi ayrı: bir ölçümün boş dönmesiyle hiç koşmaması ekranda aynı görünür; "koşamadı" asla yeşil sayılmaz |
| **Görünür retry** | Yeniden deneme yalnız geçici hatada, sınırlı ve **her deneme yazdırılır**. Sessiz retry "yavaş" ile "ağ kopuyor"u ayırt edilemez yapar |

**Sonuç:** yeni bir veri kaynağı (Odoo, REST, dosya) sqlcli'ye eklenmez — o kaynağın kendi
aracı yazılır ve bu dört sözleşmeye uyar.

## MCP Sunucu Seçimi

- `sqlserver` (192.168.40.201) → BKM/ERP varsayılan.
- `sqlserver-express` (192.168.40.66\SQLEXPRESS) → "Express'te", "66'da".

## MCP sql_query Limitleri (gotcha)

- **CTE çalışmaz.** `mcp__sqlserver__sql_query` sorguyu auto-TOP wrap edip `(WITH...)` parantezler → `Incorrect syntax near ')'`. MCP için **tek SELECT, CTE'siz** yaz. CTE'li tam sorgular SSMS içindir.
- **ORDER BY top-level olmaz.** Wrapper derived table yapar → `ORDER BY ... unless TOP/OFFSET/FOR XML`. MCP'de ORDER BY'ı çıkar veya `TOP` ekle.
- **Multi-statement reddedilir.** `DECLARE @x; SELECT...` → "Birden fazla statement". MCP'de değişkenleri inline literal yap. SSMS'te DECLARE serbest.
- **`OBJECT_DEFINITION('dbo.X')` NULL ≠ şifreli (04.07 dersi).** NULL üç sebepten: (a) `WITH ENCRYPTION`, (b) **yanlış şema** (obje `mhs`/`ent`/`bkm`'de, sen `dbo` aradın), (c) VIEW DEFINITION izni yok. "dbo.cariIsle_oto NULL → şifreli" sandım; halbuki `mhs.cariIsle_oto`'ydu. **Doğrusu:** şemadan bağımsız teyit → `SELECT s.name,o.name,CASE WHEN m.definition IS NULL THEN 'NULL' ELSE 'OK' END FROM sys.objects o JOIN sys.schemas s ON s.schema_id=o.schema_id LEFT JOIN sys.sql_modules m ON m.object_id=o.object_id WHERE o.name='<ad>'`. Hâlâ NULL ise şifreli/izin. DerinSIS: native SP (`dbo.car_isle`, `mhs.mhsEnt_car`) gerçekten `WITH ENCRYPTION`; config-level (`mhs.cariIsle_oto`, `ent.AnaCariBul`) okunur.

## E-ticaret Müşteri Zinciri

`J_ORDERS.CLIENTREF → J_ORDER_CLIENTS.LOGICALREF → CUSTOMERREF`. J_ORDER_CLIENTS standart. CUSTOMERREF=0/NULL = misafir.

## E-ticaret Sipariş Satırı + stkID Köprüsü (09.06 — KESİN)

- **Sipariş satırları:** `J_ORDER_DETAILS.ORDERREF = J_ORDERS.ORDERID` (LOGICALREF DEĞİL! ORDERID = "TS...30323794" kodundaki sayı).
- **Ürün adı:** `J_ORDER_DETAILS.ITEMREF = J_ITEMS.LOGICALREF` → `J_ITEMS.NAME`.
- **E-ticaret stkID köprüsü:** `J_ITEMS.DERINSIS_ID = urn.stkID` (DerinSIS ürün bağı; kategori için `bkm.UrunBilgi.StkID`/`KatAna` — JOKER'den `DERINSIS` linked server ile erişilir).
- **Fiyat:** `SELLINGPRICE` = BİRİM net fiyat (satır tutarı = `QUANTITY*SELLINGPRICE`). `SELLINGPRICEWITHOUTDISCOUNT` = birim brüt; indirim = `QUANTITY*(WITHOUTDISCOUNT-SELLINGPRICE)`. Kargo `J_ORDERS.CARGOPRICE`, kapıda ödeme `SERVICEPRICE`.

## Müşteri İsmi (Yazarkasa) = DerinCrm.Customer (09.06 — ÇÖZÜLDÜ)

- **`DerinCrm.dbo.Customer.Id = EncoreMerkez.Sales.CustomersId`** (int, temiz 1:1 köprü). `Customer.Name` = ad, `Customer.PhoneNumber` = tel, `Customer.CardNumber` = "2025…" sadakat kartı.
- Join: `LEFT JOIN DerinCrm.dbo.Customer c ON c.Id=s.CustomersId` → `ISNULL(c.Name, s.CustomerCardNo)`.
- ⚠️ Yanlış izler: `DerinSISBkmCrm.dbo.mst` (kart "T…" formatı — EncoreMerkez "2025…" ile EŞLEŞMEZ, ayrı sistem). `EncoreMerkezCrm.Customer` BOŞ (tek "Genel"). `Sales.CustomerData` JSON'unda da var (`"Name"`/`"MobilePhone"`) ama JSON-parse yerine DerinCrm join temiz.
- Not: En yüksek-frekanslı "müşteriler" mağaza iç kartları (İstanbulyolu Mağaza, Kumbara) — gerçek müşteri değil, RFM yorumunda dikkat.

## Kanal Değerleri (J_ORDERS.APPLICATION)

`'Mobil Uygulama (Android)'`, `'Mobil Uygulama (iOS)'`, `'Mobil Site'`, `'Web Sitesi'`.

## ISO Hafta

```sql
DATEDIFF(DAY, '20251229', CAST(ORDERDATE AS date)) / 7 + 1
```

## DerinSIS Adet İşareti + Alış/Satış Kodları (17.06 KESİN DÜZELTME — eski ADR-004 TERSTİ)

**201 kanıt (irsHrk + fatAyr, son 30g):** `tipID` lookup = `irsTip_vw`. Adet işareti **giriş(+)/çıkış(−)** mantığı:
- **Alış = ehTip/eTip `0`.** ⚠ **`10` İKİ SÖZLÜKTE FARKLI ŞEY** (ölçüldü 09.09.2026, `sqlcli lookup --count-from`): `irsHrk.ehTip=10` = **Yerel Alım** (2.378.016 kayıt, alıştır) ama `fat.eTip=10` = **İade Fark Faturası** (7.262 kayıt, alış DEĞİL). `dbo.irsTip_vw` (34 kod) ve `dbo.fatTip_vw` (13 kod) **AYRI** sözlüklerdir; biri diğerine kopyalanmıştı. Fatura tarafında alış = yalnız `eTip=0` (131.903 kayıt). `ehAdetN` **POZİTİF** (giriş). irsHrk ehTip=0 ort +216; fatAyr eTip=0 ort +17,5.
- **Satış = ehTip `1, 4, 100`** (Satış / Mağaza Satış / POS Satış). `ehAdetN` **NEGATİF** (çıkış). Net ciro `ehTutarN` daima pozitif (mutlak tutar).
- **İade:** Satış İade `3,5,101` / Alış İade `2`.
- ⚠️ **eski ADR-004 satırı YANLIŞTI** ("ehTip=1 alış, alış ehAdet negatif") — gerçeğin TAM TERSİ. `ehTip=1=Satış` (alış değil), alış POZİTİF. SEMANTIK_KATMAN.md ("ehAdetN çıkışta negatif") doğruydu.
- Adet toplarken: işaret anlamlıysa koru; mutlak miktar gerekiyorsa `ABS(ehAdetN)`.
- **`ehMaliyet` alış faturasında 0 olabilir** — maliyet ayrı job ile güncellenir; anlık 0 = job çalışmamış.

## Arama Perf: `OR EXISTS` yerine `stkID IN (alt-sorgu UNION)` (17.06 dersi)

- **`WHERE ... OR EXISTS(SELECT 1 FROM urnBrkd ...)` YASAK büyük tabloda** — optimizer urn'u (850K) full tarayıp her satıra EXISTS çalıştırır → 5.8s. Barkod/kod araması böyle yavaşladı.
- **Doğrusu:** eşleşen ID'leri ÖNCE indexli alt-sorgudan topla, sonra ana tabloyu daralt:
  `WHERE u.stkID IN (SELECT stkID FROM urn WHERE stkKod=@q UNION SELECT urnBrkdStkID FROM urnBrkd WHERE urnBarkod=@q AND urnBrkdOnce=0)` → 0.14s (42×).
- Genel kural: `OR` ile birden çok tabloya yayılan filtre → optimizer kötü plan; `IN (alt-sorgu)` veya `UNION` ile ayır.
- Korelasyonlu agregat (bakiye/stok) çok-satırlı derived-table JOIN yerine **OUTER APPLY** ile sadece eşleşen ≤N satıra indir (tüm view agg etme).
- **TVF'i korelasyonlu alt-sorguda satır-başı çağırma → timeout (19.06 dersi).** `WHERE EXISTS(SELECT 1 FROM fn_SonGecerliFiyat(@d,1) f WHERE f.fStkID=u.StkId)` N hedef için TVF'i N kez (her seferinde tüm tabloyu/6.5M satırı window'layıp) çalıştırır → timeout. **Doğrusu:** TVF'in İÇ mantığını çıkar, hedef ID filtresini scan'e GÖM (`WHERE ... AND f.fStkID IN (SELECT StkId FROM #hedef)`), `ROW_NUMBER` sadece hedef satırlarda koşsun. Aynı sonuç, saniyeler. (Aynı "filtreyi aşağı it" ilkesi — `fn_SonGecerliFiyat` 619 üründe TVF-per-row timeout, restrict-then-rownumber ile hızlandı.)

## Dapper DateOnly ↔ SQL `date` (17.06 dersi)

- **SQL `date` kolonu Dapper'da DateTime döner; record ctor `DateOnly` ise eşleşmez** → `materialization` hatası ("matching signature ... System.DateTime").
- **Çözüm:** global TypeHandler (Program.cs'te bir kez): `Dapper.SqlMapper.AddTypeHandler(new DateOnlyTypeHandler())` — `Parse: DateOnly.FromDateTime((DateTime)v)`, `SetValue: DbType.Date + value.ToDateTime(TimeOnly.MinValue)`. Hem okuma hem yazma (param) çözer.

## Dapper 8+ elemanlı ValueTuple → RECORD kullan (24.06 dersi)

- **`QueryAsync<(a,b,c,d,e,f,g,h)>` (8+ eleman) SESSİZ yanlış map'ler.** 8-elemanlı ValueTuple = `ValueTuple<...7, ValueTuple<T8>>` (nested Rest); Dapper 8. elemanı (Rest.Item1) güvenilir map etmez → o kolon **default (0/null)** kalır, hata YOK. Yevmiye fiş `Alacak` (8. kolon) hep 0 göründü ("tutar yok").
- **Çözüm:** 8+ kolonlu Dapper sorgusunda ValueTuple yerine **düz `record`** (isimle map, Rest yok). ≤7 eleman ValueTuple güvenli.
- Genel: çok-kolonlu Dapper materialization = record (positional ctor, isim eşleşmesi) > ValueTuple.

## Dapper POZİSYONEL RECORD: SIRA sözleşmedir, isim DEĞİL (10.09.2026 dersi — 2 kez)

**Positional record'da Dapper SIRA eşler.** SQL SELECT'e araya yeni kolon eklenip record'un
SONUNA yazılınca iki sonuçtan biri olur:
- tipler uyuşmazsa → `InvalidOperationException: A parameterless default constructor or one
  matching signature ... is required` (patlar, en azından görülür),
- **tipler uyuşursa → DEĞER SESSİZCE KAYAR** (hata yok, rakam yanlış).

Bu oturumda **iki kez** oldu (`SonSatisTarihi` ve talep deseni agregaları) ve **build ikisini
de yakalamadı**. Derleyici SQL metnini bilmez.

**Kural:** yeni kolon SQL'de nereye eklendiyse record'da AYNI yere eklenir. Ekleme yerine
yorum düşülür ("SQL'de X'ten hemen sonra").

**Koşulabilir denetim (elle koşulmaz diye pre-commit hook'a bağlı):**
```bash
python tools/panel_kolon_denetimi.py
```
`AS Alias` sırasını record parametre sırasıyla karşılaştırır; ilk sapmayı konumuyla yazar.
Çıkış 0 geçti · 1 KIRIK · **2 KOŞAMADI** (koşamamak yeşil sayılmaz). Kırılabilirliği
kanıtlandı: iki parametre yer değiştirildi → 44. konumda sapma bildirdi, geri alındı.
⚠ SINIR: alias'sız SELECT kolonlarını atlar (adı ifadeden çıkarmak parse ister) — atlananlar
uyarı olarak yazılır. "0 kırık" tüm eşleşmenin doğruluğunu KANITLAMAZ.

## Dapper Record Materialization: smallint/tinyint → CAST AS int (23.06 dersi)

- **Positional record (`record Foo(int X, ...)`) Dapper'da ctor tipi tam eşleşme ister.** SQL `smallint`→Int16, `tinyint`→Byte; record `int`(Int32) ile EŞLEŞMEZ → `InvalidOperationException: parameterless default constructor or one matching signature (Int16, Byte, ...) required`.
- **Çözüm:** SELECT'te `CAST(col AS int)` (ya da record alanını `short`/`byte` yap). `Fin_AyKapanis.DonemYil`(smallint)/`DonemAy`(tinyint) → `CAST(... AS int)` (KapanisDonem record int). ValueTuple da aynı — CAST güvenli.
- Scalar `QueryAsync<int>` (tek kolon) tinyint'ten sorunsuz (Convert) — sorun yalnız çok-kolonlu record/tuple ctor eşleşmesinde.

## İlişkili Dosyalar

- `docs/01-baglanti.md`, `docs/02-tablolar-magaza.md`, `docs/03-ciro-filtreleri.md`
- `docs/05-eticaret-joker.md`, `docs/08-pos-encore.md`

## SIFIR SENTINEL — `IS NOT NULL` bunları ELEMEZ (11.09.2026, beş köprüde ölçüldü)

DerinSIS/EncoreMerkez/JOKER'de "bağlı kayıt YOK" **NULL ile değil, `0` ile** yazılır. Kolon
`NOT NULL` tanımlıdır; boşluk yerine sıfır konur. Sonuç: `WHERE x IS NOT NULL` süzgeci hiçbir
şey elemez ve sorgu milyonlarca sahte eşleşme adayı taşır — **hata vermez, rakam yanlış olur.**

`sema kopru` canlı taramasında ölçülen sentineller:

| Kolon | Sıfır sayısı | Anlamı |
|---|---|---|
| `EncoreMerkez.Sales.LinkedDocumentId` | 1.292.885 | bağlı belge yok |
| `depo.paletIcHrk.piIrsID` | 1.275.953 | belgesiz (elle) palet taşıması |
| `dbo.fat.eMhsFisID` | 11.965 | fatura henüz muhasebeleşmemiş |
| `BKMDATA.Hedef.ktgId` | 6.780 (+60 adet `255`) | kategori kırılımsız hedef satırı |
| `EncoreMerkez.Sales.CustomersId` | 590.295 | anonim/yürü-gel müşteri |

**Kural:** bir FK-benzeri kolonu süzerken **`> 0`** yaz, `IS NOT NULL` yazma. Sıfırın anlamı
yoksa da sıfır gerçek bir satıra işaret etmez — INNER JOIN onu zaten düşürür ve o düşüş
**sessizdir**; kaç satır düştüğünü bilmiyorsan raporun kapsamını bilmiyorsun demektir.

**Sentinel her zaman 0 da değil:** `hedef-kategori`'de `255`, `orderdetails-items`'ta
**`-1000`** çıktı. Yeni bir köprü kurarken öksüz dağılımına bak (`sema kopru`), tek bir değerde
yığılıyorsa o sentineldir — "veri bozuk" deme.

⚠ Öksüz sayısı tek başına HATA DEĞİLDİR; hata, kaydın "kalıcı, defalarca doğrulandı"
(`confidence: 1.0`) demesiyle ölçümün çelişmesidir. Meşru öksüz `sema/bridges.yaml`
`orphans_expected` alanına yazılır — yazılınca çelişki sayılmaz.
