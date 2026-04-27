# docs/ — BKM Kitap / DerinSIS Bilgi Tabanı İndeksi

> Üç farklı Claude oturumunun aynı klasörde biriken çıktılarını harmanlayan merkezi indeks. `CLAUDE.md` sadece özet + yönlendirme. Detaylar burada.

**Son güncelleme:** 15 Nisan 2026

---

## Üç Session Temas Haritası

| Session | Tema | Ana çıktılar |
|---|---|---|
| **S1–S2** (13 Nis) | MCP Server kurulum + EncoreMerkez POS kampanya analizi | `skills/*`, `encore-merkez-analiz-raporu.html`, `3al2ode-*.html`, `sepet-*.html`, `sorgular/01-07/*.sql` |
| **S3 envanter** (14–15 Nis) | İst.Yolu −54M TL envanter soruşturması | `sorgular/envanter_*.md`, `sorgular/SESSION.md`, `docs/06-envanter-bulgular.md` |
| **S3 e-ticaret + köprü** (14–15 Nis) | JOKER H15 trend + Mobil App + Sınav/Retail köprü | `BKM-Eticaret-*`, `BKM-Mobil-App-*`, `Grok-*`, `sorgular/sinav_kanal_koprusu.md` |

---

## Konu Bazlı Referans Dosyaları (bu klasör)

| Dosya | Ne içerir | Ne zaman oku |
|---|---|---|
| [`01-baglanti.md`](01-baglanti.md) | İki SQL sunucusu (sqlserver + sqlserver-express), izinli DB'ler, DMY, collation | Yeni oturum ilk adım |
| [`02-tablolar-magaza.md`](02-tablolar-magaza.md) | Mekan mapping (FSM/Özlüce/İst.Yolu), ana tablolar (urn, irsHrk, fat, bkm.*), stkAd/stkID uyarısı, Stores↔mekanID | ERP sorgusu yazarken |
| [`03-ciro-filtreleri.md`](03-ciro-filtreleri.md) | Standart ciro filtreleri, template sorgular, anomaliler, MaliyetRaporu-Ceren job | Ciro/satış raporu |
| [`04-kanal-koprusu.md`](04-kanal-koprusu.md) | Sınav ↔ Perakende ayrımı için `SinavSiparisFisEncore ↔ Sales` köprüsü (%99,79) | Kanal ayrıştırma, 2026 tahmin |
| [`05-eticaret-joker.md`](05-eticaret-joker.md) | `ODAKJOKER.JOKER` linked server — e-ticaret standartları, H15 bulguları | E-ticaret / online analiz |
| [`06-envanter-bulgular.md`](06-envanter-bulgular.md) | İst.Yolu −54M TL envanter kök nedeni, 10 anomali, aksiyonlar | Envanter/maliyet/düzeltme |
| [`07-davranis.md`](07-davranis.md) | Fikri için konuşma tonu, format, DMY kural hatırlatması | Her oturum arka plan |
| [`08-pos-encore.md`](08-pos-encore.md) | EncoreMerkez POS — kampanya, 3al2öde, sepet, Stores mapping, compat 110 uyarısı | POS/kampanya sorgusu |
| [`09-raporlar-ve-skills.md`](09-raporlar-ve-skills.md) | Tüm rapor çıktıları + skill dosyaları haritası | Rapor/skill ararken |

---

## İlişkili Klasörler

### `sorgular/` — SQL + derin analizler
- [`SESSION.md`](../sorgular/SESSION.md) — envanter soruşturması master index (11 bölümlü)
- [`INDEX.md`](../sorgular/INDEX.md) — EncoreMerkez tematik sorgu kütüphanesi (22 sorgu, 7 klasör)
- [`00-README.md`](../sorgular/00-README.md) — e-ticaret sorgu standartları + arşiv disiplini
- [`SEMANTIK_KATMAN.md`](../sorgular/SEMANTIK_KATMAN.md) — DerinSIS semantik katman notları
- [`sinav_kanal_koprusu.md`](../sorgular/sinav_kanal_koprusu.md) — kanal köprüsü derin keşfi

### `skills/` — Plugin skill dosyaları
- [`encore-merkez/SKILL.md`](../skills/encore-merkez/SKILL.md) — EncoreMerkez tam şema
- [`bkm-kitap-data/SKILL.md`](../skills/bkm-kitap-data/SKILL.md) — DerinSIS sorgu kalıpları
- [`bkm-kitap-operasyon/SKILL.md`](../skills/bkm-kitap-operasyon/SKILL.md) — BKM operasyonel bağlam

### Root dosyaları
- [`../CLAUDE.md`](../CLAUDE.md) — kısa oturum bağlamı (buraya yönlendirir)
- [`../SESSION_LOG.md`](../SESSION_LOG.md) — kronolojik session günlüğü
- [`../README.md`](../README.md) — MCP server kurulum rehberi

### Harici
- [`D:\Belgelerim\sql\sql_server_puf_noktalari.md`](file:///D:/Belgelerim/sql/sql_server_puf_noktalari.md) — 17 maddelik SQL Server püf noktaları

---

## Kullanım Disiplini

1. **Yeni oturumda:** `CLAUDE.md` → bu `00-INDEX.md` → konuya göre ilgili dosya(lar).
2. **Yeni bilgi öğrenildiğinde:** İlgili konu dosyasına ekle, `CLAUDE.md` özetini güncelle.
3. **Yeni konu açılırsa:** `docs/NN-<konu>.md` olarak ekle, bu INDEX'e satır ekle.
4. **Rapor üretilirse:** Root'ta bırak, `09-raporlar-ve-skills.md`'e satır ekle.
5. **Session sonu:** `SESSION_LOG.md`'ye kronolojik giriş.
