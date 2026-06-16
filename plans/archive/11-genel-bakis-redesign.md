# Plan 11 — Genel Bakış (Home) Redesign: Modal → Sayfa-Nav + SignalR'sız Drill

**Tarih:** 2026-06-16
**Proje:** `bkm`
**Yazan:** Fikri / Claude (planner, opus)
**Durum:** ✅ Tamamlandı (16.06 — uygulandı, build yeşil, smoke geçti; commit bekliyor)

---

## 1. Problem

Home (`/`) ve mağaza detay sayfalarındaki tüm drill etkileşimi (TOPLAM kategori, E-ticaret kanal, kategori→ürün, ödeme, kampanya) Blazor `InteractiveServer` modalleri ve `@onclick` üzerinden çalışıyor. Bu etkileşim **SignalR/WebSocket** gerektiriyor. Mobil HTTPS'te mkcert sertifikası Android'de güvensiz sayıldığından WSS kurulamıyor → sayfa SSR ile açılıyor ama **tıklama ölü, drill çalışmıyor** (B-47, kanıt: `docs/journal/bkm/2026-06-14.md:39,57`). CFO panele çoğunlukla telefondan baktığı için modal-tabanlı analiz mobilde erişilemez durumda.

B-48 kararı (mağaza kartları `<a href>` sayfa-nav) bunu mağaza kartları için çözdü ve SSR-güvenli çalıştığı doğrulandı (`Home.razor:614` `StoreRow` gerçek `<a href>`; `0758c9c`/`8928ddc` commit). Ancak TOPLAM/E-ticaret kartları hâlâ modal (`@onclick => _modalTot/_modalEtic`), kategori→ürün drill ise `AppRankBars.OnRowClick`/`AppDataTable` accordion (ikisi de SignalR-bağlı). Bu plan, B-48 desenini Home'un kalan kartlarına yayar; modalleri kaldırıp içeriklerini ayrı sayfalara taşır; drill'i **SignalR'sız** (URL query param + server-render) hale getirir.

## 2. Scope

### Kapsam dahili

- Home (`/`) düzenleme: `_modalTot`/`_modalEtic` modalleri kaldır, ilgili kartları `<a href>` sayfa-nav yap.
- Yeni `/toplam` sayfası: mevcut `_modalTot` içeriği (3 mağaza + online birleşik kategori dağılımı) + kategori→ürün drill (SignalR'sız, query param).
- Yeni `/magazalar` sayfası: 3 mağaza yan yana karşılaştırma. "Mağaza Toplam" kartı buraya nav.
- `/tahmin` zenginleştirme: hesap adımları (YoY taban, MoM ivme, kalan gün) + mağaza/kategori tablo. Home'da tahmin kartı zaten özet (`Home.razor:128` `<a href="tahmin">`) — değişmez, sadece hedef varlığına bağlılığı gözden geçir.
- E-ticaret kanal drill: `_modalEtic` içeriği zaten `/eticaret` sayfasında var (`Eticaret.razor:44-47` kanal AppRankBars). E-ticaret kartı `<a href="eticaret">`'e bağlanır; ayrı `/etic-kanal` sayfası AÇILMAZ (mevcut sayfa yeterli).
- Kategori→ürün drill'in SignalR'sız çözümü (alternatif analizi → Bölüm 3 karar).

### Kapsam dışı (scope creep engeli)

- **Mağaza detay (`/magaza/{id}`) modallerinin** (`_modalUrun`/`_modalOdeme`/`_modalKamp`) SignalR'sız'a çevrilmesi — bu plan SADECE Home redesign'ı. Mağaza detay drill'i B-47 (cert/tunnel) ile birlikte ayrı ele alınır. (Not Bölüm 4'te.)
- B-47 cert/Cloudflare tunnel çözümü — altyapı işi, ayrı backlog maddesi. Bu plan tunnel'sız da mobilde drill çalışmasını sağlar (URL-nav fallback), tunnel'ı beklemez.
- Yeni SQL metrik/köprü keşfi — tüm query'ler mevcut (aşağıda doğrulandı). Yeni sema kaydı GEREKMEZ.
- AppRankBars/AppDataTable component'lerinin yeniden yazımı.
- Masaüstü davranışının değişmesi — masaüstünde SignalR çalışıyor; redesign mobil-öncelikli ama masaüstünü bozmamalı.

### Etkilenen dosyalar (tahmin)

- `dashboard/Components/Pages/Home.razor` — `_modalTot`+`_modalEtic` ve ilgili `@code` (OpenUrun, booleans, `_modalUrun`) kaldır; TOPLAM kartı/Tümü butonu `<a href="toplam">`, E-tic kartı `<a href="eticaret">`, "Detaylı analiz" butonu `<a href="toplam">`. (~50 satır net azalış.)
- `dashboard/Components/Pages/Toplam.razor` — **YENİ**. `@page "/toplam"`. Birleşik kategori (3 mağaza + opsiyonel online) AppRankBars + kategori→ürün drill (query param server-render).
- `dashboard/Components/Pages/Magazalar.razor` — **YENİ**. `@page "/magazalar"`. 3 mağaza yan yana net/fiş/sepet/WoW/hedef karşılaştırma; her kart `<a href="magaza/{id}">`.
- `dashboard/Components/Pages/Tahmin.razor` — hesap adımları bloğu (YoY taban → ivme → tahmin → pace, kalan gün) + mağaza tablo zenginleştir.
- `dashboard/Components/Layout/MainLayout.razor` — gerekiyorsa sidebar/btm-nav link kontrolü (yeni sayfalar menüye eklenmeli mi? → Bölüm 7 Adım kararı).

**Tahmini boyut:** 2 yeni sayfa + 3 düzenleme = 5 dosya / ~350-450 satır (yeni sayfalar ~120-160 satır/sayfa, Home net azalır).

### Query katmanı — yeniden kullanım vs yeni (DOĞRULANDI)

| İhtiyaç | Mevcut metod | Yeni gerek? |
|---|---|---|
| `/toplam` birleşik kategori | `Queries.GetPeriodAsync` → `PeriodSummary.Stores[].Kategori` (mağaza×kategori, modal'da `SelectMany.GroupBy` ile birleşiyor — `Home.razor:174-177`) | **Hayır** — aynı birleştirme `/toplam`'a taşınır |
| `/toplam` kategori→ürün drill | `RefQueries.GetUrunlerAsync(kategori, mekanId=0, start, endExcl)` (`RefQueries.cs:215`) | **Hayır** |
| `/magazalar` 3 mağaza yan yana | `Queries.GetPeriodAsync` → `PeriodSummary.Stores[]` ZATEN 3 mağaza döndürüyor (`Queries.cs:94` `foreach mid in {4477,1,4478}` → her zaman 3 `StoreCard`: net, fis, atv, gerPct, iade, kategori[], wow) | **Hayır** — tek çağrı 3 mağazayı verir |
| `/tahmin` zenginleştirme | `Queries.GetTahminAsync(bugun, mekanId)` → `TahminSonuc(TahminAy, YoYTaban, IvmePct, Tahmin, Alt, Ust, Mtd, MtdPace, Yeterli, Seri[])` (`Queries.cs:311`); Tahmin.razor zaten toplam+3 mağaza çekiyor | **Hayır** — tüm alanlar mevcut, sadece UI'da gösterilmeyen YoYTaban/IvmePct/Mtd/MtdPace tabloya açılır |
| E-ticaret kanal | `Queries.GetPeriodAsync` → `PeriodSummary.Etic[]`; `/eticaret` zaten gösteriyor | **Hayır** |

**Sonuç: SIFIR yeni query metodu, sıfır yeni SQL, sıfır yeni sema kaydı.** Tüm veri mevcut metodlardan geliyor. Bu, "sessiz yanlış rakam" riskini minimuma indirir (yeni SQL yok = yeni undercount/sign-hatası yüzeyi yok).

## 3. Alternatifler — Kategori→Ürün Drill'in SignalR'sız Çözümü (KRİTİK KARAR)

Drill mobilde ölü kalmasın diye, kategoriye tıklayınca ürün listesinin **SignalR olmadan** gelmesi gerekiyor. Üç seçenek:

### A: Native `<details>`/accordion ile ürünleri sayfada inline render
**Açıklama:** `/toplam` ilk yüklenirken her kategori için ürünleri de çekip `<details>` içine SSR ile basmak. Tıklama = tarayıcı-native disclosure (JS/SignalR gerekmez).
**Reddetme sebebi:** `GetUrunlerAsync` her kategori için TOP 100 ürün + 5 stok join'i çalıştırıyor (`RefQueries.cs:226-270`, ağır sorgu). 8-15 kategori × bu sorgu = ilk yükleme 10-20 sn + dev HTML. CFO "Özlüce geç açıldı" diye zaten şikayetçi (B-49). Tüm ürünleri peşin çekmek kabul edilemez yavaş.

### B: Modalleri koru, sadece mobilde "gerçek cert" (Cloudflare tunnel) ile SignalR'ı çalıştır
**Açıklama:** Hiçbir şey değiştirme; B-47 tunnel çözümünü bekle, modal+SignalR mobilde çalışsın.
**Reddetme sebebi:** Kullanıcı tüneli 2× reddetti (`journal 2026-06-14.md:62`). Plan harici altyapıya bağımlı kalır, redesign'ın kendisi bloke olur. Ayrıca onaylanmış karar (16.06) açıkça "modal kaldırılacak, `<a href>` sayfa-nav" diyor — bu alternatif kararı ihlal eder.

### C: Query param + server-render (SEÇİLEN)
**Açıklama:** `/toplam` kategori satırı = `<a href="toplam?kat=Oyuncak">` (gerçek HTML link, SignalR gerekmez). Sayfa `[SupplyParameterFromQuery] string? Kat` parametresini okur; `Kat` doluysa `OnParametersSetAsync`'te `GetUrunlerAsync(Kat, 0, _start, _endExcl)` çağrılır ve ürün listesi **aynı sayfada SSR** render edilir (kategori listesi üstte, seçili kategori ürünleri altta veya seçili kategori vurgulu). `Kat` boşken sadece kategori listesi. Ürün listesi `AppDataTable` ile basılır AMA accordion (30/90/360g detay) yine SignalR-bağlı — ürün satırında 90g badge + Sub'da stok adedi SSR görünür; derin accordion masaüstünde çalışır, mobilde badge yeterli sinyal verir (kritik bilgi: kaç gün yeter, zaten badge'de).
**Sebep:** B-48'in kanıtlı `<a href>` SSR-güvenli desenini birebir izler. Tek kategori sorgusu (peşin değil, talep üzerine), navigasyon = tarayıcı GET → yeni SSR render, SignalR'a sıfır bağımlılık. Mobilde tıklama çalışır. Masaüstünde de aynı kod çalışır (SignalR olsa da query-nav kullanılır, basit). Yeni query gerekmez (`GetUrunlerAsync` mevcut).

**Not (accordion alt-detay):** `AppDataTable` accordion (`Details` slot, `_open` HashSet toggle, `@onclick` — `AppDataTable.razor:67`) SignalR-bağlı. `/toplam`'da ürün listesinde accordion'u **bırakıyoruz** ama mobilde çalışmayacağını kabul ediyoruz — kritik sinyal (badge: ~Ng yeter / tükendi / durgun) accordion açılmadan SSR'da görünür (`Home.razor:412` `UrunStok`). 30/90/360g kırılımı "nice-to-have", masaüstü-only. Bu, scope'u şişirmeden (her hücreyi query-param yapmadan) %90 değeri SSR'da verir. İleride gerekirse 2. seviye `?kat=X&urun=Y` query param eklenebilir — bu plan kapsamı dışı.

## 4. Riskler

| Risk | Etki | Olasılık | Mitigation |
|---|---|---|---|
| **Birleşik kategori rakamı modal'dakinden sapar** (sessiz yanlış rakam) | yüksek | orta | `/toplam` birleştirme mantığı modal kodunun (`Home.razor:174-177` `SelectMany→GroupBy→Sum`) BİREBİR kopyası olmalı. Done criteria: aynı dönem/aynı gün için `/toplam` kategori toplamı = eski modal toplamı = `PeriodSummary.Fiziksel` (`Home.razor:179` `net @Tl(_data.Fiziksel)`). Manuel mutabakat zorunlu. |
| **`?kat=` query param ile SQL injection** | yüksek | düşük | `GetUrunlerAsync` `kategori`'yi parametreli (`@kat`, `RefQueries.cs:249,281`) kullanıyor — string concat yok. Query param doğrudan Dapper parametresine gider, güvenli. Yine de `Kat` değeri kategori listesindeki bir değerle eşleşmiyorsa boş liste göster (whitelist davranışı). |
| **Kategori adında Türkçe karakter/boşluk URL'de bozulur** (`Oyuncak`, `Kırtasiye`, `Hediye Çeki`) | orta | orta | `<a href>`'te `Uri.EscapeDataString(kat)` kullan; `[SupplyParameterFromQuery]` Blazor otomatik decode eder. Test: "Hediye Çeki" gibi boşluklu/Türkçe kategori ile drill. |
| **Yeni sayfalar menüye eklenmeden orphan kalır** (sadece kart-nav ile erişilir) | düşük | orta | Karar: `/toplam` ve `/magazalar` btm-nav'a EKLENMEZ (5 slot dolu, `journal:25`), sadece Home kart-nav'dan erişilir — bu KASITLI (drill-down sayfaları). Geri dönüş `<a href="">` (Home) veya tarayıcı geri. Done criteria'da geri-nav teyidi. |
| **Mağaza detay modalleri (kapsam dışı) hâlâ mobilde ölü** | orta | yüksek (zaten böyle) | Bu plan onları çözmez (scope dışı). Açıkça belirt: B-47 ile birlikte ayrı plan. Bu redesign en azından Home'u tam SSR yapar. |
| **Boş dönem (veri yok gün) `/toplam`/`/magazalar`'da çökme** | orta | düşük | `GetPeriodAsync` boş dönemde `Stores[]` 3 kart sıfır-değerle döner (`Queries.cs:96` `r?.Net ?? 0`). `AppRankBars`/`AppDataTable` boş listede "Veri yok" gösterir (`AppRankBars.razor:26`). Yeni sayfalar aynı null-guard'ı kullanmalı. |
| **İade sign / dönem penceresi yeni sayfada yanlış kopyalanır** | yüksek | orta | Dönem hesabı (`_period` switch, `start/endExcl`) Home'dan (`Home.razor:285-291`) BİREBİR kopyalanır; iade sign zaten SQL'de (`IIF(DocumentsTypeId=3,-1,1)`, `Queries.cs:27`) — UI'da sign yok, kopyalama riski düşük. AppPeriodPills paylaşılır. |
| **Masaüstü grid bozulur** (yeni 3-kart yan yana mobilde taşar) | düşük | orta | Mevcut responsive sınıf desenini (`grid-cols-1 lg:grid-cols-3`, `Tahmin.razor:50`) kullan. 390px teyit (CFO mobil). |

## 5. Done Criteria

- [ ] `/toplam` sayfası açılıyor; birleşik kategori dağılımı gösteriyor; toplam = eski `_modalTot` toplamı = `_data.Fiziksel` (manuel mutabakat, en az 1 dönem için rakam eşleşmesi belgeli).
- [ ] `/toplam?kat=<Kategori>` ürün listesini SSR render ediyor (SignalR kapalıyken — HTTP'den test: `http://192.168.1.61:5112/toplam?kat=Oyuncak` drill çalışır).
- [ ] Türkçe/boşluklu kategori (`Hediye Çeki` veya `Kırtasiye`) ile `?kat=` drill doğru ürünleri getiriyor (URL encode teyidi).
- [ ] `/magazalar` sayfası 3 mağazayı yan yana gösteriyor; her kart `<a href="magaza/{id}">` ile detaya gidiyor; net/fiş/sepet/WoW değerleri Home'daki mağaza kartlarıyla aynı.
- [ ] Home'da `_modalTot`/`_modalEtic` ve ilgili `@code` (OpenUrun, `_modalUrun`, `_selKat`, `_urunler`, `_urunLoading`) kaldırıldı; TOPLAM/Tümü → `<a href="toplam">`, E-tic → `<a href="eticaret">`, "Detaylı analiz" butonu → `<a href="toplam">`. Home'da hiç modal kalmadı.
- [ ] `/tahmin` hesap adımları bloğu (YoY taban → MoM ivme → tahmin, kalan gün, MTD pace) gösteriyor; rakamlar `TahminSonuc` alanlarıyla tutarlı.
- [ ] **Build yeşil:** `cd dashboard && dotnet build` 0 error. `npm run build:css` (yeni arbitrary class varsa).
- [ ] **Smoke (masaüstü):** `/`, `/toplam`, `/toplam?kat=X`, `/magazalar`, `/tahmin` hepsi render, geri-nav çalışıyor.
- [ ] **Smoke (mobil/SSR):** HTTP'den (SignalR'sız simülasyon) tüm kart-nav + `?kat=` drill tıklanabilir.
- [ ] **silent-failure-hunter taraması:** yeni `Toplam.razor`/`Magazalar.razor` + Home değişikliği — boş catch, sessiz fallback, null-coalesce ile gizlenen sıfır yok.
- [ ] **Renk/UI:** hardcode hex YOK (`grep -rn "#[0-9a-fA-F]\{6\}" dashboard/Components/Pages/Toplam.razor Magazalar.razor` boş); DaisyUI semantic token (`text-error`/`text-success`/`from-primary` vb.) `renk-standardi.md`'ye uygun.
- [ ] TODO.md güncellendi (B-48 kapanış + bu plan adımları); journal'a özet.

## 6. Rollback Planı

- Her adım ayrı commit (`feat(bkm): ... (plan: 11)`). Sorun çıkarsa `git revert <commit>` — yeni sayfalar (Toplam/Magazalar) bağımsız dosya, revert temiz.
- Home değişikliği geri alınırsa modaller geri gelir (eski `_modalTot`/`_modalEtic` kodu git history'de). Home revert'i, yeni sayfa revert'inden BAĞIMSIZ yapılabilir — ama Home'da kart `<a href="toplam">` kalıp `/toplam` silinirse 404 olur. Sıra: önce yeni sayfalar (Adım 2-3), Home değişikliği EN SON (Adım 5). Rollback'te ters sıra: önce Home geri, sonra sayfalar.
- DB/migration YOK — schema değişmiyor, rollback sadece kod.
- Routing: yeni `@page` route'ları çakışmıyor (`/toplam`, `/magazalar` mevcut route'larda yok — `Glob` ile teyit: Home/Tahmin/Magaza/Eticaret/Envanter/Musteri/Gorevler/Operasyon/Asistan/Sadakat).

## 7. Adımlar / İçerdiği TODO maddeleri

> Bağımlılık sırası: **query yok (hepsi mevcut) → yeni sayfalar önce → Home en son** (Home `<a href>`'leri hedef sayfa var olmadan 404 vermesin).

1. [ ] **P11-1** **Hazırlık + mutabakat tabanı.** Mevcut `_modalTot` birleştirme mantığını (`Home.razor:174-177`) ve `_data.Fiziksel` değerini 1 dönem için not al (referans rakam — `/toplam` bununla mutabık olacak). Dönem hesabı + AppPeriodPills paylaşım deseni teyidi. Yeni query GEREKMEDİĞİNİ doğrula (Bölüm 2 tablosu). **Veri doğrulama:** seçili gün için eski modal kategori toplamı = `_data.Fiziksel` rakamını kaydet.

2. [ ] **P11-2** **`/toplam` sayfası — kategori dağılımı (drill'siz önce).** `Toplam.razor` oluştur: `@page "/toplam"`, `AppPeriodPills`, `GetPeriodAsync` çağrısı, birleşik kategori `AppRankBars` (modal kodunun birebir kopyası: `Stores.SelectMany(s=>s.Kategori).GroupBy(k=>k.Ad).Select(Sum).OrderByDescending`). Geri butonu `<a href="">`. **Veri doğrulama:** P11-1'deki referans rakamla mutabakat — `/toplam` toplam kategori = `_data.Fiziksel` (aynı gün). Sapma varsa DUR, birleştirme mantığını P11-1 notuyla satır satır karşılaştır.

3. [ ] **P11-3** **`/toplam` kategori→ürün drill (SignalR'sız, Alt C).** Kategori satırlarını `<a href="toplam?kat=@Uri.EscapeDataString(k.Ad)">` yap (AppRankBars yerine veya `OnRowClick` yerine link-render). `[SupplyParameterFromQuery] string? Kat`; doluysa `GetUrunlerAsync(Kat, 0, _start, _endExcl)` → ürün `AppDataTable` (badge SSR). **Veri doğrulama:** `?kat=Oyuncak` ürün cirosu toplamı ≈ kategori barındaki Oyuncak değeriyle tutarlı (drill = kart kuralı, `RefQueries.cs:210-213` notu). Türkçe/boşluklu kategori (`Hediye Çeki`) ile encode testi. SignalR-kapalı (HTTP) tıklama teyidi.

4. [ ] **P11-4** **`/magazalar` sayfası — 3 mağaza karşılaştırma.** `Magazalar.razor`: `@page "/magazalar"`, `AppPeriodPills`, `GetPeriodAsync` → `Stores[]` (zaten 3 mağaza). Yan yana kart grid (`grid-cols-1 lg:grid-cols-3`): net/fiş/sepet/WoW/hedef%; her kart `<a href="magaza/{MekanId}">`. Geri `<a href="">`. **Veri doğrulama:** her mağazanın net/fiş/WoW değeri Home mağaza kartındaki (`Home.razor:77` StoreRow) ile AYNI (aynı `GetPeriodAsync` kaynağı → identik olmalı; sapma = kopyalama hatası).

5. [ ] **P11-5** **Home redesign — modalleri kaldır, kart-nav bağla.** `_modalTot`/`_modalEtic` `<Modal>` blokları + `OpenUrun`/`_modalUrun`/`_selKat`/`_urunler`/`_urunLoading`/`_modalTot`/`_modalEtic`/`_modalUrun` alanları sil. "Tümü" butonu → `<a href="toplam">`; "Mağaza Toplam" kavramı için Mağazalar başlığındaki nav → `/magazalar` (veya ayrı kart); E-tic kartı `@onclick` → `<a href="eticaret">`; GunOzeti "Detaylı analiz" butonu (`Home.razor:504`) `@onclick=>_modalTot` → `<a href="toplam">`. **Veri doğrulama:** Home render, hiç modal yok, tüm kartlar tıklanınca doğru sayfaya gidiyor (404 yok). `dotnet build` 0 error.

6. [ ] **P11-6** **`/tahmin` zenginleştirme.** `Tahmin.razor`'a hesap adımları bloğu: YoY taban (`_t.YoYTaban`) → son-3-ay MoM ivme (`_t.IvmePct`) → tahmin (`_t.Tahmin`), MTD (`_t.Mtd`) + doğrusal pace (`_t.MtdPace`) + kalan gün (`DaysInMonth - Today.Day`). Mağaza tablo (zaten var, `Tahmin.razor:50` — gerekiyorsa kategori satırı). **Veri doğrulama:** gösterilen tahmin = `YoYTaban × (1 + ivme)` (`Forecast.Hesapla`, `Queries.cs:387`) — UI hesabı yeniden yapmaz, `TahminSonuc` alanlarını gösterir (tek kaynak).

7. [ ] **P11-7** **Menü/routing kontrolü.** `/toplam`+`/magazalar` btm-nav'a EKLENMEZ (kasıtlı, drill sayfaları) — sadece teyit: `MainLayout.razor` link listesinde çakışma/eksik yok. Sidebar'a (masaüstü) eklenmeli mi → kullanıcıya AÇIK SORU (Bölüm AÇIK SORULAR).

8. [ ] **P11-8** **Doğrulama + denetim (test adımı).** `dotnet build` + `npm run build:css` yeşil. silent-failure-hunter taraması (`Toplam.razor`, `Magazalar.razor`, Home diff). Renk hardcode grep boş. Masaüstü smoke (tüm route + geri-nav). **Mobil/SSR smoke:** HTTP'den `?kat=` drill + kart-nav tıklanabilir (B-47 cert beklemeden). Mutabakat rakamları (P11-2, P11-4) belgeli.

9. [ ] **P11-9** **TODO + journal.** B-48 `[x] KAPALI` işaretle (kanıt: commit hash); plan adımları TODO senkron; journal'a özet (`docs/journal/bkm/2026-06-16.md`).

> TODO.md'ye P11-1…P11-9 maddeleri Faz altına eklenir; plan ve TODO senkron.

## 8. İlişkili

- Önceki plan: `plans/10-dashboard-icerik-genisleme.md`, `plans/09-dashboard-rafine.md`, `plans/08-apexcharts-migration.md`
- Journal: `docs/journal/bkm/2026-06-14.md` (B-47/B-48 kök neden, SignalR/cert kanıtı), `docs/journal/bkm/2026-06-16.md` (bu oturum)
- Kurallar: `.claude/rules/renk-standardi.md` (DaisyUI token), `.claude/rules/sql-server-conventions.md` (iade sign, DMY), `.claude/skills/asistan-ui/SKILL.md`
- TODO: B-47 (cert/tunnel — bu plana bağımlı DEĞİL), B-48 (mağaza kart nav — bu plan kapatır), B-49 (mağaza detay perf — ilgili değil)
- Agent: doğrulama için `silent-failure-hunter` (opus), kod review Blazor/C# için `code-reviewer` (sonnet)

## 9. KARARLAR (AskUserQuestion 16.06 — netleşti)

1. **Giriş noktası = 2 buton.** Mağazalar başlığı yanına: "Karşılaştır" → `/magazalar`, "Kategoriler" → `/toplam`. Mevcut "Tümü" butonu bu iki butonla değişir. (P11-5 buna göre.)
2. **`/toplam` = V1 mağaza-only.** Mevcut `_modalTot` mantığının BİREBİR kopyası (3 mağaza birleşik, online HARİÇ). **Sıfır yeni SQL/sema.** Online kategori sonraki sürüme ertelendi (TODO'ya not).
3. **Sidebar'a EKLE.** Masaüstü sidebar'a `/toplam` + `/magazalar` linkleri eklenir (P11-7 güncellendi: btm-nav HAYIR, sidebar EVET).

## 10. Onay

- [x] Plan kullanıcıya gösterildi
- [x] Geri bildirim alındı (kararlar Bölüm 9'da)
- [x] Onay alındı: 16.06 Fikri ("sırayla yapalım") → P11-1…P11-8 uygulandı, smoke geçti
