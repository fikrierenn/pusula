# TODO — sqlserver-mcp-server (Multi-Project)

Aktif yapılacaklar ve backlog. Bu dosya 400 satırı aşarsa tarihli konular ilgili `docs/journal/<proje>/`'a taşınır.

> **Format:**
> - Her ana başlık bir proje (`### BKM`, `### MCP Server (kod)`, `### CrossProject`).
> - Proje altında **BIRLESIK ONCELIK SIRASI** — Faz 0 (bugün), Faz 1 (bu hafta), Faz 2 (bu ay), Faz 3 (çeyrek).
> - Madde başında **kısa ID**: `B-NN` (BKM), `M-NN` (MCP), `C-NN` (CrossProject), `Y-NN` (YonetIQ). Commit mesajlarında ve journal'da referans.
>
> **Yaşam-döngüsü (plan-12 WS-1):** madde durum modeli `open [ ] → stale (≥30 gün dokunulmadı) → archive`. Stale ≠ otomatik aksiyon; `session-handoff` curator-check işaretler, kullanıcı onayıyla `## Arşiv`'e taşınır. **Silme yok** (git history korur). consolidate-sema skill dry-run raporlar.

---

## Yapılanlar

### 2026-09-12 — B-172 kapanışı · toplantı hazırlığı · gün-içi ciro paneli (10 commit)
- **B-172(c) eşiğe iş modeli ayağı** (`a9f67e5`): ölçüt iki ayaklı (2× sezon VE 5× ikmal kapağı).
  Kat 5 veriden değil devir hedefinden. Sezon ekseni yanlış pozitif üretiyormuş (4.904 çeşit,
  medyan devir 2,25 ↔ temiz grup 2,40). Panelde 40.017 → 37.103 çeşit, 83,3M → 74,7M ₺.
- **Maliyet kaydı şüpheli** (`a331f1f`): "hiç satmamış 46,8M"in %64'ü iki muhasebe kalemiydi
  ("Muhtelif Ürün" 23,2M · "İskonto ve Fiyat Farkı" 6,6M, ikisi de ERP'de `urnTip=0`).
  TMS 2 ön-şartı eklendi → 16,9M. Toplantı öncesi `veri-dogrula` QA'sında yakalandı.
- **Açık sipariş ölçüldü** (`bf12c2e`): "yolda mal var" itirazı talebi kanıtlı kohortta %85
  geçersiz (52/356). Fazla maliyetin %85'inde sipariş durmuş — alıcı lehine bulgu.
- **ODAK ağırlaştırıcısı kaldırıldı** (`ece0290`), yerine yaş satırı (21.282 çeşit / 58,6M ₺).
- **Toplantı çalışma listeleri** (`7e8d24f`) + **mağaza günlük ciro raporu** (`90f498b`,
  `ec52e82`) + **Gün Karşılaştırma paneli** (`64d901f`).
- **İade kaynağına yazılır** (`69597ce`) — iadenin %90'ı Sınav iadesi; **kasa→ERP saatlik
  aktarım** sema'ya işlendi (`aac41e3`, 52. değişmez).

### 2026-09-09 — Satış Analizi paneli + ürün drill (plan-42, 3 commit + uncommitted)
- **Panel canlı:** `/satis-analizi` — 46 MB elle Excel raporunun (273.515 ürün × 26 kolon) yerine ön-agrega `bkm.SatisAnaliziTaban` (kesim başına 275.059 satır, 6 index, son 3 kesim tutulur). Sayfa 17 ms · KPI 196 ms · arama 346 ms. Kullanıcı seçmeli 31 kolon (tercih `dbo.PanelKolonTercih`, düşen anahtar UI'da görünür).
- **Ürün drill** (`/satis-analizi/urun/{stkId}`, modal DEĞİL — ayrı sayfa): sipariş kararı + görsel · stok nerede · aylık satış/alış (AYRI ölçek) · **mağaza stoğu çizgisi** · giriş maliyeti + **iki yönlü marj** · **sezon ayrımlı tükenme** · yaş/tazelik.
- **KDV tabanı ölçüldü:** `urn.fiyatS` KDV **DAHİL** (POS iç-yüzde kimliği 89.888/89.888) · `fatAyr.ehTutarN` KDV **HARİÇ** · oran `urn.KDVs` → `kdvYuzde_vw` (29.912/29.912, 0 sapma). Marj artık iki tarafı KDV-hariç tabanda; brüt marj (satış üzerinden) + markup (maliyet üzerinden).
- **Sezon varsayımı çürütüldü:** "sezon = hızlı" ürün bazında yanlış olabiliyor — 1672852 sezon 63,57 vs dışı 93,62 ad/gün (0,7×, sezon dışı daha hızlı); 1701128 13,4× sezonluk. Tükenme artık takvim üstünde gün gün simüle ediliyor, tek ortalamayla değil.
- **ODAK köprüsü düzeltildi:** `ProductCode = stkID` sahte köprüydü (511.040 eşleşme sayısal tesadüf) → doğru zincir `ProductCode → odak_urun_tam.urun_id → barkod → urnBrkd.urnBrkdStkID` (644.107, %99,9). leadTime ort. 5,03 gün → aşırı stok + ODAK'ta var kesişimi 131,4M ₺.

### 2026-08-18 — Hesap-sorma derinleşmesi + kanal kırılması keşfi + Belinza temizliği (15 commit)
- **Serve Deep vakası:** Tem'26 tek evrak 007287 (Promarka, 50 SKU, 985.090 ₺) ama küme 2026'da 5 ayda 4,86M ₺. HP 8 varyantı: 8 evrak/3 tedarikçi, 5.064 adet, satış çökerken sipariş büyüdü → ~1,06M ₺ donmuş.
- **KANAL KIRILMASI (kök sebep, GMY teyidi):** 06.01.2025 e-ticaret faturalama Point'e devredildi → fat satış faturası 122.145→104/ay, mhsFisBaslik 251.813→7.123. **Analitik pencere başı 01.02.2025** (Ocak hibrit ay). Kırılma %94,5 KİTAP'ta; dashboard sayısal katmanı MUAF (pencere denetimi). Etkilenen: B-117 GL forensic → B-141.
- **İLİŞKİLİ TARAF:** frm 9525 ODAK-POINT = alımın ~%40'ı (2025: 307,7M ₺). Fiyat kıyasında ayrı kova.
- **ALICI-ATIF boyutu bulundu:** `bkm.OneriSiparisTalep` (EkleyenKullanici+OnaylayanKullanici). irs.gKisi = mal kabul, ALICI DEĞİL. Whitelist + rol haritası + adalet kuralları (mutlak sayı yasak, aktif-güne normalize, unvan yok) sema'ya yazıldı. Karar katmanı = mağaza md yrd.
- **plan-34 B-142/143/144/145 UYGULANDI:** ratchet (111 ürün, HP 8/8) · stockout karşı-metriği (24) · iade parametresi · fiyat sapması sekmesi (1.577 ürün / 2,70M ₺ + 3 adalet filtresi). KPI dürüstlük: Sağlıklı Oran %81→%48.
- **Belinza** repo+memory+global skill'den tamamen kaldırıldı (skill `D:\Devel`'e taşındı). Unvan GM→GMY.
- Detay: `docs/journal/bkm/2026-08-18.md`.

### 2026-08-14 — Satınalma model rafinasyonu + Bulunurluk (OSA) sistemi (~20 commit)
- **Satınalma modeli** (3-emitter dashboard+DINAMIK+Python): sabit çoklu-sezon (dbd41e5) · büyüme şeffaflık (7eb99b9) · şube-sezon paneli+yıl-etiket (98aa4a9/707ffb2) · çifte-düşüş cezası kaldırıldı (de637f9) · **RETAIL-MOMENTUM floor** (89c7b24, bulk-vs-retail: matara/ajanda vakaları) · TOPTAN-KANAL rozeti+evrak-drill (d9b4aa0/6d33883, İst.Yolu=Sınav Okulları) · SatinRetailCap parametrik.
- **Bulunurluk plan-33** (Tier-3, YENİ): OSA sayfası `/bulunurluk` (B-133/134/135, c7daa0f) · pre-agg `bkm.BulunurlukOzet/Kayip` (29d3030) · recency fix (a7aa864) · dense `StokAyBakiyeMekanBazli` bounded explicit-0 nightly-safe (a80bc39, kullanıcı çalıştırdı, 29M). Faz0: %37 kısmi-dağıtım, ~263K kayıp-adet.
- sema: bulunurluk_osa + retail_momentum_floor (metrics) · StokAyBakiyeMekanBazli (entities) · irshrk-irs köprüsü (bridges). erp-write-policy: 3 yeni bkm.* tablo.
- Detay: journal `docs/journal/bkm/2026-08-14.md`.

### 2026-06-26/27 — Baskısı Yok kapsamlı iyileştirme + ODAK Stok KPI + sema borçları
- **Baskısı Yok (B-126 uzantı + sema):** iptal-0 bug fix (`WHERE B.QUANTITY>0`) + AppKpiCarousel KPI + grup dağılımı + saat×gün heatmap (B-55 deseni) + gecikme kova grafiği + saat/haftanın-günü grafikler + _pColor köprüsü + varsayılan Son 7 gün + SQL arşiv. BASKISIYOK sema entity + 3 bridge yazıldı (B-126 TAMAMEN KAPALI).
- **ODAK Stok (B-123 uzantı):** KPI şeridi AppKpiCarousel (Çeşit/Bağlı Sermaye/Ölü Stok/Ort.Ay-Kapsam) + Aşırı Stok Top-10 kart (warning border) + marka özeti Stok ₺ kolonu.
- **E-ticaret:** sipariş saat yoğunluğu grafiği (`GetSiparisSaatAsync`).
- **Tray:** `start_dashboard.ps1` konsol ShowWindow(SW_HIDE) gizleme.
- **Sema:** `bakiyeVDGG_vw` entity + `bakiyevdgg-frm` bridge.
- 10 commit (49495cf → da842e7). Uncommitted: `.gitignore` + `raporlar/` + `make-dashboard-cert.sh`.

### 2026-06-22 — Operasyon hızlı kazanım kartları (B-112 3/4 + B-111) + TODO dedup
- **B-112** (6df2a39): Operasyon'a 3 kart — ödeme grubu+Δ (nakit-stres) / iade sebebi (RefundReasons.Type=0) / indirim kaynağı (SPC.Source). (d) kasa saatleri zaten vardı. Yeni `RefQueries.Operasyon.cs` partial + 3 record. Dönem-duyarlı.
- **B-111** (5884ac6): WMS bekleyen doluluk kartı — TEMİZ J_ORDERS aşama split (`GetBekleyenDurumAsync`), emirAyr kirli kullanılmadı. Canlı toplanma 2/hazırlanan 4.283/temin 6.185.
- **TODO dedup** (95ffc0f): B-111/B-112 Faz-2 asılları done-but-open düzeltildi (SABAH kopyalarıyla senkron).
- Build yeşil, sorgular MCP-doğrulandı. Render login-gated (kullanıcı görsel onay). Detay: `docs/journal/bkm/2026-06-22.md`.

### 2026-06-19 — FIFO üretim tek-master (0→canlı) + uçtan-uca Ocak doğrulama (cross-repo: D:\Dev\fifo = ASIL PROJE)
- **B-116 master ÜRETİLDİ+DOĞRULANDI** (commit bekliyor; ID düzeltme: eski B-113=UI-checklist çakışması → B-116): `fifo/v2-production/00_V2_MASTER_FULL.sql` (build-master.sh) — portable, $(ErpDb)/$(MaliyetDb), curated 16SP/11view/15tbl/seed. Boş BKMMaliyet_Test'e deploy+açılış+aylık+ortalama 0 hata, maliyetsiz=0, **Ocak Brüt 25,65M/%35,4 = rev2 birebir**.
- FIFO SP fix: açılış irsHrk-kümülatif (geçmiş-doğru, anlık-stok bug), GARANTİ final-tier (SonAlış→kategori-imput→devre-dışı, **1-TL sabit kaldırıldı**), 04 dryrun kolon-fix.
- **Repo ayrımı netleşti: FIFO=asıl proje, pusula=sadece sema** (kullanıcı). Tam kayıt FIFO memory'de (session_log + CLAUDE.md SON DURUM #8). Detay: `docs/journal/bkm/2026-06-19.md`.
- Yarına: FIFO commit · sızan gerçek-gider stkID-curated devre-dışı · prod cutover (201 kapalı) · **plan-23 Faz-1 sema (pusula, B-114) hâlâ açık**.

### 2026-06-18 Oturum 4 — FIFO maliyet katmanı bütünlük + Ocak K/Z + üretim-master planı (cross-repo: D:\Dev\fifo)
- **FIFO bütünlük (fifo repo):** maliyetsiz katman/çıkış → 0; 13 reprice + 619 katmansız stok katmanlandı (fytOzl/kategori-imput/devre-dışı). SP 0-fiyat guard (14_V2) + `fifo-domain §6` "FİYAT 0 OLAMAZ". Commit fifo `f474830`+`742847f`. Ocak marj rev2 birebir (brüt 25.58M/%35.4).
- **Ocak Kategori3 K/Z Excel** (bkm.UrunBilgi.Kategori3=urnKtgr2, 18 kat) + negatif-marj 34 hata-şüphe Excel → `fifo/raporlar/`.
- **Üretim tek-master planı:** `fifo/docs/PLAN-uretim-master-deploy.md` (Tier-3, GO verildi, S1'den başlanacak). + `plans/23-fifo-maliyet-sema-entegrasyon.md` (pusula sema tarafı).
- **/learn:** TVF-per-row-timeout → restrict-then-rownumber (`sql-server-conventions.md`); sqlcli json-capture (`fifo-domain §5`). Detay: journal Oturum 4.

### 2026-06-18 Oturum 2 — Genius asistanı: Faz-1+UI redesign+Faz-2 Gmail/Takvim+OpenRouter+plan-22 öğrenen katman (~35 commit)
- B-45 devasa: chat UI redesign + LLM-yönetimli tek akış (niyet-heuristik kaldırıldı) + Faz-2 Google OAuth/Takvim/Gmail (onay-kapılı) + OpenRouter→Gemini→Groq zinciri + plan-22 Hermes-uyarlı bellek (PanelAsistanBellek + bellek_yaz/gecmis_ara) + görev SonTarih + **Genius ismi + lambadan-cin maskotu** + 99-komut repertuar + markdown render. Hepsi build-yeşil + büyük kısmı canlı-doğrulandı. Sonunda free LLM kotası dolunca (OpenRouter 50/gün) test durdu → 19.06 03:00 reset / $10. Detay: `docs/journal/bkm/2026-06-18.md` Oturum 2.

### 2026-06-17 Oturum 2 — Ölü stok maliyet/filtre + Stok Hareket sayfası (defter)
- **B-104** ölü stok maliyet zinciri: son 5 alış faturası (`fatAyr` eTip=0) → `ORT_ALIS` → `fiyatS × kategori AVG(ORT_ALIS/fiyatS)` imputation (sıfır-maliyetli ürünler kategori marjıyla fiyatlanır)
- **B-105** ölü stok kirli kayıt filtresi: `urnTip=0` (gider/hizmet kalemi hariç) + `KARGO`/`Zkargo` kategori + stkID 81809 (İskonto ve Fiyat Farkı). sema entities/codes/metrics + SEMANTIK_KATMAN güncel
- **B-106** yeni **Stok Hareket sayfası** (`/stok-hareket`, NavRegistry): ürün ara (barkod/kod exact + ad LIKE, debounce as-you-type, barkod tek-sonuç otomatik) → defter. TEK birleşik liste, tarih sıralı, Devir açılış satırı + global yürüyen Kalan, Firma/Evrak kolonları, Giriş/Çıkış renk. 3 şube + 12 depo. Barkod arama 5.8s→0.14s (stkID IN alt-sorgu)
- AppDataTable `OnRowClick`; ölü stok + kategori drill satırı → tam-ekran sayfaya yönlendirir (modal-üstü-modal kaldırıldı)
- Build yeşil, sorgular MCP'de doğrulandı. **Kod commit BEKLİYOR.**

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

#### 🆕 VARDİYA UYGULAMASI (plan 48) — ilk sürüm ✅ 19.09.2026
> `vardiya-app` (Razor Pages + Solum, port 5120) · `lib/Bkm.Shared` · 17 kullanıcı açık.
> Adım 0-7 tamam: ortak kütüphane · ayrı app · kimlik/yetki · şube kapsamı (b)-tam ·
> zamansal ACL · rapor · onay akışı + atomik denetim izi · panel salt-okuma.
> Kapılar: `vardiya_kapsam_denetimi.py` · `mesai_esik_denetimi.py` · `panel_kolon_denetimi.py`.

- [x] ~~**V-01 Geçici şifre dosyası SİLİNECEK**~~ — ✅ KAPANDI 19.09.
      `ciktilar/vardiya-ilk-sifreler-20260919-0119.txt` **GMY onayıyla silindi** (1.308 bayt).
      Silme ancak kurtarma yolu kurulduktan SONRA güvenliydi: İK şifre sıfırlama
      (`/ResetPassword`, commit `8de4be2`). Ölçümde 13 kullanıcı hâlâ geçici şifreyleydi;
      kurtarma yolu olmasaydı silme onları kilitlerdi. ⚠ Geçici şifresini kaybeden
      kişi artık İK'ya gider — dosyaya değil.

- [x] ~~**V-02 Seed kadro listesi koda gömülü**~~ — ✅ KAPANDI 19.09 (commit `aebd3da`).
      Kadro `ciktilar/vardiya-kadro.json`'dan okunuyor (git yoksayar; `VARDIYA_KADRO` ile
      yol verilebilir). Dosya yok/bozuk/boş ya da rol tanınmıyorsa **çıkış 2 (KOŞAMADI)**.
      Gerçek koşum: 17 kişi okundu, 0 yeni / 17 mevcut. ⚠ "Zirve'den canlı oku" borcu
      **tek başına kapanamaz** (ölçüldü): bordro kişiyi ve lokasyonu biliyor ama **rolü
      bilmiyor** — "kim şube sorumlusudur" bir uygulama kararı. Kapanan şey listenin
      koddan çıkması; canlı okuma + şube eşlemesi ayrı iş (Solum plan-21).
- [x] ~~**V-03 Solum kabuğu devreye alınmadı**~~ — ✅ KAPANDI 19.09 (commit `00a837c`).
      `_SolumLayout` devrede; altı adaptör bağlandı (kullanıcı · şirket · kiracı · izin ·
      menü · saat). `AddSolumSingleTenant` **kullanılmadı**: sabit `userId` alıyor, 17
      gerçek kullanıcıda denetim izine yanlış kimlik yazardı. Anonim sayfalar kabuk dışında.
      Ölçüm `SolumShellTests`: kabuk + marka + menü + çıkış adresi, ayrıca `solum.css` 200.
- [ ] **V-04 Personel rolü (Faz 2)** — şemada tanımlı, hiçbir hesaba atanmadı.
      Açılırsa KVKK aydınlatma + 362 hesap yönetimi gelir.
- [x] ~~**V-05 Vardiya planı girişi + izin günü tanımı**~~ — ✅ KAPANDI 19.09 (plan 49,
      altı adım: `5dcc4b7` şema+view · `9c47882` okuma+yazma · `36e42d2` ekran+testler ·
      `6e59acd` izin günü tabanı · `77d5c6a` deploy sapması kapısı · `d15f0a3` mevzuat
      kapısı). GMY kararları: düzeltilmiş taban hesaba girer · ofis kadrosu politika
      tablosundan (V-17) · izin işareti PDKS'yi ezmez.
      Ölçüm: düzeltme yokken tüm rakamlar geçiş öncesiyle **birebir aynı** (mevzuat
      kapısı 93/1/93/124/544), düzeltme yazılınca yansıyor (781 → 782 izinli gün).
      ⚠ Kalan uçlar ayrı maddelerde: V-17 (politika parametresi) · V-18 (itiraz ekranı) ·
      V-20 (kesim/devir ekseni test edilmedi).
- [x] ~~**V-18 "Aslında izinli değildi" itirazının EKRANI yok**~~ — ✅ KAPANDI 19.09.
      Onay kutusu (iki durum) → **üç durumlu seçim**: "bir şey söylemiyorum" (kaynak
      geçerli) · "izinliydi" · "izinli DEĞİLDİ (kaynağa itiraz)". Kutu boşken niyet
      okunamıyordu — "söylemedim" ile "değildi" aynı görünüyordu.
      ⚠ Testteki **SQL arka kapısı kaldırıldı**: itiraz artık uygulamanın kendi
      yolundan yazılıyor. Eski hâliyle test, **ürünün yapamadığı** bir şeyi ölçüyordu.
      Ekran yolu için ayrı uçtan uca test (form → POST → DB) + kırmızı kip.
- [x] ~~**V-21 "Tetikleyici ATEŞLEDİ mi" mekanik olarak sorulamıyor**~~ — ✅ KAPANDI 19.09.
      Biçim geldi: **`TETİK(2026-10-01)`** (tarihli, mekanik sorulabilir) ·
      **`TETİK(koşul: …)`** (koşullu, sorulamaz ama SAYILIR). Kapıya beşinci denetim
      eklendi: ateşlemiş **tarihli** tetik + madde hâlâ açıksa **KIRIK**.
      ⚠ SINIR GÖRÜNÜR YAZILIYOR: bugün 5 koşullu tetik mekanik olarak sorulamıyor ve
      **104 açık madde tetiksiz** — yani kapı borçların yalnız küçük bir kısmını
      izliyor. Görünmeyen bir sınır, olmayan bir sınır gibi davranır.
      Kırmızı kip: tarih geçmişe çekildi → "tetik ATEŞLEDİ, 18 gün önce" → geri alındı.
- [ ] **V-22 Curator-check vadesi** — sema/TODO yaşam-döngüsü taraması (≥7 gün).
      Son tam tarama 2026-09-09, hafif tarama 19.09'da handoff'ta yapıldı.
      **TETİK(2026-09-26)** — tarihli, yani bu kapı ARTIK kendisi hatırlatıyor;
      önceki vade 10 gün gecikmişti ve onu hook'un uyarı satırı yakalamıştı, kapı değil.

- [x] ~~**V-19 Türkçe kapısının KARA LİSTE yarısı**~~ — ✅ KAPANDI 19.09. Kara listenin
      YANINA **ak liste** kondu (`tools/kod-sozcukleri.txt`, 236 sözcük): bildirilen her
      adın her sözcüğü dağarcıkta olmak zorunda; olmayan sözcük KIRIK verir ve iki
      seçenek sunar (İngilizceyse bir satır ekle, Türkçeyse çevir).
      ⚠ **Kurulurken İKİ KAÇAK buldu**: `LikeKacir` ve `CalistirAsync` aylardır koddaydı
      ve kara liste onları HİÇ görmüyordu → `EscapeLike` / `RunAsync`. Yani "kara
      listenin eksikliği görünmez" bir teori değil, bu depoda **ölçülmüş olgu**.
      Kırmızı kip üç kez: kara listede olmayan Türkçe ad (`Dukkan…`) → KIRIK · ak liste
      dosyası silindi → **KOŞAMADI** (sessizce kara listeye düşmek yasak) · geri alındı.
- [ ] **V-20 Vardiya testleri TEK KESİM üzerinde koşuyor (adım ekseni kör)** (19.09,
      Solum'un sekizinci tuzağının ikinci ekseni) — fikstür tek kesim seçiyor; **kesim
      değişimi ve devir taşıma hiç test edilmedi**. `GetSummaryAsync` devri ayrı tablodan
      topluyor (`Vrd_Devir`) ve o yol yalnız ay kapanışında yazılıyor.
      **Ölçmeyi engelleyen:** ikinci bir kesim üretmek `sp_Vrd_KisiGunDoldur` koşumu ister
      (dev veride tek kesim var).
      **TETİK(koşul: ilk gerçek ay kapanışı)** — devir yazıldığı gün bu test yazılmadan
      kapanış YAPILMAZ.

- [ ] **V-17 GM bölümleri için çalışma süresi parametresi** (19.09, plan 49 kararı S2)
      `Vrd_CalismaSaati`'nde 15 satır `OTOMATİK EKLENDİ — şube varsayılanı, İK onaylamalı`
      notu taşıyor. GM ofis kadrosunun 70 günlük "vardiya tanımsız" kısmı bu satırlar
      düzeltilince kapanır. ⚠ Tablo yalnız `--parametre-yukle` ile yazılır (JSON → tablo,
      TEK YÖN) — yani uygulama yazması değil, **İK parametre kararı**.

      **TETİK(koşul: İK bölüm bazlı çalışma sürelerini verdiğinde)**
- [x] ~~**V-16 TODO'da 6 MÜKERRER kimlik**~~ — ✅ KAPANDI 19.09. Ölçünce **ikisi kusur
      değildi**: `B-98-gen` ve `B-172(c2)` ayrı maddeler, kapının kimlik deseni onları
      kısaltıp asıl maddenin mükerreri gibi gösteriyordu (beşinci kalibrasyon).
      Kalan **dördü gerçekti** ve birleştirildi: `B-06` ve `B-12` iki bölümde yazılıydı;
      `B-110`/`B-111`'in ikinci kopyaları zaten metninde **"dup"** diyordu ama hiç
      birleştirilmemişti. Kimlik sayısı 239 → 239 (kayıp yok), mükerrer 6 → **0**.
      Tavan 0'a indi: yeni mükerrer artık **kırar** (kırmızı kiple doğrulandı).
- [x] ~~**V-15 Test takımında GÖZLENEN ama ÜRETİLEMEYEN kırmızı**~~ — ✅ KAPANDI 19.09
      (commit `36e42d2`). Tahminle bulunamadı; hata mesajına **kanıt** eklendi (üretilen
      şifre + sayfa uyarısı) ve ikinci koşumda yakalandı: şifre `Nr2&#x2B;6QQb2BWt` —
      havuzda `+` var, Razor onu `&#x2B;` diye **kodluyor**, test kodlanmış dizgeyi
      deniyordu. **Ürün doğruydu, ölçüm aracı yanlıştı**; kırmızı ara sıra çıkıyordu
      çünkü her şifrede `+` olmuyor. `WebUtility.HtmlDecode` + `data-test` tutamağı.
      5 koşum üst üste yeşil (önce 3'te 1 kırmızı).
- [ ] **V-07 Orantısızlık sezgisi MEKANİKLEŞMEDİ** (19.09, Solum S3) — ikinci kapsam
      sızıntısını bulan şey insan sezgisiydi ("2.192,6 saat makul ama kapsamla
      orantısız"). Bugün ekranda gösterilen toplamı, o ekranın **kapsam kümesinin**
      toplamıyla otomatik karşılaştıran hiçbir şey yok. Sınıf yazılı
      (`olctum-mu-cikardim-mi.md` § makul sayı kabul edilir), mekanik karşılığı yok.

- [x] ~~**V-09 Kapsam BOĞAZI**~~ — ✅ KAPANDI 19.09 (commit `a2157c4`). `VrdSql.PersonDays`/
      `Carryover` süzgeci kaynağın İÇİNE aldı (alt-sorgu otomatik kapsanır); `VrdParams`
      parametre adını tek yere indirdi; her çağrıda SQL `@token` kümesi ↔ parametre kümesi
      iki yönlü karşılaştırılıyor. Kapı yeniden yazıldı (metin saymıyor, yapıyı koruyor),
      kırmızı kip **üç kez** koşuldu. Kurulurken **dördüncü ad kayması** bulundu:
      `SaveApprovalAsync` (`@girisDk` ↔ `inMin`) — onay YAZMA yolu hiç çalışmıyormuş.
      ⚠ AÇIK: bu bir TİP değil, boğazdır — C# geçmeye zorlamıyor; iki bilinen atlatma
      yazılı ve kapı yakalıyor. Yükseltme yolu V-10.

- [x] ~~**V-10 `BannedApiAnalyzers` ile boğazı DERLEYİCİYE zorlat**~~ — ✅ KAPANDI 19.09
      (commit `704c508`). Dapper çağrısı `VrdSql` dışında **derlenmiyor** (RS0030).
      Muafiyet iki dosya: `VrdSql.cs` + `AuditTrail.cs`. Kapsam bilinçli dar:
      yalnız `lib/Bkm.Shared`. Üç ölçüm: (a) boğazı atlayan çağrı derlemeyi durdurdu,
      (b) şiddet `WarningsAsErrors` ile verilemiyor — muafiyetleri eziyor, `.editorconfig`
      kullanıldı, (c) **yasak listesi sessizce ölebiliyor** (yanlış sembol adı → analizör
      hiçbir şey demiyor) → kapıya dördüncü denetim eklendi, kırmızı kiple doğrulandı.

- [x] ~~**V-11 Boğaz kapsamı `vardiya-app`e genişletilsin mi?**~~ — ✅ KAPANDI 19.09
      (commit `2c07557`). Ölçüldü: 5 Dapper çağrısı / 2 dosya, hepsi kimlik-ACL.
      **Ölçüm "riski düşük" varsayımını çürüttü:** `Seed`in ACL yazması SQL `@sube`
      isterken C# `branch` gönderiyordu — **beşinci ad kayması**, şube ataması sessizce
      kırıkmış (seed yeniden adlandırmadan önce koşmuştu, bir daha koşturulmadı).
      `AuthSql` boğazı + `SqlContract` ortak çekirdeği kuruldu, ban ondan SONRA kondu.

- [x] ~~**V-12 ACL yazması DENETİM İZSİZ**~~ — ✅ KAPANDI 19.09 (commit `1dddaf2`).
      `Seed.GrantBranchAsync` grant + izi **aynı işlemde** yazıyor; iz yalnız gerçekten
      yazıldıysa düşüyor (idempotent ikinci çağrı olay değildir). Kırmızı kip: iz
      kapatıldı → test KIRIK. ⚠ Rol/izin yazmaları (`Vrd_Roles`, `SolumPermissionGrant`)
      hâlâ izsiz — bugün tek yazan seed, İK arayüzden vermeye başlarsa bu da gerekir.
- [x] ~~**V-13 Seed ACL yazması yeniden KOŞTURULMADI**~~ — ✅ KAPANDI 19.09 (commit `f59b784`).
      ⚠ "Seed'i tekrar çalıştır" bir doğrulama DEĞİLDİ: seed mevcut kullanıcıyı atlıyor,
      yani yeniden koşmak ACL satırını çalıştırmıyor bile. Yazma yolu tek metoda çıkarıldı
      (`Seed.GrantBranchAsync`) ve **gerçek DB'ye karşı** koşturuldu (`SeedAclWriteTests`:
      yazıyor · idempotent · doğru şube). Kırmızı kip: ad kayması geri konunca test KIRMIZI.
      **Mevcut veri ölçüldü ve SAĞLAM**: 14 ACL satırı / 12 kullanıcı, kafe müdürü 3 şube —
      beklenen kadroyla birebir. Kusur yeniden adlandırmayla koşumdan SONRA girmişti.

- [x] ~~**V-14 Test fikstürü PAYLAŞILAN DB'de yarış taşıyordu**~~ — ✅ KAPANDI 19.09
      (commit sonraki). Koleksiyon fikstürü yarışı kapattı; `FixtureIsolationTests`
      konvansiyonu **mekanik** hâle getirdi (yapıcısında `VardiyaAppFactory` isteyen her
      sınıf koleksiyonda mı — yansımayla). Kırmızı kip: etiket sökülünce sınıfı adıyla
      yazıp KIRIK verdi. ⚠ Yakalamaz: fikstürü yapıcı dışından kuran sınıf (bugün öyle
      bir yol yok, ölçüldü).

- [ ] **V-08 Türkçe tanımlayıcı kapısı — kapsam dar** (19.09) — `tools/turkce_tanimlayici_denetimi.py`
      yalnız `vardiya-app/ · lib/Bkm.Shared/ · tests/` tarıyor; `dashboard/` **dışarıda**
      (43 ihlal orada temizlenmedi, hiç bakılmadı). Genişletme maliyeti ölçülmedi.


#### 🌅 SABAH (19.06) — kalan iş kürasyonu (18.06 handoff, tüm TODO tarandı)
> Genius asistanı (B-45) BİTTİ — kalan sadece canlı-test (LLM kotası 19.06 03:00 reset / $10→1000gün) + senin dışa-dönük aksiyonların (etkinlik-Oluştur/mail-Gönder Chrome onay · auth şifre değiştir). Aşağısı pre-existing BKM backlog'undan en değerli/aksiyonel olanlar.
- [~] **🔥 B-130 Otonom muhasebe app — banka ekstresi satır→cari sınıflandırıcı (plan-27)** — 04.07. AFCP pilotu. Bağımsız `muhasebe/` (Razor Pages+Dapper+Tailwind, **API-yok**, Operax baz). Motor `BankaSiniflandirmaService` (807K `car cTip=122` in-memory index, lexical, **öneri-only salt-okuma**). **Faz-0 kanıt: agree≥%97 & n≥5 → %98.8 auto @ %61 kapsam** (807K holdout). Canlı browser smoke ✅. DerinSIS car→GL boru hattı decrypted çözüldü → sema (`car-karsi-frm`/`frm-mhsent-glhesap`, `car.cFatTip`, `banka_ekstresi_siniflandirma`). Skiller: `afcp-danisman`/`muhasebe-danisman` + 4 Operax mali skill. **✅ 04.07 Oturum-2:** perspektif kilidi (cKod frmTip=5 → %69,6/%99,63, komple Haziran backtest) · **aktif öğrenme** (`bkm.BankaOgrenme` DerinSIS bkm-şema app-owned; onay/düzelt UI; öğrenilen öncelikli; DB-kalıcı canlı doğrulandı) · UI (banka dropdown aktif-119, İstisna cari-arama, Windows auth) · car→GL boru hattı decrypted→sema. **KALAN (Monday):** (1) **F3 ERP-yazma test:** Şule 1 satır girer→yakala→`bkm.sp_BankaEkstresiGir` (car_ekle sarmalar, Fikri oluşturur) aynısını→karşılaştır→car_sil-yanlışsa; insID/evrakNo/gdrMerkez netleştir + `bkm.BankaYazimAudit`. (2) Excel-in (ClosedXML + IBAN→banka auto-seç) ham Haziran. (3) L2 skill/kural (HITL rule induction, düzeltme birikince) + tutar sinyali F1.5 + embedding no-hit F2. (4) SQL keşif arşivle `sorgular/2026-07-04-*.sql` (twin-obligation borcu). erp-write-policy: bkm.BankaOgrenme eklendi; native car F3-test ile açılır. **✅ 04.07 Oturum-3:** yönetici-rapor skill (6 kurumsal format, overclaim-yasak); afcp TEZ 3-katman tek-beyin; gider-anomali (Katman-2) 3 hipotez tarandı→hepsi meşru (0 hata, feature kurulmadı)→radar banka/nakit'e yönlenecek.
- [x] ✅ **B-162 İst.Yolu perakende/Sınav ayrımı — KÖK SEBEP BULUNDU** — 08.09. İki sebep: (1) **eTip 4 "Mağaza Satış"** eTip 100'ün dışında ayrı satış kanalı ve pratikte sadece İst.Yolu'nda (2025 20,18M / 2026 29,79M; %86-89 Sınav kategorisi) — Sınav toplu faturaları buradan akıyor. Mutabakat formülü `eTip 100 − 101 + 4 − 5` üç şubede de %0,08-1,28 içinde tutuyor (yalnız 100 ile İst.Yolu −%10,24). (2) **Belge tipi ≠ ürün kategorisi**: Sınav faturasında satılan kitap/kırtasiye 21,83M (2026), perakende fişindeki Sınav ürünü 0,19M → net bucket farkı 21,64M. Kanonik kural sema'ya yazıldı (`MEKAN_CIRO_MUTABAKAT_FORMULU`, `KANAL_AYRACI_KANONIK`, `ISTYOLU_KANAL_AYRIMI_COZULDU`), tahmin belge bazlı düzeltildi. Arşiv: `sorgular/2026-09-08-okul-hizali-ciro-tahmini.sql` blok 9.
- [x] ✅ **B-164 eTip 100 kullanan yerler tarandı + düzeltildi** — 08.09. **Tarama:** 91 dosyada eTip/ehTip 100 geçiyor; ezici çoğunluk zaten `IN (4,100)` veya `(1,4,100)` kullanıyor → ETKİLENMİYOR (OdakQueries, Queries.cs, RefQueries(.Envanter), SabahService, cok_satan_*, olu_stok_excel, export_odak_stok, forecast/data.py). **Etki ölçüldü** (Oca-2025..07.09.2026, `100` vs `100−101+4−5`): Sınav-HARİÇ 3 mağaza toplamı sadece +%0,5-0,6 (FSM −%0,5..1,0 · Özlüce −%0,4..0,8 · **İst.Yolu +%2,7..4,4**); Sınav DAHİL toplamda **İst.Yolu +%8,2..9,8**, Sınav kanalı +%12,4. **Düzeltilen:** `dashboard/Data/KadroQueries.cs` GetIsHacmiAsync (eTip IN (4,5,100,101) + iade sign'lı; build yeşil, SQL smoke-test geçti) · `sorgular/2026-09-03-personel-maliyet-fazla-mesai.sql` BLOK 3 (**yüksek etki** — maliyet oranının paydası %4-10 düşüktü, oran olduğundan yüksek görünüyordu) · `sema/queries.yaml` okul-hizali-pencere-hacim (katalog duman testi 15/15 geçti). **Not düşülen (teslim edilmiş çıktı, geriye dönük değiştirilmedi):** `sorgular/2026-09-02-kadro-vs-is-hacmi-savunma.sql` blok 11 · `scripts/verimlilik_cek_hacim.py`. **Kasten dokunulmayan:** SatinalmaQueries/satinalma_hesap_sorma/DINAMIK (`CASE WHEN ehTip=100` retail-cap alt-metriği, WHERE zaten `IN (1,4,100)`) · `2026-08-18-gl-kanal-kirilmasi` (pos_net'i bilerek ayırıyor). Değişmez eklendi: `etip4-magaza-satis-istyolu-anlamli` (kırılabilirlik sınandı; 34/34 yeşil). Ayrıca `tools/sema_degismez.py` KIRIK raporunda cp1254 çökmesi düzeltildi (UTF-8 stdout).
- [x] ✅ **B-166 KAPALI** (09.09, commit 1c107f0 + sema düzeltmesi) — doğrulandı: `sema/metrics.yaml:11-27` (fiyatS KDV dahil / fatAyr KDV hariç / iç-yüzde kanıtı) · `sema/bridges.yaml:11-24` (urn.KDVs → **dbo.urnKDV.kdvID**) · `sema/codes.yaml:438-468` (10 kod + `view_tuzagi` + kapsam dersi) · `sema/entities.yaml:886` (SatisAnaliziTaban entity) · değişmez `fiyats-kdv-dahil-ic-yuzde` + `kdv-kod-kumesi-lookupta` · arşiv `sorgular/2026-09-09-kdv-tabani-marj-olcumu.sql`. ⚠ **Aşağıdaki (c)/(d) maddeleri YANLIŞ kaldı ve düzeltildi:** oran haritası `dbo.kdvYuzde_vw` DEĞİL **`dbo.urnKDV`** — view her orana ait yalnız ilk kodu verip Hizmet/Hammadde varyantlarını (5,8,9,10) atıyordu; "29.912/29.912 uyuşma" da yanıltıcıydı (o kesişimde öksüz kod yoktu). Ayrıca `codes.yaml`'ın `note:` satırı hâlâ `kdvYuzde_vw` diyip aynı kaydın `view_tuzagi` bölümüyle çelişiyordu → 09.09'da düzeltildi. Tarihsel metin: — 09.09. Bu oturumda ölçülen şema gerçekleri `sema/*.yaml`'a YAZILMADI: (a) `urn.fiyatS` KDV **DAHİL** — kanıt POS `VatTotal = TotalPrice × oran/(100+oran)`, 89.888/89.888 satır (%20) + 39.426/39.426 (%10); üst-yüzde DEĞİL · (b) `fatAyr.ehTutarN` KDV **HARİÇ**, KDV ayrı kolonda `ehTutarKDV` · (c) `urn.KDVs` → `dbo.kdvYuzde_vw` (`ilkKDVID`) oran haritası, POS `VatPercent` ile 29.912/29.912 uyuşma, 0 sapma · (d) `dbo.kdvYuzde_vw` kod kümesi 1→%0, 2→%1, 3→%8, 6→%10, 4→%18, 7→%20 → `codes.yaml` · (e) `bkm.SatisAnaliziTaban` entity (grain Kesim+SezonYil+stkID). Ayrıca keşif SQL'i `sorgular/2026-09-09-kdv-tabani-marj-olcumu.sql`'e arşivlenecek. Değişmez adayı: `fiyats-kdv-dahil-ic-yuzde` (kırılabilirliği sınanacak).
- [ ] **B-170 Satış Analizi — YENİ ÜRÜN kör noktası + yolda stok + kart fiyatı ile değerleme** — 09.09, stkID 1739183 incelemesinden doğdu (Maxx MX-617 Tahta Kalem Seti, kart açılışı 04.09.2026, 5 günlük ürün).
  - **(a) 365-gün penceresi yeni üründe hızı ~50 kat küçük gösteriyor.** `GunlukOrtalamaSatis = SatisToplam/365` → 37/365 = **0,101 adet/gün**. Gerçek: POS'ta 2 günde **83 adet = 41,5 adet/gün** (FSM 55 + Özlüce 28; İst.Yolu'nda hiç stok yok). Gün-stok bu yüzden ~26.000 gün çıkıyor ve ürün "aşırı stok" olarak işaretleniyor — halbuki 2.440 adet merkez stoğu bu hızla **~59 gün**. ÇÖZÜM ADAYI: hız hesabında payda `MIN(365, ürünün yaşadığı gün)` olmalı (drill'de akran medyanında bu düzeltme YAPILDI, listede/tabanda YAPILMADI).
  - **(b) ✅ ÖLÇÜLDÜ 10.09 — kart YAPILMADI, beyan edildi.** Yolda stok: eşleşmeyen transfer 2.389 satır / **1.869 çeşit / 53.602 adet**; hepsinde kabul hiç yok, en eski çıkış 08.09 (2 gün), **14 günden eski 0** → kabul normalde ~2 günde tamamlanıyor, yönetim problemi değil zamanlama artefaktı. Panel bandına açıklama satırı eklendi. Aynı ölçüm "Mağazalar Arası Transfer" kartındaki 14 günlük muhafızın yeterli olduğunu kanıtladı (14 > 2). Anahtar `eNo+stkID` doğrulandı (yanlış olsaydı 120 günün tamamı eşleşmemiş görünürdü). Arşiv: `sorgular/2026-09-10-yolda-stok-transfer-eslesmesi.sql` · sema: `yolda_stok_transfer_kabul_gecikmesi`. Tarihsel not:
  - **(b-eski) "Yolda stok" hiçbir yerde görünmüyor.** Transferin karşı bacağı mağaza kabulüne kadar oluşmuyor: İst.Yolu'na 08.09'da çıkan **480** + FSM'ye 09.09'da çıkan **240** = **720 adet** ne depoda ne mağazada. Depo çıkışı ile mağaza girişi arasındaki fark ölçülebilir (`ehTip 13` tek-bacaklı satırlar) → panelde "yolda" kolonu/uyarısı adayı.
  - **(c) Stok değeri kart fiyatıyla, gerçekleşen fiyatla değil.** Kart 149 ₺; POS'ta 83 adedin **tamamı 99 ₺'ye** satılmış (indirim 4.150 ₺ = birim 50 ₺, tamamı `DiscountTotalCampaign`, `IsPriceEnteredByUser=0`). Panel 2.643 adedi 149 ₺'den **393.807 ₺** değerliyor; kampanya fiyatıyla 261.657 ₺ → **−132.150 ₺ (−%34)**. Maliyetle (44,25 ₺) 116.953 ₺. B-167(a) "Bağlanan Stok" tartışmasının somut kanıtı.
  - Marj ölçümü: maliyet 44,25 ₺ (alış listesi 59 ₺ − %25, `fytOzl` fTur=1) · satış 99 ₺ KDV dahil → KDV hariç 82,50 ₺ → **brüt marj %46,4 / markup %86,4**. Kart fiyatıyla %64,4 / %180,6 görünüyor — yani panel marjı da olduğundan iyi gösteriyor.
  - **UYGULANDI (09.09):** (i) gün-stok negatif stokta artık **null** — `MagazaStok < 0` guard'ı (`SatisAnaliziModels.cs`); kullanıcı "-365 falan yazıyor ama saçma sapan bir şekilde" dedi, sebebi −37 ÷ (37/365) = tam **−365**; ÖLÇÜLDÜ 93 ürün bunu gösteriyordu. 0 stok null DEĞİL (raf boş = 0 gün, doğru bilgi). (ii) hız paydası `EtkinGun` artık `COALESCE(IlkGiris, AcilisTarihi)` — 848 üründe değişiyor (satışı olan 11), 225'i doğru şekilde "hız güvenilmez"e (<28 gün) düşüyor, min değer 1 (bölme riski yok); 4 ayrı yerde aynı formül vardı, hepsi çevrildi. (iii) evrenden **"Kafe Hammede" çıkarıldı** (2 çeşit / 49 adet / 26.504,54 ₺; biri 89918 "KAFE RESTAURANT SATIŞLARI" hizmet kalemi, kategori agregasını −21 yapan tek sebep). (iv) **`urnTip = 0` süzgeci eklendi** — sema `codes.yaml` bunu "tüm STOK/ürün sorgularında ZORUNLU" diyordu ve panelde YOKTU; dashboard `SatisAnaliziTabanService` kat CTE + kardeş emitter `scripts/satis_analizi_excel.py` ikisine birden. Build yeşil, py derleniyor.
  - **GİDER KALEMİ ÖLÇÜLDÜ ve KAPANDI (ERP döndükten sonra):** panel evrenindeki **275.059 satırın TAMAMI `urnTip = 0`** → gider/hizmet kalemleri bu yoldan HİÇ sızmıyor (kaynak `bkm.UrunBilgi` zaten taşımıyor); eklenen `urnTip=0` süzgeci yalnız ileriye dönük emniyet, bugün rakamı değiştirmiyor. Gerçek gider kalemi **`Zkargo` kategorisinin tek üyesiydi**: stkID **79405 "ALIŞ KARGO GİDERİ"**, `stkKod='153.10'` (muhasebe hesap kodu deseni; evrende noktalı stkKod taşıyan TEK kayıt), 12.571 adet, **Tutar 0,00 ₺**, satış 0 → **Zkargo evrenden çıkarıldı**. Evren 12 → **10 kategori**: çeşit 275.059 → 275.056 · stok 6.370.045 → 6.357.425 (−12.620 = 12.571 Zkargo + 49 Kafe Hammede) · tutar 1.025.667.083,30 → 1.025.640.578,76 ₺ (−26.504,54 = Kafe Hammede; Zkargo 0 ₺). Mutabık.
  - **ELENEN İKİ ÖLÇÜT (ölçüldü, ikisi de yanlıştı):** (a) `satisTur <> 0` → 32 kayıt ama hepsi GERÇEK ürün (Missim/Çilek Bijuteri fiyat-noktası kartları, AYT soru bankası) — gider işareti değil. (b) `SatisFiyat = 0` → 15 kayıt ama 14'ü fiyatı girilmemiş gerçek ürün (Barbie Süpriz Yumurta, Edding markör, The Black Swan…); yalnız 1'i gider (79405). Ad deseni (GELİR/İSKONTO/FARK/HİZMET) 368 kayıt yakalıyor → çok gürültülü, KULLANILMADI.
  - **YAN BULGU — negatif stok jenerik fiyat-kartlarında yığılı:** Missim Bijuteri fiyat-noktası SKU'ları (`satisTur=1`) −499 / −368 / −281 / −170 adet taşıyor ve satışları yüksek (830 / 532 / 279). "Veri Kirli" KPI'sının en büyük kalemleri bunlar; gerçek sayım hatası mı yoksa jenerik kart kullanımının doğal sonucu mu — ayrı ölçüm.
  - ⚠ TABAN YENİDEN KURULMALI: (ii)(iii)(iv) yalnız yeni taban kurulumunda etkir; mevcut kesim satırları eski evrenle yazılmış. Panelde "taban kur" düğmesi.
  - ⚠ NEGATİF MAĞAZA STOĞU "VERİ KİRİ" DEĞİLDİ: taban 09.09 08:44'te kuruldu; POS satışları (08.09 23:45 `hrkTarih`) girdi, mağaza girişleri (09.09 10:12 ve 16:36) girmedi → StokFsm −27 / StokOzl −10. Sebep geriye dönük kayıt + kabul gecikmesi. Sema: `irsHrk_zaman_kolonlari` (ehTrhS = belge, hrkTarih = satırın deftere düşme anı). **Veri Kirli KPI'sı bu iki durumu ayırmalı.**
- [ ] **B-173 Ağu-Eyl 2026 alım röntgeni — ALICIYA SORULACAKLAR (ölçüm bitti, karar bekliyor)**
  Arşiv `sorgular/2026-09-10-agu-eyl-alim-arz-gunu.sql` · Excel `raporlar/asiri-alim-agu-eyl-2026.xlsx`
  (emitter `scripts/asiri_alim_excel.py`). Net alım 151,2M ₺ / 34.140 çeşit.
  (a) **Hesap sorulacak dilim 18,3M ₺ (%12,1)** — 4.501 çeşit, yaşı bilinen eski ürün,
  >365 gün arz ya da 365 günde hiç satmamış. ⚠ 10.09 akşamı verilen **21,9M YANLIŞTI**:
  yaş ayracı `IlkGiris NULL`'u ESKİ sayıyordu (307 çeşit / 3,65M ₺ ayrı kovaya taşındı).
  (b) **Derya / Mopak A4 kağıt 919K ₺** — iç tüketim hipotezi ÇÜRÜDÜ (12 ayda 8 adet);
  ~3,5 yıllık stok. Soru: *"bu bir fiyat kilidi miydi, ne kadar tasarruf sağladı?"*
  Cevap yoksa aşırı. Bu bir TALEP kararı değil FİNANSAL karar → finans ile birlikte sorulmalı.
  (c) **Yanıt / 22 sınav hazırlık kitabı 3,76M ₺** — kurumsal bulk hipotezi ÇÜRÜDÜ
  (depo→mağaza 12 ayda 2 adet). Hafifletici: sezon başı alım + 3-6 belgeli tekrar-ikmal.
  Ağırlaştırıcı: **içerik ömrü** — format/müfredat değişirse eski baskı satılamaz.
  Soru: *"bu baskılar format değişmeden eritilir mi?"*
  (d) **Yeni ürün bahsi ~39,3M ₺ / 4.599 çeşit** — ölü stok DEĞİL ama riskin yaşadığı yer;
  sell-through 8-12 haftada izlenmezse gelecek dönemin aşırı stoğu buradan doğar.
  (e) ⚠ Alıcıya atıf YAPILAMAZ (karar sahibi veride izli değil) — bunlar ürün/tedarikçi
  kohortu, kişi karnesi değil.

- [x] ✅ **B-178 AÇIK SİPARİŞ ÖLÇÜLDÜ — toplantının en büyük riski kapandı**
  12.09.2026. Kurul "alıcı 'yolda mal var' diyecek, cevabın olmayacak, üst üste üç kez
  'haklısın' demek kalan kartları geçersiz kılar" demişti. Ölçüldü (`eTip 0/3` · `eTarih` ·
  `ehAdet` — üç sema tuzağı da uygulandı): talebi kanıtlı stoksuz 356 çeşidin yalnız
  **52'sinde** sipariş var (%14,6) → itiraz %85 geçersiz. Sezon açığında 2.002/7.368 (%27) →
  itiraz kısmen haklı, kabul edilecek. Aşırı stokta fazla maliyetin **%85'inde (63,0M ₺)
  sipariş DURMUŞ** (alıcı lehine); son 30 günde hâlâ sipariş girilen 674 çeşit / 0,65M ₺.
  ⚠ Panel netleme YAPMIYOR (direktif duruyor) — bu yalnız ölçüm.
  Arşiv: `sorgular/2026-09-12-acik-siparis-kohort-kesisimi.sql`
- [x] ✅ **B-179 ODAK AĞIRLAŞTIRICISI KALDIRILDI** (commit ece0290) — çift sayım (kapak ayağı
  LeadTime'ı zaten içeriyor) + kontrol-edilebilirlik ihlali (ODAK tedarikçinin envanteri).
  Yerine "son 6 ayda mal girmiş" yaş satırı: 21.282 çeşit / 58,6M ₺.
- [ ] **B-180 SİPARİŞ KARŞILANMA BAĞI — hâlâ ölçülemiyor (sema'daki borç)**
  `sipAyr.ehSevkAdet` tamamen NULL · `irsAyr.ehSipID/ehSipSira` bağı doğrulanamadı. Bu yüzden
  "sipariş girilmiş" ile "mal hâlâ yolda" ayrılamıyor ve açık sipariş ancak PENCERE daraltarak
  okunabiliyor. Çözülürse: (a) "yolda mal" gerçekten netlenebilir, (b) sipariş karşılanma
  oranı bir hesap-sorma ekseni olur. Keşif: B-154'ün devamı.
- [x] ✅ **B-175 MALİYET KAYDI ŞÜPHELİ — "hiç satmamış 46,8M"in %64'ü iki muhasebe kalemiymiş**
  12.09.2026, hesap-sorma toplantısı ÖNCESİ `veri-dogrula` QA'sında yakalandı. `stkID 128118
  "Muhtelif Ürün"` (5 adet × 4.640.370 ₺ = 23,2M) ve `stkID 81809 "İskonto ve Fiyat Farkı"`
  (6,6M) ürün değil, muhasebe kalemi — ama ERP'de `urnTip=0` normal ürün olduğu için hiçbir
  süzgece takılmıyordu. Düzeltme: `MaliyetGuvenilirSart` (maliyet ≤ satış fiyatı, TMS 2),
  20 maliyet toplamı buna geçti; dışlanan para gizlenmedi (ayrı satır + liste filtresi).
  ETKİ: hiç satmamış 46,8M→16,9M · ölü stok 71,0M→41,0M · envanter 409,6M→378,1M ·
  aşırı stok 74,7M→73,7M. Kırılabilirlik kanıtlandı. Arşiv:
  `sorgular/2026-09-12-maliyet-kaydi-supheli.sql`
- [ ] **B-176 "Muhtelif Ürün" / "İskonto ve Fiyat Farkı" ERP'de `urnTip=0` — BAŞKA analizler?**
  Bu kalemler ürün master'ında normal ürün olarak duruyor. Satış analizi paneli artık maliyet
  tarafında eliyor ama ADET/ÇEŞİT sayan ve maliyet kullanmayan başka raporlar bunları hâlâ ürün
  sayıyor olabilir. Taranacak: `scripts/*.py` rapor scriptleri · `RefQueries.Envanter` ·
  ölü stok Excel çıktıları. Muhasebeye sorulacak: bu kalemler neden stok kartı taşıyor?
- [ ] **B-177 KAYIP FORMÜLÜ bugünkü fiyatla şişiyor (ÖLÇÜLDÜ 12.09, düzeltilmedi)**
  `SezonToplam × SatisFiyat` bugünkü fiyatı geçen sezonun adediyle çarpıyor. Ölçüldü: stoksuz
  kohort bugünkü fiyatla 20,40M ₺, geçen sezon o ürünlerden FİİLEN yapılan ciro **14,01M ₺**
  → **%45,6 şişik**. Talebi kanıtlı dilim: 9,37M vs **6,89M** → %36 şişik.
  Seçenek: kaybı gerçekleşen ciroyla göstermek (tahmin değil, ölçüm) ya da fiyatı sezon
  tarihine indirgemek. Toplantıda GERÇEKLEŞEN CİRO kullanılıyor.
- [ ] **B-172 Satış Analizi — DANIŞMAN İTİRAZLARI (satinalma-danisman 10.09, UYGULANMADI)** —
  Dört ölçüt değişikliği adil-atıf ve perverse-incentive açısından denetlendi; üç ağır bulgu:
  (a) ✅ **KAPANDI 12.09** — iki kart da artık ZIT YÖNLÜ iki satır taşıyor.
  Aşırı Stok'a HAFİFLETİCİ: "iade kanalı çalışmış" (son 24 ayda bu üründen fiilen alış
  iadesi) — ölçüldü 9.501 çeşit / 8,3M ₺ (%11,5); eşik iki ayaklı olunca yeniden ölçüldü 12.09: 12.671 çeşit / 10,8M ₺ (%14,5). ⚠ vekil: ürün bazında iade
  HAKKI veride yok, ölçülen kanalın çalıştığı. Stokta Yokluk'a AĞIRLAŞTIRICI: "talebi
  KANITLI (sezon ≥20)" — ölçüldü 356 çeşit (%4,4) kaybın %46'sını taşıyor (9,37M ₺).
  ~~(a) KARŞI-METRİK DENGESİ TERS (en ciddi).~~ Aşırı Stok'un karşı-metriği "ODAK'ta da var"
  = ceza AĞIRLAŞTIRICI; Stokta Yokluk/Sezon Açığı'nın "ODAK'ta var → hızlı temin" = ceza
  HAFİFLETİCİ. Üstüne aşırı stok TAM ölçülüyor (etiket değeri), stokta yokluk ALT SINIR
  (sansürlü talep) → rasyonel alıcı **az alır**, görünmez kayıp büyür. Düzeltme: Aşırı Stok'a
  iade-hakkı HAFİFLETİCİSİ (vekil zaten ölçüldü), Stokta Yokluk'a kanıtlı-talep AĞIRLAŞTIRICISI.
  (b) ✅ **KAPANDI 12.09** — kart artık **eşik ÜSTÜ fazla kısmın MALİYETİ**ni gösteriyor
  (72,5M ₺); alt satırda tüm stok maliyeti 110,5M ve etiket 321,5M da yazılı. Kapsam beyanı:
  maliyeti bilinen 28.974/30.403 çeşit (%95,3) → rakam ALT SINIR. Danışmanın istediği
  "maliyete geç"ten bir adım ileri: eşiğe kadarki stok meşru, ceza yalnız fazlaya yazılır.
  ~~(b) AŞIRI STOK KARTI ETİKET FİYATIYLA~~ — 329,0M ₺ gösteriyor, maliyetle 107,3M ₺;
  alıcıya ~3 kat şişik ceza. Envanter Değeri kartında maliyetli değer VAR, Aşırı Stok'ta YOK.
  En kolay ve en büyük düzeltme bu.
  (c) ✅ **KAPANDI 12.09 — eşiğe İŞ MODELİ AYAĞI eklendi.** Ölçüt artık iki ayaklı: sezon
  katı (2×) VE ikmal kapağı (5× · kapak = (LeadTime+30) × max(365g hız, sezon hızı)). Kat 5
  veriden DEĞİL hedeften: devir hedefi 2,0 (=182 gün stok) ÷ ortalama döngü 35,03 gün = 5,21.
  ⇒ hızlı temin edilen üründe eşik SIKI, yavaşta GEVŞEK; Altman & Royston "kesimin bedeli"
  uyarısı bu ayağa işlemez. **Sezon ekseninin yanlış pozitifi ölçüldü:** sezon işaretli ama
  kapak temiz 4.904 çeşidin medyan yıllık devri **2,25**, temiz grubun medyanı **2,40** —
  ayırt edilemiyor, yani sağlıklı dönen mal damgalanıyordu. Panelde: 40.017 → **37.103 çeşit**,
  fazla maliyet 83,3M → **74,7M ₺** (ceza %10 AZALDI). Arşiv:
  `sorgular/2026-09-12-esik-is-modelinden-kapak.sql`. İADE HAKKI eşiğe girmedi — hafifletici
  olarak duruyor (B-172a), çünkü ürün bazında iade hakkı veride yok, vekil kullanılıyor.
- [ ] **B-172(c2) AŞIRI STOK KARTININ KÖR NOKTASI — sezon kapısı (ÖLÇÜLDÜ 12.09, KARAR BEKLİYOR)** —
  Ölçüt `SezonToplam > 0` şartı taşıyor: sezon DIŞINDA satan **63.565 çeşit / 132,2M ₺**
  (medyan yıllık devir **0,50** — yani 2 yıllık stok) aşırı stok kartında HİÇ görünmüyor.
  Ölü Stok da almıyor (satıyorlar). Sezon kapısını kaldırıp tümüyle kapağa geçmek ölçüldü:
  37.460 → **94.021 çeşit**, fazla maliyet 81,6M → **170,2M ₺** = ceza **2,1 KAT**.
  Ara seçenekler ölçülü: kapak 8× → 76.091 çeşit / 137,1M ₺ · kapak 12× → 55.570 / 110,1M ₺.
  ⚠ Alıcıya bakan sayıyı ikiye katladığı için tek taraflı UYGULANMADI (before-major-change §4).
  Karar kullanıcıda: (i) kalsın, kör nokta kapsam bandında yazılı · (ii) kapak 12×'e geç
  (ceza +%35) · (iii) tümüyle kapak 5× (ceza 2,1 kat).
  (d) ✅ **KAPANDI 12.09 — itirazdan BÜYÜK çıktı.** Kırtasiye hariç yeniden ölçülünce asıl
  hata göründü: türetme **ORTALAMA** devir kullanıyordu, dağılım sağa çarpık olduğu için eşik
  şişiyordu. MEDYAN ile: panel geneli 3×→**2×**, Hazırlık Kitapları 8×→**2×** (dört kat hata),
  Kırtasiye monoton olmadığı için **türetilemez** (danışmanın (c) itirazının kanıtı).
  Wilson GA da yalnız 2× kesimini destekliyor. **Kategori bazlı eşik KALDIRILDI, tek eşik 2×.**
  Etki: 30.361→40.017 çeşit · 72,5M→83,3M ₺. Arşiv
  `sorgular/2026-09-12-esik-medyan-ile-yeniden-turetildi.sql`.
  ~~(d) Panel geneli 3× artık DESTEKLENMİYOR:~~ karma örneklemden türetilmişti ve onu Kırtasiye
  domine ediyordu (bantlarında 7.480 çeşit). Kırtasiye ayrıldı → kalan sekiz kategori başka
  bir kategorinin eşiğiyle yargılanıyor. 3× Kırtasiye HARİÇ yeniden ölçülmeli.
  (e) ✅ **KAPANDI 12.09** — eşik 0 → 1. ÖNCE ÖLÇÜLDÜ: tek POS satışıyla kohorttan çıkan
  **9 çeşit / 29.116 ₺ etiket / 14.915 ₺ maliyet** (kohort 115.923 çeşit / 144,2M ₺ →
  çeşidin %0,008'i). Açık gerçek ama fiilen küçük; kapı yine de kapatıldı (maliyeti sıfır).
  ⚠ "FARKLI GÜNLERDE" şartı UYGULANMADI — tabanda POS gün sayısı yok, 9 çeşit için taban
  şeması değiştirmek orantısız. Ölçülmüş erteleme.
  ~~(e) GAMING: `PosAdet > 0` adet eşiği taşımıyor~~ → TEK satış ürünü ölü stok kohortundan
  çıkarır (personel/iç kart satışı yeter). Düzeltme: `PosAdet >= 2` ve farklı günlerde.
  (f) **GAMING:** kategori ürün kartında değiştirilebilir; 2× kategoriden 8×'e taşınan ürün
  kohorttan çıkar. Kategori değişimi izlenmiyor. (ŞÜPHELİ — fiilen olup olmadığı ölçülmedi.)
  (g) ✅ **KAPANDI 12.09** — `KpiKart.Sahip` alanı + taban satırının sağında rozet.
  Dokuz eylem kartına atandı (satınalma 4 · operasyon 4 · satınalma+finans 1); ölçüm/nötr
  kartlarda sahip YOK (uydurulmaz).
  ~~(g) Sorumluluk sahibi etiketi yok:~~ "ölü stok → iade/imha" satınalma+finans, "raf bulunurluk
  → transfer" operasyon; 8.736 çeşit el değiştirdi ve kohort sahibi panelde yazılı değil.
  (h) "Gir çık" kartları Veri Kirli'ye taşındı ama o bir EYLEM kartı değil — 327 çeşit /
  931K ₺ orada birikip kimsenin işi olmuyor.

- [ ] **B-171 Satış Analizi — BEYAN EDİLDİ ama DÜZELTİLMEDİ (bilinçli borç listesi)** — 10.09.
  Hepsi panel kapsam bandında yazılı; kapatmak ek iş/karar ister:
  (a) **Aralıklı talep tahmini yok** — sınıflandırma var (ADI 1,32 · CV² 0,49), Croston/SBA/TSB
  ayrıştırması YOK. Çeşitlerin %91,9'unda gün-stok hesaplanmıyor ("—" gösteriyor); sipariş
  önerisi üretilmiyor. Kapatmak: SBA tahmini + emniyet stoğu → yeni hesap katmanı.
  ✅ **PANELE GİRDİ 11.09 (plan-46, commit sonraki satırda):** sipariş çekirdeği
  `dashboard/Data/SatisAnaliziQueries.Siparis.cs`; SATINALMA grubu + Sipariş İhtiyacı kartı
  (40,7M ₺ · 13.246 çeşit · 272.382 adet · ACİL 3.151) + 3 liste kolonu + 2 durum filtresi.
  KALAN: SBA/TSB beklenen değeri hâlâ yok (365g/sezon hızı vekil) · MOQ/koli katı veride yok ·
  panel↔Excel çeşit farkı %1,5 (yuvarlama, beyan edildi).
  ⚙ **KISMEN 10-11.09:** `siparis-karari` skill'i (miktar formülü + emniyet stoğu + taahhüt +
  çıkış planı) yazıldı, emitter `scripts/siparis_onerisi_excel.py` koştu. **Kohort 11.09'da
  düzeltildi** (kullanıcı: "çok çok az … emin misin"): ölçüt `ToplamStok = 0` idi ve gerçek
  ikmal ihtiyacının ~1/13'ünü görüyordu; artık **kapak altı** (`stok < hız × (temin+30)`),
  eldeki stok öneriden düşülüyor, satırlar ACİL/İKMAL ayrılıyor.
  Kitapdışı A listesi: 416 çeşit / 2.291 adet / 376.516 ₺ → **1.549 çeşit / 29.295 adet /
  1.942.711 ₺** (12-hafta plan cirosu 11,77M ₺).
  KALAN: hesap KODA girmedi — SBA/TSB beklenen değeri hâlâ yok, skill 365g/sezon hızını
  vekil alıyor ve emniyet σ'sını CV²'den türetiyor. Panelde sipariş kolonu YOK.
  (b) **Maliyet yaşı sapması** (B11) — satış 365 günlük, maliyet bugünkü. Maliyet yaşına göre
  marj %24,4 (<3 ay) → %63,0 (2+ yıl). Enflasyon ile yavaş devir AYRIŞTIRILAMIYOR; maliyet
  yeniden DEĞERLENMEYECEK (uydurma olurdu). ✅ **GÖRÜNÜR KILINDI 10.09:** `MaliyetTarih`
  tabanda · drill'in maliyet kutusunda son alış tarihi yazılı · listede **Maliyet Tarihi +
  Maliyet Yaşı** kolonları (sıralanabilir; yaş KESİM tarihine göre, bugüne göre değil).
  Marjı şişkin olabilecek ürünler artık süzülebiliyor. KALAN: sapmanın enflasyon payı
  ölçülemiyor — bu bir veri sınırı, kapanmayacak.
  (c) ✅ **KAPANDI 10.09** — kategori bazlı eşik ölçümle türetildi: Kırtasiye **2×**
  (devir 1,25, monoton) · Hazırlık Kitapları **8×** (devir 3,16, monoton) · kalan sekizde
  panel geneli 3× (bant eksik / monoton değil / n<30 → "ölçemediğimi değiştirmem").
  Etki: Kırtasiye 9.897 → 11.679 çeşit (+27,8M ₺) · Hazırlık 1.427 → 460 (−7,0M ₺);
  panel 308,3M → **329,0M ₺ / 30.439 çeşit**. `bkm.OneriSiparisKtg3Ondeger` politika tablosu
  kullanıcı kararıyla **İPTAL** — eşik ölçümden gelir. Arşiv
  `sorgular/2026-09-10-kategori-bazli-asiri-stok-esigi.sql`, sema
  `asiri_stok_esigi_kategori_bazli`.
  (d) **Rafa Çıkmamış Envanter'in %12'si merkezde ≤2 adet** (129/1.068) — karşı-metrik adet
  gösterdiği için yanıltma sınırlı, ölçüt daraltılmadı.
  (e) **Kayıp satış tahminleri alt sınır** — sağdan sansürlü talep; EM düzeltmesi
  (Anupindi/Dada/Gupta · Conlon & Mortimer) uygulanmadı.
  (f) **Defter doğruluğu ölçülmemiş** — panelin %0,12'si yalnız aritmetik imkânsız kayıtlar;
  literatürde IRI %50-70. Gerçek sapma yalnız fiziksel sayımla bilinir.
  (g) **Sektör devir hedefi uygulanmadı** — Kitap 1,28 / Kırtasiye 1,25 vs hedef 3,0-4,0;
  eşiği oraya çekmek 200 bin+ çeşidi kohorta sokardı. Kıyas ticari kaynak (ÇIKARIM).

- [ ] **B-167 Satış Analizi — kullanıcı kararı bekleyen üç eşik/adlandırma** — 09.09. (a) KPI **"Bağlanan Stok"** adı maliyeti ima ediyor ama **satış fiyatı** gösteriyor (ölçülen bir üründe 4,6× fark) → ad mı taban mı değişecek? (b) ✅ **eşikler artık ÖLÇÜLDÜ (10.09)** — aşırı stok **5× → 3×** (2024 stoğunun sonraki 12 ayda satılan oranı 3×'te 1,0'ın altına düşüyor: 29.647 çeşit / 309,9M ₺ etiket · 107,3M ₺ maliyet) ve sezon açığı **0,50 doğrulandı** (aynı talep bandında gerçekleşme <0,25→0,34 · 0,25-0,50→0,61 · 1,00-1,50→0,93); türetme `sorgular/2026-09-10-esik-turetme-asiri-stok-ve-sezon.sql`, sema `asiri_stok_esigi_turetildi`/`sezon_hazirlik_esigi_turetildi`. **Confound beyan edildi:** ters nedensellik + ortalamaya dönüş giderilmedi. ✅ **KATEGORİ BAZLI EŞİK KAPANDI 10.09** (Kırtasiye 2× · Hazırlık Kitapları 8× · kalan sekiz 3×, ölçümle); `bkm.OneriSiparisKtg3Ondeger` politika tablosu kullanıcı kararıyla İPTAL edildi. AÇIK KALAN: sipariş noktasındaki %50 emniyet payı hâlâ ÇIKARIM. (c) ✅ **iade hakkı KISMEN çözüldü (10.09)** — `frmIadeKural` kodunun anlamı hâlâ teyitsiz (B-150) ve ölçüm koddan anlam çıkmadığını gösterdi, ama tedarikçinin **gözlenen iade oranı** vekil olarak çalışıyor: aşırı stoğun %25,2'si (77,6M ₺) iadesi %2 altındaki tedarikçilerden. Panelde kırılım YAPILMADI (vekilin dört sınırı var: hak≠davranış · tedarikçi düzeyi · ters nedensellik · %14,8 tedarikçisi bilinmeyen), kapsam bandında beyan edildi.
- [ ] **B-168 Drill gecikmesi ÖLÇÜLDÜ — kök sebep sorgu sayısı DEĞİL** — 09.09 (ölçüm tamam, bir karar bekliyor).
  - **Ölçüm (curl min, production DB meşgul → min en az gürültülü):** `/login` (Blazor değil) 214 ms · `/not-found` 214 ms · `/ayarlar` (layout'lu, hafif) **264 ms** · liste 1.024 ms · **drill 986-1.072 ms**. Layout suçlu DEĞİL.
  - **BULGU 1 — akran sorgusu (ÇÖZÜLDÜ):** `GetAkranAsync` DMV'de ort. **1.096-1.262 ms / 470.803 mantıksal okuma**. Maliyet izole edildi (sqlcli tabanı 1.389 ms düşülmüş): yalnız `COUNT(*)` 64 ms · **tek `PERCENTILE_CONT` 376 ms** · `COUNT OVER`+4 PERCENTILE 692 ms → suçlu `COUNT(*) OVER ()` değil, **PERCENTILE_CONT pencere fonksiyonları**. ⚠ Aynı dosyanın 78. satırı bu anti-pattern'i "sayfa başına 1,2 s ekliyordu" diye yasaklıyor, 179. satırda kendisi kullanıyordu. **Düzeltme:** sorgu aynen kaldı, akran medyanı `IMemoryCache`'e alındı — (Kesim, SezonYil, Kategori1) için sabit, 42 kategori, 30 dk. Doğrulandı: 5 drill → DMV koşum 86→87. Build yeşil.
  - **BULGU 2 — reddedilen iki çözüm (ikisi de ÖLÇÜLDÜ, ikisi de daha kötü):** (a) 9 sorguyu tek `QueryMultiple`'a toplamak — ilk önerinin gerekçesi ("round-trip birikir") sorgu ÇALIŞMA süresini açıklamıyordu; (b) `ROW_NUMBER` tabanlı medyan — CTE materialize edilmediği için taban 5 kez taranıp sıralanıyor, **>40 s** (60 s timeout, iptal). PERCENTILE_CONT bundan çok daha iyi.
  - **BULGU 3 — asıl kalan sebep: her bağlantı FAZLADAN bir round-trip atıyor.** `Db.OpenWithRetryAsync` her `OpenAsync()`ta ayrı komut olarak **`SET DATEFORMAT dmy;`** çalıştırıyor (Db.cs:157-162). DB sunucusuna RTT **ort 30 ms / min 16 ms** (ping, 192.168.40.201). Drill 9 bağlantı × 2 gidiş-dönüş (SET + sorgu) ≈ **450 ms**; +264 ms layout ≈ 714 ms → ölçülen 986 ms'i açıklıyor. Drill'in TÜM sorguları DMV'de ≤15 ms (1,4-11 ms) — yani gecikme veritabanı işinde değil, **round-trip sayısında**. Etki alanı: app'te **135** `db.OpenAsync()` çağrısı, hepsi bu bedeli ödüyor.
  - **KALDIRMA RİSKİ TARANDI:** dashboard'ın kendi SQL'inde DATEFORMAT'a bağımlı **string tarih literali YOK** — `CONVERT(...,104)` kullanımlarının hepsi tarih→varchar ÇIKTI biçimlendirmesi (DATEFORMAT etkilemez). ⚠ AMA tek gerçek bağımlılık **asistan**: `AsistanService.cs:147` LLM'e "Tarih DMY" talimatı veriyor, LLM'in ürettiği SQL dmy literali taşıyabilir → blanket kaldırma o yolu bozar.
  - **UYGULANDI (kullanıcı onayı: "SET'i sorgu metnine önek yap") — ama ölçüm daha iyi bir yol gösterdi:** SET'i öneklemek yerine **tamamen kaldırıldı**. Sebep: o SET bir **NO-OP**'tu — login `sa` varsayılan dili zaten `Türkçe`, `@@LANGUAGE='Türkçe'`, `sys.syslanguages` Türkçe → `dateformat=dmy`; SET'siz `CONVERT(date,'13.06.2026')` doğru parse ediyor. Garanti sessiz sunucu varsayılanına bırakılmadı: bağlantı dizesine **`Current Language=Turkish`** eklendi (login sırasında, ek round-trip YOK) → round-trip yarıya inmedi, **sıfırlandı**. `dateformat` parametresi ve SET bloğu `Db.cs`'ten silindi (orphan).
  - **ÖLÇÜLEN SONUÇ (curl min / medyan):** drill **986 → 686 ms** min, **1.235 → 758 ms** medyan · liste 1.024 → 907 ms · ayarlar 264 → 250 ms · login 214 → 210 ms (değişmedi, Blazor değil). Akran cache'i ile birlikte drill **1.365 → 686 ms (−50%)**. Build yeşil, 0 hata.
  - **ÜÇGEN DOĞRULAMA (pyodbc):** dil verilmezse dmy OK · `Language=Turkish` dmy OK · **`Language=English` → `CONVERT(date,'13.06.2026')` "Conversion failed"**. Yani ayar taşıyıcı, sessiz değil.
  - **Değişmez eklendi:** `turkish-dili-dmy-verir` (38 kayıt, 38/38 yeşil). ⚠ İlk hali `@@LANGUAGE`'a bakıyordu ve KIRDI — çünkü koşucu (pymssql) **`us_english`/`mdy`** oturumu açıyor; ölçüm koşucunun oturumunu ölçüyordu, uygulamanın değil (kapsam uyuşmazlığı). Bağlantı-bağımsız gerçek bağımlılık `sys.syslanguages` Turkish tanımı → SQL o forma çevrildi. Ürün drill her istekte bir canlı sorgu daha aldı (ürün · akran · maliyet · aylık satış · aylık alış · aylık stok · hız · açık sipariş · görsel). Tek ürün olduğu için hızlı (ölçülmedi, kullanıcı yavaşlık bildirmedi) ama sayı artarsa round-trip birikir. **Önce ÖLÇ** (toplam süre), 500 ms'i aşıyorsa birleştir; aşmıyorsa dokunma (spekülatif optimizasyon yasak).
- [ ] **B-165 Sezon-kadro sunumu yeniden üretilsin mi? (KULLANICI KARARI)** — 08.09 (B-164'ten doğdu). `scripts/verimlilik_cek_hacim.py` + `verimlilik_excel.py` 02.09'daki sezon-kadro savunma paketini üretti ve `eTip=100` tek başına kullanıyor. Doğru formülle yeniden üretilirse: 3 mağaza toplamı +%0,5 (sonuç DEĞİŞMEZ — adet +%34,9 / kadro +%11,9 karşılaştırması ayakta), ama **İst.Yolu şube satırı +%2,7..4,4 yukarı kayar**. Paket patrona sunuldu; geriye dönük değiştirmek mi yoksa bir sonraki üretimde mi düzeltmek istenir? Karar verilene kadar script'te uyarı başlığı var.
- [ ] **B-163 Kartlı müşteri YoY ölçülemiyor (taban 2026)** — 08.09. EncoreMerkez'de kartlı fiş payı Ağu-2025 %0,3-1,4 → Ağu-2026 %77,4-81,9; tekil kartlı FSM 69 → 17.999. Bu müşteri büyümesi DEĞİL — sadakat kartı yakalaması POS geçişi sonrası (2025 sonu/2026 başı) devreye alınmış. Etki: RFM/sadakat/kartlı-kartsız raporlarında 2025 tabanı KULLANILAMAZ. YAPILACAK: (a) kart yakalamanın gerçekten hangi tarihte devreye girdiğini ölç (aylık kartlı-fiş payı serisi), (b) o tarihi `sema/metrics.yaml`'a yapısal kırılma olarak yaz (pos_sistem_gecisi_2025 kardeşi), (c) mevcut müşteri raporlarında 2025 kıyası var mı tara. Kanıt: sema `CELISKI_KARTLI_MUSTERI`.
- [ ] **B-136 Satınalma DINAMIK+Python retail-floor BİREBİR doğrula** — 14.08. Kod yazıldı (89c7b24) ama dashboard'la mutabakat SSMS+`python satinalma_hesap_sorma.py` ile yapılmadı (openpyxl karşılaştır). Retail-cap/fiş-gate/floor 3-emitter aynı olmalı.
- [ ] **B-137 Bulunurluk pre-agg re-run** (recency fix uygulanması) — 14.08. `sorgular/2026-08-14-bulunurluk-ozet-generate.sql` çalıştır → dated/ölü ürün (ajanda) düşer. Sonra dashboard doğrula.
- [ ] **B-138 Bulunurluk nightly SQL Agent job** (dense→pre-agg) — 14.08. Swap-pattern/SP versiyonu (zero-downtime). Tasarım hazır, script yazılacak.
- [~] **B-162 Patron Soruları paneli (plan-37)** — 29.08. **Faz A ✅ CANLI**: `/patron-sorulari` — 25 soru, 6 departman, rozet (9 ✅ · 8 🟡 · 7 ❌ · 1 ⬜) + kova filtresi + drill link. Registry `dashboard/Models/PatronSorulariRegistry.cs` (tek kaynak `docs/2026-08-29-patron-sorulari-kapsam.md`), `Dogrula()` 5 kontrol (soru sayısı · mükerrer ID · NavRegistry orphan route · rozet↔route tutarlılığı · parçalı-eksik/boşluk-iş zorunluluğu) sayfa tepesinde uyarı basar. Build yeşil, preview doğrulandı (masaüstü + mobil). **Faz B ⚠ KOD TAMAM / ÖLÇÜM YARIM**: `PatronSorulariQueries.cs` 6 mini-metrik (hedef-gerceklesme · mtd-ciro · acik-gorev · hediye-ceki-12ay · bulunurluk-oos · bekleyen-kargo), hepsi mevcut `*Queries`'i ÇAĞIRIR (SQL kopyası YOK — emitter-ayrimi), Stopwatch + 2 sn eşiği (aşarsa log uyarısı + ekranda süre sarı), memo (PS-1.1/1.2 tek sorgu), hata sessiz değil (ekranda kırmızı 'alınamadı'). Blok bazlı lazy — sayfa açılışında sorgu koşmaz. **29.08 ölçüm oturumunda ERP sunucusu (192.168.40.201) AĞDAN ERİŞİLEMEDİ** (ping %100 kayıp) → yalnız `acik-gorev` ölçüldü: **17 ms**, mutabakat ✅ (/gorevler '3 açık' = panel '3'). **KALAN:** 5 metriğin süre ölçümü + hedef sayfa mutabakatı (ağ gelince tek koşu); >2 sn çıkan Faz A rozetine geri alınır. Ayrıca hata yolu canlı doğrulandı (SQL timeout → '— alınamadı 20962 ms' sarı süre). · (b) **Faz C** — departman bloğu "Sen olsan ne yapardın?" butonu (şu an disabled) → o departmanın danışman rolüyle `AsistanService`; cevaptaki sayılar ekrandakiyle aynı olmalı (uydurma kontrolü) · (c) plan `plans/archive/`'a.
- [ ] **B-161 Kişisel veri maskeleme modları (`scripts/beyaz_yaka_maas_excel.py`)** — 29.08. Bugün yalnız açık (yetkili) mod var; çıktı `.gitignore`'landı (commit 1f2502d) ama **paylaşılabilir sürüm yok**. İki mod eklenecek: (a) `--maskeli` → Ad Soyad `A.Y.`, Personel No sıra no, `Cinsiyet`+`OgrenimDurumu` sorgudan HİÇ çekilmez; (b) `--toplu` → satır yok, Departman×Unvan bazlı n/min/ort/max/toplam maliyet, **n<5 hücre gizli (`—`)**. ⚠ Gerekçe: yıldızlama tek başına KORUMAZ — 27 departman × 59 unvan kırılımında hücrelerin çoğu 1 kişilik, `Departman+Unvan+Net` üçlüsü kişiyi tekilleştirir (k-anonymity). Gerçek koruma toplulaştırma; `--maskeli` çıktısına "tek kişilik satırlar hâlâ tanınabilir" uyarısı basılır. Ayrıca varsayılan modda Cinsiyet/Öğrenim gerekli mi sorgula (veri minimizasyonu) — ücret adaleti analizi yapılmayacaksa çıkar. Kural kaynağı: `.claude/skills/ik-danisman/SKILL.md` §2 KVKK sınırı. Kullanıcı 29.08: "dursun şimdilik".
- [x] ✅ **B-142** Ayarlar altyapısı (plan-34) — **18.08** commit b916f25. `/parametreler`: iade-kural kodları · atıf-dışı hesaplar · hesap birleştirme · ratchet penceresi · atıf pencere başı + (B-145'te) ilişkili-taraf frmID listesi. Hepsi PanelAyar (app-local), hardcode yok.
- [x] ✅ **B-143** Ratchet / sistematik aşırı-alım kolonu — **18.08** commit b916f25. `#alay`+`#rat` tek geçiş, bayrak çekirdekte (@ESIK). Canlı Tem'26: 111 ürün ⚠TEKRAR + 417 ↓TERS. HP kümesi (1701937-44) 8/8 yakalandı 7,7×-14,1×. **Tanım düzeltildi:** 'alım↑+satış↓' HP'yi kaçırdı (yeni ürün rampası) → '≥3 ayda alım + basit kapsam > eşik', GENÇ muafiyetinden bağımsız.
- [x] ✅ **B-144** Stockout karşı-metriği — **18.08** commit b916f25. `#kayip` (bkm.BulunurlukKayip en güncel dönem) → 📉KURU rozeti (24 ürün) + `AZ ALMIŞ` yeşil→NÖTR (ters teşvik dengesi; ratchet ile aynı sürümde çıktı).
- [x] ✅ **B-145** Fiyat sapması sekmesi — **18.08** commit 59367bb. Yeni partial `SatinalmaQueries.FiyatSapma.cs`, tıklanınca yüklenir. Canlı: 1.577 ürün / 2.703.020 ₺ dış-tedarikçi farkı. **3 adalet filtresi:** birim<1₺ hariç (jenerik SKU %3M fark üretiyordu) · ölçek-uyumsuz >10× ayrı kova (4) · GRUP-İÇİ ilişkili taraf ayrı kova (577 satır / 1.832.638 ₺ = transfer fiyatlaması). Üçü de şeffaf sayı ile gösterilir.
- [ ] **B-151 sema entity boşluğu (curator A7-A9)** — 18.08. Kodda kullanılan ama `entities.yaml`'da OLMAYAN objeler: `dbo.fat`+`dbo.fatAyr` (alış faturası = birim fiyatın kanonik kaynağı, B-145 bunun üstünde) · `stokSon_vw` (kardeşi `stokSonAltDepo_vw` kayıtlı, bu değil) · `urnKtgr2`/`urnMrk`/`urnBrkd`/`posMagaza`/`irsAyr`/`irsTip_vw`/`frmTipTnm` · `bkm.ENVANTER_RAPORU`/`MayKampanyaTahmin_2026`/`ent.tsoft_urun`. TOPLU DEĞİL — dokunuldukça (footprint-ladder). Ayrıca `bkm.urunbilgi` küçük-harf kullanımı → `bkm.UrunBilgi`'ye normalize. Rapor: `docs/curator/REPORT-2026-08-18.md` A7-A9. **A6 (Bulunurluk) ✅ kapandı.**
- [x] ✅ **B-152 canlı şema doğrulaması (curator A10)** — **18.08** tamamlandı. 60 objeden 59 mevcut; 25+ tabloda pk/key kolonları birebir uyumlu (642 kolon karşılaştırıldı), eksik/yanlış kolon YOK. `bkm.MayKampanyaTahmin_2026` yanlış alarm (CREATE scripti var, tablo yok, tüketen kod yok). Tip düzeltmesi: `bkm.UrunBilgi` VIEW. YENİ TUZAK: kolon adı case tutarsızlığı (`irsHrk.ehstkID` vs `fatAyr.ehStkID`) → ai_hints. KALAN: çapraz-DB objeler (EncoreMerkez/DerinCrm/BKMDATA/BKMMaliyet/ODAKJOKER/Mosaik) ayrı bağlantıda doğrulanacak.
- [x] ✅ **B-146 Atıf sekmesi (plan-34)** — **19.08** ÖNERİ-SAPMASI temelli 'Talep Sapması' sekmesi canlı. Bulgu: sirac.yigit+omerfaruk %100 AYNEN (öneri motorunu onaylıyor, karar koymuyor) · ist.cocuk %56 FAZLA (en çok müdahale) · ozl.kultur %97 aynen. Uç-sapma kırpma [-100,+200] + kırpılan sayı şeffaf (ist.kirtasiye %262→%49). Eski madde: — 18.08. **⚠ ÖNCE ÖNERİ-SAPMASINI KULLAN** (sema'da kayıtlı, mükerrer-birleştirmede kurtarıldı): `SiparisMiktar − OneriSiparis.OneriSiparisAdet` aynı Tarih/MekanId/StkId → öneri motoruna göre insanın sapması = en adil atıf metriği (ham talep hacmi benimseme asimetriğinden etkilenir, sapma etkilenmez). Ayrıca: Ekleyen=KARAR / Onaylayan=KONTROL ayrımı; kullanıcı alanları VARCHAR-isim (drn1 join YOK, SayimKullanici.AdSoyad köprüsü); EvrakNo MalKabul köprüsü DEĞİL (SipId→sip). `bkm.OneriSiparisTalep` (EkleyenKullanici+OnaylayanKullanici) → Alım Analizi'ne bağla. ZORUNLU kısıtlar: pencere ≥01.02.2025 · yalnız ORAN/aktif-güne normalize (mutlak talep/adet UI'da YASAK — benimseme asimetrisi İst.Yolu %70) · whitelist filtresi (hakan.cetin yazılımcı, kubra.kulaksizoglu iç denetim HARİÇ) · eren.boran+eren.boran2 BİRLEŞİK · unvan etiketi YOK (roller zaman içinde değişti) · FSM'de isimli hesap yok → şube-arası kişi kıyası KAPALI. Ayar altyapısı B-142'de hazır, sema'da tüm kurallar yazılı.
- [x] ✅ **B-153 SATINALMA ekseni atıf (plan-34, YENİ)** — **19.08** kullanıcı direktifi: "mağaza ile satınalmanın verdiği siparişler ayrı şeyler, ikisine de ayrı hesap sormak gerekiyor". `dbo.sip` eTip 0 (Alış) + 3 (Yerel Alım) → "Kim Karar Verdi" sekmesine ikinci blok. Kadro Ayarlar'dan (48 Onurhan · 76 Aydın); Samet (mal kabul) / Erkan (IT) / Mesut-Yusuf (depo) / entegrasyon (sistem) HARİÇ. Canlı: Onurhan 913 sip/94 ted., Aydın 651/64. ⚠ sipTip_vw okunmadan eTip 9 "alım" sanılıp Samet satınalmacı gösteriliyordu — düzeltildi.
- [ ] **B-154 sipariş kapama/karşılanma kontrolü (keşif)** — 19.08 kullanıcı sorusu: "sipariş girişi var mı, sipariş kapama kontrolü yapabilir miyiz". VERİ DURUMU: (a) `sipAyr.ehSevkAdet` TAMAMEN NULL → kullanılamaz · (b) `irsAyr.ehSipID/ehSipSira` bağı MEVCUT ama doğrulanamadı (ilk "%85 bağlı" ölçümü LEFT JOIN fan-out ile şişmişti; Haziran-2026 örneklerinde karşılanma 0) · (c) `sip.eDurum` 0/1/2 dağılımı var ama 0↔1 anlamı TEYİT BEKLİYOR (kapandı mı açık mı?). YAPILACAK: eDurum kod anlamı (muhasebe/DerinSIS sorusu veya sipariş ekranı incelemesi) + yaşlı siparişlerde (2025 Q1-Q2) gerçek karşılanma ölçümü (fan-out'suz, ön-toplamalı) → doğrularsa "açık sipariş yaşlandırma" kartı. Bu ölçüm tedarikçi başarısızlığı ile alıcı hatasını ayırmak için ŞART (confound).
- [x] ✅ **B-155 SinavQueries + SinavModels (plan-35)** — **19.08** tamamlandı. Build yeşil (0 uyarı). CANLI MUTABAKAT (dönem 8): KPI net 18.573.991,29 ₺ KDV hariç = kova toplamı (16.315.938,96 Paket + 805.811,86 Kıyafet + 1.452.240,47 Yan) BİREBİR. Satış fiş 341 · iade 6 · sipariş 366 · ort sepet 50.748,61. ⚠ TASARIM KARARI: satış tarafı FE'den, İADE tarafı `Sales.LinkedDocumentId`'den (FE kısmi iadeleri kaçırıyor — dönem 8'de 9.228,00 ₺ fark); kova+attach ortak `FisSet` CTE'sinden okur → sayfada iki farklı ciro çıkmaz. DI kaydı da yapıldı (B-157'nin yarısı). Orijinal 19.08. `/sinav` sayfasının veri katmanı: 5 metot (sezon KPI · ödeme sağlık · eksik kalem · yan ürün attach · iade radarı). Kaynak `sorgular/2026-08-19-sinav-*.sql` (7 dosya, canlı doğrulanmış). ZORUNLU: 3-parçalı isim (`Db.OpenAsync` master bağlamı) · `OUTER APPLY TOP 1` SiparisDetay fan-out'a karşı · `@DonemId` PARAMETRE (hardcode 8 geçmişi siler — 8.998 fiş vakası) · tutar `TotalPrice − VatTotal` (KDV hariç) · `SinavUrun.Fiyat` (SiparisDetay.BirimFiyat NULL).
- [x] ✅ **B-156 Sinav.razor 5 bölüm (plan-35)** — **20.08** tamamlandı. `/sinav` · dönem dropdown (varsayılan en güncel) · 5 bölüm. Canlı smoke (dönem 8, port 5113): kova toplamı 19.361.373 ₺ = KPI net ciro BİREBİR · attach %84,2 (303/360 fiş) · eksik kalem 58 (tedarik 9/31.849 ₺ + tahsilat 49/33.753 ₺) · çelişki uyarısı 37 sipariş kırmızı alert. Mobil 375px yatay taşma YOK, 3 tablo `overflow-x:auto`. Konsol hatası yok. ⚠ `@inject SinavQueries Sinav` bileşen adıyla çakıştı (CS0542) → `SinavQ`. Orijinal 19.08. DaisyUI token, hardcode hex YOK. Her tutarın yanında "KDV hariç" etiketi. Dönem dropdown. Flag çelişkisi > 0 → `text-error`. Eksik kalem tablosunda stok var/yok rozeti. Mobil 375px + `overflow-x-auto`. 300 satırı aşarsa sub-component (code-behind DEĞİL — markup RenderFragment kuralı).
- [x] ✅ **B-160 dönem dropdown DİNAMİK (plan-35)** — **20.08** kullanıcı direktifi: "dönem dinamik olmalı, şimdi 8 var sonra 9 da olacak" + "düşmesin, tanımı olan tüm dönemler gelmeli". Kaynak `snv.Donem` (CROSS APPLY sipariş + OUTER APPLY fiş sayısı); sipariş/fiş FİLTRESİ YOK. Yeni sezon `snv.Donem`'e eklendiği an listelenir; tanımsız orphan (−7/−8) tabloda karşılığı olmadığı için girmez. Canlı: 6 tanımlı dönem (D8 380 sip/359 fiş · D7 8.723/8.994 · D6 8.927/0 · D5 9.794/0 · D4 0/0 · D1 13/0). Varsayılan = en güncel FİŞLİ dönem (hardcode ID yok). Fişsiz dönem seçilince BİLGİ BANNER'ı: hangi bölümlerin boş, hangilerinin geçerli olduğu yazılı (sessiz sıfır göstermek yanlış okuma üretir). Smoke: D6 seçimi hatasız, banner göründü, sipariş/ödeme/eksik-kalem bölümleri dolu (3.140 kısmi · 500 eksik kalem / 1.475.198 ₺).
- [x] ✅ **B-157 NavRegistry + DI kaydı (plan-35)** — **20.08** tamamlandı. `NavItem("sinav","Sınav Okulları","graduation-cap")` Hedef Tahmin'den sonra (bölümsüz/ANALİTİK) · DI `AddBkmVeri` grubuna (Program.cs değişmedi). Orijinal 19.08. `new NavItem("sinav", "Sınav", ...)` + `ServiceRegistration.cs` ilgili `AddBkm*` grubuna (Program.cs değişmez).
- [ ] **B-158 mutabakat doğrulama (plan-35)** — 19.08. Sayfa şu rakamları BİREBİR vermeli: 18.08 net ciro 1.211.490,57 · ödeme 294/35/28 + çelişki 35 · eksik kalem 55 satır / 64.521,90 · attach Paket 1.098.902,37 / Kıyafet 35.408,92 / Yan 77.179,28 · iade 298 fiş (171 FE-içi + 127 FE-dışı). `dotnet build` yeşil (dev server kapalı — `preview_stop` önce).
- [x] ✅ **B-159 sema snv.* kayıtları + QA (plan-35)** — **20.08** tamamlandı. `entities.yaml` +7 kayıt (Siparis/SiparisDetay/SinavUrun/SinifKitap/SinavSiparisFisEncore/SiparisFis/Okul) · `bridges.yaml` +3 köprü (sinav-fis-encore · sales-iade-linked · siparisdetay-sales) · 3 dosyada `updated: 2026-08-20`. YAML geçerliliği doğrulandı. QA raporu `docs/qa/2026-08-20-sinav-paneli-veri-dogrula.md`: çek-liste 12/12 temiz (N/A hariç) · cross-source FE.InvoiceTotal = Sales header 19.879.286,19 ₺ **fark 0,00, sapan fiş 0/354** · header↔satır 0 sapma · KPI↔kova 0 sapma · fan-out yok · collation Turkish_CI_AS iki tarafta (COLLATE gerekmiyor). 1 BULGU DÜZELTİLDİ: ödeme kartındaki ciro FE-kapsamlı olduğu için KPI ile 9.228 ₺ sapıyordu → UI'dan kaldırıldı, tek ciro kaynağı KPI. Güven: YÜKSEK. Orijinal 19.08. `entities.yaml`'a: `snv.Siparis` (Odendi bit TARİHÇESİZ + kısmiyi tam sanıyor, 1.787 sipariş) · `snv.SiparisDetay` (OdemesiYapildi kalem-bazlı ödeme · BirimFiyat NULL tuzağı · FisId=Sales.DocumentNo + FisIdSiraNo=SalesProducts.Sequence köprüsü) · `snv.SinavUrun` (Fiyat kanonik kaynak) · `snv.SinifKitap` (FisteGoster ödeme davranışını AÇIKLAMIYOR — hipotez çürütüldü) · `snv.SinavSiparisFisEncore` (iadelerin %43'ünü kaçırıyor, doğru köprü `Sales.LinkedDocumentId`). Ardından `veri-dogrula` QA.
- [ ] **B-147 3 emitter senkronu (plan-34)** — 18.08. Ratchet/stockout/iade/fiyat çekirdek değişiklikleri `sorgular/2026-08-12-satinalma-hesap-DINAMIK.sql` + `scripts/satinalma_hesap_sorma.py`'ye taşınacak; sonra B-136 mutabakat koşusu (dashboard=DINAMIK=Python birebir, Tem'26). emitter-ayrimi kuralı.
- [ ] **B-148 plan-34 kapanış** — 18.08. `veri-dogrula` QA + sema/arşiv güncelleme + plan `plans/archive/`'a taşı.
- [ ] **B-149 SQL dersleri kurala yaz** — 18.08. (a) `CROSS APPLY` içinde `SUM(inner − outer.col)` YASAK (aggregate-outer-reference; ön-toplama tablosuna taşı) · (b) yüzde kolonunda `decimal(6,1)` taşar → `decimal(12,1)` · (c) kategori-payı için satır-başı korelasyonlu alt-sorgu 24,9s → tek GROUP BY. Hedef: `.claude/rules/sql-server-conventions.md`.
- [ ] **B-150 frmIadeKural 0/1/2 anlamı** — 18.08 · **10.09 VERİDEN ÇIKARILAMADI, soru keskinleşti.** Hipotez ("iade hakkı olmayan kodda fiilî iade de olmaz") ölçümle çürütüldü: frmTip=0, son 365 gün — kod 0 → %18,4 [11,6-27,8] · kod 1 → %36,4 [15,2-64,6] · kod 2 → %40,0 [30,5-50,3] tedarikçiye iade yapılmış. Cochran-Armitage chi2(1)=9,86 p=0,0017 anlamlı AMA komşu Wilson aralıklarının hepsi çakışık ve kod 1'de n=11 → ayrım desteklenmedi. **Üç kodun hepsinde fiilî iade var.** ⇒ Muhasebeye sorulacak soru artık "hangi kod iade hakkı var" DEĞİL: **"bu alan bugün bir kural mı taşıyor, yoksa terk edilmiş varsayılan mı?"** Cevap gelince `/parametreler` → iade kodları alanına girilir (B-142 parametrik). ✅ **ARA ÇÖZÜM BULUNDU (10.09):** koda ihtiyaç duymadan tedarikçinin **gözlenen 2 yıllık iade oranı** vekil olarak çalışıyor — aşırı stoğun %25,2'si (77,6M ₺) iadesi %2 altındaki tedarikçilerden, %15,3'ü (47,1M ₺) fiilen iade kabul edenlerden. Dört sınırıyla panel bandında beyan edildi; sema `iade_davranisi_vekili`, arşiv `sorgular/2026-09-10-iade-hakki-vekili.sql`.
- [ ] **B-140 Bulk hareket satırı → FİŞ DETAY drill** — 14.08. TOPTAN-KANAL bulk tablosu satırına tıklayınca belgenin tüm içeriği. Depo sevk (D01): `irs.eID→irsAyr` (kolay). İst.Yolu POS: gerçek fiş EncoreMerkez.Sales'te, DerinSIS irsHrk→EncoreMerkez Sales KÖPRÜSÜ YOK (eNo generic) → önce köprü keşfi (date+mekan+ürün+qty fuzzy? SalesId ortak-anahtar var mı?). Kullanıcı isteği "tıklayınca fiş detayı". POS fiş-detayı = EncoreMerkez.Sales köprüsü (irshrk-pos-encore sema): Products.Code=stkID + Amount + Date/ReceiptNo/CustomersId. Ama irsHrk POS günlük-aggregate → tek irsHrk satırı ≠ tek fiş.
- [ ] **B-139 Satınalma model zaafı: 2024↔2025 vahşi sezon-ayrışması** — 14.08. matara: Okul'24=417 gerçek retail, Okul'25=17 (çöküş), model son-yılı (17) alıyor → riskli. gy_sezon anomalik-düşükse yıl-öncesini de dikkate al? (Tier-3, düşünülecek — kullanıcı domain'i belirler.) **✅ 18.08 KAPSAM NETLEŞTİ:** kanal kırılmasıyla (06.01.2025 e-tic→Point devri) AÇIKLANMIYOR — ölçüldü: Kat3 10/12/16 evreninde depo-sevk akışı kırılmada düşmedi (3,63→3,43M ₺/ay = toptan, e-tic değil); kırılma %94,5 KİTAP kategorisinde. Yani B-139 **gerçek model zaafı** olarak duruyor, veri artefaktı değil. Kanıt: `sorgular/2026-08-18-gl-kanal-kirilmasi-subat2025.sql` blok 9 + sema `mhs.mhsFis_granulerlik_kirilmasi.pencere_denetimi`.
- [ ] **B-141 GL/kitap analizlerinde Şub-2025 kanal kırılması normalizasyonu** — 18.08 (YENİ, kırılma keşfinden doğdu). **06.01.2025'te e-ticaret faturalama Point'e devredildi** (GMY teyidi); kuyruk 15.01'e kadar, 16.01 pratik sıfır → analitik pencere başı **01.02.2025**, Ocak 2025 HİBRİT AY (kıyasa katma). Etkisi: dbo.fat satış faturası 122.145→104/ay, mhsFisBaslik 251.813→7.123, dbo.car 382.563→13.011; depo-sevk KİTAP 74,54M→4,13M ₺/ay (−%94,5). **Dashboard sayısal katmanı MUAF** (pencere denetimi 18.08: ciro/YoY şube-only; envanter/B-110 ehTip 4/100; bulunurluk 2025-08+; satınalma evreni etkilenmiyor). **KALAN İŞ:** (a) B-117 GL forensic'e yıl-kırılımı zorunluluğu (Benford/mükerrer/anomali yoğunluğu/SoD 2024↔2025 kıyaslanamaz), (b) kitap kategorili veya tüm-kategori DerinSIS kıyaslarında kanal-normalize, (c) muhasebe-denetci skill'ine kırılma uyarısı. Kanıt: `sorgular/2026-08-18-gl-kanal-kirilmasi-subat2025.sql` (9 blok).
- [ ] **B-131 Dashboard hedef-widget fix (Kategori — Hedef Gerçekleşme)** — 04.07. `HomeV2.razor` (route "/") + `Home.razor`: önde/geride etiket + dikey-çizgi `PacePct`(takvim) yerine **%100-tabanı** (hedef zaten günlük-prorate). `PacePct` kaldırıldı, tick `left:100%`. `charts.js` PAL→DaisyUI var. HomeV2 ~64 class-hex→token. **Preview'da görsel doğrulandı** (5081). **UNCOMMITTED** — kullanıcı **tam-restart** (dotnet watch @code hot-reload etmez) → widget doğrula. **Kalan:** HomeV2 değer-hex (HeroCard/AppAreaChart/_kColors/gradient) → CSS-var okuması = plan-28 (dark-theme).
- [~] **🔥 B-116 (cross-repo: D:\Dev\fifo) — master ÜRETİLDİ+DOĞRULANDI 19.06** (eski "B-113" ID UI-checklist'le çakışıyordu → B-116). `00_V2_MASTER_FULL.sql` portable+parametrik+curated; boş DB'ye deploy+açılış+aylık 0 hata, maliyetsiz=0, Ocak 25,65M/%35,4=rev2. Açılış geçmiş-doğru (irsHrk-kümülatif) + GARANTİ (1-TL sabit kaldırıldı→devre-dışı) + SonAlış tier. **KALAN:** (1) fifo COMMIT, (2) sızan gerçek-gider stkID-curated devre-dışı, (3) prod cutover (201 kapalı, AYRI onay).
- [~] **B-114 plan-23 (pusula sema)** — ✅ **Faz-1 ÇEKİRDEK İŞLENDİ 19.06**: `sema/entities.yaml` (BKMMaliyet 7 entity), `bridges.yaml` (stkid-urn 1.0/marj-cikis/kategori3-urnktgr2/songecerli-fiyat), `codes.yaml` (KaynakTip/Durum/SorunTipi/HareketTipi), `metrics.yaml` (fifo_karlilik/acilis_stok/garanti_tier/fiyat_0_olamaz/non_inventory). **KALAN Faz-2/3:** (a) dashboard maliyet/marj sayfası (Db.OpenMaliyet + MaliyetQueries + Maliyet.razor), (b) asistan maliyet_sql aracı.
- [ ] **B-115** Negatif-marj 34 hata-şüphe (oran>3): kullanıcı `fifo/raporlar/negatif-marj-hata-suphe-2026-06-19.xlsx` "Karar" kolonunu dolduracak → reprice+ManuelMaliyet (818 gerçek-zarar DOKUNMA).
- [x] ✅ **B-111** WMS bekleyen-sipariş doluluk göstergesi — **22.06** Operasyon sayfasına mini-kart. TEMİZ yol = J_ORDERS e-tic aşama split (`EticQueries.GetBekleyenDurumAsync`: 1000=toplanma/3001,3003,3004=hazırlanan/3006=temin, SENDDATE NULL). DerinSIS `emirAyr` KİRLİ → kullanılmadı (18.06 keşif). Canlı: toplanma 2 · hazırlanan 4.283 · temin 6.185 (yığılma tedarik tarafı, WMS picking güncel). `BekleyenDurum` record + AppRankBars kart. Build yeşil.
- [~] **🥈 B-112** Dashboard hızlı kazanımlar — ✅ **3/4 işlendi 22.06** (Operasyon sayfası, dönem-duyarlı, arka plan yükleme): (a) ödeme-grubu + önceki-dönem Δ (nakit↑=stres uyarı) · (b) iade sebebi `RefundReasons.Type=0` (DocType=3, canlı doğrulandı) · (c) indirim kaynağı `SPC.Source` 0/1/2 (canlı 77,7M/8,9M/6,2M). (d) kasa saatleri = **zaten vardı** (Saat Bazlı Yoğunluk) → atlandı. Yeni: `RefQueries.Operasyon.cs` partial + 3 record. Build yeşil. Render: login-gated (kullanıcı doğrulayacak).
- [x] ✅ **B-110** ⭐ Tedarikçi/Yayınevi performans scorecard — **22.06** (plan-24). Yeni sayfa YERİNE Envanter'e scorecard kartı (footprint-ladder dar basamak): son 12 ay marka net ciro · iade oranı · stok devir hızı (yıllık satış/anlık stok) → sipariş-kes sinyali (<1,5× error / 1,5–3× warning / >3× success). `GetTedarikciPerformansAsync` (satış+stok ayrı derived-table JOIN, OUTER APPLY timeout'tan kaçınıldı) + `TedarikciPerfRow` + kart. İç-operasyon/ev-markası hariç (0/269/2101/5972/10911). Canlı: Faber-Castell 0,46× sermaye tuzağı. Build yeşil. SQL arşiv + sema `marka_devir`.
- [~] **B-117 Muhasebe denetim katmanı (GL forensic / kapanış-müdahale Kontrol)** — **22.06**. Keşif: `DerinSISBkm.mhs` (yevmiye 39,5M, mizan/hesap planı), `dbo.car/carCek/frm/fat` (cari/çek/vade), Fikri kontrol altyapısı (`bkm.sp_Aylik*Kontrol` + `Fin_AyKapanis` + `kontrol_*` view + `mhsMizan_vw`). ✅ Üretildi+işlendi: (1) `sp_KapanisMudahaleKontrol_v2` (CAR+FAT+MHS konsolide, tüm-dönem, özet/detay-drill, severity+forensic) — **DEPLOY EDİLDİ ✅ 22.06** (SP+Fin_AyKapanis DB'de VAR doğrulandı). (2) `muhasebe-denetci` skill (commit 4b6b5b8). (3) **GM "Muhasebe/Kontrol" paneli ✅ YAZILDI** (`Muhasebe.razor`+`MuhasebeQueries.cs`, route `/muhasebe`, SP Dapper EXEC, özet→drill, commit f65a94b). ✅ **Yevmiye fiş detayı (`/yevmiye-fis`) zenginleştirildi 25.06:** audit (giren/değiştiren/onaylayan = `mhsFisBaslik.gKisi/kKisi/oKisi → drn1.insID` + g/k/oTarih) + her satıra üst hesap (`mhsHsp` hspKod-prefix parent); boş imza kutusu kaldırıldı (`Yevmiye.razor`+`MuhasebeQueries.cs`+`MuhasebeModels.cs`, uncommitted). **KALAN:** (a) panel login-arkası görsel doğrulama + v2 çıktı onayı (+ yevmiye audit/üst-hesap render onayı), (c) keşfi sema'ya yaz (mhs/car/kontrol entity+bridge — ikiz yükümlülük borcu) — ✅ **kısmen 25.06 (commit d1e9464):** `fat-mhsfis` (fisbID global-unique), `hesap-usthesap` (prefix parent), `kisi-drn1` (fiş/fatura audit) yazıldı + SQL arşiv; KALAN: car/kontrol_* entity+bridge, (d) ✅ **Fin_AyKapanis yönetim formu YAZILDI 23.06** (`Ayarlar.razor` route `/ayarlar` + `MuhasebeQueries` Upsert/Delete/List MERGE; ekle/güncelle/sil, ay-yıl guard, login-gated, ilk ERP-yazma). 2026 Ocak-Mayıs zaten dolu (Haz açık-normal). **Yazma yolu canlı test edilmedi (login+MCP salt-okuma) — kullanıcı doğrulayacak.** İşaret: fisBA=0 alacak/gelir, fisBA=1 borç/gider (doğrulandı). GM odaklı. **NOT: B-118 (Mizan/likidite dashboard) AYRI track — bu forensic, o mali-tablo.**
- [~] **B-118 Mizan / likidite dashboard (plan-25)** — ✅ **HİYERARŞİK AĞAÇ + KESİN MİZAN 23.06** (commit 4848291). Excel replikası: 3-haneli ana → alt (100.10) → en alt/leaf (100.10.001), recursive `MizanDugum`. Kaynak `mhsMizan_vw` → **`mhsFis`, "Kapanış" bilanço fişi hariç** (kapanmış yıl 0 sorununu çözdü; her yıl tek Kapanış = max yevmiye). `TekDuzenHesap` (79 ana hesap adı). `MizanQueries.GetSonucAsync` (leaf+ağaç+özet). **Excel doğrulama:** 2025 100/102/120/320/600 kuruşu kuruşuna ✓, denge 28,93 mlr. **590 fark (5,87M) = Excel 28.04 snapshot, virman 30.04 revize → veri/zamanlama, formül değil.** **KALAN:** login-arkası görsel onay · gelir tablosu/K-Z (6xx-7xx) Faz-2 · sirket=4 perf (~4s). SQL arşiv `2026-06-23-mizan-kesif.sql` + `2026-06-23-mizan-kesin-kapanis.sql`.
- [x] ✅ **B-119 İş eşikleri ayarlanabilir (PanelAyar)** — 23.06 (commit 8565d0c). `AyarService` + `PanelAyar` (BkmPanel app-local). Devir(1,5/3)·stockout(%5)·risk(100/200/300)·hariç-marka hardcode→ayar. Envanter/Muhasebe/Tedarikçi okur. Ayarlar.razor İş Eşikleri formu. **ERP yazma yalnız Fin_AyKapanis** (`.claude/rules/erp-write-policy.md` — kullanıcı direktifi).
- [x] ✅ **B-121 Monolit "konular karışıyor" yapısal fix** — 24.06 (commit aşağıda). (1) **DI feature-extension** `ServiceRegistration.cs` (`AddBkmVeri`/`AddBkmDurum`/`AddBkmAsistan`) → Program.cs 30 satır → 3 çağrı, hunk-split biter. (2) `.gitattributes` `app.css linguist-generated -diff`. (3) `commit-discipline.md` paylaşılan-dosya kuralı. 29 DI kaydı 1:1 taşındı, build 0/0, boot+login 200 doğrulandı. Bleed monolitte bitmez — disiplinle yönetilir.
- [~] **B-122 Kontrol paneli SP perf — SAF SKALER tek-dönem (CLI-ÖLÇÜLDÜ)** — 24.06. CLI timing (sqlclient, .env cred): deployed SP CAR **87s!** FAT 2.9s MHS 14s = HEPSI 45s. Sebep: `#Donemler` RANGE/değişken-JOIN → optimizer car 23.7M **full-scan** (date-range+temp+recompile yetmedi, join değişken-değeri compile'da görmüyor). **Çözüm: pure skaler** — `@AyBas/@AySon/@Kap/@Sir` skaler sabit + `OPTION(RECOMPILE)` → literal seek; `#Donemler` JOIN tamamen kaldırıldı. CLI test: CAR 87s→**139ms**, FAT→161ms, MHS 14s→243ms (~540ms HEPSI). SP tek-dönem (panel hep tek çağırır; `@Yil/@Ay` null→en yeni). Panel "Tüm dönemler" seçeneği kaldırıldı (Muhasebe.razor). **KALAN: Fikri redeploy (son sürüm).** Eski katmanlar (date-range/fisbSirketID/temp) skaler içinde korunur.
- [x] ✅ **B-120 Kontrol paneli SP `SUM(bit)` fix** — 24.06. Source `SUM(CAST(... AS int))` (commit 3413e88) + **Fikri DEPLOY ETTİ** (deployed tanımda fix doğrulandı, MCP sys.sql_modules). Kontrol paneli artık çalışır.
- [x] ✅ **B-123 ODAK Stok paneli** — 25.06 (commit 9cb40fa + iyileştirmeler 2737134/2202a78/031357e/0b1743d/983e58f/f2f40b6/2d1867b/a31e6c4). `/odak-stok` 3 sekme (marka özet / ürün dökümü server-paginated / usulsüz sipariş). ODAK=`ent.odak_depo_Stok`, alış `fat eTip=0→eFirma`. Usulsüz=stok≥6ay/satışsız + ≥2 cari; cari→fatura→/fatura drill. StkID→stok-hareket (yeni sekme). Marka/yazar filtre, tarih aralığı notu, Excel. (Kod yorumu "B-122" yazıldı — kozmetik, B-123 doğru.)
- [x] ✅ **B-124 Cari / Risk Özeti finans sayfası** — 25.06 (commit 4e17abc/e6eef09/1e2727b). `/cari-risk` `bakiyeVDGG_vw + frm`: borç/alacak/net bakiye + vadesi geçen (GecenB) + yaklaşan + limit aşımı. Filtre Satıcı(320)/Alıcı(120)/Hepsi + arama. **frm.frmTip→`dbo.frmTipTnm` lookup** (hardcode kaldırıldı, Tip 8=Hizmet) → sema/codes.yaml. Not: bakiyeVDGG_vw ~8s ağır (spinner).
- [x] ✅ **B-125 Genel Excel export bileşeni** — 25.06 (commit e7d81cb). Reusable `ExcelButton` (MiniExcel) + `ExcelExport.Olustur` (satır-sözlüğü) + `bkmDownload` JS. Her grid `<ExcelButton Rows="..." />`. Cari/Risk + ODAK + Baskısı Yok eklendi. **Diğer tablolara yayılabilir (envanter/mizan).**
- [x] ✅ **B-126 Baskısı Yok e-ticaret raporu** — 25.06 (commit 72d7a1f/bb7daa9/3cec5c0/9d09c11). `/baskisi-yok` JOKER `BASKISIYOK×J_ORDER_DETAILS×J_ITEMS×EM_USERS` (direkt OpenJoker). Gün bazlı özet + ürün detay + Excel + tarih aralığı (Bugün/Son7/Bu ay). E-ticaret sayfasına 30g trend grafiği (çeşit+adet). ✅ **BASKISIYOK sema entity + 3 bridge yazıldı 26.06** (`sema/entities.yaml:92`, `bridges.yaml:142-160`; iptal-0 bug notu dahil). TAMAMEN KAPALI.
- [x] ✅ **HK-tray Dashboard tray ikonu** — 25.06 (commit e9c2cb3/5772013). start_dashboard.ps1 NotifyIcon: çift-tık aç, sağ-tık menü (Paneli Aç / Yeniden Başlat / Yeniden Derle ve Başlat / Durdur-Çık). "Yeniden Derle ve Başlat" = eski-sürüm derdine çözüm.
- [x] ✅ **HK-denetim Haftalık muhasebe denetim zamanlı görev** — 25.06 (commit b030604). YEREL Task `BKM-Muhasebe-Denetim` Pzt 08:00 (kuruldu+tetiklendi, mail gitti). `haftalik_muhasebe_denetim.py` (SP salt-okuma + Türkçe yorum HTML) + bat + register. Bulut/headless LAN DB'ye ulaşamaz → yerel.
- [x] ✅ **B-127 FSM Trafik & Kasiyer + PDKS saatlik personel** — 29-30.06 sayfa (commit 0448dae/bd7942e/a604b53/6f42597: kapı×POS heatmap+KPI+personel tablosu). **01.07 PDKS eklendi:** `GetPdksPersonelAsync` GecoTime `OPENQUERY([PDKS])` TTagZei×TPerTab, saatlik headcount 3-kural (span MIN-MAX / çıkış-dakika dahil / opdays payda — sema `pdks_saatlik_personel`). 4-bant heatmap → tek "Personel–Trafik Uyumu" karne haritası (renk=mismatch ±0.15, opaklık=yoğunluk) + veri-tablosu modal grid. Başlık FSM'den mağaza-genel "Trafik & Kasiyer"e çevrildi (diğer mağazalar gelecek). SQL arşiv `sorgular/2026-06-30-pdks-saatlik-personel.sql` + `2026-07-01-trafik-birlesik-grid.sql` (üretim + analiz izi).
- [~] **B-128 Muhasebe Kontrol — CAR evrak drill'i eksikti + SP çift-sayım keşfi** — 01.07. (a) `EvrakAc` sadece MHS/FAT işliyordu, CAR listede çıkıp tıklanınca hiç açılmıyordu → `MuhasebeQueries.GetCariMhsFisAsync` (car.cMhsFisID→mhsFisBaslik köprü) + `/yevmiye-fis`'e yönlendirme + Kapanış kolonu (drill listesi) + kırmızı "Ay Kapanışı" (evrak sayfaları, query-param taşınır). cMhsFisID=0 olan hareketlerde (elden teslim/nakit) drill hedefi yok — normal. Tarayıcıda canlı doğrulandı (computer-use screenshot). (b) **KEŞİF: SP çift-sayım** — `sp_KapanisMudahaleKontrol_v2` HEPSI modunda aynı yevmiye fişi hem CAR hem MHS satırı olarak bağımsız flag'leniyor → Mayıs'26 kapanışta **36 mükerrer** doğrulandı. Fix kaynağa yazıldı (`sorgular/2026-06-22-muhasebe-kontrol-v2.sql`, MHS INSERT'e guard) — CAR kanonik kalır. **KALAN: Fikri review + redeploy** (SP objesi ERP-yazma politikası dışında, ben deploy etmem).
- [x] ✅ **B-129 Modal genişlik — tüm modallarda sessiz bug** — 01.07. `Modal.razor` Size prop (sm/lg/xl) hiçbir zaman görsel etki yapmıyordu: DaisyUI `sm:modal-middle` kuralı (`.sm\:modal-middle :where(.modal-box){max-width:32rem}`) Tailwind çıktısında utility class'lardan SONRA geliyor (responsive varyantlar dosya sonuna toplanır) → eşit specificity'de o kazanıyordu, Size sessizce hiçe sayılıyordu. Fix: `MaxWidthCls` artık `!` (important) prefix kullanıyor (`!max-w-2xl` vb.) + yeni `Size="full"` (`!max-w-none`, cap yok — geniş grid modalleri için). Muhasebe detay modalı `Size="full"`'a geçti. Tarayıcıda canlı doğrulandı — 10 kolonlu tablo artık scroll'suz tek ekranda.
- [ ] **TEMİZLİK:** B-NEW-00..06 (Mayıs kampanya) **stale → `## Arşiv`'e taşı** (Nisan'dan beri aktif Faz'da, bitmedi).
> Diğer açık: Faz-2 veri (B-08/09/10/11/14), otomasyon (B-21/32 mail-scheduler, B-05, B-23a-d), ertelenen (B-93/94/95 bilinçli), ayrı-repo (MCP M-0x → `D:\Dev\sqlserver-mcp`), ayrı-proje (YonetIQ Y-0x başlamadı). Tam liste aşağıda.

#### 🌅 SABAH HIZLI KAZANIMLAR (17.06 handoff — curated, açık backlog'dan ~30dk-1sa'lik işler)
> Önce bunları hızlıca temizle (düşük efor/risk, bağımsız), sonra büyük iş (Kumbara/B-91/B-81).
- [x] ✅ **HK-0 🥇 İLK İŞ: tüm açık TODO tara + iş listesi + TODO-DİSİPLİNİ SERTLEŞTİR** (18.06) (kullanıcı direktifi 17.06) — (1) TODO.md TÜM açık `[ ]` maddeleri tara (todo-verification: file:line ile canlı doğrula, stale [x]-değil-aslında-açık + atlanmış olanları yakala), (2) öncelikli **iş listesi** çıkar (efor/değer/bağımlılık). (3) **TODO-yönetimi için skill GEREKİYOR mu** değerlendir: `plan-tracker` (TodoWrite↔TODO sync) + `consolidate-sema` (stale budama) VAR — "tüm açık tara + öncelikli iş listesi" işini KAPSIYOR mu? Boşluk → **`yetenek-uret`** ile `todo-tara` skill forge (footprint: önce mevcut genişlet).
  **🔴 TODO-DİSİPLİN PROBLEMİ (17.06 gözlem — sertleştir):** done-but-`[ ]` birikiyor (C-11/C-01-05 yapıldı, açık kalmış), stale-irrelevant arşivlenmiyor (B-NEW Mayıs-kampanya Nisan'dan beri aktif Faz'daydı), dup'lar (B-90↔M-13, C-07↔B-19, B-NEW-00 iki yerde). **Curator MANUEL koşunca yakalandı → mekanik değil, kök sorun bu.** Sertleştirme planı (yarın uygula):
  - **S1 Commit→TODO ZORUNLU:** bir maddeyi kapatan commit → AYNI anda `[x]` + hash. `commit-discipline.md` + `todo-verification.md`'ye sert kural; ihlal = stale birikir.
  - **S2 Her handoff'ta TODO stale-pass** (≥7g beklemeden): done-but-open + dup + archive-irrelevant taraması session-handoff Adım 4.5'e zorunlu adım.
  - **S3 Yeni madde öncesi dup-grep:** aynı ID/konu var mı (B-90↔M-13 önlenir).
  - **S4 session-start mekanik yüzey:** done-but-`[ ]` / stale-open sayısını her oturum göster (şu an curator-due ≥7g flag var; bunu TODO-stale sayısına genişlet).
  - **S5 Belki PostToolUse hook:** git commit sonrası "commit hash içeren ama TODO'da [x] olmayan ID var mı" uyarısı (over-engineering riski — önce S1-S4 rule/skill, sonra değerlendir).
- [x] ✅ **HK-1 mobil "Diğer" menü** (18.06, commit 2f56259) (UX, ~20dk) — Mağazalar/TOPLAM/Sadakat mobilde erişilemiyor (btm-nav 5 sekme, sidebar 11). Çözüm: `MainLayout.razor` btm-nav'a 6. öğe **"Diğer" (⋯, icon `menu`)** = NavLink değil, `<label for="bkm-drawer">` (drawer toggle) → drawer tüm `NavRegistry.Items` gösteriyor zaten. Masaüstü değişmez. Tek dosya.
- [x] ✅ **HK-2 B-99 sql-denetci agent test** (18.06) — 04-karzarar/ 7 dosya: 1 kırmızı (maliyet-karsilastirma VatTotal eksik), 3 sarı (IIF/compat), 3 temiz. Format doğru, agent çalışıyor.
- [x] ✅ **HK-3 B-86 GetDepoWms 0-guard** (18.06, commit 752ab3b) (~15dk) — `RefQueries.Envanter.cs` GetDepoWmsAsync boş-sonuç→0 "Depo Bugün": gerçek-0 vs veri-yok ayırt et (nullable + "veri yok" göster).
- [x] ✅ **HK-4 B-89 ApexCharts var(--p)** (18.06, commit f97a780) (~30dk) — hardcode hex → CSS-var (context7 doğruladı `colors:['var(--p)']` çalışıyor). `AppAreaChart`/`AppBarChart` default `#4063e6`, axis renkleri → DaisyUI token. renk-standardi uyumu.
- [x] ✅ **HK-5 C-13 .gitignore build artifact** (18.06, commit 38f65d8) (~10dk) — `sorgular/03-kampanya/RaporApp/bin|obj`, `*.dll/*.exe/*.pdb` → .gitignore + `git rm --cached`.
- [x] ✅ **HK-6 B-16 Express amacı** (18.06) — PDKS sunucusu (personel devam). B-17 ALLOWED_DATABASES daraltma kararı açık kalıyor (düşük öncelik).
> Not — **B-82** (kasiyer ABS formül): `Queries.cs:157` kasSql doğrulandı (zaten -VatTotal vardı, false-positive); `:349` GetKasiyerDelta asimetri DÜZELTİLDİ (17.06). Kalan: iade-branch `ABS(DiscountTotal)` tutarlılığı — düşük öncelik, MCP mutabakatıyla doğrula.

#### Faz 0 — Yarın (Blazor dashboard devam — 12.06 oturumundan)
- [x] ✅ **B-96 müşteri kazanım/kart stat SMOKE** — KAPALI 16.06. /musteri runtime doğrulandı: kazanım area chart SVG çiziliyor (Haz 2026 ~8.381 yeni · 13 ay 223.896), kart oranı bar (ÖZLÜCE %68,4 · FSM %51,8 · İst.Yolu %53,0 · Toplam %58,7), AppSozluk (Home) native details kapalı-başlar/açılır. Konsol hatası yok. (plan-17, cf9e7ab)
- [x] **B-97** ✅ 17.06.2026 (commit 39b7449) — LokasyonConfig.cs merkezi sabit (Subeler/SubelerVeDepo) + Queries.cs·RefQueries.cs·RefQueries.Envanter.cs 9 SQL noktası + olu_stok_excel.py + forecast/data.py güncellendi. UI toggle (5-lokasyon) → ayrı TODO.
- [x] **B-98** ✅ 17.06 Kumbara indirim — köprü doğrulandı (SPC.CampaignVersion=RefundReasons.Id, CampaignId IS NULL, Id=17). GetKumbaraAsync + KumbaraAyRow + /operasyon Mağaza×Ay tablosu (lazy arka plan, %30+ kırmızı). sema güncellendi. SQL arşivlendi. (commit aff2091)
- [x] **B-98-gen** ✅ 17.06 Manuel indirim kırılımı — tüm RefundReasons.Type=1 sebepleri, sebep özeti + tıkla-drill (Mağaza×Ay). GetManuelIndirimAsync + ManuelIndirimRow. (commit 8416bec)
- [x] ✅ **B-99** → HK-2 ile kapandı (18.06, dup).
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
- [x] **R-1 Ay-seçimli kazanım drill** ✅ 17.06.2026 (commit 72c8163) — AppAreaChart OnDataPointSelection + GetKazanimDetayAsync + Musteri.razor inline detay panel.
- [x] **R-2 Kart oranı dönem seçimi** ✅ 17.06.2026 (commit 46995b7) — 7g/30g/90g pill + GetKartOranAsync + dinamik _kartData.
- [x] **R-3 E-ticaret kazanım** ✅ 17.06.2026 (commit f580478) — GetKazanimEtAsync (JOKER J_ORDERS ilk sipariş 13ay) + Musteri.razor ET kart (info renk, bağımsız evren notu).
- [x] **R-4 Kohort retention matrisi** ✅ 17.06.2026 (commit af47abc) — GetKohortAsync (12ay × N-ay geri dönüş) + heatmap tablo (renk kodlu %, n=kohort büyüklüğü).
- [x] ✅ 18.06 **R-5 Segment geçiş matrisi UI** — stale: `Sadakat.razor:100-117`'de AppDataTable panel MEVCUT (eski/yeni seg + iyileşme/kötüleşme badge). SQL GetRfmGecisAsync bağlı.
- [x] **R-6 Müşteri LTV / yaşam boyu değer** ✅ 17.06.2026 (commit 41205f3) — GetLtvAsync (kartlı/kartsız ort yıllık ciro+aktif ay+frekans) + Musteri.razor LTV karşılaştırma kartı.
- [x] **R-7 Churn / tekrar-alım oranı** ✅ 17.06.2026 (commit 41205f3) — GetChurnAsync (aktivasyon %/adet + churn riski 90g+) + progress bar UI.
- [x] **R-8 Müşteri fiş drill polish** ✅ 17.06.2026 (commit 2c913dc) — FisRow.IndirimTutar (YK SQL), iade/indirim rozeti (badge, iade kırmızı). ET durum + geri-nav: mevcut yeterli, ertelendi.
- [~] **B-40** Mağaza detay sayfası `/magaza/{id}` — ✅ panel + drill commit 13.06 (de4f214…1f2142a). Ödeme üst-grup+banka drill · kampanya 3al2öde-ayrı/Diğer-toplu drill · UPT · iade · kategori→ürün. IsValid+iade fix doğrulandı (dashboard=MCP). **Kalan:** dönüşüm (G8 kapı sayıcı CSV — FSM-only, Özlüce/İst.Yolu sayıcı bekliyor).
- [~] **B-41** JOKER kargo SQL — ✅ ÇEKİRDEK 14.06 (18 commit): il teslimat (takvim+iş günü) · aylık çıkış trendi + gün drill · COD iade maliyeti. **İş günü** çıkış (takvim 4,14→2,79g) + **veriden otomatik tatil** (resmi+dini+grev, sıfır bakım). queries.yaml+sema. **Kalan:** #5-7 (günlük detay→ay-drill ile karşılandı · v2 · çıkış-teslim→il'de var) düşük değer. Kargo kar/zarar YAPILMAZ (KargoMaliyetiniHesapla remote çağrılamaz).
- [~] **B-47 ⚡ DRILL MOBİL — ÇÖZÜM: HTTP-only (17.06 karar)** — mkcert cert Android'de güvenilmiyor → HTTPS'te wss/SignalR kurulmuyor → drill ölü. **Karar: HTTPS/PWA-cert derdini BIRAK, telefon HTTP kullansın.** Telefon (aynı Wi-Fi) → **http://192.168.1.45:5112** → `ws://` SignalR kurulur, drill çalışır. Altyapı HAZIR: 0.0.0.0:5112 dinliyor + firewall "BKM Dashboard 5112" allow + auth cookie SameAsRequest HTTP destekli. Kod değişikliği GEREKMEZ. ⚠️ PWA "ana ekrana ekle"/standalone HTTPS ister → tarayıcı modu (kabul, tek-kullanıcı LAN). Tünel/Tailscale reddedildi/gereksiz. **TELEFON TESTİ kullanıcıda → çalışırsa [x].** (CF tunnel + Let's Encrypt seçenekleri arşiv: PWA-install şart olursa Tailscale.)
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
- [x] ✅ 18.06 **B-81 🔴 KRİTİK iade-netleme** — irsHrk sorgularına `ehTip IN(3,5,101)` iade dalı eklendi: `RefQueries.cs` devir-Sat + marka-Ciro/Adet; `RefQueries.Envanter.cs` envanter-ciro + marka-rotasyon SatisAdet/SatisCiro. GetUrunlerAsync zaten doğruydu (EncoreMerkez DocType=3 sign). Stockout filtresi değişmedi (SKU-listesi, ciro değil). Mayıs doğrulama: iade/satış %4.22 (ehTip 101 only). Build OK.
- [x] ✅ 18.06 **B-82** ORTA — Kasiyer ABS(DiscountTotal) doğrulandı: iade satırında DiscountTotal POZİTİF → ABS zararsız, formül doğru. Yan bulgu: Queries.cs + MagazaQueries.cs'de IIF → CASE WHEN compat-110 fix uygulandı (14 adet).
- [x] ✅ 18.06 **B-83** ORTA — exception sızıntısı `_error = ex.Message` → Logger.LogError + generic mesaj. 10 sayfa, 17 lokasyon. ILogger<T> inject eklendi.
- [x] ✅ **B-109** forecast portaldan tetikleme + çıktı DB'ye — KAPALI 17.06. (a) `ForecastService` Process `python run.py` (cwd scripts/forecast, 10dk, exit/stderr loglu) → /tahmin "Tahmini Çalıştır" butonu. (b) **Çıktı JSON yerine `BkmPanel.dbo.PanelForecast`** (Ad PK + JSON nvarchar(max)): Python run.py pyodbc ile yazar (Windows auth, ODBC18), C# ForecastOkuService Dapper okur. API YOK — ortak DB. Python KALDI (statsforecast C# yok). Round-trip doğrulandı (pyodbc yaz + C# build). Tam run gerçek ortam (201 DB).
- [x] ✅ **B-108** takvim TAM DB → `BkmPanel` TEK tablo — KAPALI 17.06. `PanelTakvim(Id,Bas,Son,Ad,Tip,YarimGun)` — tatil/sınav tek-gün (Bas=Son), okul dönem aralık (Bas<Son), Tip ayırır (Ulusal/DiniBayram/Sinav/OkulAcik). PanelOkulDonem AYRI TABLO KALDIRILDI (gereksizdi, tek tabloda Bas/Son ile çözüldü). okul-takvimi.json → seed-if-empty (2 dönem+4 sınav doğrulandı). Dapper global `DateOnlyTypeHandler`. ⚠️ tatil boş başlar → /tahmin "Yenile" ile API'den dolar.
- [x] ✅ **B-107** app-state → localhost Express `BkmPanel` taşıma — KAPALI 17.06. JSON/SQLite dosya-state DB'ye: `IcKartService` (ic-kartlar.json→PanelIcKart), `TahminKayitService` (tahmin-kayitlari.json→PanelTahminKayit), `GorevService` (asistan.db SQLite→PanelGorev). Db.OpenPanel() senkron; servisler ctor'da ensure-table + PanelEnabled guard. Microsoft.Data.Sqlite paketi kaldırıldı. Forecast (Python çıktı cache) + Takvim (API cache) BIRAKILDI — cache, yeniden üretilir. Migration yok (Release temiz, tek-kullanıcı yeniden girer). Smoke: PanelGorev+PanelKullanici oluştu, / 200.
- [x] ✅ **B-84** basit auth — KAPALI 17.06 (plan-19). Cookie auth + global FallbackPolicy, şifre localhost `BkmPanel.dbo.PanelKullanici` (PBKDF2-SHA256 100k, sayaç/kilit SQL). İlk açılış `/setup` şifre belirleme, `/login` + `/auth/*` minimal API (Blazor-dışı, SignIn HttpContext). allow-list: login/setup/healthz/ca.crt/static. MainLayout çıkış butonu. Smoke: setup→cookie→yanlış-hata→doğru-Set-Cookie→healthz anonim doğrulandı. **Commit BEKLİYOR.**
- [x] ~~**B-85** boş catch loglama~~ — ✅ 16.06. RefQueries SPLH + Envanter marj → `ILogger.LogWarning` (RefQueries'e ILogger inject, Envanter'a @inject). Operasyon WMS iç-catch ölüydü (WhenAll await sonrası ulaşılmaz) → kaldırıldı. Build yeşil.
- [x] ✅ **B-86** → HK-3 ile kapandı (18.06, commit 752ab3b).
- [x] ~~**B-87** ölü kod~~ — ✅ 16.06. Operasyon `_pColor` field + ölü OnAfterRender theme bloğu + Gorevler `OncSinif()` silindi. Build yeşil. (todo-verification: ikisi de grep ile doğrulandı.)
- [x] ~~**B-88** perf paralel~~ — ✅ 16.06. Home `GetHedefAsync` WhenAll'a dahil (ayrı sıralı await yerine). Müşteri `GetRfmAsync` yk+et her biri kendi bağlantısı + WhenAll (B-74 deseni). SQL birebir, build yeşil, smoke 200. (Not: Müşteri 4.3s'in çoğu prerender double-render = B-91 ayrı.)
- [x] ✅ **B-89** → HK-4 ile kapandı (18.06, commit f97a780).
- [~] **B-90 → M-13 ile birleşti** (süperseded) — file-size split. ✅ RefQueries 638→334 (17.06). ⏸️ Home/Tahmin sub-component bekliyor. Sayılar M-13'te güncel; bu madde M-13'e bakar.
- [x] **B-91** ✅ 17.06 Blazor prerender double-render — PersistentComponentState 10 sayfa (Home/Musteri/Eticaret/Operasyon/Sadakat/Tahmin/Toplam/Magaza/Magazalar/Envanter). Asistan+Gorevler: DB çağrısı yok, skip. Tahmin: TahminMagazaItem record eklendi (ValueTuple JSON sorunu). Envanter: StreamRendering uyumlu (main persist, marj always background). (commit 3f7117e)
  **Problem:** prerender'lı InteractiveServer → `OnInitializedAsync` **2× çalışır** (1: statik prerender, 2: tarayıcı interactive). context7 (`/dotnet/aspnetcore.docs` blazor/components/lifecycle.md) birebir doğruladı. Masaüstünde TÜM sayfa SQL'i **çift** koşuyor (DB yükü 2×); mobilde genelde tek.
  **Mevcut rendermode:** GLOBAL `App.razor:25 <Routes @rendermode="InteractiveServer">` + 12 sayfada per-page `@rendermode InteractiveServer` (ikisi de prerender:true — aynı mod, çakışmıyor).
  **YOL 1 — `prerender:false` (REDDEDİLDİ):** App.razor Routes + 12 per-page'i tutarlı `InteractiveServerRenderMode(prerender:false)` yap. ⚠️ **Mobil B-47 REGRESYON**: SignalR flaky'ken (mobil PWA cert sorunu) şu an prerender en az SSR içerik gösteriyor; prerender'sız → boş "Yükleniyor" sonsuza. CFO mobil deneyimi bozulur. **YAPMA.**
  **YOL 2 — `PersistentComponentState` (DOĞRU, context7 örneği `blazor/state-management/prerendered-state-persistence.md`):** her sayfa: `@inject PersistentComponentState State` + `@implements IDisposable` + OnInit'te `if(!State.TryTakeFromJson<T>(key, out var restored)){ fetch } else { use restored }` + **sonda** `persistingSubscription = State.RegisterOnPersisting(Persist)` (race önler) + `Persist(){ State.PersistAsJson(key, data) }` + `Dispose(){ persistingSubscription.Dispose() }`. Prerender KORUNUR (mobil SSR içerik görür) + çift-fetch gider. DB 2×→1×.

#### ⏸️ Ertelenenler / Kısayollar (16.06 — normale çevrilecek, ATLANMAYACAK)
- [x] **B-92** ✅ 17.06.2026 (commit 4cbcbd0) — /toplam Online sekmesi: EticQueries.GetEticKategoriAsync (LOGOGRUP) lazy yük + kategori drill GetEticKategoriUrunAsync; dönem değişince cache temizle.
- [ ] **B-93** plan-12 WS-2 **faz-2** — konu-bazlı rule'ları fiziksel `.claude/rules/topic/` dizine taşı + skill-inject (gerçek system-prompt token düşüşü). **compact-survival smoke ZORUNLU** geçmeden yapma.
- [ ] **B-94** plan-12 WS-1 **telemetri** — sema/skill kullanım sayacı (`.usage.json` sidecar). Şimdilik manuel yargı; veri-temelli stale tespiti istenirse.
- [~] **B-95** sema `last_verified` geriye-doldurma — **18.08 KISMEN**: bugün fiilen doğrulanan 31 entity + 2 bridge + 1 code damgalandı (curator A2). Doğrulanmayanlara damga VURULMADI (sahte tazelik yasağı). KALAN: bridge'lerin join-kardinalite testi (products-code-stkid, hedef-kategori, salescampaign-sales, palet-irs, bekleyen-siparis-il) + enum kod listeleri + çapraz-DB entity'ler. Rapor: docs/curator/REPORT-2026-08-18.md § A2 UYGULAMA.
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
- [x] **B-65** ✅ 17.06 Müşteri kayıp/risk segmenti 3-ay trendi — SegmentTrendiRow + GetSegmentTrendiAsync (ykSql 3× t0/t30/t60) + /sadakat kart (Risk/Kayıp kırmızı, delta yön-duyarlı). (commit 8dac591)

#### 🎯 Müşteri Sadakat Derinleştirme (kullanıcı isteği 14.06 — derin CRM/sadakat). [TIER 3 plan-first — yeni "Sadakat" sayfası olabilir]
> Veri tabanı: EncoreMerkez `Sales.CustomersId` + `DerinCrm.Customer` (Name/PhoneNumber/CardNumber) · e-tic `J_ORDER_CLIENTS.CUSTOMERREF` · mevcut RFM (C1-rfm). Tek köprü çözüldü (`DerinCrm.Customer.Id = Sales.CustomersId`).
- [~] **B-66** → R-4 ile aynı (dup). R-4 takip eder.
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
- [~] **B-22** FSM kapı sayıcı entegrasyonu — **(2) SQL tabloya yükleme ✅ KAPALI 24.07.2026** — `bkm.MusteriSayi` (MekanId, Tarih, MusteriSayi) API ile otomatik besleniyor, saatlik grain, dashboard `TrafikQueries.cs`/`/trafik` sayfası zaten bundan okuyor (sema/entities.yaml doğrulandı). `sayiyo/*.xlsx` + `scripts/donusum_orani.py`/`sayiyo_excel.py` akışı **legacy** (API'den önce elle-yükleme) — güncel kod bunları kullanmıyor. **KALAN:** (1) Özlüce + İst.Yolu sayıcı kurulumu yok, (3) saat bazlı kırılım (heatmap `/trafik`'te zaten var, brief'e KPI kolonu eklenmedi). **(GÜNCEL 24.07)**
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
- [ ] **B-06** `CampaignId = NULL` **389,4M ₺** indirim kaynak araştırması (Session 2'den beri açık;
      MCP keşfiyle bulundu). ⚠ 19.09: bu madde İKİ yerde yazılıydı, birleştirildi (V-16).
- [x] ~~**B-07** Ürün bazlı maliyet/marj analizi — 3Al2Öde'nin gerçek kârlılık etkisi.~~ — ✅ 07.05.2026: `sorgular/04-karzarar/2026-05-07-gunluk-kar-zarar-maliyet-karsilastirma.sql` üretildi (plan: `plans/04-gunluk-kar-zarar-maliyet-karsilastirma.md`). Kitap kategorisinde günlük P/L, Maliyet = `fatAyr.ehTutarN / ABS(ehAdetN)`. **Kritik bulgu:** DerinSIS alış faturasında `ehAdet/ehAdetN` NEGATİF, `ehMaliyet` kolonu BOŞ — `ehTutarN/ABS(ehAdetN)` doğru formül. `irsHrk.ehMlyt` ve `fatAyr.ehMaliyet` BKM'de aktif kullanılmıyor. **06.05.2026 testi:** Net 544K ₺, Marj %22.5, Çocuk Kitabı %8 dikkat çekici (3al2öde etkisi).
- [x] ~~**B-23** Plan 04 v2 mağaza kırılımı~~ — ✅ 07.05.2026: `sorgular/04-karzarar/2026-05-07-gunluk-kar-zarar-irshrk-magazali.sql` üretildi. Satış kaynağı **irsHrk** (ehTip 1/4/100 satış, 3/5/101 iade), mağaza ID 1=FSM/4477=Özlüce/4478=İst.Yolu, 4 result-set (mağaza×kategori, genel, top 200 ürün, doğrulama). 06.05.2026 testi: FSM 255K marj %44, Özlüce 361K %43, İst.Yolu 77K %45 — toplam 693K marj (%44). Kalan v3 işleri: (a) JOKER e-ticaret, (b) önceki fatura snapshot, (c) eDvzKur çevrim, (d) stored procedure'a sarma. — bunlar **B-23a/b/c/d** olarak ayrı.
- [ ] **B-23a** v3: JOKER e-ticaret kanalı entegrasyonu (linked server ODAKJOKER.JOKER, J_ORDERS+J_ORDER_ITEMS).
- [ ] **B-23b** v3: Önceki alış faturası snapshot (fiyat trendi).
- [ ] **B-23c** v3: Yabancı para çevrim (fat.eDvzKur).
- [ ] **B-23d** v3: Stored procedure'a sarma (`bkm.sp_GunlukKitapKarZarar`).
- [x] ✅ **B-25** (18.06, commit 8e573f4) — session-protocol Adım 3.5 SEMANTIK_KATMAN zorunlu okuma eklendi. oturum başı ritüelinde **`sorgular/SEMANTIK_KATMAN.md`** zorunlu okuma listesine eklensin (ehTip kod sözlüğü, mekanID'ler, `ehTutarN = ehTutar - ehIndirim` mantığı bu dosyada). 07.05.2026 oturumunda atlandı, kullanıcı uyardı. **(YENİ)**
- [x] ✅ **B-24** (18.06, commit 8e573f4) — sql-server-conventions.md'ye eklendi (ADR-004 bölümü).
- [x] ~~**B-26** E5 GMROI doğrulaması~~ — ✅ 08.06 karzarar v7 pymssql ile koşuldu (SET DATEFORMAT dmy). Mayıs aylık GMROI: Gıda 0,23 · Kitap/Akademi 0,03 · TOPLAM 0,07/ay. Kitap kategorileri ölü sermaye (E4/ABC ile tutarlı). Tüm GM KPI sözlüğü artık doğrulandı.
- [ ] **B-27** G1 panosu (`10_00_gunluk-gm-panosu.sql`) 12 sn sürüyor — UPT için fiş-başı CROSS APPLY ağır. Günlük otomatik mail'e bağlanırsa UPT'yi ön-hesaplı/materialized tut. **(YENİ)**

#### Faz 2 — Bu ay (orta öncelik — ~10 gün)
- [ ] **B-169** **Merkez depo WMS ↔ ERP defter eşitlemesi** — plan: `plans/43-wms-erp-defter-esitleme.md` (Tier 3, BEKLEMEDE, 09.09.2026). Mekanizma çözümlemesi + ölçüm BİTTİ, uygulama yapılmadı; hiçbir tabloya yazılmadı (kullanıcı kısıtı: _"aman tablolara dokunma sakın"_).
  - **KARAR (kullanıcı 09.09):** WMS'e DOKUNULMAZ — WMS toplamı ↔ ERP defteri karşılaştırılır, fark **± sayım evrakı** olarak ERP'ye yazılır. Üretici (salt-okuma, EXEC metnini basar): `sorgular/2026-09-09-wms-erp-sayim-evraki-URET.sql`.
  - **KAPSAM DÜZELTİLDİ:** mutabakat kapsamı RAF+GİRİŞ **değil, TÜM ALANLAR** (ÇIKIŞ dahil — mal sevke ayrılmış ama hâlâ defterde). Mutabık ürün 409.229 → **417.812**; ÇIKIŞ dahil olunca 9.820 ürün kazanılıyor, 1.237 kaybediliyor (8× asimetri → tesadüf elendi). Uyumsuz çeşit **17.027 → 8.476**. ⚠ Panel stoğu (0,1) ile defter mutabakatı (0,1,2) karıştırılmaz. `ehAltDepo` mekan 12'de tek değer 0 → süzgeç gereksiz.
  - **EVREN DÜZELTİLDİ — `urnTip=0` guard'ı YETMİYOR:** farkın **%96'sı 5 hizmet/sarf kalemiydi** (144860 KARGO GELİRİ −2.798.582 · 583160 Geri Dönüşüm Kağıt +1.764.200 · 144963 KAPIDA ÖDEME −1.194.588 · 436306 KOMİSYON −207.999 · 1543633 TANIMSIZ ÜRÜN %20 +37.504) — hiçbiri WMS'te yok, düzeltilmez, evrenden çıkarılır. Süzgeç `bkm.UrunBilgi.Kategori3 NOT IN ('KARGO','Genel','Tanımsız','Zkargo')`. ⚠ KARGO GELİRİ'nin urnTip=0, satisTur=0, urnKtgrID=10 ("Çocuk Kitapları" — veri kiri).
  - **Fark (doğru kapsam + doğru evren) = GERÇEK BÜYÜKLÜK:** GİRİŞ `@GC=0` 5.443 çeşit / 152.105 adet / 231.979 ₺ · ÇIKIŞ `@GC=1` 2.952 / 41.952 / 177.172 ₺ → net **+110.153 adet / ~+54.806 ₺**. Yanlış taban (etiket) + yanlış evren (hizmet dahil) tutarı **590 kat** şişiriyordu (32,1M ₺ → 55 bin ₺).
  - **GEÇMİŞ (kullanıcı hatırlattı, doğrulandı):** Aralık 2025'te negatif defter temizlenmiş — negatif çeşit 01.12.2025'te 302.859 → 31.12.2025'te **37**. Mekanizma sayım evrakı DEĞİL, `ehTip=88 'Diğer Giriş'` 310.116 satır/+22.859.643 adet + `ehTip=89 'Diğer Çıkış'` 26.291/−40.073.558. **Kalıcı olmadı:** negatif çeşit 37 → 27 (Oca) → 80 (Mar) → 584 (Haz) → **2.545 (09.09.2026)** → tekrar eden mekanizma şart. O temizliğin WMS'e eşitlendiği geriye dönük ÖLÇÜLEMİYOR (Aralık-2025 WMS snapshot'ı yok; `StokAyBakiyeMekanBazli` mekan 12'de tek dönem taşıyor). Ayrıca `depo.sayım` zinciri **22.01.2024'te durmuş**.
  - **Parasal etkide taban MALİYET:** etiket fiyatıyla ölçüm yönü bile değiştiriyordu (etiketle −63,6M ₺ düşüş, maliyetle +30,5M ₺ artış). 5.287 çeşitte maliyet bilinmiyor → `bkm.UrunMaliyet` 4. kademede **0** döner, deftere 0 ₺ girer (adet düzelir, değer düzelmez).
  - **PİLOT ZORUNLU:** `dbo.irsSatir_ekle` ŞİFRELİ → `@ADET` işaretinin nasıl yorumlandığı okunamadı. Tek ürünle evrak yazılıp `irsHrk.ehAdetN` işareti ÖLÇÜLECEK; ters işaret girerse fark ikiye katlanır. Üretici iki varyantı da basıyor (Blok 5/6).
  - **`ent.JokerJokerCKEsitleme` deseni MERKEZ İÇİN ÇALIŞMAZ:** `depo.sayimIsle` beyan edilen `sAdet`i WMS'in `paletUrnTnm`'i ile karşılaştırır, ERP defterini hiç görmez → `sAdet=WMS` verince fark 0, ERP değişmez. `sAdet=ERP` verince WMS ERP'ye çekilir (ters yön). Ayrıca `ehTutar=0` yazar, `sAdrsID` okunmaz, `paletBazliSifirlansin=1` listelenmeyen ürünü paletten SİLER, transaction yok.
  - **Doğru araç ikili:** (1) fiziki sayım = `WMS-GunlukSayimEmiri` job'ının `sayilcaklar` CTE'sine üçüncü kol (öneri: `sorgular/2026-09-09-wms-erp-fark-sayim-emri-ONERI.sql`); (2) defter düzeltmesi = **`bkm.SayimIrsaliyeBaslikOlustur` + `bkm.SayimIrsaliyeSatirEkle`** — WMS'e dokunmaz, `eTip=99`, tutarı `bkm.UrunMaliyet` ile kendisi hesaplar, `@onay=1` (anında işler).
  - **Kapılar/tuzaklar:** `adresSnl.adrs3=0` olan 3.224 raf adresi sayım emrinden düşüyor · barkodsuz 3 çeşit · `emPaletID=217542` ve terminal kullanıcı listesi SP'de GÖMÜLÜ · `@EmNo='GUN'+yyMMdd` tekil değil · `emSonPozID` = **stkID** (pozisyon değil) · `dbo.irs_ekle`/`irsSatir_ekle`/`irsSatirHrk_ekle` **ŞİFRELİ** (son mil okunamadı).
  - **Karar bekleyen (kullanıcı/muhasebe):** stok değeri değişimi kabul mü · 3.011 ERP-negatif ürün nasıl kapanacak · WMS'te kaydı olmayan 9.230 çeşit/1.997.663 adet sayılamıyor, defter düzeltmesi onayı · maliyetsiz ürünler 0 ₺ girsin mi · job mu elle dilim dilim mi (job kurulumu AYRI onay ister).
  - **EŞİTLEME TUTTU — problem SIZINTI (kullanıcı: _"wms ile aynı yapmıştım stokları"_, doğrulandı):** 2026'da hiç hareket görmemiş 6.182 çeşidin **6.181'i hâlâ mutabık (%99,98)**; hareket görenlerde %71,86. 2026 delta farkı mevcut farkı birebir açıklıyor (ERP-eksik: ERP Δ +161.327 vs WMS Δ +306.224 → fark +151.670). Yani tarihsel kir değil, **süregelen sızıntı**.
  - **Sızıntı kanalları (ölçüldü):** (1) `paletIcHrk.pHrkTip=0` KULLANICI/manuel baskın (belgeli +745.077 · belgesiz −357.759 · sayım −81.094 = net +306.224; `pHrkTip=1` EMİR net 0) · (2) `ehTip=2` **Alış İade %84,65 uyumsuz**, baskın yön ERP-fazla 1.748 çeşit/21.602 adet = ERP-fazla farkının %51'i · (3) onaysız irsaliye katkı (onaysızda geçen 1.881 çeşidin %44,28'i uyumsuz, taban %28) — **onay job'ı yalnız eTip IN (16,90,99) işliyor, `eTip 13` onaysız kalıyor** (1.974 satır / +52.989 adet).
  - **İKİ AYRI İŞ:** **(A)** yeniden eşitleme ~194K adet / ~55K ₺ — ucuz, tek seferlik · **(B) sızıntıyı kapatmak** — asıl iş. B olmadan A sayacı sıfırlamaktan ibaret (Ara-2025: 302.859 → 37, dokuz ayda → 2.545). B için öneri: onay zincirinde eTip 13 boşluğu · alış-iade WMS↔ERP eşleşme zorunluluğu · periyodik fark izleme + eşik uyarısı.
  - **Sıra:** fiziki sayım ÖNCE, defter düzeltmesi SONRA. İlk dilim ≤200 çeşit, en yüksek **maliyetli** tutardan.
- [x] ~~**B-28** RFM müşteri segmentasyonu~~ — ✅ 08.06.2026 `sorgular/gm-rapor/musteri/C1-rfm-segmentasyon.sql`. Şampiyon 8.923 (11K ₺/9,2 sip.) · Kayıp 335.512 (353M, reaktivasyon). + A6 marka/yayınevi + E7 weeks-of-supply kuruldu.
- [x] ~~**B-33** Stokta yokluk (stockout)~~ — ✅ 08.06 `gm-rapor/envanter/E8-stockout.sql`. Dergi %23,3 · Akademi %8,7 · Kitap %5,2 (hedef <%5). SKU bakiye≤0, son 30 gün satışlı.
- [x] ~~**B-34** SPLH (işgücü verimi)~~ — ✅ 08.06 `gm-rapor/operasyon/S1-splh-isgucu-verimi.sql`. Özlüce 3.786 ₺/saat · FSM 2.822 · İst.Yolu 2.793. PDKS Per_Grp1='MAĞAZALAR'+Per_Grp2 mağaza eşleşmesi (vrd gerekmedi).
- [x] ~~**B-29** Birleşik fiziksel+online **haftalık** brief~~ — ✅ 11.06 commit 739ad0a. generate_brief.py v1.1.0: SQL_ETICARET (J_ORDERS, net=iptal/iade hariç, ISO tarih) + weekly/monthly şablonlara 1b/3b bölüm + birleşik özet satır. Doğrulama hafta 01-07.06: online 19,1M (%65) / fiziksel 10,1M (%35). Linked server düşerse fiziksel-only + warning. (B-21'in JOKER ayağı da kapandı; kitapsepeti/Heykel/kafeler hâlâ yok.)
- [x] ~~**B-30** Haftalık P2-P8 verified-wire~~ — ✅ 11.06 commit 3bb01fa. `gm-rapor/haftalik/P2-P7` dinamik hafta penceresi; P2/P3/P5/P6 MCP canlı doğrulandı (hafta 01-07.06, brief ile çapraz tutarlı), P4/P7 SSMS pointer. 10_16_kasiyer.sql içeriği yanlıştı (kampanya trendiydi) → P6 sıfırdan. Yeni köprü: Sales.UsersId=Users.Id.
- [ ] **B-08** EncoreMerkez Products tablosu → DerinSIS urn kategori mapping (urn.stkID köprüsü).
- [ ] **B-09** Sales → fat/irsHrk bağlantısı (LinkedDocumentNo / ClosureNo / TransferHistory).
- [ ] **B-10** `bkm.HareketKanal_vw` view tasarımı — Sınav vs Perakende ayrımı.
- [ ] **B-11** 2026 yıllık tahmin (Sınav / Retail ayrıştırılmış).
- [ ] **B-12** H15 e-ticaret sorgularının arşivlenmesi (`sorgular/YYYY-MM-DD-*.sql`) —
      ikiz-yükümlülük borcu (`semantic-layer.md`). ⚠ 19.09: `B-12/B-13` diye birleşik yazılmış
      ikinci bir satır vardı, birleştirildi (V-16). B-13 kendi maddesinde duruyor.
- [ ] **B-13** Önceki oturum e-ticaret trend raporu SQL'leri arşive: haftalık ciro/adet, günlük nabız, Top 20 organik, kanal kırılımı, kategori, yayınevi Top 15, sipariş durum, Echo of Silence forensic, YoY 2025, J_ITEMSBARCODE keşif.
- [ ] **B-14** Grok sinyallerini iç satış verisiyle cross-check (önceki sorgular 30s timeout — başlık-bazlı küçük sorgulara böl).
- [~] **B-112** Dashboard hızlı kazanımlar — **3/4 İŞLENDİ 22.06** (dup: SABAH satırıyla aynı, bkz satır 160). (a) ödeme grubu+Δ · (b) iade sebebi `RefundReasons.Type=0` · (c) indirim kaynağı `SPC.Source` → Operasyon, dönem-duyarlı, `RefQueries.Operasyon.cs`. (d) kasa saatleri = zaten vardı (Saat Bazlı Yoğunluk) → atlandı. Build yeşil.

- [~] **B-113** UI checklist temizlik (asistan-ui §5.5, 35 ihlal — YÜKSEK yok). ✅ 17.06 DÜZELTİLDİ: Türkçe (Error/NotFound/ReconnectModal + error-boundary::after) · **Emoji→Lucide** (Asistan 4 buton, Modal ✕, MainLayout, Home/Magazalar/Sadakat link-ikon, Operasyon badge) · **focus-visible global CSS** (app.tailwind.css `*:focus-visible` → tüm input+tıklanabilir). **KALAN:** (b) Hardcode hex 11 adet ApexCharts.Blazor C# option (AppMultiLine/Stacked/Bar/Area eksen #94a3b8 + grid + Magazalar Colors + App theme-color) — render-time C# nesne, CSS-var geçilemez → JS interop gerektirir (OnAfterRender renk-set). Eksen gri nötr/marka değil, düşük görsel etki. Ayrı iş.

#### Faz 3 — Çeyrek (düşük öncelik / temizlik — ~15 gün)
- [~] **B-45 ⭐ DEVAM — BKM-Asistan PWA-içi** (plan-20, Faz-1 başladı 18.06). LLM=**Gemini Flash + Groq fallback** (Anthropic değil — kullanıcı kararı). ✅ Faz-1 LLM katmanı commit (9783efd): `ILlmProvider` agnostik + GeminiProvider(REST)+GroqProvider(OpenAI-uyumlu)+FallbackLlmProvider + SaltOkumaGuard. ✅ Araçlar+loop **build YEŞİL + commit (2766100, 18.06)**: AsistanAraclar.cs (sql_sorgu salt-okuma+PII maske / sema_oku / ornek_sql_bul golden-record / gorev_*), AsistanService.cs (tool-use loop + sema-kurallı sistem-prompt), Program.cs (DI). **YARINA:** ~~(1) build doğrula+commit ✅~~ · ~~(2) Asistan.razor veri-sorgu modu ✅ (184c72a — Veri Sor kartı + cevap balonu + araç izi)~~ · ~~(3) Gemini çok-model rotasyon ✅ (2e9cbf1, GEMINI_MODELS liste → 429/503 sıradaki model → Groq)~~ · ~~(4) canlı test ✅ "dün ciro?" → 1.278.364,92 ₺ (MCP ile mutabık); araç izi sql_sorgu→sema_oku→sql_sorgu~~. ✅ **UI yeniden tasarım (chat, 18.06)**: tek sohbet kutusu + niyet ayrımı (soru→veri / not→taslak) + DaisyUI chat balonları + taslak kartı (Kaydet/Ata/Düzelt onaylı) + hızlı-öneri çipleri + açık görev listesi. ✅ **Not→görev bulut LLM**: TaslakUretAsync Gemini→Groq→yerel qwen (en son fallback). ✅ **Niyet heuristiği KALDIRILDI → LLM-yönetimli tek akış (18.06, kullanıcı kararı)**: tüm mesajlar SorAsync; LLM niyeti+bağlamı yönetir (takip "evet/güncelle" kopmaz), iş/not→`gorev_taslak_oner` (onaya sunar, otomatik kaydetmez), tarih yoksa son-30-gün varsay. Heuristik "mısın→not" + "evet→Özlüce few-shot sızması" bug'larını çözdü. **Odak kararı: SQL/veri-sorgu İKİNCİL** (kullanıcı "şu an önemli değil") — görev/not asistanı + temiz konuşma birincil. Kalan: (a) **unified akış CANLI test** (quota tükendiği için ertelendi — kotalar dönünce: not→taslak→onay, takip bağlamı, güvenlik yazma-reddi) · (b) GeminiProvider defansif/rotasyon (9bbfaae) canlı doğrula · (c) öğrenen katman (PanelAsistanBellek — kalıcı tercih "varsayılan 30 gün" hatırlama). Plan-20 master. ✅ **Faz-2 Gmail+Takvim TAMAM (plan-21, 18.06)**: Google OAuth (`21b11c7`) + takvim/mail araçları + onay kartları (`130c9b3`) + Meet/davetli/online-yüzyüze/tarih (`a2e9949`/`eed78be`/`886e5db`). Canlı: bağlandı, etkinlik-öner+onay-kartı (auto-exec YOK), inbox-özet gerçek. Dış-aksiyon (oluştur/gönder) = kullanıcı onayı. ✅ **OpenRouter LLM zinciri (`6370877`)**: OpenRouter→Gemini→Groq, iç-model rotasyon. ✅ **plan-22 öğrenen katman TAMAM (Hermes-uyarlı)**: PanelAsistanBellek (`73c87f6`) + bellek_yaz/gecmis_ara + Snapshot-FROZEN + GuvenlikTara; görev SonTarih (`f170f3f`); **Genius ismi+lambadan-cin maskotu** (`5964999`); 99-komut repertuar (`ab77724`). Canlı: bellek_yaz→DB, tercih yeni-konuşmada uygulandı. **KALAN (kota tükendi, 19.06 03:00 reset / $10→1000gün):** (a) canlı-test: gecmis_ara + no-auto-compact + güvenlik-reddi + due-date uçtan-uca + pano-AI derin-özet + markdown + SQL-kalite (qwen3-coder) · (b) **sen:** Faz-2 etkinlik-Oluştur+mail-Gönder Chrome'da onayla, auth-şifre değiştir · (c) free-SQL yetersizse $10 kredi/Gemini-paid kararı · (d) plan-22 Adım-8 (ops: "Bellek olarak sakla" butonu + consolidate-sema bellek-curator) · (e) LlmService/LLamaSharp tam-kaldırma. Faz-3 ajanda + WhatsApp-bildirim backlog.
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
- [ ] **C-09** `claude-context-template` `bootstrap.sh`'a multi-project flag ekle (`--multi-project bkm,yonetiq`).

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
- [ ] **C-15** (opsiyonel) TODO.md split per-project: `TODO/bkm.md` + `TODO/_crossproject.md` + `TODO/yonetiq.md`. Race condition azaltır. ADR-002'de tartışıldı.
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

### Sezon kadro savunması (02.09.2026) — takip maddeleri

- [x] **K-01 KAPANDI — kayıt hatası YOK, kişi çalışmaya devam ediyor** ✅ 03.09.2026 (kullanıcı: "k-35 devam ediyor kontrol ettirdim") — Şura'daki 2025 girişli sezonluk personelin çıkışı işlenmemiş DEĞİL; fiilen çalışıyor. **Sezonluk 62 ve 5 mağaza 211 DOĞRU**, düzeltme gerekmiyor. Ders: 375 günlük kıdem tek başına 'çıkış işlenmemiş' kanıtı değildi — iki oturum boyunca ÇIKARIM ölçüm gibi taşındı ve desteye dipnot olarak girdi. Dipnot `scripts/sunum_slayt_maliyet.py`'de düzeltildi (yeni metin: 62'nin 61'i bu yıl, 1'i geçen yıl girişli ve çalışmaya devam ediyor — İK teyidi).
- [ ] **K-02 Heykel sezonluk alım açığı** — 02.09. Norm 20, alınan 13 (−7), aktif 9. Alım en geç Heykel'de başladı (10.08; 14.08'e kadar 2 kişi) ve ayrılma oranı en yüksek (3/13 = %23). Sebep (aday bulunamadı / onay / ihtiyaç görülmedi) veriyle ayrılamıyor — operasyonla konuşulacak.
- [ ] **K-03 Heykel/Şura POS raporlama kör noktası** — 02.09. İkisi ayrı tüzel kişilik (Bursa Kültür Merkezi / Asiye Bingölbalı) ve DerinSIS eTip 100'de satışları YOK → iş hacmi, kişi başı verimlilik ve "norm gerçekten gerekli mi" soruları o iki mağaza için ölçülemiyor. Çözüm seçenekleri: (a) o firmaların POS'unu DerinSIS'e bağlamak, (b) ayrı kaynaktan aylık özet almak.
- [x] **K-04 Üç denetim ajanı bulgularının işlenmesi** ✅ 03.09.2026 (commit c884efb + 0eca76c kritik, eb96f7f orta/düşük) — python-reviewer · silent-failure-hunter · sql-denetci bulguları işlendi; kalan tek madde dosya-boyutu borcu (K-20).
- [ ] **K-05 Sezonluk tutunma aksiyonu** — 02.09. Kadrolu alımın 14 gün tutunması %95,7 → %75,0 (32 alımdan 10'u ayrıldı). En bozuk: Özlüce, Heykel, Merkez Depo. Aksiyon: ilk hafta karşılama protokolü + İdari İşler ücret–vardiya revizyonu. Ölçüt: gelecek sezon Eylül öncesi kayıp %20 → %12.

#### Denetim ajanı orta/düşük bulguları (03.09.2026 — commit eb96f7f ile DÜZELTİLDİ)

Rakamlar değişmedi (kadro 143→160 · adet 574.655→775.031 · norm 217 vs operasyonel 189 = −28);
tek anlamsal düzeltme bölüm açığında (17 → 15 + 2 teyit bekleyen). Doğrulama: 65/65 tutarlılık ✓ ·
yerleşim ihlali yok ✓ · 17 slayt PowerPoint COM ile PNG export edilip gözle kontrol edildi.

- [x] **K-06 Normda tanımlı ama kayıtta hiç personeli olmayan bölüm "açık" sayılıyordu** ✅ 03.09 —
  OYUN ALANI + MUHASEBE ayrı "teyit bekliyor" satırına alındı (bölüm açığı 17 → 15, teyit 2).
  ⚠ **Kalan iş:** OYUN ALANI Zirve `Departman` listesinde HİÇ yok → ya bölüm gerçekten boş ya
  bölüm adı farklı yazılı (key-mismatch). İK ile teyit edilecek.
- [x] **K-07 Kayma dilimlerinde boş-dilim / gün-eşitliği / büyüme-bandı guard'ı yoktu** ✅ 03.09 —
  boş dilim veya eşitsiz pencere artık `sys.exit`; bant dışı büyüme (−%50..+%200) durduruyor;
  negatif "Eylül'e kayan" uyarı basıyor.
- [x] **K-08 `gunler[yil]` mağaza döngüsünde eziliyordu** ✅ 03.09 — gün sayısı mağaza×yıl bazında
  ölçülüyor, yıllar arası eşitsizlik → çıkış, pencereden az gün → uyarı + JSON'a kayıt.
- [x] **K-09 Engelli taramasında Personelno biçim guard'ı sessiz kayıp üretiyordu** ✅ 03.09 —
  atlanan kayıt sayısı ölçülüyor (bugün 0), denetçi 0 değilse sapma veriyor.
- [x] **K-10 Destede donmuş yorum rakamları** ✅ 03.09 — 4 yıllık trend (60→91, +%11,3, +%28,8),
  mağaza performans oranı (2,2x), 1–14/15–31 Ağustos büyümesi, sezonluk kesim farkı, itiraz
  slaytındaki 2,5 gün / 6→2 / +%25,1 hepsi JSON'dan türetiliyor.
- [x] **K-11 3 POS kadrosu iki ayrı sorgudan geliyordu (2025 hiç sınanmıyordu)** ✅ 03.09 — kadro
  tek kaynak (`magaza_kadro`); denetçi her iki yılı mutabık kılıyor.
- [x] **K-12 Kategori "Oca-Ağu ciro Δ" sıfır dolgusu** ✅ 03.09 — bilinmeyen değer "—".
- [x] **K-13 Sunum kategori tablosu adedin %78'ini gösteriyordu** ✅ 03.09 — eşleşmesiz 6 kategori
  DİĞER satırında toplandı + kapsam dipnotu; denetçi kapsam oranını sınıyor.
- [x] **K-14 Şablon değişirse sessizce başlıksız slayt** ✅ 03.09 — `L()`/`setph()` bulamazsa çıkış.
- [x] **K-15 Bölüm slaytında taban farkı ile kesim farkı karışıyordu** ✅ 03.09 — cümle grafiğin
  kaynağıyla eşitlendi (31.08 kesim farkı).
- [x] **K-16 Aynı destede iki farklı "kişi başı iş" ölçeği** ✅ 03.09 — başlıklarda ölçü adlandırıldı
  (okul-hizalı ÷ TÜM kadro · Oca-Ağu ÷ kadrolu) + seviyelerin kıyaslanmayacağı yazıldı.
- [x] **K-17 pyodbc bağlantıları try/finally içinde değildi** ✅ 03.09 — mutabakat çıkışında da kapanır.
- [x] **K-18 As-of literalleri %-format ile gömülüydü** ✅ 03.09 — parametreli (`?`).
- [x] **K-19 Toplamlar iki emitter'da ayrı hesaplanıyordu** ✅ 03.09 — `veri["toplam"]` çekirdekte,
  emitter'lar okuyor (emitter-ayrımı); denetçi eşitliği sınıyor.
- [x] **Denetçi borçları** ✅ 03.09 — `tutarlilik_kontrol.py`'de kopyalanmış çapraz-sayfa formül
  bloğu silindi, 35 → 65 kontrol; `sunum_yerlesim_denetle.py` iki çıplak except → tipli + uyarı;
  üç scriptte Windows cp1254 UnicodeEncodeError → stdout utf-8.

- [x] **K-20 Dosya boyutu — veri + Excel tarafı bölündü** ✅ 03.09.2026 (plan: 39) —
  `verimlilik_excel.py` 2.283 satır → **11 modül**, en büyüğü 459 (hepsi <500): `verimlilik_ortak`
  (sabit + bağlantı + ASOF) · `verimlilik_cek_hacim` / `_kadro` / `_norm` / `_maliyet` ·
  `verimlilik_cek` (orkestrasyon, sorgu içermez) · `verimlilik_xlsx_ortak` / `_ozet` / `_hacim` /
  `_kadro` · `verimlilik_excel` (yalnız CLI — ad ve kullanım DEĞİŞMEDİ). Regresyon kanıtı: Excel
  hücre değerleri baseline ile **birebir (0 fark)**, JSON 1e-6 toleransında aynı, 94/94 tutarlılık ✓,
  deste 19 slayt ✓. Yan bulgu: `norm.bolum` sıralaması eşit açıkta çalışma-arası değişiyordu
  (set + PYTHONHASHSEED) → ikincil anahtar eklendi, çıktı tekrar-üretilebilir oldu.
- [x] **K-23 Sunum destesi split** ✅ 03.09.2026 (plan: 40) — `sunum_kadro_deck.py` 1.333 satır →
  **8 modül**, en büyüğü 361: `sunum_ortak` (palet + şablon durumu + çizim yardımcıları) ·
  `sunum_baglam` (`hesapla(v)` → SimpleNamespace, türetilmiş oranlar + dipnot metinleri) ·
  `sunum_slayt_kadro/_hacim/_norm/_maliyet/_kapanis` (tema bazlı, imza `slayt_x(C)`) ·
  `sunum_kadro_deck` (CLI — slayt SIRASI yalnız burada). Regresyon kanıtı: 19 slayt × 332 şekil
  (tür + geometri + metin + grafik serileri) baseline ile **0 fark**; yerleşim ihlali yok;
  tutarlılık 94/94. Yöntem: blok taşıma + tokenize tabanlı `C.` yeniden yazımı (STRING token'ına
  dokunulmadı — naif regex "fiili mal miktarını" gibi metinleri bozardı).
  Taşımanın açığa çıkardığı iki yapısal tuzak: (a) şablon durumu modül gövdesinde kuruluyordu →
  `ac(tpl)` tek giriş noktası, import artık yan etkisiz; (b) `nrm/mal/fm/al/ay2/ky` bir blokta
  atanıp sonrakinde okunuyordu → bağlama taşındı.

#### İK danışman denetimi — desteyi güçlendirecek eksik eksenler (03.09.2026)

- [x] **K-21 Maliyet ekseni destede** ✅ 03.09.2026 (commit e3226d9) — kaynak Zirve bordro
  `vw_PuanBil`, maliyet = Bt + Isskk + Iisk (brüt + işveren SGK + işveren işsizlik). Oca–Tem, üç
  POS mağazası: maliyet 31,2M → 47,2M ₺ (+%51,5) · kişi-ay başına maliyet 39.893 → 55.160 ₺
  (+%38,3 → artışın ana kaynağı ÜCRET, kadro değil) · **maliyet/ciro %12,85 → %12,15 = −0,70 puan**
  · kişi-ay başına ciro +%46,2. Excel «Maliyet» sayfası + sunum slaytı + itiraz maddesi.
  ⚠ Kalan iş: kıdem karşılığı ve yan haklar (giyim/yemek/yol) formülde YOK → maliyet ALT SINIR;
  tam işveren maliyeti isteniyorsa 740/760/770 GL kalemleriyle mutabakat gerekir.
- [x] **K-22 "Kadro alınmasaydı" karşı-argümanı** ✅ 03.09.2026 (commit e3226d9) — bordro fazla
  mesai saatlerinden (fm1+fm2+fm3), PDKS'ye gerek kalmadı. Fiili kişi başı yıllık FM 97 → 107 saat
  (yasal 270'in altında); kadro 2025 seviyesinde kalsaydı 75 kişi-ay eksik kapasite → +14.625 saat
  FM → **342 saat/yıl → 4857 s.K. m.41 sınırı AŞILIRDI**. Karşı-metrik dürüstçe yazıldı: yıllık
  sınır hızında çalışan kişi-ay 32 → 95 (kadro hâlâ dar). ⚠ Kalan iş: model işgücü ihtiyacını kişi
  sayısıyla doğru orantılı varsayar; kısmi süreli/hafta sonu düzenlemesi ve verim artışı yok →
  ÜST SINIR tahmini olarak sunulur.
- [x] **K-24 Sema değişmez mekanizması genişletildi (çok sunucu + bordro)** ✅ 03.09.2026 —
  `tools/sema_degismez.py` başka oturumda doğdu (tek sunucu, 8 kayıt). Genişletme: `sunucu` alanı
  (`erp`/`zirve`/`joker`) + adlandırılmış örnek için pyodbc (Zirve'ye pymssql portsuz erişemiyor,
  bağlantı asılıyordu) + hedef başına tek bağlantı + yapısal denetim (`neden`/`soru`/`db` boş
  olamaz, `karsilastirma` whitelist — Belinza xUnit koşucusundan) + `--sadece <id>`. Bu oturumun
  6 bordro/kadro/Sınav değişmezi eklendi, **altısı da kırmızıya düşürülüp geri alındı**. Toplam
  14 değişmez / 2 hedef, 0 kırık. Kurallar Belinza'dan uyarlandı:
  `.claude/rules/olctum-mu-cikardim-mi.md` (ÖLÇÜLDÜ/ÇIKARIM etiketi) + `error-handling.md`
  § Reddet mi Say mı (çelişki → reddet, eksik → say).
- [x] **K-25 `urnTip=2` dışlaması kasıtlı mı — ÖLÇÜLDÜ, dışlama DOĞRU** ✅ 03.09.2026 —
  urnTip 1 ve 2 **aynı sınıf, ikisi de mal değil**: irsHrk stok hareketi **0**, `bkm.UrunBilgi`
  master'ında **0** kayıt, yalnız `fatAyr` fatura kaleminde var (1 → 97.165 · 2 → 5.888 kalem).
  Yani `WHERE urnTip=0` dışlaması kasıtlı, sessiz veri kaybı YOK; hiçbir rapor düzeltmesi
  gerekmiyor. **Etiket düzeltildi:** "demirbaş/araç satışı" yanlıştı — 52 kaydın 38'i `H-0xx`
  fatura hizmet/gelir kalemi (Ciro Prim Geliri · Kampanya Fiyat Farkı · Hizmet Bedeli · Fiyat
  Farkı · Hasar Tazmin · Tevkifatlı Satış · Kira Geliri, hepsi KDV oranı varyantlı), 14'ü
  `252.10.xxx` gayrimenkul/arsa kartı (252=Binalar); araç satışı yalnız 2 kayıt. Tek örnekten
  türetilen etiket sınıfı yanlış tanımlıyordu ("başka ne olabilir?" kapısı). Yeni değişmez
  `mal-olmayan-kalem-stok-hareketsiz` (kırmızıya düşürülüp geri alındı) → bir gün bu kartlara
  stok hareketi girerse yakalar. Arşiv: `sorgular/2026-09-03-urntip-mal-olmayan-kalem.sql`.
  ⚠ GL/fatura analizinde (fatAyr, mizan) bu kalemler MEŞRU gelir/gider → orada urnTip filtresi
  uygulanmaz (codes.yaml'a yazıldı).
- [x] **K-26 `queries.yaml` kataloğu koşulabilir hale getirildi + 9 yapısal değişmez** ✅ 03.09.2026
  — `tools/sema_sorgu_dumani.py`: her kaydın SQL'i `COUNT(*) FROM (<sql>)` içine sarılıp koşar.
  **İlk koşu 15/15 değil 12/15 verdi**: `Sales.SaleDate` kolonu yok (doğrusu `Date` — ve
  `entities.yaml` bunu zaten yazmıştı, sema kendi içinde çelişiyordu). Düzeltince iki katman daha
  çıktı: header'da `DiscountTotalDirect` yok (`DiscountTotal`), `SalesProducts`ta `Quantity`/
  `RowTotal` yok (`Amount`/`TotalPrice`). **Kırık sorgular silinmedi** — doğru adlar ölçüldü, SQL
  düzeltildi (+ iade işareti + net KDV-hariç), damga bugüne çekildi → 15/15 koşuyor. Ölçülen yeni
  kimlik: `SUM(TotalPrice) = GrossTotal − DiscountTotal`, net KDV-hariç = `TotalPrice − VatTotal`
  (kalem ve header birebir: 7.760.175,16). Katalogun taşıyıcı yapısı 9 değişmeze çevrildi
  (belge tipi kümesi · POS-ürün köprüsü · kalem-header mutabakatı · JOKER linked server · kanal
  4 değeri · COD durum kodları · irsHrk kolonları · üç POS mağazası · depo emirAyr kolonları),
  dokuzu da kırmızıya düşürülüp geri alındı. Her değişmez `korur: [query-id]` taşıyor, koşucu
  bunu katalogla çapraz denetliyor (yazım hatalı referans yakalanıyor). **24 değişmez / 2 hedef,
  0 kırık.**
- [x] **K-27 `codes.yaml` tip kümeleri lookup'tan yeniden yazıldı** ✅ 03.09.2026 — 12 kod kümesi
  canlı ölçüldü. **`irsHrk.ehTip`: 8 kod belgelenmemişti** (18 Mağaza İçi İşlemler · 88 Diğer
  Giriş **364K kayıt** · 89 Diğer Çıkış · 90 Ürün SAY 160K · 92 Boş Paket · 95 Dönüşüm · 96 Bozuk
  Ürün · 98 Şirket İçi Kullanım); ciro filtreleri (4/100, 5/101) etkilenmiyor ama stok tarafı bu
  kodlarla dolu. **`fat.eTip`: 13 kodun 7'si eksikti** (6 Hizmet · 7 Gider · 8 Fiyat Farkı ·
  9 Fiyat Farkı Düzeltmesi · 10 İade Fark Faturası · 11-12 satış fiyat farkı). `sip.eTip` elle
  yazılan liste ile birebir tuttu. `irs.eTip` (başlık) ile `irsHrk.ehTip` (satır) AYNI küme
  (ölçüldü). Kümeler artık `irsTip_vw`/`fatTip_vw`/`sipTip_vw`'den okunuyor, canlıda
  kullanılmayanlar "canlıda yok" diye işaretli. 4 kapanma değişmezi eklendi (referans bütünlüğü,
  elle liste değil) → **28 değişmez, 0 kırık**. `posOdmTip` + `J_ORDERS.PAYDEFREF` kolon adı da
  belgelendi.
- [ ] **K-28 Fiyat farkı faturaları ürün maliyetine girmiyor** — maliyet zinciri (B-104 ölü stok
  ORT_ALIS, `olu_stok_excel.py:84`) `fat.eTip=0` kullanıyor; `8 Fiyat Farkı` · `9 Fiyat Farkı
  Düzeltmesi` · `10 İade Fark Faturası` dışarıda. Tedarikçi sonradan fiyat farkı kestiğinde ürün
  maliyeti EKSİK kalıyor (alt sınır). Ölç: 2026'da fiyat farkı faturalarının alış tutarına oranı;
  materyal ise ORT_ALIS zincirine ekle. `codes.yaml` fat.eTip'e yazıldı.
- [ ] **K-29 `bkm.IrsTipGrupMap` boş duruyor** — 21 kolonlu gruplama tablosu (TipId · AnaGrupKodu ·
  SatisPaydaMi · AlisMi · TransferMi · SirketIciMi · SayimMi…) bizim app-owned `bkm` şemamızda ama
  **0 satır**. Raporlardaki hardcoded `ehTip IN (4,100)` / `IN (5,101)` listeleri buradan
  okunabilir (tek kaynak). Doldurmak ERP yazması → `erp-write-policy.md` izin listesinde değil,
  **kullanıcı onayı gerekiyor**. → **Öneri hazır: `plans/41-irstipgrupmap.md`** (açık soru 1 CEVAPLANDI: 88/89 =
  manuel düzeltme kanalı, %85-91'i 31.12.2025 WMS–ERP eşitlemesi; sebep `eNot` metninde) (34 kodun canlı giriş/çıkış ölçümü + grup/bayrak taslağı + 4 açık soru). Yazma YAPILMADI; onay + `erp-write-policy` izin listesine ekleme bekliyor.
- [x] **K-30 Ödeme tipi kümeleri ayrıştırıldı + kart/havale etiket hatası düzeltildi** ✅ 03.09.2026
  — kullanıcı düzeltmesi: üç ayrı sistem karıştırılmamalı. `joker.J_ORDER_PAY_TYPES` = **e-ticaret**
  (`J_ORDERS.PAYDEFREF`; -13 iyzico 4,19M · -3 COD 485K · -1 havale 6,5K) · `dbo.posOdmTip` =
  **kasa** (Nakit/Kredi Kartı/Döviz/Diğer) · `encore_odeme_grup` = **EncoreMerkez kasa üst-grubu**
  (PaymentTypes 14 satır ölçüldü). Üçüne kapsam uyarısı yazıldı. **Bulgu:** `_default` kuralı HAVALE
  ve ÇEK'i "Kredi/Banka Kartı" sayıyordu (BANKA HAVALE 486 · BURFAŞ ÇEK 48; ~%0,03 — küçük ama
  yanlış etiket). `MagazaQueries.cs OdemeGrubu()` düzeltildi (Havale · Çek · Para Üstü), **build
  0 hata**. Ders: `_default` bir kova değil, ÖLÇÜLMEMİŞ kalan demek.

- [x] **K-31 sqlcli v2.2 — dört yeni yetenek (cross-repo: `D:\Dev\sqlcli`)** ✅ 03.09.2026 —
  kullanıcı isteği ("ilave özelliklere ihtiyacı varsa eklemelisin"). **`assert`** (skaler sorgu +
  `--eq/--ne/--ge/--le/--gt/--lt`, `--label`, `--why`; **exit 0 geçti · 1 KIRIK · 2 KOŞAMADI** —
  koşamamak yeşil sayılmaz) · **`lookup`** (kod tablosu → YAML/JSON + `--count-from` canlı kullanım
  sayısı; kullanılmayan kod "canlıda yok" işaretlenir) · **`--read-only` / `SQLCLI_READONLY`**
  (yazma reddi; string ve yorumlar elenerek taranır → `erp-write-policy` araç düzeyinde zorlanır) ·
  **`--param ad[:tip]=deger`** (str/int/dec/date/datetime/bool/guid; tarih TAHMİN EDİLMEZ,
  `dd.MM.yyyy` reddedilir — ölçülen vaka: `20260901` tam sayıya düşünce datetime karşılaştırması
  patlıyordu) · **`--timeout` / `--retry`** (yalnız geçici hata 10053/10060/-2/1205, sınırlı ve
  görünür) · **`${ENV}` genişletmesi** (şifre `sqlcli.json`'da durmaz; karşılığı yoksa hata verir) ·
  **UTF-8 çıktı** (konsol cp857 yazıyordu, belgeye aktarılan Türkçe bozuluyordu).
  Depo **git altına alındı** — `.git` yoktu, v2.1 çok-sağlayıcı işi de commit'siz duruyordu:
  `68e02d5` taban + `50ad562` v2.2. Build 0 hata/0 uyarı, global tool 2.2.0, altı yol canlı test
  edildi (ERP + Zirve). Pusula tarafı (commit `13f8993`): `sqlcli.json` 4 profil (şifresiz →
  gitignore'dan çıkarıldı, commit'lenir) · `tools/sq.sh` kodlama-esnek (UTF-8 dene → cp857) ·
  kural `sql-server-conventions.md § SORGU ARACI` yetenek tablosuyla güncellendi.
  ⚠ Kalan: `tools/sema_degismez.py` hâlâ kendi Python koşucusu — 28 değişmez `sqlcli assert`e
  taşınabilir (JSON-sürücülü toplu koşum ve çok-sunucu orada yok, o yüzden acil değil).

- [ ] **K-32 Sahaf girişi: resmi evraksız giriş, stoğa SIFIR maliyetle giriyor** — 88/89
  ölçümünde çıktı. `SahafGiris` belgeleri `ehTip=88` (Diğer Giriş) ile yazılıyor; **kullanıcı
  teyidi (03.09): sahaf resmi olmayan giriştir, resmi evrak yoktur** → alış faturası olmadığı
  için `ehTip IN (0,10)` dışında olması YERİNDE, hata değil.
  **ÖLÇÜLDÜ:** 2026'da 12 belge / 4.844 satır / 4.234 ayrı ürün / +5.480 adet (06.05–27.08.2026);
  **4.844 satırın 4.844'ü `ehMlyt=0`** — yani sahaf ürünü stoğa sıfır maliyetle giriyor.
  **Sonuç (ÇIKARIM, teyit bekliyor):** maliyet tabanı olmayan bu ürünler satıldığında SMM
  görünmez → brüt kâr olduğundan yüksek çıkar; envanter TL değeri de eksik kalır. Ölü stok
  maliyet imputation'ı (B-104: `fiyatS` × kategori oranı) bunları fiyatlıyor olabilir.
  ⚠ Ölçüm KARIŞIK: aynı `stkID`'ler resmi alışla da satılıyor, o yüzden "sahaf satışı = şu
  kadar kâr şişmesi" DENEMEDİ — ayrıştırma partiye/FIFO katmanına bakmayı gerektirir.
  **Kullanıcı yarın süreç bilgisini getirecek** (03.09 notu); ondan sonra: (a) maliyet nasıl
  atanmalı (0 mı, tahmini alış mı, kategori marjı mı), (b) K/Z ve envanter raporlarında
  ayrı satır mı gösterilsin, (c) plan 41'de grup ataması buna göre kesinleşir.
  Arşiv: `sorgular/2026-09-03-irstip-88-89-diger-giris-cikis.sql`

- [ ] **K-33 Sezon sonu ayrılmaları SGK'da "istifa" olarak yazılıyor — İK'ya sorulacak** —
  ÖLÇÜLDÜ 03.09.2026. Çıkış kodu sözlüğünde (`DerinSISBkm.iky.ayrilma_neden`) `18 İşin sona
  ermesi` · `19 Mevsim bitimi` · `20 Kampanya bitimi` kodları VAR, ama Zirve'de bu üçünün
  kullanımı **tüm zaman 0**; karşılığında 212 sezonluk çıkış kaydı var. 2025-2026 mağaza
  sezonluk çıkışları: **03 istifa 60 · 02 deneme süreli işçi feshi 26 · 01 deneme süreli
  işveren feshi 4 · 05 belirli süreli sözleşme bitimi 1**.
  **Neden önemli:** (a) sezonluk devir/istifa oranı yorumlanırken "istifa" sayısı yapay
  yüksek görünüyor — kadro savunmasında bu çıkarım yapılamaz; (b) kod seçiminin doğruluğu
  ve çalışanın hak/ödenek durumu **mevzuat + İK teyidi** gerektirir (biz hüküm vermiyoruz);
  (c) sözlükte olmayan 3 kod kullanılıyor: 45 (4 kişi) · 46 (1) · 48 (5) — SGK'nın sonradan
  eklediği kodlar, sözlük 36'ya kadar.
  **DIŞ KAYNAK (web araştırması 03.09, ÖLÇÜM DEĞİL — iki bağımsız kaynakta örtüştü):**
  · Kod 19 Mevsim bitimi = mevsim sonu çıkış + takip eden mevsimde tekrar giriş (akit askıda);
    kıdem/ihbar/işsizlik ödeneği doğmaz. **Personel bir sonraki sezon geri alınmayacaksa
    kod 4 kullanılmalı** (kod 4 ödeneğe hak kazandıran kodlar arasında).
  · Yani bugünkü pratik (03 istifa) ile 19 arasında ÖDENEK açısından fark yok; asıl ayrım
    "geri alınacak mı" (19) vs "alınmayacak" (4).
  · **Ayrıca 45/46/48 = İş Kanunu m.25 (işçinin kusuru) kapsamı:** 45 sataşma/alkol-uyuşturucu ·
    46 güveni kötüye kullanma-hırsızlık · 48 izinsiz devamsızlık. Bu kodlarda kıdem/ihbar/ödenek
    doğmaz. **Bizim veride 10 kişi bunlarla çıkmış (45→4 · 46→1 · 48→5)** — "istifa" değil
    DİSİPLİN; devir/ayrılma analizinde ayrı sayılmalı.
  · Kaynaklar özel hukuk/muhasebe siteleri (muhasebetr, kadimhukuk) — **SGK resmî yayını değil**;
    hukuki sonuç için İK + mevzuat teyidi şart. Biz hüküm vermiyoruz.
  **Sorulacak:** (a) sezonluk çıkışlarda hangi kod kullanılmalı (19 mu 4 mü — geri alım
  niyetine göre), (b) mevcut kayıtlar düzeltilecek mi, (c) 45/46/48 ile çıkan 10 kişi
  gerçekten disiplin vakası mı (kod yanlış girilmiş olabilir).
  Arşiv: `sorgular/2026-09-03-zirve-cikis-kodlari.sql` · sema: `vw_PersonelDepartman`
  → `isten_cikis_kodu` + `sezon_cikis_kodu_tuzagi`.

- [x] **K-06 kalıntısı ÇÖZÜLDÜ — norm'un iki karşılıksız satırı ölçüldü** ✅ 03.09.2026 —
  ikisi de veri hatası değil, sebepleri AYRI:
  · **OYUN ALANI (norm Özlüce 1):** departman Zirve'de VAR — önceki oturumda "Departman
    listesinde yok" sanılmıştı, **yanlıştı**. ÖZLÜCE / Kadro=KADRO / ünvan "ÇOCUK GELİŞ. VE
    EĞİT. ELEMANI" / giriş 13.11.2024 → çıkış 04.05.2025 (kod 03 istifa). Pozisyon Mayıs
    2025'ten beri boş → **GERÇEK AÇIK (1 kişi)**, bölüm açığına eklenebilir.
  · **MUHASEBE (norm Heykel 1):** HEYKEL'de 1 kişi vardı, çıkış 26.10.2025. ŞURA ÖN MUHASEBE
    4 kişinin tamamı çıkmış (son 31.10.2025). GENEL YÖNETİM MUHASEBE 4 aktif → muhasebe
    **Ekim 2025'te merkeze taşınmış**; Heykel normundaki satır **BAYAT NORM**, açık değil.
- [x] **K-34 KARAR VERİLDİ: norm olduğu gibi kalıyor** ✅ 03.09.2026 (kullanıcı: "kalsın şimdilik norm o şekilde") — norm kadrolu **145**, toplam **217**, fark **28**, bölüm açığı **15** DEĞİŞMEDİ; deste ve Excel yeniden üretilmeyecek. Ölçüm gerekçe olarak duruyor (OYUN ALANI gerçek açık · Heykel MUHASEBE bayat norm) ama **rakama yansıtılmıyor** — norm bir yönetim parametresi ve kullanıcı olduğu gibi bırakmayı seçti. Destedeki dipnot zaten "normda yazılı olup kayıtta personeli olmayan 2 satır açığa katılmadı; teyit bekliyor" diyor, o cümle doğru kalıyor. ⚠ Sonraki oturum bu satırları "düzeltmeye" kalkmasın: sapma değil, KARAR. Yeniden açılırsa uygulama sırası: norm JSON'una satır SİLMEDEN bayat notu → `verimlilik_cek_norm.py` → deste+Excel yeniden üretim → 167 kontrol yeşil.
- [ ] ~~K-34 eski hâli~~ —
  K-06 ölçümü iki deste rakamını etkiliyor, **karar kullanıcıda** (norm yönetim parametresi):
  · Bölüm bazlı açık **15 → 16** (OYUN ALANI gerçek açık olarak eklenirse).
  · Norm kadrolu **145 → 144** ve norm toplamı **217 → 216**, dolayısıyla "norm vs gerçek"
    farkı **28 → 27** (Heykel MUHASEBE satırı bayat sayılıp düşülürse).
  · Karar verilirse: `briefings/sezon-kadro-*/norm-kadro-*.json` notu güncellenir (satır
    SİLİNMEZ, "bayat: muhasebe merkeze taşındı 10.2025" notu eklenir), `verimlilik_cek_norm.py`
    yeniden koşar, deste + Excel yeniden üretilir, tutarlılık kontrolü (167) yeşil doğrulanır.
  · Karar verilmezse deste bugünkü hâliyle doğru kalır — dipnotta "normda yazılı olup kayıtta
    personeli olmayan 2 satır açığa katılmadı" cümlesi zaten var, ölçüm artık gerekçeyi biliyor.
- [x] **K-35 KAPANDI (⚠ K-01 ile AYNI İŞ — dup)** ✅ 03.09.2026 — İK kontrol etti, kişi çalışmaya devam ediyor; 62 doğru. **Süreç hatası:** bu madde açılırken `todo-verification.md` S3 dup-grep adımı atlandı; K-01 zaten aynı kaydı anlatıyordu. Detay K-01'de. Eski metin: — 31.08.2026 aktif
  sezonluk 62 = 61 (2026 girişli) + **1 (ŞURA, giriş 21.08.2025, 375 gün kıdem)**. Bir sezonluk
  kaydın bir yıldan uzun aktif kalması ya çıkışın işlenmemesi ya fiilen çalışmaya devam etmesi
  demek (Kadro hâlâ 'SEZONLUK'). Düzeltilirse sezonluk 62 → 61. Rakamlar İK'nın resmî kaydıyla
  birebir tutulsun diye deste bugünkü hâliyle bırakıldı. Arşiv: `sorgular/2026-09-03-zirve-cikis-kodlari.sql`

- [x] **K-36 ÇÖZÜLDÜ — çerçeve yanlıştı: 16 alış değil, kod zaten doğru** ✅ 03.09.2026 — ölçüm: 2026'da 16 hareketlerinin yalnız **%0,05'i** (33 satır / 525 adet) aynı ürün+mekan+gün'de bir alışla birlikte geçiyor → WMS eklemesi alışın kopyası değil, ama 'alış' da değil. Kod zaten amaç bazlı ayırıyor: alış metriği `IN (0,10)` (`SatinalmaQueries` #a, `RefQueries.Envanter` AlisAdet) · ürünün ilk stok girişi `IN (0,10,13,16,99)` (#ilk). **Düzeltme gerekmiyor**; K-36'nın ilk çerçevesi ('1M adet giriş kaçıyor') yanlıştı. Ama araştırma asıl sorunu buldu → K-37. Arşiv: `sorgular/2026-09-03-irstip-16-90-99-sayim-wms.sql` (K-36 eki). Eski metin: — 16/90/99 ölçümünde
  çıktı. 2026'da `16 Stok EKLE` **+1.052.596 adet** (184 belge, `eNot='WMS'`, günlük); kıyas:
  alış (0) +3.775.253 · yerel alım (10) +2.595.439. Yani **girişi `ehTip IN (0,10)` diye
  tanımlayan analizler yılda ~1M adet girişi kaçırıyor** (satınalma performansı, devir hızı
  payda/pay tutarlılığı, bulunurluk besleme analizi). Yapılacak: (a) hangi raporlar `IN (0,10)`
  kullanıyor — `grep` ile listele, (b) her biri için WMS eklemesinin dahil olup olmaması
  gerektiğine karar ver (WMS eklemesi çoğu zaman transfer/sayım düzeltmesi olabilir — sebep
  kırılımı `eNot`'ta yalnız 'WMS' yazıyor, daha ince ayrım için WMS tarafına bakmak gerekir),
  (c) karar plan 41'in `AlisMi` bayrağına yansır. Arşiv:
  `sorgular/2026-09-03-irstip-16-90-99-sayim-wms.sql`

- [x] **K-37 DÜZELTİLDİ — merkez depo stoğu WMS ay-sonu snapshot'ından okunuyor** ✅ 03.09.2026 (kullanıcı: "aylık snapshot ile düzelt") — üç yer değişti: `OdakQueries.cs` (yeni `depo` CTE + `dp.Mrkz`, mağazalar view'da kaldı) · `RefQueries.Envanter.cs` kategori-çeşit (UNION ALL: mağaza view + depo WMS) · `scripts/export_odak_stok.py`. **Build 0 hata.** Ölçülen etki: merkez depo toplamı 1.987.630 → **4.249.866**; kategori çeşidi ana kalemlerde yakın (Kırtasiye 3,04M→3,01M · Kişisel Bakım 393K→399K · Hediyelik 242K→207K · Oyuncak 219K→179K) ama **kitap tarafında belirgin düşüş** (Kitap çeşit 1.254→127 · Hazırlık 31→2) ve **'Genel' kategorisi düşüyor** (view'daki 2,16M = Geri Dönüşüm Kağıt 1.758.386 + poşetler; WMS satılabilir mal tutuyor). Gerekçe: view'ın depo defteri −4,24M negatif taşıyor (imkânsız). ⚠ WMS snapshot AYLIK (31.08.2026) — panelde ay-içi hareket görünmez; anlık depo stoğu istenirse WMS canlı tablosu ayrı iş. Eski metin: — K-36
  araştırmasının asıl çıktısı. `dbo.stokSonAltDepo_vw` mekan 12 için **1.987.630** adet
  veriyor; resmî `bkm.StokAyBakiyeMekanBazli` (Kaynak='WMS', 31.08.2026) **4.249.866** →
  **2,26M adet / 2,1 kat sapma**. Mağazalarda iki kaynak tutuyor (%0,3-4,8). Alt depo filtresi
  sebep değil (mekan 12'de yalnız `ehAltDepo=0` satır var). Sebep Ağustos'ta zaten yazılmıştı:
  *"DEPO (mekan 12): irsHrk ledger geçmişte BOZUK … WMS = tek doğru kaynak"*
  (`sorgular/2026-08-12-stok-ay-bakiye-mekan-tablo.sql` başlığı) — o zaman tek ürün örneğiyle,
  şimdi toplamda ölçüldü.
  **Etkilenen yerler:** `dashboard/Data/OdakQueries.cs:176` (Mrkz kolonu) ·
  `dashboard/Data/RefQueries.Envanter.cs:554` (Depo kolonu) · `scripts/export_odak_stok.py:46`.
  **Yapılacak (kullanıcı onayı gerekir — panel rakamı değişecek):** depo stoğunu
  `bkm.StokAyBakiyeMekanBazli` (Kaynak='WMS', son dönem) üzerinden oku; mağaza tarafı view'da
  kalsın. Sonra eski/yeni rakam mutabakatı + etkilenen ekranların smoke testi. ⚠ Dikkat: WMS
  snapshot AYLIK (ay sonu) — anlık depo stoğu isteniyorsa WMS canlı tablosu gerekir, o ayrı iş.

- [ ] **K-38 Stok snapshot job'u aylık koşmuyor + WMS damgası yanlış** — `bkm.StokAyBakiyeMekanBazli`
  detay ölçümü (03.09.2026): 29.234.965 satır · 64 dönem · 1,87 GB · 0 negatif · 0 mükerrer,
  ama **tüm tabloda tek yazım günü var: 14.08.2026**.
  · **Damga hatası:** `sorgular/2026-08-12-stok-ay-bakiye-mekan-tablo.sql` WMS satırını
    `Donem = EOMONTH(GETDATE())` ile yazıyor. 14 Ağustos'ta koşulduğu için satır **31.08.2026**
    damgalı, oysa değer **14 Ağustos anlık** stoğu. Panel (K-37) bunu "31 Ağustos depo stoğu"
    diye gösteriyor. Düzeltme seçenekleri: (a) ay-sonu koşum zorunlu kıl, (b) `Donem` yerine
    koşum tarihini damgala, (c) WMS satırlarına ayrı `AnlikTarih` kolonu ekle (bkm.* app-owned,
    ama şema değişikliği → onay).
  · **Job otomasyonu yok:** script elle çalıştırılıyor. Aylık SQL job/görev planlanmalı; yoksa
    depo geçmişi birikmiyor (şu an WMS için TEK dönem var, yani depo geçmişi YOK) ve panel
    giderek bayatlar. Canlı fark ölçüldü: WMS canlı 3.995.265 vs snapshot 4.249.866 (20 gün).
  · Yeni değişmez `stok-snapshot-tazeligi` (son yazımdan bu yana ≤45 gün) bunu bir daha sessiz
    bırakmaz — bugün 20 günle yeşil, aksarsa kırmızı.
  · **Job kurulum scripti HAZIR (03.09): `sorgular/2026-09-03-job-stok-ay-bakiye-kur.sql`** —
    job `BKM-Stok-AyBakiye-AySonu`, ayın son günü 23:30, idempotent, **ay-sonu guard'lı**
    (son gün değilse hiçbir şey yazmadan atlar → damga hatası kalıcı çözülür).
    ⚠ **KURULMADI:** `sqlcli script` çalıştırma denemesi ortam guard'ı (auto mode classifier)
    tarafından reddedildi; dolanılmadı. Kurulum için ya SSMS'te elle F5 ya da Bash izin kuralı.
    Salt-okuma doğrulaması geçti: WMS gövdesi 23.810 satır/3.995.265 adet · şube CTE derlendi ·
    `sp_add_jobschedule` parametreleri mevcut · PK çakışması yok · Agent ayakta (diğer job'lar
    03.09'da koştu). Neden hiç koşmamış sorusu da ölçüldü: `msdb.sysjobsteps` içinde bizim
    tabloyu yazan **0 adım** vardı, yerel görev planlayıcıda da kayıt yok — otomasyon hiç
    kurulmamış, script 14.08'de elle bir kez koşulmuş.
  · ⚠ Açık soru (kullanıcıya): panel depo stoğunu **canlı** `depo.stok_adres_palet_vw`'dan
    okusun mu? Snapshot geçmiş analiz için kalır. Canlıya geçilirse ÇIKIŞ ALANI'nın (543.555
    adet) dahil edilip edilmeyeceğine de karar gerekir.
