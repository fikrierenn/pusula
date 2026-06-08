# Plan 03 — Pazartesi Brief Üretim Otomasyonu

**Tarih:** 2026-05-04
**Proje:** `bkm`
**Yazan:** Claude (oturum 4 May sabah) · Onay: Fikri
**Durum:** `Taslak`

## Problem

Send pipeline tam (Task Scheduler ✓ + dinamik tarih ✓ + send_mail.py ✓), ama **content pipeline yok** — `brief.html` her hafta MANUEL üretiliyor. Sonuç: 27 Nis ve 4 May Pazartesi mailleri gitmedi (bat tetiklendi ama HTML yoktu, ExitCode=3). Kullanıcı sitemi: "her seferinde sen mi yazacaksın".

## Scope

**Dahil:** `scripts/generate_brief.py` — SQL'den haftalık + aylık + (ay dönüşümünde) kategori verisi çekip iki ayrı şablonla `briefings/<MONDAY>/brief.html` + `brief.txt` üretir. Pazar 23:30 Task Scheduler'da çalışır. send_brief.bat 09:00'da gönderir.

**İçerik yapısı (kullanıcı kararı 4 May):**

İki düzey:

- **Ay dönüşümü Pazartesi** (her ayın ilk Pazartesi): `brief.monthly.html.tmpl`
  1. **ÖNCEKİ AY tam değerlendirme** — hedef vs gerçekleşme %, kategori bazlı (Kitap/Kırtasiye/Oyuncak/Hediyelik), 3 mağaza × kategori matrisi
  2. **Bu hafta** (geçen 7 gün) — standart hafta tablosu
  3. **Bu ay MTD** — küçük (3-7 gün), trend giriş
- **Normal Pazartesi** (ay içi): `brief.weekly.html.tmpl`
  1. **Bu hafta** — standart
  2. **Bu ay MTD ilerleyişi** — hedef vs gerçekleşme oranı

Script `is_first_monday_of_month(date)` ile karar verir.

**Hariç:** AI yorumu (manuel ekleme — Claude oturumda Pazartesi sabah eklenir, opsiyonel). JOKER e-ticaret + kitapsepeti + Heykel + 3 kafe (ayrı plan, kapsam genişler — bu plan sadece 3 Bursa fiziksel mağaza).

**Etkilenen dosyalar (~7):**
- `scripts/generate_brief.py` (yeni — ana iş)
- `briefings/template/brief.weekly.html.tmpl` (yeni — normal Pazartesi)
- `briefings/template/brief.monthly.html.tmpl` (yeni — ay dönüşümü)
- `briefings/template/brief.weekly.txt.tmpl` (yeni)
- `briefings/template/brief.monthly.txt.tmpl` (yeni)
- `scripts/register-brief-generator-task.ps1` (yeni — Pazar 23:30 + Pzt 06:00 yedek)
- `docs/projects/bkm/brief-otomasyon.md` (yeni — işletim notları)
- `sorgular/dwh/brief-haftalik.sql` (yeni — kanonik haftalık sorgu)
- `sorgular/dwh/brief-aylik-kategori.sql` (yeni — aylık + kategori, B-08 mapping bağımlı)

## Alternatifler

### A: Script + opsiyonel AI ek (SEÇİLDİ)
Python script Pazar gece SQL → şablon → HTML iskelet. AI yorumu sen istersen Pazartesi sabah Claude oturumda eklersin. Mail her halükarda gider (en kötü ihtimal "sade rakam").

### B: Tam otomatik LLM-yok
Sadece tablolar + statik aksiyon listesi. Hiç AI. Avantaj: %100 otomatik. Reddetme: "neden böyle oldu" yorumu yok, brief değer kaybeder.

### C: Cron'da Claude API çağrısı
Her Pazar 23:00'de API → prompt → tam brief. Reddetme: API ücreti, hata izleme zor, prompt maintenance, kayan rate limit. Single-user için overengineering.

## Riskler

| Risk | Etki | Mitigation |
|---|---|---|
| SQL sorgu fail (DB down vs.) | Brief boş gider | try/except + log + fallback "veri çekilemedi" notu |
| Şablon değişirse script güncellenmezse | Render bozuk | template versioning (`brief.v1.html.tmpl`) + script-template eşleşme test |
| Pazar gece bilgisayar kapalı | Brief üretilmez | StartWhenAvailable + Pazartesi 06:00 yedek tetik |

## Done Criteria

- [ ] `scripts/generate_brief.py` çalışıyor, `--date` parametresi ile herhangi bir Pazartesi için brief üretebilir
- [ ] `is_first_monday_of_month()` doğru karar veriyor → uygun şablon seçiliyor
- [ ] **Hedef tablosu integrasyonu** — `BKMDATA.dbo.Hedef` çekiliyor, gerçekleşme % hesabı doğru
- [ ] **Kategori bazlı (ay dönüşümü)** — DerinSIS `urn` × `urnKtgr2` × EncoreMerkez Sales köprüsü çalışıyor (B-08 mapping)
- [ ] 4 şablon (weekly html/txt + monthly html/txt) test edildi, doğru render
- [ ] Scheduled task: Pazar 23:30 + Pazartesi 06:00 (yedek) → idempotent
- [ ] **11 May Pazartesi (normal)**: weekly brief otomatik geldi, müdahale 0
- [ ] **1 Haziran Pazartesi (ay dönüşümü)**: monthly brief otomatik geldi, Mayıs tam ay + kategori dahil
- [ ] Hata: SQL/hedef/kategori sorgu fail → mail "veri çekilemedi" notu ile gider, hata sessiz değil
- [ ] Dokümantasyon: `docs/projects/bkm/brief-otomasyon.md`

## Adımlar

1. **Faz 0 (2 saat):** Bu hafta brief.html + brief.txt'i 2 şablona dönüştür (weekly + monthly), Jinja2 placeholder'lar belirle
2. **Faz 1 (3 saat):** `generate_brief.py` — SQL haftalık + MTD sorguları + şablon doldurma + dosya yazma. Hata yönetimi + log
3. **Faz 2 (3 saat):** **Hedef tablosu (BKMDATA.dbo.Hedef)** entegrasyonu — gerçekleşme % hesabı, mağaza × dönem
4. **Faz 3 (4 saat):** **Kategori bazlı sorgu (B-08'e bağlı)** — `urn` ↔ `Products` köprüsü, kategori toplama, mağaza × kategori matrisi
5. **Faz 4 (1 saat):** Scheduled task kurulum + test
6. **Faz 5 (canlı, 4 hafta):** 11 May (weekly), 18 May (weekly), 25 May (weekly), **1 Haz (monthly first run)** gözlem + ince ayar

**Toplam: ~2 iş günü (12-15 saat)** — ay-dönüşümü ve kategori eklenince genişledi.

**MVP yaklaşımı:** Faz 0+1+4 önce yapılır (hafta-only otomatik), 11 May'da test edilir. Faz 2+3 (hedef + kategori) sonraki hafta. Bu sayede 11 May'da en azından sade weekly brief otomatik gider, riski düşük.

## İlişkili

- ADR-003 (plan-first), Plan-02 (FSM trafik — bağımsız)
- Önceki brief: `briefings/2026-04-27/`, `briefings/2026-05-04/` (manuel template kaynak)
- TODO: B-21 (bu plan onaylandığında alt-adımlara bölünecek)
- Konuşma: bugünkü "neden otomatik yapmamış" sitemine yanıt

## Onay

> **Kullanıcı onay verene kadar implement edilmez.**

3 soru:

1. **MVP-first yaklaşımı** kabul mü? Yani: 11 May için sade weekly brief otomatik (Faz 0+1+4, ~6 saat). Hedef + kategori sonraki hafta (Faz 2+3, +6 saat). 1 Haz monthly canlı.
2. **Kategori bazlı:** B-08 (EncoreMerkez Products ↔ DerinSIS urn mapping) henüz çözülmedi. Bu plan B-08'i de içine almalı mı, yoksa B-08 önce ayrı çözülsün mü? (Birlikte: scope büyür ama bütüncül. Ayrı: bu plan kategoriyi placeholder bırakır, B-08 bittiğinde doldurulur.)
3. **Hedef tablosu:** BKMDATA.dbo.Hedef şeması nasıl? Mekan × ay mı, mekan × hafta mı? Şimdi bilmiyorum, Faz 2 başında keşif gerekecek.

**Faz 0+1'i (sade weekly) bu hafta içinde bitirebilirim. Onay?**
