---
name: session-handoff
description: Oturum sonu ozet yazar. Bugun yapilanlari, build durumunu, yarim kalan islari, yarina baslangic noktasini docs/journal/YYYY-MM-DD.md dosyasina yazar VE TODO.md'yi senkronlar (tamamlananlari isaretler, yeni kesfedilen islari ekler). Yazim sonunda journal+TODO'yu tek commit'te atar. Kullanici "handoff", "oturum sonu", "iyi geceler", "kaydet ve kapat", "gunaydin ozet" gibi ifadeler kullandiginda veya /handoff calistirildiginda devreye gir.
allowed-tools: Read, Edit, Write, Bash, Grep, Glob
user-invocable: true
model: inherit
---

# Oturum Devir Skill'i

## Amac
Her oturum sonunda gun icinde olanlari kalici bir journal dosyasina yazar ve journal'i otomatik commit eder.

## Kaynak Dosya

`docs/journal/YYYY-MM-DD.md` — bugunun gunlugu.

## Cikti Sablonu

```markdown
# Oturum Gunlugu — YYYY-MM-DD

## Ana Konu
<2-4 cumle>

## Tamamlananlar
### <Kategori 1>
- Madde (dosya:line)

## Build / Test Durumu
- Build: yesil / kirmizi / calistirilmadi
- Test: X yesil, Y kirmizi
- Smoke test: yapildi / yapilmadi

## Commit Durumu
- Uncommitted: N
- Yeni commit'ler: ...

## Yarim Kalan / Yarin'a
### Üst öncelik
- ...

## İşe YARAMAYANLAR (denenen ama başarısız yaklaşımlar)
> ECC save-session "What Did NOT Work" pattern'i. Aynı çıkmaz sokağa yarın tekrar girilmesin.
- <yaklaşım> → <neden başarısız> (örn. "stkKod=BarcodeNo join → Oyuncak kategorisi sessizce kayıp")

## Kararlar
### Reddedilenler
- ~~A~~ — sebep
- B seçildi — gerekçe

## Konuşulan ek konular (parked / context)
### <Konu — parked: neden>

### Kullanıcı feedback verbatim
> "alıntı" — konteks

## Dikkat Edilmesi Gerekenler

## Yarina Baslangic Noktasi
1. ...

## Yardımcı Dosyalar
### Yeni / Değişen
- `path/to/file` — ne değişti
```

## Adim Adim

### Adim 1 — Bilgi Topla
```bash
date +%Y-%m-%d
git status --porcelain | wc -l
git log --since=midnight --oneline
git diff --name-only HEAD --diff-filter=AM
```

### Adim 2 — Journal Kontrol
```bash
# Proje alt-dizini ZORUNLU (multi-project: bkm/yonetiq). BKM bu repo'nun aktif projesi.
JOURNAL="docs/journal/bkm/$(date +%Y-%m-%d).md"
mkdir -p docs/journal/bkm
```

### Adim 3 — Konusma Baglamini DERIN OKU

KRİTİK: "Ne yazildi" + "ne tartisildi + nasil karar verildi".

- **3a. Parked öğeler** — "büyüdükçe", "şimdilik gerek yok"
- **3b. Reddedilen alternatifler** — A/B/C tartışıldı, hangi seçildi NEDEN
- **3c. Scope creep / pivot kararları**
- **3d. Kullanıcı verbatim quotes**
- **3e. Domain knowledge / sözlük**
- **3f. UX/UI saga'ları**
- **3g. Bug fix kararları (kalıcı kural)**
- **3h. İlişkili dosyalar (yeni + değişen)**
- **3i. "Hatırlatma" / "Dikkat" notları**

Hacim eşiği: 3+ saat veya 20+ dosya değişti → DETAYLI yaz.

### Adim 4 — Journal Dosyasina Yaz
- Dosya yoksa: şablondan yeni.
- Dosya varsa: `---` + `## Oturum 2`.

### Adim 4.5 — TODO.md Senkronu (ZORUNLU)

**S2 — Stale-pass (18.06 sertleştirme — her handoff'ta zorunlu):**
Önce done-but-open tara:
```bash
# done-but-[ ] adayları: bu oturumda commit'lenen ID'ler hâlâ [ ] mi?
git log --since=midnight --oneline | grep -oE '[A-Z]-[0-9]+|HK-[0-9]+|B-[0-9]+|R-[0-9]+' | sort -u
grep -n "^\- \[ \]" TODO.md | grep -E "<yukarıdaki ID'ler>"
```
Eşleşen → anında `[x]` + hash. Tüm `[ ]` madde sayısını journal'a yaz (stale trend takibi).

5 zorunlu adım:

1. TODO.md'yi oku.
2. Tamamlananları işaretle: `- [x] ~~...~~ — ✅ commit abc1234`.
3. Yeni keşfedilen işler ekle (Faz 1/2/3/Backlog'a, ID süreklilik).
4. Kararları işlet:
   - Mimari → "ADR yaz: <konu>" maddesi
   - Kural → ".claude/rules/<konu>.md yaz" maddesi
   - Backlog değişimi → sıra güncelle
5. Yapılanlar özeti: `### YYYY-MM-DD — <ana konu>` 3-5 madde.

Önemli kısıtlar:
- TODO.md formatı değişmesin (Faz 0/1/2/3 + Backlog).
- 400+ satır → bildirim ver, eski kayıtlar arşive.
- Aynı konu iki yerde olmasın.

### Adim 4.6 — Curator-check (plan-12 WS-1 — inactivity-triggered, cron YOK)

Son curator-check üstünden **≥7 gün** geçtiyse **KOŞULSUZ `consolidate-sema` dry-run çalıştır** (handoff'un parçası — atlanmaz):

1. `consolidate-sema` skill'ini dry-run modda çağır → `docs/curator/REPORT-YYYY-MM-DD.md` üretir (stale sema + dar/çakışan + eski TODO).
2. Raporun özetini + "önerilen aksiyonlar" listesini kullanıcıya göster.
3. **OTOMATİK aksiyon YOK** — archive/birleştirme/[x] yalnızca kullanıcı onayı (curator hard-rule: stale=bayrak). Onaylarsa consolidate-sema Mod-2 uygular.
4. Son curator-check tarihini journal'a not düş (`> curator-check: YYYY-MM-DD`).

**<7 gün ise:** hafif yüzey — `status: teyit bekliyor` + `SÜPERSEDED` duran sema kaydı + ≥30g açık TODO sayısını 1 satır göster (tam dry-run gerekmez).

> Tarih kaynağı: en son journal'da `curator-check:` satırı; yoksa ilk çalıştırma sayılır.

### Adim 5 — Journal + TODO OTOMATIK commit

```bash
JOURNAL="docs/journal/bkm/$(date +%Y-%m-%d).md"
TODO="TODO.md"
STAGED=""

for f in "$JOURNAL" "$TODO"; do
  if ! git diff --quiet -- "$f" 2>/dev/null || git ls-files --others --exclude-standard -- "$f" | grep -q .; then
    git add "$f"
    STAGED="$STAGED $f"
  fi
done

if [ -n "$STAGED" ]; then
  git commit -m "docs: $(date +%Y-%m-%d) handoff + TODO sync"
fi
```

Sadece bu iki dosya. `git add .` / `-A` yasak.

### Adim 5.5 — Keşif SQL + sema kontrolü (ZORUNLU — semantic-layer.md ikiz yükümlülük)

Oturumda MCP `sql_query` ile anlamlı keşif/analiz yapıldıysa:
1. **sema/ güncel mi?** Yeni köprü/kod/metrik `sema/*.yaml`'a yazıldı mı (yoksa `sema-ogren`).
2. **SQL arşivlendi mi?** Keşif sorgusu `sorgular/YYYY-MM-DD-<konu>.sql`'e kaydedildi mi (yoksa kaydet).
3. Eksikse journal "Yarına" + TODO'ya "arşivlenecek SQL: <konu>" maddesi düş.

> Bu adım `.claude/rules/semantic-layer.md` § Keşif/Analiz SQL'i Arşivle kuralını handoff'ta zorlar — sık atlanıyordu.

### Adim 6 — Ozet Goster

```
Oturum kaydedildi: docs/journal/2026-06-03.md
- Tamamlanan: 4 madde
- Yarım kalan: 2 madde
- Commit: abc1234 docs: 2026-06-03 handoff + TODO sync
- Uncommitted: N dosya (15 eşiğin altında, iyi)
- Yarına başlangıç: <ilk adım>
```

## Tetikleyiciler

- "iyi geceler" → otomatik
- "/handoff" → açık
- "devam edeceğiz" → kaydet
- "günaydın" → ters yön: en son journal'i oku ve "nerede kaldık?" özet (commit yok)

## Dikkat

1. Hiç journal yoksa: docs/journal/ oluştur.
2. Auto-commit SADECE journal + TODO.
3. Başka dosya uncommitted ise dokunma.
4. CLAUDE.md'ye session log eklenmemeli.
5. Aynı gün ikinci çağrı: `## Oturum 2` ekle.
6. Türkçe yaz, UTF-8.

### İteratif-Merge & Anchor (plan-12 WS-6 — Hermes context-compression uyarlaması)

7. **İteratif-merge, sıfırdan değil.** Aynı gün 2. oturum → önceki oturum bloğunu KORU, üstüne **delta** ekle (`## Oturum 2`). Önceki özeti yeniden yazma/budama — yalnız yeni olanı ekle (Hermes iterative-summary: bilgi kaybını önler).
8. **Anchor — budanmaz bölüm.** "Yarına Başlangıç Noktası" + "Yarım Kalan" + son kullanıcı talebi ASLA özetlenmez/budanmaz — uzun günde bile birebir korunur (Hermes tail-anchor: aktif görev kaybolmasın).
9. **Anti-thrash.** Son oturumda <%10 yeni içerik (1-2 ufak commit, kayda değer karar yok) varsa AYRI `## Oturum N` bloğu açma — mevcut son bloğa 1-2 satır not düş. Gürültü azalt.

## İlişkili Dosyalar

- `.claude/hooks/session-start.sh`
- `.claude/hooks/post-commit-journal.sh`
- `.claude/rules/commit-discipline.md`
- `docs/CONTEXT_MANAGEMENT.md`
