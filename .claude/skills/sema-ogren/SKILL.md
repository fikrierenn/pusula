---
name: sema-ogren
description: Yeni şema gerçeği (köprü/tablo/kod/metrik) öğrenildiğinde structured semantik katmana (sema/*.yaml) atomic olarak ekler. ECC continuous-learning "instinct" pattern uyarlaması. "sema öğren", "semantik katmana ekle", "bu köprüyü kaydet", "/sema-ogren" denildiğinde veya MCP sorgu yeni bir join/kod/grain ortaya çıkardığında devreye gir.
---

# sema-ogren — Şema Keşfi → Semantik Katman

BKM semantik katmanı `sema/` altında YAML olarak yaşar (canonical, makine-okunur). Bu skill, oturumda öğrenilen yeni şema gerçeğini oraya **atomic + confidence + evidence** ile yazar. ECC'nin instinct/continuous-learning fikrinin şema-keşfine uyarlanmış halidir.

## Ne zaman tetiklenir
- MCP `sql_query` yeni bir **köprü** (join FK/cross-db), **tablo/grain**, **kod/enum**, veya **metrik formülü** ortaya çıkardı.
- Kullanıcı "bunu kaydet / semantik katmana ekle / sema öğren" dedi.
- Bir hipotez **doğrulandı** (confidence yükseltme) veya **çürüdü** (sil/düşür).

## Adımlar

1. **Sınıflandır:** Öğrenilen gerçek hangi dosyaya?
   - Join/FK/cross-db bağ → `sema/bridges.yaml`
   - Tablo/view + anahtar kolon + grain → `sema/entities.yaml`
   - Enum/lookup değerleri → `sema/codes.yaml`
   - İş kategorisi/formül/hesap → `sema/metrics.yaml`

2. **Atomic kayıt yaz** (instinct formatı):
   ```yaml
   - id: <kebab-case-benzersiz>
     from: <şema.tablo.kolon>       # köprü ise
     to: <şema.tablo.kolon>
     scope: derinsis|encoremerkez|joker|cross-db
     confidence: 0.3-1.0            # ölçek: sema/README.md
     note: "<kısa açıklama / uyarı>"
     evidence: "<tarih> — <nasıl doğrulandı / hangi sorgu>"
     last_verified: <YYYY-MM-DD>    # ZORUNLU — son canlı teyit tarihi (decay için; sema/README.md)
     ttl_days: <int>                # opsiyonel — yoksa confidence'tan türetilir; confidence:1.0 MUAF
     status: "teyit bekliyor"       # opsiyonel, düşük confidence ise
   ```
   **`last_verified` zorunlu** (confidence:1.0 hariç — kalıcı, yaşlanmaz). Yaşlanma kuralı: `sema/README.md` § Decay.

3. **Duplikasyon kontrol:** Aynı `id`/bağ var mı? Varsa **güncelle** (confidence/evidence + `last_verified` bugüne çek), yeni satır ekleme.

4. **Tarih güncelle:** İlgili YAML'ın `updated:` alanı.

5. **İnsan özeti senkron:** Köprü/kod ise `sorgular/SEMANTIK_KATMAN.md`'ye de bir satır yansıt (insan-okunur).

6. **Çelişki:** Yeni gerçek eski bir kaydı çürütüyorsa — eskiyi sil veya `confidence` düşür + `note: "süperseded by <id>"`.

## İlkeler
- **Atomic:** Bir kayıt = bir gerçek. Karışık kayıt yok.
- **Kanıtlı:** Her kayıt canlı sorguyla doğrulanmış olmalı; tahmini `status: teyit bekliyor` + düşük confidence.
- **Tek doğruluk kaynağı:** Aynı bilgi iki YAML'da yaşamaz.
- **Rapor scriptleri** köprü/kod/metrik tanımını `sema/`'dan okumalı (hardcode yerine) — yeni script yazarken buna uy.

## İlişkili
- `sema/README.md` — yapı + confidence ölçeği.
- `.claude/rules/semantic-layer.md` — kalıcı kural.
- `sorgular/SEMANTIK_KATMAN.md` — insan-okunur özet.
