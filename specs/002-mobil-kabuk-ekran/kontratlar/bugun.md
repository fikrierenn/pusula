# Bugün ekranı sözleşmesi

Spec: H4 (AC-4.1–4.17), FR-003, FR-005, FR-008, FR-009, sınır durumlar · Plan: K4

## 1. Sayfa

`Components/Pages/Bugun.razor`, `@page "/"`.

```
<h1>Bugün</h1>  (+ "dd.MM.yyyy dddd" tarih; kartlar "dün"ü gösterir)
ÜST BÖLÜM   kart şeridi, sıra 1 · 1a · 3 · 4 · 5 · 7 · 8   (görünme koşulu sağlanmayan kart ÇİZİLMEZ, boş kutu yok)
ALT BÖLÜM   kart 2
            @if (Gorunum == Masaustu || TelefonKapisi.Acik("ekran:bugun-donem")) { <Home /> }   (bugünkü Ana sayfa içeriği; telefonda kapı kapalıyken çizilmez, sorgusu koşmaz)
            @if (Gorunum == Masaustu || TelefonKapisi.Acik("ekran:bugun-donem")) { Sabah brifingi }   (açılır bölüm, Dalga 2)
```

- Kart şeridi telefonda tek sütun, masaüstünde ızgara (UI kararı 2). Kartlar masaüstünde de kapıya uyar.
- Her kart kendi verisini bağımsız ve paralel yükler; biri hata verirse yalnız o kart `KullaniciMesajlari.VeriAlinamadi` gösterir (sınır durum, AC-0.10).
- Kart 6 bu spec'te hiç çizilmez (`kart:6` kapısı `003:nakit`; AC-4.14).
- İlk sürüm (001 maddelerinin ve Cari/Risk ek maddesinin hiçbiri kapanmamış): yalnız kart 7; `Home` ve Sabah bölümleri telefonda gizli (AC-4.17, GMY kararı 08.10.2026).

## 2. Kart çerçevesi (`Components/Shared/Bugun/BugunKart.razor`)

| Parametre | Tip | Not |
|---|---|---|
| `Baslik` | `string` | |
| `Hedef` | `string` | Kaynak ekran adresi; kartın tamamı `<a href>` (AC-4.15), ≥ 44 px |
| `Ton` | `BugunTon` (`Yok`, `Basari`, `Uyari`, `Hata`) | DaisyUI `text-success` / `text-warning` / `text-error`; `Yok` renksiz |
| `Yukleniyor`, `Hata` | `bool`, `string?` | Yükleniyor iskeleti sabit; spinner ve ikon CSS ile değişir (Lucide kuralı) |
| `Not` | `RenderFragment?` | 001 "Hesap düzeltildi (gg.aa)" (`<DuzeltmeNotu>`) ve "Hedef tabanı teyit bekliyor" notları göstergenin yanında (AC-0.4) |
| `ChildContent` | `RenderFragment` | Değer satırları |

Kart, kendisi ekrandaki göstergeyle **aynı çekirdek metodu** çağırır; kartta `SUM`/`CASE`/eşik hesabı yazılmaz. Renk `BugunRenk` saf fonksiyonlarından gelir.

## 3. Kartlar

| # | Bileşen | Değer(ler) | Çekirdek (kaynak ekranla ortak) | Renk (`BugunRenk`) | Kapı | Dokununca |
|---|---|---|---|---|---|---|
| 1 | `DunkuCiroKarti` | Perakende · Sınav Okulları · Toplam (her mağaza ve şirket); e-ticaret ayrı satır; kıyas günü "gg.aa.yyyy, gün adı"; her satırda geçen yıl değeri ve değişim yüzdesi | `Queries.GetPeriodAsync(dün, dün+1, kıyas, kıyas+1)` (001 T-040 sonrası perakende/Sınav kırılımıyla); kıyas günü `OkulHizaliKiyas.Bul(dün)` (plan K9: Temmuz–Ekim okul açılışı farkı, öteki aylar −364) | Satır başına bağımsız: `Degisim(%)`: ≤ −10 → `Hata`; −10 < x ≤ −5 → `Uyari`; > −5 → `Yok`. Kıyas yok → "Kıyas günü yok", `Yok`. Mağaza kapalı → "Kapalı", düşüş sayılmaz | `kart:1` | `/` dönem görünümü (`#donem`) |
| 1a | `SinavIadeKarti` (kart 1 altında satır) | Sınav Okulları iade oranı | `SinavQueries` Sınav KPI (`IadeOraniYuzde`) | ≥ %3 → `Hata` | `kart:1a` + ay ∈ {7,8,9,10} (`TimeProvider`) | `/sinav` |
| 2 | `AyHedefiKarti` | Gerçekleşen, hedef, gerçekleşme %, ay sonu tahmini, alt–üst aralık | `Queries.GetHedefAsync` + `Queries.GetTahminAsync` (`TahminSonuc.Tahmin/Alt/Ust`) | ≥ %95 `Basari`; %85–95 `Uyari`; < %85 `Hata` | `kart:2` | `/tahmin` |
| 3 | `UyarilarKarti` | "N kontrol koştu, 0 uyarı" ya da uyarı satırları; koşamayan kontroller ayrı satır (sayı + ad) | `UyariKurallari.Degerlendir(dün)` → her kontrol için {Uyari, UyariYok, Kosamadi} (tanım: plan K9 — Ana sayfanın iki uyarı kuralı) | Uyarı varsa en kötü satırın tonu; koşamayan varsa asla `Basari`; hepsi koşamadıysa "Kontroller koşamadı" | `kart:3` | `/#uyarilar` (Bugün içindeki Sabah bölümü) |
| 4 | `BekleyenSiparisKarti` | Bekleyen sipariş sayısı; 4 gün ve üstü bekleyen sayısı | `EticQueries.GetBekleyenAsync` + `BekleyenOzet(buckets)` (yeni saf fonksiyon, E-ticaret ekranı da kullanır) | 4 g+ > 0 → `Hata`; yoksa 2–3 g > 0 → `Uyari`; hepsi 0 → "0", `Yok` | `kart:4` | `/eticaret` |
| 5 | `CariRiskKarti` | Vadesi geçen alacak tutarı; limit aşan cari sayısı | 001 ek maddesinin düzelttiği Cari/Risk çekirdeği (tam toplam, alıcı/satıcı ayrımı); kart ekranın KPI'sıyla aynı metodu çağırır. 002 hesabı yazmaz | Tutar > 0 → `Hata` (spec AC-2.1); limit aşan > 0 → sayı `Uyari` | `kart:5` | `/cari-risk` |
| 7 | `GorevlerKarti` | Açık görev sayısı; geciken sayısı | `GorevService.Ozet(bugun)` | Geciken > 0 → geciken sayısı `Hata`; 0 → "0", `Yok` | `kart:7` | `/gorevler` |
| 8 | `PersonelUyumKarti` | Mağaza başına aşım sayısı (11 saat, 12 saat dinlenme, gece 7,5 saat); **ad ve sicil yok** | `VardiyaQueries.GetComplianceAsync(…, branch)` (Dalga 2, şube parametresi) | Aşım > 0 → `Uyari` | `kart:8` | `/vardiya` |

## 4. Kurallar

- **Aynı değer (FR-005, AC-0.3, AC-4.11):** kart ile kaynak ekran aynı metodu, aynı parametreyle (dönem, kapsam) çağırır. Kart 5'in değeri Cari/Risk ekranının açılış değeriyle; kart 4 E-ticaret'in bekleyen toplamıyla; kart 7 Görevler başlığıyla birebirdir.
- **Sıfır:** sayı 0 ise kart gizlenmez, "0" gösterir ve renksizdir (sınır durum).
- **Gün içi:** kartlar "dün"ü (kapalı gün) gösterir. Bugüne ait değer çizilirse yanında "gün içi, saatte bir güncellenir" yazar (sınır durum).
- **Koşamadı ≠ uyarı yok (FR-008, AC-4.9):** kontrolün kaynağı hata verdiyse sonuç `Kosamadi`dır, "0 uyarı" sayısına katılmaz.
- **KVKK (FR-009, AC-4.13):** kart 8 bileşeni yalnız şube adı ve sayı alır; çalışan adı/sicili taşıyan tip kart bileşenine geçmez.

## 5. Testler

| Test | Tür | AC |
|---|---|---|
| `BugunRenk_Degisim_SinirlarDahil` (teori: −4,99 → Yok · −5 → Uyari · −9,99 → Uyari · −10 → Hata · null → Yok) | birim | AC-4.4 |
| `BugunRenk_Gerceklesme` (95 → Basari · 94,99 → Uyari · 85 → Uyari · 84,99 → Hata) | birim | AC-4.6 |
| `BugunRenk_Bekleyen`, `BugunRenk_SinavIade` (3 → Hata), `BugunRenk_CariRisk`, `BugunRenk_Gorev`, `BugunRenk_Uyum` | birim | AC-4.5, 4.10–4.13, 2.1 |
| `SinavIadeSatiri_Temmuz_Ekim_Gorunur_Kasim_Gorunmez` (sahte `TimeProvider`; 001 T-023 yardımcısı) | birim | AC-4.5 |
| `UyariKurallari_KaynakHata_KosamadiSayilmazYesilDegil` | birim | AC-4.8, 4.9 |
| `BekleyenOzet_Kovalar` | birim | AC-4.10 |
| `CariRiskKarti_EkranKpisiyleAyniMetot` (kart ve ekran 001 ek maddesinin çekirdeğini çağırır) | birim (kaynak) + Playwright, kapı açılınca | AC-4.11 |
| `GetComplianceAsync_SubelerToplami_SirketeEsit` | canlı, `LiveDb.PanelDb()` (BkmPanel, salt-okuma; `lib/Bkm.TestAltyapi`) | AC-4.13 |
| `Bugun_375_IlkSurum_YalnizKart7` (kapı boş) · `Bugun_375_KapaliKartYok_BosKutuYok` · `Bugun_375_KartaDokununcaKaynakEkran` · `Bugun_KartDegeri_KaynakEkranlaAyni` (kart 7; kart 5 kapısı açılınca) · `Bugun_375_PersonelKartindaAdSicilYok` | Playwright | AC-4.2, 4.11, 4.15, 4.17, 4.13 |
