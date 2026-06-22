# Plan 25 — Muhasebe (Genel Muhasebe / Mizan) Dashboard Paneli

**Tarih:** 2026-06-22
**Proje:** `bkm`
**Yazan:** Fikri / Claude
**Durum:** `Taslak`

---

## 1. Problem

Dashboard tamamen satış/envanter/operasyon/müşteri odaklı; back-office (muhasebe, finans, İK, satınalma) hiç yok. Veri-keşfi sonucu: **tek gerçek-verili back-office domaini = genel muhasebe** (`DerinSISBkm.mhs` şeması, 54,96M satır, Tek Düzen Hesap Planı, son fiş 17.06.2026). Finans (`fns`) ve İK (`iky`) şemaları **boş** (0 / 93 satır) → yapılamaz. CFO bugün mizan, nakit pozisyonu, cari borç/alacak, KDV durumunu dashboard'da göremiyor; ERP ekranına gitmek zorunda.

## 2. Scope

### Kapsam dahili
- Yeni **Muhasebe** sayfası: dönem (yıl) seçili mizan + nakit/likidite + cari özet.
- **Özet kartlar:** Nakit pozisyon (100 kasa + 101/103 çek + 102 banka + 108 ödeme-aracı), Alıcılar (120) net bakiye, Satıcılar (320) net bakiye, KDV (191 indirilecek / 391 hesaplanan → net).
- **Mizan tablosu:** ana hesap (3-hane) bazlı Borç / Alacak / Bakiye; satır tıkla → alt hesap kırılımı (drill).
- **Banka & Kasa detayı:** 100/102/103 hesap-bazlı güncel bakiye.
- **En büyük cari bakiyeler:** 120 (alacaklı müşteri) + 320 (borçlu tedarikçi) Top-N.
- Veri kaynağı: mevcut `Db.OpenAsync()` (DerinSISBkm, 201) — **yeni bağlantı YOK**, cross-schema `mhs.*`.
- sema mhs kayıtları (entities/bridges/codes) + keşif SQL arşivi (ikiz yükümlülük).

### Kapsam dışı
- **Gelir tablosu / dönem K/Z (6xx-7xx)** — işaret/normal-bakiye semantiği mutabakat ister (600 bakiyesi pozitif çıktı; FIFO/DerinSIS ciro ile çapraz-doğrulama gerekli). **Faz-2'ye ertelendi.**
- Finans (`fns`) ve İK (`iky`) modülleri — veri yok.
- Yevmiye fiş drill (tek tek fiş görüntüleme) — mizan yeterli, fiş-detay sonraki tur.
- Cari hareket ekstresi (tek cari zaman-serisi) — Faz-2.
- Çoklu-şirket karşılaştırma — dönem seçici var ama yıllar-arası kıyas sonraki tur.

### Etkilenen dosyalar (tahmin)
- `dashboard/Data/MuhasebeQueries.cs` — YENİ (mizan, nakit, cari, KDV sorguları, Dapper).
- `dashboard/Models/MuhasebeModels.cs` — YENİ (MizanRow, NakitRow, CariRow, MuhasebeOzet records).
- `dashboard/Components/Pages/Muhasebe.razor` — YENİ sayfa (özet kart + mizan tablo + drill).
- `dashboard/Models/NavRegistry.cs` (veya nav neredeyse) — Muhasebe linki.
- `sema/entities.yaml` + `bridges.yaml` + `codes.yaml` — mhs domeni.
- `sorgular/2026-06-22-muhasebe-kesif.sql` — keşif arşivi.
- `TODO.md` — plan-25 maddeleri (yeni ID: B-115).

**Tahmini boyut:** ~5 dosya (3 yeni kod + sema + arşiv) / ~250 satır. Sayfa <300 satır hedef, gerekirse alt-component.

## 3. Alternatifler

### A: Tüm back-office'i birden planla (muhasebe+finans+İK+satınalma)
**Reddetme sebebi:** finans/İK boş (veri yok); satınalma B-110 ile kısmen kapsanıyor. Kullanıcı "bir domaini bitirelim" dedi. Geniş plan = yarım kalır.

### B: Gelir tablosu / dönem K/Z dahil tam mali tablo
**Reddetme sebebi:** 6xx/7xx işaret semantiği doğrulanmadı (600 pozitif anomali). Mutabakatsız "kâr=X" göstermek = sessiz-yanlış-rakam riski (rules ihlali). Mizan mekanik kesin; K/Z ayrı doğrulama turu.

### C: Mizan + nakit + cari odaklı tek sayfa, mevcut bağlantı (SEÇİLEN)
**Açıklama:** mhs zaten DerinSISBkm'de → `OpenAsync` cross-schema okur. Mekanik-kesin metrikler (borç/alacak/bakiye/nakit pozisyon/cari) önce; K/Z Faz-2.
**Sebep:** Sıfır yeni bağlantı, MCP-doğrulanabilir, en yüksek CFO değeri (likidite + cari), veri-doğruluğu garantili.

## 4. Riskler

| Risk | Etki | Olasılık | Mitigation |
|---|---|---|---|
| İşaret yanlış yorumu (borç/alacak) → ters bakiye | yüksek | orta | fisBA=0 Borç(+), fisBA=1 Alacak(fisTutar negatif saklı). Bakiye=SUM(fisTutar). MCP'de denge doğrulandı (borç=alacak, SUM=0). Mizan toplam Borç=Alacak invariant testi. |
| 6xx/7xx yanlış etiketleme (gelir pozitif anomali) | yüksek | — | Kapsam dışı (Faz-2). Bu sayfada K/Z YOK. |
| 39,5M satır perf | orta | düşük | fisSirketID (=yıl) + hesap GROUP BY ~230-510ms (MCP doğrulandı). Join (hspID AND hspSirketID). Index doğal (sirket+tarih). |
| Çoklu-şirket karışması (sirketID=dönem) | orta | orta | sirketID = dönem yılı (1=2021…6=2026). Sayfa tek dönem; default sirketID 6 (2026). Selector. |
| Cari hspKod ile DerinSIS cari/ürün köprüsü belirsiz | düşük | orta | Bu sayfa muhasebe-içi (hspKod/hspAd yeterli); ERP-cari köprüsü Faz-2 (gerekmiyor). |

## 5. Done Criteria

- [ ] Muhasebe sayfası canlı: özet kart (nakit/alıcı/satıcı/KDV) + mizan tablo + drill, dönem seçili.
- [ ] Mizan invariant: toplam Borç = toplam Alacak (denge testi geçer).
- [ ] Nakit pozisyon = 100+101+102+103+108 bakiye toplamı, MCP ile mutabık.
- [ ] DaisyUI semantic token (borç/alacak = error/success değil — muhasebe nötr; bakiye işareti renk), Türkçe UI, hardcode hex yok.
- [ ] Build yeşil + (mümkünse) render.
- [ ] sema mhs entities/bridges/codes + SQL arşiv (ikiz yükümlülük).
- [ ] TODO B-115 [x] + commit.

## 6. Rollback Planı
- Git revert tek commit. Yeni sayfa/servis izole, mevcut sayfalar etkilenmez. DB salt-okuma → migration yok. Nav linki kaldır.

## 7. Adımlar

1. [ ] **B-115.1** Keşif tamamlama: mhsAnaHsp grup eşlemesi, KDV hesap kodları (191/391), nakit hesap seti netleştir + SQL arşivle.
2. [ ] **B-115.2** `MuhasebeQueries.cs` + `MuhasebeModels.cs` — mizan / nakit / cari / KDV / özet sorguları.
3. [ ] **B-115.3** `Muhasebe.razor` — özet kart + mizan tablo + drill (alt-component gerekrse).
4. [ ] **B-115.4** Nav linki + Türkçe UI + DaisyUI token.
5. [ ] **B-115.5** Build + invariant/mutabakat doğrula + sema + TODO senkron + commit.

## 8. İlişkili
- Veri-keşfi bu oturum (2026-06-22): mhs şeması 54,96M, Tek Düzen, sirketID=dönem.
- sema disiplini: `.claude/rules/semantic-layer.md`.
- Sonraki: Faz-2 gelir tablosu/K-Z (6xx-7xx mutabakat), cari ekstre, fiş drill.
- B-110 (tedarikçi perf) — satınalma domeni komşu.

## 9. Onay
- [ ] Plan kullanıcıya gösterildi
- [ ] Onay alındı
