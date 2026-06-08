# Test Disiplini — Testleri Kapatmadan "Bitti" Deme

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

## İlişkili
- `.claude/rules/todo-verification.md` — "kapalı" iddiasını kanıtla.
- `.claude/rules/before-major-change.md` — refactor öncesi güvenlik.
