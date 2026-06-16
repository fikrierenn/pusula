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
| **Tier 3 plan dokümanı (plans/NN-slug.md)** | `planner` ✅ | opus |
| Uncommitted'i commit'lere böl | `commit-splitter` ✅ | haiku |
| Güvenlik denetimi (injection/XSS/CSRF/IDOR/secret) | `security-reviewer` | opus |
| Silent failure / sessiz yanlış rakam denetimi | `silent-failure-hunter` ✅ | opus |
| Python rapor scripti review (pymssql/sema uyum) | `python-reviewer` ✅ | sonnet |
| Kural-uyum kod review | `code-reviewer` | sonnet |
| Build derle + hata/uyarı say | `build-validator` | haiku |
| Test çalıştır + raporla | `test-runner` | haiku |
| Hiçbiri uymuyor (genel çok-adımlı) | `general-purpose` | işe göre elle ata |

✅ = bu projede mevcut (`.claude/agents/`). Diğerleri şablon — gerekirse ekle.

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

## 7. Rol & Derinlik (Hermes delegation uyarlaması — plan-12 WS-4)

Ana ajan alt-ajan açarken **rol** atar; rol yetki ve derinliği sınırlar.

| Rol | Yetki | Kim |
|---|---|---|
| **leaf** (varsayılan) | Salt-işçi. Kendi alt-ajanını AÇAMAZ (delegate yok). Tek görev, izole bağlam. Araştırma/denetim ajanları yazma-tool'suz (§5). | `code-explorer`, `silent-failure-hunter`, `python-reviewer`, `Explore`, çoğu denetim ajanı |
| **orchestrator** | Alt-ajan açabilir, ama **depth-bounded**. Sonuçları sentezler. | `planner` (plan yazımı için araştırır), ana döngü |

**Kurallar:**
- **max_concurrent = 3** — aynı anda en fazla 3 paralel alt-ajan (BKM "3+ paralel feature" eşiğiyle hizalı). Daha fazla hedef varsa dalga dalga (3'lü grup).
- **Derinlik ≤ 2** — orchestrator → leaf. Leaf alt-ajan AÇAMAZ (sonsuz fan-out engeli). 3. seviye gerekirse ana ajana geri dön.
- **İzolasyon:** alt-ajan geçmiş konuşma bağlamını GÖRMEZ — yalnızca verilen görev. Parent, child özetini bekler (senkron), sonra devam.
- **Model bilinçli:** her Task çağrısında model (haiku/sonnet/opus) işe göre seçilir (§2) — depth-cap bunu pekiştirir, eşit-harcama yasak.

## İlişkili
- `.claude/rules/session-memory.md` — sub-agent prompt disiplini.
- Proje agent'ları: `.claude/agents/*.md`.
