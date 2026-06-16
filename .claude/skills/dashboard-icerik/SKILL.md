# Dashboard İçerik Ekleme Skill'i

> Amaç: GM Dashboard'a (Blazor Server, CFO mobil PWA) yeni KART / DRILL / SAYFA / METRİK eklerken her seferinde AYNI app-dili + mobil + veri-doğru kalıbı kur. Bu oturumların (mockup → app dili → drill → stok → LLM) kristalize hâli.

**Ne zaman:** "dashboard'a X ekle", "yeni kart/grafik/drill", "şu metrik gözüksün", "envanter/müşteri/operasyon sayfasına …" denildiğinde. Yeni rapor scripti DEĞİL (o gm-rapor). Asistan/chat UI DEĞİL (o asistan-ui).

---

## 1. KEMİK İLKELER

1. **Mobil-önce.** Tasarım 390px'te başlar, masaüstü genişler. Her şey tek elle, başparmakla.
2. **Hazır bileşen kullan, yeni icat etme.** Aşağıdaki App* paleti + DaisyUI. Custom CSS sadece DaisyUI'nin vermediği için.
3. **Veri sema-driven + MCP-test-first.** Sorgu yazmadan `sema/`'ya bak; yeni sorguyu ÖNCE MCP'de çalıştır-doğrula, SONRA C#'a göm.
4. **Tablo YASAK.** `<table>` yok → AppDataTable / AppRankBars / AppIconRow.
5. **Her async aksiyon geri bildirim verir.** Basıldı-rengi (active:) + yükleniyor (spinner/"Yükleniyor…").
6. **Renk = anlam = DaisyUI token.** Ham hex yok (bkz. `.claude/rules/renk-standardi.md`).
7. **Build → 390px smoke → commit.** Doğrulamadan "bitti" yok.

---

## 2. BİLEŞEN PALETİ (`dashboard/Components/Shared/`)

| Bileşen | Ne için | Anahtar parametreler |
|---|---|---|
| **AppKpiCarousel** / hero | Üst KPI şeridi (gradient kart, mobil swipe + masaüstü grid) | `Items: IReadOnlyList<KpiCardData>` (Label/Value/Gradient/Sub). Home `HeroCard` deseni de var. |
| **AppIconRow** | Kimlikli varlık listesi (mağaza/il/kasiyer/ödeme/ölü-stok) — renkli ikon + ad/alt + tutar + opsiyonel trend + chevron | `Items, Name, Sub, Amount, Icon, IconColor?, Trend?, OnRowClick?` |
| **AppRankBars** | Dağılım/oran listesi (kategori mix, kanal payı) — progress bar + değer | `Items, Label, Value, ValueText, OnRowClick?` (set → drill) |
| **AppDataTable** | Metrik listesi (ürün/kanal/kasiyer) — sol primary+alt / sağ metrik+alt / badge / accordion | `Items, Primary, Sub?, MetricMain?, MetricSub?, Badge?, Details?` (RenderFragment<T> → tıkla-genişlet) |
| **AppAreaChart** | Fintech sparkline (trend) — büyük sayı + değişim rozeti + ince çizgi | `Items, Name, Color, Height, XValue, YValue` (ApexCharts, `where T:class`) |
| **AppBarChart** | Yuvarlak köşe bar | ApexCharts |
| **AppPeriodPills** | Dönem segment (Günlük/Haftalık/Aylık + opsiyonel özel takvim) | `Period, PeriodChanged, Busy(=_loading), ShowOzel, CssClass` |
| **Modal** | Drill bottom-sheet (grip + büyük ✕ + backdrop) | `@bind-Open, Title, ChildContent`. z-[200], modal-bottom sm:modal-middle |

**Seçim:** kimlik listesi → AppIconRow · dağılım/oran → AppRankBars · metrik+detay → AppDataTable · trend → AppAreaChart · üst KPI → carousel.

---

## 3. VERİ KATMANI

- **Sorgular:** `dashboard/Data/Queries.cs` (dönem/KPI), `RefQueries.cs` (drill/ürün), `MagazaQueries.cs`, `EticQueries.cs`. Her metot kendi `db.OpenAsync()` açar → `Task.WhenAll` ile paralel.
- **Sema-first:** join/filtre/kod `sema/{bridges,entities,codes,metrics}.yaml`'dan. Yeni gerçek keşfedince → `sema-ogren`.
- **Kurallar (`.claude/rules/sql-server-conventions.md`):**
  - Yerel DMY (`CONVERT 104`), ODAKJOKER ISO (`YYYYMMDD`).
  - EncoreMerkez: `WHERE IsValid=1`, `DiscountTotalDirect`, DocType `IN (1,2,3,6,7,8)`, iade `CASE WHEN DocType=3 THEN -` , compat 110 (IIF/STRING_AGG yok — ama default DB DerinSISBkm context'te IIF ÇALIŞIR).
  - Köprü: `Products.Code = urn.stkID` (stkKod/barkod DEĞİL).
  - **Ciro KDV-dahil** (EncoreMerkez TotalPrice/GrossTotal). irsHrk KDV-hariç (envanter/devir için).
  - Anlık stok: `stokSonAltDepo_vw` (ehMekan 1/4477/4478=mağaza, 12=Merkez Depo; transit 4480/26142/4835 hariç). ODAK e-tic stok: `ent.odak_depo_Stok` (stkID→StokMiktar).
- **Şube scope:** drill metotları `@mekan` parametresi alır — Genel=0 (3 mağaza TOPLAM), Magaza detay=`Id`. WHERE `(@mekan=0 OR MG.mekanID=@mekan)`.
- **MCP test-first:** yeni sorgu → `mcp__sqlserver__sql_query` (tek SELECT, CTE'siz, top-level ORDER BY'a TOP ekle) → sayı mantıklı mı doğrula → C#'a göm. **Asla körlemesine gömme** (stkKod=barkod / key-mismatch sessiz yanlış sayı üretir).

---

## 4. İÇERİK EKLEME AKIŞI

1. **Tier tespiti** (`.claude/rules/plan-first.md`): 3+ dosya / yeni sayfa / şema → Tier 3 plan. Tek karta metrik = Tier 1-2.
2. **Veri:** sema'ya bak → MCP'de sorgu doğrula → `Data/*.cs`'e metot + `Models/*.cs`'e record.
3. **UI:** sayfaya `<h2>`/sectitle + uygun App* bileşen. Drill gerekiyorsa `OnRowClick` → `Modal` + `_modalX` state + lazy `OpenX` (modal anında açılır + `_loading` spinner → veri gelince doldurur).
4. **Drill tek seviye:** üst modaldan alt modal açılırken üstü kapat (`_modalUst=false`) — telefonda iç içe sheet kapatma karmaşası olmasın.
5. **Doğrula + commit** (§7).

---

## 5. DOKUNMA + MOBİL KURALLARI

- **Taşma 0:** 390px'te `scrollWidth==innerWidth`. Geniş grid → kompakt/accordion. Sayılar `tabular-nums whitespace-nowrap`.
- **Dokunma geri bildirimi:** tıklanabilir her şey `active:scale-[.98]`/`active:bg-base-200` (basıldı hissi). Yavaş aksiyon (drill 3-4s, dönem reload) → spinner ("Yükleniyor…" / pill Busy spinner / modal anında açılıp spinner).
- **Modal:** bottom-sheet + grip (geniş tıkla-kapat) + ✕ 44×44 + backdrop = 3 kapatma yolu.
- **Hedef ≥44px dokunma alanı.** Buton/satır yeterince yüksek.
- **Alt nav (btm-nav)** mobilde 5 BI sayfa; üst bar zil(bildirim=NotifState)+CFO(menü). Sayfa kendi bell/CFO'sunu KOYMAZ (tekrar olur).

---

## 6. AI / LLM İÇERİK

Otomatik yorum/özet gerekiyorsa `LlmService` (yerel qwen2.5-3b):
- **Deterministik metni ANINDA göster**, LLM'i arka planda çağır (sayfa beklemez), gelince değiştir + "AI" rozeti/spinner.
- **Kuşak (gen) guard:** dönem değişirse eski LLM sonucunu yok say.
- **Küçük model işaret/sayı hatası yapar:** veriyi sayı+yön KELİMESİYLE ver ("%38 ARTIŞ"), prompt'ta "yönü ters çevirme/uydurma yok" + few-shot. İlk yük CPU'da ~75-130s.

---

## 7. DOĞRULAMA RİTÜELİ (zorunlu)

```
1. dotnet build dashboard   → 0 hata
2. preview_start (--launch-profile http) + resize 390×844
3. Smoke: ekle, drill aç, accordion genişlet → taşma 0, sayı doğru, render OK
4. preview_stop (exe kilidi) → git commit (tek konu)
```
- LAN test: `dotnet run --project dashboard --launch-profile http` → `192.168.1.x:5112` (telefon).
- Sayı doğruluğu kritikse MCP'de aynı sorguyla karşılaştır (drill = MCP eşit mi).

---

## 8. ANTI-PATTERN

- ❌ `<table>` → AppDataTable/AppRankBars.
- ❌ Ham hex / kendi renk değişkeni → DaisyUI token.
- ❌ Sorguyu MCP'de doğrulamadan C#'a gömmek → sessiz yanlış sayı.
- ❌ irsHrk (KDV-hariç) ile POS cirosu (KDV-dahil) karıştırmak.
- ❌ Yavaş aksiyona geri bildirim koymamak (pasif buton).
- ❌ İç içe modal stack (telefonda kapatma karmaşası) → tek seviye.
- ❌ Sayfaya kendi bell/CFO (üst bar'da var, tekrar).
- ❌ Build yeşil = bitti (390px smoke şart).

## İlişkili
- **On-demand rule'lar (bu skill tetiklenince UYGULA — plan-12 WS-2):** `.claude/rules/renk-standardi.md` · `.claude/rules/turkish-ui.md` · `.claude/rules/file-size-discipline.md` · `.claude/rules/coding-discipline.md`.
- `.claude/rules/renk-standardi.md` · `.claude/rules/sql-server-conventions.md` · `.claude/rules/semantic-layer.md` · `.claude/rules/plan-first.md`
- `sema/*.yaml` · `plans/08-apexcharts-migration.md` · `plans/09-dashboard-rafine.md`
- `.claude/skills/asistan-ui/SKILL.md` (chat UI — ayrı) · `.claude/skills/gm-rapor/SKILL.md` (rapor scripti — ayrı)
