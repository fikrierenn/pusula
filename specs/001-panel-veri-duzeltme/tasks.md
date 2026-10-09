# Görevler 001: Panel veri düzeltmeleri

> **Uygulayıcılar için:** Bu liste `/uygula 001` ile görev görev yürütülür. Her görev: test hattı → kod → kapılar → inceleme. Yalnız kendi görev metninizi okuyarak çalışabilmelisiniz; komşu görevlerin adları "Arayüzler" satırındadır.

**Spec:** `specs/001-panel-veri-duzeltme/spec.md` · **Plan:** `specs/001-panel-veri-duzeltme/plan.md` (Onay kaydı 03.10.2026, 12 karar) · **Kontratlar:** `specs/001-panel-veri-duzeltme/kontratlar/` · **Tarih:** 03.10.2026

## Global kısıtlar

Her görevin gereksinimine örtük olarak dahildir.

**Veritabanları (hepsi salt-okuma, FR-015, `erp-write-policy.md`):**
- EncoreMerkez compat **110**: `STRING_AGG`, `TRIM`, `IIF`, `TRY_CONVERT` YOK → `STUFF + FOR XML PATH`, `LTRIM(RTRIM())`, `CASE WHEN`, `CONVERT + ISDATE`.
- DerinSISBkm 150 · BKM 150 · BKMDATA 150 · DerinCrm 150 · JOKER 150 (doğrudan `Db.OpenJokerAsync()`) · ODAKJOKER bağlantılı sunucu 150 (OPENQUERY metninde tarih ISO `yyyyMMdd`).
- **ERP'ye, POS'a, e-ticarete yazma yok.** Bu spec app-owned `bkm.*` tablolarına da yazmaz. Yeni tablo, kolon, view, SP, job yok.
- Panel sorgularında ERP nesneleri **3 parçalı** ad: `DerinSISBkm.dbo.irsHrk`, `EncoreMerkez.dbo.Sales` (bağlantı varsayılan kataloğu `master`).
- Çapraz veritabanı string join: `COLLATE Turkish_CI_AS` (iki tarafa da).
- `EncoreMerkez.dbo.SalesProducts` her okumada `IsValid = 1` (istisna: 1001 geri dönüşüm tespiti — plan K-B gereği `IsValid`'e bakmaz).
- `Sales.LineCount` kullanılmaz. İndirim toplamı başlıkta `Sales.DiscountTotal`, kalemde `DiscountTotalDirect`; `DiscountTotalCampaign` toplanmaz.
- Belge tipleri (`Sales.DocumentsTypeId`): 1 fiş · 2 fatura · 3 iade (negatif) · 6 personel fiş · 7 personel fatura · 8 Sınav Okulları. Mağaza neti kapsamı `IN (1,2,3,6,7,8)`.
- Net ciro (Encore başlık) = `GrossTotal − DiscountTotal − VatTotal` (KDV hariç). `TotalAmount` ciro değildir.
- Mağazalar: FSM `mekanID 1` · Özlüce `4477` · İst.Yolu `4478`. Merkez depo `12`. Encore → mekân köprüsü: `Sales.PosId → Pos.StoreId → Stores.Code = posMagaza.mekanKod` (COLLATE).
- Kanonik şube cirosu (ERP): `irsHrk.ehTip` 100 − 101 + 4 − 5, `ehMekan IN (1,4477,4478)`, `ehAltDepo = 0`, `ehTutarN`.
- Merkez depo bugün: `DerinSISBkm.depo.stok_adres_palet_vw`, `adrsAlanTipID IN (0,1)`. Geçmiş ay: `DerinSISBkm.bkm.StokAyBakiyeMekanBazli`, `Kaynak = 'WMS' AND ehMekan = 12 AND Donem = @Donem`; `MAX(Donem)` yedeği YOK. ERP defteri (`stokSonAltDepo_vw`) mekân 12 için kullanılmaz.
- Ürün köprüsü `Products.Code = urn.stkID`; `stkKod` barkod değildir. Sıfır sentinel: FK benzeri kolonda `> 0` yazılır, `IS NOT NULL` değil (`LinkedDocumentId > 0`, `CustomersId > 0`).
- `NOT (… AND <NULL olabilen karşılaştırma>)` yazılmaz; NULL tarafı `ISNULL` ile sabitlenir.
- Aggregate içindeki `CASE` alt sorgu içermez (1001 dışlaması kolon biçiminde: `LEFT JOIN (SELECT DISTINCT …) gd` + `gd.SalesId IS NULL`).
- T-SQL ayrılmış kelime alias olmaz (`RowCount`, `Min`, `Max`, `Count` …).
- Kalıcı borç (K8): dokunulan sorgularda `WITH(NOLOCK)` ve tek harfli tablo takma adları **kaldırılmaz, eklenmez de değiştirilmez**.

**Tarih:**
- SQL'de tarih **literali yok**; parametre (`DateTime`) geçilir. C# tarafında `DateOnly`.
- Arşiv `.sql` dosyalarındaki SSMS yorumu DMY: `DECLARE @Bas date = CONVERT(date, '01.09.2026', 104), @Bit date = CONVERT(date, '01.10.2026', 104);`. `yyyy-MM-dd` hiçbir yerde yazılmaz. JOKER parametreleri `yyyyMMdd` string (`DateOnly.ToString("yyyyMMdd")`).
- Ekranda tarih `dd.MM.yyyy` (gg.aa.yyyy), not biçimi `dd.MM` (gg.aa).
- Doğrulama dönemi: `@Bas = 01.09.2026`, `@Bit = 01.10.2026` (bitiş hariç). İstisnalar: H12 Haziran 2026 (`sirketId 6`, `ay 6`, `ayBas 1`); H7 Eylül 2026, test adında ve kanıt başlığında "muhasebe açık dönem" (İnsan onayı 12).

**C# (yeni ve dokunulan kod, K1):**
- `DateTime.Now`/`Today` yeni kodda yasak → `TimeProvider` (`AddSingleton(TimeProvider.System)`, T-029).
- Dokunulan public sorgu metotları son parametre olarak `CancellationToken ct = default` alır ve `new CommandDefinition(sql, param, cancellationToken: ct)` ile iletir.
- Dapper konumsal kayıtlarında **sıra sözleşmedir**: yeni alan SQL `SELECT`'te ve kayıtta aynı konuma, **sona** eklenir. Her NET görevinde `python tools/panel_kolon_denetimi.py` çıkış 0.
- `smallint`/`tinyint` kolonu kayda `CAST(… AS int)` ile gelir. 8+ alanlı ValueTuple yok, kayıt kullanılır.
- Para `decimal`. SQL parçası yalnız sabit metin veya tamsayı sabiti; kullanıcı girdisi parça içine girmez.
- Yeni tanımlayıcı: İngilizce teknik kalıp + Türkçe alan terimi, Türkçe karakter yok. Kapı: `python tools/turkce_tanimlayici_denetimi.py` (yeni dosyada 0 bulgu).
- Boş `catch` yok; `ex.Message` ekrana yazılmaz.
- Paket sürümü `.csproj`'da kalır (K6: merkezi paket yönetimi alınmadı). Yeni paket yok; test paketleri `tests/BkmVardiya.Tests` ile aynı sürüm: `Microsoft.NET.Test.Sdk 17.12.0`, `xunit 2.9.2`, `xunit.runner.visualstudio 2.8.2`, `Microsoft.AspNetCore.Mvc.Testing 10.0.0`.

**UI:** DaisyUI semantik token (`text-warning`, `badge badge-ghost badge-sm` …), ham hex yok. Lucide `<i data-lucide>` koşullu render edilmez. Metinler `KullaniciMesajlari`, `StokGostergeTanimlari`, `DuzeltmeNotlari`, `HedefTabani` sabitlerinden gelir; Razor'da elle tekrar yazılmaz. Cümle en fazla 15 kelime, dipnot en fazla 2 cümle (`sunum-dili.md`). Yerleşim değişmez (mobil 002'de); yalnız değer, etiket, not, mesaj.

**Test (plan K-A):**
- Proje `tests/GmDashboard.Tests` (T-021). Trait'ler: `[Trait("Tur","Kanonik")]` · `[Trait("Tur","Koruma")]` · `[Trait("Tur","HataEkrani")]` · birim testinde `Tur` yok. Her testte `[Trait("AC","AC-x.y")]`, kanonik testlerde ayrıca `[Trait("Hikaye","H01")]` …
- Ad biçimi `Metot_Senaryo_Beklenen`. Testte `if`/döngü yok (teori + `MemberData`). `Skip` yok.
- Kanonik ve koruma testleri canlı ERP'ye yalnız `CanliDb` (T-021) üzerinden SQL koşar; panel metodu `CanliDb.PanelDb()` ile kurulan `Db` ile çağrılır. Bağlantı yok ya da nüfus 0 → `KOŞAMADI: …` ile **kırmızı**.
- Tolerans: sayı birebir; tutar `Tolerans.Tutar = 1.00m`; AC-13.3 `Tolerans.Oran = 0.003m`.
- Assert mesajına müşteri adı/telefonu yazılmaz; yalnız sayı ve en fazla ilk 3 kimlik.
- **Koşu saatleri (R4):** `Tur=Kanonik`/`Tur=Koruma` yalnız 19:00–08:00 arası veya hafta sonu; filtresiz tam koşu 22:00 sonrası. Hiçbir commit kapısına bağlanmaz. Mesai içinde yalnız birim ve `Tur=HataEkrani`.
- Komutlar (depo kökü `C:\dev\pusula`):
  - Birim: `dotnet test tests/GmDashboard.Tests --filter "Tur!=Kanonik&Tur!=Koruma"`
  - Tek hikâye: `dotnet test tests/GmDashboard.Tests --filter "Tur=Kanonik&Hikaye=H05"`
  - Derleme: `dotnet build dashboard/GmDashboard.csproj` (0 hata, uyarı sayısı görev öncesinden fazla değil) · `dotnet build tests/GmDashboard.Tests/GmDashboard.Tests.csproj -warnaserror`
- SQL denetçi: `python ../orkestra/dist/orkestra/hooks/sql_denetle.py <dosya>` (E seviyesi bulgu 0).
- Canlı ölçüm (SQL görevleri): `sqlcli query --profile erp --read-only --max-rows 100000 "<SELECT>"` (`--profile encore` / JOKER için `bash tools/sq.sh --joker`), **depo kökünden** çağrılır; dönen satır sayısı beklenenle karşılaştırılır.
- Kırmızı kip geri alma: `git reset --hard` / `git checkout -- .` YASAK; `git reset --soft HEAD~1` ya da dosyayı elle geri yazma.

**Kanonik sorgu arşivi (plan K-D):** klasör `sorgular/2026-10-panel-veri-duzeltme/`. Başlık şablonu `kontratlar/kanonik-sorgular.md`'deki gibidir (`-- ork:hedef-db`, `-- ork:compat`, Soru, AC, Dönem, Tolerans, Önce, Sonra, Bağımsız, SSMS, ayrıca `Dondurma: <hash>`). Blok işareti satır başında `-- blok: A`. Kanonik sorgu `dashboard/Data/Tanimlar/*` kullanmaz, panel SQL'inden kopyalanmaz. Aynı kaynaktan kuruluyorsa başlıkta `Aynı kaynak — neden:` ve `Başka ne olabilir:` satırları zorunlu.

**Commit:** görev başına kendi dosyaları, `git add <dosyalar>` (asla `-A`). Mesaj `<tip>(T-0NN): <özet>`, gövdede `Spec: 001 · <Hxx> · bkm` ve `Co-Authored-By: Claude <noreply@anthropic.com>`. `git status` 15 dosyayı aşmadan bölünür.

**Yayın birliği (R6):** Aynı yayın grubundaki görevler tamamlanmadan F6 yayın commit'i (T-081) atılmaz.
- **Y-FIS:** T-041, T-042, T-043, T-044, T-046, T-047 (UPT/ısı haritası) — fiş tanımının bütün tüketicileri.
- **Y-DEPO:** T-035, T-051, T-052 — merkez depo canlı WMS tüketicileri.

## İnceleme odağı

1. **Hata testi ortamının sızması (R5):** `BKM_ENV_DOSYA` tanımlıyken bir kanonik test koşarsa ya da geçici `.env` dosyası yoksa — beklenen: `CanliDb` `KOŞAMADI` ile kırmızı döner; hata fabrikası dosya yoksa kırmızı döner, gerçek `.env`'e sessizce düşmez. Testler: T-022 `CanliDb_BkmEnvDosyaTanimli_KosamadiVerir`, `HataEkraniOrtami_GeciciDosyaYok_KirmiziDoner`.
2. **Salt-okuma kapısını atlatma (R1):** `WITH x AS (SELECT 1 AS a) UPDATE …`, `SELECT a INTO #t FROM …`, `SELECT 1; EXEC sp_x`, `/* SELECT */ DELETE FROM t`, `SELECT 1 -- \n DROP TABLE t` — beklenen: hepsi reddedilir; `SELECT 'DELETE' AS a` ve `SELECT 1 /* UPDATE */` geçer. Test: T-021 `SaltOkumaKapisi_Denetle_YazmaBicimleriniReddeder` (teori), `SaltOkumaKapisi_Denetle_DizeVeYorumdakiKelimeyiGecirir`.
3. **Win-back 90 gün sınırı:** son satış fişi tam `bugun − 90` olan müşteri — beklenen: `[bugun−90, bugun)` penceresindedir, listeye **girmez**; listede en küçük `GunIdle` 91'dir. Test: T-033 `GetWinBackAsync_SonSatisTam90GunOnce_ListedeYok`.
4. **Ürün kodu dönüşüm kenarları (AC-10.3):** `'12a'`, `''`, `' 123'`, `'-5'`, `'2147483648'` (int taşması), `'0123456789'` (10 hane) — beklenen: `NULL`, hata yok; `'123'` → 123, `'999999999'` → 999999999. Test: T-058 `UrunKoduStkId_SayisalOlmayanVeTasan_NullDoner` (teori).
5. **Açık yönlendirme (H11):** `geri` = `"/\\evil.example"`, `"\\\\evil.example"`, `"//evil.example"`, `"http://evil.example"`, `"https://evil.example"` — beklenen: `"/satis-analizi"`; `"%2F%2Fevil.example"` → `"/satis-analizi?%2F%2Fevil.example"` (yerel adreste sorgu dizesi). Test: T-060 `GeriAdresi_Coz_DisAdresiReddeder` (teori), `GeriAdresi_Coz_KodlanmisCiftEgikCizgiYerelKalir`.

## AC kapsama

| AC | Görev(ler) |
|---|---|
| AC-0.1 | T-029, T-030, T-081 |
| AC-0.2 | T-029, T-080 |
| AC-1.1, AC-1.2, AC-1.3 | T-005, T-032 |
| AC-1.4 | T-032 |
| AC-2.1, AC-2.2, AC-2.3, AC-2.4 | T-006, T-033, T-034 |
| AC-3.1, AC-3.2, AC-3.4 | T-007, T-035, T-036 |
| AC-3.3 | T-007, T-051 |
| AC-4.1, AC-4.2 | T-008, T-037, T-039 |
| AC-4.3 | T-008, T-038, T-039 |
| AC-5.1, AC-5.2 | T-009, T-041, T-046 |
| AC-5.3 | T-009, T-042, T-046 |
| AC-5.4 | T-009, T-041, T-043, T-046 |
| AC-6.1, AC-6.2, AC-6.3, AC-6.4 | T-010, T-047, T-048 |
| AC-7.1, AC-7.2, AC-7.3 | T-011, T-049, T-050 |
| AC-8.1 | T-012, T-027, T-051, T-052, T-054 |
| AC-8.2 | T-012, T-052 |
| AC-8.3, AC-8.4 | T-012, T-053 (KB-1 — bkz. rapor) |
| AC-9.1, AC-9.2 | T-013, T-055, T-056 |
| AC-10.1, AC-10.2 | T-031, T-057, T-059 |
| AC-10.3 | T-014, T-058 |
| AC-11.1, AC-11.2 | T-060, T-061 |
| AC-12.1, AC-12.2, AC-12.3 | T-015, T-062, T-063 |
| AC-13.1, AC-13.2, AC-13.3 | T-016, T-040, T-045 |
| AC-13.4, AC-13.5 | T-004, T-040, T-045 |
| AC-14.1, AC-14.2 | T-064, T-065 |
| D-1 | T-066, T-067 |
| D-2 | T-017, T-068, T-069 |
| D-3 | T-070 |
| D-4 | T-017, T-071, T-072 |
| D-5 | T-073 |
| SC-001 | T-080 |
| SC-002 / FR-012 | T-005…T-017, T-080 |
| SC-003 | T-033 |
| SC-004 | T-041, T-046 |
| SC-005 | T-059 |
| SC-006 | T-020, T-024 |
| SC-007 | T-075, T-080 |
| FR-014 | T-074, T-075 |
| FR-015 | T-021 |
| FR-016 | T-040, T-045 |
| Madde 11 (doküman) | T-076, T-077, T-078 |

---

# F0 — Taban ölçümü ve dondurma

### T-001 [SQL] Taban ölçümü ve açık F0 ölçümleri
**Bağımlılık:** yok · **Test seviyesi:** yok (gerekçe: salt-okuma ölçüm; davranış değiştirmez. Kanıt = komut + satır sayısı + değer) · **AC:** SC-002 (kanıt), girdi: KR-1, KR-2, KR-4, H6, H8, H9, H13
**Dosyalar:**
- Oluştur: `sorgular/2026-10-panel-veri-duzeltme/00-taban-olcumu.sql`
**Arayüzler:**
- Tüketir: —
- Üretir: `00-taban-olcumu.sql` blokları `A`…`J` ve başlıkta her bloğun sonucu (sonraki görevler bu sonuçları okur): (a) 1001 etkisi, (b) KR-4 eşdeğerlik, (c) e-tic satır iptal tutarı, (d) `(SalesId, Sequence)` tekilliği, (f) Sınav iadesi kanal farkı, (g) satış analizi kesim farkı, (h9) Sınav kalemsiz sipariş neti, (j) JOKER erişimi, (m) merkez depo geçmiş ay okuma envanteri
**Gereksinimler (tam değerlerle):**
- Blok A (`arastirma.md` §1'in arşivi + üç mağaza): belge tipi × 1001 dışlaması, mekân 1, 4477, 4478, Eylül 2026. FSM için beklenen ölçüm referansı: tip 1 = 42.774, tip 3 = 1.518 / 1001 hariç 947. Sapma varsa başlıkta yazılır, düzeltilmez.
- Blok B: tüm zaman 1001 satırının belge tipine dağılımı (`arastirma.md` §1 ikinci sorgu).
- Blok C (KR-4, F0 b): Eylül 2026 üç mağazada `HediyeCekiQueries`'in geri dönüşüm tanımı (`RefundReasonId = 12` VEYA kalem `Code = '583160'`) ile 1001 barkod tanımının belge kümeleri: yalnız A'da, yalnız B'de, ikisinde. Sonuç cümlesi: "eşdeğer" (iki fark kümesi 0) ya da "eşdeğer değil (n/m belge)".
- Blok D (KR-2, F0 c): JOKER doğrudan; Eylül 2026 (`ORDERDATE >= '20260901' AND < '20261001'`) başlığı `STATUS NOT IN (1001,1006,1007,3000,4000)` olan siparişlerde `J_ORDER_DETAILS.STATUS IN (2004,2005,2010)` satırların `SUM(QUANTITY * SELLINGPRICEWITHOUTVAT)` tutarı, adedi ve ana net cironun yüzdesi. Yüzde > %0,5 ise başlığa "KR-2 ayrı karar gerekir" yazılır.
- Blok E (F0 d): `EncoreMerkez.dbo.SalesProducts`'ta son 90 günde `(SalesId, [Sequence])` çiftlerinden birden fazla satırı olan çift sayısı (beklenen 0).
- Blok F (F0 f): Eylül 2026 İst.Yolu'nda `DocumentsTypeId = 3` belgelerin `LinkedDocumentId > 0` olup bağlı belgesi `DocumentsTypeId = 8` olanların KDV hariç neti ve sayısı; `LinkedDocumentId = 0` iade sayısı.
- Blok G (F0 g): `DerinSISBkm.bkm.SatisAnaliziTaban` son kesiminin `Kesim` değeri ve o kesimdeki merkez depo kolonu toplamı ↔ şimdiki canlı WMS toplamı (aynı `stkID` kümesi); fark adet ve yüzde.
- Blok H (H9): `BKM.snv` Sınav siparişlerinde `K.Kalem > 0` koşulunun dışarıda bıraktığı (kalemsiz) siparişlerin neti, Eylül 2026'yı kapsayan dönem için. Sıfırdan farklıysa başlığa "H9: kalemsiz durumu gerekir" yazılır.
- Blok I (j): JOKER doğrudan bağlantısı test makinesinden `SELECT 1 AS Bagli` (`bash tools/sq.sh --joker "SELECT 1 AS Bagli"`). Başarısızsa görev `BLOCKED` döner (H4 testleri koşamaz).
- Blok J (m): `DerinSISBkm.bkm.StokAyBakiyeMekanBazli`'de `ehMekan = 12` satırlarının `Kaynak` ve `Donem` dağılımı (son 6 dönem) + panel kodunda tablonun okunduğu altı yerin listesi ve okudukları `Kaynak`/mekân: `OdakQueries.cs` (`GetUrunlerAsync`), `RefQueries.Envanter.cs` (`GetKategoriCesitAsync`), `SatinalmaQueries.cs` (`#bal`), `SatinalmaQueries.UrunDetay.cs` (`GetSubeSezonAsync`), `SatisAnaliziTabanService.cs` (`snb`). Sonuç cümlesi: "geçmiş ay merkez depo bakiyesini ekranda gösteren yer: <liste | yok>" (KB-1 girdisi).
**Adımlar:**
- [ ] Her bloğu `sqlcli query --profile <erp|encore> --read-only` ile koş; satır sayısını başlığa yaz.
- [ ] Başlığa her blok için bir sonuç cümlesi ve ölçüm tarihi (gg.aa.yyyy).
- [ ] Kapı: `python ../orkestra/dist/orkestra/hooks/sql_denetle.py sorgular/2026-10-panel-veri-duzeltme/00-taban-olcumu.sql`
**Kabul:** on blok koşmuş, her bloğun sonucu ve satır sayısı başlıkta; SQL denetçi E bulgusu 0; blok I başarılı.

### T-002 [SQL] E-ticaret kayma ölçümü — 1. koşu (R2)
**Bağımlılık:** T-001 · **Test seviyesi:** yok (gerekçe: ölçüm) · **AC:** SC-006 girdisi
**Dosyalar:**
- Oluştur: `sorgular/2026-10-panel-veri-duzeltme/00-kayma-olcumu.sql`
**Arayüzler:**
- Tüketir: T-001 blok I (JOKER erişimi)
- Üretir: başlıkta `Koşu 1: <gg.aa.yyyy ss:dd> · Sip=<n> · Ciro=<tutar>`
**Gereksinimler (tam değerlerle):**
- JOKER doğrudan, Eylül 2026 (`'20260901'`–`'20261001'`): sipariş sayısı ve net ciro, kural `o.STATUS NOT IN (1001,1006,1007,3000,4000)`, ciro `SUM(d.QUANTITY * d.SELLINGPRICEWITHOUTVAT)` (`d.ORDERREF = o.ORDERID`). Referans (02.10.2026): 113.731 sipariş, 121.955.096,47 TL.
- Ek kırılım: Eylül siparişlerinin bugünkü STATUS dağılımı (`GROUP BY o.STATUS`).
**Adımlar:**
- [ ] Sorguyu yaz, `bash tools/sq.sh --joker` ile koş, başlığa Koşu 1 satırını yaz.
- [ ] Kapı: `sql_denetle.py` (yukarıdaki komut, bu dosyayla).
**Kabul:** Koşu 1 değerleri başlıkta; E bulgusu 0.

### T-003 [SQL] E-ticaret kayma ölçümü — 2. koşu (R2)
**Bağımlılık:** T-002 ve takvim: Koşu 1'den en az 7 takvim günü sonra · **Test seviyesi:** yok (gerekçe: ölçüm) · **AC:** SC-006 girdisi
**Dosyalar:**
- Değiştir: `sorgular/2026-10-panel-veri-duzeltme/00-kayma-olcumu.sql` (yalnız başlık)
**Arayüzler:**
- Tüketir: T-002 sorgusu (aynı metin)
- Üretir: başlıkta `Koşu 2: …` ve `Kayma: Sip <fark> · Ciro <fark> TL`
**Gereksinimler (tam değerlerle):**
- Sorgu metni değişmez. Fark ≠ 0 ise başlığa: "Koruma testleri eşzamanlı eski↔yeni karşılaştırma yaptığı için etkilenmez; yalnız kanıt başlıklarındaki 'Önce' değerleri tarihlidir."
**Adımlar:**
- [ ] Koş, iki satırı başlığa yaz. Kapı: `sql_denetle.py`.
**Kabul:** iki koşu ve fark arşivde.

### T-004 [SQL] H13 hedef tabanı ölçümü ve GMY önerisi [P]
**Bağımlılık:** yok · **Test seviyesi:** yok (gerekçe: ölçüm + öneri belgesi) · **AC:** AC-13.4, AC-13.5 (girdi)
**Dosyalar:**
- Oluştur: `sorgular/2026-10-panel-veri-duzeltme/H13-hedef-tabani-olcum.sql`
- Oluştur: `.orkestra/calisma/001-panel-veri-duzeltme/h13-hedef-tabani-oneri.md`
**Arayüzler:**
- Tüketir: —
- Üretir: öneri metni "hedef tabanı: ürün kategorisi bazlı, Sınav dahil, KDV {dahil|hariç} — kanıt"
**Gereksinimler (tam değerlerle):** plan K-C üç adımı:
1. Gerçekleşen ürün bazlı: `SalesProducts.ProductsId → Products.Id`, `urn.stkID = CONVERT(int, Products.Code)` (sayısal koruma ile), `urn.urnKtgr2ID = BKMDATA.dbo.Hedef.ktgId`. Belge 8 bazlı değil.
2. Son 6 kapalı ay (Nisan–Eylül 2026) × kategori: `hedef / gercek_haric` ve `hedef / gercek_dahil`. Kategori KDV oranı `urnKDV` join ile (oran elle yazılmaz). Kitap (%0) ↔ Kırtasiye (%20) oran farkının KDV ile ilişkisi raporlanır; kesim seçilmez, iki taban kıyaslanır.
3. Mekân 12 hedefi ayrı satır; üç mağaza kartına girmediği doğrulanır.
- Öneri belgesi: tek sayfa, `sunum-dili.md` (≤ 15 kelimelik cümle), iki tabanın tablosu, "itiraz yoksa öneri uygulanır" tarihi (öneri tarihinden 5 iş günü sonra).
**Adımlar:**
- [ ] Ölç, arşivle, öneriyi yaz. Kapı: `sql_denetle.py` (bu `.sql`).
**Kabul:** üç adım kanıtlı; öneri belgesi hazır. Teyit bu spec'in teslimini beklemez.

### T-005 [SQL] Kanonik sorgu H01 — Kumbara ve manuel indirim [P]
**Bağımlılık:** yok · **Test seviyesi:** yok (gerekçe: kanonik sorgu testin kendisidir; doğruluğu T-019 bağımsız denetimi ve T-018 üçüncü ölçümle sınanır) · **AC:** AC-1.1, AC-1.2, AC-1.3
**Dosyalar:**
- Oluştur: `sorgular/2026-10-panel-veri-duzeltme/H01-kumbara-manuel.sql`
**Arayüzler:**
- Tüketir: —
- Üretir: blok A `(Magaza nvarchar, Brut decimal)` · blok B `(Sebep nvarchar, Magaza nvarchar, Indirim decimal)` (Kumbara için `Sebep = N'Kumbara'`) · blok C `(Magaza nvarchar, IadeliFis int, IadeBrut decimal, IadeIndirim decimal)`; parametreler `@Bas datetime, @Bit datetime`
**Gereksinimler (tam değerlerle):**
- Kumbara: `RefundReasons.Id = 17`; manuel: `RefundReasons.Type = 1`. Bağ: `SalesProductCampaigns.CampaignId IS NULL AND SalesProductCampaigns.CampaignVersion = RefundReasons.Id`, kalem `(SalesId, ProductSequence) = SalesProducts(SalesId, [Sequence])` ve `IsValid = 1` (sema `bridges: salescampaign-sales`).
- Fiş kümesi önce tekilleştirilir (`EXISTS` ya da `SELECT DISTINCT SalesId`), tutarlar başlıktan bir kez: `Brut = GrossTotal`, `Indirim = DiscountTotal`; `DocumentsTypeId = 3` negatif. `DocumentsTypeId IN (1,2,3,6,7,8)`. Mağaza `IN (1,4477,4478)`.
- Manuel: tekillik `(Sebep, fiş)`; iki sebepli fiş her sebepte bir kez (sebepler arası toplam bu yüzden fiş tekil toplamını aşabilir — başlıkta yazılır).
- "Önce" = bugünkü `RefQueries.GetKumbaraAsync`/`GetManuelIndirimAsync` SQL'inin Eylül 2026 değeri (sqlcli ile, `RefQueries.cs` metninden); referans Kumbara brüt önce 6.106.723,80 TL, tekil 223.717,80 TL (02.10.2026).
- Aynı kaynak (Encore) → `Aynı kaynak — neden:` (Kumbara bağı yalnız Encore'da) ve `Başka ne olabilir:` satırları.
**Adımlar:**
- [ ] Yaz, `sqlcli --profile encore --read-only` ile koş, Bağımsız/Önce değerlerini başlığa yaz. Blok C nüfusu 0 ise başlığa "AC-1.3 nüfus 0 — KOŞAMADI beklenir".
- [ ] Kapı: `sql_denetle.py`.
**Kabul:** üç blok koşar, başlık dolu, E bulgusu 0.

### T-006 [SQL] Kanonik sorgu H02 — win-back [P]
**Bağımlılık:** yok · **Test seviyesi:** yok (gerekçe: T-005 ile aynı) · **AC:** AC-2.1…AC-2.4
**Dosyalar:**
- Oluştur: `sorgular/2026-10-panel-veri-duzeltme/H02-winback.sql`
**Arayüzler:**
- Üretir: parametre `@Bugun datetime`. Blok A `(MusteriId bigint)` = son 90 günde satış fişi olan müşteriler · Blok B `(MusteriId bigint, SonSatis date)` tüm zaman son satış fişi · Blok C `(MusteriId bigint, Frq int)` `[@Bugun−365, @Bugun)` satış fişi sayısı · Blok D `(MusteriId bigint)` kanonik liste TOP 200 `ORDER BY ToplCiro DESC, MusteriId`
**Gereksinimler (tam değerlerle):**
- Satış fişi = `DocumentsTypeId = 1`. Müşteri = `Sales.CustomersId > 0`. İç kart hariç: `IcKartFiltre` kuralının SQL'i (isim `Mağaza`/`Kumbara`, telefon 599/699 öneki, elle liste) panelden kopyalanmadan `sql-server-conventions.md` § müşteri raporları ve `Data/IcKartService.cs:11-30` açıklamasından yeniden yazılır; elle liste kısmı `IcKartService`'in okuduğu kaynaktan okunur.
- Liste koşulu: `[−365, bugun)` en az bir satış fişi · `[−90, bugun)` hiç satış fişi yok · `Frq >= 3` · `ToplCiro >= 500` (`(1,3)` KDV hariç net, iade negatif).
- Referans: 02.10.2026'da 51.309 adayın 23.110'u son 90 günde fiş kesmiş.
**Adımlar:** [ ] Yaz, koş, başlık. [ ] Kapı: `sql_denetle.py`.
**Kabul:** dört blok koşar; E bulgusu 0.

### T-007 [SQL] Kanonik sorgu H03 — tedarikçi karnesi merkez depo [P]
**Bağımlılık:** yok · **Test seviyesi:** yok (gerekçe: T-005 ile aynı) · **AC:** AC-3.1…AC-3.4
**Dosyalar:**
- Oluştur: `sorgular/2026-10-panel-veri-duzeltme/H03-tedarikci-depo.sql`
**Arayüzler:**
- Üretir: Blok A `(MrkId int, DepoStok int)` canlı WMS alan 0+1, `urn.urnMrkID` üzerinden · Blok B `(DepoToplam int)` verilen marka kümesi için (`@MrkIdListe` tablo değil: test `MrkId IN` listesini ayrı ayrı A'dan toplar; B tüm markalar toplamı) · Blok C `(StkId int, DepoStok int)` depo > 0 olan ilk 20 ürün `ORDER BY stkID` · Blok D `(MrkId int, MagazaStok int)` `stokSonAltDepo_vw`, `ehAltDepo = 0`, `stok > 0`, `ehMekan IN (1,4477,4478)`
**Gereksinimler (tam değerlerle):**
- Farklı kaynak: WMS view; ERP defteri merkez depo için kullanılmaz. Referans (02.10.2026): ERP defteri 5.884.929, WMS 3.628.661 adet.
**Adımlar:** [ ] Yaz, koş, başlık. [ ] Kapı: `sql_denetle.py`.
**Kabul:** dört blok koşar; E bulgusu 0.

### T-008 [SQL] Kanonik sorgular H04 — e-ticaret kategori ve ODAK talebi
**Bağımlılık:** T-001 · **Test seviyesi:** yok (gerekçe: T-005 ile aynı) · **AC:** AC-4.1, AC-4.2, AC-4.3
**Dosyalar:**
- Oluştur: `sorgular/2026-10-panel-veri-duzeltme/H04-etic-kategori.sql`
- Oluştur: `sorgular/2026-10-panel-veri-duzeltme/H04-odak-talep.sql`
**Arayüzler:**
- Üretir: `H04-etic-kategori.sql` parametre `@BasIso varchar(8), @BitIso varchar(8)`; blok A `(Kategori nvarchar NULL, Siparis int, NetCiro decimal, Adet int)` kategorisi bilinmeyen satır `Kategori = NULL`; blok B `(Siparis int, NetCiro decimal)` ana (kategori kırılımsız). `H04-odak-talep.sql` blok A `(StkId int, Adet int)`.
- Tüketir: T-001 blok D sonucu (başlığa aktarılır)
**Gereksinimler (tam değerlerle):**
- JOKER doğrudan. Başlık kuralı `o.STATUS NOT IN (1001,1006,1007,3000,4000)`; ODAK talebinde ayrıca `d.STATUS NOT IN (2004,2005,2010)`. Kod listeleri `sema/codes.yaml: joker.J_ORDERS.STATUS.net_iptal_iade` ve `joker.J_ORDER_DETAILS.STATUS.net_iptal_iade`'den okunarak yazılır; başlıkta kaynak satırı.
- Sipariş satırı `d.ORDERREF = o.ORDERID`; ürün `d.ITEMREF = J_ITEMS.LOGICALREF`, `J_ITEMS.DERINSIS_ID = urn.stkID`; kategori `J_ITEMS.DERINSIS_LOGOGRUP`.
- ODAK talep dönemi: ODAK `ecom` CTE'sinin penceresiyle aynı (pencere `OdakQueries.cs` metninden okunur ve başlığa yazılır; Eylül 2026 sabitlenir).
- Referans: ana net 121.955.096,47 TL / 113.731 sipariş; önce 126.329.033,57 TL / 117.884.
**Adımlar:** [ ] Yaz, `bash tools/sq.sh --joker` ile koş, başlık. [ ] Kapı: `sql_denetle.py` (iki dosya).
**Kabul:** iki dosya koşar; E bulgusu 0.

### T-009 [SQL] Kanonik sorgu H05 — fiş ve iade sayısı
**Bağımlılık:** T-001 · **Test seviyesi:** yok (gerekçe: T-005 ile aynı) · **AC:** AC-5.1, AC-5.3, AC-5.4
**Dosyalar:**
- Oluştur: `sorgular/2026-10-panel-veri-duzeltme/H05-fis.sql`
**Arayüzler:**
- Üretir: blok A `(Fis int)` parametre `@Bas, @Bit, @MekanId int` · blok B `(Tip nvarchar, FisSayisi int)` kartlı/kartsız, parametre `@Bugun` (son 12 ay) · blok C `(IadeSayisi int)` parametre `@Bas, @Bit, @MekanId`
**Gereksinimler (tam değerlerle):**
- Fiş = `DocumentsTypeId = 1` ve belgede `BarcodeNo = '1001'` satırı yok. İade = `DocumentsTypeId = 3` ve 1001 satırı yok (KR-1 onaylandı).
- Kartlı = `CustomersId > 0 AND CardNumber <> ''`; kartsız anonim dahil (`CustomersId = 0`). İç kart hariç.
- Referans FSM Eylül 2026: fiş 42.774, iade 947.
- Farklı kaynak denemesi: fiş sayısı için ERP'de belge düzeyi yok (`eTip 100` günlük özet) → `Aynı kaynak — neden:` satırı.
**Adımlar:** [ ] Yaz, koş, başlık. [ ] Kapı: `sql_denetle.py`.
**Kabul:** üç blok koşar; A ve C FSM değerleri başlıkta.

### T-010 [SQL] Kanonik sorgu H06 — mağaza detay
**Bağımlılık:** T-001 · **Test seviyesi:** yok (gerekçe: T-005 ile aynı) · **AC:** AC-6.1…AC-6.4
**Dosyalar:**
- Oluştur: `sorgular/2026-10-panel-veri-duzeltme/H06-magaza.sql`
**Arayüzler:**
- Üretir: parametre `@Bas, @Bit, @MekanId`. Blok A `(IptalKalemKampanyaIndirim decimal)` iptal (`IsValid = 0`) kaleme bağlı kampanya indirimi toplamı (testte paneldeki kampanya indirimine dahil olmamalı) · Blok B `(KampanyaliKalemNetKdvDahil decimal)` geçerli kampanyalı kalemlerin `SUM(TotalPrice)` · Blok C `(IadeKdvHaric decimal)` · Blok D `(Kalem decimal, Fis int)`
- Tüketir: T-001 blok E (`(SalesId, Sequence)` tekilliği)
**Gereksinimler (tam değerlerle):**
- Kampanya kaydı kaleme `spc.SalesId = sp.SalesId AND spc.ProductSequence = sp.[Sequence]`.
- İade KDV hariç, indirim düşülmüş: `GrossTotal − DiscountTotal − VatTotal`, `DocumentsTypeId = 3`, 1001 hariç.
- UPT: pay `SUM(sp.Amount)` (`IsValid = 1`), payda fiş; yalnız `DocumentsTypeId = 1`, 1001 hariç.
- Mümkünse C bloğunun bir kontrolü `irsHrk.ehTip = 101` toplamıyla (kuruşu kuruşuna kimlik, `sql-server-conventions.md`) başlığa yazılır.
**Adımlar:** [ ] Yaz, üç mağaza için koş, başlık. [ ] Kapı: `sql_denetle.py`.
**Kabul:** dört blok × üç mağaza değerleri başlıkta.

### T-011 [SQL] Kanonik sorgu H07 — kategori marjı ve ABC [P]
**Bağımlılık:** yok · **Test seviyesi:** yok (gerekçe: T-005 ile aynı) · **AC:** AC-7.1, AC-7.2, AC-7.3
**Dosyalar:**
- Oluştur: `sorgular/2026-10-panel-veri-duzeltme/H07-marj-abc.sql`
**Arayüzler:**
- Üretir: blok A `(Ciro decimal)` kanonik şube cirosu `irsHrk` 100 − 101 + 4 − 5, üç mağaza, `ehAltDepo = 0` · blok B `(Ciro decimal)` pozitif net ürün cirolarının toplamı (Encore, `DocumentsTypeId IN (1,2,3,6,7,8)`, iade negatif, `HAVING SUM > 0`)
**Gereksinimler (tam değerlerle):**
- Başlıkta: "muhasebe açık dönem — maliyet (ehMaliyet) Eylül için değişebilir; ciro kasa tabanlı" (İnsan onayı 12).
- Farklı kaynak: A `irsHrk`, panel marjı da `irsHrk` → `Aynı kaynak — neden:`; ek kontrol A ↔ Encore toplamı (`sql-server-conventions.md` mutabakatı) başlığa.
**Adımlar:** [ ] Yaz, koş, başlık. [ ] Kapı: `sql_denetle.py`.
**Kabul:** iki blok koşar.

### T-012 [SQL] Kanonik sorgu H08 — merkez depo
**Bağımlılık:** T-001 · **Test seviyesi:** yok (gerekçe: T-005 ile aynı) · **AC:** AC-8.1…AC-8.4
**Dosyalar:**
- Oluştur: `sorgular/2026-10-panel-veri-duzeltme/H08-merkez-depo.sql`
**Arayüzler:**
- Üretir: blok A `(StkId int, Merkez int)` canlı WMS alan 0+1, parametre yok · blok B `(StkId int, Merkez int)` parametre `@Donem date`, `Kaynak = 'WMS' AND ehMekan = 12 AND Donem = @Donem` · blok C `(GoruntuVar int)` aynı süzgeçle `EXISTS`
**Gereksinimler (tam değerlerle):** referans 02.10.2026: canlı WMS 3.628.661 adet; ODAK ay sonu 4.249.866. Başlığa T-001 blok J sonucu aktarılır.
**Adımlar:** [ ] Yaz, koş (B için son dolu dönem ve dolu olmayan `01.10.2026`). [ ] Kapı: `sql_denetle.py`.
**Kabul:** üç blok koşar; olmayan dönemde B boş, C 0.

### T-013 [SQL] Kanonik sorgu H09 — Sınav ödeme sağlık kartı
**Bağımlılık:** T-001 · **Test seviyesi:** yok (gerekçe: T-005 ile aynı) · **AC:** AC-9.1, AC-9.2
**Dosyalar:**
- Oluştur: `sorgular/2026-10-panel-veri-duzeltme/H09-sinav-odeme.sql`
**Arayüzler:**
- Üretir: parametre `@DonemId int` (Eylül 2026'yı kapsayan `snv.Donem`). Blok A `(NetKdvHaric decimal)` fatura başına bir kez toplanmış Sınav neti (satış FE'den, iade `LinkedDocumentId > 0` bağından, işaretli) · blok B `(CokSiparisliFatura int)` birden çok siparişe bağlı fatura sayısı (nüfus)
- Tüketir: T-001 blok H
**Gereksinimler (tam değerlerle):** köprü `BKM.snv.SinavSiparisFisEncore` (sema `entities: BKM.snv.*`); `COLLATE Turkish_CI_AS`.
**Adımlar:** [ ] Yaz, koş, başlık. [ ] Kapı: `sql_denetle.py`.
**Kabul:** iki blok koşar.

### T-014 [SQL] Kanonik sorgu H10 — ürün kodu dönüşümü [P]
**Bağımlılık:** yok · **Test seviyesi:** yok (gerekçe: beklenen değer tablosu; testi T-058) · **AC:** AC-10.3
**Dosyalar:**
- Oluştur: `sorgular/2026-10-panel-veri-duzeltme/H10-urun-kodu.sql`
**Arayüzler:**
- Üretir: blok A `(Kod nvarchar(50), Beklenen int NULL)` sabit `VALUES` tablosu: `('123',123)`, `('999999999',999999999)`, `('12a',NULL)`, `('',NULL)`, `(' 123',NULL)`, `('-5',NULL)`, `('2147483648',NULL)`, `('0123456789',NULL)` · blok B `(SayisalOlmayan int)` `EncoreMerkez.dbo.Products` içinde `Code NOT LIKE '%[^0-9]%' AND LEN(Code) BETWEEN 1 AND 9` koşulunu sağlamayan kayıt sayısı (02.10.2026: 0)
**Adımlar:** [ ] Yaz, koş. [ ] Kapı: `sql_denetle.py`.
**Kabul:** blok A sekiz satır; B değeri başlıkta.

### T-015 [SQL] Kanonik sorgu H12 — mizan nakit, alınan çek, KDV [P]
**Bağımlılık:** yok · **Test seviyesi:** yok (gerekçe: T-005 ile aynı) · **AC:** AC-12.1, AC-12.2, AC-12.3
**Dosyalar:**
- Oluştur: `sorgular/2026-10-panel-veri-duzeltme/H12-mizan.sql`
**Arayüzler:**
- Üretir: parametre `@SirketId int = 6, @Ay int = 6, @AyBas int = 1` (Haziran 2026 kümülatif). Blok A `(Nakit decimal)` 100+102+108 borç bakiyesi · B `(AlinanCek decimal)` 101 · C `(KdvNet decimal)` 391 alacak − 191 borç − 190 borç
**Gereksinimler (tam değerlerle):** kaynak `DerinSISBkm.mhs` fiş satırları doğrudan (panelin `MizanQueries` ağacı kullanılmaz); `fisSirketID = @SirketId` (`MizanQueries.YilOffset = 2020`).
**Adımlar:** [ ] Yaz, koş. [ ] Kapı: `sql_denetle.py`.
**Kabul:** üç blok koşar.

### T-016 [SQL] Kanonik sorgular H13 — Sınav neti ve şube cirosu
**Bağımlılık:** T-001 · **Test seviyesi:** yok (gerekçe: T-005 ile aynı) · **AC:** AC-13.2, AC-13.3
**Dosyalar:**
- Oluştur: `sorgular/2026-10-panel-veri-duzeltme/H13-sinav-net.sql`
- Oluştur: `sorgular/2026-10-panel-veri-duzeltme/H13-sube-cirosu.sql`
**Arayüzler:**
- Üretir: `H13-sinav-net.sql` `(MekanId int, NetSinav decimal)`, parametre `@Bas, @Bit` — `DocumentsTypeId = 8` artı bağlı belgesi 8 olan iadeler (negatif), KDV hariç, 1001 hariç. `H13-sube-cirosu.sql` `(MekanId int, Ciro decimal)` `irsHrk` 100 − 101 + 4 − 5.
- Tüketir: T-001 blok F
**Gereksinimler (tam değerlerle):** referans: panel 469.938.584 TL, kanonik 470.550.331 TL, fark −%0,13 (02.10.2026). İade kanal kuralı İnsan onayı 4: Sınav'a bağlı iade Sınav satırından düşer.
**Adımlar:** [ ] Yaz, koş. [ ] Kapı: `sql_denetle.py` (iki dosya).
**Kabul:** iki dosya koşar.

### T-017 [SQL] Kanonik sorgular D-2 kasiyer ve D-4 hediye çeki
**Bağımlılık:** T-001 · **Test seviyesi:** yok (gerekçe: T-005 ile aynı) · **AC:** D-2, D-4
**Dosyalar:**
- Oluştur: `sorgular/2026-10-panel-veri-duzeltme/D2-kasiyer.sql`
- Oluştur: `sorgular/2026-10-panel-veri-duzeltme/D4-hediye-ceki.sql`
**Arayüzler:**
- Üretir: `D2-kasiyer.sql` `(MekanId int, KasiyerNet decimal)` kasiyer (`Sales.UsersId`) bazında toplanıp mağazaya toplanmış net, 1001 hariç, `MagazaBelgeleri`; ek blok B: kategori karması (`katSql` kapsamı) ile mağaza neti farkı. `D4-hediye-ceki.sql` `(Dilim int, Brut decimal, Indirim decimal, NetKdvDahil decimal)` kalem tabanı `Brut = TotalPrice + DiscountTotalDirect`.
- Tüketir: T-001 blok C (KR-4)
**Adımlar:** [ ] Yaz, koş. [ ] Kapı: `sql_denetle.py` (iki dosya).
**Kabul:** iki dosya koşar.

### T-018 [SQL] P1 üçüncü ölçüm (GMY Excel)
**Bağımlılık:** T-005, T-006, T-007 · **Test seviyesi:** yok (gerekçe: dış ölçüm kaydı) · **AC:** AC-1.1, AC-2.1, AC-3.2 (üçüncü ölçüm, R3)
**Dosyalar:**
- Oluştur: `sorgular/2026-10-panel-veri-duzeltme/00-p1-ucuncu-olcum.md`
**Arayüzler:**
- Tüketir: H01 blok A, H02 blok D, H03 blok B değerleri
- Üretir: tablo `| H | Rakam | GMY Excel değeri | Kanonik değer | Fark | Sonuç (tuttu/saptı) |`
**Gereksinimler (tam değerlerle):**
- GMY'den üç rakam istenir: Eylül 2026 Kumbara brüt (fiş tekil), win-back listesinden rastgele bir müşterinin son alışveriş tarihi, bir tedarikçinin merkez depo adedi (WMS). Kişisel veri yazılmaz (müşteri kimliği yerine "müşteri 1").
- Rakam gelmezse görev `NEEDS_CONTEXT` döner; ilgili H kapanışı T-080'de "karar bekliyor".
**Adımlar:** [ ] Rakamları al, tabloyu doldur.
**Kabul:** üç satır dolu; "saptı" olan H için T-080'e not.

### T-019 [SQL] Kanonik sorguların bağımsız denetimi ve dondurulması (R3)
**Bağımlılık:** T-005…T-017 · **Test seviyesi:** yok (gerekçe: denetim + dondurma) · **AC:** SC-002, R3
**Dosyalar:**
- Değiştir: `sorgular/2026-10-panel-veri-duzeltme/H*.sql`, `D*.sql` (yalnız denetim bulgusu düzeltmesi ve başlık `Dondurma:` satırı)
**Arayüzler:**
- Üretir: dondurma commit'i `db(T-019): kanonik sorguları dondur` ve ardından başlık commit'i `db(T-019): dondurma hash'ini başlıklara yaz`; her dosyada `Dondurma: <dondurma commit kısa hash>`
**Gereksinimler (tam değerlerle):**
- `sql-denetci`'ye yalnız şunlar verilir: `sorgular/2026-10-panel-veri-duzeltme/`, `.claude/rules/sql-server-conventions.md`, `sema/`. **`dashboard/` verilmez.** Denetçi bulgusu düzeltilir, düzeltme yazarı panel kodunu açmaz.
- Dondurmadan sonra kanonik dosyada değişiklik ayrı commit + gövdede gerekçe ister (T-080 "Sonra" satırları hariç).
**Adımlar:**
- [ ] Bağımsız denetim → düzeltmeler → `sql_denetle.py` tüm dosyalar.
- [ ] Dondurma commit'i; hash'i başlıklara yazan ikinci commit.
**Kabul:** denetçi raporu E bulgusu 0; tüm dosyalarda `Dondurma:` satırı.

### T-020 [SQL] Eski formüllerin dondurulmuş kopyası (koruma girdisi) [P]
**Bağımlılık:** yok (ama T-025'ten **önce** yapılmalı) · **Test seviyesi:** yok (gerekçe: karakterizasyon girdisi; kırılabilirliği T-024'te) · **AC:** SC-006
**Dosyalar:**
- Oluştur: `tests/GmDashboard.Tests/Koruma/Eski/magaza-net-eski.sql`
- Oluştur: `tests/GmDashboard.Tests/Koruma/Eski/etic-ana-eski.sql`
**Arayüzler:**
- Üretir: `magaza-net-eski.sql` → `(MekanId int, Net decimal, Fis int, Iade decimal)` parametre `@start, @end`; `etic-ana-eski.sql` → `(Sip int, Ciro decimal)` parametre `@giso, @g2iso`
**Gereksinimler (tam değerlerle):**
- Metinler `dashboard/Data/Queries.cs`'teki `storeSql` (satır 25-36) ve `eticSql` (satır 53-59) sabitlerinden **birebir** kopyalanır; başlık yorumu: kaynak dosya:satır ve kaynak commit `d5cf345`.
**Adımlar:** [ ] Kopyala; `sqlcli` ile Eylül 2026 için koş, değeri başlığa yaz.
**Kabul:** iki dosya koşar; metin kaynağıyla birebir.

# F1 — Test altyapısı

### T-021 [NET] Test projesi ve salt-okuma kapısı (R1)
**Bağımlılık:** T-019, T-020 · **Test seviyesi:** tam · **AC:** FR-015, R1
**Dosyalar:**
- Oluştur: `tests/GmDashboard.Tests/GmDashboard.Tests.csproj`
- Değiştir: `Pusula.sln` (projeyi ekle)
- Oluştur: `tests/GmDashboard.Tests/Altyapi/SaltOkumaKapisi.cs`
- Oluştur: `tests/GmDashboard.Tests/Altyapi/CanliDb.cs`
- Test: `tests/GmDashboard.Tests/Altyapi/SaltOkumaKapisiTests.cs`, `tests/GmDashboard.Tests/Altyapi/KanonikDosyaKapisiTests.cs`
**Arayüzler:**
- Tüketir: `Bkm.Shared.Data.Db(IConfiguration, ILogger<Db>)`, `Db.OpenAsync()`, `Db.OpenJokerAsync()`; kanonik `.sql` dosyaları (T-019)
- Üretir:
  - `public sealed record SaltOkumaSonucu(bool Gecti, string? Neden);`
  - `public static class SaltOkumaKapisi { public static SaltOkumaSonucu Denetle(string sql); }`
  - `public enum Hedef { Erp, Joker }`
  - `public static class CanliDb { public static Db PanelDb(); public static Task<IReadOnlyList<T>> SorguAsync<T>(Hedef hedef, string sql, object? param = null, CancellationToken ct = default); public static Task<T> TekDegerAsync<T>(Hedef hedef, string sql, object? param = null, CancellationToken ct = default); }`
**Gereksinimler (tam değerlerle):**
- csproj: `net10.0`, `Nullable enable`, `ImplicitUsings enable`, `IsPackable false`, `RootNamespace GmDashboard.Tests`, `InvariantGlobalization false`; paketler Global kısıtlardaki sürümler; `ProjectReference ..\..\dashboard\GmDashboard.csproj`; `<None Include="..\..\sorgular\2026-10-panel-veri-duzeltme\*.sql" LinkBase="Kanonik" CopyToOutputDirectory="PreserveNewest" />` ve `<None Include="Koruma\Eski\*.sql" CopyToOutputDirectory="PreserveNewest" />`.
- Kapı: dize (`'…'`, `N'…'`) ve yorum (`--…`, `/*…*/`) ayıklanır; kalan metinde ilk anlamlı kelime `SELECT` ya da `WITH` olmalı; `WITH` ise son CTE'den sonraki ilk kelime `SELECT` olmalı; ifade ayırıcı `;` sonrasında ikinci ifade yok; şu kelimelerden biri geçerse ret: `INSERT UPDATE DELETE MERGE EXEC EXECUTE DROP ALTER CREATE TRUNCATE GRANT REVOKE DENY INTO SET USE DBCC BACKUP RESTORE KILL SHUTDOWN OPENROWSET OPENDATASOURCE BULK`. Tanınmayan her şey reddedilir; `Neden` reddedilen kelimeyi/konumu yazar.
- `CanliDb.SorguAsync`: (1) `BKM_ENV_DOSYA` ortam değişkeni doluysa `Assert.Fail("KOŞAMADI: BKM_ENV_DOSYA tanımlı — hata testi ortamı sızdı")`; (2) kapıdan geçmeyen SQL → `Assert.Fail("SALT-OKUMA KAPISI: …")`; (3) bağlantı açılamazsa `Assert.Fail("KOŞAMADI: bağlantı açılamadı — <istisna türü>")` (sunucu adı yazılmaz); (4) bağlantıda önce `SET LOCK_TIMEOUT 5000; SET DEADLOCK_PRIORITY LOW;` (sabit metin, kapı dışı); (5) `BeginTransaction()`; sorgu `CommandDefinition(transaction: tx, commandTimeout: 240)`; `finally` içinde her zaman `Rollback()`.
- `CanliDb` içinde `ExecuteAsync` çağrısı **yoktur**.
- Kırmızı kip: `tests/GmDashboard.Tests/Altyapi/Sahte/zz-kirmizi-kip.sql` (`UPDATE dbo.x SET a = 1`) geçici olarak eklenir ve `KanonikDosyaKapisiTests` kırmızı görülür, dosya silinir, takım yeniden koşulur.
**Adımlar:**
- [ ] İskelet (dotnet-yazar): csproj, sln, `SaltOkumaKapisi.Denetle` ve `CanliDb` gövdeleri `throw new NotImplementedException()`; `dotnet build tests/GmDashboard.Tests/GmDashboard.Tests.csproj -warnaserror` yeşil.
- [ ] Senaryo matrisi (test-tasarimci).
- [ ] Kırmızı testler (test-yazar): `SaltOkumaKapisi_Denetle_YazmaBicimleriniReddeder` (teori: İnceleme odağı 2'deki beş ifade + `MERGE`, `TRUNCATE TABLE t`), `SaltOkumaKapisi_Denetle_DizeVeYorumdakiKelimeyiGecirir` (teori: `SELECT 'DELETE' AS a`, `SELECT 1 /* UPDATE */`, `WITH c AS (SELECT 1 AS a) SELECT a FROM c`), `KanonikDosyalar_Hepsi_SaltOkumaKapisindanGecer` (teori, `MemberData` = `Kanonik/*.sql` ve `Koruma/Eski/*.sql`, `-- blok:` ile bölünmüş her ifade), `CanliDb_SorguAsync_KapidanGecmeyenSqlCalistirmaz` (birim; bağlantı açılmadan reddedilir).
- [ ] Uygulama.
- [ ] Kırmızı kip kanıtı (yukarıda) — geri alma `--hard` içermez.
- [ ] Kapılar: derleme · birim komutu · `python tools/turkce_tanimlayici_denetimi.py`.
**Kabul:** birim testleri yeşil; kırmızı kip kanıtı raporda (komut + kırmızı çıktı + silme + yeniden yeşil).

### T-022 [NET] Hata testi yalıtımı (R5)
**Bağımlılık:** T-021 · **Test seviyesi:** tam · **AC:** AC-10.1, AC-10.2 (altyapı), R5
**Dosyalar:**
- Oluştur: `tests/GmDashboard.Tests/Altyapi/HataEkraniOrtami.cs`
- Oluştur: `tests/GmDashboard.Tests/Altyapi/HataEkraniFabrikasi.cs`
- Oluştur: `tests/GmDashboard.Tests/Altyapi/BellekGunluk.cs`
- Test: `tests/GmDashboard.Tests/HataEkrani/YalitimTests.cs`
**Arayüzler:**
- Tüketir: `CanliDb` (T-021), `Program` (`WebApplicationFactory<Program>`; .NET 10'da ek bildirim gerekmez)
- Üretir:
  - `public sealed class HataEkraniOrtami : IDisposable { public const string SahteHost = "127.0.0.1"; public const string SahtePort = "1"; public string EnvDosyasi { get; } }`
  - `[CollectionDefinition("HataEkrani", DisableParallelization = true)] public sealed class HataEkraniKoleksiyonu : ICollectionFixture<HataEkraniOrtami> { }`
  - `public sealed record GunlukKaydi(LogLevel Duzey, string Kategori, string Mesaj, Exception? Istisna);`
  - `public sealed class BellekGunluk : ILoggerProvider { public IReadOnlyList<GunlukKaydi> Kayitlar { get; } }`
  - `public sealed class HataEkraniFabrikasi : WebApplicationFactory<Program> { public BellekGunluk Gunluk { get; } }`
**Gereksinimler (tam değerlerle):**
- Karar (plan K-A'nın kendi yedeği): `Db` yalnız `.env` okur (`lib/Bkm.Shared/Data/Db.cs:19-58`, `IConfiguration` bağlantı için kullanılmaz) ve `lib/Bkm.Shared` değişmez; bu yüzden `BKM_ENV_DOSYA` yolu kullanılır.
- `HataEkraniOrtami` kurucu: geçici dosya `Path.Combine(Path.GetTempPath(), "gmd-hata-" + Guid.NewGuid().ToString("N") + ".env")` içine yalnız `MSSQL_HOST=127.0.0.1` ve `MSSQL_PORT=1` yazar (parola yok, JOKER/ZIRVE/PANEL anahtarı yok); `BKM_ENV_DOSYA`'yı bu yola ayarlar. `Dispose`: değişkeni `null` yapar, dosyayı siler.
- Fabrika: ortam `Development`; `ConfigureLogging` ile `BellekGunluk` eklenir.
- **İlk assert her testte:** `File.Exists(ortam.EnvDosyasi)` ve `Db.LoadEnvStatic()["MSSQL_HOST"] == "127.0.0.1"`.
**Adımlar:**
- [ ] İskelet · senaryo matrisi · kırmızı testler: `HataEkraniOrtami_Kurulum_DbSahteSunucuyaYonelir`, `HataEkraniOrtami_GeciciDosyaYok_KirmiziDoner` (dosya silinince ilk-adım assert'i kırmızı; bu test fabrikayı kurmadan ilk-adım yardımcısını çağırır), `CanliDb_BkmEnvDosyaTanimli_KosamadiVerir`.
- [ ] Uygulama · kırmızı kip: ortam kurucusunda dosya yolu bilerek yanlış verilir → kırmızı görülür → geri alınır.
- [ ] Kapılar: derleme · `dotnet test tests/GmDashboard.Tests --filter "Tur=HataEkrani"` · birim komutu.
**Kabul:** üç test yeşil; tam birim koşusunda (paralel) kanonik dışı testler etkilenmez.

### T-023 [NET] Ortak test yardımcıları
**Bağımlılık:** T-022 · **Test seviyesi:** tam · **AC:** tüm kanonik testlerin altyapısı
**Dosyalar:**
- Oluştur: `tests/GmDashboard.Tests/Altyapi/KanonikSorgu.cs`, `Tolerans.cs`, `Nufus.cs`, `SahteSaat.cs`, `KaynakDosya.cs`
- Test: `tests/GmDashboard.Tests/Altyapi/YardimciTests.cs`
**Arayüzler:**
- Üretir:
  - `public static class KanonikSorgu { public static string Oku(string dosya, string? blok = null); }` — `blok` verilirse `-- blok: <ad>` satırından bir sonraki `-- blok:` satırına ya da dosya sonuna kadar; başlık yorumu dahil edilmez; blok yoksa `InvalidOperationException`.
  - `public static class Tolerans { public const decimal Tutar = 1.00m; public const decimal Oran = 0.003m; public static void TutarEsit(decimal panel, decimal kanonik, string etiket); public static void OranIcinde(decimal panel, decimal kanonik, string etiket); }`
  - `public static class Nufus { public static void EnAz(int n, string neden); }` — `n < 1` → `Assert.Fail("KOŞAMADI: nüfus 0 — " + neden)`.
  - `public sealed class SahteSaat(DateTimeOffset simdi) : TimeProvider { public override DateTimeOffset GetUtcNow(); public override TimeZoneInfo LocalTimeZone => TimeZoneInfo.Utc; }`
  - `public static class KaynakDosya { public static string Oku(string depoGoreliYol); }` — `AppContext.BaseDirectory`'den yukarı `Pusula.sln` bulunana kadar çıkar.
**Adımlar:**
- [ ] İskelet · kırmızı testler: `KanonikSorgu_Oku_BlokSinirindaDurur`, `KanonikSorgu_Oku_OlmayanBlokHataVerir`, `Tolerans_TutarEsit_BirKurusFazlasindaKirmizi` (1,01 TL fark → `XunitException`), `Nufus_EnAz_SifirdaKosamadiMesaji`, `SahteSaat_GetLocalNow_VerilenAniDoner`.
- [ ] Uygulama · kapılar: derleme · birim komutu.
**Kabul:** beş test yeşil.

### T-024 [NET] Koruma testleri — eski ↔ yeni formül (SC-006)
**Bağımlılık:** T-020, T-023 · **Test seviyesi:** hafif · **AC:** SC-006
**Dosyalar:**
- Test: `tests/GmDashboard.Tests/Koruma/KorumaTests.cs`
**Arayüzler:**
- Tüketir: `Koruma/Eski/magaza-net-eski.sql`, `etic-ana-eski.sql` (T-020); `Queries.GetPeriodAsync(DateOnly start, DateOnly endExcl, DateOnly? prevStart = null, DateOnly? prevEnd = null)` → `PeriodSummary.Stores[*].Net`, `PeriodSummary.Eticaret`, `PeriodSummary.ESip`; `CanliDb`, `Tolerans`
- Üretir: `Koruma_Eylul2026_EskiVeYeniFormulEsit` (`Tur=Koruma`)
**Gereksinimler (tam değerlerle):**
- Üç mağaza `Net` farkı ≤ 1,00 TL; `ESip` birebir; `Eticaret` ≤ 1,00 TL. Sabit rakam yok. Eski SQL ve panel aynı test içinde, ardışık okunur.
- Bu test F2'den F6'ya kadar her davranış görevinde yeşil kalmalıdır.
**Adımlar:**
- [ ] Test (test-yazar) · koşu (19:00 sonrası) yeşil.
- [ ] Kırılabilirlik: `magaza-net-eski.sql`'de `DocumentsTypeId IN (1,2,3,6,7,8)` → `IN (1,2,3,6,7)` yapılır, İst.Yolu kırmızı görülür, elle geri yazılır, yeniden yeşil.
**Kabul:** yeşil + kırmızı kip kanıtı.

# F2 — Ortak tanımlar

### T-025 [NET] FisTanimi çıkarımı — rakamı değiştirmeyen refactor (R6)
**Bağımlılık:** T-024 · **Test seviyesi:** hafif · **AC:** SC-006 (koruma)
**Dosyalar:**
- Oluştur: `dashboard/Data/Tanimlar/FisTanimi.cs`
- Değiştir: `dashboard/Data/Queries.cs` (yalnız `storeSql`)
- Test: `tests/GmDashboard.Tests/Birim/FisTanimiCikarimTests.cs`
**Arayüzler:**
- Tüketir: —
- Üretir (namespace `GmDashboard.Data.Tanimlar`, `public static class FisTanimi`):
  `public const string MagazaBelgeleri = "1,2,3,6,7,8";` · `public const int SatisFisi = 1;` · `public const int Iade = 3;` · `public const int SinavOkullari = 8;` · `public static string GeriDonusumHaricJoin(string sales)` → `"LEFT JOIN (SELECT DISTINCT gd0.SalesId FROM EncoreMerkez.dbo.SalesProducts gd0 WITH(NOLOCK) WHERE gd0.BarcodeNo = '1001') gd ON gd.SalesId = {sales}.Id"` · `public const string GeriDonusumHaricKosul = "gd.SalesId IS NULL";` · `public static string NetKdvHaric(string sales)` → `"(CASE WHEN {sales}.DocumentsTypeId = 3 THEN -1 ELSE 1 END * ({sales}.GrossTotal - {sales}.DiscountTotal - {sales}.VatTotal))"` · `public static string IadeKdvHaric(string sales)` → `"(CASE WHEN {sales}.DocumentsTypeId = 3 THEN {sales}.GrossTotal - {sales}.DiscountTotal - {sales}.VatTotal ELSE 0 END)"`
**Gereksinimler (tam değerlerle):**
- `storeSql`'de `LEFT JOIN … spb … AND spb.BarcodeNo='1001'` + `spb.Id IS NULL` yerine `GeriDonusumHaricJoin("s")` + `GeriDonusumHaricKosul`; `Net` → `SUM(NetKdvHaric("s"))`; `Iade` → `SUM(IadeKdvHaric("s"))`; `DocumentsTypeId IN (` + `MagazaBelgeleri` + `)`. `Fis` kolonu **değişmez** (satış − iade, davranışı T-041 değiştirir). `storeSql` `const` yerine interpolasyonlu `static readonly string` olur.
- `takma ad` parametresi yalnız kod içi sabit (`"s"`).
**Adımlar:**
- [ ] Test (test-yazar): `FisTanimi_GeriDonusumHaricJoin_TakmaAdiOnKosulunaYazar` (`"x"` → metin `gd.SalesId = x.Id` içerir).
- [ ] Uygulama · kapılar: derleme · birim · `python tools/panel_kolon_denetimi.py` · **T-024 koruma testi önce ve sonra yeşil** (19:00 sonrası).
**Kabul:** koruma yeşil (rakam değişmedi); commit tipi `refactor`.

### T-026 [NET] EticDurum çıkarımı — rakamı değiştirmeyen refactor (R6)
**Bağımlılık:** T-025 · **Test seviyesi:** hafif · **AC:** SC-006
**Dosyalar:**
- Oluştur: `dashboard/Data/Tanimlar/EticDurum.cs`
- Değiştir: `dashboard/Data/Queries.cs` (`eticSql` ve satır ~116-118, ~174, ~185'teki `STATUS NOT IN (1001,1006,1007,3000,4000)`), `dashboard/Data/EticQueries.cs` (aynı listenin geçtiği her yer)
- Test: `tests/GmDashboard.Tests/Birim/EticDurumTests.cs`
**Arayüzler:**
- Üretir: `public static class EticDurum { public const string SiparisIptalIade = "1001,1006,1007,3000,4000"; public const string SatirIptalIade = "2004,2005,2010"; }`
**Gereksinimler (tam değerlerle):**
- Metinde liste yerine `{EticDurum.SiparisIptalIade}`. Başka değişiklik yok. `SatinalmaQueries.UrunDetay.cs:127`'ye dokunulmaz (bu görevin kapsamı dışında, T-027 sahibi).
**Adımlar:**
- [ ] Test: `EticDurum_SiparisIptalIade_SemaKodlariylaAyni` — `KaynakDosya.Oku("sema/codes.yaml")` içindeki `joker.J_ORDERS.STATUS` kaydının `net_iptal_iade` listesi sabite eşit (iki listeli metin karşılaştırma; sema değişirse kırmızı).
- [ ] Uygulama · kapılar: derleme · birim · koruma testi yeşil.
**Kabul:** koruma yeşil; `refactor`.

### T-027 [NET] MerkezDepoStok.CanliCte çıkarımı — rakamı değiştirmeyen refactor (R6) [P]
**Bağımlılık:** T-023 · **Test seviyesi:** hafif · **AC:** AC-8.1 (satınalma kısmı)
**Dosyalar:**
- Oluştur: `dashboard/Data/Tanimlar/MerkezDepoStok.cs`
- Değiştir: `dashboard/Data/SatinalmaQueries.cs` (`#depo` doldurma, satır ~225-228), `dashboard/Data/SatinalmaQueries.UrunDetay.cs` (`GetUrunOzetAsync` `DepoStok` alt sorgusu, satır ~38)
- Test: `tests/GmDashboard.Tests/Kanonik/H08SatinalmaTests.cs`
**Arayüzler:**
- Tüketir: `H08-merkez-depo.sql` blok A
- Üretir: `public static class MerkezDepoStok { public const string CanliCte = "SELECT d.stkID, CONVERT(int, SUM(d.Stok)) AS Merkez FROM DerinSISBkm.depo.stok_adres_palet_vw d WITH(NOLOCK) WHERE d.adrsAlanTipID IN (0, 1) GROUP BY d.stkID"; }` (kolonlar `stkID int, Merkez int`)
**Gereksinimler (tam değerlerle):** `#depo` = `SELECT c.stkID, c.Merkez AS d INTO #depo FROM (` + `CanliCte` + `) c WHERE c.stkID IN (SELECT stkID FROM #a)`. `UrunDetay` `DepoStok` = aynı parçadan `stkID = @id`. Davranış aynı.
**Adımlar:**
- [ ] Test (karakterizasyon, önce de yeşil): `GetUrunOzetAsync_Bugun_DepoStokCanliWmsEsit` — depo > 0 ilk 20 ürün (H08 blok A sırası) için `SatinalmaQueries.GetUrunOzetAsync(stkID).DepoStok` = blok A `Merkez`, birebir.
- [ ] Uygulama · kapılar: derleme · test (19:00 sonrası) · `panel_kolon_denetimi.py`.
**Kabul:** test önce ve sonra yeşil; `refactor`.

### T-028 [NET] FisTanimi davranış parçaları (fiş, iade sayısı, kanal)
**Bağımlılık:** T-025 · **Test seviyesi:** tam · **AC:** AC-5.1, AC-5.4, AC-13.2 (parça düzeyi)
**Dosyalar:**
- Değiştir: `dashboard/Data/Tanimlar/FisTanimi.cs`
- Test: `tests/GmDashboard.Tests/Kanonik/FisTanimiTests.cs`
**Arayüzler:**
- Tüketir: `H05-fis.sql` blok A, C; `H13-sinav-net.sql`
- Üretir (`FisTanimi`'ye eklenir):
  `public static string FisSayisi(string sales)` → `"COUNT(CASE WHEN {sales}.DocumentsTypeId = 1 AND gd.SalesId IS NULL THEN 1 END)"` · `public static string IadeSayisi(string sales)` → `"COUNT(CASE WHEN {sales}.DocumentsTypeId = 3 AND gd.SalesId IS NULL THEN 1 END)"` · `public static string KanalJoin(string sales)` → `"LEFT JOIN EncoreMerkez.dbo.Sales kn WITH(NOLOCK) ON kn.Id = {sales}.LinkedDocumentId AND {sales}.LinkedDocumentId > 0"` · `public static string SinavMi(string sales)` → `"({sales}.DocumentsTypeId = 8 OR ({sales}.DocumentsTypeId = 3 AND kn.DocumentsTypeId = 8))"`
**Gereksinimler (tam değerlerle):** `FisSayisi`/`IadeSayisi` kullanan sorgu `GeriDonusumHaricJoin` taşımak zorundadır; `SinavMi` kullanan `KanalJoin` taşımak zorundadır (XML belge yorumu).
**Adımlar:**
- [ ] Senaryo matrisi · kırmızı testler (`Tur=Kanonik`, `Hikaye=H05`/`H13`): `FisTanimi_FsmEylul2026_FisVeIadeSayisiKanonigeEsit` — test, parçalarla kurulmuş tek `SELECT` (mekân köprüsü + `GeriDonusumHaricJoin("s")` + `FisSayisi("s")`, `IadeSayisi("s")`) metnini `CanliDb` ile koşar ve H05 A/C'ye birebir karşılaştırır; `FisTanimi_SinavMi_Eylul2026SinavNetiKanonigeEsit` — `SUM(CASE WHEN SinavMi THEN NetKdvHaric END)` ↔ H13-sinav-net, ≤ 1,00 TL, mekân başına.
- [ ] Uygulama · kapılar.
**Kabul:** iki test yeşil.

### T-029 [NET] DuzeltmeNotlari ve TimeProvider kaydı
**Bağımlılık:** T-023 · **Test seviyesi:** tam · **AC:** AC-0.1, AC-0.2
**Dosyalar:**
- Oluştur: `dashboard/Data/Tanimlar/DuzeltmeNotlari.cs`
- Değiştir: `dashboard/ServiceRegistration.cs` (`AddBkmVeri` içine `s.AddSingleton(TimeProvider.System);`)
- Test: `tests/GmDashboard.Tests/Birim/DuzeltmeNotlariTests.cs`
**Arayüzler:**
- Üretir: `public static class DuzeltmeNotlari { public const int GorunurGun = 30; public static IReadOnlyDictionary<string, DateOnly> YayinTarihleri { get; } public static string? NotMetni(string gostergeAnahtari, DateOnly bugun); public static string? NotMetni(DateOnly yayin, DateOnly bugun); }`; DI'da `TimeProvider`
**Gereksinimler (tam değerlerle):**
- Sözlükte 20 anahtar, hepsi `DateOnly.MinValue` (yayında değil → not görünmez; gerçek tarih T-081'de): `sadakat.winback`, `sadakat.kartli-fis`, `trafik.fis`, `home.magaza-fis`, `home.magaza-net-kirilim`, `home.saat-kasiyer`, `magaza.kampanya`, `magaza.iade`, `magaza.upt`, `envanter.tedarikci`, `envanter.marj`, `envanter.abc`, `envanter.depo`, `odak.depo`, `odak.etic-talep`, `etic.kategori`, `sinav.odeme`, `mizan.nakit-kdv`, `musteri.rfm`, `hediye-ceki.barem`.
- `NotMetni`: anahtar yoksa `null`; `0 <= bugun.DayNumber - yayin.DayNumber <= 30` ise `"Hesap düzeltildi (" + yayin.ToString("dd.MM", CultureInfo.GetCultureInfo("tr-TR")) + ")"`; aksi `null` (yayından önceki gün de `null`).
- Sözlüğün bütün değerleri tek bir sabitten gelir: `private static readonly DateOnly Yayin = DateOnly.MinValue;` (T-081 yalnız bu satırı değiştirir).
- Gün hesabı ek bir public aşırı yüklemeyle test edilir: `public static string? NotMetni(DateOnly yayin, DateOnly bugun)`; anahtarlı sürüm bunu çağırır. (`InternalsVisibleTo` bu görevde gerekmez.)
**Adımlar:**
- [ ] İskelet · kırmızı testler: `NotMetni_YayindanSonra30Gun_Gorunur`, `NotMetni_YayindanSonra31Gun_Gorunmez`, `NotMetni_YayinGunu_GgAaBiciminde` (05.10.2026 → `"Hesap düzeltildi (05.10)"`), `NotMetni_YayindanOnce_Gorunmez`, `NotMetni_BilinmeyenAnahtar_Null`, `YayinTarihleri_YirmiAnahtar_EkranSozlesmesiyleAyni`.
- [ ] Uygulama · kapılar.
**Kabul:** altı test yeşil.

### T-030 [UI] DuzeltmeNotu bileşeni
**Bağımlılık:** T-029 · **Test seviyesi:** hafif · **AC:** AC-0.1, AC-0.2
**Dosyalar:**
- Oluştur: `dashboard/Components/Shared/DuzeltmeNotu.razor`
- Test: `tests/GmDashboard.Tests/Ekran/DuzeltmeNotuEkranTests.cs`
**Arayüzler:**
- Tüketir: `DuzeltmeNotlari.NotMetni(string, DateOnly)`, `TimeProvider`
- Üretir: `<DuzeltmeNotu Anahtar="…" />` (`[Parameter, EditorRequired] public string Anahtar { get; set; } = "";`)
**Gereksinimler (tam değerlerle):** `@inject TimeProvider Saat`; bugün = `DateOnly.FromDateTime(Saat.GetLocalNow().DateTime)`; metin `null` değilse `<span class="badge badge-ghost badge-sm">@metin</span>`, `null` ise hiçbir şey.
**Adımlar:**
- [ ] Test (kaynak metin): `DuzeltmeNotu_Kaynak_TimeProviderKullanirDateTimeNowKullanmaz` (`KaynakDosya.Oku` → `@inject TimeProvider` var, `DateTime.Now`/`DateTime.Today` yok).
- [ ] Uygulama · kapı: derleme.
**Kabul:** test yeşil.

### T-031 [NET] KullaniciMesajlari
**Bağımlılık:** T-023 · **Test seviyesi:** yok (gerekçe: davranışsız sabitler; metinleri T-057 ve T-059 testleri doğrular) · **AC:** AC-10.1, AC-8.4 (metin)
**Dosyalar:**
- Oluştur: `dashboard/Data/Tanimlar/KullaniciMesajlari.cs`
**Arayüzler:**
- Üretir: `public static class KullaniciMesajlari { public const string VeriAlinamadi = "Veriler şu anda alınamıyor. Sayfayı birkaç dakika sonra yenileyin; sorun sürerse sistem yöneticisine bildirin."; public const string KayitYapilamadi = "Eşik kaydedilemedi. Değerleri kontrol edip yeniden deneyin; sorun sürerse sistem yöneticisine bildirin."; public const string DonemdeKayitYok = "Bu dönemde kayıt yok."; public const string StokGoruntusuYok = "Bu ay için stok görüntüsü yok."; }`
**Adımlar:** [ ] Yaz · kapılar: derleme, `turkce_tanimlayici_denetimi.py`.
**Kabul:** derleme yeşil.

# F3 — P1

### T-032 [NET] H1 Kumbara ve manuel indirim fiş başına tekil
**Bağımlılık:** T-024 · **Test seviyesi:** tam · **AC:** AC-1.1, AC-1.2, AC-1.3, AC-1.4
**Dosyalar:**
- Değiştir: `dashboard/Data/RefQueries.cs` (`GetManuelIndirimAsync`, `GetKumbaraAsync`)
- Test: `tests/GmDashboard.Tests/Kanonik/H01Tests.cs`
**Arayüzler:**
- Tüketir: `H01-kumbara-manuel.sql` A, B, C
- Üretir: `Task<IReadOnlyList<KumbaraAyRow>> GetKumbaraAsync(CancellationToken ct = default)` · `Task<IReadOnlyList<ManuelIndirimRow>> GetManuelIndirimAsync(CancellationToken ct = default)` — kayıtlar değişmez (`Sebep`, `Magaza`, `Ay` `yyyy-MM`, `Brut`, `Indirim`, `FisSayisi`)
**Gereksinimler (tam değerlerle):**
- Fiş kümesi `EXISTS` ile: Kumbara `sp.IsValid = 1 AND spc.CampaignId IS NULL AND spc.CampaignVersion = 17`; manuel `… AND rr.Type = 1` (tekillik `(Sebep, fiş)`). Toplam o kümeden başlık değerleriyle bir kez; `DocumentsTypeId = 3` negatif (`Brut`, `Indirim`). `DocumentsTypeId IN (1,2,3,6,7,8)`.
- Mağaza köprüsü `mg.mekanKod COLLATE Turkish_CI_AS = st.Code COLLATE Turkish_CI_AS`.
- Tarih: `WHERE CONVERT(date, s.[Date]) >= '20260101'` → `s.[Date] >= @YilBas`, `@YilBas = new DateTime(2026, 1, 1)` (değer aynı).
- AC-1.4: Razor dosyasına dokunulmaz; `Operasyon.razor` yüklemeye devam eder.
**Adımlar:**
- [ ] Senaryo matrisi · kırmızı testler: `GetKumbaraAsync_Eylul2026_BrutFisBasinaTekilKanonigeEsit` (`Ay = "2026-09"` satırları Σ ↔ A, mağaza başına ≤ 1,00 TL), `GetManuelIndirimAsync_Eylul2026_IndirimKanonigeEsit` (sebep × mağaza ↔ B), `GetKumbaraAsync_Eylul2026_IndirimKanonigeEsit`, `GetManuelIndirimAsync_IadeliKampanya_IadeDusulur` (C nüfusu `Nufus.EnAz`; nüfus 0 → KOŞAMADI).
- [ ] Uygulama · kapılar: derleme · H01 testleri · koruma · `panel_kolon_denetimi.py`.
**Kabul:** dört test yeşil (ya da AC-1.3 "KOŞAMADI: nüfus 0" raporlu); `git diff --stat` Razor içermez.

### T-033 [NET] H2 win-back koşulu ve tanecik
**Bağımlılık:** T-029 · **Test seviyesi:** tam · **AC:** AC-2.1, AC-2.2, AC-2.3, AC-2.4, SC-003
**Dosyalar:**
- Değiştir: `dashboard/Data/SadakatQueries.cs` (`GetWinBackAsync`), `dashboard/Models/RefModels.cs` (`WinBackRow`), `dashboard/Components/Pages/Sadakat.razor` (**yalnız** çağrı satırı ~217 ve `@inject TimeProvider Saat` — derleme zorunluluğu)
- Test: `tests/GmDashboard.Tests/Kanonik/H02Tests.cs`
**Arayüzler:**
- Tüketir: `H02-winback.sql` A–D; `IcKartFiltre`; `TimeProvider`
- Üretir: `Task<IReadOnlyList<WinBackRow>> GetWinBackAsync(DateOnly bugun, CancellationToken ct = default)` · `public record WinBackRow(string Ad, string Tel, string Kart, int Frq, decimal ToplCiro, int GunIdle, long MusteriId);`
**Gereksinimler (tam değerlerle):** `kontratlar/sorgu-metodlari.md` § H2 aynen: `CustomersId > 0`, iç kart hariç, `[bugun−365, bugun)` en az bir satış fişi, `[bugun−90, bugun)` `NOT EXISTS` satış fişi, `Frq` yalnız `DocumentsTypeId = 1`, `ToplCiro` `(1,3)` KDV hariç iade negatif, `Frq >= 3`, `ToplCiro >= 500`, `GunIdle = DATEDIFF(DAY, tüm zaman son satış fişi, @Bugun)`, `GROUP BY s.CustomersId`, `ORDER BY ToplCiro DESC, MusteriId`, `TOP 200`. `GETDATE()` yok, `@Bugun` parametre. Ad/telefon/kart `DerinCrm.dbo.Customer` (`Customer.Id = Sales.CustomersId`).
- Çağrı: `Sada.GetWinBackAsync(DateOnly.FromDateTime(Saat.GetLocalNow().DateTime))`.
**Adımlar:**
- [ ] Kırmızı testler (`@Bugun` = test günü, iki taraf aynı): `GetWinBackAsync_Bugun_Son90GunAlisverisYapanYok` (A ile kesişim 0), `GetWinBackAsync_Bugun_GunIdleSonSatisFisindenVe90Ustu` (B), `GetWinBackAsync_IadeliMusteri_FrekansIadeSaymaz` (C), `GetWinBackAsync_Bugun_KanonikListeyleAyniKume` (D), `GetWinBackAsync_SonSatisTam90GunOnce_ListedeYok` (İnceleme odağı 3: min `GunIdle` ≥ 91 ve B'de `SonSatis = @Bugun − 90` olanlar listede yok). Hata mesajında yalnız sayı + ilk 3 kimlik.
- [ ] Uygulama · kapılar.
**Kabul:** beş test yeşil; kesişim 0 (SC-003).

### T-034 [UI] H2 Sadakat win-back açıklaması
**Bağımlılık:** T-033, T-030 · **Test seviyesi:** hafif · **AC:** AC-2.2 (gösterim), AC-0.1
**Dosyalar:**
- Değiştir: `dashboard/Components/Pages/Sadakat.razor`
- Test: `tests/GmDashboard.Tests/Ekran/H02EkranTests.cs`
**Arayüzler:**
- Tüketir: `WinBackRow`, `<DuzeltmeNotu Anahtar="sadakat.winback" />`, `KullaniciMesajlari.DonemdeKayitYok`
**Gereksinimler (tam değerlerle):** açıklama "Son 365 günde alışveriş yapmış, son 90 günde satış fişi olmayan müşteriler."; "Son alışveriş" kolonu `GunIdle` (gün); `MusteriId` gösterilmez; liste boşsa `DonemdeKayitYok`.
**Adımlar:** [ ] Test (kaynak metin): `Sadakat_Kaynak_WinBackNotuVeAciklamaVar`. [ ] Uygulama · kapı: derleme.
**Kabul:** test yeşil.

### T-035 [NET] H3 tedarikçi karnesi merkez depo canlı WMS
**Bağımlılık:** T-027, T-033 · **Test seviyesi:** tam · **AC:** AC-3.1, AC-3.2, AC-3.4
**Dosyalar:**
- Değiştir: `dashboard/Data/RefQueries.Envanter.cs` (`GetTedarikciPerformansAsync`), `dashboard/Models/RefModels.cs` (`TedarikciPerfRow`)
- Test: `tests/GmDashboard.Tests/Kanonik/H03Tests.cs`
**Arayüzler:**
- Tüketir: `MerkezDepoStok.CanliCte`; `H03-tedarikci-depo.sql` A, B, D
- Üretir: `Task<IReadOnlyList<TedarikciPerfRow>> GetTedarikciPerformansAsync(DateOnly bas, IReadOnlyList<int> haricMrk, CancellationToken ct = default)` · `public record TedarikciPerfRow(string Marka, int SatisAdet, int IadeAdet, decimal NetCiro, decimal SatisBrut, decimal IadeTutar, int StokAdet, int MrkId, int MagazaStokAdet, int DepoStokAdet)` (mevcut kayıt gövdesi korunur)
**Gereksinimler (tam değerlerle):** `kontratlar/sorgu-metodlari.md` § H3: `MagazaStokAdet` `stokSonAltDepo_vw` `ehAltDepo = 0`, `stok > 0`, `ehMekan IN (LokasyonConfig.Subeler)`; `DepoStokAdet` `CanliCte` → `urn.urnMrkID`; `StokAdet = MagazaStokAdet + DepoStokAdet`. Satış alt sorgusu değişmez.
**Adımlar:**
- [ ] Kırmızı testler: `GetTedarikciPerformansAsync_HerMarka_DepoCanliWmsEsit`, `GetTedarikciPerformansAsync_Toplam_WmsToplaminaEsit`, `GetTedarikciPerformansAsync_MagazaStok_Degismez` (D'ye birebir; `bas` = `new DateOnly(2025,10,3)` ve `haricMrk = PanelAyarlar.VarsayilanHaricMarkalar`).
- [ ] Uygulama · kapılar.
**Kabul:** üç test yeşil.

### T-036 [UI] H3 Envanter karnesi dipnotu
**Bağımlılık:** T-035, T-030 · **Test seviyesi:** hafif · **AC:** AC-3.1 (gösterim), AC-0.1
**Dosyalar:**
- Değiştir: `dashboard/Components/Pages/Envanter.razor`
- Test: `tests/GmDashboard.Tests/Ekran/H03EkranTests.cs`
**Gereksinimler (tam değerlerle):** stok kolonu dipnotu "Stok: mağazalar + merkez depo (WMS, raf ve giriş alanı)."; `<DuzeltmeNotu Anahtar="envanter.tedarikci" />`; karne boşsa `DonemdeKayitYok`.
**Adımlar:** [ ] Test (kaynak metin): `Envanter_Kaynak_TedarikciNotuVeDipnotVar`. [ ] Uygulama · derleme.
**Kabul:** test yeşil.

# F4 — P2 (H13 Queries kısmı kayıt sırası gereği burada)

### T-037 [NET] H4 e-ticaret kategori karması iptal/iade hariç
**Bağımlılık:** T-026, T-029 · **Test seviyesi:** tam · **AC:** AC-4.1, AC-4.2
**Dosyalar:**
- Değiştir: `dashboard/Data/EticQueries.cs` (`GetEticKategoriAsync`, `GetEticKategoriUrunAsync`, `GetEticKategoriYilAsync`, kurucuya `TimeProvider`)
- Test: `tests/GmDashboard.Tests/Kanonik/H04EticTests.cs`
**Arayüzler:**
- Tüketir: `EticDurum.SiparisIptalIade`; `H04-etic-kategori.sql` A, B
- Üretir: üç metot aynı imza + `CancellationToken ct = default`; `EticKategoriRow(string Kategori, int Siparis, decimal NetCiro, int Adet)` aynı
**Gereksinimler (tam değerlerle):** üç sorguya `o.STATUS NOT IN ({EticDurum.SiparisIptalIade})`. `Kategori = NULL` satırı döndürülmez. `GetEticKategoriYilAsync` içinde `DateTime.Today` → `TimeProvider.GetLocalNow()`.
**Adımlar:**
- [ ] Kırmızı test: `GetEticKategoriAsync_Eylul2026_AnaCiroyaEsit` — panel Σ + kanonik A'daki `Kategori IS NULL` satırı = B net (≤ 1,00 TL); sipariş: panel Σ `Siparis` ile A'nın NULL satırı birlikte B sipariş kümesine birebir (sipariş birden çok kategoride ise kanonik A tekilleştirme kuralı başlıkta yazılı olanla).
- [ ] Uygulama · kapılar.
**Kabul:** test yeşil.

### T-038 [NET] H4 ODAK e-ticaret talebi başlık + satır kuralı [P]
**Bağımlılık:** T-026 · **Test seviyesi:** tam · **AC:** AC-4.3
**Dosyalar:**
- Değiştir: `dashboard/Data/OdakQueries.cs` (`ecom` CTE'si olan `GetOdakKpiAsync`, `GetOdakAsiriAsync`, `GetUrunlerAsync`, `GetUsulsuzAsync`)
- Test: `tests/GmDashboard.Tests/Kanonik/H04OdakTalepTests.cs`
**Arayüzler:**
- Tüketir: `EticDurum.SiparisIptalIade`, `EticDurum.SatirIptalIade`; `H04-odak-talep.sql` A
- Üretir: dört metot aynı imza + `CancellationToken ct = default`; kayıtlar aynı
**Gereksinimler (tam değerlerle):** OPENQUERY metnine `AND o.STATUS NOT IN ({SiparisIptalIade}) AND d.STATUS NOT IN ({SatirIptalIade})`. `ent.odak_depo_Stok` değişmez.
**Adımlar:**
- [ ] Kırmızı test: `OdakEticTalep_Eylul2026_IptalIadeHaricAdeteEsit` — `GetUrunlerAsync` e-tic talep kolonu ↔ A, ürün başına birebir (ilk 50 ürün).
- [ ] Uygulama · kapılar.
**Kabul:** test yeşil.

### T-039 [UI] H4 notları
**Bağımlılık:** T-037, T-038, T-030 · **Test seviyesi:** hafif · **AC:** AC-4.1, AC-4.3 (gösterim), AC-0.1
**Dosyalar:**
- Değiştir: `dashboard/Components/Pages/Eticaret.razor`, `dashboard/Components/Pages/OdakStok.razor`
- Test: `tests/GmDashboard.Tests/Ekran/H04EkranTests.cs`
**Gereksinimler (tam değerlerle):** `Eticaret.razor` kategori karması/detay/yıllık grafik başlıklarında `<DuzeltmeNotu Anahtar="etic.kategori" />`, boş listede `DonemdeKayitYok`; `OdakStok.razor` e-tic talep kolonunda `<DuzeltmeNotu Anahtar="odak.etic-talep" />`.
**Adımlar:** [ ] Test (kaynak metin): `Eticaret_Kaynak_KategoriNotuVar`, `OdakStok_Kaynak_EticTalepNotuVar`. [ ] Uygulama · derleme.
**Kabul:** testler yeşil.

### T-040 [NET] H13 mağaza neti perakende/Sınav kırılımı ve hedef notu
**Bağımlılık:** T-028, T-026 · **Test seviyesi:** tam · **AC:** AC-13.1, AC-13.2, AC-13.3, AC-13.4, AC-13.5, FR-016
**Dosyalar:**
- Değiştir: `dashboard/Data/Queries.cs` (`storeSql`, `StoreCard` kurulumu), `dashboard/Models/PeriodModels.cs` (`StoreRow`, `StoreCard`)
- Oluştur: `dashboard/Data/Tanimlar/HedefTabani.cs`
- Test: `tests/GmDashboard.Tests/Kanonik/H13Tests.cs`, `tests/GmDashboard.Tests/Birim/HedefTabaniTests.cs`
**Arayüzler:**
- Tüketir: `FisTanimi.KanalJoin`, `SinavMi`, `NetKdvHaric`; `H13-sinav-net.sql`, `H13-sube-cirosu.sql`
- Üretir: `public record StoreRow(int MekanId, decimal Net, int Fis, decimal Iade, decimal NetPerakende, decimal NetSinav);` · `public record StoreCard(int MekanId, string Ad, decimal Net, int Fis, int Atv, decimal? GerPct, decimal Iade, IReadOnlyList<CategorySlice> Kategori, decimal? Wow = null, decimal NetPerakende = 0, decimal NetSinav = 0);` · `public static class HedefTabani { public const bool Teyitli = false; public const string TeyitBekliyorNotu = "Hedef tabanı teyit bekliyor"; public static string? NotMetni(bool teyitli); }` (`teyitli` → `null`, değilse not)
**Gereksinimler (tam değerlerle):**
- `storeSql`'e `KanalJoin("s")`; `NetPerakende = SUM(CASE WHEN NOT {SinavMi} THEN {NetKdvHaric} ELSE 0 END)`, `NetSinav = SUM(CASE WHEN {SinavMi} THEN {NetKdvHaric} ELSE 0 END)`; SELECT sırası `MekanId, Net, Fis, Iade, NetPerakende, NetSinav`. `Net` değişmez.
- Karar: kontrat kayıt sırası (`NetPerakende, NetSinav, IadeSayisi`) gereği H13 alanları H5'ten (T-041) önce eklenir.
**Adımlar:**
- [ ] Kırmızı testler: `GetPeriodAsync_Eylul2026_PerakendeArtiSinavToplamaEsit` (her mağaza ≤ 1,00 TL), `GetPeriodAsync_Eylul2026_SinavNetiKanonigeEsit`, `GetPeriodAsync_Eylul2026_ToplamKanonikSubeCirosunaYakin` (`Tolerans.OranIcinde`, %0,30), birim `HedefNotu_Teyitsiz_NotDoner`, `HedefNotu_Teyitli_NotYok`.
- [ ] Uygulama · kapılar: + koruma testi yeşil + `panel_kolon_denetimi.py`.
**Kabul:** beş test yeşil, koruma yeşil.

### T-041 [NET] H5 Ana sayfa ve Trafik kanonik fiş, iade sayısı
**Bağımlılık:** T-040 · **Test seviyesi:** tam · **AC:** AC-5.1, AC-5.2, AC-5.4, SC-004 · **Yayın grubu:** Y-FIS
**Dosyalar:**
- Değiştir: `dashboard/Data/Queries.cs` (`storeSql` `Fis` + `IadeSayisi`; `PeriodSummary.Fis` toplamı), `dashboard/Models/PeriodModels.cs` (`StoreRow`, `StoreCard`, `TrafikKpi`), `dashboard/Data/TrafikQueries.cs` (`GetKpiAsync`, `GetHeatAsync`, `GetPersonelAsync`, `GetGunlukAsync`)
- Test: `tests/GmDashboard.Tests/Kanonik/H05AnaSayfaTrafikTests.cs`
**Arayüzler:**
- Tüketir: `FisTanimi.FisSayisi`, `IadeSayisi`, `GeriDonusumHaricJoin`; `H05-fis.sql` A, C
- Üretir: `StoreRow(int MekanId, decimal Net, int Fis, decimal Iade, decimal NetPerakende, decimal NetSinav, int IadeSayisi)` · `StoreCard(…, decimal NetPerakende = 0, decimal NetSinav = 0, int IadeSayisi = 0)` · `public record TrafikKpi(int Ziyaretci, int Fis, decimal Net, int Kasiyer, int IadeSayisi);` · `Task<TrafikKpi> GetKpiAsync(DateOnly bas, DateOnly bit, CancellationToken ct = default)`; diğer üç Trafik metodu aynı imza + `ct`
**Gereksinimler (tam değerlerle):** `Fis = FisSayisi("s")`; `IadeSayisi = IadeSayisi("s")`; Trafik `Net`, `Kasiyer` kapsamı değişmez; ısı haritası `DailyFis`, personel `Fis`, günlük `Fis` aynı ifade. `Fis` artık satış − iade değildir.
**Adımlar:**
- [ ] Kırmızı testler: `FisSayisi_FsmEylul2026_DortGostergeKanonigeEsit` (`StoreRow.Fis` mekân 1, `TrafikKpi.Fis`, Σ ısı haritası günlük fiş, Σ personel `Fis` ↔ H05 A, birebir), `TrafikKpi_Donusum_KanonikFisKullanir` (`Fis` = A), `IadeSayisi_AnaSayfaTrafik_FsmEylul2026_KanonigeEsit` (`StoreRow.IadeSayisi`, `TrafikKpi.IadeSayisi` ↔ C = 947 referansı).
- [ ] Uygulama · kapılar (+ koruma, `panel_kolon_denetimi.py`).
**Kabul:** üç test yeşil; koruma yeşil.

### T-042 [NET] H5 Sadakat kartlı/kartsız fiş sayısı
**Bağımlılık:** T-033, T-028 · **Test seviyesi:** tam · **AC:** AC-5.3 · **Yayın grubu:** Y-FIS
**Dosyalar:**
- Değiştir: `dashboard/Data/SadakatQueries.cs` (`GetKartliAsync`)
- Test: `tests/GmDashboard.Tests/Kanonik/H05SadakatTests.cs`
**Arayüzler:**
- Tüketir: `FisTanimi.FisSayisi`, `GeriDonusumHaricJoin`; `H05-fis.sql` B
- Üretir: `GetKartliAsync(…, CancellationToken ct = default)`; `KartliRow(string Tip, int FisSayisi, int Musteri, decimal NetCiro, decimal AtvFis)` aynı
**Gereksinimler (tam değerlerle):** `FisSayisi` kanonik (yalnız satış fişi, 1001 hariç); `NetCiro` `(1,3)` iade düşülmüş, değişmez; `AtvFis = NetCiro / FisSayisi`.
**Adımlar:** [ ] Kırmızı test `GetKartliAsync_FisSayisiIadeIcermez` (B'ye birebir, kartlı ve kartsız). [ ] Uygulama · kapılar.
**Kabul:** test yeşil.

### T-043 [NET] H5 Mağaza detay fiş ve iade sayısı
**Bağımlılık:** T-041 · **Test seviyesi:** tam · **AC:** AC-5.4 · **Yayın grubu:** Y-FIS
**Dosyalar:**
- Değiştir: `dashboard/Data/MagazaQueries.cs` (`GetDetayAsync` `kpiSql` `Fis` + `IadeSayisi`), `dashboard/Models/MagazaModels.cs` (`MagazaDetay` sona `int IadeSayisi`)
- Test: `tests/GmDashboard.Tests/Kanonik/H05MagazaTests.cs`
**Arayüzler:**
- Tüketir: `FisTanimi.FisSayisi`, `IadeSayisi`; `StoreRow.IadeSayisi`, `TrafikKpi.IadeSayisi` (T-041); `H05-fis.sql` C
- Üretir: `Task<MagazaDetay?> GetDetayAsync(int mid, DateOnly start, DateOnly endExcl, CancellationToken ct = default)`; `MagazaDetay(…, int IadeSayisi)`
**Adımlar:**
- [ ] Kırmızı test `IadeSayisi_FsmEylul2026_KanonigeEsit` — `StoreRow.IadeSayisi`, `TrafikKpi.IadeSayisi`, `MagazaDetay.IadeSayisi` üçü eşit ve C'ye birebir.
- [ ] Uygulama · kapılar.
**Kabul:** test yeşil.

### T-044 [NET] H5 Sabah özeti kanonik fiş
**Bağımlılık:** T-028 · **Test seviyesi:** tam · **AC:** FR-005 (Sabah) · **Yayın grubu:** Y-FIS
**Dosyalar:**
- Değiştir: `dashboard/Data/SabahService.cs` (gün sorgusu `Fis`, satır ~56)
- Test: `tests/GmDashboard.Tests/Kanonik/H05SabahTests.cs`
**Arayüzler:**
- Tüketir: `FisTanimi.FisSayisi`, `GeriDonusumHaricJoin`; `H05-fis.sql` A (`@Bas = dün`, `@Bit = bugün`, `@MekanId`)
- Üretir: `MagazaGunSatir(string Ad, decimal Net, int Fis, …)` aynı; `Fis` anlamı kanonik
**Gereksinimler (tam değerlerle):** mevcut `spb` anti-join'i `GeriDonusumHaricJoin` ile değiştirilir; `Net` değişmez.
**Adımlar:** [ ] Kırmızı test `SabahService_Dun_FisKanonikTanimaEsit` (her mağaza, `LokasyonConfig.Mekan` adıyla eşlenir). [ ] Uygulama · kapılar.
**Kabul:** test yeşil.

### T-045 [UI] H13 Ana sayfa net kırılımı ve hedef notu
**Bağımlılık:** T-040, T-030 · **Test seviyesi:** hafif · **AC:** AC-13.1, AC-13.4, AC-13.5 (gösterim), AC-0.1
**Dosyalar:**
- Değiştir: `dashboard/Components/Pages/Home.razor`
- Test: `tests/GmDashboard.Tests/Ekran/H13EkranTests.cs`
**Gereksinimler (tam değerlerle):** mağaza kartı net bölümü üç satır: "Perakende" (`NetPerakende`), "Sınav Okulları" (`NetSinav`; 0 ise "—"), kalın "Toplam" (`Net`) (İnsan onayı 8); `<DuzeltmeNotu Anahtar="home.magaza-net-kirilim" />`; hedef kartı başlığı altında `HedefTabani.NotMetni(HedefTabani.Teyitli)` null değilse `<p class="text-warning text-xs">`.
**Adımlar:** [ ] Test (kaynak metin): `Home_Kaynak_UcSatirVeHedefNotuVar`. [ ] Uygulama · derleme.
**Kabul:** test yeşil.

### T-046 [UI] H5 fiş ve iade gösterimi
**Bağımlılık:** T-045, T-041, T-042, T-043, T-044, T-034 · **Test seviyesi:** hafif · **AC:** AC-5.1, AC-5.2, AC-5.3, AC-5.4 (gösterim), AC-0.1, SC-004 · **Yayın grubu:** Y-FIS
**Dosyalar:**
- Değiştir: `dashboard/Components/Pages/Home.razor`, `Trafik.razor`, `Sadakat.razor`, `Magaza.razor`
- Test: `tests/GmDashboard.Tests/Ekran/H05EkranTests.cs`
**Gereksinimler (tam değerlerle):**
- Home: fiş sayısının yanında "İade: N" (`StoreCard.IadeSayisi`); `<DuzeltmeNotu Anahtar="home.magaza-fis" />`.
- Trafik: KPI'da ayrı "İade" değeri; Dönüşüm = Fis ÷ Ziyaretçi; Sepet = Net ÷ Fis; dipnot "Fiş: yalnız perakende satış fişi. İade, fatura, personel ve Sınav Okulları belgesi sayılmaz."; `<DuzeltmeNotu Anahtar="trafik.fis" />`.
- Sadakat kartlı tablo dipnotu "Fiş: yalnız satış fişi. Ciro iadeler düşülmüş olarak."; `<DuzeltmeNotu Anahtar="sadakat.kartli-fis" />`.
- Magaza: fiş yanında "İade: N" (`MagazaDetay.IadeSayisi`).
**Adımlar:** [ ] Test (kaynak metin, teori 4 dosya). [ ] Uygulama · derleme.
**Kabul:** test yeşil.

### T-047 [NET] H6 mağaza detay kampanya, iade, UPT, ısı haritası
**Bağımlılık:** T-043 · **Test seviyesi:** tam · **AC:** AC-6.1, AC-6.2, AC-6.3, AC-6.4 · **Yayın grubu:** Y-FIS (UPT/ısı)
**Dosyalar:**
- Değiştir: `dashboard/Data/MagazaQueries.cs` (`kpiSql`, `uptSql`, `kampSql` `ind` CTE, `GetHeatmapAsync`)
- Test: `tests/GmDashboard.Tests/Kanonik/H06Tests.cs`
**Arayüzler:**
- Tüketir: `FisTanimi.FisSayisi`, `IadeKdvHaric`, `GeriDonusumHaricJoin`; `StoreCard.Iade` (T-041); `H06-magaza.sql` A–D
- Üretir: `GetDetayAsync(int mid, DateOnly start, DateOnly endExcl, CancellationToken ct = default)` · `Task<IReadOnlyList<HeatCell>> GetHeatmapAsync(int mid, DateOnly dun, int gun = 60, CancellationToken ct = default)`
**Gereksinimler (tam değerlerle):** `kontratlar/sorgu-metodlari.md` § H6 aynen: `Iade = IadeKdvHaric`; `IadeOran = 100 × Iade / satış neti (1,2,6,7,8 için Gross − Discount − Vat)`; UPT pay `SUM(sp.Amount)` (`IsValid = 1`) payda `FisSayisi`, yalnız tip 1, 1001 hariç; kampanya join `sp.SalesId = spc.SalesId AND sp.[Sequence] = spc.ProductSequence AND sp.IsValid = 1`; kampanya tablosu KDV dahil kalır (İnsan onayı 7); ısı haritası `COUNT(*)` → `FisSayisi`.
**Adımlar:**
- [ ] Kırmızı testler (üç mağaza teori): `GetDetayAsync_IptalKalem_KampanyaIndirimineGirmez`, `GetDetayAsync_Kampanya_BrutEksiIndirimNeteEsit`, `Iade_AnaSayfaVeMagazaDetay_AyniTaban`, `GetDetayAsync_IstYoluUpt_KanonikFisTabaninda`, `GetHeatmapAsync_IstYolu_FisToplamiKanonikFiseEsit`.
- [ ] Uygulama · kapılar.
**Kabul:** testler yeşil.

### T-048 [UI] H6 mağaza detay etiketleri
**Bağımlılık:** T-047, T-046 · **Test seviyesi:** hafif · **AC:** AC-6.2, AC-6.3, AC-6.4 (gösterim), AC-0.1
**Dosyalar:**
- Değiştir: `dashboard/Components/Pages/Magaza.razor`
- Test: `tests/GmDashboard.Tests/Ekran/H06EkranTests.cs`
**Gereksinimler (tam değerlerle):** iade ve iade oranı etiketi "(KDV hariç, indirim düşülmüş)"; kampanya başlığı "Kampanya yükü (KDV dahil)"; UPT dipnotu "Yalnız perakende satış fişleri."; notlar `magaza.kampanya`, `magaza.iade`, `magaza.upt`.
**Adımlar:** [ ] Test (kaynak metin). [ ] Uygulama · derleme.
**Kabul:** test yeşil.

### T-049 [NET] H7 kategori marjı ve ABC iade düşülmüş
**Bağımlılık:** T-035, T-032 · **Test seviyesi:** tam · **AC:** AC-7.1, AC-7.2, AC-7.3
**Dosyalar:**
- Değiştir: `dashboard/Data/RefQueries.Envanter.cs` (`GetMarjAsync`, yeni `GetMarjKategoriAsync`), `dashboard/Data/RefQueries.cs` (`GetInventoryAsync` içindeki `tAbc`), `dashboard/Models/RefModels.cs` (`MarjRow`)
- Test: `tests/GmDashboard.Tests/Kanonik/H07Tests.cs`
**Arayüzler:**
- Tüketir: `H07-marj-abc.sql` A, B
- Üretir: `Task<IReadOnlyList<MarjRow>> GetMarjKategoriAsync(DateOnly bas, DateOnly bit, CancellationToken ct = default)` · `Task<IReadOnlyList<MarjRow>> GetMarjAsync(CancellationToken ct = default)` · `public record MarjRow(string Kategori, decimal Ciro, decimal Smm, decimal MarjPct, decimal CiroMaliyetli);` · `AbcClass(string Sinif, int Adet, decimal Ciro)` aynı
**Gereksinimler (tam değerlerle):** `kontratlar/sorgu-metodlari.md` § H7 aynen (`irsHrk` ehTip 4,100 + / 5,101 −, üç mağaza, `ehAltDepo = 0`, adet `−ehAdetN`, `'(kategorisiz)'` satırı, `MarjPct = (CiroMaliyetli − Smm) / CiroMaliyetli`, görüntü süzgeci %5–%95 yalnız `GetMarjAsync`'te; ABC `DocumentsTypeId IN (1,2,3,6,7,8)` iade negatif, `HAVING > 0`).
**Adımlar:**
- [ ] Kırmızı testler: `GetMarjKategoriAsync_Eylul2026MuhasebeAcikDonem_KanonikSubeCirosunaEsit` (Σ Ciro ↔ A, ≤ 1,00 TL), `Abc_Eylul2026_IadeDusulmusCiroyaEsit` (Σ sınıf cirosu ↔ B).
- [ ] Uygulama · kapılar.
**Kabul:** iki test yeşil.

### T-050 [UI] H7 Envanter marj ve ABC notları
**Bağımlılık:** T-049, T-036 · **Test seviyesi:** hafif · **AC:** AC-7.1, AC-7.3 (gösterim), AC-0.1
**Dosyalar:**
- Değiştir: `dashboard/Components/Pages/Envanter.razor`
- Test: `tests/GmDashboard.Tests/Ekran/H07EkranTests.cs`
**Gereksinimler (tam değerlerle):** notlar `envanter.marj`, `envanter.abc`; marj dipnotu "Üç mağazanın perakende satışı, iadeler düşülmüş. Maliyet muhasebede kesinleşmemiş olabilir."; marj boşsa `DonemdeKayitYok`.
**Adımlar:** [ ] Test (kaynak metin). [ ] Uygulama · derleme.
**Kabul:** test yeşil.

### T-051 [NET] H8 Envanter merkez depo canlı WMS
**Bağımlılık:** T-049, T-027 · **Test seviyesi:** tam · **AC:** AC-8.1 (Envanter), AC-3.3 · **Yayın grubu:** Y-DEPO
**Dosyalar:**
- Değiştir: `dashboard/Data/RefQueries.Envanter.cs` (`GetKategoriCesitAsync`, `GetUrunlerAsync` `wms`, `OluStokSql`, `GetOluStokAsync` sayım)
- Test: `tests/GmDashboard.Tests/Kanonik/H08EnvanterTests.cs`
**Arayüzler:**
- Tüketir: `MerkezDepoStok.CanliCte`; `H08-merkez-depo.sql` A; `H03-tedarikci-depo.sql` C
- Üretir: dokunulan metotlar aynı imza + `CancellationToken ct = default`
**Gereksinimler (tam değerlerle):** kategori çeşit depo kolonu ve `wms` alt sorguları `CanliCte`; `StokAyBakiyeMekanBazli … MAX(Donem)` ve `paletUrnTnm` + elle liste (`'CK01'`, `'42560'`, `'20353'`) bu metotlardan kaldırılır.
**Adımlar:**
- [ ] Kırmızı testler: `GetKategoriCesitAsync_Bugun_DepoCanliWmsEsit`, `GetOluStokAsync_Bugun_DepoBileseniCanliWmsEsit` (ilk 50 satır), `MerkezDepo_KarneVeKategoriCesit_AyniKaynak` (H03 C'deki 20 ürünün kategori toplamları iki yoldan eşit).
- [ ] Uygulama · kapılar.
**Kabul:** üç test yeşil.

### T-052 [NET] H8 ODAK merkez depo canlı WMS
**Bağımlılık:** T-038, T-051 · **Test seviyesi:** tam · **AC:** AC-8.1 (ODAK), AC-8.2 · **Yayın grubu:** Y-DEPO
**Dosyalar:**
- Değiştir: `dashboard/Data/OdakQueries.cs` (`depo` CTE'si)
- Test: `tests/GmDashboard.Tests/Kanonik/H08OdakTests.cs`
**Arayüzler:**
- Tüketir: `MerkezDepoStok.CanliCte`; `H08-merkez-depo.sql` A
- Üretir: `OdakUrun.Mrkz` anlamı canlı WMS
**Gereksinimler (tam değerlerle):** `depo` CTE = `CanliCte`; `MAX(Donem)` ve `StokAyBakiyeMekanBazli` okuması kaldırılır; canlı okuma hata verirse istisna yukarı fırlar (ay sonuna geçiş yok).
**Adımlar:**
- [ ] Kırmızı testler: `MerkezDepo_BugunEkranlar_CanliWmsEsit` (ODAK, kategori çeşit, ölü stok, satınalma depo değerleri aynı dakika içinde A'ya birebir), `OdakQueries_Kaynak_AySonuGoruntusuOkumaz` (kaynak metinde `StokAyBakiyeMekanBazli` ve `MAX(Donem)` yok).
- [ ] Uygulama · kapılar.
**Kabul:** iki test yeşil.

### T-053 [NET] H8 geçmiş ay merkez depo ay sonu görüntüsü (KB-1)
**Bağımlılık:** T-027, T-031, T-001 (blok J) · **Test seviyesi:** tam · **AC:** AC-8.3, AC-8.4
**Dosyalar:**
- Değiştir: `dashboard/Data/Tanimlar/MerkezDepoStok.cs`
- Test: `tests/GmDashboard.Tests/Kanonik/H08AySonuTests.cs`
**Arayüzler:**
- Tüketir: `H08-merkez-depo.sql` B, C
- Üretir: `MerkezDepoStok`'a: `public const string AySonuCte = "SELECT b.stkID, CONVERT(int, SUM(b.Stok)) AS Merkez FROM DerinSISBkm.bkm.StokAyBakiyeMekanBazli b WITH(NOLOCK) WHERE b.Kaynak = 'WMS' AND b.ehMekan = 12 AND b.Donem = @Donem GROUP BY b.stkID";` · `public const string AySonuVarMiSql = "SELECT CASE WHEN EXISTS (SELECT 1 FROM DerinSISBkm.bkm.StokAyBakiyeMekanBazli WITH(NOLOCK) WHERE Kaynak = 'WMS' AND ehMekan = 12 AND Donem = @Donem) THEN 1 ELSE 0 END";`
**Gereksinimler (tam değerlerle):**
- **KB-1 (rapora bakın):** koda göre bugün hiçbir ekran geçmiş ay merkez depo bakiyesi göstermiyor (`#bal` ve `GetSubeSezonAsync` `Kaynak = 'irsHrk'`, üç mağaza). Bu görev yalnız tanımı ve onun kanonik testini teslim eder; ekran kolonu eklenmez (yeni gösterge 003'ün işi). T-001 blok J aksini gösterirse görev `NEEDS_CONTEXT` döner.
**Adımlar:**
- [ ] Kırmızı testler: `AySonuBakiye_Donem_GoruntuyeVeTarihineEsit` (son dolu `Donem` için `AySonuCte` ↔ B birebir), `AySonuBakiye_GoruntuYok_BaskaAyDonmez` (`@Donem = 01.10.2026` → `AySonuVarMiSql = 0` ve `AySonuCte` boş).
- [ ] Uygulama · kapılar.
**Kabul:** iki test yeşil.

### T-054 [UI] H8 ekran etiketleri
**Bağımlılık:** T-051, T-052, T-039, T-050 · **Test seviyesi:** hafif · **AC:** AC-8.1 (gösterim), KR-3, AC-0.1 · **Yayın grubu:** Y-DEPO
**Dosyalar:**
- Değiştir: `dashboard/Components/Pages/OdakStok.razor`, `Envanter.razor`, `SatisAnalizi.razor`
- Test: `tests/GmDashboard.Tests/Ekran/H08EkranTests.cs`
**Gereksinimler (tam değerlerle):** ODAK merkez depo kolonu başlığı "Merkez depo (WMS, anlık)" + `odak.depo`; Envanter kategori çeşit depo kolonu ve ölü stok depo bileşeninde `envanter.depo`; Satış analizi merkez depo kolonu başlığı "Merkez depo (kesim: dd.MM.yyyy)" (kesim tarihi filtrenin `Kesim` değeri; saat tabanda saklanmadığı için yazılmaz — KB-2).
**Adımlar:** [ ] Test (kaynak metin). [ ] Uygulama · derleme.
**Kabul:** test yeşil.

# F5 — P3 ve düşük öncelikli

### T-055 [NET] H9 Sınav ödeme sağlık kartı fatura başına bir kez
**Bağımlılık:** T-024, T-001 (blok H) · **Test seviyesi:** tam · **AC:** AC-9.1, AC-9.2
**Dosyalar:**
- Değiştir: `dashboard/Data/SinavQueries.cs` (`GetOdemeDurumAsync`)
- Test: `tests/GmDashboard.Tests/Kanonik/H09Tests.cs`
**Arayüzler:**
- Tüketir: `H09-sinav-odeme.sql` A, B; `GetSezonKpiAsync(donemId).NetKdvHaric`
- Üretir: `GetOdemeDurumAsync(int donemId, CancellationToken ct = default)`; `SinavOdemeDurum` alanları aynı
**Gereksinimler (tam değerlerle):** `X` OUTER APPLY kaldırılır; net `FisSetCte` kümesinden fiş başına bir kez; çok siparişli fişin neti bağlı sipariş sayısına **eşit bölünür** (İnsan onayı 5). T-001 blok H ≠ 0 ise kalemsiz siparişler ayrı durum satırı olarak döner (`Durum = "Kalemsiz"`).
**Adımlar:** [ ] Kırmızı test `GetOdemeDurumAsync_Donem_KpiNetineEsit` (Σ ↔ KPI ve ↔ A, ≤ 1,00 TL; B nüfusu `Nufus.EnAz`). [ ] Uygulama · kapılar.
**Kabul:** test yeşil.

### T-056 [UI] H9 Sınav notu
**Bağımlılık:** T-055, T-030 · **Test seviyesi:** hafif · **AC:** AC-9.1 (gösterim), AC-0.1
**Dosyalar:** Değiştir: `dashboard/Components/Pages/Sinav.razor` · Test: `tests/GmDashboard.Tests/Ekran/H09EkranTests.cs`
**Gereksinimler (tam değerlerle):** ödeme sağlık kartında `<DuzeltmeNotu Anahtar="sinav.odeme" />`; kart boşsa `DonemdeKayitYok`.
**Adımlar:** [ ] Test (kaynak metin). [ ] Uygulama · derleme.
**Kabul:** test yeşil.

### T-057 [NET] H10 Sabah servisi hata mesajı ve günlük
**Bağımlılık:** T-044, T-031, T-022 · **Test seviyesi:** tam · **AC:** AC-10.1, AC-10.2
**Dosyalar:**
- Değiştir: `dashboard/Data/SabahService.cs` (kurucu `ILogger<SabahService>`, `catch` ~207)
- Test: `tests/GmDashboard.Tests/HataEkrani/SabahServiceHataTests.cs`
**Arayüzler:**
- Üretir: `public sealed class SabahService(Db db, ILogger<SabahService> log)`; hata yolunda `SabahVeri.Hata = KullaniciMesajlari.VeriAlinamadi`
**Gereksinimler (tam değerlerle):** `catch (Exception ex) { log.LogError(ex, "Sabah özeti veri yükleme hatası"); … }`.
**Adımlar:**
- [ ] Kırmızı test (`[Collection("HataEkrani")]`, `Tur=HataEkrani`): `SabahService_VeriKaynagiYok_GenelMesajVeGunluk` — `Hata == VeriAlinamadi`, `Hata` "127.0.0.1" ve "Exception" içermez, günlükte `LogLevel.Error` ve "Sabah" geçen kayıt.
- [ ] Uygulama · kapılar.
**Kabul:** test yeşil.

### T-058 [NET] H10.3 sayısal olmayan ürün kodu ekranı çökertmez
**Bağımlılık:** T-051, T-047, T-055, T-068, T-071 · **Test seviyesi:** tam · **AC:** AC-10.3
**Dosyalar:**
- Oluştur: `dashboard/Data/Tanimlar/UrunKodu.cs`
- Değiştir: `dashboard/Data/RefQueries.Envanter.cs` (`CONVERT(int,pr.Code)` ~48, `CONVERT(int, p.Code)` ~214), `dashboard/Data/Queries.cs` (~89, ~136, ~250), `dashboard/Data/MagazaQueries.cs` (~154), `dashboard/Data/HediyeCekiQueries.cs` (~130, ~142, ~148, ~163), `dashboard/Data/SinavQueries.cs` (~88 `U.stkID = PR.Code`)
- Test: `tests/GmDashboard.Tests/Kanonik/H10UrunKoduTests.cs`
**Arayüzler:**
- Tüketir: `H10-urun-kodu.sql` A
- Üretir: `public static class UrunKodu { public static string StkId(string kolon); }` → `"CONVERT(int, CASE WHEN {kolon} NOT LIKE '%[^0-9]%' AND LEN({kolon}) BETWEEN 1 AND 9 THEN {kolon} END)"`
**Gereksinimler (tam değerlerle):** listelenen her ifade `UrunKodu.StkId("pr.Code")` / `("p.Code")` / `("PR.Code")` ile değiştirilir; `SatisAnaliziTabanService.cs` ve `SatisAnaliziQueries.Liste.cs` kapsam dışı (spec ekran listesinde yok). Karar: ifade beş dosyada tekrar edilmesin diye kontrata ek `UrunKodu` parçası.
**Adımlar:**
- [ ] Kırmızı testler: `UrunKoduStkId_SayisalOlmayanVeTasan_NullDoner` (teori; `SELECT v.Kod, {UrunKodu.StkId("v.Kod")} FROM (VALUES …) v(Kod)` ↔ A'nın `Beklenen`'i), `UrunKodu_Kaynak_DonusumIfadesiTekYerde` (beş dosyada `CONVERT(int,pr.Code)`, `CONVERT(int, p.Code)`, `= PR.Code` kalmadı).
- [ ] Uygulama · kapılar (+ koruma).
**Kabul:** testler yeşil.

### T-059 [UI] H10 hata ekranları
**Bağımlılık:** T-057, T-031, T-022, T-054 · **Test seviyesi:** tam · **AC:** AC-10.1, AC-10.2, SC-005
**Dosyalar:**
- Değiştir: `dashboard/Components/Pages/Sabah.razor`, `Envanter.razor`, `Operasyon.razor`, `SatinalmaAnaliz.razor`, `Esikler.razor`, `Vardiya.razor`
- Test: `tests/GmDashboard.Tests/HataEkrani/HataEkraniTests.cs`
**Arayüzler:**
- Tüketir: `HataEkraniFabrikasi`, `BellekGunluk`, `KullaniciMesajlari`, `SabahVeri.Hata`
**Gereksinimler (tam değerlerle):**
- `ex.Message` ve `ex.GetType().Name` ekrandan kaldırılır; `Logger.LogError(ex, "{Ekran} veri yükleme hatası", "<Ekran>")` (`Sabah`, `Envanter`, `Operasyon`, `SatinalmaAnaliz`, `Vardiya`); ekrana `VeriAlinamadi`.
- `SatinalmaAnaliz.razor`: üç alt bölüm öneki korunur: `"Talep sapması hesaplanamadı: " + VeriAlinamadi` (ve diğer ikisi).
- `Esikler.razor`: kayıt hatası `KayitYapilamadi`, `LogError(ex, "Eşikler kayıt hatası")`.
- `Vardiya.razor`: yükleme `try/catch`'e alınır.
- Karar: Eşikler'in hata yolu yalnız kayıtta; HTTP GET ile tetiklenmez → kaynak metin testiyle sınanır.
**Adımlar:**
- [ ] Kırmızı testler: `Ekran_VeriKaynagiYok_GenelMesajGosterirVeGunlugeYazar` (teori: `/sabah`, `/envanter`, `/operasyon`, `/satinalma/analiz`, `/vardiya`; HTML'de `VeriAlinamadi` var; `127.0.0.1`, `SqlException`, `Exception`, `InvalidOperationException` yok; günlükte ekran adı geçen `Error` kaydı), `Esikler_Kaynak_KayitHatasiGenelMesaj`, `HataMetni_AltiEkran_ExMessageYok` (altı dosyada `ex.Message` ve `GetType().Name` sayısı 0).
- [ ] Uygulama · kapılar: `--filter "Tur=HataEkrani"` + birim.
**Kabul:** testler yeşil (SC-005 = 0).

### T-060 [NET] H11 GeriAdresi [P]
**Bağımlılık:** T-023 · **Test seviyesi:** tam · **AC:** AC-11.1, AC-11.2
**Dosyalar:** Oluştur: `dashboard/Data/Tanimlar/GeriAdresi.cs` · Test: `tests/GmDashboard.Tests/Birim/GeriAdresiTests.cs`
**Arayüzler:** Üretir: `public static class GeriAdresi { public static string Coz(string? geri); }`
**Gereksinimler (tam değerlerle):** `null`/boş → `"/satis-analizi"`; `"/"` ile başlıyor ve `"//"` ile başlamıyor ve `"\"` içermiyor → olduğu gibi; `"/"` ile başlamıyor → `"/satis-analizi?" + geri`; `"//"` ile başlayan, `"\"` içeren, `"http:"`/`"https:"` ile başlayan → `"/satis-analizi"`.
**Adımlar:**
- [ ] Kırmızı testler: `GeriAdresi_Coz_SezonAksiyonYerelYolKorunur` (`"/sezon-aksiyon"`), `GeriAdresi_Coz_FiltreDurumuSatisAnalizineEklenir` (`"kesim=20260930"` → `"/satis-analizi?kesim=20260930"`), `GeriAdresi_Coz_BosIseSatisAnalizi`, `GeriAdresi_Coz_DisAdresiReddeder` (İnceleme odağı 5), `GeriAdresi_Coz_KodlanmisCiftEgikCizgiYerelKalir`.
- [ ] Uygulama · kapılar.
**Kabul:** testler yeşil.

### T-061 [UI] H11 ürün detayından geri dönüş
**Bağımlılık:** T-060 · **Test seviyesi:** hafif · **AC:** AC-11.1, AC-11.2
**Dosyalar:** Değiştir: `dashboard/Components/Pages/SatisAnaliziUrun.razor` (`Geri()` ~1071) · Test: `tests/GmDashboard.Tests/Ekran/H11EkranTests.cs`
**Gereksinimler (tam değerlerle):** `Geri()` → `Nav.NavigateTo(GeriAdresi.Coz(geri))`; `/satis-analizi?{geri}` birleştirmesi kalkar.
**Adımlar:** [ ] Test (kaynak metin): `SatisAnaliziUrun_Kaynak_GeriAdresiCozKullanir`. [ ] Uygulama · derleme.
**Kabul:** test yeşil.

### T-062 [NET] H12 mizan nakit, alınan çek, devreden KDV
**Bağımlılık:** T-024 · **Test seviyesi:** tam · **AC:** AC-12.1, AC-12.2, AC-12.3
**Dosyalar:**
- Değiştir: `dashboard/Data/MizanQueries.cs` (`OzetHesapla` `private` → `internal static`), `dashboard/Models/MizanModels.cs` (`MizanOzet`), `dashboard/GmDashboard.csproj` (`<ItemGroup><InternalsVisibleTo Include="GmDashboard.Tests" /></ItemGroup>`)
- Test: `tests/GmDashboard.Tests/Birim/MizanOzetTests.cs`, `tests/GmDashboard.Tests/Kanonik/H12Tests.cs`
**Arayüzler:**
- Tüketir: `H12-mizan.sql` A, B, C
- Üretir: `internal static MizanOzet OzetHesapla(IReadOnlyDictionary<string, decimal> k, IReadOnlyList<MizanNode> kokler)` · `public record MizanOzet(decimal Nakit, decimal VerilenCek, decimal Alicilar, decimal Saticilar, decimal KdvIndirilecek, decimal KdvHesaplanan, decimal KdvNet, decimal ToplamBorc, decimal ToplamAlacak, decimal AlinanCek, decimal KdvDevreden);` · `GetSonucAsync(int sirketId, int ay = 12, int ayBas = 1)` imzası aynı
**Gereksinimler (tam değerlerle):** `Nakit = Borc("100","102","108")`; `AlinanCek = Borc("101")`; `KdvDevreden = Borc("190")`; `KdvNet = KdvHesaplanan − KdvIndirilecek − KdvDevreden`.
**Adımlar:**
- [ ] Kırmızı testler: birim `OzetHesapla_101Bakiyesi_NakitteYokAlinanCekte`, `OzetHesapla_190Bakiyesi_KdvNettenDusulur`; kanonik `MizanOzet_KapanmisAy_HesapKumelerineEsit` (`GetSonucAsync(6, 6, 1)`, ≤ 1,00 TL üç değer).
- [ ] Uygulama · kapılar.
**Kabul:** üç test yeşil.

### T-063 [UI] H12 mizan kartları
**Bağımlılık:** T-062, T-030 · **Test seviyesi:** hafif · **AC:** AC-12.2 (gösterim), AC-0.1
**Dosyalar:** Değiştir: `dashboard/Components/Pages/Mizan.razor` · Test: `tests/GmDashboard.Tests/Ekran/H12EkranTests.cs`
**Gereksinimler (tam değerlerle):** "Nakit" kartı açıklaması "100, 102, 108"; yeni kart "Alınan çekler" (`AlinanCek`, 101); KDV kartına "Devreden KDV" satırı; `<DuzeltmeNotu Anahtar="mizan.nakit-kdv" />`. Yerleşim mevcut kart ızgarasına bir kart ekler.
**Adımlar:** [ ] Test (kaynak metin). [ ] Uygulama · derleme.
**Kabul:** test yeşil.

### T-064 [NET] H14 stok gösterge tanımları
**Bağımlılık:** T-058 · **Test seviyesi:** tam · **AC:** AC-14.2
**Dosyalar:**
- Oluştur: `dashboard/Data/Tanimlar/StokGostergeTanimlari.cs`
- Değiştir: `dashboard/Data/RefQueries.Envanter.cs` (`OluStokSql` içindeki `90` sabitleri), eşik SQL'de sabit yazılıysa `dashboard/Data/SezonAksiyonQueries.cs` ve `dashboard/Data/SatisAnaliziQueries.Liste.cs`
- Test: `tests/GmDashboard.Tests/Birim/StokGostergeTanimlariTests.cs`
**Arayüzler:**
- Üretir: `public static class StokGostergeTanimlari { public const int EnvanterOluStokSatisYokGun = 90; public const int EnvanterOluStokYasGun = 90; public static string EnvanterOluStokMetni { get; } public static string EnvanterStoktaYoklukMetni(decimal hedefYuzde); public static string SatinalmaFazlaMetni(int fazlaAy); public static string SatisAnaliziMetni(string gosterge); public static string SezonAksiyonMetni(string gosterge); }`
**Gereksinimler (tam değerlerle):**
- İlk adım (plan F0'daki eşik envanteri): dört ekrandaki ölü stok / aşırı stok / stokta yokluk göstergelerinin hesabı okunur; süre, eşik, kapsam tabloya yazılır (rapora). Değer değiştirilmez (tekilleştirme 003'te).
- Bilinen: Envanter ölü stok = son 90 günde üç mağazada `ehTip IN (4,100)` satışı yok, ürün kartı 90 günden eski, stok > 0, stok = üç mağaza + merkez depo (WMS). `EnvanterOluStokMetni` = "Son 90 günde mağazalarda satılmamış, 90 günden eski ve stokta olan ürün. Stok mağazalar ve merkez depo (WMS) toplamıdır."
- Karar (kontrattan sapma): Satınalma FAZLA eşiği `PanelAyarlar.SatinFazlaAy` ve Envanter stokta yokluk hedefi `PanelAyarlar.StokYoklukHedef` kullanıcının değiştirebildiği ayardır; metin sabitten değil **aynı ayar değerinden** üretilir (fonksiyon parametresi). Sabite çevirmek Eşikler ekranını bozar.
- `OluStokSql`'deki iki `90` → sabitler.
- Metin en fazla iki cümle, cümle ≤ 15 kelime.
**Adımlar:**
- [ ] Kırmızı testler: `StokTanimMetni_EnvanterOluStok_SqlSabitleriniIcerir` (metin `EnvanterOluStokSatisYokGun` ve `EnvanterOluStokYasGun` değerlerini içerir; `OluStokSql` kaynak metni iki sabite başvurur), `StokTanimMetni_SatinalmaFazla_AyarDegeriniYazar` (6 → metin "6 ay" içerir), `StokTanimMetni_Hepsi_IkiCumleyiAsmaz` (teori).
- [ ] Uygulama · kapılar.
**Kabul:** testler yeşil.

### T-065 [UI] H14 tanım metinleri ekranda
**Bağımlılık:** T-064, T-059 · **Test seviyesi:** hafif · **AC:** AC-14.1
**Dosyalar:**
- Değiştir: `dashboard/Components/Pages/Envanter.razor`, `SatisAnalizi.razor`, `SezonAksiyon.razor`, `SatinalmaAnaliz.razor`
- Test: `tests/GmDashboard.Tests/Ekran/H14EkranTests.cs`
**Gereksinimler (tam değerlerle):** her ölü/aşırı/stokta yokluk göstergesinin altında `text-base-content/60 text-xs` dipnot; metin `StokGostergeTanimlari`'ndan (ayar değeri `Ayar.Deger.SatinFazlaAy` / `StokYoklukHedef` ile).
**Adımlar:** [ ] Test (kaynak metin, teori 4 dosya: `StokGostergeTanimlari.` başvurusu var). [ ] Uygulama · derleme.
**Kabul:** test yeşil.

### T-066 [NET] D-1 RFM cirosu iade düşülmüş, LTV etiketi
**Bağımlılık:** T-049 · **Test seviyesi:** tam · **AC:** D-1
**Dosyalar:** Değiştir: `dashboard/Data/RefQueries.cs` (`GetRfmAsync` `ykSql`, `GetLtvAsync` segment etiketi) · Test: `tests/GmDashboard.Tests/Kanonik/D1Tests.cs`
**Arayüzler:** Üretir: `GetRfmAsync(DateOnly dun, CancellationToken ct = default)`, `GetLtvAsync(DateOnly dun, CancellationToken ct = default)`; `RfmSegment` aynı
**Gereksinimler (tam değerlerle):** `DocumentsTypeId IN (1,3)`; `Frq = COUNT(CASE WHEN DocumentsTypeId = 1 …)`; `Rec` yalnız satış fişinin son tarihinden; `Mon` iade negatif. LTV: `'Kartsız'` → `'Kayıtlı, kartsız'`.
**Adımlar:**
- [ ] Kırmızı testler: `GetRfmAsync_Dun_SegmentCirosuIadeDusulmus` (Σ segment cirosu = aynı müşteri kümesinin `(1,3)` net toplamı, CanliDb ile bağımsız yazılmış tek SELECT, ≤ 1,00 TL), `GetLtvAsync_Etiket_KayitliKartsiz`.
- [ ] Uygulama · kapılar.
**Kabul:** testler yeşil.

### T-067 [UI] D-1 müşteri ekranı dipnotu
**Bağımlılık:** T-066, T-030 · **Test seviyesi:** hafif · **AC:** D-1
**Dosyalar:** Değiştir: `dashboard/Components/Pages/Musteri.razor` · Test: `tests/GmDashboard.Tests/Ekran/D1EkranTests.cs`
**Gereksinimler (tam değerlerle):** LTV dipnotu "Anonim (yürü-gel) müşteri bu tabloda yok."; RFM segment cirosunda `<DuzeltmeNotu Anahtar="musteri.rfm" />`.
**Adımlar:** [ ] Test (kaynak metin). [ ] Uygulama · derleme.
**Kabul:** test yeşil.

### T-068 [NET] D-2 saat yoğunluğu ve kasiyer kapsamı
**Bağımlılık:** T-041 · **Test seviyesi:** tam · **AC:** D-2
**Dosyalar:** Değiştir: `dashboard/Data/Queries.cs` (`saatSql`, `kasSql`, `GetKasiyerDeltaAsync`) · Test: `tests/GmDashboard.Tests/Kanonik/D2Tests.cs`
**Arayüzler:**
- Tüketir: `FisTanimi.GeriDonusumHaricJoin`, `FisSayisi`, `NetKdvHaric`; `D2-kasiyer.sql`
- Üretir: `GetKasiyerDeltaAsync(DateOnly start, DateOnly endExcl, DateOnly prevStart, DateOnly prevEnd, CancellationToken ct = default)`; `KasiyerRow`, `HourBar` aynı
**Gereksinimler (tam değerlerle):** köprü `Pos → Stores → posMagaza` (`StoresId` doğrudan değil), 1001 hariç, `Fis = FisSayisi`, kasiyer net `NetKdvHaric` (iade dalındaki `ABS(DiscountTotal)` kalkar). `katSql` değişmez; farkı `D2-kasiyer.sql` blok B'de.
**Adımlar:** [ ] Kırmızı test `Kasiyer_Eylul2026_MagazaNetineEsit` (Σ kasiyer `Net` = Σ mağaza `Net`, ≤ 1,00 TL, ve ↔ kanonik). [ ] Uygulama · kapılar (+ koruma).
**Kabul:** test yeşil.

### T-069 [UI] D-2 notları
**Bağımlılık:** T-068, T-046, T-059 · **Test seviyesi:** hafif · **AC:** D-2
**Dosyalar:** Değiştir: `dashboard/Components/Pages/Home.razor`, `Operasyon.razor` · Test: `tests/GmDashboard.Tests/Ekran/D2EkranTests.cs`
**Gereksinimler (tam değerlerle):** Home saat yoğunluğu ve kasiyer tablosu, Operasyon kasiyer delta tablosu: `<DuzeltmeNotu Anahtar="home.saat-kasiyer" />`.
**Adımlar:** [ ] Test (kaynak metin). [ ] Uygulama · derleme.
**Kabul:** test yeşil.

### T-070 [UI] D-3 "Baskısı yok" KDV etiketi [P]
**Bağımlılık:** T-023 · **Test seviyesi:** hafif · **AC:** D-3
**Dosyalar:** Değiştir: `dashboard/Components/Pages/BaskisiYok.razor` · Test: `tests/GmDashboard.Tests/Ekran/D3EkranTests.cs`
**Gereksinimler (tam değerlerle):** tutar kolon başlıklarına "(KDV dahil)".
**Adımlar:** [ ] Test (kaynak metin: "(KDV dahil)" geçiyor). [ ] Uygulama · derleme.
**Kabul:** test yeşil.

### T-071 [NET] D-4 hediye çeki barem aynı KDV tabanı
**Bağımlılık:** T-019, T-001 (blok C) · **Test seviyesi:** tam · **AC:** D-4
**Dosyalar:** Değiştir: `dashboard/Data/HediyeCekiQueries.cs` (`GetBaremKalemAsync`), `dashboard/Models/HediyeCekiModels.cs` (`HcBaremKalem` sona `decimal NetKdvDahil`) · Test: `tests/GmDashboard.Tests/Kanonik/D4Tests.cs`
**Arayüzler:** Tüketir: `D4-hediye-ceki.sql`. Üretir: `GetBaremKalemAsync(DateOnly bas, DateOnly bit, CancellationToken ct = default)`; `HcBaremKalem(…, decimal NetKdvDahil)`
**Gereksinimler (tam değerlerle):** `Brut = TotalPrice + DiscountTotalDirect`, `Indirim = DiscountTotalDirect`, `NetKdvDahil = TotalPrice`; mevcut `Net` (KDV hariç) kalır. KR-4: T-001 blok C "eşdeğer" ise `GeriDonusumHaric` → `FisTanimi.GeriDonusumHaricJoin`; "eşdeğer değil" ise dokunulmaz ve fark T-074'te sema'ya yazılır.
**Adımlar:** [ ] Kırmızı test `GetBaremKalemAsync_Satir_BrutEksiIndirimNeteEsit` (her satır ≤ 1,00 TL, ve ↔ kanonik). [ ] Uygulama · kapılar.
**Kabul:** test yeşil.

### T-072 [UI] D-4 hediye çeki kolonları
**Bağımlılık:** T-071, T-030 · **Test seviyesi:** hafif · **AC:** D-4
**Dosyalar:** Değiştir: `dashboard/Components/Pages/HediyeCeki.razor` · Test: `tests/GmDashboard.Tests/Ekran/D4EkranTests.cs`
**Gereksinimler (tam değerlerle):** barem tablosunda Brüt / İndirim / Net "(KDV dahil)" kolonları `NetKdvDahil` ile; mevcut net "(KDV hariç)" ayrı kolon; `<DuzeltmeNotu Anahtar="hediye-ceki.barem" />`; boşsa `DonemdeKayitYok`.
**Adımlar:** [ ] Test (kaynak metin). [ ] Uygulama · derleme.
**Kabul:** test yeşil.

### T-073 [UI] D-5 ciro tabanı dipnotları [P]
**Bağımlılık:** T-023 · **Test seviyesi:** hafif · **AC:** D-5
**Dosyalar:** Değiştir: `dashboard/Components/Pages/Magazalar.razor` (gün karşılaştırma), `dashboard/Components/Pages/Tahmin.razor` · Test: `tests/GmDashboard.Tests/Ekran/D5EkranTests.cs`
**Gereksinimler (tam değerlerle):** Magazalar dipnotu "Kasa verisi, KDV dahil (KDV hariç ayrıca gösterilir)."; Tahmin dipnotu "ERP stok hareketi, KDV hariç, satış − iade." — iki metin ilgili sorgunun gerçek tabanıyla karşılaştırılır (`GunKarsilastirQueries`, `Queries.GetTahminAsync`/`GetGercekCiroAsync`); uyuşmazsa metin koda göre düzeltilir, SQL değişmez.
**Adımlar:** [ ] Test (kaynak metin). [ ] Uygulama · derleme.
**Kabul:** test yeşil.

# Semantik katman ve doküman

### T-074 [SQL] sema kural kayıtları
**Bağımlılık:** T-028, T-001 · **Test seviyesi:** hafif · **AC:** FR-014
**Etiket gerekçesi:** sema kaydı `sema-ogren` deseninde canlı SQL kanıtıyla yazılır (`evidence` = arşiv sorgusu + sayı + tarih); yazar sorguyu yeniden koşabilmelidir. Teknik yazar ([DOC]) canlı ERP sorgusu koşmaz; bu yüzden [SQL].
**Dosyalar:** Değiştir: `sema/metrics.yaml`, `sema/codes.yaml`; oluştur/değiştir: `docs/sema-adaylari.yaml` (`ork sema-aday` çıktısı)
**Arayüzler:** Üretir: `metrics.yaml: FIS_KANONIK`; `codes.yaml: EncoreMerkez.SalesProducts.BarcodeNo` altında 1001 notu
**Gereksinimler (tam değerlerle):**
- Önce aday: `python ../orkestra/ci/ork.py sema-aday "Kanonik fiş: DocumentsTypeId=1 ve belgede BarcodeNo='1001' satırı yok; iade ayrı sayı" --tur metrik --kanit "sorgular/2026-10-panel-veri-duzeltme/H05-fis.sql; FSM Eylül 2026 fiş 42.774, iade 947" --guven 0.95` ve 1001 için `--tur kod`. Sonra `sema-ogren` ile işlenir (K3: sema sahibi bu depo; tanım GMY onaylı, K7).
- Kural yazılır, liste yazılmaz (`semantic-layer.md` § şema gerçeği ≠ satır verisi). `last_verified: 2026-10-<gün>`.
- KR-4 "eşdeğer değil" ise iki geri dönüşüm tanımının farkı `codes.yaml`'a not.
**Adımlar:** [ ] Aday + işleme. [ ] Kapı: `python tools/sema_degismez.py` (çıkış 0 — mevcut değişmezler bozulmadı).
**Kabul:** iki kayıt yazılı; değişmez koşucusu yeşil.

### T-075 [SQL] Dört yeni değişmez
**Bağımlılık:** T-001, T-019 · **Test seviyesi:** hafif · **AC:** FR-014, SC-007
**Etiket gerekçesi:** değişmez bir SQL denetimidir; kırmızı kip canlı koşum ister ([SQL]).
**Dosyalar:** Değiştir: `sema/degismezler.json`
**Arayüzler:** Üretir: `encore-kalem-salesid-sequence-tekil`, `encore-products-code-sayisal`, `geri-donusum-1001-satis-fisinde-gecerli-yok`, `wms-alan-tipi-kumesi-kapali` (her birinde `soru`, `neden`, `db`, `karsilastirma`, `sunucu: erp`, nüfus sorgusu `population`)
**Gereksinimler (tam değerlerle):** nüfuslar: `SalesProductCampaigns` son 90 gün · `EncoreMerkez.dbo.Products` · `SalesProducts WHERE BarcodeNo = '1001'` · `DerinSISBkm.depo.adresAlanTip`. Beklenen: çift satır 0; sayısal olmayan kod 0; tip 1 belgede `IsValid = 1` olan 1001 satırı sayısı T-001 blok B'deki değer (`encok`); alan tipi kümesi `{0,1,2}`.
**Adımlar:**
- [ ] Ekle; her biri için beklenen değer bilerek bozulur → `python tools/sema_degismez.py` çıkış 1 görülür → elle geri yazılır → çıkış 0.
**Kabul:** dört kırmızı kip kanıtı + son koşu çıkış 0.

### T-076 [DOC] ADR-005, ADR-006 ve merkez depo kuralı
**Bağımlılık:** T-022, T-028, T-053 · **Test seviyesi:** yok (gerekçe: yalnız doküman) · **AC:** Madde 5, Madde 9 (A1, A2)
**Dosyalar:**
- Oluştur: `docs/ADR/005-dashboard-test-projesi-canli-erp.md` (A1), `docs/ADR/006-panel-ortak-tanimlar.md` (A2)
- Değiştir: `.claude/rules/sql-server-conventions.md` (§ MERKEZ DEPO STOĞU)
**Gereksinimler (tam değerlerle):**
- Numara 004 kullanılmaz: kurallarda "eski ADR-004" adıyla geçen ve dosyası olmayan bir başvuru var; karışmasın diye 005/006.
- A1: test projesi, salt-okuma kapısı + ROLLBACK, KOŞAMADI = kırmızı, kanonik sorgu bağımsız, kapalı ay tabanı, `BKM_ENV_DOSYA` yalıtımı ve neden DI yolu seçilemediği; reddedilenler: `BkmVardiya.Tests`'e ekleme, `sema_degismez`, Testcontainers. Orta vade: `db_datareader` login'i (S5).
- A2: `Data/Tanimlar/` SQL parçası sabitleri + sema kural kaydı; kanonik doğrulamanın bilerek bağımsız tutulması; 003 şartı.
- Kural: "Bugün canlı WMS; geçmiş ay ay sonu görüntüsü, `@Donem` açık, `MAX(Donem)` yedeği yok; canlı hata verirse görüntüye sessiz geçiş yok." — kanıt `T-052`, `T-053` testleri.
- Şablon `docs/ADR/000-template.md`; dil kuralları `yazim-metin`.
**Adımlar:** [ ] Yaz · `dokuman_denetle.py` hook temiz.
**Kabul:** üç dosya; her iddia kaynağa bağlı.

### T-077 [YARDIM] Panel tanımları yardım sayfası
**Bağımlılık:** T-046, T-054, T-039, T-045, T-059 · **Test seviyesi:** yok (gerekçe: yalnız doküman) · **AC:** Madde 11
**Dosyalar:** Oluştur: `docs/yardim/panel-tanimlari.md`
**Gereksinimler (tam değerlerle):**
- Künye: `> Tür: başvuru · Kaynak commit: <hash> · İzlenen yollar: dashboard/Data/Tanimlar/, sema/metrics.yaml · Son doğrulama: gg.aa.yyyy`.
- Bölümler: "Fiş sayısı neyi sayar", "Merkez depo stoğu nereden gelir", "E-ticaret cirosunda iptal ve iade", "Hedef karşılaştırmasındaki not", "'Hesap düzeltildi' notu ne zaman görünür (30 gün)", "Hata mesajı görürseniz". Ekran adları **kalın** ve koddaki metinle birebir; sema kaydına bağlantı.
**Adımlar:** [ ] Yaz · `dokuman_denetle.py` temiz.
**Kabul:** sayfa hazır.

### T-078 [DOC] CHANGELOG ve izleme maddeleri
**Bağımlılık:** T-069, T-072, T-073, T-065, T-063, T-061, T-056, T-067, T-070 · **Test seviyesi:** yok (gerekçe: yalnız doküman) · **AC:** Madde 11
**Dosyalar:** Oluştur: `dashboard/CHANGELOG.md` · Değiştir: `TODO.md`
**Gereksinimler (tam değerlerle):**
- CHANGELOG (Keep a Changelog, Türkçe başlık): `## [Yayımlanmamış]` → `### Düzeltildi` (H1–H14, D-1–D-5, kullanıcı etkisiyle; örnek: "Mağaza kartındaki fiş sayısı yalnız perakende satış fişini sayar; iade ayrı gösterilir."), `### Eklendi` (Ana sayfada perakende/Sınav kırılımı, Alınan çekler kartı, "Hesap düzeltildi" notu), ve "Excel raporları (`scripts/`) henüz eski tanımda." satırı.
- `TODO.md` (önce `grep -n` ile mükerrer kontrolü): (1) hangi `scripts/*.py` hangi fiş/iade/depo tanımını kullanıyor listesi — betikler `grep -l "DocumentsTypeId\|1001\|StokAyBakiye\|paletUrnTnm" scripts/*.py` ile bulunur; (2) "Hedef tabanı teyit bekliyor notu 30 gün teyitsiz kalırsa yükselt (yayın + 30 gün)"; (3) A3 ADR + `HedefTabani.Teyitli = true` görevi (teyit gelince).
**Adımlar:** [ ] Yaz · `dokuman_denetle.py` temiz.
**Kabul:** iki dosya güncel.

# F6 — Kapanış

### T-079 [NET] Düzeltme notu anahtar tutarlılık testi
**Bağımlılık:** T-034, T-036, T-039, T-045, T-046, T-048, T-050, T-054, T-056, T-063, T-067, T-069, T-072 · **Test seviyesi:** hafif · **AC:** AC-0.1
**Dosyalar:** Test: `tests/GmDashboard.Tests/Birim/DuzeltmeNotuAnahtarTests.cs`
**Gereksinimler (tam değerlerle):** `dashboard/Components/Pages/*.razor` içindeki `Anahtar="…"` değerleri kümesi = `DuzeltmeNotlari.YayinTarihleri.Keys` (20). Fark mesajı iki yönü ayrı yazar ("sözlükte var, ekranda yok" / "ekranda var, sözlükte yok").
**Adımlar:** [ ] Test · bir anahtarı bilerek sil → kırmızı → geri yaz → yeşil.
**Kabul:** test yeşil + kırmızı kip kanıtı.

### T-080 [SQL] Kapanış ölçümü, SC raporu ve oturum günlüğü
**Bağımlılık:** T-003, T-018, T-074, T-075, T-076, T-077, T-078, T-079, T-058 · **Test seviyesi:** yok (gerekçe: ölçüm ve rapor; testler önceki görevlerde) · **AC:** SC-001…SC-007, AC-0.2, FR-012
**Dosyalar:**
- Değiştir: `sorgular/2026-10-panel-veri-duzeltme/*.sql` (yalnız `Sonra:` satırları; ayrı commit, gövde "dondurma sonrası yalnız Sonra satırı")
- Oluştur: `.orkestra/calisma/001-panel-veri-duzeltme/sc-raporu.md`
- Değiştir: `docs/journal/bkm/<kapanış günü yyyy-MM-dd>.md` (append)
**Gereksinimler (tam değerlerle):**
- 22:00 sonrası tam koşu: `dotnet test tests/GmDashboard.Tests` (filtresiz); her testin süresi kaydedilir; koşu sırasında `SELECT session_id, blocking_session_id FROM sys.dm_exec_requests WHERE blocking_session_id <> 0` iki kez.
- Kapılar: `dotnet build dashboard/GmDashboard.csproj` 0 hata · `python tools/panel_kolon_denetimi.py` 0 · `python tools/sema_degismez.py` 0 · `python tools/turkce_tanimlayici_denetimi.py` 0 (yeni dosyalar).
- SC raporu: her AC ve SC için `tuttu / saptı / koşamadı / karar bekliyor`; P1 üçüncü ölçüm (T-018) sonucu; KB-1 ve KB-2 durumu.
- Journal (AC-0.2): her değişen gösterge için anahtar, önce değeri, sonra değeri, kanıt dosyası.
**Adımlar:** [ ] Koşu · Sonra değerleri · rapor · journal.
**Kabul:** "saptı" kalan kalem yok; aksi varsa yayın (T-081) yapılmaz.

### T-081 [NET] Yayın tarihi (tek satırlık commit)
**Bağımlılık:** T-080 ve yayın günü · **Test seviyesi:** hafif · **AC:** AC-0.1
**Dosyalar:** Değiştir: `dashboard/Data/Tanimlar/DuzeltmeNotlari.cs` (tarih sabiti) · Test: `tests/GmDashboard.Tests/Birim/YayinTarihiTests.cs`
**Gereksinimler (tam değerlerle):** sözlük tek bir `private static readonly DateOnly Yayin = new(<yıl>, <ay>, <gün>);` sabitine bağlıdır (T-029'da `DateOnly.MinValue`); bu görev yalnız o satırı yayın günüyle değiştirir. Yayın günü = dashboard'un yeni sürümle çalışmaya başladığı gün (K5/S2 bekleniyor).
**Adımlar:**
- [ ] Test (test-yazar, ayrı commit): `YayinTarihleri_Hepsi_AyniVeMinValueDegil` → kırmızı.
- [ ] Tek satır değişikliği → yeşil.
**Kabul:** test yeşil; commit diff'i tek satır.

# Ek görevler — 002 planından (09.10.2026)

> Kaynak: `specs/002-mobil-kabuk-ekran/plan.md` § "001'e eklenecek görevler" (G-1, G-2, G-3) ve `specs/002-mobil-kabuk-ekran/arastirma.md` § 8. GMY kararları: Cari/Risk "önce düzelt, sonra telefona" (08.10.2026); 002 Dalga 1 001'i beklemez (08.10.2026, K10).
> Yukarıdaki T-001…T-081 değiştirilmedi. Bu görevlerin istediği spec ve kontrat metinleri her görevin **Spec değişikliği gerekli** / **Kontrat değişikliği gerekli** notunda tam metin olarak durur; spec sahibi uygular.

**Test altyapısı adları (gerçek imzalar, `lib/Bkm.TestAltyapi`, T-021 düzeltme turu K-r1-6):** T-021…T-023 metnindeki Türkçe adların yerine şunlar geçerlidir:
`LiveDb.PanelDb()` · `LiveDb.QueryAsync<T>(DbTarget target, string sql, object? param = null, CancellationToken ct = default)` · `LiveDb.ScalarAsync<T>(DbTarget target, string sql, object? param = null, CancellationToken ct = default)` · `DbTarget.Erp` / `DbTarget.Joker` · `ReadOnlyGate.Check(string sql)` · `CanonicalQuery.Read(string file, string? block = null)` · `Tolerance.Amount` (1,00) · `Tolerance.AmountEqual(decimal panel, decimal canonical, string label)` · `Population.AtLeast(int n, string reason)` · `FakeClock(DateTimeOffset now)` · `SourceFile.Read(string repoRelativePath, string? startDirectory = null)`.

**Sıra ve bağımlılık özeti:**

| Görev | Ne zaman başlar | Neyi bekletir |
|---|---|---|
| T-082 [SQL] | Hemen (T-001'den bağımsız) | T-083 |
| T-083 [NET] | T-082 dondurulduktan ve T-023 uygulandıktan sonra | T-084 |
| T-085 [NET] | 002 Dalga 1 master'a girdikten sonra (merge insan kararı) | T-084 |
| T-084 [UI] | T-083 + T-085 + T-029 + T-030 + T-031 sonrası | T-079, T-080 (öneri: bu iki görev T-084'ten sonra koşar) |
| T-086 [DOC] | T-080 SC raporu + `/kabul-testi` hükmü sonrası | 002 Dalga 3 (kapı açma) |
| T-087 [NET] | T-029 (TimeProvider kaydı) ve T-024 sonrası; T-026 kısım 2 ve T-037'den önce | T-026 (kısım 2), T-037 |

T-079 ve T-080'in "Bağımlılık" satırları bu görevleri saymıyor. Görev metinleri değiştirilmedi; uygulayıcı T-079 ve T-080'i T-084 bittikten sonra başlatır.

**AC kapsama (ek):**

| AC (öneri, bkz. T-082 notu) | Görev(ler) |
|---|---|
| AC-15.1 | T-082, T-083, T-084 |
| AC-15.2 | T-083, T-084 |
| AC-15.3 | T-082, T-083, T-084 |
| FR-018 (öneri) | T-083, T-084 |
| AC-0.1 (yeni anahtar `cari-risk.ozet`) | T-084 |
| FR-012 (H15 önce/sonra/bağımsız) | T-082 |
| FR-014 (sema adayı) | T-082 |
| 002 R3 (kabul sonucu git'te) | T-086 |
| 002 K10 (master'ı alma) | T-085 |

**İnceleme odağı (ek):**
1. **İlk N sınırının toplama geri sızması:** toplam sorgusuna `TOP (200)` ya da `ORDER BY … OFFSET` eklenirse beklenen: satıcı borcu kanoniğe eşit değil, kırmızı. Test: T-083 `GetCariRiskOzetAsync_Bugun_AliciVeSaticiTumKayitlaraEsit` (kırmızı kip bu ifadeyle kanıtlanır).
2. **Nüfus eski sınırın altına düşerse:** iki grup da 200 kayıt ya da altındaysa ilk-N hatası ölçülemez; beklenen: yeşil değil `KOŞAMADI`. Test: T-083 `GetCariRiskOzetAsync_GrupKayitSayisi_EskiSinirdanBuyukVeBirebir`.
3. **Razor'da listeden toplama:** `_rows.Sum(` ya da `_rows.Count(r => r.Limit` ifadesi Cari/Risk sayfasına geri gelirse beklenen kırmızı. Test: T-084 `CariRisk_Kaynak_OzetCekirdektenGelirListedenToplanmaz`.
4. **Merge sonrası çift `TimeProvider` kaydı:** 001 ve 002 aynı satırı farklı konumlara eklediyse git çakışma vermez, satır iki kez kalır; beklenen kırmızı. Test: T-085 `ServiceRegistration_TimeProvider_TekKayit`.
5. **Kanıtsız ya da git dışı kanıtla "tuttu":** `Kanıt` hücresi boş ya da `.orkestra/` ile başlayan satır; beklenen kırmızı. Test: T-086 `KabulSonucu_Satir_KanitDoluVeGitIcinde` (teori).

### T-082 [SQL] Kanonik sorgu H15 — Cari/Risk tam toplam, alıcı ve satıcı ayrı (G-1)
**Bağımlılık:** yok (T-001'den bağımsız; T-019 dondurmasına girmez, kendi dondurmasını yapar) · **Test seviyesi:** yok (gerekçe: kanonik sorgu testin kendisidir; doğruluğu bu görevdeki bağımsız `sql-denetci` incelemesiyle sınanır) · **AC:** AC-15.1, AC-15.3 (öneri), FR-012, FR-014
**Dosyalar:**
- Oluştur: `sorgular/2026-10-panel-veri-duzeltme/H15-cari-risk.sql`
- Oluştur: `sorgular/2026-10-08-cari-risk-kapsam.sql` (ölçüm arşivi, `semantic-layer.md` § ikiz yükümlülük)
- Oluştur/değiştir: `docs/sema-adaylari.yaml` (`ork sema-aday` çıktısı)
**Arayüzler:**
- Tüketir: —
- Üretir: `H15-cari-risk.sql` blok `A` → `(Grup varchar(3), Kayit int, VadesiGecen decimal(18,2), LimitAsan int, LimitTanimli int)`, parametresiz, tam iki satır (`'120'`, `'320'`); blok `B` → `(Grup varchar(3), LimitTanimliFrm int)`; blok `C` → `(DisKayit int, DisVadesiGecen decimal(18,2))`. Başlıkta `Dondurma: <hash>`.
**Gereksinimler (tam değerlerle):**
- Hedef `-- ork:hedef-db DerinSISBkm`, `-- ork:compat 150`. Başlık şablonu `kontratlar/kanonik-sorgular.md`; örnek biçim `H12-mizan.sql` (Soru, AC, Dönem, Tolerans, Önce, Sonra, Bağımsız, Aynı kaynak — neden, Başka ne olabilir, Kapsam, Dondurma, SSMS, Komut).
- Köprü sema'dan: `bridges.yaml: bakiyevdgg-frm` → `DerinSISBkm.dbo.bakiyeVDGG_vw.cKod = DerinSISBkm.dbo.frm.frmID`. Kolonlar: `bakiye` (net bakiye), `GecenB` (vadesi geçen), `frm.frmKod`, `frm.frmBakiyeLimit`.
- Nüfus (A ve C): `ABS(b.bakiye) > 0`. Grup = `LEFT(fr.frmKod, 3)`; A yalnız `fr.frmKod LIKE '120%'` (alıcı) ve `LIKE '320%'` (satıcı).
- Blok A, grup başına: `Kayit = COUNT(*)`; `VadesiGecen = SUM(CAST(b.GecenB AS decimal(18,2)))` — **TOP, ROW_NUMBER, sıralama yok**; `LimitAsan = SUM(CASE WHEN ISNULL(fr.frmBakiyeLimit, 0) > 0 AND ABS(b.bakiye) > fr.frmBakiyeLimit THEN 1 ELSE 0 END)`; `LimitTanimli = SUM(CASE WHEN ISNULL(fr.frmBakiyeLimit, 0) > 0 THEN 1 ELSE 0 END)`. İşaret görünümdeki gibi kalır (satıcı vadesi geçen negatif gelir; çevirme panelin işidir).
- Blok B (AC-15.3 kanıtı, bakiyeden bağımsız): `DerinSISBkm.dbo.frm` içinde `frmKod LIKE '120%'` ve `LIKE '320%'` gruplarında `ISNULL(frmBakiyeLimit, 0) > 0` olan kayıt sayısı. Sonuç başlığa yazılır; 0 ise başlığa "Limit tanımlı cari yok — ekranda 'Limit tanımlı değil' notu beklenir."
- Blok C (kapsam beyanı): bakiyesi sıfırdan farklı olup `120`/`320` dışında kalan cari sayısı ve vadesi geçen toplamı ("Hepsi" sekmesinin fazlası). Yorum yapılmaz, yalnız sayı.
- Kanonik sorgu panel SQL'inden kopyalanmaz; `dashboard/` açılmaz. Başlıkta zorunlu satırlar:
  - `Aynı kaynak — neden: evet. Vadesi geçen yaşlandırması yalnız ERP'nin bakiyeVDGG_vw görünümünde var; bağımsız ikinci kaynak yok. Bağımsızlık yazım yolundan: sınırsız grup toplamı, sıralama yok.`
  - `Başka ne olabilir:` en az üç madde — (1) ekranın amacı bilerek satıcı borcu olabilirdi; GMY kararı 08.10.2026 ikisini ayrı gösterir. (2) Alıcı toplamının içeriği (grup içi cariler) ölçülmedi; ÇIKARIM yapılmaz. (3) Görünüm her çağrıda bütün cari hareketini toplar; panel ve kanonik aynı dakika içinde okunur.
- `Önce:` satırı `sorgular/2026-10-08-cari-risk-kapsam.sql` ile bu görev gününde yeniden koşulan değerdir; 08.10.2026 referansı da yazılır: alıcı 284 kayıt, tümü 1.229.462.178,38 / ilk 200 1.229.471.096,77; satıcı 300 kayıt, tümü −72.794.717,37 / ilk 200 −147.310.896,38 (ekran varsayılanı); limit aşan iki grupta 0.
- `Dönem:` "Bugün (canlı görünüm, tarih parametresi yok). Kıyas aynı dakika içinde." `Tolerans:` "Tutar ≤ 1,00 TL; sayılar birebir."
- `sorgular/2026-10-08-cari-risk-kapsam.sql`: `arastirma.md` § 8'deki sorgu **birebir**; başlık: soru, hedef DB, 08.10.2026 bulgu tablosu, "H15 Önce değerinin kaynağı".
- Sema adayı (yazma değil, aday): `python ../orkestra/ci/ork.py sema-aday "Cari/Risk vadesi geçen alacak = 120 grubu bütün carilerin GecenB toplamı; vadesi geçen borç = 320 grubu, işaret çevrilmiş; ilk N kayıttan toplanmaz" --tur metrik --kanit "sorgular/2026-10-panel-veri-duzeltme/H15-cari-risk.sql; <koşu günü> alıcı <n> kayıt, satıcı <n> kayıt" --guven 0.9`.
- Dondurma: `sql-denetci`'ye yalnız `sorgular/2026-10-panel-veri-duzeltme/H15-cari-risk.sql`, `.claude/rules/sql-server-conventions.md`, `sema/` verilir (`dashboard/` verilmez). Bulgu düzeltilir; sonra `db(T-082): H15 kanonik sorguyu dondur` ve ardından `db(T-082): dondurma hash'ini başlığa yaz`.
**Adımlar:**
- [ ] Önce ölçümü: `sqlcli query --profile erp --read-only --max-rows 100000 "<2026-10-08-cari-risk-kapsam.sql gövdesi>"` (depo kökünden); dönen 2 satır başlığa.
- [ ] A, B, C bloklarını yaz; her birini aynı komutla koş; satır sayıları beklenenle (A: 2, B: 2, C: 1) karşılaştırılır.
- [ ] Kapı: `python ../orkestra/dist/orkestra/hooks/sql_denetle.py sorgular/2026-10-panel-veri-duzeltme/H15-cari-risk.sql` ve aynısı `sorgular/2026-10-08-cari-risk-kapsam.sql` için (E bulgusu 0).
- [ ] `dotnet test tests/GmDashboard.Tests --filter "FullyQualifiedName~CanonicalFileGate"` — yeni dosyanın her bloğu salt-okuma kapısından geçer.
- [ ] Bağımsız denetim → dondurma → hash commit'i. Sema adayı.
**Kabul:** iki dosya koşar; başlıkta Önce, Bağımsız, B sonucu ve `Dondurma:` dolu; E bulgusu 0; kapı testi yeşil.
**Spec değişikliği gerekli (spec sahibi uygular; tam metin önerisi):**
- `spec.md` § Kullanıcı hikâyeleri, H14'ten sonra:
  > ### H15 — Cari/Risk özeti bütün carilerden, alacak ve borç ayrı (P2)
  > Ek madde, GMY kararı 08.10.2026 ("önce düzelt, sonra telefona"). Telefon kapısı anahtarı `001:cari-risk` (spec 002).
  > GMY olarak Cari/Risk ekranında vadesi geçen alacağı ve borcu bütün carilerden hesaplanmış, alıcı ve satıcı için ayrı görmek istiyorum, böylece ilk 200 kaydın toplamını gerçek toplam sanmam.
  > **Bağımsız test:** Ekrandaki özet değerler, aynı dakika içinde bütün alıcı ve satıcı carilerinden bağımsız hesaplanan toplamla karşılaştırılır.
  > **Kabul kriterleri:**
  > - **AC-15.1:** Verildiğinde alıcı ve satıcı carilerinin bugünkü bakiyeleri, Yapıldığında Cari/Risk ekranı açıldığında, O zaman "Vadesi geçen alacak" bütün alıcı carilerinden, "Vadesi geçen borç" bütün satıcı carilerinden hesaplanmış görünür ve her biri bağımsız hesaplanan toplama 1,00 TL toleransla eşittir.
  > - **AC-15.2:** Verildiğinde Cari/Risk listesi en yüksek bakiyeli ilk N kayıtla sınırlı, Yapıldığında sekme ya da arama değiştirildiğinde, O zaman özet göstergeler değişmez ve hiçbir özet gösterge yalnız listedeki kayıtlardan hesaplanmaz; bugünkü "Toplam Net Bakiye" kartı kalkar.
  > - **AC-15.3:** Verildiğinde alıcı ve satıcı carileri, Yapıldığında Cari/Risk ekranı açıldığında, O zaman "Limit aşan cari" bütün bu carilerden sayılır ve bağımsız sayımla birebir aynıdır; kredi limiti tanımlı hiçbir cari yoksa sayının altında "Limit tanımlı değil" notu görünür.
  > Telefondaki "Vadesi geçen alacak" kartının bu değerle aynı olması spec 002 AC-4.11'de doğrulanır.
- `spec.md` § Fonksiyonel gereksinimler, FR-017'den sonra:
  > - **FR-018:** Sistem Cari/Risk özet göstergelerini (vadesi geçen alacak, vadesi geçen borç, limit aşan cari) listenin kayıt sınırından bağımsız olarak bütün alıcı ve satıcı carilerinden hesaplamak ve alacak ile borcu ayrı göstermek ZORUNDADIR (H15; GMY kararı 08.10.2026).
- `spec.md` SC-002: "(H1–H9 ve D-1–D-5 için %100)" → "(H1–H9, H15 ve D-1–D-5 için %100)".
- **Karar gerekir (GMY):** AC-15.2'deki "Toplam Net Bakiye kartı kalkar" bir öneridir. Seçenek: kart kalır ama değeri de bütün carilerden hesaplanır (o zaman çekirdeğe iki tutar daha eklenir). Karar gelmeden T-084 başlamaz.
**Kontrat değişikliği gerekli:** `kontratlar/kanonik-sorgular.md` tablosuna satırlar:
> | AC-15.1 | `H15-cari-risk.sql` blok A | — (canlı) | `FinansQueries.GetCariRiskOzetAsync()` | `VadesiGecenAlacak` = A(120).`VadesiGecen`; `VadesiGecenBorc` = −A(320).`VadesiGecen`; ≤ 1 TL; aynı dakika | `GetCariRiskOzetAsync_Bugun_AliciVeSaticiTumKayitlaraEsit` |
> | AC-15.3 | aynı, blok A (+ B kanıt) | — | aynı | `LimitAsanCari` = A(120)+A(320) `LimitAsan`; `LimitTanimliCari` = A `LimitTanimli` toplamı; birebir | `GetCariRiskOzetAsync_Bugun_LimitSayilariBirebir` |

### T-083 [NET] H15 Cari/Risk özet çekirdeği (G-1)
**Bağımlılık:** T-082 (dondurulmuş), T-023 (yardımcıların gövdeleri) · **Test seviyesi:** tam · **AC:** AC-15.1, AC-15.2 (çekirdek), AC-15.3, FR-018
**Dosyalar:**
- Değiştir: `dashboard/Data/FinansQueries.cs` (yeni metot; `GetCariRiskAsync` değişmez)
- Oluştur: `dashboard/Models/CariRiskOzet.cs` (002'nin dokunabileceği `MuhasebeModels.cs`'e eklenmez)
- Oluştur: `dashboard/Data/Tanimlar/CariRiskTanimlari.cs`
- Test: `tests/GmDashboard.Tests/Kanonik/H15Tests.cs`
**Arayüzler:**
- Tüketir: `H15-cari-risk.sql` blok `A` → `(Grup varchar(3), Kayit int, VadesiGecen decimal(18,2), LimitAsan int, LimitTanimli int)` (T-082); `LiveDb.PanelDb()`, `LiveDb.QueryAsync<T>`, `CanonicalQuery.Read`, `Tolerance.AmountEqual`, `Population.AtLeast`; `FinansQueries(Db db)`
- Üretir:
  - `namespace GmDashboard.Models; public sealed record CariRiskOzet(decimal VadesiGecenAlacak, decimal VadesiGecenBorc, int LimitAsanCari, int LimitTanimliCari, int AliciKayit, int SaticiKayit);`
  - `public async Task<CariRiskOzet> GetCariRiskOzetAsync(CancellationToken ct = default)` (`FinansQueries` içinde)
  - `namespace GmDashboard.Data.Tanimlar; public static class CariRiskTanimlari { public const string LimitTanimliDegil = "Limit tanımlı değil"; public const string OzetDipnotu = "Özet bütün alıcı ve satıcı carilerinden hesaplanır. Liste en yüksek bakiyeli kayıtları gösterir."; }`
**Gereksinimler (tam değerlerle):**
- Tek `SELECT`, `new CommandDefinition(sql, cancellationToken: ct)`, 3 parçalı adlar, `TOP`/`ORDER BY` yok. Kaynak `DerinSISBkm.dbo.bakiyeVDGG_vw b JOIN DerinSISBkm.dbo.frm fr ON fr.frmID = b.cKod`, süzgeç `ABS(b.bakiye) > 0 AND (fr.frmKod LIKE '120%' OR fr.frmKod LIKE '320%')`.
- Kolonlar, kayıttaki sırayla (Dapper konumsal; `panel_kolon_denetimi.py` 0):
  1. `VadesiGecenAlacak = CAST(ISNULL(SUM(CASE WHEN fr.frmKod LIKE '120%' THEN b.GecenB END), 0) AS decimal(18,2))`
  2. `VadesiGecenBorc = CAST(-ISNULL(SUM(CASE WHEN fr.frmKod LIKE '320%' THEN b.GecenB END), 0) AS decimal(18,2))` — borç pozitif yazılır (satıcıya ödenmesi geçmiş tutar)
  3. `LimitAsanCari = SUM(CASE WHEN ISNULL(fr.frmBakiyeLimit, 0) > 0 AND ABS(b.bakiye) > fr.frmBakiyeLimit THEN 1 ELSE 0 END)`
  4. `LimitTanimliCari = SUM(CASE WHEN ISNULL(fr.frmBakiyeLimit, 0) > 0 THEN 1 ELSE 0 END)`
  5. `AliciKayit = SUM(CASE WHEN fr.frmKod LIKE '120%' THEN 1 ELSE 0 END)`
  6. `SaticiKayit = SUM(CASE WHEN fr.frmKod LIKE '320%' THEN 1 ELSE 0 END)`
- Metot sekme ya da arama parametresi almaz (AC-15.2: özet listeden bağımsız). İstisna yakalanmaz; çağıran ekran yakalar.
- `CariRiskTanimlari` metinleri `sunum-dili.md` sınırında (cümle ≤ 15 kelime, en fazla 2 cümle); Razor'da tekrar yazılmaz.
**Adımlar:**
- [ ] İskelet (dotnet-yazar): kayıt, sabitler, metot gövdesi `throw new NotImplementedException()`; `dotnet build dashboard/GmDashboard.csproj` 0 hata.
- [ ] Senaryo matrisi (test-tasarimci) · kırmızı testler (test-yazar), hepsi `[Trait("Tur","Kanonik")]`, `[Trait("Hikaye","H15")]`:
  - `GetCariRiskOzetAsync_Bugun_AliciVeSaticiTumKayitlaraEsit` (`AC-15.1`): blok A `CanonicalQuery.Read("H15-cari-risk.sql", "A")` ile `LiveDb.QueryAsync<H15Grup>(DbTarget.Erp, …)`; panel `new FinansQueries(LiveDb.PanelDb()).GetCariRiskOzetAsync()`; ardışık okunur. `Tolerance.AmountEqual(panel.VadesiGecenAlacak, a120.VadesiGecen, "vadesi geçen alacak")`, `Tolerance.AmountEqual(panel.VadesiGecenBorc, -a320.VadesiGecen, "vadesi geçen borç")`. Test içi kayıt `private sealed record H15Grup(string Grup, int Kayit, decimal VadesiGecen, int LimitAsan, int LimitTanimli);`, satır seçimi `Single(r => r.Grup == "120")`.
  - `GetCariRiskOzetAsync_GrupKayitSayisi_EskiSinirdanBuyukVeBirebir` (`AC-15.1`): `Population.AtLeast(Math.Max(a120.Kayit, a320.Kayit) - 200, "iki grup da 200 kayıt ya da altında; ilk-N hatası ayırt edilemez")`; `Assert.Equal(a120.Kayit, panel.AliciKayit)`, `Assert.Equal(a320.Kayit, panel.SaticiKayit)`.
  - `GetCariRiskOzetAsync_Bugun_LimitSayilariBirebir` (`AC-15.3`): `panel.LimitAsanCari == a120.LimitAsan + a320.LimitAsan`; `panel.LimitTanimliCari == a120.LimitTanimli + a320.LimitTanimli`.
- [ ] Uygulama · koşu (19:00–08:00 ya da hafta sonu): `dotnet test tests/GmDashboard.Tests --filter "Tur=Kanonik&Hikaye=H15"`.
- [ ] Kırmızı kip: toplam sorgusuna geçici `TOP (200)` + `ORDER BY ABS(b.bakiye) DESC` alt sorgusu eklenir → ilk test kırmızı görülür → elle geri yazılır (`--hard` yok) → üç test yeşil.
- [ ] Kapılar: `dotnet build dashboard/GmDashboard.csproj` · `dotnet build tests/GmDashboard.Tests/GmDashboard.Tests.csproj -warnaserror` · birim komutu · `python tools/panel_kolon_denetimi.py` (0) · `python tools/turkce_tanimlayici_denetimi.py` (yeni dosyalarda 0).
**Kabul:** üç kanonik test yeşil; kırmızı kip kanıtı raporda (komut, kırmızı çıktı, geri yazma, yeniden yeşil); kapılar temiz.

### T-084 [UI] H15 Cari/Risk özet kartları (G-1)
**Bağımlılık:** T-083, T-085 (Cari/Risk sayfası 002 Dalga 1 sürümüyle 001 dalında olmalı; 002 bu dosyanın sahibidir), T-029, T-030, T-031 · T-082 notundaki GMY kararı ("Toplam Net Bakiye" kartı) · ekran sözleşmesine satırın eklenmesi (aşağıda) · **Test seviyesi:** hafif · **AC:** AC-15.1, AC-15.2, AC-15.3 (gösterim), AC-0.1, FR-010
**Dosyalar:**
- Değiştir: `dashboard/Components/Pages/CariRisk.razor`
- Değiştir: `dashboard/Data/Tanimlar/DuzeltmeNotlari.cs` (sözlüğe `cari-risk.ozet` anahtarı, değeri ortak `Yayin` sabiti)
- Değiştir (yalnız sabit sayı taşıyorsa): `tests/GmDashboard.Tests/Birim/DuzeltmeNotlariTests.cs`
- Değiştir: `dashboard/wwwroot/app.css` (yalnız `npm run build:css` çıktısı değiştiyse; `dashboard/` içinde)
- Test: `tests/GmDashboard.Tests/Ekran/H15EkranTests.cs`
**Arayüzler:**
- Tüketir: `Task<CariRiskOzet> GetCariRiskOzetAsync(CancellationToken ct = default)`, `CariRiskOzet(decimal VadesiGecenAlacak, decimal VadesiGecenBorc, int LimitAsanCari, int LimitTanimliCari, int AliciKayit, int SaticiKayit)`, `CariRiskTanimlari.LimitTanimliDegil`, `CariRiskTanimlari.OzetDipnotu` (T-083); `<DuzeltmeNotu Anahtar="…" />` (T-030); `KullaniciMesajlari.VeriAlinamadi` (T-031 / 002 ON-1); `SourceFile.Read`
- Üretir: sayfa kaynak metni sözleşmesi (testlerde); `DuzeltmeNotlari.YayinTarihleri["cari-risk.ozet"]`
**Gereksinimler (tam değerlerle):**
- Özet `_ozet` (`CariRiskOzet?`) ayrı durumdur: ilk açılışta liste ile paralel yüklenir (`Task.WhenAll`), sekme ve arama değişince **yeniden yüklenmez**. Yüklenene kadar kart değerleri `…` gösterir (sabit `span`, Lucide yok).
- Kart ızgarası (yerleşim aynı, dört kart; 002 sonrası satır numaraları değişir — `_rows.Sum(r => r.VadesiGecen)` ve `_rows.Count(r => r.Limit > 0 …)` ifadelerini taşıyan kartlar hedeftir):
  1. "Listedeki kayıt" — `_rows.Count` (liste sayısı; özet değil).
  2. "Vadesi geçen alacak", alt satır "Alıcılar (120), tümü" — `_ozet.VadesiGecenAlacak`; `> 0` ise `text-error`.
  3. "Vadesi geçen borç", alt satır "Satıcılar (320), tümü" — `_ozet.VadesiGecenBorc`; `> 0` ise `text-warning`. (GMY kararı "Toplam Net Bakiye kartı kalır" derse bu kart beşinci olur; görev metni karar sonrası güncellenir.)
  4. "Limit aşan cari" — `_ozet.LimitAsanCari`; `> 0` ise `text-warning`; `_ozet.LimitTanimliCari == 0` ise altında `text-xs text-base-content/50` ile `CariRiskTanimlari.LimitTanimliDegil`.
- Kartların yanında `<DuzeltmeNotu Anahtar="cari-risk.ozet" />`; mevcut dipnotun altına `CariRiskTanimlari.OzetDipnotu`.
- Hata: özet ya da liste yüklenemezse ekranda `KullaniciMesajlari.VeriAlinamadi`, günlüğe `Logger.LogError(ex, "Cari risk özeti yüklenemedi")`. Merge sonrası sayfada `ex.Message` kaldıysa kaldırılır; 002 zaten kaldırdıysa o satıra dokunulmaz.
- Kart etiketleri cümle düzeninde, ≤ 15 kelime; renkler DaisyUI token'ı. 002'nin telefon düzeni sınıflarına (`lg:` kırılma noktası, `Gorunum`) dokunulmaz.
- `DuzeltmeNotlari`: yeni anahtar 21'inci olur. T-029 testi sözlüğü ekran sözleşmesiyle karşılaştırıyorsa değişmez; sabit `20` taşıyorsa `21` yapılır ve test adı `YayinTarihleri_Anahtarlar_EkranSozlesmesiyleAyni` olur (ayrı commit `test(T-084): düzeltme notu anahtar sayısını 21 yap`). T-079 küme eşitliğine bakar; metnindeki "(20)" bilgi amaçlıdır.
**Adımlar:**
- [ ] Testler (test-yazar, kaynak metin, `SourceFile.Read("dashboard/Components/Pages/CariRisk.razor")`):
  - `CariRisk_Kaynak_OzetCekirdektenGelirListedenToplanmaz`: `GetCariRiskOzetAsync` geçer; `_rows.Sum(` geçmez; `_rows.Count(r => r.Limit` geçmez.
  - `CariRisk_Kaynak_DuzeltmeNotuVeMetinlerSabitten`: `<DuzeltmeNotu Anahtar="cari-risk.ozet" />`, `CariRiskTanimlari.LimitTanimliDegil`, `CariRiskTanimlari.OzetDipnotu`, `KullaniciMesajlari.VeriAlinamadi` geçer; `ex.Message` geçmez.
- [ ] Uygulama · `npm run build:css` (`dashboard/` içinde; `node_modules` yoksa atlanır, raporda yazılır) · derleme.
- [ ] Kırmızı kip: Vadesi geçen kartına geçici `_rows.Sum(r => r.VadesiGecen)` geri yazılır → ilk test kırmızı → elle geri alınır → yeşil.
- [ ] Elle kontrol (masaüstü): sekme Satıcılar → Alıcılar → Hepsi ve arama "a" sırasında özet kartları değişmiyor; ekran görüntüsü commit edilmez, yalnız gözlem raporda.
- [ ] Kapılar: derleme · birim komutu · `python tools/turkce_tanimlayici_denetimi.py` · T-079 testi bu görevden sonra koşarsa yeşil.
**Kabul:** iki test yeşil + kırmızı kip kanıtı; elle kontrol notu raporda.
**Kontrat değişikliği gerekli:** `kontratlar/ekranlar.md` § 1 tablosuna satır:
> | `cari-risk.ozet` | `/cari-risk` | Vadesi geçen alacak, vadesi geçen borç, limit aşan cari | H15 |

§ 2'ye bölüm:
> ### Cari/Risk (`/cari-risk`)
> - Özet kartları bütün alıcı ve satıcı carilerinden: "Vadesi geçen alacak", "Vadesi geçen borç", "Limit aşan cari". Liste en yüksek bakiyeli kayıtlarla sınırlı kalır, özeti etkilemez (H15).
> - Limit tanımlı cari yoksa "Limit tanımlı değil" notu.

### T-085 [NET] Master'ı alma ve T-029/T-031 uyarlaması (G-3, K10)
**Bağımlılık:** 002 Dalga 1'in master'a merge edilmesi (insan kararı; ON-1 commit'i master'da olmalı: `git log master --oneline -- dashboard/Data/Tanimlar/KullaniciMesajlari.cs` en az bir satır döner, dönmezse görev başlamaz) · `git status --porcelain` boş · **Test seviyesi:** hafif · **AC:** AC-10.1 (metin sözleşmesi), AC-0.1 (DI), 002 K10
**Dosyalar:**
- Değiştir (merge çakışması çıkarsa): `dashboard/ServiceRegistration.cs`, `dashboard/Data/Tanimlar/KullaniciMesajlari.cs`, `dashboard/Components/Pages/Home.razor`, `dashboard/wwwroot/app.css`, `tests/GmDashboard.Tests/GmDashboard.Tests.csproj`, `tests/GmDashboard.Tests/Directory.Packages.props`, `Pusula.sln`
- Test: `tests/GmDashboard.Tests/Birim/OrtakTanimMergeTests.cs`
**Arayüzler:**
- Tüketir: master'daki 002 ON-1 içeriği — `s.AddSingleton(TimeProvider.System);` (`AddBkmVeri` içinde) ve `KullaniciMesajlari` (T-031 "Üretir" satırındaki dört sabit, birebir); `kontratlar/ekranlar.md` § 3 tablosu; `SourceFile.Read`
- Üretir: 001 dalında merge commit'i `chore(T-085): master'ı al (002 Dalga 1)`; T-029 ve T-031'in kalan kapsamı (aşağıda); iki birim testi
**Gereksinimler (tam değerlerle):**
- Yol: 001 dalında `git merge master` (yerel `master`, 002 Dalga 1 merge'ünü içerir). Yeniden tabanlama, `--hard`, `checkout -- .` yok. Merge commit'i insan onayıyla atılır (denetleyici GMY'ye çakışma listesini gösterir).
- Çakışma kuralı: 001 tarafında çözülür, **002'nin satırları korunur**.
  - `ServiceRegistration.cs`: `TimeProvider` satırı tek kalır.
  - `KullaniciMesajlari.cs` (iki dal da eklediyse add/add): içerik T-031 sözleşmesiyle birebirse master sürümü alınır. Metin farklıysa iki spec çelişiyor demektir → görev `NEEDS_CONTEXT` döner, elle seçim yapılmaz.
  - `Home.razor`: 002'nin `@page` satırı korunur, 001'in gövde değişiklikleri (T-045, T-046, T-069) korunur.
  - `app.css`: master sürümü alınır, sonra `dashboard/` içinde `npm run build:css` ile yeniden üretilir.
  - Test projesi (`GmDashboard.Tests.csproj`, yerel `Directory.Packages.props`, `Pusula.sln`): 002 kendi testleri için projeyi ya da paket satırını eklediyse iki tarafın birleşimi alınır (001 paketleri + `Microsoft.Playwright`); aynı paketin iki farklı sürümü varsa `NEEDS_CONTEXT`.
- T-029 ve T-031'in kapsamı merge anına göre:
  - **T-029/T-031 henüz yapılmadıysa:** T-031 "dosya zaten var; içerik sözleşmeyle aynı mı" doğrulamasına iner (aşağıdaki test + `turkce_tanimlayici_denetimi.py`); T-029 yalnız `DuzeltmeNotlari` ve testlerine iner, `ServiceRegistration.cs`'e dokunmaz.
  - **Yapıldıysa:** satırlar birebir aynıysa çakışma yoktur; aşağıdaki testler yine koşar.
- Testler (birim, `Tur` yok):
  - `ServiceRegistration_TimeProvider_TekKayit`: `Regex.Matches(SourceFile.Read("dashboard/ServiceRegistration.cs"), @"AddSingleton\(TimeProvider\.System\)").Count == 1`.
  - `KullaniciMesajlari_Metin_EkranSozlesmesiyleAyni` (teori, `MemberData` = dört sabit adı ve değeri): `kontratlar/ekranlar.md` § 3 tablosundaki aynı adlı satırın metni sabite birebir eşit.
**Adımlar:**
- [ ] Ön koşul komutları; çıktıları rapora.
- [ ] `git merge master`; `git diff --name-only --diff-filter=U` ile çakışan dosya listesi rapora.
- [ ] Çakışmaları kurala göre çöz · `npm run build:css` · `dotnet build dashboard/GmDashboard.csproj` 0 hata.
- [ ] Testleri yaz (test-yazar) · koş · kırmızı kip: `ServiceRegistration.cs`'e geçici ikinci `s.AddSingleton(TimeProvider.System);` → kırmızı → elle sil → yeşil.
- [ ] Tam birim koşusu: `dotnet test tests/GmDashboard.Tests --filter "Tur!=Kanonik&Tur!=Koruma"` (002'nin birim testleri dahil yeşil; `Tur=Mobil` bu görevde koşulmaz).
- [ ] Defter: `ork not karar` ile T-029/T-031'in hangi duruma indiği.
**Kabul:** merge commit'i 001 dalında; çakışma listesi ve çözümü raporda; iki test yeşil + kırmızı kip kanıtı; birim takımı yeşil.

### T-086 [DOC] 001 kabul sonucu dosyası (G-2, 002 risk R3)
**Bağımlılık:** T-080 (SC raporu, "saptı" kalmamış), 001 `/kabul-testi` hükmü, T-084, T-085 (002'nin kapı testi depoda olsun diye) · **Test seviyesi:** hafif · **AC:** 002 R3; 002 `kontratlar/telefon-kapisi.md` § 4
**Etiket gerekçesi:** dosyayı denetleyici yazar, içerik belgedir ([DOC]). Biçim testi test-yazar adımıdır (T-081'deki gibi ayrı commit).
**Dosyalar:**
- Oluştur: `specs/001-panel-veri-duzeltme/kabul-sonucu.md`
- Test: `tests/GmDashboard.Tests/Birim/KabulSonucuTests.cs`
**Arayüzler:**
- Tüketir: `.orkestra/calisma/001-panel-veri-duzeltme/sc-raporu.md` (T-080), `docs/journal/bkm/<kapanış günü>.md` (T-080), madde anahtarları `specs/002-mobil-kabuk-ekran/kontratlar/telefon-kapisi.md` § 2
- Üretir: tablo `| Madde | Sonuç | Tarih | Kanıt |` — 002'nin `KapananMaddeler_HepsiKabulSonucundaTuttu` testi bu dosyayı okur
**Gereksinimler (tam değerlerle):**
- Dosya başı: `# 001 kabul sonucu` ve altında `> GMY onayı: <gg.aa.yyyy> · kayıt: docs/journal/bkm/<yyyy-MM-dd>.md` (onay `ork not karar` ile journal'a yazılmış olmalı).
- Tam 21 satır, bu sırayla: `001:H1` … `001:H9`, `001:H10.1` (AC-10.1, AC-10.2), `001:H10.3` (AC-10.3), `001:H11` … `001:H14`, `001:D-1` … `001:D-5`, `001:cari-risk` (H15).
- `Sonuç` ∈ {`tuttu`, `saptı`, `koşamadı`, `karar bekliyor`}. `tuttu` yalnız maddenin bütün AC'leri SC raporunda "tuttu" ise. Örnek: H13 hedef tabanı teyit edilmediyse `karar bekliyor`.
- `Tarih` gg.aa.yyyy (hükmün günü).
- `Kanıt` her satırda dolu; ilk belirteci şunlardan biri: (a) maddeyi kapatan son NET/UI görev commit'inin kısa hash'i (7–40 onaltılık karakter, depoda var), (b) depoda var olan dosya yolu (ör. kanonik `.sql` dosyası ya da kapanış journal'ı). `.orkestra/` ile başlayan yol tek başına kanıt değildir (git dışı). İlk belirteçten sonra ` · ` ile AC listesi ve test adı yazılır: `a1b2c3d · AC-12.1–12.3 GEÇTİ (MizanOzet_KapanmisAy_HesapKumelerineEsit)`.
- `yazim-metin` kuralları; kişisel veri yok.
- Testler (birim, test-yazar):
  - `KabulSonucu_Maddeler_SozlesmeKumesiyleAyni`: dosyadaki `Madde` kümesi = testte açıkça yazılmış 21 anahtar; fark iki yönlü yazılır.
  - `KabulSonucu_Satir_KanitDoluVeGitIcinde` (teori, `MemberData` = satırlar): `Sonuç` geçerli kümede; `Kanıt` boş değil; ilk belirteç `.orkestra/` ile başlamaz.
  - `KabulSonucu_HashKanit_DepodaVar` (teori, `MemberData` = ilk belirteci `^[0-9a-f]{7,40}$` olan satırlar): `git cat-file -e <hash>^{commit}` çıkış 0 (depo kökünde, `SourceFile` ile bulunan `Pusula.sln` klasörü).
  - `KabulSonucu_YolKanit_DepodaVar` (teori, `MemberData` = öteki satırlar): `File.Exists(<depo kökü>/<yol>)`.
**Adımlar:**
- [ ] Testler (ayrı commit `test(T-086): kabul sonucu biçim testleri`) → dosya yokken kırmızı.
- [ ] Dosyayı yaz · testler yeşil.
- [ ] Kırmızı kip: bir satırın `Kanıt` hücresi boşaltılır → kırmızı → elle geri yazılır → yeşil.
- [ ] 002 kapı testi: `dotnet test tests/GmDashboard.Tests --filter "FullyQualifiedName~KapananMaddeler_HepsiKabulSonucundaTuttu"` yeşil (o an `KapananMaddeler` boşsa bunu raporda yaz: test bu dosyayı henüz bir anahtar için sınamadı).
- [ ] Kapı: `dokuman_denetle.py` hook temiz.
**Kabul:** 21 satır; dört test yeşil + kırmızı kip kanıtı; GMY onay satırı dolu.

### T-087 [NET] EticQueries borç temizliği — TimeProvider ve güvenli sorgu (rakamı değiştirmeyen)
**Bağımlılık:** T-029 (`TimeProvider` DI kaydı), T-023 (`FakeClock`, `SourceFile`), T-024 (koruma testi) · **Test seviyesi:** tam · **AC:** SC-006; global kısıtlar R1 (salt-okuma, FR-015) ve K1 (C# kuralları: `DateTime.Now` yasak, SQL parçası yalnız sabit metin)
**Kaynak:** defter 09.10 14:31 kararları ve T-026 yazar raporu. `dashboard/Data/EticQueries.cs` bu görevden önce 9 CS-009 + 1 DAT-001 + 1 SEC-002 taşıyor; dosya bazlı G-STATIC-CS ve G-SEC-SAST dosyaya her dokunuşta kırmızı. T-026 kısım 2 bu yüzden ertelendi; yaması `.orkestra/calisma/001-panel-veri-duzeltme/T-026-eticqueries.patch` (5 yer).
**Not (sıra — diğer görev satırları değiştirilmedi):**
- **T-026 kısım 2** (EticQueries.cs'teki 5 `STATUS NOT IN (1001,1006,1007,3000,4000)` yeri) ve **T-037** (`GetEticKategoriAsync`, `GetEticKategoriUrunAsync`, `GetEticKategoriYilAsync`) bu görevden SONRA koşar. İkisinin "Bağımlılık" satırına **T-087** eklenmelidir; spec sahibi uygular.
- **T-037 ile örtüşme:** T-037'nin "kurucuya `TimeProvider`" ve "`GetEticKategoriYilAsync` içinde `DateTime.Today` → `TimeProvider.GetLocalNow()`" maddeleri bu görevde yapılır. T-037 o iki maddeyi yeniden yapmaz; yalnız kalan kapsamını (sipariş durum süzgeci, `Kategori = NULL` satırı, `ct`) uygular.
- **T-026 kısım 2 yaması** bu görevin ekleyeceği `using` ve kurucu satırları yüzünden satır kaymasıyla uygulanmayabilir. O durumda yama içeriği elle yeniden uygulanır (5 yer: sınıf yorumu satırı, `GetKargoPerfAsync`, `GetKargoGunAsync`, `GetAyKargoAsync`, `GetGunKargoAsync` sorguları); içerik değişmez.
**Dosyalar:**
- Oluştur: `dashboard/Data/Definitions/EcommerceCalendar.cs`
- Değiştir: `dashboard/Data/EticQueries.cs` (kurucu, `TatilValuesAsync`, `TatilApply`, `GetAyKargoAsync`, `GetEticKategoriYilAsync`; başka sorgu metnine dokunulmaz)
- Test: `tests/GmDashboard.Tests/Unit/EticQueriesDebtTests.cs`
**Arayüzler:**
- Tüketir: `s.AddSingleton(TimeProvider.System);` (`dashboard/ServiceRegistration.cs`, `AddBkmVeri` içinde, T-029); `FakeClock(DateTimeOffset now)` (`lib/Bkm.TestAltyapi/FakeClock.cs`, yerel saat dilimi UTC); `SourceFile.Read(string repoRelativePath, string? startDirectory = null)` (T-023)
- Üretir:
  - `public sealed class EticQueries(Db db, TimeProvider time)` — `AddScoped<EticQueries>()` kaydı değişmez; public metot imzaları değişmez.
  - `namespace GmDashboard.Data.Definitions; public static class EcommerceCalendar` ile:
    - `public static DateOnly Today(TimeProvider time)` → `DateOnly.FromDateTime(time.GetLocalNow().DateTime)`
    - `public static (DateOnly Start, DateOnly EndExclusive) HolidayScan(DateOnly today)` → `(today.AddMonths(-18), today)`
    - `public static (DateOnly Start, DateOnly EndExclusive) MonthlyTrend(DateOnly today)` → `end = new DateOnly(today.Year, today.Month, 1)`, `(end.AddMonths(-12), end)`
    - `public static (DateOnly Start, DateOnly EndExclusive) YearToDate(DateOnly today)` → `(new DateOnly(today.Year, 1, 1), today.AddDays(1))`
    - `public static string HolidayValues(IReadOnlyCollection<DateOnly> holidays)` → her gün için `(CONVERT(date,'yyyyMMdd'))`, virgülle birleşik; boşsa `(CONVERT(date,'19000101'))`
    - `public static string HolidayApply(string holidayValues)` → `CROSS APPLY (SELECT COUNT(*) T FROM (VALUES <holidayValues>) H(d) WHERE H.d>o.ORDERDATE AND H.d<=o.SENDDATE AND DATEPART(WEEKDAY,H.d) NOT IN (1,7)) ta`
**Gereksinimler (tam değerlerle):**
- **CS-009 (9 yer):** `EticQueries.cs` içindeki bütün `DateTime.Today` ve `DateTime.UtcNow` kullanımları kalkar. Ölçüldü (09.10.2026, `Grep`): dosyada `DateTime.Now` yok; bugünkü satırlar 35, 39, 56 (`UtcNow`) ve 40, 41, 131, 132, 288, 289 (`Today`) — defter ve kapı çıktısı bu 9 satırı bir fazla numaralıyor (36, 40, 41, 42, 57, 132, 133, 289, 290). Hedef satır numarası değil, içeriktir.
  - `TatilValuesAsync`: önbellek süresi `(time.GetUtcNow().UtcDateTime - _tatilCacheZaman).TotalHours < 6` (iki yerde); `_tatilCacheZaman = time.GetUtcNow().UtcDateTime`; tarama aralığı `var (bas, son) = EcommerceCalendar.HolidayScan(EcommerceCalendar.Today(time));`.
  - `GetAyKargoAsync`: `var (ayBas, ayBitis) = EcommerceCalendar.MonthlyTrend(EcommerceCalendar.Today(time));`.
  - `GetEticKategoriYilAsync`: `var (yilBas, yarin) = EcommerceCalendar.YearToDate(EcommerceCalendar.Today(time));`.
  - Tarih anlamı aynı: yerel gün. Üretimde `TimeProvider.System.LocalTimeZone` = `TimeZoneInfo.Local`, yani eski `DateTime.Today` ile aynı gün.
  - Statik önbellek (`_tatilCache`, `_tatilCacheZaman`, `_tatilLock`) static kalır (tatil günleri istekten bağımsız, `AddScoped` ömrüne taşınmaz).
- **SEC-002 (44-47 civarı, `QueryAsync<DateTime>` + dize birleştirme):** sorgu metni tek `const string CalisilanGunSql = """ SELECT CONVERT(date,o.SENDDATE) d FROM dbo.J_ORDERS o WHERE o.SENDDATE>=@bas AND o.SENDDATE<@son GROUP BY CONVERT(date,o.SENDDATE) HAVING COUNT(*)>=@esik """;` olur (metin birebir aynı, `+` birleştirmesi yok); çağrı `conn.QueryAsync<DateTime>(CalisilanGunSql, new { bas = bas.ToString("yyyyMMdd"), son = son.ToString("yyyyMMdd"), esik = CalismaEsigi })`; parametreler aynı kalır.
- **DAT-001 (62-64, `TatilApply` içinde tatil `VALUES` interpolasyonu):** sabit-metin + `Replace` deseni. `EcommerceCalendar` içinde `private const string HolidayApplyTemplate` (`@@VALUES@@` yer tutuculu) ve `private const string HolidayRowTemplate = "(CONVERT(date,'@@DAY@@'))"`; `HolidayRowTemplate.Replace("@@DAY@@", day.ToString("yyyyMMdd", CultureInfo.InvariantCulture))`, `HolidayApplyTemplate.Replace("@@VALUES@@", holidayValues)`. Yer tutucuya giren tek değer `DateOnly`'den `yyyyMMdd` biçimiyle üretilen metindir; kullanıcı girdisi SQL'e girmez. `EticQueries.TatilApply` bir satırlık `EcommerceCalendar.HolidayApply(tatilValues)` çağrısına iner (dört çağıran satıra dokunulmaz); `TatilValuesAsync` satır metnini `EcommerceCalendar.HolidayValues(tatiller)` ile kurar (`$"(CONVERT(date,'{d:yyyyMMdd}'))"` ve `"(CONVERT(date,'19000101'))"` satırları kalkar).
- **Davranış aynı:** üretilen SQL metni, `HolidayApply` ve `HolidayValues` çıktıları eski metinle karakter karakter aynıdır (testler bunu sabitler). Public metot imzaları değişmez; `CancellationToken` ekleme bu görevin kapsamı değildir (gövdesi yalnız tarih satırlarında değişen iki metotta ve dört `TatilApply` çağıranında davranış-aynı sınırını ve beş çağıran dosyayı aşar; `ct` T-037 ve sonraki dokunuşlara kalır — K1 `ct` maddesinden bilinçli istisna, gerekçesi bu satır).
- Başka sorgu metni, `STATUS NOT IN (...)` listeleri, yorum satırları, `WITH(NOLOCK)` ve tablo takma adları değişmez (K8; T-026 kısım 2 listeleri ayrı görevdir).
- Yeni tanımlayıcılar İngilizce, Türkçe karakter yok.
**Adımlar:**
- [ ] Ön koşullar (çıktıları rapora): `git status --porcelain dashboard/Data/EticQueries.cs` boş (dosya HEAD'de, yama dışarıda); `ServiceRegistration.cs` içinde `AddSingleton(TimeProvider.System)` tam bir satır; `./ork cs dashboard/Data/EticQueries.cs` taban çıktısı (beklenen: 9 CS-009, 1 DAT-001, 1 SEC-002).
- [ ] İskelet (dotnet-yazar): `EcommerceCalendar` imzaları + `NotImplementedException`; `EticQueries` kurucusuna `TimeProvider time` (gövdeye dokunmadan); `dotnet build dashboard/GmDashboard.csproj` 0 hata.
- [ ] Senaryo matrisi (test-tasarimci) · kırmızı testler (test-yazar), birim, `Tur` yok, hepsi `[Trait("AC","SC-006")]`, `Unit/EticQueriesDebtTests.cs`:
  - `Today_FakeClockLateEvening_ReturnsSameDay`: `FakeClock(2026-10-09 23:30 +00:00)` → `2026-10-09`.
  - `Today_FakeClockAfterMidnight_ReturnsNextDay`: `FakeClock(2026-10-10 00:30 +00:00)` → `2026-10-10` (önceki gün dönmez).
  - `HolidayScan_GivenDay_ReturnsEighteenMonthWindow` (teori): `2026-10-09 → (2025-04-09, 2026-10-09)` · `2026-03-31 → (2024-09-30, 2026-03-31)` · `2026-01-01 → (2024-07-01, 2026-01-01)`.
  - `MonthlyTrend_GivenDay_ReturnsThirteenMonthWindow` (teori): `2026-10-09 → (2025-10-01, 2026-10-01)` · `2026-01-01 → (2025-01-01, 2026-01-01)` · `2026-12-31 → (2025-12-01, 2026-12-01)`.
  - `YearToDate_GivenDay_ReturnsJanuaryToTomorrow` (teori): `2026-10-09 → (2026-01-01, 2026-10-10)` · `2026-12-31 → (2026-01-01, 2027-01-01)` · `2024-02-29 → (2024-01-01, 2024-03-01)`.
  - `HolidayValues_TwoDays_ListsConvertRows`: `[2026-10-29, 2026-10-30]` → `(CONVERT(date,'20261029')),(CONVERT(date,'20261030'))`.
  - `HolidayValues_Empty_ReturnsGuardRow`: boş → `(CONVERT(date,'19000101'))`.
  - `HolidayApply_OneRow_MatchesPreviousText`: `HolidayApply("(CONVERT(date,'20261029'))")` = `CROSS APPLY (SELECT COUNT(*) T FROM (VALUES (CONVERT(date,'20261029'))) H(d) WHERE H.d>o.ORDERDATE AND H.d<=o.SENDDATE AND DATEPART(WEEKDAY,H.d) NOT IN (1,7)) ta`.
  - `HolidayApply_OneRow_LeavesNoPlaceholder` (ne olmamalı): çıktıda `@@` yok.
  - `EticQueries_Source_HasNoDirectClockCalls` (teori, `SourceFile.Read("dashboard/Data/EticQueries.cs")`): `DateTime.Now`, `DateTime.Today`, `DateTime.UtcNow` üçü de geçmez.
  - `EticQueries_Source_TakesTimeProviderInConstructor`: metin `public sealed class EticQueries(Db db, TimeProvider time)` içerir.
  - `EticQueries_Source_BuildsNoHolidaySqlByConcatenation`: `Regex.IsMatch(kaynak, @"QueryAsync<DateTime>\(\s*""")` false (sorgu sabitten gelir); `$"CROSS APPLY` geçmez; `$"(CONVERT(date,'{` geçmez.
  - Kırmızı doğru sebepten: `NotImplementedException` ya da iddia hatası (derleme hatası kırmızı sayılmaz).
- [ ] Uygulama (dotnet-yazar) · yeni İngilizce sözcükler için ak liste önerisi rapora (denetleyici toplu ekler, `tools/kod-sozcukleri.txt` yazara kapalı).
- [ ] Kırmızı kip: `EticQueries.cs`'e geçici bir `DateTime.Today` geri yazılır → `EticQueries_Source_HasNoDirectClockCalls` kırmızı → elle geri yazılır (`--hard` yok) → yeşil.
- [ ] Kapılar: `dotnet build dashboard/GmDashboard.csproj` (0 hata, uyarı sayısı görev öncesinden fazla değil) · `dotnet build tests/GmDashboard.Tests/GmDashboard.Tests.csproj -warnaserror` · `dotnet test tests/GmDashboard.Tests --filter "Tur!=Kanonik&Tur!=Koruma"` · `./ork cs dashboard/Data/EticQueries.cs` ve `./ork cs dashboard/Data/Definitions/EcommerceCalendar.cs` 0 bulgu · G-SEC-SAST iki dosyada geçer · `python tools/panel_kolon_denetimi.py` (0) · `python tools/turkce_tanimlayici_denetimi.py` (0) · **T-024 koruma testi yeşil** (canlı; 19:00 sonrası ya da hafta sonu, R4).
**Kabul:** birim testleri yeşil + kırmızı kip kanıtı; `./ork cs` ve SAST iki dosyada 0 bulgu; T-024 koruma yeşil (rakam değişmedi); commit tipi `refactor`, gövdede "davranış aynı, `DateTime.Today`/`UtcNow` → `TimeProvider`".
