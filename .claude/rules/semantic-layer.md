# Semantik Katman Disiplini

_BKM şema bilgisi `sema/*.yaml`'da canonical, makine-okunur tutulur. `paths:` yok — compact sonrası survive._

## Temel İlke

**Şema gerçeği öğrenilince hafızada kalmaz — `sema/`'ya yazılır.** Köprü, tablo grain'i, enum kodu, metrik formülü canlı sorguyla doğrulandığında `sema/*.yaml`'a atomic + confidence + evidence ile eklenir (ECC continuous-learning instinct pattern). Skill: `sema-ogren`.

## Dosya yönlendirme

| Öğrenilen | Hedef |
|---|---|
| Join / FK / cross-db bağ | `sema/bridges.yaml` |
| Tablo/view + PK + anahtar kolon + grain | `sema/entities.yaml` |
| Enum / lookup değerleri | `sema/codes.yaml` |
| İş kategorisi / formül / hesap modeli | `sema/metrics.yaml` |
| İnsan-okunur özet (köprü/kod) | `sorgular/SEMANTIK_KATMAN.md` (senkron) |

## Kurallar

1. **Sorgu yazmadan önce `sema/`'ya bak.** Doğru join `bridges.yaml`'da, doğru filtre/kod `codes.yaml`/`metrics.yaml`'da. Hardcode etme — oradan al.
2. **Yeni gerçek → anında kayıt.** "Sonra eklerim" yok; oturum içinde `sema-ogren` ile yaz.
3. **Atomic + kanıtlı.** Bir kayıt = bir gerçek. Her kayıt canlı doğrulanmış; tahmin `status: teyit bekliyor` + düşük confidence.
4. **Duplikasyon yok.** Aynı bağ varsa güncelle (confidence/evidence), yeni satır açma.
5. **Çelişki → düzelt.** Yeni gerçek eskiyi çürütürse eskiyi sil veya düşür (`note: süperseded`).
6. **Rapor scriptleri sema-driven.** Yeni script köprü/kod/metrik tanımını `sema/`'dan okur; tutarlılık tek kaynaktan.

## Confidence ölçeği
`1.0` kalıcı (PK/FK) · `0.9-0.99` canlı %99+ eşleşme · `0.5-0.8` gözlem ama tam teyit yok · `0.3-0.5` hipotez/teyit bekliyor.

## Yaşlanma (Decay) & Curator-check — plan-12 WS-1

Fact-Force Gate'in eksik yarısı: doğrulanmış gerçek **yaşlanır**. Sessiz-yanlış-rakam riski bayatlamış varsayımdan doğar (stkKod=barkod, depo key-mismatch).

1. **Yeni/güncellenen kayıtta `last_verified` zorunlu** (confidence:1.0 hariç — kalıcı, yaşlanmaz). Yaşlanma + ttl tablosu: `sema/README.md` § Decay.
2. **Sorgu yazmadan önce sema'ya bakarken** kayıt stale ise (`last_verified + ttl_days < bugün`) → körü körüne kullanma; **canlı doğrula**, sonra `last_verified`'ı bugüne çek (çürürse düşür/sil — `sema-ogren` çelişki kuralı).
3. **Stale = bayrak, otomatik aksiyon DEĞİL.** Kayıt silinmez/değişmez; sadece "yeniden doğrula" işareti. Otomatik archive YASAK — kullanıcı onayı şart.
4. **Curator-check** `session-handoff` içinde inactivity-triggered (≥7g): stale + dar/çakışan kayıt taraması. Derin konsolidasyon → `consolidate-sema` skill'i (dry-run rapor + onay).

## İlişkili
- `sema/README.md`, `.claude/skills/sema-ogren/SKILL.md`, `.claude/skills/consolidate-sema/SKILL.md`
- `.claude/rules/sql-server-conventions.md` — T-SQL yazım kuralları (DMY, compat 110, IsValid)
- `sorgular/SEMANTIK_KATMAN.md` — insan-okunur tam sözlük
