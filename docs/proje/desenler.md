# Desenler — mevcut kodun gerçek konvansiyonları

> Tür: proje tanıtımı (desenler, başvuru) · Kaynak commit: `d5cf345` · İzlenen yollar: `dashboard/**`, `lib/Bkm.Shared/**`, `tests/BkmVardiya.Tests/**`, `sorgular/2026-09-17-vardiya-sp-kur.sql`, `sorgular/2026-06-22-muhasebe-kontrol-v2.sql` · Son doğrulama: 03.10.2026 (/tanit; sayılar `grep`/`wc` ile ölçüldü, kapsam `dashboard/Components`, `Data`, `Models`, `Program.cs` — `bin/obj` hariç)

Bu sayfa olanı anlatır, olması gerekeni değil. Orkestra kural kataloğuyla çelişkiler en alttaki tabloda; hangisinin uyarlanacağı kullanıcının kararı.

## 1. İsimlendirme

- **Sınıf soneki konuya göre:** `*Queries` (salt-okuma SQL, 25 sınıf), `*Service` (durum/süreç), `*Models.cs` (record DTO dosyası). Örnek: `public sealed class MagazaQueries(Db db)` — `dashboard/Data/MagazaQueries.cs:11`.
- **Metot:** İngilizce fiil + Türkçe alan terimi + `Async`: `GetDetayAsync`, `GetOzetAsync`, `GetKumbaraAsync` (`Data/MagazaQueries.cs:29`, `Data/MuhasebeQueries.cs:24`). Tam Türkçe metot da var: `DogrulaAsync`, `KullaniciVarMiAsync`, `SetupAsync` (`Data/AuthService.cs:41`).
- **Alan:** `_camelCase` (`_error`, `_loading` — `Components/Pages/Magaza.razor:257`).
- **Türkçe tanımlayıcı yaygın:** `tools/turkce_tanimlayici_denetimi.py` dashboard'da **3.508 bulgu / 128 dosya**yı "dondurulmuş borç" tabanında tutuyor (yeni dosya 0 tolerans). Türkçe karakterli tanımlayıcı da var: anonim tip üyeleri `Ürün_Adı`, `Özlüce`, `İst_Yolu`, `Yaş_Gün` (`Program.cs:412-421`).
- **Dosya başına çok tip:** `Models/*Models.cs` dosyaları çok sayıda record taşır (ör. `Models/SatisAnaliziModels.cs` 824 satır).
- **Kısmi sınıf ile bölme:** `RefQueries.cs` + `RefQueries.Envanter.cs` + `RefQueries.Operasyon.cs`; `SatisAnaliziQueries{,.Liste,.Excel,.Siparis}.cs`.

## 2. Hata ve sonuç tipi

- **`Result<T>` yok.** Beklenen "bulunamadı" sonucu nullable dönüşle: `Task<MagazaDetay?> GetDetayAsync(...)` → `return null` (`Data/MagazaQueries.cs:29-31`).
- **Enum sonuç** tek yerde: `AuthSonuc` (`Basarili/Kilitli/Kapali…`, `Data/AuthService.cs:41-44`, kullanım `Program.cs:96-105`).
- **Çelişkiyi reddeden değer tipi:** `SayfaSonucu<T>.Olustur(...)` kurucuda anlamsız durumları atar (`Models/SayfaSonucu.cs:57`, gerekçe `:1-25`); 13 geçiş.
- **Razor yükleme deseni:** `try { … } catch (Exception ex) { Logger.LogError(ex, "Veri yükleme hatası"); _error = $"{ex.GetType().Name}: {ex.Message}"; }` (`Components/Pages/Magaza.razor:343`), ekranda `Veri alınamadı: @_error` (`:38`). `ex.Message` UI'a: **51 geçiş / 27 dosya**; bu tam kalıp 22 kez.
- `catch (Exception …)` toplam 136; gövdesiz `catch { }` 3; yorumlu boş catch (`catch { /* … */ }`) birkaç yerde (`Magaza.razor:377,385`).
- Geçici/kalıcı SQL hata ayrımı merkezi: `SqlErrorClassifier.Classify/ShouldRetry` (`lib/Bkm.Shared/Data/SqlErrorClassifier.cs:40,63`), yalnız bağlantı açılışında 2 deneme + log (`lib/Bkm.Shared/Data/Db.cs:174-200`).

## 3. DI kaydı

- Özellik gruplu genişletme metotları: `AddBkmVeri` / `AddBkmDurum` / `AddBkmAsistan` (`dashboard/ServiceRegistration.cs:13,46,61`), `Program.cs:46-48`'den çağrılır. Yeni servis kendi grubuna eklenir, `Program.cs` değişmez.
- Ömür: `Db` Singleton; `*Queries` Scoped; durum servisleri (`GorevService`, `AyarService` …) ve LLM sağlayıcıları Singleton.
- Enjeksiyon: **birincil kurucu** (`public sealed class MagazaQueries(Db db)`); Razor'da `@inject`.
- `IOptions<T>` kullanımı **0**; yapılandırma `Db.LoadEnvStatic()` ile `.env`'den okunur (`lib/Bkm.Shared/Data/Db.cs:205`).

## 4. SQL çağırma şekli

- **Varsayılan: gömülü SQL + Dapper.** C# raw string sabiti, ardından `QueryAsync<record|tuple>`:
  `const string kpiSql = """ SELECT … FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK) … """;` (`Data/MagazaQueries.cs:39-53`) → `c.QuerySingleOrDefaultAsync<(decimal? Net, …)>(kpiSql, par)` (`:54`).
- Paralel sorgu deseni: her sorgu kendi bağlantısıyla, `Task.WhenAll` sonrası `.Result` okunur (`Data/MagazaQueries.cs:34`, `Components/Pages/Envanter.razor:444-447`; `.Result` 55 geçiş, hepsi tamamlanmış görev üzerinde — ÇIKARIM, tek tek doğrulanmadı).
- `CommandDefinition` 51 geçiş (ör. `Data/GunKarsilastirQueries.cs:127`, `cancellationToken: ct` ile).
- **SP çağrısı yalnız 2 yer:** `const string Sp = "DerinSISBkm.bkm.sp_KapanisMudahaleKontrol_v2";` (`Data/MuhasebeQueries.cs:15`) → `conn.QueryAsync<KontrolOzetRow>(Sp, new { Yil = yil, … }, commandType: CommandType.StoredProcedure)` (`:26-31`).
- **3-parçalı ad zorunlu** (bağlantı `master`'da açılır): `DerinSISBkm.dbo.irsHrk`, `EncoreMerkez.dbo.Sales`.
- `WITH(NOLOCK)` **436 geçiş** — fiilî standart.
- Cross-DB string join: `COLLATE Turkish_CI_AS` her iki tarafta (`Data/MagazaQueries.cs:49`; 31 geçiş).
- Tarih: parametre (`DateOnly` → `DateTime`), `>= @start AND < @end` (`Data/MagazaQueries.cs:52`). ISO basic literal `'20260101'` 6 geçiş (ör. `Data/RefQueries.cs:590`), DMY literal 1, `yyyy-MM-dd` literal 0. `BETWEEN` 21 geçiş.
- Yazma: satır içi SQL (`MERGE DerinSISBkm.bkm.Fin_AyKapanis` `Data/MuhasebeQueries.cs:192`; `DELETE`+`INSERT…SELECT` `Data/SatisAnaliziTabanService.cs:112-437`; panel `dbo.Panel*` MERGE/INSERT/DELETE). Fiziksel `DELETE` 9 geçiş (2 ERP app-owned, 7 panel).
- Dapper tuzak kapıları: record sırası `tools/panel_kolon_denetimi.py` (bugün geçti), `DateOnlyTypeHandler` (`Program.cs:438-446`), smallint/tinyint için `CAST(... AS int)`.

## 5. SP header örneği (gerçek)

SP'ler `sorgular/` altında betik olarak durur; başlık bloğu `CREATE` **üstünde** serbest metin yorumdur, Orkestra şablonundaki alanlar (Amaç/Versiyon/Değişiklik/Bağımlılıklar/Çağıranlar/Hata kodları) yok:

```sql
/* ============================================================================
   bkm.sp_Vrd_KisiGunDoldur — kişi-gün tabanının T-SQL karşılığı (plan 47, Faz 1)
   Hedef : DEV → BkmPanel @ BT-FIKRI\SQLEXPRESS. PROD'a yazma YOK.
   … (gerekçe ve ölçüm notları)
   ============================================================================ */
CREATE OR ALTER PROCEDURE bkm.sp_Vrd_KisiGunDoldur
    @Bas date, @Bit date, @SayimBas date = NULL, @Konus bit = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    …
    THROW 50001, 'KOSAMADI: @SayimBas, @Bas''tan once olamaz.', 1;
```

Kaynak: `sorgular/2026-09-17-vardiya-sp-kur.sql:1-33`. `CREATE OR ALTER`, `NOCOUNT`, `XACT_ABORT`, 5xxxx `THROW` var; ad öneki `sp_`. DerinSISBkm `bkm` şemasında 118 SP'nin **27'si `sp_`**, **0'ı `usp_`** önekli (ölçüldü, `sys.procedures`).

## 6. Test isimlendirmesi

Dashboard'da test yok. Tek test projesinde (vardiya) **İngilizce cümle, alt çizgili**: `Manager_sees_only_own_branch`, `Preconditions_population_is_sufficient` (`tests/BkmVardiya.Tests/BranchScopeTests.cs:53,77`), sınıf `<Konu>Tests`. xUnit, 29 test, atlama bayrağı yok.

## 7. Diğer gözlenen desenler

- Namespace: file-scoped, klasörle uyumlu (`GmDashboard.Data`, `GmDashboard.Data.Asistan`) — 83/83 dosya.
- Sınıflar çoğunlukla `sealed` (81/91), DTO'lar `record` (250 geçiş).
- Log: `ILogger` mesaj şablonu; interpolasyonlu log **0**.
- Async: `Data/` içinde 195 `public Task<…>` metodunun **15**'i `CancellationToken` alıyor.
- Saat: `DateTime.Today` 102, `DateTime.Now` 15, `TimeProvider` 0.
- `async void` 1 (olay işleyicisi, `Components/Layout/MainLayout.razor:211`).
- UI: DaisyUI semantik sınıflar; ikonlar `<i data-lucide>` (200 geçiş) + `lucide.createIcons()`; Chart.js `wwwroot/js/charts.js` JS interop; 5 ApexCharts bileşeni.
- Gerekçe yorumları yoğun ve ölçüm tarihli ("ÖLÇÜLDÜ 09.09…"); karar izi koda gömülü.

## Kural kataloğu ile çelişkiler (Orkestra `kurallar-dotnet` / `kurallar-sql` ↔ mevcut kod)

| Kural ID | Katalog | Mevcut desen | Örnek sayısı (ölçüldü) | Örnek |
|---|---|---|---|---|
| NAM (dil) | alan terimi Türkçe, teknik kalıp İngilizce; **Türkçe karakter yok** | proje kuralı (`turkish-ui.md`) "kod İngilizce" diyor; kod karışık; Türkçe karakterli tanımlayıcı var | 3.508 Türkçe tanımlayıcı bulgusu / 128 dosya (dondurulmuş); Türkçe karakterli 4+ | `Program.cs:412-421` |
| NAM (dosya) | dosya başına bir public tip | `*Models.cs` çok tipli | 19 Models dosyası | `Models/SatisAnaliziModels.cs` |
| CS (boyut) | sınıf ≤300, metot ≤40 | büyük dosyalar | 300+ satır 39 dosya, 500+ 20 (razor 12) | `Pages/SatisAnaliziUrun.razor` 1.212 |
| CS (saat) | `DateTime.Now` yasak → `TimeProvider` | `DateTime.Today/Now` | 102 + 15; TimeProvider 0 | `Program.cs:162` |
| ASY | her I/O metodu `CancellationToken` | çoğu almıyor | 15 / 195 | `Data/MagazaQueries.cs:29` |
| ASY | `.Result` yasak | `Task.WhenAll` sonrası `.Result` | 55 | `Pages/Envanter.razor:444` |
| ERR / SEC | kullanıcıya iç detay yok; `catch (Exception)` yalnız dış katman | sayfada `ex.Message` gösterimi; sayfa başına catch | 51 / 27 dosya; `catch (Exception` 136; boş catch 3 | `Pages/Magaza.razor:343` |
| ERR (Result) | beklenen hata `Result`/ProblemDetails | nullable dönüş / enum | `Result<` 0 (7 geçişin hepsi başka tip) | `Data/MagazaQueries.cs:29` |
| ARC-001…005 | Api → Application → Domain, port arayüzü | tek proje, Razor → Queries doğrudan | 1 proje; arayüz yalnız `ILlmProvider` | `ServiceRegistration.cs:13` |
| ARC-004 | endpoint'te iş/biçim mantığı yok | `Program.cs` Excel uçları ~250 satır mantık | 3 uç | `Program.cs:156-404` |
| DAT-002 | yazma SP üzerinden | satır içi MERGE/INSERT/DELETE | 13 yazma ifadesi (2 ERP hedefi) | `Data/MuhasebeQueries.cs:192` |
| DAT (okuma) | `CommandDefinition` + CT | çoğunlukla düz `QueryAsync(sql, param)` | `CommandDefinition` 51 / `OpenAsync` 149 | `Data/MagazaQueries.cs:54` |
| DAT-009 | her okuma limit/sayfalama | `SayfaSonucu` yalnız satış analizinde | 13 geçiş | `Models/SayfaSonucu.cs:57` |
| Config | `IOptions<T>` + `ValidateOnStart` | `.env` doğrudan okunur | `IOptions` 0 | `lib/Bkm.Shared/Data/Db.cs:205` |
| PKG-001 | `Directory.Packages.props` | sürüm her csproj'da | 6 csproj; Muhasebe Dapper 2.1.66 / SqlClient 6.0.1 (kayma) | `muhasebe/Muhasebe.csproj` |
| PKG-003 | `global.json` | yok | 0 | — |
| PKG-004 | `.slnx` | `Pusula.sln` | 1 | — |
| Build | `TreatWarningsAsErrors`, analyzer latest-recommended, `.editorconfig` | yok (yalnız BannedApiAnalyzers, lib + vardiya-app) | build 6 uyarı | `Pages/Vardiya.razor:372` |
| SEC | endpoint varsayılan `[Authorize]` | yalnız non-Development'ta `FallbackPolicy`; Development anonim | 1 karar noktası | `Program.cs:32-37` |
| Test | `Metot_Senaryo_Beklenen` | İngilizce cümle snake_case; dashboard'da test yok | 29 test (vardiya); dashboard 0 | `BranchScopeTests.cs:77` |
| SP-013 | NOLOCK yok | NOLOCK fiilî standart | 436 | `Data/MagazaQueries.cs:46` |
| SQL ad | `usp_` öneki, `sp_` yasak | `bkm.sp_*` | 27 / 118 `bkm` SP'si; `usp_` 0 | `Data/MuhasebeQueries.cs:15` |
| SP-002 | yapılandırılmış header | serbest yorum bloğu CREATE üstünde | 2/2 incelenen SP | `sorgular/2026-09-17-vardiya-sp-kur.sql:1-19` |
| QRY (alias) | `a,b,c` tek harf alias yasak | tek harf alias yaygın (`s`, `p`, `i`, `u`) | `JOIN … <harf> ON` 108 | `Data/MagazaQueries.cs:46-49` |
| QRY (BETWEEN) | datetime'da `>= AND <` | çoğunlukla uyumlu; BETWEEN var | 21 | — |
| RUN-001 | DMY literal | parametre + ISO basic literal | ISO basic 6 (bir kısmı yorum), `yyyy-MM-dd` 0 | `Data/RefQueries.cs:590` |
| RUN-004 | compat 110'da yasak fonksiyonlar | uyumlu (geçişler yalnız yorumda) | 0 gerçek kullanım | — |
| RUN-005 | para `DECIMAL(18,4)` | legacy DB'ler `decimal(18,2)`, `decimal(15,2/3)`, JOKER `money`; C# `decimal` | değiştirilemez (kaynak şema) | `veritabani.md` |
| RUN-006 | `src.*` salt okunur katman | `src` şeması yok | 0 | — |
| RUN-007 | okumada soft-delete filtresi | yalnız `SalesProducts.IsValid` filtreleniyor; `Products/Stores.IsDeleted`, `J_ORDERS.ACTIVE` kullanılmıyor; DerinSIS'te kolon yok | `IsValid=1` 24 / SalesProducts 31 | `veritabani.md` § Soft-delete |
| RUN-008 | hard DELETE yasak | app-owned ön-agrega ve panel tablolarında fiziksel DELETE | 9 | `Data/SatisAnaliziTabanService.cs:127` |
