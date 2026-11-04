# Görevler 002: Telefon kabuğu ve ekranlar

> **Uygulayıcılar için:** Bu liste `/uygula 002` ile görev görev yürütülür. Her görev: test hattı → kod → kapılar → inceleme. Yalnız kendi görev metninizi okuyarak çalışabilmelisiniz; komşu görevlerin adları "Arayüzler" satırındadır. Kontratlardaki Türkçe kod adlarının yerine § Ad eşlemesi'ndeki adlar geçer.

**Spec:** `specs/002-mobil-kabuk-ekran/spec.md` (Onaylandı 08.10.2026, değişiklik 1–3) · **Plan:** `specs/002-mobil-kabuk-ekran/plan.md` (Onaylandı 09.10.2026) · **Kontratlar:** `specs/002-mobil-kabuk-ekran/kontratlar/` · **Veri modeli:** `veri-modeli.md` · **ADR:** `docs/ADR/007-mobil-duzen-olcumu-playwright.md` (Önerildi) · **Tarih:** 09.10.2026

## Global kısıtlar

Her görevin gereksinimine örtük olarak dahildir.

### Dal, dalga ve dosya sahipliği (plan K10, § Uygulama sırası)

- Dal `ork/002-mobil-kabuk-ekran`, **master'dan** açılır. Yeniden tabanlama yok; 001 dalı master'ı `git merge` ile alır (001 T-085).
- **Dalga 1** (T-001…T-040) 001'i beklemez; master'a merge insan kararıdır. **Dalga 2** (T-041…T-073) 001 master'a girdikten sonra başlar. **Dalga 3** (T-074, T-075) kapı açma commit'leridir; her biri `specs/001-panel-veri-duzeltme/kabul-sonucu.md` satırına bağlıdır.
- **Dalga 1, 001'in dokunduğu dosyalara girmez.** Tek dar istisna: `dashboard/Components/Pages/Home.razor` yalnız `@page "/"` satırının silinmesi (T-034). Bu commit'in gövdesinde `001 dosyası, dar istisna` yazar. ON-1 (T-001) satırları 001 T-029/T-031 karşılığıdır.
- 001'e ait, Dalga 1'de dokunulmayan dosyalar: `Home.razor` (gövde), `Sabah.razor`, `SabahService.cs`, `Musteri.razor`, `Trafik.razor`, `Sadakat.razor`, `Magaza.razor`, `Magazalar.razor`, `Eticaret.razor`, `Sinav.razor`, `Tahmin.razor`, `Envanter.razor`, `Operasyon.razor`, `Vardiya.razor`, `Mizan.razor`, `SatisAnalizi.razor`, `SatisAnaliziTablo.razor`, `SatisAnaliziUrun.razor`, `Bulunurluk.razor`, `SatinalmaUrunDetay.razor`, `HediyeCeki.razor`, `OdakStok.razor`, `BaskisiYok.razor`, `SatinalmaAnaliz.razor`, `SezonAksiyon.razor`, `Esikler.razor`, `Queries.cs`, `EticQueries.cs`, `SinavQueries.cs`, `RefQueries*.cs`, `SadakatQueries.cs`, `TrafikQueries.cs`, `FinansQueries.cs`. 002 bu `*Queries.cs` dosyalarını hiç değiştirmez, yalnız çağırır.
- **Test altyapısının 002 dalına gelişi (denetleyici kuralı, 09.10.2026):** `lib/Bkm.TestAltyapi/**`, `tests/GmDashboard.Tests/**` ve `Pusula.sln` içindeki bu iki projenin satırları, T-001'de 001 dalının **tek bir commit'indeki hâliyle birebir** alınır. Sonrasında 002 bu dosyalara **yalnız ekleme** yapar (yeni test dosyası, yeni klasör). Var olan dosyalar değiştirilmez. Tek istisna: `tests/GmDashboard.Tests/GmDashboard.Tests.csproj` ve `tests/GmDashboard.Tests/Directory.Packages.props` dosyalarına Playwright paketi **ayrı satır** olarak eklenir (T-003); merge'te bunu 001 T-085 çözer (birleşim: 001 paketleri + `Microsoft.Playwright`).
- Aynı dosyaya dokunan görevler `[P]` değildir ve "Bağımlılık" satırıyla sıralıdır. Zincirler: `MainLayout.razor` T-018 → T-019 → T-021 → T-022 · `NavRegistry.cs` T-010 → T-020 (Dalga 2'de T-065, T-067) · `Program.cs` T-007 → T-025 · `ServiceRegistration.cs` T-001 → T-006 → T-008 · `App.razor` T-018 → T-026 · `Styles/app.tailwind.css` T-019 → T-024 · `Ayarlar.razor` T-022 → T-033 · `GeniusBellek.razor` T-028 → T-035 · `Today.razor` T-034 → T-049 → T-050 → T-051 → T-052 → T-054 → T-055 → T-053 · `LegacyRedirect.razor` T-035 → T-055 → T-065 → T-067 → T-068.
- `dashboard/wwwroot/app.css` (Tailwind çıktısı) her UI görevinde `dashboard/` içinde `npm run build:css` ile yeniden üretilir ve o görevin commit'iyle gider (`commit-discipline.md` § paylaşılan dosya). `node_modules` yoksa adım atlanır ve raporda yazılır.

### Ad eşlemesi — kontrat adı → kod adı (bağlayıcı)

Yeni kod tanımlayıcıları İngilizce teknik kalıp + `tools/kod-sozcukleri.txt` ak listesindeki alan terimleridir (`cari`, `mizan`, `sinav`, `gelir`, `hediye`, `sadakat`, `vardiya` …). Kapı: `python tools/turkce_tanimlayici_denetimi.py <dosyalar>` yeni dosyada 0 bulgu; dashboard'daki eski dosyalar çırçır tabanını aşamaz (`tools/turkce-taban.json`). Ak listede olmayan İngilizce sözcük için görevin sonunda denetleyici `tools/kod-sozcukleri.txt`'e satır ekler, ayrı `chore(bkm): kod sözcük ak listesi (T-0NN)` commit'iyle (001 T-021/T-022 deseni). Gerekçe: 001 defteri 08.10.2026 kararı "kapı kazanır". Kontrattaki **dize değerleri** (kapı anahtarları `"ekran:mizan"`, `"001:H5"`; Türkçe UI metinleri; SQL tablo ve kolon adları; `[Trait("Tur","Mobil")]`) değişmez.

| Kontrat | Kod |
|---|---|
| `TelefonKapisi` (`Bagimlilik`, `KapananMaddeler`, `KisiselVeriEkranlari`, `Acik`) | `PhoneGate` (`Dependencies`, `AcceptedItems`, `PersonalDataScreens`, `IsOpen`) + `ItemKeys`, `ShouldRender`, `ShouldBlockBody` |
| `Gorunum` (`Bilinmiyor`, `Telefon`, `Masaustu`) | `Viewport` (`Unknown`, `Phone`, `Desktop`) |
| `GorunumSaglayici.razor`, `gorunum.js`, `GorunumDegisti(bool)` | `ViewportProvider.razor`, `wwwroot/js/viewport.js`, `OnViewportChanged(bool isDesktop)` |
| `NavItem.Sinif`, `Sekme`, `KapiAnahtari`; `EkranSinifi`, `MobilSekme` | `NavItem.ScreenClass`, `Tab`, `GateKey`; `ScreenClass { A, B, C }`, `MobileTab { None, Today, Sales, Finance, Assistant, More }` |
| `MobilSekmePaneli.razor` (`Sekme`, `Kapat`) | `MobileTabPanel.razor` (`Tab`, `Close`) |
| `KisiselVeriMaske` (`Ad`, `Telefon`, `KartNo`) | `PersonalDataMask` (`Name`, `Phone`, `CardNumber`) |
| `OturumKurali` (`MutlakSure`, `BostaSure`, `YenidenDogrulama`, `Degerlendir`) | `SessionRules` (`AbsoluteLifetime`, `IdleTimeout`, `RevalidationInterval`, `Evaluate`) + `LastSeenWriteInterval` |
| `OturumDurumu` (`Gecersiz`, `Iptal`, `MutlakDoldu`, `Bosta`, `Gecerli`) | `SessionState` (`Missing`, `Revoked`, `AbsoluteExpired`, `Idle`, `Valid`) |
| `OturumService` (`AcAsync`, `GetirAsync`, `SonGorulmeYazAsync`, `KapatAsync`, `HepsiniKapatAsync`, `AcikOturumlarAsync`) | `ISessionStore` / `SessionService` (`OpenAsync`, `GetAsync`, `TouchAsync`, `CloseAsync`, `CloseAllAsync`, `ListOpenAsync`) |
| `PanelOturumSatiri`, `OturumOzeti` | `PanelSessionRow`, `SessionSummary` |
| `OturumDogrulayici.cs` | `SessionCookieValidator.cs`, `SessionRevalidatingStateProvider.cs`, `SessionActivityHandler.cs`, `CircuitActivity.cs` |
| `Oturumlar.razor` | `SessionList.razor` |
| `GorevService.GecikenMi`, `Ozet` → (açık, geciken) | `GorevService.IsOverdue`, `GetSummary` → `TaskSummary(int Open, int Overdue)` |
| `GelirTabloQueries.Ozetle` | `GelirTabloQueries.Summarize` → `IncomeSummary` |
| `MuhasebeQueries.KontrolOzeti` | `MuhasebeQueries.SummarizeControls` → `ControlSummary` |
| `KullaniciMesajlari.VeriAlinamadi` (001 T-031) | `UserMessages.DataUnavailable` (T-001; bkz. § Açık nokta N-1) |
| `Bugun.razor`, `BugunKart.razor`, `BugunTon`, `BugunRenk` | `Today.razor`, `TodayCard.razor`, `CardTone { None, Success, Warning, Error }`, `CardTones` |
| Kart bileşenleri (`DunkuCiroKarti` …) | `YesterdaySalesCard`, `ExamReturnRow`, `MonthTargetCard`, `AlertsCard`, `PendingOrdersCard`, `ReceivablesCard`, `TasksCard`, `StaffComplianceCard` |
| `EskiAdres.razor`, `EskiAdresler.Hedef` | `LegacyRedirect.razor`, `LegacyRoutes.Target` |
| `UyariKurallari.Degerlendir` | `AlertRules.Evaluate` → `CheckResult` / `CheckOutcome { Alert, NoAlert, CouldNotRun }` |
| `OkulHizaliKiyas.Bul` | `SchoolAlignedComparison.Find` |
| `BekleyenOzet` | `PendingSummary.From` |
| `AsistanGirisCubugu.razor` | `AssistantInputBar.razor` |
| Test adları (`Bagimlilik_SpecTablosuylaAyni` …) | Her görevde İngilizce ad yazılı; kontrat adı parantez içinde |

### Veritabanı ve veri

- Yeni ERP SQL yok. ERP, POS, e-ticaret ve app-owned `bkm.*` tablolarına **yazma yok** (FR-013, `erp-write-policy.md`). Tek yeni tablo `BkmPanel.dbo.PanelOturum` (panelin kendi deposu, SANAL-FIKRI, dev); yazan yalnız `SessionService`.
- Panel bağlantısı `Db.OpenPanelAsync()`; `null` dönerse panel yapılandırılmamıştır.
- Dalga 2'deki tek SQL değişikliği `VardiyaQueries.GetComplianceAsync` şube süzgeci (T-047); her alt sorgu kendi süzgecini taşır, `python tools/vardiya_kapsam_denetimi.py` çıkış 0.
- Canlı ölçüm: `sqlcli query --profile <erp|panel> --read-only --max-rows 100000 "<SELECT>"`, **depo kökünden** (`C:\dev\pusula`). Yazma komutunun çıktısı yönlendirilmez.

### C#

- `DateTime.Now`/`Today` yeni kodda yok → `TimeProvider` (T-001 kaydı). Saklanan zaman UTC (`GetUtcNow().UtcDateTime`); ekranda yerel saat, `dd.MM.yyyy HH:mm` (`CultureInfo.GetCultureInfo("tr-TR")`).
- Yeni ve dokunulan I/O metotları `CancellationToken ct` alır; Dapper `new CommandDefinition(sql, param, cancellationToken: ct)`.
- Dapper konumsal kaydında **sıra sözleşmedir**; SQL takma adları kayıt parametre sırasıyla aynı. Her NET görevinde `python tools/panel_kolon_denetimi.py` çıkış 0.
- Para `decimal`. Boş `catch` yok. `ex.Message`, istisna türü, SP/sunucu adı ekrana yazılmaz; ekran `UserMessages.DataUnavailable` + `Logger.LogError(ex, "{Ekran} veri yükleme hatası", "<Ekran>")` (AC-0.10).
- Hesap Razor'da yazılmaz (`emitter-ayrimi.md`): kart ve telefon özeti, kaynak ekranla aynı çekirdek metodu aynı parametreyle çağırır (FR-005). Hesap taşıma ile düzen değişikliği aynı commit'e girmez.
- Dokunulan `.razor` dosyası görevden sonra görevden önceki satır sayısından büyük olamaz (plan K8); değişen bölüm alt bileşene çıkar. Yeni bileşen < 300 satır. Kabulde `wc -l` önce/sonra raporda.
- `@code` içinde RenderFragment taşıyan dosyaya code-behind eklenmez; alt bileşen kullanılır.

### Arayüz

- Telefon/masaüstü kırılması tek: `lg` (1024 px). Düzen farkı CSS `lg:` sınıfıyla. İçerik farkı sunucuda: masaüstüne özgü bölüm, vardiya isimli satırları, düzenleme formları ve dışa aktarma yalnız `Viewport == Desktop` iken **çizilir ve verisi yüklenir**; `Unknown` (ön çizim dahil) telefon gibi davranır.
- Çizim kuralı: `PhoneGate.ShouldRender(viewport, key)` = `viewport == Viewport.Desktop || PhoneGate.IsOpen(key)`. CSS ile gizleme kapı yerine geçmez.
- DaisyUI semantik token; ham hex yok (istisna: manifest ve `theme-color`, plan § Karmaşıklık). Lucide `<i data-lucide>` koşullu çizilmez; görünürlük CSS ile değişir. Bütün alt ağacın birlikte kalkması serbesttir.
- Dokunulabilir öğe `button`, `a`, `role="button"` ya da `role="tab"` taşır; telefonda ≥ 44×44 px (`min-h-11 min-w-11`). Giriş alanı telefonda ≥ 16 px.
- Dışa aktarma öğesi `data-disa-aktarma` özniteliği taşır ve yalnız `Desktop`'ta çizilir.
- Gösterge karşılaştırma işareti: `data-gosterge="<ekran>.<ad>"` (AC-0.3).
- UI metni Türkçe, cümle düzeninde, ≤ 15 kelime (`sunum-dili.md`, `yazim-metin`). İptal düğmesi her yerde **Vazgeç**.
- Sabit metinler (görevlerde tırnak içinde verilen) birebir yazılır.

### Test

- Proje `tests/GmDashboard.Tests` (T-001 ile gelir). Klasörler: `Birim/` (saf birim, kaynak taraması), `Kabuk/` (`WebApplicationFactory`), `Mobil/` (Playwright), `Canli/` (BkmPanel entegrasyon). `tests/**` yalnız test rolleri (test-yazar, e2e-test-yazari) yazar; `*.props` dahil.
- Altyapı (`lib/Bkm.TestAltyapi`, İngilizce API): `LiveDb.PanelDb()`, `LiveDb.QueryAsync<T>(DbTarget, string, object?, CancellationToken)`, `LiveDb.ScalarAsync<T>(…)`, `DbTarget.Erp`/`Joker`, `ReadOnlyGate.Check(string)`, `CanonicalQuery.Read(string file, string? block)`, `Tolerance.Amount`/`AmountEqual`, `Population.AtLeast(int, string)`, `FakeClock(DateTimeOffset now)` (`LocalTimeZone` UTC), `SourceFile.Read(string repoRelativePath, string? startDirectory = null)`, `ErrorScreenEnvironment`, `MemoryLoggerProvider`. Test projesinde `ErrorScreenCollection.Name = "ErrorScreen"` koleksiyonu ve `ErrorScreenFactory` vardır.
- Test adı İngilizce `Method_Scenario_Expected`; her testte `[Trait("AC","AC-x.y")]`. Playwright testleri `[Trait("Tur","Mobil")]` ve `[Collection("Mobil")]`. BkmPanel entegrasyonu `[Trait("Tur","Canli")]`. Birim testinde `Tur` yok. Testte `if`/döngü yok (teori + `MemberData`); `Skip` yok; `Thread.Sleep`/`Task.Delay` yok (Playwright `WaitForAsync`/`Expect` beklemesi serbest).
- Ulaşılamayan sunucu, boş nüfus, hazır olmayan sayfa → `Assert.Fail("KOŞAMADI: …")` = **kırmızı**.
- Assert mesajına ve test çıktısına kişi adı, telefon, kart numarası, sicil yazılmaz; yalnız bulundu/bulunmadı ve sayı.
- Playwright çıktısı (ekran görüntüsü, iz) yalnız hata anında ve yalnız `tests/GmDashboard.Tests/Mobil/cikti/` altına; klasör git dışı (T-002).
- Komutlar (depo kökü):
  - Birim + kabuk: `dotnet test tests/GmDashboard.Tests --filter "Tur!=Kanonik&Tur!=Koruma&Tur!=Mobil&Tur!=Canli"`
  - Canlı panel: `dotnet test tests/GmDashboard.Tests --filter "Tur=Canli"`
  - Telefon: önce ayrı süreçte `dotnet run --project dashboard --launch-profile http`, sonra `dotnet test tests/GmDashboard.Tests --filter "Tur=Mobil"` (`PANEL_URL` yoksa `http://localhost:5112`)
  - Derleme: `dotnet build dashboard/GmDashboard.csproj` (0 hata, uyarı sayısı görev öncesinden fazla değil) · `dotnet build tests/GmDashboard.Tests/GmDashboard.Tests.csproj -warnaserror`
  - Kapılar: `python tools/turkce_tanimlayici_denetimi.py <dosyalar>` · `python tools/panel_kolon_denetimi.py` (NET) · `python ../orkestra/dist/orkestra/hooks/sql_denetle.py <dosya>` (SQL)
- `Tur=Mobil` hiçbir commit kapısına bağlanmaz; görev kabulünde ve dalga sonunda koşulur.
- Kırmızı kip geri alma: `git reset --hard` / `git checkout -- .` YASAK; dosya elle geri yazılır ya da `git reset --soft HEAD~1`.

### Commit

- Görev başına kendi dosyaları, `git add <dosyalar>` (asla `-A`). Başlık `<tip>(bkm): <özet> (T-0NN)`, gövdede `Spec: 002 · <AC> · bkm` ve `Co-Authored-By: Claude <noreply@anthropic.com>`. `git status` 15 dosyayı aşmadan bölünür.

### Açık noktalar (denetleyiciye; görev başlamadan çözülmesi gerekenler hazırlık raporunda)

- **N-1 — `KullaniciMesajlari` adı:** 001 T-031/T-084/T-085 `KullaniciMesajlari.VeriAlinamadi` ve `dashboard/Data/Tanimlar/KullaniciMesajlari.cs` adını bekliyor. Bu ad yeni dashboard dosyasında tanımlayıcı kapısını kırar (`Kullanici` kara listede; taban 0). T-001 `UserMessages.DataUnavailable` yazar; 001 T-031/T-084/T-085 metinlerinin bu adla güncellenmesi gerekir.
- **N-2 — 001 test altyapısının kaynak commit'i:** 09.10.2026'da 001 HEAD `58181bf`; bu commit'te `FakeClock.GetUtcNow`, `SourceFile.Read`, `Population.AtLeast`, `Tolerance.*`, `CanonicalQuery.Read` gövdeleri `NotImplementedException` (001 T-023 iskeleti). 002 bunları kullanır ve değiştiremez; T-001 bu yüzden 001 T-023 uygulama commit'i olan bir HEAD'i alır.

## İnceleme odağı

1. **Kapı anahtarında yazım hatası ya da boşluk:** `PhoneGate.IsOpen("ekran:mizan ")` ya da sözlükte olmayan `"ekran:mizann"` — beklenen: `InvalidOperationException`; sessizce `false` (kapalı ekran gibi) dönmez. Test: T-009 `IsOpen_UndefinedKey_Throws` (teori: `"ekran:mizan "`, `"ekran:mizann"`, `""`).
2. **Kişisel veri ekranının alt yolu ve büyük harf:** telefonda `/musteri/123`, `/MUSTERI`, `/trafik?x=1`, `/sadakat#a` doğrudan açılır — beklenen: `ShouldBlockBody` `true`, sayfa bileşeni kurulmaz; `/musteriler` (önek ama başka sözcük) `false`. Test: T-009 `ShouldBlockBody_PersonalDataPaths_BlockOnPhoneWhenGateClosed` (teori).
3. **Maskede uç girdiler:** ad `"  "`, `"İsmail ŞAHİN"`, `"a"`; telefon `"0532-123 45 45"`, `"5321234545"` (10 hane), `"12345"`; kart `"1234"`, `"12345"` — beklenen: `"—"`, `"İ*** Ş***"`, `"a***"`; `"0532 *** ** 45"`, `"5321 *** ** 45"`, `"***"`; `"****"`, `"**** 2345"`. Test: T-016 `Name_Phone_CardNumber_EdgeInputs_MaskedAsContract` (teori).
4. **Oturum süre sınırları:** mutlak bitişe tam eşit an, 1 ms önce; boşta 11:59:59,999 ve tam 12:00 — beklenen: eşitlikte `AbsoluteExpired`/`Idle` (`>=`), 1 ms önce `Valid`; iptal edilmiş ama süresi dolmamış satır `Revoked` (süre kontrolünden önce). Test: T-005 `Evaluate_Boundaries_StateAsContract` (teori).
5. **Kabul sonucu dosyasında kanıt hilesi:** `AcceptedItems`'a `001:H12` eklenmiş; dosyada satır `koşamadı`, ya da `tuttu` ama `Kanıt` boş, `.orkestra/...` ile başlıyor, var olmayan hash `abcdef1` — beklenen: dördü de kırmızı. Test: T-009 `AcceptedItems_EvidenceRules_RejectInvalidRows` (teori, geçici dosya `startDirectory` ile).

## AC kapsama

| AC / FR / SC | Görev(ler) |
|---|---|
| AC-0.1 | T-009, T-010, T-017, T-019, T-034, T-074 |
| AC-0.2 | T-009, T-017, T-074 |
| AC-0.3 | T-034, T-049, T-050, T-052, T-054, T-071 |
| AC-0.4 | T-049, T-050, T-056…T-064, T-071 |
| AC-0.5 | T-017, T-027…T-034, T-037, T-056…T-064, T-071 |
| AC-0.6 | T-017, T-024, T-027…T-034, T-037, T-056…T-064 |
| AC-0.7 | T-017, T-024, T-027…T-034, T-056…T-064 |
| AC-0.8 | T-017, T-024, T-028 |
| AC-0.9 | T-018, T-034, T-041, T-056…T-064, T-071 |
| AC-0.10 | T-001, T-029, T-030, T-031, T-034, T-049…T-054 |
| AC-0.11 | T-017, T-024, T-061, T-067, T-070 |
| AC-1.1, AC-1.2, AC-1.3 | T-026, T-040 |
| AC-1.4 | T-010, T-019 |
| AC-1.5 | T-017, T-019 |
| AC-1.6 | T-019, T-028 |
| AC-1.7 | T-011, T-019 |
| AC-1.8 | T-010, T-019, T-020 |
| AC-1.9 | T-007 |
| AC-1.10 | T-025, T-026 |
| AC-1.11 | T-024 |
| AC-1.12 | T-006, T-008, T-022, T-023 |
| AC-1.13, AC-1.14 | T-005, T-007, T-008 |
| AC-1.15 | T-022, T-023 |
| AC-1.16 | T-006, T-007, T-023 |
| AC-2.1, AC-2.2 | T-031 (düzen), T-074 (açılış) |
| AC-2.1a | T-009, T-019, T-031 |
| AC-2.3 | T-011, T-027 |
| AC-2.4 | T-027 |
| AC-2.5 | T-028, T-040 |
| AC-2.6, AC-2.7 | T-028 |
| AC-3.1 | T-015, T-029 |
| AC-3.2 | T-014, T-030 |
| AC-3.3 | T-064 |
| AC-3.4 | T-009, T-019 |
| AC-3.5 | T-029, T-030 |
| AC-4.1 | T-034, T-049…T-054 |
| AC-4.2 | T-009, T-034 |
| AC-4.3 | T-049 |
| AC-4.4 | T-012, T-042, T-049 |
| AC-4.5 | T-012, T-046, T-049 |
| AC-4.6, AC-4.7 | T-012, T-044, T-050 |
| AC-4.8, AC-4.9 | T-043, T-051 |
| AC-4.10 | T-012, T-045, T-052 |
| AC-4.11 | T-012, T-053 |
| AC-4.12 | T-011, T-012, T-034 |
| AC-4.13 | T-012, T-047, T-054 |
| AC-4.14 | T-009, T-034 |
| AC-4.15 | T-034, T-049…T-054 |
| AC-4.16 | T-013, T-055 |
| AC-4.17 | T-034 |
| AC-5.1 | T-017, T-019 |
| AC-5.2 | T-056 · AC-5.3 T-057 · AC-5.4 T-045, T-058 · AC-5.5 T-059 · AC-5.6 T-032 · AC-5.7 T-060 |
| AC-5.8 | T-056…T-064, T-071 |
| AC-6.1 | T-010, T-019 |
| AC-6.2 | T-017, T-036, T-065…T-068, T-070 |
| AC-6.3, AC-6.3a | T-009, T-062 |
| AC-6.4 | T-061 |
| AC-6.5, AC-6.5a | T-063 |
| AC-6.6, AC-6.7 | T-033, T-069 (AC-6.7 oturum kısmı T-022) |
| AC-7.1 | T-013, T-035, T-055, T-065, T-067, T-068 |
| AC-7.2 | T-013, T-068 |
| AC-7.3 | T-028, T-041, T-065, T-067, T-068, T-071 |
| AC-7.4 | T-010, T-035, T-065, T-067 |
| AC-8.0, AC-8.0a | T-009, T-019, T-021, T-074 |
| AC-8.1…AC-8.6 | T-016, T-065, T-066, T-074 |
| AC-8.7 | T-065, T-066 |
| FR-001 · FR-002 · FR-003 | T-026 · T-019 · T-007, T-034 |
| FR-003a · FR-003b | T-036, T-070 · T-033, T-069 |
| FR-004 · FR-005 | T-009 · T-014, T-015, T-034, T-049…T-054, T-071 |
| FR-006 · FR-007 · FR-008 | T-017, T-024 · T-018, T-056…T-064 · T-012, T-051 |
| FR-009 | T-054, T-063 |
| FR-010 | T-013, T-035, T-055, T-065, T-067, T-068 |
| FR-011 | T-025, T-026 |
| FR-012, FR-013 | T-014, T-015 (taşıma eşitliği), T-047 (yazma yok), her görevin kapısı |
| FR-014 | T-004…T-008, T-022, T-023 |
| FR-015 | T-016, T-021, T-065, T-066 |
| FR-016 | T-024, T-070 |
| SC-001 · SC-001a · SC-002 | T-017, T-037, T-071 · T-036, T-070, T-037, T-071 · T-017, T-037 |
| SC-003 | T-040 |
| SC-004 | T-019 |
| SC-005 | T-071 |
| SC-006 · SC-007 | T-017, T-019 · T-013, T-035, T-071 |
| SC-008 (ÇIKARIM ölçüt) | T-025 (günlük), T-075 |
| SC-009 · SC-009a | T-021, T-063, T-074 · T-019, T-021 |
| SC-010 · SC-011 | T-023 · T-017, T-024 |
| Madde 11 (doküman) | T-038, T-039, T-072, T-073 |

---

# Dalga 1 — ilk telefon sürümü (001'den önce yayınlanır)

### T-001 [NET] ON-1: test altyapısının alınması, TimeProvider kaydı, UserMessages
**Bağımlılık:** plan onayı · **Test seviyesi:** hafif · **AC:** AC-0.10 (metin), K10
**Dış bağımlılık:** 001 görev 023 (ortak test yardımcılarının uygulaması commit'li; bkz. N-2)
**Dosyalar:**
- Al (001 dalındaki kaynak commit'ten birebir): `lib/Bkm.TestAltyapi/**`, `tests/GmDashboard.Tests/**`, `Pusula.sln` (yalnız `Bkm.TestAltyapi` ve `GmDashboard.Tests` proje satırları ve onların yapılandırma satırları), `sorgular/2026-10-panel-veri-duzeltme/**` (kopyalanan testlerin girdisi), `specs/002-mobil-kabuk-ekran/**`, `docs/ADR/007-mobil-duzen-olcumu-playwright.md`
- Değiştir: `dashboard/ServiceRegistration.cs` (`AddBkmVeri` içine tek satır)
- Oluştur: `dashboard/Data/Tanimlar/UserMessages.cs`
- Test: `tests/GmDashboard.Tests/Birim/SharedDefinitionsTests.cs`
**Arayüzler:**
- Tüketir: 001 dalı (`ork/001-panel-veri-duzeltme`)
- Üretir:
  - DI'da `TimeProvider` (`s.AddSingleton(TimeProvider.System);`)
  - `namespace GmDashboard.Data.Tanimlar; public static class UserMessages { public const string DataUnavailable = "Veriler şu anda alınamıyor. Sayfayı birkaç dakika sonra yenileyin; sorun sürerse sistem yöneticisine bildirin."; public const string SaveFailed = "Eşik kaydedilemedi. Değerleri kontrol edip yeniden deneyin; sorun sürerse sistem yöneticisine bildirin."; public const string NoRecordsInPeriod = "Bu dönemde kayıt yok."; public const string NoStockSnapshot = "Bu ay için stok görüntüsü yok."; }`
**Gereksinimler (tam değerlerle):**
- **Kaynak commit:** görev başladığı anda `git rev-parse ork/001-panel-veri-duzeltme` çıktısı. Ön koşul: o commit'te `git grep -n NotImplementedException <hash> -- lib/Bkm.TestAltyapi` **boş** döner (001 T-023 uygulanmış). Boş dönmezse görev `BLOCKED` döner ve çıktıyı rapora yazar. Kaynak hash commit gövdesine ve rapora yazılır.
- Alma yolu: `git checkout <hash> -- lib/Bkm.TestAltyapi tests/GmDashboard.Tests sorgular/2026-10-panel-veri-duzeltme specs/002-mobil-kabuk-ekran docs/ADR/007-mobil-duzen-olcumu-playwright.md`; `Pusula.sln` için `git show <hash>:Pusula.sln` ile iki projenin satırları elle eklenir (master'daki öteki satırlar korunur). Alınan dosyalarda **tek karakter değişmez**; doğrulama: `git diff <hash> -- lib/Bkm.TestAltyapi tests/GmDashboard.Tests` boş.
- `lib/Bkm.TestAltyapi/**` ve `Pusula.sln` dotnet-yazar; `tests/GmDashboard.Tests/**` test-yazar adımıdır (rol yazma sınırı). Alma ayrı commit: `chore(bkm): 001 test altyapısını al — <hash> (T-001)`.
- `ServiceRegistration.cs`: satır `s.AddSingleton(TimeProvider.System);` `AddBkmVeri` gövdesinin ilk satırı olur (001 T-029 ile birebir metin).
- `UserMessages`: dört sabit yukarıdaki sırayla, metinler 001 T-031 sözleşmesiyle birebir (ad farkı N-1).
- Commit gövdesi: `001 dosyası, dar istisna (ServiceRegistration TimeProvider satırı)`.
**Adımlar:**
- [ ] Ön koşul komutu; çıktı rapora.
- [ ] Alma (dotnet-yazar + test-yazar) · `dotnet build tests/GmDashboard.Tests/GmDashboard.Tests.csproj -warnaserror` · birim komutu yeşil (alınan testlerin sayısı rapora; 001'deki sayıyla aynı).
- [ ] Kırmızı testler (test-yazar): `AddBkmVeri_TimeProvider_RegisteredOnceAsSystem` (kaynak: `SourceFile.Read("dashboard/ServiceRegistration.cs")` içinde `AddSingleton(TimeProvider.System)` tam 1 kez; ayrıca `new ServiceCollection().AddBkmVeri()` sağlayıcısından `TimeProvider` = `TimeProvider.System`), `UserMessages_Texts_MatchContract` (teori, dört ad → metin; metinler testte açık yazılı).
- [ ] Uygulama · kapılar: derleme · birim · `turkce_tanimlayici_denetimi.py dashboard/Data/Tanimlar/UserMessages.cs dashboard/ServiceRegistration.cs`.
**Kabul:** alınan testler 001'deki gibi yeşil; iki yeni test yeşil; kaynak hash raporda; `git diff <hash>` alınan klasörlerde boş.

### T-002 [CI] Playwright çıktı klasörünü git dışına alma [P]
**Bağımlılık:** T-001 · **Test seviyesi:** yok (gerekçe: yalnız `.gitignore`; kanıt `git check-ignore` çıktısı) · **AC:** KVKK K6 (plan K6)
**Dosyalar:**
- Değiştir: `.gitignore`
**Arayüzler:**
- Üretir: `tests/GmDashboard.Tests/Mobil/cikti/` git dışı
**Gereksinimler (tam değerlerle):**
- Dosya sonuna yorum `# Spec 002 — Playwright hata çıktısı (KVKK K6): canlı veri taşır, commit edilmez` ve satır `tests/GmDashboard.Tests/Mobil/cikti/`.
- `git check-ignore -v lib/Bkm.TestAltyapi/obj/x tests/GmDashboard.Tests/bin/x` boş dönerse, 001 commit `3f633ae`'nin `.gitignore` satırları (`git show 3f633ae -- .gitignore`) birebir eklenir.
**Adımlar:** [ ] Düzenle · [ ] `git check-ignore -v tests/GmDashboard.Tests/Mobil/cikti/a.png` kuralı gösterir; `git check-ignore -v tests/GmDashboard.Tests/Mobil/MobileCollection.cs` boş döner.
**Kabul:** iki komut çıktısı raporda.

### T-003 [E2E] Playwright altyapısı
**Bağımlılık:** T-001, T-002 · **Test seviyesi:** hafif · **AC:** AC-0.5–0.8 altyapısı, ADR-007
**Dosyalar:**
- Değiştir (ayrı satır ekleme): `tests/GmDashboard.Tests/GmDashboard.Tests.csproj` (`<PackageReference Include="Microsoft.Playwright" />`), `tests/GmDashboard.Tests/Directory.Packages.props` (`<PackageVersion Include="Microsoft.Playwright" Version="…" />`)
- Oluştur: `tests/GmDashboard.Tests/Mobil/MobileBrowserFixture.cs`, `Mobil/MobileCollection.cs`, `Mobil/Viewports.cs`, `Mobil/PageReady.cs`, `Mobil/FailureArtifacts.cs`
- Test: `tests/GmDashboard.Tests/Mobil/InfrastructureTests.cs`
**Arayüzler:**
- Tüketir: `SourceFile` deposu kökü bulma kuralı (`Pusula.sln`)
- Üretir (namespace `GmDashboard.Tests.Mobil`):
  - `public sealed class MobileBrowserFixture : IAsyncLifetime { public string BaseUrl { get; } public IBrowser Browser { get; } public Task<IPage> OpenAsync(BrowserNewContextOptions options, string path); }`
  - `[CollectionDefinition("Mobil", DisableParallelization = true)] public sealed class MobileCollection : ICollectionFixture<MobileBrowserFixture> { public const string Name = "Mobil"; }`
  - `public static class Viewports { public static BrowserNewContextOptions Phone(); public static BrowserNewContextOptions Desktop(); }`
  - `public static class PageReady { public static Task WaitAsync(IPage page, TimeSpan? timeout = null); public static Task ScrollToEndAsync(IPage page); }`
  - `public static class FailureArtifacts { public static string Directory { get; } public static Task CaptureAsync(IPage page, string testName); }`
**Gereksinimler (tam değerlerle):**
- Paket: `dotnet add tests/GmDashboard.Tests package Microsoft.Playwright` (merkezi paket yönetimi sürümü yerel props'a yazar); yazılan sürüm rapora; `dotnet list tests/GmDashboard.Tests package --vulnerable` "güvenlik açığı yok". csproj ve props'ta var olan satırlar değişmez (yalnız ekleme). Tarayıcı indirilmez (`playwright install` koşulmaz).
- Fikstür: `BaseUrl` = `PANEL_URL` ortam değişkeni, yoksa `http://localhost:5112`. `InitializeAsync`: önce `HttpClient` ile `GET {BaseUrl}/healthz` (5 sn); başarısızsa `Assert.Fail("KOŞAMADI: panel sunucusuna ulaşılamadı — " + BaseUrl)`. Sonra `Playwright.CreateAsync()` + `Chromium.LaunchAsync(new() { Channel = "chrome", Headless = true })`; başarısızsa `Assert.Fail("KOŞAMADI: Chrome başlatılamadı — " + <istisna türü>)`.
- `Viewports.Phone()`: `ViewportSize = new() { Width = 375, Height = 812 }`, `DeviceScaleFactor = 3`, `IsMobile = true`, `HasTouch = true`, `Locale = "tr-TR"`. `Desktop()`: 1280×800, `Locale = "tr-TR"`.
- `PageReady.WaitAsync`: (1) görünür `h1`, (2) görünür `.loading` yok, (3) `MutationObserver` ile 750 ms DOM değişmedi — üçü birlikte; varsayılan süre 45 sn; aşılırsa `Assert.Fail("KOŞAMADI: sayfa hazır olmadı — " + page.Url)`. `ScrollToEndAsync`: 400 px adımlarla `window.scrollBy` sonuna kadar, ardından `WaitAsync` yeniden.
- `FailureArtifacts.Directory` = depo kökü + `tests/GmDashboard.Tests/Mobil/cikti/` (kök: `AppContext.BaseDirectory`'den yukarı `Pusula.sln`). Yalnız hata anında ekran görüntüsü yazılır.
**Adımlar:**
- [ ] Paket ekleme · derleme `-warnaserror`.
- [ ] Testler (e2e-test-yazari): `Fixture_ServerUnreachable_FailsCouldNotRun` (fikstür `PANEL_URL=http://127.0.0.1:1` ile ayrı örnek; mesaj `KOŞAMADI` ile başlar — `Tur` yok, tarayıcı açılmaz), `PageReady_NoHeading_FailsCouldNotRun` (`SetContentAsync("<div>x</div>")`, `timeout` 2 sn; `Tur=Mobil`), `Viewports_Phone_Is375TouchMobile` (birim), `PageReady_LoginPage_BecomesReady` (`/login`, `Tur=Mobil`, canlı sunucu).
- [ ] Kırmızı kip: `PageReady` koşulu (2) geçici olarak kaldırılır → `.loading` içeren içerikte erken hazır olduğu bir test (`PageReady_VisibleLoading_NotReady`) kırmızı görülür → geri yazılır.
- [ ] Kapılar: derleme · birim · `Tur=Mobil` (sunucu açık) · `turkce_tanimlayici_denetimi.py tests/GmDashboard.Tests/Mobil`.
**Kabul:** testler yeşil; paket sürümü ve güvenlik çıktısı raporda; kırmızı kip kanıtı.

### T-004 [SQL] `dbo.PanelOturum` kurulum betiği [P]
**Bağımlılık:** T-001 · **Test seviyesi:** hafif · **AC:** FR-014, AC-1.12–1.16 (depo)
**Dosyalar:**
- Oluştur: `sorgular/2026-10-09-panel-oturum-kur.sql`
**Arayüzler:**
- Üretir: `BkmPanel.dbo.PanelOturum (Id uniqueidentifier, KullaniciId int, MutlakBitis datetime2(3), SonGorulme datetime2(3), CihazOzeti nvarchar(60) NULL, IptalNedeni nvarchar(20) NULL, IsValid bit, OlusturmaTarihi datetime2(3), GuncellemeTarihi datetime2(3) NULL)`
**Gereksinimler (tam değerlerle):**
- Başlık: `-- ork:hedef-db BkmPanel (SANAL-FIKRI, dev)` · `-- ork:compat 150` · amaç (spec 002 K12) · geri alma yorum bloğu `-- GERİ ALMA: DROP TABLE dbo.PanelOturum;` (çalışmaz, yorum).
- `IF OBJECT_ID(N'dbo.PanelOturum', N'U') IS NULL CREATE TABLE dbo.PanelOturum (…)` kolonlar `veri-modeli.md` § 6'daki sırayla ve tiplerle; `CONSTRAINT PK_PanelOturum PRIMARY KEY (Id)`; `CONSTRAINT FK_PanelOturum_PanelKullanici FOREIGN KEY (KullaniciId) REFERENCES dbo.PanelKullanici (Id)`; `CONSTRAINT DF_PanelOturum_IsValid DEFAULT (1) FOR IsValid`; `CONSTRAINT DF_PanelOturum_OlusturmaTarihi DEFAULT (SYSUTCDATETIME())`; `CONSTRAINT CK_PanelOturum_IptalNedeni CHECK (IptalNedeni IS NULL OR IptalNedeni IN (N'cikis', N'hepsi', N'bosta', N'mutlak'))`.
- `IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_PanelOturum_KullaniciId_IsValid' AND object_id = OBJECT_ID(N'dbo.PanelOturum')) CREATE INDEX IX_PanelOturum_KullaniciId_IsValid ON dbo.PanelOturum (KullaniciId, IsValid) INCLUDE (MutlakBitis, SonGorulme);`
- Tarih literali yok. DELETE yok.
**Adımlar:**
- [ ] Yaz · `sql_denetle.py` E bulgusu 0.
- [ ] Dev'e iki kez uygula (idempotent): `sqlcli script --profile panel sorgular/2026-10-09-panel-oturum-kur.sql` (depo kökünden; çıktı yönlendirilmez).
- [ ] Doğrulama (salt-okuma): `sqlcli query --profile panel --read-only "SELECT name, type_desc FROM sys.objects WHERE parent_object_id = OBJECT_ID(N'dbo.PanelOturum') OR object_id = OBJECT_ID(N'dbo.PanelOturum')"` → tablo + PK + FK + 2 DF + CK; `sys.indexes` sorgusu indeksi gösterir; `sys.columns` sırası ve tipleri `veri-modeli.md` ile aynı.
- [ ] Kırmızı kip: geçici `INSERT … IptalNedeni = N'yanlis'` tek bir transaction içinde denenir (`BEGIN TRAN … ROLLBACK`) → CHECK hatası görülür.
**Kabul:** iki uygulama hatasız; doğrulama çıktıları raporda; CHECK kırmızısı raporda.

### T-005 [NET] Oturum kuralı ve cihaz özeti (saf)
**Bağımlılık:** T-001 · **Test seviyesi:** tam · **AC:** AC-1.13, AC-1.14, AC-1.15 (cihaz özeti)
**Dosyalar:**
- Oluştur: `dashboard/Models/SessionModels.cs`, `dashboard/Models/SessionRules.cs`, `dashboard/Models/DeviceSummary.cs`
- Test: `tests/GmDashboard.Tests/Birim/SessionRulesTests.cs`, `tests/GmDashboard.Tests/Birim/DeviceSummaryTests.cs`
**Arayüzler:**
- Üretir (namespace `GmDashboard.Models`):
  - `public sealed record PanelSessionRow(Guid Id, int UserId, DateTime AbsoluteExpiryUtc, DateTime LastSeenUtc, string? DeviceSummary, string? RevokeReason, bool IsValid, DateTime CreatedUtc);`
  - `public sealed record SessionSummary(Guid Id, string? DeviceSummary, DateTime LastSeenUtc, DateTime CreatedUtc);`
  - `public enum SessionState { Valid, Missing, Revoked, AbsoluteExpired, Idle }`
  - `public static class SessionCloseReason { public const string Logout = "cikis"; public const string All = "hepsi"; public const string Idle = "bosta"; public const string Absolute = "mutlak"; }`
  - `public static class SessionRules { public static readonly TimeSpan AbsoluteLifetime = TimeSpan.FromDays(7); public static readonly TimeSpan IdleTimeout = TimeSpan.FromHours(12); public static readonly TimeSpan RevalidationInterval = TimeSpan.FromMinutes(1); public static readonly TimeSpan LastSeenWriteInterval = TimeSpan.FromMinutes(1); public const string SessionClaim = "oid"; public static SessionState Evaluate(PanelSessionRow? row, DateTime nowUtc); public static string? CloseReasonFor(SessionState state); }`
  - `public static class DeviceSummary { public static string? FromUserAgent(string? userAgent); }`
**Gereksinimler (tam değerlerle):**
- `Evaluate` sırası: `row is null` → `Missing`; `!row.IsValid` → `Revoked`; `nowUtc >= row.AbsoluteExpiryUtc` → `AbsoluteExpired`; `nowUtc - row.LastSeenUtc >= IdleTimeout` → `Idle`; aksi `Valid`.
- `CloseReasonFor`: `Idle` → `"bosta"`, `AbsoluteExpired` → `"mutlak"`, öteki → `null`.
- `FromUserAgent`: boş/null → `null`. İşletim sistemi (ilk eşleşen): `"Android"` → Android; `"iPhone"`/`"iPad"`/`"iPod"` → iOS; `"Windows"` → Windows; `"Macintosh"`/`"Mac OS X"` → macOS; `"Linux"` → Linux; aksi `"Diğer"`. Tarayıcı (ilk eşleşen): `"Edg/"` → Edge; `"CriOS"`/`"Chrome/"` → Chrome; `"FxiOS"`/`"Firefox/"` → Firefox; `"Safari/"` → Safari; aksi `"Diğer"`. Sonuç `"<OS> · <Tarayıcı>"`, en çok 60 karakter. Ham değer ve IP hiçbir yerde tutulmaz.
**Adımlar:**
- [ ] İskelet (gövdeler `NotImplementedException`) · senaryo matrisi (test-tasarimci) · kırmızı testler (test-yazar):
  - `Evaluate_Boundaries_StateAsContract` (teori; İnceleme odağı 4 + `null` satır + iptal ve süresi dolmuş satır → `Revoked`) — kontrat `OturumKurali_Degerlendir`
  - `CloseReasonFor_EachState_ReasonOrNull` (teori)
  - `FromUserAgent_KnownAgents_ShortSummary` (teori: Android Chrome, iPhone Safari, iPhone CriOS, Windows Edge, Windows Chrome, Mac Safari, Linux Firefox, `"curl/8"` → `"Diğer · Diğer"`, `null` → `null`, 500 karakterlik dize → ≤ 60)
  - `SessionRules_Constants_AsPlan` (7 gün, 12 saat, 1 dk, 1 dk, `"oid"`)
- [ ] Uygulama · kapılar: derleme · birim · `turkce_tanimlayici_denetimi.py` (üç yeni dosya).
- [ ] Kırmızı kip: `IdleTimeout` geçici 12 saat yerine 13 saat → sınır teorisi kırmızı → geri yazılır.
**Kabul:** testler yeşil; kırmızı kip kanıtı.

### T-006 [NET] `SessionService` — BkmPanel oturum deposu
**Bağımlılık:** T-004, T-005 · **Test seviyesi:** tam · **AC:** AC-1.12, AC-1.15, AC-1.16, FR-014
**Dosyalar:**
- Oluştur: `dashboard/Data/ISessionStore.cs`, `dashboard/Data/SessionService.cs`
- Değiştir: `dashboard/ServiceRegistration.cs` (`AddBkmDurum` içine kayıt)
- Test: `tests/GmDashboard.Tests/Canli/SessionServiceTests.cs`
**Arayüzler:**
- Tüketir: `PanelSessionRow`, `SessionSummary`, `SessionRules`, `SessionCloseReason` (T-005); `Db.OpenPanelAsync()`; tablo (T-004)
- Üretir:
  - `public interface ISessionStore { Task<Guid> OpenAsync(int userId, string? deviceSummary, CancellationToken ct); Task<PanelSessionRow?> GetAsync(Guid id, CancellationToken ct); Task TouchAsync(Guid id, DateTime atUtc, CancellationToken ct); Task CloseAsync(Guid id, string reason, CancellationToken ct); Task<int> CloseAllAsync(int userId, CancellationToken ct); Task<IReadOnlyList<SessionSummary>> ListOpenAsync(int userId, CancellationToken ct); }`
  - `public sealed class SessionService(Db db, TimeProvider clock, ILogger<SessionService> logger) : ISessionStore`
  - DI: `s.AddSingleton<ISessionStore, SessionService>();`
**Gereksinimler (tam değerlerle):**
- `OpenPanelAsync()` `null` → `InvalidOperationException("Panel veritabanı yapılandırılmamış.")`. Başka istisna yakalanmaz (çağıran karar verir).
- `OpenAsync`: `Id = Guid.NewGuid()`, `now = clock.GetUtcNow().UtcDateTime`; `INSERT INTO dbo.PanelOturum (Id, KullaniciId, MutlakBitis, SonGorulme, CihazOzeti) VALUES (@id, @userId, @expiry, @now, @device)`; `expiry = now + SessionRules.AbsoluteLifetime`; `deviceSummary` 60 karakterde kesilir.
- `GetAsync`: `SELECT Id, KullaniciId AS UserId, MutlakBitis AS AbsoluteExpiryUtc, SonGorulme AS LastSeenUtc, CihazOzeti AS DeviceSummary, IptalNedeni AS RevokeReason, IsValid, OlusturmaTarihi AS CreatedUtc FROM dbo.PanelOturum WHERE Id = @id`. Dönen `DateTime`'lar `DateTime.SpecifyKind(…, DateTimeKind.Utc)`.
- `TouchAsync`: `UPDATE dbo.PanelOturum SET SonGorulme = @at WHERE Id = @id AND IsValid = 1 AND SonGorulme < @at`.
- `CloseAsync`: `reason` `SessionCloseReason` dört değerinden biri değilse `ArgumentOutOfRangeException`; `UPDATE dbo.PanelOturum SET IsValid = 0, IptalNedeni = @reason, GuncellemeTarihi = SYSUTCDATETIME() WHERE Id = @id AND IsValid = 1`.
- `CloseAllAsync`: aynı `UPDATE` ifadesi, `IptalNedeni = N'hepsi'`, `WHERE KullaniciId = @userId AND IsValid = 1`; etkilenen satır sayısını döner; `LogInformation("Bütün oturumlar kapatıldı: {Adet}", n)`.
- `ListOpenAsync`: `SELECT Id, CihazOzeti AS DeviceSummary, SonGorulme AS LastSeenUtc, OlusturmaTarihi AS CreatedUtc FROM dbo.PanelOturum WHERE KullaniciId = @userId AND IsValid = 1 AND MutlakBitis > @now ORDER BY SonGorulme DESC`.
- DELETE ve MERGE yok. ERP bağlantısı açılmaz.
**Adımlar:**
- [ ] İskelet · senaryo matrisi · kırmızı testler (test-yazar), `[Trait("Tur","Canli")]`, her test `new TransactionScope(TransactionScopeOption.Required, TransactionScopeAsyncFlowOption.Enabled)` içinde, `Complete()` **çağrılmadan** (geri alınır); ilk assert `Transaction.Current!.TransactionInformation.DistributedIdentifier == Guid.Empty` (dağıtık işleme yükselmedi). Test kullanıcısı aynı kapsamda `INSERT dbo.PanelKullanici (KullaniciAdi, Aktif) VALUES (N'zz_test_oturum', 1)` ile kurulur (kolonların NOT NULL olanları için T-004 öncesi `sqlcli --profile panel` ile `sys.columns` okunur ve rapora yazılır):
  - `OpenGetClose_OneSession_RoundTrips` (kontrat `OturumService_AcKapatHepsini_BkmPanel`): aç → oku (`IsValid`, `AbsoluteExpiryUtc = Created + 7 gün` ±1 sn) → `CloseAsync("cikis")` → `Revoked` durumunda satır.
  - `CloseAll_TwoSessions_ClosesBothReturnsTwo`
  - `Close_Logout_OtherSessionStaysOpen` (kontrat `Cikis_YalnizKendiOturumunuKapatir`, AC-1.16)
  - `ListOpen_ClosedSessionNotListed`
  - `Close_UnknownReason_Throws` (birim; bağlantı açılmadan)
  - `Touch_OlderTimestamp_DoesNotMoveBack`
  - Bağlantı yoksa `KOŞAMADI` (panel `.env` yok → `Assert.Fail`).
- [ ] Uygulama · kapılar: derleme · birim · `Tur=Canli` · `panel_kolon_denetimi.py` · `turkce_tanimlayici_denetimi.py`.
- [ ] Koşu sonrası kalıntı ölçümü: `sqlcli query --profile panel --read-only "SELECT COUNT(*) FROM dbo.PanelKullanici WHERE KullaniciAdi LIKE N'zz_test_%'"` → 0.
**Kabul:** testler yeşil; dağıtık işlem kimliği boş; kalıntı 0.

### T-007 [NET] HTTP oturum hattı — giriş, çıkış, çerez doğrulama
**Bağımlılık:** T-006 · **Test seviyesi:** tam · **AC:** AC-1.9, AC-1.13, AC-1.14, AC-1.16, FR-003, FR-014
**Dosyalar:**
- Oluştur: `dashboard/Data/SessionCookieValidator.cs`
- Değiştir: `dashboard/Data/AuthService.cs` (yeni metot), `dashboard/Program.cs` (çerez seçenekleri; `/auth/login`, `/auth/setup`, `/auth/logout`)
- Test: `tests/GmDashboard.Tests/Kabuk/ShellFactory.cs`, `tests/GmDashboard.Tests/Kabuk/SessionHttpTests.cs`, `tests/GmDashboard.Tests/Birim/SessionCookieValidatorTests.cs`
**Arayüzler:**
- Tüketir: `ISessionStore` (T-006), `SessionRules`, `SessionState`, `DeviceSummary.FromUserAgent` (T-005), `TimeProvider`
- Üretir:
  - `public Task<int?> FindActiveUserIdAsync(string userName, CancellationToken ct)` (`AuthService` içinde) — `SELECT Id FROM dbo.PanelKullanici WHERE KullaniciAdi = @ad AND Aktif = 1`
  - `public static class SessionCookieValidator { public static Task ValidateAsync(CookieValidatePrincipalContext context); }`
  - Test: `public sealed class ShellFactory : WebApplicationFactory<Program> { public ShellFactory(ErrorScreenEnvironment env, string environmentName, ISessionStore? sessionStore = null); public MemoryLoggerProvider Logs { get; } public string ProtectCookie(ClaimsPrincipal principal); }`
**Gereksinimler (tam değerlerle):**
- Çerez: `o.ExpireTimeSpan = SessionRules.AbsoluteLifetime; o.SlidingExpiration = false; o.Events.OnValidatePrincipal = SessionCookieValidator.ValidateAsync;` öteki seçenekler değişmez.
- `/auth/login` ve `/auth/setup` başarı dalı: `userId = await auth.FindActiveUserIdAsync(ad, ct)`; `null` → `/login?hata=yanlis`. `oid = await store.OpenAsync(userId, DeviceSummary.FromUserAgent(ctx.Request.Headers.UserAgent), ct)`. Kimlik talepleri `ClaimTypes.Name` + `new Claim(SessionRules.SessionClaim, oid.ToString())`. `SignInAsync(…, new AuthenticationProperties { IsPersistent = true, ExpiresUtc = clock.GetUtcNow() + SessionRules.AbsoluteLifetime })`. `LogInformation("Oturum açıldı: {Kullanici}", ad)`. Yönlendirme `/` (FR-003).
- `/auth/logout`: `oid` talebi `Guid` ise `CloseAsync(oid, SessionCloseReason.Logout, ct)`; sonra `SignOutAsync`; `LogInformation("Oturum kapatıldı: {Kullanici}", ad)`.
- `ValidateAsync`: kimlik doğrulanmamışsa dön. `oid` yoksa/çözülemezse durum `Missing`. Aksi `row = await store.GetAsync(oid)`, `state = SessionRules.Evaluate(row, now)`. `Valid` değilse: `CloseReasonFor(state)` null değilse `CloseAsync(oid, reason)`; `context.RejectPrincipal()`; `await context.HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme)`; `LogInformation("Oturum geçersiz: {Durum}", state)`. `Valid` ise `now - row.LastSeenUtc >= SessionRules.LastSeenWriteInterval` olduğunda `TouchAsync(oid, now)`. Depo istisnası (`OperationCanceledException` dışı): `LogError(ex, "Oturum doğrulanamadı")`, istek reddedilmez (kontrat § 4a).
- Bağımlılıklar `context.HttpContext.RequestServices`'ten alınır (`ISessionStore`, `TimeProvider`, `ILoggerFactory`).
**Adımlar:**
- [ ] İskelet · senaryo matrisi · kırmızı testler (test-yazar):
  - Birim, sahte `ISessionStore` (test içi sınıf) + `FakeClock`: `Validate_RevokedSession_RejectsAndSignsOut`, `Validate_IdleSession_ClosesWithIdleReason`, `Validate_MissingClaim_Rejects`, `Validate_StoreThrows_LogsErrorAndAllows`, `Validate_ValidSessionSeenTwoMinutesAgo_Touches`, `Validate_ValidSessionSeenNow_DoesNotTouch`. Bağlam `new CookieValidatePrincipalContext(httpContext, scheme, options, ticket)` ile kurulur; `httpContext.RequestServices` `AddAuthentication().AddCookie()` + sahteler.
  - `[Collection("ErrorScreen")]` kabuk: `Root_NoSession_Production_RedirectsToLogin` (kontrat `KokIstek_OturumYok_GiriseYonlenirRakamYok`, AC-1.9: `GET /` → 302, `Location` `/login` içerir, gövde boş), `Root_RevokedSessionCookie_Production_RedirectsToLogin` (kontrat `GecersizOturum_HttpIstegi_GiriseYonlenir`: `ShellFactory.ProtectCookie` ile `oid` taşıyan çerez, sahte depo `Revoked` döner → 302 `/login`).
  - `ShellFactory.ProtectCookie`: `Services.GetRequiredService<IOptionsMonitor<CookieAuthenticationOptions>>().Get(CookieAuthenticationDefaults.AuthenticationScheme).TicketDataFormat.Protect(new AuthenticationTicket(principal, scheme))`; çerez adı `bkm_panel`. Fabrika `ConfigureTestServices` ile `ISessionStore`'u verilen sahteyle değiştirir; `ErrorScreenEnvironment.AssertIsolated()` kurucuda.
- [ ] Uygulama · kapılar: derleme · birim + kabuk · `turkce_tanimlayici_denetimi.py` · Program.cs satır sayısı önce/sonra raporda.
- [ ] Kırmızı kip: `ValidateAsync` içinde `RejectPrincipal()` geçici olarak kaldırılır → `Root_RevokedSessionCookie_…` kırmızı → geri yazılır.
**Kabul:** testler yeşil; kırmızı kip kanıtı. Not: Production ortamında `WebApplicationFactory` statik varlık nedeniyle kalkmazsa görev `NEEDS_CONTEXT` döner (elle Production örneği T-037'de).

### T-008 [NET] Açık devre oturum hattı — 1 dakikalık yeniden doğrulama ve etkinlik
**Bağımlılık:** T-007 · **Test seviyesi:** tam · **AC:** AC-1.12, AC-1.13, FR-014
**Dosyalar:**
- Oluştur: `dashboard/Data/CircuitActivity.cs`, `dashboard/Data/SessionActivityHandler.cs`, `dashboard/Data/SessionRevalidatingStateProvider.cs`
- Değiştir: `dashboard/ServiceRegistration.cs` (`AddBkmDurum`)
- Test: `tests/GmDashboard.Tests/Birim/SessionRevalidationTests.cs`
**Arayüzler:**
- Tüketir: `ISessionStore` (T-006), `SessionRules` (T-005), `TimeProvider`
- Üretir:
  - `public sealed class CircuitActivity { public DateTime? LastActivityUtc { get; set; } }` (scoped)
  - `public sealed class SessionActivityHandler(CircuitActivity activity, TimeProvider clock) : CircuitHandler` — `CreateInboundActivityHandler(next)` her olayda `activity.LastActivityUtc = clock.GetUtcNow().UtcDateTime` yazar, sonra `next`
  - `public sealed class SessionRevalidatingStateProvider(ILoggerFactory loggerFactory, IServiceScopeFactory scopeFactory, CircuitActivity activity, TimeProvider clock) : RevalidatingServerAuthenticationStateProvider` — `RevalidationInterval => SessionRules.RevalidationInterval`; `public Task<bool> IsStillValidAsync(ClaimsPrincipal user, CancellationToken ct)`; `ValidateAuthenticationStateAsync` bunu çağırır
  - DI: `s.AddScoped<CircuitActivity>(); s.AddScoped<CircuitHandler, SessionActivityHandler>(); s.AddScoped<AuthenticationStateProvider, SessionRevalidatingStateProvider>();`
**Gereksinimler (tam değerlerle):**
- `IsStillValidAsync`: kimlik doğrulanmamış → `true` (Development anonim önizleme bozulmaz). `oid` yok → `false`. `row = GetAsync`; `activity.LastActivityUtc > row.LastSeenUtc` ise önce `TouchAsync(oid, LastActivityUtc)` ve değerlendirmede bu zaman kullanılır. `Evaluate` `Valid` değilse `CloseReasonFor` ile kapatır, `false` döner. Depo istisnası → `LogError(ex, "Oturum yeniden doğrulanamadı")`, `false` (güvenli taraf).
**Adımlar:**
- [ ] İskelet · senaryo matrisi · kırmızı testler (sahte depo + `FakeClock`): `IsStillValid_Anonymous_True`, `IsStillValid_Revoked_False`, `IsStillValid_StoreThrows_False`, `IsStillValid_ActivityNewerThanLastSeen_TouchesAndValid`, `IsStillValid_IdleTwelveHoursNoActivity_ClosesIdleFalse`, `RevalidationInterval_IsOneMinute`, `ActivityHandler_InboundEvent_RecordsUtcNow`.
- [ ] Uygulama · kapılar: derleme · birim · `turkce_tanimlayici_denetimi.py`.
- [ ] Kırmızı kip: `IsStillValidAsync` geçici `return true` → `IsStillValid_Revoked_False` kırmızı → geri yazılır.
**Kabul:** yedi test yeşil; kırmızı kip kanıtı. Uçtan uca 1 dakika ölçümü T-023'te.

### T-009 [NET] `Viewport` ve `PhoneGate`
**Bağımlılık:** T-001 · **Test seviyesi:** tam · **AC:** AC-0.1, AC-0.2, AC-2.1a, AC-3.4, AC-4.2, AC-4.14, AC-6.3a, AC-8.0, FR-004, SC-006
**Dosyalar:**
- Oluştur: `dashboard/Models/Viewport.cs`, `dashboard/Models/PhoneGate.cs`
- Test: `tests/GmDashboard.Tests/Birim/PhoneGateTests.cs`, `tests/GmDashboard.Tests/Birim/PhoneGateSpecTableTests.cs`, `tests/GmDashboard.Tests/Birim/AcceptanceResultTests.cs`
**Arayüzler:**
- Tüketir: `SourceFile.Read` (lib), `specs/002-mobil-kabuk-ekran/spec.md`, `specs/001-panel-veri-duzeltme/kabul-sonucu.md` (henüz yok)
- Üretir (namespace `GmDashboard.Models`):
  - `public enum Viewport { Unknown, Phone, Desktop }`
  - `public static class PhoneGate { public static readonly IReadOnlySet<string> ItemKeys; public static readonly IReadOnlyDictionary<string, string[]> Dependencies; public static readonly FrozenSet<string> AcceptedItems; public static readonly IReadOnlyDictionary<string, string> PersonalDataScreens; public static bool IsOpen(string key); public static bool ShouldRender(Viewport viewport, string key); public static bool ShouldBlockBody(Viewport viewport, string baseRelativePath); }`
**Gereksinimler (tam değerlerle):**
- `ItemKeys` (22): `001:H1` … `001:H9`, `001:H11` … `001:H14`, `001:H10.1`, `001:H10.3`, `001:D-1`, `001:D-2`, `001:D-3`, `001:D-5`, `001:cari-risk`, `003:nakit`, `ek:splh`. (`001:D-1` kontrat § 2 listesinde yok, § 3 ve spec kullanıyor — eklenir.)
- `Dependencies`: `kontratlar/telefon-kapisi.md` § 3 tablosu birebir (29 anahtar: 19 `ekran:`, 9 `kart:`, 1 `gosterge:`). Bağımlılıksız ekranlar boş dizi.
- `AcceptedItems` = boş küme (`FrozenSet<string>.Empty`).
- `PersonalDataScreens`: `"musteri"` → `"ekran:musteri"`, `"trafik"` → `"ekran:trafik"`, `"sadakat"` → `"ekran:sadakat"`.
- `IsOpen`: anahtar `Dependencies`'te yoksa `InvalidOperationException($"Tanımsız kapı anahtarı: '{key}'")`; aksi bütün maddeler `AcceptedItems`'ta ise `true`.
- `ShouldRender(v, key)` = `v == Viewport.Desktop || IsOpen(key)`.
- `ShouldBlockBody(v, path)`: `v == Desktop` → `false`. Yol `?` ve `#`'ten kesilir, baştaki `/` atılır, küçük harfe çevrilir (`ToLowerInvariant`); ilk segment `PersonalDataScreens` anahtarına **eşitse** (önek değil) ve o kapı kapalıysa `true`.
**Adımlar:**
- [ ] İskelet · senaryo matrisi · kırmızı testler (test-yazar):
  - `Dependencies_ItemsAreKnownKeys` (kontrat `Bagimlilik_AnahtarlarGecerli`)
  - `Dependencies_MatchSpecTables` (kontrat `Bagimlilik_SpecTablosuylaAyni`): `SourceFile.Read("specs/002-mobil-kabuk-ekran/spec.md")`; "001 bağımlılığı" ve H4 "Kart bağımlılığı" tabloları satır satır okunur. Test içinde **açık eşleme**: satır etiketi → anahtar (`"Bugün (Ana sayfa + Sabah)"` → `ekran:bugun-donem`; `"Toplam"` → `ekran:toplam`; `"Mağaza"` → `ekran:magaza`; `"Mağazalar"` → `ekran:magazalar`; `"E-ticaret"` → `ekran:eticaret`; `"Sınav Okulları"` → `ekran:sinav`; `"Tahmin"` → `ekran:tahmin`; `"Envanter"` → `ekran:envanter`; `"Operasyon"` → `ekran:operasyon`; `"Vardiya"` → `ekran:vardiya`; `"Mizan"` → `ekran:mizan`; `"Cari/Risk"` → `ekran:cari-risk`; `"Müşteri (C, maskeli)"` → `ekran:musteri`; `"Trafik (C, maskeli)"` → `ekran:trafik`; `"Sadakat (X → Müşteri, maskeli)"` → `ekran:sadakat`; `"Görevler, Asistan, Muhasebe, Gelir tablosu"` → dört anahtar; kart `1`…`8` → `kart:1`…`kart:8`, `1a` → `kart:1a`). Hücre çözme kuralı: `H<n>` → `001:H<n>`; `D-<n>` → `001:D-<n>`; `H10 (AC-10.1)` → `001:H10.1`; `H10 (AC-10.3)` → `001:H10.3`; `H10 (AC-10.1, AC-10.3)` → ikisi; `001 ek maddesi` → `001:cari-risk`; `spec 003` → `003:nakit`; `kart 1 koşulları` → `kart:1`'in kümesi; `yok` → boş; `+ Temmuz–Ekim` yok sayılır. Spec'te karşılığı olmayan sözlük anahtarı yalnız `gosterge:` önekli olabilir.
  - `Dependencies_EveryABScreenDefined` → T-010'da (NavRegistry gerekir).
  - `PersonalDataScreens_ExpectedItems` (kontrat `Bagimlilik_KisiselVeriEkranlari_BeklenenMadde`): `ekran:trafik` → `{001:H5}`, `ekran:musteri` → `{001:D-1}`, `ekran:sadakat` → `{001:H2, 001:H5}` (testte açık).
  - `IndicatorKeys_ExpectedItems` (kontrat `Bagimlilik_GostergeAnahtarlari_BeklenenMadde`): `gosterge:operasyon-splh` → yalnız `{ek:splh}`; hiçbir `gosterge:` anahtarı `001:` önekli maddeye bağlanmaz.
  - `IsOpen_UndefinedKey_Throws` (İnceleme odağı 1), `IsOpen_AllItemsAccepted_True` / `IsOpen_OneItemMissing_False` (kuralı `IsOpenFor(string key, IReadOnlySet<string> accepted)` iç yardımcısı üzerinden sınamak için `public static bool IsOpenFor(...)` da üretilir; `IsOpen` onu `AcceptedItems` ile çağırır), `IsOpen_NoDependencies_True` (`ekran:gorevler`).
  - `ShouldRender_ViewportByGate_Matrix` (kontrat `CizimKurali_KapaliKapi_TelefondaCizilmez_MasaustundeCizilir`; teori 3 görünüm × açık/kapalı; `Unknown` çizmez).
  - `ShouldBlockBody_PersonalDataPaths_BlockOnPhoneWhenGateClosed` (İnceleme odağı 2; kontrat `KisiselVeriKorumasi_KapaliKapi_TelefondaBodyCizilmez`).
  - `AcceptedItems_AllMarkedHeldInAcceptanceFile` (kontrat `KapananMaddeler_HepsiKabulSonucundaTuttu`): küme boşsa dosya aranmaz ve test geçer; doluysa `specs/001-panel-veri-duzeltme/kabul-sonucu.md` okunur, her anahtar için `| <anahtar> | tuttu | … | <kanıt> |` satırı; kanıtın ilk boşlukla ayrılmış belirteci ya `^[0-9a-f]{7,40}$` ve `git cat-file -e <hash>^{commit}` çıkış 0 (depo kökünde; `git` yoksa `KOŞAMADI`), ya da `.orkestra/` ile başlamayan, depoda var olan dosya yolu.
  - `AcceptedItems_EvidenceRules_RejectInvalidRows` (İnceleme odağı 5): kural ayrı `public static IReadOnlyList<string> AcceptanceViolations(IReadOnlySet<string> accepted, string fileText, Func<string, bool> commitExists, Func<string, bool> pathExists)` saf fonksiyonuyla sınanır (bu yardımcı `PhoneGate` içinde değil, test projesinde `Birim/AcceptanceResultParser.cs` olarak test-yazar yazar).
  - `PersonalDataScreen_GateOpen_RequiresMaskInRazor` (kontrat `KisiselVeriEkrani_KapiAcilmadan_MaskeHazirOlmali`): `IsOpen("ekran:trafik")` → `Trafik.razor`, `ekran:musteri` → `Musteri.razor`, `ekran:sadakat` → `Sadakat.razor` kaynağında `PersonalDataMask.` geçmeli (bugün kapılar kapalı, koşul boş geçer).
- [ ] Uygulama · kapılar: derleme · birim · `turkce_tanimlayici_denetimi.py`.
- [ ] Kırmızı kip (üçü ayrı): (a) `AcceptedItems`'a geçici `001:H12` → `AcceptedItems_AllMarkedHeldInAcceptanceFile` kırmızı; (b) sözlükte `gosterge:operasyon-splh` geçici `{001:cari-risk}` → `IndicatorKeys_ExpectedItems` kırmızı (plan R2 kabul ölçütü); (c) sözlükte `ekran:mizan` geçici `{001:H11}` → `Dependencies_MatchSpecTables` kırmızı. Her biri elle geri yazılır.
**Kabul:** testler yeşil; üç kırmızı kip kanıtı.

### T-010 [NET] `NavRegistry` — sınıf, sekme, kapı alanları
**Bağımlılık:** T-009 · **Test seviyesi:** tam · **AC:** AC-1.4, AC-1.8, AC-6.1, AC-7.4, AC-0.1
**Dosyalar:**
- Değiştir: `dashboard/Models/NavRegistry.cs`
- Test: `tests/GmDashboard.Tests/Birim/NavRegistryTests.cs`
**Arayüzler:**
- Tüketir: `PhoneGate.Dependencies` (T-009)
- Üretir: `public enum ScreenClass { A, B, C }` · `public enum MobileTab { None, Today, Sales, Finance, Assistant, More }` · `public record NavItem(string Href, string Label, string Icon, ScreenClass ScreenClass, MobileTab Tab = MobileTab.None, string? GateKey = null, bool InBottomNav = false, string? BottomLabel = null, bool MatchAll = false, string Section = "ANALİTİK", bool GorevBadge = false)` (`Match`, `BtmLabel` aynı) · `public static IEnumerable<NavItem> ForTab(MobileTab tab)`
**Gereksinimler (tam değerlerle):**
- `InBottomNav`, `BottomLabel`, `BottomNav`, `BtmLabel` bu görevde **kalır** (MainLayout T-019'da bırakır; silme T-020).
- `bellek` öğesi çıkar. `sadakat` ve `bulunurluk` Dalga 2 birleşmesine kadar kalır (masaüstü menüsünde bilgi kaybı olmasın, AC-0.9; T-065/T-067 çıkarır).
- Kök öğenin etiketi `"Bugün"` (Href `""`, `MatchAll`, `Section ""`).
- Sınıf / sekme / kapı (öğe sırası değişmez): `""` A/Today/— · `patron-sorulari` C/More/— · `tahmin` B/Sales/`ekran:tahmin` · `operasyon` B/More/`ekran:operasyon` · `kadro` C/More/— · `vardiya` B/More/`ekran:vardiya` · `magazalar` B/Sales/`ekran:magazalar` · `toplam` B/Sales/`ekran:toplam` · `eticaret` B/Sales/`ekran:eticaret` · `sinav` B/Sales/`ekran:sinav` · `trafik` C/More/`ekran:trafik` · `musteri` C/More/`ekran:musteri` · `sadakat` C/More/`ekran:sadakat` · `hediye-ceki` C/More/— · `satis-analizi` C/More/— · `sezon-aksiyon` C/More/— · `envanter` B/More/`ekran:envanter` · `stok-hareket` C/More/— · `odak-stok` C/More/— · `bulunurluk` C/More/— · `baskisi-yok` C/More/— · `satinalma/analiz` C/More/— · `muhasebe` B/Finance/`ekran:muhasebe` · `mizan` B/Finance/`ekran:mizan` · `gider-mizan` C/More/— · `gelir-tablosu` B/Finance/`ekran:gelir-tablosu` · `cari-risk` A/Finance/`ekran:cari-risk` · `asistan` A/Assistant/`ekran:asistan` · `gorevler` A/Assistant/`ekran:gorevler` · `parametreler` C/More/— · `ayarlar` C/More/—.
- Mağaza (`/magaza/{id}`, B, Sales, `ekran:magaza`) kayıtta değil; panel `LokasyonConfig.Mekan`'dan üretir (T-019).
**Adımlar:**
- [ ] Kırmızı testler: `Items_EveryItemHasClass` (kontrat `NavRegistry_HerOgeninSinifiVar`), `Items_MergedScreensAbsent` (Dalga 1: `bellek`, `v2` yok; kontrat `NavRegistry_XEkranlariYok`), `Items_ABItemsHaveDefinedGateKey` (kontrat `Bagimlilik_HerABEkraniTanimli`: her A/B öğesinin `GateKey`'i `PhoneGate.Dependencies`'te; ayrıca `ekran:magaza` tanımlı), `Items_ClassAndTabTable_AsContract` (teori; yukarıdaki satırlar testte açık), `RootItem_LabelIsToday`, `Sections_Unchanged` (masaüstü grup sırası: YÖNETİM, SATIŞ, MÜŞTERİ, STOK & SATINALMA, FİNANS, ASİSTAN, SİSTEM).
- [ ] Uygulama · kapılar: derleme (MainLayout derlenir) · birim · `turkce_tanimlayici_denetimi.py dashboard/Models/NavRegistry.cs` (taban aşılmaz).
**Kabul:** testler yeşil.

### T-011 [NET] `GorevService` gecikme kuralı ve özet [P]
**Bağımlılık:** T-001 · **Test seviyesi:** tam · **AC:** AC-1.7, AC-2.3, AC-4.12
**Dosyalar:**
- Değiştir: `dashboard/Data/GorevService.cs`
- Test: `tests/GmDashboard.Tests/Birim/TaskSummaryTests.cs`
**Arayüzler:**
- Üretir: `public sealed record TaskSummary(int Open, int Overdue);` · `public static bool IsOverdue(Gorev task, DateOnly today)` · `public TaskSummary GetSummary(DateOnly today)` (`GorevService` içinde; `Listele(acikOnly: true)` üstünden)
**Gereksinimler (tam değerlerle):**
- `IsOverdue`: `task.Durum != "Kapalı"` ve `SonTarih` `"dd.MM.yyyy"` (`CultureInfo.InvariantCulture`) ile çözülür ve `< today`. Çözülemeyen/boş tarih → `false`. Kural `Gorevler.razor:135` ile birebir (taşıma; Razor tarafı T-027).
- `GetSummary`: `Open` = açık liste sayısı, `Overdue` = `IsOverdue` sayısı. Panel kapalıysa `new TaskSummary(0, 0)`.
- Mevcut metotlara dokunulmaz.
**Adımlar:**
- [ ] Kırmızı testler (kontrat `GorevOzet_SonTarihGecmisVeAcik_Geciken`): `IsOverdue_PastDueOpen_True`, `IsOverdue_PastDueClosed_False`, `IsOverdue_NoDueDate_False`, `IsOverdue_DueToday_False`, `IsOverdue_UnparsableDate_False`.
- [ ] Uygulama · kapılar: derleme · birim · `turkce_tanimlayici_denetimi.py dashboard/Data/GorevService.cs` (taban aşılmaz).
**Kabul:** beş test yeşil.

### T-012 [NET] `CardTones` — Bugün renk eşikleri [P]
**Bağımlılık:** T-001 · **Test seviyesi:** tam · **AC:** AC-4.4, AC-4.5, AC-4.6, AC-4.10, AC-4.11, AC-4.12, AC-4.13, AC-2.1, FR-008
**Dosyalar:**
- Oluştur: `dashboard/Models/CardTones.cs`
- Test: `tests/GmDashboard.Tests/Birim/CardTonesTests.cs`
**Arayüzler:**
- Üretir: `public enum CardTone { None, Success, Warning, Error }` · `public static class CardTones { public static CardTone ForChange(decimal? changePercent); public static CardTone ForAttainment(decimal attainmentPercent); public static CardTone ForPendingOrders(int twoToThreeDays, int fourPlusDays); public static CardTone ForExamReturnRate(decimal ratePercent); public static CardTone ForOverdueReceivable(decimal amount); public static CardTone ForOverLimitCount(int count); public static CardTone ForOverdueTasks(int overdue); public static CardTone ForCompliance(int breaches); public static string CssClass(CardTone tone); }`
**Gereksinimler (tam değerlerle):**
- `ForChange`: `null` → None; `≤ −10` → Error; `−10 < x ≤ −5` → Warning; `> −5` → None.
- `ForAttainment`: `≥ 95` → Success; `85 ≤ x < 95` → Warning; `< 85` → Error.
- `ForPendingOrders`: `fourPlus > 0` → Error; aksi `twoToThree > 0` → Warning; aksi None.
- `ForExamReturnRate`: `≥ 3` → Error; aksi None.
- `ForOverdueReceivable`: `> 0` → Error; aksi None. `ForOverLimitCount`: `> 0` → Warning. `ForOverdueTasks`: `> 0` → Error. `ForCompliance`: `> 0` → Warning.
- `CssClass`: None → `""`, Success → `"text-success"`, Warning → `"text-warning"`, Error → `"text-error"`.
**Adımlar:**
- [ ] Kırmızı testler: `ForChange_Boundaries` (−4,99 None · −5 Warning · −9,99 Warning · −10 Error · null None), `ForAttainment_Boundaries` (95 Success · 94,99 Warning · 85 Warning · 84,99 Error), `ForPendingOrders_Buckets`, `ForExamReturnRate_ThreePercentIsError` (2,99 None · 3 Error), `ForOverdueReceivable_Zero_None`, `ForOverLimitCount_Positive_Warning`, `ForOverdueTasks_Zero_None`, `ForCompliance_Positive_Warning`, `CssClass_EachTone`.
- [ ] Uygulama · kapılar.
**Kabul:** testler yeşil.

### T-013 [NET] `LegacyRoutes` — eski adres eşlemesi [P]
**Bağımlılık:** T-001 · **Test seviyesi:** tam · **AC:** AC-7.1, AC-7.2, AC-4.16, FR-010
**Dosyalar:**
- Oluştur: `dashboard/Models/LegacyRoutes.cs`
- Test: `tests/GmDashboard.Tests/Birim/LegacyRoutesTests.cs`
**Arayüzler:**
- Üretir: `public static class LegacyRoutes { public static string Target(string baseRelativePath, int? stkId); }`
**Gereksinimler (tam değerlerle):**
- Yol `?`/`#`'ten kesilir, baştaki `/` atılır, küçük harf. Eşleme: `v2` → `/` · `bellek` → `/asistan?sekme=bellek` · `sabah` → `/#sabah` · `sadakat` → `/musteri?sekme=sadakat` · `bulunurluk` → `/satis-analizi?sekme=bulunurluk` · `satinalma/urun/<n>` → `/satis-analizi/urun/{stkId}?sekme=satinalma` (`stkId` null ise `ArgumentNullException`). Tanımsız yol → `ArgumentOutOfRangeException`.
**Adımlar:**
- [ ] Kırmızı testler: `Target_SixLegacyPaths_MapAsContract` (teori; kontrat `EskiAdresler_Hedef`), `Target_ProductDetail_KeepsStkId` (`satinalma/urun/42`, 42), `Target_UnknownPath_Throws`, `Target_QueryString_Ignored` (`sadakat?x=1`).
- [ ] Uygulama · kapılar.
**Kabul:** testler yeşil.

### T-014 [NET] `GelirTabloQueries.Summarize` [P]
**Bağımlılık:** T-001 · **Test seviyesi:** tam · **AC:** AC-3.2, FR-005, FR-012
**Dosyalar:**
- Değiştir: `dashboard/Data/GelirTabloQueries.cs` (yeni statik metot)
- Oluştur: `dashboard/Models/IncomeSummary.cs`
- Test: `tests/GmDashboard.Tests/Birim/IncomeSummaryTests.cs`
**Arayüzler:**
- Tüketir: `GelirDetay(string Bolum, string Kategori, string HspKod, string HspAd, decimal Tutar)`
- Üretir: `public sealed record IncomeSummary(decimal NetSales, decimal OperatingExpense, decimal OperatingProfit);` · `public static IncomeSummary Summarize(IReadOnlyList<GelirDetay> rows)`
**Gereksinimler (tam değerlerle):**
- `NetSales = Σ Tutar (Bolum == "NETSATIS")`; `OperatingExpense = Σ Tutar (Bolum == "GIDER")` (negatif kalır); `OperatingProfit = NetSales + OperatingExpense`. `GelirTablosu.razor:180-199` ile birebir formül. Razor bu görevde değişmez (taşıma T-030).
**Adımlar:**
- [ ] Kırmızı testler: `Summarize_MixedRows_FormulaAsRazor` (kontrat `GelirTablosu_Ozetle_FaaliyetKari`; NETSATIS 1000, GIDER −300 ve −200, FINANSMAN −50 → 1000, −500, 500), `Summarize_NoRows_Zeros`, `Summarize_OtherSectionsIgnored`.
- [ ] Uygulama · kapılar.
**Kabul:** testler yeşil.

### T-015 [NET] `MuhasebeQueries.SummarizeControls` [P]
**Bağımlılık:** T-001 · **Test seviyesi:** tam · **AC:** AC-3.1, FR-005
**Dosyalar:**
- Değiştir: `dashboard/Data/MuhasebeQueries.cs` (yeni statik metot)
- Oluştur: `dashboard/Models/ControlSummary.cs`
- Test: `tests/GmDashboard.Tests/Birim/ControlSummaryTests.cs`
**Arayüzler:**
- Tüketir: `KontrolOzetRow` (`EvrakAdet`, `ToplamTutar`, `GiderAd`, `Kaynak` …)
- Üretir: `public sealed record ControlSummary(int DocumentCount, decimal TotalAmount, IReadOnlyList<KontrolOzetRow> TopThree);` · `public static ControlSummary SummarizeControls(IReadOnlyList<KontrolOzetRow> rows)`
**Gereksinimler (tam değerlerle):** `DocumentCount = Σ EvrakAdet`; `TotalAmount = Σ ToplamTutar`; `TopThree` = `ToplamTutar`'a göre azalan ilk 3 (eşitlikte `Kaynak`, sonra `GiderKod` artan). Girdi Muhasebe ekranının seçili dönem için `GetOzetAsync` sonucudur.
**Adımlar:**
- [ ] Kırmızı testler: `SummarizeControls_FiveRows_TopThreeByAmount` (kontrat `MuhasebeKontrolOzeti_EnBuyukUc`), `SummarizeControls_Empty_Zeros`, `SummarizeControls_Tie_StableOrder`.
- [ ] Uygulama · kapılar.
**Kabul:** testler yeşil.

### T-016 [NET] `PersonalDataMask` [P]
**Bağımlılık:** T-001 · **Test seviyesi:** tam · **AC:** AC-8.1, AC-8.6, FR-015
**Dosyalar:**
- Oluştur: `dashboard/Models/PersonalDataMask.cs`
- Test: `tests/GmDashboard.Tests/Birim/PersonalDataMaskTests.cs`
**Arayüzler:**
- Üretir: `public static class PersonalDataMask { public static string Name(string? name); public static string Phone(string? phone); public static string CardNumber(string? card); }`
**Gereksinimler (tam değerlerle):**
- `Name`: boş/boşluk/null → `"—"`; boşlukla ayrılan her kelime → ilk harf (`StringInfo` metin öğesi) + `"***"`, tek boşlukla birleşir (`"Ahmet Yılmaz"` → `"A*** Y***"`).
- `Phone`: boş/null → `"—"`; yalnız rakamlar alınır; < 6 rakam → `"***"`; aksi ilk 4 rakam + `" *** ** "` + son 2 rakam (`"05321234545"` → `"0532 *** ** 45"`; `"5321234545"` → `"5321 *** ** 45"`).
- `CardNumber`: boş/null → `"—"`; uzunluk ≤ 4 → `"****"`; aksi `"**** "` + son 4 (`"2025000012341234"` → `"**** 1234"`).
**Adımlar:**
- [ ] Kırmızı testler (kontrat `KisiselVeriMaske_Ad/Telefon/KartNo`): `Name_Phone_CardNumber_ContractExamples` (teori), `Name_Phone_CardNumber_EdgeInputs_MaskedAsContract` (İnceleme odağı 3), `Mask_Output_NeverContainsSourceBeyondAllowedChars` (teori: çıktı, girdinin açık bırakılan kısmı dışında girdi alt dizisi taşımaz; ≥ %10 "olmamalı" testi).
- [ ] Uygulama · kapılar.
**Kabul:** testler yeşil. (Razor hücreleri Dalga 2.)

### T-017 [E2E] Ölçüm takımı ve kırmızı ilk koşu
**Bağımlılık:** T-003, T-009, T-010 · **Test seviyesi:** tam · **AC:** AC-0.1, AC-0.2, AC-0.5–0.8, AC-0.11, AC-1.5, AC-5.1, AC-6.2, SC-001, SC-001a, SC-002, SC-006, SC-011
**Dosyalar:**
- Oluştur: `tests/GmDashboard.Tests/Mobil/ScreenCatalog.cs`, `Mobil/LayoutProbe.cs`, `Mobil/ScreenRulesTests.cs`, `Mobil/GateMenuTests.cs`
- Test: `tests/GmDashboard.Tests/Birim/ClickableSemanticsTests.cs`
**Arayüzler:**
- Tüketir: `NavRegistry.Items`, `ScreenClass`, `MobileTab`, `NavItem.GateKey` (T-010); `PhoneGate.ShouldRender`, `IsOpen` (T-009); `MobileBrowserFixture`, `Viewports`, `PageReady`, `FailureArtifacts` (T-003)
- Üretir: `public sealed record ScreenCase(string Path, ScreenClass Class, string? GateKey, RuleMode Mode);` · `public enum RuleMode { Enforce, Report, OverflowOnly }` · `public static class ScreenCatalog { public static IEnumerable<object[]> All(); }` · `public static class LayoutProbe { public static Task<LayoutReport> MeasureAsync(IPage page, bool overflowOnly); }` · `public sealed record LayoutReport(int ScrollWidth, IReadOnlyList<string> SmallTargets, IReadOnlyList<string> HoverOnlyTitles, IReadOnlyList<string> SmallInputs, IReadOnlyList<string> ExportControls, bool BottomNavCoversLastChild);`
**Gereksinimler (tam değerlerle):**
- Ekran listesi elle yazılmaz: `NavRegistry.Items` + `/magaza/1`, `/magaza/4477`, `/magaza/4478` + `/satis-analizi/urun/{MOBIL_ORNEK_STKID}`, `/yevmiye-fis?fis={MOBIL_ORNEK_FIS}`, `/fatura?fat={MOBIL_ORNEK_FAT}` (ortam değişkeni yoksa o satır `KOŞAMADI`). Kip: A/B ve kapı açık (`GateKey` null ya da `IsOpen`) → `Enforce`; A/B kapı kapalı → `Report` (ihlaller çıktıya yazılır, kırmızı değil); C → `OverflowOnly`. `/musteri`, `/trafik`, `/sadakat` bu teoride ölçülmez (T-021'in işi).
- Ölçüm tanımları `kontratlar/olcum.md` § 5 birebir: `scrollWidth` (`documentElement` ve `body`) ≤ 375; dokunma seçicisi ve satır içi bağlantı istisnası; `[title]` metni `document.body.innerText` içinde; `input, select, textarea` hesaplanmış `font-size` ≥ 16; sayfa sonunda `main` son çocuğunun alt kenarı ≤ `.btm-nav` üst kenarı.
- Dışa aktarma: telefonda `[data-disa-aktarma]`, `a[download]`, `a[href*="excel" i]` öğe sayısı 0. Dalga 2'ye kalan üç bilinen ihlal (`/sezon-aksiyon`, `/satis-analizi`, `/envanter`) bu kuralda `Report` kipindedir; liste testte açık yazılır ve T-061, T-067, T-070 siler (bkz. hazırlık raporu C-3).
- Kapı (`GateMenuTests`, kontrat olcum § 5 Kapı): Satış, Finans, Diğer panelleri açılır; görünen bağlantı kümesi = `NavRegistry.ForTab(tab)` ∩ (`GateKey` null ya da `IsOpen`) — beklenen küme aynı kodu çağırarak kurulur; fark 0. Diğer panelinde "Masaüstünde daha iyi" grubu = `ScreenClass.C` öğeleri; kapısı kapalı C öğesi bağlantısız satırdır (`a[href]` yok).
- Birim (`ClickableSemanticsTests`, kontrat `TiklanabilirOge_ABEkranlarinda_SemantikEtiketli`): A/B ekran `.razor` kaynaklarında (`SourceFile.Read`; dosya listesi `NavRegistry` A/B öğelerinden `Components/Pages/<ad>.razor` eşlemesi testte açık) `@onclick` taşıyan `div|tr|td|span|li` öğesi `role=` taşır. Kapı kapalı ekran dosyaları rapora yazılır, kırmızı değil.
- İhlal satırı: ekran, kural, öğe (etiket adı + ilk 40 karakter metin + boyut); kişisel veri yok.
**Adımlar:**
- [ ] Senaryo matrisi (test-tasarimci) · testler (e2e-test-yazari): `ScreenRules_Phone375_AsMode` (teori, `MemberData = ScreenCatalog.All()`, görüntü adı yolu taşır), `GateMenu_PanelLinks_EqualOpenItems` (teori: Sales, Finance, More), `GateMenu_More_DesktopBetterGroupListsClassC`, `ClickableSemantics_ABScreens_HaveRole`.
- [ ] **Kırmızı ilk koşu** (sunucu açık): sonuç tablosu (ekran × kural, ihlal sayısı) rapora; beklenen: Dalga 1 A/B ekranlarında ve C ekranlarında taşma/dokunma ihlali var; kapı testi bugünkü alt menü yüzünden kırmızı.
- [ ] Kırılabilirlik (`olcum.md` § 6): geçici olarak tek ekrana 400 px'lik öğe, 24 px düğme, metinde olmayan `title`, 12 px `input` eklenir (denetleyici, çalışma dizininde, commit edilmez) → dört kural kırmızı → elle geri alınır. Kapı için `AcceptedItems`'a geçici anahtar → beklenen küme değişir.
- [ ] Süre: tek tam turun süresi rapora (ADR-007 "Bilinmeyen").
**Kabul:** testler derlenir; kırmızı ilk koşu tablosu ve kırılabilirlik kanıtı raporda. Bu testler Dalga 1 sonunda T-037'de yeşil olur.

### T-018 [UI] `ViewportProvider` ve görünüm bildirimi
**Bağımlılık:** T-009, T-003 · **Test seviyesi:** hafif · **AC:** FR-007, FR-009 (altyapı), AC-0.9
**Dosyalar:**
- Oluştur: `dashboard/Components/Layout/ViewportProvider.razor`, `dashboard/wwwroot/js/viewport.js`
- Değiştir: `dashboard/Components/Layout/MainLayout.razor` (gövdeyi sarar), `dashboard/Components/App.razor` (`<script src="js/viewport.js"></script>`, `blazor.web.js`'den önce)
- Test: `tests/GmDashboard.Tests/Mobil/ViewportTests.cs`
**Arayüzler:**
- Tüketir: `Viewport` (T-009)
- Üretir: `<ViewportProvider>` → `<CascadingValue Value="Current" IsFixed="false">`; `[JSInvokable] public Task OnViewportChanged(bool isDesktop)`; JS `window.bkmViewport.watch(dotNetRef)` → `matchMedia('(min-width: 1024px)')`, ilk çağrı ve `change` olayı. Sarmal öğe `<div data-viewport="unknown|phone|desktop">`. Sayfalar `[CascadingParameter] public Viewport Viewport { get; set; }` ile alır.
**Gereksinimler (tam değerlerle):** Ön çizimde ve ilk bildirime kadar `Unknown`. `OnAfterRenderAsync(firstRender)` içinde `DotNetObjectReference` ile `watch`; `IAsyncDisposable` ile bırakılır (`unwatch`). Değişimde `StateHasChanged`.
**Adımlar:**
- [ ] Kırmızı testler (e2e-test-yazari): `Viewport_Phone375_ReportsPhone`, `Viewport_Desktop1280_ReportsDesktop`, `Viewport_ResizeDesktopToPhone_SwitchesToPhone` (`data-viewport` okunur).
- [ ] Uygulama · `npm run build:css` · derleme · `turkce_tanimlayici_denetimi.py`.
**Kabul:** üç test yeşil; `MainLayout.razor` satır artışı ≤ 4.

### T-019 [UI] Alt menü, sekme paneli, rozet, CFO menüsü
**Bağımlılık:** T-018, T-010, T-011, T-017 · **Test seviyesi:** tam · **AC:** AC-1.4–1.8, AC-0.1, AC-2.1a, AC-3.4, AC-5.1, AC-6.1, AC-8.0, SC-004, SC-006, SC-009a
**Dosyalar:**
- Oluştur: `dashboard/Components/Layout/MobileTabPanel.razor`
- Değiştir: `dashboard/Components/Layout/MainLayout.razor`, `dashboard/Styles/app.tailwind.css`, `dashboard/wwwroot/app.css`
- Test: `tests/GmDashboard.Tests/Mobil/BottomNavTests.cs`
**Arayüzler:**
- Tüketir: `NavRegistry.ForTab`, `NavItem.GateKey`, `ScreenClass` (T-010); `PhoneGate.IsOpen` (T-009); `GorevService.GetSummary(DateOnly)` → `TaskSummary` (T-011); `TimeProvider`; `LokasyonConfig.Mekan`
- Üretir: `<MobileTabPanel Tab="MobileTab" Close="EventCallback" />`
**Gereksinimler (tam değerlerle):** kontrat `kabuk.md` § 2–3 birebir:
- Alt menü `btm-nav lg:hidden`; sıra Bugün (`<a href="/">`) · Satış (`<button aria-expanded>`) · Finans (button) · Asistan (`<a href="/asistan">`) · Diğer (button); etiketler "Bugün", "Satış", "Finans", "Asistan", "Diğer"; etkin sekme `text-primary` + `aria-current="page"` (bulunulan sayfanın `Tab`'ı; panel açıkken açan sekme); her sekme `min-h-11 min-w-11`, etiket `text-[11px] font-bold` (`text-[10px]` kalkar); `pb-[env(safe-area-inset-bottom)]`; `main` alt boşluğu `pb-[calc(4rem+env(safe-area-inset-bottom))] lg:pb-0`.
- Rozet Asistan sekmesinde `<span class="badge badge-error badge-sm">` = `GetSummary(bugün).Overdue`; 0 ise çizilmez. Masaüstü kenar çubuğu rozeti bugünkü gibi açık görev sayısını gösterir.
- Klavye kuralı `app.tailwind.css`: `body:has(:is(input,textarea,select):focus) .btm-nav { display: none; }` (yalnız `@media (max-width: 1023px)`).
- Panel: alt menünün üstünde, `max-h-[70vh] overflow-y-auto`, arka plana, bağlantıya dokununca ve `LocationChanged`'da kapanır. Öğe satırı `<a href>` + ikon + etiket, `min-h-11`. Kapı kapalı öğe (A/B) **çizilmez**. Satış: Mağazalar, her `LokasyonConfig.Mekan` mağazası için `/magaza/{id}` ("Mağaza — <ad>", kapı `ekran:magaza`), E-ticaret, Sınav Okulları, TOPLAM Kategori, Hedef Tahmin. Finans: Cari / Risk, Muhasebe / Kontrol, Gelir Tablosu, Mizan / Finans. Diğer: üstte Operasyon, Envanter, Vardiya / Mesai (kapı açık olanlar); başlık **"Masaüstünde daha iyi"**; altında C öğeleri — kapısı açık ya da kapısız C öğesi bağlantı; kapısı kapalı C öğesi (`trafik`, `musteri`, `sadakat`) bağlantısız satır "<etiket> — Masaüstünde açılır"; ayrıca üç bağlantısız sabit satır: "Satış analizi ürün detayı — Satış analizinden açılır", "Yevmiye fişi — Muhasebe ekranından açılır", "Fatura — Muhasebe ekranından açılır".
- Masaüstü üst barındaki CFO menüsü: `@onclick` + `NavigateTo` öğeleri `<a href="…">` olur; "Sabah Brifingi" öğesi kalkar; kullanılmayan hamburger etiketi (`hidden lg:hidden`) kalkar. Kenar çubuğu grupları değişmez (AC-1.8).
- Eski `NavRegistry.BottomNav` döngüsü ve "Diğer" çekmece etiketi kalkar.
**Adımlar:**
- [ ] Senaryo matrisi · kırmızı testler (e2e-test-yazari): `BottomNav_Phone_FiveTabsOrderAndActive` (kontrat `AltMenu_375_BesSekmeSiraVeEtkin`), `BottomNav_Desktop_Hidden` (`AltMenu_1280_Gorunmez`), `BottomNav_Phone_LastRowAboveMenu` (`AltMenu_375_SonSatirMenununUstunde`), `Navigation_TasksInTwoTaps` (`Hedef_BugundenIkiDokunusta`, Görevler: Asistan → Görevler şeridi; şerit T-028'den sonra yeşil), `Badge_NoOverdue_NotRendered` ve `Badge_Overdue_ShowsCount` (`Rozet_GecikenYoksaYok`; geciken görev T-027 sonrası test verisiyle değil, ekrandaki `Overdue` değeriyle karşılaştırılır: `/gorevler` başlığındaki geciken sayısı), `MorePanel_PersonalScreens_NoLinkWhenClosed` (SC-009a), `Desktop_CfoMenu_LinksAreAnchors`.
- [ ] Uygulama · `npm run build:css` · derleme · `turkce_tanimlayici_denetimi.py` · T-017 `GateMenu_*` yeşil.
**Kabul:** testler yeşil (Görevler iki dokunuş testi T-028 bitince); `MainLayout.razor` satır sayısı önce/sonra raporda (artış panel bileşenine çıkar).

### T-020 [NET] `NavRegistry` eski alt menü alanlarının kaldırılması
**Bağımlılık:** T-019 · **Test seviyesi:** hafif · **AC:** AC-1.4 (tek kaynak)
**Dosyalar:**
- Değiştir: `dashboard/Models/NavRegistry.cs`
- Test: `tests/GmDashboard.Tests/Birim/NavRegistryLegacyMembersTests.cs`
**Arayüzler:**
- Üretir: `public record NavItem(string Href, string Label, string Icon, ScreenClass ScreenClass, MobileTab Tab = MobileTab.None, string? GateKey = null, bool MatchAll = false, string Section = "ANALİTİK", bool GorevBadge = false)`; `BottomNav`, `BtmLabel` yok
**Gereksinimler (tam değerlerle):** `InBottomNav`, `BottomLabel`, `BtmLabel`, `BottomNav` silinir; çağıran kalmadığı `grep -rn "InBottomNav\|BottomLabel\|BtmLabel\|BottomNav" dashboard/` ile doğrulanır (boş). Commit tipi `refactor`.
**Adımlar:** [ ] Test: `NavRegistry_Source_NoLegacyBottomNavMembers` (kaynak taraması) · [ ] Uygulama · derleme · birim (T-010 testleri yeşil kalır).
**Kabul:** test yeşil; grep boş; T-010 testleri yeşil.

### T-021 [UI] Kişisel veri ekranı koruması (doğrudan adres)
**Bağımlılık:** T-019, T-009 · **Test seviyesi:** tam · **AC:** AC-8.0, AC-0.1, FR-015, SC-009a, KVKK K4/K11
**Dosyalar:**
- Değiştir: `dashboard/Components/Layout/MainLayout.razor`
- Test: `tests/GmDashboard.Tests/Mobil/PersonalDataGuardTests.cs`
**Arayüzler:**
- Tüketir: `PhoneGate.ShouldBlockBody(Viewport, string)` (T-009); `Viewport` (T-018); `NavigationManager.ToBaseRelativePath`; `LiveDb.QueryAsync` (örnek değer)
**Gereksinimler (tam değerlerle):** `ShouldBlockBody(Viewport, Nav.ToBaseRelativePath(Nav.Uri))` `true` ise `@Body` yerine `<div class="alert" role="status">Bu ekran telefonda henüz kapalı. Masaüstünden açın.</div>` çizilir (spec AC-8.0 metni); sayfa bileşeni kurulmaz. `LocationChanged`'da yeniden değerlendirilir. Masaüstünde değişiklik yok.
**Adımlar:**
- [ ] Senaryo matrisi · kırmızı testler (e2e-test-yazari): `PersonalScreens_Phone_DirectUrl_ShowsNoteNoData` (kontrat `KisiselVeriEkrani_375_KapaliKapi_DogrudanAdresNot`; teori `/musteri`, `/trafik`, `/sadakat`): not var; `page.WebSocket` ile yakalanan bütün çerçeveler (alınan, gönderilen) ve `document.documentElement.innerHTML` taranır — örnek değerler `LiveDb.QueryAsync<string>(DbTarget.Erp, …)` ile aynı gün alınır (Müşteri: `SELECT TOP 1 c.Name FROM DerinCrm.dbo.Customer c WHERE c.Name IS NOT NULL AND LEN(c.Name) > 5`; telefonun son 7 rakamı aynı kayıttan; Trafik: son 7 günde fişi olan bir kasiyerin adı, sorgu `kontratlar/olcum.md` § 5 kapsamında T-021 test-tasarimcisi yazar ve `ReadOnlyGate`'ten geçer); değer çıktıya yazılmaz; örnek bulunamazsa `KOŞAMADI`. `PersonalScreens_Desktop_Unchanged` (sayfa kurulur; not yok).
- [ ] Uygulama · derleme.
- [ ] Kırılabilirlik (`olcum.md` § 5): koruma koşulu geçici `false` → telefon testi kırmızı → elle geri alınır.
**Kabul:** testler yeşil; kırılabilirlik kanıtı.

### T-022 [UI] Oturum arayüzü — devre kapanınca girişe dönüş, Ayarlar → Oturumlar
**Bağımlılık:** T-021, T-008, T-018 · **Test seviyesi:** hafif · **AC:** AC-1.12, AC-1.15, AC-6.7 (oturum)
**Dosyalar:**
- Oluştur: `dashboard/Components/Shared/SessionList.razor`
- Değiştir: `dashboard/Components/Layout/MainLayout.razor` (`AuthenticationStateChanged`), `dashboard/Components/Pages/Ayarlar.razor` (bölüm eklenir: `<SessionList />`, ≤ 3 satır)
- Test: `tests/GmDashboard.Tests/Birim/SessionUiSourceTests.cs`
**Arayüzler:**
- Tüketir: `ISessionStore.ListOpenAsync`, `CloseAllAsync`, `GetAsync` (T-006); `SessionRules.SessionClaim` (T-005); `Viewport` (T-018); `Modal` bileşeni
**Gereksinimler (tam değerlerle):**
- `MainLayout`: `AuthenticationStateProvider.AuthenticationStateChanged` aboneliği; yeni durum kimlik doğrulanmamışsa ve önceki doğrulanmışsa `Nav.NavigateTo("/login", forceLoad: true)`. `IDisposable` ile abonelik bırakılır.
- `SessionList`: başlık **"Oturumlar"**; satır: cihaz özeti (yoksa "Bilinmeyen cihaz") · "Son görülme: dd.MM.yyyy HH:mm" (yerel saat) · bu cihaz için "Bu cihaz" rozeti (`oid` eşleşmesi). IP gösterilmez. **Bütün oturumları kapat** düğmesi ve `Modal` yalnız `Viewport == Desktop`; modal metni "Bütün oturumlar kapatılsın mı? Bu cihaz dahil her yerde yeniden giriş gerekir." düğmeler [**Kapat**] [**Vazgeç**]. Onayda `CloseAllAsync(userId)` (`userId` = `GetAsync(oid).UserId`), sonuç "{n} oturum kapatıldı." ve `Nav.NavigateTo("/login", forceLoad: true)`. Hata → `UserMessages.DataUnavailable` + `LogError`.
**Adımlar:**
- [ ] Testler (kaynak metin): `SessionList_Source_CloseAllOnlyOnDesktop` (düğme `Viewport.Desktop` koşulunun içinde), `SessionList_Source_NoIpAddress` (`RemoteIpAddress`/`IP` geçmez), `MainLayout_Source_NavigatesToLoginOnAnonymous`.
- [ ] Uygulama · `npm run build:css` · derleme · `turkce_tanimlayici_denetimi.py`.
**Kabul:** testler yeşil; uçtan uca ölçüm T-023.

### T-023 [E2E] Oturum uçtan uca
**Bağımlılık:** T-022, T-007 · **Test seviyesi:** tam · **AC:** AC-1.12, AC-1.15, AC-1.16, SC-010
**Dosyalar:**
- Test: `tests/GmDashboard.Tests/Mobil/SessionEndToEndTests.cs`
**Arayüzler:**
- Tüketir: `MobileBrowserFixture`, `Viewports` (T-003); `/auth/login` formu (`kullanici`, `sifre`); `.env`'deki `PANEL_TEST_KULLANICI`, `PANEL_TEST_SIFRE`
**Gereksinimler (tam değerlerle):**
- Hedef **Production yayın örneği** (`olcum.md` § 1): `PANEL_URL_PROD` ortam değişkeni; yoksa `KOŞAMADI`. Kimlik `.env`'den okunur, koda ve çıktıya yazılmaz; yoksa `KOŞAMADI`.
- `CloseAll_PhoneReturnsToLoginWithinOneMinute` (kontrat `HepsiniKapat_TelefonBirDakikadaGiriseDoner`): iki bağlam (telefon 375, masaüstü 1280) aynı kullanıcıyla girer; telefon `/` açık kalır; masaüstü Ayarlar → Oturumlar → **Bütün oturumları kapat** → **Kapat**; telefonda `page.WaitForURLAsync("**/login**", new() { Timeout = 75_000 })`; ölçülen süre rapora; giriş sayfasında rakam yok (`innerText`'te `\d{1,3}(\.\d{3})+` deseni yok).
- `Sessions_Phone_NoCloseButton`, `Sessions_Desktop_ListWithoutIp` (`Oturumlar_375_DugmeYok`, `Oturumlar_1280_ListeIpYok`; IP deseni `\d+\.\d+\.\d+\.\d+` yok).
- `Logout_ClosesOnlyOwnSession`: iki bağlam; biri **Çıkış yap**; öteki `/` yeniden yüklenince açık kalır.
**Adımlar:** [ ] Testler · [ ] Production yayın örneği: `dotnet publish dashboard -c Release -o <scratchpad>/yayin` + `ASPNETCORE_ENVIRONMENT=Production` ile localhost'ta başlatma (tünel yok) · [ ] koşu · [ ] kırılabilirlik: T-008 `RevalidationInterval` geçici 10 dk (çalışma dizini, commit edilmez) → ilk test kırmızı → geri.
**Kabul:** dört test yeşil; ölçülen dönüş süresi ≤ 60 sn raporda; kırılabilirlik kanıtı.

### T-024 [UI] Ortak bileşen dokunma düzeni, dışa aktarma kuralı, bağlantı kopması
**Bağımlılık:** T-019, T-018 · **Test seviyesi:** tam · **AC:** AC-0.6, AC-0.7, AC-0.8, AC-0.11, AC-1.11, FR-006, FR-016, SC-011
**Dosyalar:**
- Değiştir: `dashboard/Components/Shared/AppDataTable.razor`, `AppPeriodPills.razor`, `Sayfalama.razor`, `Modal.razor`, `ExcelButton.razor`, `AppKpiCarousel.razor`, `AppIconRow.razor`, `dashboard/Components/Layout/ReconnectModal.razor`, `dashboard/Styles/app.tailwind.css`, `dashboard/wwwroot/app.css`
- Test: `tests/GmDashboard.Tests/Mobil/SharedComponentsTests.cs`, `tests/GmDashboard.Tests/Birim/ExportButtonSourceTests.cs`
**Arayüzler:**
- Tüketir: `Viewport` (T-018)
- Üretir: `ExcelButton` yalnız `Viewport == Desktop` iken çizilir ve `data-disa-aktarma` taşır (parametreleri değişmez)
**Gereksinimler (tam değerlerle):**
- `AppDataTable` tıklanabilir satır: `role="button" tabindex="0"`, `min-h-11`, Enter/Space ile aynı işlem.
- `AppPeriodPills`, `Sayfalama` düğmeleri, `Modal` kapatma düğmesi, `ReconnectModal` **Tekrar Dene** düğmesi telefonda `min-h-11 min-w-11` (`lg:` altında); `ReconnectModal` telefonda tam genişlik.
- `app.tailwind.css`: `@media (max-width: 1023px) { input, select, textarea { font-size: max(16px, 1em); } }`.
- `title=` taşıyan ortak bileşen bilgisi telefonda görünür metin olur (`<span class="sr-only lg:not-sr-only">` değil; görünür `text-xs` satır) — `AppIconRow`, `AppKpiCarousel` içindeki `title` kullanımları.
**Adımlar:**
- [ ] Kırmızı testler (e2e-test-yazari + test-yazar): `ExportButton_Source_RenderedOnlyOnDesktop` (birim), `Export_Phone_NoExportControl` (kontrat `Excel_375_DisaAktarmaYok`, `/gelir-tablosu` ve `/gider-mizan`), `Export_Desktop_ButtonWorks` (`/gelir-tablosu` 1280'de düğme var), `ReconnectModal_Phone_VisibleAndStays` (kontrat `BaglantiKoptu_UyariGorunurVeDurur`: `page.Context.SetOfflineAsync(true)` sonrası modal görünür ve 10 sn içinde kaybolmaz), `Input_Phone_FontAtLeast16` (`/cari-risk` arama alanı).
- [ ] Uygulama · `npm run build:css` · derleme.
**Kabul:** testler yeşil; T-017 ortak bileşen kaynaklı dokunma ihlalleri raporda azaldı.

### T-025 [NET] HTML `no-store` başlığı ve uygulama açılış günlüğü
**Bağımlılık:** T-007 · **Test seviyesi:** tam · **AC:** FR-011, AC-1.10, SC-008
**Dosyalar:**
- Değiştir: `dashboard/Program.cs`
- Test: `tests/GmDashboard.Tests/Kabuk/HtmlCachingTests.cs`
**Arayüzler:**
- Tüketir: `ShellFactory` (T-007)
**Gereksinimler (tam değerlerle):**
- Ara katman (`UseAuthentication`'dan önce): `ctx.Response.OnStarting` içinde `ContentType` `text/html` ile başlıyorsa `Cache-Control: no-store`. `/manifest.json`, `/service-worker.js`, statik varlık etkilenmez.
- `GET /` ve sorgu `kaynak=uygulama` ise `LogInformation("Uygulama açılışı {Kaynak}", "uygulama")`. Değer başka hiçbir yerde okunmaz.
**Adımlar:**
- [ ] Kırmızı testler (`[Collection("ErrorScreen")]`, Development): `HtmlResponse_CarriesNoStore` (kontrat `HtmlYaniti_NoStoreTasir`; `GET /login` ya da `/`), `Manifest_NoNoStore`, `AppLaunch_SourceQuery_Logged` (`MemoryLoggerProvider` kaydı).
- [ ] Uygulama · kapılar.
**Kabul:** testler yeşil.

### T-026 [UI] PWA varlıkları — manifest, ikonlar, service worker, çevrimdışı sayfa
**Bağımlılık:** T-025, T-018 · **Test seviyesi:** tam · **AC:** AC-1.1, AC-1.2, AC-1.3, AC-1.10, FR-001, FR-011
**Dosyalar:**
- Değiştir: `dashboard/wwwroot/manifest.json`, `dashboard/wwwroot/service-worker.js`, `dashboard/Components/App.razor`
- Oluştur: `dashboard/wwwroot/offline.html`, `dashboard/wwwroot/icon-maskable-512.png`, `dashboard/wwwroot/apple-touch-icon.png`
- Test: `tests/GmDashboard.Tests/Kabuk/ManifestTests.cs`, `tests/GmDashboard.Tests/Mobil/OfflineTests.cs`
**Gereksinimler (tam değerlerle):**
- `manifest.json`: `"id": "/"`, `"name": "BKM Yönetim Paneli"`, `"short_name": "BKM Panel"`, `"start_url": "/?kaynak=uygulama"`, `"scope": "/"`, `"display": "standalone"`, `"orientation": "portrait"`, `"lang": "tr"`, `"background_color": "#f1f5f9"`, `"theme_color": "#4063e6"`, `icons`: `/icon-192.png` 192 `any`, `/icon-512.png` 512 `any`, `/icon-maskable-512.png` 512 `maskable`. `description` kalır.
- `icon-maskable-512.png`: 512×512, zemin `#f1f5f9` dolu; `icon-512.png` 288×288'e ölçeklenip ortalanır (logo, çapı 409,6 px olan güvenli dairenin içinde). `apple-touch-icon.png`: 180×180, zemin `#f1f5f9` dolu (saydamlık yok), `icon-512.png` 144×144 ortalı. Üretim aracı Pillow (`python -I -c "import PIL"` ile doğrulanır; yoksa görev `NEEDS_CONTEXT`); üretim komutu rapora.
- `App.razor` `<head>`: viewport `width=device-width, initial-scale=1, viewport-fit=cover, interactive-widget=resizes-content` (`maximum-scale`/`user-scalable` yok); `<link rel="apple-touch-icon" sizes="180x180" href="/apple-touch-icon.png" />` (eski `icon-192` apple satırı yerine). Öteki satırlar değişmez.
- `service-worker.js` kontrat § 5 birebir: `CACHE = "bkm-kabuk-v1"`; `install`: `addAll(["/offline.html", "/app.css", "/icon-192.png"])` + `skipWaiting`; `activate`: `CACHE` dışındakileri sil + `clients.claim`; `fetch`: yalnız `request.mode === "navigate"` → `respondWith(fetch(request).catch(() => caches.match("/offline.html")))`; öteki isteklerde `respondWith` çağrılmaz.
- `offline.html`: `<html lang="tr">`, `/app.css`; metin "Bağlantı yok. İnternet bağlantınızı kontrol edip yeniden deneyin."; düğme **Yeniden dene** (`onclick="location.reload()"`, `min-h-11`); rakam, mağaza adı, kullanıcı verisi yok.
**Adımlar:**
- [ ] Kırmızı testler: `Manifest_InstallFieldsComplete` (kontrat `Manifest_KurulumAlanlariTam`; alanlar + üç ikon dosyası var + maskable ayrı dosya + PNG boyutları başlıktan okunur), `OfflinePage_NoDigits` (birim, dosya metni), `Offline_AppLaunch_ShowsRetryNoNumbers` (Playwright, `SetOfflineAsync(true)` + `GotoAsync("/?kaynak=uygulama")`; kontrat `Cevrimdisi_UygulamaAcilisi_UyariVeYenidenDene_RakamYok`), `Offline_CacheHoldsShellAssetsOnly` (`caches.keys()` + içerik listesi ⊆ üç varlık; kontrat `Cevrimdisi_OnbellekteYalnizKabukVarliklari`).
- [ ] Uygulama · ikon üretimi · derleme.
- [ ] maskable önizleme: `icon-maskable-512.png` daire maskesiyle kırpılmış önizleme görüntüsü scratchpad'e üretilir, gözlem rapora (dosya commit edilmez).
**Kabul:** testler yeşil.

### T-027 [UI] Görevler telefon düzeni ve silme onayı
**Bağımlılık:** T-011, T-024, T-001 · **Test seviyesi:** tam · **AC:** AC-2.3, AC-2.4, AC-0.5–0.8
**Dosyalar:**
- Değiştir: `dashboard/Components/Pages/Gorevler.razor`
- Test: `tests/GmDashboard.Tests/Mobil/TasksScreenTests.cs`
**Arayüzler:**
- Tüketir: `GorevService.GetSummary`, `IsOverdue` (T-011); `TimeProvider`; `Modal`; `CardTones.ForOverdueTasks` (T-012)
**Gereksinimler (tam değerlerle):** üstte iki gösterge `data-gosterge="gorevler.acik"` ve `"gorevler.geciken"` (geciken > 0 `text-error`); geciken görev `badge badge-error` "Gecikti"; `Gecikti` Razor metodu kalkar, `GorevService.IsOverdue(g, bugün)` çağrılır (bugün `TimeProvider`); **Sil** önce `Modal` açar: "Görev silinsin mi? Bu işlem geri alınamaz." [**Sil**] [**Vazgeç**] — masaüstünde de; düğmeler telefonda ≥ 44 px; girişler 16 px.
**Adımlar:**
- [ ] Kırmızı testler (e2e-test-yazari): `DeleteTask_AsksConfirmation` (kontrat `GorevSil_OnaySorar`; Vazgeç sonrası görev durur — test görevi oluşturmaz, var olan ilk görevde yalnız Vazgeç yolu; görev yoksa `KOŞAMADI`), `TasksHeader_Phone_OpenAndOverdueVisible`, birim `Gorevler_Source_UsesServiceOverdueRule` (`GorevService.IsOverdue` geçer, `DateTime.Today` geçmez).
- [ ] Uygulama · `npm run build:css` · derleme · T-017 `/gorevler` satırı `Enforce` yeşil.
**Kabul:** testler yeşil; `/gorevler` ölçümde yeşil; satır sayısı önce/sonra.

### T-028 [UI] Asistan şeridi, Bellek sekmesi, giriş çubuğu
**Bağımlılık:** T-024, T-019 · **Test seviyesi:** tam · **AC:** AC-2.5, AC-2.6, AC-2.7, AC-1.6, AC-7.3 (Bellek)
**Dosyalar:**
- Oluştur: `dashboard/Components/Shared/Asistan/AssistantInputBar.razor`, `dashboard/Components/Shared/Asistan/AssistantTabStrip.razor`
- Değiştir: `dashboard/Components/Pages/Asistan.razor`, `dashboard/Components/Pages/GeniusBellek.razor` (yalnız başlık/çerçeve için `[Parameter] public bool Embedded { get; set; }`; `@page` kalır — T-035 kaldırır)
- Test: `tests/GmDashboard.Tests/Mobil/AssistantScreenTests.cs`
**Gereksinimler (tam değerlerle):** şerit `role="tablist"`: **Sohbet** (`role="tab"`) · **Görevler** (`<a href="/gorevler">`, geciken rozeti) · **Bellek** (`role="tab"`); `[SupplyParameterFromQuery(Name = "sekme")] string? Sekme`, `"bellek"` → Bellek sekmesi, tanınmayan → Sohbet. Bellek sekmesi `<GeniusBellek Embedded="true" />`. `Asistan.razor:48` `NavigateTo("bellek")` → sekme değiştirme. Giriş çubuğu akış içinde, sayfa sonunda `sticky bottom-0`; giriş 16 px; öneri kartlarında onay/ret düğmeleri ≥ 44 px ve masaüstüyle aynı metodu çağırır. `Asistan.razor` satır sayısı artmaz (giriş çubuğu ve şerit alt bileşene çıkar).
**Adımlar:**
- [ ] Kırmızı testler: `Assistant_Phone_StripWithThreeTabs`, `Assistant_BellekQuery_OpensMemoryTab`, `Assistant_Phone_InputBarVisibleAtEnd` (sayfa sonunda giriş ve gönder düğmesi görünür), `Assistant_Source_NoNavigateToBellek` (birim). Klavye davranışı (AC-2.5) cihazda T-040.
- [ ] Uygulama · `npm run build:css` · derleme · T-017 `/asistan` `Enforce` yeşil.
**Kabul:** testler yeşil; satır sayısı önce/sonra.

### T-029 [UI] Muhasebe telefon özeti ve hata metni
**Bağımlılık:** T-015, T-024, T-001 · **Test seviyesi:** tam · **AC:** AC-3.1, AC-3.5, AC-0.10, FR-007
**Dosyalar:**
- Oluştur: `dashboard/Components/Shared/Muhasebe/ControlSummaryCard.razor`
- Değiştir: `dashboard/Components/Pages/Muhasebe.razor`
- Test: `tests/GmDashboard.Tests/Mobil/AccountingScreenTests.cs`, `tests/GmDashboard.Tests/Birim/ErrorTextSourceTests.cs`, `tests/GmDashboard.Tests/Kabuk/DataSourceDownTests.cs`
**Arayüzler:**
- Tüketir: `MuhasebeQueries.SummarizeControls` → `ControlSummary` (T-015); `UserMessages.DataUnavailable` (T-001); `Viewport`
**Gereksinimler (tam değerlerle):** en üstte `ControlSummaryCard`: bulgu adedi (`data-gosterge="muhasebe.adet"`), toplam tutar (`"muhasebe.tutar"`, `1.234,56 TL` biçimi), en büyük 3 kalem; girdi ekranın seçili dönemi için zaten yüklenen `GetOzetAsync` satırları (yeni sorgu yok). Ayrıntı tablosu ve evrak açma yalnız `Desktop`'ta çizilir ve yüklenir; telefonda "Ayrıntı masaüstünde."; yıl/ay seçimi telefonda tek satır, taşmaz. `Muhasebe.razor:40,171` istisna metni → `UserMessages.DataUnavailable` + `LogError(ex, "{Ekran} veri yükleme hatası", "Muhasebe")`.
**Adımlar:**
- [ ] Kırmızı testler: `ErrorText_Wave1Screens_NoExceptionMessage` (birim; kontrat `HataMetni_Dalga1Ekranlari_ExMessageYok`; teori: CariRisk, Muhasebe, GelirTablosu, Gorevler, Asistan kaynağında `ex.Message`, `GetType().Name` yok — öteki dört ekran kendi görevinde yeşile döner), `Accounting_DataSourceDown_ShowsGenericMessage` (kabuk, `[Collection("ErrorScreen")]`, Development: `GET /muhasebe` gövdesinde `UserMessages.DataUnavailable` var, `127.0.0.1`, `Exception`, `SqlException` yok; kontrat `Ekran_VeriKaynagiYok_GenelMesaj`), `Accounting_Phone_SummaryTopNoDetailTable`, `Accounting_Desktop_DetailTablePresent`, `Accounting_SummaryValue_SameOnPhoneAndDesktop` (`data-gosterge` iki görünümde birebir).
- [ ] Uygulama · `npm run build:css` · derleme · T-017 `/muhasebe` `Enforce` yeşil.
**Kabul:** testler yeşil (birim teoride kendi satırı); satır sayısı önce/sonra.

### T-030 [UI] Gelir tablosu: hesabın çekirdeğe taşınması ve telefon özeti
**Bağımlılık:** T-014, T-024, T-029 · **Test seviyesi:** tam · **AC:** AC-3.2, AC-3.5, AC-0.10, FR-005, FR-012
**Dosyalar:**
- Değiştir: `dashboard/Components/Pages/GelirTablosu.razor`
- Oluştur: `dashboard/Components/Shared/GelirTablosu/IncomeSummaryCard.razor`
- Test: `tests/GmDashboard.Tests/Mobil/IncomeStatementScreenTests.cs`
**Arayüzler:**
- Tüketir: `GelirTabloQueries.Summarize` → `IncomeSummary` (T-014); `MuhasebeQueries.GetDonemlerAsync()` (kapanmış dönemler, en yeni önce); `UserMessages.DataUnavailable`
**Gereksinimler (tam değerlerle):**
- **Commit 1 (`refactor`):** `Hesapla()` içinde `_netSatis`, `_faaliyetGider`, `_faaliyetKar` `GelirTabloQueries.Summarize(_rows)`'tan alınır; başka değişiklik yok. Kanıt: masaüstünde aynı dönem için Net satış, Faaliyet gideri, Faaliyet kârı değerleri commit öncesi ve sonrası birebir (Playwright `IncomeStatement_Desktop_ValuesUnchangedByRefactor`, önce-değerler aynı koşuda commit öncesi derlemeden alınır ve scratchpad'e yazılır).
- **Commit 2 (`feat`):** telefonda üstte `IncomeSummaryCard`: kapanmış son ayın (`GetDonemlerAsync()[0]`) faaliyet kârı (`data-gosterge="gelir-tablosu.faaliyet-kari"`) ve altında "Tahakkuk esaslıdır, nakit akışı değildir."; gelir tablosu satırları yalnız `Desktop`'ta; telefonda "Ayrıntı masaüstünde.". Masaüstünün varsayılan dönemi değişmez. `GelirTablosu.razor:175` istisna metni → `UserMessages.DataUnavailable` + `LogError`.
**Adımlar:**
- [ ] Kırmızı testler: `IncomeStatement_Phone_LastClosedMonthProfitAndNote`, `IncomeStatement_Desktop_RowsPresent`, `IncomeStatement_Desktop_ValuesUnchangedByRefactor`.
- [ ] Uygulama (iki commit) · `npm run build:css` · derleme · T-017 `/gelir-tablosu` `Enforce` yeşil.
**Kabul:** testler yeşil; refactor commit'i önce/sonra değerleri raporda.

### T-031 [UI] Cari/Risk telefon düzeni (kapı kapalı)
**Bağımlılık:** T-024, T-029 · **Test seviyesi:** tam · **AC:** AC-2.2 (düzen), AC-2.1a, AC-0.10, AC-0.11
**Dosyalar:**
- Değiştir: `dashboard/Components/Pages/CariRisk.razor`
- Oluştur: `dashboard/Components/Shared/CariRisk/CariRiskCardList.razor`
- Test: `tests/GmDashboard.Tests/Mobil/CariRiskScreenTests.cs`
**Gereksinimler (tam değerlerle):** gösterge hesabına (`CariRisk.razor:40-56`, ilk 200 satırdan toplama) **dokunulmaz** — 001 T-083/T-084'ün işi. Telefonda liste `CariRiskCardList`: her cari tek kart (ad + net bakiye), dokununca açılan ayrıntıda kod, tip, borç, alacak, vadesi geçen, yaklaşan, limit (`role="button"`). Masaüstü tablosu değişmez. Arama ve kapsam sekmeleri telefonda ≥ 44 px, `input` 16 px. `CariRisk.razor:120` istisna metni → `UserMessages.DataUnavailable` + `LogError`. Gösterge öğeleri `data-gosterge="cari-risk.vadesi-gecen"`, `"cari-risk.limit-asan"`.
**Adımlar:**
- [ ] Kırmızı testler: `CariRisk_Phone_CardListWithDetail` (`Report` kipindeki ekran doğrudan adresle açılır), `CariRisk_Desktop_TableUnchanged`, `CariRisk_PhoneFinancePanel_NoLink` (AC-2.1a).
- [ ] Uygulama · `npm run build:css` · derleme.
**Kabul:** testler yeşil; ölçüm `Report` satırında ihlal 0 raporda. Commit gövdesi: "001 T-084 bu dosyada kart ızgarasına dokunacak; telefon sınıfları korunmalı".

### T-032 [UI] Toplam telefon özeti (kapı kapalı)
**Bağımlılık:** T-024 · **Test seviyesi:** tam · **AC:** AC-5.6, FR-007
**Dosyalar:**
- Değiştir: `dashboard/Components/Pages/Toplam.razor`
- Test: `tests/GmDashboard.Tests/Mobil/TotalScreenTests.cs`
**Gereksinimler (tam değerlerle):** telefonda cirosu en yüksek 5 kategori ve payı (ekranda zaten yüklenen listeden; yeni hesap yok, yalnız sıralı ilk 5) `data-gosterge="toplam.kategori-<sıra>"`; tüm liste yalnız `Desktop`'ta; telefonda "Ayrıntı masaüstünde.".
**Adımlar:** [ ] Kırmızı testler: `Total_Phone_TopFiveAndNote`, `Total_Desktop_FullList` · [ ] Uygulama · derleme.
**Kabul:** testler yeşil; `Report` satırında ihlal 0.

### T-033 [UI] Ayarlar telefonda salt okunur
**Bağımlılık:** T-022, T-024 · **Test seviyesi:** tam · **AC:** AC-6.6, AC-6.7, FR-003b, AC-6.2
**Dosyalar:**
- Değiştir: `dashboard/Components/Pages/Ayarlar.razor`
- Oluştur: `dashboard/Components/Shared/Ayarlar/SettingsReadOnly.razor`
- Test: `tests/GmDashboard.Tests/Mobil/SettingsScreenTests.cs`
**Gereksinimler (tam değerlerle):** `Viewport != Desktop`: kayıtlı değerler düz metin listesi (`SettingsReadOnly`), form alanı, kaydet ve sil düğmesi çizilmez; not "Değişiklik masaüstünden yapılır."; `SessionList` görünür (salt okunur). Masaüstü formu (ay kapanış tarihi girişi) aynen. Sayfa telefonda yana taşmaz.
**Adımlar:** [ ] Kırmızı testler: `Settings_Phone_NoEditNote` (kontrat `Ayarlar_375_DuzenlemeYok_Not`: `input`, "Kaydet", "Sil" yok), `Settings_Desktop_FormPresent` (`Ayarlar_1280_FormVar`) · [ ] Uygulama · derleme.
**Kabul:** testler yeşil; T-017 `/ayarlar` taşma yeşil.

### T-034 [UI] Bugün sayfası (ilk sürüm: kart 7)
**Bağımlılık:** T-012, T-011, T-024, T-018 · **Test seviyesi:** tam · **AC:** AC-4.1, AC-4.2, AC-4.12, AC-4.14, AC-4.15, AC-4.17, AC-0.1, AC-0.9, AC-0.10, FR-003
**Dosyalar:**
- Oluştur: `dashboard/Components/Pages/Today.razor`, `dashboard/Components/Shared/Today/TodayCard.razor`, `dashboard/Components/Shared/Today/TasksCard.razor`
- Değiştir: `dashboard/Components/Pages/Home.razor` (**dar istisna**: yalnız `@page "/"` satırı silinir)
- Test: `tests/GmDashboard.Tests/Mobil/TodayScreenTests.cs`, `tests/GmDashboard.Tests/Birim/HomeNarrowExceptionTests.cs`
**Arayüzler:**
- Tüketir: `PhoneGate.ShouldRender` (T-009); `CardTone`, `CardTones` (T-012); `GorevService.GetSummary` (T-011); `UserMessages.DataUnavailable`; `Viewport`
- Üretir: `<TodayCard Title Target Tone Loading Error Note ChildContent />` (`string Title`, `string Target`, `CardTone Tone`, `bool Loading`, `string? Error`, `RenderFragment? Note`, `RenderFragment ChildContent`) — kartın tamamı `<a href="@Target">`, `min-h-11`; `<TasksCard />`
**Gereksinimler (tam değerlerle):**
- `Today.razor` `@page "/"`: `<h1>Bugün</h1>` + tarih `dd.MM.yyyy dddd` (tr-TR, `TimeProvider`). Üst bölüm kart şeridi (bu görevde yalnız kart 7; şerit telefonda tek sütun, masaüstünde `lg:grid-cols-3`). Alt bölüm: `@if (PhoneGate.ShouldRender(Viewport, "ekran:bugun-donem")) { <Home /> }` — telefonda kapı kapalıyken çizilmez ve sorgusu koşmaz; masaüstünde bugünkü Ana sayfa eksiksiz.
- Kart 7 (`kart:7`, kapısız): "Açık görev" ve "Geciken" sayıları `data-gosterge="bugun.gorev-acik"`, `"bugun.gorev-geciken"`; geciken `CardTones.ForOverdueTasks`; 0 → "0", renksiz; hedef `/gorevler`. Yükleme hatası yalnız bu kartta `UserMessages.DataUnavailable`.
- Kart 6 hiç çizilmez (AC-4.14). Kapısı kapalı kart için boş kutu yok.
- `Home.razor`'dan `@page "/"` silinmesi `Today.razor`'ın eklendiği **aynı commit'te** olur (iki bileşen aynı adresi tutarsa uygulama açılmaz); Home'daki değişiklik tek satır; commit gövdesi `001 dosyası, dar istisna (Home.razor @page)`.
**Adımlar:**
- [ ] Kırmızı testler: `Today_Phone_FirstRelease_OnlyCard7` (kontrat `Bugun_375_IlkSurum_YalnizKart7`; `/` telefonda: tek kart, `Home` bölümü yok), `Today_Phone_NoEmptyBoxes` (`Bugun_375_KapaliKartYok_BosKutuYok`), `Today_Phone_TapCardOpensSource` (`Bugun_375_KartaDokununcaKaynakEkran`), `Today_Card7_SameAsTasksHeader` (`Bugun_KartDegeri_KaynakEkranlaAyni`: `bugun.gorev-acik` = `gorevler.acik`), `Today_Desktop_HomeContentPresent` (AC-0.9: 1280'de Ana sayfanın "Hedefler" başlığı var), `Today_Phone_HomeQueriesNotRun` (R7: telefon açılışında sunucu günlüğünde Ana sayfa sorgu günlüğü yok — `MemoryLoggerProvider` değil, Playwright ağ: `/_blazor` çerçevelerinde "Hedefler" yok), birim `Home_Diff_OnlyPageDirectiveRemoved` (`git diff master -- dashboard/Components/Pages/Home.razor` tek silinen satır `@page "/"`).
- [ ] Uygulama · `npm run build:css` · derleme · T-017 `/` `Enforce` yeşil.
**Kabul:** testler yeşil; Home diff tek satır.

### T-035 [UI] Eski adres yönlendirmesi: `/v2`, `/bellek`
**Bağımlılık:** T-013, T-028, T-034 · **Test seviyesi:** tam · **AC:** AC-7.1, AC-7.4, FR-010, SC-007
**Dosyalar:**
- Oluştur: `dashboard/Components/Pages/LegacyRedirect.razor`
- Değiştir: `dashboard/Components/Pages/HomeV2.razor` (yalnız `@page "/v2"` silinir), `dashboard/Components/Pages/GeniusBellek.razor` (yalnız `@page "/bellek"` silinir)
- Test: `tests/GmDashboard.Tests/Kabuk/LegacyRedirectTests.cs`, `tests/GmDashboard.Tests/Birim/LegacyLinksSourceTests.cs`
**Arayüzler:**
- Tüketir: `LegacyRoutes.Target(string, int?)` (T-013)
**Gereksinimler (tam değerlerle):** `LegacyRedirect.razor`: `@page "/v2"`, `@page "/bellek"`; `[Parameter] public int? StkId { get; set; }`; `OnInitialized` → `Nav.NavigateTo(LegacyRoutes.Target(Nav.ToBaseRelativePath(Nav.Uri), StkId), replace: true)`. İçerik çizmez. Eski `@page` satırları aynı commit'te silinir.
**Adımlar:**
- [ ] Kırmızı testler: `LegacyPath_Get_RedirectsToTarget` (kontrat `EskiAdres_GetIstegi_302VeHedef`; `[Collection("ErrorScreen")]`, Development; teori `/v2` → `/`, `/bellek` → `/asistan?sekme=bellek`; 302 ve `Location`), `LegacyLinks_NoInAppLinkToMergedPaths` (kontrat `EskiAdres_UygulamaIcindeBaglantiYok`; Dalga 1 kapsamı: `"/v2"`, `"v2"`, `"bellek"` dizesi yalnız `LegacyRedirect.razor`, `LegacyRoutes.cs`'te).
- [ ] Uygulama · derleme.
**Kabul:** testler yeşil.

### T-036 [UI] Dalga 1 C ekranlarında yana taşmama
**Bağımlılık:** T-024, T-017 · **Test seviyesi:** hafif · **AC:** AC-6.2, FR-003a, SC-001a, AC-0.11
**Dosyalar:**
- Değiştir: `dashboard/Components/Pages/Kadro.razor`, `PatronSorulari.razor`, `StokHareket.razor`, `GiderMerkeziMizan.razor`, `Yevmiye.razor`, `Fatura.razor`
- Test: — (T-017 `ScreenRules_Phone375_AsMode` bu altı ekranın satırları)
**Gereksinimler (tam değerlerle):** geniş tablo `overflow-x-auto` kabına alınır; ızgara çocuklarına `min-w-0`; sabit genişlik kalkar (ör. Fatura 580 px → `w-full lg:w-[580px]`). Yeniden tasarım yok, 44 px kuralı yok. Masaüstü görünümü değişmez.
**Adımlar:** [ ] Uygulama · `npm run build:css` · derleme · `Tur=Mobil` altı satır yeşil (Yevmiye ve Fatura `MOBIL_ORNEK_FIS`/`MOBIL_ORNEK_FAT` ile).
**Kabul:** altı satır yeşil; her dosyanın satır sayısı önce/sonra.

### T-037 [E2E] Dalga 1 bitiş turu — Development ve Production, R5/R7 ölçümü
**Bağımlılık:** T-019…T-036 · **Test seviyesi:** tam · **AC:** SC-001, SC-001a (Dalga 1 kısmı), SC-002, SC-006, R5, R7
**Dosyalar:**
- Test: `tests/GmDashboard.Tests/Mobil/StartupCostTests.cs`
**Gereksinimler (tam değerlerle):**
- `Tur=Mobil` tam koşu Development'a karşı yeşil. Ardından `dotnet publish dashboard -c Release` çıktısı `ASPNETCORE_ENVIRONMENT=Production` ile localhost'ta (tünel yok) başlatılır; `PANEL_URL` ona yöneltilir; kabuk testleri (manifest, SW, `no-store`, oturumsuz → `/login`, çevrimdışı) ve oturum açılarak taşma/dokunma turu bir kez koşar.
- `TodayPhoneOpen_SqlCallsAndDuration` (R7): telefon görünümünde `/` açılışında süre (ms) ve sunucu günlüğündeki SQL çağrı sayısı (Development günlüğünde `Dapper`/`Db` sorgu satırları — sayım yöntemi rapora); masaüstüne özgü bölüm sorgusu **0**. Değerler rapora; eşik yok (ölçüm).
- Rapor: ekran × kural sonuç tablosu (Enforce/Report/OverflowOnly), Report satırlarındaki ihlaller, tur süresi.
**Adımlar:** [ ] Test · [ ] iki tur · [ ] rapor.
**Kabul:** Development ve Production turu yeşil (Report satırları hariç); R7 ölçümü raporda.

### T-038 [YARDIM] Telefona kurulum ve telefon menüsü yardımı
**Bağımlılık:** T-026, T-022, T-019, T-034 · **Test seviyesi:** yok (gerekçe: yardım belgesi; arayüz adlarının koddan doğrulanması kapı adımı) · **AC:** Madde 11, SC-003 (yönerge), KVKK K3/K10
**Dosyalar:**
- Oluştur: `docs/yardim/telefona-kurulum.md`, `docs/yardim/telefon-menusu.md`
**Gereksinimler (tam değerlerle):**
- Künye: `> Tür: nasıl yapılır · Kaynak commit: <hash> · İzlenen yollar: dashboard/wwwroot/manifest.json, dashboard/Components/Layout/MainLayout.razor, dashboard/Components/Shared/SessionList.razor · Son doğrulama: gg.aa.yyyy`.
- `telefona-kurulum.md`: ön koşul (şirket iç ağı, telefonda ekran kilidi zorunlu); "Android'de paneli ana ekrana ekleme" (LAN `https://<sunucu>:5443`, `/ca.crt` indirip güvenme, **Ana ekrana ekle**); "iPhone'da paneli ana ekrana ekleme" (Safari, CA profili + **Ayarlar → Genel → Hakkında → Sertifika Güven Ayarları** tam güven, **Paylaş → Ana Ekrana Ekle**; iç ağda kurulamazsa "004'e kadar bekliyor" notu); "Telefonunuz kaybolursa" (kontrat `kabuk.md` § 8 dört adım: **Ayarlar** → **Oturumlar** → **Bütün oturumları kapat**; parolayı değiştirin; telefon bulunursa uygulamayı kaldırın; masaüstüne erişim yoksa sistem yöneticisi Data Protection anahtarlarını yeniler); sorun giderme ("Bağlantı yok" sayfası; oturum 12 saat boşta / 7 günde kapanır). Tünel yöntemi yazılmaz (K6).
- `telefon-menusu.md`: beş sekme; "Masaüstünde daha iyi" grubu; kapalı ekranların neden görünmediği (001 düzeltmesi bitince açılır); Müşteri/Trafik notu.
- Arayüz adları kodla birebir (**Bugün**, **Satış**, **Finans**, **Asistan**, **Diğer**, **Bütün oturumları kapat**, **Yeniden dene**). Ekran görüntüsü yok.
**Adımlar:** [ ] Yaz · [ ] `dokuman_denetle.py` hook temiz · [ ] arayüz adları `grep` ile kodda bulunur (komut ve çıktı rapora).
**Kabul:** iki belge, hook temiz, grep kanıtı.

### T-039 [DOC] CHANGELOG, ADR durumları, ADR taslakları, yapılacaklar listesi maddeleri
**Bağımlılık:** T-037 · **Test seviyesi:** yok (gerekçe: belge) · **AC:** Madde 11, plan § ADR adayları, İnsan onayı 4 ve 6
**Dosyalar:**
- Oluştur ya da değiştir: `dashboard/CHANGELOG.md` (yoksa oluşturulur: başlık `# Değişiklik günlüğü — BKM Yönetim Paneli` + `## [Yayımlanmamış]`)
- Değiştir: `docs/ADR/007-mobil-duzen-olcumu-playwright.md` (Durum `Kabul edildi`, Uygulama kutuları işaretli), `TODO.md`
- Oluştur: `docs/ADR/008-telefon-kapisi.md`, `docs/ADR/009-tek-kaynak-ekran-ve-gorunum.md`, `docs/ADR/010-service-worker-veri-saklamaz.md` (üçü `Önerildi`, şablon `docs/ADR/000-template.md`)
**Gereksinimler (tam değerlerle):**
- CHANGELOG `[Yayımlanmamış]` → **Eklendi:** telefona kurulum, beş sekmeli alt menü, Bugün ekranı (görevler kartı), oturum listesi ve "Bütün oturumları kapat", çevrimdışı uyarısı · **Değişti:** Ana sayfa "Bugün" adını aldı; Görev silme onay sorar; Asistan belleği Asistan'ın içinde; telefonda dışa aktarma yok; oturum 12 saat boşta ya da 7 günde kapanır · **Güvenlik:** telefonda Müşteri, Trafik, Sadakat kapalı. Kullanıcı etkisi dilinde; commit listesi yok.
- ADR-008: plan K1 + A1; ADR-009: plan K2 + A2; ADR-010: plan K6 service worker + A4. Her biri Bağlam / Karar / Reddedilenler / Sonuçlar; kaynak plan bölümü bağlantısı.
- `TODO.md` (bkm başlığı; önce `grep -n` ile mükerrer kontrolü): K8 500+ satır C ekranlarının bölünmesi; K7 Asistan maske kuralı (izin listesine geçiş, KVKK S3); K9 Vardiya serbest metin notu ölçümü; dışa aktarma günlüğü (004); Lucide `@latest` sabitleme; service worker önbellek adını `app.css` içerik özetine bağlama.
- ADR numarası 004 kullanılmaz; 005/006 001 T-076'ya ayrılı (yazılmaz).
**Adımlar:** [ ] Yaz · [ ] `dokuman_denetle.py` temiz.
**Kabul:** dosyalar yazılı; hook temiz.

### T-040 [ISLETIM] LAN kurulum denemesi — Android ve iOS (SC-003)
**Bağımlılık:** T-023 (oturum yönetimi bitti), T-026, T-037, T-038 · **Test seviyesi:** yok (gerekçe: cihazda elle kabul; kanıt gözlem kaydı, kod değişmez) · **AC:** AC-1.1, AC-1.2, AC-1.3, AC-2.5, SC-003
**Dosyalar:**
- Oluştur: `.orkestra/calisma/002-mobil-kabuk-ekran/kurulum-denemesi.md` (git dışı)
**Gereksinimler (tam değerlerle):**
- Yalnız şirket iç ağı, HTTPS 5443 + `/ca.crt`; **tünel açılmaz** (K6). Production yayın örneği.
- Adımlar `docs/yardim/telefona-kurulum.md`'den birebir; her cihaz için: ana ekrana ekleme, simgenin kırpılmadan görünmesi (AC-1.3), simgeden adres çubuksuz tam ekran dikey açılış (AC-1.2), Bugün açılışı, Asistan'da klavye açıkken giriş ve gönder düğmesinin görünmesi (AC-2.5), çevrimdışı açılışta "Bağlantı yok" sayfası.
- Ekran görüntüsü yalnız Bugün (kart 7), çevrimdışı sayfa ve giriş sayfasından; commit edilmez.
- iOS'ta CA tam güveni kurulamazsa satır "karar bekliyor (004)" yazılır, "geçti" sayılmaz.
**Adımlar:** [ ] Android · [ ] iOS · [ ] gözlem kaydı + `ork not ölçüm`.
**Kabul:** iki cihazın her adımı için sonuç (geçti / kaldı / karar bekliyor) kayıtta.

---

# Dalga 2 — 001 master'a girdikten sonra

> **Giriş koşulu:** 001 dalı master'a merge edildi (`git log master --oneline -- dashboard/Data/Tanimlar/FisTanimi.cs` dolu). Dalga başlamadan bu bölümdeki "Tüketir" satırları 001'in master'daki **gerçek imzalarıyla** (tanımlayıcı kapısı nedeniyle İngilizce adlara dönmüş olabilir) yeniden doğrulanır; fark varsa `/gorevler 002` Dalga 2 bölümü güncellenir, görevde tahmin edilmez. Kart 5 (T-053) için 001 T-083 `GetCariRiskOzetAsync` master'da olmalıdır.

### T-041 [E2E] Dalga 2 masaüstü taban kaydı (önce)
**Bağımlılık:** Dalga 2 giriş koşulu · **Test seviyesi:** tam · **AC:** AC-0.9, AC-7.3 (önce-değerler)
**Dosyalar:**
- Test: `tests/GmDashboard.Tests/Mobil/DesktopBaselineTests.cs`, `tests/GmDashboard.Tests/Mobil/DesktopBaseline.cs`
**Gereksinimler (tam değerlerle):** 1280 px'te her `NavRegistry` öğesi + `/magaza/1`, `/sadakat`, `/bulunurluk`, `/satinalma/urun/{MOBIL_ORNEK_STKID}`, `/sabah` için: `h1, h2, h3`, `.stat-title`, `thead th` metinleri listesi; birleşecek dört ekran (`/sadakat`, `/bulunurluk`, `/satinalma/urun/…`, `/sabah`) için ayrıca `.stat-title` → `.stat-value` metin eşlemesi. Çıktı `tests/GmDashboard.Tests/Mobil/cikti/dalga2-once.json` (git dışı; canlı değer). `DesktopBaseline.Load()` / `Compare(after)` yardımcıları T-071 için.
**Adımlar:** [ ] Test (`Baseline_Desktop_Record`, `Tur=Mobil`) · [ ] Dalga 2 UI görevlerinden **önce** aynı gün koşu.
**Kabul:** dosya üretildi; ekran sayısı ve süre raporda.

### T-042 [NET] `SchoolAlignedComparison` — kart 1 kıyas günü [P]
**Bağımlılık:** Dalga 2 giriş · **Test seviyesi:** tam · **AC:** AC-4.4
**Dosyalar:** Oluştur `dashboard/Models/SchoolAlignedComparison.cs` · Test `tests/GmDashboard.Tests/Birim/SchoolAlignedComparisonTests.cs`
**Arayüzler:** Tüketir `SezonAksiyonFiltre.OkulAcilis` (`Models/SezonAksiyonModels.cs:178`, `IReadOnlyDictionary<int, DateOnly>`; sınıf adı dosyadan okunur) · Üretir `public static class SchoolAlignedComparison { public static DateOnly? Find(DateOnly yesterday); }`
**Gereksinimler (tam değerlerle):** `yesterday.Month` 7–10 ise: `OkulAcilis` `Y` ve `Y−1` yıllarını içermiyorsa `null`; aksi `yesterday.AddDays(-(OkulAcilis[Y].DayNumber - OkulAcilis[Y-1].DayNumber))`. Öteki aylar `yesterday.AddDays(-364)`.
**Adımlar:** [ ] Kırmızı testler: `Find_September2026_Minus371` (14.09.2026 → 08.09.2025, ikisi Pazartesi), `Find_November_Minus364SameWeekday`, `Find_July_UsesSchoolOpeningDiff`, `Find_YearUndefined_Null` (2027 Ağustos) · [ ] Uygulama · kapılar.
**Kabul:** testler yeşil.

### T-043 [NET] `AlertRules` — kart 3 kontrol kümesi [P]
**Bağımlılık:** Dalga 2 giriş · **Test seviyesi:** tam · **AC:** AC-4.8, AC-4.9, FR-008
**Dosyalar:** Oluştur `dashboard/Data/AlertRules.cs` · Test `tests/GmDashboard.Tests/Birim/AlertRulesTests.cs`
**Arayüzler:**
- Tüketir: `PeriodSummary` (`Stores[*].Wow`, `Stores[*].Ad`, `Stores[*].Net`, `Fiziksel`, `Iade`)
- Üretir: `public enum CheckOutcome { Alert, NoAlert, CouldNotRun }` · `public sealed record CheckResult(string Name, CheckOutcome Outcome, string? Title, string? Detail, string Tone);` · `public static class AlertRules { public const string StoreDropName = "Mağaza cirosu düşüşü"; public const string ReturnRateName = "İade oranı"; public static IReadOnlyList<CheckResult> Evaluate(PeriodSummary? data); public static (DateOnly Start, DateOnly EndExcl, DateOnly PrevStart, DateOnly PrevEnd) YesterdayWindow(DateOnly today); }`
**Gereksinimler (tam değerlerle):** `data is null` → iki kontrol de `CouldNotRun`. Kontrol 1: `Wow ≤ −10` olan her mağaza `Alert` (tone `"error"`, başlık `"<Ad> ciro %<Wow>"`), yoksa `NoAlert`. Kontrol 2: `Fiziksel > 0` ise oran `Math.Round(100 * Iade / Fiziksel, 1)`; `> 2` → `Alert` (tone `"warning"`), aksi `NoAlert`; `Fiziksel == 0` → `NoAlert`. Metin biçimleri `Home.razor:398-410` ile birebir. `YesterdayWindow`: `Home.razor`'ın `_period == "gun"` dalının `GetPeriodAsync`'e verdiği dört tarihle birebir (Home'dan okunur, testte açık değerle).
**Adımlar:** [ ] Kırmızı testler: `Evaluate_NullData_BothCouldNotRun` (kontrat `UyariKurallari_KaynakHata_KosamadiSayilmazYesilDegil`), `Evaluate_StoreDropTen_Alert`, `Evaluate_ReturnRateAboveTwo_Alert`, `Evaluate_AllQuiet_TwoNoAlert`, `YesterdayWindow_KnownDate_AsHome` · [ ] Uygulama · kapılar.
**Kabul:** testler yeşil.

### T-044 [NET] `TargetSummary` — kart 2 ay toplamı [P]
**Bağımlılık:** Dalga 2 giriş · **Test seviyesi:** tam · **AC:** AC-4.6, FR-005
**Dosyalar:** Oluştur `dashboard/Models/TargetSummary.cs` · Test `tests/GmDashboard.Tests/Birim/TargetSummaryTests.cs`
**Arayüzler:** Tüketir `HedefMagaza` (`Net`, `Hedef`) · Üretir `public sealed record TargetTotals(decimal Actual, decimal Target, decimal? AttainmentPercent);` · `public static class TargetSummary { public static TargetTotals From(IReadOnlyList<HedefMagaza> stores); }`
**Gereksinimler (tam değerlerle):** `Actual = Σ Net`, `Target = Σ Hedef`, `AttainmentPercent = Target > 0 ? Math.Round(100 * Actual / Target, 1) : null` — `Home.razor:107` toplamıyla birebir.
**Adımlar:** [ ] Kırmızı testler: `From_ThreeStores_SumsAndPercent`, `From_ZeroTarget_NullPercent` · [ ] Uygulama.
**Kabul:** testler yeşil.

### T-045 [NET] `PendingSummary` — kart 4 ve E-ticaret [P]
**Bağımlılık:** Dalga 2 giriş · **Test seviyesi:** tam · **AC:** AC-4.10, AC-5.4
**Dosyalar:** Oluştur `dashboard/Models/PendingSummary.cs` · Test `tests/GmDashboard.Tests/Birim/PendingSummaryTests.cs`
**Arayüzler:** Tüketir `BekleyenBucket(string Bucket, int Adet)` (kovalar `"0-1g"`, `"2-3g"`, `"4-7g"`, `"8+g"`) · Üretir `public sealed record PendingTotals(int Total, int TwoToThreeDays, int FourPlusDays);` · `public static class PendingSummary { public static PendingTotals From(IReadOnlyList<BekleyenBucket> buckets); }`
**Gereksinimler (tam değerlerle):** `Total` = dört kova; `TwoToThreeDays` = `"2-3g"`; `FourPlusDays` = `"4-7g"` + `"8+g"`. Tanınmayan kova adı → `ArgumentException`.
**Adımlar:** [ ] Kırmızı testler: `From_FourBuckets_Totals` (kontrat `BekleyenOzet_Kovalar`), `From_UnknownBucket_Throws`, `From_AllZero_Zeros` · [ ] Uygulama.
**Kabul:** testler yeşil.

### T-046 [NET] `SinavPeriod.DefaultId` — kart 1a ve Sınav ekranının ortak dönemi [P]
**Bağımlılık:** Dalga 2 giriş · **Test seviyesi:** tam · **AC:** AC-4.5, FR-005
**Dosyalar:** Oluştur `dashboard/Models/SinavPeriod.cs` · Test `tests/GmDashboard.Tests/Birim/SinavPeriodTests.cs`
**Arayüzler:** Tüketir `SinavDonem` (`DonemId`, `FisVar`) · Üretir `public static class SinavPeriod { public static int? DefaultId(IReadOnlyList<SinavDonem> periods); public static bool ReturnRowVisible(DateOnly today); }`
**Gereksinimler (tam değerlerle):** `DefaultId` = ilk `FisVar` olanın `DonemId`'i, yoksa ilk elemanın, liste boşsa `null` (`Sinav.razor:321` ile birebir). `ReturnRowVisible`: ay 7, 8, 9, 10 → `true`.
**Adımlar:** [ ] Kırmızı testler: `DefaultId_FirstWithReceipts`, `DefaultId_NoneWithReceipts_First`, `DefaultId_Empty_Null`, `ReturnRowVisible_JulyToOctober` (teori; kontrat `SinavIadeSatiri_Temmuz_Ekim_Gorunur_Kasim_Gorunmez`) · [ ] Uygulama.
**Kabul:** testler yeşil.

### T-047 [NET] `VardiyaQueries.GetComplianceAsync` şube parametresi [P]
**Bağımlılık:** Dalga 2 giriş · **Test seviyesi:** tam · **AC:** AC-4.13, FR-009
**Dosyalar:** Değiştir `lib/Bkm.Shared/Data/VardiyaQueries.cs` · Test `tests/GmDashboard.Tests/Canli/ComplianceBranchTests.cs`
**Arayüzler:** Üretir `public async Task<VrdCompliance?> GetComplianceAsync(string userId, DateOnly bas, DateOnly bit, string? branch = null)`; şube listesi `GetBranchBreakdownAsync(userId, bas, bit)` → `VrdBranch`
**Gereksinimler (tam değerlerle):** `branch == null` sonucu bugünküyle birebir. Doluysa **her** kapsamlı tablo referansı (ana sorgu ve her alt sorgu) `Sube = @branch` süzgecini ayrıca taşır. Yazma yok. `python tools/vardiya_kapsam_denetimi.py` çıkış 0.
**Adımlar:** [ ] Kırmızı testler (`Tur=Canli`, BkmPanel dev salt-okuma): `Compliance_SumOfBranches_EqualsCompany` (kontrat `GetComplianceAsync_SubelerToplami_SirketeEsit`; her sayaç; şube listesi boşsa `KOŞAMADI`), `Compliance_NullBranch_SameAsBefore` · [ ] Uygulama · kapılar (+ `vardiya_kapsam_denetimi.py`) · [ ] kırmızı kip: bir alt sorgudan süzgeç geçici silinir → ilk test kırmızı → geri.
**Kabul:** testler yeşil; kapsam denetimi 0; kırmızı kip kanıtı.

### T-048 [UI] Ana sayfa: uyarı kuralları ve hedef toplamının çekirdeğe taşınması (refactor)
**Bağımlılık:** T-043, T-044 · **Test seviyesi:** hafif · **AC:** AC-4.8 (tek kaynak), AC-4.6, FR-005, FR-012
**Dosyalar:** Değiştir `dashboard/Components/Pages/Home.razor` · Test `tests/GmDashboard.Tests/Birim/HomeCoreSourceTests.cs`
**Gereksinimler (tam değerlerle):** `BuildAlerts` iki uyarı kuralını `AlertRules.Evaluate(_data)` sonucundan kurar (başarı kuralları 3 ve 4 Home'da kalır, kontrol sayılmaz). Mağaza hedef toplamı (`tNet`, `tHed`) `TargetSummary.From(_hedefMag)`'dan. Görünen metin ve değerler değişmez. Commit tipi `refactor`.
**Adımlar:** [ ] Test (kaynak): `Home_Source_UsesAlertRulesAndTargetSummary` · [ ] Uygulama · Playwright masaüstü `/` uyarı ve hedef değerleri önce/sonra birebir (T-041 tabanıyla) · derleme.
**Kabul:** test yeşil; önce/sonra eşit.

### T-049 [UI] Bugün kart 1 (dünkü ciro) ve 1a (Sınav iade oranı)
**Bağımlılık:** T-042, T-046, T-048, T-034 · **Test seviyesi:** tam · **AC:** AC-4.1, AC-4.3, AC-4.4, AC-4.5, AC-4.15, AC-0.3, AC-0.4, AC-0.10
**Dosyalar:** Oluştur `dashboard/Components/Shared/Today/YesterdaySalesCard.razor`, `dashboard/Components/Shared/Today/ExamReturnRow.razor` · Değiştir `dashboard/Components/Pages/Today.razor` · Test `tests/GmDashboard.Tests/Mobil/TodayCard1Tests.cs`
**Arayüzler:** Tüketir `Queries.GetPeriodAsync(DateOnly start, DateOnly endExcl, DateOnly? prevStart, DateOnly? prevEnd)` → `PeriodSummary.Stores[*]` (`Net`, `NetPerakende`, `NetSinav`, `Fis`) ve `Eticaret` (001 T-040); `SchoolAlignedComparison.Find` (T-042); `CardTones.ForChange`, `ForExamReturnRate` (T-012); `SinavQueries.GetDonemlerAsync`, `GetSezonKpiAsync(int?)` → `IadeOraniYuzde`; `SinavPeriod` (T-046); `<DuzeltmeNotu Anahtar="home.magaza-net-kirilim" />` (001 T-030)
**Gereksinimler (tam değerlerle):** kapı `kart:1`; satırlar her mağaza ve şirket için Perakende · Sınav Okulları · Toplam, ayrı satır E-ticaret; dün ve kıyas günü için `GetPeriodAsync(gün, gün+1)` iki çağrı (aynı çekirdek, aynı tanım); kıyas başlığı `"dd.MM.yyyy, dddd"`; değişim `(dün − kıyas) / kıyas × 100`, kıyas değeri 0 ya da kıyas günü `null` → "Kıyas günü yok", renk yok; mağazanın dün `Net == 0 && Fis == 0` → "Kapalı", renk yok; her satırın rengi yalnız kendi değişiminden. Perakende + Sınav = Toplam 1,00 TL toleransla (gösterim kontrolü değil, test). 1a: kapı `kart:1a` ve `SinavPeriod.ReturnRowVisible(bugün)`; dönem `SinavPeriod.DefaultId`; oran ≥ %3 `text-error`; hedef `/sinav`. Hata yalnız kartta. Not `DuzeltmeNotu` göstergenin yanında.
**Adımlar:** [ ] Kırmızı testler (kapı geçici açık değil; test, kartı kapı kapalıyken telefonda **görmez** ve masaüstünde görür): `Card1_Desktop_RowsAndComparisonDay`, `Card1_Desktop_RetailPlusExamEqualsTotal`, `Card1_Phone_GateClosed_NotRendered`, `Card1a_OutsideSeason_NotRendered` (birim, `FakeClock` Kasım) · [ ] Uygulama · derleme.
**Kabul:** testler yeşil.

### T-050 [UI] Bugün kart 2 (ay hedefi ve tahmin)
**Bağımlılık:** T-044, T-049 · **Test seviyesi:** tam · **AC:** AC-4.6, AC-4.7, AC-0.4
**Dosyalar:** Oluştur `dashboard/Components/Shared/Today/MonthTargetCard.razor` · Değiştir `Today.razor` · Test `tests/GmDashboard.Tests/Mobil/TodayCard2Tests.cs`
**Arayüzler:** Tüketir `Queries.GetHedefAsync(new DateOnly(dün.Year, dün.Month, 1), bugün)`; `TargetSummary.From` (T-044); `Queries.GetTahminAsync(bugün, bugün.Year, bugün.Month, 0)` → `Tahmin`, `Alt`, `Ust`; `CardTones.ForAttainment`; `HedefTabani.NotMetni(HedefTabani.Teyitli)` (001 T-040)
**Gereksinimler (tam değerlerle):** alt bölümde; kapı `kart:2`; gerçekleşen, hedef, gerçekleşme %, ay sonu tahmini, "Alt–Üst" aralığı; not null değilse `<p class="text-warning text-xs">`; hedef `/tahmin`. Masaüstünde de görünür (UI kararı 5).
**Adımlar:** [ ] Kırmızı testler: `Card2_Desktop_ValuesEqualHomeTarget` (`data-gosterge="bugun.hedef-gerceklesme"` = Ana sayfa hedef toplamı), `Card2_Desktop_TargetBaseNoteShown` (`Teyitli == false` iken) · [ ] Uygulama.
**Kabul:** testler yeşil.

### T-051 [UI] Bugün kart 3 (uyarılar)
**Bağımlılık:** T-043, T-050 · **Test seviyesi:** tam · **AC:** AC-4.8, AC-4.9, FR-008
**Dosyalar:** Oluştur `dashboard/Components/Shared/Today/AlertsCard.razor` · Değiştir `Today.razor` · Test `tests/GmDashboard.Tests/Mobil/TodayCard3Tests.cs`, `tests/GmDashboard.Tests/Birim/AlertsCardTextTests.cs`
**Arayüzler:** Tüketir `AlertRules.YesterdayWindow`, `AlertRules.Evaluate` (T-043), `Queries.GetPeriodAsync`
**Gereksinimler (tam değerlerle):** kapı `kart:3`; sorgu istisnası → `Evaluate(null)` (`CouldNotRun`). Metin: uyarı yoksa "N kontrol koştu, 0 uyarı" (N = `NoAlert` sayısı); koşamayan varsa ayrı satır "Koşamadı (k): <adlar>" ve kart asla `Success` tonu almaz; hepsi koşamadıysa "Kontroller koşamadı". Hedef `/#uyarilar`. Metin kuralı saf fonksiyon `AlertsCardText.Summary(IReadOnlyList<CheckResult>)` (aynı dosyada değil: `dashboard/Models/AlertsCardText.cs`, bu görev oluşturur).
**Adımlar:** [ ] Kırmızı testler: `Summary_AllNoAlert_NChecksZeroAlerts`, `Summary_OneCouldNotRun_NotGreenAndListed`, `Summary_AllCouldNotRun_ControlsCouldNotRun` (birim), `Card3_Desktop_Rendered` · [ ] Uygulama.
**Kabul:** testler yeşil.

### T-052 [UI] Bugün kart 4 (bekleyen sipariş)
**Bağımlılık:** T-045, T-051 · **Test seviyesi:** tam · **AC:** AC-4.10, AC-4.15, AC-0.3
**Dosyalar:** Oluştur `dashboard/Components/Shared/Today/PendingOrdersCard.razor` · Değiştir `Today.razor` · Test `tests/GmDashboard.Tests/Mobil/TodayCard4Tests.cs`
**Arayüzler:** Tüketir `EticQueries.GetBekleyenAsync()`, `PendingSummary.From` (T-045), `CardTones.ForPendingOrders`
**Gereksinimler (tam değerlerle):** kapı `kart:4`; "Bekleyen sipariş" (`data-gosterge="bugun.bekleyen"`) ve "4 gün ve üstü"; 0 → "0", renksiz; hedef `/eticaret`.
**Adımlar:** [ ] Kırmızı test `Card4_Desktop_SameAsEcommercePending` (T-058 sonrası E-ticaret `eticaret.bekleyen` ile eşit) · [ ] Uygulama.
**Kabul:** test yeşil.

### T-053 [UI] Bugün kart 5 (vadesi geçen alacak)
**Bağımlılık:** T-055 (Today.razor zinciri) · **Test seviyesi:** tam · **AC:** AC-4.11, AC-2.1 (renk), AC-0.3
**Dış bağımlılık:** 001 görev 083 (`GetCariRiskOzetAsync`) master'da
**Dosyalar:** Oluştur `dashboard/Components/Shared/Today/ReceivablesCard.razor` · Değiştir `Today.razor` · Test `tests/GmDashboard.Tests/Birim/ReceivablesCardSourceTests.cs`
**Arayüzler:** Tüketir `FinansQueries.GetCariRiskOzetAsync(CancellationToken)` → `CariRiskOzet(decimal VadesiGecenAlacak, decimal VadesiGecenBorc, int LimitAsanCari, int LimitTanimliCari, int AliciKayit, int SaticiKayit)` (001 T-083; master'daki ad Dalga 2 girişinde doğrulanır); `CardTones.ForOverdueReceivable`, `ForOverLimitCount`
**Gereksinimler (tam değerlerle):** kapı `kart:5`; "Vadesi geçen alacak" (`VadesiGecenAlacak`, > 0 `text-error`), "Limit aşan cari" (> 0 `text-warning`); hedef `/cari-risk`. Kart hesap yazmaz.
**Adımlar:** [ ] Kırmızı test `ReceivablesCard_Source_CallsSameCoreAsScreen` (kontrat `CariRiskKarti_EkranKpisiyleAyniMetot`: kart ve `CariRisk.razor` kaynağında `GetCariRiskOzetAsync` geçer; `_rows.Sum` geçmez) · [ ] Uygulama.
**Kabul:** test yeşil; Playwright değer eşitliği kapı açılınca T-074'te.

### T-054 [UI] Bugün kart 8 (personel çalışma süresi uyumu)
**Bağımlılık:** T-047, T-052 · **Test seviyesi:** tam · **AC:** AC-4.13, FR-009
**Dosyalar:** Oluştur `dashboard/Components/Shared/Today/StaffComplianceCard.razor` · Değiştir `Today.razor` · Test `tests/GmDashboard.Tests/Mobil/TodayCard8Tests.cs`
**Arayüzler:** Tüketir `GetBranchBreakdownAsync(userId, bas, bit)`, `GetComplianceAsync(userId, bas, bit, branch)` (T-047); `CardTones.ForCompliance`
**Gereksinimler (tam değerlerle):** kapı `kart:8`; dönem Vardiya ekranının açılış dönemiyle aynı; satır başına şube adı + aşım sayısı (11 saat, 12 saat dinlenme, gece 7,5 saat); bileşene yalnız `(string Branch, int Breaches)` listesi geçer; ad/sicil taşıyan tip kart bileşenine girmez. Hedef `/vardiya`.
**Adımlar:** [ ] Kırmızı test `Card8_Desktop_NoNameOrSicilInDom` (kontrat `Bugun_375_PersonelKartindaAdSicilYok`; örnek ad/sicil `bkm.Vrd_KisiGun`'den panel salt-okuma ile alınır, DOM ve SignalR çerçevelerinde yok) · [ ] Uygulama.
**Kabul:** test yeşil.

### T-055 [UI] Sabah birleşmesi (Bugün → Sabah brifingi bölümü)
**Bağımlılık:** T-054, T-035 · **Test seviyesi:** tam · **AC:** AC-4.16, AC-7.1, FR-010
**Dosyalar:** Değiştir `dashboard/Components/Pages/Sabah.razor` (`@page` silinir, `[Parameter] public bool Embedded`), `Today.razor` (`id="sabah"` açılır bölüm: başlık **Sabah brifingi**, açıldığında üretilir), `LegacyRedirect.razor` (`@page "/sabah"`) · Test `tests/GmDashboard.Tests/Kabuk/LegacyRedirectWave2Tests.cs`
**Gereksinimler (tam değerlerle):** bölüm `ShouldRender(Viewport, "ekran:bugun-donem")` iken; açılır bölüm (`<details>`) açılmadan LLM çağrılmaz (UI kararı 3). Uyarı listesi çapası `id="uyarilar"`.
**Adımlar:** [ ] Kırmızı testler: `LegacyPath_Sabah_RedirectsToTodayAnchor` (302 `/#sabah`), `Today_Desktop_MorningSectionCollapsedUntilOpened` · [ ] Uygulama.
**Kabul:** testler yeşil.

#### B ekranları — ortak kural (B-ORTAK; T-056…T-064 buna atıf yapar)

1. Telefonda yalnız görevin "Görünen" maddesi çizilir. "Gizlenen" bölüm yalnız `Viewport == Desktop` iken **çizilir ve verisi yüklenir**. Telefonda ve `Unknown`'da yerinde "Ayrıntı masaüstünde." yazar (FR-007).
2. Telefon özeti alt bileşene çıkar: `dashboard/Components/Shared/<Klasör>/<Ad>PhoneSummary.razor`. Ekran dosyası büyümez (önce/sonra `wc -l` raporda).
3. Özet, ekranın bugün yüklediği veriyi ya da adı verilen çekirdek metodu kullanır. Yeni sorgu ve Razor içinde hesap yok (FR-005, FR-012).
4. Her gösterge `data-gosterge="<ekran>.<ad>"` taşır. 001 notları (`<DuzeltmeNotu>`) göstergenin yanında durur (AC-0.4).
5. Hata durumunda `UserMessages.DataUnavailable` + `LogError(ex, "{Ekran} veri yükleme hatası", "<Ekran>")` (AC-0.10).
6. Masaüstü görünümü bugünküyle aynı kalır (AC-0.9, AC-5.8).
7. Ortak testler (e2e-test-yazari, `Tur=Mobil`):
   - `<Ad>_Phone_SummaryAndNote`: kapı kapalıyken ekran doğrudan adresle açılır.
   - `<Ad>_Desktop_SectionComplete`: kontrat `BEkrani_1280_BolumEksiksiz`; T-041 tabanıyla başlık listesi aynı.
8. T-017 ölçümündeki ekran satırı `Report` kipinde ihlalsiz kalır. Kapı Dalga 3'te T-074 ile açılır.
9. Kapılar: `npm run build:css` · derleme · `turkce_tanimlayici_denetimi.py` (yeni dosyada 0, eski dosyada taban aşılmaz).

### T-056 [UI] Mağazalar telefon özeti
**Bağımlılık:** T-041 · **Test seviyesi:** tam · **AC:** AC-5.2, AC-0.4, AC-0.9, AC-5.8, FR-007
**Dış bağımlılık:** 001 madde D-5 master'da (kapı anahtarı `ekran:magazalar` → `001:D-5`)
**Dosyalar:**
- Değiştir: `dashboard/Components/Pages/Magazalar.razor`
- Oluştur: `dashboard/Components/Shared/Magazalar/MagazalarPhoneSummary.razor`
- Test: `tests/GmDashboard.Tests/Mobil/StoresScreenTests.cs`
**Arayüzler:**
- Tüketir: ekranın bugün yüklediği mağaza listesi; `Viewport` (T-018); `UserMessages.DataUnavailable` (T-001)
- Üretir: `<MagazalarPhoneSummary />`
**Gereksinimler (tam değerlerle):**
- Rota `/magazalar`.
- Görünen: her mağaza bir kart (`data-gosterge="magazalar.<mekanId>.net"`). Okul açılışı uyarısı görünür metin olarak yazar, `title` içinde kalmaz.
- Gizlenen: gün karşılaştırma tablosunun geniş hâli.
**Adımlar:**
- [ ] Kırmızı testler (B-ORTAK 7): `Stores_Phone_SummaryAndNote`, `Stores_Desktop_SectionComplete`, `Stores_Phone_SchoolOpeningWarningVisibleText`.
- [ ] Uygulama · kapılar (B-ORTAK 9).
**Kabul:** üç test yeşil; satır sayısı önce/sonra raporda.

### T-057 [UI] Mağaza telefon özeti
**Bağımlılık:** T-041 · **Test seviyesi:** tam · **AC:** AC-5.3, AC-0.4, AC-0.9, AC-5.8, FR-007
**Dış bağımlılık:** 001 maddeleri H6 ve H10.3 master'da (kapı `ekran:magaza` → `001:H6`, `001:H10.3`)
**Dosyalar:**
- Değiştir: `dashboard/Components/Pages/Magaza.razor`
- Oluştur: `dashboard/Components/Shared/Magaza/MagazaPhoneSummary.razor`
- Test: `tests/GmDashboard.Tests/Mobil/StoreScreenTests.cs`
**Arayüzler:**
- Tüketir: ekranın bugün yüklediği mağaza detayı ve ısı haritası verisi; `Viewport`; `UserMessages.DataUnavailable`
- Üretir: `<MagazaPhoneSummary />`
**Gereksinimler (tam değerlerle):**
- Rota `/magaza/{Id:int}`; testlerde `/magaza/1`, `/magaza/4477`, `/magaza/4478`.
- Görünen: göstergeler telefonda en çok iki sütunda dizilir (`grid-cols-2`). Altında dönemin en yoğun 5 saati liste olarak yer alır. Liste ısı haritası hücrelerinin saat bazında toplanıp azalan sıralanmasıyla kurulur; yeni sorgu yok, saat başına toplam fiş sayısı kullanılır. Göstergeler `data-gosterge="magaza.<ad>"`.
- Gizlenen: saat × gün ısı haritası.
**Adımlar:**
- [ ] Kırmızı testler: `Store_Phone_SummaryAndNote`, `Store_Desktop_SectionComplete`, `Store_Phone_TopFiveHoursListed` (beş satır, azalan).
- [ ] Uygulama · kapılar.
**Kabul:** testler yeşil.

### T-058 [UI] E-ticaret telefon özeti
**Bağımlılık:** T-045 · **Test seviyesi:** tam · **AC:** AC-5.4, AC-0.3, AC-0.4, AC-0.9, FR-007
**Dış bağımlılık:** 001 maddeleri H4 ve D-3 master'da (kapı `ekran:eticaret` → `001:H4`, `001:D-3`)
**Dosyalar:**
- Değiştir: `dashboard/Components/Pages/Eticaret.razor`
- Oluştur: `dashboard/Components/Shared/Eticaret/EticaretPhoneSummary.razor`
- Test: `tests/GmDashboard.Tests/Mobil/EcommerceScreenTests.cs`
**Arayüzler:**
- Tüketir: `EticQueries.GetBekleyenAsync()` → `BekleyenBucket`; `PendingSummary.From` → `PendingTotals` (T-045); `CardTones.ForPendingOrders` (T-012); ekranın bugün yüklediği net ciro
- Üretir: `<EticaretPhoneSummary />`; `data-gosterge="eticaret.bekleyen"` (T-052 kart 4 bununla karşılaştırılır)
**Gereksinimler (tam değerlerle):**
- Rota `/eticaret`.
- Görünen: en üstte bekleyen sipariş kartı (toplam bekleyen ve "4 gün ve üstü"). Kartın rengi `CardTones.ForPendingOrders`'tan gelir. Altında net ciro (`data-gosterge="eticaret.net"`). Masaüstündeki bekleyen bölümü de `PendingSummary.From`'u çağırır (tek çekirdek).
- Gizlenen: kategori, kargo ve huni bölümleri.
**Adımlar:**
- [ ] Kırmızı testler: `Ecommerce_Phone_SummaryAndNote`, `Ecommerce_Desktop_SectionComplete`, `Ecommerce_PendingValue_SameOnPhoneAndDesktop`.
- [ ] Uygulama · kapılar.
**Kabul:** testler yeşil.

### T-059 [UI] Sınav Okulları telefon özeti
**Bağımlılık:** T-046 · **Test seviyesi:** tam · **AC:** AC-5.5, AC-0.4, AC-0.9, FR-005, FR-007
**Dış bağımlılık:** 001 maddeleri H9 ve H10.3 master'da (kapı `ekran:sinav` → `001:H9`, `001:H10.3`)
**Dosyalar:**
- Değiştir: `dashboard/Components/Pages/Sinav.razor`
- Oluştur: `dashboard/Components/Shared/Sinav/SinavPhoneSummary.razor`
- Test: `tests/GmDashboard.Tests/Mobil/SinavScreenTests.cs`
**Arayüzler:**
- Tüketir: `SinavQueries.GetDonemlerAsync()`, `GetSezonKpiAsync(int?)` → `SinavSezonKpi.IadeOraniYuzde`; `SinavPeriod.DefaultId` (T-046); `CardTones.ForExamReturnRate` (T-012)
- Üretir: `<SinavPhoneSummary />`
**Gereksinimler (tam değerlerle):**
- Rota `/sinav`.
- `Sinav.razor:321`'deki varsayılan dönem seçimi `SinavPeriod.DefaultId(_donemler)` çağrısına döner; davranış birebir aynı kalır.
- Görünen: ana göstergeler (`data-gosterge="sinav.net"`, `"sinav.iade-orani"`). İade oranı %3 ya da üstündeyse `text-error`.
- Gizlenen: iade belge listesi.
**Adımlar:**
- [ ] Kırmızı testler: `Sinav_Phone_SummaryAndNote`, `Sinav_Desktop_SectionComplete`, birim `Sinav_Source_UsesSinavPeriodDefault`.
- [ ] Uygulama · kapılar.
**Kabul:** testler yeşil.

### T-060 [UI] Tahmin telefon özeti
**Bağımlılık:** T-041 · **Test seviyesi:** tam · **AC:** AC-5.7, AC-0.4, AC-0.9, FR-007
**Dış bağımlılık:** 001 madde D-5 master'da (kapı `ekran:tahmin` → `001:D-5`)
**Dosyalar:**
- Değiştir: `dashboard/Components/Pages/Tahmin.razor`
- Oluştur: `dashboard/Components/Shared/Tahmin/TahminPhoneSummary.razor`
- Test: `tests/GmDashboard.Tests/Mobil/ForecastScreenTests.cs`
**Arayüzler:**
- Tüketir: ekranın bugün yüklediği `TahminSonuc` (`Tahmin`, `Alt`, `Ust`)
- Üretir: `<TahminPhoneSummary />`
**Gereksinimler (tam değerlerle):**
- Rota `/tahmin`.
- Görünen: tahmin (`data-gosterge="tahmin.tahmin"`) ve "Alt–Üst" aralığı (`"tahmin.alt"`, `"tahmin.ust"`).
- Gizlenen: modellerin karşılaştırması.
**Adımlar:**
- [ ] Kırmızı testler: `Forecast_Phone_SummaryAndNote`, `Forecast_Desktop_SectionComplete`.
- [ ] Uygulama · kapılar.
**Kabul:** testler yeşil.

### T-061 [UI] Envanter telefon özeti ve dışa aktarma
**Bağımlılık:** T-041 · **Test seviyesi:** tam · **AC:** AC-6.4, AC-0.11, AC-0.4, AC-0.9, FR-007, FR-016
**Dış bağımlılık:** 001 maddeleri H3, H7, H8, H14 ve H10.1 master'da (kapı `ekran:envanter` → `001:H3`, `001:H7`, `001:H8`, `001:H14`, `001:H10.1`); 001 H14 tanım sabitleri (`StokGostergeTanimlari`, adı Dalga 2 girişinde doğrulanır)
**Dosyalar:**
- Değiştir: `dashboard/Components/Pages/Envanter.razor`
- Oluştur: `dashboard/Components/Shared/Envanter/EnvanterPhoneSummary.razor`
- Değiştir (e2e-test-yazari, yalnız ekleme): `tests/GmDashboard.Tests/Mobil/ScreenRulesTests.cs` içindeki bilinen dışa aktarma ihlal listesinden `/envanter` satırı silinir
- Test: `tests/GmDashboard.Tests/Mobil/InventoryScreenTests.cs`
**Arayüzler:**
- Tüketir: ekranın bugün yüklediği üç stok göstergesi; `StokGostergeTanimlari` metinleri (001 H14)
- Üretir: `<EnvanterPhoneSummary />`
**Gereksinimler (tam değerlerle):**
- Rota `/envanter`.
- Görünen: üç gösterge, ölü stok, aşırı stok ve stokta yokluk (`data-gosterge="envanter.olu-stok"`, `"envanter.asiri-stok"`, `"envanter.stokta-yok"`). Her birinin yanında 001 H14 tanım metni yer alır; metin sabitten gelir, Razor'da yeniden yazılmaz.
- Gizlenen: listeler ve modallar.
- `Envanter.razor:316`'daki `/api/olustok-excel` bağlantısı `data-disa-aktarma` taşır ve yalnız `Desktop`'ta çizilir.
**Adımlar:**
- [ ] Kırmızı testler: `Inventory_Phone_SummaryAndNote`, `Inventory_Desktop_SectionComplete`, `Inventory_Phone_NoExportLink`.
- [ ] Uygulama · kapılar · T-017 dışa aktarma kuralı `/envanter` için `Enforce` kipinde yeşil.
**Kabul:** testler yeşil; bilinen ihlal listesinde `/envanter` yok.

### T-062 [UI] Operasyon telefon özeti
**Bağımlılık:** T-041 · **Test seviyesi:** tam · **AC:** AC-6.3, AC-6.3a, AC-0.9, FR-007
**Dış bağımlılık:** 001 maddeleri H1 ve H10.1 master'da (kapı `ekran:operasyon` → `001:H1`, `001:H10.1`)
**Dosyalar:**
- Değiştir: `dashboard/Components/Pages/Operasyon.razor`
- Oluştur: `dashboard/Components/Shared/Operasyon/OperasyonPhoneSummary.razor`
- Test: `tests/GmDashboard.Tests/Mobil/OperationsScreenTests.cs`
**Arayüzler:**
- Tüketir: ekranın bugün yüklediği uyarı (istisna) verisi; `PhoneGate.ShouldRender` (T-009)
- Üretir: `<OperasyonPhoneSummary />`
**Gereksinimler (tam değerlerle):**
- Rota `/operasyon`.
- Görünen: yalnız uyarı (istisna) kartı.
- Gizlenen: Kumbara ve manuel indirim göstergesi (001 AC-1.4) ve öteki bölümler.
- Personel saati başına satış göstergesi `PhoneGate.ShouldRender(Viewport, "gosterge:operasyon-splh")` koşuluyla çizilir. Bu anahtar `ek:splh` maddesine bağlıdır ve bugün kapalıdır.
- Masaüstündeki gösterge değişmez.
**Adımlar:**
- [ ] Kırmızı testler: `Operations_Phone_SummaryAndNote`, `Operations_Desktop_SectionComplete`, `Operation_Phone_NoStaffHourSales` (AC-6.3).
- [ ] Uygulama · kapılar.
**Kabul:** testler yeşil.

### T-063 [UI] Vardiya telefon özeti (KVKK)
**Bağımlılık:** T-054 · **Test seviyesi:** tam · **AC:** AC-6.5, AC-6.5a, FR-009, SC-009, AC-0.9
**Dış bağımlılık:** 001 madde H10.1 master'da (kapı `ekran:vardiya` → `001:H10.1`)
**Dosyalar:**
- Değiştir: `dashboard/Components/Pages/Vardiya.razor`
- Oluştur: `dashboard/Components/Shared/Vardiya/VardiyaPhoneSummary.razor`
- Test: `tests/GmDashboard.Tests/Mobil/VardiyaScreenTests.cs`
**Arayüzler:**
- Tüketir: `VardiyaQueries.GetBranchBreakdownAsync(string userId, DateOnly bas, DateOnly bit)` → `VrdBranch`, uyum kartları; `GetRowsAsync(…)` (yalnız masaüstü); `Viewport` (T-018); `LiveDb.PanelDb()` (test örneği)
- Üretir: `<VardiyaPhoneSummary />`
**Gereksinimler (tam değerlerle):**
- Rota `/vardiya`.
- Görünen: mağaza bazında isimsiz özet (`data-gosterge="vardiya.<sube>.<ad>"`).
- Kişi satırları:
  - `GetRowsAsync` yalnız `Viewport == Desktop` iken çağrılır. `Phone` ve `Unknown`'da çağrılmaz.
  - Bileşen durumunda isimli kayıt tutulmaz.
  - Masaüstünden telefona geçişte (görünüm değişimi) isimli liste durumdan silinir ve `StateHasChanged` çağrılır.
  - Telefonda yerinde "Kişi satırları masaüstünde." yazar.
- CSS ile gizleme kabul edilmez.
**Adımlar:**
- [ ] Kırmızı testler:
  - `Vardiya_Phone_SummaryAndNote`
  - `Vardiya_Desktop_SectionComplete`
  - `Vardiya_Phone_NoNameOrSicilInDomOrCircuit` (kontrat `Vardiya_375_AdSicilNeDomdaNeDevredeVar`): sayfa sonuna kadar kaydırılır. `innerHTML` ve bütün SignalR çerçeveleri, `LiveDb.PanelDb()` ile aynı dönemden alınan örnek kişinin adı ve sicili için taranır. Çıktıya yalnız "bulundu/bulunmadı" yazılır. Örnek yoksa `KOŞAMADI`.
  - `Vardiya_ResizeToPhone_NamedListRemoved` (kontrat `Gorunum_PencereDaralinca_IsimliListeSilinir`, AC-6.5a)
- [ ] Uygulama · kapılar.
- [ ] Kırılabilirlik: telefonda geçici olarak bir isimli satır çizilir, test kırmızı görülür, değişiklik elle geri alınır.
**Kabul:** testler yeşil; kırılabilirlik kanıtı raporda.

### T-064 [UI] Mizan telefon özeti
**Bağımlılık:** T-041 · **Test seviyesi:** tam · **AC:** AC-3.3, AC-0.4, AC-0.9, FR-007
**Dış bağımlılık:** 001 madde H12 master'da (kapı `ekran:mizan` → `001:H12`); 001 H12 mizan kartları (nakit, alınan çek, KDV)
**Dosyalar:**
- Değiştir: `dashboard/Components/Pages/Mizan.razor`
- Oluştur: `dashboard/Components/Shared/Mizan/MizanPhoneSummary.razor`
- Test: `tests/GmDashboard.Tests/Mobil/MizanScreenTests.cs`
**Arayüzler:**
- Tüketir: 001 H12'nin ekrana koyduğu nakit, alınan çekler ve KDV pozisyonu değerleri (ad Dalga 2 girişinde doğrulanır)
- Üretir: `<MizanPhoneSummary />`
**Gereksinimler (tam değerlerle):**
- Rota `/mizan`.
- Görünen: nakit, alınan çekler (nakitten ayrı) ve KDV pozisyonu (`data-gosterge="mizan.nakit"`, `"mizan.alinan-cek"`, `"mizan.kdv"`).
- Gizlenen: hesap ağacı (`MizanDugum`). Telefonda yerinde "Ayrıntı masaüstünde." yazar.
**Adımlar:**
- [ ] Kırmızı testler: `Mizan_Phone_SummaryAndNote`, `Mizan_Desktop_SectionComplete`.
- [ ] Uygulama · kapılar.
**Kabul:** testler yeşil.

### T-065 [UI] Müşteri + Sadakat birleşmesi ve maske hücreleri
**Bağımlılık:** T-016, T-055 (LegacyRedirect zinciri), T-041 · **Test seviyesi:** tam · **AC:** AC-7.1, AC-7.3, AC-7.4, AC-8.1, AC-8.2, AC-8.4, AC-8.5, AC-8.6, AC-8.7, AC-6.2, FR-015
**Dosyalar:** Değiştir `dashboard/Components/Pages/Musteri.razor` (Sadakat sekmesi `role="tab"` + `?sekme=sadakat`; ≤ 15 satır), `Sadakat.razor` (`@page` silinir; maske hücreleri), `LegacyRedirect.razor` (`@page "/sadakat"`), `dashboard/Models/NavRegistry.cs` (`sadakat` öğesi çıkar) · Oluştur `dashboard/Components/Shared/Musteri/MaskedCell.razor` · Test `tests/GmDashboard.Tests/Birim/PersonalDataMaskWiringTests.cs`, `tests/GmDashboard.Tests/Mobil/CustomerScreenTests.cs`
**Gereksinimler (tam değerlerle):** `MaskedCell` (`Kind` = Name/Phone/Card, `Value`): `Viewport != Desktop` → `PersonalDataMask.<Kind>(Value)`, aksi açık değer; sıralama/arama açık değerle sunucuda. Müşteri: ad, telefon, kart no (liste, satır ayrıntısı, RFM ve LTV tabloları); Sadakat: win-back ad, telefon, kart no. Sayılar değişmez. Telefonda sayfa yana taşmaz (tablo kendi kabında). Kapı kapalı kalır.
**Adımlar:** [ ] Kırmızı testler: `MaskWiring_Source_AllPersonalCellsUseMaskedCell` (kaynak: `c.Name`, `PhoneNumber`, `CardNumber` doğrudan çizilmez), `LegacyPath_Sadakat_RedirectsToCustomerTab`, `Customer_Desktop_ValuesOpen` (kontrat `Maske_1280_AcikDegerGorunur`), `Customer_SadakatTab_SameValuesAsBaseline` (AC-7.3, T-041) · [ ] Uygulama.
**Kabul:** testler yeşil. Telefon maske ölçümü (`Maske_375_…`) kapı açılırken T-074'te.

### T-066 [UI] Trafik maske ve taşma
**Bağımlılık:** T-065 · **Test seviyesi:** tam · **AC:** AC-8.3, AC-8.4, AC-8.7, AC-6.2, FR-015
**Dosyalar:** Değiştir `dashboard/Components/Pages/Trafik.razor` · Test `tests/GmDashboard.Tests/Birim/TrafficMaskWiringTests.cs`
**Gereksinimler (tam değerlerle):** personel tablosunda kasiyer adı `MaskedCell Kind=Name`; fiş, net, gün, saat açık; telefonda yana taşmaz.
**Adımlar:** [ ] Kırmızı test `TrafficMaskWiring_Source_CashierNameMasked` · [ ] Uygulama.
**Kabul:** test yeşil.

### T-067 [UI] Bulunurluk → Satış analizi sekmesi, taşma, dışa aktarma
**Bağımlılık:** T-065 (LegacyRedirect, NavRegistry zinciri) · **Test seviyesi:** tam · **AC:** AC-7.1, AC-7.3, AC-7.4, AC-6.2, AC-0.11
**Dosyalar:** Değiştir `SatisAnalizi.razor` (Bulunurluk sekmesi, `?sekme=bulunurluk`; ≤ 15 satır), `SatisAnaliziTablo.razor` (Excel bağlantısı `data-disa-aktarma` + yalnız `Desktop`; taşma), `Bulunurluk.razor` (`@page` silinir), `LegacyRedirect.razor` (`@page "/bulunurluk"`), `NavRegistry.cs` (`bulunurluk` çıkar) · Test `tests/GmDashboard.Tests/Mobil/SalesAnalysisMergeTests.cs`
**Adımlar:** [ ] Kırmızı testler: `LegacyPath_Bulunurluk_RedirectsToTab`, `SalesAnalysis_BulunurlukTab_SameValuesAsBaseline`, `SalesAnalysis_Phone_NoExport` · [ ] Uygulama.
**Kabul:** testler yeşil; T-017 bilinen ihlal listesinden `/satis-analizi` silinir.

### T-068 [UI] Satınalma ürün detayı → Satış analizi ürün detayı sekmesi
**Bağımlılık:** T-067 · **Test seviyesi:** tam · **AC:** AC-7.1, AC-7.2, AC-7.3, AC-6.2
**Dosyalar:** Değiştir `SatisAnaliziUrun.razor` (Satınalma sekmesi, `?sekme=satinalma`; ≤ 15 satır; taşma), `SatinalmaUrunDetay.razor` (`@page` silinir, `[Parameter] int StkId` korunur), `LegacyRedirect.razor` (`@page "/satinalma/urun/{StkId:int}"`) · Test `tests/GmDashboard.Tests/Mobil/ProductDetailMergeTests.cs`
**Adımlar:** [ ] Kırmızı testler: `LegacyPath_PurchaseProduct_SameProductTab` (`/satinalma/urun/{MOBIL_ORNEK_STKID}` → aynı ürün), `ProductDetail_PurchaseTab_SameValuesAsBaseline`, `LegacyLinks_NoInAppLinkToMergedPaths_All` (T-035 testinin altı adresli hâli) · [ ] Uygulama.
**Kabul:** testler yeşil.

### T-069 [UI] Eşikler telefonda salt okunur
**Bağımlılık:** T-041 · **Test seviyesi:** tam · **AC:** AC-6.6, AC-6.7, FR-003b
**Dosyalar:** Değiştir `dashboard/Components/Pages/Esikler.razor` · Test `tests/GmDashboard.Tests/Mobil/ThresholdsScreenTests.cs`
**Gereksinimler (tam değerlerle):** T-033 ile aynı kural ve not metni; `SettingsReadOnly` deseni (`Components/Shared/Ayarlar/SettingsReadOnly.razor` yeniden kullanılır, değişmez).
**Adımlar:** [ ] Testler `Thresholds_Phone_NoEditNote`, `Thresholds_Desktop_FormPresent` · [ ] Uygulama.
**Kabul:** testler yeşil.

### T-070 [UI] Kalan C ekranlarında taşma ve dışa aktarma
**Bağımlılık:** T-041 · **Test seviyesi:** hafif · **AC:** AC-6.2, FR-003a, AC-0.11, SC-001a
**Dosyalar:** Değiştir `HediyeCeki.razor`, `OdakStok.razor`, `BaskisiYok.razor`, `SatinalmaAnaliz.razor`, `SezonAksiyon.razor` (Excel bağlantısı `data-disa-aktarma` + yalnız `Desktop`)
**Gereksinimler (tam değerlerle):** T-036 ile aynı taşma kuralı. T-017'deki bilinen dışa aktarma ihlal listesinden `/sezon-aksiyon` silinir (liste boşalır; e2e-test-yazari adımı).
**Adımlar:** [ ] Uygulama · `Tur=Mobil` beş satır ve dışa aktarma kuralı `Enforce` yeşil.
**Kabul:** satırlar yeşil; bilinen ihlal listesi boş.

### T-071 [E2E] Dalga 2 bitiş turu
**Bağımlılık:** T-042…T-070 · **Test seviyesi:** tam · **AC:** AC-0.3, AC-0.4, AC-0.9, AC-5.8, AC-7.3, SC-001, SC-001a, SC-005, SC-007
**Dosyalar:** Test `tests/GmDashboard.Tests/Mobil/Wave2CompletionTests.cs`
**Gereksinimler (tam değerlerle):** `Desktop_AfterWave2_NothingMissing` (T-041 tabanıyla başlık/gösterge listesi karşılaştırması; eksik 0); `Indicator_PhoneAndDesktop_SameValue` (kontrat `Gosterge_375ve1280_AyniDeger`; açık ekranların her birinden en az bir `data-gosterge`); `MergedIndicator_SameValueInTarget` (kontrat `BirlesenGosterge_HedefteAyniDeger`); `Note_Phone_NextToIndicator` (AC-0.4); Development + Production turu.
**Adımlar:** [ ] Testler · [ ] iki tur · [ ] rapor.
**Kabul:** yeşil; rapor.

### T-072 [YARDIM] Telefon menüsü yardımının güncellenmesi
**Bağımlılık:** T-071 · **Test seviyesi:** yok (gerekçe: belge) · **AC:** Madde 11
**Dosyalar:** Değiştir `docs/yardim/telefon-menusu.md`
**Gereksinimler (tam değerlerle):** Bugün kartlarının anlamı ve renkleri (eşikler `CardTones` ile birebir), birleşen ekranların yeni yeri, Vardiya'da kişi satırının neden yok olduğu. Künye güncellenir.
**Adımlar:** [ ] Yaz · hook temiz.
**Kabul:** belge güncel.

### T-073 [DOC] CHANGELOG — Dalga 2
**Bağımlılık:** T-071 · **Test seviyesi:** yok (gerekçe: belge) · **AC:** Madde 11
**Dosyalar:** Değiştir `dashboard/CHANGELOG.md`
**Gereksinimler (tam değerlerle):** `[Yayımlanmamış]` → Eklendi: Bugün kartları (dünkü ciro, ay hedefi, uyarılar, bekleyen sipariş, vadesi geçen alacak, personel uyumu); Değişti: Sabah, Sadakat, Bulunurluk, Satınalma ürün detayı birleşti, eski adresler yönlenir; telefonda B ekranları özet gösterir.
**Adımlar:** [ ] Yaz · hook temiz.
**Kabul:** güncel.

---

# Dalga 3 — kapı açma

### T-074 [NET] Telefon kapısı açma (madde başına ayrı commit)
**Bağımlılık:** Dalga 2'nin ilgili ekran görevi tamam · **Test seviyesi:** tam · **AC:** AC-0.2, AC-2.1, AC-4.11, AC-8.0a, AC-8.1–8.7, SC-006, SC-009
**Dış bağımlılık:** 001 görev 086 — `specs/001-panel-veri-duzeltme/kabul-sonucu.md` içinde ilgili satır `tuttu` ve kanıtlı
**Dosyalar:**
- Değiştir: `dashboard/Models/PhoneGate.cs` (yalnız `AcceptedItems` satırı)
- Test: `tests/GmDashboard.Tests/Mobil/PersonalDataMaskPhoneTests.cs` (bir kez, ilk kişisel veri kapısında)
**Arayüzler:**
- Tüketir: `PhoneGate.AcceptedItems`, `IsOpen` (T-009); `kabul-sonucu.md` (001 T-086)
**Gereksinimler (tam değerlerle):**
- Her yürütme **tek madde anahtarı** ekler; commit `feat(bkm): telefon kapısı <anahtar> açıldı (T-074)`; gövdede kabul satırının kanıtı. Geri alma ayrı commit (anahtar çıkar).
- Yürütme sırası her seferinde: (1) `kabul-sonucu.md` satırını oku; `tuttu` değilse dur. (2) Anahtarı ekle. (3) Birim takımı (`AcceptedItems_AllMarkedHeldInAcceptanceFile` dahil) yeşil. (4) `IsOpen` değeri **false → true** dönen her `ekran:`/`kart:`/`gosterge:` anahtarı listelenir (geçici test çıktısı) ve aşağıdaki tablo satırları koşulur. (5) Kırmızıysa commit yok, anahtar geri çıkar.
- Açılınca koşulacaklar:

| Açılan anahtar | Koşulacak |
|---|---|
| herhangi bir A/B `ekran:` | `ScreenRules_Phone375_AsMode` o ekranın satırı `Enforce` kipinde yeşil; `GateMenu_PanelLinks_EqualOpenItems` |
| `ekran:bugun-donem` | `Today_Phone_*` + `/` `Enforce`; Ana sayfa bölümü telefonda çizilir |
| `kart:1`…`kart:8` | ilgili `TodayCard<N>Tests` telefonda (`Phone` varyantı görünür) + `Indicator_PhoneAndDesktop_SameValue` o kart |
| `kart:5` / `ekran:cari-risk` | `Bugun_KartDegeri_KaynakEkranlaAyni` kart 5 ↔ Cari/Risk (AC-4.11), `CariRisk_Phone_*` |
| `ekran:musteri`, `ekran:trafik`, `ekran:sadakat` | **commit'ten önce** `PersonalData_Phone_NoOpenValueInDomOrCircuit` (kontrat `Maske_375_AcikAdTelefonNeDomdaNeDevrede`, `olcum.md` § 5: sonuna kadar kaydırma, bir satırın ayrıntısı açılır; `innerHTML` + bütün SignalR çerçeveleri; örnekler aynı dönemden `LiveDb`: müşteri açık adı, telefonun son 7 rakamı, kart numarasının ilk 8 karakteri; Trafik kasiyer açık adı; örnek yoksa `KOŞAMADI`) yeşil; `PersonalDataScreen_GateOpen_RequiresMaskInRazor` yeşil; `PersonalScreens_Phone_DirectUrl_…` artık sayfayı açar |
| `gosterge:operasyon-splh` | `ek:splh` başka kayıtta kabul edilmeden eklenmez |

- İlk kişisel veri kapısında maske testi yazılır (e2e-test-yazari) ve kırılabilirliği gösterilir: telefonda bir hücre geçici açık değerle çizilir → kırmızı → elle geri.
**Adımlar:** [ ] Madde başına yukarıdaki sıra · [ ] `ork not karar` ile açılış.
**Kabul:** her açılış commit'i tek satır; ilgili testler yeşil; maske testi kırılabilirlik kanıtıyla (bir kez).

### T-075 [ISLETIM] SC-008 açılış sayımı (ÇIKARIM ölçüt)
**Bağımlılık:** Dalga 1 yayını + 10 iş günü · **Test seviyesi:** yok (gerekçe: ölçüm; kod değişmez) · **AC:** SC-008
**Dosyalar:** Oluştur `.orkestra/calisma/002-mobil-kabuk-ekran/sc-008-sayim.md` (git dışı)
**Gereksinimler (tam değerlerle):** sunucu günlüğünde `Uygulama açılışı uygulama` satırları gün başına sayılır (10 iş günü, 08:00–10:00 aralığı ayrıca); yöntem ve komut kayda; sonuç `ork not ölçüm` ile journal'a. Etiket ÇIKARIM ölçüt (spec).
**Adımlar:** [ ] Sayım · [ ] kayıt.
**Kabul:** sayım tablosu ve komut kayıtta.
