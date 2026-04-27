# 09 — Raporlar & Skills Haritası

> Üst: [`00-INDEX.md`](00-INDEX.md) · [`../CLAUDE.md`](../CLAUDE.md)

Tüm oluşturulan rapor çıktıları ve skill dosyaları — üç session'ın harmanlanmış listesi.

## Rapor Çıktıları (root `D:\Dev\sqlserver-mcp-server\`)

### E-ticaret / Trend (JOKER)
- `BKM-Eticaret-Trend-Raporu.md` / `.html` — H15 tam rapor (13 bölüm + Grok §10b)
- `BKM-Eticaret-Yonetim-Sunumu.html` — Reveal.js yönetim sunumu
- `BKM-Mobil-App-Baremli-Rapor.md` / `.html` — App sıklık + sepet + 15 haftalık seyir
- `BKM-Kitap-Trend-Endeksi-Sistem-Tasarimi.md` — trend endeksi sistem tasarımı
- `BKM-Pilot-Trend-Raporu.md` — pilot rapor
- `Grok-Sosyal-Dinleme-Raporu.md` — X/Twitter sosyal dinleme (atıflı)

### EncoreMerkez POS
- `encore-merkez-analiz-raporu.html` — 10 bölüm kapsamlı DB analiz
- `3al2ode-kampanya-raporu.html` — kampanya performans (eski)
- `sorgular/03-kampanya/3al2ode-kampanya-raporu-nisan2026.html` — **Nisan 2026 güncel rapor** (IsValid filtreli, doğrulanmış)
- `sepet-buyuklugu-etkisi-raporu.html` — sepet büyüklüğü

### Araçlar
- `sorgular/03-kampanya/SsmsExcelExporter/` — SSMS → Excel system tray aracı (C#, ClosedXML, dual hotkey)

### Proje
- `README.md` — MCP server kurulum (8 tool, SQL Server connector)
- `SESSION_LOG.md` — kronolojik session logu (Session 1–5)

## Skill Dosyaları (`skills/`)

| Skill | İçerik |
|---|---|
| [`skills/encore-merkez/SKILL.md`](../skills/encore-merkez/SKILL.md) | EncoreMerkez tam şema (8 şema, 196 obje, 145 FK), Stores mapping |
| [`skills/bkm-kitap-data/SKILL.md`](../skills/bkm-kitap-data/SKILL.md) | DerinSIS tablo/SP/view/sorgu kalıpları |
| [`skills/bkm-kitap-operasyon/SKILL.md`](../skills/bkm-kitap-operasyon/SKILL.md) | BKM operasyonel bağlam (Emek, Tsoft, İYS entegrasyonları) |

Tetikleme: "Encore/POS/kasa/kampanya", "BKM sorgu/DerinSIS", "BKM Kitap/Emek/Tsoft" ifadelerinde otomatik devreye girer.

## Sorgu Arşivi Disiplini

- Format: `sorgular/YYYY-MM-DD-<analiz>.sql`
- Standartlar: [`../sorgular/00-README.md`](../sorgular/00-README.md)
- Semantik katman: [`../sorgular/SEMANTIK_KATMAN.md`](../sorgular/SEMANTIK_KATMAN.md)
- EncoreMerkez tematik: [`../sorgular/INDEX.md`](../sorgular/INDEX.md)
- Envanter master: [`../sorgular/SESSION.md`](../sorgular/SESSION.md)
