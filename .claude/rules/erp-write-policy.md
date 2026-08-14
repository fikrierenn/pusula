# ERP Yazma Politikası (KRİTİK — kullanıcı direktifi 23.06.2026)

> Core rule. `paths:` yok — compact sonrası survive. Güvenlik sınıfı: veri-bütünlüğü.

## Mutlak Kural

**ERP / production veritabanlarına izinli yazma hedefleri = SADECE app-owned `bkm.*` tabloları: `bkm.Fin_AyKapanis` (dashboard) + `bkm.BankaOgrenme` (muhasebe app) + `bkm.StokAyBakiyeMekanBazli` (stok geçmiş, SQL job) + `bkm.BulunurlukOzet` + `bkm.BulunurlukKayip` (bulunurluk pre-agg, SQL job). Başka HİÇBİR tabloya / DerinSIS native tabloya / başka şemaya yazma YOK.**

Kullanıcı direktifi (verbatim): _"sadece o tabloya yazacaksın, başkası yasak"_ (23.06 Fin_AyKapanis) · _"bkm şeması olarak"_ (04.07 BankaOgrenme) · _"pre-agg tabloları oluştur"_ (14.08 Bulunurluk — plan-33, OSA özet deposu; dense StokAyBakiyeMekanBazli + BulunurlukOzet/Kayip SQL job'la yazılır, dashboard salt-okur).

> **İlke:** `bkm` şeması = Fikri'nin app-owned namespace'i (DerinSIS native `dbo`/`mhs`/`ent` DEĞİL). Yeni app-owned `bkm.*` tablosu yazımı yalnız kullanıcı açık onayıyla + bu kurala eklenerek. DerinSIS native tablo (car/fat/irsHrk/mhsFis…) yazımı MUTLAK YASAK.

## Bağlantı Bazlı Yetki

| Bağlantı (Db.cs) | Hedef | Yazma izni |
|---|---|---|
| `Db.OpenAsync()` | 192.168.40.201 — **DerinSISBkm / EncoreMerkez / BKM (ERP)** | **SALT-OKUMA** — istisna yalnız app-owned `bkm.Fin_AyKapanis` + `bkm.BankaOgrenme` (INSERT/UPDATE/DELETE). Başka tablo / native tablo yazımı YASAK. |
| `Db.OpenJokerAsync()` | 192.168.40.70 — **JOKER e-ticaret** | **SALT-OKUMA** — istisna yok. |
| `Db.OpenPanel()` / `OpenPanelAsync()` | localhost — **BkmPanel (app-local)** | Yazma SERBEST ama yalnız `dbo.Panel*` kendi tabloları (auth/görev/bellek/tahmin/takvim/içkart). Bu panelin kendi durum deposu, ERP değil. |

## Neden

ERP (DerinSIS/EncoreMerkez) canlı muhasebe/satış/stok sistemi. Yanlış/kazara yazma = veri bozulması, mutabakat kaybı, geri-alınamaz. Panel salt-okuma analitik araç; tek meşru ERP-yazması ay-kapanış tarihi girişi (`Fin_AyKapanis`, Kontrol panelinin tarama dönemini belirler).

## Uygulama (geliştirici + AI)

1. **Yeni ERP yazma kodu (`Db.OpenAsync` üstünden INSERT/UPDATE/DELETE/MERGE/EXEC-write) yazmadan ÖNCE DUR.** Hedef `bkm.Fin_AyKapanis` değilse → **YAZMA**, kullanıcıya sor. Onay alınırsa bu kuralı güncelle (tabloyu istisna listesine ekle).
2. `Db.OpenAsync` ile çalışan SP'ler salt-okuma rapor SP'si olmalı (ör. `sp_KapanisMudahaleKontrol_v2` — SELECT-only). Yazan SP EXEC etme.
3. Mevcut uyumlu kod: `MuhasebeQueries.UpsertKapanisAsync` / `DeleteKapanisAsync` — tek meşru ERP-yazıcı. Diğer tüm `*Queries.cs` (Mizan/Ref/Magaza/Etic/Sadakat/Queries) salt-SELECT.
4. **MCP** `mcp__sqlserver__*` zaten `ALLOW_WRITE=false` (salt-okuma guard) — açma.

## Önerilen Sertleştirme (DB-seviyesi — gerçek zorlama)

Kod-disiplini + bu kural ilk savunma. **Asıl garanti:** dashboard'ı `sa` yerine kısıtlı login ile çalıştır:
- Yeni SQL login `bkm_panel_rw`: `DerinSISBkm`'de `db_datareader` + yalnız `GRANT INSERT, UPDATE, DELETE ON bkm.Fin_AyKapanis`.
- `.env` `MSSQL_USER` bunu kullansın. O zaman hatalı kod bile başka tabloya yazamaz (server reddeder).
- Script hazır değil — kullanıcı DB-admin ile uygulayınca `.env` güncellenir. (Şimdilik `sa` + kod-disiplini.)

## İlişkili
- `.claude/rules/security-principles.md` — genel güvenlik.
- `.claude/rules/before-major-change.md` — yazma = büyük değişiklik, onay gerekir.
- `dashboard/Data/MuhasebeQueries.cs` — tek meşru ERP-yazıcı (Fin_AyKapanis).
- `dashboard/Data/Db.cs` — bağlantı fabrikası (OpenAsync/OpenJoker/OpenPanel ayrımı).
