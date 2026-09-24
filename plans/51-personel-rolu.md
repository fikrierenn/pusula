# Plan 51 — Personel rolü (V-04)

**Tarih:** 2026-09-20
**Proje:** `bkm`
**Yazan:** Claude (oturum `14a933e8`)
**Durum:** `Taslak` — GMY onayı bekliyor

---

## 1. Problem

Vardiya uygulaması bugün üç rolle çalışıyor: GMY · İK · ŞubeSorumlusu (17 hesap).
Çalışanın kendisi kendi mesai kaydını göremiyor; eksik/fazla bakiyesini öğrenmek
için müdürüne sormak zorunda. Bu hem bilgi asimetrisi hem itiraz sürtünmesi
yaratıyor: V-18'de eklenen "izinli değildi" itirazını bugün yalnız MÜDÜR
yazabiliyor, oysa itirazın kaynağı çalışanın kendisi.

## 2. ⚠ ÖNCE BİR DÜZELTME — plan 48'in iddiası YANLIŞ

Plan 48 (satır 51-52) şunu yazıyor:

> "Rol **şemada tanımlı kalır** ama hiçbir hesaba atanmaz — Faz 2'de açmak yeni
> yapı değil, yalnız hesap açmak olur."

**ÖLÇÜLDÜ (2026-09-20, `bkm` / BkmPanel) — üç parçası da yanlış:**

| İddia | Ölçüm |
|---|---|
| "Rol şemada tanımlı" | `bkm.Vrd_Roles` **3 satır**: GMY · IK · SubeSorumlusu. **Personel YOK.** |
| "Yeni yapı değil" | Kapsam yalnız ŞUBE ekseninde çözülüyor (`bkm.Vrd_SubeKapsami`). SİCİL ekseni **hiç yok**. |
| "Yalnız hesap açmak" | `bkm.Vrd_Users` düz ASP.NET Identity — **`SicilNo` kolonu yok**. Giriş yapan kişi ile personel kaydı arasında **hiçbir bağ yok**. |

Yani bugün bir "Personel" hesabı açılsa: `vardiya.tumSubeler` izni olmaz,
`Vrd_KullaniciSube`'de satırı olmaz → `Vrd_SubeKapsami` **boş küme** döner →
kullanıcı **hiçbir şey görmez**. Rol çalışmaz, sessizce boş ekran verir.

> Bu, `olctum-mu-cikardim-mi.md` § makul çıkarım sınıfı: "rol şemada duruyor"
> cümlesi makul görünüyordu ve 19.09'dan beri TODO'da öyle duruyordu; kimse
> `Vrd_Roles`'a bakmamıştı.

## 3. Ölçülen nüfus

| | |
|---|--:|
| Kişi-günde tekil sicil | **380** (TODO "362" diyordu — bayat) |
| Adı dolu sicil | 380 |
| Sicili BOŞ kişi-gün | 1 |
| Şube | 9 |
| Mevcut hesap | 17 (2 GMY · 3 İK · 12 ŞubeSorumlusu) |

⚠ 380 sayısı **bu kesimde çalışmış** kişidir; kadro sayısı değil. İşten ayrılan
da içinde. Hesap açılacak gerçek kadro İK'dan alınmalı.

## 4. Scope

### Kapsam dahili
1. **Kullanıcı ↔ sicil bağı** — bir kullanıcı hangi personel kaydının sahibi.
2. **Sicil ekseni kapsam çözümü** — şube ekseninin yanına, veritabanında.
3. **Personel rolü + izni** ve mevcut üç rolün ETKİLENMEMESİ.
4. **Personel ekranı** — kendi kişi-günü, kendi eksik/fazla bakiyesi, kendi devri.
5. **İtiraz yazma** — V-18 itirazını çalışanın kendisi yazabilsin (karar: bkz. S3).
6. **KVKK aydınlatma** metni + veri minimizasyonu denetimi.
7. **Kapılar:** V-07 toplanabilirlik testinin bozulmaması (bkz. §7).

### Kapsam DIŞI
- Şifre dağıtım ARACI (mail/SMS altyapısı) — İK süreci, ayrı iş.
- Personelin başkasının verisini görmesi — hiçbir senaryoda.
- Mobil uygulama / PWA.
- Prod'a terfi — bu plan DEV (`BkmPanel`) üzerinde kalır.

### Etkilenen dosyalar (tahmin)
- `sorgular/2026-09-XX-personel-rolu-kur.sql` — bağ tablosu + TVF + rol/izin (YENİ)
- `lib/Bkm.Shared/Data/VrdSql.cs` — kapsam boğazı: sicil ekseni
- `lib/Bkm.Shared/Data/VardiyaQueries.cs` — personel yüzeyleri
- `vardiya-app/Pages/Benim*.cshtml(.cs)` — personel ekranı (YENİ)
- `vardiya-app/Security/Seed.cs` · `Permissions.cs` — rol + izin
- `tests/BkmVardiya.Tests/PersonelScopeTests.cs` (YENİ) + `VardiyaAppFactory.cs`
- `tools/vardiya_kapsam_denetimi.py` — sicil ekseni de denetlensin
- `.claude/rules/erp-write-policy.md` — yeni tablo yazma yetkisi

**Tahmini boyut:** ~8 dosya, 400-600 satır. **Tier 3.**

## 5. Alternatifler

### A. Kullanıcı ↔ sicil bağı nasıl kurulur

| # | Seçenek | Artı | Eksi |
|---|---|---|---|
| **A1** | `Vrd_Users`'a `SicilNo` kolonu ekle | tek join, basit | Solum'un Identity şemasını DEĞİŞTİRİR; `DapperUserStore` standart kolon yazar, bir sonraki Solum sürümü kırabilir |
| **A2 ✅** | Ayrı `bkm.Vrd_KullaniciSicil (UserId, SicilNo)` tablosu | Identity şemasına DOKUNMAZ; `Vrd_KullaniciSube` ile aynı desen (zaten var ve çalışıyor) | bir join daha |
| A3 | UserName = sicil kuralı | tablosuz | ad değişince kopar; `fikri.eren` deseni zaten sicil değil |

**Öneri A2** — mevcut ACL deseninin ikizi. `KullaniciSube` nasıl çalışıyorsa
`KullaniciSicil` de öyle çalışır; yeni kavram yok.

### B. Kapsam nasıl çözülür

| # | Seçenek | Artı | Eksi |
|---|---|---|---|
| **B1 ✅** | Yeni TVF `bkm.Vrd_KisiKapsami(@UserId)` → sicil kümesi; boğazda `(Sube IN … OR SicilNo IN …)` | kapsam VERİTABANINDA kalır (GMY'nin 18.09 "b-tam yap" kararıyla aynı çizgi) | boğaz SQL'i biraz büyür |
| B2 | Uygulamada `if (personelMi) …` dallanması | kolay | **REDDEDİLDİ** — kapsamı uygulamaya taşır; `Permissions.cs`'in kendi notu "kod rol adı GÖRMEZ" diyor |
| B3 | Personel için ayrı sorgu seti | izole | aynı metrik iki yerde → `emitter-ayrimi` ihlali, biri bayatlar |

**Öneri B1.**

### C. Hesap açma

| # | Seçenek | Eksi |
|---|---|---|
| **C1 ✅** | Kademeli: önce 1 pilot şube (~50 kişi), ölç, sonra yay | — |
| C2 | 380 hesabı tek seferde | şifre dağıtımı + destek yükü tek anda patlar |

## 6. Riskler

| Risk | Önlem |
|---|---|
| **Personel BAŞKASININ verisini görür** | Sicil süzgeci boğazın İÇİNDE (B1). Test: personel ↔ başka sicil → boş. Bu planın EN KRİTİK kapısı. |
| **Kapsam boş kalır, sessiz boş ekran** | Bağ yoksa ekran "kaydınız eşleşmedi, İK'ya başvurun" DER; sessiz boş liste YASAK. |
| **V-07 toplanabilirlik testi bozulur** | Personel kapsamı şube bölmesi DEĞİL; `f(müdür)+f(tümleyen)==f(İK)` iddiası personel kullanıcı eklenince hâlâ geçerli (personel ayrı bir kullanıcı, bölmeye girmiyor) — ama test ön koşulu bunu YAZMALI. |
| **KVKK** | Kişi yalnız KENDİ verisini görür = veri sahibi erişimi, en güvenli hâl. Yine de aydınlatma metni + "ne toplanıyor / ne kadar saklanıyor" ekranı gerekir. İK + hukuk onayı ŞART. |
| **380 şifre** | C1 kademeli + ilk girişte zorunlu değiştirme (zaten var: `vardiya.sifreDegistir` claim). |
| **İşten ayrılan hesabı açık kalır** | Kadro kaynağı Zirve; ayrılanın hesabı kilitlenmeli. Bu bir SÜREÇ, kod değil — İK'ya yazılmalı. |

## 7. Done tanımı

1. Personel hesabı kendi kişi-gününü ve bakiyesini görüyor.
2. **Başka bir sicilin kaydını sorgulayınca BOŞ dönüyor** — test ile kanıtlı.
3. Mevcut üç rolün gördüğü rakamlar **birebir değişmedi** (parite ölçümü).
4. `tools/vardiya_kapsam_denetimi.py` sicil eksenini de denetliyor.
5. V-07 toplanabilirlik testi hâlâ yeşil; ön koşuluna personel notu eklendi.
6. **Kırmızı kip koştu:** sicil süzgeci kaldırılınca test KIRMIZI veriyor.
7. KVKK aydınlatma metni ekranda + İK onayı alınmış.

## 8. Rollback

Rol ve bağ tablosu ADDITIVE — mevcut üç rol hiç etkilenmiyor.
Geri alma: `Vrd_UserRoles`'tan personel atamalarını sil (hesaplar kalır, kapsam
boşalır) veya `SolumPermissionGrant`'tan personel iznini kaldır. Şema DROP
gerekmez. DEV'de kalıyor, prod'a hiçbir şey yazılmıyor.

## 9. Adımlar

1. DDL: `bkm.Vrd_KullaniciSicil` + `bkm.Vrd_KisiKapsami` TVF + `Personel` rolü/izni.
2. Boğaz: `VrdSql`'e sicil ekseni; SQL sözleşmesi güncellenir.
3. Test ÖNCE: `PersonelScopeTests` — başkasının verisi BOŞ, kendi verisi DOLU.
4. Personel ekranı (salt-okuma) + "eşleşmedi" mesajı.
5. İtiraz yazma (S3 kararına göre).
6. Kapılar: kapsam denetimi + V-07 ön koşulu.
7. Pilot şube, ölçüm, yayma.

---

## GMY KARARI BEKLEYEN ÜÇ SORU

**S1 — Personel neyi görsün?**
(a) yalnız kendi kişi-günü + bakiyesi · (b) + kendi vardiya planı ·
(c) + kendi şubesinin ANONİM özeti (kıyas için)

**S2 — İtirazı personel yazabilsin mi?**
(a) hayır, yalnız görsün · (b) evet, yazsın ama müdür ONAYLASIN ·
(c) evet, doğrudan yazsın
⚠ (c) seçilirse bir kişi kendi mesai kaydını tek taraflı değiştirebilir hâle gelir;
onay basamağı olmadan bu bir yazma yetkisidir.

**S3 — Hesap açma kimde?**
(a) İK tek tek (mevcut `ResetPassword` ekranı) · (b) toplu üretim + İK dağıtır ·
(c) kişi kendi kaydolur (e-posta doğrulama) — altyapı YOK, ayrı iş.
