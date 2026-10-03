# Teknoloji — sürümler, paketler, build ve test

> Tür: proje tanıtımı (teknoloji, başvuru) · Kaynak commit: `d5cf345` · İzlenen yollar: `dashboard/GmDashboard.csproj`, `dashboard/package.json`, `dashboard/Components/App.razor`, `lib/Bkm.Shared/Bkm.Shared.csproj`, `vardiya-app/BkmVardiya.csproj`, `tests/BkmVardiya.Tests/BkmVardiya.Tests.csproj`, `asistan/BkmAsistan.csproj`, `muhasebe/Muhasebe.csproj`, `package.json` · Son doğrulama: 03.10.2026 (/tanit, komutlar bu oturumda koşuldu)

## Çalışma zamanı

| Bileşen | Sürüm | Kanıt |
|---|---|---|
| .NET SDK (makinede) | 10.0.401 | `dotnet --version` |
| Hedef çerçeve | `net10.0` (tüm .NET projeleri) | `*.csproj` `TargetFramework` |
| `global.json` | **yok** | depo kökü `ls` |
| `Directory.Build.props` / `Directory.Packages.props` | **yok** (merkezi paket yönetimi yok) | depo kökü `ls` |
| Kök `.editorconfig` | **yok**; yalnız `lib/Bkm.Shared/.editorconfig` (ban-list şiddeti) | `ls -a` |
| Çözüm biçimi | `Pusula.sln` (klasik; `.slnx` değil) | depo kökü |
| Python | 3.12.10 | `python --version` |
| Node | 24.19.0 (Tailwind derlemesi için) | `node --version` |

Proje ayarları (`GmDashboard.csproj`): `Nullable=enable`, `ImplicitUsings=enable`, `BlazorDisableThrowNavigationException=true`. `TreatWarningsAsErrors`, `AnalysisLevel`, `EnforceCodeStyleInBuild` **hiçbir** csproj'da yok (ölçüldü: `grep -l TreatWarningsAsErrors` boş).

## NuGet paketleri

### GmDashboard (`dashboard/GmDashboard.csproj`)

| Paket | Sürüm | Kullanım |
|---|---|---|
| Dapper | 2.1.79 | tüm veri erişimi |
| Microsoft.Data.SqlClient | 7.0.1 | SQL Server sürücüsü |
| Blazor-ApexCharts | 6.1.0 | mobil grafik (5 `<ApexChart` kullanımı) |
| MiniExcel | 1.35.0 | Excel uçları (akışla) |
| Markdig | 1.3.1 | asistan yanıtı markdown → HTML |
| Google.Apis.Auth / Calendar.v3 / Gmail.v1 | 1.75.0 / 1.74.0.4154 / 1.74.0.4162 | asistan Gmail+Takvim araçları |
| LLamaSharp + Backend.Cpu | 0.27.0 | yerel LLM — `LlmService` DI'dan **kaldırılmış**, paket hâlâ referanslı (`Program.cs:45`) |

### Diğer projeler

| Proje | Paketler |
|---|---|
| Bkm.Shared | Dapper 2.1.79 · SqlClient 7.0.1 · Logging.Abstractions 10.0.0 · Configuration.Abstractions 10.0.0 · **BannedApiAnalyzers 5.6.0** (`T:Dapper.SqlMapper` yasak, boğaz `VrdSql.cs`) |
| BkmVardiya | BannedApiAnalyzers 5.6.0 + Solum (ProjectReference, `C:\dev\Solum`) |
| BkmVardiya.Tests | Microsoft.NET.Test.Sdk 17.12.0 · xunit 2.9.2 · xunit.runner.visualstudio 2.8.2 · Mvc.Testing 10.0.0 |
| BkmAsistan | Dapper 2.1.79 · LLamaSharp 0.27.0 · Microsoft.Data.Sqlite 10.0.9 · Telegram.Bot 22.10.1 |
| Muhasebe (çözüm dışı) | **Dapper 2.1.66 · SqlClient 6.0.1** (dashboard'dan geride — sürüm kayması) · Negotiate 10.0.9 · ClosedXML 0.105.0 |

Sürüm eşitliği elle korunuyor: `Bkm.Shared.csproj` yorumu "Sürümler dashboard ile AYNI tutulur; ayrışırsa NU1605".

## Veri erişimi

- **Dapper + gömülü SQL** (raw string). Saklı yordam çağrısı yalnız 2 yerde (`Data/MuhasebeQueries.cs:31,43` → `bkm.sp_KapanisMudahaleKontrol_v2`). EF Core yok, ADO.NET doğrudan yok.
- Bağlantı: `Bkm.Shared.Data.Db` — `.env`'den beş hedef: ERP (`OpenAsync`, varsayılan katalog `master`, 3-parçalı ad zorunlu), JOKER (`OpenJokerAsync`), Zirve (`OpenZirveAsync`), panel (`OpenPanel`/`OpenPanelAsync`). Geçici hatada en çok 2 yeniden deneme + log (`lib/Bkm.Shared/Data/Db.cs:173-200`). DMY, bağlantı dizesinde `CurrentLanguage=Turkish` ile (`Db.cs:44`).
- Kullanım sayıları (ölçüldü, grep): `OpenAsync()` 149 · `OpenJokerAsync` 31 · `OpenZirveAsync` 3 · `OpenPanel*` 46 · `CommandDefinition` 51 · `WITH(NOLOCK)` 436.
- Python tarafı: `pyodbc` 31 dosya, `pymssql` 11, `openpyxl` 131 import (Excel emitter'lar).

## Frontend

| Parça | Sürüm/kaynak |
|---|---|
| Blazor Server (Interactive Server render mode) | .NET 10 (`Program.cs:17-18`, `432-433`) |
| Tailwind CSS | 3.4.17 (`dashboard/package.json` devDependency) |
| DaisyUI | 4.12.14 — tema `corporate` (+ `business`) |
| Chart.js | **CDN `chart.js@4`** (sürüm sabit değil) + `chartjs-plugin-datalabels@2` (`Components/App.razor:27-28`); interop `wwwroot/js/charts.js` |
| ApexCharts | Blazor-ApexCharts 6.1.0 |
| İkon | **CDN `lucide@latest`** (`App.razor:29`) — sabitlenmemiş; 200 `data-lucide` kullanımı |
| PWA | `wwwroot/manifest.json` + `service-worker.js` (yalnız kurulum için; fetch'e karışmaz, önbellek yok) |

`wwwroot/app.css` üretilen dosyadır ve commit'lidir; bu makinede `dashboard/node_modules` yok, yani `dotnet build` Tailwind adımını atlar (`GmDashboard.csproj` `Condition="Exists('node_modules')"`).

## Test çatıları

- **xUnit** — yalnız `tests/BkmVardiya.Tests` (vardiya uygulaması). Panel DB'ye bağlanan uçtan uca testler; atlama bayrağı yok (DB yoksa kırmızı).
- **Dashboard için otomatik test yok.** Yerine metin/şema kapıları: `tools/panel_kolon_denetimi.py`, `tools/turkce_tanimlayici_denetimi.py`, `tools/sema_degismez.py`, `tools/sema_sorgu_dumani.py`.
- Python `test_*.py`: 0 dosya. Kökteki `package.json` `test` betiği eski MCP sunucusunun (`src/`, dondurulmuş) testleridir.

## Build / test komutları (bu oturumda koşuldu)

| Komut | Çıkış | Sonuç |
|---|---|---|
| `dotnet build dashboard/GmDashboard.csproj -nologo -v q` | 0 | **0 hata, 6 uyarı** (CS8602 `SatisAnaliziTablo.razor:69`; CS0169/CS0414 ×5 `Vardiya.razor:372-373`), 31,6 sn |
| `dotnet test tests/BkmVardiya.Tests/BkmVardiya.Tests.csproj --list-tests` | 0 | 29 test listelendi (10 sınıf); Solum projeleri `C:\dev\Solum`'dan derlendi |
| `python tools/panel_kolon_denetimi.py` | 0 | "Denetim geçti · 0 uyarı · 0 kırık" |
| `python tools/turkce_tanimlayici_denetimi.py` | 0 | "Denetim geçti · 194 dosya · dondurulmuş borç 3508 bulgu (128 dosya)" |
| `python tools/sema_denetim.py` | 0 | 545 kayıt · KIRIK 0 · UYARI 606 |
| `./ork sema denetle` | — | **KOŞAMADI**: "`sema` aracı bulunamadı" |

Testler **koşulmadı** (yalnız listelendi): panel DB'si (`PANEL_DB_HOST`) bu makineden erişilemiyor (sqlcli `--profile panel` → error 26, "Belirtilen Sunucuyu/Örneği Bulma Hatası"); koşulsa kırmızı dönerdi ve bu kod kusuru anlamına gelmezdi.

Çalıştırma:

```bash
cd dashboard && npm install && npm run build:css   # yalnız stil değiştiyse
dotnet run --project dashboard/GmDashboard.csproj   # http://0.0.0.0:5112
```
