# TODO — sqlserver-mcp-server (Multi-Project)

Aktif yapılacaklar ve backlog. Bu dosya 400 satırı aşarsa tarihli konular ilgili `docs/journal/<proje>/`'a taşınır.

> **Format:**
> - Her ana başlık bir proje (`### BKM`, `### MCP Server (kod)`, `### CrossProject`).
> - Proje altında **BIRLESIK ONCELIK SIRASI** — Faz 0 (bugün), Faz 1 (bu hafta), Faz 2 (bu ay), Faz 3 (çeyrek).
> - Madde başında **kısa ID**: `B-NN` (BKM), `M-NN` (MCP), `C-NN` (CrossProject), `BL-NN` (Belinza), `Y-NN` (YonetIQ). Commit mesajlarında ve journal'da referans.

---

## Yapılanlar

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

#### Faz 0 — Yarın (Blazor dashboard devam — 12.06 oturumundan)
- [ ] **B-40** Mağaza 5 panel (Genel Bakış sığ): ödeme mix · iade analizi · kampanya yükü · UPT/sepet derinliği · dönüşüm (FSM kapı sayıcı). Veri hazır (G2/P3/P5/G8). Agent prompt 12.06 transcript'te hazır. **(YENİ)**
- [ ] **B-41** 7 JOKER kargo SQL entegre (`D:\Belgelerim\sql\_JOKER\`): kargo gün detay · kargoya verilme süreleri v2 · ay bazlı ortalama · çıkış-teslim süreleri · kargo+kapıda ödeme bedelleri · kapıda ödeme rapor · il teslimat perf. **Kullanıcının gerçek üretim sorguları — agent L1-L3'ten daha doğru.** L1-L3 + dashboard E-ticaret kargo panellerini bunlarla güçlendir. **(YENİ)**
- [ ] **B-42** Eski Python pano (`scripts/gm_dashboard.py`) emekli kararı — Blazor canlı (`dashboard/`, port 5112). Paralel mi dursun? briefings/* eski çıktılar yanlış e-tic rakamıyla → regenerate/temizle. **(YENİ)**
- [ ] **B-43** Kafe POS DB erişimi araştır — EncoreMerkez'de kafe yok, xlsx kanonik. Kafe ayrı POS sistemi nerede? **(YENİ)**

#### Faz 0 — Bugün (blocker'ları kaldır — 1-3 saat)
- [x] ~~**B-01** `scripts/send_mail.py` UnicodeEncodeError düzelt~~ — ✅ `[OK]` + `sys.stdout.reconfigure(encoding="utf-8")`. Gmail "Sent" doğrulaması: kullanıcı kontrol edecek (geçen hafta 20.04 11:19 mail muhtemelen gitti — hata print'teydi).
- [x] ~~**B-02** Bu Pazartesi (27.04.2026) `briefings/2026-04-27/brief.html` + `brief.txt` üret~~ — ✅ 28 Nis Salı sabahı **retroaktif** üretildi (SQL bağlantısı dünden geri geldi, MCP CWD fix uygulandı). Mail gönderildi (fikrieren@gmail.com + fikri.eren@bkmkitap.com), kullanıcı "ok geldi" onayladı. Brief: H17 Net 13,27M / WoW −%1,5 / 23 Nis Çocuk Bayramı patlama (3,4M tek gün) → 1 May Emek Bayramı sinyali.
- [ ] **B-21** Sonraki Pazartesi brief Task Scheduler ile otomatik tetikleme. ~~JOKER e-ticaret~~ ✅ 11.06 (B-29, commit 739ad0a). Kalan: kitapsepeti + Heykel + kafeler dahil edilmeli + scheduler kaydı (B-04).
- [~] **B-22** FSM kapı sayıcı entegrasyonu — **KISMEN ÇÖZÜLDÜ 08.06.2026.** Veri geldi (`sayiyo/sayiyo_*.xlsx`, geniş format, FSM 08.04→güncel günlük giriş). Tidy: `sayiyo/fsm_gunluk_trafik.csv`. **G8 dönüşüm çalışıyor** (`scripts/donusum_orani.py`: CSV giriş + EncoreMerkez fiş → günlük dönüşüm % + ₺/ziyaret). Doğrulama: 02-08.06 %51,0 (dashboard 10.738 ile birebir). FSM ~%50 sağlıklı. **KALAN:** (1) Özlüce + İst.Yolu sayıcı verisi yok, (2) trafiği SQL tabloya yükle (`bkm.MagazaTrafik`) → native join + brief KPI kolonu, (3) saat bazlı kırılım. **(GÜNCEL)**
- [x] ~~**B-03** `send_brief.bat` tarih güncelle~~ — ✅ DİNAMİK yapıldı, her Pazartesi'yi otomatik hesaplıyor (PowerShell `(Get-Date).AddDays(...)`). Bir daha güncelleme gerekmez.
- [x] ~~**B-35** EncoreMerkez stkID köprüsü~~ — ✅ 09.06 BULUNDU: `Products.Code`(int)=`urn.stkID` (%99,98). Join: SalesProducts.ProductsId→Products.Code=stkID→urn. Oyuncak 700K→10,96M doğrulandı. Kural yazıldı.
- [x] ~~**B-36** Dashboard devir/ölü sermaye hesap detayı~~ — ✅ 09.06 modallara Satılan/ay + Ort Stok adet + 'Hesap' (12×S÷O) kolonları + formül başlığı. Devir 0,15x artık şeffaf.
- [x] ~~**B-37** stkID düzeltmesi rapor dosyalarına~~ — ✅ 09.06 G4-kategori-magaza.sql + A6-marka-yayinevi.sql + generate_brief.py SQL_CATEGORY/TOTAL → Products.Code=urn.stkID köprüsü. G4 doğrulandı (Oyuncak 07.06 3,5k→491k, 140× düzelme).
- [ ] **B-NEW-00 ⚡ (restart sonrası):** SQL bağlantı testi `mcp__sqlserver__sql_query SELECT @@SERVERNAME, GETDATE()`. OK ise B-NEW-01'e geç.

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
- [ ] **C-13** Build artifact'ları `.gitignore`'a taşı: `sorgular/03-kampanya/RaporApp/bin/Release/`, `obj/Release/`, `*.dll`, `*.exe`, `*.pdb`. 3. commit'te yığıldı (220 dosyanın çoğu bunlar). `git rm --cached -r ...` + yeni commit.
- [x] ~~**C-14** Paralel oturum koruma — ADR-002 implementasyonu~~ — ✅ Lock mekanizması + `session-start.sh` uyarı + `session-handoff` pre-commit git check + stale cleanup (4h TTL) + `session-protocol.md` lock disiplini. Detay: `docs/ADR/002-paralel-oturum-koruma.md`.
- [ ] **C-15** (opsiyonel) TODO.md split per-project: `TODO/bkm.md` + `TODO/_crossproject.md` + `TODO/belinza.md` + `TODO/yonetiq.md`. Race condition azaltır. ADR-002'de tartışıldı.
- [x] ~~**C-16** Plan-first tier sistemi~~ — ✅ `plans/` klasörü + `feature-template.md` + `.claude/rules/plan-first.md` + ADR-003. Tier 1 (yok) / Tier 2 (TODO) / Tier 3 (tam plan). Detay: `docs/ADR/003-plan-first-tier-system.md`. **(YENİ)**
- [ ] **C-17** Pre-commit hook: Tier 3 sinyali varsa plan referansı yoksa uyarı (fail-soft). `.claude/rules/plan-first.md` § İstisnalar. **(YENİ)**
- [ ] **C-18** Handoff skill plan tamamlanma kontrolü — done criteria check edildi mi, plan archive'a taşınıyor mu. **(YENİ)**

### Dokümantasyon
- [ ] **C-12** README.md'ye multi-project yapı eklemesi (mevcut sadece MCP server kurulum).
