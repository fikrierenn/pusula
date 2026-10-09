# Ekran sözleşmesi — A, B, C ekranlarının telefon davranışı

Spec: H2, H3, H5, H6, AC-0.3–0.10, FR-005–FR-009, FR-003a/b · Plan: K2, K8
Genel kurallar (her A/B ekranı):
- Tek `.razor`, tek hesap. Masaüstüne özgü bölüm yalnız `Gorunum == Masaustu` iken **çizilir ve verisi yüklenir** (plan K2); telefonda yerinde "Ayrıntı masaüstünde." notu (FR-007). Yalnız düzen farkları (sütun, boşluk) CSS `lg:` sınıflarıyla.
- Dışa aktarma (`ExcelButton` ve benzeri) yalnız `Gorunum == Masaustu` iken çizilir; telefonda hiçbir ekranda (A, B, C) dışa aktarma düğmesi yoktur (KVKK K5, FR-011).
- Telefon özetinde gösterilen her gösterge masaüstündeki aynı göstergeyle **aynı alan**dan okunur; karşılaştırma ölçümü için öğe `data-gosterge="<ekran>.<ad>"` taşır (AC-0.3, SC-005).
- Dokunulabilir her öğe `button`, `a` ya da `role="button"`/`role="tab"` taşır ve telefonda ≥ 44×44 px (AC-0.6). Giriş alanları telefonda 16 px (AC-0.8).
- `title=` ile taşınan bilgi telefonda görünür metin ya da dokununca açılan açıklamadır (AC-0.7).
- Hata: `KullaniciMesajlari.VeriAlinamadi` + `Logger.LogError(ex, "{Ekran} veri yükleme hatası", "<Ekran>")`; `ex.Message`, `GetType().Name`, SP adı ekrana yazılmaz (AC-0.10). Bugün bunu ihlal eden 002 ekranları: `CariRisk.razor:120`, `Muhasebe.razor:40,171`.
- Dosya büyümez: değişen bölüm alt bileşene çıkar (plan K8).
- 001 notları (`DuzeltmeNotu`, "Hedef tabanı teyit bekliyor") telefonda da göstergenin yanında (AC-0.4).

## A — telefonda tam

| Ekran | Telefon sözleşmesi | AC | Dalga |
|---|---|---|---|
| **Cari/Risk** `/cari-risk` | En üstte iki gösterge: vadesi geçen tutar (> 0 `text-error`), limit aşan cari sayısı (> 0 `text-warning`) — hesap 001 Cari/Risk ek maddesinin çekirdeğinden. Gösterge 001 Cari/Risk ek maddesinin düzelttiği hesaptır (tam toplam, alıcı/satıcı ayrımı); ekran telefona o madde kabul testinden geçince açılır (`ekran:cari-risk` kapısı). Liste `AppDataTable`: birincil = cari adı, metrik = net bakiye; dokununca açılan ayrıntıda kod, tip, borç, alacak, vadesi geçen, yaklaşan, limit (masaüstündeki alanların tamamı). Arama ve kapsam sekmeleri telefonda ≥ 44 px, `input` 16 px | AC-2.1, 2.2 | 1 (düzen) · kapı: `001:cari-risk` |
| **Görevler** `/gorevler` | En üstte açık ve geciken sayısı (`GorevService.Ozet`); geciken görev `badge badge-error`. Ekle, tamamla, sil telefonda da var; **silme `Modal` ile onay sorar** ("Görev silinsin mi? Bu işlem geri alınamaz." [Sil] [Vazgeç]) — masaüstünde de aynı (bugün onaysız: `Gorevler.razor:54,138`) | AC-2.3, 2.4 | 1 |
| **Asistan** `/asistan` | Başta şerit: Sohbet · Görevler (`/gorevler` bağlantısı, geciken rozeti) · Bellek (sayfa içi sekme; `GeniusBellek` alt bileşen). Giriş çubuğu `AsistanGirisCubugu` alt bileşeni: akış içinde, sayfa sonunda yapışkan; odakta alt menü gizlenir. Öneri kartlarında onay/ret düğmeleri ≥ 44 px, sonuç masaüstüyle aynı metot | AC-2.5–2.7 | 1 |
| **Bugün** `/` | `bugun.md` | H4 | 1–2 |

## B — özet

| Ekran | Telefonda görünen | Telefonda gizlenen (yerinde not) | AC | Kapı | Dalga |
|---|---|---|---|---|---|
| **Muhasebe** | Seçili dönemin kontrol bulgusu adedi, toplam tutar, tutarı en büyük 3 kalem (`MuhasebeQueries.KontrolOzeti`); yıl/ay seçimi taşmadan | Ayrıntı tablosu, evrak açma | AC-3.1, 3.5 | — | 1 |
| **Gelir tablosu** | Kapanmış son ayın faaliyet kârı (`GelirTabloQueries.Ozetle`; ay `bkm.Fin_AyKapanis`'ten) + "Tahakkuk esaslıdır, nakit akışı değildir." Masaüstünün varsayılan dönemi değişmez | Gelir tablosu satırları | AC-3.2, 3.5 | — | 1 |
| **Mizan** | Nakit, alınan çekler (nakitten ayrı), KDV pozisyonu (001 H12 kartları) | Hesap ağacı (`MizanDugum`) | AC-3.3, 3.4 | `ekran:mizan` | 2 |
| **Toplam** | Cirosu en yüksek 5 kategori ve payı | Tüm kategori listesi | AC-5.6 | `ekran:toplam` | 1 (001 dosyaya dokunmuyor) |
| **Mağazalar** | Her mağaza bir kart; okul açılışı uyarısı görünür metin | Gün karşılaştırma tablosunun geniş hâli | AC-5.2 | `ekran:magazalar` | 2 |
| **Mağaza** `/magaza/{id}` | Göstergeler en çok 2 sütun; dönemin en yoğun 5 saati liste | Saat × gün ısı haritası | AC-5.3 | `ekran:magaza` | 2 |
| **E-ticaret** | Bekleyen sipariş kartı en üstte (`BekleyenOzet`), altında net ciro | Kategori, kargo, huni bölümleri | AC-5.4 | `ekran:eticaret` | 2 |
| **Sınav Okulları** | Ana göstergeler; iade oranı ≥ %3 `text-error` | İade belge listesi | AC-5.5 | `ekran:sinav` | 2 |
| **Tahmin** | Tahmin + alt–üst aralık | Model karşılaştırması | AC-5.7 | `ekran:tahmin` | 2 |
| **Operasyon** | Yalnız uyarı (istisna) kartı | Kumbara ve manuel indirim (001 AC-1.4), personel saati başına satış (AC-6.3, kapı `ek:splh`), öteki bölümler | AC-6.3, 6.3a | `ekran:operasyon` | 2 |
| **Envanter** | Üç gösterge: ölü stok, aşırı stok, stokta yokluk + 001 H14 tanım metinleri (`StokGostergeTanimlari`) | Listeler, modallar | AC-6.4 | `ekran:envanter` | 2 |
| **Vardiya** | Mağaza bazında, isimsiz özet (`GetBranchBreakdownAsync`, uyum kartları) | Kişi satırları tablosu (ad, sicil, not): telefonda `GetRowsAsync` **çağrılmaz**, satırlar DOM'a ve SignalR akışına gönderilmez, bileşen durumunda tutulmaz; yerinde "Kişi satırları masaüstünde." (KVKK K2) | AC-6.5, FR-009 | `ekran:vardiya` | 2 |

Masaüstünde gizlenen bölüm yoktur: B ekranının masaüstü görünümü bugünküyle aynıdır (AC-5.8, AC-0.9).

## C — yalnız masaüstü (asgari)

17 ekran (spec § Ekran sınıfları). Telefonda açılınca **sayfa** yana taşmaz; geniş tablo kendi kutusunda kayar (`overflow-x-auto` kap, `min-w-0` ızgara çocukları, sabit genişlik kalkar — ör. Fatura 580 px). 44 px kuralı uygulanmaz (AC-6.2, FR-003a, SC-001a). Yeniden tasarım yok.
Dalga 1: Kadro, Patron soruları, Stok hareket, Gider merkezi mizanı, Yevmiye, Fatura, Ayarlar. Dalga 2: Müşteri, Trafik, Hediye çeki, ODAK stok, Baskısı yok, Satınalma analiz, Satış analizi, Satış analizi ürün detayı, Sezon aksiyon, Eşikler.

### Maskeleme — Müşteri, Sadakat, Trafik (plan K11, GMY 08.10 + 09.10.2026)

**Takvim:** ilk sürümde bu üç ekran telefonda kapalıdır (kapılar `ekran:musteri` → D-1, `ekran:trafik` → H5, `ekran:sadakat` → H2+H5). Kapalıyken telefonda doğrudan adresle açılırsa `MainLayout` sayfayı kurmaz, "Bu ekran masaüstünde açılır." yazar. `KisiselVeriMaske` Dalga 1'de yazılır; Razor hücreleri Dalga 2'de (001 master'a girince) bağlanır; kapı Dalga 3'te, maske ölçümü yeşilken açılır.

Kural: `Gorunum != Masaustu` (telefon ya da bilinmiyor) iken aşağıdaki alanlar **sunucuda, çizim anında** maskelenir; açık değer DOM'a ve SignalR akışına gitmez. Masaüstünde değişiklik yok. Sorgu değişmez.

```csharp
public static class KisiselVeriMaske
{
    public static string Ad(string? ad);        // "Ahmet Yılmaz" → "A*** Y***"; her kelimenin ilk harfi + "***"; boş/null → "—"
    public static string Telefon(string? tel);   // yalnız rakamlar alınır; ≥ 6 rakam → ilk 4 + " *** ** " + son 2 ("05321234545" → "0532 *** ** 45"); 10 haneli (başında 0 yok) → başa "0" eklenmeden ilk 4 rakam; < 6 rakam → "***"; boş/null → "—"
    public static string KartNo(string? kart);   // son 4 karakter açık: "2025000012341234" → "**** 1234"; ≤ 4 karakter → "****"; boş/null → "—"
}
```

| Ekran | Maskelenen alan | Not |
|---|---|---|
| Müşteri (`/musteri`) | Müşteri adı, telefon, kart no (liste, drill, RFM/LTV tabloları) | Sayılar (ciro, sıklık) açık kalır |
| Sadakat (`/sadakat`; Dalga 2'de Müşteri sekmesi) | Win-back listesi ad, telefon, kart no | Birleşmede maske birlikte taşınır |
| Trafik (`/trafik`) | Kasiyer adı (personel tablosu) | Fiş, net, gün, saat açık kalır |

- Maskelenmiş değer arama/sıralama anahtarı olarak kullanılmaz (sıralama açık değerle sunucuda yapılır, yalnız gösterim maskeli).
- Satıra dokununca açılan ayrıntı da maskelidir.

### Ayarlar ve Eşikler (veri değiştiren ekranlar)

| Görünüm | Davranış | AC |
|---|---|---|
| Telefon | Kayıtlı değerler düz metin listesi; form alanı, kaydet ve sil düğmesi `Gorunum != Masaustu` iken çizilmez; not: "Değişiklik masaüstünden yapılır." | AC-6.6, FR-003b |
| Masaüstü | Bugünkü form; ay kapanış tarihi girişi ve eşik kaydı aynen | AC-6.7 |

Bu bir arayüz kuralıdır, yetki sınırı değildir (tek kullanıcı; plan § Anayasa kapıları 8).

## Birleşen ekranlar (X)

| Eski | Hedefte yer | Dosya | Dalga |
|---|---|---|---|
| Ana sayfa v2 `/v2` | Bugün (bölüm yok) | `HomeV2.razor` `@page` kalkar | 1 |
| Asistan belleği `/bellek` | Asistan → Bellek sekmesi | `GeniusBellek.razor` alt bileşen | 1 |
| Sadakat `/sadakat` | Müşteri → Sadakat sekmesi | `Sadakat.razor` alt bileşen | 2 |
| Bulunurluk `/bulunurluk` | Satış analizi → Bulunurluk sekmesi | `Bulunurluk.razor` alt bileşen | 2 |
| Satınalma ürün detayı `/satinalma/urun/{id}` | Satış analizi ürün detayı → Satınalma sekmesi (aynı ürün) | `SatinalmaUrunDetay.razor` alt bileşen (`StkId` parametresi) | 2 |
| Sabah `/sabah` | Bugün → Sabah brifingi bölümü | `Sabah.razor` alt bileşen | 2 |

Alt bileşene dönüşen dosyanın sorgusu ve hesabı değişmez; bu yüzden hedefteki gösterge değeri eski ekranla aynıdır (AC-7.3). Sekmeler `role="tab"`, ≥ 44 px.

## Testler

| Test | Tür | AC |
|---|---|---|
| `TiklanabilirOge_ABEkranlarinda_SemantikEtiketli` (kaynak taraması: `@onclick` taşıyan `div/tr/td/span/li` → `role` zorunlu) | birim | AC-0.6 |
| `HataMetni_Dalga1Ekranlari_ExMessageYok` (CariRisk, Muhasebe, GelirTablosu, Gorevler, Asistan) | birim (kaynak metin) | AC-0.10 |
| `Ekran_VeriKaynagiYok_GenelMesaj` (001 T-022 hata ekranı fabrikasıyla; ad 001'de kesinleşir) | `WebApplicationFactory` | AC-0.10 |
| `GorevSil_OnaySorar` | Playwright | AC-2.4 |
| `Gosterge_375ve1280_AyniDeger` (her açık ekrandan `data-gosterge` örnekleri) | Playwright | AC-0.3, SC-005 |
| `BEkrani_375_GizliBolumYerindeNot` / `BEkrani_1280_BolumEksiksiz` | Playwright | FR-007, AC-5.8, 0.9 |
| `Ayarlar_375_DuzenlemeYok_Not`, `Ayarlar_1280_FormVar` | Playwright | AC-6.6, 6.7 |
| `Vardiya_375_AdSicilNeDomdaNeDevredeVar`: telefon görünümünde sayfa açılır, sonuna kadar kaydırılır; `document.documentElement.innerHTML` **ve** Playwright `page.WebSocket` ile yakalanan bütün SignalR çerçeveleri (alınan ve gönderilen) canlı veriden alınan bir örnek kişinin adı ve sicili için taranır (örnek `LiveDb.PanelDb()` ile aynı dönemden; değer test çıktısına yazılmaz, yalnız bulundu/bulunmadı). Örnek kişi yoksa KOŞAMADI. **Kırılabilirlik:** telefon görünümünde geçici olarak bir isimli satır çizilir → test kırmızı görülür → elle geri alınır | Playwright | AC-6.5, FR-009, KVKK K2 |
| `Excel_375_DisaAktarmaYok` | Playwright (`olcum.md` § 5) | KVKK K5 |
| `KisiselVeriMaske_Ad/Telefon/KartNo` (teori: normal, Türkçe harf `İ/Ş/Ç`, çok kelime, boş, null, kısa telefon, boşluklu/tireli telefon, 10 ve 11 haneli telefon, ≤ 4 kart) | birim | KVKK K4, K11 |
| `KisiselVeriEkrani_375_KapaliKapi_DogrudanAdresNot` (Dalga 1: `/musteri`, `/trafik`, `/sadakat` telefon görünümünde → not var; DOM ve SignalR çerçevelerinde örnek açık ad/telefon yok; panelde bağlantı yok) | Playwright | KVKK K4, K11, AC-0.1 |
| `Maske_375_AcikAdTelefonNeDomdaNeDevrede` (Müşteri, Sadakat, Trafik; `olcum.md` § 5). Koşulduğu yer: Dalga 3 kapı açma görevi — anahtar `KapananMaddeler`'e eklendikten sonra, commit'ten **önce**; kırmızıysa kapı commit'lenmez. Dalga 2'de masaüstü dışı çizim, birim düzeyinde `KisiselVeriMaske` + hücre bağlantısının kaynak taraması ile sınanır | Playwright | KVKK K4, K11 |
| `Maske_1280_AcikDegerGorunur` (masaüstü değişmedi) | Playwright | AC-0.9 |
| `GelirTablosu_Ozetle_FaaliyetKari` (net satış + faaliyet gideri) | birim | AC-3.2 |
| `MuhasebeKontrolOzeti_EnBuyukUc` | birim | AC-3.1 |
| Taşma, 44 px, ipucu, 16 px | `olcum.md` | AC-0.5–0.8, 6.2 |
| Masaüstü eksiksizliği: dalga öncesi ve sonrası 1280 px'te her ekranın `data-gosterge`/başlık listesi karşılaştırılır | Playwright (önce/sonra) | AC-0.9 |
