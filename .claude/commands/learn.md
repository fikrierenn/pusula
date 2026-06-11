---
description: "Oturumda çözülen anlamlı bir sorunu kalıcı kurala/derse dönüştürür (ECC /learn — instinct pattern). Şema gerçeğiyse sema-ogren'e yönlendirir."
argument-hint: "[öğrenilen ders — boş bırakılırsa oturumdan çıkarılır]"
allowed-tools: ["Read", "Grep", "Glob", "Edit", "Write", "Skill"]
---

# /learn — Çözülen Sorundan Kalıcı Ders

Oturumda debug edilip çözülen anlamlı sorunları kalıcılaştırır. `session-memory.md` "aynı hatayı 2. kez yapıyorum → rule yaz" kuralının yürütücüsü.

## Adımlar

1. **Dersi çıkar:** Argüman verilmişse onu kullan; verilmemişse bu oturumda çözülen sorunları tara (hata → kök neden → çözüm üçlüsü net olanlar). Önemsizleri (typo, tek seferlik) ALMA.

2. **Sınıflandır → hedef:**
   | Ders tipi | Hedef |
   |---|---|
   | **Şema gerçeği** (köprü/kod/grain/metrik) | `sema-ogren` skill'ini çağır → `sema/*.yaml` (BURAYA YAZMA, skill yazsın) |
   | T-SQL yazım kuralı (tarih, compat, kolon adı) | `.claude/rules/sql-server-conventions.md` |
   | MCP gotcha (CTE, ORDER BY, timeout) | `.claude/rules/sql-server-conventions.md` § MCP |
   | Python script kalıbı (pymssql/openpyxl/encoding) | `.claude/rules/coding-discipline.md` veya ilgili rule |
   | Anti-pattern (silme/refactor kazası) | `.claude/rules/before-major-change.md` § Anti-pattern |
   | İş bilgisi (Heykel=Bursa Kültür, COD ekonomisi gibi) | İlgili `docs/NN-*.md` |
   | Tek seferlik bağlam | journal — rule'a YAZMA |

3. **Atomic yaz:** Bir ders = bir madde. Format: **ne yapma → neden → doğrusu** (+ tarih). Mevcut benzer madde varsa güncelle, duplike etme.

4. **Bildir:** Hangi dosyaya ne eklendiğini tek satırda raporla.

## Kurallar
- Kullanıcı onayı olmadan kural SİLME (ekleme serbest).
- CLAUDE.md'ye yazma — o fihrist (200 satır eşiği); dersler rules/docs/sema'ya.
- Spekülatif "ileride lazım olur" dersi yazma — sadece gerçekleşen hata.
