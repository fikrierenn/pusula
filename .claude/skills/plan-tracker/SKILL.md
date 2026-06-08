---
name: plan-tracker
description: TodoWrite in-session durumuyla `TODO.md` dosyasini es zamanli senkronda tutar. Cok adimli bir is planlandiginda maddeleri TODO.md'ye kalici yazar; her is bitince TODO.md'de `[ ]` -> `✅` + commit hash ile isaretler. Kullanici "planla", "todo guncelle", "bu isleri kaydet" dediginde veya uzun plan + implementation akisi basladiginda devreye gir. TodoWrite alternatifi DEGIL, yardimcisidir — ikisi her zaman birlikte guncellenir.
allowed-tools: Read, Edit, Write, Bash, Grep
user-invocable: true
model: inherit
---

# plan-tracker Skill

## Amac

TodoWrite tool'u **in-session gecici** durum tutar: `/clear`, oturum sonu, compact sonrasi kaybolur. `TODO.md` **kalici** ama elle guncellemek zorunlu — Claude yaparken unutur.

Bu skill iki durumu bir birine bagli tutar:
- Plan yapilirken (3+ adim): hem TodoWrite'a yaz, hem TODO.md'ye.
- Adim bitince: hem TodoWrite'da completed, hem TODO.md'de `✅` + commit hash.
- Oturum basinda: TODO.md'deki aktif (`[ ]`) maddeleri TodoWrite'a geri yukle.

## Ne zaman tetikle

**Devreye gir:**
- Kullanici 3+ adimli bir plan tanimladiginda ("onem sirasina gore devam", "once X sonra Y sonra Z")
- Bir maddeyi tamamlaydiginda (commit sonrasi)
- Oturum basinda ("gunaydin", "nerede kaldik" — SessionStart hook zaten TODO.md'yi enjekte ediyor ama aktif maddeleri TodoWrite'a aktar)

**Devreye girme:**
- Tek adimli trivial is ("bu dosyayi duzelt")
- Soru-cevap akisi
- Kullanici acikca "sadece TodoWrite kullan, dosyaya yazma" dediginde

## Dosya Konumu

Birincil: proje kokunde `TODO.md`. Iki ana bolum:

```markdown
## Devam eden isler (aktif)

### BIRLESIK ONCELIK SIRASI
#### FAZ 0 — ... / FAZ 1 — ... / FAZ 2 — ... / FAZ 3 — ...

1. **ID · Kisa baslik** — (sure) — detay...
2. ...

## Yapilanlar (tamam)
- ✅ **ID · Baslik** — commit `<hash>` — (kisa ozet)
```

- Aktif madde: `1. **ID · Baslik** — ...`
- Tamam: `✅ **ID · Baslik** — commit `<hash>` — ...`
- Devam eden ama yarim: `⏳ **ID · Baslik** — kismi (ne yapildi) — (kalan)` veya yeni bir alt madde ekle.

## Adim Adim

### Mod 1: Plan yaz (baslangic)

Kullanici cok adimli plan verdi:

1. **TodoWrite** cagir: her madde icin `{ content, activeForm, status: "pending" }`. Ilk madde `in_progress`.
2. **TODO.md oku.** "Devam eden isler (aktif)" bolumunu bul.
3. **Yeni maddeleri ekle** uygun faza. ID ver:
   - Guvenlik: `G-NN`
   - Mimari: `M-NN`
   - Feature: `F-NN`
   - Bug: `B-NN`
   - Nondeterministic: kullanıcıya sor, yoksa oturum-lokal sira (`T-01`, `T-02`).
4. Format: `NN. **<ID> · <Baslik>** — (sure) — <kisa detay>`
5. TODO.md'yi **commit etme** (skill sadece yazar, commit kullanici karari).

### Mod 2: Madde tamamla (commit sonrasi)

Bir madde tamamlandi + commit edildi:

1. **TodoWrite** guncelle: o maddeyi `completed` yap.
2. **Commit hash al:** `git rev-parse --short HEAD`.
3. **TODO.md'de bul:** madde satiri (ID ile grep).
4. **Satiri degistir:** 
   - `- [ ] **<ID> · ...**` veya `NN. **<ID> · ...**` -> `✅ **<ID> · <Baslik>** — commit \`<hash>\` — <kisa ozet>`
   - Aktif listede kaldir, "Yapilanlar (tamam)" veya ilgili faz bolumunun basina tasi.
   - **Alternatif (tarihsel):** Aktif listede birakip sadece `✅` + hash ekleme daha az rearrange gerektirir. Tercih ilk seferki stil ile devam.
5. Next `pending` TodoWrite maddesini `in_progress` yap.

### Mod 3: Yarim kaldi (oturum sonu / ara)

- TodoWrite `in_progress` → kal (sessiz).
- TODO.md'de madde `⏳` emoji ile isaretle + mevcut durum: `⏳ **<ID> · <Baslik>** — kismi yapildi: <ne bitti>. Kalan: <ne kaldi>`.

### Mod 4: Oturum basinda geri yukle

SessionStart hook TODO.md'yi zaten context'e enjekte ediyor. Ek olarak:

1. `TODO.md` "Devam eden isler (aktif)" bolumunu oku.
2. Acik maddeleri (`[ ]` veya `⏳`) TodoWrite'a yukle, ilkini `in_progress` yap.
3. Bu sessizce yapilir (user'a raporlama gerek yok).

## Kurallar

1. **TodoWrite ve TODO.md birbirinden kopuk kalmaz.** Biri guncellenince digeri de.
2. **Trivial is icin skill'i cagirma.** Tek dosya fix, soru-cevap, aciklama → sadece TodoWrite yeter (veya o da yeterli degil).
3. **ID tutarliligi:** TODO.md'de zaten `G-01`, `M-02` gibi ID'ler kullaniliyorsa yeni madde eklerken tip prefix + sonraki numara.
4. **Commit hash eklemek:** madde tamamen bittiginde zorunlu — 6 ay sonra TODO.md'den `git show <hash>` ile detaya ulasilabilir.
5. **Commit etme:** skill TODO.md'yi commit etmez. Kullanici "todo commit'le" dedginde veya bir sonraki feature commit'iyle birlikte gider.
6. **Faz kayma:** madde kapanirken oldugu fazda kalir (Faz 0'da baslamis is, Faz 0'da ✅). Yeni maddeler "aktif plan" fazina yazilir.

## Ornek Akis

**Kullanici:** "Once M-02 kalan duzeltmelerini yap, sonra M-03 Faz A, sonra M-04 testleri."

**Skill (Mod 1):**
- TodoWrite: 3 madde, `{ M-02 kalan: in_progress, M-03 Faz A: pending, M-04 tests: pending }`.
- TODO.md: her 3 madde zaten aktif listede mi kontrol et. Yoksa faz altina ekle.
- Sil yerine yeniden duzenle: Faz 1 altinda siraya koy.

**Implementation + commit:**
- M-02 bitti, `git log -1` → hash `b6ff43a`.
- Skill (Mod 2):
  - TodoWrite: M-02 `completed`, M-03 `in_progress`.
  - TODO.md: `- M-02 · Exception sanitize` -> `✅ **M-02 · Exception sanitize** — commit `b6ff43a` — 7 leak temizlendi`.

**Oturum bitti, M-04 yarim:**
- Skill (Mod 3):
  - TodoWrite: M-04 kal `in_progress`.
  - TODO.md: `⏳ **M-04 · Unit tests** — DashboardRendererTests yazildi (3/5), UserDataFilter regex edge test kaldi, UserRole sync test kaldi`.

**Yeni oturum "gunaydin":**
- SessionStart hook TODO.md'yi enjekte eder.
- Skill (Mod 4): `⏳` ve `[ ]` maddeleri TodoWrite'a yukle, `⏳` olan `in_progress`.

## Iliskili Dosyalar

- `TODO.md` (proje koku) — kalici plan.
- `docs/journal/YYYY-MM-DD.md` (session-handoff skill) — gunluk ozet.
- `.claude/rules/commit-discipline.md` — TODO.md commit kurallari (skill TODO.md'yi commit etmez).
- `.claude/rules/session-memory.md` — bagalm disiplini.

## TODO.md Ilk Kurulum Sablonu

Eger TODO.md yoksa ya da format eksikse skill sablon uygular:

```markdown
# TODO — {{ProjectName}}

## Yapilanlar (tamam)
_(commit'lendikce buraya — `✅ <ID> · <baslik> — commit \`<hash>\` — <ozet>`)_

## Devam eden isler (aktif)

### BIRLESIK ONCELIK SIRASI
#### FAZ 0 — Bugun (blocker)
- [ ] ...
#### FAZ 1 — Bu hafta
- [ ] ...
#### FAZ 2 — Bu ay
- [ ] ...
#### FAZ 3 — Ceyrek
- [ ] ...
```
