# Yapı — çözüm haritası, katmanlar, giriş noktaları

> Tür: proje tanıtımı (yapı) · Kaynak commit: `d5cf345` · İzlenen yollar: `Pusula.sln`, `*/**.csproj`, `dashboard/`, `lib/Bkm.Shared/`, `vardiya-app/`, `tests/`, `asistan/`, `muhasebe/`, `sorgular/`, `scripts/`, `sema/`, `tools/` · Son doğrulama: 03.10.2026 (/tanit)

## Depo nedir

`pusula` çok-projeli bir **analitik çalışma alanı**: kanonik şema bilgisi (`sema/`), arşiv SQL (`sorgular/`), Python rapor betikleri (`scripts/`), denetim kapıları (`tools/`), planlar (`plans/`) ve birkaç .NET uygulaması. Bu doküman **odak: `dashboard/`**; diğerleri yalnız dashboard ile ilişkileri kadar.

## Çözüm haritası (ölçüldü: `Pusula.sln` + `find -name *.csproj`)

| Proje | Yol | Tür | Çözümde mi | ProjectReference |
|---|---|---|---|---|
| **GmDashboard** | `dashboard/GmDashboard.csproj` | Blazor Server (Web SDK) | evet | → `lib/Bkm.Shared` |
| Bkm.Shared | `lib/Bkm.Shared/Bkm.Shared.csproj` | sınıf kütüphanesi | evet | — |
| BkmVardiya | `vardiya-app/BkmVardiya.csproj` | Razor Pages (Web SDK) | evet | → `lib/Bkm.Shared`, → `../../Solum/src/{Solum.Web, Solum.Identity, Solum.Sql.SqlServer}` (depo DIŞI, `C:\dev\Solum`) |
| BkmVardiya.Tests | `tests/BkmVardiya.Tests/` | xUnit | evet | → `vardiya-app` |
| BkmAsistan | `asistan/BkmAsistan.csproj` | konsol (Telegram botu) | evet | — |
| diskscan | `tools/diskscan/` | konsol aracı | evet | — |
| Muhasebe | `muhasebe/Muhasebe.csproj` | Web | **hayır** | — |
| RaporApp, SsmsExcelExporter | `sorgular/03-kampanya/*` | yardımcı | **hayır** | — |

Bağımlılık yönü: `GmDashboard → Bkm.Shared ← BkmVardiya → Solum.*`. Döngü yok. Dashboard'ın test projesi **yok** (tek test projesi vardiya uygulamasını sınar).

## dashboard/ klasör düzeni (ölçüldü)

```text
dashboard/
  Program.cs              446 satır — host, auth, minimal API uçları (login/setup/Excel/healthz), pipeline
  ServiceRegistration.cs  özellik-bazlı DI: AddBkmVeri / AddBkmDurum / AddBkmAsistan
  GlobalUsings.cs         Bkm.Shared.Data + Bkm.Shared.Models global using
  Components/
    App.razor, Routes.razor, _Imports.razor
    Layout/   MainLayout (DaisyUI drawer+navbar+btm-nav), ReconnectModal (.razor/.css/.js)
    Pages/    43 .razor (41 @page; SatisAnaliziTablo ve MizanDugum alt bileşen)
    Shared/   13 ortak bileşen (AppAreaChart, AppDataTable, AppKpiCarousel, ExcelButton, Modal, Sayfalama …)
  Data/       50 .cs — *Queries (Dapper + gömülü SQL), *Service (durum/forecast/auth), Asistan/ (13 .cs, LLM zinciri)
  Models/     19 .cs — record DTO'lar, NavRegistry, SayfaSonucu<T>, filtre modelleri
  Styles/     app.tailwind.css (kaynak) → wwwroot/app.css (üretilen, commit'li)
  wwwroot/    app.css, js/charts.js (Chart.js interop), js/theme-colors.js, manifest.json, service-worker.js, ikonlar
  Data/okul-takvimi.json  MEB takvimi (output'a kopyalanır)
```

Büyüklük (ölçüldü, `wc -l`): Components+Data+Models toplam 33.715 satır. 500+ satır dosya **20** (12'si `.razor`), 300+ satır **39**. En büyükler: `Data/SatisAnaliziQueries.Liste.cs` 1.244 · `Pages/SatisAnaliziUrun.razor` 1.212 · `Data/SatisAnaliziQueries.cs` 1.203 · `Pages/SatisAnalizi.razor` 1.200 · `Models/SatisAnaliziModels.cs` 824.

## Katmanlar (gerçekte olduğu gibi)

Dashboard **tek projeli, iki katmanlı** bir yapı:

1. **Sunum** — `Components/Pages/*.razor`: `@inject` ile `*Queries`/`*Service` sınıflarını doğrudan çağırır, `@code` içinde yükleme/hata durumu tutar.
2. **Veri** — `Data/*Queries.cs`: SQL metni (C# raw string `"""…"""`) + Dapper çağrısı + çoğu zaman iş mantığı (filtre, agrega, sınıflama) aynı sınıfta. Bağlantı `Bkm.Shared.Data.Db` fabrikasından.
3. **Model** — `Models/*.cs`: record DTO'lar; bazıları hesaplanmış property taşır (ör. `RefModels.cs:146 DevirHizi`).

Application/Domain/Infrastructure ayrımı, port arayüzü, handler yok. İş hesabının bir bölümü SQL'de (ERP SP'leri, `bkm.*` view'lar), bir bölümü Python'da (`scripts/forecast` — `ForecastService` `python run.py` süreci başlatır, `Data/ForecastService.cs:14-31`).

### Mevcut sapmalar (Orkestra ARC kurallarına göre)

| Kod | Gözlem | Kanıt |
|---|---|---|
| ARC-001/002/005 | Katman/proje ayrımı yok; Razor sayfası veri sınıfını doğrudan çağırıyor, dış sistem (LLM, Google, python) port arayüzü olmadan | `ServiceRegistration.cs:13-74`; yalnız `ILlmProvider` arayüzü var (`Data/Asistan/ILlmProvider.cs`) |
| ARC-004 | Minimal API uçlarında iş/biçim mantığı (Excel sayfa kurgusu, eşik, açıklama metinleri) `Program.cs` içinde | `Program.cs:156-404` (~250 satır) |
| ARC-010 | "Data" klasörü sorgu, durum servisi, auth, Excel dönüştürücü, forecast süreç yöneticisini birlikte taşıyor | `Data/` listesi (AuthService, ExcelExport, ForecastService, NotifState, PerfState) |
| ARC-008 | `lib/Bkm.Shared` plan 48 ile eklenmiş (ADR yerine plan) — bilgi | `GmDashboard.csproj` yorum satırı |

## SQL dosyalarının yeri

- **Dashboard SQL'i** `dashboard/Data/*.cs` içinde gömülü (kural: "dashboard `*.cs` = kodun evi", `.claude/rules/semantic-layer.md`). Ayrı `.sql` dosyası yok.
- **Arşiv/keşif SQL'i** `sorgular/` (161 girdi: tarihli `YYYY-MM-DD-*.sql` + `01-ciro … 07-sistem` konu klasörleri).
- **SP/DDL betikleri** de `sorgular/` altında (ör. `sorgular/2026-06-22-muhasebe-kontrol-v2.sql` → `bkm.sp_KapanisMudahaleKontrol_v2`, `sorgular/2026-09-09-satis-analizi-taban-tablo-kur.sql`). `db/` klasörü, migration aracı, tSQLt YOK.
- **Semantik katman** `sema/*.yaml` (bridges/entities/codes/metrics/queries/locations + `degismezler.json`).

## Giriş noktaları

| Giriş | Yer |
|---|---|
| Web host | `dashboard/Program.cs` (top-level statements); `dotnet run` → `http://0.0.0.0:5112` (`Properties/launchSettings.json:8`) |
| Startup yan etkisi | `LokasyonConfig.InitAsync` — `posMagaza`'dan mekan listesini yükler (`Program.cs:53-55`) |
| Blazor kök | `Components/App.razor` → `Routes.razor` → `Layout/MainLayout.razor` |
| HTTP uçları | `/login`, `/setup`, `/auth/*`, `/auth/google*`, `/healthz`, `/ca.crt`, `/api/*-excel` (`Program.cs:79-429`) |
| CSS build | `dashboard/package.json` `build:css` (MSBuild target `BuildTailwindCss`, `node_modules` varsa) |

## Dashboard ile ilişkili diğer alanlar

| Alan | İlişki |
|---|---|
| `lib/Bkm.Shared` | `Db` bağlantı fabrikası (`.env` okur), `SqlErrorClassifier`, `VardiyaQueries` — dashboard `/vardiya` sayfası bunu kullanır |
| `sema/` | Sorgu yazarken kanonik köprü/kod kaynağı; asistan aracı `sema_oku` sema'yı okur (`Data/Asistan/AsistanAraclar.cs`) |
| `scripts/` (79 dosya) | Kardeş emitter'lar (Excel) — ör. `scripts/sezon_aksiyon_listesi_excel.py` dashboard Excel ucuyla aynı iş mantığını taşır (`Program.cs:292`); `scripts/forecast` panelin tahmin kaynağı |
| `tools/` | Kapılar: `panel_kolon_denetimi.py` (Dapper record sırası), `turkce_tanimlayici_denetimi.py` (dashboard dahil, cırcır tabanı), `sema_degismez.py`, `vardiya_kapsam_denetimi.py` |
| `vardiya-app/` | Ayrı uygulama (Solum tabanlı), aynı `Bkm.Shared`'ı paylaşır |
| `dashboardv2/` | Yalnız referans HTML + `HomeV2.razor` taslağı |
| `asistan/` | Ayrı konsol Telegram botu (dashboard'daki Genius'tan bağımsız) |
| `.claude/hooks/git-pre-commit-panel.sh` | `panel_kolon_denetimi.py` koşar; bu klonda `.git/hooks/pre-commit` **kurulu değil** (ölçüldü: `ls .git/hooks` yalnız `*.sample`) |
