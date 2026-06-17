# Footprint Ladder — Yeni Yetenek En Dar Basamakta

_Hermes "narrow waist" uyarlaması (plan-12 WS-2). Yeni bir ihtiyaç çıkınca onu çözen EN DAR footprint'te dur. `paths:` yok — compact sonrası survive._

## Temel İlke

**Çekirdek dar bel; yetenek kenarda.** Her yeni kalıcı yapı (rule/skill/agent/sema-entity/dashboard sayfası) bakım yükü + bağlam maliyeti getirir. Bir ihtiyaç çıktığında merdivenin EN ALT (en dar) basamağında çöz; üst basamağa ancak alt basamak yetmezse çık.

## Merdiven (alttan üste — alt = dar/ucuz)

| # | Basamak | Ne zaman | Maliyet |
|---|---|---|---|
| 1 | **Mevcut script/rule/sorguyu genişlet** | Var olan bir şeye 1 fonksiyon/satır/kolon eklemek çözüyorsa | ~0 yeni yüzey |
| 2 | **Yeni skill** | Tekrarlanan bir iş akışı; tetik-bazlı yüklenir (her zaman bağlamda değil) | Düşük — sadece tetiklenince |
| 3 | **Yeni rule** | Kalıcı davranış kuralı (her oturum geçerli) | Orta — her session bağlamda (core ise) |
| 4 | **Yeni agent** | Özelleşmiş, salt-okuma/denetim alt-ajan | Orta — tanım + model seçimi |
| 5 | **Yeni sema-entity/bridge** | Yeni tablo/köprü/kod kalıcı şema gerçeği | Orta — decay+bakım (`semantic-layer.md`) |
| 6 | **Yeni dashboard sayfası/servis (SON ÇARE)** | Kullanıcı-görünür yeni yüzey; başka basamak çözemiyor | Yüksek — UI+SQL+test+perf+nav |

## Kurallar

1. **Aşağıdan yukarı sor:** "Bunu mevcut X'i genişleterek çözebilir miyim?" → hayırsa bir üst basamak.
2. **Atlama yapma:** 6. basamağa (yeni sayfa) gitmeden önce 1-5 elendi mi?
3. **Şüphede aşağıda kal.** Dar çözüm yetmezse büyütmek kolay; geniş çözümü küçültmek zor (B-75 redesign dersi).
4. **BKM'de OLMAYAN basamaklar:** Hermes'in MCP-catalog / plugin / core-tool rung'ları BKM'ye UYMAZ (tek-kullanıcı/tek-makine — `plans/12` §5 reddedilenler). Yetenek skill/rule/agent ile genişler.

## Anti-pattern

- ❌ "Yeni özellik = yeni sayfa" refleksi → önce mevcut sayfaya bölüm/sorgu eklenebilir mi?
- ❌ Tek-kullanımlık iş için yeni skill/agent → mevcut akışta inline çöz.
- ❌ "İleride lazım olur" diye geniş soyutlama (bkz. `coding-discipline.md` simplicity-first).
- ❌ **Skill/agent yaratmadan önce mevcut listeyi kontrol ETMEMEK** (17.06 dersi: `bkm-sunum`'u proje-local yarattım, halbuki global kapsamlı versiyonu vardı → dup). Yeni skill/agent ÖNCESİ available-skills listesine (proje `.claude/skills/` + global + plugin) bak; aynı isim/işlev varsa GENİŞLET, yaratma.
- ❌ Dış repodan (awesome-X, superpowers vb.) "esin" diye BKM'de zaten olanı tekrar kurmak → önce mevcut rule/skill ile kıyasla; çoğu zaten kapsanmış olabilir.

## İlişkili
- `.claude/rules/coding-discipline.md` — simplicity-first (aynı damar).
- `.claude/rules/plan-first.md` — Tier sistemi (büyük basamak = Tier-3 plan).
- `.claude/rules/semantic-layer.md` — sema-entity basamağı + decay.
- `plans/archive/12-hermes-adaptasyon.md` — kaynak (Hermes narrow-waist; tamamlandı, arşivde).
