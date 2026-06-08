# Oturum Protokolü

_Her Claude oturumunun başı / ortası / sonu ritüelleri. Bu kural evrensel — her projede aynı._

## Neden bu dosya var

Deneyim: SessionStart hook bazen fire etmeyebiliyor (Cowork, farklı başlatma yolları). Daha kötüsü, fire ettiğinde Claude "çıktıyı context'te gördüm, hook çalıştı, yeterli" varsayımı yapıp `bash` ile tekrar çalıştırmayı atlıyor. O varsayım **iki ayrı hata** üretti: stale context + yanlış cevap. Kural bu sebeple **koşulsuz** hale getirildi.

## Oturum Başı — İlk yanıttan önce ZORUNLU

### Adım 1 — Hook'u KOŞULSUZ çalıştır

```bash
bash .claude/hooks/session-start.sh
```

**Her oturumda, istisnasız.** Context'te hook çıktısı görünüyor olsa bile tekrar çalıştır. Fresh çıktı context'tekinden farklı olabilir, context stale olabilir. **"Hook fire etti, atla" varsayımı yasak.**

Çıktı: son 3 gün commit'ler, uncommitted sayısı, 15-eşik uyarısı, aktif TODO başlıkları, son journal'ın son 40 satırı.

### Adım 2 — Son 2 journal dosyasını oku

```bash
ls -t docs/journal/*.md | head -2
```

Her ikisini de `Read` et. Özellikle bak:
- **Tamamlananlar** — son oturumda ne bitti
- **Yarım kalan işler** — nereden devam edilecek
- **Düzeltme notları** — tekrarlanmaması gereken hata

### Adım 3 — TODO.md aktif öncelikleri oku

`TODO.md` → **"BIRLESIK ONCELIK SIRASI"** bölümü. En az Faz 0 (bugün) + Faz 1'in ilk 3 maddesi. Aktif bug başlıkları.

### Adım 4 — Uncommitted durumu bil

`git status --porcelain | wc -l` — 15 üstüyse **yeni iş yasak**, önce commit-split.

### Kullanıcıya cevap

Yukarıdaki 4 adım **sessizce** yapılır. Kullanıcıya "şunu okudum şunu okudum" demeye gerek yok. Cevap bu okumalara dayanır, hafızaya veya context'teki hook çıktısına değil.

---

## Oturum Ortası

### 15 dosya eşiği
`git status` ile uncommitted > 15 → **yeni iş yasak**, önce commit-discipline kurallarına göre böl (commit-splitter subagent çağır).

### 3 paralel feature eşiği
Aynı anda 3'ten fazla feature branch açıksa birini bitirmeden yenisine geçme. Context kayar, bağlam dağılır.

### Kural değişikliği → dosyaya yaz
Kullanıcı yeni bir kural söylüyorsa konuşmada kalmaz, hemen ilgili `.claude/rules/*.md` dosyasına eklenir. "Aklında tut" demez — konuşma hafızasından kural çekilmez.

### Mimari karar → ADR
Mimari karar alındıysa `docs/ADR/NNN-konu.md` yaz (veya en azından TODO'ya "ADR-X yaz" kaydı düş).

---

## Oturum Sonu

### Tetikler
Kullanıcı "iyi geceler" / "handoff" / "kaydet ve kapat" / "/handoff" / "devam edeceğiz" → `.claude/skills/session-handoff/SKILL.md` devreye girer.

### Ne yapar
`docs/journal/YYYY-MM-DD.md`'ye append eder:
- Ana konu, tamamlananlar (dosya:line referanslı), build/test durumu, commit durumu, yarım kalan işler, kararlar, dikkat edilmesi gerekenler, yarına başlangıç noktası.

### CLAUDE.md'ye session log yazma
Session log **CLAUDE.md'ye yazılmaz** (200 satır eşiği + 3 katman ayrımı kuralı). Sadece journal'a.

### Commit kararı
Skill commit **etmez**. Kullanıcı açıkça isteyene kadar commit yok.

---

## Ritüel atlandığında

1. **Kabul et.** "Hook fire etmedi" / "context'te vardı" mazeret değil — elle okuma sorumluluğu vardır.
2. **Anında kapat.** Hook'u manuel çalıştır, journal'i oku, TODO'yu gözden geçir.
3. **Önlemini dosyaya yaz.** Aynı tür hata tekrar olmasın diye kural güçlendir (bu dosya örneği).
4. **Journal'a süreç notu düş.** "Süreç hatası: X atladı. Önlem: Y eklendi."

---

## İlişkili Dosyalar

- `docs/CONTEXT_MANAGEMENT.md` — bağlam yönetimi anayasası (ilkeler bütünü).
- `.claude/hooks/session-start.sh` — oturum başı bilgi toplayıcı.
- `.claude/skills/session-handoff/SKILL.md` — oturum sonu journal yazar.
- `.claude/rules/commit-discipline.md` — 15 dosya eşiği, branch-per-ask.
- `docs/journal/` — tarihli oturum kayıtları.
