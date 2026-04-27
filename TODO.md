# TODO — sqlserver-mcp-server (Multi-Project)

Aktif yapılacaklar ve backlog. Bu dosya 400 satırı aşarsa tarihli konular ilgili `docs/journal/<proje>/`'a taşınır.

> **Format:**
> - Her ana başlık bir proje (`### BKM`, `### MCP Server (kod)`, `### CrossProject`).
> - Proje altında **BIRLESIK ONCELIK SIRASI** — Faz 0 (bugün), Faz 1 (bu hafta), Faz 2 (bu ay), Faz 3 (çeyrek).
> - Madde başında **kısa ID**: `B-NN` (BKM), `M-NN` (MCP), `C-NN` (CrossProject), `BL-NN` (Belinza), `Y-NN` (YonetIQ). Commit mesajlarında ve journal'da referans.

---

## Yapılanlar

### 2026-04-27 — Oturum 3: MCP CWD bug + Mayıs %50 kampanya scope (handoff)
- ⚠️ **MCP CWD bug** tespit: `claude_desktop_config.json`'da `cwd` yok → dotenv `.env` bulamıyor → `localhost:1433` fallback.
- ✅ Config-level fix dosyaları yazıldı: `claude_desktop_config.FIXED.json`, `fix-mcp-config.ps1`, `fix-mcp-config.bat`.
- ⏳ **Pending kullanıcıdan:** Claude Desktop tam restart (sistem tepsisi → Quit → tekrar aç).
- ✅ **BKM Mayıs %50 kitap kampanya tahmini TAM SCOPE'LANDI** — 4 karar onaylı (3 mağaza, hibrit baz May25×Apr26/Apr25, 3 senaryo, Excel). Execution restart sonrası başlayacak — bkz B-NEW-01..06.
- 📋 Detay: `docs/journal/_crossproject/2026-04-27.md` (Oturum 3) + `docs/journal/bkm/2026-04-27.md` (kampanya scope + RESUME).
- 🔁 **Yarın için trigger phrase:** "mayıs kampanyası" / "kitap %50 tahmin" / "kampanya tahminine devam".

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

## Devam Eden (aktif)

### BKM — BIRLESIK ONCELIK SIRASI

#### Faz 0 — Bugün (blocker'ları kaldır — 1-3 saat)
- [x] ~~**B-01** `scripts/send_mail.py` UnicodeEncodeError düzelt~~ — ✅ `[OK]` + `sys.stdout.reconfigure(encoding="utf-8")`. Gmail "Sent" doğrulaması: kullanıcı kontrol edecek (geçen hafta 20.04 11:19 mail muhtemelen gitti — hata print'teydi).
- [ ] **B-02** ~~Bu Pazartesi (27.04.2026)~~ **Sonraki Pazartesi (04.05.2026)** `briefings/2026-05-04/brief.html` + `brief.txt` üret — SQL bağlantısı erişilebilir bir oturumdan. (Bu hafta atlandı, SQL kapalı.)
- [x] ~~**B-03** `send_brief.bat` tarih güncelle~~ — ✅ DİNAMİK yapıldı, her Pazartesi'yi otomatik hesaplıyor (PowerShell `(Get-Date).AddDays(...)`). Bir daha güncelleme gerekmez.
- [ ] **B-NEW-00 ⚡ ÜST ÖNCELİK (restart sonrası ilk iş):** SQL bağlantı testi `mcp__sqlserver__sql_query SELECT @@SERVERNAME, GETDATE()`. OK ise B-NEW-01'e geç.

#### Faz 0.5 — Mayıs %50 kitap kampanyası tahmini (TAM SCOPE'LANDI, sırayla yürüt)

> **Tetikleyici:** "mayıs kampanyası" / "kitap %50 tahmin" / "kampanya tahminine devam"
> **Tam plan:** `docs/journal/bkm/2026-04-27.md` → RESUME bölümünden başla, hiçbir karar yeniden tartışılmasın.

- [ ] **B-NEW-01** Şema keşfi: `urnKtgr2.ktgrAd` LIKE 'KITAP%' kategori isimlerini bul. EncoreMerkez `Sales`/`SalesProducts`/`Products` describe. Products↔urn köprüsü (LinkedProductId veya Barcode↔barkod fallback).
- [ ] **B-NEW-02** Geçmiş veri sorguları (3 dönem): May25 (01-31), Apr25 (01-30), Apr26 (01-26 — gün-prorate). Filtreler: `IsValid=1`, `DocumentsTypeId IN (1,2,3,6,7,8)`, kitap kategorisi. CampaignId NULL/NOT NULL ayrı çıkar.
- [ ] **B-NEW-03** Tahmin modeli: `tahmin = may25 × MIN(MAX(apr26/apr25, 0.5), 2.0) × elastikiyet`. 3 senaryo (1.5x / 2.0x / 2.5x adet). Edge case'ler: Apr25=0, May25=0 ayrı handle.
- [ ] **B-NEW-04** Excel çıktı (xlsx skill): 7 sheet — Yönetim Özeti / Kategori / Top100 Ciro / Top100 Adet / Tüm Kitaplar / Senaryo Karşılaştırma / Doğrulama.
- [ ] **B-NEW-05** Doğrulama: top 10 mantıklı mı, kategori dağılımı sağlık check, outlier flag.
- [ ] **B-NEW-06** (Opsiyonel) Stok ihtiyacı türevi: tahmin × güvenlik − mevcut stok = sipariş öneri.

#### Faz 1 — Bu hafta (yüksek öncelik — ~5 gün)
- [ ] **B-04** `scripts/register-scheduled-task.ps1` çalıştır → Task Scheduler kaydı (her Pazartesi 09:00). **(YENİ — script hazır, sadece çalıştırılacak)**
- [ ] **B-05** SsmsExcelExporter build & test (`dotnet publish -c Release -r win-x64`) — Ctrl+Shift+E + Ctrl+Shift+W çalışmalı.
- [ ] **B-06** `CampaignId = NULL` 389,4M ₺ indirim kaynak araştırması (Session 2'den beri açık).
- [ ] **B-07** Ürün bazlı maliyet/marj analizi — 3Al2Öde'nin gerçek kârlılık etkisi.

#### Faz 2 — Bu ay (orta öncelik — ~10 gün)
- [ ] **B-08** EncoreMerkez Products tablosu → DerinSIS urn kategori mapping (urn.stkID köprüsü).
- [ ] **B-09** Sales → fat/irsHrk bağlantısı (LinkedDocumentNo / ClosureNo / TransferHistory).
- [ ] **B-10** `bkm.HareketKanal_vw` view tasarımı — Sınav vs Perakende ayrımı.
- [ ] **B-11** 2026 yıllık tahmin (Sınav / Retail ayrıştırılmış).
- [ ] **B-12** H15 e-ticaret sorgularının arşivlenmesi (`sorgular/YYYY-MM-DD-*.sql`).
- [ ] **B-13** Önceki oturum e-ticaret trend raporu SQL'leri arşive: haftalık ciro/adet, günlük nabız, Top 20 organik, kanal kırılımı, kategori, yayınevi Top 15, sipariş durum, Echo of Silence forensic, YoY 2025, J_ITEMSBARCODE keşif.
- [ ] **B-14** Grok sinyallerini iç satış verisiyle cross-check (önceki sorgular 30s timeout — başlık-bazlı küçük sorgulara böl).

#### Faz 3 — Çeyrek (düşük öncelik / temizlik — ~15 gün)
- [ ] **B-15** `BKM-Mobil-App-Baremli-Sorgular.sql` (eski J_CLCARD versiyonu) deprecated → kaldır.
- [ ] **B-16** Express sunucusunun (192.168.40.66\SQLEXPRESS) kullanım amacı dokümante et — `CLAUDE.md`'de hâlâ `[DOLDUR]`.
- [ ] **B-17** Express'te hangi DB'ler var, `ALLOWED_DATABASES` daraltılmalı mı karar.
- [ ] **B-18** İki sunucu arası cross-server sorgu (linked server / OPENROWSET) ihtiyacı çıkarsa değerlendir.
- [ ] **B-19** ADR-001 yaz: "Multi-project journal yapısı" (bugünkü kararın resmi kaydı).

### MCP Server (kod) — BIRLESIK ONCELIK SIRASI

#### Faz 0 — Bugün
- [ ] **M-01** Yok (kod tarafında acil iş yok).

#### Faz 1 — Bu hafta
- [ ] **C-NEW-01** ⚡ Kalıcı CWD fix: `src/index.ts` line 1 `import "dotenv/config"` → absolute-path dotenv load (`fileURLToPath(import.meta.url)` ile `__dirname`'den `.env` yükle). Sonra `npm run build` + restart + test (config'den cwd/env çıkarıp). Başarılıysa `fix-mcp-config.{ps1,bat,FIXED.json}` arşivlenebilir.

#### Faz 1 — Bu hafta
- [ ] **M-02** `src/tools/sp.ts` ve `src/tools/diagnostics.ts` üzerinde herhangi bir bug tespit edilmedi — gözden geçirme + test.

#### Faz 2 — Bu ay
- [ ] **M-03** `sql_query` timeout iyileştirmesi — büyük result set'lerde stream/pagination.
- [ ] **M-04** HTTP transport stabilitesi (Cowork/Workspace bağlantısı için cloudflared kalıcı tunnel).

#### Faz 3 — Çeyrek
- [ ] **M-05** `MAX_ROWS` env var dinamik — sorgu bazında override.
- [ ] **M-06** Yeni discovery tool: `sql_table_dependencies` (ilişkili tabloları otomatik çıkar).

### CrossProject — BIRLESIK ONCELIK SIRASI

#### Faz 0 — Bugün
- [ ] **C-01** `_kurulum-paketi/claude-config/` içeriğini `.claude/` olarak repo köküne kopyala (PowerShell veya elle).
- [ ] **C-02** `CLAUDE.md.PATCH` içeriğini mevcut CLAUDE.md sonuna ekle (`§ Session & Memory Disiplini`).
- [ ] **C-03** `git mv SESSION_LOG.md docs/journal/bkm/_archive-session-log.md`.
- [ ] **C-04** Hook test: `bash .claude/hooks/session-start.sh` — multi-project journal listesi gelmeli.
- [ ] **C-05** İlk commit: `chore(crossproject): atlasops session/memory yapısı adapte (multi-project)`.

#### Faz 1 — Bu hafta
- [ ] **C-06** Template (D:\Dev\claude-context-template) güncelle: atlasops'taki güncel session-handoff SKILL.md'yi merge et.
- [ ] **C-07** ADR-001 yaz: "Multi-project journal yapısı".

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
- [ ] **C-11** `pre-commit-antipattern.sh` hook ekle (şu an pasif) — ihtiyaç hissedilince.
- [ ] **C-13** Build artifact'ları `.gitignore`'a taşı: `sorgular/03-kampanya/RaporApp/bin/Release/`, `obj/Release/`, `*.dll`, `*.exe`, `*.pdb`. 3. commit'te yığıldı (220 dosyanın çoğu bunlar). `git rm --cached -r ...` + yeni commit. **(YENİ)**

### Dokümantasyon
- [ ] **C-12** README.md'ye multi-project yapı eklemesi (mevcut sadece MCP server kurulum).
