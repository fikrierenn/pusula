# denetim — Çok-Ajan Kod/SQL/Güvenlik Denetimi → Tek Bulgu Paketi

TestSprite "consistent failure bundle + agent install skill" kalıbının lokal/gizli uyarlaması (17.06). Mevcut denetçi ajanları **standart prompt + standart çıktı şeması** ile koşturur, bulguları **tek bulgu paketi**nde toplar, KIRMIZI'ları KANIT ile doğrular (false-positive eler), düzeltilebilirleri uygular, çözülen dersleri `/learn`'e besler. Veri dışarı çıkmaz (TestSprite cloud aksine).

## Ne zaman tetiklenir
- "denetle", "audit", "full scan kontrol", "kodu/sql'i denetle", "/denetim"
- Büyük değişiklik sonrası (yeni servis, auth, şema, çok-commit oturum)
- Oturum sonu kalite kapısı (handoff öncesi opsiyonel)

## Adımlar

### 1. Kapsam belirle
Değişen dosyaları çıkar (`git diff --name-only`, bu oturum commit'leri) + ilgili alanlar. Kapsamı denetçilere böl.

### 2. Denetçileri paralel koştur (max 3 eşzamanlı — agent-usage; dalga dalga)
İş → ajan → model (agent-usage matrisi):
| Alan | Ajan | Model |
|---|---|---|
| SQL doğruluk/konvansiyon | `sql-denetci` | sonnet |
| Python script kalite | `python-reviewer` | sonnet |
| Sessiz hata / yutulmuş | `silent-failure-hunter` | opus |
| Güvenlik (auth/injection/secret/XSS/CSRF) | `general-purpose` | opus |
| Kural-uyum kod | `code-reviewer` (varsa) | sonnet |

Her denetçiye **ZORUNLU standart prompt kuyruğu:**
- Scope: <net dosya listesi>
- YAPMAYACAKLARIN: kod değiştirme, scope dışı, spekülatif. Kanıtlı bulgu + dosya:satır.
- **Standart çıktı şeması (bulgu paketi satırı):** `| SEVERITY (KRİTİK/YÜKSEK/ORTA/DÜŞÜK) | dosya:satır | sorun | öneri |`. Temizse "temiz" de.

### 3. Sentez → tek Bulgu Paketi
Tüm ajan çıktılarını TEK tabloya birleştir:

```
| # | SEVERITY | Alan | dosya:satır | Sorun | DURUM |
```
DURUM: `açık` / `doğrulandı` / `false-positive` / `düzeltildi` / `ertelendi`.

### 4. KIRMIZI/YÜKSEK doğrula — KANITSIZ DÜZELTME YASAK (kritik)
- Her KIRMIZI bulguyu **canlı kanıtla** (MCP sorgu / kod oku / before-major-change Fact-Force). Doğrulanmadan düzeltme YOK.
- **Ders (17.06):** sql-denetci `irs.eTip=1`'i "alış" sandı (KIRMIZI) → 201-doğrulama: 1=Satış → **false-positive**. Düzeltseydim satış cirosunu silip marjı bozardım. Doğrulama = `todo-verification.md` + `before-major-change.md`.
- False-positive → DURUM işaretle, düzeltme.

### 5. Düzeltmeleri uygula (doğrulanmış + düşük-risk)
- Kesin/düşük-risk olanları uygula → DURUM=düzeltildi. Build/smoke.
- Doğrulama gerektiren / büyük olanları TODO bug-aday + DURUM=ertelendi.
- Kullanıcı-görünür/mimari → onay.

### 6. /learn besle + commit
- Çözülen tekrarlanabilir sorunlar → `/learn` (kalıcı kural/sema).
- Tek commit: `fix(<proje>): denetim bulguları — <özet>`. Commit mesajında false-positive notu.

## İlkeler
- **Salt-okuma denetçi** (Edit/Write yok) — düzeltme ana döngüde, kanıtla.
- **Standart şema** = tutarlı, izlenebilir, /learn'e beslenebilir (TestSprite "failure bundle" özü).
- **Lokal/gizli** — veri TestSprite gibi dışarı gitmez.
- **Kanıt > bulgu** — denetçi iddia eder, ana ajan doğrular (false-positive eler).

## İlişkili
- `.claude/agents/` — sql-denetci, python-reviewer, silent-failure-hunter
- `.claude/rules/agent-usage.md` — model seçimi, max_concurrent=3, salt-okuma
- `.claude/rules/before-major-change.md` — Fact-Force doğrulama
- `.claude/rules/todo-verification.md` — kanıtsız aksiyon yasak
- `.claude/commands/learn.md` (skill) — çözülen → kalıcı ders
