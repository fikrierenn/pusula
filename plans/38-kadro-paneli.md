# plan-38 · Kadro / Sezon Personeli Paneli (dashboard)

**Durum:** UYGULANDI — build yeşil, canlı doğrulama `.env ZIRVE_PASSWORD` bekliyor (Tier 3) · **Tarih:** 02.09.2026 · **Tetik:** "bu analizi dashboard'a ekle"

## Problem

Sezon kadrosu analizi (sezonluk/kadrolu ayrımı, 30.06 taban → 31.08 kesim, iş hacmi karşılaştırması) şu an tek seferlik: `sorgular/2026-09-02-*.sql` + `briefings/sezon-kadro-20260902/*.xlsx`. Her sorulduğunda elle üretiliyor. Dashboard'da kalıcı sayfa olursa kesim tarihleri parametrik, rakamlar canlı olur.

## ⚠ BLOKER — Zirve verisine dashboard'dan erişim yok

| Katman | Durum |
|---|---|
| Kadro verisi | Zirve `BKM_GENEL.dbo.vw_PersonelDepartman` (192.168.40.25\ZRVSQL2008) |
| Dashboard bağlantıları | `Db.OpenAsync()` → 192.168.40.201 · `OpenJokerAsync()` → .70 · `OpenPanel()` → localhost. **Zirve YOK.** |
| Linked server | 201'de `[ZIRVE]` **var** (remote login `kutlama`) |
| Test sonucu (02.09.2026) | `OPENQUERY([ZIRVE],'... vw_PersonelDepartman')` → **"SELECT permission was denied"**; `perbilgi` de aynı. Yani linked server ayakta ama `kutlama` login'inin İK objelerinde okuma yetkisi yok. |
| Kıyas | Trafik sayfası PDKS'i `OPENQUERY([PDKS],...)` ile okuyor (remote login `pdksrapor`, yetkili) → desen mevcut, yalnız Zirve tarafında yetki eksik. |

**KARAR: Yol B seçildi (02.09.2026)** — dashboard'a doğrudan Zirve bağlantısı. Alternatifler kayıt için aşağıda:

| # | Yol | Gerekli | Artı | Eksi |
|---|---|---|---|---|
| **A** | `kutlama` login'ine Zirve'de SELECT yetkisi verilsin (yalnız `vw_PersonelDepartman`, gerekiyorsa `puanbil`) | Zirve DB admin 1 GRANT | Kod tarafı hazır desen (PDKS gibi), yeni sır yok, en hızlı | Yetki İK verisine açılır → salt-okuma + tek view ile sınırlanmalı |
| **B** | Dashboard'a doğrudan Zirve bağlantısı (`Db.OpenZirveAsync`) | Yeni `.env` anahtarları (ZIRVE_HOST/USER/PASSWORD) + `Db.cs` + `ServiceRegistration` | Linked-server bağımlılığı yok, perf daha iyi | Yeni sır yönetimi, yeni bağlantı yüzeyi, güvenlik incelemesi |
| **C** | Gece job'u ile toplu özet 201'e yazılsın (`bkm.KadroOzet`), dashboard salt-okur | SQL Agent job + **yeni app-owned tablo onayı** (`erp-write-policy.md` istisna listesine eklenmeli) | Dashboard hızlı, KVKK açısından en temiz (yalnız toplulaştırılmış satır), Zirve'ye canlı bağımlılık yok | Veri 1 gün gecikmeli, job bakımı, ERP yazma politikası güncellemesi gerekir |

**Önerim: A** (tek GRANT, mevcut desen). A mümkün değilse **C** (KVKK açısından en temiz), **B** son çare.

## Kapsam (onay sonrası)

- `dashboard/Data/KadroQueries.cs` (yeni) — 4 metot: dönem KPI · şube×grup (sezonluk/engelli/etkinlik/diğer) · taban→kesim akışı · iş hacmi karşılaştırması (EncoreMerkez, mevcut `OpenAsync`).
- `dashboard/Components/Pages/Kadro.razor` (yeni) — 2 kesim seçici (taban tarihi + kesim tarihi), 4 KPI, akış grafiği, şube tablosu, iş hacmi tablosu.
- `dashboard/Models/NavRegistry.cs` — tek satır: `new NavItem("kadro", "Kadro", "users-round")`.
- `sema/entities.yaml` — linked-server erişim notu (yetki durumu + hangi login).

**Kapsam DIŞI:** kişi-düzeyi liste (KVKK — dashboard yalnız toplulaştırılmış), ücret/maliyet (birim karışıklığı, ayrı iş), engelli reyon kırılımı (özel nitelikli veri).

## Riskler

1. **KVKK m.6** — engelli sayısı özel nitelikli. Dashboard'da yalnız şube-toplamı; reyon/isim yok. Sayfa auth arkasında (mevcut `AuthService`).
2. **Perf** — linked-server OPENQUERY her istekte Zirve'ye gider. Tek view + WHERE ile küçük sonuç; gerekirse 5 dk memory cache.
3. **Yanlış kıyas riski** — "bugün aktif" yıllar arası kıyaslanamaz (censoring). Sayfa **taban/kesim** modelini zorunlu kılar; ham "aktif" tek başına gösterilmez. Kural: `sema/metrics.yaml → sezon_personel_kohort`.
4. **`Kadro` alanı kirli** — 12 NULL/boş + "PART-TIME"/"PART TIME" iki yazım. Sorguda normalize; sayfada "tanımsız" satırı görünür kalsın (gizlenmesin).

## Done kriterleri

- [ ] Sayfa açılıyor, taban 30.06 / kesim 31.08 seçiliyken **SP rakamlarıyla birebir**: sezonluk 65→62, kadrolu 135→149, taban 139→153, ürün adedi (takvim-tarihli, DerinSIS) +%16,2.
- [ ] `dotnet build` yeşil, sayfa yükleme < 3 sn.
- [ ] Nav'da tek satır, mobil btm-nav'a eklenmedi (kalabalık).
- [ ] KVKK: sayfada isim/personel no/ücret YOK.

## Rollback

Tek sayfa + tek Queries dosyası + tek nav satırı → `git revert`. Yol A seçilirse GRANT geri alınır (`REVOKE SELECT`).

## Adımlar

1. Erişim yolu onayı (A/B/C) + gerekiyorsa GRANT/job.
2. `KadroQueries.cs` — önce tek metot (şube×grup), MCP'de doğrulanmış SQL'i port et.
3. Mutabakat: Excel `magaza-tablo.xlsx` ile birebir kontrol.
4. `Kadro.razor` iskelet → KPI → tablo → grafik (charts.js, DaisyUI token).
5. Nav satırı + build + smoke.
6. `veri-dogrula` QA → sema notu → planı `plans/archive/`'a taşı.

## İlişkili

- `sorgular/2026-09-02-sezon-personel-kohort-magaza.sql` (kohort/censoring çekirdeği)
- `sorgular/2026-09-02-kadro-vs-is-hacmi-savunma.sql` (iş hacmi çekirdeği, blok 10)
- `scripts/magaza_tablo_excel.py` · `scripts/patron_ozet_excel.py` (mevcut emitter'lar — aynı çekirdek)
- `.claude/rules/erp-write-policy.md` (yol C seçilirse güncellenir)
- `dashboard/Data/TrafikQueries.cs` (OPENQUERY deseni örneği)


---

## Uygulama kaydı (02.09.2026)

**Yapılanlar** (build yeşil, 0 uyarı):
- `dashboard/Data/Db.cs` — `OpenZirveAsync()` + `ZirveEnabled`. Salt-okuma; `.env` `ZIRVE_HOST/DATABASE/USER/PASSWORD`.
  `ZIRVE_PASSWORD` boşsa bağlantı kurulmaz, panel uyarı gösterir (sessiz hata yok).
- `dashboard/Models/KadroModels.cs` — 4 record, tamamı toplulaştırılmış (kişi satırı yok).
- `dashboard/Data/KadroQueries.cs` — 4 metot: `GetOzetAsync` · `GetSubeGrupAsync` · `GetTutunmaAsync` · `GetIsHacmiAsync`.
- `dashboard/Components/Pages/Kadro.razor` — `/kadro`; taban+kesim+sezon başı seçici, 4 KPI, şube×grup tablosu, tutunma tablosu, iş hacmi tablosu.
- `dashboard/ServiceRegistration.cs` + `dashboard/Models/NavRegistry.cs` — DI + tek nav satırı.

**MUTABAKAT — İK'nın SP'si referans alındı:**
`Zirve dbo.sp_PersonelKarsilastirma_Ozet` gövdesi incelendi (kullanıcı paylaştı; `sys.sql_modules` NULL döndüğü için okunamıyordu).
Konvansiyonu: as-of aktif = `Igt <= T AND (Ict IS NULL OR Ict >= T)`, kıyas = tarih vs `DATEADD(YEAR,-1,...)`, kapsam tüm lokasyon, kırılım Lokasyon+AltLokasyon+AltAltLokasyon, kadro tipi ayırmaz.
İlk sürümde `Ict > T` kullanılmıştı → kurumsal rapordan düşük çıkıyordu. **Panel SP formülüne çekildi.**

| Ölçü (mağazalar) | `Ict >` (eski) | `Ict >=` (SP, geçerli) |
|---|---|---|
| Sezonluk 31.08 | 64 → 61 | **65 → 62** |
| Kadrolu 31.08 | 132 → 148 | **135 → 149** |
| Kadrolu taban 30.06 | 133 → 150 | **139 → 153** |
| Taban farkı | +17 | **+14** |
| Sezon içi kadrolu | −2 | **−4** (2025 de −4) |

Doğrulama (tüm lokasyon, 31.08): SP 322 → 335 (+13) · aynı formülle bu panel 322 → 335 ✓

**Kalan (done kriterleri):**
- [ ] `.env` `ZIRVE_USER` + `ZIRVE_PASSWORD` girilecek (kullanıcı) → panel canlı doğrulanacak.
- [ ] Canlı mutabakat: taban 30.06 / kesim 31.08 seçiliyken sezonluk 65→62, kadrolu 135→149, ürün adedi (3 mağaza, takvim-tarihli) +%16,2.
- [ ] Sayfa yükleme < 3 sn (Zirve OPENQUERY yok, doğrudan bağlantı — ölçülecek).
- [x] Nav tek satır, mobil btm-nav'a eklenmedi.
- [x] KVKK: sayfada isim/personel no/ücret yok.

## Düzeltme kaydı (02.09.2026, ikinci tur)

1. **Kadrolu kesim 150 → 149** (dolayısıyla sezon içi −3 → **−4**, iki yılda da aynı). İlk sayımda `perbilgi`
   LEFT JOIN'i satır çoğaltıyordu; temiz sayım `vw_PersonelDepartman` tek tablo üzerinden yapıldı.
   Doğrulama: `Lokasyon LIKE 'MA%'` toplam 31.08 → 2025: 200 kişi (135 kadrolu + 65 sezonluk) ·
   2026: 211 kişi (149 + 62).
2. **İş hacmi EncoreMerkez → DerinSIS** (`GetIsHacmiAsync`): POS geçişi (Tem 2025) EncoreMerkez'in 2025
   tabanını yapay küçültüyordu (sahte +%67 adet / +%97 ciro). Fiş ve sepet kolonları kaldırıldı —
   eTip 100 günlük özet, fiş sayısı yok; yerine **mutlak adet ve ciro** (2025 → 2026) + Δ gösteriliyor.
3. **Takvim hizalama uyarısı** panele eklendi: sayfa takvim-tarihli kıyas yapar; okul açılışı kayınca
   (8 Eyl 2025 → 14 Eyl 2026) Ağustos'ta yapay düşüş gösterir. Okul-hizalı doğru ölçüm arşiv SQL blok 11'de
   (adet 574.718 → 775.192 = +%34,9 · ciro KDV dahil 71,84M → 122,60M = +%70,7 · kadro 143 → 160).
4. **Kıdem → verimlilik testi negatif çıktı** — "1 tecrübeli = 3 acemi" iddiası üç testte de doğrulanmadı;
   patron sayfasına konulmadı. Detay: `sema/metrics.yaml → ik_norm_kadro_turnover.KIDEM_VERIMLILIK_TESTI`
   ve arşiv SQL blok 12.
