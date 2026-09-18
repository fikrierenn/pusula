# 48 — Vardiya Yönetim Uygulaması (ayrı app + ortak kütüphane)

**Durum:** ONAYLANDI 18.09 · Adım 0-3 ✅ · **Adım 4 sırada (auth + rol + şube sınırı)** · **Tier:** 3 · **Tarih:** 18.09.2026
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

- ⭐ **Kendi `AuthService`'imiz YAZILMAYACAK** (18.09 kararı): Solum.Identity'nin
  `DapperUserStore`'u kullanılır — kullanıcı adı + şifre, kilit/başarısız sayaç, claim, rol.
  Panelin `AuthService`'i kopyalanmaz ve ortak kütüphaneye de taşınmaz.
- **Cookie şemasını uygulama kurar** — Solum kimlik doğrulama şeması kaydetmez, yalnız depo verir.
- **Kullanıcı tabloları panelden ayrı** (`PanelKullanici` ≠ Solum kullanıcı tabloları) —
  panelin tek-kullanıcı hesabı ile vardiya kadrosu karışmaz.
- İlk şifre dağıtımı: ~10-15 hesap (personel rolü kapalı olduğu için). İK'nın hesap açıp
  ilk şifreyi verdiği, kullanıcının ilk girişte değiştirdiği akış — ilk girişte değişim ZORUNLU.
- **Şifre sıfırlama** İK rolünde; sıfırlama denetim izine yazılır.

## Mimari — ayrı uygulama, ortak DB + ortak kütüphane

Repoda **ayrı app deseni zaten kurulu** (ÖLÇÜLDÜ): `dashboard/GmDashboard.csproj`,
`asistan/BkmAsistan.csproj`, `muhasebe/Muhasebe.csproj` — üçü ayrı web app.

```
vardiya-app/BkmVardiya.csproj      ← ✅ KURULDU — Razor Pages + Solum, port 5120 (Adım 3)
lib/Bkm.Shared/Bkm.Shared.csproj   ← ✅ KURULDU (Adım 2) — ortak sınıf kütüphanesi
   Data/Db.cs · Data/SqlErrorClassifier.cs · Data/VardiyaQueries.cs · Models/VardiyaModels.cs
dashboard/GmDashboard.csproj       ← ✅ ProjectReference + GlobalUsings.cs
```

## Solum — kimlik/yetki/arayüz omurgası (GMY kararı 18.09: *"solum framework var onu kullansana"*)

`D:\Dev\Solum` — kendi ortak katmanımız: kimlik, yetki, çok kiracılılık, denetim izi,
CRUD ve Razor arayüz kabuğu. Sekiz paket, sürüm 0.7.0.

**Uygulama Razor Pages'e çevrildi.** Ölçüldü: `Solum.Web` bir Razor Pages/MVC kütüphanesi
(`AddRazorSupportForMvc`, içerik `.cshtml`); `src/` altında `.razor` **0**, `ComponentBase` **0**.
Blazor'da kabuk/menü/CRUD temeli kullanılamaz. GMY kararı: *"razor yap ne olacak zaten bir şey
yapmadık"* — Adım 3'ün Blazor iskeleti atıldı (bir saatlik iş), Razor Pages kuruldu.
Tailwind/DaisyUI da kaldırıldı: Solum kendi tasarım sistemini getiriyor (`solum.css`),
iki tasarım sistemi bir arada tutulmaz — bu uygulama `renk-standardi.md`'nin DaisyUI
kuralının DIŞINDADIR.

### ⭐ ŞUBE, Solum'un `ICurrentCompany`'si DEĞİLDİR (Solum ekibi, 18.09)

Şubeyi Solum'un "şirket" kapsamına oturtmak ilk bakışta bedava görünüyor (otomatik süzme +
otomatik doldurma) ama **reddedildi**, iki gerekçeyle:

1. `ICurrentCompany`'nin yanında `IsCrossCompany` bayrağı var ve o bayrak konsolide rapor
   için **meşru olarak açılır**. GMY'nin "bütün şubeleri gör" ihtiyacı onu açtırırdı — ve o
   bayrak aynı zamanda **tüzel kişilik** sınırını açan bayraktır. BKM ikinci bir şirket
   kurduğu gün, şube için açılmış kapı şirketler arası açılmış olurdu.
2. `ICompanyScoped`'un getirisi **EF makinesidir** (sorgu süzgeci + `SaveChanges` kuralları).
   Biz Dapper + SP kullanıyoruz → **bedeli var, getirisi sıfır**.

⇒ Şube kolonu `Vrd_*` tablolarında **kendi adıyla** durur: `SubeId`, `CompanyId` değil.

**Şube boğazı (Adım 4'te kurulacak):** `@SubeId` değerini hiçbir sayfa üretmez. Tek bir
`SubeKapsami` servisi claim'den okur, ACL'ye karşı doğrular, SP çağrısı parametreyi
**yalnız oradan** alır. Sayfa "hangi şube" parametresi **alamaz** — alabiliyorsa bir gün
biri oraya istekten gelen değeri yazar. Ölçüt: *"yanlış bir şube id'si bu yoldan geçebilir mi?"*
(Daha sert seçenek: SP `@KullaniciId` alıp şubeyi SQL içinde ACL'den çözer — boğaz veritabanında.
GMY'nin "hepsi" durumu için ayrı yol gerekir. Karar Adım 4'te.)

### ⚠ "Tüm şubeler" yetkisi ÇEREZDE TAŞINMAZ (Solum emsali, 18.09)

Solum'un `IsCrossCompany` bayrağı bilerek **talepte taşınmıyor**; gerekçesi ölçülü:
*"bir kez verilen konsolide hakkı oturum boyunca açık kalırdı."*

Aynısı GMY'nin ve İK'nın "tüm şubeler" görüşü için geçerli: kalıcı bir claim/çerez bayrağı
**değil**, isteğe bağlı ve her seferinde yeniden verilen bir kapsam olmalı. Böylece bir GMY
oturumu ele geçirilse bile kalıcı bir kapı açılmış olmaz.

### Roller: kod ROL adı görmez, İZİN görür

Identity rolleri *kim olduğunu* söyler; kod `vardiya.onayla` / `vardiya.tumSubeler` gibi
**izinleri** kontrol eder. `if (rol == "IK")` yazılmaz — dördüncü rol geldiği gün o
karşılaştırmaların hepsini bulmak gerekir ve biri kaçar. İzin→rol eşlemesi başta kodda sabit
bir sözlük olabilir; `SolumPermissionGrant` tablosu sonra devreye alınırsa çağrı yerleri
değişmez.

### Alınan Solum betikleri (hepsi DEĞİL)

| Betik | Alınıyor mu |
|---|---|
| `0005_SolumPermissions` | ✅ izin katmanı için. ⚠ `SolumUserCompanyAccess` şube ACL'i DEĞİL — şube ACL'i `Vrd_*` altında bizim |
| `0025_SolumAuditTrail` | ✅ **KURULDU 19.09** — ilk koşumda patladı (`Changes NVARCHAR(8000)`, T-SQL sınırı 4000, Hata 2717); betik **hiçbir SQL Server'da koşmamıştı**, üçüncü tüketici olarak ilk koşan biz olduk. Solum `NVARCHAR(MAX)` ile onardı (`38dcfe3`) ve şema kapısına tip-sınırı iddiası ekledi. Bizde yamalanmadı, onarılmış sürüm koşuldu. |
| `0015_SolumTimeOffset` | ❌ **ALINMIYOR — ölçüldü (Solum, 18.09):** yalnız `SolumNotification` + `SolumMailLog`'a dokunuyor, ikisi de `0010`'un tablosu; `0005`/`0025` ile sıfır teması. `0025.At` zaten `DATETIMEOFFSET(7)`. ⚠ Almak zararsız görünür (`IF OBJECT_ID` korumalı) ama **sessiz kusur üretir**: koşmamış betik deftere "uygulandı" yazılır, ileride `0010` alınırsa dönüşüm hiç koşmaz. Bildirim/mail eklenirse sıra `0010` → `0015`, birlikte. |
| `0010_SolumMessaging` · `0020_SolumSettings` · `0030_SolumAttachments` | ❌ gerekmiyor |

Koşucu `MigrationRunner`; zinciri biz veriyoruz. Betikler idempotent ama kimlik **ad + içerik
özeti** — atlanan betik sonradan eklenebilir, **düzenlenen** betik hata verir (doğrusu budur).

### Bağlama yöntemi: `ProjectReference`

Solum ekibinin önerisi ve mevcut iki tüketicinin yaptığı: restore yok, ara durum görünür,
kırıcı dokunuş öncesi tüketiciye haber veriliyor. Yerel NuGet beslemesi de makineye bağlı
olduğu için üstünlüğü yoktu. (Genel bir NuGet feed'i Solum'un açık borcu.)
⭐ `Solum.Identity` fiilen **donmuş** (180 shipped / 1 unshipped üye) — en çok dayandığımız
paket en kararlısı. `Solum.Web` en oynak (248 unshipped) ama ondan yalnız kabuk alıyoruz.

**Ad `BkmVardiya.Core` değil `Bkm.Shared` oldu:** taşınan `Db` vardiyaya özgü değil —
Joker, Zirve ve panel bağlantılarını da taşıyor. Vardiya adını vermek kapsamı yanlış
anlatırdı.

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
2. ✅ **TAMAM 18.09** — `lib/Bkm.Shared` kuruldu; dört dosya `git mv` ile taşındı
   (geçmiş korundu): `Db` · `SqlErrorClassifier` · `VardiyaQueries` · `VardiyaModels`.
   Namespace `Bkm.Shared.Data` / `Bkm.Shared.Models`; dashboard'a `GlobalUsings.cs`
   eklendi → **çağıran 47 dosyaya dokunulmadı**. Derleme yeşil.
   **ÖLÇÜLDÜ:** taşıma sonrası kırılan yer yalnız 2 satır (`Program.cs`, tam nitelikli
   `GmDashboard.Data.Db` yazımı) + kütüphanede eksik iki `using` (Web SDK'nın implicit
   using'i sınıf kütüphanesinde yok). Hepsi **derleme hatası** olarak görüldü — sessiz
   sapma değil. Smoke test AÇIK (panel çalışır durumdaydı, yeniden başlatılmadı).
3. ✅ **TAMAM 18.09** (sonra Razor Pages'e çevrildi — 3b) — `vardiya-app` iskeleti:
   ~~Blazor Server~~ (port **5120**), ~~DaisyUI~~
   corporate tema, Türkçe UI, `Bkm.Shared` ProjectReference. Derleme **0 uyarı 0 hata**.
   **ÖLÇÜLDÜ (smoke):** uygulama ayağa kalktı ve ortak kütüphaneden kesim okudu —
   31.08-16.09.2026 · sayım başı 01.09 · **6.113 kişi-gün** · 9 şube · yazılma 17.09 20:23.
   6.113 rakamı plan-47 parite kapısındakiyle AYNI → taşıma veriyi bozmadı.
   `.claude/launch.json`'a `vardiya-app` profili eklendi.
   **3b ✅ Razor Pages dönüşümü (aynı gün):** Solum kararı gelince Blazor iskeleti atıldı,
   Razor Pages + Solum `ProjectReference` kuruldu, Tailwind/DaisyUI kaldırıldı.
   Derleme 0 uyarı 0 hata; smoke AYNI veriyi verdi (6.113 kişi-gün / 9 şube) ve
   `solum.css` yükleniyor. Solum kabuğu (`_SolumLayout`) henüz KULLANILMIYOR:
   `IMenuBuilder`/`IPermissionChecker`/`ICurrentUser` auth'a bağlı → Adım 4.
   ⚠ Bu iskelette **giriş YOK** — sayfa anonim açılıyor, üstte "Geliştirme — giriş yok"
   yazıyor. Ağa açılmadan önce Adım 4 kapanmalı.
4. Auth + rol + şube sınırı — **Solum.Identity** (`DapperUserStore`, kullanıcı adı+şifre;
   cookie şemasını biz kurarız, Solum yalnız depo verir) + `SubeKapsami` boğazı + izin
   katmanı + `_SolumLayout` kabuğunun devreye alınması. Sunucu-taraflı süzgeç ve yetki testi.
5. Eksik/fazla + mesai raporu ekranı (mevcut sayfadan taşıma).
6. Onay akışı ekranı + denetim izi (`bkm.Vrd_Onay` üzerine log).
7. Panelin vardiya sayfasının akıbeti; nav düzenlemesi.
8. Parite + yetki testleri, journal + sema kaydı, TODO senkronu.

## Geri alma

Yeni app ayrı proje — çalışmazsa çalıştırılmaz, panel eski haliyle sürer. Tek geri-alınması
iş isteyen adım ortak kütüphaneye çıkarma (Adım 2); o adım kendi commit'inde tutulur ve
`git revert` ile tek hamlede dönülür. Veri tarafına DDL eklenmez — plan-47 tabloları aynen
kullanılır (yalnız denetim-izi tablosu eklenirse `erp-write-policy.md` güncellenir).
