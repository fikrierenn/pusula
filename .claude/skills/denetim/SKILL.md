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
Kapsama göre İLGİLİ denetçileri seç (hepsini her zaman değil — değişen alana göre). İş → ajan → model:
| Alan | Ajan/Araç | Model | Tetik |
|---|---|---|---|
| SQL doğruluk/konvansiyon (IsValid/COLLATE/tarih/stkKod-barkod/iade-netleme/KDV) | `sql-denetci` ✅ | sonnet | SQL değişti (dashboard `*.cs` gömülü, `sorgular/**`) |
| Python script kalite (injection/sızıntı/sessiz-hata/sema-uyum) | `python-reviewer` ✅ | sonnet | `scripts/**/*.py` değişti |
| Sessiz hata / yutulmuş / sessiz fallback / veri maskeleme | `silent-failure-hunter` ✅ | opus | Yeni servis/rapor, finansal yol |
| Güvenlik (auth/injection/secret/XSS/CSRF/IDOR/Process) | `general-purpose` | opus | auth/endpoint/dış-süreç/secret değişti |
| Kural-uyum kod review | `code-reviewer` (yoksa `general-purpose`) | sonnet | büyük kod değişimi |

**Mevcut proje denetçileri (✅):** `sql-denetci`, `python-reviewer`, `silent-failure-hunter`. Güvenlik/kod-review için dedicated agent YOK → `general-purpose` + uygun model (agent-usage §2).

Her denetçiye **ZORUNLU standart prompt kuyruğu:**
- Scope: <net dosya listesi>
- YAPMAYACAKLARIN: kod değiştirme, scope dışı, spekülatif. Kanıtlı bulgu + dosya:satır.
- **Standart çıktı şeması (bulgu paketi satırı):** `| SEVERITY (KRİTİK/YÜKSEK/ORTA/DÜŞÜK) | dosya:satır | sorun | öneri |`. Temizse "temiz" de.

### 2.5 Tamamlayıcı denetimler (kapsama göre — bütünlük için)
Kod-ajan denetçilerinin DIŞINDA, denetim ailesinin geri kalanı:
- **Sema denetimi** → `consolidate-sema` skill (dry-run): stale (`last_verified+ttl<bugün`) + dar/çakışan sema kaydı + eski TODO. Şema/sema değişen oturumda KOŞULSUZ (curator). Çıktı `docs/curator/REPORT-*.md` → bulgu paketine "sema" satırları.
- **Mekanik denetim** → pre-commit antipattern hook (`.claude/hooks/`): `DateTime.Now`/`async void`/`new HttpClient()`/`catch{}`/hardcode-secret. Commit'te otomatik; denetimde elle de tetiklenebilir.
- **Plan/TODO doğrulama** → `todo-verification.md` akışı: "kapalı" iddialarını file:line ile kanıtla (stale madde temizliği).

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

## Denetim Ailesi (tamamı — bu skill orkestre eder)
- **Kod/SQL/Python ajanları:** `.claude/agents/sql-denetci.md`, `python-reviewer.md`, `silent-failure-hunter.md` (salt-okuma, raporlar)
- **Güvenlik/kod-review:** dedicated agent yok → `general-purpose` + opus/sonnet (agent-usage §2)
- **Sema curator:** `consolidate-sema` skill (stale/dar/çakışan sema + eski TODO, dry-run + onay)
- **Mekanik:** pre-commit antipattern hook (`.claude/hooks/`) — commit-time + elle
- **Kalıcılaştırma:** `learn` skill — çözülen denetim bulgusu → kalıcı kural/sema

## İlişkili
- `.claude/rules/agent-usage.md` — model seçimi, max_concurrent=3, salt-okuma, leaf/orchestrator
- `.claude/rules/before-major-change.md` — Fact-Force doğrulama (KIRMIZI kanıtla)
- `.claude/rules/todo-verification.md` — kanıtsız aksiyon yasak
- `.claude/rules/security-principles.md` — güvenlik denetim ölçütleri
