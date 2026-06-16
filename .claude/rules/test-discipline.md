# Test Disiplini — Testleri Kapatmadan "Bitti" Deme

> **Rule katmanı:** on-demand (konu-bazlı) — feature/fix/refactor kapatma anında birincil. Core değil. plan-12 WS-2 / footprint-ladder.

_Kapsam: Yeni feature / bug fix / refactor kapatma kriteri. `paths:` yok — compact sonrası survive._

## Mutlak Kurallar

1. **Yeni feature / bug fix / refactor → test çalıştırılmadan kapatma.**
   - Etkilenen testler projenin test komutuyla (`npm test` / `pytest` / `dotnet test` / `go test`) **geçti** olmalı (failure veya skip yetmez).
   - "Test yok ama kod doğru görünüyor" yetmez — boşluk varsa **yeni test yaz**, sonra çalıştır.
   - **Build yeşil ≠ test yeşil.** Bunu karıştırma. Compile/lint geçmesi runtime doğruluğu kanıtlamaz.

2. **Yeni test eklendiğinde → en az 1 koşum yap.**
   - Test dosyasını yazmak yetmez; çalıştır + sonucu raporla.
   - Failure varsa **fix et veya scaffolding'i geri al** — yarım kalmış test commit'leme.

3. **Test yokken bug fix → en az regression test yaz.**
   - Fix öncesi: bug'ı reproduce eden failing test.
   - Fix sonrası: aynı test geçer.
   - Sonraki regression yakalanır.

4. **Refactor → mevcut test seti yeşil kalmalı.**
   - Refactor öncesi: `N/N geçti` not.
   - Refactor sonrası: aynı sayı (veya artmış) geçti.
   - Test sayısı azalırsa kasıtlı silme dışında **regression sinyali**.

## "Bitti" Tanımı (Definition of Done)

Bir iş ancak şu üçü sağlanınca kapanır:
1. Build/compile/lint yeşil.
2. İlgili testler çalıştırıldı ve **geçti**.
3. Kullanıcı-görünür değişiklikse smoke test yapıldı (gerçek senaryo).

## Anti-pattern

1. **"Build yeşil, tamam sayalım"** — test çalıştırılmadı, runtime kırık olabilir.
2. **Test yazıp çalıştırmadan commit etmek** — failure git history'ye girer.
3. **`skip` / `xit` / `[Ignore]` ile testi by-pass etmek** — sebep dokümante edilmeden devre dışı kabul edilmez.
4. **Failure'ı "ileride bakacağım" diye bırakmak** — stale-claim olur (`.claude/rules/todo-verification.md`).
5. **Sadece happy-path test** — edge case, hata yolu, boş/null girdi de test edilir.
6. **Snapshot / change-detector test** — mevcut-veriyi sabitleyen test kapsam katmaz, ilk değişimde kırılır (plan-12 WS-7, Hermes "explicit contracts over snapshots").

## Davranışsal Kontrat > Snapshot (plan-12 WS-7)

Test **ilişki/invariant** doğrular, anlık-veriyi değil. Mevcut sayıyı/listeyi sabitleyen test = "change-detector" (her veri değişiminde kırılır, hata yakalamaz).

| ❌ Snapshot (kötü) | ✅ İnvariant (iyi) |
|---|---|
| `assert len(stores) == 3` | `assert len(stores) >= 1` |
| `assert net == 5_401_374` | `assert net == brut - indirim` (formül ilişkisi) |
| `assert "Oyuncak" in kategoriler` | `assert all(k.ciro >= 0 for k in kategoriler)` |
| `assert rows == 37` | `assert rows > 0 and toplam == sum(r.ciro for r in rows)` |

BKM rapor doğrulamasında: "bu hafta X satır geldi" değil — "satır ≥1 VE net=brüt−indirim VE iade negatif düşülmüş". Rakam mutabakatı (MCP eski/yeni) ayrı; test = davranış sözleşmesi.

## İlişkili
- `.claude/rules/todo-verification.md` — "kapalı" iddiasını kanıtla.
- `.claude/rules/before-major-change.md` — refactor öncesi güvenlik.
