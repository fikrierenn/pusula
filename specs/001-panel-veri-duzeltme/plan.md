# Plan 001: Panel veri düzeltmeleri

**Durum:** Onaylandı (03.10.2026) · **Spec:** `specs/001-panel-veri-duzeltme/spec.md` (Onaylandı 03.10.2026) · **Tarih:** 03.10.2026

## Özet

Düzeltmeler yalnız panelin okuma sorgularında yapılır. ERP'ye ve yeni tabloya dokunulmaz. Ekranlar arasında çelişen tanımlar (fiş, e-ticaret iptal/iade, merkez depo stoğu, perakende/Sınav ayrımı) `dashboard/Data/Tanimlar/` altında tek bir yerde SQL parçası olarak tutulur. Spec'in kapsadığı her sorgu bu parçaları kullanır. Her kabul kriteri, yeni `tests/GmDashboard.Tests` projesinde canlı ERP'ye karşı salt-okuma bir testle sınanır. Test, panelin gerçek sorgu metodunu çağırır ve sonucu `sorgular/2026-10-panel-veri-duzeltme/` altındaki **bağımsız** kanonik sorguyla karşılaştırır. Aynı dosyalar FR-012'nin istediği kanıt arşividir.

## Teknik bağlam

- **Çözüm / projeler:** `dashboard/GmDashboard.csproj` (değişir) · `tests/GmDashboard.Tests` (**yeni**, ADR adayı A1) · `Pusula.sln` (yeni test projesi eklenir). `lib/Bkm.Shared` değişmez.
- **Hedef veritabanları (salt-okuma):** EncoreMerkez compat **110** (STRING_AGG/TRIM/IIF/TRY_CONVERT yok) · DerinSISBkm 150 · BKM 150 · BKMDATA 150 · DerinCrm 150 · JOKER 150 (doğrudan bağlantı) · ODAKJOKER bağlantılı sunucu (ISO tarih). Collation `Turkish_CI_AS`, çapraz veritabanı string join'de açık `COLLATE`. Kaynak: `config/veritabanlari.json`, `docs/proje/veritabani.md`.
- **Bağlantı:** `Db.OpenAsync()` varsayılan katalog `master` olduğundan her ERP nesnesi 3 parçalı adla yazılır (`sql-server-conventions.md`).
- **Katmanlar:** dashboard tek projeli, iki katmanlı (Razor → `*Queries`). Katman eklenmez (K1, anayasa Madde 5). Değişen: `Data/*Queries.cs`, `Data/Tanimlar/*` (yeni), `Models/*Models.cs`, ilgili `Components/Pages/*.razor`, `Components/Shared/DuzeltmeNotu.razor` (yeni).
- **Veri erişimi:** Dapper + gömülü SQL (mevcut desen). Yeni SP yok. Dokunulan metotlar `CancellationToken` alır (K1).
- **Test:** xUnit 2.9.2 + Microsoft.NET.Test.Sdk 17.12.0 + Mvc.Testing 10.0.0. Bunlar depoda `tests/BkmVardiya.Tests`'te zaten kullanılan sürümlerdir; depoya yeni paket girmez. Testcontainers, tSQLt, Playwright ve bUnit **kullanılmaz** (gerekçe: "Test stratejisi").

## Kararlar

### K-A — Test stratejisi: canlı ERP'ye karşı salt-okuma entegrasyon testi, kanonik sorgu bağımsız

Seçenekler değerlendirildi:

| Seçenek | Neyi sınar | Sonuç |
|---|---|---|
| **(1) xUnit entegrasyon testi:** panel metodu çağrılır, bağımsız kanonik sorguyla karşılaştırılır | Uygulama kodunun kendisini (SQL metni + C# eşleme + Dapper kayıt sırası) | **Seçildi** |
| (2) `sema/degismezler.json` + `tools/sema_degismez.py` | Veri tabanındaki bir **veri gerçeğini**. Panel metodunu çağıramaz, panel SQL'inin bir kopyasını koşar | Yalnız düzeltmelerin **dayandığı veri gerçekleri** için (aşağıda 4 kayıt) |
| (3) `sqlcli assert` | (2) ile aynı; tek seferlik ölçüm | Yalnız taban ölçümünde (F0) el aracı; kalıcı kapı yapılmaz |

Gerekçe:
- (2) ve (3) panelin SQL'ini **kopyalayarak** sınar. Kopya ile asıl kod ayrışırsa test yeşil kalır, ekran yanlış kalır (`emitter-ayrimi.md` § anahtar çatallanması, `test-discipline.md` § dokuzuncu vaka). Hatanın kendisi C# tarafında olabilir (8+ elemanlı tuple, kayıt sırası); bunu yalnız metodu çağıran test görür.
- Anayasa Madde 7 gerçek SQL Server ister. Kaynak veri canlı ERP'dedir ve Testcontainers ile çoğaltılamaz (DerinSIS/EncoreMerkez şeması + yıllık veri). Testler **yalnız SELECT** çalıştırır (Madde 8: ajan üretim veritabanına yazmaz).
- Doğrulama dönemi kapalı aydır (Eylül 2026). İki taraf aynı anda okunduğu için geç gelen bir aktarım iki tarafı da aynı biçimde etkiler. Testler "şu sayıdır" demez, "bu iki bağımsız hesap eşittir" der (`test-discipline.md` § davranışsal kontrat).

Test türleri:

| Tür | Ne | DB | Kırmızı önce mi |
|---|---|---|---|
| **Kanonik eşitlik** (`[Trait("Tur","Kanonik")]`) | Her AC: panel metodu ↔ kanonik sorgu, tolerans içinde | Canlı ERP/JOKER, salt-okuma | Evet. Bugün ölçülmüş sapma var (H1–H9), düzeltme öncesi kırmızı görülür |
| **Koruma** (`[Trait("Tur","Koruma")]`) | SC-006: bugün tutan rakam (3 şube net, e-tic sipariş/net) değişmez. Sabit sayıyla yazılmaz: **eski formül ↔ yeni formül** aynı anda koşulur ve eşit olmalıdır. Eski SQL dondurulmuş kopya olarak yalnız test projesinde durur (`tests/GmDashboard.Tests/Koruma/Eski/*.sql`) (risk R2) | Canlı | Hayır, karakterizasyon testidir; önce ve sonra yeşil kalmalıdır. Kırılabilirliği eski kopya bilerek bozularak kanıtlanır |
| **Birim** | `DuzeltmeNotu` görünürlüğü (AC-0.1/0.2), `GeriAdresi` (AC-11), `MizanQueries.OzetHesapla` (AC-12 hesap kümesi), stok tanım metinleri (AC-14.2), hedef notu (AC-13.4/13.5) | Yok | Evet |
| **Hata ekranı** | AC-10.1/10.2: `WebApplicationFactory` + `BKM_ENV_DOSYA` ile erişilemez sunucu gösteren geçici `.env`; Development ortamında sayfa HTML'i okunur, günlük yakalanır | Erişilemez sunucu (sır yok) | Evet (bugün `ex.Message` ekrana basılıyor) |

Ortak test kuralları:
- **Salt-okuma kapısı (risk R1, F1'in ilk görevi).** Testler canlı ERP'ye bugün `sa` ile bağlanır (`Db.cs:25`); "yalnız SELECT" bir niyet beyanıdır ve zorlanmalıdır. Test yardımcısı (`Altyapi/CanliDb`) her ifadeyi çalıştırmadan önce izin listesinden geçirir: yalnız `SELECT` ve `WITH … SELECT`. Dize ve yorum ayıklanarak taranır; tanınmayan her şey reddedilir (`sqlcli --read-only` sözleşmesiyle aynı, `sql-server-conventions.md` § dört sözleşme). Ayrıca her ifade, her zaman `ROLLBACK` edilen bir transaction içinde koşar. Kapı, kanonik `.sql` dosyalarına ve test içindeki gömülü SQL'e uygulanır. Yardımcıda `ExecuteAsync` yoktur. **Kırılabilirlik kanıtı:** `UPDATE` içeren sahte bir kanonik dosya ile kapı bilerek kırılır, kırmızı (reddedildi) görülür, sahte dosya silinir. Geri alma `git reset --hard` / `checkout -- .` **içermez**; çalışma dizininde commit edilmemiş iş varsa önce ayrılır (`commit-discipline.md` § kırmızı kip). Orta vade: `erp-write-policy.md` § sertleştirmedeki `db_datareader` login'i test için öne çekilir (İnsan onayı 11).
- **Hata testi yalıtımı (risk R5, F1'in ikinci görevi).** Bağlantıyı ya da ortamı değiştiren hata testi ayrı bir koleksiyondadır (`[CollectionDefinition(DisableParallelization = true)]`). Tercih edilen yol, `WebApplicationFactory.ConfigureTestServices` içinde `Db` kaydının sahte sunucuya bağlanan örnekle değiştirilmesidir; `BKM_ENV_DOSYA` yalnız bu yol çalışmazsa kullanılır. Testin **ilk** adımı bağlanılacak `DataSource`'un sahte sunucu olduğunu doğrular (assert). Gerekçe: `BKM_ENV_DOSYA` dosyası bulunamazsa `Db` sessizce gerçek `.env`'e döner (`Db.cs:212-214`) ve "hata testi" canlı ERP'ye bağlanır.
- **ERP yükü (risk R4).** Test bağlantısı açılışta `SET LOCK_TIMEOUT 5000; SET DEADLOCK_PRIORITY LOW;` çalıştırır. `Tur=Kanonik` ve `Tur=Koruma` hiçbir commit kapısına (pre-commit, CI) bağlanmaz; yalnız elle ya da gece koşar. İlk tam koşu mesai dışında (22:00 sonrası) yapılır, her testin süresi ve okuma sayısı kaydedilir. Koşu sırasında `sys.dm_exec_requests.blocking_session_id` izlenir.
- **KOŞAMADI ≠ geçti.** Bağlantı kurulamazsa ya da kanonik sorgu boş dönerse (nüfus 0), test "KOŞAMADI: …" mesajıyla **kırmızı** döner. xUnit'te üçüncü durum yok; atlama bayrağı da kullanılmaz (`BkmVardiya.Tests` deseni, `olctum-mu-cikardim-mi.md` § nüfus sıfırsa).
- **Tolerans:** sayılar birebir, tutarlar ≤ 1,00 TL (spec). Tolerans sabiti test projesinde tek yerdedir.
- **Kırılabilirlik:** her test türünden en az biri için tolerans ya da beklenen değer bilerek bozulur, kırmızı görülür, geri alınır. Geri alma `git reset --hard` ile yapılmaz (`commit-discipline.md`).
- Test adları katalog biçimindedir: `GetKumbaraAsync_Eylul2026_FisBasinaTekilKanonigeEsit` (K1, yeni kod).
- Koşu: `dotnet test tests/GmDashboard.Tests --filter Tur=Kanonik` ERP'ye erişen makinede (SANAL-FIKRI). Panel veritabanı (BkmPanel) gerekmez; testler `Db.OpenPanel*` çağırmaz. Birim testleri (`Tur` etiketi yok) her yerde ve her commit'te koşabilir.
- **Doğrulama dönemi ve muhasebe kapanışı (risk R2).** Eylül 2026 kasa için kapalıdır ama muhasebede açıktır: son kapanış Haziran 2026 (`bkm.Fin_AyKapanis`, KapanisDT 27.07.2026; risk raporu ölçümü). Mizan (H12) ve maliyet (`ehMaliyet`, H7 marj) Eylül'ü değiştirmeye devam eder. H7 ve H12 için dönem kararı açık karardır (İnsan onayı 12): doğrulama ayı Haziran 2026'ya çekilir **ya da** kanıt başlığında ve test adında "muhasebe açık dönem" yazılır. Kasa tabanlı H'ler (H1, H2, H5, H6, H13) Eylül'de kalır.

### K-B — Ortak tanımların tek kaynağı

Mevcut emsal: `IcKartFiltre` (`Data/IcKartService.cs:11`) ve `LokasyonConfig` (`Data/LokasyonConfig.cs`) zaten SQL parçasını tek yerden veriyor. Aynı desen sürdürülür; yeni soyutlama, arayüz ya da sorgu üreticisi yazılmaz (Madde 6).

| Tanım | C# kaynağı (yeni) | sema kaydı | Kullanan |
|---|---|---|---|
| Kanonik fiş, iade sayısı, geri dönüşüm (1001) dışlaması, perakende/Sınav kanal ayracı | `Data/Tanimlar/FisTanimi.cs` | `metrics.yaml: FIS_KANONIK` (kural) + `codes.yaml: EncoreMerkez.SalesProducts.BarcodeNo` 1001 notu | Queries, TrafikQueries, MagazaQueries, SadakatQueries, SabahService, RefQueries (RFM) |
| E-ticaret iptal/iade/kayıp: sipariş başlığı `net_iptal_iade` + satır `net_iptal_iade` | `Data/Tanimlar/EticDurum.cs` | var olan `codes.yaml: joker.J_ORDERS.STATUS` / `joker.J_ORDER_DETAILS.STATUS` (kod listesi sema'dan **okunur**, kodda yalnız iki sabit) | EticQueries, OdakQueries |
| Merkez depo stoğu: bugün = canlı WMS (alan 0+1); geçmiş ay = ay sonu görüntüsü, açık dönem parametresiyle | `Data/Tanimlar/MerkezDepoStok.cs` | var olan `sql-server-conventions.md` § merkez depo + `entities.yaml` `depo.stok_adres_palet_vw` | OdakQueries, RefQueries.Envanter, SatinalmaQueries(.UrunDetay) |
| Değişiklik notu ("Hesap düzeltildi (gg.aa)") | `Data/Tanimlar/DuzeltmeNotlari.cs` + `Components/Shared/DuzeltmeNotu.razor` | — | Değişen göstergelerin sayfaları |

Kurallar:
- SQL parçası **sabit metin ya da tamsayı sabiti**dir; kullanıcı girdisi içermez (injection yok). Parametreler Dapper'la geçer.
- Aggregate içinde alt sorgu yasak olduğu için (`sql-server-conventions.md` § aggregate) 1001 dışlaması iki biçimde verilir: `WHERE` için anti-join, sayım için **kolon biçimi** (`LEFT JOIN (SELECT DISTINCT SalesId …) gd` + `gd.SalesId IS NULL`).
- Python Excel betikleri (`scripts/`) bu tanımları bugün ayrı yazıyor; bu spec'te dokunulmaz (K1). Kapsam dışı ve izleme maddesidir (bkz. § Kapsam dışı ve izleme).
- Kanonik **doğrulama** sorgusu bilerek bağımsız yazılır, `Tanimlar/`'ı kullanmaz. Bu bir emitter çatallanması değildir: amacı panelden bağımsız ikinci ölçümdür (`veri-dogrula` deseni). ADR adayı A2'de yazılır.

### K-C — H13 hedef tabanının ölçülmesi

Plan aşamasında ölçülenler (ÖLÇÜLDÜ, 03.10.2026, sorgular `arastirma.md` § 3):
- `BKMDATA.dbo.Hedef` **kategori (urnKtgr2) düzeyindedir** ve **Sınav Okulları kategorisini (ktgId 19) içerir**: İst.Yolu Eylül 2026 hedefinin 295,3 M TL'si bu kategoride (toplam 396,1 M TL).
- Mekân 12 (merkez depo) için ayrı hedef var: Eylül 2026'da 179,3 M TL. Ana sayfa yalnız üç mağazayı karşılaştırıyor, kapsam bu bakımdan tutarlı.
- Eylül 2026 hedef/gerçekleşen oranı (Encore, KDV hariç → KDV dahil): FSM 1,40 → 1,32 · Özlüce 1,25 → 1,17 · İst.Yolu 1,08 → 1,06. Tek ay KDV tabanını ayırmaya **yetmez**.

Bu nedenle tabanı belirleyecek ölçüm F0'da üç adımda yapılır (`sorgular/2026-10-panel-veri-duzeltme/H13-hedef-tabani-olcum.sql`):
1. **Sınav ayrımı:** hedef ürün kategorisine göre kurulmuş. Gerçekleşen de ürün bazlı (Products.Code → urn → urnKtgr2) hesaplanmalı, belge 8 bazlı değil. Kanıt: `sql-server-conventions.md` § kanal ayracı, belge bazlı ≠ ürün bazlı.
2. **KDV ayırıcısı:** KDV oranı farklı kategorilerde (Kitap %0 ↔ Kırtasiye %20) son 6 kapalı ay için `hedef / gerçekleşen_haric` ve `hedef / gerçekleşen_dahil` oranları hesaplanır. Hedef KDV dahil tabanda kurulmuşsa hariç tabandaki oran Kırtasiye'de Kitap'tan sistematik olarak yüksek çıkar; dahil tabanda bu fark kaybolur. Karar ölçütü: kategoriler arası oran farkının KDV oranıyla ilişkisi (6 ay × kategori). Seçilen kesim değil, iki tabanın kıyası raporlanır (`olctum-mu-cikardim-mi.md` § eşik türetme).
3. **Merkez depo:** hedefte mekân 12 ayrı satır; üç mağaza kartına girmez. Doğrulanır, öneri metnine yazılır.

Çıktı: GMY'ye tek sayfalık öneri ("hedef tabanı: ürün kategorisi bazlı, Sınav dahil, KDV {dahil|hariç} — kanıt"). Teyit gelene kadar Ana sayfada "Hedef tabanı teyit bekliyor" notu durur (AC-13.4). Teyit kodda tek bir sabitle (`HedefTabani.Teyitli`) açılır (AC-13.5). Teyit 001'in teslimini beklemez (spec kapsam dışı).

### K-D — Kanıt arşivi

- Klasör: `sorgular/2026-10-panel-veri-duzeltme/`. Dosya başına bir hikâye ya da bulgu: `00-taban-olcumu.sql`, `H01-kumbara-manuel.sql` … `H14-…`, `D1-…` … `D5-…`.
- Her dosyanın başlığı: soru, hedef veritabanı (`-- ork:hedef-db EncoreMerkez` + compat), dönem, tolerans, **önce / sonra / bağımsız değer** ve ölçüm tarihi (FR-012, SC-002). SSMS'te çalıştırmak için gereken `DECLARE @Bas date = CONVERT(date,'01.09.2026',104)` satırları yorum içinde durur. Gövde, testin Dapper ile çalıştırdığı parametreli tek ifadedir.
- Test projesi bu dosyaları kopyalamaz, bağlantıyla içerir (`<None Include="..\..\sorgular\2026-10-panel-veri-duzeltme\*.sql" LinkBase="Kanonik" CopyToOutputDirectory="PreserveNewest" />`). Böylece kanıt ile test aynı metni kullanır.
- Dosyalar Orkestra `sql_denetle.py` ile E seviyesi bulgu kalmayana kadar denetlenir.
- **Bağımsızlık güvencesi (risk R3).** Ortak bir yanlış varsayım hem panele hem kanonik sorguya girerse test yeşil, ekran yanlış olur (`test-discipline.md` § dokuzuncu vaka). Bu yüzden:
  1. Kanonik sorgular F0'da, **düzeltme kodundan önce** yazılır ve dondurulur. Dondurma commit'inin kısa hash'i her dosyanın başlığına yazılır; sonradan değişiklik ayrı commit ve gerekçe ister.
  2. Mümkün olan her H için kanonik sorgu **farklı kaynaktan** kurulur: Encore'a karşı `irsHrk` ya da `posOzetUrun` (kuruşu kuruşuna kimliği ölçülmüş, `sql-server-conventions.md` § POS özet), merkez depoya karşı WMS view'ı, e-ticarete karşı JOKER doğrudan. Aynı kaynaktan kurulan dosyanın başlığında "aynı kaynak — neden farklı kaynak yok" satırı ve bir "başka ne olabilir?" notu bulunur.
  3. `sql-denetci` kanonik dosyaları **panel kodunu görmeden** denetler (yalnız `sorgular/2026-10-panel-veri-duzeltme/`, kural dosyaları ve sema verilir).
  4. P1 (H1–H3) için GMY'nin bugünkü elle Excel kontrolünden en az bir rakam üçüncü ölçüm olarak arşive girer. Üçüncü ölçüm saparsa ilgili H kapanmaz, "saptı" raporlanır.
- `sema/` ikiz yükümlülüğü: yeni gerçekler `ork sema-aday` ile aday olarak yazılır (dış sema'ya doğrudan yazılmaz); onaylananlar `sema-ogren` ile işlenir.

## Anayasa kapıları

| Madde | Soru | Sonuç | Not |
|---|---|---|---|
| 1 Test-önce | Her davranış için önce kırmızı test planlandı mı? | ✅ | Kanonik, birim ve hata testleri düzeltme öncesi kırmızı görülür. Koruma testleri (SC-006) tanımı gereği önce de yeşildir; kırılabilirlikleri bilerek bozularak kanıtlanır. Testi test yazarı rolü yazar, kod yazarı dokunamaz |
| 2 Runtime kuralları | DMY, compat, DECIMAL, src.*, IsValid gözetildi mi? | ✅ (istisnalı) | EncoreMerkez compat 110 kısıtı parçalarda gözetilir. Tarih parametre ile geçer, literal yok. ODAKJOKER OPENQUERY'de ISO. `SalesProducts.IsValid = 1` her kalem okumasında, kampanya CTE'sine eklenir (H6). Para: kaynak şema `decimal(18,2)`/`money`; C# `decimal` (değiştirilemez, `desenler.md`). `WITH(NOLOCK)` (SP-013) dokunulan sorgularda **kaldırılmaz**: fiilî proje standardı, 436 geçiş; kaldırmak kilit davranışını değiştirir ve bu spec'in konusu değildir → karmaşıklık takibi |
| 3 Katman yönü | ARC-001..006 ihlali var mı? | ⚠ mevcut borç | Yeni katman yok; Razor → Queries doğrudan çağrısı sürer (K1, `yapi.md`). Yeni ihlal eklenmez |
| 5 Sadelik | Yeni proje/katman/bağımlılık var mı? Varsa ADR? | ⚠ 1 yeni proje | `tests/GmDashboard.Tests`, ADR A1. Paket yok (sürümler depoda var). Dokunulan proje sayısı 2 (dashboard + test) ≤ 3 |
| 6 Soyutlama karşıtı | Framework sarmalanıyor mu? | ✅ | Tanımlar sabit SQL parçası (emsal `IcKartFiltre`). Dapper, `TimeProvider`, `WebApplicationFactory` doğrudan kullanılır |
| 7 Gerçek DB testi | Entegrasyon testleri gerçek SQL Server'da mı? | ✅ | Canlı ERP, salt-okuma. Kontratlar (`kontratlar/`) uygulamadan önce yazıldı |
| 8 Güvenlik | Her guard için negatif test; sır kodda yok | ✅ | Yetki modeli değişmiyor. Negatif testler: `GeriAdresi` dış adres reddi (açık yönlendirme), hata ekranında sunucu adı/SQL/istisna metni görünmez. Testler sırrı `.env`'den okur; hata testi sırsız geçici `.env` kullanır. Test çıktısına kişisel veri (müşteri adı/telefonu) **yazılmaz**, yalnız sayım ve kimlik numarası karşılaştırılır |
| 9 İzlenebilirlik | Her AC → görev → test eşlenebilir mi? | ✅ | `kontratlar/kanonik-sorgular.md` AC → kanonik dosya → test adı tablosu |
| 10 İnsan kapıları | Plan onayı ve UI kararları insanda mı? | ✅ | "İnsan onayı gerektirenler" bölümü |
| 11 Doküman | Yardım ve CHANGELOG | ✅ planlandı | `dashboard/CHANGELOG.md` (yeni, Keep a Changelog, "Düzeltildi") + `docs/yardim/panel-tanimlari.md` (yeni; fiş, merkez depo, e-ticaret iptal, hedef tabanı; sema'ya bağlantılı) |

## Bileşenler ve sorumluluklar

| Bileşen | Tür | Sorumluluk | Dosya(lar) | AC |
|---|---|---|---|---|
| `FisTanimi` | Static SQL parçası | Kanonik fiş/iade sayımı, 1001 dışlaması (WHERE + kolon biçimi), kanal ayracı (iade → bağlı belgenin kanalı), perakende/Sınav net ifadeleri | `dashboard/Data/Tanimlar/FisTanimi.cs` (yeni) | H5, H6, H13, D-2 |
| `EticDurum` | Static sabit | Başlık iptal/iade/kayıp kodları, satır iptal/iade kodları | `dashboard/Data/Tanimlar/EticDurum.cs` (yeni) | H4 |
| `MerkezDepoStok` | Static SQL parçası | Canlı WMS (alan 0+1) CTE gövdesi; ay sonu görüntüsü (`@Donem` zorunlu, `MAX(Donem)` yedeği yok) | `dashboard/Data/Tanimlar/MerkezDepoStok.cs` (yeni) | H3, H8 |
| `DuzeltmeNotlari` + `DuzeltmeNotu` | Static kayıt + Razor bileşeni | Gösterge anahtarı → yayın tarihi; `TimeProvider` ile 30 gün kuralı | `dashboard/Data/Tanimlar/DuzeltmeNotlari.cs`, `dashboard/Components/Shared/DuzeltmeNotu.razor` (yeni) | AC-0.1, 0.2 |
| `HedefTabani` | Static sabit | `Teyitli` bayrağı + not metni | `dashboard/Data/Tanimlar/HedefTabani.cs` (yeni) | AC-13.4, 13.5 |
| `GeriAdresi` | Saf fonksiyon | `geri` sorgu parametresini yerel yola ya da `/satis-analizi?…` adresine çözer; dış adresi reddeder | `dashboard/Data/Tanimlar/GeriAdresi.cs` (yeni) | H11 |
| `KullaniciMesajlari` | Static sabit | Hata ve boş durum metinleri tek yerde | `dashboard/Data/Tanimlar/KullaniciMesajlari.cs` (yeni) | H10, AC-8.4 |
| `StokGostergeTanimlari` | Static sabit + metin | Ölü/aşırı stok ve stokta yokluk eşikleri; SQL ve açıklama metni aynı sabitten | `dashboard/Data/Tanimlar/StokGostergeTanimlari.cs` (yeni) | H14 |
| `RefQueries` | Sorgu | Kumbara/manuel fiş başına tekil (H1); ABC iade sign'lı (H7); RFM Monetary iade düşülmüş, LTV etiketi (D-1) | `dashboard/Data/RefQueries.cs` | H1, H7, D-1 |
| `RefQueries.Envanter` | Sorgu | Tedarikçi karnesi depo = canlı WMS + ayrık kolonlar (H3); marj kanonik şube cirosu + kategorisiz satır (H7); kategori çeşit depo = canlı WMS (H8); ölü stok depo bileşeni = kanonik WMS (H8); `ISNUMERIC` korumalı dönüşüm (H10.3) | `dashboard/Data/RefQueries.Envanter.cs` | H3, H7, H8, H10 |
| `SadakatQueries` | Sorgu | Win-back koşulu, frekans yalnız satış fişi, `@Bugun` parametresi, müşteri kimliği taneciği (H2); kartlı/kartsız fiş sayımı (H5) | `dashboard/Data/SadakatQueries.cs` | H2, H5 |
| `EticQueries` | Sorgu | Kategori 3 sorgusuna başlık STATUS süzgeci (H4); "Baskısı yok" etiketi (D-3, Razor) | `dashboard/Data/EticQueries.cs` | H4, D-3 |
| `OdakQueries` | Sorgu | E-tic talep: başlık + satır STATUS süzgeci (H4); depo = canlı WMS (H8) | `dashboard/Data/OdakQueries.cs` | H4, H8 |
| `TrafikQueries` | Sorgu | Fiş = kanonik; iade ayrı sayı; net değişmez | `dashboard/Data/TrafikQueries.cs` | H5 |
| `Queries` | Sorgu | Mağaza fiş/iade kanonik, perakende/Sınav/Toplam (H5, H13); saat/kasiyer kapsamı mağaza netiyle aynı (D-2); hedef notu | `dashboard/Data/Queries.cs` | H5, H13, D-2 |
| `MagazaQueries` | Sorgu | Kampanya `IsValid` + KDV dahil etiketli (H6.1–6.2); iade KDV hariç (H6.3); UPT ve ısı haritası kanonik fiş (H6.4) | `dashboard/Data/MagazaQueries.cs` | H6 |
| `SinavQueries` | Sorgu | Ödeme sağlık kartı `FisSet` tabanından, fatura bağlı sipariş sayısına eşit bölünür | `dashboard/Data/SinavQueries.cs` | H9 |
| `MizanQueries` | Hesap | Nakit 101'siz; `AlinanCek` ayrı; KDV pozisyonu 190 dahil | `dashboard/Data/MizanQueries.cs`, `Models/MizanModels.cs` | H12 |
| `SabahService` | Servis | Hata mesajı genel + günlük; fiş kanonik | `dashboard/Data/SabahService.cs` | H10, H5 |
| `HediyeCekiQueries` | Sorgu | Barem brüt/indirim/net aynı KDV tabanı | `dashboard/Data/HediyeCekiQueries.cs` | D-4, H10.3 |
| Razor sayfaları | UI | Hata mesajı genel (H10); notlar, etiketler, dipnotlar; Geri (H11) | `Components/Pages/{Sabah,Envanter,Operasyon,SatinalmaAnaliz,Esikler,Vardiya,Home,Trafik,Sadakat,Magaza,Etic,Odak,Sinav,Mizan,SatisAnaliziUrun,SatisAnalizi,SezonAksiyon,GunKarsilastir,Tahmin,HediyeCeki}.razor` | H10, H11, H13, H14, D-1..5, AC-0 |
| `ServiceRegistration` | DI | `AddSingleton(TimeProvider.System)` (`AddBkmVeri` içinde; ASP.NET Core varsayılan olarak kaydetmiyor) | `dashboard/ServiceRegistration.cs` | AC-0.1 |
| `GmDashboard.Tests` | Test projesi | Kanonik, koruma, birim, hata ekranı testleri | `tests/GmDashboard.Tests/**` (yeni) | Tümü |
| Kanonik sorgular | Arşiv + test girdisi | Bağımsız doğrulama sorgusu + önce/sonra kaydı | `sorgular/2026-10-panel-veri-duzeltme/*.sql` (yeni) | FR-012 |
| sema | Kural kaydı | `FIS_KANONIK`, 1001 = iade belgesindeki geri dönüşüm satırı, hedef tabanı (teyit sonrası), 4 yeni değişmez | `sema/metrics.yaml`, `sema/codes.yaml`, `sema/degismezler.json` | FR-014 |

Ayrıntılı imza ve sonuç kümeleri: `kontratlar/`.

### Yeni değişmezler (`sema/degismezler.json`, veri gerçeği, panel kodu değil)

| id | Neyi korur | Nüfus |
|---|---|---|
| `encore-kalem-salesid-sequence-tekil` | H6 kampanya CTE'si `SalesProducts`'a `(SalesId, Sequence)` ile bağlanınca çoğalma olmaz | `SalesProductCampaigns` son 90 gün |
| `encore-products-code-sayisal` | H10.3 latent riskin hâlâ sıfır olduğu (bugün 0 kayıt; çıkarsa ekran çökmez ama eşleşme dışı kalır, sayısı görülür) | `Products` |
| `geri-donusum-1001-satis-fisinde-gecerli-yok` | 1001 satırı geçerli olarak yalnız iade belgesinde bulunur; kanonik fiş sayımının 1001 dışlamasından etkilenmediği | `SalesProducts BarcodeNo='1001'` |
| `wms-alan-tipi-kumesi-kapali` | Merkez depo tanımı `adrsAlanTipID IN (0,1)`; yeni alan tipi çıkarsa sessizce dışarıda kalmasın | `depo.adresAlanTip` |

Her biri eklenirken beklenen değer bozulur, kırmızı görülür, geri alınır.

## Veri modeli

Bkz. `veri-modeli.md`. **Yeni tablo, kolon, view, SP, job yok. ERP'ye yazma yok. Veri kaybı: yok.** "Hesap düzeltildi" notunun kalıcılığı kod sabitidir (`DuzeltmeNotlari.cs`); panel veritabanına da tablo açılmaz.

## Kontratlar

Bkz. `kontratlar/`:
- `ortak-tanimlar.md`: `FisTanimi`, `EticDurum`, `MerkezDepoStok`, `DuzeltmeNotlari`, `HedefTabani`, `GeriAdresi`, `StokGostergeTanimlari` imzaları ve ürettikleri SQL'in sözleşmesi
- `sorgu-metodlari.md`: değişen her sorgu metodunun imzası, sonuç kümesi (kolon + tip + sıra), davranış değişikliği
- `ekranlar.md`: ekran sözleşmesi (göstergeler, etiketler, notlar, hata mesajları, boş durum)
- `kanonik-sorgular.md`: AC → kanonik sorgu dosyası → parametre → beklenen ilişki → test adı

SP, API ucu ve yeni HTTP durum kodu yok.

## Hata kodları

Bu spec SP ya da API eklemez; 5xxxx kodu, HTTP karşılığı yok. `db/hata-kodlari.yaml` bu depoda yok ve bu spec için açılmaz.

Kullanıcıya görünen hata ve boş durum metinleri (`kontratlar/ekranlar.md` § mesajlar):

| Durum | Ekran metni | Günlük | Kaynak AC |
|---|---|---|---|
| Veri kaynağı hata döndürdü | "Veriler şu anda alınamıyor. Sayfayı birkaç dakika sonra yenileyin; sorun sürerse sistem yöneticisine bildirin." | `LogError(ex, "{Ekran} veri yükleme hatası")`, ekran adı ve zaman | AC-10.1, 10.2 |
| Kayıt (Eşikler) başarısız | "Eşik kaydedilemedi. Değerleri kontrol edip yeniden deneyin; sorun sürerse sistem yöneticisine bildirin." | `LogError(ex, "Eşikler kayıt hatası")` | AC-10.1 |
| Dönemde kayıt yok | "Bu dönemde kayıt yok." | — | Sınır durumlar |
| Ay sonu stok görüntüsü yok | "Bu ay için stok görüntüsü yok." | `LogInformation` | AC-8.4 |
| Canlı WMS erişilemez | Hata metni (yukarıdaki); ay sonu görüntüsüne sessiz geçiş **yok** | `LogError` | Sınır durumlar |

## UI kararları

Panel (`/ui-panel`) **gerekmez**. Hepsi mevcut DaisyUI deseninde, metin ya da satır eklemesidir; mobil yerleşim 002'nin işidir. Varsayılan öneriler (güven orta-yüksek):

1. **"Hesap düzeltildi (gg.aa)":** gösterge etiketinin yanında `badge badge-ghost badge-sm` (görünür metin, `title`'a bağlı değil).
2. **Ana sayfa mağaza kartı (AC-13.1):** mevcut tek net satırının yerine üç satır: "Perakende", "Sınav Okulları", altta kalın "Toplam". Sınav Okulları değeri 0 olan mağazada (FSM, Özlüce) satır "—" ile gösterilir. *Bu, kullanıcı-görünür yerleşim değişikliğidir; insan onayı listesinde.*
3. **Hedef notu (AC-13.4):** hedef kartı başlığının altında `text-warning` küçük metin "Hedef tabanı teyit bekliyor".
4. **Ay sonu stok tarihi (AC-8.3):** değerin yanında "(31.08.2026 görüntüsü)".
5. **Stok tanım metinleri (H14):** gösterge altında dipnot (en fazla 2 cümle; `sunum-dili.md`).
6. **İade sayısı (AC-5.4):** fiş sayısının yanında ayrı değer "İade: N".
7. **KDV etiketleri (D-3, D-4, H6.2, D-5):** kolon başlığına "(KDV dahil)" / dipnotta taban.

## Uygulama sırası (görevlere bölünmeden önce)

| Faz | İçerik | Bitiş ölçütü |
|---|---|---|
| **F0 Taban ölçümü** | Tüm "önce" değerleri Eylül 2026 için yeniden ölçülür ve kanonik dosya başlıklarına yazılır. Açık ölçümler: (a) 1001 = iade belgesi bulgusunun üç mağaza ve AC-5.4 için etkisi; (b) `HediyeCekiQueries.GeriDonusumHaric` (RefundReasonId 12 + Code 583160) ile 1001 tanımının eşdeğerliği; (c) Eylül 2026'da geçerli başlıklı siparişlerde satır 2004/2005/2010 tutarı (H4 kararı); (d) `(SalesId, Sequence)` tekilliği; (e) H13 hedef tabanı (K-C); (f) Sınav iadesinin kanala atanma farkı (H13); (g) Satış analizi tabanının merkez depo kolonunun kesim anı farkı (H8); (h) **R2 kayma ölçümü:** Eylül 2026 e-ticaret net ciro ve sipariş sayısı bugün ve **7 gün sonra** iki kez ölçülür, fark yazılır (cayma ve iade statüsü geçişi); (i) H7/H12 için dönem kararı (Haziran 2026 ya da "muhasebe açık dönem" etiketi) İnsan onayı 12'ye sunulur; (j) JOKER doğrudan bağlantısı test makinesinden tek `SELECT 1` ile denenir; (k) **kanonik sorgular düzeltme kodundan önce yazılır, `sql-denetci` panel kodunu görmeden denetler ve dosyalar dondurulur** (K-D § bağımsızlık); (l) eski formüllerin dondurulmuş kopyası koruma testleri için test projesine alınır | `00-taban-olcumu.sql` + her `Hxx` başlığında "önce" ve dondurma hash'i dolu; kayma ölçümünün iki koşusu arşivde; sema adayları yazıldı |
| **F1 Test altyapısı + kırmızı** | **Görev 1 (R1):** salt-okuma kapısı (izin listesi `SELECT`/`WITH…SELECT` + her ifade `ROLLBACK` edilen transaction) ve `UPDATE` içeren sahte dosyayla kırılabilirlik kanıtı. **Görev 2 (R5):** hata testi koleksiyonu, paralellik kapalı, `Db` DI ile sahte sunucuya, ilk adımda `DataSource` doğrulaması. Sonra: test projesinin geri kalanı, ortak yardımcılar (tolerans, KOŞAMADI, `LOCK_TIMEOUT`/`DEADLOCK_PRIORITY`), tüm kanonik/koruma/birim/hata testleri. Düzeltme öncesi kırmızı listesi raporlanır | Görev 1 ve 2 kanıtlı; kırmızılar doğru sebepten; koruma testleri (eski ↔ yeni formül) yeşil |
| **F2 Ortak tanımlar** | `Data/Tanimlar/*`, `DuzeltmeNotu.razor`, `TimeProvider` DI. **Önce rakamı değiştirmeyen çıkarım commit'i** (R6): parçalar bugünkü davranışı birebir üretir, koruma testleri yeşil | Birim testleri ve koruma testleri yeşil |
| **F3 P1** | H1, H2, H3 (onay gerektirmeyen H2 ve H3 öne alınabilir, R7) | İlgili kanonik testler yeşil |
| **F4 P2** | H4, H5, H6, H7, H8 | İlgili kanonik testler yeşil |
| **F5 P3 + düşük** | H9–H14, D-1..D-5 (onay gerektirmeyen H10, H11, H12 öne alınabilir, R7) | İlgili testler yeşil |
| **F6 Kapanış** | `dotnet build` 0 hata; birim testleri yeşil; kanonik ve koruma testleri mesai dışında elle koşulur, tümü yeşil; `python tools/panel_kolon_denetimi.py` 0; `python tools/sema_degismez.py` 0 (SC-007); `python tools/turkce_tanimlayici_denetimi.py` 0 (yeni dosya 0 tolerans); "sonra" değerleri arşive; CHANGELOG + yardım; journal (AC-0.2); `DuzeltmeNotlari` yayın tarihi **yayın günü ayrı tek satırlık commit'le** | SC-001…SC-007 raporu "tuttu / saptı / koşamadı / karar bekliyor" |

**Commit stratejisi (risk R6).**
- Her tanım iki adımda girer. Önce rakamı değiştirmeyen çıkarım commit'i gelir; koruma testleri yeşil kalır. Sonra davranışı değiştiren commit gelir.
- Bir tanımın **tüm** kullanıcıları aynı yayında değişir. Örnek: fiş tanımı Ana sayfa, Trafik, Sadakat, Mağaza ve Sabah'ta birlikte. Ara durumda ekranlar arası fiş sayısı bugünden daha tutarsız olmamalıdır (SC-004).
- Her H ayrı commit: `fix(bkm): H5 kanonik fiş tanımı (spec: 001)`. Paylaşılan dosya kendi H'sinin commit'iyle gider.
- `git status` 15 dosya eşiğini aşmadan commit bölünür. Yarım kalan tanım yayına alınmaz.

## Riskler (risk analisti, 03.10.2026; en fazla 7)

Kaynak: `.orkestra/calisma/001-panel-veri-duzeltme/risk-rapor.md`. Karar: **ŞART**. R1 ve R5 önlemleri F1'in ilk iki görevi, R2 ve R3 önlemleri F0'da; plana işlendi. Bu koşulla **ilerle**.

| # | Risk | Sınıf | Olas. | Etki | Erken sinyal | Önleyici (planda nerede) | Kontenjans | Güven |
|---|---|---|---|---|---|---|---|---|
| R1 | Testler canlı ERP'ye `sa` ile bağlanır ve kanonik `.sql` metnini olduğu gibi çalıştırır. Kanonik dosyaya düşen bir `UPDATE`/`DELETE`/`EXEC` ERP'de geri alınamaz değişiklik yapar | Varoluşsal | Düşük | Yüksek | Kanonik dosyada `SELECT`/`WITH` dışı ilk kelime; test yardımcısında `ExecuteAsync`; `git diff sorgular/` içinde `INTO`/`EXEC` | Salt-okuma kapısı (izin listesi) + her ifade `ROLLBACK` edilen transaction + `UPDATE`'li sahte dosyayla kırılabilirlik kanıtı (K-A, F1 görev 1). Orta vade `db_datareader` login'i (İnsan onayı 11) | Testler durdurulur; değişen satır SQL Server günlüğünden ya da yedekten tespit edilir; GMY ve DerinSIS satıcısı bilgilendirilir | Orta |
| R2 | Eylül 2026 yalnız kasa için kapalı. Muhasebe son kapanışı Haziran 2026; mizan (H12) ve maliyet (H7) Eylül'ü değiştirir. Eylül e-ticaret siparişleri Ekim'de iade/iptale geçer (H4, SC-006). "Önce" sayıları bayatlar, sabit sayılı koruma testi kod değişmeden kırmızıya döner | Operasyonel | Yüksek | Orta | Aynı koruma testi iki gün arayla farklı sonuç; "önce" değeri F0 ile F6 arasında kod değişmeden kayıyor | F0 (h) kayma ölçümü (bugün ve +7 gün); koruma testleri "eski formül ↔ yeni formül" (K-A); H7/H12 dönem kararı (F0 (i), İnsan onayı 12) | Kayma ölçülürse koruma testleri Haziran/Ağustos'a taşınır; Eylül yalnız kasa tabanlı H'lerde kalır | Orta |
| R3 | "Bağımsız" kanonik sorguyu düzeltmeyi yazan aynı zincir yazar. Ortak yanlış varsayım iki tarafa girerse test yeşil, ekran yanlış olur | Stratejik | Orta | Yüksek | Kanonik dosya panel SQL'iyle aynı join/filtre metnini taşıyor; ikisi aynı kaynaktan okuyor; "başka ne olabilir?" satırı yok | Kanonik sorgular düzeltme kodundan önce yazılıp dondurulur; mümkünse farklı kaynak (`irsHrk`/`posOzetUrun`/WMS/JOKER); `sql-denetci` panel kodunu görmeden denetler; P1 için GMY'nin Excel'inden üçüncü ölçüm (K-D § bağımsızlık, F0 (k)) | Üçüncü ölçüm saparsa ilgili H kapanmaz, "saptı" raporlanır; tanım GMY'ye döner | Yüksek |
| R4 | Kanonik ve koruma testleri mesai içinde canlı ERP'de ağır tarama yapar; paylaşımlı kilit saatlik kasa→ERP aktarımını ve POS'u bekletebilir | Operasyonel | Orta | Orta | Koşu > 10 dk; `blocking_session_id` dolu; gün içi Encore↔ERP farkı %3-4 bandını aşıyor; mağazadan yavaşlık şikâyeti | `SET LOCK_TIMEOUT 5000` + `SET DEADLOCK_PRIORITY LOW`; ilk tam koşu mesai dışı; `Tur=Kanonik/Koruma` hiçbir commit kapısına bağlanmaz (K-A) | Koşu mesai dışına sabitlenir; ağır sorgular için Eylül tek mağaza alt kümesi | Orta |
| R5 | Hata testi bağlantı ortamını değiştirir. Paralel koşuda kanonik testler sahte sunucuya bağlanır (rastgele KOŞAMADI); `BKM_ENV_DOSYA` dosyası yoksa `Db` sessizce gerçek `.env`'e döner ve "hata testi" canlı ERP'ye bağlanır | Operasyonel | Orta | Orta | Kanonik testlerin yalnız tam koşuda KOŞAMADI vermesi; hata testinin bağlandığı `DataSource` beklenenden farklı | Ayrı koleksiyon, paralellik kapalı; `Db` DI ile sahte sunucuya; ilk adımda `DataSource` doğrulaması; başlangıçta panel DB'ye bağlanan hosted servisler `ConfigureTestServices` ile kaldırılır (K-A, F1 görev 2) | Hata testi `*Queries` + bileşen düzeyine indirgenir | Yüksek |
| R6 | Kapsam geniş (12 sorgu sınıfı, ~20 Razor, test projesi, sema). Çıkarım ile davranış değişikliği aynı commit'e girerse ya da fiş tanımı tüketicilere faz faz yayılırsa ara durumda ekranlar arası tutarsızlık bugünden kötü olur (SC-004 tersine döner); 15 dosya eşiği aşılır | Operasyonel | Yüksek | Orta | `git status` > 15; bir commit'te hem `Tanimlar/*` hem rakam değişikliği; ekranlardan biri yeni, diğeri eski fiş sayısını gösteriyor | Önce rakamı değiştirmeyen çıkarım commit'i, sonra davranış commit'i; bir tanımın tüm kullanıcıları aynı yayında; H başına commit (§ Commit stratejisi) | H bazında `git revert`; yarım kalan tanım yayına alınmaz | Orta |
| R7 | Tek kişi darboğazı: 12 onay maddesi, ADR A1–A3, hedef teyidi ve ERP'ye erişen tek test makinesi aynı kişiye bağlı. Rakamlar değişince GMY "dün farklıydı" deyip elle Excel'e dönebilir | Operasyonel | Orta | Orta | F0 bitiminden sonra 5 iş günü içinde maddelerin yarısından azı cevaplı; journal'da aynı açık soru iki oturum üst üste; yayından sonra GMY'den gelen ilk "rakam değişti" sorusu | F0 bitince onay maddeleri tek sayfada, her biri öneri + rakam + "itiraz yoksa öneri uygulanır" tarihiyle; onay gerektirmeyen H'ler (H2, H3, H10, H11, H12) önce teslim; AC-0 notu + journal + CHANGELOG + kanıtta önce/sonra | Onaysız maddeler "karar bekliyor" etiketiyle ayrılır, kalan H'ler teslim edilir; SC-001 raporu bunları "karar bekliyor" yazar | Yüksek |

### Spec-karar maddeleri (risk değil, açık karar)

Ölçümle kesinleşmiş ya da gerçekleşmiş durumlar risk tablosunda tutulmaz; insan kararı bekler.

| # | Durum | Kanıt | Karar yeri |
|---|---|---|---|
| KR-1 | "Geri dönüşüm fişi" fiilen iade belgesi. Kanonik tanımla FSM Eylül 2026 iade sayısı 947, spec AC-5.4 1.518 yazıyor | ÖLÇÜLDÜ, `arastirma.md` § 1 | İnsan onayı 1. Onaya kadar AC-5.4 testi iki değeri raporlar |
| KR-2 | E-ticaret "aynı kural": satır iptali (2004/2005/2010) ciroya uygulanırsa ana ciro değişir (SC-006); uygulanmazsa ODAK talebi ile ciro farklı kuralda kalır | Kod + sema; tutar F0 (c) | İnsan onayı 2. Fark > %0,5 ise ayrı karar |
| KR-3 | Satış analizi merkez depo kolonu ön-agrega kesiminden geliyor; AC-8.1 birebir eşitliği kesimden sonra bozulur | Kod; fark F0 (g) | İnsan onayı 3 |
| KR-4 | İki ayrı geri dönüşüm tanımı (1001 barkodu ↔ `RefundReasonId 12` + `Code 583160`); eşdeğer değilse D-2 ve D-4 tabanları kayar | Kod; eşdeğerlik F0 (b) | Eşdeğerse Hediye çeki `FisTanimi`'ne bağlanır; değilse ayrı kalır, fark sema'ya yazılır |

## Kapsam dışı ve izleme

- **Python Excel betikleri (`scripts/`)** eski fiş, iade ve depo tanımında kalır (K1). GMY panelde yeni, Excel ve brifingde eski rakamı görebilir. Önlem: hangi betiğin hangi tanımı kullandığı listesi `TODO.md`'ye; CHANGELOG'da "Excel raporları henüz eski tanımda" satırı.
- **Spec 003 şartı:** 003 (yeni raporlar, indirim ve kasa kontrolü) fiş, e-ticaret iptal/iade ve merkez depo için `dashboard/Data/Tanimlar/` parçalarını ve sema `FIS_KANONIK` kaydını kullanır; kendi tanımını kurmaz. Şart 003 spec'ine girdi olarak iletilir.
- "Hedef tabanı teyit bekliyor" notu kalıcılaşabilir: 30 gün teyitsiz kalırsa `TODO.md`'de yükseltilir.
- Kanonik testler commit kapısına bağlı değildir; yalnız koşulursa yakalar. Aylık muhasebe kapanışından sonra elle koşulur, sonuç journal'a yazılır.
- Başarısız küme testi çıktısında yalnız sayı yazılır, müşteri kimliği listesi yazılmaz (KVKK).

## Karmaşıklık takibi (anayasa istisnaları)

| İstisna | Gerekçe | Daha basit alternatif neden reddedildi | Onay |
|---|---|---|---|
| Yeni proje `tests/GmDashboard.Tests` (Madde 5, ARC-008) | Spec otomatik davranış testi istiyor; dashboard'da test projesi yok | `BkmVardiya.Tests`'e eklemek: o proje ayrı bir uygulamayı (vardiya, panel DB) sınar, panel DB olmadan kırmızı döner; iki uygulamayı tek projede karıştırmak koşuyu bağımlı kılar. `sema_degismez`/`sqlcli assert`: uygulama kodunu sınamaz (K-A) | Gerekli (ADR A1) |
| `WITH(NOLOCK)` dokunulan sorgularda kalır (SP-013) | Fiilî standart; kaldırmak kilit/bekleme davranışını değiştirir, bu spec'in konusu değil | Kaldırmak: canlı ERP'de okuma kilitleri, ölçülmemiş performans riski | Gerekli (K1 genişletmesi) |
| Tek harfli tablo takma adları (QRY) dokunulan sorgularda kalır | Sorgu farkını küçük tutar; inceleme ve önce/sonra karşılaştırması kolaylaşır | Yeniden adlandırma: diff'i büyütür, hata gizler | Gerekli (K1 genişletmesi) |
| Testlerde ERP'ye karşı canlı okuma (izole test DB yok) | Kaynak veri yalnız canlıda; Madde 8 yalnız yazmayı yasaklar | Testcontainers: DerinSIS/EncoreMerkez şeması ve verisi çoğaltılamaz | Bilgi |

## ADR adayları

- **A1:** Dashboard için test projesi ve canlı ERP'ye karşı salt-okuma entegrasyon testi deseni (KOŞAMADI = kırmızı, kanonik sorgu bağımsız, kapalı ay tabanı). Neden kalıcı: 002/003 aynı deseni kullanacak. **ADR gerekli: evet**
- **A2:** Panel ortak tanımlarının tek kaynağı `Data/Tanimlar/` (SQL parçası sabitleri) + sema kural kaydı; kanonik doğrulama sorgusunun bilerek bağımsız tutulması. Neden kalıcı: emitter-ayrımı kuralının panel içi uygulaması; 003 indirim/kasa raporu bunu kullanacak. **ADR gerekli: evet**
- **A3:** Hedef tabanı (teyitten sonra): hedef ürün kategorisi bazlı, Sınav dahil, KDV {teyit edilen}. **ADR gerekli: evet** (GMY teyidi gelince)
- Merkez depo "bugün canlı / geçmiş tarihli görüntü, `MAX(Donem)` yedeği yok" kararı ADR değil; `sql-server-conventions.md` § merkez depo bölümüne kural olarak eklenir.

## İnsan onayı gerektirenler

1. **KR-1, AC-5.4 iade sayısı:** 1001 satırlı iade belgeleri iade sayısından dışlansın mı? Öneri: **evet** (FSM Eylül 2026: 947). Spec'teki 1.518 değeri dışlamasız sayım.
2. **KR-2, e-ticaret satır iptali:** ciro/sipariş için başlık kuralı korunsun, adet/talep için satır kuralı da eklensin mi? Öneri: **evet**; ciroya satır kuralı 003'te karar.
3. **KR-3, Satış analizi merkez depo:** kesim zamanı etiketi mi (öneri), canlı bağlama mı?
4. **H13 Sınav iadesi:** Sınav belgesine bağlı iade Sınav satırından mı düşülsün (öneri: evet; Gün karşılaştırma ve Sınav sayfası bu kuralı kullanıyor), yoksa perakendeden mi?
5. **H9 dağıtım:** birden çok siparişe bağlı faturanın neti siparişlere eşit bölünsün mü (öneri), yoksa ilk siparişe mi yazılsın?
6. **H1 indirim tanımı:** Kumbara/manuel indirim = Kumbara satırı taşıyan fişin başlık `DiscountTotal`'ı, fiş başına bir kez (öneri; 003 ayrıca Kumbara'ya özgü satır indirimini gösterebilir).
7. **H6.2 kampanya yükü tabanı:** kampanya tablosu KDV dahil kalsın ve etiketlensin mi (öneri; satır KDV'sini indirime dağıtmak ölçülmemiş varsayım ister)?
8. **Ana sayfa mağaza kartı yerleşimi** (UI 2): üç satır.
9. **ADR A1, A2** ve karmaşıklık takibindeki iki K1 genişletmesi.
10. **H13 hedef tabanı önerisi** (F0 sonrası).
11. **R1 orta vade:** test koşusu için yalnız `db_datareader` yetkili ayrı SQL login'i (`erp-write-policy.md` § sertleştirme) öne çekilsin mi? Öneri: evet; DB yöneticisi işi.
12. **R2, H7/H12 doğrulama dönemi:** muhasebe son kapanışı Haziran 2026. Öneri: H12 (mizan) Haziran 2026'ya çekilsin; H7 (marj) Eylül'de kalsın, kanıt başlığında ve test adında "muhasebe açık dönem" yazsın (ciro kasa tabanlı, yalnız maliyet açık).

## Onay kaydı (03.10.2026)

GMY plan 001'i ve "İnsan onayı" listesindeki 12 maddenin tamamını önerilen haliyle onayladı:
KR-1 evet (947) · KR-2 evet (satır kuralı ciroya 003'te) · KR-3 kesim zamanı etiketi · H13 Sınav iadesi Sınav satırından · H9 eşit bölme · H1 başlık indirimi fiş başına bir kez · H6.2 KDV dahil + etiket · Ana sayfa üç satır · ADR A1/A2 yazılır, `WITH(NOLOCK)` ve tek harfli takma ad dokunulan sorgularda borç olarak kalır (K1 genişletmesi) · H13 hedef tabanı F0 sonrası öneri · test için salt-okuma SQL login'i (DB yöneticisi) · H12 Haziran 2026, H7 Eylül + "muhasebe açık dönem" etiketi.
