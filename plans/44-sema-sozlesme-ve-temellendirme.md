# Plan 44 — Sema: sözleşme, referans grafı, canlı temellendirme

**Tarih:** 2026-09-11
**Proje:** `bkm`
**Yazan:** Claude (oturum `2bc97e22`)
**Durum:** `Uygulamada`

---

## 1. Problem

`sema/` 305 kayıtla BKM'nin en değerli kurumsal varlığı ama **şemasız**. Ölçüm (2026-09-11,
`scratchpad/sema_profil.py`):

| Boyut | Ölçüm |
|---|---|
| Kayıt | 305 — entities 124 · bridges 59 · codes 35 · metrics 71 · queries 15 |
| Alan adı savrulması | entities'te ~100 alan adı **yalnız 1 kayıtta** kullanılmış |
| Eş-anlamlı alanlar | kanıt 4 ad (`evidence`/`olcum`/`dogrulama`/`kanit`) · açıklama 6 ad · kural 4 ad · kaynak 3 ad |
| Kanıtsız kayıt | **140 / 312** (%45) |
| `last_verified` yok | **102** kayıt |
| Çapraz referans | 81 tespitin **tamamı prose'a gömülü** — makine okuyamaz |
| Kolon açıklaması | **1 / 124** entity (`dbo.irsHrk`) |
| Metrik semantiği | `tip` 0/71 · `additivity` 0/71 · `birim` 0/71 · `taban` 0/71 |
| Atomiklik ihlali | `metrics:hediye_ceki` **20.205 karakter** tek kayıt |

Sonuç üç somut zarar:
1. **Decay çalışmıyor.** 102 kayıtta damga yok → "stale" hesaplanamaz; README'deki ttl tablosu boşta döner.
2. **Kırık referans görünmez.** Bir köprü silinse/yeniden adlandırılsa onu prose'da anan 81 yer sessizce yanlış kalır.
3. **Kanıt etiketlenemiyor.** `olctum-mu-cikardim-mi.md` her sayının arkasında komut ister; kayıtların %45'inde kanıt alanı bile yok.

## 2. Scope

### Kapsam dahili
- `sema/_sozlesme.yaml` — kayıt tipi başına zorunlu/opsiyonel alan sözleşmesi (makine-okunur).
- `tools/sema_denetim.py` — sözleşme + referans bütünlüğü + atomiklik denetçisi. Exit **0/1/2**.
- Alan adı normalizasyonu: eş-anlamlılar tek ada; sözleşme dışı zengin alanlar `ayrinti:` altına.
- `kullanir:` referans grafı (`dosya:id`) + çözülemeyen referansta KIRIK.
- Canlı kolon temellendirme: `tools/sema_kolon_cek.py` — `sys.columns`'tan `columns:` doldurur, drift'i kırmızı verir.
- Metrik semantiği: `tip` / `birim` / `taban` / `additivity` / `grain`.
- Dev kayıtların atomikleştirilmesi (>4.000 karakter).
- `sema/README.md` + `.claude/rules/semantic-layer.md` + `.claude/skills/sema-ogren` sözleşmeye hizalanır.

### Kapsam dışı
- **Asistan tarafı (`sema_oku` / `AsistanAraclar.cs`) — DOKUNULMAYACAK.** Kullanıcı direktifi
  (2026-09-11): _"asistan kısmı neredeyse hiç kullanılmıyor, istediğim gibi çalışmadı, onunla çok
  uğraşma."_ `SemaOku` 6.000 karakter sessiz kırpması BİLİNEN ve KABUL EDİLEN borç → TODO'ya not,
  bu planda çözülmüyor.
- Semantic Kernel / Microsoft Agent Framework — ayrı konu, reddedildi (isim çakışması + SK
  maintenance-only).
- Skill eval iskeleti (power-platform-skills deseni) — ayrı plan.
- `sema/degismezler.json` ve `queries.yaml` **koşucuları** — zaten çalışıyor, davranışları değişmez.

### Etkilenen dosyalar
| Dosya | Ne olacak |
|---|---|
| `sema/_sozlesme.yaml` | YENİ — sözleşme |
| `tools/sema_denetim.py` | YENİ — denetçi (0/1/2) |
| `tools/sema_kolon_cek.py` | YENİ — canlı kolon temellendirme + drift |
| `sema/entities.yaml` | alan normalizasyonu + `ayrinti:` + `columns:` + `kullanir:` |
| `sema/metrics.yaml` | alan normalizasyonu + semantik alanlar + atomikleştirme |
| `sema/bridges.yaml` | eksik `last_verified`/`evidence` tamamlama |
| `sema/codes.yaml` | alan normalizasyonu |
| `sema/queries.yaml` | `kullanir:` bağlama |
| `sema/README.md` | sözleşme bölümü |
| `.claude/rules/semantic-layer.md` | sözleşme + denetçi kuralı |
| `.claude/skills/sema-ogren/SKILL.md` | yeni kayıt sözleşmeye uygun yazılır |
| `.claude/hooks/pre-commit-antipattern.sh` | denetçi çağrısı |

**Tahmini boyut:** 12 dosya. YAML tarafı büyük ama çoğu mekanik göç.

## 3. Alternatifler

### A: Sema'yı dbt/Cube'a taşı (gerçek semantik katman ürünü)
**Açıklama:** `sema/`'yı bırak, dbt semantic layer veya Cube data model kur; metrikleri orada tanımla.
**Reddetme sebebi:** İkisi de bir **dönüşüm/sorgu motoru** getiriyor (dbt: warehouse + jinja + çalıştırma;
Cube: Node servis + önbellek + API). BKM'de dönüşüm katmanı yok — ERP'ye salt-okuma bakıyoruz ve yazma
yasak (`erp-write-policy`). Motoru kurup yalnız "sözlük" kısmını kullanmak footprint-ladder 6. basamak,
üstelik `confidence`/`evidence`/decay alanlarımızın ikisinde de karşılığı yok. Reddedildi.

### B: JSON Schema + otomatik toplu göç (tek seferde hepsini normalize et)
**Açıklama:** Resmî JSON Schema yaz, `sema/*.yaml`'ı bir scriptle tek seferde yeniden yaz.
**Reddetme sebebi:** Otomatik yeniden yazma YAML yorumlarını ve blok-skaler biçimini (`>-`) kaybettirir;
sema'daki yorumlar (`# --- ERP iç ---`, kolon yanı notları) bilgi taşıyor. Ayrıca 140 kanıtsız kaydın
kanıtı **otomatik üretilemez** — uydurulur. Sessiz yanlış üretme riski, tam kaçındığımız sınıf.
Reddedildi. (JSON Schema yerine kendi YAML sözleşmemiz + **raporlayan** denetçi seçildi.)

### C — SEÇİLEN: Sözleşme + raporlayan denetçi + kademeli göç + canlı temellendirme
**Açıklama:** Önce sözleşmeyi yaz ve **hiçbir şeyi değiştirmeyen** denetçiyle ihlalleri ÖLÇ. Sonra
faz faz göç ettir; her fazda denetçi sayıyı düşürsün. Zengin/tek-kullanımlık alanlar silinmez,
`ayrinti:` altına alınır — bilgi kaybı sıfır, üst seviye sözleşmeye uyar. Kolon açıklamaları elle
değil `sys.columns`'tan çekilir ("liste elle yazılmaz" kuralı).
**Sebep:** Bilgi kaybı yok · her adım ölçülür · geri alınabilir · mevcut koşucuları (degismezler,
sorgu dumanı) bozmaz · kendi kurallarımızla (atomic, kanıtlı, ölçülmüş) hizalı.

## 4. Riskler

| Risk | Etki | Olasılık | Mitigation |
|---|---|---|---|
| Alan yeniden adlandırma mevcut tüketiciyi kırar (`sema_degismez.py`, `sema_sorgu_dumani.py`, skill'ler) | yüksek | orta | **Baskın adlar korunur** (`evidence`/`note`/`confidence`/`last_verified`) — yalnız azınlık eş-anlamlılar onlara katlanır. Göç sonrası iki koşucu da çalıştırılıp yeşil görülür |
| Otomatik göç YAML yorumu/biçimi kaybettirir | orta | yüksek | Toplu yeniden yazma YOK — hedefli `sed`/elle düzenleme, her dosya sonrası `yaml.safe_load` + kayıt sayısı karşılaştırması |
| `ayrinti:` altına taşıma bilgiyi gömer, okunmaz olur | orta | düşük | Denetçi `ayrinti:` içeriğini saymaya devam eder; README'de "zenginlik burada" yazar. Silme yok |
| Kanıtsız 140 kayda kanıt **uydurma** baskısı | yüksek | orta | Kanıt otomatik ÜRETİLMEZ. Kanıtsız kayıt `kanit_durumu: yok` ile işaretlenir ve denetçide **UYARI** (KIRIK değil) sayılır; gerçek kanıt ancak ölçülünce yazılır |
| `sys.columns` çekimi ERP'ye yük / bağlantı yok | düşük | orta | Salt-okuma katalog sorgusu, yalnız istenen tablolar. Bağlanamazsa **exit 2 (KOŞAMADI)** — yeşil demez |
| Kapsam patlaması (305 kaydın hepsini elle elden geçirme) | yüksek | yüksek | Faz sınırı: F2'de yalnız **mekanik** eş-anlamlı katlama; içerik elden geçirme F5/F6'ya, sıcak kayıtlarla sınırlı |

## 5. Fazlar

| Faz | İş | Done |
|---|---|---|
| **F1** | `sema/_sozlesme.yaml` + `tools/sema_denetim.py` (raporlar, değiştirmez) | Denetçi koşuyor, ihlal sayısı ÖLÇÜLDÜ, kırılabilirliği kanıtlandı |
| **F2** | Eş-anlamlı alan katlaması + `ayrinti:` kapsülleme | Denetçi "sözleşme dışı alan" sayısı → 0; `safe_load` kayıt sayısı değişmedi |
| **F3** | `kullanir:` referans grafı + bütünlük denetimi | Prose'daki 81 gömülü referansın tamamı açık alana taşındı; çözülemeyen referans = KIRIK |
| **F4** | `tools/sema_kolon_cek.py` — `sys.columns` temellendirme + drift | Sıcak 15 entity'de `columns:` canlıdan dolu; uydurma kolon adı kırmızı verir |
| **F5** | Metrik semantiği (`tip`/`birim`/`taban`/`additivity`/`grain`) | 71 metriğin tamamında 5 alan dolu; additivity kuralı değişmeze bağlandı |
| **F6** | Atomikleştirme (>4.000 karakter kayıtlar) | `hediye_ceki` dahil dev kayıtlar bölündü; max kayıt < 4.000 |

## 6. Done Criteria

- [ ] `python tools/sema_denetim.py` → **exit 0**; bağlanamazsa exit 2 (asla sessiz yeşil).
- [ ] Denetçinin kırılabilirliği kanıtlandı: bir alan bilerek bozuldu → KIRIK görüldü → geri alındı.
- [ ] `python tools/sema_degismez.py` ve `python tools/sema_sorgu_dumani.py` göç sonrası **aynı** sonucu veriyor (regresyon yok).
- [ ] `yaml.safe_load` kayıt sayısı göç öncesi/sonrası birebir (bilgi kaybı yok).
- [ ] Çapraz referans: prose'da kalan gömülü referans 0; `kullanir:` çözülmeyen referans 0.
- [ ] Kolon temellendirme: sıcak 15 entity `sys.columns` ile doğrulanmış; drift denetimi kırmızı verebiliyor.
- [ ] `sema/README.md` + `semantic-layer.md` + `sema-ogren` sözleşmeyi anlatıyor.
- [ ] Pre-commit hook denetçiyi koşuyor.

## 7. Rollback

Her faz ayrı commit. Sema değişiklikleri saf veri → `git revert <hash>` yeterli, şema/DB göçü yok.
Denetçi ve sözleşme yeni dosya; silinirse eski davranışa dönülür. ERP'ye **hiçbir yazma yok**
(`sema_kolon_cek.py` salt-okuma `sys.columns`).
