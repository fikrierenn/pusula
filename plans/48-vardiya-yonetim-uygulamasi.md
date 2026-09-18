# 48 — Vardiya Yönetim Uygulaması (ayrı app + ortak kütüphane)

**Durum:** TASLAK — onay bekliyor · **Tier:** 3 · **Tarih:** 18.09.2026
**Karar sahibi:** Fikri Eren (GMY) — *"vardiya yönetimi için ayrı bir program yapı yazmalıyız"*
**Önceki plan:** `plans/47-vardiya-eksik-fazla-sql.md` (Faz 1 tamam — `bkm.Vrd_*` + `sp_Vrd_KisiGunDoldur`, parite 0 fark)

## Problem

Vardiya/mesai işi bugün **GMY panelinin içinde** yaşıyor (`dashboard/Components/Pages/Vardiya.razor`
549 satır + `dashboard/Data/VardiyaQueries.cs` 324 satır). Üç şey bunu sürdürülemez yapıyor:

1. **Kullanıcı kitlesi farklı.** Onay akışını mağaza müdürü ve İK yürütecek; personel kendi
   kaydını görecek. GMY paneli ciro, marj, satınalma, stok taşıyor — o veriyi mağaza
   müdürüne ve personele açmak istenmiyor. Bugün panelde **rol ayrımı YOK** (ÖLÇÜLDÜ:
   `dashboard/Data/AuthService.cs` — `PanelKullanici` tek-kullanıcı, PBKDF2, rol kolonu yok).
2. **Yazan taraf büyüyor.** Panel bugüne dek salt-okumaydı; tek yazması `Fin_AyKapanis`'ti.
   Onay akışı düzenli, çok-kullanıcılı YAZMA getiriyor — ayrı sorumluluk, ayrı denetim izi.
3. **Kesinti yüzeyi ortak.** Panelin ağır sorgusu (satış analizi, drill) vardiya onayını da
   yavaşlatır; panel deploy'u onay akışını da kesintiye uğratır.

## Kapsam — İLK SÜRÜM (GMY kararı 18.09)

**İÇİNDE:**
- **Yönetici onay akışı** — eksik/fazla satırına onaylı giriş/çıkış, evden çalışma / ek mesai,
  gerekçe, onaylayan + zaman damgası.
- **Eksik/fazla + mesai raporu** — bugün `Vardiya.razor`'un gösterdiği okuma yüzü, yeni
  uygulamaya taşınır (KPI, durum kırılımı, şube kırılımı, kalma bandı, mevzuat/uyum kapısı).

**DIŞINDA (ayrı karar, ayrı faz):**
- Vardiya **planı girişi** (kim hangi gün hangi vardiyada) — bugün sistemde yok, kaynağı
  Excel. İlk sürümde plan yine mevcut kaynaktan okunur.
- **İzin günü / hafta tatili tanımı** — 18.09'da konuşuldu (*"şubelerdeki personellere de
  sabit izin günü yapmak gerekiyor"*), kapsam dışı bırakıldı.
- Bordro/ödeme entegrasyonu.

> İlk sürüm **hesabı değiştirmez.** Hesap `bkm.sp_Vrd_KisiGunDoldur` içinde kalır ve plan-47
> parite kapısı geçerliliğini korur. Bu plan yalnız **kimin nereden eriştiğini** değiştirir.

## Roller ve yetki matrisi (GMY kararı 18.09 — dört rol)

| Rol | Görür | Yazar | İlk sürüm |
|---|---|---|---|
| **Mağaza müdürü / şube sorumlusu** | yalnız KENDİ şubesi | kendi şubesinin onay satırları | ✅ açık |
| **İK** | tüm şubeler | tüm onaylar + kapanış | ✅ açık |
| **GMY** | tüm şubeler | — (salt-okuma + denetim) | ✅ açık |
| **Personel** | yalnız KENDİ kişi-gün kaydı ve eksik/fazla bakiyesi | — | ❌ **KAPALI** (GMY kararı 18.09) |

**Personel rolü ilk sürümde açılmaz** (GMY kararı 18.09: *"personel rolü şimdilik kapalı olsun"*).
Kazanç ölçülebilir: kullanıcı sayısı 362'den ~10-15'e iner (şube sorumluları + İK + GMY),
KVKK aydınlatma metni ve kişiye-açık veri yüzeyi ilk sürümden tamamen çıkar.
Rol **şemada tanımlı kalır** ama hiçbir hesaba atanmaz — Faz 2'de açmak yeni yapı değil,
yalnız hesap açmak olur.

⚠ **Şube sınırı bir güvenlik sınırıdır, bir UI filtresi değil.** Her sorguya şube süzgeci
sunucu tarafında, oturumdaki kimlikten konur; istemciden gelen şube parametresine GÜVENİLMEZ.

⚠ **KVKK:** personel rolü açıldığında kişisel çalışma verisini kişinin kendisine açar —
kapsam `SicilNo = oturum sahibi` ile sınırlı olacak, aydınlatma metni + erişim logu ZORUNLU
(`.claude/rules/security-principles.md` § Audit Logging). İlk sürümde rol kapalı olduğu için
bu yük ertelendi, **kaldırılmadı** — Faz 2'nin ön şartıdır.

## Kimlik doğrulama (GMY kararı 18.09 — domain hesabı YOK)

*"domain hesabı yok"* → Windows/Negotiate (muhasebe app deseni) **kullanılamaz**. Kullanıcı
adı + şifre gerekir.

- Panelin `AuthService` deseni aynen izlenir: **PBKDF2-SHA256 100k**, salt kolonu,
  başarısız sayaç + kilit SQL tarafında, şifre koda/env'e plain GİRMEZ.
- Kod **kopyalanmaz**: `AuthService` ortak kütüphaneye çıkarılıp iki app tarafından
  kullanılabilir mi, yoksa vardiya app'i kendi kopyasını mı taşır → Adım 4'te karara bağlanır.
  Varsayılan tercih: **ortak kütüphaneye al** (`emitter-ayrimi.md` tek-kaynak ilkesi), ama
  **kullanıcı TABLOLARI ayrı kalır** (`PanelKullanici` ≠ `Vrd_Kullanici`) — panelin tek-kullanıcı
  hesabı ile vardiya kadrosu karışmaz.
- İlk şifre dağıtımı: ~10-15 hesap (personel rolü kapalı olduğu için). İK'nın hesap açıp
  ilk şifreyi verdiği, kullanıcının ilk girişte değiştirdiği akış — ilk girişte değişim ZORUNLU.
- **Şifre sıfırlama** İK rolünde; sıfırlama denetim izine yazılır.

## Mimari — ayrı uygulama, ortak DB + ortak kütüphane

Repoda **ayrı app deseni zaten kurulu** (ÖLÇÜLDÜ): `dashboard/GmDashboard.csproj`,
`asistan/BkmAsistan.csproj`, `muhasebe/Muhasebe.csproj` — üçü ayrı web app.

```
vardiya-app/BkmVardiya.csproj      ← YENİ: Blazor Server, kendi portu, kendi auth'u
lib/BkmVardiya.Core.csproj         ← YENİ: ortak sınıf kütüphanesi
   Db.cs · VrdModels · VardiyaQueries · MevzuatKapisi
dashboard/GmDashboard.csproj       ← lib'e ProjectReference (kendi kopyası SİLİNİR)
```

- **Veri tabanı ortak:** `bkm.Vrd_*` (şimdi dev `BkmPanel`, terfide `DerinSISBkm` — plan-47).
  İki uygulama aynı tabloyu okur; yazan taraf yalnız vardiya app'i olur.
- **Hesap ortak:** `sp_Vrd_KisiGunDoldur`. Kopyalanmaz (`emitter-ayrimi.md` § tek hesap çekirdeği).
- **Panel ne olur:** GMY paneli vardiya sayfasını **salt-okuma özet** olarak tutar ya da
  tamamen bırakıp yeni app'e link verir — Adım 7'de karara bağlanır.

## Alternatifler (reddedildi)

1. **Panel içinde ayrı modül + rol.** En dar basamak (`footprint-ladder.md`) ve teklif edildi.
   GMY reddetti: mağaza müdürü ve personel GMY panelinin kapsamına alınmış olurdu; tek
   auth şemasına 300+ kullanıcı binerdi (ÖLÇÜLDÜ: aktif personel listesi 362 satır).
2. **Tam bağımsız uygulama, kod paylaşımı YOK.** Reddedildi: `VardiyaQueries` iki yerde
   yaşardı, biri güncellenir öteki bayatlardı — `emitter-ayrimi.md`'nin yasakladığı desen.
3. **Hazır PDKS/İK paketi satın alma.** Kapsam dışı — mevcut PDKS zaten var, eksik olan
   onay akışı ve eksik/fazla hesabı; hesap plan-47'de kanıtlandı.
4. **Panelin vardiya sayfasını olduğu gibi bırakıp yanına ikinci bir sayfa açma.** Reddedildi:
   yetki sorunu çözülmez, sadece ertelenir.

## Riskler

| Risk | Önlem |
|---|---|
| **Ortak kütüphaneye çıkarma dashboard'ı kırar** | `VardiyaQueries`/`VrdModels` taşınırken namespace değişir → derleme hatası GÖRÜLÜR (sessiz değil). Build yeşil + Vardiya sayfası smoke test kapatma ölçütü. |
| **Şube sınırı UI filtresine indirgenir** | Süzgeç sunucu tarafında, oturum kimliğinden. İstemci parametresiyle şube geçilemediği bir testle kanıtlanır (kırılabilirlik: testte süzgeç kaldırılır → RED görülür). |
| **Auth iki yerde ayrışır** | Yeni app kendi kullanıcı tablosunu kurar; panelin `PanelKullanici`'sine dokunulmaz. Ortak kütüphane auth İÇERMEZ. |
| 300+ kullanıcıya şifre dağıtımı | ✅ **KAPANDI 18.09** — personel rolü ilk sürümde kapalı, hesap sayısı ~10-15. |
| Domain yok → şifre yönetimi bize kalıyor | PBKDF2 + kilit + ilk-giriş değişimi zorunlu; panelin ölçülmüş deseni izlenir, yeni şifre şeması icat edilmez. |
| Dev/prod karışması | plan-47'deki `Kaynak` kolonu deseni sürer; app başlığında ortam etiketi görünür. |
| Uncommitted borç (19 dosya) plan başlarken karışır | Adım 0: commit-split. |

## KARARLAR ve KALAN AÇIK SORULAR

**Kapandı (GMY, 18.09):**
1. ✅ **Kimlik doğrulama** — domain hesabı YOK → kullanıcı adı + şifre (PBKDF2, panel deseni).
2. ✅ **Personel rolü** — ilk sürümde KAPALI.

**Açık ama işi bloklamıyor:**
3. **Erişim yeri:** yalnız şirket ağı mı, dışarıdan da mı? Dışarıdansa HTTPS sertifikası +
   ağ kuralı ayrı iş. → deploy adımında (Adım 7 sonrası) karara bağlanır.
4. **Panelin vardiya sayfası kalsın mı?** (GMY için salt-okuma özet vs. tamamen link.)
   → Adım 7.
5. **Şube ↔ kullanıcı eşlemesi nereden?** Müdürün hangi şubeye bağlı olduğu bir yerde
   yazılmalı. `Vrd_Kullanici.Sube` elle mi girilecek, `Vrd_Sube` ile mi doğrulanacak →
   Adım 4'te kararlaştırılır; **elle giriş seçilirse şubenin geçerliliği FK ile zorlanır**.

## Bitiş ölçütü (Definition of Done)

1. `dotnet build` yeşil — dashboard + yeni app + lib.
2. **Parite:** yeni app'in eksik/fazla raporu ile mevcut panel raporu aynı kesimde
   **birebir aynı** (0 fark). Ortak kütüphane doğru çıkarıldıysa bu tanım gereği tutmalı —
   tutmuyorsa çıkarma sırasında mantık sızmış demektir.
3. **Yetki testi:** müdür rolü başka şubenin satırını ne görebiliyor ne yazabiliyor;
   test kırılabilir olduğu gösterilerek yazılır (süzgeç kaldırılınca KIRMIZI).
4. Onay yazması denetim izi bırakıyor (kim, ne zaman, eski değer → yeni değer).
5. Smoke test: açık üç rolle (müdür / İK / GMY) giriş → beklenen kapsam görülüyor.
6. Personel rolüne atanmış hesap SIFIR (rol kapalı olduğu sorguyla doğrulanır).

## Adımlar

0. **Commit-split** — 19 uncommitted dosya (15 eşiği aşıldı, `commit-discipline.md`).
1. ✅ Auth yöntemi + personel rolü kapsamı kararı (18.09).
2. `lib/BkmVardiya.Core` kurulumu; `Db` + `VrdModels` + `VardiyaQueries` taşınır,
   dashboard `ProjectReference` ile aynı sınıfları kullanır. **Davranış değişmez** —
   panel sayfası aynı çalışır (build + smoke kanıt).
3. `vardiya-app` iskeleti: Blazor Server, DaisyUI tema (`renk-standardi.md`), Türkçe UI.
4. Auth + rol + şube sınırı; sunucu-taraflı süzgeç ve yetki testi.
5. Eksik/fazla + mesai raporu ekranı (mevcut sayfadan taşıma).
6. Onay akışı ekranı + denetim izi (`bkm.Vrd_Onay` üzerine log).
7. Panelin vardiya sayfasının akıbeti; nav düzenlemesi.
8. Parite + yetki testleri, journal + sema kaydı, TODO senkronu.

## Geri alma

Yeni app ayrı proje — çalışmazsa çalıştırılmaz, panel eski haliyle sürer. Tek geri-alınması
iş isteyen adım ortak kütüphaneye çıkarma (Adım 2); o adım kendi commit'inde tutulur ve
`git revert` ile tek hamlede dönülür. Veri tarafına DDL eklenmez — plan-47 tabloları aynen
kullanılır (yalnız denetim-izi tablosu eklenirse `erp-write-policy.md` güncellenir).
