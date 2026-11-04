# Veri modeli — 002 Telefon kabuğu ve ekranlar

**Özet:** Tek yeni tablo: **`BkmPanel.dbo.PanelOturum`** (plan K12; panelin kendi deposu, `SANAL-FIKRI`, ERP değil). Başka yeni ya da değişen tablo, kolon, view, fonksiyon, SP, tip veya SQL Agent job yoktur. Migration: idempotent kurulum betiği + geri alma betiği (§ 6). **Veri kaybı: yok.** ERP, POS, e-ticaret ve app-owned `bkm.*` tablolarına yazılmaz (FR-013, `erp-write-policy.md`). Panel veritabanındaki görev ve asistan yazmaları bugünkü gibi sürer; yeni yazma yolu eklenmez.

## 1. Kodda tutulan durum (tablo değil)

| Bilgi | Yer | Neden tablo değil |
|---|---|---|
| 001 bağımlılığı (ekran/kart → gerekli maddeler) | `dashboard/Models/TelefonKapisi.cs` `Bagimlilik` | Spec tablosunun kod karşılığı; birim testi spec ile eşitliği denetler (`kontratlar/telefon-kapisi.md`) |
| Kapanmış 001 maddeleri | `TelefonKapisi.KapananMaddeler` | Açılış kanıta (git'teki `specs/001-panel-veri-duzeltme/kabul-sonucu.md`) bağlı, incelenen commit'le olur. Yapılandırma ya da `dbo.PanelAyar` kanıtsız açılmaya izin verirdi (plan K1) |
| Ekran sınıfı ve telefon sekmesi | `dashboard/Models/NavRegistry.cs` (`Sinif`, `MobilSekme`) | Menünün tek kaynağı zaten bu kayıt |
| Bugün kart tanımları ve renk eşikleri | `Components/Shared/Bugun/*` + `dashboard/Models/BugunRenk.cs` | Spec sabitleri (−%5/−%10, %95/%85, %3, 2–3 g/4 g) |
| Eski adres eşlemesi | `Components/Pages/EskiAdres.razor` | Altı sabit adres |

## 2. Okunan kaynaklar

Yeni kaynak yok (spec § Veri kaynağı). Kartlar ve telefon özetleri bugünkü sorgu metotlarını çağırır:

| Kart / özet | Metot | Kaynak (compat) |
|---|---|---|
| Kart 1, 2, Ana sayfa | `Queries.GetPeriodAsync`, `GetHedefAsync`, `GetTahminAsync` | EncoreMerkez (110), DerinSISBkm (150), BKMDATA (150) |
| Kart 1a, Sınav | `SinavQueries` (Sınav KPI) | BKM (150), EncoreMerkez (110) |
| Kart 3 | `UyariKurallari` (Ana sayfa verisi üstünde; tanım GMY kararına bağlı) | — |
| Kart 4, E-ticaret | `EticQueries.GetBekleyenAsync` | JOKER (150) |
| Kart 5, Cari/Risk | 001 Cari/Risk ek maddesinin düzelttiği çekirdek (`FinansQueries`); 002 hesap yazmaz | DerinSISBkm (150) `dbo.bakiyeVDGG_vw` |
| Kart 7, Görevler, rozet | `GorevService.Listele` + `Ozet` | BkmPanel `dbo.PanelGorev` |
| Kart 8, Vardiya | `VardiyaQueries.GetComplianceAsync` (+ şube parametresi, Dalga 2) | BkmPanel (dev) `bkm.Vrd_*` |
| Muhasebe özeti | `MuhasebeQueries` (`bkm.sp_KapanisMudahaleKontrol_v2`, salt-okuma) | DerinSISBkm (150) |
| Gelir tablosu özeti | `GelirTabloQueries` + `Ozetle`; kapanmış son ay `bkm.Fin_AyKapanis` (okuma) | DerinSISBkm (150) |

## 3. Tek SQL değişikliği (Dalga 2): `VardiyaQueries.GetComplianceAsync`

- İsteğe bağlı `string? branch` parametresi eklenir; `null` bugünkü sonucu birebir verir (koruma testi).
- Sorgudaki **her** kapsamlı tablo referansı şube süzgecini ayrıca taşır (`sql-server-conventions.md` § kapsam süzgeci her alt sorguda ayrı). Kapı: `python tools/vardiya_kapsam_denetimi.py` çıkış 0.
- Değişmez test: Σ şube sonuçları = şube süzgeçsiz sonuç (her sayaç için).
- Hedef: BkmPanel (dev, `SANAL-FIKRI`), salt-okuma. Yazma yok.

## 4. Cihazda saklanan veri

Yok (FR-011). Service worker önbelleğinde yalnız `offline.html`, `app.css` ve ikonlar durur; HTML sayfa, `/_blazor` ve veri önbelleğe girmez. HTML yanıtı `Cache-Control: no-store` taşır. Ayrıntı `kontratlar/kabuk.md` § Service worker.

## 5. Standart kolonlar, migration, geri alma

Yeni tablo olmadığı için standart kolon (`IsValid`, `OlusturmaTarihi` …) ve migration yoktur. Geri alma `git revert` ile yapılır. Birleşen ekran dosyaları silinmez; `@page` satırı geri eklenip yönlendirme kaldırılınca eski ekran döner.

## 6. `BkmPanel.dbo.PanelOturum` (plan K12)

| Kolon | Tip | Null | Varsayılan | Not |
|---|---|---|---|---|
| `Id` | `uniqueidentifier` | hayır | — | PK (`PK_PanelOturum`); çerezdeki `oid` talebi |
| `KullaniciId` | `int` | hayır | — | FK `FK_PanelOturum_PanelKullanici` → `dbo.PanelKullanici(Id)` |
| `MutlakBitis` | `datetime2(3)` | hayır | — | Açılış + 7 gün (UTC) |
| `SonGorulme` | `datetime2(3)` | hayır | — | Son etkileşim (UTC); en çok dakikada bir yazılır |
| `CihazOzeti` | `nvarchar(60)` | evet | — | `User-Agent`'tan türetilmiş kısa metin ("Android · Chrome"); ham değer ve IP tutulmaz |
| `IptalNedeni` | `nvarchar(20)` | evet | — | `cikis` · `hepsi` · `bosta` · `mutlak` (`CK_PanelOturum_IptalNedeni`) |
| `IsValid` | `bit` | hayır | `1` (`DF_PanelOturum_IsValid`) | 0 = oturum kapandı (soft delete) |
| `OlusturmaTarihi` | `datetime2(3)` | hayır | `SYSUTCDATETIME()` | Oturum açılışı |
| `GuncellemeTarihi` | `datetime2(3)` | evet | — | Son durum değişikliği (iptal) |

- İndeks: `IX_PanelOturum_KullaniciId_IsValid (KullaniciId, IsValid) INCLUDE (MutlakBitis, SonGorulme)` — "bütün oturumları kapat" ve liste sorgusu; FK indeksi de bunu karşılar (DDL-005).
- `OlusturanKullanici`/`GuncelleyenKullanici` standart kolonları yok: satırın sahibi zaten `KullaniciId`, değiştiren yalnız aynı kullanıcı ya da sistemin süre kuralı (`IptalNedeni` bunu ayırır). Sapma bilerek; Orkestra DDL standardına karşı gerekçeli.
- Tarih tipi `datetime2(3)` UTC; ekranda yerel saate çevrilir (gg.aa.yyyy ss:dd).
- **Silme yok** (RUN-008): satırlar `IsValid = 0` ile kapanır. Saklama süresi hukuka soruldu (KVKK S8, öneri 1 yıl); karar gelince ayrı iş olarak arşivleme ya da silme onayı alınır. Hacim: günde birkaç satır.
- **Yazma yolu:** yalnız `OturumService` (`Db.OpenPanelAsync()`). Yazılan ifadeler: giriş `INSERT` (kolon listeli), çıkış/iptal `UPDATE … SET IsValid = 0, IptalNedeni = @n, GuncellemeTarihi = SYSUTCDATETIME() WHERE …`, `SonGorulme` `UPDATE`. `MERGE` yok. Paneldeki mevcut desen satır içi SQL; SP kullanılmaz (panel tabloları için mevcut desen, `desenler.md` § 4).
- **Kurulum:** `sorgular/2026-10-xx-panel-oturum-kur.sql` — `IF OBJECT_ID(N'dbo.PanelOturum', N'U') IS NULL CREATE TABLE …`; kısıtlar ve indeks adlı ve koşullu. Geri alma: aynı dosyada yorum bloğu `DROP TABLE dbo.PanelOturum` (yeni tablo; düşürülünce yalnız oturum kayıtları gider, kullanıcılar giriş yeniden yapar). Hedef: BkmPanel dev (`SANAL-FIKRI`). Mevcut `Panel*` servislerinin "yoksa oluştur" deseni (`AyarService.cs:26`) bu tablo için kullanılmaz: kısıt ve indeks adlı, incelenebilir bir betikte durur.
- **Test yazması:** entegrasyon testi BkmPanel'e `zz_test_` önekli bir test kullanıcısıyla yazar ve kendi bağlantısında geri alınan transaction içinde koşar (`erp-write-policy.md` § test yazması deseni; `dbo.Panel*` panelin kendi deposu). Salt-okuma `LiveDb` bu test için kullanılmaz.
