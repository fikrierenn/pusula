---
name: yetenek-uret
description: BKM çatısına yeni yetenek (skill / agent / hook / rule) SİSTEMATİK üretir veya mevcut olanı GÜNCELLER. footprint-ladder en-dar-basamak seçimi + convention-uyumlu scaffold + kayıt (hook→settings.json) + test + onay. "yeni skill yap", "bu skill'i güncelle/iyileştir", "X için agent", "hook ekle/oluştur", "yetenek üret", "kendini geliştir", "çatıyı geliştir", "/yetenek-uret" denildiğinde tetiklenir. İNSAN-TETİKLİ (otonom daemon DEĞİL). Her üretim/güncelleme kullanıcı onayı + git-revert'lenebilir.
---

# Yetenek Üret — Çatı Self-Development (insan-tetikli)

> Hermes "self-improvement" fikrinin BKM-güvenli hali. Otonom DEĞİL: Claude çağrı-bağımlı, BKM daemon/cron reddetti (plan-12 §5). Bu skill **sen tetikleyince** yeni yeteneği DOĞRU basamakta, convention-uyumlu, kayıtlı ve test'li üretir/günceller. Üçlü döngünün "üret/güncelle" ayağı: `/learn` (sorun→kural) + **yetenek-uret** (üret/güncelle) + `consolidate-sema` (bakım/budama).

## 0. İlk Soru — Gerçekten Yeni Yüzey mi? (footprint-ladder ZORUNLU)

Üretmeden ÖNCE merdiveni aşağıdan sor (`.claude/rules/footprint-ladder.md`):
1. Mevcut script/rule/skill'i **genişletmek** çözüyor mu? → yeni dosya AÇMA.
2. Çözmüyorsa: skill < rule < agent < hook < sema-entity < dashboard sayfası — EN DAR basamak.
3. Şüphede → kullanıcıya sor: "Bu yeni X mı, yoksa mevcut Y'yi genişletme mi?"

**Anti-pattern:** her ihtiyaca yeni skill/agent refleksi. Tek-kullanımlık iş → inline çöz.

## 1. İhtiyaç Netleştir
- Ne tetikleyecek? (kullanıcı ifadesi / olay / dosya türü)
- Tek seferlik mi tekrar eden mi? (tek seferlik → skill DEĞİL)
- Hangi tip: **skill** (tekrarlı iş akışı) · **agent** (özelleşmiş salt-okuma/üretim alt-iş) · **hook** (mekanik olay-tetikli enforcement) · **rule** (kalıcı davranış).

## 2. Tipe Göre Scaffold

### Skill → `.claude/skills/<ad>/SKILL.md`
- YAML frontmatter: `name` (kebab-case), `description` (NE yaptığı + TETİKLEYİCİ ifadeler — recall için kritik).
- Gövde: amaç, adımlar, anti-pattern, İlişkili. Türkçe (turkish-ui), kısa (response-style).
- Tetik ifadelerini description'a AÇIK yaz (skill bunlarla bulunur).

### Agent → `.claude/agents/<ad>.md`
- Frontmatter: `name`, `description` (ne zaman çağrılır), `tools` (salt-okuma denetçi → Edit/Write YOK — agent-usage §5).
- **Model tier** (agent-usage §2): haiku (mekanik/tarama) · sonnet (analiz/review) · opus (derin/yüksek-risk). Bilinçli seç, yaz.
- Rol: leaf (varsayılan, alt-ajan açamaz) — agent-usage §7.
- Prompt disiplini: Görev / Scope / YAPMAYACAKLARIN / Done / Raporla.

### Hook → `.claude/hooks/<ad>.sh` + `.claude/settings.json` WIRE
- Event seç: SessionStart (bağlam enjekte) · PreToolUse (blok/gate) · PostToolUse · PreCompact · Stop (dikkat: her turda fire, gürültü).
- Script: `set -e`, `cd "$(git rev-parse --show-toplevel)"`, stdin JSON (jq + sed fallback), exit kodları (0=geç, 2=blok+stderr).
- **BKM-adapte ZORUNLU** (jenerik şablonu körü körüne wire ETME): BKM'de print()=CLI legit, DateTime.Now=yerel display → BLOK değil UYAR. Güvenlik (şifre/ex.Message/bare-except) = BLOK.
- settings.json'a ekle (event matcher). **Wire etmeden hook ölüdür** (pre-commit-antipattern bu yüzden aylarca dormant kaldı).

### Rule → `.claude/rules/<konu>.md`
- `paths:` YOK (compact-survival — semantic-layer/session-memory).
- Başına katman etiketi: "Rule katmanı: core (her oturum) / on-demand (konu tetiklenince)".
- core ise CLAUDE.md İçerik Haritası + ilişkili rule'lara çapraz-ref.

## 3. Kayıt + Keşfedilebilirlik
- Hook → settings.json (yoksa fiilen çalışmaz).
- Skill/agent → otomatik keşfedilir (dosya yeterli) ama description tetikleyici-zengin olmalı.
- Yeni rule core ise CLAUDE.md'ye 1-satır pointer.
- agent-usage.md iş→ajan matrisine yeni agent satırı.

## 4. Test (test-discipline)
- Hook: `bash -n` syntax + davranış (git-commit-dışı→exit 0, hedef olay→beklenen).
- Kod üreten agent/skill ait olduğu stack'te build/test.
- Skill/rule: tetik ifadesiyle bir kuru-koşu (doğru yükleniyor mu).

## 5. Mevcut Yeteneği GÜNCELLE (self-update)
- Tetik: "bu skill eksik/yanlış", curator-check stale bulgusu, kullanıcı feedback.
- Aynı workflow: oku → eksiği bul → minimal düzelt (surgical, coding-discipline) → test → onay.
- Çelişen/eskiyen kural → düzelt veya `note: süperseded` (semantic-layer çelişki kuralı). Silme yerine güncelle.

## 6. Onay + Commit
- Üretim/güncelleme **kullanıcı onayı** olmadan kalıcılaşmaz (footprint maliyeti).
- Commit: `feat(crossproject): yeni <tip> <ad>` veya `chore(crossproject): <ad> güncelle`. git-revert'lenebilir.
- TODO/journal'a not (ne eklendi, neden).

## Guardrails
- ❌ Otonom (onaysız) üretim/değiştirme YOK.
- ❌ Aynı işi yapan ikinci skill/agent (consolidate-sema dup tespit eder).
- ❌ Jenerik hook'u BKM-adapte etmeden wire.
- ✅ En dar basamak, convention-uyumlu, test'li, geri-alınabilir.

## İlişkili
- `.claude/rules/footprint-ladder.md` — basamak seçimi (ZORUNLU ilk adım).
- `.claude/rules/agent-usage.md` — agent model/rol/prompt.
- `.claude/commands/learn.md` — sorun→kural (bu skill'in kardeşi: çıkarım).
- `.claude/skills/consolidate-sema/SKILL.md` — bakım/budama (döngünün 3. ayağı).
- `.claude/settings.json` — hook kayıt yeri.
