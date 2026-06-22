# CLAUDE.md — Pusula (BKM Kitap Analitik Çalışma Alanı)

> Kısa iskelet. Detaylar [`docs/00-INDEX.md`](docs/00-INDEX.md) altındadır. **İlk adım:** `docs/00-INDEX.md` → ilgili konu dosyası.

**Son güncelleme:** 11 Haziran 2026 · **Repo:** `D:\Dev\pusula` (eski adı sqlserver-mcp-server)
**Kullanıcı:** Fikri (BKM Kitap GM)

## Aktif Temalar (beş session harmanlanmış)

1. **EncoreMerkez POS** (S1–S2, S5): kampanya, 3al2öde, sepet, IsValid/LineCount keşfi, veri doğrulama → [`docs/08-pos-encore.md`](docs/08-pos-encore.md)
2. **Envanter soruşturması** (S3): İst.Yolu −54M TL → [`docs/06-envanter-bulgular.md`](docs/06-envanter-bulgular.md)
3. **E-ticaret + Kanal köprüsü** (S3–S4): JOKER H15, Mobil App, Grok, Sınav/Retail → [`docs/05-eticaret-joker.md`](docs/05-eticaret-joker.md) · [`docs/04-kanal-koprusu.md`](docs/04-kanal-koprusu.md)

Kronolojik günlük: [`SESSION_LOG.md`](SESSION_LOG.md)

---

## Proje Kimliği

- **Şirket:** BKM Kitap (kitap + kırtasiye + sınav okulları)
- **Mağazalar:** FSM (mekanID 1, Encore 2/M01) · Özlüce (4477, 3/M02) · İst.Yolu (4478, 1/M03)
- **Ağu 2024:** Sınav Okulları operasyonu FSM → İst.Yolu
- **ERP:** DerinSIS · **POS:** EncoreMerkez · **WMS:** depo şeması · **E-ticaret:** JOKER (linked server)

## Bağlantı (özet)

> **MCP server kodu ayrıldı (10.06):** `src/`+`dist/` dondurulmuş — geliştirme artık `D:\Dev\sqlserver-mcp`'de (kendi CLAUDE.md'si var). Config geçişine kadar buradaki `dist/` canlı çalışır (TODO M-01). Bu repo = BKM analitik çalışma alanı.

İki paralel MCP — detay [`docs/01-baglanti.md`](docs/01-baglanti.md):
- `mcp__sqlserver__*` → 192.168.40.201 (DerinSISBkm, BKM, EncoreMerkez, +linked ODAKJOKER)
- `mcp__sqlserver-express__*` → 192.168.40.66\SQLEXPRESS

## Sabit Kurallar (hatırlatma)

- Tarih (yerel): **DMY** (`dd.MM.yyyy`, `CONVERT(..., 104)`). `yyyy-MM-dd` **KULLANMA**.
- Tarih (ODAKJOKER linked): `YYYYMMDD` ISO
- `urn.stkAd` / `urn.stkID` (urnAd/urnID **hata**)
- `urnKtgr2.ktgrAd` (ktgr2Ad **hata**)
- Cross-db string join → `COLLATE Turkish_CI_AS` (BKM.snv ↔ EncoreMerkez/DerinSIS)
- EncoreMerkez compat 110: `STRING_AGG`, `TRIM`, `IIF`, `TRY_CONVERT` **yok**
- **EncoreMerkez SalesProducts:** her zaman `WHERE IsValid = 1` filtresi kullan
- **LineCount KULLANMA** → `CROSS APPLY (SELECT COUNT(*) FROM SalesProducts WHERE SalesId=s.Id AND IsValid=1)`
- **İndirim toplamı:** sadece `DiscountTotalDirect` kullan (`DiscountTotalCampaign` alt kümesidir, toplarsan çift sayarsın)
- **Belge filtresi:** `DocumentsTypeId IN (1, 2, 3, 6, 7, 8)` — İade (3) negatif sign ile düşülür
  - 1=Fiş, 2=Fatura, 3=İade(-), 6=Personel Fiş, 7=Personel Fatura, 8=Sınav Okulları
  - SUM'larda: `CASE WHEN s.DocumentsTypeId=3 THEN -s.GrossTotal ELSE s.GrossTotal END`
  - AVG'larda: `CASE WHEN s.DocumentsTypeId <> 3 THEN ... END` (İade hariç)
- Davranış tonu: [`docs/07-davranis.md`](docs/07-davranis.md)

## İçerik Haritası

| Konu | Dosya |
|---|---|
| **İndeks (her şey burada)** | [`docs/00-INDEX.md`](docs/00-INDEX.md) |
| Bağlantı, izinler, collation | [`docs/01-baglanti.md`](docs/01-baglanti.md) |
| Mekan + ana tablolar + Stores mapping | [`docs/02-tablolar-magaza.md`](docs/02-tablolar-magaza.md) |
| Ciro filtreleri + anomaliler + job | [`docs/03-ciro-filtreleri.md`](docs/03-ciro-filtreleri.md) |
| Sınav/Retail kanal köprüsü | [`docs/04-kanal-koprusu.md`](docs/04-kanal-koprusu.md) |
| E-ticaret (ODAKJOKER) + H15 | [`docs/05-eticaret-joker.md`](docs/05-eticaret-joker.md) |
| Envanter −54M TL | [`docs/06-envanter-bulgular.md`](docs/06-envanter-bulgular.md) |
| Davranış | [`docs/07-davranis.md`](docs/07-davranis.md) |
| EncoreMerkez POS / kampanya | [`docs/08-pos-encore.md`](docs/08-pos-encore.md) |
| Raporlar + skills haritası | [`docs/09-raporlar-ve-skills.md`](docs/09-raporlar-ve-skills.md) |
| Merkez depo / WMS | [`docs/12-depo-wms.md`](docs/12-depo-wms.md) |
| **Semantik katman (canonical)** | [`sema/README.md`](sema/README.md) — bridges/codes/entities/metrics/queries.yaml. Sorgu yazmadan ÖNCE bak; yeni keşif → `sema-ogren` |

## Bekleyen İşler

> Detaylı liste artık [`TODO.md`](TODO.md) içinde — multi-project Faz yapısı (BKM + MCP + CrossProject + Belinza/YonetIQ).
>
> Aşağıdaki kısa hatırlatma listesi 27.04.2026'da TODO.md'ye taşındı, burada tarihsel referans olarak duruyor.

- Sales → fat/irsHrk bağlantısı (LinkedDocumentNo / ClosureNo / TransferHistory)
- Products ↔ urn mapping (ProductsId ↔ stkID) · Stores↔mekanID **çözüldü** (08'de)
- `bkm.HareketKanal_vw` view tasarımı
- 2026 yıllık tahmin (Sınav / Retail ayrıştırılmış)
- H15 e-ticaret sorgularının arşivlenmesi (`sorgular/YYYY-MM-DD-*.sql`)
- `CampaignId = NULL` 389,4M ₺ indirim kaynak araştırması
- SsmsExcelExporter build & test (Ctrl+Shift+E / Ctrl+Shift+W)
- Ürün bazlı maliyet/marj analizi — 3Al2Öde gerçek kârlılık etkisi
- Products → DerinSIS urn kategori mapping

---

## § Session & Memory Disiplini

> Atlasops'tan adapte edildi (27.04.2026). Detaylar `.claude/rules/`'da.

### Üç Katman Ayrımı

| Bilgi | Nerede |
|---|---|
| Proje kimliği (değişmez) | `CLAUDE.md` (bu dosya) |
| Davranış kuralı (kalıcı) | `.claude/rules/<konu>.md` |
| Aktif plan / backlog | `TODO.md` |
| Mimari karar | `docs/ADR/NNN-<slug>.md` |
| Oturum notu / günlük | `docs/journal/<proje>/YYYY-MM-DD.md` |

**Aynı bilgi iki yerde durmaz.** Multi-project repo: `<proje>` = `bkm` / `belinza` / `yonetiq` / `_crossproject`.

### Oturum Başı Ritüeli (KOŞULSUZ)

İlk yanıttan ÖNCE:

1. `bash .claude/hooks/session-start.sh` — fresh çıktı al (context'tekine güvenme).
2. Hangi projedeysen `ls -t docs/journal/<proje>/*.md | head -2` → son 2 journal oku.
3. `TODO.md` → ilgili proje başlığı altındaki Faz 0 + Faz 1 ilk 3 madde.
4. `git status --porcelain | wc -l` — 15 üstüyse yeni iş yasak.

Bu 4 adım sessizce yapılır. Cevap bu okumalara dayanır, hafızaya değil. Detay: `.claude/rules/session-protocol.md`.

### Oturum Sonu Ritüeli

Kullanıcı "iyi geceler" / "/handoff" / "kaydet ve kapat" derse → `session-handoff` skill devreye girer:
- `docs/journal/<proje>/YYYY-MM-DD.md`'ye append.
- `TODO.md` senkronu (tamamlananları işaretle, yeni keşfedilen işleri ekle).
- Journal + TODO **otomatik commit** (sadece bu iki dosya).

### Kritik Eşikler

| Sinyal | Aksiyon |
|---|---|
| `CLAUDE.md` > 200 satır | `.claude/rules/`'a split |
| Uncommitted > 15 | `commit-splitter` subagent |
| Aynı hatayı 2. kez yapıyorum | Rule/skill'e yaz |
| 3+ paralel feature | Biri bitene kadar yeni başlatma |
| `/compact` sonrası kural unutuldu | `paths:` olmadan rule yaz |
| Proje karışmış commit | `commit-splitter` ile böl |

### Multi-Project Commit Disiplini

- Scope = proje adı: `feat(bkm): haftalık brief otomasyonu`, `chore(mcp): timeout fix`, `docs(crossproject): rule güncelleme`.
- Bir commit yalnızca tek proje değiştirir.
- Karışmış değişiklik → commit-splitter bucket'lar.

### İlişkili Dosyalar

> **Rule katmanları (plan-12 WS-2):** `core` (her oturum birincil — session-protocol/memory, commit, sql-server-conventions, semantic-layer, before-major-change, response-style, error-handling, security-principles) vs `on-demand` (konu-bazlı — renk-standardi, turkish-ui, file-size, agent-usage, coding, test, todo-verification; ilgili iş/skill tetiklenince birincil). Hepsi yüklü kalır (compact-survival); etiket = öncelik. Yeni yetenek → `.claude/rules/footprint-ladder.md` (en dar basamak).

- `.claude/rules/session-memory.md` — Üç katman ayrımı, eşikler.
- `.claude/rules/session-protocol.md` — Oturum başı/orta/sonu ritüel.
- `.claude/rules/commit-discipline.md` — 15 dosya eşiği, scope kullanımı.
- `.claude/rules/sql-server-conventions.md` — DMY, EncoreMerkez compat, IsValid, J_ORDER_CLIENTS.
- `.claude/rules/semantic-layer.md` — sorgu öncesi `sema/`'ya bak; keşif → sema-ogren (ECC continuous-learning).
- `.claude/rules/before-major-change.md` § Fact-Force Gate — bilinmeyen tabloya ilk sorgu / scripte ilk edit öncesi keşif zorunlu.
- `.claude/skills/session-handoff/SKILL.md` — Oturum sonu skill ("İşe YARAMAYANLAR" bölümü dahil).
- `.claude/skills/sema-ogren/SKILL.md` — şema keşfi → sema/*.yaml.
- `.claude/agents/commit-splitter.md` — Multi-project bucket'lama.
- `.claude/agents/planner.md` — Tier 3 plan yazıcı (opus). `python-reviewer.md` + `silent-failure-hunter.md` — script kalite / sessiz hata denetimi.
- `.claude/commands/learn.md` — /learn: çözülen sorun → kalıcı ders.
- `docs/CONTEXT_MANAGEMENT.md` — Bağlam yönetimi anayasası (8 ilke).
- `docs/journal/README.md` — Multi-project journal yapısı.
- `TODO.md` — Faz yapılı, proje başlıklı backlog.
