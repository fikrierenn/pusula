# Emitter Ayrımı — Tek Hesap Çekirdeği, Çoklu Çıktı

> **Rule katmanı:** on-demand (konu-bazlı) — rapor/analiz ÜRETİMİ tetiklenince birincil. Core değil. plan-12 WS-2 / footprint-ladder.
>
> _Dış ilham: `/last30days` skill'inin engine/emitter ayrımı (tek Python motoru → md/json/html/sqlite emitter). Ama sosyal-kaynak değil — BKM analiz mimarisine uyarlandı._ `paths:` yok — compact sonrası survive.

## Temel İlke

**Bir analiz = (a) HESAP ÇEKİRDEĞİ + (b) EMITTER'lar.** Çekirdek bir kez yazılır (tek doğruluk kaynağı); her çıktı formatı onu ÇAĞIRIR, kopyalamaz.

| Katman | Ne yapar | Ne YAPMAZ |
|---|---|---|
| **Hesap Çekirdeği** | Ham sonucu üretir — tek sqlcli/sema-driven sorgu (köprü/kod/metrik `sema/`'dan). Grain + filtre + iş mantığı burada. | Sunum/format YAPMAZ (Excel stili, renk, HTML) |
| **Emitter** | Çekirdeğin ham sonucunu bir formata döker | Hesap/iş-mantığı YAPMAZ (SUM/CASE/join emitter'da yasak) |

**Emitter tipleri (BKM):**
- **excel** — pyodbc + openpyxl (scripts/*.py). Türkçe varchar → pyodbc (CP1254).
- **dashboard** — Dapper (`*Queries.cs`) → Razor + charts.js (DaisyUI token).
- **markdown** — `yonetici-rapor` / brief (CFO belgesi).
- **json** — API/köprü (Python↔C# ortak SQL tablosu deseni).

## Kural

1. **Çekirdek tek yerde.** Aynı metriği iki çıktı için iki kez SQL yazma → kaynağı paylaş (arşiv `sorgular/*.sql`, `sema/` metrik tanımı, veya ortak Query metodu).
2. **Emitter hesapsız.** Emitter'da `SUM`/`CASE`/join görürsen → o mantık çekirdeğe ait, taşı. Emitter sadece biçim (kolon adı, TL format, renk, grafik).
3. **Çekirdek değişince tüm emitter otomatik uyar** — tek kaynak sayesinde. Kopyalanmış SQL bunu bozar (biri güncellenir, diğeri bayatlar → sessiz sapma).
4. **Yeni çıktı = yeni emitter, yeni çekirdek DEĞİL.** "Excel de lazım" → mevcut çekirdeği yeni emitter'la dök; sorguyu yeniden yazma.
5. **Sema uyum.** Çekirdek köprü/kod/metrik'i `sema/`'dan okur (hardcode değil) — `semantic-layer.md`.

## BKM Örnek (canonical)

**etic-iptal** (`sorgular/2026-07-30-etic-kart-iptal-detay.sql`) = **çekirdek** (5 blok, grain/türeme/prorate/iade mantığı orada). Aynı çekirdekten:
- **excel** emitter → pyodbc script (CFO dökümü)
- **dashboard** emitter → `EticQueries.Iptal.cs` + `EticIptal.razor` (KPI+grafik)
- **markdown** emitter → `yonetici-rapor` brief

Üçü de AYNI iş mantığını (STATUS 2004/2005/2010, brüt+net, türeme filtresi) çekirdekten alır — üç kez yazılmaz.

## BİÇİM DE TEK YERDE — anahtar çatallanması (10.09.2026 vakası)

Emitter'lar hesabı paylaşınca iş bitmiyor: **kolon anahtarı → değer eşlemesi** de tek yerde
olmalı. Aksi hâlde çatallanma **sessiz boş kolon** üretir — derleyici görmez, test yoksa
kimse görmez, hücre sadece boş kalır.

**Ölçülmüş vaka:** Satış Analizi'nde ekran tablosu Razor içinde YEREL bir eşleme taşıyordu,
Excel endpoint'i ortak `SatisAnaliziHucre`'yi kullanıyordu. Çift yönlü kayıp:
- ekranda `sonsatis` hiç yoktu; yeni `talepdeseni`/`satanay` `_ => ""` dalına düşüp **boş**tu
  → kullanıcının istediği "Son Satış" kolonu ekranda **çalışmıyordu**,
- Excel'de anahtar adları farklı yazıldığı için (`sezon_kapsama` vs `kapsama`,
  `ay1..3` vs `sezon_ay1..3`) o kolonlar **boş** çıkıyordu.

**Kural:** ham değer ve ekran metni AYNI sınıfta (`Deger()` / `Metin()`); kanonik anahtar
kümesi kolon tanımıdır. Yeni kolon = tek dosya değişikliği.

**Koşulabilir denetim** (pre-commit hook'a bağlı): `python tools/panel_kolon_denetimi.py`
— kolon tanımı ↔ eşleme anahtar farkını yazar. "Tanımlı ama eşlemede yok" = KIRIK (o kolon
boş görünür); "eşlemede var ama tanımı yok" = UYARI (hiçbir çıktıda seçilemez, ölü dal).
Kırılabilirliği kanıtlandı: bir anahtar bozuldu → hook `exit 2` ile commit'i bloklandı.

## Anti-pattern

- ❌ Her script kendi SQL'ini gömer + kendi Excel'ini basar → aynı metrik 3 dosyada, biri düzeltilir öteki bayatlar (sql-denetci/veri-dogrula yükü, sessiz sapma).
- ❌ Emitter'da iş mantığı (Razor `@code`'da SUM, Excel script'inde CASE) → hesap iki yere dağılır.
- ❌ "Dashboard için sorguyu baştan yazdım" → çekirdek zaten `sorgular/`'da; port et, kopyalama.
- ❌ Dashboard gömülü SQL ile arşiv SQL çatallanır → **dashboard `*.cs` = kodun evi** (semantic-layer istisnası), ama iş mantığı ikisinde AYNI kalmalı; sapıyorsa çekirdek tek-kaynağı boz demektir.

## İlişkili
- `.claude/skills/veri-dogrula/SKILL.md` § Cross-Source Sweep — çoklu-kaynak mutabakat (kardeş desen).
- `.claude/skills/yonetici-rapor/SKILL.md` — markdown emitter (belge).
- `.claude/skills/dashboard-icerik/SKILL.md` — dashboard emitter.
- `.claude/rules/semantic-layer.md` — çekirdek sema'dan okur.
- `.claude/rules/footprint-ladder.md` — yeni emitter = en dar basamak (yeni çekirdek/sayfa değil).
