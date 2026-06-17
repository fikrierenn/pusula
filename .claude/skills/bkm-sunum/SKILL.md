# bkm-sunum — CFO PDF/PPTX Yönetim Sunumu

> BKM analitik verisini (gm-rapor / canlı MCP) **CFO sunumuna** (PowerPoint + PDF) çevirir. awesome-claude-skills "Document" ailesi ilhamı (17.06). Ağır işi `anthropic-skills:pptx` / `:pdf` yapar; bu skill **BKM verisi + format + renk + tetik** sağlar (ince sarmalayıcı, footprint-ladder basamak-2). HTML mail brief'in (gm-rapor) sunum/arşiv kardeşi.

## Ne zaman tetiklenir
- "sunum yap", "CFO sunum", "yönetim sunumu", "PowerPoint/PPTX rapor", "PDF brief", "aylık sunum", "/bkm-sunum"
- Aylık/çeyrek yönetim toplantısı materyali; haftalık brief'in sunulabilir hali

## Girdi → veri kaynağı (öncelik sırası)
1. **gm-rapor** çıktısı (haftalık/aylık brief verisi — KPI'lar zaten hesaplı) varsa onu kullan.
2. Yoksa **canlı MCP** (`mcp__sqlserver`) — sema'dan doğru sorgu (semantic-layer kuralı): net ciro, kategori, kanal (perakende/e-tic), kargo, hedef-vs-gerçek, ölü stok, marj.
3. Dönem kullanıcıdan (varsayılan: geçen tam ay). KDV-hariç (plan-16), iade-netlenmiş (ehTip 3,5,101 / DocType=3).

## Akış
1. **KPI topla** — dönem net ciro + WoW/MoM + YoY, kanal kırılımı, top kategori, hedef-vs-gerçek (Hedef Tahmin/tahmin DB), ölü sermaye, kargo/COD. Sema-driven, rakam mutabakatı (dashboard ile tutar).
2. **Slide planı** (PPTX — `anthropic-skills:pptx`):
   - Kapak: "BKM Kitap — <Dönem> Yönetim Özeti" + tarih
   - KPI bandı: Net Ciro · Δ% (WoW/MoM/YoY) · Fiş/ATV · Online pay
   - Kanal: perakende vs e-ticaret (pasta/bar)
   - Kategori: top-N ciro + Δ (tablo/bar)
   - Hedef-vs-gerçek: tahmin bandı + sapma
   - Risk/sinyal: ölü sermaye, stockout>%5, COD iade, devir<1.5×
   - Kapanış: 3 madde aksiyon önerisi
3. **PDF gerekiyorsa** `anthropic-skills:pdf` (aynı içerik, yazdırılabilir).
4. Çıktı: `briefings/<YYYY-MM-DD>/sunum.pptx` (+ `.pdf`).

## Format / kurallar
- **Türkçe**, UTF-8 (turkish-ui). Sayı `tr-TR` (#.##0), ₺ son ek.
- **Renk = anlam** (renk-standardi): artış yeşil, düşüş/risk kırmızı, marka BKM kırmızısı (#E30622) kapak/vurgu. Hardcode hex sadece sunum dosyasında (DaisyUI yok burada) — anlam-renk eşlemesi korunur.
- **Sinyal>rapor:** her slide "ne anlama geliyor" 1 satır (CFO kararı). Süs grafik yok.
- **Rakam mutabakatı:** sunum sayıları dashboard/gm-rapor ile AYNI olmalı (sema-driven tek kaynak). Çelişki → durdur, doğrula.

## İlkeler
- **İnce sarmalayıcı** — slide üretim mekaniği anthropic-skills:pptx/pdf'e ait; bu skill veri+anlatı+format.
- **Veri doğruluğu > görsellik** — yanlış rakamlı şık sunum zararlı (CFO kararı). Önce mutabakat.
- **Footprint:** yeni kod/servis YOK — mevcut sorgu/gm-rapor + hazır document skill.

## İlişkili
- `anthropic-skills:pptx`, `anthropic-skills:pdf` — slide/PDF motoru
- `.claude/skills/gm-rapor/SKILL.md` — KPI/veri kaynağı (HTML brief kardeşi)
- `.claude/rules/renk-standardi.md` · `turkish-ui.md` — format
- `.claude/rules/semantic-layer.md` · `sql-server-conventions.md` — doğru sorgu/rakam
- `sema/*.yaml` — metrik/köprü tek kaynak
