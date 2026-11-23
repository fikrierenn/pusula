---
name: egitim-gundem-tara
description: Scans Turkish education-policy news (MEB circulars, Resmî Gazete rules, ÖSYM/LGS/YKS exam changes, curriculum changes, free MEB resources such as MEBİ, school-calendar shocks, supplementary-book bans) and appends dated candidate events to the forecast event register. Triggers: "eğitim gündemi tara", "MEB değişikliği var mı", "sınav değişikliği araştır", "olay tablosunu güncelle", the weekly scheduled task "egitim-gundem-tara".
---

# Education agenda scan (event register feeder)

Purpose: BKM demand for test-prep books, school stationery and the exam-prep school channel moves with MEB/ÖSYM decisions
(user, 16.11.2026: "sürekli okullarda yöntem değişikliği sınav değişikliği oluyor"). The monthly forecast (plan 55) uses
these as dated events, usable only after their **announcement date**. This skill finds new ones; it never changes the model.

The run must finish its own research. The user's complaint (23.11.2026) was that the task "yarım yamalak ne olduğunu
anlamadan karar bekliyor": it handed over items it had not read or assessed. Resolve first, escalate last (step 7).

## Files

- Register: `C:\dev\pusula\docs\egitim-gundem\olaylar.yaml` (UTF-8, list under key `olaylar`). Append new items at the end
  of the list, copying the shape of existing items; never edit or delete an item whose `durum` is `onaylandi`. Keep the
  header comment. After writing, check the file still parses (`python -c "import yaml;yaml.safe_load(open(r'<path>',encoding='utf-8'))"`).
- Scan log: `C:\dev\pusula\docs\egitim-gundem\tarama-<dd.MM.yyyy>.md`, one per run, in Turkish.
- Lock: `C:\dev\pusula\docs\egitim-gundem\.tarama.lock` (git-ignored; see step 0).

Item fields: `olay_id, duyuru_tarihi, yururluk, aciklama, sinif, beklenen_yon, etkilenen (list), kaynak_url, guven, durum, eklenme`

- `duyuru_tarihi`, `yururluk`, `eklenme`: dd.MM.yyyy strings. If the announcement date is not verified, write `'?'` and say so.
  Quote values that start with `-`, `?` or contain `:`.
- `sinif`: yasak · ucretsiz_ikame · sinav · mufredat · takvim · diger.
- `beklenen_yon`: + · − · ?
- `etkilenen`: list of hazirlik · okul_kategorileri · sinav_kanali · kirtasiye · genel.
- `guven`: Yüksek (meb.gov.tr / resmigazete.gov.tr / osym.gov.tr, or two independent outlets) · Orta (one outlet) · Düşük.
- `durum`: always `aday` when this skill writes it. Only the user/coordinator promotes to `onaylandi` or `reddedildi`.

## Steps

0. **Take the lock before reading anything else.** On 16.11.2026 two runs started 6 seconds apart and both wrote the
   register. Create the lock atomically; the command fails if another run holds it:

   ```
   python -c "import os,sys,time,datetime as d;p=r'C:\dev\pusula\docs\egitim-gundem\.tarama.lock';e=os.path.exists(p);a=time.time()-os.path.getmtime(p) if e else 0;(e and a<10800) and sys.exit('KILITLI: %d dk once alinmis'%(a//60));e and os.remove(p);f=open(p,'x',encoding='utf-8');f.write(d.datetime.now().strftime('%d.%m.%Y %H:%M:%S'));f.close();print('kilit alindi')"
   ```

   - Exit code non-zero (`KILITLI` or `FileExistsError`): another run is active. Stop at once: no search, no register
     write, no log file. Reply with one line saying so and end the run.
   - A lock older than 3 hours is stale (a crashed run); the command removes it and takes a new one. Note this in the log.
   - Remove the lock as the very last file action of the run (step 9), also when the run ends early or fails after
     taking it. Never remove a lock this run did not take.
1. Read the register and find the latest `eklenme` date; the scan window is from 14 days before that date to today
   (first run: last 90 days).
   - **Carry-over from the previous log.** Open the most recent earlier `tarama-*.md`. Every item it lists under a
     "Pencere dışı" heading, and every item in its "Doğrulanamayanlar" list, is in scope for this run whatever its date.
     Each one must leave this run decided: an `aday` row, or a rejection with its reason in "Elenenler". None may be
     listed as "Pencere dışı" a second time. (The window rule alone missed the 28.07.2026 Okul Öncesi Eğitim ve
     İlköğretim Kurumları Yönetmeliği change and the 28.10.2026 new EBA for two runs.)
   - If this run itself meets a relevant item older than the window, decide it now the same way. Use "Pencere dışı" only
     for an item that could not be finished in this run, with the reason.
   - **One-off backfill (only when the user or coordinator asks for it):** set the window start to 01.07.2026 for that
     single run, state "geriye dönük tarama: 01.07.2026 – bugün" at the top of the log, and return to the normal window
     next run. Precedent: the 17.09–02.11.2026 backfill recorded in `tarama-16.11.2026.md`.
2. Run web searches in Turkish, at least these queries, each limited to the window:
   MEB genelge yardımcı kaynak · MEB kaynak kitap yasak · Resmî Gazete Ders Kitapları ve Eğitim Araçları Yönetmeliği ·
   LGS değişiklik · YKS TYT AYT değişiklik ÖSYM · müfredat değişikliği Maarif modeli · MEBİ ücretsiz deneme ·
   okullar tatil / açılış tarihi · ders kitabı ücretsiz dağıtım · veli kaynak kitap tepki ·
   MEB ölçme değerlendirme yönetmeliği değişiklik (ortak yazılı, okul içi sınav kuralları) ·
   Resmî Gazete Millî Eğitim Bakanlığı yönetmelik (window dates; catches rules the topic queries miss).
   Prefer meb.gov.tr, osym.gov.tr and resmigazete.gov.tr.
3. **Verify every date at its source.** A date seen only in a search snippet or a news outlet is not verified. Open the
   official page (meb.gov.tr, osym.gov.tr, resmigazete.gov.tr) and read the date there. If the page or PDF does not
   open, try the other official route (the ministry news item, the Resmî Gazete issue of that day, the unit's own
   announcement list) before giving up. Only then write `'?'`, and put the item in "Doğrulanamayanlar" with what was tried.
   - This also covers rows already in the register whose date is `'?'` or was flagged in an earlier log.
   - Never edit an `onaylandi` row. Put the verified value in the log under "Onaylı satırlar için öneriler" as:
     `öneri: <alan> = <değer>, kaynak: <URL>, doğrulandı`. Example: T2027 `duyuru_tarihi` 30.10.2026, MEB news 42348,
     was left for two runs as "sayfa açılarak doğrulanmadı"; opening that page settles it.
4. Keep an item only if it can plausibly shift paid supplementary-book, stationery or exam-prep demand. Drop opinion
   pieces and rumours unless a ministry statement exists.
5. Deduplicate against the register (same decision = same row; a new step of an existing decision gets its own row with a
   suffix such as `G2026b`).
6. Append new items with `durum: aday`. Never invent a date or URL; unverifiable dates are `?`.
7. **Resolve before escalating.** Nothing reaches "Kullanıcı kararı bekleyen" until all three are done for it:
   - (a) **Read the primary official text**: the Resmî Gazete text itself, the circular, the ÖSYM guide. A secondary
     outlet's summary is not enough. (The 23.11.2026 log left RG 33430 articles 7–11 as ÇIKARIM from one secondary
     source although the gazette text was one click away.) Mark what was read as ÖLÇÜLDÜ and what is inferred as ÇIKARIM.
   - (b) **Assess the effect on supplementary/source-book demand**: does it affect sales, in which direction, for which
     group (`etkilenen`), and from when. One or two sentences, with the passage it rests on.
   - (c) **Write your own recommendation**: add as `aday` / reject / propose a correction, with the reason.

   Then sort the item:
   - Settled by (a)–(c): act on it (row or rejection). It does not go to the user.
   - A genuine business decision (for example whether an event class should enter the model, or how to treat an event
     whose direction is disputed): goes to "Kullanıcı kararı bekleyen", each with the recommendation from (c). Promoting
     a row to `onaylandi` is not listed there item by item; the "Eklenen satırlar" table already serves that.
   - Could not be verified even from the primary source: goes to the separate "Doğrulanamayanlar" list, with the reason
     and what was tried. It is then carried into the next run (step 1).

   Forbidden: handing over an item without a recommendation, and phrases such as "kullanıcı isterse değerlendirilebilir",
   "karar kullanıcıda" or "bilgi için" in place of a decision.
8. Write the scan log in Turkish with these sections, in this order; write "yok" under a section that is empty:
   Pencere · Önceki taramadan devreden kalemler (each with its outcome) · Koşulan sorgular · Eklenen satırlar (table) ·
   Onaylı satırlar için öneriler · Elenenler (one-line reasons) · Kullanıcı kararı bekleyen (each with a recommendation) ·
   Doğrulanamayanlar (reason + what was tried) · Pencere dışı (only unfinished items, with the reason) · Doğrulama.
   Write "yeni olay yok" if nothing was found. A run that finds nothing still writes its log (silence is not evidence).
9. Close the run: check the register parses, remove the lock, then give the 3-line summary (rows added · items waiting
   for a user decision · items not verifiable). After the summary, if the tool `mcp__ccd_session_mgmt__archive_session`
   is available (load it with ToolSearch if it is deferred), archive this run's own session by calling it with
   `"self"`. If the tool is not available, skip this without comment. Do this only in a scheduled-task run, not when the
   user invoked the skill inside a working session.

## Do not

- Do not edit forecast code, `scripts/forecast/run.py`, `.orkestra/calisma/`, sema or any database.
- Do not commit; do not change rows with `durum=onaylandi`.
- Do not put user or company data into search queries.
- Do not invent a date or a URL. An unverified value is `'?'` plus an entry in "Doğrulanamayanlar".
- Do not write to the register or the log without holding the lock (step 0).

## Related

- Plan: `plans/archive/55-aylik-tahmin-birlesik-model.md` (event feature, blind rule: usable only when announcement date ≤ origin).
- Effect measurement: `.orkestra/calisma/tahmin/faz0/olay/` (F0-04b).
