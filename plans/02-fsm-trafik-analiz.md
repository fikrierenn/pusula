# Plan 02 — FSM Trafik & Dönüşüm Sistematizasyon

**Tarih:** 2026-04-28
**Proje:** `bkm` + `crossproject` (multi-touchpoint)
**Yazan:** Claude (oturum 28.04 sabah) · Onay: Fikri
**Durum:** `Taslak` — kullanıcı onayı bekleniyor

---

## 1. Problem

FSM kapı sayıcı sistemi 8 Nisan'da kuruldu ve veri üretiyor (giriş sayıları), ama **bu veri analiz akışına entegre değil:**

1. **Manuel kopyalama** ile akıyor — 28 Nis hızlı raporu için kullanıcı tabloyu chat'e yapıştırdı, otomatik import yok.
2. **Sadece FSM'de** var — Özlüce ve İst.Yolu'nda yok, karşılaştırmalı analiz imkânsız.
3. **Saat bazlı kırılım yok** — sadece günlük toplam (peak saat / kuşak analizi yapılamıyor).
4. **Pazartesi brifing'e bağlı değil** — Dönüşüm % ve Kişi başı ciro KPI'ları her hafta elle hesaplanmak zorunda.
5. **Veri kalitesi sorunları kontrolsüz** — 29-30 Nis future timestamps, 30 Nis = 8 giriş anomalisi keşfedildi (bu plan olmadan).

Bu ayda 2 kez "elle yap" yapılırsa makul, ama haftada/günde olunca süreklilik bozulur. Sayıcı verisi **gerçek değer üretmek için sistematize olmalı.**

## 2. Scope

### Kapsam dahili
- **Vendor / cihaz keşfi** — Bursa Nilüfer FSM'de hangi marka/model sayıcı, ne format export ediyor (API/CSV/DB).
- **SQL Server şema** — `bkm.MagazaTrafik` (veya benzer) tablo: tarih, mağaza, saat (varsa), giriş sayısı, kaynak, import_at.
- **İmport scripti** — Python (`scripts/import_trafik.py`) veya PowerShell. Vendor formatına göre.
- **Pilot raporu sistematizasyonu** — bugün manuel oluşturulan markdown'ı parametrik script'e taşı (`scripts/generate_trafik_report.py`).
- **Pazartesi brifing entegrasyonu** — `briefings/template/brief.html`'a Dönüşüm % + Kişi başı ciro kolonları eklenir.
- **Veri kalitesi check'leri** — future timestamp filtresi, anomali (giriş < 50 günlerde flag), açılış-kapanış saat dışı kayıt uyarısı.
- **Dokümantasyon** — `docs/projects/bkm/sayici-entegrasyonu.md` (kurulum + işletim notları).

### Kapsam dışı
- **Power BI / Metabase dashboard** — ayrı Tier 3 plan (`plans/03-bi-trafik-dashboard.md` ileride).
- **Diğer mağazalara cihaz kurulumu** — operasyonel (donanım sipariş, kurulum), bu plan teknik altyapı sağlar, donanım tarafı şube müdürlerinde.
- **A/B kampanya etki ölçümü** — sayıcı veri akışı kararlı çalıştıktan sonra ileride.
- **Saat bazlı veri** (Faz 4'te değerlendirilecek, vendor destekliyorsa).
- **Heykel mağaza** — kapsamda 3 Bursa mağazası var.

### Etkilenen dosyalar (tahmin)

| Dosya | Tip | Ne değişecek |
|---|---|---|
| `bkm.MagazaTrafik` (SQL DDL) | Yeni | Tablo + indeks + foreign key (Stores) |
| `sorgular/dwh/trafik-tablo-create.sql` | Yeni | DDL kanonik |
| `sorgular/dwh/trafik-haftalik-ozet.sql` | Yeni | Brief için temel sorgu |
| `sorgular/dwh/donusum-kpi-magaza.sql` | Yeni | Dönüşüm + kişi başı ciro KPI |
| `scripts/import_trafik.py` | Yeni | Vendor → SQL import |
| `scripts/generate_trafik_report.py` | Yeni | Otomatik MD/HTML rapor üretici |
| `briefings/template/brief.html` | Var | KPI kolonları eklenir |
| `docs/projects/bkm/sayici-entegrasyonu.md` | Yeni | İşletim notları |
| `.claude/rules/sql-server-conventions.md` | Var | trafik tablo kural eklemesi (varsa) |
| `TODO.md` | Var | Faz adımları işlenecek |
| `docs/journal/bkm/YYYY-MM-DD.md` | Yeni | Plan ilerleme notları |

**Tahmini boyut:** 8-11 dosya, ~400-600 satır kod + SQL + dokümantasyon.

## 3. Alternatifler

### A: Manuel kopyala-yapıştır + Python parser (mevcut yaklaşım sürdürülsün)
**Açıklama:** Hafta başında kullanıcı sayıcı raporunu chat'e yapıştırır, ben parse edip rapor üretirim.
**Reddetme sebebi:**
- Hatalara açık (yapıştırma hatası, satır eksik kalabilir).
- Scale etmiyor: 3 mağaza × 7 gün = 21 yapıştırma/hafta.
- Saat bazlı veri eklenirse iyice imkansız.
- "Otomatik kayıt" disiplini yok → veri kaybolur.

### B: Sayıcı vendor API → daily fetch cron job
**Açıklama:** Vendor REST API sunuyorsa Python scripti her gece bir kez fetch eder, SQL'e yazar.
**Reddetme sebebi:** API var olduğu kanıtlanmadı — Faz 0 keşfine bağlı. Yoksa düşer. (Yine de ilk denenecek seçenek.)

### C: Sayıcı CSV/Excel export → SQL Server `BULK INSERT` (önerilen — pratik)
**Açıklama:** Vendor cihazları genellikle CSV/Excel export edebilir. Bir Windows klasörüne her gün otomatik bırakılır, scheduled task BULK INSERT yapar.
**Sebep:**
- Çoğu vendor destekler (donanım-bağımsız).
- API gerektirmez, vendor desteği bağımlı değil.
- Hata izlemesi kolay (CSV dosyasını gör).
- BULK INSERT performanslı.
- **MVP için en hızlı yol.**

### D: Vendor yazılımı SQL Server'a direkt yazsın (vendor'dan iste)
**Açıklama:** Cihaz/yazılım SQL'e doğrudan bağlanır.
**Reddetme sebebi:**
- Vendor desteği gerekli — bağımlı.
- Müsait değilse plan donar.
- Güvenlik: cihaz creds nasıl yönetilir?
- Çok temiz ama overengineering MVP için.

### E: Üçüncü parti tool (Power Automate, Zapier vb.)
**Açıklama:** Sayıcı → cloud → SQL aktarımı no-code platform.
**Reddetme sebebi:** Aylık ücret, dış bağımlılık, lokal kurulu sayıcılarla uyumsuz olabilir.

**Seçilen: C** — Vendor CSV export + Windows klasör + scheduled task BULK INSERT. B (API) Faz 0'da denenir, varsa kabul edilir.

## 4. Riskler

| Risk | Etki | Olasılık | Mitigation |
|---|---|---|---|
| Vendor API yok ve CSV export da kısıtlı | yüksek | orta | Faz 0 keşfi öncelikli, alternatif: ekrandan "snapshot" PDF parsing |
| Sayıcı cihaz saatleri senkron değil (29-30 Nis bug) | orta | yüksek | Import sırasında cihaz timestamp + import_at karşılaştırma; future timestamp REJECT + log |
| Personel/iç giriş veri kirliliği | orta | yüksek | Açılış-kapanış saat aralığı dışı kayıtları flag + ayrı kolonda tutarak (`personel_ihtimali` boolean) |
| Cihaz arızası → veri kaybı | düşük | düşük | İmport scripti idempotent; aynı tarih için yeniden import override etmesin, log gerekecek |
| Vendor desteği yetersiz | orta | orta | C planı (CSV) bağımsız çalışıyor; vendor desteği sadece cihaz arızasında lazım |
| 3 mağazada farklı vendor olur (sonradan) | orta | düşük | Tablo şeması source kolonu ile vendor-bağımsız tasarlandı |
| Brief'e KPI eklendiğinde yöneticiler yanlış yorumlar | orta | orta | İlk hafta brief'te "Dönüşüm bandı %47-53 sektör için sağlıklı" eğitim kutusu |
| FSM düşük sepet sorunu sayıcı ile çözülmez sanılır | orta | yüksek | Sayıcı tanı aracı, çözüm değil — bu plan'ın done criteria'sında belirtildi |

## 5. Done Criteria

Plan tamamlandı sayılması için:

- [ ] **Faz 0**: Vendor + cihaz modeli + export formatı belgelendi (`docs/projects/bkm/sayici-entegrasyonu.md` 1. bölüm).
- [ ] **Faz 1**: `bkm.MagazaTrafik` tablo oluştu, en az 30 gün FSM verisi içeriyor (8 Nis - 7 May).
- [ ] **Faz 1**: Manuel CSV import scripti çalışıyor, 1 komutla import yapıyor.
- [ ] **Faz 2**: Scheduled task otomatik daily import çalıştırıyor, 7 gün üst üste anomali 0.
- [ ] **Faz 2**: Veri kalite check'leri aktif (future timestamp REJECT, açılış-kapanış dışı flag).
- [ ] **Faz 3**: Pazartesi brifing'e "Dönüşüm %" + "Kişi başı ciro" kolonları eklendi, 1 hafta canlı çalıştı.
- [ ] **Faz 3**: `scripts/generate_trafik_report.py` parametrik (tarih aralığı + mağaza) HTML/MD üretiyor.
- [ ] **Faz 3**: Bu rapor briefing'e otomatik linkleniyor.
- [ ] Dokümantasyon tam (`docs/projects/bkm/sayici-entegrasyonu.md` işletim + sorun giderme).
- [ ] **Test geçti**: 7 günlük otomatik akış, manuel müdahale 0, veri kayıp 0, anomali tespiti gerçekleşti (en az 1 vakaya rastlandı).

## 6. Rollback Planı

Bu plan **additive** — hiçbir mevcut veri/işlev değişmiyor, sadece yeni katman ekleniyor. Rollback gerekirse:

```sql
-- DB rollback
DROP TABLE IF EXISTS bkm.MagazaTrafik;
```

```powershell
# Dosya rollback
git revert <commit-range>
# scheduled task kaldır
Unregister-ScheduledTask -TaskName "BKM-Sayici-Import" -Confirm:$false
```

Brifing entegrasyonu rollback'i daha karmaşık (template revert) ama etki kullanıcıya görünür değil — sadece KPI kolonları kalkar.

## 7. Adımlar / TODO Maddeleri

### Faz 0 — Keşif (1 gün)
- [ ] **B-22.0** Vendor / cihaz markası FSM şubesinden öğren (IT veya şube müdürü)
- [ ] **B-22.1** Cihazın yazılımı incelendi: API var mı? CSV export var mı? Hangi alanlar?
- [ ] **B-22.2** Mevcut sayıcı verisi geçmişi: 8 Nis öncesi var mı? Cihaz ne zaman kuruldu?
- [ ] **B-22.3** Sayım metodolojisi: tek yönlü mü çift yönlü mü? Çıkışları sayıyor mu?
- [ ] **B-22.4** 29-30 Nis future timestamp bug'ı netleştirildi (cihaz saati mi, rapor sistemi mi)
- [ ] Sonuç → `docs/projects/bkm/sayici-entegrasyonu.md` § 1

### Faz 1 — Tablo + Manuel İmport (1-2 gün)
- [ ] **B-22.5** `bkm.MagazaTrafik` DDL yazıldı + uygulandı (`sorgular/dwh/trafik-tablo-create.sql`)
- [ ] **B-22.6** İlk yükleme: 8 Nis - 28 Nis FSM verisi manuel CSV ile yüklendi
- [ ] **B-22.7** `scripts/import_trafik.py` ilk versiyon — CSV → SQL idempotent insert
- [ ] **B-22.8** Veri doğrulama sorgusu: `sorgular/dwh/trafik-haftalik-ozet.sql`
- [ ] **B-22.9** Mevcut rapor.md ile bu tablodan üretilen versiyonu eşleştir (regression test)

### Faz 2 — Otomasyon (2-3 gün)
- [ ] **B-22.10** Vendor CSV otomatik export ayarı (cihazda set edilebilirse)
- [ ] **B-22.11** Windows scheduled task kurulumu — daily 06:00 import
- [ ] **B-22.12** Veri kalite check'leri import scriptine eklendi (future REJECT + anomali flag)
- [ ] **B-22.13** Hata durumu mail/log uyarı
- [ ] **B-22.14** 7 gün boyunca izleme, anomali yok teyit

### Faz 3 — Brief Entegrasyonu (1-2 gün)
- [ ] **B-22.15** `scripts/generate_trafik_report.py` parametrik
- [ ] **B-22.16** Pazartesi brifing template'ine Dönüşüm % + Kişi başı ciro kolonları
- [ ] **B-22.17** İlk Pazartesi (4 May) canlı test
- [ ] **B-22.18** Yönetim için "dönüşüm bandı %47-53 = sağlıklı" eğitim notu brief'te

### Faz 4 — İleri (opsiyonel — bu plana dahil değil)
- Saat bazlı veri (vendor destekliyorsa) — ayrı plan
- Özlüce + İst.Yolu cihaz sipariş + kurulum — operasyonel iş
- Power BI dashboard — Tier 3 ayrı plan

## 8. İlişkili

- **ADR'ler:** ADR-001 (multi-project), ADR-003 (plan-first tier sistemi — bu plan-first ilk canlı uygulaması)
- **Önceki plan:** Yok (ilk yazılan plan)
- **Sonraki plan:** `plans/01-mayis-kampanya-tahmini.md` (numara önce ama yazım sonra), `plans/03-bi-trafik-dashboard.md` (Faz 4 ileride)
- **TODO ID'leri:** B-22 ana, B-22.0..B-22.18 alt-adımlar
- **TODO bağlantı:** B-08 (EncoreMerkez Products ↔ DerinSIS urn mapping) — FSM kategori sepet kırılımı için bu plan tamamlanması gerek (sayıcı verisi ile çapraz)
- **Konuşma referansı:** `docs/journal/_crossproject/2026-04-27.md` (Oturum 5 hızlı analiz), `briefings/2026-04-28-fsm-trafik/rapor.md` (pilot)
- **Mevcut çıktı (pilot Tier 2):** `briefings/2026-04-28-fsm-trafik/rapor.md` + `index.html` — bu plan üretildikten sonra "Faz 0 önce-pilot kanıtı" olarak referans

## 9. Onay

> **Kullanıcı onay verene kadar implement edilmez.**

Onay sırasında ele alınması gereken sorular:

1. **Faz sırası ve süresi** mantıklı mı? Toplam ~6-8 gün tahmin (kişi/saat). FAZ 4 (saat bazlı, dashboard) bu plana dahil değil — kabul mü?
2. **Seçilen alternatif C (CSV BULK INSERT)** uygun mu, yoksa B (API) öncelikli mi tercih edersin?
3. **B-22.0** vendor keşfi için kim sorumlu — IT departmanı mı, şube müdürü mü? Bilgi alabilir misin?
4. **Faz 4 (saat bazlı + diğer mağazalar + dashboard)** ayrı planlar olsun mu yoksa bu plana eklensin mi (kapsam genişler)?
5. **B-08 ile bağlantı** — FSM kategori sepet kırılımı bu plan ile birlikte mi yapılsın, ayrı mı? Sayıcı + kategori birleşince güçlü içgörü çıkar.

---

**Onay alındıktan sonra:**
- TODO.md'ye B-22.0..B-22.18 alt-adımlar eklenecek (Faz 1 tabloya).
- Implementation commit'lerinde plan referansı: `feat(bkm): trafik tablo (plan: 02)`
- Plan dosyası tamamlanınca `plans/archive/02-fsm-trafik-analiz.md`'a taşınacak.
- Done criteria check edilecek, journal'a özet.
