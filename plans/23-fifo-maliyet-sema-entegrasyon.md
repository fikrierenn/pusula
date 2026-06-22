# Plan 23 — FIFO Maliyet ↔ Sema/Öğrenme İki Yönlü Birleşme + Aktivasyon

**Tarih:** 2026-06-19
**Proje:** `bkm` (+ cross-repo: `D:\Dev\fifo`)
**Yazan:** Fikri / Claude
**Durum:** `Taslak`

---

## 1. Problem

FIFO maliyet sistemi (`D:\Dev\fifo` — BKMMaliyet DB) olgun ve lokalde (BT-FIKRI) dolu çalışıyor (Katman 657.945 · Çıkış 267.494 · Açılış 508.801, Ocak 2026 karlılık doğrulandı). Ama bu zengin maliyet/marj bilgisi **pusula'dan kopuk**: (a) pusula'nın yapılandırılmış `sema/*.yaml`'ında BKMMaliyet boş kabuk (`rol: "maliyet/marj"` var, entity/bridge/code/metric YOK); (b) FIFO projesinin kendi belleği anlatı-markdown (`memory/*.md`), pusula'nın atomic+confidence+decay disiplininde değil — iki ayrı öğrenme rejimi; (c) Genius asistanı "X ürünün marjı / mağaza karlılığı" soramaz, dashboard'da maliyet/marj yüzeyi yok.

İki sistemi harmanlamamız gerekiyor: FIFO domen gerçeği pusula semasına girsin, FIFO repo'su pusula'nın öğrenen iskeletine hizalansın, ve sonuç **asistanda + dashboard'da canlı** olsun.

## 2. Scope

### Kapsam dahili
- **Yön A — FIFO bilgisi → pusula sema:** BKMMaliyet entity/bridge/code/metric kayıtları `sema/*.yaml`'a (sqlcli ile canlı doğrulanmış, evidence + last_verified).
- **Yön B — FIFO repo → pusula iskeletine hizalama:** `D:\Dev\fifo` memory/rule'ları pusula'nın sema-ogren/decay/footprint disiplinine yaklaştırılır (yeni mükerrer sistem KURMADAN — köprü/cross-link + ortak kurallar).
- **Aktivasyon 1 — Asistan:** Genius maliyet/marj sorularını cevaplar (sema kayıtları + lokal BKMMaliyet'e SQL bağlantısı).
- **Aktivasyon 2 — Dashboard:** Maliyet/marj sayfası (lokal BKMMaliyet, env-driven bağlantı, DaisyUI semantic token).
- Keşif SQL'leri `sorgular/2026-06-19-fifo-*.sql` arşivi (ikiz yükümlülük).

### Kapsam dışı
- FIFO SP/hesaplama mantığı değişikliği (FIFO repo'da; bu plan onu TÜKETİR, değiştirmez).
- OrtalamaAylikMaliyet'i lokalde doldurmak (boş — FIFO-vs-ortalama karşılaştırması Faz dışı; sadece FIFO maliyeti aktive edilir, ortalama "veri bekliyor" işaretlenir).
- 201 production BKMMaliyet'e geçiş (env değişimiyle; bu plan lokal=test üzerine kurulur, kod host-agnostik).
- FIFO repo'sunun pusula'ya taşınması/merge'i (ayrı repo kalır — sadece bilgi+disiplin köprülenir).

### Etkilenen dosyalar (tahmin)
- `sema/entities.yaml` — BKMMaliyet entity'leri (FifoKatman, FifoCikisDetay, FifoAcilisEnvanter, OrtalamaAylikMaliyet, FifoSorunluStoklar, view'lar)
- `sema/bridges.yaml` — BKMMaliyet.StkId ↔ DerinSIS urn.stkID; FifoCikisDetay.MekanId ↔ mekan; gelir↔maliyet köprüsü
- `sema/codes.yaml` — KaynakTip, Durum, SorunTipi, HareketTipi kod sözlükleri
- `sema/metrics.yaml` — SMM, brüt kâr, marj, FIFO birim maliyet, fallback güvenilirlik metrikleri
- `sema/README.md` + `sorgular/SEMANTIK_KATMAN.md` — insan-okunur senkron
- `dashboard/Data/Db.cs` — `OpenMaliyetAsync()` lokal bağlantı (PANEL_DB kalıbı, env-driven)
- `dashboard/Data/MaliyetQueries.cs` — YENİ (maliyet/marj sorguları, Dapper)
- `dashboard/Components/Pages/Maliyet.razor` (+ alt-component) — YENİ sayfa
- `dashboard/Data/Asistan/AsistanAraclar.cs` — `maliyet_sql` aracı (lokal bağlantıya route) + sema_oku zaten kapsar
- `dashboard/Data/Asistan/AsistanService.cs` — prompt'a maliyet domeni ipucu
- nav (sidebar) — Maliyet linki
- `.env` — `MALIYET_DB_HOST/NAME/TRUSTED` anahtarları (+ `.env.example`)
- `D:\Dev\fifo\.claude\rules\memory-protocol.md` + `CLAUDE.md` — pusula sema köprüsü notu (cross-link)
- `sorgular/2026-06-19-fifo-*.sql` — keşif arşivi
- `TODO.md` — plan-23 maddeleri

**Tahmini boyut:** ~14 dosya / sema ağırlıklı + 1 yeni sayfa + 1 yeni servis. Faza bölünür.

## 3. Alternatifler

### A: Sadece sema'ya yaz, UI/asistan ertele
**Açıklama:** FIFO bilgisini sema/*.yaml'a işle, dashboard+asistan sonraki tura.
**Reddetme sebebi:** Kullanıcı açıkça "her ikisi de" (asistan + dashboard aktivasyonu) dedi. Yarım kalır.

### B: BKMMaliyet'i 201 MCP allowlist'e ekle, her şeyi 201'den besle
**Açıklama:** ALLOWED_DATABASES'e BKMMaliyet ekle, 201 production verisinden çalış.
**Reddetme sebebi:** Kullanıcı "maliyet testi 201'de değil lokalde" dedi. 201 BKMMaliyet'in güncelliği belirsiz; en taze veri lokal (BT-FIKRI). Gelir+maliyet tutarlılığı için ikisi de lokalden gelmeli.

### C: İki yönlü birleşme + lokal-besleme + env-driven host (SEÇİLEN)
**Açıklama:** sqlcli ile lokal canlı doğrula → sema'ya kanıtlı yaz; dashboard+asistan lokal BKMMaliyet'e env-driven bağlanır (host değişimi = .env, kod sabit → ileride 201'e geçiş bedava); FIFO repo disiplini cross-link'le hizalanır.
**Sebep:** Kullanıcı direktifine birebir uyar; test=lokal, prod=201 geçişi koda dokunmadan; sema canlı-kanıtlı (decay disiplini sağlanır).

## 4. Riskler

| Risk | Etki | Olasılık | Mitigation |
|---|---|---|---|
| Dashboard makinesi BT-FIKRI default instance'a erişemez (named instance/auth) | yüksek | orta | Faz 0'da `OpenMaliyetAsync` smoke-test; PANEL_DB Windows-auth kalıbı zaten çalışıyor (aynı makine) |
| Gelir (DerinSIS_Local) ↔ maliyet (FIFO) mekan/ürün eşleşmesi tutarsız | yüksek | orta | Marj sorgusu FIFO karlılık raporu SQL'ini taban alır (zaten doğrulanmış); mekan seti `1,12,4477,4478 + altDepo=0` sabit |
| OrtalamaAylikMaliyet boş → marj karşılaştırması yanıltıcı | orta | kesin | Sadece FIFO maliyeti göster; "ortalama: veri bekliyor" rozeti (silent-fallback YASAK) |
| Asistan maliyet SQL'i yanlış DB'ye (201) gider | orta | orta | `maliyet_sql` ayrı araç, açıkça lokal bağlantı; prompt'ta "maliyet=lokal" notu |
| Sema'ya yazılan köprü bayatlar (FIFO re-run sonrası) | düşük | orta | last_verified + ttl; runtime dashboard sorgusu doğal re-verify |
| FIFO repo'da mükerrer öğrenme sistemi kurma | orta | düşük | Yön B = cross-link + ortak kural, YENİ sistem değil (memory-protocol.md zaten "mükerrer KURMAZ" diyor) |

## 5. Done Criteria

- [ ] `sema/entities|bridges|codes|metrics.yaml` BKMMaliyet kayıtları eklendi, hepsi sqlcli ile canlı doğrulandı (evidence + last_verified=2026-06-19)
- [ ] `sorgular/2026-06-19-fifo-*.sql` keşif arşivi yazıldı (ikiz yükümlülük)
- [ ] `Db.OpenMaliyetAsync()` lokal BKMMaliyet'e bağlanıyor (smoke-test geçti)
- [ ] Dashboard Maliyet sayfası canlı veri gösteriyor (SMM, brüt kâr, marj — mağaza kırılımlı), DaisyUI token, Türkçe UI
- [ ] Genius asistanı "Ocak ayı brüt kâr marjı / X ürünün FIFO maliyeti" sorusunu doğru SQL ile cevaplıyor (canlı test)
- [ ] FIFO repo CLAUDE.md/memory-protocol'a pusula-sema köprü notu (cross-link)
- [ ] Marj rakamı FIFO karlılık raporuyla mutabık (Ocak: brüt kâr ~25.58M, marj %35.40 — rev2)
- [ ] `.env.example` MALIYET_DB_* anahtarları + dokümante
- [ ] Build yeşil + sayfa smoke-test + asistan canlı test

## 6. Rollback Planı

- Sema: `git revert` (yalnız yaml — veri değişmez, geri alma güvenli).
- Dashboard: yeni sayfa/servis izole → `git revert` + nav linki kaldır. Mevcut sayfalar etkilenmez (yeni bağlantı opsiyonel — `.env` MALIYET_DB_HOST yoksa sayfa "yapılandırılmadı" gösterir, PANEL_DB kalıbı).
- DB migration YOK (salt-okuma tüketim) → down script gerekmez.
- `.env` rollback: MALIYET_DB_* satırlarını sil.

## 7. Adımlar / TODO maddeleri

> **KULLANICI DİREKTİFİ (19.06):** ŞOV TARAFINDAN ÖNCE veri bütünlüğü. Maliyetsiz katman = 0, ters/negatif kayıt = 0, anomali = 0 OLMADAN dashboard/asistan (Faz 2-3) BAŞLAMAZ. Faz -1 = kapı (gate).

**Faz -1 — VERİ BÜTÜNLÜĞÜ DENETİMİ (GATE — her şeyden önce)**
0a. [ ] **F23-G1** Şema doğrula (describe FifoKatman/FifoCikisDetay/FifoSorunluStoklar/FifoAcilisEnvanter — kolon/tip kesin).
0b. [ ] **F23-G2** **Maliyetsiz yok:** BirimMaliyet=0/NULL katman + çıkış (Durum=FIYAT_YOK/HAYALI_FIYAT_YOK dağılımı). Hedef = 0 (veya gerekçeli kabul).
0c. [ ] **F23-G3** **Ters/negatif yok:** negatif BirimMaliyet, negatif KalanMiktar, KalanMiktar>GirisMiktar, negatif CikisTutar/Miktar.
0d. [ ] **F23-G4** **Sorunlu stok:** FifoSorunluStoklar SorunTipi dağılımı (ALIS_YOK/STOK_YETERSIZ/FIYAT_YOK kaç ürün).
0e. [ ] **F23-G5** **Negatif marj:** gelir<maliyet ürünler (B-grubu 58 referans) — tek tek değil sayım+dağılım.
0f. [ ] **F23-G6** **Tüketim invariant:** SUM(çıkış)≤SUM(giriş); KalanMiktar=GirisMiktar−tüketim tutarlılığı; katman-tüketim FK sağlam.
0g. [ ] **F23-G7** Bulgu raporu → `sorgular/2026-06-19-fifo-butunluk-denetim.sql` (arşiv) + özet. AÇIK kalan anomaliler kullanıcıya sunulur, düzeltme onayı alınır. **GATE: hepsi temiz/kabul edilmeden Faz 2+ yok.**

**Faz -1 BULGULARI (2026-06-19) — ne yapıldı / ne kaldı:**
- ✅ Yapısal bütünlük TERTEMİZ: C1 tüketim 0 · C2 negatif/ters 0 · C3 birim-maliyet eşleşme 0 · C4 orphan 0 · C7 mekan-12 OK.
- ✅ 13 sıfır-maliyet katman (669 adet) + 2 çıkış reprice'landı (`fifo/v2-production/20_V2`). Kök neden: 14_V2 SonAlis/SonMerkez CTE 0-fiyat guard'sızdı → fix (`WHERE BirimMaliyet>0`). Kural: `fifo/.claude/rules/fifo-domain.md §6`. Commit `f474830` (fifo repo).
- 🔶 **619 katmansız maliyetsiz envanter (FIYAT_YOK, devre-dışı hariç) — KALAN GATE.** Teşhis:
  - **330** ürünün kanonik `fn_SonGecerliFiyat(2025-12-31,1)` fiyatı VAR (fTur=1/fTip=1, sonrakiNet>0) → mevcut açılış BAYAT (SART tier fiyatlamalıydı, koşmamış/eski).
  - 15 fatAyr gerçek alış · geri kalan SatisFiyat imputation · **92 gerçekten fiyatsız** (ne alış ne fytOzl).
  - `19_V2` fallback seed'i `FifoFallbackFiyatlari`'na yazılmış ama **tüketilmemiş** (açılış DEVIR_FALLBACK ile re-run edilmemiş).
  - Engel: açılış re-run **irs/irsAyr DROP** (disk temizliği) yüzünden bloklu.
- **KARAR (kullanıcı 19.06):** 520→son fytOzl/kanonik fiyat · uygulama = **201'den irs/irsAyr re-seed + tam re-run** (hedefli insert DEĞİL).

**Faz -1B — 619 REMEDIATION — ✅ TAMAMLANDI (hafif yol, re-run YOK; commit `742847f`):**
- Keşif: 619'un **çıkışı SIFIR** (saf açılış stoğu) → re-run/Ocak/irs-irsAyr-re-seed GEREKSİZ. Kullanıcı "büyüğü silme" → hedefli katman insert.
- `21_V2_AcilisEksikMaliyet.sql` (idempotent, transaction, 0-kalırsa-ABORT): fiyat öncelik fatAyr→fytOzl(fn HIZLI eşdeğeri, TVF değil)→SatisFiyat×kategori-marj→kategori-ort→devre-dışı.
- Sonuç: +573 katman (fytOzl 330 / kategori-imput 227 / kategori-ort 16) + 46 devre-dışı (hepsi UrunBilgi master'da YOK = obsolete). İmpute'lar `FifoFallbackFiyatlari` (SatinalmaSarti=KATEGORI_IMPUT) audit.
- ✅ DOĞRULAMA: maliyetsiz katman=0 · maliyetsiz çıkış=0 · katmansız açılış=0 · C1/C2/C3=0 · toplam katman 658.518.
- 🔶 KALAN (ayrı, gate-dışı kalite): **982 negatif-marj triyajı** (gerçek zarar mı maliyet-tahmin hatası mı).

**GATE DURUMU:** "Fiyat 0 olamaz · maliyetsiz kalmayacak · ters/anomali olmayacak" → ✅ SAĞLANDI. Şov tarafı (Faz 1-3 sema+dashboard+asistan) açıldı.

**Faz 0 — Keşif + bağlantı (bloker çöz)**
1. [ ] **F23-0a** sqlcli ile BKMMaliyet köprülerini canlı doğrula (StkId↔urn.stkID eşleşme oranı, MekanId değerleri, KaynakTip/Durum/SorunTipi dağılımı, vw_MaliyetKarsilastirma şeması). SQL'leri `sorgular/2026-06-19-fifo-kesif.sql`'e arşivle.
2. [ ] **F23-0b** `Db.OpenMaliyetAsync()` + `.env` MALIYET_DB_* (PANEL_DB kalıbı, Windows auth, BT-FIKRI). Smoke-test: COUNT sorgusu.

**Faz 1 — Sema (Yön A)**
3. [ ] **F23-1a** `sema/entities.yaml` — BKMMaliyet entity'leri (kanıtlı).
4. [ ] **F23-1b** `sema/bridges.yaml` — maliyet↔ERP köprüleri.
5. [ ] **F23-1c** `sema/codes.yaml` — KaynakTip/Durum/SorunTipi/HareketTipi.
6. [ ] **F23-1d** `sema/metrics.yaml` — SMM/brüt kâr/marj/FIFO birim maliyet formülleri.
7. [ ] **F23-1e** `sema/README.md` + `sorgular/SEMANTIK_KATMAN.md` senkron.

**Faz 2 — Dashboard (Aktivasyon 2)**
8. [ ] **F23-2a** `MaliyetQueries.cs` — SMM/marj sorguları (FIFO karlılık SQL taban, mağaza kırılımlı).
9. [ ] **F23-2b** `Maliyet.razor` + alt-component (sayfa, grafik, tablo, CSV).
10. [ ] **F23-2c** nav linki + Türkçe UI + DaisyUI token.
11. [ ] **F23-2d** Marj mutabakatı (Ocak rev2: brüt 25.58M / %35.40) + smoke-test.

**Faz 3 — Asistan (Aktivasyon 1)**
12. [ ] **F23-3a** `maliyet_sql` aracı (lokal bağlantıya route) + AsistanAraclar.
13. [ ] **F23-3b** AsistanService prompt'a maliyet domeni ipucu (maliyet=lokal notu).
14. [ ] **F23-3c** Canlı test: marj/maliyet sorusu → doğru cevap.

**Faz 4 — FIFO repo hizalama (Yön B) + kapanış**
15. [ ] **F23-4a** FIFO repo `CLAUDE.md`/`memory-protocol.md`'ye pusula-sema köprü notu (cross-link; mükerrer sistem değil).
16. [ ] **F23-4b** Journal + TODO senkron + plan arşive.

## 8. İlişkili

- FIFO kaynak: `D:\Dev\fifo\CLAUDE.md`, `~/.claude/projects/d--Dev-fifo/memory/semantic_layer.md` + `fifo_logic_findings.md`
- FIFO domen kuralı: `D:\Dev\fifo\.claude\rules\fifo-domain.md` (ortak-havuz, devre-dışı, rerun-safe)
- pusula sema disiplini: `.claude/rules/semantic-layer.md`, `sema/README.md`
- Asistan: `plans/20-bkm-asistan-pwa.md`, `dashboard/Data/Asistan/*`
- FIFO karlılık raporu (mutabakat referansı): `D:\Dev\fifo\raporlar\Ocak2026_Karlilik_Raporu.md`

## 9. Onay

- [ ] Plan kullanıcıya gösterildi
- [ ] Geri bildirim alındı
- [ ] Onay alındı: <tarih>
