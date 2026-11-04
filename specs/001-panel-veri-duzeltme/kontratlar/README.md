# Kontratlar — 001 Panel veri düzeltmeleri

Bu spec SP ve API ucu eklemez. Kontratlar dört dosyadadır:

| Dosya | İçerik |
|---|---|
| `ortak-tanimlar.md` | `dashboard/Data/Tanimlar/*` sınıflarının imzaları ve ürettikleri SQL parçasının sözleşmesi |
| `sorgu-metodlari.md` | Değişen her `*Queries` metodunun imzası, sonuç kümesi (kolon, tip, sıra) ve davranış farkı |
| `ekranlar.md` | Ekran sözleşmesi: göstergeler, etiketler, notlar, hata ve boş durum metinleri |
| `kanonik-sorgular.md` | AC → kanonik sorgu dosyası → parametreler → beklenen ilişki → test adı |

## Ortak kurallar

- **Doğrulama dönemi:** `@Bas = 01.09.2026`, `@Bit = 01.10.2026` (bitiş hariç). Bugüne bağlı göstergelerde (win-back, canlı WMS) tek `@Bugun` iki tarafa da verilir.
- **Tolerans:** adet ve sayılarda birebir; tutarlarda `|panel − kanonik| ≤ 1,00 TL`.
- **Sonuç etiketi:** `tuttu` / `saptı` / `koşamadı`. Bağlantı yok, sorgu hatası ya da kanonik nüfus 0 → `koşamadı`, test kırmızı.
- **Tarih:** C# tarafında `DateOnly`, SQL'e `DateTime` parametresi. SQL içinde tarih literali yok. ODAKJOKER OPENQUERY metninde ISO `yyyyMMdd` (yalnız `DateOnly`'den üretilir).
- **İsimlendirme:** 3 parçalı ERP adları. Yeni C# tanımlayıcıları İngilizce teknik kalıp + Türkçe alan terimi, Türkçe karakter yok (K1).
- **İptal belirteci:** dokunulan public metotlar son parametre olarak `CancellationToken ct = default` alır ve `CommandDefinition` ile iletir (K1). Varsayılan değer çağıranları kırmaz.
