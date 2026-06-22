# Plan 24 — Tedarikçi/Yayınevi Performans Scorecard (B-110)

**Tarih:** 2026-06-22
**Proje:** `bkm`
**Yazan:** Fikri / Claude
**Durum:** `Tamamlandı` (22.06.2026 — onaylandı + uygulandı, build yeşil, canlı doğrulandı)

---

## 1. Problem

CFO "bu yayınevinden/markadan sipariş kesmeli miyim?" sorusu = sermaye kararı. Bugün Envanter'de iki ayrı marka kartı var (Top-20 ciro + "Alış-Satış Dengesi" aylık birikim/erime) ama hiçbiri **sermaye verimliliği** ölçmüyor: bir markanın iade oranı yüksek + stok devri yavaşsa o markaya bağlanan para ölü. Devir hızı + iade oranı + ciro tek satırda yan yana görülmeden "sipariş kes" kararı sezgisel kalıyor.

## 2. Scope

### Kapsam dahili
- Marka/yayınevi bazında tek scorecard: **yıllık ciro · iade oranı · stok devir hızı (yıllık) · anlık stok değeri** + "sipariş-kes" sinyali (devir < 1.5×).
- Eşik renklendirme: devir < 1.5× → `text-error` (sermaye tuzağı), 1.5–3× → `text-warning`, > 3× → `text-success`. İade oranı > %10 → ayrı `text-error` rozet.
- Envanter sayfasına mevcut iki marka kartının altına yeni kart.

### Kapsam dışı
- Yeni sayfa / nav / route YOK (footprint-ladder rung-1: mevcut Envanter sayfasını genişlet).
- Maliyet-bazlı (SMM) devir YOK — adet-bazlı devir (yıllık satış adet / anlık stok adet). Değer-bazlı devir Faz-2'ye bırakılır.
- Otomatik sipariş kesme/aksiyon YOK — sadece sinyal gösterimi (karar CFO'da).
- Tedarikçi (cari/firma) bazlı kırılım YOK — bu sürüm **marka/yayınevi** (`urnMrk`). Cari-bazlı ayrı iş.

### Etkilenen dosyalar (tahmin)
- `dashboard/Data/RefQueries.Envanter.cs` — yeni `GetTedarikciPerformansAsync(DateOnly yilBas, DateOnly bugun)` (~40 satır, tek SELECT, irsHrk 12-ay satış/iade + stokSonAltDepo_vw anlık stok join).
- `dashboard/Models/RefModels.cs` — yeni `record TedarikciPerfRow(string Marka, decimal YillikCiro, int SatisAdet, int IadeAdet, decimal IadeOrani, int StokAdet, decimal DevirHizi)`.
- `dashboard/Components/Pages/Envanter.razor` — yeni kart + arka plan yükleme (mevcut `_rot` deseni taklit).
- `TODO.md` — B-110 [~]→[x] senkron.

**Tahmini boyut:** 3 dosya / ~90 satır.

## 3. Alternatifler

### A: Yeni ayrı sayfa (`/tedarikci`)
**Açıklama:** Tedarikçi scorecard'ı kendi sayfasında, nav'a ekle.
**Reddetme sebebi:** footprint-ladder rung-6 (en pahalı): UI+route+nav+perf+test. Veri Envanter bağlamına ait (stok devri = envanter konusu). B-75 redesign dersi: dar başla, gerekirse büyüt.

### B: Mevcut "Marka Alış-Satış Dengesi" kartını zenginleştir
**Açıklama:** O kartın satırlarına iade oranı + devir kolonu ekle.
**Reddetme sebebi:** O kart aylık birikim/erime (kısa-vade akış) anlatıyor; devir+iade yıllık sermaye lensi. İkisini tek kartta karıştırmak okunabilirliği bozar, AppDataTable kolon sayısı şişer.

### C: Envanter'e yeni odaklı scorecard kartı (SEÇİLEN)
**Açıklama:** Mevcut iki marka kartının altına 3. kart — yıllık devir/iade/ciro + sipariş-kes sinyali. Aynı `urnMrk` köprüsü, aynı sayfa, yeni sorgu.
**Sebep:** Köprü kanıtlı (`GetMarkaRotasyonAsync` deseni), sayfa hazır, sıfır yeni yüzey. CFO kararını mevcut envanter bağlamında verir.

## 4. Riskler

| Risk | Etki | Olasılık | Mitigation |
|---|---|---|---|
| Devir paydası (anlık stok=0) → bölme hatası/sonsuz | orta | orta | `StokAdet=0` → DevirHizi NULL/∞ ayrı işle; UI'da "stok yok, hızlı tüketilmiş" rozeti. SQL'de NULLIF guard. |
| Düşük-hacim marka gürültüsü (1 adet satıp 0,3× devir) | düşük | yüksek | `HAVING SatisAdet >= N` (örn. ≥50) eşiği + dergi/sınav kategori dışlama (ölü stok deseni urnKtgr2ID NOT IN). |
| 12-ay irsHrk taraması yavaş | düşük | düşük | mevcut marka sorguları benzer hacimde hızlı; WITH(NOLOCK), arka plan yükle (kullanıcıyı bloklamaz). |
| Anlık stok=irsHrk view merkez-depo eksik (sema uyarısı) | orta | orta | Stok = mağaza (1/4477/4478) + merkez (12) `stokSonAltDepo_vw`; marka scorecard satış-merkezli → mağaza stoğu yeterli, merkez-WMS palet farkı bu lens için ikincil (dipnotta belirt). |

## 5. Done Criteria

- [ ] `GetTedarikciPerformansAsync` MCP'de canlı doğrulandı (devir/iade rakamları mantıklı, top markalar tutarlı).
- [ ] Devir < 1.5× markalar `text-error`, iade > %10 rozet doğru renkleniyor.
- [ ] StokAdet=0 kenar durumu çökme yapmıyor.
- [ ] .NET build yeşil (0 uyarı/hata).
- [ ] Renk standardı: hardcode hex yok, DaisyUI token (`text-error`/`warning`/`success`).
- [ ] Test (davranış-kontrat): iade_orani = iade/(satış brüt) ∈ [0,1]; devir ≥ 0; satır ≥ 1.
- [ ] TODO B-110 [x] + commit hash.

## 6. Rollback Planı

- Git revert: tek commit (`feat(bkm): tedarikçi/yayınevi performans scorecard (B-110)`) → `git revert <hash>`. DB değişikliği yok, salt-okuma sorgu. Risk minimal.

## 7. Adımlar

1. [ ] **B-110.1** MCP keşif: irsHrk 12-ay satış/iade + stokSonAltDepo_vw stok, marka bazlı devir formülü doğrula (tek SELECT, CTE'siz).
2. [ ] **B-110.2** `GetTedarikciPerformansAsync` + `TedarikciPerfRow` yaz.
3. [ ] **B-110.3** Envanter.razor kartı + arka plan yükleme (`_tedPerf` deseni).
4. [ ] **B-110.4** Build + (mümkünse) render doğrula; keşif SQL'i `sorgular/2026-06-22-tedarikci-performans.sql` arşivle.
5. [ ] **B-110.5** TODO senkron + commit.

## 8. İlişkili

- Önceki: `GetMarkaRotasyonAsync` (RefQueries.Envanter.cs:483) — aynı urnMrk köprüsü.
- sema: `bridges.yaml` urnMrk join, `metrics.yaml` devir/stok kaynağı (irsHrk + stokSonAltDepo_vw).
- TODO ID: B-110.
- Journal: `docs/journal/bkm/2026-06-22.md`.

## 9. Onay

- [ ] Plan kullanıcıya gösterildi
- [ ] Onay alındı
