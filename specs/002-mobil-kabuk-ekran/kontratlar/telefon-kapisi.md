# Telefon kapısı sözleşmesi

Spec: FR-004, AC-0.1, AC-0.2, AC-3.4, AC-4.2, AC-4.14, AC-4.17, SC-006 · Plan: K1

## 1. İmza

```csharp
namespace GmDashboard.Models;

public static class TelefonKapisi
{
    // Ekran ya da kart anahtarı → gerekli madde anahtarları. Kaynak: spec 002 § "001 bağımlılığı" + H4 kart tablosu.
    public static readonly IReadOnlyDictionary<string, string[]> Bagimlilik;

    // 001 kabul testinden "tuttu" ile geçmiş maddeler. Bugün BOŞ.
    // Ekleme yalnız specs/001-panel-veri-duzeltme/kabul-sonucu.md'de "tuttu" satırı varken.
    public static readonly FrozenSet<string> KapananMaddeler;

    // Kapı kapalıyken telefonda doğrudan adresle de açılmayan ekranlar (K11): adres öneki → kapı anahtarı.
    public static readonly IReadOnlyDictionary<string, string> KisiselVeriEkranlari; // "musteri"→"ekran:musteri", "trafik"→"ekran:trafik", "sadakat"→"ekran:sadakat"

    public static bool Acik(string anahtar);                 // tanımsız anahtar → InvalidOperationException (programlama hatası)
}
```

- `Acik` tanımsız anahtarda **patlar**. Sessizce `false` dönmek, yazım hatasını "kapalı ekran" gibi gösterirdi.
- Bağımlılığı olmayan ekran (Görevler, Asistan, Muhasebe, Gelir tablosu) sözlükte boş dizi ile yer alır; her A/B ekranı sözlükte olmak zorundadır (test).
- Çizim kuralı (plan K2): `Çiz = Gorunum == Masaustu || TelefonKapisi.Acik(anahtar)`. CSS gizleme yardımcısı yoktur; kapısı kapalı bölüm telefonda çizilmez ve verisi yüklenmez.

## 2. Madde anahtarları

Biçim `<spec>:<madde>`. 001 maddeleri spec 001 başlıklarından; H10 iki kabul kriteriyle ayrı anahtardır.

| Anahtar | Anlamı |
|---|---|
| `001:H1` … `001:H14` | 001 hikâyeleri (H10 hariç) |
| `001:H10.1` | 001 AC-10.1 (hata ekranı genel mesaj) |
| `001:H10.3` | 001 AC-10.3 (sayısal olmayan ürün kodu) |
| `001:D-2`, `001:D-3`, `001:D-5` | 001 düşük bulgular |
| `003:nakit` | Spec 003 nakit raporu teslim edildi (kart 6) |
| `001:cari-risk` | 001 ek maddesi: Cari/Risk tam toplam + alıcı/satıcı ayrımı (GMY 08.10.2026) |
| `001:cari-risk` | 001 ek maddesi: Cari/Risk tam toplam + alıcı/satıcı ayrımı (GMY 08.10.2026) |
| `ek:splh` | Personel saati başına satış hesabının düzeltmesi (001 ek maddesi ya da 003) kabul testinden geçti |

## 3. Bağımlılık sözlüğü (spec 002 tablosunun kod karşılığı)

| Anahtar | Gerekli maddeler |
|---|---|
| `ekran:bugun-donem` (Ana sayfa içeriği + Sabah brifingi telefonda) | `001:H5`, `001:H13`, `001:D-2`, `001:D-5`, `001:H10.1`, `001:H10.3` |
| `ekran:toplam` | `001:H10.3` |
| `ekran:magaza` | `001:H6`, `001:H10.3` |
| `ekran:magazalar` | `001:D-5` |
| `ekran:eticaret` | `001:H4`, `001:D-3` |
| `ekran:sinav` | `001:H9`, `001:H10.3` |
| `ekran:tahmin` | `001:D-5` |
| `ekran:envanter` | `001:H3`, `001:H7`, `001:H8`, `001:H14`, `001:H10.1` |
| `ekran:operasyon` | `001:H1`, `001:H10.1` |
| `ekran:vardiya` | `001:H10.1` |
| `ekran:mizan` | `001:H12` |
| `ekran:cari-risk` | `001:cari-risk` |
| `ekran:trafik` (C, kişisel veri; maskeli açılır) | `001:H5` |
| `ekran:musteri` (C, kişisel veri; maskeli açılır) | `001:D-1` |
| `ekran:sadakat` (Müşteri içindeki Sadakat sekmesi; Dalga 2 öncesi `/sadakat`) | `001:H2`, `001:H5` |
| `ekran:gorevler`, `ekran:asistan`, `ekran:muhasebe`, `ekran:gelir-tablosu` | — |
| `kart:1` dünkü ciro | `001:H5`, `001:H13`, `001:D-2`, `001:H10.3` |
| `kart:1a` Sınav iade oranı | `001:H9` (+ Temmuz–Ekim zaman kuralı, kapı dışı) |
| `kart:2` ay hedefi | `001:H13`, `001:D-5` |
| `kart:3` uyarılar | `001:H10.1` + `kart:1` maddeleri (`001:H5`, `001:H13`, `001:D-2`, `001:H10.3`) — plan K9; spec değişikliği önerisi plan § Spec değişikliği gerekli |
| `kart:4` bekleyen sipariş | `001:H4`, `001:D-3` |
| `kart:5` vadesi geçen alacak | `001:cari-risk` |
| `kart:6` nakit | `003:nakit` |
| `kart:7` görevler | — |
| `kart:8` personel uyumu | `001:H10.1` |
| `gosterge:operasyon-splh` (personel saati başına satış, telefon özeti) | `ek:splh` |

`ekran:operasyon` kapısı açılsa da personel saati başına satış göstergesi telefon özetinde görünmez (AC-6.3); kendi anahtarı `ek:splh`'ye bağlıdır ve o madde ancak düzeltme ayrı kayıtta (001 ek maddesi ya da 003) kabul testinden geçince açılır (AC-6.3a).

## 4. Açma ve geri alma yolu

1. 001 `/kabul-testi` hükmü verilir.
2. Denetleyici `specs/001-panel-veri-duzeltme/kabul-sonucu.md`'yi yazar ve commit'ler. Biçim:
   ```markdown
   | Madde | Sonuç | Tarih | Kanıt |
   |---|---|---|---|
   | 001:H12 | tuttu | 20.10.2026 | .orkestra/calisma/001-panel-veri-duzeltme/kabul/... (özet: AC-12.1..12.3 GEÇTİ) |
   ```
   `Sonuç` ∈ {`tuttu`, `saptı`, `koşamadı`, `karar bekliyor`}.
3. 002 kapı görevi `KapananMaddeler`'e anahtarı ekler; tek satır, ayrı commit: `feat(bkm): telefon kapısı 001:H12 açıldı (spec 002)`.
4. Geri alma: anahtar kümeden çıkarılır (ayrı commit). Ekran ve kart bir sonraki yayında telefondan kalkar (spec § Sınır durumlar).

## 5. Testler (birim, her commit'te koşar)

| Test | Doğrular | Kırmızı ne zaman |
|---|---|---|
| `Bagimlilik_SpecTablosuylaAyni` | Sözlük, spec 002 "001 bağımlılığı" ve H4 kart tablolarıyla madde madde aynı (spec dosyası 001 T-023'ün depo dosyası okuma yardımcısıyla okunur); spec tablolarında olmayan anahtar yalnız `gosterge:` önekli olabilir (AC-6.3a) | Biri değişip öteki değişmezse |
| `Bagimlilik_AnahtarlarGecerli` | Her madde anahtarı § 2 kümesinde | Yazım hatası (`001:H5 ` gibi) |
| `Bagimlilik_HerABEkraniTanimli` | `NavRegistry` A/B öğelerinin hepsinin `ekran:` anahtarı var | Yeni A/B ekranı kapısız eklenirse |
| `Bagimlilik_KisiselVeriEkranlari_BeklenenMadde` | `ekran:trafik` → `{001:H5}`, `ekran:musteri` → `{001:D-1}`, `ekran:sadakat` → `{001:H2, 001:H5}` (testte açıkça yazılı); `KisiselVeriEkranlari`'ndaki her anahtar `Bagimlilik`'te var ve boş değil | Biri kapısız ya da yanlış maddeye bağlanırsa |
| `KisiselVeriEkrani_KapiAcilmadan_MaskeHazirOlmali` (kaynak taraması): `KapananMaddeler` `ekran:trafik/musteri/sadakat`'ı açıyorsa ilgili `.razor` dosyasında `KisiselVeriMaske.` çağrısı bulunmalı | Maske hücreleri yazılmadan kapı açılırsa |
| `KisiselVeriKorumasi_KapaliKapi_TelefondaBodyCizilmez` (birim: `MainLayout` karar fonksiyonu teori, `Gorunum` × kapı × adres; `/musteri/...` alt yolları dahil) | Koruma atlanırsa |
| `KapananMaddeler_HepsiKabulSonucundaTuttu` | Kümedeki her anahtar için `kabul-sonucu.md`'de `tuttu` satırı; o satırın `Kanıt` hücresi boş değil ve bir commit hash'i (7–40 onaltılık karakter, depoda var) ya da depoda var olan bir dosya yolu taşır | Kanıtsız açma; `koşamadı` satırıyla açma; boş ya da var olmayan kanıt |
| `Bagimlilik_GostergeAnahtarlari_BeklenenMadde` | Her `gosterge:` anahtarının beklenen madde kümesi testte açıkça yazılı: `gosterge:operasyon-splh` → yalnız `{ek:splh}`. Ek koşul: hiçbir `gosterge:` anahtarı `001:` önekli maddeye bağlanamaz | Bozuk satır (`gosterge:operasyon-splh` → `001:cari-risk`) |
| `Acik_TanimsizAnahtar_Patlar` | Tanımsız anahtar sessizce kapalı sayılmaz | — |
| `Acik_TumMaddelerKapaliysa_True` / `_BiriEksikse_False` | Kural | — |
| `CizimKurali_KapaliKapi_TelefondaCizilmez_MasaustundeCizilir` (teori: `Gorunum` × `Acik`) | Masaüstü etkilenmez; `Bilinmiyor` iken çizilmez | — |

Kırılabilirlik: `KapananMaddeler`'e geçici olarak `001:H12` eklenir (kabul sonucu yok) → test kırmızı görülür → geri alınır (`git reset --hard` kullanılmaz).
**Kabul ölçütü (risk taraması R2/R3, 08.10.2026):** `Bagimlilik_GostergeAnahtarlari_BeklenenMadde`, bu sözleşmenin önceki sürümündeki bozuk satırla (`gosterge:operasyon-splh` → `001:cari-risk`) koşulunca **kırmızı** vermelidir; kapı görevi bu kırmızıyı görmeden kapanmaz. `Kanıt` hücresi boş bir `tuttu` satırı `KapananMaddeler_HepsiKabulSonucundaTuttu`'yu kırmızıya düşürmelidir.

Uçtan uca karşılığı `olcum.md` § Kapı.
