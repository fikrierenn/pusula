# Agent Kullanım Disiplini (Ana Ajan Delegasyonu)

_Ana ajanın işleri alt-ajanlara (subagent) NASIL dağıtacağını ve hangi model katmanını seçeceğini tanımlar. Amaç: doğru iş → doğru ajan → doğru model. `paths:` yok — compact sonrası survive._

## 1. Temel İlke

**`general-purpose`'u varsayılan yapma.** Her iş için en dar kapsamlı, en uygun özelleşmiş ajanı seç. Özel ajan yoksa `general-purpose` kullan **ama model'i işe göre `model` parametresiyle elle ata** — varsayılana bırakma.

## 2. Model Katmanı Seçimi (ZORUNLU farklılaştırma)

| Model | Ne zaman | Örnek iş |
|---|---|---|
| **haiku** | Mekanik, deterministik, düşük-muhakeme; çok sayıda hızlı tarama | dosya/sembol arama, build/test çalıştır, şema diff, commit-split, basit grep raporu |
| **sonnet** | Dengeli analiz + üretim; orta muhakeme | mimari blueprint, kod review (kural uyumu), web çok-kaynak tarama, orta karmaşık keşif |
| **opus** | Derin muhakeme, çok-adımlı, yüksek-risk, ince hatalı sonuç pahalı | güvenlik review, silent-failure avı, veri-doğruluğu denetimi, derin domain araştırması, mimari karar |

**Kural:** Bir Agent/Task çağrısında model'i bilinçli seç. Şüphedeysen göreve göre yukarı/aşağı kaydır; eşit harcama (her şeye opus / her şeye general-purpose) yasak.

## 3. İş → Ajan Matrisi (proje agent setine göre uyarla)

| İş türü | Tipik ajan | Model |
|---|---|---|
| "X nerede / Y referansı / keşif" | `code-explorer` | haiku |
| Yeni feature/modül mimari blueprint | `code-architect` | sonnet |
| Uncommitted'i commit'lere böl | `commit-splitter` | haiku |
| Güvenlik denetimi (injection/XSS/CSRF/IDOR/secret) | `security-reviewer` | opus |
| Silent failure / error handling denetimi | `silent-failure-hunter` | opus |
| Kural-uyum kod review | `code-reviewer` | sonnet |
| Build derle + hata/uyarı say | `build-validator` | haiku |
| Test çalıştır + raporla | `test-runner` | haiku |
| Hiçbiri uymuyor (genel çok-adımlı) | `general-purpose` | işe göre elle ata |

## 4. Paralellik ve Fan-out

- Bağımsız işleri **tek mesajda paralel** başlat (birden çok Agent çağrısı).
- Aynı türden çok sayıda hedef (N dosya/N modül) varsa: her birine ayrı dar-kapsamlı haiku/sonnet ajan; sonucu ana ajan sentezler.
- Büyük çok-fazlı orkestrasyon (onlarca ajan) sadece kullanıcı açıkça "workflow" derse veya ultracode açıksa.

## 5. Salt-Okuma Disiplini

- Araştırma/denetim ajanlarına **yazma tool'u verme** (Edit/Write yok). Denetçi/araştırmacı ajanlar read-only (+ gerekiyorsa Bash).
- "Raporla, çözme." Karar + uygulama ana döngüde kalır → kontrol kullanıcıda.

## 6. Sub-agent Prompt Disiplini

```
Görev: <net, tek paragraf>
Scope: <dosya listesi / modül>
YAPMAYACAKLARIN: Scope dışı dokunma. Fark ettiğin sorunu raporla, çözme.
Done tanımı: <ne dönünce bitmiş sayılır>
Raporla: <istenen çıktı format>
```

## İlişkili
- `.claude/rules/session-memory.md` — sub-agent prompt disiplini.
- Proje agent'ları: `.claude/agents/*.md`.
