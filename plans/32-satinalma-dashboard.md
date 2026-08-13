# plan-32 — Satınalma Hesap-Sorma Dashboard Sayfası

**Tier:** 3 (kullanıcı-görünür yeni sayfa + yeni SQL + Razor + nav)
**Durum:** onaylandı (kullanıcı) — uygulanıyor
**Tarih:** 2026-08-13

## Problem
Satınalma hesap-sorma raporu şu an sadece Excel (Python emitter) + SSMS (DINAMIK SQL). Dashboard'da yok → GM panelde göremiyor.

## Çözüm (emitter-ayrımı)
DINAMIK SQL = **çekirdek** (iş mantığı orada, Python ile birebir doğrulandı). Dashboard = **yeni emitter** — aynı SQL'i Dapper ile çalıştırır, çekirdeği kopyalamaz, port eder.

## Kapsam
- `Models/SatinalmaModels.cs` — `SatinalmaSatir` (24 kolon).
- `Data/SatinalmaQueries.cs` — `GetAsync(string ay0)`: DINAMIK port (3-part `DerinSISBkm.*` isim + `@AY0` param, OPENQUERY linked kalır). `Db.OpenAsync` salt-okuma (erp-write-policy).
- `Components/Pages/Satinalma.razor` — `/satinalma`: ay seçici (son 12 ay, varsayılan son-biten) + KPI band + değerlendirme-grubu filtre (checkbox, FAZLA+ÖLÜ ön-seçili) + tablo (DaisyUI token, renk-standardi).
- `Models/NavRegistry.cs` +1 satır · `ServiceRegistration.cs` +1 `AddScoped`.

## Kararlar (kullanıcı onayı)
- Tablo: seçimli filtre, kritikler (FAZLA/ÖLÜ) ön-seçili.
- Varsayılan ay: son biten ay (canlı-stok ay-sonu ≈ doğru).

## Riskler
- Perf: DINAMIK temp-table + OPENQUERY ~5-15s → loading spinner (CommandTimeout 240s var).
- 3-part isim zorunlu (master katalog, Err 208 — sql-server-conventions 23.06 dersi).

## Done
Build yeşil · sayfa açılır · Temmuz verisi DINAMIK/Excel ile tutarlı · nav görünür.
