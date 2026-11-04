# Plan 53 — Pusula repo birleştirme + tek repoya indirme

**Tarih:** 2026-11-04
**Proje:** `bkm`
**Yazan:** Claude (oturum `f7e36e39`)
**Durum:** `Onaylandı` (2026-11-04) — F0 uygulamada

---

## 1. Problem

`pusula` deposunun **iki çatallanmış klonu** yan yana çalışıyor ve ikisi de ötekinin
güncel kopyası değil:

| | D:\Dev\pusula | X:\Dev\pusula |
|---|---|---|
| HEAD | `288968c` | `f3bad91` |
| Branch | `master` | `ork/001-panel-veri-duzeltme` |
| Son aktivite | 2026-11-04 | 2026-10-24 |
| Uncommitted | 4 | 39 |
| Git objeleri | **paylaşılmıyor** (ayrı klon, divergent) |

Tam ağaç diff'i: **775 dosya içerikçe farklı** (`sema/*.yaml` dahil). Çatallanma noktası
~**3–5 Ekim 2026**; sonra iki hat bağımsız ilerledi:

- **D** → domain-analiz hattı: `AySonuStok` (razor+arşiv+üretici), ODAK iade/hesapsorma,
  satınalma toplantı, hazırlık-akademi stok, `dashboard/Data/forecast`.
- **X** → yapısal/altyapı hattı: `lib/Bkm.TestAltyapi` + `tests/GmDashboard.Tests` (test
  projesi), `Directory.Packages.props` (NuGet CPM), `web/` cockpit + `ork`/`.orkestra`,
  `tools/talep-tahmin` + `tools/ens-kalibrasyon` + makro-envanter scriptleri, 5 bölünmüş
  rule dosyası, ADR-007.

Risk: `sema/*.yaml` iki tarafta sapmış → **aynı soruya iki repo farklı cevap verir** (sessiz
yanlış rakam sınıfı). İki repo açık kaldıkça sapma büyür. Çözüm: tek kanonik trunk'ta
birleştir, ötekini emekliye al, **tek repodan devam et**.

## 2. Scope

### Kapsam dahili
- İki klonun özgün-iş envanterini dosya düzeyinde kesinleştir (manifesto).
- Kanonik trunk seç (öneri: **D** — en yeni aktivite + bu oturum burada; X'in altyapısı D'ye taşınır).
- X-özgün yapısal işi (test altyapısı, CPM, cockpit, orkestra, talep-tahmin/ens araçları, rule split, ADR) D'ye **kontrollü port**.
- `sema/*.yaml` çatallanmasını **satır-satır uzlaştır** (ölçümle; hangi değer doğru — canlı doğrula).
- Birleşme sonrası X'i **arşivle** (bundle + salt-okuma), çalışmayı tek repoya indir.

### Kapsam dışı
- Otomatik `git merge` / `git pull` iki klon arası — **YAPILMAZ** (objeler paylaşılmıyor, divergent; kör merge 775 dosyada çakışma + sema bozar).
- Yeni özellik geliştirme — bu plan yalnız birleştirme.
- X'in uncommitted 39 dosyasından yarım işleri "tamamlama" — ya commit edilmiş hali taşınır ya açıkça atılır.

### Etkilenen dosyalar (tahmin)
- `plans/53-*.md` (bu dosya)
- D'ye yeni gelenler: `lib/Bkm.TestAltyapi/**`, `tests/GmDashboard.Tests/**`, `Directory.Packages.props` (+ muhasebe + sorgular), `web/**`, `ork*`, `.orkestra/**`, `tools/talep-tahmin/**`, `tools/ens-kalibrasyon/**`, `.claude/rules/{arayuz,csharp,dokuman,sql,testler}.md`, `docs/ADR/007-*.md`
- Uzlaştırılacak: `sema/*.yaml` (her iki tarafta modifiye), `TODO.md`, `CLAUDE.md`, çakışan dashboard/scripts dosyaları
- **Tahmini boyut:** port edilen ~60–90 X-özgün dosya + ~20–40 uzlaştırma. Çok fazlı.

## 3. Alternatifler

### A: Kör `git merge` (X branch'ini D'ye çek)
**Açıklama:** X'i remote ekle, `git merge ork/001...`.
**Reddetme sebebi:** Objeler paylaşılmıyor (ayrı klonlar) → unrelated-histories; 775 dosya çakışma; `sema/*.yaml` otomatik merge **sessiz yanlış değer** üretir (olctum-mu-cikardim-mi: makul görünen yanlış). before-major-change: geri-alınamaz, yasak.

### B: X'i trunk seç, D'yi taşı
**Açıklama:** X kanonik olsun, D'nin domain işi X'e portlansın.
**Reddetme sebebi:** X 11 gün eski + bu oturumun işi (hazırlık-akademi, ODAK iade 11-03/04) D'de; X branch'i feature-branch (`ork/001`), master değil; D'nin HEAD'i daha ileride. Daha çok ters-port gerekir.

### C (seçilen): D trunk, X'ten yapısal port + sema uzlaştır, sonra teke indir
**Açıklama:** D master kanonik kalır. X-özgün **yapısal** iş (test altyapısı, CPM, cockpit, orkestra, araçlar, rule split, ADR) parça parça D'ye port edilir — her parça kendi commit'i + build/test kapısı. `sema/*.yaml` çatallanması canlı ölçümle uzlaştırılır. Bitince X bundle'la arşivlenir, salt-okuma yapılır; çalışma yalnız D'de sürer.
**Sebep:** En yeni aktivite + açık oturum D'de; X'in değeri çoğunlukla **eklemeli altyapı** (D'de hiç yok → çakışmasız eklenir, riski düşük). Port parça-parça → her adım geri-alınabilir, build kanıtlar.

## 4. Riskler

| Risk | Etki | Olasılık | Mitigation |
|---|---|---|---|
| `sema/*.yaml` iki değerden yanlışı seçilir | yüksek (sessiz yanlış rakam) | orta | Her çatallanan kayıt **canlı sqlcli ile yeniden ölçülür**; `sema_degismez.py` + `sema_sorgu_dumani.py` koşturulur; değer ölçümden gelir, taraf seçiminden değil |
| X port'u D build'ini kırar (CPM geçişi) | yüksek | orta | CPM (`Directory.Packages.props`) ayrı commit + `dotnet build` kapısı; kırarsa o commit revert |
| X'in 39 uncommitted'inde yarım iş | orta | yüksek | Önce X'te `git status` + `git stash list` envanteri; yarım iş ya commit'li haliyle taşınır ya açıkça atılır (manifestoda işaretli) |
| Port sırasında D'nin açık işi karışır | orta | düşük | D'de önce 4 uncommitted temizle/commit; birleştirme ayrı branch `merge/x-port` |
| Teke indirince X'teki unique iş kaybolur | yüksek | düşük | X **silinmez** — `git bundle` + ayrı klasöre read-only arşiv; done criteria'da bundle doğrulanır |
| 775 dosya elle gözden kaçar | orta | orta | Dosya-düzeyi manifesto (Adım 1) tek doğruluk kaynağı; her dosya "port / atla / uzlaştır" etiketli |

## 5. Done Criteria

- [ ] Dosya-düzeyi özgün-iş manifestosu çıkarıldı (`plans/53-manifesto.md` veya scratchpad) — her X-özgün ve çatallanan dosya için karar etiketli.
- [ ] X-özgün yapısal iş D'ye port edildi (test altyapısı + CPM + cockpit + orkestra + araçlar + rule split + ADR), her parça kendi commit'i.
- [ ] `dotnet build` + `tests/GmDashboard.Tests` yeşil (X'ten gelen test projesi D'de koşuyor).
- [ ] `sema/*.yaml` çatallanması uzlaştırıldı; `python tools/sema_degismez.py` çıkış 0; `tools/sema_sorgu_dumani.py` kırık sorgu yok.
- [ ] Çatallanan her sema kaydı **canlı ölçümle** doğrulandı (taraf seçimiyle değil) — ölçüm `evidence` + tarih damgalı.
- [ ] X `git bundle create` ile arşivlendi; bundle `git bundle verify` geçti; arşiv konumu journal'da yazılı.
- [ ] X klonu salt-okuma/emekli (yeni commit yok); çalışma yalnız D'de.
- [ ] Journal 2026-11-xx + TODO senkron.

## 6. Rollback

- Birleştirme ayrı branch `merge/x-port`'ta yapılır; master'a squash-merge **son adımda**. Kötü giderse branch silinir, master dokunulmamış.
- Her port adımı kendi commit'i → tek tek `git revert`.
- X bundle'ı var olduğu sürece X'in tüm işi geri gelebilir (teke indirme geri-alınabilir).

## 7. Adımlar (sıra + bağımlılık)

**Faz 0 — Hazırlık (bağımsız)**
1. D'de 4 uncommitted'i çöz (commit / stash).
2. X'te `git status` + `git stash list` + `git log --oneline master..HEAD` → yarım iş envanteri.
3. `merge/x-port` branch'i D'de aç.

**Faz 1 — Manifesto (Faz 0 sonrası)**
4. Tam diff + "only in" listelerinden **dosya-düzeyi manifesto**: her dosya `port | atla | uzlaştır | zaten-var`. (Diff zaten üretildi; kararı yaz.)

**Faz 2 — Yapısal port (çakışmasız önce; her biri commit + build kapısı)**
5. `Directory.Packages.props` + CPM geçişi → `dotnet build` kapısı.
6. `lib/Bkm.TestAltyapi` + `tests/GmDashboard.Tests` → `dotnet test` kapısı.
7. `tools/talep-tahmin` + `tools/ens-kalibrasyon` + makro-envanter scriptleri.
8. `web/` cockpit + `ork`/`ork.cmd`/`.orkestra` + `config`.
9. `.claude/rules/{arayuz,csharp,dokuman,sql,testler}.md` split + `docs/ADR/007` + `acik-kararlar.md` + `sema-adaylari.yaml`.
10. X-özgün sorgular (ekim-hedef, bursa-kültür iade, talep-tahmin, ens-kalibrasyon, panel-veri-düzeltme) → `sorgular/`.

**Faz 3 — Uzlaştırma (en riskli; ölçüm zorunlu)**
11. `sema/*.yaml` çatallanan kayıtları tek tek: canlı sqlcli ölç → doğru değeri yaz → `evidence` tarihle. `sema_degismez.py` + `sema_sorgu_dumani.py` kapısı.
12. `TODO.md` + `CLAUDE.md` + çakışan dashboard/scripts dosyaları uzlaştır.

**Faz 4 — Teke indirme**
13. `merge/x-port` → master squash-merge (build+test+sema kapıları yeşilken).
14. X `git bundle create pusula-x-arsiv-2026-11-xx.bundle --all` → `git bundle verify`.
15. Bundle'ı arşiv klasörüne taşı; X klonunu emekliye al (README notu / salt-okuma).
16. Journal + TODO senkron; bu planı `plans/archive/`'e taşı.

---

> **Not:** Faz 2 (çakışmasız eklemeli port) riski düşük — D'de o dosyalar hiç yok. Asıl risk Faz 3 (sema uzlaştırma): orada taraf seçilmez, **ölçülür**. before-major-change + olctum-mu-cikardim-mi geçerli: her değer komutla doğrulanır.
