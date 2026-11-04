# Plan 52 — Bursa Kültür iade zinciri takibi (GM panel + drill)

**Tarih:** 2026-10-23
**Proje:** `bkm`
**Yazan:** Fikri / Claude (oturum `d6a3ddd8`)
**Durum:** `Taslak` — GMY onayı bekliyor
**TODO:** B-192 … B-201 (`TODO.md` § Devam Eden → Bursa Kültür iade zinciri)

---

## 1. Problem

BKM, DerinSIS'ten Bursa Kültür Merkezi'ne (frmID 56) **alış iade faturası** keser
(`fat.eTip = 2`). Beklenen akış: Bursa Kültür bu faturayı kendi programı **KIBO**'ya giriş
olarak işler ve malı **asıl tedarikçisine** iade faturasıyla gönderir. Bugün bu zincirin
üçüncü halkasını (tedarikçiye iade) izleyen hiçbir ekran yok; iade edilen malın gerçekten
tedarikçiye gidip gitmediği, Bursa Kültür'de kalıp kalmadığı ya da bize geri satılıp
satılmadığı bilinmiyor.

Kullanıcı (GMY) sözleri — bu planın sınırlarını belirler:

- *"derinsisten bursa kültür merkezine iade faturası kesiyoruz o da o faturayı giriş yapıp
  asıl firmasına iade faturası kesiyor olması gerekiyor bu zinciri izlememiz lazım"*
- *"ürün ürün karşılaştırma yapabilmemiz lazım"*
- *"bak aynı ürün iade edilmiş mi peki benim numaram ile iade edilemez zaten"*
- *"bizim iademiz ile başlayacak kontrol tetikleme bizden olacak"*
- *"fatura tarihinden sonraki ilk iade olmalı"*
- *"ayrıca bir bağlantı yapmana gerek yok derinsis üstünden linked ile yapabilirsin"*
- *"bunu takip edebileceğim gm dashboard tarafına drill ekranlarla detaylarına kadar bakabileceğim şekilde ekle"*

## 2. Ölçülmüş zemin (23.10.2026 — hepsi ÖLÇÜLDÜ)

Kanıt sorguları: `sorgular/2026-10-23-bursa-kultur-iade-zinciri.sql` (blok 1-8) ve
çekirdek `sorgular/2026-10-23-bursa-kultur-iade-zinciri-toplu.sql`. Sema kayıtları:
`entities: kibo_sunucu_haritasi · kibobkm.dbo.tumbelgeler · kibobkm.dbo.stokinout ·
kibobkm.dbo.cari · kibo_stok_bakiyesi_guvenilmez` · `codes: kibobkm.tumbelgeler.belgekod ·
kibobkm.ambar.kod` · `bridges: fat-eno-kibo-fattakipno · urnbrkd-kibo-stokkod ·
frm-kibo-cari-bkm` · `metrics: bursa_kultur_iade_zinciri`.

### 2.1 Nerede ne var

| Yer | Ne | Not |
|---|---|---|
| `[192.168.40.140].kibobkm` | **Bursa Kültür canlı KIBO** (tfirma `bkmnet`) | DerinSIS 201'den linked server ile, ayrı bağlantı YOK |
| `[192.168.40.140].kibobkm0609/2014/2017` | KIBO arşiv kopyaları | kapsam dışı |
| `[192.168.40.140].GOPLUS*` | Logo | **KULLANILMIYOR** (kullanıcı) |
| `SURA.kibobkm` (192.168.40.164) | **ŞURA** firması KIBO'su | Bursa Kültür DEĞİL; kullanıcı: "ara bağlantı katman tabloları, iptal" |
| 201 `KIBO` veritabanı | yalnız ürün ana verisi | fatura/cari YOK |
| `DerinSISBkm.bkm.HeykelSatisKibo` | günlük kategori satış özeti | fatura değil |

### 2.2 Köprüler

- **Fatura:** `DerinSIS fat.eNo` = `KIBO tumbelgeler.fattakipno` (= `einvoice_id`).
  Bizim iademiz KIBO'da **belgekod 3 (Alış Faturası)** olarak girilir.
  Kapsam: 2024 13/13 · 2025 25/25 · 2026 69/72 (eksik 3'ü 22.10.2026'da kesilenler).
  ⚠ DerinSIS tarafında `eFirma = 56` şart — numara çakışması görüldü (eFirma 63412).
- **Ürün:** `urnBrkd.urnBarkod` (`urnBrkdOnce = 0`) = `stokinout.stok_kod`. 2026'da
  7.734 barkodun 7.679'u birincil, 43'ü yalnız ek barkodla eşleşti, 12'si eşleşmedi.
- **Cari:** KIBO'da BKM = `cari.skod 1417` (VKN 1270120858), eski kart 1412.

### 2.3 KIBO belge tipleri (2025+ dağılımdan)

1 Satış Faturası · **2 Alış İade Faturası** (⚠ fiyat farkı faturaları da bu kodla) ·
**3 Alış Faturası** (⚠ BKM'den gelen her belge: satış, mağaza satış, alış iade, hizmet,
gider, fiyat farkı, iade fark) · 4 Satış İade · 27 perakende fiş (106 aynası, sayılmaz) ·
99 perakende iade (107 aynası) · 9/10/19/20/150/152 banka-kasa · 21-24 çek/senet ·
46/47 virman · stok fişleri 17/18/104/105/6 (17/18 alt anlamı teyit bekliyor).

### 2.4 Tuzaklar (panelde karşılığı olmalı)

1. `stokinout.lngcarikod` çoğunlukla 0 → **cari başlıktan** (`tumbelgeler`) alınır.
2. `ambar_kod` 2025+ hep 0 → mağaza kırılımı KIBO'dan **yapılamaz**.
3. **KIBO stok bakiyesi güvenilmez:** 547.785 ürünün 119.112'si eksi (−9,93M adet).
   "Bursa Kültür'de kalan" stok KIBO'dan okunmaz; ekranda yalnız "KIBO kaydına göre"
   diye ve uyarıyla gösterilir.
4. Perakende (27) `net_tutar`'da barkodun fiyat alanına okutulduğu uç satırlar
   (9,79 trilyon TL gibi) → tutar toplanırken > 1.000.000 satır elenir.
5. belgekod 2 içinde fiyat farkı faturası var → tedarikçi iadesi = **stok çıkışı olan**
   satır (`out_miktar > 0`).
6. `relbelgeno` fatura↔iade bağı taşımıyor → eşleşme **ürün + tarih** (kullanıcı:
   "benim numaram ile iade edilemez zaten").
7. Cross-server tek sorgu (OUTER APPLY) 120 sn'yi aştı → uzak tarafa **literal liste**
   (dinamik SQL) gönderilir; 110 fatura ~10 sn.

### 2.5 İzlenen örnekler (kabul testi için altın vakalar)

| Bizim iade | Ne çıktı |
|---|---|
| IEF2026000002413 (17.10.2026, 12 LGS Türkçe) | KIBO 55069868 birebir · tedarikçiye iade yok · perakende satılıyor · KIBO stoğu −2.049 |
| IEF2026000000176 (17.01.2026, 315 Tuval Boyama Seti) | KIBO 55065962 birebir · **10.02.2026 BEF2026000000127 ile aynı 315 adet BKM'ye geri satıldı** · üründe KIBO'da hiç tedarikçi alışı yok (stok −12.667) |
| IFF2026000000010 (08.01.2026, eTip 10 İade Fark) | KIBO'da **120 adet stok girişli alış** olarak işlenmiş |
| IEF2025000000680 (17.06.2025, 36 ürün / 15.000 adet) | 36/36 birebir · tedarikçi KARGI BASIM'a iade 0 · 1 adet geri satış · 6.204 perakende |
| IEF2025000000526 + 0535 (12.05.2025, aynı gün) | 13.05.2025 **tek OMTEKS iadesi ikisini birlikte** karşılıyor (Omt-174: 30 + 630 = 660) |
| IEF2026000001888 / 1960 / 2246 | 17.10.2026 POİNT iadesi; adetler bizimkiyle uyuşmuyor (1↔2, 4↔2, 4↔3) |

### 2.6 Toplu sonuç (01.01.2024 → 23.10.2026, 110 fatura / 479 satır, paylaştırmasız)

| Durum | Satır | Adet | Tutar (KDV hariç) |
|---|--:|--:|--:|
| Bursa Kültür'de (iade yok) | 395 | 200.356 | 2,84M ₺ |
| BKM'ye geri satıldı | 52 | 54.267 | 0,59M ₺ |
| Giriş adedi farklı | 8 | 671 | 0,14M ₺ |
| Tedarikçiye iade edildi | 13 | 5.207 | 0,12M ₺ |
| KIBO'ya girilmemiş | 9 | 26 | 0,01M ₺ |
| Kısmen iade edildi | 2 | 8 | 0,00M ₺ |

## 3. Kurallar (kullanıcı kararları — uygulamada değişmez)

| # | Kural | Kaynak |
|---|---|---|
| K1 | Kontrol **bizim iade faturamızla** başlar (`fat.eTip=2`, `eFirma=56`, `eDurum<>2`) | kullanıcı |
| K2 | KIBO girişi = `fattakipno = fat.eNo`, belgekod 3, aynı barkod | ölçüm |
| K3 | Tedarikçi iadesi = fatura tarihinden **sonraki ilk** belgekod 2 belgesi, cari ∉ (1417, 1412), `out_miktar > 0`; adet o belgedeki | kullanıcı |
| K4 | Aynı ilk iade birden çok faturamıza düşerse adet **tarih sırasıyla paylaştırılır**, iki kez sayılmaz | kullanıcı (seçim 23.10) |
| K5 | Yan göstergeler iadeden sonra: BKM'ye geri satış (belgekod 1, cari 1417/1412) · başkasına satış · perakende (27) | ölçüm |
| K6 | KIBO stok bakiyesi "fiili stok" diye gösterilmez | ölçüm |
| K7 | Bağlantı DerinSIS (201) üzerinden linked server; yeni bağlantı dizesi YOK | kullanıcı |
| K8 | Yazma yok — ERP'ye de KIBO'ya da (yalnız sorgu içi `#temp`) | erp-write-policy |
| K9 | Menü yeri: **FİNANS** bölümü, Muhasebe sayfalarının yanı | kullanıcı (seçim 23.10) |

## 4. Scope

### Kapsam dahili

1. **Çekirdek sorgu** (`emitter-ayrimi.md`): toplu sorgunun panel sürümü — K4 paylaştırması
   eklenir; arşiv `sorgular/2026-10-23-bursa-kultur-iade-zinciri-toplu.sql` ile mantık AYNI
   kalır (arşiv de K4'le güncellenir).
2. **Liste ekranı `/bursa-iade`:**
   - Filtre: tarih aralığı (varsayılan yılbaşı → bugün), mekan (FSM / Özlüce / İst.Yolu / Merkez depo), durum.
   - KPI kartları: bizim iade (fatura / adet / tutar) · tedarikçiye giden · BKM'ye geri satılan ·
     Bursa Kültür'de kalan · KIBO'ya girilmemiş / adet farklı (uyarı).
   - Fatura tablosu: fatura no, tarih, mekan, satır, adet, tutar, durum dağılımı (mini çubuk),
     en eski bekleyen gün. Satıra tık → fatura drill.
   - Excel (mevcut `ExcelButton` + `/api/...-excel` deseni): satır düzeyi tam döküm.
3. **Fatura drill `/bursa-iade/fatura?no=IEF…`:** başlık (DerinSIS + KIBO belge no, tarih,
   tutar karşılaştırması) + ürün ürün tablo: barkod, ürün, bizim adet, KIBO girişi, fark,
   ilk tedarikçi iadesi (KIBO belge no, tarih, firma, adet, paylaştırılan adet, gün),
   BKM'ye geri satış, perakende, durum. Ürüne tık → ürün drill.
4. **Ürün drill `/bursa-iade/urun?barkod=…`:** ürünün KIBO hareket zaman çizelgesi (alış,
   alış iade, satış, perakende — belge belge, cari adıyla) + aynı ürünün DerinSIS tarafı
   (Bursa Kültür'den alış, ona iade) yan yana; KIBO stok bakiyesi uyarılı.
5. Menü satırı (`NavRegistry` FİNANS), DI (`ServiceRegistration.AddBkmVeri`).
6. Sema `metrics.bursa_kultur_iade_zinciri` → `applied_in` panel dosyasına bağlanır.

### Kapsam dışı

- KIBO'ya ya da ERP'ye her türlü yazma (K8).
- Bursa Kültür'ün tedarikçi alışlarının nerede kayıtlı olduğunun çözümü (açık soru S1).
- Heykel/Şura mağaza satış raporu (K-03) — KIBO perakende (27) bunu mümkün kılıyor ama ayrı iş.
- SQL Agent job / ön-agrega tablo (gerekirse ayrı onay; §5 alternatif B).
- Şura (SURA.kibobkm) zinciri.

### Etkilenen dosyalar (tahmin)

- `dashboard/Data/BursaIadeQueries.cs` — yeni, çekirdek sorgu + DTO eşleme (≤300 satır; aşarsa `partial` ile `.Urun.cs`).
- `dashboard/Models/BursaIadeModels.cs` — yeni, record'lar (8+ kolon → record, ValueTuple değil).
- `dashboard/Components/Pages/BursaIade.razor` — yeni liste.
- `dashboard/Components/Pages/BursaIadeFatura.razor` — yeni fatura drill.
- `dashboard/Components/Pages/BursaIadeUrun.razor` — yeni ürün drill.
- `dashboard/Models/NavRegistry.cs` — FİNANS'a 1 satır.
- `dashboard/ServiceRegistration.cs` — `AddBkmVeri`'ye 1 satır.
- `dashboard/Program.cs` — Excel endpoint (mevcut `/api/*-excel` deseni).
- `sorgular/2026-10-23-bursa-kultur-iade-zinciri-toplu.sql` — K4 paylaştırması.
- `sema/metrics.yaml` — `applied_in`.
- Test: mevcut test projesine `BursaIadeQueries` davranış testleri.

**Tahmini boyut:** ~10 dosya / ~1.000 satır.

## 5. Alternatifler

### A: Ön-agrega `bkm.*` tablosu + SQL Agent job
**Açıklama:** zinciri gece job'la `bkm.BursaIadeZincir`'e yaz, panel salt okusun.
**Reddetme sebebi:** yeni app-owned ERP tablosu + job ayrı onay ister (erp-write-policy);
ölçülen süre (~10 sn / 110 fatura) buna gerek göstermiyor. Performans sorun olursa yeniden açılır.

### B: KIBO'ya doğrudan ikinci bağlantı (`Db.OpenKibo`)
**Açıklama:** dashboard 140'a ayrı connection string ile bağlansın.
**Reddetme sebebi:** kullanıcı açıkça istemedi (K7: "linked ile yapabilirsin"); yeni sır,
yeni `.env` değişkeni, yeni yetki yüzeyi.

### C: Mevcut bir sayfaya bölüm eklemek (footprint-ladder 1. basamak)
**Açıklama:** Muhasebe/Kontrol sayfasına "Bursa Kültür iadeleri" kartı.
**Reddetme sebebi:** kullanıcı drill ekranlarla ürün düzeyine kadar iniş istedi; tek kart
bunu taşımaz. Yine de **Muhasebe sayfasına özet kart + bağlantı** eklenebilir (opsiyonel adım).

### D (seçilen): Linked server üzerinden canlı sorgu + 3 ekran
**Sebep:** K7'ye uyar, yazma yok, ölçülmüş süre kabul edilebilir, mevcut drill deseni
(`Fatura.razor`, `SatinalmaUrunDetay.razor`) kopyalanır.

## 6. Riskler

| Risk | Etki | Olasılık | Önlem |
|---|---|---|---|
| Dashboard kullanıcısının (`.env MSSQL_USER`) linked server login eşlemesi farklı → uzak sorgu reddedilir | yüksek | orta | Adım B-193'te dashboard kimliğiyle `SELECT TOP 1 … FROM [192.168.40.140].kibobkm.dbo.tfirma` ölçülür; reddedilirse DBA'ya eşleme talebi |
| Dapper parametreli batch `sp_executesql` içinde koşar → `#temp` + iç dinamik `EXEC` kapsamı | orta | orta | `#temp` aynı batch içinde yaratılıp kullanılır (erp-write-policy'deki çağrılar arası kayıp burada yok); B-194'te ölçülür |
| `Db.OpenAsync` varsayılan katalog `master` → 2 parçalı ad Err 208 | orta | yüksek | tüm DerinSIS nesneleri 3 parçalı (`DerinSISBkm.dbo.fat`) |
| Geniş tarih aralığında uzak IN listesi çok uzar (binlerce barkod) | orta | düşük | barkod listesi 500'lük dilimlerle; ölçüm: 479 satır ~10 sn |
| K4 paylaştırması yanlış dağıtır → "iade edildi" şişer/eksilir | yüksek | orta | davranış testi: bir iade belgesinin paylaştırılan toplamı ≤ belge adedi; OMTEKS vakası (526+535) altın test |
| KIBO stok bakiyesi "kalan stok" sanılır | yüksek | orta | ekranda uyarı + kolon adı "KIBO kaydına göre"; K6 |
| belgekod 2 fark faturaları iade sayılır | orta | orta | `out_miktar > 0` süzgeci; test |
| KIBO veritabanı (140) kapalı/yavaş → sayfa boş ya da yavaş | orta | düşük | timeout 120 sn, "KIBO'ya ulaşılamadı" mesajı (sessiz boş YASAK — olctum-mu-cikardim-mi) |
| Uncommitted dosya sayısı 35 (> 15 eşiği) | orta | kesin | B-192: önce commit-split (kullanıcı onayladı, uygulama yarıda kaldı) |

## 7. Done Criteria

- [ ] Liste, fatura drill, ürün drill çalışıyor; menüde FİNANS altında görünüyor.
- [ ] Altın vakalar (§2.5) ekranda ölçülmüş değerlerle birebir:
      IEF2026000002413 → iade yok; IEF2026000000176 → BKM'ye geri satıldı 315;
      IEF2025000000680 → 36/36 birebir, iade 0; 526+535 → OMTEKS iadesi paylaştırılmış
      (Omt-174'te 30 + 630 = 660, iki kez sayılmamış).
- [ ] Toplu durum dağılımı arşiv sorgusuyla aynı (paylaştırmalı sürüm; fark varsa açıklanmış).
- [ ] Davranış testleri yeşil: paylaştırılan ≤ iade adedi · durum kümesi kapalı · fark faturası (out_miktar=0) iade sayılmıyor · KIBO'ya ulaşılamazsa hata görünür (boş liste değil).
- [ ] `python tools/panel_kolon_denetimi.py` 0 KIRIK (record sırası = SELECT sırası).
- [ ] Build yeşil + test yeşil + tarayıcıda smoke (ekran görüntüsü).
- [ ] Excel çıktısı ekran tablosuyla aynı kolon eşlemesinden (emitter-ayrimi § biçim de tek yerde).
- [ ] Sema `metrics.bursa_kultur_iade_zinciri.applied_in` güncel; `sema denetle` KIRIK 0.

## 8. Rollback

- Yalnız yeni dosyalar + `NavRegistry`/`ServiceRegistration`/`Program.cs`'e birer satır →
  `git revert <commit>` yeterli. DB değişikliği yok, job yok.

## 9. Adımlar

0. [ ] **B-192** Commit-split: 35 commit edilmemiş dosyayı konulara böl (kullanıcı 23.10'da onayladı; commit-splitter çağrısı kesildi, yeniden başlatılacak). Kalan < 15 olmadan B-193'e geçilmez.
1. [ ] **B-193** Ön ölçüm: dashboard kimliğiyle linked server erişimi (`tfirma` okuma) + süre; sonuç plana yazılır.
2. [ ] **B-194** Çekirdek: K4 paylaştırmalı sorgu (arşiv dosyası güncellenir) + `BursaIadeQueries` (3 metot: liste özeti, fatura satırları, ürün zaman çizelgesi) + record'lar.
3. [ ] **B-195** Testler önce: altın vakalar + davranış kontratları (kırmızı → yeşil).
4. [ ] **B-196** Liste ekranı `/bursa-iade` (KPI + filtre + tablo + Excel).
5. [ ] **B-197** Fatura drill `/bursa-iade/fatura`.
6. [ ] **B-198** Ürün drill `/bursa-iade/urun` (KIBO + DerinSIS yan yana, stok uyarısı).
7. [ ] **B-199** Menü + DI + Excel endpoint; `panel_kolon_denetimi` + build + test + tarayıcı smoke.
8. [ ] **B-200** Sema `applied_in` + journal + TODO kapanışı; plan arşive.
9. [ ] **B-201** (opsiyonel) Muhasebe/Kontrol sayfasına özet kart + bağlantı.

## 10. Açık sorular (ölçülmedi — "teyit bekliyor")

- **S1** Bursa Kültür tedarikçi alışlarını nereye giriyor? KIBO'da çok ürünün alışı yok
  (Tuval Boyama Seti: hiç; 119.112 ürün eksi stok). GOPLUS kullanılmıyor. Cevap gelene kadar
  "Bursa Kültür'de kalan" kolonu yalnız KIBO kaydına göredir.
- **S2** IEF2026000000176 → BEF2026000000127: iade edilen 315 adetin 24 gün sonra Heykel
  Transfer (mekan 60398) üzerinden aynen geri alınması bilinçli bir işlem mi?
- **S3** İade fark faturası (eTip 10, IFF…) KIBO'da stok girişli alış olarak işleniyor —
  Bursa Kültür muhasebesine iletilecek mi?
- **S4** KIBO stok fişi kodları 17 (belgetip 1/2) ve 18 (belgetip 7/10) ne anlama geliyor?
- **S5** 2026'da eşleşmeyen 12 barkod ve "giriş adedi farklı" 8 satır tek tek incelenecek.
- **S6** 22.10.2026'da kesilen 3 iade (IEF…2535/2537/2542) KIBO'ya girildi mi? (ertesi gün yeniden ölç)

## 11. İlişkili

- Kanıt: `sorgular/2026-10-23-bursa-kultur-iade-zinciri.sql` · çekirdek `…-toplu.sql`
- Sema: §2 başındaki kayıtlar
- Desen: `dashboard/Components/Pages/Fatura.razor`, `SatinalmaUrunDetay.razor`
- Kurallar: `erp-write-policy.md`, `emitter-ayrimi.md`, `sql-server-conventions.md` (3 parçalı ad, Dapper record sırası), `olctum-mu-cikardim-mi.md`
- İlgili backlog: K-03 (Heykel/Şura POS kör noktası — KIBO 27 ile çözülebilir)
