# Sorgu metotları — imza ve sonuç kümesi sözleşmesi

Kayıt alanları SQL `SELECT` sırasıyla **aynı sırada** olmalıdır (Dapper konumsal kayıt). Yeni alanlar sona eklenir. Her metot salt-okumadır. "Önce" kolonu bugünkü davranıştır (kod satırı ile), "Sonra" kolonu sözleşmedir.

Tip kısaltması: `dec` = `decimal` (SQL `decimal(18,2)`/`money`; C# `decimal`), `int` = `int` (smallint/tinyint için SQL'de `CAST(... AS int)`).

---

## H1 — `RefQueries.GetKumbaraAsync` / `GetManuelIndirimAsync`

```csharp
Task<IReadOnlyList<KumbaraAyRow>>      GetKumbaraAsync(CancellationToken ct = default);
Task<IReadOnlyList<ManuelIndirimRow>>  GetManuelIndirimAsync(CancellationToken ct = default);
```

| Sonuç kolonu | Tip | Sonra (sözleşme) |
|---|---|---|
| `Sebep` (yalnız manuel) | `string` | `RefundReasons.Name`, `Type = 1` |
| `Magaza` | `string` | `Stores.Name` |
| `Ay` | `string` | `yyyy-MM` (etiket; tarih karşılaştırmasında kullanılmaz) |
| `Brut` | `dec` | Fiş başına **bir kez** `Sales.GrossTotal`; iade (`3`) negatif |
| `Indirim` | `dec` | Fiş başına bir kez `Sales.DiscountTotal`; iade negatif (İnsan onayı 6) |
| `FisSayisi` | `int` | `COUNT(DISTINCT s.Id)` |

- **Önce:** `RefQueries.cs:578,607`. `Sales → SalesProducts → SalesProductCampaigns` join'inden sonra `SUM(s.GrossTotal)` → kalem sayısı kadar şişme (Eylül 2026 Kumbara 6.106.723,80 TL ↔ tekil 223.717,80 TL). Belge filtresi yok, `COLLATE` yok.
- **Sonra:** Fiş kümesi önce `EXISTS` ile seçilir (Kumbara satırı **geçerli** bir kaleme bağlı: `sp.IsValid = 1 AND spc.CampaignId IS NULL AND spc.CampaignVersion = 17`), toplam o kümeden alınır. `DocumentsTypeId IN (1,2,3,6,7,8)`. Mağaza köprüsü `COLLATE Turkish_CI_AS`. Tarih süzgeci SARGable: `s.[Date] >= @YilBas` (bugünkü `'20260101'` sabiti parametreye taşınır, değer aynı).
- Ekranda gösterilmez (AC-1.4); `Operasyon.razor` yüklemeye devam eder.

## H2 — `SadakatQueries.GetWinBackAsync`

```csharp
Task<IReadOnlyList<WinBackRow>> GetWinBackAsync(DateOnly bugun, CancellationToken ct = default);
record WinBackRow(string Ad, string Tel, string Kart, int Frq, decimal ToplCiro, int GunIdle, long MusteriId);
```

| Kolon | Tip | Sözleşme |
|---|---|---|
| `Ad`, `Tel`, `Kart` | `string` | `DerinCrm.dbo.Customer` (müşteri başına tek satır) |
| `Frq` | `int` | `[bugun−365, bugun)` içindeki **satış fişi** (`DocumentsTypeId = 1`) sayısı. İade sayılmaz (AC-2.3) |
| `ToplCiro` | `dec` | Aynı pencerede `(1, 3)` net KDV hariç, iade negatif |
| `GunIdle` | `int` | `DATEDIFF(DAY, tüm zamanlardaki son satış fişi tarihi, @Bugun)` > 90 (AC-2.2) |
| `MusteriId` | `long` | `Sales.CustomersId` (ekranda gösterilmez) |

- **Liste koşulu:** `CustomersId > 0`, iç kart hariç (`IcKartFiltre`), `[bugun−365, bugun)` içinde en az bir satış fişi, `[bugun−90, bugun)` içinde **hiç** satış fişi yok (`NOT EXISTS`), `Frq >= 3`, `ToplCiro >= 500`.
- **Tanecik:** `GROUP BY s.CustomersId` (önce ad + telefon + kart üçlüsüydü; aynı ada sahip iki müşteri birleşiyordu).
- **Sıralama:** `ORDER BY ToplCiro DESC, MusteriId` (eşitlikte belirleyici); `TOP 200` görüntü sınırıdır.
- **Önce:** `SadakatQueries.cs:10-37`. Pencere `[−365, −90)`; son 90 gün koşulu yok (51.309 adayın 23.110'u aktif); `Frq` iadeyi sayıyor; `GETDATE()`.
- Çağıran (`Sadakat.razor`) `bugun`'u `TimeProvider`'dan verir.

## H3 — `RefQueries.GetTedarikciPerformansAsync`

```csharp
Task<IReadOnlyList<TedarikciPerfRow>> GetTedarikciPerformansAsync(DateOnly bas, IReadOnlyList<int> haricMrk, CancellationToken ct = default);
record TedarikciPerfRow(string Marka, int SatisAdet, int IadeAdet, decimal NetCiro, decimal SatisBrut, decimal IadeTutar, int StokAdet,
                        int MrkId, int MagazaStokAdet, int DepoStokAdet);
```

- `MagazaStokAdet`: `stokSonAltDepo_vw`, `ehAltDepo = 0`, `stok > 0`, `ehMekan IN (LokasyonConfig.Subeler)`. Değeri düzeltme öncesindeki mağaza bileşeniyle aynıdır (AC-3.4).
- `DepoStokAdet`: `MerkezDepoStok.CanliCte` → `urn.urnMrkID` (AC-3.1).
- `StokAdet = MagazaStokAdet + DepoStokAdet`; devir hızı ve sipariş sinyali bu değerle hesaplanır (Razor/model mantığı değişmez).
- Satış alt sorgusu değişmez (`SubelerVeDepo` satış hareketinde zararsız, `sql-bulgulari.md`).
- **Önce:** `RefQueries.Envanter.cs:536`, stok `SubelerVeDepo` (mekan 12 ERP defteri).

## H4 — `EticQueries.GetEticKategoriAsync` / `GetEticKategoriUrunAsync` / `GetEticKategoriYilAsync`

İmzalar aynı + `CancellationToken ct = default`. Sonuç kümeleri aynı (`EticKategoriRow(Kategori, Siparis, NetCiro, Adet)` …).

- **Sonra:** `o.STATUS NOT IN ({EticDurum.SiparisIptalIade})`.
- Kategorisi bilinmeyen satırlar (`DERINSIS_LOGOGRUP IS NULL`) bugün dışlanıyor; AC-4.2 için **kategori + bilinmeyen = ana** ilişkisi kanonik sorguda kurulur. Metot `Kategori = NULL` satırını döndürmez (ekran değişmez).
- `GetEticKategoriYilAsync`: `DateTime.Today` → `TimeProvider` (dokunulan kod, K1); `TimeProvider` kurucuya enjekte edilir.

## H4 / H8 — `OdakQueries`

`GetOdakKpiAsync`, `GetOdakAsiriAsync`, `GetUrunlerAsync`, `GetUsulsuzAsync` (e-tic talebi taşıyan `ecom` CTE'si olan dört metot). İmzalar ve sonuç kümeleri aynı.

- `ecom` CTE (OPENQUERY metni): `AND o.STATUS NOT IN ({EticDurum.SiparisIptalIade}) AND d.STATUS NOT IN ({EticDurum.SatirIptalIade})` (AC-4.3). Sabitler tamsayı listesi; injection yok.
- `depo` CTE: `MerkezDepoStok.CanliCte` (AC-8.1). Önce: `StokAyBakiyeMekanBazli`, `MAX(Donem)` (31.08.2026, bir ay bayat).
- `ent.odak_depo_Stok` (ODAK fulfillment deposu) **değişmez**; merkez depo ile karıştırılmaz.

## H5 — `TrafikQueries`

```csharp
Task<TrafikKpi> GetKpiAsync(DateOnly bas, DateOnly bit, CancellationToken ct = default);
record TrafikKpi(int Ziyaretci, int Fis, decimal Net, int Kasiyer, int IadeSayisi);
```

- `Fis = FisTanimi.FisSayisi("s")`, `IadeSayisi = FisTanimi.IadeSayisi("s")`.
- `Net`, `Kasiyer` kapsamı değişmez (`MagazaBelgeleri`, 1001 hariç).
- `GetHeatAsync` (`DailyFis`), `GetPersonelAsync` (`Fis`), `GetGunlukAsync` (`Fis`) aynı ifadeyi kullanır. Sepet ortalaması `Net / Fis`, dönüşüm `Fis / Ziyaretci` (AC-5.2).
- Önce: `TrafikQueries.cs:32,71,168,198`, `COUNT(*)` ya da `satış − iade` (1,2,3,6,7,8).

## H5 / H13 / D-2 — `Queries.GetPeriodAsync`

```csharp
Task<PeriodSummary> GetPeriodAsync(DateOnly start, DateOnly endExcl, DateOnly? prevStart = null, DateOnly? prevEnd = null, CancellationToken ct = default);
record StoreRow(int MekanId, decimal Net, int Fis, decimal Iade, decimal NetPerakende, decimal NetSinav, int IadeSayisi);
```

| Kolon | Sözleşme |
|---|---|
| `Net` | Değişmez (SC-006): `MagazaBelgeleri`, 1001 hariç, iade negatif, KDV hariç |
| `Fis` | `FisTanimi.FisSayisi` (önce: satış − iade, 1,2,6,7,8 dahil) |
| `Iade` | Değişmez: iade tutarı KDV hariç |
| `NetPerakende` | `Net` içinden `NOT SinavMi` olanlar |
| `NetSinav` | `Net` içinden `SinavMi` olanlar. Kontrol: `NetPerakende + NetSinav = Net` (AC-13.1) |
| `IadeSayisi` | `FisTanimi.IadeSayisi` |

- `saatSql` ve `kasSql` (`Queries.cs:145-164`) ile `GetKasiyerDeltaAsync` (`:344-355`): `posMagaza` köprüsü (`Pos → Stores → posMagaza`, `StoresId` doğrudan değil), 1001 hariç, `Fis = FisSayisi`, kasiyer net formülü `NetKdvHaric` (önce iade dalında `ABS(DiscountTotal)` vardı). Kontrol: Σ kasiyer `Net` = Σ mağaza `Net` (D-2).
- `katSql` (kategori karması): 1001 satır düzeyinde dışlanıyor; değişmez. Fark sınırı D-2 kanıtında raporlanır.
- `GetHedefAsync`: değişmez; Ana sayfa notu `HedefTabani.Teyitli == false` iken gösterilir.

## H6 — `MagazaQueries`

```csharp
Task<MagazaDetay?> GetDetayAsync(int mid, DateOnly start, DateOnly endExcl, CancellationToken ct = default);
Task<IReadOnlyList<HeatCell>> GetHeatmapAsync(int mid, DateOnly dun, int gun = 60, CancellationToken ct = default);
```

- `kpiSql`: `Fis = FisSayisi`; `Iade = IadeKdvHaric` (önce `GrossTotal`, KDV dahil, indirim düşülmemiş); `IadeOran = 100 × Iade / satış neti` (satış neti = `1,2,6,7,8` için `Gross − Discount − Vat`); `+ IadeSayisi` (AC-6.3, AC-5.4).
- `uptSql`: pay `SUM(sp.Amount)` ve payda `FisSayisi`, yalnız `DocumentsTypeId = 1`, 1001 hariç (AC-6.4).
- `kampSql` `ind` CTE: `JOIN EncoreMerkez.dbo.SalesProducts sp ON sp.SalesId = spc.SalesId AND sp.[Sequence] = spc.ProductSequence AND sp.IsValid = 1` (AC-6.1). `(SalesId, Sequence)` tekilliği değişmezle korunur.
- Kampanya tablosu tabanı **KDV dahil** kalır ve ekranda etiketlenir (İnsan onayı 7). Kontrol: `Brut − Indirim = Σ geçerli kampanyalı kalem TotalPrice` (AC-6.2).
- `GetHeatmapAsync`: `COUNT(*)` → `FisSayisi` (AC-6.4).

## H7 — `RefQueries.GetMarjAsync` / ABC

```csharp
Task<IReadOnlyList<MarjRow>> GetMarjKategoriAsync(DateOnly bas, DateOnly bit, CancellationToken ct = default);  // ham, süzgeçsiz
Task<IReadOnlyList<MarjRow>> GetMarjAsync(CancellationToken ct = default);   // son 30 gün; görüntü süzgeci (%5–%95) burada
record MarjRow(string Kategori, decimal Ciro, decimal Smm, decimal MarjPct, decimal CiroMaliyetli);
```

- Kaynak `irsHrk` (kanonik şube cirosu): ciro `ehTip 4,100` (+) / `5,101` (−), `ehMekan IN (Subeler)`, `ehAltDepo = 0`. Adet `−ehAdetN` (satışta negatif, iadede pozitif; işaret korunur). Merkez depo toptanı (mekan 12, `eTip 1`) girmez (AC-7.1).
- Kategorisi çözülemeyen ürün `'(kategorisiz)'` satırı olarak döner (LEFT JOIN); maliyeti bilinmeyen ürün `Ciro`'da kalır, `Smm` ve `CiroMaliyetli`'ye girmez. `MarjPct = (CiroMaliyetli − Smm) / CiroMaliyetli`.
- Kontrol (AC-7.2): Σ `Ciro` (`GetMarjKategoriAsync`, süzgeçsiz) = kanonik şube cirosu (100 − 101 + 4 − 5, üç mağaza).
- Önce: `RefQueries.Envanter.cs:443-480`, `irs/irsAyr` `eTip IN (1,4,100)`, mekan 12 dahil, iade yok, `ABS(ehAdetN)`.
- **ABC** (`GetInventoryAsync` içindeki `tAbc`, `RefQueries.cs:118`): ürün cirosu `DocumentsTypeId IN (1,2,3,6,7,8)`, iade negatif; `HAVING > 0` kalır (AC-7.3). Sonuç `AbcClass(Sinif, Adet, Ciro)` aynı.

## H8 — Merkez depo okuyan diğer metotlar

| Metot | Sonra |
|---|---|
| `RefQueries.GetKategoriCesitAsync` | Depo kolonu `MerkezDepoStok.CanliCte` (önce ay sonu `MAX(Donem)`) |
| `RefQueries.GetUrunlerAsync`, `OluStokSql`, `GetOluStokAsync` (sayım) | `wms` alt sorgusu `CanliCte` (önce `paletUrnTnm` + elle liste) |
| `SatinalmaQueries` `#depo` | Zaten canlı (`SatinalmaQueries.cs:227`); parçaya bağlanır, davranış aynı |
| `SatinalmaQueries` `#bal` / `SatinalmaQueries.UrunDetay` geçmiş ay | `AySonuCte` + `@Donem`; değerin yanında görüntü tarihi döner (AC-8.3); görüntü yoksa boş sonuç + "yok" bayrağı (AC-8.4) |

Geçmiş ay bakiyesi döndüren metotlar sonuç kaydına `DateOnly? GoruntuTarihi` alanı ekler (sona). `null` = görüntü yok.

## H9 — `SinavQueries.GetOdemeDurumAsync`

İmza aynı + `ct`. `SinavOdemeDurum` alanları aynı; `NetKdvHaric` anlamı değişir.

- `X` OUTER APPLY kaldırılır. Net, `FisSetCte` kümesinden (satış FE'den, iade `LinkedDocumentId`'den, işaretli) fiş başına bir kez alınır.
- Bir fiş birden çok `SiparisKod`'a bağlıysa fişin neti bağlı sipariş sayısına **eşit bölünür** (İnsan onayı 5).
- Kontrol (AC-9.1): Σ `NetKdvHaric` (tüm durumlar) = `GetSezonKpiAsync(donemId).NetKdvHaric`. `K.Kalem > 0` koşulunun dışarıda bıraktığı siparişlerin neti F0'da ölçülür; sıfır değilse ayrı "kalemsiz" durumu olarak döner.

## H10 — Hata yönetimi

| Yer | Sonra |
|---|---|
| `SabahService.GetAsync` (`:207-212`) | `catch (Exception ex)`: `_log.LogError(ex, "Sabah özeti veri yükleme hatası")`; `Hata = KullaniciMesajlari.VeriAlinamadi`. Servis `ILogger<SabahService>` alır |
| `Sabah`, `Envanter`, `Operasyon`, `SatinalmaAnaliz`, `Esikler`, `Vardiya` sayfaları | `ex.Message` / `ex.GetType().Name` ekrana yazılmaz; `Logger.LogError(ex, "{Ekran} veri yükleme hatası", ekranAdi)`; ekrana `ekranlar.md` § mesajlar. `Vardiya.razor` yüklemesi `try/catch`'e alınır |
| `CONVERT(int, pr.Code)` (Envanter `:46,212`, `Queries` `:91,138,252`, `MagazaQueries:154`, `HediyeCekiQueries:142,168`, `SinavQueries:88`) | `CONVERT(int, CASE WHEN pr.Code NOT LIKE '%[^0-9]%' AND LEN(pr.Code) BETWEEN 1 AND 9 THEN pr.Code END)` (yalnız rakam, int taşması yok; compat 110 uyumlu); çevrilemeyen kayıt `NULL` olur, join dışında kalır, sorgu hata vermez (AC-10.3). Desen `SatisAnaliziTabanService.cs:318` ile aynı amaçta, daha sıkı |

Ortak mesaj sabitleri tek yerde: `dashboard/Data/Tanimlar/KullaniciMesajlari.cs` (`VeriAlinamadi`, `KayitYapilamadi`, `DonemdeKayitYok`, `StokGoruntusuYok`).

## H12 — `MizanQueries`

```csharp
Task<MizanSonuc> GetSonucAsync(int sirketId, int ay = 12, int ayBas = 1);   // imza aynı
internal static MizanOzet OzetHesapla(IReadOnlyDictionary<string, decimal> k, IReadOnlyList<MizanNode> kokler);  // private → internal (test)
record MizanOzet(decimal Nakit, decimal VerilenCek, decimal Alicilar, decimal Saticilar,
                 decimal KdvIndirilecek, decimal KdvHesaplanan, decimal KdvNet,
                 decimal ToplamBorc, decimal ToplamAlacak, decimal AlinanCek, decimal KdvDevreden);
```

- `Nakit = Borc("100","102","108")` (101 çıkarıldı, AC-12.1); `AlinanCek = Borc("101")` (AC-12.2); `KdvDevreden = Borc("190")`; `KdvNet = KdvHesaplanan − KdvIndirilecek − KdvDevreden` (AC-12.3).
- `GmDashboard.csproj`: `<InternalsVisibleTo Include="GmDashboard.Tests" />`.

## D-1 — `RefQueries.GetRfmAsync` (yazarkasa) / `GetLtvAsync`

- RFM `ykSql`: `DocumentsTypeId IN (1,3)`; `Frq = COUNT(CASE WHEN DocumentsTypeId = 1 …)`; `Rec` yalnız satış fişinin son tarihinden; `Mon` iade negatif. Sonuç `RfmSegment` aynı.
- LTV: SQL değişmez; segment etiketi `'Kartsız'` → `'Kayıtlı, kartsız'` (anonim yürü-gel müşteri kapsam dışı olduğu için).

## D-4 — `HediyeCekiQueries.GetBaremKalemAsync`

- `Brut = TotalPrice + DiscountTotalDirect`, `Indirim = DiscountTotalDirect`, `NetKdvDahil = TotalPrice` → aynı (KDV dahil) taban; `Brut − Indirim = NetKdvDahil`.
- Mevcut `Net` (KDV hariç) marj hesabı için kalır, ekranda "(KDV hariç)" etiketiyle ayrı kolondur. Kayda `NetKdvDahil` sona eklenir.
- `GeriDonusumHaric` (RefundReasonId 12 + Code 583160) F0 (b) ölçümüne göre ya `FisTanimi`'ne bağlanır ya da gerekçesiyle kalır.

## Değişmeyen ve kapsam dışı bırakılanlar

- `HediyeCekiQueries` fiş sayıları (`:110,242`) çekle ödenen fiş kavramıdır, perakende fiş göstergesi değildir; dokunulmaz.
- `SinavQueries` fiş sayıları Sınav belgeleridir; dokunulmaz.
- `GunKarsilastirQueries`, `Queries.GetTahminAsync`/`GetGercekCiroAsync`: yalnız dipnot (D-5), SQL değişmez.
