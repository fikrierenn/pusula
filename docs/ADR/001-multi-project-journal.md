# ADR-001 — Multi-Project Journal Yapısı

## Durum

`Kabul edildi`

## Tarih

2026-04-27

## Proje

`crossproject`

## Bağlam

`sqlserver-mcp-server` repo'su tek bir projeye değil, birden fazla SQL Server bağlantısına köprü kuran bir MCP server. ALLOWED_DATABASES = "BKM, Belinza, YonetIQ" — yani 3 farklı kurumsal projeye hizmet ediyor:

- **BKM Kitap** (kapsamlı içerik dolu — DerinSIS + EncoreMerkez + JOKER)
- **Belinza** (henüz boş)
- **YonetIQ** (henüz boş)

Buna ek olarak repo'nun kendisi (MCP server kodu, `.claude/` disiplini, infra) bir cross-project katman.

İlk session'larda `SESSION_LOG.md` tek bir kronolojik dosyaydı — proje ayrımı yoktu, BKM verisiyle MCP kod değişiklikleri iç içe geçmişti. Bu yapıda:
- Yeni oturum hangi projede çalışılacak belirsiz
- Commit scope'ları karışık
- Belinza/YonetIQ için yer ayrılmamış
- "Tek bir bilgi iki yerde durmasın" ilkesi (CONTEXT_MANAGEMENT İlke 1) ihlal edilmiş

## Karar

Journal yapısı **proje başına ayrı klasör** olacak:

```
docs/journal/
├── bkm/
│   ├── README.md
│   ├── YYYY-MM-DD.md
│   └── _archive-session-log.md
├── belinza/
│   └── README.md (boş başlangıç)
├── yonetiq/
│   └── README.md (boş başlangıç)
└── _crossproject/
    ├── README.md
    └── YYYY-MM-DD.md
```

Commit scope = proje adı:
- `feat(bkm): ...` → `docs/journal/bkm/`
- `chore(crossproject): ...` → `docs/journal/_crossproject/`
- `fix(mcp): ...` → MCP server kodu (cross-project altında değerlendirilebilir veya ayrı `mcp` scope)

`SessionStart` hook her proje klasörünün son journal'ını enjekte ediyor. `session-handoff` skill hangi projede çalışıldığını dosya pattern'inden tespit ediyor (`briefings/`, `sorgular/`, `docs/0[1-9]-` → bkm; `src/`, `package.json` → crossproject).

## Sebepler

- Multi-project repo gerçeği: 3 DB bağlantısı + cross-project infra.
- Proje ayrımı paralel oturumların çakışmasını **kısmen** çözüyor (farklı proje farklı dosya).
- Belinza ve YonetIQ için yer açık, içerik dolduğunda yapı hazır.
- Commit scope'ları net (`feat(bkm):` vs `feat(belinza):`).

## Alternatifler (Reddedilenler)

### A: Tek `docs/journal/YYYY-MM-DD.md`
**Reddetme sebebi:** Proje ayrımı yok. Multi-project yapı bilgi tabanını birbirine karıştırır.

### B: Tek `SESSION_LOG.md` (mevcut durum)
**Reddetme sebebi:** Tarih bazlı bile değil, kronolojik tek dosya. 200 satır eşiğini sürekli aşar, grep ile arama bile zor.

### C: Branch-per-project
**Reddetme sebebi:** Git geçmişi karmaşıklaşır, SaaS-grade ama overengineering. main üzerinde proje ayrımı dosya yapısı ile yeterli.

## Sonuçlar

### Olumlu
- Yeni proje eklemek kolay (`docs/journal/<yeniproje>/` aç).
- Hook ve skill multi-project aware.
- Commit scope disiplini doğal olarak gelir.
- Paralel oturumlar farklı projelerde çakışmaz.

### Olumsuz / Risk
- Aynı proje içinde paralel oturum hâlâ çakışabilir (bkz. ADR-002).
- TODO.md ortak — proje sayısı arttıkça karmaşıklaşır (bkz. ADR-002 önerisi: TODO/<proje>.md split).

### Bilinmeyen
- Belinza ve YonetIQ için kaç journal birikecek, ne hızda büyüyecek.
- Cross-project işlerin _crossproject/'ta ne kadar yer tutacağı.

## Uygulama

- [x] `docs/journal/<proje>/` klasörleri açıldı (4 proje).
- [x] `SESSION_LOG.md` parçalandı (6 tarihli dosya + arşiv).
- [x] `session-start.sh` hook her klasörün son journal'ını enjekte ediyor.
- [x] `post-commit-journal.sh` hook commit scope'una göre doğru klasöre yazıyor.
- [x] `session-handoff` skill proje tespiti yapıyor.
- [x] `commit-discipline.md` rule'da multi-project commit scope kuralı.

## İlişkili Dosyalar

- `.claude/rules/commit-discipline.md` — scope kuralları
- `.claude/skills/session-handoff/SKILL.md` — proje tespiti
- `.claude/hooks/session-start.sh` — multi-project enjeksiyon
- `.claude/hooks/post-commit-journal.sh` — scope-aware journal yazımı
- `docs/CONTEXT_MANAGEMENT.md` — § İlke 8 (Multi-Project Ayrımı)
- ADR-002 — Paralel oturum koruma (bu kararın açık eksikliğini ele alır)

## Referanslar

- Konuşma: `docs/journal/_crossproject/2026-04-27.md` (Oturum 1, Adaptasyon)
- TODO ID: `C-08` (mevcut docs/01-09'u `docs/projects/bkm/` altına taşı — ileri taşımalı)
