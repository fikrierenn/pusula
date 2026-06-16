# TODO — sqlserver-mcp-server (Multi-Project)

Aktif yapılacaklar ve backlog. Bu dosya 400 satırı aşarsa tarihli konular ilgili `docs/journal/<proje>/`'a taşınır.

> **Format:**
> - Her ana başlık bir proje (`### BKM`, `### MCP Server (kod)`, `### CrossProject`).
> - Proje altında **BIRLESIK ONCELIK SIRASI** — Faz 0 (bugün), Faz 1 (bu hafta), Faz 2 (bu ay), Faz 3 (çeyrek).
> - Madde başında **kısa ID**: `B-NN` (BKM), `M-NN` (MCP), `C-NN` (CrossProject), `BL-NN` (Belinza), `Y-NN` (YonetIQ). Commit mesajlarında ve journal'da referans.
>
> **Yaşam-döngüsü (plan-12 WS-1):** madde durum modeli `open [ ] → stale (≥30 gün dokunulmadı) → archive`. Stale ≠ otomatik aksiyon; `session-handoff` curator-check işaretler, kullanıcı onayıyla `## Arşiv`'e taşınır. **Silme yok** (git history korur). consolidate-sema skill dry-run raporlar.

---

## Yapılanlar

### 2026-06-16 Oturum 6 — Kumbara keşfi + iç-kart tek filtre (plan-18) + müşteri raporları FİŞ bazlı (CFO direktifi)
- **B-96** müşteri kazanım/kart stat smoke ✅ · **Kumbara = RefundReasons Id=17 indirim tipi** keşfi (işlem-bağı kullanıcıda, 17.06)
- **plan-18** iç-kart tek kanonik filtre (`IcKartFiltre.Sql`/`SqlCols`) → 9 müşteri sorgusu; isim+tel(599/699)+elle liste tek tanım (B-100)
- **/sadakat LLM yorumu** (B-101) · **kartlı/kartsız FİŞ düzeltme** 5.627→529.428 kartsız fiş (B-102) · ParetoRow bigint fix
- **B-103 CFO direktifi:** tüm müşteri raporları FİŞ bazlı (Fatura/Sınav/Personel hariç) + belirgin rozet; kural `sql-server-conventions.md`'ye yazıldı
- Build yeşil, /musteri + /sadakat canlı doğrulandı. Kod commit BEKLİYOR (3 bucket).

### 2026-06-16 Oturum 5 — plan 13→17 + tahmin motoru + KDV-hariç + fiş drill (~30 commit)
- **plan-13** Genel Bakış redesign ✅ · **plan-14** tahmin ay-seçimi+kayıt+MAPE+takvim etmenleri ✅
- **plan-15** Python tahmin motoru + öğrenen katman ✅ (`scripts/forecast/` 6 modül, 6 model ensemble, backtest MAPE %7,5, ForecastOkuService + dashboard, run_forecast.bat + schtasks 10:00)
- **plan-16** tüm dashboard KDV+kargo-hariç ✅ (28 sorgu, headline -%7-9, sema 14.06 KDV-dahil kararı süperseded)
- **plan-17** Python eksik portlar: WP-1 fiş drill+termal-fiş ✅ · WP-3 saat fiş+ciro ✅ · WP-4 AppSozluk sözlük ✅ (WP-2 lokasyon ⏳)
- iç-kart elle işaretleme ✅ (IcKartService) · 2 skill (sema-sorgu, forecast-yorum) + 1 agent (sql-denetci) ✅
- müşteri kazanım+kart stat (build yeşil, **smoke bekliyor**)

### 2026-06-16 — E-ticaret direkt JOKER + perf + recovery + B-48 (6 commit)
- E-ticaret 10 sorgu linked ODAKJOKER → **192.168.40.70 DİREKT** (Db.OpenJokerAsync, .env JOKER_HOST). Kategori `J_ITEMS.DERINSIS_LOGOGRUP`=Kategori3 grain (0.6s vs 4.1s). Kategori→ürün drill + kategori yıl trendi yığılmış grafik (AppStackedBarChart) + il akordiyon. commit b792f4e.
- Kampanya brüt **spc fan-out fix** (N indirim satırı/ürün → brüt şişiyordu) + **GetDetay 7 sorgu paralel** (B-49 ikinci tur ~3.4s→1.2s). commit 609f3dd.
- **Telefon circuit auto-recovery** (/healthz poll + sunucu dönünce reload). commit 689e348.
- **B-48** mağaza kartı `<a href>` SSR-güvenli nav. commit 8928ddc.
- Context7 MCP kuruldu (.mcp.json, untracked — restart+onay bekliyor). Genel Bakış redesign kararları alındı (B-75).

### 2026-06-15 Oturum 3 — Sayfa yükleme süresi göstergesi
- `PerfState` scoped servis + MainLayout footer rozeti (⏱ sayfa+süre, <2sn yeşil/2-5sn sarı/>5sn kırmızı) + 8 sayfa wiring. commit e3360a3. **Smoke test bekliyor.** Mobil header rozeti açık soru.

### 2026-06-15 — Kanonik maliyet + WMS depo + ölü stok raporu + perf (~22 commit)
- **Tek maliyet sistemi:** gece job `MaliyetRaporu-Ceren` şelalesi keşfi (son 5 alış faturası → ORT_ALIS → sonraki) → `sema/metrics.yaml:birim_maliyet`. GetMarj fatAyr-AVG → kanonik (Kitap %30,6).
- **Kanonik depo = WMS palet** (`depo.paletUrnTnm`, 4,38M) — `stokSonAltDepo` mekan=12 (2,14M) EKSİK. `sema/bridges.yaml:wms-depo-stok`. GetUrunler drill depo'su WMS'e geçti.
- **Ölü stok ürün raporu (E4):** `scripts/olu_stok_excel.py` (`--kategori`/`--sadece-olu`) — ürün-grain, job şelalesi + canlı stok. Kitap 98K SKU=65,9M, ölü 30,4M. KATALOG.md E4.
- **Perf:** Envanter progressive load (marj ~40s arka plana, sayfa 40s→5s) · GetMarj ürün-başı ön-agg (40s→10s, rakam birebir aynı) · ölü stok drill 90g tara · gTarih<90g filtresi.
- **Runtime fix'leri:** GetMarkaRotasyon (ehTutarN + CAST int) · GetDepoWms (DerinSISBkm prefix) · DepoWmsTrend DateTime · ODAK Envanter'den tamamen kaldırıldı.
- ⚠️ İşe yaramayan: `BKM_STOKLAR_MALIYETLI` stok kolonları BAYAT (sadece ORT_ALIS) · `irsHrk.ehMlyt` çöp.

### 2026-06-14 Oturum 5 — Mockup özellikleri + AI/LLM + Tahmin + Faz 1 (~40 commit)
- AI Günün Özeti → yerel LLM (qwen2.5-3b, işaret-inversiyon fix) · bildirim merkezi global bar (NotifState + App.razor global rendermode) · ürün drill kaç-gün-yeter 30/90/360g + stok dağılımı 5-konum (FSM/Özlüce/İst.Yolu/Depo12/ODAK) · modal tek-seviye+44px✕ · dokunma geri bildirimi.
- 2 skill: dashboard-icerik (ekle) + dashboard-oneri (öner). Tarama → plan-10 (B-53..B-72, 3 faz).
- **Faz 1 TAMAM:** B-54 pace-line · B-53 mağaza trend · B-73 Hedef Tahmin (YoY×ivme) + /tahmin sayfası · B-56 COD il · B-57 kasiyer delta · B-55 saat×gün heatmap.
- İade fix: Tahmin irsHrk net = satış [1,4,100] − iade [3,5,101] (sema kanonik).
- B-58/B-65 → Faz 3 /sadakat'a taşındı. Sırada: Faz 2 veya Faz 3 (derin CRM sadakat — kullanıcı isteği).

### 2026-06-14 — B-41 kargo çekirdek + grafik UX + PWA/mobil app
- B-41 çekirdek: il teslimat (takvim+iş günü) · aylık çıkış + gün drill · COD iade maliyeti. Çıkış İŞ GÜNÜ (4,14→2,79g) + **veriden otomatik tatil** (resmi+dini+grev, API/hardcode reddedildi). queries.yaml+sema.
- Grafik UX: chartjs-plugin-datalabels (donut % / bar değer), oran hover-hint, mobil tooltip intersect:false, '4.2B'→'4.215' fix.
- **PWA + mobil app**: manifest/ikon/SW + alt tab-bar (btm-nav lg:hidden, masaüstü bozulmaz) + LAN HTTPS (mkcert 192.168.1.61:5443).
- ⚠️ Açık: mobil HTTPS drill çalışmıyor (güvensiz cert→SignalR yok) → B-47. 18 commit.

### 2026-06-13 — Dashboard DaisyUI literal + mağaza detay (B-40) + kampanya derinlemesine
- Tüm 7 sayfa DaisyUI/Tailwind literal (custom köprü sıfır), drill modal DaisyUI native, renk standardı kuralı, panel tarih etiketleri.
- B-40 mağaza detay `/magaza/{id}`: KPI+UPT+ödeme grup(banka drill)+kampanya(grup drill)+kategori. 13 commit (9eeb470→1f2142a).
- **Kampanya fiş-detay doğrulama → 2 gerçek hata fix**: 3al2öde indirimi IsValid=1 köprüsü + DocType IN(1,2,6,7,8) zorunlu (iptal kalem/iade Diğer'i şişiriyordu). Dashboard=MCP birebir.
- `scripts/build_3al2ode_belge_excel.py` (belge listesi Excel). sema: UPT, encore-kampanya-kalem, encore_odeme_grup, kampanya IsValid+iade kritik kuralı.

### 2026-06-08/09 — Oturum 3: Kapı sayıcı + işgücü + GM Dashboard
- ✅ Kapı sayıcı (FSM) → dönüşüm %51, işgücü üçgeni (trafik×PDKS×dönüşüm), yatırım gerekçesi (~3M ₺ fırsat). `scripts/kapi_sayici_analiz.py`, `isgucu_trafik_ucgen.py`, pitch raporu.
- ✅ E5 GMROI doğrulandı (karzarar pymssql).
- ✅ **GM Dashboard** `scripts/gm_dashboard.py` — tek sayfa, dönem seçici, her panelde drill (ürün embed, müşteri/sipariş --serve), lokasyon çoklu-seçim, terim sözlüğü, ciro-vs-envanter scatter. Canlı server.
- 🔑 **KÖK DÜZELTME:** stkKod≠barkod → kategori/marka/ciro-env hepsi irsHrk.ehstkID. Oyuncak "ölü stok" yanlış alarmı düzeldi (gerçek ciro 9,14M). Kalıcı kural yazıldı.
- 10 commit. Detay: `docs/journal/bkm/2026-06-08.md` (Oturum 3).

### 2026-06-08 — GM rapor sistemi (günlük pano G0-G7 + envanter E1-E6 + ABC + skill)
- ✅ **Günlük pano G0-G7** kuruldu, tümü MCP-doğrulandı (07.06.2026). Birleşik toplam, GM panosu (UPT/WoW/YoY/MTD), ödeme, iade, kategori, saat, anomali, e-ticaret. Harita: `sorgular/INDEX.md`.
- ✅ **Envanter verim E1-E6** (Plan 05 tamamlandı): snapshot + devir hızı + sell-through (adet bazlı, COGS gerekmez) + E5 GMROI (SSMS, karzarar). Sınav Okulları hayalet tüm raporlardan dışlandı.
- ✅ **ABC analizi (A5)** Pareto 80/20: A %25 SKU→%80 ciro, C %40 SKU→%5.
- ✅ `/gm-rapor` skill + `sorgular/gm-rapor/KATALOG.md` iş haritası + deep-research (perakende KPI best-practice, 16 doğrulanmış iddia).
- ✅ MCP CTE/ORDER BY limitleri `.claude/rules/sql-server-conventions.md`'e kalıcı kural.
- 🔑 **Bulgu:** E-ticaret cironun %61'i (07.06: online 3,02M > fiziksel 1,93M) — brief sadece fizikseli gösteriyor. İst.Yolu zayıf (WoW −%18,8, iade %3,5, Hazırlık Kit. yarı). FSM UPT 3,38 (düşük sepet).
- 22 commit. Detay: `docs/journal/bkm/2026-06-08.md`.

### 2026-04-27 — Oturum 3: MCP CWD bug + Mayıs %50 kampanya scope (handoff)
- ⚠️ **MCP CWD bug** tespit: `claude_desktop_config.json`'da `cwd` yok → dotenv `.env` bulamıyor → `localhost:1433` fallback.
- ✅ Config-level fix dosyaları yazıldı: `claude_desktop_config.FIXED.json`, `fix-mcp-config.ps1`, `fix-mcp-config.bat`.
- ⏳ **Pending kullanıcıdan:** Claude Desktop tam restart (sistem tepsisi → Quit → tekrar aç).
- ✅ **BKM Mayıs %50 kitap kampanya tahmini TAM SCOPE'LANDI** — 4 karar onaylı (3 mağaza, hibrit baz May25×Apr26/Apr25, 3 senaryo, Excel). Execution restart sonrası başlayacak — bkz B-NEW-01..06.
- 📋 Detay: `docs/journal/_crossproject/2026-04-27.md` (Oturum 3) + `docs/journal/bkm/2026-04-27.md` (kampanya scope + RESUME).
- 🔁 **Yarın için trigger phrase:** "mayıs kampanyası" / "kitap %50 tahmin" / "kampanya tahminine devam".
- ✅ **PortalHUB MCP eklendi** (Oturum 3 ek): `src/services/database.ts` named instance desteği + `claude_desktop_config.FIXED.json`'a `portalhub` MCP entry + `D:\Dev\reporthub` trusted folder. Deploy için: `npm run build` → `fix-mcp-config.bat` → Claude Desktop restart.

### 2026-04-27 — Oturum 2: B-01/03/04 + 3 commit + handoff
- ✅ İlk 3 commit atıldı: `7fed866 feat(mcp)`, `7f90d3b chore(crossproject)`, `4c61365 docs(bkm)` — 261 dosya total.
- ✅ **B-01** `scripts/send_mail.py` UnicodeEncodeError fix (UTF-8 stdout + `✓` → `[OK]`).
- ✅ **B-03** `send_brief.bat` dinamik tarih (her hafta Pazartesi'sini PowerShell ile hesaplıyor).
- ✅ **B-04** `scripts/register-scheduled-task.ps1` yazıldı (kullanıcı tarafından çalıştırılacak).
- ✅ Hook fix: `_archive*.md` skip + LF satır sonu + `.gitattributes`.
- ❌ **B-02** brief.html üretimi: SQL bağlantısı kapalı (Cowork sandbox→localhost:1433), sonraki Pazartesi'ye ertelendi.
- Detay: `docs/journal/_crossproject/2026-04-27.md` (Oturum 2 bölümü).

### 2026-04-27 — Oturum 1: atlasops session/memory yapısı adaptasyonu (crossproject)
- Multi-project iskelet kuruldu (`.claude/` + `docs/journal/<proje>/` + handoff skill + hooks).
- SESSION_LOG.md tarihli journal'lara parçalandı (6 dosya), orijinal arşive taşındı.
- TODO.md (bu dosya) Faz yapısıyla başlatıldı.
- Detay: `docs/journal/_crossproject/2026-04-27.md`.

### 2026-04-21 — Session 5 devam (bkm)
- SsmsExcelExporter (C# WinForms + ClosedXML, 2 hotkey) yazıldı.
- Nisan 2026 3Al2Öde HTML kampanya raporu üretildi.
- Briefing mail otomasyonunun ilk kurulumu (`scripts/send_mail.py`, `send_brief.bat`).
- Detay: `docs/journal/bkm/2026-04-21.md`.

### 2026-04-20 — Session 5 başlangıç (bkm)
- IsValid keşfi + 7 SQL düzeltmesi.
- İndirim kolon ilişkisi çözüldü (DiscountTotalDirect).
- 3 mağaza × 3 grupta doğrulama formülleri.
- Detay: `docs/journal/bkm/2026-04-20.md`.

---

### 2026-06-12 — Blazor GM Dashboard sıfırdan + e-ticaret status FIX + rapor skill L/M/K
- Blazor Server + Dapper dashboard 5 sayfa (Genel Bakış/E-ticaret/Operasyon/Envanter/Müşteri), tüm panel Python birebir, drill modal + Chart.js. (~30 commit)
- **KRİTİK FIX (712f440):** e-ticaret NET status filtresi yanlıştı (%70 eksik). 3004/3006 normal aşama, iade DEĞİL. Doğru: NOT IN (1001,1006,1007,3000,4000). Dashboard+brief+Python+sema düzeltildi.
- gm-rapor skill L/M/K modları (kargo/bekleyen/hedef/kampanya/kafe) + sema 4 yeni köprü.
- Kalan: B-40 mağaza 5 panel · B-41 JOKER kargo SQL entegre · B-42 Python pano emekli · B-43 kafe POS.

## Devam Eden (aktif)

### BKM — BIRLESIK ONCELIK SIRASI

#### 🌅 SABAH HIZLI KAZANIMLAR (17.06 handoff — curated, açık backlog'dan ~30dk-1sa'lik işler)
> Önce bunları hızlıca temizle (düşük efor/risk, bağımsız), sonra büyük iş (Kumbara/B-91/B-81).
- [ ] **HK-1 mobil "Diğer" menü** (UX, ~20dk) — Mağazalar/TOPLAM/Sadakat mobilde erişilemiyor (btm-nav 5 sekme, sidebar 11). Çözüm: `MainLayout.razor` btm-nav'a 6. öğe **"Diğer" (⋯, icon `menu`)** = NavLink değil, `<label for="bkm-drawer">` (drawer toggle) → drawer tüm `NavRegistry.Items` gösteriyor zaten. Masaüstü değişmez. Tek dosya.
- [ ] **HK-2 B-99 sql-denetci agent test** (~15dk) — `sorgular/04-karzarar/` dar kapsamda agent çalıştır, bulgu+format doğru mu. (Yeni fiş-bazlı denetim maddesi #12 eklendi — onu da test eder.)
- [ ] **HK-3 B-86 GetDepoWms 0-guard** (~15dk) — `RefQueries.Envanter.cs` GetDepoWmsAsync boş-sonuç→0 "Depo Bugün": gerçek-0 vs veri-yok ayırt et (nullable + "veri yok" göster).
- [ ] **HK-4 B-89 ApexCharts var(--p)** (~30dk) — hardcode hex → CSS-var (context7 doğruladı `colors:['var(--p)']` çalışıyor). `AppAreaChart`/`AppBarChart` default `#4063e6`, axis renkleri → DaisyUI token. renk-standardi uyumu.
- [ ] **HK-5 C-13 .gitignore build artifact** (~10dk) — `sorgular/03-kampanya/RaporApp/bin|obj`, `*.dll/*.exe/*.pdb` → .gitignore + `git rm --cached`.
- [ ] **HK-6 B-16/B-17 Express DB doc** (~15dk) — CLAUDE.md'de `[DOLDUR]`: Express (192.168.40.66\SQLEXPRESS) amacı + hangi DB'ler + ALLOWED_DATABASES daralt kararı.
> Not — **B-82** (kasiyer ABS formül): `Queries.cs:157` kasSql doğrulandı (zaten -VatTotal vardı, false-positive); `:349` GetKasiyerDelta asimetri DÜZELTİLDİ (17.06). Kalan: iade-branch `ABS(DiscountTotal)` tutarlılığı — düşük öncelik, MCP mutabakatıyla doğrula.

#### Faz 0 — Yarın (Blazor dashboard devam — 12.06 oturumundan)
- [x] ✅ **B-96 müşteri kazanım/kart stat SMOKE** — KAPALI 16.06. /musteri runtime doğrulandı: kazanım area chart SVG çiziliyor (Haz 2026 ~8.381 yeni · 13 ay 223.896), kart oranı bar (ÖZLÜCE %68,4 · FSM %51,8 · İst.Yolu %53,0 · Toplam %58,7), AppSozluk (Home) native details kapalı-başlar/açılır. Konsol hatası yok. (plan-17, cf9e7ab)
- [ ] **B-97 plan-17 WP-2 lokasyon filtresi** — `GetInventoryAsync` ~10 noktada `ehMekan IN (1,4477,4478)` hardcoded → 5-lokasyon (FSM/Özl/İst/Depo12/ODAK) toggle param + "stok=şube+Depo, ODAK hariç" (Python urunler_query_sql). Dedike, mutabakatlı.
- [~] **B-98 manuel indirim TİPİ + Kumbara (16.06 REVİZE)** — DÜZELTME: manuel indirim TİP LİSTESİ var → `EncoreMerkez.dbo.RefundReasons` Type=1 (Personel, BSE, Anlaşmalı Kurum, 3Al2Öde, Bkm Kart, Sınav Koleji, **Okul Kumbara Projesi=Id 17**…). AMA seçilen tip işlem kolonuna BAĞLANMIYOR (RefundReasonId sadece Type=0; PriceChangeReasonId=0; Sales.RefundReasonId boş; Audits/Jobs/Details'te yok; EncoreMerkez view/SP yok). Kumbara indirim raporu OTOMATIK geliyor (POS e-postası: Mağaza×Tarih → brüt/ind/net/%/fiş/ürün). 🔜 **Kullanıcı 17.06 kaynak tabloyu verecek** → işlem-bağını bağla → İndirim Kaynak kırılımı paneli (SPC.Source 0=kampanya/1=manuel/2=legacy/3=kupon) + Kumbara satırı + RefundReasons referans liste. sema/codes.yaml'a kaydedildi (status: teyit bekliyor). `scripts/_kumbara_scan.py` izlenmiyor — temizle/sil.
- [ ] **B-99 sql-denetci agent test** — yeni agent yüklendi (sonraki oturum aktif), denenmedi. `sorgular/04-karzarar/` dar kapsamda doğrula (bulgu üretiyor mu + format).
- [x] ✅ **B-100 iç-kart tek kanonik filtre (plan-18)** — KAPALI 16.06. `IcKartFiltre.Sql` (WHERE NOT-IN subquery) + `SqlCols` (aggregate-CASE, Customer-join) → 9 müşteri sorgusuna uygulandı (RefQueries RFM/kazanım/kart-oranı/drill + SadakatQueries WinBack/Pareto/Kartlı/RfmGeçiş/TekrarAlış). İsim(Mağaza/Kumbara)+tel(599/699)+elle liste tek tanım. Smoke: /musteri kart-oranı İst.Yolu %53→%50,6 (AKL/RGR/AGH 599-kartlar düştü), /sadakat 5 panel hatasız. Build yeşil. Pre-existing fix: ParetoRow.Dilim int↔NTILE bigint → `CAST(... AS int)`.
- [x] ✅ **B-103 TÜM müşteri raporları FİŞ bazlı + görünür etiket (16.06 CFO direktifi)** — KAPALI 16.06. Kural: `sql-server-conventions.md` § Müşteri Raporları Fiş Bazlı. Sayım/frekans (RFM, RfmGeçiş, TekrarAlış, kart-oranı, kazanım) → `DocumentsTypeId=1`; ciro (Pareto, WinBack, Kartlı) → `(1,3)` iade-sign'lı. Fatura(2)/Personel(6,7)/Sınav(8) HARİÇ. Etki: Pareto dilim1 527M→139,7M (Sınav çıktı), kart-oranı saf fiş. /musteri + /sadakat başlığında belirgin "📄 Fiş bazlı (perakende · Fatura/Sınav hariç)" rozeti. Build yeşil, ikisi de doğrulandı.
- [x] ✅ **B-102 sadakat kartlı/kartsız FİŞ düzeltme** — KAPALI 16.06. Eski: `CustomersId>0` + belge(1,2,3,6,7,8) → "Kartsız" 5.627 fiş/262M (Sınav=8 266M kirliliği, anonim eksik). Yeni: perakende(1,3), kartsız=anonim(CustomersId=0) dahil, metrik sepet/fiş. Kartlı 474.615 fiş/675₺ · Kartsız 529.428 fiş/539₺. KartliRow.AtvMusteri→AtvFis. (RefModels+SadakatQueries+Sadakat.razor)
- [x] ✅ **B-101 /sadakat LLM yorumu** — KAPALI 16.06. `LlmService.SadakatYorumUret` (GunOzeti deseni: veri özeti→akıcı Türkçe yorum+aksiyon, uydurma-yok kuralı) + Sadakat.razor koyu yorum kartı (arka plan çağrı, spinner, `RendererInfo.IsInteractive` guard → prerender çift-inference engeli). Pipeline doğrulandı (model yüklendi+üretiyor); CPU-sandbox'ta yavaş, kullanıcı makinesinde Home özeti gibi. Pareto: ilk %10 müşteri = ciro %71,5 (konsantrasyon riski).

#### Çatı self-development (17.06 — "Hermes gibi kendini geliştirsin")
- [x] ✅ **H-12 yetenek-uret meta-skill** — KAPALI 17.06. `.claude/skills/yetenek-uret/SKILL.md`: skill/agent/hook/rule SİSTEMATİK üret + mevcut GÜNCELLE. footprint-ladder rung seçimi → tip-bazlı scaffold (skill frontmatter / agent model-tier+rol / hook BKM-adapte+settings-wire / rule core-etiket) → kayıt → test → onay. İNSAN-TETİKLİ (otonom daemon DEĞİL — plan-12 §5; Claude çağrı-bağımlı). Döngü: `/learn` (çıkarım) + yetenek-uret (üret/güncelle) + `consolidate-sema` (bakım). git-revert'lenebilir.
> NOT: Tam otonom self-modification REDDEDİLDİ (tehlikeli + Claude çağrı-bağımlı + BKM daemon yok). "Self-improving" = insan-onaylı üçlü döngü.

#### Hermes disiplin aktivasyonu (16.06 — "katı disiplin, mekanik enforcement")
> plan-12 7/7 WS yapıldı ama çoğu PASİF (ben-uygular). Mekanikleştirildi:
- [x] ✅ **H-09 disiplin hook'ları aktif** — KAPALI 16.06. (1) `session-start.sh` journal-path bug FIX (`docs/journal/bkm/` — eskiden flat→README; curator-check de bundan görünmüyordu) + curator-due (≥7g) kontrolü + her-oturum disiplin yüzeyi (commit-eşik/keşif-SQL-arşiv/fiş-bazlı/footprint). (2) `pre-commit-antipattern.sh` BKM-adapte (BLOK=şifre/ex.Message/bare-except/async-void; UYAR=print/DateTime — CLI script print'i bloklamaz) + settings.json PreToolUse(Bash) **wire** (dormant'tı). Test: git-commit-dışı/staged-yok → exit 0.
- [ ] **H-10 (ERTELE — bilinçli) WS-2 faz-2 fiziksel rule taşıma** — on-demand rule'ları `topic/` + `paths:`/skill-inject → gerçek token tasarrufu. RİSK: compact-survival (rule post-/compact düşer → sessiz konvansiyon kaybı = BKM'nin EN korktuğu sessiz-yanlış-rakam). Tek-kullanıcıda token ağrı değil → değer<risk. plan-12 §4 test-gate'li. Hook'lar zaten disiplini aktifledi → faz-2 GEREKMİYOR. Açılırsa: ayrı plan + compact-smoke şart.
- [ ] **H-11 (ERTELE) WS-1 telemetri sidecar** — sema/skill kullanım sayacı. plan-12 reddi: tek-kullanıcıda over-engineering, manuel yargı yeter.

#### Mimari / kod-bütünlüğü debt (16.06 full-scan — 4 ajan + roslyn deneme + file-size)
> Build 0/0, gerçek antipattern/circular yok, SQL-Razor temiz ayrık. Aşağıdakiler debt (compiler hatası değil). roslyn MCP init olmadı (repo'da .sln yok — navigator başka solution'a bağlı).
- [~] **M-10 DRY (kısmi — bilinçli)** — ✅ `LlmService` 3× inference bloğu → `Infer(prompt,maxTokens,temp)` helper (45 satır deduplike, 17.06). ⏸️ Mekan dict (1 satır×2, isim değişmez) · `Q<T>` lambda (1 satır×2) · `LoadEnv()` (dedup = yeni dosya ya LlmService→Db tuhaf coupling) → **BIRAKILDI**: trivial/stabil dup'ın dedup maliyeti > faydası (footprint-ladder/simplicity-first). Divergence riski ~sıfır.
- [x] ✅ **M-11 GetRfmGecisAsync hard-coded tarih → kayan pencere** — KAPALI 17.06. `DECLARE @bugun/@anchor1=bugün-3ay` + `DATEADD(MONTH,...)` → seg1=[bugün-15ay..bugün-3ay], seg2=[bugün-12ay..bugün]. Her gün otomatik güncel. UI başlık+dipnot dinamik. Build yeşil, MCP sliding-window sane (6→6 122K, 2-Sadık→Şampiyon 2571).
- [x] ✅ **M-12 kargo/il linked-server → direkt JOKER** — KAPALI 16.06. `Queries.cs:169-189` kargoSql/ilSql `ODAKJOKER.*` 4-part + ana `conn` → `dbo.*` 2-part + `jconn` (zaten açık, satır 61). JOKER linked server kaldırılmıştı (kullanıcı) — bunlar straggler'dı. Build yeşil.
- [~] **M-13 file-size split (kısmi)** — ✅ RefQueries.cs 638→**334** + `RefQueries.Envanter.cs` 314 (partial class, envanter/ürün/ops/marj; DI+çağıran değişmez, build yeşil) 17.06. ⏸️ Home.razor 566 + Tahmin.razor 504 → code-behind GEÇERSİZ (`@code` içinde markup RenderFragment → düz .cs derlenmez). **Sub-component extraction** gerek (markup chunk'ı child .razor'a) — dedike Tier-3, dikkatli. (300+ debt: Queries 472, Eticaret 411, Magaza 377, EticQueries 318, Musteri 304; generate_brief.py 678.)

#### RFM / Müşteri tarafı — eklenecekler backlog (16.06 not, B-96 smoke sonrası)
- [ ] **R-1 Ay-seçimli kazanım drill** — kazanım grafiğinde aya tıkla → o ayın yeni müşterileri listesi (ad/tel/ilk fiş/ilk tutar). Şu an 13-ay seri sadece adet.
- [ ] **R-2 Kart oranı dönem seçimi** — kart-fiş oranı şu an 30g sabit. Günlük/haftalık/aylık pill ekle.
- [ ] **R-3 E-ticaret kazanım** — yeni müşteri kazanım şu an YK (yazarkasa) only. JOKER CUSTOMERREF ilk-sipariş ile e-tic kazanım serisi ekle (ayrı evren).
- [ ] **R-4 Kohort retention matrisi** (= B-66) — aylık edinim kohortu × N-ay-sonra geri dönüş % (heatmap). "Ocak'ta gelenin %X'i 3. ay hâlâ alıyor."
- [ ] **R-5 Segment geçiş matrisi UI** — `SadakatQueries.GetRfmGecisAsync` SQL VAR (B-67), dashboard'da panel YOK. 3-6 ay önceki segment → bugünkü segment akışı (kim Şampiyon'dan Risk'e düştü).
- [ ] **R-6 Müşteri LTV / yaşam boyu değer** — segment başına ort. yıllık harcama × tahmini ömür. Kart sahibi vs kartsız ATV farkı (GetKartliAsync var, kazanca bağla).
- [ ] **R-7 Churn / tekrar-alım oranı** — ilk alıştan sonra 2. alış yapan % (aktivasyon), 90g sessizleşen (churn riski) adedi/trendi.
- [ ] **R-8 Müşteri fiş drill polish** — fiş listesinde indirimli/kampanyalı fiş işareti (rozet), ET sipariş durumu, geri-navigasyon UX (şu an seviye state).
- [~] **B-40** Mağaza detay sayfası `/magaza/{id}` — ✅ panel + drill commit 13.06 (de4f214…1f2142a). Ödeme üst-grup+banka drill · kampanya 3al2öde-ayrı/Diğer-toplu drill · UPT · iade · kategori→ürün. IsValid+iade fix doğrulandı (dashboard=MCP). **Kalan:** dönüşüm (G8 kapı sayıcı CSV — FSM-only, Özlüce/İst.Yolu sayıcı bekliyor).
- [~] **B-41** JOKER kargo SQL — ✅ ÇEKİRDEK 14.06 (18 commit): il teslimat (takvim+iş günü) · aylık çıkış trendi + gün drill · COD iade maliyeti. **İş günü** çıkış (takvim 4,14→2,79g) + **veriden otomatik tatil** (resmi+dini+grev, sıfır bakım). queries.yaml+sema. **Kalan:** #5-7 (günlük detay→ay-drill ile karşılandı · v2 · çıkış-teslim→il'de var) düşük değer. Kargo kar/zarar YAPILMAZ (KargoMaliyetiniHesapla remote çağrılamaz).
- [ ] **B-47 ⚡ DRILL MOBİL FIX** — mkcert güvensiz cert (Android kırmızı X) → WSS/SignalR kurulmuyor → mobil HTTPS'te interaktivite/drill YOK (sayfa SSR açılır, tıklama ölü). Kanıt: HTTP'den (http://192.168.1.61:5112) drill çalışmalı. **Çözüm: Cloudflare tunnel** (gerçek cert → WSS+PWA install+standalone+drill hepsi). Kullanıcı tüneli 2× reddetti ama mkcert Android'de yetmiyor. VEYA iç sunucu+Let's Encrypt. **(YENİ 14.06)**
- [x] ~~**B-48** Mağaza kartı nav `<a href>` SSR-güvenli~~ — ✅ 16.06 commit 8928ddc. Mağaza kartları + Tahmin + "incele" `@onclick NavigateTo` → gerçek `<a href>` (SignalR'sız çalışır, mobil "açılmıyor" kökü). Modal'lar (TOPLAM/E-tic kategori) interaktivite-bağlı kaldı → B-47. Kart birleştirme tam çözümü → **B-75 redesign**.
- [x] ~~**B-49** Mağaza detay PERF (paralel)~~ — ✅ 14.06 (649e346 sayfa-seviyesi WhenAll) **+ 16.06 commit 609f3dd** (GetDetayAsync İÇİ 7 sorgu hâlâ sıralıydı ~3.4s → her biri kendi bağlantısı + WhenAll → **~1.2s**). Rakam birebir aynı.
- [x] ~~**B-74 ⚡ PERF progressive-load**~~ — ✅ tamamlandı. Envanter ✅ 15.06. Eticaret ✅ 16.06 commit b792f4e (10 sorgu .70 DİREKT + LOGOGRUP 4.1s→0.6s). **16.06 Envanter darboğazı çözüldü (13.4s→1.2s algılanan):** (1) GetInventoryAsync 5 sorgu tek bağlantıda sıralıydı → her biri kendi bağlantısı + Task.WhenAll (B-49 deseni), WhenAll grubu **1.1s**; (2) GetMarjAsync (~9s maliyet şelalesi) `await` ile prerender'ı blokluyordu → `[StreamRendering]` eklendi, sayfa 1.2s'te stream'lenir, marj sonradan (mobil HTTP'de de, SignalR'sız). **Hipotez çürütüldü (todo-verification):** RfmGecis 494ms (ağır değil) + Stockout pre-agg 1092ms vs CROSS APPLY 1021ms (kazanç yok) → ikisi de DEĞİŞTİRİLMEDİ, gereksiz churn engellendi. Rakamlar birebir (11 kategori, stockout MCP eşleşti). **Kalan:** Sadakat 2.2s (kabul edilebilir, dokunulmadı).
- [x] ~~**B-75 ⚡ GENEL BAKIŞ REDESIGN (Tier-3)**~~ — ✅ 16.06 (`plans/11-genel-bakis-redesign.md`, uncommitted). (1) Home modaller kaldırıldı → Mağazalar başlığı 2 buton (Karşılaştır→/magazalar, Kategoriler→/toplam), E-tic kartı `<a href="eticaret">`, "Detaylı analiz"→/toplam — hepsi `<a href>` SSR-güvenli; (2) yeni **`/toplam`** sayfa (3 mağaza birleşik kategori `_modalTot` birebir + kategori→ürün drill `?d=&kat=` query-param SSR, SignalR'sız); (3) yeni **`/magazalar`** 3 mağaza karşılaştırma; (4) **/tahmin** hesap adımları bloğu (YoY taban→ivme→tahmin + MTD/kalan gün). Sidebar'a Mağazalar+TOPLAM eklendi. Build yeşil, CSS derlendi, smoke geçti (drill 100 ürün, mutabakat Fiziksel=kategori toplam %0,0017 fark=görüntü yuvarlama). **Karar: V1 mağaza-only** (online kategori ertelendi — yeni e-tic kategori SQL gerektirir). **(YENİ 16.06)**
- [x] ~~**B-76 sema kaydı**~~ — ✅ 16.06 `sema/bridges.yaml`: joker-direct-conn (.70 OpenJokerAsync), items-logogrup-kategori3 (`J_ITEMS.DERINSIS_LOGOGRUP`=Kategori3 metin, cross-server hop yok), encore-kampanya-kalem fan-out gotcha (spc N satır/ürün → SUM(sp.TotalPrice) N× şişer; indirim spc'den doğru, brüt/net ayrı CTE). + SEMANTIK_KATMAN.md insan senkron. YAML geçerli (32 köprü).

#### 🔁 Plan-12 Hermes Adaptasyon — KALAN WS (16.06, `plans/12-hermes-adaptasyon.md`)
> ✅ Yapılan: WS-1 (78c9060 sema/TODO yaşam-döngüsü), WS-4+WS-6 (86d903e agent rol + handoff anchor). Kalan workstream'ler her biri ayrı mini-onay (§10):
- [x] ~~**B-77** WS-2 NarrowWaist~~ — ✅ 16.06 commit 72d3f62. footprint-ladder.md + 7 rule on-demand etiketi + asistan-ui/dashboard-icerik skill referans + CLAUDE.md tier notu. Compact-survival korundu (paths: yok). Faz-2 fiziksel taşıma → B-93.
- [x] ~~**B-78** WS-5 ErrorClass~~ — ✅ 16.06. SqlErrorClassifier.cs (transient/fatal, 18456 auth-fatal) + Db.cs OpenWithRetryAsync (max-2 backoff, loglu, mevcut timeout birleşik) + _errors.py (pymssql is_transient+connect_with_retry) + generate_brief.py bağlandı + error-handling.md sınıflandırıcı bölümü. Build yeşil, Python OK, smoke 200. silent-failure-hunter auth-fatal yanlışsınıflama bulgusu düzeltildi. (send_mail SMTP=DB değil → kapsam dışı.)
- [x] ~~**B-79** WS-3 Registry-nav~~ — ✅ 16.06. `dashboard/Models/NavRegistry.cs` (NavItem record + Items + BottomNav/Sections) → MainLayout sidebar+btm-nav `@foreach` türetir. Yeni sayfa = tek satır, orphan riski yok (B-75 kökü). Build yeşil, smoke: sidebar 11 + btm-nav 5 + 2 grup, görsel birebir. (Razor `section` rezerve → `grp`.)
- [x] ~~**B-80** WS-7~~ — ✅ 16.06. test-discipline.md davranışsal-kontrat bölümü (snapshot/change-detector reddet → ilişki-invariant; BKM rapor: net=brüt−indirim). **Plan-12 TAMAMLANDI (7/7 WS).**

#### 🔬 Sistem Denetimi Bulguları (16.06, 4-ajan + Context7) — KOD DÜZELTME BEKLİYOR
> Denetim raporu journal 16.06 Oturum. Güvenlik TEMİZ (injection/secret/XSS yok). Aşağısı açık:
- [ ] **B-81 🔴 KRİTİK iade-netleme (~%0,9 ciro şişik)** — irsHrk sorguları `ehTip IN (4,100)` alıp iade `(101,5,3)` DÜŞMÜYOR: `RefQueries.cs` devir(84-88)/marka(115)/cve(312-317)/rotasyon(505-508)/marj(478) + EncoreMerkez `ReturnAmount` netleme `Queries.cs` katSql/skatSql + `MagazaQueries.cs` katSql + `RefQueries.GetUrunlerAsync`. sema `metrics.yaml net_ciro`/`encore_irshrk_mutabakat` zaten "DÜZELTME BEKLİYOR". **Her sorgu MCP eski/yeni mutabakatlı** düzeltme — dedike iş, aceleye gelmez. (En yüksek değer.)
- [ ] **B-82** ORTA — Kasiyer net `ABS(DiscountTotal)` formülü diğer sorgulardan farklı (Queries.cs:148-160, 333-341), çift-düzeltme riski → doğrula.
- [ ] **B-83** ORTA — exception sızıntısı `_error = ex.Message` UI'da (tüm sayfalar) → generic mesaj + detay logger'a.
- [ ] **B-84** ORTA — auth YOK (finansal + müşteri PII ağa açık). İç LAN/PWA bağlamı kabul ama karar gerek (basit auth?).
- [x] ~~**B-85** boş catch loglama~~ — ✅ 16.06. RefQueries SPLH + Envanter marj → `ILogger.LogWarning` (RefQueries'e ILogger inject, Envanter'a @inject). Operasyon WMS iç-catch ölüydü (WhenAll await sonrası ulaşılmaz) → kaldırıldı. Build yeşil.
- [ ] **B-86** ORTA — `GetDepoWmsAsync` boş-sonuç→0 "Depo Bugün" (RefQueries:399-410): gerçek-0 vs veri-yok ayırt edilemez.
- [x] ~~**B-87** ölü kod~~ — ✅ 16.06. Operasyon `_pColor` field + ölü OnAfterRender theme bloğu + Gorevler `OncSinif()` silindi. Build yeşil. (todo-verification: ikisi de grep ile doğrulandı.)
- [x] ~~**B-88** perf paralel~~ — ✅ 16.06. Home `GetHedefAsync` WhenAll'a dahil (ayrı sıralı await yerine). Müşteri `GetRfmAsync` yk+et her biri kendi bağlantısı + WhenAll (B-74 deseni). SQL birebir, build yeşil, smoke 200. (Not: Müşteri 4.3s'in çoğu prerender double-render = B-91 ayrı.)
- [ ] **B-89** DÜŞÜK — hardcode hex → ApexCharts CSS-var (**Context7 doğruladı: `colors:['var(--p)']` çalışıyor**, ilk denetimin "API kısıtı" sonucu YANLIŞ): `AppAreaChart`/`AppBarChart` default `#4063e6`, axis renkleri, `charts.js` PAL → `var(--p)/--er/--su`.
- [~] **B-90 → M-13 ile birleşti** (süperseded) — file-size split. ✅ RefQueries 638→334 (17.06). ⏸️ Home/Tahmin sub-component bekliyor. Sayılar M-13'te güncel; bu madde M-13'e bakar.
- [ ] **B-91 ⚡ Blazor prerender double-render — DETAYLI PLAN (17.06, context7 doğruladı)** 🔴 TUZAK VAR, dikkatli.
  **Problem:** prerender'lı InteractiveServer → `OnInitializedAsync` **2× çalışır** (1: statik prerender, 2: tarayıcı interactive). context7 (`/dotnet/aspnetcore.docs` blazor/components/lifecycle.md) birebir doğruladı. Masaüstünde TÜM sayfa SQL'i **çift** koşuyor (DB yükü 2×); mobilde genelde tek.
  **Mevcut rendermode:** GLOBAL `App.razor:25 <Routes @rendermode="InteractiveServer">` + 12 sayfada per-page `@rendermode InteractiveServer` (ikisi de prerender:true — aynı mod, çakışmıyor).
  **YOL 1 — `prerender:false` (REDDEDİLDİ):** App.razor Routes + 12 per-page'i tutarlı `InteractiveServerRenderMode(prerender:false)` yap. ⚠️ **Mobil B-47 REGRESYON**: SignalR flaky'ken (mobil PWA cert sorunu) şu an prerender en az SSR içerik gösteriyor; prerender'sız → boş "Yükleniyor" sonsuza. CFO mobil deneyimi bozulur. **YAPMA.**
  **YOL 2 — `PersistentComponentState` (DOĞRU, context7 örneği `blazor/state-management/prerendered-state-persistence.md`):** her sayfa: `@inject PersistentComponentState State` + `@implements IDisposable` + OnInit'te `if(!State.TryTakeFromJson<T>(key, out var restored)){ fetch } else { use restored }` + **sonda** `persistingSubscription = State.RegisterOnPersisting(Persist)` (race önler) + `Persist(){ State.PersistAsJson(key, data) }` + `Dispose(){ persistingSubscription.Dispose() }`. Prerender KORUNUR (mobil SSR içerik görür) + çift-fetch gider. DB 2×→1×.
  **PLAN:** Tier-3, TAZE oturum. Sayfa-sayfa (ağır önce: Home 8-sorgu · Müşteri RFM · Envanter). Her sayfa: uygula → build → smoke (masaüstü tek-fetch + **mobil SSR hâlâ görünür** + drill çalışır). 12 sayfa × N alan boilerplate — verbose ama mekanik. Mobil regresyon testi ZORUNLU (B-47 ile etkileşir).

#### ⏸️ Ertelenenler / Kısayollar (16.06 — normale çevrilecek, ATLANMAYACAK)
- [ ] **B-92** /toplam **online (e-ticaret) kategori** V2 — B-75'te V1 mağaza-only yapıldı; online kategori için yeni e-tic SQL (J_ORDER_DETAILS→J_ITEMS→DERINSIS_ID→urnKtgr2 veya LOGOGRUP) gerekir + ayrı doğrulama.
- [ ] **B-93** plan-12 WS-2 **faz-2** — konu-bazlı rule'ları fiziksel `.claude/rules/topic/` dizine taşı + skill-inject (gerçek system-prompt token düşüşü). **compact-survival smoke ZORUNLU** geçmeden yapma.
- [ ] **B-94** plan-12 WS-1 **telemetri** — sema/skill kullanım sayacı (`.usage.json` sidecar). Şimdilik manuel yargı; veri-temelli stale tespiti istenirse.
- [ ] **B-95** sema **last_verified geriye-doldurma** — şu an sadece encore-kampanya-kalem örnek aldı. Diğer <1.0 kayıtlar (bekleyen-siparis-il 0.9, hedef-kategori 0.95, salescampaign-sales 0.95, items-derinsis kontrol) dokunuldukça `last_verified` kazanmalı (toplu değil, footprint-ladder).
- [x] ~~**B-50 ⚡ MOBİL TASARIM POLISH**~~ — ✅ 14.06 commit 72aada5+48b4221 (KPI beyaz/kompakt + hedef guard, build:css .NET target). B-51 ile süperseded.
- [x] ~~**B-51 ⚡ APP DİLİ → WEB/BLAZOR UYARLAMA**~~ — ✅ 14.06 (cbefab3→0d2c0bc, ~24 commit). TÜM dashboard mobil-app dili: gradient hero CAROUSEL (AppKpiCarousel) + ikon-kart mağaza (trend WoW) + segment pill (AppPeriodPills) + fintech sparkline + **HTML progress (AppRankBars)** + accordion grid (AppDataTable). plan-08 (ApexCharts pilot → kullanıcı beğenmedi → HTML progress PİVOT) + plan-09 (5 iş: paralel/grid-oran/E-tic carousel/filtre/irsHrk). **irsHrk KDV mutabakatı:** fark %100=KDV(EncoreMerkez dahil/irsHrk hariç)+iade → drill EncoreMerkez net KDV-dahil (kart=drill), sema yazıldı. Shared: AppArea/Bar/RankBars/DataTable/KpiCarousel/PeriodPills.
- [x] ~~**B-52** Home TOPLAM/E-tic kategori modalları `<table>` → AppDataTable~~ — ✅ 14.06 commit 2e9dc88 (+ b42b60f Görevler/Asistan, + ef8e85e tap-feedback). Dashboard'da artık HİÇ `<table>` yok. Bu oturum ayrıca: AI Günün Özeti→yerel LLM (e68cf77), bildirim merkezi global bar (3077378), ürün drill kaç-gün-yeter 30/90/360g + stok dağılımı FSM/Özlüce/İst.Yolu/Depo/ODAK (507b8fa/958e0bc/6da84fa), modal kapatma UX (1b956c2). Skill: dashboard-icerik (75bd9b7) + dashboard-oneri (9a71835).

#### Dashboard İçerik Backlog — dashboard-oneri taraması (14.06). Seçilince `dashboard-icerik` ile uygula.

**🔥 Hızlı kazanım (S — mevcut sorgu varyasyonu, yeni tablo/köprü yok):**
- [x] ~~**B-53** Mağaza detay 30-gün ciro trendi~~ — ✅ 14.06 commit 1719bb9. MagazaQueries.GetTrendAsync (mekanID filtreli) + AppAreaChart. Özlüce 13.06=967.304 doğrulandı.
- [x] ~~**B-54** Hedef pace-line~~ — ✅ 14.06 commit 7befb53. Dikey çizgi=bugün beklenen %(gün/ay), geride/önde rozet, haftalıkta da hedef. Gün 14/30→%47.
- [x] ~~**B-73** Hedef Tahmin kartı (CFO yöntemi: YoY taban × MoM ivme)~~ — ✅ 14.06 commit e390c27. irsHrk net (tam geçmiş), GetTahminAsync + saf-C# Forecast.Hesapla. Geçen yıl aynı ay × son-3-ay YoY ivmesi + senaryo bandı ±σ + MTD pace. Haziran 51,34M (=30,98M×1,657) doğrulandı. Sınav sezonu YoY tabanda korunur. Yöntem hafızada [[bkm-hedef-tahmin-yontemi]].
- [x] ~~**B-55** Mağaza saat×gün ısı haritası~~ — ✅ 14.06. MagazaQueries.GetHeatmapAsync, gün=DATEDIFF%7 (deterministik DATEFIRST-bağımsız), primary-opacity hücre, son 60g. Hafta sonu+öğleden sonra zirve. **FAZ 1 TAMAM** (B-53/54/55/56/57 + B-73 + Tahmin sayfası /tahmin). B-58/B-65 sadakat metriği → Faz 3 /sadakat'a taşındı.
- [x] ~~**B-56** COD iade il haritası~~ — ✅ 14.06 commit 75d55c2. PAYDEFREF=-3+DCITY+CARGODELIVERYSTATUS=2, oran sıralı (HAVING≥20). Doğu illeri ~%17. AppDataTable.
- [x] ~~**B-57** Kasiyer önceki-döneme delta rozeti~~ — ✅ 14.06 commit 6f8b1de. GetKasiyerDeltaAsync (kasSql 2× + Magaza|Ad eşleşme). Yeşil/kırmızı delta badge.
- [x] **B-58** Tekrar satın-alma oranı (Frq>1 payı) ✅ 35d6195 — %40.1 KPI /sadakat carousel

**Orta (M — yeni sorgu/cross-db join):**
- [x] ~~**B-59**~~ ✅ 15.06 commit 3c8d32b — JOKER DERINSIS_ID→urnKtgr2 kategori mix, AppRankBars (Eticaret)
- [x] ~~**B-60**~~ ✅ 15.06 commit 7daf10f — depo.emirAyr toplama verimi, 14g trend + bugün KPI (Operasyon)
- [x] ~~**B-61**~~ ✅ 15.06 commit d2d829f — fatAyr OUTER APPLY brüt marj %, NOLOCK, Envanter sayfası
- [x] ~~**B-62**~~ ✅ 15.06 commit bf39b10 — aylık satılan vs kullanılan, net yükümlülük (Envanter). VOUCHERCODE e-tic hariç, Eylül 2025 anomalisi görünür.
- [x] **B-63** Marka alış-vs-satış dengesi (rotasyon matrisi) ✅ ebfbed9 — Top30 AppDataTable + birikim/erime badge (Envanter)

**Düşük:**
- [x] **B-64** E-ticaret sipariş durumu huni ✅ 1c1b162 — J_ORDERS.STATUS 6 aşama + badge (Eticaret)
- [ ] **B-65** Müşteri kayıp/risk segmenti 3-ay trendi → **Faz 3 /sadakat** (B-67 segment geçiş matrisi ile birlikte). Veri: ykSql 3× (t/t-30/t-60).

#### 🎯 Müşteri Sadakat Derinleştirme (kullanıcı isteği 14.06 — derin CRM/sadakat). [TIER 3 plan-first — yeni "Sadakat" sayfası olabilir]
> Veri tabanı: EncoreMerkez `Sales.CustomersId` + `DerinCrm.Customer` (Name/PhoneNumber/CardNumber) · e-tic `J_ORDER_CLIENTS.CUSTOMERREF` · mevcut RFM (C1-rfm). Tek köprü çözüldü (`DerinCrm.Customer.Id = Sales.CustomersId`).
- [ ] **B-66** Kohort retention matrisi — aylık edinim kohortu × N-ay-sonra geri dönüş oranı (heatmap). "Ocak'ta gelen müşterinin %X'i 3. ay hâlâ alıyor". En güçlü sadakat metriği. **(yüksek, L)**
- [x] **B-67** RFM segment geçiş matrisi ✅ 10b6121 — iyileşme/kötüleşme badge + geçiş tablosu (/sadakat)
- [x] **B-68** Win-back / reaktivasyon listesi ✅ 46089e4 — Top200 aksiyon listesi /sadakat sayfası
- [x] **B-69** Sadakat kartı analizi ✅ a88becc — kartlı vs kartsız ATV + fiş/müşteri karşılaştırma (/sadakat)
- [x] **B-70** Müşteri konsantrasyonu (Pareto) ✅ 46089e4 — %10'ar dilim kümülatif ciro /sadakat
- [x] **B-71** İlk-alış → 2. alış dönüşümü ✅ 35d6195 — ort. 49g KPI /sadakat carousel
- [ ] **B-72** Müşteri bazlı kategori afinitesi — "kitap alan müşteri kırtasiyeye de geçiyor mu" (çapraz-satış sinyali, sepet genişletme). **(düşük, L)**
- [x] ~~**B-42** Eski Python pano emekli~~ — ✅ 13.06: `scripts/gm_dashboard.py` SİLİNDİ (Blazor superset, 14 panel eşleşti + fazlası, cascade yok). briefings/* eski çıktılar GEÇMİŞ hafta (kullanılmaz) → dokunulmadı; gelecek brief generate_brief (status-fix sonrası) doğru üretir.
- [ ] **B-43** Kafe POS DB erişimi araştır — EncoreMerkez'de kafe yok, xlsx kanonik. Kafe ayrı POS sistemi nerede? **(YENİ)**
- [x] ~~**B-46** `tools/diskscan` native disk tarayıcı~~ — ✅ 13.06 commit 16f0caf. (1) optimize rebuild (42→37 sn), (2) .gitignore+kaynak commit, (3) C tarandı → cache D'ye yönlendirildi (npm/pip/yarn) + ~8,3 GB temizlendi (C 16→27,7 GB boş). D: 5,3→124 GB. MFT makine policy ile kapalı (err 50/1300) — dir-walk tavanı.

#### Faz 0 — Bugün (blocker'ları kaldır — 1-3 saat)
- [x] ~~**B-01** `scripts/send_mail.py` UnicodeEncodeError düzelt~~ — ✅ `[OK]` + `sys.stdout.reconfigure(encoding="utf-8")`. Gmail "Sent" doğrulaması: kullanıcı kontrol edecek (geçen hafta 20.04 11:19 mail muhtemelen gitti — hata print'teydi).
- [x] ~~**B-02** Bu Pazartesi (27.04.2026) `briefings/2026-04-27/brief.html` + `brief.txt` üret~~ — ✅ 28 Nis Salı sabahı **retroaktif** üretildi (SQL bağlantısı dünden geri geldi, MCP CWD fix uygulandı). Mail gönderildi (fikrieren@gmail.com + fikri.eren@bkmkitap.com), kullanıcı "ok geldi" onayladı. Brief: H17 Net 13,27M / WoW −%1,5 / 23 Nis Çocuk Bayramı patlama (3,4M tek gün) → 1 May Emek Bayramı sinyali.
- [ ] **B-21** Sonraki Pazartesi brief Task Scheduler ile otomatik tetikleme. ~~JOKER e-ticaret~~ ✅ 11.06 (B-29, commit 739ad0a). Kalan: kitapsepeti + Heykel + kafeler dahil edilmeli + scheduler kaydı (B-04).
- [~] **B-22** FSM kapı sayıcı entegrasyonu — **KISMEN ÇÖZÜLDÜ 08.06.2026.** Veri geldi (`sayiyo/sayiyo_*.xlsx`, geniş format, FSM 08.04→güncel günlük giriş). Tidy: `sayiyo/fsm_gunluk_trafik.csv`. **G8 dönüşüm çalışıyor** (`scripts/donusum_orani.py`: CSV giriş + EncoreMerkez fiş → günlük dönüşüm % + ₺/ziyaret). Doğrulama: 02-08.06 %51,0 (dashboard 10.738 ile birebir). FSM ~%50 sağlıklı. **KALAN:** (1) Özlüce + İst.Yolu sayıcı verisi yok, (2) trafiği SQL tabloya yükle (`bkm.MagazaTrafik`) → native join + brief KPI kolonu, (3) saat bazlı kırılım. **(GÜNCEL)**
- [x] ~~**B-03** `send_brief.bat` tarih güncelle~~ — ✅ DİNAMİK yapıldı, her Pazartesi'yi otomatik hesaplıyor (PowerShell `(Get-Date).AddDays(...)`). Bir daha güncelleme gerekmez.
- [x] ~~**B-35** EncoreMerkez stkID köprüsü~~ — ✅ 09.06 BULUNDU: `Products.Code`(int)=`urn.stkID` (%99,98). Join: SalesProducts.ProductsId→Products.Code=stkID→urn. Oyuncak 700K→10,96M doğrulandı. Kural yazıldı.
- [x] ~~**B-36** Dashboard devir/ölü sermaye hesap detayı~~ — ✅ 09.06 modallara Satılan/ay + Ort Stok adet + 'Hesap' (12×S÷O) kolonları + formül başlığı. Devir 0,15x artık şeffaf.
- [x] ~~**B-37** stkID düzeltmesi rapor dosyalarına~~ — ✅ 09.06 G4-kategori-magaza.sql + A6-marka-yayinevi.sql + generate_brief.py SQL_CATEGORY/TOTAL → Products.Code=urn.stkID köprüsü. G4 doğrulandı (Oyuncak 07.06 3,5k→491k, 140× düzelme).

#### Faz 0.5 — Mayıs %50 kitap kampanyası tahmini
> ⤵️ **ARŞİVLENDİ (17.06 curator)** — kampanya penceresi geçti (Nisan-Mayıs 2025/26). Detay `## Arşiv`'de. Geçerliliği geri gelirse (yeni kampanya) aktif Faz'a alınır + RESUME `docs/journal/bkm/2026-04-27.md`.

#### Faz 1 — Bu hafta (yüksek öncelik — ~5 gün)
- [ ] **B-04** `scripts/register-scheduled-task.ps1` çalıştır → Task Scheduler kaydı (her Pazartesi 09:00). **Tek görev mimarisi:** 14.05.2026'da `send_brief.bat` v5 self-healing yapıldı (brief.html yoksa `generate_brief.py` ile kendisi üretir → eski generator/sender yarış koşulu bitti, 11.05'te bu yüzden mail gitmemişti). `register-brief-generator-task.ps1` deprecated edildi (artık sadece eski `BKM-Brief-Generator` görevini kaldırıyor); `register-scheduled-task.ps1` çalıştırıldığında o eski görevi de otomatik temizler. **Kullanıcı sadece `register-scheduled-task.ps1`'i çalıştıracak.**
- [ ] **B-20** Pazartesi maili **fikri.eren@bkmkitap.com**'a SPAM'a düşüyor olabilir (4 kez gönderildi 20.04'te, kullanıcı "gelmedi" dedi). Kontrol: BKM webmail spam klasörü. Çözüm: BKM whitelist veya SPF/DKIM doğrulama veya gönderici adresini `fikrieren@gmail.com`'dan BKM SMTP'sine değiştirmek. **(YENİ)**
- [ ] **B-05** SsmsExcelExporter build & test (`dotnet publish -c Release -r win-x64`) — Ctrl+Shift+E + Ctrl+Shift+W çalışmalı.
- [ ] **B-06** `CampaignId = NULL` 389,4M ₺ indirim kaynak araştırması (Session 2'den beri açık).
- [x] ~~**B-07** Ürün bazlı maliyet/marj analizi — 3Al2Öde'nin gerçek kârlılık etkisi.~~ — ✅ 07.05.2026: `sorgular/04-karzarar/2026-05-07-gunluk-kar-zarar-maliyet-karsilastirma.sql` üretildi (plan: `plans/04-gunluk-kar-zarar-maliyet-karsilastirma.md`). Kitap kategorisinde günlük P/L, Maliyet = `fatAyr.ehTutarN / ABS(ehAdetN)`. **Kritik bulgu:** DerinSIS alış faturasında `ehAdet/ehAdetN` NEGATİF, `ehMaliyet` kolonu BOŞ — `ehTutarN/ABS(ehAdetN)` doğru formül. `irsHrk.ehMlyt` ve `fatAyr.ehMaliyet` BKM'de aktif kullanılmıyor. **06.05.2026 testi:** Net 544K ₺, Marj %22.5, Çocuk Kitabı %8 dikkat çekici (3al2öde etkisi).
- [x] ~~**B-23** Plan 04 v2 mağaza kırılımı~~ — ✅ 07.05.2026: `sorgular/04-karzarar/2026-05-07-gunluk-kar-zarar-irshrk-magazali.sql` üretildi. Satış kaynağı **irsHrk** (ehTip 1/4/100 satış, 3/5/101 iade), mağaza ID 1=FSM/4477=Özlüce/4478=İst.Yolu, 4 result-set (mağaza×kategori, genel, top 200 ürün, doğrulama). 06.05.2026 testi: FSM 255K marj %44, Özlüce 361K %43, İst.Yolu 77K %45 — toplam 693K marj (%44). Kalan v3 işleri: (a) JOKER e-ticaret, (b) önceki fatura snapshot, (c) eDvzKur çevrim, (d) stored procedure'a sarma. — bunlar **B-23a/b/c/d** olarak ayrı.
- [ ] **B-23a** v3: JOKER e-ticaret kanalı entegrasyonu (linked server ODAKJOKER.JOKER, J_ORDERS+J_ORDER_ITEMS).
- [ ] **B-23b** v3: Önceki alış faturası snapshot (fiyat trendi).
- [ ] **B-23c** v3: Yabancı para çevrim (fat.eDvzKur).
- [ ] **B-23d** v3: Stored procedure'a sarma (`bkm.sp_GunlukKitapKarZarar`).
- [ ] **B-25** CLAUDE.md veya `.claude/rules/session-protocol.md`'ye ekle: oturum başı ritüelinde **`sorgular/SEMANTIK_KATMAN.md`** zorunlu okuma listesine eklensin (ehTip kod sözlüğü, mekanID'ler, `ehTutarN = ehTutar - ehIndirim` mantığı bu dosyada). 07.05.2026 oturumunda atlandı, kullanıcı uyardı. **(YENİ)**
- [ ] **B-24** ADR-004 yaz: "DerinSIS alış faturası convention'ı: ehAdet NEGATİF + ehMaliyet=0" — bu kritik kural sql-server-conventions.md'ye eklendi mi kontrol et. **(YENİ)**
- [x] ~~**B-26** E5 GMROI doğrulaması~~ — ✅ 08.06 karzarar v7 pymssql ile koşuldu (SET DATEFORMAT dmy). Mayıs aylık GMROI: Gıda 0,23 · Kitap/Akademi 0,03 · TOPLAM 0,07/ay. Kitap kategorileri ölü sermaye (E4/ABC ile tutarlı). Tüm GM KPI sözlüğü artık doğrulandı.
- [ ] **B-27** G1 panosu (`10_00_gunluk-gm-panosu.sql`) 12 sn sürüyor — UPT için fiş-başı CROSS APPLY ağır. Günlük otomatik mail'e bağlanırsa UPT'yi ön-hesaplı/materialized tut. **(YENİ)**

#### Faz 2 — Bu ay (orta öncelik — ~10 gün)
- [x] ~~**B-28** RFM müşteri segmentasyonu~~ — ✅ 08.06.2026 `sorgular/gm-rapor/musteri/C1-rfm-segmentasyon.sql`. Şampiyon 8.923 (11K ₺/9,2 sip.) · Kayıp 335.512 (353M, reaktivasyon). + A6 marka/yayınevi + E7 weeks-of-supply kuruldu.
- [x] ~~**B-33** Stokta yokluk (stockout)~~ — ✅ 08.06 `gm-rapor/envanter/E8-stockout.sql`. Dergi %23,3 · Akademi %8,7 · Kitap %5,2 (hedef <%5). SKU bakiye≤0, son 30 gün satışlı.
- [x] ~~**B-34** SPLH (işgücü verimi)~~ — ✅ 08.06 `gm-rapor/operasyon/S1-splh-isgucu-verimi.sql`. Özlüce 3.786 ₺/saat · FSM 2.822 · İst.Yolu 2.793. PDKS Per_Grp1='MAĞAZALAR'+Per_Grp2 mağaza eşleşmesi (vrd gerekmedi).
- [x] ~~**B-29** Birleşik fiziksel+online **haftalık** brief~~ — ✅ 11.06 commit 739ad0a. generate_brief.py v1.1.0: SQL_ETICARET (J_ORDERS, net=iptal/iade hariç, ISO tarih) + weekly/monthly şablonlara 1b/3b bölüm + birleşik özet satır. Doğrulama hafta 01-07.06: online 19,1M (%65) / fiziksel 10,1M (%35). Linked server düşerse fiziksel-only + warning. (B-21'in JOKER ayağı da kapandı; kitapsepeti/Heykel/kafeler hâlâ yok.)
- [x] ~~**B-30** Haftalık P2-P8 verified-wire~~ — ✅ 11.06 commit 3bb01fa. `gm-rapor/haftalik/P2-P7` dinamik hafta penceresi; P2/P3/P5/P6 MCP canlı doğrulandı (hafta 01-07.06, brief ile çapraz tutarlı), P4/P7 SSMS pointer. 10_16_kasiyer.sql içeriği yanlıştı (kampanya trendiydi) → P6 sıfırdan. Yeni köprü: Sales.UsersId=Users.Id.
- [ ] **B-08** EncoreMerkez Products tablosu → DerinSIS urn kategori mapping (urn.stkID köprüsü).
- [ ] **B-09** Sales → fat/irsHrk bağlantısı (LinkedDocumentNo / ClosureNo / TransferHistory).
- [ ] **B-10** `bkm.HareketKanal_vw` view tasarımı — Sınav vs Perakende ayrımı.
- [ ] **B-11** 2026 yıllık tahmin (Sınav / Retail ayrıştırılmış).
- [ ] **B-12** H15 e-ticaret sorgularının arşivlenmesi (`sorgular/YYYY-MM-DD-*.sql`).
- [ ] **B-13** Önceki oturum e-ticaret trend raporu SQL'leri arşive: haftalık ciro/adet, günlük nabız, Top 20 organik, kanal kırılımı, kategori, yayınevi Top 15, sipariş durum, Echo of Silence forensic, YoY 2025, J_ITEMSBARCODE keşif.
- [ ] **B-14** Grok sinyallerini iç satış verisiyle cross-check (önceki sorgular 30s timeout — başlık-bazlı küçük sorgulara böl).

#### Faz 3 — Çeyrek (düşük öncelik / temizlik — ~15 gün)
- [ ] **B-45** [FİKİR — TIER 3 plan-first] **BKM-Asistan** (OpenClaw'dan esinlenme, 12.06): minimal AI asistan — Telegram bot + Claude API (tool use) + mevcut sema/Dapper/gm-rapor araçları. CFO telefondan "dün kargo/ciro ne oldu" yazar → Claude SQL/rapor aracıyla Türkçe cevap. Stack C# (.NET, Telegram.Bot + Anthropic SDK), dashboard ile tutarlı. OpenClaw'ın çekirdeği (kanal+agent+tool) — 15 kanal/sandbox/companion GEREKSİZ. Kurmadan önce: güvenlik (tek-kullanıcı auth), API maliyet, mimari plan. **(YENİ — şimdilik fikir, ileride)**
- [ ] **B-31** [TIER 3 plan-first] GM rapor dosyalarını (12 dosya, 7 klasör) `sorgular/gm-rapor/` altına taşı — skill/katalog/plan/INDEX referansları güncellenmeli. Şimdilik `sorgular/INDEX.md` tek-harita yeterli. **(YENİ)**
- [ ] **B-32** [TIER 3 plan-first] Günlük otomatik mail (G0-G7) — generate_brief gibi günlük pano, Task Scheduler 08:30. B-27 (UPT performans) önce çözülmeli. **(YENİ)**
- [ ] **B-15** `BKM-Mobil-App-Baremli-Sorgular.sql` (eski J_CLCARD versiyonu) deprecated → kaldır.
- [ ] **B-16** Express sunucusunun (192.168.40.66\SQLEXPRESS) kullanım amacı dokümante et — `CLAUDE.md`'de hâlâ `[DOLDUR]`.
- [ ] **B-17** Express'te hangi DB'ler var, `ALLOWED_DATABASES` daraltılmalı mı karar.
- [ ] **B-18** İki sunucu arası cross-server sorgu (linked server / OPENROWSET) ihtiyacı çıkarsa değerlendir.
- [x] ~~**B-19** ADR-001 yaz: "Multi-project journal yapısı"~~ — ✅ `docs/ADR/001-multi-project-journal.md` yazıldı.

### MCP Server (kod) — BIRLESIK ONCELIK SIRASI

#### Faz 0 — Bugün
- [/] **M-01** ⚡ **Config geçişi + Pusula rename — restart bekliyor (11.06):** Config'ler GÜNCELLENDİ: desktop config 3 server → `D:\Dev\sqlserver-mcp\dist\index.js` (env'ler korundu, yedek: `.bak-rename`); `.claude.json` proje anahtarları → `D:\Dev\pusula`; repo-içi 14 dosya path'i + package.json name=pusula; memory dizini kopyalandı (`D--Dev-pusula`). **KULLANICI YAPACAK:** (1) Claude'u tamamen kapat, (2) PowerShell: `Rename-Item D:\Dev\sqlserver-mcp-server pusula`, (3) Claude'u `D:\Dev\pusula`'da aç. **Restart sonrası ilk iş:** `SELECT @@SERVERNAME` smoke (3 server) → OK ise bu repodan `src/`+`dist/`+`node_modules/`+`tsconfig.json` sil (package.json kalsın, isim taşıyor).
- [ ] **M-01b** Yeni repo'ya GitHub remote + push. Açık işler artık orada: `D:\Dev\sqlserver-mcp\TODO.md` (CTE wrap fix M-04, ORDER BY M-05, test kapsamı M-03). C-NEW-01 (CWD fix) da oraya taşındı sayılır — yeni repo'da yapılacak.

#### Faz 1 — Bu hafta
- [ ] **C-NEW-01** ⚡ Kalıcı CWD fix: `src/index.ts` line 1 `import "dotenv/config"` → absolute-path dotenv load (`fileURLToPath(import.meta.url)` ile `__dirname`'den `.env` yükle). Sonra `npm run build` + restart + test (config'den cwd/env çıkarıp). Başarılıysa `fix-mcp-config.{ps1,bat,FIXED.json}` arşivlenebilir.
- [x] ~~**M-NEW-02** Named instance desteği~~ — ✅ `src/services/database.ts` patch'lendi: `MSSQL_HOST="HOST\\INSTANCE"` formatı parse + `instanceName` kullanılıyor + port instance varsa skip. Backward compatible. **Deploy:** `npm run build` gerekiyor.

#### Faz 2 — Bu ay
- [ ] **M-NEW-03** Plaintext password risk: `claude_desktop_config.FIXED.json` ve `fix-mcp-config.ps1` repo'da plaintext SA şifre içeriyor. `.gitignore`'a al veya `*.example.*` template versiyonu yap.

#### Faz 1 — Bu hafta
- [ ] **M-02** `src/tools/sp.ts` ve `src/tools/diagnostics.ts` üzerinde herhangi bir bug tespit edilmedi — gözden geçirme + test.

#### Faz 2 — Bu ay
- [ ] **M-03** `sql_query` timeout iyileştirmesi — büyük result set'lerde stream/pagination.
- [ ] **M-04** HTTP transport stabilitesi (Cowork/Workspace bağlantısı için cloudflared kalıcı tunnel).

#### Faz 3 — Çeyrek
- [ ] **M-05** `MAX_ROWS` env var dinamik — sorgu bazında override.
- [ ] **M-06** Yeni discovery tool: `sql_table_dependencies` (ilişkili tabloları otomatik çıkar).

### CrossProject — BIRLESIK ONCELIK SIRASI

#### Faz 1.5 — Semantik katman + ECC entegrasyon backlog (10.06 araştırma çıktısı)
- [x] **SK-01** `sema/` structured katman kuruldu (entities/bridges/codes/metrics/queries.yaml) + `sema-ogren` skill + `semantic-layer.md` rule. ✅ 10.06
- [x] **SK-02** queries.yaml golden-SQL kataloğu (8 doğrulanmış sorgu) + compat blok + ai_hints + kolon description (irsHrk). ✅ 10.06
- [ ] **SK-03** entities.yaml kalan kritik tablolara kolon `description` (Sales, J_ORDERS, emirAyr) — Wren MDL pattern.
- [ ] **SK-04** metrics.yaml type sistemi (`type: sum|ratio|derived` + numerator/denominator) — dbt MetricFlow pattern.
- [ ] **SK-05** metrics'e `sample_values` (sanity check referans değerleri) — LLM sonuç doğrulama zemini.
- [ ] **SK-06** SEMANTIK_KATMAN.md ↔ sema/*.yaml senkron taraması (15 Nis'ten stale; depo/e-tic bu oturum eklendi, eski bölümler YAML'a aktarılacak).
- [ ] **ECC-01** context-budget benzeri: session başında MCP/rule token maliyeti görünürlüğü (ECC skills/context-budget'tan uyarla).
- [ ] **ECC-02** Fact-Force Gate hook: bilinmeyen tabloya ilk sql_query öncesi sema/ + describe zorunluluğu (PreToolUse).
- [x] **ECC-03** planner agent + /learn komutu + Fact-Force Gate (before-major-change) + pre-compact hook — BKM'ye uygulandı; Operax+Mizan'a da aynı paket. ✅ 10.06
- [ ] **ECC-04** inventory-demand-planning skill'i incele → BKM talep tahmini/güvenlik stoğu (B-NEW-06 ile birleşir).
- [x] **ECC-05** python-reviewer + silent-failure-hunter agent'ları eklendi (.claude/agents/). ✅ 10.06
- [x] **ECC-06** session-handoff'a "İşe YARAMAYANLAR" bölümü. ✅ 10.06

#### Faz 0 — Bugün
- [x] ~~**C-01..C-05** atlasops session/memory kurulum~~ — ✅ TAMAM (27.04, Oturum 1). `.claude/` (rules+skills+hooks+agents) mevcut, CLAUDE.md § Session & Memory var, SESSION_LOG arşivlendi, hook'lar çalışıyor (session-start + handoff + pre-commit), ilk commit atıldı. Stale-open kalmıştı (curator yakaladı 17.06).

#### Faz 1 — Bu hafta
- [ ] **C-06** Template (D:\Dev\claude-context-template) güncelle: atlasops'taki güncel session-handoff SKILL.md'yi merge et.
- [x] ~~**C-07** ADR-001 yaz~~ — ✅ B-19 ile yapıldı (`docs/ADR/001-multi-project-journal.md`). Duplicate madde.

#### Faz 2 — Bu ay
- [ ] **C-08** Mevcut `docs/01-baglanti.md` ... `09-raporlar-ve-skills.md` BKM odaklı — `docs/projects/bkm/` altına taşı (büyük refactor, ayrı PR).
- [ ] **C-09** `claude-context-template` `bootstrap.sh`'a multi-project flag ekle (`--multi-project bkm,belinza,yonetiq`).

### Belinza — Backlog

- [ ] **BL-01** İlk oturum: bağlantı bilgisi (sunucu, DB, izinli şema) docs/journal/belinza/'ya yaz.
- [ ] **BL-02** Belinza skill'i (`belinza-baglan` Cowork tarafında mevcut) ile bu repo arasında köprü kur.

### YonetIQ — Backlog

- [ ] **Y-01** İlk oturum: bağlantı bilgisi docs/journal/yonetiq/'a yaz.
- [ ] **Y-02** YonetIQ skill'i (`yonetiq-platform` Cowork tarafında mevcut) ile bu repo arasında köprü kur.

---

## Yapılacaklar (genel backlog — temalı)

### Disiplin
- [ ] **C-10** Aylık `/consolidate-memory` çağrısı — eski journal'ları arşive taşı (3 ay sonra).
- [x] ~~**C-11** `pre-commit-antipattern.sh` hook ekle~~ — ✅ 17.06 wire edildi (H-09: settings.json PreToolUse(Bash) + BKM-adapte blok/uyar). Commit 7fc5a36.
- [ ] **C-13** Build artifact'ları `.gitignore`'a taşı: `sorgular/03-kampanya/RaporApp/bin/Release/`, `obj/Release/`, `*.dll`, `*.exe`, `*.pdb`. 3. commit'te yığıldı (220 dosyanın çoğu bunlar). `git rm --cached -r ...` + yeni commit.
- [x] ~~**C-14** Paralel oturum koruma — ADR-002 implementasyonu~~ — ✅ Lock mekanizması + `session-start.sh` uyarı + `session-handoff` pre-commit git check + stale cleanup (4h TTL) + `session-protocol.md` lock disiplini. Detay: `docs/ADR/002-paralel-oturum-koruma.md`.
- [ ] **C-15** (opsiyonel) TODO.md split per-project: `TODO/bkm.md` + `TODO/_crossproject.md` + `TODO/belinza.md` + `TODO/yonetiq.md`. Race condition azaltır. ADR-002'de tartışıldı.
- [x] ~~**C-16** Plan-first tier sistemi~~ — ✅ `plans/` klasörü + `feature-template.md` + `.claude/rules/plan-first.md` + ADR-003. Tier 1 (yok) / Tier 2 (TODO) / Tier 3 (tam plan). Detay: `docs/ADR/003-plan-first-tier-system.md`. **(YENİ)**
- [ ] **C-17** Pre-commit hook: Tier 3 sinyali varsa plan referansı yoksa uyarı (fail-soft). `.claude/rules/plan-first.md` § İstisnalar. **(YENİ)**
- [ ] **C-18** Handoff skill plan tamamlanma kontrolü — done criteria check edildi mi, plan archive'a taşınıyor mu. **(YENİ)**

### Dokümantasyon
- [ ] **C-12** README.md'ye multi-project yapı eklemesi (mevcut sadece MCP server kurulum).

---

## Arşiv

> Tamamlanmamış ama artık geçersiz/ertelenmiş maddeler (plan-12 WS-1 state-machine). **Silinmez** — git history korur + buraya taşınır. Geçerliliği geri gelirse aktif Faz'a alınır. Taşıma: `session-handoff` curator-check işaretler → kullanıcı onayı → buraya.

### Mayıs %50 kitap kampanyası tahmini (B-NEW-00..06) — arşiv 17.06
> Sebep: kampanya penceresi geçti (Nisan-Mayıs 2025/26, şu an Haziran). Tam plan/RESUME: `docs/journal/bkm/2026-04-27.md`. Yeni kampanya gelirse aktif Faz'a geri al.
- [ ] **B-NEW-00** (restart sonrası) SQL bağlantı testi `SELECT @@SERVERNAME, GETDATE()`.
- [ ] **B-NEW-01** Şema keşfi: `urnKtgr2.ktgrAd` LIKE 'KITAP%' + EncoreMerkez Sales/SalesProducts/Products + Products↔urn köprüsü.
- [ ] **B-NEW-02** Geçmiş veri 3 dönem (May25/Apr25/Apr26 prorate), IsValid=1, DocType IN(1,2,3,6,7,8), CampaignId NULL/NOT NULL ayrı.
- [ ] **B-NEW-03** Model `tahmin = may25 × MIN(MAX(apr26/apr25,0.5),2.0) × elastikiyet`, 3 senaryo, edge-case.
- [ ] **B-NEW-04** Excel 7 sheet (xlsx skill).
- [ ] **B-NEW-05** Doğrulama (top10/dağılım/outlier).
- [ ] **B-NEW-06** (ops.) Stok ihtiyacı türevi.
