# Plan 10 — Dashboard İçerik Genişleme (B-53..B-72)

**Durum:** Onay bekliyor · **Tier:** 3 · **Tarih:** 14.06.2026 · **Kaynak:** dashboard-oneri taraması + kullanıcı sadakat isteği
**İlişkili:** `.claude/skills/dashboard-icerik/SKILL.md` (uygula) · plan-08/09 (önceki dashboard) · `sema/*.yaml`

---

## Problem

GM Dashboard 6 sayfa app-dili tamam ama **erişilebilir veri ↔ gösterilen** arasında boşluk: trend yok (anlık sayı çok), kırılım yok (toplam çok), karşılaştırma yok (hedef vs gerçek, dönem vs dönem), müşteri sadakat sığ (tek RFM snapshot). 20 fırsat (B-53..B-72) belirlendi; ikisi tema: (a) genel içerik genişleme, (b) **derin müşteri sadakat** (kullanıcı talebi).

## Scope

**Dahil:** B-53..B-72 — mevcut App* bileşen paleti + Queries/RefQueries/EticQueries + sema-driven sorgu. Yeni "Sadakat" sayfası (B-66+).
**Hariç:** Yeni POS/kafe kaynağı (B-43), mobil HTTPS/cert (B-47), yeni dış bağımlılık. Linked-server ağır sorgular (B-59) timeout korumalı.

## Alternatifler (reddedilen)

- ❌ **Hepsini tek mega-commit.** Reddedildi — 20 özellik tek PR = test/rollback imkânsız. Faz + özellik-başına commit.
- ❌ **Sadakat metriklerini mevcut Müşteri sayfasına sıkıştır.** Reddedildi — 7 derin metrik tek sayfayı boğar; ayrı `/sadakat` sayfası (drill'li).
- ❌ **Önce orta/zor (M/L) işler.** Reddedildi — hızlı kazanımlar (S) önce: değer erken, pattern ısınır, risk düşük.

## Riskler

- **JOKER linked-server timeout** (B-59 online kategori, B-56 COD il) → `try/catch` + fallback + log; sorguyu dar tut (ISO tarih, TOP). 
- **360g/çoklu-dönem tarama yavaş** (kohort B-66, kasiyer 2× B-57) → drill spinner + materialized düşün.
- **Müşteri PII** (isim/tel/kart — B-68 win-back) → sadece dashboard içi, export log, maskeleme (tel son 4). `security-principles.md`.
- **Enum keşfi eksik** (B-64 J_ORDERS.STATUS) → önce `SELECT STATUS,COUNT(*)` + codes.yaml.

## Done Kriterleri (her özellik)

1. MCP'de sorgu doğrulandı (sayı mantıklı, drill=MCP eşit).
2. Build yeşil + 390px smoke (taşma 0, render OK).
3. App* bileşen (tablo yok), renk-standardı, dokunma geri bildirimi.
4. Yeni şema gerçeği → `sema-ogren`. Tek-konu commit.

## Rollback

Özellik-başına commit → `git revert <hash>`. Yeni sayfa (/sadakat) izole, mevcut sayfaları etkilemez.

---

## FAZ 1 — Hızlı Kazanımlar (S, mevcut sorgu varyasyonu, yeni tablo yok)

> Hedef: tek oturumda 5-7 özellik. Her biri mevcut metodun küçük varyasyonu.

| Adım | B | Ne | Veri / Dosya | Bileşen |
|---|---|---|---|---|
| 1.1 | **B-54** | Hedef **pace-line** (beklenen ilerleme çizgisi) — haftalıkta da hedef göster | C# `Today.Day/DaysInMonth`, SQL yok · Home.razor HedefRow | progress + marker |
| 1.2 | **B-53** | Mağaza **30-gün ciro trendi** | `Queries.GetTrendAsync` + mekanId param · Magaza.razor | AppAreaChart |
| 1.3 | **B-57** | **Kasiyer** aylık sıralama + önceki-ay **delta** rozeti | `kasSql` 2× (cari+önceki) + C# delta · Operasyon | AppDataTable + trend |
| 1.4 | **B-58/B-65** | Müşteri **tekrar-alış oranı** + **kayıp 3-ay trendi** | `ykSql` 3× (t/t-30/t-60), Frq>1 payı · Musteri | AppAreaChart + stat |
| 1.5 | **B-56** | **COD iade il** tablosu (coğrafi risk) | `GetIlTeslimat` + PAYDEFREF=-3 + CARGODELIVERYSTATUS · Eticaret | AppDataTable (timeout-korumalı) |
| 1.6 | **B-55** | Mağaza **saat×gün ısı haritası** (7×14) | Sales DATEPART HOUR+WEEKDAY (saatSql+weekday) · Magaza | **yeni AppHeatmap** (~60 satır SVG/grid) |

**Faz 1 çıkışı:** 6 özellik canlı, her biri ayrı commit. Pattern doğrulandı.

---

## FAZ 2 — Orta (M, yeni sorgu / cross-db join)

| Adım | B | Ne | Veri | Not |
|---|---|---|---|---|
| 2.1 | **B-59** | E-tic **online kategori mix** | J_ORDER_DETAILS→J_ITEMS.DERINSIS_ID→urnKtgr2 (ISO) | JOKER timeout riski — dar sorgu |
| 2.2 | **B-60** | **Depo WMS anlık durum** kartı | J_DEPO_TOPLANACAK + depo.emirAyr(bugün) + Joker CK | Home veya /depo |
| 2.3 | **B-61** | Kategori **net marj %** | B-07 SQL (fatAyr.ehTutarN/ABS(ehAdetN)) adapt | Envanter |
| 2.4 | **B-62** | **Hediye çeki** yükümlülük | SalesPayments + çeki ID keşfi + VOUCHERCODE | önce ID keşfi |
| 2.5 | **B-63** | **Marka** alış-vs-satış dengesi | irsHrk 4/100 vs 0/10 GROUP BY urnMrk | Envanter |
| 2.6 | **B-64** | E-tic sipariş **funnel** | J_ORDERS.STATUS (önce enum keşfi→codes.yaml) | düşük öncelik |

---

## FAZ 3 — 🎯 Müşteri Sadakat Sayfası (`/sadakat`) — DERİN CRM (kullanıcı isteği)

> Yeni sayfa. Veri tabanı hazır: `EncoreMerkez.Sales.CustomersId = DerinCrm.Customer.Id` (köprü çözülü) + isim/tel/`CardNumber` + e-tic `J_ORDER_CLIENTS.CUSTOMERREF` + mevcut C1-rfm. **Önce MCP'de her metrik doğrulanır.**

| Adım | B | Metrik | Yöntem |
|---|---|---|---|
| 3.0 | — | `/sadakat` sayfa iskeleti + nav (alt nav 5 dolu → CFO menü veya Müşteri alt-sekme) + hero KPI (toplam müşteri/aktif/kayıp/CLV ort.) | shell |
| 3.1 | **B-66** | **Kohort retention** matrisi (aylık edinim × N-ay geri dönüş) | AppHeatmap, en güçlü sadakat metriği |
| 3.2 | **B-67** | **RFM segment geçiş** matrisi (dönem→dönem migrasyon) | RFM 2 dönem + akış (Şampiyon→Risk uyarı) |
| 3.3 | **B-68** | **Win-back** listesi (yüksek değer + 90g hareketsiz) | AppDataTable, isim/tel(maskeli)/kart · PII dikkat |
| 3.4 | **B-69** | **Sadakat kartı** analizi (kartlı vs kartsız ATV/frekans + penetrasyon) | CardNumber kullanımı |
| 3.5 | **B-70** | Müşteri **Pareto** (ciro %X / N müşteri) + top **CLV** tahmini | konsantrasyon riski |
| 3.6 | **B-71** | **Onboarding funnel** (1.→2. alış dönüşüm + süre) | tutma başlangıcı |
| 3.7 | **B-72** | Kategori **afinitesi** (çapraz-satış: kitap→kırtasiye) | sepet genişletme |

**Faz 3 önce ayrı mini-plan gerekebilir** (B-66/67 kohort SQL karmaşık) — Faz 3'e geçmeden kohort SQL'i MCP'de prototiple.

---

## Sıra / Bağımlılık

1. **Faz 1** (S) → erken değer, düşük risk. **Buradan başla.**
2. **Faz 2** (M) → Faz 1 pattern'i oturunca.
3. **Faz 3** (Sadakat) → en yüksek kullanıcı-isteği değeri ama en derin; 3.0 shell + 3.1/3.2/3.3 çekirdek önce, gerisi iteratif.

**Önerilen ilk iş:** B-54 pace-line (sıfır SQL, anında) → B-53 mağaza trend → B-55 heatmap. Sonra kullanıcı sadakat istiyorsa Faz 3'e atla.

## Adım Disiplini (her B-xx)

```
sema'ya bak → MCP'de sorgu doğrula → Data/*.cs metot + Models record →
sayfa App* bileşen + drill → build → preview 390px smoke → tek-konu commit →
yeni gerçek varsa sema-ogren → TODO'da B-xx ✅ + hash
```
