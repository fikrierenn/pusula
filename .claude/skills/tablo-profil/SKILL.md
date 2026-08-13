---
name: tablo-profil
description: Bilinmeyen/tanınmayan tabloya sistematik profil — Fact-Force Gate'in prosedür hali. Yapı + grain + kalite + köprü adayı keşfi, sonuç sema-ogren'e beslenir. "tabloyu profille", "bu tablo ne", "tanımadığım tablo", "tablo keşfi", "grain ne", "/tablo-profil" denildiğinde veya sema/'da kaydı olmayan tabloya ilk analitik sorgu yazılmadan önce devreye gir.
---

# tablo-profil — Bilinmeyen Tablo Sistematik Keşif

> `before-major-change.md` § Fact-Force Gate "önce keşfet" der; bu skill NASIL'ı verir. Çıktı iki yere akar: `sema-ogren` (gerçek) + `sorgular/YYYY-MM-DD-*.sql` (SQL arşiv — ikiz yükümlülük).

## 0. Önce sema'ya bak

`sema/entities.yaml` + `bridges.yaml` + `codes.yaml` grep. Kayıtlıysa ve `last_verified` taze → profil GEREKSİZ, oradakini kullan. Stale ise → sadece stale alanı canlı doğrula (tam profil değil).

## 1. Yapı

```sql
SELECT c.name, t.name AS tip, c.max_length, c.is_nullable
FROM sys.columns c JOIN sys.types t ON t.user_type_id = c.user_type_id
WHERE c.object_id = OBJECT_ID('şema.Tablo')
```
+ satır sayısı (`sql_table_stats` / `COUNT(*)`), PK/index (`sql_describe_table` zaten çoğunu verir — MCP aracı varsa onu kullan, elle sorgu yazma).

## 2. Örnek Veri

`TOP 5` ham satır — kolon adlarının gerçek içeriğiyle uyuşup uyuşmadığına bak (DerinSIS'te ad yanıltır: stkKod≠barkod dersi).

## 3. Grain Tespiti (KRİTİK — atlanırsa join explosion)

Aday anahtar için: `COUNT(*)` vs `COUNT(DISTINCT anahtar)`. Eşitse grain=o anahtar. Değilse hangi kombinasyon tekil, bul. Grain bilinmeden bu tabloya join YAZILMAZ.

## 4. Kalite

- Kritik kolonlarda NULL/sıfır oranı (`SUM(CASE WHEN x IS NULL THEN 1 ELSE 0 END)`).
- Tarih kolonu: `MIN/MAX` — kapsanan aralık, bugüne kadar dolu mu (job gecikmesi belirtisi).
- Enum-aday (düşük kardinalite) kolon: `GROUP BY kolon` top-20 dağılım → kod sözlüğü adayı.

## 5. Köprü Adayları

ID-görünümlü kolonlar için bilinen tablolara eşleşme oranı testi:
```sql
SELECT COUNT(*) AS toplam,
  SUM(CASE WHEN h.stkID IS NOT NULL THEN 1 ELSE 0 END) AS eslesen
FROM YeniTablo y LEFT JOIN urn h ON h.stkID = y.AdayKolon
```
%99+ → köprü; %9 gibi kısmi → SAHTE köprü (Products.Code=stkKod %9 vakası) — kaydetme, uyar.

## 6. Kayıt (İKİZ YÜKÜMLÜLÜK — atlanmaz)

1. Gerçekler → `sema-ogren`: entity (grain+PK+kolonlar), bridge (eşleşme oranı=confidence), code (enum dağılımı). `last_verified` bugün.
2. Profil SQL'leri → `sorgular/YYYY-MM-DD-<tablo>-profil.sql` (2-3 satır yorum başlıkla).

## MCP Notları

- CTE yok, tek SELECT; ORDER BY → TOP ile; DECLARE yok (inline literal).
- EncoreMerkez compat 110: TRY_CONVERT/STRING_AGG/IIF yok.
- Dashboard hedefliyse 3-parçalı isim doğrula (`DerinSISBkm.bkm.X`) — MCP'de çalışması app'te çalışacağını kanıtlamaz.

## Anti-pattern

- ❌ "Tablo adı tanıdık, direkt sorgularım" — Fact-Force Gate ihlali.
- ❌ Grain'siz join → şişmiş SUM (sonra `veri-dogrula` yakalar ama iş baştan yanlış).
- ❌ Profil yapıp sema'ya yazmamak / SQL arşivlememek — keşif kaybolur, yeniden keşif pahalı.
- ❌ Kolon adından anlam çıkarıp örnek veriye bakmamak.

## İlişkili
- `.claude/rules/before-major-change.md` § Fact-Force Gate — zorunluluğun kaynağı.
- `.claude/skills/sema-ogren/SKILL.md` — bulguların kayıt yeri.
- `.claude/rules/semantic-layer.md` — ikiz yükümlülük + decay.
- `.claude/skills/veri-dogrula/SKILL.md` — teslim öncesi QA (bu skill'in aşağı-akışı).
